# SPORT: Cycling (sport_id=30)

This file is the canonical structural record for Cycling. It contains only confirmed
sport-specific usage, meanings, identifiers, evidence boundaries and open structural
questions. Global database mechanisms belong in `../DATABASE.md`.

For additions, insert approved content immediately before the exact active
`MANUAL PASTE ZONE` marker in the destination subsection. Keep the marker unchanged
and at the end of its subsection. Replace existing rows or paragraphs in place when a
correction is required.

## Identity and evidence

- First discovery date: 2026-08-16
- Latest evidence date: 2026-08-16
- Verification boundary: **the whole sport**. All 51 tournament templates, 735 tournaments,
  3528 stages, 10578 active events and 1270283 event participations, 2001 to 2026. Nothing
  below is narrowed unless the paragraph says so.

`sport.name` is `Cycling` and the provider code is `cy`. `SPORTS.md` maps that to the
repository slug `Cycling`.

**The client takes this sport whole, and that is a decision rather than an absence.** Soccer
and Ice Hockey are limited to the national-team competitions because the league and club
calendar that dominates them is outside what UK Sport asked for. Cycling is not: confirmed on
2026-08-16 that all 51 templates are in scope, professional road racing included, so
`OUT_OF_SCOPE_TEMPLATE_ID_LIST` is `0` and no statement here carries a template filter.

That decision is what makes cost the sport's central problem, and the shape of the cost is
specific. **Cycling holds fewer events than Ice Hockey and sixty-five times more
participations**: 10578 events against 9803, but 1270283 participations against 19607, because
a road race enters the whole peloton rather than two sides. Five templates carry 9930 of the
events and 1236222 of the participations:

| Template | id | Gender | Events | Participations |
|---|---:|---|---:|---:|
| `Category 1` | 9481 | male | 3116 | 315156 |
| `Category Pro` | 9432 | male | 2317 | 262975 |
| `World Tour 1` | 483 | male | 2192 | 322072 |
| `World Tour 1 Grand Tour` | 10356 | male | 1446 | 257477 |
| `World Tour 1` | 9764 | female | 859 | 78542 |

The remaining 46 templates hold 648 events and about 34000 participations between them, and
they are the national-team calendar: the World Championships, the continental championships
for Africa, Asia, Pan America, Oceania and Europe, the Summer Olympics, the Commonwealth,
Pan American, European, Asian and South East Asian Games, the Youth Olympics, the European
Youth Olympic Festival, and the Danish national championship.

**Sixteen templates hold no event at all.** Seven are IOC-purpose and the standing
`tt.name NOT LIKE '%(IOC)%'` filter removes them anyway. The other nine do not empty so
cleanly: `10350 World Championship RR` (male) holds **69 tournaments and no events**,
`10352 World Championship RR` (female) 42, `10351` and `10353 World Championship TT` 9 and 16,
and the three `Summer Paralympics` templates one each. The `(IOC)` twins carry the same
tournament counts against the same names, which is what an unread structural question looks
like rather than an answered one. Recorded under Open questions.

## Structural coverage

| Area | Status | Evidence |
|---|---|---|
| Core hierarchy | Confirmed | `GLOBAL-DISCOVERY-002` sport-wide, 51 templates |
| Event participants | Confirmed | `GLOBAL-DISCOVERY-004`, `-032` sport-wide |
| Event results | Confirmed | `GLOBAL-DISCOVERY-007` sport-wide, 6 types, and `-026` over all six |
| Incidents | Confirmed absent | `GLOBAL-DISCOVERY-008` returned nothing |
| Lineups | Confirmed absent | `GLOBAL-DISCOVERY-005` returned nothing |
| Scope layer | Confirmed | `GLOBAL-DISCOVERY-009`, `-010` sport-wide |
| Properties | Confirmed | `GLOBAL-DISCOVERY-011` sport-wide, 33 rows |
| object_relation | Confirmed | `GLOBAL-DISCOVERY-012` sport-wide, 5 pairs |
| object_discipline | Confirmed | `GLOBAL-DISCOVERY-013` sport-wide, one discipline |
| Statistics | Confirmed | `GLOBAL-DISCOVERY-015`, `-016`, `-017`, `-028`, `-030`, `-031` |
| Reference values | Confirmed | `GLOBAL-DISCOVERY-018` sport-wide, 24 round types |
| Other tables | Not checked | |

## Tables and relation paths used

