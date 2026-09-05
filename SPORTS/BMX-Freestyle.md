# SPORT: BMX Freestyle (sport_id=58, discipline 430)

This file is the canonical structural record for BMX Freestyle. It contains only confirmed
sport-specific usage, meanings, identifiers, evidence boundaries and open structural
questions. Global database mechanisms belong in `../DATABASE.md`.

**This sport is one of the three disciplines under `sport.id = 58`, not the whole of it.** The
database calls 58 `BMX` and contests Racing (429), Time Trial (776) and Freestyle (430). The
first two are one sport to anybody reading a board and are documented in `SPORTS/BMX-Racing.md`;
this file is the third. They shared one file, one board and one set of CheckIDs until
2026-09-04.

The boundary is carried by `DISCIPLINE_ID_LIST` in `SPORTS/params.json` and reaches the database
through the commented discipline filter every statement that can reach a discipline carries.
`TOOLS/README.md` owns the mechanism and `POWERBI.md` the query contract.

**The global structure is inherited and not re-measured.** Both sports are the same rows of the
same tables under the same `sport.id`, so which tables exist, which relation paths are live and
which storage layers the database uses are settled in `SPORTS/BMX-Racing.md` and are not
restated here. What this file records is where the two disciplines differ, measured on
2026-09-04, and that is the only reason it is a separate file.

For additions, insert approved content immediately before the exact active
`MANUAL PASTE ZONE` marker in the destination subsection. Keep the marker unchanged
and at the end of its subsection. Replace existing rows or paragraphs in place when a
correction is required.

## Identity and evidence

- First discovery date: 2026-09-04
- Latest evidence date: 2026-09-04
- Verification boundary: the discipline split, event result types, round types, event status
  and the Comp.Rank fields are confirmed from active data on 2026-09-04. Everything else is
  inherited from `SPORTS/BMX-Racing.md` and has not been re-measured against discipline 430
  alone: incidents, lineups, the scope layer, properties and `object_relation` are `Not checked`
  here and their status in the Racing file is a statement about `sport.id` 58 as a whole.

## Structural coverage

| Area | Status | Evidence |
|---|---|---|
| Core hierarchy | Used | sport.id=58, discipline 430; 272 events, 78 tournaments, 18 templates, 2016-2025 |
| Event participants | Used | 652 competitors ride Freestyle only, 37 ride both disciplines; read 2026-09-04 |
| Event results | Used | 5 result types, and the sport is decided on 102 Points rather than the clock |
| Incidents | Not checked | inherited from BMX-Racing, not re-measured for 430 |
| Lineups | Not checked | inherited from BMX-Racing, not re-measured for 430 |
| Scope layer | Not checked | BMX-Racing records scope types 101 and 102 for this discipline; not re-measured |
| Properties | Not checked | inherited from BMX-Racing, not re-measured for 430 |
| object_relation | Not checked | inherited from BMX-Racing, not re-measured for 430 |
| object_discipline | Used | owner type 5, disciplineFK 430; every event resolves to exactly one discipline |
| Statistics | Used | Comp.Rank on the tournament, three fields only; read 2026-09-04 |
| Reference values | Used | round_type, result_type and status_desc names confirmed 2026-09-04 |
| Other tables | Not checked | |

## Tables and relation paths used

Inherited from `SPORTS/BMX-Racing.md`. The two disciplines are rows of the same tables under
one `sport.id`, so no relation path is particular to either.

<!-- MANUAL PASTE ZONE: 58 TABLES AND RELATIONS — insert approved additions immediately before this marker; do not move or delete it. -->

## Participant and lineup structure

Participant type `athlete` only, as in Racing.

**37 competitors ride both disciplines**, out of 2726 who ride either. 2037 are Racing or Time
Trial only and 652 are Freestyle only. Measured 2026-09-04. A person-level check therefore
cannot divide the two sports cleanly, and those 37 appear under both.

<!-- MANUAL PASTE ZONE: 58 PARTICIPANTS AND LINEUPS — insert approved additions immediately before this marker; do not move or delete it. -->

## Event result types

Five types carry values, measured 2026-09-04 across the whole discipline.

