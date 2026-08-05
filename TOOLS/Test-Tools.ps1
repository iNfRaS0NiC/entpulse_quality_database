<#
.SYNOPSIS
    Behavioural tests for the TOOLS scripts.

.DESCRIPTION
    Test-Package.ps1 proves the package is internally consistent. This proves the two
    scripts that read it behave as documented: which checks a run selects, how placeholders
    are filled, how the SQL catalogue is parsed, what the workbook writer emits, and whether
    the approved DQ statements keep the specific scope/granularity fixes they depend on.

    No Pester dependency. Windows PowerShell 5.1 ships Pester 3.4, whose syntax differs from
    every current version, so a suite written against either one is wrong on the other
    machine. The harness below is the same Add-Result shape Test-Package.ps1 already uses.

    Nothing here touches the network. Run-Query.ps1 is dot-sourced with -DotSourceOnly,
    which runs its prologue and stops before Main.

.PARAMETER RepoRoot
    Repository to test. Defaults to the parent of this script.

.EXAMPLE
    .\TOOLS\Test-Tools.ps1

.EXAMPLE
    .\TOOLS\Test-Tools.ps1 -Quiet
#>
[CmdletBinding()]
param(
    [string]$RepoRootPath,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

if (-not $RepoRootPath) { $RepoRootPath = Split-Path -Parent $PSScriptRoot }
$RepoRootPath = (Resolve-Path -LiteralPath $RepoRootPath).Path

# --------------------------------------------------------------------------------------
# Harness
# --------------------------------------------------------------------------------------

$script:Results = @()
$script:CaseCount = 0
$script:Findings = @()
$script:Group = ''
$script:GroupName = ''

function Start-Group {
    # Cases report into the open group; Complete-Group closes it into one result line, the
    # same Group/Name/Status shape Test-Package.ps1 prints.
    param([string]$Group, [string]$Name)

    $script:Group = $Group
    $script:GroupName = $Name
    $script:Findings = @()
}

function Complete-Group {
    $script:Results += [pscustomobject]@{
        Group    = $script:Group
        Name     = $script:GroupName
        Status   = $(if ($script:Findings.Count -gt 0) { 'FAIL' } else { 'PASS' })
        Findings = $script:Findings
    }
}

function Test-That {
    # One case. A case fails by throwing, so an assertion helper is just a throw.
    param([string]$Describes, [scriptblock]$Body)

    $script:CaseCount++
    try {
        & $Body
    }
    catch {
        $script:Findings += "$Describes - $($_.Exception.Message)"
    }
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Message = 'value')
    if ("$Expected" -ne "$Actual") {
        throw "$Message expected '$Expected' but was '$Actual'"
    }
}

function Assert-True {
    param($Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-Throws {
    # Asserts both that it threw and that the message names the cause, so a test cannot pass
    # on an unrelated failure that happens to be an exception.
    param([scriptblock]$Body, [string]$Matching, [string]$Message = 'call')

    $threw = $false
    try { & $Body } catch { $threw = $true; $text = $_.Exception.Message }
    if (-not $threw) { throw "$Message was expected to throw and did not" }
    if ($Matching -and $text -notmatch $Matching) {
        throw "$Message threw '$text', which does not match '$Matching'"
    }
}

# --------------------------------------------------------------------------------------
# Fixtures
# --------------------------------------------------------------------------------------

# Outside the repository: Test-Package.ps1 scans every .ps1, .sql, .md and .json under the
# root it is given, and a fixture left inside would be validated as if it were content.
$FixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ("entpulse-tools-tests-" + [Guid]::NewGuid().ToString('N').Substring(0, 8))

function New-FixtureCatalogueRoot {
    # A repository-shaped directory holding known statements, so parser and selection tests
    # assert against a fixture rather than against whatever the real catalogue happens to
    # contain today.
    $root = Join-Path $FixtureRoot 'catalogue'
    New-Item -ItemType Directory -Path (Join-Path $root 'GLOBAL_DQ') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $root 'POWERBI_QUERIES') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $root 'SPORTS') -Force | Out-Null

    $global = @'
SELECT
    -- CheckID - GLOBAL-DQ-001
    -- Name - FIRST_TEMPLATE
    -- What it does: Finds the first thing.
    'First' AS check_type
FROM t WHERE t.sportFK = {{SPORT_ID}};

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-002
    -- Name - SECOND_TEMPLATE
    -- What it does: Finds the second thing.
    'Second' AS check_type
FROM statistic_data{{SHARD_ID}} sd
JOIN statistic_participants{{SHARD_ID}} sp ON sp.id = sd.statistic_participants{{SHARD_ID}}FK
WHERE sp.sportFK = {{SPORT_ID}};

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-003
    -- Name - THIRD_TEMPLATE
    -- What it does: Finds the third thing.
    'Third' AS check_type
FROM t;

-- ======================================================================================

SELECT
    -- Name - NOT_A_CHECK
    'no CheckID here' AS check_type
FROM t;
'@

    # Fixtureball-DQ-004 is the sport's own version of what GLOBAL-DQ-002 expresses: same
    # logical check, its own statement. It is the shape that makes a catalogue-driven run
    # execute both the template and the replacement.
    $sport = @'
SELECT
    -- CheckID - Fixtureball-DQ-002
    -- Name - SPORT_AUTHORED
    -- What it does: Finds a sport-specific thing.
    'Own' AS check_type
FROM t;

-- ======================================================================================

SELECT
    -- CheckID - Fixtureball-DQ-004
    -- Name - SECOND_TEMPLATE
    -- What it does: Finds the second thing, the way this sport stores it.
    'Second, locally' AS check_type
FROM t;
'@

    $other = @'
SELECT
    -- CheckID - Otherball-DQ-001
    -- Name - OTHER_SPORT
    -- What it does: Belongs to a different sport.
    'Other' AS check_type
FROM t;
'@

    $registry = @'
# Fixture registry

| CheckID | Sport | Family | Category | Object | Name | Query file | Status |
|---|---|---|---|---|---|---|---|
| Fixtureball-DQ-001 | Fixtureball | GLOBAL-DQ-001 | MISSING_VALUES | EVENT | FIRST_TEMPLATE | `GLOBAL_DQ/FIXTURE.sql` | Approved |
| Fixtureball-DQ-002 | Fixtureball | - | MISSING_VALUES | EVENT | SPORT_AUTHORED | `POWERBI_QUERIES/Fixtureball.sql` | Approved |
| Fixtureball-DQ-003 | Fixtureball | GLOBAL-DQ-003 | MISSING_VALUES | EVENT | THIRD_TEMPLATE | `GLOBAL_DQ/FIXTURE.sql` | Deprecated |
| Fixtureball-DQ-004 | Fixtureball | GLOBAL-DQ-002 | MISSING_VALUES | EVENT | SECOND_TEMPLATE | `POWERBI_QUERIES/Fixtureball.sql` | Approved |
| Otherball-DQ-001 | Otherball | - | MISSING_VALUES | EVENT | OTHER_SPORT | `POWERBI_QUERIES/Otherball.sql` | Approved |
'@

    $params = @'
{
  "Fixtureball": {
    "SPORT_ID": 999,
    "_checkSignal": {
      "GLOBAL-DQ-003": {
        "signal": "Blocked",
        "reason": "blocked in the fixture, to prove the reason is carried through"
      },
      "GLOBAL-DQ-001": {
        "signal": "Monitor",
        "reason": "classified in the fixture, to prove a running check carries its signal"
      }
    }
  }
}
'@

    $sportIndex = @'
# Fixture sports

| Sport ID | Sport | Competition model | Structural file | Structural status | Last evidence date | Database sport name |
|---:|---|---|---|---|---|---|
| 777 | Water-Polo | H2H (team) | `SPORTS/Water-Polo.md` | In progress | 2026-08-03 | Water Polo |
'@

    $utf8 = New-Object System.Text.UTF8Encoding $false
    [IO.File]::WriteAllText((Join-Path $root 'GLOBAL_DQ\FIXTURE.sql'), $global, $utf8)
    [IO.File]::WriteAllText((Join-Path $root 'POWERBI_QUERIES\Fixtureball.sql'), $sport, $utf8)
    [IO.File]::WriteAllText((Join-Path $root 'POWERBI_QUERIES\Otherball.sql'), $other, $utf8)
    [IO.File]::WriteAllText((Join-Path $root 'POWERBI_REGISTRY.md'), $registry, $utf8)
    [IO.File]::WriteAllText((Join-Path $root 'SPORTS\params.json'), $params, $utf8)
    [IO.File]::WriteAllText((Join-Path $root 'SPORTS.md'), $sportIndex, $utf8)
    return $root
}