The sport is **Listing (individual and team)** by `DATABASE.md` `DB-SEM-015`: an event enters a
field and ranks it, and the field is normally athletes but is teams in the team time trials.
`GLOBAL-DISCOVERY-032` measured 2026-08-16 over the one discipline:

| Discipline | Stage gender | Participant type | Events | Templates | Years |
|---|---|---|---:|---:|---|
| `628 Road Race` | male | `athlete` | 8450 | 19 | 2001-2026 |
| `628 Road Race` | female | `athlete` | 1002 | 15 | 2003-2026 |
| `628 Road Race` | male | `team` | 136 | 8 | 2004-2026 |
| `628 Road Race` | female | `team` | 29 | 3 | 2004-2025 |
| `628 Road Race` | mixed | `team` | 7 | 2 | 2019-2025 |

**Two tables the sport does not use at all**, which is a structural fact rather than a
shortage of rows: `lineup` and `incident` are both empty for Cycling, measured 2026-08-16.
A road race enters each rider directly on the event, so there is no squad to name, and the
sport records no in-race event the way a match records a goal or a card. Every check reading
either layer is therefore not applicable here, and the two heaviest tables in the database do
not participate in this sport's cost.

<!-- MANUAL PASTE ZONE: 30 TABLES AND RELATIONS — insert approved additions immediately before this marker; do not move or delete it. -->

## Participant and lineup structure

There is no lineup layer. Participation is a direct `event_participants` row, and
`GLOBAL-DISCOVERY-004` measured sport-wide on 2026-08-16:

| Participant type | Gender | Participants | Participations |
|---|---|---:|---:|
| `athlete` | male | 14848 | 1178047 |
| `athlete` | female | 4424 | 88973 |
| `team` | male | 325 | 2659 |
| `team` | female | 95 | 407 |
| `team` | mixed | 38 | 102 |

**A `mixed` team is real in this sport**, unlike Ice Hockey where the value does not occur:
38 teams carry it across 102 participations, and `10054 World Championship 1` is a `mixed`
template with 8 events from 2019. The mixed relay is a contested format here.

The sport registry (`object_participants`) holds 12 role-type-gender combinations sport-wide:
15683 active male athletes and 4269 female, 1651 and 365 inactive, 495 active male teams and
147 female, 87 inactive male teams and 1 female, 38 mixed teams, 96 active male coaches and 1
inactive.

**Coaches are out of scope for this sport, decided 2026-08-16.** The registry holds 97 active
and 1 inactive, and no check written here audits one. The exclusion is recorded in
`SPORTS/params.json` as `REGISTRY_PARTICIPANT_TYPE_LIST`, which names `athlete` and `team`
only; `GLOBAL-DQ-009 PARTICIPANT_NO_PARTICIPATION_ANYWHERE` is the sole template that reads
the list. It is also the type that template could never clear: a coach is entered on no event,
this sport writes no lineup, and no coach appears in a Comp.Rank, so all 98 were reported for
the absence of a path rather than for a defect. Ice Hockey answered the same shape differently
because it has a fourth path - `refereeFK` on 270 events - and Cycling's property list holds
no equivalent.

**One registry row disagrees with the participant it registers**: `Mauro Gianetti` (id 75943)
is registered under the role `athlete` while the participant is typed `coach`. One row, and
the same shape Ice Hockey carries on 150. It is recorded rather than checked, since the type
it names is out of scope.

**Every person in the registry appears exactly once.** Measured 2026-08-16 over what
`GLOBAL-DISCOVERY-033` reads - `op.del = 'no'`, `p.del = 'no'`, type `athlete` - Cycling holds
21968 rows for 21968 people. Soccer and Ice Hockey do not: they hold 1644 and 943 more rows
than people. The measurement is recorded in `GLOBAL_QUERIES/PARTICIPANTS.sql` beside the
statement it affects.

**41 groups of athletes share a name**, and 39 of them carry conflicting dates of birth, which
is what a namesake looks like rather than a duplicate. Two do not: `Isaiah Thompson` (1818611
with one participation, 1875549 with none, both born 2004-05-11) and `Brayan Vargas` (1347817
with eight, 1825040 with none). An empty record beside a used one, on the same date of birth,
is the shape a duplicate has. No coach shares a name with another.

<!-- MANUAL PASTE ZONE: 30 PARTICIPANTS AND LINEUPS — insert approved additions immediately before this marker; do not move or delete it. -->

## Event result types

