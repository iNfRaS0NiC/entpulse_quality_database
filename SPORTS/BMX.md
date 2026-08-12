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
- Latest evidence date: 2026-07-25
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
| Reference values | Used | result_type, scope_type, discipline, statistic_type and statistic_data_type names confirmed |
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
| duration | 101 | Bare seconds: `+0.038` gap, or plain `98.455` for the leader | Duration | Confirmed-data |
| points | 102 | | Points | Confirmed-data |
| comment | 104 | Closed set of status codes | Comment | Confirmed-data |
| medal | 501 | | Medal | Confirmed-data |
| duration_full_time | 557 | `m:ss.f` or bare seconds; populated in 9 events only | Full-time duration | Confirmed-data |
| wave_1 | 547 | | Wave 1 | Confirmed-data |

`101 Duration` carries the sport's times and follows the leader/gap convention, but it
stores them as bare seconds with no colon: `+0.038` for a gap, `98.455` for a leader. This
is what `BMX-DQ-030` exists for, the colon-tolerant global shape being too loose here.

`557 Full-time duration` is the opposite case. It is present but effectively unused: 421
participant rows across 9 events, against 61 463 rows in 7 994 events for `101`. Its values
take both `m:ss.f` and bare-second shapes. A check whose eligible population requires an
active full time therefore audits nine events for this sport and its coverage count says so
- the finding to read is the coverage, not the absence of violations.

`104 Comment` is not free text. Its whole active population resolves to a closed set of
status codes:

| Value | Meaning | Note |
|---|---|---|
| `Q` | Qualified to the next round | The dominant value by a wide margin; a progression marker, not an invalid result |
| `DNF` | Did not finish | |
| `DNS` | Did not start | |
| `Disq.` | Disqualified | The most common of three spellings of one status |
| `Disqualified` | Disqualified | |
| `DSQ` | Disqualified | |
| `REL` | Relegated | A placing penalty; a relegated rider still holds a classification |
| `DNF/Q` | — | A single row combining two markers; no confirmed meaning |

Three spellings of Disqualified are in use, and which one dominates depends on the layer:
`Disq.` at event level, `DSQ` among Comp.Rank data. Neither is a rare typo of the other, so
the sport stores one status under three spellings rather than mistyping one of them.

`Q` is the sport's dominant Comment value because the format qualifies riders out of heats.
That is the opposite of a sport where the same value appears a handful of times and reads as
leakage, which is why the accepted set is recorded per sport rather than globally.

`REL` marks a placing penalty and not the absence of a result, so a relegated rider is
expected to carry a rank.

`GLOBAL-DQ-122` returns 1 391 findings over 9 325 finished ranked events, and the shape of
the gap matters more than its size. It is neither an era nor a round type: the absence runs
from 2004 to 2025 at roughly one event in ten every year, and it appears in every round the
sport holds — `Heats` 823 of 2 838, `Final` 209 of 539, `Qualifier` 144 of 1 169,
`Semi Finals` 75, `Quarter Finals` 53. The same round type is clean in the majority of its
own events, which rules out the reading that a moto is placed without a time by design.
What is left is a standing coverage gap in the feed: `101 Duration` reaches 7 994 of the
9 325 events, and where it is missing the placing rests on nothing stored.

`RESULT_TIE_VALUE_TYPE_LIST` for this sport is `101` alone, so no second field can stand in
for the duration the way `557` does for Triathlon.

### What shape `101 Duration` is actually written in

Measured 2026-08-12 over every active event participant in the sport, split by placing:

| Position | Shape | Rows | Events | Range written |
|---|---|---|---|---|
| rank 1 | absolute, plain | 8 000 | 7 994 | `22.598` – `95.20` |
| every other rank | absolute, plain | 51 158 | 7 968 | `11.20` – `98.455` |
| every other rank | absolute, clock | 1 540 | 1 271 | `1:00.002` – `3:27.565` |
| every other rank | gap (`+`) | 759 | 26 | `+0.037` – `+9.775` |
| every other rank | other | 6 | 1 | `58.995 +`, `1:18.619 +` |

Three things follow, and they are worth keeping apart.

**The field holds absolute times for every placing, not a leader and a set of gaps.** 59 158 of
the 60 698 non-clock rows are absolute, and the `+` shape appears in 26 events out of 7 994.
Whatever the intended convention was, what is stored is a full time per rider.

