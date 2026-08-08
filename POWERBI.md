# PowerBI Data Quality

## Purpose

This file defines the permanent policy for user-approved PowerBI data-quality checks.
It is not a registry and does not store full sport SQL.

The PowerBI layer is split into three responsibilities:

| Location | Responsibility |
|---|---|
| `POWERBI.md` | Stable policy, query contract and update workflow |
| `POWERBI_REGISTRY.md` | Compact source of truth for assigned CheckIDs, families, categories, objects, names, query paths and statuses |
| `GLOBAL_DQ/` | Reusable DQ check templates and their parameter contract |
| `POWERBI_QUERIES/<SportSlug>.sql` | Full approved SQL authored for one sport, ordered by CheckID |

Do not copy registry rows or full sport queries back into this file.

## Boundary with structural discovery

Inventories, usage summaries, name-pattern catalogs, value-shape catalogs and drill-down
queries are structural discovery, not DQ violations. Reusable versions belong under
`GLOBAL_QUERIES/` with `GLOBAL-DISCOVERY-NNN` identities.

A DQ check asserts one user-approved missing, wrong, duplicate, invalid or otherwise
actionable condition. Do not assign a DQ CheckID merely because a discovery query
returns counts or unusual values.

## Authorization gate

DQ work starts only after the user explicitly names:

1. the sport;
2. the requested category or problem area.

Examples such as `MISSING_VALUES`, `NO_RELATED_RECORDS`, `DATE_RANGE_MISMATCH`,
`WRONG_GENDER` and `WRONG_RESULTS` are category examples, not active requests. Do not propose, name, number or generate DQ checks outside the category
opened by the user.

## Approval and identity workflow

1. The user chooses the sport and DQ category.
2. Use only confirmed structure for that sport.
3. If evidence is insufficient, return only the required structural SQL and wait for
   its result.
4. Propose candidates only inside the opened category.
5. Wait for the user to select a concrete candidate.
6. Read `POWERBI_REGISTRY.md` and assign the next unused sport-scoped CheckID only
   after approval.
7. Generate the query under the SQL, coverage and scope contracts below.
8. Retain the approved check as a pending PowerBI update.
9. Do not generate PowerBI copy/paste blocks automatically.

CheckID format:

```text
<SportSlug>-DQ-NNN
```

Rules:

- numbering starts at `DQ-001` independently for each sport;
- the SportSlug uses the documented English sport name with spaces replaced by hyphens;
- assigned IDs are never renumbered, deleted or reused;
- an updated version of the same logical check keeps its CheckID;
- a materially different check receives a new ID after separate user approval.

## SQL header and name contract

Every approved query begins with `SELECT` as its first word. `SELECT` is alone on the
first line. Exactly three contiguous description comments follow the first outer
`SELECT`, before `DISTINCT`, the first selected column or any other expression:

```sql
SELECT
    -- CheckID - Curling-DQ-002
    -- Name - EVENT_RESULTS_DUPLICATE_ROWS
    -- What it does: Finds active duplicate result rows for Curling events with the same event participant and result type.
    ...
```

Do not place comments before the first `SELECT`. Do not repeat the identity header under
nested `SELECT` statements or later `UNION` branches.

The Name starts with the canonical object, table or logical storage layer actually
checked. The suffix states the concrete purpose in uppercase words.

Preferred prefixes:

| Prefix | Checked layer |
|---|---|
| `EVENT_` | Event row or direct event-level references |
| `EVENT_RESULTS_` | Event-participant `result` rows and result types |
| `EVENT_SETTINGS_` | Event properties, settings or mapped configuration |
| `TOURNAMENT_` | Tournament or tournament-stage structure |
| `TEMPLATE_` | Tournament-template structure |
| `COMP.RANK_RESULTS_` | Competition-ranking result storage |
| `COMP.RANK_SETTINGS_` | Competition-ranking settings or metadata |
| `PARTICIPANT_` | Participant identity, type, relations or properties |

The prefix list is extensible when a new canonical object or storage layer is confirmed.
Do not start a Name with `DISCOVERY`, `MISSING`, `WRONG`, `INVALID`, the sport name,
the DQ category or the CheckID.

The SQL identity header contains only:

1. `CheckID`;
2. `Name`;
3. `What it does`.

Do not add decorative separator lines or extra identity comments such as `Sport`,
`Category`, `Stands on`, `Applies to`, `Positive control`, `Output`, `Coverage`,
`Notes`, `Assumptions` or `Follow-up`.

## Mandatory coverage contract

Every approved DQ query must self-validate its audited scope in the same SQL statement.
Use the established findings-plus-coverage pattern:

- finding rows use their concrete `check_type` and return `NULL AS eligible_count`;
- a `UNION ALL` branch returns one row with `check_type = 'COVERAGE'`;
- the coverage row returns `COUNT(DISTINCT <audited_object_id>) AS eligible_count`;
- the coverage branch uses the same sport scope, active-row conditions and every
  activated scope-limiting filter as the findings branch;
- the coverage branch counts eligible objects before the violation predicate is applied;
- every `UNION ALL` branch returns the same number of columns in the same order.

Interpretation:

| Result | Meaning |
|---|---|
| Finding rows + `eligible_count > 0` | The query reached its scope and found violations |
| No finding rows + `eligible_count > 0` | The scope was checked and no violations were found |
| `eligible_count = 0` | One of two different things; never clean data. Read the next paragraph before acting |
| Missing `COVERAGE` row or failed statement | The result is not validated |

A zero coverage count has two causes and they call for opposite responses:

| Cause | What it looks like | What to do |
|---|---|---|
| **Misdirected scope** | The statement anchors on the wrong type, shard, owner level or filter, so it audits objects the rule was never about | Correct the scope. The result proves nothing until you do |
| **Sentinel** | The scope is exactly right and the population it audits is legitimately empty today | Nothing. Zero is the check's correct answer for now, and the check exists to stop being silent when the population appears |

The distinction is never readable from the number itself, so the sport file must say which
one applies and why, naming the check. Without that sentence a later reader has to re-derive
it, and the cheap conclusion — "no rows, so it does not apply here" — is the one `CLAUDE.md`
forbids: a sentinel retired on its own zero is silent precisely when the row it waits for
arrives. A sentinel is not a `_checkSignal` value. It is an ordinary `Actionable` check with
nothing to act on yet, and `TOOLS/README.md` owns why none of the three signals fits it.

Coverage values are operational evidence only. They are not structural findings and do
not belong in `DATABASE.md` or `SPORTS/<SportSlug>.md`.

### What the check should return next time

The table above reads one run. A re-run after the findings have been corrected asks a further
question the coverage row cannot answer on its own: was this check supposed to come back
empty? Most are, and some are not — a check whose findings are population-wide keeps its rows
however much is corrected, and one with an agreed remainder keeps exactly that many. Left
unwritten, the answer lives in whoever ran it last.

`SPORTS/params.json` records it per sport under `_expected`, in the same shape as
`_checkSignal` and with the same enforcement; `TOOLS/README.md` owns the vocabulary and the
default each signal implies. The rule that matters here is the one this file already applies
to applicability: **the expectation is read off the check's invariant, never off the last
run's count.** A check that returned nothing today is not thereby a `Zero` check, and
recording it as one is how a sentinel gets retired on its own zero.

## Audited-object granularity

Finding rows report the audited object, not raw child records.

- Return one finding row per distinct audited object; collapse join fan-out with
  `GROUP BY` on that object or `EXISTS` before listing or counting, so the same object
  never repeats across finding rows.
- Express counts as `COUNT(DISTINCT <object_id>)`. A raw violating-record count may appear
  only as an explicitly named secondary column such as `violating_record_count`, alongside
  the specific violation breakdown when useful.
- Order finding rows by the audited object ID or by a per-object aggregate such as
  `violating_record_count`; keep the `COVERAGE` row last.

## Statistics (Comp.Rank) query rules

These rules are mandatory for every DQ or discovery query whose audited object is a
`statistic`, `statistic_participants11` or `statistic_data11` row.

- Always project `template_name` (`tt.name`) — and, when a tournament is in scope,
  `tournament_name` (`t.name`) — as context columns, so every finding is traceable to its
  template without a second lookup.
- Always exclude IOC-purpose templates from both the findings and the coverage branch with
  `AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')`. IOC templates carry structurally
  different data and are out of scope for statistics checks. The exclusion is a base-scope
  filter, so it must appear identically in every `UNION ALL` branch and be applied before
  `eligible_count` is computed.

## Mandatory scope-limiting contract

Every approved query must include at least one safe commented filter suitable for
large sports. Choose the filter from the actual audited object and confirmed relation
path; do not insert a template filter where the audited population has no valid template
relation.

Preferred filters, in order of applicability:

```sql
-- AND t.tournament_templateFK = <tournament_template_id>
```

Use this only when every eligible audited object reaches the selected template through
the query's confirmed relation path.

**Filter the tournament's foreign key, not the template's primary key**, wherever the
statement already joins the tournament that owns the template. The two select the same rows
and are not the same query; `DATABASE.md` `DB-SEM-016` owns why, and measured it at 2.5 seconds
against 28.3 for an identical result. Where no tournament is in scope — a statement auditing
templates themselves — the primary-key form stays correct:

```sql
-- AND tt.id = <tournament_template_id>
```

Both forms are recognised by `TOOLS/Run-Query.ps1 -TemplateIds`, and the alias and column are
read out of the marker rather than assumed.

```sql
-- AND e.startdate >= '<from_datetime>'
-- AND e.startdate <  '<to_datetime>'
```

Use a half-open date range for event-linked data when template scope is unavailable or
insufficient. Use the date column belonging to the confirmed audited path.

```sql
-- AND p.id BETWEEN <from_participant_id> AND <to_participant_id>
```

Use stable primary-key ranges for standalone objects or checks whose purpose includes
missing relations. Replace `p` with the audited table alias.

Rules:

- repeat every activated filter in the findings and coverage branches;
- calculate `eligible_count` after those filters;
- use non-overlapping primary-key batches, for example `1–1000`, `1001–2000`;
- never use `LIMIT/OFFSET` as the audited-scope mechanism;
- never add a relation-dependent filter that would exclude the missing relation the
  query is designed to find;
- use the confirmed numeric sport ID instead of an ambiguous name search when the ID is
  documented.

## Cost and result-size discipline

Every DQ query follows the query cost and result-size rule in `WORKFLOW.md`. Two
constraints are specific to DQ:

- A DQ statement never applies `LIMIT` to its result. On the outer statement or on a
  `UNION ALL` branch it would truncate finding rows or drop the `COVERAGE` row and
  invalidate the result. Control result size through the activated scope filters and
  through audited-object aggregation instead. `LIMIT` inside a scalar subquery that picks
  one value per audited object — `(SELECT r.value FROM result r WHERE ... LIMIT 1)` — does
  not limit the result and is allowed.
- When a batch still times out or exhausts executor memory, reduce that batch — a shorter
  half-open date window or a smaller primary-key range — and rerun the same statement per
  batch. Report each batch's `eligible_count` separately; never merge batches into one
  claimed coverage figure.

The one exception to that last rule is worth stating precisely, because the distinction is
not the arithmetic but what the arithmetic is allowed to claim. Batches chosen by hand are
reported separately because nothing guarantees they tile the population: they are picked at
different times, may overlap, and may leave a gap between them, so their sum asserts a
coverage the run never had. Windows that partition the audited object's own primary key
within a single execution carry that guarantee by construction — every object falls in
exactly one window, and the marker sits in the coverage branch as well as the findings
branch, so each window counts the same population its findings came from. Their sum is
therefore the coverage, not a claim about it, and may be merged into one `COVERAGE` row.

That exception is what `TOOLS/Run-Query.ps1` relies on when it answers a result too large by
cutting the id range up; `TOOLS/README.md` owns the runner behaviour. It does not extend to
date windows, to ranges typed in by a person, or to pieces run across separate invocations —
in each of those the guarantee is an intention rather than a property of the run.

Prefer `EXISTS` over `JOIN` plus `DISTINCT` in the violation predicate, and keep the
findings and coverage branches on the same indexed scope so neither branch scans more
than the other.

## Reusable templates

Before authoring a sport statement, check `GLOBAL_DQ/README.md`. A check whose violation
condition holds for every applicable sport belongs there once, parameterized, rather than
copied per sport: at 110 sports a hand-copied check means 110 places to fix and no way to
detect the copies that drifted.

Instantiating a template for a sport produces a registry row and, when needed, parameter
values in `SPORTS/params.json` — not a new statement. The authorization gate above is
unchanged: a template is not permission to check a sport.

A check stays sport-authored when its condition cannot be expressed through declared
parameters. `GLOBAL_DQ/README.md` owns the qualification rule and the promotion sequence.

## Query-file contract

- Store all active approved sport-authored checks for one sport in
  `POWERBI_QUERIES/<SportSlug>.sql`.
- Never create one SQL file per check.
- Order statements by CheckID.
- The file begins with the first query's `SELECT`; do not add a file header before it.
- Keep each check as one complete statement ending in `;`.
- Separate consecutive statements with the
  `-- ================================================================================`
  banner line used across the repository. `TOOLS/Run-Query.ps1` and
  `TOOLS/Test-Package.ps1` split the file on that banner, so a missing one merges two
  statements into a single unrunnable block. Do not wrap SQL in Markdown fences.
- Execute or paste one statement at a time because the Pool accepts one statement per
  execution. `TOOLS/Run-Query.ps1` observes the same constraint and can run a sport's
  approved checks in one pass; see `TOOLS/README.md`.
- Event-result and statistic-result checks remain separate unless the user explicitly
  approves a combined query.

## Registry contract

`POWERBI_REGISTRY.md` uses this exact column order:

```markdown
| CheckID | Sport | Family | Category | Object | Name | Query file | Status |
```

