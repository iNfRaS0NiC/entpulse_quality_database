<#
.SYNOPSIS
    Static consistency check for the Project 2.0 package.

.DESCRIPTION
    Verifies mechanically everything the repository asserts about itself: SQL identity
    headers, CheckID uniqueness, the DQ coverage contract, UNION ALL column counts,
    registry-versus-SQL agreement, declared parameters, paste markers and the sport index.

    It parses; it does not execute. Live permissions, runtime cost and result semantics are
    outside its reach; that boundary is stated in the report it writes.

    Rules live in their owners (POWERBI.md, WORKFLOW.md, GLOBAL_QUERIES/README.md,
    GLOBAL_DQ/README.md). This script encodes them; it does not redefine them.

.PARAMETER ReportPath
    Write VALIDATION_REPORT.md from this run instead of only printing. The report is
    generated output: edit the script, not the report.

.EXAMPLE
    .\TOOLS\Test-Package.ps1

.EXAMPLE
    .\TOOLS\Test-Package.ps1 -ReportPath .\VALIDATION_REPORT.md
#>
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$ReportPath,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

# This file stays pure ASCII, as Run-Query.ps1 does: Windows PowerShell 5.1 reads a .ps1
# without a BOM as ANSI, so a literal em dash would arrive mojibaked and fail to parse.
# The character still has to be produced, because a deprecated registry row uses it.
$EmDash = [string][char]0x2014

if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent $PSScriptRoot }
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path

# --------------------------------------------------------------------------------------
# Result collection
# --------------------------------------------------------------------------------------

$script:Results = @()
$script:Metrics = [ordered]@{}

function Add-Result {
    param(
        [string]$Group,
        [string]$Name,
        [string[]]$Findings = @(),
        [switch]$Skipped
    )

    $status = 'PASS'
    if ($Skipped) { $status = 'SKIP' }
    elseif ($Findings.Count -gt 0) { $status = 'FAIL' }

    $script:Results += [pscustomobject]@{
        Group    = $Group
        Name     = $Name
        Status   = $status
        Findings = $Findings
    }
}

function Set-Metric {
    param([string]$Name, $Value)
    $script:Metrics[$Name] = $Value
}

