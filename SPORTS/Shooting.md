# SPORT: Shooting (sport_id=45)

This file is the canonical structural record for Shooting. It contains only confirmed
sport-specific usage, meanings, identifiers, evidence boundaries and open structural
questions. Global database mechanisms belong in `../DATABASE.md`.

For additions, insert approved content immediately before the exact active
`MANUAL PASTE ZONE` marker in the destination subsection. Keep the marker unchanged
and at the end of its subsection. Replace existing rows or paragraphs in place when a
correction is required.

## Identity and evidence

- First discovery date: 2026-09-05
- Latest evidence date: 2026-09-05
- Verification boundary: the whole database sport, `sport.name` `Shooting`, enet code `sh`.
  No client scope has been applied and none is declared, so nothing here is narrowed to a
  template set. The statistics layer was deliberately not read - see Statistics below.

## Structural coverage

| Area | Status | Evidence |
|---|---|---|
| Core hierarchy | Confirmed-data | `GLOBAL-DISCOVERY-002`, 55 template/gender rows |
| Event participants | Confirmed-data | `GLOBAL-DISCOVERY-004` and `-006` |
| Event results | Confirmed-data | `GLOBAL-DISCOVERY-007`, and `-026` over every one of the eight fields |
| Incidents | Not used | `GLOBAL-DISCOVERY-008` returned zero active rows |
| Lineups | Confirmed-data | `GLOBAL-DISCOVERY-005` |
| Scope layer | Not used | `GLOBAL-DISCOVERY-009` and `-010` returned zero active rows |
| Properties | Confirmed-data | `GLOBAL-DISCOVERY-011` |
| object_relation | Confirmed-data | `GLOBAL-DISCOVERY-012` |
| object_discipline | Confirmed-data | `GLOBAL-DISCOVERY-013` and `-032` |
| Statistics | Not checked | not read on purpose, 2026-09-05 |
| Reference values | Confirmed-data | `GLOBAL-DISCOVERY-003` statuses, `-018` and `-019` round types |
| Other tables | Not checked | |

## Tables and relation paths used

The sport is stored on the ordinary hierarchy: `tournament_template` -> `tournament` ->
`tournament_stage` -> `event` -> `event_participants` -> `result`, with `object_discipline`
carrying the discipline on the event and `lineup` carrying a team's members.

A template is split by gender rather than shared across genders: the same competition name
appears as separate template rows for male, female and mixed. `African Championships` is three
templates, `Asian Championship` three, and so on across the 55 rows.

<!-- MANUAL PASTE ZONE: 45 TABLES AND RELATIONS — insert approved additions immediately before this marker; do not move or delete it. -->

## Participant and lineup structure

Both an athlete and a team enter events. Athletes are the larger population and teams are a
real second one, not an artefact: they hold a lineup of their own members.

- Event participants are `athlete` and `team`.
- The registry holds `athlete` and `team` in the roles `athlete` and `team`.
- The one lineup type in use is `14 Starter`, whose parent is a `team` and whose members are
  `athlete`. Members are recorded as male or female; no mixed member row exists, and a mixed
  team is a team of male and female members rather than a member marked mixed.

<!-- MANUAL PASTE ZONE: 45 PARTICIPANTS AND LINEUPS — insert approved additions immediately before this marker; do not move or delete it. -->

## Event result types