`Category` identifies the DQ problem family. `Object` identifies the canonical object or
logical storage layer. `Name` must match the SQL identity header exactly.

### Category and the priority it implies

Every category belongs to one of three bands, and the band says what a reviewer works
through first. A broken structure outranks a wrong value, and a wrong value outranks an
empty field: a relation that does not resolve breaks everything read through it, whereas an
empty field is one fact nobody has entered yet. Recorded by decision of 2026-08-05.

| Band | Categories | What is wrong |
|---|---|---|
| `1 Structure` | `WRONG_STRUCTURE`, `NO_RELATED_RECORDS` | the shape or the relation itself |
| `2 Wrong value` | `WRONG_RESULTS`, `WRONG_GENDER`, `WRONG_DISCIPLINE`, `DATE_RANGE_MISMATCH`, `MALFORMED_NAME` | the value is present and wrong |
| `3 Missing value` | `MISSING_VALUES` | the field is empty |

The band is **derived** from the category, never authored per check, so a check cannot
disagree with its own category. The numeric prefix is what makes an ordinary sort produce
the priority order, since the names do not sort that way on their own.

`TOOLS/Run-Query.ps1` carries the map into the workbook and `TOOLS/Test-Package.ps1`
declares the same one, failing any registry `Category` that is missing from it — so a new
category cannot reach a reviewer as a blank on the column meant to say what to do first.
Adding a category means adding it here and in both scripts.

`Family` and `Query file` answer two independent questions and must not be conflated:

| Column | Question |
|---|---|
| `Family` | Which logical check is this? A `GLOBAL-DQ-NNN` template ID, or `—` when the check has no template |
| `Query file` | Which file holds the executable statement? |

`Family` is what lets PowerBI group and compare one check across sports, whose own CheckIDs
differ because numbering restarts per sport. Assign it whenever a template expresses the
same logical check, even when the sport runs its own statement.

For `Approved` rows, `Query file` points either to a `GLOBAL_DQ/` template — the row is an
instantiation and no per-sport statement exists — or to `POWERBI_QUERIES/<SportSlug>.sql`,
which must then contain a statement with that CheckID. A row cannot have both. For
`Deprecated` rows, `Query file` may be `—` when executable SQL was intentionally removed;
the CheckID remains permanently reserved.

The registry is the authority for assigned IDs and statuses. The sport SQL file is the
authority for executable query text. If the two disagree, treat the PowerBI update as
incomplete and ask the user to provide or correct the missing counterpart.

## Manual PowerBI update command

Approved pending checks are converted into file updates only after:

```text
PREPARE_POWERBI_UPDATE SPORT=<Sport>
```

Example:

```text
PREPARE_POWERBI_UPDATE SPORT=Curling
```

When this command is received:

1. review only user-approved checks for the named sport;
2. compare CheckIDs and semantic meaning with the latest `POWERBI_REGISTRY.md`;
3. compare executable SQL with the latest `POWERBI_QUERIES/<SportSlug>.sql`, if it
   exists;
4. remove checks already present and unchanged;
5. validate the header, coverage and scope contracts for every missing or changed query;
6. return one consolidated registry block and one consolidated sport-query block when
   both destinations change;
7. place new registry rows immediately before the exact `POWERBI DQ REGISTRY` marker;
8. if the sport query file does not exist, return its complete initial content;
9. for an existing sport query file, identify the exact CheckID statement to replace or
   the exact CheckID after which a new statement is inserted;
10. never add full SQL to `POWERBI.md`;
11. never edit project files directly, except under the VSCode direct-editing exception
    in `AI_INSTRUCTIONS.md`, when running inside a local IDE and the user has explicitly
    confirmed the specific change.

The registry block uses `POWERBI_REGISTRY.md`. The SQL block uses the exact
`POWERBI_QUERIES/<SportSlug>.sql` path. DQ observations, violation counts, unapproved
ideas and unrelated structural findings are not eligible.

If no approved PowerBI change is missing, answer exactly:

```text
No PowerBI update required.
```

## SQL execution constraints

- Use one SQL statement per Pool execution.
- The first word is `SELECT`, alone on the first line.
- Place the required three comments immediately below the first outer `SELECT`.
- Never write a CTE. The Pool rejects `WITH` outright, because `SELECT` must be the first
  word; nest derived tables instead. `TOOLS/README.md` owns the server-side rule.
- Use the exact approved sport and scope.
- Never carry example IDs from another sport.
- Do not append unrelated queries or suggestions when the user requests one query.

## PowerBI open questions

Only stable questions explicitly raised during authorized PowerBI work belong here.

<!-- MANUAL PASTE ZONE: POWERBI OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
