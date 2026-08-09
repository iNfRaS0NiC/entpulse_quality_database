<#
.SYNOPSIS
    The live per-sport Google Sheet: what a run writes into it, and what it must not touch.

.DESCRIPTION
    Run-Query.ps1 dot-sources this file. It holds no network code and sends nothing: given
    what a run produced and what the document already contains, it computes the list of
    operations that would bring the document up to date. Turning that list into API calls is
    the transport's job, and it is deliberately separate - the merge is where the defects
    live, and a merge that needs a login to test is a merge nobody tests.

    The document is permanent and one per sport. Every earlier design wrote a new file per
    run, which is why reviewer comments died with each one; the point of this file is that
    they do not, so every rule below is about leaving somebody else's cells alone.

    This file stays pure ASCII, as the other TOOLS scripts do: Windows PowerShell 5.1 reads a
    .ps1 without a BOM as ANSI, so a literal em dash would arrive mojibaked and fail to parse.
#>

$SheetsApiRoot = 'https://sheets.googleapis.com/v4/spreadsheets'
$SheetsTokenUrl = 'https://oauth2.googleapis.com/token'
$SheetsScope = 'https://www.googleapis.com/auth/spreadsheets'

# The title Google gives a spreadsheet nobody has named. The runner names the document while
# it still reads exactly this, and never over a title somebody chose: a colleague who renames
# it has decided something, and an instrument that quietly puts its own name back every week
# is the same defect as one that overwrites a comment.
$SheetsUntitled = 'Untitled spreadsheet'

# Titles this runner has given documents in the past. A document still carrying one of these
# is wearing a name nobody chose, so a change to the naming pattern reaches it. Add the old
# pattern here whenever the pattern changes; nothing else may go in this list.
$SheetsFormerTitles = @('Enetpulse DQ - *')

# Rows per write request. A single 20 000-row block is megabytes of JSON in one body, which is
# slow to build, slow to send and all-or-nothing if it fails.
$SheetsWriteChunk = 2000

$script:SheetsAccessToken = ''
$script:SheetsTokenExpiry = [datetime]::MinValue

# How far the last document update got. The phases have to be sent in order - a tab before a
# range names it, a clear before the rows that replace it - so a failure in a later one leaves
# the earlier ones applied. Without this the run reports "the document was not updated" for a
# document that was, which is the wrong thing to tell somebody deciding whether to look at it.
$script:SheetsStage = ''

function Set-SheetsAddressFamily {
    <#
        Refuse IPv6 for a host whose IPv6 is dead.

        sheets.googleapis.com resolves to eight IPv6 addresses before its first IPv4 one, and
        on a network that cannot route 2001:4860::/32 every one of them has to time out before
        .NET Framework tries IPv4. It has no Happy Eyeballs: the addresses are walked in order,
        each waiting out its own connect timeout. Measured here, the first request to the host
        took 168 seconds and every request after it 207 milliseconds, because by then the
        connection was established and pooled.

        The fix is the bind delegate, and which of its two forms is used matters. Returning a
        mismatched local endpoint for an IPv6 remote reads as a failed bind and .NET retries the
        same address, which is slower than doing nothing - it ran past seven minutes. Throwing
        makes it abandon that address and move to the next, and the same first request then
        takes three seconds.

        This is a workaround for a network fault rather than a fix for one. If the IPv6 route
        starts working, or IPv6 is disabled on the adapter, this becomes a no-op that costs
        nothing.
    #>
    param([string]$Uri)

    $point = [Net.ServicePointManager]::FindServicePoint([Uri]$Uri)
    if ($point.BindIPEndPointDelegate) { return }
    $point.BindIPEndPointDelegate = {
        param($servicePoint, $remoteEndPoint, $retryCount)
        if ($remoteEndPoint.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetworkV6) {
            throw (New-Object InvalidOperationException 'IPv6 refused for this host')
        }
        return $null
    }
}

# How many result rows one check may put in the live document. The hard limit is Google's, at
# 10 million cells per spreadsheet, and it is a document budget rather than a per-tab one: a
# sport is around fifty checks in one permanent file, so a single six-figure check can take a
# sixth of the document by itself. Sheets also becomes slow to open and scroll well before
# the limit, and writing that many cells over the API costs minutes per run.
#
# Re-derived from a run of all six documented sports on 2026-08-08 - 496 checks, no failures -
# rather than left at the 20 000 first guessed here. What that measured:
#
#   largest single check   Curling-DQ-041, 17 626 rows
#   largest sport in total Curling, 79 523 rows over 105 checks, about 636 000 cells
#   six-figure results     none, under each sport's documented scope
#
# So the first guess was tight in the wrong place. Three Curling checks sat within 12% of it,
# where one heavier import would have started truncating a legitimate result - while the
# document it was protecting was at 6.4% of Google's limit, with room to spare by an order of
# magnitude.
#
# 50 000 is roughly three times the largest count seen and still only about 4% of a document
# for one check, so the guard against a genuinely pathological result survives without
# threatening anything real. Worth re-deriving again if a sport is ever run outside its
# documented scope: Soccer sport-wide is the known six-figure case, and it does not arise
# under the 28 client templates SPORTS/Soccer.md scopes it to.
$SheetsMaxRowsPerCheck = 50000

# When the whole document would pass this, the run says so. A warning rather than a truncation
# because the answer is a decision - drop a check from the document, tighten a scope, split
# the sport - and none of those is the runner's to make silently.
$SheetsCellBudgetWarning = 8000000

# The columns on the live Overview, in order, matching the workbook so the two read alike.
$SheetsOverviewColumns = @(
    'Sport', 'CheckID', 'Parameters', 'Check Name', 'Priority', 'Category', 'What it does',
    'Rows', 'Status', 'Check By', 'Comment', 'Signal', 'Signal reason',
    'Expected', 'Findings', 'Eligible', 'Prev findings', 'Prev eligible', 'Change',
    'Verdict', 'Last run', 'Trends')

# Row 1 of a check tab. Without it D2 and E2 hold "1 Structure" and "NO_RELATED_RECORDS" over
# nothing, and a reader has to go back to Overview to learn what they are.
#
# Priority is gone: it is derived from Category and exists to sort the board, and by the time
# a tab is open the sorting has done its work. Category keeps a place further out. The six
# after Check By are the ones a person wants while looking at the rows themselves - whether
# this was ever supposed to reach zero, out of how large a population, and whether the last
# fix moved it.
#
# Signal and Signal reason are gone from here as well. They are the runner's own
# classification of the check, settled before the statement was sent and unchanged by reading
# what it returned, so on a tab opened to look at findings they are two columns of noise
# between the identity and the reviewer's own cells. Overview still carries both, hidden.
$SheetsCheckTabColumns = @(
    'Check ID', 'Check Name', 'SQL Used', 'What it does',
    'Comment', 'Check By',
    'Expected', 'Findings', 'Eligible', 'Prev findings', 'Change', 'Verdict', 'Trends',
    'Category', 'Parameters')

# Who owns what. The runner writes around these and never through them: they hold the only
# thing in the document that cannot be regenerated, which is what a person concluded from
# reading it. Everything else the runner can rebuild from the run.
#
# Overview's are Status, Check By and Comment; a check tab's are the same two fields for one
# check. Note that a check tab's Comment is the source and Overview's is a formula reading it
# - so overwriting either would cost the text, and the runner writes neither.
#
# Found by name rather than written as numbers. They were 7 and 8 on a check tab and moved to
# 5 and 6 when Signal and Signal reason came out, and a comment at the old literal 7 would
# have been the reviewer's text sitting in what is now Expected while Comment was overwritten
# every run. Nothing here needs to know a position that the column list already states.
$SheetsOverviewReviewerColumns = @(9, 10, 11)
$SheetsCheckTabReviewerColumns = @(
    ([array]::IndexOf($SheetsCheckTabColumns, 'Comment') + 1),
    ([array]::IndexOf($SheetsCheckTabColumns, 'Check By') + 1))

# Columns Overview ships hidden. Signal and Signal reason are the runner's classification,
# settled before the run and unchanged by reading it. Parameters is empty for every check of
# a sport that takes none and identical for every check of one that does, so it is a column
# of repetition next to the two things a reviewer navigates by. All three stay in the sheet
# and in _summary.csv; unhiding brings back every value.
#
# Hidden once, on the run that creates Overview, and never re-hidden: somebody who unhides one
# has decided something, and putting it back every week is the same defect as overwriting a
# comment. Contiguous runs are hidden together and gaps are not bridged, so hiding C does not
# take D through K with it.
$SheetsOverviewHiddenColumns = @(3, 12, 13)

