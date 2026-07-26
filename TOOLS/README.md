# Query Runner

`Run-Query.ps1` executes the repository's registered statements against the Content Query
Builder without opening the Pool UI. It resolves SQL by CheckID, substitutes the declared
`{{...}}` parameters, authenticates, posts one statement per execution and writes the
result to the screen, to CSV/JSON, or to a single `.xlsx` workbook.

The tool changes only how a statement reaches the server. Every rule about what a
statement may contain still lives where it did:

| Question | Canonical owner |
|---|---|
| Which query to select, and its parameters | `GLOBAL_QUERIES/README.md` |
| Scope, cost, `LIMIT` and failure handling | `WORKFLOW.md` |
| DQ identity, coverage and approval | `POWERBI.md` |

## Requirements

- Windows PowerShell 5.1 or later. Nothing else is installed: the workbook writer emits
  OOXML directly, so neither Excel nor the `ImportExcel` module is needed.
- Network access to the Content Query Builder host.
- An account for that application.

## Setup on a new machine

### 1. Clone the repository

```powershell
git clone https://github.com/iNfRaS0NiC/entpulse_quality_database.git
cd entpulse_quality_database
```

### 2. Allow local scripts to run

Windows blocks `.ps1` files under its default `Restricted` policy. Once per user:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

To avoid changing the machine, prefix each call instead:

```powershell
powershell -ExecutionPolicy Bypass -File .\TOOLS\Run-Query.ps1 -ListChecks
```

### 3. Supply credentials

Create `TOOLS/secrets.local.ps1`. The script dot-sources it automatically when present,
and `.gitignore` excludes `*.local.ps1`, so it never reaches the repository.

```powershell
$env:EP_QB_EMAIL = 'you@enetpulse.com'
$env:EP_QB_PASSWORD = 'your-password'

# Instead of the login, a live browser session copied from DevTools:
# Network -> execute-sql -> Copy as cURL -> the value after -b
# $env:EP_QB_COOKIE = 'XSRF-TOKEN=...; content-query-builder-session=...'

# A different Content Query Builder instance:
# $env:EP_QB_URL = 'http://spcdev.enetpulse.com:19080'

# Where result files are written. Default: D:\SQL's Output
# $env:EP_QB_OUTPUT = 'C:\SQL Output'
```

Every value may come from the environment instead. The file simply saves typing. When
both the email and the password are missing, the script prompts for them.

The default server is `http://spcdev.enetpulse.com:19080`; `EP_QB_URL` overrides it.

### 4. Verify

```powershell
.\TOOLS\Run-Query.ps1 -ListChecks
```

This reads only local `.sql` files, so it proves the catalogue is found before any
credential is used. Then run one real statement:

```powershell
.\TOOLS\Run-Query.ps1 BMX-DQ-003
```

If the machine has no `D:` drive, set `EP_QB_OUTPUT` to where results should be written
before running anything that produces files; see "Where results are written".

### 5. Optional: call it from anywhere

Define a wrapper in your PowerShell profile (`$PROFILE.CurrentUserAllHosts`, created if
absent) so the runner works from any directory under a short name:

```powershell
$EntpulseQueryRunner = 'D:\path\to\entpulse_quality_database\TOOLS\Run-Query.ps1'

function cqb {
    $env:EP_QB_COMMAND = 'cqb'
    if ($args.Count -ge 1 -and "$($args[0])" -eq 'info') {
        & $EntpulseQueryRunner -Info
        return
    }
    & $EntpulseQueryRunner @args
}
```

Rename the function to rename the command, and keep `EP_QB_COMMAND` matching so the
built-in help shows the name you actually type. The profile also needs the execution
policy from step 2.

## Command set

`Run-Query.ps1 -Info` prints the full set with live values — server, catalogue size and
the account in use. The summary:

