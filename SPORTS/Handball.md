# SPORT: Handball (sport_id=20)

This file is the canonical structural record for Handball. It contains only confirmed
sport-specific usage, meanings, identifiers, evidence boundaries and open structural
questions. Global database mechanisms belong in `../DATABASE.md`.

For additions, insert approved content immediately before the exact active
`MANUAL PASTE ZONE` marker in the destination subsection. Keep the marker unchanged
and at the end of its subsection. Replace existing rows or paragraphs in place when a
correction is required.

## Identity and evidence

- First discovery date: 2026-08-28
- Latest evidence date: 2026-08-28
- Verification boundary: the client's 39 tournament templates, 13573 active events. The sport
  holds 160 active templates and 187413 events server-wide, so **everything below describes
  7.2 per cent of the sport** unless the paragraph says otherwise. Registry, statistic and
  participant figures are sport-wide, because those layers carry no template relation and the
  narrowing cannot reach them; every count read through an event is inside the boundary.

`sport.name` is `Handball` and the provider code is `hb`. `SPORTS.md` maps that to the
repository slug `Handball`, which is the same word.

**The client boundary is declared as what it contains, not as what it excludes.** 39 templates
of 160, and `SPORTS/params.json` names those 39 under `IN_SCOPE_TEMPLATE_ID_LIST`; the runner
computes the 121 it does not take, at every run, against the templates the sport has then.
`TOOLS/README.md` owns the mechanism and states the rule as declaring whichever list is the
short one, because that is also the one whose default is right. Here the two are 39 against
121, and the sport is overwhelmingly club handball - national leagues, cups and the European
club competitions - none of which the client takes. Under an exclusion list every new league
would arrive inside the boundary with nobody deciding it.

The 39 are the national-team competitions, both genders throughout: the Summer Olympics and
its qualification tournaments, the Youth Olympic Games and the European Youth Olympic
Festival, the World and European Championships at senior level and at U17 to U21, and the
continental championships - Africa Cup of Nations, Asian Championship, Pan American
Championship, Oceania Nations Cup - together with the Asian, Pan American and Southeast Asian
Games. **No club competition is in scope**, including `348`/`349 Champions League`, which is
where a large share of the sport's Comp.Rank sits.

**`9610 World Championship U18` male is inside the boundary and holds nothing at all**:
no tournament, no stage, no event. Measured 2026-08-28 through `GLOBAL-DISCOVERY-002`
narrowed, and it is the only empty template in the boundary.

**The men's editions exist; they are stored at a different age.** Handball runs the women's
junior world championships at U18 and U20 and the men's at U19 and U21, and the database
follows that: `11108 World Championship U19` male holds 11 tournaments, 86 stages and 813
events, against `9611 World Championship U18` female's 724. The original client list named
`9610`, an age group the men never contested, and did not name `11108`.

**`11108` was added to the boundary on 2026-08-28** by the user's decision, taking it from 38
templates to 39 and from 12760 events to 13573. `9610` was kept rather than replaced, so the
empty template stays audited and stays visible - `Handball-DQ-001` reports it, and whether the
client meant to order it at all is still a question for them.

## Structural coverage

| Area | Status | Evidence |
|---|---|---|
| Core hierarchy | Confirmed | `GLOBAL-DISCOVERY-002` narrowed, 39 templates, one of them empty |
| Event participants | Confirmed | `GLOBAL-DISCOVERY-004`, `-032` narrowed, teams only |
| Event results | Confirmed | `GLOBAL-DISCOVERY-007` narrowed, 8 types; `-026` narrowed over all 8 |
| Incidents | Confirmed, outside client scope | `GLOBAL-DISCOVERY-008` narrowed, 13 types; UK Sport does not take the layer, decided 2026-08-28 |
| Lineups | Confirmed | `GLOBAL-DISCOVERY-005` narrowed, 2 lineup types |
| Scope layer | Confirmed | `GLOBAL-DISCOVERY-009`, `-010` narrowed, 2 scope types |
| Properties | Confirmed | `GLOBAL-DISCOVERY-011` narrowed, 30 rows |
| object_relation | Confirmed | `GLOBAL-DISCOVERY-012` narrowed, 6 pairs |
| object_discipline | Confirmed | `GLOBAL-DISCOVERY-013` narrowed, one discipline |
| Statistics | Confirmed | `GLOBAL-DISCOVERY-015`, `-016`, `-017`, `-024`, `-025`, `-028`, `-029`, `-030`, `-031` sport-wide |
| Reference values | Confirmed | `GLOBAL-DISCOVERY-014` narrowed, 1984 stages; `-018`/`-019` narrowed, all 46 round types |
| Stage name patterns | Confirmed | `GLOBAL-DISCOVERY-022`/`-023` narrowed, all 200 patterns over all 1984 stages |
| Participant duplicates | Confirmed | `GLOBAL-DISCOVERY-033` sport-wide, 208 name groups |
| Event name patterns | Not checked | `GLOBAL-DISCOVERY-020` narrowed returns 4666 patterns; `-021` read 8 of them, which is a sample and not coverage |
| Event result value detail | Not checked | `GLOBAL-DISCOVERY-027` completed for `501 Medal` only; see Open questions |
| Venues and cities | Not checked | |
| Status vocabulary map | Not checked | |
| Translations | Not checked | |
| Other tables | Not checked | |

