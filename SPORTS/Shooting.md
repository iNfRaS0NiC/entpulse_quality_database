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

**One check runs with narrower coverage than its `eligible_count` suggests, and this is where it
is recorded.** `GLOBAL-DQ-007 PARTICIPANT_MISSING_DATE_OF_BIRTH`, running here as
`Shooting-DQ-001`, reaches a person by three paths - an event participant row, a lineup place,
and a Comp.Rank row - and reads the sport registry beside them. The Comp.Rank path is marked
optional in the statement precisely so that a sport opened without the layer still gets the other
three; with no confirmed `SHARD_ID` or `STATISTIC_TYPE_ID` the runner drops the marked pair from
the findings branch and the coverage branch together, and says so on every run. The consequence is
the part worth writing down: **an athlete reachable only through a Comp.Rank statistic, appearing
in no event and no lineup, is not audited**, and `eligible_count` - 16 113 on 2026-09-06, with 479
findings - counts the paths that were read rather than the sport's whole population. Nothing else
in the sport is narrowed this way; the run named this one check and no other. It corrects itself
when the Comp.Rank layer comes back, which is the same reason the layer is `Not checked` rather
than `Not applicable`.

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
- `103 Distance` holds 29 rows in 18 shapes, and **not one of them is a number.** Seventeen rows
  in sixteen shapes are multi-line blobs of six numbers apiece - `286`, `299`, `284`, `292`,
  `298`, `288` on one row, separated by newlines - and every one of them sits in a single event,
  5792171 `50m Rifle 3 Positions Team Final`. Six numbers in the 280-300 band is a competitor's
  six series of a three-position match, so a whole scorecard has been written into one cell of a
  field named for a distance. The other twelve rows carry `Q`, the qualification mark, in two
  events, and one carries the literal word `Comment` - event 5765754, `Double Trap Qualification`,
  European Championships Shotgun 2006.
- `535 Tops` holds 77 rows in 38 shapes. `DNS` is the single commonest value at 23 rows in 23
  events, which is a no-result mark sitting in a tie-break field; then `Q` on 5 rows, `--/--` on
  3, `-` on 2, `QF` on 2 and `Medal Matches` on 1. Its 32 numeric shapes are not one quantity
  either: `11`, `16`, `17` and `2` are the size a shoot-off tally would be, while `1141`, `1154`,
  `1176`, `1179`, `115.5`, `133.7`, `154.3`, `176.6`, `198` and `199.7` are scores.
- `536 Zones` holds 23 rows in 15 shapes. `Gold`, `Silver` and `Bronze` on 2 rows each, then
  `4th`, `6th`, `7th` and `Final` on one apiece - medals, placings and a round name in a field
  meant for a count. Its numbers are `0`, `1`, `2`, `4`, `6`, `7`, and also `503` and `507`,
  which are scores.

Event 5974406 `25m Pistol Final`, South East Asian Games 2017, appears in two of these at once:
`Gold` in Zones and `Medal Matches` in Tops.

Profiled whole on 2026-09-06 - every row of all three fields, not a sample. **This bears directly
on the open question about shoot-offs below.** `535 Tops` and `536 Zones` are the only fields that
could record what separates two competitors on the same score, and what they mostly hold is
something else: of the 100 rows across the two, the non-numeric ones are medals, placings, round
names and a `DNS`, and the numeric ones mix plausible tallies with scores. The fields built for
the question are themselves not being used for it.

**All of this was decided on 2026-09-06, and most of it turned out to be watched already.**
`Shooting-DQ-070 GLOBAL-DQ-070 EVENT_RESULTS_NUMERIC_FIELD_NON_NUMERIC` reads
`NUMERIC_RESULT_TYPE_LIST`, which names `103`, `535` and `536` among its five, and reports every
value in them that is not a number - 46 findings, and among them all three of `103 Distance`'s
events, the `Gold` and `Medal Matches` of 5974406, and the `Comment` of 5765754. So `103 Distance`
needs nothing: it holds 29 rows in 18 shapes and **not one of them is numeric**, which puts the
whole field inside that check already. Adding `103` to `UNUSED_RESULT_TYPE_LIST` was considered
and rejected for that reason - it would have put a second check over the same three events, which
is the argument that kept `GLOBAL-DQ-019` out.

