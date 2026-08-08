<#
.SYNOPSIS
    Runs registered queries from this repository against the Content Query Builder API.

.DESCRIPTION
    Resolves SQL from CheckIDs (wildcards allowed), a file or a literal string, substitutes
    {{PLACEHOLDER}} parameters, authenticates against the Content Query Builder and posts
    each statement to /api/relation-manager/execute-sql.

    A sport check needs no parameters: POWERBI_QUERIES statements are approved against one
    confirmed sport and carry its ID directly. Only GLOBAL-DISCOVERY statements declare
    {{...}} tokens, filled with -SportId and -Params.

    One CheckID prints to the screen or to -OutFile. Several CheckIDs switch to batch mode:
    one file per check plus a _summary.csv, and a failing check no longer stops the run.
    Files are named after the CheckID, for example BMX-DQ-003.csv. Rows written to a flat
    file carry check_id and check_name as their first two columns.

    -Format xlsx collects a whole batch into a single workbook instead. Its first tab,
    Overview, lists Sport, CheckID, Check Name, What it does, Rows and the Status, Check By and
    Comment fields for every check, with each row count linking to its tab. Signal and Signal
    reason follow, hidden. The check tabs are named after the "-- Name -" header, abbreviated to
    fit Excel's 31-character limit, and there the identity sits above the data rather than on
    every row: row 1 the labels, row 2 the CheckID, the name, the statement that ran as a single
    line and what the check asserts, with empty Comment and Check By cells for the reviewer, row
    3 the link back to Overview, and the result table from row 5. Upload that file to Google
    Drive and open it as Sheets.

    Overview's Comment is a formula reading the check tab's own Comment cell, so the comment is
    written once, beside the rows that provoked it, and read from the board that lists every
    check. The mirror is one-way by necessity: a cell holds a value or a formula and never both,
    so typing into Overview's Comment replaces the link with what was typed and that row stops
    following its tab.

    -Chain carries a discovery batch through its drill-downs. A statement whose parameter has
    to be picked out of a summary is normally skipped; under -Chain the runner reads the
    summary it already ran, takes the values that summary ranks first, and runs the drill-down
    once per value in the same workbook. The value is a sample and the run says so: what was
    not pursued is reported and kept in the Overview.

    A batch is written to survive being cut short. Each statement runs under a wall-clock
    watchdog, so a connection the server half-closes is abandoned as a failed check instead
    of stalling the run, and a workbook is re-written every minute with the checks completed
    so far. Interrupting a run therefore costs at most the last minute of it, not all of it.

    Each run writes into its own folder under "D:\SQL's Output", named for the sport and the
    run time. EP_QB_OUTPUT overrides the root; -OutDir and -OutFile override it entirely.

    Credentials are never stored in this file. They are read from the environment:
        EP_QB_EMAIL     login email
        EP_QB_PASSWORD  login password
        EP_QB_COOKIE    optional, a ready session cookie such as
                        "XSRF-TOKEN=...; content-query-builder-session=..."
        EP_QB_URL       optional, base URL override
    TOOLS\secrets.local.ps1 is dot-sourced when present and may set any of them,
    which keeps them off the command line. It is excluded from git by .gitignore.
    When email or password is missing the script prompts for them interactively.
    The session cookie is cached in %LOCALAPPDATA%\entpulse-qb\session.xml and reused
    until the server rejects it.

.EXAMPLE
    .\TOOLS\Run-Query.ps1 BMX-DQ-003

.EXAMPLE
    .\TOOLS\Run-Query.ps1 BMX-DQ-* -Format xlsx
    Runs the whole BMX catalogue into one workbook under "D:\SQL's Output".

.EXAMPLE
    .\TOOLS\Run-Query.ps1 GLOBAL-DQ-* -Sport BMX -WithPatterns -Format xlsx
    The sport's DQ templates plus every PATTERNS.sql statement whose parameters -Sport can
    supply, in one workbook, so a finding can be read against the names and round types
    actually in use. A drill-down needs a value picked out of a summary and is left out.

.EXAMPLE
    .\TOOLS\Run-Query.ps1 -Sport Triathlon -RunAll
    Every check POWERBI_REGISTRY.md records as Approved for Triathlon, using a sport-authored
    override where its row names one, plus the pattern summaries. Unapproved, blocked and
    deprecated checks do not run.

.EXAMPLE
    .\TOOLS\Run-Query.ps1 GLOBAL-DISCOVERY-* -Sport "Ice Hockey" -Chain -Format xlsx
    The whole discovery catalogue for a sport being opened, drill-downs included: each summary
    feeds the detail statement below it, so one command covers what used to be a batch plus a
    dozen hand-run follow-ups. -ChainTop and -ChainMax set how far it goes.

.EXAMPLE
    .\TOOLS\Run-Query.ps1 BMX-DQ-001,BMX-DQ-002,BMX-DQ-003 -OutDir .\out

.EXAMPLE
    .\TOOLS\Run-Query.ps1 BMX-DQ-* -MaxChecks 5

.EXAMPLE
    .\TOOLS\Run-Query.ps1 GLOBAL-DISCOVERY-015 -SportId 58 -Format csv -OutFile .\out.csv

.EXAMPLE
    .\TOOLS\Run-Query.ps1 -Sql "SELECT COUNT(*) AS c FROM sport;" -Format json
#>
[CmdletBinding()]
param(
    # One or more CheckIDs. Wildcards are allowed: BMX-DQ-*, GLOBAL-*, *
    [Parameter(Position = 0)]
    [string[]]$CheckId,

    [string]$File,

    [string]$Sql,

    # Shorthand for the {{SPORT_ID}} placeholder. GLOBAL statements need it; a sport
    # check carries its own sport ID and ignores it.
    [int]$SportId,

    # Sport name. Discovers the parameters that are structural facts - the sport ID, the
    # statistic type and owner, the physical shard - and fills them in. Statements still
    # needing an investigative selection are reported and skipped rather than guessed.
    [string]$Sport,

    # Explicit repository identity. Use this when the repository slug differs from the
    # database's sport.name; SPORTS.md maps the two. -Sport remains the compatible shorthand
    # and may contain either value for a documented sport.
    [string]$SportSlug,

    # Exact sport.name stored in the database. May be paired with -SportSlug while opening a
    # new sport, before SPORTS.md has a row that can map the two.
    [string]$DatabaseSportName,

    # Remaining placeholders, either NAME=VALUE strings or a hashtable.
    [object]$Params,

    # Narrows the run to these tournament templates by activating the commented template
    # filter POWERBI.md's scope-limiting contract already puts in every branch that has a
    # template relation. A statement carrying no such marker is skipped rather than run
    # wide, because a silently unnarrowed result would be read as the narrow one.
    [int[]]$TemplateIds,

    # Drops the sport-registry branch from a statement that marks one as optional, so the
    # audited people are only those the three participation paths reach. The registry has no
    # template relation and so survives -TemplateIds untouched; without this a narrowed run of
    # such a statement still audits every person registered to the sport. A statement marking
    # no such branch runs unchanged - dropping nothing from it is a no-op, and the run reports
    # which statements were actually trimmed.
    [switch]$WithoutRegistryBranch,

    [ValidateSet('table', 'json', 'csv', 'xlsx')]
    [string]$Format = 'table',

    # Single check, or any number of checks when -Format is xlsx. Otherwise use -OutDir.
    [string]$OutFile,

    # Batch runs write one file per check here. Defaults to output\run_<timestamp>.
    [string]$OutDir,

    # Cap how many of the matched checks actually run. 0 means no cap.
    [int]$MaxChecks,

    # Adds the pattern statements to whatever else the run matched, typically a whole
    # sport's DQ catalogue, so one workbook carries the findings together with the round
    # types and the name patterns they have to be read against.
    [switch]$WithPatterns,

    # One command for a whole sport: every check POWERBI_REGISTRY.md records as Approved for
    # it, plus the pattern statements, collected into one workbook. Needs -Sport. Implies
    # -WithPatterns and -Format xlsx unless a format is given.
    [switch]$RunAll,

    # Runs the drill-downs a discovery batch would otherwise skip, filling each from the
    # summary the statement itself names as its source. Opening a sport stops being a batch
    # followed by a dozen hand-run follow-ups.
    [switch]$Chain,

    # How many values to pursue at each level of the chain: the first entry is how many the
    # summaries feed their details, the second how many a detail one level down is given. A
    # summary orders its rows by frequency, so these are the shapes the sport uses most.
    [int[]]$ChainTop = @(3, 2),

    # The ceiling on chained statements for the whole run. A chain widens as it deepens, and
    # this is what keeps a sport with many result types from turning one command into an
    # afternoon. What it stops is reported, never dropped silently.
    [int]$ChainMax = 40,

    # Turns -RunAll into discovery: run the whole GLOBAL catalogue against the sport whether
    # or not anything is approved for it. This is how an undocumented sport is opened, and
    # the only way to run a template the registry does not authorize. Its output is
    # execution evidence, never a DQ result: nothing it runs has been approved for the sport.
    [switch]$IncludeUnapproved,

    [int]$Preview = 50,

    [switch]$DryRun,

    [switch]$ListChecks,

    # Prints the full command set. The cqb wrapper maps a bare "info" onto this.
    [switch]$Info,

    [switch]$Relogin,

    # Keep this run out of RUNS/<Sport>.json. An experiment, a re-run of one check to see
    # whether it still errors, a narrowed run that is not the sport's periodic pass - none of
    # those should sit in the history the next run compares itself against.
    [switch]$NoLedger,

    # Dot-source the file for its functions and stop before Main. TOOLS/Test-Tools.ps1 uses
    # it to exercise selection, parameter expansion, the parser and the workbook writer
    # without a login or a statement. Nothing in a normal run passes it.
    [switch]$DotSourceOnly
)

$ErrorActionPreference = 'Stop'

# What the run was aimed at, which a GLOBAL CheckID cannot say for itself. Main resolves this
# to the repository slug before any output is built. Read by Get-SportFromCheckId for the
# workbook's Sport column and the run folder name.
$script:RunSportName = ''

# When this invocation began, stamped once so every ledger entry a run writes carries the
# same moment however long the run took. UTC because the ledger is tracked in git and read on
# more than one machine; the run folder keeps the local time a person recognises.
$script:RunStartedUtc = (Get-Date).ToUniversalTime()

# Every choice the run made for itself, and every one it left open. A run decides some things
# by itself - the busiest statistic type, the values a chain pursues - and defers others, and
# both are only honest while they stay execution output. The moment one is copied into
# SPORTS/params.json it is read by every later run as confirmed evidence, and a heuristic
# recorded there is indistinguishable from a fact somebody checked.
#
# So the run writes them down where they can be answered rather than leaving them as console
# prose somebody has to notice: a Decisions tab beside the Overview and a _decisions.json next
# to it. WORKFLOW.md's evidence gate and the new-sport skill's stage 2b own what must happen to
# them before anything is recorded; this only makes sure the list exists.
$script:RunDecision = @()

function Add-RunDecision {
    # Alternatives are read from the run's own output, never invented: an option nobody can act
    # on is worse than none, because it reads as a choice that was available.
    param(
        [string]$Kind,
        [string]$Subject,
        [string]$Chose,
        [string]$Why,
        [string[]]$Alternatives
    )

    $script:RunDecision += [pscustomobject]@{
        Decision     = $Kind
        Subject      = $Subject
        'Run chose'  = $Chose
        Why          = $Why
        Alternatives = (@($Alternatives) -join '; ')
        Answer       = ''
    }
}

# Local, git-ignored credential file. Loaded before anything reads EP_QB_*, so it
# can supply the login, a session cookie or a different base URL.
$SecretsPath = Join-Path $PSScriptRoot 'secrets.local.ps1'
if (Test-Path $SecretsPath) { . $SecretsPath }

$BaseUrl = $env:EP_QB_URL
if ([string]::IsNullOrWhiteSpace($BaseUrl)) { $BaseUrl = 'http://spcdev.enetpulse.com:19080' }
$BaseUrl = $BaseUrl.TrimEnd('/')

$ExecuteUrl = "$BaseUrl/api/relation-manager/execute-sql"
$LoginUrl = "$BaseUrl/login"
$LoginPageUrl = "$BaseUrl/app/pool"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$StateDir = Join-Path $env:LOCALAPPDATA 'entpulse-qb'
$StatePath = Join-Path $StateDir 'session.xml'

# Results land outside the working copy. EP_QB_OUTPUT overrides the default; a machine
# without that drive falls back into the repository, which .gitignore already excludes.
$OutputRoot = $env:EP_QB_OUTPUT
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = "D:\SQL's Output"
    $drive = (Split-Path -Qualifier $OutputRoot) + '\'
    if (-not (Test-Path $drive)) { $OutputRoot = Join-Path $RepoRoot 'output' }
}

# Where the run's own history lives. RUNS/<Sport>.json holds one entry per run per statement:
# the row count, the findings, the eligible population and the expectation each was read
# against. It exists because a re-run after colleagues have corrected the data is otherwise
# read against a memory of the last one, and a memory does not survive fifty checks.
#
# Unlike everything else a run writes, this is inside the working copy and tracked in git.
# The history is the point, and a file under the output root has none: it is per-machine,
# unbacked and invisible to anyone else. That places it next to a rule it must not be
# mistaken for. CLAUDE.md is explicit that results are execution output and never evidence,
# and that stands unchanged - the ledger records what a run returned and what a reviewer said
# about it, and neither becomes a structural finding except through PREPARE_DOC_UPDATE.
$LedgerDirName = 'RUNS'
$LedgerVersion = 1

# How far the audited population may move before a raw finding delta stops being comparable.
# The database is corrected while it is being read, so small drift is the normal state and
# flagging it would make the column noise; a population that moved by more than this makes
# "was 40, now 3" a statement about two different scopes rather than about the data.
$LedgerEligibleDriftPct = 5

# How far the finding rate may move on a check whose findings are population-wide before the
# run calls it a change rather than the same picture. Wider than the drift threshold on
# purpose: a proportion bounces where a population does not.
$LedgerRateMovePct = 10

# What the previous run recorded for each statement, read once before the batch starts. A
# lookup rather than a file read per check, and settled before this run appends its own entry
# so nothing can compare itself against itself.
$script:PreviousRun = @{}

# Small pause between statements in a batch, so a long catalogue does not hammer the API.
$BatchDelayMs = 250

# How long a single statement may take before the runner stops waiting for it. The first
# value is what the HTTP stack is told; the second is the wall clock the watchdog holds it
# to, because -TimeoutSec has been observed not to fire at all when the server half-closes
# the connection instead of answering. The grace between them lets a request that is merely
# slow fail with the server's own message rather than as an abandoned one.
$StatementTimeoutSec = 300
$WatchdogGraceSec = 30

# An abandoned request keeps its connection until the process exits, and the default limit
# of two per endpoint would let a couple of them stall every statement that follows.
[Net.ServicePointManager]::DefaultConnectionLimit = 64

# How often a batch writing a workbook re-writes it with the checks completed so far.
# Rebuilding costs real time on a large catalogue, so this trades a bounded slowdown for
# never losing more than this much of a run.
$SnapshotIntervalSec = 60

# Hoisted out of the cell writer, which runs once per cell across thousands of rows.
$XlsxNumericTypes = @([int], [long], [double], [decimal], [single], [int16], [uint16], [uint32], [uint64], [byte], [sbyte])
$XlsxInvariant = [Globalization.CultureInfo]::InvariantCulture
$XlsxCellLimit = 32767

# --------------------------------------------------------------------------------------
# Query resolution
# --------------------------------------------------------------------------------------

function Get-QuerySourceFiles {
    $dirs = @(
        (Join-Path $RepoRoot 'GLOBAL_QUERIES'),
        (Join-Path $RepoRoot 'GLOBAL_DQ'),
        (Join-Path $RepoRoot 'POWERBI_QUERIES')
    )
    $files = @()
    foreach ($d in $dirs) {
        if (Test-Path $d) {
            $files += Get-ChildItem -Path $d -Filter *.sql -File
        }
    }
    return $files
}

function Get-CheckCatalogue {
    # Every registered check, with the SQL body attached. Statements are separated by the
    # "-- ====..." banner lines used across the repo.
    $catalogue = @()

    foreach ($f in Get-QuerySourceFiles) {
        $raw = Get-Content -LiteralPath $f.FullName -Raw

        # CheckID -> line number, so -ListChecks can point straight at the source.
        $lineOf = @{}
        $n = 0
        foreach ($line in ($raw -split "\r?\n")) {
            $n++
            $m = [regex]::Match($line, '^\s*--\s*CheckID\s*[-:]\s*(\S+)\s*$')
            if ($m.Success -and -not $lineOf.ContainsKey($m.Groups[1].Value)) {
                $lineOf[$m.Groups[1].Value] = $n
            }
        }

        foreach ($block in [regex]::Split($raw, '(?m)^--\s*={10,}\s*\r?$')) {
            $idMatch = [regex]::Match($block, '(?m)^\s*--\s*CheckID\s*[-:]\s*(\S+)\s*$')
            if (-not $idMatch.Success) { continue }

            $id = $idMatch.Groups[1].Value
            $nameMatch = [regex]::Match($block, '(?m)^\s*--\s*Name\s*[-:]\s*(.+?)\s*$')
            # The third identity comment. Carried through the run so the workbook can say
            # what a check asserts beside what it found, rather than sending the reader
            # back to the registry to look it up.
            $whatMatch = [regex]::Match($block, '(?m)^\s*--\s*What it does:\s*(.+?)\s*$')

            $catalogue += [pscustomobject]@{
                CheckId = $id
                Name    = $(if ($nameMatch.Success) { $nameMatch.Groups[1].Value } else { '' })
                What    = $(if ($whatMatch.Success) { $whatMatch.Groups[1].Value } else { '' })
                File    = $f.Name
                Line    = $(if ($lineOf.ContainsKey($id)) { $lineOf[$id] } else { 0 })
                Path    = $f.FullName
                Sql     = $block.Trim()
            }
        }
    }

    return $catalogue
}

function Select-Checks {
    param([string[]]$Patterns)

    $catalogue = Get-CheckCatalogue
    $selected = @()

    foreach ($pattern in $Patterns) {
        $hits = @($catalogue | Where-Object { $_.CheckId -like $pattern } | Sort-Object CheckId)
        if ($hits.Count -eq 0) {
            throw "No CheckID matches '$pattern'. Use -ListChecks to see available IDs."
        }
        $selected += $hits
    }

    # A CheckID living in two files is a repository error, not something to guess about.
    $duplicate = $selected | Group-Object CheckId | Where-Object { $_.Count -gt 1 } | Select-Object -First 1
    if ($duplicate) {
        $where = ($duplicate.Group | ForEach-Object { $_.File } | Select-Object -Unique) -join ', '
        if (($duplicate.Group | ForEach-Object { $_.File } | Select-Object -Unique).Count -gt 1) {
            throw "CheckID '$($duplicate.Name)' is ambiguous, found in: $where"
        }
    }

    # Overlapping patterns must not run the same check twice.
    $seen = @{}
    $unique = @()
    foreach ($check in $selected) {
        if (-not $seen.ContainsKey($check.CheckId)) {
            $seen[$check.CheckId] = $true
            $unique += $check
        }
    }

    # No comma wrapper here: the caller re-wraps with @(), and the two together nest.
    return $unique
}

function Get-RegistryRow {
    # POWERBI_REGISTRY.md as objects. The registry is the authorization record: a template
    # becomes a check for a sport when that sport has a row for it, and not before.
    # POWERBI.md owns that rule; this only reads it.
    param([string]$SportName)

    $path = Join-Path $RepoRoot 'POWERBI_REGISTRY.md'
    if (-not (Test-Path -LiteralPath $path)) {
        throw "POWERBI_REGISTRY.md not found under $RepoRoot. -RunAll selects from it."
    }

    $rows = @()
    foreach ($line in (Get-Content -LiteralPath $path -Encoding UTF8)) {
        if ($line -notmatch '^\s*\|') { continue }
        $cells = @(($line.Trim() -replace '^\|', '' -replace '\|\s*$', '') -split '\|' |
            ForEach-Object { ($_ -replace '`', '').Trim() })
        if ($cells.Count -ne 8) { continue }
        if ($cells[0] -notmatch '^\S+-DQ-\d+$') { continue }
        if ($SportName -and $cells[1] -ne $SportName) { continue }

        $rows += [pscustomobject]@{
            CheckId   = $cells[0]
            Sport     = $cells[1]
            Family    = $cells[2]
            Category  = $cells[3]
            Object    = $cells[4]
            Name      = $cells[5]
            QueryFile = $cells[6]
            Status    = $cells[7]
        }
    }
    return $rows
}

function ConvertTo-SportSlug {
    # SPORTS.md owns the slug rule. This is only the fallback for a sport not documented
    # there yet; a recorded mapping always wins.
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) { return '' }

    $decomposed = $Name.Normalize([Text.NormalizationForm]::FormD)
    $builder = New-Object Text.StringBuilder
    foreach ($character in $decomposed.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($character) -ne
            [Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$builder.Append($character)
        }
    }

    $ascii = $builder.ToString().Normalize([Text.NormalizationForm]::FormC)
    $slug = [regex]::Replace($ascii.Trim(), '\s+', '-')
    $slug = [regex]::Replace($slug, '[^A-Za-z0-9.\-]', '')
    return $slug.Trim('-')
}

function Get-SportIndexEntry {
    # The index owns the mapping between a stable repository slug and the exact database
    # sport.name. The database-name column was appended so the original column positions stay
    # compatible with older readers of SPORTS.md.
    $path = Join-Path $RepoRoot 'SPORTS.md'
    if (-not (Test-Path -LiteralPath $path)) { return @() }

    $entries = @()
    foreach ($line in (Get-Content -LiteralPath $path -Encoding UTF8)) {
        if ($line -notmatch '^\s*\|\s*\d+\s*\|') { continue }
        $cells = @(($line.Trim() -replace '^\|', '' -replace '\|\s*$', '') -split '\|' |
            ForEach-Object { ($_ -replace '`', '').Trim() })
        if ($cells.Count -lt 2) { continue }

        $slug = $cells[1]
        # Six-column indexes predate the explicit mapping. They remain readable, with the
        # historical assumption that slug and database name were the same.
        $databaseName = if ($cells.Count -ge 7 -and -not [string]::IsNullOrWhiteSpace($cells[6])) {
            $cells[6]
        }
        else { $slug }

        $entries += [pscustomobject]@{
            SportId     = [int]$cells[0]
            Slug        = $slug
            DatabaseName = $databaseName
        }
    }
    return $entries
}

function Resolve-SportIdentity {
    # Keep -Sport compatible while separating the two identities it used to conflate. For a
    # documented sport it may be either the slug or the exact DB name. The explicit pair is
    # useful before a new sport has an index row.
    param(
        [string]$SportValue,
        [string]$SportSlugValue,
        [string]$DatabaseSportNameValue
    )

    if (-not [string]::IsNullOrWhiteSpace($SportValue) -and
        (-not [string]::IsNullOrWhiteSpace($SportSlugValue) -or
         -not [string]::IsNullOrWhiteSpace($DatabaseSportNameValue))) {
        throw '-Sport is the compatible shorthand; do not combine it with -SportSlug or -DatabaseSportName.'
    }

    if ([string]::IsNullOrWhiteSpace($SportValue) -and
        [string]::IsNullOrWhiteSpace($SportSlugValue) -and
        [string]::IsNullOrWhiteSpace($DatabaseSportNameValue)) {
        return $null
    }

    $entries = @(Get-SportIndexEntry)
    $matches = @()

    if (-not [string]::IsNullOrWhiteSpace($SportValue)) {
        $matches = @($entries | Where-Object {
                $_.Slug -ieq $SportValue -or $_.DatabaseName -ieq $SportValue
            })
    }
    else {
        $matches = @($entries | Where-Object {
                ([string]::IsNullOrWhiteSpace($SportSlugValue) -or $_.Slug -ieq $SportSlugValue) -and
                ([string]::IsNullOrWhiteSpace($DatabaseSportNameValue) -or $_.DatabaseName -ieq $DatabaseSportNameValue)
            })

        # A supplied pair that points at two different documented rows is an error worth
        # naming, not an undocumented sport to derive afresh.
        $slugMatch = @($entries | Where-Object { $_.Slug -ieq $SportSlugValue })
        $databaseMatch = @($entries | Where-Object { $_.DatabaseName -ieq $DatabaseSportNameValue })
        if ($SportSlugValue -and $DatabaseSportNameValue -and
            (($slugMatch.Count -gt 0 -and $slugMatch[0].DatabaseName -ine $DatabaseSportNameValue) -or
             ($databaseMatch.Count -gt 0 -and $databaseMatch[0].Slug -ine $SportSlugValue))) {
            throw "Sport identity '$SportSlugValue' / '$DatabaseSportNameValue' contradicts the mapping in SPORTS.md."
        }
    }

    $matches = @($matches | Group-Object Slug | ForEach-Object { $_.Group[0] })
    if ($matches.Count -gt 1) {
        throw "Sport identity is ambiguous in SPORTS.md; pass both -SportSlug and -DatabaseSportName."
    }
    if ($matches.Count -eq 1) {
        return [pscustomobject]@{
            Slug         = $matches[0].Slug
            DatabaseName = $matches[0].DatabaseName
            SportId      = $matches[0].SportId
            Documented   = $true
        }
    }

    $databaseName = if ($DatabaseSportNameValue) { $DatabaseSportNameValue } else { $SportValue }
    $slug = if ($SportSlugValue) { $SportSlugValue } else { ConvertTo-SportSlug -Name $databaseName }
    if ([string]::IsNullOrWhiteSpace($databaseName)) { $databaseName = $slug }

    if ([string]::IsNullOrWhiteSpace($slug) -or $slug -cnotmatch '^[A-Za-z0-9.\-]+$') {
        throw "Repository sport slug '$slug' is invalid; use only A-Z, a-z, 0-9, period and hyphen."
    }

    return [pscustomobject]@{
        Slug         = $slug
        DatabaseName = $databaseName
        SportId      = $null
        Documented   = $false
    }
}

