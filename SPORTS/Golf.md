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
- Latest evidence date: 2026-08-13
- Verification boundary: one GLOBAL discovery sweep, sport-wide and unnarrowed, plus the
  targeted follow-ups named below. `enet_sport_code` is `g`. Two catalogue statements could
  not be run as written and were narrowed; what each narrowing gave up is recorded against
  its area. **Every figure in this file is sport-wide, and the client scope is narrower than
  the sport** — see **Scope** below. A count here is what Golf holds, not what a check now
  returns, and the two differ by roughly a seventh of the events and a third of the event
  participants.

## Structural coverage

| Area | Status | Evidence |
|---|---|---|
| Core hierarchy | Confirmed | `GLOBAL-DISCOVERY-001`, `-002` |
| Event participants | Confirmed | `GLOBAL-DISCOVERY-004`, `-032` |
| Event results | Confirmed | `GLOBAL-DISCOVERY-007` narrowed; `-026` for `31`–`34`, `36`, `100` |
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

**The sport scores a round at a time, and the total is not stored at all.** `31`–`35` and
`526`–`529` are per-round fields. The editing interface shows two further columns beside them,
`Total` and `Total Par`, and only the second of the two exists in the database.

`36 Par` is `Total Par`: the score against par for the whole event, and it is measured rather
than inferred. Over every stroke-play participant holding four numeric rounds and a numeric
`36`, the value equals the sum of the rounds minus the course par times four - confirmed on
9023 participants in 2026 with no exception, and on 200572 sport-wide. The course par comes
from the `tournament_stage` property `Par`, which is why that property is not decoration.

`Total` - the raw stroke count, 258 for a 66-65-63-64 - **has no result type.** The interface
computes it from the four rounds. Any check wanting a stroke total has to sum the rounds itself,
and any check comparing "the event's score" against a rank must use `36`, which is signed and
therefore not comparable to a stroke count.

This also explains the shape counts above. `36` writes an over-par score two ways: 310110 values
carry a bare `#` and 9347 carry `+#`, and both mean the same thing. The `-#` majority of 222174
is the under-par side, which needs no sign convention to be unambiguous.

**The value shapes are measured.** `GLOBAL-DISCOVERY-026` was run sport-wide for `36`, `31`,
`32`, `33`, `34` and `100`, one result type per execution.

`36 Par` holds 546735 values in eleven shapes. Three are the sport working correctly: `#`
(310110 values in 4559 events), `-#` with an ASCII hyphen (222174 in 4765) and `+#` (9347 in
124). The rest are not:

| Shape | Values | Events | What it is |
|---|---:|---:|---|
| `-` | 4831 | 1743 | a bare hyphen where a number belongs - "no score" written into a numeric field |
| `<EMPTY>` | 163 | 31 | empty string |
| `−#` | 39 | 2 | `U+2212`, the typographic minus |
| `â€™#` | 32 | 3 | the same `U+2212`, double-encoded through UTF-8 |
| `E` | 21 | 4 | a bare letter |
| `–#` | 14 | 1 | `U+2013`, an en dash |
| `N/A` | 3 | 1 | text |
| `#<tab> #` | 1 | 1 | a tab inside the value |

**The field writes a minus four different ways.** The ASCII hyphen accounts for 222174 of them
and the other three for 85 values across 6 events, so a cast that accepts only `-` loses those
85 silently rather than loudly.

`31`–`34 Strokes` are cleaner in proportion but hold two defects of their own:

| Result type | `-#` | `Â<nbsp>` | `D` | `<EMPTY>` |
|---|---:|---:|---:|---:|
| 31 (round 1) | 417 | - | 1 | 133 |
| 32 (round 2) | 398 | - | 3 | 274 |
| 33 (round 3) | 172 | 437 | 2 | 2648 |
| 34 (round 4) | 206 | 356 | - | 3146 |

**A negative stroke count is the larger of the two and cannot be a real score**: 1193 values
across the four rounds record a player taking fewer than nought strokes. The `Â` is
`U+00C2 U+00A0`, a non-breaking space that has been through a UTF-8 round trip twice, and it
occupies 793 values in eleven events. `31` and `32` additionally hold `# #` and `# # #`, two
numbers in one value, and `32` holds `#n`.

