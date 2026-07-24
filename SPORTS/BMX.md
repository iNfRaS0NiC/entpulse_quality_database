# SPORT: BMX (sport_id=58)

This file is the canonical structural record for BMX. It contains only confirmed
sport-specific usage, meanings, identifiers, evidence boundaries and open structural
questions. Global database mechanisms belong in `../DATABASE.md`.

For additions, insert approved content immediately before the exact active
`MANUAL PASTE ZONE` marker in the destination subsection. Keep the marker unchanged
and at the end of its subsection. Replace existing rows or paragraphs in place when a
correction is required.

## Identity and evidence
- First discovery date: 2026-07-20
- Latest evidence date: 2026-07-22
- Verification boundary: sport identity, event participants, event results, incidents, lineups, scope layer, properties, object_relation, object_discipline, statistics, reference values and event status mapping all confirmed from active data.

## Structural coverage
| Area | Status | Evidence |
|---|---|---|
| Core hierarchy | Used | sport.id=58, name='BMX', enetSportCode='mx' |
| Event participants | Used | Only participant type `athlete`, genders `male`/`female` observed |
| Event results | Used | 7 result_typeFK/result_code pairs confirmed |
| Incidents | Not used | Complete-layer query returned zero active rows |
| Lineups | Not used | Complete-layer query returned zero active rows |
| Scope layer | Used | scope_typeFK 101, 102, 103 |
| Properties | Used | Confirmed for event, tournament_stage and participant owners; not used for tournament owner |
| object_relation | Used | (2→152) template subset, (4→151) stage age class |
| object_discipline | Used | Owner type 5 (event); disciplineFK 429, 430 and 776 |
| Statistics | Used | statistic_typeFK=11, object_typeFK=3 (tournament-level) confirmed |
| Reference values | Used | result_type, scope_type and discipline names confirmed |
| Other tables | Used | event.status_type/status_descFK mapping confirmed |

## Tables and relation paths used

Core hierarchy through `tournament_template.sportFK=58`; event results via `result`;
scope via `event_scope`/`scope_result`; properties via `property`
(`object='event'|'tournament_stage'|'participant'`); disciplines via
`object_discipline` (owner type 5); statistics via `statistic`
(`object_typeFK=3`) → `statistic_participants11` → `statistic_data11`, with
`statistic_config` for statistic-level metadata.

<!-- MANUAL PASTE ZONE: 58 TABLES AND RELATIONS — insert approved additions immediately before this marker; do not move or delete it. -->

## Participant and lineup structure

BMX event_participants use only participant type `athlete`, with genders `male` and `female`. No lineup rows exist for BMX (Not used). Only participant type `athlete` is linked through `statistic_participants11`.

First and last name are stored via the generic `language` table
(`object='participant'`, `language_typeFK=7` for `first_name`, `language_typeFK=8` for
`last_name`), confirmed active for BMX athletes. `participant.name` (full name) is a
separate, already-confirmed direct column.

<!-- MANUAL PASTE ZONE: 58 PARTICIPANTS AND LINEUPS — insert approved additions immediately before this marker; do not move or delete it. -->

## Event result types
| result_code | result_typeFK | Value shape | Confirmed meaning | Evidence |
|---|---:|---|---|---|
| rank | 100 | | Rank | Confirmed-data |
| duration | 101 | | Duration | Confirmed-data |
| points | 102 | | Points | Confirmed-data |
| comment | 104 | | Comment | Confirmed-data |
| medal | 501 | | Medal | Confirmed-data |
| duration_full_time | 557 | | Full-time duration | Confirmed-data |
| wave_1 | 547 | | Wave 1 | Confirmed-data |

<!-- MANUAL PASTE ZONE: 58 EVENT RESULTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Incident types

Not used — confirmed zero active incident rows for BMX events.

<!-- MANUAL PASTE ZONE: 58 INCIDENTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Scope types and data types

Used — scope_typeFK values 101 (checkpoint1), 102 (checkpoint2), 103 (checkpoint3) confirmed on BMX event_scope containers.

<!-- MANUAL PASTE ZONE: 58 SCOPES — insert approved additions immediately before this marker; do not move or delete it. -->

## Properties

Confirmed active `property` type='metadata' names by owner:
- `event`: discipline, Live, Round, Type, medal_related, ElapsedTime, Heat, checkpoints, checkpoint_details
- `tournament_stage`: Cup, StatusComment
- `participant`: status, date_of_birth, height, weight
- `tournament`: Not used (complete-owner query returned zero active rows)

<!-- MANUAL PASTE ZONE: 58 PROPERTIES — insert approved additions immediately before this marker; do not move or delete it. -->

## Generic relations and disciplines

`object_relation`: (object_typeFK=2 → rel_object_typeFK=152) and (object_typeFK=4 → rel_object_typeFK=151) both confirmed active for BMX.
`object_discipline`: owner type 5 (event) confirmed active with three disciplines: 429=Racing, 430=Freestyle, 776=Time Trial.
Confirmed active `tournament_age_class` values linked via `object_relation` (4→151) for BMX stages with active events: `SENIOR`, `YOUTH`.

<!-- MANUAL PASTE ZONE: 58 GENERIC RELATIONS AND DISCIPLINES — insert approved additions immediately before this marker; do not move or delete it. -->