## Tables and relation paths used

The sport is **H2H (team)** by `DATABASE.md` `DB-SEM-015`: every event inside the boundary
carries exactly two `event_participants` rows and the participant is a `team`. 27146
participations over 13573 events, with no exception measured.

`event -> tournament_stage -> tournament -> tournament_template` is the whole hierarchy and all
four layers are populated. `GLOBAL-DISCOVERY-002` narrowed returns 39 template rows, one per
template in the boundary; 38 of them hold tournaments and `9610 World Championship U18` male
holds none.

Comp.Rank hangs off the **tournament** (`statistic.object_typeFK = 3`), 464 statistics
sport-wide, participants in `statistic_participants11` and data in `statistic_data11`. The
shard was confirmed by running `GLOBAL-DISCOVERY-016` and `-017` against it directly; the
runner's own probe had reported no shard, because the lowest-id statistic of the type is a row
named `test` that holds no participants at all.

Six `object_relation` pairs are in use inside the boundary:

| Source | Target | Rows | Distinct targets |
|---|---|---:|---:|
| `4` `tournament_stage` | `151` `tournament_age_class` | 1983 | 3 |
| `4` `tournament_stage` | `33` `country` | 1710 | 68 |
| `83` `statistic` | `33` `country` | 332 | 4 |
| `83` `statistic` | `151` `tournament_age_class` | 330 | 3 |
| `2` `tournament_template` | `152` `tournament_sub_set` | 39 | 19 |
| `1` `sport` | `153` `category` | 1 | 1 |

One discipline throughout, `634` 7aSide, on all 13573 events and on 437 statistics inside the
boundary. `GLOBAL-DISCOVERY-032` returns two rows and only two: 7aSide / female / team, 6340
events over 19 templates, 2000 to 2026; and 7aSide / male / team, 7233 events over 19
templates, 2001 to 2027. Beach handball and 6aSide are not stored under this sport.

<!-- MANUAL PASTE ZONE: 20 TABLES AND RELATIONS — insert approved additions immediately before this marker; do not move or delete it. -->

## Participant and lineup structure

`event_participants` holds **teams only**, with no measured exception: 380 male teams over
14466 participations and 266 female teams over 12680, inside the boundary. Unlike Ice Hockey,
not one athlete is entered as an event participant.

The people are in the **lineup**, and inside the boundary the layer uses two lineup types:

| lineup_typeFK | Name | Member type | Rows | Distinct members |
|---:|---|---|---:|---:|
| 6 | Unknown | athlete | 35268 female, 34196 male | 2221, 2214 |
| 14 | Starter | athlete | 19283 male, 15726 female | 1729, 1337 |
| 6 | Unknown | coach | 1417 male, 161 female | 42, 5 |
| 14 | Starter | coach | 57 male, 7 female | 8, 1 |

**`6 Unknown` is the busiest lineup type, not a residue**: 70842 rows against 35073 for
`14 Starter`. **Adding `11108` changed not one lineup row either**, so its 813 events carry
no squads at all - the same silence the incident layer shows for them. A check treating an unknown lineup type as absent would silence two thirds of the
lineup layer in this sport. Sport-wide the sport also uses `1 Goalkeeper` (347 rows) and
`5 Substitute player` (2 rows), and neither appears inside the client boundary; that is a
property of this population today and not a structural absence, so a check reading those types
stays applicable here.

64 rows file a `coach` under a lineup type whose other members are athletes, which is worth
naming before a check counts lineup members as players.

The sport registry (`object_participants`) is sport-wide and much larger than the boundary:
15837 active male athletes and 11778 female, 1669 male teams and 1288 female, 316 male coaches
and 12 female, 118 male officials and 45 female, plus 75 male and 124 female athletes and 27
teams flagged inactive.

**The registry role and the participant type disagree on 100 rows**, audited by
`Handball-DQ-060`: 47 rows register a `coach` under the role `athlete`, 5 more do so for women,
2 do so with `del` set, and 41 male and 5 female `official` rows carry an empty role.

**30 registered people hold more than one registry row under the same name**, measured
2026-08-28 through `GLOBAL-DISCOVERY-033` with `PERSON_PARTICIPANT_TYPE_LIST` set to
`'athlete'`. That run returns 208 name groups in total, of which 178 point at genuinely
different participant ids and 30 are one person entered twice. Widening the parameter to
`'athlete', 'coach'` was measured on the same day and rejected: it returns 264 groups, and of
the 56 it adds only 4 point at different people while 52 are one person holding both an athlete
and a coach registry row. The narrow value is what `SPORTS/params.json` records; the wide
measurement is kept here because it is the obvious thing for the next reader to try.

<!-- MANUAL PASTE ZONE: 20 PARTICIPANTS AND LINEUPS — insert approved additions immediately before this marker; do not move or delete it. -->

## Event result types

