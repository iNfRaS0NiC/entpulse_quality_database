# SPORT: Ice-Hockey (sport_id=5)

This file is the canonical structural record for Ice-Hockey. It contains only confirmed
sport-specific usage, meanings, identifiers, evidence boundaries and open structural
questions. Global database mechanisms belong in `../DATABASE.md`.

For additions, insert approved content immediately before the exact active
`MANUAL PASTE ZONE` marker in the destination subsection. Keep the marker unchanged
and at the end of its subsection. Replace existing rows or paragraphs in place when a
correction is required.

## Identity and evidence

- First discovery date: 2026-08-14
- Latest evidence date: 2026-08-15
- Verification boundary: the client's 25 tournament templates, 9803 active events. The sport
  holds 112 active templates and 316395 events server-wide, so **everything below describes
  3.1 per cent of the sport** unless the paragraph says otherwise. Registry, statistic and
  participant figures are sport-wide, because those layers carry no template relation and the
  narrowing cannot reach them; every count read through an event is inside the boundary.

`sport.name` is `Ice Hockey` and the provider code is `ih`. `SPORTS.md` maps that to the
repository slug `Ice-Hockey`.

**The client boundary is declared as what it contains, not as what it excludes.** 25 templates
of 112, and `SPORTS/params.json` names those 25 under `IN_SCOPE_TEMPLATE_ID_LIST`; the runner
computes the 87 it does not take, at every run, against the templates the sport has then. The
reason is the default rather than the length: the sport gained templates in 2016, 2018, 2020,
2022, 2025 and 2026, and under an exclusion list each new one would arrive inside the client's
boundary without anybody deciding it. One league the size of the KHL is 17669 events against
the 9803 the client asked for. `TOOLS/README.md` owns the mechanism.

The 25 are the national-team competitions: Winter Olympics and its qualification for both
genders, World Championship divisions 1 and 2 for both genders, the U-20 and U18 World
Championships, World Cup of Hockey, Euro Hockey Tour, the Asian Winter Games, the Challenge
Cup of Asia, the Winter Youth Olympic Games, the European Youth Olympic Festival, the
Southeast Asian Games and the 4 Nations Cup. **No club league is in scope, including
`9694 Great Britain 1`.**

**Great Britain plays 112 matches in five templates the boundary does not take, and whether it
should is the client's call rather than ours.** Measured 2026-08-15; four separate participant
records carry the name:

| Team | id | Template outside the boundary | GB matches | Template total | Years |
|---|---:|---|---:|---:|---|
| `Great Britain U20` | 47031 | `309 B-World Championship U-20 1` male | 40 | 570 | 2006–2016 |
| `Great Britain` | 1696372 | `10850 World Championship 3` female | 39 | 395 | 2011–2022 |
| `Great Britain` | 341 | `320 Friendlies 1` male | 25 | 683 | 2016–2026 |
| `Great Britain U18` | 1885307 | `11496 World Championship U18 2` female | 5 | 30 | 2026 |
| `Great Britain` | 341 | `314 Euro Ice Hockey Challenge 1` male | 3 | 527 | 2008 only |

There is a pattern in what the boundary took: divisions 1 and 2 of the men's senior World
Championship, but only division 1 of the U-20 and of the U18, and divisions 1 and 2 of the
women's while Great Britain competed in division 3. A template is taken whole, so the five
together are 2205 events against the 9803 the boundary holds now - a 22 per cent increase for
112 matches of the client's own. `11496` is also the case the inclusion form was chosen for: a
template that first appears in 2026, holding a Great Britain team, which under an exclusion
list would have arrived inside the boundary with nobody deciding it.

**Answered 2026-08-15: the client does not want those levels counted.** The boundary stays at
25 templates and the five are out by decision rather than by oversight. The measurement is kept
because it is the obvious thing for the next reader to notice and re-measure, and because the
answer would have to be revisited if the client's scope ever widened. Nothing here was a defect
at any point; it was a question about what UK Sport wants counted, and it has been put and
answered.

## Structural coverage

| Area | Status | Evidence |
|---|---|---|
| Core hierarchy | Confirmed | `GLOBAL-DISCOVERY-002` narrowed, 25 templates |
| Event participants | Confirmed | `GLOBAL-DISCOVERY-004`, `-032` narrowed |
| Event results | Confirmed | `GLOBAL-DISCOVERY-007` narrowed, 12 types |
| Incidents | Confirmed | `GLOBAL-DISCOVERY-008` narrowed, 16 types |
| Lineups | Confirmed | `GLOBAL-DISCOVERY-005` narrowed, 5 lineup types |
| Scope layer | Confirmed | `GLOBAL-DISCOVERY-009`, `-010` narrowed, 7 scope types |
| Properties | Confirmed | `GLOBAL-DISCOVERY-011` narrowed, 33 rows |
| object_relation | Confirmed | `GLOBAL-DISCOVERY-012` narrowed, 7 pairs |
| object_discipline | Confirmed | `GLOBAL-DISCOVERY-013` narrowed, one discipline |
| Statistics | Confirmed | `GLOBAL-DISCOVERY-015`, `-016`, `-017`, `-030`, `-031` sport-wide |
| Reference values | Confirmed | `GLOBAL-DISCOVERY-018` narrowed, 26 round types |
| Venues and cities | Confirmed | measured 2026-08-15, `venue_object` on 232 events, `city_object` on none |
| Status vocabulary map | Confirmed | measured 2026-08-15, `map_sport_status_desc` maps 89 descriptions to the sport |
| Translations | Confirmed present, unread | measured 2026-08-15, `language` holds 147586 rows over 46 language types |
| Other tables | Confirmed absent or out of scope | `object_round` never attaches to an event outside `FIFA`; nothing else in `DATABASE.md` is populated for this sport |

## Tables and relation paths used

The sport is **H2H (team)** by `DATABASE.md` `DB-SEM-015`: every event carries exactly two
`event_participants` rows and the participant is a `team`, with one measured exception recorded
under Participants below.

`event → tournament_stage → tournament → tournament_template` is the whole hierarchy, and all
four layers are populated. `GLOBAL-DISCOVERY-002` returns 25 template rows for the boundary,
one per template, with no template holding zero tournaments.

Comp.Rank hangs off the **tournament** (`statistic.object_typeFK = 3`), 904 statistics
sport-wide, participants in `statistic_participants11` and data in `statistic_data11`.

<!-- MANUAL PASTE ZONE: 5 TABLES AND RELATIONS — insert approved additions immediately before this marker; do not move or delete it. -->

## Participant and lineup structure

`event_participants` holds **teams only**: 135 male teams over 15226 participations and 96
female teams over 4380, inside the boundary.

**One athlete is entered as an event participant, and it is the only one.** Aleksandr Ossipov,
participant `1356520`, one participation, one event, male, 2015. `GLOBAL-DISCOVERY-032` places
it in a single event of a single template. In a sport that enters teams everywhere else this is
a structural contradiction rather than a variant, and it is one row.

The people are in the **lineup**, and the layer is fully populated — unlike Golf, where the
lineup table holds nothing at all. Five lineup types are in use inside the boundary:

| lineup_typeFK | Name | Member type | Rows | Distinct members |
|---:|---|---|---:|---:|
| 14 | Starter | athlete | 42620 male, 12194 female | 3517, 751 |
| 6 | Unknown | athlete | 8037 male | 1072 |
| 5 | Substitute player | athlete | 3520 male, 1020 female | 1018, 231 |
| 10 | Coach | coach | 502 male, 46 female | 57, 4 |
| 1 | Goalkeeper | athlete | 1 female | 1 |

Two shapes in that table are worth naming before any check reads it. **`6 Unknown` is a real
lineup type carrying 8037 rows**, so a check treating an unknown type as absent would silence a
sixth of the male lineup. And **`1 Goalkeeper` holds exactly one row** — every other goalkeeper
in the sport is filed as a Starter — so the type is declared and effectively unused rather than
a category the sport maintains. `17` rows file a `coach` under `14 Starter`, which contradicts
both the type and the member's own participant type.

The sport registry (`object_participants`) is sport-wide and much larger than the boundary:
35956 active male athletes and 3406 female, 1352 male teams and 215 female, 282 male coaches
and 5 female, 113 male officials and 32 female.

**15201 registered athletes are entered nowhere in the database at all**, and this is a question
rather than a work list. Measured 2026-08-14: not one of them appears as an event participant in
ice hockey or in any other sport, none is in a lineup, none is in a Comp.Rank, and 15187 of them
carry both a date of birth and a country. Complete profiles that were never attached to a match
are not an empty field somebody can fill from the row, and merging will not clear them either -
only 552 sit in a duplicate-name group. `GLOBAL-DQ-009` reports them and is not instantiated;
`Ice-Hockey-DQ-088` audits the rest of the registry.