**Two notations are in use, and inside a single event they never overlap.** The highest plain
value written in an event that also uses clock notation is `59.977`; the lowest clock value in
the same events is `1:00.002`. The boundary is exactly one minute and holds without a single
exception across all 1 271 events that carry both — so a check reporting "this event mixes two
notations" would report 1 271 events that are perfectly consistent.

**Where the boundary is not held is small and specific:** 19 events, 105 rows, writing a minute
or more in plain seconds — `60.02`, `61.12`, `98.455` — against `1:00.02` elsewhere. Rank 1 is
its own case: it is written plain in every one of its 8 000 rows, up to `95.20`, so it never
takes clock notation at all.

No check is written for any of this. The notation question sits inside the first finding rather
than beside it: if the field's convention is settled as absolute-per-rider, the notation rule
has to be stated for that convention before it can be checked, and 105 rows are likely to be
corrected in the same pass. `GLOBAL_DQ/README.md` records why `GLOBAL-DQ-120` leaves the
question alone — it reads precision, and notation is a question about magnitudes.

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
| 11 (Competition Stats) | tournament (object_typeFK=3) | statistic_participants11 | statistic_data11 | Data: Rank(1270), Points(1271), Duration(1272), Comment(1273), Pair(1276), Medal(1277), Time(1426), Time Difference(1427), Team(1429). Config: Start date(1463), End date(1464), Gender(1470), Event id(1471) | Confirmed-data |

The `1273 Comment` data field holds its own closed set of status codes, and it is not the
same set the event layer uses: `DNF`, `DNS`, `No Time`, `DSQ`, `Disqualified`, `Disq.`,
`REL`, and empty values.

Two differences from the event layer are structural rather than incidental. `Q`, the
dominant event-level Comment value, does not occur here at all, consistent with Comp.Rank
being built from a final classification rather than from round-by-round progression.
`No Time` occurs only here: the source carried no time for a rider who is nonetheless
expected to have finished, so it marks a missing measurement and not a missing result.

The three spellings of Disqualified are present in this layer too, but `DSQ` dominates here
while `Disq.` dominates at event level. A check reading either layer must take its accepted
set from that layer's own inventory.

`1271 Points` is the only data field carrying a measured quantity, and it occurs under
IOC-purpose templates only. A statistics check excludes those templates by contract, so
`GLOBAL-DQ-077` has an empty eligible population here and `NUMERIC_DATA_TYPE_LIST` stays
empty. The event layer is not affected by this: `GLOBAL-DQ-076` does not exclude IOC-purpose
templates, and the event-level `102 Points` result type is recorded in
`NUMERIC_RESULT_TYPE_LIST`.

The sport stores its Comp.Rank times in the deprecated `1272 Duration` field together with
`1427 Time Difference`, leaving the current `1426 Time` field empty. `GLOBAL-DQ-029` is the
check that names this. `GLOBAL-DQ-046` reads the same absence as a rank/time mismatch and
therefore reports its whole eligible population for this sport; it has to be read after
`GLOBAL-DQ-029` and not as an independent finding.

`PRECISION_DATA_TYPE_LIST` is `1272` for the same reason, and it is the one parameter here
that deliberately names a deprecated field. The alternatives are both empty: `1426 Time` holds
nothing, and `1271 Points` occurs under IOC-purpose templates only, which every statistics
statement excludes — the absence `NUMERIC_DATA_TYPE_LIST` already records. Auditing the
superseded field is not an endorsement of it; 321 statistics hold 6 171 duration values there
and anything reading this sport's Comp.Rank times reads them from `1272`.

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
| statistic_type | 11 | Competition Stats |
| statistic_data_type (data) | 1270 | Rank |
| statistic_data_type (data) | 1271 | Points |
| statistic_data_type (data) | 1272 | Duration |
| statistic_data_type (data) | 1273 | Comment |
| statistic_data_type (data) | 1276 | Pair |
| statistic_data_type (data) | 1277 | Medal |
| statistic_data_type (data) | 1426 | Time |
| statistic_data_type (data) | 1427 | Time Difference |
| statistic_data_type (data) | 1429 | Team |
| statistic_data_type (config) | 1463 | Start date |
| statistic_data_type (config) | 1464 | End date |
| statistic_data_type (config) | 1470 | Gender |
| statistic_data_type (config) | 1471 | Event id |

<!-- MANUAL PASTE ZONE: 58 REFERENCE VALUES — insert approved additions immediately before this marker; do not move or delete it. -->

## Event and round representation

event.status_type/status_descFK combinations confirmed: finished/6, notstarted/1, cancelled/106.

