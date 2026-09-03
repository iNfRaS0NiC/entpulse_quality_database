<#
.SYNOPSIS
    Create the "Run requests" and "Run approvals" tabs on a sport's live board, and protect
    each for the accounts that have to write it.

.DESCRIPTION
    Two tabs per sport document: the queue a reviewer's click writes into and the worker reads,
    and the approvals tab that authorises a whole-sport run. This script creates both, formats
    the queue, protects each of them, and records in TOOLS/sheet-registry.json that the
    document now carries the queue.

    The protection is the point, not the decoration - but it protects less than this file used
    to claim. A menu item in a container-bound Apps Script runs as the person who clicked it.
    There is no "execute as the owner" for one, whatever an installable onOpen trigger does for
    onOpen itself, so a queue tab with the owner as its only editor is a queue tab whose button
    throws "You are trying to edit a protected cell or object" for everybody else. It did, on
    Soccer, 2026-09-03, and the claim had stood in this file since it was written.

    So "Run requests" lists the owner and every requesters.allowed account as editors. That
    still keeps out anybody the document is merely shared with, and it no longer proves
    "Requested by": that cell is now a claim one of a few named accounts can write, and the
    worker reads it as a claim.

    "Run approvals" is where the boundary went. It carries the owner as its only editor, the DQ
    menu records a Request ID there before queueing a whole-sport row, and the worker runs
    *SPORT* only for an ID it finds there. A check inside RunRequests.gs could not do this job,
    because anybody who can write the queue tab reaches it without calling that file at all.

    Nothing here runs a statement or touches a check tab. The board updater leaves this tab
    alone by construction: TOOLS/Sheets.ps1 removes exactly one tab ever, Sheet1 while it is
    still empty, plus the tab of a check withdrawn from the registry.

    This file stays pure ASCII, as the other TOOLS scripts do: Windows PowerShell 5.1 reads a
    .ps1 without a BOM as ANSI, so a literal em dash would arrive mojibaked and fail to parse.

.PARAMETER Sport
    The repository slug, as in TOOLS/sheet-registry.json - Soccer, Ice-Hockey, Track-Cycling.

.PARAMETER SpreadsheetId
    Override the document the registry names. For a board that is not registered yet.

.PARAMETER Register
    After creating the tab, set runRequests to true for that sport in the registry, which is
    what makes the worker poll it. Left off, the tab is created and the worker ignores it,
    which is the right order while the Apps Script has not been deployed yet.

.PARAMETER Unprotected
    Create the tab without the protected range. For a document where the protection has to be
    arranged by hand, or a rehearsal. It leaves the allowlist as the only guard, which the
    plan is explicit is not a boundary, so the script says so when it is used.

.PARAMETER WhatIf
    Say what would be sent, send nothing.

.EXAMPLE
    .\TOOLS\Add-RunRequestsTab.ps1 -Sport Soccer -WhatIf

.EXAMPLE
    .\TOOLS\Add-RunRequestsTab.ps1 -Sport Soccer -Register
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Sport,

    [string]$SpreadsheetId,

    [switch]$Register,

    [switch]$Unprotected,

    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

. (Join-Path $PSScriptRoot 'Sheets.ps1')

$SecretsPath = Join-Path $PSScriptRoot 'secrets.local.ps1'
if (Test-Path -LiteralPath $SecretsPath) { . $SecretsPath }

$QueueSheetName = 'Run requests'
# Kept in step with the same name in TOOLS/Watch-SheetRequests.ps1, which reads it.
$ApprovalSheetName = 'Run approvals'
$RegistryPath = Join-Path $PSScriptRoot 'sheet-registry.json'

