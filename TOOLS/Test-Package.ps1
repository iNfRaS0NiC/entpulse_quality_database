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

# The named keys inside a sport's SPORTS/params.json entry that are not themselves parameters.
# Run-Query.ps1 declares the same names; both files are the contract for those blocks. It also
# skips any key with a leading underscore, so a block added to the JSON before it is named here
# is ignored rather than read as a parameter; this list stays because the four are the ones the
# two scripts actually read.
$NotApplicableKey = '_notApplicable'
$CheckSignalKey = '_checkSignal'
$ExpectedKey = '_expected'
$NamesKey = '_names'
# Which way round a sport puts its client boundary. Not a parameter - no statement declares a
# token for it - so it belongs with the other blocks that are about the sport rather than for
# the SQL. TOOLS/Run-Query.ps1 declares the same name and the pair of files is the contract.
$ClientScopeFormKey = '_clientScopeForm'
$ClientScopeForms = @('complement', 'in-scope')
$ReservedParamKeys = @($NotApplicableKey, $CheckSignalKey, $ExpectedKey, $NamesKey,
    $ClientScopeFormKey)

# The client's boundary, expressed as the templates it does not take. README.md owns why the
# client is a boundary of its own; this is the value every statement that can carry one reads.
$ClientScopeKey = 'OUT_OF_SCOPE_TEMPLATE_ID_LIST'

# The other form the same boundary may take. A sport declares whichever list is the short one:
# naming the templates the client does take, when it takes few, or the ones it does not, when it
# takes most. Run-Query.ps1 holds the same pair and computes whichever was not declared, so the
# two files are one contract - this one checks what the sport file says and what its statements
# then have to carry.
#
# The two are not interchangeable in a statement. An exclusion leaves a template added later
# inside the boundary; an inclusion leaves it outside. That is the whole reason a sport gets to
# choose, so a sport declaring the inclusion writes an inclusion into its own SQL, and writing
# the complement there instead would put the wrong default back where nobody would look for it.
$InScopeKey = 'IN_SCOPE_TEMPLATE_ID_LIST'
$MedalTemplateKey = 'MEDAL_TEMPLATE_ID_LIST'

# The commented run-time filter, in the two alias forms POWERBI.md allows. Declared here as the
# validator's own copy rather than imported: Run-Query.ps1 activates it and this only counts it,
# and a tool that fails a package must not need the tool it is checking to be loadable.
$TemplateFilterMarkerPattern =
'(?m)^[ \t]*--[ \t]*AND[ \t]+\w+\.(id|tournament_templateFK)[ \t]*=[ \t]*<tournament_template_id>[ \t]*\r?$'

# Actionable is the default and is never recorded. Deprecated is absent on purpose:
# POWERBI_REGISTRY.md's Status column owns it, and a value with two owners drifts.
$CheckSignalValues = @('Monitor', 'Informational', 'Blocked', 'Not applicable',
    'Out of client scope', 'Sentinel')

# What a re-run should return once the findings have been corrected, and the default each
# signal implies. Only the exception is recorded, so an entry restating its own default is a
# finding: the block would otherwise grow into a second copy of something already derivable,
# and every copy drifts. Run-Query.ps1 declares the same pair.
$CheckExpectValues = @('Zero', 'Non-zero', 'Residual')
$ExpectedBySignal = @{
    'Actionable'    = 'Zero'
    'Monitor'       = 'Non-zero'
    'Informational' = 'Non-zero'
    'Sentinel'      = 'Zero'
}

# The priority band each registry Category falls in. Run-Query.ps1 declares the same map and
# puts the band in the workbook; this side exists so a category added to the registry without
# a band cannot reach a reviewer as an unexplained blank. POWERBI.md owns the vocabulary.
$CheckPriorityByCategory = @{
    'WRONG_STRUCTURE'     = '1 Structure'
    'NO_RELATED_RECORDS'  = '1 Structure'
    'WRONG_RESULTS'       = '2 Wrong value'
    'WRONG_GENDER'        = '2 Wrong value'
    'WRONG_DISCIPLINE'    = '2 Wrong value'
    'DATE_RANGE_MISMATCH' = '2 Wrong value'
    'MALFORMED_NAME'      = '2 Wrong value'
    # Two records where there should be one. Carried here as well so the two maps cannot
    # disagree about a band.
    'DUPLICATE_RECORD'    = '2 Wrong value'
    'MISSING_VALUES'      = '3 Missing value'
    # Not a defect family: a pattern summary is a census, and it sorts below every band that
    # names something correctable. Carried here as well so the two maps cannot disagree.
    'PATTERNS'            = '4 Patterns'
}

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

