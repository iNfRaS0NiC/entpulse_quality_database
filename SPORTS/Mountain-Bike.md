# SPORT: Mountain-Bike (sport_id=56)

This file is the canonical structural record for Mountain-Bike. It contains only confirmed
sport-specific usage, meanings, identifiers, evidence boundaries and open structural
questions. Global database mechanisms belong in `../DATABASE.md`.

For additions, insert approved content immediately before the exact active
`MANUAL PASTE ZONE` marker in the destination subsection. Keep the marker unchanged
and at the end of its subsection. Replace existing rows or paragraphs in place when a
correction is required.

## Identity and evidence

- First discovery date: 2026-08-31
- Latest evidence date: 2026-08-31
- Verification boundary: the whole `GLOBAL-DISCOVERY` catalogue, 001 through 033, was run for
  this sport on 2026-08-31, Comp.Rank layer included by the user's decision of the same day.
  `GLOBAL-DISCOVERY-033 PARTICIPANT_DUPLICATE_CANDIDATES_BY_NAME`, which counts an athlete's
  history through the statistic shard to find two rows that may be one person, failed inside
  the chain because the runner substituted `PERSON_PARTICIPANT_TYPE_LIST` unquoted; it was
  re-run by hand with `'athlete'` and returned. Every **summary** named below
  is complete coverage of what the sport stores.

**The sport is `Mountain Bike`, `sport.id = 56`, enet code `mb`.** It is not `Cycling`
(`sport.id = 30`), `Track Cycling` (`55`), `BMX` (`58`) or `Para Cycling` (`117`), and nothing
recorded here was measured against any of them. The five are separate rows and a rider
registered under one of them is not reachable through another.

Four detail statements were pursued to completion rather than sampled, so the inventories they
belong to are closed: `GLOBAL-DISCOVERY-019 EVENT_ROUND_TYPE_USAGE_DETAIL`, which lists the
events filed under one round type, over all four round types; `GLOBAL-DISCOVERY-021
EVENT_NAME_PATTERNS_DETAIL`, which lists the events matching one name shape, over all eleven
event-name patterns; `GLOBAL-DISCOVERY-026 EVENT_RESULTS_VALUE_PATTERNS_SUMMARY`, which censuses
the value shapes one result type holds, over all five result types; and `GLOBAL-DISCOVERY-028
STATISTIC_DATA_VALUE_PATTERNS_SUMMARY`, the same census on the statistic side, over all seven
statistic data types.

Three were left as samples by the user's decision of 2026-08-31, and the rows beneath their
summaries are examples rather than coverage: `GLOBAL-DISCOVERY-023
TOURNAMENT_STAGE_NAME_PATTERNS_DETAIL`, which lists the stages matching one name shape, pursued
5 of 195 stage-name patterns; `GLOBAL-DISCOVERY-025 STATISTIC_NAME_PATTERNS_DETAIL`, the same
listing for statistic names, pursued 5 of 233; and `GLOBAL-DISCOVERY-027
EVENT_RESULTS_VALUE_PATTERNS_DETAIL`, which lists the result rows carrying one value shape,
pursued the three patterns each result type ranks first, 3 of 47 combinations. Each summary above them is complete; only the listings are
partial, and they are a long tail of one competition's own name rather than a shape the sport
uses.

## Structural coverage

| Area | Status | Evidence |
|---|---|---|
| Core hierarchy | Used | 45 templates under `tt.sportFK = 56`, standard five-level path |
| Event participants | Used | `athlete` only, male and female |
| Event results | Used | Five active result types |
| Incidents | Not used | The complete-layer query returned zero active rows |
| Lineups | Not used | Zero active rows; the sport contests no team event |
| Scope layer | Not used | Zero active containers and zero value rows, both layers |
| Properties | Used | Three owner objects |
| object_relation | Used | Four active source/target combinations |
| object_discipline | Used | Four disciplines, on events and on statistics alike |
| Statistics | Used | Comp.Rank, `statistic_typeFK = 11`, owner `3 tournament`, shard 11 |
| Reference values | Used | Round types, event statuses, age classes, the result comment vocabulary |
| Other tables | Not checked | |

**The competition model is `Listing`, with individual participants only.** Measured 2026-08-31:
`event_participants` carries `athlete` and nothing else, an event's field runs to tens of riders,
and the sport populates the event-level rank result type `100 Rank` across its finished events.
There is no pairing to read and no team to resolve a result through.

## Tables and relation paths used

