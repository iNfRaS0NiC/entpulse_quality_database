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
    -RunAll here rather than being assembled from anything the sheet said. No cell ever reaches
    a shell.

    Anybody on requesters.allowed may ask for a whole-sport run; only the owner's approval lets
    one start. The approval is a Request ID in the "Run approvals" tab, which is protected with
    the owner as its only editor, so the authorisation is a write Google permits to one account
    rather than a check any of this could be talked out of. "Requested by" authorises nothing:
    every allowed account can edit the queue tab, so that cell is a claim. An unapproved
    whole-sport request is left WAITING rather than failed - it has not been turned down, only
    not yet read - and the requests behind it carry on running past it.

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
# Protected with the owner as its only editor, which is the whole of the whole-sport gate.
# `Run requests` lists every allowed account as an editor - a menu item runs as whoever
# clicked it, so it could not be otherwise - and that makes `Requested by` a claim anybody on
# the list can write. A Request ID in this tab is the one thing they cannot.
$ApprovalSheetName = 'Run approvals'
$WholeSportToken = '*SPORT*'
$RegistryPath = Join-Path $PSScriptRoot 'sheet-registry.json'
$RunQuery = Join-Path $PSScriptRoot 'Run-Query.ps1'
$RepoRoot = Split-Path -Parent $PSScriptRoot

# A loop over the boards is written `foreach ($board in ...)` and never `$sport`. Variable
# names in PowerShell are case-insensitive, so `$sport` is the `[string]$Sport` parameter, and
# a typed parameter constrains the variable for the whole scope: assigning a board object to it
# silently converts it to a string, and every property read off it is then empty. Measured
# 2026-09-01, where it showed as a 404 on a GET with no document id in the path.

# The columns as Add-RunRequestsTab.ps1 writes them: the name this script calls a column by,
# against the header text the tab actually carries. Order matters - it is the fallback layout
# for a tab whose header cannot be read - but the position is read off row 1 wherever one can
# be, because two columns were inserted into the middle of this list on 2026-09-01 and a
# worker counting from a fixed list would have written every status one column to the left of
# the header describing it.
$ColumnTitle = [ordered]@{
    RequestId      = 'Request ID'
    CheckId        = 'CheckID'
    CheckName      = 'Check name'
    RequestedBy    = 'Requested by'
    RequestedAt    = 'Requested at'
    Status         = 'Status'
    Progress       = 'Progress'
    StartedAt      = 'Started at'
    FinishedAt     = 'Finished at'
    RunId          = 'Run ID'
    Findings       = 'Findings'
    FindingsBefore = 'Findings before'
    Change         = 'Change'
    Eligible       = 'Eligible'
    Verdict        = 'Verdict'
    Error          = 'Error'
}

# One-based, because a Sheets A1 range is one-based and converting twice is how a status lands
# in the wrong cell.
$Column = @{}
$columnPosition = 1
foreach ($key in $ColumnTitle.Keys) {
    $Column[$key] = $columnPosition
    $columnPosition++
}

$OpenStatuses = @('QUEUED', 'WAITING', 'RUNNING')

# Said once per worker, not once per request: two clocks an hour apart are one fault.
$script:StampWarned = $false

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

    $all = @($Values)
    $at = Get-QueueColumnMap -Values $all

    $rows = @()
    for ($i = 1; $i -lt $all.Count; $i++) {
        $cells = @($all[$i])
        if ($cells.Count -eq 0) { continue }

        # $Index -ge 1 matters: at 0, $cells[$Index - 1] is $cells[-1], which in PowerShell is
        # the last element rather than an error - the Error column read as the Request ID.
        function Cell { param($Index) if ($Index -ge 1 -and $cells.Count -ge $Index) { [string]$cells[$Index - 1] } else { '' } }

        $requestId = (Cell $at.RequestId).Trim()
        if ([string]::IsNullOrWhiteSpace($requestId)) { continue }

        $rows += [pscustomobject]@{
            RowNumber   = $i + 1
            RequestId   = $requestId
            CheckId     = (Cell $at.CheckId).Trim()
            CheckName   = (Cell $at.CheckName).Trim()
            RequestedBy = (Cell $at.RequestedBy).Trim()
            RequestedAt = (Cell $at.RequestedAt).Trim()
            Status      = (Cell $at.Status).Trim().ToUpperInvariant()
            RunId       = (Cell $at.RunId).Trim()
        }
    }
    return $rows
}

