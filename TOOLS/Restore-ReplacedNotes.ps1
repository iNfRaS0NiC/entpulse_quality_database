<#
.SYNOPSIS
    Puts back the reviewer notes that were replaced on a board between 2026-08-31 and 2026-09-10.

.DESCRIPTION
    A one-off repair, written for a defect that no longer happens.

    From 2026-08-31 until 2026-09-10 a row marked `Fixed` that came back in the result had its
    Review Note replaced outright with why it was still there - `No Change`, or `Other issue for
    the same event`. The reviewer's own sentence went to the `Review log` tab and nowhere else.
    On 2026-09-10 that cost `Biathlon-DQ-084 PARTICIPANT_MISSING_DATE_OF_BIRTH` a column of dates
    of birth somebody had gone and found, one per row, in a single run.

    Sheets.ps1 now keeps the sentence and puts the reason after it in brackets -
    `2002-11-09 (No Change)` - so nothing written from that day on is lost. This restores what
    was lost before it, out of the log that kept it.

    **It reads the log and writes only Review Note cells.** For every logged row whose Why says
    the note was replaced, the finding is located on its own check tab by the same key the log
    records, and the cell is rewritten to the logged sentence with the reason it currently
    carries in brackets. A cell holding anything other than a bare reason is left alone: the
    reviewer has written since, and their newer sentence is not this script's to overwrite.

    Nothing is written without -Apply. A bare run reports what it would do, per board and per
    tab, and that is the form to read before deciding.

.PARAMETER Sport
    One sport's board. Omit for every board in TOOLS/sheet-registry.json that names a document.

.PARAMETER Apply
    Write the cells. Without it the script reports and sends nothing.

.EXAMPLE
    .\TOOLS\Restore-ReplacedNotes.ps1
    .\TOOLS\Restore-ReplacedNotes.ps1 -Sport Biathlon
    .\TOOLS\Restore-ReplacedNotes.ps1 -Sport Biathlon -Apply
