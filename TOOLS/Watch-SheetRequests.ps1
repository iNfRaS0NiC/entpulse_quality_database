<#
.SYNOPSIS
    Run the checks reviewers ask for from their boards.

.DESCRIPTION
    Reads the "Run requests" tab on every registered document, takes the oldest request that
    is waiting, runs it, and writes back what it returned. One request at a time on the
    machine, one check per request, and nothing built out of a cell.

    What it will not do is the point of it. The Apps Script constrains the shape of a request;
    this enforces it, because a person with edit access could type into the tab directly. A
    CheckID has to match one known ID exactly - not a pattern, not a list, no wildcard, no
    comma, no second word. The reserved token *SPORT* is the single exception and maps to
    -RunAll here rather than being assembled from anything the sheet said; it is refused unless
    the requester is the owner recorded in TOOLS/sheet-registry.json, and refused outright
    while no owner is recorded. No cell ever reaches a shell.

    Each run is its own powershell.exe. That is what makes an interrupted worker safe: the run
    lock is a file handle, so a killed child releases it, and a request left RUNNING by a
    crash is returned to the queue at startup with the reason written into its Error cell.

    Rows are addressed by Request ID and never by row index. Two writers share this tab - the
    Apps Script appends, this updates - so the tab is re-read immediately before every write.

    This file stays pure ASCII, as the other TOOLS scripts do: Windows PowerShell 5.1 reads a
    .ps1 without a BOM as ANSI, so a literal em dash would arrive mojibaked and fail to parse.

.PARAMETER IntervalSeconds
    How long to wait between passes when there was nothing to do. Default 90.

    A pass costs one Sheets read per registered document, so the interval is what decides the
    idle cost of the whole system: at 30 seconds and sixteen boards it is 32 reads a minute
    against a documented per-user limit of 60, before a single request has been answered. 90
    seconds thirds that and costs a reviewer at most a minute and a half of waiting, which is
    the trade the owner chose on 2026-09-01 - the work is not that urgent.

    Since the same day that per-document cost is paid only by the documents that changed. One
    Drive query a pass names them, so an idle pass is one request whatever the number of
    boards, and the interval is no longer what a hundredth board would break. See
    -FullSweepPasses, which is what keeps that an optimisation rather than a risk.

.PARAMETER FullSweepPasses
    How often to read every registered document regardless of what Drive said. Default 10,
    which at the default interval is a full sweep every fifteen minutes. 1 disables the Drive
    pre-filter entirely and reads every board every pass, which is what this did before
    2026-09-01.

    The Drive pre-filter is a saving and never the correctness boundary. It depends on Drive's
    clock agreeing with this machine's and on a change having propagated by the time it is
    asked about, and if either fails it reports nothing changed - which is indistinguishable
    from nothing having changed. The sweep is what turns "a request is lost" into "a request
    waits at most fifteen minutes", and that is the whole reason it exists.

.PARAMETER Once
    One pass and stop, rather than running until it is stopped.

.PARAMETER Sport
    Only this document. Without it, every sport whose registry row has runRequests = true.

.PARAMETER MaxRequests
    Stop after this many requests have been handled. 0 is no limit.

.PARAMETER WhatIf
    Read the queue and say what would happen to each request. Runs nothing, writes nothing.

.PARAMETER DotSourceOnly
    Define the functions and stop. TOOLS/Test-Tools.ps1 uses it to exercise the validation
    without a document and without a login.

.EXAMPLE
    .\TOOLS\Watch-SheetRequests.ps1 -Once -WhatIf

.EXAMPLE
    .\TOOLS\Watch-SheetRequests.ps1