# The Pool cuts a statement at the first literal ';' without noticing that it sits inside a
# string, so the rest of the statement never reaches MySQL and what does arrive ends on an
# unterminated literal. It is not a syntax error anyone can see by reading the SQL, and it
# killed the whole name-format family - 32 approved checks across six sports - silently, for
# as long as those statements had existed. Comments are stripped before execution and are
# therefore safe; only string literals are scanned here. Returns character indexes so the
# caller can report a line the same way the LIMIT rule does.
function Get-StringLiteralSemicolonIndexes {
    param([string]$Sql)

    $chars = $Sql.ToCharArray()
    $hits = @()
    $inString = $false
    $inComment = $false
    $i = 0

    while ($i -lt $chars.Length) {
        $c = $chars[$i]

        if ($inComment) {
            if ($c -eq "`n") { $inComment = $false }
            $i++
            continue
        }

        if ($inString) {
            # Mirrors Get-MaskedSql: '' is an escaped quote, \x is MySQL's backslash escape.
            if ($c -eq '\' -and $i + 1 -lt $chars.Length) { $i += 2; continue }
            if ($c -eq "'") {
                if ($i + 1 -lt $chars.Length -and $chars[$i + 1] -eq "'") { $i += 2; continue }
                $inString = $false; $i++; continue
            }
            if ($c -eq ';') { $hits += $i }
            $i++
            continue
        }

        if ($c -eq '-' -and $i + 1 -lt $chars.Length -and $chars[$i + 1] -eq '-') { $inComment = $true; $i += 2; continue }
        if ($c -eq "'") { $inString = $true; $i++; continue }
        $i++
    }

    return $hits
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

                $sql = $block.Trim()
                $masked = Get-MaskedSql -Sql $sql
                $depthMap = Get-DepthMap -Masked $masked

                $statements += [pscustomobject]@{
                    CheckId    = $(if ($idMatch.Success) { $idMatch.Groups[1].Value } else { '' })
                    Name       = $(if ($nameMatch.Success) { $nameMatch.Groups[1].Value } else { '' })
                    What       = $(if ($whatMatch.Success) { $whatMatch.Groups[1].Value } else { '' })
                    File       = Get-RelativePath -Path $file.FullName
                    Directory  = $file.Directory.Name
                    Line       = $lineNumber
                    Sql        = $sql
                    # Masked once here rather than in each rule that needs it. Every character
                    # of every statement passes through a PowerShell loop to get this, and two
                    # rules were each doing it for themselves - the same 1.6 MB walked twice,
                    # worth 11.4 seconds against 10.3 on the measurement above. The depth map
                    # travels with it because nothing wants one without the other, and the Sql
                    # the mask was built from is the one stored, so the two cannot drift apart.
                    Masked     = $masked
                    Depth      = $depthMap
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
    'TOOLS/README.md', 'TOOLS/Run-Query.ps1', 'TOOLS/Sheets.ps1', 'TOOLS/Connect-Sheets.ps1',
    'TOOLS/Test-Package.ps1', 'TOOLS/Test-Tools.ps1'
)
$missing = @($expected | Where-Object { -not (Test-Path -LiteralPath (Join-Path $RepoRoot $_)) } |
    ForEach-Object { "missing: $_" })
Add-Result -Group 'Package' -Name 'Expected Project 2.0 files present' -Findings $missing

# -Include is silently ignored when -Recurse is combined with -LiteralPath, so the extension
# filter has to be a predicate. output/ is excluded because it holds query result exports the
# runner writes there by default, and .gitignore keeps them out of the repository.
#
# RUNS/ is excluded for a different reason, and it is the one that made this the slowest thing
# the validator does. Those files are the run ledger, written by ConvertTo-Json and never by a
# person, so they cannot carry a trailing space or lose a final newline, and no rule in this file
# is about them. What they can do is grow: measured 2026-08-25 they were 13.3 MB of the 16.9 MB
# this walk covered, one sport's ledger reaching 1.6 MB, and the walk alone cost 7.37 seconds
# against 0.36 without them. On the whole validator, best of three alternating passes, that is
# 17.3 seconds down to 11.4 - a third of the run spent reading files nothing here has an opinion
# about, and rising with every run recorded.
$textExtensions = @('.md', '.sql', '.ps1', '.json')
$textFiles = @(Get-ChildItem -LiteralPath $RepoRoot -Recurse -File |
    Where-Object {
        $textExtensions -contains $_.Extension -and
        $_.FullName -notmatch '\\\.git\\' -and
        $_.FullName -notmatch '\\output\\' -and
        $_.FullName -notmatch '\\RUNS\\' -and
        $_.Name -notlike '*.local.ps1'
    })

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

# A semicolon may only be the one that ends the statement. Anywhere inside a literal it is a
# cut the executor makes and the reader cannot see; write the character as \\x{3B} in a regexp,
# or choose a different one where SEPARATOR forbids an expression.
$cutFindings = @()
foreach ($s in $statements) {
    foreach ($idx in @(Get-StringLiteralSemicolonIndexes -Sql $s.Sql)) {
        $line = ([regex]::Matches($s.Sql.Substring(0, $idx), "`n")).Count + 1
        $cutFindings += "$($s.File):$($s.Line) ($($s.CheckId)): ';' inside a string literal at statement line $line - the executor cuts the statement there"
    }
}
Add-Result -Group 'SQL' -Name 'No semicolon inside a string literal' -Findings $cutFindings
Set-Metric 'Statements cut by a literal semicolon' $cutFindings.Count

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
    $masked = $s.Masked
    $depth = $s.Depth
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
    $masked = $s.Masked
    $depth = $s.Depth
    foreach ($m in (Get-TopLevelMatches -Masked $masked -Depth $depth -Pattern '\bLIMIT\b')) {
        $line = ([regex]::Matches($s.Sql.Substring(0, $m.Index), "`n")).Count + 1
        $limitFindings += "${where}: LIMIT applied to the result at statement line $line"
    }
}
Add-Result -Group 'DQ' -Name 'Coverage contract' -Findings $coverageFindings
Add-Result -Group 'DQ' -Name 'No result-level LIMIT' -Findings $limitFindings

# Optional branches. A statement marking one drops it in the findings and in the coverage
# together, or eligible_count is counted over a population the findings never saw - the rule
# GLOBAL_DQ/README.md states for both markers. Mechanically that means BEGIN and END come in
# pairs and the pairs come in twos; a statement marking none is untouched by this.
$branchFindings = @()
foreach ($s in ($dqStatements + $globalDq)) {
    $where = "$($s.CheckId) ($($s.File):$($s.Line))"
    foreach ($marker in @('REGISTRY', 'STATISTIC')) {
        $begins = ([regex]::Matches($s.Sql, "(?m)^[ `t]*--[ `t]*$marker BRANCH BEGIN[ `t]*`$")).Count
        $ends = ([regex]::Matches($s.Sql, "(?m)^[ `t]*--[ `t]*$marker BRANCH END[ `t]*`$")).Count
        if ($begins -ne $ends) {
            $branchFindings += "${where}: $marker BRANCH has $begins BEGIN and $ends END"
            continue
        }
        if ($begins -ne 0 -and $begins -ne 2) {
            $branchFindings += ("${where}: $marker BRANCH is marked $begins time(s); " +
                'mark the findings branch and the coverage branch together, or neither')
        }
    }
}
Add-Result -Group 'DQ' -Name 'Optional branches marked in pairs' -Findings $branchFindings

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

# A statement carrying an id window can be cut into shards and merged when its result is too
# large for one request. Merging sums the COVERAGE counts, which is exact only while the
# window and the counted object are the same thing: cut on participants and count events, and
# an event spanning two windows would be counted twice. The runner cannot see that at run
# time, so it is settled here instead.
$shardFindings = @()
foreach ($s in ($dqStatements + $globalDq)) {
    $windows = [regex]::Matches($s.Sql, '(?m)^\s*--\s*AND\s+([\w.]+)\s+BETWEEN\s+<from_([a-z_]+)_id>\s+AND\s+<to_([a-z_]+)_id>\s*$')
    if ($windows.Count -eq 0) { continue }
    $where = "$($s.CheckId) ($($s.File):$($s.Line))"

    $objects = @($windows | ForEach-Object { $_.Groups[2].Value } | Select-Object -Unique)
    if ($objects.Count -gt 1) {
        $shardFindings += "${where}: id windows name more than one object ($($objects -join ', ')); a merged run could not sum one coverage count"
        continue
    }
    $object = $objects[0]

    foreach ($w in $windows) {
        if ($w.Groups[2].Value -ne $w.Groups[3].Value) {
            $shardFindings += "${where}: window runs from <from_$($w.Groups[2].Value)_id> to <to_$($w.Groups[3].Value)_id>, which name different objects"
        }
    }

    # Every top-level branch must carry a window, or an unwindowed branch would return its
    # whole population inside each shard and be multiplied by the merge. Only top-level ones
    # count: these statements union their participation sources inside a derived table, and a
    # window on the table that drives the branch already constrains everything it feeds.
    $branchStarts = @(0)
    $depth = 0
    for ($i = 0; $i -lt $s.Sql.Length; $i++) {
        $ch = $s.Sql[$i]
        if ($ch -eq '(') { $depth++ }
        elseif ($ch -eq ')') { $depth-- }
        elseif ($depth -eq 0 -and $ch -eq 'U' -and $s.Sql.Substring($i) -match '^UNION\s+ALL\b') {
            $branchStarts += $i
        }
    }

    for ($b = 0; $b -lt $branchStarts.Count; $b++) {
        $from = $branchStarts[$b]
        $to = if ($b + 1 -lt $branchStarts.Count) { $branchStarts[$b + 1] } else { $s.Sql.Length }
        $branch = $s.Sql.Substring($from, $to - $from)
        if ($branch -notmatch '(?m)^\s*--\s*AND\s+[\w.]+\s+BETWEEN\s+<from_[a-z_]+_id>') {
            $shardFindings += "${where}: branch $($b + 1) of $($branchStarts.Count) carries no id window, so a merged run would repeat its whole population in every shard"
        }
    }

    # [A-Za-z_0-9.] and not [a-z_0-9.]. PowerShell's -match is case-insensitive and
    # [regex]::Matches is not, so a lower-case class here meant every counted key carrying a
    # capital never matched at all - the pattern stopped at the first upper-case letter, the
    # closing bracket failed, and the rule passed the statement without reading it. Every
    # ...FK slipped it silently, which is the worst way for a validator to fail: not a wrong
    # answer but no answer, reported as a pass. Noticed 2026-08-30 while GLOBAL-DQ-030 was
    # being rewritten: this rule failed that statement on its id windows, and reading why
    # showed that its COUNT(DISTINCT sp.participantFK) had never been read at all. Widened
    # 2026-08-31. It surfaced three statements at once, all of them counting
    # op.participantFK where they window on participant, and all three were corrected to
    # count p.id rather than the rule relaxed.
    $counted = @([regex]::Matches($s.Sql, 'COUNT\(DISTINCT\s+([A-Za-z_0-9.]+)\)') | ForEach-Object { $_.Groups[1].Value })
    foreach ($key in $counted) {
        $tail = ($key -split '\.')[-1]
        if ($tail -ne 'id' -and $tail -ne "${object}_id") {
            $shardFindings += "${where}: cut on $object but coverage counts $key, so summing the shards would not be exact"
        }
    }
}
Add-Result -Group 'DQ' -Name 'Shardable statements can be merged' -Findings $shardFindings

# --------------------------------------------------------------------------------------
# The client boundary is carried by the statement, not by the run
# --------------------------------------------------------------------------------------

# A commented template filter is a place the scope *can* be narrowed at run time; the client's
# boundary is a place it *is* narrowed, always, and it has to survive being pasted into PowerBI
# out of this file. So wherever a statement declares it can reach the tournament template, it
# excludes the templates this client does not take - once per marker, in every branch that has
# one, findings and coverage alike, or eligible_count is counted over a population the findings
# never saw.
#
# Written against the marker rather than against a list of CheckIDs: a template added later is
# held to the same rule without anybody remembering to add it to a list.
$scopeFindings = @()

# What each sport's boundary is, so a sport taken whole is not made to write "exclude nothing"
# into forty statements. Read here rather than from the sport block further down because this
# rule is about the SQL and runs with it.
$boundaryOf = @{}
$inScopeOf = @{}
$medalOf = @{}
$boundarySource = Join-Path $RepoRoot 'SPORTS/params.json'
if (Test-Path -LiteralPath $boundarySource) {
    $parsed = Get-Content -LiteralPath $boundarySource -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($sportProperty in $parsed.PSObject.Properties) {
        if ($sportProperty.Name.StartsWith('_')) { continue }
        $boundaryOf[$sportProperty.Name] = [string]$sportProperty.Value.$ClientScopeKey
        $inScopeOf[$sportProperty.Name] = [string]$sportProperty.Value.$InScopeKey
        $medalOf[$sportProperty.Name] = [string]$sportProperty.Value.$MedalTemplateKey
    }
}

foreach ($s in $statements) {
    if ($s.CheckId -notmatch '-DQ-') { continue }

    $markers = @([regex]::Matches($s.Sql, $TemplateFilterMarkerPattern))
    if ($markers.Count -eq 0) { continue }

    $where = "$($s.CheckId) ($($s.File):$($s.Line))"
    $excluded = @([regex]::Matches($s.Sql,
            '(?m)^\s*AND\s+\w+\.(?:id|tournament_templateFK)\s+NOT\s+IN\s*\(([^)]*)\)'))

    # A GLOBAL template reads the boundary through the token, because seven sports share the
    # text and each has a different one. A sport statement carries its sport's ids written out,
    # because POWERBI.md says a sport check takes no parameters - so a token there would never
    # be substituted and the statement would go to the client with {{...}} in it.
    if ($s.CheckId -like 'GLOBAL-DQ-*') {
        if ($excluded.Count -lt $markers.Count) {
            $scopeFindings += ("${where}: {0} template filter(s) but {1} client-boundary line(s); " -f
                $markers.Count, $excluded.Count) +
            'every branch that can reach the template excludes {{OUT_OF_SCOPE_TEMPLATE_ID_LIST}}'
        }
        elseif ($s.Sql -notmatch '\{\{OUT_OF_SCOPE_TEMPLATE_ID_LIST\}\}') {
            $scopeFindings += "${where}: excludes a template list literally; a GLOBAL template reads {{OUT_OF_SCOPE_TEMPLATE_ID_LIST}}, which each sport fills"
        }
        continue
    }

    if ($s.Sql -match '\{\{') {
        $scopeFindings += "${where}: a sport statement carries a {{...}} token, which nothing substitutes outside the runner"
        continue
    }

    $slug = ($s.CheckId -split '-DQ-')[0]

    # A sport that declared what the client takes writes that, not its complement. The list is
    # the short one by definition - that is why the sport declared it that way round - and it is
    # also the one with the safe default: a template the sport gains next season is outside an
    # inclusion and inside an exclusion, and only one of those is what the client asked for.
    $inScope = [string]$inScopeOf[$slug]
    if (-not [string]::IsNullOrWhiteSpace($inScope)) {

        # The excluding form, allowed only where the including one does not execute. A
        # selective IN over a short list makes the optimiser drive from tournament and lose the
        # index path into the statistic shards, and on a big enough statement the server gives
        # up rather than returning slowly: Handball-DQ-062 timed out at the gateway on five
        # separate rewrites and ran in 14 seconds the moment the same filter was written as the
        # complement. A statement in that position declares it, and the declaration is what is
        # checked - not the author's word for it.
        #
        # What the marker costs is the safe default, and that is the whole reason the including
        # form is the rule: a template the sport gains next season is outside an inclusion and
        # INSIDE this statement. So the ids are still verified, from the side that can be: the
        # declared in-scope list must equal SPORTS/params.json exactly, and the excluded list
        # must not hold a single template the client takes. What cannot be caught here is the
        # new template, and the marker text is required to say so in the statement itself.
        $boundaryMarker = [regex]::Match($s.Sql,
                '(?m)^\s*--\s*CLIENT BOUNDARY EXCLUDING FORM:\s*(\S.*)$')
        if ($boundaryMarker.Success) {
            $declared = [regex]::Match($s.Sql, '(?m)^\s*--\s*IN SCOPE:\s*([0-9,\s]+)$')
            if (-not $declared.Success) {
                $scopeFindings += "${where}: declares the excluding form but no '-- IN SCOPE:' line, so its ids cannot be compared with SPORTS/params.json"
                continue
            }
            $wantedIn = @($inScope -split ',' | ForEach-Object { $_.Trim() } | Sort-Object)
            $said = @($declared.Groups[1].Value -split ',' | ForEach-Object { $_.Trim() } |
                Where-Object { $_ } | Sort-Object)
            if (($said -join ',') -ne ($wantedIn -join ',')) {
                $scopeFindings += "${where}: its '-- IN SCOPE:' line is ($($declared.Groups[1].Value.Trim())) but SPORTS/params.json $InScopeKey for $slug is ($inScope)"
                continue
            }
            if ($excluded.Count -lt $markers.Count) {
                $scopeFindings += ("${where}: {0} template filter(s) but {1} client-boundary line(s); " -f
                    $markers.Count, $excluded.Count) +
                "the excluding form still keeps every branch that can reach a template to the boundary"
                continue
            }
            foreach ($listed in $excluded) {
                $held = @($listed.Groups[1].Value -split ',' | ForEach-Object { $_.Trim() } |
                    Where-Object { $_ })
                $overlap = @($held | Where-Object { $wantedIn -contains $_ })
                if ($overlap.Count -gt 0) {
                    $scopeFindings += "${where}: excludes ($($overlap -join ', ')), which $slug declares as in scope"
                }
            }
            continue
        }

        $included = @([regex]::Matches($s.Sql,
                '(?m)^\s*AND\s+\w+\.(?:id|tournament_templateFK)\s+IN\s*\(([^)]*)\)'))
        if ($included.Count -lt $markers.Count) {
            $scopeFindings += ("${where}: {0} template filter(s) but {1} client-boundary line(s); " -f
                $markers.Count, $included.Count) +
            "$slug declares $InScopeKey, so every branch that can reach a template keeps to it"
        }
        $wantedIn = @($inScope -split ',' | ForEach-Object { $_.Trim() } | Sort-Object)

        # A second list the same statement may legitimately keep to. A check auditing medals
        # audits the competitions that award them, which is a subset of what the client takes -
        # Golf narrows GLOBAL-DQ-026 that way and Ice Hockey follows it. Only this one list is
        # allowed beside the boundary, and it is compared just as strictly: a subset that is
        # anybody's guess rather than the sport's own declaration is the same defect as a
        # widened one, arriving from the other side.
        $medal = [string]$medalOf[$slug]
        $wantedMedal = @()
        if (-not [string]::IsNullOrWhiteSpace($medal)) {
            $wantedMedal = @($medal -split ',' | ForEach-Object { $_.Trim() } | Sort-Object)
        }

        foreach ($listed in $included) {
            $held = @($listed.Groups[1].Value -split ',' | ForEach-Object { $_.Trim() } | Sort-Object)
            if (($held -join ',') -eq ($wantedIn -join ',')) { continue }
            if ($wantedMedal.Count -gt 0 -and ($held -join ',') -eq ($wantedMedal -join ',')) { continue }
            $scopeFindings += "${where}: keeps to ($($listed.Groups[1].Value)) but SPORTS/params.json $InScopeKey for $slug is ($inScope)" +
                $(if ($wantedMedal.Count -gt 0) { " and $MedalTemplateKey is ($medal)" } else { '' })
        }
        continue
    }

    # A sport the client takes whole writes nothing: "exclude nothing" in forty statements is
    # noise that stops being read, and the day such a sport gains a boundary the value is what
    # changes and this rule is what notices.
    $boundary = [string]$boundaryOf[$slug]
    if ([string]::IsNullOrWhiteSpace($boundary) -or $boundary -eq '0') { continue }

    if ($excluded.Count -lt $markers.Count) {
        $scopeFindings += ("${where}: {0} template filter(s) but {1} client-boundary line(s); " -f
            $markers.Count, $excluded.Count) +
        "$slug does not take every template, so every branch that can reach one excludes the rest"
        continue
    }

    # And the ids must be the sport's, not a copy that has drifted from it. A statement quietly
    # auditing a template the sport file says is out of scope is the defect this whole rule
    # exists to prevent, and it looks identical to a correct one until the ids are compared.
    $wanted = @($boundary -split ',' | ForEach-Object { $_.Trim() } | Sort-Object)
    foreach ($listed in $excluded) {
        $held = @($listed.Groups[1].Value -split ',' | ForEach-Object { $_.Trim() } | Sort-Object)
        if (($held -join ',') -ne ($wanted -join ',')) {
            $scopeFindings += "${where}: excludes ($($listed.Groups[1].Value)) but SPORTS/params.json $ClientScopeKey for $slug is ($boundary)"
        }
    }
}
Add-Result -Group 'DQ' -Name 'Client boundary is in the statement' -Findings $scopeFindings

# A template filter reads the tournament's foreign key, never the template's primary key.
# The two select identical rows and are not the same query: keying on tournament_template.id
# makes the optimiser drive from tournament_template and lose the index path into the
# statistic shards. Measured 2026-08-30 against the live database, alternating runs, with
# byte-identical result sets both ways - Golf-DQ-085 62.4s against 2.8, Ice-Hockey-DQ-112
# 122.9s against 4.4. Twenty-two and twenty-eight times, on one filter each.
#
# Only a literal filter is reported. A join condition carrying the same alias - tt2.id =
# st.objectFK, which correlates a template to the statistic that owns it - is how a statement
# auditing templates themselves is written, and is correct: it has no tournament to read the
# key from. What makes a filter a filter is a literal on the right-hand side.
#
# The pair is discovered from the statement rather than assumed, because the alias that owns
# the template is whatever the statement declared it to be: tt goes with t, tt2 with t2.
# DATABASE.md DB-SEM-016 owns the database fact and POWERBI.md the query contract; the
# commented marker the runner activates is held to the same rule by Test-Tools.ps1, which is
# why these two were written by hand and reached the package unnoticed.
$filterFindings = @()
foreach ($s in $statements) {
    $masked = Get-MaskedSql -Sql $s.Sql
    $owners = @{}
    foreach ($m in [regex]::Matches($masked, '(\w+)\.id\s*=\s*(\w+)\.tournament_templateFK')) {
        $owners[$m.Groups[1].Value] = $m.Groups[2].Value
    }
    if ($owners.Count -eq 0) { continue }

    foreach ($alias in $owners.Keys) {
        $pattern = '(?m)^[ 	]*AND[ 	]+' + [regex]::Escape($alias) + '\.id[ 	]*(?:IN[ 	]*\([ 	]*\d|=[ 	]*\d)'
        foreach ($hit in [regex]::Matches($masked, $pattern)) {
            $line = ([regex]::Matches($masked.Substring(0, $hit.Index), "`n")).Count + 1
            $filterFindings += ("$($s.File):$($s.Line) ($($s.CheckId)): filters on $alias.id at statement line " +
                "$line - the template's own key, where $($owners[$alias]) is already joined; " +
                "use $($owners[$alias]).tournament_templateFK")
        }
    }
}
Add-Result -Group 'DQ' -Name 'Template filter uses the foreign key' -Findings $filterFindings

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
# Both collections are indexed by CheckID here rather than scanned inside the loop below. That
# loop runs once per registry row - 1724 of them - and a pipeline scan for the statement and a
# second for the template costs 1724 x (162 + 149) predicate evaluations for an answer a
# hashtable gives in one lookup. Measured on this package, indexing them here and memoising the
# template placeholders further down takes the validator from 10.1 seconds to 5.5 on an idle
# machine, with identical output and identical metrics.
$sqlById = @{}
foreach ($dqStatement in $dqStatements) {
    if (-not $sqlById.ContainsKey($dqStatement.CheckId)) { $sqlById[$dqStatement.CheckId] = $dqStatement }
}
$templateById = @{}
foreach ($dqTemplate in $globalDq) {
    if (-not $templateById.ContainsKey($dqTemplate.CheckId)) { $templateById[$dqTemplate.CheckId] = $dqTemplate }
}
# What a template declares, filled in the first time each family is asked for. See the
# parameter-completeness loop below, which is where it is read.
$neededByFamily = @{}

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
    if ($family -ne $EmDash -and -not $templateById.ContainsKey($family)) {
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
        $sql = $(if ($sqlById.ContainsKey($id)) { $sqlById[$id] } else { $null })
        $template = $(if ($templateById.ContainsKey($family)) { $templateById[$family] } else { $null })

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

# The registry states its own row order, so the order is checkable rather than a convention
# nobody can enforce. Rows arrive in approval order, which drifts from Sport-then-CheckID
# on every append unless something says so.
$orderFindings = @()

$expectedOrder = @($registryRows |
    Sort-Object @{ Expression = { $_.Cells[1] } },
                @{ Expression = { [int]([regex]::Match($_.Cells[0], '(\d+)$').Groups[1].Value) } } |
    ForEach-Object { $_.Cells[0] })

# Only the first displaced row is reported: one row in the wrong place shifts every row
# after it, and a list of 200 findings would hide which one actually moved.
for ($i = 0; $i -lt $registryRows.Count; $i++) {
    if ($registryRows[$i].Cells[0] -ne $expectedOrder[$i]) {
        $orderFindings += "POWERBI_REGISTRY.md:$($registryRows[$i].Line): $($registryRows[$i].Cells[0]) is out of order; rows sort by Sport then CheckID, so $($expectedOrder[$i]) belongs here"
        break
    }
}

# A blank line between two rows splits the table in two when rendered, while the row
# scanner reads straight past it. Contiguity is only visible from the line numbers.
for ($i = 1; $i -lt $registryRows.Count; $i++) {
    if ($registryRows[$i].Line -ne $registryRows[$i - 1].Line + 1) {
        $orderFindings += "POWERBI_REGISTRY.md:$($registryRows[$i - 1].Line + 1): the row block breaks between $($registryRows[$i - 1].Cells[0]) and $($registryRows[$i].Cells[0]); a break here splits the rendered table"
    }
}

Add-Result -Group 'PowerBI' -Name 'Registry row order and contiguity' -Findings $orderFindings

# The workbook derives a priority band from the Category rather than asking each check to
# state one, so a category nobody has banded would reach the reviewer as an unexplained
# blank on the column that is meant to say what to do first.
$priorityFindings = @()
$seenCategories = @{}

foreach ($row in $registryRows) {
    $category = [string]$row.Cells[3]
    if ([string]::IsNullOrWhiteSpace($category)) {
        $priorityFindings += "POWERBI_REGISTRY.md:$($row.Line): $($row.Cells[0]) records no Category, so the run cannot band it"
        continue
    }
    if ($seenCategories.ContainsKey($category)) { continue }
    $seenCategories[$category] = $true

    if (-not $CheckPriorityByCategory.ContainsKey($category)) {
        $priorityFindings += "POWERBI_REGISTRY.md:$($row.Line): Category '$category' has no priority band; add it to the map in TOOLS/Run-Query.ps1 and TOOLS/Test-Package.ps1, and to the table POWERBI.md owns"
    }
}

Add-Result -Group 'PowerBI' -Name 'Every category has a priority band' -Findings $priorityFindings
Set-Metric 'DQ categories in use' $seenCategories.Count

# --------------------------------------------------------------------------------------
# Sports index and parameters
# --------------------------------------------------------------------------------------

$sportFindings = @()
$indexRows = Get-MarkdownTableRow -Path (Join-Path $RepoRoot 'SPORTS.md') -FirstCell '^\d+$'
$indexed = @{}

# Columns: sport id, slug, competition model, structural file, status, last evidence date,
# exact database sport.name. The last pair is what lets the runner keep a stable repository
# slug without guessing the value its live discovery SQL must match.
# The model is validated against the vocabulary DATABASE.md DB-SEM-015 defines, so a value
# invented in the index fails here rather than travelling as if it were a confirmed fact.
$competitionModels = @(
    'H2H (team)', 'H2H (individual)', 'H2H (individual and team)',
    'Listing (team)', 'Listing (individual)', 'Listing (individual and team)',
    'Hybrid (team)', 'Hybrid (individual)', 'Hybrid (individual and team)',
    'Not checked'
)

foreach ($row in $indexRows) {
    if ($row.Cells.Count -lt 4) { continue }
    $sport = $row.Cells[1]
    $model = $row.Cells[2]
    $file = Remove-Backtick $row.Cells[3]
    $databaseName = $(if ($row.Cells.Count -ge 7) { $row.Cells[6] } else { '' })
    $indexed[$sport] = [pscustomobject]@{
        SportId = [int]$row.Cells[0]
        File = $file
        DatabaseName = $databaseName
    }

    if ($row.Cells.Count -ne 7) {
        $sportFindings += "SPORTS.md:$($row.Line): '$sport' has $($row.Cells.Count) columns, expected 7 including Database sport name"
    }
    elseif ([string]::IsNullOrWhiteSpace($databaseName)) {
        $sportFindings += "SPORTS.md:$($row.Line): '$sport' has no exact Database sport name"
    }

    if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot $file))) {
        $sportFindings += "SPORTS.md:$($row.Line): '$file' does not exist"
    }
    if ($file -ne "SPORTS/$sport.md") {
        $sportFindings += "SPORTS.md:$($row.Line): '$sport' should map to SPORTS/$sport.md"
    }
    if ($sport -match '[^A-Za-z0-9.\-]') {
        $sportFindings += "SPORTS.md:$($row.Line): sport slug '$sport' contains a character outside [A-Za-z0-9.-]"
    }
    if ($competitionModels -notcontains $model) {
        $sportFindings += "SPORTS.md:$($row.Line): '$sport' competition model '$model' is not one DB-SEM-015 defines"
    }
}