**The sport has a fourth path from an event to a person, and it changes who counts as unused.**
`refereeFK` is a `ref:participant` property on 270 events. `GLOBAL-DQ-009` asserts three paths -
event, lineup, Comp.Rank - so it reported 224 officials as attached to nothing, of whom **160
referee an event**. Any check asking whether a person is used in this sport has to read the
property as well, which is why `Ice-Hockey-DQ-088` does and reports 64 officials rather than 224.

**Its 329 rows were reviewed on 2026-08-15 and judged normal, and the check is now `Monitor`.**
A sport registry legitimately holds entries that were never used, and 136 teams, 129 coaches and
64 officials that no event, lineup, Comp.Rank or `refereeFK` property reaches are not 329 rows
anybody works through. What the number describes is how much of the registry has never been
entered anywhere; a rise in it is the question, not the rows.

**The registry role and the participant type disagree on 150 rows**, which is a defect shape
rather than a vocabulary: 66 rows register a `coach` under the role `athlete`, 4 more under
role `athlete` with `del` set, 1 registers an `athlete` under the role `coach`, 1 registers an
`official` under the role `athlete`, and 84 rows carry an empty role for an `official`.

<!-- MANUAL PASTE ZONE: 5 PARTICIPANTS AND LINEUPS — insert approved additions immediately before this marker; do not move or delete it. -->

## Event result types

Twelve active result types inside the boundary, from `GLOBAL-DISCOVERY-007` narrowed.
`result_row_count` is what was returned; the event count beside it is what the type reaches.

| result_code | result_typeFK | Value shape | Confirmed meaning | Evidence |
|---|---:|---|---|---|
| ordinarytime | 1 | integer | Goals in regulation | 19606 rows, 9803 events |
| period1 | 51 | integer | Goals in the first period | 19606 rows, 9803 events |
| finalresult | 4 | integer | The score the result is decided on | 19202 rows, 9601 events |
| runningscore | 6 | integer | Mirror of the score | 19582 rows, 9791 events |
| period2 | 52 | integer | Goals in the second period | 17024 rows, 8512 events |
| period3 | 53 | integer | Goals in the third period | 17002 rows, 8501 events |
| extratime | 2 | integer | Goals in overtime | 1818 rows, 909 events |
| penaltyshootout | 3 | integer | Shootout goals | 802 rows, 401 events |
| medal | 501 | `bronze` / silver / gold | Medal awarded | 30 rows, 20 events |
| overallscore | 550 | integer | Aggregate over a series | 8 rows, 4 events |
| finaloutcome | 549 | `lost` / won | Outcome word | 6 rows, 3 events |
| rank | 100 | integer | See the note under `Ice-Hockey-DQ-023` | 117 rows, 2026-08-28 |

**`1 Ordinary time` and `51 Period 1` reach every event in the boundary and `4 Final Result`
does not.** 9803 against 9601, and measuring the 202 on 2026-08-14 settled what they are:
**182 cancelled events and 20 not started**, every one of them holding a running score and a
period score and none of them a final result. No finished event is among them - all 9596 hold
the score, on both sides, under all four finished descriptions. `6 Running score` sits between
the two totals at 9791.

So the sport writes a scoreline for a match it never resolved, and the deciding result is the
one field it withholds. That is the shape a results check here is scoped around: `finished` is
the population, and the 202 belong to `GLOBAL-DQ-047`, which reports the 20 not-started ones.

**What an unplayed event may hold is a rule and it is already enforced.** Decided 2026-08-15: a
result on a `Not started` event is a defect and a result on a `Cancelled` or postponed one is
not, because a cancelled match may well have been played before the tournament was abandoned.
Measured the same day, the two populations look nothing alike. The 20 not-started events each
hold `1 Ordinary time`, `51 Period 1` and `6 Running score`, and **every value is `0`** - a
fixture carrying an empty scoreline. The 187 cancelled ones hold the same three with real values
from `0` to `11`, plus periods on ten, `2 Extra time` on one, and `4 Final Result` on five.
Those five are all from 27 and 29 December 2021, games of the `World Championship U-20` edition
that was abandoned: `Czechia U20-Canada U20` 3-6, `USA U20-Slovakia U20` 3-2,
`Austria U20-Finland U20` 1-7, `Russia U20-Switzerland U20` 4-2 and
`Finland U20-Czechia U20` 1-0. They are matches that were played and then annulled, which is the
world rather than the database. `Ice-Hockey-DQ-019` reports 30 of 30 and touches none of the
cancelled ones, so the rule needs no new check.

The three `190 Finished after awarded win` events carry a result on both sides and the values are
what a forfeit looks like: `Italy-Belgium` 1933 at 1-0, and `Poland-Sweden` and
`Finland-Czechoslovakia` in 1974 both at 5-0.

**`100 Rank` holds a single row in the whole boundary.** This is a head-to-head sport where the
result is a score, not a placing, so a rank on one event participant is a stray rather than a
thin layer — and it is the same event as the stray `athlete` participation above.

`549 Final Outcome` and `550 Overall Score` are each on a handful of events and have not been
read further. Both are named here so that neither reads as an unknown type later.

**The score adds up along two links, and until 2026-08-15 neither was asserted.** The three
periods make `1 Ordinary time`, and ordinary time with `2 Extra time` and `3 Penalty shootout`
makes `4 Final Result`. `Ice-Hockey-DQ-059` jumps the middle - it sums the periods straight into
the final - so an event whose two errors cancel passes it. `Ice-Hockey-DQ-104` asserts both
links and names which one broke, over 8492 events, and reports 5. All five are at the 2026
Winter Olympics, and both links fail together on every one of them; no event in the sport fails
one alone. That is the same import `Ice-Hockey-DQ-059` and `Ice-Hockey-DQ-101` already see from
two other directions. Until this check existed **`1 Ordinary time` was read by nothing**, on all
9803 events.

**How a game was decided and how it says it was decided can disagree, and seven do.** The
pairing is the sport's own: `13 Finished AP` means the shootout settled it and carries both an
overtime and a shootout score, because a shootout is only reached through overtime;
`59 Finished OT` carries the overtime score and no shootout; `6 Finished` carries neither.
`Ice-Hockey-DQ-105` asserts it over 9593 events and reports one `Finished` holding both scores
and six `Finished OT` holding a shootout - which is to say six games that were decided on
penalties and are filed as decided in overtime. `190 Finished after awarded win` is left out in
both directions, since an awarded win is not a way of playing the game out. This is the sport
variant of `GLOBAL-DQ-089`, which reads an extra-period scope column this sport does not have.

**The timed goals and the scoreline agree on all but eleven events.** `Ice-Hockey-DQ-106`
counts the goal incidents written against each side and compares them with that side's
`4 Final Result`, over the 2215 events that carry any goal incident at all - asserting it
everywhere would report the reach of the incident layer instead. Five incident types are goals
and the type id is the only safe discriminator, because `11 Penalty shootout missed` carries the
`goal` code as well: the check counts `7`, `8`, `12`, `21` and `22`.

**A cancelled match still records how far it got, and that is not a defect.** Measured
2026-08-20 sport-wide, all **3938** cancelled events carry `1 Ordinary time`, `6 Running score`
and `51 Period 1`; only 212 also carry Period 2 and 211 Period 3. That is the shape of a game
abandoned part way through, written down faithfully. A check reading it as "an event that did
not happen holds a result" would report all 3938 and be wrong about every one, which is why
`GLOBAL-DQ-090` now asks its question only of finished events.

**What is a defect is `4 Final Result` on such an event**, because a final result is what a
finished contest produces. Sport-wide that is 160 events; inside the client's boundary and
after the 2004 cutoff it is **four**, and they are one story: Czechia U20 - Canada U20,
USA U20 - Slovakia U20, Austria U20 - Finland U20 and Russia U20 - Switzerland U20, all played
on 27 December 2021 in the U-20 World Championship that was abandoned to COVID.
`Ice-Hockey-DQ-113` reports them, on `GLOBAL-DQ-126` written for exactly this.

The two shapes are easy to confuse and the difference is the whole point: `Ordinary time` on a
cancelled match says the match started, `Final Result` says it ended.

<!-- MANUAL PASTE ZONE: 5 EVENT RESULTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Incident types

Sixteen active incident types inside the boundary, and the layer is genuinely used — 41254
incident rows over the 9803 events. `GLOBAL-DISCOVERY-008` narrowed.

