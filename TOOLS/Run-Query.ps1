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
    Overview, lists Sport, CheckID, Object, Check Name, What it does, Rows and the Status,
    Check By and Comment fields for every check, with each row count linking to its tab. Object
    is the layer the check audits, in the six words POWERBI.md collapses the registry's Object
    column to, and it is what says which layer to repair first. Signal and Signal reason follow,
    hidden. The check tabs are named after the "-- Name -" header, abbreviated to
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

    Only one run is live on the machine at a time, whoever started it. The lock is a file
    held open for writing under %LOCALAPPDATA%\entpulse-qb; a second run waits for it and says
    what it is waiting for, and nothing has to be cleaned up because the handle dies with the
    process. -Info, -History, -ListChecks and -DryRun are outside it and stay free. -NoWait
    refuses to wait and exits 75 instead, which is what the Sheets worker reads as WAITING;
    -LockWaitSeconds sets how long a waiting run waits, and -NoLock skips the lock entirely.

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

    # Narrows the run to the checks that read a given stored value: -DataType rank, or
    # -DataType 100 for one exact type id. A name matches every layer storing it, so `rank`
    # takes both 100 Rank on an event result and 1270 Rank in a Comp.Rank, which is what a
    # repair actually looks like. Several may be named at once. What each check reads is
    # derived from its own rendered SQL, so the selection cannot fall out of step with the
    # statements; a check reading none of the named types is reported as skipped rather than
    # silently dropped, so a run that matched nothing says so.
    [string[]]$DataType,

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

    # What a check has returned across every recorded run, read out of RUNS/<Sport>.json. The
    # live document compares this run with the one before it and nothing else; this is where
    # the first run and the tenth sit side by side. Takes a CheckID or a wildcard, and finds
    # the sport in the prefix.
    [string]$History,

    # Prints the full command set. The cqb wrapper maps a bare "info" onto this.
    [switch]$Info,

    [switch]$Relogin,

    # A run that leaves no trace. Trying a new statement, checking whether a fix took, running
    # a narrowed slice that is not the sport's periodic pass: none of those should sit in the
    # history the next run compares itself against, and none should touch what a reviewer is
    # looking at. The results are still written, under a folder named TEST <Sport> <stamp>, so
    # the run can be read and the folder can be deleted without anyone having to remember
    # which ones were real.
    [switch]$TestRun,

    # The live per-sport Google Sheet to update, as the id out of its URL: the part between
    # /d/ and /edit. Needed once per sport - after a run has written to it the id is kept in
    # that sport's RUNS/<Sport>.json, and later runs find it there.
    [string]$SheetId,

    # What to call the document, used while it is still called Untitled spreadsheet or still
    # carries a name this runner gave it. Defaults to "DQ <Sport> Enetpulse". A document
    # somebody has named themselves is left alone, whoever named it.
    [string]$SheetTitle,

    # Skip the live document for this run, and write only the workbook. For a run that is real
    # enough to record but that should not reach the people reading the sheet.
    [switch]$NoSheet,
    [switch]$NoLedger,

    # Run without taking the machine-wide lock. For a reader that only wants rows out of a
    # statement while a board refresh is under way, and for a caller that already holds it.
    # It does not make two runs safe to overlap; it says this one accepts that risk.
    [switch]$NoLock,

    # Do not wait for the lock: if another run holds it, say who and stop. The Sheets worker
    # uses this to write WAITING and a reason into the request row instead of blocking.
    [switch]$NoWait,

    # How long to wait for the lock before giving up. The default covers a full board refresh
    # of the largest sport, because waiting behind one is the normal case rather than a fault.
    [int]$LockWaitSeconds = 2700,

    # Dot-source the file for its functions and stop before Main. TOOLS/Test-Tools.ps1 uses
    # it to exercise selection, parameter expansion, the parser and the workbook writer
    # without a login or a statement. Nothing in a normal run passes it.
    [switch]$DotSourceOnly
)

$ErrorActionPreference = 'Stop'

# The machine-wide run lock: the open handle while this run holds it, and what was in the
# way when it could not. Both are read by Main and by TOOLS/Test-Tools.ps1.
$script:RunLockStream = $null
$script:RunLockBlockedBy = $null

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

# How many runs -History puts across the page when it pivots. A run id is thirty characters
# and the numbers under it are two or three, so the width is set by the count of columns
# rather than by anything in them. What is cut is reported, never dropped quietly, and asking
# for one check shows every run it has.
$HistoryRunColumns = 12

# How many runs the History tab carries, this one included. The oldest falls off the end to
# make room for the newest, which is the whole of the rule: the tab is a window onto
# RUNS/<Sport>.json and never a second copy of it, and nothing is deleted from the ledger to
# keep the window this size.
#
# Forty rather than thirty or fifty. It is a year of weekly runs, it holds every recorded run
# of six of the twelve sports as this is written, and the largest tab it produces today is
# Curling at 1664 rows - one range write against the eleven hundred a board already sends. A
# year of weekly runs at a hundred and twenty checks would make that 4800 rows, which is still
# one write and still well inside what Sheets will hold. What bounds it is not the cell count
# but how far back a reviewer will ever scroll.
$SheetHistoryRuns = 40

# How many runs the Trends column carries, this one included. The document compares against
# one run and the ledger holds them all; this is the middle, and the middle is what answers
# "is this moving" without opening anything. Short enough to stay one readable cell.
$TrendRunCount = 5

# How each point in that cell is dated. A bare series says a check moved but not when, and
# "when" is the whole question after colleagues report a fix: four zeroes in a row mean one
# thing across four weeks and another across one afternoon.
#
# Two formats rather than one, chosen per run over the whole tail rather than per row, so the
# column stays a single shape a reader can scan. The short one is what a weekly cadence wants;
# the long one appears only when two runs in the window fall on the same calendar day, which
# is exactly when the date alone would print the same label twice and say nothing.
$TrendStampShort = 'dd.MM'
$TrendStampLong = 'dd.MM HH:mm'
$script:TrendStampFormat = $TrendStampShort

# What separates the runs in that cell. Built from its code point rather than typed, as
# Test-Package.ps1 builds its em dash: these scripts stay pure ASCII because Windows
# PowerShell 5.1 reads a .ps1 without a BOM as ANSI, and the rule is about the source file
# rather than about what it writes. The cell gets the real arrow.
#
# Not '>', which is what this was first written with. In a cell full of numbers that reads as
# a comparison operator, so "100 > 105" states something plainly false. The series is
# chronological and the separator should say so and nothing else.
$TrendSeparator = ' ' + [string][char]0x2192 + ' '

# The last few findings counts per run key, read once before the batch alongside the previous
# run. Same snapshot rule: taken before this run appends, so nothing counts itself twice.
$script:RecentFindings = @{}

# The live per-sport document. Kept in its own file rather than added to this one: the merge
# is where the defects live and it has to be testable without a login, so nothing in Sheets.ps1
# reaches the network. It is dot-sourced rather than run, so -DotSourceOnly picks it up too.
. (Join-Path $PSScriptRoot 'Sheets.ps1')

# What the run says out loud to somebody who is not looking at a board. Kept out of both files
# above for the same reason they are kept apart: the queue and the wording are pure functions
# over what a run already produced and are tested without a login, and nothing here may fail a
# run. See TOOLS/Notify.ps1.
. (Join-Path $PSScriptRoot 'Notify.ps1')

# Which checks a nightly pass would run, and what it may cost. Kept apart for the reason the
# two files above are: the rule is where the defects live and it has to be exercisable against
# sixteen real ledgers without a login. See TOOLS/Nightly.ps1.
. (Join-Path $PSScriptRoot 'Nightly.ps1')

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

function Get-CatalogueFingerprint {
    # What the catalogue was parsed from, cheaply enough to check on every call: the number of
    # source files, their total length and the newest write time. Stat calls, not reads.
    $files = @(Get-QuerySourceFiles)
    if ($files.Count -eq 0) { return '0' }
    $length = (@($files | ForEach-Object { [long]$_.Length }) | Measure-Object -Sum).Sum
    $newest = (@($files | ForEach-Object { $_.LastWriteTimeUtc.Ticks }) | Measure-Object -Maximum).Maximum
    return ('{0}|{1}|{2}|{3}' -f $RepoRoot, $files.Count, $length, $newest)
}

$script:CheckCatalogueCache = @{}

function Get-CheckCatalogue {
    # Every registered check, with the SQL body attached. Statements are separated by the
    # "-- ====..." banner lines used across the repo.
    #
    # Parsed once and kept, because a single -RunAll asks for the catalogue three times and
    # re-reading all twenty-four SQL files costs about 0.4 seconds each time. The cache is keyed
    # on the repository root and on what the files themselves look like, not on the root alone:
    # Test-Tools.ps1 dot-sources this script once and then points $RepoRoot at a fixture
    # catalogue and back, and rewrites SQL files between calls. A cache keyed on the root alone
    # would hand the fixture's checks to the test that asked for the real ones.
    $fingerprint = Get-CatalogueFingerprint
    if ($script:CheckCatalogueCache.ContainsKey($fingerprint)) {
        return $script:CheckCatalogueCache[$fingerprint]
    }

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

    $script:CheckCatalogueCache[$fingerprint] = $catalogue
    return $catalogue
}

function Select-RegistryChecks {
    <#
        A sport CheckID that names no statement of its own, resolved the way -RunAll resolves
        it: through the registry row, to the template that row instantiates.

        Most checks are like this. Artistic Gymnastics approves 99 and only 10 are statements
        the sport wrote; the other 89 are rows pointing at a GLOBAL_DQ template. Without this,
        nine in ten checks could only be run by running the whole sport - fifteen minutes to
        see whether one correction took.

        Approved rows only. A Deprecated row keeps its CheckID for good and must not run
        because somebody typed it.
    #>
    param([string]$Pattern, $Catalogue)

    if ($Pattern -notmatch '^(.+)-DQ-') { return @() }
    $sport = $matches[1]
    if ($sport -eq 'GLOBAL') { return @() }

    $rows = @()
    try { $rows = @(Get-RegistryRow -SportName $sport) } catch { return @() }

    $byId = @{}
    foreach ($entry in $Catalogue) { $byId[$entry.CheckId] = $entry }

    $jobs = @()
    foreach ($row in @($rows | Where-Object { $_.Status -eq 'Approved' -and $_.CheckId -like $Pattern } | Sort-Object CheckId)) {
        # The Query file decides which statement runs, exactly as it does under -RunAll: a
        # GLOBAL_DQ path means the row instantiates its Family, anything else means the sport
        # authored its own and the row's own CheckID names it.
        $wanted = $(if ($row.QueryFile -like 'GLOBAL_DQ/*') { $row.Family } else { $row.CheckId })
        if (-not $byId.ContainsKey($wanted)) { continue }
        $statement = $byId[$wanted]

        # The row's CheckID travels with the result, never the template's. Signal and the
        # expectation are hydrated later, off Template and CheckId, by the same two passes
        # every other selection goes through.
        $jobs += [pscustomobject]@{
            CheckId  = $row.CheckId
            Name     = $statement.Name
            What     = $statement.What
            File     = $statement.File
            Line     = $statement.Line
            Path     = $statement.Path
            Sql      = $statement.Sql
            Template = $(if ($wanted -eq $row.CheckId) { '' } else { $wanted })
            Category = $row.Category
            Object   = $row.Object
        }
    }
    return $jobs
}

function Select-Checks {
    param([string[]]$Patterns)

    $catalogue = Get-CheckCatalogue
    $selected = @()

    foreach ($pattern in $Patterns) {
        $hits = @($catalogue | Where-Object { $_.CheckId -like $pattern } | Sort-Object CheckId)

        # A sport CheckID naming no statement is the normal case rather than the exception,
        # so the registry is consulted before this is called a miss.
        if ($hits.Count -eq 0) {
            $hits = @(Select-RegistryChecks -Pattern $pattern -Catalogue $catalogue)
        }

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
            Object       = $row.Object
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
        Object       = $(if ($Job.PSObject.Properties.Name -contains 'Object') { [string]$Job.Object } else { '' })
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
'(?m)^([ \t]*)--[ \t]*AND[ \t]+(\w+)\.(id|tournament_templateFK)[ \t]*=[ \t]*<tournament_template_id>[ \t]*\r?$'

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
'(?m)^([ \t]*)--[ \t]*AND[ \t]+([\w.]+)[ \t]+BETWEEN[ \t]+<from_([a-z_]+)_id>[ \t]+AND[ \t]+<to_[a-z_]+_id>[ \t]*\r?$'

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

    $coverage = $null
    $total = 0

    # Sized up front, for the reason spelled out in Add-CheckColumns. It matters more here than
    # anywhere: this function only runs when a statement had to be cut into id windows, which
    # only happens because its result was too large for one request - so the one path that
    # appends row by row is the one guaranteed to have the most rows to append.
    $room = 0
    foreach ($rows in $Parts) { $room += @($rows).Count }
    $findings = [object[]]::new($room + 1)
    $kept = 0

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
            $findings[$kept] = $row
            $kept++
        }
    }

    # The single merged COVERAGE row goes last, exactly where appending put it, because
    # COVERAGE sorts last by contract and a reader of the merged result must not find it
    # in the middle.
    if ($null -ne $coverage) {
        $coverage.eligible_count = $total
        $findings[$kept] = $coverage
        $kept++
    }

    # Returned without the comma-wrap idiom, exactly as this function always has. A caller
    # writing @(Merge-ShardedRows ...) collects the raw pipeline output, and a wrapped array
    # arrives there as one item rather than as its rows - which is a merged result of 1.
    if ($kept -eq 0) { return @() }
    if ($kept -eq $findings.Count) { return $findings }
    return @($findings[0..($kept - 1)])
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

# The Comp.Rank branch of a statement that reaches the same people another way as well. A
# sport opened without that layer has no confirmed SHARD_ID or STATISTIC_TYPE_ID, so the branch
# cannot be written at all, and refusing the whole statement would leave the sport with no check
# over the paths it can read. Unlike the registry branch this is not a switch: what the sport has
# had confirmed decides it, so it cannot be remembered on one run and forgotten on the next, and
# it stops applying by itself on the day the parameters are recorded.
$StatisticBranchMarker =
'(?ms)^[ \t]*--[ \t]*STATISTIC BRANCH BEGIN[ \t]*\r?\n.*?^[ \t]*--[ \t]*STATISTIC BRANCH END[ \t]*\r?\n'

# The parameters the marked branch is written from. Both must be confirmed for it to stand.
$StatisticBranchParameters = @('SHARD_ID', 'STATISTIC_TYPE_ID')

