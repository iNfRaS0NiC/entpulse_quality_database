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
  the sport. Only the registry and the statistic layers remain confirmed sport-wide: the
  registry has no template relation at all, and the statistic discovery statements reach the
  template through a disjunction over six owner types that a single filter cannot narrow
  correctly. Every other area, properties included, was measured inside the scope. Each area's
  row below records which of the two it is.

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
| Scope layer | Used | `GLOBAL-DISCOVERY-009`, `-010` (scope) |
| Properties | Used | `GLOBAL-DISCOVERY-011` (scope), after it gained the template filter its branches always supported |
| object_relation | Used | `GLOBAL-DISCOVERY-012` (scope) |
| object_discipline | Used | `GLOBAL-DISCOVERY-013` (scope) |
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

Inside the scope `object_relation` carries a sport-level pair `1 → 153`, the template-to-subset
pair `2 → 152`, stage-level host country `4 → 33` and age class `4 → 151`, and the
statistic-level pairs `83 → 33` and `83 → 151`. A template-to-city pair `2 → 33` and a
stage-to-stage pair `4 → 4` exist elsewhere in the sport but not under these templates.

The sport-level pair is the one relation in that statement with no template above it, so it
survives narrowing untouched. That is correct rather than a leak — the relation belongs to the
sport itself and no template owns it — but it is the same shape as the registry branch of
`GLOBAL-DQ-007` and is noted here so the difference is a judgement on record rather than an
oversight.

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

**The two sides of a match do not field equal lineups, and are not expected to.** Each side
names its own substitutes, so one team's lineup is routinely a member or two shorter than its
opponent's inside the same event. `GLOBAL-DQ-068` measures exactly that and therefore reports a
large share of the scope; its finding is the proportion, not the event. The Comp.Rank layer
behaves the same way for squads entered in one competition, which is why `GLOBAL-DQ-065` is
monitored on the same reasoning. Both are signalled `Monitor` in `SPORTS/params.json`.

**Coaches occupy playing lineup types.** `coach` members appear under `Substitute player` and
`Midfield`, not only under the `Coach` lineup type. A check that infers a person's role from
the lineup type they occupy will therefore be wrong for this sport, and a check that infers it
from `participant.type` disagrees with the registry as described above.

**Only two of the four registry roles are reachable by the three participation paths.** An
`athlete` is reached through a lineup place or a Comp.Rank row, a `team` through an event
participant row, and a `coach` through both a lineup place and a Comp.Rank row. An `official`
is reached by none of them: the role's own mechanism is the `ref:participant` path, which is
outside this client's scope by the decision of 2026-08-05, so a participation check finds an
official only by accident. `REGISTRY_PARTICIPANT_TYPE_LIST` is therefore narrowed to `athlete`
and `team` for `GLOBAL-DQ-009`, the one statement that reads it — a scope for that check, not a
correction to the four roles the registry carries.

**`Soccer-DQ-080` returns more rows than one request can carry, and is the first check in the
package that does.** The registry it audits held 393 933 athletes and teams on 2026-08-05, of
which a little over a third reach none of the three paths, so the statement returns on the
order of 140 000 finding rows. Its coverage is healthy and its scope is correct; what fails is the transport,
which runs out of memory before it can return them:

```text
Query failed (HTTP 500): Allowed memory size of 134217728 bytes exhausted
```

That is the second of the two failure modes `WORKFLOW.md` separates — a result too large,
not a statement too slow — and the statement already carries the marker that answers it:

```sql
-- AND p.id BETWEEN <from_participant_id> AND <to_participant_id>
```

The runner activates that marker itself. On a result too large it measures the participant id
range, cuts it into windows and merges the pieces back into one result, so the check needs
neither a range chosen by hand nor a run of its own. The range is deliberately not recorded
here: it moves with every participant the feed adds, and the runner reads it at execution time.

