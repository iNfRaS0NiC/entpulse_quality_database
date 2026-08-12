# SPORT: Golf (sport_id=3)

This file is the canonical structural record for Golf. It contains only confirmed
sport-specific usage, meanings, identifiers, evidence boundaries and open structural
questions. Global database mechanisms belong in `../DATABASE.md`.

For additions, insert approved content immediately before the exact active
`MANUAL PASTE ZONE` marker in the destination subsection. Keep the marker unchanged
and at the end of its subsection. Replace existing rows or paragraphs in place when a
correction is required.

## Identity and evidence

- First discovery date: 2026-08-12
- Latest evidence date: 2026-08-12
- Verification boundary: one GLOBAL discovery sweep, sport-wide and unnarrowed, plus the
  targeted follow-ups named below. `enet_sport_code` is `g`. Two catalogue statements could
  not be run as written and were narrowed; what each narrowing gave up is recorded against
  its area. Nothing here is measured against a client scope, because none is agreed yet -
  see **Client scope is not the sport** below.

## Structural coverage

| Area | Status | Evidence |
|---|---|---|
| Core hierarchy | Confirmed | `GLOBAL-DISCOVERY-001`, `-002` |
| Event participants | Confirmed | `GLOBAL-DISCOVERY-004`, `-032` |
| Event results | Confirmed (inventory only) | `GLOBAL-DISCOVERY-007`, narrowed |
| Incidents | Confirmed absent | `GLOBAL-DISCOVERY-008` |
| Lineups | Confirmed absent | `GLOBAL-DISCOVERY-005` |
| Scope layer | Confirmed | `GLOBAL-DISCOVERY-009`, `-010` narrowed |
| Properties | Confirmed | `GLOBAL-DISCOVERY-011` |
| object_relation | Confirmed | `GLOBAL-DISCOVERY-012` |
| object_discipline | Confirmed | `GLOBAL-DISCOVERY-013`, `-032` |
| Statistics | Confirmed | `GLOBAL-DISCOVERY-015`, `-016`, `-017`, `-030`, `-031` |
| Reference values | Confirmed | `GLOBAL-DISCOVERY-014` |
| Other tables | Not checked | |

## Tables and relation paths used

Core hierarchy through `tournament_template.sportFK = 3` → `tournament` →
`tournament_stage` → `event` → `event_participants` → `result`. 37 active templates, 425
tournaments, 5464 stages, 19443 events, 585083 event participants and 3326056 result rows.
Golf is the largest sport documented here: its event-participant count is roughly two and a
half times Modern Pentathlon's, and its scope layer is an order of magnitude larger again.

`event_scope` → `scope_result` is the sport's heaviest storage by a wide margin, and the
reason two catalogue statements failed on the first sweep. `lineup` is not used at all.
`incident` is not used at all.

`object_relation` carries five active pairs: a sport-level `1 → 153`, a template-level
`2 → 152`, a stage-level `4 → 151` on 5455 of the 5464 stages, and two statistic-level pairs,
`83 → 33` on 3444 statistics and `83 → 151` on 3383.

<!-- MANUAL PASTE ZONE: 3 TABLES AND RELATIONS — insert approved additions immediately before this marker; do not move or delete it. -->

## Participant and lineup structure

Event participants are `athlete` and `team`. Athletes dominate: 14018 male and 5809 female
participant records against 36 male, 32 female and 1 mixed team. The sport registry agrees,
and additionally carries 131 male and 11 female athletes flagged inactive.

**A pair is stored as one `athlete`, not as a team with a lineup.** Golf uses no `lineup` row
anywhere - `GLOBAL-DISCOVERY-005` returns nothing for the sport - yet it contests foursomes and
fourball, and those pairings are stored as a single `athlete` participant whose name holds both
players separated by a slash: `A. Hansen/Olesen`, and at event level
`Aada Rissanen/Emilia Torvinen-Linda Stebernjak/Hannah Mitterberger`. Any check that assumes an
`athlete` participant is one person is therefore wrong here, and any check that looks for a
pair's members in a lineup finds nothing. The `team` participants are a different thing again -
continental and national sides such as `Asia`, `Asia (f)` and `Captains`, used by the cup
competitions.

