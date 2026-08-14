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
    },
    "_expected": {
      "Fixtureball-DQ-002": {
        "expect": "Residual",
        "residual": 4,
        "reason": "four rows in the fixture are agreed to stay, to prove the count is carried"
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

Test-That 'a sport CheckID with no statement of its own resolves through the registry' {
    # Nine in ten checks are like this: a registry row pointing at a GLOBAL_DQ template. Until
    # this resolved, they could only be run by running the whole sport - fifteen minutes to
    # see whether one correction took.
    $resolved = @(Select-Checks -Patterns @('Fixtureball-DQ-001'))
    Assert-Equal 1 $resolved.Count 'the row is found'
    Assert-Equal 'Fixtureball-DQ-001' $resolved[0].CheckId 'and carries the sport CheckID, not the template'
    Assert-Equal 'GLOBAL-DQ-001' $resolved[0].Template 'while naming the template it instantiates'
    Assert-Equal 'FIRST_TEMPLATE' $resolved[0].Name 'with the template statement behind it'
    Assert-Equal 'MISSING_VALUES' $resolved[0].Category 'and the category off its row'
}

Test-That 'a sport statement still wins over the registry path' {
    # Fixtureball-DQ-004 is the sport own version of what GLOBAL-DQ-002 expresses. The .sql
    # catalogue has it, so it is found there and the registry is never consulted.
    $own = @(Select-Checks -Patterns @('Fixtureball-DQ-004'))
    Assert-Equal 1 $own.Count 'found'
    Assert-Equal 'SECOND_TEMPLATE' $own[0].Name 'the sport own statement'
    Assert-True (-not $own[0].Template) 'and no template, because it is not an instantiation'
}

Test-That 'a deprecated row is not run because somebody typed its CheckID' {
    # The ID stays reserved for good. Being able to name it is not permission to run it.
    $threw = $false
    try { Select-Checks -Patterns @('Fixtureball-DQ-003') | Out-Null }
    catch { $threw = $true }
    Assert-True $threw 'a Deprecated row does not resolve'
}

Test-That 'a wildcard reaches registry rows as well as statements' {
    $all = @(Select-Checks -Patterns @('Fixtureball-DQ-*') | ForEach-Object { $_.CheckId })
    Assert-True ($all -contains 'Fixtureball-DQ-002') 'the sport statement'
    Assert-True ($all -contains 'Fixtureball-DQ-004') 'and the other one'
    Assert-True ($all -notcontains 'Fixtureball-DQ-003') 'but never the deprecated row'
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

Test-That 'a sport-authored statement run by ID is still filed under its registry category' {
    # It is in the catalogue under exactly the ID the user typed, so Select-Checks hits on the
    # first lookup and never reaches the registry - unlike a check instantiating a template,
    # which misses and picks its category up on the way through. Golf-DQ-085 reached a live
    # board with an empty Priority and Category beside Golf-DQ-084, which had both.
    $hydrated = @(Set-JobCheckCategory -Jobs @(Select-Checks -Patterns @('Fixtureball-DQ-002')))
    Assert-Equal 1 $hydrated.Count 'one job back, not a nested array'
    Assert-Equal 'MISSING_VALUES' ([string]$hydrated[0].Category) 'the category off its registry row'
    Assert-Equal '3 Missing value' (Get-CheckPriority -Category ([string]$hydrated[0].Category)) `
        'and the band the board sorts on'
}

Test-That 'a category the selection already carried is not re-read' {
    $job = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Category = 'WRONG_RESULTS' }
    $hydrated = @(Set-JobCheckCategory -Jobs @($job))
    Assert-Equal 'WRONG_RESULTS' ([string]$hydrated[0].Category) 'the registry row must not overwrite it'
}

Test-That 'a statement with no registry row stays uncategorised rather than guessing' {
    $hydrated = @(Set-JobCheckCategory -Jobs @(Select-Checks -Patterns @('GLOBAL-DQ-001')))
    Assert-Equal '' ([string]$hydrated[0].Category) 'a direct template run is nobody''s category'
    Assert-Equal '' (Get-CheckPriority -Category ([string]$hydrated[0].Category)) 'and no band'
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

Test-That 'the marker column is read from the marker, not assumed' {
    # The two forms are not equivalent to the optimiser. Filtering tournament_template.id makes
    # it drive from the template table and lose the index path into the statistic shards;
    # filtering tournament.tournament_templateFK keeps the plan that starts where the scope
    # does. Measured on Soccer, the same result took 28.3s one way and 2.5s the other, so the
    # activated filter has to preserve whichever column the statement declares.
    $sql = "  -- AND t.tournament_templateFK = <tournament_template_id>`n" +
           "  -- AND tt.id = <tournament_template_id>`n" +
           "  -- AND t2.tournament_templateFK = <tournament_template_id>"
    $out = Enable-TemplateFilter -Text $sql -TemplateIds @(44, 50)

    Assert-Equal 3 $out.Activated 'both marker columns should be recognised'
    Assert-True ($out.Sql -match [regex]::Escape('AND t.tournament_templateFK IN (44, 50)')) 'foreign-key form kept'
    Assert-True ($out.Sql -match [regex]::Escape('AND tt.id IN (44, 50)')) 'primary-key form kept'
    Assert-True ($out.Sql -match [regex]::Escape('AND t2.tournament_templateFK IN (44, 50)')) 'aliased foreign-key form kept'
    Assert-True ($out.Sql -notmatch '<tournament_template_id>') 'no marker should survive'
}

Test-That 'every marker that can name a tournament does' {
    # Asserted against the real files: a marker sitting where the statement already joins the
    # tournament that owns the template must filter the foreign key, or the run pays about ten
    # times the cost for the same rows. A marker with no tournament in scope keeps tt.id.
    $files = Get-ChildItem -LiteralPath $RealRepoRoot -Recurse -Filter *.sql |
        Where-Object { $_.FullName -notmatch '\\output\\' }
    $wrong = @()
    foreach ($f in $files) {
        $lines = [IO.File]::ReadAllLines($f.FullName)
        $start = 0
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^SELECT\s*$') { $start = $i }
            if ($lines[$i] -match '^\s*--\s*AND\s+(\w+)\.id\s*=\s*<tournament_template_id>') {
                $tt = $matches[1]
                $window = ($lines[$start..$i] -join "`n")
                if ($window -match ([regex]::Escape($tt) + '\.id\s*=\s*(\w+)\.tournament_templateFK')) {
                    $wrong += "$($f.Name):$($i + 1)"
                }
            }
        }
    }
    Assert-Equal 0 $wrong.Count "markers still keyed on the template primary key: $($wrong -join ', ')"
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
    # no branch. The caller runs it unchanged rather than refusing it - dropping nothing is a
    # no-op, unlike an unnarrowed statement under -TemplateIds, which would claim a scope it
    # does not have.
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
# Chaining
# --------------------------------------------------------------------------------------

Start-Group 'Runner' 'Chaining'

function New-ChainRow {
    param([hashtable]$Cells)
    return [pscustomobject]$Cells
}

function New-ChainStatement {
    param([string]$CheckId, [string]$Name, [string]$Sql)
    return [pscustomobject]@{ CheckId = $CheckId; Name = $Name; What = ''; File = 'x.sql'; Line = 1; Path = 'x.sql'; Sql = $Sql }
}

Test-That 'a source declared on the placeholder line is read' {
    $sql = "SELECT 1 WHERE r.result_typeFK = {{RESULT_TYPE_ID}}  -- select result_type_id from GLOBAL-DISCOVERY-007 (EVENT_RESULTS_TYPES_CODES)"
    $declared = Get-DeclaredFeeder -Text $sql

    Assert-True $declared.ContainsKey('RESULT_TYPE_ID') 'the placeholder should be declared'
    Assert-Equal 'result_type_id' $declared['RESULT_TYPE_ID'].Column 'column'
    Assert-Equal 'GLOBAL-DISCOVERY-007' $declared['RESULT_TYPE_ID'].CheckId 'source CheckID'
}

Test-That 'a source declared on a comment line of its own is read' {
    # GLOBAL-DISCOVERY-019 uses this form, because its placeholder appears twice on two lines
    # and neither of them is the one to hang the declaration on.
    $sql = "  -- {{ROUND_TYPE_ID}}: select round_type_id from GLOBAL-DISCOVERY-018 (EVENT_ROUND_TYPE_USAGE_SUMMARY)`n  e.round_typeFK = {{ROUND_TYPE_ID}}"
    $declared = Get-DeclaredFeeder -Text $sql

    Assert-Equal 1 $declared.Count 'one declaration'
    Assert-Equal 'round_type_id' $declared['ROUND_TYPE_ID'].Column 'column'
    Assert-Equal 'GLOBAL-DISCOVERY-018' $declared['ROUND_TYPE_ID'].CheckId 'source CheckID'
}

Test-That 'a comment naming no source declares nothing' {
    $sql = "WHERE sdt.statistic_typeFK = {{STATISTIC_TYPE_ID}}  -- same statistic_type_id as the inner filter"
    Assert-Equal 0 (Get-DeclaredFeeder -Text $sql).Count 'no declaration'
}

Test-That 'every drill-down in GLOBAL_QUERIES declares where its value comes from' {
    # Asserted against the real files, because -Chain is only as good as the declarations and a
    # statement added without one would silently stay skipped forever. The assignment is local
    # to this case, which is how Get-CheckCatalogue is pointed at a catalogue for one test.
    $RepoRoot = $RealRepoRoot
    $automatic = @{}
    foreach ($name in $DiscoverableParameters) { $automatic[$name] = 1 }

    $undeclared = @()
    foreach ($check in (Get-CheckCatalogue | Where-Object { $_.CheckId -like 'GLOBAL-DISCOVERY-*' })) {
        $missing = @(Get-MissingPlaceholders -Text $check.Sql -Values $automatic)
        if ($missing.Count -eq 0) { continue }

        $declared = Get-DeclaredFeeder -Text $check.Sql
        foreach ($name in $missing) {
            if (-not $declared.ContainsKey($name)) { $undeclared += "$($check.CheckId).$name" }
        }
    }

    Assert-Equal 0 $undeclared.Count ("undeclared drill-down parameters: " + ($undeclared -join ', '))
}

Test-That 'a declaration may narrow its source to the rows the consumer reads' {
    $sql = "AND sd.statistic_data_typeFK = {{STATISTIC_DATA_TYPE_ID}}  -- select statistic_data_type_id from GLOBAL-DISCOVERY-017 (X) where storage_layer = statistic_data{{SHARD_ID}}"
    $declared = Get-DeclaredFeeder -Text $sql

    Assert-Equal 'statistic_data_type_id' $declared['STATISTIC_DATA_TYPE_ID'].Column 'column'
    Assert-Equal 'storage_layer' $declared['STATISTIC_DATA_TYPE_ID'].Filter.Column 'filter column'
    Assert-Equal 'statistic_data{{SHARD_ID}}' $declared['STATISTIC_DATA_TYPE_ID'].Filter.Value 'filter value, still unexpanded'
}

Test-That 'a declaration without a filter reports none' {
    $sql = "AND r.result_typeFK = {{RESULT_TYPE_ID}}  -- select result_type_id from GLOBAL-DISCOVERY-007 (X)"
    Assert-True ($null -eq (Get-DeclaredFeeder -Text $sql)['RESULT_TYPE_ID'].Filter) 'no filter'
}

Test-That 'a filter keeps only its own rows and expands what the run knows' {
    $rows = @(
        (New-ChainRow @{ storage_layer = 'statistic_config'; statistic_data_type_id = 1463 }),
        (New-ChainRow @{ storage_layer = 'statistic_data11'; statistic_data_type_id = 1270 })
    )
    $filter = [pscustomobject]@{ Column = 'storage_layer'; Value = 'statistic_data{{SHARD_ID}}' }
    $kept = @(Select-FeederRow -Rows $rows -Filters @($filter) -ParamTable @{ SHARD_ID = 11 })

    Assert-Equal 1 $kept.Count 'row count'
    Assert-Equal 1270 $kept[0].statistic_data_type_id 'the data-layer row survives'
}

Test-That 'a filter the run cannot resolve selects nothing rather than everything' {
    # Answering an unresolvable filter with the unfiltered rows is the silent wrong answer the
    # whole mechanism exists to prevent, so it selects none and the caller reports no source.
    $rows = @((New-ChainRow @{ storage_layer = 'statistic_data11'; statistic_data_type_id = 1270 }))
    $filter = [pscustomobject]@{ Column = 'storage_layer'; Value = 'statistic_data{{SHARD_ID}}' }
    Assert-Equal 0 (@(Select-FeederRow -Rows $rows -Filters @($filter) -ParamTable @{}).Count) 'unresolved filter'

    $absent = [pscustomobject]@{ Column = 'no_such_column'; Value = 'x' }
    Assert-Equal 0 (@(Select-FeederRow -Rows $rows -Filters @($absent) -ParamTable @{}).Count) 'column the source does not project'
}

Test-That 'a source holding only the wrong layer is not a source' {
    # Modern Pentathlon, before the filter existed: GLOBAL-DISCOVERY-017 orders by storage layer,
    # so statistic_config always leads, and GLOBAL-DISCOVERY-028 was fed three field types the
    # data shard cannot hold. All three came back empty and GLOBAL-DISCOVERY-029 never ran.
    $detail = New-ChainStatement -CheckId 'GLOBAL-DISCOVERY-028' -Name 'STATISTIC_DATA_VALUE_PATTERNS_SUMMARY' `
        -Sql "SELECT 1 WHERE sd.statistic_data_typeFK = {{STATISTIC_DATA_TYPE_ID}}  -- select statistic_data_type_id from GLOBAL-DISCOVERY-017 (X) where storage_layer = statistic_data{{SHARD_ID}}"
    $pending = @([pscustomobject]@{ Job = $detail; Kind = 'NEEDS_SELECTION'; Missing = 'STATISTIC_DATA_TYPE_ID' })

    $configOnly = [pscustomobject]@{
        Job  = (New-ChainStatement -CheckId 'GLOBAL-DISCOVERY-017' -Name 'STATISTIC_DATA_AND_CONFIG_FIELDS' -Sql 'SELECT 1')
        Rows = @(
            (New-ChainRow @{ storage_layer = 'statistic_config'; statistic_data_type_id = 1463 }),
            (New-ChainRow @{ storage_layer = 'statistic_config'; statistic_data_type_id = 1464 })
        )
    }
    $wave = Get-ChainedJob -Pending $pending -Completed @($configOnly) -ParamTable @{ SHARD_ID = 11 } `
        -Top 3 -Budget 40 -TemplateIds @()

    Assert-Equal 0 $wave.Jobs.Count 'a config-only inventory feeds nothing to a data-shard statement'
    Assert-Equal 'NO_SOURCE' $wave.Notes[0].Kind 'reported as no source'
    Assert-True ($wave.Notes[0].Reason -match 'storage_layer') 'the reason should name the filter that emptied it'
}

Test-That 'a mixed source feeds only the rows the consumer reads' {
    $detail = New-ChainStatement -CheckId 'GLOBAL-DISCOVERY-028' -Name 'STATISTIC_DATA_VALUE_PATTERNS_SUMMARY' `
        -Sql "SELECT 1 WHERE sd.statistic_data_typeFK = {{STATISTIC_DATA_TYPE_ID}}  -- select statistic_data_type_id from GLOBAL-DISCOVERY-017 (X) where storage_layer = statistic_data{{SHARD_ID}}"
    $pending = @([pscustomobject]@{ Job = $detail; Kind = 'NEEDS_SELECTION'; Missing = 'STATISTIC_DATA_TYPE_ID' })

    $mixed = [pscustomobject]@{
        Job  = (New-ChainStatement -CheckId 'GLOBAL-DISCOVERY-017' -Name 'STATISTIC_DATA_AND_CONFIG_FIELDS' -Sql 'SELECT 1')
        Rows = @(
            (New-ChainRow @{ storage_layer = 'statistic_config'; statistic_data_type_id = 1463 }),
            (New-ChainRow @{ storage_layer = 'statistic_data11'; statistic_data_type_id = 1270 }),
            (New-ChainRow @{ storage_layer = 'statistic_data11'; statistic_data_type_id = 1271 })
        )
    }
    $wave = Get-ChainedJob -Pending $pending -Completed @($mixed) -ParamTable @{ SHARD_ID = 11 } `
        -Top 3 -Budget 40 -TemplateIds @()

    Assert-Equal 2 $wave.Jobs.Count 'only the two data-layer types'
    Assert-Equal 'STATISTIC_DATA_TYPE_ID=1270' $wave.Jobs[0].Parameters 'first data-layer type'
    Assert-Equal 'STATISTIC_DATA_TYPE_ID=1271' $wave.Jobs[1].Parameters 'second data-layer type'
}

Test-That 'a filter applies to its own source and not to a nearer one' {
    # GLOBAL-DISCOVERY-029 declares storage_layer against GLOBAL-DISCOVERY-017, but is normally
    # fed by a run of GLOBAL-DISCOVERY-028, whose result projects no storage_layer at all.
    # Carrying the filter across empties every row of it and stops the chain one step short -
    # which is what happened on the first live run after the filter was added.
    $rows = @(
        (New-ChainRow @{ statistic_data_type_id = 1270; value_pattern = '#' }),
        (New-ChainRow @{ statistic_data_type_id = 1270; value_pattern = '#.#' })
    )
    $filter = [pscustomobject]@{ CheckId = 'GLOBAL-DISCOVERY-017'; Column = 'storage_layer'; Value = 'statistic_data{{SHARD_ID}}' }

    $nearer = @(Select-FeederRow -Rows $rows -Filters @($filter) -ParamTable @{ SHARD_ID = 11 } -CheckId 'GLOBAL-DISCOVERY-028')
    Assert-Equal 2 $nearer.Count 'a filter declared against another source must not be applied here'

    $own = @(Select-FeederRow -Rows $rows -Filters @($filter) -ParamTable @{ SHARD_ID = 11 } -CheckId 'GLOBAL-DISCOVERY-017')
    Assert-Equal 0 $own.Count 'against its own source the missing column still selects nothing'
}

Test-That 'the statistic-data drill-downs declare the layer they read' {
    # Asserted against the real file: without this the chain feeds them config fields and both
    # go quiet, which is a failure that reports as clean.
    $RepoRoot = $RealRepoRoot
    $catalogue = Get-CheckCatalogue

    foreach ($id in @('GLOBAL-DISCOVERY-028', 'GLOBAL-DISCOVERY-029')) {
        $check = @($catalogue | Where-Object { $_.CheckId -eq $id })
        Assert-Equal 1 $check.Count "$id should be found once"

        $filter = (Get-DeclaredFeeder -Text $check[0].Sql)['STATISTIC_DATA_TYPE_ID'].Filter
        Assert-True ($null -ne $filter) "$id should declare a storage-layer filter"
        Assert-Equal 'storage_layer' $filter.Column "$id filter column"
        Assert-Equal 'statistic_data{{SHARD_ID}}' $filter.Value "$id filter value"
    }
}

Test-That 'a quoted placeholder is told apart from a bare one' {
    Assert-True (Test-QuotedPlaceholder -Text "x = '{{NAME_PATTERN}}'" -Name 'NAME_PATTERN') 'quoted'
    Assert-True (-not (Test-QuotedPlaceholder -Text 'x = {{ROUND_TYPE_ID}}' -Name 'ROUND_TYPE_ID')) 'bare'
}

Test-That 'a bare placeholder takes the literal NULL and a quoted one is refused' {
    # GLOBAL-DISCOVERY-019 carries an IS NULL arm, so NULL selects the events with no round
    # type. A quoted comparison can match no such thing, and running it would cost a full scan
    # to report nothing for a reason about SQL rather than about the sport.
    Assert-Equal 'NULL' (ConvertTo-ChainValue -Text 'x = {{ROUND_TYPE_ID}}' -Name 'ROUND_TYPE_ID' -Value $null) 'bare null'
    Assert-True ($null -eq (ConvertTo-ChainValue -Text "x = '{{NAME_PATTERN}}'" -Name 'NAME_PATTERN' -Value $null)) 'quoted null'
}

Test-That 'a chained string value is escaped for the quotes it lands in' {
    $value = ConvertTo-ChainValue -Text "x = '{{NAME_PATTERN}}'" -Name 'NAME_PATTERN' -Value "O'Brien a\b"
    Assert-Equal "O''Brien a\\b" $value 'escaped value'
}

Test-That 'a backslash is doubled, not quadrupled' {
    # The replacement side of -replace is a regex replacement string, where '\\\\' is four
    # literal characters. Get-SqlLiteral carried that form while nothing in the package had a
    # backslash to expose it; a name pattern comes out of the data and can.
    Assert-Equal 'a\\b' (Get-SqlEscaped -Text 'a\b') 'escaped backslash'
    Assert-Equal "'a\\b'" (Get-SqlLiteral -Text 'a\b') 'escaped literal'
}

Test-That 'value combinations keep the source order and drop repeats' {
    $rows = @(
        (New-ChainRow @{ result_type_id = 1; value_pattern = '#' }),
        (New-ChainRow @{ result_type_id = 1; value_pattern = '#' }),
        (New-ChainRow @{ result_type_id = 9; value_pattern = '#' })
    )
    $sets = @(Get-ChainValueSet -Rows $rows -Columns @('result_type_id', 'value_pattern'))

    Assert-Equal 2 $sets.Count 'distinct combinations'
    Assert-Equal 1 $sets[0]['result_type_id'] 'the summary order is kept'
    Assert-Equal 9 $sets[1]['result_type_id'] 'second combination'
}

Test-That 'columns are read as whole rows rather than crossed' {
    # Crossing the columns would offer (1,'x') and (9,'y'), which no row reported and the sport
    # may never have had.
    $rows = @(
        (New-ChainRow @{ result_type_id = 1; value_pattern = 'y' }),
        (New-ChainRow @{ result_type_id = 9; value_pattern = 'x' })
    )
    $sets = @(Get-ChainValueSet -Rows $rows -Columns @('result_type_id', 'value_pattern'))

    Assert-Equal 2 $sets.Count 'combination count'
    Assert-Equal 'y' $sets[0]['value_pattern'] 'the pair reported for 1'
    Assert-Equal 'x' $sets[1]['value_pattern'] 'the pair reported for 9'
}

$chainDetail = New-ChainStatement -CheckId 'GLOBAL-DISCOVERY-019' -Name 'EVENT_ROUND_TYPE_USAGE_DETAIL' `
    -Sql "SELECT e.id FROM event e WHERE e.sportFK = {{SPORT_ID}}`n  -- {{ROUND_TYPE_ID}}: select round_type_id from GLOBAL-DISCOVERY-018 (EVENT_ROUND_TYPE_USAGE_SUMMARY)`n  AND e.round_typeFK = {{ROUND_TYPE_ID}}"

$chainSummary = [pscustomobject]@{
    Job  = (New-ChainStatement -CheckId 'GLOBAL-DISCOVERY-018' -Name 'EVENT_ROUND_TYPE_USAGE_SUMMARY' -Sql 'SELECT 1')
    Rows = @(
        (New-ChainRow @{ round_type_id = 5 }),
        (New-ChainRow @{ round_type_id = 12 }),
        (New-ChainRow @{ round_type_id = 7 })
    )
}

$chainPending = @([pscustomobject]@{ Job = $chainDetail; Kind = 'NEEDS_SELECTION'; Missing = 'ROUND_TYPE_ID' })

Test-That 'a drill-down is bound once per value its declared source ranks first' {
    $wave = Get-ChainedJob -Pending $chainPending -Completed @($chainSummary) `
        -ParamTable @{ SPORT_ID = 58 } -Top 2 -Budget 40 -TemplateIds @()

    Assert-Equal 2 $wave.Jobs.Count 'chained job count'
    Assert-True ($wave.Jobs[0].Sql -match 'e\.round_typeFK = 5') 'the first value should be substituted'
    Assert-True ($wave.Jobs[1].Sql -match 'e\.round_typeFK = 12') 'the second value should be substituted'
    Assert-True ($wave.Jobs[0].Sql -notmatch '\{\{') 'no placeholder should survive'
    Assert-Equal 1 $wave.Resolved.Count 'the statement should be reported as chained'
}

Test-That 'a chained run keeps the CheckID and carries its values beside it' {
    # POWERBI.md makes the CheckID the identity of a statement. Running one statement three
    # times must not read as three checks, here or anywhere downstream of the workbook.
    $wave = Get-ChainedJob -Pending $chainPending -Completed @($chainSummary) `
        -ParamTable @{ SPORT_ID = 58 } -Top 1 -Budget 40 -TemplateIds @()

    Assert-Equal 'GLOBAL-DISCOVERY-019' $wave.Jobs[0].CheckId 'the CheckID is unchanged'
    Assert-Equal 'ROUND_TYPE_ID=5' $wave.Jobs[0].Parameters 'the values travel in Parameters'
    Assert-Equal 'GLOBAL-DISCOVERY-019 [ROUND_TYPE_ID=5]' (Get-JobRunKey -Job $wave.Jobs[0]) 'run key'
    Assert-Equal 'Informational' $wave.Jobs[0].Signal 'a chained discovery run is informational'
}

Test-That 'values the chain did not pursue are reported rather than dropped' {
    $wave = Get-ChainedJob -Pending $chainPending -Completed @($chainSummary) `
        -ParamTable @{ SPORT_ID = 58 } -Top 1 -Budget 40 -TemplateIds @()

    $note = @($wave.Notes | Where-Object { $_.Kind -eq 'NOT_PURSUED' })
    Assert-Equal 1 $note.Count 'one note'
    Assert-True ($note[0].Reason -match '^2 further value') 'the note should count what was left'
}

Test-That 'the ceiling stops the chain and says so' {
    $wave = Get-ChainedJob -Pending $chainPending -Completed @($chainSummary) `
        -ParamTable @{ SPORT_ID = 58 } -Top 3 -Budget 2 -TemplateIds @()

    Assert-Equal 2 $wave.Jobs.Count 'the budget should cap the wave'
    Assert-True $wave.Capped 'reaching the ceiling should be reported'
}

Test-That 'two placeholders are refused unless one result carries both' {
    # GLOBAL-DISCOVERY-027 declares RESULT_TYPE_ID against 007 and VALUE_PATTERN against 026.
    # Before 026 has run there is no result holding the pair, and taking one from each source
    # would invent a combination neither reported.
    $detail = New-ChainStatement -CheckId 'GLOBAL-DISCOVERY-027' -Name 'EVENT_RESULTS_VALUE_PATTERNS_DETAIL' `
        -Sql ("SELECT 1 WHERE r.result_typeFK = {{RESULT_TYPE_ID}}  -- select result_type_id from GLOBAL-DISCOVERY-007 (X)`n" +
            "  AND p = '{{VALUE_PATTERN}}'  -- select value_pattern from GLOBAL-DISCOVERY-026 (Y)")

    $inventory = [pscustomobject]@{
        Job  = (New-ChainStatement -CheckId 'GLOBAL-DISCOVERY-007' -Name 'EVENT_RESULTS_TYPES_CODES' -Sql 'SELECT 1')
        Rows = @((New-ChainRow @{ result_type_id = 1 }), (New-ChainRow @{ result_type_id = 9 }))
    }
    $pending = @([pscustomobject]@{ Job = $detail; Kind = 'NEEDS_SELECTION'; Missing = 'RESULT_TYPE_ID, VALUE_PATTERN' })

    $early = Get-ChainedJob -Pending $pending -Completed @($inventory) -ParamTable @{} -Top 3 -Budget 40 -TemplateIds @()
    Assert-Equal 0 $early.Jobs.Count 'nothing should be chained from two separate sources'
    Assert-Equal 'NO_SOURCE' $early.Notes[0].Kind 'the reason should be recorded'

    # Once the summary has run, one of its results carries both columns, already bound to the
    # value it was itself given.
    $summary = [pscustomobject]@{
        Job  = (New-ChainStatement -CheckId 'GLOBAL-DISCOVERY-026' -Name 'EVENT_RESULTS_VALUE_PATTERNS_SUMMARY' -Sql 'SELECT 1')
        Rows = @((New-ChainRow @{ result_type_id = 9; value_pattern = '#:#' }))
    }
    $late = Get-ChainedJob -Pending $pending -Completed @($inventory, $summary) -ParamTable @{} -Top 3 -Budget 40 -TemplateIds @()

    Assert-Equal 1 $late.Jobs.Count 'the pair should chain once the summary carries both'
    Assert-True ($late.Jobs[0].Sql -match 'r\.result_typeFK = 9') 'the co-occurring result type'
    Assert-True ($late.Jobs[0].Sql -match "p = '#:#'") 'the co-occurring pattern'
}

Test-That 'a chained statement is narrowed like every other under -TemplateIds' {
    $detail = New-ChainStatement -CheckId 'GLOBAL-DISCOVERY-019' -Name 'EVENT_ROUND_TYPE_USAGE_DETAIL' `
        -Sql ("SELECT 1 WHERE e.round_typeFK = {{ROUND_TYPE_ID}}  -- select round_type_id from GLOBAL-DISCOVERY-018 (X)`n" +
            "  -- AND t.tournament_templateFK = <tournament_template_id>")
    $pending = @([pscustomobject]@{ Job = $detail; Kind = 'NEEDS_SELECTION'; Missing = 'ROUND_TYPE_ID' })

    $wave = Get-ChainedJob -Pending $pending -Completed @($chainSummary) -ParamTable @{} -Top 1 -Budget 40 -TemplateIds @(44, 50)
    Assert-Equal 1 $wave.Jobs.Count 'chained job count'
    Assert-True ($wave.Jobs[0].Sql -match [regex]::Escape('t.tournament_templateFK IN (44, 50)')) 'the filter should be activated'
}

Test-That 'a chained statement carrying no template filter is dropped rather than run wide' {
    $detail = New-ChainStatement -CheckId 'GLOBAL-DISCOVERY-019' -Name 'EVENT_ROUND_TYPE_USAGE_DETAIL' `
        -Sql "SELECT 1 WHERE e.round_typeFK = {{ROUND_TYPE_ID}}  -- select round_type_id from GLOBAL-DISCOVERY-018 (X)"
    $pending = @([pscustomobject]@{ Job = $detail; Kind = 'NEEDS_SELECTION'; Missing = 'ROUND_TYPE_ID' })

    $wave = Get-ChainedJob -Pending $pending -Completed @($chainSummary) -ParamTable @{} -Top 1 -Budget 40 -TemplateIds @(44)
    Assert-Equal 0 $wave.Jobs.Count 'an unnarrowable chained statement must not run'
    Assert-Equal 1 (@($wave.Notes | Where-Object { $_.Kind -eq 'DROPPED' }).Count) 'the drop should be recorded'
}

Test-That 'a recorded decision carries its alternatives and leaves the answer empty' {
    $script:RunDecision = @()
    Add-RunDecision -Kind 'Statistic type and owner' -Subject 'STATISTIC_TYPE_ID' `
        -Chose 'type 11 / owner 3' -Why 'the busiest pair' -Alternatives @('type 11 / owner 5', 'type 83 / owner 3')

    Assert-Equal 1 $script:RunDecision.Count 'one decision'
    Assert-Equal 'type 11 / owner 5; type 83 / owner 3' $script:RunDecision[0].Alternatives 'alternatives'
    Assert-Equal '' $script:RunDecision[0].Answer 'the runner writes the question and never the answer'
    $script:RunDecision = @()
}

Test-That 'the decision file is written only when something is open' {
    $path = Join-Path $FixtureRoot '_decisions.json'
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }

    # An empty file would read as a run that had no decisions rather than one that recorded none.
    Assert-True ($null -eq (Save-RunDecisions -Decisions @() -Path $path)) 'nothing open writes nothing'
    Assert-True (-not (Test-Path -LiteralPath $path)) 'no file should exist'

    $decision = [pscustomobject]@{
        Decision = 'Audited nothing'; Subject = 'GLOBAL-DQ-001'; 'Run chose' = 'deferred'
        Why = 'eligible_count is 0'; Alternatives = 'a misdirected scope; a legitimately empty population'
        Answer = ''
    }
    Assert-Equal $path (Save-RunDecisions -Decisions @($decision) -Path $path) 'returns the path it wrote'

    # No byte-order mark: Set-Content -Encoding UTF8 writes one, and ConvertFrom-Json then reads
    # it as part of the first property name, which made the file unreadable by the step it
    # exists for. Asserted on the bytes, because reading it as text is what hides the problem.
    $head = [IO.File]::ReadAllBytes($path)[0..2]
    Assert-True (-not ($head[0] -eq 0xEF -and $head[1] -eq 0xBB -and $head[2] -eq 0xBF)) 'the file must carry no BOM'

    # A list even at one element. ConvertTo-Json unwraps a single-element array into a bare
    # object, and a consumer reading the file as a list then reads one decision as none.
    Assert-True ([IO.File]::ReadAllText($path).TrimStart().StartsWith('[')) 'the file must be a JSON array'

    $saved = @(Get-Content -LiteralPath $path -Raw | ConvertFrom-Json)
    Assert-Equal 1 $saved.Count 'one decision saved'
    Assert-Equal 'GLOBAL-DQ-001' $saved[0].Subject 'subject survives the round trip'
    Assert-True ($saved[0].Alternatives -match 'legitimately empty') 'both alternatives survive'

    # The round trip a reader actually performs, and the one that lost a run's decisions when
    # the file still carried a BOM: read it back and write it out again unchanged.
    Save-RunDecisions -Decisions $saved -Path $path | Out-Null
    $again = @(Get-Content -LiteralPath $path -Raw | ConvertFrom-Json)
    Assert-Equal 1 $again.Count 'the file survives being read and written again'
    Assert-Equal 'GLOBAL-DQ-001' $again[0].Subject 'and keeps its content'
}