function Copy-RepositoryFixture {
    # A throwaway copy of the real repository, for tests that must run Test-Package.ps1
    # against a deliberately broken package. It exits, so it runs as a child process.
    param([string]$Name)

    $target = Join-Path $FixtureRoot $Name
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    Get-ChildItem -LiteralPath $RepoRootPath -Force |
        Where-Object { $_.Name -notin @('.git', 'output') } |
        ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $target -Recurse -Force }
    return $target
}

function Invoke-PackageValidator {
    # Returns the exit code and the console text together, because the finding text is the
    # part under test: a run that fails for some other reason must not count as a pass.
    param([string]$Root)

    $script = Join-Path $RepoRootPath 'TOOLS\Test-Package.ps1'
    $output = & powershell.exe -NoProfile -NonInteractive -File $script -RepoRoot $Root 2>&1
    return [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Text     = ($output | Out-String)
    }
}

# --------------------------------------------------------------------------------------
# Load the runner
# --------------------------------------------------------------------------------------

. (Join-Path $PSScriptRoot 'Run-Query.ps1') -DotSourceOnly

# Get-CheckCatalogue and Select-Checks read $RepoRoot from the enclosing scope, so pointing
# it at a fixture is how a test chooses which catalogue those functions see.
$RealRepoRoot = $RepoRoot

# --------------------------------------------------------------------------------------
# Selection
# --------------------------------------------------------------------------------------

$fixtureRoot = New-FixtureCatalogueRoot

Start-Group 'Runner' 'Run selection'

$RepoRoot = $fixtureRoot
$fixtureCatalogue = Get-CheckCatalogue

$fixtureSelection = Select-RunAllChecks -Catalogue $fixtureCatalogue -SportName 'Fixtureball'
$fixtureIds = @($fixtureSelection.Jobs | ForEach-Object { $_.CheckId })

Test-That '-RunAll selects exactly the Approved rows for the sport' {
    Assert-Equal 3 $fixtureIds.Count 'selected count'
    Assert-True ($fixtureIds -contains 'Fixtureball-DQ-001') 'the template instantiation should be selected'
    Assert-True ($fixtureIds -contains 'Fixtureball-DQ-002') 'the sport statement should be selected'
    Assert-True ($fixtureIds -contains 'Fixtureball-DQ-004') 'the sport override should be selected'
}

Test-That 'a template with no row for the sport is not run' {
    # GLOBAL-DQ-003 exists in the catalogue and is only ever named by a Deprecated row.
    Assert-True ($fixtureSelection.NotApprovedIds -contains 'GLOBAL-DQ-003') 'GLOBAL-DQ-003 should be reported as not approved'
    foreach ($job in $fixtureSelection.Jobs) {
        Assert-True ($job.Template -ne 'GLOBAL-DQ-003') 'no job should run GLOBAL-DQ-003'
    }
}

Test-That 'a Deprecated row is not run and is named' {
    Assert-True ($fixtureIds -notcontains 'Fixtureball-DQ-003') 'the deprecated check must not run'
    Assert-True ($fixtureSelection.DeprecatedIds -contains 'Fixtureball-DQ-003') 'the deprecated check should be reported'
}

Test-That 'a sport override runs instead of its template, not alongside it' {
    # The defect this rule exists for: Fixtureball-DQ-004 replaces GLOBAL-DQ-002, so running
    # both would report the same logical check twice, once against the wrong statement.
    $override = $fixtureSelection.Jobs | Where-Object { $_.CheckId -eq 'Fixtureball-DQ-004' }
    Assert-Equal 'Fixtureball.sql' $override.File 'the override should run the sport statement'
    Assert-True ($fixtureSelection.NotApprovedIds -notcontains 'GLOBAL-DQ-002') 'the family is approved, through the override'
    Assert-Equal 1 (@($fixtureSelection.Jobs | Where-Object { $_.Name -eq 'SECOND_TEMPLATE' }).Count) 'SECOND_TEMPLATE job count'
}

Test-That 'a job carries the sport CheckID and names the template it instantiates' {
    $instantiated = $fixtureSelection.Jobs | Where-Object { $_.CheckId -eq 'Fixtureball-DQ-001' }
    Assert-Equal 'GLOBAL-DQ-001' $instantiated.Template 'the template it instantiates'
    Assert-Equal 'FIRST_TEMPLATE' $instantiated.Name 'the statement Name'
    Assert-True ($instantiated.Sql -match 'First') 'the template body should be attached'

    $own = $fixtureSelection.Jobs | Where-Object { $_.CheckId -eq 'Fixtureball-DQ-002' }
    Assert-Equal '' $own.Template 'a sport-authored check instantiates no template'
}

Test-That 'a blocked template is reported with the reason it is blocked' {
    Assert-Equal 1 $fixtureSelection.BlockedFamilies.Count 'blocked count'
    Assert-Equal 'GLOBAL-DQ-003' $fixtureSelection.BlockedFamilies[0].Family 'blocked family'
    Assert-True ($fixtureSelection.BlockedFamilies[0].Reason -match 'fixture') 'the reason should be carried through'
}

Test-That 'a running check carries the signal recorded against its template' {
    $classified = $fixtureSelection.Jobs | Where-Object { $_.CheckId -eq 'Fixtureball-DQ-001' }
    Assert-Equal 'Monitor' $classified.Signal 'signal'
    Assert-True ($classified.SignalReason -match 'fixture') 'the reason should travel with the job'
}

Test-That 'an unclassified check defaults to actionable' {
    $plain = $fixtureSelection.Jobs | Where-Object { $_.CheckId -eq 'Fixtureball-DQ-002' }
    Assert-Equal 'Actionable' $plain.Signal 'signal'
}

