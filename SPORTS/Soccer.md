# SPORT: Soccer (sport_id=1)

This file is the canonical structural record for Soccer. It contains only confirmed
sport-specific usage, meanings, identifiers, evidence boundaries and open structural
questions. Global database mechanisms belong in `../DATABASE.md`.

For additions, insert approved content immediately before the exact active
`MANUAL PASTE ZONE` marker in the destination subsection. Keep the marker unchanged
and at the end of its subsection. Replace existing rows or paragraphs in place when a
correction is required.

## Identity and evidence

- First discovery date: 2026-08-05
- Latest evidence date: 2026-08-05
- Verification boundary: **Soccer is documented within a client scope, not across the sport.**
  Everything below that concerns the competition hierarchy, event participants, results,
  incidents, lineups, round types, disciplines and the scope layer was confirmed over the
  28 tournament templates named under Scope below, and describes those templates rather than
  the sport. The registry, property, `object_relation`, `object_discipline` and statistic
  layers were confirmed sport-wide, because the discovery statements that read them carry no
  template relation to narrow on. Each area's row below records which of the two it is.
  Properties are covered for the `event` owner only, measured inside the scope by a statement
  written for the purpose after `GLOBAL-DISCOVERY-011` proved unable to complete against the
  whole sport; the `tournament_stage` and `participant` owners remain `Not checked`.

## Scope

Soccer is the first documented sport whose client scope is narrower than the sport. The
database carries the sport's full league population; the client's interest is a fixed set of
28 `tournament_template` rows, and every narrowed statement is run with `-TemplateIds` over
exactly those:

| Competition | Templates |
|---|---|
| World Championship | 76, 77 |
| European Championship | 50, 292 |
| European Championship U21 | 288 |
| European Championship U19 | 287, 9377 |
| European Championship U17 | 301, 9379 |
| Copa America | 44, 10368 |
| Africa Cup of Nations | 289, 10371 |
| African Nations Championship | 9428 |
| CAF Confederations Cup | 9468 |
| Asian Cup | 290, 10269 |
| Asian Games | 9833, 11241 |
| OFC Nations Cup | 11243, 11244 |
| Pan American Games | 11245, 11246 |
| Algarve Cup | 9579 |
| Summer Olympics | 65, 66 |
| Summer Youth Olympics | 11185, 11186 |

Most competitions occupy two templates, one per gender; `288`, `9428` and `9468` are male
only and `9579` female only, matching competitions that exist for one gender.

**`9468` CAF Confederations Cup is a club competition and is in scope deliberately.** Its
event participants are clubs where every other template in the set carries national teams, so
any check that assumes one kind of entity throughout the scope will meet both. It is also the
only template in the set that carries no Comp.Rank statistic, which places it outside the
eligible population of every statistic check rather than inside it with no findings.

A narrowed check's `eligible_count` is therefore read against these templates. A count far
below the sport's own population is the scope working, not a misdirected scope.

<!-- MANUAL PASTE ZONE: 1 SCOPE — insert approved additions immediately before this marker; do not move or delete it. -->

## Structural coverage

| Area | Status | Evidence |
|---|---|---|
| Core hierarchy | Used | `GLOBAL-DISCOVERY-002`, `-003` (scope) |
| Event participants | Used | `GLOBAL-DISCOVERY-004` (scope), `-006` (sport-wide) |
| Event results | Used | `GLOBAL-DISCOVERY-007`, `-026` (scope) |
| Incidents | Used | `GLOBAL-DISCOVERY-008` (scope) |
| Lineups | Used | `GLOBAL-DISCOVERY-005` (scope) |
| Scope layer | Used | `GLOBAL-DISCOVERY-009` (scope), `-010` (sport-wide) |
| Properties | Used for the `event` owner (scope); other owners `Not checked` | `GLOBAL-DISCOVERY-011` failed on server temporary storage and is not narrowable; the event owner was measured separately |
| object_relation | Used | `GLOBAL-DISCOVERY-012` (sport-wide) |
| object_discipline | Used | `GLOBAL-DISCOVERY-013` (sport-wide) |
| Statistics | Used | `GLOBAL-DISCOVERY-015`, `-016`, `-017`, `-028` (sport-wide) |
| Reference values | Used | `GLOBAL-DISCOVERY-030`, `-031` (sport-wide) |
| Other tables | Not checked | |

## Tables and relation paths used

Core hierarchy through `tournament_template.sportFK=1` → `tournament` → `tournament_stage` →
`event`; event participants via `event_participants`; results via `result`; incidents via
`incident`; lineups via `lineup` on `event_participants`; the scope layer via `event_scope`,
`event_scope_detail` and `scope_result`; disciplines via `object_discipline` on owner types 5
(event) and 83 (statistic); statistics via `statistic` (`object_typeFK=3`) →
`statistic_participants11` → `statistic_data11`, with `statistic_config` for statistic-level
metadata.