<!-- MANUAL PASTE ZONE: 3 PARTICIPANTS AND LINEUPS — insert approved additions immediately before this marker; do not move or delete it. -->

## Event result types

Seventeen active result types, from `GLOBAL-DISCOVERY-007` narrowed. The narrowing dropped the
three `COUNT(DISTINCT)` columns the statement declares and kept the sport-wide scope, so the
inventory below is complete for the sport and the per-type participant and event counts are
not yet measured. `result_row_count` is what was returned.

| result_code | result_typeFK | Value shape | Confirmed meaning | Evidence |
|---|---:|---|---|---|
| strokes_r1 | 31 | integer, and non-numeric text occurs | Strokes taken in round 1 | 547725 rows |
| par | 36 | signed integer against par | Score against par for the event | 546735 rows |
| strokes_r2 | 32 | integer, and non-numeric text occurs | Strokes taken in round 2 | 540614 rows |
| made_cut | 38 | `yes` / `no` | Whether the player survived the cut | 534976 rows |
| rank | 100 | integer, up to 9999 | Finishing place | 526444 rows |
| strokes_r3 | 33 | integer, and non-numeric text occurs | Strokes taken in round 3 | 311327 rows |
| strokes_r4 | 34 | integer, and non-numeric text occurs | Strokes taken in round 4 | 250309 rows |
| finalresult | 4 | `0` … `won` | Match-play outcome | 25479 rows |
| mpscore | 39 | text, includes `WO` | Match-play score line | 16813 rows |
| comment | 104 | text, includes `WD` | Status comment | 10257 rows |
| prize_money | 540 | decimal, `0` … `99807.62` | Prize money | 9593 rows |
| strokes_points_r1 | 526 | integer | Stableford-style points, round 1 | 1727 rows |
| strokes_points_r2 | 527 | integer | Stableford-style points, round 2 | 1713 rows |
| strokes_points_r3 | 528 | integer | Stableford-style points, round 3 | 961 rows |
| strokes_points_r4 | 529 | integer, `-1` occurs | Stableford-style points, round 4 | 881 rows |
| strokes_r5 | 35 | integer | Strokes taken in a fifth round | 484 rows |
| medal | 501 | `bronze` / `silver` / gold | Medal awarded | 18 rows |

**The sport scores a round at a time, not a single figure.** `31`–`35` and `526`–`529` are
per-round fields rather than one total, so a check reading "the event's score" has to decide
which round it means. `36 Par` is the event-level figure against par and is the closest thing
the sport has to a single score.

**Two value-shape defects are visible in the inventory itself and are not yet quantified.**
`36 Par` returns a minimum of `−9` written with the typographic minus sign `U+2212` rather than
an ASCII hyphen, which every numeric cast and every `REGEXP '^-?[0-9]+$'` treats as text.
`34 Strokes 4th round` returns a minimum of `Â`, a mojibake byte standing in a field the sport
otherwise fills with integers; `31`, `32` and `33` return `D` on the same reading. These are
recorded as observed values, not as counts - `GLOBAL-DISCOVERY-026` has not been run for any
result type here, and until it is, the size of each is unknown.

<!-- MANUAL PASTE ZONE: 3 EVENT RESULTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Incident types

Golf stores no incidents. `GLOBAL-DISCOVERY-008` returns no active incident row for the sport.
This is a structural absence rather than an empty population: the sport has no in-play event
the incident layer models.

<!-- MANUAL PASTE ZONE: 3 INCIDENTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Scope types and data types

**The scope layer holds the round of golf hole by hole, and it is the sport's largest
storage.** Five active scope types, from `GLOBAL-DISCOVERY-009`:

| scope_typeFK | Name | Containers |
|---:|---|---:|
| 305 | final_result | 2721 |
| 462 | round1 | 2028 |
| 463 | round2 | 2024 |
| 464 | round3 | 2010 |
| 465 | round4 | 1595 |

Under them, `scope_result` carries 29653897 active values across 104 distinct
`scope_data_typeFK` values and 324 scope-type/data-type combinations. The families are:

- `strokes1`–`strokes28` (302–361): strokes taken at each hole;
- `par1`–`par30` (320–351): the par of each hole;
- `mpscore1`–`mpscore28` (364–391): the match-play state hole by hole;
- `tee_time` (338), `venueFK` (396) and `starting_hole` (397).

