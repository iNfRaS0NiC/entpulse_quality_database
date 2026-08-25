# SPORT: Speed-Skating (sport_id=19)

This file is the canonical structural record for Speed-Skating. It contains only confirmed
sport-specific usage, meanings, identifiers, evidence boundaries and open structural
questions. Global database mechanisms belong in `../DATABASE.md`.

For additions, insert approved content immediately before the exact active
`MANUAL PASTE ZONE` marker in the destination subsection. Keep the marker unchanged
and at the end of its subsection. Replace existing rows or paragraphs in place when a
correction is required.

## Identity and evidence

- First discovery date: 2026-08-22
- Latest evidence date: 2026-08-22
- Verification boundary: the whole `GLOBAL-DISCOVERY` catalogue, 001 through 033, was run for
  this sport on 2026-08-22 and every statement returned. `-033` failed inside the chain
  because the runner substituted `PERSON_PARTICIPANT_TYPE_LIST` unquoted; it was re-run by
  hand with `'athlete'` and returned. Every **summary** named below is therefore complete
  coverage of what the sport stores.

**The sport is `Speed Skating`, `sport.id = 19`, enet code `sp`.** `Short Track Speed
Skating` is a different sport, `sport.id = 15`, and nothing in this file was measured against
it. The two are not variants of one row.

Detail statements were run only for values chosen to answer a question: `GLOBAL-DISCOVERY-019`
for round type 0; `-027` for Startnumber `DNF` and `#.#` and for Duration `-`, `DQ` and `DNF`;
`-029` for Time `#:#.#:#.#`, Rank `<EMPTY>` and Time Difference `e_difference  +#.#  t` and
`-#.#`. Each is a sample of the value it was run for and nothing wider. `-021`, `-023` and
`-025` were run only on the three values their summaries rank first, so the event-name,
stage-name and statistic-name families below rest on their summaries, which are complete, and
not on the row listings beneath them, which are not.

## Structural coverage

| Area | Status | Evidence |
|---|---|---|
| Core hierarchy | Used | 101 templates under `tt.sportFK = 19`, standard five-level path |
| Event participants | Used | `athlete` and `team` only |
| Event results | Used | Eight active result types |
| Incidents | Not used | The complete-layer query returned zero active rows; the sport writes non-start and disqualification into result type `104 Comment` instead |
| Lineups | Used | Two types, `6 Unknown` and `14 Starter`, athletes under a team parent |
| Scope layer | Used | 26 container types, 25 numbered checkpoints and a final result; the largest storage the sport has after the result row itself |
| Properties | Used | Four owner objects |
| object_relation | Used | Six active source/target combinations |
| object_discipline | Used | Two discipline vocabularies in simultaneous use on events and on statistics |
| Statistics | Used | Comp.Rank, `statistic_typeFK = 11`, owner `3 tournament`, shard 11 |
| Reference values | Used | Round types, event statuses, age classes, tournament sub sets, the result comment vocabulary |
| Other tables | Not checked | |

**The competition model is `Listing`, with both individual and team participants.**
`DATABASE.md` `DB-SEM-015` states the model as a condition on rows, and the condition was
measured rather than assigned, 2026-08-22: an event's field takes 68 distinct sizes from 1 to
well past 50, so it is not fixed at two, and the sport populates the event-level rank result
type `100 Rank` on 4721 of its 5088 events. The 99 events holding exactly two participants are
a field of two, not a pair.

The race is skated in pairs on the ice, and that is not what the model describes. The pairing
is a scheduling fact the database does not store as the classification: the event holds the
whole field, every skater carries a rank against the whole field, and the pair a skater was
drawn into is recorded as a start number, not as an opponent.

## Tables and relation paths used

The sport uses the standard hierarchy without deviation:
`tournament_template -> tournament -> tournament_stage -> event -> event_participants`,
anchored on `tt.sportFK = 19`.

**A template is one gender, and the gendered templates are where the data is.** Nearly every
competition is stored as two or three templates carrying the same name and differing only in
`tournament_template.gender` - `World Cup` is 12327 male, 12328 female and 30 mixed;
`Asian Winter Games` is 12356 male, 12357 female and 11206 mixed. Of the 101 templates, 30 are
male, 29 female and 42 mixed. A statement that identifies a competition by template name alone
therefore addresses a fraction of it.