# The columns the plan names, in its order. The worker addresses rows by Request ID and never
# by row index, so this order is a convenience for the reader rather than a contract - but the
# Apps Script appends positionally, so the two files have to agree and this is where it is written.
$Columns = @(
    @{ Name = 'Request ID'; Width = 175 },
    @{ Name = 'CheckID'; Width = 150 },
    # What the ID asserts, beside the ID. CLAUDE.md's rule that a CheckID never travels alone
    # binds hardest on a row somebody is deciding about, and cancelling a request offering a
    # bare Soccer-DQ-087 is deciding blind. The Apps Script fills it from Overview at the
    # moment of the click so it is never briefly empty; the worker fills it if that failed.
    @{ Name = 'Check name'; Width = 330 },
    @{ Name = 'Requested by'; Width = 200 },
    @{ Name = 'Requested at'; Width = 150 },
    @{ Name = 'Status'; Width = 90; Align = 'CENTER' },
    # How far a run has got, written while it is still running. Beside Status because that is
    # where somebody looks when they want to know whether to keep waiting, and RUNNING on its
    # own answers that for about five seconds. A whole-board refresh is fifteen minutes, and a
    # word that does not change for fifteen minutes is indistinguishable from a wedged one.
    #
    # Status keeps its single word. It carries conditional formatting keyed on the exact text
    # and the worker matches it exactly, so a count appended to it would cost the row its
    # colour and take the request out of the worker's own open set.
    # 260 while the note carried the CheckID it was on. That was dropped after the first live
    # run - the name is stale by the time anybody reads it - and the widest thing left is
    # "113 of 113 in 15 min, 4 failed".
    @{ Name = 'Progress'; Width = 175; Align = 'CENTER' },
    @{ Name = 'Started at'; Width = 150 },
    @{ Name = 'Finished at'; Width = 150 },
    @{ Name = 'Run ID'; Width = 210 },
    @{ Name = 'Findings'; Width = 85; Align = 'CENTER' },
    # What the board showed before this run, and the arithmetic between them. Both come out of
    # the sentence the runner already prints for a single re-run - "Improved: 4 finding(s) of
    # 27858 eligible, expected Zero (was 11, run Soccer 01.09.2026 19-31-04)" - so neither
    # costs a read. Verdict beside them is the board's own word for the same movement.
    @{ Name = 'Findings before'; Width = 110; Align = 'CENTER' },
    @{ Name = 'Change'; Width = 95; Align = 'CENTER' },
    @{ Name = 'Eligible'; Width = 90; Align = 'CENTER' },
    @{ Name = 'Verdict'; Width = 120 },
    @{ Name = 'Error'; Width = 420 }
)

function Get-ColumnIndex {
    # Zero-based, by name. Every request below addresses a column through this rather than by
    # a number written twice: two columns were inserted into the middle of this list on
    # 2026-09-01, and every hardcoded index would have moved silently.
    param([string]$Name)
    for ($i = 0; $i -lt $Columns.Count; $i++) {
        if ($Columns[$i].Name -eq $Name) { return $i }
    }
    throw "There is no column called '$Name' in this script's column list."
}

function Read-Registry {
    if (-not (Test-Path -LiteralPath $RegistryPath)) {
        throw "TOOLS/sheet-registry.json not found. It owns which document belongs to which sport."
    }
    return (Get-Content -LiteralPath $RegistryPath -Raw -Encoding UTF8 | ConvertFrom-Json)
}

$registry = Read-Registry

if ([string]::IsNullOrWhiteSpace($SpreadsheetId)) {
    if (-not ($registry.sports.PSObject.Properties.Name -contains $Sport)) {
        throw ("$Sport has no row in TOOLS/sheet-registry.json. Add it, or pass -SpreadsheetId " +
            "for a board that is not registered yet.")
    }
    $SpreadsheetId = [string]$registry.sports.$Sport.spreadsheetId
}
if ([string]::IsNullOrWhiteSpace($SpreadsheetId)) {
    throw "$Sport names no document."
}

Write-Host ""
Write-Host ("{0} -> {1}" -f $Sport, $SpreadsheetId) -ForegroundColor Cyan

# ----- what is there already ------------------------------------------------------------

$existingSheetId = $null
$title = ''
if (-not $WhatIf) {
    $book = Invoke-SheetsApiWithRetry -Method GET -Path ("$SpreadsheetId" + '?fields=properties.title,sheets.properties')
    $title = [string]$book.properties.title
    foreach ($sheet in @($book.sheets)) {
        if ([string]$sheet.properties.title -eq $QueueSheetName) {
            $existingSheetId = [int]$sheet.properties.sheetId
        }
    }
    Write-Host ("  document: {0}" -f $title) -ForegroundColor DarkGray
}

