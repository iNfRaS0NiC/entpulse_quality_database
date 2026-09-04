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
| duration | 101 | clock value | Present, and marginal - see below | 135 values over 13 events |
| duration_full_time | 557 | clock value | Present, and marginal - see below | 135 values over 13 events |

**Freestyle is judged, Racing is timed, and that is the substantive difference between the two
sports.** Racing carries 61 492 values in each of `101 Duration` and `557 Full-time duration`
and 766 in `102 Points`; Freestyle carries 4390 in Points and 135 in each clock field. The
finishing order of a Freestyle event follows the judges' score.

`547 Wave 1` is used by Racing on two values and by Freestyle on none.

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
Whether the registry can be divided by discipline at all is the open question below.

**The board exists and is deliberately empty.** It is registered in `TOOLS/sheet-registry.json`
and is still an untitled document with no tabs, because a board is handed to colleagues when its
sport is done rather than when its first check is approved. It is filled by the first run after
this sport's checks are approved, and that run also names it.

<!-- MANUAL PASTE ZONE: 58 DATA QUALITY CHECKS — insert approved additions immediately before this marker; do not move or delete it. -->

## Open questions

- **The 13 events carrying a duration.** 135 values in each of `101 Duration` and `557 Full-time
  duration`, on 13 of 272 events, in a discipline decided on points. The smallest Freestyle
  duration read on 2026-09-04 is `-1.000`, which is not a time. Whether these are a defect, a
  different discipline's rows attached to a Freestyle event, or a format this sport does use on
  a few events has not been established, and no check should assume any of the three.
- **Whether this sport declares a timed discipline at all.** Racing declares
  `TIMED_DISCIPLINE_LIST = 429, 776` and five checks read it. Freestyle is judged, so the
  parameter is recorded as not applicable in `SPORTS/params.json` and those five checks are
  skipped rather than answered - but that is a conclusion about the sport and it rests on the
  open question above.
- **The expected round set.** Four round types are in use today. Which set a check should expect
  is a judgement about the sport's format rather than a count of what it currently holds, and
  it has not been made.
- **Whether the participant registry can be divided by discipline at all.** `BMX-Freestyle-DQ-001
  PARTICIPANT_MISSING_DATE_OF_BIRTH` reports 3007 eligible here and 3010 on BMX-Racing over a
  population of 3026, so the two sports audit almost exactly the same people. Measured
  2026-09-04. Two readings are open and neither has been tested: that the registry is keyed on
  `sport.id` and holds no discipline at all, in which case no person-level check can be divided
  and the sport files should say so once; or that a path exists and this statement's discipline
  filter sits where it cannot use it, in which case it is a defect in the marker and not a fact
  about the database. Every other person-level check inherits whichever answer this gets.

<!-- MANUAL PASTE ZONE: 58 OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
