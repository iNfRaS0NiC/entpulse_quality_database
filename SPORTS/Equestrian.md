# SPORT: Equestrian (sport_id=37)

This file is the canonical structural record for Equestrian. It contains only confirmed
sport-specific usage, meanings, identifiers, evidence boundaries and open structural
questions. Global database mechanisms belong in `../DATABASE.md`.

For additions, insert approved content immediately before the exact active
`MANUAL PASTE ZONE` marker in the destination subsection. Keep the marker unchanged
and at the end of its subsection. Replace existing rows or paragraphs in place when a
correction is required.

## Identity and evidence

- First discovery date: 2026-08-18
- Latest evidence date: 2026-08-18
- Verification boundary: the full `GLOBAL-DISCOVERY` catalogue was run for the sport and
  every statement returned; none failed. Drill-down statements were chained on the three
  values each summary ranks first, so every **summary** below is complete coverage while
  every **detail** is a sample. Where a detail decided something, it was re-run for the
  value that decided it, and that is said where it applies.

**Four sports share this `sport.id`.** `object_discipline` separates Jumping, Dressage,
Eventing and Driving, and they are contested under different templates with different result
vocabularies. The sport is documented whole; a check written for one discipline says so.

## Structural coverage

| Area | Status | Evidence |
|---|---|---|
| Core hierarchy | Used | 92 templates, 5694 events under `tt.sportFK = 37` |
| Event participants | Used | `athlete` and `team` only; the horse is a reference, not a row |
| Event results | Used | 12 active result types |
| Incidents | Not used | The complete-layer query returned zero active rows |
| Lineups | Used | One type, `14 Starter`, athletes under a team parent |
| Scope layer | Used | Four containers and one value in the whole sport |
| Properties | Used | Five owner objects, including `event_participants` and `lineup` |
| object_relation | Used | Six active source/target combinations |
| object_discipline | Used | 13 disciplines on events, 8 on statistics |
| Statistics | Used | One type/owner pair, one physical shard |
| Reference values | Used | Round types, statuses and the result comment vocabulary |
| Other tables | Not checked | |

## Tables and relation paths used

The sport uses the standard hierarchy without deviation:
`tournament_template -> tournament -> tournament_stage -> event -> event_participants`,
anchored on `tt.sportFK = 37`.

**The rider-and-horse pair is stored three times, by three different mechanisms.** No two of
them are the same construction, and a statement asserting the pair has to name which one it
reads:

| Layer | Mechanism | Coverage measured 2026-08-18 |
|---|---|---|
| `event_participants` | `property` of type `ref:participant` named `horseFK`, value holding a `participant.id` | 114507 of 115243 athlete participations resolve to an active horse |
| `lineup` | the same `horseFK` reference property, owned by the lineup row | 17967 of 18145 lineup rows resolve to an active horse |
| Comp.Rank | the horse is a real `statistic_participants11` row, bound to its rider by a shared `statistic_data11` field `1276 Pair` | 11978 pairs hold exactly one athlete and one horse |

`../DATABASE.md` section 6 owns the reference-property mechanism itself, which is global and
not this sport's. What is this sport's is that it uses all three at once.

<!-- MANUAL PASTE ZONE: 37 TABLES AND RELATIONS — insert approved additions immediately before this marker; do not move or delete it. -->

## Participant and lineup structure

**`event_participants` carries only `athlete` and `team`.** A horse is never an event
participant. It is reached from the participation through the `horseFK` property, so a
statement counting horses at event level counts nothing, and a statement joining
`participant.type = 'horse'` to `event_participants` returns an empty set. Both were run and
both did.

| `participant.type` | Gender | Participants | Participations |
|---|---|---:|---:|
| `athlete` | male | 5189 | 65274 |
| `athlete` | female | 5913 | 49969 |
| `team` | mixed | 186 | 5448 |
| `team` | male | 1 | 1 |

**The registry knows the horses; the event layer does not.** `object_participants` for
`object = 'sport'`, `objectFK = 37` holds three roles - `athlete`, `horse` and `team` - and
the horses are the largest of the three at 25571 registry rows. Horse gender is its own
vocabulary: `gelding`, `mare`, `stallion`, `male`, `female` and `undefined` all occur.

