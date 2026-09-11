# SPORT: Para-Athletics (sport_id=112)

This file is the canonical structural record for Para Athletics. It contains only confirmed
sport-specific usage, meanings, identifiers, evidence boundaries and open structural
questions. Global database mechanisms belong in `../DATABASE.md`.

For additions, insert approved content immediately before the exact active
`MANUAL PASTE ZONE` marker in the destination subsection. Keep the marker unchanged
and at the end of its subsection. Replace existing rows or paragraphs in place when a
correction is required.

## Identity and evidence

- First discovery date: 2026-09-11
- Latest evidence date: 2026-09-11
- Verification boundary: the sport was opened **without the Comp.Rank layer**, by the standing
  decision of 2026-08-26 that a sport is documented from its event results first and its
  ranking afterwards, because the ranking is generated from those results.
  `GLOBAL-DISCOVERY-015 STATISTIC_TYPES_AND_OWNERS`,
  `GLOBAL-DISCOVERY-016 STATISTIC_PARTICIPANT_SHARD_USAGE`,
  `GLOBAL-DISCOVERY-017 STATISTIC_DATA_AND_CONFIG_FIELDS`,
  `GLOBAL-DISCOVERY-024 STATISTIC_NAME_PATTERNS_SUMMARY`,
  `GLOBAL-DISCOVERY-025 STATISTIC_NAME_PATTERNS_DETAIL`,
  `GLOBAL-DISCOVERY-028 STATISTIC_DATA_VALUE_PATTERNS_SUMMARY`,
  `GLOBAL-DISCOVERY-029 STATISTIC_DATA_VALUE_PATTERNS_DETAIL`,
  `GLOBAL-DISCOVERY-030 STATISTIC_DATA_TYPE_CATALOG`,
  `GLOBAL-DISCOVERY-031 STATISTIC_DATA_TYPE_DECLARED_VS_USED` and
  `GLOBAL-DISCOVERY-033 PARTICIPANT_DUPLICATE_CANDIDATES_BY_NAME` were therefore not run, and
  every statistics area below is `Not checked` rather than `Not applicable`. The runner's own
  parameter discovery reported "the sport has no statistics" on 2026-09-11; that is a heuristic
  printed by a run and not a reading of the layer, and it is recorded here only so that the
  reader who opens the layer knows what to expect rather than as a finding.
- The rest of the catalogue was run whole on 2026-09-11, 58 statements with none failing, and
  the drill-downs were taken as far as the user decided: `GLOBAL-DISCOVERY-019
  EVENT_ROUND_TYPE_USAGE_DETAIL` for eight of nine round types, the ninth being `89 1` with a
  single event; `GLOBAL-DISCOVERY-023 TOURNAMENT_STAGE_NAME_PATTERNS_DETAIL` for eight of
  thirteen stage patterns, the other five being the single-stage marathons the summary lists in
  full; `GLOBAL-DISCOVERY-026 EVENT_RESULTS_VALUE_PATTERNS_SUMMARY` for eight of ten result
  types, the other two read by hand and recorded under Event result types.
- `GLOBAL-DISCOVERY-021 EVENT_NAME_PATTERNS_DETAIL` was run for the eight most populated of
  154 name patterns and is **a sample, decided 2026-09-11**; the summary lists all 154 and is
  the inventory. `GLOBAL-DISCOVERY-027 EVENT_RESULTS_VALUE_PATTERNS_DETAIL` was run for the
  eight most populated type/pattern pairs of 39, and the four rare forms that decide a
  convention were read by hand the same day; the rest is a sample and the summary is the
  inventory.
- **The disability class layer is not read by any statement in the GLOBAL catalogue.**
  Everything this file records about it was measured ad hoc on 2026-09-11, following
  `../DATABASE.md` `DB-SEM-020`.

## Structural coverage

| Area | Status | Evidence |
|---|---|---|
| Core hierarchy | Confirmed | `GLOBAL-DISCOVERY-002 CORE_HIERARCHY_USAGE`, `GLOBAL-DISCOVERY-003 EVENT_STATUS_USAGE`, `GLOBAL-DISCOVERY-014 TOURNAMENT_STAGE_REFERENCE_STORAGE`, `GLOBAL-DISCOVERY-022 TOURNAMENT_STAGE_NAME_PATTERNS_SUMMARY` |
| Event participants | Confirmed | `GLOBAL-DISCOVERY-004 EVENT_PARTICIPANT_TYPES_GENDERS`, `GLOBAL-DISCOVERY-006 SPORT_REGISTRY_PARTICIPANT_TYPES` |
| Event results | Confirmed | `GLOBAL-DISCOVERY-007 EVENT_RESULTS_TYPES_CODES`, `GLOBAL-DISCOVERY-026 EVENT_RESULTS_VALUE_PATTERNS_SUMMARY`, `GLOBAL-DISCOVERY-027 EVENT_RESULTS_VALUE_PATTERNS_DETAIL` as a sample, ad-hoc profiling 2026-09-11 |
| Incidents | Not used | `GLOBAL-DISCOVERY-008 INCIDENT_TYPES_CODES` returned zero rows |
| Lineups | Confirmed | `GLOBAL-DISCOVERY-005 LINEUP_TYPES_PARTICIPANT_TYPES` |
| Scope layer | Not used | `GLOBAL-DISCOVERY-009 SCOPE_TYPES` and `GLOBAL-DISCOVERY-010 SCOPE_DATA_TYPES_AND_LAYERS` both returned zero active rows |
| Properties | Confirmed | `GLOBAL-DISCOVERY-011 PROPERTY_USAGE_BY_OWNER` |
| object_relation | Confirmed | `GLOBAL-DISCOVERY-012 OBJECT_RELATION_USAGE` |
| object_discipline | Confirmed | `GLOBAL-DISCOVERY-013 OBJECT_DISCIPLINE_USAGE`, `GLOBAL-DISCOVERY-032 EVENT_DISCIPLINE_GENDER_PARTICIPANT_MATRIX` |
| Disability class | Confirmed | ad-hoc measurement 2026-09-11 against `object_disability_class`, see the section of that name |
| Statistics | Not checked | deliberately unread, see Identity and evidence |
| Reference values | Confirmed | `GLOBAL-DISCOVERY-003`, `GLOBAL-DISCOVERY-018 EVENT_ROUND_TYPE_USAGE_SUMMARY`, `GLOBAL-DISCOVERY-019 EVENT_ROUND_TYPE_USAGE_DETAIL` |
| Other tables | Not checked | |