| result_code | result_typeFK | Value shape | Confirmed meaning | Evidence |
|---|---:|---|---|---|
| rank | 100 | positive integer | Finishing place | 4825 values over 262 events |
| points | 102 | decimal | **The deciding value of this sport.** A judged score, not a time | 4390 values over 230 events |
| medal | 501 | `gold`, `silver`, `bronze` | Medal awarded | 352 values over 118 events |
| comment | 104 | short code, e.g. `Disq.` | Status qualifier on a competitor | 140 values over 39 events |
| duration | 101 | clock value | **Not a time. The judges' score, written into a clock field** - see below | 135 values over 13 events |
| duration_full_time | 557 | clock value | **Not a time. The judges' score, written into a clock field** - see below | 135 values over 13 events |

**Freestyle is judged, Racing is timed, and that is the substantive difference between the two
sports.** Racing carries 61 492 values in each of `101 Duration` and `557 Full-time duration`
and 766 in `102 Points`; Freestyle carries 4390 in Points and 135 in each clock field. The
finishing order of a Freestyle event follows the judges' score.

`547 Wave 1` is used by Racing on two values and by Freestyle on none.

**The 135 clock values are the score, stored in the wrong field.** Read 2026-09-05 across all
thirteen events. Event 3291684, the 2020 Olympic seeding round, is the only one of the thirteen
carrying both Points and the clock fields, and on all nine competitors `557 Full-time duration`
is the competitor's own Points value read as seconds and formatted as a clock:

| Competitor | Rank | `102 Points` | `557 Full-time` | `101 Duration` |
|---|---:|---:|---|---|
| Logan Martin | 1 | 90.97 | `1:30.970` | `1:30.970` |
| Rimu Nakamura | 2 | 87.67 | `1:27.670` | `-3.000` |
| Daniel Dhers | 3 | 85.10 | `1:25.100` | `-5.000` |
| Anthony Jeanjean | 4 | 84.65 | `1:24.650` | `-6.000` |
| Nick Bruce | 9 | 3.80 | `3.800` | `-27.000` |

`101 Duration` holds the gap to the leader in the same invented units - `-3.000` where the gap
is 3.3 points - which is what the `-1.000` first read on 2026-09-04 is: a one-point gap, and
never a time. The leader carries the full value in both fields rather than a gap of zero.

**Twelve of the thirteen carry no Points at all**, so on those the score exists only in the
field that misnames it. All thirteen are ordinary Freestyle events - four Pan American Games
2019, four 2023, two European Championships 2025 and the Olympic seeding round - so this is
neither another discipline's rows nor a format the sport uses. It is one wrong way of entering
a result, repeated. Reported rather than repaired; `CLAUDE.md` owns that boundary.

<!-- MANUAL PASTE ZONE: 58 EVENT RESULTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Incident types

Not checked for discipline 430.

<!-- MANUAL PASTE ZONE: 58 INCIDENTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Scope types and data types

Not checked for discipline 430. `SPORTS/BMX-Racing.md` records scope types 101 and 102 against
Freestyle and 101, 102 and 103 against Racing, from the reading of 2026-07-25.

<!-- MANUAL PASTE ZONE: 58 SCOPES — insert approved additions immediately before this marker; do not move or delete it. -->

## Properties

Not checked for discipline 430.

<!-- MANUAL PASTE ZONE: 58 PROPERTIES — insert approved additions immediately before this marker; do not move or delete it. -->

## Generic relations and disciplines

`object_discipline` owner type 5 (event), `disciplineFK = 430`. Every event under `sport.id` 58
resolves to exactly one discipline and none to two, measured 2026-09-04 across all 9390 events.

**Two templates carry both disciplines**, both named `Summer Olympics`: 12256 with 96 Racing
events and 4 Freestyle, and 12257 with 51 and 4. Every other template is one discipline only -
51 of 53. A template-level statement cannot divide the two sports on those two, which is why
the boundary is drawn on the discipline and not on the template list.

<!-- MANUAL PASTE ZONE: 58 GENERIC RELATIONS AND DISCIPLINES — insert approved additions immediately before this marker; do not move or delete it. -->

## Statistics

| statistic_typeFK | Owner type | Participant shard | Data shard | Fields/config | Evidence |
|---:|---:|---:|---:|---|---|
| 11 | 3 (tournament) | `statistic_participants11` | `statistic_data11` | three data fields only | read 2026-09-04 |

**Eighteen Comp.Rank statistics reach this discipline**, out of 438 under `sport.id` 58 that any
statistics check can see. Twelve resolve through both available paths and six through the direct
`object_discipline` relation at owner type 83 alone; none resolves through the event path only,
so owner type 83 covers all eighteen. That is why the discipline filter on a statistic is
written against owner type 83 rather than through `statistic_config` Event id.