#>
[CmdletBinding()]
param(
    [int]$IntervalSeconds = 90,
    [ValidateRange(1, 1000)]
    [int]$FullSweepPasses = 10,
    [switch]$Once,
    [string]$Sport,
    [int]$MaxRequests = 0,
    [switch]$WhatIf,
    [string]$LogPath,
    [switch]$NoLog,
    [switch]$DotSourceOnly
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

. (Join-Path $PSScriptRoot 'Sheets.ps1')

$SecretsPath = Join-Path $PSScriptRoot 'secrets.local.ps1'
if (Test-Path -LiteralPath $SecretsPath) { . $SecretsPath }

$QueueSheetName = 'Run requests'
$WholeSportToken = '*SPORT*'
$RegistryPath = Join-Path $PSScriptRoot 'sheet-registry.json'
$RunQuery = Join-Path $PSScriptRoot 'Run-Query.ps1'
$RepoRoot = Split-Path -Parent $PSScriptRoot

# A loop over the boards is written `foreach ($board in ...)` and never `$sport`. Variable
# names in PowerShell are case-insensitive, so `$sport` is the `[string]$Sport` parameter, and
# a typed parameter constrains the variable for the whole scope: assigning a board object to it
# silently converts it to a string, and every property read off it is then empty. Measured
# 2026-09-01, where it showed as a 404 on a GET with no document id in the path.

# The columns as Add-RunRequestsTab.ps1 writes them, one-based, because a Sheets A1 range is
# one-based and converting twice is how a status lands in the wrong cell.
$Column = @{
    RequestId   = 1
    CheckId     = 2
    RequestedBy = 3
    RequestedAt = 4
    Status      = 5
    StartedAt   = 6
    FinishedAt  = 7
    RunId       = 8
    Findings    = 9
    Eligible    = 10
    Verdict     = 11
    Error       = 12
}

$OpenStatuses = @('QUEUED', 'WAITING', 'RUNNING')

# --------------------------------------------------------------------------------------
# Reading the queue
# --------------------------------------------------------------------------------------

function ConvertTo-RequestRows {
    <#
        The tab's values as objects, with the row number each came from.

        Pure, so the validation below can be exercised against rows somebody typed into a test
        rather than against a document. The row number is carried for the write, but a write is
        always preceded by a fresh read and a match on Request ID: a request appended while
        this was thinking shifts every row under it.
    #>
    param($Values)

    $rows = @()
    $all = @($Values)
    for ($i = 1; $i -lt $all.Count; $i++) {
        $cells = @($all[$i])
        if ($cells.Count -eq 0) { continue }

        function Cell { param($Index) if ($cells.Count -ge $Index) { [string]$cells[$Index - 1] } else { '' } }

        $requestId = (Cell $Column.RequestId).Trim()
        if ([string]::IsNullOrWhiteSpace($requestId)) { continue }

        $rows += [pscustomobject]@{
            RowNumber   = $i + 1
            RequestId   = $requestId
            CheckId     = (Cell $Column.CheckId).Trim()
            RequestedBy = (Cell $Column.RequestedBy).Trim()
            RequestedAt = (Cell $Column.RequestedAt).Trim()
            Status      = (Cell $Column.Status).Trim().ToUpperInvariant()
            RunId       = (Cell $Column.RunId).Trim()
        }
    }
    return $rows
}

function Get-SheetRegistryFile {
    if (-not (Test-Path -LiteralPath $RegistryPath)) {
        throw "TOOLS/sheet-registry.json not found. It owns which document belongs to which sport, and who may ask."
    }
    return (Get-Content -LiteralPath $RegistryPath -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Get-ApprovedCheckIds {
    <#
        Every CheckID POWERBI_REGISTRY.md records as Approved, with the sport it belongs to.

        Read from the registry file rather than from the SQL, because what a request may name
        is what is approved for a sport, and a Deprecated row keeps its ID for ever. Read once
        per pass: the file changes when somebody commits, not while a request is in flight.
    #>
    $path = Join-Path $RepoRoot 'POWERBI_REGISTRY.md'
    $table = @{}
    foreach ($line in @(Get-Content -LiteralPath $path)) {
        if ($line -notmatch '^\|\s*([A-Za-z][A-Za-z0-9.\-]*-DQ-\d+)\s*\|') { continue }
        $checkId = $Matches[1]
        $cells = @($line -split '\|')
        if ($cells.Count -lt 9) { continue }
        $sport = $cells[2].Trim()
        $status = $cells[8].Trim()
        $table[$checkId] = [pscustomobject]@{ Sport = $sport; Status = $status }
    }
    return $table
}

# --------------------------------------------------------------------------------------
# What may run
# --------------------------------------------------------------------------------------

function Test-RequestAcceptable {
    <#
        Whether one request may run, and what it would run.

        Every refusal returns a reason in the requester's words rather than a code, because the
        reason is written into the Error cell and read by the person who clicked.

        Pure: it takes the request, the sport whose document it came from, the approved-check
        table and the registry, and returns a verdict. Nothing here reaches a document, a
        database or a shell, which is what lets every refusal be a test.
    #>
    param(
        $Request,
        [string]$Sport,
        $Approved,
        $Registry,
        $OpenRequests
    )

    function Refuse { param([string]$Why) return [pscustomobject]@{ Ok = $false; Why = $Why; RunAll = $false; CheckId = '' } }

    $checkId = [string]$Request.CheckId
    $requestedBy = ([string]$Request.RequestedBy).Trim().ToLowerInvariant()

    # ----- who is asking ----------------------------------------------------------------
    $allowed = @()
    $owner = ''
    if ($Registry -and $Registry.PSObject.Properties.Name -contains 'requesters') {
        $allowed = @($Registry.requesters.allowed | ForEach-Object { ([string]$_).Trim().ToLowerInvariant() })
        $owner = ([string]$Registry.requesters.owner).Trim().ToLowerInvariant()
    }

    if ([string]::IsNullOrWhiteSpace($requestedBy)) {
        return (Refuse 'No requester recorded, so this was not asked for through the DQ menu.')
    }
    $isOwner = ($owner -ne '' -and $requestedBy -eq $owner)

    # ----- the whole sport, which is the owner's alone ----------------------------------
    #
    # Decided before the allowed list rather than after it, because a whole-sport run is
    # authorised by being the owner and never by being on that list. Read in the other order
    # it was, and a request made while no owner is recorded was refused as 'not on the list' -
    # true, useless, and pointing at the wrong file to fix.
    if ($checkId -eq $WholeSportToken) {
        if ([string]::IsNullOrWhiteSpace($owner)) {
            return (Refuse ('No owner is recorded in TOOLS/sheet-registry.json, so a whole-sport ' +
                    'run cannot be authorised. It is the one request that runs every check against ' +
                    'the production database.'))
        }
        if (-not $isOwner) {
            return (Refuse 'A whole-sport run is the owner''s to ask for. Use "Run this check" for one check.')
        }
        foreach ($open in @($OpenRequests)) {
            if ($open.RequestId -eq $Request.RequestId) { continue }
            if ($open.CheckId -eq $WholeSportToken) {
                return (Refuse 'A whole-sport run is already on the queue.')
            }
        }
        return [pscustomobject]@{ Ok = $true; Why = ''; RunAll = $true; CheckId = $WholeSportToken }
    }

    # ----- who is asking, for an ordinary check ------------------------------------------
    if (-not $isOwner -and $allowed -notcontains $requestedBy) {
        return (Refuse ("$requestedBy is not on the list of accounts that may ask for a run. " +
                "Add it to requesters.allowed in TOOLS/sheet-registry.json."))
    }

    # ----- one CheckID, and nothing that is not one -------------------------------------
    #
    # Shape before lookup, so a cell holding two IDs or a wildcard is refused in its own words
    # rather than as "unknown check". The pattern admits no space, comma, asterisk or path
    # separator, which is every way a second instruction could be smuggled into the cell.
    if ([string]::IsNullOrWhiteSpace($checkId)) {
        return (Refuse 'No CheckID in the request.')
    }
    if ($checkId -notmatch '^[A-Za-z][A-Za-z0-9.\-]*-DQ-\d{1,4}$') {
        return (Refuse ("`"$checkId`" does not read as one CheckID. One check at a time, by its " +
                'full ID - Soccer-DQ-023, not DQ-023, not a list and not a pattern.'))
    }

    if (-not $Approved.ContainsKey($checkId)) {
        return (Refuse "$checkId is not a CheckID this package knows.")
    }
    $row = $Approved[$checkId]

    if ($row.Sport -ne $Sport) {
        return (Refuse ("$checkId belongs to $($row.Sport), and this is the $Sport board. " +
                'A board runs only its own sport''s checks.'))
    }
    if ($row.Status -ne 'Approved') {
        return (Refuse "$checkId is $($row.Status) in POWERBI_REGISTRY.md, so it does not run.")
    }

    foreach ($open in @($OpenRequests)) {
        if ($open.RequestId -eq $Request.RequestId) { continue }
        if ($open.CheckId -eq $checkId) {
            return (Refuse "$checkId is already queued or running.")
        }
        if ($open.CheckId -eq $WholeSportToken) {
            return (Refuse 'A whole-sport run is on the queue and will run this check anyway.')
        }
    }

    return [pscustomobject]@{ Ok = $true; Why = ''; RunAll = $false; CheckId = $checkId }
}

# --------------------------------------------------------------------------------------
# Talking to the document
# --------------------------------------------------------------------------------------

function Select-BoardsToPoll {
    <#
        Which documents this pass reads, out of the ones being watched.

        Pure, and separate from the query that feeds it, because this is where the saving could
        turn into a lost request and that decision has to be testable without a login. Four
        answers, and three of them are "all of them":

          - the first pass has no baseline to compare against;
          - every FullSweepPasses-th pass, whatever Drive said, because the pre-filter can be
            wrong in the one direction that is silent - reporting no change when there was one -
            and a sweep bounds that to one interval times FullSweepPasses instead of for ever;
          - a pass where Drive could not answer. $null is "I do not know" and never "nothing
            changed"; reading them all is the honest reading of not knowing;
          - otherwise, only the documents Drive named.
    #>
    param(
        $Boards,
        # id -> modifiedTime, or $null when Drive could not answer.
        $ChangedIds,
        [int]$PassNumber,
        [int]$FullSweepPasses
    )

    if ($PassNumber -le 1) {
        return [pscustomobject]@{ Boards = @($Boards); Why = 'first pass'; Swept = $true }
    }
    if ($FullSweepPasses -le 1 -or ($PassNumber % $FullSweepPasses) -eq 0) {
        return [pscustomobject]@{ Boards = @($Boards); Why = 'full sweep'; Swept = $true }
    }
    if ($null -eq $ChangedIds) {
        return [pscustomobject]@{ Boards = @($Boards); Why = 'Drive could not say'; Swept = $true }
    }

    $picked = @($Boards | Where-Object { $ChangedIds.ContainsKey([string]$_.SpreadsheetId) })
    return [pscustomobject]@{ Boards = $picked; Why = 'changed on Drive'; Swept = $false }
}

function Read-RequestQueue {
    param([string]$SpreadsheetId)

    $range = [uri]::EscapeDataString("$QueueSheetName!A1:L2000")
    $response = Invoke-SheetsApiWithRetry -Method GET -Path "$SpreadsheetId/values/$range"
    return (ConvertTo-RequestRows -Values $response.values)
}

function Set-RequestCells {
    <#
        Write named columns of one request, found by its Request ID in a fresh read.

        Never by the row number carried from an earlier read. The Apps Script appends while
        this runs, and a row that moved under a stale index means one person's status written
        over another person's request.
    #>
    param(
        [string]$SpreadsheetId,
        [string]$RequestId,
        [hashtable]$Values
    )

    $rows = Read-RequestQueue -SpreadsheetId $SpreadsheetId
    $row = @($rows | Where-Object { $_.RequestId -eq $RequestId })[0]
    if (-not $row) {
        Write-Host ("  request {0} is no longer on the tab, so nothing was written back" -f $RequestId) -ForegroundColor Yellow
        return
    }

    $data = @()
    foreach ($name in $Values.Keys) {
        $index = [int]$Column[$name]
        $letter = [char]([int][char]'A' + $index - 1)
        $data += @{
            range  = "$QueueSheetName!$letter$($row.RowNumber)"
            values = @(, @($Values[$name]))
        }
    }

    [void](Invoke-SheetsApiWithRetry -Method POST -Path "$SpreadsheetId/values:batchUpdate" -Body @{
            valueInputOption = 'USER_ENTERED'
            data             = $data
        })
}

# --------------------------------------------------------------------------------------
# Running one
# --------------------------------------------------------------------------------------

function Invoke-RequestedRun {
    <#
        One request, in its own powershell.exe.

        Its own process on purpose. The run lock is a file handle, so a worker that is killed
        while a run is in flight leaves nothing locked; and a run that throws cannot take the
        worker down with it. The arguments are built from the validated verdict and never from
        the cell: a CheckID that reached here matched one known ID exactly, or is the one
        reserved token this maps to -RunAll itself.

        Exit code 75 is the run lock saying the machine is busy. That is not a failure and the
        request goes back to the queue as WAITING with the reason the lock printed.
    #>
    param($Verdict, [string]$Sport)

    $arguments = @('-NoProfile', '-File', $RunQuery)
    if ($Verdict.RunAll) { $arguments += @('-Sport', $Sport, '-RunAll') }
    else { $arguments += @($Verdict.CheckId) }
    $arguments += @('-NoWait')

    $output = Join-Path ([IO.Path]::GetTempPath()) ('ep-request-{0}.log' -f ([guid]::NewGuid().ToString('N')))
    $process = Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -PassThru -Wait `
        -NoNewWindow -RedirectStandardOutput $output

    $text = ''
    try { $text = Get-Content -LiteralPath $output -Raw -ErrorAction SilentlyContinue } catch { }
    Remove-Item -LiteralPath $output -Force -ErrorAction SilentlyContinue

    return [pscustomobject]@{
        ExitCode = [int]$process.ExitCode
        Output   = [string]$text
    }
}

function Get-RunOutcome {
    <#
        What the run said, read back out of what it printed.

        The runner already prints the sentence a reader wants - "New: 20 finding(s) of 27858
        eligible, expected Zero" - and the verdict word it chose. Taking them from there rather
        than re-deriving them keeps the sheet saying exactly what the console said, which is
        the thing somebody will compare it against.
    #>
    param([string]$Output)

    $findings = ''
    $eligible = ''
    $verdict = ''

    $match = [regex]::Match($Output, '(?m)^\s*(?<verdict>[A-Za-z][A-Za-z ]*?):\s+(?<findings>\d+)\s+finding\(s\) of (?<eligible>\d+) eligible')
    if ($match.Success) {
        $verdict = $match.Groups['verdict'].Value.Trim()
        $findings = $match.Groups['findings'].Value
        $eligible = $match.Groups['eligible'].Value
    }

    # A single run names itself on a `Run <Sport> dd.MM.yyyy HH-mm-ss` line, which is what the
    # ledger entry is keyed by; a batch is identified by the folder it wrote. Both are read,
    # the explicit name first, so a reader can find the entry either way.
    $runId = ''
    $named = [regex]::Match($Output, '(?m)^Run (?<name>.+?)\s*$')
    if ($named.Success) { $runId = $named.Groups['name'].Value.Trim() }
    else {
        $folder = [regex]::Match($Output, '(?m)Written:\s+(?<path>.+)$')
        if ($folder.Success) { $runId = Split-Path -Leaf ($folder.Groups['path'].Value.Trim()) }
    }

    return [pscustomobject]@{ Findings = $findings; Eligible = $eligible; Verdict = $verdict; RunId = $runId }
}

function Test-RunQueryAlive {
    <#
        Whether a Run-Query.ps1 is running on this machine right now.

        Asked before a RUNNING request is put back on the queue. A worker restarted while a
        run is still going - the service bounced, somebody started a second worker - would
        otherwise queue a request whose run is about to finish and write DONE over the top of
        it, and the reader would see one request run twice with no way to tell which figure
        belongs to which.

        Matched on the command line rather than on a stored PID, because the run this worker
        started is gone with the worker that started it and the one that matters is any run at
        all: the lock is machine-wide, so a second run cannot be in flight beside it.
    #>
    try {
        $running = @(Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction Stop |
            Where-Object { $_.CommandLine -like '*Run-Query.ps1*' -and $_.ProcessId -ne $PID })
        return ($running.Count -gt 0)
    }
    catch {
        # A machine that will not answer the question is treated as busy. Leaving a request
        # RUNNING costs a person clicking again; queueing one whose run is live costs a
        # duplicate nobody can untangle from the sheet.
        Write-Host ('  could not tell whether a run is in flight, so nothing was recovered this time: {0}' -f `
                $_.Exception.Message) -ForegroundColor Yellow
        return $true
    }
}

if ($DotSourceOnly) { return }

# --------------------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------------------

# ----- the log ---------------------------------------------------------------------------
#
# Start-Transcript rather than lines written by hand, for the reason Invoke-NightlyRun.ps1
# gives: most of what is worth keeping is printed by Run-Query in the child process, and a
# transcript captures the host. A worker that has been up for a week and refused something at
# three in the morning is otherwise a story nobody can reconstruct.
#
# The plan said RUNS/worker/<date>.log. It goes to TOOLS/worker.local.log instead, beside
# nightly.local.log: RUNS/ holds run ledgers and one .gitignore rule already covers *.local.log,
# and `.log` is outside the set Test-Package.ps1 scans, so nothing has an opinion about its bytes.

$logStarted = $false

function Stop-WorkerLog {
    if (-not $script:logStarted) { return }
    $script:logStarted = $false
    try { [void](Stop-Transcript) } catch { }
}

if (-not $NoLog -and -not $WhatIf) {
    if ([string]::IsNullOrWhiteSpace($LogPath)) { $LogPath = Join-Path $PSScriptRoot 'worker.local.log' }
    try {
        $existing = Get-Item -LiteralPath $LogPath -ErrorAction SilentlyContinue
        if ($existing -and $existing.Length -gt 5MB) {
            Move-Item -LiteralPath $LogPath -Destination ($LogPath + '.1') -Force
        }
    }
    catch { }

    # A log must never stop the worker. If the file cannot be opened it still runs, and says so
    # where somebody watching would see it.
    try {
        [void](Start-Transcript -LiteralPath $LogPath -Append -ErrorAction Stop)
        $logStarted = $true
    }
    catch {
        Write-Host ('  the log at {0} could not be opened, so this session leaves no record: {1}' -f `
                $LogPath, $_.Exception.Message) -ForegroundColor Yellow
    }
}

$registry = Get-SheetRegistryFile

$sports = @()
foreach ($property in $registry.sports.PSObject.Properties) {
    if (-not $property.Value.runRequests) { continue }
    if ($Sport -and $property.Name -ne $Sport) { continue }
    $sports += [pscustomobject]@{ Name = $property.Name; SpreadsheetId = [string]$property.Value.spreadsheetId }
}

if ($sports.Count -eq 0) {
    Write-Host ""
    if ($Sport) {
        Write-Host ("{0} is not set up for run requests. Deploy the Apps Script, then run " -f $Sport) -ForegroundColor Yellow
        Write-Host ("  .\TOOLS\Add-RunRequestsTab.ps1 -Sport {0} -Register" -f $Sport) -ForegroundColor Yellow
    }
    else {
        Write-Host "No document has runRequests = true in TOOLS/sheet-registry.json, so there is nothing to watch." -ForegroundColor Yellow
    }
    Stop-WorkerLog
    exit 0
}

Write-Host ""
Write-Host ("Watching {0}: {1}" -f $sports.Count, (($sports | ForEach-Object { $_.Name }) -join ', ')) -ForegroundColor Cyan
if ($WhatIf) { Write-Host "  -WhatIf: reading and reporting, running nothing." -ForegroundColor Yellow }

# ----- what a crash left behind -----------------------------------------------------------
#
# A request left RUNNING is one a worker was in the middle of when it stopped. Its run was its
# own process and went with it, and DQ statements are read-only, so putting it back on the
# queue costs a re-run and never a wrong write.
#
# Unless a run is still in flight. A worker restarted while one is going - the service bounced,
# a second worker started by hand - would otherwise queue a request whose run is about to write
# DONE over the top of it, and the sheet would show one request run twice with no way to tell
# which figure belongs to which. So the question is asked of the machine and not of the sheet.

if (-not $WhatIf) {
    $runInFlight = Test-RunQueryAlive
    if ($runInFlight) {
        Write-Host '  a run is in flight, so anything left RUNNING is left where it is' -ForegroundColor DarkGray
    }
    foreach ($board in $sports) {
        $stranded = @((Read-RequestQueue -SpreadsheetId $board.SpreadsheetId) | Where-Object { $_.Status -eq 'RUNNING' })
        foreach ($request in $stranded) {
            if ($runInFlight) {
                Write-Host ("  {0} is RUNNING and a run is in flight; leaving it alone" -f `
                        $request.RequestId) -ForegroundColor DarkGray
                continue
            }
            Write-Host ("  {0} was left RUNNING by an interrupted worker; returning it to the queue" -f `
                    $request.RequestId) -ForegroundColor Yellow
            Set-RequestCells -SpreadsheetId $board.SpreadsheetId -RequestId $request.RequestId -Values @{
                Status    = 'QUEUED'
                StartedAt = ''
                Error     = ('Recovered after an interruption at ' + (Get-Date).ToString('dd.MM.yyyy HH:mm:ss') + ' and queued again.')
            }
        }
    }
}

$handled = 0

# Re-read when the registry file changes, and not on a timer. A worker that has been up since
# Monday must not still be refusing a check approved on Tuesday, and must not re-parse 1882
# rows every thirty seconds to find that out.
$approved = Get-ApprovedCheckIds
$approvedStamp = (Get-Item -LiteralPath (Join-Path $RepoRoot 'POWERBI_REGISTRY.md')).LastWriteTimeUtc

# ----- the Drive pre-filter ----------------------------------------------------------------
#
# How far back each change query looks, past the moment the previous one was asked. This machine
# writes the window from its own clock and Google writes modifiedTime from its; a machine a
# minute fast would otherwise ask about a moment that has not happened yet and be told, quite
# correctly, that nothing has changed. Two minutes covers ordinary drift and costs one extra
# read of a board that did change, because a board only reappears in the window if it moved.
# Drift larger than this is caught by the full sweep and reported, not absorbed.
$DriveOverlapSeconds = 120

$pass = 0
$driveSince = (Get-Date).ToUniversalTime().AddSeconds(-$DriveOverlapSeconds)
$driveOff = $false            # said once, not every ninety seconds
$driveProved = $false         # the first answer is worth one line: it proves the scope is there
$flaggedSinceSweep = @{}      # what Drive named since the last full sweep, for the check below

while ($true) {
    $didSomething = $false
    $pass++

    try {
        $stamp = (Get-Item -LiteralPath (Join-Path $RepoRoot 'POWERBI_REGISTRY.md')).LastWriteTimeUtc
        if ($stamp -ne $approvedStamp) {
            $approved = Get-ApprovedCheckIds
            $approvedStamp = $stamp
            Write-Host ('  POWERBI_REGISTRY.md changed; {0} CheckID(s) now known' -f $approved.Count) -ForegroundColor DarkGray
        }
    }
    catch { }

    # One request that decides what the rest of the pass costs. Skipped when the pre-filter is
    # off, and on a pass that is going to sweep anyway - asking Drive to name what we are about
    # to read regardless is a request spent on nothing.
    $changed = $null
    $sweepDue = ($FullSweepPasses -le 1 -or $pass -le 1 -or ($pass % $FullSweepPasses) -eq 0)
    if (-not $sweepDue) {
        $asked = (Get-Date).ToUniversalTime()
        try {
            $changed = Get-DriveSpreadsheetsModifiedSince -Since $driveSince
            $driveSince = $asked.AddSeconds(-$DriveOverlapSeconds)
            foreach ($id in $changed.Keys) { $flaggedSinceSweep[$id] = $true }
            if (-not $driveProved) {
                # A missing scope is otherwise invisible: the worker keeps working, only slower,
                # and nothing says the saving never started. One line at startup says it did.
                Write-Host ('  Drive change queries are live; an idle pass is one request rather than {0}' -f `
                        $sports.Count) -ForegroundColor DarkGray
                $driveProved = $true
            }
            if ($driveOff) {
                Write-Host '  Drive is answering change queries again; back to reading only what moved' -ForegroundColor DarkGray
                $driveOff = $false
            }
        }
        catch {
            # A pass loses its saving and nothing else. Said once, because a worker that has
            # been up since Monday must not write the same line nine hundred times.
            $changed = $null
            if (-not $driveOff) {
                Write-Host ("  Drive could not say what changed, so every board is being read this " +
                    "pass and the next ones: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
                $driveOff = $true
            }
        }
    }

    $selection = Select-BoardsToPoll -Boards $sports -ChangedIds $changed `
        -PassNumber $pass -FullSweepPasses $FullSweepPasses

    foreach ($board in $selection.Boards) {
        $rows = @()
        try { $rows = Read-RequestQueue -SpreadsheetId $board.SpreadsheetId }
        catch {
            Write-Host ("  {0}'s queue could not be read this pass: {1}" -f $board.Name, $_.Exception.Message) -ForegroundColor Yellow
            continue
        }

        $open = @($rows | Where-Object { $OpenStatuses -contains $_.Status })

        # What the pre-filter would have cost. On a sweep, a board holding open work that no
        # change query has named since the last sweep is the pre-filter having been wrong in the
        # one direction that is silent. Once is the race between the last query and this sweep;
        # repeatedly is a clock or a scope, and it is the difference between a saving and a
        # request nobody answers.
        if ($selection.Swept -and $pass -gt 1 -and $FullSweepPasses -gt 1 -and -not $driveOff `
                -and $open.Count -gt 0 -and -not $flaggedSinceSweep.ContainsKey($board.SpreadsheetId)) {
            Write-Host ("  the sweep found open work on {0} that no Drive change query had named. " +
                "Once is the race between the two; repeatedly means the pre-filter is not seeing " +
                "changes, and -FullSweepPasses 1 turns it off." -f $board.Name) -ForegroundColor Yellow
        }

        $next = @($open | Where-Object { $_.Status -eq 'QUEUED' -or $_.Status -eq 'WAITING' })[0]
        if (-not $next) { continue }

        # Only what is ahead of it in the queue. A request is refused for duplicating an
        # earlier one, never for duplicating a later one: judged against the whole open set,
        # the oldest request loses to a *SPORT* somebody added underneath it a minute ago,
        # which is the queue running backwards. Row order is append order.
        $ahead = @($open | Where-Object { $_.RowNumber -lt $next.RowNumber })

        $verdict = Test-RequestAcceptable -Request $next -Sport $board.Name -Approved $approved `
            -Registry $registry -OpenRequests $ahead

        if (-not $verdict.Ok) {
            Write-Host ("  {0} {1}: refused - {2}" -f $board.Name, $next.RequestId, $verdict.Why) -ForegroundColor Yellow
            if (-not $WhatIf) {
                Set-RequestCells -SpreadsheetId $board.SpreadsheetId -RequestId $next.RequestId -Values @{
                    Status     = 'ERROR'
                    FinishedAt = (Get-Date).ToString('dd.MM.yyyy HH:mm:ss')
                    Error      = $verdict.Why
                }
            }
            # A refusal is a request handled. Counting only the runs made -MaxRequests unable
            # to stop on a queue of refusals, which is exactly the queue an acceptance session
            # stages.
            $handled++
            $didSomething = $true
            continue
        }

        $label = if ($verdict.RunAll) { "the whole $($board.Name) board" } else { $verdict.CheckId }

        # Everyone else waiting for the same check. Two people clicking the same row within a
        # minute is the ordinary case, not the awkward one, and it must cost one run: the second
        # request is not refused - it is answered with the same figures, because the check did
        # run and it ran for both of them. Collected before the run, because the queue moves.
        $companions = @($open | Where-Object {
                $_.RequestId -ne $next.RequestId -and $_.CheckId -eq $next.CheckId -and
                ($_.Status -eq 'QUEUED' -or $_.Status -eq 'WAITING')
            })
        if ($companions.Count -gt 0) {
            Write-Host ("    {0} other request(s) asked for the same check and will share this run" -f `
                    $companions.Count) -ForegroundColor DarkGray
        }

        Write-Host ("  {0} {1}: running {2}" -f $board.Name, $next.RequestId, $label) -ForegroundColor Green

        if ($WhatIf) {
            $didSomething = $true
            continue
        }

        Set-RequestCells -SpreadsheetId $board.SpreadsheetId -RequestId $next.RequestId -Values @{
            Status    = 'RUNNING'
            StartedAt = (Get-Date).ToString('dd.MM.yyyy HH:mm:ss')
            Error     = ''
        }

        $result = Invoke-RequestedRun -Verdict $verdict -Sport $board.Name

        if ($result.ExitCode -eq 75) {
            # The machine is busy, which is not this request's fault. Back on the queue with
            # the reason the lock printed, so the person watching sees what is ahead of them.
            $reason = 'The machine is busy with another run.'
            $waiting = [regex]::Match($result.Output, '(?m)the machine is already running (?<what>.+?), so this run was not started')
            if ($waiting.Success) { $reason = 'Waiting for ' + $waiting.Groups['what'].Value.Trim() + '.' }

            Write-Host ("    {0}" -f $reason) -ForegroundColor Yellow
            Set-RequestCells -SpreadsheetId $board.SpreadsheetId -RequestId $next.RequestId -Values @{
                Status    = 'WAITING'
                StartedAt = ''
                Error     = $reason
            }
            $didSomething = $true
            continue
        }

        $outcome = Get-RunOutcome -Output $result.Output

        if ($result.ExitCode -ne 0) {
            $message = 'The run failed. See the worker log.'
            $failure = [regex]::Match($result.Output, '(?m)^(?<line>.*(ERROR|Exception|failed).*)$')
            if ($failure.Success) { $message = $failure.Groups['line'].Value.Trim() }
            if ($message.Length -gt 480) { $message = $message.Substring(0, 480) }

            Write-Host ("    failed: {0}" -f $message) -ForegroundColor Red
            Set-RequestCells -SpreadsheetId $board.SpreadsheetId -RequestId $next.RequestId -Values @{
                Status     = 'ERROR'
                FinishedAt = (Get-Date).ToString('dd.MM.yyyy HH:mm:ss')
                Error      = $message
            }
        }
        else {
            Write-Host ("    done: {0} finding(s) of {1} eligible, {2}" -f `
                    $outcome.Findings, $outcome.Eligible, $outcome.Verdict) -ForegroundColor DarkGray
            $done = @{
                Status     = 'DONE'
                FinishedAt = (Get-Date).ToString('dd.MM.yyyy HH:mm:ss')
                RunId      = $outcome.RunId
                Findings   = $outcome.Findings
                Eligible   = $outcome.Eligible
                Verdict    = $outcome.Verdict
                Error      = ''
            }
            Set-RequestCells -SpreadsheetId $board.SpreadsheetId -RequestId $next.RequestId -Values $done

            foreach ($companion in $companions) {
                $shared = @{}
                foreach ($key in $done.Keys) { $shared[$key] = $done[$key] }
                $shared['Error'] = ('Answered by ' + $next.RequestId + ', which ran the same check.')
                Set-RequestCells -SpreadsheetId $board.SpreadsheetId -RequestId $companion.RequestId -Values $shared
                $handled++
            }
        }

        $handled++
        $didSomething = $true
    }

    # The window closes with the sweep that checked it, not with the pass that filled it.
    if ($selection.Swept) { $flaggedSinceSweep = @{} }

    if ($Once) { break }
    if ($MaxRequests -gt 0 -and $handled -ge $MaxRequests) {
        Write-Host ("Handled {0} request(s); stopping as asked." -f $handled) -ForegroundColor DarkGray
        break
    }
    if (-not $didSomething) { Start-Sleep -Seconds $IntervalSeconds }
}

Write-Host ""
Stop-WorkerLog