Eight active result types inside the boundary, from `GLOBAL-DISCOVERY-007` narrowed.
`GLOBAL-DISCOVERY-026` narrowed was run over all eight, so the value shapes below are the
sport's whole use of the layer inside the boundary rather than a sample.

| result_code | result_typeFK | Value shape | Confirmed meaning | Evidence |
|---|---:|---|---|---|
| runningscore | 6 | integer | Mirror of the score | 27146 rows, 13573 events |
| ordinarytime | 1 | integer | Goals in regulation | 26970 rows, 13485 events |
| finalresult | 4 | integer | The score the result is decided on | 26750 rows, 13375 events |
| halftime | 5 | integer | Goals at half time | 24220 rows, 12110 events |
| eventoutcome | 668 | `won` / `lost` / `draw` | Outcome word | 2836 rows, 1418 events |
| medal | 501 | `gold` / `silver` / `bronze` | Medal awarded | 708 rows, 469 events |
| extratime | 2 | integer | Goals in extra time | 316 rows, 158 events |
| penaltyshootout | 3 | integer | Shootout goals | 146 rows, 73 events |

**`6 Running score` reaches every event in the boundary and the deciding result does not.**
13573 against 13375 for `4 Final Result`, and 13485 for `1 Ordinary time`. The two gaps are
198 and 88 events, unchanged by the addition of `11108`, so every one of them sits in a
template the boundary already held. Which events they are has not been measured, so nothing is concluded from the gap here; it is recorded
under Open questions as the first thing a results check in this sport has to settle.

**`501 Medal` is identical inside the boundary and sport-wide** - 708 rows over 469 events in
both - so every medal the database holds for handball belongs to a competition the client
takes. Its three values are not balanced: 239 `gold`, 239 `silver` and 230 `bronze`. Nine
medal sets are missing their bronze, and that is a question rather than a finding until
somebody looks at which nine.

**`668 Event outcome` is symmetric inside the boundary**: 1301 `won` against 1301 `lost`, plus
234 `draw` rows over 117 events, which is two rows per drawn event as it should be. Sport-wide
the same type reads 47933 `won` against 47934 `lost`, so exactly one event outside the client's
boundary carries a loser with no winner.

<!-- MANUAL PASTE ZONE: 20 EVENT RESULTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Incident types

Thirteen active incident types inside the boundary, from `GLOBAL-DISCOVERY-008` narrowed.
The `incident_code` groups them into three families - `goal`, `card` and `assist` - and the
card family is where handball differs from the other team sports in the package.

| incident_typeFK | Name | Code | Rows | Events |
|---:|---|---|---:|---:|
| 7 | Regular goal | goal | 91733 | 1855 |
| 34 | Assist | assist | 46050 | 1701 |
| 23 | 2 min suspension | card | 27615 | 3697 |
| 14 | Yellow card | card | 14285 | 3289 |
| 8 | Penalty | goal | 10645 | 1840 |
| 9 | Missed penalty | goal | 3436 | 1523 |
| 30 | Exclusion | card | 515 | 462 |
| 18 | Extratime Goal | goal | 234 | 25 |
| 12 | Penalty shootout scored | goal | 58 | 7 |
| 29 | Disqualification | card | 44 | 38 |
| 28 | Extratime penalty scored | goal | 37 | 22 |
| 11 | Penalty shootout missed | goal | 23 | 7 |
| 19 | Extratime missed penalty | goal | 7 | 5 |

**`23 2 min suspension` is a card in this sport and it is the commonest one**, ahead of
`14 Yellow card`; `30 Exclusion` and `29 Disqualification` complete the family. A check that
equates the card family with disciplinary dismissal would misread the suspension, which is a
temporary penalty a player returns from.

`16 Red card` exists sport-wide with 22 rows and reaches no event inside the boundary. As with
the unused lineup types, that is a data state rather than a structural absence.

**The incident layer is outside the client's scope and no check reads it.** Decided
2026-08-28: UK Sport does not take incident detail, so the inventory above is documentation
of what the sport stores rather than a population anybody audits. It is recorded in full
because the layer is real and another client may well want it - at which point this section
is the starting point rather than a fresh discovery run.

What it covers today, measured the same day: `7 Regular goal` reaches 1855 of the 13573
events, 13.7 per cent. **Adding `11108` and its 813 events changed not one incident count**,
so that template's matches carry no incident detail whatever. Neither figure is a defect
under the current client and neither is `Not applicable`: the structure is present and
populated, and it is the scope that excludes it. Whether the rest were never collected or were collected elsewhere has not been
measured.

<!-- MANUAL PASTE ZONE: 20 INCIDENTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Scope types and data types

Two scope types inside the boundary, both of them extra time:

| scope_typeFK | Name | Containers | Events |
|---:|---|---:|---:|
| 460 | extra_time_first_time | 77 | 77 |
| 461 | extra_time_second_time | 73 | 73 |

One storage layer under them, `scope_result`, holding a single data type - `162 goals`, 147
values over 75 containers in the first period of extra time and 139 over 71 in the second.