| incident_typeFK | Name | Code | Rows | Events |
|---:|---|---|---:|---:|
| 23 | 2 min suspension | `card` | 10246 | 1286 |
| 34 | Assist | `assist` | 10083 | 1877 |
| 7 | Regular goal | `goal` | 9060 | 2180 |
| 35 | Assist 2nd | `assist` | 7045 | 1733 |
| 21 | Power Play goal | `goal` | 3293 | 1654 |
| 22 | Short Handed goal | `goal` | 311 | 285 |
| 32 | Substitution in | `subst_in` | 262 | 237 |
| 20 | Substitution out | `subst` | 259 | 234 |
| 25 | 10 min suspension | `card` | 227 | 192 |
| 24 | 5 min suspension | `card` | 165 | 142 |
| 12 | Penalty shootout scored | `goal` | 137 | 123 |
| 8 | Penalty | `goal` | 77 | 77 |
| 11 | Penalty shootout missed | `goal` | 69 | 8 |
| 47 | 20 min suspension | `card` | 11 | 11 |
| 52 | 2 min Bench suspension | `card` | 5 | 4 |
| 51 | 25 min suspension | `card` | 3 | 3 |

**Five distinct types share the code `goal`, and one of them is a miss.** `11 Penalty shootout
missed` carries `goal` like the other four, so the code cannot be read as "a goal was scored"
and any check counting goals by code would count misses among them. The type id is the only
reliable discriminator.

**Substitutions come in pairs and the pairs do not match.** 259 `Substitution out` against 262
`Substitution in`, over 234 and 237 events. The difference is small enough to be a handful of
events and is not yet read.

The incidents cover 2180 of 9803 events at most, so the layer is populated for roughly a fifth
of the boundary rather than for all of it. That is a coverage figure, not a defect, and a check
written against incidents has to say which population it audits.

**Only the goals in this layer are audited, and that is a scope decision rather than an
oversight.** Decided 2026-08-15: the client's subject is the result, so a layer describing what
happened during a match earns a check only where it verifies a result. `Ice-Hockey-DQ-106`
qualifies because it counts goals against the scoreline; the penalties, the substitutions and
the spectator count do not. Three candidates were measured to the point of being writable and
then declined, and the measurements are recorded here so that nobody makes them twice:

| Candidate | What it would assert | Findings | Eligible |
|---|---|---:|---:|
| Penalty minutes | `165 penalty_minutes` in the boxscore equals the sum of incident types `23`, `24`, `25`, `47`, `51`, `52` | 116 | 1546 |
| Substitutions | a `20 Substitution out` has a `32 Substitution in` | 3 | 237 |
| Duplicate property | an event property is written once | 2 | 9803 |

The penalty measurement is worth keeping for its shape rather than its size: **89 of the 116
differ by exactly `+10`**, the boxscore counting ten minutes the incidents do not account for,
against 27 scattered differences of `-12` to `+20`. That is one repeated omission rather than
116 separate ones. The duplicate property is `Spectators` on 2 events, both times the same value
twice, and no GLOBAL template covers a duplicated event property - the package guards duplicate
results, Comp.Rank data, Comp.Rank config and participants, but not this.

**`incident.elapsed` is seconds in this sport, and the data says so on its own.** `DATABASE.md`
records the format as open globally. Measured 2026-08-15 over the 8502 finished events holding
all three period results: 12713 goals under types `7`, `21`, `22` and `8` fall 3758 in the first
1200 seconds, 4509 in the second, 4221 in the third and 225 beyond 3600, which is a hockey game
seen through a clock. Read as minutes the same values would put 12585 of 12713 goals after the
sixtieth minute. The maximum is 4626, a game that went to a shootout.

<!-- MANUAL PASTE ZONE: 5 INCIDENTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Scope types and data types

Seven scope types inside the boundary, from `GLOBAL-DISCOVERY-009` narrowed:

| scope_typeFK | Name | Containers | Events |
|---:|---|---:|---:|
| 305 | `final_result` | 1196 | 1196 |
| 322 | `period1` | 898 | 898 |
| 323 | `period2` | 898 | 898 |
| 324 | `period3` | 898 | 898 |
| 310 | `overtime` | 133 | 133 |
| 595 | `series_score` | 35 | 35 |
| 351 | `aggregate_score` | 4 | 4 |

One container per event per type throughout, with no event holding two of the same scope.

**The scope layer and the result layer say the same things and disagree about how often.**
Period scores exist as result types `51`–`53` on 8501 to 9803 events and as scope types
`322`–`324` on 898. The scope layer is the newer and thinner of the two, and a check reading
periods must choose one and say which; reading both would double-count every event that has
them in both places.

**What the scope layer actually holds is a boxscore, not a scoreline.** `GLOBAL-DISCOVERY-010`
returns 129 rows over three storage layers, and the shape is unlike every listing sport in this
package:

| Layer | What owns a value | Fields | Reach |
|---|---|---:|---|
| `scope_result` | the team | 17 | `164 shots`, `167 faceoff_total_wins`, `165 penalty_minutes`, `86 penalties`, `170 goalie_saves`, `401 goalie_save_percentage`, `468 shooting_percentage`, `470 powerplay_percentage`, `471 penalty_killing_percentage`, `155 blocks`, `221 hits`, `273 missed_shots`, `469 empty_net_goals` |
| `lineup_scope_result` | one player in the lineup | 18 | the same fields per player, plus `2 points`, `152 assists`, `161 plus_minus`, `177 time_on_ice_secs`, `175 faceoffs_won` |
| `event_scope_detail` | the container | 1 | `ref_eventFK`, 4 rows under `351 aggregate_score` |

Two facts constrain any check written here. **The team-level `305 final_result` scope carries no
`162 goals` field at all** - goals appear only under the three period scopes, on 881 to 882
containers - so the score cannot be read from the final-result scope. And **the per-player layer
is the larger of the two**: `152 assists` alone holds 31952 values over 1047 containers, against
1620 rows over 810 for any team field.

The boxscore is what makes the 12 per cent reach of the scope layer bearable rather than a
defect: a match without it is a match nobody typed a boxscore for, not a match with a missing
score. It is still an absence somebody has to answer for, so `GLOBAL-DQ-107` is instantiated as
`Ice-Hockey-DQ-087` and reports 8410 of them.

**Those 8410 were reviewed on 2026-08-15 and judged normal for the sport, and the check is now
`Monitor`.** The container is written by era rather than by rule: the first year a template
stores one runs 1997, 2000, 2010, 2016, 2017, 2018, 2022 and 2023, and 14 of the client's 25
templates have never stored one at all. A narrowing was looked for and there is none. Confined
to tournaments that store the breakdown somewhere, the check leaves 530 rows over 23
tournaments - but inside those the shape is 2 or 3 matches carrying it out of 21 to 52: the
1997 World Championship misses 49 of 52, and every U18 World Championship from 2011 to 2019
misses 19 of its 21. By round it is no different, the Final at 73 of 288 and the Quarter Finals
at 114 of 415, so no round is complete either and there is no sub-population where the
breakdown is reliably expected. The proportion is the finding and a single row is not a defect;
the number falls on its own if the provider ever writes the layer backwards.

**The period is the container here, not a field inside one, and four templates read the
opposite.** Most sports store a period-by-period score as several `scope_data_type` columns
inside one scope; ice hockey gives each period its own `scope_type` - `322`, `323`, `324` - and
puts a single `162 goals` field in each. `GLOBAL-DQ-086`, `-091` and `-092` all group on the
data type and find nothing to group, and `GLOBAL-DQ-089` looks for an extra-period column that
does not exist: the extra period is `310 overtime`, its own container on 133 events, and it
carries no `162 goals` field either, so the overtime score is readable only from result type
`2 Extra time`. All four are recorded `Not applicable` in `SPORTS/params.json` on that ground.

The question `GLOBAL-DQ-091` asks survives the inversion, and **`Ice-Hockey-DQ-089`** asks it on
the sport's own axis: whether a period is stored for some sides of an event and not all, or
twice for one. Measured 2026-08-14 it returns 0 findings over 882 eligible events - both teams
carry every period they played, and none is written twice. It is kept because the invariant is
real and the layer is being filled, not because it found something.

Two of the template parameters are empty by measurement rather than unrecorded.
`SCOPE_PERIOD_SENTINEL_LIST` is empty: the period values are the plain numbers `0` to `9`, with
no symbol for a period that was not played, so `GLOBAL-DQ-086` has no vocabulary to assert and
`GLOBAL-DQ-092` has no sentinel whose position could be wrong.