#>
[CmdletBinding()]
param(
    [string]$Sport,
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'

# **Taken before the dot-source and not after.** Run-Query.ps1 declares a -Sport of its own, and
# dot-sourcing runs its param block in this scope: $Sport is rebound to that script's empty
# default and the filter below silently stops filtering. Caught on the first dry run, which
# read all nineteen boards when it had been asked for one.
$onlySport = [string]$Sport

# Run-Query.ps1 dot-sources Sheets.ps1 and the credentials with it, so the token, the retry and
# every constant this needs arrive the same way a run gets them. Asking for them twice is how
# the two would come to disagree about a column name.
. (Join-Path $PSScriptRoot 'Run-Query.ps1') -DotSourceOnly

$registryPath = Join-Path $PSScriptRoot 'sheet-registry.json'
if (-not (Test-Path -LiteralPath $registryPath)) {
    throw "TOOLS/sheet-registry.json not found. It owns which document belongs to which sport."
}
$registry = Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json

# The two sentences a replaced note was ever filed under. The first is what every run between
# 2026-08-31 and 2026-09-10 wrote; the second is what runs write now, and it is read as well so
# a board updated in between is not half-restored.
$replacedWhy = @(
    'replaced on the board with why it is still there'
    'added after the note on the board'
)

# What a cell holds when it is one of the two replacements and nothing else.
$bareReasons = @($SheetsRowReviewFixedStillOpenNote, $SheetsRowReviewFixedMovedNote)

function Test-BareReason {
    # Exactly one of the two, and an empty cell is NOT one of them.
    #
    # A cell holding a replacement is a cell this defect emptied and nobody has touched since,
    # which is the only state safe to write into. An empty one is not: the note was dropped for
    # some other reason, or a reviewer cleared it, and either way putting a sentence from the
    # log back into it would be inventing a conclusion rather than restoring one. Tightened
    # after the first dry run offered to write into one such cell on BMX-Racing.
    param([string]$Value)
    $text = ([string]$Value).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { return $false }
    foreach ($reason in $bareReasons) { if ($text -eq $reason) { return $true } }
    return $false
}

$boards = @()
foreach ($property in $registry.sports.PSObject.Properties) {
    if ($onlySport -and $property.Name -ne $onlySport) { continue }
    $id = [string]$property.Value.spreadsheetId
    if ([string]::IsNullOrWhiteSpace($id)) { continue }
    $boards += [pscustomobject]@{ Sport = $property.Name; SpreadsheetId = $id }
}
if ($boards.Count -eq 0) { throw "No board to read. Check the sport name against TOOLS/sheet-registry.json." }

Write-Host ""
Write-Host ("Restoring replaced review notes - {0} board(s){1}" -f $boards.Count,
    $(if ($Apply) { '' } else { ', reporting only' })) -ForegroundColor Cyan
Write-Host ""

$totalRestored = 0
$totalSkipped = 0

foreach ($board in $boards) {
    Write-Host ("{0}" -f $board.Sport) -ForegroundColor White

    # ---- the log, which is the only place the sentences survive
    $log = $null
    try {
        $log = Invoke-SheetsApiWithRetry -Method GET `
            -Path ("{0}/values/{1}!A1:Z20000" -f $board.SpreadsheetId,
                [uri]::EscapeDataString($SheetsReviewLogTabName))
    }
    catch {
        Write-Host "  no Review log tab, so there is nothing to restore from" -ForegroundColor DarkGray
        continue
    }

    $logValues = @($log.values)
    if ($logValues.Count -lt 2) {
        Write-Host "  the Review log is empty" -ForegroundColor DarkGray
        continue
    }

    $logHeader = @($logValues[0])
    $atCheckId = [array]::IndexOf($logHeader, 'CheckID')
    $atTab = [array]::IndexOf($logHeader, 'Check tab')
    $atKey = [array]::IndexOf($logHeader, 'Finding key')
    $atNote = [array]::IndexOf($logHeader, 'Review Note')
    $atWhy = [array]::IndexOf($logHeader, 'Why')
    if ($atCheckId -lt 0 -or $atKey -lt 0 -or $atNote -lt 0 -or $atWhy -lt 0) {
        Write-Host "  the Review log is not in the expected shape; left alone" -ForegroundColor Yellow
        continue
    }

    # tab -> key -> the sentence to put back. Later rows win: the log is appended in run order,
    # so the last thing said about a key is the last thing the cell held before this defect
    # emptied it. A row whose own note is a bare reason is not a sentence and is skipped, or a
    # second replacement would restore the first replacement.
    $wanted = @{}
    foreach ($row in @($logValues | Select-Object -Skip 1)) {
        $cells = @($row)
        $why = $(if ($cells.Count -gt $atWhy) { [string]$cells[$atWhy] } else { '' })
        $matched = $false
        foreach ($phrase in $replacedWhy) { if ($why -like ('*' + $phrase + '*')) { $matched = $true } }
        if (-not $matched) { continue }

        # A logged note that is itself a replacement is not a sentence to put back: it is what
        # a later run found in the cell and moved on again. Empty is not one either.
        $note = $(if ($cells.Count -gt $atNote) { [string]$cells[$atNote] } else { '' })
        if ([string]::IsNullOrWhiteSpace($note)) { continue }
        if (Test-BareReason -Value $note) { continue }

        $tab = $(if ($atTab -ge 0 -and $cells.Count -gt $atTab) { [string]$cells[$atTab] } else { '' })
        $key = $(if ($cells.Count -gt $atKey) { [string]$cells[$atKey] } else { '' })
        if ([string]::IsNullOrWhiteSpace($tab) -or [string]::IsNullOrWhiteSpace($key)) { continue }

        if (-not $wanted.ContainsKey($tab)) { $wanted[$tab] = @{} }
        $wanted[$tab][$key.Trim()] = $note.Trim()
    }

    if ($wanted.Keys.Count -eq 0) {
        Write-Host "  nothing in the log was replaced, so there is nothing to put back" -ForegroundColor DarkGray
        continue
    }

    # ---- each tab the log names
    $updates = @()
    $restoredHere = 0
    $skippedHere = 0

    foreach ($tab in ($wanted.Keys | Sort-Object)) {
        $values = $null
        try {
            $values = Invoke-SheetsApiWithRetry -Method GET `
                -Path ("{0}/values/{1}!A{2}:ZZ20000" -f $board.SpreadsheetId,
                    [uri]::EscapeDataString($tab), $SheetsCheckTabResultRow)
        }
        catch {
            Write-Host ("  {0}: the tab named in the log is gone" -f $tab) -ForegroundColor Yellow
            continue
        }

        $rows = @($values.values)
        if ($rows.Count -lt 2) { continue }

        $header = @($rows[0])
        $noteAt = [array]::IndexOf($header, $SheetsRowReviewColumns[1])
        if ($noteAt -lt 0) {
            Write-Host ("  {0}: no Review Note column" -f $tab) -ForegroundColor Yellow
            continue
        }
        $keyColumns = Get-SheetsFindingKeyColumns -Header $header

        for ($i = 1; $i -lt $rows.Count; $i++) {
            $row = @($rows[$i])
            $key = (Get-SheetsFindingKey -Row $row -Columns $keyColumns) -replace "`u{001F}", ' | '
            if (-not $wanted[$tab].ContainsKey($key)) { continue }

            $current = $(if ($row.Count -gt $noteAt) { [string]$row[$noteAt] } else { '' })

            # Only a cell still holding a bare reason is restored. Anything else is a reviewer
            # who has written since, and their sentence outranks a log entry from before it.
            if (-not (Test-BareReason -Value $current)) { $skippedHere++; continue }

            $reason = ([string]$current).Trim()
            $becomes = '{0} ({1})' -f $wanted[$tab][$key], $reason

            # A1 notation: the header sits on $SheetsCheckTabResultRow, so data row $i is that
            # plus $i.
            $sheetRow = $SheetsCheckTabResultRow + $i
            # ConvertTo-SheetsColumnName counts from 1 and $noteAt is an index into the header.
            $column = ConvertTo-SheetsColumnName -Index ($noteAt + 1)
            $updates += [pscustomobject]@{
                Range = ("'{0}'!{1}{2}" -f ($tab -replace "'", "''"), $column, $sheetRow)
                Value = $becomes
                Was   = $current
            }
            $restoredHere++
        }
    }

    if ($restoredHere -eq 0) {
        Write-Host ("  nothing to restore ({0} cell(s) already carry a newer note)" -f $skippedHere) -ForegroundColor DarkGray
        $totalSkipped += $skippedHere
        continue
    }

    Write-Host ("  {0} cell(s) to restore, {1} left alone" -f $restoredHere, $skippedHere) -ForegroundColor Green
    foreach ($one in ($updates | Select-Object -First 5)) {
        Write-Host ("    {0}  '{1}' -> '{2}'" -f $one.Range, $one.Was, $one.Value) -ForegroundColor DarkGray
    }
    if ($updates.Count -gt 5) {
        Write-Host ("    ... and {0} more" -f ($updates.Count - 5)) -ForegroundColor DarkGray
    }

    if ($Apply) {
        # One batch for the board. The cells are scattered across tabs and rows, and a cell at a
        # time would be one request each on a tab holding six hundred of them.
        $data = @($updates | ForEach-Object {
                @{ range = $_.Range; values = @(, @($_.Value)) }
            })
        $body = @{ valueInputOption = 'RAW'; data = $data }
        $null = Invoke-SheetsApiWithRetry -Method POST `
            -Path ("{0}/values:batchUpdate" -f $board.SpreadsheetId) -Body $body
        Write-Host ("  written" -f $updates.Count) -ForegroundColor Green
    }

    $totalRestored += $restoredHere
    $totalSkipped += $skippedHere
}

Write-Host ""
Write-Host ("{0} cell(s) {1}, {2} left alone" -f $totalRestored,
    $(if ($Apply) { 'restored' } else { 'would be restored' }), $totalSkipped) -ForegroundColor Cyan
if (-not $Apply -and $totalRestored -gt 0) {
    Write-Host "Nothing was written. Add -Apply to write the cells." -ForegroundColor Yellow
}
Write-Host ""