Two things still make this check unlike its neighbours and are worth knowing before a batch is
run: the registry has no template relation, so `-TemplateIds` skips the statement rather than
narrowing it, and the registry is the audited population itself, so `-WithoutRegistryBranch`
has nothing to drop. Neither switch makes it cheaper, so it is measured at full scope or not
at all.

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

**The mirrored pair is written before the match is played.** A fixture that has not happened
yet already carries `6 runningscore` with no `4 finalresult` beside it — the scope reaches the
2028 European Championship, whose semi-finals stand with placeholder participants named
`Winner SF 1` and `Winner SF 2`. `GLOBAL-DQ-090` reads both types without narrowing to played
events, so its output is dominated by the calendar rather than by defects, and it is signalled
`Monitor` for that reason. The pair that stopped being written for a **finished** match is what
the check is for and remains worth reading inside its output.

The check audits the event rather than the competitor since 2026-08-12, and this sport is where
that mattered most in volume: a score the import never wrote is missing on both sides of a match
at once, so every finding here was reported twice. The count went from 286 to 143 and the
coverage halved with it, 14430 to 7215 — both halves of the proportion had been counting sides
of a match where the defect belongs to the match.

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

`GLOBAL-DISCOVERY-011` reads every property owner at once and against the whole sport
exhausts the server's temporary storage rather than returning a result. All four of its
branches reach `tournament_template`, so the statement now carries the standard template
filter and returns the whole layer for the scope in about a second.

Events carry a wide property vocabulary. `Round` and `Live` sit on every event in scope.
Timing marks record the passage of the match — game and half start and end, and the same set
again for extra time. Match context arrives as `Spectators`, `VenueName`, `VenueNeutral`,
`ElapsedTime`, `BestOf` and `BestOfNum` for a tie played over two legs, and `medal_related`.
Production state is carried by `Verified`, `LineupConfirmed`, `Commentary`, `LiveStatsType`,
`LiveStatsPlus` and `SuperLive`.

**There is no `Winner` property, and the outcome is not stored anywhere else either.**
Measured across every property name the scope uses, the sport records no winning side on the
event at all. `549 finaloutcome` exists but does not stand in for it: remeasured 2026-08-26
inside the client scope it sits on **74 of 6479 matches**, so for 6405 of them the winner is
derivable from the two scores and stored nowhere.

An earlier version of this paragraph said the information a `Winner` check looks for is
"present one layer away". That is true of 1 per cent of the matches and false of the rest, and
the difference matters because it decides what kind of absence this is. It is not a sport that
keeps the outcome somewhere else; it is a sport that does not keep it.

**The check is expected and the sport is not ready for it.** `GLOBAL-DQ-087` and
`GLOBAL-DQ-088` are `Blocked` rather than `Not applicable`: the `Winner` property is meant to
be set on every head-to-head sport, the work to add it is under way, and a block lifts when the
data is fixed while `Not applicable` promises a review that never comes. Until then the
`WINNER_*` parameters have no vocabulary to declare, which is a fact about today and not about
the model - Volleyball already writes the property, so the model supports it.

**Match officials reach an event through properties, not through participation.** Properties
of type `ref:participant` carry `refereeFK`, `assistant1_refereeFK`, `assistant2_refereeFK`,
`fourth_refereeFK`, `var1_refereeFK` and `var2_refereeFK`, each naming a `participant`. This is
a fourth way of taking part in the sport, alongside the event participant row, the lineup place
and the Comp.Rank statistic, and no approved check reads it. It is why the registry's
`official` role appears to take no part in the sport when measured through the other three.

**The referee path is outside the client's scope by explicit decision of 2026-08-05, and is
recorded here as structure rather than as work.** UK Sport does not ask about match officials,
so no check is to read `ref:participant` and none is to be written for it. The consequence
must be carried rather than forgotten: a participation check counting the three mechanisms
reports every registered `official` as taking no part in the sport, and that finding is an
artefact of the unread fourth path, not a defect in the data.