**What was not watched is a number in the right format and the wrong field.** Measured the same
day: 30 of the 41 numeric rows in `535 Tops`, across 9 events, are character for character the
competitor's own `102 Points` - `1141` against `1141`, `1176` against `1176`, `199.7` against
`199.7` - and `536 Zones` has 4 more such rows in 2 events. A four-digit team score in a tie-break
field is a perfectly good number, so nothing reported it. `Shooting-DQ-076
EVENT_RESULTS_TOPS_OR_ZONES_HOLDS_THE_COMPETITORS_OWN_POINTS` now does: 11 findings of 16 eligible
events, which is two thirds of everything that uses these two fields at all.

**One event is the same defect in a form no check sees, and it is named here rather than lost.**
In 5971614 `Skeet Team Final` the two fields are swapped outright - `536 Zones` holds `503` and
`507` while `102 Points` holds `6` and `2`. Nothing equals anything, so an equality test passes it,
and `Shooting-DQ-070` passes it too because both values are numbers. Catching a swap needs a rule
about which magnitudes belong in which field, and nobody has made that rule for this sport;
asserting one to gain a single event is the wrong trade.

The small matches are reported with the large ones and that is deliberate. `4` against `4` and `6`
against `6` in a trap team event may be coincidence, because both quantities are small there. The
user's decision of 2026-09-06 was that a row a person can judge belongs in front of a person
rather than behind a threshold nobody agreed.

**Equal scores ranked apart are how this sport ranks, and what separated them is almost never
stored.** A final is shot off and a qualification is counted back on inner tens; the database keeps
the outcome and not the reason. Measured 2026-09-06 over every finished event, counting each group
of competitors sharing one `102 Points` value while holding different Ranks: **31 578 groups in
4 620 events, of which four carry anything that records a tie-break.**

- **4 groups in 4 events** carry a genuine shoot-off mark in `104 Comment`: `pr, s-off 7`,
  `pr, s-off 8`, `s-off: 2`, `q s-off: 4`.
- **5 groups in 3 events** carry a small number in `535 Tops` or `536 Zones`, and even those come
  mixed with `4th`, `Silver`, `Bronze` and `Gold` on the same rows, or are pairs like `63, 64` and
  `81, 83` that are scores rather than tallies.
- **17 groups in 17 events** carry something in those fields that explains nothing - `DNS` in
  sixteen of them and `Q` in one.
- **31 552 groups in 4 611 events** carry nothing anywhere.

A first sweep the same day put the explained count at 26. It counted a group as explained if any
tied competitor held anything at all in `535 Tops` or `536 Zones`, and profiling those two fields
whole showed what they hold. The figure is four, or nine counting the small numbers generously.

By round, from that first sweep and left as it was measured - its `535 Tops`/`536 Zones` column
reads as "holds something there" rather than "is explained":

| Round type | Tie groups | Events | Shoot-off comment | `535 Tops` / `536 Zones` | Neither |
|---|---|---|---|---|---|
| `179 Qualifier` | 28 343 | 3 148 | 0 | 16 | 28 327 |
| `173 Final` | 1 808 | 913 | 3 | 5 | 1 800 |
| `round_typeFK 0` | 712 | 130 | 0 | 0 | 712 |
| `178 Semi Finals` | 443 | 291 | 0 | 0 | 443 |
| `191 Elimination` | 88 | 32 | 0 | 0 | 88 |
| `38` (named `1`) | 56 | 24 | 0 | 0 | 56 |
| `181 bronze` | 56 | 54 | 0 | 1 | 55 |
| `171 Preliminary` | 34 | 12 | 0 | 0 | 34 |
| `39` (named `2`) | 29 | 8 | 0 | 0 | 29 |
| `176 Quarter Finals` | 7 | 6 | 0 | 0 | 7 |
| `152 Qualifier` | 1 | 1 | 0 | 0 | 1 |
| `228 Placement Phase` | 1 | 1 | 1 | 0 | 0 |

