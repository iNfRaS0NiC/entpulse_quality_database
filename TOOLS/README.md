# Query Runner

`Run-Query.ps1` executes the repository's registered statements against the Content Query
Builder without opening the Pool UI. It resolves SQL by CheckID, substitutes the declared
`{{...}}` parameters, authenticates, posts one statement per execution and writes the
result to the screen, to CSV/JSON, or to a single `.xlsx` workbook.

`Test-Package.ps1` is the companion: it parses the same catalogue without sending anything
and fails when the package contradicts its own rules. Run it after changing SQL, a registry
row or a paste marker; see "Package validation" below.

`Sheets.ps1` computes what a run would write into the live per-sport Google Sheet. It is
dot-sourced by the runner and sends nothing itself; see "The live per-sport document".

`Connect-Sheets.ps1` is the one-time Google authorisation for that document. It is the only
interactive script in the package: it opens a browser, waits for a person, and is meant to be
run once per machine and forgotten.

`Test-Tools.ps1` tests these scripts themselves - selection, parameter expansion, the
catalogue parser, the workbook writer and the sheet merge. Run it after changing any of them;
see "Tool tests" below.

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
| `-History BMX-DQ-003` | Every recorded run of a check, oldest first |
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
| `-DataType rank` / `-DataType 100` | Narrow the run to the checks that read a stored value type |
| `-WithoutRegistryBranch` | Drop the optional sport-registry branch where a statement marks one |
| `-Sql "SELECT ..."` / `-File .\q.sql` | Ad-hoc statement |
| `-TestRun` | A run that leaves no trace: results written under `TEST …`, nothing recorded |
| `-SheetId 1qyz…` | The live per-sport document to update. Needed once; remembered afterwards |
| `-SheetTitle "…"` | What to call it, used only while it is still `Untitled spreadsheet` |
| `-NoSheet` | Record the run, but leave the live document alone |
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

### The client boundary, and which way round a sport declares it

`{{OUT_OF_SCOPE_TEMPLATE_ID_LIST}}` is what every statement reads: the templates the client
does not take. A sport may put that list in `SPORTS/params.json` directly, or may declare
`IN_SCOPE_TEMPLATE_ID_LIST` instead — the templates the client **does** take — and let the
runner compute the complement before anything is sent.

Which way round is not a preference. It decides what happens to a template the sport gains
next season, and the two answers are opposite: an exclusion list leaves it inside the client's
boundary, an inclusion list leaves it outside. So the rule is to declare whichever list is the
short one, because that is also the one whose default is right.

Golf's client takes 16 templates of 36. Naming the 20 it does not take is the shorter list, and
a golf template added later is probably one the client does want, so the exclusion is both
readable and correctly defaulted. Ice Hockey's client takes 25 of 112 — every national-team
competition, no club league at all. Naming the other 87 would be a list nobody can read, the
sport gains templates most seasons, and each one would arrive inside the boundary without
anybody deciding it. One new league the size of the KHL is 17,669 events against the 9,803 the
client asked for, and nothing would fail.

Declaring both is refused rather than resolved by precedence: they say one thing twice and
would disagree the first time either was edited. The run reports what it derived:

```
Resolving parameters for 'Ice-Hockey' (database sport 'Ice Hockey')...
  OUT_OF_SCOPE_TEMPLATE_ID_LIST  25 of 112 template(s) in scope; 87 excluded  (derived from IN_SCOPE_TEMPLATE_ID_LIST)
```

An id that no active template of the sport carries stops the run. The complement is computed
by exclusion, so an id belonging to nothing removes nothing, and a typo would widen the client's
boundary rather than narrow it — silently, which is the one way this must not fail.

A sport declaring the inclusion writes an inclusion into its own `POWERBI_QUERIES/<Sport>.sql`
statements too, since a sport check carries no tokens. `TOOLS/Test-Package.ps1` checks that the
ids there match `SPORTS/params.json`, and that the statements did not write the complement
instead — which would put the wrong default back where nobody would look for it.

**One exception, added 2026-08-28, for a statement the including form cannot execute.** A
selective `IN` over a short list can make the optimiser drive from `tournament` and lose the
index path into the statistic shards — the same failure `DB-SEM-016` describes for `tt.id`,
arriving from a different direction. Where that happens the server does not return slowly, it
gives up: `Handball-DQ-062` timed out at the gateway on five rewrites — the filter written
directly, moved after the aggregation, with the coverage branch rebuilt as a derived table,
with `STRAIGHT_JOIN` pinning the driving table, and with the joins reversed to drive from
`statistic_data11` — and returned in 14.3 seconds the moment the same filter was written as the
complement.

Such a statement may write the complement, and it declares that it is doing so:

```sql
-- CLIENT BOUNDARY EXCLUDING FORM: <why the including form does not execute, measured>
-- IN SCOPE: 363, 364, 380, ...
```

`Test-Package.ps1` then checks what it still can: the `IN SCOPE` line must equal
`IN_SCOPE_TEMPLATE_ID_LIST` exactly, every branch that can reach a template must still carry a
boundary line, and the excluded list must not hold a single template the client takes. A
statement claiming the exception without the `IN SCOPE` line fails, because its ids would be
comparable with nothing.

What the exception cannot protect is the reason the including form is the rule: **a template
the sport gains next season is outside the inclusion and inside such a statement.** No checker
sees that, because the repository does not hold the sport's template inventory. So the marker
text is required to say it, and a sport carrying one of these has a standing obligation — when
its boundary changes, that statement's excluded list changes with it or it silently widens.
Use the exception only where the including form has actually been measured not to run, and
record the measurement.

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

### Narrowing a run to one kind of stored value

Defects arrive in families. A provider correcting every bad `Rank` in the database corrects it
across the event layer and the ranking layer at once, and what has to be re-run afterwards is
every check that reads a `Rank` - which is not a category, not a sport and not a template, and
until this flag existed could only be found by opening each statement.

```powershell
.\TOOLS\Run-Query.ps1 -Sport Golf -RunAll -DataType rank
.\TOOLS\Run-Query.ps1 -Sport Golf -RunAll -DataType 100
.\TOOLS\Run-Query.ps1 -Sport Golf -RunAll -DataType rank,comment
```

**A name matches every layer that stores it and a number matches one type exactly.** Measured
on Golf on 2026-08-21, `-DataType rank` selects 22 checks - both `100 Rank` on an event result
and `1270 Rank` in a Comp.Rank - while `-DataType 100` selects 11. The name is usually what a
repair looks like; the number is for when only one layer was touched.

The vocabulary is the database's own, from `result_type`, `statistic_data_type`,
`scope_data_type` and `scope_type`. It is not invented here and it is not a list to maintain:
run any check and read its **Data types** column for the words that sport actually uses.

**The types are grouped by the layer that stores them**, because the layer is what tells one
type from another when the name repeats:

```text
Comp.Rank: 1270 Rank, 1273 Comment; Setting: 1463 Start date
Result: 100 Rank, 501 Medal
Scope: 322 period1, 323 period2, 324 period3; Scope field: 162 goals
```

`Result` is `result_type`, `Scope` is `scope_type`, `Scope field` is `scope_data_type`, and the
last two are the pair that needs saying: **`statistic_data_type` is one catalogue read by two
different owners.** `statistic_dataN.statistic_data_typeFK` types a value belonging to one ranked
participant — `Comp.Rank` here — and `statistic_config.statistic_data_typeFK` types a setting
belonging to the whole ranking, shown as `Setting`. The column name is the same in both, so only
the table that owns the reference separates them, and the two are repaired in entirely different
ways: a rank is corrected row by row, a start date is one field on the statistic. `DATABASE.md`
draws the distinction under `statistic_config`, and until 2026-08-21 this column flattened it.

`Comp.Rank` is the right label for `statistic_dataN` because this package audits statistic type
11 and nothing else — `SPORTS/params.json` records `STATISTIC_TYPE_ID` as 11 for all eleven
sports. A package auditing a second statistic type would have to name that layer from the type
rather than assume it.

Types keep the order the statement reads them in rather than being sorted, inside each layer.
The order says something: `Ice-Hockey-DQ-112` lists `1277 Medal` before `1270 Rank` because it
starts from the medal and reaches the rank, and sorting would lose that.

**What a check reads is derived from its own rendered SQL, not authored against its CheckID.**
A GLOBAL template names its types through declared parameters and a sport statement carries the
numbers directly, but after expansion both are plain numbers in the same columns, so one parser
answers for all of them. Nothing has to be kept in step by hand and nothing can drift: a
statement that starts reading a new field says so at the next run.

**It reports reading, not asserting.** A check joining `104 Comment` only to exclude the rows
that carry one reads the comment and asserts something about the rank, and it is listed under
both - correctly, because correcting the comments changes which rows it returns. That is the
question a re-run asks. Where the difference matters to a reader, a statement may name the
narrower answer itself with a line in its prose block:

```sql
-- Audits: 100
```

No statement carries one today. The mechanism exists so the first check whose derived list
misleads somebody can be corrected beside the assertion it describes, rather than in a table
somewhere else.

`round_typeFK` and `incident_typeFK` are outside the vocabulary on purpose. A round is
structure rather than a stored value repaired field by field, and a sport's `ROUND_TYPE_LIST`
would put twenty-six ids into a column meant to be read at a glance.

A check reading none of the named types is reported as skipped and counted, not listed: under
`-DataType` that is normally most of a sport's catalogue, and a hundred lines saying so would
bury the few that ran.

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

The rule was broken once, on 2026-08-14, and the cost is recorded here so it is not broken
again. A timeout had been made to cut like a large result does, on the reasoning that a
primary-key window lets the optimiser drive from it and each window really does read a
fraction: `GLOBAL-DQ-030` on Golf timed out over the whole statistic range and returned a
thirty-second of it in 2.1 seconds. The reasoning was sound and the arithmetic was not. Cutting
that check into 32 windows made it finishable at 843 seconds — every window a full request
against the largest statistic tables in the database — and left the server answering `504` to a
three-table `COUNT(*)` for hours afterwards, which stopped the day's work for everyone using it.
Rewriting the same check as one statement returned the identical 13 findings in 9 seconds.

So a slow statement is never cut, whatever the window keys on. **Never more than one window is
opened for a statement that failed on time.** A statement that will not run is a statement to
redesign, and the redesign has been cheaper than the cut every time it has been tried. Anything
that reads the whole of a shard table to answer a per-row question is asking the wrong question,
and the runner is not the place to make a wrong question affordable.

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

Five values are recordable. `Actionable` is the default and is never written down — a sixth
value on every check would make the block a second copy of the registry. `Deprecated` is
deliberately not a signal: `POWERBI_REGISTRY.md`'s `Status` column owns it, and a value with
two owners drifts.

| Signal | Means | Enforced as |
|---|---|---|
| `Monitor` | Real, but population-wide. The proportion is the finding; a single row is not a defect | Must have an `Approved` row — it describes a check that runs |
| `Not applicable` | The sport has nothing for the check to read, so it reports the whole population | No row requirement, either way |
| `Out of client scope` | The sport stores what the check reads, but only outside the client's boundary, so the check audits nothing this client is buying | No row requirement, either way |
| `Sentinel` | The scope is right and the structure is there; the population it audits is empty today and the check is waiting for it | Must have an `Approved` row — it describes a check that runs |
| `Blocked` | Would report the sport's normal shape as a defect until something else is fixed first | Must **not** have an `Approved` row — it says "not yet" |

`Blocked` and `Not applicable` are easy to confuse and the difference matters: a block lifts
when the underlying data is fixed, and the check is then approved. `Not applicable` does not
lift, because the structure it reads is one the sport does not have. Recording a permanent
absence as `Blocked` promises a review that will never come.

`Out of client scope` is the third of that family and is the one that says *not here, not now*.
The structure exists and the sport fills it — so it is not `Not applicable` — and nothing needs
correcting before the check could run — so it is not `Blocked`. What is true is that every row
it would audit sits in a `tournament_template` the client does not take, and the sport file's
scope section names which. Golf is the confirmed case: its match play is contested almost
entirely under the templates outside `SPORTS/Golf.md`'s client boundary, so a knockout check
there audits a real population belonging to somebody else.

It lifts on a decision rather than on a repair or an import: the day the client's boundary moves,
the same check runs unchanged. That is why it is written down instead of the check being
deprecated — a deprecated CheckID never comes back, and this one is meant to.

Like `Not applicable`, it suppresses the run's `eligible_count = 0` question, and for the same
reason: a zero there is still not clean data, and the entry records which of the answers it is
rather than pretending the question was never asked.

`Sentinel` is the fourth of that family and is the only one of them that is waiting for
something. `POWERBI.md` says `eligible_count = 0` is one of exactly two things — a misdirected
scope to correct, or a correct scope over a population that is legitimately empty today — and
until this value existed only the first had a word. A run therefore asked the same question
about the same checks every time, and the answer lived in the sport file where the run could
not see it; the `Decisions` tab then showed two unanswered questions that had been answered
weeks earlier. This is that answer, written where the run reads it.