event.round_typeFK is confirmed active for BMX events, referencing the round_type table. Round type names are not unique identifiers — multiple round_type IDs share identical name text (e.g., two IDs named 'Heats', two named 'Quarter Finals', two named 'Final'); queries must reference round_typeFK by ID, not name. A confirmed unmapped value round_typeFK=0 occurs with no matching round_type row, distinct from a NULL round_typeFK.

A single round_typeFK value can be attached to events representing logically different rounds. Confirmed for round_typeFK=189 (Seeding), which is used by events named as Time Trial Superfinal, Seeding Run and Semifinal Heat across different tournament templates. Round type identity must not be treated as a reliable indicator of the actual round an event represents

BMX Comp.Rank participants carry a Phase through `object_round` (object_typeFK=138, type='phase'), recording the round the participant's rank was taken from. Phase is not universal: a large share of active BMX Comp.Rank participant rows carry no phase row at all.

The round types used by BMX Phase values are not the set BMX events use, and the split follows the knockout flag (`DB-SEM-012`). BMX events use the **non-knockout** variants — 176 Quarter Finals, 178 Semi Finals, 184 1/8, 185 1/16, 188 1/32, 173 Final — while the majority of Phase values use the **knockout** variants of the same names: 3, 2, 4, 5, 6, 9. Phase additionally carries round types BMX events never use, confirmed for 19 (Small Final) and 152 (Qualifier), both knockout; and BMX events use round types that never appear as a Phase, confirmed for 189 (Seeding) and the unmapped 0. Comparing a BMX Phase against its event's round_typeFK by ID alone reports nearly the whole population as mismatched and is not a valid check.

The complete set of `event.round_typeFK` values BMX events currently carry, confirmed by
inventory: 3 (Quarter Finals), 9 (Final), 38, 171 (Preliminary), 173 (Final), 176 (Quarter
Finals), 178 (Semi Finals), 179 (Qualifier), 180 (Repechage), 184 (1/8), 185 (1/16), 188
(1/32), 189 (Seeding), 204 (Heats), 320 (Heats), plus the unmapped 0. Three names occur under
two IDs each - Heats as 204 and 320, Quarter Finals as 176 and 3, Final as 173 and 9 - which
is the duplication the paragraph above warns about, now quantified.

`38` resolves to a `round_type` row named `1`, and the round it stands for is **Round 1**,
the first racing round. Confirmed two ways. Every one of the 37 distinct event names carried
by `38` has the shape `Men's Racing Round 1 Heat 4` or `Women's Racing Round 1 Heat 1`, with
no other shape present, across 3 templates and the years 2017 to 2025. And 138 tournament
stages carry `38` beside the full bracket in the same stage - `173`, `176`, `178`, `180`,
`184`, `185` and `188` - which places it before the 1/32 rather than beside it.

The bare `1` is therefore a weakness of the `round_type` reference row, not of the events
using it: the name does not say which round it is, while the events do.

<!-- MANUAL PASTE ZONE: 58 EVENT AND ROUND REPRESENTATION — insert approved additions immediately before this marker; do not move or delete it. -->

## Confirmed sport-specific storage semantics
City for a BMX tournament stage is stored via `city_object` (object_typeFK=4, objectFK=tournament_stage.id) linking to `city`, not via a direct column.

Venue is unpopulated for BMX. `venue_object` holds no active row for any BMX tournament stage (object_typeFK=4), event (5) or Comp.Rank statistic (83), and the venue field visible on the Comp.Rank edit form is unpopulated for the sport. The layer was queried complete at all three levels and returned zero active links.

That is a row count, not a structure the sport lacks: `venue_object` is the global mechanism `DATABASE.md` records, available to every sport, and `SPORTS/Curling.md` establishes that venue is newly populated in this database with the backfill still ahead. BMX is at nought per cent of that backfill. `GLOBAL-DQ-074` is therefore a `Monitor` rather than `Not applicable` — it covers every event, reports every event, and the figure to read is the proportion, which is expected to fall as the backfill reaches the sport. An earlier revision classified it away on the zero, which `CLAUDE.md` forbids: the check would then have stayed silent on the day the first venue arrived.

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

Sport 58 carries two editorially distinct sports across its three disciplines: Racing and Time Trial together form BMX Racing, while Freestyle is BMX Freestyle. A structure spanning Racing and Time Trial therefore stays inside one sport; one spanning Racing and Freestyle would cross both, which is why the two cases must not be treated as the same condition.