if ($null -ne $existingSheetId) {
    Write-Host ("  '{0}' is already there (sheet {1}); leaving it and its rows alone." -f `
            $QueueSheetName, $existingSheetId) -ForegroundColor Yellow
}
else {
    # ----- create it --------------------------------------------------------------------

    $addSheet = @{
        addSheet = @{
            properties = @{
                title          = $QueueSheetName
                index          = 1
                gridProperties = @{
                    rowCount         = 1000
                    columnCount      = $Columns.Count
                    frozenRowCount   = 1
                }
                tabColor       = @{ red = 0.85; green = 0.60; blue = 0.15 }
            }
        }
    }

    if ($WhatIf) {
        Write-Host ("  would create '{0}' with {1} columns and a frozen header" -f `
                $QueueSheetName, $Columns.Count) -ForegroundColor DarkGray
    }
    else {
        $created = Invoke-SheetsApiWithRetry -Method POST -Path "$SpreadsheetId`:batchUpdate" `
            -Body @{ requests = @($addSheet) }
        $existingSheetId = [int]$created.replies[0].addSheet.properties.sheetId
        Write-Host ("  created '{0}' as sheet {1}" -f $QueueSheetName, $existingSheetId) -ForegroundColor Green
    }
}

# ----- a tab written before a column existed ----------------------------------------------
#
# The header is rewritten below whatever happens. On a tab that already holds rows that is not
# enough on its own: writing "Check name" over what used to be "Requested by" leaves every
# existing row one column out of step with the header describing it, and the worker addresses
# cells by column name. So a column that is missing is inserted, which shifts the rows with it,
# before anything is written.
#
# Only insertion, and only in order. A header that has the right names in the wrong order, or a
# name this script does not know, is somebody else's edit or a layout this script is too old to
# understand, and both are reported rather than guessed at.

if (-not $WhatIf -and $null -ne $existingSheetId) {
    $headerRange = [uri]::EscapeDataString("$QueueSheetName!1:1")
    $headerRead = Invoke-SheetsApiWithRetry -Method GET -Path "$SpreadsheetId/values/$headerRange"
    $actual = @()
    if ($headerRead.values -and @($headerRead.values).Count -gt 0) {
        $actual = @(@($headerRead.values)[0] | ForEach-Object { ([string]$_).Trim() })
    }

    if ($actual.Count -gt 0) {
        $unknown = @($actual | Where-Object { $_ -and -not ($Columns.Name -contains $_) })
        if ($unknown.Count -gt 0) {
            throw ("The '$QueueSheetName' tab has column(s) this script does not know: " +
                ($unknown -join ', ') + ". Nothing was changed. Either somebody added them by " +
                'hand, or this script is older than the tab.')
        }

        $inserts = @()
        $working = [Collections.ArrayList]@($actual)
        for ($i = 0; $i -lt $Columns.Count; $i++) {
            $want = [string]$Columns[$i].Name
            if ($i -lt $working.Count -and $working[$i] -eq $want) { continue }
            if ($working -contains $want) {
                throw ("The '$QueueSheetName' tab has '$want' at column " +
                    ([int]($working.IndexOf($want)) + 1) + ' where this script expects column ' +
                    ($i + 1) + '. Reordering a column would move the rows under it, so nothing ' +
                    'was changed.')
            }
            $inserts += @{
                insertDimension = @{
                    range        = @{
                        sheetId    = $existingSheetId
                        dimension  = 'COLUMNS'
                        startIndex = $i
                        endIndex   = $i + 1
                    }
                    # The new column takes the tab's plain format, not a copy of its neighbour's.
                    inheritFromBefore = $false
                }
            }
            [void]$working.Insert($i, $want)
        }

        if ($inserts.Count -gt 0) {
            [void](Invoke-SheetsApiWithRetry -Method POST -Path "$SpreadsheetId`:batchUpdate" `
                    -Body @{ requests = $inserts })
            Write-Host ("  inserted {0} new column(s), shifting the existing rows with them: {1}" -f `
                    $inserts.Count, ((0..($Columns.Count - 1) | Where-Object { -not ($actual -contains $Columns[$_].Name) } |
                        ForEach-Object { $Columns[$_].Name }) -join ', ')) -ForegroundColor Green
        }
    }
}

# ----- header, widths, formats ----------------------------------------------------------

if (-not $WhatIf -and $null -ne $existingSheetId) {
    $requests = @()

    $requests += @{
        updateCells = @{
            range  = @{ sheetId = $existingSheetId; startRowIndex = 0; endRowIndex = 1 }
            rows   = @(@{ values = @($Columns | ForEach-Object {
                            @{
                                userEnteredValue  = @{ stringValue = $_.Name }
                                userEnteredFormat = @{
                                    # The crimson the board's own Overview header wears, read off
                                    # the document rather than guessed, so the queue looks like
                                    # part of the board and not like something bolted to it.
                                    backgroundColor    = @{ red = 0.792; green = 0.09; blue = 0.267 }
                                    horizontalAlignment = $(if ($_.Align) { $_.Align } else { 'LEFT' })
                                    verticalAlignment  = 'MIDDLE'
                                    textFormat         = @{
                                        bold            = $true
                                        fontFamily      = 'Roboto'
                                        fontSize        = 10
                                        foregroundColor = @{ red = 1; green = 1; blue = 1 }
                                    }
                                }
                            }
                        }) })
            fields = 'userEnteredValue,userEnteredFormat'
        }
    }

    for ($i = 0; $i -lt $Columns.Count; $i++) {
        $requests += @{
            updateDimensionProperties = @{
                range      = @{
                    sheetId    = $existingSheetId
                    dimension  = 'COLUMNS'
                    startIndex = $i
                    endIndex   = $i + 1
                }
                properties = @{ pixelSize = [int]$Columns[$i].Width }
                fields     = 'pixelSize'
            }
        }
    }

    # A column that declares an alignment gets it on its rows as well as its header, or the
    # header sits centred over a left-hand stack of words. Status is the only one so far: its
    # value comes from a fixed set of six, and centred it reads as a badge rather than as a
    # sentence that happens to be short.
    for ($i = 0; $i -lt $Columns.Count; $i++) {
        if (-not $Columns[$i].Align) { continue }
        $requests += @{
            repeatCell = @{
                range  = @{ sheetId = $existingSheetId; startRowIndex = 1; startColumnIndex = $i; endColumnIndex = $i + 1 }
                cell   = @{ userEnteredFormat = @{ horizontalAlignment = [string]$Columns[$i].Align } }
                fields = 'userEnteredFormat.horizontalAlignment'
            }
        }
    }

    # Progress is the one column whose text is bold. The row's colour already says which state
    # the request is in, so what a reader wants next is the figure - and it is a number sitting
    # among fifteen columns of words. Bold on the Status word was what this replaced: it shouted
    # the one thing the colour had already said, and left the number to be hunted for.
    $requests += @{
        repeatCell = @{
            range  = @{
                sheetId          = $existingSheetId
                startRowIndex    = 1
                startColumnIndex = (Get-ColumnIndex 'Progress')
                endColumnIndex   = (Get-ColumnIndex 'Progress') + 1
            }
            cell   = @{ userEnteredFormat = @{ textFormat = @{ bold = $true } } }
            # Named to the single property. Anything broader would take the header's own bold
            # with it, because the header is written by a different request to this same range.
            fields = 'userEnteredFormat.textFormat.bold'
        }
    }

    # The three timestamps read as times rather than as numbers, which is the difference
    # between a person seeing when a run started and seeing 45901.6.
    foreach ($column in @((Get-ColumnIndex 'Requested at'), (Get-ColumnIndex 'Started at'), (Get-ColumnIndex 'Finished at'))) {
        $requests += @{
            repeatCell = @{
                range  = @{ sheetId = $existingSheetId; startRowIndex = 1; startColumnIndex = $column; endColumnIndex = $column + 1 }
                cell   = @{ userEnteredFormat = @{ numberFormat = @{ type = 'DATE_TIME'; pattern = 'dd.MM.yyyy HH:mm:ss' } } }
                fields = 'userEnteredFormat.numberFormat'
            }
        }
    }

    [void](Invoke-SheetsApiWithRetry -Method POST -Path "$SpreadsheetId`:batchUpdate" -Body @{ requests = $requests })
    Write-Host "  header, widths, alignment and time formats written" -ForegroundColor DarkGray
}