It is not `Not applicable`, because the column, the layer and the relation are all there and a
row arriving tomorrow would be audited. It is not `Out of client scope`, because the boundary
is not what empties it. It is not `Blocked`, because nothing has to be repaired first and the
check is approved and running now. What is true is that the sport has not yet imported a row of
the kind it reads — and the day it does, the check that was written for that day is the one
already watching. That is why a sentinel is never dropped: a check removed for returning
nothing is the check that will be missing when the rows arrive.

The sport file must say what the empty population is and why it is expected to fill, exactly as
it must for the other three. A signal recorded without that sentence is a row count promoted to
a classification, which is the thing this whole section exists to prevent.

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

### What a re-run should return once the data is corrected

The third reserved key is `_expected`, and it answers the question the signal does not. The
signal says what today's rows are worth. This says what tomorrow's count should be, after
colleagues have worked through the findings and the sport is run again.

The two are close enough to be confused and the difference is the whole reason this exists.
Reading a re-run without it means remembering, check by check, which ones were ever supposed
to reach zero — and across a sport's whole catalogue that memory is the first thing to go. A
check that comes back with forty rows is either a failure to correct anything or exactly what
it is meant to return, and nothing in the workbook said which.

Three values, and only the exception is written down:

| Expect | Means |
|---|---|
| `Zero` | every finding row is a defect, so a corrected sport returns the `COVERAGE` row alone |
| `Non-zero` | rows remain however much is corrected: the proportion is the finding, not the row |
| `Residual` | a known and agreed number of rows stays behind; anything above it is new |

The default comes from the signal, so most checks need no entry at all:

| Signal | Expects |
|---|---|
| `Actionable` | `Zero` |
| `Monitor` | `Non-zero` |
| `Informational` | `Non-zero` |
| `Sentinel` | `Zero` |
| `Blocked`, `Not applicable`, `Out of client scope` | nothing — no count anybody should be expecting |

`Sentinel` expects `Zero` rather than nothing, and the difference from the three below it is
the point: those three describe a check that should not be counted at all, while a sentinel is
a live check whose population has not arrived. When it does, every row it returns is a defect —
so the expectation is the one it will be judged by, recorded before the day it is needed rather
than on it. A sentinel whose invariant is population-wide writes `Non-zero` itself, as any
check may.

```json
"BMX": {
  "SPORT_ID": 58,
  "_expected": {
    "BMX-DQ-014": {
      "expect": "Residual",
      "residual": 12,
      "reason": "twelve historical rows predate the source that would fix them; the sport file names them"
    }
  }
}
```

`Test-Package.ps1` holds the block to the same contract the two beside it keep. Every key
names a `GLOBAL-DQ-NNN` template the sport instantiates or one of its own CheckIDs, every
reason is non-empty, `Residual` carries its count and nothing else does, and the check has an
`Approved` row — an expectation about a check that does not run is a statement about nothing,
which is the rule `Monitor` already keeps. One more finding is specific to this block: **an
entry restating the value its signal already implies is rejected.** A value written in two
places is a value that can disagree with itself, and the block exists for the exceptions.

**The expectation is read off the check's invariant, never off the last run's count.** A
check that happens to return nothing today is not thereby a `Zero` check, exactly as
`CLAUDE.md` refuses to let an empty population decide applicability. Recording `Zero` because
a run came back clean is the same mistake in a new column, and it is worse here: a wrong
expectation is not a missing judgement but a judgement the tooling repeats at every run.

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

A short named list rides along besides the pattern summaries — today `GLOBAL-DISCOVERY-033`,
the duplicate-person candidates. Named rather than derived, because the file it lives in also
holds drill-downs, so the rule that picks `PATTERNS.sql` on the strength of its file cannot
be pointed at it. Its parameters are tested against what the sport has **recorded** as well as
what `-Sport` discovers: `PERSON_PARTICIPANT_TYPE_LIST` is not something a run works out for
itself, but every sport in the package states it, and a statement needing only a value already
written down is no less automatic for it. A sport that has not recorded one is left out by
name and the run says so.

These carry a defect category in spite of being discovery, which no other `GLOBAL-DISCOVERY`
statement does. A census has no defect family; a list of people entered twice does, and it is
correctable by merging. So `033` lands on a board under `2 Wrong value` / `DUPLICATE_RECORD`
while keeping the `Informational` signal that makes it `Monitor Only` expecting a non-zero
count — watch it, do not drive it to zero. `POWERBI.md` owns the band, `Run-Query.ps1` the
list.

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

**It is written once, at the end of the run.** A batch used to rebuild it every sixty seconds
so that a run which wedged or was interrupted did not cost the checks that had already
succeeded. That was removed on 2026-08-26, and the reason is worth keeping because the idea is
a reasonable one to have again.

The rebuild was whole every time, so it cost more the further the run got — 36.5 seconds after
30 checks of a Triathlon-shaped board, 49.1 after 114 — and the interval was counted from the
end of the previous write, which made the real cycle sixty seconds of work and forty-five of
writing. Measured against the recorded runs, that is 365 of Triathlon's 968 seconds and 1079 of
Swimming's 1785: six minutes in every ten spent rewriting a file nobody was reading.

What it protected was the least valuable of the three things a run produces. A run that dies has
not updated the live document and has not written a ledger entry, so it is re-run whatever is on
disk, and the workbook it leaves behind is a frozen artifact of a run that never counted.

If the protection is ever wanted again, the thing to bring back is not the interim rebuild but
the per-check flat file that every other format already writes as it goes: one small file per
check as it completes, costing milliseconds instead of a whole workbook.

`Overview` is the first tab:

| Sport | CheckID | Object | Check Name | Priority | Category | What it does | Rows | Status | Check By | Comment | Signal | Signal reason |
|---|---|---|---|---|---|---|---:|---|---|---|---|---|
| BMX | BMX-DQ-001 | Participant | PARTICIPANT_MISSING_DATE_OF_BIRTH | 3 Missing value | MISSING_VALUES | Finds active participants of the selected types that … | 1064 | Not reviewed | | `='PARTICIPANT_MISSING…'!G2` | Monitor | Population-wide absence … |

`Comment` at K is the one computed cell in the workbook: a formula reading `G2` on the check
tab that row links to. The comment is therefore written once, on the tab, beside the rows
that provoked it, and read from the board that lists every check.

The mirror is one way, and cannot be two. A cell holds a value or a formula and never both,
so two cells cannot each feed the other; a spreadsheet has no bidirectional binding to offer.
Typing into Overview's `Comment` replaces the formula with what was typed, and that row stops
following its tab — recovered by re-running the check or by pasting the formula back. This
direction was chosen because losing a mirror costs a mirror, while a mirror on the check tab
would have put the text somebody wrote at the same risk. A check that failed or was skipped
has no tab and gets an empty cell rather than a formula pointing nowhere.

Columns N to U hold the comparison with the run before this one — `Expected`, `Findings`,
`Eligible`, `Prev findings`, `Prev eligible`, `Change`, `Verdict`, `Last run`. See "What the
run before this one returned" for what each verdict means and why the block sits after `M`
rather than beside `Rows`. `Trends` is on the live document only; the workbook is a snapshot
of one run and a series belongs where the series is maintained.

`Data types` is last, and holds the stored values the statement read, grouped by the layer that
stores them — `Comp.Rank: 1270 Rank, 1273 Comment; Setting: 1463 Start date` — so a reviewer can
see what a check touches without opening it, and filter the board to one defect family when the
provider corrects one. It is derived from the rendered SQL rather than
authored anywhere, so it cannot drift from the statement; `-DataType` selects a run by the same
values, and "Narrowing a run to one kind of stored value" owns the rule. Its position is
mechanical rather than a judgement about importance: `H`, `I`, `K` and `L:M` are pinned by
letter in the row builder, the validation range and `Test-Tools.ps1` at once, so a column
inserted before them would break the row-count link, the `Status` dropdown and the `Comment`
mirror together. Last is the only position that costs nothing.

`Signal` and `Signal reason` are columns L and M, and the workbook ships with both hidden.
They are the runner's own classification, settled before the run and unchanged by reading
it, so the reviewer opens on the columns that are theirs to work through. Nothing is
dropped: unhiding L:M brings back every value, and both still travel in `_summary.csv`.

`Object` is the layer the check audits, and it is what says which layer to repair first: a
Comp.Rank is generated from the events beneath it, so repairing the ranking before the events
is work that gets undone, and a check name does not say which of the two it reads. It holds one
of six words — `Participant`, `Event`, `Comp Rank`, `Tournament`, `Stage`, `Template` — taken
from the `Object` column of `POWERBI_REGISTRY.md` and collapsed to them. `POWERBI.md` owns both
the registry vocabulary and the collapse; the registry keeps the finer distinction between a
check on an event and one on that event's results, and the board does not carry it.

Column `C` held `Parameters` until 2026-08-19, hidden. It was empty for every check of a sport
that takes none and identical for every check of one that does, and the reviewers asked for the
column back. `Parameters` still travels in `_summary.csv` and on each check tab, where it is
what tells two chained runs of one statement apart and where a `SKIPPED` row records the values
the chain did not pursue.

### Decisions

A run decides some things by itself — the busiest statistic type and owner, the values a chain
pursues — and leaves others open. Both are honest while they stay execution output. The moment
one is copied into `SPORTS/params.json` it is read by every later run as confirmed evidence, and
a heuristic recorded there is indistinguishable from a fact somebody checked.

So they are written down rather than printed and forgotten: a `Decisions` tab straight after
Overview, and a `_decisions.json` beside the workbook. Both appear only when something is open.

| Column | What it holds |
|---|---|
| `Decision` | which kind — statistic type and owner, chain values not pursued, drill-down without a source, statement not run, audited nothing, statement failed |
| `Subject` | the parameter or the run key it concerns |
| `Run chose` | what the run did: a value it picked, or `deferred` / `skipped` |
| `Why` | on what basis, in the run's own words |
| `Alternatives` | the real options, read from the run's output — never invented |
| `Answer` | the reader's column, like `Check By`; the runner writes the question and never the answer |

The one that matters most is the statistic type and owner pair. Every statistics statement and
every Comp.Rank template reads the sport through it, `GLOBAL-DISCOVERY-015` may return several,
and the runner takes the busiest. As a grey console line that was easy to miss; as a row with
the other pairs beside it, it has to be answered. The row is written even when there was only
one candidate, so "nothing to decide" is recorded rather than assumed.

`WORKFLOW.md` owns the evidence gate and the `new-sport` skill's stage 2b owns what must happen
to these before a sport file is written. The runner only makes sure the list exists.

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

`Rows` is what is still open, and doubles as the jump to that check's tab. A check that failed
shows `ERROR` instead, so it cannot be misread as a clean zero, and is left unlinked because it
has no tab; the reason is on the console and in `_summary.csv`, along with the durations.

**It is the count the console printed less the rows the reviewers marked `No Issue / Change`.**
The other two row verdicts need no such help. A row marked `Fixed` leaves the result the next
time the check runs, because the thing it described is gone, so the count falls on its own; a
row marked `In Progress` is open work and belongs in the count for as long as it says so. `No
Issue / Change` is the one that is settled and never leaves: the reviewer has decided the row is
the sport rather than a defect, so it returns every run for good. Counting it makes a finished
check read as a busy one forever — on `Golf-DQ-048` that was 251 of 283 rows, a board saying
there were 283 things to do when there were 32.

A dismissal closes a row for as long as the row reads what it read. Let it come back saying
something else and the dismissal is parked, the row is open again, and the count rises — not
because the data got worse but because the conclusion that closed it was reached about a reading
nobody is looking at any more. `A conclusion belongs to the reading it was reached about` below
owns the rule.

`Findings`, `Eligible` and `Change` are untouched by this and always carry the full number. They
are the run's own measurement of the database, and a reviewer's conclusion may close a row but
may not edit what a statement returned. The tab still holds every row, dismissed ones included,
so `Rows` and the tab differ on purpose and `Findings` beside it is where the difference shows.

The subtraction uses the same match that puts the notes back beside their findings — computed
once, read by both — so a note whose finding is no longer in the result is logged rather than
subtracted. `Sheets.ps1` `$SheetsRowReviewDismissed` owns the value.

`Status` is a manual tracking field, and its dropdown offers the same eleven words the live
document does - one list, `$SheetsStatusBands` in `TOOLS/Sheets.ps1`, read by both:

| Open | Closed |
|---|---|
| `Not reviewed`, `Reviewing`, `On Hold`, `IT Fix`, `Other Team`, `Reopened` | `Clean`, `Monitor Only`, `Completed`, `Skipped` |

`Monitor Only` is the reviewer's counterpart to the `Informational` signal: the check ran, it
was read, and there was never anything in it to act on.

Two of those the workbook settles itself, so a reviewer opens on the rows that actually want
reading:

| Seeded as | When |
|---|---|
| `Monitor Only` | the signal is `Informational` — nothing in the output is correctable |
| `Clean` | the check returned exactly one row, its `COVERAGE` row, **and that row counts a population above zero** |
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