**What `horseFK` resolves to, measured 2026-08-18:**

| Owner | Reference state | Count |
|---|---|---:|
| `event_participants` | resolves to an active horse | 114507 participations |
| `event_participants` | points at a participant that does not exist | 272 |
| `event_participants` | property absent entirely | 227 |
| `event_participants` | present but empty or `0` | 222 |
| `event_participants` | points at a participant that is not a horse | 15 |
| `lineup` | resolves to an active horse | 17967 rows |
| `lineup` | property absent entirely | 154 |
| `lineup` | points at a participant that does not exist | 24 |

The failure shapes are different defects with different causes, and a statement testing only
for presence reports the first and misses the rest. Team participations carry no `horseFK`
and correctly so - a team does not ride.

**Lineups are the team's rider-and-horse pairs.** One lineup type is in use, `14 Starter`,
its parent event participant is always a `team`, and its members are always `athlete`. Each
member carries its own `horseFK`, so the lineup is a list of pairs rather than a list of
people, which is the structure the sport actually competes in.

<!-- MANUAL PASTE ZONE: 37 PARTICIPANTS AND LINEUPS — insert approved additions immediately before this marker; do not move or delete it. -->

## Event result types

Twelve result types are active. **Three are in scope for the current client's checks -
`100 Rank`, `644 Score` and `104 Comment`** - decided 2026-08-18. The other nine are
documented because they are real and another client may take them; nothing is written on
them now.

| result_code | result_typeFK | Value shape | Confirmed meaning | In scope | Evidence |
|---|---:|---|---|---|---|
| `rank` | 100 | `#` | Finishing place; the field ranks whole | **yes** | 109933 values, 5511 events |
| `score` | 644 | `#.#`, `#.#.#`, invisible | Dressage mark; see the two shapes below | **yes** | 29294 values, 2125 events |
| `comment` | 104 | 31 distinct values | Status vocabulary; see Reference values | **yes** | 12395 values, 2916 events |
| `errors` | 312 | `+ #` | Jumping faults | no | 10581 values, 396 events |
| `duration` | 101 | `#.#`, `+#.#` | Time, and time behind | no | 7252 values, 254 events |
| `medal` | 501 | `gold`/`silver`/`bronze` | Medal | no | 6125 values, 2060 events |
| `points` | 102 | `#` | Points | no | 1959 values, 64 events |
| `runningscore` | 6 | `#.#`, `#,#` | Running score | no | 1812 values, 96 events |
| `jump_off_penalties` | 515 | `#` | Jump-off faults | no | 655 values, 79 events |
| `jump_off_time` | 516 | `#.#` | Jump-off time | no | 601 values, 73 events |
| `startnumber` | 408 | `#` | Start order | no | 493 values, 63 events |
| `penalties` | 545 | `#` | Penalties | no | 196 values, 3 events |

**`644 Score` is written in two unusual shapes and only one of them is a defect.**

The first is `#.#.#` - two three-decimal numbers with no separator, such as `72.750` followed
by `80.000` in one field. Measured 2026-08-18 it holds 226 values across exactly 15 events,
**every one of them a Grand Prix Freestyle**, and in 14 of the 15 it reaches the entire field:
18 of 18, 17 of 17, 15 of 15, with the one exception carrying no score at all rather than a
plain one. Not a single competitor in any of those events holds a single number. A shape that
reaches a whole field is a format and not a mistake - the discriminator `../POWERBI.md`
records for `Golf-DQ-101` - so **these 226 are the sport writing two marks, not 226 broken
values.**

**`644 Score` is therefore not recorded in `NUMERIC_RESULT_TYPE_LIST`.** Decided 2026-08-18.
`GLOBAL-DQ-076 EVENT_RESULTS_NUMERIC_FIELD_NON_NUMERIC`, which flags text stored in a numeric
result field, rejects a second decimal point and would report every Freestyle card in the
sport, for ever and wrongly. The sport's other numeric result types were not taken into the
client's scope, so the parameter has no value left to carry and is left unwritten rather than
half-filled.