Test-That 'the workbook carries a Decisions tab, and only when there is one' {
    $job = [pscustomobject]@{ CheckId = 'GLOBAL-DISCOVERY-001'; Name = 'SPORT_IDENTITY'; What = 'identity' }
    $summary = @(New-RunSummaryRow -Job $job -Rows 1 -Seconds 1 -Status 'OK')
    $collected = @([pscustomobject]@{ Job = $job; Rows = @([pscustomobject]@{ sport_id = 42 }) })

    $script:RunDecision = @()
    $without = Join-Path $FixtureRoot 'run-no-decisions.xlsx'
    Save-RunWorkbook -Summary $summary -Collected $collected -Path $without | Out-Null

    Add-RunDecision -Kind 'Statistic type and owner' -Subject 'STATISTIC_TYPE_ID' `
        -Chose 'type 11 / owner 3' -Why 'the busiest pair' -Alternatives @('type 11 / owner 5')
    $with = Join-Path $FixtureRoot 'run-with-decisions.xlsx'
    Save-RunWorkbook -Summary $summary -Collected $collected -Path $with | Out-Null
    $script:RunDecision = @()

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    foreach ($pair in @(@{ Path = $without; Expect = $false }, @{ Path = $with; Expect = $true })) {
        $zip = [IO.Compression.ZipFile]::OpenRead($pair.Path)
        try {
            $entry = $zip.GetEntry('xl/workbook.xml')
            $reader = New-Object IO.StreamReader($entry.Open())
            try { $xml = $reader.ReadToEnd() } finally { $reader.Dispose() }
        }
        finally { $zip.Dispose() }

        if ($pair.Expect) {
            Assert-True ($xml -match 'name="Decisions"') 'a run with an open decision should carry the tab'
            # Second, so what the run decided for itself is read before what it found.
            $names = @([regex]::Matches($xml, '<sheet name="([^"]*)"') | ForEach-Object { $_.Groups[1].Value })
            Assert-Equal 'Decisions' $names[1] 'Decisions should sit straight after Overview'
        }
        else {
            Assert-True ($xml -notmatch 'name="Decisions"') 'a run with none should carry no tab'
        }
    }
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

Test-That 'the SQL sheet keeps a statement on its own lines' {
    $entries = @(
        [pscustomobject]@{ CheckId = 'GLOBAL-DQ-001'; Name = 'FIRST'; Sql = "SELECT 1`nFROM t;" },
        [pscustomobject]@{ CheckId = 'GLOBAL-DQ-002'; Name = 'SECOND'; Sql = "SELECT 2;" })
    $built = New-SqlSheet -Entries $entries -TabOf @{ 'GLOBAL-DQ-001' = 'FIRST'; 'GLOBAL-DQ-002' = 'SECOND' }

    # Row 1 is the column-name row, so the first block starts at row 2 and the second one
    # after two SQL lines and a blank separator.
    Assert-Equal 'A2' $built.Anchor['GLOBAL-DQ-001'] 'first block anchor'
    Assert-Equal 'A6' $built.Anchor['GLOBAL-DQ-002'] 'second block anchor'

    $statements = @($built.Sheet.Rows | ForEach-Object { $_.'Statement' })
    Assert-Equal 'SELECT 1' $statements[1] 'the statement keeps its own first line'
    Assert-Equal 'FROM t;' $statements[2] 'and its second'
}

Test-That 'a statement with no tab still gets a block' {
    $built = New-SqlSheet -Entries @(
        [pscustomobject]@{ CheckId = 'GLOBAL-DQ-003'; Name = 'THIRD'; Sql = 'SELECT 3;' }) -TabOf @{}
    Assert-Equal 'A2' $built.Anchor['GLOBAL-DQ-003'] 'the block is anchored'
    Assert-Equal 0 @($built.Sheet.Links).Count 'with no link back to a tab that does not exist'
}

Test-That 'nothing collected produces no SQL sheet' {
    Assert-True ($null -eq (New-SqlSheet -Entries @() -TabOf @{})) 'an empty run has no SQL sheet'
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
    # RunKey and Parameters follow the CheckID: a chained run repeats the CheckID by design,
    # and these two are what tell one execution of it from the next. Findings and Eligible sit
    # beside Rows because they are what make two runs comparable: Rows counts the COVERAGE row
    # in with the findings, and says nothing about the population they came out of.
    $expected = '"CheckId","RunKey","Parameters","Name","What","Rows","Findings","Eligible",' +
        '"Seconds","Status","Priority","Category","Signal","SignalReason",' +
        '"Expected","ExpectedResidual","ExpectedReason",' +
        '"Verdict","Change","PrevFindings","PrevEligible","PrevRunId","Trend"'
    Assert-Equal $expected $header 'summary column order'
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
    Assert-True ($xml -match 'hyperlink ref="H2"') 'Rows hyperlink should follow its column'
    Assert-True ($xml -match 'sqref="I2:I2"') 'Status validation should follow its column'
    Assert-True ($detailXml -match '>Signal<') 'detail tab should name the Signal field'
    Assert-True ($detailXml -match '>Signal reason<') 'detail tab should name the Signal reason field'
    Assert-True ($detailXml -match 'population-wide fixture signal') 'detail tab should carry the signal reason'

    # The signal columns are hidden, not dropped, so the values asserted above must still
    # be in the part - and L:M is where the two of them land once Priority and Category take
    # E and F, Parameters takes C and Comment takes K.
    Assert-True ($xml -match '<cols><col min="12" max="12"[^>]*hidden="1"') 'Signal should be hidden'
    Assert-True ($xml -match '<col min="13" max="13"[^>]*hidden="1"/></cols>') 'Signal reason should be hidden'
    Assert-True ($xml.IndexOf('<cols>') -lt $xml.IndexOf('<sheetData>')) 'cols must precede sheetData'
    Assert-True ($detailXml -notmatch '<cols>') 'a check tab should hide nothing'
}

Test-That 'workbook Overview carries the comparison block without moving what was there' {
    $job = [pscustomobject]@{
        CheckId = 'Fixtureball-DQ-001'; Name = 'COMPARED'; What = 'compared'
        Sql = 'SELECT 1;'; Expected = 'Zero'
    }
    # A previous run to be read against, so the block has something to show rather than the
    # empty cells a first run would produce.
    $script:PreviousRun = @{ 'Fixtureball-DQ-001' = [pscustomobject]@{
            RunId = 'Fixtureball 01.01.2026 09-00-00'; Findings = 40; Eligible = 900 } }
    $summary = @(New-RunSummaryRow -Job $job -Rows 4 -Seconds 1 -Status 'OK' -Eligible 900 -Findings 3)
    $script:PreviousRun = @{}

    $collected = @([pscustomobject]@{
            Job = $job
            Rows = @([pscustomobject]@{ check_type = 'COVERAGE'; eligible_count = 900 })
        })
    $path = Join-Path $FixtureRoot 'run-with-comparison.xlsx'
    Save-RunWorkbook -Summary $summary -Collected $collected -Path $path | Out-Null

    Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null
    $zip = [IO.Compression.ZipFile]::OpenRead($path)
    try {
        $entry = $zip.GetEntry('xl/worksheets/sheet1.xml')
        $reader = New-Object IO.StreamReader($entry.Open())
        try { $xml = $reader.ReadToEnd() } finally { $reader.Dispose() }
    }
    finally { $zip.Dispose() }

    foreach ($column in @('Expected', 'Findings', 'Eligible', 'Prev findings', 'Prev eligible',
            'Change', 'Verdict', 'Last run')) {
        Assert-True ($xml -match (">{0}<" -f [regex]::Escape($column))) "Overview should name the $column column"
    }
    Assert-True ($xml -match '>Improved<') 'Overview should carry the verdict'
    Assert-True ($xml -match 'Fixtureball 01.01.2026 09-00-00') 'and which run it was read against'

    # The whole reason the block is appended rather than inserted: these three are pinned in
    # the row builder, the validation sqref and here at once, and an inserted column would
    # break the row-count link, the Status dropdown and the Comment mirror together.
    Assert-True ($xml -match 'hyperlink ref="H2"') 'Rows should still link from H'
    Assert-True ($xml -match 'sqref="I2:I2"') 'Status validation should still bind to I'
    Assert-True ($xml -match '<col min="12" max="12"[^>]*hidden="1"') 'Signal should still be hidden at L'
    Assert-True ($xml -match '<col min="13" max="13"[^>]*hidden="1"/></cols>') 'Signal reason should still be M, and the last hidden one'
}