function Get-RelativePath {
    param([string]$Path)
    return $Path.Substring($RepoRoot.Length).TrimStart('\', '/') -replace '\\', '/'
}

# --------------------------------------------------------------------------------------
# SQL masking
#
# Column counting, LIMIT placement and UNION ALL splitting all need to know whether a
# character sits inside a string literal, inside a comment, or inside parentheses. Masking
# replaces literals and comments with same-length filler so every index still lines up
# with the original text, then a depth array answers the parenthesis question.
# --------------------------------------------------------------------------------------

function Get-MaskedSql {
    param([string]$Sql)

    $chars = $Sql.ToCharArray()
    $out = New-Object 'System.Text.StringBuilder'
    $inString = $false
    $inComment = $false
    $i = 0

    while ($i -lt $chars.Length) {
        $c = $chars[$i]

        if ($inComment) {
            if ($c -eq "`n") { $inComment = $false; [void]$out.Append($c) }
            else { [void]$out.Append(' ') }
            $i++
            continue
        }

        if ($inString) {
            # '' is an escaped quote inside a literal; \' is MySQL's backslash escape.
            if ($c -eq '\' -and $i + 1 -lt $chars.Length) {
                [void]$out.Append('x'); [void]$out.Append('x'); $i += 2; continue
            }
            if ($c -eq "'") {
                if ($i + 1 -lt $chars.Length -and $chars[$i + 1] -eq "'") {
                    [void]$out.Append('x'); [void]$out.Append('x'); $i += 2; continue
                }
                $inString = $false; [void]$out.Append("'"); $i++; continue
            }
            if ($c -eq "`n") { [void]$out.Append($c) } else { [void]$out.Append('x') }
            $i++
            continue
        }

        if ($c -eq '-' -and $i + 1 -lt $chars.Length -and $chars[$i + 1] -eq '-') {
            $inComment = $true; [void]$out.Append('  '); $i += 2; continue
        }
        if ($c -eq "'") { $inString = $true; [void]$out.Append("'"); $i++; continue }

        [void]$out.Append($c)
        $i++
    }

    return $out.ToString()
}

function Get-DepthMap {
    param([string]$Masked)

    $depth = New-Object 'int[]' $Masked.Length
    $level = 0
    for ($i = 0; $i -lt $Masked.Length; $i++) {
        $c = $Masked[$i]
        if ($c -eq '(') { $depth[$i] = $level; $level++ }
        elseif ($c -eq ')') { if ($level -gt 0) { $level-- }; $depth[$i] = $level }
        else { $depth[$i] = $level }
    }
    return $depth
}

function Get-TopLevelMatches {
    param([string]$Masked, [int[]]$Depth, [string]$Pattern)

    $hits = @()
    foreach ($m in [regex]::Matches($Masked, $Pattern, 'IgnoreCase')) {
        if ($Depth[$m.Index] -eq 0) { $hits += $m }
    }
    return $hits
}

function Get-BranchColumnCount {
    # Columns in one UNION branch: depth-0 commas between its SELECT and its FROM, plus one.
    param([string]$Masked, [int[]]$Depth, [int]$Start, [int]$End)

    $slice = $Masked.Substring($Start, $End - $Start)
    $selectMatch = $null
    foreach ($m in [regex]::Matches($slice, '\bSELECT\b', 'IgnoreCase')) {
        if ($Depth[$Start + $m.Index] -eq 0) { $selectMatch = $m; break }
    }
    if (-not $selectMatch) { return $null }

    $listStart = $Start + $selectMatch.Index + $selectMatch.Length
    $listEnd = $End
    foreach ($m in [regex]::Matches($Masked.Substring($listStart, $End - $listStart), '\bFROM\b', 'IgnoreCase')) {
        if ($Depth[$listStart + $m.Index] -eq 0) { $listEnd = $listStart + $m.Index; break }
    }

    $count = 1
    for ($i = $listStart; $i -lt $listEnd; $i++) {
        if ($Masked[$i] -eq ',' -and $Depth[$i] -eq 0) { $count++ }
    }
    return $count
}

# --------------------------------------------------------------------------------------
# Catalogue
# --------------------------------------------------------------------------------------

function Get-SqlSourceDirectory {
    $dirs = @()
    foreach ($name in 'GLOBAL_QUERIES', 'GLOBAL_DQ', 'POWERBI_QUERIES') {
        $path = Join-Path $RepoRoot $name
        if (Test-Path -LiteralPath $path) { $dirs += $path }
    }
    return $dirs
}

function Get-Statements {
    # One entry per executable statement, with the raw block and its header fields.
    $statements = @()

    foreach ($dir in Get-SqlSourceDirectory) {
        foreach ($file in (Get-ChildItem -LiteralPath $dir -Filter *.sql -File | Sort-Object Name)) {
            $raw = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
            $offset = 0
            $blocks = [regex]::Split($raw, '(?m)^--\s*={10,}\s*\r?$')

            foreach ($block in $blocks) {
                $blockStart = $raw.IndexOf($block, $offset)
                if ($blockStart -ge 0) { $offset = $blockStart + $block.Length }
                if ($block -notmatch '(?m)^\s*--\s*CheckID') { continue }

                $lineNumber = 1
                if ($blockStart -gt 0) {
                    $lineNumber = ([regex]::Matches($raw.Substring(0, $blockStart), "`n")).Count + 1
                }

                $idMatch = [regex]::Match($block, '(?m)^\s*--\s*CheckID\s*-\s*(\S+)\s*$')
                $nameMatch = [regex]::Match($block, '(?m)^\s*--\s*Name\s*-\s*(.+?)\s*$')
                $whatMatch = [regex]::Match($block, '(?m)^\s*--\s*What it does:\s*(.+?)\s*$')

                $statements += [pscustomobject]@{
                    CheckId    = $(if ($idMatch.Success) { $idMatch.Groups[1].Value } else { '' })
                    Name       = $(if ($nameMatch.Success) { $nameMatch.Groups[1].Value } else { '' })
                    What       = $(if ($whatMatch.Success) { $whatMatch.Groups[1].Value } else { '' })
                    File       = Get-RelativePath -Path $file.FullName
                    Directory  = $file.Directory.Name
                    Line       = $lineNumber
                    Sql        = $block.Trim()
                }
            }
        }
    }

    return $statements
}

function Get-MarkdownTableRow {
    # Rows of a Markdown table whose first cell matches $FirstCell, as string arrays.
    param([string]$Path, [string]$FirstCell)

    $rows = @()
    if (-not (Test-Path -LiteralPath $Path)) { return $rows }

    $n = 0
    foreach ($line in (Get-Content -LiteralPath $Path -Encoding UTF8)) {
        $n++
        if ($line -notmatch '^\s*\|') { continue }
        $cells = @(($line.Trim() -replace '^\|', '' -replace '\|\s*$', '') -split '\|' | ForEach-Object { $_.Trim() })
        if ($cells.Count -lt 2) { continue }
        if ($cells[0] -notmatch $FirstCell) { continue }
        $rows += [pscustomobject]@{ Line = $n; Cells = $cells }
    }
    return $rows
}

function Remove-Backtick {
    param([string]$Text)
    return ($Text -replace '`', '').Trim()
}

$statements = Get-Statements
$dqStatements = @($statements | Where-Object { $_.CheckId -match '-DQ-\d+$' -and $_.Directory -eq 'POWERBI_QUERIES' })
$globalDiscovery = @($statements | Where-Object { $_.CheckId -like 'GLOBAL-DISCOVERY-*' })
$globalDq = @($statements | Where-Object { $_.CheckId -like 'GLOBAL-DQ-*' })

Set-Metric 'SQL files parsed' (@(Get-SqlSourceDirectory | ForEach-Object { Get-ChildItem -LiteralPath $_ -Filter *.sql -File }).Count)
Set-Metric 'SQL statements parsed' $statements.Count
Set-Metric 'GLOBAL discovery statements' $globalDiscovery.Count
Set-Metric 'GLOBAL DQ templates' $globalDq.Count
Set-Metric 'Sport DQ statements' $dqStatements.Count

# --------------------------------------------------------------------------------------
# Package checks
# --------------------------------------------------------------------------------------

$expected = @(
    'README.md', 'CLAUDE.md', 'AI_INSTRUCTIONS.md', 'DATABASE.md', 'SPORTS.md',
    'WORKFLOW.md', 'POWERBI.md', 'POWERBI_REGISTRY.md', 'VALIDATION_REPORT.md',
    'SPORTS/_TEMPLATE.md', 'SPORTS/params.json',
    'GLOBAL_QUERIES/README.md', 'GLOBAL_DQ/README.md',
    'TOOLS/README.md', 'TOOLS/Run-Query.ps1', 'TOOLS/Test-Package.ps1'
)
$missing = @($expected | Where-Object { -not (Test-Path -LiteralPath (Join-Path $RepoRoot $_)) } |
    ForEach-Object { "missing: $_" })
Add-Result -Group 'Package' -Name 'Expected Project 2.0 files present' -Findings $missing

$textFiles = @(Get-ChildItem -LiteralPath $RepoRoot -Recurse -File -Include *.md, *.sql, *.ps1, *.json |
    Where-Object { $_.FullName -notmatch '\\\.git\\' -and $_.Name -notlike '*.local.ps1' })

$newlineFindings = @()
$whitespaceFindings = @()
$bomFindings = @()
foreach ($file in $textFiles) {
    # Byte-level, because Get-Content -Encoding UTF8 strips a BOM silently. No file in this
    # repository carries one: a .ps1 without a BOM is read as ANSI by PowerShell 5.1, so the
    # scripts stay pure ASCII, and the Markdown files are consistently BOM-free.
    $head = New-Object 'byte[]' 3
    $stream = [System.IO.File]::OpenRead($file.FullName)
    try { $read = $stream.Read($head, 0, 3) } finally { $stream.Dispose() }
    if ($read -eq 3 -and $head[0] -eq 0xEF -and $head[1] -eq 0xBB -and $head[2] -eq 0xBF) {
        $bomFindings += "UTF-8 BOM: $(Get-RelativePath -Path $file.FullName)"
    }

    $raw = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
    if ($null -eq $raw -or $raw.Length -eq 0) { continue }
    if ($raw[-1] -ne "`n") { $newlineFindings += "no final newline: $(Get-RelativePath -Path $file.FullName)" }

    $n = 0
    foreach ($line in ($raw -split "\r?\n")) {
        $n++
        if ($line -match '[ \t]+$') {
            $whitespaceFindings += "trailing whitespace: $(Get-RelativePath -Path $file.FullName):$n"
        }
    }
}
Add-Result -Group 'Package' -Name 'Final newline' -Findings $newlineFindings
Add-Result -Group 'Package' -Name 'Trailing whitespace' -Findings $whitespaceFindings
Add-Result -Group 'Package' -Name 'No UTF-8 BOM' -Findings $bomFindings

# Every active marker is the fixed lower boundary of its section: unique inside its file,
# and followed by a heading, a horizontal rule or end of file.
$markerFindings = @()
$markerCount = 0
foreach ($file in ($textFiles | Where-Object { $_.Extension -eq '.md' })) {
    $lines = @(Get-Content -LiteralPath $file.FullName -Encoding UTF8)
    $seen = @{}
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $m = [regex]::Match($lines[$i], 'MANUAL PASTE ZONE:\s*(.+?)\s*\u2014')
        if (-not $m.Success) { continue }

        $marker = $m.Groups[1].Value
        $markerCount++
        $rel = Get-RelativePath -Path $file.FullName
        if ($seen.ContainsKey($marker)) {
            $markerFindings += "duplicate marker '$marker': ${rel}:$($i + 1) also at line $($seen[$marker])"
        }
        $seen[$marker] = $i + 1

        $next = ''
        for ($j = $i + 1; $j -lt $lines.Count; $j++) {
            if ($lines[$j].Trim()) { $next = $lines[$j].Trim(); break }
        }
        if ($next -and $next -notmatch '^(#|---)') {
            $markerFindings += "marker '$marker' is not at the end of its section (${rel}:$($i + 1) followed by '$next')"
        }
    }
}
Add-Result -Group 'Package' -Name 'Manual-paste markers unique and section-final' -Findings $markerFindings
# Counted so a run that found no markers at all cannot read as a pass.
Set-Metric 'Manual-paste markers found' $markerCount
if ($markerCount -eq 0) {
    Add-Result -Group 'Package' -Name 'Markers were actually located' -Findings @('no MANUAL PASTE ZONE marker matched; the marker check inspected nothing')
}