The sport uses the standard hierarchy without deviation:
`tournament_template -> tournament -> tournament_stage -> event -> event_participants`,
anchored on `tt.sportFK = 56`.

**The gender is on the stage, not on the template.** Every one of the sport's 889 active stages
carries a `stage_gender`, measured 2026-08-31, and the template above it does not divide by
gender the way Speed Skating's does. A statement identifying a competition by template name
therefore addresses both genders of it, which is the opposite of the trap that sport sets.

<!-- MANUAL PASTE ZONE: 56 TABLES AND RELATIONS — insert approved additions immediately before this marker; do not move or delete it. -->

## Participant and lineup structure

**`event_participants` carries only `athlete`.** No team has ever started an event in this
sport, in either gender, and there is no discipline in it that fields one.

**The sport registry holds teams that never race.** Its roles are `athlete` and `team`, and the
team rows are trade teams a rider is affiliated to rather than an entity that contests anything.
A statement reading the registry therefore meets a participant type the event layer never
returns, and the two lists are deliberately different in `SPORTS/params.json` for that reason.

**The lineup layer is empty and is empty by construction, not by omission.** A lineup hangs off
a team's participation in an event, and this sport records no such participation, so there is
nothing for one to hang from. This is `Not used` rather than a gap to be filled.

<!-- MANUAL PASTE ZONE: 56 PARTICIPANTS AND LINEUPS — insert approved additions immediately before this marker; do not move or delete it. -->

## Event result types

| result_code | result_typeFK | Value shape | Confirmed meaning | Evidence |
|---|---:|---|---|---|
| `rank` | 100 | `#`, one pattern only | The rider's place in the field | `GLOBAL-DISCOVERY-026 EVENT_RESULTS_VALUE_PATTERNS_SUMMARY` over the whole type, 2026-08-31 |
| `duration` | 101 | 30 patterns; the leader carries an absolute time and everyone behind a signed gap | Race time, or the gap to the leader | `GLOBAL-DISCOVERY-026 EVENT_RESULTS_VALUE_PATTERNS_SUMMARY` over the whole type, 2026-08-31 |
| `comment` | 104 | 12 spellings | Why a rider has no time, or how far down they finished | `GLOBAL-DISCOVERY-026 EVENT_RESULTS_VALUE_PATTERNS_SUMMARY` over the whole type, 2026-08-31 |
| `laps_behind` | 222 | 11 patterns, times and laps together | How far behind the rider finished | `GLOBAL-DISCOVERY-026 EVENT_RESULTS_VALUE_PATTERNS_SUMMARY` over the whole type, 2026-08-31 |
| `medal` | 501 | `gold`, `silver`, `bronze` and nothing else | The medal awarded | `GLOBAL-DISCOVERY-026 EVENT_RESULTS_VALUE_PATTERNS_SUMMARY` over the whole type, 2026-08-31 |

**`101 Duration` is the sport's untidiest field and the shapes are not interchangeable.** Thirty
distinct patterns, measured 2026-08-31 over every value the type holds. The two largest are the
gap forms `+#:#` and `+#.#`; the absolute forms `#:#.#` and `#:#:#` sit beside them. Beyond those
the field also holds `#.#.#` with dots where a clock would use colons, `#:#,#` with a comma for
the decimal, `#:#:#:#` in four components, and a signed-negative `-#`. A statement parsing this
field on one convention is parsing a fraction of it.

**`222 Laps behind` does not only hold laps.** The name says laps and the field holds both: the
lap forms `-#LAP`, `# lap`, `# laps` sit in it alongside the duration forms `+#.#`, `+#:#` and
`+#:#:#`. Whichever of the two a reader assumes, the other half is misread, and the field cannot
be cast to a number without deciding which it is first.

**The comment vocabulary is not normalized.** Disqualification is spelled four ways —
`Disqualified`, `DSQ`, `DQ`, `Disq.` — and being lapped six — `Lapped`, `LPD`, `-# LAP`,
`-# LAPS`, `# Lap`, and the lap forms inside `222` above. Non-starting and non-finishing are
`DNS` and `DNF`, and `No time` is a third thing again.

<!-- MANUAL PASTE ZONE: 56 EVENT RESULTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Incident types

**The incident layer holds no active row for this sport.** `GLOBAL-DISCOVERY-008` returned
nothing on 2026-08-31. What another sport would record as an incident this one writes into
`104 Comment` instead — the non-start, the non-finish and the disqualification are all there.