On the live board the tab is frozen to row 5, so the whole identity block and the result's
own column names stay in view while the rows scroll. Sheets makes a table's header sticky by
itself, and with two tables on the tab the one it chose was the identity at the top — which
kept the check's name in sight, the one thing a reader already knows, and took the column
names away.

`Check ID`, `Check Name` and `What it does` range left; everything else on the tab is
centred. They read as sentences rather than as values, and centring a sentence starts it in a
different place on every tab and hides a clipped ending in the middle of the cell. `SQL Used`
between them stays centred: it is a one-word control, not a sentence.

C2 reads `SQL` and jumps to the statement, which lives on the `SQL` tab at the end of the
workbook rather than in the cell. It used to be the statement itself, collapsed onto one
line: a cell of a few thousand characters that nothing could display, and that pushed the
result table out of shape the moment somebody opened it. On the `SQL` tab each statement
keeps the line breaks it was written with, one line per row, and its first cell jumps back
to the results it produced.

`Comment` and `Check By` are written as headings and nothing else: both columns belong to
whoever reads the workbook, and the runner never puts a value in either. `G2` is where a
comment is written for the whole check — the Overview column of the same name reads this
cell and never the other way round. `Priority`,
`Category`, `What it does`, `Signal` and `Signal reason` beside them are the same values the
Overview carries, so a tab opened from a link explains itself without the reader going back.
Unlike the Overview, a check tab leaves the signal fields visible — there are only two of
them on a row that is already about one check.

`SQL Used` stays at C on a check tab, because C2 is where the jump to the statement lives.
That is why `Parameters` is appended at K here rather than sitting near the front: inserting
it would have taken the statement link with it. On the Overview, `Rows` links from column H,
the `Status` dropdown binds to I, `Comment` computes at K, and the hidden signal pair is L:M.
A change to these positions is a change to three places at once — the row builder, the
validation `sqref`, and the assertions in `Test-Tools.ps1` that pin them.

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

## What the run before this one returned

Every run is a folder with a date on it, and nothing reads the folder before it. That is
fine for one check and stops working for a sport: after colleagues have corrected a round of
findings the sport is run again, and the only way to tell what moved is to open the previous
workbook beside the new one and compare by eye, check by check.

`RUNS/<Sport>.json` is the run's own history. One entry per run, appended, newest last so a
`git diff` of the file is the run that was just added and nothing else:

```json
{
  "sport": "BMX",
  "ledgerVersion": 1,
  "runs": [
    {
      "runId": "BMX 07.08.2026 09-09-47",
      "startedUtc": "2026-08-07T06:09:47Z",
      "output": "D:\\SQL's Output\\BMX 07.08.2026 09-09-47",
      "commit": "883eb473e1e6",
      "checks": [
        { "checkId": "BMX-DQ-001", "runKey": "BMX-DQ-001", "parameters": "",
          "name": "PARTICIPANT_MISSING_DATE_OF_BIRTH", "category": "MISSING_VALUES",
          "signal": "Monitor", "expected": "Non-zero",
          "rows": 1065, "findings": 1064, "eligible": 12043,
          "seconds": 3.2, "status": "OK", "sqlHash": "921cc305e33f" }
      ]
    }
  ]
}
```

**`findings` and `eligible` are carried rather than the row count alone, because the row
count cannot be compared.** It includes the `COVERAGE` row, so a clean check reports 1 and a
check with one finding reports 2. And on its own it says nothing about the population those
findings came out of: a check that fell from 40 to 3 while its `eligible_count` fell by the
same proportion corrected nothing. Both numbers were being computed already — `Get-CoverageCount`
reads the coverage branch to seed the workbook's `Status` — and both were thrown away with
the terminal. They now also travel in `_summary.csv`.

### Which statement produced the number

`sqlHash` is the first twelve hex of SHA256 over the statement **as it was actually sent** —
parameters substituted, narrowing applied. `commit` is the package version that ran it, with a
trailing `+` when the working tree carried uncommitted changes, because a run made mid-edit is
exactly the case where a bare commit would be a lie.

They exist because a moved count could not otherwise be read. `Biathlon-DQ-038` recorded 3
findings of 2358 eligible on six consecutive runs:

```text
Biathlon 27.08.2026 10-29-25    134.6s  find=3  elig=2358  Unchanged
Biathlon 27.08.2026 11-53-22    144.1s  find=3  elig=2358  Unchanged
Biathlon 27.08.2026 12-09-22    139.4s  find=3  elig=2358  Unchanged
Biathlon 27.08.2026 21-38-33    154.8s  find=3  elig=2358  Unchanged
Biathlon 29.08.2026 02-09-13    142.7s  find=3  elig=2358  Unchanged
Biathlon 30.08.2026 07-53-09    141.8s  find=3  elig=2358  Unchanged
```

Between the last two the statement was rewritten from an all-pairs self-join to a window and
went from 141.8 seconds to 12.1. Nothing in those rows says so. A reviewer reading them cannot
tell a number that held because the data held from one that held because nothing about the
check moved — and those are different pieces of news.

A run that finds the fingerprint changed says so rather than leaving it in the file. On one
check it is appended to the comparison:

```text
Unchanged: 3 finding(s) of 2358 eligible, expected Zero (was 3, run Biathlon 30.08.2026 07-53-09), which ran a different statement
```

and on a batch it is named after `Done:`, beside the skipped ones.

**A narrowed run fingerprints differently from a wide one, on purpose.** `-TemplateIds`
rewrites the statement and the population it audits is genuinely not the same population, so a
count from one is not comparable with a count from the other. That the fingerprint says so is
the point, not a false alarm.

Twelve characters rather than sixty-four: it answers same-or-different and nothing else, and
the full digest across 23126 rows would be 1.2 MB of a 25.5 MB ledger to say it four times
over. As it stands the two fields cost about 2.2 per cent of the file.

They travel in `_summary.csv` too, appended after `Trend`. **Anything new goes on the end**, so
a script reading that file by column position keeps every column it already had.
### The verdict

Each run reads itself against the last recorded one and writes the answer per check. The
expectation decides what counts as good news, which is the whole reason it is recorded:
forty rows is a failure to correct anything on one check and exactly the right answer on
another.

| Verdict | When |
|---|---|
| `New` | no earlier run to compare against — this one is the base |
| `Clean` | expected `Zero`, no findings came back, and none came back last time either |
| `Resolved` | expected `Zero`, no findings came back, and last time there were some |
| `Improved` / `Unchanged` / `Regressed` | expected `Zero`, and the findings fell, held or rose |
| `As expected` | expected `Non-zero` and the proportion held; or `Residual` and the findings are within the agreed count |
| `Above residual` | expected `Residual`, and more rows came back than were agreed to stay |
| `Unexpectedly empty` | expected `Non-zero`, and nothing came back |
| `Scope moved` | the audited population shifted by more than 5%, so the raw delta compares two different scopes |
| `Audited nothing` | `eligible_count` is 0, which is never clean data |
| *(empty)* | the statement failed, was skipped, or has no `COVERAGE` row to read findings from |

Four of these carry the reasoning that is easy to get wrong:

**`Unexpectedly empty` is the inverse of the mistake this whole column exists to prevent.** A
check whose findings are population-wide cannot correct itself to nothing, so an empty result
means it broke — a scope that stopped resolving, a join that stopped matching. Without an
expectation recorded against it, that check comes back with zero rows and reads as the best
result on the board.

**`Resolved` and `Unexpectedly empty` are decided before anything is compared,** because zero
findings is a statement about the data and not about the population it came out of. A sport
that grew by half still resolves.

**`Resolved` and `Clean` are the same zero and not the same news.** `Resolved` claims work
landed, so it is said only where work landed; a check that was clean last week and is clean
this week has resolved nothing. Saying otherwise every week buries the rows that did change
among the ones that never do.

**`Scope moved` guards a raw count, and only a raw count.** A check expected to reach zero is
read by subtraction, so a population that moved makes "was 40, now 3" a claim about two
different scopes. A `Non-zero` check is read by proportion instead — 1064 of 12 000 and 1170
of 13 200 are the same picture — so the guard does not apply to it and would misfire if it
did. Ordinary drift stays quiet: colleagues are correcting the data while it is being read,
and a threshold that fired every run would be noise.

**`Above residual` is absolute.** An agreed remainder is a count of specific rows somebody
decided to leave, so exceeding it means new rows arrived, whatever the population did.

The Overview carries the block at **N:U** — `Expected`, `Findings`, `Eligible`,
`Prev findings`, `Prev eligible`, `Change`, `Verdict`, `Last run` — appended after the hidden
signal pair rather than inserted beside `Rows`. `H`, `I`, `K` and `L:M` are pinned in three
places at once, and moving them would break the row-count link, the `Status` dropdown and the
`Comment` mirror together. The block stays visible: it is the answer to the question a re-run
is for, and a column somebody has to unhide is a column nobody reads.

A single check run to the screen prints its verdict rather than only filing it, since
somebody re-running one check after a reported fix is standing at the terminal waiting for
exactly that line.

Three things are deliberately outside it:

- **Discovery statements.** A round type with a count is a census, not a finding that can be
  resolved, so the pattern statements `-RunAll` carries alongside the checks are left out
  rather than filling the history with numbers nobody will compare.
- **A run with `-TestRun`.** See below.
- **Anything a reviewer wrote.** Not yet: the `Comment` and `Status` a reviewer types still
  live in the workbook and still do not survive the next run. Carrying them is the step after
  this one.

### Reading the whole history

The board compares this run with the one before it, and that is all it shows. Everything
else is in the ledger, and `-History` is how it is read back:

```powershell
.\TOOLS\Run-Query.ps1 -History Artistic-Gymnastics-DQ-021
```

```text
Artistic-Gymnastics-DQ-021

Run                                     Findings Eligible Rate   Verdict   Status
---                                     -------- -------- ----   -------   ------
Artistic-Gymnastics 09.08.2026 10-11-18        1      825  0,12%  New       OK
Artistic-Gymnastics 16.08.2026 09-02-44        0      831  0,00%  Resolved  OK
```

Oldest first, so the first run and the tenth sit side by side.

A wildcard reaches a whole sport, and the shape changes with it — a hundred one-row tables is
not a table, so the check becomes the row and the run becomes the column:

```powershell
.\TOOLS\Run-Query.ps1 -History 'Artistic-Gymnastics-DQ-*'
```

```text
CheckId                     R1  R2  R3  Net
-------                     --  --  --  ---
Artistic-Gymnastics-DQ-020   1   1   0   -1
Artistic-Gymnastics-DQ-022  32  33  41    9

Columns, oldest first:
  R1   Artistic-Gymnastics 09.08.2026 10-11-18
  ...
```

`Net` is the last run against the first, which is the reason for looking at more than two.
Columns are numbered because a run id is thirty characters and a dozen of them across is not
a console width; the legend underneath carries the dates. At most twelve runs are shown and
anything older is counted rather than dropped silently — ask for one check to see all of it.
A run where the check failed reads `ERR` rather than a number, so it cannot pass for a zero.

`Rate` is `findings / eligible`, carried because a raw count is only comparable while the
population behind it is, and over ten runs it rarely stays still. `Verdict` is what that run
concluded at the time, not what today would conclude.

The sport comes from the CheckID prefix, so nothing else has to be passed. It reads the ledger
and nothing else: no credentials, no network, and no run.

The live document carries the same thing on its `History` tab, windowed to the last 40 runs,
for the reviewers who do not have the repository. This command is the unwindowed read and shows
every run ever recorded.

**A run made with `-TestRun` is absent, by its own request.** So is anything that has not been
run at all — the command says so rather than printing an empty table that reads like a clean
result.

Two properties of the ledger matter when reading it back. Each entry keeps the `signal` and
`expected` that were in force **at the time of that run**, so reclassifying a check later does
not rewrite what earlier runs meant. And because the file is tracked, `git log -p
RUNS/<Sport>.json` gives the history of the history — though only for runs somebody committed.

### A run that leaves no trace

Trying a new statement, checking whether a reported fix took, running a narrowed slice that
is not the sport's periodic pass — those are not the sport's history, and a run that files
itself as one moves the baseline every later run is read against.

```powershell
.\TOOLS\Run-Query.ps1 -Sport BMX -RunAll -TestRun
```

The run executes normally and its verdicts are still computed against the last recorded run,
because a test is worth more when it says what moved. What it does not do is record: nothing
is appended to `RUNS/BMX.json`, so the next real run still compares against the last real one.

**Results are still written**, because a run nobody can read proves nothing. The folder is
named `TEST BMX 08.08.2026 14-22-05`, so it can be deleted on sight rather than by
remembering which of ten folders were real. `-OutDir` and `-OutFile` still override the whole
scheme, and a run given one of those is named whatever it was told.

A run mixing sports writes to each sport's own file, because a ledger keyed on anything but
the sport cannot be read by the next run of that sport. A file that cannot be parsed is
reported and left exactly as it was: a run overwriting a history it could not read would
destroy the only copy of it, and the history is the reason the file exists.

Nothing prunes it. A sport running its catalogue weekly adds a few dozen small entries a
week, which is years away from being a problem, and a silent cap would make a history read as
complete when it was not.

