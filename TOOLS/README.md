# Query Runner

`Run-Query.ps1` executes the repository's registered statements against the Content Query
Builder without opening the Pool UI. It resolves SQL by CheckID, substitutes the declared
`{{...}}` parameters, authenticates, posts one statement per execution and writes the
result to the screen, to CSV/JSON, or to a single `.xlsx` workbook.

`Test-Package.ps1` is the companion: it parses the same catalogue without sending anything
and fails when the package contradicts its own rules. Run it after changing SQL, a registry
row or a paste marker; see "Package validation" below.

`Test-Tools.ps1` tests these two scripts themselves - selection, parameter expansion, the
catalogue parser and the workbook writer. Run it after changing either script; see "Tool
tests" below.

The tools change only how a statement reaches the server. Every rule about what a
statement may contain still lives where it did:

| Question | Canonical owner |
|---|---|
| Which discovery query to select, and its parameters | `GLOBAL_QUERIES/README.md` |
| Which DQ template to select, and its parameters | `GLOBAL_DQ/README.md` |
| Confirmed per-sport parameter values | `SPORTS/params.json` |
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
| `-Sport BMX` | Discover the structural parameters and fill them in |
| `-Sport "Water Polo"` | Accept the exact database name or documented repository slug |
| `-SportSlug Water-Polo -DatabaseSportName "Water Polo"` | State both identities explicitly while opening a sport |
| `-Sport BMX -RunAll` | Everything approved for one sport, plus the patterns, in one workbook |
| `-Sport X -RunAll -IncludeUnapproved` | Discovery only for a genuinely undocumented sport: runs the GLOBAL catalogue against it |
| `BMX-DQ-003` | One check to the screen |
| `BMX-DQ-001,BMX-DQ-005` | A chosen few |
| `BMX-DQ-*` | Every match; more than one switches to batch mode |
| `-MaxChecks 10` | Cap how many matched checks actually run |
| `-Chain` | Also run the drill-downs, filled from the summaries the same run produced |
| `-ChainTop 3,2` | How many values to pursue per chain level; default 3 then 2 |
| `-ChainMax 40` | Ceiling on chained statements for the whole run |
| `-WithPatterns` | Add the round-type and name-pattern statements to the run |
| `-Preview 200` | Show more than the default 50 screen rows |
| `-OutFile .\out.csv` | Write one check to a file |
| `-OutDir .\out` | Batch target folder |
| `-Format table\|csv\|json\|xlsx` | Output shape |
| `-DryRun` | Print the SQL, or the batch selection, and send nothing |
| `-TemplateIds 44,50,65` | Narrow the run to these tournament templates |
| `-WithoutRegistryBranch` | Drop the optional sport-registry branch where a statement marks one |
| `-Sql "SELECT ..."` / `-File .\q.sql` | Ad-hoc statement |
| `-Relogin` | Discard the cached cookie and authenticate again |

### Parameters

**A sport check takes no parameters.** `POWERBI_QUERIES/<SportSlug>.sql` statements are
approved against one confirmed sport and carry its numeric ID directly, so
`BMX-DQ-003` runs on its own:

```powershell
.\TOOLS\Run-Query.ps1 BMX-DQ-003
```

`GLOBAL-DISCOVERY-NNN` and `GLOBAL-DQ-NNN` statements declare `{{...}}` tokens, because a
GLOBAL statement is reusable across sports by design. `{{SPORT_ID}}` has a dedicated switch;
every other declared token goes through `-Params`, in either form:

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

### Narrowing a run to certain templates

`-TemplateIds` restricts a run to named tournament templates:

```powershell
.\TOOLS\Run-Query.ps1 GLOBAL-DISCOVERY-* -Sport Soccer -TemplateIds 44,50,65 -Format xlsx
```

It writes no new condition. `POWERBI.md`'s scope-limiting contract already requires a
commented template filter in every branch whose audited population reaches a template, so the
flag only uncomments what the statement already declares. Because the marker is in the findings
branch and the coverage branch alike, `eligible_count` is counted over exactly the narrowed
scope, which is what the coverage contract demands.

Both the alias and the column are taken from each marker rather than assumed. Most statements
join the template layer once as `tt`, but a statement joining it twice uses `tt2`, `ttx` or
`tty`, and narrowing on `tt` alone would filter one branch while its sibling still read the
whole sport.