Every BMX tournament-level Comp.Rank statistic (statistic_typeFK=11, object_typeFK=3) that reaches a discipline resolves to exactly one. Measured independently through both confirmed paths — `statistic_config` Event id (1471) → event → `object_discipline` (owner type 5), and the direct `object_discipline` relation on the statistic (owner type 83) — no statistic maps to more than one discipline. This replaces an earlier conclusion that some BMX statistics span two disciplines, which the current data does not reproduce through either path.

The measurement is bounded by the discipline-orphan open question below. The two paths cover a similar but not identical population, and a substantial minority of active BMX Comp.Rank statistics reach neither, so they are outside this evidence and remain unclassified. A discipline-scoped check must verify that a path exists rather than assume it.

`statistic.name` for BMX tournament-level Comp.Rank statistics has no fixed taxonomy — it is a free-text label typically embedding tournament, discipline and round context. Do not treat `statistic.name` as an enum when writing checks.

A single BMX `event_participants` row can have multiple active `result` rows with
different `result_typeFK` values. Do not assume a 1:1 ratio between participation count
and result-row count when building coverage or ratio-based checks.

Confirmed active `tournament_stage.gender` values for BMX stages with active events: `male`, `female`, `mixed` — no `NULL`, empty or `undefined` values observed in this evidence.

BMX Rank (`result_typeFK=100`) values within one event are not a contiguous `1..N` sequence. A participant who did not start or did not finish keeps an active Rank row holding a sentinel value outside the finishing order, paired with an active `comment` (`result_typeFK=104`) value such as `DNS` or `DNF`. The same convention produces duplicate Rank values, where several non-finishing participants share one sentinel. Confirmed positive control: event 5124031 stores ranks `1,2,3,4,5,7,7,10`, where both `7` rows carry `DNF` and the `10` row carries `DNS`. A check asserting rank-sequence completeness must exclude participants carrying an active comment value, or it reports this convention as a defect.

Confirmed active BMX `comment` (`result_typeFK=104`) values: `Q`, `DNF`, `DNS`, `DISQ.`, `REL`, `DISQUALIFIED`, `DSQ` and `DNF/Q`. `Q` marks a participant who advanced from a qualifying heat; it accompanies a normal finishing rank and is not a non-finishing marker.

The comment field is free text with no normalized vocabulary. Disqualification alone is written four ways — `DISQ.`, `DISQUALIFIED`, `DSQ` and, in one case, the compound `DNF/Q`. Any logic that classifies a participant status by comment must match a confirmed value set, never a single token, and must be re-derived from data when the sport's evidence is refreshed.

A BMX event's Rank sequence may legitimately exceed its own participant count when the event stores competition-wide classification positions rather than within-event finishing order. Confirmed positive control: event 5221729 holds 114 active participants ranked `1..121` with interior gaps. Rank magnitude alone therefore does not identify a defect; an invalid rank is one that is both above the event's participant count and disconnected from the next lower rank in the same event.

<!-- MANUAL PASTE ZONE: 58 STORAGE SEMANTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Open questions

- Whether BMX `event.round_typeFK=0` (unmapped to any `round_type` row) is an intended sentinel value for "not assigned", or represents bad/legacy data — not yet confirmed.
- Some BMX Comp.Rank statistics (statistic_typeFK=11, object_typeFK=3) have no reliable path to a discipline: neither `statistic_config` Event id (1471) → event → `object_discipline`, nor a direct `object_discipline` relation (owner type=83) on the statistic itself, is guaranteed to exist. A statistic can be fully discipline-orphaned from both mechanisms (confirmed example: statistic_id=166712, name "Female Park"). Discipline-scoped checks and analysis for BMX Comp.Rank statistics must not assume either path is universal.
- Whether the sentinel Rank value paired with a `DNS` or `DNF` comment follows a fixed rule is not confirmed. Observed values do not resolve to one: in event 5124031 `DNF` maps to `7` and `DNS` to `10` within an eight-participant heat. Until the rule is confirmed, a check must recognise a non-finishing participant by the presence of an active comment, never by the rank value itself.
- Which convention `101 Duration` is meant to follow. `BMX-DQ-030` encodes a leader and a set of `+` gaps, and the stored data is the opposite: absolute times for every placing, with the gap shape in 26 events out of 7 994 (see "What shape `101 Duration` is actually written in"). Either the check states a convention the sport does not keep, or the sport has drifted from one it was meant to keep, and the two call for opposite corrections. Raised 2026-08-12; a notation check for the same field is held behind this answer, because the rule for writing a minute or more cannot be stated before the shape it applies to is settled.
<!-- MANUAL PASTE ZONE: 58 OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