<!-- MANUAL PASTE ZONE: 56 INCIDENTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Scope types and data types

**The scope layer is not used at all.** Both halves were measured on 2026-08-31 and both
returned nothing: `GLOBAL-DISCOVERY-009` found no active event-scope container, and
`GLOBAL-DISCOVERY-010` no value row under one. The sport stores a race as a single result per
rider and keeps no split, lap or period beneath it, which is what a mass-start discipline decided
on one crossing of the line has no need of.

<!-- MANUAL PASTE ZONE: 56 SCOPES — insert approved additions immediately before this marker; do not move or delete it. -->

## Properties

Three owner objects carry properties, measured 2026-08-31:

| Owner | Property names |
|---|---|
| `event` | `discipline`, `Kilometers`, `Live`, `medal_related`, `Round`, `Type` |
| `participant` | `date_of_birth`, `height`, `weight`, `status`, `tdf_stage_wins` |
| `tournament_stage` | `Live`, `StatusComment` |

**`Kilometers` is on almost no event.** It carries the course length and is filled on ten events
of the sport's eleven hundred, so a statement reading distance from it is reading a property the
sport does not maintain rather than one it fills badly.

**`tdf_stage_wins` is a road-cycling property on a mountain-bike rider.** It sits on eight
participants and counts Tour de France stage wins, which is a fact about a career in a different
sport that happens to hang off a participant this one also registers.

<!-- MANUAL PASTE ZONE: 56 PROPERTIES — insert approved additions immediately before this marker; do not move or delete it. -->

## Generic relations and disciplines

**Four disciplines, and both layers agree on them**: `402 Cross Country`, `403 Downhill`,
`404 Marathon` and `551 Cross Country Marathon`. Each appears on events through
`object_discipline` with `object_typeFK = 5` and on Comp.Rank statistics with
`object_typeFK = 83`, and the set is the same on both sides.

**`404 Marathon` and `551 Cross Country Marathon` coexist and are not the same id for one thing.**
Both are in use, on events and on statistics, and the second is the smaller. Which competitions
belong to which, and whether the split is a distinction the sport draws or two spellings of one
discipline, is recorded below as an open question rather than answered here.

**`object_relation` carries four active source and target combinations**, measured 2026-08-31:
template to `152 tournament_sub_set`, stage to `151`, and statistic to `33` and to `151`.

**The stage carries country and age class on every row, and host country on none.** Measured
2026-08-31 over all 889 active stages: a direct country and an age class are on every one, a city
on 665 of them, and the host-country relation is used by nothing. A statement reading a venue
country through the host-country path finds nothing in this sport and must read the direct one.

<!-- MANUAL PASTE ZONE: 56 GENERIC RELATIONS AND DISCIPLINES — insert approved additions immediately before this marker; do not move or delete it. -->

## Statistics

| statistic_typeFK | Owner type | Participant shard | Data shard | Fields/config | Evidence |
|---:|---:|---:|---:|---|---|
| 11 | 3 tournament | `statistic_participants11` | `statistic_data11` | 7 data fields, 4 config fields | `GLOBAL-DISCOVERY-015 STATISTIC_TYPES_AND_OWNERS`, `GLOBAL-DISCOVERY-016 STATISTIC_PARTICIPANT_SHARD_USAGE` and `GLOBAL-DISCOVERY-017 STATISTIC_DATA_AND_CONFIG_FIELDS`, 2026-08-31 |

**`GLOBAL-DISCOVERY-015` returned exactly one type and owner pair**, so nothing was chosen here:
there was no alternative to choose from. Comp.Rank, `statistic_typeFK = 11`, owner level
`3 tournament`, confirmed on physical shard 11.

The data fields are `1270 Rank`, `1271 Points`, `1272 Duration`, `1273 Comment`,
`1274 Laps Behind`, `1277 Medal` and `1427 Time Difference`. The config fields are
`1463 Start date`, `1464 End date`, `1470 Gender` and `1471 Event id`.

**`1272 Duration` is live here, and that is worth saying because it is not everywhere.** Speed
Skating records the same field as deprecated and reads its times elsewhere; in this sport it is
one of the two most populated data fields the layer has. A parameter naming it must be set per
sport and never carried across.

**`1427 Time Difference` holds a four-component form on a small number of rows.** Measured
2026-08-31: values shaped `+2:12:18:27.000` and `+1:00:16:56.000` on 17 rows across 5
statistics, all of them in Marathon and Downhill competitions. The field's other three shapes are
the ordinary `+#:#.#`, `+#.#` and `+#:#:#`. What the fourth component is counting is recorded
below as an open question; nothing here asserts it is a defect.