**The `mixed` template is usually an empty shell.** 38 of the 42 mixed templates hold
tournaments and nothing beneath them - no stage, no event. `27 World Championship Allround`
carries 30 tournaments and zero stages, `28 World Championship Single Distances` 29 and zero,
`25 European Championship` 22 and zero. Only four mixed templates carry events at all:
`30 World Cup`, `10755 Junior World Cup`, `10918 World Allround Junior Championships` and
`11179 Youth Olympic Games`, and those hold the genuinely mixed-gender competitions rather
than the undivided imports.

**26 templates carry the `(IOC)` suffix and none of them holds a stage or an event.** They
hold tournaments and nothing beneath them, which is the same shape Equestrian's and
Swimming's IOC templates have. Unlike those, **Speed Skating's IOC templates carry Comp.Rank
statistics**: 2301 of the sport's 9314 statistics hang off a tournament whose template is an
IOC one. The statistics half of this sport is therefore not empty under IOC templates the way
the event half is, and a statement that excludes IOC templates from a statistic scope is
excluding roughly a quarter of the population on purpose rather than as a formality.

One further template is empty without being mixed or IOC: `12341 World Junior Championships`
male, one tournament, one stage, no events.

<!-- MANUAL PASTE ZONE: 19 TABLES AND RELATIONS — insert approved additions immediately before this marker; do not move or delete it. -->

## Participant and lineup structure

**`event_participants` carries only `athlete` and `team`.** Athletes skate individual
distances and teams skate Team Pursuit, Team Sprint, the relays and the Mixed Gender Relay.
Athlete participations exist in two genders, team participations in three - `male`, `female`
and `mixed` - and the mixed team is the Mixed Gender Relay.

**The registry holds two roles and one inactive row.** `object_participants` for
`object = 'sport'`, `objectFK = 19` holds `athlete` and `team`. Measured 2026-08-22, every
registry row is active except one, a female athlete. The registry is close to the event layer
in size rather than far wider than it, which is the opposite of Swimming's shape.

**Lineups are the team's skaters, and two lineup types are in use where other sports have
one.** `14 Starter` behaves as it does elsewhere: 64 rows, one per member, parent `team`,
members `athlete`. `6 Unknown` carries the rest and is far larger - 13 726 rows over 2005
members. Both types put `athlete` members under a `team` parent, and both record the member's
own gender, `male` or `female`, never `mixed`. So a Mixed Gender Relay's composition is
readable only from the lineup, where the members' genders differ from the parent team's.

The two types are not a distinction the sport makes about the skaters; `6 Unknown` is the
absence of a stated lineup type rather than a second kind of membership. Which of the two a
lineup lands in is an open question below.

<!-- MANUAL PASTE ZONE: 19 PARTICIPANTS AND LINEUPS — insert approved additions immediately before this marker; do not move or delete it. -->

## Event result types

| result_code | result_typeFK | Value shape | Confirmed meaning | Evidence |
|---|---:|---|---|---|
| `rank` | 100 | A bare integer, one normalized shape and no other | The skater's or team's finishing place in the event's field | `GLOBAL-DISCOVERY-007`, `-026`, 2026-08-22 |
| `duration` | 101 | Two different things: a signed gap `+S.hh` / `-S.hh` / `+M:SS.hh`, and an absolute time `M:SS.hh` / `S.hh`; plus `-`, `DQ` and `DNF` as text | Ambiguous by construction - see storage semantics | `GLOBAL-DISCOVERY-007`, `-026`, `-027`, 2026-08-22 |
| `points` | 102 | `M:SS.hh` or `S.hh` | Stored on two events only; the value shape is a duration, not a point score | `GLOBAL-DISCOVERY-007`, `-026`, 2026-08-22 |
| `comment` | 104 | A closed vocabulary of 62 values, not free text | Qualification, record and non-finish markers, several notations for each; the vocabulary is not the one the Comp.Rank layer writes - see below | `GLOBAL-DISCOVERY-007`, `-026`, 2026-08-22; vocabulary measured 2026-08-24 |
| `startnumber` | 408 | A bare integer | The skater's start number, which is also the pair the skater was drawn into | `GLOBAL-DISCOVERY-007`, `-026`, `-027`, 2026-08-22 |
| `medal` | 501 | `gold`, `silver`, `bronze` and nothing else | The medal awarded | `GLOBAL-DISCOVERY-007`, `-026`, 2026-08-22 |
| `secondpoints` | 510 | A bare integer | A second score beside the primary result, on a small minority of events | `GLOBAL-DISCOVERY-007`, `-026`, 2026-08-22 |
| `duration_full_time` | 557 | `M:SS.hh` or `S.hh`; no text, no sign | The skater's own total time for the distance | `GLOBAL-DISCOVERY-007`, `-026`, 2026-08-22 |