function Remove-StatisticBranch {
    # Removes every marked branch and reports how many it found.
    param([string]$Text)

    $found = [regex]::Matches($Text, $StatisticBranchMarker)
    $stripped = [regex]::Replace($Text, $StatisticBranchMarker, '')

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
    # The values are encrypted with DPAPI before they touch the disk, because one of them is
    # not a session at all: remember_web_* is a persistent credential, and anything that can
    # read the file can log in as the user until it is revoked.
    #
    # DPAPI rather than an ACL, because the ACL is not this project's to set. %LOCALAPPDATA%
    # grants CodexSandboxUsers read by inheritance, machine-wide, for the agent sandboxes that
    # run here - tightening one folder underneath it would be this repository quietly editing
    # the machine. ConvertFrom-SecureString keys the ciphertext to the user account instead, so
    # those accounts still read the bytes and get nothing they can open. The wire is a separate
    # question and not one this file can answer: the server offers no TLS port, and reaching it
    # at all goes through the VPN.
    param($Session)

    if (-not (Test-Path $StateDir)) { New-Item -ItemType Directory -Path $StateDir | Out-Null }
    $uri = [uri]$BaseUrl

    # Keep the newest cookie per name, otherwise a stale duplicate can win on restore.
    $latest = [ordered]@{}
    foreach ($c in $Session.Cookies.GetCookies($uri)) { $latest[$c.Name] = $c.Value }

    $bag = @()
    foreach ($name in $latest.Keys) {
        $secure = ConvertTo-SecureString -String ([string]$latest[$name]) -AsPlainText -Force
        $bag += @{ Name = $name; Protected = (ConvertFrom-SecureString -SecureString $secure) }
    }
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

    # A file written before the values were protected has Value and no Protected, and a file
    # written by another user account cannot be unprotected by this one. Both return $null and
    # cost a fresh login, which is what this function already does for a file it cannot parse.
    $session = New-EmptySession
    foreach ($c in $bag) {
        if (-not $c.Protected) { return $null }
        try {
            $secure = ConvertTo-SecureString -String ([string]$c.Protected)
            $plain = [Runtime.InteropServices.Marshal]::PtrToStringUni(
                [Runtime.InteropServices.Marshal]::SecureStringToGlobalAllocUnicode($secure))
        }
        catch { return $null }
        Add-CookieToSession -Session $session -Name $c.Name -Value $plain
    }
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

# Statements the watchdog gave up on, and the runspace each one is still holding.
#
# The abandonment is deliberate and explained where it happens. What this adds is that it stops
# being invisible: nothing counted it, so 'a thread and a socket until the process exits' was a
# sentence in a comment rather than a number anybody could check. Measured over the 23126 check
# rows recorded to 2026-08-30 it has never once fired - every one of the 325 failures came back
# through the normal path and disposed - which is exactly why it needs counting rather than
# rebuilding: a mechanism nobody can see is one nobody can tell has started misbehaving.
$script:AbandonedShells = @()

function Close-AbandonedShells {
    # Called once, after every statement has run. A shell whose runspace has since come to rest
    # can be disposed now for free, because Dispose only blocks while Stop is still waiting on
    # the call that wedged. One still Running or Stopping is left exactly where it was: waiting
    # on it here would hang the end of a run that had otherwise finished, which is the failure
    # the abandonment exists to avoid in the first place.
    if (@($script:AbandonedShells).Count -eq 0) { return }

    $held = @($script:AbandonedShells)
    $labels = @($held | ForEach-Object { [string]$_.Label })
    $reclaimed = 0
    $still = @()
    foreach ($one in $held) {
        $state = ''
        try { $state = [string]$one.Shell.InvocationStateInfo.State } catch { $state = '' }
        if ($state -eq 'Stopped' -or $state -eq 'Completed' -or $state -eq 'Failed') {
            try { $one.Shell.Dispose(); $reclaimed++ } catch { $still += $one }
        }
        else { $still += $one }
    }
    $script:AbandonedShells = $still

    Write-Host ('  Abandoned by the watchdog, so nothing was audited for: {0}' -f `
            ($labels -join ', ')) -ForegroundColor Yellow
    Write-Host ('  {0} of {1} connection(s) had since come to rest and were released; {2} left holding a thread and a socket until this process exits' -f `
            $reclaimed, $held.Count, $still.Count) -ForegroundColor Yellow
}
function Invoke-RemoteSql {
    param($Session, [string]$Statement, [string]$Label = '')

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
        # Kept rather than dropped, so the end of the run can say how many there were and
        # release the ones whose connections have since died. Holding the reference costs
        # nothing the abandoned runspace was not already costing.
        $script:AbandonedShells += [pscustomobject]@{
            Shell = $shell
            Label = $(if ($Label) { [string]$Label } else { 'a statement' })
            At    = (Get-Date)
        }
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
    param([string]$Statement, [string]$Label = '')

    try {
        return Invoke-RemoteSql -Session $script:Session -Statement $Statement -Label $Label
    }
    catch {
        $status = 0
        if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }

        if ($status -eq 401 -or $status -eq 403 -or $status -eq 419) {
            Write-Host "Session rejected (HTTP $status), logging in again..." -ForegroundColor DarkGray
            if (Test-Path $StatePath) { Remove-Item -LiteralPath $StatePath -Force }
            $script:Session = New-AuthenticatedSession
            return Invoke-RemoteSql -Session $script:Session -Statement $Statement -Label $Label
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
    param([string]$Statement, [long]$From, [long]$To, [int]$Depth = 0, [string]$Label = '')

    $shard = Enable-ShardFilter -Text $Statement -From $From -To $To

    try {
        return Get-ResultRows -Content (Invoke-SqlWithRetry -Statement $shard.Sql -Label $Label).Content
    }
    catch {
        if (-not (Test-ResultTooLarge -Message $_.Exception.Message)) { throw }
        if ($Depth -ge $MaxShardDepth -or $From -ge $To) { throw }

        $mid = [long][math]::Floor(($From + $To) / 2)
        $left = Invoke-ShardedSql -Statement $Statement -From $From -To $mid -Depth ($Depth + 1) -Label $Label
        $right = Invoke-ShardedSql -Statement $Statement -From ($mid + 1) -To $To -Depth ($Depth + 1) -Label $Label
        return Merge-ShardedRows -Parts @($left, $right)
    }
}

function Get-StatementRows {
    # One statement's rows. Whole where the transport can carry them, cut into id windows and
    # merged where it cannot - so a batch is not lost to the one check whose findings outgrew
    # the connection, and nobody has to know in advance which check that is.
    param([string]$Statement, [string]$CheckId)

    try {
        return Get-ResultRows -Content (Invoke-SqlWithRetry -Statement $Statement -Label $CheckId).Content
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
            $parts += , (Invoke-ShardedSql -Statement $Statement -From $lo -To $hi -Depth 1 -Label $CheckId)
        }

        return Merge-ShardedRows -Parts $parts
    }
}

# The parameters Resolve-SportParameters can read from the database. Anything else has to
# come from SPORTS/params.json or the command line: a value the runner cannot confirm is
# never guessed.
$DiscoverableParameters = @('SPORT_ID', 'STATISTIC_TYPE_ID', 'STATISTIC_OWNER_TYPE_ID', 'SHARD_ID')

# The client boundary, and the form a sport may declare it in instead. Named here rather than
# written out at each use because Test-Package.ps1 holds the same pair and the two files are one
# contract: what the sport file may say, and what every statement ends up reading.
$ClientScopeParameter = 'OUT_OF_SCOPE_TEMPLATE_ID_LIST'
$InScopeParameter = 'IN_SCOPE_TEMPLATE_ID_LIST'

# The named keys inside a sport's SPORTS/params.json entry that are not themselves parameters.
# _notApplicable holds the parameters the sport is documented as unable to supply, mapped to
# the reason. _checkSignal holds what a check's output is worth for this sport, for the ones
# that are not simply actionable. _expected holds what a re-run should return once the data
# has been corrected. _names holds, for every parameter carrying database ids, what those ids
# are called - written for a reader rather than for the runner. Test-Package.ps1 declares the
# same names; the pair of files is the contract for all four blocks.
$NotApplicableKey = '_notApplicable'
$CheckSignalKey = '_checkSignal'
$ExpectedKey = '_expected'
$NamesKey = '_names'
$ReservedParamKeys = @($NotApplicableKey, $CheckSignalKey, $ExpectedKey, $NamesKey)

# What a recorded signal may say. Actionable is the default and is never recorded: writing it
# down for every check would make the block a second copy of the registry. Deprecated is
# deliberately absent - POWERBI_REGISTRY.md's Status column owns that, and a value with two
# owners drifts.
$CheckSignalValues = @('Monitor', 'Informational', 'Blocked', 'Not applicable',
    'Out of client scope', 'Sentinel')

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

# The default each signal implies, so only the exception is written down. Blocked, Not
# applicable and Out of client scope are absent rather than empty: a check that must not run
# yet, that reads a layer the sport does not have, or whose whole population sits outside the
# client's boundary has no count anybody should be expecting.
#
# Sentinel is present, and that is the difference between it and the three that are absent. It
# is a live check whose population has not arrived, not a check nobody should be counting: the
# day a row of the kind it reads is imported, every finding it returns is a defect. Recording
# the expectation now rather than on that day is the whole reason the block exists.
$ExpectedBySignal = @{
    'Actionable'    = 'Zero'
    'Monitor'       = 'Non-zero'
    'Informational' = 'Non-zero'
    'Sentinel'      = 'Zero'
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
    # Two records where the database should hold one. The value in each is present and may be
    # perfectly correct on its own - what is wrong is that there are two of them, and every
    # count read through either is short by whatever the other carries. Recorded 2026-08-11.
    'DUPLICATE_RECORD'    = '2 Wrong value'
    'MISSING_VALUES'      = '3 Missing value'
    # Not a defect family at all: a pattern summary is a census of how something is spelled or
    # used, and its rows are groups with counts rather than things to correct. It sorts below
    # every band that names a defect, which is what a fourth number buys over a blank.
    'PATTERNS'            = '4 Patterns'
}

# Discovery is a census by construction: its rows are categories with counts, and a category
# cannot be corrected the way a missing birth date can. So every statement in GLOBAL_QUERIES
# is informational without a sport having to say so, and the reviewer is told once rather than
# left to infer it from the shape of each result.
$DiscoveryCheckIdPattern = 'GLOBAL-DISCOVERY-*'
$DiscoverySignalReason = 'Discovery: the output describes the population rather than finding defects in it, so no row is correctable.'

# The discovery statements that ride along with a whole-sport run besides the pattern
# summaries, and the defect family each one reports. Two separate things are being said here
# and both are exceptions to a rule above, so both are written down rather than derived.
#
# Riding along: -WithPatterns selects PATTERNS.sql on the strength of its file, which holds
# nothing but census summaries. A statement elsewhere in GLOBAL_QUERIES has to be named,
# because the file it lives in also holds drill-downs whose parameter is a value read out of
# another result - and choosing one of those automatically would put a sample on the board
# dressed up as coverage.
#
# The family: discovery carries no category, because a census has no defect family. These do.
# GLOBAL-DISCOVERY-033 groups people whose records look like two entries for one person, and
# a duplicate is correctable by merging - so it takes a real category and the band that
# follows from it, while staying Informational, which is what puts it on the board as
# Monitor Only expecting a non-zero count. Watch it, do not drive it to zero.
#
# Recorded by decision of 2026-08-11.
$RideAlongDiscovery = @{
    'GLOBAL-DISCOVERY-033' = 'DUPLICATE_RECORD'
}

# --------------------------------------------------------------------------------------
# Which stored values a check reads
#
# The vocabulary is the one the people repairing the data work in: 100 Rank, 101 Duration,
# 104 Comment, 1277 Medal. Colleagues correct one defect family at a time and then have to
# re-run everything the corrected field reaches, and until this existed the only way to find
# those checks was to open every statement and read it.
#
# **Derived from the rendered SQL rather than authored against the CheckID**, and that is what
# keeps it honest. A GLOBAL template names its types through declared parameters and a sport
# statement carries the numbers directly - the package forbids parameters there - but after
# expansion both are plain numbers in the same columns, so one parser answers for all 261
# statements and nothing can drift out of step with the statement it describes. A hand-kept
# column over 1147 registry rows would say whatever it said when it was last edited.
#
# `round_typeFK` and `incident_typeFK` are deliberately outside the vocabulary. A round is
# structure rather than a stored value nobody repairs field by field, and `ROUND_TYPE_LIST`
# would put twenty-six ids into a column meant to be read at a glance.
# --------------------------------------------------------------------------------------

# The layers a stored value can live in, in the order the board prints them, with the reference
# table each is named from.
#
# **`statistic_data_type` is one catalogue read by two different owners**, and the column name
# cannot tell them apart: `statistic_dataN.statistic_data_typeFK` types a value belonging to one
# ranked participant, `statistic_config.statistic_data_typeFK` types a setting belonging to the
# whole ranking, and both are spelled the same. Flattened into one list they read as fields of
# one kind - `1270 Rank, 1463 Start date, 1273 Comment` looks like three of the same thing and is
# two participant values and one setting of the statistic, repaired in completely different
# ways. DATABASE.md draws the distinction under "statistic_config"; the board now keeps it.
#
# `Comp.Rank` is the right label for `statistic_dataN` here because this package audits statistic
# type 11 and nothing else - SPORTS/params.json records `STATISTIC_TYPE_ID` as 11 for all eleven
# sports. A package that ever audited a second statistic type would have to name the layer from
# the type rather than assume it.
$DataTypeLayers = [ordered]@{
    'result'     = @{ Label = 'Result'; Table = 'result_type' }
    'data'       = @{ Label = 'Comp.Rank'; Table = 'statistic_data_type' }
    'config'     = @{ Label = 'Setting'; Table = 'statistic_data_type' }
    'scope'      = @{ Label = 'Scope'; Table = 'scope_type' }
    'scope_data' = @{ Label = 'Scope field'; Table = 'scope_data_type' }
}

# The type columns whose owning table is settled by the column name alone.
$DataTypeSimpleColumns = [ordered]@{
    'result_typeFK'     = 'result'
    'scope_data_typeFK' = 'scope_data'
    'scope_typeFK'      = 'scope'
}

function Remove-SqlComment {
    # Comment text is prose about the check and names types by number as it explains them -
    # "104 Comment holds the vocabulary" - so parsing it would report what a statement talks
    # about rather than what it reads. The commented template and date filters live there too,
    # and an inactive filter is not something the check touches.
    param([string]$Sql)

    return [regex]::Replace($Sql, '(?m)--.*$', '')
}

function Get-StatementDataType {
    # The (layer, id) pairs one rendered statement reads, grouped by layer in the order above
    # and kept in the order the statement reads them inside each. The reading order is worth
    # keeping: GLOBAL-DQ-101 reaches the rank through the medal, and a list starting at Medal
    # says something a sorted one does not.
    #
    # `NOT IN` counts as reading. A type excluded from a scope still decides which rows come
    # back, so correcting it changes the finding - which is exactly what somebody re-running
    # after a repair needs to know. The narrower question, what the check asserts rather than
    # what it reads, is the `-- Audits:` line below.
    param([string]$Sql)

    $bare = Remove-SqlComment -Sql $Sql
    $found = [ordered]@{}

    function Add-Ref {
        param([string]$Layer, [string]$Digits)

        foreach ($id in [regex]::Matches($Digits, '\d+')) {
            $key = '{0}|{1}' -f $Layer, $id.Value
            if (-not $found.Contains($key)) {
                $found[$key] = [pscustomobject]@{ Layer = $Layer; Id = [int]$id.Value }
            }
        }
    }

    # A digit has to follow, so `r.result_typeFK = r2.result_typeFK` in a self-join is not read
    # as a type reference - it names the column twice and no value at all. The lookbehind stops
    # a longer column name matching a shorter one inside it while still allowing the `sd.` an
    # alias puts in front.
    foreach ($column in $DataTypeSimpleColumns.Keys) {
        $pattern = '(?<![A-Za-z0-9_])' + [regex]::Escape($column) + '\s*(?:=\s*|(?:NOT\s+)?IN\s*\(\s*)([0-9][0-9,\s]*)'
        foreach ($match in [regex]::Matches($bare, $pattern, 'IgnoreCase')) {
            Add-Ref -Layer $DataTypeSimpleColumns[$column] -Digits $match.Groups[1].Value
        }
    }

    # Which alias owns which table, so a `statistic_data_typeFK` reference can be attributed.
    # Measured across the package on 2026-08-21: all 145 such references carry an alias and
    # every alias binds to one of these two, none to neither. An unbound alias would still be
    # read as a participant field, which is the commoner of the two and the safer guess.
    $configAlias = @{}
    foreach ($match in [regex]::Matches($bare, 'statistic_config\s+(\w+)', 'IgnoreCase')) {
        $configAlias[$match.Groups[1].Value] = $true
    }

    $pattern = '(?:(\w+)\.)?statistic_data_typeFK\s*(?:=\s*|(?:NOT\s+)?IN\s*\(\s*)([0-9][0-9,\s]*)'
    foreach ($match in [regex]::Matches($bare, $pattern, 'IgnoreCase')) {
        $alias = $match.Groups[1].Value
        $layer = $(if ($alias -and $configAlias.ContainsKey($alias)) { 'config' } else { 'data' })
        Add-Ref -Layer $layer -Digits $match.Groups[2].Value
    }

    $ordered = @()
    foreach ($layer in $DataTypeLayers.Keys) {
        $ordered += @($found.Values | Where-Object { $_.Layer -eq $layer })
    }
    return , $ordered
}

function Get-StatementAuditedTypes {
    # The optional hand-written corrective, for the statement whose assertion is narrower than
    # its scope: a check reading 104 Comment only to exclude the rows that have one, while what
    # it asserts is about 100 Rank, reads both and audits one.
    #
    # It is a line in the prose block rather than a fourth identity comment, because the
    # identity header is exactly three lines and TOOLS/Test-Package.ps1 fails a fourth:
    #
    #     -- Audits: 100, 101
    #
    # Nothing carries one today. The mechanism exists so that the first statement whose derived
    # list misleads a reader can be corrected in the statement itself, beside the assertion it
    # describes, rather than in a table somewhere else.
    param([string]$Sql)

    $match = [regex]::Match($Sql, '(?m)^\s*--\s*Audits:\s*(.+)$')
    if (-not $match.Success) { return @() }

    return @([regex]::Matches($match.Groups[1].Value, '\d+') | ForEach-Object { [int]$_.Value })
}

function Resolve-DataTypeName {
    # One query for every id the whole run needs. The names live in four small reference tables
    # and asking per statement would be a hundred round trips to fill one column. Comp.Rank and
    # Setting share `statistic_data_type` and are asked for separately, because the ids differ
    # and a branch each is cheaper to build than a union of them here.
    param($Refs)

    $names = @{}
    $refs = @($Refs)
    if ($refs.Count -eq 0) { return $names }

    $branches = @()
    foreach ($layer in $DataTypeLayers.Keys) {
        $ids = @($refs | Where-Object { $_.Layer -eq $layer } | ForEach-Object { $_.Id } | Sort-Object -Unique)
        if ($ids.Count -eq 0) { continue }
        $branches += "SELECT '$layer' AS layer, id, name FROM $($DataTypeLayers[$layer].Table) WHERE id IN ($($ids -join ', '))"
    }
    if ($branches.Count -eq 0) { return $names }

    Confirm-RunnerSession

    try {
        $rows = Get-ResultRows -Content (Invoke-SqlWithRetry -Statement ($branches -join "`nUNION ALL`n")).Content
    }
    catch {
        # A column is not worth failing a run for. An unnamed id still identifies the type and
        # still selects the check, so the run carries the numbers and says so once.
        Write-Host "  could not name the data types ($($_.Exception.Message))" -ForegroundColor DarkGray
        return $names
    }

    foreach ($row in @($rows)) {
        $names[('{0}|{1}' -f [string]$row.layer, [string]$row.id)] = [string]$row.name
    }
    return $names
}

function Format-DataTypeList {
    # What the board shows: each layer named, then its types as id with the name it carries.
    # Neither half of a type is enough alone - a reader who knows the sport reads 101 and a
    # reader who does not reads Duration - and the layer is what tells 100 Rank on an event
    # result from 1270 Rank in a ranking without anybody having to know the id ranges.
    param($Refs, [hashtable]$Names)

    $refs = @($Refs)
    if ($refs.Count -eq 0) { return '' }

    $groups = @()
    foreach ($layer in $DataTypeLayers.Keys) {
        $inLayer = @($refs | Where-Object { $_.Layer -eq $layer })
        if ($inLayer.Count -eq 0) { continue }

        $parts = @()
        foreach ($ref in $inLayer) {
            $key = '{0}|{1}' -f $ref.Layer, $ref.Id
            $name = $(if ($Names -and $Names.ContainsKey($key)) { $Names[$key] } else { '' })
            $parts += $(if ($name) { '{0} {1}' -f $ref.Id, $name } else { [string]$ref.Id })
        }
        $groups += '{0}: {1}' -f $DataTypeLayers[$layer].Label, ($parts -join ', ')
    }
    # A semicolon between layers and a comma inside one, and the separator has to be ASCII.
    # TOOLS/Test-Package.ps1 forbids a BOM on any file in the package, and Windows PowerShell
    # 5.1 reads a BOM-less .ps1 as ANSI rather than UTF-8 - so a middle dot written here as
    # UTF-8 is parsed as two Windows-1252 characters and reaches the board as 'A-circumflex
    # middle dot', in the file's bytes and not only on screen. Every other script in TOOLS is
    # pure ASCII and this is why; the convention was there before this line and undocumented.
    return ($groups -join '; ')
}

function Test-DataTypeMatch {
    # Whether a check reads what the user named. A number matches that id exactly; anything
    # else matches the type's name, so `-DataType rank` selects both 100 Rank and 1270 Rank
    # and `-DataType 100` selects only the event one. Matching by name is what the repair
    # actually looks like - a defect family is corrected across every layer that stores it.
    #
    # DATABASE.md says a field type must be matched by id and never by name, and this does not
    # break that rule: the names compared here are the names of ids a statement already reads,
    # resolved from those ids, and no id is ever looked up by name from the catalogue. The rule
    # exists because names repeat - measured 2026-08-21, `Rank` is declared under nine ids, of
    # which eight belong to statistic type 6 and no statement in this package touches one.
    param($Refs, [hashtable]$Names, [string[]]$Wanted)

    foreach ($want in @($Wanted)) {
        $token = $want.Trim()
        if (-not $token) { continue }

        foreach ($ref in @($Refs)) {
            if ($token -match '^\d+$') {
                if ([int]$token -eq $ref.Id) { return $true }
                continue
            }
            $key = '{0}|{1}' -f $ref.Layer, $ref.Id
            if ($Names -and $Names.ContainsKey($key) -and $Names[$key] -like "*$token*") { return $true }
        }
    }
    return $false
}

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
        # Any leading underscore, not only the four named above. A parameter name is a token a
        # statement declares and none of them starts with one, so the prefix is the convention
        # for "this block is about the sport rather than for the SQL". Naming the blocks one by
        # one leaves the next one to leak: _names was added on 2026-08-13 and printed as a
        # parameter, its whole object dumped into the resolution list, until this line existed.
        if ($property.Name.StartsWith('_')) { continue }
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

function Remove-CoverageRows {
    # The rows a reader is meant to work through, which is every row except the COVERAGE one.
    #
    # A COVERAGE row is the statement answering how much it audited, not something it found. It
    # carries a count and nothing else - every finding column in it is NULL - so on a tab it is
    # a row somebody has to read past, and in a count it is the reason a clean check reported 1
    # where it had found nothing. Taken off both from 2026-08-28, so the number on Overview and
    # the rows on the tab it links to are the same thing.
    #
    # Nothing is lost. eligible_count is its own Overview column, it is in _summary.csv, and it
    # is in RUNS/<Sport>.json. What it costs is that a check auditing nothing and a check finding
    # nothing now look alike on the tab - both empty - and are told apart by Eligible and by the
    # run's own `Audited nothing` line.
    #
    # A statement with no check_type column is returned untouched: a discovery or pattern
    # statement declares no coverage branch, so there is nothing here to subtract and guessing
    # that one of its rows is a coverage row would delete a result.
    param($Rows)

    $all = @($Rows | Where-Object { $null -ne $_ })
    if ($all.Count -eq 0) { return $all }
    if (-not ($all | Where-Object { $_.PSObject.Properties.Name -contains 'check_type' })) {
        return $all
    }
    return @($all | Where-Object { [string]$_.check_type -ne 'COVERAGE' })
}

function Get-SeededStatus {
    # The two verdicts the workbook can settle for itself, so a reviewer opens on the rows
    # that actually want reading.
    #
    # An informational check has nothing to act on by its nature. A check that came back with
    # no findings at all found nothing today - which is a reading of the data and not the
    # absence of one. It was `$Rows -eq 1` until 2026-08-28, when the COVERAGE row stopped
    # being counted: the check that reported one row and the check that reports none now are
    # the same check.
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
    if ($Signal -eq 'Informational') { return 'Monitor Only' }
    if ($Rows -eq 0 -and $null -ne $Eligible -and $Eligible -gt 0) { return 'Clean' }
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

function Set-JobCheckCategory {
    # The category a check is filed under belongs to its registry row, and a run must carry it
    # however the job was selected. -RunAll builds its jobs from those rows and already has it;
    # a run naming CheckIDs does not, and one selection path in particular loses it silently.
    #
    # A check instantiating a template is not in the statement catalogue under its own ID -
    # the catalogue holds GLOBAL-DQ-020, not Golf-DQ-004 - so Select-Checks misses, falls
    # through to the registry and picks the category up on the way. A sport that authored its
    # own statement is in the catalogue under exactly the ID the user typed, the first lookup
    # hits, and the registry is never consulted: Golf-DQ-085 reached the board with an empty
    # Priority and Category while Golf-DQ-084 beside it was filed correctly. The blank was
    # indistinguishable from a check nobody had categorised.
    #
    # Only fills what is empty, so a registry-built job keeps the row it was built from, and
    # a direct GLOBAL-DQ or discovery run - which has no registry row and no category anybody
    # authored - still reports blank rather than a guess.
    param($Jobs)

    $needsCategory = @(@($Jobs) | Where-Object {
            $_.CheckId -and (
                $_.PSObject.Properties.Name -notcontains 'Category' -or
                [string]::IsNullOrWhiteSpace([string]$_.Category)) })
    if ($needsCategory.Count -eq 0) { return @($Jobs) }

    $byId = @{}
    foreach ($row in @(Get-RegistryRow)) {
        if (-not $byId.ContainsKey([string]$row.CheckId)) { $byId[[string]$row.CheckId] = $row }
    }

    foreach ($job in $needsCategory) {
        $row = $(if ($byId.ContainsKey([string]$job.CheckId)) { $byId[[string]$job.CheckId] } else { $null })
        if (-not $row) { continue }
        $job | Add-Member -NotePropertyName Category -NotePropertyValue ([string]$row.Category) -Force
    }

    return @($Jobs)
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

function Confirm-RunnerSession {
    # A session, once, whoever asks first. Parameter discovery and the client boundary both
    # need one before the run proper does, and each used to open its own - which under
    # -Relogin meant deleting the saved state a second time, after the first had already
    # replaced it with a live login.
    if ($null -ne $script:Session) { return }
    if ($Relogin -and (Test-Path $StatePath)) { Remove-Item -LiteralPath $StatePath -Force }
    if (-not $Relogin) { $script:Session = Restore-SessionState }
    if ($null -eq $script:Session) { $script:Session = New-AuthenticatedSession }
}

function Resolve-ClientBoundary {
    <#
        The client's boundary as every statement needs it, derived from the form a person can
        keep by hand.

        Two sports want opposite defaults and the reason is arithmetic rather than taste. Golf's
        client takes 16 of 36 templates, so naming the 20 it does not take is the short list,
        and a template added later is one the client probably does take - the exclusion list has
        the right default and stays readable. Ice Hockey's client takes 25 of 112: every
        national-team competition and no club league at all. Naming what it does not take is 87
        ids, the sport gains templates most seasons, and under an exclusion list every new one
        arrives inside the boundary without anybody deciding it. One league the size of the KHL
        is 17669 events against the 9803 the client asked for, and nothing would fail.

        So a sport declares whichever list is the short one and the runner computes the other.
        IN_SCOPE_TEMPLATE_ID_LIST names what the client takes, and the complement is worked out
        against the sport's templates as they are now rather than as they were when somebody
        last counted. OUT_OF_SCOPE_TEMPLATE_ID_LIST names what it does not and is used as
        written. Declaring both is a contradiction and is refused rather than settled by
        precedence, because the two would disagree the day one of them was edited.

        An id that is not the sport's own is a typo and stops the run. It would otherwise widen
        the boundary silently: the complement is computed by exclusion, so an id belonging to no
        template of this sport removes nothing and the client quietly gains whatever the reader
        meant to name.
    #>
    param([hashtable]$Values)

    if (-not $Values.ContainsKey($InScopeParameter)) { return $null }

    if ($Values.ContainsKey($ClientScopeParameter)) {
        throw ("SPORTS/params.json declares both $InScopeParameter and $ClientScopeParameter. " +
            'They are two ways of saying the same boundary and would disagree the first time one was edited; declare the shorter list only.')
    }

    $wanted = @([string]$Values[$InScopeParameter] -split ',' |
        ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' })
    if ($wanted.Count -eq 0) {
        throw "SPORTS/params.json $InScopeParameter is not a comma-separated id list: '$($Values[$InScopeParameter])'"
    }
    if (-not $Values.ContainsKey('SPORT_ID')) {
        throw "$InScopeParameter needs SPORT_ID to compute its complement, and the sport has none resolved."
    }

    Confirm-RunnerSession
    $sportId = [int]$Values['SPORT_ID']

    # Built into a variable rather than formatted inside the call. -f binds to the whole
    # pipeline element, so writing it inline applied the format to the result of the query
    # instead of to the statement, and the server was sent {0} and {1} verbatim.
    $statement = "SELECT id AS template_id, CASE WHEN id IN ({0}) THEN 'in' ELSE 'out' END AS side " +
    "FROM tournament_template WHERE del = 'no' AND sportFK = {1} ORDER BY id;"
    $statement = $statement -f ($wanted -join ', '), $sportId
    $rows = Get-ResultRows -Content (Invoke-SqlWithRetry -Statement $statement).Content

    $held = @($rows | Where-Object { $_.side -eq 'in' } | ForEach-Object { [string]$_.template_id })
    $stray = @($wanted | Where-Object { $held -notcontains $_ })
    if ($stray.Count -gt 0) {
        throw ("$InScopeParameter names $($stray.Count) template(s) that are not active under sport ${sportId}: " +
            ($stray -join ', ') + '. An id the sport does not have removes nothing from the complement, so the boundary would silently be wider than written.')
    }

    # '0' rather than an empty string when the client takes every template there is: no template
    # has that id, so NOT IN (0) excludes nothing, and an empty list would be a syntax error in
    # all 264 places that read it.
    $complement = @($rows | Where-Object { $_.side -eq 'out' } | ForEach-Object { [string]$_.template_id })
    $value = $(if ($complement.Count -gt 0) { $complement -join ', ' } else { '0' })

    Write-Host ("  {0,-30} {1} of {2} template(s) in scope; {3} excluded  (derived from {4})" -f `
            $ClientScopeParameter, $held.Count, $rows.Count, $complement.Count, $InScopeParameter) -ForegroundColor DarkGray
    return $value
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

    # Sized up front and filled by index, never grown. `$array +=` allocates a new array and
    # copies the old one into it, so a loop that appends n times copies n-squared elements -
    # invisible on a result of forty rows and most of the call on a real one. Measured
    # 2026-08-30 on the sizes this actually sees: 13099 rows took 3.86 seconds appended against
    # 0.35 allocated, and 46380 - which is what Swimming-DQ-026 returns on every run - took
    # 63.31 against 1.66, a factor of 38. Soccer-DQ-080's 140629 is the largest result on record
    # and the curve is quadratic, so it was minutes. Sheets.ps1 carries the same fix in five
    # places, each marked the same way.
    $all = @($Rows)
    $tagged = [object[]]::new($all.Count)
    for ($i = 0; $i -lt $all.Count; $i++) {
        $ordered = [ordered]@{ check_id = $CheckId; check_name = $Name }
        foreach ($property in $all[$i].PSObject.Properties) { $ordered[$property.Name] = $property.Value }
        $tagged[$i] = [pscustomobject]$ordered
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

    # A test run still writes its results - a run you cannot read proves nothing - but it says
    # so in the folder name. Ten of them otherwise pile up beside the real ones and the only
    # thing separating them is whoever remembers which was which.
    $prefix = $(if ($TestRun) { 'TEST ' } else { '' })
    return Join-Path $OutputRoot ('{0}{1} {2}' -f $prefix, (Get-RunSport -Jobs $Jobs), $stamp)
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
            # -notcontains: this runs once per cell, and a board is tens of thousands
            # of them.
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

function Get-SqlFingerprint {
    # The first twelve hex of SHA256 over the statement as it was actually sent, parameters
    # substituted and narrowing applied.
    #
    # It exists because a moved count cannot otherwise be read. Biathlon-DQ-038 recorded 3
    # findings of 2358 on six consecutive runs, and between the last two the statement was
    # rewritten from an all-pairs self-join to a window and went from 141.8 seconds to 12.1.
    # Nothing in those six rows says so, so a reviewer cannot tell a number that held because
    # the data held from one that held because the check is the same check.
    #
    # Twelve characters, not sixty-four. It answers same-or-different and nothing else, and
    # sixty-four across 23126 rows is 1.2 MB of a 25.5 MB ledger to say it four times over.
    #
    # A narrowed run hashes differently from a wide one on purpose. -TemplateIds rewrites the
    # statement, and the population it audits is genuinely not the same population, so a count
    # from one is not comparable with a count from the other. That the fingerprint says so is
    # the point rather than a false alarm.
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Text))
        return ([System.BitConverter]::ToString($bytes) -replace '-', '').Substring(0, 12).ToLowerInvariant()
    }
    finally { $sha.Dispose() }
}

function Get-RepoCommit {
    # Which version of the package produced a run, as a short commit with a trailing + when
    # the working tree carried uncommitted changes - because a run made mid-edit is exactly
    # the case where a bare commit hash would be a lie. Empty where git cannot answer, which
    # is a fact about the machine rather than a failure of the run.
    if ($script:RepoCommit -ne $null) { return $script:RepoCommit }
    $script:RepoCommit = ''
    try {
        $head = (& git -C $RepoRoot rev-parse --short=12 HEAD 2>$null)
        if ($LASTEXITCODE -eq 0 -and $head) {
            $dirty = (& git -C $RepoRoot status --porcelain 2>$null)
            $script:RepoCommit = ([string]$head).Trim() + $(if ($dirty) { '+' } else { '' })
        }
    }
    catch { $script:RepoCommit = '' }
    return $script:RepoCommit
}
$script:RepoCommit = $null
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

    # The audited object, on the same terms as the category: authored against the CheckID in
    # POWERBI_REGISTRY.md and not derivable from the statement, so a run outside the registry
    # leaves it empty rather than reading a layer out of the SQL.
    $object = ''
    if ($Job.PSObject.Properties.Name -contains 'Object') {
        $object = [string]$Job.Object
    }

    # The stored values the statement reads, unlike the two above derived from the SQL itself
    # rather than authored against the CheckID - so an ad-hoc statement and a direct template
    # run carry it too, where category and object are blank because nobody filed them.
    $dataTypes = ''
    if ($Job.PSObject.Properties.Name -contains 'DataTypes') {
        $dataTypes = [string]$Job.DataTypes
    }

    # A pattern summary is the one statement outside the registry whose family is knowable
    # without anybody authoring it: PATTERNS.sql holds nothing else. Taken from the file rather
    # than from a list of CheckIDs, for the reason -WithPatterns selects them that way - a
    # pattern statement added later is classified on its own without a list to keep in step.
    if (-not $category -and $Job.PSObject.Properties.Name -contains 'File' -and
        [string]$Job.File -eq 'PATTERNS.sql') {
        $category = 'PATTERNS'
    }

    # A discovery statement that reports a defect family in spite of being discovery. Named
    # one by one where $RideAlongDiscovery is declared, and applied last so a registry row
    # naming the same CheckID still wins.
    if (-not $category -and $Job.CheckId -and $RideAlongDiscovery.ContainsKey([string]$Job.CheckId)) {
        $category = $RideAlongDiscovery[[string]$Job.CheckId]
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
        -Findings $Findings -Eligible $Eligible -Previous $previous -Ran $ran -Signal $signal

    $change = $null
    if ($null -ne $Findings -and $null -ne $previous -and $null -ne $previous.Findings) {
        $change = [int]$Findings - [int]$previous.Findings
    }

    # This run last, so the series reads forward and ends on today. One cell answering "is this
    # moving, and over what span" without opening the ledger or the console. Each point is
    # dated, because a check that has read zero four times says one thing across four weeks
    # and another across one afternoon of re-runs, and the numbers alone cannot tell them apart.
    $points = @()
    if ($script:RecentFindings.ContainsKey($runKey)) {
        foreach ($point in @($script:RecentFindings[$runKey])) {
            $points += [pscustomobject]@{ Value = [string]$point.Value; Stamp = $point.Stamp }
        }
    }
    $points += [pscustomobject]@{
        Stamp = $script:RunStartedUtc.ToLocalTime()
        Value = $(
            if (-not $ran) { 'ERR' }
            elseif ($null -eq $Findings) { '-' }
            else { [string][int]$Findings })
    }
    $series = New-TrendSeries -Points $points
    $trend = $(if ($points.Count -gt 1) { $series.Text } else { '' })
    $trendRuns = $(if ($points.Count -gt 1) { $series.Runs } else { @() })

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
        Object      = $object
        DataTypes   = $dataTypes
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
        Trend        = $trend
        # Appended after Trend rather than beside PrevRunId, so a reader whose script names
        # _summary.csv columns by position keeps every column it already had.
        SqlHash      = Get-SqlFingerprint -Text ([string]$Job.Sql)
        PrevSqlHash  = $(if ($previous) { [string]$previous.SqlHash } else { '' })
        TrendRuns    = $trendRuns
        # The series as points rather than as the string built from them. The live document
        # subtracts the findings its reviewers have already settled, and a rendered trend cannot
        # be re-levelled by editing text: each point is coloured against the one before it, and
        # a point reading ERR is not a measurement to shift. Carried so the merge can rebuild
        # the series from the same points at the level the board actually reports.
        TrendPoints  = $points
    }
}

function Save-RunSummaryCsv {
    # TrendRuns and TrendPoints are left out. One is character offsets into the Trend string and
    # the other the points it was built from - both structure for the live document, not facts
    # about the run - and in a flat file each arrives as the word System.Object[] in a column
    # nobody can read. Trend itself stays, because the rendered series is the readable form.
    param($Summary, [string]$Path)
    $Summary | Select-Object -Property * -ExcludeProperty TrendRuns, TrendPoints |
        Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8
}

$script:RunLedgerCache = @{}

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

    # Parsed once per run rather than once per caller. One run reads the sport's history three
    # times over - the previous entry per check, the trend series, and again to append - and the
    # largest ledger here is 2.4 MB, about 0.3 seconds of ConvertFrom-Json each time. The key
    # carries the file's write time and length, so the copy is dropped the moment the file
    # changes underneath it: Save-RunLedger rewrites it, and Test-Tools.ps1 rewrites fixtures
    # between two reads in the same process.
    $stamp = Get-Item -LiteralPath $path
    $key = '{0}|{1}|{2}' -f $path, $stamp.LastWriteTimeUtc.Ticks, $stamp.Length
    if ($script:RunLedgerCache.ContainsKey($key)) { return $script:RunLedgerCache[$key] }

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
    $script:RunLedgerCache[$key] = $ledger
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
                    SqlHash    = [string]$check.sqlHash
                }
            }
        }
    }
    return $previous
}

function Get-RunStamp {
    # When a recorded run started, in local time, or $null if the entry cannot say.
    #
    # startedUtc is the authority because it is unambiguous and machine-written. The runId is
    # the fallback and not the other way round: it is the output folder's name, a person can
    # rename a folder, and a run printed to the screen never had one. Both are parsed under
    # the invariant culture - dd.MM.yyyy is the folder convention here and would be read as
    # MM.dd.yyyy by a machine set to en-US.
    param($Run)

    $utc = [string]$Run.startedUtc
    if (-not [string]::IsNullOrWhiteSpace($utc)) {
        $parsed = [datetime]::MinValue
        $styles = [Globalization.DateTimeStyles]::AssumeUniversal -bor `
            [Globalization.DateTimeStyles]::AdjustToUniversal
        if ([datetime]::TryParse($utc, [Globalization.CultureInfo]::InvariantCulture, $styles, [ref]$parsed)) {
            return [datetime]::SpecifyKind($parsed, [DateTimeKind]::Utc).ToLocalTime()
        }
    }

    if ([string]$Run.runId -match '(\d{2}\.\d{2}\.\d{4} \d{2}-\d{2}-\d{2})$') {
        $parsed = [datetime]::MinValue
        if ([datetime]::TryParseExact($matches[1], 'dd.MM.yyyy HH-mm-ss',
                [Globalization.CultureInfo]::InvariantCulture,
                [Globalization.DateTimeStyles]::None, [ref]$parsed)) {
            return $parsed
        }
    }
    return $null
}

function Import-RecentFindings {
    # The last few recorded findings for each statement about to run, oldest first, each
    # carrying the moment its run started so the series can date itself.
    #
    # Unlike Import-PreviousRunEntries this keeps the failed runs. A comparison against an
    # error says nothing and is skipped there; a series with a gap in it is a different thing,
    # and hiding the gap would draw a smooth line through a week nobody measured.
    param($Jobs, [int]$Count = $TrendRunCount)

    $recent = @{}
    $sports = @($Jobs | ForEach-Object { Get-SportFromCheckId -CheckId $_.CheckId } | Select-Object -Unique)

    foreach ($sport in $sports) {
        if ($sport -in @('AD-HOC', 'GLOBAL', '')) { continue }
        $ledger = Read-RunLedger -Sport $sport
        if ($null -eq $ledger) { continue }

        foreach ($run in @($ledger.runs)) {
            $stamp = Get-RunStamp -Run $run
            foreach ($check in @($run.checks)) {
                $key = [string]$check.runKey
                if (-not $recent.ContainsKey($key)) { $recent[$key] = @() }

                $status = [string]$check.status
                $recent[$key] += [pscustomobject]@{
                    Stamp = $stamp
                    Value = $(if ($status -like 'ERROR*' -or $status -like 'SKIPPED*' -or $null -eq $check.findings) {
                            'ERR'
                        }
                        else { [string][int]$check.findings })
                }
            }
        }
    }

    # Trimmed to the tail here rather than while collecting, because the ledger is walked
    # oldest first and the interesting end is the other one.
    foreach ($key in @($recent.Keys)) {
        $recent[$key] = @(@($recent[$key]) | Select-Object -Last ($Count - 1))
    }
    return $recent
}

function Get-TrendStampFormat {
    # Whether this run's Trends column dates its points to the day or to the minute.
    #
    # Decided once over every point any row will show, this run's own included, rather than
    # per row: two rows formatted differently in one column read as two different measures,
    # and the reader has no way to know the difference is only in how crowded one check's
    # history happens to be.
    param($Recent, [datetime]$Current)

    $seen = @{}
    if ($null -ne $Current) { $seen[$Current.ToString('yyyy-MM-dd')] = 1 }

    foreach ($key in @($Recent.Keys)) {
        foreach ($point in @($Recent[$key])) {
            if ($null -eq $point.Stamp) { continue }
            $day = ([datetime]$point.Stamp).ToString('yyyy-MM-dd')
            # Any repeat at all settles it: two points would otherwise carry the same label
            # while standing for different runs.
            if ($seen.ContainsKey($day)) { return $TrendStampLong }
            $seen[$day] = 1
        }
    }
    return $TrendStampShort
}

function Format-TrendPoint {
    # One point of the series: the finding count, then when it was measured. The count leads
    # because the shape of the series is what the column is for and the eye should get it
    # first; an undatable point degrades to the bare number rather than to an empty bracket.
    param([string]$Value, $Stamp)

    if ($null -eq $Stamp) { return $Value }
    return '{0} ({1})' -f $Value, ([datetime]$Stamp).ToString($script:TrendStampFormat,
        [Globalization.CultureInfo]::InvariantCulture)
}

function New-TrendSeries {
    <#
        The trend as one string plus where the numbers sit inside it.

        A count is coloured against the count before it - down is the check improving, up is
        it getting worse, level is neither - so the column answers "which way is this moving"
        without the reader subtracting anything. Only the number is coloured; the timestamp
        beside it is context and stays as it is.

        A run that failed contributes ERR and is not a measurement, so it takes the level
        colour and does not become the thing the next point is compared against: a check that
        read 5, errored, then read 3 has gone down by two, and saying otherwise would make an
        outage look like progress.

        Returns the offsets rather than the formatting, because where a number starts is a fact
        about the string and which green to use is not.
    #>
    param($Points)

    $text = ''
    $runs = @()
    $previous = $null

    foreach ($point in @($Points)) {
        if ($text.Length -gt 0) { $text += $TrendSeparator }

        $value = [string]$point.Value
        $start = $text.Length
        $text += (Format-TrendPoint -Value $value -Stamp $point.Stamp)

        $current = 0
        $numeric = [int]::TryParse($value, [ref]$current)
        $direction = 'level'
        if ($numeric -and $null -ne $previous) {
            if ($current -lt $previous) { $direction = 'down' }
            elseif ($current -gt $previous) { $direction = 'up' }
        }
        if ($numeric) { $previous = $current }

        $runs += [pscustomobject]@{
            Start     = $start
            Length    = $value.Length
            Direction = $direction
        }
    }

    return [pscustomobject]@{ Text = $text; Runs = $runs }
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
        [bool]$Ran,
        [string]$Signal = ''
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
    #
    # Unless a person has already been: a sentinel is that question answered, in the sport file
    # and in the signal, and a board that keeps reporting Audited nothing beside it is arguing
    # with a classification the same document carries. The word is different from the other
    # three classified zeros because this one is not settled forever - it says the check is
    # watching an empty population, and the day rows arrive the verdict returns to whatever the
    # numbers say.
    if ($null -ne $Eligible -and [int]$Eligible -eq 0) {
        if ($Signal -eq 'Sentinel') { return 'Sentinel' }
        return 'Audited nothing'
    }

    $now = [int]$Findings

    # Read before any comparison, because zero findings is a statement about the data and not
    # about the population it came out of. A check that should reach zero and did is resolved
    # however much the sport grew; a check whose findings are population-wide and returned
    # none is almost certainly broken, and that is worth saying loudly rather than filing as
    # the best result on the board.
    if ($Expected -eq 'Zero' -and $now -eq 0) {
        # Resolved claims work landed, so it is only said where work landed. A check that was
        # clean last week and is clean this week has resolved nothing, and reporting it as a
        # weekly success buries the rows that did change among the ones that never do.
        if ($null -ne $Previous -and $null -ne $Previous.Findings -and [int]$Previous.Findings -gt 0) {
            return 'Resolved'
        }
        return 'Clean'
    }
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
        # Recorded per run rather than looked up later, because it is a property of the
        # statement as it was sent: a check whose scope is widened next month read something
        # different today, and the ledger is the only place that can still say what.
        dataTypes  = [string]$Entry.DataTypes
        signal     = [string]$Entry.Signal
        expected   = [string]$Entry.Expected
        verdict    = [string]$Entry.Verdict
        rows       = $Entry.Rows
        findings   = $Entry.Findings
        eligible   = $Entry.Eligible
        seconds    = $Entry.Seconds
        status     = [string]$Entry.Status
        # The statement this row is about, so the next run can tell a count that held because
        # the data held from one that held because nothing about the check moved.
        sqlHash    = [string]$Entry.SqlHash
    }
    if ($null -ne $Entry.ExpectedResidual) { $ordered['residual'] = $Entry.ExpectedResidual }
    return [pscustomobject]$ordered
}

# The Overview's Status and Check By as the document held them, keyed by CheckID, filled while
# the live document is read and emptied by every run that does not open one. Two columns nothing
# else copies: Status is on the check tabs but as the run's own state rather than the reviewer's,
# and Check By is nowhere else at all.
$script:SheetReviewSnapshot = [ordered]@{}

function Test-RunWasComplete {
    # A run is complete when it was asked for the sport's whole approved catalogue and nothing
    # capped it. Two places need the answer - the board merge, which may only mark checks a
    # complete run did not produce, and the ledger, which may only snapshot the whole board's
    # review from one. They had the expression written out twice until 2026-09-01; one function
    # so a change to what "complete" means cannot reach one caller and miss the other.
    return ($RunAll -and $MaxChecks -le 0)
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
    param($Summary, [string]$Output, [string]$SheetId)

    # -TestRun leaves no trace at all. -NoLedger is narrower and exists for one caller: the
    # nightly pass, which updates a board every night and would otherwise add about 29,000
    # lines a night to sixteen files that are in git. It writes the board, because a reviewer
    # who follows the notification should meet the red chip rather than a green one it has just
    # contradicted; it does not write here, because the ledger is the record of full runs and a
    # subset measured overnight is not one.
    #
    # What that costs is worth naming rather than discovering. The next run still compares
    # against the last recorded run, so a night's numbers are not what the morning's board is
    # read against - which is correct for `Prev findings` and slightly weakens one rule: the
    # guard that closes `Reopened` only after two clean runs counts recorded runs, so it counts
    # full boards rather than nights.
    if ($TestRun -or $NoLedger) { return @() }

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
            commit     = (Get-RepoCommit)
            checks     = @($group.Group | ForEach-Object { New-LedgerCheckEntry -Entry $_ })
        }

        # The reviewers' own two columns as the document held them when this run read it, keyed
        # by CheckID. Recorded only when the run actually opened the document - a run with no
        # sheet has nothing to snapshot - and only for the sport whose checks these are.
        # Whether this run reached the live document, and what it cost. Written for the sport
        # whose document it was, and only when a document was opened at all - a run made with
        # -NoSheet or against a mixed selection has nothing to say here and says nothing.
        if ($script:SheetOutcome -and $sport -notin @('MIXED', 'AD-HOC', 'GLOBAL', '')) {
            $run | Add-Member -NotePropertyName sheet -NotePropertyValue $script:SheetOutcome
        }

        # A complete run snapshots the whole board, because there the snapshot is true. A
        # partial one records only the checks it ran, and this is the difference between a
        # one-check run costing 512 lines and costing 52: measured 2026-09-01 on Soccer, the
        # check itself was 21 lines, the sheet block 23, the scaffolding 12 - and `review` 468,
        # because it held the reviewer's word on all 116 Soccer checks rather than the one that
        # ran. At the 50-80 clicks a day the sheet run queue is being built for, the difference
        # is 41,000 lines a day against 4,200, in a file that is in git.
        #
        # Nothing loses a status by this. Get-NightlyLedgerState walks the ledger forward and
        # looks up `review.<checkId>` for the check in hand, falling back to the last status it
        # knew when a run's block does not carry that check - it was written that way for
        # narrowed re-runs, which already wrote no block at all.
        if ($script:SheetReviewSnapshot -and $script:SheetReviewSnapshot.Count -gt 0) {
            $wasComplete = Test-RunWasComplete
            $inThisRun = @{}
            foreach ($entry in @($group.Group)) { $inThisRun[[string]$entry.CheckId] = $true }

            $mine = [ordered]@{}
            foreach ($checkId in @($script:SheetReviewSnapshot.Keys)) {
                if ((Get-SportFromCheckId -CheckId $checkId) -ne $sport) { continue }
                if (-not $wasComplete -and -not $inThisRun.ContainsKey([string]$checkId)) { continue }
                $mine[$checkId] = $script:SheetReviewSnapshot[$checkId]
            }
            if ($mine.Count -gt 0) {
                $run | Add-Member -NotePropertyName review -NotePropertyValue $mine
            }
        }

        $ledger.runs = @($ledger.runs) + $run
        $ledger.ledgerVersion = $LedgerVersion
        $ledger.sport = $sport

        # Recorded only after the document was actually written to, so a mistyped id never
        # becomes the sport's remembered one. From here a periodic run needs no -SheetId.
        if (-not [string]::IsNullOrWhiteSpace($SheetId)) {
            $ledger | Add-Member -NotePropertyName sheetId -NotePropertyValue $SheetId -Force
        }

        $path = Get-LedgerPath -Sport $sport
        $dir = Split-Path -Parent $path
        if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

        # No byte-order mark, for the same reason _decisions.json has none: ConvertFrom-Json
        # reads one as part of the first property name, so the next run could not read back
        # the file this one wrote.
        # With a trailing newline, because unlike everything else a run writes this file is
        # inside the working copy, and Test-Package.ps1 holds every tracked text file to that.
        # ConvertTo-Json does not end with one.
        try {
            [IO.File]::WriteAllText($path, (($ledger | ConvertTo-Json -Depth 6) + "`r`n"),
                (New-Object Text.UTF8Encoding $false))
            $written += $path
        }
        catch {
            Write-Host ("  RUNS/{0}.json could not be written: {1}" -f $sport, $_.Exception.Message) -ForegroundColor Yellow
        }
    }

    return $written
}

function Get-CheckHistory {
    # Every recorded run of the checks a pattern matches, oldest first, as rows a caller can
    # print or sort. Reads the ledger and nothing else: no credentials, no network, and no
    # opinion about what the numbers mean beyond the verdict each run already recorded.
    param([string]$Pattern, [string]$Sport)

    $ledger = Read-RunLedger -Sport $Sport
    if ($null -eq $ledger) { return @() }

    $rows = @()
    foreach ($run in @($ledger.runs)) {
        foreach ($check in @($run.checks)) {
            if ([string]$check.runKey -notlike $Pattern -and [string]$check.checkId -notlike $Pattern) { continue }

            # The proportion, because a raw count is only comparable while the population is,
            # and over ten runs it rarely stays still.
            $rate = ''
            if ($null -ne $check.findings -and $null -ne $check.eligible -and [int]$check.eligible -gt 0) {
                $rate = '{0:N2}%' -f ([double][int]$check.findings / [int]$check.eligible * 100)
            }

            $rows += [pscustomobject]@{
                CheckId  = [string]$check.checkId
                Run      = [string]$run.runId
                Started  = [string]$run.startedUtc
                Findings = $check.findings
                Eligible = $check.eligible
                Rate     = $rate
                Verdict  = [string]$check.verdict
                Status   = [string]$check.status
            }
        }
    }
    return $rows
}

function Get-SheetHistoryRows {
    <#
        The sport's recorded runs as the History tab holds them: one row per check per run,
        oldest run first within each check, newest runs kept and oldest dropped.

        This run is added here rather than read back, because Save-RunSheet deliberately goes
        before Save-RunLedger - the sheet id is only remembered once the document has taken a
        write - so at the moment the tab is planned the ledger does not yet know about today.
        Built through New-LedgerCheckEntry and filtered the way Save-RunLedger filters, so the
        row the tab shows for this run is the row the ledger is about to file, and the two
        cannot come to different conclusions about the same statement.

        The window is applied to runs, not to rows. A check that ran in three of the last forty
        runs has three rows and a check that ran in all forty has forty, and both series end on
        the same run - which is what makes two rows on this tab comparable at all.
    #>
    param($Summary, [string]$Sport, [string]$RunId, [int]$Keep = $SheetHistoryRuns)

    if ([string]::IsNullOrWhiteSpace($Sport) -or $Sport -in @('MIXED', 'AD-HOC', 'GLOBAL')) { return @() }

    $ledger = Read-RunLedger -Sport $Sport
    $runs = @()
    if ($null -ne $ledger) { $runs = @($ledger.runs) }

    # The same two conditions Save-RunLedger records under: a statement with no CheckID has no
    # series to belong to, and a discovery statement is a census rather than a finding.
    $mine = @($Summary | Where-Object {
            -not [string]::IsNullOrWhiteSpace([string]$_.CheckId) -and
            ([string]$_.CheckId) -notlike $DiscoveryCheckIdPattern -and
            (Get-SportFromCheckId -CheckId $_.CheckId) -eq $Sport
        })
    if ($mine.Count -gt 0) {
        $runs += [pscustomobject]@{
            runId      = $RunId
            startedUtc = $script:RunStartedUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
            checks     = @($mine | ForEach-Object { New-LedgerCheckEntry -Entry $_ })
        }
    }

    if ($runs.Count -eq 0) { return @() }
    if ($Keep -gt 0 -and $runs.Count -gt $Keep) { $runs = @($runs | Select-Object -Last $Keep) }

    # Walked oldest first so a check's series is built in the order it happened, and Change can
    # be read off the entry before it without looking anything up.
    #
    # Into a list rather than onto an array. $rows += copies the whole array each time, which is
    # a second and a half of nothing for the sixteen hundred rows the largest sport holds today
    # and nine times that for the forty-eight hundred a year of weekly runs would reach. The
    # tab is meant to cost one write, not a growing share of every run.
    $rows = New-Object 'Collections.Generic.List[object]'
    $previous = @{}
    $seen = 0
    foreach ($run in $runs) {
        $stamp = Get-RunStamp -Run $run
        $when = $(if ($null -eq $stamp) { '' } else {
                ([datetime]$stamp).ToString('yyyy-MM-dd HH:mm',
                    [Globalization.CultureInfo]::InvariantCulture)
            })
        foreach ($check in @($run.checks)) {
            $key = [string]$check.runKey
            if ([string]::IsNullOrWhiteSpace($key)) { $key = [string]$check.checkId }

            $status = [string]$check.status
            $ran = -not ($status -like 'ERROR*' -or $status -like 'SKIPPED*')

            # The proportion, because a raw count is only comparable while the population is,
            # and over forty runs it rarely stays still. Blank rather than zero where there is
            # no population to be a proportion of.
            #
            # Formatted under the invariant culture, unlike the console's own history: this
            # string lands in a document read by people on differently configured machines, and
            # a run made on one of them must not write 12,63% into a column the run before
            # filled with 12.63%.
            $rate = ''
            if ($ran -and $null -ne $check.findings -and $null -ne $check.eligible -and
                [int]$check.eligible -gt 0) {
                $rate = ([double][int]$check.findings / [int]$check.eligible * 100).ToString('N2',
                    [Globalization.CultureInfo]::InvariantCulture) + '%'
            }

            # Against the run before it in this window, not against the run before it in the
            # ledger. A row whose predecessor fell off the end has nothing on the tab to be a
            # change from, and a number the reader cannot see is not a comparison.
            $change = ''
            if ($ran -and $null -ne $check.findings -and $previous.ContainsKey($key) -and
                $null -ne $previous[$key]) {
                $change = [int]$check.findings - [int]$previous[$key]
            }
            $previous[$key] = $(if ($ran) { $check.findings } else { $null })

            # Sorted by CheckID and then by when the run happened, which needs the position to
            # survive the sort - two runs can share a minute and a string sort on the stamp
            # would then put them in either order.
            $seen++
            $rows.Add([pscustomobject]@{
                'CheckID'    = [string]$check.checkId
                'Check Name' = [string]$check.name
                'Parameters' = [string]$check.parameters
                'Run'        = [string]$run.runId
                'Run date'   = $when
                'Findings'   = $(if ($ran) { $check.findings } else { '' })
                'Eligible'   = $(if ($ran) { $check.eligible } else { '' })
                'Rate'       = $rate
                'Change'     = $change
                'Verdict'    = [string]$check.verdict
                'Status'     = $status
                # One key rather than three sort expressions. The run's position is padded so it
                # sorts as a number would - a check that ran forty times would otherwise put its
                # tenth run before its second - and it is the position rather than the stamp,
                # because two runs can share a minute and a sort on the stamp would then put
                # them in either order.
                # Joined by a unit separator, so a CheckID that is the start of another one
                # cannot sort into the middle of it.
                SortKey      = ([string]$check.checkId + "`u{001F}" +
                    [string]$check.parameters + "`u{001F}" + $seen.ToString('D6'))
            })
        }
    }

    return @($rows | Sort-Object -Property SortKey)
}

function Show-CheckHistory {
    param([string]$Pattern, [string]$Sport)

    $rows = @(Get-CheckHistory -Pattern $Pattern -Sport $Sport)
    if ($rows.Count -eq 0) {
        Write-Host ("Nothing recorded for '{0}' in RUNS\{1}.json." -f $Pattern, $Sport) -ForegroundColor Yellow
        Write-Host '  A check appears here once it has been run without -TestRun.' -ForegroundColor DarkGray
        return
    }

    $checks = @($rows | ForEach-Object { $_.CheckId } | Select-Object -Unique | Sort-Object)
    $runs = @($rows | ForEach-Object { $_.Run } | Select-Object -Unique)

    if ($checks.Count -eq 1) {
        # One check: the run is the interesting axis, so it gets a row each and every column
        # the ledger holds.
        Write-Host ''
        Write-Host $checks[0] -ForegroundColor Cyan
        $rows | Format-Table Run, Findings, Eligible, Rate, Verdict, Status -AutoSize
    }
    else {
        # A sport is a hundred checks, and a hundred one-row tables is not a table. Pivoted
        # instead: the check is the row, the run is the column, and the cell is the finding
        # count - which is the shape the question "what moved" is actually asked in.
        #
        # Columns are numbered rather than dated because a run id is thirty characters and
        # twelve of them across is not a console width. The legend below carries the dates.
        $shown = @($runs | Select-Object -Last $HistoryRunColumns)
        $label = @{}
        for ($i = 0; $i -lt $shown.Count; $i++) { $label[$shown[$i]] = 'R{0}' -f ($i + 1) }

        $table = @()
        foreach ($check in $checks) {
            $line = [ordered]@{ CheckId = $check }
            $series = @()
            foreach ($run in $shown) {
                $hit = @($rows | Where-Object { $_.CheckId -eq $check -and $_.Run -eq $run })[0]
                $cell = $(if ($hit) { $(if ($hit.Status -like 'OK*') { $hit.Findings } else { 'ERR' }) } else { '' })
                $line[$label[$run]] = $cell
                if ($hit -and $hit.Status -like 'OK*' -and $null -ne $hit.Findings) { $series += [int]$hit.Findings }
            }
            # First against last, which is the whole point of looking at more than two runs.
            $line['Net'] = $(if ($series.Count -ge 2) { $series[-1] - $series[0] } else { '' })
            $table += [pscustomobject]$line
        }
        $table | Format-Table -AutoSize

        Write-Host 'Columns, oldest first:' -ForegroundColor DarkGray
        foreach ($run in $shown) { Write-Host ("  {0,-4} {1}" -f $label[$run], $run) -ForegroundColor DarkGray }
        if ($runs.Count -gt $shown.Count) {
            Write-Host ("  {0} earlier run(s) not shown. Ask for one check to see all of them." -f `
                ($runs.Count - $shown.Count)) -ForegroundColor Yellow
        }
    }

    Write-Host ("{0} check(s) over {1} recorded run(s)." -f $checks.Count, $runs.Count) -ForegroundColor DarkGray
    Write-Host '  A run made with -TestRun is deliberately absent: it was asked to leave no trace.' -ForegroundColor DarkGray
}

function Format-RunDuration {
    # Seconds as something readable at the scale it actually is. A run reports 47.3s, 4m 12s and
    # 1h 03m from the same function, because a board that takes half an hour and one that takes
    # half a minute are both normal and "1893.4s" makes neither of them legible.
    param([double]$Seconds)

    if ($Seconds -lt 90) { return ('{0:n1}s' -f $Seconds) }
    $span = [timespan]::FromSeconds($Seconds)
    if ($span.TotalHours -ge 1) { return ('{0}h {1:00}m' -f [int]$span.TotalHours, $span.Minutes) }
    return ('{0}m {1:00}s' -f [int]$span.TotalMinutes, $span.Seconds)
}

# What the live document update cost on this run, seconds. Zero when no document was opened.
$script:SheetSeconds = 0.0

# How the live document update ended, or $null when no document was opened at all.
#
# Recorded because the question "did that run reach the board" had no answer anywhere. On
# 27.08 a run was found to have failed and two others could not be told apart from it: the
# console said so at the time and the console was gone, the board carries no mark of the run
# that wrote it, and the ledger recorded the run as though the update were part of it. Reading
# the board instead is what led to the wrong answer - Last run holds the run BEFORE this one,
# so a board naming yesterday is exactly what a successful run today produces.
$script:SheetOutcome = $null
$script:SheetRegistryCache = $null

function Get-SheetRegistry {
    # TOOLS/sheet-registry.json owns which document holds which sport's board. Read once and
    # kept, because a batch asks for it at the end of every run and the file does not move
    # underneath one.
    #
    # A missing or unreadable file is not fatal. The mapping also survives in each sport's
    # ledger, where it lived until 2026-09-01, so a run can still find its document and say
    # that it had to; a run that cannot reach its board is a worse outcome than a run that
    # reaches it by the old route and mentions it.
    if ($null -ne $script:SheetRegistryCache) { return $script:SheetRegistryCache }

    $path = Join-Path $PSScriptRoot 'sheet-registry.json'
    $table = @{}
    if (Test-Path -LiteralPath $path) {
        try {
            $parsed = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($parsed -and $parsed.PSObject.Properties.Name -contains 'sports') {
                foreach ($property in $parsed.sports.PSObject.Properties) {
                    $table[$property.Name] = $property.Value
                }
            }
        }
        catch {
            Write-Host ('  {0} could not be read, so each sport''s document is taken from its ledger instead: {1}' -f `
                    $path, $_.Exception.Message) -ForegroundColor Yellow
        }
    }

    $script:SheetRegistryCache = $table
    return $table
}

function Get-SportSheetId {
    <#
        The document id for one sport, from the file that owns the mapping.

        The order is deliberate. An explicit -SheetId wins, because a person naming a document
        on the command line means it. Then TOOLS/sheet-registry.json. Then, only for a sport
        with no row there, the sheetId the sport's ledger remembers - and that route says so
        out loud, because it is the one this file was written to replace.

        Where both are present and disagree, the registry wins and the disagreement is
        reported rather than resolved silently: one of the two documents is the board people
        are reading, and a run that quietly wrote to the other would be very hard to notice.
    #>
    param([string]$Sport, [string]$Explicit)

    if (-not [string]::IsNullOrWhiteSpace($Explicit)) { return $Explicit }
    if ([string]::IsNullOrWhiteSpace($Sport)) { return '' }

    $registry = Get-SheetRegistry
    $registered = ''
    if ($registry.ContainsKey($Sport)) {
        $entry = $registry[$Sport]
        if ($entry -and $entry.PSObject.Properties.Name -contains 'spreadsheetId') {
            $registered = [string]$entry.spreadsheetId
        }
    }

    $remembered = ''
    $ledger = Read-RunLedger -Sport $Sport
    if ($ledger -and $ledger.PSObject.Properties.Name -contains 'sheetId') {
        $remembered = [string]$ledger.sheetId
    }

    if (-not [string]::IsNullOrWhiteSpace($registered)) {
        if (-not [string]::IsNullOrWhiteSpace($remembered) -and $remembered -ne $registered) {
            Write-Host ('  {0} names document {1} and the ledger remembers {2}; the registry is the owner, so that is the one being written' -f `
                    $Sport, $registered, $remembered) -ForegroundColor Yellow
        }
        return $registered
    }

    if (-not [string]::IsNullOrWhiteSpace($remembered)) {
        Write-Host ('  {0} has no row in TOOLS/sheet-registry.json, so its document was taken from the ledger. Add the row.' -f $Sport) `
            -ForegroundColor Yellow
        return $remembered
    }

    return ''
}

function Get-RunRequestSports {
    # The sports whose document carries the Run requests tab. TOOLS/Watch-SheetRequests.ps1
    # polls these and nothing else, so a board that has not been set up costs it no calls.
    $registry = Get-SheetRegistry
    $names = @()
    foreach ($name in @($registry.Keys)) {
        $entry = $registry[$name]
        if ($entry -and $entry.PSObject.Properties.Name -contains 'runRequests' -and $entry.runRequests) {
            $names += $name
        }
    }
    return @($names | Sort-Object)
}

function Save-RunSheet {
    <#
        Bring the sport's live document up to date with this run.

        Which document belongs to the sport is TOOLS/sheet-registry.json's to say, so a
        periodic run needs nothing but -RunAll; -SheetId overrides it and the sport's ledger is
        the fallback for a sport with no row yet. A run that mixes sports updates nothing: the
        document is per sport, and there is no honest way to guess which of two sports a mixed
        run belongs in.

        A failure here is reported and does not end the run. By the time this is reached the
        statements have all executed and the workbook is on disk, so an expired token or a
        revoked share must not throw that away - the sheet can be brought up to date by running
        again, and the results cannot.
    #>
    param($Summary, $Collected, [string]$Sport, [string]$OutputFolder)

    if ($TestRun -or $NoSheet) { return $null }
    if ($Sport -in @('MIXED', 'AD-HOC', 'GLOBAL', '')) { return $null }

    $id = Get-SportSheetId -Sport $Sport -Explicit $SheetId
    if ([string]::IsNullOrWhiteSpace($id)) { return $null }

    # Before the try, so a failure inside it can still say how long it had been going.
    $sheetClock = $null
    try {
        Write-Host 'Updating the live document.' -ForegroundColor DarkGray
        Reset-SheetsTimings
        $sheetClock = Get-Date

        Set-SheetsStage 'reading the document'
        $state = Read-SheetState -SpreadsheetId $id

        # What the reviewers had on the board when this run read it, against the CheckID each
        # value belongs to. Written into the run ledger below, which is in git and is ordered by
        # nothing but the run: a sort applied to the document cannot reach it, and a value found
        # beside the wrong check can be traced back to the last run that saw it beside the right
        # one. Asked for on 2026-08-27, after ten Comment mirrors were found beside the wrong
        # check and Check By turned out to have no second copy anywhere.
        $script:SheetReviewSnapshot = [ordered]@{}
        foreach ($checkId in @($state.OverviewRowOf.Keys | Sort-Object)) {
            $wasStatus = $(if ($state.StatusOf -and $state.StatusOf.ContainsKey($checkId)) {
                    [string]$state.StatusOf[$checkId]
                } else { '' })
            $wasBy = $(if ($state.CheckByOf -and $state.CheckByOf.ContainsKey($checkId)) {
                    [string]$state.CheckByOf[$checkId]
                } else { '' })
            if ([string]::IsNullOrWhiteSpace($wasStatus) -and [string]::IsNullOrWhiteSpace($wasBy)) { continue }
            $script:SheetReviewSnapshot[$checkId] = [ordered]@{
                status  = $wasStatus
                checkBy = $wasBy
            }
        }

        $title = $(if ($SheetTitle) { $SheetTitle } else { "DQ $Sport Enetpulse" })
        if (Set-SheetTitleIfUnnamed -SpreadsheetId $id -CurrentTitle $state.Title -Title $title) {
            Write-Host "  named it '$title'" -ForegroundColor DarkGray
        }

        # Three fields the workbook derives while building its Overview and the summary row
        # does not carry: which sport the CheckID belongs to, what the Rows cell reads for a
        # check that failed, and the status the board opens on. Derived here through the same
        # Get-SeededStatus the workbook uses, so the two cannot come to different conclusions
        # about the same check.
        $enriched = @()
        foreach ($entry in $Summary) {
            # Findings rather than the raw row count, so the number matches the tab it links
            # to: Remove-CoverageRows takes the COVERAGE row off the tab and this takes it out
            # of the count. Findings is $null for a statement that declares no coverage branch
            # - a pattern or discovery statement - and there the raw count is what its tab
            # holds.
            $rowsCell = switch -Wildcard ($entry.Status) {
                'ERROR*' { 'ERROR' }
                'SKIPPED*' { 'SKIPPED' }
                default { $(if ($null -ne $entry.Findings) { $entry.Findings } else { $entry.Rows }) }
            }
            $ran = ($rowsCell -isnot [string])
            $signal = $(if ($entry.Signal) { [string]$entry.Signal } else { 'Actionable' })

            $copy = $entry.PSObject.Copy()
            $copy | Add-Member -NotePropertyName Sport -NotePropertyValue (Get-SportFromCheckId -CheckId $entry.CheckId) -Force
            $copy | Add-Member -NotePropertyName RowsCell -NotePropertyValue $rowsCell -Force
            $copy | Add-Member -NotePropertyName SeededStatus -NotePropertyValue `
                (Get-SeededStatus -Signal $signal -Rows $rowsCell -Ran $ran -Eligible $entry.Eligible) -Force
            $enriched += $copy
        }

        # A run is complete when it was asked for the sport's whole approved catalogue and
        # nothing capped it. Only such a run may mark the checks it did not produce; anything
        # narrower was never asked for them. A skipped check is not affected either way - it
        # has a summary row of its own and reports SKIPPED. Test-RunWasComplete owns the
        # expression, because Save-RunLedger asks the same question about the review snapshot.
        $complete = Test-RunWasComplete

        # The same stamp the ledger files a run under, so a row in the review log can be traced
        # to the run that dropped the note and to the output folder that run left behind.
        $stamp = $(if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
                $script:RunStartedUtc.ToLocalTime().ToString('dd.MM.yyyy HH-mm-ss')
            }
            else { Split-Path -Leaf $OutputFolder })

        # Every run reads the registry for the sport's withdrawn checks, whether or not it was
        # asked for them. Deprecation is not an inference from what the run produced - it is a
        # row in POWERBI_REGISTRY.md - so it does not wait for a complete run the way "Not in
        # this run" has to. Read here rather than taken from the selection, because a run
        # naming two CheckIDs has a selection covering two checks and the board carries all of
        # them.
        $retired = @(Get-RegistryRow -SportName $Sport |
            Where-Object { $_.Status -eq 'Deprecated' } |
            ForEach-Object { [string]$_.CheckId })

        # Built from the ledger plus this run, and windowed to the last $SheetHistoryRuns runs.
        # Passed in rather than read inside the merge, so the one file that knows where the
        # ledger lives stays the one file that decides what is kept - and so the merge can be
        # tested against a handful of rows without a ledger or a login.
        $history = @(Get-SheetHistoryRows -Summary $Summary -Sport $Sport -RunId $stamp)

        Set-SheetsStage 'planning the changes'
        $plan = New-SheetsMergePlan -Summary $enriched -Collected $Collected -Existing $state `
            -OutputFolder $OutputFolder -Stamp $stamp -Retired $retired -History $history `
            -Complete:$complete
        if ($plan.Warning) { Write-Host "  $($plan.Warning)" -ForegroundColor Yellow }

        $sent = Invoke-SheetsPlan -SpreadsheetId $id -Plan $plan
        Write-Host ("  {0} tab(s) added, {1} cleared, {2} range(s) written, {3} table(s)" -f `
                $sent.Added, $sent.Cleared, $sent.Written, $sent.Tables) -ForegroundColor DarkGray
        # Where the reviewers' notes were put before the tabs were cleared. Said out loud
        # rather than left in the folder, because the run that needs it is the one that did
        # not finish - and that run's last legible line is this one.
        if ($sent.PSObject.Properties.Name -contains 'NotesSaved' -and $sent.NotesSaved) {
            Write-Host ("  {0} reviewer note(s) written down before the clear: {1}" -f `
                    $sent.NotesCount, $sent.NotesSaved) -ForegroundColor DarkGray
        }

        # A check a reviewer had closed has come back, and the board is the only place that
        # says so. Queued here rather than where the transition is decided, and after the plan
        # has been applied rather than before, because a message about a red cell that was
        # never written is worse than no message: the reader goes to the board and finds the
        # green chip the run failed to replace.
        #
        # Nothing in here may end the update. By this line the statements have run, the
        # workbook is on disk and the document is current; a queue file that will not open is
        # a message somebody does not get, and that is not worth any of the three.
        try {
            $reopened = New-ReopenNotification -Renames $plan.StatusRenames -RunId $stamp `
                -StartedUtc $script:RunStartedUtc -Sport $Sport -SheetId $id `
                -ReopenedWord $SheetsReopenedStatus `
                -GidOf $(if ($sent.PSObject.Properties.Name -contains 'GidOf') { $sent.GidOf } else { $null })
            if ($reopened.Count -gt 0) {
                $queuePath = Get-NotifyQueuePath
                $queued = Add-NotifyEvent -Queue (Read-NotifyQueue -Path $queuePath) -Events $reopened
                if ($queued.Added -gt 0) {
                    [void](Save-NotifyQueue -Queue $queued.Queue -Path $queuePath)
                }
                # Named, never counted. The whole argument for this feature is that a number
                # tells a reader nothing about whether to stop what they are doing, and a run
                # that queued a message without saying which check it was about would put the
                # only copy of that answer in a file nobody opens.
                foreach ($item in $reopened) {
                    Write-Host ("  Reopened, and queued to notify: {0} {1} - was {2}, this run returned {3} open finding(s)" -f `
                            $item.checkId, $item.name, $item.previousStatus, $item.currentFindings) `
                        -ForegroundColor Yellow
                }
                if ($queued.Added -lt $reopened.Count) {
                    Write-Host ("  {0} of them were already queued by an earlier attempt and are not queued twice" -f `
                            ($reopened.Count - $queued.Added)) -ForegroundColor DarkGray
                }
            }

            # The run queues and does not send. Sending is TOOLS/Send-Notifications.ps1, on a
            # schedule, and the split is the point rather than a tidiness: a board run covers
            # one sport, so sending here means one mail per sport, and a night across sixteen
            # sports is sixteen mails. Held instead, they arrive as one list.
            $pending = @(Read-NotifyQueue -Path $queuePath |
                    Where-Object { [string]$_.status -eq $NotifyStatusQueued })
            if ($pending.Count -gt 0) {
                Write-Host ("  {0} notification(s) waiting to be sent; TOOLS\Send-Notifications.ps1 sends them" -f `
                        $pending.Count) -ForegroundColor DarkGray
            }
        }
        catch {
            Write-Host ("  the reopen notification could not be queued and the run is unaffected: {0}" -f `
                    $_.Exception.Message) -ForegroundColor Yellow
        }

        # What the update cost, and where. Kept for the run's closing line as well as printed
        # here, because the question this answers is usually "was it the database or the board",
        # and that one needs both halves side by side.
        $script:SheetSeconds = ((Get-Date) - $sheetClock).TotalSeconds
        Write-Host ("  Document updated in {0}: {1}" -f `
                (Format-RunDuration -Seconds $script:SheetSeconds),
                (Get-SheetsTimingLine -Total $script:SheetSeconds)) -ForegroundColor DarkGray
        Write-Host ("  {0} value request(s), {1} tab(s) confirmed to have reached their last row" -f `
                $script:SheetsValueRequests, $script:SheetsTabsConfirmed) -ForegroundColor DarkGray

        $script:SheetOutcome = [ordered]@{
            updated         = $true
            seconds         = [math]::Round($script:SheetSeconds, 1)
            valueRequests   = [int]$script:SheetsValueRequests
            tabsConfirmed   = [int]$script:SheetsTabsConfirmed
            rowsReaddressed = [int]$script:SheetsRowsMoved
            tabsMoved       = [int]$script:SheetsTabsMoved
            phases          = (Get-SheetsPhaseRecord)
        }

        # Said out loud, because it changes what somebody sees when they open the document and
        # nothing else on the run would mention it.
        if ($script:SheetsTabsMoved -gt 0) {
            Write-Host ("  {0} board tab(s) moved to the front: {1}" -f `
                    $script:SheetsTabsMoved, ($SheetsLeadingTabs -join ', ')) -ForegroundColor DarkGray
        }

        # Said out loud rather than kept. A cell that had to be re-addressed is a cell the board
        # moved under, which is the defect this addressing exists to close - so the run that
        # sees it happening is the run that has to say it did.
        if ($script:SheetsRowsMoved -gt 0) {
            Write-Host ("  {0} cell(s) were re-addressed because the board moved under the write" -f `
                    $script:SheetsRowsMoved) -ForegroundColor DarkGray
        }
        if ($history.Count -gt 0) {
            # The span rather than the count of runs, because "40 runs" says nothing about how
            # far back the tab reaches and the two are not the same question on a ledger this
            # busy: forty entries can be a fortnight of re-runs or a year of weekly boards.
            $span = @($history | ForEach-Object { [string]$_.'Run date' } |
                Where-Object { $_ } | Sort-Object -Unique)
            $reach = $(if ($span.Count -gt 1) { '{0} to {1}' -f $span[0], $span[-1] }
                elseif ($span.Count -eq 1) { $span[0] } else { 'undated' })
            Write-Host ("  History: {0:n0} row(s) over the last {1} recorded run(s), {2}" -f `
                    $history.Count, [math]::Min($SheetHistoryRuns, @($history |
                        ForEach-Object { [string]$_.Run } | Sort-Object -Unique).Count), $reach) `
                -ForegroundColor DarkGray
        }

        # Status is the reviewer's column and the run writes into it in two narrow cases only.
        # Both are named here rather than counted, because a status that changed without anybody
        # choosing it is otherwise findable only in the document's own edit history, one cell at
        # a time - which is how the 2026-08-25 On Hold defect went four days without being seen.
        # Notes that could not be put back, named per check rather than counted in one number.
        # A conclusion is carried only against a row that comes back identical, so a statement
        # whose values do not survive the round trip through Sheets would park every note it
        # holds on the same run - and a Review log nobody opens is where that hides. Printed
        # here for the same reason the Status changes below are: a number that moved without
        # anybody choosing it has to be said out loud on the run it moved.
        foreach ($lost in @($plan.NotesDropped)) {
            $moved = $(if ($lost.Moved -gt 0) {
                    ', {0} of them because the finding came back reading differently' -f $lost.Moved
                } else { '' })
            Write-Host ("  {0}: {1} note(s) went to the Review log{2}" -f `
                    $lost.CheckId, $lost.Count, $moved) -ForegroundColor Yellow
        }

        foreach ($change in @($plan.StatusRenames)) {
            $from = $(if ([string]::IsNullOrWhiteSpace([string]$change.From)) { 'blank' } else { "'$($change.From)'" })
            Write-Host ("  Status set on {0}: {1} -> '{2}' - {3}" -f `
                    $change.CheckId, $from, $change.To, $change.Why) -ForegroundColor Yellow
        }
        foreach ($fixed in @($plan.MirrorsRepaired)) {
            Write-Host ("  Comment mirror on {0} named another check's tab and was put back: {1} -> {2}" -f `
                    $fixed.CheckId, $fixed.Was, $fixed.Now) -ForegroundColor Yellow
        }
        # A withdrawn check leaving the board, named rather than counted and for the same reason
        # every other write into somebody's columns is: the row goes, and any comment on it goes
        # with it. If that was not wanted, this line is where it has to be seen.
        if (@($plan.StatusRemoved).Count -gt 0) {
            Write-Host ("  Withdrawn and removed from the board: {0}" -f `
                    ((@($plan.StatusRemoved) | ForEach-Object {
                            $was = $(if ([string]::IsNullOrWhiteSpace([string]$_.Status)) { 'no status' } else { $_.Status })
                            "$($_.CheckId) ($was)"
                        }) -join ', ')) -ForegroundColor Yellow
        }
        Write-Host "  https://docs.google.com/spreadsheets/d/$id/edit" -ForegroundColor DarkGray
        return $id
    }
    catch {
        # Which phase, because the earlier ones are already applied and saying otherwise sends
        # somebody to look at a document that is in fact current except for one thing.
        $stage = $(if ($script:SheetsStage) { $script:SheetsStage } else { 'starting' })
        Write-Host "  the live document update failed while $stage" -ForegroundColor Yellow
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Yellow

        # The time it spent before it failed, and where. Kept on the same variable a successful
        # update writes, so the run's closing line does not quietly fold a failed half-hour into
        # the figure for writing files - which is what it did on 27.08, reporting 5m 03s of files
        # for a workbook that took 6m 24s.
        if ($sheetClock) {
            $script:SheetSeconds = ((Get-Date) - $sheetClock).TotalSeconds
            Set-SheetsStage ''
            Write-Host ("  It had been going {0}: {1}" -f `
                    (Format-RunDuration -Seconds $script:SheetSeconds),
                    (Get-SheetsTimingLine -Total $script:SheetSeconds)) -ForegroundColor Yellow
        }

        # The failure, in the ledger rather than only on a console nobody kept. `stage` is the
        # one thing that says how much of the document is current: everything before it applied.
        $script:SheetOutcome = [ordered]@{
            updated         = $false
            stage           = [string]$stage
            why             = ([string]$_.Exception.Message -replace '\s+', ' ')
            seconds         = [math]::Round($script:SheetSeconds, 1)
            valueRequests   = [int]$script:SheetsValueRequests
            tabsConfirmed   = [int]$script:SheetsTabsConfirmed
            rowsReaddressed = [int]$script:SheetsRowsMoved
            tabsMoved       = [int]$script:SheetsTabsMoved
            phases          = (Get-SheetsPhaseRecord)
        }
        Write-Host '  Whatever ran before that stage is applied. The results are on disk either way,' -ForegroundColor Yellow
        Write-Host '  and running again brings the document fully up to date.' -ForegroundColor Yellow
        return $null
    }
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
    # Builds the whole workbook out of what the run produced. Returns the checks whose tab
    # name still had to be cut.
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
    # The eligible count travels with the rows rather than being read back out of them: the
    # COVERAGE row is stripped before a tab is written, so recomputing it here would find
    # nothing and call every check in the workbook uncounted. A caller passing rows with no
    # Eligible beside them - a fixture, an older path - still gets the old reading.
    $eligibleOf = @{}
    $tabRowsOf = @{}
    foreach ($item in $Collected) {
        $tabRowsOf[(Get-JobRunKey -Job $item.Job)] = @(Remove-CoverageRows -Rows $item.Rows).Count
        $eligibleOf[(Get-JobRunKey -Job $item.Job)] = $(
            if ($item.PSObject.Properties.Name -contains 'Eligible' -and $null -ne $item.Eligible) {
                $item.Eligible
            }
            else { Get-CoverageCount -Rows $item.Rows })
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
        #
        # Findings rather than the raw row count, for the reason the live document uses it too:
        # the COVERAGE row is not work, so it is not in the number. The two derivations have to
        # stay the same expression or the workbook and the board seed different statuses for
        # the same check - which is what the note above Get-SeededStatus warns about.
        $entryKey = $(if ($entry.PSObject.Properties.Name -contains 'RunKey' -and $entry.RunKey) {
                [string]$entry.RunKey
            }
            else { [string]$entry.CheckId })
        $rowsCell = switch -Wildcard ($entry.Status) {
            'ERROR*' { 'ERROR' }
            'SKIPPED*' { 'SKIPPED' }
            default {
                $(if ($null -ne $entry.Findings) { $entry.Findings }
                    elseif ($tabRowsOf.ContainsKey($entryKey)) { $tabRowsOf[$entryKey] }
                    else { $entry.Rows })
            }
        }
        $ran = ($rowsCell -isnot [string])

        $signalValue = $(if ($entry.Signal) { $entry.Signal } else { 'Actionable' })

        $runKey = $(if ($entry.PSObject.Properties.Name -contains 'RunKey' -and $entry.RunKey) {
                [string]$entry.RunKey
            }
            else { [string]$entry.CheckId })

        $eligible = $(if ($eligibleOf.ContainsKey($runKey)) { $eligibleOf[$runKey] } else { $null })
        $seededStatus = Get-SeededStatus -Signal $signalValue -Rows $rowsCell -Ran $ran -Eligible $eligible

        # Object sits beside the CheckID because it is what the board is worked through by: a
        # Comp.Rank is generated from the events beneath it, so repairing the ranking before
        # the events is work that gets undone, and the check name does not say which layer it
        # reads. Taken from POWERBI_REGISTRY.md and collapsed to the six words the reviewers
        # asked for on 2026-08-19; the registry keeps its finer nine.
        $overviewRows += [pscustomobject]@{
            'Sport'         = Get-SportFromCheckId -CheckId $entry.CheckId
            'CheckID'       = $entry.CheckId
            'Object'        = (ConvertTo-SheetsObjectName -Value ([string]$entry.Object))
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
            # Appended, not placed where it would be read first, and the reason is mechanical:
            # H, I, K and L:M are pinned by letter in this builder, in the validation sqref
            # below and in Test-Tools.ps1, so a column inserted anywhere before them breaks the
            # row-count link, the Status dropdown and the Comment mirror at once. Last is the
            # only position that costs nothing, and a reviewer filters on it wherever it sits.
            'Data types'    = [string]$entry.DataTypes
        }
        # Rows carries the jump to the tab, so its column moves with it - H, because a third
        # column sits at C before Check Name.
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
            # The same vocabulary the live board offers, taken from the same list, because a
            # workbook and a board that disagree about the words are how the column came to
            # hold nine spellings of five ideas in the first place. $SheetsStatusBands owns it.
            Validation     = @{
                Sqref  = "I2:I$overviewRow"
                Values = (@($SheetsStatusBands | ForEach-Object { $_.Value }) -join ',')
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
            Rows   = (Remove-CoverageRows -Rows $item.Rows)
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

    # Written aside and moved into place, so a write interrupted halfway cannot leave a
    # truncated zip where the last good one was.
    $writing = $Path + '.writing'
    Save-Workbook -Sheets $sheets -Path $writing
    Move-Item -LiteralPath $writing -Destination $Path -Force

    return $shortened
}

# --------------------------------------------------------------------------------------
# The machine-wide run lock
# --------------------------------------------------------------------------------------
#
# One run at a time on this machine, whoever started it: the Sheets worker, the owner's
# shell, a scheduled task, another script. Two runs that overlap do not merely compete for
# the server - they write the same board and append to the same ledger, and the second one
# to finish silently wins.
#
# The lock is a file held open for writing with FileShare::Read. Anybody else asking to
# write it is refused by the operating system, and anybody may read it, which is how a
# waiting run finds out what it is waiting for. Nothing has to be cleaned up: when the
# process dies, by exit or by kill or by a reboot, Windows drops the handle and the lock is
# gone with it. There is no timestamp to expire and no stale lock to break by hand, which
# are the two failure modes a lock file usually brings with it.

function Get-RunLockPath {
    # Outside the repository on purpose. It is machine state, not package state, and a lock
    # inside TOOLS would be one more file the validator has to know to ignore.
    if ($env:EP_QB_LOCK) { return $env:EP_QB_LOCK }

    $root = $env:LOCALAPPDATA
    if ([string]::IsNullOrWhiteSpace($root)) { $root = [IO.Path]::GetTempPath() }
    $dir = Join-Path $root 'entpulse-qb'
    if (-not (Test-Path -LiteralPath $dir)) {
        [void](New-Item -ItemType Directory -Path $dir -Force)
    }
    return (Join-Path $dir 'run.lock')
}

function Read-RunLockHolder {
    # Reads the description the holder wrote. FileShare::ReadWrite on this side, because the
    # holder's own handle is a writing one and a reader that does not share writing is
    # refused by the same rule that keeps the second runner out.
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $text = ''
    try {
        $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
        try {
            $reader = New-Object IO.StreamReader($stream)
            $text = $reader.ReadToEnd()
        }
        finally { $stream.Dispose() }
    }
    catch { return $null }

    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    try { return ($text | ConvertFrom-Json) } catch { return $null }
}

function Format-RunLockHolder {
    # One line a person can act on: what is running, since when, and by which process. The
    # Apps Script confirmation and the worker's WAITING reason are both built from this, so
    # it says the work rather than the switches - "a full board refresh of Soccer" tells the
    # reader how long to expect to wait; "-RunAll" does not.
    param($Holder)

    if (-not $Holder) { return 'another run, which did not say what it was' }

    $what = [string]$Holder.what
    if ([string]::IsNullOrWhiteSpace($what)) { $what = 'another run' }

    $since = ''
    try {
        $started = [datetime]::Parse([string]$Holder.startedUtc, [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::AdjustToUniversal -bor [Globalization.DateTimeStyles]::AssumeUniversal)
        $seconds = ((Get-Date).ToUniversalTime() - $started).TotalSeconds
        if ($seconds -ge 0) { $since = ', running for ' + (Format-RunDuration -Seconds $seconds) }
    }
    catch { $since = '' }

    return ('{0} (process {1}{2})' -f $what, $Holder.pid, $since)
}

function Open-RunLock {
    # Takes the lock, or reports who has it. Returns $true when this run may proceed.
    #
    # -NoWait is the Sheets worker's path: it wants the reason, not the wait, so it can write
    # WAITING into the request row and come back. Everything else waits, because waiting
    # behind a board refresh is the normal case - 13 minutes for a mid-sized sport, measured
    # on Mountain Bike - and a run that failed instead would read as the feature being broken.
    param(
        [string]$What,
        [int]$WaitSeconds = 2700,
        [switch]$NoWait
    )

    $script:RunLockBlockedBy = $null
    $path = Get-RunLockPath
    $deadline = (Get-Date).AddSeconds([math]::Max(0, $WaitSeconds))
    $announced = $false
    $stream = $null

    while ($true) {
        try {
            $stream = [IO.File]::Open($path, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::Write, [IO.FileShare]::Read)
            break
        }
        catch [IO.IOException] {
            $holder = Read-RunLockHolder -Path $path
            $script:RunLockBlockedBy = $holder
            $description = Format-RunLockHolder -Holder $holder

            if ($NoWait) {
                Write-Host ('  the machine is already running {0}, so this run was not started' -f $description) -ForegroundColor Yellow
                return $false
            }
            if ((Get-Date) -ge $deadline) {
                Write-Host ('  gave up waiting for {0}' -f $description) -ForegroundColor Yellow
                return $false
            }
            if (-not $announced) {
                Write-Host ('  waiting for {0}' -f $description) -ForegroundColor Yellow
                $announced = $true
            }
            Start-Sleep -Seconds 3
        }
    }

    $holder = [ordered]@{
        pid        = $PID
        startedUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        what       = $What
        host       = $env:COMPUTERNAME
    }
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes(($holder | ConvertTo-Json -Compress))
        $stream.SetLength(0)
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush()
    }
    catch {
        # The lock is held either way; only the description failed. A waiter then reads it as
        # "another run, which did not say what it was", which is worse than a name and better
        # than letting a second run through.
        Write-Host ('  the run lock was taken but could not be described: {0}' -f $_.Exception.Message) -ForegroundColor DarkGray
    }

    $script:RunLockStream = $stream
    if ($announced) { Write-Host '  the machine is free; starting' -ForegroundColor DarkGray }
    return $true
}

function Close-RunLock {
    # Called at the end of a run. Not required for correctness - the handle dies with the
    # process - but a run invoked in-process rather than as its own powershell.exe would
    # otherwise hold the machine until that session exited.
    if (-not $script:RunLockStream) { return }
    try { $script:RunLockStream.Dispose() } catch { }
    $script:RunLockStream = $null
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
    Write-Line "$Entry -History BMX-DQ-003" 'every recorded run of a check, oldest first'

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
    Write-Host '  Overview lists Sport, CheckID, Object, Check Name, What it does, Rows' -ForegroundColor DarkGray
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
    Write-Line "$Entry ... -TestRun" 'a run that leaves no trace'
    Write-Host '  Results still land on disk, under TEST <Sport> <stamp> so the folder can be' -ForegroundColor DarkGray
    Write-Host '  deleted on sight. Nothing is recorded, so the next real run still compares' -ForegroundColor DarkGray
    Write-Host '  against the last real one.' -ForegroundColor DarkGray
    Write-Host '  Each run appends its row, finding and eligible counts to RUNS\<Sport>.json,' -ForegroundColor DarkGray
    Write-Host '  then reads itself against the last one and writes a Verdict per check:' -ForegroundColor DarkGray
    Write-Host '  Clean, Resolved, Improved, Unchanged, Regressed, As expected, Above residual,' -ForegroundColor DarkGray
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

if ($History) {
    # A local read of the ledger, so it sits with -ListChecks above the login rather than
    # below it: asking what a check has done before should never need credentials.
    $sport = $(if ($ResolvedSportSlug) { $ResolvedSportSlug }
        elseif ($History -match '^(.+)-DQ-') { $matches[1] }
        else { '' })

    if (-not $sport -or $sport -eq 'GLOBAL') {
        throw ("-History needs to know the sport, and '$History' does not name one. Pass a sport " +
            "CheckID such as BMX-DQ-003, or add -Sport.")
    }
    Show-CheckHistory -Pattern $History -Sport $sport
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
    # The file's name labels the run and is not its CheckId, which is empty here as it is
    # under -Sql: both are ad-hoc statements that came from nowhere in the catalogue.
    #
    # It used to be the CheckId, and the cost was not cosmetic. Get-SportFromCheckId reads a
    # prefix out of a CheckId, and a basename with no -DQ- in it falls through to everything
    # before the first hyphen - so a run of comprank.sql filed itself under a sport called
    # "comprank" and Save-RunLedger created RUNS/comprank.json, inside the working copy and
    # tracked in git. Two of those reached a commit before anybody noticed.
    $jobs = @([pscustomobject]@{
            CheckId = ''
            Name    = [IO.Path]::GetFileNameWithoutExtension($File)
            What    = ''
            Sql     = (Get-Content -LiteralPath $File -Raw)
        })
}
elseif ($CheckId) {
    $jobs = @(Select-Checks -Patterns $CheckId)

    # A sport CheckID carries its sport in the prefix, and most of them resolve to a template
    # whose {{...}} placeholders only that sport can fill. So a run given nothing but the ID
    # adopts the identity the ID already states, rather than stopping on a placeholder the
    # user had no reason to think was involved.
    #
    # Only when every selected check agrees, and never over an explicit -Sport: a run naming
    # two sports has no single identity to adopt, and one that was told its sport was told.
    if (-not $sportIdentity) {
        # Wrapped in @() before indexing, not only before counting. Select-Object -Unique over
        # one item returns the string itself rather than a one-element array, and indexing a
        # string takes a character: the first attempt at this resolved the sport as "A".
        $prefixes = @(@($jobs | ForEach-Object {
                    if ([string]$_.CheckId -match '^(.+)-DQ-') { $matches[1] } }) | Select-Object -Unique)
        if ($prefixes.Count -eq 1 -and $prefixes[0] -ne 'GLOBAL') {
            $inferred = Resolve-SportIdentity -SportValue $prefixes[0]
            if ($inferred) {
                $sportIdentity = $inferred
                $ResolvedSportSlug = $inferred.Slug
                $ResolvedDatabaseSportName = $inferred.DatabaseName
                $script:RunSportName = $ResolvedSportSlug
                Write-Host "Sport taken from the CheckID: $ResolvedSportSlug" -ForegroundColor DarkGray
            }
        }
    }
}
else {
    throw 'Nothing to run. Pass a CheckID, -File, -Sql or -RunAll with -Sport. Use -ListChecks to list registered CheckIDs.'
}

# Deferred under -DataType, and applied after that narrowing instead. The cap trims the matched
# set, and under -DataType the matched set is not what runs: capping first takes an arbitrary
# ten of a hundred and then filters those, which on Ice Hockey left nothing at all and read as
# "no statement reads rank" when twenty-two of them do. -TemplateIds does not have this problem
# because it narrows the scope of each statement rather than choosing between statements.
if ($MaxChecks -gt 0 -and $DataType.Count -eq 0 -and $jobs.Count -gt $MaxChecks) {
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

    # The named discovery statements, on the same terms. Their parameters are tested against
    # what the sport has recorded as well as what -Sport discovers: PERSON_PARTICIPANT_TYPE_LIST
    # is not something a run can work out for itself, but every sport in the package states it,
    # and a statement that only needs a value already written down is no less automatic for it.
    # A sport that has not recorded one is skipped by name rather than failing on a placeholder.
    if ($RideAlongDiscovery.Count -gt 0) {
        $supplied = @{}
        foreach ($name in $DiscoverableParameters) { $supplied[$name] = $true }
        if ($sportIdentity) {
            foreach ($name in (Get-SportFileParameters -SportName $ResolvedSportSlug).Keys) {
                $supplied[[string]$name] = $true
            }
        }

        $alongside = @(Get-CheckCatalogue |
            Where-Object { $RideAlongDiscovery.ContainsKey([string]$_.CheckId) } |
            Where-Object { -not $alreadyMatched.ContainsKey($_.CheckId) } |
            Sort-Object CheckId)

        $carried = @()
        foreach ($one in $alongside) {
            $missing = @(Get-MissingPlaceholders -Text $one.Sql -Values $supplied)
            if ($missing.Count -gt 0) {
                Write-Host ("  {0} left out: the sport supplies no {1}." -f `
                        $one.CheckId, ($missing -join ', ')) -ForegroundColor DarkGray
                continue
            }
            $carried += $one
        }

        if ($carried.Count -gt 0) {
            $jobs = @($jobs) + $carried
            Write-Host ("Adding {0} discovery statement(s) alongside: {1}" -f `
                    $carried.Count, (($carried | ForEach-Object { $_.CheckId }) -join ', ')) -ForegroundColor DarkGray
        }
    }
}

# The category too, and for the same reason - it decides the Priority band the board sorts on,
# so a job that lost it sorts under "no priority" rather than where the reader expects it.
$jobs = @(Set-JobCheckCategory -Jobs $jobs)

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

# Named before the sport block so the report below can read it whether or not a sport was given.
$statisticTrimmed = @()
$statisticBranchMissing = @()

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

    # The Comp.Rank branch, dropped from the statements that mark it where the sport has no
    # confirmed parameters to write it with. Read here rather than after discovery, and that
    # order is the point: discovery can find a shard for any sport, so letting it fill one
    # would run a layer nobody has confirmed and report its coverage as though somebody had.
    # A value passed on -Params counts as confirmed and keeps the branch, which is how a run
    # reads the layer deliberately.
    $statisticBranchMissing = @($StatisticBranchParameters |
        Where-Object { -not $paramTable.ContainsKey($_) })
    if ($statisticBranchMissing.Count -gt 0) {
        foreach ($job in $jobs) {
            $trimmed = Remove-StatisticBranch -Text $job.Sql
            if ($trimmed.Removed -gt 0) {
                $job.Sql = $trimmed.Sql
                $statisticTrimmed += $job.CheckId
            }
        }
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
        Confirm-RunnerSession
        foreach ($entry in (Resolve-SportParameters -DatabaseSportNameValue $ResolvedDatabaseSportName).GetEnumerator()) {
            if (-not $paramTable.ContainsKey($entry.Key)) { $paramTable[$entry.Key] = $entry.Value }
        }
    }
    else {
        Write-Host '  nothing left to discover; no discovery query sent.' -ForegroundColor DarkGray
    }

    # After discovery, because the complement is computed per sport and SPORT_ID may only have
    # arrived a moment ago. A sport declaring the boundary the usual way reaches none of this:
    # Resolve-ClientBoundary returns nothing and the value it already has stands.
    $derived = Resolve-ClientBoundary -Values $paramTable
    if ($null -ne $derived) { $paramTable[$ClientScopeParameter] = $derived }
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

# Read after expansion and after narrowing, so what is recorded is what was actually sent. A
# template filter changes the scope but not the stored values a statement reads, and a run
# reporting the types of an unexpanded statement would be reporting the placeholders.
foreach ($job in $runnable) {
    $job | Add-Member -NotePropertyName 'DataTypeRefs' -NotePropertyValue (Get-StatementDataType -Sql $job.Sql) -Force
    $job | Add-Member -NotePropertyName 'AuditedTypeIds' -NotePropertyValue (Get-StatementAuditedTypes -Sql $job.Sql) -Force
}

# One naming pass for the whole batch. Skipped under -DryRun, which sends nothing and must go
# on sending nothing - unless -DataType named a type by name, where the names are what the
# selection is made against and the run cannot answer without them.
$dataTypeNames = @{}
if ($runnable.Count -gt 0 -and (-not $DryRun -or $DataType.Count -gt 0)) {
    $allRefs = @($runnable | ForEach-Object { @($_.DataTypeRefs) })
    $dataTypeNames = Resolve-DataTypeName -Refs $allRefs
}

foreach ($job in $runnable) {
    $job | Add-Member -NotePropertyName 'DataTypes' `
        -NotePropertyValue (Format-DataTypeList -Refs $job.DataTypeRefs -Names $dataTypeNames) -Force
}

if ($DataType.Count -gt 0) {
    $selected = @()
    foreach ($job in $runnable) {
        if (Test-DataTypeMatch -Refs $job.DataTypeRefs -Names $dataTypeNames -Wanted $DataType) {
            $selected += $job
            continue
        }
        # Reported rather than dropped, for the reason every other narrowing here is reported:
        # a batch that quietly shrank is read as a batch that ran.
        $skipped += [pscustomobject]@{
            Job     = $job
            Missing = ''
            Kind    = 'NOT_THIS_DATA_TYPE'
            Reason  = $(if ($job.DataTypes) { "reads $($job.DataTypes)" } else { 'reads no stored value type' })
        }
    }
    $runnable = $selected
    Write-Host ("Narrowed to -DataType {0}: {1} check(s) read it." -f ($DataType -join ', '), $runnable.Count) -ForegroundColor DarkGray

    # The cap the matched set did not get, now that the set it should cap is known.
    if ($MaxChecks -gt 0 -and $runnable.Count -gt $MaxChecks) {
        Write-Host "  running the first $MaxChecks of them." -ForegroundColor DarkGray
        $runnable = $runnable[0..($MaxChecks - 1)]
    }
    Write-Host ''
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
    # Counted, not listed. Under -DataType this is normally most of the sport's catalogue, and
    # a hundred lines saying a check reads something else would bury the three that were run.
    $otherType = @($skipped | Where-Object { $_.Kind -eq 'NOT_THIS_DATA_TYPE' })
    if ($otherType.Count -gt 0) {
        Write-Host "  reads none of the -DataType values ($($otherType.Count))" -ForegroundColor DarkGray
    }
    Write-Host ''
}

if ($registryTrimmed.Count -gt 0) {
    Write-Host ("Registry branch dropped from {0}: {1}" -f $registryTrimmed.Count, ($registryTrimmed -join ', ')) -ForegroundColor DarkGray
    Write-Host ''
}

if ($statisticTrimmed.Count -gt 0) {
    # Louder than the registry line and deliberately so. That one reports a switch somebody
    # asked for; this one reports a narrowing the run decided by itself, and a coverage number
    # standing without it beside it would read as the whole population.
    Write-Host ("Comp.Rank branch dropped from {0}: {1}" -f $statisticTrimmed.Count, ($statisticTrimmed -join ', ')) -ForegroundColor Yellow
    Write-Host ("  {0} not confirmed for this sport, so the branch cannot be written. The run" -f ($statisticBranchMissing -join ' and ')) -ForegroundColor Yellow
    Write-Host '  covers the other paths only, and eligible_count counts those.' -ForegroundColor Yellow
    Add-RunDecision -Kind 'Comp.Rank branch dropped' -Subject ($statisticTrimmed -join ', ') `
        -Chose 'ran the statement without its Comp.Rank path' `
        -Why ("{0} is not confirmed in SPORTS/params.json for this sport, so the marked branch cannot be written. eligible_count counts the remaining paths, and a person reachable only through Comp.Rank is not audited by this run" -f ($statisticBranchMissing -join ' and ')) `
        -Alternatives @(
            'confirm the Comp.Rank parameters in the sport file and re-run with every path',
            'pass -Params SHARD_ID=<id> STATISTIC_TYPE_ID=<id> to read the layer for this run only',
            'accept the narrowed coverage and record in the sport file which paths it covered')
    Write-Host ''
}

if ($runnable.Count -eq 0) {
    if ($DataType.Count -gt 0) {
        throw ("No matched statement reads $($DataType -join ', '). Name a type id, or a name as " +
            "the database spells it - run one check and read its Data types column for the " +
            "vocabulary this sport actually uses.")
    }
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

# ----- the machine-wide lock -----------------------------------------------------------

# Taken here rather than at the top of Main, so that -Info, -History, -ListChecks and -DryRun
# stay free while a board refresh is under way: none of them sends a statement, writes a file,
# touches the document or appends to the ledger, and refusing a reader the catalogue would be
# a lock that costs more than it protects.
if (-not $NoLock) {
    $sportLabel = if ($ResolvedSportSlug) { $ResolvedSportSlug } else { 'no sport named' }
    $lockWhat = if ($RunAll -and $MaxChecks -le 0) {
        'a full board refresh of {0}, {1} check(s)' -f $sportLabel, $jobs.Count
    }
    elseif ($isBatch) {
        'a batch of {0} check(s) on {1}' -f $jobs.Count, $sportLabel
    }
    else {
        '{0} {1}' -f $jobs[0].CheckId, $jobs[0].Name
    }

    if (-not (Open-RunLock -What $lockWhat -WaitSeconds $LockWaitSeconds -NoWait:$NoWait)) {
        # Not an error. The caller asked not to wait, or waited as long as it was willing to,
        # and Open-RunLock has already said what is in the way. Exit code 75 is EX_TEMPFAIL:
        # the Sheets worker reads it as WAITING rather than ERROR, so a queued request is put
        # back rather than marked failed for having been asked at a busy moment.
        exit 75
    }
}

# ----- session -------------------------------------------------------------------------

# -Sport has to reach the database to discover its parameters and to work out the client
# boundary, so the session may already exist. Confirm-RunnerSession is a no-op when it does.
Confirm-RunnerSession

# ----- batch run -----------------------------------------------------------------------

if ($isBatch) {
    if ($TestRun) {
        Write-Host 'Test run: results are written, nothing is recorded.' -ForegroundColor Yellow
    }
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
    $script:RecentFindings = Import-RecentFindings -Jobs $jobs
    $script:TrendStampFormat = Get-TrendStampFormat -Recent $script:RecentFindings `
        -Current $script:RunStartedUtc.ToLocalTime()
    if ($script:PreviousRun.Count -gt 0) {
        Write-Host ("Comparing against the last recorded run of {0} check(s)." -f $script:PreviousRun.Count) -ForegroundColor DarkGray
    }
    else {
        Write-Host 'No earlier run recorded for this sport: every verdict this run writes is New.' -ForegroundColor DarkGray
    }

    $summary = @()
    $collected = @()
    $index = 0

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
                        $collected += [pscustomobject]@{
                            Job      = $job
                            Rows     = (Remove-CoverageRows -Rows $rows)
                            Eligible = $eligible
                        }
                    }
                    else {
                        # A flat file has nowhere else to record which check a row came from.
                        # The file is named for the run rather than the check, or two chained
                        # runs of one CheckID would overwrite each other.
                        $tagged = Add-CheckColumns -Rows $rows -CheckId $runKey -Name $job.Name
                        $target = Join-Path $OutDir ((Get-SafeFileName -CheckId $runKey) + $extension)
                        Save-Rows -Rows $tagged -Path $target -Fmt $Format

                        # The live document needs the rows whatever file format was asked
                        # for, and this is the only place they exist. Collecting them under
                        # the workbook alone left a batch run in any other format updating
                        # Overview and nothing else: the merge plan walks $collected to
                        # clear and rewrite each check's own tab, to point Rows at that tab,
                        # and to put the statement on the SQL tab, so an empty list produced
                        # fresh numbers standing over last run's findings. Untagged, because
                        # check_id and check_name belong to a file that left this shell and
                        # the tab already carries both. Capped at what a tab can hold: a flat
                        # run streams to disk precisely so a large result is not carried in
                        # memory, and the plan writes no more than this either.
                        $collected += [pscustomobject]@{
                            Job      = $job
                            Rows     = @((Remove-CoverageRows -Rows $rows) |
                                Select-Object -First $SheetsMaxRowsPerCheck)
                            Eligible = $eligible
                        }
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

            # A workbook run used to rebuild the whole file every sixty seconds here, so that
            # a run which wedged or was interrupted did not cost the checks that had already
            # succeeded. Removed 2026-08-26, measured rather than guessed.
            #
            # The rebuild is whole every time, so it costs more the further the run gets:
            # 36.5 seconds after 30 checks of a Triathlon-shaped board, 49.1 after 114. The
            # interval was counted from the end of the previous write, making the real cycle
            # 60 seconds of work and 45 of writing. Against the recorded runs that is 365 of
            # Triathlon's 968 seconds, and 1079 of Swimming's 1785 - six minutes in every ten
            # spent rewriting a file nobody was reading.
            #
            # What it protected was the least valuable of the three destinations. A run that
            # dies has not updated the live document and has not written a ledger entry, so it
            # is re-run whatever is on disk; the workbook it leaves behind is a frozen artifact
            # of a run that never counted. TOOLS/README.md owns the reasoning, and per-check
            # flat files - which every other format already writes as it goes - are what to
            # bring back if the protection is ever wanted at a price worth paying.

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

    # The one decision POWERBI.md fixes to a closed set of answers, so it is the one the run
    # can state completely. It is never clean data.
    #
    # A check the sport has already classified as Not applicable is not raised. The zero is
    # still not clean data and the classification does not make it so - it records which of the
    # answers this one is, and re-asking a question the sport file has answered is the same
    # defect as overwriting a comment somebody wrote. Modern-Pentathlon GLOBAL-DQ-028 is the
    # case: it audits a Time Difference field the sport has never written, which is settled and
    # cannot change without the sport changing how it scores.
    #
    # Out of client scope is answered too, and it is a different answer: the population is there
    # and somebody fills it, but not inside the boundary this client bought. Golf's knockout
    # checks are the case - the sport contests match play almost only under templates the client
    # does not take - and the zero lifts on the day that boundary moves, not on an import.
    #
    # Sentinel is the third answer and the only one that is waiting for something: the scope is
    # right, the structure is there, and the sport has not yet imported a row of the kind the
    # check reads. POWERBI.md names it as one of exactly two things a zero can be, and until the
    # signal existed it had no word - so a run asked about the same checks every time while the
    # answer sat in the sport file, out of the run's reach. Cycling-DQ-071 and Cycling-DQ-087
    # are the case, and had been answered for weeks before the Decisions tab stopped asking.
    $classifiedZero = @('Not applicable', 'Out of client scope', 'Sentinel')
    $audited = @($collected | Where-Object {
            0 -eq (Get-CoverageCount -Rows $_.Rows) -and
            $classifiedZero -notcontains [string]$_.Job.Signal
        })
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

    # Before the ledger, so the id is only remembered once the document has taken a write.
    $sheetUsed = Save-RunSheet -Summary $summary -Collected $collected `
        -Sport (Get-RunSport -Jobs $jobs) -OutputFolder $runFolder
    $ledgerFiles = @(Save-RunLedger -Summary $summary -Output $runFolder -SheetId $sheetUsed)

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
    elseif ($TestRun) {
        Write-Host 'Test run: nothing recorded in RUNS/, so the next real run still compares against the last real one.' -ForegroundColor DarkGray
    }

    $failed = @($summary | Where-Object { $_.Status -like 'ERROR*' }).Count
    # Counted and named beside the failures, because a skipped check is not a passed one and
    # this line was the only place anybody looked. Soccer-DQ-080 and Soccer-DQ-096 skipped on
    # every narrowed run from 26.08 to 30.08 - the ledger said SKIPPED each time and this line
    # said nothing, so a run reporting '0 failed' had in fact audited two fewer things than it
    # was asked to. Named rather than counted: a number alone sends the reader to the ledger to
    # find out which, which is exactly the step nobody took.
    $skipped = @($summary | Where-Object { $_.Status -like 'SKIPPED*' })
    $totalRows = ($summary | Measure-Object Rows -Sum).Sum
    Write-Host ("Done: {0} statement(s), {1} rows, {2} failed, {3} skipped -> {4}" -f `
            $index, $totalRows, $failed, $skipped.Count, $destination) -ForegroundColor DarkGray
    if ($skipped.Count -gt 0) {
        Write-Host ("  Skipped, so nothing was audited for: {0}" -f `
            ((@($skipped | ForEach-Object { [string]$_.RunKey })) -join ', ')) -ForegroundColor Yellow
    }
    Close-AbandonedShells

    # Checks whose statement is not the one the previous run ran. Named rather than counted,
    # for the reason the skipped ones are: a count sends the reader to the ledger to work out
    # which, and a number that moved because the statement moved reads exactly like a number
    # that moved because the data did.
    $rewritten = @($summary | Where-Object {
            $_.PrevSqlHash -and $_.SqlHash -and $_.PrevSqlHash -ne $_.SqlHash })
    if ($rewritten.Count -gt 0) {
        Write-Host ('  Compared against a different statement, so the change is not only the data: {0}' -f `
            ((@($rewritten | ForEach-Object { [string]$_.RunKey })) -join ', ')) -ForegroundColor Yellow
    }

    # Where the run's time went, in the three parts anybody asks about. The database figure is
    # the sum of what each statement reported, which is already on every line above; the document
    # figure is what the update cost; the file is what is left, and it is named as what is left
    # rather than measured, so the three add up to the wall clock and none of it goes missing.
    #
    # Printed on every batch run and not only on a slow one. A single slow run is a complaint;
    # the same figure on every run is what makes the next slow one obvious, and the 31 minutes
    # this line was added for had been paid on every Triathlon run before anybody timed one.
    $wall = ((Get-Date) - $script:RunStartedUtc.ToLocalTime()).TotalSeconds
    $database = [double](($summary | Measure-Object Seconds -Sum).Sum)
    $writing = [math]::Max(0.0, $wall - $database - $script:SheetSeconds)
    $split = @(('database {0}' -f (Format-RunDuration -Seconds $database)))
    if ($script:SheetSeconds -ge 0.5) {
        $split += ('document {0}' -f (Format-RunDuration -Seconds $script:SheetSeconds))
    }
    if ($writing -ge 0.5) { $split += ('files {0}' -f (Format-RunDuration -Seconds $writing)) }
    Write-Host ("Elapsed {0}: {1}" -f (Format-RunDuration -Seconds $wall), ($split -join ', ')) `
        -ForegroundColor DarkGray
    Close-RunLock
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
# the history is being consulted. -TestRun is how an experiment stays out.
$script:PreviousRun = Import-PreviousRunEntries -Jobs $jobs
$script:RecentFindings = Import-RecentFindings -Jobs $jobs
$script:TrendStampFormat = Get-TrendStampFormat -Recent $script:RecentFindings `
    -Current $script:RunStartedUtc.ToLocalTime()
$singleSummary = @(New-RunSummaryRow -Job $job -Rows $count -Seconds ([math]::Round($elapsed.TotalSeconds, 1)) `
        -Status 'OK' -Eligible (Get-CoverageCount -Rows $rows) -Findings (Get-FindingCount -Rows $rows))
# The document is brought up to date from a single check too. It was left out at first
# because a partial run marked every check it had not produced as Not in this run, which one
# re-run would have used to repaint the whole board; bbe58d8 restricted that to a full pass,
# and with it gone there is no reason a fix verified here should not show where people read.
$singleSheet = Save-RunSheet -Summary $singleSummary -Collected @([pscustomobject]@{ Job = $job; Rows = $rows }) `
    -Sport (Get-RunSport -Jobs $jobs) -OutputFolder $(if ($OutFile) { Split-Path -Parent $OutFile } else { '' })

$singleLedger = @(Save-RunLedger -Summary $singleSummary -SheetId $singleSheet `
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
    # Whether the two numbers are even comparable. A count that held across a rewritten
    # statement is not the same news as a count that held across the same one, and until the
    # fingerprint was recorded there was no way to tell them apart after the fact.
    if ($singleRow.PrevSqlHash -and $singleRow.SqlHash -and
        $singleRow.PrevSqlHash -ne $singleRow.SqlHash) {
        $against += ', which ran a different statement'
    }
    Write-Host ("{0}: {1} finding(s) of {2} eligible, expected {3}{4}" -f `
            $singleRow.Verdict, $singleRow.Findings, $singleRow.Eligible,
            $(if ($singleRow.Expected) { $singleRow.Expected } else { 'nothing recorded' }),
            $against) -ForegroundColor $verdictColour
}
if ($singleLedger.Count -gt 0) {
    # Named as well as recorded. A batch is identifiable by the folder it wrote and a single
    # run wrote none, so until 2026-09-01 there was nothing to point a reader at: the Sheets
    # worker had an empty Run ID cell for every request it completed. The name is the run's own
    # start time in the form a batch folder uses, which is what the ledger entry is keyed by.
    $runName = '{0} {1}' -f $(if ($script:RunSportName) { $script:RunSportName } else { 'Run' }),
        $script:RunStartedUtc.ToLocalTime().ToString('dd.MM.yyyy HH-mm-ss')
    Write-Host ("Run {0}" -f $runName) -ForegroundColor DarkGray
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
    Close-RunLock
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

Close-RunLock