Test-That 'a direct GLOBAL selection receives the sport signal outside RunAll' {
    $direct = @(Set-JobCheckSignal -Jobs @(Select-Checks -Patterns @('GLOBAL-DQ-001', 'GLOBAL-DQ-002')) `
            -SportName 'Fixtureball')
    Assert-Equal 2 $direct.Count 'direct selection count'
    $monitored = $direct | Where-Object { $_.CheckId -eq 'GLOBAL-DQ-001' }
    Assert-Equal 1 (@($monitored).Count) 'monitored direct job count'
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$monitored.Sql)) `
        'direct selection should return a job, not a nested array'
    Assert-Equal 'Monitor' $monitored.Signal 'direct selection signal'
    Assert-True ($monitored.SignalReason -match 'fixture') 'direct selection reason'
}

Test-That 'only the non-actionable checks are reported as classified' {
    Assert-Equal 1 $fixtureSelection.Classified.Count 'classified count'
    Assert-Equal 'Fixtureball-DQ-001' $fixtureSelection.Classified[0].CheckId 'classified CheckID'
}

Test-That '-RunAll excludes another sport rows' {
    Assert-True ($fixtureIds -notcontains 'Otherball-DQ-001') 'Otherball-DQ-001 must not be selected for Fixtureball'
}

Test-That 'a sport with no registry row is an error pointing at the discovery switch' {
    Assert-Throws { Select-RunAllChecks -Catalogue $fixtureCatalogue -SportName 'Nosuchball' } 'IncludeUnapproved' 'Select-RunAllChecks'
}

Test-That '-IncludeUnapproved runs the catalogue instead, and says it is unapproved' {
    $discovery = Select-RunAllChecks -Catalogue $fixtureCatalogue -SportName 'Nosuchball' -IncludeUnapproved
    Assert-Equal 3 $discovery.Jobs.Count 'template-only count'
    Assert-True $discovery.Unapproved 'the selection should be flagged unapproved'
}

Test-That '-IncludeUnapproved refuses a documented sport instead of bypassing its block' {
    Assert-Throws {
        Select-RunAllChecks -Catalogue $fixtureCatalogue -SportName 'Fixtureball' -IncludeUnapproved
    } 'genuinely undocumented' 'documented IncludeUnapproved'
}

Test-That 'the sport index maps an exact database name to its repository slug' {
    $identity = Resolve-SportIdentity -SportValue 'Water Polo'
    Assert-Equal 'Water-Polo' $identity.Slug 'repository slug'
    Assert-Equal 'Water Polo' $identity.DatabaseName 'database sport name'
    Assert-True $identity.Documented 'the index row should make the identity documented'

    $fromSlug = Resolve-SportIdentity -SportValue 'Water-Polo'
    Assert-Equal 'Water Polo' $fromSlug.DatabaseName 'database name resolved from slug'
}

Test-That 'an undocumented database name gets a slug without becoming documented' {
    $identity = Resolve-SportIdentity -DatabaseSportNameValue 'Artistic Gymnastics'
    Assert-Equal 'Artistic-Gymnastics' $identity.Slug 'derived slug'
    Assert-Equal 'Artistic Gymnastics' $identity.DatabaseName 'database name'
    Assert-True (-not $identity.Documented) 'a derived identity must remain undocumented'
}

Test-That 'an explicit repository slug cannot contain spaces' {
    Assert-Throws {
        Resolve-SportIdentity -SportSlugValue 'Arena Ball' -DatabaseSportNameValue 'Arena Ball'
    } 'slug' 'invalid explicit slug'
}

Test-That '-RunAll returns the selection sorted by CheckID' {
    $sorted = @($fixtureIds | Sort-Object)
    for ($i = 0; $i -lt $fixtureIds.Count; $i++) { Assert-Equal $sorted[$i] $fixtureIds[$i] "position $i" }
}

Test-That 'a wildcard pattern expands to every matching CheckID' {
    $ids = @((Select-Checks -Patterns @('GLOBAL-DQ-*')) | ForEach-Object { $_.CheckId })
    Assert-Equal 3 $ids.Count 'wildcard match count'
}

Test-That 'overlapping patterns do not run a check twice' {
    $ids = @((Select-Checks -Patterns @('GLOBAL-DQ-*', 'GLOBAL-DQ-001')) | ForEach-Object { $_.CheckId })
    Assert-Equal 3 $ids.Count 'deduplicated count'
}

Test-That 'a pattern matching nothing is an error rather than an empty run' {
    Assert-Throws { Select-Checks -Patterns @('NOSUCH-DQ-*') } 'No CheckID matches' 'Select-Checks'
}

Test-That 'an exact CheckID selects exactly one statement' {
    $hits = @(Select-Checks -Patterns @('Fixtureball-DQ-002'))
    Assert-Equal 1 $hits.Count 'exact match count'
    Assert-Equal 'SPORT_AUTHORED' $hits[0].Name 'selected Name'
}

Complete-Group

# --------------------------------------------------------------------------------------
# Parameter expansion
# --------------------------------------------------------------------------------------

Start-Group 'Runner' 'Parameter expansion'

Test-That 'a hashtable is accepted as given' {
    $table = ConvertTo-ParamTable -Value @{ SPORT_ID = 58 }
    Assert-Equal 58 $table['SPORT_ID'] 'SPORT_ID'
}

Test-That 'NAME=VALUE strings are accepted' {
    $table = ConvertTo-ParamTable -Value @('SPORT_ID=58', 'SHARD_ID=11')
    Assert-Equal 58 $table['SPORT_ID'] 'SPORT_ID'
    Assert-Equal 11 $table['SHARD_ID'] 'SHARD_ID'
}

Test-That 'a quoted comma separated string is split the same way an unquoted one is' {
    # PowerShell splits an unquoted -Params SPORT_ID=58,SHARD_ID=11 into an array itself, so
    # only the quoted form reaches the parser whole. Both must mean the same thing.
    $table = ConvertTo-ParamTable -Value 'SPORT_ID=58,SHARD_ID=11'
    Assert-Equal 58 $table['SPORT_ID'] 'SPORT_ID'
    Assert-Equal 11 $table['SHARD_ID'] 'SHARD_ID'
}

Test-That 'a comma inside a single value is not treated as a separator' {
    $table = ConvertTo-ParamTable -Value 'NAME=a,b'
    Assert-Equal 'a,b' $table['NAME'] 'NAME'
}

Test-That 'a parameter with no equals sign is refused' {
    Assert-Throws { ConvertTo-ParamTable -Value 'SPORT_ID' } 'Cannot read parameter' 'ConvertTo-ParamTable'
}

Test-That 'missing placeholders are listed once each' {
    $sql = 'SELECT {{SPORT_ID}}, {{SHARD_ID}}, {{SHARD_ID}} FROM t;'
    $missing = @(Get-MissingPlaceholders -Text $sql -Values @{ SPORT_ID = 58 })
    Assert-Equal 1 $missing.Count 'missing count'
    Assert-Equal 'SHARD_ID' $missing[0] 'missing name'
}

Test-That 'nothing is missing when every placeholder has a value' {
    $missing = @(Get-MissingPlaceholders -Text 'SELECT {{SPORT_ID}};' -Values @{ SPORT_ID = 58 })
    Assert-Equal 0 $missing.Count 'missing count'
}

Test-That 'every occurrence of a repeated placeholder is replaced' {
    # SHARD_ID appears three times in one join in the real templates, so a replace that
    # stops at the first would produce SQL that parses and reads the wrong table.
    $sql = 'FROM statistic_data{{SHARD_ID}} sd JOIN statistic_participants{{SHARD_ID}} sp ON sp.id = sd.statistic_participants{{SHARD_ID}}FK'
    $out = Expand-Placeholders -Text $sql -Values @{ SHARD_ID = 11 }
    Assert-True ($out -notmatch '\{\{') 'no placeholder should survive'
    Assert-Equal 3 ([regex]::Matches($out, '11').Count) 'substitution count'
}

Test-That 'a decimal parameter reaches the statement with a decimal point' {
    # The development machine runs bg-BG, where a culture-sensitive conversion would produce
    # 0,01 and send the server a tolerance it cannot parse. FULL_TIME_TOLERANCE_SECONDS is a
    # real parameter of this shape.
    $out = Expand-Placeholders -Text 'ABS(d) <= {{TOL}}' -Values @{ TOL = [decimal]0.01 }
    Assert-Equal 'ABS(d) <= 0.01' $out 'expanded text'

    $out = Expand-Placeholders -Text 'ABS(d) <= {{TOL}}' -Values @{ TOL = [double]1.5 }
    Assert-Equal 'ABS(d) <= 1.5' $out 'expanded text'
}

Test-That 'whitespace inside the braces still resolves' {
    $out = Expand-Placeholders -Text 'SELECT {{ SPORT_ID }};' -Values @{ SPORT_ID = 58 }
    Assert-Equal 'SELECT 58;' $out 'expanded text'
}

Test-That 'an unfilled placeholder is an error naming the parameter' {
    Assert-Throws { Expand-Placeholders -Text 'SELECT {{SHARD_ID}};' -Values @{} } 'SHARD_ID' 'Expand-Placeholders'
}

Test-That 'the template filter is activated in every branch that carries the marker' {
    # The findings branch and the coverage branch must narrow together, or eligible_count
    # would be counted over a scope the findings never saw.
    $sql = @"
FROM tournament_template tt
WHERE tt.del = 'no'
  -- AND tt.id = <tournament_template_id>
UNION ALL
FROM tournament_template tt
WHERE tt.del = 'no'
  -- AND tt.id = <tournament_template_id>
"@
    $out = Enable-TemplateFilter -Text $sql -TemplateIds @(44, 50, 65)

    Assert-Equal 2 $out.Activated 'both markers should be activated'
    Assert-Equal 2 ([regex]::Matches($out.Sql, [regex]::Escape('AND tt.id IN (44, 50, 65)')).Count) `
        'both branches should carry the same list'
    Assert-True ($out.Sql -notmatch '<tournament_template_id>') 'no marker should survive'
    Assert-True ($out.Sql -match '(?m)^  AND tt\.id IN') 'the marker indentation should be kept'
}

Test-That 'the alias is read from the marker rather than assumed' {
    # A statement joining the template layer twice uses tt2, ttx or tty. Narrowing on tt
    # alone would filter one branch and leave its sibling reading the whole sport.
    $sql = "-- AND tt.id = <tournament_template_id>`n" +
           "-- AND tt2.id = <tournament_template_id>`n" +
           "-- AND ttx.id = <tournament_template_id>`n" +
           "-- AND tty.id = <tournament_template_id>"
    $out = Enable-TemplateFilter -Text $sql -TemplateIds @(7)

    Assert-Equal 4 $out.Activated 'every alias should be activated'
    foreach ($alias in 'tt', 'tt2', 'ttx', 'tty') {
        Assert-True ($out.Sql -match [regex]::Escape("AND $alias.id IN (7)")) "$alias should keep its own alias"
    }
}

Test-That 'a statement with no marker reports nothing to activate' {
    # The caller stops such a statement; it must never come back silently unnarrowed.
    $sql = "FROM object_participants op`nWHERE op.object = 'sport' AND op.objectFK = 1"
    $out = Enable-TemplateFilter -Text $sql -TemplateIds @(44)

    Assert-Equal 0 $out.Activated 'nothing should be activated'
    Assert-Equal $sql $out.Sql 'the statement should be returned untouched'
}

Test-That 'a projection naming the template id is not mistaken for a filter' {
    # tt.id AS tournament_template_id occurs in nine statements and is a column, not a marker.
    $sql = "SELECT tt.id AS tournament_template_id,`n       tt.name`nFROM tournament_template tt"
    $out = Enable-TemplateFilter -Text $sql -TemplateIds @(44)

    Assert-Equal 0 $out.Activated 'a projection is not a filter'
    Assert-True ($out.Sql -match 'tt\.id AS tournament_template_id') 'the projection should survive intact'
}

Test-That 'a marked registry branch is dropped and the rest of the statement survives' {
    $sql = @"
FROM (
    SELECT ep.participantFK FROM event_participants ep
    -- REGISTRY BRANCH BEGIN
    UNION ALL

    SELECT op.participantFK
    FROM object_participants op
    WHERE op.object = 'sport'
    -- REGISTRY BRANCH END
) u
"@
    $out = Remove-RegistryBranch -Text $sql

    Assert-Equal 1 $out.Removed 'one branch should be removed'
    Assert-True ($out.Sql -notmatch 'object_participants') 'the registry branch should be gone'
    Assert-True ($out.Sql -notmatch 'UNION ALL') 'the UNION ALL joining it should go with it'
    Assert-True ($out.Sql -match 'event_participants') 'the surviving branch should be untouched'
    Assert-True ($out.Sql -match '\) u') 'the derived table should still close'
}

Test-That 'both branches of one statement are dropped together' {
    # The findings branch and the coverage branch must lose the registry at the same time, or
    # eligible_count would be counted over a population the findings never saw.
    $one = "    -- REGISTRY BRANCH BEGIN`n    UNION ALL`n    SELECT 1`n    -- REGISTRY BRANCH END`n"
    $out = Remove-RegistryBranch -Text ("A`n" + $one + "B`n" + $one + "C`n")

    Assert-Equal 2 $out.Removed 'both branches should be removed'
    Assert-Equal "A`nB`nC`n" $out.Sql 'only the marked blocks should go'
}

Test-That 'a statement marking no registry branch reports nothing to drop' {
    # GLOBAL-DQ-009 is the standing case: the registry is its audited population, so it marks
    # no branch and the caller stops rather than leaving it with nothing to audit.
    $sql = "SELECT op.participantFK FROM object_participants op WHERE op.object = 'sport'"
    $out = Remove-RegistryBranch -Text $sql

    Assert-Equal 0 $out.Removed 'nothing should be removed'
    Assert-Equal $sql $out.Sql 'the statement should be returned untouched'
}

Test-That 'GLOBAL-DQ-007 marks its registry branch and GLOBAL-DQ-009 does not' {
    # The whole mechanism rests on which statement carries the pair, so it is asserted against
    # the real file rather than a fixture.
    $file = Join-Path $RealRepoRoot 'GLOBAL_DQ\PARTICIPANTS.sql'
    $text = Get-Content -LiteralPath $file -Raw
    $statements = $text -split '(?m)^-- ={10,}\s*$'

    $seven = @($statements | Where-Object { $_ -match 'CheckID - GLOBAL-DQ-007\b' })
    $nine = @($statements | Where-Object { $_ -match 'CheckID - GLOBAL-DQ-009\b' })
    Assert-Equal 1 $seven.Count 'GLOBAL-DQ-007 should be found once'
    Assert-Equal 1 $nine.Count 'GLOBAL-DQ-009 should be found once'

    Assert-Equal 2 (Remove-RegistryBranch -Text $seven[0]).Removed 'GLOBAL-DQ-007 marks both its branches'
    Assert-Equal 0 (Remove-RegistryBranch -Text $nine[0]).Removed 'GLOBAL-DQ-009 marks none'
    Assert-True ($nine[0] -match 'object_participants') 'GLOBAL-DQ-009 still reads the registry'
}

Test-That 'an already active filter is not activated twice' {
    $sql = "  -- AND tt.id = <tournament_template_id>"
    $once = Enable-TemplateFilter -Text $sql -TemplateIds @(44)
    $twice = Enable-TemplateFilter -Text $once.Sql -TemplateIds @(50)

    Assert-Equal 0 $twice.Activated 'the second pass should find no marker'
    Assert-True ($twice.Sql -match [regex]::Escape('IN (44)')) 'the first list should stand'
}

Complete-Group

# --------------------------------------------------------------------------------------
# Catalogue parser
# --------------------------------------------------------------------------------------

Start-Group 'Runner' 'Catalogue parser'

Test-That 'the banner separates statements' {
    # Three templates in the banner-separated file, two statements in one sport file and
    # one in the other.
    Assert-Equal 6 $fixtureCatalogue.Count 'statements parsed'
}

Test-That 'the three identity comments are read' {
    $first = $fixtureCatalogue | Where-Object { $_.CheckId -eq 'GLOBAL-DQ-001' }
    Assert-Equal 'FIRST_TEMPLATE' $first.Name 'Name'
    Assert-Equal 'Finds the first thing.' $first.What 'What it does'
}

Test-That 'a block with no CheckID is not a statement' {
    $ids = @($fixtureCatalogue | ForEach-Object { $_.CheckId })
    Assert-True ($ids -notcontains 'NOT_A_CHECK') 'a block without a CheckID must be skipped'
}

Test-That 'the recorded line points at the CheckID line' {
    $second = $fixtureCatalogue | Where-Object { $_.CheckId -eq 'GLOBAL-DQ-002' }
    $line = (Get-Content -LiteralPath $second.Path)[$second.Line - 1]
    Assert-True ($line -match 'CheckID - GLOBAL-DQ-002') "line $($second.Line) should hold the CheckID, was '$line'"
}

Test-That 'the statement body travels with the entry' {
    $first = $fixtureCatalogue | Where-Object { $_.CheckId -eq 'GLOBAL-DQ-001' }
    Assert-True ($first.Sql -match 'FROM t WHERE') 'the SQL body should be attached'
    Assert-True ($first.Sql -match '^SELECT') 'the block should start at SELECT'
}

Test-That 'the response envelope is unwrapped' {
    $rows = Get-ResultRows -Content '{"sql":"SELECT 1","response":[{"a":1},{"a":2}]}'
    Assert-Equal 2 $rows.Count 'row count'
    Assert-Equal 1 $rows[0].a 'first value'
}

Test-That 'a single row is not unrolled into its columns' {
    $rows = Get-ResultRows -Content '{"response":[{"a":1,"b":2}]}'
    Assert-Equal 1 $rows.Count 'row count'
}

Test-That 'a null response is an empty result rather than one null row' {
    $rows = Get-ResultRows -Content '{"response":null}'
    Assert-Equal 0 $rows.Count 'row count'
}

Test-That 'an error payload is raised rather than returned as data' {
    Assert-Throws { Get-ResultRows -Content '{"response":"You have an error in your SQL syntax"}' } 'error' 'Get-ResultRows'
}

Test-That 'a non JSON body is reported with its first characters' {
    Assert-Throws { Get-ResultRows -Content '<html>502 Bad Gateway</html>' } 'did not return JSON' 'Get-ResultRows'
}

Complete-Group

# --------------------------------------------------------------------------------------
# Workbook writer
# --------------------------------------------------------------------------------------

Start-Group 'Runner' 'Workbook generation'

Test-That 'column names carry past Z' {
    Assert-Equal 'A' (Get-ExcelColumnName -Index 1) 'column 1'
    Assert-Equal 'Z' (Get-ExcelColumnName -Index 26) 'column 26'
    Assert-Equal 'AA' (Get-ExcelColumnName -Index 27) 'column 27'
    Assert-Equal 'AZ' (Get-ExcelColumnName -Index 52) 'column 52'
    Assert-Equal 'BA' (Get-ExcelColumnName -Index 53) 'column 53'
}

Test-That 'markup in a value is escaped' {
    Assert-Equal '&lt;b&gt; &amp; &apos;' (ConvertTo-XmlText -Text "<b> & '") 'escaped text'
}

Test-That 'control characters are dropped rather than written' {
    # XML 1.0 cannot represent them, and Excel refuses to open the file if they are emitted.
    $out = ConvertTo-XmlText -Text ("a" + [char]0x01 + "b")
    Assert-Equal 'ab' $out 'cleaned text'
}

Test-That 'a sheet name is cut to the Excel limit' {
    $name = ConvertTo-SheetName -Preferred ('X' * 40) -Fallback 'f' -Used @{}
    Assert-Equal 31 $name.Length 'sheet name length'
}

Test-That 'characters Excel forbids in a tab name are replaced' {
    $name = ConvertTo-SheetName -Preferred 'a:b\c/d?e*f[g]h' -Fallback 'f' -Used @{}
    Assert-Equal 'a_b_c_d_e_f_g_h' $name 'sanitised name'
}

Test-That 'a duplicate tab name is suffixed and stays within the limit' {
    $used = @{}
    $first = ConvertTo-SheetName -Preferred ('Y' * 31) -Fallback 'f' -Used $used
    $second = ConvertTo-SheetName -Preferred ('Y' * 31) -Fallback 'f' -Used $used
    Assert-True ($first -ne $second) 'the second tab must not reuse the first name'
    Assert-True ($second.Length -le 31) "suffixed name was $($second.Length) characters"
}

Test-That 'a number is written as a value and a string as inline text' {
    Assert-True ((Get-CellXml -Reference 'A1' -Value 42) -match '<v>42</v>') 'a number should be a v element'
    Assert-True ((Get-CellXml -Reference 'A1' -Value 'x') -match 't="inlineStr"') 'a string should be inline'
}

Test-That 'a decimal is written invariant rather than with a local comma' {
    # A bg-BG decimal comma would make Excel read the number as text.
    Assert-True ((Get-CellXml -Reference 'A1' -Value ([double]1.5)) -match '<v>1\.5</v>') 'invariant decimal point'
}

Test-That 'an over-long cell is truncated before it reaches Excel' {
    $xml = Get-CellXml -Reference 'A1' -Value ('z' * 40000)
    Assert-True ($xml -match 'truncated') 'the value should be marked truncated'
}

Test-That 'line comments are removed before the statement is collapsed' {
    $sql = "SELECT 1 -- a comment`nFROM t;"
    $out = ConvertTo-SingleLineSql -Sql $sql
    Assert-True ($out -notmatch 'comment') 'the comment should be gone'
    Assert-True ($out -notmatch "`n") 'the result should be one line'
    Assert-Equal 'SELECT 1 FROM t;' $out 'collapsed statement'
}

Test-That 'a double dash inside a string literal survives' {
    $out = ConvertTo-SingleLineSql -Sql "SELECT '--not a comment' AS x;"
    Assert-True ($out -match 'not a comment') 'the literal should be preserved'
}

Test-That 'a workbook is a readable package with one sheet per input' {
    $path = Join-Path $FixtureRoot 'book.xlsx'
    $sheets = @(
        [pscustomobject]@{ Name = 'Overview'; Rows = @([pscustomobject]@{ CheckID = 'GLOBAL-DQ-001'; Rows = 3 }) },
        [pscustomobject]@{ Name = 'FIRST_TEMPLATE'; Rows = @([pscustomobject]@{ check_type = 'First'; id = 7 }) }
    )
    Save-Workbook -Sheets $sheets -Path $path

    Assert-True (Test-Path -LiteralPath $path) 'the workbook should exist'

    Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null
    $zip = [IO.Compression.ZipFile]::OpenRead($path)
    try {
        $names = @($zip.Entries | ForEach-Object { $_.FullName })
    }
    finally { $zip.Dispose() }

    foreach ($part in @('[Content_Types].xml', 'xl/workbook.xml', 'xl/worksheets/sheet1.xml', 'xl/worksheets/sheet2.xml')) {
        Assert-True ($names -contains $part) "the package should contain $part"
    }
    Assert-True ($names -notcontains 'xl/worksheets/sheet3.xml') 'no sheet should be written for an input that was not given'
}

Test-That 'run summary defaults to Actionable and preserves an explicit signal' {
    $plainJob = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Name = 'PLAIN'; What = 'plain' }
    $plain = New-RunSummaryRow -Job $plainJob -Rows 0 -Seconds 1 -Status 'clean'
    Assert-Equal 'Actionable' $plain.Signal 'default signal'
    Assert-Equal '' $plain.SignalReason 'default reason'

    $monitorJob = [pscustomobject]@{
        CheckId = 'Fixtureball-DQ-001'; Name = 'MONITORED'; What = 'monitored'
        Signal = 'Monitor'; SignalReason = 'population-wide fixture signal'
    }
    $monitor = New-RunSummaryRow -Job $monitorJob -Rows 3 -Seconds 2 -Status 'OK'
    Assert-Equal 'Monitor' $monitor.Signal 'explicit signal'
    Assert-Equal 'population-wide fixture signal' $monitor.SignalReason 'explicit reason'
}