**One negative value exists in the whole scope layer.** Event `4332332` holds
`167 faceoff_total_wins = -1` under `310 overtime`, and it is the only value in any scope field
of the boundary that begins with a minus. Nothing reads it yet.

<!-- MANUAL PASTE ZONE: 5 SCOPES — insert approved additions immediately before this marker; do not move or delete it. -->

## Properties

At `event`, from `GLOBAL-DISCOVERY-011` narrowed. Two reach every event in the boundary:
`Live` (9803) and `Round` (9803). `GameEnded` is on 9601 — the same 9601 that carry a Final
Result — and `GameStarted` on only 4145.

The rest are thinner and are recorded so that none of them reads as unknown later: `ElapsedTime`
(948), `Verified` (3316), `LineupConfirmed` (1110), `VenueName` (263), `VenueNeutral` (175),
`VenueToBeDecided` (8), `Spectators` (268 rows over 266 events), `BestOfNum` (106), `BestOf`
(92), `period1`/`period2`/`period3` as timestamps (78, 76, 76), `medal_related` (8) and
`StartTimeToBeDecided` (3).

`refereeFK` is a `ref:participant` property on 270 events, which is a fourth path from an event
to a person, beside `event_participants`, `lineup` and the Comp.Rank statistic.

**The venue is a relation and it reaches 232 events; the city is not stored at all.** Measured
2026-08-15 and recorded because `Ice-Hockey-DQ-080` rests on it: `venue_object` with owner type
`5` carries exactly one row per event on 232 of the 9803, naming real arenas - `BCF Arena`,
`Gangneung Hockey Centre`, `Kwandong Hockey Centre` - with no event holding two. 9803 less those
232 is the 9571 that check reports, so its population is now confirmed rather than assumed. No
tournament stage in the sport carries a venue and **no event carries a `city_object` row at
all**, so the city of a match is not stored anywhere: the `VenueName` property on 263 events is
the only other place a location appears, and nothing reads it.

**There is no `discipline` property inside the boundary, and that is correct rather than a
gap.** The discipline of an event lives in the `object_discipline` relation and nowhere else:
ice hockey carries `635 6aSide` on 312717 events server-wide, exactly as
`SPORTS/Artistic-Gymnastics.md` carries `Vault` on 1424, `Floor Exercise` on 1388 and each
apparatus on its own rows. The `discipline` event property is a legacy path that survives in 64
sports and is only substantial where a sport never adopted the relation - 319645 events in
Fencing - while every team sport holds a remnant: 7 events in ice hockey, 9 in Curling, 14 in
Handball, 5 in Volleyball. None of the ice hockey 7 is inside the client boundary. Decided
2026-08-15 that no statement here may read the property, and that the relation is the only
storage the sport asserts.

**`Spectators` holds 268 rows over 266 events**, so two events carry it twice. A property the
sport writes once per event holding two values is a duplicate rather than a range.

<!-- MANUAL PASTE ZONE: 5 PROPERTIES — insert approved additions immediately before this marker; do not move or delete it. -->

## Generic relations and disciplines

**One discipline, `635 6aSide`**, and it is on 9783 of the 9803 events in the boundary. The
remaining **20 events carry no discipline relation at all**. `object_discipline` also links 692
statistics to the same discipline.

Because the sport has exactly one discipline, `object_discipline` cannot separate populations
here the way `disciplineFK` 629 and 630 separate Golf's stroke play from its match play. It is
a completeness test rather than a filter, and the 20 events without it are the finding.

`object_relation` pairs in use, from `GLOBAL-DISCOVERY-012` narrowed:

| object_typeFK | related_object_typeFK | Rows | Sources | Targets |
|---:|---:|---:|---:|---:|
| 4 | 151 | 1346 | 1346 | 3 |
| 4 | 33 | 995 | 995 | 40 |
| 83 | 151 | 665 | 655 | 3 |
| 83 | 33 | 694 | 694 | 35 |
| 83 | 43 | 487 | 487 | 146 |
| 2 | 152 | 25 | 25 | 12 |
| 1 | 153 | 1 | 1 | 1 |

**`83 → 151` has 665 rows over 655 sources**, so ten statistics carry the relation twice where
every other pair is one to one.

<!-- MANUAL PASTE ZONE: 5 GENERIC RELATIONS AND DISCIPLINES — insert approved additions immediately before this marker; do not move or delete it. -->

## Statistics

| statistic_typeFK | Owner type | Participant shard | Data shard | Fields/config | Evidence |
|---:|---:|---:|---:|---|---|
| 11 | 3 (tournament) | `statistic_participants11` | `statistic_data11` | `1270` Rank, `1271` Points, `1273` Comment, `1277` Medal, `1429` Team; config `1463` Start date, `1464` End date, `1470` Gender, `1471` Event id | `GLOBAL-DISCOVERY-015`, `-016`, `-017` |

`statistic_typeFK = 11` is **Comp.Rank** in this project. 904 statistics sport-wide own the
type at `object_typeFK = 3`. Four further type/owner pairs exist and are not used by this
project: type 1, 4 and 6 at owner 3 (15, 15 and 10 statistics) and type 11 at owner 4
(`tournament_stage`, 1 statistic).

Data fields measured sport-wide: `1270 Rank` on 44110 values over 810 statistics, `1429 Team`
on 51941 over 371, `1277 Medal` on 10395 over 443, `1271 Points` on 8 over 2, `1273 Comment` on
2 over 1.

**`1429 Team` names the side the ranked person plays for, and it is the field that separates
two different kinds of Comp.Rank.** Measured 2026-08-15 inside the boundary: all 43708 values
resolve to an active participant, every one of them of type `team`, and not one repeats the
participant on its own row — the first pair read is `A.J. Francisco [athlete]` naming
`USA U18 [team]`. So this is an affiliation and never a duplicate.

That answers what the layer holds, and it turns out to hold two things:

| What the statistic ranks | Statistics | Ranked rows | Naming a team | Holding a Rank | Holding a Medal |
|---|---:|---:|---:|---:|---:|
| teams | 445 | 3345 | 0 | 3331 | 855 |
| athletes | 229 | 31338 | 31338 | 22186 | 6744 |
| a coach and athletes | 72 | 12373 | 12370 | 9814 | 2787 |

The 445 are standings — the participant is the team, so no affiliation is written and none
should be. The other 301 are player leaderboards, named `Competition Stats (athletes)` and
`Competition Stats Group A (athletes)`, where every row is a person and the Team field says
which side they played for. `GLOBAL-DQ-098` asserts exactly this and reports 0 of 142 as
`Ice-Hockey-DQ-076`, which is the correct outcome now that the two shapes are known apart.

**So most of the sport's medals are on players, not on teams.** 9531 of the 10386 `1277 Medal`
values sit on athlete rows and 855 on team rows. That does not change the reading recorded
under the storage semantics below — the event medal layer is still nearly unwritten and that is
still a gap — but it does change what the statistic medal is evidence of: it says a named player
won something, not that a country did.

**72 statistics rank a coach alongside the athletes**, and 12370 of their 12373 rows name a
team. `Ice-Hockey-DQ-052` already reports exactly those 72 as a mixed participant type, so the
shape is on the board; what is not established is whether a coach should carry a Rank in a
scoring leaderboard at all, and no statement asserts that.

**The two shapes are a pair, and a tournament is supposed to carry both.** Decided 2026-08-15:
a tournament holds one Comp.Rank ranking its teams and one ranking its players, and on the
player one the `1429 Team` field is filled and names a team. That is the rule, and the two
halves are asserted separately because their audited objects differ.

`Ice-Hockey-DQ-102` asks it of the tournament and reports 119 of 275 - 75 that hold the team
ranking and no player ranking, and 44 that hold neither. Only a tournament that staged at least
one match is eligible: **55 tournaments in the boundary hold no event at all** - 36 with a team
ranking and 19 with none - and a tournament that was never played cannot be asked for a ranking
of it. Those 55 are already reported elsewhere and need nothing new: 51 of them carry no stage
either and are `Ice-Hockey-DQ-027`, while the other 4 carry 9 stages between them holding no
event, which is `Ice-Hockey-DQ-002`. Excluding them here is therefore not a blind spot but the
avoidance of a third report of the same fact.

`Ice-Hockey-DQ-103` asks it of the player ranking and reports 2 statistics of 301, three rows in
all: `Roman Josi` in `Winter Olympics Male 2014 - Competition Rank(athletes)`, and
`Christoph Brandner` and `Jeremy Rebek` in `Competition Stats Group A (athletes)` of the 2008
`World Championship 2`. No row anywhere names something that is not a team, so the second half
of the rule is clean and the check stands to keep it that way.