A further 194 statistics under `sport.id` 58 reach no discipline by either path. All 194 sit on
four `(IOC)` templates - 12435, 12366, 13135 and 13134 - which every statistics statement
already excludes, so none of them is a statistic any check can see and none is lost to either
sport. `POWERBI.md` owns the IOC exclusion.

**Three data fields carry values and six do not**, measured 2026-09-04:

| statistic_data_typeFK | Name | Freestyle values | Racing values |
|---:|---|---:|---:|
| 1465 | Organization | 163 | 20971 |
| 1270 | Rank | 163 | 20607 |
| 1277 | Medal | 12 | 647 |
| 1272 | Duration | 0 | 6164 |
| 1427 | Time Difference | 0 | 5619 |
| 1273 | Comment | 0 | 1369 |
| 1426 | Time | 0 | 169 |
| 1276 | Pair | 0 | 2 |
| 1429 | Team | 0 | 1 |

The six zeros are a data state and not a structural absence: the fields are a global mechanism
this discipline has not populated, and nothing about the storage prevents it. They are not
grounds for calling a check `Not applicable`; `CLAUDE.md` owns that distinction.

**A Comp.Rank here ranks the competition, and its top is the final exactly.** Read 2026-09-05 on
the four records that carry participants - the 2025 World Cups at Montpellier, Shanghai and Sakai,
the last of those twice. They rank 58, 47, 38 and 20 riders against finals of 12, 12, 12 and 20,
and every rider standing in both holds the same number in both: 12, 12, 12 and 20 agreements and
not one disagreement across 56 comparisons. The best place absent from the final is 13 in each of
the three that have a qualifier, so places 1 to 12 are the finalists with nobody else among them
and 13 downward are the riders the final did not reach. `GLOBAL-DQ-154` was written for this rule
and `BMX-Freestyle-DQ-111` asserts it here; it returns nothing today, which is what the rule
holding looks like.

**Fourteen of the eighteen Comp.Rank records hold no participant at all.** Measured the same day:
only the four 2025 World Cups are populated, while 2016, 2019, 2020, 2023, 2024 and the 2025
European Championships are empty shells with their configuration filled in and nobody ranked.
`BMX-Freestyle-DQ-050 COMP.RANK_NO_PARTICIPANTS` reports all fourteen. That is 78 per cent of the
layer, and it is the reason `GLOBAL-DQ-154` can only see four: it has nothing to compare on the
rest.

**The linked event is the final and the ranking is wider than it**, which matters for any check
written against this layer. A statement asserting that everyone ranked took part in the linked
event would report 46 of Montpellier's 58 riders and be wrong to. `GLOBAL-DQ-042` asks the
question the other way round - whether each finalist appears in the ranking - and is correct here
for that reason.

<!-- MANUAL PASTE ZONE: 58 STATISTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Reference values

| Kind | id | Name |
|---|---:|---|
| discipline | 430 | Freestyle |
| round_type | 173 | Final |
| round_type | 152 | Qualifier |
| round_type | 2 | Semi Finals |
| round_type | 189 | Seeding |
| status_desc | 6 | Finished |
| status_desc | 1 | Not started |

<!-- MANUAL PASTE ZONE: 58 REFERENCE VALUES — insert approved additions immediately before this marker; do not move or delete it. -->

## Event and round representation

**Four round types, against Racing's twelve.** Measured 2026-09-04:

| round_typeFK | Name | Freestyle events | Racing events |
|---:|---|---:|---:|
| 173 | Final | 121 | 426 |
| 152 | Qualifier | 115 | 1074 |
| 2 | Semi Finals | 34 | 650 |
| 189 | Seeding | 2 | 31 |

Racing additionally uses 320 Heats (2870), 38 (1275), 3 Quarter Finals (964), 168 Repechage
(734), 4 `1/8` (651), 5 `1/16` (320), 6 `1/32` (109) and 171 Preliminary (14). Freestyle uses
none of the eight. A Freestyle competition is a qualifier, a semi-final and a final; the heat
and repechage ladder belongs to racing.