# --------------------------------------------------------------------------------------
# SQL identity and shape
# --------------------------------------------------------------------------------------

$headerFindings = @()
foreach ($s in $statements) {
    $where = "$($s.File):$($s.Line)"
    $lines = @($s.Sql -split "\r?\n")

    if ($lines[0].Trim() -ne 'SELECT') {
        $headerFindings += "${where}: first line is not a bare SELECT"
    }
    if ($lines.Count -lt 4) { $headerFindings += "${where}: statement too short to carry an identity header"; continue }
    if ($lines[1] -notmatch '^\s*--\s*CheckID\s*-\s*\S+\s*$') { $headerFindings += "${where}: line 2 is not '-- CheckID - <id>'" }
    if ($lines[2] -notmatch '^\s*--\s*Name\s*-\s*\S') { $headerFindings += "${where}: line 3 is not '-- Name - <NAME>'" }
    if ($lines[3] -notmatch '^\s*--\s*What it does:\s*\S') { $headerFindings += "${where}: line 4 is not '-- What it does: ...'" }
    if ($lines[4] -match '^\s*--') { $headerFindings += "${where}: a fourth identity comment follows the header" }

    if ($s.Name -match '^(DISCOVERY|MISSING|WRONG|INVALID)') {
        $headerFindings += "$where ($($s.CheckId)): Name starts with a condition word, not the audited object"
    }
    if ($s.Sql -notmatch ';\s*$') { $headerFindings += "$where ($($s.CheckId)): statement does not end with ';'" }
}
Add-Result -Group 'SQL' -Name 'Identity header shape' -Findings $headerFindings