**Sport-wide the layer is wider than that and the difference is scope, not structure.**
`351 aggregate_score` carries 196 containers with `27 final_result` and `262 final_outcome`
under `scope_result`, and `ref_eventFK` under `event_scope_detail` - the only use of that
second layer in the sport. Not one of those containers belongs to a template the client takes,
because aggregate scores are how two-legged club ties are stored. The layer and both its
storage paths therefore exist in handball and a check reading them stays applicable; it simply
has no eligible population inside this boundary today.

<!-- MANUAL PASTE ZONE: 20 SCOPES — insert approved additions immediately before this marker; do not move or delete it. -->

## Properties

Thirty property rows inside the boundary, from `GLOBAL-DISCOVERY-011` narrowed, over four
owners. Two are `ref:participant` and the rest are `metadata`.

`event` carries 18 metadata names. `Live` reaches all 13573 events and `Round` reaches 13540.
`GameEnded` is on 13336 and `GameStarted` on 4910, so more than half the events record an end
without a start. `FirstHalfEnded` (2688), `SecondHalfStarted` (2724) and `SecondHalfEnded`
(6007) are the timing trail; `ElapsedTime` is on 1837. `Verified` is on 3845, `Spectators` on
1830, `VenueName` on 1855, `VenueNeutral` on 1160, `LineupConfirmed` on 1137, `RefereeName` on
395, `medal_related` on 459, `StartTimeToBeDecided` on 158, and `BestOf`/`BestOfNum` on 16 each.

`event` also carries **two `ref:participant` properties, `refereeFK` and `second_refereeFK`,
on 1702 events each**. This is a fourth path from an event to a person, alongside the event
participant, the lineup and the Comp.Rank, and any check asking whether a registered person is
used in this sport has to read it. Handball stores two referees where Ice Hockey stores one.

`event_participants` carries `AwardedWinner` on 30 rows, which is the marker behind the
`190 Finished after awarded win` status. `participant` carries `IsNationalTeam` and
`ToBeDecided` on 646 rows each. `tournament_stage` carries `Cup`, `Live` and `Ranking` on all
1984 stages, `International` and `Note` on 323, `promotion_reference` on 44 and `StatusComment`
on 4.

Sport-wide the event owner carries one more name that no in-boundary event uses, `discipline`,
and the `participant` owner two more, `HomePage` and `status`.

<!-- MANUAL PASTE ZONE: 20 PROPERTIES — insert approved additions immediately before this marker; do not move or delete it. -->

## Generic relations and disciplines

Recorded under Tables and relation paths above, because the six `object_relation` pairs and
the single discipline are the same evidence read two ways. Nothing further is confirmed here.

<!-- MANUAL PASTE ZONE: 20 GENERIC RELATIONS AND DISCIPLINES — insert approved additions immediately before this marker; do not move or delete it. -->

## Statistics

| statistic_typeFK | Owner type | Participant shard | Data shard | Fields/config | Evidence |
|---:|---:|---:|---:|---|---|
| 11 | 3 `tournament` | 11 | 11 | data `1270 Rank`, `1277 Medal`, `1429 Team`; config `1463 Start date`, `1464 End date`, `1470 Gender`, `1471 Event id` | `GLOBAL-DISCOVERY-015`, `-016`, `-017`, `-030`, `-031` sport-wide, 2026-08-28 |

Every figure in this section is **sport-wide**. The statistics statements carry no template
filter, so `-TemplateIds` cannot reach them and the client boundary does not apply to what
follows.

Comp.Rank (`statistic_typeFK = 11`, called Comp.Rank in this project) is owned by the
**tournament** on 464 statistics. A single further statistic sits at `tournament_stage` level
and is not what the sport documents itself on. Three other statistic types exist under the
sport at tournament level and none of them is Comp.Rank: `1 Player Stats` 54,
`4 Player Stats Extended` 54, `6 Fun Facts Stats` 51.

**Three of the 42 declared data field types carry values**, confirmed by
`GLOBAL-DISCOVERY-031`:

| statistic_data_typeFK | Name | Values | Statistics | Value shapes |
|---:|---|---:|---:|---|
| 1429 | Team | 20746 | 65 | integer participant ids |
| 1270 | Rank | 5088 | 393 | integer |
| 1277 | Medal | 1018 | 343 | `gold` 343, `silver` 342, `bronze` 333 |

`GLOBAL-DISCOVERY-028` and `-029` were run over all three and returned one value pattern for
`Rank` and for `Team` and exactly three for `Medal`, so this is coverage of the layer rather
than a sample. The other 39 declared types are declared and unused.

The split between the two groups is the sport's own naming: statistics named
`... - Competition Rank` carry `Rank` and `Medal` at team level, and the 65 named
`... - Competition Rank (athletes)` carry `Team` - the athlete's team id - which is why one
field spans four times the values over a sixth of the statistics.

**Six of the 464 statistics hold no participants on the shard**, one of which is the row named
`test`. `GLOBAL-DISCOVERY-024`/`-025` were run to full coverage over all 39 name patterns:
197 statistics carry the generic name `Competition Stats` rather than naming their tournament,
and the remaining 266 follow `<Tournament> <Gender> <Year> - Competition Rank`, with the
casing of the athletes suffix varying between `(athletes)`, `(Athletes)` and a form written
without the preceding space.