**`101 Duration` holds a gap and an absolute time in the same column.** 84 668 values carry a
leading `+` or `-` and are a difference from the winner; 6559 carry no sign and are an
absolute time. `557 Full-time duration` holds the absolute time unambiguously, which is why
the two exist side by side. A statement that parses `101` as a time without testing the sign
is parsing two different quantities as one.

**`101 Duration` also carries text where a duration is expected.** 24 values are a bare `-`,
and they are not scattered: 23 of the 24 events are Mass Start races at Junior World Cup and
Youth Olympic Games stages, measured 2026-08-22. Mass Start resolves on points rather than on
elapsed time, so the dash is the sport declining to record a time that the format does not
produce. That is a shape of the discipline, not a defect. The two remaining text values, `DQ`
and `DNF`, sit in one single event, 961949 `500 Metres` under World Championship Single
Distances 2011, and are the other thing - a comment written into the duration column.

**`102 Points` is a duration by another name.** Both its value shapes are times, and it is
stored on two events. The name of the result type and the content of its values disagree.

<!-- MANUAL PASTE ZONE: 19 EVENT RESULTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Incident types

**The sport writes no incidents.** `GLOBAL-DISCOVERY-008` returned zero active rows for the
whole sport. This is `Not used` rather than `Not checked` because the meaning an incident
would carry is demonstrably carried elsewhere: disqualification, withdrawal and non-start are
written into result type `104 Comment` as `Disqualified`, `DQ`, `Disq.`, `DNS`, `DNF`, `WDR`
and `Withdrawn`.

**The two layers do not share a comment vocabulary, and neither is free text.** Measured
2026-08-24: the event layer's `104 Comment` holds 62 distinct values and the Comp.Rank layer's
`1273 Comment` holds 52, and the two lists are not versions of one another. The event layer
alone writes the division and round markers `fa`, `fb`, `fc`, `fd`, `sf1`, `sf2`, `q` and
`adv`; the Comp.Rank layer alone writes `wd`, `dsq`, `nr` and `sb`. Both write the same
non-finish core and both write the `ff` flight series. A check reading one layer's vocabulary
against the other's rows would report a large part of the sport as invalid, which is why
`GLOBAL_DQ/README.md` inventories the two separately and why `RESULT_COMMENT_VALUE_LIST` and
`DATA_COMMENT_VALUE_LIST` are declared from separate measurements.

`nr` is the value that shows why the vocabulary cannot be read off the codes. It looks like
"no result" and it is not: measured 2026-08-24, all 8 of its rows carry a rank between 1 and 3
and 5 of them carry a medal, so it is a national record and belongs with `wr`, `or`, `pb`, `sb`
and `tr`. The genuine refusals are distinguishable by measurement rather than by spelling -
`wd` carries a time on 0 of 272 rows, `dsq` on 0 of 271, `no time` on 0 of 198.

A check looking for a skater's disqualification must read the comment result,
not the incident layer.

<!-- MANUAL PASTE ZONE: 19 INCIDENTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Scope types and data types

**The scope layer is a split-time layer, it is large, and it is the sport's second result
store.** 26 container types are in use: `101 checkpoint1` through `125 checkpoint25`, and
`305 final_result`. The container count falls away with the checkpoint number - `101` on 1980
events, `112` on 277, `125` on 17 - because a checkpoint exists only where the distance has a
lap for it. `305 final_result` is on 1851 events.