Test-That 'flat run summary writes Signal and SignalReason columns' {
    $job = [pscustomobject]@{
        CheckId = 'Fixtureball-DQ-001'; Name = 'MONITORED'; What = 'monitored'
        Signal = 'Monitor'; SignalReason = 'population-wide fixture signal'
    }
    $row = New-RunSummaryRow -Job $job -Rows 3 -Seconds 2 -Status 'OK'
    $path = Join-Path $FixtureRoot '_summary.csv'
    Save-RunSummaryCsv -Summary @($row) -Path $path
    $header = Get-Content -LiteralPath $path -TotalCount 1
    $saved = @(Import-Csv -LiteralPath $path)
    Assert-Equal 1 $saved.Count 'summary row count'
    Assert-Equal '"CheckId","Name","What","Rows","Seconds","Status","Signal","SignalReason"' `
        $header 'summary column order'
    Assert-Equal 'Monitor' $saved[0].Signal 'saved signal'
    Assert-Equal 'population-wide fixture signal' $saved[0].SignalReason 'saved signal reason'
}

Test-That 'workbook Overview carries Signal and Signal reason' {
    $job = [pscustomobject]@{
        CheckId = 'Fixtureball-DQ-001'; Name = 'MONITORED'; What = 'monitored'
        Sql = 'SELECT 1;'; Signal = 'Monitor'; SignalReason = 'population-wide fixture signal'
    }
    $summary = @(New-RunSummaryRow -Job $job -Rows 1 -Seconds 1 -Status 'OK')
    $collected = @([pscustomobject]@{
            Job = $job
            Rows = @([pscustomobject]@{ check_type = 'Fixture'; id = 1 })
        })
    $path = Join-Path $FixtureRoot 'run-with-signal.xlsx'
    Save-RunWorkbook -Summary $summary -Collected $collected -Path $path | Out-Null

    Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null
    $zip = [IO.Compression.ZipFile]::OpenRead($path)
    try {
        $entry = $zip.GetEntry('xl/worksheets/sheet1.xml')
        $reader = New-Object IO.StreamReader($entry.Open())
        try { $xml = $reader.ReadToEnd() } finally { $reader.Dispose() }

        $detailEntry = $zip.GetEntry('xl/worksheets/sheet2.xml')
        $detailReader = New-Object IO.StreamReader($detailEntry.Open())
        try { $detailXml = $detailReader.ReadToEnd() } finally { $detailReader.Dispose() }
    }
    finally { $zip.Dispose() }

    Assert-True ($xml -match '>Signal<') 'Overview should name the Signal column'
    Assert-True ($xml -match '>Signal reason<') 'Overview should name the Signal reason column'
    Assert-True ($xml -match '>Monitor<') 'Overview should carry the signal value'
    Assert-True ($xml -match 'population-wide fixture signal') 'Overview should carry the reason'
    Assert-True ($xml -match 'hyperlink ref="E2"') 'Rows hyperlink should keep its established column'
    Assert-True ($xml -match 'sqref="F2:F2"') 'Status validation should keep its established column'
    Assert-True ($detailXml -match '>Signal<') 'detail tab should name the Signal field'
    Assert-True ($detailXml -match '>Signal reason<') 'detail tab should name the Signal reason field'
    Assert-True ($detailXml -match 'population-wide fixture signal') 'detail tab should carry the signal reason'

    # The signal columns are hidden, not dropped, so the values asserted above must still
    # be in the part - and H:I is where the two of them land once Check By takes G.
    Assert-True ($xml -match '<cols><col min="8" max="8"[^>]*hidden="1"') 'Signal should be hidden'
    Assert-True ($xml -match '<col min="9" max="9"[^>]*hidden="1"/></cols>') 'Signal reason should be hidden'
    Assert-True ($xml.IndexOf('<cols>') -lt $xml.IndexOf('<sheetData>')) 'cols must precede sheetData'
    Assert-True ($detailXml -notmatch '<cols>') 'a check tab should hide nothing'
}

Test-That 'workbook carries the Check By column and the IT Task status' {
    $job = [pscustomobject]@{
        CheckId = 'Fixtureball-DQ-001'; Name = 'MANUAL_FIELDS'; What = 'manual'
        Sql = 'SELECT 1;'
    }
    $summary = @(New-RunSummaryRow -Job $job -Rows 1 -Seconds 1 -Status 'OK')
    $collected = @([pscustomobject]@{
            Job = $job
            Rows = @([pscustomobject]@{ check_type = 'Fixture'; id = 1 })
        })
    $path = Join-Path $FixtureRoot 'run-with-check-by.xlsx'
    Save-RunWorkbook -Summary $summary -Collected $collected -Path $path | Out-Null

    Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null
    $zip = [IO.Compression.ZipFile]::OpenRead($path)
    try {
        $entry = $zip.GetEntry('xl/worksheets/sheet1.xml')
        $reader = New-Object IO.StreamReader($entry.Open())
        try { $xml = $reader.ReadToEnd() } finally { $reader.Dispose() }

        $detailEntry = $zip.GetEntry('xl/worksheets/sheet2.xml')
        $detailReader = New-Object IO.StreamReader($detailEntry.Open())
        try { $detailXml = $detailReader.ReadToEnd() } finally { $detailReader.Dispose() }
    }
    finally { $zip.Dispose() }

    Assert-True ($xml -match '>Check By<') 'Overview should name the Check By column'
    Assert-True ($xml -match 'r="G1"[^>]*><is><t[^>]*>Check By<') 'Check By should sit in Overview column G'
    Assert-True ($xml -match '"Not Started,In Progress,IT Task,Completed"') 'IT Task should be in the dropdown'
    Assert-True ($detailXml -match 'r="F1"[^>]*><is><t[^>]*>Check By<') 'Check By should sit after Comment on a check tab'
    # An empty manual field writes no cell at all, so the reviewer types into a blank.
    Assert-True ($detailXml -notmatch 'r="F2"') 'Check By should be left empty on a check tab'
    Assert-True ($detailXml -match 'r="G1"[^>]*><is><t[^>]*>Signal<') 'Signal should follow Check By on a check tab'
}

Complete-Group

# --------------------------------------------------------------------------------------
# Approved DQ semantic regressions
#
# Test-Package.ps1 intentionally stops at static package consistency; it cannot execute the
# MySQL statements. These focused assertions pin the exact SQL shapes behind previously
# observed false-clean coverage and join-fan-out defects. They complement, rather than
# replace, the live positive controls recorded in the sport files.
# --------------------------------------------------------------------------------------

$RepoRoot = $RealRepoRoot
$realCatalogue = Get-CheckCatalogue

Start-Group 'DQ' 'Approved semantic regressions'

Test-That 'GLOBAL-DQ-111 keeps unreadable times, one event row and symmetric no-result scope' {
    $statement = @($realCatalogue | Where-Object { $_.CheckId -eq 'GLOBAL-DQ-111' })
    Assert-Equal 1 $statement.Count 'GLOBAL-DQ-111 statement count'
    $sql = $statement[0].Sql

    Assert-True ($sql -match 'EFFECTIVE_TIME_UNPARSEABLE_AND_NOT_MONOTONIC') `
        'the combined event-level violation type is missing'
    Assert-True ($sql -match '(?is)LEFT\s+JOIN\s*\(.+?\)\s*b\s+ON') `
        'unreadable left-side values would again depend on finding a peer'
    Assert-True ($sql -match '(?is)b\.is_gap\s*=\s*a\.is_gap\s+AND\s+a\.seconds\s+IS\s+NOT\s+NULL\s+AND\s+b\.seconds\s+IS\s+NOT\s+NULL\s+AND\s+b\.seconds\s*<\s*a\.seconds') `
        'the self-join no longer prunes readable non-monotonic pairs before materialization'
    Assert-True ($sql -match '(?m)^\s*GROUP BY a\.event_id\s*$') `
        'findings are not collapsed to one row per event'
    Assert-Equal 3 ([regex]::Matches($sql, 'RESULT_COMMENT_NO_RESULT_LIST')).Count `
        'no-result exclusions in the two finding inputs and coverage input'
    Assert-True ($sql -match '(?is)SELECT\s+DISTINCT\s+c\.event_id.+?\)\s+eligible') `
        'coverage no longer counts the pre-violation event population'
}

Test-That 'GLOBAL-DQ-102 keeps the scope-type list symmetric across findings and coverage' {
    $statement = @($realCatalogue | Where-Object { $_.CheckId -eq 'GLOBAL-DQ-102' })
    Assert-Equal 1 $statement.Count 'GLOBAL-DQ-102 statement count'
    $sql = $statement[0].Sql
    $branches = [regex]::Split($sql, '(?im)^\s*UNION ALL\s*$')

    Assert-Equal 2 $branches.Count 'findings and coverage branches'
    Assert-Equal 1 ([regex]::Matches($branches[0], 'es\.scope_typeFK\s+IN\s*\(\s*\{\{SCOPE_TYPE_LIST\}\}\s*\)')).Count `
        'scope-type list in findings'
    Assert-Equal 1 ([regex]::Matches($branches[1], 'es\.scope_typeFK\s+IN\s*\(\s*\{\{SCOPE_TYPE_LIST\}\}\s*\)')).Count `
        'scope-type list in coverage'
    Assert-Equal 0 ([regex]::Matches($sql, '\{\{SCOPE_TYPE_ID\}\}')).Count `
        'obsolete scalar scope parameter'
}