$idFindings = @()
$byId = $statements | Group-Object CheckId
foreach ($group in $byId) {
    if ($group.Count -gt 1) {
        $places = ($group.Group | ForEach-Object { "$($_.File):$($_.Line)" }) -join ', '
        $idFindings += "duplicate CheckID $($group.Name) at $places"
    }
}
foreach ($s in $statements) {
    if ($s.CheckId -notmatch '^(GLOBAL-(DISCOVERY|DQ)|[A-Za-z0-9][A-Za-z0-9.]*(-[A-Za-z0-9.]+)*-(DISCOVERY|DQ))-\d{3}$') {
        $idFindings += "$($s.File):$($s.Line): CheckID '$($s.CheckId)' is outside the documented namespaces"
    }
}
Add-Result -Group 'SQL' -Name 'CheckID unique and well-formed' -Findings $idFindings
Set-Metric 'Duplicate active SQL CheckIDs' (@($byId | Where-Object { $_.Count -gt 1 }).Count)

$unionFindings = @()
foreach ($s in $statements) {
    $masked = Get-MaskedSql -Sql $s.Sql
    $depth = Get-DepthMap -Masked $masked
    $splits = Get-TopLevelMatches -Masked $masked -Depth $depth -Pattern '\bUNION\s+ALL\b'
    if ($splits.Count -eq 0) { continue }

    $bounds = @(0)
    foreach ($m in $splits) { $bounds += $m.Index; $bounds += ($m.Index + $m.Length) }
    $bounds += $masked.Length

    $counts = @()
    for ($i = 0; $i -lt $bounds.Count; $i += 2) {
        $counts += Get-BranchColumnCount -Masked $masked -Depth $depth -Start $bounds[$i] -End $bounds[$i + 1]
    }

    $distinct = @($counts | Where-Object { $null -ne $_ } | Select-Object -Unique)
    if ($distinct.Count -gt 1) {
        $unionFindings += "$($s.CheckId) ($($s.File):$($s.Line)): UNION branches select $($counts -join '/') columns"
    }
}
Add-Result -Group 'SQL' -Name 'UNION ALL column counts agree' -Findings $unionFindings
Set-Metric 'UNION column-count mismatches' $unionFindings.Count

# --------------------------------------------------------------------------------------
# DQ contract
# --------------------------------------------------------------------------------------