`object_relation` carries the template-to-subset pair `2 → 152`, a template-to-city pair
`2 → 33`, stage-level host country `4 → 33` and age class `4 → 151`, a stage-to-stage pair
`4 → 4`, and the statistic-level pairs `83 → 33` and `83 → 151`.

<!-- MANUAL PASTE ZONE: 1 TABLES AND RELATIONS — insert approved additions immediately before this marker; do not move or delete it. -->

## Participant and lineup structure

Event participants are teams only, male and female, and **every event in scope holds exactly
two of them**. No `athlete` participant reaches the event layer directly. With no event-level
rank result type populated either, both conditions `DB-SEM-015` states for `H2H` hold, and the
sport is recorded as `H2H (team)` on that measurement rather than by judgement.

The sport-level registry (`object_participants`, object='sport', objectFK=1) is wider than the
event layer and wider than any sport documented before it: it carries `athlete`, `team`,
`coach` and `official` roles, each with active and inactive rows, and `official` occurs in no
other documented sport.

**The registry role and the participant's own type disagree.** `op.participant_type` and
`p.type` are independent fields here, and rows exist in both directions — a registry row
filed under the `athlete` role whose participant is of type `coach`, and the reverse. The
disagreement is a property of how the two fields are populated, not of any one row, so a check
reading a person's role from either field alone will describe a different population depending
on which it picks.

Lineups are this sport's membership mechanism and are richly typed: `Goalkeeper`, `Defence`,
`Midfield`, `Forward`, `Substitute player`, `Starter` and `Coach` all attach members to a
`team` event participant. Members are of type `athlete` and of type `coach`.

**Coaches occupy playing lineup types.** `coach` members appear under `Substitute player` and
`Midfield`, not only under the `Coach` lineup type. A check that infers a person's role from
the lineup type they occupy will therefore be wrong for this sport, and a check that infers it
from `participant.type` disagrees with the registry as described above.

<!-- MANUAL PASTE ZONE: 1 PARTICIPANTS AND LINEUPS — insert approved additions immediately before this marker; do not move or delete it. -->

## Event result types

| result_code | result_typeFK | Value shape | Confirmed meaning | Evidence |
|---|---:|---|---|---|
| `ordinarytime` | 1 | Numeric | Score at the end of ordinary time | `GLOBAL-DISCOVERY-007` |
| `extratime` | 2 | Numeric | Score in extra time | `GLOBAL-DISCOVERY-007` |
| `penaltyshootout` | 3 | Numeric | Penalty shootout score | `GLOBAL-DISCOVERY-007` |
| `finalresult` | 4 | Numeric | The deciding score of the pairing | `GLOBAL-DISCOVERY-007`, `-026` |
| `halftime` | 5 | Numeric | Score at half time | `GLOBAL-DISCOVERY-007` |
| `runningscore` | 6 | Numeric | The pairing's score carried on the opposing side | `GLOBAL-DISCOVERY-007`, `-026` |
| `medal` | 501 | Medal code | Medal awarded to the participant | `GLOBAL-DISCOVERY-007` |
| `finaloutcome` | 549 | Text | Won or lost, as a word | `GLOBAL-DISCOVERY-007` |
| `overallscore` | 550 | Numeric | Score across both legs of a tie | `GLOBAL-DISCOVERY-007` |

`4` and `6` are the confirmed final-score and mirror-score pair, verified by value pattern:
both carry a bare integer and nothing else, and `6` is present on every event in scope where
`4` is present on slightly fewer. The sport stores **no Rank, no Comment and no Duration
result type** — the pairing is the classification and the match is a fixed length, so neither
a place nor a status vocabulary nor an elapsed time has anywhere to sit.

<!-- MANUAL PASTE ZONE: 1 EVENT RESULTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Incident types

Soccer is the first documented sport with a populated incident layer. Confirmed types, by
`incident_code`:

- `goal` — `7` Regular goal, `8` Penalty, `9` Missed penalty, `10` Own goal,
  `11` Penalty shootout missed, `12` Penalty shootout scored, `18` Extratime Goal,
  `19` Extratime missed penalty, `28` Extratime penalty scored, `41` Extratime own goal,
  `33` Cancelled Goal, `61` Cancelled missed penalty, `62` Cancelled penalty
- `card` — `14` Yellow card, `15` Yellow card 2, `16` Red card, `60` Cancelled Card,
  `70` Cancelled Yellow Card
- `subst` — `20` Substitution out; `subst_in` — `32` Substitution in
- `assist` — `34` Assist