**No athlete ranking carries a place.** Measured 2026-08-28: the 65 statistics named
`... - Competition Rank (athletes)` carry `1429 Team` and nothing else, the 393 carrying
`1270 Rank` are all team-level, and the overlap between the two sets is exactly zero. An
athlete ranking in handball is a squad list with each player's team id, not a ranking of
athletes. This is why `Handball-DQ-032` (`GLOBAL-DQ-143`) audits nothing: it compares an
athlete ranking's places against its team twin's, and one side has no places to compare.

<!-- MANUAL PASTE ZONE: 20 STATISTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## DQ checks

Three categories were opened on 2026-08-28 - `1 Structure` (`WRONG_STRUCTURE`,
`NO_RELATED_RECORDS`), `2 Wrong value` (`WRONG_RESULTS`, `WRONG_GENDER`, `WRONG_DISCIPLINE`,
`DATE_RANGE_MISMATCH`, `MALFORMED_NAME`, `DUPLICATE_RECORD`) and `3 Missing value`
(`MISSING_VALUES`) - and 83 checks were approved as `Handball-DQ-001` to `Handball-DQ-083`.

**The fourth band is not a category anybody opens.** `4 Patterns` carries no DQ template at
all: `POWERBI.md` records it as the band for the `PATTERNS.sql` discovery summaries the runner
injects on its own, whose rows are a census of how something is spelled rather than things to
correct. There is nothing to approve there, and saying so is better than leaving the band
looking unfinished. Every one is a registry row
whose `Family` names a GLOBAL template; no sport statement was authored, because no approved
condition needed one. `POWERBI_REGISTRY.md` holds the rows and `GLOBAL_DQ/README.md` the
templates.

All 117 templates in the two bands were matched against the sport's recorded parameters;
55 could be instantiated and were profiled against the client boundary before anything was
numbered. What the 53 are made of:

| Group | Count | What they are |
|---|---:|---|
| Clean signal, small volume | 16 | Findings between 1 and 126 rows over a populated scope. Four of them audit questions this file already raises: `GLOBAL-DQ-001` reports `9610`, `-010` reports the `test` statistic, `-050` reports the `Bronze Match` spelling, `-103` reports duplicated ranking participants |
| Zero findings, populated scope | 28 | Clean today over 22 to 26146 audited objects. Approved on the invariant they guard rather than on today's count, while the colleagues are correcting data |
| Large, read before numbering | 4 | `GLOBAL-DQ-058` 9555 of 13098, `-068` 1833 of 3544, `-065` 61 of 66, `-096` 215 of 13098 |
| Sentinels, `eligible_count = 0` | 6 | `GLOBAL-DQ-066`, `-067`, `-098`, `-109`, `-132`, `-143` |
| Band 3, clean signal or clean today | 14 | `GLOBAL-DQ-002`, `-005`, `-006`, `-008`, `-011`, `-013`, `-015`, `-016`, `-022`, `-023`, `-038`, `-064`, `-069`, `-070` |
| Band 3, large share, approved knowingly | 6 | `GLOBAL-DQ-007` 2929 of 27782, `-026` 121 of 332, `-032` 65 of 327, `-033` 327 of 327, `-074` 11252 of 13098, `-130` 13098 of 13098 |

**The five sentinels are a correct scope over a population that is empty today, not a
misdirected one.** `POWERBI.md` owns that distinction and it was settled per check:
`-066` and `-067` read mixed-gender teams, which handball does not field; `-109` reads the
`discipline` event property, which no in-boundary event carries; `-132` reads
`organizationFK`, which `GLOBAL-DQ-130` measures as absent on every participation; and
`-143` is explained under Statistics above. None of them is `Not applicable`: the structure
is present in every case and the check revives on the day rows appear.

**`GLOBAL-DQ-049 EVENT_NAME_FORMAT_INVALID` was read and rejected on 2026-08-28.** It reports
every event name in the boundary - every single one - and the only violation it raises is
`HYPHEN_WITHOUT_SPACES`: handball writes `Denmark-Norway` where the rule expects
`Denmark - Norway`. The template's own applicability note warns that a sport whose names
follow another convention will report its whole vocabulary, and that is what happened. This
is the sport's naming convention rather than a defect, so no CheckID was assigned. It would
become a real check only if the colleagues decided to change the convention.

**Band 3 was opened the same day and its six large findings were approved with their numbers
read rather than in spite of them.** Four of them describe a layer this sport does not fill at
all, and that is the finding: `GLOBAL-DQ-130` reports every one of the 13098 event
participations as missing an organization, `-074` reports 11252 of 13098 events with no venue,
`-033` reports all 327 Comp.Rank statistics as carrying no phase, and `-026` reports 121 of 332
with an invalid medal set. `GLOBAL-DQ-130`'s own catalogue row settles how to read the first:
an unfilled organization is a defect and never a reason to record the check as `Not applicable`
or `Monitor`.

