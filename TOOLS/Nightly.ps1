# The nightly pass.
#
# A run every night across the opened sports whose only job is to notice that something which
# was clean has stopped being clean. It does not replace the full board and it never writes to
# one; it leaves no trace in RUNS/ either, so the next real run still compares against the last
# real one. See output/NIGHTLY_RUN_PLAN.md for the measurements the design rests on.
#
# Everything here is a pure function over what the ledgers already hold. Nothing in this file
# runs a statement, opens a connection or sends anything, which is what lets the selection be
# tested against sixteen real ledgers without a login.

# What a night is allowed to cost, in seconds of database time.
#
# A ceiling, not a target. Sixteen sports' whole closed set is 68 minutes, so today it binds on
# nothing; it starts binding at around 26 sports once the review has closed most of what is
# open, which is a handful of sports away rather than at the hundred everybody pictures. That
# is why the selector trims from the first day rather than having trimming added later.
$NightlyBudgetSeconds = 4.5 * 60 * 60

# The share of that budget kept for the checks cheapest-first would never reach.
#
# Sorting by cost alone means the expensive closed checks are never seen between full boards:
# 43 of them today, 22 minutes, more than half of it Comp.Rank. A reserved slice spent on the
# least recently run means each comes round every few nights instead of never.
$NightlyRotationShare = 0.15

# The reviewer's words under which a check is worth running at night.
#
# All three are conclusions a result can contradict. `Clean` says it returns nothing and
# `Completed` says the findings were dealt with - a run that returns rows disproves either.
# `Reopened` is already disproved and stays in because the run is what will show it fixed.
#
# What is left out is left out for a reason rather than by omission. `Not reviewed` and a blank
# cell carry no conclusion to contradict, so a row appearing there is news to nobody in
# particular. `On Hold`, `IT Fix` and `Other Team` are waiting on somebody who is not the
# reviewer. `Monitor Only` expects a count for ever. `Skipped` and `Deprecated` are out of the
# reading altogether. Decided 2026-09-01, and measured first: of the four handed-off words only
# one check in the whole package is both handed off and closed, so this filter costs nothing
# against them and exists for the two that matter.
$NightlyReviewStatuses = @('Clean', 'Completed', 'Reopened')

function Get-NightlyLedgerState {
    <#
        The latest thing every check in a sport is known to have done, and the last word a
        reviewer put on it.

        Walked forward so the newest entry wins, which is what Import-PreviousRunEntries in
        Run-Query.ps1 does and for the same reason: a run that failed or was skipped is passed
        over rather than recorded, because comparing against an error says nothing and the
        reading anybody wants is against the last time the check produced a number.

        The reviewer's status is taken the same way but from a different place - the run's
        `review` block, which Save-RunSheet writes from what the board held when the run read
        it. That makes it the status **as of the last board run**, not a live one. A status
        somebody changed this morning is not here until the next board, and the selector says
        so rather than pretending otherwise.
    #>
    param($Ledger)

    $state = @{}
    foreach ($run in @($Ledger.runs)) {
        $review = $run.review
        foreach ($check in @($run.checks)) {
            $key = [string]$check.runKey
            if ([string]::IsNullOrWhiteSpace($key)) { $key = [string]$check.checkId }
            if ([string]::IsNullOrWhiteSpace($key)) { continue }

            $status = [string]$check.status
            if ($status -like 'ERROR*' -or $status -like 'SKIPPED*') { continue }
            if ($null -eq $check.findings) { continue }

            $reviewStatus = ''
            if ($review -and $review.PSObject.Properties.Name -contains $check.checkId) {
                $reviewStatus = ([string]$review.$($check.checkId).status).Trim()
            }
            elseif ($state.ContainsKey($key)) {
                # A run that carried no review block - a narrowed re-run, say - must not erase
                # what the last board knew. The measurement is newer; the reviewer's word is not.
                $reviewStatus = [string]$state[$key].ReviewStatus
            }

            $state[$key] = [pscustomobject]@{
                CheckId      = [string]$check.checkId
                RunKey       = $key
                Name         = [string]$check.name
                Findings     = [int]$check.findings
                Eligible     = $(if ($null -eq $check.eligible) { 0 } else { [int]$check.eligible })
                Expected     = [string]$check.expected
                Signal       = [string]$check.signal
                Seconds      = $(if ($null -eq $check.seconds) { 0.0 } else { [double]$check.seconds })
                SqlHash      = [string]$check.sqlHash
                ReviewStatus = $reviewStatus
                RunId        = [string]$run.runId
                StartedUtc   = [string]$run.startedUtc
            }
        }
    }
    return $state
}