Test-That 'GLOBAL-DQ-025 treats configured dates as a containing interval' {
    $statement = @($realCatalogue | Where-Object { $_.CheckId -eq 'GLOBAL-DQ-025' })
    Assert-Equal 1 $statement.Count 'GLOBAL-DQ-025 statement count'
    $sql = $statement[0].Sql
    $branches = [regex]::Split($sql, '(?im)^\s*UNION ALL\s*$')

    Assert-Equal 2 $branches.Count 'findings and coverage branches'
    Assert-True ($branches[0] -match 'Config_Date_Range_Inverted') `
        'inverted interval verdict'
    Assert-True ($branches[0] -match 'Linked_Events_Outside_Both_Bounds') `
        'both-bounds verdict'
    Assert-True ($branches[0] -match 'Linked_Event_Before_Config_Start') `
        'before-start verdict'
    Assert-True ($branches[0] -match 'Linked_Event_After_Config_End') `
        'after-end verdict'
    Assert-True ($branches[0] -match 'DATE\(x\.config_start_date\)\s*>\s*DATE\(x\.config_end_date\)') `
        'inverted interval predicate'
    Assert-True ($branches[0] -match 'DATE\(x\.earliest_linked_event_startdate\)\s*<\s*DATE\(x\.config_start_date\)') `
        'linked event before configured interval predicate'
    Assert-True ($branches[0] -match 'DATE\(x\.latest_linked_event_startdate\)\s*>\s*DATE\(x\.config_end_date\)') `
        'linked event after configured interval predicate'
    Assert-Equal 0 ([regex]::Matches($sql,
            'config_(start|end)_date\)\s*<>\s*DATE\(')).Count `
        'obsolete exact-endpoint comparison'
    Assert-Equal 2 ([regex]::Matches($sql,
            'statistic_data_typeFK\s+IN\s*\(\s*\{\{CONFIG_START_DATE_TYPE_ID\}\}\s*,\s*\{\{CONFIG_END_DATE_TYPE_ID\}\}\s*\)')).Count `
        'identical active config-date eligibility in findings and coverage'
    Assert-Equal 2 ([regex]::Matches($sql,
            'JOIN\s+statistic_config\s+sce\s+ON\s+sce\.statisticFK\s*=\s*s\.id')).Count `
        'Event-id joins in findings and coverage'
    Assert-Equal 2 ([regex]::Matches($sql,
            "tt\.name\s+NOT\s+LIKE\s+'%\(IOC\)%'")).Count `
        'IOC exclusion in findings and coverage'
    Assert-True ($branches[1] -match 'COUNT\s*\(\s*DISTINCT\s+s\.id\s*\)\s+AS\s+eligible_count') `
        'coverage must count eligible statistics'
}