**The player ranking covers the teams two different ways, and both are correct.** Measured
2026-08-15 over the 233 tournaments carrying both shapes: in **154** every ranked team has a
squad, and they run from 1999 to 2026; in **75** only three teams do, and those three are always
exactly gold, silver and bronze holding a full 22 to 25 man roster while nobody else holds one.
Those 75 run from 1920 to 2004, so this is an editorial practice the sport changed rather than
two kinds of defect. The 1998 World Championship is the plain case: `Sweden`, `Finland` and
`Czechia` carry 24, 23 and 24 players and the other thirteen teams carry none.

**Four tournaments are neither, and `Ice-Hockey-DQ-108` reports them.** The rule it asserts is
the pair: a player ranking covers every ranked team, or exactly the ones that medalled, and
anything in between is an import that stopped part way. What it finds is not a thin classification
but whole squads missing, and the check names them in `ranked_teams_without_players`:

| Tournament | Ranked | With players | Missing |
|---|---:|---:|---|
| `7977` Winter Olympics 2014 | 12 | 11 | **`Sweden`**, the silver medallist |
| `27617` World Championship U18 2021 | 10 | 9 | **`Russia U18`**, the silver medallist |
| `16214` Winter Olympics 2022 | 22 | 10 | twelve teams, `Canada` and `Finland` among them |
| `27000` World Championship 1933 | 12 | 3 | nine, and the tournament records only two medals |

Two of the four are a silver medallist whose entire 25-man roster is absent while every other
team in the same tournament carries one, which is a stronger statement than the counts suggest.

The statement builds the set of teams the player rows name once, as a derived table, rather than
asking it per row: asked per row it is two correlated subqueries over 43708 player rows and the
server returned a gateway timeout twice. Built once it answers in 8.6 seconds.

**Naming a team is not the same as naming the right one.** `Ice-Hockey-DQ-107` compares the
`1429 Team` value with the lineups the player actually appears in, inside the same tournament,
and reports 1 row of 8918: **`Mason Raymond`** ranked under **`Czechia`**. The eligible
population is a player who appears in some lineup of that tournament - 194 rows measured on
2026-08-15 appear in none, which is the lineup layer's reach rather than a defect, and they are
counted nowhere. The lineup condition is also what makes the statement runnable: the layer
reaches 43 tournaments of 414, and comparing across the rest returned a gateway timeout twice
before the population was narrowed to where an answer exists.

**The same reach decides whether a ranked person can be asked to appear in their tournament at
all, and `GLOBAL-DQ-030` cannot ask it here.** That template accepts two participation paths -
an `event_participants` row or a `lineup` row - and in a team sport only the second can ever
succeed for a player, because the side entered against the event is the team and never the
person. Ice Hockey writes a lineup for 1616 of its 9803 events, so under a tournament that
stores none every ranked player is reported by construction. Reviewed 2026-08-15 on the
findings: 341 of the template's 371 statistics, and the 16650 athletes named in them, sit in
exactly that state, which is the absence of a layer rather than a stray entry; 66 of those
statistics carry coaches, read the same way, since 165 coaches do hold a lineup row and the path
is theirs too. Where the layer is present the rule reads correctly and returns 24 statistics
over 198 participants. `Ice-Hockey-DQ-110` is that statement, adding the lineup condition to the
template's own two; `GLOBAL-DQ-030` is recorded `Not applicable` in `SPORTS/params.json`, and
`Ice-Hockey-DQ-012` keeps its row as `Deprecated`.

**`1271 Points` and `1273 Comment` are declared and all but unused**: 8 values on 2 statistics
and 2 values on 1. Neither is structurally absent, and re-read on 2026-08-14 both turned out to
be populations a check can be written against after all - small ones, but not empty. The Points
values are `2, 3, 4, 5, 7, 9`, all numeric, and the Comment holds `DQ` twice, so
`DATA_COMMENT_VALUE_LIST` and `DATA_COMMENT_NO_RESULT_LIST` are both `'dq'` and
`NUMERIC_DATA_TYPE_LIST` is `1271`. `Ice-Hockey-DQ-094` and `Ice-Hockey-DQ-097` read them and
report nothing. `DATA_TIME_TYPE_ID` is recorded as `1426`, the field's global id, though this
sport writes no row into it.

`1277 Medal` holds only `bronze`, `gold` and `silver`, over 10386 values on 440 statistics. That
is 9 values and 3 statistics fewer than the same measurement returned on 2026-08-13, which is
the database being corrected under the reading rather than a discrepancy to resolve.

Config: `1463 Start date` and `1464 End date` on 837 statistics each, `1470 Gender` on 797,
`1471 Event id` on 33. So **40 statistics carry no gender and 67 carry no dates**, against a
population of 904.

**The `Event id` config is almost never written, and that is a finding on its own.**
`statistic_data_typeFK = 1471` holds the comma-separated list of events a Comp.Rank covers -
the only machine-readable statement of what a ranking is a ranking *of*. Measured 2026-08-20,
inside the client's 2004 boundary, **133 tournaments** hold a Comp.Rank that declares no scope
at all, against 30 statistics that do declare one.

Nothing is wrong with those rankings. A reader can see that a final standings covers the final;
the database cannot say so. What it costs is every question of the form "which events produced
this ranking", and `GLOBAL-DQ-040` is one of them: 209 of its 219 rows for this sport are that
template reporting it cannot answer, which is why the template is `Not applicable` here and
`Ice-Hockey-DQ-111` asks the answerable part instead. Golf writes the field and returns none of
that case in 430 rows, so this is practice rather than schema.

It is recorded here rather than reported 209 times because the audited object is the tournament
and not the final: 133 repairs, not 209 rows. Handing it over is a decision nobody has taken
yet.

**The sport writes three kinds of Comp.Rank and only one of them awards a medal.** Nothing in
the structure separates them: measured 2026-08-20, a group table and a tournament's medal table
carry the same three config fields - Start date, End date, Gender - and reach the same
`object_relation` target types 33, 43 and 151. The **name** is the only thing that differs, and
the sport writes it consistently:

| Name shape | What it is | Awards medals |
|---|---|---|
| `Competition Stats Group A` | the table for one group of one stage | no |
| `... - Competition Rank (Athletes)` | a squad list, one row per player | no |
| `Winter Olympics Male 2010 - Competition Rank` | the tournament's own standings | yes |

That is why `GLOBAL-DQ-026` is `Not applicable` here. Run plainly inside the 2004 boundary it
returned 295 of 557, and 292 of those were the first two kinds behaving correctly - 210
`No_Medals_At_All` and 82 `Medal_Set_Unreadable_Without_Rank`. Three rows said something.
`Ice-Hockey-DQ-112` narrows twice, by `MEDAL_TEMPLATE_ID_LIST` and by the name, and returns
**4 of 189**. Golf met the same wall at 3286 of 3491 and answered it the same way.

Two of the four are the same defect a decade apart - Winter Olympics 2010 and Asian Winter
Games 2011, each holding two golds against one first place and no bronze at all. The other two
are World Championship 2 rankings from 2009 and 2011 that hold three places and no medal of any
kind.

**What the narrowing gives up is worth naming.** A group table holding a medal, or a squad list
holding one, is a real defect and `Ice-Hockey-DQ-112` cannot see it. `GLOBAL-DQ-125` asserts the
other half - no medal outside the medal templates - and the two are only coherent while they
read the same list.

<!-- MANUAL PASTE ZONE: 5 STATISTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Reference values

Event status inside the boundary, from `GLOBAL-DISCOVERY-003` narrowed:

| status_type | status_desc | Events |
|---|---|---:|
| finished | `6 Finished` | 8686 |
| finished | `59 Finished OT` | 513 |
| finished | `13 Finished AP` | 394 |
| finished | `190 Finished after awarded win` | 3 |
| cancelled | `106 Cancelled` | 187 |
| notstarted | `1 Not started` | 20 |

**Four descriptions sit under `finished` and three of them change what the result means.** A
game finished after overtime, after penalties or by an awarded win did not end the way a
regulation game ended, and 910 events of 9803 are one of those three. A check reading
`status_type = 'finished'` alone treats all four alike, which is right for asking whether the
event concluded and wrong for asking how it was decided.

The 20 `notstarted` events are inside a boundary whose newest template data runs to 2027, so
they are not necessarily stale; `WORKFLOW.md`'s stale-notstarted rule needs the dates read
before it is applied here.