function Test-SportDocumented {
    # -IncludeUnapproved is an opening workflow, not an authorization override. Fail closed
    # if any repository surface already knows the slug, even when the package is temporarily
    # inconsistent and one of the other surfaces is missing.
    param([string]$SportSlugValue)

    if (@(Get-SportIndexEntry | Where-Object { $_.Slug -ieq $SportSlugValue }).Count -gt 0) { return $true }
    if (Test-Path -LiteralPath (Join-Path $RepoRoot "SPORTS\$SportSlugValue.md")) { return $true }
    if (Test-Path -LiteralPath (Join-Path $RepoRoot "POWERBI_QUERIES\$SportSlugValue.sql")) { return $true }

    $registryPath = Join-Path $RepoRoot 'POWERBI_REGISTRY.md'
    if (Test-Path -LiteralPath $registryPath) {
        if (@(Get-RegistryRow -SportName $SportSlugValue).Count -gt 0) { return $true }
    }

    $paramsPath = Join-Path $RepoRoot 'SPORTS\params.json'
    if (Test-Path -LiteralPath $paramsPath) {
        try {
            $params = Get-Content -LiteralPath $paramsPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if (@($params.PSObject.Properties | Where-Object { $_.Name -ieq $SportSlugValue }).Count -gt 0) {
                return $true
            }
        }
        catch {
            # An unreadable documentation surface is not proof that a sport is new. The
            # package validator will give the detailed JSON error.
            return $true
        }
    }
    return $false
}

function Select-RunAllChecks {
    # What "-RunAll -Sport X" means: every check POWERBI_REGISTRY.md records as Approved for
    # that sport, run through the statement its Query file names, and carrying its own
    # CheckID rather than the template's.
    #
    # Selected from the registry rather than from the .sql files, because the files hold the
    # whole GLOBAL catalogue and a template is not a check for a sport until that sport has
    # a row for it. Selecting from the files instead runs three kinds of statement nobody
    # asked for: templates never approved for this sport, the generic version of a template
    # the sport has replaced with its own statement, and a check whose row is Deprecated.
    #
    # Returns the jobs together with what was left out, so the caller can say so rather than
    # leave a shorter run unexplained.
    param($Catalogue, [string]$SportName, [switch]$IncludeUnapproved)

    $byId = @{}
    foreach ($entry in $Catalogue) { $byId[$entry.CheckId] = $entry }

    $templateIds = @($Catalogue | Where-Object { $_.CheckId -like 'GLOBAL-DQ-*' } |
        ForEach-Object { $_.CheckId } | Sort-Object)

    if ($IncludeUnapproved) {
        if (Test-SportDocumented -SportSlugValue $SportName) {
            throw ("-IncludeUnapproved is only for a genuinely undocumented sport. '$SportName' " +
                'already exists in the repository, so its registry approvals, blocked signals and deprecated rows must remain authoritative.')
        }

        # An undocumented sport has no rows yet, and running the catalogue against it is how
        # it gets opened. That is discovery, not a DQ run: nothing here is approved for the
        # sport, and WORKFLOW.md's sequence still has to be followed before anything is.
        $jobs = @($Catalogue |
            Where-Object { $_.CheckId -like 'GLOBAL-DQ-*' -or $_.CheckId -like "$SportName-DQ-*" } |
            Sort-Object CheckId)

        return [pscustomobject]@{
            Jobs             = $jobs
            Unapproved       = $true
            DeprecatedIds    = @()
            NotApprovedIds   = @()
            BlockedFamilies  = @()
            Classified       = @()
            MissingStatement = @()
        }
    }

    $signals = Get-SportCheckSignal -SportName $SportName

    $rows = @(Get-RegistryRow -SportName $SportName)
    if ($rows.Count -eq 0) {
        throw ("No POWERBI_REGISTRY.md row names the sport '$SportName', so nothing is approved to run. " +
            "Sport names are exact and case-sensitive. To run the GLOBAL catalogue against an " +
            "undocumented sport as discovery, pass -IncludeUnapproved.")
    }

    $approved = @($rows | Where-Object { $_.Status -eq 'Approved' })
    $deprecated = @($rows | Where-Object { $_.Status -eq 'Deprecated' })

    $jobs = @()
    $missing = @()
    foreach ($row in ($approved | Sort-Object CheckId)) {
        # The Query file decides which statement runs. A GLOBAL_DQ path means the row is an
        # instantiation of its Family; anything else means the sport authored its own, and
        # then the row's own CheckID names the statement.
        $wanted = if ($row.QueryFile -like 'GLOBAL_DQ/*') { $row.Family } else { $row.CheckId }

        if (-not $byId.ContainsKey($wanted)) {
            $missing += "$($row.CheckId): $($row.QueryFile) names $wanted, which is not in the catalogue"
            continue
        }

        $statement = $byId[$wanted]

        # A classification may be recorded against the template the row instantiates or
        # against the row's own CheckID, whichever names the check for this sport.
        $signal = $null
        foreach ($key in @($row.Family, $row.CheckId)) {
            if ($key -and $signals.ContainsKey($key)) { $signal = $signals[$key]; break }
        }

        # The row's CheckID travels with the result, not the template's. POWERBI_REGISTRY.md
        # makes the CheckID the stable identifier for PowerBI and any external report, and
        # two sports instantiating one template would otherwise both report the template ID.
        $jobs += [pscustomobject]@{
            CheckId      = $row.CheckId
            Name         = $statement.Name
            What         = $statement.What
            File         = $statement.File
            Line         = $statement.Line
            Path         = $statement.Path
            Sql          = $statement.Sql
            Template     = $(if ($wanted -eq $row.CheckId) { '' } else { $wanted })
            Category     = $row.Category
            Signal       = $(if ($signal) { $signal.Signal } else { 'Actionable' })
            SignalReason = $(if ($signal) { $signal.Reason } else { '' })
        }
    }

    $approvedFamilies = @($approved | ForEach-Object { $_.Family } | Where-Object { $_ -like 'GLOBAL-DQ-*' })
    $notApproved = @($templateIds | Where-Object { $approvedFamilies -notcontains $_ })

    # A template this sport is documented as unable to use yet, with the reason. Reported
    # rather than merely absent, so a shorter run does not read as an oversight.
    $blocked = @($notApproved |
        Where-Object { $signals.ContainsKey($_) -and $signals[$_].Signal -eq 'Blocked' } |
        ForEach-Object { [pscustomobject]@{ Family = $_; Reason = $signals[$_].Reason } })

    # Checks that are running and whose findings are documented as something other than
    # defects. Named before the run rather than left for the reader to rediscover from the
    # workbook, which is where the sport file's conclusion went unread until now.
    $classified = @($jobs | Where-Object { $_.Signal -ne 'Actionable' })

    return [pscustomobject]@{
        Jobs             = @($jobs)
        Unapproved       = $false
        DeprecatedIds    = @($deprecated | ForEach-Object { $_.CheckId })
        NotApprovedIds   = $notApproved
        BlockedFamilies  = $blocked
        Classified       = $classified
        MissingStatement = $missing
    }
}

