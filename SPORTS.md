# Sport Structural Index

## Purpose

This file is the compact index for sport-specific structural documentation.
Detailed findings are stored in one file per sport under `SPORTS/<SportSlug>.md`.

Do not place full sport findings in this index. Do not duplicate global database
mechanisms from `DATABASE.md`.

## Sport index

| Sport ID | Sport | Competition model | Structural file | Structural status | Last evidence date | Database sport name |
|---:|---|---|---|---|---|---|
| 58 | BMX | Listing (individual) | `SPORTS/BMX.md` | In progress | 2026-07-22 | BMX |
| 50 | Triathlon | Listing (individual and team) | `SPORTS/Triathlon.md` | In progress | 2026-07-30 | Triathlon |
| 10 | Curling | H2H (team) | `SPORTS/Curling.md` | In progress | 2026-08-01 | Curling |
| 40 | Artistic-Gymnastics | Listing (individual and team) | `SPORTS/Artistic-Gymnastics.md` | In progress | 2026-08-04 | Artistic Gymnastics |
| 1 | Soccer | H2H (team) | `SPORTS/Soccer.md` | In progress | 2026-08-05 | Soccer |
| 42 | Modern-Pentathlon | Listing (individual and team) | `SPORTS/Modern-Pentathlon.md` | In progress | 2026-08-06 | Modern Pentathlon |
| 3 | Golf | Hybrid (individual and team) | `SPORTS/Golf.md` | In progress | 2026-08-12 | Golf |

<!-- MANUAL PASTE ZONE: SPORT INDEX — insert approved additions immediately before this marker; do not move or delete it. -->

## New-sport rule

After the first confirmed structural result for a new sport, retain the finding as
pending. When `PREPARE_DOC_UPDATE SPORT=<Sport>` is requested:

1. add one row immediately before the `SPORT INDEX` marker;
2. create one new `SPORTS/<SportSlug>.md` file from `SPORTS/_TEMPLATE.md`;
3. fill only confirmed areas;
4. leave every uninvestigated area as `Not checked`;
5. never create one file per finding, table or query.

## Competition model rule

The `Competition model` column above records how a sport resolves a result: `H2H`, `Listing`
or `Hybrid`, with the participant type its events carry in brackets. `DATABASE.md`
`DB-SEM-015` owns the definitions and states each one as a condition on rows, so the value is
measured from the sport's data rather than assigned by judgement.

The column exists because the model, not the sport, is what decides which checks can have an
eligible population. A sport with no event-level rank cannot run a rank check; a sport whose
events hold exactly two participants can run pairwise checks no listing sport can. Recording
the model once explains a whole group of skipped checks that would otherwise look unrelated.

Fill it only after the sport file documents the evidence. An unclassified sport leaves the
cell `Not checked`, on the same terms as any other unverified area.

## Sport slug rule

One slug identifies a sport everywhere: the `Sport` column below, `SPORTS/<SportSlug>.md`,
`POWERBI_QUERIES/<SportSlug>.sql`, the `<SportSlug>-DQ-NNN` CheckID prefix and the key in
`SPORTS/params.json`. `TOOLS/Test-Package.ps1` fails when they disagree, and
`TOOLS/Run-Query.ps1` derives the run folder from the CheckID prefix, so a slug that is only
almost right silently scatters output.

Derive it from the documented English sport name:

| Rule | Example |
|---|---|
| Keep the name's own capitalization | `BMX`, `Curling` |
| Replace each space with a single hyphen | `Water Polo` → `Water-Polo` |
| Keep an existing period | `3x3 Basketball` → `3x3-Basketball` |
| Drop any other character | `Cycling (Road)` → `Cycling-Road` |
| Strip diacritics to their ASCII base | `Pétanque` → `Petanque` |

The result contains only `A-Z`, `a-z`, `0-9`, `.` and `-`. Multi-word slugs are parsed
correctly: the CheckID prefix is everything before `-DQ-`, so `Water-Polo-DQ-001` resolves
to `Water-Polo`.

The slug is not required to equal the database's `sport.name`. The final index column records
the exact database value while `Sport` records the repository slug, so the mapping is never
inferred after a sport is documented. `-Sport` accepts either value and resolves both;
`-SportSlug` plus `-DatabaseSportName` makes the pair explicit while opening a new sport.

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