## The live per-sport document

Reviewers work in Google Sheets, and until now every run produced a new workbook to upload.
The numbers survived that — the ledger above is what carries them — but the `Status` and
`Comment` a reviewer typed stayed in the previous Sheet, which is the complaint the whole of
this began with. A new file per run strands review state by construction.

So the destination becomes **one permanent Sheet per sport**, updated in place. `Sheets.ps1`
decides what that update is. It holds no network code and sends nothing: given what a run
produced and what the document already contains, it returns the list of operations that would
bring the document up to date. The transport is separate on purpose — the merge is where a
permanent document can lose somebody's work, and a merge that needs a login to exercise is a
merge nobody exercises.

**Status is at `I`, `Check By` at `J`, `Comment` at `K`, `Time Spent (minutes)` at `L`, and a
check tab's own three are `E2`, `F2` and `G2`. A run never writes any of them.** That is the whole protection, and it is a better
one than locking: Sheets has no lock to take, and two people editing at once is the normal
case. The runner writes its own columns in two spans per row and steps over the reviewer's.
The only exception is a row for a check the document has never held, where there is nothing
of anyone's to overwrite and the seeded `Status` is what says the row needs no reading.

None of those four positions is written as a number anywhere but in the column lists at the
top of `Sheets.ps1`; the reviewer's columns and the cell the mirror points at are derived from
them. A check tab's pair was `G2` and `H2` until `Signal` and `Signal reason` came out of that
tab, and a literal left behind would have put somebody's comment in what is now `Expected`.

Two rules follow from the document outliving the run, and both are easy to get wrong:

- **A row is found by its CheckID, never by its position.** Writing the Overview as a
  positional block is the obvious implementation and it corrupts the board: adding one check
  in the middle shifts every row below it, and each comment then describes the check above
  the one it was written for. An existing check is updated in the row it already occupies —
  wherever the reviewer has since sorted it to — and a new one is appended at the bottom.
  Sorting is theirs to do and theirs to keep.
- **A tab is never deleted.** A check that stopped running keeps its tab and its comments,
  and its `Verdict` reads `Not in this run` so the board does not show last run's number as
  though it were this one's. Deleting it would throw away the one thing in the document
  nobody can regenerate.

Only a run asked for the sport's whole catalogue — `-RunAll`, uncapped — marks the checks it
did not produce. A partial run did not fail to produce the other ninety; it was never asked
for them, and marking them would repaint the whole board every time somebody re-ran one check
after a reported fix. The rows such a run leaves alone keep the last full run's numbers, which
is what they are. A *skipped* check is unaffected either way: it has a summary row of its own
and reports `SKIPPED`.

**The `SQL` tab is the one thing a run must never clear.** Every other range the merge clears
holds rows the run can produce again — an Overview row, a check tab's results — so a run that
stops between clearing and writing loses nothing that is not about to be sent anyway. The `SQL`
tab is the opposite: it carries one block per check, and for every check the run did not hold,
that block exists nowhere but on the tab itself. It reaches the merge by being read back off
it.

Clearing it first put those statements in a window. A run cancelled inside that window, or one
whose write was refused, left the tab empty — and the next narrow run then read no blocks,
merged against nothing, and wrote its single statement over the catalogue, which is behaviour
indistinguishable from working correctly. Golf lost 105 statements to it on 2026-08-20. The
merge itself was already right and had been since 2026-08-10; what was wrong was that it was
handed an empty tab and believed it.

So the column is overwritten in place, padded with blank rows out to whatever the tab already
reached, in a single write. A write that never lands leaves the previous column entire. And
because overwriting in place is no protection against a *read* that came back empty, a tab
holding rows that parse as no block at all is left untouched and reported: rows that yield no
statement mean a tab this run could not read, not an empty one.

That skip used to be permanent, and saying so is the point of the rest of this section. The
condition is read off the tab, and nothing a later run does changes what the tab holds, so a
board that reached the state stayed in it while the warning told the reader to run the sport's
whole catalogue and the code refused that run exactly as it refused the narrow ones. Golf and
Ice-Hockey were both found there on 2026-08-29, 14 471 and 13 703 rows of intact SQL under
blank headings, each after a sheet update that had failed earlier the same day. Two things now
stand between a board and that state.

**A heading is read from either column.** A block is found by a heading row carrying the
CheckID and nothing else. In column `A` that heading is a link, and a link is a formula, and a
formula cannot be sent in the same `RAW` batch as the statements — so it goes in a second
batch, and a run that dies between the two leaves exactly that tab. Column `B` of the same row
carries the CheckID as plain text, rides in the batch with the statement it names, and is
hidden. The two land together or neither lands.

**A complete run may rebuild.** `-RunAll`, uncapped, was asked for the sport's whole approved
catalogue and produced it, so a tab that parses as nothing is rewritten rather than preserved.
Only if the run really did produce it all: a check that failed, or that returned nothing
whatsoever, never reaches the collected results and so has no block, and rebuilding without it
would delete the one copy of its statement there is. Such a run leaves the tab alone and names
the checks that are missing. A discovery statement the board carries is not in the catalogue
and does not survive the rebuild — against a tab that already parses as nothing, those blocks
were lost either way, but running the sport's discovery statements alongside the catalogue puts
them back in the same rewrite.

**Not the identity header**, though it looks like the obvious third. Every statement opens with
`SELECT` alone and its `-- CheckID - ` comment under it, which makes a headless tab look
self-describing. What that comment carries is the CheckID of the *statement*, and for a check
instantiated from a `GLOBAL` template that is the template's rather than the board's: measured
against Handball's tab, 109 of its 123 blocks come back named `GLOBAL-DQ-nnn` instead of
`Handball-DQ-nnn`, and only the 14 sport-authored ones are right. Nothing on the board maps one
to the other — `Overview` carries no template column — so those blocks would merge under names
nothing matches and the rewrite would write every statement twice, under the wrong headings. A
tab that parses as nothing is recoverable by a complete run. A tab rebuilt from the wrong names
is not.

A check tab is also cleared to its end before it is written, rather than to a depth this code
believes it has. Forty rows last run and three this one would otherwise leave thirty-seven
stale rows under the three new ones, which reads as forty findings — and a remembered depth is
only right while the memory is, which a `-TestRun`, a hand edit or a half-finished write all
break. The end of the tab is a fact.

### What the board carries that the workbook does not

`Overview` runs `A` to `X`, the workbook's twenty-one columns plus three of its own:
`Time Spent (minutes)` at `L`, `All findings` at `Q` and `Trends` at `X`.

`Time Spent (minutes)` is the reviewer's, for how long the check took to work through. Every
check tab carries one too, at `G2`, and the two are deliberately not linked: how long the rows
took and how long the board took to read about them are different numbers, and a mirror would
force them to be one. `Comment` is mirrored because it is one piece of text about one check;
this is not.

`All findings` is what the statement returned. Every other column that counts findings —
`Findings`, `Prev findings`, `Change`, `Verdict` and the `Trends` series — counts what is still
**open**, with the rows the reviewers marked `No Issue / Change` taken out of it. A settled
finding stays in the result for good, because the decision is a reading of the data rather than
a change to it, so counting it forever made a finished check read as a busy one. `Rows` had that
subtraction to itself until 2026-08-17, which is how a check could show 0 open rows beside a
`Findings` of 40 and a verdict of `Above residual`.

`Eligible` and `Prev eligible` are untouched by it. They count the population a finding came out
of, and dismissing a finding does not shrink the population it was found in.

`Findings` turns **red** where it is more than half of `Eligible` and the check's signal is
`Actionable` or `Sentinel`. The count alone does not say this: 420 findings is a small number
beside Swimming's 46 379 and a total one beside BMX's 420 eligible, and the board sorts on the
count — so the check that found every single thing it looked at sits below one that found a
hundredth of what it looked at. The share is what separates them.

Measured across all fifteen boards on 2026-08-29: 742 rows carry findings and a population and
ask for action, of which 199 are over a tenth, 131 over a quarter, 88 over a half and 63 over
nine tenths. So most of what the band catches is not merely high but at 100% — a whole
population, which is either a systemic gap or a scope pointed at the wrong thing. Either way it
is a question for a person rather than a number to read past, and every one of the twelve
highest was still `Not reviewed` when the band was added.

The signals are listed positively because the vocabulary is closed and the negative list is
longer. `Monitor` and `Informational` are out because nothing in their output is correctable,
and `Informational` is what this board renders as `Monitor Only`, so excluding one without the
other would leave half the idea behind. `Blocked`, `Not applicable` and `Out of client scope`
are out because the check is not in play. `Sentinel` is in: it expects zero, so a sentinel
covering its whole population is the loudest thing on the board.

The rule is a formula rather than a number band, because a share is two cells. It is guarded on
`Eligible` being a number greater than zero — a row whose coverage branch has not run yet holds
an empty cell, and Sheets reads that as zero.

The dismissal count is today's, and it comes off the historical points of the series as well,
because no per-run figure was ever recorded to use instead. A reduced present against a raw past
would draw a drop on the day the reviewers worked rather than the day the data changed. It also
leaves `Change` alone, the same figure coming off both ends of it.

`Change` and `Verdict` are coloured the way the series is: **bold green** where the check
improved, **bold red** where it worsened, **bold black** where it did not move. `Change` compares
to zero directly; `Verdict` holds a word, so its rule reads the `Change` cell on its own row. A
row with no `Change` at all is left uncoloured rather than counted as level. The three colours
come from the same map the trend uses — a green that drifted from the green beside it would be
worse than no colour at all.

`Trends` is the last five open counts for that check, this run last, each dated:
`40 (18.07) → 12 (25.07) → 3 (01.08) → 1 (08.08)`. The separator is an arrow rather than `>`,
which in a cell full of numbers reads as a comparison operator and makes `100 > 105` state
something plainly false. The board compares against one run and the ledger holds them all;
this is the middle, and it is the answer to "is this moving" without opening anything. A run
where the check failed reads `ERR` in the series rather than being skipped — a gap that is
drawn over is a week nobody measured, shown as a smooth line.

The date is part of the point rather than decoration. Four zeroes in a row mean one thing
across four weeks and another across one afternoon of re-runs while a fix was being tested,
and the counts alone cannot tell those apart. Each label is the local time the run started,
taken from the ledger's `startedUtc`, falling back to the run folder's name and then — if
neither can be read — to no label at all rather than to a guess.

Two date formats, and the run picks one for the whole column: `dd.MM` normally, `dd.MM HH:mm`
as soon as two runs in the window fall on the same calendar day. Choosing per row would put
two shapes in one column and leave a reader to work out that the difference is only in how
crowded one check's history happens to be. The clock therefore appears exactly when the date
alone would print the same label against two different runs, which in practice means a day
spent re-running one check.

**The series is per check, not per column.** It shows every run of *that* check, so two rows
whose third value sits in the same place are not necessarily describing the same day: a check
re-run four times while a fix was being tested has four entries where its neighbours have one.
That is the right behaviour for the question the column answers, and the wrong basis for
comparing two checks against each other. `-History` carries the run each number came from.

It lives on the board rather than on a tab of its own for one reason: a separate history tab
is a second copy of the ledger, and a run that fails to reach the document leaves it looking
complete while quietly missing the newest run. A column goes stale with the row it sits in,
and the whole board goes stale together — visibly, and fixed by the next successful run.

`Rows` is coloured by how much work is behind it: **0 in green**; **1 to 100 in orange**;
**above 100 in red**. That is a size judgement and not a severity one — severity is `Priority`,
which comes from the category and does not move.

**The `COVERAGE` row is not counted, and from 2026-08-28 it is not written to the tab either.**
Until then `Rows` was the raw row count, so a clean check read 1 and a check with a single
finding read 2 — a column whose smallest number was not the empty one. The row is a statement
answering how much it audited rather than something it found, so it comes out of the count and
off the tab together, and the number on Overview is the number of rows behind the link.
`eligible_count` is not lost: it is the `Eligible` column, it is in `_summary.csv`, and it is in
`RUNS/<Sport>.json`. What it costs is that a check that audited nothing and a check that found
nothing now look alike on the tab — both empty — and are told apart by `Eligible` and by the
run's own `Audited nothing` line.

Because the cell counts what is open, the colour follows the review rather than the run, and
that is the point of it: a check whose findings have all been dismissed goes green, and a
reviewer working down the board by colour stops being sent back to it. `All findings`
beside it says what the run actually returned.

The cell is a link to the check's tab and a number at the same time, which is why the count
goes into the `HYPERLINK` formula unquoted. Quoted it is text: it sorts 1, 10, 2 and a band
comparing against 100 never matches it. A check that failed holds the word `ERROR` instead,
quoted, and no band colours it.

The three bands are rewritten on every run over that one column, so a threshold changed in
`TOOLS/Sheets.ps1` reaches documents created before the change. A conditional format somebody
adds on `Rows` will not survive the next run; on any other column it is theirs and is left
alone.