$coverageFindings = @()
$limitFindings = @()
foreach ($s in ($dqStatements + $globalDq)) {
    $where = "$($s.CheckId) ($($s.File):$($s.Line))"
    if ($s.Sql -notmatch 'AS check_type') { $coverageFindings += "${where}: no check_type column" }
    if ($s.Sql -notmatch "'COVERAGE'") { $coverageFindings += "${where}: no COVERAGE branch" }
    if ($s.Sql -notmatch 'eligible_count') { $coverageFindings += "${where}: no eligible_count column" }
    if ($s.Sql -notmatch 'COUNT\(DISTINCT') { $coverageFindings += "${where}: coverage is not COUNT(DISTINCT ...)" }
    if ($s.Sql -notmatch '(?m)^\s*--\s*AND\s') { $coverageFindings += "${where}: no commented scope-limiting filter" }

    # LIMIT is allowed inside a scalar subquery and nowhere else: at depth 0 it would
    # truncate finding rows or drop the COVERAGE row.
    $masked = Get-MaskedSql -Sql $s.Sql
    $depth = Get-DepthMap -Masked $masked
    foreach ($m in (Get-TopLevelMatches -Masked $masked -Depth $depth -Pattern '\bLIMIT\b')) {
        $line = ([regex]::Matches($s.Sql.Substring(0, $m.Index), "`n")).Count + 1
        $limitFindings += "${where}: LIMIT applied to the result at statement line $line"
    }
}
Add-Result -Group 'DQ' -Name 'Coverage contract' -Findings $coverageFindings
Add-Result -Group 'DQ' -Name 'No result-level LIMIT' -Findings $limitFindings

# Statistics rules: a statistic-owned audited object needs template context and the IOC
# exclusion in every branch. The trigger is the audited object, not any mention of the
# tables: a participant check may read statistic_data11 in a subquery and still audit a
# participant, so the Comp.Rank Name prefix is what decides.
$statsFindings = @()
foreach ($s in ($dqStatements + $globalDq)) {
    if ($s.Name -notlike 'COMP.RANK*') { continue }
    $where = "$($s.CheckId) ($($s.File):$($s.Line))"
    if ($s.Sql -notmatch 'AS template_name') { $statsFindings += "${where}: no template_name context column" }

    $iocCount = ([regex]::Matches($s.Sql, "NOT LIKE '%\(IOC\)%'")).Count
    $branchCount = ([regex]::Matches($s.Sql, '(?i)\bUNION\s+ALL\b')).Count + 1
    if ($iocCount -lt $branchCount) {
        $statsFindings += "${where}: IOC exclusion appears $iocCount time(s) for $branchCount UNION branch(es)"
    }
}
Add-Result -Group 'DQ' -Name 'Statistics context and IOC exclusion' -Findings $statsFindings

# --------------------------------------------------------------------------------------
# GLOBAL parameterization
# --------------------------------------------------------------------------------------

$paramFindings = @()
$registries = @{
    'GLOBAL-DISCOVERY' = Join-Path $RepoRoot 'GLOBAL_QUERIES/README.md'
    'GLOBAL-DQ'        = Join-Path $RepoRoot 'GLOBAL_DQ/README.md'
}