`100 Rank` is clean. All 526444 values in 4841 events carry the single shape `#`, with no empty,
no text and no separator. Its maximum of 9999 is a valid integer and a question about the value
rather than about its shape.

**The comment vocabulary, and why two of its values are not "no result".** `104 Comment` holds
10257 rows over nine values and an empty string: `wd` (6824 rows in 2573 events), `mdf` (1711 in
170), empty (809 in 408), `dq` (761 in 580), `mc` (74 in 1), `rtd` (51 in 25), `sub` (16 in 14),
`nr` (7 in 5), `dns` (2 in 1) and `n/r` (2 in 1).

`RESULT_COMMENT_NO_RESULT_LIST` is `wd`, `dq`, `rtd`, `dns`, `nr` and `n/r` - the six that end a
participation without a classification. `mc` and `mdf` are deliberately outside it, and this is
where golf differs from every other sport in the package. A player who missed the cut has valid
round-one and round-two scores, and `mdf` means made the cut and did not finish, so both hold
real results and simply stop earlier than the field. Treating them as "no result" would silence
1785 participations in which a missing rank is a genuine finding.

`nr` and `n/r` are one value written two ways, 7 rows and 2. Both are listed so that neither
reads as an unknown comment, which is a vocabulary defect recorded rather than repaired.

**`wd` is not a no-result marker in golf, and that is the sport speaking rather than the data
being wrong.** A player who withdraws keeps the position the field gave them, so a `wd` sitting
beside a Rank is the convention and not a contradiction. Confirmed 2026-08-12. `wd` was in
`RESULT_COMMENT_NO_RESULT_LIST` when the vocabulary was first recorded, and taking it out moved
`GLOBAL-DQ-117` from 7644 findings to 823 - from four fifths of its eligible population, which
is a proportion, to a list somebody can work through. It moved `GLOBAL-DQ-122` the other way,
47 to 87, and that is the same fact read from the other side: if a withdrawal keeps its place,
the place owes a deciding value like any other.

What remains in the list is `dq`, `rtd`, `dns`, `nr` and `n/r`. A disqualification removes a
result rather than freezing it, which is why `dq` stays in and `wd` does not.

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

**The discipline is stored twice for a small minority of events, and the two copies agree.** The
`object_discipline` relation reaches 19434 events; the `discipline` event property is written on
332. `GLOBAL-DQ-109` audits the 329 of those whose value resolves to an active discipline through
both paths and reports no disagreement, so the property is a partial duplicate of the relation
rather than a competing or stale record of it. The relation remains the path a Golf statement
should read, because it is the one that covers the sport.

The claim also holds upward and sideways. `GLOBAL-DQ-100` finds no Comp.Rank claiming a
discipline that no event under its own tournament contested, over 3444 statistics, and
`GLOBAL-DQ-110` finds none contradicting the events it names through the `1471` Event id config,
over 3194. Together with the stage measurement - no stage mixes disciplines, 5441 of 5441 - the
discipline layer is the one part of this sport that is internally consistent everywhere it was
measured.

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

**`225 Main Phase` is this sport's final round, and `9`/`173 Final` are not.** The distinction
matters because Golf is Hybrid and the two words mean different things in its two disciplines.
Main Phase is where a stroke-play field is classified as a whole: it covers 3186 of the 3440
events a Comp.Rank names through its Event id config, and it holds every one of the sport's 18
medal results, six gold, six silver and six bronze across six events. `173 Final` is a match
between two players; it is named by a Comp.Rank five times in the sport and awards no medal
anywhere. `FINAL_ROUND_TYPE_LIST` is therefore `225` alone, which is unlike every other sport
documented here, and the reason is the model rather than the data being thin.

Including `9` and `173` would not widen the audit, it would make three checks assert something
false - that a two-player match owes a full medal set. The match-play finals are not left
unaudited by the choice: they are ordinary events and every check that does not key on the final
round reads them, which is most of the catalogue.