| result_code | result_typeFK | Value shape | Confirmed meaning | Evidence |
|---|---:|---|---|---|
| rank | 100 | `#` | The placing. The only other shape is `-` | `GLOBAL-DISCOVERY-026`, 2 shapes |
| points | 102 | `#` and `#.#` | The score. The decimal form is the one finals use | `GLOBAL-DISCOVERY-026`, 6 shapes |
| comment | 104 | free text | Qualification and status words | `GLOBAL-DISCOVERY-026`, 41 shapes |
| medal | 501 | `gold`, `silver`, `bronze` | The medal won | `GLOBAL-DISCOVERY-026`, 3 shapes |
| duration | 101 | mixed, see below | Not a duration in this sport | `GLOBAL-DISCOVERY-026`, 31 shapes |
| tops | 535 | `#` and words | Shoot-off, and only in 36 events | `GLOBAL-DISCOVERY-026`, 8 shapes |
| distance | 103 | words | Present in 3 events and holding no distance | `GLOBAL-DISCOVERY-026`, 3 shapes |
| zones | 536 | `#` and words | Shoot-off, and only in 9 events | `GLOBAL-DISCOVERY-026`, 6 shapes |

**The value inventory is complete and the addresses behind it are a sample.**
`GLOBAL-DISCOVERY-026` ran over every one of the eight fields and listed all 100 shapes they
hold between them, so the inventory above is coverage. `GLOBAL-DISCOVERY-027`, which names the
events behind one shape, was run for the two busiest shapes of each field and for six chosen
odd ones; the other 84 pairs have no event named against them yet.

`100 Rank` and `102 Points` carry the sport: 171 134 and 170 960 rows, in 8 632 and 8 587
events. Every other field is thin by comparison, and three of them - `101`, `103`, `535`,
`536` - hold values that do not belong to the field they sit in. That is recorded under
Confirmed sport-specific storage semantics rather than here, because it is a statement about
what the data does, not about what the field means.

<!-- MANUAL PASTE ZONE: 45 EVENT RESULTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Incident types

Not used - `GLOBAL-DISCOVERY-008` returned zero active incident rows for Shooting events on
2026-09-05. The statement is a complete-layer query and it succeeded, which is what separates
this from `Not checked`.

<!-- MANUAL PASTE ZONE: 45 INCIDENTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Scope types and data types

Not used - `GLOBAL-DISCOVERY-009` and `GLOBAL-DISCOVERY-010` both returned zero active rows on
2026-09-05. The sport has no scope container inside an event: a series of shots is stored as
its own event, not as a scope of one. `-010` reads the data inside a scope, so its zero follows
from the first and is not independent evidence.

<!-- MANUAL PASTE ZONE: 45 SCOPES — insert approved additions immediately before this marker; do not move or delete it. -->

## Properties

Fifteen property rows are in use, all `metadata` except one.

- On the event: `discipline`, `Live`, `medal_related`, `ParticipantType`, `Round`, `Type`, and
  `ElapsedTime` on a single event.
- On the participant: `date_of_birth`, `height`, `weight`, `status`, `IsNationalTeam`,
  `ToBeDecided`.
- On the tournament stage: `Cup`.
- The one non-metadata row is `ref:participant` `organizationFK` on `event_participants`, and
  it is present on four rows in total.

`Live` and `Round` are on every one of the 8 922 events; `Type` on 8 919; `ParticipantType` on
8 579; `discipline` on 5 586, which is fewer than the events that carry a discipline through
`object_discipline`.

<!-- MANUAL PASTE ZONE: 45 PROPERTIES — insert approved additions immediately before this marker; do not move or delete it. -->

## Generic relations and disciplines

`object_discipline` carries the discipline on the event, owner type 5, across 35 discipline
rows. The named disciplines are the shooting events themselves - `Trap`, `Skeet`,
`10m Air Rifle`, `10m Air Pistol`, `25m Pistol`, `50m Pistol`, `50m Rifle Prone`,
`50m Rifle 3 Position`, `25m Rapid Fire Pistol`, `Double Trap`, `10m Running target`, and the
300m and Fullbore families.

`object_relation` is thin: six owner/related pairs, the largest being owner type 4 to related
type 151 with 853 rows, which is the stage-to-country path that
`GLOBAL-DISCOVERY-014` reads.

`GLOBAL-DISCOVERY-032` returned 91 discipline/gender/participant combinations actually
contested. A combination absent from that matrix has not been contested and must not be
assumed available.