## Tables and relation paths used

The sport keeps to the generic path `tournament_template -> tournament -> tournament_stage ->
event -> event_participants -> result`, with `object_participants` as the sport registry,
`lineup` for the members of a relay team, `object_discipline` for the discipline of an event,
`property` for event and participant metadata, `object_relation` for stage-to-country,
stage-to-city and tournament-level references, and `object_disability_class` for the class an
event is contested in and the class a competitor holds.

`event_scope`, `scope_result` and `incident` are not used: the scope discovery statements and
the incident statement returned zero active rows on 2026-09-11.

<!-- MANUAL PASTE ZONE: 112 TABLES AND RELATIONS — insert approved additions immediately before this marker; do not move or delete it. -->

## Participant and lineup structure

Both an athlete and a team enter events. Athletes are the population, 4438 male and 2146
female with 47 372 event participations between them; teams are the relay squads, 38 male, 22
mixed and 15 female, entered in the `4 X 100 Metres`, `4 X 400 Metres` and Universal relays.

- Event participants are `athlete` and `team`.
- The registry (`object_participants`, `object = 'sport'`) holds `athlete` and `team` in the
  roles `athlete` and `team`, all active, 4434 male and 2127 female athletes and 75 teams. It
  files the same two types as the events and no support role: no coach, no official and no
  guide. A guide runner is a `Pilot` property on the participation, see Properties.
- The one lineup type in use is `14 Starter`, whose parent is a `team` and whose members are
  `athlete`, 398 male and 148 female members across 1022 lineup rows.

<!-- MANUAL PASTE ZONE: 112 PARTICIPANTS AND LINEUPS — insert approved additions immediately before this marker; do not move or delete it. -->

## Event result types

| result_code | result_typeFK | Value shape | Confirmed meaning | Evidence |
|---|---:|---|---|---|
| rank | 100 | Whole numbers; `—` and `NM`, `DNS` where no place was resolved | Rank | `GLOBAL-DISCOVERY-007 EVENT_RESULTS_TYPES_CODES`, `GLOBAL-DISCOVERY-026 EVENT_RESULTS_VALUE_PATTERNS_SUMMARY` |
| duration | 101 | `ss.ff`, `m:ss.ff`, `h:mm:ss` for the marathons, plain seconds; also `+0.00` on field-event athletes, distances with a trailing ` m`, and status text the field cannot mean | Duration, the time of a track or road event | `GLOBAL-DISCOVERY-007`, `GLOBAL-DISCOVERY-026`, ad-hoc profiling 2026-09-11 |
| points | 102 | Whole numbers on the pentathlon; elsewhere times and distances that belong in `101` and `103` | Points, the total of a combined event; **filled with another field's value everywhere else**, see below | `GLOBAL-DISCOVERY-007`, `GLOBAL-DISCOVERY-026`, ad-hoc profiling 2026-09-11 |
| distance | 103 | `m.cc` metres; also times, status codes and record marks the field cannot mean | Distance, the mark of a jump or throw | `GLOBAL-DISCOVERY-007`, `GLOBAL-DISCOVERY-026`, ad-hoc profiling 2026-09-11 |
| comment | 104 | Progression, record and status codes, singly and combined with `, ` | Comment | `GLOBAL-DISCOVERY-007`, `GLOBAL-DISCOVERY-026` |
| medal | 501 | `gold`, `silver`, `bronze` and nothing else | Medal | `GLOBAL-DISCOVERY-007`, `GLOBAL-DISCOVERY-026` |
| tops | 535 | Status codes, record marks and a few times | **Not a meaning this sport has.** A climbing result type, see below | `GLOBAL-DISCOVERY-007`, `GLOBAL-DISCOVERY-026` |
| zones | 536 | Status codes, record marks and a few times | **Not a meaning this sport has.** A climbing result type, see below | `GLOBAL-DISCOVERY-007`, `GLOBAL-DISCOVERY-026` |
| top_attempts | 537 | Another competitor's name and country | **Not a meaning this sport has.** Ten rows, see below | `GLOBAL-DISCOVERY-007`, ad-hoc profiling 2026-09-11 |
| zone_attempts | 538 | A time | **Not a meaning this sport has.** Ten rows, see below | `GLOBAL-DISCOVERY-007`, ad-hoc profiling 2026-09-11 |

`100 Rank` is on 45 871 participations in 7519 events, the sport's most complete field.
`101 Duration` is on 38 351 in 6324 events, `103 Distance` on 15 399 in 1985, and the two
between them are the performance of a track or road event and of a field event respectively.

**`104 Comment` is the sport's status and record field**, 21 256 rows in 5923 events across 104
distinct written forms. The vocabulary is small and combines: progression `Q` and `q`, records
`WR`, `AR`, `CR`, `GR`, `ER`, `PR`, `NR`, `RR`, `WL`, `WRC`, `PRC`, the continental `AS`, `AF`,
`AM`, `OC`, a season or personal best `SB`, `PB`, an equalled record written `=WR`, `=AR`,
`=CR`, `=PR`, `=SB`, `=PB`, `=ER`, `=RR`, the no-result statuses `DQ`, `DSQ`, `Disq.`, `DNS`,
`DNF`, `NM`, `NMR`, and `YC` or `Yellow card`. Codes combine with a comma and a space, as in
`Q, SB` and `Q, WR, AR, PR`. **Disqualification is written three ways** - `DQ` on 701 rows,
`DSQ` on 61, `Disq.` on 27 - and the combinations are written with every spacing the keyboard
allows: `Q, PB`, `Q , PB`, `q ,PB`, `Q,  SB`, `Q SB`, `PB , Q`. A check reading this field by
value carries the canonical forms and reports the spacing. **The spacing is a defect, not a
vocabulary**, by the user's decision of 2026-09-11 when the check was instantiated: the
vocabulary keeps the canonical `Q, PB` form alone and `Para-Athletics-DQ-082` reports the 32
written variants on their 128 rows as `COMMENT_INVALID_VALUE`, beside the medal names, the
`LT3`-style codes and the stray `F1`. The alternative, admitting every spacing the keyboard
allows into `RESULT_COMMENT_VALUE_LIST`, was rejected because a list that accepts `q ,PB` has
stopped saying what the field's written form is. Four rows hold a medal name (`Gold`,
`Silver`, `Bronze`) and six hold `F#`, a class, which the field cannot mean.