**The duplicate key drops the event name and keeps the calendar day, and both halves were
measured rather than assumed.** Golf names its match-play events after the competitors -
`Aaron Baddeley-Tiger Woods` - which is the condition `GLOBAL-DQ-062` states for
`DUPLICATE_KEY_INCLUDES_EVENT_NAME = 0`: the name repeats the participant set in an order the
data does not fix, so it splits `A-B` from `B-A` that the participant key has already matched.
Of the 63 groups of match-play events sharing a stage, a calendar day and a participant set, 59
already carry an identical name, so dropping the name costs nothing; the remaining 4 are exactly
the groups a name key would hide.

`DUPLICATE_KEY_USES_CALENDAR_DAY` is `1`. Twenty-three of those 63 groups carry different
timestamps on the same day for the same pairing, and two golfers do not play two separate matches
in a day - that is a re-import arriving with a shifted start, which a timestamp key never groups
at all and therefore never reports.

**Round type names are not unique identifiers here, the same way they are not in BMX.** Quarter
Finals occurs as both `176` and `3`, Semi Finals as `178` and `2`, Final as `173` and `9`,
Small Final as `186` and `19`, `1/8` as `184` and `4`, Playoff as `304` and `305`, and the
numbered rounds `1`…`4` occur twice over under two different id runs. A statement must reference
`round_typeFK` by id and never by name.

**`round_typeFK = 0` is carried by 80 events and resolves to no `round_type` row**, and
`1 no round` by a further 79. The first is unmapped, the second is a named round type meaning
the absence of one; they are different states and are not interchangeable.

<!-- MANUAL PASTE ZONE: 3 EVENT AND ROUND REPRESENTATION — insert approved additions immediately before this marker; do not move or delete it. -->

## Scope

**UK Sport does not take twenty of the sport's tournament templates, and every Golf check
excludes them.** Recorded 2026-08-13, replacing the opposite conclusion this file carried until
that day — that the client took the sport whole. The ids live in `SPORTS/params.json` under
`OUT_OF_SCOPE_TEMPLATE_ID_LIST` and are written into the statements themselves rather than
applied at run time, because the statement is what PowerBI executes; `POWERBI.md` owns that
contract.

| Out of scope | Templates |
|---|---|
| Professional tours below the top flight | `9692 Challenge Tour 1`, `9418 Champions Tour 1`, `9633 Korn Ferry Tour`, `9691 Asian Tour 1`, `9693 Sunshine Tour 1`, `9201 PGA Tour of Australasia 1` |
| Breakaway tour | `10305 LIV Golf` |
| Team match-play cups | `432 Ryder Cup 1`, `438` and `435 Solheim Cup 1`, `9142 Solheim Cup`, `10341 Presidents Cup`, `9645 Walker Cup 1` |
| Amateur world team championships | `11528 Eisenhower Trophy`, `11529 Espirito Santo Trophy` |
| Short-form and test data | `9831 GolfSixes`, `10333 GolfSixes alt test`, `10334 GolfSixes test kris`, `9932 Mixed`, `12649 TEST` |

Four of them — `435`, `9142`, `10333`, `10334` — are already `del = 'yes'` and carry nothing.
They are listed anyway, so the boundary states a decision rather than the current state of a
flag.

**Deferred, not unsupported.** These competitions will be looked at; they are not being looked at
now. The data is there, the sport fills it, and every check would run against it unchanged — the
exclusion is a list of ids, so the day the boundary moves the list moves and nothing else does.
`README.md` owns why the client is a boundary of its own.

What it costs, measured on 2026-08-13:

| Layer | In scope | Out | Out |
|---|---|---|---|
| Events | 16,544 | 2,899 | 14.9% |
| Event participants | 393,722 | 191,441 | **32.7%** |
| Comp.Rank statistics | 3,440 | 51 | 1.5% |
| Comp.Rank participants | 355,654 | 3,690 | 1.0% |

The second row is the one to remember: a seventh of the events but a third of the participants,
because a tour field is 144 players and a cup is 24. A participant-level check loses a third of
its population and a Comp.Rank check loses almost nothing.

**One check the boundary does not reach.** `Golf-DQ-036` (`GLOBAL-DQ-009`) audits people the
sport registry knows and no participation path reaches. The registry has no template relation —
that is precisely what it audits — so there is nothing to exclude, and its 742 findings over
20,638 registered people stay sport-wide. A person who competed only under an excluded template
is not among them: they have participation, and this check reports having none.