<!-- MANUAL PASTE ZONE: 45 GENERIC RELATIONS AND DISCIPLINES — insert approved additions immediately before this marker; do not move or delete it. -->

## Statistics

| statistic_typeFK | Owner type | Participant shard | Data shard | Fields/config | Evidence |
|---:|---:|---:|---:|---|---|

Not checked, and deliberately so. Shooting was opened on 2026-09-05 without the Comp.Rank
layer, under the standing decision of 2026-08-26 to leave it aside while the event results it
is generated from are being corrected. No statistics discovery statement was run and no
statistic parameter is declared in `SPORTS/params.json`.

This is `Not checked` and never `Not applicable`: the layer exists here. Parameter resolution
saw `statistic_typeFK` 11 at tournament level over 122 statistics on shard 11 while resolving
the sport, which is enough to know the structure is present and not enough to document it. The
sport comes back to this.

<!-- MANUAL PASTE ZONE: 45 STATISTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Reference values

**Event status.** Three in use: `finished` (`6 Finished`) on 8 850 events, `notstarted`
(`1 Not started`) on 65, and `cancelled` (`106 Cancelled`) on 7.

**Round types.** Twelve in use, and `GLOBAL-DISCOVERY-019` was run for every one of them, so
this is coverage rather than a sample.

| round_typeFK | Name | Events |
|---:|---|---:|
| 173 | Final | 3 824 |
| 179 | Qualifier | 3 679 |
| 181 | bronze | 675 |
| 178 | Semi Finals | 398 |
| 0 | *(no name)* | 174 |
| 191 | Elimination | 89 |
| 38 | 1 | 29 |
| 171 | Preliminary | 22 |
| 176 | Quarter Finals | 12 |
| 39 | 2 | 10 |
| 228 | Placement Phase | 9 |
| 152 | Qualifier | 1 |

Three things in that table are structural rather than incidental, and each is carried into
Open questions below: `0` maps to no `round_type` row at all; `38` and `39` are named with a
bare digit; and `152` and `179` are two different ids both named `Qualifier`.

<!-- MANUAL PASTE ZONE: 45 REFERENCE VALUES — insert approved additions immediately before this marker; do not move or delete it. -->

## Event and round representation

An event name states the discipline and the round: `10m Air Pistol Final`,
`10m Air Rifle Qualification`, `Trap Final`, `Skeet Final`. The busiest four patterns are the
air pistol and air rifle finals and qualifications, at 484, 482, 470 and 469 events each.

A stage name states the competition and often its host city: `World Cup Munich`,
`World Cup Changwon`, `World Cup Lonato`, `European Championships`,
`European Championships Shotgun`.

**Both name inventories are a sample and are recorded as one.** `GLOBAL-DISCOVERY-020` counted
442 distinct event-name patterns and `-022` counted 188 stage-name patterns; the detail
statements were run for the three busiest of each. The count of patterns is coverage; the names
behind all but three of them are not. The pattern count is high because a digit in a name makes
its own pattern, so `10m` and `25m` events separate.

<!-- MANUAL PASTE ZONE: 45 EVENT AND ROUND REPRESENTATION — insert approved additions immediately before this marker; do not move or delete it. -->

## Confirmed sport-specific storage semantics

**Four result fields hold values belonging to other fields.** Measured 2026-09-05 with
`GLOBAL-DISCOVERY-026` over the whole inventory, and addressed to named events with `-027`.

- `101 Duration` holds 31 distinct shapes across 2 437 rows in 391 events. The numeric shapes
  are the bulk, but they are not durations: in `Trap Qualification` the values run 52 to 71,
  which is a count of targets hit. Beyond those it holds a bare backtick in 88 events, all of
  them under the `World Cup` template and starting at `World Cup Granada` 2013; the country
  codes AUT, CRO, CZE, FIN, FRA, GBR, GER and HUN, one row each; and two athlete names -
  `Daria Turulo` in event 5789722 `Skeet Final`, and `Diana Bacosi`.