function Get-QueueColumnMap {
    <#
        Where each column is on this particular tab, one-based and keyed the way this script
        names them.

        Read off row 1 of the values in hand rather than counted from $Column, so a tab that has
        gained a column - or has not gained one yet - is addressed as it actually is. $Column is
        the fallback, and it is only reached for a header this cannot read at all, which is a
        tab written by nothing and a case the caller will fail on anyway.

        Pure, and takes the values rather than a document, because everything that decides where
        a status gets written has to be exercisable without a login.
    #>
    param($Values)

    $map = @{}
    foreach ($key in $ColumnTitle.Keys) { $map[$key] = [int]$Column[$key] }

    $all = @($Values)
    if ($all.Count -eq 0) { return $map }

    $header = @($all[0])
    $seen = @{}
    for ($c = 0; $c -lt $header.Count; $c++) {
        $title = ([string]$header[$c]).Trim()
        if ($title) { $seen[$title] = $c + 1 }
    }
    if ($seen.Count -eq 0) { return $map }

    foreach ($key in @($ColumnTitle.Keys)) {
        $title = [string]$ColumnTitle[$key]
        if ($seen.ContainsKey($title)) { $map[$key] = [int]$seen[$title] }
        # 0 for a column this tab has not got. Never the position it would have had, and never
        # a neighbour's: a write to the wrong column succeeds and is wrong, which is the one
        # outcome worth going out of the way to make impossible.
        else { $map[$key] = 0 }
    }
    return $map
}

function Get-SheetRegistryFile {
    if (-not (Test-Path -LiteralPath $RegistryPath)) {
        throw "TOOLS/sheet-registry.json not found. It owns which document belongs to which sport, and who may ask."
    }
    return (Get-Content -LiteralPath $RegistryPath -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Get-WatchedSports {
    <#
        The documents to watch: every sport whose registry row has runRequests = true, narrowed
        to one by -Sport when it was given.

        A function rather than eight lines at startup, because the list is rebuilt while the
        worker runs. It used to be read once, and a sport registered afterwards stayed invisible
        until somebody restarted the process - which the scheduled task will not do on its own,
        MultipleInstances being IgnoreNew: every trigger spawns a process that bounces off the
        one already up and exits. Found on 2026-09-04 with a colleague's request sitting QUEUED
        on Speed-Skating against a worker that had been up since the previous evening watching
        Soccer alone.
    #>
    param($Registry, [string]$OnlySport)

    $list = @()
    foreach ($property in $Registry.sports.PSObject.Properties) {
        if (-not $property.Value.runRequests) { continue }
        if ($OnlySport -and $property.Name -ne $OnlySport) { continue }
        $list += [pscustomobject]@{ Name = $property.Name; SpreadsheetId = [string]$property.Value.spreadsheetId }
    }
    return @($list)
}

function Get-ApprovedCheckIds {
    <#
        Every CheckID POWERBI_REGISTRY.md records as Approved, with the sport it belongs to and
        what it asserts.

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
        # | CheckID | Sport | Family | Category | Object | Name | Query file | Status |
        $name = $cells[6].Trim()
        $status = $cells[8].Trim()
        $table[$checkId] = [pscustomobject]@{ Sport = $sport; Name = $name; Status = $status }
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
        $OpenRequests,
        # Request IDs the owner approved, from the tab only the owner can write. $null means the
        # board has no such tab; an empty array means it has one and this request is not in it.
        $WholeSportApprovals = $null
    )

    # Refused and held are different answers and the caller acts on them differently: a refusal
    # is final and lands in the Error cell as ERROR, a hold leaves the row WAITING for somebody
    # to decide. Collapsing the second into the first is what makes an approvable request
    # unapprovable, because it is marked failed before anyone has read it.
    function Refuse { param([string]$Why) return [pscustomobject]@{ Ok = $false; Pending = $false; Why = $Why; RunAll = $false; CheckId = '' } }
    function Hold { param([string]$Why) return [pscustomobject]@{ Ok = $false; Pending = $true; Why = $Why; RunAll = $false; CheckId = '' } }

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
        # Anybody on the list may ask for one; only the owner's approval lets it run. Until
        # 2026-09-03 this compared `Requested by` against the owner and called that the rule,
        # which it never was: every account on the list is an editor of `Run requests` - a menu
        # item runs as whoever clicked it, so the tab has to take their writes - and any of them
        # could type that cell. The cell is a claim. `Run approvals` is not.
        if (-not $isOwner -and $allowed -notcontains $requestedBy) {
            return (Refuse ("$requestedBy is not on the list of accounts that may ask for a run. " +
                    'Add it to requesters.allowed in TOOLS/sheet-registry.json.'))
        }

        if ($null -eq $WholeSportApprovals) {
            return (Refuse ("This board has no '$ApprovalSheetName' tab, so a whole-sport run " +
                    'cannot be authorised. Run .\TOOLS\Add-RunRequestsTab.ps1 -Sport ' + $Sport +
                    ' to create it; it is protected for the owner alone.'))
        }

        # Held rather than refused: an unapproved request is one the owner has not looked at
        # yet, not one they have turned down, and a row marked ERROR ninety seconds after it was
        # asked for cannot then be approved. The caller leaves it WAITING and takes the next
        # request, so a whole-sport row waiting for a decision does not hold up the single
        # checks behind it.
        if (@($WholeSportApprovals) -notcontains [string]$Request.RequestId) {
            return (Hold ("Waiting for the owner to approve it. Whole-sport runs are approved " +
                    "from the DQ menu, which records the Request ID in '$ApprovalSheetName' - the " +
                    'one tab the owner alone can write.'))
        }

        foreach ($open in @($OpenRequests)) {
            if ($open.RequestId -eq $Request.RequestId) { continue }
            if ($open.CheckId -eq $WholeSportToken) {
                return (Refuse 'A whole-sport run is already on the queue.')
            }
        }
        return [pscustomobject]@{ Ok = $true; Pending = $false; Why = ''; RunAll = $true; CheckId = $WholeSportToken }
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

    return [pscustomobject]@{ Ok = $true; Pending = $false; Why = ''; RunAll = $false; CheckId = $checkId }
}

# --------------------------------------------------------------------------------------
# Talking to the document
# --------------------------------------------------------------------------------------

function Test-RequestStampSane {
    <#
        Whether a request claims to have been made in the future.

        The board carries two clocks. `Requested at` is written by the Apps Script in the
        document's zone; `Started at` and `Finished at` are written here in the machine's. While
        those agree the row reads in order, and when they do not it reads as a run that finished
        before it was asked for - which is what the Soccer board showed on 2026-09-01, an hour
        out, because appsscript.json declared Europe/Sofia while the document and the machine
        were both Europe/Paris.

        That was found by a person reading a row, which is the wrong way to find it. This is the
        cheap check that would have said it on the first request: no zone arithmetic, no mapping
        of IANA names onto the Windows ones PowerShell 5.1 can resolve - just the symptom.

        Returns $true for a stamp this machine can believe. A stamp it cannot parse is believed:
        an unreadable cell is a different fault and not this one to report.
    #>
    param([string]$RequestedAt, [int]$ToleranceMinutes = 5)

    if ([string]::IsNullOrWhiteSpace($RequestedAt)) { return $true }

    $parsed = [datetime]::MinValue
    $ok = [datetime]::TryParseExact($RequestedAt.Trim(), 'dd.MM.yyyy HH:mm:ss',
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::None, [ref]$parsed)
    if (-not $ok) { return $true }

    return ($parsed -le (Get-Date).AddMinutes($ToleranceMinutes))
}

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

    # A1:Z and not A1:L. The tab was twelve columns wide until 2026-09-01 and is fifteen now;
    # Z leaves room for the next few without this being the line that has to be remembered.
    $range = [uri]::EscapeDataString("$QueueSheetName!A1:Z2000")
    $response = Invoke-SheetsApiWithRetry -Method GET -Path "$SpreadsheetId/values/$range"
    return (ConvertTo-RequestRows -Values $response.values)
}