Numbering past eighteen is real and used: `par19`–`par24` and `strokes19`–`strokes27` all carry
values, which is how the sport records extra holes. `mpscore` running to 28 alongside `strokes`
confirms that match play is scored hole by hole in the same layer as stroke play rather than in
a structure of its own.

`GLOBAL-DISCOVERY-010` could not be run as written - it timed out at 180 seconds, and again
when its three storage layers were split apart. What ran is the `scope_result` layer with the
two reference joins and the value samples removed, which is where the numbers above come from.
Two things are therefore not yet measured: the per-combination sample values, and the
`event_scope_detail` and `lineup_scope_result` layers. `lineup_scope_result` is expected to be
empty because the sport writes no lineups, but that is an expectation and not a measurement.

**`scope_data_typeFK = 0` carries 206 values and has no row in `scope_data_type`.** It occurs
under `round1` (2 values), `round2` (35), `round3` (2) and `round4` (167) and never under
`final_result`. An unmapped data type is the scope-layer counterpart of the unmapped
`round_typeFK = 0` recorded below, and neither is a count that will resolve itself.

A further set of `scope_data_typeFK` values under Golf's scopes resolves to names belonging to
other sports' vocabularies - `penalty_stroke_9` (415), `clock_penalty_4` (489),
`clock_penalty_6` (491), `clock_penalty_7` (492), `clock_penalty_15` (500) - alongside
`hole_number_for_stroke_19` through `hole_number_for_stroke_27` (424–426, 457, 459, 461, 474,
476, 747), which do read as golf. Whether the penalty names are a shared generic id or a
misfiled value is an open question below.

<!-- MANUAL PASTE ZONE: 3 SCOPES — insert approved additions immediately before this marker; do not move or delete it. -->

## Properties

Golf's property layer is the busiest of any sport documented here, and much of the sport's
competition context lives in it rather than in a typed column.

At `tournament_stage`: `Par` (4643), `Length` (4601), `Venue` (5176), `Rounds` (5458),
`Cut` (2455) and `ProjectedCut` (1032), `Prize` (3890) and `Currency` (3893),
`tee_time_round_1`–`tee_time_round_4` (2763, 2605, 2487, 2052), `Type` (5459, holding values
such as `Greensomes Matchplay`), `Tourname` (82, holding `Major`), `StatusComment` (253),
`Live`, `status`, `startDate`, `endDate`.

At `event`: `Type` (19434, holding `Match Play`), `Round` (19363), `Live` (17663),
`gameType` (11652, holding values such as `Doubles 3`), `current_hole` (5945), `Rounds` (4952),
`last_updated` (4504), `discipline` (332), `EventTypeName` (107), `Verified` (13),
`currentRound`, `playoffStarted`, `startDelayed`, `GameStarted`, `GameEnded`,
`SecondHalfEnded`, `medal_related` (4), `EndDate` (911), `Tourname` (9).

At `participant`: `status` (19826), `professional_status` (18921), `date_of_birth` (9765),
`place_of_birth` (4125), `height` (3474), `weight` (2562), `IsNationalTeam` (63),
`position` (4).

Three of these carry values that do not match their own name and are recorded as observed
rather than counted: `place_of_birth` samples as `1991-04-11`, a date in a place field;
`position` samples as `Defensive Line (DL)`, an American-football position on a golf
participant; `tee_time_round_4` samples as `---`.

<!-- MANUAL PASTE ZONE: 3 PROPERTIES — insert approved additions immediately before this marker; do not move or delete it. -->

## Generic relations and disciplines

**Golf contests two disciplines and both are large.** `object_discipline` attaches
`629 Stroke Play` to 5142 events and `630 Match Play` to 14292, and the same split reaches the
statistic layer: 3196 statistics carry Stroke Play and 248 carry Match Play.

The two are not separate competitions. Thirteen templates carry both, and several carry them in
comparable volume - `429 European Tour 1` holds 984 Stroke Play events and 955 Match Play,
`430 European Tour and PGA Tour 1` holds 180 and 1653, `436 LPGA Tour 1` holds 653 and 1099.
This is what makes the sport `Hybrid` under `DATABASE.md` `DB-SEM-015` rather than two sports
sharing an id, and it is measured from the templates rather than asserted.