- `103 Distance` holds 29 rows in 3 events, and one of its three shapes is the literal word
  `Comment` - event 5765754, `Double Trap Qualification`, European Championships Shotgun 2006.
- `536 Zones` holds `Gold`, `Silver`, `Bronze` and `Final` beside its numbers.
- `535 Tops` holds `Medal Matches`, `QF` and `--/--` beside its numbers.

Event 5974406 `25m Pistol Final`, South East Asian Games 2017, appears in two of these at once:
`Gold` in Zones and `Medal Matches` in Tops.

This is recorded as what the data holds. Whether any of it is a defect, and which field each
value belongs in, has not been decided and no check is written for it.

**`GLOBAL-DQ-096 EVENT_NAME_DOES_NOT_NAME_ITS_PARTICIPANTS` is `Not applicable` here, and the
template says so itself.** It is written for head-to-head sports by the competition model: naming
an event after the competitors is what `Team 1 - Team 2` is, and a sport that lines a field up and
ranks it has nothing to put in such a name. Measured 2026-09-06, it reports 8 636 of 8 636 events,
because every one of them is named for its discipline and round - `10m Air Rifle Final`,
`Trap Qualification`, `Air Pistol Team Bronze Medal Match`. No CheckID is assigned and none is
reserved. Decided 2026-09-06.

**`GLOBAL-DQ-127 EVENT_RESULTS_TIED_VALUE_WITHOUT_SHARED_RANK` is `Not applicable` here.** The
template starts from competitors holding the same deciding value and asks why their place was not
shared. This sport does not share a place on an equal score: it separates the two by a count-back
that the database does not store, so equal `102 Points` never implies an equal Rank and the
template's premise does not hold. Measured 2026-09-06 it reports 4 620 events of 8 586, 54% of the
sport, at a median of four tie groups per event and a maximum of forty. The absence is structural
rather than a count - the deciding quantity for a tie is not recorded anywhere in the sport, which
is why no parameter can express it - and `GLOBAL-DQ-021 EVENT_RESULTS_RANK_DUPLICATE_WITHOUT_COMMENT`
reads the opposite direction and is instantiated as `Shooting-DQ-046`. No CheckID is assigned and
none is reserved. Decided 2026-09-06.

**Eighteen more templates are `Not applicable` here, decided 2026-09-06.** None is assigned a
CheckID and none reserves one. They fall in six groups and each group has one reason.

**Seven are `Not applicable` because they need an event scope layer this sport does not write** -
`GLOBAL-DQ-085`, `GLOBAL-DQ-086`, `GLOBAL-DQ-089`, `GLOBAL-DQ-091`, `GLOBAL-DQ-092`,
`GLOBAL-DQ-102` and `GLOBAL-DQ-107`. `GLOBAL-DISCOVERY-009` and `-010` both returned zero active
rows on 2026-09-05: a series of shots is stored as its own event, not as a scope inside one, so
there is no container for any of them to read.

**Four are `Not applicable` because they need a timed discipline and a full-time field** -
`GLOBAL-DQ-045`, `GLOBAL-DQ-054`, `GLOBAL-DQ-056` and `GLOBAL-DQ-111`. The sport has neither. Its
whole result vocabulary is eight types - `100 Rank`, `102 Points`, `501 Medal`, `104 Comment`,
`101 Duration`, `535 Tops`, `536 Zones` and `103 Distance` - so `557 Full-time duration` does not
occur anywhere in it, and no shooting discipline is decided by a clock. The same measurement puts
`CLOCK_RESULT_TYPE_LIST` outside `SPORTS/params.json`.

