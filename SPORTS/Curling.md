# SPORT: Curling (sport_id=10)

This file is the canonical structural record for Curling. It contains only confirmed
sport-specific usage, meanings, identifiers, evidence boundaries and open structural
questions. Global database mechanisms belong in `../DATABASE.md`.

For additions, insert approved content immediately before the exact active
`MANUAL PASTE ZONE` marker in the destination subsection. Keep the marker unchanged
and at the end of its subsection. Replace existing rows or paragraphs in place when a
correction is required.

## Identity and evidence

- First discovery date: 2026-08-01
- Latest evidence date: 2026-08-01
- Verification boundary: sport identity, core hierarchy, event statuses, event participants,
  event results, incidents, lineups, scope layer, properties, object_relation,
  object_discipline, statistics and reference values all confirmed from active data. Venue
  storage was measured only through the DQ template that reads it, not through a discovery
  statement of its own.

## Structural coverage

| Area | Status | Evidence |
|---|---|---|
| Core hierarchy | Used | `GLOBAL-DISCOVERY-002`, `-003` |
| Event participants | Used | `GLOBAL-DISCOVERY-004`, `-006` |
| Event results | Used | `GLOBAL-DISCOVERY-007`, `-026` |
| Incidents | Not used | `GLOBAL-DISCOVERY-008` returned zero active rows |
| Lineups | Used | `GLOBAL-DISCOVERY-005` |
| Scope layer | Used | `GLOBAL-DISCOVERY-009`, `-010` |
| Properties | Used | `GLOBAL-DISCOVERY-011` |
| object_relation | Used | `GLOBAL-DISCOVERY-012` |
| object_discipline | Used | `GLOBAL-DISCOVERY-013` |
| Statistics | Used | `GLOBAL-DISCOVERY-015`, `-016`, `-017`, `-028`, `-031` |
| Reference values | Used | `GLOBAL-DISCOVERY-030`, `-031` |
| Other tables | Not checked | |

## Tables and relation paths used

Core hierarchy through `tournament_template.sportFK=10`; event results via `result`; scope
via `event_scope`/`scope_result`; properties via `property`
(`object='event'|'tournament_stage'|'participant'`); disciplines via `object_discipline` on
owner types 5 (event) and 83 (statistic); statistics via `statistic` (`object_typeFK=3`) →
`statistic_participants11` → `statistic_data11`, with `statistic_config` for statistic-level
metadata.

Unlike the sports documented before it, Curling attaches disciplines to statistics as well as
to events, and `object_relation` carries three pairs whose source is a statistic.

<!-- MANUAL PASTE ZONE: 10 TABLES AND RELATIONS — insert approved additions immediately before this marker; do not move or delete it. -->

## Participant and lineup structure

Event participants are teams only. No `athlete` participant reaches the event layer directly,
and both the male and the female team populations are matched by a third, `mixed`, used by the
mixed doubles and mixed team formats.

The sport-level registry (`object_participants`, object='sport', objectFK=10) is wider than
the event layer: it carries `athlete`, `team` and `coach` roles, with both active and inactive
athletes. `coach` occurs in no other documented sport.

Lineups are used but are not the sport's membership mechanism. `lineup_type` 14 `Starter`
attaches `athlete` members to a `team` event participant, and only a small minority of team
event participants carry one. Athlete-to-team membership is carried by the Comp.Rank layer
instead, through the `(athletes)` statistic described under Statistics below. A check that
reads team membership from lineups therefore measures the minority mechanism and reports the
rest of the sport; `GLOBAL-DQ-058` is that check and its finding here is the proportion, not a
defect per event. It is signalled `Monitor` for that reason. An earlier revision of
`SPORTS/params.json` recorded it as `Not applicable`, contradicting this paragraph.

<!-- MANUAL PASTE ZONE: 10 PARTICIPANTS AND LINEUPS — insert approved additions immediately before this marker; do not move or delete it. -->

## Event result types

| result_code | result_typeFK | Value shape | Confirmed meaning | Evidence |
|---|---:|---|---|---|
| finalresult | 4 | Non-negative integer; no other shape occurs | Final Result | Confirmed-data |
| runningscore | 6 | Non-negative integer; no other shape occurs | Running score | Confirmed-data |
| medal | 501 | `gold` / `silver` / `bronze` | Medal | Confirmed-data |
| ordinarytime | 1 | Integer | Ordinary time | Confirmed-data |