Two storage layers hang beneath a container:

| Layer | What it holds |
|---|---|
| `event_scope_detail` | Per-container flags and labels: `name` (the lap or distance the split was taken at - `0.5`, `1`, `1000 m`, `1400`), and the booleans `intermediate_sprint`, `final_sprint`, `overall_classification`, `allround_points` |
| `scope_result` | Per-participant values, data types `1 rank`, `2 points`, `3 comment`, `4 duration`, `7 checkpoint_points_sprint` |

`scope_result` holds 132 459 rank values and 123 051 duration values, measured 2026-08-22 -
more rows than the event result layer carries for the same quantities. A statement that reads
only `event_result` is reading the smaller half of this sport's results.

**The scope layer here scores, which is not true of every listing sport.** `2 points` and
`7 checkpoint_points_sprint` are per-checkpoint scores, and `event_scope_detail` marks which
checkpoints are sprint checkpoints and which feed the overall classification. This is the
mass-start and allround machinery: intermediate sprints award points at named laps and those
points decide the finishing order.

**The period is the container here, and the data type is the quantity.** That is the opposite
of the shape the `GLOBAL-DQ` scope templates read, and it was measured rather than assumed on
2026-08-22: the same five data types - `1 rank`, `2 points`, `3 comment`, `4 duration`,
`7 checkpoint_points_sprint` - appear under `101 checkpoint1` and under `305 final_result`
alike, so a data type says which quantity a value is and never which period it belongs to.
Curling stores it the other way round, one container `305 final_result` holding `282 end_1`
through `292 end_extra`, and that is the shape `GLOBAL-DQ-091` is parameterised for. The
consequence is recorded in `SPORTS/params.json` `_checkSignal`: no list of data types names
this sport's periods and no single container holds them, so the check is `Not applicable`
by construction rather than for want of a population. The question it asks is still a real
one for a 25-checkpoint split layer, and it stays open in the section below.

**The layer begins in 2013.** Measured 2026-08-23 over every finished event in the sport: no
year from 2003 to 2012 carries a single `305 final_result` container, one event in 2002 does,
and from 2013 onward between 55 and 80 per cent of finished events carry one. The gap is not a
property of the discipline - every distance is partial in the same way, `500 Meters` at 311 of
836 and `1500 Meters` at 184 of 528 - so a statement asserting the layer over the sport's whole
history is asserting it over a decade that has none. `SPORTS/params.json` `_checkSignal`
records the consequence for `GLOBAL-DQ-107`.

**Only `305 final_result` is in the client's scope**, by decision of 2026-08-23. The
checkpoints are the sport's own machinery - intermediate sprints, lap splits and the points
that come off them - and the client takes the final result alone. That is why `SCOPE_TYPE_ID`
is a single container here even though the layer is 25 checkpoints deep, and it does not narrow
`SCOPE_TYPE_LIST`, which still names all 26 because the relational checks that read it are
asking about the whole layer's integrity rather than about what the client consumes.

**The checkpoint `name` labels are free text and are not written to one convention.** `0.5`,
`1`, `1.5`, `10`, `1000 m`, `1200 m`, `1400` and `1800 m` all occur - a lap number and a
distance, with and without a unit, in the same field.

<!-- MANUAL PASTE ZONE: 19 SCOPES — insert approved additions immediately before this marker; do not move or delete it. -->

## Properties

Four owner objects carry properties:

| Owner | Type | Names in use |
|---|---|---|
| `event` | `metadata` | `AllRound`, `checkpoints`, `checkpoint_details`, `discipline`, `ElapsedTime`, `Live`, `medal_related`, `ParticipantType`, `race_type`, `Round`, `Type` |
| `event_participants` | `ref:participant` | `organizationFK`, holding a `participant.id` |
| `participant` | `metadata` | `date_of_birth`, `height`, `IsNationalTeam`, `status`, `weight` |
| `tournament_stage` | `metadata` | `StatusComment`, `Venue` |

