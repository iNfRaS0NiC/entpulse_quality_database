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
    Overview, lists Sport, CheckID, Check Name, What it does, Rows and the Status and Check By
    fields for every check, with each row count linking to its tab. Signal and Signal reason
    follow, hidden. The check tabs are named after the "-- Name -" header, abbreviated to fit
    Excel's 31-character limit, and there the identity sits above the data rather than on every
    row: row 1 the labels, row 2 the CheckID, the name, the statement that ran as a single line
    and what the check asserts, with empty Comment and Check By cells for the reviewer, row 3
    the link back to Overview, and the result table from row 5. Upload that file to Google
    Drive and open it as Sheets.

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

function Get-MissingPlaceholders {
    param([string]$Text, [hashtable]$Values)

    return @([regex]::Matches($Text, '\{\{\s*(\w+)\s*\}\}') |
        ForEach-Object { $_.Groups[1].Value } |
        Where-Object { -not $Values.ContainsKey($_) } |
        Select-Object -Unique)
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

    return "'" + (($Text -replace '\\', '\\\\') -replace "'", "''") + "'"
}

# The parameters Resolve-SportParameters can read from the database. Anything else has to
# come from SPORTS/params.json or the command line: a value the runner cannot confirm is
# never guessed.
$DiscoverableParameters = @('SPORT_ID', 'STATISTIC_TYPE_ID', 'STATISTIC_OWNER_TYPE_ID', 'SHARD_ID')

# The two keys inside a sport's SPORTS/params.json entry that are not themselves parameters.
# _notApplicable holds the parameters the sport is documented as unable to supply, mapped to
# the reason. _checkSignal holds what a check's output is worth for this sport, for the ones
# that are not simply actionable. Test-Package.ps1 declares the same two names; the pair of
# files is the contract for both blocks.
$NotApplicableKey = '_notApplicable'
$CheckSignalKey = '_checkSignal'
$ReservedParamKeys = @($NotApplicableKey, $CheckSignalKey)

# What a recorded signal may say. Actionable is the default and is never recorded: writing it
# down for every check would make the block a second copy of the registry. Deprecated is
# deliberately absent - POWERBI_REGISTRY.md's Status column owns that, and a value with two
# owners drifts.
$CheckSignalValues = @('Monitor', 'Blocked', 'Not applicable')

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

        $signal = if ($classification) { $classification.Signal }
            elseif ($job.PSObject.Properties.Name -contains 'Signal' -and $job.Signal) { [string]$job.Signal }
            else { 'Actionable' }
        $reason = if ($classification) { $classification.Reason }
            elseif ($job.PSObject.Properties.Name -contains 'SignalReason') { [string]$job.SignalReason }
            else { '' }

        $job | Add-Member -NotePropertyName Signal -NotePropertyValue $signal -Force
        $job | Add-Member -NotePropertyName SignalReason -NotePropertyValue $reason -Force
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

    if ($ranked.Count -gt 1) {
        $others = ($ranked | Select-Object -Skip 1 | ForEach-Object {
                'type {0} / owner {1} ({2})' -f $_.statistic_type_id, $_.statistic_owner_type_id, $_.statistic_count
            }) -join '; '
        Write-Host "  other pairs not used: $others" -ForegroundColor DarkGray
    }

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