The sport carries no Rank, Duration, Comment or Full-time result type. The classification is
the score itself: `4 Final Result` holds one value per team, so the winner is read from the
pair rather than from a stored place. This is the first documented sport whose event layer
holds no rank at all, and it removes the whole family of checks that read a rank, a time or a
status code against one another.

`4` and `6` are the only result types carrying a measured quantity, and
`GLOBAL-DISCOVERY-026` confirms a single value shape for each: digits only, with no empty
value, no decimal and no text anywhere in the active population.

`4 Final Result` and `6 Running score` are not two figures but one stored twice. Across the
whole active population they hold the same value for effectively every participant, so the
pair is a duplicate by design and any disagreement between them is a defect rather than a
distinction. `GLOBAL-DQ-090` asserts that, and either side being absent is the same defect
caught earlier.

The defect belongs to the match rather than to one side of it, and this sport is where that was
measured: a score the import never wrote is missing for both teams at once, so 29 of the 30
affected events were reporting exactly two rows each. The check audits the event since
2026-08-12, and the count went from 59 to 30 against a coverage that halved with it, 35840 to
17920. `affected_count` still names how many of the field are involved, which for a Curling
match is two whenever the whole match is affected and one where a single side lost its value.

`1 Ordinary time` is an anomaly rather than a field the sport uses. It occurs on a handful of
events only, and almost every one of them carries the `Finished after awarded win` status, so
it reads as a by-product of how an awarded win is recorded rather than as a result the sport
maintains. No rule can be asserted on it until what writes it is known; a check whose eligible
population requires it audits those few events and its coverage count says so.

`Finished after awarded win` is where this sport's result defects concentrate, and three
independent checks converge on it. On such an event `4 Final Result` is either absent or left
at zero while `6 Running score` and the end-by-end scope values carry the play that actually
happened. That single editorial gap is visible as a mirrored-pair disagreement
(`GLOBAL-DQ-090`), as an end sum that does not reach its total (`GLOBAL-DQ-085`) and, where
both sides are left at zero, as a tie no head-to-head sport should record (`GLOBAL-DQ-084`).
The same two events are reported by all three.

The sport uses no status vocabulary on a result. `RESULT_COMMENT_VALUE_LIST` is therefore
recorded as the empty list `''`, following the convention `GLOBAL_DQ/README.md` records for
`SERIES_SKIP_YEARS`: a sport with nothing to name records a value that matches nothing rather
than leaving the parameter unset. `GLOBAL-DQ-076` runs on that basis and can never report its
`STATUS_CODE_IN_NUMERIC_FIELD` branch here.

<!-- MANUAL PASTE ZONE: 10 EVENT RESULTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Incident types

Not used — `GLOBAL-DISCOVERY-008` returned zero active incident rows for Curling events.

<!-- MANUAL PASTE ZONE: 10 INCIDENTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Scope types and data types

Used, and with a shape neither previously documented sport has. One scope type,
`305 final_result`, with one active container per event, and the container holds the game's
end-by-end scoring in the `scope_result` layer:

| scope_data_typeFK | Detail name |
|---:|---|
| 282–289 | `end_1` … `end_8` |
| 290 | `end_9` |
| 291 | `end_10` |
| 292 | `end_extra` |

Two things vary independently here, and conflating them misreads the layer.

**Which end columns exist.** `end_1` through `end_8` carry a value in effectively every
container, `end_9` and `end_10` in a substantial majority but not all, and `end_extra` in a
small minority. Two scheduled game lengths therefore coexist, eight ends and ten, and the
extra end is the exception rather than a parallel convention.

**How many ends were actually scored.** That is not the scheduled length. A conceded game
stops early, and the count of ends holding a number runs across the whole range from six to
eleven rather than clustering on eight and ten. Ten and nine are the most common, then eight,
seven and six, with eleven the extra end; a handful of events hold fewer than five, which are
abandoned games rather than a format.

A check keyed on a fixed number of ends is therefore wrong twice over: wrong for one of the
two scheduled lengths, and wrong for every conceded game of either.

An end that was not played is not stored as an empty row. It carries the sentinel `X`, and
`X` is the only non-numeric value the layer holds anywhere in the sport: every active period
row across the whole population is either a plain integer or `X`, with no null, no empty
string and no second symbol. The sentinel is what makes the arithmetic work — a conceded game
whose ends read `5-0-4-5-3-3-X-X` sums to its stored total exactly, because the sentinel is
skipped rather than counted as zero. `GLOBAL-DQ-085` sums only plainly numeric values for that
reason, and `GLOBAL-DQ-086` guards the assumption by reporting any period value that is
neither a number nor a confirmed sentinel, before it can reach the sum as a silent zero.