**`checkpoints` and `checkpoint_details` are the scope layer's index.** `checkpoints` holds a
count and `checkpoint_details` the ordered lap list - `0.5, 1, 1.5, 2, 2.5, Finish` - on
exactly the events that carry `event_scope` containers. The same lap list is therefore stored
twice, once as a property string on the event and once as `event_scope_detail` rows beneath
it.

**The event's `discipline` property duplicates the `object_discipline` relation.** Both are
written on the event, and they are two independent statements of the same fact. The property
carries the discipline's name as text, the relation carries its id.

**`Type` and `Round` restate the gender and the round type the event already has.** `Type`
holds `Female` or `Male`, which `tournament_template.gender` and the stage already say;
`Round` holds `After Run 1`, which the event's `round_typeFK` already says. Three fields
carry the gender of a Speed Skating event and two carry its round.

**`organizationFK` is written on 8 event participations.** The sport has 5088 events. This is
the empty-organization shape rather than a sport that stores organizations, and it is a data
state, not a structural absence: the column and the relation both exist.

**`Venue` is written on 4 stages and `StatusComment` on 34.** Neither is a convention the
sport follows; the venue is normally readable only through the stage name and, for
statistics, through the `43 city` relation described below.

<!-- MANUAL PASTE ZONE: 19 PROPERTIES — insert approved additions immediately before this marker; do not move or delete it. -->

## Generic relations and disciplines

Six `object_relation` combinations are active, measured 2026-08-22:

| Source | Target | What it records |
|---|---|---|
| `1 sport` | `153 category` | The sport is `1 OLYMPIC` |
| `2 tournament_template` | `152 tournament_sub_set` | 16 subsets over 75 template rows: `24 WORLD_CHAMPIONSHIPS`, `1 EUROPE`, `54 NORWAY`, `36 WORLD_JUNIOR_CHAMPIONSHIPS`, `2 ASIA`, `42 USA`, `3 WINTER_OLYMPICS`, `12 WORLD_CUP`, `46 FOUR_CONTINENTS`, `50 JUNIOR_WORLD_CUP`, `49 CANADA`, `51 NETHERLANDS`, `55 GERMANY`, `37 WINTER_YOUTH_OLYMPICS`, `31 ASIAN_WINTER_GAMES`, `9 NORTH_AMERICA` |
| `4 tournament_stage` | `151 tournament_age_class` | `1 SENIOR` on 714 stages, `3 JUNIOR` on 196, `2 YOUTH` on 9 |
| `83 statistic` | `33 country` | 19 countries over 9258 statistics |
| `83 statistic` | `43 city` | 59 cities over 4863 statistic rows |
| `83 statistic` | `151 tournament_age_class` | The same three age classes, on 4413 statistics |

**The venue city is stored on the statistic, not on the stage.** `GLOBAL-DISCOVERY-014`
returned a `city_ids` column that is empty on all 921 stages, and a `host_country_ids` column
that is empty on all of them too; the stage carries a direct country and an age class and
nothing else. The city relation exists only from `83 statistic`. A statement asking where a
competition was held must go through the statistic layer or parse the stage name.

**Two discipline vocabularies are in simultaneous use, and they are two generations rather
than two dimensions.** `object_discipline` reaches both `5 event` and `83 statistic`, and both
carry the same split:

| Older set, spelled `Metres` | Newer set, spelled `Meters` |
|---|---|
| `138 500 Metres`, `135 1000 Metres`, `136 1500 Metres`, `140 3000 Metres`, `139 5000 Metres`, `137 10000 Metres`, `143 100 Metres`, `141 3000 Metres Relay`, `142 5000 Metres Relay` | `324 500 Meters`, `329 1000 Meters`, `326 1500 Meters`, `328 3000 Meters`, `325 5000 Meters`, `327 10000 Meters`, `565 100 Meters`, `330 Mass Start`, `331 Team Pursuit`, `332 Team Sprint`, `333 Mixed Gender Relay` |

The split is temporal, measured on `GLOBAL-DISCOVERY-032`, 2026-08-22: the `Metres` ids carry
events whose last year is 2016, the `Meters` ids carry events through 2026. The same physical
distance therefore has two ids, and which one an event uses says when the event was loaded,
not what was skated. `787 Overall Classification` exists on statistics only and belongs to
neither set.

