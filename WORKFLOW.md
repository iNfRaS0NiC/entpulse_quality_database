# Manual Documentation and Query Workflow

## Core principle

The user controls investigation, promotion and documentation.

The assistant may answer structural, analytical, custom and experimental SQL requests
directly. Reusable conclusions become pending findings; they do not become project
documentation until an explicit update command is received.

## Request modes

### GLOBAL discovery

Use this mode when an existing entry in `GLOBAL_QUERIES/README.md` answers the requested
structural question.

- Return only the requested statement.
- Replace all mandatory `{{...}}` parameters in the working copy.
- Preserve the `GLOBAL-DISCOVERY-NNN` QueryID.
- Do not save a sport-substituted copy.
- Do not run or return unrelated catalog queries.

### Ad-hoc or custom SQL

An explicit custom, random, experimental or comparative request overrides the normal
catalog-selection sequence.

- Answer the request directly.
- Do not require a matching GLOBAL query.
- Do not force the user to select a predefined structural area.
- Do not promote the query automatically.
- Do not assign a permanent QueryID or DQ CheckID unless promotion is explicitly
  approved.
- If one query is requested, return one query.

### Sport-specific discovery exception

Use `<SportSlug>-DISCOVERY-NNN` only when:

- the required relation path or meaning is genuinely sport-specific;
- no GLOBAL query can represent it through documented parameters;
- the exception is intended for reuse within that sport.

An ordinary one-time ad-hoc query does not require a permanent discovery ID.

### PowerBI/DQ

Activate DQ rules only when the user explicitly opens a sport and category/problem
area. `POWERBI.md` is the only canonical source for the DQ contract.

## SQL identity contract

Every executable or template SQL statement starts with `SELECT` as its first word.
`SELECT` is alone on the first line. Exactly three contiguous identity comments follow
before the first selected expression:

```sql
SELECT
    -- CheckID - GLOBAL-DISCOVERY-007
    -- Name - EVENT_RESULTS_TYPES
    -- What it does: Lists active result types and result codes used by the selected sport.
    ...
```

The header appears only below the first outer `SELECT`. It is not repeated under
subqueries or `UNION` branches.

Identity namespaces:

| Namespace | Use |
|---|---|
| `GLOBAL-DISCOVERY-NNN` | Canonical reusable structural discovery statement |
| `<SportSlug>-DISCOVERY-NNN` | Reusable sport-specific discovery exception |
| `<SportSlug>-DQ-NNN` | User-approved PowerBI/DQ check |

Summary and detail statements are separate executable queries and must have different
IDs.

The Name begins with the canonical object or storage layer, not with `DISCOVERY`,
`MISSING`, `WRONG`, a sport name, category or ID.

## GLOBAL parameter contract

Mandatory textual parameters use uppercase double-brace tokens:

```text
{{SPORT_ID}}
{{STATISTIC_TYPE_ID}}
{{STATISTIC_OWNER_TYPE_ID}}
{{SHARD_ID}}
```

Rules:

- every mandatory parameter is declared in `GLOBAL_QUERIES/README.md`;
- replace every mandatory token before execution;
- never persist a substituted sport value in the canonical GLOBAL file;
- parameters inside physical table names, such as `statistic_data{{SHARD_ID}}`, require
  textual substitution and are not SQL bind variables;
- optional filters remain commented and use angle-bracket examples;
- a query that needs an undeclared sport-specific assumption is not GLOBAL.

## Aggregation and ordering rule

Every discovery and DQ statement is counted and ordered by its audited object, never by
raw child-record volume.

- Each returned row represents one distinct subject — an object ID, a value pattern or a
  value — never one row per raw child record (`result`, `statistic_data`, property, etc.).
- Detail, drill-down and DQ finding statements return exactly one row per distinct audited
  object (event, statistic, stage, participant …); collapse any join fan-out with
  `GROUP BY` on the object or `EXISTS` before counting or listing.
- Express every count as `COUNT(DISTINCT <object_id>)`. A raw record count may appear only
  as an explicitly named secondary column (`value_count`, `violating_record_count`), never
  as the reported object total.
- Order by the audited object ID, or by a per-object aggregate such as the violation or
  record count when severity ranking is more useful; never order so that one object repeats
  across rows. Keep any `COVERAGE` row last.

## Query cost and result-size rule

The database is very large. Assume that an unscoped statement fails. Two different
failures occur and they need different corrections:

| Symptom | Cause | Correction |
|---|---|---|
| `Request timed out` | Server-side cost: unbounded scan, join fan-out, filesort, a function or `REGEXP` on the filtered column, a multi-shard scan | Narrow the scanned population before the statement groups or sorts anything |
| `Allowed memory size of 134217728 bytes exhausted` | Client-side buffering: the executor holds the whole result set in a 128 MB PHP process | Return fewer rows and fewer or narrower columns |

Both are query-design failures, not infrastructure problems.

### Before returning a statement

1. Anchor the scope. Every statement filters on `tt.sportFK = {{SPORT_ID}}` or the
   confirmed indexed equivalent for its relation path.