foreach ($prefix in $registries.Keys) {
    $registryPath = $registries[$prefix]
    $owned = @($statements | Where-Object { $_.CheckId -like "$prefix-*" })
    if ($owned.Count -eq 0) { continue }

    if (-not (Test-Path -LiteralPath $registryPath)) {
        $paramFindings += "registry missing for ${prefix}: $(Get-RelativePath -Path $registryPath)"
        continue
    }

    $rows = Get-MarkdownTableRow -Path $registryPath -FirstCell "^$prefix-\d+$"
    $rowById = @{}
    foreach ($row in $rows) { $rowById[$row.Cells[0]] = $row }

    foreach ($s in $owned) {
        if ($s.Sql -match '\bsportFK\s*=\s*\d') {
            $paramFindings += "$($s.CheckId): hard-coded sportFK literal in a $prefix statement"
        }

        if (-not $rowById.ContainsKey($s.CheckId)) {
            $paramFindings += "$($s.CheckId) has no row in $(Get-RelativePath -Path $registryPath)"
            continue
        }

        $row = $rowById[$s.CheckId]
        if ((Remove-Backtick $row.Cells[1]) -ne $s.Name) {
            $paramFindings += "$($s.CheckId): registry Name '$(Remove-Backtick $row.Cells[1])' does not match SQL Name '$($s.Name)'"
        }
        # The Description mirrors the '-- What it does:' line but is not a copy of it:
        # GLOBAL_QUERIES/README.md omits the sport-scoping phrase from every row that
        # declares SPORT_ID. Word overlap catches a Description describing a different
        # query without failing that documented omission.
        $description = Remove-Backtick $row.Cells[3]
        if (-not $description) {
            $paramFindings += "$($s.CheckId): registry Description is empty"
        }
        else {
            $whatWords = @([regex]::Matches($s.What.ToLower(), '[a-z_]{3,}') | ForEach-Object { $_.Value })
            $descWords = @([regex]::Matches($description.ToLower(), '[a-z_]{3,}') | ForEach-Object { $_.Value })
            $shared = @($descWords | Where-Object { $whatWords -contains $_ })
            if ($descWords.Count -gt 0 -and ($shared.Count / $descWords.Count) -lt 0.8) {
                $overlap = [math]::Round(100 * $shared.Count / $descWords.Count)
                $paramFindings += "$($s.CheckId): registry Description shares only $overlap% of its words with the '-- What it does:' line"
            }
        }

        $used = @([regex]::Matches($s.Sql, '\{\{([A-Z_]+)\}\}') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
        $declared = @([regex]::Matches($row.Cells[4], '[A-Z_]{3,}') | ForEach-Object { $_.Value } | Select-Object -Unique)

        foreach ($token in $used) {
            if ($declared -notcontains $token) {
                $paramFindings += "$($s.CheckId): uses {{$token}} but the registry does not declare it"
            }
        }
        foreach ($token in $declared) {
            if ($used -notcontains $token) {
                $paramFindings += "$($s.CheckId): registry declares $token but the statement does not use it"
            }
        }
    }

    foreach ($row in $rows) {
        if (-not ($owned | Where-Object { $_.CheckId -eq $row.Cells[0] })) {
            $paramFindings += "$(Get-RelativePath -Path $registryPath):$($row.Line): $($row.Cells[0]) has a registry row but no statement"
        }
    }
}
Add-Result -Group 'GLOBAL' -Name 'Registry versus executable SQL, and declared parameters' -Findings $paramFindings

# --------------------------------------------------------------------------------------
# PowerBI registry
# --------------------------------------------------------------------------------------

$registryPath = Join-Path $RepoRoot 'POWERBI_REGISTRY.md'
$registryRows = Get-MarkdownTableRow -Path $registryPath -FirstCell '^\S+-DQ-\d+$'
$registryFindings = @()
$expectedColumns = 8
$templateIds = @($globalDq | ForEach-Object { $_.CheckId })

$rowById = @{}
foreach ($row in $registryRows) {
    $id = $row.Cells[0]
    if ($rowById.ContainsKey($id)) {
        $registryFindings += "POWERBI_REGISTRY.md:$($row.Line): duplicate row for $id"
        continue
    }
    $rowById[$id] = $row

    if ($row.Cells.Count -ne $expectedColumns) {
        $registryFindings += "POWERBI_REGISTRY.md:$($row.Line): $id has $($row.Cells.Count) cells, expected $expectedColumns"
        continue
    }

    $sport = $row.Cells[1]
    $family = Remove-Backtick $row.Cells[2]
    $name = Remove-Backtick $row.Cells[5]
    $queryFile = Remove-Backtick $row.Cells[6]
    $status = $row.Cells[7]

    if ($id -notlike "$sport-DQ-*") {
        $registryFindings += "POWERBI_REGISTRY.md:$($row.Line): $id does not carry the Sport '$sport' as its prefix"
    }
    if ($family -ne $EmDash -and $templateIds -notcontains $family) {
        $registryFindings += "POWERBI_REGISTRY.md:$($row.Line): $id declares Family '$family', which is not an existing GLOBAL-DQ template"
    }
    if ($status -notin @('Approved', 'Deprecated')) {
        $registryFindings += "POWERBI_REGISTRY.md:$($row.Line): $id has Status '$status'"
    }

    if ($status -eq 'Approved') {
        # Family and Query file are independent facts. Family names the logical check, so
        # PowerBI can group one check family across sports. Query file names the executable
        # SQL: a template under GLOBAL_DQ/ means the row is an instantiation; the sport file
        # means the sport authored its own statement, which a member of a family still may.
        $sql = $dqStatements | Where-Object { $_.CheckId -eq $id }
        $template = $globalDq | Where-Object { $_.CheckId -eq $family }

        if ($queryFile -like 'GLOBAL_DQ/*') {
            if ($family -eq $EmDash) {
                $registryFindings += "POWERBI_REGISTRY.md:$($row.Line): $id runs a template but declares no Family"
            }
            elseif ($template) {
                if ($queryFile -ne $template.File) {
                    $registryFindings += "POWERBI_REGISTRY.md:$($row.Line): $id instantiates $family, whose statement is in '$($template.File)', not '$queryFile'"
                }
                if ($name -ne $template.Name) {
                    $registryFindings += "POWERBI_REGISTRY.md:$($row.Line): $id registry Name '$name' does not match template Name '$($template.Name)'"
                }
            }
            if ($sql) {
                $registryFindings += "$($id): runs template $family but also has its own statement in '$($sql.File)'; one CheckID has one executable statement"
            }
        }
        else {
            if ($queryFile -ne "POWERBI_QUERIES/$sport.sql") {
                $registryFindings += "POWERBI_REGISTRY.md:$($row.Line): $id points at '$queryFile' instead of POWERBI_QUERIES/$sport.sql"
            }
            if (-not $sql) {
                $registryFindings += "POWERBI_REGISTRY.md:$($row.Line): $id is Approved but has no executable statement"
            }
            elseif ($sql.Name -ne $name) {
                $registryFindings += "$($id): registry Name '$name' does not match SQL Name '$($sql.Name)'"
            }
            elseif ($sql.File -ne $queryFile) {
                $registryFindings += "$($id): statement lives in '$($sql.File)' but the registry says '$queryFile'"
            }

            # A sport-authored member of a family must still be the same logical check.
            if ($template -and $sql -and $sql.Name -ne $template.Name) {
                $registryFindings += "$($id): declares Family $family but its Name '$($sql.Name)' differs from the template's '$($template.Name)'"
            }
        }
    }
}

foreach ($s in $dqStatements) {
    if (-not $rowById.ContainsKey($s.CheckId)) {
        $registryFindings += "$($s.File):$($s.Line): $($s.CheckId) has executable SQL but no registry row"
    }
}

# Numbering starts at 001 per sport and stays gap-free unless a row was deprecated.
foreach ($group in ($registryRows | Group-Object { $_.Cells[1] })) {
    $numbers = @($group.Group | ForEach-Object { [int]([regex]::Match($_.Cells[0], '(\d+)$').Groups[1].Value) } | Sort-Object)
    if ($numbers[0] -ne 1) {
        $registryFindings += "$($group.Name): DQ numbering starts at $($numbers[0]), not 001"
    }
    for ($i = 1; $i -lt $numbers.Count; $i++) {
        if ($numbers[$i] -ne $numbers[$i - 1] + 1) {
            $registryFindings += "$($group.Name): CheckID gap between DQ-$('{0:000}' -f $numbers[$i - 1]) and DQ-$('{0:000}' -f $numbers[$i]); a reserved deprecated row should keep the number"
        }
    }
}
Add-Result -Group 'PowerBI' -Name 'Registry versus active sport SQL' -Findings $registryFindings
Set-Metric 'PowerBI registry rows' $registryRows.Count

# --------------------------------------------------------------------------------------
# Sports index and parameters
# --------------------------------------------------------------------------------------

$sportFindings = @()
$indexRows = Get-MarkdownTableRow -Path (Join-Path $RepoRoot 'SPORTS.md') -FirstCell '^\d+$'
$indexed = @{}

foreach ($row in $indexRows) {
    if ($row.Cells.Count -lt 3) { continue }
    $sport = $row.Cells[1]
    $file = Remove-Backtick $row.Cells[2]
    $indexed[$sport] = [pscustomobject]@{ SportId = [int]$row.Cells[0]; File = $file }

    if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot $file))) {
        $sportFindings += "SPORTS.md:$($row.Line): '$file' does not exist"
    }
    if ($file -ne "SPORTS/$sport.md") {
        $sportFindings += "SPORTS.md:$($row.Line): '$sport' should map to SPORTS/$sport.md"
    }
    if ($sport -match '[^A-Za-z0-9.\-]') {
        $sportFindings += "SPORTS.md:$($row.Line): sport slug '$sport' contains a character outside [A-Za-z0-9.-]"
    }
}