The second shape is a defect: 69 values across 4 events, all in `Asian Games Eventing` between
2008 and 2019, whose entire content is one `U+00A0` non-breaking space, stored as `C2A0`. It
is neither `NULL` nor empty, so `TRIM()` does not remove it and a naive blank test reads it as
populated. `GLOBAL-DQ-069 EVENT_RESULTS_VALUE_BLANK` already replaces that byte sequence
explicitly and classifies it `BLANK_INVISIBLE_CHARACTER`, so the shape needs no new check.

<!-- MANUAL PASTE ZONE: 37 EVENT RESULTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Incident types

**Not used.** The complete-layer inventory returned zero active incident rows for the sport.

<!-- MANUAL PASTE ZONE: 37 INCIDENTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Scope types and data types

**Present but effectively unused.** The whole sport holds four `event_scope` containers, all
of type `305 final_result`, and one value beneath them: a `scope_result` row of scope data
type `443 fence17` reading `R`, on event `2677424 XC Fences`. `lineup_scope_result` and
`event_scope_detail` were not separately inventoried.

Four containers is not a storage layer a check can be built on, and this is recorded so the
next reader does not re-derive it.

<!-- MANUAL PASTE ZONE: 37 SCOPES — insert approved additions immediately before this marker; do not move or delete it. -->

## Properties

Five owner objects carry properties. `event_participants` and `lineup` are the two the GLOBAL
catalogue could not see before 2026-08-18; `GLOBAL-DISCOVERY-011` now inventories the first.

| Owner | Type | Name | Rows | Owners |
|---|---|---|---:|---:|
| `event_participants` | `ref:participant` | `horseFK` | 115016 | 115016 |
| `lineup` | `ref:participant` | `horseFK` | 17991 | 17991 |
| `participant` | `metadata` | `status` | 11102 | 11102 |
| `participant` | `metadata` | `date_of_birth` | 10878 | 10878 |
| `event` | `metadata` | `Live` | 5694 | 5694 |
| `event` | `metadata` | `Round` | 2694 | 2694 |
| `event` | `metadata` | `medal_related` | 2005 | 2005 |
| `event` | `metadata` | `ParticipantType` | 571 | 571 |
| `participant` | `metadata` | `height` | 516 | 516 |
| `participant` | `metadata` | `weight` | 512 | 512 |
| `event` | `metadata` | `discipline` | 363 | 363 |
| `participant` | `metadata` | `discipline` | 187 | 187 |
| `participant` | `metadata` | `IsNationalTeam` | 187 | 187 |
| `event` | `metadata` | `jump_off` | 116 | 116 |
| `event` | `metadata` | `Type` | 92 | 92 |
| `event` | `metadata` | `Verified` | 14 | 14 |
| `tournament_stage` | `metadata` | `StatusComment` | 5 | 5 |
| `event` | `metadata` | `ElapsedTime` | 2 | 2 |
| `participant` | `metadata` | `ToBeDecided` | 2 | 2 |
| `tournament_stage` | `metadata` | `Cup` | 1 | 1 |
| `participant` | `metadata` | `place_of_birth` | 1 | 1 |
| `participant` | `metadata` | `professional_status` | 1 | 1 |

The `discipline` property on 363 events is the legacy path `../DATABASE.md` `DB-SEM-019`
describes. The relation is what this sport means; the property is not read.

<!-- MANUAL PASTE ZONE: 37 PROPERTIES — insert approved additions immediately before this marker; do not move or delete it. -->

## Generic relations and disciplines

`object_relation`, active combinations:

| Source type | Target type | Rows | Meaning |
|---:|---:|---:|---|
| 1 `sport` | 153 `category` | 1 | The sport's Olympic marking |
| 2 `tournament_template` | 152 `tournament_sub_set` | 87 | Template subset |
| 4 `tournament_stage` | 151 `tournament_age_class` | 3386 | Stage age class |
| 4 `tournament_stage` | 33 `country` | 1 | Host country relation |
| 83 `statistic` | 33 `country` | 431 | Comp.Rank country |
| 83 `statistic` | 151 `tournament_age_class` | 431 | Comp.Rank age class |

