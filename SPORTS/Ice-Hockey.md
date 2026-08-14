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
- Latest evidence date: 2026-08-14
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
| Other tables | Not checked | |

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
| rank | 100 | integer | Finishing place | **1 row, 1 event** |

**`1 Ordinary time` and `51 Period 1` reach every event in the boundary and `4 Final Result`
does not.** 9803 against 9601 is 202 events holding a period score and no final result, which
is the first thing a results check here has to be scoped around. `6 Running score` sits between
them at 9791.

**`100 Rank` holds a single row in the whole boundary.** This is a head-to-head sport where the
result is a score, not a placing, so a rank on one event participant is a stray rather than a
thin layer — and it is the same event as the stray `athlete` participation above.

`549 Final Outcome` and `550 Overall Score` are each on a handful of events and have not been
read further. Both are named here so that neither reads as an unknown type later.

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

**`1429 Team` carries more values than `1270 Rank` and reaches fewer than half the statistics.**
51941 against 44110, on 371 statistics against 810. A Team field on a participant row of a team
sport is not obviously the same thing as a rank, and what it holds — the sample is `100108`,
which reads as a participant id — is not yet established.

**`1271 Points` and `1273 Comment` are declared and all but unused**: 8 values on 2 statistics
and 2 values on 1. Neither is a population a check can be written against today, and neither is
structurally absent.

Config: `1463 Start date` and `1464 End date` on 837 statistics each, `1470 Gender` on 797,
`1471 Event id` on 33. So **40 statistics carry no gender and 67 carry no dates**, against a
population of 904.

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

<!-- MANUAL PASTE ZONE: 5 REFERENCE VALUES — insert approved additions immediately before this marker; do not move or delete it. -->

## Event and round representation

26 round types inside the boundary. The group stage is numbered rather than named — `38 "1"`
through `44 "7"`, carrying 4571, 1280, 1274, 475, 471, 118 and 110 events — and the knockout is
named: `3 Quarter Finals` (427), `2 Semi Finals` (338), `9 Final` (291), `138 bronze` (198).

**The numbered round types carry names that are bare digits**, so a round type's name cannot be
matched as text without colliding with a placing. The id is the identifier here.

`Round` is also an event property on all 9803 events, holding a number. Whether it agrees with
`event.round_typeFK` is not measured.

<!-- MANUAL PASTE ZONE: 5 EVENT AND ROUND REPRESENTATION — insert approved additions immediately before this marker; do not move or delete it. -->

## Confirmed sport-specific storage semantics

Nothing beyond what the sections above record. This file is one day old and every paragraph in
it is a first reading.

<!-- MANUAL PASTE ZONE: 5 STORAGE SEMANTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Open questions

1. **What does `1429 Team` hold on a Comp.Rank participant row?** 51941 values on 371
   statistics, sample `100108`, which reads as a participant id. In a team sport whose Comp.Rank
   ranks teams, a Team field on the participant row is either a duplicate of the participant or
   something else entirely, and no check should read it until this is answered.
2. **Do the period result types and the period scope types describe the same games?**
   `51`–`53` reach 8501 to 9803 events, `322`–`324` reach 898. Whether the 898 are a subset and
   whether the two agree where both exist is unmeasured, and a period check has to know.
3. **Does the `Round` property agree with `event.round_typeFK`?** Both are on every event in
   the boundary and neither has been read against the other.
4. **What are the 202 events holding a period score and no Final Result?** 9803 against 9601,
   and `GameEnded` sits on the same 9601.
5. **Are the 20 events with no `object_discipline` relation also the 20 `notstarted` events?**
   The counts are equal, which is either the explanation or a coincidence worth ruling out.
6. **Is the single `athlete` event participation, the single `100 Rank` value and the one
   event they share the same defect?** All three point at one event in 2015.

<!-- MANUAL PASTE ZONE: 5 OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