function Test-NightlyCandidate {
    <#
        Whether one check is worth running tonight.

        Only a check that is currently closed can newly fire. A check already returning
        findings is already open on the board and in front of whoever is reviewing it; running
        it again tonight tells nobody anything they are not already looking at. So the nightly
        pass is a selection problem rather than a narrowing one, and this is the selection.

        `eligible_count` above zero matters as much as findings of zero. A check over an empty
        population returns nothing every night for a reason that has nothing to do with the
        data being right, and its day comes when the population arrives - which a full board
        will see.
    #>
    param($Entry, [string[]]$Statuses = $NightlyReviewStatuses, $Legacy)

    if ($null -eq $Entry) { return $false }
    if ([string]$Entry.Expected -ne 'Zero') { return $false }
    if ([int]$Entry.Findings -ne 0) { return $false }
    if ([int]$Entry.Eligible -le 0) { return $false }

    $status = [string]$Entry.ReviewStatus
    if ($Legacy -and $Legacy.ContainsKey($status)) { $status = [string]$Legacy[$status] }
    return ($Statuses -contains $status)
}

function Select-NightlyChecks {
    <#
        Tonight's checks, sport by sport, and what they are expected to cost.

        **Computed, never written down.** A frozen list of CheckIDs rots: a check that reopens
        stays in it after somebody has fixed the data, a new sport joins the package and is not
        in it, and a check that reopens tonight would be run again tomorrow for nothing. A
        frozen *threshold* rots the same way, which is why this takes a budget rather than a
        number of seconds - as sports accumulate the effective ceiling falls on its own, in the
        order the cost table says to give things up in.

        Cheapest first, then a reserved slice for the expensive tail by least recently run. The
        rotation is not decoration: without it the costly closed checks are invisible between
        full boards, and more than half of that cost is the Comp.Rank layer.

        Timing comes from the ledger, so the cost model tracks the database rather than a guess
        made once.
    #>
    param(
        $Ledgers,
        [double]$BudgetSeconds = $NightlyBudgetSeconds,
        [double]$RotationShare = $NightlyRotationShare,
        [string[]]$Statuses = $NightlyReviewStatuses,
        $Legacy,
        [datetime]$Now = (Get-Date),
        $LastRunAt
    )

    $candidates = @()
    foreach ($ledger in @($Ledgers)) {
        if ($null -eq $ledger) { continue }
        $sport = [string]$ledger.sport
        $state = Get-NightlyLedgerState -Ledger $ledger
        foreach ($key in @($state.Keys)) {
            $entry = $state[$key]
            if (-not (Test-NightlyCandidate -Entry $entry -Statuses $Statuses -Legacy $Legacy)) { continue }
            $entry | Add-Member -NotePropertyName Sport -NotePropertyValue $sport -Force
            $candidates += $entry
        }
    }

    # Sorted by cost, and by CheckID within the same cost so two nights with the same ledgers
    # choose the same checks. A selector whose output moves without its input moving cannot be
    # tested and cannot be explained to anybody looking at two mornings' mail.
    $ordered = @($candidates | Sort-Object @{ Expression = 'Seconds' }, @{ Expression = 'Sport' }, @{ Expression = 'CheckId' })

    $rotationBudget = $BudgetSeconds * $RotationShare
    $mainBudget = $BudgetSeconds - $rotationBudget

    $taken = @()
    $skipped = @()
    $spent = 0.0
    foreach ($entry in $ordered) {
        if (($spent + $entry.Seconds) -le $mainBudget) {
            $taken += $entry
            $spent += $entry.Seconds
        }
        else { $skipped += $entry }
    }

    # The tail, least recently run first. A check nothing has recorded a nightly run for is
    # oldest by definition and goes first, which is what makes the first few nights sweep the
    # whole tail rather than the same corner of it.
    $rotated = @()
    if ($skipped.Count -gt 0 -and $rotationBudget -gt 0) {
        $seen = @{}
        if ($LastRunAt) {
            foreach ($key in @($LastRunAt.Keys)) { $seen[[string]$key] = $LastRunAt[$key] }
        }
        $byAge = @($skipped | Sort-Object @{ Expression = {
                    $key = '{0}|{1}' -f $_.Sport, $_.RunKey
                    if ($seen.ContainsKey($key)) { [datetime]$seen[$key] } else { [datetime]::MinValue }
                }
            }, @{ Expression = 'Seconds' }, @{ Expression = 'CheckId' })

        # The share reserves; the remainder is available. Cheapest-first stops when the next
        # check does not fit, which leaves the main pass holding time it cannot spend - and a
        # budget is a ceiling rather than an allocation, so that time goes to the tail instead
        # of being discarded. What the share guarantees is the other direction: main is capped
        # below the budget, so the tail gets a slice even on a night main could fill by itself.
        $allowance = $BudgetSeconds - $spent
        $rotationSpent = 0.0
        foreach ($entry in $byAge) {
            if (($rotationSpent + $entry.Seconds) -gt $allowance) { continue }
            $rotated += $entry
            $rotationSpent += $entry.Seconds
        }
    }

    $selected = @($taken) + @($rotated)
    $bySport = @{}
    foreach ($entry in $selected) {
        if (-not $bySport.ContainsKey($entry.Sport)) { $bySport[$entry.Sport] = @() }
        $bySport[$entry.Sport] += $entry
    }

    return [pscustomobject]@{
        Checks     = $selected
        BySport    = $bySport
        Candidates = $candidates.Count
        Seconds    = ($selected | Measure-Object -Property Seconds -Sum).Sum
        Deferred   = @($skipped | Where-Object { $rotated -notcontains $_ }).Count
        Budget     = $BudgetSeconds
    }
}