# ----- colour ----------------------------------------------------------------------------
#
# A queue is read at a glance or it is not read at all: the eye should find the one red row
# without reading twelve columns. Status carries the colour because it is the only cell whose
# value is a state, and the three states somebody is actually scanning for - DONE, ERROR and
# RUNNING - tint the whole row as well. A tint on one cell in sixteen is found by reading, not
# by glancing, which is the whole thing it was for.
#
# Both the banding and the rules are removed before they are added. Sheets appends rather than
# replaces, so running this script twice on a document would otherwise leave two bands and
# twelve rules stacked on the same cells.

if (-not $WhatIf -and $null -ne $existingSheetId) {
    $tidy = @()

    $current = Invoke-SheetsApiWithRetry -Method GET -Path ("$SpreadsheetId" +
        '?fields=sheets(properties.sheetId,bandedRanges,conditionalFormats)')
    foreach ($sheet in @($current.sheets)) {
        if ([int]$sheet.properties.sheetId -ne $existingSheetId) { continue }

        if ($null -ne $sheet.bandedRanges) {
            foreach ($band in @($sheet.bandedRanges)) {
                $tidy += @{ deleteBanding = @{ bandedRangeId = [int]$band.bandedRangeId } }
            }
        }
        if ($null -ne $sheet.conditionalFormats) {
            # Backwards: each delete shifts the indexes of the rules after it.
            for ($i = @($sheet.conditionalFormats).Count - 1; $i -ge 0; $i--) {
                $tidy += @{ deleteConditionalFormatRule = @{ sheetId = $existingSheetId; index = $i } }
            }
        }
    }

    $tidy += @{
        addBanding = @{
            bandedRange = @{
                range          = @{ sheetId = $existingSheetId; startRowIndex = 1 }
                rowProperties  = @{
                    firstBandColor  = @{ red = 1; green = 1; blue = 1 }
                    secondBandColor = @{ red = 0.976; green = 0.976; blue = 0.980 }
                }
            }
        }
    }

    # Status, one colour per state, in the order a request moves through them. Row says whether
    # the state also tints its whole row: the three a person scans the queue for do, and the
    # three that are only bookkeeping - queued, waiting, cancelled - keep to their own cell.
    #
    # A tinted row is the same colour as its Status cell and not a paler version of it, so the
    # two cannot disagree about where the row begins. ERROR is #f4c6c3.
    $states = @(
        @{ Word = 'QUEUED';    Back = @(0.925, 0.937, 0.953); Fore = @(0.30, 0.35, 0.42); Row = $false },
        @{ Word = 'WAITING';   Back = @(1.000, 0.949, 0.800); Fore = @(0.55, 0.42, 0.00); Row = $false },
        @{ Word = 'RUNNING';   Back = @(0.816, 0.886, 0.973); Fore = @(0.05, 0.28, 0.63); Row = $true },
        @{ Word = 'DONE';      Back = @(0.851, 0.918, 0.827); Fore = @(0.11, 0.37, 0.13); Row = $true },
        @{ Word = 'ERROR';     Back = @(0.957, 0.776, 0.765); Fore = @(0.64, 0.11, 0.07); Row = $true },
        @{ Word = 'CANCELLED'; Back = @(0.937, 0.937, 0.937); Fore = @(0.50, 0.50, 0.50); Row = $false }
    )

    # The row rules are added before the Status ones so that they end up underneath them. Every
    # rule here is inserted at index 0, so the last one added sits on top - and a rule on top
    # claims the properties it names. Status keeps its own cell, the row rule takes the other
    # fifteen columns, and nothing depends on how Sheets resolves two rules over one cell: they
    # claim the same colour, and only the Status rule claims a text colour at all.
    #
    # The Status column's own letter, derived rather than typed: this was $E until two columns
    # were inserted to its left.
    $statusLetter = [char]([int][char]'A' + (Get-ColumnIndex 'Status'))

    foreach ($state in @($states | Where-Object { $_.Row })) {
        $tidy += @{
            addConditionalFormatRule = @{
                index = 0
                rule  = @{
                    ranges      = @(@{
                            sheetId          = $existingSheetId
                            startRowIndex    = 1
                            startColumnIndex = 0
                            endColumnIndex   = $Columns.Count
                        })
                    booleanRule = @{
                        condition = @{ type = 'CUSTOM_FORMULA'; values = @(@{
                                    userEnteredValue = ('=${0}2="{1}"' -f $statusLetter, $state.Word) }) }
                        format    = @{
                            backgroundColor = @{ red = $state.Back[0]; green = $state.Back[1]; blue = $state.Back[2] }
                        }
                    }
                }
            }
        }
    }

    foreach ($state in $states) {
        $tidy += @{
            addConditionalFormatRule = @{
                index = 0
                rule  = @{
                    ranges      = @(@{
                            sheetId          = $existingSheetId
                            startRowIndex    = 1
                            startColumnIndex = (Get-ColumnIndex 'Status')
                            endColumnIndex   = (Get-ColumnIndex 'Status') + 1
                        })
                    booleanRule = @{
                        condition = @{ type = 'TEXT_EQ'; values = @(@{ userEnteredValue = $state.Word }) }
                        format    = @{
                            backgroundColor = @{ red = $state.Back[0]; green = $state.Back[1]; blue = $state.Back[2] }
                            # No bold here any more. It belongs to Progress alone, and a Status
                            # word that is both coloured and bold says its one thing twice.
                            textFormat      = @{
                                foregroundColor = @{ red = $state.Fore[0]; green = $state.Fore[1]; blue = $state.Fore[2] }
                            }
                        }
                    }
                }
            }
        }
    }

    # The faint ERROR row this replaced was #fef2f0 - a tint so light that the row it marked
    # still had to be found by reading the Status column, which is the step it existed to save.

    [void](Invoke-SheetsApiWithRetry -Method POST -Path "$SpreadsheetId`:batchUpdate" -Body @{ requests = $tidy })
    Write-Host ('  banded, Status coloured per state, and the whole row tinted for {0}' -f `
        ((@($states | Where-Object { $_.Row } | ForEach-Object { $_.Word })) -join ', ')) -ForegroundColor DarkGray
}

# ----- the boundary that actually holds --------------------------------------------------

if ($Unprotected) {
    Write-Host ("  -Unprotected: the tab is open to every editor of this document. The allowed " +
        "list then guards against a mistake and not against intent, because 'Requested by' is a " +
        "cell anybody can type into.") -ForegroundColor Yellow
}
elseif ($WhatIf) {
    Write-Host ("  would protect the whole tab, with the owner and the {0} allowed account(s) as " +
        "its editors" -f @($registry.requesters.allowed).Count) -ForegroundColor DarkGray
}
elseif ($null -ne $existingSheetId) {
    $already = $false
    $protection = Invoke-SheetsApiWithRetry -Method GET -Path ("$SpreadsheetId" + '?fields=sheets(properties.sheetId,protectedRanges)')
    foreach ($sheet in @($protection.sheets)) {
        if ([int]$sheet.properties.sheetId -ne $existingSheetId) { continue }
        # Not @($sheet.protectedRanges).Count on its own: an absent field is $null, and
        # @($null) is an array of one in PowerShell, so an unprotected tab read as protected
        # and this script reported a boundary it had not created. Measured on Soccer,
        # 2026-09-01, on the first real run.
        if ($null -ne $sheet.protectedRanges -and @($sheet.protectedRanges).Count -gt 0) {
            $already = $true
        }
    }

    if ($already) {
        Write-Host "  the tab is already protected; leaving the existing protection alone" -ForegroundColor Yellow
    }
    else {
        # Every allowed account is an editor here, and that is not a weakening of the boundary
        # but the only shape it can take. A menu item runs as the person who clicked it - there
        # is no "execute as the owner" for one, whatever an installable onOpen trigger does for
        # onOpen itself - so a tab the owner alone may edit is a tab whose button fails for
        # everybody else. It did, with "You are trying to edit a protected cell or object", on
        # Soccer 2026-09-03.
        #
        # What the tab still keeps out is every account not on the list, including anybody the
        # document is merely shared with. What it no longer proves is `Requested by`, which is
        # now a claim one of five accounts can write. The whole-sport gate moved to
        # `Run approvals` below for exactly that reason.
        $queueEditors = @(@($registry.requesters.owner) + @($registry.requesters.allowed) |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
        $protect = @{
            addProtectedRange = @{
                protectedRange = @{
                    range         = @{ sheetId = $existingSheetId }
                    description   = 'The DQ run queue. Appended by the DQ menu as the person clicking it, and by the runner on the owner machine.'
                    warningOnly   = $false
                    requestingUserCanEdit = $true
                    editors       = @{ users = $queueEditors; domainUsersCanEdit = $false }
                }
            }
        }
        [void](Invoke-SheetsApiWithRetry -Method POST -Path "$SpreadsheetId`:batchUpdate" -Body @{ requests = @($protect) })
        Write-Host ("  protected: {0} account(s) may write it, and nobody else" -f $queueEditors.Count) -ForegroundColor Green
    }
}

