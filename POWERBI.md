# PowerBI Data Quality

## Purpose

This file defines the permanent policy for user-approved PowerBI data-quality checks.
It is not a registry and does not store full sport SQL.

The PowerBI layer is split into three responsibilities:

| Location | Responsibility |
|---|---|
| `POWERBI.md` | Stable policy, query contract and update workflow |
| `POWERBI_REGISTRY.md` | Compact source of truth for assigned CheckIDs, categories, objects, names, query paths and statuses |
| `POWERBI_QUERIES/<SportSlug>.sql` | Full approved SQL for one sport, ordered by CheckID |

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
| `eligible_count = 0` | Empty or misdirected scope; do not report the data as clean |
| Missing `COVERAGE` row or failed statement | The result is not validated |

Coverage values are operational evidence only. They are not structural findings and do
not belong in `DATABASE.md` or `SPORTS/<SportSlug>.md`.

## Mandatory scope-limiting contract

Every approved query must include at least one safe commented filter suitable for
large sports. Choose the filter from the actual audited object and confirmed relation
path; do not insert a template filter where the audited population has no valid template
relation.

Preferred filters, in order of applicability:

```sql
-- AND tt.id = <tournament_template_id>
```

Use this only when every eligible audited object reaches the selected template through
the query's confirmed relation path.

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

## Query-file contract

- Store all active approved checks for one sport in
  `POWERBI_QUERIES/<SportSlug>.sql`.
- Never create one SQL file per check.
- Order statements by CheckID.
- The file begins with the first query's `SELECT`; do not add a file header before it.
- Keep each check as one complete statement ending in `;`.
- Separate statements with blank lines only; do not wrap SQL in Markdown fences.
- Execute or paste one statement at a time because the Pool accepts one statement per
  execution.
- Event-result and statistic-result checks remain separate unless the user explicitly
  approves a combined query.

## Registry contract

`POWERBI_REGISTRY.md` uses this exact column order:

```markdown
| CheckID | Sport | Category | Object | Name | Query file | Status |
```

`Category` identifies the DQ family. `Object` identifies the canonical object or logical
storage layer. `Name` must match the SQL identity header exactly.

For `Approved` rows, `Query file` points to the sport file containing the full active
statement. For `Deprecated` rows, `Query file` may be `—` when executable SQL was
intentionally removed; the CheckID remains permanently reserved.

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
11. never edit project files directly.

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
- Do not depend on CTEs when the Pool rejects `WITH`.
- Use the exact approved sport and scope.
- Never carry example IDs from another sport.
- Do not append unrelated queries or suggestions when the user requests one query.

## PowerBI open questions

Only stable questions explicitly raised during authorized PowerBI work belong here.

<!-- MANUAL PASTE ZONE: POWERBI OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