| result_code | result_typeFK | Value shape | Confirmed meaning | Evidence |
|---|---:|---|---|---|
| `rank` | 100 | `#`, and `<EMPTY>` on 447 events | The finishing place | `GLOBAL-DISCOVERY-007`, `-026`, 1139827 rows over 9608 events |
| `duration` | 101 | 14 shapes, chiefly `+#:#` and `#:#:#` | The rider's time: absolute for the winner, a gap for everybody else | `-007`, `-026`, 1139754 rows over 9605 events |
| `comment` | 104 | 13 vocabulary values | Why a rider holds no time | `-007`, `-026`, 114381 rows over 7520 events |
| `medal` | 501 | `gold`, `silver`, `bronze` | The medal awarded | `-007`, `-026`, 1777 rows over 592 events |
| `points` | 102 | `#` | Not read further | `-007`, `-026`, 31 rows over 12 events |
| `laps_behind` | 222 | `#` | Not read further | `-007`, 31 rows over 12 events |

**`102 Points` and `222 Laps behind` cover the same 12 events and the same 31 rows.** Whether
that is one format written twice or two fields that happen to coincide is not settled, and is
recorded under Open questions.

**The comment vocabulary is where the sport records a rider who did not finish**, and it holds
three spellings of one idea. Measured 2026-08-16 by `GLOBAL-DISCOVERY-026`:

| Value | Rows | Events | Reading |
|---|---:|---:|---|
| `DNF` | 101136 | 6254 | did not finish |
| `DNS` | 8363 | 4015 | did not start |
| `HD` | 3111 | 585 | outside the time limit (hors delai) |
| `Disqualified` | 1400 | 686 | disqualified, spelled as a word |
| `DSQ` | 146 | 107 | disqualified, spelled as a code |
| `OTL` | 137 | 36 | over the time limit |
| `+# lap` | 40 | 1 | a lap down |
| `a` | 19 | 1 | unread |
| `FF#` | 16 | 3 | unread |
| `DQ` | 5 | 1 | disqualified, a third spelling |
| `FTM` | 5 | 5 | unread |
| `HUD` | 2 | 2 | unread |
| `OOT` | 1 | 1 | unread |

**Disqualification is written three ways** - `Disqualified` 1400, `DSQ` 146, `DQ` 5 - and
being outside the time limit is written at least twice, `HD` 3111 against `OTL` 137 and
possibly `OOT` 1. Neither is a defect until somebody decides which spelling the sport means,
and the decision has not been made.

**The five unread values were read on the row on 2026-08-16** and each is confined:

- `a` is nineteen riders in one event, `Race` under `Driedaagse De Panne-Koksijde` 2018,
  template `9764 World Tour 1` (female). The whole group carries the single letter.
- `FF#` runs `FF1` to `FF14` across three events - Tour de France 2012 stage 7, World
  Championship TT 2024, African Championships 2005 - and the numbers run consecutively inside
  each event rather than across them.
- `FTM` is one rider in each of five `Giro d'Italia` stages: 2012, 2013, 2014, 2015 and 2019.
  It occurs in no other tournament.
- `HUD` is two riders, African Championships 2025 and Santos Tour Down Under WE 2026.
- `OOT` is one rider, Tour of Qinghai Lake 2025 stage 2.

<!-- MANUAL PASTE ZONE: 30 EVENT RESULTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Incident types

**The sport records no incident at all.** `GLOBAL-DISCOVERY-008` returned nothing sport-wide
on 2026-08-16. This is structural rather than empty: a road race has no discrete in-race event
of the kind `incident` is built for, and nothing in the sport writes one.

<!-- MANUAL PASTE ZONE: 30 INCIDENTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Scope types and data types

**The scope layer is a chain of checkpoints along the course, and it is unlike any other sport
opened so far.** `GLOBAL-DISCOVERY-009` measured 2026-08-16: scope types `101 checkpoint1`
through at least `148 checkpoint48`, each its own container, one per event. Reach falls along
the chain - `checkpoint1` on 1095 events, `checkpoint10` on 572, `checkpoint30` on 551,
`checkpoint48` on 385 - because a longer race carries more checkpoints than a short one.

Under them `event_scope_detail` carries the course rather than a score:

| Detail name | Sample value | What it holds |
|---|---|---|
| `distance` | `0.0 km` | how far into the course the checkpoint sits |
| `distance_to_go` | `0` | the complement |
| `distance_type` | `finish_line`, `mountain1` | what kind of point it is |
| `distance_name` | `1` | |
| `altitude` | `10 m` | |
| `Yellow jersey group` | | the group holding the race lead at that point |
| `Green jersey group` | | the points classification |
| `Polka dot jersey group` | | the mountains classification |
| `White jersey group` | | the young-rider classification |

**A scope type `0` exists whose name is empty**, on 95 events, and it carries `distance` and
`distance_type` with the sample values `Finish` and `mountain1`. It is not read further.

<!-- MANUAL PASTE ZONE: 30 SCOPES — insert approved additions immediately before this marker; do not move or delete it. -->

## Properties

`GLOBAL-DISCOVERY-011` measured 33 property rows sport-wide on 2026-08-16, all of type
`metadata`, across three owners.

On the event, 16 names:

| Name | Rows | Sample |
|---|---:|---|
| `Live` | 10578 | `no` |
| `Round` | 10519 | `1` |
| `Kilometers` | 9002 | `0.7` |
| `StartName` | 8997 | `'s-Hertogenbosch` |
| `EndName` | 8997 | `'s-Heerenhoek` |
| `RaceType` | 7897 | `normal` |
| `ParticipantType` | 7739 | `athlete` |
| `StageType` | 7279 | `flat` |
| `Number` | 2050 | `0` |
| `Verified` | 798 | `yes` |
| `medal_related` | 577 | `yes` |
| `track_condition` | 434 | `Dry` |
| `weather` | 434 | `Cloudy` |
| `TopResults` | 117 | `10` |
| `discipline` | 106 | `Road Cycling` |
| `StartTimeToBeDecided` | 56 | `no` |

On the participant, 9 names: `date_of_birth` 18731, `height` 1962, `weight` 1935,
`status` 19272, `IsNationalTeam` 265, `tdf_stage_wins` 140, `bicycles` 68, `HomePage` 65,
`founded` 60, `professional_status` 3.

On the tournament stage, 3: `Live` 3500, `StatusComment` 256 (sample `Cancelled`), `Venue` 33.

**The `discipline` event property is present on 106 events and is the legacy path.**
`DATABASE.md` `DB-SEM-019` records that discipline lives in `object_discipline` and that the
property is superseded; `object_discipline` reaches 10566 events here against the property's
106. The decision taken for Ice Hockey on 2026-08-15 - that no statement reads the property -
applies for the same reason, and is not re-opened by the property existing here.

**`StartName` and `EndName` are the sport's own geography** and reach 8997 events each, which
is a layer no other opened sport carries. Neither is read further yet.

<!-- MANUAL PASTE ZONE: 30 PROPERTIES — insert approved additions immediately before this marker; do not move or delete it. -->

## Generic relations and disciplines

**One discipline, `628 Road Race`**, on 10566 of 10578 events and on 1791 of 2018 statistics,
measured 2026-08-16. Twelve events carry no discipline relation.

`object_relation` holds five source-target pairs sport-wide: `4 -> 151` on 3524 rows (the
stage to its age class, 3 distinct classes), `83 -> 33` on 1791 (the statistic to its
discipline, 44 distinct), `83 -> 151` on 1792 (the statistic to its age class, 2 distinct),
`2 -> 152` on 2 and `1 -> 153` on 1.

Stage reference storage (`GLOBAL-DISCOVERY-014`) shows the country written directly as
`11 International` with the age class `1 SENIOR` on the championship stages read.

<!-- MANUAL PASTE ZONE: 30 GENERIC RELATIONS AND DISCIPLINES — insert approved additions immediately before this marker; do not move or delete it. -->

## Statistics

| statistic_typeFK | Owner type | Participant shard | Data shard | Fields/config | Evidence |
|---:|---:|---:|---:|---|---|
| 11 | 3 (tournament) | `statistic_participants11` | `statistic_data11` | `1270` Rank, `1272` Duration, `1273` Comment, `1277` Medal, `1426` Time, `1427` Time Difference; config `1463` Start date, `1464` End date, `1470` Gender, `1471` Event id, `1472` Standing id | `GLOBAL-DISCOVERY-015`, `-016`, `-017`, `-030` |

`statistic_typeFK = 11` is **Comp.Rank** in this project. 2018 statistics own the type at
`object_typeFK = 3`, and `GLOBAL-DISCOVERY-015` returned that one pair and no other, so the
owner level was not chosen from alternatives.