**`map_sport_status_desc` cannot be used to validate a status, and that is worth saying because
it looks as though it could.** Measured 2026-08-15: it maps **89 descriptions** to ice hockey,
and the sport's events use **6** of them. What the other 83 are is the giveaway - `1st half`,
`2nd half`, `Halftime` and `Kick Off Delayed` from football, `Top 1st` through `End 9th` from
baseball, `1st Quarter` to `4th Quarter` from basketball. The map is a permissive allow-list
rather than a statement about the sport, so a check reading it would accept a hockey match
described as being at half time. What the sport actually uses is the six under Event status
above, and `ROUND_TYPE_LIST`-style confirmation belongs in `SPORTS/params.json` rather than in
this table.

<!-- MANUAL PASTE ZONE: 5 REFERENCE VALUES — insert approved additions immediately before this marker; do not move or delete it. -->

## Event and round representation

26 round types inside the boundary, and together they account for all 9803 events. The group
stage is numbered rather than named — `38 "1"` through `44 "7"`, carrying 4571, 1280, 1274, 475,
471, 118 and 110 events — the knockout is named: `3 Quarter Finals` (427), `2 Semi Finals` (338),
`9 Final` (291), `138 bronze` (198), `4 1/8` (8) — and a third group settles places rather than
advancement: `22 5/6` (81), `26 5/8` (50), `23 7/8` (23), `24 9/10` (12), `25 11/12` (8),
`136 9/12` (3), `135 13/14` (1).

The remaining seven are second numbered series: `89 "1"` (38), `90 "2"` (5), `91 "3"` (3),
`92 "4"` (1), and `45 "8"` (7), `46 "9"` (7), `47 "10"` (3).

The full confirmed set is `2, 3, 4, 9, 22, 23, 24, 25, 26, 38, 39, 40, 41, 42, 43, 44, 45, 46,
47, 89, 90, 91, 92, 135, 136, 138`, and `SPORTS/params.json` records exactly that under
`ROUND_TYPE_LIST`. It first recorded 11 of them, and `GLOBAL-DQ-075` reported the other 15 as
unexpected round types — 250 events that were filed correctly. `POWERBI.md` records the case.

**The numbered round types carry names that are bare digits**, so a round type's name cannot be
matched as text without colliding with a placing. Worse, the names repeat across ids: `38` and
`89` are both named `1`, `39` and `90` both `2`, `40` and `91` both `3`, `41` and `92` both `4`.
The id is the identifier here, and no statement may match these rounds by name.

**The name collision is also a knockout-flag collision, and the two ids are not interchangeable.**
Measured 2026-08-14: `38 "1"` is `knockout = no` and `89 "1"` is `yes`, and the same holds for
`39`/`90`, `40`/`91` and `41`/`92`. This is the pair `DB-SEM-012` describes. What it rules out is
classifying the digits: `89` carries 16 Relegation Playoff games, 8 Olympic Qualification Round
games and 4 Olympic quarter finals - genuinely elimination - alongside the round-robin First,
Second and Third Rounds of the 1931 World Championship, which are not. Neither list can hold
`1` without being wrong about part of what the id covers.

So `GLOBAL-DQ-097` and `GLOBAL-DQ-118` are instantiated on the named rounds only, as
`Ice-Hockey-DQ-092` and `Ice-Hockey-DQ-093`. `ELIMINATION_ROUND_NAME_LIST` holds the five named
knockout rounds and the seven placement rounds - `5/6`, `5/8`, `7/8`, `9/10`, `9/12`, `11/12`,
`13/14`, each a single match with a winner - and `GROUP_ROUND_NAME_LIST` is empty, so the digits
are left unjudged, which the template's own rule allows. Both return 0 findings today, over 12
round types and 1440 events: every name the sport spells out is already flagged correctly. They
are kept for the day a final is filed under a non-knockout id.

**`Round` is also an event property on all 9803 events, it disagrees with `event.round_typeFK`
on 341 of them, and nothing here reads it.** Decided 2026-08-15: the round of an event is
`event.round_typeFK` and the property is not a second opinion the client is interested in. No
statement may compare the two, and the 341 are not findings.

The measurement is recorded because the disagreement is real and someone will find it again.
Every event carries the property, 9462 repeat the round type's own name, and the 341 that do not
are all filed under `38 "1"` while the property says `2`, `3`, `4`, `5` or `6`. They cluster
into **64 stages** — a group of 15 matches holding 3 on round `1` and 12 disagreeing — so what
they measure is 64 imports that put a whole group stage on the first round, not 341 separate
mistakes. Were it ever read, the correction would be derivable: the round type carrying the
property's name with the same knockout flag, `2` to `39`, `3` to `40`, `4` to `41`, `5` to `42`,
`6` to `43`.

This is not the same case as the `discipline` property, which is a remnant. The `Round` property
is written everywhere — 123 sports, and 317265 ice hockey events server-wide — so it is a
parallel copy the feed maintains rather than an abandoned path. What makes it unread here is the
client's decision, not its size. `object_round` is no help either: it attaches a round to a
tournament stage or to a Comp.Rank participant, and the only sport where it attaches to an event
is `FIFA`, on 949 events.

<!-- MANUAL PASTE ZONE: 5 EVENT AND ROUND REPRESENTATION — insert approved additions immediately before this marker; do not move or delete it. -->

## Confirmed sport-specific storage semantics

**A level score is a result in this sport, and only some rounds forbid it.** Measured
2026-08-14: 297 events in the boundary hold the same `4 Final Result` on both sides, and 290 of
them are in the numbered group rounds `38` to `46`, where a draw is the outcome and the sport
awards points for it. Whether a tie is legal is therefore a question about the round, not about
the sport, and no statement here may assert the sport-level rule. `GLOBAL-DQ-084` is recorded
`Not applicable` in `SPORTS/params.json` on exactly that ground, which is the same signal and
the same reason `SPORTS/Soccer.md` records; `GLOBAL_DQ/README.md` owns the prerequisite that
demands it.

The 7 remaining are in rounds that must produce a winner, and they are a defect list rather
than a rule: the 1998 World Championship final Sweden-Finland stored `0-0`, the 1998 and 1999
semi-finals, the 2001 U-20 final at `5-5`, and three placement matches from 1933 and 1995. A
knockout round decided in overtime or on penalty shots stores the deciding goal in
`2 Extra time` or `3 Penalty shootout`, so a level final result with neither is a match whose
resolution was never imported. Soccer carries the narrower rule as `Soccer-DQ-022`; the
equivalent here is **`Ice-Hockey-DQ-058`**, over 1413 eligible events.

**The period scores add up, and the sum has to include overtime and the shootout.** Measured
2026-08-14 over the 9596 finished events: 8692 have `51`+`52`+`53` equal to `4 Final Result`
outright, and a further 897 agree only once `2 Extra time` and `3 Penalty shootout` are added -
so a sport-level rule that summed the three periods alone would report every match decided
beyond regulation. `Ice-Hockey-DQ-059` sums all five and reports 4, all of them at the 2026
Winter Olympics.

**Where the boxscore and the result layer both hold a period, they agree three times in a
thousand short of always.** Measured 2026-08-15 over the 882 events carrying both: 5285 of 5288
participant-periods are identical, and the three that are not are all a first period at the
2026 Winter Olympics, all with the result layer holding `0` where the boxscore holds a goal.

| Event | Date | Side | Boxscore | Result |
|---|---|---|---:|---:|
| `4849552 Slovakia-Finland` | 2026-02-11 | Slovakia | 1 | 0 |
| `4849551 Switzerland-France` | 2026-02-12 | Switzerland | 2 | 0 |
| `4849782 Canada-France` | 2026-02-15 | France | 1 | 0 |

`Ice-Hockey-DQ-059` reports 4 events whose periods do not sum to the final result, also all at
the 2026 Winter Olympics, so the two readings are almost certainly one import going wrong at one
tournament rather than two separate faults. **`Ice-Hockey-DQ-101`** asserts the agreement, over
882 eligible events - those storing a period in both layers for the same participation, which is
the only population where the two can be compared. It is deliberately not a restatement of
`-059`: that check sums one layer against its own final result and would pass a period written
consistently wrong, while this one needs a second opinion to exist before it says anything, and
is silent on every event that has the period once.

**The period breakdown is incomplete on 1104 finished events, and `Ice-Hockey-DQ-109` reports
them all.** Measured 2026-08-15 over the 9596 finished events holding any period result, the
shortfall comes in three shapes: **1091** hold the first period alone with a value equal to the
final result on every side, **10** hold the first and second and no third (1987 to 2001), and
**3** hold the first alone with a value that differs from the final result - those three are the
`190 Finished after awarded win` events, where the forfeit score and the period field were never
going to agree. The check is on the board even though its main reading is a question rather than
a correction, so that the question is visible in a run and not only in this file.

