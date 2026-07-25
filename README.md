# Enetpulse Database Documentation

Project layout version: **2.0**

## Purpose

This project has two separated goals:

1. document the global Enetpulse sports-content database structure and the confirmed
   way each sport uses it;
2. build PowerBI data-quality checks only when the user explicitly requests and
   approves them.

Reusable structural discovery SQL is stored once in `GLOBAL_QUERIES/`. A GLOBAL query
may be executed for many sports by replacing its documented parameters; it is never
copied into a separate SQL file for every sport.

## Source-of-truth map

| Location | Canonical responsibility |
|---|---|
| `README.md` | Project boundary, file map and start-here rules |
| `DATABASE.md` | Global tables, columns, relations, storage mechanisms and semantics |
| `SPORTS.md` | Compact index of sport structural files and their status |
| `SPORTS/_TEMPLATE.md` | Template for one new sport structural file |
| `SPORTS/<SportSlug>.md` | Confirmed structural usage and open questions for one sport |
| `GLOBAL_QUERIES/README.md` | Registry, parameter contract and applicability of reusable discovery SQL |
| `GLOBAL_QUERIES/*.sql` | Canonical reusable structural discovery statements grouped by domain |
| `POWERBI.md` | Stable DQ authorization, identity, coverage, scope and storage policy |
| `POWERBI_REGISTRY.md` | Compact index of assigned DQ CheckIDs and statuses |
| `POWERBI_QUERIES/<SportSlug>.sql` | Approved executable DQ SQL for one sport |
| `WORKFLOW.md` | Operational commands, routing and update workflow |
| `CHANGELOG.md` | Short audit of material project changes |
| `VALIDATION_REPORT.md` | Static package, registry and SQL-parser validation result |
| `AI_INSTRUCTIONS.md` | Matching behavior instructions for the user-operated assistant |

Each rule has one canonical owner. Other files may link to it but must not restate the
full rule.

## Non-negotiable rules

- Treat the latest uploaded Project 2.0 files as the only current source of truth.
- Do not use archived findings or Project 1.x files as active evidence.
- Do not convert structural findings into DQ checks automatically.
- Do not assign a DQ CheckID before the user approves a concrete check.
- Do not create one file per finding, table, query or individual DQ check.
- Store one structural file per sport and one approved DQ SQL file per sport.
- Store reusable discovery SQL once under `GLOBAL_QUERIES/`.
- Scope every statement before it runs; the database is large enough that unscoped
  queries time out or exhaust the executor's memory (`WORKFLOW.md`).
- If the user requests one query, return only that query.
- Do not run or return the complete GLOBAL catalog automatically.
- Custom, random and experimental SQL requests are always permitted.
- Documentation and PowerBI paste blocks require their explicit update commands.
- Inside a local IDE such as VSCode the assistant may apply approved changes to project
  files directly, but only after explicit user confirmation; otherwise it returns
  ready-to-paste blocks. The canonical rule lives in `AI_INSTRUCTIONS.md`.
- Builder documentation, automatic audit tooling, legacy QA logic and the `standing`,
  `standing_participants` and `standing_data` family remain out of scope.

## Query-selection order

For a structural SQL request:

1. read `GLOBAL_QUERIES/README.md`;
2. reuse the smallest matching GLOBAL query when one exists;
3. replace only its declared mandatory parameters in the working copy;
4. keep its `GLOBAL-DISCOVERY-NNN` identity;
5. do not save the substituted working copy as another project query;
6. write an ad-hoc query when no catalog entry fits or when the user explicitly asks
   for a custom approach.

A custom query remains ad hoc unless the user later approves its promotion to the
GLOBAL catalog or to a sport-specific discovery exception.

## Normal structural sequence

1. The user names a sport and a structural question.
2. The assistant returns one matching GLOBAL or ad-hoc SQL statement.
3. The user executes it and returns the result.
4. The assistant interprets and classifies the evidence.
5. Reusable conclusions remain pending in the current chat.
6. The assistant returns documentation blocks only after:

```text
PREPARE_DOC_UPDATE LAST_STRUCTURAL_FINDING
PREPARE_DOC_UPDATE ALL_MISSING_STRUCTURAL_FINDINGS
PREPARE_DOC_UPDATE SPORT=<Sport>
```

## PowerBI sequence

PowerBI work starts only after the user explicitly names a sport and a DQ category or
problem area. Approved changes are returned only after:

```text
PREPARE_POWERBI_UPDATE SPORT=<Sport>
```

The complete DQ contract is defined only in `POWERBI.md`.

## Minimal context profiles

### Structural work for one sport

Load:

- `README.md`;
- `DATABASE.md`;
- `SPORTS.md`;
- `SPORTS/<SportSlug>.md`, when it exists;
- `GLOBAL_QUERIES/README.md`;
- only the relevant GLOBAL SQL domain file;
- `WORKFLOW.md`.

Do not load all sport files or all GLOBAL SQL files.

### PowerBI work for one sport

In addition to the structural context, load:

- `POWERBI.md`;
- `POWERBI_REGISTRY.md`;
- `POWERBI_QUERIES/<SportSlug>.sql`, when it exists.

Do not load query files for unrelated sports.

## Universal manual-paste-zone rule

For every Markdown project file:

- insert approved additions immediately before the exact active
  `MANUAL PASTE ZONE` marker;
- keep the marker unchanged and at the end of its destination section;
- never place new content after a marker;
- replace exact existing rows or blocks in place when correcting content;
- treat markers containing `<SPORT_ID>` as template placeholders, not active targets.

SQL files do not use paste-zone markers. Insert or replace their statements by unique
QueryID or CheckID order.

If a required marker is missing, duplicated or not at the end of its destination
section, report the inconsistency and do not guess a paste position.

## Manual project-level additions

Project boundary, layout or source-of-truth changes are inserted immediately before
the marker below.

<!-- MANUAL PASTE ZONE: README PROJECT RULES — insert approved additions immediately before this marker; do not move or delete it. -->