`object_discipline` is what separates the four sports inside `sport_id = 37`:

| Discipline | id | Events | Statistics |
|---|---:|---:|---:|
| Jumping | 426 | 2536 | 357 |
| Dressage | 425 | 2451 | 3 |
| Eventing | 424 | 333 | 36 |
| Show Jumping | 69 | 242 | 17 |
| Dressage Grand Prix | 71 | 50 | |
| 3Day Event Dressage | 73 | 22 | |
| Dressage Grand Prix Freestyle | 70 | 16 | 4 |
| 3Day Event Jumping | 74 | 12 | 3 |
| Dressage Grand Prix Special | 75 | 10 | 7 |
| 3Day Event Cross Country | 72 | 9 | |
| Cross Country Fences | 347 | 8 | |
| Driving | 428 | 4 | 4 |
| Cross Country | 402 | 1 | |

Every stage gender in the discipline matrix is `mixed`; the sport contests men and women in
one field, which is why no gender-split check has an eligible population here.

<!-- MANUAL PASTE ZONE: 37 GENERIC RELATIONS AND DISCIPLINES — insert approved additions immediately before this marker; do not move or delete it. -->

## Statistics

| statistic_typeFK | Owner type | Participant shard | Data shard | Fields/config | Evidence |
|---:|---:|---:|---:|---|---|
| 11 (Comp.Rank) | 3 `tournament` | 11 | 11 | 12 data fields, 4 config fields | 630 statistics |

`GLOBAL-DISCOVERY-015` returned exactly one type/owner pair, so nothing was chosen and there
is no alternative to record.

**The shard is 11 and had to be measured rather than probed.** The runner's automatic probe
reported that no shard held rows for its sample statistic and left `SHARD_ID` unresolved; the
sample it picked happens to be one of the statistics with no participant rows. Joining the
sport's registered horses to `statistic_participants11` directly returned 18793 rows, which
settled it. `../DATABASE.md` `DB-SEM-006` already records that the statistic type does not
determine the shard; this is a case where the probe's own sample was the problem.

Comp.Rank participant rows by type, IOC templates excluded:

| Type | Rows | Participants | Statistics |
|---|---:|---:|---:|
| `athlete` | 12077 | 2598 | 377 |
| `horse` | 12428 | 5145 | 355 |
| `team` | 457 | 104 | 40 |

Data fields in use on `statistic_data11`, with the six taken into the client's scope marked:

| id | Name | Values | Statistics | In scope | Value shape |
|---:|---|---:|---:|---|---|
| 1276 | **Pair** | 36463 | 512 | **yes** | `#` |
| 1270 | **Rank** | 30469 | 571 | **yes** | `#` |
| 1429 | **Team** | 6870 | 69 | **yes** | `#`, a `participant.id` |
| 1273 | **Comment** | 3641 | 357 | **yes** | status words |
| 1277 | **Medal** | 3144 | 452 | **yes** | `gold`/`silver`/`bronze` only |
| 1271 | **Points** | 3087 | 72 | **yes** | `#.#`, `#` |
| 1403 | Penalties | 1270 | 32 | no | |
| 1473 | Score | 595 | 9 | no | |
| 1426 | Time | 334 | 11 | no | |
| 1474 | Percentage | 232 | 7 | no | |
| 1477 | Jump Off Time | 24 | 3 | no | |
| 1478 | Jump Off Penalties | 24 | 3 | no | |

`statistic_config` carries four fields on 431 of the 630 statistics: `1463 Start date`,
`1464 End date`, `1470 Gender` and `1471 Event id`. Twenty-nine further data types are
declared for statistic type 11 and hold no value in this sport.

**`1276 Pair` is the field that binds a rider to a horse.** Grouped by statistic and value it
composes as follows, measured 2026-08-18 with IOC templates excluded:

| Composition | Pairs | Statistics |
|---|---:|---:|
| one athlete and one horse | 11978 | 374 |
| one horse alone | 418 | 91 |
| one athlete alone | 27 | 25 |
| two horses and no rider | 2 | 2 |

Team participant rows carry no `Pair` value at all, which is correct: a team classification
row is not a ride.