**The expected set is five, and the fifth is a judgement rather than a measurement.** Decided
2026-09-04: `ROUND_TYPE_LIST = 2, 152, 171, 173, 189`. Four of those are the round types measured
above; `171 Preliminary` is not, and Freestyle holds no event on it today. It is in the list
because a Freestyle competition may legitimately hold a preliminary round, which is a statement
about the format and not about the current population - the distinction `CLAUDE.md` draws between
a structural absence and a data state, read here in the direction that keeps the check useful on
the day such a round arrives. The cost is equally plain: a genuinely wrong `171` on a Freestyle
event is now not reported. `SPORTS/params.json` `_names` carries the same reasoning.

**Event status differs too.** Freestyle holds 264 finished events and 8 not started, and no
cancelled event; Racing holds 9109 finished and 9 cancelled, and none not started. That is a
data state on the day it was read, not a structural claim about either sport.

<!-- MANUAL PASTE ZONE: 58 EVENT AND ROUND REPRESENTATION — insert approved additions immediately before this marker; do not move or delete it. -->

## Confirmed sport-specific storage semantics

Inherited from `SPORTS/BMX-Racing.md` except where this file records otherwise. The one
semantic that is particular to this discipline is the deciding value: a Freestyle result is
settled on `102 Points`, and the clock fields it does carry do not decide anything.

<!-- MANUAL PASTE ZONE: 58 STORAGE SEMANTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Data quality checks

**`BMX-Freestyle-DQ-001 PARTICIPANT_MISSING_DATE_OF_BIRTH`**, approved 2026-09-04. It reads
`GLOBAL-DQ-007` and asks which registered competitors of this sport carry no date of birth.
`GLOBAL_DQ/README.md` declares that template mandatory for every sport in the index.

**It does not divide between the two sports, and that was known when it was approved.** Measured
the day it was written: 1198 findings of 3007 eligible here, against 1198 of 3010 on BMX-Racing,
where the same statement run against neither discipline reports 3026. Two coverages summing to
6017 over a population of 3026 is not a boundary; it is the same people counted twice. The
discipline filter narrows the paths by which a person competed, and the population this check
audits is the sport's participant registry, which `sport.id` 58 keys on the sport rather than on
the discipline.

The consequence for a reader of the boards is concrete: a colleague who fills in a date of birth
from the BMX-Racing board will see the count fall on this one too, without having touched it.

**Settled 2026-09-05: the check stays the same on both sports, and the duplication is accepted.**
The registry is `object_participants` keyed on `object = 'sport'` and `objectFK = 58`; it carries
no discipline at all, so this is a fact about the database rather than a filter in the wrong
place. The runner's `-WithoutRegistryBranch` would drop that branch and leave the three
participation paths, which do divide - but it would also drop everybody registered to the sport
with no recorded participation, and those are the records most likely to be incomplete, which is
what this check exists to find. Keeping them audited twice is the cheaper mistake than not
auditing them at all. Every other person-level check on these two sports inherits the same
answer.
Whether the registry can be divided by discipline at all is the open question below.

**`BMX-Freestyle-DQ-002 EVENT_RESULTS_CLOCK_VALUE_IN_JUDGED_DISCIPLINE`**, approved 2026-09-05.
It reads `GLOBAL-DQ-152`, written the same day for this finding and for any judged sport after
it: a discipline decided by judging records a score, so a value in one of its clock fields is a
number entered in the wrong field. Two `check_type`s because they are two repairs -
`CLOCK_VALUE_BESIDE_ITS_SCORE` where the score is also present and the clock value is a
duplicate to remove, and `CLOCK_VALUE_INSTEAD_OF_SCORE` where it is not and removing the clock
value would delete the result.

Measured on approval: **13 findings of 262 eligible**, twelve of them the second kind. The
eligible population is the Freestyle events carrying any result at all, not all 272. The check
is fast - 0,4 seconds - because the clock fields are nearly empty here, which is the point.

The reason it took a check to find is worth recording: the values are well-formed clocks and
they run monotonically with the finishing order, so `GLOBAL-DQ-045` and `GLOBAL-DQ-054` would
have passed every one of them. They are only wrong if you already know the sport is judged.

**The sport was opened to all eight categories on 2026-09-05 and holds 110 live checks**,
`BMX-Freestyle-DQ-001` through `-111`, one of them deprecated by the `GLOBAL-DQ-004`/`-150` merge:
39 `WRONG_RESULTS`, 24 `MISSING_VALUES`, 15 `WRONG_STRUCTURE`, 12 `NO_RELATED_RECORDS`,
6 `MALFORMED_NAME`, 6 `DATE_RANGE_MISMATCH`, 5 `WRONG_GENDER` and 3 `WRONG_DISCIPLINE`.