<!-- MANUAL PASTE ZONE: 10 SCOPES — insert approved additions immediately before this marker; do not move or delete it. -->

## Properties

Confirmed active `property` type='metadata' names by owner:

- `event`: discipline, ElapsedTime, Live, medal_related, ParticipantType, Round,
  StartDateTimeToBeDecided, StartTimeToBeDecided
- `participant`: IsNationalTeam, ToBeDecided
- `tournament_stage`: Cup, Live, Venue
- `tournament`: Not used

`ParticipantType`, `IsNationalTeam`, `ToBeDecided`, `StartDateTimeToBeDecided` and
`StartTimeToBeDecided` occur in no other documented sport. `Venue` is present as a stage
property on a small minority of stages and is not the `venue_object` mechanism `DATABASE.md`
records, so it does not make an event resolve to a venue.

<!-- MANUAL PASTE ZONE: 10 PROPERTIES — insert approved additions immediately before this marker; do not move or delete it. -->

## Generic relations and disciplines

`object_relation` pairs confirmed active: (1→153), (2→152), (4→151), (83→33), (83→43) and
(83→151). The three whose source object type is 83 (statistic) are new against the sports
documented before this one.

`object_discipline` is used on owner type 5 (event) and owner type 83 (statistic), with two
disciplines: 752 `Mixed Doubles` and 753 `4aSide`.

The discipline, stage gender and participant-type combinations the sport has contested:

| Discipline | Stage genders contested | Participant type |
|---|---|---|
| 752 `Mixed Doubles` | mixed only | team |
| 753 `4aSide` | male, female, mixed | team |

`Mixed Doubles` is contested as a mixed format only. A check that expects every discipline to appear
under every gender would be wrong here, and the matrix rather than a rule is what says so.

**The statistic layer's discipline is not always the one its own tournament ran.** Two
statistics named `World Championships Mixed - Competition Rank`, the team half and its
`(athletes)` partner, carry `753 4aSide` while every active event under their tournament was
contested in `752 Mixed Doubles`. `GLOBAL-DQ-100` reports them, and the direction of the
error is what it adds: the events are the record of what was played, so the statistic is
wrong rather than the events.

That is the third independent route to the same pair. `GLOBAL-DQ-095` reaches them through a
place held twice, `Curling-DQ-078` through rosters of two under a four-player discipline, and
`GLOBAL-DQ-100` through the discipline itself. Three checks reading three different columns
and arriving at one statistic is what makes the finding safe to act on.

<!-- MANUAL PASTE ZONE: 10 GENERIC RELATIONS AND DISCIPLINES — insert approved additions immediately before this marker; do not move or delete it. -->

## Statistics

| statistic_typeFK | Owner type | Participant shard | Data shard | Fields/config | Evidence |
|---:|---:|---:|---:|---|---|
| 11 (Comp.Rank) | 3 (tournament) | statistic_participants11 | statistic_data11 | Data: Rank(1270), Points(1271), Comment(1273), Medal(1277), Qualification rank(1278), Team(1429). Config: Start date(1463), End date(1464), Gender(1470) | Confirmed-schema-data |

Comp.Rank is the only statistic type the sport uses. The physical shard is 11 for both
participants and data, confirmed by probing rather than derived from the type (`DB-SEM-006`).

Comp.Rank separates team results from athlete results, and the separation is structural rather
than only editorial: a statistic whose name carries the `(athletes)` suffix holds `athlete`
participants and nothing else, while a statistic without the suffix holds `team` participants
and nothing else. No statistic holds both. The `(athletes)` statistic is where an athlete's
team membership is recorded, through the `1429 Team` data field holding the team's
`participant.id`, and it is the sport's primary membership mechanism rather than the event
lineup.

The sport stores no time in Comp.Rank. Neither the current `1426 Time` and
`1427 Time Difference` fields nor the deprecated `1272 Duration` occurs, which removes every
check that reads a stored time against a rank.

`statistic_config` records no `1471 Event id`, so a Comp.Rank statistic cannot be resolved to
the event it was taken from through that path.

Three data fields are present but marginal, and each is confined to IOC-purpose templates:

- `1271 Points` carries decimal values and is the sport's only numeric data field. Because a
  statistics statement excludes IOC-purpose templates, `GLOBAL-DQ-077` has an empty eligible
  population here and `NUMERIC_DATA_TYPE_LIST` stays unrecorded.
- `1273 Comment` resolves to the single value `DNF`.
- `1278 Qualification rank` carries one value in the whole sport, and that value is a medal
  word rather than a rank. It is a defect and not a second meaning the field carries: the row
  is the athlete Lajos Belleli in statistic `325855`, European Championships B-Division Male
  2011, whose `1278` reads `silver` while his `1277 Medal` already reads `silver` and his
  `1270 Rank` correctly reads `2`. The value is a copy of the medal that landed in the wrong
  field, so the field is unused in this sport rather than differently used.

One statistic exists at owner level 4 (tournament_stage) rather than 3. It is named `test`,
holds no participant row in any state, and is active, sitting on the Winter Olympics 2022
stage. It is not expected to exist and is a defect; owner level 4 has no intended use in this
sport, whose real statistic layer is owner level 3 alone.

**The Comp.Rank organization is not filled at all, and `Curling-DQ-115` is a sentinel because of it.** Measured 2026-08-25 this sport holds 952 tournament-owned Comp.Rank records over 21 453 ranked participations and **not one** carries an Organization value on the statistic data type the sport declares for it.

That makes `Curling-DQ-115 COMP.RANK_PARTICIPANT_ORGANIZATION_COUNTRY_CONTRADICTS_COMPETITOR` return an `eligible_count` of 0. It is the second of the two things a zero can be - a correct scope over a population that is legitimately empty today, not a misdirected one - and the measurement above is what settles which. The check asks whether the organization that is there is the right one; there is none to ask about. `Curling-DQ-105` is what reports the absence itself.

It is instantiated rather than left off on the ruling of 2026-08-25 that the field is expected to be populated, and the day it is, this is the check that reads what arrives. Four of the twelve documented sports already fill it - Artistic Gymnastics, Triathlon, Golf and Ice Hockey - and those four are exactly the four that carried this check before today.

<!-- MANUAL PASTE ZONE: 10 STATISTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Reference values

| Code type | id | name |
|---|---:|---|
| result_type | 1 | Ordinary time |
| result_type | 4 | Final Result |
| result_type | 6 | Running score |
| result_type | 501 | Medal |
| scope_type | 305 | final_result |
| scope_data_type | 282–292 | end_1 … end_10, end_extra |
| lineup_type | 14 | Starter |
| discipline | 752 | Mixed Doubles |
| discipline | 753 | 4aSide |
| statistic_type | 11 | Competition Stats |
| statistic_data_type (data) | 1270 | Rank |
| statistic_data_type (data) | 1271 | Points |
| statistic_data_type (data) | 1273 | Comment |
| statistic_data_type (data) | 1277 | Medal |
| statistic_data_type (data) | 1278 | Qualification rank |
| statistic_data_type (data) | 1429 | Team |
| statistic_data_type (config) | 1463 | Start date |
| statistic_data_type (config) | 1464 | End date |
| statistic_data_type (config) | 1470 | Gender |

<!-- MANUAL PASTE ZONE: 10 REFERENCE VALUES — insert approved additions immediately before this marker; do not move or delete it. -->

## Event and round representation

An event name is the pairing that plays it: `Andorra-Canada` for a team game and
`Brazil/New Zealand-Canada/Spain` for mixed doubles, where each side is itself two country
names joined by a slash. No other shape occurs.

Two consequences follow, and both are structural rather than incidental:

- every event name contains a hyphen with no surrounding spaces, so `GLOBAL-DQ-049` reports
  the sport's whole distinct-name vocabulary under `HYPHEN_WITHOUT_SPACES`. The rule is not
  wrong; it is describing the naming convention. The findings worth reading in that result are
  the ones breaking a second rule as well;
- `GLOBAL-DISCOVERY-020` groups event names by a digit-normalized pattern, and a pairing of
  country names holds no digits to normalize. The summary therefore degenerates into a list of
  pairings and carries no pattern information for this sport.