# ----- the record of what the nights have done ------------------------------------------
#
# Two things have to survive from one night to the next, and neither belongs in RUNS/.
#
# The ledger is the record of full runs and is in git; a nightly pass writes nothing there on
# purpose, so that the next real run still compares against the last real one and so that
# sixteen files do not change every night in a repository nobody would be committing them to.
# What is kept here is one thing: when each check last ran at night, so the rotation moves
# through the expensive tail rather than sweeping the same corner of it.
#
# It held what the last night found as well until 2026-09-01, so that a check firing on Monday
# was not reported again on Tuesday. That belongs to the board rather than here: a check the
# night writes to `Reopened` is no longer `Clean` or `Completed`, so the next night's run
# cannot reopen it again and no second message is possible. The rule that made the duplicate
# impossible was already written, and keeping a second copy of it here would have been a
# second thing to keep true.
#
# It is local and ignored by git under the same rule as the credentials beside it. Losing it
# costs a rotation that starts again from the cheapest, which is what the first night does
# anyway.
$NightlyStateFileName = 'nightly.local.json'
$NightlyStateVersion = 1

function Get-NightlyStatePath {
    param([string]$Root = $PSScriptRoot)
    if ([string]::IsNullOrWhiteSpace($Root)) { $Root = '.' }
    return (Join-Path $Root $NightlyStateFileName)
}

function Read-NightlyState {
    <#
        What the previous nights recorded, or an empty state.

        A missing file is the first night and is not a fault. A file that will not parse is
        reported and treated as empty rather than thrown: the alternative is a local file
        ending a pass that has not run anything yet, and the cost of being wrong is one
        repeated message.
    #>
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { $Path = Get-NightlyStatePath }
    $empty = [pscustomobject]@{ LastRunAt = @{} }
    if (-not (Test-Path -LiteralPath $Path)) { return $empty }

    try {
        $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($raw)) { return $empty }
        $parsed = $raw | ConvertFrom-Json
    }
    catch {
        Write-Host ("  the nightly state at {0} could not be read and is being treated as empty: {1}" -f `
                $Path, $_.Exception.Message) -ForegroundColor Yellow
        return $empty
    }

    $lastRunAt = @{}
    if ($parsed.PSObject.Properties.Name -contains 'lastRunAt' -and $parsed.lastRunAt) {
        foreach ($property in @($parsed.lastRunAt.PSObject.Properties)) {
            $lastRunAt[[string]$property.Name] = $property.Value
        }
    }
    return [pscustomobject]@{ LastRunAt = $lastRunAt }
}

function Save-NightlyState {
    # Written whole, in the shape Read-NightlyState expects. Keys are 'Sport|RunKey', because a
    # CheckID is unique within a sport and a run key carries the parameters a narrowed check
    # was run under.
    param($State, [string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { $Path = Get-NightlyStatePath }
    $document = [pscustomobject]@{
        stateVersion = $NightlyStateVersion
        lastRunAt    = [pscustomobject]@{}
    }
    foreach ($key in @($State.LastRunAt.Keys)) {
        $value = $State.LastRunAt[$key]
        $text = $(if ($value -is [datetime]) {
                $value.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
            } else { [string]$value })
        $document.lastRunAt | Add-Member -NotePropertyName ([string]$key) -NotePropertyValue $text -Force
    }
    # Written without a byte order mark. Set-Content -Encoding UTF8 emits one on Windows
    # PowerShell 5.1, and the package forbids them - Test-Package.ps1 failed on this very file
    # the first time it was written. The same call Connect-Sheets.ps1 uses for the same reason.
    [IO.File]::WriteAllText($Path, ($document | ConvertTo-Json -Depth 6),
        (New-Object Text.UTF8Encoding $false))
    return $Path
}

function Get-NightlyKey {
    # One check, in one sport. The run key rather than the CheckID because a narrowed check
    # carries its parameters in it, and two narrowings of the same check are two measurements.
    param([string]$Sport, $Entry)

    $key = [string]$Entry.RunKey
    if ([string]::IsNullOrWhiteSpace($key)) { $key = [string]$Entry.CheckId }
    return ('{0}|{1}' -f $Sport, $key)
}
