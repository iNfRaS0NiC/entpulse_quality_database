# SPORT: Curling (sport_id=10)

This file is the canonical structural record for Curling. It contains only confirmed
sport-specific usage, meanings, identifiers, evidence boundaries and open structural
questions. Global database mechanisms belong in `../DATABASE.md`.

For additions, insert approved content immediately before the exact active
`MANUAL PASTE ZONE` marker in the destination subsection. Keep the marker unchanged
and at the end of its subsection. Replace existing rows or paragraphs in place when a
correction is required.

## Identity and evidence

- First discovery date: 2026-08-01
- Latest evidence date: 2026-08-01
- Verification boundary: sport identity, core hierarchy, event statuses, event participants,
  event results, incidents, lineups, scope layer, properties, object_relation,
  object_discipline, statistics and reference values all confirmed from active data. Venue
  storage was measured only through the DQ template that reads it, not through a discovery
  statement of its own.

## Structural coverage

| Area | Status | Evidence |
|---|---|---|
| Core hierarchy | Used | `GLOBAL-DISCOVERY-002`, `-003` |
| Event participants | Used | `GLOBAL-DISCOVERY-004`, `-006` |
| Event results | Used | `GLOBAL-DISCOVERY-007`, `-026` |
| Incidents | Not used | `GLOBAL-DISCOVERY-008` returned zero active rows |
| Lineups | Used | `GLOBAL-DISCOVERY-005` |
| Scope layer | Used | `GLOBAL-DISCOVERY-009`, `-010` |
| Properties | Used | `GLOBAL-DISCOVERY-011` |
| object_relation | Used | `GLOBAL-DISCOVERY-012` |
| object_discipline | Used | `GLOBAL-DISCOVERY-013` |
| Statistics | Used | `GLOBAL-DISCOVERY-015`, `-016`, `-017`, `-028`, `-031` |
| Reference values | Used | `GLOBAL-DISCOVERY-030`, `-031` |
| Other tables | Not checked | |

## Tables and relation paths used

Core hierarchy through `tournament_template.sportFK=10`; event results via `result`; scope
via `event_scope`/`scope_result`; properties via `property`
(`object='event'|'tournament_stage'|'participant'`); disciplines via `object_discipline` on
owner types 5 (event) and 83 (statistic); statistics via `statistic` (`object_typeFK=3`) →
`statistic_participants11` → `statistic_data11`, with `statistic_config` for statistic-level
metadata.

Unlike the sports documented before it, Curling attaches disciplines to statistics as well as
to events, and `object_relation` carries three pairs whose source is a statistic.

<!-- MANUAL PASTE ZONE: 10 TABLES AND RELATIONS — insert approved additions immediately before this marker; do not move or delete it. -->

## Participant and lineup structure

Event participants are teams only. No `athlete` participant reaches the event layer directly,
and both the male and the female team populations are matched by a third, `mixed`, used by the
mixed doubles and mixed team formats.

The sport-level registry (`object_participants`, object='sport', objectFK=10) is wider than
the event layer: it carries `athlete`, `team` and `coach` roles, with both active and inactive
athletes. `coach` occurs in no other documented sport.

Lineups are used but are not the sport's membership mechanism. `lineup_type` 14 `Starter`
attaches `athlete` members to a `team` event participant, and only a small minority of team
event participants carry one. Athlete-to-team membership is carried by the Comp.Rank layer
instead, through the `(athletes)` statistic described under Statistics below. A check that
reads team membership from lineups therefore measures the minority mechanism and reports the
rest of the sport; `GLOBAL-DQ-058` is that check and its finding here is the proportion, not a
defect per event.

<!-- MANUAL PASTE ZONE: 10 PARTICIPANTS AND LINEUPS — insert approved additions immediately before this marker; do not move or delete it. -->

## Event result types