`Status` is a closed vocabulary rather than free text, offered as a coloured dropdown down the
whole column: **Not reviewed**, **Clean**, **Monitor Only**, **Reviewing**, **On Hold**,
**Completed**, **Reopened**, **IT Fix**, **Other Team**, **Skipped**. The list is `$SheetsStatusBands` in
`TOOLS/Sheets.ps1`, and the workbook's dropdown reads the same constant, because a workbook and a
board that disagree about the words are how the column came to hold nine spellings of five ideas
across six boards. Validation is strict, so an undeclared word is refused rather than flagged.

**Three were added on 2026-08-21**, each saying something the original six could not. `On Hold`
is a review that started and stopped, which `Reviewing` claimed was still moving. `Other Team` is
the second direction a check can be handed in: `IT Fix` was the only one, so a check somebody
else owns reached the board as either that or `Not reviewed`. `Skipped` is a deliberate decision
not to work a check now - leaving it `Not reviewed` made a settled decision look like an
untouched row.

Their colours answer the reading groups rather than each other. `IT Fix` and `Other Team` are two
ambers because they mean the same kind of thing and differ only in who received it, the same
reason `Clean` and `Completed` are two greens. `On Hold` is orange, beside the red of
`Not reviewed` and not in it. `Skipped` is teal rather than the third green it was first asked to
be: three green chips in a column of ten would cost the glance the colour exists to give.

`Skipped` is also the one word here that means something else elsewhere on the same row. The
runner writes `SKIPPED` into the `Rows` cell for a statement it did not execute, and this is a
person saying they executed it and put it aside. Two columns, one word, two meanings, and it was
decided knowingly because it is the word the reviewers use.

A superseded spelling still on a board is renamed on the next run — `No issue` and `No Changes`
to `Clean`, `No action needed` to `Monitor Only`, `Fixed` to `Completed`, `For IT` and
`Reported to IT` to `IT Fix`, and the observed typo `Monitor Olnly` to `Monitor Only`. The map is
a closed list of synonyms, so it renames a conclusion and never forms one. A word nobody declared
is left exactly as typed.

### `Reopened`, and the three cases in which the runner writes a Status

`Status` is the reviewer's column and the runner writes around it. Three exceptions, each narrow
by construction and each reported by the run rather than made quietly - `-RunAll` prints every
write into the column and every one it declined to make.

The first is the rename above. The second is the reopening below, and the third is the closing
after it.

**`Deprecated` used to be a fourth and is not written anywhere any more.** Until 2026-08-28 a
withdrawn check kept its row, with `Rows` set to 0, `Signal` and `Verdict` reading `Deprecated`,
a sentence in `C3` of its tab, and the registry's word in `Status` wherever nobody had answered.
The row and the tab are now removed instead - see **A withdrawn check leaves the board** below.

The third is **`Reopened`, added 2026-08-25**, and it exists because two of the words are claims
about a state rather than about a check. `Clean` says the check returns nothing; `Completed` says
the findings were dealt with. A later run contradicts either by simply returning rows, and until
this existed it did so silently: colleagues cleared a check, marked it `Completed`, and ten days
later it came back with new findings under a green chip nobody had reason to look at twice. A
board is scanned and filtered by this column, so a stale word in it is not cosmetic - it is work
that has become invisible.

So a run that finds `Clean` or `Completed` on a check its own result contradicts writes
`Reopened` over it, and names the check, the word it replaced and the count that refuted it.

| | |
|---|---|
| What triggers it | the cell reads `Clean` or `Completed`, or a superseded spelling of either, **and** the check's `Expected` is `Zero`, **and** the run returns open findings |
| Why the expectation matters | `Zero` is carried by `Actionable` and `Sentinel`, and for both every returned row is a defect. `Non-zero` belongs to `Monitor`, where the proportion is the finding and the count never reaches nothing; `Residual` is a remainder somebody agreed to leave; an empty expectation belongs to `Blocked`, `Not applicable` and `Out of client scope`. On those, `Completed` means the reviewer read it, so reopening would ask the same question every run for ever. Narrowed 2026-08-26 after the first eleven boards moved 99 checks and eight of them should not have |
| What counts | `Findings` after dismissals, not raw rows — a check whose remaining rows are all marked `No Issue / Change` is still finished and keeps its word |
| The other eight | untouched by *this* rule. `Monitor Only` expects a count forever, `Reviewing`, `On Hold` and `Skipped` say where the reading got to, `IT Fix` and `Other Team` say who is holding it, `Not reviewed` is the seed and `Deprecated` is the registry's. None is a claim a result can contradict by returning rows — but five of them are closed by returning nothing, which is the fourth exception below |
| Going the other way | see the fourth exception. Until 2026-08-27 the answer here was *never*, and for `Clean`, `Monitor Only` and `Skipped` it still is |

`Reopened` rather than `Not reviewed` because the two are different facts. Nobody has looked is
not the same as somebody looked, closed it, and it came back - and the second is the one worth a
reviewer's attention first. It is red for the same reason `IT Fix` and `Other Team` are two
ambers: it belongs with `Not reviewed` in the reading, because both mean this row has not been
answered as it now stands.

**The first run after a board adopts it will reopen everything that had already gone stale**,
which on a long-lived board is the accumulated debt arriving at once rather than anything going
wrong.

### Being told a check reopened, without opening the board

`Reopened` is written into a column on a document, and the whole reason the word exists is that
the check has stopped being somewhere anybody was going to look. So the run also says it out
loud, and can send it.

Every run that updates a board queues one message per check it moved to `Reopened`, and names
each of them on screen whether or not anything is sent:

```text
  Reopened, and queued to notify: Soccer-DQ-023 EVENT_RESULTS_MISSING_FOR_FINISHED - was Completed, this run returned 5 open finding(s)
```

Nothing leaves the machine until an address is set. Add it to `TOOLS/secrets.local.ps1`, one
address or several separated by commas or semicolons:

```powershell
$env:EP_NOTIFY_TO = 'dq-review@enetpulse.com'
```

Without it the messages stay queued and the run says how many are waiting. That is the opt-in:
a board update is run by whoever is working on a sport, and a feature that starts mailing a list
the day it is merged is one that mails a list nobody agreed to. Messages queued before the
address was set go out on the first run after it is.

| | |
|---|---|
| When it is sent | not by the run. A board run queues and says how many are waiting; `TOOLS/Send-Notifications.ps1` sends, twice a day from Task Scheduler. A board run covers one sport, so sending from inside it would be one mail per sport and a night across sixteen sports would be sixteen mails. Each drain covers everything queued since the last one, so no window has to be configured - the queue is the window |
| What is sent | one message covering every check in it, as a list: sport, check, name, rows, and a link. Twenty reopens across four boards is one mail |
| Where the two links go | the **sport** opens that board's `Overview`; the word at the end of the row opens the **check's own tab**. A reader who wants the sport and a reader who wants the one finding are two different readers |
| What it looks like | text and HTML both, text first. A plain-text mail can only carry a naked URL, and a Google tab link is ninety characters that push the four columns off the screen; HTML gives the row a word to hang the link on. The text alternative is what a client refusing HTML shows and what a search over somebody's mail matches |
| A tab it cannot name | links to the board instead. A tab id is a number Google assigns and one created on this very run has none until Google answers, so the link degrades rather than pointing at whichever tab the document was last left on |
| What is never sent | anything that is not a reopen. A check closing itself on two clean runs, and a superseded spelling being brought up to date, are both in the same list the run reads and neither is news |
| What a check that expects `Non-zero` sends | nothing, ever. The gate is the same `Expected` gate that governs the word itself, so a `Monitor` check whose count jumps is not a reopen and does not mail. This is the thing most likely to be reported as a fault |
| Which numbers it quotes | the open ones, dismissals already subtracted, so the message and the board agree. A reviewer who has marked rows `No Issue / Change` sees the same count in both places, and the message says which count it is |
| Sent twice | no. One transition is one message, keyed on the run's own start, so a board update retried after a transport failure does not mail again |
| Already dealt with | not sent. The queue is written when a run finds something and is a file from then on, so it cannot know that somebody worked through the rows during the day. The board is asked again at sending time and only checks it still calls `Reopened` go out; the rest are named on screen and marked sent, because they were raised and answered. Measured the first day it ran: six of nineteen BMX checks had already been answered by the afternoon drain |
| If the board cannot be read | everything sends. A board that will not read, a check the board does not carry, a status that comes back blank - all send. A network fault that silenced an alarm would be the worst failure here, because it is silent and looks exactly like a quiet night |
| If sending fails | the message keeps its place and goes out on the next board run. After five attempts it is marked `FAILED` and left for somebody to look at |
| What it can cost a run | nothing. By the time this happens the statements have run, the workbook is on disk and the document is current, and none of the three is worth an undelivered message |

The queue is `TOOLS/notifications.local.json`, ignored by git under the same rule as the
credentials beside it. It is a record of what has been said, not evidence of anything, and
nothing may be cited from it. **Being ignored by git does not exempt it from the package
rules** - `Test-Package.ps1` scans the working tree, and this file failed it twice before that
sank in: once for the byte order mark `Set-Content -Encoding UTF8` writes on Windows PowerShell
5.1, and once for the final newline `WriteAllText` does not.

**The transport is the Gmail API on the credentials the board already uses.** A refresh grant
does not carry a scope - the access token inherits whatever the refresh token was granted - so
there is no second client, no second secret and nothing extra to renew. What it costs is one
re-consent, because a refresh token minted before `gmail.send` was added to the scope keeps the
narrower grant for ever:

```powershell
.\TOOLS\Connect-Sheets.ps1 -Force
```

The token is replaced only if the new consent succeeds, so a failed attempt leaves the board
working. Until it is run, a send fails with a 403 whose own message does not say why; the runner
adds the sentence that does.

**The Gmail API has to be enabled in the same Google Cloud project as the Sheets API**, under
**APIs and Services -> Library**. This is a separate thing from the scope and fails the same
way - a 403 - so the two are easy to confuse. They are told apart by the reason Google returns:
`ACCESS_TOKEN_SCOPE_INSUFFICIENT` is the consent, `SERVICE_DISABLED` is the project, and the
runner prints Google's own message either way, which for the second carries the URL that turns
it on. Measured on the first live send, 2026-08-31, where the scope was right and the API was
off.

One more consequence worth knowing before it is switched on: the mail goes out **as the
authorised account**, so a reader sees it from a person rather than from an instrument - set
`$env:EP_NOTIFY_FROM` to name the sender differently if the account permits it.

### The third: a check closed by coming back with nothing

The mirror of `Reopened` and the same shape - one direction, and only where the run knows
something the reviewer's word does not. **The one thing a run can be certain of is that the
finding is gone.** A check waiting on somebody, or part-read, that comes back with its `COVERAGE`
row alone has had its answer, and leaving it open is the board saying otherwise about the single
case it cannot be wrong on. Found by hand it costs a reviewer one row at a time across every
sport.

| | |
|---|---|
| What triggers it | the cell reads one of the five words below, **and** the check ran and returned a result, **and** `Findings` after dismissals is zero |
| Written | `Completed` |
| The five | `Other Team`, `IT Fix` and `On Hold`, added 2026-08-27, which say the reading stopped and is waiting on somebody. `Reviewing`, added 2026-08-28, which is the same reading still running - keeping it apart from `On Hold` said a review in progress is less finished than a review paused, which nobody meant. And `Reopened`, added the same day under a guard |
| The guard on `Reopened` | it closes only when **the run before it was also clean**. This is the one word the run writes itself, and without the guard a check whose rows come and go would be raised on one run and put out on the next by the same mechanism, with nobody ever seeing it red - the board is where reviewers look, and an Overview status change is not written to the `Review log`. A previous count that is missing or does not parse is not a clean previous run |
| What does not trigger it | a check that failed or was skipped. Both put a word where the count goes - `ERROR`, `SKIPPED` - and both would otherwise read as zero findings and close a check nobody has answered |
| Still never closed | `Clean` and `Monitor Only`, which are already conclusions, and `Skipped`, which says the reading never started |

The rule for `Reopened` before 2026-08-28 was that the run never writes it back: a run may
contradict a conclusion, but forming one is not its to do. What changed is not that argument but
its cost - a row fixed months ago sat red until somebody scrolled past it, and there is nothing
there for a person to decide, because the run raised the word and the run can see it no longer
applies. The guard is what keeps the original argument intact.

### A withdrawn check leaves the board

A check `POWERBI_REGISTRY.md` records as `Deprecated` has its Overview row deleted and its tab
deleted with it, on every run and not only on a complete one. The registry is where a CheckID is
permanent, and the row there keeps its `Deprecated` status for good; the board is a work list,
and a check that no longer runs is not work. Thirteen such rows had accumulated across the
fifteen boards by 2026-08-28, each one a line every reviewer reads past for ever.

**What it costs is stated rather than hidden: a comment somebody wrote against that check goes
with the row, and no run can rebuild it.** That is why it was not done before. It is accepted
now because the conclusion worth keeping about a withdrawn check is why it was withdrawn, and
that lives in the sport file and the registry rather than in a cell. Every removal is named on
the run that makes it, with whatever the Status cell had held.