function ConvertTo-ParamTable {
    # Accepts @{ SPORT_ID = 58 } as well as the friendlier SPORT_ID=58,FROM_ID=100 form.
    param($Value)

    $table = @{}
    if ($null -eq $Value) { return $table }

    if ($Value -is [hashtable]) {
        foreach ($key in $Value.Keys) { $table[[string]$key] = $Value[$key] }
        return $table
    }

    foreach ($item in @($Value)) {
        $text = [string]$item
        if ([string]::IsNullOrWhiteSpace($text)) { continue }

        # An unquoted -Params SPORT_ID=58,SHARD_ID=11 is split into an array by PowerShell
        # before it ever arrives, but a quoted one arrives whole and would otherwise be read
        # as SPORT_ID = "58,SHARD_ID=11" - wrong, and silently so. Splitting here as well
        # makes the documented form behave the same either way. A comma inside a value is
        # left alone, because the split only stands when every piece is itself a NAME=VALUE.
        $pieces = @($text)
        if ($text.Contains(',')) {
            $candidate = @($text -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
            $allNamed = @($candidate | Where-Object { $_.IndexOf('=') -gt 0 }).Count -eq $candidate.Count
            if ($candidate.Count -gt 1 -and $allNamed) { $pieces = $candidate }
        }

        foreach ($piece in $pieces) {
            $split = $piece.IndexOf('=')
            if ($split -lt 1) {
                throw "Cannot read parameter '$piece'. Use NAME=VALUE, for example -Params SPORT_ID=58"
            }
            $table[$piece.Substring(0, $split).Trim()] = $piece.Substring($split + 1).Trim()
        }
    }

    return $table
}

function Get-SqlEscaped {
    # A value going between SQL quotes. String.Replace rather than -replace: the replacement
    # side of -replace is a regex replacement string, where '\\\\' is four literal characters
    # and doubles one backslash into four rather than two. Nothing in the package has carried a
    # backslash so far, so the older form worked by never being tested; a name pattern comes
    # straight out of the data and can.
    param([string]$Text)

    return $Text.Replace('\', '\\').Replace("'", "''")
}

function Get-MissingPlaceholders {
    param([string]$Text, [hashtable]$Values)

    return @([regex]::Matches($Text, '\{\{\s*(\w+)\s*\}\}') |
        ForEach-Object { $_.Groups[1].Value } |
        Where-Object { -not $Values.ContainsKey($_) } |
        Select-Object -Unique)
}

# --------------------------------------------------------------------------------------
# Chaining
#
# A drill-down does not invent the value it needs. GLOBAL_QUERIES already authors the source
# on the placeholder's own line, in one of two forms that say the same thing:
#
#   AND r.result_typeFK = {{RESULT_TYPE_ID}}  -- select result_type_id from GLOBAL-DISCOVERY-007 (...)
#   -- {{ROUND_TYPE_ID}}: select round_type_id from GLOBAL-DISCOVERY-018 (...)
#
# So the feed is a repository fact like every other, read rather than inferred, and a statement
# added later chains on its own declaration without a pairing table here to keep in step.
# GLOBAL_QUERIES/README.md owns the declaration; this only reads it.
#
# What chaining adds is that the value is taken automatically: the rows the feeder itself ranks
# first, which every summary in the catalogue orders by frequency. That makes a chained result a
# sample of the busiest shapes, never coverage - so the values not pursued are reported and kept
# in the workbook rather than left for the reader to infer from a tab count.
#
# A source wider than its consumer says so, with a trailing "where <column> = <value>":
#
#   -- select statistic_data_type_id from GLOBAL-DISCOVERY-017 (...) where storage_layer = statistic_data{{SHARD_ID}}
#
# GLOBAL-DISCOVERY-017 inventories the config layer beside the data shard and orders by storage
# layer first, so statistic_config always leads whatever the counts are, while GLOBAL-DISCOVERY-028
# reads the data shard alone. Without the filter the chain feeds it field types that layer cannot
# hold, every one comes back empty, and the drill-down below them never runs at all - which is
# what happened on Modern Pentathlon before this existed.
#
# Note what the filter is not: a way to pick better values. It is the consumer stating which of
# its source's rows are about the thing it reads, which no ordering could have supplied.
# --------------------------------------------------------------------------------------

# The filter is optional and reads the same in both declaration forms.
$ChainDeclarationFilter = '(?:[ \t]+where[ \t]+(?<filter>\w+)[ \t]*=[ \t]*(?<value>[^\r\n]+?)[ \t]*(?=$|\r))?'

$ChainOwnLineDeclaration =
'(?m)^[ \t]*--[ \t]*\{\{[ \t]*(?<name>\w+)[ \t]*\}\}[ \t]*:[ \t]*select[ \t]+(?<column>\w+)[ \t]+from[ \t]+(?<check>GLOBAL-DISCOVERY-\d+)(?:[ \t]*\([^)\r\n]*\))?' +
$ChainDeclarationFilter

$ChainInlineDeclaration =
'(?m)^(?<sql>[^\r\n]*\{\{[ \t]*\w+[ \t]*\}\}[^\r\n]*?)--[ \t]*select[ \t]+(?<column>\w+)[ \t]+from[ \t]+(?<check>GLOBAL-DISCOVERY-\d+)(?:[ \t]*\([^)\r\n]*\))?' +
$ChainDeclarationFilter

function New-DeclaredFeeder {
    param($Match)

    $filter = $null
    if ($Match.Groups['filter'].Success) {
        $filter = [pscustomobject]@{
            Column = $Match.Groups['filter'].Value
            Value  = $Match.Groups['value'].Value.Trim()
        }
    }

    return [pscustomobject]@{
        Column  = $Match.Groups['column'].Value
        CheckId = $Match.Groups['check'].Value
        Filter  = $filter
    }
}

function Get-DeclaredFeeder {
    # Which statement supplies each placeholder, under which column name, and which of its rows
    # are the ones to read. The own-line form is read first because it names its placeholder
    # explicitly; the inline form takes the last placeholder standing before the comment, which
    # is the one the comment sits on.
    param([string]$Text)

    $declared = @{}

    foreach ($match in [regex]::Matches($Text, $ChainOwnLineDeclaration)) {
        $name = $match.Groups['name'].Value
        if ($declared.ContainsKey($name)) { continue }
        $declared[$name] = New-DeclaredFeeder -Match $match
    }

    foreach ($match in [regex]::Matches($Text, $ChainInlineDeclaration)) {
        $names = [regex]::Matches($match.Groups['sql'].Value, '\{\{\s*(\w+)\s*\}\}')
        if ($names.Count -eq 0) { continue }

        $name = $names[$names.Count - 1].Groups[1].Value
        if ($declared.ContainsKey($name)) { continue }
        $declared[$name] = New-DeclaredFeeder -Match $match
    }

    return $declared
}

function Expand-KnownPlaceholders {
    # Substitutes what the run already knows and leaves the rest standing. Expand-Placeholders
    # throws on a leftover, which is right for a statement about to be sent and wrong here: a
    # declared filter is read before the caller has decided whether it can be honoured at all.
    param([string]$Text, [hashtable]$Values)

    return [regex]::Replace($Text, '\{\{\s*(\w+)\s*\}\}', {
            param($m)
            $key = $m.Groups[1].Value
            if ($Values.ContainsKey($key)) { return [string]$Values[$key] }
            return $m.Value
        })
}

function Select-FeederRow {
    # The rows of a source a consumer may actually read, per the filters declared against that
    # source. Only those: a filter belongs to the statement it was written on, and a two-level
    # chain reaches its values through a nearer source that never projected the filtered column.
    # GLOBAL-DISCOVERY-029 declares storage_layer against GLOBAL-DISCOVERY-017 and is normally
    # fed by GLOBAL-DISCOVERY-028, whose result has no storage_layer to test - carrying the
    # filter across would empty every row of it and stop the chain one step from the end.
    #
    # Applied to its own source, a filter naming a column that source does not project selects
    # nothing rather than everything: there the statement asked for a distinction its source
    # cannot make, and answering with the unfiltered rows is the silent wrong answer.
    param($Rows, $Filters, [hashtable]$ParamTable, [string]$CheckId)

    $rows = @($Rows)
    foreach ($filter in @($Filters)) {
        if ($null -eq $filter) { continue }
        if ($CheckId -and $filter.CheckId -and $filter.CheckId -ne $CheckId) { continue }

        $wanted = Expand-KnownPlaceholders -Text $filter.Value -Values $ParamTable
        if ($wanted -match '\{\{') { return @() }

        $rows = @($rows | Where-Object {
                $names = $_.PSObject.Properties.Name
                ($names -contains $filter.Column) -and ([string]$_.($filter.Column) -eq $wanted)
            })
    }
    return $rows
}

function Test-QuotedPlaceholder {
    # A placeholder substituted inside SQL quotes carries a string; a bare one carries a number
    # or the literal NULL. The two need opposite handling for a feeder cell that holds nothing,
    # so the shape is read off the statement rather than guessed from the parameter's name.
    param([string]$Text, [string]$Name)

    return ($Text -match ("'\{\{\s*" + [regex]::Escape($Name) + "\s*\}\}'"))
}

function ConvertTo-ChainValue {
    # What replaces the placeholder. Returns $null for a combination that cannot be pursued,
    # which the caller drops with its reason rather than running.
    param([string]$Text, [string]$Name, $Value)

    $quoted = Test-QuotedPlaceholder -Text $Text -Name $Name
    $empty = ($null -eq $Value -or $Value -is [DBNull] -or [string]$Value -eq '')

    if ($empty) {
        # A quoted comparison can never match a value the feeder does not have, so the
        # statement would run, cost a full scan and report nothing - for a reason about SQL
        # rather than about the sport. Bare is the opposite: GLOBAL-DISCOVERY-019 is written
        # with an IS NULL arm precisely so the literal NULL selects the events that have none.
        if ($quoted) { return $null }
        return 'NULL'
    }

    $text = [string]$Value
    if ($quoted) { return (Get-SqlEscaped -Text $text) }
    return $text
}

function Test-RowColumn {
    # Whether a result carries every column named. Read off the first row, because the API
    # returns one shape for the whole result set.
    param($Rows, [string[]]$Columns)

    $first = @($Rows) | Select-Object -First 1
    if ($null -eq $first) { return $false }

    $names = $first.PSObject.Properties.Name
    foreach ($column in $Columns) {
        if ($names -notcontains $column) { return $false }
    }
    return $true
}

function Get-ChainValueSet {
    # The value combinations a feeder offers, in its own order, without repeats. Taken as whole
    # rows rather than one column at a time: a summary's rows are the combinations that occur
    # together, and crossing its columns would manufacture pairs the sport never had.
    param($Rows, [string[]]$Columns)

    $seen = @{}
    $sets = @()

    foreach ($row in @($Rows)) {
        if ($null -eq $row) { continue }

        $names = $row.PSObject.Properties.Name
        $absent = @($Columns | Where-Object { $names -notcontains $_ })
        if ($absent.Count -gt 0) { continue }

        $set = [ordered]@{}
        foreach ($column in $Columns) { $set[$column] = $row.$column }

        # A separator no pattern can contain, so two different combinations cannot collide
        # into one key and be silently deduplicated.
        $key = (@($Columns | ForEach-Object { [string]$set[$_] }) -join [char]1)
        if ($seen.ContainsKey($key)) { continue }
        $seen[$key] = $true

        $sets += , $set
    }

    # Returned plain, not comma-wrapped: the caller re-wraps with @(), and the two together
    # would nest the whole list inside a single element.
    return $sets
}

function New-ChainedJob {
    # One drill-down bound to one combination of values. The CheckID is unchanged - POWERBI.md
    # makes it the identity of the statement, and running one statement three times does not
    # make three statements - so the values travel beside it in Parameters, and RunKey is what
    # keeps the three runs apart in a workbook that is otherwise keyed per check.
    param($Job, $Assignment, [hashtable]$ParamTable)

    $values = @{}
    foreach ($entry in $ParamTable.GetEnumerator()) { $values[$entry.Key] = $entry.Value }

    $shown = @()
    foreach ($name in $Assignment.Keys) {
        $literal = ConvertTo-ChainValue -Text $Job.Sql -Name $name -Value $Assignment[$name]
        if ($null -eq $literal) { return $null }

        $values[$name] = $literal
        $shown += ('{0}={1}' -f $name,
            $(if ($null -eq $Assignment[$name]) { 'NULL' } else { [string]$Assignment[$name] }))
    }

    $parameters = $shown -join ', '

    return [pscustomobject]@{
        CheckId      = $Job.CheckId
        Name         = $Job.Name
        What         = $Job.What
        File         = $Job.File
        Line         = $Job.Line
        Path         = $Job.Path
        Sql          = (Expand-Placeholders -Text $Job.Sql -Values $values)
        RunKey       = ('{0} [{1}]' -f $Job.CheckId, $parameters)
        Parameters   = $parameters
        Category     = $(if ($Job.PSObject.Properties.Name -contains 'Category') { [string]$Job.Category } else { '' })
        Signal       = $(if ($Job.PSObject.Properties.Name -contains 'Signal' -and $Job.Signal) { [string]$Job.Signal } else { 'Informational' })
        SignalReason = $(if ($Job.PSObject.Properties.Name -contains 'SignalReason' -and $Job.SignalReason) { [string]$Job.SignalReason } else { $DiscoverySignalReason })
    }
}

function Get-ChainedJob {
    # The next wave of the chain: every statement still short of a value, bound to the values
    # its declared feeder has already returned.
    #
    # Which run feeds it is not a pairing table either. A statement declares one feeder per
    # placeholder, and among the runs of those feeders the ones used are those whose result
    # carries every column the statement is missing - because a two-level chain reaches its
    # values through a summary that is itself already bound to one of them, and reading the
    # two placeholders out of two different runs would produce combinations neither reported.
    # Where no single run carries them all, nothing is guessed: the statement stays skipped
    # and the run says which pair it could not find together.
    param($Pending, $Completed, [hashtable]$ParamTable, [int]$Top, [int]$Budget, [int[]]$TemplateIds)

    $jobs = @()
    $resolved = @()
    $notes = @()
    $capped = $false

    foreach ($item in $Pending) {
        if ($jobs.Count -ge $Budget) { $capped = $true; break }

        $job = $item.Job
        $missing = @(Get-MissingPlaceholders -Text $job.Sql -Values $ParamTable)
        if ($missing.Count -eq 0) { continue }

        $declared = Get-DeclaredFeeder -Text $job.Sql
        $undeclared = @($missing | Where-Object { -not $declared.ContainsKey($_) })
        if ($undeclared.Count -gt 0) {
            $notes += [pscustomobject]@{
                Job    = $job
                Kind   = 'UNDECLARED'
                Reason = ("no source declared for {0}; GLOBAL_QUERIES names one on the placeholder's own line" -f
                    ($undeclared -join ', '))
            }
            continue
        }

        $columnOf = @{}
        foreach ($name in $missing) { $columnOf[$name] = $declared[$name].Column }
        $wanted = @($missing | ForEach-Object { $columnOf[$_] } | Select-Object -Unique)
        $feeders = @($missing | ForEach-Object { $declared[$_].CheckId } | Select-Object -Unique)
        # Each filter carries the source it was declared against, so it is applied to that
        # source's rows and to no other.
        $filters = @($missing | ForEach-Object {
                $entry = $declared[$_]
                if ($entry.Filter) {
                    [pscustomobject]@{
                        CheckId = $entry.CheckId
                        Column  = $entry.Filter.Column
                        Value   = $entry.Filter.Value
                    }
                }
            } | Where-Object { $_ })

        # Narrowed before the source is judged, not after: a run of the right statement whose
        # rows are all the wrong layer is not a source, and counting it as one would produce a
        # wave of drill-downs that can only come back empty.
        $sources = @()
        foreach ($candidate in $Completed) {
            if ($feeders -notcontains $candidate.Job.CheckId) { continue }

            $rows = @(Select-FeederRow -Rows $candidate.Rows -Filters $filters -ParamTable $ParamTable `
                    -CheckId $candidate.Job.CheckId)
            if ($rows.Count -eq 0) { continue }
            if (-not (Test-RowColumn -Rows $rows -Columns $wanted)) { continue }

            $sources += [pscustomobject]@{ Job = $candidate.Job; Rows = $rows }
        }

        if ($sources.Count -eq 0) {
            $ran = @($Completed | Where-Object { $feeders -contains $_.Job.CheckId })
            $filtered = @($filters | ForEach-Object { "{0} = {1}" -f $_.Column, $_.Value })
            $notes += [pscustomobject]@{
                Job    = $job
                Kind   = 'NO_SOURCE'
                Reason = $(if ($ran.Count -eq 0) {
                        ("{0} returned nothing to select from" -f ($feeders -join ', '))
                    }
                    elseif ($filtered.Count -gt 0) {
                        ("no run of {0} carries {1} together in rows where {2}" -f
                            ($feeders -join ', '), ($wanted -join ' and '), ($filtered -join ' and '))
                    }
                    else {
                        ("no single run of {0} carries {1} together" -f ($feeders -join ', '), ($wanted -join ' and '))
                    })
            }
            continue
        }

        $made = 0
        $dropped = 0
        $unpursued = 0

        foreach ($source in $sources) {
            $sets = @(Get-ChainValueSet -Rows $source.Rows -Columns $wanted)
            $pursued = @($sets | Select-Object -First $Top)
            $unpursued += ($sets.Count - $pursued.Count)

            foreach ($set in $pursued) {
                if ($jobs.Count -ge $Budget) { $capped = $true; break }

                $assignment = [ordered]@{}
                foreach ($name in $missing) { $assignment[$name] = $set[$columnOf[$name]] }

                $chained = New-ChainedJob -Job $job -Assignment $assignment -ParamTable $ParamTable
                if ($null -eq $chained) { $dropped++; continue }

                # Narrowing is applied here as well as in the main selection, or a chained run
                # under -TemplateIds would be the one statement in the workbook that quietly
                # covered the whole sport.
                if ($TemplateIds.Count -gt 0) {
                    $narrowed = Enable-TemplateFilter -Text $chained.Sql -TemplateIds $TemplateIds
                    if ($narrowed.Activated -eq 0) { $dropped++; continue }
                    $chained.Sql = $narrowed.Sql
                }

                $jobs += $chained
                $made++
            }

            if ($capped) { break }
        }

        if ($unpursued -gt 0) {
            $notes += [pscustomobject]@{
                Job    = $job
                Kind   = 'NOT_PURSUED'
                Reason = ("{0} further value(s) of {1} not pursued; -ChainTop takes the {2} the summary ranks first" -f
                    $unpursued, ($wanted -join '/'), $Top)
            }
        }
        if ($dropped -gt 0) {
            $notes += [pscustomobject]@{
                Job    = $job
                Kind   = 'DROPPED'
                Reason = ("{0} value(s) could not be pursued: a quoted parameter has no value to match" -f $dropped)
            }
        }
        if ($made -gt 0) { $resolved += $item }
    }

    return [pscustomobject]@{
        Jobs     = @($jobs)
        Resolved = @($resolved)
        Notes    = @($notes)
        Capped   = $capped
    }
}

# The lower boundary of a branch's scope, as POWERBI.md fixes it. Both the alias and the
# column are read out of the marker rather than assumed. The alias, because a statement
# joining the template layer more than once uses tt2, ttx or tty, and an expression keyed on
# tt alone would narrow one branch and leave its sibling wide - the one failure this whole
# mechanism exists to prevent. The column, because the two forms are not equivalent to the
# optimiser: filtering tournament_template.id makes it drive from the template table and lose
# the index path into the statistic shards, where filtering tournament.tournament_templateFK
# keeps the plan that starts where the scope does. Measured on Soccer, the same result takes
# 28.3s one way and 2.5s the other.
$TemplateFilterMarker =
'(?m)^([ \t]*)--[ \t]*AND[ \t]+(\w+)\.(id|tournament_templateFK)[ \t]*=[ \t]*<tournament_template_id>[ \t]*$'

function Enable-TemplateFilter {
    # Activates every template filter in the statement and reports how many it found, so a
    # statement with none can be stopped rather than run over the whole sport.
    param([string]$Text, [int[]]$TemplateIds)

    $found = [regex]::Matches($Text, $TemplateFilterMarker)
    $list = ($TemplateIds -join ', ')

    $activated = [regex]::Replace($Text, $TemplateFilterMarker, {
            param($m)
            '{0}AND {1}.{2} IN ({3})' -f $m.Groups[1].Value, $m.Groups[2].Value, $m.Groups[3].Value, $list
        })

    return [pscustomobject]@{ Sql = $activated; Activated = $found.Count }
}

# The id window a statement can be cut into. WORKFLOW.md separates two ways scope failure
# arrives, and this marker answers the second: not a statement too slow, but a result the
# transport cannot carry whole. Soccer's registry holds close to 400 000 audited people and
# GLOBAL-DQ-009 reports around 140 000 of them, which exhausts the API's memory before a row
# is returned.
#
# The placeholder names the object the window keys on - <from_participant_id> means the
# participant table - so the runner can find that table's id range without being told.
$ShardFilterMarker =
'(?m)^([ \t]*)--[ \t]*AND[ \t]+([\w.]+)[ \t]+BETWEEN[ \t]+<from_([a-z_]+)_id>[ \t]+AND[ \t]+<to_[a-z_]+_id>[ \t]*$'

# A runaway split is the thing to bound rather than the split itself. Eight levels is 256
# windows, far past any result this package can produce.
$MaxShardDepth = 8

# How many windows the first cut makes. Halving from the whole range would rediscover the
# limit by failing at every level, and a failure costs the same full scan a success does -
# the transport only gives up once the rows are gathered. Measured on Soccer: halving spent
# seven failed scans to reach eight windows, where cutting straight to eight spends none.
$InitialShardCount = 8

function Enable-ShardFilter {
    # Activates every id window in the statement. Returns $null for a statement that declares
    # none, which is how a caller learns it cannot be cut rather than guessing a column.
    param([string]$Text, [long]$From, [long]$To)

    $found = [regex]::Matches($Text, $ShardFilterMarker)
    if ($found.Count -eq 0) { return $null }

    $activated = [regex]::Replace($Text, $ShardFilterMarker, {
            param($m)
            '{0}AND {1} BETWEEN {2} AND {3}' -f $m.Groups[1].Value, $m.Groups[2].Value, $From, $To
        })

    return [pscustomobject]@{
        Sql       = $activated
        Object    = $found[0].Groups[3].Value
        Activated = $found.Count
    }
}

function Test-ResultTooLarge {
    # The transport giving up on the size of a result, which is the one failure sharding
    # answers. A statement that is merely slow fails differently and must not be cut, because
    # cutting it would multiply the time rather than divide the rows.
    param([string]$Message)

    return ([string]$Message -match 'Allowed memory size' -or
        [string]$Message -match 'memory[ _]?(size )?exhausted' -or
        [string]$Message -match 'Out of memory')
}

function Merge-ShardedRows {
    # Findings concatenate; COVERAGE does not. Each shard reports the population of its own
    # window, so the merged statement must carry one COVERAGE row holding their sum, or the
    # workbook would show a check that audited nothing per shard.
    #
    # Summing is exact only because the window and the count key are the same object, which
    # Test-Package.ps1 enforces statically for every statement carrying the marker.
    param($Parts)

    $findings = @()
    $coverage = $null
    $total = 0

    foreach ($rows in $Parts) {
        foreach ($row in @($rows)) {
            if ($null -eq $row) { continue }
            $names = $row.PSObject.Properties.Name
            if ($names -contains 'check_type' -and [string]$row.check_type -eq 'COVERAGE') {
                if ($null -eq $coverage) { $coverage = $row }
                $value = 0
                if ($names -contains 'eligible_count' -and
                    [int]::TryParse([string]$row.eligible_count, [ref]$value)) { $total += $value }
                continue
            }
            $findings += $row
        }
    }

    if ($null -ne $coverage) {
        $coverage.eligible_count = $total
        $findings += $coverage
    }
    return $findings
}

# A branch a statement declares optional. Only a statement that reads the registry as one
# source beside others carries the pair; one whose audited population is the registry itself
# does not, which is what makes dropping it refusable rather than silently destructive.
$RegistryBranchMarker =
'(?ms)^[ \t]*--[ \t]*REGISTRY BRANCH BEGIN[ \t]*\r?\n.*?^[ \t]*--[ \t]*REGISTRY BRANCH END[ \t]*\r?\n'

function Remove-RegistryBranch {
    # Removes every marked branch and reports how many it found.
    param([string]$Text)

    $found = [regex]::Matches($Text, $RegistryBranchMarker)
    $stripped = [regex]::Replace($Text, $RegistryBranchMarker, '')

    return [pscustomobject]@{ Sql = $stripped; Removed = $found.Count }
}

function Expand-Placeholders {
    param([string]$Text, [hashtable]$Values)

    $result = [regex]::Replace($Text, '\{\{\s*(\w+)\s*\}\}', {
            param($m)
            $key = $m.Groups[1].Value
            if ($Values.ContainsKey($key)) { return [string]$Values[$key] }
            return $m.Value
        })

    $missing = @([regex]::Matches($result, '\{\{\s*(\w+)\s*\}\}') |
        ForEach-Object { $_.Groups[1].Value } |
        Select-Object -Unique)

    if ($missing.Count -gt 0) {
        $hint = if ($missing -contains 'SPORT_ID') { '-SportId 58' } else { "-Params $($missing[0])=<value>" }
        throw "Missing parameter value(s): $($missing -join ', '). Pass them like: $hint"
    }
    return $result
}

# --------------------------------------------------------------------------------------
# Session handling
# --------------------------------------------------------------------------------------

function New-EmptySession {
    return New-Object Microsoft.PowerShell.Commands.WebRequestSession
}

function Add-CookieToSession {
    param($Session, [string]$Name, [string]$Value)

    $uri = [uri]$BaseUrl
    $cookie = New-Object System.Net.Cookie($Name, $Value, '/', $uri.Host)
    $Session.Cookies.Add($cookie)
}

function Save-SessionState {
    param($Session)

    if (-not (Test-Path $StateDir)) { New-Item -ItemType Directory -Path $StateDir | Out-Null }
    $uri = [uri]$BaseUrl

    # Keep the newest cookie per name, otherwise a stale duplicate can win on restore.
    $latest = [ordered]@{}
    foreach ($c in $Session.Cookies.GetCookies($uri)) { $latest[$c.Name] = $c.Value }

    $bag = @()
    foreach ($name in $latest.Keys) { $bag += @{ Name = $name; Value = $latest[$name] } }
    $bag | Export-Clixml -Path $StatePath
}

function Restore-SessionState {
    if (-not (Test-Path $StatePath)) { return $null }
    try {
        $bag = Import-Clixml -Path $StatePath
    }
    catch {
        return $null
    }
    if (-not $bag) { return $null }

    $session = New-EmptySession
    foreach ($c in $bag) { Add-CookieToSession -Session $session -Name $c.Name -Value $c.Value }
    return $session
}

function Get-LoginCredential {
    $email = $env:EP_QB_EMAIL
    if ([string]::IsNullOrWhiteSpace($email)) {
        $email = Read-Host 'Content Query Builder email'
    }

    $password = $env:EP_QB_PASSWORD
    if ([string]::IsNullOrWhiteSpace($password)) {
        $secure = Read-Host 'Password' -AsSecureString
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        try { $password = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) }
        finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    }

    return @{ Email = $email; Password = $password }
}

function New-AuthenticatedSession {
    # A pasted session cookie wins over an interactive login.
    if (-not [string]::IsNullOrWhiteSpace($env:EP_QB_COOKIE)) {
        $session = New-EmptySession
        foreach ($part in ($env:EP_QB_COOKIE -split ';')) {
            $kv = $part.Trim()
            if ($kv -match '^([^=]+)=(.*)$') {
                Add-CookieToSession -Session $session -Name $matches[1].Trim() -Value $matches[2].Trim()
            }
        }
        Write-Host 'Using session cookie from EP_QB_COOKIE.' -ForegroundColor DarkGray
        return $session
    }

    Write-Host 'Logging in...' -ForegroundColor DarkGray

    $session = New-EmptySession
    $page = Invoke-WebRequest -Uri $LoginPageUrl -WebSession $session -UseBasicParsing -TimeoutSec 30

    $tokenMatch = [regex]::Match($page.Content, 'name="_token"\s+value="([^"]+)"')
    if (-not $tokenMatch.Success) {
        throw 'Could not read the CSRF _token from the login page. The login form may have changed.'
    }

    $cred = Get-LoginCredential
    $body = @{
        _token   = $tokenMatch.Groups[1].Value
        email    = $cred.Email
        password = $cred.Password
        remember = 'on'
    }

    $response = Invoke-WebRequest -Uri $LoginUrl -Method POST -Body $body -WebSession $session `
        -UseBasicParsing -TimeoutSec 30

    # A successful login redirects away from /login; a failed one re-renders the form.
    $landedOnLogin = $false
    if ($response.BaseResponse -and $response.BaseResponse.ResponseUri) {
        $landedOnLogin = $response.BaseResponse.ResponseUri.AbsolutePath -match '(?i)/login/?$'
    }

    if ($landedOnLogin -or ($response.Content -match 'name="_token"' -and $response.Content -match '(?i)log ?in')) {
        # Laravel puts the reason in the validation block, which is far more useful
        # than guessing which of the two settings is wrong.
        $reasonMatch = [regex]::Match($response.Content,
            '(?is)<(?:div|span|p|strong|li)[^>]*(?:invalid-feedback|alert|error|danger)[^>]*>(.*?)</(?:div|span|p|strong|li)>')
        if ($reasonMatch.Success) {
            $reason = ((($reasonMatch.Groups[1].Value -replace '<[^>]+>', '') -replace '\s+', ' ').Trim())
            if ($reason) {
                throw "Login failed for '$($cred.Email)': $reason  (check TOOLS\secrets.local.ps1)"
            }
        }
        throw 'Login failed. Check EP_QB_EMAIL and EP_QB_PASSWORD.'
    }

    Save-SessionState -Session $session
    return $session
}

function Get-XsrfHeaderValue {
    param($Session)

    $uri = [uri]$BaseUrl
    foreach ($c in $Session.Cookies.GetCookies($uri)) {
        if ($c.Name -eq 'XSRF-TOKEN') {
            return [uri]::UnescapeDataString($c.Value)
        }
    }
    return $null
}

# --------------------------------------------------------------------------------------
# Execution
# --------------------------------------------------------------------------------------

# Runs in a runspace of its own so the caller can walk away from it. A failure is returned
# as data rather than thrown: the ErrorRecord has to cross the runspace boundary intact for
# Get-ErrorDetail to read the MySQL message off the response body.
$RemoteSqlScript = @'
param($Session, $Url, $Body, $Headers, $TimeoutSec)
$ErrorActionPreference = 'Stop'
try {
    $response = Invoke-WebRequest -Uri $Url -Method POST -Body $Body `
        -ContentType 'application/x-www-form-urlencoded' -Headers $Headers `
        -WebSession $Session -UseBasicParsing -TimeoutSec $TimeoutSec
    [pscustomobject]@{ Response = $response; Failure = $null }
}
catch {
    [pscustomobject]@{ Response = $null; Failure = $_ }
}
'@

function Invoke-RemoteSql {
    param($Session, [string]$Statement)

    $headers = @{
        'accept'           = 'application/json'
        'X-Requested-With' = 'XMLHttpRequest'
        'Referer'          = $LoginPageUrl
    }
    $xsrf = Get-XsrfHeaderValue -Session $Session
    if ($xsrf) { $headers['X-XSRF-TOKEN'] = $xsrf }

    $body = 'sql=' + [uri]::EscapeDataString($Statement)

    $shell = [powershell]::Create()
    [void]$shell.AddScript($RemoteSqlScript)
    [void]$shell.AddArgument($Session)
    [void]$shell.AddArgument($ExecuteUrl)
    [void]$shell.AddArgument($body)
    [void]$shell.AddArgument($headers)
    [void]$shell.AddArgument($StatementTimeoutSec)

    $async = $shell.BeginInvoke()
    $limit = $StatementTimeoutSec + $WatchdogGraceSec

    if (-not $async.AsyncWaitHandle.WaitOne([timespan]::FromSeconds($limit))) {
        # Stop() would block on the very call that is stuck, and Dispose() waits for Stop,
        # so the runspace is signalled asynchronously and then left behind. It holds one
        # thread and one dead socket until the process exits; the run carries on.
        [void]$shell.BeginStop($null, $null)
        throw ("No response after {0}s. The connection wedged rather than failing, " -f $limit) +
        'so the statement was abandoned. Nothing ran twice; re-run this check on its own.'
    }

    try { $result = @($shell.EndInvoke($async)) } finally { $shell.Dispose() }

    if ($result.Count -eq 0) { throw 'The request ended without returning anything.' }
    if ($result[0].Failure) { throw $result[0].Failure }
    return $result[0].Response
}

function Get-ErrorDetail {
    # A rejected statement comes back as HTTP 500 with the MySQL message in the
    # body, which Invoke-WebRequest hides behind a generic exception.
    param($ErrorRecord)

    $response = $ErrorRecord.Exception.Response
    if ($null -eq $response) { return $null }

    $body = $null
    try {
        $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
        try { $body = $reader.ReadToEnd() } finally { $reader.Dispose() }
    }
    catch { return $null }

    if ([string]::IsNullOrWhiteSpace($body)) { return $null }

    $detail = $body
    try {
        $parsed = $body | ConvertFrom-Json
        foreach ($name in @('response', 'error', 'message', 'exception')) {
            if ($parsed.PSObject.Properties.Name -contains $name -and $parsed.$name -is [string]) {
                $detail = $parsed.$name
                break
            }
        }
    }
    catch { }

    $detail = ($detail -replace '\s+', ' ').Trim()
    if ($detail.Length -gt 800) { $detail = $detail.Substring(0, 800) + '...' }
    return $detail
}

function Invoke-SqlWithRetry {
    # Uses and refreshes $script:Session so a batch survives an expiring cookie.
    param([string]$Statement)

    try {
        return Invoke-RemoteSql -Session $script:Session -Statement $Statement
    }
    catch {
        $status = 0
        if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }

        if ($status -eq 401 -or $status -eq 403 -or $status -eq 419) {
            Write-Host "Session rejected (HTTP $status), logging in again..." -ForegroundColor DarkGray
            if (Test-Path $StatePath) { Remove-Item -LiteralPath $StatePath -Force }
            $script:Session = New-AuthenticatedSession
            return Invoke-RemoteSql -Session $script:Session -Statement $Statement
        }

        $detail = Get-ErrorDetail -ErrorRecord $_
        if ($detail) { throw "Query failed (HTTP $status): $detail" }
        throw
    }
}

function Get-SqlLiteral {
    param([string]$Text)

    return "'" + (Get-SqlEscaped -Text $Text) + "'"
}

function Get-ShardBounds {
    # The id range the windows are cut from, read from the object the marker names. The whole
    # table is used rather than the sport's slice of it: a window falling outside the sport
    # returns nothing and costs one cheap query, where deriving the sport's own range would
    # mean parsing the statement's FROM clause to find out how it reaches the sport.
    param([string]$Object)

    # The name comes out of a placeholder in our own SQL, but it is about to be concatenated
    # into a statement, so it is checked rather than trusted.
    if ($Object -notmatch '^[a-z][a-z_]*$') { return $null }

    $probe = "SELECT MIN(id) AS lo, MAX(id) AS hi FROM $Object WHERE del = 'no'"
    $rows = @(Get-ResultRows -Content (Invoke-SqlWithRetry -Statement $probe).Content)
    if ($rows.Count -eq 0) { return $null }

    $lo = 0
    $hi = 0
    if (-not [long]::TryParse([string]$rows[0].lo, [ref]$lo)) { return $null }
    if (-not [long]::TryParse([string]$rows[0].hi, [ref]$hi)) { return $null }
    if ($hi -lt $lo) { return $null }

    return [pscustomobject]@{ Lo = $lo; Hi = $hi }
}

function Invoke-ShardedSql {
    # Runs one id window, and halves it on the same failure rather than guessing a shard count
    # up front: the size that defeats the transport is a property of the data, not of the
    # statement, and it changes as the database grows.
    param([string]$Statement, [long]$From, [long]$To, [int]$Depth = 0)

    $shard = Enable-ShardFilter -Text $Statement -From $From -To $To

    try {
        return Get-ResultRows -Content (Invoke-SqlWithRetry -Statement $shard.Sql).Content
    }
    catch {
        if (-not (Test-ResultTooLarge -Message $_.Exception.Message)) { throw }
        if ($Depth -ge $MaxShardDepth -or $From -ge $To) { throw }

        $mid = [long][math]::Floor(($From + $To) / 2)
        $left = Invoke-ShardedSql -Statement $Statement -From $From -To $mid -Depth ($Depth + 1)
        $right = Invoke-ShardedSql -Statement $Statement -From ($mid + 1) -To $To -Depth ($Depth + 1)
        return Merge-ShardedRows -Parts @($left, $right)
    }
}

function Get-StatementRows {
    # One statement's rows. Whole where the transport can carry them, cut into id windows and
    # merged where it cannot - so a batch is not lost to the one check whose findings outgrew
    # the connection, and nobody has to know in advance which check that is.
    param([string]$Statement, [string]$CheckId)

    try {
        return Get-ResultRows -Content (Invoke-SqlWithRetry -Statement $Statement).Content
    }
    catch {
        if (-not (Test-ResultTooLarge -Message $_.Exception.Message)) { throw }

        $shard = Enable-ShardFilter -Text $Statement -From 0 -To 0
        if (-not $shard) { throw }

        $bounds = Get-ShardBounds -Object $shard.Object
        if (-not $bounds) { throw }

        Write-Host ("  {0}: result too large for one request, cutting {1} ids {2}-{3} into {4} windows" -f `
                $CheckId, $shard.Object, $bounds.Lo, $bounds.Hi, $InitialShardCount) -ForegroundColor Yellow

        # The whole range has just failed, so it is not tried again. Each window that still
        # cannot be carried halves itself from here.
        $span = $bounds.Hi - $bounds.Lo + 1
        $step = [long][math]::Ceiling($span / $InitialShardCount)
        $parts = @()

        for ($lo = $bounds.Lo; $lo -le $bounds.Hi; $lo += $step) {
            $hi = [long][math]::Min($lo + $step - 1, $bounds.Hi)
            $parts += , (Invoke-ShardedSql -Statement $Statement -From $lo -To $hi -Depth 1)
        }

        return Merge-ShardedRows -Parts $parts
    }
}

# The parameters Resolve-SportParameters can read from the database. Anything else has to
# come from SPORTS/params.json or the command line: a value the runner cannot confirm is
# never guessed.
$DiscoverableParameters = @('SPORT_ID', 'STATISTIC_TYPE_ID', 'STATISTIC_OWNER_TYPE_ID', 'SHARD_ID')

# The three keys inside a sport's SPORTS/params.json entry that are not themselves parameters.
# _notApplicable holds the parameters the sport is documented as unable to supply, mapped to
# the reason. _checkSignal holds what a check's output is worth for this sport, for the ones
# that are not simply actionable. _expected holds what a re-run should return once the data
# has been corrected. Test-Package.ps1 declares the same three names; the pair of files is
# the contract for all three blocks.
$NotApplicableKey = '_notApplicable'
$CheckSignalKey = '_checkSignal'
$ExpectedKey = '_expected'
$ReservedParamKeys = @($NotApplicableKey, $CheckSignalKey, $ExpectedKey)

# What a recorded signal may say. Actionable is the default and is never recorded: writing it
# down for every check would make the block a second copy of the registry. Deprecated is
# deliberately absent - POWERBI_REGISTRY.md's Status column owns that, and a value with two
# owners drifts.
$CheckSignalValues = @('Monitor', 'Informational', 'Blocked', 'Not applicable')

# What a re-run should return after the reported findings have been corrected. This is a
# different question from the signal, and the difference is the whole reason the block
# exists: the signal says what today's rows are worth, the expectation says what tomorrow's
# count should be. Reading a re-run without it means remembering, per check, which ones were
# ever supposed to reach zero - which is exactly what stops working at fifty checks.
#
#   Zero      every finding row is a defect, so a corrected sport returns the COVERAGE row alone
#   Non-zero  rows remain however much is corrected: the proportion is the finding, not the row
#   Residual  a known and agreed number of rows stays behind; anything above it is new
#
# The expectation is read off the check's invariant, never off the last run's count. A check
# that happens to return nothing today is not thereby a Zero check, exactly as CLAUDE.md
# refuses to let an empty population decide applicability.
$CheckExpectValues = @('Zero', 'Non-zero', 'Residual')

# The default each signal implies, so only the exception is written down. Blocked and Not
# applicable are absent rather than empty: a check that must not run yet, or that reads a
# layer the sport does not have, has no count anybody should be expecting.
$ExpectedBySignal = @{
    'Actionable'    = 'Zero'
    'Monitor'       = 'Non-zero'
    'Informational' = 'Non-zero'
}

# What to work through first, banded from the Category POWERBI_REGISTRY.md already records
# against every row. A broken structure outranks a wrong value, and a wrong value outranks an
# empty field: a relation that does not resolve breaks everything read through it, whereas an
# empty field is one fact nobody has entered yet. Recorded by decision of 2026-08-05.
#
# The band is derived rather than authored per check, so a check cannot disagree with its own
# category. The numeric prefix is what makes an ordinary sort in Sheets produce the priority
# order, since the names themselves do not sort that way. POWERBI.md owns the vocabulary and
# Test-Package.ps1 declares the same map, failing a registry Category that is missing from it.
$CheckPriorityByCategory = @{
    'WRONG_STRUCTURE'     = '1 Structure'
    'NO_RELATED_RECORDS'  = '1 Structure'
    'WRONG_RESULTS'       = '2 Wrong value'
    'WRONG_GENDER'        = '2 Wrong value'
    'WRONG_DISCIPLINE'    = '2 Wrong value'
    'DATE_RANGE_MISMATCH' = '2 Wrong value'
    'MALFORMED_NAME'      = '2 Wrong value'
    'MISSING_VALUES'      = '3 Missing value'
}

# Discovery is a census by construction: its rows are categories with counts, and a category
# cannot be corrected the way a missing birth date can. So every statement in GLOBAL_QUERIES
# is informational without a sport having to say so, and the reviewer is told once rather than
# left to infer it from the shape of each result.
$DiscoveryCheckIdPattern = 'GLOBAL-DISCOVERY-*'
$DiscoverySignalReason = 'Discovery: the output describes the population rather than finding defects in it, so no row is correctable.'

function Get-SportFileParameters {
    # Values a sport has already had confirmed and recorded. These outrank discovery: the
    # file holds documented evidence, discovery holds a heuristic (the busiest type/owner
    # pair). GLOBAL_DQ/README.md owns the file's shape.
    param([string]$SportName)

    $resolved = @{}
    $path = Join-Path $RepoRoot 'SPORTS\params.json'
    if (-not (Test-Path -LiteralPath $path)) { return $resolved }

    try {
        $params = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        Write-Host "  SPORTS/params.json could not be read: $($_.Exception.Message)" -ForegroundColor Yellow
        return $resolved
    }

    $entry = $params.PSObject.Properties | Where-Object { $_.Name -eq $SportName }
    if (-not $entry) {
        Write-Host "  '$SportName' is not in SPORTS/params.json; falling back to discovery." -ForegroundColor DarkGray
        return $resolved
    }

    foreach ($property in $entry.Value.PSObject.Properties) {
        if ($ReservedParamKeys -contains $property.Name) { continue }
        $resolved[$property.Name] = $property.Value
        # [string] on a number is invariant in PowerShell, which is what reaches the SQL, but
        # -f formats in the current culture. Under bg-BG that showed 0,01 for a value the
        # statement received as 0.01 - the same number reported two ways. Show what is sent.
        Write-Host ("  {0,-30} {1}  (SPORTS/params.json)" -f $property.Name, [string]$property.Value) -ForegroundColor DarkGray
    }
    return $resolved
}

function Get-SportCheckSignal {
    # What a check's output is worth for this sport, keyed by the GLOBAL-DQ template ID or by
    # the sport's own CheckID, for the ones that are not simply actionable. Anything absent
    # is actionable.
    #
    # This is a different question from _notApplicable, which is about a parameter the sport
    # cannot supply so the statement cannot run at all. Here every parameter is present and
    # the statement runs; what is in doubt is whether its findings are defects:
    #
    #   Monitor         real but population-wide - the proportion is the finding, not the row
    #   Informational   nothing in the output is correctable for this sport: it describes a
    #                   state rather than naming a defect. Distinct from Monitor, which still
    #                   asks a human to sort the real findings from the legitimate ones
    #   Not applicable  measures a layer or mechanism this sport does not use
    #   Blocked         would report the sport's normal shape as a defect until something
    #                   else is fixed first, so it must not be approved yet
    #
    # Selection does not depend on it. What it buys is that a documented conclusion in a sport
    # file stops being invisible to the run that contradicts it: -RunAll names the classified
    # checks it is about to run, and Test-Package.ps1 enforces each value's own rule.
    param([string]$SportName)

    $resolved = @{}
    $path = Join-Path $RepoRoot 'SPORTS\params.json'
    if (-not (Test-Path -LiteralPath $path)) { return $resolved }

    try {
        $params = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        return $resolved
    }

    $entry = $params.PSObject.Properties | Where-Object { $_.Name -eq $SportName }
    if (-not $entry) { return $resolved }

    $block = $entry.Value.PSObject.Properties | Where-Object { $_.Name -eq $CheckSignalKey }
    if (-not $block) { return $resolved }

    foreach ($property in $block.Value.PSObject.Properties) {
        $signal = [string]$property.Value.signal
        if ($CheckSignalValues -notcontains $signal) {
            # Reported rather than dropped: an unreadable classification is worse than none,
            # because the reader assumes the block is being honoured. Test-Package.ps1 fails
            # on the same condition.
            Write-Host ("  SPORTS/params.json: $($property.Name) has signal '$signal', which is not one of: " +
                ($CheckSignalValues -join ', ')) -ForegroundColor Yellow
            continue
        }
        $resolved[$property.Name] = [pscustomobject]@{
            Signal = $signal
            Reason = [string]$property.Value.reason
        }
    }
    return $resolved
}

function Get-SportCheckExpected {
    # What a re-run of each check should return for this sport once the reported findings have
    # been corrected, keyed the same way _checkSignal is: by the GLOBAL-DQ template ID or by
    # the sport's own CheckID. Anything absent takes the default its signal implies.
    #
    # Only the exception is recorded, for the same reason Actionable is never written down: a
    # value on every check would make the block a second copy of something already derivable.
    param([string]$SportName)

    $resolved = @{}
    $path = Join-Path $RepoRoot 'SPORTS\params.json'
    if (-not (Test-Path -LiteralPath $path)) { return $resolved }

    try {
        $params = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        return $resolved
    }

    $entry = $params.PSObject.Properties | Where-Object { $_.Name -eq $SportName }
    if (-not $entry) { return $resolved }

    $block = $entry.Value.PSObject.Properties | Where-Object { $_.Name -eq $ExpectedKey }
    if (-not $block) { return $resolved }

    foreach ($property in $block.Value.PSObject.Properties) {
        $expect = [string]$property.Value.expect
        if ($CheckExpectValues -notcontains $expect) {
            # Reported rather than dropped, as an unreadable signal is: the reader otherwise
            # assumes the block is being honoured. Test-Package.ps1 fails on the same condition.
            Write-Host ("  SPORTS/params.json: $($property.Name) expects '$expect', which is not one of: " +
                ($CheckExpectValues -join ', ')) -ForegroundColor Yellow
            continue
        }

        $residual = $null
        if ($expect -eq 'Residual') {
            $parsed = 0
            if ([int]::TryParse([string]$property.Value.residual, [ref]$parsed)) { $residual = $parsed }
        }

        $resolved[$property.Name] = [pscustomobject]@{
            Expect   = $expect
            Residual = $residual
            Reason   = [string]$property.Value.reason
        }
    }
    return $resolved
}

function Get-ExpectedForSignal {
    # The expectation a signal implies on its own. Empty for Blocked and Not applicable,
    # which describe checks nobody should be reading a count from.
    param([string]$Signal)

    if ([string]::IsNullOrWhiteSpace($Signal)) { return '' }
    if ($ExpectedBySignal.ContainsKey($Signal)) { return $ExpectedBySignal[$Signal] }
    return ''
}

function Get-CoverageCount {
    # The eligible_count a statement reports in its COVERAGE row: how many objects it actually
    # audited. Returns $null for a statement that declares no COVERAGE branch, which is every
    # discovery statement and nothing else the validator lets through.
    param($Rows)

    $total = $null
    foreach ($row in @($Rows)) {
        if ($null -eq $row) { continue }
        $names = $row.PSObject.Properties.Name
        if ($names -notcontains 'check_type' -or $names -notcontains 'eligible_count') { continue }
        if ([string]$row.check_type -ne 'COVERAGE') { continue }

        $value = 0
        if (-not [int]::TryParse([string]$row.eligible_count, [ref]$value)) { continue }
        $total = $(if ($null -eq $total) { $value } else { $total + $value })
    }
    return $total
}

function Get-FindingCount {
    # The rows that are findings, which is the row count less its COVERAGE row or rows. The
    # raw count cannot be compared between two runs on its own: every DQ statement returns a
    # COVERAGE row whether or not it found anything, so a clean check reports 1 and a check
    # with one finding reports 2. Subtracting it is what makes "was 40, now 3" mean what it
    # reads as.
    #
    # Returns $null where there is no check_type column to subtract by - a discovery
    # statement, or a failed one - rather than guessing that every row was a finding.
    param($Rows)

    $all = @($Rows | Where-Object { $null -ne $_ })
    if ($all.Count -eq 0) { return $null }

    $coverage = 0
    $typed = $false
    foreach ($row in $all) {
        if ($row.PSObject.Properties.Name -notcontains 'check_type') { continue }
        $typed = $true
        if ([string]$row.check_type -eq 'COVERAGE') { $coverage++ }
    }
    if (-not $typed) { return $null }
    return $all.Count - $coverage
}

function Get-SeededStatus {
    # The two verdicts the workbook can settle for itself, so a reviewer opens on the rows
    # that actually want reading.
    #
    # An informational check has nothing to act on by its nature. A check that came back with
    # its COVERAGE row alone found nothing today - which is a reading of the data and not the
    # absence of one.
    #
    # But the row count alone cannot say that. A statement that audited nothing returns the
    # same single row as one that found nothing wrong, and only the eligible_count in it tells
    # them apart: zero findings is clean data only when something was in scope to be found.
    # CLAUDE.md's coverage contract is explicit that a zero there is never clean, so it is
    # never seeded closed - it wants a person to decide whether the scope is misdirected or
    # the population is legitimately empty.
    #
    # A check that failed or was skipped is never seeded closed either, whatever its signal:
    # a closing status asserts that somebody read an output, and there is none to have read.
    # It also reports one row, holding the word ERROR rather than a coverage count.
    param([string]$Signal, $Rows, [bool]$Ran, $Eligible)

    if (-not $Ran) { return 'Not reviewed' }
    if ($Signal -eq 'Informational') { return 'No action needed' }
    if ($Rows -eq 1 -and $null -ne $Eligible -and $Eligible -gt 0) { return 'No issue' }
    return 'Not reviewed'
}

function Get-CheckPriority {
    # The band a check falls in, from the Category its registry row records. A category the
    # map does not know sorts last and says so, rather than leaving a blank the reader would
    # take for "no priority"; Test-Package.ps1 fails before it can reach a workbook.
    param([string]$Category)

    if ([string]::IsNullOrWhiteSpace($Category)) { return '' }
    if ($CheckPriorityByCategory.ContainsKey($Category)) { return $CheckPriorityByCategory[$Category] }
    return '9 Unclassified'
}

function Set-JobCheckSignal {
    # Apply the sport's interpretation to every execution path, not only -RunAll. Direct
    # GLOBAL-DQ patterns still run against one documented sport and must not lose a known
    # Monitor or Not applicable verdict when their workbook/summary is built.
    param($Jobs, [string]$SportName)

    $signals = $(if ([string]::IsNullOrWhiteSpace($SportName)) { @{} }
        else { Get-SportCheckSignal -SportName $SportName })
    $hydrated = @()

    foreach ($job in @($Jobs)) {
        $classification = $null
        $keys = @()
        if ($job.PSObject.Properties.Name -contains 'Template' -and $job.Template) {
            $keys += [string]$job.Template
        }
        if ($job.CheckId) { $keys += [string]$job.CheckId }

        foreach ($key in $keys) {
            if ($signals.ContainsKey($key)) {
                $classification = $signals[$key]
                break
            }
        }

        # A sport may still record something about a discovery statement, so the recorded
        # classification is read first and only an unclassified one falls back to the rule.
        $discovery = ([string]$job.CheckId -like $DiscoveryCheckIdPattern)

        $signal = if ($classification) { $classification.Signal }
            elseif ($discovery) { 'Informational' }
            elseif ($job.PSObject.Properties.Name -contains 'Signal' -and $job.Signal) { [string]$job.Signal }
            else { 'Actionable' }
        $reason = if ($classification) { $classification.Reason }
            elseif ($discovery) { $DiscoverySignalReason }
            elseif ($job.PSObject.Properties.Name -contains 'SignalReason') { [string]$job.SignalReason }
            else { '' }

        $job | Add-Member -NotePropertyName Signal -NotePropertyValue $signal -Force
        $job | Add-Member -NotePropertyName SignalReason -NotePropertyValue $reason -Force
        $hydrated += $job
    }

    return $hydrated
}

function Set-JobCheckExpectation {
    # What each check should return on a corrected re-run. Runs after Set-JobCheckSignal
    # rather than inside it because the default is derived from the signal, so the signal has
    # to be settled first; a recorded expectation then overrides that default.
    #
    # Keyed like the signal block: the template ID first, then the sport's own CheckID, so a
    # sport that replaced a template with its own statement classifies the statement it runs.
    param($Jobs, [string]$SportName)

    $expectations = $(if ([string]::IsNullOrWhiteSpace($SportName)) { @{} }
        else { Get-SportCheckExpected -SportName $SportName })
    $hydrated = @()

    foreach ($job in @($Jobs)) {
        $recorded = $null
        $keys = @()
        if ($job.PSObject.Properties.Name -contains 'Template' -and $job.Template) {
            $keys += [string]$job.Template
        }
        if ($job.CheckId) { $keys += [string]$job.CheckId }

        foreach ($key in $keys) {
            if ($expectations.ContainsKey($key)) {
                $recorded = $expectations[$key]
                break
            }
        }

        $signal = $(if ($job.PSObject.Properties.Name -contains 'Signal') { [string]$job.Signal } else { '' })

        $expect = $(if ($recorded) { $recorded.Expect } else { Get-ExpectedForSignal -Signal $signal })
        $residual = $(if ($recorded) { $recorded.Residual } else { $null })
        $why = $(if ($recorded) { $recorded.Reason }
            elseif ($expect) { "derived from signal $signal" }
            else { '' })

        $job | Add-Member -NotePropertyName Expected -NotePropertyValue $expect -Force
        $job | Add-Member -NotePropertyName ExpectedResidual -NotePropertyValue $residual -Force
        $job | Add-Member -NotePropertyName ExpectedReason -NotePropertyValue $why -Force
        $hydrated += $job
    }

    return $hydrated
}

function Get-SportNotApplicable {
    # Parameters the sport is documented as never being able to supply, each with the reason
    # it cannot. A missing value and an impossible one look identical to the placeholder
    # scanner, so without this the runner reports "needs X" for a sport that will never have
    # an X, and the reader has to open the sport file to learn which of the two it is.
    param([string]$SportName)

    $resolved = @{}
    $path = Join-Path $RepoRoot 'SPORTS\params.json'
    if (-not (Test-Path -LiteralPath $path)) { return $resolved }

    try {
        $params = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        return $resolved
    }

    $entry = $params.PSObject.Properties | Where-Object { $_.Name -eq $SportName }
    if (-not $entry) { return $resolved }

    $block = $entry.Value.PSObject.Properties | Where-Object { $_.Name -eq $NotApplicableKey }
    if (-not $block) { return $resolved }

    foreach ($property in $block.Value.PSObject.Properties) {
        $resolved[$property.Name] = [string]$property.Value
    }
    return $resolved
}

function Resolve-SportParameters {
    # Fills the placeholders that are structural facts about a sport. Everything here is
    # read from the database rather than assumed: DATABASE.md DB-SEM-006 records that the
    # statistic type does not determine the physical shard, so the shard is probed.
    param([string]$DatabaseSportNameValue)

    $resolved = @{}
    Write-Host "Discovering parameters for database sport '$DatabaseSportNameValue'..." -ForegroundColor DarkGray

    $literal = Get-SqlLiteral -Text $DatabaseSportNameValue
    $response = Invoke-SqlWithRetry -Statement `
        "SELECT id AS sport_id, name AS sport_name FROM sport WHERE del = 'no' AND name = $literal ORDER BY id;"
    # Get-ResultRows returns its array comma-wrapped so a single row is not unrolled.
    # Wrapping the call in @() would therefore nest it, not flatten it; assign it plain.
    $hits = Get-ResultRows -Content $response.Content

    if ($hits.Count -eq 0) {
        throw "No active sport is named '$DatabaseSportNameValue'. Names are exact; list them with -Sql ""SELECT id, name FROM sport WHERE del='no' ORDER BY name;"""
    }
    if ($hits.Count -gt 1) {
        throw "'$DatabaseSportNameValue' matches $($hits.Count) active sports. Pass -SportId instead."
    }

    $sportId = [int]$hits[0].sport_id
    $resolved['SPORT_ID'] = $sportId
    Write-Host ("  SPORT_ID                 {0}" -f $sportId) -ForegroundColor DarkGray

    # The statistic type and owner come from the catalogue's own discovery statement, so
    # the runner cannot drift from what the documented query reports.
    $inventory = @(Get-CheckCatalogue | Where-Object { $_.CheckId -eq 'GLOBAL-DISCOVERY-015' })
    if ($inventory.Count -ne 1) {
        Write-Host '  GLOBAL-DISCOVERY-015 not found; statistic parameters stay unresolved.' -ForegroundColor DarkGray
        return $resolved
    }

    $statement = Expand-Placeholders -Text $inventory[0].Sql -Values @{ SPORT_ID = $sportId }
    $rows = Get-ResultRows -Content (Invoke-SqlWithRetry -Statement $statement).Content
    if ($rows.Count -eq 0) {
        Write-Host '  the sport has no statistics; statistic parameters stay unresolved.' -ForegroundColor DarkGray
        return $resolved
    }

    # More than one type/owner pair is possible. The busiest is the useful default, and the
    # others are named so the choice is visible rather than silent.
    $ranked = @($rows | Sort-Object { [int]$_.statistic_count } -Descending)
    $chosen = $ranked[0]
    $resolved['STATISTIC_TYPE_ID'] = [int]$chosen.statistic_type_id
    $resolved['STATISTIC_OWNER_TYPE_ID'] = [int]$chosen.statistic_owner_type_id

    Write-Host ("  STATISTIC_TYPE_ID        {0}  ({1})" -f $chosen.statistic_type_id, $chosen.statistic_type_name) -ForegroundColor DarkGray
    Write-Host ("  STATISTIC_OWNER_TYPE_ID  {0}  ({1}, {2} statistics)" -f `
            $chosen.statistic_owner_type_id, $chosen.owner_path, $chosen.statistic_count) -ForegroundColor DarkGray

    # The one choice in this whole run that everything downstream inherits: 016, 017, 024, 025,
    # 028, 029 and every Comp.Rank template read the sport through it. Printed as a grey line it
    # was easy to miss; recorded here it has to be answered before it can become a params.json
    # entry that later runs treat as established.
    $others = @($ranked | Select-Object -Skip 1 | ForEach-Object {
            'type {0} / owner {1} ({2}, {3} statistics)' -f `
                $_.statistic_type_id, $_.statistic_owner_type_id, $_.owner_path, $_.statistic_count
        })

    if ($others.Count -gt 0) {
        Write-Host ("  other pairs not used: {0}" -f ($others -join '; ')) -ForegroundColor DarkGray
    }

    Add-RunDecision -Kind 'Statistic type and owner' `
        -Subject 'STATISTIC_TYPE_ID, STATISTIC_OWNER_TYPE_ID' `
        -Chose ('type {0} / owner {1} ({2}, {3} statistics)' -f `
            $chosen.statistic_type_id, $chosen.statistic_owner_type_id, $chosen.owner_path, $chosen.statistic_count) `
        -Why $(if ($others.Count -eq 0) {
                'GLOBAL-DISCOVERY-015 returned one pair, so nothing was chosen'
            }
            else { 'the busiest pair GLOBAL-DISCOVERY-015 returned; a count, not a documented fact' }) `
        -Alternatives $(if ($others.Count -eq 0) { @('none - one candidate') } else { $others })

    # Shard: probe one table per execution, as WORKFLOW.md requires, using a statistic the
    # inventory already confirmed belongs to this sport.
    $sample = $chosen.sample_statistic_id
    if (-not $sample) { return $resolved }

    $shardRows = Get-ResultRows -Content (Invoke-SqlWithRetry -Statement (
            "SELECT table_name AS shard_table FROM information_schema.tables " +
            "WHERE table_schema = DATABASE() AND table_name REGEXP '^statistic_participants[0-9]+$' " +
            "ORDER BY CAST(SUBSTRING(table_name, 23) AS UNSIGNED);")).Content

    foreach ($shardRow in $shardRows) {
        $table = [string]$shardRow.shard_table
        $number = [regex]::Match($table, '(\d+)$').Groups[1].Value
        if (-not $number) { continue }

        $probe = Get-ResultRows -Content (Invoke-SqlWithRetry -Statement (
                "SELECT COUNT(*) AS c FROM $table WHERE statisticFK = $sample AND del = 'no';")).Content

        if ($probe.Count -gt 0 -and [int]$probe[0].c -gt 0) {
            $resolved['SHARD_ID'] = [int]$number
            Write-Host ("  SHARD_ID                 {0}  (confirmed on {1})" -f $number, $table) -ForegroundColor DarkGray
            break
        }
    }

    if (-not $resolved.ContainsKey('SHARD_ID')) {
        Write-Host '  no shard holds rows for the sample statistic; SHARD_ID stays unresolved.' -ForegroundColor DarkGray
    }

    return $resolved
}

function Get-ResultRows {
    param([string]$Content)

    try {
        $parsed = $Content | ConvertFrom-Json
    }
    catch {
        throw "Server did not return JSON. First 300 characters:`n" + $Content.Substring(0, [Math]::Min(300, $Content.Length))
    }

    if ($parsed -is [array]) { return , $parsed }

    # The app wraps results as { "sql": "<echo>", "response": [ {col: val}, ... ] }.
    # A string or object under that key is an error message, not a result set.
    foreach ($name in @('response', 'data', 'rows', 'result', 'results', 'records')) {
        if ($parsed.PSObject.Properties.Name -contains $name) {
            $value = $parsed.$name
            if ($null -eq $value) { return , @() }
            if ($value -is [string]) { throw "Query API returned an error: $value" }
            if ($value -is [array]) { return , $value }
            return , @($value)
        }
    }

    foreach ($name in @('error', 'message', 'exception')) {
        if ($parsed.PSObject.Properties.Name -contains $name) {
            throw "Query API returned an error: $($parsed.$name)"
        }
    }

    return , @($parsed)
}

function Add-CheckColumns {
    # Exported rows stay identifiable once they are out of this shell.
    param($Rows, [string]$CheckId, [string]$Name)

    if ([string]::IsNullOrWhiteSpace($CheckId)) { return , @($Rows) }

    $tagged = @()
    foreach ($row in $Rows) {
        $ordered = [ordered]@{ check_id = $CheckId; check_name = $Name }
        foreach ($property in $row.PSObject.Properties) { $ordered[$property.Name] = $property.Value }
        $tagged += [pscustomobject]$ordered
    }
    return , $tagged
}

function Get-SportFromCheckId {
    # CheckIDs are <SportSlug>-DQ-NNN or GLOBAL-DISCOVERY-NNN, so the prefix names the sport.
    # A GLOBAL statement is the exception: its prefix names the catalogue it lives in, not
    # what it was run against. Under -Sport that answer is known, and it is the one the
    # reader of the workbook wants, so it wins over the prefix.
    param([string]$CheckId)

    if ([string]::IsNullOrWhiteSpace($CheckId)) { return 'AD-HOC' }

    $prefix = if ($CheckId -match '^(.+?)-(?:DQ|DISCOVERY)-\d+$') { $matches[1] } else { ($CheckId -split '-')[0] }
    if ($prefix -eq 'GLOBAL' -and -not [string]::IsNullOrWhiteSpace($script:RunSportName)) {
        return $script:RunSportName
    }
    return $prefix
}

function Get-RunSport {
    param($Jobs)

    $sports = @($Jobs | ForEach-Object { Get-SportFromCheckId -CheckId $_.CheckId } | Select-Object -Unique)
    if ($sports.Count -eq 1) { return $sports[0] }
    return 'MIXED'
}

function Get-RunFolder {
    param($Jobs)

    # Windows rejects ':' in a path, so the run time separates with hyphens.
    $stamp = Get-Date -Format 'dd.MM.yyyy HH-mm-ss'
    return Join-Path $OutputRoot ('{0} {1}' -f (Get-RunSport -Jobs $Jobs), $stamp)
}

function Get-JobRunKey {
    # What identifies one execution. Normally the CheckID, which is what a check is; under
    # -Chain the same statement runs once per value it was fed, and only the values tell those
    # executions apart. Nothing here is a CheckID: POWERBI.md forbids minting one, and a run
    # key never leaves the run it names.
    param($Job)

    if ($null -eq $Job) { return '' }
    if ($Job.PSObject.Properties.Name -contains 'RunKey' -and $Job.RunKey) { return [string]$Job.RunKey }
    return [string]$Job.CheckId
}

function Get-SafeFileName {
    param([string]$CheckId)

    $stem = [regex]::Replace($CheckId, '[^A-Za-z0-9._-]+', '_')
    if (-not $stem) { $stem = 'query' }
    if ($stem.Length -gt 120) { $stem = $stem.Substring(0, 120) }
    return $stem
}

# --------------------------------------------------------------------------------------
# Workbook writing
#
# An .xlsx is a zip of XML parts, so it can be produced with nothing but the .NET
# libraries that ship with Windows. That keeps the tool working on a machine with
# neither Excel nor the ImportExcel module installed.
# --------------------------------------------------------------------------------------

function Get-ExcelColumnName {
    param([int]$Index)

    $name = ''
    while ($Index -gt 0) {
        $remainder = ($Index - 1) % 26
        $name = [char](65 + $remainder) + $name
        $Index = [int](($Index - $remainder - 1) / 26)
    }
    return $name
}

function ConvertTo-XmlText {
    param([string]$Text)

    if ([string]::IsNullOrEmpty($Text)) { return '' }
    # Control characters are not representable in XML 1.0 and would corrupt the part.
    $clean = [regex]::Replace($Text, '[\x00-\x08\x0B\x0C\x0E-\x1F]', '')
    return [Security.SecurityElement]::Escape($clean)
}

# Check names run past Excel's 31-character tab limit far more often than not, and they
# differ in their suffix, so plain truncation hides exactly the distinguishing part. Word
# level abbreviation of the recurring object and condition terms fixes almost all of it:
# over the current catalogue of 70 statements it takes the count needing truncation from
# 44 down to 3, with every resulting tab name still unique.
$XlsxNameAbbreviations = @{
    'COMP.RANK' = 'CR'; 'PARTICIPANTS' = 'PTCS'; 'PARTICIPANT' = 'PTC'; 'PARTICIPATION' = 'PART'
    'TOURNAMENTS' = 'TRNS'; 'TOURNAMENT' = 'TRN'; 'TEMPLATE' = 'TPL'; 'STAGES' = 'STGS'
    'STAGE' = 'STG'; 'RESULTS' = 'RES'; 'SETTINGS' = 'SET'; 'MISSING' = 'MISS'
    'MISMATCH' = 'MISM'; 'UNEXPECTED' = 'UNEXP'; 'INVALID' = 'INVLD'; 'DEPRECATED' = 'DEPR'
    'DURATION' = 'DUR'; 'DIFFERENCE' = 'DIFF'; 'FORMAT' = 'FMT'; 'RELATED' = 'REL'
    'DISCIPLINE' = 'DISC'; 'GENDER' = 'GEN'; 'SUBSET' = 'SUBS'; 'EVENT' = 'EV'
    'REFERENCE' = 'REF'; 'STATISTIC' = 'STAT'; 'REGISTRY' = 'REG'; 'PATTERNS' = 'PTRN'
    'SUMMARY' = 'SUM'; 'DETAIL' = 'DET'; 'DECLARED' = 'DECL'; 'STORAGE' = 'STOR'
    'PROFILE' = 'PROF'; 'FIELDS' = 'FLDS'
}

function Get-ShortSheetName {
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) { return $Name }

    $tokens = $Name -split '_' | ForEach-Object {
        if ($XlsxNameAbbreviations.ContainsKey($_)) { $XlsxNameAbbreviations[$_] } else { $_ }
    }
    return ($tokens -join '_')
}

function ConvertTo-SheetName {
    # Excel caps sheet names at 31 characters, forbids : \ / ? * [ ] and demands
    # uniqueness. Google Sheets keeps whatever names the file carries.
    param([string]$Preferred, [string]$Fallback, [hashtable]$Used)

    $name = $Preferred
    if ([string]::IsNullOrWhiteSpace($name)) { $name = $Fallback }
    $name = [regex]::Replace($name, '[:\\/?*\[\]]', '_').Trim()
    if ($name.Length -gt 31) { $name = $name.Substring(0, 31) }
    if ([string]::IsNullOrWhiteSpace($name)) { $name = 'sheet' }

    $base = $name
    $counter = 2
    while ($Used.ContainsKey($name.ToLowerInvariant())) {
        $suffix = "~$counter"
        $keep = [Math]::Min($base.Length, 31 - $suffix.Length)
        $name = $base.Substring(0, $keep) + $suffix
        $counter++
    }

    $Used[$name.ToLowerInvariant()] = $true
    return $name
}

function New-XlsxFormula {
    # A cell that computes instead of holding text. Wrapped in a type of its own so that
    # Get-CellXml can tell it from a string that merely starts with '=', which a reviewer's
    # comment legitimately might.
    param([string]$Formula)

    return [pscustomobject]@{ PSTypeName = 'Xlsx.Formula'; Formula = $Formula }
}

function Get-CellXml {
    # Style 1 is the hyperlink look defined in Get-StylesXml; 0 is the default.
    param([string]$Reference, $Value, [int]$Style = 0)

    if ($null -eq $Value) { return '' }

    $styleAttribute = if ($Style -gt 0) { ' s="{0}"' -f $Style } else { '' }

    # No cached <v>: the value is whatever the other sheet holds when the file is opened,
    # and a stale cached one would be shown until something forced a recalculation.
    # Get-WorkbookXml sets fullCalcOnLoad so the reader computes it on open.
    if ($Value.PSObject.TypeNames -contains 'Xlsx.Formula') {
        if ([string]::IsNullOrEmpty($Value.Formula)) { return '' }
        return '<c r="{0}"{1}><f>{2}</f></c>' -f `
            $Reference, $styleAttribute, (ConvertTo-XmlText -Text $Value.Formula)
    }

    if ($XlsxNumericTypes -contains $Value.GetType()) {
        # Invariant formatting, or a bg-BG decimal comma would make Excel read
        # the number as text.
        return '<c r="{0}"{1}><v>{2}</v></c>' -f `
            $Reference, $styleAttribute, [string]::Format($XlsxInvariant, '{0}', $Value)
    }

    $raw = [string]$Value
    if ($raw -eq '') { return '' }

    # Excel refuses to open a file containing an over-long cell. Trim the text
    # itself, before escaping inflates it.
    if ($raw.Length -gt $XlsxCellLimit) {
        $raw = $raw.Substring(0, $XlsxCellLimit - 20) + ' ...[truncated]'
    }

    return '<c r="{0}"{1} t="inlineStr"><is><t xml:space="preserve">{2}</t></is></c>' -f `
        $Reference, $styleAttribute, (ConvertTo-XmlText -Text $raw)
}

function Get-StylesXml {
    # The smallest style sheet Excel accepts. Font 1 is the blue underline that makes a
    # navigation cell read as a link; the two fills and the border are mandatory entries.
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +
    '<fonts count="2">' +
    '<font><sz val="11"/><name val="Calibri"/></font>' +
    '<font><u/><color rgb="FF0563C1"/><sz val="11"/><name val="Calibri"/></font>' +
    '</fonts>' +
    '<fills count="2">' +
    '<fill><patternFill patternType="none"/></fill>' +
    '<fill><patternFill patternType="gray125"/></fill>' +
    '</fills>' +
    '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>' +
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>' +
    '<cellXfs count="2">' +
    '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>' +
    '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>' +
    '</cellXfs>' +
    '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>' +
    '</styleSheet>'
}

function Add-ZipTextEntry {
    param($Zip, [string]$Name, [string]$Content)

    $entry = $Zip.CreateEntry($Name)
    $writer = New-Object IO.StreamWriter($entry.Open(), (New-Object Text.UTF8Encoding($false)))
    try { $writer.Write($Content) } finally { $writer.Dispose() }
}

function Save-Workbook {
    # $Sheets is a list of objects carrying a Name and a Rows collection.
    param($Sheets, [string]$Path)

    Add-Type -AssemblyName System.IO.Compression | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (Test-Path $Path) { Remove-Item -LiteralPath $Path -Force }

    $stream = [IO.File]::Create($Path)
    $zip = New-Object IO.Compression.ZipArchive($stream, [IO.Compression.ZipArchiveMode]::Create)

    try {
        $overrides = New-Object Text.StringBuilder
        $sheetTags = New-Object Text.StringBuilder
        $relTags = New-Object Text.StringBuilder

        $index = 0
        foreach ($sheet in $Sheets) {
            $index++
            $rows = @($sheet.Rows)

            # Columns are unioned across rows, because a later row may carry a key
            # the first one lacked. Membership goes through a hashtable rather than
            # -notcontains: this runs once per cell, and the interim snapshots repeat
            # the whole build several times per run.
            $columns = @()
            $seenColumn = @{}
            foreach ($row in $rows) {
                foreach ($property in $row.PSObject.Properties) {
                    if (-not $seenColumn.ContainsKey($property.Name)) {
                        $seenColumn[$property.Name] = $true
                        $columns += $property.Name
                    }
                }
            }

            $xml = New-Object Text.StringBuilder
            [void]$xml.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
            [void]$xml.Append('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">')

            # The schema fixes this order too: cols before sheetData. A hidden column keeps
            # its heading and its values and still exports - it is only collapsed out of the
            # reader's way, and unhiding it is a two-click undo. The width is carried so a
            # column reopened by hand comes back readable instead of at Excel's default.
            $hiddenColumns = @(if ($null -eq $sheet.HiddenColumns) { @() } else { $sheet.HiddenColumns })
            if ($hiddenColumns.Count -gt 0) {
                [void]$xml.Append('<cols>')
                foreach ($column in $hiddenColumns) {
                    [void]$xml.Append(('<col min="{0}" max="{0}" width="20" customWidth="1" hidden="1"/>' -f $column))
                }
                [void]$xml.Append('</cols>')
            }

            [void]$xml.Append('<sheetData>')

            # Identity lives once on row 1 rather than repeated down every data row.
            # Row 2 is deliberately skipped: sheetData tolerates gaps, and the blank
            # line keeps the table below a self-contained block for sorting and
            # filtering. OOXML row numbering must still ascend.
            # @($null) yields a one-element array, so the null is tested before wrapping,
            # and the result of an if statement is enumerated, so a one-element array
            # inside it would collapse to the element and lose .Count unless the whole
            # statement is wrapped.
            $header = @(if ($null -eq $sheet.Header) { @() } else { $sheet.Header })
            $headerRow = ($header.Count -gt 0)

            $links = @(if ($null -eq $sheet.Links) { @() } else { $sheet.Links })
            if ($sheet.BackTo) {
                $links += [pscustomobject]@{ Ref = 'A3'; Target = $sheet.BackTo; Text = 'Return to Overview' }
            }
            $linked = @{}
            foreach ($link in $links) { $linked[$link.Ref] = $true }

            # A check tab opens with a labelled identity block:
            #   row 1  Check ID | Check Name | SQL Used | Priority | Category | What it does |
            #          Comment | Check By | Signal | Signal reason | Parameters
            #   row 2  the values, with Comment and Check By left empty for the reviewer
            #   row 3  the link back to Overview, in a cell of its own
            #   row 4  blank, so the result table below stays its own block
            # SQL Used stays at C, because C2 is where the jump to the statement lives, so
            # Parameters - which only a chained run fills - is appended at the end instead.
            if ($headerRow) {
                $labels = @('Check ID', 'Check Name', 'SQL Used', 'Priority', 'Category',
                    'What it does', 'Comment', 'Check By', 'Signal', 'Signal reason', 'Parameters')

                [void]$xml.Append('<row r="1">')
                for ($c = 0; $c -lt $header.Count; $c++) {
                    $ref = (Get-ExcelColumnName -Index ($c + 1)) + '1'
                    [void]$xml.Append((Get-CellXml -Reference $ref -Value $labels[$c]))
                }
                [void]$xml.Append('</row>')

                [void]$xml.Append('<row r="2">')
                for ($c = 0; $c -lt $header.Count; $c++) {
                    $ref = (Get-ExcelColumnName -Index ($c + 1)) + '2'
                    $style = if ($linked.ContainsKey($ref)) { 1 } else { 0 }
                    [void]$xml.Append((Get-CellXml -Reference $ref -Value $header[$c] -Style $style))
                }
                [void]$xml.Append('</row>')

                if ($sheet.BackTo) {
                    [void]$xml.Append('<row r="3">')
                    [void]$xml.Append((Get-CellXml -Reference 'A3' -Value 'Return to Overview' -Style 1))
                    [void]$xml.Append('</row>')
                }
            }

            $rowNumber = if ($headerRow) { 5 } else { 1 }

            [void]$xml.Append(('<row r="{0}">' -f $rowNumber))
            for ($c = 0; $c -lt $columns.Count; $c++) {
                $ref = (Get-ExcelColumnName -Index ($c + 1)) + $rowNumber
                [void]$xml.Append((Get-CellXml -Reference $ref -Value $columns[$c]))
            }
            [void]$xml.Append('</row>')

            foreach ($row in $rows) {
                $rowNumber++
                [void]$xml.Append(('<row r="{0}">' -f $rowNumber))

                for ($c = 0; $c -lt $columns.Count; $c++) {
                    $ref = (Get-ExcelColumnName -Index ($c + 1)) + $rowNumber
                    $style = if ($linked.ContainsKey($ref)) { 1 } else { 0 }
                    [void]$xml.Append((Get-CellXml -Reference $ref -Value $row.($columns[$c]) -Style $style))
                }

                [void]$xml.Append('</row>')
            }

            [void]$xml.Append('</sheetData>')

            # The schema fixes this order: dataValidations before hyperlinks.
            if ($sheet.Validation) {
                [void]$xml.Append(('<dataValidations count="1"><dataValidation type="list" allowBlank="1" showInputMessage="1" showErrorMessage="1" sqref="{0}"><formula1>"{1}"</formula1></dataValidation></dataValidations>' -f `
                            $sheet.Validation.Sqref, (ConvertTo-XmlText -Text $sheet.Validation.Values)))
            }

            # Google Sheets ignores a linked cell's own value and labels it from the
            # hyperlink record: with a display attribute it shows that, without one it
            # falls back to the raw "#gid=..." target. So display carries the label the
            # cell should read, and must never be set to the location. Excel takes its
            # label from the cell value, which is kept identical.
            if ($links.Count -gt 0) {
                [void]$xml.Append('<hyperlinks>')
                foreach ($link in $links) {
                    # A link into the SQL sheet has to land on the block it belongs to, not on
                    # the top of a sheet holding every statement in the run.
                    $cell = 'A1'
                    if ($link.PSObject.Properties.Name -contains 'Cell' -and $link.Cell) {
                        $cell = [string]$link.Cell
                    }
                    $location = "'" + ($link.Target -replace "'", "''") + "'!" + $cell
                    [void]$xml.Append(('<hyperlink ref="{0}" location="{1}" display="{2}"/>' -f `
                                $link.Ref, (ConvertTo-XmlText -Text $location), (ConvertTo-XmlText -Text $link.Text)))
                }
                [void]$xml.Append('</hyperlinks>')
            }

            [void]$xml.Append('</worksheet>')
            Add-ZipTextEntry -Zip $zip -Name "xl/worksheets/sheet$index.xml" -Content $xml.ToString()

            [void]$overrides.Append(('<Override PartName="/xl/worksheets/sheet{0}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>' -f $index))
            [void]$sheetTags.Append(('<sheet name="{0}" sheetId="{1}" r:id="rId{1}"/>' -f (ConvertTo-XmlText -Text $sheet.Name), $index))
            [void]$relTags.Append(('<Relationship Id="rId{0}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet{0}.xml"/>' -f $index))
        }

        $stylesRelId = 'rId' + ($index + 1)
        Add-ZipTextEntry -Zip $zip -Name 'xl/styles.xml' -Content (Get-StylesXml)
        [void]$relTags.Append(('<Relationship Id="{0}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>' -f $stylesRelId))

        Add-ZipTextEntry -Zip $zip -Name '[Content_Types].xml' -Content (
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
            '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
            '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' +
            '<Default Extension="xml" ContentType="application/xml"/>' +
            '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' +
            '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>' +
            $overrides.ToString() + '</Types>')

        Add-ZipTextEntry -Zip $zip -Name '_rels/.rels' -Content (
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>' +
            '</Relationships>')

        Add-ZipTextEntry -Zip $zip -Name 'xl/workbook.xml' -Content (
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
            '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" ' +
            'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>' +
            $sheetTags.ToString() + '</sheets>' +
            # The formula cells carry no cached result, so the reader is told to compute the
            # book once on open. The schema fixes this order: calcPr comes after sheets.
            '<calcPr calcId="0" fullCalcOnLoad="1"/>' +
            '</workbook>')

        Add-ZipTextEntry -Zip $zip -Name 'xl/_rels/workbook.xml.rels' -Content (
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
            $relTags.ToString() + '</Relationships>')
    }
    finally {
        $zip.Dispose()
        $stream.Dispose()
    }
}

function New-SqlSheet {
    # The statement each check ran, one line per row, on a sheet of its own.
    #
    # It used to sit in C2 of every check tab: one cell holding a few thousand characters on a
    # single line. Nothing about that was readable, and opening the cell pushed the result
    # table below it out of place. Here the statement keeps its line breaks, C2 becomes the
    # jump to the right block, and the block's first cell jumps back to the results.
    param($Entries, $TabOf, [string]$SheetName = 'SQL')

    $entries = @($Entries)
    if ($entries.Count -eq 0) { return $null }

    $rows = @()
    $links = @()
    $anchor = @{}
    $rowNumber = 1   # row 1 carries the column names the writer emits from the row objects

    foreach ($entry in $entries) {
        $rowNumber++
        # Anchored per execution, not per CheckID: a chained statement appears here once per
        # value it ran with, and each block holds the statement that actually went out.
        $key = $(if ($entry.PSObject.Properties.Name -contains 'Key' -and $entry.Key) {
                [string]$entry.Key
            }
            else { [string]$entry.CheckId })

        $anchor[$key] = "A$rowNumber"
        $rows += [pscustomobject]@{ 'Check ID' = $key; 'Statement' = $entry.Name }

        if ($TabOf -and $TabOf.ContainsKey($key)) {
            $links += [pscustomobject]@{
                Ref    = "A$rowNumber"
                Target = $TabOf[$key]
                Text   = $key
            }
        }

        foreach ($line in ([string]$entry.Sql -split '\r?\n')) {
            $rowNumber++
            $rows += [pscustomobject]@{ 'Check ID' = ''; 'Statement' = $line }
        }

        # One blank row, so two consecutive statements read as two blocks.
        $rowNumber++
        $rows += [pscustomobject]@{ 'Check ID' = ''; 'Statement' = '' }
    }

    return [pscustomobject]@{
        Sheet  = [pscustomobject]@{
            Name   = $SheetName
            Rows   = $rows
            Header = $null
            BackTo = $null
            Links  = $links
        }
        Anchor = $anchor
        Name   = $SheetName
    }
}

function Save-Rows {
    param($Rows, [string]$Path, [string]$Fmt, [string]$SheetName = 'data', $Header, $SqlEntry)

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }

    if ($Fmt -eq 'xlsx') {
        # A single-sheet workbook has no Overview to link back to. It still gets the SQL sheet,
        # so one check exported on its own reads the same way as one inside a batch.
        $tabOf = @{}
        if ($SqlEntry) { $tabOf[$SqlEntry.CheckId] = $SheetName }
        $sqlSheet = New-SqlSheet -Entries $SqlEntry -TabOf $tabOf

        $sheet = [pscustomobject]@{
            Name   = $SheetName
            Rows   = $Rows
            Header = $Header
            BackTo = $null
        }

        $sheets = @($sheet)
        if ($sqlSheet -and $sqlSheet.Anchor.ContainsKey($SqlEntry.CheckId)) {
            $sheet | Add-Member -NotePropertyName Links -NotePropertyValue @(
                [pscustomobject]@{
                    Ref    = 'C2'
                    Target = $sqlSheet.Name
                    Cell   = $sqlSheet.Anchor[$SqlEntry.CheckId]
                    Text   = 'SQL'
                })
            $sheets += $sqlSheet.Sheet
        }

        Save-Workbook -Path $Path -Sheets $sheets
    }
    elseif ($Fmt -eq 'json') {
        $Rows | ConvertTo-Json -Depth 8 | Out-File -LiteralPath $Path -Encoding utf8
    }
    else {
        $Rows | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8
    }
}

function New-RunSummaryRow {
    # One durable execution record used by both XLSX Overview and flat _summary.csv. The
    # signal defaults here so pattern jobs and older callers cannot accidentally emit an
    # empty classification that a downstream report reads as actionable by guesswork.
    param(
        $Job,
        [int]$Rows,
        [double]$Seconds,
        [string]$Status,
        $Eligible = $null,
        $Findings = $null
    )

    $signal = 'Actionable'
    $reason = ''
    if ($Job.PSObject.Properties.Name -contains 'Signal' -and
        -not [string]::IsNullOrWhiteSpace([string]$Job.Signal)) {
        $signal = [string]$Job.Signal
    }
    if ($Job.PSObject.Properties.Name -contains 'SignalReason') {
        $reason = [string]$Job.SignalReason
    }

    # Only a registry-backed run knows the category: it is authored against the CheckID, not
    # derivable from the statement. A direct template run and a discovery statement leave both
    # fields empty rather than guessing a band for a check nobody has categorised.
    $category = ''
    if ($Job.PSObject.Properties.Name -contains 'Category') {
        $category = [string]$Job.Category
    }

    # RunKey, not CheckId, is what a workbook keys a tab and a coverage count by: -Chain runs
    # one statement once per value, and the CheckID is the same for all of them by design.
    # Parameters is what tells those runs apart for a reader.
    $runKey = $Job.CheckId
    if ($Job.PSObject.Properties.Name -contains 'RunKey' -and $Job.RunKey) { $runKey = [string]$Job.RunKey }

    $parameters = ''
    if ($Job.PSObject.Properties.Name -contains 'Parameters') { $parameters = [string]$Job.Parameters }

    # Eligible and Findings are what make one run comparable with the next, and neither is
    # recoverable from Rows. A raw count mixes the COVERAGE row in with the findings, and it
    # says nothing about the population those findings came out of - so "was 40, now 3" reads
    # as an improvement whether the sport shrank or the data was corrected. Both were being
    # computed already and thrown away with the terminal.
    $expected = ''
    $expectedResidual = $null
    $expectedReason = ''
    if ($Job.PSObject.Properties.Name -contains 'Expected') { $expected = [string]$Job.Expected }
    if ($Job.PSObject.Properties.Name -contains 'ExpectedResidual') { $expectedResidual = $Job.ExpectedResidual }
    if ($Job.PSObject.Properties.Name -contains 'ExpectedReason') { $expectedReason = [string]$Job.ExpectedReason }

    # Computed here rather than in the workbook writer so one place decides it and every
    # destination agrees: the Overview, the flat summary and the ledger entry this run
    # appends all read the same value. $script:PreviousRun was settled before the batch
    # started, so nothing can compare itself against the entry it is about to write.
    $previous = $(if ($script:PreviousRun.ContainsKey($runKey)) { $script:PreviousRun[$runKey] } else { $null })
    $ran = -not ($Status -like 'ERROR*' -or $Status -like 'SKIPPED*')
    $verdict = Get-CheckVerdict -Expected $expected -Residual $expectedResidual `
        -Findings $Findings -Eligible $Eligible -Previous $previous -Ran $ran

    $change = $null
    if ($null -ne $Findings -and $null -ne $previous -and $null -ne $previous.Findings) {
        $change = [int]$Findings - [int]$previous.Findings
    }

    return [pscustomobject]@{
        CheckId     = $Job.CheckId
        RunKey      = $runKey
        Parameters  = $parameters
        Name        = $Job.Name
        What        = $Job.What
        Rows        = $Rows
        Findings    = $Findings
        Eligible    = $Eligible
        Seconds     = $Seconds
        Status      = $Status
        Priority    = Get-CheckPriority -Category $category
        Category    = $category
        Signal      = $signal
        SignalReason = $reason
        Expected     = $expected
        ExpectedResidual = $expectedResidual
        ExpectedReason   = $expectedReason
        Verdict      = $verdict
        Change       = $change
        PrevFindings = $(if ($previous) { $previous.Findings } else { $null })
        PrevEligible = $(if ($previous) { $previous.Eligible } else { $null })
        PrevRunId    = $(if ($previous) { [string]$previous.RunId } else { '' })
    }
}

function Save-RunSummaryCsv {
    param($Summary, [string]$Path)
    $Summary | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8
}

function Get-LedgerPath {
    # $RepoRoot is read at call time rather than folded into a constant at load time, as every
    # other reader of a repository file does: pointing it at a fixture is how Test-Tools.ps1
    # exercises this without writing into the working copy.
    param([string]$Sport)
    return Join-Path (Join-Path $RepoRoot $LedgerDirName) ("{0}.json" -f $Sport)
}

function Read-RunLedger {
    # The sport's ledger as it stands, or an empty one. A file that cannot be parsed is
    # reported and left alone rather than replaced: a run overwriting a history it could not
    # read would destroy the only copy of it, and the history is the reason the file exists.
    param([string]$Sport)

    $path = Get-LedgerPath -Sport $Sport
    if (-not (Test-Path -LiteralPath $path)) {
        return [pscustomobject]@{ sport = $Sport; ledgerVersion = $LedgerVersion; runs = @() }
    }

    try {
        $ledger = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        Write-Host ("  RUNS/{0}.json could not be read, so this run was not recorded: {1}" -f `
                $Sport, $_.Exception.Message) -ForegroundColor Yellow
        return $null
    }

    if ($null -eq $ledger.runs) {
        $ledger | Add-Member -NotePropertyName runs -NotePropertyValue @() -Force
    }
    return $ledger
}

function Import-PreviousRunEntries {
    # What the last run recorded for each statement this run is about to execute, keyed by
    # run key. Walked forward so the newest entry wins.
    #
    # A run that failed or was skipped is passed over rather than recorded as the previous
    # one. Comparing against an error says nothing, and the reading a reviewer wants is
    # against the last time the check actually produced a number - which may be two runs ago.
    param($Jobs)

    $previous = @{}
    $sports = @($Jobs | ForEach-Object { Get-SportFromCheckId -CheckId $_.CheckId } | Select-Object -Unique)

    foreach ($sport in $sports) {
        if ($sport -in @('AD-HOC', 'GLOBAL', '')) { continue }
        $ledger = Read-RunLedger -Sport $sport
        if ($null -eq $ledger) { continue }

        foreach ($run in @($ledger.runs)) {
            foreach ($check in @($run.checks)) {
                if ($null -eq $check.findings) { continue }
                $status = [string]$check.status
                if ($status -like 'ERROR*' -or $status -like 'SKIPPED*') { continue }

                $previous[[string]$check.runKey] = [pscustomobject]@{
                    RunId      = [string]$run.runId
                    StartedUtc = [string]$run.startedUtc
                    Findings   = $check.findings
                    Eligible   = $check.eligible
                }
            }
        }
    }
    return $previous
}

function Get-CheckVerdict {
    # What this run says when read against the last one. The expectation decides what counts
    # as good news, which is the whole reason it is recorded: forty rows is a failure to
    # correct anything on one check and exactly the right answer on another.
    param(
        [string]$Expected,
        $Residual,
        $Findings,
        $Eligible,
        $Previous,
        [bool]$Ran
    )

    # A failed or skipped statement produced nothing to judge, and the Rows cell already says
    # ERROR or SKIPPED. A verdict beside it would assert that somebody read an output that
    # does not exist. Same for a statement with no COVERAGE row to subtract - a discovery
    # census has no findings to count.
    if (-not $Ran) { return '' }
    if ($null -eq $Findings) { return '' }

    # POWERBI.md is explicit that this is never clean data, so it outranks every comparison:
    # a check auditing nothing returns the same numbers whether the scope is misdirected or
    # the population is legitimately empty, and both want a person before anything else.
    if ($null -ne $Eligible -and [int]$Eligible -eq 0) { return 'Audited nothing' }

    $now = [int]$Findings

    # Read before any comparison, because zero findings is a statement about the data and not
    # about the population it came out of. A check that should reach zero and did is resolved
    # however much the sport grew; a check whose findings are population-wide and returned
    # none is almost certainly broken, and that is worth saying loudly rather than filing as
    # the best result on the board.
    if ($Expected -eq 'Zero' -and $now -eq 0) { return 'Resolved' }
    if ($Expected -eq 'Non-zero' -and $now -eq 0) { return 'Unexpectedly empty' }

    # An agreed remainder is an absolute count of rows somebody decided to leave, so it is
    # judged against itself rather than against the run before it.
    if ($Expected -eq 'Residual') {
        $limit = $(if ($null -ne $Residual) { [int]$Residual } else { 0 })
        if ($now -gt $limit) { return 'Above residual' }
        return 'As expected'
    }

    if ($null -eq $Previous -or $null -eq $Previous.Findings) { return 'New' }
    $before = [int]$Previous.Findings

    if ($Expected -eq 'Non-zero') {
        # The proportion is the finding, so the proportion is what is compared.
        $rateNow = $null
        $ratePrev = $null
        if ($null -ne $Eligible -and [int]$Eligible -gt 0) { $rateNow = $now / [double][int]$Eligible }
        if ($null -ne $Previous.Eligible -and [int]$Previous.Eligible -gt 0) {
            $ratePrev = $before / [double][int]$Previous.Eligible
        }

        if ($null -eq $rateNow -or $null -eq $ratePrev -or $ratePrev -eq 0) {
            # Nothing to take a proportion of, so the counts are all there is to compare.
            if ($now -lt $before) { return 'Improved' }
            if ($now -eq $before) { return 'As expected' }
            return 'Regressed'
        }

        $move = [math]::Abs($rateNow - $ratePrev) / $ratePrev * 100
        if ($move -le $LedgerRateMovePct) { return 'As expected' }
        if ($rateNow -lt $ratePrev) { return 'Improved' }
        return 'Regressed'
    }

    # Everything from here compares two raw counts, and a raw delta is only comparable while
    # the population behind it is. If the sport gained a fifth again as many objects, fewer
    # findings may still be worse data, and reporting that as an improvement is the one wrong
    # answer this column can give.
    #
    # The guard sits here rather than above the Non-zero branch on purpose. That branch
    # already divides by the population, so a moved one is what it handles correctly rather
    # than something it needs protecting from; running the guard first would have reported
    # Scope moved for a check whose proportion had not shifted at all.
    if ($null -ne $Eligible -and $null -ne $Previous.Eligible -and [int]$Previous.Eligible -gt 0) {
        $drift = [math]::Abs([int]$Eligible - [int]$Previous.Eligible) / [double][int]$Previous.Eligible * 100
        if ($drift -gt $LedgerEligibleDriftPct) { return 'Scope moved' }
    }

    # Expected Zero, or a check the sport gave no expectation at all - a plain reading of the
    # two counts, which is the most that can be said without one.
    if ($now -lt $before) { return 'Improved' }
    if ($now -eq $before) { return 'Unchanged' }
    return 'Regressed'
}

function New-LedgerCheckEntry {
    # One statement's result as the next run will read it. Findings and eligible are carried
    # rather than the row count alone, because the row count cannot be compared: it includes
    # the COVERAGE row, and it says nothing about the population the findings came out of.
    param($Entry)

    $ordered = [ordered]@{
        checkId    = [string]$Entry.CheckId
        runKey     = [string]$Entry.RunKey
        parameters = [string]$Entry.Parameters
        name       = [string]$Entry.Name
        category   = [string]$Entry.Category
        signal     = [string]$Entry.Signal
        expected   = [string]$Entry.Expected
        verdict    = [string]$Entry.Verdict
        rows       = $Entry.Rows
        findings   = $Entry.Findings
        eligible   = $Entry.Eligible
        seconds    = $Entry.Seconds
        status     = [string]$Entry.Status
    }
    if ($null -ne $Entry.ExpectedResidual) { $ordered['residual'] = $Entry.ExpectedResidual }
    return [pscustomobject]$ordered
}

function Save-RunLedger {
    # Append this run to RUNS/<Sport>.json, one file per sport, newest last so a git diff of
    # the file is the run that was just added and nothing else.
    #
    # Discovery statements are left out. They are a census by construction - a round type with
    # a count is not a finding that can be resolved - and recording them would fill the sport's
    # history with numbers nobody is going to compare. The pattern statements -RunAll carries
    # alongside the checks are exactly those, so a -RunAll ledger entry holds the checks only.
    #
    # A run that mixes sports writes to each sport's own file, because a ledger keyed on
    # anything but the sport cannot be read by the next run of that sport.
    param($Summary, [string]$Output)

    if ($NoLedger) { return @() }

    $recordable = @($Summary | Where-Object {
            -not [string]::IsNullOrWhiteSpace([string]$_.CheckId) -and
            ([string]$_.CheckId) -notlike $DiscoveryCheckIdPattern
        })
    if ($recordable.Count -eq 0) { return @() }

    # The run folder's own name, so an entry points at the frozen artifact that produced it.
    # A run printed to the screen has no folder, and falls back to the same stamp the folder
    # would have carried rather than to an empty string nothing can be ordered by.
    $runId = $(if ([string]::IsNullOrWhiteSpace($Output)) {
            $script:RunStartedUtc.ToLocalTime().ToString('dd.MM.yyyy HH-mm-ss')
        }
        else { Split-Path -Leaf $Output })
    $written = @()

    foreach ($group in ($recordable | Group-Object { Get-SportFromCheckId -CheckId $_.CheckId })) {
        $sport = [string]$group.Name
        # AD-HOC has no sport to file under, and GLOBAL means the run carried no sport
        # identity - Get-SportFromCheckId already resolves one when there is one.
        if ($sport -in @('AD-HOC', 'GLOBAL', '')) { continue }

        $ledger = Read-RunLedger -Sport $sport
        if ($null -eq $ledger) { continue }

        $run = [pscustomobject][ordered]@{
            runId      = $runId
            startedUtc = $script:RunStartedUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
            output     = [string]$Output
            checks     = @($group.Group | ForEach-Object { New-LedgerCheckEntry -Entry $_ })
        }

        $ledger.runs = @($ledger.runs) + $run
        $ledger.ledgerVersion = $LedgerVersion
        $ledger.sport = $sport

        $path = Get-LedgerPath -Sport $sport
        $dir = Split-Path -Parent $path
        if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

        # No byte-order mark, for the same reason _decisions.json has none: ConvertFrom-Json
        # reads one as part of the first property name, so the next run could not read back
        # the file this one wrote.
        try {
            [IO.File]::WriteAllText($path, ($ledger | ConvertTo-Json -Depth 6),
                (New-Object Text.UTF8Encoding $false))
            $written += $path
        }
        catch {
            Write-Host ("  RUNS/{0}.json could not be written: {1}" -f $sport, $_.Exception.Message) -ForegroundColor Yellow
        }
    }

    return $written
}

function Save-RunDecisions {
    # The open decisions as data, next to whatever else the run wrote. JSON rather than only a
    # workbook tab because this list is meant to be read by the next step of the workflow, and a
    # tab inside a zip is not something a later run or a reviewer's script can pick up.
    # Writing nothing when there is nothing open is deliberate: an empty file would read as a
    # run that had no decisions rather than one that recorded none.
    param($Decisions, [string]$Path)

    $decisions = @($Decisions)
    if ($decisions.Count -eq 0) { return $null }

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    # Always a JSON array, even for one decision. ConvertTo-Json unwraps a single-element array
    # into a bare object, and a consumer reading the file as a list then either fails or, worse,
    # reads one decision as none.
    $json = if ($decisions.Count -eq 1) {
        '[' + ($decisions[0] | ConvertTo-Json -Depth 5) + ']'
    }
    else { $decisions | ConvertTo-Json -Depth 5 }

    # Written without a byte-order mark. Set-Content -Encoding UTF8 emits one on Windows
    # PowerShell, and ConvertFrom-Json reads it as part of the first property name - so the file
    # meant to be read back by the next step of the workflow could not be. The package validator
    # holds repository files to the same rule.
    [IO.File]::WriteAllText($Path, $json, (New-Object Text.UTF8Encoding $false))
    return $Path
}

function Save-RunWorkbook {
    # Builds the whole workbook out of what the run has produced so far, so one piece of
    # code writes both the interim snapshots and the final file. Returns the checks whose
    # tab name still had to be cut.
    param($Summary, $Collected, [string]$Path)

    # The summary leads, so a clean or failed check is still visible in the
    # workbook even though it has no tab of its own.
    # Overview is reserved first, so a check named the same cannot take the name and
    # leave the links pointing at the wrong tab.
    $used = @{}
    $overviewName = ConvertTo-SheetName -Preferred 'Overview' -Fallback 'Overview' -Used $used

    # Read from the result rows rather than carried on the summary, because the summary holds
    # a row count and the count is exactly what cannot tell a clean check from a dead one.
    #
    # Keyed by RunKey throughout: under -Chain one CheckID runs several times with different
    # values, and keying by CheckID would give all of those runs the last one's tab and the
    # last one's coverage count.
    $eligibleOf = @{}
    foreach ($item in $Collected) {
        $eligibleOf[(Get-JobRunKey -Job $item.Job)] = Get-CoverageCount -Rows $item.Rows
    }

    $tabOf = @{}
    $shortened = @()
    foreach ($item in $Collected) {
        $runKey = Get-JobRunKey -Job $item.Job
        $preferred = if ($item.Job.Name) { $item.Job.Name } else { $item.Job.CheckId }
        $abbreviated = Get-ShortSheetName -Name $preferred
        $sheetName = ConvertTo-SheetName -Preferred $abbreviated -Fallback $item.Job.CheckId -Used $used
        $tabOf[$runKey] = $sheetName
        # Abbreviation is lossless enough to pass unreported; only a name that still had
        # to be cut is worth flagging.
        if ($sheetName -ne $abbreviated) {
            $shortened += [pscustomobject]@{ CheckId = $runKey; Wanted = $preferred; Tab = $sheetName }
        }
    }

    # Rows is both the count and the jump to its tab: the display attribute keeps the
    # number readable in Google Sheets, so the link costs the cell nothing. A check that
    # failed has no tab and stays unlinked. Status is a manual tracking field.
    $overviewRows = @()
    $links = @()
    $overviewRow = 1

    foreach ($entry in $Summary) {
        $overviewRow++
        # A check that failed or never ran would otherwise read as a clean zero.
        $rowsCell = switch -Wildcard ($entry.Status) {
            'ERROR*' { 'ERROR' }
            'SKIPPED*' { 'SKIPPED' }
            default { $entry.Rows }
        }
        $ran = ($rowsCell -isnot [string])

        $signalValue = $(if ($entry.Signal) { $entry.Signal } else { 'Actionable' })

        $runKey = $(if ($entry.PSObject.Properties.Name -contains 'RunKey' -and $entry.RunKey) {
                [string]$entry.RunKey
            }
            else { [string]$entry.CheckId })

        $eligible = $(if ($eligibleOf.ContainsKey($runKey)) { $eligibleOf[$runKey] } else { $null })
        $seededStatus = Get-SeededStatus -Signal $signalValue -Rows $rowsCell -Ran $ran -Eligible $eligible

        # Parameters sits beside the CheckID because it is part of what was run, not a result:
        # three rows carrying GLOBAL-DISCOVERY-019 differ in nothing else.
        $overviewRows += [pscustomobject]@{
            'Sport'         = Get-SportFromCheckId -CheckId $entry.CheckId
            'CheckID'       = $entry.CheckId
            'Parameters'    = $(if ($entry.PSObject.Properties.Name -contains 'Parameters') { [string]$entry.Parameters } else { '' })
            'Check Name'    = $entry.Name
            'Priority'      = [string]$entry.Priority
            'Category'      = [string]$entry.Category
            'What it does'  = $entry.What
            'Rows'          = $rowsCell
            'Status'        = $seededStatus
            'Check By'      = ''
            # Mirrored from the check tab rather than typed here: the comment is formed while
            # reading the rows, so it is written where the rows are, and Overview is the board
            # that shows all of them at once. One direction only - a cell holds a value or a
            # formula, never both, so the two cannot each feed the other. This is the safer of
            # the two directions: overwriting the mirror costs the mirror, while overwriting a
            # mirror on the tab would cost the text somebody actually wrote.
            'Comment'       = $(
                if ($ran -and $tabOf.ContainsKey($runKey)) {
                    New-XlsxFormula -Formula ("='" + ($tabOf[$runKey] -replace "'", "''") + "'!G2")
                }
                else { '' })
            'Signal'        = $signalValue
            'Signal reason' = [string]$entry.SignalReason
            # Appended after the hidden signal pair rather than inserted beside Rows, because
            # H, I, K and L:M are pinned in three places at once - this row builder, the
            # validation sqref below and the assertions in Test-Tools.ps1 - and moving them
            # would break the row-count link, the Status dropdown and the Comment mirror
            # together. The comparison block therefore starts at N.
            'Expected'      = [string]$entry.Expected
            'Findings'      = $entry.Findings
            'Eligible'      = $entry.Eligible
            'Prev findings' = $entry.PrevFindings
            'Prev eligible' = $entry.PrevEligible
            'Change'        = $entry.Change
            'Verdict'       = [string]$entry.Verdict
            'Last run'      = [string]$entry.PrevRunId
        }
        # Rows carries the jump to the tab, so its column moves with it - H since Parameters
        # was inserted at C.
        if ($ran -and $tabOf.ContainsKey($runKey)) {
            $links += [pscustomobject]@{
                Ref    = "H$overviewRow"
                Target = $tabOf[$runKey]
                Text   = [string]$entry.Rows
            }
        }
    }

    # Decisions sits second, right where a reader arrives from Overview, because what the run
    # decided for itself has to be read before what it found. Answer is the reader's column, in
    # the same spirit as Check By: the runner writes the question and never the answer.
    $decisionSheet = $null
    if ($script:RunDecision.Count -gt 0) {
        $decisionSheet = [pscustomobject]@{
            Name   = (ConvertTo-SheetName -Preferred 'Decisions' -Fallback 'Decisions' -Used $used)
            Rows   = @($script:RunDecision)
            Header = $null
            BackTo = $null
        }
    }

    # Signal and Signal reason are the runner's own classification, settled before the run
    # and unchanged by reading it, so they are collapsed out of the reviewer's way rather
    # than dropped: L and M still carry every value for whoever needs to unhide them. They
    # moved one column right when Comment was inserted at K, beside the two other fields the
    # reviewer owns.
    #
    # The comparison block at N:U stays visible, hidden pair or not. It is the answer to the
    # question a re-run is for - was this supposed to come back empty, and did it - and a
    # column somebody has to unhide is a column nobody reads.
    $sheets = @([pscustomobject]@{
            Name           = $overviewName
            Rows           = $overviewRows
            Header         = $null
            BackTo         = $null
            Links          = $links
            HiddenColumns  = @(12, 13)
            # Each value names an outcome rather than a stage of work, because "Completed"
            # hides the only thing the next reader needs: completed with what result. The
            # three closing values are the three ways a check can honestly end.
            Validation     = @{
                Sqref  = "I2:I$overviewRow"
                Values = 'Not reviewed,Reviewing,On hold,No issue,Reported to IT,Fixed,No action needed'
            }
        })

    if ($decisionSheet) { $sheets += $decisionSheet }

    $sqlSheet = New-SqlSheet -TabOf $tabOf -Entries @($Collected | ForEach-Object {
            [pscustomobject]@{
                Key     = (Get-JobRunKey -Job $_.Job)
                CheckId = $_.Job.CheckId
                Name    = $_.Job.Name
                Sql     = $_.Job.Sql
            }
        })

    # Comment and Check By are written empty on purpose: both columns are the reviewer's,
    # and the workbook only supplies their headings. C2 holds the jump to the statement
    # rather than the statement itself.
    foreach ($item in $Collected) {
        $itemRunKey = Get-JobRunKey -Job $item.Job
        $itemCategory = $(if ($item.Job.PSObject.Properties.Name -contains 'Category') {
                [string]$item.Job.Category
            }
            else { '' })
        $itemParameters = $(if ($item.Job.PSObject.Properties.Name -contains 'Parameters') {
                [string]$item.Job.Parameters
            }
            else { '' })

        # Parameters is appended rather than inserted: C2 is where the jump to the statement
        # lives, and moving SQL Used off C would move the link with it.
        $sheet = [pscustomobject]@{
            Name   = $tabOf[$itemRunKey]
            Rows   = $item.Rows
            Header = @($item.Job.CheckId, $item.Job.Name, 'SQL',
                (Get-CheckPriority -Category $itemCategory), $itemCategory,
                $item.Job.What, '', '',
                $(if ($item.Job.Signal) { $item.Job.Signal } else { 'Actionable' }),
                [string]$item.Job.SignalReason, $itemParameters)
            BackTo = $overviewName
        }

        if ($sqlSheet -and $sqlSheet.Anchor.ContainsKey($itemRunKey)) {
            $sheet | Add-Member -NotePropertyName Links -NotePropertyValue @(
                [pscustomobject]@{
                    Ref    = 'C2'
                    Target = $sqlSheet.Name
                    Cell   = $sqlSheet.Anchor[$itemRunKey]
                    Text   = 'SQL'
                })
        }

        $sheets += $sheet
    }

    # Last, so the check tabs stay next to the Overview they are read from.
    if ($sqlSheet) { $sheets += $sqlSheet.Sheet }

    # Written aside and moved into place, so a snapshot interrupted halfway cannot leave a
    # truncated zip where the last good one was.
    $writing = $Path + '.writing'
    Save-Workbook -Sheets $sheets -Path $writing
    Move-Item -LiteralPath $writing -Destination $Path -Force

    return $shortened
}

# --------------------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------------------

# The prologue above has run, so a caller dot-sourcing for the functions gets them with the
# script variables they read already set. Everything below this line talks to the server.
if ($DotSourceOnly) { return }

$sportIdentity = Resolve-SportIdentity -SportValue $Sport -SportSlugValue $SportSlug `
    -DatabaseSportNameValue $DatabaseSportName
if ($sportIdentity) {
    $ResolvedSportSlug = $sportIdentity.Slug
    $ResolvedDatabaseSportName = $sportIdentity.DatabaseName
    $script:RunSportName = $ResolvedSportSlug
}
else {
    $ResolvedSportSlug = ''
    $ResolvedDatabaseSportName = ''
}

if ($Info) {
    # The wrapper function announces itself through EP_QB_COMMAND so the examples
    # below show what the reader actually types.
    $Entry = if ($env:EP_QB_COMMAND) { $env:EP_QB_COMMAND } else { '.\TOOLS\Run-Query.ps1' }

    $catalogue = Get-CheckCatalogue
    $sources = ($catalogue | Group-Object File | Sort-Object Name |
        ForEach-Object { "$($_.Name) ($($_.Count))" }) -join ', '

    function Write-Section { param([string]$Title) Write-Host "`n$Title" -ForegroundColor Cyan }
    function Write-Line {
        param([string]$Command, [string]$Explains)

        $column = 54
        $text = '  ' + $Command

        # A long example would otherwise run straight into its explanation.
        if ($text.Length -ge $column) {
            Write-Host $text -ForegroundColor White
            Write-Host ((' ' * $column) + $Explains) -ForegroundColor DarkGray
            return
        }

        Write-Host $text.PadRight($column) -ForegroundColor White -NoNewline
        Write-Host $Explains -ForegroundColor DarkGray
    }

    Write-Host "`nContent Query Builder runner" -ForegroundColor Green
    Write-Host "  server    $BaseUrl" -ForegroundColor DarkGray
    Write-Host "  script    $PSCommandPath" -ForegroundColor DarkGray
    Write-Host "  checks    $($catalogue.Count) in $sources" -ForegroundColor DarkGray
    Write-Host "  login     $(if ($env:EP_QB_COOKIE) { 'EP_QB_COOKIE' } elseif ($env:EP_QB_EMAIL) { $env:EP_QB_EMAIL } else { 'not configured' })" -ForegroundColor DarkGray

    Write-Section 'FIND CHECKS'
    # The bare "info" word is the wrapper's doing; the script itself needs the switch.
    Write-Line $(if ($env:EP_QB_COMMAND) { "$Entry info" } else { "$Entry -Info" }) 'this page'
    Write-Line "$Entry -ListChecks" 'every CheckID with its name and source line'
    Write-Line "$Entry -ListChecks BMX-DQ-0*" 'filter the list by wildcard'

    Write-Section 'RUN ONE'
    Write-Line "$Entry BMX-DQ-003" 'to the screen'
    Write-Line "$Entry BMX-DQ-003 -Preview 200" 'show more than the default 50 rows'
    Write-Line "$Entry BMX-DQ-003 -OutFile .\out.csv" 'to a file, tagged with check_id'
    Write-Line "$Entry BMX-DQ-003 -DryRun" 'print the SQL, send nothing'

    Write-Section 'RUN MANY'
    Write-Line "$Entry BMX-DQ-001,BMX-DQ-005" 'a chosen few'
    Write-Line "$Entry BMX-DQ-*" 'the whole BMX catalogue'
    Write-Line "$Entry BMX-DQ-* -MaxChecks 10" 'only the first 10 matches'
    Write-Line "$Entry BMX-DQ-* -Format xlsx" 'one workbook, one tab per check'
    Write-Line "$Entry BMX-DQ-* -OutDir .\out" 'choose the target folder'
    Write-Host '  Batch mode keeps going when a check fails. Results land in' -ForegroundColor DarkGray
    Write-Host "  $OutputRoot\<Sport> <dd.MM.yyyy HH-mm-ss>" -ForegroundColor DarkGray

    Write-Section 'PARAMETERS'
    Write-Host '  A sport check carries its own sport ID and needs no parameter.' -ForegroundColor DarkGray
    Write-Host '  Only GLOBAL-DISCOVERY statements declare {{PLACEHOLDER}} tokens.' -ForegroundColor DarkGray
    Write-Line "$Entry GLOBAL-DISCOVERY-001 -SportId 58" 'fills {{SPORT_ID}}'
    Write-Line '-Params STATISTIC_TYPE_ID=11,SHARD_ID=11' 'any other declared token'
    Write-Line '-Params @{ SHARD_ID = 11 }' 'the hashtable form also works'
    Write-Line "$Entry -Sport 'Water Polo' ..." 'database name or documented repository slug'
    Write-Line "$Entry -SportSlug Water-Polo -DatabaseSportName 'Water Polo' ..." 'make a new mapping explicit'

    Write-Section 'NARROWING TO CERTAIN TEMPLATES'
    Write-Line '-TemplateIds 44,50,65' 'run only these tournament templates'
    Write-Host '  Activates the commented template filter POWERBI.md already requires in' -ForegroundColor DarkGray
    Write-Host '  every branch that has a template relation, in the findings and the' -ForegroundColor DarkGray
    Write-Host '  coverage branch alike, so eligible_count is counted over the same scope.' -ForegroundColor DarkGray
    Write-Host '  A statement carrying no such marker audits a population with no template' -ForegroundColor DarkGray
    Write-Host '  relation: it is skipped, never run wide and reported as though narrow.' -ForegroundColor DarkGray

    Write-Section 'OPEN A NEW SPORT'
    Write-Line "$Entry GLOBAL-DISCOVERY-* -Sport BMX -Format xlsx" 'discover the parameters, then run'
    Write-Host '  -Sport resolves the sport ID, the statistic type and owner, and probes' -ForegroundColor DarkGray
    Write-Host '  for the physical shard. Statements needing a value picked from a summary' -ForegroundColor DarkGray
    Write-Host '  result are listed and skipped, never guessed. An explicit -SportId or' -ForegroundColor DarkGray
    Write-Host '  -Params wins over a discovered value.' -ForegroundColor DarkGray

    Write-Section 'FOLLOW THE DRILL-DOWNS TOO'
    Write-Line "$Entry GLOBAL-DISCOVERY-* -Sport BMX -Chain -Format xlsx" 'summaries and their details, one command'
    Write-Line '-ChainTop 3,2' 'values per level; default 3 then 2'
    Write-Line '-ChainMax 40' 'ceiling on chained statements for the run'
    Write-Host '  A skipped drill-down names its own source: GLOBAL_QUERIES writes' -ForegroundColor DarkGray
    Write-Host '  "select <column> from GLOBAL-DISCOVERY-NNN" on the placeholder line. -Chain' -ForegroundColor DarkGray
    Write-Host '  reads that, takes the values the summary ranks first and runs the drill-down' -ForegroundColor DarkGray
    Write-Host '  once per value, in the same workbook. The CheckID is unchanged and the' -ForegroundColor DarkGray
    Write-Host '  values appear in Parameters, so nothing here mints an identity.' -ForegroundColor DarkGray
    Write-Host '  Chained results are samples of the busiest shapes, never coverage: what was' -ForegroundColor DarkGray
    Write-Host '  not pursued keeps a SKIPPED row of its own in the Overview.' -ForegroundColor DarkGray

    Write-Section 'PATTERNS ALONGSIDE A RUN'
    Write-Line "$Entry GLOBAL-DQ-* -Sport BMX -WithPatterns -Format xlsx" 'DQ plus the patterns'
    Write-Host '  Adds every PATTERNS.sql statement whose parameters -Sport can supply:' -ForegroundColor DarkGray
    Write-Host '  the round-type and name-pattern summaries. A drill-down is left out,' -ForegroundColor DarkGray
    Write-Host '  its value being one you pick out of a summary and run separately.' -ForegroundColor DarkGray

    Write-Section 'EVERYTHING FOR ONE SPORT'
    Write-Line "$Entry -Sport Triathlon -RunAll" 'the whole sport in one command'
    Write-Host '  Every Approved registry row for the sport, using the Query file it names,' -ForegroundColor DarkGray
    Write-Host '  and the patterns, in one workbook under the output root. Blocked,' -ForegroundColor DarkGray
    Write-Host '  unapproved and deprecated checks do not run. Implies' -ForegroundColor DarkGray
    Write-Host '  -WithPatterns and -Format xlsx; an explicit -Format or -OutDir still wins.' -ForegroundColor DarkGray
    Write-Host '  A template the sport cannot parameterise is listed as SKIPPED, not run.' -ForegroundColor DarkGray
    Write-Host '  -IncludeUnapproved is accepted only while the sport is absent everywhere' -ForegroundColor DarkGray
    Write-Host '  in the repository; it cannot override an existing registry or block.' -ForegroundColor DarkGray

    Write-Section 'AD-HOC SQL'
    Write-Line "$Entry -Sql `"SELECT COUNT(*) AS c FROM sport;`"" 'run a literal statement'
    Write-Line "$Entry -File .\scratch.sql" 'run a file'
    Write-Host '  The server only accepts statements starting with SELECT. It rejects WITH,' -ForegroundColor DarkGray
    Write-Host '  so nest derived tables instead of writing a CTE; window functions are fine.' -ForegroundColor DarkGray

    Write-Section 'OUTPUT'
    Write-Line '-Format table' 'default, on-screen preview'
    Write-Line '-Format csv' 'CSV, with check_id and check_name columns'
    Write-Line '-Format json' 'JSON, with check_id and check_name fields'
    Write-Line '-Format xlsx' 'one .xlsx, tabs named after each check, Overview first'
    Write-Host '  Overview lists Sport, CheckID, Parameters, Check Name, What it does, Rows' -ForegroundColor DarkGray
    Write-Host '  and the Status, Check By and Comment fields, with Signal and Signal reason' -ForegroundColor DarkGray
    Write-Host '  hidden behind them, and N:U carrying Expected, Findings, Eligible, the same' -ForegroundColor DarkGray
    Write-Host '  two from the previous run, Change, Verdict and Last run.' -ForegroundColor DarkGray
    Write-Host '  Each row count links to its tab. Overview Comment is a' -ForegroundColor DarkGray
    Write-Host '  formula reading the tab it belongs to, so write the comment on the tab;' -ForegroundColor DarkGray
    Write-Host '  typing over it here replaces the link. On a check tab' -ForegroundColor DarkGray
    Write-Host '  row 2 holds the CheckID, the name, the one-line SQL that ran and what' -ForegroundColor DarkGray
    Write-Host '  the check asserts, with empty Comment and Check By cells beside them;' -ForegroundColor DarkGray
    Write-Host '  A3 returns to Overview, and the result table starts on row 5. CSV and JSON keep' -ForegroundColor DarkGray
    Write-Host '  check_id and check_name as columns, having nowhere else to put them.' -ForegroundColor DarkGray
    Write-Host '  Files are named after the CheckID: BMX-DQ-003.csv' -ForegroundColor DarkGray
    Write-Host '  Upload the .xlsx to Google Drive and open it as Sheets to get the tabs.' -ForegroundColor DarkGray

    Write-Section 'HISTORY'
    Write-Line "$Entry ... -NoLedger" 'keep this run out of the sport history'
    Write-Host '  Each run appends its row, finding and eligible counts to RUNS\<Sport>.json,' -ForegroundColor DarkGray
    Write-Host '  then reads itself against the last one and writes a Verdict per check:' -ForegroundColor DarkGray
    Write-Host '  Resolved, Improved, Unchanged, Regressed, As expected, Above residual,' -ForegroundColor DarkGray
    Write-Host '  Unexpectedly empty, Scope moved, Audited nothing, New.' -ForegroundColor DarkGray
    Write-Host '  What counts as good news comes from _expected in SPORTS\params.json.' -ForegroundColor DarkGray
    Write-Host '  A record of what a run returned, never evidence: a finding still enters the' -ForegroundColor DarkGray
    Write-Host '  repository only through PREPARE_DOC_UPDATE.' -ForegroundColor DarkGray

    Write-Section 'SESSION'
    Write-Line "$Entry ... -Relogin" 'throw away the cached cookie and log in again'
    Write-Host "  Credentials live in TOOLS\secrets.local.ps1 (git-ignored)." -ForegroundColor DarkGray
    Write-Host "  Cached cookie: $StatePath" -ForegroundColor DarkGray
    Write-Host ''
    return
}

if ($ListChecks) {
    $catalogue = Get-CheckCatalogue
    if ($CheckId) {
        $catalogue = @($catalogue | Where-Object {
                $id = $_.CheckId
                @($CheckId | Where-Object { $id -like $_ }).Count -gt 0
            })
    }
    $catalogue | Sort-Object CheckId | Format-Table CheckId, Name, File, Line -AutoSize
    return
}

# ----- what to run ---------------------------------------------------------------------

if ($RunAll) {
    # Everything one sport can be asked, in one command: its approved DQ checks and the
    # patterns those findings have to be read against. Select-RunAllChecks owns which checks
    # those are.
    if ([string]::IsNullOrWhiteSpace($ResolvedSportSlug)) {
        throw '-RunAll needs -Sport <name> (or -SportSlug/-DatabaseSportName): it selects that sport''s checks, and a GLOBAL template has no sport of its own.'
    }

    $selection = Select-RunAllChecks -Catalogue (Get-CheckCatalogue) -SportName $ResolvedSportSlug -IncludeUnapproved:$IncludeUnapproved
    $jobs = @($selection.Jobs)

    if ($selection.MissingStatement.Count -gt 0) {
        # An Approved row whose statement is not in the catalogue is a broken package, not a
        # check to skip quietly. Test-Package.ps1 reports the same condition.
        throw ("POWERBI_REGISTRY.md has $($selection.MissingStatement.Count) Approved row(s) with no executable statement:`n  " +
            ($selection.MissingStatement -join "`n  ") + "`nRun TOOLS\Test-Package.ps1.")
    }
    if ($jobs.Count -eq 0) {
        throw "Nothing is Approved for $ResolvedSportSlug in POWERBI_REGISTRY.md. Use -ListChecks to see what is registered."
    }

    if ($selection.Unapproved) {
        Write-Host ("-RunAll -IncludeUnapproved: {0} statement(s) for {1}, plus the patterns." -f $jobs.Count, $ResolvedSportSlug) -ForegroundColor Yellow
        Write-Host '  Discovery, not a DQ run: none of these is approved for this sport.' -ForegroundColor Yellow
    }
    else {
        $instantiated = @($jobs | Where-Object { $_.Template }).Count
        Write-Host ("-RunAll: {0} approved check(s) for {1} - {2} template instantiation(s) and {3} sport statement(s) - plus the patterns." -f `
            $jobs.Count, $ResolvedSportSlug, $instantiated, ($jobs.Count - $instantiated)) -ForegroundColor DarkGray

        # What was left out, and why. A run that is shorter than the catalogue should say so
        # here rather than leave the reader counting tabs in the workbook.
        if ($selection.NotApprovedIds.Count -gt 0) {
            Write-Host ("  {0} GLOBAL template(s) not approved for {1} and not run." -f $selection.NotApprovedIds.Count, $ResolvedSportSlug) -ForegroundColor DarkGray
        }
        foreach ($block in $selection.BlockedFamilies) {
            Write-Host ("  {0} is blocked for {1}: {2}" -f $block.Family, $ResolvedSportSlug, $block.Reason) -ForegroundColor DarkGray
        }
        if ($selection.DeprecatedIds.Count -gt 0) {
            Write-Host ("  deprecated and not run: {0}" -f ($selection.DeprecatedIds -join ', ')) -ForegroundColor DarkGray
        }

        # Running, but with the sport file's verdict on what the findings mean attached, so
        # the reader is not left to take a full-population result at face value.
        foreach ($item in $selection.Classified) {
            Write-Host ("  {0} runs as {1}: {2}" -f $item.CheckId, $item.Signal, $item.SignalReason) -ForegroundColor DarkGray
        }
    }

    $WithPatterns = $true
    # A workbook is the only shape that holds a whole catalogue together; an explicit
    # -Format still wins, for the reader who wants the flat files instead.
    if (-not $PSBoundParameters.ContainsKey('Format')) { $Format = 'xlsx' }
}
elseif ($Sql) {
    $jobs = @([pscustomobject]@{ CheckId = ''; Name = ''; What = ''; Sql = $Sql })
}
elseif ($File) {
    $jobs = @([pscustomobject]@{
            CheckId = [IO.Path]::GetFileNameWithoutExtension($File)
            Name    = ''
            What    = ''
            Sql     = (Get-Content -LiteralPath $File -Raw)
        })
}
elseif ($CheckId) {
    $jobs = @(Select-Checks -Patterns $CheckId)
}
else {
    throw 'Nothing to run. Pass a CheckID, -File, -Sql or -RunAll with -Sport. Use -ListChecks to list registered CheckIDs.'
}

if ($MaxChecks -gt 0 -and $jobs.Count -gt $MaxChecks) {
    Write-Host "Matched $($jobs.Count) checks, running the first $MaxChecks." -ForegroundColor DarkGray
    $jobs = $jobs[0..($MaxChecks - 1)]
}

# The pattern statements answer "which round types and names does this sport actually
# use", which is the context a DQ finding is read against, so they are worth carrying in
# the same workbook.
#
# Which of them qualify is derived rather than listed: a statement is automatic when every
# placeholder it declares is one -Sport can supply. That is exactly what separates a
# pattern summary from a drill-down, whose parameter is a value read out of a summary
# result and would be a sample dressed up as coverage if it were chosen automatically. No
# list of IDs to keep in step with PATTERNS.sql, and a pattern statement added later is
# picked up or left out on its own parameters.
#
# Applied after -MaxChecks: the cap exists to trim the matched set, and these were asked
# for by name rather than matched. Injected before the parameters are resolved, so -Sport
# discovers whatever they need on a sport that has none recorded yet.
if ($WithPatterns) {
    $automatic = @{}
    foreach ($name in $DiscoverableParameters) { $automatic[$name] = $true }

    $alreadyMatched = @{}
    foreach ($job in $jobs) {
        if ($job.CheckId) { $alreadyMatched[$job.CheckId] = $true }
    }

    $added = @(Get-CheckCatalogue |
        Where-Object { $_.File -eq 'PATTERNS.sql' } |
        Where-Object { -not $alreadyMatched.ContainsKey($_.CheckId) } |
        Where-Object { (Get-MissingPlaceholders -Text $_.Sql -Values $automatic).Count -eq 0 } |
        Sort-Object CheckId)

    if ($added.Count -gt 0) {
        $jobs = @($jobs) + $added
        Write-Host ("Adding {0} pattern statement(s): {1}" -f `
                $added.Count, (($added | ForEach-Object { $_.CheckId }) -join ', ')) -ForegroundColor DarkGray
    }
}

# A sport classification belongs to the run regardless of how its jobs were selected.
# -RunAll already carries it from the registry selection; this also hydrates direct IDs,
# wildcards and the pattern statements they pull alongside them. It runs without a sport too,
# because the discovery rule is a property of the statement rather than of the sport it is
# pointed at, and a run started with -SportId alone must not lose it.
$jobs = @(Set-JobCheckSignal -Jobs $jobs -SportName $(if ($sportIdentity) { $ResolvedSportSlug } else { '' }))

# The expectation is derived from the signal just set, then overridden by anything the sport
# records, so this cannot be folded into the call above.
$jobs = @(Set-JobCheckExpectation -Jobs $jobs -SportName $(if ($sportIdentity) { $ResolvedSportSlug } else { '' }))

# ----- parameters ----------------------------------------------------------------------

$paramTable = ConvertTo-ParamTable -Value $Params

# Precedence, widest trust last: an explicit -Params or -SportId wins, then the values the
# sport has had confirmed and recorded, then live discovery for whatever is still missing.
# Each step fills only keys the earlier ones left empty.
if ($sportIdentity) {
    $identityText = if ($ResolvedSportSlug -ceq $ResolvedDatabaseSportName) {
        "'$ResolvedSportSlug'"
    }
    else { "'$ResolvedSportSlug' (database sport '$ResolvedDatabaseSportName')" }
    Write-Host "Resolving parameters for $identityText..." -ForegroundColor DarkGray
    foreach ($entry in (Get-SportFileParameters -SportName $ResolvedSportSlug).GetEnumerator()) {
        if (-not $paramTable.ContainsKey($entry.Key)) { $paramTable[$entry.Key] = $entry.Value }
    }

    # Discovery costs several executions, so it runs only when it can actually supply
    # something still missing. A drill-down placeholder is not discoverable and is skipped
    # further down instead.
    $stillMissing = @()
    foreach ($job in $jobs) {
        $stillMissing += Get-MissingPlaceholders -Text $job.Sql -Values $paramTable
    }
    $stillMissing = @($stillMissing | Select-Object -Unique | Where-Object { $DiscoverableParameters -contains $_ })

    if ($stillMissing.Count -gt 0) {
        if ($Relogin -and (Test-Path $StatePath)) { Remove-Item -LiteralPath $StatePath -Force }
        $script:Session = $null
        if (-not $Relogin) { $script:Session = Restore-SessionState }
        if ($null -eq $script:Session) { $script:Session = New-AuthenticatedSession }

        foreach ($entry in (Resolve-SportParameters -DatabaseSportNameValue $ResolvedDatabaseSportName).GetEnumerator()) {
            if (-not $paramTable.ContainsKey($entry.Key)) { $paramTable[$entry.Key] = $entry.Value }
        }
    }
    else {
        Write-Host '  nothing left to discover; no discovery query sent.' -ForegroundColor DarkGray
    }
    Write-Host ''
}

if ($PSBoundParameters.ContainsKey('SportId')) { $paramTable['SPORT_ID'] = $SportId }

# A statement still short of a value is skipped rather than guessed, but only under -Sport:
# without it an unfilled placeholder is a mistake worth stopping for.
$skipped = @()
$runnable = @()
$registryTrimmed = @()

$notApplicable = @{}
if ($sportIdentity) { $notApplicable = Get-SportNotApplicable -SportName $ResolvedSportSlug }

foreach ($job in $jobs) {
    $missing = Get-MissingPlaceholders -Text $job.Sql -Values $paramTable
    if ($sportIdentity -and $missing.Count -gt 0 -and $jobs.Count -gt 1) {
        # One impossible parameter is enough: the statement can never run for this sport, so
        # it is reported as not applicable even when other placeholders are merely unfilled.
        $blocked = @($missing | Where-Object { $notApplicable.ContainsKey($_) })
        if ($blocked.Count -gt 0) {
            # One cause commonly blocks several parameters - a sport storing no time fails
            # three of them at once - so the reason is printed once with its parameters
            # listed, rather than repeated until the line is unreadable.
            $reason = (($blocked | Group-Object { $notApplicable[$_] } | ForEach-Object {
                        "{0} - {1}" -f (($_.Group | Sort-Object) -join ', '), $_.Name
                    }) -join '; ')
            $skipped += [pscustomobject]@{
                Job     = $job
                Missing = ($missing -join ', ')
                Kind    = 'NOT_APPLICABLE'
                Reason  = $reason
            }
        }
        else {
            $skipped += [pscustomobject]@{
                Job     = $job
                Missing = ($missing -join ', ')
                Kind    = 'NEEDS_SELECTION'
                Reason  = ''
            }
        }
        continue
    }
    $job.Sql = Expand-Placeholders -Text $job.Sql -Values $paramTable

    # Narrowing happens after expansion, so a filter can sit beside a placeholder in the same
    # WHERE clause. A statement with no marker is one whose audited population has no template
    # relation - POWERBI.md forbids inventing one there - so it is stopped rather than run
    # wide and reported as though it were narrow.
    if ($TemplateIds.Count -gt 0) {
        $narrowed = Enable-TemplateFilter -Text $job.Sql -TemplateIds $TemplateIds
        if ($narrowed.Activated -eq 0) {
            if ($jobs.Count -eq 1) {
                throw ("$($job.CheckId) carries no template filter, so -TemplateIds cannot " +
                    'narrow it. Its audited population has no template relation; run it ' +
                    'without -TemplateIds and read the result as sport-wide.')
            }
            $skipped += [pscustomobject]@{
                Job     = $job
                Missing = ''
                Kind    = 'NO_TEMPLATE_FILTER'
                Reason  = 'no template filter to activate; the audited population has no template relation'
            }
            continue
        }
        $job.Sql = $narrowed.Sql
    }

    # A statement marking no optional registry branch is run unchanged rather than skipped.
    # Dropping nothing from it is a no-op, and its result is the honest one - unlike an
    # unnarrowed statement under -TemplateIds, which would claim a scope it does not have.
    # Most statements never read the registry at all, so refusing them here would empty a
    # batch to make a point about the two that do.
    if ($WithoutRegistryBranch) {
        $trimmed = Remove-RegistryBranch -Text $job.Sql
        if ($trimmed.Removed -gt 0) {
            $job.Sql = $trimmed.Sql
            $registryTrimmed += $job.CheckId
        }
    }

    $runnable += $job
}

if ($skipped.Count -gt 0) {
    $impossible = @($skipped | Where-Object { $_.Kind -eq 'NOT_APPLICABLE' })
    $unnarrowable = @($skipped | Where-Object { $_.Kind -eq 'NO_TEMPLATE_FILTER' })
    $unselected = @($skipped | Where-Object { $_.Kind -eq 'NEEDS_SELECTION' })

    Write-Host "Skipping $($skipped.Count) statement(s):" -ForegroundColor DarkGray

    if ($impossible.Count -gt 0) {
        Write-Host "  not applicable to this sport ($($impossible.Count)):" -ForegroundColor DarkGray
        $impossible | ForEach-Object { "    {0}  {1}" -f $_.Job.CheckId, $_.Reason } | Write-Host -ForegroundColor DarkGray
    }
    if ($unnarrowable.Count -gt 0) {
        Write-Host "  cannot be narrowed to -TemplateIds ($($unnarrowable.Count)):" -ForegroundColor DarkGray
        $unnarrowable | ForEach-Object { "    {0}  {1}" -f $_.Job.CheckId, $_.Reason } | Write-Host -ForegroundColor DarkGray
    }
    if ($unselected.Count -gt 0) {
        Write-Host "  needs a value selected from a summary result ($($unselected.Count)):" -ForegroundColor DarkGray
        $unselected | ForEach-Object { "    {0}  needs {1}" -f $_.Job.CheckId, $_.Missing } | Write-Host -ForegroundColor DarkGray
    }
    Write-Host ''
}

if ($registryTrimmed.Count -gt 0) {
    Write-Host ("Registry branch dropped from {0}: {1}" -f $registryTrimmed.Count, ($registryTrimmed -join ', ')) -ForegroundColor DarkGray
    Write-Host ''
}

if ($runnable.Count -eq 0) {
    throw ("Nothing left to run: every matched statement is either not applicable to this sport, " +
        "carries no template filter for -TemplateIds to activate, or needs a value that must be " +
        "selected from a summary result.")
}

$jobs = $runnable

# A chained run is a batch even when one statement starts it: the wave it feeds makes several,
# and they need the summary, the per-run files and the workbook that only the batch path writes.
$chainable = @($skipped | Where-Object {
        $Chain -and $_.Kind -eq 'NEEDS_SELECTION' -and $_.Job.CheckId -like $DiscoveryCheckIdPattern
    })
$isBatch = ($jobs.Count -gt 1) -or ($chainable.Count -gt 0)

if ($Chain) {
    if ($ChainTop.Count -eq 0) {
        throw '-ChainTop needs at least one level, for example -ChainTop 3,2.'
    }
    if ($chainable.Count -eq 0) {
        Write-Host '-Chain has nothing to chain: no matched discovery statement is waiting on a value from a summary.' -ForegroundColor DarkGray
    }
}

if ($DryRun) {
    if ($isBatch) {
        Write-Host "--- $($jobs.Count) checks that would run ---" -ForegroundColor DarkGray
        $jobs | Format-Table CheckId, Name -AutoSize
        if ($Chain) {
            Write-Host ('  -Chain would add up to {0} more, but which ones depends on values only the run itself returns.' -f $ChainMax) -ForegroundColor DarkGray
        }
    }
    else {
        Write-Host "--- SQL that would be sent ($($jobs[0].CheckId)) ---" -ForegroundColor DarkGray
        Write-Output $jobs[0].Sql
    }
    return
}

$isWorkbook = $Format -eq 'xlsx'

if ($isBatch -and $OutFile -and -not $isWorkbook) {
    throw "-OutFile takes a single check because column layouts differ per check. Use -OutDir, or -Format xlsx to collect every check into one workbook."
}

# ----- session -------------------------------------------------------------------------

# -Sport has to reach the database to discover anything, so the session may already exist.
if (-not $script:Session) {
    if ($Relogin -and (Test-Path $StatePath)) { Remove-Item -LiteralPath $StatePath -Force }
    if (-not $Relogin) { $script:Session = Restore-SessionState }
    if ($null -eq $script:Session) { $script:Session = New-AuthenticatedSession }
}

# ----- batch run -----------------------------------------------------------------------

if ($isBatch) {
    if ($isWorkbook) {
        # One workbook for the whole run, so it can be uploaded as a single file.
        $workbookPath = $OutFile
        if (-not $workbookPath) {
            $folder = if ($OutDir) { $OutDir } else { Get-RunFolder -Jobs $jobs }
            $workbookPath = Join-Path $folder ((Get-RunSport -Jobs $jobs) + '.xlsx')
        }
        Write-Host "Running $($jobs.Count) checks into $workbookPath" -ForegroundColor DarkGray
    }
    else {
        if (-not $OutDir) { $OutDir = Get-RunFolder -Jobs $jobs }
        if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
        $extension = if ($Format -eq 'json') { '.json' } else { '.csv' }
        Write-Host "Running $($jobs.Count) checks into $OutDir" -ForegroundColor DarkGray
    }

    # Read before the first statement is sent. Every verdict this run computes is against
    # this snapshot, and it is taken before the run appends an entry of its own, so no check
    # can end up compared against itself.
    $script:PreviousRun = Import-PreviousRunEntries -Jobs $jobs
    if ($script:PreviousRun.Count -gt 0) {
        Write-Host ("Comparing against the last recorded run of {0} check(s)." -f $script:PreviousRun.Count) -ForegroundColor DarkGray
    }
    else {
        Write-Host 'No earlier run recorded for this sport: every verdict this run writes is New.' -ForegroundColor DarkGray
    }

    $summary = @()
    $collected = @()
    $index = 0
    $lastSnapshot = Get-Date

    # The run is a queue of waves rather than one list. Without -Chain there is exactly one
    # wave and this behaves as it always did; with it, each wave is built out of what the
    # previous one returned, which is the only order the values can arrive in.
    $queue = @($jobs)
    $planned = $queue.Count

    # Feeder results, kept whatever the output format. A workbook run already holds them in
    # $collected, but a chained flat run must not have to re-read a CSV it just wrote.
    $chainSource = @()
    $chainNotes = @()
    $chainResolved = @{}
    $chainedTotal = 0
    $chainCapped = $false
    $level = 0

    # Only discovery chains. A DQ statement short of a parameter is short of a confirmed fact
    # about the sport, not of a value to sample, and POWERBI.md does not let a check be run on
    # a guess. -Chain is silent about them rather than refusing the run they came with.
    $pendingSelection = @()
    if ($Chain) {
        $pendingSelection = @($skipped |
            Where-Object { $_.Kind -eq 'NEEDS_SELECTION' -and $_.Job.CheckId -like $DiscoveryCheckIdPattern })
    }

    while ($queue.Count -gt 0) {
        foreach ($job in $queue) {
            $index++
            $started = Get-Date
            $rowCount = 0
            $status = 'OK'
            $runKey = Get-JobRunKey -Job $job
            # Read here rather than after the loop: a check that came back with its COVERAGE
            # row alone never reaches $collected under a flat format, and a failed one never
            # reaches it at all, so this is the only point where every check still has rows.
            $eligible = $null
            $findings = $null

            try {
                $rows = Get-StatementRows -Statement $job.Sql -CheckId $runKey
                $rowCount = @($rows).Count
                $eligible = Get-CoverageCount -Rows $rows
                $findings = Get-FindingCount -Rows $rows

                if ($rowCount -gt 0) {
                    if ($isWorkbook) {
                        # A workbook names the check on the tab and on row 1, so the rows
                        # themselves stay clean.
                        $collected += [pscustomobject]@{ Job = $job; Rows = $rows }
                    }
                    else {
                        # A flat file has nowhere else to record which check a row came from.
                        # The file is named for the run rather than the check, or two chained
                        # runs of one CheckID would overwrite each other.
                        $tagged = Add-CheckColumns -Rows $rows -CheckId $runKey -Name $job.Name
                        $target = Join-Path $OutDir ((Get-SafeFileName -CheckId $runKey) + $extension)
                        Save-Rows -Rows $tagged -Path $target -Fmt $Format
                    }

                    if ($Chain) { $chainSource += [pscustomobject]@{ Job = $job; Rows = $rows } }
                }
                else {
                    $status = 'clean'
                }
            }
            catch {
                $status = "ERROR: $($_.Exception.Message)"
            }

            $elapsed = ((Get-Date) - $started).TotalSeconds
            $summary += New-RunSummaryRow -Job $job -Rows $rowCount `
                -Seconds ([math]::Round($elapsed, 1)) -Status $status `
                -Eligible $eligible -Findings $findings

            $colour = if ($status -like 'ERROR*') { 'Red' } else { 'DarkGray' }
            Write-Host ("[{0}/{1}] {2}  rows={3}  {4:n1}s  {5}" -f `
                    $index, $planned, $runKey, $rowCount, $elapsed, $status) -ForegroundColor $colour

            # A run that wedges or is interrupted must not cost the checks that already
            # succeeded. Flat files are written per check as they come, so only the workbook
            # needs this. A snapshot that cannot be written - the file open in Excel, most
            # likely - is reported and skipped: it must never end the run it exists to protect.
            if ($isWorkbook -and $collected.Count -gt 0 -and $index -lt $planned -and
                ((Get-Date) - $lastSnapshot).TotalSeconds -ge $SnapshotIntervalSec) {
                try {
                    Save-RunWorkbook -Summary $summary -Collected $collected -Path $workbookPath | Out-Null
                    Write-Host ("        snapshot: {0} of {1} checks saved" -f $index, $planned) -ForegroundColor DarkGray
                }
                catch {
                    Write-Host "        snapshot failed: $($_.Exception.Message)" -ForegroundColor Yellow
                }
                $lastSnapshot = Get-Date
            }

            if ($index -lt $planned) { Start-Sleep -Milliseconds $BatchDelayMs }
        }

        $queue = @()
        if (-not $Chain -or $level -ge $ChainTop.Count -or $pendingSelection.Count -eq 0) { break }

        $top = $ChainTop[$level]
        $level++
        if ($top -le 0) { break }

        $wave = Get-ChainedJob -Pending $pendingSelection -Completed $chainSource -ParamTable $paramTable `
            -Top $top -Budget ($ChainMax - $chainedTotal) -TemplateIds $TemplateIds

        $chainNotes += @($wave.Notes)
        if ($wave.Capped) { $chainCapped = $true }

        foreach ($item in $wave.Resolved) { $chainResolved[$item.Job.CheckId] = $true }
        $pendingSelection = @($pendingSelection | Where-Object { -not $chainResolved.ContainsKey($_.Job.CheckId) })

        $queue = @($wave.Jobs)
        if ($queue.Count -eq 0) { break }

        $chainedTotal += $queue.Count
        $planned += $queue.Count

        Write-Host ''
        Write-Host ("Chain level {0}: {1} drill-down(s) from {2} value(s) each." -f `
                $level, $queue.Count, $top) -ForegroundColor DarkGray
        foreach ($chained in $queue) {
            Write-Host ("    {0}  {1}" -f $chained.CheckId, $chained.Parameters) -ForegroundColor DarkGray
        }
        Write-Host ''
    }

    Save-SessionState -Session $script:Session

    # A statement the chain reached is no longer skipped, and a level that could not find a
    # source yet is not a finding once a later level did. Everything else stays: an incomplete
    # run must say so here rather than leave the reader counting tabs.
    $chainNotes = @($chainNotes | Where-Object {
            -not ($_.Kind -eq 'NO_SOURCE' -and $chainResolved.ContainsKey($_.Job.CheckId))
        })

    # A statement short of a source says so once per level it was tried at, and the reader
    # needs the fact, not the count of attempts.
    $seenNote = @{}
    $chainNotes = @($chainNotes | Where-Object {
            $key = '{0}|{1}|{2}' -f $_.Job.CheckId, $_.Kind, $_.Reason
            if ($seenNote.ContainsKey($key)) { return $false }
            $seenNote[$key] = $true
            return $true
        })

    $chainReason = @{}
    foreach ($note in $chainNotes) {
        if ($note.Kind -eq 'NOT_PURSUED') { continue }
        if (-not $chainReason.ContainsKey($note.Job.CheckId)) { $chainReason[$note.Job.CheckId] = $note.Reason }
    }

    # Statements that could not be filled belong in the record too, or the run would look
    # like it covered the whole catalogue.
    foreach ($item in $skipped) {
        if ($item.Kind -eq 'NEEDS_SELECTION' -and $chainResolved.ContainsKey($item.Job.CheckId)) { continue }

        $skipStatus = switch ($item.Kind) {
            'NOT_APPLICABLE'      { "SKIPPED: not applicable - $($item.Reason)" }
            'NO_TEMPLATE_FILTER'  { "SKIPPED: not narrowable - $($item.Reason)" }
            default               {
                $why = "SKIPPED: needs $($item.Missing)"
                if ($chainReason.ContainsKey($item.Job.CheckId)) {
                    $why += " - not chained: $($chainReason[$item.Job.CheckId])"
                }
                $why
            }
        }
        $summary += New-RunSummaryRow -Job $item.Job -Rows 0 -Seconds 0 -Status $skipStatus
    }

    # What the chain reached but did not exhaust. A row of its own, because a reader counting
    # three GLOBAL-DISCOVERY-019 tabs has no way to know whether that was three of three or
    # three of forty, and the difference is the whole distance between a sample and coverage.
    foreach ($note in @($chainNotes | Where-Object { $_.Kind -eq 'NOT_PURSUED' })) {
        $summary += New-RunSummaryRow -Job $note.Job -Rows 0 -Seconds 0 -Status "SKIPPED: $($note.Reason)"
    }

    # Everything the run left open, collected before anything is written, so the Decisions tab
    # and the JSON beside it are complete rather than a subset that happened to be known early.
    # The chain notes already carry their own alternatives - a count of values not pursued, a
    # pair that could not be found together - so nothing is reconstructed from the console.
    foreach ($note in $chainNotes) {
        $kind = switch ($note.Kind) {
            'NOT_PURSUED' { 'Chain values not pursued' }
            'NO_SOURCE'   { 'Drill-down without a source' }
            'UNDECLARED'  { 'Drill-down without a source' }
            default       { 'Chain value dropped' }
        }
        Add-RunDecision -Kind $kind -Subject $note.Job.CheckId -Chose 'deferred' -Why $note.Reason `
            -Alternatives @('raise -ChainTop and re-run', 'run it by hand with a chosen value',
                'record the area as a sample, saying so')
    }

    foreach ($item in $skipped) {
        if ($item.Kind -ne 'NEEDS_SELECTION') { continue }
        if ($chainResolved.ContainsKey($item.Job.CheckId)) { continue }

        Add-RunDecision -Kind 'Statement not run' -Subject $item.Job.CheckId -Chose 'skipped' `
            -Why ("needs {0}, which is a value picked out of a summary result" -f $item.Missing) `
            -Alternatives @('run it with -Params <NAME>=<value>', 'record the area as Not checked')
    }

    # The one decision POWERBI.md fixes to exactly two answers, so it is the one the run can
    # state completely. It cannot be a third thing, and it is never clean data.
    $audited = @($collected | Where-Object { 0 -eq (Get-CoverageCount -Rows $_.Rows) })
    foreach ($item in $audited) {
        Add-RunDecision -Kind 'Audited nothing' -Subject (Get-JobRunKey -Job $item.Job) -Chose 'deferred' `
            -Why 'eligible_count is 0, which POWERBI.md says is never clean data' `
            -Alternatives @('a misdirected scope, to be corrected',
                'a correct scope over a population that is legitimately empty today, to be recorded as a sentinel')
    }

    foreach ($entry in @($summary | Where-Object { $_.Status -like 'ERROR*' })) {
        Add-RunDecision -Kind 'Statement failed' -Subject $entry.RunKey -Chose 'deferred' `
            -Why ([string]$entry.Status) `
            -Alternatives @('re-run it on its own', 'record the area as Not checked - never Not used')
    }

    if ($isWorkbook) {
        $shortened = @(Save-RunWorkbook -Summary $summary -Collected $collected -Path $workbookPath)
        $destination = $workbookPath
        $decisionPath = Join-Path (Split-Path -Parent $workbookPath) '_decisions.json'
    }
    else {
        Save-RunSummaryCsv -Summary $summary -Path (Join-Path $OutDir '_summary.csv')
        $destination = $OutDir
        $decisionPath = Join-Path $OutDir '_decisions.json'
    }

    $decisionFile = Save-RunDecisions -Decisions $script:RunDecision -Path $decisionPath
    # The run folder, not the workbook inside it: the ledger's runId is what ties an entry to
    # the frozen artifact that produced it, and that artifact is the whole folder.
    $runFolder = $(if ($isWorkbook) { Split-Path -Parent $workbookPath } else { $OutDir })
    $ledgerFiles = @(Save-RunLedger -Summary $summary -Output $runFolder)

    $summary | Format-Table CheckId, Parameters, Name, Signal, Rows, Findings, Eligible, Seconds, Status -AutoSize

    if ($isWorkbook -and $shortened.Count -gt 0) {
        Write-Host "Tab names capped at Excel's 31-character limit:" -ForegroundColor DarkGray
        $shortened | Format-Table CheckId, Wanted, Tab -AutoSize
    }

    # A chained run is a sample of the busiest shapes, and every way it fell short of the whole
    # is said out loud. WORKFLOW.md's evidence rule turns on exactly this distinction.
    if ($Chain) {
        if ($chainedTotal -gt 0) {
            Write-Host ("Chained {0} drill-down(s) over {1} level(s)." -f $chainedTotal, $level) -ForegroundColor DarkGray
        }
        else {
            Write-Host 'Chained nothing: no skipped statement could be filled from a result this run produced.' -ForegroundColor DarkGray
        }

        foreach ($note in $chainNotes) {
            Write-Host ("  {0}  {1}" -f $note.Job.CheckId, $note.Reason) -ForegroundColor DarkGray
        }
        if ($chainCapped) {
            Write-Host ("  -ChainMax $ChainMax reached; the chain stopped there rather than widening further.") -ForegroundColor Yellow
        }
        Write-Host '  Chained values are the ones each summary ranks first, so these results are samples, never coverage.' -ForegroundColor DarkGray
    }

    # A check that audited nothing succeeded, returned one row and reported no findings, so it
    # is indistinguishable from a clean one anywhere except in its own eligible_count. Named
    # here because CLAUDE.md's coverage contract says a zero there is never clean data: it is
    # either a misdirected scope to correct or a legitimately empty population to record, and
    # both need a person. Nothing selects on it - the run is already over.
    if ($audited.Count -gt 0) {
        Write-Host ("{0} check(s) audited nothing - eligible_count is 0, which is never clean data: {1}" -f `
                $audited.Count, (($audited | ForEach-Object { Get-JobRunKey -Job $_.Job }) -join ', ')) -ForegroundColor Yellow
    }

    if ($script:RunDecision.Count -gt 0) {
        Write-Host ("{0} decision(s) recorded on the Decisions tab. Each is a choice the run made for" -f `
                $script:RunDecision.Count) -ForegroundColor Yellow
        Write-Host '  itself or left open, and none of them is settled evidence until somebody answers it.' -ForegroundColor Yellow
        if ($decisionFile) { Write-Host "  $decisionFile" -ForegroundColor DarkGray }
    }

    if ($ledgerFiles.Count -gt 0) {
        Write-Host ("Recorded in {0}. It is a run record, not evidence: a finding still enters" -f `
                ($ledgerFiles -join ', ')) -ForegroundColor DarkGray
        Write-Host '  the repository only through PREPARE_DOC_UPDATE.' -ForegroundColor DarkGray
    }
    elseif ($NoLedger) {
        Write-Host 'Not recorded in RUNS/: -NoLedger was given, so the next run compares against the one before this.' -ForegroundColor DarkGray
    }

    $failed = @($summary | Where-Object { $_.Status -like 'ERROR*' }).Count
    $totalRows = ($summary | Measure-Object Rows -Sum).Sum
    Write-Host ("Done: {0} statement(s), {1} rows, {2} failed -> {3}" -f `
            $index, $totalRows, $failed, $destination) -ForegroundColor DarkGray
    return
}

# ----- single run ----------------------------------------------------------------------

$job = $jobs[0]
if ($job.CheckId) {
    Write-Host "Query: $($job.CheckId)  $($job.Name)" -ForegroundColor DarkGray
}

$started = Get-Date
$rows = Get-StatementRows -Statement $job.Sql -CheckId $job.CheckId
$elapsed = (Get-Date) - $started

Save-SessionState -Session $script:Session

$count = @($rows).Count
Write-Host ("Rows: {0}   Elapsed: {1:n1}s" -f $count, $elapsed.TotalSeconds) -ForegroundColor DarkGray

# A workbook cannot be printed, so it always lands somewhere on disk.
if ($isWorkbook -and -not $OutFile) {
    $folder = if ($OutDir) { $OutDir } else { Get-RunFolder -Jobs $jobs }
    $OutFile = Join-Path $folder ((Get-SafeFileName -CheckId $job.CheckId) + '.xlsx')
}

# Recorded like a batch is, and after the output path is settled so the entry can point at
# the folder it produced. Re-running one check on its own is the commonest thing to do after
# colleagues report a fix, so leaving it out would put a hole in the history exactly where
# the history is being consulted. -NoLedger is how an experiment stays out.
$script:PreviousRun = Import-PreviousRunEntries -Jobs $jobs
$singleSummary = @(New-RunSummaryRow -Job $job -Rows $count -Seconds ([math]::Round($elapsed.TotalSeconds, 1)) `
        -Status 'OK' -Eligible (Get-CoverageCount -Rows $rows) -Findings (Get-FindingCount -Rows $rows))
$singleLedger = @(Save-RunLedger -Summary $singleSummary `
        -Output $(if ($OutFile) { Split-Path -Parent $OutFile } else { '' }))

# The reading a single re-run is usually for. Printed rather than left in the ledger, because
# somebody who ran one check after a reported fix is standing at the terminal waiting for it.
$singleRow = $singleSummary[0]
if ($singleRow.Verdict) {
    $verdictColour = switch ($singleRow.Verdict) {
        { $_ -in @('Resolved', 'Improved', 'As expected') } { 'Green' }
        { $_ -in @('Regressed', 'Above residual', 'Unexpectedly empty', 'Audited nothing') } { 'Yellow' }
        default { 'DarkGray' }
    }
    $against = $(if ($null -ne $singleRow.PrevFindings) {
            ' (was {0}, run {1})' -f $singleRow.PrevFindings, $singleRow.PrevRunId
        }
        else { '' })
    Write-Host ("{0}: {1} finding(s) of {2} eligible, expected {3}{4}" -f `
            $singleRow.Verdict, $singleRow.Findings, $singleRow.Eligible,
            $(if ($singleRow.Expected) { $singleRow.Expected } else { 'nothing recorded' }),
            $against) -ForegroundColor $verdictColour
}
if ($singleLedger.Count -gt 0) {
    Write-Host ("Recorded in {0}" -f ($singleLedger -join ', ')) -ForegroundColor DarkGray
}

if ($OutFile) {
    $used = @{}
    $preferred = if ($job.Name) { $job.Name } else { $job.CheckId }
    $sheetName = ConvertTo-SheetName -Preferred $preferred -Fallback 'data' -Used $used

    if ($isWorkbook) {
        $singleSignal = if ($job.PSObject.Properties.Name -contains 'Signal' -and $job.Signal) {
            [string]$job.Signal
        }
        else { 'Actionable' }
        $singleReason = if ($job.PSObject.Properties.Name -contains 'SignalReason') {
            [string]$job.SignalReason
        }
        else { '' }
        $singleCategory = if ($job.PSObject.Properties.Name -contains 'Category') {
            [string]$job.Category
        }
        else { '' }

        Save-Rows -Rows $rows -Path $OutFile -Fmt $Format -SheetName $sheetName `
            -Header @($job.CheckId, $job.Name, 'SQL',
                (Get-CheckPriority -Category $singleCategory), $singleCategory,
                $job.What, '', '', $singleSignal, $singleReason) `
            -SqlEntry ([pscustomobject]@{ CheckId = $job.CheckId; Name = $job.Name; Sql = $job.Sql })
    }
    else {
        $tagged = Add-CheckColumns -Rows $rows -CheckId $job.CheckId -Name $job.Name
        Save-Rows -Rows $tagged -Path $OutFile -Fmt $Format -SheetName $sheetName
    }

    Write-Host "Written: $OutFile" -ForegroundColor DarkGray
    return
}

switch ($Format) {
    'json' { Add-CheckColumns -Rows $rows -CheckId $job.CheckId -Name $job.Name | ConvertTo-Json -Depth 8 }
    'csv' { Add-CheckColumns -Rows $rows -CheckId $job.CheckId -Name $job.Name | ConvertTo-Csv -NoTypeInformation }
    default {
        # The header line above already says which check this is, so the on-screen
        # table stays free of the repeated check_id / check_name columns.
        if ($count -gt $Preview) {
            Write-Host "Showing first $Preview of $count rows. Use -Format json or -OutFile for all." -ForegroundColor DarkGray
        }
        $rows | Select-Object -First $Preview | Format-Table -AutoSize
    }
}