Data fields measured 2026-08-16: `1270 Rank` 184694 values over 1959 statistics,
`1426 Time` 85959 over 776, `1427 Time Difference` 70676 over 1070, `1273 Comment` 30712 over
737, `1272 Duration` 2592 over 113, `1277 Medal` 2063 over 688.

**`1429 Team` is declared and never written**, which separates this sport from Ice Hockey where
the same field carries the rider's side on 43708 rows. `GLOBAL-DISCOVERY-031` confirms it holds
zero values here, along with `1271 Points`, `1274 Laps Behind`, `1275 Order`, `1276 Pair`,
`1278 Qualification rank`, `1390 Distance`, `1403 Penalties` and `1428 Wind`.

**The two time fields each hold both an absolute time and a gap**, and the difference is the
leading `+`. `GLOBAL-DISCOVERY-028` measured 2026-08-16:

| Field | Shape | Values | Statistics |
|---|---|---:|---:|
| `1426 Time` | `+#:#` | 66665 | 748 |
| `1426 Time` | `+#:#:#` | 15102 | 401 |
| `1426 Time` | `#:#:#` | 3960 | 770 |
| `1426 Time` | `+#h #:#` | 140 | 1 |
| `1426 Time` | `#:#` | 54 | 5 |
| `1426 Time` | `<EMPTY>` | 33 | 1 |
| `1427 Time Difference` | `+#:#` | 64264 | 950 |
| `1427 Time Difference` | `<EMPTY>` | 2790 | 46 |
| `1427 Time Difference` | `+#:#.#` | 2402 | 93 |
| `1427 Time Difference` | `#:#:#` | 693 | 693 |

**`+#h #:#` writes the hour as a letter**, and it occurs in exactly one statistic:
`Tour de France Male - Competition Rank`, 140 riders, values from `+1h 02:43` to `+3h 24:16`.
It is the same quantity as `+#:#:#` in a different notation, and it appears where the gap runs
into hours, which on a Grand Tour is the back of the field.

**`1427 Time Difference` is empty on 2790 riders across 46 statistics**, including
`Summer Olympics Mens Road Race Stage`, `World Championship RR Race` (79 and 33 riders) and
`Paris-Tours`. This is the largest empty population read so far and is the one that does not
look like a notation.

**`1277 Medal` holds one medal too many in three statistics**: `gold` on 689 values over 688
statistics and `silver` on 689 over 687, against `bronze` on 685 over 685.

<!-- MANUAL PASTE ZONE: 30 STATISTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Reference values

**Statuses**, `GLOBAL-DISCOVERY-003` sport-wide 2026-08-16: `finished` / `6 Finished` on 9608
events, `cancelled` / `106 Cancelled` on 796, `notstarted` / `1 Not started` on 172,
`notstarted` / `5 Postponed` on 1, `interrupted` / `17 Abandoned` on 1. Five combinations, and
796 cancelled events is a population no other opened sport carries at that share.

**Round types**, `GLOBAL-DISCOVERY-018` sport-wide, 24 of them. Twenty-one are stage numbers
`1` to `21` under ids `38` to `58`, one is `173 Final` on 599 events, and two are neither:

- **`0` carries an empty name** on 53 events across 4 templates and 13 tournaments, 41 of them
  named `Race`.
- **`89` is named `1`** and holds a single event, while `38` is also named `1` and holds 3086.
  `DATABASE.md` `DB-SEM-012` records that one round name exists under two ids; this is that
  case, with one event on the wrong side of it.

**Name patterns.** The whole tail was read in one statement on 2026-08-16 rather than by
pursuing it value by value, because in road cycling every race carries its own name and the
tail is a list of races rather than a list of forms. `tournament_stage` holds 541 patterns over
3528 stages, 92 of them occurring once; `statistic` holds 305 over 2018, 72 occurring once.
Neither layer holds an untrimmed name, a non-ASCII character, a lower-case opening or a blank.
**Sixteen statistic name patterns hold a double space**, which is the only hygiene breach in
either layer. 55 stage patterns and 2 statistic patterns join words with an unspaced hyphen,
which in this sport is how a course is named - `Polenca - Andratx` spaced, `Paris-Tours` not.

<!-- MANUAL PASTE ZONE: 30 REFERENCE VALUES — insert approved additions immediately before this marker; do not move or delete it. -->

## Event and round representation