Test-That 'workbook carries the Check By column and the outcome statuses' {
    $job = [pscustomobject]@{
        CheckId = 'Fixtureball-DQ-001'; Name = 'MANUAL_FIELDS'; What = 'manual'
        Sql = 'SELECT 1;'
    }
    $summary = @(New-RunSummaryRow -Job $job -Rows 1 -Seconds 1 -Status 'OK')
    # A statement that found nothing still returns its COVERAGE row, and the count in it is
    # what lets the workbook call the result clean.
    $collected = @([pscustomobject]@{
            Job = $job
            Rows = @([pscustomobject]@{ check_type = 'COVERAGE'; id = $null; eligible_count = 806 })
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
    Assert-True ($xml -match 'r="J1"[^>]*><is><t[^>]*>Check By<') 'Check By should sit in Overview column J'
    Assert-True ($xml -match 'r="C1"[^>]*><is><t[^>]*>Parameters<') 'Parameters should sit beside the CheckID it qualifies'
    Assert-True ($xml -match 'r="E1"[^>]*><is><t[^>]*>Priority<') 'Priority should sit beside Check Name'
    Assert-True ($xml -match 'r="F1"[^>]*><is><t[^>]*>Category<') 'Category should follow Priority'
    # One vocabulary for the workbook and the live board, taken from $SheetsStatusBands so
    # the two cannot drift; the column held nine spellings of five ideas when they could.
    Assert-True ($xml -match '"Not reviewed,Clean,Monitor Only,Reviewing,Completed,IT Fix,Deprecated"') 'the dropdown should offer the outcome statuses'
    Assert-True ($xml -match '>Clean<') 'a check returning only its COVERAGE row should open as Clean'
    Assert-True ($detailXml -match 'r="H1"[^>]*><is><t[^>]*>Check By<') 'Check By should sit after Comment on a check tab'
    # An empty manual field writes no cell at all, so the reviewer types into a blank.
    Assert-True ($detailXml -notmatch 'r="H2"') 'Check By should be left empty on a check tab'
    Assert-True ($detailXml -match 'r="I1"[^>]*><is><t[^>]*>Signal<') 'Signal should follow Check By on a check tab'
}

Test-That 'Overview Comment mirrors the check tab it belongs to' {
    # The apostrophe is the point of the name: a sheet reference quotes the name, so a quote
    # inside it has to be doubled or the formula ends early and the file opens broken.
    $job = [pscustomobject]@{
        CheckId = 'Fixtureball-DQ-001'; Name = "KEEPER'S_COMMENT"; What = 'mirrored'
        Sql = 'SELECT 1;'
    }
    # A check that never ran has no tab, so its Comment cell must stay empty rather than
    # point at a sheet that is not in the book.
    $failed = [pscustomobject]@{
        CheckId = 'Fixtureball-DQ-002'; Name = 'NEVER_RAN'; What = 'failed'
        Sql = 'SELECT 2;'
    }
    $summary = @(
        (New-RunSummaryRow -Job $job -Rows 1 -Seconds 1 -Status 'OK'),
        (New-RunSummaryRow -Job $failed -Rows 0 -Seconds 1 -Status 'ERROR: fixture')
    )
    $collected = @([pscustomobject]@{
            Job = $job
            Rows = @([pscustomobject]@{ check_type = 'Fixture'; id = 1 })
        })
    $path = Join-Path $FixtureRoot 'run-with-comment.xlsx'
    Save-RunWorkbook -Summary $summary -Collected $collected -Path $path | Out-Null

    Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null
    $zip = [IO.Compression.ZipFile]::OpenRead($path)
    try {
        $entry = $zip.GetEntry('xl/worksheets/sheet1.xml')
        $reader = New-Object IO.StreamReader($entry.Open())
        try { $xml = $reader.ReadToEnd() } finally { $reader.Dispose() }

        $bookEntry = $zip.GetEntry('xl/workbook.xml')
        $bookReader = New-Object IO.StreamReader($bookEntry.Open())
        try { $bookXml = $bookReader.ReadToEnd() } finally { $bookReader.Dispose() }
    }
    finally { $zip.Dispose() }

    Assert-True ($xml -match 'r="K1"[^>]*><is><t[^>]*>Comment<') 'Comment should sit in Overview column K'
    # Compared after decoding, because the part carries the formula XML-escaped and it is the
    # formula the reader ends up with that has to be right.
    $formula = [regex]::Match($xml, 'r="K2"[^>]*><f>(.*?)</f>').Groups[1].Value
    Assert-Equal "='KEEPER''S_COMMENT'!G2" ([Net.WebUtility]::HtmlDecode($formula)) 'Comment should read G2 on the check tab, with the name quote doubled'
    Assert-True ($xml -notmatch 'r="K3"') 'a check with no tab should get no Comment formula'
    # A formula carrying no cached result shows nothing until the reader computes it.
    Assert-True ($bookXml -match 'fullCalcOnLoad="1"') 'the workbook should be told to calculate on open'
    Assert-True ($bookXml.IndexOf('</sheets>') -lt $bookXml.IndexOf('<calcPr')) 'calcPr must follow sheets'
}

Test-That 'an id window is activated and reports the object it keys on' {
    $sql = @'
SELECT p.id
FROM participant p
WHERE p.del = 'no'
  -- AND p.id BETWEEN <from_participant_id> AND <to_participant_id>
'@
    $shard = Enable-ShardFilter -Text $sql -From 1567 -To 900000
    Assert-Equal 1 $shard.Activated 'one window found'
    Assert-Equal 'participant' $shard.Object 'the placeholder names the table to read the range from'
    Assert-True ($shard.Sql -match 'AND p\.id BETWEEN 1567 AND 900000') 'the window is written into the statement'
    Assert-True ($shard.Sql -notmatch '<from_') 'no placeholder survives'

    # A statement with no window cannot be cut, and says so rather than being guessed at.
    Assert-True ($null -eq (Enable-ShardFilter -Text 'SELECT 1;' -From 1 -To 2)) 'no marker means no shard'
}

Test-That 'only a result too large is answered by cutting it up' {
    Assert-True (Test-ResultTooLarge -Message 'Allowed memory size of 134217728 bytes exhausted') 'the failure sharding exists for'
    Assert-True (Test-ResultTooLarge -Message 'Out of memory') 'and its other wording'
    # Cutting a slow statement multiplies the time instead of dividing the rows.
    Assert-True (-not (Test-ResultTooLarge -Message 'Maximum execution time of 300 seconds exceeded')) 'a slow statement is not a large one'
    Assert-True (-not (Test-ResultTooLarge -Message 'Unknown column p.nope in field list')) 'nor is a broken one'
}

Test-That 'merging shards concatenates findings and sums coverage' {
    $first = @(
        [pscustomobject]@{ check_type = 'No_Participation'; participant_id = 11; eligible_count = $null }
        [pscustomobject]@{ check_type = 'No_Participation'; participant_id = 12; eligible_count = $null }
        [pscustomobject]@{ check_type = 'COVERAGE'; participant_id = $null; eligible_count = 200 })
    $second = @(
        [pscustomobject]@{ check_type = 'No_Participation'; participant_id = 90; eligible_count = $null }
        [pscustomobject]@{ check_type = 'COVERAGE'; participant_id = $null; eligible_count = 193933 })

    $merged = @(Merge-ShardedRows -Parts @($first, $second))

    Assert-Equal 4 $merged.Count 'three findings and one coverage row'
    $coverage = @($merged | Where-Object { $_.check_type -eq 'COVERAGE' })
    Assert-Equal 1 $coverage.Count 'the shards must not each keep their own coverage row'
    Assert-Equal 194133 $coverage[0].eligible_count 'the counts are summed, not repeated'
    Assert-Equal 'COVERAGE' $merged[-1].check_type 'coverage still sorts last'
}

Test-That 'the workbook seeds the two statuses it can settle itself' {
    Assert-Equal 'Monitor Only' (Get-SeededStatus -Signal 'Informational' -Rows 40 -Ran $true -Eligible $null) `
        'an informational check has nothing to act on whatever it returned'
    Assert-Equal 'Clean' (Get-SeededStatus -Signal 'Actionable' -Rows 1 -Ran $true -Eligible 20000) `
        'only the COVERAGE row, over a population, means nothing was found today'
    Assert-Equal 'Not reviewed' (Get-SeededStatus -Signal 'Actionable' -Rows 12 -Ran $true -Eligible 20000) `
        'findings wait for a reviewer'
    Assert-Equal 'Not reviewed' (Get-SeededStatus -Signal 'Monitor' -Rows 900 -Ran $true -Eligible 20000) `
        'a monitored check still wants reading'
    # A failed check reports one cell too, but it holds the word ERROR rather than a coverage
    # count, so it must never be seeded as a clean result.
    Assert-Equal 'Not reviewed' (Get-SeededStatus -Signal 'Actionable' -Rows 'ERROR' -Ran $false -Eligible $null) `
        'a failed check produced no verdict'
    # An informational check that failed is still a failure. A closing status asserts that
    # somebody read an output, and a check that did not run has none to have read.
    Assert-Equal 'Not reviewed' (Get-SeededStatus -Signal 'Informational' -Rows 'ERROR' -Ran $false -Eligible $null) `
        'a failed check is never closed, whatever its signal'
}

Test-That 'a check that audited nothing is never called clean' {
    # The whole point of the coverage contract. Both of these return one row and no findings;
    # only the eligible_count inside that row says whether anything was looked at.
    Assert-Equal 'Clean' (Get-SeededStatus -Signal 'Actionable' -Rows 1 -Ran $true -Eligible 952) `
        'zero findings over a real population is clean data'
    Assert-Equal 'Not reviewed' (Get-SeededStatus -Signal 'Actionable' -Rows 1 -Ran $true -Eligible 0) `
        'zero findings over nothing is not clean data and wants a person'
    # No COVERAGE branch at all means the single row is a finding, not a coverage count.
    Assert-Equal 'Not reviewed' (Get-SeededStatus -Signal 'Actionable' -Rows 1 -Ran $true -Eligible $null) `
        'a statement with no coverage branch cannot be read as clean'
}

Test-That 'the coverage count is read out of the COVERAGE row' {
    $withFindings = @(
        [pscustomobject]@{ check_type = 'Missing_DOB'; participant_id = 7; eligible_count = $null }
        [pscustomobject]@{ check_type = 'COVERAGE'; participant_id = $null; eligible_count = 1064 })
    Assert-Equal 1064 (Get-CoverageCount -Rows $withFindings) 'the COVERAGE row carries the count'

    $auditedNothing = @([pscustomobject]@{ check_type = 'COVERAGE'; eligible_count = 0 })
    Assert-Equal 0 (Get-CoverageCount -Rows $auditedNothing) 'a zero is read as a zero, not as absent'

    # A discovery statement declares no coverage branch, and $null is how that is said.
    $census = @([pscustomobject]@{ round_type_id = 9; events = 412 })
    Assert-True ($null -eq (Get-CoverageCount -Rows $census)) 'no COVERAGE branch means no count'

    # The value arrives from the database as text.
    $asText = @([pscustomobject]@{ check_type = 'COVERAGE'; eligible_count = '  3388 ' })
    Assert-Equal 3388 (Get-CoverageCount -Rows $asText) 'a numeric string is still a count'
}

Test-That 'the statement lives on the SQL sheet and C2 jumps to it' {
    $job = [pscustomobject]@{
        CheckId = 'Fixtureball-DQ-002'; Name = 'SQL_OFF_THE_TAB'; What = 'sql'
        Sql = "SELECT 1`nFROM t;"
    }
    $summary = @(New-RunSummaryRow -Job $job -Rows 1 -Seconds 1 -Status 'OK')
    $collected = @([pscustomobject]@{
            Job = $job
            Rows = @([pscustomobject]@{ check_type = 'Fixture'; id = 1 })
        })
    $path = Join-Path $FixtureRoot 'run-with-sql-sheet.xlsx'
    Save-RunWorkbook -Summary $summary -Collected $collected -Path $path | Out-Null

    Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null
    $zip = [IO.Compression.ZipFile]::OpenRead($path)
    try {
        $read = {
            param($name)
            $entry = $zip.GetEntry($name)
            if (-not $entry) { return $null }
            $reader = New-Object IO.StreamReader($entry.Open())
            try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
        }
        $detailXml = & $read 'xl/worksheets/sheet2.xml'
        $sqlXml = & $read 'xl/worksheets/sheet3.xml'
        $workbookXml = & $read 'xl/workbook.xml'
    }
    finally { $zip.Dispose() }

    Assert-True ($workbookXml -match 'name="SQL"') 'the workbook should carry a SQL sheet'

    # C2 holds a short label, never the statement: a cell of a few thousand characters is
    # what pushed the result table out of shape when it was opened.
    Assert-True ($detailXml -match 'r="C2"[^>]*><is><t[^>]*>SQL<') 'C2 should read SQL'
    Assert-True ($detailXml -notmatch 'SELECT 1') 'the statement should not be on the check tab'
    # The sheet name is quoted in the location and the quotes reach the part XML-escaped.
    Assert-True ($detailXml -match 'location="&apos;SQL&apos;!A2"') 'C2 should jump to the block, not to the top of the sheet'

    # The statement keeps the line breaks it was written with.
    Assert-True ($sqlXml -match '>SELECT 1<') 'the first line stands alone'
    Assert-True ($sqlXml -match '>FROM t;<') 'and so does the second'
    Assert-True ($sqlXml -match 'location="&apos;SQL_OFF_THE_TAB&apos;!A1"') 'the block should link back to its results'
}

Complete-Group

# --------------------------------------------------------------------------------------
# Expectations and the run ledger
#
# What a re-run should return, and whether the run before it can still be read. Both exist
# for the same reason: a catalogue of fifty checks cannot be re-read after a round of
# corrections by remembering which ones were ever supposed to reach zero.
# --------------------------------------------------------------------------------------

$RepoRoot = $fixtureRoot

Start-Group 'Runner' 'Expectations and ledger'

Test-That 'findings are the row count less the COVERAGE row' {
    $rows = @(
        [pscustomobject]@{ check_type = 'Missing_DOB'; eligible_count = $null },
        [pscustomobject]@{ check_type = 'Missing_DOB'; eligible_count = $null },
        [pscustomobject]@{ check_type = 'COVERAGE'; eligible_count = 900 })
    Assert-Equal 2 (Get-FindingCount -Rows $rows) 'two findings out of three rows'
    Assert-Equal 900 (Get-CoverageCount -Rows $rows) 'the eligible population'
}

Test-That 'a check reporting its COVERAGE row alone has no findings' {
    $rows = @([pscustomobject]@{ check_type = 'COVERAGE'; eligible_count = 40 })
    Assert-Equal 0 (Get-FindingCount -Rows $rows) 'a clean check found nothing'
}

Test-That 'a statement with no check_type reports no finding count rather than guessing' {
    # A discovery census has no COVERAGE row to subtract, so calling every row a finding
    # would put a number in the ledger that means nothing when the next run compares it.
    $rows = @([pscustomobject]@{ round_type_id = 5; events = 412 })
    Assert-Equal $null (Get-FindingCount -Rows $rows) 'no finding count without a check_type'
}

Test-That 'an expectation is derived from the signal when the sport records none' {
    $jobs = @(
        [pscustomobject]@{ CheckId = 'Fixtureball-DQ-001'; Signal = 'Monitor' },
        [pscustomobject]@{ CheckId = 'Fixtureball-DQ-004'; Signal = 'Actionable' },
        [pscustomobject]@{ CheckId = 'Fixtureball-DQ-003'; Signal = 'Blocked' })
    $hydrated = @(Set-JobCheckExpectation -Jobs $jobs -SportName 'Fixtureball')

    Assert-Equal 'Non-zero' $hydrated[0].Expected 'a Monitor check keeps rows however much is corrected'
    Assert-Equal 'Zero' $hydrated[1].Expected 'an actionable check should reach its COVERAGE row alone'
    Assert-Equal '' $hydrated[2].Expected 'a blocked check has no count anybody should expect'
}

Test-That 'a check outside the client boundary is a recordable signal expecting no count' {
    # The third member of the family that expects nothing, and the one that lifts on a decision
    # rather than on a repair or an import. Golf's knockout checks are the case: the sport
    # contests match play almost only under templates the client does not take, so the check
    # audits a real population belonging to somebody else.
    Assert-True ($CheckSignalValues -contains 'Out of client scope') 'the runner accepts it'
    Assert-Equal '' (Get-ExpectedForSignal -Signal 'Out of client scope') `
        'and nobody should be expecting a count from it'

    # Distinct from Not applicable, which the vocabulary keeps for a structure the sport does
    # not have at all. Both suppress the run's eligible_count = 0 question; neither turns that
    # zero into clean data.
    Assert-Equal '' (Get-ExpectedForSignal -Signal 'Not applicable') 'the sibling is unchanged'
    Assert-Equal 'Non-zero' (Get-ExpectedForSignal -Signal 'Monitor') 'and a running check still is'
}

Test-That 'a recorded expectation overrides the one the signal implies' {
    $jobs = @([pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Signal = 'Actionable' })
    $hydrated = @(Set-JobCheckExpectation -Jobs $jobs -SportName 'Fixtureball')

    Assert-Equal 'Residual' $hydrated[0].Expected 'the recorded value wins over the derived one'
    Assert-Equal 4 $hydrated[0].ExpectedResidual 'the residual count is carried'
    Assert-True ($hydrated[0].ExpectedReason -like '*agreed to stay*') 'the reason travels with it'
}

Test-That 'an expectation recorded against a template reaches the sport statement that runs it' {
    # The sport's CheckID is what the registry makes the stable identifier, but a sport that
    # instantiates a template classifies the template. Both keys have to resolve.
    $jobs = @([pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Template = 'GLOBAL-DQ-002'; Signal = 'Actionable' })
    $hydrated = @(Set-JobCheckExpectation -Jobs $jobs -SportName 'Fixtureball')
    Assert-Equal 'Residual' $hydrated[0].Expected 'the sport CheckID resolves when the template records nothing'
}

Test-That 'the run summary carries findings, eligible and the expectation' {
    $job = [pscustomobject]@{
        CheckId = 'Fixtureball-DQ-002'; Name = 'SPORT_AUTHORED'; What = 'a thing'
        Signal = 'Actionable'; Expected = 'Residual'; ExpectedResidual = 4; ExpectedReason = 'agreed'
    }
    $row = New-RunSummaryRow -Job $job -Rows 6 -Seconds 1 -Status 'OK' -Eligible 900 -Findings 5
    Assert-Equal 5 $row.Findings 'findings'
    Assert-Equal 900 $row.Eligible 'eligible'
    Assert-Equal 'Residual' $row.Expected 'expectation'
    Assert-Equal 4 $row.ExpectedResidual 'residual count'
}

Test-That 'a run is appended to the sport ledger, newest last' {
    $ledgerDir = Join-Path $fixtureRoot 'RUNS'
    if (Test-Path -LiteralPath $ledgerDir) { Remove-Item -LiteralPath $ledgerDir -Recurse -Force }

    $job = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Name = 'SPORT_AUTHORED'; What = 'a thing'; Expected = 'Zero' }
    $first = @(New-RunSummaryRow -Job $job -Rows 41 -Seconds 1 -Status 'OK' -Eligible 900 -Findings 40)
    Save-RunLedger -Summary $first -Output 'Fixtureball 01.01.2026 09-00-00' | Out-Null

    $second = @(New-RunSummaryRow -Job $job -Rows 4 -Seconds 1 -Status 'OK' -Eligible 900 -Findings 3)
    $written = @(Save-RunLedger -Summary $second -Output 'Fixtureball 02.01.2026 09-00-00')

    Assert-Equal 1 $written.Count 'one file per sport'
    $ledger = Get-Content -LiteralPath $written[0] -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-Equal 'Fixtureball' $ledger.sport 'the ledger names its sport'
    Assert-Equal 2 @($ledger.runs).Count 'both runs are kept'
    Assert-Equal 'Fixtureball 02.01.2026 09-00-00' $ledger.runs[-1].runId 'newest last, so a diff shows the run just added'
    Assert-Equal 40 $ledger.runs[0].checks[0].findings 'the first run keeps its findings'
    Assert-Equal 3 $ledger.runs[-1].checks[0].findings 'and the second keeps its own'
    Assert-Equal 900 $ledger.runs[-1].checks[0].eligible 'the population both were read against'
}

Test-That 'a discovery statement is left out of the ledger' {
    # A round type with a count is not a finding that can be resolved, so recording it would
    # fill the history with numbers nobody is going to compare.
    $ledgerDir = Join-Path $fixtureRoot 'RUNS'
    if (Test-Path -LiteralPath $ledgerDir) { Remove-Item -LiteralPath $ledgerDir -Recurse -Force }

    $script:RunSportName = 'Fixtureball'
    $discovery = [pscustomobject]@{ CheckId = 'GLOBAL-DISCOVERY-018'; Name = 'ROUND_TYPES'; What = 'census' }
    $check = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Name = 'SPORT_AUTHORED'; What = 'a thing' }
    $summary = @(
        (New-RunSummaryRow -Job $discovery -Rows 9 -Seconds 1 -Status 'OK'),
        (New-RunSummaryRow -Job $check -Rows 4 -Seconds 1 -Status 'OK' -Eligible 900 -Findings 3))

    $written = @(Save-RunLedger -Summary $summary -Output 'Fixtureball 03.01.2026 09-00-00')
    $script:RunSportName = ''

    $ledger = Get-Content -LiteralPath $written[0] -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-Equal 1 @($ledger.runs[-1].checks).Count 'only the check is recorded'
    Assert-Equal 'Fixtureball-DQ-002' $ledger.runs[-1].checks[0].checkId 'and it is the DQ one'
}

Test-That 'a run mixing sports writes to each sport ledger' {
    $ledgerDir = Join-Path $fixtureRoot 'RUNS'
    if (Test-Path -LiteralPath $ledgerDir) { Remove-Item -LiteralPath $ledgerDir -Recurse -Force }

    $summary = @(
        (New-RunSummaryRow -Job ([pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Name = 'A'; What = '' }) `
            -Rows 1 -Seconds 1 -Status 'OK' -Eligible 5 -Findings 0),
        (New-RunSummaryRow -Job ([pscustomobject]@{ CheckId = 'Otherball-DQ-001'; Name = 'B'; What = '' }) `
            -Rows 1 -Seconds 1 -Status 'OK' -Eligible 7 -Findings 0))

    $written = @(Save-RunLedger -Summary $summary -Output 'MIXED 04.01.2026 09-00-00')
    Assert-Equal 2 $written.Count 'a ledger keyed on anything but the sport cannot be read by that sport'
    Assert-True (Test-Path -LiteralPath (Join-Path $ledgerDir 'Fixtureball.json')) 'Fixtureball has its own file'
    Assert-True (Test-Path -LiteralPath (Join-Path $ledgerDir 'Otherball.json')) 'and so does Otherball'
}

Test-That 'a check with no earlier run is New rather than judged' {
    Assert-Equal 'New' (Get-CheckVerdict -Expected 'Zero' -Residual $null -Findings 40 `
            -Eligible 900 -Previous $null -Ran $true) 'the first run is the base'
}

Test-That 'a check that should reach zero and did is Resolved' {
    $before = [pscustomobject]@{ Findings = 40; Eligible = 900; RunId = 'a' }
    Assert-Equal 'Resolved' (Get-CheckVerdict -Expected 'Zero' -Residual $null -Findings 0 `
            -Eligible 900 -Previous $before -Ran $true) 'nothing left to correct'
}

Test-That 'a check that was clean and stayed clean is not called Resolved' {
    # Resolved claims work landed. Said every week about a check that has never had a finding,
    # it buries the rows that did change among the ones that never do. Seen on the first live
    # run, where a check with no findings in either run reported Resolved.
    $clean = [pscustomobject]@{ Findings = 0; Eligible = 7166; RunId = 'a' }
    Assert-Equal 'Clean' (Get-CheckVerdict -Expected 'Zero' -Residual $null -Findings 0 `
            -Eligible 7166 -Previous $clean -Ran $true) 'clean then, clean now'
    Assert-Equal 'Clean' (Get-CheckVerdict -Expected 'Zero' -Residual $null -Findings 0 `
            -Eligible 7166 -Previous $null -Ran $true) 'and a first run that found nothing resolved nothing either'
}

Test-That 'Resolved is read before the population is, because zero is absolute' {
    # Zero findings says something about the data, not about how many objects it came out
    # of, so a sport that grew by half still resolves rather than reporting Scope moved.
    $before = [pscustomobject]@{ Findings = 40; Eligible = 900; RunId = 'a' }
    Assert-Equal 'Resolved' (Get-CheckVerdict -Expected 'Zero' -Residual $null -Findings 0 `
            -Eligible 1400 -Previous $before -Ran $true) 'a moved scope does not unresolve a clean check'
}

Test-That 'a population-wide check returning nothing is Unexpectedly empty' {
    # The one case where zero is the alarming answer: a check whose findings are the whole
    # population cannot correct itself to nothing, so an empty result means it broke.
    $before = [pscustomobject]@{ Findings = 1064; Eligible = 12000; RunId = 'a' }
    Assert-Equal 'Unexpectedly empty' (Get-CheckVerdict -Expected 'Non-zero' -Residual $null `
            -Findings 0 -Eligible 12000 -Previous $before -Ran $true) 'zero is wrong here'
}

Test-That 'a check that audited nothing outranks every comparison' {
    $before = [pscustomobject]@{ Findings = 40; Eligible = 900; RunId = 'a' }
    Assert-Equal 'Audited nothing' (Get-CheckVerdict -Expected 'Zero' -Residual $null -Findings 0 `
            -Eligible 0 -Previous $before -Ran $true) 'eligible_count 0 is never clean data'
}

Test-That 'findings falling against a steady population is Improved, and rising is Regressed' {
    $before = [pscustomobject]@{ Findings = 40; Eligible = 900; RunId = 'a' }
    Assert-Equal 'Improved' (Get-CheckVerdict -Expected 'Zero' -Residual $null -Findings 3 `
            -Eligible 900 -Previous $before -Ran $true) 'fewer findings'
    Assert-Equal 'Unchanged' (Get-CheckVerdict -Expected 'Zero' -Residual $null -Findings 40 `
            -Eligible 900 -Previous $before -Ran $true) 'the same findings'
    Assert-Equal 'Regressed' (Get-CheckVerdict -Expected 'Zero' -Residual $null -Findings 51 `
            -Eligible 900 -Previous $before -Ran $true) 'more findings'
}

Test-That 'a population that moved makes the raw delta incomparable' {
    # 900 to 1200 is a third again as many objects. Three findings out of 1200 may be worse
    # data than forty out of 900, and calling that an improvement is the one wrong answer
    # this column can give.
    $before = [pscustomobject]@{ Findings = 40; Eligible = 900; RunId = 'a' }
    Assert-Equal 'Scope moved' (Get-CheckVerdict -Expected 'Zero' -Residual $null -Findings 3 `
            -Eligible 1200 -Previous $before -Ran $true) 'the two runs audited different scopes'

    # Drift below the threshold is the normal state - colleagues are correcting the data
    # while it is being read - so it must not fire on every run.
    Assert-Equal 'Improved' (Get-CheckVerdict -Expected 'Zero' -Residual $null -Findings 3 `
            -Eligible 920 -Previous $before -Ran $true) 'ordinary drift is not a moved scope'
}

Test-That 'an agreed remainder is judged against its own count' {
    $before = [pscustomobject]@{ Findings = 40; Eligible = 900; RunId = 'a' }
    Assert-Equal 'As expected' (Get-CheckVerdict -Expected 'Residual' -Residual 12 -Findings 12 `
            -Eligible 900 -Previous $before -Ran $true) 'exactly the agreed remainder'
    Assert-Equal 'As expected' (Get-CheckVerdict -Expected 'Residual' -Residual 12 -Findings 5 `
            -Eligible 900 -Previous $before -Ran $true) 'below it'
    Assert-Equal 'Above residual' (Get-CheckVerdict -Expected 'Residual' -Residual 12 -Findings 13 `
            -Eligible 900 -Previous $before -Ran $true) 'one row more than was agreed'
}

Test-That 'a population-wide check is compared by proportion, not by count' {
    # 1064 of 12000 and 1170 of 13200 are the same picture; the raw count rose by a hundred.
    $before = [pscustomobject]@{ Findings = 1064; Eligible = 12000; RunId = 'a' }
    Assert-Equal 'As expected' (Get-CheckVerdict -Expected 'Non-zero' -Residual $null `
            -Findings 1170 -Eligible 13200 -Previous $before -Ran $true) 'the same proportion'
    Assert-Equal 'Regressed' (Get-CheckVerdict -Expected 'Non-zero' -Residual $null `
            -Findings 2400 -Eligible 12000 -Previous $before -Ran $true) 'the proportion doubled'
}

Test-That 'a failed or unreadable statement gets no verdict at all' {
    $before = [pscustomobject]@{ Findings = 40; Eligible = 900; RunId = 'a' }
    Assert-Equal '' (Get-CheckVerdict -Expected 'Zero' -Residual $null -Findings $null `
            -Eligible $null -Previous $before -Ran $false) 'a failed statement produced nothing to judge'
    Assert-Equal '' (Get-CheckVerdict -Expected 'Zero' -Residual $null -Findings $null `
            -Eligible $null -Previous $before -Ran $true) 'nor did one with no COVERAGE row'
}

Test-That 'the previous run is read from the ledger, skipping the runs that failed' {
    # Comparing against an error says nothing. The reading a reviewer wants is against the
    # last run that actually produced a number, which may be two runs back.
    $ledgerDir = Join-Path $fixtureRoot 'RUNS'
    if (Test-Path -LiteralPath $ledgerDir) { Remove-Item -LiteralPath $ledgerDir -Recurse -Force }

    $job = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Name = 'A'; What = '' }
    Save-RunLedger -Summary @(New-RunSummaryRow -Job $job -Rows 41 -Seconds 1 -Status 'OK' `
            -Eligible 900 -Findings 40) -Output 'run-one' | Out-Null
    Save-RunLedger -Summary @(New-RunSummaryRow -Job $job -Rows 0 -Seconds 1 `
            -Status 'ERROR: fixture') -Output 'run-two' | Out-Null

    $previous = Import-PreviousRunEntries -Jobs @($job)
    Assert-Equal 40 $previous['Fixtureball-DQ-002'].Findings 'the last run that produced a number'
    Assert-Equal 'run-one' $previous['Fixtureball-DQ-002'].RunId 'and the run it came from'
}

Test-That 'the summary carries the verdict and what it was read against' {
    $ledgerDir = Join-Path $fixtureRoot 'RUNS'
    if (Test-Path -LiteralPath $ledgerDir) { Remove-Item -LiteralPath $ledgerDir -Recurse -Force }

    $job = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Name = 'A'; What = ''; Expected = 'Zero' }
    Save-RunLedger -Summary @(New-RunSummaryRow -Job $job -Rows 41 -Seconds 1 -Status 'OK' `
            -Eligible 900 -Findings 40) -Output 'run-one' | Out-Null

    $script:PreviousRun = Import-PreviousRunEntries -Jobs @($job)
    $row = New-RunSummaryRow -Job $job -Rows 4 -Seconds 1 -Status 'OK' -Eligible 900 -Findings 3
    $script:PreviousRun = @{}

    Assert-Equal 'Improved' $row.Verdict 'the verdict'
    Assert-Equal -37 $row.Change 'the signed change'
    Assert-Equal 40 $row.PrevFindings 'what it was read against'
    Assert-Equal 'run-one' $row.PrevRunId 'and which run that was'
}

Test-That 'a recorded run can say when it started, and falls back to its folder name' {
    $utc = Get-RunStamp -Run ([pscustomobject]@{
            startedUtc = '2026-08-01T06:30:00Z'; runId = 'Fixtureball 09.09.2026 23-00-00' })
    Assert-Equal '2026-08-01' $utc.ToString('yyyy-MM-dd') 'startedUtc wins over the folder name'

    # dd.MM.yyyy, read under the invariant culture. A machine set to en-US would otherwise
    # take this for the third of July.
    $folder = Get-RunStamp -Run ([pscustomobject]@{ runId = 'Fixtureball 07.03.2026 18-45-00' })
    Assert-Equal '2026-03-07 18:45' $folder.ToString('yyyy-MM-dd HH:mm') 'the folder name when there is nothing else'
    Assert-Equal $null (Get-RunStamp -Run ([pscustomobject]@{ runId = 'nothing datable' })) 'and neither'
}

Test-That 'the Trends column dates to the day, and to the minute when a day repeats' {
    # Decided once for the whole column rather than per row: two rows formatted differently
    # read as two different measures.
    $day = { param($s) [pscustomobject]@{ Stamp = [datetime]$s; Value = '0' } }
    $spread = @{ a = @((& $day '2026-08-01 09:00'), (& $day '2026-08-08 09:00')) }
    Assert-Equal 'dd.MM' (Get-TrendStampFormat -Recent $spread `
            -Current ([datetime]'2026-08-15 09:00')) 'a weekly cadence needs no clock'

    $twice = @{ a = @((& $day '2026-08-01 09:00'), (& $day '2026-08-01 17:00')) }
    Assert-Equal 'dd.MM HH:mm' (Get-TrendStampFormat -Recent $twice `
            -Current ([datetime]'2026-08-15 09:00')) 'two runs on one day would print one label twice'

    # This run is a point of the series too, so it settles the format like any other.
    Assert-Equal 'dd.MM HH:mm' (Get-TrendStampFormat -Recent $spread `
            -Current ([datetime]'2026-08-08 17:00')) 'including when the repeat is today'

    # A point the ledger cannot date must not decide the format for the ones it can.
    $undated = @{ a = @([pscustomobject]@{ Stamp = $null; Value = '0' }, (& $day '2026-08-01 09:00')) }
    Assert-Equal 'dd.MM' (Get-TrendStampFormat -Recent $undated `
            -Current ([datetime]'2026-08-08 09:00')) 'an undatable point abstains'
}

Test-That 'a trend point leads with the count and degrades to it when undated' {
    $script:TrendStampFormat = 'dd.MM'
    Assert-Equal '12 (01.08)' (Format-TrendPoint -Value '12' -Stamp ([datetime]'2026-08-01 09:00')) 'count first'
    Assert-Equal 'ERR' (Format-TrendPoint -Value 'ERR' -Stamp $null) 'no empty bracket'
}

Test-That 'the trend carries a date against every count, this run included' {
    $ledgerDir = Join-Path $fixtureRoot 'RUNS'
    if (Test-Path -LiteralPath $ledgerDir) { Remove-Item -LiteralPath $ledgerDir -Recurse -Force }

    $job = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Name = 'A'; What = ''; Expected = 'Zero' }
    $started = $script:RunStartedUtc
    try {
        foreach ($pair in @(@('2026-08-01T07:00:00Z', 40), @('2026-08-08T07:00:00Z', 12))) {
            $script:RunStartedUtc = [datetime]::Parse($pair[0], [Globalization.CultureInfo]::InvariantCulture,
                [Globalization.DateTimeStyles]::AdjustToUniversal -bor [Globalization.DateTimeStyles]::AssumeUniversal)
            Save-RunLedger -Output ("run-{0}" -f $pair[1]) -Summary @(New-RunSummaryRow -Job $job `
                    -Rows ($pair[1] + 1) -Seconds 1 -Status 'OK' -Findings $pair[1] -Eligible 900) | Out-Null
        }

        $script:RunStartedUtc = [datetime]::Parse('2026-08-15T07:00:00Z', [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::AdjustToUniversal -bor [Globalization.DateTimeStyles]::AssumeUniversal)
        $script:RecentFindings = Import-RecentFindings -Jobs @($job)
        $script:TrendStampFormat = Get-TrendStampFormat -Recent $script:RecentFindings `
            -Current $script:RunStartedUtc.ToLocalTime()
        $row = New-RunSummaryRow -Job $job -Rows 1 -Seconds 1 -Status 'OK' -Eligible 900 -Findings 0
    }
    finally {
        $script:RunStartedUtc = $started
        $script:RecentFindings = @{}
        $script:TrendStampFormat = 'dd.MM'
    }

    # Local time, so the labels follow the clock the reader is looking at rather than UTC.
    $stamps = @(@('2026-08-01T07:00:00Z', '2026-08-08T07:00:00Z', '2026-08-15T07:00:00Z') | ForEach-Object {
            ([datetime]::Parse($_, [Globalization.CultureInfo]::InvariantCulture,
                [Globalization.DateTimeStyles]::AdjustToUniversal -bor
                [Globalization.DateTimeStyles]::AssumeUniversal)).ToLocalTime().ToString('dd.MM')
        })
    $arrow = ' ' + [string][char]0x2192 + ' '
    $expected = ('40 ({0})' -f $stamps[0]), ('12 ({0})' -f $stamps[1]), ('0 ({0})' -f $stamps[2]) -join $arrow
    Assert-Equal $expected $row.Trend 'three dated points, this run last'
}

Test-That 'an ad-hoc statement files itself under no sport at all' {
    # A basename with no -DQ- in it falls through Get-SportFromCheckId to everything before
    # the first hyphen, so -File comprank.sql once created RUNS/comprank.json inside the
    # working copy - a tracked file named after a scratch query. Both ad-hoc forms carry an
    # empty CheckId now, and AD-HOC is what Save-RunLedger refuses to file.
    Assert-Equal 'AD-HOC' (Get-SportFromCheckId -CheckId '') 'nothing to read a sport out of'
    Assert-Equal 'AD-HOC' (Get-SportFromCheckId -CheckId $null) 'nor out of nothing at all'

    $ledgerDir = Join-Path $fixtureRoot 'RUNS'
    if (Test-Path -LiteralPath $ledgerDir) { Remove-Item -LiteralPath $ledgerDir -Recurse -Force }

    $adhoc = [pscustomobject]@{ CheckId = ''; Name = 'comprank'; What = '' }
    $written = @(Save-RunLedger -Summary @(New-RunSummaryRow -Job $adhoc -Rows 3 -Seconds 1 `
                -Status 'OK' -Eligible 9 -Findings 2) -Output 'run-one')
    Assert-Equal 0 $written.Count 'no ledger is written for it'
    Assert-True (-not (Test-Path -LiteralPath $ledgerDir)) 'and no RUNS directory is created'
}