# How Overview colours its Rows column, and what each band means.
#
# Rows is the raw row count of the result, so a clean check returns exactly one - the COVERAGE
# branch and nothing else. One is therefore the good case, and zero is not: a statement that
# returned nothing at all did not run the coverage contract and is a defect in the check.
#
# Above that the bands are a size judgement rather than a severity one. Severity is Priority,
# which comes from the category and does not move; this says how much work is in front of
# whoever opens the tab, which is the question the board is scanned for.
#
# Rewritten every run rather than set once, and only over rules that cover exactly this
# column: a threshold changed here has to reach a document created before the change, and the
# alternative - adding three more rules each week - fills the sheet with duplicates. A rule
# somebody adds themselves on the Rows column will not survive the next run. Any other column
# is theirs.
$SheetsRowsBands = @(
    [pscustomobject]@{ Type = 'NUMBER_EQ'; Values = @('1'); Colour = '#188038' }
    [pscustomobject]@{ Type = 'NUMBER_BETWEEN'; Values = @('2', '100'); Colour = '#B06000' }
    [pscustomobject]@{ Type = 'NUMBER_GREATER'; Values = @('100'); Colour = '#C5221F' }
)

# The tab holding every statement the run sent, and the name of the token a link to it uses.
# A link needs the target tab's numeric id, which is not known until the tab has been created,
# so the plan writes the token and the transport resolves it once the ids come back.
$SheetsSqlTabName = 'SQL'
$SheetsGidToken = '{{GID:%NAME%}}'

# Where a check tab's result block starts. Rows 1 and 2 are the identity, row 3 the link back
# to Overview and any truncation note, row 4 blank so the results below stay a self-contained
# block for sorting and filtering.
$SheetsCheckTabResultRow = 5

function ConvertTo-SheetsColumnName {
    # 1 -> A, 26 -> Z, 27 -> AA. The API takes A1 notation and the planner works in numbers,
    # because the reviewer-owned columns are easier to reason about as indices.
    param([int]$Index)

    $name = ''
    $n = $Index
    while ($n -gt 0) {
        $remainder = ($n - 1) % 26
        $name = [char](65 + $remainder) + $name
        $n = [int][math]::Floor(($n - 1) / 26)
    }
    return $name
}

function New-SheetsRange {
    param([int]$FromColumn, [int]$FromRow, [int]$ToColumn, [int]$ToRow)
    return '{0}{1}:{2}{3}' -f (ConvertTo-SheetsColumnName -Index $FromColumn), $FromRow,
        (ConvertTo-SheetsColumnName -Index $ToColumn), $ToRow
}

function Split-SheetsWritableSpans {
    # The contiguous column spans a run may write, given the ones a reviewer owns. Returned as
    # spans rather than as one range per cell because the API charges per range, and a sport's
    # Overview is fifty rows of twenty-one columns: two spans a row instead of eighteen.
    param([int]$Width, [int[]]$Reserved)

    $spans = @()
    $start = 0
    for ($column = 1; $column -le $Width; $column++) {
        if ($Reserved -contains $column) {
            if ($start -gt 0) { $spans += [pscustomobject]@{ From = $start; To = $column - 1 } }
            $start = 0
        }
        elseif ($start -eq 0) { $start = $column }
    }
    if ($start -gt 0) { $spans += [pscustomobject]@{ From = $start; To = $Width } }

    # Returned unwrapped. A leading comma would have preserved a one-element result and cost
    # the caller the multi-element one: @(...) around the call then sees a single item holding
    # the array rather than the spans themselves.
    return $spans
}

function Split-SheetsColumnRuns {
    # A set of column indices as contiguous spans, ascending. The API hides a range rather than
    # a list, so a scattered set is several ranges and collapsing it to one min..max would hide
    # everything in between.
    param([int[]]$Columns)

    $runs = @()
    $current = $null
    foreach ($column in @($Columns | Sort-Object -Unique)) {
        if ($null -ne $current -and $column -eq ($current.To + 1)) { $current.To = $column; continue }
        if ($null -ne $current) { $runs += $current }
        $current = [pscustomobject]@{ From = $column; To = $column }
    }
    if ($null -ne $current) { $runs += $current }
    return $runs
}

function ConvertTo-SheetsColour {
    # #RRGGBB as the API wants it: three channels from zero to one, not from zero to 255.
    param([string]$Hex)

    $value = $Hex.TrimStart('#')
    return @{
        red   = [int]::Parse($value.Substring(0, 2), 'HexNumber') / 255
        green = [int]::Parse($value.Substring(2, 2), 'HexNumber') / 255
        blue  = [int]::Parse($value.Substring(4, 2), 'HexNumber') / 255
    }
}

function ConvertTo-SheetsTableName {
    # A table name has to be usable inside a formula, so Sheets allows letters, digits and
    # underscores and refuses to start on a digit. A CheckID is full of hyphens, which is why
    # the first live run of this came back with "The table name is invalid" - the probe that
    # went before it was called "probe" and proved only that a legal name is legal.
    param([string]$Name)

    $safe = [regex]::Replace([string]$Name, '[^A-Za-z0-9_]', '_')
    if ($safe -notmatch '^[A-Za-z_]') { $safe = '_' + $safe }
    return $safe
}

function New-SheetsCommentMirror {
    # The formula Overview's Comment holds: a reference to the Comment cell of that check's own
    # tab. Derived from the column list rather than written as a literal, for the reason given
    # beside $SheetsCheckTabReviewerColumns - the cell was G2, is E2, and the two places that
    # emit this must not be able to disagree with the layout or with each other.
    param([string]$Sheet)

    $cell = (ConvertTo-SheetsColumnName -Index ([array]::IndexOf($SheetsCheckTabColumns, 'Comment') + 1)) + '2'
    return "='" + ($Sheet -replace "'", "''") + "'!" + $cell
}