<!-- MANUAL PASTE ZONE: 56 STATISTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Reference values

**Event status.** Four combinations are in use: `finished` with `6 Finished`, `cancelled` with
`106 Cancelled`, and `notstarted` with either `1 Not started` or `5 Postponed`. A statement
treating `notstarted` as one thing is folding a postponement into a race that has simply not
happened yet.

**Round type.** `173 Final` covers all but a handful of events. `9 Final` is the
`knockout = 'yes'` member of the same name pair `DATABASE.md` `DB-SEM-012` describes and is used
on a few. `171 Preliminary` is used once. `0` resolves to no round type at all and is not a
value the sport uses — see the open question below.

**Medal.** `501 Medal` on the event side and `1277 Medal` on the statistic side both hold
`gold`, `silver` and `bronze` and nothing else.

<!-- MANUAL PASTE ZONE: 56 REFERENCE VALUES — insert approved additions immediately before this marker; do not move or delete it. -->

## Event and round representation

**The event name is the discipline, and almost nothing else.** Eleven name patterns cover the
whole sport, pursued to completion on 2026-08-31. The three largest are `Cross Country`,
`Downhill` and `Marathon`, each a bare discipline name repeated across every season, and
`Downhill ##` and `Cross Country ##` number a run within a meeting. The round is in
`round_typeFK` and in the `Round` property, not in the name.

**`Cross-Country` with a hyphen is one competition's own spelling, not scattered typing.** Sixteen
events carry it, one per year from 2009 to 2025 with 2021 absent, against the 432 that spell it
`Cross Country`. A statement matching the discipline on the event name has to allow for both, and
a repair that normalizes the hyphen away is editing one competition's whole history.

**Six events are named only `Female` or `Male`.** Three of each, in 2004, 2008 and 2012 — Olympic
years, three editions of each gender's race. The name says who raced and not what was raced, and
the discipline is only reachable through `object_discipline` for them.

**`Cross Country Eliminator` is new and is two events.** Both are dated 2025-12-11, and it is the
only event name in the sport that names a format rather than a discipline.

<!-- MANUAL PASTE ZONE: 56 EVENT AND ROUND REPRESENTATION — insert approved additions immediately before this marker; do not move or delete it. -->

## Confirmed sport-specific storage semantics

**The whole sport is inside the client boundary, decided 2026-08-31.** UK Sport takes all 45
tournament templates, so `OUT_OF_SCOPE_TEMPLATE_ID_LIST` is `0` by decision rather than by
default and a run needs no narrowing. Two consequences worth stating, because they do not hold
for the other sports in this package: a sport-wide count here is a client-scope count, and a
board built from an unnarrowed run is the board the client sees. Soccer takes 28 templates of
many and Speed Skating excludes 56 of 101, so a habit carried from either of them - reaching
for `-TemplateIds`, or reading a sport-wide number as an overcount - is wrong here.

**The leader carries a time and the field carries a gap, in `101 Duration`.** The convention is
the one `DATABASE.md` records for the timed sports: one absolute value per event and a signed
difference for everybody else. A statement reading this field as a race time is reading a gap on
all but one row per event, and a plausibility rule built on it must exclude the signed values
before it means anything.

**Being lapped is recorded in three different places.** `104 Comment` holds `Lapped`, `LPD` and
the `-# LAP` forms; `222 Laps behind` holds the lap count; and `1274 Laps Behind` holds it again
on the statistic side. A rider lapped out of a cross-country race can therefore be described by
any of the three, and a statement reading one of them alone will disagree with the other two.

**The `+` convention is not kept, and the departure is not a second convention.** Measured
2026-08-31 over the 1044 events holding ranked non-winners with a `101 Duration`: 702 store
every non-winner as a `+` gap, 281 store every one of them as an absolute time, and 61 store
some of each inside a single event. The absolute form belongs to no discipline and no era -
Downhill splits 186 against 183, Cross Country runs 334 against 81, and every season from 2009
to 2025 holds both shapes. `GLOBAL-DQ-019 EVENT_DURATION_FORMAT_MISMATCH_TO_RANK` was approved
whole on that reading, all 347 events, on 2026-08-31.