function Read-WholeSportApprovals {
    <#
        Every Request ID the owner has approved for a whole-sport run, on one board.

        Returns $null when the tab is absent, and an array - possibly empty - when it is there.
        The two are different answers and the caller says so differently: a board with no tab
        needs one created, a board with a tab and no matching row has an unapproved request.
        Collapsing them into "not approved" would send somebody looking for an approval button
        on a document that has none.

        Read fresh each time it is needed, and needed only when a *SPORT* row is next. It is
        one extra request against a rare case, rather than a request every pass for a tab that
        is empty on almost every board.
    #>
    param([string]$SpreadsheetId)

    $range = [uri]::EscapeDataString("$ApprovalSheetName!A1:C1000")
    try {
        $response = Invoke-SheetsApiWithRetry -Method GET -Path "$SpreadsheetId/values/$range" `
            -What 'reading the whole-sport approvals'
    }
    catch {
        # Sheets answers a missing tab with 400, and there is no cheaper way to ask. Anything
        # else - a network fault, a revoked token - must not read as "no tab", because that
        # would turn a transport problem into a permanent refusal with the wrong advice on it.
        if ($_.Exception.Message -match '400') { return $null }
        throw
    }

    $ids = @()
    $rows = @($response.values)
    for ($i = 1; $i -lt $rows.Count; $i++) {
        $id = ([string]@($rows[$i])[0]).Trim()
        if (-not [string]::IsNullOrWhiteSpace($id)) { $ids += $id }
    }
    return @($ids)
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

    $range = [uri]::EscapeDataString("$QueueSheetName!A1:Z2000")
    $response = Invoke-SheetsApiWithRetry -Method GET -Path "$SpreadsheetId/values/$range"
    $rows = ConvertTo-RequestRows -Values $response.values
    $at = Get-QueueColumnMap -Values $response.values

    $row = @($rows | Where-Object { $_.RequestId -eq $RequestId })[0]
    if (-not $row) {
        Write-Host ("  request {0} is no longer on the tab, so nothing was written back" -f $RequestId) -ForegroundColor Yellow
        return
    }

    $data = @()
    foreach ($name in $Values.Keys) {
        $index = [int]$at[$name]
        if ($index -lt 1) {
            # The tab predates this column. Said rather than written somewhere else, and said
            # with the fix, because the row is otherwise correct and nobody would look.
            Write-Host ("  this board has no '{0}' column yet, so that figure was not written. " +
                "Run .\TOOLS\Add-RunRequestsTab.ps1 -Sport <Sport> to add it." -f `
                    $ColumnTitle[$name]) -ForegroundColor Yellow
            continue
        }
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