Event **5967926** `25m Pistol Final`, Asian Championship, 6 February 2026, is the shape in one row
set: two competitors on 35 points, ranked 1 and 2, gold and silver, with `104 Comment`,
`535 Tops`, `536 Zones` and `101 Duration` empty on every row of the event. Swap the two ranks and
nothing in the database contradicts it. That is what `Shooting-DQ-075
EVENT_RESULTS_TIED_SCORE_WITHOUT_SHARED_RANK_IN_MEDAL_ROUND` puts in front of a reviewer, and why
it is restricted to the rounds where the answer costs somebody a medal.

**The sport writes two different ranking conventions and neither is dominant.** After a tie, a
rank sequence can skip the places the tie consumed - 1, 2, 2, 4 - or run on dense - 1, 2, 2, 3.
Measured 2026-09-06 over every finished event, counting each tie group that has a next rank after
it: **283 groups in 81 events skip and 264 groups in 92 events run dense**, with three more groups
in three events doing neither. Both conventions run the whole history, 2004 to 2025, so this is
not an old practice replaced by a new one; the three that are neither are all 2004. An event
picks one and holds to it - of the 72 events reported for a dense tie, two also contain a skip
somewhere else, and no more.

Which of the two is correct is still not settled as a rule, and the package is not neutral
between them. **The user decided on 2026-09-06 what to do about that, and it was not to pick a
convention:** the events stay in the check and the review judges them one at a time, fixing or
leaving each. Nothing is excluded and nothing is declared correct in advance. `GLOBAL-DQ-119 EVENT_RESULTS_RANK_SEQUENCE_BROKEN`, running here as
`Shooting-DQ-066`, asserts the skip convention in its own words - "ties skipping the places they
consume" - and carries a `RANK_SEQUENCE_TIE_DOES_NOT_SKIP` branch for the events that do not.
Of its 447 findings over 8 632 eligible events on 2026-09-06: 251 are `RANK_SEQUENCE_GAP`, 124 are
`RANK_SEQUENCE_DOES_NOT_START_AT_ONE`, and **72 are `RANK_SEQUENCE_TIE_DOES_NOT_SKIP` - the dense
events, reported as defects because the template picked the other convention.** Under the dense
reading those 72 are correct data and the 81 skip events would be the finding instead; the check
reports only 10 of those 81 today, and for other reasons.

The check was approved on 2026-09-06 knowing this, on the user's decision. It is written here
rather than left in a commit message because the reason a check carries a known unresolved
question is the part nobody can reconstruct from the board.

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

**One more is `Not applicable` because the sport has no duration to hold a convention** -
`GLOBAL-DQ-019 EVENT_DURATION_FORMAT_MISMATCH_TO_RANK`. It asserts the leader/gap form, the
winner carrying an absolute time and everyone behind a signed difference, and
`GLOBAL_DQ/README.md` states its prerequisite as a sport confirmed to follow that convention on
its duration result type. This sport follows no such convention because it writes no duration:
the user confirmed on 2026-09-06 that `101 Duration` should not be populated here at all, which
is what made the classification decidable - until that answer it was `Not checked` rather than
`Not applicable`, and the distinction was real. Run the same day to be sure of what was being
set aside: 390 findings of 391 eligible events, and those 391 are the same events
`Shooting-DQ-074 GLOBAL-DQ-155 EVENT_RESULTS_UNUSED_RESULT_TYPE_HOLDS_VALUES` already reports.
Nothing goes unwatched by this exclusion; what it would have added is a second row over one
population, asserting a convention the sport does not have rather than the defect it does.

**With these, every one of the 155 GLOBAL DQ templates has a decision behind it for this sport**,
as of 2026-09-06: 74 instantiated as `Shooting-DQ-001` to `-074`, 24 `Not applicable`, 52
belonging to the Comp.Rank layer this opening deliberately left out, two deprecated, and three
that only a head-to-head sport can hold. **Nothing is `Not checked`** - the first sport in the
package where that is true, Modern Pentathlon having left one blocked.