The column matters as much as the alias, and for a different reason. A marker sitting where the
statement already joins the tournament filters `t.tournament_templateFK`; one auditing templates
themselves filters `tt.id`. The two select identical rows and cost wildly different amounts,
because keying on the template's primary key makes the optimiser drive from the template table
and lose the index path into the statistic shards. `POWERBI.md` owns the rule; the effect is
about tenfold on the Comp.Rank checks.

**A statement carrying no marker is skipped, not run.** No marker means the audited population
has no template relation — the sport registry is the standing example — and `POWERBI.md`
forbids inventing one there. Such a statement appears as `SKIPPED: not narrowable` in the
workbook Overview, so it is visibly absent rather than silently sport-wide; running a single
one this way stops with an error instead. Run it without `-TemplateIds` and read its result as
what it is: sport-wide.

Narrowing happens after `{{...}}` expansion, so a filter may sit beside a placeholder in the
same `WHERE` clause. Applying the flag twice is a no-op: the second pass finds no marker left.

### Dropping the registry branch

`-TemplateIds` cannot narrow what has no template relation, and the sport registry has none. A
statement that reaches people through the registry **as well as** through the participation
paths therefore stays sport-wide in that one branch however tightly the rest is narrowed —
`GLOBAL-DQ-007` is the case, and a narrowed run of it would still audit every person
registered to the sport.

`-WithoutRegistryBranch` removes that branch where the statement marks it optional:

```powershell
.\TOOLS\Run-Query.ps1 GLOBAL-DQ-007 -Sport Soccer -TemplateIds 44,50,65 -WithoutRegistryBranch
```

The two flags are meant to be used together. Apart, the first narrows everything except the
registry and the second removes the registry without narrowing anything else.

A statement marks the branch by bracketing it with `-- REGISTRY BRANCH BEGIN` and
`-- REGISTRY BRANCH END`, and both the findings branch and the coverage branch must be marked
so they lose the registry together — otherwise `eligible_count` would be counted over a
population the findings never saw. `GLOBAL_DQ/README.md` owns that contract.

**A statement marking no branch is skipped, not run.** For it the registry is not one source
among several but the audited population itself, and removing it would leave nothing to audit.
`GLOBAL-DQ-009` is the standing example: its whole subject is people the registry knows and no
participation path reaches. It appears as `SKIPPED: registry-bound` in the Overview, and a
single one stops with an error.

### A result too large for one request

Some statements are correctly scoped and still return more rows than the executor can hold.
`GLOBAL-DQ-009` on Soccer is the standing case: a healthy population, a correct scope, and six
figures of findings that die in a 128 MB process. The runner cuts such a result up and merges
it back, so the check needs no manual range and no run of its own.

This answers **one** of the two failure modes `WORKFLOW.md` separates, and only that one:

| Server says | Runner does |
|---|---|
| `Allowed memory size ... exhausted` | Cuts the id range into windows and merges the pieces |
| `Request timed out` | Nothing. Reports the failure |

The asymmetry is the point. A statement that is too slow is still too slow in eight parts, and
eight of them cost eight times the scan; cutting it up would turn one honest failure into a
long run of them. Server-side cost is corrected in the statement, by narrowing the population
before it groups or sorts. `WORKFLOW.md` owns that correction.

Cutting works off the same kind of commented marker the template flag uses:

```sql
-- AND p.id BETWEEN <from_participant_id> AND <to_participant_id>
```

The runner reads the alias and column out of the marker, measures that object's live id range,
and fans out into eight windows. A window that still cannot be carried halves itself from
there, to a fixed depth. The full range is never retried once it has failed — an earlier
version did, and paid for a failed scan again at every level.

Two properties make the merged result trustworthy rather than merely convenient. The windows
partition the id space, so no object lands in two of them or in none. And the marker sits in
the coverage branch as well as the findings branch, so `eligible_count` is summed into a single
`COVERAGE` row over exactly the same population the findings were read from — the coverage
contract holds across the cut, which is why `Test-Package.ps1` fails a statement whose
top-level `UNION ALL` branches do not all carry the marker. Those two properties are exactly
what `POWERBI.md` requires before summed windows may be reported as one coverage figure, and
it owns that rule; batches a person chooses are still reported one by one.

A statement carrying no marker cannot be cut, and its failure stands as reported. That is a
statement-design problem rather than a runner limit: `POWERBI.md` requires every approved query
to carry at least one safe commented filter chosen from its own audited object, and for a
standalone object the primary-key range is that filter.

### Opening a new sport

`-Sport <name>` accepts either identity `SPORTS.md` records: the stable repository slug used
by registry rows, parameter keys, CheckIDs and output, or the exact database `sport.name` used
by live discovery SQL. Thus a documented `Water-Polo` row whose database name is `Water Polo`
works through either spelling without conflating the two. `-SportSlug` and
`-DatabaseSportName` make the pair explicit before a new sport has an index row.