foreach ($group in ($indexRows | Where-Object { $_.Cells.Count -ge 7 } |
        Group-Object { $_.Cells[6].ToLowerInvariant() } | Where-Object { $_.Count -gt 1 })) {
    $slugs = @($group.Group | ForEach-Object { $_.Cells[1] }) -join ', '
    $sportFindings += "SPORTS.md: database sport name '$($group.Group[0].Cells[6])' maps to more than one slug: $slugs"
}

foreach ($group in ($indexRows | Group-Object { $_.Cells[1].ToLowerInvariant() } |
        Where-Object { $_.Count -gt 1 })) {
    $sportFindings += "SPORTS.md: repository slug '$($group.Group[0].Cells[1])' appears more than once"
}

# A template GLOBAL_DQ/README.md marks mandatory must carry an Approved row for every sport in
# the index. Nothing enforced this until 2026-08-28, which is how
# GLOBAL-DQ-007 PARTICIPANT_MISSING_DATE_OF_BIRTH came to be missing from Biathlon and
# Track-Cycling: the parameter rule below refused it for a sport with no Comp.Rank values, the
# refusal was correct at the time, and nothing anywhere said the check was owed. A missing
# mandatory template now fails the package rather than waiting for somebody to notice.
#
# The marker lives in the Applicability cell because GLOBAL_DQ/README.md owns which template to
# reuse; this script encodes the rule and does not redefine it. Adding a template to the list is
# a decision about every sport at once, so it is made there, in the sentence a reader of that
# file will see, rather than in a list here that only this script reads.
$mandatoryMarker = 'Mandatory for every sport.'
$dqReadmeRows = Get-MarkdownTableRow -Path (Join-Path $RepoRoot 'GLOBAL_DQ/README.md') -FirstCell '^GLOBAL-DQ-\d+$'
$mandatory = @($dqReadmeRows | Where-Object { $_.Cells.Count -gt 5 -and $_.Cells[5] -like "*$mandatoryMarker*" })

