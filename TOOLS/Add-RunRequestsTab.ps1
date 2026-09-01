<#
.SYNOPSIS
    Create the "Run requests" tab on a sport's live board, and protect it.

.DESCRIPTION
    One tab per sport document, holding the queue a reviewer's click writes into and the
    worker reads. This script creates it, formats it, protects it, and records in
    TOOLS/sheet-registry.json that the document now carries it.

    The protection is the point, not the decoration. TOOLS/sheets-apps-script/RunRequests.gs
    validates who is clicking, but "Requested by" is a cell: anybody with edit access to the
    tab could type somebody else's address into it as easily as a CheckID, so an allowlist
    keyed on it guards against a mistake and not against intent. The boundary that holds is
    edit access. This adds a protected range over the whole tab with no other editors, which
    leaves the tab writable by the owner and by anything running as the owner - the Apps
    Script, deployed to execute as the owner, and the worker on the owner's machine - and by
    nobody else. Reviewers keep the button and lose the keyboard.

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
$RegistryPath = Join-Path $PSScriptRoot 'sheet-registry.json'

# The columns the plan names, in its order. The worker addresses rows by Request ID and never
# by row index, so this order is a convenience for the reader rather than a contract - but the
# Apps Script appends positionally, so the two files have to agree and this is where it is written.
$Columns = @(
    @{ Name = 'Request ID'; Width = 190 },
    @{ Name = 'CheckID'; Width = 150 },
    @{ Name = 'Requested by'; Width = 210 },
    @{ Name = 'Requested at'; Width = 150 },
    @{ Name = 'Status'; Width = 90; Align = 'CENTER' },
    @{ Name = 'Started at'; Width = 150 },
    @{ Name = 'Finished at'; Width = 150 },
    @{ Name = 'Run ID'; Width = 210 },
    @{ Name = 'Findings'; Width = 80 },
    @{ Name = 'Eligible'; Width = 80 },
    @{ Name = 'Verdict'; Width = 120 },
    @{ Name = 'Error'; Width = 420 }
)

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

    # The three timestamps read as times rather than as numbers, which is the difference
    # between a person seeing when a run started and seeing 45901.6.
    foreach ($column in @(3, 5, 6)) {
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
# value is a state, and a whole row is tinted only for ERROR, which is the one a person has to
# do something about.
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

    # Status, one colour per state, in the order a request moves through them.
    $states = @(
        @{ Word = 'QUEUED';    Back = @(0.925, 0.937, 0.953); Fore = @(0.30, 0.35, 0.42) },
        @{ Word = 'WAITING';   Back = @(1.000, 0.949, 0.800); Fore = @(0.55, 0.42, 0.00) },
        @{ Word = 'RUNNING';   Back = @(0.816, 0.886, 0.973); Fore = @(0.05, 0.28, 0.63) },
        @{ Word = 'DONE';      Back = @(0.851, 0.918, 0.827); Fore = @(0.11, 0.37, 0.13) },
        @{ Word = 'ERROR';     Back = @(0.957, 0.780, 0.765); Fore = @(0.64, 0.11, 0.07) },
        @{ Word = 'CANCELLED'; Back = @(0.937, 0.937, 0.937); Fore = @(0.50, 0.50, 0.50) }
    )

    foreach ($state in $states) {
        $tidy += @{
            addConditionalFormatRule = @{
                index = 0
                rule  = @{
                    ranges      = @(@{
                            sheetId          = $existingSheetId
                            startRowIndex    = 1
                            startColumnIndex = 4
                            endColumnIndex   = 5
                        })
                    booleanRule = @{
                        condition = @{ type = 'TEXT_EQ'; values = @(@{ userEnteredValue = $state.Word }) }
                        format    = @{
                            backgroundColor = @{ red = $state.Back[0]; green = $state.Back[1]; blue = $state.Back[2] }
                            textFormat      = @{
                                bold            = $true
                                foregroundColor = @{ red = $state.Fore[0]; green = $state.Fore[1]; blue = $state.Fore[2] }
                            }
                        }
                    }
                }
            }
        }
    }

    # The whole row for a failure, faintly. A refusal is the one row somebody has to act on,
    # and its reason is twelve columns to the right of the status that announces it.
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
                    condition = @{ type = 'CUSTOM_FORMULA'; values = @(@{ userEnteredValue = '=$E2="ERROR"' }) }
                    format    = @{ backgroundColor = @{ red = 0.996; green = 0.949; blue = 0.941 } }
                }
            }
        }
    }

    [void](Invoke-SheetsApiWithRetry -Method POST -Path "$SpreadsheetId`:batchUpdate" -Body @{ requests = $tidy })
    Write-Host '  banded, and Status coloured per state with a failed row tinted whole' -ForegroundColor DarkGray
}

# ----- the boundary that actually holds --------------------------------------------------

if ($Unprotected) {
    Write-Host ("  -Unprotected: the tab is open to every editor of this document. The allowed " +
        "list then guards against a mistake and not against intent, because 'Requested by' is a " +
        "cell anybody can type into.") -ForegroundColor Yellow
}
elseif ($WhatIf) {
    Write-Host "  would protect the whole tab, leaving the owner as its only editor" -ForegroundColor DarkGray
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
        # No `users` and no `domainUsersCanEdit`: the owner stays the only editor, and so does
        # anything running as the owner. That is exactly the Apps Script deployed to execute as
        # the owner, which is what lets the button keep working for the people who may click it.
        $protect = @{
            addProtectedRange = @{
                protectedRange = @{
                    range         = @{ sheetId = $existingSheetId }
                    description   = 'The DQ run queue. Written by the DQ menu and by the runner on the owner machine.'
                    warningOnly   = $false
                    requestingUserCanEdit = $true
                    editors       = @{ domainUsersCanEdit = $false }
                }
            }
        }
        [void](Invoke-SheetsApiWithRetry -Method POST -Path "$SpreadsheetId`:batchUpdate" -Body @{ requests = @($protect) })
        Write-Host "  protected: the owner is the only editor, so the tab is reachable through the button and not by hand" -ForegroundColor Green
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
Write-Host "  3. Deploy > Test deployments is not enough: the trigger has to run as the owner." -ForegroundColor DarkGray
Write-Host "     Add an installable onOpen trigger owned by the owner account." -ForegroundColor DarkGray
Write-Host "  4. Reload the document and check the DQ menu appears." -ForegroundColor DarkGray
Write-Host ""