It then discovers the parameters that are structural facts and fills them in, so a sport that
has never been queried needs one command:

```powershell
.\TOOLS\Run-Query.ps1 GLOBAL-DISCOVERY-* -Sport BMX -Format xlsx
```

`-Sport` resolves parameters from three sources, widest trust last:

1. an explicit `-SportId` or `-Params` on the command line;
2. the sport's entry in `SPORTS/params.json` — values already confirmed and documented;
3. live discovery against the database, for whatever the first two left empty.

Recorded values outrank discovery because the file holds evidence while discovery holds a
heuristic. When nothing discoverable is still missing, no discovery query is sent at all, so
a documented sport runs its templates without a single extra round trip:

```powershell
.\TOOLS\Run-Query.ps1 GLOBAL-DQ-* -Sport BMX -Format xlsx
```

Discovery, when it does run, is three lookups against the database, none of them assumed:

1. the mapped exact database sport name resolves to `SPORT_ID`;
2. `GLOBAL-DISCOVERY-015` reports the statistic types and owner levels the sport uses, and
   the busiest pair becomes `STATISTIC_TYPE_ID` and `STATISTIC_OWNER_TYPE_ID`. Any other
   pair is printed rather than silently dropped;
3. `SHARD_ID` is confirmed by probing each `statistic_participantsN` table, one execution
   apiece, for a statistic the inventory just attributed to this sport.

The shard is probed rather than derived because `DATABASE.md` `DB-SEM-006` records that
the statistic type does not determine the physical shard.

That covers 23 of the 31 GLOBAL statements. The remaining 8 are drill-downs whose
parameter is a value the reader picks out of a summary result — a round type, a name
pattern, a result type, a statistic data type. Choosing one automatically would produce a
sample dressed up as coverage, so they are listed and skipped instead:

```text
Skipping 8 statement(s):
  needs a value selected from a summary result (8):
    GLOBAL-DISCOVERY-019  needs ROUND_TYPE_ID
    GLOBAL-DISCOVERY-021  needs NAME_PATTERN
    ...
```

They appear in the workbook's Overview as `SKIPPED`, so a run never reads as full coverage
of the catalogue. Run them afterwards with the value chosen from its summary:

```powershell
.\TOOLS\Run-Query.ps1 GLOBAL-DISCOVERY-019 -Sport BMX -Params ROUND_TYPE_ID=5
```

An explicit `-SportId` or `-Params` always overrides a discovered value. Skipping applies
only under `-Sport` and only to a batch: elsewhere an unfilled placeholder still stops the
run, because there it is a mistake rather than a deferred choice.

### Following the drill-downs in the same run

Picking every one of those eight values by hand is a dozen further commands, each waiting on
a result read in between. `-Chain` does that walk inside one run:

```powershell
.\TOOLS\Run-Query.ps1 GLOBAL-DISCOVERY-* -Sport BMX -Chain -Format xlsx
```

Nothing here is inferred about which summary feeds which drill-down. `GLOBAL_QUERIES` already
writes the source on the placeholder's own line, in one of two forms:

```sql
AND r.result_typeFK = {{RESULT_TYPE_ID}}  -- select result_type_id from GLOBAL-DISCOVERY-007 (EVENT_RESULTS_TYPES_CODES)
-- {{ROUND_TYPE_ID}}: select round_type_id from GLOBAL-DISCOVERY-018 (EVENT_ROUND_TYPE_USAGE_SUMMARY)
```

The runner reads that declaration, takes the values the named summary ranks first — every
summary in the catalogue orders by frequency — and runs the drill-down once per value. A
statement added later chains on its own declaration; there is no pairing list to maintain,
and `TOOLS/Test-Tools.ps1` fails a drill-down that declares no source.

A source covering more than its consumer reads narrows itself in the same declaration, with a
trailing `where storage_layer = statistic_data{{SHARD_ID}}`. `GLOBAL-DISCOVERY-017` inventories
the config layer beside the data shard and orders by layer, so its config rows always lead;
`GLOBAL-DISCOVERY-028` reads the shard alone. Rows are narrowed before the source is judged, so
a run holding only the wrong layer is reported as no source rather than producing a wave of
drill-downs that can only come back empty.

Two rules keep the result honest:

- **Values are taken as whole rows, never crossed.** `GLOBAL-DISCOVERY-027` needs a result
  type and a value pattern together. Both are read from one run of `GLOBAL-DISCOVERY-026`,
  which is itself already bound to one result type, so the pairs are ones the sport reported.
  Where no single result carries every column a statement is missing, nothing is guessed: the
  statement stays `SKIPPED` and the Overview says which pair could not be found together.
- **A chained result is a sample, never coverage.** What the chain did not reach keeps a
  `SKIPPED` row of its own — `SKIPPED: 9 further value(s) of name_pattern not pursued` — so
  three tabs of one CheckID cannot be mistaken for three of three.

`-ChainTop 3,2` sets how many values each level pursues, and `-ChainMax 40` caps the run;
both report what they cut rather than quietly narrowing it. The CheckID never changes: a
chained run carries its values in the workbook's `Parameters` column, because `POWERBI.md`
makes the CheckID the identity of a statement and running one statement three times does not
make three checks.

`-Chain` applies only to `GLOBAL-DISCOVERY` statements. A DQ check short of a parameter is
short of a confirmed fact about the sport, not of a value to sample, and `POWERBI.md` does
not let one run on a guess.

### A parameter the sport can never supply

A deferred choice and an impossible one look identical to the placeholder scanner: both are
an unfilled `{{TOKEN}}`. They are not the same thing, and reporting them alike sends the
reader to the sport file to find out which is which. A sport records the difference in its
`SPORTS/params.json` entry, under one of the two keys that are not themselves parameters:

```json
"Triathlon": {
  "SPORT_ID": 50,
  "_notApplicable": {
    "NUMERIC_RESULT_TYPE_LIST": "no result type carries a measured quantity; every confirmed type is a place, a time, a status vocabulary or a medal code"
  }
}
```

The reason travels with the skip, in the run output and in the workbook's Overview:

```text
Skipping 2 statement(s):
  not applicable to this sport (1):
    GLOBAL-DQ-076  NUMERIC_RESULT_TYPE_LIST - no result type carries a measured quantity; ...
  needs a value selected from a summary result (1):
    GLOBAL-DQ-019  needs RESULT_TYPE_ID
```

One impossible parameter is enough to classify a statement as not applicable, because one is
enough to make it permanently unrunnable for that sport. `Test-Package.ps1` holds the block
to its contract: every key is a parameter name, every reason is non-empty, no parameter is
both recorded and declared impossible, and no `Approved` registry row instantiates a template
whose parameter the sport has declared it cannot supply.

Record a parameter here only after the sport file documents why. The block is the runner's
copy of a conclusion, never the place the conclusion is reached.

### What a check's findings are worth for this sport

The other reserved key is `_checkSignal`. It is not the same condition as the one above and
must not be confused with it: there, a parameter is missing and the statement cannot run.
Here every parameter **is** recorded, the statement runs, and what is in doubt is whether its
findings are defects.

Three values are recordable. `Actionable` is the default and is never written down — a fourth
value on every check would make the block a second copy of the registry. `Deprecated` is
deliberately not a signal: `POWERBI_REGISTRY.md`'s `Status` column owns it, and a value with
two owners drifts.

| Signal | Means | Enforced as |
|---|---|---|
| `Monitor` | Real, but population-wide. The proportion is the finding; a single row is not a defect | Must have an `Approved` row — it describes a check that runs |
| `Not applicable` | The sport has nothing for the check to read, so it reports the whole population | No row requirement, either way |
| `Blocked` | Would report the sport's normal shape as a defect until something else is fixed first | Must **not** have an `Approved` row — it says "not yet" |

`Blocked` and `Not applicable` are easy to confuse and the difference matters: a block lifts
when the underlying data is fixed, and the check is then approved. `Not applicable` does not
lift, because the structure it reads is one the sport does not have. Recording a permanent
absence as `Blocked` promises a review that will never come.

**A signal is read off the structure, never off the current population.** A sport that stores
no such column, no such layer and no such relation is `Not applicable`. A sport that stores
all three but holds no row carrying that value today is not: it is a sport whose check
returns nothing, which is the check working. The distinction is the whole point of writing
one. A status, a type or a value absent this morning can arrive with the next import, and a
check classified away on a row count is precisely the check that will stay silent when it
does — the arrival it existed to catch becomes the thing it can no longer see. "Zero rows
returned" and "nothing to read" are different findings and are never interchangeable. When it
is not clear which of the two applies, ask rather than classify: an unclassified check keeps
running, and running is the safe default.

`Not applicable` carries no row requirement in either direction on purpose. A check the sport
should never have is usually simply unapproved, but the cases where one *was* approved are
exactly the ones worth being able to write down — and deprecating it is a separate decision,
recorded in `POWERBI_REGISTRY.md`.