| Form | Effect |
|---|---|
| `-ListChecks` | Every CheckID with its name, source file and line |
| `-ListChecks BMX-DQ-0*` | The same list, filtered by wildcard |
| `BMX-DQ-003` | One check to the screen |
| `BMX-DQ-001,BMX-DQ-005` | A chosen few |
| `BMX-DQ-*` | Every match; more than one switches to batch mode |
| `-MaxChecks 10` | Cap how many matched checks actually run |
| `-Preview 200` | Show more than the default 50 screen rows |
| `-OutFile .\out.csv` | Write one check to a file |
| `-OutDir .\out` | Batch target folder |
| `-Format table\|csv\|json\|xlsx` | Output shape |
| `-DryRun` | Print the SQL, or the batch selection, and send nothing |
| `-Sql "SELECT ..."` / `-File .\q.sql` | Ad-hoc statement |
| `-Relogin` | Discard the cached cookie and authenticate again |

### Parameters

**A sport check takes no parameters.** `POWERBI_QUERIES/<SportSlug>.sql` statements are
approved against one confirmed sport and carry its numeric ID directly, so
`BMX-DQ-003` runs on its own:

```powershell
.\TOOLS\Run-Query.ps1 BMX-DQ-003
```

Only `GLOBAL-DISCOVERY-NNN` statements declare `{{...}}` tokens, because a GLOBAL query is
reusable across sports by design. `{{SPORT_ID}}` has a dedicated switch; every other
declared token goes through `-Params`, in either form:

```powershell
.\TOOLS\Run-Query.ps1 GLOBAL-DISCOVERY-001 -SportId 58

.\TOOLS\Run-Query.ps1 GLOBAL-DISCOVERY-016 -SportId 58 `
    -Params STATISTIC_TYPE_ID=11,STATISTIC_OWNER_TYPE_ID=3,SHARD_ID=11

.\TOOLS\Run-Query.ps1 GLOBAL-DISCOVERY-016 -SportId 58 `
    -Params @{ STATISTIC_TYPE_ID = 11; STATISTIC_OWNER_TYPE_ID = 3; SHARD_ID = 11 }
```

An unreplaced token stops the run before anything is sent, and the error names the
missing tokens. A parameter passed to a statement that declares none is simply unused.
Parameter meanings are declared in `GLOBAL_QUERIES/README.md`; the runner substitutes them
textually and validates nothing about their values.

## Output

### Screen

The default. The header line names the check, and only the first `-Preview` rows print.

### CSV and JSON

Every row is prefixed with `check_id` and `check_name`, because a flat file has nowhere
else to record which check produced it. Files are named after the CheckID —
`BMX-DQ-003.csv`.

### Workbook

`-Format xlsx` collects a whole batch into one file, which is the shape to upload to
Google Drive and open as Sheets.

`Overview` is the first tab:

| Sport | CheckID | Check Name | Rows |
|---|---|---|---:|
| BMX | BMX-DQ-001 | PARTICIPANT_MISSING_DATE_OF_BIRTH | 1064 |

Every check appears, including those that returned nothing or failed and therefore have
no tab of their own. `Sport` is taken from the CheckID prefix. `Rows` is the count the
console printed, as a number. A check that failed shows `ERROR` instead, so it cannot be
misread as a clean zero; the reason is on the console and in `_summary.csv`. Durations
stay on the console and in `_summary.csv`.

Then one tab per check, named after its `-- Name -` header:

```text
     A                  B                    C
1    Check ID           Check Name           SQL Used
2    BMX-DQ-001         PARTICIPANT_MIS...   SELECT 'Missing_DOB' AS check_type, ...
3    Back to Overview
4
5    check_type         participant_id       participant_name   ...
6    Missing_DOB        1473234              Jude Jones         ...
```

The identity sits on rows 1 and 2 rather than on every data row. Row 3 holds the only link
in the workbook, back to Overview, and row 4 is blank so the result table below stays a
self-contained block for sorting and filtering.

**No cell holding data is ever a link.** Google Sheets rewrites an imported internal link
into a `HYPERLINK` formula whose visible label is the link target, replacing whatever the
cell contained. Excel does not, which makes this easy to miss. Navigation therefore runs
one way only, from a dedicated cell whose text is expendable.

C2 holds the statement on a single line. Its newlines would otherwise make the row as tall
as the whole query and push the sheet out of shape. Collapsing them requires the SQL
comments to be removed first — everything after a `--` would otherwise be commented out —
so the cell holds a comment-free one-line form that still runs when copied out. The
formatted original stays in the repository `.sql` file.

