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
    @{ Name = 'Status'; Width = 90 },
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
                                    textFormat      = @{ bold = $true }
                                    backgroundColor = @{ red = 0.94; green = 0.94; blue = 0.94 }
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
    Write-Host "  header, widths and time formats written" -ForegroundColor DarkGray
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
        $registry.sports.$Sport.runRequests = $true
        $json = $registry | ConvertTo-Json -Depth 8
        [IO.File]::WriteAllText($RegistryPath, ($json -replace "`r`n", "`n") + "`n", (New-Object Text.UTF8Encoding($false)))
        Write-Host "  recorded: the worker will poll this document" -ForegroundColor Green
    }
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
