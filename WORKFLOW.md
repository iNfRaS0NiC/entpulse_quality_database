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
- [ ] QueryID or CheckID is unique for one executable statement.
- [ ] No structural finding was converted into DQ automatically.
- [ ] No documentation block was emitted without an explicit update command.
- [ ] Every Markdown addition targets one unique marker immediately before it.
- [ ] Every replacement identifies exact existing content.
- [ ] No unrelated sport file or query file was loaded or changed.

## Manual workflow additions

User-approved workflow changes are inserted immediately before the marker below.

<!-- MANUAL PASTE ZONE: WORKFLOW RULES — insert approved additions immediately before this marker; do not move or delete it. -->