Two format limits apply. Tab names are capped at 31 characters, so longer check names are
truncated and the run reports which ones; the full name remains in B2 and in the Overview.
A cell cannot exceed 32 767 characters, so an unusually long statement in C2 is trimmed
with a `...[truncated]` marker.

## Where results are written

Results are kept outside the working copy. Every run gets its own folder, named after the
sport and the moment it started:

```text
D:\SQL's Output\BMX 26.07.2026 09-09-47\BMX.xlsx
D:\SQL's Output\GLOBAL 26.07.2026 09-10-24\GLOBAL-DISCOVERY-001.csv
D:\SQL's Output\MIXED 26.07.2026 09-10-25\...
```

The sport comes from the CheckID prefix; a run mixing prefixes is `MIXED`. The run time
uses hyphens rather than colons because Windows rejects `:` in a path.

`EP_QB_OUTPUT` overrides the root. On a machine without a `D:` drive the runner falls
back to `output\` inside the repository, which `.gitignore` excludes. `-OutDir` and
`-OutFile` override the whole scheme for one run.

## Batch behaviour

More than one matched CheckID switches to batch mode.

- Per-file formats write one file per CheckID plus `_summary.csv`; a workbook writes one
  `<Sport>.xlsx`.
- A failing check is recorded as `ERROR: <server message>` and the run continues. Nothing
  is retried automatically.
- Statements are sent one at a time with a short pause between them.
- Row counts and durations are printed per check as the run proceeds. `_summary.csv` keeps
  both, plus the server's message for a failure; the workbook's Overview tab keeps the row
  count and marks a failure `ERROR`.

A batch inherits the cost constraints in `WORKFLOW.md`. Running the whole catalogue for a
large sport can time out check by check; narrow the scope in the statement rather than
expecting the runner to compensate.

## Authentication

Resolved in this order:

1. `EP_QB_COOKIE`, when set.
2. The cached session in `%LOCALAPPDATA%\entpulse-qb\session.xml`.
3. A form login with `EP_QB_EMAIL` and `EP_QB_PASSWORD`, prompting for whatever is
   missing.

The cookie is cached after a successful call and reused until the server rejects it. On
HTTP 401, 403 or 419 the runner discards the cache, logs in again and retries the
statement once. `-Relogin` forces that path.

The "Unlock SQL" button in the Pool UI is a front-end guard on the text area. The
execute-sql route is separate, so it has no effect on the runner.

## New sports and queries

The catalogue is read from disk on every invocation; nothing is cached or registered. A
new statement is picked up as soon as three conditions hold:

1. it lives in a `.sql` file under `GLOBAL_QUERIES/` or `POWERBI_QUERIES/` — no other
   directory is scanned;
2. statements are separated by the `-- =====...` banner lines used across the repository;
3. it carries `-- CheckID - <id>`, and preferably `-- Name - <NAME>`, which becomes the
   workbook tab name.

Adding `POWERBI_QUERIES/<NewSport>.sql` therefore needs no change to the runner:
`<NewSport>-DQ-*` works immediately.

## Troubleshooting

| Symptom | Cause |
|---|---|
| `cannot be loaded because running scripts is disabled` | Execution policy; see setup step 2 |
| `Login failed for '<email>': <reason>` | The server's own validation message, verbatim |
| `Query failed (HTTP 500): SQL must start with SELECT!` | The server accepts only `SELECT`/`WITH` |
| `Query failed (HTTP 500): SQLSTATE[...]` | The MySQL error for the statement, verbatim |
| `Missing parameter value(s): X` | A declared `{{X}}` token had no value. Only GLOBAL statements declare tokens |
| `No CheckID matches 'X'` | Wrong ID or pattern; check `-ListChecks` |
| `Request timed out` / `Allowed memory size ... exhausted` | Query-design failures. `WORKFLOW.md` owns the correction |

## Not in git

`TOOLS/secrets.local.ps1` and everything under `output/` are excluded by `.gitignore`.
Never commit credentials, and never paste a session cookie into a tracked file.