**`GLOBAL-DQ-045 EVENT_DURATION_FULL_TIME_MISMATCH_TO_RANK` reports the convention above as a
defect, and was approved anyway.** It returns 925 events, of which 826 are
`DURATION_FULL_TIME_INVALID_FORMAT`: the template tests `{{RESULT_FULL_TIME_TYPE_ID}}` against
`^[0-9]+(:[0-9]+)*(\.[0-9]+)?$`, which no `+` gap can match, and this sport points that
parameter at `101 Duration` because it has no second duration column. The 99 events reporting
only `RANK_PRESENT_DURATION_FULL_TIME_MISSING` are the defect the check was wanted for. The
user was told the split before deciding and took the check whole on 2026-08-31, so a reviewer
meeting 826 of these rows is meeting the sport behaving normally and should close them
`No Issue / Change`.

**`GLOBAL-DQ-082 TOURNAMENT_STAGE_EVENT_DISCIPLINE_INCONSISTENT` was not approved, and no
CheckID is assigned or reserved.** It returns 220 of 878 stages and all 220 are the same pair,
Cross Country and Downhill, one event of each - stage 836253 `World Cup - Pietermaritzburg`
(2014) is the shape, and it repeats across the World Cup and four continental championships. A
World Cup round runs both disciplines at one venue in one weekend, so the rows are the sport's
own calendar rather than a defect. This is deliberately **not** recorded as `Not applicable`:
the decision rests on what the 220 rows turned out to hold rather than on a structure the sport
lacks, and the candidate stays available if the stage model is ever read differently. Decided
2026-08-31.

**Six approved checks return `eligible_count = 0`, and every one is a sentinel rather than a
misdirected scope.** `GLOBAL-DQ-130 EVENT_PARTICIPANT_ORGANIZATION_MISSING` scopes by design
only on tournaments that fill the organization somewhere, and this sport fills it nowhere - the
fact is reported at its own grain by `GLOBAL-DQ-147
TOURNAMENT_PARTICIPANT_ORGANIZATION_MISSING_THROUGHOUT`, which returns all 399 tournaments.
`GLOBAL-DQ-132` and `GLOBAL-DQ-146
EVENT_PARTICIPANT_ORGANIZATION_COUNTRY_CONTRADICTS_COMPETITOR` (and `_DETAIL`), and
`GLOBAL-DQ-136` and `GLOBAL-DQ-145` for the same rule on the Comp.Rank side, have no
organization to contradict anything. `GLOBAL-DQ-143
COMP.RANK_ATHLETE_RANKING_DISAGREES_WITH_ITS_TEAM_TWIN` has no team twin because the sport
fields no team in any event, which is a data state and not a structural absence: the registry
carries team-typed participants and the shard would hold them. All six were approved on
2026-08-31 to hold the invariant for the day the field is filled.

**The organization gap is reported at two grains on purpose.** `GLOBAL-DQ-147` returns 399 of
399 tournaments and `GLOBAL-DQ-131 COMP.RANK_PARTICIPANT_ORGANIZATION_MISSING` returns 818 of
818 statistics, which is one absence said 1217 times. Both were approved on 2026-08-31 with
that overlap stated, so that the Comp.Rank layer can be seen apart from the event layer.

**Four templates are `Not applicable` here, and each for its own reason.** None is assigned a
CheckID and none reserves one; decided 2026-08-31. All four read a structure this sport does
not store, rather than a population that happens to be empty.

`GLOBAL-DQ-056 EVENT_DURATION_FULL_TIME_ARITHMETIC_MISMATCH` asserts that a competitor's gap
plus the leader's time equals that competitor's own absolute time. It needs two duration
columns to compare and this sport has one: `101 Duration` carries the leader's time and
everybody else's gap in the same field, and there is no `557 Full-time duration` row anywhere in
the sport. Pointing both sides of the arithmetic at `101` would compare a column with itself.

`GLOBAL-DQ-054 EVENT_RESULTS_RANK_FULL_TIME_NOT_MONOTONIC` and `GLOBAL-DQ-111
EVENT_RESULTS_RANK_EFFECTIVE_TIME_NOT_MONOTONIC` assert that absolute times rise with rank down
the classification. Both need a column holding an absolute time for every competitor, which is
the same column this sport does not have. `GLOBAL-DQ-019
EVENT_DURATION_FORMAT_MISMATCH_TO_RANK` reads the field the sport does fill and is approved.

`GLOBAL-DQ-029 COMP.RANK_RESULTS_DEPRECATED_DURATION_USED` asserts that `1272 Duration` is a
deprecated field a sport should have stopped writing. It is live here: it is where this sport's
Comp.Rank layer keeps a rider's time, and `DATA_TIME_TYPE_ID` points at it deliberately. The
template's premise is false for this sport rather than its population empty.