Test-That 'a test run records nothing and names its folder so' {
    # The two halves have to hold together: recording nothing is worthless if the folder is
    # indistinguishable from a real run's, and marking the folder is worthless if the entry
    # went in anyway and moved the baseline.
    $ledgerDir = Join-Path $fixtureRoot 'RUNS'
    if (Test-Path -LiteralPath $ledgerDir) { Remove-Item -LiteralPath $ledgerDir -Recurse -Force }

    $job = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Name = 'A'; What = '' }
    $summary = @(New-RunSummaryRow -Job $job -Rows 1 -Seconds 1 -Status 'OK' -Eligible 5 -Findings 0)

    $TestRun = $true
    try {
        $written = @(Save-RunLedger -Summary $summary -Output 'TEST Fixtureball 01.01.2026 09-00-00')
        $folder = Get-RunFolder -Jobs @($job)
    }
    finally { $TestRun = $false }

    Assert-Equal 0 $written.Count 'a test run appends nothing'
    Assert-True (-not (Test-Path -LiteralPath $ledgerDir)) 'and creates no ledger at all'
    Assert-True ((Split-Path -Leaf $folder) -like 'TEST Fixtureball *') 'the folder says which runs can be deleted'

    $real = Get-RunFolder -Jobs @($job)
    Assert-True ((Split-Path -Leaf $real) -notlike 'TEST *') 'a real run keeps its plain name'
}

Test-That 'the history of a check is every recorded run of it, oldest first' {
    # The document compares this run with the one before it and nothing else. This is where
    # the first run and the tenth sit side by side.
    $ledgerDir = Join-Path $fixtureRoot 'RUNS'
    if (Test-Path -LiteralPath $ledgerDir) { Remove-Item -LiteralPath $ledgerDir -Recurse -Force }

    $job = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Name = 'TRACKED'; What = ''; Expected = 'Zero' }
    foreach ($pair in @(@(40, 900), @(12, 900), @(0, 910))) {
        $script:PreviousRun = Import-PreviousRunEntries -Jobs @($job)
        Save-RunLedger -Output ("run-{0}" -f $pair[0]) -Summary @(New-RunSummaryRow -Job $job `
                -Rows ($pair[0] + 1) -Seconds 1 -Status 'OK' -Findings $pair[0] -Eligible $pair[1]) | Out-Null
    }
    $script:PreviousRun = @{}

    $rows = @(Get-CheckHistory -Pattern 'Fixtureball-DQ-002' -Sport 'Fixtureball')
    Assert-Equal 3 $rows.Count 'every run appears'
    Assert-Equal 40 $rows[0].Findings 'oldest first'
    Assert-Equal 0 $rows[2].Findings 'and newest last'
    Assert-Equal 'Improved' $rows[1].Verdict 'each carrying the verdict that run recorded'
    Assert-Equal 'Resolved' $rows[2].Verdict 'including the one that closed it'

    # The proportion, because a raw count is only comparable while the population is.
    Assert-Equal '4,44%' $rows[0].Rate 'the rate is computed from the run own numbers'
}

Test-That 'a history of a check nobody has run says so rather than lying with an empty table' {
    $ledgerDir = Join-Path $fixtureRoot 'RUNS'
    if (Test-Path -LiteralPath $ledgerDir) { Remove-Item -LiteralPath $ledgerDir -Recurse -Force }
    Assert-Equal 0 @(Get-CheckHistory -Pattern 'Fixtureball-DQ-002' -Sport 'Fixtureball').Count 'nothing recorded'
}

Test-That 'a history pattern reaches more than one check' {
    $ledgerDir = Join-Path $fixtureRoot 'RUNS'
    if (Test-Path -LiteralPath $ledgerDir) { Remove-Item -LiteralPath $ledgerDir -Recurse -Force }

    $first = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Name = 'A'; What = '' }
    $second = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-004'; Name = 'B'; What = '' }
    Save-RunLedger -Output 'one' -Summary @(
        (New-RunSummaryRow -Job $first -Rows 2 -Seconds 1 -Status 'OK' -Findings 1 -Eligible 10),
        (New-RunSummaryRow -Job $second -Rows 3 -Seconds 1 -Status 'OK' -Findings 2 -Eligible 20)) | Out-Null

    $all = @(Get-CheckHistory -Pattern 'Fixtureball-DQ-*' -Sport 'Fixtureball')
    Assert-Equal 2 $all.Count 'both checks are returned'
    Assert-Equal 1 @(Get-CheckHistory -Pattern 'Fixtureball-DQ-004' -Sport 'Fixtureball').Count 'and one can be asked for alone'
}

Test-That 'an unreadable ledger is reported rather than overwritten' {
    # The history is the whole reason the file exists, so a run that cannot read it must not
    # replace it with one entry of its own.
    $ledgerDir = Join-Path $fixtureRoot 'RUNS'
    if (Test-Path -LiteralPath $ledgerDir) { Remove-Item -LiteralPath $ledgerDir -Recurse -Force }
    New-Item -ItemType Directory -Path $ledgerDir -Force | Out-Null

    $path = Join-Path $ledgerDir 'Fixtureball.json'
    [IO.File]::WriteAllText($path, '{ not json at all', (New-Object Text.UTF8Encoding $false))

    $summary = @(New-RunSummaryRow -Job ([pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Name = 'A'; What = '' }) `
            -Rows 1 -Seconds 1 -Status 'OK' -Eligible 5 -Findings 0)
    $written = @(Save-RunLedger -Summary $summary -Output 'Fixtureball 05.01.2026 09-00-00')

    Assert-Equal 0 $written.Count 'nothing is written over a history that could not be read'
    Assert-Equal '{ not json at all' (Get-Content -LiteralPath $path -Raw) 'and the file is left exactly as it was'
}

Complete-Group

# --------------------------------------------------------------------------------------
# The live per-sport document
#
# Sheets.ps1 sends nothing, so all of this runs without a login. That is the point of the
# split: the merge is where a permanent document can lose somebody's work, and a merge that
# needs credentials to exercise is a merge nobody exercises.
# --------------------------------------------------------------------------------------

Start-Group 'Runner' 'Live sheet merge'

function New-SheetFixtureEntry {
    param([string]$CheckId, [int]$Findings, [int]$Eligible, [string]$Verdict, [string]$Status = 'Not reviewed')

    return [pscustomobject]@{
        Sport = 'Fixtureball'; CheckId = $CheckId; RunKey = $CheckId; Parameters = ''
        Name = "NAME_$CheckId"; Priority = '3 Missing value'; Category = 'MISSING_VALUES'
        What = 'a thing'; RowsCell = $Findings + 1; Signal = 'Actionable'; SignalReason = ''
        Expected = 'Zero'; Findings = $Findings; Eligible = $Eligible
        PrevFindings = $null; PrevEligible = $null; Change = $null
        Verdict = $Verdict; PrevRunId = ''; SeededStatus = $Status
    }
}

Test-That 'a column index becomes its spreadsheet letter' {
    Assert-Equal 'A' (ConvertTo-SheetsColumnName -Index 1) 'first'
    Assert-Equal 'Z' (ConvertTo-SheetsColumnName -Index 26) 'last single letter'
    Assert-Equal 'AA' (ConvertTo-SheetsColumnName -Index 27) 'first double letter'
    Assert-Equal 'U' (ConvertTo-SheetsColumnName -Index 21) 'the last Overview column'
}

Test-That 'the reviewer columns split the row into the spans a run may write' {
    # Two ranges per row instead of eighteen. The API charges per range and a sport is fifty
    # rows of twenty-one columns.
    $spans = @(Split-SheetsWritableSpans -Width 22 -Reserved @(9, 10, 11))
    Assert-Equal 2 $spans.Count 'two writable spans'
    Assert-Equal 1 $spans[0].From 'first span starts at A'
    Assert-Equal 8 $spans[0].To 'and stops before Status'
    Assert-Equal 12 $spans[1].From 'second span resumes after Comment'
    Assert-Equal 22 $spans[1].To 'and runs to the last column'
}

Test-That 'a check the document already holds is updated in the row it occupies' {
    # Not at the position CheckID order would put it in. The reviewer may have sorted or
    # moved the board, and a comment describes the row it sits on.
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 3 -Eligible 900 -Verdict 'Improved'))
    $existing = [pscustomobject]@{
        HasOverviewHeader = $true
        OverviewRowOf = @{ 'Fixtureball-DQ-002' = 7 }
        TabOf = @{}
        ResultRowsOf = @{}
    }
    $plan = New-SheetsMergePlan -Summary $summary -Collected @() -Existing $existing -OutputFolder 'x'
    # Row 1 excluded: the header is rewritten every run and is not this check's row.
    $writes = @($plan.Operations | Where-Object {
            $_.Sheet -eq 'Overview' -and $_.Kind -eq 'Write' -and $_.Range -notlike '*1:*1' })

    Assert-Equal 2 $writes.Count 'two spans, written around the reviewer columns'
    Assert-Equal 'A7:H7' $writes[0].Range 'the first span, on the row the check already has'
    Assert-Equal 'L7:V7' $writes[1].Range 'the second span, resuming after Comment'
    foreach ($write in $writes) {
        Assert-True ($write.Range -notmatch '^[IJK]') "a run must never write $($write.Range)"
    }
}

Test-That 'a check the document has never held is appended, seeded status and all' {
    # The one time the reviewer columns are written: there is nothing of theirs to overwrite,
    # and the seeded Status is what says the row needs no reading.
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-009' -Findings 0 -Eligible 40 `
                -Verdict 'Resolved' -Status 'No issue'))
    $existing = [pscustomobject]@{
        HasOverviewHeader = $true
        OverviewRowOf = @{ 'Fixtureball-DQ-002' = 7 }
        TabOf = @{}
        ResultRowsOf = @{}
    }
    $plan = New-SheetsMergePlan -Summary $summary -Collected @() -Existing $existing -OutputFolder 'x'
    # DQ-002 is in the document and not in this run, so it gets a Verdict cell of its own.
    # The append is the whole-row write, and it is the one under test here.
    $appended = @($plan.Operations | Where-Object { $_.Sheet -eq 'Overview' -and $_.Range -like 'A*:V*' -and $_.Range -ne 'A1:V1' })

    Assert-Equal 1 $appended.Count 'one whole-row write'
    Assert-Equal 'A8:V8' $appended[0].Range 'appended below the last row in use, not sorted into place'
    Assert-Equal 'No issue' $appended[0].Values[0][8] 'the seeded status goes in on a new row'
}

Test-That 'a withdrawn check is retired by any run, not only by a complete one' {
    # Deprecation is a row in the registry rather than an inference from what the run
    # produced, so unlike "Not in this run" it does not wait for -Complete. The run below
    # names one check and the board holds two.
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 3 -Eligible 900 -Verdict 'Improved'))
    $existing = [pscustomobject]@{
        HasOverviewHeader = $true
        OverviewRowOf = @{ 'Fixtureball-DQ-002' = 7; 'Fixtureball-DQ-044' = 8 }
        TabOf = @{ 'Fixtureball-DQ-044' = 'OLD_MEDAL_CHECK' }
        ResultRowsOf = @{}
    }
    $plan = New-SheetsMergePlan -Summary $summary -Collected @() -Existing $existing `
        -OutputFolder 'x' -Retired @('Fixtureball-DQ-044')

    $span = @($plan.Operations | Where-Object { $_.Sheet -eq 'Overview' -and $_.Range -eq 'L8:V8' })
    Assert-Equal 1 $span.Count 'the run-owned columns are written in one span'
    Assert-Equal 'Deprecated' $span[0].Values[0][0] 'Signal says so'
    Assert-Equal 'Deprecated' $span[0].Values[0][8] 'and so does Verdict'
    Assert-Equal '' $span[0].Values[0][3] 'Findings is cleared rather than left reading as current'

    # Status is I, and this is the one thing a run puts there: a row reading Deprecated in
    # Signal and Verdict while Status still said Not reviewed was asking to be reviewed and
    # answering that there was nothing to review, and a filter on Not reviewed kept serving it.
    $status = @($plan.Operations | Where-Object { $_.Sheet -eq 'Overview' -and $_.Range -eq 'I8:I8' })
    Assert-Equal 1 $status.Count 'the withdrawal reaches the reviewer-facing Status too'
    Assert-Equal 'Deprecated' $status[0].Values[0][0] 'in the registry''s own word'
    Assert-True ($SheetsStatusBands.Value -contains 'Deprecated') 'which the closed list has to offer'

    # J and K stay the reviewer's: Check By and Comment are what somebody concluded, and a
    # withdrawn check keeps its history for the same reason its CheckID is never reused.
    $onRow8 = @($plan.Operations | Where-Object { $_.Sheet -eq 'Overview' -and $_.Kind -eq 'Write' -and $_.Range -like '*8:*8' })
    foreach ($write in $onRow8) {
        Assert-True ($write.Range -notmatch '^[JK]') "a run must never write $($write.Range)"
    }

    # The Rows cell: a plain zero that always lands, then the link on top. A formula sent RAW
    # arrives as text, and the USER_ENTERED side drops a write whose tab token did not resolve -
    # so a single write carrying only the link would leave the stale count standing.
    $rowsCells = @($plan.Operations | Where-Object { $_.Sheet -eq 'Overview' -and $_.Range -eq 'H8:H8' })
    Assert-Equal 2 $rowsCells.Count 'the number and the link are two writes'
    Assert-Equal 0 $rowsCells[0].Values[0][0] 'the plain zero goes first'
    Assert-True ($rowsCells[0].PSObject.Properties.Name -notcontains 'Raw') 'and goes in RAW, so it always lands'
    Assert-Equal $false $rowsCells[1].Raw 'the link needs USER_ENTERED or it arrives as text'
    Assert-True ([string]$rowsCells[1].Values[0][0] -like '=HYPERLINK(*') 'and it is a link'

    # The tab keeps its identity and its comments, loses its findings, and says why.
    $cleared = @($plan.Operations | Where-Object { $_.Sheet -eq 'OLD_MEDAL_CHECK' -and $_.Kind -eq 'Clear' })
    Assert-Equal 1 $cleared.Count 'the findings are cleared from the tab'
    Assert-True ($cleared[0].Range -like ('A' + $SheetsCheckTabResultRow + ':*')) 'from the result row down, so rows 1 to 4 survive'
    $note = @($plan.Operations | Where-Object { $_.Sheet -eq 'OLD_MEDAL_CHECK' -and $_.Range -eq 'C3' })
    Assert-Equal 1 $note.Count 'and the reason is written where a tab says things about itself'
    Assert-True ([string]$note[0].Values[0][0] -like '*POWERBI_REGISTRY.md*') 'naming where the withdrawal is recorded'

    # A retired row must not also be told it was not in this run: two markers, one of them
    # overwriting the other, and which one wins would depend on plan order.
    $verdictOnly = @($plan.Operations | Where-Object { $_.Sheet -eq 'Overview' -and $_.Range -eq 'T8:T8' })
    Assert-Equal 0 $verdictOnly.Count 'no Not-in-this-run cell on a row already marked withdrawn'
}

Test-That 'a withdrawn check that ran anyway keeps the numbers it just produced' {
    # The registry and the selection disagreeing is a state worth surviving: this run measured
    # the check, and replacing a measurement with an assertion would be the worse answer.
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-044' -Findings 5 -Eligible 60 -Verdict 'Improved'))
    $existing = [pscustomobject]@{
        HasOverviewHeader = $true
        OverviewRowOf = @{ 'Fixtureball-DQ-044' = 8 }
        TabOf = @{}
        ResultRowsOf = @{}
    }
    $plan = New-SheetsMergePlan -Summary $summary -Collected @() -Existing $existing `
        -OutputFolder 'x' -Retired @('Fixtureball-DQ-044')

    $span = @($plan.Operations | Where-Object { $_.Sheet -eq 'Overview' -and $_.Range -eq 'L8:V8' })
    Assert-Equal 1 $span.Count 'one write, the run own'
    Assert-Equal 5 $span[0].Values[0][3] 'holding what the run measured rather than a cleared cell'
}

Test-That 'the Overview header is rewritten every run, so a new column gets a name' {
    # It used to be written once, which held exactly as long as the board never gained a
    # column. Trends was added, the header of a document created before it stayed twenty-one
    # cells wide, and Sheets filled the twenty-second with a placeholder of its own.
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 1 -Eligible 9 -Verdict 'New'))

    $fresh = New-SheetsMergePlan -Summary $summary -Collected @() -Existing $null -OutputFolder 'x'
    $header = @($fresh.Operations | Where-Object { $_.Range -eq 'A1:V1' })
    Assert-Equal 1 $header.Count 'an empty document gets its header'
    Assert-Equal 'Trends' $header[0].Values[0][21] 'out to the last column the board writes'

    $existing = [pscustomobject]@{
        HasOverviewSheet = $true; HasOverviewHeader = $true; OverviewRowOf = @{}; TabOf = @{}
    }
    $again = New-SheetsMergePlan -Summary $summary -Collected @() -Existing $existing -OutputFolder 'x'
    Assert-Equal 1 @($again.Operations | Where-Object { $_.Range -eq 'A1:V1' }).Count `
        'and a document that already has one gets it again, in case the board has grown'
}

Test-That 'a document without an Overview tab has one added before anything names it' {
    # A new spreadsheet has a single Sheet1. Google rejects an entire batch with "Unable to
    # parse range" if one range names a tab that does not exist, so the very first run would
    # fail on its own header write. Observed live against an empty document.
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 1 -Eligible 9 -Verdict 'New'))
    $plan = New-SheetsMergePlan -Summary $summary -Collected @() -Existing $null -OutputFolder 'x'

    $ops = @($plan.Operations)
    $add = @($ops | Where-Object { $_.Kind -eq 'AddSheet' -and $_.Sheet -eq 'Overview' })
    Assert-Equal 1 $add.Count 'Overview is added'
    $addAt = [array]::IndexOf($ops, $add[0])
    $writeAt = [array]::IndexOf($ops, @($ops | Where-Object { $_.Sheet -eq 'Overview' -and $_.Kind -eq 'Write' })[0])
    Assert-True ($addAt -lt $writeAt) 'before the first thing written into it'

    $existing = [pscustomobject]@{
        HasOverviewSheet = $true; HasOverviewHeader = $true; OverviewRowOf = @{}; TabOf = @{}
    }
    $again = New-SheetsMergePlan -Summary $summary -Collected @() -Existing $existing -OutputFolder 'x'
    Assert-Equal 0 @($again.Operations | Where-Object { $_.Kind -eq 'AddSheet' -and $_.Sheet -eq 'Overview' }).Count `
        'and not added a second time'
}

Test-That 'a check that stopped running keeps its tab and is marked instead' {
    # Deleting the row would take its comments with it, and those are the one thing in the
    # document nobody can regenerate. Leaving it untouched would show last run's number as
    # though it were this run's.
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 3 -Eligible 900 -Verdict 'Improved'))
    $existing = [pscustomobject]@{
        HasOverviewHeader = $true
        OverviewRowOf = @{ 'Fixtureball-DQ-002' = 2; 'Fixtureball-DQ-003' = 3 }
        TabOf = @{}
        ResultRowsOf = @{}
    }
    $plan = New-SheetsMergePlan -Summary $summary -Collected @() -Existing $existing -OutputFolder 'x' -Complete

    Assert-Equal 0 @($plan.Operations | Where-Object { $_.Kind -eq 'DeleteSheet' }).Count 'nothing is deleted'
    $marked = @($plan.Operations | Where-Object { $_.Range -eq 'T3:T3' })
    Assert-Equal 1 $marked.Count 'the absent check gets its Verdict cell written'
    Assert-Equal 'Not in this run' $marked[0].Values[0][0] 'saying it did not run rather than nothing'
}

Test-That 'a partial run does not repaint the checks it was never asked for' {
    # Re-running one check after a reported fix would otherwise mark the other ninety Not in
    # this run, and the board would flip-flop on every such run. A partial run did not fail
    # to produce them; it was never asked.
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 3 -Eligible 900 -Verdict 'Improved'))
    $existing = [pscustomobject]@{
        HasOverviewSheet = $true; HasOverviewHeader = $true
        OverviewRowOf = @{ 'Fixtureball-DQ-002' = 2; 'Fixtureball-DQ-003' = 3 }
        EmptyCommentOf = @{}; TabOf = @{}; Titles = @('Overview')
    }
    $plan = New-SheetsMergePlan -Summary $summary -Collected @() -Existing $existing -OutputFolder 'x'

    Assert-Equal 0 @($plan.Operations | Where-Object { $_.Range -eq 'T3:T3' }).Count `
        'the row this run was not asked about keeps the last full run numbers'
    Assert-True (@($plan.Operations | Where-Object { $_.Range -like '*2:*2' }).Count -gt 0) `
        'while the check that did run is still updated'
}

Test-That 'a check tab is cleared to its end, not to a depth this code believes it has' {
    # Forty rows last run and three this one would otherwise leave thirty-seven stale rows
    # under the three new ones, which reads as forty findings. Clearing to a remembered depth
    # is only right while the memory is: a -TestRun that wrote the sheet without recording, a
    # hand edit, a write that failed halfway. The end of the tab is a fact.
    $job = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Name = 'SHRANK'; What = ''; Sql = 'SELECT 1;' }
    $rows = @(1..3 | ForEach-Object { [pscustomobject]@{ check_type = 'X'; id = $_ } })
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 3 -Eligible 900 -Verdict 'Improved'))
    $existing = [pscustomobject]@{
        HasOverviewHeader = $true
        OverviewRowOf = @{ 'Fixtureball-DQ-002' = 2 }
        TabOf = @{ 'Fixtureball-DQ-002' = 'SHRANK' }
    }
    $plan = New-SheetsMergePlan -Summary $summary -Collected @([pscustomobject]@{ Job = $job; Rows = $rows }) `
        -Existing $existing -OutputFolder 'x'

    $clear = @($plan.Operations | Where-Object { $_.Kind -eq 'Clear' -and $_.Sheet -eq 'SHRANK' })
    Assert-Equal 1 $clear.Count 'one clear for the tab'
    # Through AZ, not Z. The reviewer columns sit to the right of whatever the statement
    # returned, and a clear stopping short of them would leave last week's notes standing
    # beside this week's rows - the one failure the whole carry-forward exists to prevent.
    Assert-Equal 'A5:AZ' $clear[0].Range 'open ended, so nothing stale can survive below the new rows'

    $ops = @($plan.Operations)
    $clearAt = [array]::IndexOf($ops, $clear[0])
    $writeAt = [array]::IndexOf($ops, @($ops | Where-Object {
                $_.Kind -eq 'Write' -and $_.Sheet -eq 'SHRANK' -and $_.Range -like 'A5:*' })[0])
    Assert-True ($clearAt -lt $writeAt) 'and cleared before the new rows land on top'
}

Test-That 'a check the run produced gets its tab rewritten and its Rows cell linked to it' {
    # Both come from the same walk of $Collected, which is what made one defect look like
    # two. A batch run in any format but xlsx collected nothing, so Overview took the new
    # numbers while the tab under it kept the last run's findings and Rows stayed a plain
    # number - fresh figures standing over stale rows, with no way in to see it.
    $job = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Name = 'LINKED'; What = ''; Sql = 'SELECT 1;' }
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 3 -Eligible 90 -Verdict 'Improved'))
    $existing = [pscustomobject]@{
        HasOverviewSheet  = $true
        HasOverviewHeader = $true
        Titles            = @('Overview', 'LINKED')
        OverviewRowOf     = @{ 'Fixtureball-DQ-002' = 4 }
        TabOf             = @{ 'Fixtureball-DQ-002' = 'LINKED' }
        SheetIdOf         = @{ 'Overview' = 0; 'LINKED' = 77 }
    }
    $rows = @(1..3 | ForEach-Object { [pscustomobject]@{ check_type = 'X'; id = $_ } })
    $plan = New-SheetsMergePlan -Summary $summary `
        -Collected @([pscustomobject]@{ Job = $job; Rows = $rows }) `
        -Existing $existing -OutputFolder 'x'

    Assert-Equal 1 @($plan.Operations | Where-Object {
            $_.Kind -eq 'Clear' -and $_.Sheet -eq 'LINKED' }).Count 'the tab is cleared before it is rewritten'
    Assert-True (@($plan.Operations | Where-Object {
                $_.Kind -eq 'Write' -and $_.Sheet -eq 'LINKED' -and $_.Range -like 'A5:*' }).Count -gt 0) `
        'and the findings are written to it'

    # H is the Rows column, and its own single-cell write is the link. The A:H span wrote a
    # plain number first, which is what a check with no tab keeps.
    $rowsWrite = @($plan.Operations | Where-Object {
            $_.Kind -eq 'Write' -and $_.Sheet -eq 'Overview' -and $_.Range -eq 'H4:H4' })
    Assert-Equal 1 $rowsWrite.Count 'Rows is written as a cell of its own'
    Assert-True ([string]$rowsWrite[0].Values[0][0] -like '=HYPERLINK("#gid=*') 'and it holds a link, not a bare number'

    # The token names the tab; Invoke-SheetsPlan resolves it against every id the document
    # has. A name the document does not carry would leave it unresolved, and an unresolved
    # write is dropped rather than sent.
    Assert-True ([string]$rowsWrite[0].Values[0][0] -like '*{{GID:LINKED}}*') 'naming the tab it belongs to'
    Assert-True ($plan.KnownSheetIds.ContainsKey('LINKED')) 'which the plan can resolve to an id'
}