`REGISTRY_PARTICIPANT_TYPE_LIST` keeps `official` regardless, because the parameter describes
what the registry holds and the registry does hold that role. The exclusion belongs to this
client rather than to the database, so it is made per run: a participation check is executed
with the role removed from the list, and the run records that it was. Decided 2026-08-05.

Tournament stages carry `Cup`, `International`, `Live`, `Ranking` and `youth` across the whole
scope, plus `Note` and `StatusComment` as free operational text and a sparse `reserve`.

Participants carry `IsNationalTeam` and `ToBeDecided` on every team in scope, and `HomePage`
and `home_shirt_color_1` on a few. **`IsNationalTeam` is where the club and national-team
distinction is stored.** The scope deliberately mixes the two, and this property separates them
structurally rather than by reading a template name, so a check needing one kind of entity has
somewhere to look.

The `tournament` owner carries no properties anywhere in the scope.

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

**The two kinds of Comp.Rank statistic divide the work between them, and the split is
structural.** A statistic without the `(athletes)` suffix ranks `team` participants and holds
the placing. A statistic with the suffix lists `athlete` and `coach` participants, and every
one of those rows carries `1429 Team` while **all but one carries no `1270 Rank` row at all** —
not an empty rank, no row. So the athlete statistic records who was in the squad, and the team
statistic records where the squad finished.

The single exception is measured rather than assumed, and is worth naming because the earlier
record of this file claimed there was none: across the whole sport on 2026-08-05, one athlete
row carries a Rank, in statistic `305482` under template `296 World Championship U20 1`. That
template is outside the client scope, so a narrowed run never meets it. It is a stray value
rather than a second way of storing a placing — one row against fourteen thousand — but the
rule stated here is a strong majority, not an absolute.

This is a state of the data rather than a limit of the schema: `1270 Rank` is a field of this
layer and the team statistics use it, so a squad list that began carrying a placing would be
readable the day it appeared. The event layer is the opposite case and is settled elsewhere —
a head-to-head sport stores no place on a result, which is why `RESULT_RANK_TYPE_ID` is
recorded as unavailable in `SPORTS/params.json`.

**Two squad statistics carry a medal without holding a place.** Measured 2026-08-12 over every
tournament-owned Comp.Rank outside IOC-purpose templates: 65 of the sport's 490 statistics hold
no Rank on any holder, all 65 are the `(athletes)` variant, and 63 of them carry no medal
either — the roster shape this section describes. The remaining two award a medal to a squad
whose placing is stored nowhere in the statistic, `310947` under the European Championship U17
Male 2015 among them. The medal is not wrong on its face; what is missing is the place it
stands for, in a statistic that by the split above is not supposed to record one. Whether the
medal belongs on the team statistic instead, or the squad list is meant to carry a placing
after all, is for the data owners. `GLOBAL-DQ-026` reports all 65 under
`Medal_Set_Unreadable_Without_Rank`, which is why the check is a `Monitor` for this sport: the
63 are the sport's normal shape and only these two are a repair.

### Checks whose eligible population is empty

The coverage contract requires the sport file to say which of the two kinds each zero is.
Measured on 2026-08-05, three approved checks audit nothing today, and all three are sentinels
rather than misdirected scopes — the scope is aimed correctly and the population it names does
not exist yet:

| Check | Its population | Why it is empty |
|---|---|---|
| `Soccer-DQ-053` | Comp.Rank statistics whose Gender config reads `mixed` | the config carries only `male` and `female` |
| `Soccer-DQ-054` | event participants that are teams of gender `mixed` | team participants are only `male` and `female` |
| `Soccer-DQ-066` | athlete Comp.Rank rows holding a numeric Rank | the squad lists carry no Rank row, as above |

None of the three reads a structure the sport lacks. `mixed` is a value of a populated column
in both of the first two, and `CLAUDE.md` is explicit that a value with no rows today is a data
state: excluding a check on that basis disables it for the day those rows arrive, which is the
day it was written for. Each keeps its registry row, its ID and its `Approved` status.