**`102 Points` holds points on nineteen rows and something else on the other 1114.** Measured
2026-09-11 by discipline: the nineteen are `Pentathlon - Overall`, values 3324 to 5806, which is
what a combined-event total looks like. The rest are the performance of the event under the
wrong type - 435 sprint times on the `100 Metres` (10.49 to 29.28), 127 on the `400 Metres`,
throws on the `Shot Put`, `Javelin Throw`, `Discus Throw` and `Club Throw`, jumps on the
`Long Jump` and `High Jump`, and 43 `1500 Metres` times from the Para Asian Games of 2018 in
clock notation. The type is real and its meaning is the pentathlon total; everything else on it
is a value that belongs in `101` or `103`.

**The same shift runs the other way on the two performance fields.** `103 Distance` holds 310
running times in `m:ss.ff`, 296 of them from the World Championships of 2013, and `101 Duration`
holds 13 distances with a trailing ` m` from the Discus F42/F44 of 2006 and the Long Jump T46 of
2013. `101 Duration` also holds `+0.00` on 87 rows, all of them throwers and jumpers at eight
championships from 2004 to 2025, which is a gap column filled with zero for competitors who have
no time; and eight `Bronze Medalist`, eight `Silver Medalist`, six `DQ`, nine `DNS` and five
`NM`, which are a medal and a status in the time field. None of these is a convention the sport
follows; each is a value in the wrong field, and they are recorded here so the value-shape
column above is not read as the field's whole content.