The sport contests a wide round-type vocabulary, and eleven of its round names occur under two
ids at once. Every one of those pairs is the knockout/non-knockout split `DB-SEM-012` records
globally, not a second vocabulary: Preliminary (`171` no, `253` yes), Final (`173` no, `9`
yes), Semi Finals (`178` no, `2` yes), bronze (`181` no, `138` yes), Quarter Finals (`176` no,
`3` yes), Playoff (`304` no, `305` yes), Qualifier (`179` no, `152` yes), 1/8 (`184` no, `4`
yes), 1/16 (`185` no, `5` yes), 5/8 (`262` no, `26` yes) and 9/12 (`303` no, `136` yes).

The per-sport fact `DB-SEM-012` asks for is which side the sport stores, and Curling stores
both: in every pair the non-knockout variant carries the large majority of events and the
knockout variant a consistent minority. A check keyed on one id of a pair therefore audits
part of the sport and reports the rest, which is why the Final round set is recorded as both
ids rather than the one the sport uses most.

Round types 38, 39, 40 and 41 resolve to `round_type` rows named `1`, `2`, `3` and `4`, all
non-knockout with a bracket size of `0`. They occur inside a single stage and halve in event
count from one to the next, so they are consecutive rounds of one progression. This agrees
with the reading `SPORTS/BMX.md` records for `38` and extends it to the rest of the family.

Every active event resolves to a `finished` status type, under four status descriptions:
Finished, Finished AEI, Finished after awarded win and Finished AET. No not-started or in-play
status currently occurs.

That absence is a row count, not a structure the sport lacks: `event.status_descFK` is in
active use here, and `status_desc.status_type` carries a `notstarted` value the sport can
receive with any import. The two not-started checks are therefore instantiated rather than
classified away — `Curling-DQ-100` and `Curling-DQ-101` — and `NOT_STARTED_DESC_LIST` names
the full canonical family rather than the ids seen so far. `CLAUDE.md` owns the rule; an
earlier revision recorded both parameters as impossible on the strength of the current
population, which would have kept the sport silent on the day a not-started event arrived.

`Curling-DQ-100` returns `eligible_count = 0` and is a **sentinel** in the sense `POWERBI.md`
defines: the scope is correct and the population is legitimately empty today, so zero is its
right answer and not a scope to correct. `Curling-DQ-101` reads the same status family but
also audits finished events, so it covers 17920.

It carries the `Sentinel` signal since 2026-08-17, and did not before because the vocabulary
had no such word — which cost something visible. The run reads the signal to decide which
`eligible_count = 0` questions are already answered, so it raised this one on the `Decisions`
tab of every run while the paragraph above had answered it. `TOOLS/README.md` owns the word.

`Curling-DQ-007` was briefly a sentinel and briefly `Not applicable`, and was neither. Its
coverage was zero because `GLOBAL-DQ-007` reached participants through `event_participants`
alone, and this sport enters teams — its athletes are carried by lineups and by the Comp.Rank
statistic. The template now reads all three paths and the sport registry beside them, so the
check covers the sport's athletes as it always should have, and the classification is
removed. The lesson is the one `CLAUDE.md` records: a zero coverage count is a question about
the statement before it is ever a fact about the sport.

`Finished AEI` is the status the sport uses for a game decided in an extra end, and the
`end_extra` scope column is the independent record of the same fact. The two are meant to
agree, and where they do not the disagreement is one-directional: the extra end is scored but
the status stays plain `Finished`, far more often than the reverse. `Finished AET` also occurs
against a scored extra end, which is the wrong member of the pair — the sport plays an extra
end, not extra time.

The number of ends carrying a score cannot substitute for the `end_extra` column here. Nine
scored ends is either an eight-end game that went to an extra end or a ten-end game conceded
on the ninth, and nothing in the count separates the two. `GLOBAL-DQ-089` therefore reads the
extra-end column and never a period count.

`Finished after awarded win` describes how the game ended rather than whether it went to an
extra end, and both live in `status_descFK`. A game that went to an extra end and was then
awarded can carry only one of the two, so the field cannot express both at once.

**The sport awards its medals across two events, not one.** The Final settles gold and
silver between the two teams contesting it, and a separate bronze match settles bronze.
Both rounds are stored under the knockout/non-knockout pair `DB-SEM-012` records: Final
`9`/`173` and bronze `181`/`138`. `MEDAL_ROUND_TYPE_LIST` is therefore the four ids
`9, 138, 173, 181`, and it is a wider set than `FINAL_ROUND_TYPE_LIST` rather than a copy
of it. `BRONZE_ROUND_TYPE_LIST` records the other half of that split, `138, 181`, because
knowing where a medal may occur is not the same as knowing which one: the Final decides gold
and silver, the bronze match decides bronze, and only the two lists together say so.