function New-SheetsGidLink {
    # A link to another tab of the same document, and optionally to a cell in it. The tab is
    # named rather than numbered because a tab this run is creating has no number yet;
    # Invoke-SheetsPlan substitutes the real one once the structure batch has answered.
    param([string]$Sheet, $Text, [string]$Cell)

    $target = '#gid=' + ($SheetsGidToken -replace '%NAME%', $Sheet)
    if ($Cell) { $target += '&range=' + $Cell }

    # A number goes in unquoted, so the cell holds a number. Overview's Rows is the only caller
    # that passes one, and the difference is not cosmetic: quoted, it is text that sorts
    # 1, 10, 2 and that a conditional format comparing against 100 never matches. Formatted
    # under the invariant culture, because a machine set to bg-BG writes a decimal comma and
    # Sheets would read the formula as two arguments.
    $label = $(if ($Text -is [string] -or $null -eq $Text) {
            '"' + ([string]$Text -replace '"', '""') + '"'
        }
        else { [string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0}', $Text) })
    return '=HYPERLINK("{0}",{1})' -f $target, $label
}

function New-SheetsOverviewRow {
    # One Overview row in column order, from the summary entry the run already built. The
    # reviewer's three columns are placed as $null: the planner writes around them on a row
    # that exists, and seeds them only on a row it is adding.
    param($Entry, [string]$SeededStatus)

    return @(
        [string]$Entry.Sport
        [string]$Entry.CheckId
        [string]$Entry.Parameters
        [string]$Entry.Name
        [string]$Entry.Priority
        [string]$Entry.Category
        [string]$Entry.What
        $Entry.RowsCell
        $SeededStatus
        ''
        ''
        [string]$Entry.Signal
        [string]$Entry.SignalReason
        [string]$Entry.Expected
        $Entry.Findings
        $Entry.Eligible
        $Entry.PrevFindings
        $Entry.PrevEligible
        $Entry.Change
        [string]$Entry.Verdict
        [string]$Entry.PrevRunId
        [string]$Entry.Trend
    )
}

function New-SheetsMergePlan {
    <#
        What to send, given what the run produced and what the document already holds.

        Two rules shape all of it, and both exist because the document outlives the run.

        A row is found by its CheckID, never by its position. Writing the Overview as a
        positional block is the obvious implementation and it is wrong: adding one check in
        the middle shifts every row below it, and each reviewer comment then describes the
        check above the one it was written for. So an existing check is updated in the row it
        already occupies, wherever the reviewer has since moved or sorted it to, and a new
        check is appended at the bottom rather than slotted into CheckID order. Sorting is
        the reviewer's to do, and theirs to keep.

        A tab is never deleted. A check that stopped running - deprecated, dropped from the
        registry, no longer approved - keeps its tab and its comments, and is marked instead.
        Deleting it would throw away the one thing in the document nobody can regenerate.
    #>
    param(
        $Summary,
        $Collected,
        $Existing,
        [string]$OutputFolder,
        [int]$MaxRows = $SheetsMaxRowsPerCheck,
        [switch]$Complete
    )

    $plan = @()
    $width = $SheetsOverviewColumns.Count
    $overviewSpans = Split-SheetsWritableSpans -Width $width -Reserved $SheetsOverviewReviewerColumns

    $rowOf = @{}
    if ($Existing -and $Existing.OverviewRowOf) {
        foreach ($key in $Existing.OverviewRowOf.Keys) { $rowOf[$key] = [int]$Existing.OverviewRowOf[$key] }
    }
    $tabOf = @{}
    if ($Existing -and $Existing.TabOf) {
        foreach ($key in $Existing.TabOf.Keys) { $tabOf[$key] = [string]$Existing.TabOf[$key] }
    }

    # Every title already in the document, plus the ones this plan is about to mint. Two check
    # names can abbreviate to the same string, and addSheet fails outright on a duplicate
    # title - which would take the whole run's document update with it. Sheets allows 100
    # characters where Excel allows 31, so nothing is truncated here; only collisions are
    # resolved, the same way the workbook resolves them.
    $usedTitles = @{}
    if ($Existing -and $Existing.Titles) {
        foreach ($title in @($Existing.Titles)) { $usedTitles[[string]$title] = $true }
    }
    $usedTitles['Overview'] = $true

    # Copied rather than used in place: adoption removes from it, and mutating the caller's
    # state object would leave a second call on the same state seeing a different document.
    $emptyTabs = @{}
    if ($Existing -and $Existing.EmptyTabs) {
        foreach ($title in @($Existing.EmptyTabs.Keys)) { $emptyTabs[[string]$title] = $true }
    }
    $emptyTabs.Remove('Overview')

    # A new document has one tab called Sheet1 and no Overview. The tab has to exist before
    # anything names it in a range - Google rejects the whole batch with "Unable to parse
    # range" otherwise - and Invoke-SheetsPlan sends every AddSheet before any write.
    if (-not $Existing -or -not $Existing.HasOverviewSheet) {
        $plan += [pscustomobject]@{ Kind = 'AddSheet'; Sheet = 'Overview' }

        # One operation per contiguous run, not one spanning the lowest to the highest. That
        # shortcut held while the hidden columns were the adjacent L and M; adding C to the
        # list would have hidden C through M and taken Check Name, Rows and Status with it.
        foreach ($span in @(Split-SheetsColumnRuns -Columns $SheetsOverviewHiddenColumns)) {
            $plan += [pscustomobject]@{
                Kind = 'HideColumns'; Sheet = 'Overview'; From = $span.From; To = $span.To
            }
        }
    }

    # The colour bands on Rows, replacing whatever this run finds on that one column. Emitted
    # on every run and not only at creation: a band changed in the source has to reach the
    # documents that already exist, which is the defect that left one board with a column
    # Sheets had to name for itself.
    $rowsColumnIndex = [array]::IndexOf($SheetsOverviewColumns, 'Rows') + 1
    $existingRules = @()
    if ($Existing -and $Existing.ConditionalFormatsOf -and $Existing.ConditionalFormatsOf.ContainsKey('Overview')) {
        $existingRules = @($Existing.ConditionalFormatsOf['Overview'])
    }
    $drop = @()
    for ($index = 0; $index -lt $existingRules.Count; $index++) {
        # Only a rule covering exactly this column. One drawn across the whole board, or over
        # any other column, was somebody's and is left where it is.
        $ranges = @($existingRules[$index].ranges)
        $mine = @($ranges | Where-Object {
                [int]$_.startColumnIndex -eq ($rowsColumnIndex - 1) -and
                [int]$_.endColumnIndex -eq $rowsColumnIndex })
        if ($mine.Count -eq $ranges.Count -and $ranges.Count -gt 0) { $drop += $index }
    }
    $plan += [pscustomobject]@{
        Kind   = 'FormatRules'
        Sheet  = 'Overview'
        Column = $rowsColumnIndex
        Drop   = $drop
        Rules  = $SheetsRowsBands
    }

    # Google gives a new spreadsheet one tab called Sheet1, and it is nobody's: it exists
    # because the document does. Removed once, on the run that first writes here, and only
    # while it is still untouched - the moment somebody puts anything in it, it stops being
    # the default and becomes theirs, which is the same line every other rule here draws.
    #
    # This is the one exception to a tab never being deleted, and it is narrow on purpose: it
    # names one title, and only when empty. Nothing else in this file removes a tab.
    if ($Existing -and $Existing.EmptyTabs -and $Existing.EmptyTabs.ContainsKey('Sheet1') -and
        $Existing.SheetIdOf -and $Existing.SheetIdOf.ContainsKey('Sheet1')) {
        $plan += [pscustomobject]@{
            Kind    = 'DeleteSheet'
            Sheet   = 'Sheet1'
            SheetId = [int]$Existing.SheetIdOf['Sheet1']
        }
        $emptyTabs.Remove('Sheet1')
        $usedTitles.Remove('Sheet1')
    }

    # Overview is the board and belongs at the front. It is created after Sheet1 exists, so
    # without this it opens second on a new document and stays there.
    if ($Existing -and $Existing.SheetIndexOf -and $Existing.SheetIdOf -and
        $Existing.SheetIndexOf.ContainsKey('Overview') -and
        [int]$Existing.SheetIndexOf['Overview'] -ne 0) {
        $plan += [pscustomobject]@{
            Kind    = 'MoveSheet'
            Sheet   = 'Overview'
            SheetId = [int]$Existing.SheetIdOf['Overview']
            Index   = 0
        }
    }

    # Written every run, like a check tab's. It used to be written once, on the reasoning that
    # row 1 was already right on every later run and rewriting it would be a call that changes
    # nothing - which held exactly as long as the board never gained a column. Trend was added,
    # the header of a document created before it stayed twenty-one cells wide, and Sheets
    # filled the twenty-second with a placeholder of its own the moment the table reached it.
    #
    # One saved range was not worth a board that cannot describe its own newest column. Nothing
    # in row 1 is anybody's: the reviewer's cells on Overview are I, J and K, one row below.
    $plan += [pscustomobject]@{
        Kind   = 'Write'
        Sheet  = 'Overview'
        Range  = (New-SheetsRange -FromColumn 1 -FromRow 1 -ToColumn $width -ToRow 1)
        Values = @(, $SheetsOverviewColumns)
    }

    $nextRow = 2
    if ($rowOf.Count -gt 0) {
        $nextRow = ([int](($rowOf.Values | Measure-Object -Maximum).Maximum)) + 1
    }

    # Tab titles are settled before the Overview rows rather than while writing the tabs
    # themselves, because a new Overview row carries a formula pointing at its check's tab and
    # cannot be written before that tab has a name. Resolving them in one pass also puts every
    # collision check in one place.
    # The same pass sizes the grid. A tab is created with 1000 rows and Google will not grow
    # one to meet a range that starts past its end: a 5 000-row result writes its first chunk,
    # which stretches the grid to exactly that chunk, and the second chunk is then rejected
    # for beginning beyond it - taking the whole batch, and so the whole document update, with
    # it. Observed on the first full run of a sport, where nothing under the 2 000-row chunk
    # size had ever reached it.
    $titleOf = @{}
    $capacityOf = @{}
    if ($Existing -and $Existing.RowCapacityOf) {
        foreach ($key in $Existing.RowCapacityOf.Keys) { $capacityOf[[string]$key] = [int]$Existing.RowCapacityOf[$key] }
    }

    foreach ($item in $Collected) {
        $runKey = Get-JobRunKey -Job $item.Job
        $needed = $SheetsCheckTabResultRow + [math]::Min(@($item.Rows).Count, $MaxRows) + 1

        if ($tabOf.ContainsKey($runKey)) {
            $title = $tabOf[$runKey]
            $titleOf[$runKey] = $title

            # Grown, never shrunk. Lowering rowCount deletes the rows below it, and on a tab
            # somebody may have annotated that is not a decision this code gets to make.
            $have = $(if ($capacityOf.ContainsKey($title)) { $capacityOf[$title] } else { 1000 })
            $sheetId = $(if ($Existing -and $Existing.SheetIdOf -and $Existing.SheetIdOf.ContainsKey($title)) {
                    [int]$Existing.SheetIdOf[$title]
                }
                else { $null })

            if ($needed -gt $have -and $null -ne $sheetId) {
                $plan += [pscustomobject]@{ Kind = 'Resize'; Sheet = $title; SheetId = $sheetId; Rows = $needed }
                $capacityOf[$title] = $needed
            }
            continue
        }

        # A title already in the document blocks a new tab - except when the tab wearing it is
        # empty. That is this code's own leftover: the tabs and the values travel in separate
        # batches, so an update that fails on the second leaves a set of nameless tabs behind,
        # and the next run cannot recognise them because a tab is matched by the Check ID in
        # its own A2. Minting a second set beside them is what happened the first time a full
        # sport was written: 99 empty tabs, then 99 more carrying a ~2.
        $wanted = Get-ShortSheetName -Name $(if ($item.Job.Name) { $item.Job.Name } else { $runKey })
        $title = $wanted
        $suffix = 2
        while ($usedTitles.ContainsKey($title) -and -not $emptyTabs.ContainsKey($title)) {
            $title = "$wanted~$suffix"
            $suffix++
        }

        $adopted = $emptyTabs.ContainsKey($title)
        # Claimed, so a second check cannot adopt the same leftover.
        $emptyTabs.Remove($title)
        $usedTitles[$title] = $true

        if ($adopted) {
            $have = $(if ($capacityOf.ContainsKey($title)) { $capacityOf[$title] } else { 1000 })
            $sheetId = $(if ($Existing -and $Existing.SheetIdOf -and $Existing.SheetIdOf.ContainsKey($title)) {
                    [int]$Existing.SheetIdOf[$title]
                }
                else { $null })
            if ($needed -gt $have -and $null -ne $sheetId) {
                $plan += [pscustomobject]@{ Kind = 'Resize'; Sheet = $title; SheetId = $sheetId; Rows = $needed }
                $capacityOf[$title] = $needed
            }
        }
        else {
            $plan += [pscustomobject]@{
                Kind  = 'AddSheet'
                Sheet = $title
                Rows  = [math]::Max($needed, 1000)
            }
            $capacityOf[$title] = [math]::Max($needed, 1000)
        }

        $tabOf[$runKey] = $title
        $titleOf[$runKey] = $title
    }

    $cells = 0
    $seen = @{}

    foreach ($entry in $Summary) {
        $runKey = [string]$entry.RunKey
        if (-not $runKey) { $runKey = [string]$entry.CheckId }
        $seen[$runKey] = $true

        $values = New-SheetsOverviewRow -Entry $entry -SeededStatus ([string]$entry.SeededStatus)

        # Rows doubles as the way in to the check's own tab, as it does in the workbook. It is
        # written as a plain number first and replaced by the link afterwards, so a check with
        # no tab - one that failed or was skipped - simply keeps the number and reads ERROR or
        # SKIPPED rather than offering a link to nowhere.
        #
        # The numeric columns a reviewer sorts and filters on are Findings, Eligible and
        # Change, and all three stay plain. Rows is the one that can afford to be a formula.
        $rowsColumn = [array]::IndexOf($SheetsOverviewColumns, 'Rows') + 1
        $rowsLink = $null
        if ($titleOf.ContainsKey($runKey)) {
            $rowsLink = New-SheetsGidLink -Sheet $titleOf[$runKey] -Text $entry.RowsCell
        }

        if ($rowOf.ContainsKey($runKey)) {
            # The row exists, so the reviewer's three columns are theirs and the run writes
            # around them - two spans rather than one, and never through I, J or K.
            $row = $rowOf[$runKey]
            foreach ($span in $overviewSpans) {
                $slice = @($values[($span.From - 1)..($span.To - 1)])
                $plan += [pscustomobject]@{
                    Kind   = 'Write'
                    Sheet  = 'Overview'
                    Range  = (New-SheetsRange -FromColumn $span.From -FromRow $row -ToColumn $span.To -ToRow $row)
                    Values = @(, $slice)
                }
                $cells += $slice.Count
            }

            # An empty Comment cell holds nothing of anyone's, so seeding the mirror into it
            # costs nothing and is the only way a row written before the mirror existed - or
            # one whose cell was cleared - ever gets one. A cell with anything in it, formula
            # or text, is left alone.
            $wanted = $(if ($Existing -and $Existing.EmptyCommentOf) { [bool]$Existing.EmptyCommentOf[$runKey] } else { $false })
            if ($wanted -and $titleOf.ContainsKey($runKey)) {
                $commentColumn = [array]::IndexOf($SheetsOverviewColumns, 'Comment') + 1
                $plan += [pscustomobject]@{
                    Kind   = 'Write'
                    Raw    = $false
                    Sheet  = 'Overview'
                    Range  = (New-SheetsRange -FromColumn $commentColumn -FromRow $row `
                            -ToColumn $commentColumn -ToRow $row)
                    Values = @(, @((New-SheetsCommentMirror -Sheet $titleOf[$runKey])))
                }
                $cells += 1
            }
        }
        else {
            # A check the document has never held. This is the one time the run writes the
            # reviewer's columns, because there is nothing of theirs to overwrite and the
            # seeded Status is what tells them the row needs no reading.
            $plan += [pscustomobject]@{
                Kind   = 'Write'
                Sheet  = 'Overview'
                Range  = (New-SheetsRange -FromColumn 1 -FromRow $nextRow -ToColumn $width -ToRow $nextRow)
                Values = @(, $values)
            }
            $cells += $values.Count

            # Comment mirrors the check tab's G2, so a comment is written once beside the rows
            # that provoked it and read from the board that lists every check. Seeded on a new
            # row only: on every later run the cell is the reviewer's, whether it still holds
            # this formula or the text they typed over it.
            #
            # The mirror is one way and cannot be two. A cell holds a value or a formula and
            # never both, so two cells cannot each feed the other. This is the safer
            # direction: typing over the mirror costs a mirror, while a mirror on the check
            # tab would have put the words somebody wrote at the same risk.
            #
            # Raw = $false because a formula sent as RAW arrives as the literal text of one.
            # It is emitted after the row write above, and Invoke-SheetsPlan sends the RAW
            # batch first, so it lands on top of the empty cell that write leaves at K.
            if ($titleOf.ContainsKey($runKey)) {
                $commentColumn = [array]::IndexOf($SheetsOverviewColumns, 'Comment') + 1
                $plan += [pscustomobject]@{
                    Kind   = 'Write'
                    Raw    = $false
                    Sheet  = 'Overview'
                    Range  = (New-SheetsRange -FromColumn $commentColumn -FromRow $nextRow `
                            -ToColumn $commentColumn -ToRow $nextRow)
                    Values = @(, @((New-SheetsCommentMirror -Sheet $titleOf[$runKey])))
                }
                $cells += 1
            }

            $rowOf[$runKey] = $nextRow
            $nextRow++
        }

        # Written for both an existing row and a new one, and after either, so it lands on top
        # of the plain number the row write left there.
        if ($rowsLink) {
            $plan += [pscustomobject]@{
                Kind   = 'Write'
                Raw    = $false
                Sheet  = 'Overview'
                Range  = (New-SheetsRange -FromColumn $rowsColumn -FromRow $rowOf[$runKey] `
                        -ToColumn $rowsColumn -ToRow $rowOf[$runKey])
                Values = @(, @($rowsLink))
            }
            $cells += 1
        }
    }

    # A check the document holds and this run did not produce. Not deleted and not left
    # looking current: the Verdict column says it did not run, so a reviewer reading the board
    # is not told last run's number as though it were this one's.
    #
    # Only a run that was meant to cover the sport may say this, which is what -Complete
    # carries. A partial run - one CheckID after a reported fix, a wildcard, a capped batch -
    # did not fail to produce the other ninety checks; it was never asked for them, and
    # marking them would repaint the whole board every time somebody re-ran one thing. The
    # rows it leaves alone keep the last full run's numbers, which is what they are.
    foreach ($runKey in @($rowOf.Keys)) {
        if (-not $Complete) { break }
        if ($seen.ContainsKey($runKey)) { continue }
        $verdictColumn = [array]::IndexOf($SheetsOverviewColumns, 'Verdict') + 1
        $plan += [pscustomobject]@{
            Kind   = 'Write'
            Sheet  = 'Overview'
            Range  = (New-SheetsRange -FromColumn $verdictColumn -FromRow $rowOf[$runKey] `
                    -ToColumn $verdictColumn -ToRow $rowOf[$runKey])
            Values = @(, @('Not in this run'))
        }
        $cells += 1
    }

    # Overview is a table like every result block, and for the same reasons: the styled header
    # stays put while scrolling, and the filter buttons are how a hundred rows get read.
    #
    # It used to be created only by hand and merely maintained here, on the reasoning that a
    # table on the board was the reviewer's own decision. That held until the document was
    # rebuilt from empty and the hand-made one went with it - leaving a rule that would never
    # restore what it had helped lose, and five more sports each needing somebody to remember.
    #
    # An existing one keeps its name rather than being replaced. Its extent does not: both
    # ends of it go stale, and for different reasons.
    #
    # Rows, because a table covers the checks that existed when it was made and the next run
    # appends below it. Columns, because the board gains one now and then - and unlike a
    # comment, no column here is anybody's choice to preserve. Every one of the 22 is written
    # by this code. Keeping a remembered width was the wrong caution: Trend was added, the
    # table still ended at the column before it, and the new column sat outside the table with
    # no header of its own for as long as nobody looked.
    $board = $(if ($Existing -and $Existing.TableOf -and $Existing.TableOf.ContainsKey('Overview')) {
            $Existing.TableOf['Overview']
        }
        else { $null })
    $lastRow = $nextRow - 1

    if ($lastRow -gt 1 -and (-not $board -or $board.ToRow -ne $lastRow -or
            $board.ToCol -ne $width -or $board.FromCol -ne 0 -or $board.FromRow -ne 0)) {
        $plan += [pscustomobject]@{
            Kind    = 'Table'
            Sheet   = 'Overview'
            # One board to a document, so the plain name is free and stays readable in a
            # formula. An existing table keeps whatever it was called.
            Name    = $(if ($board) { $board.Name } else { 'Overview' })
            FromRow = 0
            ToRow   = $lastRow
            FromCol = 0
            ToCol   = $width
        }
    }

    # Then the check tabs, and the SQL tab built alongside them.
    #
    # One tab holding every statement, rather than the statement in each check tab's own C2.
    # A cell of a few thousand characters displays as nothing and pushes the result table out
    # of shape, and the statement keeps the line breaks it was written with here. Each block
    # links back to the results it produced, and each check's C2 links forward to its block.
    $sqlLines = @()
    $sqlBackLinks = @()

    foreach ($item in $Collected) {
        $runKey = Get-JobRunKey -Job $item.Job
        $rows = @($item.Rows)
        $entry = @($Summary | Where-Object {
                ([string]$_.RunKey -eq $runKey) -or ([string]$_.CheckId -eq $runKey) })
        $entry = $(if ($entry.Count -gt 0) { $entry[0] } else { $null })

        # Settled in the pass above, along with any AddSheet it needed.
        $title = $titleOf[$runKey]

        # This check's block on the SQL tab: a heading row that links back to these results,
        # then the statement one line per row, then a blank row. The heading row's number is
        # what C2 above links forward to.
        $sqlRow = $sqlLines.Count + 1
        $sqlBackLinks += [pscustomobject]@{
            Row   = $sqlRow
            Value = (New-SheetsGidLink -Sheet $title -Text ([string]$item.Job.CheckId))
        }
        $sqlLines += , @('')
        foreach ($line in @([string]$item.Job.Sql -split "`r?`n")) { $sqlLines += , @($line) }
        $sqlLines += , @('')

        # Row 1 names the columns. Unlike Overview's header it is rewritten every run rather
        # than seeded once, because none of it is anybody's: the reviewer's cells on a check
        # tab are one row below their headings.
        $plan += [pscustomobject]@{
            Kind   = 'Write'
            Sheet  = $title
            Range  = (New-SheetsRange -FromColumn 1 -FromRow 1 -ToColumn $SheetsCheckTabColumns.Count -ToRow 1)
            Values = @(, $SheetsCheckTabColumns)
        }
        $cells += $SheetsCheckTabColumns.Count

        # Row 2 holds the identity, and Comment and Check By in the middle of it belong to the
        # reviewer, so the same two-span treatment applies as on Overview.
        $identity = @(
            [string]$item.Job.CheckId
            [string]$item.Job.Name
            'SQL'
            [string]$item.Job.What
            ''
            ''
            [string]$(if ($entry) { $entry.Expected } else { '' })
            $(if ($entry) { $entry.Findings } else { $null })
            $(if ($entry) { $entry.Eligible } else { $null })
            $(if ($entry) { $entry.PrevFindings } else { $null })
            $(if ($entry) { $entry.Change } else { $null })
            [string]$(if ($entry) { $entry.Verdict } else { '' })
            [string]$(if ($entry) { $entry.Trend } else { '' })
            [string]$(if ($entry) { $entry.Category } else { '' })
            [string]$(if ($entry) { $entry.Parameters } else { '' })
        )
        $identitySpans = Split-SheetsWritableSpans -Width $identity.Count -Reserved $SheetsCheckTabReviewerColumns
        foreach ($span in $identitySpans) {
            $slice = @($identity[($span.From - 1)..($span.To - 1)])
            $plan += [pscustomobject]@{
                Kind   = 'Write'
                Sheet  = $title
                Range  = (New-SheetsRange -FromColumn $span.From -FromRow 2 -ToColumn $span.To -ToRow 2)
                Values = @(, $slice)
            }
            $cells += $slice.Count
        }

        # C2 and A3, the two links a check tab carries. Both are formulas, so both go in the
        # USER_ENTERED batch, and both land after the row that wrote plain text into C2.
        #
        # A3 rather than row 2, and row 4 left blank below it, so the result table starting at
        # row 5 stays a self-contained block that sorts and filters on its own.
        $plan += [pscustomobject]@{
            Kind   = 'Write'
            Raw    = $false
            Sheet  = $title
            Range  = 'C2'
            Values = @(, @((New-SheetsGidLink -Sheet $SheetsSqlTabName -Text 'SQL' -Cell ('A' + $sqlRow))))
        }
        $plan += [pscustomobject]@{
            Kind   = 'Write'
            Raw    = $false
            Sheet  = $title
            Range  = 'A3'
            Values = @(, @((New-SheetsGidLink -Sheet 'Overview' -Text 'Return to Overview')))
        }

        # What was written, and what was not. A truncated tab says so on its own face rather
        # than in the run log, because the person who reads it a week later has only the tab.
        $written = @($rows | Select-Object -First $MaxRows)
        $note = ''
        if ($rows.Count -gt $MaxRows) {
            $note = '{0:n0} of {1:n0} rows. The full result is in {2}' -f $MaxRows, $rows.Count, $OutputFolder
        }
        $plan += [pscustomobject]@{
            Kind   = 'Write'
            Sheet  = $title
            Range  = 'C3'
            Values = @(, @($note))
        }

        # Cleared before it is written, and to the end of the tab rather than to a remembered
        # depth. A check that found forty rows last run and three this one would otherwise
        # leave thirty-seven stale rows under the three new ones, which reads as forty
        # findings.
        #
        # Open-ended on purpose. Clearing to a depth this code believes the tab has is only
        # right while that belief is: a run recorded with -TestRun, an edit somebody made by
        # hand, a failed write halfway through - any of those and the remembered number is
        # short, which leaves exactly the stale rows this exists to remove. The end of the
        # tab is a fact rather than a belief, and costs the same one request.
        $plan += [pscustomobject]@{
            Kind  = 'Clear'
            Sheet = $title
            Range = '{0}{1}:Z' -f (ConvertTo-SheetsColumnName -Index 1), $SheetsCheckTabResultRow
        }

        if ($written.Count -gt 0) {
            $header = @($written[0].PSObject.Properties.Name)
            $table = @(, $header)
            foreach ($row in $written) {
                $table += , @($header | ForEach-Object { $row.$_ })
            }
            $plan += [pscustomobject]@{
                Kind   = 'Write'
                Sheet  = $title
                Range  = (New-SheetsRange -FromColumn 1 -FromRow $SheetsCheckTabResultRow `
                        -ToColumn $header.Count -ToRow ($SheetsCheckTabResultRow + $written.Count))
                Values = $table
            }
            $cells += $header.Count * ($written.Count + 1)

            # The result block as a table: a styled header, filter buttons and banded rows,
            # without any of it being written as formatting. The range has to be maintained
            # rather than set once, because every run replaces a different number of rows and
            # a table left at last week's extent either cuts the result short or trails empty
            # rows past its end.
            #
            # No column types are declared. Left to guess, Sheets reads a value like 2019-03
            # as a date and shows an error over data that is exactly what the database
            # returned.
            $plan += [pscustomobject]@{
                Kind    = 'Table'
                Sheet   = $title
                Name    = (ConvertTo-SheetsTableName -Name ([string]$item.Job.CheckId))
                FromRow = $SheetsCheckTabResultRow - 1
                ToRow   = $SheetsCheckTabResultRow + $written.Count
                FromCol = 0
                ToCol   = $header.Count
            }
        }
    }

    # The SQL tab, once the blocks are known. Rewritten whole every run: a statement can
    # change between runs, and unlike a check tab there is nothing on it that is anybody's.
    if ($sqlLines.Count -gt 0) {
        $sqlNeeded = $sqlLines.Count + 10
        if ($usedTitles.ContainsKey($SheetsSqlTabName)) {
            $have = $(if ($capacityOf.ContainsKey($SheetsSqlTabName)) { $capacityOf[$SheetsSqlTabName] } else { 1000 })
            $sqlId = $(if ($Existing -and $Existing.SheetIdOf -and $Existing.SheetIdOf.ContainsKey($SheetsSqlTabName)) {
                    [int]$Existing.SheetIdOf[$SheetsSqlTabName]
                }
                else { $null })
            if ($sqlNeeded -gt $have -and $null -ne $sqlId) {
                $plan += [pscustomobject]@{
                    Kind = 'Resize'; Sheet = $SheetsSqlTabName; SheetId = $sqlId; Rows = $sqlNeeded
                }
            }
        }
        else {
            $plan += [pscustomobject]@{
                Kind  = 'AddSheet'
                Sheet = $SheetsSqlTabName
                Rows  = [math]::Max($sqlNeeded, 1000)
            }
            $usedTitles[$SheetsSqlTabName] = $true
        }

        $plan += [pscustomobject]@{ Kind = 'Clear'; Sheet = $SheetsSqlTabName; Range = 'A1:B' }
        $plan += [pscustomobject]@{
            Kind   = 'Write'
            Sheet  = $SheetsSqlTabName
            Range  = (New-SheetsRange -FromColumn 1 -FromRow 1 -ToColumn 1 -ToRow $sqlLines.Count)
            Values = $sqlLines
        }
        $cells += $sqlLines.Count

        # The heading rows are links, so they go in the USER_ENTERED batch and land on top of
        # the blank cells the block write leaves for them.
        foreach ($back in $sqlBackLinks) {
            $plan += [pscustomobject]@{
                Kind   = 'Write'
                Raw    = $false
                Sheet  = $SheetsSqlTabName
                Range  = ('A{0}' -f $back.Row)
                Values = @(, @($back.Value))
            }
        }
        $cells += $sqlBackLinks.Count
    }

    # A run rewrites essentially every cell it owns, so what this plan writes is a fair proxy
    # for what the document will hold. Reported rather than acted on: the answers are to drop
    # a check from the document, tighten a scope or split the sport, and none of those is the
    # runner's to choose silently.
    $warning = ''
    if ($cells -gt $SheetsCellBudgetWarning) {
        $warning = ('This run writes {0:n0} cells. Google caps a spreadsheet at 10 000 000, ' +
            'and Sheets is slow well below that.') -f $cells
    }

    $known = @{}
    if ($Existing -and $Existing.SheetIdOf) {
        foreach ($key in $Existing.SheetIdOf.Keys) { $known[[string]$key] = [int]$Existing.SheetIdOf[$key] }
    }

    $tables = @{}
    if ($Existing -and $Existing.TableOf) {
        foreach ($key in $Existing.TableOf.Keys) { $tables[[string]$key] = $Existing.TableOf[$key] }
    }

    return [pscustomobject]@{
        Operations    = $plan
        Cells         = $cells
        Warning       = $warning
        RowOf         = $rowOf
        TabOf         = $tabOf
        KnownSheetIds = $known
        KnownTables   = $tables
    }
}

# ----- transport -------------------------------------------------------------------------
#
# Everything above computes; everything below sends. The split is what lets the merge be
# tested without a login, and nothing below decides anything the merge has not already
# decided.

function Get-SheetsAccessToken {
    # The refresh token is long-lived and recorded once by Connect-Sheets.ps1; an access token
    # lasts an hour. Cached for the process with a minute of margin, because a run that takes
    # fifty minutes must not fail on the last check for a token that expired mid-request.
    param([switch]$Force)

    if (-not $Force -and $script:SheetsAccessToken -and (Get-Date) -lt $script:SheetsTokenExpiry) {
        return $script:SheetsAccessToken
    }

    foreach ($name in @('EP_SHEETS_CLIENT_ID', 'EP_SHEETS_CLIENT_SECRET', 'EP_SHEETS_REFRESH_TOKEN')) {
        if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) {
            throw ("$name is not set. Run TOOLS\Connect-Sheets.ps1 once to authorise the " +
                'Google account; TOOLS\README.md has the console steps that come before it.')
        }
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Set-SheetsAddressFamily -Uri $SheetsTokenUrl

    try {
        $response = Invoke-RestMethod -Method Post -Uri $SheetsTokenUrl -TimeoutSec 60 -Body @{
            client_id     = $env:EP_SHEETS_CLIENT_ID
            client_secret = $env:EP_SHEETS_CLIENT_SECRET
            refresh_token = $env:EP_SHEETS_REFRESH_TOKEN
            grant_type    = 'refresh_token'
        }
    }
    catch {
        # invalid_grant is the one worth naming, because its cause is never in this code and
        # the message Google returns does not say what to do about it.
        $detail = $_.Exception.Message
        if ($detail -like '*400*') {
            $detail += ("`n  The refresh token was rejected. It is revoked by a password change, by " +
                'removing the app from the account, or after seven days if the OAuth consent screen ' +
                'is External and still in Testing. Re-run TOOLS\Connect-Sheets.ps1 -Force.')
        }
        throw "Google refused the refresh token: $detail"
    }

    $script:SheetsAccessToken = [string]$response.access_token
    $script:SheetsTokenExpiry = (Get-Date).AddSeconds([int]$response.expires_in - 60)
    return $script:SheetsAccessToken
}

function Invoke-SheetsApi {
    param(
        [string]$Method,
        [string]$Path,
        $Body
    )

    $uri = "$SheetsApiRoot/$Path"
    Set-SheetsAddressFamily -Uri $uri
    $headers = @{ Authorization = 'Bearer ' + (Get-SheetsAccessToken) }

    $arguments = @{
        Method     = $Method
        Uri        = $uri
        Headers    = $headers
        TimeoutSec = 180
    }
    if ($null -ne $Body) {
        $arguments['Body'] = ($Body | ConvertTo-Json -Depth 12 -Compress)
        $arguments['ContentType'] = 'application/json; charset=utf-8'
    }

    try { return Invoke-RestMethod @arguments }
    catch {
        # Google's own message is in the body and says far more than the status line does -
        # which range was malformed, which sheet does not exist, which scope is missing.
        $detail = $_.Exception.Message
        if ($_.Exception.Response) {
            try {
                $reader = New-Object IO.StreamReader($_.Exception.Response.GetResponseStream())
                $detail = $reader.ReadToEnd()
            }
            catch { }
        }
        throw "Sheets API $Method $Path failed: $detail"
    }
}

function Read-SheetState {
    <#
        What the document already holds, in the shape New-SheetsMergePlan expects.

        Two reads, not more. The tab list and the Overview CheckID column are enough: an
        existing check is found by its CheckID and updated in the row it occupies, and a tab
        is found by the Check ID its own A2 carries rather than by guessing at the title,
        because the title is an abbreviation of the check name and the name can change.
    #>
    param([string]$SpreadsheetId)

    $meta = Invoke-SheetsApi -Method Get -Path ("$SpreadsheetId" +
        '?fields=properties.title,sheets.properties.title,sheets.properties.sheetId' +
        ',sheets.properties.gridProperties.rowCount,sheets.tables' +
        ',sheets.conditionalFormats.ranges')
    $titles = @($meta.sheets | ForEach-Object { [string]$_.properties.title })
    $hasOverview = ($titles -contains 'Overview')

    # How many rows each tab's grid currently holds, and the id that identifies it. A write
    # past the end of the grid is rejected outright - Google does not grow a sheet to meet a
    # range that starts beyond it - so the plan has to know the capacity before it can decide
    # to raise it, and updateSheetProperties names a sheet by id rather than by title.
    $capacityOf = @{}
    $idOf = @{}
    $indexOf = @{}
    $tableOf = @{}
    $formatsOf = @{}
    $position = 0
    foreach ($sheet in @($meta.sheets)) {
        $title = [string]$sheet.properties.title
        $capacityOf[$title] = [int]$sheet.properties.gridProperties.rowCount
        $idOf[$title] = [int]$sheet.properties.sheetId
        $indexOf[$title] = $position
        $position++

        # Ranges only. A conditional format rule is identified for replacement by what it
        # covers and nothing else, so the condition and the colours are weight the read does
        # not need to carry - and the ranges come back in the order the rules are indexed in,
        # which is what deleting one depends on.
        $formatsOf[$title] = @($sheet.conditionalFormats)

        # At most one table per tab is tracked, which is all this writes and all a check tab
        # has room to mean. A table somebody made themselves is kept and its extent corrected
        # rather than replaced: the range is what goes stale as a result grows or shrinks, and
        # correcting it is the whole of what maintenance means here.
        $table = @($sheet.tables)[0]
        if ($table) {
            $tableOf[$title] = [pscustomobject]@{
                Id       = [string]$table.tableId
                Name     = [string]$table.name
                FromRow  = [int]$table.range.startRowIndex
                ToRow    = [int]$table.range.endRowIndex
                FromCol  = [int]$table.range.startColumnIndex
                ToCol    = [int]$table.range.endColumnIndex
            }
        }
    }

    # Only tabs that exist may be named in a range. Google rejects the whole batch with
    # "Unable to parse range" for one that does not, so a brand new document - which has a
    # single Sheet1 and no Overview - would fail on the read before anything could be written.
    # Through K rather than through B, because the merge needs to know which Comment cells are
    # empty as well as which checks are on the board.
    $reads = @()
    if ($hasOverview) { $reads += 'Overview!A1:K' }
    $checkTabs = @($titles | Where-Object { $_ -ne 'Overview' })
    foreach ($title in $checkTabs) { $reads += "'" + ($title -replace "'", "''") + "'!A2" }

    $rowOf = @{}
    $tabOf = @{}
    $emptyComment = @{}
    # A tab holding no Check ID in its own A2. Almost always this run's predecessor: the tabs
    # go in one batch and the values in another, so a document update that fails on the second
    # leaves the first behind. Naming them lets the next run adopt its own leftovers instead
    # of minting a second set beside them.
    $emptyTabs = @{}
    $hasHeader = $false

    if ($reads.Count -gt 0) {
        $query = ($reads | ForEach-Object { 'ranges=' + [uri]::EscapeDataString($_) }) -join '&'
        $values = Invoke-SheetsApi -Method Get -Path "$SpreadsheetId/values:batchGet`?$query&majorDimension=ROWS"
        $ranges = @($values.valueRanges)

        $offset = 0
        if ($hasOverview -and $ranges.Count -gt 0) {
            $rows = @($ranges[0].values)
            # Row 1 is the header when there is one at all; CheckID is column B.
            $hasHeader = ($rows.Count -gt 0 -and @($rows[0]).Count -gt 0 -and
                -not [string]::IsNullOrWhiteSpace([string]@($rows[0])[0]))
            for ($r = 1; $r -lt $rows.Count; $r++) {
                $cells = @($rows[$r])
                if ($cells.Count -lt 2) { continue }
                $checkId = [string]$cells[1]
                if ([string]::IsNullOrWhiteSpace($checkId)) { continue }
                $rowOf[$checkId] = $r + 1

                # K is column index 10. A short row means the API stopped at the last
                # non-empty cell, so anything short of K has an empty Comment.
                if ($cells.Count -lt 11 -or [string]::IsNullOrWhiteSpace([string]$cells[10])) {
                    $emptyComment[$checkId] = $true
                }
            }
            $offset = 1
        }

        # A tab is matched to its check by the Check ID its own A2 carries, never by its
        # title: the title is an abbreviation of the check name, and a name can change without
        # the check becoming a different one.
        for ($i = 0; $i -lt $checkTabs.Count; $i++) {
            $index = $i + $offset
            if ($index -ge $ranges.Count) { break }
            $rows = @($ranges[$index].values)

            $checkId = ''
            if ($rows.Count -gt 0 -and @($rows[0]).Count -gt 0) { $checkId = [string]@($rows[0])[0] }

            if (-not [string]::IsNullOrWhiteSpace($checkId)) { $tabOf[$checkId] = $checkTabs[$i] }
            else { $emptyTabs[$checkTabs[$i]] = $true }
        }
    }

    return [pscustomobject]@{
        Title             = [string]$meta.properties.title
        Titles            = $titles
        HasOverviewSheet  = $hasOverview
        HasOverviewHeader = $hasHeader
        OverviewRowOf     = $rowOf
        EmptyCommentOf    = $emptyComment
        TabOf             = $tabOf
        EmptyTabs         = $emptyTabs
        RowCapacityOf     = $capacityOf
        SheetIdOf         = $idOf
        SheetIndexOf      = $indexOf
        TableOf           = $tableOf
        ConditionalFormatsOf = $formatsOf
    }
}

function Split-SheetsWriteChunks {
    # One write operation into as many as its row count needs. A 20 000-row block is megabytes
    # of JSON in a single body: slow to build, slow to send, and lost entirely if it fails.
    param($Operation, [int]$ChunkSize = $SheetsWriteChunk)

    $values = @($Operation.Values)
    if ($values.Count -le $ChunkSize) { return @($Operation) }

    # Only a range anchored at a known first row can be split, which every result block is.
    if ($Operation.Range -notmatch '^([A-Z]+)(\d+):([A-Z]+)(\d+)$') { return @($Operation) }
    $fromColumn = $matches[1]
    $fromRow = [int]$matches[2]
    $toColumn = $matches[3]

    $chunks = @()
    $offset = 0
    while ($offset -lt $values.Count) {
        $slice = @($values | Select-Object -Skip $offset -First $ChunkSize)
        $start = $fromRow + $offset
        $chunks += [pscustomobject]@{
            Kind   = 'Write'
            Sheet  = $Operation.Sheet
            Range  = '{0}{1}:{2}{3}' -f $fromColumn, $start, $toColumn, ($start + $slice.Count - 1)
            Values = $slice
        }
        $offset += $ChunkSize
    }
    return $chunks
}

function ConvertTo-SheetsCellValue {
    # Sheets takes strings, numbers and booleans. A $null becomes an empty string rather than
    # a JSON null, which the API rejects inside a value range.
    param($Value)

    if ($null -eq $Value) { return '' }
    if ($Value -is [bool]) { return $Value }
    if ($Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal]) { return $Value }
    return [string]$Value
}

function Invoke-SheetsPlan {
    # Send a plan. Ordered rather than batched into one call: tabs have to exist before
    # anything is written into them, and stale rows have to be gone before new ones land on
    # top of them. Within each of those three phases the requests are batched.
    param([string]$SpreadsheetId, $Plan)

    $operations = @($Plan.Operations)

    $script:SheetsStage = 'adding and sizing tabs'
    # Structure first, and in one call: a tab has to exist before a range names it, and a grid
    # has to be big enough before a range reaches past its end. Both are rejected the same
    # way, and a rejection takes the whole batch it travelled in.
    $adds = @($operations | Where-Object { $_.Kind -eq 'AddSheet' })
    $resizes = @($operations | Where-Object { $_.Kind -eq 'Resize' })
    $structure = @()

    foreach ($add in $adds) {
        $rows = $(if ($add.PSObject.Properties.Name -contains 'Rows' -and $add.Rows) { [int]$add.Rows } else { 1000 })
        $structure += @{
            addSheet = @{
                properties = @{
                    title          = $add.Sheet
                    gridProperties = @{ rowCount = $rows; columnCount = 26 }
                }
            }
        }
    }
    foreach ($resize in $resizes) {
        # By sheetId: updateSheetProperties identifies a sheet by id and not by title, and
        # setting title here would rename the tab rather than find it. A tab this run is
        # adding needs no resize, because it is created at the size it needs.
        $structure += @{
            updateSheetProperties = @{
                properties = @{
                    sheetId        = [int]$resize.SheetId
                    gridProperties = @{ rowCount = [int]$resize.Rows }
                }
                fields     = 'gridProperties.rowCount'
            }
        }
    }

    # Requests apply in order, so the removal goes before the move: deleting a sheet shifts
    # every index after it, and Overview's target of 0 has to be read against the document as
    # it will be, not as it was.
    foreach ($drop in @($operations | Where-Object { $_.Kind -eq 'DeleteSheet' })) {
        $structure += @{ deleteSheet = @{ sheetId = [int]$drop.SheetId } }
    }
    foreach ($move in @($operations | Where-Object { $_.Kind -eq 'MoveSheet' })) {
        $structure += @{
            updateSheetProperties = @{
                properties = @{ sheetId = [int]$move.SheetId; index = [int]$move.Index }
                fields     = 'index'
            }
        }
    }

    # Every tab id this run can name: the ones the document already had, plus the ones the
    # structure batch has just minted. A link carries the target's numeric id and nothing
    # knows a new tab's id until Google answers, which is why the plan writes a token.
    $gidOf = @{}
    if ($Plan.PSObject.Properties.Name -contains 'KnownSheetIds' -and $Plan.KnownSheetIds) {
        foreach ($key in $Plan.KnownSheetIds.Keys) { $gidOf[[string]$key] = [int]$Plan.KnownSheetIds[$key] }
    }

    if ($structure.Count -gt 0) {
        $answer = Invoke-SheetsApi -Method Post -Path "$SpreadsheetId`:batchUpdate" -Body @{ requests = $structure }
        foreach ($reply in @($answer.replies)) {
            if ($reply.addSheet) {
                $gidOf[[string]$reply.addSheet.properties.title] = [int]$reply.addSheet.properties.sheetId
            }
        }
    }

    $script:SheetsStage = 'hiding columns and colouring Rows'
    # Both need a tab id, so they wait for the batch that creates the tab.
    $hides = @($operations | Where-Object { $_.Kind -eq 'HideColumns' })
    $second = @()
    foreach ($hide in $hides) {
        if (-not $gidOf.ContainsKey($hide.Sheet)) { continue }
        $second += @{
            updateDimensionProperties = @{
                range      = @{
                    sheetId    = [int]$gidOf[$hide.Sheet]
                    dimension  = 'COLUMNS'
                    startIndex = [int]$hide.From - 1
                    endIndex   = [int]$hide.To
                }
                properties = @{ hiddenByUser = $true }
                fields     = 'hiddenByUser'
            }
        }
    }

    foreach ($rules in @($operations | Where-Object { $_.Kind -eq 'FormatRules' })) {
        if (-not $gidOf.ContainsKey($rules.Sheet)) { continue }
        $sheetId = [int]$gidOf[$rules.Sheet]

        # Highest index first. Each deletion renumbers the rules after it, so removing 0 then 1
        # removes the original 0 and 2 and leaves the rule in the middle behind.
        foreach ($index in @(@($rules.Drop) | Sort-Object -Descending)) {
            $second += @{ deleteConditionalFormatRule = @{ sheetId = $sheetId; index = [int]$index } }
        }

        $at = 0
        foreach ($band in @($rules.Rules)) {
            $second += @{
                addConditionalFormatRule = @{
                    index = $at
                    rule  = @{
                        # No endRowIndex, so the band covers the column however far the board
                        # grows. startRowIndex 1 keeps it off the header.
                        ranges     = @(@{
                                sheetId          = $sheetId
                                startRowIndex    = 1
                                startColumnIndex = [int]$rules.Column - 1
                                endColumnIndex   = [int]$rules.Column
                            })
                        booleanRule = @{
                            condition = @{
                                type   = [string]$band.Type
                                values = @(@($band.Values) | ForEach-Object { @{ userEnteredValue = [string]$_ } })
                            }
                            format    = @{
                                textFormat = @{
                                    bold                 = $true
                                    foregroundColorStyle = @{ rgbColor = (ConvertTo-SheetsColour -Hex $band.Colour) }
                                }
                            }
                        }
                    }
                }
            }
            $at++
        }
    }

    if ($second.Count -gt 0) {
        Invoke-SheetsApi -Method Post -Path "$SpreadsheetId`:batchUpdate" -Body @{ requests = $second } | Out-Null
    }

    $script:SheetsStage = 'clearing stale rows'
    $clears = @($operations | Where-Object { $_.Kind -eq 'Clear' })
    if ($clears.Count -gt 0) {
        $ranges = @($clears | ForEach-Object { "'" + ($_.Sheet -replace "'", "''") + "'!" + $_.Range })
        Invoke-SheetsApi -Method Post -Path "$SpreadsheetId/values:batchClear" -Body @{ ranges = $ranges } | Out-Null
    }

    $writes = @()
    foreach ($operation in @($operations | Where-Object { $_.Kind -eq 'Write' })) {
        $writes += Split-SheetsWriteChunks -Operation $operation
    }

    $raw = @()
    $entered = @()
    foreach ($write in $writes) {
        $rows = @()
        foreach ($row in @($write.Values)) {
            $rows += , @(@($row) | ForEach-Object { ConvertTo-SheetsCellValue -Value $_ })
        }
        $range = @{
            range  = "'" + ($write.Sheet -replace "'", "''") + "'!" + $write.Range
            values = $rows
        }

        # Raw is the default and is what almost everything wants. A finding is data: a name
        # beginning with a hyphen, or a value Sheets would read as a date, has to arrive as
        # what the database returned. Only the Comment mirror opts out, because a formula
        # sent as RAW arrives as the literal text of one.
        $isRaw = $true
        if ($write.PSObject.Properties.Name -contains 'Raw' -and $write.Raw -eq $false) { $isRaw = $false }

        # Only a formula carries a link, so only the USER_ENTERED side needs resolving. A
        # token whose tab does not exist would leave a literal in the cell, so it is dropped
        # rather than written: a broken link is worse than a missing one, because it reads as
        # something that ought to work.
        if (-not $isRaw) {
            # A plain loop, not ForEach-Object: a pipeline block runs in a child scope, so a
            # flag set inside one never reaches the variable being tested out here.
            $unresolved = $false
            $resolved = @()
            foreach ($row in $rows) {
                $cells = @()
                foreach ($cell in @($row)) {
                    $text = [string]$cell
                    foreach ($name in @($gidOf.Keys)) {
                        $text = $text.Replace(($SheetsGidToken -replace '%NAME%', $name), [string]$gidOf[$name])
                    }
                    if ($text -like '*{{GID:*') { $unresolved = $true }
                    $cells += $text
                }
                $resolved += , $cells
            }
            if ($unresolved) { continue }
            $range['values'] = $resolved
        }

        if ($isRaw) { $raw += $range } else { $entered += $range }
    }

    $script:SheetsStage = 'writing values'
    # RAW first. The whole-row write of a new Overview row leaves K empty and the mirror lands
    # on top of it, so the order of these two calls is what decides which value survives.
    if ($raw.Count -gt 0) {
        Invoke-SheetsApi -Method Post -Path "$SpreadsheetId/values:batchUpdate" -Body @{
            valueInputOption = 'RAW'
            data             = $raw
        } | Out-Null
    }
    if ($entered.Count -gt 0) {
        Invoke-SheetsApi -Method Post -Path "$SpreadsheetId/values:batchUpdate" -Body @{
            valueInputOption = 'USER_ENTERED'
            data             = $entered
        } | Out-Null
    }

    $script:SheetsStage = 'declaring the result tables'
    # Tables last: the tab has to exist and its rows have to be in place before a range is
    # declared over them. A tab that already carries one is updated rather than given a
    # second - the range is the part that goes stale, not the table.
    $tableOps = @($operations | Where-Object { $_.Kind -eq 'Table' })
    $tableRequests = @()
    $known = @{}
    if ($Plan.PSObject.Properties.Name -contains 'KnownTables' -and $Plan.KnownTables) {
        foreach ($key in $Plan.KnownTables.Keys) { $known[[string]$key] = $Plan.KnownTables[$key] }
    }

    foreach ($table in $tableOps) {
        if (-not $gidOf.ContainsKey($table.Sheet)) { continue }
        $range = @{
            sheetId          = [int]$gidOf[$table.Sheet]
            startRowIndex    = [int]$table.FromRow
            endRowIndex      = [int]$table.ToRow
            startColumnIndex = [int]$table.FromCol
            endColumnIndex   = [int]$table.ToCol
        }

        if ($known.ContainsKey($table.Sheet)) {
            $tableRequests += @{
                updateTable = @{
                    table  = @{ tableId = [string]$known[$table.Sheet].Id; range = $range }
                    fields = 'range'
                }
            }
        }
        else {
            $tableRequests += @{ addTable = @{ table = @{ name = [string]$table.Name; range = $range } } }
        }
    }

    if ($tableRequests.Count -gt 0) {
        Invoke-SheetsApi -Method Post -Path "$SpreadsheetId`:batchUpdate" -Body @{ requests = $tableRequests } | Out-Null
    }

    return [pscustomobject]@{
        Added   = $adds.Count
        Cleared = $clears.Count
        Written = $writes.Count
        Tables  = $tableRequests.Count
    }
}

function Test-SheetsTitleIsOurs {
    # Whether the document's current title is one the runner may replace. Separated from the
    # call that replaces it so the decision can be tested without a login, which is the same
    # split the merge and the transport are on.
    #
    # Google's placeholder counts, and so does any name this runner has given a document: a
    # name we produced ourselves is nobody's decision, which is why changing the naming pattern
    # does not strand the documents named under the old one. Everything else is somebody's.
    param([string]$CurrentTitle, [string]$Title)

    if ([string]::IsNullOrWhiteSpace($Title)) { return $false }
    if ($CurrentTitle -eq $Title) { return $false }
    if ([string]::IsNullOrWhiteSpace($CurrentTitle) -or $CurrentTitle -eq $SheetsUntitled) { return $true }

    foreach ($pattern in $SheetsFormerTitles) {
        if ($CurrentTitle -like $pattern) { return $true }
    }
    return $false
}

function Set-SheetTitleIfUnnamed {
    # Named while Google's own placeholder is still there, or while the title is one this
    # runner gave it, and never over a title somebody chose. A colleague who renames the
    # document has decided something, and putting the runner's name back every week is the
    # same defect as overwriting a comment.
    param([string]$SpreadsheetId, [string]$CurrentTitle, [string]$Title)

    if (-not (Test-SheetsTitleIsOurs -CurrentTitle $CurrentTitle -Title $Title)) { return $false }

    Invoke-SheetsApi -Method Post -Path "$SpreadsheetId`:batchUpdate" -Body @{
        requests = @(@{
                updateSpreadsheetProperties = @{
                    properties = @{ title = $Title }
                    fields     = 'title'
                }
            })
    } | Out-Null
    return $true
}