**Three are `Not applicable` because they need a score mirrored between two sides** -
`GLOBAL-DQ-090`, `GLOBAL-DQ-108` and `GLOBAL-DQ-114` - and two different facts put them out.
`GLOBAL-DQ-090` and `GLOBAL-DQ-114` need one figure stored in two result types, which is a
head-to-head shape; this sport stores one score, and `RESULT_SCORE_TYPE_ID` and
`RESULT_FINAL_SCORE_TYPE_ID` are both `102 Points` for exactly that reason. `GLOBAL-DQ-108` is out
on its own ground: it asserts the deciding score is a count of scoring units and so may be neither
negative nor fractional, and a shooting final is scored to a decimal - 33 808 of the field's
values carry one against 137 100 whole ones - so it would report every final. That is the same
fact that keeps `PRECISION_RESULT_TYPE_LIST` undeclared.

**Two are `Not applicable` because they need the `Winner` property on a head-to-head contest** -
`GLOBAL-DQ-087` and `GLOBAL-DQ-088`. Both name `H2H` per `DATABASE.md` `DB-SEM-015` as their
prerequisite, and this sport lines a field up and ranks it. `GLOBAL-DQ-088` additionally reads
`event_participants.number` 1 as the home side and 2 as the away side, which has no meaning in a
field of thirteen.

**One is `Not applicable` because it needs an event that is a contest between exactly two
entries** - `GLOBAL-DQ-083`. Measured 2026-09-06, this sport's events hold 3, 5, 7, 9, 10, 11, 12,
13, 15, 16, 17, 18, 19, 20, 24 and 29 competitors among the commonest sizes alone, so there is no
field size to declare and `EVENT_PARTICIPANT_COUNT_LIST` has no value that would mean anything.

**One is `Not applicable` for two independent reasons, and either alone would settle it** -
`GLOBAL-DQ-052 EVENT_RESULTS_COMMENT_INVALID_OR_CONTRADICTED`. `GLOBAL_DQ/README.md` states that a
sport instantiates it or `GLOBAL-DQ-117`, never both, because the two read the same population and
both emit `COMMENT_INVALID_VALUE`; this sport carries `GLOBAL-DQ-117` as `Shooting-DQ-058`, which
is the correct half for a sport settling a placing from a stored score rather than from a time.
Independently, `GLOBAL-DQ-052` tests the contradiction against a full time and a duration, and
this sport stores no full time at all, so its stronger arm could never run here.

**Three more are `Not applicable` because the parameter they read is deliberately undeclared, and
the reason for each lives in `SPORTS/params.json` under `_names` rather than here.**
`GLOBAL-DQ-120 EVENT_RESULTS_NUMERIC_WRITTEN_FORM_INCONSISTENT` reads
`PRECISION_RESULT_TYPE_LIST`, which is undeclared because `102 Points` is written whole in a
qualification and to a decimal in a final, so the check would report the difference between two
rounds as an inconsistency. `GLOBAL-DQ-128 EVENT_RESULTS_CLOCK_VALUE_COMPONENT_OUT_OF_RANGE` and
`GLOBAL-DQ-152 EVENT_RESULTS_CLOCK_VALUE_IN_JUDGED_DISCIPLINE` read `CLOCK_RESULT_TYPE_LIST`,
which is undeclared because the sport writes no clock value at all - every result value it holds
was searched for a colon on 2026-09-06 and two came back, both shoot-off tallies in a comment.

**With these, every one of the 154 GLOBAL DQ templates has a decision behind it for this sport**,
as of 2026-09-06: 73 instantiated as `Shooting-DQ-001` to `-073`, 23 `Not applicable`, one
`Not checked` pending the `101 Duration` question, 52 belonging to the Comp.Rank layer this
opening deliberately left out, two deprecated, and three that only a head-to-head sport can hold.

<!-- MANUAL PASTE ZONE: 45 STORAGE SEMANTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Open questions

