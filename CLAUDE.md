# Enetpulse Quality Database — working rules

Entry point for an assistant working on this repository inside a local IDE. Project
layout version **2.0**.

`AI_INSTRUCTIONS.md` is the same contract written for a chat bot receiving the files as
uploads. Where the two differ, this file governs local work; every structural, identity,
scope, coverage and statistics rule in `AI_INSTRUCTIONS.md` still applies unchanged.

## What this project is

Two separated goals:

1. document the global Enetpulse database structure and each sport's confirmed use of it;
2. build PowerBI data-quality checks **only** when the user explicitly requests and
   approves them.

Structural discovery never becomes a DQ check on its own initiative.

## One canonical owner per rule

`README.md` holds the source-of-truth map. Read the owner before restating a rule, and
change the rule in its owner rather than in a second copy. The files that own the rules
most often needed:

| Question | Owner |
|---|---|
| Global tables, relations, storage semantics | `DATABASE.md` |
| One sport's confirmed usage | `SPORTS/<SportSlug>.md` |
| Which discovery query to reuse, and its parameters | `GLOBAL_QUERIES/README.md` |
| Which DQ template to reuse, and its parameters | `GLOBAL_DQ/README.md` |
| Scope, cost, `LIMIT`, failure handling, promotion | `WORKFLOW.md` |
| DQ authorization, identity, coverage, storage | `POWERBI.md` |
| Assigned DQ CheckIDs and statuses | `POWERBI_REGISTRY.md` |
| Confirmed per-sport parameter values | `SPORTS/params.json` |
| Running a statement, output shapes | `TOOLS/README.md` |

## Working in this repository

- Apply an approved change directly to the file, but only after the user has confirmed
  that specific change. Without confirmation, propose it — do not write.
- After writing, report exactly which files, CheckIDs and rules changed.
- Load only what the current sport and query domain need. Never load every sport file or
  every SQL file; `README.md` defines the minimal context profiles.
- Run `TOOLS/Test-Package.ps1` after changing any `.sql` file, registry row or paste
  marker. It is the mechanical check for everything listed under "Hard rules" below.
- Run `TOOLS/Test-Tools.ps1` after changing `TOOLS/Run-Query.ps1` or
  `TOOLS/Test-Package.ps1`. It tests those two scripts rather than the package.
- Results produced by `TOOLS/Run-Query.ps1` are execution output, never evidence. A
  finding enters the repository only through the `PREPARE_DOC_UPDATE` sequence in
  `WORKFLOW.md`. `RUNS/<Sport>.json` is the one exception to where that output is written,
  not to what it is worth: the runner appends each run's row, finding and eligible counts
  there so the next run can be compared with it. It is a record of what a run returned, never
  a basis for a structural claim, and nothing may be cited from it. `TOOLS/README.md` owns
  the file; `SPORTS/params.json` `_expected` owns what each check should return once the data
  is corrected.

## Hard rules

Violating one of these silently corrupts the package, so they are repeated here rather
than only in their owner:

- **Identity header.** Every executable statement starts with `SELECT` alone on line 1,
  followed by exactly three contiguous comments: `-- CheckID - `, `-- Name - `,
  `-- What it does: `. Never above the `SELECT`, never repeated under a subquery or
  `UNION` branch. The Name starts with the canonical object or storage layer.
- **One ID, one statement.** A CheckID identifies exactly one executable statement.
  Summary and detail are separate statements with separate IDs.
- **CheckIDs are permanent.** Never renumber, delete or reuse an assigned DQ CheckID. A
  deprecated check keeps its row and its ID; gaps are expected.
- **No DQ without approval.** A DQ CheckID is assigned only after the user names a sport
  and a category and then approves a concrete check.
- **The 200-row gate.** A candidate returning more than 200 finding rows is run and read
  before it is numbered, and what share of those rows is the sport behaving normally is
  established first. Where that is not certain, the check is not written — ask instead. An
  unwritten check costs a question; an assigned CheckID is permanent, so withdrawing one
  leaves a `Deprecated` row forever. `POWERBI.md` owns the rule and records what it is
  measured on.
- **Coverage contract.** Every DQ statement returns finding rows with a concrete
  `check_type` and `NULL AS eligible_count`, plus one `UNION ALL` branch with
  `check_type = 'COVERAGE'` and `COUNT(DISTINCT <object_id>) AS eligible_count` over the
  identical scope. `eligible_count = 0` is never clean data, and is one of two things:
  a misdirected scope that must be corrected, or a correct scope over a population that
  is legitimately empty today, which is a sentinel and needs no change. The sport file
  must say which. `POWERBI.md` owns the distinction.
- **Audited-object rows.** One row per distinct audited object, never one per raw child
  record. Counts are `COUNT(DISTINCT <object_id>)`; raw counts only as named secondary
  columns. `COVERAGE` sorts last.
- **Scope before running.** The database is large enough that an unscoped statement fails.
  Anchor on the sport, activate a narrowing filter on a large sport, summary before
  detail, one shard per execution. `WORKFLOW.md` owns the full rule and the two distinct
  failure modes.
- **Statistics context.** Any statement whose audited object is a `statistic`,
  `statistic_participantsN` or `statistic_dataN` row projects `template_name` and excludes
  IOC-purpose templates identically in every branch.
- **Applicability is structural, never a row count.** A check is `Not applicable` for a sport
  only when the sport does not store the structure the rule reads — no such column, layer or
  relation. A status, type, discipline or value that simply has no rows today is a data
  state, not a structural absence: excluding a check on that basis disables it for the day
  those rows arrive, which is the day it was written for. Never classify from the current
  population; where the two are hard to tell apart, ask. `TOOLS/README.md` owns the signal
  vocabulary, `GLOBAL_DQ/README.md` the prerequisite column.
- **Template filter: the foreign key, never the primary key.** A commented template filter
  reads `t.tournament_templateFK`, not `tt.id`, wherever the statement already joins the
  tournament that owns the template. The two select identical rows and are not the same query:
  keying on the template's primary key makes the optimiser drive from `tournament_template` and
  lose the index path into the statistic shards, and the same result then costs roughly ten
  times as much — measured on Soccer, 2.5 seconds against 28.3, and about a minute per
  Comp.Rank check across a batch. Only a statement auditing templates themselves, with no
  tournament in scope, keeps `tt.id`. The alias belongs to the statement that declares it:
  `tt` pairs with `t`, `tt2` with `t2`. `DATABASE.md` `DB-SEM-016` owns the database fact,
  `POWERBI.md` the query contract, and `TOOLS/Test-Tools.ps1` fails a marker that keeps the
  primary key where a tournament is joined.

- **Paste markers.** A `MANUAL PASTE ZONE` marker is the fixed lower boundary of its
  section. Insert immediately before it, never after; keep it unchanged; never include it
  in inserted text. If it is missing, duplicated or misplaced, report it and stop. Markers
  containing `<SPORT_ID>` are template placeholders, not targets. SQL files use no markers.

## Terminology

`statistic_typeFK = 11` is called **Comp.Rank** in this project. That is deliberate
internal terminology; do not normalize it to the database name "Competition Stats".

## Out of scope

Do not introduce unless explicitly requested: Builder documentation, automatic audit
tooling, legacy QA logic, automatic DQ recommendations, data-repair instructions, and the
`standing`, `standing_participants`, `standing_data` family. Confirmed
competition-ranking structures stay in scope.
