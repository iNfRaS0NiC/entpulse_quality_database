<#
.SYNOPSIS
    Run the nightly pass: the closed checks that fit the night's budget, sport by sport.

.DESCRIPTION
    One job. Notice that something which was clean has stopped being clean, soon after it
    happens rather than whenever somebody next runs a full board.

    It selects rather than narrows. Only a check that is currently closed can newly fire - one
    already returning findings is already open on the board and in front of whoever is
    reviewing it - so the pass runs the closed ones and nothing else. Which of them fit is
    decided by a budget rather than a threshold in seconds, cheapest first, with a slice kept
    for the expensive tail so it comes round rather than never running between full boards.
    TOOLS/Nightly.ps1 holds the rule.

    **It writes to the board, and that is the point.** A check it finds is written `Reopened`
    by the same rule a full run uses, which means the reviewer meets a red chip rather than a
    green one contradicted by an email, and the notification goes out through the machinery
    that already exists. It also means no second copy of "report this once": a check written
    `Reopened` is no longer `Clean` or `Completed`, so the next night cannot reopen it again.

    A partial run is safe on a board by construction - see the -Complete guard in
    New-SheetsMergePlan. Rows the pass did not run are left holding the last full run's
    numbers rather than being blanked or removed.

    Nothing here decides anything about the data. It runs approved statements, writes what they
    returned, and leaves every conclusion to the people reading the board.

.PARAMETER Sport
    Limit the pass to these sports. Every sport with a ledger by default.

.PARAMETER BudgetMinutes
    What the night may cost in database time. The default is the 4.5 hours agreed on
    2026-09-01. A ceiling rather than a target: sixteen sports' whole closed set is about 67
    minutes, so today it binds on nothing.

.PARAMETER WhatIf
    Choose and report without running anything. What a first look should do.

.PARAMETER LogPath
    Where the pass writes what it printed. `TOOLS/nightly.local.log` by default, appended.

    The pass runs unattended from Task Scheduler, which captures nothing, and it runs with
    -NoLedger, so RUNS/ holds no record of it either. Without this file a night leaves no
    trace at all: a sport that failed, a check that timed out at the gateway, the seconds each
    statement cost - none of it is anywhere the next morning, and a broken night is
    indistinguishable from a quiet one. The board is not the answer, because a partial run
    leaves the rows it could not run holding the last full run's numbers.

.PARAMETER NoLog
    Run without writing the log. -WhatIf never writes one: it is a look at the selection, not
    a pass, and a log of passes is worth more for holding only passes.

.EXAMPLE
    .\TOOLS\Invoke-NightlyRun.ps1 -WhatIf

.EXAMPLE
    .\TOOLS\Invoke-NightlyRun.ps1 -Sport Curling