**`Shooting-DQ-075` and `-076` are the sport's own statements**, both added 2026-09-06 and living
in `POWERBI_QUERIES/Shooting.sql`. The second is described under the storage semantics above. `GLOBAL-DQ-127 EVENT_RESULTS_TIED_VALUE_WITHOUT_SHARED_RANK` is
still `Not applicable` as written, for the reason above, and `Shooting-DQ-075
EVENT_RESULTS_TIED_SCORE_WITHOUT_SHARED_RANK_IN_MEDAL_ROUND` asks the same question of `173 Final`
and `181 bronze` alone. The template carries no round-type parameter and five other sports read it
whole, so adding one would put the question to Biathlon, Mountain Bike, Speed Skating, Swimming
and Track Cycling, none of whom has been asked it; the narrowing belongs to this sport and is
written here. It reported 967 findings of 4 268 eligible events on the day it was written.

## What five closed questions settled

**These five were open questions when the sport was opened and the user answered them on
2026-09-06.** Each settles structure rather than a count, and each is written down here because a
question that closes leaves nothing behind unless the answer is recorded where the question was.

- **An event without a round type is always a defect.** `event.round_typeFK = 0` resolves to no
  `round_type` row and stands on 174 events. It is not a sentinel for "not assigned": this sport
  contests no round the reference table does not name.
  `GLOBAL-DQ-006 EVENT_MISSING_ROUND_TYPE`, running here as `Shooting-DQ-017`, already reports
  exactly those 174 and needs no change; the answer makes its findings confirmed defects rather
  than a shape awaiting a reading. 69 of the 174 also award a medal, which is why `round_typeFK 0`
  stays out of `MEDAL_ROUND_TYPE_LIST` - listing it there would silence the 69 instead of
  reporting them. The same question stands open on BMX and the two have still not been compared.

- **Round types `38` and `39` are round 1 and round 2.** The bare digits are what the sport calls
  them, not a truncation of a longer name. They cover 39 events between them and stay in
  `ROUND_TYPE_LIST`.

- **`152 Qualifier` is a wrong id; `179 Qualifier` is the sport's Qualifier.** 179 holds 3 679
  events from February 2004 to July 2026. 152 holds one, event `5968725` of 24 October 2017. The
  id is for the people who own the reference table to delete, with its single event repointed.
  152 was removed from `ROUND_TYPE_LIST` the same day so that
  `GLOBAL-DQ-075 EVENT_ROUND_TYPE_NOT_IN_EXPECTED_SET`, running here as `Shooting-DQ-055`,
  reports that one event: while 152 was still listed the check was `Clean` over 8 748 eligible
  events and the defect stood on no board at all.

- **`101 Duration` should not be populated in this sport.** The field name says duration and
  nothing in it is a time. Measured 2026-09-06 over all 8 922 events: 391 carry a value, 2 437
  rows in total, and not one row is a per-competitor measurement. **2 040 of them - 84%, in 373 of
  the 391 events - are one of 24 values that appear exactly once per event.** `6.943` in 263
  events, `6.93` in 261, `7.084` in 260, `7.47` and `7.482` in 259 each, `7.419` in 256, then
  `10.779` in 47, `7.895` in 46, `10.922` in 45, and fifteen more from `8.402` down to `9.649`,
  each in 12 to 22 events. Which values a competition gets follows its template - the first six
  are World Cup, the rest Asian Games, Asian Championship, African Championships and European
  Championships - and they span 2006 to 2026. They land on the leading placings and stop. Event
  5964240 `50m Pistol Final`, 8 February 2026, is the shape in one row set: thirteen competitors
  scoring 563 down to 522, the top six carrying `6.93`, `6.943`, `7.084`, `7.419`, `7.47`,
  `7.482` in that order and the other seven carrying nothing. They rise as the score falls, which
  is why they read as a plausible ordering and went unquestioned for twenty years. The remaining
  397 rows are debris of four kinds: 313 rows in 12 events where the value is character for
  character the competitor's own `102 Points`; 57 non-numeric one-offs including six athlete
  names, the country codes `FRA`, `AUT` and `SVK`, and the literal words `Points` and `Име`, which
  are column headings written in as data; 20 further numbers; and 7 bare hyphens.
  `GLOBAL-DQ-155 EVENT_RESULTS_UNUSED_RESULT_TYPE_HOLDS_VALUES`, running here as
  `Shooting-DQ-074`, reads the whole field and reported 391 events on 2026-09-06.
  Running that check returns every one of the 2 437 rows; they are not held in a file.