```json
"Curling": {
  "SPORT_ID": 10,
  "_checkSignal": {
    "GLOBAL-DQ-058": {
      "signal": "Not applicable",
      "reason": "lineups are used but are not this sport's membership mechanism: only a small minority of team event participants carry a Starter lineup... SPORTS/Curling.md names this check directly."
    }
  }
}
```

Keys name either a `GLOBAL-DQ-NNN` template the sport instantiates or one of the sport's own
CheckIDs, and every entry carries a non-empty reason.

Selection does not depend on the block: a `Blocked` template has no row, so it is not selected
either way, and a `Monitor` or `Not applicable` check is approved and still runs. What it buys
is that a conclusion already written in a sport file stops being invisible to the run that
contradicts it. `-RunAll` names the blocked templates among what it left out and the classified
checks among what it is about to run, each with its reason. `Signal` and `Signal reason` also
survive in the workbook Overview and flat `_summary.csv`, so the classification is not lost
with the terminal. The same hydration applies to direct `GLOBAL-DQ-* -Sport <sport>` batches,
not only `-RunAll`; `Test-Package.ps1` enforces the table above.

The sport file still owns the reasoning; this is the machine-readable half of it. A signal is
a description of the check's output, not a decision about its future — deprecating a check is
a separate act, recorded in `POWERBI_REGISTRY.md`.

On a sport with a large event or statistic volume, run a capped batch first —
`-MaxChecks 8` — and read what it costs before letting the whole catalogue go.

### Patterns alongside a DQ run

A DQ finding is read against the names and round types the sport actually uses, so
`-WithPatterns` carries both in one workbook:

```powershell
.\TOOLS\Run-Query.ps1 GLOBAL-DQ-* -Sport BMX -WithPatterns -Format xlsx
```

Which statements qualify is derived from their parameters rather than listed by ID: every
`GLOBAL_QUERIES/PATTERNS.sql` statement whose placeholders `-Sport` can supply — the sport
ID, the statistic type and owner, the physical shard. Today that is the four summaries,
`018`, `020`, `022` and `024`. A pattern statement added later needs no change here; it is
picked up or left out on its own parameters.

Note that `024` is included although it declares more than `SPORT_ID`: it also needs
`STATISTIC_TYPE_ID` and `STATISTIC_OWNER_TYPE_ID`, and those are structural facts `-Sport`
resolves from `SPORTS/params.json` or discovers. What decides is whether a parameter can be
resolved without a human reading a result, not how many there are.

A drill-down is deliberately left out on the same test. Its parameter is a round type, a
name pattern or a result type — a value picked out of a summary — and choosing one
automatically would produce a sample dressed up as coverage. Run it afterwards by the
normal path, with the value chosen from its summary:

```powershell
.\TOOLS\Run-Query.ps1 GLOBAL-DISCOVERY-021 -Sport Triathlon -Params NAME_PATTERN="Triathlon"
```

Anything the run already matched is not added twice, and the switch applies after
`-MaxChecks`, because the cap exists to trim the matched set while these were asked for by
name. Without `-Sport`, an unfilled placeholder stops the run as it always does.

### Everything for one sport

```powershell
.\TOOLS\Run-Query.ps1 -Sport Triathlon -RunAll
```

One command for the sport's whole approved catalogue: every check `POWERBI_REGISTRY.md`
records as `Approved` for it, plus the pattern statements, collected into one workbook under
the output root. It implies `-WithPatterns` and `-Format xlsx`; an explicit `-Format`,
`-OutDir` or `-MaxChecks` still wins.

**The registry decides what runs, and the row's `Query file` decides how.** A `GLOBAL_DQ/`
path means the row instantiates its `Family`, so the template's statement runs; anything else
means the sport authored its own, and the row's own CheckID names it. Three things follow,
and each one was a real defect while the selection was read from the `.sql` files instead:

- a template with no row for this sport does not run — a template is not a check for a sport
  until that sport has a row for it, and `POWERBI.md` owns that rule;
- a `Deprecated` row does not run, while keeping its reserved CheckID;
- a sport that replaced a template with its own statement runs that statement **instead of**
  the template, not alongside it.

Results carry the sport's CheckID rather than the template's, because that is what
`POWERBI_REGISTRY.md` makes the stable identifier for PowerBI and any external report. Two
sports instantiating one template would otherwise both report the template ID.