Two exceptions sit inside that rule and are the reason it is stated as a generation rather
than a cut-off. `143 100 Metres` runs from 2006 to 2025, on the newer side of the boundary;
`565 100 Meters` holds a single event, from 2008, on the older side. The 100 m is a rarity in
this sport and its two ids are used the wrong way round relative to every other distance.

<!-- MANUAL PASTE ZONE: 19 GENERIC RELATIONS AND DISCIPLINES — insert approved additions immediately before this marker; do not move or delete it. -->

## Statistics

| statistic_typeFK | Owner type | Participant shard | Data shard | Fields/config | Evidence |
|---:|---:|---:|---:|---|---|
| 11 | 3 `tournament` | `statistic_participants11` | `statistic_data11` | `statistic_config`: `1463 Start date`, `1464 End date`, `1470 Gender`, `1471 Event id`. `statistic_data11`: `1270 Rank`, `1271 Points`, `1272 Duration`, `1273 Comment`, `1277 Medal`, `1426 Time`, `1427 Time Difference`, `1429 Team`, `1457 Time behind`, `1465 Organization`, `1467 Place`, `1468 Date` | `GLOBAL-DISCOVERY-015`, `-016`, `-017`, `-024`, `-028`, 2026-08-22 |

**One statistic type, one owner level, and no second pair.** `GLOBAL-DISCOVERY-015` returned a
single row: Comp.Rank on the tournament. There was nothing to choose between, so no choice was
made. 9314 statistics exist.

**Roughly a third of the sport's Comp.Rank hangs off a tournament that holds no event at
all.** Measured 2026-08-23: of the 7013 non-IOC tournament-owned statistics, 2193 sit on a
tournament with no stage or no event beneath it, and 4820 sit on one that has events. The
empty owners are the `mixed` shell templates described above - the national championships
worst of all, `Netherlands Single Distance Championships`, `Germany Single Distance
Championships`, `Canada Single Distance Championships` - which carry a ranking for a
competition whose events are stored under the gendered template instead.

This is the single most consequential fact about reading this sport's statistic layer. A
ranked competitor there can never be an event participant in the owning tournament, because
the tournament has nothing to take part in, so any statement joining a statistic to its
tournament's events reports a third of the layer without that being what the statement
asserts. `SPORTS/params.json` `_checkSignal` records it for `GLOBAL-DQ-030`.

**12 of the 42 declared data types are used.** The other 30 are declared in
`statistic_data_type` and carry no row for this sport - `1274 Laps Behind`, `1276 Pair`,
`1278 Qualification rank`, `1428 Wind` and the rest. Absence here is a data state, not a
structural absence: the type exists and the shard would hold it.

**The statistic name is written in two generations, and the generation decides whether
`config Gender` is present.** Measured 2026-08-22 over all 9314:

| Template purpose | Name form | `config Gender` | Statistics |
|---|---|---|---:|
| non-IOC | long, `<stage> <distance> <gender> - Competition Rank` | present | 3798 |
| non-IOC | long | **absent** | 3 |
| non-IOC | short, `1000 m Male After Run 1` | present | 539 |
| non-IOC | short | **absent** | 2673 |
| IOC | long | present | 50 |
| IOC | short | present | 23 |
| IOC | short | **absent** | 2228 |

The short form is 80 name patterns over 4938 statistics, the long form 744 patterns over
4376. The missing `1470 Gender` config row is therefore not a scattered omission - it tracks
the naming generation, and the gender is still recoverable from the name in both forms, which
spell `Male` or `Female` out. The three long-form exceptions are one statistic name repeated
under one template, `World Championship Sprint Overall Classification Male - Competition
Rank` under `12333`, ids 346970, 347015 and 347207.

**Value shapes in `statistic_data11`, all measured 2026-08-22 across every used type:**