function Read-SharedText {
    <#
        A file another process is holding open for writing.

        Get-Content cannot: the child's redirected stdout handle denies the ordinary read, and
        the failure is an exception rather than an empty string. FileShare::ReadWrite is the
        whole of the fix - it says this reader accepts that the file is changing under it, which
        for a progress line is exactly true and exactly harmless.

        Returns '' rather than throwing. Progress is the least important thing this worker does,
        and a run must not fail because its own progress could not be read.
    #>
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    try {
        $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
        try {
            $reader = New-Object IO.StreamReader($stream)
            try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
        }
        finally { $stream.Dispose() }
    }
    catch { return '' }
}

# The runner's per-check line, and the one place its shape is written down. The progress note
# and the stall clock both read it, so they can never disagree about which check the run is on.
$Script:CheckLinePattern = '(?m)^\[(?<done>\d+)/(?<total>\d+)\]\s+(?<check>\S+)'

function Get-RunDoneCount {
    <#
        How many checks the runner has printed a line for, and nothing else.

        The stall clock needs this apart from the note. A note cannot say of itself that it has
        stopped changing, and the caller is the only thing that watches the same run twice.
        Zero for output with no line in it yet, which is the first half-minute of every run.
    #>
    param([string]$Output)

    $found = [regex]::Matches([string]$Output, $Script:CheckLinePattern)
    if ($found.Count -eq 0) { return 0 }
    return [int]$found[$found.Count - 1].Groups['done'].Value
}

function Get-RunProgress {
    <#
        How far a run has got, from the line the runner already prints for every check:

            [34/113] Soccer-DQ-052  rows=5  2.4s  OK

        Read from the last such line rather than counted, so a run that skipped checks is
        reported as the runner sees it and not as this function guesses.

        Empty for a run of one check. `1 of 1` tells a reader nothing they cannot see from the
        status, and an estimate over a single sample is not an estimate.

        The estimate is this run's own pace and nothing else - elapsed divided by what is done.
        Not the recorded durations in RUNS/<Sport>.json: that file is a record of what a run
        returned and nothing may be cited from it, and a board is the last place to start.
        It swings, because checks differ by a factor of a hundred, so it is offered as "about"
        and never as a time.
    #>
    param([string]$Output, [datetime]$Started, [datetime]$Now = (Get-Date),
        [datetime]$DoneSince = [datetime]::MinValue, [int]$StallSeconds = 120)

    $found = [regex]::Matches([string]$Output, $Script:CheckLinePattern)
    if ($found.Count -eq 0) { return '' }

    $last = $found[$found.Count - 1]
    $done = [int]$last.Groups['done'].Value
    $total = [int]$last.Groups['total'].Value
    if ($total -le 1 -or $done -le 0) { return '' }

    # The CheckID the run happens to be on is not in the note. It was, on the first live run,
    # and it made the column twice as wide for a name that has changed by the time anybody has
    # read it - the row it names is already finished. The count and the estimate are what the
    # question was.
    $note = '{0} of {1}' -f $done, $total

    # Every check has printed its line and the run has not exited, so what is left is the board
    # write. That is minutes on a board the size of Soccer, and the runner prints nothing at all
    # between its last check and its exit - so without this the count sits at its maximum and
    # the row reads as finished while the document is still being changed under the reader.
    #
    # Safe to say unconditionally, because this is only ever called while the process is alive.
    # The cell a finished run keeps is built from the tally further down and never from here.
    if ($done -ge $total) { return $note + ', writing the board' }

    # A check that runs for minutes freezes the count, and a frozen count is precisely what a
    # wedged run looks like from the outside. Measured on Soccer 2026-09-03: Soccer-DQ-080
    # PARTICIPANT_NO_PARTICIPATION_ANYWHERE - a player who appears in no event anywhere - took
    # 5 min 18 s of a 14-minute board refresh, 38 per cent of it inside one statement, and for
    # all of it the cell said 79 of 118 and nothing more. The clock is what tells a reader the
    # worker is alive; the estimate cannot, because it is the thing that stopped moving.
    #
    # Floored, never rounded. It is a measurement and not the estimate beside it, so it says
    # the smaller true number rather than the nearer one.
    if ($DoneSince -gt [datetime]::MinValue) {
        $stalled = ($Now - $DoneSince).TotalSeconds
        if ($stalled -ge $StallSeconds) {
            return $note + (', on one for {0} min' -f [int][math]::Floor($stalled / 60))
        }
    }

    $elapsed = ($Now - $Started).TotalSeconds
    if ($elapsed -le 0) { return $note }
    $remaining = ($elapsed / $done) * ($total - $done)
    if ($remaining -lt 60) { $note += ', under a minute left' }
    else { $note += ', about {0} min left' -f [int][math]::Round($remaining / 60) }
    return $note
}