The run says what it left out: how many templates are not approved for this sport, which
CheckIDs are deprecated, and any template `SPORTS/params.json` records as blocked, with the
reason. A shorter workbook than the catalogue is then explained rather than left to be
counted. It also names the checks it *is* running whose findings that file classifies as
something other than defects — see "What a check's findings are worth for this sport".

A template the sport cannot fill — because a parameter is not recorded for it — is still
listed as `SKIPPED` in the Overview exactly as under any other batch, so the workbook never
reads as full coverage when it is not.

### An undocumented sport

```powershell
.\TOOLS\Run-Query.ps1 -Sport "Artistic Gymnastics" -RunAll -IncludeUnapproved
```

A sport with no registry row has nothing approved, so plain `-RunAll` stops and says so.
`-IncludeUnapproved` runs the GLOBAL catalogue against it anyway, which is how a sport is
opened. It is accepted only when no sport-index row, sport file, parameter entry, registry row
or sport SQL file already names that slug. On a documented sport it stops instead of bypassing
an approval, blocked signal or deprecated row. The allowed output is discovery evidence,
never a DQ result: nothing it ran is approved for the sport. The run labels itself accordingly.

What a run produces is execution output, never evidence. `WORKFLOW.md` "Starting a new
sport" owns the sequence around these commands: which drill-downs to run, how a confirmed
finding reaches `SPORTS.md` and the sport file, and when DQ work may begin.

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

| Sport | CheckID | Parameters | Check Name | Priority | Category | What it does | Rows | Status | Check By | Signal | Signal reason |
|---|---|---|---|---|---|---|---:|---|---|---|---|
| BMX | BMX-DQ-001 | | PARTICIPANT_MISSING_DATE_OF_BIRTH | 3 Missing value | MISSING_VALUES | Finds active participants of the selected types that … | 1064 | Not reviewed | | Monitor | Population-wide absence … |

`Signal` and `Signal reason` are columns K and L, and the workbook ships with both hidden.
They are the runner's own classification, settled before the run and unchanged by reading
it, so the reviewer opens on the columns that are theirs to work through. Nothing is
dropped: unhiding K:L brings back every value, and both still travel in `_summary.csv`.

`Parameters` is empty for almost every row and fills only under `-Chain`, where one statement
runs once per value it was fed. Those runs share a CheckID by design — the CheckID identifies
the statement, not the execution — so `Parameters` is what tells them apart, and it is also
where a `SKIPPED` row records the values the chain did not pursue.

`Category` is the row's own `Category` from `POWERBI_REGISTRY.md`, and `Priority` is the
band `POWERBI.md` derives from it — `1 Structure`, `2 Wrong value`, `3 Missing value`. The
numeric prefix means sorting the column produces the working order rather than an
alphabetical one. Both are empty for a statement no registry row names: a direct template
run and a discovery statement have no category to band, and the runner leaves them blank
rather than inventing one.

Every check appears, including those that returned nothing or failed and therefore have
no tab of their own. `Sport` is taken from the CheckID prefix. `What it does` is the
statement's own `-- What it does:` line, carried through the run so a reader can see what
a check asserts beside what it found, without going back to the registry for it.

`Signal` says what the output is worth before anyone reads it. It defaults to `Actionable`,
and a sport's `_checkSignal` block records the exceptions with their reasons:

| Signal | What it says |
|---|---|
| `Actionable` | every row names something that can be corrected |
| `Monitor` | real, but population-wide, or mixed with legitimate shapes: a human sorts them |
| `Informational` | nothing here is correctable — the output describes a state |
| `Blocked` | would report the sport's normal shape as a defect; not to be approved yet |
| `Not applicable` | measures a layer or mechanism this sport does not use |

`Informational` is the one value the runner also assigns on its own: every `GLOBAL-DISCOVERY`
statement carries it without a sport saying so. Discovery is a census by construction, and a
row of it is a category with a count — nobody can correct `round type 9, 412 events` the way
they can correct a missing date of birth. The distinction from `Monitor` matters in the other
direction too: a `Monitor` check still has work in it, so labelling one informational would
tell the reviewer to skip a tab that needs them.

`Rows` is the count the console printed, and doubles as the jump to that check's tab. A
check that failed shows `ERROR` instead, so it cannot be misread as a clean zero, and is
left unlinked because it has no tab; the reason is on the console and in `_summary.csv`,
along with the durations.

`Status` is a manual tracking field. Its dropdown names outcomes rather than stages of work,
because "completed" hides the only thing the next reader needs — completed with what result:

| Open | Closed |
|---|---|
| `Not reviewed`, `Reviewing`, `On hold` | `No issue`, `Reported to IT`, `Fixed`, `No action needed` |

`No action needed` is the reviewer's counterpart to the `Informational` signal: the check ran,
it was read, and there was never anything in it to act on.

Two of those the workbook settles itself, so a reviewer opens on the rows that actually want
reading:

| Seeded as | When |
|---|---|
| `No action needed` | the signal is `Informational` — nothing in the output is correctable |
| `No issue` | the check returned exactly one row, its `COVERAGE` row, **and that row counts a population above zero** |
| `Not reviewed` | everything else |

The one-row rule is the coverage contract read back: every DQ statement returns a `COVERAGE`
row whether or not it has findings, so a result of exactly one row *is* the statement saying
it found none.

**The row count alone cannot say that, which is the whole reason the contract exists.** A
statement that audited nothing returns the same single row as one that found nothing wrong.
Only the `eligible_count` inside it separates them, and `CLAUDE.md` is explicit that a zero
there is never clean data — it is either a misdirected scope to correct or a population that
is legitimately empty today, and both want a person. So the runner reads the value out of the
`COVERAGE` row rather than counting rows, never seeds a zero-coverage check closed, and names
those checks on the console when a run finishes:

```text
2 check(s) audited nothing - eligible_count is 0, which is never clean data: BMX-DQ-014, BMX-DQ-031
```

A check that failed or was skipped is never seeded closed either, whatever its signal — it
reports one cell too, holding `ERROR` rather than a coverage count, and a closing status would
assert that somebody read an output that does not exist.

`Check By` is a second manual field, written as a heading over empty cells and free text.
Nothing in the runner reads either back.

Then one tab per check:

```text
     A                B                   C          D                E                F                G          H          I          J                K
1    Check ID         Check Name          SQL Used   Priority         Category         What it does     Comment    Check By   Signal     Signal reason    Parameters
2    BMX-DQ-001       PARTICIPANT_MIS...  SQL        3 Missing value  MISSING_VALUES   Finds active ...                       Monitor    Population-wide…
3    Return to Overview
4
5    check_type       participant_id      participant_name   ...
6    Missing_DOB      1473234             Jude Jones         ...
```

The identity sits on rows 1 and 2 rather than on every data row. Row 3 holds the link back
to Overview, and row 4 is blank so the result table below stays a self-contained block for
sorting and filtering.

C2 reads `SQL` and jumps to the statement, which lives on the `SQL` tab at the end of the
workbook rather than in the cell. It used to be the statement itself, collapsed onto one
line: a cell of a few thousand characters that nothing could display, and that pushed the
result table out of shape the moment somebody opened it. On the `SQL` tab each statement
keeps the line breaks it was written with, one line per row, and its first cell jumps back
to the results it produced.

`Comment` and `Check By` are written as headings and nothing else: both columns belong to
whoever reads the workbook, and the runner never puts a value in either. `Priority`,
`Category`, `What it does`, `Signal` and `Signal reason` beside them are the same values the
Overview carries, so a tab opened from a link explains itself without the reader going back.
Unlike the Overview, a check tab leaves the signal fields visible — there are only two of
them on a row that is already about one check.

`SQL Used` stays at C on a check tab, because C2 is where the jump to the statement lives.
That is why `Parameters` is appended at K here while it sits at C on the Overview: inserting
it would have taken the statement link with it. On the Overview, `Rows` links from column H,
the `Status` dropdown binds to I, and the hidden signal pair is K:L. A change to these
positions is a change to three places at once — the row builder, the validation `sqref`, and
the assertions in `Test-Tools.ps1` that pin them.

**A linked cell in Google Sheets is labelled from the hyperlink record, not from its own
value.** With a `display` attribute Sheets shows that text; without one it falls back to
the raw `#gid=...` target. So `display` carries the label the cell should read, and must
never be set to the location — that was the original defect, and removing the attribute
only traded one wrong label for another. Excel takes its label from the cell value, which
is written identically, so the two agree.

This is what lets `Rows` be both a number and a link: its `display` is the row count. Any
new link must set `display` to whatever the cell is meant to read.

### Tab names

Check names routinely run past Excel's 31-character tab limit, and they differ in their
suffix, so plain truncation hides the distinguishing part: `..._DATE_RANGE_MISMATCH_STAGE`
and `..._DATE_RANGE_MISMATCH_EVENTS` used to collapse onto the same tab name. Recurring
object and condition words are therefore abbreviated first — `PARTICIPANT` to `PTC`,
`COMP.RANK` to `CR`, `MISSING` to `MISS`, and so on — which leaves
`CR_SET_DATE_RANGE_MISM_STG` and `CR_SET_DATE_RANGE_MISM_EVENTS` distinct.