## Confirmed sport-specific storage semantics

**`-TemplateIds` is not the scope mechanism for this sport.** It is how Soccer keeps its
statements affordable; Golf's boundary is in the statements and its remaining 21 live templates
are read whole, so narrowing further here would not be a scope decision but a hole in the audit.
What is left for cost is the rest of
`WORKFLOW.md`'s cost rule, and it has to do all the work on the largest sport in the package:
a half-open `startdate` window, a primary-key range, one round type or one result type per
execution, `EXISTS` in place of `JOIN` plus `DISTINCT`, and no `COUNT(DISTINCT)` where a plain
`COUNT(*)` answers the question.

This is measured rather than cautionary. Two of the 24 catalogue statements that ran against
Golf failed on cost alone - `GLOBAL-DISCOVERY-007` exhausted the server's temporary space and
`GLOBAL-DISCOVERY-010` timed out twice - and both are ordinary statements that every other sport
runs without trouble. A Golf DQ statement written to the shape that works on Curling should be
expected to fail here until it is sized.

**A medal event is identified by its template, not by its round type, and no parameter can say
so.** Every one of the sport's 18 medal results sits in round type `225 Main Phase`, which is
also the round every stroke-play tournament on every professional tour uses. Only
`9600`/`9601 Summer Olympics` awards a medal, in 6 events; the other 5014 events carrying that
round type award none.

`MEDAL_ROUND_TYPE_LIST = 225` is therefore correct in one direction and false in the other. Read
as "a medal may only appear on these rounds" it holds, and `GLOBAL-DQ-039` and `GLOBAL-DQ-073`
both return clean on it. Read as "these rounds award medals" it fails, and `GLOBAL-DQ-037` and
`GLOBAL-DQ-038` report 4751 and 4764 of 4768 - the whole population. Both are `Not applicable`
here for that reason, and the asymmetry is the sport's, not the templates'.

This is a consequence of the client scope reaching well past the Games. The twenty templates it
excludes are cups and secondary tours, not the stroke-play tours that hold `225 Main Phase`, so
the asymmetry survives the boundary unchanged: a sport narrowed to its Games templates alone
would have a medal round that means what the parameter assumes, and this one still does not.

**The template can say it, and on 2026-08-13 it was written down.** The sentence above holds
about round types and was too broad about parameters: what no *round-type* list can express, a
template list can. Thirteen templates award medals in this sport and were confirmed by decision,
not measured - `9600` and `9601 Summer Olympics`, `11498 Summer Youth Olympics`,
`9779 European Championships 1`, `10327 Pan American Games`, `10328 Asian Games`,
`10537`/`10538 Pacific Games`, `11532 Southeast Asian Games`, `11507 British Boys Amateur
Championship`, `11524 British Girls Amateur Championship`, `11525 European Girls' Team
Championship`, `11526 European Boys' Team Championship`. Every other template awards none.

`MEDAL_TEMPLATE_ID_LIST` records them and `GLOBAL-DQ-125` asserts the negative half of the rule:
a Comp.Rank outside those templates holds no medal. It reports 43 statistics over 3240, holding
130 medals between them, from three templates:

| Template | Comp.Rank holding medals |
|---|---:|
| `430 European Tour and PGA Tour 1` | 21 |
| `11528 Eisenhower Trophy` | 11 |
| `11529 Espirito Santo Trophy` | 11 |

`430` is a professional tour and the finding is the plain one. The two trophies are the World
Amateur Team Championships and sit beside four amateur championships that *are* on the list, so
whether they were meant to be excluded is a question for the reviewer rather than a defect this
file should assert either way. One further oddity is visible in the same rows and is not what
the check was looking for: statistics named `Espirito Santo Trophy - Competition Rank` are filed
under template `11528 Eisenhower Trophy`.

Five of the thirteen hold no medal at all today - `11525`, `11526`, `9779`, `10537`, `10538`.
The rule as recorded is one-directional, so that is not a finding for `GLOBAL-DQ-125`. It is a
finding for the check on the other side of the list, which is where it now lands.