Two of the six are narrower and already explained by what this file records elsewhere.
`GLOBAL-DQ-032` reports 65 of 327 Comp.Rank statistics as holding no rank for their
participants - those are exactly the 65 `(athletes)` rankings, which carry `1429 Team` and no
`1270 Rank`, the same fact that makes `Handball-DQ-032` a sentinel. And `GLOBAL-DQ-007` reports
2929 of 27782 registered athletes with no date of birth, 10.5 per cent, which is the figure the
duplicate work of `Handball-DQ-059` depends on: a date of birth is what separates a duplicate
from a namesake.

**`GLOBAL-DQ-006 EVENT_MISSING_ROUND_TYPE` reports exactly the 85 events whose `round_typeFK`
is `0`**, closing the loop opened under Event and round representation. Removing `0` from
`ROUND_TYPE_LIST` did not put them on a board, because `GLOBAL-DQ-075` inner-joins `round_type`
and a dangling key never reaches it; this is the check that does, and it is `Handball-DQ-065`.

**Five checks were written from the rules of handball itself, on 2026-08-28.** They came from
reading the data rather than the catalogue: eight finished events were sampled from every one
of the 45 round types the boundary uses, and the sport's own arithmetic was read off them - a
bronze match at 26:26 after ordinary time, 7:5 in extra time and 33:31 final, and everywhere
else Final Result equal to Ordinary time exactly. Each of the five asserts something the rules
of the game make true and no GLOBAL template asks:

| Check | Rule it asserts | Findings |
|---|---|---:|
| `Handball-DQ-110` | Final Result is Ordinary time plus Extra time, and nothing else | 74 |
| `Handball-DQ-111` | A penalty shootout cannot happen without extra time before it | 56 |
| `Handball-DQ-112` | A knockout tie cannot end level - the round exists to send one team home | 3 |
| `Handball-DQ-113` | A team cannot hold more goals at half time than at the end of ordinary time | 1 |
| `Handball-DQ-114` | The Event outcome word agrees with the Final Result | 0 |

`-113` is the strongest invariant the result layer has here: goals are not taken away, so no
format, rule change or competition can produce an exception. It finds one event, and that is
the point rather than an objection - it costs almost nothing to run and a rise in it means the
half-time and full-time fields have been crossed.

`-114` returns nothing and was approved on that basis rather than despite it. `668 Event
outcome` is written by a different path from `4 Final Result`, on 1418 events against 13375,
and the two agree everywhere today; a redundant field that has never disagreed is exactly the
one that drifts unnoticed once it does. `GLOBAL-DQ-088` asks the same question of the `Winner`
property, which this sport does not store at all, so without this statement the question would
go unasked.

`-112` is deliberately narrower than `Handball-DQ-090` (`GLOBAL-DQ-084`), which reports every
tie in the sport - 532 of them, and 528 are group-stage matches handball allows to end level.
Reading that census is what surfaced the 3 that break a rule, and both are kept: one is the
count of ties, the other is the ties that should not exist.

**Two templates were run, read and deliberately not numbered, both for the same reason: they
read the scope layer as something handball does not use it for.** `GLOBAL-DQ-085
EVENT_SCOPE_PERIOD_SUM_MISMATCH_TOTAL` sums a match's periods against its total and returned
147 findings of 147 eligible, every one `TOTAL_ABOVE_PERIOD_SUM`. That is arithmetic working
correctly on the wrong structure: this sport's only scope containers are `460` and `461`, the
two halves of EXTRA time, so what they hold is an addition to the ordinary-time score rather
than a decomposition of the final one. `GLOBAL-DQ-107
EVENT_SCOPE_CONTAINER_MISSING_FOR_FINISHED` asserts that a finished event has a container at
all and returned 12823 of 12900 - because only 77 matches in the boundary went to extra time.
Neither is recorded as a parameter being not applicable, because no parameter is: both ran on
the values this sport records. They are simply questions this sport's storage does not answer,
and `Handball-DQ-104` and `-105` audit the same two containers on questions it does.

**One classification was made, measured and reversed the same day.**
`ELIMINATION_ROUND_NAME_LIST` was first written with the final and the bronze match in the
GROUP list - the reading Track Cycling uses, where a final ranks a whole field and eliminates
nobody. `GLOBAL-DQ-097` and `-118` immediately reported 2 and 490
`NON_ELIMINATION_ROUND_MARKED_KNOCKOUT`, because the database marks both rounds as knockout and
is right to: in a handball tournament the loser of the final and the loser of the bronze match
each go out of the contest that round decides. Moving both into the elimination list took the
two checks to **0 findings**, which is what a correct classification looks like. The 490 were
never a defect in the data; they were the parameter disagreeing with it, and the sport file
records that because the next reader will otherwise re-derive it.

**Three templates were profiled last, because they only became runnable partway through.**
`GLOBAL-DQ-040`, `-042` and `-138` want `FINAL_ROUND_TYPE_LIST` and `MEDAL_ROUND_TYPE_LIST`,
which were not recorded when bands 1 and 2 were first swept and were added later while
answering the open questions. Re-counting what the sport can run against what it has caught
them; they are `Handball-DQ-084` to `-086`. The lesson is worth keeping: recording a parameter
unblocks templates that an earlier sweep has already passed over, so the count is re-derived
after parameters change rather than assumed to be settled.