| result_code | result_typeFK | Value shape | Confirmed meaning | Evidence |
|---|---:|---|---|---|
| finalresult | 4 | Non-negative integer; no other shape occurs | Final Result | Confirmed-data |
| runningscore | 6 | Non-negative integer; no other shape occurs | Running score | Confirmed-data |
| medal | 501 | `gold` / `silver` / `bronze` | Medal | Confirmed-data |
| ordinarytime | 1 | Integer | Ordinary time | Confirmed-data |

The sport carries no Rank, Duration, Comment or Full-time result type. The classification is
the score itself: `4 Final Result` holds one value per team, so the winner is read from the
pair rather than from a stored place. This is the first documented sport whose event layer
holds no rank at all, and it removes the whole family of checks that read a rank, a time or a
status code against one another.

`4` and `6` are the only result types carrying a measured quantity, and
`GLOBAL-DISCOVERY-026` confirms a single value shape for each: digits only, with no empty
value, no decimal and no text anywhere in the active population.

`1 Ordinary time` is present but effectively unused, in a handful of events against the full
population of the other three. A check whose eligible population requires it audits those few
events and its coverage count says so.

The sport uses no status vocabulary on a result. `RESULT_COMMENT_VALUE_LIST` is therefore
recorded as the empty list `''`, following the convention `GLOBAL_DQ/README.md` records for
`SERIES_SKIP_YEARS`: a sport with nothing to name records a value that matches nothing rather
than leaving the parameter unset. `GLOBAL-DQ-076` runs on that basis and can never report its
`STATUS_CODE_IN_NUMERIC_FIELD` branch here.

<!-- MANUAL PASTE ZONE: 10 EVENT RESULTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Incident types

Not used — `GLOBAL-DISCOVERY-008` returned zero active incident rows for Curling events.

<!-- MANUAL PASTE ZONE: 10 INCIDENTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Scope types and data types

Used, and with a shape neither previously documented sport has. One scope type,
`305 final_result`, with one active container per event, and the container holds the game's
end-by-end scoring in the `scope_result` layer:

| scope_data_typeFK | Detail name |
|---:|---|
| 282–289 | `end_1` … `end_8` |
| 290 | `end_9` |
| 291 | `end_10` |
| 292 | `end_extra` |

`end_1` through `end_8` are present in effectively every container, `end_9` and `end_10` in a
substantial majority but not all, and `end_extra` in a small minority. Two game lengths
therefore coexist in the active data, and an extra end is the exception rather than a parallel
convention. A check keyed on a fixed number of ends would be wrong for one of the two lengths.

<!-- MANUAL PASTE ZONE: 10 SCOPES — insert approved additions immediately before this marker; do not move or delete it. -->

## Properties

Confirmed active `property` type='metadata' names by owner:

- `event`: discipline, ElapsedTime, Live, medal_related, ParticipantType, Round,
  StartDateTimeToBeDecided, StartTimeToBeDecided
- `participant`: IsNationalTeam, ToBeDecided
- `tournament_stage`: Cup, Live, Venue
- `tournament`: Not used

`ParticipantType`, `IsNationalTeam`, `ToBeDecided`, `StartDateTimeToBeDecided` and
`StartTimeToBeDecided` occur in no other documented sport. `Venue` is present as a stage
property on a small minority of stages and is not the `venue_object` mechanism `DATABASE.md`
records, so it does not make an event resolve to a venue.

<!-- MANUAL PASTE ZONE: 10 PROPERTIES — insert approved additions immediately before this marker; do not move or delete it. -->

## Generic relations and disciplines

`object_relation` pairs confirmed active: (1→153), (2→152), (4→151), (83→33), (83→43) and
(83→151). The three whose source object type is 83 (statistic) are new against the sports
documented before this one.

`object_discipline` is used on owner type 5 (event) and owner type 83 (statistic), with two
disciplines: 752 `2aSide` and 753 `4aSide`.

The discipline, stage gender and participant-type combinations the sport has contested:

| Discipline | Stage genders contested | Participant type |
|---|---|---|
| 752 `2aSide` | mixed only | team |
| 753 `4aSide` | male, female, mixed | team |