**`Golf-DQ-085` is `GLOBAL-DQ-026` narrowed to those thirteen templates, and `Golf-DQ-044` is
deprecated.** The global template audits every Comp.Rank a sport holds, and Golf's are tournament
classifications: it reported 3286 of 3491, almost all of them `No_Medals_At_All` on competitions
that award none. Narrowing it inside the template would have taken the check from the six other
sports that run it and declare no medal-template list, so the narrowing lives in
`POWERBI_QUERIES/Golf.sql` and carries Golf's values written out. The two must be kept the same:
`GLOBAL-DQ-125` asserts no medal outside the thirteen, `Golf-DQ-085` audits the medal set inside
them, and they are only coherent while they read the same list.

It reports 192 of 251, and the composition is what makes it readable where 3286 of 3491 was not:

| What it found | Rows |
|---|---:|
| `Medal_Set_Unreadable_Without_Rank` - no Rank to compare the medals with | 101 |
| `No_Medals_At_All` - a medal template awarding none | 87 |
| `Medal_Missing_For_Shared_Place` | 2 |
| `Duplicate_Bronze` | 1 |
| `Podium_Truncated_Below_Medal` | 1 |

The 87 are the reverse direction of the rule, arriving without a check being written for it: 83
sit under `11526 European Boys' Team Championship` and `11525 European Girls' Team Championship`
counted together with the two British championships, which is the same five-template gap named
above seen from the other side. The 101 belong to `Golf-DQ-001` and are not restated here. Four
rows are medal-set defects in the sense the check was written for.

**Test data is inside the scope, not beside it.** Because no template is excluded,
`12649 TEST` and its 899 event participants are part of every sport-wide count a Golf check will
return, as is the `TEST - ISCO Championship` event. Any Golf finding list will contain them, and
they are not a defect the check found - they are the population it was pointed at.

**`12649 TEST` is a template named TEST, and it is populated.** Seven tournaments, seven stages,
seven events and 899 event participants. The event inventory also returns
`TEST - ISCO Championship` as the sole `inprogress` event in the sport. This is test data in the
production population, and any sport-wide count in this file includes it.

**`10341 Presidents Cup` has nine tournaments and no stages, events or participants.** It is an
empty branch of the hierarchy rather than a missing template, which is the state
`GLOBAL-DQ-001` exists to report.

**A stroke-play tournament is one event dated on its opening day, and the stage carries the days
it was actually played.** The four rounds are not four events: `810110 Omega Hong Kong Open` runs
`2001-11-29` to `2001-12-02` on the stage and holds a single event dated `2001-11-29`. So the
stage end date is later than the last event start date by the length of the tournament, and it is
supposed to be.

`GLOBAL-DQ-004` reports 5089 of 5450 stages on that account. 4969 of them are exactly this shape -
stage start equal to the earliest event, stage end one to four days later - and 4975 hold their
events on one single date. The template's invariant, that a stage is bounded by its own events,
is false for a sport whose event is a container for several days of play. The residue is 120
stages: 89 whose start disagrees while the end matches, 24 running five days or more past their
last event, and 7 disagreeing at both ends.

**Match play names an event after its two competitors and joins them with a hyphen carrying no
spaces**, as in `A-Lim Kim-Andrea Lee`. The separator between the two players and the hyphen
inside one player's own name are the same character, which is why the name cannot be split back
into its parts and why `DUPLICATE_KEY_INCLUDES_EVENT_NAME` is `0` for this sport.

It also means the sport's own naming convention breaks a text-hygiene rule on every match-play
event. `GLOBAL-DQ-049` reports 13430 of 14720 distinct event names, and 13340 of those break
`HYPHEN_WITHOUT_SPACES` and nothing else. Ninety names break something a reviewer would want:
10 hold a corrupted character, 3 are all uppercase, 3 start lowercase, 2 double a capital and one
doubles a space, with a further 71 corrupted names that also carry the separator.

**Stroke play names an event after the tournament and names no competitor at all.** `5035212
Boeing Classic` carries 78 players and none of them in its name. This is the Hybrid model showing
up in the naming layer the way it already shows up in the result layer: `GLOBAL-DQ-096` asserts
that an event names the competitors that play it, which is true of the sport's match-play half
and false of its stroke-play half, and it reports 4875 events for naming no participant.