Test-That 'a write too large for one request is split at its own first row' {
    $rows = @(1..7 | ForEach-Object { , @("r$_", $_) })
    $operation = [pscustomobject]@{ Kind = 'Write'; Sheet = 'BIG'; Range = 'A5:B11'; Values = $rows }
    $chunks = @(Split-SheetsWriteChunks -Operation $operation -ChunkSize 3)

    Assert-Equal 3 $chunks.Count 'seven rows in threes'
    Assert-Equal 'A5:B7' $chunks[0].Range 'the first chunk starts where the block does'
    Assert-Equal 'A8:B10' $chunks[1].Range 'the second continues without a gap'
    Assert-Equal 'A11:B11' $chunks[2].Range 'and the last is the remainder, not a full chunk'
    Assert-Equal 7 (@($chunks | ForEach-Object { @($_.Values).Count }) | Measure-Object -Sum).Sum 'no row is lost or repeated'
}

Test-That 'a write that fits is not split' {
    $operation = [pscustomobject]@{ Kind = 'Write'; Sheet = 'S'; Range = 'A5:B6'; Values = @(, @('a', 1)) }
    Assert-Equal 1 @(Split-SheetsWriteChunks -Operation $operation -ChunkSize 2000).Count 'one operation in, one out'
}

Test-That 'a null cell is sent as empty rather than as JSON null' {
    # The API rejects a null inside a value range, and every run has them: a check with no
    # previous run has no Prev findings, no Change and no Last run.
    Assert-Equal '' (ConvertTo-SheetsCellValue -Value $null) 'null becomes empty'
    Assert-Equal 12 (ConvertTo-SheetsCellValue -Value 12) 'a number stays a number'
    Assert-Equal 'Resolved' (ConvertTo-SheetsCellValue -Value 'Resolved') 'a string stays a string'
}

Test-That 'a check tab never writes the two cells the reviewer owns' {
    $job = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Name = 'OWNED'; What = 'a thing'; Sql = 'SELECT 1;' }
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 1 -Eligible 9 -Verdict 'New'))
    $existing = [pscustomobject]@{
        HasOverviewHeader = $true
        OverviewRowOf = @{ 'Fixtureball-DQ-002' = 2 }
        TabOf = @{ 'Fixtureball-DQ-002' = 'OWNED' }
        ResultRowsOf = @{}
    }
    $plan = New-SheetsMergePlan -Summary $summary -Collected `
        @([pscustomobject]@{ Job = $job; Rows = @([pscustomobject]@{ check_type = 'X' }) }) `
        -Existing $existing -OutputFolder 'x'

    # The spans only; C2 is written separately as the link to the statement.
    $identity = @($plan.Operations | Where-Object {
            $_.Sheet -eq 'OWNED' -and $_.Kind -eq 'Write' -and $_.Range -match '^[A-Z]2:[A-Z]2$' })
    Assert-Equal 2 $identity.Count 'the identity row is written in two spans'
    Assert-Equal 'A2:D2' $identity[0].Range 'up to What it does'
    Assert-Equal 'G2:O2' $identity[1].Range 'resuming after Comment and Check By'
    Assert-Equal 0 @($plan.Operations | Where-Object {
            $_.Sheet -eq 'OWNED' -and $_.Range -in @('E2', 'F2') }).Count 'and never through E2 or F2'
}

Test-That 'a result over the cap is cut and the tab says so on its own face' {
    $job = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Name = 'BIG'; What = ''; Sql = 'SELECT 1;' }
    $rows = @(1..12 | ForEach-Object { [pscustomobject]@{ check_type = 'X'; id = $_ } })
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 12 -Eligible 900 -Verdict 'New'))
    $existing = [pscustomobject]@{
        HasOverviewHeader = $true; OverviewRowOf = @{}; TabOf = @{ 'Fixtureball-DQ-002' = 'BIG' }
        ResultRowsOf = @{}
    }
    $plan = New-SheetsMergePlan -Summary $summary -Collected @([pscustomobject]@{ Job = $job; Rows = $rows }) `
        -Existing $existing -OutputFolder "D:\out\run" -MaxRows 5

    $note = @($plan.Operations | Where-Object { $_.Range -eq 'C3' })[0].Values[0][0]
    Assert-True ($note -like '5 of 12 rows*') "the tab should name both counts; it said '$note'"
    Assert-True ($note -like "*D:\out\run*") 'and where the full result is'

    # Kind matters as well as the range: the clear that precedes the block starts at A5 too.
    $written = @($plan.Operations | Where-Object {
            $_.Sheet -eq 'BIG' -and $_.Kind -eq 'Write' -and $_.Range -like 'A5:*' })
    Assert-Equal 1 $written.Count 'one result block'
    Assert-Equal 6 $written[0].Values.Count 'a header plus five rows, not twelve'
}

Test-That 'a result under the cap carries no truncation note' {
    $job = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Name = 'SMALL'; What = ''; Sql = 'SELECT 1;' }
    $rows = @(1..3 | ForEach-Object { [pscustomobject]@{ check_type = 'X'; id = $_ } })
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 3 -Eligible 900 -Verdict 'New'))
    $existing = [pscustomobject]@{
        HasOverviewHeader = $true; OverviewRowOf = @{}; TabOf = @{ 'Fixtureball-DQ-002' = 'SMALL' }
        ResultRowsOf = @{}
    }
    $plan = New-SheetsMergePlan -Summary $summary -Collected @([pscustomobject]@{ Job = $job; Rows = $rows }) `
        -Existing $existing -OutputFolder 'x' -MaxRows 20000

    Assert-Equal '' @($plan.Operations | Where-Object { $_.Range -eq 'C3' })[0].Values[0][0] `
        'nothing was cut, so the tab says nothing'
}

Test-That 'two checks abbreviating to one title do not collide' {
    # addSheet fails outright on a duplicate title, and it is sent in the same batch as every
    # other tab this run adds - so one collision would cost the whole document update.
    $first = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Name = 'SAME_NAME'; What = ''; Sql = 'SELECT 1;' }
    $second = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-004'; Name = 'SAME_NAME'; What = ''; Sql = 'SELECT 1;' }
    $summary = @(
        (New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 1 -Eligible 9 -Verdict 'New'),
        (New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-004' -Findings 1 -Eligible 9 -Verdict 'New'))
    $rows = @([pscustomobject]@{ check_type = 'X' })
    $existing = [pscustomobject]@{
        HasOverviewSheet = $true; HasOverviewHeader = $true; OverviewRowOf = @{}; TabOf = @{}
        Titles = @('Overview')
    }

    $plan = New-SheetsMergePlan -Summary $summary -Existing $existing -OutputFolder 'x' -Collected @(
        [pscustomobject]@{ Job = $first; Rows = $rows },
        [pscustomobject]@{ Job = $second; Rows = $rows })

    $added = @($plan.Operations | Where-Object { $_.Kind -eq 'AddSheet' -and $_.Sheet -ne 'SQL' } |
        ForEach-Object { $_.Sheet })
    Assert-Equal 2 $added.Count 'both tabs are added'
    Assert-Equal 2 (@($added | Select-Object -Unique)).Count 'and under different titles'
    Assert-True ($added -contains 'SAME_NAME~2') "the second is suffixed; got $($added -join ', ')"
}

Test-That 'a title the document already uses is not minted a second time' {
    $job = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Name = 'TAKEN'; What = ''; Sql = 'SELECT 1;' }
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 1 -Eligible 9 -Verdict 'New'))
    # The tab exists but carries a different check's id in A2, so this check has no tab of its
    # own and needs one - under a title that is free.
    $existing = [pscustomobject]@{
        HasOverviewSheet = $true; HasOverviewHeader = $true; OverviewRowOf = @{}; TabOf = @{}
        Titles = @('Overview', 'TAKEN')
    }
    $plan = New-SheetsMergePlan -Summary $summary -Existing $existing -OutputFolder 'x' -Collected `
        @([pscustomobject]@{ Job = $job; Rows = @([pscustomobject]@{ check_type = 'X' }) })

    Assert-Equal 'TAKEN~2' @($plan.Operations | Where-Object { $_.Kind -eq 'AddSheet' })[0].Sheet `
        'the existing tab is left alone and a free title is used'
}

Test-That 'a new row seeds the Comment mirror, and a later run leaves it alone' {
    # Written once, on the row that did not exist before. On any later run K is the
    # reviewer's, whether it still holds the formula or the text they typed over it.
    $job = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Name = 'MIRRORED'; What = ''; Sql = 'SELECT 1;' }
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 1 -Eligible 9 -Verdict 'New'))
    $collected = @([pscustomobject]@{ Job = $job; Rows = @([pscustomobject]@{ check_type = 'X' }) })

    $fresh = New-SheetsMergePlan -Summary $summary -Collected $collected -OutputFolder 'x' -Existing (
        [pscustomobject]@{ HasOverviewSheet = $true; HasOverviewHeader = $true; OverviewRowOf = @{}; TabOf = @{}; Titles = @('Overview') })
    $mirror = @($fresh.Operations | Where-Object { $_.Sheet -eq 'Overview' -and $_.Range -like 'K*' })

    Assert-Equal 1 $mirror.Count 'one mirror written'
    Assert-Equal "='MIRRORED'!E2" $mirror[0].Values[0][0]'pointing at the tab it belongs to'
    Assert-Equal $false $mirror[0].Raw 'sent as USER_ENTERED, or it arrives as the text of a formula'

    # And the mirror must come after the row write that leaves K empty, since both land in
    # the same run and the later one wins.
    $ops = @($fresh.Operations)
    $rowAt = [array]::IndexOf($ops, @($ops | Where-Object { $_.Range -like 'A*:U*' -and $_.Range -ne 'A1:U1' })[0])
    Assert-True ($rowAt -lt [array]::IndexOf($ops, $mirror[0])) 'the mirror lands on top of the empty cell'

    $second = New-SheetsMergePlan -Summary $summary -Collected $collected -OutputFolder 'x' -Existing (
        [pscustomobject]@{
            HasOverviewSheet = $true; HasOverviewHeader = $true
            OverviewRowOf = @{ 'Fixtureball-DQ-002' = 2 }
            EmptyCommentOf = @{}
            TabOf = @{ 'Fixtureball-DQ-002' = 'MIRRORED' }; Titles = @('Overview', 'MIRRORED') })
    Assert-Equal 0 @($second.Operations | Where-Object { $_.Sheet -eq 'Overview' -and $_.Range -like 'K*' }).Count `
        'a row that already exists keeps whatever is in its Comment cell'
}

Test-That 'an existing row with an empty Comment is seeded, and one with anything in it is not' {
    # A row written before the mirror existed, or one whose cell was cleared, otherwise never
    # gets one. An empty cell holds nothing of anyone's; a cell with text in it holds the only
    # thing in the document that cannot be regenerated.
    $job = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Name = 'MIRRORED'; What = ''; Sql = 'SELECT 1;' }
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 1 -Eligible 9 -Verdict 'New'))
    $collected = @([pscustomobject]@{ Job = $job; Rows = @([pscustomobject]@{ check_type = 'X' }) })

    $state = @{
        HasOverviewSheet = $true; HasOverviewHeader = $true
        OverviewRowOf = @{ 'Fixtureball-DQ-002' = 4 }
        TabOf = @{ 'Fixtureball-DQ-002' = 'MIRRORED' }; Titles = @('Overview', 'MIRRORED')
    }

    $state['EmptyCommentOf'] = @{ 'Fixtureball-DQ-002' = $true }
    $seeded = New-SheetsMergePlan -Summary $summary -Collected $collected -OutputFolder 'x' `
        -Existing ([pscustomobject]$state)
    $mirror = @($seeded.Operations | Where-Object { $_.Sheet -eq 'Overview' -and $_.Range -like 'K*' })
    Assert-Equal 1 $mirror.Count 'the empty cell is seeded'
    Assert-Equal 'K4:K4' $mirror[0].Range 'on the row the check already occupies'
    Assert-Equal "='MIRRORED'!E2" $mirror[0].Values[0][0]'pointing at its own tab'

    $state['EmptyCommentOf'] = @{}
    $kept = New-SheetsMergePlan -Summary $summary -Collected $collected -OutputFolder 'x' `
        -Existing ([pscustomobject]$state)
    Assert-Equal 0 @($kept.Operations | Where-Object { $_.Sheet -eq 'Overview' -and $_.Range -like 'K*' }).Count `
        'and a cell somebody has written in is left alone'
}

Test-That 'a check with no tab gets no mirror pointing nowhere' {
    # A check that failed or was skipped has no tab, so a formula would reference a sheet
    # that does not exist and show as #REF on the board.
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 0 -Eligible 9 -Verdict 'New'))
    $plan = New-SheetsMergePlan -Summary $summary -Collected @() -OutputFolder 'x' -Existing (
        [pscustomobject]@{ HasOverviewSheet = $true; HasOverviewHeader = $true; OverviewRowOf = @{}; TabOf = @{}; Titles = @('Overview') })

    Assert-Equal 0 @($plan.Operations | Where-Object { $_.Sheet -eq 'Overview' -and $_.Range -like 'K*' }).Count `
        'no tab, no mirror'
}

Test-That 'a new tab is created at the size its result needs' {
    # A tab is born with 1000 rows and Google will not grow one to meet a range starting past
    # its end. A 5 000-row result writes its first chunk, which stretches the grid to exactly
    # that chunk, and the second chunk is rejected for beginning beyond it - taking the whole
    # batch, and so the whole document update, with it.
    $job = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Name = 'BIG_RESULT'; What = ''; Sql = 'SELECT 1;' }
    $rows = @(1..5000 | ForEach-Object { [pscustomobject]@{ check_type = 'X'; id = $_ } })
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 5000 -Eligible 9000 -Verdict 'New'))
    $existing = [pscustomobject]@{
        HasOverviewSheet = $true; HasOverviewHeader = $true; OverviewRowOf = @{}
        EmptyCommentOf = @{}; TabOf = @{}; Titles = @('Overview')
        RowCapacityOf = @{}; SheetIdOf = @{}
    }
    $plan = New-SheetsMergePlan -Summary $summary -Collected @([pscustomobject]@{ Job = $job; Rows = $rows }) `
        -Existing $existing -OutputFolder 'x'

    $add = @($plan.Operations | Where-Object { $_.Kind -eq 'AddSheet' -and $_.Sheet -eq 'BIG_RESULT' })
    Assert-Equal 1 $add.Count 'the tab is added'
    Assert-True ($add[0].Rows -ge 5005) "created with room for the result; got $($add[0].Rows)"
}

Test-That 'an existing tab too small for this run is grown, by id, and never shrunk' {
    $job = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Name = 'GROWN'; What = ''; Sql = 'SELECT 1;' }
    $rows = @(1..4000 | ForEach-Object { [pscustomobject]@{ check_type = 'X'; id = $_ } })
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 4000 -Eligible 9000 -Verdict 'New'))
    $state = @{
        HasOverviewSheet = $true; HasOverviewHeader = $true; OverviewRowOf = @{}
        EmptyCommentOf = @{}; TabOf = @{ 'Fixtureball-DQ-002' = 'GROWN' }
        Titles = @('Overview', 'GROWN'); SheetIdOf = @{ 'GROWN' = 771 }
    }

    $state['RowCapacityOf'] = @{ 'GROWN' = 1000 }
    $grow = New-SheetsMergePlan -Summary $summary -Collected @([pscustomobject]@{ Job = $job; Rows = $rows }) `
        -Existing ([pscustomobject]$state) -OutputFolder 'x'
    $resize = @($grow.Operations | Where-Object { $_.Kind -eq 'Resize' })
    Assert-Equal 1 $resize.Count 'a tab short of room is grown'
    Assert-Equal 771 $resize[0].SheetId 'named by sheetId, since updateSheetProperties cannot find one by title'
    Assert-True ($resize[0].Rows -ge 4005) "to at least what the result needs; got $($resize[0].Rows)"

    # Lowering rowCount deletes the rows below it, and on a tab somebody may have annotated
    # that is not a decision this code gets to make.
    $state['RowCapacityOf'] = @{ 'GROWN' = 20000 }
    $keep = New-SheetsMergePlan -Summary $summary -Collected @([pscustomobject]@{ Job = $job; Rows = $rows }) `
        -Existing ([pscustomobject]$state) -OutputFolder 'x'
    Assert-Equal 0 @($keep.Operations | Where-Object { $_.Kind -eq 'Resize' }).Count `
        'a tab with room to spare is left as it is, never shrunk'
}

Test-That 'an empty tab left by a failed update is adopted, not duplicated' {
    # The tabs and the values travel in separate batches. An update that fails on the second
    # leaves nameless tabs behind, and the next run cannot recognise them because a tab is
    # matched by the Check ID in its own A2. Observed live: 99 empty tabs, then 99 more
    # carrying a ~2 beside them.
    $job = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Name = 'LEFTOVER'; What = ''; Sql = 'SELECT 1;' }
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 1 -Eligible 9 -Verdict 'New'))
    $existing = [pscustomobject]@{
        HasOverviewSheet = $true; HasOverviewHeader = $true; OverviewRowOf = @{}
        EmptyCommentOf = @{}; TabOf = @{}
        Titles = @('Overview', 'LEFTOVER')
        EmptyTabs = @{ 'LEFTOVER' = $true }
        RowCapacityOf = @{ 'LEFTOVER' = 1000 }; SheetIdOf = @{ 'LEFTOVER' = 42 }
    }
    $plan = New-SheetsMergePlan -Summary $summary -Existing $existing -OutputFolder 'x' -Collected `
        @([pscustomobject]@{ Job = $job; Rows = @([pscustomobject]@{ check_type = 'X' }) })

    Assert-Equal 0 @($plan.Operations | Where-Object { $_.Kind -eq 'AddSheet' -and $_.Sheet -ne 'SQL' }).Count `
        'no check tab is added'
    Assert-True (@($plan.Operations | Where-Object { $_.Sheet -eq 'LEFTOVER' -and $_.Kind -eq 'Write' }).Count -gt 0) `
        'the leftover is written into instead'
    Assert-Equal 0 @($plan.Operations | Where-Object { $_.Sheet -like '*~2' }).Count 'and no second set is minted'
}

Test-That 'two checks cannot adopt the same leftover' {
    $first = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Name = 'SHARED'; What = ''; Sql = 'SELECT 1;' }
    $second = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-004'; Name = 'SHARED'; What = ''; Sql = 'SELECT 1;' }
    $summary = @(
        (New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 1 -Eligible 9 -Verdict 'New'),
        (New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-004' -Findings 1 -Eligible 9 -Verdict 'New'))
    $rows = @([pscustomobject]@{ check_type = 'X' })
    $existing = [pscustomobject]@{
        HasOverviewSheet = $true; HasOverviewHeader = $true; OverviewRowOf = @{}
        EmptyCommentOf = @{}; TabOf = @{}
        Titles = @('Overview', 'SHARED'); EmptyTabs = @{ 'SHARED' = $true }
        RowCapacityOf = @{ 'SHARED' = 1000 }; SheetIdOf = @{ 'SHARED' = 7 }
    }
    $plan = New-SheetsMergePlan -Summary $summary -Existing $existing -OutputFolder 'x' -Collected @(
        [pscustomobject]@{ Job = $first; Rows = $rows },
        [pscustomobject]@{ Job = $second; Rows = $rows })

    $added = @($plan.Operations | Where-Object { $_.Kind -eq 'AddSheet' -and $_.Sheet -ne 'SQL' } |
        ForEach-Object { $_.Sheet })
    Assert-Equal 1 $added.Count 'the second check gets a tab of its own'
    Assert-Equal 'SHARED~2' $added[0] 'under a free title, since the leftover is already claimed'
}

Test-That 'the default Sheet1 is removed once, and Overview is brought to the front' {
    # Sheet1 exists because the document does, not because anybody made it. Overview is
    # created after it and would otherwise open second for good.
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 1 -Eligible 9 -Verdict 'New'))
    $existing = [pscustomobject]@{
        HasOverviewSheet = $true; HasOverviewHeader = $true; OverviewRowOf = @{}
        EmptyCommentOf = @{}; TabOf = @{}; Titles = @('Sheet1', 'Overview')
        EmptyTabs = @{ 'Sheet1' = $true }
        RowCapacityOf = @{}; SheetIdOf = @{ 'Sheet1' = 0; 'Overview' = 55 }
        SheetIndexOf = @{ 'Sheet1' = 0; 'Overview' = 1 }
    }
    $plan = New-SheetsMergePlan -Summary $summary -Collected @() -Existing $existing -OutputFolder 'x'
    $ops = @($plan.Operations)

    $drop = @($ops | Where-Object { $_.Kind -eq 'DeleteSheet' })
    Assert-Equal 1 $drop.Count 'Sheet1 is removed'
    Assert-Equal 'Sheet1' $drop[0].Sheet 'and nothing else is'

    $move = @($ops | Where-Object { $_.Kind -eq 'MoveSheet' })
    Assert-Equal 1 $move.Count 'Overview is moved'
    Assert-Equal 0 $move[0].Index 'to the front'
    Assert-True ([array]::IndexOf($ops, $drop[0]) -lt [array]::IndexOf($ops, $move[0])) `
        'removal before the move, since deleting shifts every index after it'
}

Test-That 'a Sheet1 somebody has used is left alone, and a front Overview is not moved' {
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 1 -Eligible 9 -Verdict 'New'))
    $existing = [pscustomobject]@{
        HasOverviewSheet = $true; HasOverviewHeader = $true; OverviewRowOf = @{}
        EmptyCommentOf = @{}; TabOf = @{}; Titles = @('Overview', 'Sheet1')
        # Not in EmptyTabs: it carries something, so it stopped being the default.
        EmptyTabs = @{}
        RowCapacityOf = @{}; SheetIdOf = @{ 'Sheet1' = 0; 'Overview' = 55 }
        SheetIndexOf = @{ 'Overview' = 0; 'Sheet1' = 1 }
    }
    $plan = New-SheetsMergePlan -Summary $summary -Collected @() -Existing $existing -OutputFolder 'x'

    Assert-Equal 0 @($plan.Operations | Where-Object { $_.Kind -eq 'DeleteSheet' }).Count `
        'a tab with anything in it is nobody else to delete'
    Assert-Equal 0 @($plan.Operations | Where-Object { $_.Kind -eq 'MoveSheet' }).Count `
        'and an Overview already at the front is not moved to change nothing'
}

Test-That 'a check tab carries its header row and both of its links' {
    # Without row 1 the tab shows "1 Structure" and a category over nothing, and a reader has
    # to go back to Overview to learn what D2 and E2 are.
    $job = [pscustomobject]@{
        CheckId = 'Fixtureball-DQ-002'; Name = 'LINKED'; What = 'a thing'
        Sql = "SELECT 1`nFROM t;"
    }
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 1 -Eligible 9 -Verdict 'New'))
    $existing = [pscustomobject]@{
        HasOverviewSheet = $true; HasOverviewHeader = $true; OverviewRowOf = @{}
        EmptyCommentOf = @{}; TabOf = @{}; Titles = @('Overview'); EmptyTabs = @{}
        RowCapacityOf = @{}; SheetIdOf = @{ 'Overview' = 5 }; SheetIndexOf = @{ 'Overview' = 0 }
    }
    $plan = New-SheetsMergePlan -Summary $summary -Existing $existing -OutputFolder 'x' -Collected `
        @([pscustomobject]@{ Job = $job; Rows = @([pscustomobject]@{ check_type = 'X' }) })

    $header = @($plan.Operations | Where-Object { $_.Sheet -eq 'LINKED' -and $_.Range -eq 'A1:O1' })
    Assert-Equal 1 $header.Count 'the header row is written'
    Assert-Equal 'What it does' $header[0].Values[0][3] 'so D names what D2 holds'

    # The mirror is derived from this list rather than written as a literal, so the two cannot
    # disagree - but a reader still has to be told where the reviewer's cells are.
    Assert-Equal 'Comment' $header[0].Values[0][4] 'Comment at E'
    Assert-Equal 'Check By' $header[0].Values[0][5] 'and Check By at F'
    Assert-Equal 'Expected' $header[0].Values[0][6] 'the comparison block starts at G'
    Assert-Equal 'Verdict' $header[0].Values[0][11] 'and ends with the verdict at L'
    Assert-True ($header[0].Values[0] -notcontains 'Priority') 'Priority is gone, being a board sort'
    Assert-True ($header[0].Values[0] -notcontains 'Signal') 'and so is the signal pair'
    Assert-True ($header[0].Values[0] -notcontains 'Signal reason') 'both of it'

    $back = @($plan.Operations | Where-Object { $_.Sheet -eq 'LINKED' -and $_.Range -eq 'A3' })
    Assert-Equal 1 $back.Count 'A3 carries the way back'
    Assert-True ($back[0].Values[0][0] -like '*Return to Overview*') 'labelled for a reader'
    Assert-Equal $false $back[0].Raw 'as a formula, or it arrives as the text of one'

    $sql = @($plan.Operations | Where-Object { $_.Sheet -eq 'LINKED' -and $_.Range -eq 'C2' })
    Assert-Equal 1 $sql.Count 'C2 links forward to the statement'
    Assert-True ($sql[0].Values[0][0] -like '*range=A1*') 'at the block this check owns'
}

Test-That 'the row count on Overview is the way in to the check tab' {
    # A reviewer scans the board and clicks through. Rows carries the link, as it does in the
    # workbook; Findings, Eligible and Change stay plain numbers so they still sort and filter.
    $job = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Name = 'JUMPED'; What = ''; Sql = 'SELECT 1;' }
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 1 -Eligible 9 -Verdict 'New'))
    $existing = [pscustomobject]@{
        HasOverviewSheet = $true; HasOverviewHeader = $true; OverviewRowOf = @{ 'Fixtureball-DQ-002' = 4 }
        EmptyCommentOf = @{}; TabOf = @{ 'Fixtureball-DQ-002' = 'JUMPED' }
        Titles = @('Overview', 'JUMPED'); EmptyTabs = @{}
        RowCapacityOf = @{}; SheetIdOf = @{ 'Overview' = 5; 'JUMPED' = 9 }; SheetIndexOf = @{ 'Overview' = 0 }
    }
    $plan = New-SheetsMergePlan -Summary $summary -Existing $existing -OutputFolder 'x' -Collected `
        @([pscustomobject]@{ Job = $job; Rows = @([pscustomobject]@{ check_type = 'X' }) })

    $link = @($plan.Operations | Where-Object { $_.Sheet -eq 'Overview' -and $_.Range -eq 'H4:H4' })
    Assert-Equal 1 $link.Count 'Rows carries a link'
    Assert-Equal $false $link[0].Raw 'as a formula'
    Assert-True ($link[0].Values[0][0] -like '*JUMPED*') 'pointing at this check own tab'
}