| | |
|---|---|
| What triggers it | the registry row reads `Deprecated`, **and** the run did not produce a result for the check |
| What does not | a withdrawn check that ran anyway. The registry and the selection disagreeing is a state worth surviving: this run measured the check, and deleting the row would delete a measurement that was taken |
| When it is applied | after every value write and before the sort. Deleting a row shifts every row beneath it, so doing it in the structure batch - which is sent first - would land every write of the run one row out. Within the batch the deletions go bottom-up for the same reason |

Seeding uses the same vocabulary: an informational check opens on `Monitor Only`, a check that
came back with its `COVERAGE` row alone over a real population opens on `Clean`, and everything
else — including every failure — opens on `Not reviewed`.

Five columns ship hidden. `Signal` and `Signal reason` at `M` and `N` are the runner's own
classification, settled before the run and unchanged by reading it. `Object` at `C` is not
among them: it is the column the board is worked through by. `Eligible`,
`Prev findings` and `Prev eligible` at `R:T` joined them on 2026-08-17 at the reviewers'
asking: all three are context for a number rather than the number, and `Change` and `Verdict`
already answer which way a check moved. Nothing is dropped: unhiding brings back every value,
and all five travel in `_summary.csv`.

**A full sport pass states the whole row: the six are closed and every other column the board
writes is opened.** Hiding used to happen once, on the run that created `Overview`, and used
only to add — so a board hid whatever it had ever hidden, and its layout became a function of
its own history rather than of `Sheets.ps1`. One run on 2026-08-17 proved that three different
ways: BMX came out with the six, Cycling with four of them, and Triathlon with twelve, hiding
`Expected`, `Findings`, `Change`, `Verdict`, `Last run` and `Trends` — the columns a reviewer
opens the board to read. A column inserted in the middle of the row carries its neighbour's
hidden flag and shifts everybody else's along, and nothing ever put any of it back.

The cost is stated rather than hidden, and it runs both ways: a column somebody opened closes
again on the next full pass, and one they closed opens on it. A partial run touches neither, so
re-running one check after a reported fix does not repaint a board somebody is reading.

**A board written before a column existed has room made for it rather than its rows rewritten.**
The run compares the header it finds against the column list it writes and inserts what has been
added since, before any value is sent, so what is already in the row is pushed right along with
it. A row the run does not rewrite — a check that has stopped running — lands back under its own
headings, and one it does write goes into the layout the insertion just made. Only insertion is
migrated: a column removed or moved would mean deleting or reordering cells holding somebody's
data, so the whole migration is abandoned rather than half applied.

A check tab is migrated differently, by placing its two identity rows by name. `insertDimension`
takes the whole column, and on a check tab rows 1 and 2 are the identity while row 5 down is the
result — the first version of this pushed a column through every result table on the board.
Nothing moved and the tables were rebuilt at their proper width immediately, but Sheets had
already named the column it briefly saw, and 107 tabs came back reading `Column 11` beside their
result headers.

A check tab is `A` to `O`: the identity, then `Comment` and `Check By`, then the same
comparison block the board carries, then `Category` and `Parameters`. `Signal` and `Signal
reason` are not among them. They classify the check rather than describe what it returned, and
they were settled before the statement was sent — two columns of noise on a tab somebody opened
to look at findings. `Overview` still carries both, hidden.

Rows 1 to 3 of a check tab are a table of their own, named for the check's number and what the
block is — `DQ_104_Overview`. It exists for the same reason the result table below it does: a
named block is one a sort or a filter will not run past, and without it a filter set on the
results reaches up into the identity and hides it. The name carries underscores because a table
name is a formula identifier; the heading in `A1` carries the spaces. `Return to Overview` in
`A3` is bold and in Google's link blue, so the one control on the tab reads as a control rather
than as another line of the identity above it.

The `SQL` tab is shared: one block per check, and each check tab's `C2` points at a row number
in it. A run therefore **merges** into it rather than rewriting it from what the run held. The
order the tab already has is kept and a check new to it is appended, which leaves most row
numbers still; `C2` is rewritten for a check this run held, and for one it did not whose block
moved underneath it. Rewriting the tab from the run instead — which is what it did until
2026-08-10 — meant a run of a single check cleared the column, left its own statement alone on
it and pointed every other check's `C2` at a blank row, which looks exactly like a working link.

Overview's `Comment` mirrors the check tab's `E2`, as it does in the workbook: the comment is
written once beside the rows that provoked it, and read from the board that lists every check.
The formula is seeded when the row is created, and afterwards on any run where the cell is
still empty — an empty cell holds nothing of anyone's, so seeding it costs nothing, and it is
the only way a row written before the mirror existed ever gets one. A cell with anything in
it, formula or typed text, is left alone.

The mirror is one way and cannot be two. A cell holds a value or a formula and never both, so
two cells cannot each feed the other. Typing into Overview's `Comment` replaces the formula and
that row stops following its tab, recovered by clearing the cell and running again. This
direction was chosen because losing a mirror costs a mirror, while a mirror on the check tab
would have put the words somebody wrote at the same risk.

It is also the one thing a run sends as `USER_ENTERED` rather than `RAW`. Everything else is
data — a name beginning with a hyphen, a value Sheets would read as a date — and has to arrive
as what the database returned; a formula sent that way arrives as the literal text of one.

### Reviewing one finding at a time

`Comment` and `Check By` are about the check. A tab holding a thousand findings has one of
each, and somebody working through those findings needs to mark the one in front of them — so
every result block carries two more columns to the right of whatever the statement returned:

| Column | Holds |
|---|---|
| `Review Status` | what was concluded about this one finding — a closed list |
| `Review Note` | why, in the reviewer's own words — free text |

The split is by convention rather than in the code: either column being filled marks the row,
and both travel together. `Review Status` is the one a column is filtered and counted by, which
is why it holds a word and not a sentence — a paragraph there makes "how many of these 63 are
closed" unanswerable, and it is the question the column is for.

It offers three values, drawn from what was written rather than from what a vocabulary ought to
contain:

| Value | Colour | Means |
|---|---|---|
| `Fixed` | green | corrected in the database |
| `No Issue / Change` | green | looked at — either not a defect, or nothing to change |
| `In Progress` | blue | being worked on |

`No Issue / Change` reads in the same green as `Fixed` from 2026-08-31. The two are different
conclusions and the grey used to say so, but what a reviewer scanning a tab wants from a colour
is whether a row is closed, and both of these close it. `In Progress` is the one that is still
open and keeps a colour of its own. The values stay distinct in the cell and in the `Review
log`, so nothing that counts them is affected — only the reading is.

The column is also sized to hold `No Issue / Change` whole. Every other column of a result block
is sized from its header, and here the header is the shorter half — thirteen characters against
seventeen — so the longest value used to arrive clipped. The width is computed from the list, so
adding a value widens the column with it.

`No Issue / Change` carries both words because both were written and they turned out to mean
one thing. 610 cells held five spellings of four ideas, and `no issue` appeared only on the
stray-participant check while `no change` appeared only on the year-gap check — never side by
side. Two checks' words for the same outcome, not two outcomes. Folding them under one value
that names both keeps either reviewer's reading legible.

`For IT` was considered and left out: the check-level `Status` already has `IT Fix`, and nobody
has yet needed to say it about a single row. Adding a fourth value costs one line and the
migration below makes it harmless, so the list stays as small as the evidence supports.

### A conclusion belongs to the reading it was reached about

**All three values are carried to the next run only against a row that comes back identical.**
Every other note goes to the `Review log` with the reason. A note is found by its key — the
`check_type` and the id columns — and then the rest of the row is compared before it is put
back, so a finding that stayed under the same key while its counts, names or values moved comes
back unreviewed rather than green.

Until 2026-08-26 only `Fixed` was held to this, on the reasoning that the other two judge the
object rather than the reading: this organization is a neutral entry, this stage is being
corrected. What reviewers write does not support it. `Same with the source` sits on 176 of the
183 rows of one Artistic Gymnastics tab, and it is a claim about the reading — let the row come
back saying something else and the sentence is untrue of it while the cell still looks settled.
`In Progress` says a colleague is looking at this row, which is no less about the reading.

The mechanism was already in production for `Fixed` and had fired: of the 991 `Fixed` marks that
board has seen, 990 left the result on their own, one came back under the same key holding a
different reading and was parked in the log, and none was inherited by a changed row.

#### `Fixed` is the exception, and says why it is still there

**A `Fixed` row that comes back keeps its mark, and its note is rewritten to say why.** By the
user's decision of 2026-08-31. `Fixed` is the one value that makes a prediction — the thing
described is gone, so the row should be too — and a row that is still in the result has refuted
it. Before this the board said nothing about that: an identical reading carried the mark over in
silence, and a changed one threw it to the log, so either way the reviewer met their own green
row again with no idea why.

| What the row did | `Review Status` | `Review Note` becomes |
|---|---|---|
| came back identical | stays `Fixed` | `No Change` |
| came back reading differently | stays `Fixed` | `Other issue for the same event` |

The second is the reading the rule above would have dropped. Under the same key, a different
reading means the object was corrected and something else about it is wrong now — a different
finding wearing the same key, rather than the same one persisting — and telling the reviewer
that is worth more than clearing the cell.

**The sentence it replaces goes to the `Review log`, not the bin.** The cell answers "why is this
back" and the log goes on answering "what did anybody conclude about it", so nothing a reviewer
took the trouble to write is lost. A `Fixed` row with no note of its own logs nothing, because
nothing was replaced.

The exception is narrow on purpose: only `Fixed`, because only `Fixed` predicts its own
disappearance. `No Issue / Change` and `In Progress` assert nothing about the next run and
follow the rule above unchanged.

**A note with no reading behind it is carried on the key alone.** That is the one exception and
it is deliberate: a note rescued out of `eligible_count` by the legacy path below was never read
as part of a row, so there is nothing to compare it against, and dropping it for want of a
comparison nobody took would throw away exactly what the rescue exists to save.

Each run names what it parked, per check, on the console. A statement whose values do not survive
the round trip through Sheets would park every note it holds on the same run, and a `Review log`
nobody opens is where that would hide.

`$SheetsRowReviewLegacy` renames what was written before the list existed — `fixed` → `Fixed`,
`no issue` and `no change` → `No Issue / Change`, `in progress` and `in prog` → `In Progress`.
It is applied wherever a note passes through, so a cell reaches its column already spelled the
way the dropdown offers rather than being flagged by the run that introduced it. A spelling not
listed is left exactly as written: `not found` is the one such cell, and guessing which of the
three the reviewer meant would be inventing their conclusion rather than recording it. Sheets
flags it, which is the right way for them to be asked.

A former heading is still recognised. A tab is found by its heading, so renaming a column makes
every existing one invisible to the next run — and invisible here means cleared and rewritten
empty, the exact loss these columns were added to stop. `$SheetsRowReviewFormerColumns` lists
what the block has been called before, and a tab written under an old name is read and rewritten
under the current one without anybody touching it.

They exist because there was nowhere else. On Triathlon the reviewers used `eligible_count`,
which is the coverage column and is overwritten every run: 388 cells of real review sitting in
the one place guaranteed to be destroyed. Nothing in the runner authors either column.

Free text rather than a dropdown, deliberately. The words reached for — *fixed*, *no issue*,
*in progress*, *not found*, *no change* — are a vocabulary nobody has agreed yet, and a closed
list would reject every cell already written. `Status` went the other way for a reason that does
not apply here: it is read across sports to answer how much of the catalogue has been reviewed,
while these are read by the person who wrote them.

**A note is tied to its finding, not to the row it sat on.** Every run rewrites the block, and a
correction removes rows so everything under them moves up — a note left where it was would end
up against somebody else's finding, which reads exactly like a judgement somebody made. So the
run reads the notes off the board first, keys each one, and puts it back beside the finding with
the same key however far that finding has moved.

The key is the row's **id columns**, led by `check_type`. A result carries its audited object's
id by the coverage contract, and ids are the part of a row that does not change while the row
means the same thing; the names, counts and values beside them are payload. Plural forms are not
id columns — `participant_ids` on `GLOBAL-DQ-030` is a list that grows and shrinks as people are
corrected, and keying on it would park a note every time one member of the group was fixed. A
result with no id column at all keys on its whole row, which parks a note whenever anything in it
changed: conservative, and the right failure for findings with no id to be about.

### `History`

Every recorded run of every check, one row per check per run, oldest first within each check.
The board compares this run with the one before it and the `Trends` column carries five points;
this is the rest of the ledger made readable by somebody who will never open a JSON file.

| Column | |
|---|---|
| `CheckID`, `Check Name`, `Parameters` | the statement, named rather than numbered |
| `Run`, `Run date` | the run id, which is the output folder that produced it, and when it started |
| `Findings`, `Eligible`, `Rate` | what the statement returned, out of how large a population, and the share |
| `Change` | against the run before it **within the window** — blank where there is none on the tab |
| `Verdict`, `Status` | what that run concluded at the time, not what today would conclude |