function Get-RunCheckTally {
    <#
        How many checks the run attempted and how many of them failed, from the per-check line:

            [34/113] Soccer-DQ-052  rows=5  2.4s  OK
            [35/113] Soccer-DQ-053  rows=0  3.8s  ERROR: Unable to connect to the remote server

        This is the only honest way to tell a whole-sport run that did nothing from one that
        found nothing. A -RunAll prints no "N finding(s) of M eligible" sentence at all - that
        one belongs to a single re-run - so an empty Findings cell is its normal state, and a
        worker that read emptiness as failure would mark every successful board refresh ERROR.
        What separates them is the status on each line.

        Measured on Soccer 2026-09-03: a whole-sport request ran for 27 minutes with the API's
        TLS listener down, every check failed to connect, and the row was written DONE with
        empty figures - indistinguishable, to a reader, from a clean board.

        The seconds are matched loosely because the runner formats them for the machine's
        locale, and this one writes 2,4s rather than 2.4s.
    #>
    param([string]$Output)

    $lines = [regex]::Matches([string]$Output,
        '(?m)^\[(?<done>\d+)/(?<total>\d+)\]\s+(?<check>\S+)\s+rows=(?<rows>\S*)\s+[\d.,]+s\s+(?<status>.*)$')

    $total = 0
    $failed = 0
    $firstError = ''
    foreach ($line in $lines) {
        $total++
        $status = ([string]$line.Groups['status'].Value).Trim()
        if ($status -like 'ERROR*') {
            $failed++
            if (-not $firstError) {
                $firstError = '{0}: {1}' -f $line.Groups['check'].Value, $status
            }
        }
    }

    return [pscustomobject]@{
        Total      = $total
        Failed     = $failed
        FirstError = $firstError
        AllFailed  = ($total -gt 0 -and $failed -eq $total)
    }
}