`GLOBAL-DQ-040` is the substantial one, 178 of 254 finals, and 175 of those 178 are a single
shape - `COMP.RANK_EVENT_SCOPE_UNDETERMINABLE`. They do not say a final has no ranking; they say
which ranking covers which event cannot be determined, because the phase is absent on all 327
statistics and `1471 Event id` is present on only 79. `Handball-DQ-075` reports that same gap
from the statistic's side, and these two are deliberately not one check: the audited object is
the event here and the statistic there, and a correction made on one does not clear the other.
Only 3 of the 178 are a tournament genuinely holding no Comp.Rank at all.

**Five band-3 templates stay blocked**, each on a parameter this opening did not confirm:
`GLOBAL-DQ-034` and `-035` want `PLACEHOLDER_COUNTRY_LIST`, `-037` wants `RESULT_RANK_TYPE_ID`
(this sport stores no rank on an event result at all, so that one is likely structural rather
than unmeasured), `-087` wants `WINNER_VALUE_LIST`, and `-131` wants
`DATA_ORGANIZATION_TYPE_ID`.

**Nine checks are the sport's own statements rather than instantiated templates**, written
2026-08-28 as the two categories were worked: `Handball-DQ-059` (a person the registry holds
twice), `-060` (a registry row whose role contradicts the participant's type), `-061` (a stage
abbreviating a group as `Gr.` where the sport writes `Grp.`) and `-062` (a Comp.Rank whose squad
sizes differ by four or more). Each exists because no GLOBAL template asks that question, and
each says so in its own text.

**`Handball-DQ-062` is the first statement in the package to use the excluding form of the
client boundary**, and it forced a package rule to change. The including form the rule requires
does not execute here at all - five rewrites timed out at the gateway, and the same filter
written as the complement returns in 14.3 seconds. `TOOLS/README.md` now records the exception,
`TOOLS/Test-Package.ps1` enforces what can still be enforced, and the statement carries a
standing obligation in its own comment: **when this sport's boundary changes, that statement's
excluded list must change with it or it silently widens.**

**`GLOBAL-DQ-134 COMP.RANK_RESULTS_RANK_SEQUENCE_BROKEN` could not be run** and is not
numbered: it needs `COMP_RANK_ENTRY_SIZE_LIST`, which is not recorded for this sport. The
62 remaining templates in the two bands are blocked the same way, each on a parameter this
opening did not confirm.

## Reference values

From `GLOBAL-DISCOVERY-014` narrowed over all 1984 stages in the boundary.

| Reference | Stages carrying it | Values |
|---|---:|---|
| `direct_country` | 1984 of 1984 | `International` 1961, `Czechia` 10, `South Korea` 7, `North Macedonia` 6 |
| `tournament_age_class` | 1983 of 1984 | `SENIOR` 1100, `JUNIOR` 499, `YOUTH` 384 |
| host country relation | 1710 of 1984 | 68 distinct countries |
| city link | 0 of 1984 | the layer is unused in this boundary |

**The direct country is a placeholder on all but 23 stages.** `International` is the value on
1961 of them, which is what a national-team competition should carry; 10 name Czechia, 7 South
Korea and 6 North Macedonia. Judged 2026-08-28 not to be a question worth carrying - 23 of
1984 - and closed rather than left open. `DATABASE.md` treats `International` as a placeholder
country, so a check reading the direct country here reads a constant.

**One stage of 1984 carries no age class.** Every other stage carries exactly one of three, and
the split is the competition level: senior, junior and youth.

<!-- MANUAL PASTE ZONE: 20 REFERENCE VALUES — insert approved additions immediately before this marker; do not move or delete it. -->

## Event and round representation

**46 round types inside the boundary, read to full coverage.** `GLOBAL-DISCOVERY-018`
narrowed returned all 46 and `-019` was run for every one of them, reaching all 13573 events.
This is coverage, not a sample.

29 of the 46 carry a name that says what the round is - `2 Semi Finals`, `3 Quarter Finals`,
`9 Final`, `4 1/8`, `138 bronze`, and a placement family running from `22 5/6` through
`206 29/32`.

**17 carry a name that is only a number, and the numbers repeat across two parallel ranges.**
Ids `38` to `43` are named `1` to `6` and hold the bulk of the boundary - 2974, 2717, 2280,
749, 677 and 28 events. Ids `89` to `103` are named `1`, `2`, `3`, `4`, `5`, `6`, `7`, `9`,
`11`, `13` and `15` and hold between 1 and 52 events each. Six names - `1` through `6` - are
therefore carried by two different round type ids each. Any check or report keying on the round
name rather than the id will merge them.

**`round_typeFK = 0` is in use on 85 events and its name is empty.** It is not a gap in the
inventory; it is a real value those events carry.

Stage names: `GLOBAL-DISCOVERY-022`/`-023` narrowed were run to full coverage over all 200
digit-normalized patterns, reaching all 1984 stages. The patterns are competition-and-phase
names such as `European Championship U# Main Round Grp. #` (67 stages) and
`European Championships Qualification grp. #`. **The abbreviation for a group is spelled three
ways** - `Grp.`, `grp.` and `Gr.` - with `World Championships Gr. E`,
`World Championships grp. E` and their `Grp.` siblings sitting in the inventory as separate
patterns.