Abbreviating first leaves the great majority of names inside the limit with every tab name
still unique, where plain truncation collapsed dozens of them. The map lives in
`$XlsxNameAbbreviations` in the script; extend it when a new recurring word appears. A name
that still overruns is cut and reported at the end of the run, and duplicates gain a `~2`
suffix. The full name is always in the Overview and in B2.

Catalogue sizes are deliberately not quoted here: `-ListChecks` reports the current count,
and a hand-maintained number in prose drifts the moment a sport is added.

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
  is retried automatically, with one exception: a result too large is cut into id windows
  and merged, as described under "A result too large for one request".
- Statements are sent one at a time with a short pause between them.
- Row counts and durations are printed per check as the run proceeds. `_summary.csv` keeps
  both, the `Signal` and `SignalReason`, plus the server's message for a failure; the
  workbook's Overview tab keeps the same signal metadata and row count and marks a failure
  `ERROR`.

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

1. it lives in a `.sql` file under `GLOBAL_QUERIES/`, `GLOBAL_DQ/` or `POWERBI_QUERIES/` —
   no other directory is scanned;
2. statements are separated by the `-- =====...` banner lines used across the repository;
3. it carries `-- CheckID - <id>`, and preferably `-- Name - <NAME>`, which becomes the
   workbook tab name.

Adding `POWERBI_QUERIES/<NewSport>.sql` therefore needs no change to the runner:
`<NewSport>-DQ-*` works immediately.

A sport that runs GLOBAL DQ templates instead needs no `.sql` file at all — only its entry
in `SPORTS/params.json` and its registry rows. Run the templates directly:

```powershell
.\TOOLS\Run-Query.ps1 GLOBAL-DQ-* -Sport Curling -Format xlsx
```

A GLOBAL CheckID names the catalogue it lives in, not what it was run against, so under a
sport identity the resolved repository slug is what the Overview's `Sport` column and the run
folder are named after. The exact database name is used only to resolve live SQL. Without a
sport identity there is nothing better to fall back on and both read `GLOBAL`.

## Package validation

```powershell
.\TOOLS\Test-Package.ps1
```

Parses every `.sql` file and registry in the repository and reports one line per check:
identity headers, CheckID uniqueness, the DQ coverage contract, `UNION ALL` column counts,
result-level `LIMIT`, registry-versus-SQL agreement, declared parameters, paste markers,
registry row order, the sport index and `SPORTS/params.json`. Exit code 1 on any failure, so
it drops into a hook or a pre-commit step unchanged.

`POWERBI_REGISTRY.md` declares that its rows sort by Sport and then by CheckID, so the order
is checked rather than left to whoever appends the next row. Only the first displaced row is
reported: one row in the wrong place shifts every row after it. A blank line between two rows
is reported separately, because it splits the rendered table in two while the row scanner
reads straight past it.

It needs no credentials and sends nothing, because it parses rather than executes. That is
also its boundary: it cannot prove live permissions, runtime cost or result semantics.

`-ReportPath` refreshes the tracked report:

```powershell
.\TOOLS\Test-Package.ps1 -ReportPath .\VALIDATION_REPORT.md
```

`VALIDATION_REPORT.md` is generated output. Fix the script or the package, never the report.

## Tool tests

```powershell
.\TOOLS\Test-Tools.ps1
```

`Test-Package.ps1` proves the package is consistent; this proves the two scripts that read it
behave as documented. It covers which checks `-RunAll` and a wildcard select, the slug-to-DB
name mapping and undocumented-sport guard, how `{{...}}` parameters are filled, how the
catalogue is parsed out of the banner-separated `.sql` files, and what the workbook and flat
summary writers emit. Focused SQL assertions also pin previously observed coverage and
join-fan-out regressions in the approved checks. The registry order rule is tested by breaking
a throwaway copy of the repository and requiring the validator to catch it, so the rule cannot
quietly stop biting.

There is no Pester dependency. Windows PowerShell 5.1 ships Pester 3.4, whose syntax differs
from every current version, so a suite written against either one fails on the other machine.
The harness is the same `Group / Name / Status` shape `Test-Package.ps1` prints, and exits 1
on any failure.

Nothing here touches the network: `Run-Query.ps1` is dot-sourced with `-DotSourceOnly`, which
runs its prologue and stops before `Main`. That switch exists for this file and for nothing
else.

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