**`51 Period 1` doubles as the whole score on 1091 finished events, and this is unresolved.**
Those events carry no `52` and no `53` at all, and on every one of them the `51` value equals
the `4 Final Result` exactly, which is what makes it readable as a total rather than as a first
period in which all the goals happened. They run from 1932 to 2024, so it is not a habit the
sport has stopped. Ten more carry `51` and `52` and no `53`. Nothing reads the period fields as
a breakdown yet, and `Ice-Hockey-DQ-059` audits only sides holding all three, so no check
depends on the answer - but one is recorded as open question 7 below, because the day a check
does read them it will read 1091 first periods that are not first periods.

**The event medal layer is almost unwritten, and that is a gap rather than a convention.**
Measured 2026-08-14 over the 483 events in a medal round: 463 carry no `501 Medal` value at
all - 278 finals and 185 bronze matches - and 737 of the 962 participations in those rounds
lack the medal their own score implies. The `medal_related` property is on 8 events of 9803.
Against that, the Comp.Rank `1277 Medal` field holds 10395 values over 443 statistics, and the
three checks reading it return 0, 0 and 2.

So the sport does record its medals, in the statistic, and does not record them on the event
that awarded them. Decided 2026-08-14 that the event is the place a medal belongs and its
absence is a defect: `Ice-Hockey-DQ-077`, `-078` and `-079` assert it, and `-079` names the
medal each participation should hold, since the score already says who won. The 463 and the 737
are a work list, not a storage habit.

`GLOBAL-DQ-037` is the one medal template that stays out, and not on that ground: it reads
`100 Rank` to decide which medal a finalist should hold, and this sport carries one Rank value
in the whole boundary. `GLOBAL-DQ-093` asks the same question from the round type and is
instantiated in its place.

**The sport contests men and women and nothing else.** `1470 Gender` on the Comp.Rank config
holds `male` on 443 statistics and `female` on 212, and never a third value; all 25 templates in
the boundary are `male` (13) or `female` (12). There is no mixed team format anywhere, which is
what `GLOBAL-DQ-066` and `GLOBAL-DQ-067` audit - a mixed side whose composition is uneven - so
both reach an empty population by the sport's own structure rather than by a shortage of rows.

**No Comp.Rank participant in this sport carries a phase.** `GLOBAL-DQ-033` reports 746 of 746
statistics, and the `object_round` rows it reads do not exist anywhere in the sport. `Golf` and
`Soccer` both record the identical measurement as a structural absence and do not run the check.
Ice hockey does: decided 2026-08-14 that the phase is a field nobody has filled rather than one
the sport has no place for, so `Ice-Hockey-DQ-084` keeps it on the board until it is. The two
readings are not distinguishable from the data, which is why the decision is recorded here and
not derived.

**A Comp.Rank that awards a place awards a medal, the group phase included.** `GLOBAL-DQ-026`
reports 309, of which 224 are group standings - `Competition Stats Group A` and `Group B` of the
World Championship divisions - holding a first, second and third place and no medal at all. The
reading that a group is not a medal event was refused on the same day: `Ice-Hockey-DQ-083` runs
whole.

**No tournament stage in this sport carries a city.** `GLOBAL-DQ-034` reports 1348 of 1348
stages, and on 995 of them the city is the only thing missing; the other 353 also carry no host
country, and those 353 are the stages whose own country is `International`, where the host is
what says where the thing was actually played. One field unfilled everywhere is one storage
habit rather than 1348 defects, and the count is the size of the fill, not a reason to withdraw
the check: decided 2026-08-14 to instantiate it whole as `Ice-Hockey-DQ-090`. The 353 are the
part of it that can shrink first.

The Comp.Rank equivalent is a different shape and is instantiated on its own terms.
`GLOBAL-DQ-035` reports 426 of 557 as `Ice-Hockey-DQ-091`, spread across four fields rather than
concentrated in one - 274 holding a placeholder country, 223 missing a city, 59 missing the
gender, 52 missing the country - and 131 statistics are clean. The sport does fill these fields
somewhere, which is what makes this a work list where the stage check is a habit.

`PLACEHOLDER_COUNTRY_LIST` is `'International', 'Unknown', 'Undefined'`. The first two exist -
139 participants carry `International` and 6 carry `Unknown`, all of them teams - and
`Undefined` never matches, which the template's prerequisite allows.

**The schedule breaks are mostly the twentieth century, and the parameter cannot say so.**
`GLOBAL-DQ-081` reports 11 of 23 templates as `Ice-Hockey-DQ-098`. **The twentieth century is no
longer among them**, and that is the client's 2004 boundary rather than a repair: the gaps this
paragraph used to name - `1920 -> 1924`, the war years `1939 -> 1947`, the Olympic years in
which no separate world championship was held - are outside what UK Sport takes and the check
no longer reaches them. Remeasured 2026-08-21.
What is left is recent and mostly one competition. The two `Winter Olympics Qualification`
templates carry 12 and 8 skipped editions between 2004 and 2025, which is a four-yearly
qualification measured against a yearly rhythm the check reads off its own editions. Then
`Challenge Cup of Asia` with 6 and 3, `World Championship 1` with 4 - `2005 -> 2007`,
`2009 -> 2011`, `2013 -> 2015` - and `World Championship 2` with 2, one of which is
`2019 -> 2022` and is COVID. `11076` and `11077` still report `2011 -> 2017` and
`2017 -> 2025` because the Asian Winter Games moved twice, and both show 0 editions skipped
because the check reads their rhythm as four-yearly and the moves fit it.

`SERIES_SKIP_YEARS` cannot suppress any of these, and the reason is structural rather than a
matter of listing more years: the template discounts a skipped year only if some tournament in
the sport ran in it, and 1940 to 1946 hold no event anywhere in ice hockey. Since the 2004
boundary those seven years are out of the check's reach as well, so the parameter's war years
are now a record of what is known rather than anything the check could use; `2020` is the only
value that can still do work and the only one inside the boundary. Decided 2026-08-14 to
instantiate the check anyway: 11 rows each carrying a `break_detail` is a list a person reads
once, and the alternative is not knowing when an import stops arriving.

**`MEDAL_TEMPLATE_ID_LIST` holds 21 of the 25 templates in the boundary.** Nineteen award medals
and hold them today; `308` and `10849`, the men's and women's `World Championship 2`, are added
by judgement because a divisional championship awards its own gold, silver and bronze whether or
not any are stored. The four left out are `313` and `10568`, `Euro Hockey Tour 1`, a seasonal
series with a winner rather than a podium, and `10501` and `10720`,
`Winter Olympics Qualification`, which hands out places. `GLOBAL-DQ-125` runs as
`Ice-Hockey-DQ-100` and reports 0 of 124 eligible.

Five more templates were instantiated on the same day and report nothing at all:
`Ice-Hockey-DQ-094` over the two Comp.Rank Comment values, `Ice-Hockey-DQ-095` over 9616 events
whose status could contradict their date, `Ice-Hockey-DQ-096` over 9803 events that could
duplicate one another, `Ice-Hockey-DQ-097` over the two statistics holding `1271 Points`, and
`Ice-Hockey-DQ-099` over 9803 events whose whole-unit result fields could hold a fraction. None
of them is empty scope - each has a population and each population is clean.

Nothing else beyond what the sections above record. This file is one day old and every other
paragraph in it is a first reading.

**The findings were reviewed on 2026-08-15, and the sport is the first in the package where
every reporting check has been judged.** 62 of the 106 approved checks returned something, 27093
rows in all, and each was read as one question rather than as its rows. **59 came back a
defect** and are the data owners' work, not the package's: no statement was changed on their
account and none should be. **Three came back normal for the sport**, and each of those is a
statement about the check rather than about the data - `Ice-Hockey-DQ-087` and
`Ice-Hockey-DQ-088` are now `Monitor`, recorded above where each layer is described, and
`GLOBAL-DQ-030` turned out to be unaskable in a team sport and was replaced by
`Ice-Hockey-DQ-110`. Nothing was judged a parameter fault and nothing was left unclear, so no
question came back from the review. What that leaves outstanding is a data correction round, and
what each check should return after it needs no `_expected` entry: the signal supplies it, so
the two `Monitor` checks expect a number that stays and every other approved check expects zero.

**`Ice-Hockey-DQ-023 EVENT_RESULTS_MEDAL_RANK_MISMATCH` is `Deprecated` from 2026-08-28, and
the CheckID keeps its row.** `GLOBAL-DQ-053` asserts that a medal follows a place: gold is one,
silver two, bronze three, and a medal with no place at all is a defect. That is true of a sport
whose medals come out of a ranking. This sport's do not.