2. For a large sport, activate at least one narrowing filter — a tournament template, a
   half-open `startdate` range or a primary-key range — instead of leaving every
   scope-limiting filter commented.
3. Return the summary statement before its detail counterpart. A detail or drill-down
   statement runs only for one ID, pattern or value already selected from that summary.
4. When the population size is unknown, size it first with a cheap
   `SELECT COUNT(DISTINCT <object_id>)` over the same `FROM`/`WHERE`, then narrow or
   batch when it exceeds a few thousand objects.

### Statement construction

- Cap detail output with an explicit `LIMIT <n>` (default 500); see the `LIMIT` rule
  below.
- Select named columns only; never `SELECT *`. Return IDs and short keys, and take one
  `MIN(...) AS sample_...` instead of streaming every name or value.
- Use `GROUP_CONCAT` only over a small bounded `DISTINCT` set. On large groups it is the
  most common cause of the memory error.
- Prefer `EXISTS` over `JOIN` plus `DISTINCT` for existence tests: it stops at the first
  matching child row and avoids fan-out.
- Keep every filter index-usable. Compare indexed FK/PK columns directly; never wrap the
  filtered column in a function, `REGEXP_REPLACE` or a leading-wildcard `LIKE`.
  Digit normalization and other value shaping apply to already-scoped rows in `SELECT`
  and `GROUP BY`, never as the driving predicate.
- Resolve descriptive names through the smallest necessary join chain. A long `LEFT JOIN`
  chain added only to display names belongs in a separate small lookup query.
- Use one confirmed `{{SHARD_ID}}` per execution. Never union or scan all statistic
  participant/data shards in one statement.
- Run one statement per execution; do not chain heavy statements.

### LIMIT

`LIMIT` is the correct fix for the memory error and the right default on an ad-hoc detail
listing. It has three boundaries.

- It rarely prevents a timeout. `GROUP BY`, `DISTINCT` and `ORDER BY` on a computed column
  are materialized in full before the limit applies, so
  `... GROUP BY pattern ORDER BY cnt DESC LIMIT 20` still scans the whole scope. `LIMIT`
  short-circuits only when rows can stream in the requested order — no aggregation, and
  `ORDER BY` on an indexed column or none at all. Scope is what prevents timeouts; `LIMIT`
  only protects the executor's memory.
- A truncated result is not evidence. When the returned row count equals the limit, treat
  the result as partial: it supports "these examples exist", never "this is all of them",
  "this is not used" or any count. Raise the limit or narrow the scope before classifying
  the evidence.
- Page by key, never with `OFFSET`. `OFFSET n` still reads and discards n rows, and rows
  shift between pages without a stable total order. Use
  `WHERE e.id > <last_seen_id> ORDER BY e.id LIMIT 500` instead.

`LIMIT` never replaces scope, is never the audited-scope mechanism, and never appears in a
DQ statement — see `POWERBI.md`.

### When a statement fails

Do not rerun the same statement.

1. State which failure occurred — timeout or memory.
2. Narrow one dimension at a time: shorter date window or smaller primary-key batch, then
   drop `GROUP_CONCAT` and name joins, then replace detail with summary, then a single
   template.
3. Return the narrowed statement and name what was narrowed.

A narrowed result describes only the narrowed scope. Never report it as complete coverage
of the sport.

## Evidence classification

After a result, classify evidence as:

| Status | Requirement |
|---|---|
| `Confirmed-schema` | Schema metadata confirms the table, column or relation shape |
| `Confirmed-data` | Successful scoped output demonstrates the mechanism |
| `Confirmed-schema-data` | Independently confirmed by schema and data |
| `Observed-sport` | Confirmed only for the named sport |
| `Open question` | Evidence is missing, partial or contradictory |

A successful complete-layer query returning zero active rows may support `Not used`.
A failed, partial or insufficient query remains `Not checked`.

## Pending structural findings

After interpreting a result:

1. retain only stable reusable structural conclusions;
2. route global mechanisms to `DATABASE.md`;
3. route sport usage to `SPORTS/<SportSlug>.md`;
4. consolidate compatible findings for the same destination section;
5. replace an earlier pending conclusion when later evidence corrects it;
6. do not generate a paste block automatically.

Do not retain transient counts, percentages, current min/max IDs, example row IDs,
temporary samples, status distributions or DQ violation counts as documentation text.

If one discovery confirms both a global mechanism and one sport's use of it, retain two
short pending findings: one global and one sport-specific.

## Documentation eligibility gate

For a documentation update, classify each candidate as:

- `DOCUMENTABLE_STRUCTURE`
- `DOCUMENTABLE_OPEN_QUESTION`
- `TRANSIENT_DATA`
- `DQ_OBSERVATION`
- `DUPLICATE`
- `UNCONFIRMED`

Only the first two are eligible.

Before producing a block, compare semantic meaning with the latest uploaded Project 2.0
files. Do not create a duplicate merely because wording differs.

## Documentation-update commands