The 602 rows it reports for naming only some of them are the finding the check exists for -
`4315561 Benjamin James-Mark Power` is a match against a participant recorded as `Ben James`, so
the event name and the participant register disagree about the same person's name.

**A tour season is named for one year and played across two.** Tournament `2663`, named `2002`
under `European Tour 1`, holds 37 stages that begin in 2001 and end in 2002, and the same holds
for every European Tour season in the file. `GLOBAL-DQ-080` reports 45 tournaments and 42 of them
are this: a single-year name over a season the stages carry into a second year. The template
recognises the written span form `2025/26`; the sport does not use it, so a straddling season is
indistinguishable from a misnamed one by name alone.

**A woman entering a men's field is golf, and it is not distinguishable from a mis-stored gender
by structure.** `Michelle Wie West`, `Carlota Ciganda`, `Charley Hull`, `Georgia Hall` and
`Catriona Matthew` are all recorded `female` and all entered in stages recorded `male`, which is
what happened. It surfaces in two places: `GLOBAL-DQ-123` reports 31 athletes that way, and
`GLOBAL-DQ-044` reports 17 male Comp.Rank each holding exactly one female among 119 to 191 men -
`Legends Reno-Tahoe Open`, `John Deere Classic`, `B.C. Open`, `84 Lumber Classic`.

The same finding lists hold rows that read as genuine defects, and they are told apart by what
carries the gender rather than by the count. A national team entity - `England`, `France`,
`Spain`, `Scotland` - is stored once with one gender and entered under both, which puts 26 team
rows in `GLOBAL-DQ-123`; and the European Boys' and Girls' Team Championships hold 3 to 10
wrong-gender team members each in `GLOBAL-DQ-044`. Neither check can make the distinction itself.

**A round named Final is not a knockout round in this sport, and `173 Final` carrying
`knockout = no` is correct.** Recorded by decision on 2026-08-13, against the shape of the data
rather than from it, and the measurement is here so the decision is legible.

Golf files 529 events on `173 Final`, all of them Match Play, and 28 on `9 Final`, also all
Match Play. Two round types, one name, opposite flags, and the sport uses both. Read from the
data alone the larger population would have looked like the defect; the reading is the other way
round, so `'final'` moved from `ELIMINATION_ROUND_NAME_LIST` to `GROUP_ROUND_NAME_LIST` and the
expectation for the name is now `no`.

The consequence is deliberate and is the point of stating it: `GLOBAL-DQ-118` stops reporting the
529 events on `173` and starts reporting the 28 on `9`, which is a repair list a person can
finish. `GLOBAL-DQ-097` follows it, as the two are written to always agree on which round types
are wrong.

Nothing else in the pair moved. `176 Quarter Finals`, `178 Semi Finals`, `188 1/32`, `185 1/16`,
`184 1/8`, `186 Small Final` and `304 Playoff` all carry `knockout = no` and all remain findings,
6126 events between them: those names are elimination rounds in this sport as in any other, and
the sport's own knockout-flagged twins - `3`, `2`, `4`, `19`, `305` - are what they should sit on.

**The scope container is stored by fourteen templates and not by twenty-two, and the client
reads neither.** `Golf-DQ-058`, running `GLOBAL-DQ-107`, was deprecated on 2026-08-13 by
decision, not by measurement, and the measurement is recorded here so the decision can be
reversed knowing what it gave up.

Of the 36 templates holding finished events, 14 carry an `event_scope` container of type `305`
on at least some of them - `430 European Tour and PGA Tour 1` on 811 of 1829, `436 LPGA Tour 1`
on 663 of 1710, `9645 Walker Cup 1` on 130 of 135, `10305 LIV Golf` on 111 of 172. Twenty-two
carry none at all, including every amateur team championship and **every Games template**:
`9600`/`9601 Summer Olympics` 0 of 3, `11498 Summer Youth Olympics` 0 of 4, `10328 Asian Games`
0 of 10, `10327 Pan American Games` 0 of 6, `11532 Southeast Asian Games` 0 of 6.