Soccer's statistic layer is far wider than Comp.Rank alone. Other active types sit at three
owner levels — tournament, tournament stage and event — and include `Player Stats`,
`Team Stats`, their Extended variants and `Fun Facts Stats`, with the largest populations at
event level. None of that layer is read by any approved check, and it is recorded here as
structure rather than as a candidate.

**The Comp.Rank organization is not filled at all, and `Soccer-DQ-103` is a sentinel because of it.** Measured 2026-08-25 this sport holds 493 tournament-owned Comp.Rank records over 21 035 ranked participations and **not one** carries an Organization value on the statistic data type the sport declares for it.

That makes `Soccer-DQ-103 COMP.RANK_PARTICIPANT_ORGANIZATION_COUNTRY_CONTRADICTS_COMPETITOR` return an `eligible_count` of 0. It is the second of the two things a zero can be - a correct scope over a population that is legitimately empty today, not a misdirected one - and the measurement above is what settles which. The check asks whether the organization that is there is the right one; there is none to ask about. `Soccer-DQ-093` is what reports the absence itself.

It is instantiated rather than left off on the ruling of 2026-08-25 that the field is expected to be populated, and the day it is, this is the check that reads what arrives. Four of the twelve documented sports already fill it - Artistic Gymnastics, Triathlon, Golf and Ice Hockey - and those four are exactly the four that carried this check before today.

<!-- MANUAL PASTE ZONE: 1 STATISTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Reference values

Comp.Rank `1277 Medal` uses the standard `gold`, `silver`, `bronze` vocabulary and also occurs
with an empty value. `1270 Rank` carries a bare integer.

A Comp.Rank statistic is named `<Competition> <Gender> <Year> - Competition Rank`, with an
`(athletes)` variant beside the plain one wherever the competition ranks both teams and the
people in them. Tournament stage names follow their competition and hold to their own forms
without exception across every distinct pattern in scope.

**The plausible rank ceiling is the field size, and the field is about to grow.** The largest
field any competition in scope has entered so far is 32, and the World Championship expands to
48 from 2026, which the scope already reaches. `RANK_MAX_PLAUSIBLE` is recorded as the ceiling
the sport can legitimately award rather than the largest value stored today, so the expansion
arrives as competition rather than as a defect report.

**That ceiling is a judgement about the client's 28 templates and does not hold across the
sport.** Outside them the Nations League ranks every UEFA federation in one Comp.Rank statistic
and reaches 51 — measured on 2026-08-05 in statistic `201308` under template `10457`, where
Armenia, the Faroe Islands and Moldova hold 51, 50 and 49. Those are correct placings, so any
Comp.Rank check keyed on `RANK_MAX_PLAUSIBLE` must be run with `-TemplateIds`; run sport-wide
it reports a legitimate final ranking as an outlier. The parameter is right for the scope it
was recorded for and wrong for the sport, which is a property of the client boundary rather
than of the value.

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

Under `status_type = 'notstarted'` the catalogue offers `Not started`, `Postponed`,
`Abandoned`, `Kick Off Delayed`, `Start delayed` and a few competition-specific variants.
`NOT_STARTED_DESC_LIST` records only the `Not started` and `Postponed` descriptors, on the same
reading the four sports before it used: the parameter names the statuses that are expected to
carry **no results**, and an abandoned match legitimately carries the goals scored before it
was abandoned. Listing `Abandoned` would report those goals as a defect. The distinction
matters more here than in the sports documented earlier, because abandonment after play has
begun is a normal outcome in this one.

**Under `status_type = 'finished'` the scope uses six descriptors, and each says which score
stages the match should carry.** Measured on 2026-08-05:

| `status_descFK` | Descriptor | Means |
|---:|---|---|
| 6 | Finished | decided inside ninety minutes |
| 13 | Finished AP | decided by a penalty shootout |
| 11 | Finished AET | decided in extra time |
| 190 | Finished after awarded win | decided administratively |
| 16 | Finished AGG | decided on the aggregate of two legs |
| 24 | Finished ASG | decided by a silver goal |