**Four climbing result types are present and none of them means what its name says.**
`535 Tops` (234 rows in 78 events) and `536 Zones` (40 in 13) hold the same status codes and
record marks as `104 Comment` plus a handful of times and a stray `final`. `537 Top attempts`
and `538 Zone attempts` are ten rows each, all from one day of the Para Asian Games,
2018-10-08: `537` holds the name and country of a different competitor in the same event
(`Songwut Lamsan Thailand` on Hiep Ngoc Nguyen's participation in the `400m - T11`), and `538`
a time that reads as that competitor's own. The first reading of this file took the pair for a
guide's record, because a `T11` runner competes with one. **Measured on 2026-09-11, it is not:
the four fields hold the results of a different race of the same day, written into whatever
result type was free.** On Shinya Wada's row in `5000m - T11`, `537` and `538` hold his own name
and his own `1500m - T11` time of the same afternoon, `4:22.87`, rank 2 there; `535` and `536`
beside them hold Hamid Eslami's name and his `4:18.18`, the win in that same 1500 m. Every
5000 m row pairs the same way with a 1500 m result of some class, the `400m - T11` and
`400m - T12` rows with the other 400 m heats, and Prawat Wahoram, a `T54` wheelchair racer who
has no guide, is named on his own `5000m - T53/54` row with his `1500m - T53/54` time. The
same row carries the one defect this leaves behind: its `101 Duration` is `3:14.54`, the
1500 m time, and the 5000 m time `11:13.06` sits in `102 Points`. All four types are kept in
the table because they are genuinely present in the sport's data; the meaning column says what
each one is instead, and `Para-Athletics-DQ-073` on
`GLOBAL-DQ-155 EVENT_RESULTS_UNUSED_RESULT_TYPE_HOLDS_VALUES` reports every one of the 294 rows
as a value in a type the sport does not write.

<!-- MANUAL PASTE ZONE: 112 EVENT RESULTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Incident types

The incident layer is not used. `GLOBAL-DISCOVERY-008 INCIDENT_TYPES_CODES` returned zero rows
on 2026-09-11.

<!-- MANUAL PASTE ZONE: 112 INCIDENTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Scope types and data types

The scope layer is not used. Both `GLOBAL-DISCOVERY-009 SCOPE_TYPES` and
`GLOBAL-DISCOVERY-010 SCOPE_DATA_TYPES_AND_LAYERS` returned zero active rows on 2026-09-11.
A heat or a round is its own event, see Event and round representation; a split or an attempt
is not stored anywhere in the sport.

<!-- MANUAL PASTE ZONE: 112 SCOPES — insert approved additions immediately before this marker; do not move or delete it. -->

## Properties

Measured by `GLOBAL-DISCOVERY-011 PROPERTY_USAGE_BY_OWNER` on 2026-09-11, over 7733 active
events and 6637 registered participants.

| Owner | Type | Name | Owners carrying it | Confirmed meaning |
|---|---|---|---:|---|
| event | metadata | `Round` | 7733 | the round number, `1` on a heat and on a straight final alike |
| event | metadata | `Live` | 7733 | `no` throughout |
| event | metadata | `discipline` | 7611 | the discipline as text, `100 Metres`, beside the `object_discipline` link |
| event | metadata | `Type` | 7217 | the gender of the event: `Male` 4517, `Female` 2684, `Mixed` 16 |
| event | metadata | `medal_related` | 4639 | sample value `yes`, on as many events as carry a medal |
| event | metadata | `ElapsedTime` | 3346 | sample value `0`; the meaning was not read |
| event | metadata | `ParticipantType` | 2985 | `athlete` or `team` |
| event | metadata | `Heat` | 2826 | the heat number within a round |
| event | metadata | `Class` | 548 | the class as text, `F11`, on 548 events only; the class itself is `object_disability_class`, see Disability class |
| event_participants | ref:participant | `Pilot` | 270 | the guide runner of a visually impaired athlete, as a reference to another participant |
| event_participants | ref:participant | `organizationFK` | 51 | the organisation a participation is filed under |
| participant | metadata | `status` | 6637 | `active` |
| participant | metadata | `date_of_birth` | 3762 | date of birth, on 57 per cent of the registry |
| participant | metadata | `IsNationalTeam` | 41 | sample value `no`, on 41 participants |
| participant | metadata | `discipline` | 16 | sample value `4 x 100`, on 16 participants |
| participant | metadata | `height`, `weight` | 3 | three athletes each |
| tournament_stage | metadata | `Live` | 94 | `no` throughout |

**The `Winner` event property is not written**, as on every listing sport; the field is
resolved by `100 Rank`.

`Class` on 548 events is a second, textual copy of what `object_disability_class` carries on
7616, and the two are not kept in step by anything. `GLOBAL-DQ-158
EVENT_DISABILITY_CLASS_CONTRADICTED_BY_PROPERTY` reads exactly this pair and is owed by the
sport under the Para rule.

<!-- MANUAL PASTE ZONE: 112 PROPERTIES — insert approved additions immediately before this marker; do not move or delete it. -->

## Generic relations and disciplines

`object_discipline` carries the discipline on the event, owner type 5, across 25 discipline
rows: the running distances from `100 Metres` to `10000 Metres` and `Marathon`, the jumps,
the throws including `Club Throw`, the two relays, and the pentathlon as `Pentathlon -
Overall` plus one row each for three of its parts. 74 events carry discipline id `0`, which is
no discipline at all.

**The sport has no discipline catalogue of its own: its events are filed under the disciplines
of Athletics, `sport.id` 4.** Every discipline row above belongs to sport 4, and on 2026-09-11
`GLOBAL-DQ-015 EVENT_SETTINGS_DISCIPLINE_MISSING_UNRESOLVED_OR_FOREIGN` read all 7733 events as
carrying a foreign discipline before `DISCIPLINE_SPORT_ID_LIST` was added to it and to
`GLOBAL-DQ-161` the same day; the sport declares `4, 112`.

**Three distances appear under two ids, and the second id is another sport's.** `1500 Metres`
is id `5` (Athletics) on 25 events and id `136` on 389, `5000 Metres` is `6` on 8 and `139` on
138, `Marathon` is `17` on 4 and `404` on 45 - and `136` and `139` belong to Speed Skating
(sport 19), `404` to Mountain Bike (sport 56). The first reading of this file called them two
catalogues of one sport; the corrected `GLOBAL-DQ-015` named the owners the same day. The 572
events on them are events pointing at a same-named discipline of the wrong sport, which is the
`Discipline_Belongs_To_Another_Sport` state that check exists for, and the Athletics catalogue
itself holds no duplicated spelling, which is why `GLOBAL-DQ-161` reports nothing over 5971
events.

**The cause is a lookup by name, applied to every tournament but one.** Measured on 2026-09-11
over the 609 events on the six ids: the Athletics ids `5`, `6` and `17` are carried only by
Summer Paralympics 2024, whose 37 links are the earliest `object_discipline` rows the sport has
(ids 5174 to 12010); every other tournament, 37 of them from Athens 2004 to the 2025 World
Championships, carries `136`, `139` and `404` on all 572 of its events, and no event carries
both an Athletics id and a foreign one. Three names resolved to two different foreign sports is
what a lookup that takes the first discipline row spelled `1500 Metres` produces, and one import
of one source could not have done it across 37 tournaments and 21 years. Paris 2024 was loaded
first and correctly; the historical backfill behind it was not. `Para-Athletics-DQ-010` on
`GLOBAL-DQ-015` reports the 572 events, and the repair is one substitution per id.

`object_relation` holds three pairs: owner type 4 (stage) to related type 151 (country) on 82
rows, which is the host country `GLOBAL-DISCOVERY-014` reads; owner type 4 to related type 33
(city) on 49 rows; and owner type 2 to related type 152 on 18 rows, six distinct related
objects. Type 2 is `tournament_template`, not `tournament` as the first reading of this file
wrote, and the pair is the template-subset path `../DATABASE.md` `REL-OBJECT-002` documents:
read on 2026-09-11, the 18 templates are the sport's six competitions in their three genders,
and the six related objects are the sub-sets `SUMMER_PARALYMPICS` and `COMMONWEALTH_GAMES`
under the set `SUMMER_GAMES`, `ASIAN_SUMMER_GAMES` and `PAN_AMERICAN_GAMES` under
`CONTINENTAL_GAMES`, `EUROPE` under `CONTINENTAL_CHAMPIONSHIPS`, and `WORLD_CHAMPIONSHIPS`
under the set of the same name. Nothing in it is particular to the sport.

`GLOBAL-DISCOVERY-032` returned 43 discipline/gender/participant combinations actually
contested, from 2004 to 2025. A combination absent from that matrix has not been contested and
must not be assumed available; the mixed relay and the women's `4 X 400 Metres` are entered by
teams, everything else by athletes.

<!-- MANUAL PASTE ZONE: 112 GENERIC RELATIONS AND DISCIPLINES — insert approved additions immediately before this marker; do not move or delete it. -->

## Disability class

This section has no counterpart in `SPORTS/_TEMPLATE.md`. It is here because the layer is
central to how a Para sport stores its competition and because no GLOBAL statement reads it;
`../DATABASE.md` `DB-SEM-020` owns the structure.

The sport registers **162 classes** at sport level, `object_typeFK = 1`, `objectFK = 112`. They
are the single classes - `T11` to `T64`, `F11` to `F64`, `T20`, `F20` - and, in far greater
number, the combined classes an event is actually contested in: `F11-12`, `F32-34/51-58`,
`F35/36/37/38`, `T12-13/37-38`, written with a hyphen for a range and a slash for a list, and
sometimes both. A combined class is what an event is contested in and named for, so the
vocabulary is the vocabulary of events and not only of athletes.

| Object level | object_typeFK | Para-Athletics usage |
|---|---:|---|
| `event` | 5 | 7616 of 7733 active events carry a class, 156 distinct classes, 7625 links |
| `participant` | 15 | 3122 of 6637 registered participants carry a class, 93 distinct |
| `event_participants` | 6 | 3 entries |
| `lineup` | 73 | none |
| `object_participants` | 59 | none |

**The athlete level is half filled**: 3122 classified of 6637, which `DB-SEM-020` already
names as the second-largest athlete population in the database, and 3515 unclassified.
`GLOBAL-DQ-157 PARTICIPANT_DISABILITY_CLASS_MISSING` reads that gap.

**One class outside the vocabulary is carried by 710 events, and it is a Cyrillic letter.**
Measured 2026-09-11, `disability_class` 27 is named `Т11` with U+0422, the Cyrillic capital Te,
as its first character (bytes `D0 A2 31 31`), beside the registered `T11` with the Latin T; 710
of the sport's events are linked to it and it is not in the sport's own vocabulary.
`GLOBAL-DQ-159 EVENT_DISABILITY_CLASS_NOT_IN_SPORT_VOCABULARY` reports exactly this; the class
row itself is a duplicate in the reference table, which is outside this sport.

**Nine events carry more than one class**, which `GLOBAL-DQ-160 EVENT_DISABILITY_CLASS_AMBIGUOUS`
reads; whether each is an event contested across classes that should carry one combined class
instead, or two links where one was meant, was not read on 2026-09-11 and is the check's work.

117 events carry no class at all. `GLOBAL-DQ-156 EVENT_DISABILITY_CLASS_MISSING` separates
them itself, read on 2026-09-11: 113 name a registered class in their own name, as
`200 Metres - T37` of Beijing 2008 does, and owe the object that name already states; four name
none, and they are the three `4 X 100 Metres Relay` of Paris 2024, the universal relay that is
contested across classes by rule, and one `Shot Put - Seated` of 2006, which names a condition
rather than a class. `Para-Athletics-DQ-074` reports both states, 113 and 4, as its two
`check_type` values.

<!-- MANUAL PASTE ZONE: 112 DISABILITY CLASS — insert approved additions immediately before this marker; do not move or delete it. -->

## Statistics

| statistic_typeFK | Owner type | Participant shard | Data shard | Fields/config | Evidence |
|---:|---:|---:|---:|---|---|

**Not checked, deliberately.** The sport was opened on 2026-09-11 without the Comp.Rank layer
under the pause of 2026-08-26, and nothing in this section was read. The omission is recorded
in `SPORTS/params.json` under `_deferredLayers`, which is what keeps the 49 `COMP.RANK_*`
templates from being demanded of the sport until the layer is opened; it is `Not checked` and
never `Not applicable`, because the pause is expected to lift. The runner's discovery printed
"the sport has no statistics" on 2026-09-11 and that line is a heuristic, not this section's
evidence.

<!-- MANUAL PASTE ZONE: 112 STATISTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Reference values

- `sport.id` 112, `sport.name` `Para Athletics`, no enet sport code.
- Event statuses: `finished` (`status_desc` 6 `Finished`) on 7555 events, `notstarted`
  (1 `Not started`) on 149, `cancelled` (106 `Cancelled`) on 29.
- Round types, by `GLOBAL-DISCOVERY-018 EVENT_ROUND_TYPE_USAGE_SUMMARY`: `173 Final` 4804
  events, `38 1` 2324, `178 Semi Finals` 548, `284 Final B` 26, `179 Qualifier` 23,
  `265 Final A` 4, `2 Semi Finals` 2, `39 2` 1, `89 1` 1. The three single-digit-named types
  are heats; `2` and `89` duplicate `178` and `38` by name and are the minority spelling.
- Medals are awarded on `173 Final` (13 750 medal rows) and `265 Final A` (12); `284 Final B`
  awards none, being the consolation final of wheelchair racing.
- Tournament templates, 20 rows over seven names split by gender: `World Championships`
  (12862 male, 12863 female, 12864 mixed), `Summer Paralympics` (12157 male, 12158 female,
  10677 mixed), `European Championships` (13181, 13182, 13183), `ParaPan American Games`
  (12861, 13170, 13171), `Para Asian Games` (13234, 13235, 13236), `Commonwealth Games`
  (13231 male, 13232 female, 13233 mixed), `Wheelchair Marathon Majors` (13175 male, 13176
  female). Two templates hold no tournament at all: `13233 Commonwealth Games` mixed and
  `13176 Wheelchair Marathon Majors` female.
- Stage names equal template names except under `Wheelchair Marathon Majors`, whose 16 stages
  are the six majors by city, `Berlin Marathon`, `Boston Marathon`, `Chicago Marathon`,
  `London Marathon`, `New York Marathon`, `Tokyo Marathon`, and the series name itself.
- 82 of the 94 stages carry age class `1 SENIOR` and 12 carry none, which `GLOBAL-DQ-002`
  reads. A host country is missing on 45 stages and a city on 24, which `GLOBAL-DQ-034` reads;
  every stage carries a direct country.
- Client boundary: every template is in scope (`OUT_OF_SCOPE_TEMPLATE_ID_LIST` = `0`) from
  season 2004, as for Para Swimming; the sport's first stored season is 2004.

<!-- MANUAL PASTE ZONE: 112 REFERENCE VALUES — insert approved additions immediately before this marker; do not move or delete it. -->

## Event and round representation

An event is one race, one heat of a race, or one field-event competition, in one class or
combined class, and is named `<discipline> - <class>`: `100 Metres - T11`, `Shot Put - F34`,
`Discus Throw - F33-34/52`, `4 X 100 Metres Relay - T11-13`. `GLOBAL-DISCOVERY-020
EVENT_NAME_PATTERNS_SUMMARY` returned 154 name patterns and the largest two are one name
written twice: `# Metres - T#` on 3003 events and `#m - T#` on 2247, the second being the
spelling the Para Asian Games and the later World Championships use. The other 152 are the
combined-class spellings (`F#/#`, `F#-#`, `F#/F#`, `F#/#/#`), the relays, the marathons named
for their city, and `#m - T# Heats Summary` on 29 events, which is a summary event standing
beside its heats.

A heat is its own event under round type `38 1` (or `39 2` for a second round) with the
`Heat` property carrying the heat number; a semi-final is `178 Semi Finals`; a final is
`173 Final`, or `265 Final A` and `284 Final B` in wheelchair racing. Field events and
marathons are a single `173 Final`. There is no bronze-medal contest and no knockout; `179
Qualifier` samples as a field event's qualifying round (`Club Throw - F32`).

<!-- MANUAL PASTE ZONE: 112 EVENT AND ROUND REPRESENTATION — insert approved additions immediately before this marker; do not move or delete it. -->

## Confirmed sport-specific storage semantics

- **The performance of an event is in `101 Duration` for a track or road event and in
  `103 Distance` for a field event, and the place in `100 Rank`.** Which of the two a
  discipline uses follows from the discipline, not from the event, so a check comparing
  performance to place has to be told which disciplines are timed.
- **`102 Points` means the pentathlon total and nothing else.** The 1114 rows carrying a time
  or a distance under it are a shifted field, recorded under Event result types.
- **`104 Comment` is the status and record field**, with the vocabulary recorded under Event
  result types; `DQ`, `DSQ`, `Disq.`, `DNS`, `DNF` and `NM` mean the competitor has no
  classified result.
- **A disability class is attached to the event and, for half the registry, to the athlete**,
  through `object_disability_class`; the `Class` property on 548 events is a textual copy of
  the same fact and not its home.
- **A guide runner is a `Pilot` property on the participation**, a reference to another
  participant, on 270 participations; the guide is not an event participant in their own right.
- **The scope, incident and Winner layers are not written.**

### The whole catalogue, decided on the day the sport was opened

Para Athletics is the first sport opened under the whole-catalogue rule of `GLOBAL_DQ/README.md`
"Mandatory templates", so every one of the 164 GLOBAL templates has a record behind it as of
2026-09-11 and `TOOLS/Test-Package.ps1` holds the sport to that. The 49 Comp.Rank templates are
deferred under `_deferredLayers`; the three retired ones are owed by nobody; 27 are closed by
the eight parameters under `_notApplicable` in `SPORTS/params.json`, each pointing at the
section of this file that documents the absence - no deciding score, no scope layer, no full
time, no support role in the registry, no field size; `GLOBAL-DQ-009` is `Blocked` behind the
deferred layer as on Shooting and Para Swimming; six are `Not applicable` by signal; and 82 are
instantiated as `Para-Athletics-DQ-001` to `-082`, numbered in the order of the templates.

Every template was run before it was numbered, the whole catalogue in one four-minute batch,
and every result over 200 rows was read. The user decided them in five groups.

**Six `Not applicable` by signal, with the reading in `_checkSignal`:** `GLOBAL-DQ-019
EVENT_DURATION_FORMAT_MISMATCH_TO_RANK` (the sport writes absolute times, 6286 of 6320
reported), `GLOBAL-DQ-093 EVENT_RESULTS_MEDAL_SET_INVALID_FOR_MEDAL_ROUND`, `GLOBAL-DQ-096
EVENT_NAME_DOES_NOT_NAME_ITS_PARTICIPANTS` and `GLOBAL-DQ-144
EVENT_RESULTS_RANK_STORED_BY_A_HEAD_TO_HEAD_SPORT` (head-to-head sports only; the last
exhausted the server's memory before reporting the whole population), `GLOBAL-DQ-152
EVENT_RESULTS_CLOCK_VALUE_IN_JUDGED_DISCIPLINE` (judged disciplines only, and the template
says a timed sport must not instantiate it; 6324 reported) and `GLOBAL-DQ-127
EVENT_RESULTS_TIED_VALUE_WITHOUT_SHARED_RANK` (354 events where the same time to the hundredth
holds adjacent places, separated by a thousandth or a photo finish the database does not
store, the same reading as Shooting's count-back).

**Two templates were changed for this sport before instantiation.** `GLOBAL-DQ-015` and
`GLOBAL-DQ-161` gained `DISCIPLINE_SPORT_ID_LIST`, because this sport's disciplines are
Athletics' and the first run read every event as foreign; see Generic relations and disciplines.
With `4, 112` declared, `GLOBAL-DQ-015` reports 1762: 1116 events with no discipline, 74
pointing at id `0`, and 572 pointing at Speed Skating's and Mountain Bike's same-named
distances. All three are defects, none is the sport's shape, and it is instantiated as
`Actionable`.

**The readings behind the large counts**, each decided 2026-09-11:

| Check | Template | Reported | Reading and signal |
|---|---|---:|---|
| `Para-Athletics-DQ-006` | `GLOBAL-DQ-007 PARTICIPANT_MISSING_DATE_OF_BIRTH` | 2837 of 6610 | mandatory for every sport; `Actionable` |
| `Para-Athletics-DQ-038` | `GLOBAL-DQ-074 EVENT_MISSING_VENUE` | 7733 of 7733 | no event carries a venue; the user chose `Actionable` as on Ice Hockey rather than the sentinel Para Swimming carries, because an event should say where it was held |
| `Para-Athletics-DQ-058` | `GLOBAL-DQ-130 EVENT_PARTICIPANT_ORGANIZATION_MISSING` | 7525 of 7525 | the organisation is unfilled throughout; `Actionable`, by the standing decision that an empty organisation is a defect |
| `Para-Athletics-DQ-068` | `GLOBAL-DQ-147 TOURNAMENT_PARTICIPANT_ORGANIZATION_MISSING_THROUGHOUT` | 75 of 76 | the same absence at tournament level; `Actionable` |
| `Para-Athletics-DQ-075` | `GLOBAL-DQ-157 PARTICIPANT_DISABILITY_CLASS_MISSING` | 3453 of 6561 | half the registry holds no class; `Actionable` |
| `Para-Athletics-DQ-077` | `GLOBAL-DQ-159 EVENT_DISABILITY_CLASS_NOT_IN_SPORT_VOCABULARY` | 710 of 7616 | every row is the Cyrillic `Т11`; one correction, `Actionable` |
| `Para-Athletics-DQ-080` | `GLOBAL-DQ-162 EVENT_PARTICIPANT_DISABILITY_CLASS_CONTRADICTS_THE_EVENTS` | 2412 of 11441 | 552 are `Т11` again, about 1500 are a combined-class event entered by a member of the class, the rest a held class differing from the entered one; `Monitor` |
| `Para-Athletics-DQ-050` | `GLOBAL-DQ-118 EVENT_ROUND_TYPE_KNOCKOUT_FLAG_CONTRADICTS_ROUND_DETAIL` | 571 of 5407 | every semi-final and qualifier, no knockout flag anywhere; `Actionable`, as Ice Hockey decided the same shape |
| `Para-Athletics-DQ-052` | `GLOBAL-DQ-120 EVENT_RESULTS_NUMERIC_WRITTEN_FORM_INCONSISTENT` | 792 of 7048 | `11.2` beside `11.23` in one event; a hand-timed and an automatic mark differ legitimately and nothing says which is which; `Monitor` |
| `Para-Athletics-DQ-053` | `GLOBAL-DQ-122 EVENT_RESULTS_RANK_WITHOUT_DECIDING_VALUE` | 433 of 7519 | a place with no time or mark, Para Asian Games 2010 and 2014 and the ParaPan American Games above all; `Actionable` |
| `Para-Athletics-DQ-055` | `GLOBAL-DQ-124 EVENT_RESULTS_INTEGER_FIELD_FRACTIONAL` | 232 of 7519 | times written into `102 Points`; `Actionable` |
| `Para-Athletics-DQ-082` | `GLOBAL-DQ-164 EVENT_RESULTS_COMMENT_INVALID_OR_CONTRADICTED_BY_DURATION` | 318 of 21256 | as on Para Swimming: no-result statuses beside a Rank, and values outside the vocabulary; `Actionable` |
| `Para-Athletics-DQ-036` | `GLOBAL-DQ-071 EVENT_NO_PARTICIPANTS` | 208 of 7733 | 178 not started or cancelled, 30 finished with nobody in them; `Actionable` |
| `Para-Athletics-DQ-010` | `GLOBAL-DQ-015 EVENT_SETTINGS_DISCIPLINE_MISSING_UNRESOLVED_OR_FOREIGN` | 1762 of 7733 | read above; `Actionable` |

The other 68 instantiated templates returned under 200 rows or nothing, and are `Actionable`
with the default expectation of zero. The full instantiation:

| CheckID | Template | Reported | Signal |
|---|---|---:|---|
| `Para-Athletics-DQ-001` | `GLOBAL-DQ-001` | 2 of 20 | Actionable |
| `Para-Athletics-DQ-002` | `GLOBAL-DQ-002` | 12 of 94 | Actionable |
| `Para-Athletics-DQ-003` | `GLOBAL-DQ-003` | 1 of 94 | Actionable |
| `Para-Athletics-DQ-004` | `GLOBAL-DQ-005` | 0 of 94 | Actionable |
| `Para-Athletics-DQ-005` | `GLOBAL-DQ-006` | 0 of 7733 | Actionable |
| `Para-Athletics-DQ-006` | `GLOBAL-DQ-007` | 2837 of 6610 | Actionable |
| `Para-Athletics-DQ-007` | `GLOBAL-DQ-008` | 3 of 6659 | Actionable |
| `Para-Athletics-DQ-008` | `GLOBAL-DQ-013` | 2 of 20 | Actionable |
| `Para-Athletics-DQ-009` | `GLOBAL-DQ-014` | 0 of 82 | Actionable |
| `Para-Athletics-DQ-010` | `GLOBAL-DQ-015` | 1762 of 7733 | Actionable |
| `Para-Athletics-DQ-011` | `GLOBAL-DQ-016` | 0 of 7733 | Actionable |
| `Para-Athletics-DQ-012` | `GLOBAL-DQ-017` | 31 of 7555 | Actionable |
| `Para-Athletics-DQ-013` | `GLOBAL-DQ-018` | 0 of 13762 | Actionable |
| `Para-Athletics-DQ-014` | `GLOBAL-DQ-020` | 13 of 7519 | Actionable |
| `Para-Athletics-DQ-015` | `GLOBAL-DQ-021` | 10 of 7519 | Actionable |
| `Para-Athletics-DQ-016` | `GLOBAL-DQ-034` | 70 of 94 | Actionable |
| `Para-Athletics-DQ-017` | `GLOBAL-DQ-036` | 59 of 47789 | Actionable |
| `Para-Athletics-DQ-018` | `GLOBAL-DQ-037` | 3 of 4659 | Actionable |
| `Para-Athletics-DQ-019` | `GLOBAL-DQ-038` | 22 of 4659 | Actionable |
| `Para-Athletics-DQ-020` | `GLOBAL-DQ-039` | 0 of 2896 | Actionable |
| `Para-Athletics-DQ-021` | `GLOBAL-DQ-043` | 1 of 47789 | Actionable |
| `Para-Athletics-DQ-022` | `GLOBAL-DQ-047` | 0 of 149 | Actionable |
| `Para-Athletics-DQ-023` | `GLOBAL-DQ-048` | 0 of 13 | Actionable |
| `Para-Athletics-DQ-024` | `GLOBAL-DQ-049` | 161 of 736 | Actionable |
| `Para-Athletics-DQ-025` | `GLOBAL-DQ-050` | 0 of 94 | Actionable |
| `Para-Athletics-DQ-026` | `GLOBAL-DQ-053` | 0 of 13762 | Actionable |
| `Para-Athletics-DQ-027` | `GLOBAL-DQ-055` | 1 of 7525 | Actionable |
| `Para-Athletics-DQ-028` | `GLOBAL-DQ-058` | 48 of 112 | Actionable |
| `Para-Athletics-DQ-029` | `GLOBAL-DQ-059` | 0 of 7524 | Actionable |
| `Para-Athletics-DQ-030` | `GLOBAL-DQ-061` | 146 of 7704 | Actionable |
| `Para-Athletics-DQ-031` | `GLOBAL-DQ-062` | 19 of 7733 | Actionable |
| `Para-Athletics-DQ-032` | `GLOBAL-DQ-063` | 2 of 89 | Actionable |
| `Para-Athletics-DQ-033` | `GLOBAL-DQ-067` | 0 of 54 | Actionable |
| `Para-Athletics-DQ-034` | `GLOBAL-DQ-068` | 3 of 66 | Actionable |
| `Para-Athletics-DQ-035` | `GLOBAL-DQ-069` | 0 of 47763 | Actionable |
| `Para-Athletics-DQ-036` | `GLOBAL-DQ-071` | 208 of 7733 | Actionable |
| `Para-Athletics-DQ-037` | `GLOBAL-DQ-073` | 2 of 2896 | Actionable |
| `Para-Athletics-DQ-038` | `GLOBAL-DQ-074` | 7733 of 7733 | Actionable |
| `Para-Athletics-DQ-039` | `GLOBAL-DQ-075` | 0 of 7733 | Actionable |
| `Para-Athletics-DQ-040` | `GLOBAL-DQ-076` | 122 of 7519 | Actionable |
| `Para-Athletics-DQ-041` | `GLOBAL-DQ-078` | 0 of 22 | Actionable |
| `Para-Athletics-DQ-042` | `GLOBAL-DQ-079` | 0 of 7 | Actionable |
| `Para-Athletics-DQ-043` | `GLOBAL-DQ-080` | 0 of 87 | Actionable |
| `Para-Athletics-DQ-044` | `GLOBAL-DQ-081` | 5 of 14 | Actionable |
| `Para-Athletics-DQ-045` | `GLOBAL-DQ-082` | 65 of 71 | Actionable |
| `Para-Athletics-DQ-046` | `GLOBAL-DQ-097` | 2 of 6 | Actionable |
| `Para-Athletics-DQ-047` | `GLOBAL-DQ-104` | 0 of 7525 | Actionable |
| `Para-Athletics-DQ-048` | `GLOBAL-DQ-109` | 0 of 6539 | Actionable |
| `Para-Athletics-DQ-049` | `GLOBAL-DQ-112` | 0 of 66 | Actionable |
| `Para-Athletics-DQ-050` | `GLOBAL-DQ-118` | 571 of 5407 | Actionable |
| `Para-Athletics-DQ-051` | `GLOBAL-DQ-119` | 69 of 7519 | Actionable |
| `Para-Athletics-DQ-052` | `GLOBAL-DQ-120` | 792 of 7048 | Monitor |
| `Para-Athletics-DQ-053` | `GLOBAL-DQ-122` | 433 of 7519 | Actionable |
| `Para-Athletics-DQ-054` | `GLOBAL-DQ-123` | 3 of 6659 | Actionable |
| `Para-Athletics-DQ-055` | `GLOBAL-DQ-124` | 232 of 7519 | Actionable |
| `Para-Athletics-DQ-056` | `GLOBAL-DQ-128` | 1 of 1680 | Actionable |
| `Para-Athletics-DQ-057` | `GLOBAL-DQ-129` | 0 of 7525 | Actionable |
| `Para-Athletics-DQ-058` | `GLOBAL-DQ-130` | 7525 of 7525 | Actionable |
| `Para-Athletics-DQ-059` | `GLOBAL-DQ-132` | 3 of 3 | Actionable |
| `Para-Athletics-DQ-060` | `GLOBAL-DQ-133` | 1 of 18 | Actionable |
| `Para-Athletics-DQ-061` | `GLOBAL-DQ-137` | 10 of 7525 | Actionable |
| `Para-Athletics-DQ-062` | `GLOBAL-DQ-138` | 0 of 2896 | Actionable |
| `Para-Athletics-DQ-063` | `GLOBAL-DQ-139` | 0 of 18 | Actionable |
| `Para-Athletics-DQ-064` | `GLOBAL-DQ-140` | 0 of 18 | Actionable |
| `Para-Athletics-DQ-065` | `GLOBAL-DQ-141` | 4 of 7108 | Actionable |
| `Para-Athletics-DQ-066` | `GLOBAL-DQ-142` | 0 of 6409 | Actionable |
| `Para-Athletics-DQ-067` | `GLOBAL-DQ-146` | 51 of 51 | Actionable |
| `Para-Athletics-DQ-068` | `GLOBAL-DQ-147` | 75 of 76 | Actionable |
| `Para-Athletics-DQ-069` | `GLOBAL-DQ-148` | 0 of 7519 | Actionable |
| `Para-Athletics-DQ-070` | `GLOBAL-DQ-149` | 43 of 76 | Actionable |
| `Para-Athletics-DQ-071` | `GLOBAL-DQ-151` | 21 of 6610 | Actionable |
| `Para-Athletics-DQ-072` | `GLOBAL-DQ-153` | 40 of 93 | Actionable |
| `Para-Athletics-DQ-073` | `GLOBAL-DQ-155` | 83 of 7524 | Actionable |
| `Para-Athletics-DQ-074` | `GLOBAL-DQ-156` | 117 of 7733 | Actionable |
| `Para-Athletics-DQ-075` | `GLOBAL-DQ-157` | 3453 of 6561 | Actionable |
| `Para-Athletics-DQ-076` | `GLOBAL-DQ-158` | 55 of 548 | Actionable |
| `Para-Athletics-DQ-077` | `GLOBAL-DQ-159` | 710 of 7616 | Actionable |
| `Para-Athletics-DQ-078` | `GLOBAL-DQ-160` | 9 of 7616 | Actionable |
| `Para-Athletics-DQ-079` | `GLOBAL-DQ-161` | 0 of 5971 | Actionable |
| `Para-Athletics-DQ-080` | `GLOBAL-DQ-162` | 2412 of 11441 | Monitor |
| `Para-Athletics-DQ-081` | `GLOBAL-DQ-163` | 5 of 7733 | Actionable |
| `Para-Athletics-DQ-082` | `GLOBAL-DQ-164` | 318 of 21256 | Actionable |

`GLOBAL-DQ-007` and `GLOBAL-DQ-151` run with their Comp.Rank branch dropped, as the optional
branch contract provides while the layer is deferred; the runner reports the narrowing on every
run.

<!-- MANUAL PASTE ZONE: 112 STORAGE SEMANTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Open questions

**Nothing here is open.** The five questions the opening raised on 2026-09-11 were measured and
decided the same afternoon, and each is kept with what closed it rather than deleted, because
the reason a question stopped being open is the part nobody can reconstruct from the answer.
Four closed by measurement and one by a decision of the user's, recorded with the alternative
that was rejected.

1. **What `537 Top attempts` and `538 Zone attempts` hold on their twenty rows of 2018-10-08.**
   *Closed: the results of another race of the same day.* Not a guide's record, which was the
   first reading: the named person is a competitor of the same games with exactly that time in
   the 1500 m or the other 400 m heats, on one row the athlete himself, and one of them is a
   wheelchair racer who has no guide. Recorded under Event results, together with the one row
   whose `101 Duration` holds the wrong race's time.
2. **Whether the spacing variants of a combined Comment are a vocabulary or a defect.** *Closed
   by decision: a defect.* `Para-Athletics-DQ-082` keeps reporting the 128 rows; admitting the
   32 forms into the vocabulary was the rejected alternative. Recorded under Event results.
3. **What `object_relation` type 2 to type 152 carries on 18 rows.** *Closed, and the question
   had a wrong word in it.* Type 2 is the tournament template, and the pair is the documented
   template-subset path: six competitions in three genders, six sub-sets under four sets.
   Recorded under Generic relations and disciplines.
4. **Why 572 events point at Speed Skating's and Mountain Bike's disciplines.** *Closed: a
   lookup by name on the historical backfill.* Only Paris 2024, loaded first, carries the
   Athletics ids; the 37 tournaments behind it carry the foreign ones on every event, and no
   event carries both. Recorded under Generic relations and disciplines;
   `Para-Athletics-DQ-010` reports the rows.
5. **How many of the 117 events without a class state one in their own name.** *Closed: 113,
   and the four that do not are the universal relays of Paris 2024 and one seated shot put.*
   `Para-Athletics-DQ-074` already reports the two states apart. Recorded under Disability
   class.

<!-- MANUAL PASTE ZONE: 112 OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