Measured sport-wide, on 2026-08-13, before the client boundary was recorded. Two of the four
best-covered templates named above — `9645 Walker Cup 1` and `10305 LIV Golf` — are outside it,
so a re-measurement inside the boundary would find the container rarer still. Anyone reversing
the deprecation should re-measure rather than read these numbers as the population the check
would now see.

So the structure exists and is used, and the check is not `Not applicable` under this project's
rule - it would have reported 16334 of 19053 finished events forever, and a scope container
arriving tomorrow is exactly what it was written to notice. It is deprecated instead, which
keeps the CheckID reserved and the row in the registry, because the client does not read scope
results and a permanent 86 per cent finding is noise on a board somebody has to work through.
The hole-by-hole scope layer is outside the DQ work by the decision of 2026-08-12, and this is
the same decision reaching the one check that could see it.

**Two `statistic_data11` fields are declared for the shard and never written.** `1427` Time
difference and `1429` Team both resolve for statistic type 11 and Golf stores no row in either, so
`GLOBAL-DQ-028`, `GLOBAL-DQ-064`, `GLOBAL-DQ-065` and `GLOBAL-DQ-066` all audit an empty
population. That is a sentinel rather than a misdirected scope: the field exists, the sport has
not used it, and the day it does the check is already pointed at it.

<!-- MANUAL PASTE ZONE: 3 STORAGE SEMANTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Open questions

1. **How is a pair participant meant to be read?** A foursome is one `athlete` row holding two
   names and no lineup. Whether the two players are reachable at all, and through what, is
   unknown; if they are not, the sport cannot answer "who played" for its pairs formats.
2. **What are the five `tournament_stage`-owned statistics?** Shard, fields and purpose are all
   unchecked, and they are the one statistic population this sweep did not touch.
3. **Are `penalty_stroke_9` and the four `clock_penalty_*` data types genuinely Golf's?** They
   carry values under Golf scopes but read as another sport's vocabulary. A shared generic id
   and a misfiled value look identical from here.
4. **What do `event_scope_detail` and `lineup_scope_result` hold for Golf?** Neither layer was
   measured. The second is expected to be empty because the sport writes no lineups, which is
   an expectation and not a measurement.
5. **Which round is "the" score?** The sport stores strokes per round and no single stroke
   total, so any check comparing a score against a rank has to say which figure it means.
6. **Nothing checks whether a match-play result is coherent.** The sport contests 14292 Match
   Play events and no check reads their outcome. `GLOBAL-DQ-094` is the template for it and
   cannot instantiate here: it reads the place off a pair of numeric scores, and Golf stores
   `won` and `0` in `4 finalresult` with a score line in `39 mpscore`. So no check today asks
   whether both sides of a match are marked `won`, whether neither is, or whether `39`
   contradicts `4`. Raised when `FINAL_ROUND_TYPE_LIST` was settled at `225` on 2026-08-12 - the
   gap is not caused by that choice and is not closed by reversing it, because the two medal
   templates that read match rounds are inapplicable to this sport for their own reasons.
7. **Is `-` in `36 Par` the sport's way of writing "no score", or a defect?** It is the fourth
   most common shape in the field at 4831 values over 1743 events, which is too many to be
   accidental and too few to be the convention. The answer decides whether a Par check treats it
   as a missing value or as a legitimate one.
**The hole-by-hole scope layer is not audited for now.** Decided 2026-08-12. Its 29653897 values
are counted sport-wide; most of them sit inside the client's boundary, and they are deliberately
left outside the DQ work rather than overlooked. This is a decision about where the effort goes and not a
statement about the data: the layer is the sport's largest storage and the two catalogue
failures both came from it, so a check written against it later has to be sized before it is
written. Nothing here classifies it `Not applicable` - the structure is present and the sport
fills it.

Settled since this file was opened, then reversed: the client scope was recorded as the whole
sport until 2026-08-13, when UK Sport named twenty templates it does not take. **Scope** above
owns the list and what it costs. The reversal is left visible rather than tidied away, because
several conclusions in this file were reached while the wider boundary was believed, and a
reader meeting one of them deserves to know which assumption it was written under.

<!-- MANUAL PASTE ZONE: 3 OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