Test-That 'GLOBAL-DQ-030 accepts direct event participants and active lineup members' {
    $statement = @($realCatalogue | Where-Object { $_.CheckId -eq 'GLOBAL-DQ-030' })
    Assert-Equal 1 $statement.Count 'GLOBAL-DQ-030 statement count'
    $sql = $statement[0].Sql
    $branches = [regex]::Split($sql, '(?im)^\s*UNION ALL\s*$')

    Assert-Equal 2 $branches.Count 'findings and coverage branches'
    Assert-Equal 2 ([regex]::Matches($branches[0], 'AND\s+NOT\s+EXISTS\s*\(')).Count `
        'direct-participant and lineup-member exclusion paths'
    Assert-True ($branches[0] -match 'ep2\.participantFK\s*=\s*sp\.participantFK') `
        'direct event participant predicate'
    Assert-True ($branches[0] -match 'JOIN\s+lineup\s+l3\s+ON\s+l3\.event_participantsFK\s*=\s*ep3\.id') `
        'active lineup path'
    Assert-True ($branches[0] -match 'l3\.participantFK\s*=\s*sp\.participantFK') `
        'lineup member predicate'
    Assert-Equal 0 ([regex]::Matches($branches[1], 'event_participants|JOIN\s+lineup')).Count `
        'coverage must remain independent of participation representation'
    Assert-True ($branches[1] -match 'COUNT\s*\(\s*DISTINCT\s+sp\.id\s*\)\s+AS\s+eligible_count') `
        'coverage must count statistic-participant rows'
    Assert-Equal 2 ([regex]::Matches($sql, "tt\.name\s+NOT\s+LIKE\s+'%\(IOC\)%'")).Count `
        'IOC exclusion in findings and coverage'
}

Test-That 'Artistic-Gymnastics-DQ-029 excludes only confirmed postponed editions symmetrically' {
    $statement = @($realCatalogue | Where-Object { $_.CheckId -eq 'Artistic-Gymnastics-DQ-029' })
    Assert-Equal 1 $statement.Count 'Artistic-Gymnastics-DQ-029 statement count'
    $sql = $statement[0].Sql
    $branches = [regex]::Split($sql, '(?im)^\s*UNION ALL\s*$')

    Assert-Equal 2 $branches.Count 'findings and coverage branches'
    Assert-Equal 1 ([regex]::Matches($branches[0],
            't\.id\s+NOT\s+IN\s*\(\s*14678\s*,\s*36693\s*\)')).Count `
        'postponed-edition exclusion in findings'
    Assert-Equal 1 ([regex]::Matches($branches[1],
            't\.id\s+NOT\s+IN\s*\(\s*14678\s*,\s*36693\s*\)')).Count `
        'postponed-edition exclusion in coverage'
    Assert-Equal 1 ([regex]::Matches($branches[0], 'tt\.sportFK\s*=\s*40')).Count `
        'Artistic Gymnastics scope in findings'
    Assert-Equal 1 ([regex]::Matches($branches[1], 'tt\.sportFK\s*=\s*40')).Count `
        'Artistic Gymnastics scope in coverage'
    Assert-True ($branches[1] -match 'COUNT\s*\(\s*DISTINCT\s+t\.id\s*\)\s+AS\s+eligible_count') `
        'coverage must count eligible tournaments'
    Assert-Equal 0 ([regex]::Matches($sql, '\{\{\w+\}\}')).Count `
        'sport-authored statement must not retain template placeholders'
}

Test-That 'GLOBAL-DQ-109 compares two discipline sets with symmetric resolvable scope' {
    $statement = @($realCatalogue | Where-Object { $_.CheckId -eq 'GLOBAL-DQ-109' })
    Assert-Equal 1 $statement.Count 'GLOBAL-DQ-109 statement count'
    $sql = $statement[0].Sql

    Assert-Equal 2 ([regex]::Matches($sql, '(?is)GROUP_CONCAT\s*\(\s*DISTINCT\s+LOWER')).Count `
        'distinct normalized discipline set aggregates'
    Assert-True ($sql -match 'HAVING\s+property_disciplines\s+<>\s+relation_disciplines') `
        'set comparison is missing'
    Assert-Equal 2 ([regex]::Matches($sql, 'FROM\s+property\s+pr2')).Count `
        'property eligibility in findings and coverage'
    Assert-Equal 2 ([regex]::Matches($sql, 'FROM\s+object_discipline\s+od2')).Count `
        'relation eligibility in findings and coverage'
}

Test-That 'GLOBAL-DQ-113 resolves active participants in findings and coverage' {
    $statement = @($realCatalogue | Where-Object { $_.CheckId -eq 'GLOBAL-DQ-113' })
    Assert-Equal 1 $statement.Count 'GLOBAL-DQ-113 statement count'
    Assert-Equal 2 ([regex]::Matches($statement[0].Sql,
            'JOIN\s+participant\s+p\d*\s+ON\s+p\d*\.id\s*=\s*sp\d*\.participantFK')).Count `
        'active participant joins across both branches'
}