| Data type | Shapes |
|---|---|
| `1270 Rank` | A bare integer, and one empty value |
| `1271 Points` | An integer, or a decimal |
| `1272 Duration` | `M:SS.hh`, `S.hh`, and one `+S.hh` |
| `1273 Comment` | Empty on 64 463 of 72 306 rows; otherwise the non-finish vocabulary |
| `1277 Medal` | Empty on 57 271 of 81 409 rows; otherwise `gold`, `silver`, `bronze` |
| `1426 Time` | `M:SS.hh` or `S.hh`, and two values carrying two colons |
| `1427 Time Difference` | `+S.hh` dominant, plus `M:SS.hh`, `S.hh`, `+M:SS.hh`, two `-S.hh` and one corrupted value |
| `1429 Team`, `1465 Organization` | A bare integer, a `participant.id` |
| `1457 Time behind` | `+S.hh`, two rows |
| `1467 Place` | Free text, `Calgary, AB (CAN)` |
| `1468 Date` | `DD.MM.YYYY` |

**The empty string is stored where a value is absent, rather than the row being absent.**
`1273 Comment` and `1277 Medal` are both mostly empty strings. A check testing these for
presence must test for the empty string, not only for a missing row.

**The Comp.Rank organization is not filled at all, and `Speed-Skating-DQ-121` is a sentinel because of it.** Measured 2026-08-25 this sport holds 6 722 tournament-owned Comp.Rank records over 135 811 ranked participations and **not one** carries an Organization value on the statistic data type the sport declares for it.

That makes `Speed-Skating-DQ-121 COMP.RANK_PARTICIPANT_ORGANIZATION_COUNTRY_CONTRADICTS_COMPETITOR` return an `eligible_count` of 0. It is the second of the two things a zero can be - a correct scope over a population that is legitimately empty today, not a misdirected one - and the measurement above is what settles which. The check asks whether the organization that is there is the right one; there is none to ask about. `Speed-Skating-DQ-107` is what reports the absence itself.

It is instantiated rather than left off on the ruling of 2026-08-25 that the field is expected to be populated, and the day it is, this is the check that reads what arrives. Four of the twelve documented sports already fill it - Artistic Gymnastics, Triathlon, Golf and Ice Hockey - and those four are exactly the four that carried this check before today.

<!-- MANUAL PASTE ZONE: 19 STATISTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Reference values

**Event statuses - three, and no more.** `finished` / `6 Finished` on 4721 events,
`cancelled` / `106 Cancelled` on 348, `notstarted` / `1 Not started` on 19.

**Round types - eight named, plus one absence.** `173 Final` on 4134 events, `182 After Run 1`
on 600, `178 Semi Finals` on 277, `176 Quarter Finals` on 30, `179 Qualifier` on 13,
`181 bronze` on 12, `204 Heats` on 3, `171 Preliminary` on 2. `181 bronze` is spelled in lower
case where every other name is capitalised.

**Age classes - `1 SENIOR`, `3 JUNIOR`, `2 YOUTH`**, reached from both the stage and the
statistic.

**The result comment vocabulary is not normalized.** `104 Comment` spells disqualification
three ways - `Disqualified`, `DQ`, `Disq.` - and withdrawal two - `WDR`, `Withdrawn`.
`1273 Comment` on the statistic side spells disqualification four ways - `Disqualified`, `DQ`,
`DSQ`, `Disq.` - and withdrawal three - `WD`, `WDR`, `Withdrawn`. `DSQ` occurs on the
statistic side and never on the event side. Records are marked `WR`, `OR`, `NR`, `SB`, `PB`,
`TR` and the combinations `WR, OR`, `TR/SB`, `Q/OR`, `OR/FA`, `OR/SF#`.

<!-- MANUAL PASTE ZONE: 19 REFERENCE VALUES — insert approved additions immediately before this marker; do not move or delete it. -->

## Event and round representation

**The event name carries the distance and nothing about the round, except when it does.**
27 name patterns cover the whole sport. The two largest are `# Metres` on 2298 events and
`# Meters` on 1527 - the same `Metres`/`Meters` generation split the discipline ids have. The
round is normally in `round_typeFK` and in the `Round` property, not in the name, but
`Mass Start Semifinal #`, `Team Pursuit Final B` and `Team Pursuit Quarterfinals` put it in the
name too.