`24 Finished ASG` occurs once, on the 2004 European Championship semi-final, and behaves
exactly as `11` does: extra time, no shootout. It is kept rather than treated as an anomaly,
because a status the sport still holds is a status the data can use again.

**A penalty shootout does not imply extra time.** Nearly a quarter of the matches decided on
penalties went to them straight from a level ninety minutes, which is the format several
competitions in scope have used rather than a defect. `Soccer-DQ-081` therefore asserts that
`13` carries a shootout and never that it carries extra time — the rule the measurement
refused. It asserts the reverse implications instead: a shootout belongs to `13` alone, and
extra time to `11`, `13`, `16` and `24`. `190` is left out of both, because an awarded result
replaces a match that may genuinely have been abandoned mid-way, so a stage stored beside it
records the play rather than contradicting the status.

<!-- MANUAL PASTE ZONE: 1 EVENT AND ROUND REPRESENTATION — insert approved additions immediately before this marker; do not move or delete it. -->

## Confirmed sport-specific storage semantics

- **The score result types are cumulative into `4 finalresult`, which equals
  `1 ordinarytime` + `2 extratime` + `3 penaltyshootout`.** The relation holds for every Final
  Result row in scope without exception, including the rows where extra time or the shootout is
  absent and contributes nothing. `5 halftime` is not a term in it: it is a snapshot taken
  during ordinary time, not a stage that adds to the total. Any check comparing one score type
  against another must use this relation rather than assume each type is an independent value.
- **A knockout round must produce a winner; a group round need not.** `round_type.knockout`
  is the discriminator, read from the id the event carries rather than from the round name,
  because `DB-SEM-012` records that one name exists as both. Two exceptions keep the rule from
  being asserted for the sport as a whole: a group match may legitimately end level, and so may
  one leg of a tie decided on aggregate, which is played inside a knockout round and marked by
  the `BestOf` event property. `Soccer-DQ-022` is the rule with both exclusions applied.
- The pairing is the classification. There is no event-level rank and no `Winner` event
  property, and for all but a fraction of matches there is no stored outcome either: the
  winner is read from the two `finalresult` values and nothing else records it.
- **`549 finaloutcome` is a field of the two-legged tie, not of the match.** Measured on
  2026-08-05 across the scope, it sits on about one match in a hundred, and every match
  carrying it carries all three markers of an aggregate tie beside it — `550 overallscore`,
  the `BestOf` event property and a `351 aggregate_score` scope container — without a single
  exception. It records which side won the tie, so it must be read against `550`, never
  against `4 finalresult`: on a good third of those matches the side marked `won` lost the leg
  it is stored on, or the leg was drawn, and both are the tie being decided somewhere else.
  Read against `550` no side marked `won` holds the lower aggregate, and where the aggregate
  is level the tie was settled by away goals or by a shootout.
- A match official takes part through an event property of type `ref:participant`, never
  through an event participant row, a lineup place or a statistic.
- The same two participants never meet twice on one calendar day, which is what
  `DUPLICATE_KEY_USES_CALENDAR_DAY = 1` records: two meetings of one pairing on one date are a
  duplicate whatever their kick-off times say.
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
- **Do the sport-wide areas need re-confirming inside the scope?** The registry and the
  statistic findings still describe all of Soccer. The registry has no template relation and
  never will; the statistic statements could be narrowed only by a filter shaped for their
  six-way owner disjunction, which does not exist yet. Deliberately left that way on
  2026-08-05: what those statements establish — which statistic types and owners the sport
  uses, which shard holds them, which data and config fields exist — does not change with the
  scope, so the wider evidence is sound for the facts recorded from it. It would matter for a
  finding counted per row, and none of these is.
<!-- MANUAL PASTE ZONE: 1 OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