<!-- MANUAL PASTE ZONE: 37 STATISTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Reference values

**Event statuses.** Three are in use: `finished` / `6 Finished` on 5512 events, `notstarted` /
`1 Not started` on 149, and `cancelled` / `106 Cancelled` on 33.

**The `104 Comment` vocabulary is 31 values and it is not one vocabulary.** Grouped by what
each value means, with the years and the number of templates each appears in:

| Meaning | Standard | Live duplicates of the same meaning |
|---|---|---|
| Retired | `Retired` - 5222, 2004-2026, 68 templates | `RET` 95 (2008-2024) · `RT` 4 (**2026 only**) |
| Eliminated | `EL` - 3881, 2004-2026, 69 templates | `Eliminated` 214 (2004-2026) · `ELM` 9 (2021-2025) |
| Withdrawn | `WD` - 1608, 2004-2026, 66 templates | `Withdrawn` 2 (2016-2025) |
| Disqualified | `DSQ` - 355, 2004-2026, 43 templates | `Disq.` 4 (2004 only) |

**The duplicates are not a replaced legacy vocabulary; they are still being written.** `RT`
first appears in 2026, and `Eliminated` has run beside `EL` for twenty-two years. The majority
is the convention by 55:1 for `RET` and 1300:1 for `RT`, which is the ratio `../POWERBI.md`
records as telling a convention from a defect for `Golf-DQ-103`.

Three groups of values are **not** duplicates and must not be folded into the above:

- **The Jump-Off family**, almost all 2025-2026: `Jump-Off` 38, `EL Jump-Off` 9,
  `WD Jump-Off` 5, `Retired Jump-Off` 6, `From Jump-Off 1` to `From Jump-Off 4`,
  `WD Jump-Off 1` to `WD Jump-Off 4`, and `Retired Jump-Off 3`. This is a newer convention
  carrying which jump-off the outcome belongs to, not a corruption of an older one.
- **Distinct meanings**: `Q` 800 (qualified, 3 templates), `DNF` 16, `DNS` 4,
  `Not Accepted` 6, `SUBST` 1, `A` 79, `Round 1` 9.
- **One value that is neither**: `u00a0`, 2 values in 2011 and 2018 - an escaped
  non-breaking space written into the field as literal text.

**Round types**, all 13 in use:

| id | Name | Events |
|---:|---|---:|
| 173 | Final | 5035 |
| 0 | *(none)* | 340 |
| 285 | Jumping | 87 |
| 179 | Qualifier | 79 |
| 177 | Overall Classification | 75 |
| 183 | Pre-final | 23 |
| 291 | Dressage | 18 |
| 289 | Cross Country | 15 |
| 287 | XC Fences | 8 |
| 9 | Final | 5 |
| 38 | 1 | 3 |
| 39 | 2 | 3 |
| 265 | Final A | 3 |

Two distinct ids are both named `Final`, `173` and `9`, which is the shape `../DATABASE.md`
`DB-SEM-012` describes.

<!-- MANUAL PASTE ZONE: 37 REFERENCE VALUES — insert approved additions immediately before this marker; do not move or delete it. -->

## Event and round representation

**340 events carry `round_typeFK = 0`** - no round type at all, rather than one that no longer
exists. The gap is live and not a historical import: it runs unbroken from 2004 to 2027 across
31 of the 92 templates, most heavily `FEI Jumping World Cup Western European League` with 80.
By status it is 241 `finished`, 98 `notstarted` and 1 `cancelled`, and 90 of the events fall in
2026 and 2027. `GLOBAL-DQ-006 EVENT_MISSING_ROUND_TYPE` reports the whole population; the sport
is documented as one gap rather than split by status, decided 2026-08-18.

The commonest event names among them are `World Cup Table A` 38, `GP - Grand Prix` 30 and
`GP FS - Grand Prix Freestyle to Music` 29 - competition formats, so the name does not stand in
for the missing round type.

**Name patterns.** 711 distinct event-name patterns and 566 stage-name patterns, both
summarised in full; the detail statements were chained on the three values each summary ranks
first and are samples. Event names are competition formats rather than round descriptions
(`GP - Grand Prix`, `GP FS - Grand Prix Freestyle to Music`, `World Cup Table A`), while stage
names carry the league and the venue
(`FEI Dressage World Cup North American League Wellington`).