Test-That 'a check with no tab keeps a plain row count rather than a link to nowhere' {
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 0 -Eligible 9 -Verdict 'New'))
    $existing = [pscustomobject]@{
        HasOverviewSheet = $true; HasOverviewHeader = $true; OverviewRowOf = @{ 'Fixtureball-DQ-002' = 4 }
        EmptyCommentOf = @{}; TabOf = @{}; Titles = @('Overview'); EmptyTabs = @{}
        RowCapacityOf = @{}; SheetIdOf = @{ 'Overview' = 5 }; SheetIndexOf = @{ 'Overview' = 0 }
    }
    $plan = New-SheetsMergePlan -Summary $summary -Collected @() -Existing $existing -OutputFolder 'x'
    Assert-Equal 0 @($plan.Operations | Where-Object { $_.Range -eq 'H4:H4' }).Count 'no link is written'
}

Test-That 'a result block is declared a table, and an existing one is corrected not replaced' {
    $job = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Name = 'TABLED'; What = ''; Sql = 'SELECT 1;' }
    $rows = @(1..3 | ForEach-Object { [pscustomobject]@{ check_type = 'X'; id = $_ } })
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 3 -Eligible 9 -Verdict 'New'))
    $state = @{
        HasOverviewSheet = $true; HasOverviewHeader = $true; OverviewRowOf = @{}
        EmptyCommentOf = @{}; TabOf = @{ 'Fixtureball-DQ-002' = 'TABLED' }
        Titles = @('Overview', 'TABLED'); EmptyTabs = @{}
        RowCapacityOf = @{}; SheetIdOf = @{ 'Overview' = 5; 'TABLED' = 9 }; SheetIndexOf = @{ 'Overview' = 0 }
    }

    $state['TableOf'] = @{}
    $fresh = New-SheetsMergePlan -Summary $summary -Collected @([pscustomobject]@{ Job = $job; Rows = $rows }) `
        -Existing ([pscustomobject]$state) -OutputFolder 'x'
    $table = @($fresh.Operations | Where-Object { $_.Kind -eq 'Table' -and $_.Sheet -eq 'TABLED' })
    # Two: the identity block at the top and the results below it. Found by name rather than
    # by position, so neither assertion depends on which the planner happens to emit first.
    Assert-Equal 2 $table.Count 'the result block and the identity block are each declared a table'
    $result = @($table | Where-Object { $_.Name -eq 'Fixtureball_DQ_002' })
    Assert-Equal 1 $result.Count 'the result block is named for the check'
    Assert-Equal 4 $result[0].FromRow 'starting on the header row of the block'
    Assert-Equal 8 $result[0].ToRow 'and ending past the last row it holds'
    # The identity block takes the check's number and nothing else: every tab in the document
    # is the same sport, so the sport in the name would distinguish none of them.
    $identity = @($table | Where-Object { $_.Name -eq 'DQ_002_Overview' })
    Assert-Equal 1 $identity.Count 'the identity block is named for the check number alone'
    Assert-Equal 0 $identity[0].FromRow 'covering the header'
    Assert-Equal 3 $identity[0].ToRow 'the identity row and the way back'
    Assert-Equal 0 $fresh.KnownTables.Count 'with nothing existing to update'

    # A tab that already carries one is updated. The range is what goes stale as a result
    # grows or shrinks; the table itself is fine.
    $state['TableOf'] = @{ 'TABLED' = @([pscustomobject]@{ Id = 'T1'; Name = 'old'; FromRow = 4; ToRow = 99; FromCol = 0; ToCol = 4 }) }
    $again = New-SheetsMergePlan -Summary $summary -Collected @([pscustomobject]@{ Job = $job; Rows = $rows }) `
        -Existing ([pscustomobject]$state) -OutputFolder 'x'
    Assert-Equal 'T1' @($again.KnownTables['TABLED'])[0].Id 'the existing table is carried to the transport'
    Assert-Equal 8 @($again.Operations | Where-Object {
            $_.Kind -eq 'Table' -and $_.Sheet -eq 'TABLED' -and $_.Name -eq 'Fixtureball_DQ_002' })[0].ToRow `
        'and its extent corrected to this run'
}

Test-That 'a table name is made formula-safe' {
    # Sheets allows letters, digits and underscores and refuses to start on a digit, and a
    # CheckID is full of hyphens. The live run that found this came back with "The table name
    # is invalid"; the probe before it was called probe, and proved only that a legal name is
    # legal.
    Assert-Equal 'Artistic_Gymnastics_DQ_021' (ConvertTo-SheetsTableName -Name 'Artistic-Gymnastics-DQ-021') 'hyphens'
    Assert-Equal 'GLOBAL_DQ_009' (ConvertTo-SheetsTableName -Name 'GLOBAL-DQ-009') 'and the template form'
    Assert-Equal '_2024_thing' (ConvertTo-SheetsTableName -Name '2024 thing') 'a leading digit is prefixed'
    Assert-Equal 'Already_fine' (ConvertTo-SheetsTableName -Name 'Already_fine') 'a legal name is untouched'
}

Test-That 'a board with no table gets one' {
    # It used to be created only by hand and merely maintained here. That held until the
    # document was rebuilt from empty and the hand-made one went with it, leaving a rule that
    # would never restore what it had helped lose.
    $summary = @(
        (New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 1 -Eligible 9 -Verdict 'New'),
        (New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-004' -Findings 1 -Eligible 9 -Verdict 'New'))
    $existing = [pscustomobject]@{
        HasOverviewSheet = $true; HasOverviewHeader = $true; OverviewRowOf = @{}
        EmptyCommentOf = @{}; TabOf = @{}; Titles = @('Overview'); EmptyTabs = @{}
        RowCapacityOf = @{}; SheetIdOf = @{ 'Overview' = 5 }; SheetIndexOf = @{ 'Overview' = 0 }
        TableOf = @{}
    }
    $plan = New-SheetsMergePlan -Summary $summary -Collected @() -Existing $existing -OutputFolder 'x'

    $board = @($plan.Operations | Where-Object { $_.Kind -eq 'Table' -and $_.Sheet -eq 'Overview' })
    Assert-Equal 1 $board.Count 'the board is declared a table'
    Assert-Equal 'Overview' $board[0].Name 'under the plain name, one board to a document'
    Assert-Equal 0 $board[0].FromRow 'starting on the header row'
    Assert-Equal 3 $board[0].ToRow 'and covering both appended checks'
    Assert-Equal 22 $board[0].ToCol 'across every column the board writes'
}

Test-That 'a board holding only its header is not made a table' {
    $existing = [pscustomobject]@{
        HasOverviewSheet = $true; HasOverviewHeader = $true; OverviewRowOf = @{}
        EmptyCommentOf = @{}; TabOf = @{}; Titles = @('Overview'); EmptyTabs = @{}
        RowCapacityOf = @{}; SheetIdOf = @{ 'Overview' = 5 }; SheetIndexOf = @{ 'Overview' = 0 }
        TableOf = @{}
    }
    $plan = New-SheetsMergePlan -Summary @() -Collected @() -Existing $existing -OutputFolder 'x'
    Assert-Equal 0 @($plan.Operations | Where-Object { $_.Kind -eq 'Table' }).Count `
        'a table over nothing but a heading is not a table'
}

Test-That 'a stale table on Overview is widened to the columns the board writes' {
    # Nothing here creates one. But a table made today covers today checks, and the next run
    # appends below it, so the range is exactly what goes stale.
    $summary = @(
        (New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 1 -Eligible 9 -Verdict 'New'),
        (New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-004' -Findings 1 -Eligible 9 -Verdict 'New'))
    $existing = [pscustomobject]@{
        HasOverviewSheet = $true; HasOverviewHeader = $true
        OverviewRowOf = @{ 'Fixtureball-DQ-002' = 2 }
        EmptyCommentOf = @{}; TabOf = @{}; Titles = @('Overview'); EmptyTabs = @{}
        RowCapacityOf = @{}; SheetIdOf = @{ 'Overview' = 5 }; SheetIndexOf = @{ 'Overview' = 0 }
        # A table made before the board gained a column: too short and too narrow.
        TableOf = @{ 'Overview' = [pscustomobject]@{ Id = 'B1'; Name = 'Table1'; FromRow = 0; ToRow = 2; FromCol = 0; ToCol = 15 } }
    }
    $plan = New-SheetsMergePlan -Summary $summary -Collected @() -Existing $existing -OutputFolder 'x'

    $board = @($plan.Operations | Where-Object { $_.Kind -eq 'Table' -and $_.Sheet -eq 'Overview' })
    Assert-Equal 1 $board.Count 'the extent is corrected'
    Assert-Equal 3 $board[0].ToRow 'down to the row the appended check now occupies'
    # No column here is anybody's choice to preserve - every one is written by the runner - so
    # a remembered width just leaves the newest column outside the table without a header.
    Assert-Equal 22 $board[0].ToCol 'and out to every column the board writes'
    Assert-Equal 'Table1' $board[0].Name 'while keeping their own name for it'
}

Test-That 'the board is redeclared every run, and keeps the name it was given' {
    # It used to be declared only when its extent had moved, which was right while the extent
    # was all the declaration carried. It now carries the header colour too, and a colour
    # changed in the source has to reach a document whose row count happens to be unchanged.
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 1 -Eligible 9 -Verdict 'New'))
    $existing = [pscustomobject]@{
        HasOverviewSheet = $true; HasOverviewHeader = $true
        OverviewRowOf = @{ 'Fixtureball-DQ-002' = 2 }
        EmptyCommentOf = @{}; TabOf = @{}; Titles = @('Overview'); EmptyTabs = @{}
        RowCapacityOf = @{}; SheetIdOf = @{ 'Overview' = 5 }; SheetIndexOf = @{ 'Overview' = 0 }
        TableOf = @{ 'Overview' = @([pscustomobject]@{ Id = 'B1'; Name = 'Petar board'; FromRow = 0; ToRow = 2; FromCol = 0; ToCol = 22 }) }
    }
    $plan = New-SheetsMergePlan -Summary $summary -Collected @() -Existing $existing -OutputFolder 'x'
    $board = @($plan.Operations | Where-Object { $_.Kind -eq 'Table' -and $_.Sheet -eq 'Overview' })
    Assert-Equal 1 $board.Count 'the board is declared'
    # The board holds rows, so it wears the same red as a result block rather than the grey
    # that marks a block naming a check.
    Assert-Equal $SheetsDataHeaderColour $board[0].HeaderColour 'in the colour a block of data wears'
    Assert-Equal 'Petar board' $board[0].Name 'under whatever somebody renamed it to'
}

Test-That 'the SQL tab holds every statement, each linking back to its results' {
    $first = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Name = 'ONE'; What = ''; Sql = "SELECT 1`nFROM t;" }
    $second = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-004'; Name = 'TWO'; What = ''; Sql = "SELECT 2`nFROM t;" }
    $summary = @(
        (New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 1 -Eligible 9 -Verdict 'New'),
        (New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-004' -Findings 1 -Eligible 9 -Verdict 'New'))
    $rows = @([pscustomobject]@{ check_type = 'X' })
    $existing = [pscustomobject]@{
        HasOverviewSheet = $true; HasOverviewHeader = $true; OverviewRowOf = @{}
        EmptyCommentOf = @{}; TabOf = @{}; Titles = @('Overview'); EmptyTabs = @{}
        RowCapacityOf = @{}; SheetIdOf = @{ 'Overview' = 5 }; SheetIndexOf = @{ 'Overview' = 0 }
    }
    $plan = New-SheetsMergePlan -Summary $summary -Existing $existing -OutputFolder 'x' -Collected @(
        [pscustomobject]@{ Job = $first; Rows = $rows },
        [pscustomobject]@{ Job = $second; Rows = $rows })

    Assert-Equal 1 @($plan.Operations | Where-Object { $_.Kind -eq 'AddSheet' -and $_.Sheet -eq 'SQL' }).Count 'the SQL tab is added'
    $block = @($plan.Operations | Where-Object { $_.Sheet -eq 'SQL' -and $_.Kind -eq 'Write' -and $_.Raw -ne $false })
    Assert-Equal 1 $block.Count 'one block write for the whole tab'
    $flat = (@($block[0].Values) | ForEach-Object { @($_)[0] }) -join "`n"
    Assert-True ($flat -like '*SELECT 1*') 'the first statement is on it'
    Assert-True ($flat -like '*SELECT 2*') 'and so is the second'
    Assert-True ($flat -like '*FROM t;*') 'keeping the line breaks it was written with'

    $backs = @($plan.Operations | Where-Object { $_.Sheet -eq 'SQL' -and $_.Raw -eq $false })
    Assert-Equal 2 $backs.Count 'each block links back to its results'
    Assert-True ($backs[0].Values[0][0] -like '*Fixtureball-DQ-002*') 'labelled with the CheckID'

    # The two C2 links must point at different blocks, or every check opens the same statement.
    $c2 = @($plan.Operations | Where-Object { $_.Range -eq 'C2' } | ForEach-Object { $_.Values[0][0] })
    Assert-Equal 2 (@($c2 | Select-Object -Unique)).Count 'and the two forward links differ'
}

Test-That 'the hidden columns are hidden only on the run that creates the board' {
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 1 -Eligible 9 -Verdict 'New'))

    # One operation per contiguous run. Collapsing the set to its lowest and highest would
    # hide C through M and take Check Name, Rows and Status with it.
    $fresh = New-SheetsMergePlan -Summary $summary -Collected @() -Existing $null -OutputFolder 'x'
    $hide = @($fresh.Operations | Where-Object { $_.Kind -eq 'HideColumns' })
    Assert-Equal 2 $hide.Count 'hidden when Overview is created, and the gap is not bridged'
    Assert-Equal 3 $hide[0].From 'Parameters at C'
    Assert-Equal 3 $hide[0].To 'and only C'
    Assert-Equal 12 $hide[1].From 'from L'
    Assert-Equal 13 $hide[1].To 'to M'

    # Somebody who unhides them has decided something; putting them back every week is the
    # same defect as overwriting a comment.
    $existing = [pscustomobject]@{
        HasOverviewSheet = $true; HasOverviewHeader = $true; OverviewRowOf = @{}
        EmptyCommentOf = @{}; TabOf = @{}; Titles = @('Overview'); EmptyTabs = @{}
        RowCapacityOf = @{}; SheetIdOf = @{ 'Overview' = 5 }; SheetIndexOf = @{ 'Overview' = 0 }
    }
    Assert-Equal 0 @((New-SheetsMergePlan -Summary $summary -Collected @() -Existing $existing `
                -OutputFolder 'x').Operations | Where-Object { $_.Kind -eq 'HideColumns' }).Count `
        'and never re-hidden afterwards'
}

Test-That 'the runner renames a document it named itself, and nobody else' {
    $new = 'DQ Fixtureball Enetpulse'
    Assert-True (Test-SheetsTitleIsOurs -CurrentTitle 'Untitled spreadsheet' -Title $new) 'the placeholder'
    Assert-True (Test-SheetsTitleIsOurs -CurrentTitle '' -Title $new) 'and no title at all'

    # The pattern changed once. A document still wearing the old one is wearing a name nobody
    # chose, so the change reaches it rather than leaving one board named unlike the rest.
    Assert-True (Test-SheetsTitleIsOurs -CurrentTitle 'Enetpulse DQ - Fixtureball' -Title $new) `
        'and a name this runner gave it under the old pattern'

    Assert-Equal $false (Test-SheetsTitleIsOurs -CurrentTitle 'Petar - do not touch' -Title $new) `
        'a title somebody chose is theirs'
    Assert-Equal $false (Test-SheetsTitleIsOurs -CurrentTitle $new -Title $new) 'and one already right is not rewritten'
}

Test-That 'the Rows colour bands are rewritten every run, over that column only' {
    # Set once, they could never reach a document created before a threshold changed - the
    # defect that left one board with a column Sheets had to name for itself. Added without
    # removing, they would stack three more rules a week.
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 1 -Eligible 9 -Verdict 'New'))

    $fresh = New-SheetsMergePlan -Summary $summary -Collected @() -Existing $null -OutputFolder 'x'
    $rules = @($fresh.Operations | Where-Object { $_.Kind -eq 'FormatRules' })
    # Two columns carry bands now - Rows and Status.
    Assert-Equal 2 $rules.Count 'a new document gets its bands'
    Assert-Equal 8 $rules[0].Column 'on Rows at H'
    Assert-Equal 0 @($rules[0].Drop).Count 'with nothing to remove'
    Assert-Equal 3 @($rules[0].Rules).Count 'clean, a handful, and a hundred or more'

    # Column H is index 7 to 8; a rule over the whole board, or over any other column, is
    # somebody else's and survives.
    $existing = [pscustomobject]@{
        HasOverviewSheet = $true; HasOverviewHeader = $true; OverviewRowOf = @{}
        EmptyCommentOf = @{}; TabOf = @{}; Titles = @('Overview'); EmptyTabs = @{}
        RowCapacityOf = @{}; SheetIdOf = @{ 'Overview' = 5 }; SheetIndexOf = @{ 'Overview' = 0 }
        ConditionalFormatsOf = @{ 'Overview' = @(
                [pscustomobject]@{ ranges = @([pscustomobject]@{ startColumnIndex = 7; endColumnIndex = 8 }) }
                [pscustomobject]@{ ranges = @([pscustomobject]@{ startColumnIndex = 0; endColumnIndex = 22 }) }
                [pscustomobject]@{ ranges = @([pscustomobject]@{ startColumnIndex = 7; endColumnIndex = 8 }) }
                [pscustomobject]@{ ranges = @([pscustomobject]@{ startColumnIndex = 8; endColumnIndex = 9 }) }
            ) }
    }
    $again = @(@(New-SheetsMergePlan -Summary $summary -Collected @() -Existing $existing `
                -OutputFolder 'x').Operations | Where-Object { $_.Kind -eq 'FormatRules' })
    Assert-Equal 2 $again.Count 'and an existing one gets them again'
    $rowsRule = @($again | Where-Object { $_.Column -eq 8 })
    $statusRule = @($again | Where-Object { $_.Column -eq 9 })
    Assert-Equal '0 2' (@($rowsRule[0].Drop) -join ' ') 'replacing only the rules that cover Rows'
    # Status is column I, one to the right. The two drop lists are computed in a single pass
    # over the original rule list: each deletion renumbers what follows it, so two passes each
    # counting from zero would have the second one delete a rule the first had already shifted.
    Assert-Equal 1 $statusRule.Count 'and Status at I gets its own'
    Assert-Equal '3' (@($statusRule[0].Drop) -join ' ') 'replacing only the rules that cover Status'
    Assert-Equal 7 @($statusRule[0].Rules).Count 'one band per status the vocabulary allows'
    Assert-Equal 'TEXT_EQ' $statusRule[0].Rules[0].Type 'matched on the word, not on a number'
    Assert-True ([bool]$statusRule[0].Rules[0].Background) 'and filled, because what it wants to look like is a chip'

    # Rows runs to the bottom of the sheet; Status stops at the last row of the board. Sheets
    # shows a colour inside the dropdown editor only for a rule covering the same range the
    # validation does, and a validation on a table column covers the table.
    Assert-Equal $null $rowsRule[0].EndRow 'Rows follows the board down'
    Assert-True ([int]$statusRule[0].EndRow -gt 1) 'Status stops where the board does'
}

Test-That 'the board is centred, its owned headings named, and sorted by priority' {
    $summary = @(
        (New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 1 -Eligible 9 -Verdict 'New'),
        (New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-003' -Findings 0 -Eligible 9 -Verdict 'New'))
    $plan = New-SheetsMergePlan -Summary $summary -Collected @() -Existing $null -OutputFolder 'x'
    $formats = @($plan.Operations | Where-Object { $_.Kind -eq 'Format' -and $_.Sheet -eq 'Overview' })

    # One rule over the whole board, with no end row, so next week's rows are centred too.
    $whole = @($formats | Where-Object { $_.FromCol -eq 0 -and $_.ToCol -eq 22 })
    Assert-Equal 1 $whole.Count 'the whole board takes one alignment rule'
    Assert-Equal 'CENTER' $whole[0].Align 'centred'
    Assert-Equal $null $whole[0].ToRow 'and unbounded, so it follows the board down'

    # Status at I, Check By at J, Comment at K - the three the runner writes around.
    $owned = @($formats | Where-Object { $_.Colour -eq $SheetsReviewerHeaderColour })
    Assert-Equal 3 $owned.Count 'the reviewer three are named on the header row'
    Assert-Equal '8 9 10' ((@($owned | ForEach-Object { $_.FromCol }) | Sort-Object) -join ' ') `
        'at Status, Check By and Comment'
    Assert-Equal 1 $owned[0].ToRow 'on the header row alone, not down the column'
    Assert-True ([bool]$owned[0].Bold) 'and bold'

    $sort = @($plan.Operations | Where-Object { $_.Kind -eq 'Sort' })
    Assert-Equal 1 $sort.Count 'the board is sorted'
    # Priority carries a numeric prefix so a text sort produces the band order; CheckID second
    # keeps the order inside a band stable rather than whatever the last sort left.
    Assert-Equal '4 1' (@($sort[0].By) -join ' ') 'by Priority, then CheckID'
    Assert-Equal 1 $sort[0].FromRow 'below the header'
}

Test-That 'a finding is keyed by its ids, and by everything when it has none' {
    # The ids are the part of a row that does not change while the row means the same thing.
    $header = @('check_type', 'statistic_id', 'template_name', 'stray_participants',
        'participant_ids', 'participant_names')
    Assert-Equal '0 1' ((Get-SheetsFindingKeyColumns -Header $header) -join ' ') `
        'check_type and the one singular id column'

    # participant_ids is a list that grows and shrinks as people are corrected, and keying on
    # it would park a note every time somebody fixed one member of the group.
    Assert-True (@(Get-SheetsFindingKeyColumns -Header $header) -notcontains 4) `
        'a plural id column is payload, not identity'

    $plain = @('check_type', 'template_name', 'name_pattern')
    Assert-Equal '0 1 2' ((Get-SheetsFindingKeyColumns -Header $plain) -join ' ') `
        'a result with no id at all keys on the whole row'

    $key = Get-SheetsFindingKey -Row @('STRAY', '322012', 'World Cup') -Columns @(0, 1)
    Assert-Equal 'STRAY' ($key -split "`u{001F}")[0] 'the check type leads'
    Assert-Equal '322012' ($key -split "`u{001F}")[1] 'then the id'
    Assert-True ($key -ne (Get-SheetsFindingKey -Row @('OTHER', '322012', 'World Cup') -Columns @(0, 1))) `
        'two assertions about one object are two findings'
}

Test-That 'a note follows its finding rather than the row it used to be on' {
    # The row moved from third to first because the two above it were corrected. A note left at
    # its old offset would land against somebody else's finding, which reads exactly like a
    # judgement somebody made.
    $header = @('check_type', 'statistic_id', 'tournament_name')
    $rows = @(
        [pscustomobject]@{ check_type = 'STRAY'; statistic_id = '322012'; tournament_name = '2014' }
        [pscustomobject]@{ check_type = 'STRAY'; statistic_id = '999999'; tournament_name = '2019' }
    )
    $notes = @(
        [pscustomobject]@{ Key = (Get-SheetsFindingKey -Row @('STRAY', '322012') -Columns @(0, 1))
            Review = 'no issue'; Note = 'checked with the federation'
        }
        [pscustomobject]@{ Key = (Get-SheetsFindingKey -Row @('STRAY', '111111') -Columns @(0, 1))
            Review = 'fixed'; Note = ''
        }
    )
    $carried = New-SheetsCarriedReview -Header $header -Rows $rows -Was $header -Notes $notes

    Assert-Equal 'No Issue / Change' $carried.Review[0] 'the surviving finding keeps its review'
    Assert-Equal 'checked with the federation' $carried.Note[0] 'and its note'
    Assert-Equal '' $carried.Review[1] 'a finding nobody judged stays empty'
    Assert-Equal 1 @($carried.Dropped).Count 'the one whose finding is gone is reported'
    Assert-Equal 'Fixed' $carried.Dropped[0].Review 'with what it said'
    Assert-True ($carried.Dropped[0].Why -like '*no longer in the result*') 'and why it could not go back'
}

Test-That 'a re-shaped check parks every note instead of matching them by luck' {
    # GLOBAL-DQ-030 went from one row per stray participant to one row per statistic on
    # 2026-08-11. Its 310 notes were keyed on a column the new result does not emit, and that
    # is not a correction - it must not read like one.
    $was = @('check_type', 'statistic_participants_id', 'statistic_id', 'participant_id')
    $now = @('check_type', 'statistic_id', 'template_name')
    $rows = @([pscustomobject]@{ check_type = 'STRAY'; statistic_id = '322012'; template_name = 'World Cup' })
    $notes = @([pscustomobject]@{ Key = "STRAY`u{001F}1404776`u{001F}322012`u{001F}2009157"
            Review = 'no issue'; Note = ''
        })
    $carried = New-SheetsCarriedReview -Header $now -Rows $rows -Was $was -Notes $notes

    Assert-Equal '' $carried.Review[0] 'nothing is guessed onto the new rows'
    Assert-Equal 1 @($carried.Dropped).Count 'and the note is reported rather than dropped quietly'
    Assert-True ($carried.Dropped[0].Why -like '*re-shaped*') 'saying the shape changed, not that it was fixed'
}