- Whether `event.round_typeFK = 0`, on 174 events and mapping to no `round_type` row, is an
  intended sentinel for "not assigned" or is bad data. The same question stands open on BMX and
  the two have not been compared.
- What round types `38` and `39` are. They are named with the bare digits `1` and `2` and cover
  39 events between them, and a name of one character cannot be read as a round.
- Why `152` and `179` are two different round types both named `Qualifier`, one holding 3 679
  events and the other holding 1. Either the single event is misfiled or the two ids mean
  different things that the names do not distinguish.
- What `101 Duration` is meant to hold in this sport, and whether most of what is in it was
  written there in error. The field name says duration and nothing in it is a time. Measured
  2026-09-06 over all 8 922 events: 391 carry a value at all, 2 437 rows in total, and the field
  holds no per-competitor measurement of any kind.

  **2 040 of those rows - 84% - in 373 of the 391 events, are one of 24 values that appear
  exactly once per event.** `6.943` in 263 events, `6.93` in 261, `7.084` in 260, `7.47` and
  `7.482` in 259 each, `7.419` in 256, then `10.779` in 47, `7.895` in 46, `10.922` in 45, and
  fifteen more from `8.402` down to `9.649`, each in 12 to 22 events. The bare backtick belongs to
  the same family and behaves identically: 88 rows in 88 events, one apiece. Which values a
  competition gets follows its template - the first six are World Cup, the rest Asian Games, Asian
  Championship, African Championships and European Championships - and they span 2006 to 2026.
  They land on the leading placings and stop. Event 5964240 `50m Pistol Final`, 8 February 2026,
  is the shape in one row set: thirteen competitors scoring 563 down to 522, the top six carrying
  `6.93`, `6.943`, `7.084`, `7.419`, `7.47`, `7.482` in that order and the other seven carrying
  nothing. They rise as the score falls, which is why they read as a plausible ordering and went
  unquestioned for twenty years. A value appearing once in each of 260 events is not a measurement
  of any of them.

  The remaining 397 rows are debris of four kinds: 313 rows in 12 events where the value is
  character for character the competitor's own `102 Points`; 57 non-numeric one-offs including six
  athlete names, the country codes `FRA`, `AUT` and `SVK`, and the literal words `Points` and
  `Име`, which are column headings written in as data; 20 further numbers; and 7 bare hyphens.

  Nothing is repaired here and no check is written for it. `GLOBAL-DQ-019
  EVENT_DURATION_FORMAT_MISMATCH_TO_RANK` - which asserts the leader/gap convention, the winner
  carrying an absolute time and everyone behind a `+` difference - is `Not checked` rather than
  `Not applicable` and waits on this answer: it reports 390 of the 391 events, so what it would be
  reading is this open question rather than 390 malformed times. `output/SHOOTING_DURATION_FIELD.csv`
  holds every one of the 2 437 rows for the people who can answer it.

- What the bare backtick in `101 Duration` means. It is one value in each of 88 events, all
  under the `World Cup` template, which makes it a convention of one source rather than 88
  separate mistakes. Re-read 2026-09-06, it is not a question of its own: it behaves exactly like
  the 23 numeric values above it, once per event and never twice, so whatever wrote those wrote
  this. It is listed separately only because a reader looking for it will look for it by name.

- Where a shoot-off is recorded when it separates two finalists on the same score. Equal `102
  Points` with different Ranks is how this sport ranks and is not in itself a question, but 1 204
  of the events showing it are Finals, where a tie is shot off rather than counted back. The
  fields that would hold it, `535 Tops` and `536 Zones`, exist in 36 and 9 events in the whole
  sport, so whatever separated the other finalists is not written down. Measured 2026-09-06 while
  classifying `GLOBAL-DQ-127 EVENT_RESULTS_TIED_VALUE_WITHOUT_SHARED_RANK` as `Not applicable`,
  which is what makes this the remaining half of that question rather than part of it.

<!-- MANUAL PASTE ZONE: 45 OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