`2aSide` is contested as a mixed format only. A check that expects every discipline to appear
under every gender would be wrong here, and the matrix rather than a rule is what says so.

<!-- MANUAL PASTE ZONE: 10 GENERIC RELATIONS AND DISCIPLINES — insert approved additions immediately before this marker; do not move or delete it. -->

## Statistics

| statistic_typeFK | Owner type | Participant shard | Data shard | Fields/config | Evidence |
|---:|---:|---:|---:|---|---|
| 11 (Comp.Rank) | 3 (tournament) | statistic_participants11 | statistic_data11 | Data: Rank(1270), Points(1271), Comment(1273), Medal(1277), Qualification rank(1278), Team(1429). Config: Start date(1463), End date(1464), Gender(1470) | Confirmed-schema-data |

Comp.Rank is the only statistic type the sport uses. The physical shard is 11 for both
participants and data, confirmed by probing rather than derived from the type (`DB-SEM-006`).

Comp.Rank separates team results from athlete results, and the separation is structural rather
than only editorial: a statistic whose name carries the `(athletes)` suffix holds `athlete`
participants and nothing else, while a statistic without the suffix holds `team` participants
and nothing else. No statistic holds both. The `(athletes)` statistic is where an athlete's
team membership is recorded, through the `1429 Team` data field holding the team's
`participant.id`, and it is the sport's primary membership mechanism rather than the event
lineup.

The sport stores no time in Comp.Rank. Neither the current `1426 Time` and
`1427 Time Difference` fields nor the deprecated `1272 Duration` occurs, which removes every
check that reads a stored time against a rank.

`statistic_config` records no `1471 Event id`, so a Comp.Rank statistic cannot be resolved to
the event it was taken from through that path.

Three data fields are present but marginal, and each is confined to IOC-purpose templates:

- `1271 Points` carries decimal values and is the sport's only numeric data field. Because a
  statistics statement excludes IOC-purpose templates, `GLOBAL-DQ-077` has an empty eligible
  population here and `NUMERIC_DATA_TYPE_LIST` stays unrecorded.
- `1273 Comment` resolves to the single value `DNF`.
- `1278 Qualification rank` carries one value, and that value is a medal word rather than a
  rank.

One statistic exists at owner level 4 (tournament_stage) rather than 3. It is named `test`,
holds no participant row, and is active. The sport's real statistic layer is owner level 3
alone.

<!-- MANUAL PASTE ZONE: 10 STATISTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Reference values

| Code type | id | name |
|---|---:|---|
| result_type | 1 | Ordinary time |
| result_type | 4 | Final Result |
| result_type | 6 | Running score |
| result_type | 501 | Medal |
| scope_type | 305 | final_result |
| scope_data_type | 282–292 | end_1 … end_10, end_extra |
| lineup_type | 14 | Starter |
| discipline | 752 | 2aSide |
| discipline | 753 | 4aSide |
| statistic_type | 11 | Competition Stats |
| statistic_data_type (data) | 1270 | Rank |
| statistic_data_type (data) | 1271 | Points |
| statistic_data_type (data) | 1273 | Comment |
| statistic_data_type (data) | 1277 | Medal |
| statistic_data_type (data) | 1278 | Qualification rank |
| statistic_data_type (data) | 1429 | Team |
| statistic_data_type (config) | 1463 | Start date |
| statistic_data_type (config) | 1464 | End date |
| statistic_data_type (config) | 1470 | Gender |

<!-- MANUAL PASTE ZONE: 10 REFERENCE VALUES — insert approved additions immediately before this marker; do not move or delete it. -->

## Event and round representation

An event name is the pairing that plays it: `Andorra-Canada` for a team game and
`Brazil/New Zealand-Canada/Spain` for mixed doubles, where each side is itself two country
names joined by a slash. No other shape occurs.

Two consequences follow, and both are structural rather than incidental:

- every event name contains a hyphen with no surrounding spaces, so `GLOBAL-DQ-049` reports
  the sport's whole distinct-name vocabulary under `HYPHEN_WITHOUT_SPACES`. The rule is not
  wrong; it is describing the naming convention. The findings worth reading in that result are
  the ones breaking a second rule as well;
- `GLOBAL-DISCOVERY-020` groups event names by a digit-normalized pattern, and a pairing of
  country names holds no digits to normalize. The summary therefore degenerates into a list of
  pairings and carries no pattern information for this sport.

The sport contests a wide round-type vocabulary, and eleven of its round names occur under two
ids at once. Every one of those pairs is the knockout/non-knockout split `DB-SEM-012` records
globally, not a second vocabulary: Preliminary (`171` no, `253` yes), Final (`173` no, `9`
yes), Semi Finals (`178` no, `2` yes), bronze (`181` no, `138` yes), Quarter Finals (`176` no,
`3` yes), Playoff (`304` no, `305` yes), Qualifier (`179` no, `152` yes), 1/8 (`184` no, `4`
yes), 1/16 (`185` no, `5` yes), 5/8 (`262` no, `26` yes) and 9/12 (`303` no, `136` yes).

The per-sport fact `DB-SEM-012` asks for is which side the sport stores, and Curling stores
both: in every pair the non-knockout variant carries the large majority of events and the
knockout variant a consistent minority. A check keyed on one id of a pair therefore audits
part of the sport and reports the rest, which is why the Final round set is recorded as both
ids rather than the one the sport uses most.

Round types 38, 39, 40 and 41 resolve to `round_type` rows named `1`, `2`, `3` and `4`, all
non-knockout with a bracket size of `0`. They occur inside a single stage and halve in event
count from one to the next, so they are consecutive rounds of one progression. This agrees
with the reading `SPORTS/BMX.md` records for `38` and extends it to the rest of the family.

Every active event resolves to a `finished` status type, under four status descriptions:
Finished, Finished AEI, Finished after awarded win and Finished AET. No not-started or in-play
status occurs, so a check keyed on one audits nothing here.

<!-- MANUAL PASTE ZONE: 10 EVENT AND ROUND REPRESENTATION — insert approved additions immediately before this marker; do not move or delete it. -->

## Confirmed sport-specific storage semantics

The sport is head to head between two teams, and it meets the `H2H` condition `DB-SEM-015`
states without exception: every active event holds exactly two event participants, both of
type `team`, and each score result type carries one value per participant. A result is read as
a pair and never as a standalone classification, which is why the sport populates no
event-level rank.

Most active events resolve to no venue, through neither their own `venue_object` link nor
their tournament stage's. `GLOBAL-DQ-074` therefore reports the large majority of the sport,
and the finding to read is the proportion rather than the individual event.

The sport uses no placeholder country. Every country reached from a tournament stage's direct
country column and every country reached from a statistic's `object_relation` (83→33) resolves
to a real country row, so `PLACEHOLDER_COUNTRY_LIST` is recorded as the empty list `''` on the
same convention the empty status vocabulary uses above.

The sport has run in every calendar year of its span, without a season missing between its
first and its last. 2020 is reduced rather than absent, so it is not a skipped year:
`SERIES_SKIP_YEARS` records the value `0`, a year that never occurs, following the convention
`GLOBAL_DQ/README.md` states for a sport with nothing to skip. This differs from both sports
documented before it, which do skip 2020.

<!-- MANUAL PASTE ZONE: 10 STORAGE SEMANTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Open questions

- Whether the single `1278 Qualification rank` value, which holds a medal word rather than a
  rank, is an isolated defect or a second meaning the field carries in this sport.
- Whether the active, participant-less statistic named `test` at owner level 4 is expected to
  exist, and whether owner level 4 has any intended use for this sport.
- Whether the events that resolve to no venue are expected to carry one. The measurement came
  from a DQ template rather than a discovery statement, so it sizes the population without
  establishing what the sport intends.

<!-- MANUAL PASTE ZONE: 10 OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