**Two more templates are `Not applicable` here, decided 2026-08-31 when the last five DQ
categories were opened.** Neither is assigned a CheckID and neither reserves one.

`GLOBAL-DQ-107 EVENT_SCOPE_CONTAINER_MISSING_FOR_FINISHED` asserts that a finished event holds
a scope container - a period, a leg, a run - to hang its partial results on. This sport stores
no scope layer at all: measured 2026-08-31, `GLOBAL-DISCOVERY-009` found no active event-scope
container and the value side returned nothing either, on both layers. The template's mandatory
`SCOPE_TYPE_ID` therefore has no value to take, and inventing one would point the check at a
layer nobody has seen. Four of the sixteen documented sports instantiate it, and they are the
four that keep periods.

`GLOBAL-DQ-135 PARTICIPANT_COACH_OR_OFFICIAL_NO_PARTICIPATION_ANYWHERE` asserts that a coach or
official carried in the registry appears somewhere in the competition. This sport's registry
holds one person role, `athlete`, measured 2026-08-31 - there is no coach and no official row to
audit, and `SUPPORT_PARTICIPANT_TYPE_LIST` has nothing to name. Three of the sixteen sports
instantiate it. This is the participant-role twin of the reasoning above rather than an empty
population: `PERSON_ROLE_TYPE_LIST` for this sport is `'athlete'` alone for the same reason.

**Three templates are `Not applicable` here because they say so themselves.** Each is written
for head-to-head sports by the competition model rather than by reading any sport's rows, and
this sport lines a field up and ranks it. None is assigned a CheckID and none reserves one;
decided 2026-08-31. `GLOBAL-DQ-093 EVENT_RESULTS_MEDAL_SET_INVALID_FOR_MEDAL_ROUND` exists for a
sport that decides bronze in its own match, so no single event holds the full medal set - here
the final awards all three and `GLOBAL-DQ-037` is the check that fits. `GLOBAL-DQ-096
EVENT_NAME_DOES_NOT_NAME_ITS_PARTICIPANTS` asks whether an event is named for its two sides, and
a listing sport has nothing to put in such a name: every event here is named for its discipline.
`GLOBAL-DQ-144 EVENT_RESULTS_RANK_STORED_BY_A_HEAD_TO_HEAD_SPORT` reports a Rank as a defect
because a head-to-head event is two sides and a score; a Rank is this sport's whole
classification.

**`GLOBAL-DQ-127 EVENT_RESULTS_TIED_VALUE_WITHOUT_SHARED_RANK` was approved whole, and most of
what it returns is the rules of cycling.** It returns 385 of 1044 events. Measured 2026-08-31
over the 388 events where two riders hold one `101 Duration` under different ranks: 260 are
Cross Country, 88 Marathon and 5 Cross Country Marathon, all mass-start disciplines where the
sport gives a whole finishing group the time of the rider who led it and still ranks them in
crossing order - the largest such group is 14 riders on one value. The remaining 35 are
Downhill, where each rider starts alone and an identical time cannot be a real dead heat; there
the largest group is 11 riders on one value, which is stored precision lost rather than eleven
simultaneous runs. The user was given that split and took the check whole, so a reviewer meeting
a Cross Country or Marathon row here is meeting the sport's own convention.

<!-- MANUAL PASTE ZONE: 56 STORAGE SEMANTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Open questions

**Is `551 Cross Country Marathon` a discipline of its own or a second spelling of `404 Marathon`?**
Both are in use on events and on statistics. Answering it decides whether a marathon check reads
one id or two, and it cannot be answered from the ids alone.

**What is the fourth component of `1427 Time Difference` counting?** `+2:12:18:27.000` reads as
days, hours, minutes and seconds if the leading number is a day, and a gap of over a day in a
marathon is not a gap anybody rode. 17 rows across 5 statistics, all in Marathon and Downhill.

**Which round type do the 17 events carrying `round_typeFK = 0` belong to?** The value resolves
to no round type at all, so the events are outside the sport's own vocabulary rather than in an
unusual corner of it.

**What is `222 Laps behind` for, given that it holds durations?** Either the field is a
general "how far behind" and its name is wrong, or the duration values in it belong in
`101 Duration` and are in the wrong column. The two readings imply opposite repairs.

<!-- MANUAL PASTE ZONE: 56 OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
