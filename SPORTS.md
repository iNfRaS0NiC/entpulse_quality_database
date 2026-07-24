# Sport Structural Index

## Purpose

This file is the compact index for sport-specific structural documentation.
Detailed findings are stored in one file per sport under `SPORTS/<SportSlug>.md`.

Do not place full sport findings in this index. Do not duplicate global database
mechanisms from `DATABASE.md`.

## Sport index

| Sport ID | Sport | Structural file | Structural status | Last evidence date |
|---:|---|---|---|---|
| 58 | BMX | `SPORTS/BMX.md` | In progress | 2026-07-22 |

<!-- MANUAL PASTE ZONE: SPORT INDEX — insert approved additions immediately before this marker; do not move or delete it. -->

## New-sport rule

After the first confirmed structural result for a new sport, retain the finding as
pending. When `PREPARE_DOC_UPDATE SPORT=<Sport>` is requested:

1. add one row immediately before the `SPORT INDEX` marker;
2. create one new `SPORTS/<SportSlug>.md` file from `SPORTS/_TEMPLATE.md`;
3. fill only confirmed areas;
4. leave every uninvestigated area as `Not checked`;
5. never create one file per finding, table or query.

## Status meanings

| Status | Meaning |
|---|---|
| `Used` | Successful sport-scoped evidence shows active usage |
| `Not used` | A successful complete-layer query returned zero active usage |
| `Not checked` | The layer was not queried, the query failed or coverage was incomplete |

An empty section is not evidence. It remains `Not checked` until verified.

## Manual index-rule additions

Project-level changes to this index are inserted immediately before the marker below.

<!-- MANUAL PASTE ZONE: SPORTS INDEX RULES — insert approved additions immediately before this marker; do not move or delete it. -->