foreach ($file in (Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'SPORTS') -Filter *.md -File)) {
    if ($file.BaseName -eq '_TEMPLATE') { continue }
    if (-not $indexed.ContainsKey($file.BaseName)) {
        $sportFindings += "SPORTS/$($file.Name) has no row in SPORTS.md"
    }
}

foreach ($sport in ($dqStatements | ForEach-Object { ($_.CheckId -split '-DQ-')[0] } | Select-Object -Unique)) {
    if (-not $indexed.ContainsKey($sport)) {
        $sportFindings += "DQ checks exist for '$sport' but SPORTS.md has no row for it"
    }
}

$paramsPath = Join-Path $RepoRoot 'SPORTS/params.json'
if (Test-Path -LiteralPath $paramsPath) {
    try {
        $params = Get-Content -LiteralPath $paramsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($property in $params.PSObject.Properties) {
            if ($property.Name -eq '$schema') { continue }
            $sport = $property.Name
            if (-not $indexed.ContainsKey($sport)) {
                $sportFindings += "SPORTS/params.json: '$sport' has no row in SPORTS.md"
                continue
            }
            $declaredId = $property.Value.SPORT_ID
            if ($null -eq $declaredId) {
                $sportFindings += "SPORTS/params.json: '$sport' declares no SPORT_ID"
            }
            elseif ([int]$declaredId -ne $indexed[$sport].SportId) {
                $sportFindings += "SPORTS/params.json: '$sport' SPORT_ID $declaredId disagrees with SPORTS.md ($($indexed[$sport].SportId))"
            }
        }

        # A row that actually runs a template is only executable if the sport records every
        # parameter the template declares. Without this the gap surfaces as a failed run.
        foreach ($row in $registryRows) {
            if ($row.Cells.Count -ne $expectedColumns) { continue }
            if ($row.Cells[7] -ne 'Approved') { continue }
            if ((Remove-Backtick $row.Cells[6]) -notlike 'GLOBAL_DQ/*') { continue }
            $family = Remove-Backtick $row.Cells[2]
            if ($family -eq $EmDash) { continue }

            $sport = $row.Cells[1]
            $template = $globalDq | Where-Object { $_.CheckId -eq $family }
            if (-not $template) { continue }

            $needed = @([regex]::Matches($template.Sql, '\{\{([A-Z_]+)\}\}') |
                ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
            $recorded = @()
            if ($params.PSObject.Properties.Name -contains $sport) {
                $recorded = @($params.$sport.PSObject.Properties.Name)
            }
            foreach ($token in $needed) {
                if ($recorded -notcontains $token) {
                    $sportFindings += "SPORTS/params.json: '$sport' instantiates $family but records no $token"
                }
            }
        }
    }
    catch {
        $sportFindings += "SPORTS/params.json is not valid JSON: $($_.Exception.Message)"
    }
}
Add-Result -Group 'Sports' -Name 'Sport index, slugs and parameter file' -Findings $sportFindings
Set-Metric 'Sports indexed' $indexed.Count

# --------------------------------------------------------------------------------------
# Output
# --------------------------------------------------------------------------------------

$failed = @($script:Results | Where-Object { $_.Status -eq 'FAIL' })
$overall = 'PASS'
if ($failed.Count -gt 0) { $overall = 'FAIL' }

if (-not $Quiet) {
    Write-Host ''
    Write-Host "Project 2.0 package validation - $RepoRoot" -ForegroundColor Cyan
    Write-Host ''

    foreach ($result in $script:Results) {
        $colour = 'Green'
        if ($result.Status -eq 'FAIL') { $colour = 'Red' }
        elseif ($result.Status -eq 'SKIP') { $colour = 'DarkGray' }
        Write-Host ("  {0,-4} {1,-10} {2}" -f $result.Status, $result.Group, $result.Name) -ForegroundColor $colour
        foreach ($finding in $result.Findings) {
            Write-Host "         $finding" -ForegroundColor Yellow
        }
    }

    Write-Host ''
    foreach ($key in $script:Metrics.Keys) {
        Write-Host ("  {0,-32} {1}" -f $key, $script:Metrics[$key]) -ForegroundColor DarkGray
    }
    Write-Host ''
    $colour = 'Green'
    if ($overall -eq 'FAIL') { $colour = 'Red' }
    Write-Host "  $overall - $($failed.Count) failing check(s), $((@($script:Results | ForEach-Object { $_.Findings.Count }) | Measure-Object -Sum).Sum) finding(s)" -ForegroundColor $colour
    Write-Host ''
}

if ($ReportPath) {
    $lines = @()
    $lines += '# Project 2.0 Validation Report'
    $lines += ''
    $lines += "Generated by ``TOOLS/Test-Package.ps1`` on **$(Get-Date -Format 'yyyy-MM-dd')**. This file is"
    $lines += 'output, not a hand-written claim: re-run the script rather than editing it.'
    $lines += ''
    $lines += '## Result'
    $lines += ''
    if ($overall -eq 'PASS') {
        $lines += "**PASS $EmDash the package is internally consistent.**"
    }
    else {
        $lines += "**FAIL $EmDash $($failed.Count) check(s) failing.**"
    }
    $lines += ''
    $lines += '## Checks'
    $lines += ''
    $lines += '| Group | Check | Result |'
    $lines += '|---|---|---:|'
    foreach ($result in $script:Results) {
        $lines += "| $($result.Group) | $($result.Name) | $($result.Status) |"
    }
    $lines += ''
    $lines += '## Metrics'
    $lines += ''
    $lines += '| Metric | Value |'
    $lines += '|---|---:|'
    foreach ($key in $script:Metrics.Keys) {
        $lines += "| $key | $($script:Metrics[$key]) |"
    }

    if ($failed.Count -gt 0) {
        $lines += ''
        $lines += '## Findings'
        $lines += ''
        foreach ($result in $failed) {
            $lines += "### $($result.Group) $EmDash $($result.Name)"
            $lines += ''
            foreach ($finding in $result.Findings) { $lines += "- $finding" }
            $lines += ''
        }
    }

    $lines += ''
    $lines += '## Boundary'
    $lines += ''
    $lines += 'This report proves package consistency and static SQL shape. It does not prove live'
    $lines += 'database permissions, runtime cost or result semantics, because no statement was'
    $lines += 'executed. Run a small approved sample through `TOOLS/Run-Query.ps1` for that.'

    $resolved = $ReportPath
    if (-not [System.IO.Path]::IsPathRooted($resolved)) { $resolved = Join-Path (Get-Location).Path $ReportPath }
    $resolved = [System.IO.Path]::GetFullPath($resolved)

    # Written through .NET rather than Set-Content: PowerShell 5.1's -Encoding utf8 emits a
    # BOM, which no other Markdown file in the repository carries, and appends CRLF to text
    # already joined with LF. Both would show up as findings on the next run.
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($resolved, ($lines -join "`n") + "`n", $encoding)
    if (-not $Quiet) { Write-Host "  report written: $resolved" -ForegroundColor DarkGray; Write-Host '' }
}

if ($overall -eq 'FAIL') { exit 1 }
exit 0