## Statistics
| statistic_typeFK | Owner type | Participant shard | Data shard | Fields/config | Evidence |
|---:|---:|---:|---:|---|---|
| 11 | tournament (object_typeFK=3) | statistic_participants11 | statistic_data11 | Data: Rank(1270), Points(1271), Duration(1272), Comment(1273), Pair(1276), Medal(1277), Time(1426), Time Difference(1427), Team(1429). Config: Start date(1463), End date(1464), Gender(1470), Event id(1471) | Confirmed-data |

<!-- MANUAL PASTE ZONE: 58 STATISTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Reference values

| Code type | id | name |
|---|---:|---|
| result_type | 100 | Rank |
| result_type | 101 | Duration |
| result_type | 102 | Points |
| result_type | 104 | Comment |
| result_type | 501 | Medal |
| result_type | 547 | Wave 1 |
| result_type | 557 | Full-time duration |
| scope_type | 101 | checkpoint1 |
| scope_type | 102 | checkpoint2 |
| scope_type | 103 | checkpoint3 |
| discipline | 429 | Racing |
| discipline | 430 | Freestyle |
| discipline | 776 | Time Trial |
| statistic_data_type (config) | 1463 | Start date |
| statistic_data_type (config) | 1464 | End date |
| statistic_data_type (config) | 1470 | Gender |
| statistic_data_type (config) | 1471 | Event id |

<!-- MANUAL PASTE ZONE: 58 REFERENCE VALUES — insert approved additions immediately before this marker; do not move or delete it. -->

## Event and round representation

event.status_type/status_descFK combinations confirmed: finished/6, notstarted/1, cancelled/106.

event.round_typeFK is confirmed active for BMX events, referencing the round_type table. Round type names are not unique identifiers — multiple round_type IDs share identical name text (e.g., two IDs named 'Heats', two named 'Quarter Finals', two named 'Final'); queries must reference round_typeFK by ID, not name. A confirmed unmapped value round_typeFK=0 occurs with no matching round_type row, distinct from a NULL round_typeFK.

A single round_typeFK value can be attached to events representing logically different rounds. Confirmed for round_typeFK=189 (Seeding), which is used by events named as Time Trial Superfinal, Seeding Run and Semifinal Heat across different tournament templates. Round type identity must not be treated as a reliable indicator of the actual round an event represents

<!-- MANUAL PASTE ZONE: 58 EVENT AND ROUND REPRESENTATION — insert approved additions immediately before this marker; do not move or delete it. -->

## Confirmed sport-specific storage semantics
City for a BMX tournament stage is stored via `city_object` (object_typeFK=4, objectFK=tournament_stage.id) linking to `city`, not via a direct column.

Host Country for a BMX tournament stage is stored via `object_relation` (object_typeFK=4 → rel_object_typeFK=33), distinct from the direct `tournament_stage.countryFK` column. Confirmed active and functional for BMX via manual positive control (stage 920060).

The sport-level registry (`object_participants`, object='sport', objectFK=58) contains both `athlete` and `team` type participants, even though `event_participants` for BMX confirms only `athlete` type usage (team event participation is Not used). Registered team participants exist at the sport registry level without corresponding event participation.

Event-level `property` value under name='discipline' matches exactly the discipline name confirmed via `object_discipline` (Racing, Freestyle, Time Trial) — both mechanisms are consistent and refer to the same three disciplines under sport_id=58.

BMX (sport_id=58) covers three disciplines with distinct result_type and scope_type coverage:

| Discipline (disciplineFK) | result_typeFK used | scope_typeFK used |
|---|---|---|
| Racing (429) | 100, 101, 102, 104, 501, 547, 557 | 101, 102, 103 |
| Freestyle (430) | 100, 101, 102, 104, 501 | 101, 102 |
| Time Trial (776) | 100, 101, 104, 501, 557 | Not used |

Structural and DQ checks for BMX should be scoped per discipline (via `object_discipline`), not only per sport_id, since result_type and scope_type usage vary by discipline.

A tournament-level Comp.Rank statistic (statistic_typeFK=11, object_typeFK=3) is not necessarily scoped to a single discipline. Some BMX statistics span events from two disciplines within the same tournament (e.g. Racing+Time Trial, or Racing+Freestyle). Checks must not assume one statistic maps to exactly one discipline; discipline scoping must be verified per event via `object_discipline`, not inferred from the owning statistic alone.

`statistic.name` for BMX tournament-level Comp.Rank statistics has no fixed taxonomy — it is a free-text label typically embedding tournament, discipline and round context. Do not treat `statistic.name` as an enum when writing checks.

A single BMX `event_participants` row can have multiple active `result` rows with
different `result_typeFK` values. Do not assume a 1:1 ratio between participation count
and result-row count when building coverage or ratio-based checks.

Confirmed active `tournament_stage.gender` values for BMX stages with active events: `male`, `female`, `mixed` — no `NULL`, empty or `undefined` values observed in this evidence.

<!-- MANUAL PASTE ZONE: 58 STORAGE SEMANTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Open questions

- Whether BMX `event.round_typeFK=0` (unmapped to any `round_type` row) is an intended sentinel value for "not assigned", or represents bad/legacy data — not yet confirmed.
- Some BMX Comp.Rank statistics (statistic_typeFK=11, object_typeFK=3) have no reliable path to a discipline: neither `statistic_config` Event id (1471) → event → `object_discipline`, nor a direct `object_discipline` relation (owner type=83) on the statistic itself, is guaranteed to exist. A statistic can be fully discipline-orphaned from both mechanisms (confirmed example: statistic_id=166712, name "Female Park"). Discipline-scoped checks and analysis for BMX Comp.Rank statistics must not assume either path is universal.
<!-- MANUAL PASTE ZONE: 58 OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