if ($mandatory.Count -eq 0) {
    $sportFindings += ("GLOBAL_DQ/README.md: no template carries '$mandatoryMarker', so the " +
        'mandatory-template rule inspected nothing')
}
foreach ($template in $mandatory) {
    $family = $template.Cells[0]
    $templateName = Remove-Backtick $template.Cells[1]
    $carrying = @($registryRows |
        Where-Object {
            $_.Cells.Count -eq $expectedColumns -and $_.Cells[7] -eq 'Approved' -and
            (Remove-Backtick $_.Cells[2]) -eq $family
        } | ForEach-Object { $_.Cells[1] } | Select-Object -Unique)

    foreach ($sport in ($indexed.Keys | Sort-Object)) {
        if ($carrying -notcontains $sport) {
            $sportFindings += ("POWERBI_REGISTRY.md: '$sport' carries no Approved row for " +
                "$family $templateName, which GLOBAL_DQ/README.md declares mandatory for every sport")
        }
    }
}

foreach ($group in ($indexRows | Group-Object { $_.Cells[0] } | Where-Object { $_.Count -gt 1 })) {
    $slugs = @($group.Group | ForEach-Object { $_.Cells[1] }) -join ', '
    $sportFindings += "SPORTS.md: Sport ID $($group.Name) maps to more than one slug: $slugs"
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

            # A parameter is either recorded or documented as impossible, never both, and an
            # impossible one is only useful with the reason attached: the runner prints it in
            # place of "needs X" so the reader never has to open the sport file to tell a
            # missing value from one that will never exist.
            $block = $property.Value.PSObject.Properties | Where-Object { $_.Name -eq $NotApplicableKey }
            if ($block) {
                $recordedHere = @($property.Value.PSObject.Properties.Name | Where-Object { $ReservedParamKeys -notcontains $_ })
                foreach ($entry in $block.Value.PSObject.Properties) {
                    if ($entry.Name -cnotmatch '^[A-Z][A-Z0-9_]*$') {
                        $sportFindings += "SPORTS/params.json: '$sport' $NotApplicableKey key '$($entry.Name)' is not a parameter name"
                    }
                    if ([string]::IsNullOrWhiteSpace([string]$entry.Value)) {
                        $sportFindings += "SPORTS/params.json: '$sport' $NotApplicableKey records no reason for $($entry.Name)"
                    }
                    if ($recordedHere -contains $entry.Name) {
                        $sportFindings += "SPORTS/params.json: '$sport' records $($entry.Name) and also declares it not applicable"
                    }
                }
            }

            # A NO_RESULT list names the values that mean "no result was recorded". Every one
            # of them is therefore a value the sport uses, so it has to be in the VALUE list
            # too. GLOBAL-DQ-052 and -057 read both inside one statement: the VALUE list
            # decides what is an invalid comment, the NO_RESULT list what a comment excuses.
            # A value in the second but not the first is reported as invalid and honoured as
            # a no-result marker by the same check, which is a contradiction no result can
            # resolve.
            foreach ($pair in @(
                    @{ Values = 'RESULT_COMMENT_VALUE_LIST'; NoResult = 'RESULT_COMMENT_NO_RESULT_LIST' },
                    @{ Values = 'DATA_COMMENT_VALUE_LIST'; NoResult = 'DATA_COMMENT_NO_RESULT_LIST' })) {

                $valueText = [string]$property.Value.($pair.Values)
                $noResultText = [string]$property.Value.($pair.NoResult)
                if ([string]::IsNullOrWhiteSpace($valueText) -or [string]::IsNullOrWhiteSpace($noResultText)) { continue }

                # Both are SQL IN-list fragments: 'a', 'b', 'c'. Compared lowercased, because
                # that is how the statements compare them.
                $declared = @($valueText -split ',' | ForEach-Object { $_.Trim().Trim("'").ToLowerInvariant() })
                foreach ($item in @($noResultText -split ',' | ForEach-Object { $_.Trim().Trim("'").ToLowerInvariant() })) {
                    if ($item -eq '') { continue }
                    if ($declared -notcontains $item) {
                        $sportFindings += "SPORTS/params.json: '$sport' $($pair.NoResult) contains '$item' but $($pair.Values) does not; the same check would report it invalid and honour it as a no-result marker"
                    }
                }
            }

            # The client boundary, which every sport declares because every statement that can
            # carry one reads it. A sport that leaves it out does not run sport-wide: the token
            # goes unresolved and the runner skips the statement, so 80-odd checks would vanish
            # from that sport's board reported as needing a value nobody knew to supply. '0'
            # is the neutral value - no template has id 0 - and says the sport is taken whole.
            #
            # Either form satisfies it. A sport naming what the client does take leaves the
            # complement to the runner, which computes it against the templates the sport has
            # today - so the value nobody maintains is the one that would have gone stale.
            # Declaring both is refused rather than resolved: they say the same thing twice and
            # would disagree the first time one of them was edited.
            $boundary = [string]$property.Value.$ClientScopeKey
            $inScope = [string]$property.Value.$InScopeKey
            $hasBoundary = -not [string]::IsNullOrWhiteSpace($boundary)
            $hasInScope = -not [string]::IsNullOrWhiteSpace($inScope)

            if ($hasBoundary -and $hasInScope) {
                $sportFindings += "SPORTS/params.json: '$sport' declares both $ClientScopeKey and $InScopeKey; they are two ways of writing one boundary, so declare the shorter list only"
            }
            elseif (-not $hasBoundary -and -not $hasInScope) {
                $sportFindings += "SPORTS/params.json: '$sport' declares no $ClientScopeKey and no $InScopeKey; use '0' for a sport the client takes whole, since a missing token skips every statement that reads it"
            }
            elseif ($hasBoundary -and $boundary -notmatch '^\s*\d+(\s*,\s*\d+)*\s*$') {
                $sportFindings += "SPORTS/params.json: '$sport' $ClientScopeKey is not a comma-separated id list: '$boundary'"
            }
            elseif ($hasInScope -and $inScope -notmatch '^\s*\d+(\s*,\s*\d+)*\s*$') {
                $sportFindings += "SPORTS/params.json: '$sport' $InScopeKey is not a comma-separated id list: '$inScope'"
            }
            elseif ($hasInScope -and $inScope.Trim() -eq '0') {
                $sportFindings += "SPORTS/params.json: '$sport' $InScopeKey is '0', which names no template and would leave the client nothing; a sport taken whole declares $ClientScopeKey as '0' instead"
            }

            # A classification is only worth writing down if it is held to something, so each
            # value carries its own rule. Blocked says the check must not be approved yet;
            # Monitor and Not applicable describe a check that is approved and running, so
            # classifying one that is not approved is a statement about nothing.
            # Read once for both blocks below: each classifies a check by the template the
            # sport instantiates or by its own CheckID, and each has a rule about whether that
            # check is approved to run.
            $sportRows = @($registryRows |
                Where-Object { $_.Cells.Count -eq $expectedColumns -and $_.Cells[1] -eq $sport -and $_.Cells[7] -eq 'Approved' })
            $approvedFamilies = @($sportRows | ForEach-Object { Remove-Backtick $_.Cells[2] })
            $approvedIds = @($sportRows | ForEach-Object { $_.Cells[0] })
            $signalOf = @{}

            $signalBlock = $property.Value.PSObject.Properties | Where-Object { $_.Name -eq $CheckSignalKey }
            if ($signalBlock) {
                foreach ($recorded in $signalBlock.Value.PSObject.Properties) {
                    $signalOf[$recorded.Name] = [string]$recorded.Value.signal
                }

                foreach ($entry in $signalBlock.Value.PSObject.Properties) {
                    $key = $entry.Name
                    $signal = [string]$entry.Value.signal
                    $reason = [string]$entry.Value.reason

                    # The key names either the template the sport instantiates or one of its
                    # own statements. Anything else classifies a check that does not exist.
                    $isTemplate = $key -cmatch '^GLOBAL-DQ-\d{3}$'
                    $isOwn = $key -cmatch "^$([regex]::Escape($sport))-DQ-\d+$"
                    if (-not $isTemplate -and -not $isOwn) {
                        $sportFindings += "SPORTS/params.json: '$sport' $CheckSignalKey key '$key' is neither a GLOBAL-DQ template ID nor a $sport CheckID"
                        continue
                    }
                    if ($isTemplate -and -not $templateById.ContainsKey($key)) {
                        $sportFindings += "SPORTS/params.json: '$sport' classifies $key, which is not an existing GLOBAL-DQ template"
                        continue
                    }

                    if ($CheckSignalValues -notcontains $signal) {
                        $sportFindings += "SPORTS/params.json: '$sport' gives $key signal '$signal'; allowed: $($CheckSignalValues -join ', ') (Actionable is the default and is not recorded; POWERBI_REGISTRY.md Status owns Deprecated)"
                        continue
                    }
                    if ([string]::IsNullOrWhiteSpace($reason)) {
                        $sportFindings += "SPORTS/params.json: '$sport' records no reason for $key"
                    }

                    $isApproved = $(if ($isTemplate) { $approvedFamilies -contains $key } else { $approvedIds -contains $key })

                    # Blocked is temporary and says "not yet", so an Approved row contradicts
                    # it. Monitor describes what a running check's findings mean, so it needs
                    # one. Not applicable says the sport has nothing for the check to read,
                    # which is true whether or not anyone approved it - and the cases where
                    # someone did are exactly the ones worth being able to write down. Out of
                    # client scope carries no requirement for the same reason from the other
                    # side: the check is usually approved and running, and what it audits is a
                    # population this client does not take.
                    if ($signal -eq 'Blocked' -and $isApproved) {
                        $sportFindings += "SPORTS/params.json: '$sport' declares $key blocked but POWERBI_REGISTRY.md approves it"
                    }
                    if ($signal -eq 'Monitor' -and -not $isApproved) {
                        $sportFindings += "SPORTS/params.json: '$sport' classifies $key as 'Monitor' but POWERBI_REGISTRY.md has no Approved row for it; Monitor describes a check that runs"
                    }
                    # Sentinel carries Monitor's requirement and not Blocked's, which is the
                    # whole distinction: it says the check is approved, running and watching an
                    # empty population, so a sentinel with no Approved row is a check watching
                    # nothing from nowhere.
                    if ($signal -eq 'Sentinel' -and -not $isApproved) {
                        $sportFindings += "SPORTS/params.json: '$sport' classifies $key as 'Sentinel' but POWERBI_REGISTRY.md has no Approved row for it; a sentinel is a check that runs"
                    }
                }
            }

            # What a re-run should return once the reported findings have been corrected. The
            # signal already implies an answer for every check, so this block records only the
            # checks whose answer is not the implied one - and an entry that restates the
            # default is a finding rather than a harmless repetition, because a value written
            # in two places is a value that can disagree with itself.
            #
            # An expectation about a check with no Approved row is a statement about nothing,
            # which is the same rule Monitor carries and for the same reason. It also catches
            # the confusion worth catching: a Blocked check must not have an Approved row, so
            # an expectation recorded against one is caught here rather than read as a promise
            # about output that is not being produced.
            $expectedBlock = $property.Value.PSObject.Properties | Where-Object { $_.Name -eq $ExpectedKey }
            if ($expectedBlock) {
                foreach ($entry in $expectedBlock.Value.PSObject.Properties) {
                    $key = $entry.Name
                    $expect = [string]$entry.Value.expect
                    $reason = [string]$entry.Value.reason

                    $isTemplate = $key -cmatch '^GLOBAL-DQ-\d{3}$'
                    $isOwn = $key -cmatch "^$([regex]::Escape($sport))-DQ-\d+$"
                    if (-not $isTemplate -and -not $isOwn) {
                        $sportFindings += "SPORTS/params.json: '$sport' $ExpectedKey key '$key' is neither a GLOBAL-DQ template ID nor a $sport CheckID"
                        continue
                    }
                    if ($isTemplate -and -not $templateById.ContainsKey($key)) {
                        $sportFindings += "SPORTS/params.json: '$sport' records an expectation for $key, which is not an existing GLOBAL-DQ template"
                        continue
                    }

                    if ($CheckExpectValues -notcontains $expect) {
                        $sportFindings += "SPORTS/params.json: '$sport' expects '$expect' from $key; allowed: $($CheckExpectValues -join ', ')"
                        continue
                    }
                    if ([string]::IsNullOrWhiteSpace($reason)) {
                        $sportFindings += "SPORTS/params.json: '$sport' records no reason for expecting '$expect' from $key"
                    }

                    # Residual is a count of rows that are known and agreed to stay behind, so
                    # the count is the whole content of the classification. Without it the
                    # entry says only "some rows remain", which is Non-zero written at length.
                    $residualText = [string]$entry.Value.residual
                    $residual = 0
                    $hasResidual = [int]::TryParse($residualText, [ref]$residual)
                    if ($expect -eq 'Residual') {
                        if (-not $hasResidual -or $residual -lt 0) {
                            $sportFindings += "SPORTS/params.json: '$sport' expects 'Residual' from $key but records no residual count"
                        }
                    }
                    elseif ($residualText -ne '') {
                        $sportFindings += "SPORTS/params.json: '$sport' records a residual count for $key, which expects '$expect' rather than 'Residual'"
                    }

                    # The signal recorded for the same check, or Actionable, which is the
                    # default nobody writes down.
                    $signal = $(if ($signalOf.ContainsKey($key)) { $signalOf[$key] } else { 'Actionable' })
                    $implied = $(if ($ExpectedBySignal.ContainsKey($signal)) { $ExpectedBySignal[$signal] } else { '' })
                    if ($expect -eq $implied) {
                        $sportFindings += "SPORTS/params.json: '$sport' records '$expect' for $key, which is already what signal '$signal' implies; record only the exception"
                    }

                    $isApproved = $(if ($isTemplate) { $approvedFamilies -contains $key } else { $approvedIds -contains $key })
                    if (-not $isApproved) {
                        $sportFindings += "SPORTS/params.json: '$sport' records an expectation for $key but POWERBI_REGISTRY.md has no Approved row for it; an expectation describes a check that runs"
                    }
                }
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
            $template = $(if ($templateById.ContainsKey($family)) { $templateById[$family] } else { $null })
            if (-not $template) { continue }

            # A placeholder standing only inside the optional Comp.Rank branch is not one the
            # sport has to record. TOOLS/Run-Query.ps1 drops that branch for a sport with no
            # confirmed SHARD_ID and STATISTIC_TYPE_ID, so demanding them here would refuse the
            # instantiation the marker exists to allow - which is exactly how GLOBAL-DQ-007 came
            # to be missing from Biathlon and Track-Cycling. The registry branch is not stripped
            # here: it goes only on an explicit switch, so its parameters stay required.
            # Worked out once per template, not once per row that instantiates it: 149 templates
            # stand behind about 1700 Approved rows, and stripping the branch and re-matching the
            # placeholders for each of them re-answers the same question 1700 times.
            #
            # The pattern below keeps a carriage return and a line feed as real characters
            # inside the string literal, which is what lets it match both line endings. It is
            # left exactly as it was: an editor normalising this file's line endings would eat
            # the carriage return out of it, and the pattern would then stop matching the CRLF
            # the SQL files use - surfacing not as a crash but as four sports reported missing
            # parameters they do record.
            if ($neededByFamily.ContainsKey($family)) {
                $needed = $neededByFamily[$family]
            }
            else {
                $templateSql = [regex]::Replace($template.Sql,
                    '(?ms)^[ 	]*--[ 	]*STATISTIC BRANCH BEGIN[ 	]*
?
.*?^[ 	]*--[ 	]*STATISTIC BRANCH END[ 	]*
?
', '')
                $needed = @([regex]::Matches($templateSql, '\{\{([A-Z_]+)\}\}') |
                        ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
                $neededByFamily[$family] = $needed
            }
            $recorded = @()
            $unsupplied = @()
            if ($params.PSObject.Properties.Name -contains $sport) {
                $recorded = @($params.$sport.PSObject.Properties.Name | Where-Object { $ReservedParamKeys -notcontains $_ })
                $naBlock = $params.$sport.PSObject.Properties | Where-Object { $_.Name -eq $NotApplicableKey }
                if ($naBlock) { $unsupplied = @($naBlock.Value.PSObject.Properties.Name) }

                # The client boundary is declared one way round or the other, and the sport
                # that names what the client takes has still supplied the token every template
                # reads: TOOLS/Run-Query.ps1 computes the complement at run time. Asking for
                # the exclusion by name here would force a sport to record both, which the
                # rule immediately above this one forbids.
                if ($recorded -contains $InScopeKey -and $recorded -notcontains $ClientScopeKey) {
                    $recorded += $ClientScopeKey
                }
            }
            foreach ($token in $needed) {
                if ($unsupplied -contains $token) {
                    $sportFindings += "SPORTS/params.json: '$sport' instantiates $family as Approved but declares $token not applicable"
                }
                elseif ($recorded -notcontains $token) {
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