They arrived in five batches on that one day - 66 on what the sport could already run, then 10,
9, 9 and 13 as each group of parameters was settled. **The parameters are the work and the
approvals followed them.** 55 are declared, and `SPORTS/params.json` says of each whether it was
measured here or inherited from BMX-Racing, because those are not the same kind of statement.

**The candidates were drawn from what BMX-Racing instantiates rather than from the whole
catalogue**, because this file already records that the global structure is inherited and not
re-measured: the two sports are the same rows of the same tables under one `sport.id`. What
needed deciding was only where the two disciplines genuinely differ. Of BMX-Racing's 115
templates, 66 could run here on the parameters this sport declares and 48 could not, each of
those blocked on a value that is a decision rather than a copy - `TIMED_DISCIPLINE_LIST` above
all, which must stay undeclared here because the discipline is judged and every event would be
reported. Those 48 are unopened, not refused.

**The Comp.Rank layer is in, against the standing pause.** Since 2026-08-26 a new sport is
opened without it while event results are corrected. This sport is not a new opening: its
statistics layer was read on 2026-09-04 and is documented above, so 21 Comp.Rank templates were
included by the user's decision of 2026-09-05.

**Two candidates carry a caution rather than a clean prerequisite.**
`GLOBAL-DQ-082 TOURNAMENT_STAGE_EVENT_DISCIPLINE_INCONSISTENT` asks whether a stage groups one
discipline, and 16 of the 523 stages under `sport.id` 58 group more than one - four of them
reaching Freestyle, on `BMX World Championship` and `Summer Olympics`. It was approved on the
measurement rather than on the prerequisite's plain reading: four findings, not a whole
population, and BMX-Racing already reports the same stages from the other side.
`GLOBAL-DQ-109 EVENT_SETTINGS_DISCIPLINE_STORAGE_MISMATCH` reads the discipline property, and
this file records Properties as `Not checked`; it was approved on the same inheritance argument
and its behaviour here is not yet observed.

**One parameter is recorded as not applicable rather than merely unset.**
`TIMED_DISCIPLINE_LIST` cannot have a value here: 430 Freestyle is judged and its order follows
`102 Points`. That is the sport's format and not a state of its data, so `GLOBAL-DQ-045`, `-046`,
`-054`, `-056` and `-111` are `Not applicable` and will never be numbered - `GLOBAL-DQ-054` says
as much in its own prerequisite. `SPORTS/params.json` `_notApplicable` carries the reason.

**One candidate is deliberately unopened.** `GLOBAL-DQ-019 EVENT_DURATION_FORMAT_MISMATCH_TO_RANK`
asserts that rank 1 holds an absolute time and the rest hold plus-prefixed gaps. BMX-Racing has an
open question about whether that is the convention this database keeps at all, and the same field
here holds scores rather than times. Approving it would inherit an argument nobody has settled.

**Almost none of them has been run.** The 200-row gate was measured for `BMX-Freestyle-DQ-002`,
which returned 13, and for `-111`, which returned none. What the rest return is unknown until the
sport's first full run, and any that floods is a candidate to withdraw - which `POWERBI.md` warns
is not a neutral correction. Two are known in advance to be large and were approved with the
number in view: `GLOBAL-DQ-118` reports all 121 finals, because `173 Final` carries
`knockout = no` in a table every sport shares, and `GLOBAL-DQ-040` reports 103 of them, because
only 18 of this discipline's 121 finals are linked to a Comp.Rank.

**The board exists and is deliberately empty.** It is registered in `TOOLS/sheet-registry.json`
and is still an untitled document with no tabs, because a board is handed to colleagues when its
sport is done rather than when its first check is approved. It is filled by the first run after
this sport's checks are approved, and that run also names it.

<!-- MANUAL PASTE ZONE: 58 DATA QUALITY CHECKS — insert approved additions immediately before this marker; do not move or delete it. -->

## Open questions

None. The three this file opened on 2026-09-04 - the thirteen events carrying a duration, whether
the sport declares a timed discipline, and whether the participant registry can be divided - were
all answered on 2026-09-05 and their answers are recorded in the sections they belong to.

<!-- MANUAL PASTE ZONE: 58 OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