Measured 2026-08-28 inside the boundary, all 658 medal rows over 412 events sit in `9 Final`
or `138 bronze` and nowhere else - 246 finals carrying gold and silver, 166 bronze matches
carrying bronze. The medal is the outcome of a match, so 542 of the 658 carry no place, and the
check was reporting every one of them: 542 findings of 542 eligible, a check with no clean row
in it. It had grown 30, then 35, then 542 as colleagues added the medals that were missing,
which is the check getting louder the more correct the data became.

The question it asks is already asked where this sport does store a place. `1270 Rank` lives on
the Comp.Rank layer and `Ice-Hockey-DQ-031` runs `GLOBAL-DQ-072` over it. The medal itself is
covered from four sides at event level - `-078` for the medal set the round should hold, `-079`
for the medal against the score, `-014` for a medal on a round that awards none, and `-121`.
Nothing is unwatched by this deprecation.

Handball, Soccer and Curling never instantiated `GLOBAL-DQ-053` at all: each declares
`RESULT_RANK_TYPE_ID` not applicable because the pairing is the classification, and the
parameter rule refused the template for them. Ice-Hockey is the only H2H sport that records the
parameter, which is the only reason the template reached it.

**`RESULT_RANK_TYPE_ID` stays recorded, and is not to be declared not applicable here.** Unlike
the other three, this sport does store `100 Rank` - 117 rows on 2026-08-28. What they hold is
the point: 116 sit beside a medal on a final or a bronze match and read `1`, `2` or `3`, an
exact restatement of the medal word that adds nothing to it, and every one of them agrees with
its medal. The 117th carries `92` on an event of round type `40`, with no medal beside it, and
a place of 92 in a match between two teams is not a place at all. `Ice-Hockey-DQ-055` reports
that row - event 1837359, Poland-Ukraine - and removing the parameter would take the only
report of it with it.

**`Ice-Hockey-DQ-055` carried a smaller version of the same H2H problem and is `Deprecated`
from 2026-08-28 too, replaced by `Ice-Hockey-DQ-128`.** It ran `GLOBAL-DQ-119`, whose own
applicability asks for a sport storing an event-level Rank over a ranked field, and this sport
has no field to rank. Measured that day it returned 3 findings of 60 eligible, two of them
events 344939 and 344941 - the Euro Hockey Tour bronze matches of 2007 - each reported as
`sequence starts at 3, expected 1`. A bronze match decides third and fourth, so starting at 3
is what those events should say. Ten of the eleven sports running that template are Listing or
Hybrid; Ice-Hockey was the only H2H one, for the same reason it was the only one running
`GLOBAL-DQ-053`.

**`Ice-Hockey-DQ-128 EVENT_RESULTS_RANK_DOES_NOT_RESTATE_THE_MEDAL` asks what a place can
actually mean here.** With no field to rank, a Rank in this sport is either the medal written
a second time as a number or it is nothing, so the statement reports a Rank with no medal
beside it and a Rank that disagrees with the medal it sits next to, and nothing else. Measured
2026-08-28 it returns 1 finding of 117 eligible: the 92 on Aleksandr Ossipov, and no bronze
match. It does not depend on `Ice-Hockey-DQ-057` continuing to reach the same event, which it
would stop doing the day somebody writes that side a Final Result instead of removing the row.

<!-- MANUAL PASTE ZONE: 5 STORAGE SEMANTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Open questions

1. ~~**What does `1429 Team` hold on a Comp.Rank participant row?**~~ Answered 2026-08-15: the
   side the ranked person plays for. Every one of the 43708 values in the boundary resolves to
   an active `team` participant and none repeats its own row. It is also what separates the 445
   team standings from the 301 player leaderboards. Recorded under Statistics above.
2. ~~**Do the period result types and the period scope types describe the same games?**~~
   Answered 2026-08-15: yes, and they agree. Where both layers store a period for the same
   participation, 5285 of 5288 pairs are identical - `period1` 1761, `period2` 1762, `period3`
   1762 - so the scope periods are a subset of the result periods and say the same thing. The
   three exceptions are recorded under Event result types above. A period check may read either
   layer; reading both would double-count the 882 events that have them in both places.
3. ~~**Does the `Round` property agree with `event.round_typeFK`?**~~ Answered 2026-08-15: on
   9462 of 9803 events, and the 341 that disagree cluster into 64 stages imported with a whole
   group on round `1`. No check was written: the client reads the round from
   `event.round_typeFK` and not from the property. Recorded under Event and round representation
   above.
4. ~~**What are the 202 events holding a period score and no Final Result?**~~ Answered
   2026-08-14: 182 cancelled and 20 not started, no finished event among them. Recorded under
   Event result types above, and `Ice-Hockey-DQ-057` guards the finished population.
5. ~~**Are the 20 events with no `object_discipline` relation also the 20 `notstarted` events?**~~
   Answered 2026-08-15: yes, the same 20. All of them are `Not started` in
   `33 World Championship 1`, dated 2026-11-06 to 2026-11-11, so they are fixtures whose
   discipline has not been written yet rather than played events missing one.
   `Ice-Hockey-DQ-067` reports them and needs no change; what it reports is a fixture waiting
   to be completed, and it should fall to zero on its own.
6. ~~**Is the single `athlete` event participation, the single `100 Rank` value and the one
   event they share the same defect?**~~ Answered 2026-08-14: yes, and the event is
   **1837359 Poland-Ukraine**, World Championship 2, 2015-04-22. It carries three
   `event_participants` rows where every other event in the sport carries two - the two teams
   and Aleksandr Ossipov - and the third holds the sport's only `100 Rank` value and no
   `4 Final Result`. `Ice-Hockey-DQ-057` found it independently as its single finding, which is
   what made the three observations one row. It is one correction, and it belongs to the
   colleagues rather than to a check. **The word "only" was true on 2026-08-14 and is not any
   more:** re-measured 2026-08-28 the sport holds 117 `100 Rank` rows inside the boundary. The
   other 116 arrived with the medals the colleagues have been adding and restate the medal word
   rather than adding a place. Nothing about the answer above changes - 1837359 is still the
   event and 92 is still the value - but a later reader should not take the count from here.
7. ~~**Is `51 Period 1` the first period or the whole game on the 1091 events that store no
   other period?**~~ Closed as a question on 2026-08-15 and reported instead. The value equals
   the final result on every one of them and they run from 1932 to 2024. Every layer that could
   separate the two readings was measured and every one is empty for exactly these events:
   **0 goal incidents**, **0 lineup rows**, and of the 19 holding any scope container at all,
   **none holds a period scope** - so no further query will settle which reading is right.
   Decided that this makes it a finding rather than an open question: **`Ice-Hockey-DQ-109`**
   reports the population, and whoever reads the findings decides what the field means. Nothing
   is pending with anybody. Until the reading is settled no statement may treat `51` as a first
   period; `Ice-Hockey-DQ-059` and `Ice-Hockey-DQ-104` already audit only sides holding all
   three, so neither depends on it.

8. ~~**Should a bronze match be expected to rank its two teams 3 and 4, or 1 and 2?**~~
   Answered 2026-08-28, on the day it was raised: the question does not have to be settled,
   because nothing in this sport needs to read a rank sequence. `Ice-Hockey-DQ-055` was
   deprecated and `Ice-Hockey-DQ-128` put in its place, and that statement asks whether a rank
   restates its medal rather than whether a sequence starts at one - so a bronze match ranking
   3 is simply correct to it and is not reported. What follows below is the reading that led
   there, kept because it is why the template does not fit.
   `Ice-Hockey-DQ-055` reports events 344939 and 344941, the Euro Hockey Tour bronze matches of
   2007, as `sequence starts at 3, expected 1`, and third and fourth is what a bronze match
   actually decides. `GLOBAL-DQ-119` reads an event as a field ranked from one, which is right
   for a listing sport and wrong for a two-team match that settles places three and four.
   Raised while deprecating `Ice-Hockey-DQ-023` for the same H2H mismatch. Three ways out were
   weighed: teaching `GLOBAL-DQ-119` the bronze round, which would have reached Speed-Skating
   and Track-Cycling as well - the only other two declaring a `BRONZE_ROUND_TYPE_LIST` - and so
   needed measuring on both before a line could be written; asking the colleagues whether the
   116 echo ranks belong in the data at all; and the sport statement, which is what was chosen.
   The other two remain available and neither is closed by this: whether ice hockey should
   store an event-level Rank at all is still nobody's decision, and `-128` reports the same one
   row either way.
<!-- MANUAL PASTE ZONE: 5 OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