`GLOBAL-DISCOVERY-032` gives the full matrix, and the first and last years each combination
occurs: Stroke Play male athlete 3646 events over 21 templates from 2001, Match Play male
athlete 7474 over 11 from 2004, Match Play team male 676 and female 611 from 2004, Stroke Play
mixed athlete 28 from 2018, Match Play mixed athlete 56 in 2018 alone.

<!-- MANUAL PASTE ZONE: 3 GENERIC RELATIONS AND DISCIPLINES — insert approved additions immediately before this marker; do not move or delete it. -->

## Statistics

| statistic_typeFK | Owner type | Participant shard | Data shard | Fields/config | Evidence |
|---:|---:|---:|---:|---|---|
| 11 | 3 (tournament) | 11 | 11 | data `1270`, `1271`, `1277`, `1476`; config `1463`, `1464`, `1470`, `1471` | 3491 statistics |
| 11 | 4 (tournament_stage) | not probed | not probed | not checked | 5 statistics |

`SHARD_ID = 11` is confirmed by probing, not derived: `GLOBAL-DISCOVERY-016` found the sport's
statistics in `statistic_participants11`, which is what `DATABASE.md` `DB-SEM-006` requires.

**Golf's Comp.Rank carries a `Par` field no other documented sport uses.** Of the 42 data types
declared for statistic type 11, Golf populates four: `1476 Par` (341045 values over 3023
statistics), `1270 Rank` (336054 over 3239), `1277 Medal` (315 over 99) and `1271 Points`
(58 over 29). `Par` is therefore not a minor field here - it is used almost as widely as Rank,
and any statistic-layer check that assumes Points is the sport's quantity will read the wrong
column.

Config is complete and uniform: `1463 Start date`, `1464 End date` and `1470 Gender` on 3445
statistics each, `1471 Event id` on 3444. The one statistic missing an Event id is a gap of
exactly one row against three complete fields.

Statistic names carry the discipline in the text - `100th Open de France - Competition Rank
(stroke play)` - which is a naming convention rather than a typed relation, and the typed
relation exists separately through `object_discipline` on the statistic.

**Five statistics sit at `tournament_stage` level rather than at `tournament`.** They are the
minority pair `GLOBAL-DISCOVERY-015` reported beside the main one and the run did not use them.
Their shard, fields and purpose are not checked.

<!-- MANUAL PASTE ZONE: 3 STATISTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Reference values

`GLOBAL-DISCOVERY-014` returns one row per stage for all 5464 stages, so the sport stores stage
reference data broadly rather than sparsely. The stage-level `object_relation` pair `4 → 151`
covers 5455 of them against just 2 distinct related objects, and the statistic-level `83 → 33`
covers 3444 against 65. Which reference each resolves to is not yet read.

<!-- MANUAL PASTE ZONE: 3 REFERENCE VALUES — insert approved additions immediately before this marker; do not move or delete it. -->

## Event and round representation

Six status combinations, from `GLOBAL-DISCOVERY-003`: `finished`/`6 Finished` on 18416 events,
`finished`/`260 Finished after play-off` on 458, `cancelled`/`106 Cancelled` on 208,
`notstarted`/`1 Not started` on 181, `finished`/`259 Halved` on 179, and
`inprogress`/`101 4th Round Started` on 1.

**`259 Halved` is a match-play status and confirms the hybrid model from a second direction.**
A halved match is a drawn head-to-head result, a state a listing sport has no way to express.

Thirty-two `event.round_typeFK` values are in use, from `GLOBAL-DISCOVERY-018`. The busiest is
`225 Main Phase` on 5020 events, which is where stroke play sits. The rest are the match-play
bracket - `176 Quarter Finals` (3656), `178 Semi Finals` (953), `173 Final` (529),
`188 1/32` (621), `185 1/16` (384), `184 1/8` (336), `186 Small Final` (36) - together with two
separate runs of numbered rounds, `38`–`43` named `1`…`6` (2723, 868, 685, 383, 457, 6) and
`89`–`92` named `1`…`4` (634, 475, 243, 48), the placement rounds `264 5/6` (465),
`263 7/8` (413), `262 5/8` (6), `22 5/6` (2), `23 7/8` (1), and `304`/`305 Playoff` (140, 4).