`Findings` here is `All findings`, not `Overview`'s `Findings`. The ledger records what the
statement returned and the board subtracts what reviewers have since marked
`No Issue / Change`, so the same run reads higher on this tab than on the board by exactly
the number of settled findings. That is the right way round for a history: a dismissal is a
reading of the data rather than a change to it, and subtracting today's dismissals from a
run made three weeks ago would rewrite what that run measured.

Long form rather than a run to a column. The obvious pivot is wrong for this ledger: most
entries in it are single-check re-runs made while a statement was being written, and each would
arrive as a column holding one number and a hundred and twenty blanks. A re-run costs one row
here and reads as what it was.

A run where the check failed carries no count and no rate, so a gap cannot pass for a zero, and
nothing after it is measured against an error. A check that has stopped running keeps its rows,
for the reason its tab is kept: a reading of a population nobody can take again.

**The window is the last 40 runs, and the oldest falls off the end to make room for the newest.**
`$SheetHistoryRuns` in `TOOLS/Run-Query.ps1` sets it. Forty is a year of weekly runs; it holds
every recorded run of six of the twelve sports as this is written, and the largest tab it
produces is around 1700 rows — one range write against the eleven hundred a board already
sends, and about two seconds of the minutes a board run takes.

**Nothing is deleted from the ledger to keep the window this size.** The tab is a window onto
`RUNS/<Sport>.json` and never a second copy of it; `-History` still reads every run ever
recorded, and raising the number brings older runs straight back onto the tab.

The tab is rewritten whole each run — cleared first, because the window shrinks as well as
grows and rows that have fallen off the end would otherwise sit below the new block dated by
nothing. Every row on it was generated and none of it is anybody's, so there is nothing to
carry over. It is written after the run's own numbers are known but before the ledger is
appended to, so this run's row is on the tab under the run id the ledger is about to file it
under, and the two cannot disagree.

It is a record of what runs returned, and `It is a record, not evidence` below applies to it
exactly as it applies to the ledger it is drawn from.

### `Review log`

What could not be put back. A check that returned 1130 findings and now returns 800 says nothing
about the 330 that went, and the reviewer who marked half of them cannot tell a correction from a
scope that moved underneath them. Each dropped note is written down with the reason:

| `Why` | Means |
|---|---|
| the finding is no longer in the result | the row is gone — corrected, or out of scope now |
| the finding under that key came back reading differently | the row stayed, and says something else than it did |
| more than one finding in this result carries this key | the note cannot be told which of them it is about |
| the check was re-shaped | the columns the key is built from are not the ones the note was written against |
| the row was marked `Fixed` and came back, so its note was replaced on the board | the mark stayed and the cell now says why the row is still there |

The last of them is not a dropped conclusion. The row keeps its `Fixed` and the reviewer's
sentence is kept here because the cell it sat in now holds `No Change` or `Other issue for the
same event` instead; see `Fixed is the exception` above.

The second is not a fix and must not read like one. `GLOBAL-DQ-030` went from one row per stray
participant to one row per statistic on 2026-08-11, and its notes were keyed on a column the new
result no longer emits — every one of them was parked, none was guessed onto a new row.

The tab accumulates and is read backwards: from a count that surprises somebody, to the run that
changed it. It is rewritten whole each run from what it already held plus what this run dropped —
nothing on it is anybody's, every row was generated, and rewriting is what stops a failed run
leaving half a block behind. A board where nobody has written a note has no such tab.

Reading the notes back costs two requests and usually touches almost nothing. The reviewer
columns alone are asked for first, and Google stops a range at its last non-empty cell, so a tab
nobody has written on comes back empty; only the tabs that returned something are then asked for
their id columns.

### The copy taken before the tabs are cleared

A check tab is cleared through `AZ` and rewritten from the notes read off it minutes earlier.
The clear has to reach that far — the reviewer columns sit to the right of whatever the
statement returned, and stopping short of them leaves last week's notes standing beside this
week's rows, which is the one failure the whole mechanism exists to prevent. Between the clear
and the write, though, those columns are on the board nowhere and in the run's own memory only.

That window is the `writing values` phase, and it is not short: **51.8 to 82.5 seconds** across
the runs recorded so far. A run that dies inside it — a refused batch, a dropped connection, a
cancelled console — takes every note with it. The same failure has already happened once: the
SQL catalogue tab lost 105 of Golf's statements on 2026-08-20, and the loss looked exactly like
correct behaviour. That tab was moved to overwriting in place, which a check tab cannot be,
because its result shrinks and the stale rows underneath have to go.

So the notes are written down first, into the run's own output folder:

```text
reviewer notes before clear 30.08.2026 11-42-07.json
```

It holds the document id, the run it belongs to and every note as it was read — the key that
puts it back beside its finding, the `Status`, the `Comment` and the row fingerprint. The run
names the file on the console as it writes it, because the run that needs it is the one that did
not finish, and this is its last legible line.

It is written only when there is something to clear and there is something to lose, it is
stamped rather than overwritten — two failures in a row would otherwise have the second write
notes read off an already-emptied board over the first one's copy — and a failure to write it is
reported without stopping the update. Abandoning a run to protect a backup would be the larger
loss.

Nothing reads it back automatically. It is a copy for a person to restore from, and restoring is
a decision, not a step.
### Pointing a sport at its document

Create the Sheet yourself, share it with whoever reviews, and give the runner its id once —
the part of the URL between `/d/` and `/edit`:

```powershell
.\TOOLS\Run-Query.ps1 -Sport Artistic-Gymnastics -RunAll -SheetId 1qyz...uris
```

The id is recorded in that sport's `RUNS/<Sport>.json` **after** the document has taken a
write, so a mistyped one never becomes the sport's remembered address. From then on the
periodic run needs nothing:

```powershell
.\TOOLS\Run-Query.ps1 -Sport Artistic-Gymnastics -RunAll
```

The document is created by a person rather than by the runner on purpose. One made through
the API is born in whoever authorised it's Drive with no one else on it, and sharing is then
a manual step anyway — later, and in a place nobody thinks to look.

While the title is still Google's own `Untitled spreadsheet`, the first run names it
`DQ <Sport> Enetpulse`, or whatever `-SheetTitle` says. A title somebody chose is never
overwritten: titling the document is a decision, and putting the runner's name back every
week is the same defect as overwriting a comment.

A title the runner itself gave is not such a decision, so a change to the naming pattern
reaches the documents named under the old one — `Enetpulse DQ - <Sport>` was the pattern until
2026-08-09 and is corrected on the next run. `$SheetsFormerTitles` in `TOOLS/Sheets.ps1` is
the list of patterns this runner has used, and the only thing that may go in it. Every name
outside that list belongs to whoever typed it.

A run that mixes sports updates no document, because the document is per sport and there is
no honest way to guess which of two a mixed run belongs to. `-TestRun` skips it as it skips
the ledger, and `-NoSheet` skips only the document for a run that should still be recorded.

**A failure here does not end the run.** By the time the document is written the statements
have all executed and the workbook is on disk, so an expired token or a revoked share must
not throw that away. It is reported, and the next run brings the document up to date.

### Authorising, once

The document needs a Google account, and the account is authorised once per machine:

```powershell
.\TOOLS\Connect-Sheets.ps1
```

It opens a browser, waits for the account to approve, and writes the refresh token into
`TOOLS/secrets.local.ps1`, which `.gitignore` excludes alongside the Query Builder
credentials already there. Every later run exchanges that token for an access token by
itself, with no browser and no interaction.

Before it can work, two values from Google Cloud Console must be in that file:

```powershell
$env:EP_SHEETS_CLIENT_ID     = '....apps.googleusercontent.com'
$env:EP_SHEETS_CLIENT_SECRET = 'GOCSPX-....'
```

They come from **APIs and Services -> Credentials -> Create credentials -> OAuth client ID**,
with application type **Desktop app**, in a project that has the **Google Sheets API**
enabled. A Desktop client accepts any loopback port without registering it, so nothing in the
console has to match anything here.

**Set the OAuth consent screen to `Internal`, not `External`.** An External app sits in
`Testing` status, and Google expires its refresh tokens after seven days — so the runner would
work for a week and then fail with `invalid_grant` until somebody authorised it again. Internal
has no such expiry. If a later run does start failing that way, the token was revoked, and
`Connect-Sheets.ps1 -Force` replaces it.

### How much of a result reaches the document

Google caps a spreadsheet at **10 million cells**, and the cap is per document, not per tab —
a sport is around fifty checks in one permanent file. A 14 000-row missing-value check is
about 1% of that and writes in full; the problem is the handful of statements that return six
figures, where one check can take a sixth of the document. Sheets is also slow to open and
scroll well below the cap, and writing that many cells over the API costs minutes per run.

So a check writes at most **50 000 rows** into the document, and a tab that was cut says so
on its own face — `50 000 of 214 338 rows. The full result is in <run folder>` — because the
person reading it a week later has only the tab. The full result is in the `.xlsx` snapshot,
which is still written and still frozen per run.

That number was measured rather than guessed. All six documented sports were run on
2026-08-08 — 496 checks, no failures — and what it found was that the first figure written
here, 20 000, was tight in the wrong place:

| | |
|---|---|
| Largest single check | `Curling-DQ-041`, 17 626 rows |
| Largest sport in total | Curling, 79 523 rows over 105 checks — about 636 000 cells |
| Six-figure results | none, under each sport's documented scope |

Three Curling checks sat within 12% of the old cap, where one heavier import would have begun
truncating a legitimate result — while the document that cap was protecting was at 6.4% of
Google's limit. 50 000 is about three times the largest count seen and still roughly 4% of a
document for one check, so the guard against a pathological result survives without
threatening anything real.

Worth re-deriving again if a sport is ever run outside its documented scope. Soccer sport-wide
is the known six-figure case, and it does not arise under the 28 client templates
`SPORTS/Soccer.md` scopes it to — narrowed, Soccer was the *smallest* of the six.

A plan that would write more than 8 million cells prints a warning rather than truncating
itself: the answers are to drop a check from the document, tighten a scope or split the sport,
and none of those is the runner's to choose silently.

### It is a record, not evidence

`RUNS/` is inside the working copy and tracked in git, which every other thing a run writes
is not. That is the point — a per-machine file under the output root has no history, no
backup and no way to reach a colleague — but it places the ledger next to a rule it must not
be mistaken for.

`CLAUDE.md` is explicit that results produced by this runner are execution output and never
evidence, and that stands unchanged. The ledger records what a run returned; it does not make
any of it a structural finding. A finding still enters the repository only through the
`PREPARE_DOC_UPDATE` sequence in `WORKFLOW.md`, and a coverage count still does not belong in
`DATABASE.md` or a sport file. What the ledger is for is the next run, not the next document.

## The nightly pass

A run every night across the opened sports whose only job is to notice that something which was
clean has stopped being clean, soon after it happens rather than whenever somebody next runs a
full board.

```powershell
.\TOOLS\Invoke-NightlyRun.ps1 -WhatIf     # choose and report, run nothing
.\TOOLS\Invoke-NightlyRun.ps1             # every sport with a ledger
.\TOOLS\Invoke-NightlyRun.ps1 -Sport Curling
```

**It selects rather than narrows.** Only a check that is currently closed can newly fire: one
already returning findings is already open on the board and in front of whoever is reviewing it,
so running it again tonight tells nobody anything. Narrowing the *scope* was measured and
rejected - on Cycling, current-year against the whole board was 21m13s against 9m28s, 55 per
cent saved, but 47 of 125 checks gained under 0.2 seconds each and a narrowed run returning zero
proves nothing outside its window. Selection saves far more and costs nothing.

| | |
|---|---|
| What runs | a check whose last recorded run returned zero findings over an `eligible_count` above zero, whose expectation is `Zero`, whose status was `OK`, and whose reviewer status is `Clean`, `Completed` or `Reopened` |
| Why those three statuses | each is a conclusion a result can contradict. `Not reviewed` and a blank cell carry no conclusion; `On Hold`, `IT Fix` and `Other Team` are waiting on somebody else; `Monitor Only` expects a count for ever; `Skipped` and `Deprecated` are out of the reading. Measured first: only one check in the package is both handed off and closed, so the filter costs nothing against those and exists for the two that matter |
| Where the status comes from | `run.review` in the ledger, written from what the board held when the last run read it. It is **not live**: a status changed this morning is not seen until the next board run |
| How much runs | as much as fits a budget of database time, cheapest first, with a slice kept for the expensive tail by least recently run. 4.5 hours by default |
| Why a budget and not a threshold | a threshold in seconds rots the way a hardcoded list of CheckIDs does. Under a budget the effective ceiling falls on its own as sports accumulate, in the order the cost table says to give things up in |

Today that is **779 checks and about 67 minutes** of database time across sixteen sports, plus
roughly a minute a sport writing boards. The ceiling binds on nothing yet; it starts binding at
around 26 sports once the review has closed most of what is currently open.

### It writes to the board

A check the pass finds is written `Reopened` by the same rule a full run uses, and the
notification goes out through the machinery that already exists - see **Being told a check
reopened** above. That is deliberate on two counts. A reviewer who follows the message meets the
red chip rather than a green one the message has just contradicted. And "report this once" is
then a consequence rather than a second rule to keep true: a check written `Reopened` is no
longer `Clean` or `Completed`, so the next night cannot reopen it again.