<!-- MANUAL PASTE ZONE: 37 EVENT AND ROUND REPRESENTATION — insert approved additions immediately before this marker; do not move or delete it. -->

## Confirmed sport-specific storage semantics

**`statistic_config 1471 Event id` names one event of the tournament, not the Comp.Rank's
scope.** Established 2026-08-18 by comparing every Comp.Rank pair against the `horseFK` of the
same rider's participation in the event the config names:

| Comparison | Pairs |
|---|---:|
| Both layers name the same horse | 10233 |
| Different horse here, but the same rider and horse ride elsewhere in the tournament | 721 |
| Rider absent from that event, but competing elsewhere in the tournament | 1657 |
| Different horse, and the pair rides nowhere in the tournament | 2 |
| Rider appears in no event of the tournament | 87 |

**The storage layers agree.** What looks at first like 723 contradictions and 1744 missing
riders is almost entirely one fact: a Comp.Rank covers a tournament while its `Event id` points
at a single event inside it, so a rider legitimately rides a different horse in a different
round. The residue after that explanation is **89 pairs**, and it is named here so a later
reader does not mistake the whole 2467 for it. `../DATABASE.md` section 11 holds the open
question of where the Comp.Rank-to-events relation will finally live; this narrows it without
answering it.

**The client boundary is every template except the five `(IOC)` ones**, decided 2026-08-18:
`12779`, `12780`, `12781`, `12785` and `12787`. All five hold tournaments and no stage or
event. The exclusion is declared rather than an inclusion because it is the shorter list, and
because a template the sport gains next season is one this client does want.

**Three competitions exist three times under three template ids**, and only one copy of each is
populated:

| Competition | Populated | Empty twin | `(IOC)` twin |
|---|---:|---:|---:|
| FEI Dressage World Championships | 11466 | 10440 | 12785 |
| FEI Eventing World Championships | 11416 | 10439 | 12781 |
| FEI Jumping World Championships | 10438 | 10441 | 12787 |
| FEI World Cup Final | 10442 | — | 12780 |

The empty non-`(IOC)` twins stay inside the client boundary, decided 2026-08-18, so
`GLOBAL-DQ-001 TEMPLATE_NO_TOURNAMENTS_OR_STAGES` will report them; they are recorded here so
that report reads as a known duplication rather than as three unexplained empty templates.
Three further templates are empty without a populated twin: `10813 FEI Nations Cup` with one
tournament, `10814 World Cup` with three, and `10863 MARS Badminton` with none at all.

**The registry holds duplicate identities, and four fifths of them are horses.**
`GLOBAL-DISCOVERY-033` returned 246 name groups on 2026-08-18: 202 horses and 44 people. In 145
of them both records carry participations, so one competitor's history is split across two
identities - `Manuel Fernandez` 148 against 7, `Juan Jimenez` 73 against 2,
`Samantha McIntosh` 37 against 35, and the horse `Don Auriello` across three records at 10, 0
and 0. In the remaining 101 neither record is used. 142 of the groups carry conflicting dates
of birth, which is why nothing merged them automatically.

Two boundaries sit on that number. **The query requires a name of two parts or more**, so a
horse named in a single word is invisible to it and the true horse population is larger by an
unmeasured amount. And **no check exists for this condition in any sport**: the eight
`DUPLICATE` templates in `GLOBAL_DQ/` all assert one participant recorded twice in one place,
never two records that are one being. Building it would be a GLOBAL promotion of
`GLOBAL-DISCOVERY-033`, not an instantiation of an existing template.

<!-- MANUAL PASTE ZONE: 37 STORAGE SEMANTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Open questions

1. **Do `1276 Pair` and the lineup `horseFK` name the same horse for the same ride?** The
   comparison run on 2026-08-18 was Comp.Rank against the **event** layer, not against the
   **lineup** layer, so the third pairing has not been checked against the other two. It is
   recorded as unmeasured rather than as agreeing.

<!-- MANUAL PASTE ZONE: 37 OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