**The stage name carries the competition and, for the national series, the year.** 105 name
patterns. The championships use a bare name repeated across seasons - `European Championship`
on 50 stages, `World Championship Allround` on 42 - and the tournament beneath carries the
season. The Norwegian series does the opposite and writes the year into the stage name:
`NM Allround 2006` through `NM Allround 2026`. `WC Heerenveen` and `WC Heerenveen2` are two
patterns for one venue, the second used where a season visits it twice.

**The event layer and the Comp.Rank phase name the same round with different ids.** An event's
Final is `173 Final`, `knockout = 'no'`. The phase recorded against a Comp.Rank participant row,
in `object_round` with `object_typeFK = 138`, is `9 Final` on 14621 of the sport's 14810 medalled
rows - the `knockout = 'yes'` member of the same name pair that `DATABASE.md` `DB-SEM-012`
describes. Two further finals appear only on the phase side, `265 Final A` and `273 Final B`.

A parameter measured on one layer is therefore wrong on the other, and this was found the hard
way on 2026-08-23: `MEDAL_ROUND_TYPE_LIST` read from the event layer alone made `GLOBAL-DQ-041`
report 14681 rows of 19619 against a rule that was simply pointed at ids the phase never uses.
The same mistake, in the same shape, made `GLOBAL-DQ-125` report 1380: `MEDAL_TEMPLATE_ID_LIST`
had been measured from `501 Medal` on events, and 23 templates award medals only through
`1277 Medal` on the statistic. Both are corrected and both dropped to their real counts. Any
parameter naming a round type or a medal-bearing template must be measured on both layers.

**17 events carry `round_typeFK = 0`, which resolves to no round type at all.** They are one
block, not a scattered defect: every one is `cancelled`, all sit in four stages, 879624
through 879627, and all are dated 2 or 5 March 2023 with contiguous event ids 3888816 to
3888832.

<!-- MANUAL PASTE ZONE: 19 EVENT AND ROUND REPRESENTATION — insert approved additions immediately before this marker; do not move or delete it. -->

## Confirmed sport-specific storage semantics

**A time is stored in four places and they are not interchangeable.** `event_result`
`101 Duration` holds a signed gap or an absolute time; `event_result` `557 Full-time duration`
holds the absolute time only; `scope_result` `4 duration` holds the split times;
`statistic_data11` `1426 Time` and `1427 Time Difference` split absolute from gap the way
`557` and `101` do, one level up. A statement asserting "the skater's time" must name which of
these it means.

**The gender of a Speed Skating result is stated up to four times.** On
`tournament_template.gender`, on the stage, in the event's `Type` property, and inside the
statistic's own name; and a fifth time in `statistic_config` `1470 Gender` where that row
exists. They are independent writes of one fact.

<!-- MANUAL PASTE ZONE: 19 STORAGE SEMANTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Open questions

**What separates lineup type `6 Unknown` from `14 Starter`?** Both put athlete members under a
team parent and neither carries anything the other does not. `6` holds 13 726 rows and `14`
holds 64. If `6` is the absence of a stated type rather than a type, then a check reading
`14 Starter` as this sport's membership mechanism reads 0.5% of the memberships.

**Is a checkpoint stored for every skater who passed it?** `GLOBAL-DQ-091` asks exactly this
of a period, and it cannot be pointed at this layer: its parameters take the period as a data
type inside one container and this sport keeps the period as the container. That is settled
and recorded above; what is not settled is the question itself. A skater missing from
`checkpoint7` while the rest of the field is there is either a split nobody recorded or a
split that was recorded against the wrong race, and no check in the package looks. The layer
is large enough for it to matter - 132459 rank values and 123051 duration values - and
answering it needs a sport-authored statement, which nobody has approved.

**Which of the two discipline generations should a check anchor on?** A statement filtering
`object_discipline` on `324 500 Meters` silently drops every 500 m event before 2016, and one
filtering on `138 500 Metres` drops every one after. The 100 m pair is used the opposite way
round from the rest, so no single rule covers all of them.

**Is `102 Points` mis-typed?** Both of its value shapes are times and it is stored on two
events. Either the result type is wrong for what those two events hold, or the values are.

<!-- MANUAL PASTE ZONE: 19 OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