function Get-RunDuration {
    <#
        What the whole thing took, for the cell to keep once it has stopped moving. A row that
        says only DONE cannot answer "was that quick?", which is the question asked next.
    #>
    param([datetime]$Started, [datetime]$Finished)

    $seconds = ($Finished - $Started).TotalSeconds
    if ($seconds -lt 90) { return '{0}s' -f [int][math]::Round($seconds) }
    return '{0} min' -f [int][math]::Round($seconds / 60)
}

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

        -Wait was dropped on 2026-09-03 so that the log can be read while it is being written.
        A whole-board refresh is about fifteen minutes, and for all of it the row said RUNNING
        and nothing else - which answers neither "how far" nor "how much longer", and is what a
        wedged run looks like too. OnProgress is handed each new line to write; the run does not
        depend on it, and a progress write that throws must never cost the run.
    #>
    param($Verdict, [string]$Sport, [scriptblock]$OnProgress, [int]$ProgressSeconds = 30)

    $arguments = @('-NoProfile', '-File', $RunQuery)
    if ($Verdict.RunAll) { $arguments += @('-Sport', $Sport, '-RunAll') }
    else { $arguments += @($Verdict.CheckId) }
    $arguments += @('-NoWait')

    $output = Join-Path ([IO.Path]::GetTempPath()) ('ep-request-{0}.log' -f ([guid]::NewGuid().ToString('N')))
    $started = Get-Date
    $process = Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -PassThru `
        -NoNewWindow -RedirectStandardOutput $output

    # Poll the log often and the document rarely. Reading a local file every three seconds costs
    # nothing; writing a cell is a Sheets request, so it is paid at most once per
    # -ProgressSeconds and only when the count has actually moved. A check that takes longer
    # than the interval therefore writes once, not five times.
    $lastNote = ''
    $lastWrite = [datetime]::MinValue
    $lastDone = -1
    $doneSince = $started
    while (-not $process.HasExited) {
        Start-Sleep -Seconds 3
        if (-not $OnProgress) { continue }

        # The count is sampled every pass, the cell written at most once per -ProgressSeconds.
        # Reading a local file costs nothing and the stall clock is only honest if it sees the
        # count move when it moves; sampling it at the write interval would report a check as
        # half a minute slower than it was.
        $text = Read-SharedText -Path $output
        $done = Get-RunDoneCount -Output $text
        if ($done -ne $lastDone) { $lastDone = $done; $doneSince = Get-Date }

        if (((Get-Date) - $lastWrite).TotalSeconds -lt $ProgressSeconds) { continue }

        $note = Get-RunProgress -Output $text -Started $started -DoneSince $doneSince
        if ([string]::IsNullOrWhiteSpace($note) -or $note -eq $lastNote) { continue }
        try { & $OnProgress $note } catch {
            Write-Host ("  progress could not be written: {0}" -f $_.Exception.Message) -ForegroundColor DarkGray
        }
        $lastNote = $note
        $lastWrite = Get-Date
    }
    $process.WaitForExit()

    $text = Read-SharedText -Path $output
    Remove-Item -LiteralPath $output -Force -ErrorAction SilentlyContinue

    return [pscustomobject]@{
        ExitCode = [int]$process.ExitCode
        Output   = [string]$text
        Started  = $started
        Finished = Get-Date
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
    $before = ''
    $change = ''

    $match = [regex]::Match($Output, '(?m)^\s*(?<verdict>[A-Za-z][A-Za-z ]*?):\s+(?<findings>\d+)\s+finding\(s\) of (?<eligible>\d+) eligible')
    if ($match.Success) {
        $verdict = $match.Groups['verdict'].Value.Trim()
        $findings = $match.Groups['findings'].Value
        $eligible = $match.Groups['eligible'].Value
    }

    # What the run before this one found, out of the same sentence: the runner already prints
    # "(was 11, run Soccer 01.09.2026 19-31-04)" for a single re-run, so the figure a reviewer
    # wants to compare against costs no read and cannot disagree with the console.
    #
    # The runner appends ", which ran a different statement" when the two runs did not execute
    # the same SQL. That is carried into the Change cell rather than dropped, because a delta
    # across a rewritten statement is not a delta - it is two different questions answered.
    $was = [regex]::Match($Output, '\(was (?<before>\d+), run (?<run>[^)]*)\)(?<rewritten>, which ran a different statement)?')
    if ($was.Success) {
        $before = $was.Groups['before'].Value
        if ($findings -ne '') {
            $delta = [int]$findings - [int]$before
            $change = $(if ($delta -gt 0) { '+' + $delta } else { [string]$delta })
            if ($was.Groups['rewritten'].Success) { $change += ' (different statement)' }
        }
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

    return [pscustomobject]@{
        Findings = $findings; Eligible = $eligible; Verdict = $verdict; RunId = $runId
        FindingsBefore = $before; Change = $change
    }
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

$sports = Get-WatchedSports -Registry $registry -OnlySport $Sport

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

# The same treatment for the list of documents. Add-RunRequestsTab.ps1 writes this file when a
# sport is set up, and until 2026-09-04 a worker already running never noticed - so setting a
# sport up was not enough, somebody also had to restart the worker, and nothing said so.
$sportsStamp = (Get-Item -LiteralPath $RegistryPath).LastWriteTimeUtc

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

    # And the documents, on the same terms. A sport set up mid-run joins the watch on the next
    # pass instead of waiting for a restart that the scheduled task cannot perform.
    try {
        $sportsNow = (Get-Item -LiteralPath $RegistryPath).LastWriteTimeUtc
        if ($sportsNow -ne $sportsStamp) {
            $before = @($sports | ForEach-Object { $_.Name })
            $sports = Get-WatchedSports -Registry (Get-SheetRegistryFile) -OnlySport $Sport
            $sportsStamp = $sportsNow
            $after = @($sports | ForEach-Object { $_.Name })
            $added = @($after | Where-Object { $before -notcontains $_ })
            $dropped = @($before | Where-Object { $after -notcontains $_ })
            $said = 'sheet-registry.json changed; watching {0}' -f $sports.Count
            if ($added.Count -gt 0) { $said += (', added ' + ($added -join ', ')) }
            if ($dropped.Count -gt 0) { $said += (', dropped ' + ($dropped -join ', ')) }
            Write-Host ('  ' + $said) -ForegroundColor DarkGray
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
                $saving = $(if ($sports.Count -gt 1) {
                        'one request rather than {0} reads' -f $sports.Count
                    }
                    else { 'one request whatever the number of boards' })
                Write-Host ('  Drive change queries are live; an idle pass costs ' + $saving) -ForegroundColor DarkGray
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

        $candidates = @($open | Where-Object { $_.Status -eq 'QUEUED' -or $_.Status -eq 'WAITING' })
        if ($candidates.Count -eq 0) { continue }

        # A whole-sport request the owner has not approved yet is held, not run and not failed,
        # and the queue steps over it. Held rather than taken in turn because it may wait for
        # hours: a request nobody has looked at must not stop the single checks behind it, and
        # the alternative - failing it after ninety seconds - makes an approvable request
        # impossible to approve.
        #
        # The tab is read once per pass and only when a *SPORT* row is actually open, which on
        # almost every board is never. An absent tab is not a hold: it can never be approved, so
        # it goes on to be refused with the sentence that says which script creates it.
        $held = @{}
        $approvals = $null
        $wholeSportOpen = @($candidates | Where-Object { $_.CheckId -eq $WholeSportToken })
        if ($wholeSportOpen.Count -gt 0) {
            $approvals = Read-WholeSportApprovals -SpreadsheetId $board.SpreadsheetId
            if ($null -ne $approvals) {
                foreach ($pending in $wholeSportOpen) {
                    if (@($approvals) -contains [string]$pending.RequestId) { continue }
                    $held[[string]$pending.RequestId] = $true
                    # Written once, on the way into WAITING. A worker up since Monday must not
                    # rewrite the same two cells every ninety seconds for a request nobody has
                    # got round to.
                    if ($pending.Status -ne 'WAITING' -and -not $WhatIf) {
                        Set-RequestCells -SpreadsheetId $board.SpreadsheetId -RequestId $pending.RequestId -Values @{
                            Status = 'WAITING'
                            Error  = "Waiting for the owner to approve it, in '$ApprovalSheetName'."
                        }
                        Write-Host ("  {0} {1}: held, waiting for the owner to approve a whole-sport run" -f `
                                $board.Name, $pending.RequestId) -ForegroundColor DarkGray
                    }
                }
            }
        }

        $next = @($candidates | Where-Object { -not $held.ContainsKey([string]$_.RequestId) })[0]
        if (-not $next) { continue }

        # Only what is ahead of it in the queue. A request is refused for duplicating an
        # earlier one, never for duplicating a later one: judged against the whole open set,
        # the oldest request loses to a *SPORT* somebody added underneath it a minute ago,
        # which is the queue running backwards. Row order is append order.
        #
        # Held rows are not ahead of anything. An unapproved whole-sport request would otherwise
        # be a whole-sport run in the eyes of the check behind it, and every single check on the
        # board would be refused for sitting behind a run that is not happening.
        $ahead = @($open | Where-Object {
                $_.RowNumber -lt $next.RowNumber -and -not $held.ContainsKey([string]$_.RequestId) })

        $verdict = Test-RequestAcceptable -Request $next -Sport $board.Name -Approved $approved `
            -Registry $registry -OpenRequests $ahead -WholeSportApprovals $approvals

        # A held request should have been stepped over above and never reach here. It is caught
        # anyway, because the cost of being wrong is a request marked failed that somebody was
        # about to approve, and ERROR is not a state the owner can approve their way out of.
        if (-not $verdict.Ok -and $verdict.Pending) {
            Write-Host ("  {0} {1}: held - {2}" -f $board.Name, $next.RequestId, $verdict.Why) -ForegroundColor DarkGray
            if (-not $WhatIf -and $next.Status -ne 'WAITING') {
                Set-RequestCells -SpreadsheetId $board.SpreadsheetId -RequestId $next.RequestId -Values @{
                    Status = 'WAITING'
                    Error  = $verdict.Why
                }
            }
            continue
        }

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

        if (-not (Test-RequestStampSane -RequestedAt $next.RequestedAt) -and -not $script:StampWarned) {
            # Once per worker. The row is still run - the clocks disagreeing says nothing about
            # whether the check should execute - but the board is showing a run that starts
            # before it was asked for, and nobody reading it would guess why.
            Write-Host ("  {0} says it was requested at {1}, which is ahead of this machine's clock. " +
                "The document's time zone and this machine's have drifted apart; the run is fine, " +
                "the row will read out of order." -f $next.RequestId, $next.RequestedAt) -ForegroundColor Yellow
            $script:StampWarned = $true
        }

        Write-Host ("  {0} {1}: running {2}" -f $board.Name, $next.RequestId, $label) -ForegroundColor Green

        if ($WhatIf) {
            $didSomething = $true
            continue
        }

        $starting = @{
            Status    = 'RUNNING'
            StartedAt = (Get-Date).ToString('dd.MM.yyyy HH:mm:ss')
            Progress  = ''
            Error     = ''
        }

        # The name the Apps Script could not find, or a row appended before the column existed.
        # Written at the start rather than at the end, because the whole point of it is to be
        # readable while the thing is running.
        if (-not $next.CheckName) {
            $known = $approved[$next.CheckId]
            if ($next.CheckId -eq $WholeSportToken) {
                $starting['CheckName'] = 'every approved check for this sport'
            }
            elseif ($known -and $known.Name) {
                $starting['CheckName'] = $known.Name
            }
        }

        Set-RequestCells -SpreadsheetId $board.SpreadsheetId -RequestId $next.RequestId -Values $starting

        # The progress cell, written while the run is still going. The closure captures what it
        # needs from this iteration; a failure inside it is swallowed by Invoke-RequestedRun,
        # because a run must not die of its own progress report.
        $boardId = $board.SpreadsheetId
        $requestId = $next.RequestId
        $reportProgress = {
            param([string]$Note)
            Set-RequestCells -SpreadsheetId $boardId -RequestId $requestId -Values @{ Progress = $Note }
        }.GetNewClosure()

        # Only a whole-sport run reports progress. A single check is a minute at most, so the
        # cell would be filled and emptied before anybody read it, and "1 of 1" answers a
        # question nobody asked. The owner's call, 2026-09-03, watching the first live one.
        $result = Invoke-RequestedRun -Verdict $verdict -Sport $board.Name `
            -OnProgress $(if ($WhatIf -or -not $verdict.RunAll) { $null } else { $reportProgress })

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
                Progress  = ''
                Error     = $reason
            }
            $didSomething = $true
            continue
        }

        $outcome = Get-RunOutcome -Output $result.Output
        $tally = Get-RunCheckTally -Output $result.Output
        $took = Get-RunDuration -Started $result.Started -Finished $result.Finished

        # A run whose every check failed exited 0 and was written DONE with empty figures, which
        # on the board is what a clean sport looks like. Only a positive count flips it: the
        # tally has to have seen checks and have seen all of them fail. Where nothing could be
        # parsed at all, the old behaviour stands, because guessing failure from silence would
        # mark a perfectly good run as broken.
        if ($result.ExitCode -eq 0 -and $tally.AllFailed) {
            $message = 'Every check failed. {0}' -f $(if ($tally.FirstError) { $tally.FirstError } else { 'See the worker log.' })
            if ($message.Length -gt 480) { $message = $message.Substring(0, 480) }

            Write-Host ("    {0} of {0} check(s) failed: {1}" -f $tally.Total, $tally.FirstError) -ForegroundColor Red
            Set-RequestCells -SpreadsheetId $board.SpreadsheetId -RequestId $next.RequestId -Values @{
                Status     = 'ERROR'
                FinishedAt = (Get-Date).ToString('dd.MM.yyyy HH:mm:ss')
                Progress   = '{0} of {0} failed, in {1}' -f $tally.Total, $took
                Error      = $message
            }
            $handled++
            $didSomething = $true
            continue
        }

        if ($result.ExitCode -ne 0) {
            $message = 'The run failed. See the worker log.'
            $failure = [regex]::Match($result.Output, '(?m)^(?<line>.*(ERROR|Exception|failed).*)$')
            if ($failure.Success) { $message = $failure.Groups['line'].Value.Trim() }
            if ($message.Length -gt 480) { $message = $message.Substring(0, 480) }

            Write-Host ("    failed: {0}" -f $message) -ForegroundColor Red
            Set-RequestCells -SpreadsheetId $board.SpreadsheetId -RequestId $next.RequestId -Values @{
                Status     = 'ERROR'
                FinishedAt = (Get-Date).ToString('dd.MM.yyyy HH:mm:ss')
                Progress   = $(if ($verdict.RunAll -and $tally.Total -gt 0) { '{0} of {1} done, in {2}' -f ($tally.Total - $tally.Failed), $tally.Total, $took } else { '' })
                Error      = $message
            }
        }
        else {
            $movement = $(if ($outcome.FindingsBefore -ne '') { ', was ' + $outcome.FindingsBefore } else { '' })
            Write-Host ("    done: {0} finding(s) of {1} eligible, {2}{3}" -f `
                    $outcome.Findings, $outcome.Eligible, $outcome.Verdict, $movement) -ForegroundColor DarkGray
            # What it came to, kept once it has stopped moving. A row saying only DONE cannot
            # answer "was that quick?", and a run where a few checks failed among many is worth
            # seeing without opening the workbook.
            $progress = ''
            if ($verdict.RunAll -and $tally.Total -gt 1) {
                $progress = '{0} of {1} in {2}' -f $tally.Total, $tally.Total, $took
                if ($tally.Failed -gt 0) {
                    $progress = '{0} of {1} in {2}, {3} failed' -f `
                        ($tally.Total - $tally.Failed), $tally.Total, $took, $tally.Failed
                }
            }

            $done = @{
                Status         = 'DONE'
                FinishedAt     = (Get-Date).ToString('dd.MM.yyyy HH:mm:ss')
                Progress       = $progress
                RunId          = $outcome.RunId
                Findings       = $outcome.Findings
                FindingsBefore = $outcome.FindingsBefore
                Change         = $outcome.Change
                Eligible       = $outcome.Eligible
                Verdict        = $outcome.Verdict
                Error          = ''
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