Test-That 'GLOBAL-DQ-115 audits dangling Comp.Rank references before participant resolution' {
    $statement = @($realCatalogue | Where-Object { $_.CheckId -eq 'GLOBAL-DQ-115' })
    Assert-Equal 1 $statement.Count 'GLOBAL-DQ-115 statement count'
    $sql = $statement[0].Sql
    $branches = [regex]::Split($sql, '(?im)^\s*UNION ALL\s*$')

    Assert-Equal 2 $branches.Count 'findings and coverage branches'
    Assert-True ($branches[0] -match 'LEFT\s+JOIN\s+participant\s+p\s+ON\s+p\.id\s*=\s*sp\.participantFK') `
        'findings must retain unresolved participant references'
    Assert-True ($branches[0] -match "p\.id\s+IS\s+NULL\s+OR\s+p\.del\s*<>\s*'no'") `
        'missing and soft-deleted references must both be findings'
    Assert-True ($branches[0] -match 'PARTICIPANT_REFERENCE_MISSING') `
        'missing-reference verdict'
    Assert-True ($branches[0] -match 'PARTICIPANT_REFERENCE_SOFT_DELETED') `
        'soft-deleted-reference verdict'
    Assert-Equal 0 ([regex]::Matches($branches[1], 'JOIN\s+participant')).Count `
        'coverage must not resolve participant and hide dangling rows'
    Assert-True ($branches[1] -match 'COUNT\s*\(\s*DISTINCT\s+sp\.id\s*\)\s+AS\s+eligible_count') `
        'coverage must count statistic-participant audited objects'
    Assert-Equal 2 ([regex]::Matches($sql, "tt\.name\s+NOT\s+LIKE\s+'%\(IOC\)%'")).Count `
        'IOC exclusion in findings and coverage'
    Assert-True ($sql -match 'ORDER\s+BY\s+sort_order\s*,\s*statistic_participants_id') `
        'stable audited-object order'
}

Test-That 'Curling-DQ-095 and Triathlon-DQ-070 keep participant scope symmetric' {
    $curling = @($realCatalogue | Where-Object { $_.CheckId -eq 'Curling-DQ-095' })
    $triathlon = @($realCatalogue | Where-Object { $_.CheckId -eq 'Triathlon-DQ-070' })
    Assert-Equal 1 $curling.Count 'Curling-DQ-095 statement count'
    Assert-Equal 1 $triathlon.Count 'Triathlon-DQ-070 statement count'
    Assert-True ($curling[0].Sql -match 'COUNT\(DISTINCT\s+p\.id\)') `
        'Curling-DQ-095 no longer counts distinct participants'
    Assert-Equal 2 ([regex]::Matches($curling[0].Sql, 'JOIN\s+participant\s+p\d*\s+ON')).Count `
        'Curling-DQ-095 participant joins across both branches'
    Assert-Equal 2 ([regex]::Matches($triathlon[0].Sql, 'JOIN\s+participant\s+p\s+ON')).Count `
        'Triathlon-DQ-070 participant joins across both branches'
}

Test-That 'Curling-DQ-096 scopes discipline through EXISTS rather than a fan-out join' {
    $statement = @($realCatalogue | Where-Object { $_.CheckId -eq 'Curling-DQ-096' })
    Assert-Equal 1 $statement.Count 'Curling-DQ-096 statement count'
    $sql = $statement[0].Sql
    Assert-Equal 2 ([regex]::Matches($sql, 'EXISTS\s*\(\s*SELECT\s+1\s+FROM\s+object_discipline')).Count `
        'discipline EXISTS predicates in findings and coverage'
    Assert-Equal 0 ([regex]::Matches($sql, '(?m)^JOIN\s+object_discipline')).Count `
        'fan-out object_discipline joins'
}

Complete-Group

# --------------------------------------------------------------------------------------
# Validator behaviour
#
# The registry order rule is only worth having if it bites, so it is tested by breaking a
# copy of the repository rather than by reading the code back.
# --------------------------------------------------------------------------------------

$RepoRoot = $RealRepoRoot

Start-Group 'Validator' 'Package validator'

Test-That 'the repository as it stands passes' {
    $run = Invoke-PackageValidator -Root $RepoRootPath
    Assert-Equal 0 $run.ExitCode "validator exit code; output was:`n$($run.Text)"
}