- **Four comment values were read on 2026-09-06 and three of them are settled by the data.**
They had been approved into `RESULT_COMMENT_VALUE_LIST` without their meaning being known.
`gm` and `bm` sit in one event, `5972406 10m Air Pistol Qualification`: `gm` on the competitors
ranked 1 and 2, `bm` on those ranked 3 and 4. That is the ISSF format - the top two of a
qualification go to the Gold Medal Match and the next two to the Bronze Medal Match - so both are
qualification marks like `q` and neither is a medal. `golden hit`, one row on the competitor
ranked 1 of `5854896 25m Pistol Medal Match`, is the deciding hit that won the match, which makes
it a third shoot-off marker beside `so` and `s-off`. `rpo` is the one still resting on an outside
source rather than on the database: 149 rows in 23 events, almost all qualifications, carrying
ordinary ranks and scores including rank 1 with the highest score of its event; in ISSF usage it
is Ranking Points Only, a competitor who shoots and is placed but cannot advance and takes
ranking points alone. The database is consistent with that and does not establish it. `a/rpo` on
one row and `rpo/rpo` on 14 rows in two events are composites of the same.

**The bare backtick in `101 Duration` belongs to that same defect.** One value in each of 88
  events, all under the `World Cup` template. Re-read 2026-09-06, it behaves exactly like the 24
  numeric constants above - once per event and never twice - and the user confirmed it as most
  likely the same mistake rather than a convention of one source. It is inside
  `Shooting-DQ-074`'s findings and needs nothing of its own.

<!-- MANUAL PASTE ZONE: 45 STORAGE SEMANTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Open questions

**None outstanding as of 2026-09-06.** The sport was opened with six and all six now carry an
answer; the two that survived the day closed last, and neither closed by being classified away.

- **Where a shoot-off or a countback is recorded when it separates two competitors on the same
  score.** Still not answered as a rule, and the user decided on 2026-09-06 not to wait for one:
  the competitors on the same score go into a check and the review reads them one at a time,
  fixing what is wrong and leaving what is right. `Shooting-DQ-075
  EVENT_RESULTS_TIED_SCORE_WITHOUT_SHARED_RANK_IN_MEDAL_ROUND` is that check, over `173 Final` and
  `181 bronze` - 967 findings of 4 268 eligible events. The whole-sport form was measured and
  rejected as unreadable: 31 578 tie groups in 4 620 events, 54% of the sport, of which four carry
  anything recording a tie-break. `POWERBI_QUERIES/Shooting.sql` holds the reasoning and the three
  narrowings that were measured and not chosen.

- **Which ranking convention is right.** Also unsettled as a rule and settled the same way. The 72
  `RANK_SEQUENCE_TIE_DOES_NOT_SKIP` findings of `Shooting-DQ-066` stay on the board and the review
  judges them; `GLOBAL-DQ-119` was not narrowed, no branch was switched off, and no convention was
  declared correct.

**What that leaves for people is a reading, not a decision.** Two of the sport's findings sets -
`Shooting-DQ-075`'s 967 events and `Shooting-DQ-066`'s 72 - rest on questions nobody has answered
in the abstract, and each row is the place to answer it concretely. That is written down here so a
later reader does not mistake a large finding count for a large defect count.

<!-- MANUAL PASTE ZONE: 45 OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