**The round number is not the stage number, and the gap is systematic.** Read on 2026-08-16
through `GLOBAL-DISCOVERY-019` over all 24 round types: every numbered round holds a large
majority named for it and a consistent minority named one lower.

| Round type | Name | Events | Most common event name | Next |
|---:|---|---:|---|---|
| 41 | `4` | 1117 | `Stage 4` x921 | `Stage 3` x175 |
| 42 | `5` | 923 | `Stage 5` x753 | `Stage 4` x160 |
| 43 | `6` | 589 | `Stage 6` x472 | `Stage 5` x112 |
| 44 | `7` | 408 | `Stage 7` x329 | `Stage 6` x77 |
| 58 | `21` | 67 | `Stage 21` x61 | `Stage 20` x6 |

The offset is exactly one and runs the length of the chain. What produces it is not confirmed;
it is recorded under Open questions rather than asserted.

**Split stages share a round.** `Stage 3b`, `Stage 8a` and `Stage 8b` appear beside their whole
counterparts, which is the sport running two half-stages in one day.

**No event here is named after the riders in it, and that follows from the competition model
rather than from this sport's habits.** Only a head-to-head sport writes `Team 1 - Team 2`,
because that name is the contest between two entries; a field of 120 riders has nothing to put
in such a name. `GLOBAL-DQ-096 EVENT_NAME_DOES_NOT_NAME_ITS_PARTICIPANTS` therefore does not
apply and is recorded `Not applicable` in `SPORTS/params.json`. Measured 2026-08-16 before the
rule was stated: 9611 of 9611 events, every one naming zero of its 94 to 124 competitors. The
three sports that do instantiate that template - Curling, Ice Hockey and Soccer - are all
`H2H (team)`, and `GLOBAL_DQ/README.md` now carries the rule.

**`173 Final` is the only round that travels**, reaching 599 events across 14 templates and 24
tournaments - `Race` 385, `Time Trial` 199, `Stage` 8. The championships settle on `Final`
while the stage races number their rounds, and rounds `15` to `21` exist in a single template,
`10356 World Tour 1 Grand Tour`.

<!-- MANUAL PASTE ZONE: 30 EVENT AND ROUND REPRESENTATION — insert approved additions immediately before this marker; do not move or delete it. -->

## Confirmed sport-specific storage semantics

**Cost lives in `event_participants` and `result`, not in the event count.** With 120
participations to an event and 1.14 million rows in each of `100 Rank` and `101 Duration`, a
statement that walks the sport once per person does not return: `GLOBAL-DISCOVERY-033` failed
on both its runs on 2026-08-16 for exactly that reason, and was rewritten to group each
participation path once rather than count it per person. Any statement written here is read
against that shape first.

<!-- MANUAL PASTE ZONE: 30 STORAGE SEMANTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Open questions

1. **What produces the one-stage offset between the round type and the event name?** Every
   numbered round holds a minority named one lower - 175 of 1117 on round `41`, 160 of 923 on
   `42`, and so on down the chain. A prologue occupying a round would produce exactly this, but
   nothing has been read that confirms it. Answering it decides whether the round number can be
   used to check the stage number at all.
2. **Are `102 Points` and `222 Laps behind` one field or two?** They cover the same 12 events
   and the same 31 rows, and both sample as `0`.
3. **What are the nine templates that hold tournaments and no events?** `10350 World
   Championship RR` (male) holds 69 tournaments and no event, `10352` (female) 42, `10351` and
   `10353 World Championship TT` 9 and 16, and the three `Summer Paralympics` templates one
   each. The `(IOC)` twins carry the same counts against the same names.
4. **Which spelling of a disqualification does the sport mean?** `Disqualified` on 1400 rows,
   `DSQ` on 146 and `DQ` on 5, with `HD` 3111, `OTL` 137 and possibly `OOT` 1 doing the same
   for a rider outside the time limit. No comment vocabulary parameter is recorded until this
   is settled.
5. **What do `a`, `FF#`, `FTM`, `HUD` and `OOT` mean?** Each was read on the row and each is
   confined to a handful of events, recorded under Event result types above.
6. **Why is `1427 Time Difference` empty on 2790 riders across 46 statistics?** Every other
   empty population read in this sport is a notation; this one is not obviously one.
7. **What are the 12 events with no `object_discipline` relation?** The sport has one
   discipline and 10566 of 10578 events carry it.
8. **What is scope type `0`, whose name is empty, on 95 events?**

<!-- MANUAL PASTE ZONE: 30 OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