Two properties of this vocabulary matter to any check that reads it. **A cancelled incident is
its own type rather than a flag**, so `Cancelled Goal` and `Regular goal` are separate rows and
a naive goal count includes retractions unless the cancelled types are excluded. And
**a substitution is stored as two types**, `Substitution out` and `Substitution in`, so the two
sides of one substitution are separate rows that a per-incident count treats as two events.

<!-- MANUAL PASTE ZONE: 1 INCIDENTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Scope types and data types

The sport uses exactly one scope type, `351 aggregate_score`, and it is not a period layer.
It holds the aggregate of a two-legged tie: `event_scope_detail` carries `ref_eventFK` linking
the container to the other leg, and `scope_result` carries `27 final_result` and
`262 final_outcome` beneath it.

This is a different use of the scope layer from any sport documented before. Curling's scope
containers hold period-by-period scores that sum to a total; Soccer's hold one tie assembled
from two separate events. A check written for period storage reads a structure this sport does
not maintain, and a check written for aggregate ties reads one Curling does not.

<!-- MANUAL PASTE ZONE: 1 SCOPES — insert approved additions immediately before this marker; do not move or delete it. -->

## Properties

`GLOBAL-DISCOVERY-011` reads every property owner at once, carries no template filter, and
against the whole sport exhausts the server's temporary storage rather than returning a
result. The **event** owner was therefore measured on its own, inside the scope, and is
documented here; `tournament_stage` and `participant` owners remain `Not checked`.

Events carry a wide property vocabulary. `Round` and `Live` sit on every event in scope.
Timing marks record the passage of the match — game and half start and end, and the same set
again for extra time. Match context arrives as `Spectators`, `VenueName`, `VenueNeutral`,
`ElapsedTime`, `BestOf` and `BestOfNum` for a tie played over two legs, and `medal_related`.
Production state is carried by `Verified`, `LineupConfirmed`, `Commentary`, `LiveStatsType`,
`LiveStatsPlus` and `SuperLive`.

**There is no `Winner` property.** Measured across every property name the scope uses, the
sport records no winning side on the event at all: the outcome lives on the result, as
`549 finaloutcome`. A check reading a `Winner` event property therefore reads a structure this
sport does not write, while the information it looks for is present one layer away.

**Match officials reach an event through properties, not through participation.** Properties
of type `ref:participant` carry `refereeFK`, `assistant1_refereeFK`, `assistant2_refereeFK`,
`fourth_refereeFK`, `var1_refereeFK` and `var2_refereeFK`, each naming a `participant`. This is
a fourth way of taking part in the sport, alongside the event participant row, the lineup place
and the Comp.Rank statistic, and no approved check reads it. It is why the registry's
`official` role appears to take no part in the sport when measured through the other three.

<!-- MANUAL PASTE ZONE: 1 PROPERTIES — insert approved additions immediately before this marker; do not move or delete it. -->

## Generic relations and disciplines

The sport contests a single discipline, `627 11aSide`, and attaches it to both events
(owner type 5) and statistics (owner type 83). Gender is carried by the tournament stage
rather than by the discipline, so the male and female programmes are the same discipline under
stages of different gender.

Tournament stages resolve their country through two independent paths: a direct
`tournament_stage.countryFK`, which in this scope commonly holds the placeholder value
`International`, and a host-country `object_relation 4 → 33` naming the actual host. Age class
arrives through `object_relation 4 → 151`. A check reading only the direct column will
therefore find a placeholder where the host is recorded elsewhere.

<!-- MANUAL PASTE ZONE: 1 GENERIC RELATIONS AND DISCIPLINES — insert approved additions immediately before this marker; do not move or delete it. -->

## Statistics

| statistic_typeFK | Owner type | Participant shard | Data shard | Fields/config | Evidence |
|---:|---:|---:|---:|---|---|
| 11 | 3 | `statistic_participants11` | `statistic_data11` | Rank `1270`, Medal `1277`, Team `1429`; config Start date `1463`, End date `1464`, Gender `1470` | `GLOBAL-DISCOVERY-015`, `-016`, `-017` |

Comp.Rank is confirmed on shard 11 from the shard statement's own result, not carried over
from the sports documented before. Its data layer holds a place, a medal and the team an
athlete competed for, and **no Comment, no Time and no Points field** — so this sport's
Comp.Rank has no status vocabulary and no measured quantity.

**`1429 Team` is populated here.** Soccer is the first documented sport to fill it, which
makes it the only confirmed case of the field the Triathlon record describes as unpopulated.

Soccer's statistic layer is far wider than Comp.Rank alone. Other active types sit at three
owner levels — tournament, tournament stage and event — and include `Player Stats`,
`Team Stats`, their Extended variants and `Fun Facts Stats`, with the largest populations at
event level. None of that layer is read by any approved check, and it is recorded here as
structure rather than as a candidate.