function Get-CellXml {
    # Style 1 is the hyperlink look defined in Get-StylesXml; 0 is the default.
    param([string]$Reference, $Value, [int]$Style = 0)

    if ($null -eq $Value) { return '' }

    $styleAttribute = if ($Style -gt 0) { ' s="{0}"' -f $Style } else { '' }

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

function ConvertTo-SingleLineSql {
    # C1 records the statement that ran, but its newlines make row 1 as tall as the whole
    # query and push the sheet out of shape. Collapsing them requires removing the line
    # comments first: otherwise everything after a "--" ends up commented out and the
    # copied statement no longer runs. Quote state is tracked so a "--" or "#" inside a
    # string literal survives.
    param([string]$Sql)

    $out = New-Object Text.StringBuilder
    $quote = $null
    $i = 0
    $n = $Sql.Length

    while ($i -lt $n) {
        $ch = $Sql[$i]

        if ($quote) {
            [void]$out.Append($ch)
            if ($ch -eq '\' -and $i + 1 -lt $n) {
                [void]$out.Append($Sql[$i + 1])
                $i += 2
                continue
            }
            if ($ch -eq $quote) { $quote = $null }
            $i++
            continue
        }

        if ($ch -eq "'" -or $ch -eq '"' -or $ch -eq '`') {
            $quote = $ch
            [void]$out.Append($ch)
            $i++
            continue
        }

        if (($ch -eq '-' -and $i + 1 -lt $n -and $Sql[$i + 1] -eq '-') -or $ch -eq '#') {
            $end = $Sql.IndexOf("`n", $i)
            if ($end -lt 0) { break }
            $i = $end + 1
            [void]$out.Append(' ')
            continue
        }

        if ($ch -eq '/' -and $i + 1 -lt $n -and $Sql[$i + 1] -eq '*') {
            $end = $Sql.IndexOf('*/', $i)
            $i = if ($end -lt 0) { $n } else { $end + 2 }
            [void]$out.Append(' ')
            continue
        }

        [void]$out.Append($ch)
        $i++
    }

    return (($out.ToString() -replace '\s+', ' ').Trim())
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
            #   row 1  Check ID | Check Name | SQL Used | What it does | Comment |
            #          Check By | Signal | Signal reason
            #   row 2  the values, with Comment and Check By left empty for the reviewer
            #   row 3  the link back to Overview, in a cell of its own
            #   row 4  blank, so the result table below stays its own block
            if ($headerRow) {
                $labels = @('Check ID', 'Check Name', 'SQL Used', 'What it does',
                    'Comment', 'Check By', 'Signal', 'Signal reason')

                [void]$xml.Append('<row r="1">')
                for ($c = 0; $c -lt $header.Count; $c++) {
                    $ref = (Get-ExcelColumnName -Index ($c + 1)) + '1'
                    [void]$xml.Append((Get-CellXml -Reference $ref -Value $labels[$c]))
                }
                [void]$xml.Append('</row>')

                # A fixed height keeps the one-line statement in C2 from stretching the row.
                [void]$xml.Append('<row r="2" ht="15" customHeight="1">')
                for ($c = 0; $c -lt $header.Count; $c++) {
                    $ref = (Get-ExcelColumnName -Index ($c + 1)) + '2'
                    [void]$xml.Append((Get-CellXml -Reference $ref -Value $header[$c]))
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
                    $location = "'" + ($link.Target -replace "'", "''") + "'!A1"
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
            $sheetTags.ToString() + '</sheets></workbook>')

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

function Save-Rows {
    param($Rows, [string]$Path, [string]$Fmt, [string]$SheetName = 'data', $Header)

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }

    if ($Fmt -eq 'xlsx') {
        # A single-sheet workbook has no Overview to link back to.
        Save-Workbook -Path $Path -Sheets @([pscustomobject]@{
                Name   = $SheetName
                Rows   = $Rows
                Header = $Header
                BackTo = $null
            })
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
        [string]$Status
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

    return [pscustomobject]@{
        CheckId     = $Job.CheckId
        Name        = $Job.Name
        What        = $Job.What
        Rows        = $Rows
        Seconds     = $Seconds
        Status      = $Status
        Signal      = $signal
        SignalReason = $reason
    }
}

function Save-RunSummaryCsv {
    param($Summary, [string]$Path)
    $Summary | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8
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

    $tabOf = @{}
    $shortened = @()
    foreach ($item in $Collected) {
        $preferred = if ($item.Job.Name) { $item.Job.Name } else { $item.Job.CheckId }
        $abbreviated = Get-ShortSheetName -Name $preferred
        $sheetName = ConvertTo-SheetName -Preferred $abbreviated -Fallback $item.Job.CheckId -Used $used
        $tabOf[$item.Job.CheckId] = $sheetName
        # Abbreviation is lossless enough to pass unreported; only a name that still had
        # to be cut is worth flagging.
        if ($sheetName -ne $abbreviated) {
            $shortened += [pscustomobject]@{ CheckId = $item.Job.CheckId; Wanted = $preferred; Tab = $sheetName }
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

        $overviewRows += [pscustomobject]@{
            'Sport'         = Get-SportFromCheckId -CheckId $entry.CheckId
            'CheckID'       = $entry.CheckId
            'Check Name'    = $entry.Name
            'What it does'  = $entry.What
            'Rows'          = $rowsCell
            'Status'        = 'Not Started'
            'Check By'      = ''
            'Signal'        = $(if ($entry.Signal) { $entry.Signal } else { 'Actionable' })
            'Signal reason' = [string]$entry.SignalReason
        }
        # Rows carries the jump to the tab, so its column moves with it.
        if ($ran -and $tabOf.ContainsKey($entry.CheckId)) {
            $links += [pscustomobject]@{
                Ref    = "E$overviewRow"
                Target = $tabOf[$entry.CheckId]
                Text   = [string]$entry.Rows
            }
        }
    }

    # Signal and Signal reason are the runner's own classification, settled before the run
    # and unchanged by reading it, so they are collapsed out of the reviewer's way rather
    # than dropped: H and I still carry every value for whoever needs to unhide them.
    $sheets = @([pscustomobject]@{
            Name           = $overviewName
            Rows           = $overviewRows
            Header         = $null
            BackTo         = $null
            Links          = $links
            HiddenColumns  = @(8, 9)
            Validation     = @{
                Sqref  = "F2:F$overviewRow"
                Values = 'Not Started,In Progress,IT Task,Completed'
            }
        })

    # Comment and Check By are written empty on purpose: both columns are the reviewer's,
    # and the workbook only supplies their headings.
    foreach ($item in $Collected) {
        $sheets += [pscustomobject]@{
            Name   = $tabOf[$item.Job.CheckId]
            Rows   = $item.Rows
            Header = @($item.Job.CheckId, $item.Job.Name, (ConvertTo-SingleLineSql -Sql $item.Job.Sql),
                $item.Job.What, '', '',
                $(if ($item.Job.Signal) { $item.Job.Signal } else { 'Actionable' }),
                [string]$item.Job.SignalReason)
            BackTo = $overviewName
        }
    }

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

    Write-Section 'OPEN A NEW SPORT'
    Write-Line "$Entry GLOBAL-DISCOVERY-* -Sport BMX -Format xlsx" 'discover the parameters, then run'
    Write-Host '  -Sport resolves the sport ID, the statistic type and owner, and probes' -ForegroundColor DarkGray
    Write-Host '  for the physical shard. Statements needing a value picked from a summary' -ForegroundColor DarkGray
    Write-Host '  result are listed and skipped, never guessed. An explicit -SportId or' -ForegroundColor DarkGray
    Write-Host '  -Params wins over a discovered value.' -ForegroundColor DarkGray

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
    Write-Host '  The server only accepts statements starting with SELECT or WITH.' -ForegroundColor DarkGray

    Write-Section 'OUTPUT'
    Write-Line '-Format table' 'default, on-screen preview'
    Write-Line '-Format csv' 'CSV, with check_id and check_name columns'
    Write-Line '-Format json' 'JSON, with check_id and check_name fields'
    Write-Line '-Format xlsx' 'one .xlsx, tabs named after each check, Overview first'
    Write-Host '  Overview lists Sport, CheckID, Check Name, What it does, Rows and the' -ForegroundColor DarkGray
    Write-Host '  Status and Check By fields to fill in, with Signal and Signal reason' -ForegroundColor DarkGray
    Write-Host '  hidden behind them; each row count links to its tab. On a check tab' -ForegroundColor DarkGray
    Write-Host '  row 2 holds the CheckID, the name, the one-line SQL that ran and what' -ForegroundColor DarkGray
    Write-Host '  the check asserts, with empty Comment and Check By cells beside them;' -ForegroundColor DarkGray
    Write-Host '  A3 returns to Overview, and the result table starts on row 5. CSV and JSON keep' -ForegroundColor DarkGray
    Write-Host '  check_id and check_name as columns, having nowhere else to put them.' -ForegroundColor DarkGray
    Write-Host '  Files are named after the CheckID: BMX-DQ-003.csv' -ForegroundColor DarkGray
    Write-Host '  Upload the .xlsx to Google Drive and open it as Sheets to get the tabs.' -ForegroundColor DarkGray

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
# wildcards and the pattern statements they pull alongside them.
if ($sportIdentity) {
    $jobs = @(Set-JobCheckSignal -Jobs $jobs -SportName $ResolvedSportSlug)
}

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
    $runnable += $job
}

if ($skipped.Count -gt 0) {
    $impossible = @($skipped | Where-Object { $_.Kind -eq 'NOT_APPLICABLE' })
    $unselected = @($skipped | Where-Object { $_.Kind -ne 'NOT_APPLICABLE' })

    Write-Host "Skipping $($skipped.Count) statement(s):" -ForegroundColor DarkGray

    if ($impossible.Count -gt 0) {
        Write-Host "  not applicable to this sport ($($impossible.Count)):" -ForegroundColor DarkGray
        $impossible | ForEach-Object { "    {0}  {1}" -f $_.Job.CheckId, $_.Reason } | Write-Host -ForegroundColor DarkGray
    }
    if ($unselected.Count -gt 0) {
        Write-Host "  needs a value selected from a summary result ($($unselected.Count)):" -ForegroundColor DarkGray
        $unselected | ForEach-Object { "    {0}  needs {1}" -f $_.Job.CheckId, $_.Missing } | Write-Host -ForegroundColor DarkGray
    }
    Write-Host ''
}

if ($runnable.Count -eq 0) {
    throw "Nothing left to run: every matched statement is either not applicable to this sport or needs a value that must be selected from a summary result."
}

$jobs = $runnable
$isBatch = $jobs.Count -gt 1

if ($DryRun) {
    if ($isBatch) {
        Write-Host "--- $($jobs.Count) checks that would run ---" -ForegroundColor DarkGray
        $jobs | Format-Table CheckId, Name -AutoSize
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

    $summary = @()
    $collected = @()
    $index = 0
    $lastSnapshot = Get-Date

    foreach ($job in $jobs) {
        $index++
        $started = Get-Date
        $rowCount = 0
        $status = 'OK'

        try {
            $response = Invoke-SqlWithRetry -Statement $job.Sql
            $rows = Get-ResultRows -Content $response.Content
            $rowCount = @($rows).Count

            if ($rowCount -gt 0) {
                if ($isWorkbook) {
                    # A workbook names the check on the tab and on row 1, so the rows
                    # themselves stay clean.
                    $collected += [pscustomobject]@{ Job = $job; Rows = $rows }
                }
                else {
                    # A flat file has nowhere else to record which check a row came from.
                    $tagged = Add-CheckColumns -Rows $rows -CheckId $job.CheckId -Name $job.Name
                    $target = Join-Path $OutDir ((Get-SafeFileName -CheckId $job.CheckId) + $extension)
                    Save-Rows -Rows $tagged -Path $target -Fmt $Format
                }
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
            -Seconds ([math]::Round($elapsed, 1)) -Status $status

        $colour = if ($status -like 'ERROR*') { 'Red' } else { 'DarkGray' }
        Write-Host ("[{0}/{1}] {2}  rows={3}  {4:n1}s  {5}" -f `
                $index, $jobs.Count, $job.CheckId, $rowCount, $elapsed, $status) -ForegroundColor $colour

        # A run that wedges or is interrupted must not cost the checks that already
        # succeeded. Flat files are written per check as they come, so only the workbook
        # needs this. A snapshot that cannot be written - the file open in Excel, most
        # likely - is reported and skipped: it must never end the run it exists to protect.
        if ($isWorkbook -and $collected.Count -gt 0 -and $index -lt $jobs.Count -and
            ((Get-Date) - $lastSnapshot).TotalSeconds -ge $SnapshotIntervalSec) {
            try {
                Save-RunWorkbook -Summary $summary -Collected $collected -Path $workbookPath | Out-Null
                Write-Host ("        snapshot: {0} of {1} checks saved" -f $index, $jobs.Count) -ForegroundColor DarkGray
            }
            catch {
                Write-Host "        snapshot failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
            $lastSnapshot = Get-Date
        }

        if ($index -lt $jobs.Count) { Start-Sleep -Milliseconds $BatchDelayMs }
    }

    Save-SessionState -Session $script:Session

    # Statements that could not be filled belong in the record too, or the run would look
    # like it covered the whole catalogue.
    foreach ($item in $skipped) {
        $skipStatus = if ($item.Kind -eq 'NOT_APPLICABLE') {
                "SKIPPED: not applicable - $($item.Reason)"
            }
            else {
                "SKIPPED: needs $($item.Missing)"
            }
        $summary += New-RunSummaryRow -Job $item.Job -Rows 0 -Seconds 0 -Status $skipStatus
    }

    if ($isWorkbook) {
        $shortened = @(Save-RunWorkbook -Summary $summary -Collected $collected -Path $workbookPath)
        $destination = $workbookPath
    }
    else {
        Save-RunSummaryCsv -Summary $summary -Path (Join-Path $OutDir '_summary.csv')
        $destination = $OutDir
    }

    $summary | Format-Table CheckId, Name, Signal, Rows, Seconds, Status -AutoSize

    if ($isWorkbook -and $shortened.Count -gt 0) {
        Write-Host "Tab names capped at Excel's 31-character limit:" -ForegroundColor DarkGray
        $shortened | Format-Table CheckId, Wanted, Tab -AutoSize
    }

    $failed = @($summary | Where-Object { $_.Status -like 'ERROR*' }).Count
    $totalRows = ($summary | Measure-Object Rows -Sum).Sum
    Write-Host ("Done: {0} checks, {1} rows, {2} failed -> {3}" -f `
            $jobs.Count, $totalRows, $failed, $destination) -ForegroundColor DarkGray
    return
}

# ----- single run ----------------------------------------------------------------------

$job = $jobs[0]
if ($job.CheckId) {
    Write-Host "Query: $($job.CheckId)  $($job.Name)" -ForegroundColor DarkGray
}

$started = Get-Date
$response = Invoke-SqlWithRetry -Statement $job.Sql
$elapsed = (Get-Date) - $started

Save-SessionState -Session $script:Session

$rows = Get-ResultRows -Content $response.Content
$count = @($rows).Count
Write-Host ("Rows: {0}   Elapsed: {1:n1}s" -f $count, $elapsed.TotalSeconds) -ForegroundColor DarkGray

# A workbook cannot be printed, so it always lands somewhere on disk.
if ($isWorkbook -and -not $OutFile) {
    $folder = if ($OutDir) { $OutDir } else { Get-RunFolder -Jobs $jobs }
    $OutFile = Join-Path $folder ((Get-SafeFileName -CheckId $job.CheckId) + '.xlsx')
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
        Save-Rows -Rows $rows -Path $OutFile -Fmt $Format -SheetName $sheetName `
            -Header @($job.CheckId, $job.Name, (ConvertTo-SingleLineSql -Sql $job.Sql),
                $job.What, '', '', $singleSignal, $singleReason)
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