Test-That 'two swapped registry rows are reported as out of order' {
    $root = Copy-RepositoryFixture -Name 'swapped'
    $path = Join-Path $root 'POWERBI_REGISTRY.md'
    $lines = [IO.File]::ReadAllText($path) -split "`n"

    $rows = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\| \S+-DQ-\d+ \|') { $rows += $i }
    }
    $a = $rows[0]
    $b = $rows[1]
    $keep = $lines[$a]
    $lines[$a] = $lines[$b]
    $lines[$b] = $keep
    [IO.File]::WriteAllText($path, ($lines -join "`n"), (New-Object System.Text.UTF8Encoding $false))

    $run = Invoke-PackageValidator -Root $root
    Assert-Equal 1 $run.ExitCode 'validator exit code'
    Assert-True ($run.Text -match 'is out of order') "the order finding should be reported; output was:`n$($run.Text)"
}

Test-That 'a sport index row without its database name is reported' {
    $root = Copy-RepositoryFixture -Name 'sport-name-map'
    $path = Join-Path $root 'SPORTS.md'
    $lines = @([IO.File]::ReadAllText($path) -split "`n")
    $changed = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\| 58 \| BMX \|') {
            $lines[$i] = $lines[$i] -replace '\|\s*BMX\s*\|\s*$', '|  |'
            $changed = $true
            break
        }
    }
    if (-not $changed) { throw 'the BMX sport-index row was not found in the fixture copy' }
    [IO.File]::WriteAllText($path, ($lines -join "`n"), (New-Object System.Text.UTF8Encoding $false))

    $run = Invoke-PackageValidator -Root $root
    Assert-Equal 1 $run.ExitCode 'validator exit code'
    Assert-True ($run.Text -match 'has no exact Database sport name') "the mapping finding should be reported; output was:`n$($run.Text)"
}

Test-That 'one database sport name cannot map to two repository slugs' {
    $root = Copy-RepositoryFixture -Name 'duplicate-sport-name-map'
    $path = Join-Path $root 'SPORTS.md'
    $text = [IO.File]::ReadAllText($path)
    $text = $text -replace '(?m)^(\| 10 \| Curling \|[^\r\n]*\|) Curling \|\s*$', '$1 BMX |'
    [IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding $false))

    $run = Invoke-PackageValidator -Root $root
    Assert-Equal 1 $run.ExitCode 'validator exit code'
    Assert-True ($run.Text -match "database sport name 'BMX' maps to more than one slug") `
        "the duplicate mapping finding should be reported; output was:`n$($run.Text)"
}

Test-That 'a no-result value missing from the value list is reported' {
    # The defect this rule exists for: 'disq.' sat in both sports' NO_RESULT lists and in
    # neither VALUE list, so GLOBAL-DQ-052 reported it invalid and honoured it as a no-result
    # marker in the same statement. The sport files had recorded the spelling all along.
    $root = Copy-RepositoryFixture -Name 'vocabulary'
    $path = Join-Path $root 'SPORTS\params.json'
    $text = [IO.File]::ReadAllText($path)

    $before = "'q', 'dnf', 'dns', 'dsq', 'rel', 'disq.', 'disqualified'"
    if (-not $text.Contains($before)) { throw 'the BMX result comment vocabulary was not found in the fixture copy' }
    $text = $text.Replace($before, "'q', 'dnf', 'dns', 'dsq', 'rel'")
    [IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding $false))

    $run = Invoke-PackageValidator -Root $root
    Assert-Equal 1 $run.ExitCode 'validator exit code'
    Assert-True ($run.Text -match "contains 'disq\.' but RESULT_COMMENT_VALUE_LIST does not") "the vocabulary finding should be reported; output was:`n$($run.Text)"
}

Test-That 'approving a template the sport declares blocked is reported' {
    # The block is a paragraph in a sport file until something enforces it. Triathlon
    # declares GLOBAL-DQ-095 blocked, so a row approving it has to fail.
    $root = Copy-RepositoryFixture -Name 'blocked'
    $path = Join-Path $root 'POWERBI_REGISTRY.md'
    $text = [IO.File]::ReadAllText($path)

    $row = '| Triathlon-DQ-088 | Triathlon | GLOBAL-DQ-095 | WRONG_RESULTS | COMP.RANK_RESULTS | COMP.RANK_RESULTS_RANK_DUPLICATE_WITHOUT_COMMENT | `GLOBAL_DQ/STATISTICS.sql` | Approved |'
    $marker = '<!-- MANUAL PASTE ZONE: POWERBI DQ REGISTRY'
    $at = $text.IndexOf($marker)
    if ($at -lt 0) { throw 'the registry marker was not found in the fixture copy' }
    $text = $text.Substring(0, $at) + $row + "`n`n" + $text.Substring($at)
    [IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding $false))

    $run = Invoke-PackageValidator -Root $root
    Assert-Equal 1 $run.ExitCode 'validator exit code'
    Assert-True ($run.Text -match 'declares GLOBAL-DQ-095 blocked') "the block finding should be reported; output was:`n$($run.Text)"
}

Test-That 'a blank line inside the table is reported as a break' {
    $root = Copy-RepositoryFixture -Name 'broken'
    $path = Join-Path $root 'POWERBI_REGISTRY.md'
    $lines = @([IO.File]::ReadAllText($path) -split "`n")

    $at = 0
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\| \S+-DQ-\d+ \|') { $at = $i }
        elseif ($at -gt 0) { break }
    }
    # Split the block in half rather than after the last row, where a blank line is correct.
    $split = [int](($at + 1) / 2)
    $rebuilt = @($lines[0..$split]) + @('') + @($lines[($split + 1)..($lines.Count - 1)])
    [IO.File]::WriteAllText($path, ($rebuilt -join "`n"), (New-Object System.Text.UTF8Encoding $false))

    $run = Invoke-PackageValidator -Root $root
    Assert-Equal 1 $run.ExitCode 'validator exit code'
    Assert-True ($run.Text -match 'the row block breaks') "the contiguity finding should be reported; output was:`n$($run.Text)"
}

Complete-Group

# --------------------------------------------------------------------------------------
# Output
# --------------------------------------------------------------------------------------

if (Test-Path -LiteralPath $FixtureRoot) {
    Remove-Item -LiteralPath $FixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
}

$failed = @($script:Results | Where-Object { $_.Status -eq 'FAIL' })
$findingCount = (@($script:Results | ForEach-Object { $_.Findings.Count }) | Measure-Object -Sum).Sum
$overall = $(if ($failed.Count -gt 0) { 'FAIL' } else { 'PASS' })

if (-not $Quiet) {
    Write-Host ''
    Write-Host "TOOLS behaviour tests - $RepoRootPath" -ForegroundColor Cyan
    Write-Host ''

    foreach ($result in $script:Results) {
        $colour = $(if ($result.Status -eq 'FAIL') { 'Red' } else { 'Green' })
        Write-Host ("  {0,-4} {1,-10} {2}" -f $result.Status, $result.Group, $result.Name) -ForegroundColor $colour
        foreach ($finding in $result.Findings) {
            Write-Host "         $finding" -ForegroundColor Yellow
        }
    }

    Write-Host ''
    Write-Host ("  {0,-32} {1}" -f 'Cases run', $script:CaseCount) -ForegroundColor DarkGray
    Write-Host ''
    $colour = $(if ($overall -eq 'FAIL') { 'Red' } else { 'Green' })
    Write-Host "  $overall - $($failed.Count) failing group(s), $findingCount finding(s)" -ForegroundColor $colour
    Write-Host ''
}

if ($overall -eq 'FAIL') { exit 1 }
exit 0
