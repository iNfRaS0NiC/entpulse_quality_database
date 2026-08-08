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

# How many result rows one check may put in the live document. The hard limit is Google's, at
# 10 million cells per spreadsheet, and it is a document budget rather than a per-tab one: a
# sport is around fifty checks in one permanent file, so a single six-figure check can take a
# sixth of the document by itself. Sheets also becomes slow to open and scroll well before
# the limit, and writing that many cells over the API costs minutes per run.
#
# 20 000 is chosen to clear the largest counts actually seen - a 14 000-row missing-value
# check writes in full, at about 1% of the budget - while stopping the handful of statements
# that return six figures. It is a round number standing in for a distribution nobody has
# measured yet: once RUNS/<Sport>.json holds two runs it carries findings for every check of
# every sport, and the number should be re-derived from that rather than left as a guess.
$SheetsMaxRowsPerCheck = 20000

# When the whole document would pass this, the run says so. A warning rather than a truncation
# because the answer is a decision - drop a check from the document, tighten a scope, split
# the sport - and none of those is the runner's to make silently.
$SheetsCellBudgetWarning = 8000000

# The columns on the live Overview, in order, matching the workbook so the two read alike.
$SheetsOverviewColumns = @(
    'Sport', 'CheckID', 'Parameters', 'Check Name', 'Priority', 'Category', 'What it does',
    'Rows', 'Status', 'Check By', 'Comment', 'Signal', 'Signal reason',
    'Expected', 'Findings', 'Eligible', 'Prev findings', 'Prev eligible', 'Change',
    'Verdict', 'Last run')

# Who owns what. The runner writes around these and never through them: they hold the only
# thing in the document that cannot be regenerated, which is what a person concluded from
# reading it. Everything else the runner can rebuild from the run.
#
# Overview I, J and K are Status, Check By and Comment. A check tab's G2 and H2 are the same
# two fields for one check. Note that a check tab's Comment is the source and Overview's is a
# formula reading it - so overwriting either would cost the text, and the runner writes
# neither.
$SheetsOverviewReviewerColumns = @(9, 10, 11)
$SheetsCheckTabReviewerColumns = @(7, 8)

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
        [int]$MaxRows = $SheetsMaxRowsPerCheck
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

    # A document nobody has written to yet has no header. Written once, and never again: on
    # every later run row 1 is already right, and rewriting it would be an API call a run
    # makes to change nothing.
    if (-not $Existing -or -not $Existing.HasOverviewHeader) {
        $plan += [pscustomobject]@{
            Kind   = 'Write'
            Sheet  = 'Overview'
            Range  = (New-SheetsRange -FromColumn 1 -FromRow 1 -ToColumn $width -ToRow 1)
            Values = @(, $SheetsOverviewColumns)
        }
    }

    $nextRow = 2
    if ($rowOf.Count -gt 0) {
        $nextRow = ([int](($rowOf.Values | Measure-Object -Maximum).Maximum)) + 1
    }

    $cells = 0
    $seen = @{}

    foreach ($entry in $Summary) {
        $runKey = [string]$entry.RunKey
        if (-not $runKey) { $runKey = [string]$entry.CheckId }
        $seen[$runKey] = $true

        $values = New-SheetsOverviewRow -Entry $entry -SeededStatus ([string]$entry.SeededStatus)

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
            $rowOf[$runKey] = $nextRow
            $nextRow++
        }
    }

    # A check the document holds and this run did not produce. Not deleted and not left
    # looking current: the Verdict column says it did not run, so a reviewer reading the board
    # is not told last run's number as though it were this one's.
    foreach ($runKey in @($rowOf.Keys)) {
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

    # Then the check tabs.
    foreach ($item in $Collected) {
        $runKey = Get-JobRunKey -Job $item.Job
        $rows = @($item.Rows)
        $entry = @($Summary | Where-Object {
                ([string]$_.RunKey -eq $runKey) -or ([string]$_.CheckId -eq $runKey) })
        $entry = $(if ($entry.Count -gt 0) { $entry[0] } else { $null })

        $title = $(if ($tabOf.ContainsKey($runKey)) { $tabOf[$runKey] }
            else { Get-ShortSheetName -Name $(if ($item.Job.Name) { $item.Job.Name } else { $runKey }) })

        if (-not $tabOf.ContainsKey($runKey)) {
            $plan += [pscustomobject]@{ Kind = 'AddSheet'; Sheet = $title }
            $tabOf[$runKey] = $title
        }

        # Row 2 holds the identity, and G2/H2 in the middle of it belong to the reviewer, so
        # the same two-span treatment applies as on Overview.
        $identity = @(
            [string]$item.Job.CheckId
            [string]$item.Job.Name
            'SQL'
            [string]$(if ($entry) { $entry.Priority } else { '' })
            [string]$(if ($entry) { $entry.Category } else { '' })
            [string]$item.Job.What
            ''
            ''
            [string]$(if ($entry) { $entry.Signal } else { '' })
            [string]$(if ($entry) { $entry.SignalReason } else { '' })
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

        # Cleared before it is written, and cleared further than it is written, because a
        # check that found forty rows last run and three this one would otherwise show three
        # new rows above thirty-seven stale ones - which reads as forty findings.
        $previousRows = 0
        if ($Existing -and $Existing.ResultRowsOf -and $Existing.ResultRowsOf.ContainsKey($runKey)) {
            $previousRows = [int]$Existing.ResultRowsOf[$runKey]
        }
        $clearTo = [math]::Max($previousRows, $written.Count) + $SheetsCheckTabResultRow
        $plan += [pscustomobject]@{
            Kind  = 'Clear'
            Sheet = $title
            Range = (New-SheetsRange -FromColumn 1 -FromRow $SheetsCheckTabResultRow `
                    -ToColumn 26 -ToRow $clearTo)
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
        }
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

    return [pscustomobject]@{
        Operations = $plan
        Cells      = $cells
        Warning    = $warning
        RowOf      = $rowOf
        TabOf      = $tabOf
    }
}