<!-- MANUAL PASTE ZONE: 1 STATISTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Reference values

Comp.Rank `1277 Medal` uses the standard `gold`, `silver`, `bronze` vocabulary and also occurs
with an empty value. `1270 Rank` carries a bare integer.

**An empty `1277 Medal` value is a written state, not an unwritten field.** Read against the
`1270 Rank` beside it, `gold`, `silver` and `bronze` accompany the first three places while the
empty value sits overwhelmingly at fourth place and worse. The field therefore distinguishes
three things and not two: a medal, a placing without a medal, and no Medal row at all. A check
treating an empty value as a missing one will report the sport's normal way of recording a
non-medallist.

<!-- MANUAL PASTE ZONE: 1 REFERENCE VALUES — insert approved additions immediately before this marker; do not move or delete it. -->

## Event and round representation

An event name is the pairing that plays it, written `Home-Away` with no spaces around the
hyphen. Across every distinct name pattern in scope the convention holds without exception:
no double spaces, no spaced hyphen, no name lacking a hyphen and no non-ASCII lookalike. The
name therefore carries nothing beyond which two participants take part, which is what
`DUPLICATE_KEY_INCLUDES_EVENT_NAME = 0` records. A generic name-format rule reading the hyphen
will describe this convention rather than find a defect in it.

Round types divide into three kinds:

- **Group matchdays** — `38`, `39`, `40`, `41`, `42`, `43` and `89`, whose names are the bare
  numbers `1` to `6`. The detail statement confirms these are matchdays inside a group stage,
  not rounds of a knockout.
- **Knockout rounds** — `5` (1/16), `4` (1/8), `3` Quarter Finals, `2` Semi Finals, `9` Final,
  `138` bronze and `305` Playoff.
- **Placement matches** — `22` (5/6), `23` (7/8), `24` (9/10), `25` (11/12) and `26` (5/8),
  which decide an order among competitors already eliminated. They are neither knockout nor
  group and belong in neither name list.

Gold and silver are decided in `9` Final and bronze in the separate `138` bronze match, so
the medal rounds are `9` and `138` while the final round alone is `9`.

Tournament stage names follow their competition, in the forms `World Cup grp. #`,
`EURO U# Grp. A`, `Women's EURO U# Final Stage` and `World Cup Bronze Match`.

<!-- MANUAL PASTE ZONE: 1 EVENT AND ROUND REPRESENTATION — insert approved additions immediately before this marker; do not move or delete it. -->

## Confirmed sport-specific storage semantics

- **The score result types are cumulative into `4 finalresult`, which equals
  `1 ordinarytime` + `2 extratime` + `3 penaltyshootout`.** The relation holds for every Final
  Result row in scope without exception, including the rows where extra time or the shootout is
  absent and contributes nothing. `5 halftime` is not a term in it: it is a snapshot taken
  during ordinary time, not a stage that adds to the total. Any check comparing one score type
  against another must use this relation rather than assume each type is an independent value.
- The pairing is the classification. There is no event-level rank and no `Winner` event
  property; the outcome is stored on the result as `549 finaloutcome`, carrying `won` and
  `lost`, and is additionally derivable from the two `finalresult` values.
- A match official takes part through an event property of type `ref:participant`, never
  through an event participant row, a lineup place or a statistic.
- A tie played over two legs is assembled in the scope layer under `351 aggregate_score`, with
  the second leg reached through `event_scope_detail.ref_eventFK`.
- A cancelled incident is a distinct incident type, not a flag on the original.
- A substitution occupies two incident rows, one out and one in.
- The registry role and `participant.type` are independent fields that disagree in both
  directions.

<!-- MANUAL PASTE ZONE: 1 STORAGE SEMANTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Open questions

- **How does `550 overallscore` relate to the `351 aggregate_score` scope layer?** Both record
  a two-legged tie, one as an event result and one as a scope container. Whether they are two
  writings of the same number, or whether one is derived from the other, is not verified.
- **Which participant role is authoritative when the registry and `participant.type`
  disagree?** Until this is settled, a person-role check cannot be written without choosing a
  field arbitrarily.
- **What do the `tournament_stage` and `participant` property owners hold?** The event owner
  was measured separately once `GLOBAL-DISCOVERY-011` proved unable to complete, and the same
  can be done for the other two. Until then the statement stays unusable for this sport.
- **Should the referee properties be treated as a fourth participation path?** They are how
  match officials take part, and no approved check reads them. A participation check that
  counts the three known mechanisms describes officials as taking no part in the sport.
- **Do the sport-wide areas need re-confirming inside the scope?** The registry, statistic,
  relation and discipline findings describe all of Soccer. Where a check narrows to the client
  scope but its structural evidence was taken sport-wide, the two are not the same population.

<!-- MANUAL PASTE ZONE: 1 OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