Test-That 'a reviewer column is found under the name it had as well as the one it has' {
    # A tab is found by its heading, so renaming a column makes every existing one invisible to
    # the next run - and invisible here means cleared and rewritten empty, which is the loss
    # these columns exist to stop. Artistic Gymnastics carried 104 tabs headed 'Review' for a
    # day before it became 'Review Status'.
    $current = @('check_type', 'event_id', 'eligible_count') + $SheetsRowReviewColumns
    Assert-Equal 3 (Get-SheetsReviewColumnIndex -Header $current) 'the heading it has now'

    # Only the first column is looked for; the second is the one beside it, so its own heading
    # can change without anything having to remember what it used to be.
    foreach ($former in $SheetsRowReviewFormerColumns) {
        $old = @('check_type', 'event_id', 'eligible_count', $former, 'Review note')
        Assert-Equal 3 (Get-SheetsReviewColumnIndex -Header $old) "the heading '$former' it had before"
    }

    Assert-Equal -1 (Get-SheetsReviewColumnIndex -Header @('check_type', 'event_id')) `
        'and a tab that has never had one says so'
}

Test-That 'a dropdown finds its table by row as well as by column' {
    # A check tab carries two tables and both span every column index the result uses, so
    # matching on columns alone picked whichever the API listed first. That put Review Status on
    # 'Category' in the identity block on one tab and in the right place on the next, from the
    # same run - the order Google returns tables in is not part of the contract.
    $identity = [pscustomobject]@{
        Id = 'id-block'; Name = 'DQ_051_Overview'; FromRow = 0; ToRow = 3; FromCol = 0; ToCol = 15
        Columns = @(@{ columnIndex = 13; columnName = 'Category' })
    }
    $result = [pscustomobject]@{
        Id = 'id-result'; Name = 'Fixtureball_DQ_051'; FromRow = 4; ToRow = 8; FromCol = 0; ToCol = 15
        Columns = @(@{ columnIndex = 13; columnName = 'Review Status' })
    }
    $validation = [pscustomobject]@{
        Sheet = 'T'; Column = 14; Name = 'Review Status'; Values = @('Fixed', 'In Progress')
    }

    # The identity block first in the list, which is the order that produced the defect.
    $request = New-SheetsValidationRequest -Validation $validation -Tables @($identity, $result) `
        -SheetId 9 -Row 4
    Assert-Equal 'id-result' $request.updateTable.table.tableId 'the result table, not the block above it'
    $typed = @(@($request.updateTable.table.columnProperties) | Where-Object { $_.columnType })
    Assert-Equal 'Review Status' $typed[0].columnName 'and the column it belongs to'

    # Without a row it still has to choose something rather than fail, which is what Overview -
    # one table on the tab - relies on.
    $plain = New-SheetsValidationRequest -Validation $validation -Tables @($result) -SheetId 9
    Assert-Equal 'id-result' $plain.updateTable.table.tableId 'a single-table tab needs no row'
}

Test-That 'a tab with no table yet takes the dropdown below its result header, not up the column' {
    # The tables are declared after this batch is sent, so the run that creates a check tab
    # finds none and falls back to a plain rule. Drawn from row 2 it ran up through the identity
    # block, and on a seven-column result that block's Findings sits at the same index: a count
    # of 742 with a reviewer's three words on it.
    $validation = [pscustomobject]@{
        Sheet = 'T'; Column = 8; Name = 'Review Status'; Values = @('Fixed', 'In Progress')
    }

    $sent = New-SheetsValidationRequest -Validation $validation -Tables @() -SheetId 9 -Row 4
    Assert-Equal 5 $sent.setDataValidation.range.startRowIndex 'the first row under the result header'
    Assert-Equal $null $sent.setDataValidation.range.endRowIndex 'and open below it, for rows a later run appends'
    Assert-Equal 7 $sent.setDataValidation.range.startColumnIndex 'over the column the planner named'

    $noRow = New-SheetsValidationRequest -Validation $validation -Tables @() -SheetId 9
    Assert-Equal 1 $noRow.setDataValidation.range.startRowIndex 'Overview, with no header row to be told about, is unchanged'
}

Test-That 'a type put on the wrong table by an earlier run is taken off' {
    $identity = [pscustomobject]@{
        Id = 'id-block'; Name = 'DQ_051_Overview'; FromRow = 0; ToRow = 3; FromCol = 0; ToCol = 15
        Columns = @(
            @{ columnIndex = 12; columnName = 'Verdict' }
            @{ columnIndex = 13; columnName = 'Category'; columnType = 'DROPDOWN' })
    }
    $result = [pscustomobject]@{
        Id = 'id-result'; Name = 'Fixtureball_DQ_051'; FromRow = 4; ToRow = 8; FromCol = 0; ToCol = 15
        Columns = @(@{ columnIndex = 13; columnName = 'Review Status' })
    }

    $request = New-SheetsValidationClearRequest -Tables @($identity, $result) -Row 0
    Assert-Equal 'id-block' $request.updateTable.table.tableId 'the identity block is the one cleared'
    $columns = @($request.updateTable.table.columnProperties)
    Assert-Equal 2 $columns.Count 'the whole list is resent, because a partial one replaces it'
    Assert-Equal 0 @($columns | Where-Object { $_.columnType }).Count 'with no type left on any of them'
    Assert-Equal 'Category' @($columns | Where-Object { $_.columnIndex -eq 13 })[0].columnName `
        'and the names Sheets holds are kept'

    # Nothing to undo is not a request. A board that never had the defect must not be given a
    # call per tab for it.
    $clean = [pscustomobject]@{
        Id = 'id-clean'; Name = 'DQ_052_Overview'; FromRow = 0; ToRow = 3; FromCol = 0; ToCol = 15
        Columns = @(@{ columnIndex = 13; columnName = 'Category' })
    }
    Assert-Equal $null (New-SheetsValidationClearRequest -Tables @($clean) -Row 0) `
        'a table with no typed column produces nothing'
}

Test-That 'the identity block of a check tab is cleared of rules as well as of column types' {
    # Taking a type off a table does not touch a rule sitting on a cell, and the dropdown
    # reached the block both ways: as a type on whichever table the API listed first, and as a
    # plain rule drawn up the column by the run that created the tab. A board carrying the
    # second kept it through every run that fixed the first.
    $job = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Name = 'CLEARED'; What = ''; Sql = 'SELECT 1;' }
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 1 -Eligible 9 -Verdict 'New'))
    $existing = [pscustomobject]@{
        HasOverviewSheet = $true; HasOverviewHeader = $true; OverviewRowOf = @{}
        EmptyCommentOf = @{}; TabOf = @{}; Titles = @('Overview')
        EmptyTabs = @{}; RowCapacityOf = @{}; SheetIdOf = @{ 'Overview' = 5 }
    }
    $plan = New-SheetsMergePlan -Summary $summary -Existing $existing -OutputFolder 'x' -Collected `
        @([pscustomobject]@{ Job = $job; Rows = @([pscustomobject]@{ check_type = 'X' }) })

    $clear = @($plan.Operations | Where-Object { $_.Kind -eq 'ValidationClear' })
    Assert-Equal 1 $clear.Count 'one clear for the tab'
    Assert-Equal 0 ([int]$clear[0].Row) 'the identity block is still the table it names'
    Assert-Equal 0 ([int]$clear[0].FromRow) 'and the cells run from the top of the tab'
    Assert-Equal 4 ([int]$clear[0].ToRow) 'up to the result header, which keeps its own'
    Assert-True ($clear[0].PSObject.Properties.Name -notcontains 'FromCol') `
        'every column of it: no column of the identity block is a reviewer''s'
}

Test-That 'a word written before the list existed is renamed, never invented' {
    Assert-Equal 'Fixed' (ConvertTo-SheetsReviewStatus -Value 'fixed') 'lower case is what the whole of the existing 610 was typed in'
    Assert-Equal 'No Issue / Change' (ConvertTo-SheetsReviewStatus -Value 'no issue') 'one check said no issue'
    Assert-Equal 'No Issue / Change' (ConvertTo-SheetsReviewStatus -Value 'no change') 'another said no change about the same outcome'
    Assert-Equal 'In Progress' (ConvertTo-SheetsReviewStatus -Value 'In prog') 'an abbreviation is a spelling like any other'
    Assert-Equal 'Fixed' (ConvertTo-SheetsReviewStatus -Value 'Fixed') 'a current value passes through untouched'

    # Guessing which of the three 'not found' meant would be inventing a conclusion rather than
    # recording one. It is left as written and the dropdown flags it, which is how the reviewer
    # gets asked.
    Assert-Equal 'not found' (ConvertTo-SheetsReviewStatus -Value 'not found') 'an undeclared word is left exactly as written'
    Assert-Equal '' (ConvertTo-SheetsReviewStatus -Value '') 'and an empty cell stays empty'
}

Test-That 'a carried note arrives already spelled the way the column offers' {
    # Renamed on the way in, so a cell is not flagged by the same run that introduced the list.
    $header = @('check_type', 'statistic_id')
    $rows = @([pscustomobject]@{ check_type = 'STRAY'; statistic_id = '322012' })
    $notes = @(
        [pscustomobject]@{ Key = (Get-SheetsFindingKey -Row @('STRAY', '322012') -Columns @(0, 1))
            Review = 'no change'; Note = 'the gap is real'
        }
        [pscustomobject]@{ Key = (Get-SheetsFindingKey -Row @('STRAY', '999') -Columns @(0, 1))
            Review = 'fixed'; Note = ''
        }
    )
    $carried = New-SheetsCarriedReview -Header $header -Rows $rows -Was $header -Notes $notes

    Assert-Equal 'No Issue / Change' $carried.Review[0] 'the note put back beside its finding'
    Assert-Equal 'Fixed' $carried.Dropped[0].Review 'and the one written to the log read the same'
}

Test-That 'Review Status is a closed list, coloured, and drawn only over its own column' {
    $job = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Name = 'LIST'; What = ''; Sql = 'SELECT 1;' }
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 1 -Eligible 9 -Verdict 'New'))
    $state = [pscustomobject]@{
        HasOverviewSheet = $true; HasOverviewHeader = $true; OverviewRowOf = @{}
        EmptyCommentOf = @{}; StatusOf = @{}; TabOf = @{ 'Fixtureball-DQ-002' = 'LIST' }
        Titles = @('Overview', 'LIST'); EmptyTabs = @{}
        RowCapacityOf = @{}; SheetIdOf = @{ 'Overview' = 5; 'LIST' = 9 }; SheetIndexOf = @{ 'Overview' = 0 }
        ConditionalFormatsOf = @{ 'LIST' = @(
                # Ours: covers exactly the Review Status column, which lands at index 2.
                [pscustomobject]@{ ranges = @([pscustomobject]@{ startColumnIndex = 2; endColumnIndex = 3 }) }
                # Somebody's own, drawn across the result. Left where it is.
                [pscustomobject]@{ ranges = @([pscustomobject]@{ startColumnIndex = 0; endColumnIndex = 4 }) }
            ) }
    }
    $plan = New-SheetsMergePlan -Summary $summary -Existing $state -OutputFolder 'x' -Collected `
        @([pscustomobject]@{ Job = $job; Rows = @([pscustomobject]@{ check_type = 'X'; event_id = '7' }) })

    $validation = @($plan.Operations | Where-Object { $_.Kind -eq 'Validation' -and $_.Sheet -eq 'LIST' })
    Assert-Equal 1 $validation.Count 'the column carries a dropdown'
    Assert-Equal 3 $validation[0].Column 'at Review Status, right after the two data columns'
    Assert-Equal 'Fixed|No Issue / Change|In Progress' (@($validation[0].Values) -join '|') `
        'offering exactly the declared list'

    $rules = @($plan.Operations | Where-Object { $_.Kind -eq 'FormatRules' -and $_.Sheet -eq 'LIST' })
    Assert-Equal 1 $rules.Count 'and one set of colour bands'
    Assert-Equal 3 $rules[0].Column 'over the same column'
    # From the result header down. The identity block above is a different table, and a band
    # drawn from row 1 would colour cells belonging to neither.
    Assert-Equal $SheetsCheckTabResultRow $rules[0].StartRow 'starting at the result block'
    Assert-Equal '0' (@($rules[0].Drop) -join ',') 'replacing only the rule that covers exactly this column'
    Assert-Equal $SheetsRowReviewBands.Count @($rules[0].Rules).Count 'one band per value'
}

Test-That 'a note written where there was nowhere better is still a note' {
    # Before the reviewer columns existed there was nowhere to put a per-row conclusion, and on
    # Triathlon 388 of them went into eligible_count - the coverage column, overwritten every
    # run. The run that gives the tab somewhere better reads them out of it first.
    $header = @('check_type', 'statistic_id', 'eligible_count')
    $carriedIn = @([pscustomobject]@{
            Key = (Get-SheetsFindingKey -Row @('STRAY', '322012') -Columns @(0, 1))
            Review = 'no issue'; Note = ''
        })
    $rows = @([pscustomobject]@{ check_type = 'STRAY'; statistic_id = '322012'; eligible_count = $null })
    $carried = New-SheetsCarriedReview -Header $header -Rows $rows -Was $header -Notes $carriedIn

    Assert-Equal 'No Issue / Change' $carried.Review[0] 'it survives into the column built for it, in the spelling that column offers'
    Assert-Equal 0 @($carried.Dropped).Count 'and nothing is logged as lost'
}

Test-That 'a first run writes the reviewer columns and logs nothing' {
    $job = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Name = 'FRESH'; What = ''; Sql = 'SELECT 1;' }
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 1 -Eligible 9 -Verdict 'New'))
    $state = [pscustomobject]@{
        HasOverviewSheet = $true; HasOverviewHeader = $true; OverviewRowOf = @{}
        EmptyCommentOf = @{}; StatusOf = @{}; TabOf = @{ 'Fixtureball-DQ-002' = 'FRESH' }
        Titles = @('Overview', 'FRESH'); EmptyTabs = @{}; ConditionalFormatsOf = @{}
        RowCapacityOf = @{}; SheetIdOf = @{ 'Overview' = 5; 'FRESH' = 9 }; SheetIndexOf = @{ 'Overview' = 0 }
    }
    $plan = New-SheetsMergePlan -Summary $summary -Existing $state -OutputFolder 'x' -Collected `
        @([pscustomobject]@{ Job = $job; Rows = @([pscustomobject]@{ check_type = 'X'; event_id = '7' }) })

    $block = @($plan.Operations | Where-Object {
            $_.Kind -eq 'Write' -and $_.Sheet -eq 'FRESH' -and $_.Range -like 'A5:*' })
    Assert-Equal 1 $block.Count 'the result block is written once'
    $header = @($block[0].Values[0])
    Assert-Equal 'check_type event_id Review Status Review Note' ($header -join ' ') `
        'the reviewer columns are appended to what the statement returned'
    Assert-Equal 4 @($block[0].Values[1]).Count 'and every row is as wide as the header'

    # A board nobody has written on yet has nothing to log, and an empty log tab on every one of
    # a hundred documents would be a hundred tabs saying nothing.
    Assert-Equal 0 @($plan.Operations | Where-Object { $_.Sheet -eq $SheetsReviewLogTabName }).Count `
        'and no log tab is created with nothing to put in it'

    $table = @($plan.Operations | Where-Object { $_.Kind -eq 'Table' -and $_.Sheet -eq 'FRESH' })
    $result = @($table | Where-Object { $_.Name -eq 'Fixtureball_DQ_002' })
    Assert-Equal 4 $result[0].ToCol 'the result table covers the reviewer columns too'
}

Test-That 'a note with nowhere to go reaches the log rather than the bin' {
    $job = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Name = 'GONE'; What = ''; Sql = 'SELECT 1;' }
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 1 -Eligible 9 -Verdict 'New'))
    $state = [pscustomobject]@{
        HasOverviewSheet = $true; HasOverviewHeader = $true; OverviewRowOf = @{}
        EmptyCommentOf = @{}; StatusOf = @{}; TabOf = @{ 'Fixtureball-DQ-002' = 'GONE' }
        Titles = @('Overview', 'GONE'); EmptyTabs = @{}; ConditionalFormatsOf = @{}
        RowCapacityOf = @{}; SheetIdOf = @{ 'Overview' = 5; 'GONE' = 9 }; SheetIndexOf = @{ 'Overview' = 0 }
        ResultHeaderOf = @{ 'GONE' = @('check_type', 'event_id', 'Review', 'Review note') }
        ReviewNotesOf = @{ 'GONE' = @([pscustomobject]@{
                    Key = (Get-SheetsFindingKey -Row @('X', '4242') -Columns @(0, 1))
                    Review = 'fixed'; Note = 'corrected in the feed'
                }) }
        ReviewLog = @()
    }
    $plan = New-SheetsMergePlan -Summary $summary -Existing $state -OutputFolder 'x' -Stamp '11.08.2026 09-00-00' `
        -Collected @([pscustomobject]@{ Job = $job; Rows = @([pscustomobject]@{ check_type = 'X'; event_id = '7' }) })

    $write = @($plan.Operations | Where-Object {
            $_.Kind -eq 'Write' -and $_.Sheet -eq $SheetsReviewLogTabName })
    Assert-Equal 1 $write.Count 'the log is written'
    Assert-Equal ($SheetsReviewLogColumns -join ' ') (@($write[0].Values[0]) -join ' ') 'with its header'
    $logged = @($write[0].Values[1])
    Assert-Equal 'Fixtureball-DQ-002' $logged[0] 'the check it belonged to'
    Assert-Equal 'X | 4242' $logged[2] 'the key spelled out so it can be matched by eye'
    Assert-Equal 'fixed' $logged[3] 'what the reviewer had concluded'
    Assert-Equal '11.08.2026 09-00-00' $logged[5] 'and the run that dropped it'

    Assert-Equal 1 @($plan.Operations | Where-Object {
            $_.Kind -eq 'AddSheet' -and $_.Sheet -eq $SheetsReviewLogTabName }).Count 'the tab is created'
}

Test-That 'the log accumulates rather than being replaced by the latest run' {
    $job = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Name = 'KEEP'; What = ''; Sql = 'SELECT 1;' }
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 1 -Eligible 9 -Verdict 'New'))
    $older = [pscustomobject]@{
        'CheckID' = 'Fixtureball-DQ-009'; 'Check tab' = 'OTHER'; 'Finding key' = 'X | 1'
        'Review Status' = 'fixed'; 'Review Note' = ''; 'Dropped on' = '01.08.2026 09-00-00'
        'Why' = 'the finding is no longer in the result'
    }
    $state = [pscustomobject]@{
        HasOverviewSheet = $true; HasOverviewHeader = $true; OverviewRowOf = @{}
        EmptyCommentOf = @{}; StatusOf = @{}; TabOf = @{ 'Fixtureball-DQ-002' = 'KEEP' }
        Titles = @('Overview', 'KEEP', $SheetsReviewLogTabName); EmptyTabs = @{}; ConditionalFormatsOf = @{}
        RowCapacityOf = @{ $SheetsReviewLogTabName = 1000 }
        SheetIdOf = @{ 'Overview' = 5; 'KEEP' = 9; $SheetsReviewLogTabName = 11 }
        SheetIndexOf = @{ 'Overview' = 0 }
        ResultHeaderOf = @{ 'KEEP' = @('check_type', 'event_id', 'Review', 'Review note') }
        ReviewNotesOf = @{ 'KEEP' = @([pscustomobject]@{
                    Key = (Get-SheetsFindingKey -Row @('X', '4242') -Columns @(0, 1))
                    Review = 'no issue'; Note = ''
                }) }
        ReviewLog = @($older)
    }
    $plan = New-SheetsMergePlan -Summary $summary -Existing $state -OutputFolder 'x' -Stamp '11.08.2026 10-00-00' `
        -Collected @([pscustomobject]@{ Job = $job; Rows = @([pscustomobject]@{ check_type = 'X'; event_id = '7' }) })

    $write = @($plan.Operations | Where-Object {
            $_.Kind -eq 'Write' -and $_.Sheet -eq $SheetsReviewLogTabName })
    Assert-Equal 3 @($write[0].Values).Count 'the header, what was there and what this run dropped'
    Assert-Equal 'Fixtureball-DQ-009' @($write[0].Values[1])[0] 'the older entry is kept'

    # A row logged before the vocabulary existed is renamed too. Left alone it keeps the
    # spelling of its own run, so a filter on Fixed misses every row logged earlier - the drift
    # the closed list exists to stop, in the one place nobody would look for it.
    Assert-Equal 'Fixed' @($write[0].Values[1])[3] 'and reads in the spelling the column now offers'
    Assert-Equal 'Fixtureball-DQ-002' @($write[0].Values[2])[0] 'and this run appends under it'
    Assert-Equal 0 @($plan.Operations | Where-Object {
            $_.Kind -eq 'AddSheet' -and $_.Sheet -eq $SheetsReviewLogTabName }).Count `
        'a tab that exists is not added again'
}

Test-That 'a check tab centres everything but the way out, which it widens instead' {
    $job = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Name = 'WIDE'; What = ''; Sql = 'SELECT 1;' }
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 1 -Eligible 9 -Verdict 'New'))
    $state = [pscustomobject]@{
        HasOverviewSheet = $true; HasOverviewHeader = $true; OverviewRowOf = @{}
        EmptyCommentOf = @{}; StatusOf = @{}; TabOf = @{ 'Fixtureball-DQ-002' = 'WIDE' }
        Titles = @('Overview', 'WIDE'); EmptyTabs = @{}; ConditionalFormatsOf = @{}
        RowCapacityOf = @{}; SheetIdOf = @{ 'Overview' = 5; 'WIDE' = 9 }; SheetIndexOf = @{ 'Overview' = 0 }
    }
    $plan = New-SheetsMergePlan -Summary $summary -Existing $state -OutputFolder 'x' `
        -Collected @([pscustomobject]@{ Job = $job; Rows = @([pscustomobject]@{ check_type = 'X' }) })
    $formats = @($plan.Operations | Where-Object { $_.Kind -eq 'Format' -and $_.Sheet -eq 'WIDE' })

    # A3 is the one thing left alone: a link reads as a control only if it starts where the
    # eye already is, so it is widened rather than centred.
    $back = @($formats | Where-Object { $_.FromRow -eq 2 -and $_.FromCol -eq 0 })
    Assert-Equal 'LEFT' $back[0].Align 'the way back stays left'
    Assert-Equal $SheetsLinkColour $back[0].Colour 'in the brighter blue'
    $width = @($plan.Operations | Where-Object {
            $_.Kind -eq 'ColumnWidth' -and $_.Sheet -eq 'WIDE' -and $_.Width -eq $SheetsCheckTabFirstColumnWidth
        })
    Assert-Equal $true ($width.Count -ge 1) 'and its column is widened so it is not clipped'
    Assert-Equal 1 $width[0].From 'column A'

    # The result block under the link is centred with the rest of the tab, and follows it down
    # so a result that grows next week is centred too.
    $columnA = @($formats | Where-Object { $_.FromCol -eq 0 -and $_.Align -eq 'CENTER' })
    Assert-Equal 1 $columnA.Count 'column A is centred below the link'
    Assert-Equal 3 $columnA[0].FromRow 'from the row under it'
    Assert-Equal $null $columnA[0].ToRow 'and following the results down'

    # The three columns that read as sentences range left, header and value together. Centring
    # a sentence puts its first word somewhere different on every tab, and What it does is long
    # enough to be clipped - which centring hides in the middle instead of at the end.
    $ranged = @($formats | Where-Object { $_.Align -eq 'LEFT' -and $_.FromRow -eq 0 })
    Assert-Equal '0 1 3' ((@($ranged | ForEach-Object { $_.FromCol }) | Sort-Object) -join ' ') `
        'Check ID, Check Name and What it does, with SQL Used left centred between them'
    foreach ($one in $ranged) {
        Assert-Equal 2 $one.ToRow 'the heading and the value, and nothing below them'
    }

    # The identity block held still while the results scroll, so the column names stay in view
    # rather than the check's own name, which is on the tab it was reached from anyway.
    $freeze = @($plan.Operations | Where-Object { $_.Kind -eq 'Freeze' -and $_.Sheet -eq 'WIDE' })
    Assert-Equal 1 $freeze.Count 'the tab freezes'
    Assert-Equal $SheetsCheckTabResultRow $freeze[0].Rows 'down to the result header, row 5'

    # C2 is the darker blue: it sits inside the identity row rather than alone on a line.
    $sql = @($formats | Where-Object { $_.FromRow -eq 1 -and $_.Colour -eq $SheetsSqlLinkColour })
    Assert-Equal 1 $sql.Count 'the statement link is darker'
    Assert-Equal 2 $sql[0].FromCol 'at SQL Used, column C'
    Assert-True ([bool]$sql[0].Bold) 'and bold'

    # The identity block is a different kind of thing from the results, so a different colour.
    $tables = @($plan.Operations | Where-Object { $_.Kind -eq 'Table' -and $_.Sheet -eq 'WIDE' })
    $identity = @($tables | Where-Object { $_.Name -eq 'DQ_002_Overview' })
    # The block naming the check recedes; the block holding rows takes the colour every other
    # block of data wears, the board included.
    Assert-Equal $SheetsIdentityHeaderColour $identity[0].HeaderColour 'the identity block recedes into grey'
    $result = @($tables | Where-Object { $_.Name -eq 'Fixtureball_DQ_002' })
    Assert-Equal $SheetsDataHeaderColour $result[0].HeaderColour 'the result block wears the data colour'
    Assert-True ($SheetsIdentityHeaderColour -ne $SheetsDataHeaderColour) 'and the two are not the same'
}