**Round type names are not unique identifiers here, the same way they are not in BMX.** Quarter
Finals occurs as both `176` and `3`, Semi Finals as `178` and `2`, Final as `173` and `9`,
Small Final as `186` and `19`, `1/8` as `184` and `4`, Playoff as `304` and `305`, and the
numbered rounds `1`…`4` occur twice over under two different id runs. A statement must reference
`round_typeFK` by id and never by name.

**`round_typeFK = 0` is carried by 80 events and resolves to no `round_type` row**, and
`1 no round` by a further 79. The first is unmapped, the second is a named round type meaning
the absence of one; they are different states and are not interchangeable.

<!-- MANUAL PASTE ZONE: 3 EVENT AND ROUND REPRESENTATION — insert approved additions immediately before this marker; do not move or delete it. -->

## Confirmed sport-specific storage semantics

**Client scope is not the sport.** Golf is the second sport documented here whose client scope
is narrower than the database population, and the gap is far wider than Soccer's. The sport's
volume sits almost entirely in the professional tours - `429 European Tour 1`, `431 PGA Tour 1`,
`436 LPGA Tour 1`, `430`, `434`, `9692 Challenge Tour 1`, `9418 Champions Tour 1`,
`9633 Korn Ferry Tour`, `9691 Asian Tour 1`, `9693 Sunshine Tour 1`, `10305 LIV Golf` - and in
the amateur team championships `11525`, `11526`, `11507`, `11524`. The templates an NOC client
competes under are the smallest in the sport: `9600` and `9601 Summer Olympics` at three events
each, `11498 Summer Youth Olympics` at four, `10328 Asian Games` at ten, `10327 Pan American
Games` and `11532 Southeast Asian Games` at six each, `10537`/`10538 Pacific Games` at one each,
and `9779 European Championships 1` at fifty-seven. That is under half a per cent of the sport's
19443 events. No scope is agreed yet, and no count in this file is measured against one - every
figure here is sport-wide. `SPORTS/Soccer.md` records how a narrowed scope is stated once it is.

**`12649 TEST` is a template named TEST, and it is populated.** Seven tournaments, seven stages,
seven events and 899 event participants. The event inventory also returns
`TEST - ISCO Championship` as the sole `inprogress` event in the sport. This is test data in the
production population, and any sport-wide count in this file includes it.

**`10341 Presidents Cup` has nine tournaments and no stages, events or participants.** It is an
empty branch of the hierarchy rather than a missing template, which is the state
`GLOBAL-DQ-001` exists to report.

<!-- MANUAL PASTE ZONE: 3 STORAGE SEMANTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Open questions

1. **Which templates are in the client's scope?** Nothing in this file is narrowed, and the
   answer changes every eligible count a DQ check would report. Until it is settled, a Golf
   check run sport-wide reads the professional tours, which is almost certainly not what is
   being audited.
2. **How is a pair participant meant to be read?** A foursome is one `athlete` row holding two
   names and no lineup. Whether the two players are reachable at all, and through what, is
   unknown; if they are not, the sport cannot answer "who played" for its pairs formats.
3. **How large are the two value-shape defects in the result layer?** The typographic minus in
   `36 Par` and the mojibake in `31`–`34` are visible as minimum values. `GLOBAL-DISCOVERY-026`
   has not been run for any result type and neither is counted.
4. **What are the five `tournament_stage`-owned statistics?** Shard, fields and purpose are all
   unchecked, and they are the one statistic population this sweep did not touch.
5. **Are `penalty_stroke_9` and the four `clock_penalty_*` data types genuinely Golf's?** They
   carry values under Golf scopes but read as another sport's vocabulary. A shared generic id
   and a misfiled value look identical from here.
6. **What do `event_scope_detail` and `lineup_scope_result` hold for Golf?** Neither layer was
   measured. The second is expected to be empty because the sport writes no lineups, which is
   an expectation and not a measurement.
7. **Which round is "the" score?** The sport stores strokes per round and no single stroke
   total, so any check comparing a score against a rank has to say which figure it means.

<!-- MANUAL PASTE ZONE: 3 OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