A partial run is safe on a board by construction. Every whole-board behaviour in
`New-SheetsMergePlan` is gated on `-Complete`, which only a `-RunAll` run sets; rows the pass did
not run keep the last full run's numbers rather than being blanked, marked or removed.

**It does not write to `RUNS/`.** The pass runs with `-NoLedger`, which is narrower than
`-TestRun`: the board is updated, the ledger is not. Measured on the first pilot, a nightly run
of 20 checks added 747 lines to one sport's ledger - about 29,000 lines and a megabyte a night
across sixteen sports, in files that are in git. What that costs is worth knowing rather than
discovering: the next run still compares against the last *recorded* run, so a night's numbers
are not what the morning's board is read against, and the guard that closes `Reopened` after two
clean runs counts recorded runs, which means full boards rather than nights.

### What it leaves behind

`TOOLS/nightly.local.json`, ignored by git under the same rule as the credentials beside it. It
holds one thing: when each check last ran at night, so the rotation moves through the expensive
tail instead of sweeping the same corner of it. Losing it costs a rotation that starts again from
the cheapest, which is what the first night does anyway.

A sport that fails does not end the pass, and its checks stay in the rotation rather than being
recorded as done. One broken board must not silence fifteen others.

And `TOOLS/nightly.local.log`, appended each pass and ignored by git under the same rule. Added
2026-09-01, because until then a night left **no trace at all**: Task Scheduler captures nothing,
`-NoLedger` means `RUNS/` is not written, and the board is no help because a partial run leaves
the rows it could not run holding the last full run's numbers. A sport that failed, a statement
that timed out at the gateway, the seconds each one cost - none of it was anywhere the next
morning, and a broken night read exactly like a quiet one.

It is a `Start-Transcript`, not lines written by hand, because most of what is worth keeping is
printed by `Run-Query.ps1` rather than by the pass: the per-check line with its rows and seconds,
the parameters it resolved, the board it wrote. Those go to the host, which a transcript captures
and the pass's `| Out-Null` does not touch. `-WhatIf` writes none - it is a look at the selection
rather than a pass - and `-NoLog` turns it off. A log that cannot be opened is reported and the
night runs anyway. At about 850 lines a night the file rotates once past 5 MB, into
`nightly.local.log.1`, which bounds it at two files and roughly two months.

## Batch behaviour

More than one matched CheckID switches to batch mode.

- Per-file formats write one file per CheckID plus `_summary.csv`; a workbook writes one
  `<Sport>.xlsx`.
- A failing check is recorded as `ERROR: <server message>` and the run continues. Nothing
  is retried automatically, with one exception: a result too large is cut into id windows
  and merged, as described under "A result too large for one request".
- Statements are sent one at a time with a short pause between them.
- Row counts and durations are printed per check as the run proceeds. `_summary.csv` keeps
  both, the `Findings` and `Eligible` counts, the `Signal` and `SignalReason`, the `Expected`
  value and its reason, plus the server's message for a failure; the workbook's Overview tab
  keeps the signal metadata and row count and marks a failure `ERROR`.

A batch inherits the cost constraints in `WORKFLOW.md`. Running the whole catalogue for a
large sport can time out check by check; narrow the scope in the statement rather than
expecting the runner to compensate.

## Which document a sport writes to

`TOOLS/sheet-registry.json` owns the mapping from a sport to its live Google Sheets document.

```json
    "Soccer": {
        "spreadsheetId": "1g5F6v96J9l56MM1yROTf3Y7p9hzYVVAvcuReWqVKnSE",
        "runRequests": false
    }
```

The id was remembered in `RUNS/<Sport>.json` until 2026-09-01, and a run still falls back to
it for a sport with no row yet - saying so, because that is the route this file replaces.
`RUNS/` is a record of what a run returned and nothing may be cited from it, so anything that
has to *decide* where to write reads the registry instead of the ledger.

Resolution order, and it is short on purpose:

1. `-SheetId` on the command line, because somebody naming a document means it;
2. `TOOLS/sheet-registry.json`;
3. the sport's ledger, with a line asking for the row to be added.

Where the registry and the ledger disagree, the registry wins and the disagreement is printed.
One of the two is the board people are reading, and a run that quietly wrote to the other
would be very hard to notice.

`runRequests` says whether that document carries the `Run requests` tab and its Apps Script,
which is what lets a reviewer ask for one check to be re-run from the board. It is `false`
everywhere today; Soccer is being set up first and alone, because the first deploy is scopes,
permissions and an approval and each one after it is about fifteen minutes.

A sport gets its row the first time its board is published. `TOOLS/Test-Tools.ps1` fails if a
sport indexed in `SPORTS.md` has no row here.

## Asking for a run from a board

A sport's document can carry a `Run requests` tab and a `DQ` menu, so a reviewer looking at a
finding can ask for that check to be re-run without a shell. The click writes one row; the
machine does the rest.

| Piece | Where |
|---|---|
| The menu and what it appends | `TOOLS/sheets-apps-script/RunRequests.gs`, pasted into the document's Apps Script project |
| Its scopes | `TOOLS/sheets-apps-script/appsscript.json` |
| Creating and protecting the tab | `TOOLS/Add-RunRequestsTab.ps1 -Sport <Sport>` |
| Who may ask | `requesters` in `TOOLS/sheet-registry.json` |
| Which documents carry it | `runRequests` in the same file |

The script holds no SQL, no credentials and no execution logic. It appends one row and stops.
`Run this check` writes one full CheckID - `Soccer-DQ-023`, never `DQ-023` and never a list -
read from `A2` on a check tab or from column B of the selected `Overview` row. `Run the whole
sport` is the owner's alone and writes the single reserved token `*SPORT*` rather than a list,
so the cell stays one value and the machine maps that value to `-RunAll` itself.

### The part that is a boundary, and the part that is not

`Requested by` is a cell. Anybody with edit access to the tab can type somebody else's address
into it as easily as a CheckID, so **the allowed list guards against a mistake and not against
intent**. What holds is edit access: `Add-RunRequestsTab.ps1` puts a protected range over the
whole tab with no other editors, and the Apps Script is deployed to execute as the owner. The
button then still appends for everybody allowed to click it, and nobody can write the queue by
hand.

Verify it rather than trust the script's own word - the first run on Soccer reported a
protection it had not created, because an absent `protectedRanges` field is `$null` and
`@($null).Count` is 1 in PowerShell:

```powershell
Invoke-SheetsApiWithRetry -Method GET -Path ("$id" + '?fields=sheets(properties.title,protectedRanges)')
```

`requesters.owner` is empty until it is filled in, and while it is empty every `*SPORT*`
request is refused. That is the safe way round: it is the one request that sets `-RunAll`
against the production database.

### Deploying it on a document

```powershell
.\TOOLS\Add-RunRequestsTab.ps1 -Sport Soccer -WhatIf   # say what it would do
.\TOOLS\Add-RunRequestsTab.ps1 -Sport Soccer           # create and protect the tab
```

Then, in the browser: paste `RunRequests.gs` and `appsscript.json` into Extensions > Apps
Script, and add an **installable** `onOpen` trigger owned by the owner account - a simple
trigger runs as the viewer and would not be able to write a protected tab. Reload the document
and the `DQ` menu appears.

Only when that works, run again with `-Register`, which sets `runRequests` to true and is what
makes the worker poll the document. The order matters: a registered document with no menu is a
queue nobody can add to, and a worker polling it for nothing.

The board updater leaves this tab alone by construction. `TOOLS/Sheets.ps1` removes exactly one
tab ever - `Sheet1`, and only while it is still empty - plus the tab of a check withdrawn from
the registry.

## One run at a time on the machine

Every run that sends a statement takes a machine-wide lock first, whoever started it: the
owner's shell, a scheduled task, the nightly pass, the Sheets worker. Two runs that overlap
do not merely compete for the server - they write the same board and append to the same
ledger, and whichever finishes second silently wins.

The lock is a file under `%LOCALAPPDATA%\entpulse-qbun.lock`, held open for writing while
the run lasts. A second run is refused by the operating system rather than by a timestamp, so
there is no stale lock to break by hand and nothing to clean up: when the process ends, by
exit or by kill or by a reboot, Windows drops the handle and the lock is gone with it. The
file itself stays on disk between runs and what it then contains is the last holder's
description, which nothing reads - a description is only consulted when an open was refused.

A waiting run says what it is waiting for and how long that has been going:

```text
  waiting for a full board refresh of Soccer, 113 check(s) (process 29080, running for 4m 12s)
  the machine is free; starting
```

| Switch | Effect |
|---|---|
| *(none)* | Wait up to `-LockWaitSeconds`, which defaults to 2700. Waiting behind a board refresh is the normal case - a mid-sized sport takes about 13 minutes - not a fault |
| `-NoWait` | Do not wait. Print who holds it and exit **75**, which is `EX_TEMPFAIL`: a caller reads it as *busy, ask again* rather than as a failed run |
| `-LockWaitSeconds <n>` | How long to wait before giving up, which also exits 75 |
| `-NoLock` | Take no lock. For reading rows out of a statement while a refresh is under way. It does not make two runs safe to overlap; it says this one accepts that risk |

`-Info`, `-History`, `-ListChecks` and `-DryRun` are outside the lock and stay free while a
refresh runs. None of them sends a statement, writes a result, touches the document or
appends to the ledger, so refusing them the catalogue would cost more than it protects.

`EP_QB_LOCK` overrides the path, which is what the tool tests use to stay off the machine's
own lock.

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
identity headers, semicolons inside string literals, CheckID uniqueness, the DQ coverage
contract, `UNION ALL` column counts, result-level `LIMIT`, registry-versus-SQL agreement,
declared parameters, paste markers, registry row order, the sport index and
`SPORTS/params.json`. Exit code 1 on any failure, so it drops into a hook or a pre-commit
step unchanged.

The semicolon rule is the one whose absence cost the most. The executor cuts a statement at
the first literal `;` without noticing that it sits inside a string, so the remainder never
reaches MySQL and what does arrive ends on an unterminated literal. Nothing about the SQL
looks wrong to a reader, and the whole name-format family — 32 approved checks across six
sports — had been dying that way for as long as those statements existed. Write the character
as `\\x{3B}` inside a regexp, or pick a different one where `SEPARATOR` accepts only a
literal. A `;` in a comment is fine: comments are stripped before execution.

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

### What the suite costs, and where

Three hundred and twenty of the cases run in process and take **ten seconds between them**.
Everything else is the sixteen cases that copy the repository, break the copy in one specific
way, and run `Test-Package.ps1` over it as a child process — that is the only honest way to
test that a rule still bites, and it is also the whole of the suite's running time.

It used to be 1425 seconds and is now 396. Not because copying is expensive — one copy is 86
milliseconds — but because **nothing removed a copy until the process exited**. Sixteen of them
accumulated almost three hundred megabytes of files nothing on the machine had scanned
before, and the validator run over each new copy grew with the tree: 11.4 seconds for the
first, 21.9 for the fifth.

So `Copy-RepositoryFixture` now does two things it did not:

- **leaves `RUNS/` out**, which is fifteen of the eighteen megabytes a copy weighs. Nothing is
  lost by it: `Test-Package.ps1` has excluded `\RUNS\` from its own walk since the change
  before this one, and the validator passes `0 failing check(s), 0 finding(s)` on a copy
  without it;
- **removes the previous copy when it makes the next one.** No case holds two at once, so the
  tree stays at one copy instead of sixteen.

If a case is ever written that does need two copies alive together, that second rule is the one
to revisit — and it will announce itself, because the first copy will have gone.

## Troubleshooting

| Symptom | Cause |
|---|---|
| `cannot be loaded because running scripts is disabled` | Execution policy; see setup step 2 |
| `Login failed for '<email>': <reason>` | The server's own validation message, verbatim |
| `Query failed (HTTP 500): SQL must start with SELECT!` | The server accepts `SELECT` and nothing else. A `WITH ... AS (...)` common table expression is rejected by this rule, so write nested derived tables instead — which is what every statement in the package already does. Window functions are unaffected: the server is MySQL 8, and `LEAD`, `LAG` and `OVER` work inside a derived table |
| `Query failed (HTTP 500): SQLSTATE[...]` | The MySQL error for the statement, verbatim |
| `Missing parameter value(s): X` | A declared `{{X}}` token had no value. Only GLOBAL statements declare tokens |
| `No CheckID matches 'X'` | Wrong ID or pattern; check `-ListChecks` |
| `Request timed out` / `Allowed memory size ... exhausted` | Query-design failures. `WORKFLOW.md` owns the correction |

## Not in git

`TOOLS/secrets.local.ps1`, `TOOLS/notifications.local.json` and everything under `output/`
are excluded by `.gitignore`. Never commit credentials, and never paste a session cookie into a
tracked file.

The notification queue is out for a different reason from the credentials: it is the record of
what this machine has already said, so a second clone replaying it would send every message
again. Losing it costs a duplicate mail and nothing else.