Test-That 'a result column is sized from its own header, and the header row wraps' {
    # Every column of a check tab is centred, so a name wider than its column is clipped at both
    # ends and reads as a different word - 'first_appearance' as 'est_appearai'. The width fits a
    # name of ordinary length and the wrap catches the rest, so neither mechanism has to be right
    # on its own.
    $header = @('id', 'first_appearance', 'deprecated_duration_participant_count')
    $spans = @(Get-SheetsResultColumnWidths -Header $header)

    Assert-Equal 3 $spans.Count 'one span per column where no two agree'
    Assert-Equal $SheetsResultColumnMinWidth $spans[0].Width 'a short name claims the floor, not less'
    Assert-Equal (16 * $SheetsResultColumnCharWidth + $SheetsResultColumnPadding) $spans[1].Width `
        'an ordinary name claims what it needs'
    Assert-Equal $SheetsResultColumnMaxWidth $spans[2].Width 'and the longest is capped rather than let run'

    # Merged, because the API sets a width over a range and most tables repeat a handful of
    # numbers side by side. One request for four columns that agree, not four.
    $same = @(Get-SheetsResultColumnWidths -Header @('aa', 'bb', 'cc', 'dd'))
    Assert-Equal 1 $same.Count 'neighbours that agree are one span'
    Assert-Equal 1 $same[0].From 'from the first'
    Assert-Equal 4 $same[0].To 'to the last'

    # Column A holds the way back to Overview above the results. Its header must not shrink it
    # back under the link the tab was widened for.
    $first = @(Get-SheetsResultColumnWidths -Header @('id', 'id') -FirstColumnWidth 175)
    Assert-Equal 175 $first[0].Width 'column A keeps the width the link needs'
    Assert-Equal $SheetsResultColumnMinWidth $first[1].Width 'and the column beside it does not'

    $job = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-003'; Name = 'HDR'; What = ''; Sql = 'SELECT 1;' }
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-003' -Findings 1 -Eligible 9 -Verdict 'New'))
    $state = [pscustomobject]@{
        HasOverviewSheet = $true; HasOverviewHeader = $true; OverviewRowOf = @{}
        EmptyCommentOf = @{}; StatusOf = @{}; TabOf = @{ 'Fixtureball-DQ-003' = 'HDR' }
        Titles = @('Overview', 'HDR'); EmptyTabs = @{}; ConditionalFormatsOf = @{}
        RowCapacityOf = @{}; SheetIdOf = @{ 'Overview' = 5; 'HDR' = 9 }; SheetIndexOf = @{ 'Overview' = 0 }
    }
    $plan = New-SheetsMergePlan -Summary $summary -Existing $state -OutputFolder 'x' `
        -Collected @([pscustomobject]@{
                Job  = $job
                Rows = @([pscustomobject]@{ check_type = 'X'; distinct_countries = 2 })
            })

    # Only the row the runner writes the column names into. A wrapped value would make one tall
    # row of every finding that holds a long string, and a cell's wrap is the reviewer's.
    $wrap = @($plan.Operations | Where-Object { $_.Kind -eq 'Format' -and $_.Sheet -eq 'HDR' -and $_.Wrap })
    Assert-Equal 1 $wrap.Count 'the header row wraps'
    Assert-Equal 'WRAP' $wrap[0].Wrap 'and says so in the API vocabulary'
    Assert-Equal ($SheetsCheckTabResultRow - 1) $wrap[0].FromRow 'at the result header'
    Assert-Equal $SheetsCheckTabResultRow $wrap[0].ToRow 'and nowhere below it'

    # The reviewer columns are part of the header and get sized with it.
    $widths = @($plan.Operations | Where-Object { $_.Kind -eq 'ColumnWidth' -and $_.Sheet -eq 'HDR' })
    $covered = 0
    foreach ($span in $widths) { if ($span.To -gt $covered) { $covered = $span.To } }
    Assert-Equal 4 $covered 'both projected columns and both reviewer columns are sized'
}

Test-That 'a trend colours each count against the one before it' {
    $points = @(
        [pscustomobject]@{ Value = '10'; Stamp = $null }
        [pscustomobject]@{ Value = '4'; Stamp = $null }
        [pscustomobject]@{ Value = '4'; Stamp = $null }
        [pscustomobject]@{ Value = '9'; Stamp = $null }
    )
    $series = New-TrendSeries -Points $points
    Assert-Equal '10 -> 4 -> 4 -> 9' ($series.Text -replace [regex]::Escape($TrendSeparator), ' -> ') `
        'the series reads forward and ends on today'
    Assert-Equal 'level down level up' (@($series.Runs | ForEach-Object { $_.Direction }) -join ' ') `
        'the first has nothing to be compared against, then down, level, up'

    # Offsets into the string, not into the list of points: a colour is applied by character.
    # '10' at 0, then three characters of separator, so '4' begins at 5.
    Assert-Equal '0 5' (@($series.Runs | Select-Object -First 2 | ForEach-Object { $_.Start }) -join ' ') `
        'each number starts where the text says it does'
    Assert-Equal 2 $series.Runs[0].Length 'and runs as far as its digits'

    # A failed run is not a measurement. 5 then ERR then 3 has gone down by two, and comparing
    # 3 against ERR would let an outage read as progress.
    $withError = New-TrendSeries -Points @(
        [pscustomobject]@{ Value = '5'; Stamp = $null }
        [pscustomobject]@{ Value = 'ERR'; Stamp = $null }
        [pscustomobject]@{ Value = '3'; Stamp = $null })
    Assert-Equal 'level level down' (@($withError.Runs | ForEach-Object { $_.Direction }) -join ' ') `
        'an error takes the level colour and is not what the next point is measured against'
}

Test-That 'the trend cell is written as runs, with the dates between them left plain' {
    $runs = @(
        [pscustomobject]@{ Start = 0; Length = 2; Direction = 'level' }
        [pscustomobject]@{ Start = 20; Length = 1; Direction = 'down' }
    )
    $op = New-SheetsTrendRichText -Sheet 'Overview' -Row 7 -Column 22 -Text ('10 (09.08 10:11) -> 4') -Runs $runs
    Assert-Equal 'RichText' $op.Kind 'the cell carries structure, not just a value'
    Assert-Equal 22 $op.Column 'at Trends'

    # Every coloured number needs a plain run straight after it, or the colour bleeds through
    # the timestamp and the arrow into the next count.
    Assert-Equal 4 @($op.Runs).Count 'two numbers, and a reset after each'
    Assert-Equal '0 2 20 21' (@($op.Runs | ForEach-Object { $_.Start }) -join ' ') 'in ascending order'
    Assert-Equal $true $op.Runs[0].Bold 'the number is bold'
    Assert-Equal $false $op.Runs[1].Bold 'the date after it is not'
    Assert-Equal $null $op.Runs[1].Colour 'and takes no colour of its own'
    Assert-Equal $SheetsTrendColours['down'] $op.Runs[2].Colour 'a fall is green'

    # One point is not a trend, and colouring it would assert a direction nobody measured.
    Assert-Equal $null (New-SheetsTrendRichText -Sheet 'Overview' -Row 7 -Column 22 -Text '3' `
            -Runs @([pscustomobject]@{ Start = 0; Length = 1; Direction = 'level' })) `
        'a series of one is left alone'
    Assert-Equal $null (New-SheetsTrendRichText -Sheet 'Overview' -Row 7 -Column 22 -Text '' -Runs @()) `
        'and so is an empty one'
}

Test-That 'every conditional rule is deleted before any is added, highest index first' {
    # Two columns, each with its own drop list read off the same original rule list. Done a
    # column at a time - delete Rows, add Rows, delete Status - the second set of indexes is
    # already stale, because the first deletion shifted everything under it. That is exactly
    # what happened on a live board: the Rows colouring vanished entirely and three Status
    # rules from the run before were left behind.
    $ops = @(
        [pscustomobject]@{ Kind = 'FormatRules'; Sheet = 'Overview'; Column = 8; Drop = @(6, 7, 8) }
        [pscustomobject]@{ Kind = 'FormatRules'; Sheet = 'Overview'; Column = 9; Drop = @(0, 1, 2, 3, 4, 5) }
    )
    $deletions = @(Get-SheetsRuleDeletions -RuleOps $ops -GidOf @{ 'Overview' = 5 })
    Assert-Equal 9 $deletions.Count 'every rule both columns claim is deleted'
    $order = @($deletions | ForEach-Object { $_.deleteConditionalFormatRule.index })
    Assert-Equal '8 7 6 5 4 3 2 1 0' ($order -join ' ') 'in one descending pass across both columns'
    Assert-Equal 5 $deletions[0].deleteConditionalFormatRule.sheetId 'against the tab that holds them'

    # Nothing to drop on a fresh document, and no request for it.
    $fresh = @(Get-SheetsRuleDeletions -RuleOps @(
            [pscustomobject]@{ Kind = 'FormatRules'; Sheet = 'Overview'; Column = 8; Drop = @() }) -GidOf @{ 'Overview' = 5 })
    Assert-Equal 0 $fresh.Count 'a new document deletes nothing'
}

Test-That 'a dropdown on a table column is set through the table, not through the cells' {
    # Sheets refuses setDataValidation on a column that carries a type inside a table -
    # "This operation is not allowed on cells in typed columns" - and the rejection takes the
    # whole batch with it. Two boards were already in that state, put there by hand, and the
    # run that met them wrote no colours, no values and left the SQL tab broken.
    $validation = [pscustomobject]@{
        Kind = 'Validation'; Sheet = 'Overview'; Column = 9; Name = 'Status'
        Values = @('Not reviewed', 'Clean')
    }
    $tables = @([pscustomobject]@{
            Id = 'BOARD'; Name = 'Overview'; FromRow = 0; ToRow = 99; FromCol = 0; ToCol = 22
            Columns = @(
                [pscustomobject]@{ columnIndex = 7; columnName = 'Rows' }
                [pscustomobject]@{ columnIndex = 8; columnName = 'Status'; columnType = 'DROPDOWN' }
                [pscustomobject]@{ columnIndex = 9; columnName = 'Check By' }
            )
        })

    $sent = New-SheetsValidationRequest -Validation $validation -Tables $tables -SheetId 5
    Assert-True ([bool]$sent.updateTable) 'the table is asked, not the cells'
    Assert-Equal $null $sent.setDataValidation 'setDataValidation would be refused'
    Assert-Equal 'BOARD' $sent.updateTable.table.tableId 'on the table that covers the column'
    Assert-Equal 'columnProperties' $sent.updateTable.fields 'changing only the column list'

    # The whole column list goes back, because a partial one replaces it: sending only Status
    # would drop the names Sheets holds for all the others.
    $columns = @($sent.updateTable.table.columnProperties)
    Assert-Equal 3 $columns.Count 'every column it already had is resent'
    $status = @($columns | Where-Object { $_.columnIndex -eq 8 })
    Assert-Equal 'DROPDOWN' $status[0].columnType 'the typed column keeps its type'
    Assert-Equal 'Not reviewed Clean' (@($status[0].dataValidationRule.condition.values |
            ForEach-Object { $_.userEnteredValue }) -join ' ') 'under this run vocabulary'
    Assert-Equal 'Rows' @($columns | Where-Object { $_.columnIndex -eq 7 })[0].columnName 'and the others are untouched'

    # A table whose column list has no entry for it yet - the state the boards that had no
    # dropdown were in - gains one rather than being left alone.
    $untyped = @([pscustomobject]@{
            Id = 'BOARD'; Name = 'Overview'; FromRow = 0; ToRow = 99; FromCol = 0; ToCol = 22; Columns = @()
        })
    $added = @((New-SheetsValidationRequest -Validation $validation -Tables $untyped -SheetId 5).updateTable.table.columnProperties)
    Assert-Equal 1 $added.Count 'the column is added to the list'
    Assert-Equal 'Status' $added[0].columnName 'under the name the planner gave it'

    # No table over that column: the cells take it directly, as they do on a plain tab.
    $plain = New-SheetsValidationRequest -Validation $validation -Tables @() -SheetId 5
    Assert-True ([bool]$plain.setDataValidation) 'a column outside a table takes it directly'
    Assert-Equal $true $plain.setDataValidation.rule.strict 'and is refused a word nobody declared'
    Assert-Equal 8 $plain.setDataValidation.range.startColumnIndex 'over the column the planner named'
}

Test-That 'the SQL tab is merged, so a narrow run does not delete the rest of the catalogue' {
    # The defect this was written for. The SQL tab is shared - one block per check, and each
    # check tab's C2 points at a row number in it - but it was rewritten from whatever the run
    # held. A run of one check therefore cleared the column, left its own statement alone on
    # it, and pointed every other check's C2 at a blank row. It looked like a working link.
    $job = [pscustomobject]@{
        CheckId = 'Fixtureball-DQ-002'; Name = 'TWO'; What = ''
        Sql     = "SELECT 2 REVISED;`nAND more;"
    }
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 1 -Eligible 9 -Verdict 'New'))
    $existing = [pscustomobject]@{
        HasOverviewSheet = $true; HasOverviewHeader = $true; OverviewRowOf = @{}
        EmptyCommentOf = @{}; StatusOf = @{}
        TabOf = @{ 'Fixtureball-DQ-001' = 'ONE'; 'Fixtureball-DQ-002' = 'TWO'; 'Fixtureball-DQ-003' = 'THREE' }
        Titles = @('Overview', 'SQL', 'ONE', 'TWO', 'THREE'); EmptyTabs = @{}
        RowCapacityOf = @{}; ConditionalFormatsOf = @{}
        SheetIdOf = @{ 'Overview' = 5; 'SQL' = 6; 'ONE' = 7; 'TWO' = 8; 'THREE' = 9 }
        SheetIndexOf = @{ 'Overview' = 0 }
        # Heading row, statement, trailing blank. Three blocks of three rows each.
        SqlBlocks = @(
            [pscustomobject]@{ CheckId = 'Fixtureball-DQ-001'; Row = 1; Lines = @('SELECT 1;', '') }
            [pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Row = 4; Lines = @('SELECT 2;', '') }
            [pscustomobject]@{ CheckId = 'Fixtureball-DQ-003'; Row = 7; Lines = @('SELECT 3;', '') }
        )
    }
    $plan = New-SheetsMergePlan -Summary $summary -Existing $existing -OutputFolder 'x' `
        -Collected @([pscustomobject]@{ Job = $job; Rows = @([pscustomobject]@{ check_type = 'X' }) })

    $block = @($plan.Operations | Where-Object { $_.Kind -eq 'Write' -and $_.Sheet -eq 'SQL' -and $_.Values.Count -gt 1 })
    Assert-Equal 1 $block.Count 'the tab is written as one block'
    $written = @(@($block[0].Values) | ForEach-Object { [string]@($_)[0] })
    Assert-True ($written -contains 'SELECT 1;') 'a check this run did not hold keeps its statement'
    Assert-True ($written -contains 'SELECT 3;') 'and so does the one after it'
    Assert-True ($written -contains 'SELECT 2 REVISED;') 'while the run replaces its own'
    Assert-True ($written -contains 'AND more;') 'with every line of it'
    Assert-Equal 0 @($written | Where-Object { $_ -eq 'SELECT 2;' }).Count 'rather than being added beside the old one'

    # DQ-001 keeps rows 1-3. DQ-002 grew by a line, so DQ-003 slid from row 7 to row 8.
    $backLinks = @($plan.Operations | Where-Object { $_.Kind -eq 'Write' -and $_.Sheet -eq 'SQL' -and $_.Values.Count -eq 1 })
    Assert-Equal 3 $backLinks.Count 'every block keeps a heading, not only this run own'

    $anchorOf = @{}
    foreach ($op in @($plan.Operations | Where-Object { $_.Kind -eq 'Write' -and $_.Range -eq 'C2' })) {
        $anchorOf[[string]$op.Sheet] = [string]$op.Values[0][0]
    }
    Assert-True ($anchorOf.ContainsKey('TWO')) 'the check that ran gets its link'
    Assert-True ($anchorOf['TWO'] -like '*range=A4*') 'pointing at the row its block still starts on'
    # The one that matters: a tab this run never touched, whose block moved under it.
    Assert-True ($anchorOf.ContainsKey('THREE')) 'and so does a check that only shifted'
    Assert-True ($anchorOf['THREE'] -like '*range=A8*') 'pointing at where it moved to'
    Assert-Equal $false ($anchorOf.ContainsKey('ONE')) 'a block that did not move is left alone'
}

Test-That 'Status is a closed vocabulary, and a superseded spelling is renamed to it' {
    # Free text drifted: six boards held nine spellings of five ideas, because the workbook
    # offered one vocabulary, the seeding code wrote a second, and the live board enforced
    # neither. The dropdown closes it; the map below keeps the closing from costing anything.
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 1 -Eligible 9 -Verdict 'New'))
    $existing = [pscustomobject]@{
        HasOverviewSheet = $true; HasOverviewHeader = $true
        OverviewRowOf = @{ 'Fixtureball-DQ-002' = 7; 'Fixtureball-DQ-003' = 8; 'Fixtureball-DQ-004' = 9 }
        StatusOf = @{
            'Fixtureball-DQ-002' = 'No issue'      # superseded
            'Fixtureball-DQ-003' = 'Reviewing'     # already current
            'Fixtureball-DQ-004' = 'Ask Petar'     # nobody declared this one
        }
        EmptyCommentOf = @{}; TabOf = @{}; Titles = @('Overview'); EmptyTabs = @{}
        RowCapacityOf = @{}; SheetIdOf = @{ 'Overview' = 5 }; SheetIndexOf = @{ 'Overview' = 0 }
        ConditionalFormatsOf = @{}
    }
    $plan = New-SheetsMergePlan -Summary $summary -Collected @() -Existing $existing -OutputFolder 'x'

    $validation = @($plan.Operations | Where-Object { $_.Kind -eq 'Validation' })
    Assert-Equal 1 $validation.Count 'the Status column carries a dropdown'
    Assert-Equal 9 $validation[0].Column 'at I'
    Assert-Equal 'Not reviewed Clean Monitor Only Reviewing Completed IT Fix Deprecated' (@($validation[0].Values) -join ' ') `
        'offering exactly the declared outcomes'

    # I7 and nothing else. This is the one place the runner writes into a reviewer's column,
    # and it renames a conclusion rather than forming one.
    $renames = @($plan.Operations | Where-Object { $_.Kind -eq 'Write' -and $_.Sheet -eq 'Overview' -and $_.Range -match '^I\d+$' })
    Assert-Equal 1 $renames.Count 'only the superseded spelling is rewritten'
    Assert-Equal 'I7' $renames[0].Range 'in the row that holds it'
    Assert-Equal 'Clean' $renames[0].Values[0][0] 'under the word that now means it'
}

Test-That 'the Rows cell holds a number, so it sorts and compares as one' {
    # Quoted, it is text: it sorts 1, 10, 2 and a band comparing against 100 never matches it.
    # An errored check has no count to hold and keeps its word, quoted.
    $link = New-SheetsGidLink -Sheet 'TAB' -Text 42
    Assert-True ($link -like '*,42)') 'a count goes in unquoted'
    Assert-True ((New-SheetsGidLink -Sheet 'TAB' -Text 'ERROR') -like '*,"ERROR")') 'a word does not'
}

Test-That 'a plan large enough to threaten the document says so' {
    $job = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Name = 'HUGE'; What = ''; Sql = 'SELECT 1;' }
    $rows = @(1..400 | ForEach-Object { [pscustomobject]@{ a = 1; b = 2; c = 3; d = 4; e = 5 } })
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 400 -Eligible 900 -Verdict 'New'))
    $existing = [pscustomobject]@{
        HasOverviewHeader = $true; OverviewRowOf = @{}; TabOf = @{ 'Fixtureball-DQ-002' = 'HUGE' }
        ResultRowsOf = @{}
    }

    $under = New-SheetsMergePlan -Summary $summary -Collected @([pscustomobject]@{ Job = $job; Rows = $rows }) `
        -Existing $existing -OutputFolder 'x'
    Assert-Equal '' $under.Warning 'an ordinary run says nothing'

    # The threshold is a script variable, so a test can put it below the fixture rather than
    # building a two-thousand-row one to reach eight million cells.
    $keep = $SheetsCellBudgetWarning
    $SheetsCellBudgetWarning = 100
    try {
        $over = New-SheetsMergePlan -Summary $summary -Collected @([pscustomobject]@{ Job = $job; Rows = $rows }) `
            -Existing $existing -OutputFolder 'x'
    }
    finally { $SheetsCellBudgetWarning = $keep }

    Assert-True ($over.Warning -like '*10 000 000*') "the warning should name the real cap; it said '$($over.Warning)'"
    Assert-True ($over.Cells -gt 100) 'and the plan should count what it writes'
}

Test-That 'a tab the document lacks is added before it is written to' {
    $job = [pscustomobject]@{ CheckId = 'Fixtureball-DQ-002'; Name = 'BRAND_NEW'; What = ''; Sql = 'SELECT 1;' }
    $summary = @((New-SheetFixtureEntry -CheckId 'Fixtureball-DQ-002' -Findings 1 -Eligible 9 -Verdict 'New'))
    $existing = [pscustomobject]@{
        HasOverviewHeader = $true; OverviewRowOf = @{}; TabOf = @{}; ResultRowsOf = @{}
    }
    $plan = New-SheetsMergePlan -Summary $summary -Collected `
        @([pscustomobject]@{ Job = $job; Rows = @([pscustomobject]@{ check_type = 'X' }) }) `
        -Existing $existing -OutputFolder 'x'

    $ops = @($plan.Operations)
    $addAt = [array]::IndexOf($ops, @($ops | Where-Object { $_.Kind -eq 'AddSheet' })[0])
    $writeAt = [array]::IndexOf($ops, @($ops | Where-Object { $_.Sheet -eq 'BRAND_NEW' -and $_.Kind -eq 'Write' })[0])
    Assert-True ($addAt -ge 0) 'the tab is added'
    Assert-True ($addAt -lt $writeAt) 'and added before anything is written into it'
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

    # The audited object is the statistic, not the stray participant row. Whoever corrects this
    # works a Comp.Rank table at a time, and the row-level shape repeated one tournament's name
    # up to 54 times for what is one table with one thing wrong with it.
    Assert-True ($branches[0] -match '(?im)^\s*GROUP BY\s+s\.id\s*,') `
        'findings grouped to one row per statistic'
    Assert-True ($branches[1] -match 'COUNT\s*\(\s*DISTINCT\s+s\.id\s*\)\s+AS\s+eligible_count') `
        'coverage must count the same object the findings do'

    # The stray people still travel with the row. Two counts and two lists, because the server
    # caps GROUP_CONCAT at 1024 characters and truncates past it without saying so - the counts
    # are what make a cut list visible.
    foreach ($column in @('stray_participants', 'stray_participant_rows',
            'participant_ids', 'participant_names')) {
        Assert-True ($branches[0] -match [regex]::Escape("AS $column")) "findings carry $column"
    }

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

function Set-FixtureExpectation {
    # Writes an _expected block into a throwaway copy's SPORTS/params.json. The block is the
    # thing under test, so it is injected as text rather than round-tripped through
    # ConvertTo-Json, which would reformat the whole file and hide what changed.
    param([string]$Root, [string]$Sport, [string]$Block)

    $path = Join-Path $Root 'SPORTS\params.json'
    $text = [IO.File]::ReadAllText($path)
    $anchor = '  "{0}": {{' -f $Sport
    $index = $text.IndexOf($anchor)
    if ($index -lt 0) { throw "the $Sport entry was not found in the fixture copy" }

    $insertAt = $index + $anchor.Length
    $text = $text.Insert($insertAt, "`n    `"_expected`": {`n$Block`n    },")
    [IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding $false))
}

Test-That 'an expectation restating the default its signal implies is reported' {
    # The block records exceptions. A value written in two places is a value that can
    # disagree with itself, which is the same reason Actionable is never written down.
    $root = Copy-RepositoryFixture -Name 'expected-restates-default'
    Set-FixtureExpectation -Root $root -Sport 'BMX' -Block @'
      "BMX-DQ-003": {
        "expect": "Zero",
        "reason": "restates what an actionable check already implies"
      }
'@

    $run = Invoke-PackageValidator -Root $root
    Assert-Equal 1 $run.ExitCode 'validator exit code'
    Assert-True ($run.Text -match 'record only the exception') `
        "the restated-default finding should be reported; output was:`n$($run.Text)"
}

Test-That 'a Residual expectation without its count is reported' {
    $root = Copy-RepositoryFixture -Name 'expected-no-residual'
    Set-FixtureExpectation -Root $root -Sport 'BMX' -Block @'
      "BMX-DQ-003": {
        "expect": "Residual",
        "reason": "says some rows stay behind without saying how many"
      }
'@

    $run = Invoke-PackageValidator -Root $root
    Assert-Equal 1 $run.ExitCode 'validator exit code'
    Assert-True ($run.Text -match 'records no residual count') `
        "the missing-count finding should be reported; output was:`n$($run.Text)"
}

Test-That 'an expectation for a check with no Approved row is reported' {
    $root = Copy-RepositoryFixture -Name 'expected-unapproved'
    Set-FixtureExpectation -Root $root -Sport 'BMX' -Block @'
      "BMX-DQ-994": {
        "expect": "Non-zero",
        "reason": "no registry row assigns this CheckID"
      }
'@

    $run = Invoke-PackageValidator -Root $root
    Assert-Equal 1 $run.ExitCode 'validator exit code'
    Assert-True ($run.Text -match 'an expectation describes a check that runs') `
        "the unapproved finding should be reported; output was:`n$($run.Text)"
}

Test-That 'an expectation outside the vocabulary is reported' {
    $root = Copy-RepositoryFixture -Name 'expected-unknown-value'
    Set-FixtureExpectation -Root $root -Sport 'BMX' -Block @'
      "BMX-DQ-003": {
        "expect": "Fewer",
        "reason": "not one of the three the runner can read"
      }
'@

    $run = Invoke-PackageValidator -Root $root
    Assert-Equal 1 $run.ExitCode 'validator exit code'
    Assert-True ($run.Text -match "expects 'Fewer'") `
        "the vocabulary finding should be reported; output was:`n$($run.Text)"
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

Test-That 'a semicolon inside a string literal is reported' {
    # The defect this rule exists for: the HTML-entity patterns ended on a literal ';', the
    # executor cut every one of those statements there, and the whole name-format family -
    # 32 approved checks across six sports - had been dying on an unterminated literal for as
    # long as it had existed. Nothing in the SQL looks wrong to a reader.
    $root = Copy-RepositoryFixture -Name 'literal-semicolon'
    $path = Join-Path $root 'GLOBAL_DQ\HIERARCHY.sql'
    $text = [IO.File]::ReadAllText($path)

    $before = "REGEXP '&(amp|quot|apos|lt|gt|nbsp)\\x{3B}'"
    if (-not $text.Contains($before)) { throw 'the escaped entity pattern was not found in the fixture copy' }
    $text = $text.Replace($before, "REGEXP '&(amp|quot|apos|lt|gt|nbsp);'")
    [IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding $false))

    $run = Invoke-PackageValidator -Root $root
    Assert-Equal 1 $run.ExitCode 'validator exit code'
    Assert-True ($run.Text -match "';' inside a string literal") `
        "the cut finding should be reported; output was:`n$($run.Text)"
}

Test-That 'a semicolon inside a comment is left alone' {
    # The rule must not over-fire: comments are stripped before execution, so a ';' in one is
    # harmless - and the notes explaining this very rule contain one.
    $root = Copy-RepositoryFixture -Name 'comment-semicolon'
    $path = Join-Path $root 'GLOBAL_DQ\HIERARCHY.sql'
    $text = [IO.File]::ReadAllText($path)

    $anchor = '    -- Semicolon as \\x{3B}, never literal: the Pool cuts the statement at the first one.'
    if (-not $text.Contains($anchor)) { throw 'the anchor comment was not found in the fixture copy' }
    $text = $text.Replace($anchor, $anchor + "`n    -- A trailing note ending in a semicolon;")
    [IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding $false))

    $run = Invoke-PackageValidator -Root $root
    Assert-Equal 0 $run.ExitCode "validator exit code; output was:`n$($run.Text)"
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