#>
[CmdletBinding()]
param(
    [string[]]$Sport,
    [double]$BudgetMinutes = 270,
    [switch]$WhatIf,
    [switch]$Quiet,
    [string]$LogPath,
    [switch]$NoLog
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Sheets.ps1')
. (Join-Path $PSScriptRoot 'Nightly.ps1')

# For the queue alone. The pass sends nothing itself - it writes the failure where the 07:00
# drain will find it, exactly as a board run writes a reopened check there.
. (Join-Path $PSScriptRoot 'Notify.ps1')

$RepoRoot = Split-Path -Parent $PSScriptRoot
$LedgerDir = Join-Path $RepoRoot 'RUNS'
$RunQuery = Join-Path $PSScriptRoot 'Run-Query.ps1'

# ----- the log ------------------------------------------------------------------------------
#
# Start-Transcript rather than lines written by hand, because what is worth keeping is mostly
# printed by Run-Query rather than here: the per-check line with its rows and seconds, the
# parameters it resolved, the sheet it wrote. Those go to the host, which a transcript captures
# and the `| Out-Null` below does not touch.
#
# The name follows nightly.local.json beside it, so one .gitignore rule covers both. `.log` is
# outside the set Test-Package.ps1 scans, so nothing here has an opinion about its bytes.

$logStarted = $false

function Stop-NightlyLog {
    # Called before every exit. Transcription is flushed as it goes, so a process killed
    # mid-pass still leaves everything up to that moment; this only writes the footer.
    if (-not $script:logStarted) { return }
    $script:logStarted = $false
    try { [void](Stop-Transcript) } catch { }
}

if (-not $NoLog -and -not $WhatIf) {
    if ([string]::IsNullOrWhiteSpace($LogPath)) {
        $LogPath = Join-Path $PSScriptRoot 'nightly.local.log'
    }
    # About 850 lines a night, so roughly 30 MB a year on a laptop that keeps this file for
    # ever. One rotation bounds it at two files without needing anything to tidy up.
    try {
        $existing = Get-Item -LiteralPath $LogPath -ErrorAction SilentlyContinue
        if ($existing -and $existing.Length -gt 5MB) {
            Move-Item -LiteralPath $LogPath -Destination ($LogPath + '.1') -Force
        }
    }
    catch { }

    # A log must never stop a pass. If the file cannot be opened the night still runs, and says
    # so where somebody watching would see it.
    try {
        [void](Start-Transcript -LiteralPath $LogPath -Append -ErrorAction Stop)
        $logStarted = $true
    }
    catch {
        Write-Host ("  the log at {0} could not be opened, so this pass leaves no record: {1}" -f `
                $LogPath, $_.Exception.Message) -ForegroundColor Yellow
    }
}

if (-not (Test-Path -LiteralPath $LedgerDir)) {
    Write-Host "No RUNS/ directory at $LedgerDir - nothing has been run yet." -ForegroundColor Yellow
    Stop-NightlyLog
    exit 0
}

# ----- choose -------------------------------------------------------------------------------

$ledgers = @()
foreach ($file in @(Get-ChildItem -LiteralPath $LedgerDir -Filter '*.json' | Sort-Object Name)) {
    try { $ledger = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json }
    catch {
        Write-Host ("  {0} could not be read and this sport is skipped: {1}" -f `
                $file.Name, $_.Exception.Message) -ForegroundColor Yellow
        continue
    }
    if ($null -eq $ledger -or [string]::IsNullOrWhiteSpace([string]$ledger.sport)) { continue }
    if ($Sport -and @($Sport) -notcontains [string]$ledger.sport) { continue }
    $ledgers += $ledger
}

if ($ledgers.Count -eq 0) {
    Write-Host 'No sport ledgers matched.' -ForegroundColor Yellow
    Stop-NightlyLog
    exit 0
}

$statePath = Get-NightlyStatePath
$state = Read-NightlyState -Path $statePath

# What the package still contains, which the ledgers cannot say. A ledger is never rewritten,
# so it goes on offering a check long after the registry retired it - and asking Run-Query for
# an id it no longer has fails the whole sport, not the one check. Read-NightlyApprovals owns
# the reasoning and the night it cost.
#
# A missing registry stops the pass rather than running it unfiltered. Running blind is how
# this failed the first time, and a checkout without POWERBI_REGISTRY.md is a broken checkout -
# not an occasion to send 957 statements at the production database and hope.
$registryPath = Join-Path $RepoRoot 'POWERBI_REGISTRY.md'
$approved = Read-NightlyApprovals -Path $registryPath
if ($null -eq $approved) {
    Write-Host ("POWERBI_REGISTRY.md not found at {0}. It says which checks still exist, so nothing is run without it." -f `
            $registryPath) -ForegroundColor Red
    Stop-NightlyLog
    exit 1
}

$selection = Select-NightlyChecks -Ledgers $ledgers -Legacy $SheetsStatusLegacy `
    -BudgetSeconds ($BudgetMinutes * 60) -LastRunAt $state.LastRunAt -Approved $approved

if (-not $Quiet) {
    Write-Host ("Nightly pass: {0} check(s) of {1} closed, about {2:n1} min of database time, budget {3:n0} min." -f `
            $selection.Checks.Count, $selection.Candidates,
            ($selection.Seconds / 60), $BudgetMinutes) -ForegroundColor Cyan
    if ($selection.Deferred -gt 0) {
        Write-Host ("  {0} check(s) did not fit and come round on a later night." -f `
                $selection.Deferred) -ForegroundColor DarkGray
    }
}

# Said whatever else is said, and said with -Quiet too. A ledger offering a check the registry
# has retired is a mismatch somebody has to resolve - the ledger is right about what ran and the
# registry is right about what exists - and the pass is the only place the two ever meet.
if (@($selection.Retired).Count -gt 0) {
    $byRetiredSport = @{}
    foreach ($entry in @($selection.Retired)) {
        $name = [string]$entry.Sport
        if (-not $byRetiredSport.ContainsKey($name)) { $byRetiredSport[$name] = @() }
        $byRetiredSport[$name] += $entry
    }
    Write-Host ("  {0} check(s) are closed in a ledger but no longer Approved in POWERBI_REGISTRY.md, and were not run:" -f `
            @($selection.Retired).Count) -ForegroundColor Yellow

    # Named, with a ceiling. Each id goes out with what it asserts, because a bare number asks
    # somebody to decide about a check they have not been told anything about - but a whole
    # sport's worth of them is a wall rather than a report. RUNS/BMX.json is why the ceiling is
    # here: it is the ledger of a sport that was split in two, so every one of its 62 closed
    # checks is retired at once and would print on one line every night.
    # -WhatIf is somebody looking at the selection by hand, so it names every one; a night
    # writing to a log nobody opens until something is wrong gets the first few.
    $cap = $(if ($WhatIf) { [int]::MaxValue } else { 6 })
    foreach ($name in @($byRetiredSport.Keys | Sort-Object)) {
        $entries = @($byRetiredSport[$name] | Sort-Object CheckId)
        $ids = @($entries | Select-Object -First $cap | ForEach-Object { '{0} {1}' -f $_.CheckId, $_.Name })
        $line = $ids -join '; '
        if ($entries.Count -gt $cap) {
            $line += (' - and {0} more, named in full by -WhatIf' -f ($entries.Count - $cap))
        }
        Write-Host ("    {0}: {1}" -f $name, $line) -ForegroundColor Yellow
    }
}

if ($selection.Checks.Count -eq 0) {
    Write-Host 'Nothing to run.' -ForegroundColor DarkGray
    Stop-NightlyLog
    exit 0
}

if ($WhatIf) {
    foreach ($sportName in @($selection.BySport.Keys | Sort-Object)) {
        $checks = @($selection.BySport[$sportName])
        $seconds = ($checks | Measure-Object -Property Seconds -Sum).Sum
        Write-Host ("  {0,-22} {1,3} check(s)  {2,6:n1}s" -f $sportName, $checks.Count, $seconds)
    }
    Write-Host 'Nothing was run: -WhatIf.' -ForegroundColor DarkGray
    exit 0
}

# ----- run ----------------------------------------------------------------------------------
#
# One sport at a time, because a board is per sport and a run that mixes them updates none. The
# checks go in as an explicit list, so -RunAll is not set and the merge treats the run as the
# partial one it is.
#
# A sport that fails does not end the pass. The rest of the night is still worth having, and a
# failure that stopped everything would mean one broken board silences fifteen others.

$ran = 0
$failed = @()
$clock = Get-Date

# The night's own identity, so that a failure queued for one pass is not queued again by the
# next. Add-NotifyEvent keys on the notification id and the id carries this, so a pass re-run by
# hand after a fix queues nothing for a sport it has already reported.
$runId = $clock.ToString('dd.MM.yyyy HH-mm-ss')
$startedUtc = $clock.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

foreach ($sportName in @($selection.BySport.Keys | Sort-Object)) {
    $checks = @($selection.BySport[$sportName])
    $ids = @($checks | ForEach-Object { [string]$_.CheckId })

    if (-not $Quiet) {
        Write-Host ("{0}: {1} check(s)" -f $sportName, $ids.Count) -ForegroundColor DarkGray
    }

    try {
        # -NoLedger, not -TestRun. The board is written, because that is the point; RUNS/ is
        # not, because a subset measured overnight is not a full run and sixteen ledger files
        # changing every night is about 29,000 lines a night in a repository that is in git.
        & $RunQuery $ids -Sport $sportName -Format table -Preview 0 -NoLedger | Out-Null
        $ran += $ids.Count
        $now = Get-Date
        foreach ($check in $checks) {
            $state.LastRunAt[(Get-NightlyKey -Sport $sportName -Entry $check)] = $now.ToUniversalTime()
        }
    }
    catch {
        # Named rather than counted, and the sport is left out of the state so its checks still
        # count as waiting. A night that quietly recorded a failed sport as done would take it
        # out of the rotation for as long as the failure lasted.
        $failed += [pscustomobject]@{
            Sport  = $sportName
            Reason = [string]$_.Exception.Message
            Checks = $ids.Count
        }
        Write-Host ("  {0} failed and its checks stay in the rotation: {1}" -f `
                $sportName, $_.Exception.Message) -ForegroundColor Yellow
    }
}

[void](Save-NightlyState -State $state -Path $statePath)

$elapsed = ((Get-Date) - $clock).TotalMinutes
Write-Host ("Nightly pass finished: {0} check(s) over {1} sport(s) in {2:n1} min." -f `
        $ran, ($selection.BySport.Keys.Count - $failed.Count), $elapsed) -ForegroundColor Cyan

# What the pass found is not reported here. A check it reopened was written to the board by the
# same rule a full run uses, and queued for notification there; TOOLS/Send-Notifications.ps1
# sends it at the next scheduled drain. One mechanism, one wording, whichever run noticed.
if ($failed.Count -gt 0) {
    Write-Host ("  {0} sport(s) failed: {1}" -f `
            $failed.Count, (@($failed | ForEach-Object { $_.Sport }) -join ', ')) -ForegroundColor Yellow

    # Queued, not sent. The pass has no address and no business having one: TOOLS/Notify.ps1
    # owns the queue and TOOLS/Send-Notifications.ps1 drains it at 07:00, which is the same
    # path a reopened check already takes. One mechanism, one place a message can be lost.
    #
    # This exists because the failure was silent. Six sports failed on the night of 2026-09-05
    # and again on the 06th and the 07th - 432 of 957 checks unwatched - and the only trace was
    # a line in a log and an exit code in Task Scheduler. A pass that cannot say it did not run
    # is a pass nobody can rely on, and the alarm has to reach a person rather than a file.
    try {
        $events = New-NotifyPassFailureEvent -RunId $runId -StartedUtc $startedUtc -Failures $failed
        $queuePath = Get-NotifyQueuePath
        $added = Add-NotifyEvent -Queue (Read-NotifyQueue -Path $queuePath) -Events $events
        [void](Save-NotifyQueue -Queue $added.Queue -Path $queuePath)
        Write-Host ("  {0} of them queued for the next notification drain." -f $added.Added) `
            -ForegroundColor DarkGray
    }
    catch {
        # A queue that will not open must not be the reason a pass reports success. It has
        # already failed; this only decides how loudly.
        Write-Host ("  the failure could not be queued for notification: {0}" -f `
                $_.Exception.Message) -ForegroundColor Yellow
    }

    Stop-NightlyLog
    exit 1
}
Stop-NightlyLog
exit 0