The split is measured rather than assumed. Every active Medal result in the sport sits on one
of those four rounds, gold and silver only on `9` and `173` and bronze only on `138` and
`181`, with a single silver on `138` as the lone exception - which is a defect the medal
checks report, not a second convention.

Two consequences follow, and both are about which object a medal rule can be asserted on:

- no single event can hold the full set of three medals, because a head-to-head event holds
  two participants. `GLOBAL-DQ-037` asserts exactly that of one event, so its finding branch
  reports every Final in the sport as missing bronze by construction, before any data is
  read. It is uninstantiable here, and `Curling-DQ-030` is deprecated for that reason; the
  ID stays reserved. Completeness of the medal set is asserted instead in the Comp.Rank
  layer, per statistic, by `GLOBAL-DQ-026`;
- a rule about where a medal may occur is keyed on the medal rounds and never on the Final
  alone. `GLOBAL-DQ-038`, `-039`, `-041` and `-073` read `MEDAL_ROUND_TYPE_LIST` for that
  reason; keyed on the Final alone, all four report every bronze match in the sport.

A stage is not the object either. It carries no medal of its own — the medal is a result row
on an event participant — so the round the event sits on is what identifies a medal event.

<!-- MANUAL PASTE ZONE: 10 EVENT AND ROUND REPRESENTATION — insert approved additions immediately before this marker; do not move or delete it. -->

## Confirmed sport-specific storage semantics

The sport is head to head between two teams, and it meets the `H2H` condition `DB-SEM-015`
states without exception: every active event holds exactly two event participants, both of
type `team`, and each score result type carries one value per participant. A result is read as
a pair and never as a standalone classification, which is why the sport populates no
event-level rank.

Most active events resolve to no venue, through neither their own `venue_object` link nor
their tournament stage's: 16764 of 17920, against 739 carrying their own link and 417
inheriting one from their stage. That is expected rather than defective. Venue is newly
populated in this database and the backfill is still ahead, so the absence records how far it
has reached rather than something missing that was once there. `GLOBAL-DQ-074` stays
instantiated for exactly that reason - it is the measure of the backfill's progress, and the
figure to read is the proportion rather than the individual event. It will start reading as a
defect only once the population is expected to be complete. It is signalled `Monitor` for that
reason. An earlier revision of `SPORTS/params.json` recorded it as `Not applicable` and stated
that no event resolves to a venue, which contradicted this paragraph and misstated the sport:
1156 events do resolve to one.

**The sport records no winner.** The `Winner` event property, which 30 other sports use to
name the winning side, does not occur on a single Curling event. Nor does any result type
carry the outcome: the sport stores `1 Ordinary time`, `4 Final Result`, `6 Running score` and
`501 Medal`, and none of them names a side. The winner is therefore not stored at all here —
it is only derivable, by comparing the two `4 Final Result` values, and `501 Medal` marks a
podium at the end of a competition rather than the outcome of a match.

That makes `GLOBAL-DQ-087` and `GLOBAL-DQ-088` uninstantiable for this sport today, and the
`WINNER_*` parameters are recorded as not applicable for that reason rather than left blank.
The reason is about what the sport stores now, not about what it could store: if the property
starts being written, the parameters are what change, not the checks.

The sport uses no placeholder country. Every country reached from a tournament stage's direct
country column and every country reached from a statistic's `object_relation` (83→33) resolves
to a real country row, so `PLACEHOLDER_COUNTRY_LIST` is recorded as the empty list `''` on the
same convention the empty status vocabulary uses above.

The sport has run in every calendar year of its span, without a season missing between its
first and its last. 2020 is reduced rather than absent, so it is not a skipped year:
`SERIES_SKIP_YEARS` records the value `0`, a year that never occurs, following the convention
`GLOBAL_DQ/README.md` states for a sport with nothing to skip. This differs from both sports
documented before it, which do skip 2020.

<!-- MANUAL PASTE ZONE: 10 STORAGE SEMANTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Open questions

All three questions this file opened with are answered and have moved to the sections that
own them: the stray `1278 Qualification rank` value and the `test` statistic at owner level 4
are both defects and are recorded under Statistics, and the events resolving to no venue are
expected at this stage of the venue backfill and are recorded under storage semantics.

<!-- MANUAL PASTE ZONE: 10 OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