```text
PREPARE_DOC_UPDATE LAST_STRUCTURAL_FINDING
```

Processes only the latest confirmed reusable structural finding.

```text
PREPARE_DOC_UPDATE ALL_MISSING_STRUCTURAL_FINDINGS
```

Processes all eligible pending findings in the current chat that are missing from the
latest uploaded files.

```text
PREPARE_DOC_UPDATE SPORT=<Sport>
```

Processes only eligible pending findings for the named sport.

For every command:

- never include unrelated findings or SQL;
- consolidate changes by destination section;
- identify one exact active marker for every Markdown addition;
- identify exact existing content for every replacement;
- return the smallest useful number of blocks.

If nothing is eligible, answer exactly:

```text
No structural documentation update required.
```

## Paste-block format

For an addition:

```text
COPY/PASTE FINDING
File: <exact project path>
Section: <exact heading>
Paste position: Immediately before <exact active MANUAL PASTE ZONE marker>
Text:
<ready Markdown only>
```

For a replacement:

```text
Paste position: Replace <exact existing row or block> in place
```

Never include the marker itself in `Text`.

## Starting a new sport

When `PREPARE_DOC_UPDATE SPORT=<Sport>` is requested for an undocumented sport:

1. add one index row to `SPORTS.md`;
2. create one complete `SPORTS/<SportSlug>.md` file from `SPORTS/_TEMPLATE.md`;
3. replace every `<SPORT_ID>` placeholder with the confirmed numeric sport ID;
4. fill confirmed areas only;
5. leave every other area `Not checked`.

Later updates target only the smallest relevant part of that sport file.

## Promoting an ad-hoc query

Promotion is separate from running the query.

### Promote to GLOBAL

Only after explicit approval:

1. prove the relation path is global;
2. remove sport names and hard-coded sport IDs;
3. declare every mandatory parameter;
4. assign the next unused `GLOBAL-DISCOVERY-NNN`;
5. insert the registry row in `GLOBAL_QUERIES/README.md`;
6. insert the statement in its domain SQL file by QueryID order;
7. validate that one executable statement has one unique ID.

### Promote to DQ

Follow `POWERBI.md`. Do not reuse a discovery ID as a DQ CheckID.

## PowerBI update command

Approved DQ changes are prepared only after:

```text
PREPARE_POWERBI_UPDATE SPORT=<Sport>
```

Use `POWERBI.md`, `POWERBI_REGISTRY.md` and the matching sport query file. Do not
duplicate the DQ contract here.

## File-loading discipline

Load only the files required for the current sport and query domain. Never load all
sport files or all PowerBI query files.

The minimum profiles are defined in `README.md`.

## Re-upload rule

Treat newly uploaded Project 2.0 files as authoritative. Never assume a previously
generated block was pasted unless it is present in the latest file.

## Completion checklist

- [ ] The current request mode was identified correctly.
- [ ] A matching GLOBAL query was reused when appropriate.
- [ ] Every mandatory parameter was replaced in the working copy.
- [ ] One requested query produced one returned query.
- [ ] Each result row is one distinct audited object; raw counts are named secondary columns only.
- [ ] The statement is scoped by an indexed anchor, plus one active narrowing filter for a large sport.
- [ ] Detail output is capped and columns are narrow; no `SELECT *` and no unbounded `GROUP_CONCAT`.
- [ ] QueryID or CheckID is unique for one executable statement.
- [ ] No structural finding was converted into DQ automatically.
- [ ] No documentation block was emitted without an explicit update command.
- [ ] Every Markdown addition targets one unique marker immediately before it.
- [ ] Every replacement identifies exact existing content.
- [ ] No unrelated sport file or query file was loaded or changed.

## Query execution

A statement reaches the database in one of two ways. Both send one statement per
execution and neither changes any rule above.

| Route | Use |
|---|---|
| Content Query Builder Pool UI | Single exploratory statement, inspecting the result in the browser |
| `TOOLS/Run-Query.ps1` | Executing a registered CheckID, and any run producing files |

The runner resolves SQL by CheckID from `GLOBAL_QUERIES/` and `POWERBI_QUERIES/`,
substitutes the declared `{{...}}` parameters and writes results to the screen, to
CSV/JSON, or to one `.xlsx` workbook with a tab per check. It discovers new statements
from disk on every invocation, so a new sport query file needs no registration.

`TOOLS/README.md` is the canonical owner of its setup, command set and output shapes. Do
not restate them here.

Two boundaries matter for this workflow:

- The runner substitutes parameters textually. It does not validate scope, cost or
  identity; the rules in this file and in `POWERBI.md` still apply to every statement it
  sends.
- A batch run does not weaken the cost rule above. When a check fails, the runner records
  the server's message and continues; correcting the statement remains a query-design
  step, and a failed check is `Not checked`, never `Not used`.

## Manual workflow additions

User-approved workflow changes are inserted immediately before the marker below.

<!-- MANUAL PASTE ZONE: WORKFLOW RULES — insert approved additions immediately before this marker; do not move or delete it. -->