# ----- the one tab the owner keeps to themselves -------------------------------------------
#
# A whole-sport run costs about fifteen minutes, holds the machine lock for all of it and
# repaints a board, so it is the one request that is the owner's alone. It cannot be gated by
# `Requested by`, which every account on the queue's editor list can now type, nor by a check
# inside RunRequests.gs, which anybody who can write the queue tab bypasses by not calling it.
#
# So it is gated by a write nobody else is permitted to make. The DQ menu records the Request ID
# here before it queues the row; the worker runs *SPORT* only for an ID it finds here. The
# protection is the authorisation, and there is no code path around it.

if ($Unprotected) {
    Write-Host "  -Unprotected: no approvals tab either, so no whole-sport run can be authorised" -ForegroundColor Yellow
}
elseif ($WhatIf) {
    Write-Host "  would create '$ApprovalSheetName', protected with the owner as its only editor" -ForegroundColor DarkGray
}
else {
    $book = Invoke-SheetsApiWithRetry -Method GET -Path ("$SpreadsheetId" + '?fields=sheets(properties(sheetId,title),protectedRanges)')
    $approvalSheetId = $null
    $approvalProtected = $false
    foreach ($sheet in @($book.sheets)) {
        if ([string]$sheet.properties.title -ne $ApprovalSheetName) { continue }
        $approvalSheetId = [int]$sheet.properties.sheetId
        if ($null -ne $sheet.protectedRanges -and @($sheet.protectedRanges).Count -gt 0) {
            $approvalProtected = $true
        }
    }

    if ($null -eq $approvalSheetId) {
        $made = Invoke-SheetsApiWithRetry -Method POST -Path "$SpreadsheetId`:batchUpdate" -Body @{
            requests = @(@{ addSheet = @{ properties = @{
                            title          = $ApprovalSheetName
                            gridProperties = @{ rowCount = 1000; columnCount = 3; frozenRowCount = 1 }
                        } } })
        }
        $approvalSheetId = [int]$made.replies[0].addSheet.properties.sheetId
        Write-Host "  created '$ApprovalSheetName'" -ForegroundColor Green
    }
    else {
        Write-Host "  '$ApprovalSheetName' is already there" -ForegroundColor DarkGray
    }

    # Written every time and not only on creation, so a tab left half-made by an interrupted
    # run is finished by the next one rather than staying headerless for ever. Three cells of
    # RAW over three cells that already say the same thing costs nothing.
    #
    # values:batchUpdate, as everything else here writes. A POST to /values/{range} is only a
    # route as :append; plain, it is not one, and Google answers with the HTML of its 404 page
    # rather than an API error - which is a puzzling thing to find in a console. Measured here
    # on Soccer, 2026-09-03.
    [void](Invoke-SheetsApiWithRetry -Method POST -Path "$SpreadsheetId/values:batchUpdate" -Body @{
            valueInputOption = 'RAW'
            data             = @(@{
                    range  = "$ApprovalSheetName!A1:C1"
                    values = @(, @('Request ID', 'Approved at', 'Approved by'))
                })
        })

    if ($approvalProtected) {
        Write-Host "  its protection is already set; leaving it alone" -ForegroundColor Yellow
    }
    else {
        # No `users` here, deliberately, and this is the one place that stays that way: the
        # owner is the only editor, so the only account that can approve a whole-sport run is
        # the one running the machine that would perform it.
        [void](Invoke-SheetsApiWithRetry -Method POST -Path "$SpreadsheetId`:batchUpdate" -Body @{
            requests = @(@{ addProtectedRange = @{ protectedRange = @{
                            range                 = @{ sheetId = $approvalSheetId }
                            description           = 'Whole-sport approvals. The owner is the only editor, and that is what authorises a *SPORT* run.'
                            warningOnly           = $false
                            requestingUserCanEdit = $true
                            editors               = @{ domainUsersCanEdit = $false }
                        } } })
        })
        Write-Host "  protected: the owner alone, which is what makes it an approval" -ForegroundColor Green
    }
}