Event names: `GLOBAL-DISCOVERY-020` narrowed returns **4666 patterns over 13573 events**, and
`-021` was run for the 8 the summary ranks first, which is a sample and is recorded as one.
The shape those 8 show is `Team-Team` for senior events and `Team U#-Team U#` for age-group
events; the remaining 4658 patterns are unread and no claim is made about them.

<!-- MANUAL PASTE ZONE: 20 EVENT AND ROUND REPRESENTATION — insert approved additions immediately before this marker; do not move or delete it. -->

## Confirmed sport-specific storage semantics

Nothing beyond what the sections above state as confirmed. The sport's storage is the
package's ordinary team-sport shape: a four-layer hierarchy, two team participants per event,
the score in `event_results`, the match detail in `event_incidents`, extra time in the scope
layer, and Comp.Rank on the tournament in shard 11.

Two things are specific to handball and are stated where they belong rather than repeated
here: `23 2 min suspension` is a card, and `6 Unknown` is the busiest lineup type.

<!-- MANUAL PASTE ZONE: 20 STORAGE SEMANTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Open questions

Ordered by what a check would have to settle first. None of these is a defect anybody here
has classified; each is a measurement or a decision that has not been made.

1. **`9610 World Championship U18` male is in the client boundary and holds nothing.** Its
   female counterpart holds 724 events. Are the male editions stored under another template,
   or absent from the database?
2. **198 events in the boundary hold no `4 Final Result` and 88 hold no `1 Ordinary time`,**
   while `6 Running score` reaches all 13573. Both counts were identical before `11108` was
   added, so none of them is in that template. Which events those are has not been measured,
   and the answer decides how a results check is scoped here.
3. **Nine medal sets are missing their bronze** - 239 `gold`, 239 `silver`, 230 `bronze` on
   `501 Medal`, every one of them inside the boundary.
4. **`round_typeFK = 0` on 85 events, with an empty name**, and six round names carried by two
   different round type ids each.
5. **30 registered athletes hold more than one registry row under the same name.**
6. ~~95 registry rows disagree between the role and the participant type.~~ **Answered
   2026-08-28: the count is 100, and it is now `Handball-DQ-060` rather than an open question.**
7. **The group abbreviation is spelled `Grp.`, `grp.` and `Gr.`** across stage names.
8. ~~The incident layer reaches 1855 of 13573 events.~~ **Closed 2026-08-28: the incident
   layer is outside UK Sport's scope, so its coverage is not a question for this client.**
   Revisit when the package serves a client who takes it. Whether the rest were never collected
   has not been measured.

Not checked, and deliberately so:

- `GLOBAL-DISCOVERY-027` for result types `1`, `4`, `5`, `6` and `668`. Sport-wide it fails
  with the server's memory exhausted at 186378 events, and narrowed the chain cannot fill it
  from any single summary. It completed for `501 Medal`, where the two scopes are identical.
- `GLOBAL-DISCOVERY-021` beyond 8 of 4666 event name patterns.

Seen sport-wide and outside the client boundary, recorded so nobody re-derives them:

- Statistic `145449` is named `test`, holds no participants, and is the lowest-id Comp.Rank
  statistic of the sport - which is why the runner's automatic shard probe reported no shard.
- 197 Comp.Rank statistics carry the generic name `Competition Stats`.
- `1270 Rank` holds at least one zero-padded value, `09`.
- `668 Event outcome` reads 47933 `won` against 47934 `lost` sport-wide: one event has a loser
  and no winner.
- The `RefereeName` event property sometimes holds a number instead of a name.
- Two `2 Extra time` result values are empty on one event.

Raised by the DQ work of 2026-08-28 and not yet answered:

10. ~~Should `GLOBAL-DQ-058` findings be worked or accepted?~~ **Answered 2026-08-28: the
    lineup layer stays in scope and `Handball-DQ-005` is recorded as `Monitor`.** 9555 of
    13098 team participations carry no lineup, all of the same kind and running from 2004
    forward, so the number is a coverage indicator rather than a work list - a RISE in it is
    the question. The layer stays in scope, unlike the incident layer, because a team is the
    only kind of event participant this sport enters and the lineup is the only path from an
    event to a person.
11. ~~`GLOBAL-DQ-065` reports 61 of 66 Comp.Rank statistics.~~ **Answered 2026-08-28 by
    writing `Handball-DQ-062`, which asks the same question at the threshold this sport
    needs.** A handball squad is not a fixed number - the rules have allowed 14, 15 and 16 -
    so teams differing by one, two or three players are the sport behaving normally. The gap
    distribution splits cleanly: 12 statistics differ by 1, 13 by 2, 13 by 3, and then 22
    differ by 4 or more, up to a gap of 22 in `World Championship U21 Male 2025` (6 against
    28) and a squad of ONE athlete against 15 in `Summer Olympics Female 2008`. `-062`
    reports those 22; `Handball-DQ-026` keeps the general question and its 61.

<!-- MANUAL PASTE ZONE: 20 OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