# ----- record it -------------------------------------------------------------------------

if ($Register) {
    if ($WhatIf) {
        Write-Host "  would set runRequests = true for $Sport in TOOLS/sheet-registry.json" -ForegroundColor DarkGray
    }
    elseif (-not ($registry.sports.PSObject.Properties.Name -contains $Sport)) {
        Write-Host ("  {0} has no row in the registry, so nothing was recorded. Add the row first." -f $Sport) -ForegroundColor Yellow
    }
    else {
        # One flag, edited in place, and never a reserialise of the whole file. Windows
        # PowerShell 5.1's ConvertTo-Json replaces every apostrophe and angle bracket with its
        # numeric escape and reindents to its own style, so setting this one boolean through it
        # rewrote all eighty lines and left the three prose _about fields unreadable. Measured
        # on the first real -Register, Soccer, 2026-09-01. This file is read by people as well
        # as by scripts, so its formatting is part of it.
        $raw = Get-Content -LiteralPath $RegistryPath -Raw -Encoding UTF8
        # [^}] and not . - a sport's block contains no brace of its own, and a lazy dot walked
        # straight past this sport's "runRequests": true into the next sport's false and flipped
        # that one instead. Caught on Soccer 2026-09-01, having turned on Speed-Skating, which
        # has no queue tab: the worker would have polled a document with nothing to read.
        $pattern = '("' + [regex]::Escape($Sport) + '"\s*:\s*\{[^}]*?"runRequests"\s*:\s*)false'
        $rx = New-Object Text.RegularExpressions.Regex($pattern)

        if (-not $rx.IsMatch($raw)) {
            Write-Host ("  {0} already has runRequests = true; the file was left alone." -f $Sport) -ForegroundColor DarkGray
        }
        else {
            $updated = $rx.Replace($raw, '${1}true', 1)
            [IO.File]::WriteAllText($RegistryPath, $updated, (New-Object Text.UTF8Encoding($false)))
            Write-Host "  recorded: the worker will poll this document" -ForegroundColor Green
        }
    }
}
elseif ($registry.sports.PSObject.Properties.Name -contains $Sport -and $registry.sports.$Sport.runRequests) {
    Write-Host '  already registered; the worker polls this document' -ForegroundColor DarkGray
}
else {
    Write-Host ("  not registered. The worker ignores this document until " +
        "runRequests is true - run again with -Register once the Apps Script is deployed.") -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Next, by hand and in the browser:" -ForegroundColor Cyan
Write-Host "  1. Extensions > Apps Script, paste TOOLS/sheets-apps-script/RunRequests.gs" -ForegroundColor DarkGray
Write-Host "  2. Project Settings > show appsscript.json, paste the one beside it" -ForegroundColor DarkGray
Write-Host "  3. Reload the document and check the DQ menu appears." -ForegroundColor DarkGray
Write-Host "     A simple onOpen builds the menu for anybody who may open the document; no" -ForegroundColor DarkGray
Write-Host "     installable trigger is needed, and one would not change who a menu item runs as." -ForegroundColor DarkGray
Write-Host "  4. Each colleague authorises the script once, on their first click." -ForegroundColor DarkGray
Write-Host ""
