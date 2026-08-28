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

**Where the `horseFK` failures sit decides what they are.** Measured 2026-08-18 against the
field each defective participation sits in:

| Failure | Participations | Events | Reach | Years |
|---|---:|---:|---|---|
| reference points at a participant that does not exist | 272 | 242 | part of the field | 2005-2026 |
| present but empty or `0` | 183 | 105 | part of the field | 2005-2026 |
| property absent entirely | 227 | 7 | **whole field** | 2004-2016 |
| present but empty or `0` | 39 | 2 | **whole field** | 2008-2011 |
| points at a participant that is not a horse | 15 | 1 | **whole field** | 2026 |

The first two classes sit beside riders whose horse resolves, and each is one rider's defect.
The last three take an entire field at once and are **ten events to load again rather than
281 rows to correct one by one** - seven with no horse layer written at all, two holding
nothing usable, and one from 2026 whose whole field points at participants that are not
horses. The distinction is not visible in a count and is why the two are recorded apart.

**Horse gender is written in two vocabularies at once, and they are two spellings of one
fact.** The registry holds `gelding` on 7197 horses, `male` on 7923, `mare` on 3077,
`female` on 3182, `stallion` on 2719 and `undefined` on 1474.

Measured 2026-08-18, this is not an era: both vocabularies run unbroken from 2004 to 2026,
and since 2020 the horse vocabulary carries 26099 rides against the person vocabulary's
11409. A statement asserting the horse vocabulary would therefore report 45 percent of the
register for ever, which is why none is written.

What settles their relation is the duplicate records. Of the 315 horse pairs proved to be one
animal by riding under one rider in one tournament, **106 carry the horse vocabulary on one
side and the person vocabulary on the other** - `Absolut` is `gelding` on one record and
`male` on the other, `Active Walero` `undefined` against `gelding` - and 41 more pair the
person vocabulary against `undefined`. Where two records are provably one horse, the two
vocabularies describe the same animal, so `male` and `female` are the coarser spelling rather
than a distinct meaning. Whether that is by design is a question for whoever loads the data;
it is recorded here as measured, not as decided.

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

**66312 ranked participations carry no measure at all, and neither does the field they sit in.**
Measured 2026-08-19 across 2867 events, none of which holds a single value in any of the eight
result types that measure a ride - `644 Score`, `312 Errors`, `101 Duration`, `102 Points`,
`6 Running Score`, `515 Jump Off Penalties`, `516 Jump Off Time`, `545 Penalties`. The place is
stored and nothing that produced it is:

| Discipline | Ranked participations | Events |
|---|---:|---:|
| Jumping | 55513 | 2302 |
| Dressage | 6290 | 368 |
| Eventing | 4400 | 191 |
| Driving | 79 | 4 |
| Show Jumping | 30 | 2 |

**This is the format and not a gap**, by the discriminator `../POWERBI.md` records for
`Golf-DQ-101`: the shape reaches the entire field of every one of those events rather than part
of it. Jumping is five sixths of it - the sport loaded with a place and nothing else - and the
last row is the same discipline under its second name, which
`Generic relations and disciplines` above documents.

`Equestrian-DQ-109 EVENT_RANKED_PARTICIPATION_HOLDING_NO_MEASURE_WHERE_THE_FIELD_IS_MEASURED`
therefore reports none of these. It reports only a card sitting in a field whose other members
are measured, where the event itself proves a measure was available and this one did not get
it.

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

**Only four of those thirteen values name a discipline.** Read whole on 2026-08-18, the
column holds two generations. The modern block is `424 Eventing`, `425 Dressage`,
`426 Jumping` and `428 Driving`, and it is the one the sport's separation rests on. Beside it
runs an older block, and none of its values is a fifth discipline:

| Legacy value | id | What it actually names |
|---|---:|---|
| Show Jumping | 69 | a second name for `426 Jumping` |
| Dressage Grand Prix | 71 | a dressage **test** |
| Dressage Grand Prix Freestyle | 70 | a dressage test |
| Dressage Grand Prix Special | 75 | a dressage test |
| 3Day Event Dressage | 73 | a **phase** inside eventing |
| 3Day Event Jumping | 74 | a phase inside eventing |
| 3Day Event Cross Country | 72 | a phase inside eventing |
| Cross Country | 402 | a phase inside eventing |
| Cross Country Fences | 347 | a phase inside eventing, finer still |

A test and a phase are real things and they belong somewhere; they do not belong in the
column that tells one sub-sport from another. **370 events and 31 Comp.Rank records carry
one**, against 5675 and 434 in total, so the four cover 93 percent of each layer and the
separation silently fails for the rest. Anything reading the four to place an object cannot
place those 401.

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

**The two rows of a Pair are a mirror, and the exceptions are countable.** A rider and the
horse it rode are two `statistic_participants11` rows and one competitor, so the sport writes
the ride's result into both. Measured 2026-08-18 over every Pair holding exactly one rider and
one horse:

| Data field | Pairs agreeing | Pairs contradicting | Only one side carries it |
|---|---:|---:|---:|
| Rank | 10741 | 0 | 0 |
| Team | 1507 | **20** | 0 |
| Comment | 1400 | 0 | 0 |
| Medal | 1275 | **2** | 0 |
| Penalties | 583 | 0 | 0 |
| Score | 345 | 0 | 0 |
| Time | 156 | 0 | 0 |
| Points | 149 | 0 | 0 |
| Percentage | 108 | 0 | 0 |
| Jump Off Penalties | 12 | 0 | 0 |
| Jump Off Time | 12 | 0 | 0 |

**Not once does one side hold a value the other lacks.** Eleven fields, 10741 pairs, and the
only disagreements are 20 Pairs whose rider and horse are entered on different teams and 2
whose rider and horse hold different medals. The mirror is therefore a confirmed property of
the storage rather than an assumption about it.

`1429 Team` holds a `participant.id` like any other reference, and every value carrying one
resolves to an active team.

**The Comp.Rank organization is not filled at all, and `Equestrian-DQ-120` is a sentinel because of it.** Measured 2026-08-25 this sport holds 424 tournament-owned Comp.Rank records over 25 449 ranked participations and **not one** carries an Organization value on the statistic data type the sport declares for it.

That makes `Equestrian-DQ-120 COMP.RANK_PARTICIPANT_ORGANIZATION_COUNTRY_CONTRADICTS_COMPETITOR` return an `eligible_count` of 0. It is the second of the two things a zero can be - a correct scope over a population that is legitimately empty today, not a misdirected one - and the measurement above is what settles which. The check asks whether the organization that is there is the right one; there is none to ask about. `Equestrian-DQ-112` is what reports the absence itself.

It is instantiated rather than left off on the ruling of 2026-08-25 that the field is expected to be populated, and the day it is, this is the check that reads what arrives. Four of the twelve documented sports already fill it - Artistic Gymnastics, Triathlon, Golf and Ice Hockey - and those four are exactly the four that carried this check before today.

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

**5062 of the sport's 5694 events start at exactly `14:00:00`** - 88.9%, measured 2026-08-19.
The remaining 632 spread across 126 further times, the next commonest being `12:00:00` with 88
and `15:00:00` with 42. **No event carries midnight**, which is what an unset time usually looks
like, so the column is not empty: it is filled with one value.

**Nothing may be reasoned from an event's time of day.** A check comparing two events' start
times, ordering rounds inside a day, or reading the gap between them would be reading a default
in nine cases out of ten and would report the sport rather than a defect. The date is usable and
the time is not. It is recorded here because the column looks populated, and its shape gives a
later reader no way to see otherwise.

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

**All three storage layers name the same horse for the same ride.** The comparison against the
event layer above left the lineup layer unchecked; it was measured on 2026-08-18 and the
answer is unambiguous once the two layers are asked about **one ride** rather than one
tournament.

Read at tournament level, every rider-and-horse pair a lineup names against the Comp.Rank
pairs of the same tournament:

| Comparison | Lineup pairs | Tournaments |
|---|---:|---:|
| both layers name the same horse | 1715 | 33 |
| rider paired in Comp.Rank with another horse only | 9 | 5 |
| rider absent from that tournament's Comp.Rank | 130 | 5 |
| tournament holds no Comp.Rank pair at all | 12208 | 189 |

Read at ride level - the lineup of the very event a Comp.Rank names in its
`statistic_config 1471 Event id`:

| Comparison | Lineup rides | Statistics |
|---|---:|---:|
| both layers name the same horse | **1782** | 42 |
| the two layers name different horses | **0** | - |
| rider in the lineup carries no Pair in that Comp.Rank | 1490 | 35 |

**Zero disagreements out of 1782.** The nine that differ at tournament level were read one by
one and every one is a rider on more than one horse across the tournament, several carrying
both horses inside the lineup layer itself. This is the same explanation the event-layer
comparison already required, and it closes the question that section left open.

The largest number in the first table is not a disagreement either: **189 tournaments hold
lineups and no Comp.Rank pair at all**, 12208 rides. That measures how much of the sport the
ranking layer covers, and it belongs beside the 630 Comp.Rank records against 915 tournaments
already recorded above.

**`644 Score` runs in opposite directions in the two disciplines that use it.** Measured
2026-08-19 by comparing, inside one event, every ordered pair of participations where one holds
a better rank than the other:

| Discipline | Compared pairs | Better rank holds the higher score | Better rank holds the lower score | Events |
|---|---:|---:|---:|---:|
| Dressage | 278204 | 276127 | 1826 | 1991 |
| Eventing | 56782 | 0 | 56698 | 93 |
| Jumping | 829 | 291 | 537 | 4 |

Dressage is a mark and higher wins. Eventing is a penalty total and lower wins, with **not one
pair out of 56782 going the other way**. The two are one column, and nothing in the row says
which rule applies - only the discipline of the event tells them apart. **Any statement reading
`644 Score` as good-or-bad must branch on the discipline first**, and `../GLOBAL_DQ/README.md`
holds no template that does; that is why no GLOBAL check asserts an ordering here.

**The 1826 Dressage pairs that break the rule are not a check, and will not be one.** Decided
2026-08-19. They sit in 39 events between 2007 and 2025, and what ordered those fields is not in
the database: a Freestyle carries two marks in one field, a final can be ordered by an earlier
round, a total can be carried in from outside the event. The candidate was written, run, read
and withdrawn because the input it would audit is inconsistent and the question is outside what
the client asks today. It is recorded so the next reader who measures the same 1826 knows they
were seen and why nothing came of them, instead of starting the question over.

**The Jumping row founds no rule at all** - 4 events, split 291 against 537. Jumping is scored
on faults and time in `312 Errors` and `101 Duration`, so what a `644 Score` means on those four
cards is not established. Four events is too small a population to conclude from and it is left
as an observation, not carried into any check.

**Template names stop at 50 characters, and that is the storage rather than the titles.**
Measured 2026-08-19: 87 templates, the longest name exactly 50, four sitting on it and nine more
between 45 and 49. Two of the four end mid-word - `11248 FEI Jumping World Cup Northern Central
European Le` and `11249` the Southern one beside it, each missing the rest of `League` - while
`11266` and `11267`, the two North America leagues, reach 50 and end on a complete word.

A clipped name travels into every report, every board tab and every join anybody makes on it,
and nothing downstream can tell a cut name from a short one.
`Equestrian-DQ-110 TEMPLATE_NAME_STOPPED_AT_THE_STORAGE_CEILING` reads the ceiling out of the
data rather than carrying 50 as a constant, so it keeps working if the column is widened instead
of going silently blind on the day that happens.

**A stage is written as whole days, 00:00:00 to 23:59:59, and that is why this is the one
documented sport carrying no `GLOBAL-DQ-004`.** The template asserts that a stage contains the
events it holds, and this sport satisfies it: measured 2026-08-26 it returns 13 stages.
`Equestrian-DQ-067 TOURNAMENT_STAGE_EVENT_OUTSIDE_DATE_RANGE` asserts the same containment on
the exact timestamp rather than on the calendar day, and returns those 13 plus 4 more, where an
event falls outside the hours of a stage that was not written as whole days. The stricter
statement is kept and the template is not instantiated beside it, because it would restate a
subset of what the sport already reports.

**The reason recorded before 2026-08-26 was a different one and is no longer true.**
`GLOBAL-DQ-004` required a stage's dates to *equal* its first and last event dates until that
day, which the whole-day convention cannot satisfy: a stage containing every one of its events
still differed from their span by the hours at each end, and that was 3303 of the 3338 stages it
reported, measured 2026-08-18. The template was changed to containment for every sport at once,
so the exclusion here now rests on duplication rather than on the sport failing to store what
the template read. It is recorded because the two look identical from the board - the same name
on both - and only the granularity separates them.
**`GLOBAL-DQ-055 EVENT_PARTICIPANTS_DUPLICATE_IN_EVENT` is deliberately not instantiated, and
this is where that is recorded.** It was simply absent until 2026-08-28 - no parameter blocked
it and no line explained it - so it was run and read before being left out. Measured that day
it reports 1273 events of 5527 eligible, which is a quarter of the sport and would have gone to
the board as defects.

They are not defects. Splitting every rider entered more than once in one event by the `horseFK`
on the participation gives 3977 pairs where the two entries name two different horses, 18 where
neither entry names a horse at all and the entrant is a team, 2 where the same horse is entered
twice, and 1 mixed. A rider contesting a competition on two horses is what this sport does, and
the template cannot see it: no other sport puts a second object on the participation, so
`event_participants` alone reads the two entries as one competitor entered twice.

**`Equestrian-DQ-124 EVENT_PARTICIPANTS_DUPLICATE_THE_HORSE_DOES_NOT_EXPLAIN` is the
twenty-one, written 2026-08-28 once the reason above had been recorded.** It audits the same
object the template does - a competitor entered more than once in a single event - and reports
only the duplicates the horse fails to account for. Measured the day it was written: **21
findings of 3998 eligible**, where the eligible count is competitors entered more than once,
not every participation, because that is the population the twenty-one should be read against.

Three shapes, and they are three different repairs:

- **18 `NO_ENTRY_NAMES_A_HORSE`.** Every one is a team - Great Britain, Germany and Ireland are
  each entered twice in event `2912966`. A team carries no `horseFK` and correctly so, so
  nothing can explain a team appearing twice; these are plain duplicates.
- **2 `THE_SAME_HORSE_ENTERED_MORE_THAN_ONCE`.** Joris van Springel on `Over and Over` in event
  `471269`, and Julie Davey on `Air Hill The Rajah` in `5095903`. One rider, one horse, two
  entries.
- **1 `SOME_ENTRIES_NAME_A_HORSE_AND_SOME_DO_NOT`.** Jose Filho in event `5077706`, one entry on
  `Cartujano Jmen` and one with `horseFK` empty.

The horse is read from the `horseFK` property, never from `event_participants`, for the reason
the participant section records: a horse is not an event participant in this sport. The join to
the horse itself is a `LEFT JOIN` on purpose - the 272 participations whose `horseFK` points at
a participant that does not exist still name a horse as far as this check is concerned, so a
dangling reference does not turn a two-horse ride into a duplicate. That defect belongs to
`GLOBAL-DQ-006`. `0` and the empty string are treated as no horse rather than as a horse, which
is what separates the Jose Filho row from a legitimate two-horse ride.

<!-- MANUAL PASTE ZONE: 37 STORAGE SEMANTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Open questions

**What a `644 Score` means on a Jumping card, and whether it runs in either direction.**
Jumping is scored on faults and time, in `312 Errors` and `101 Duration`, and four of its events
carry a `644 Score` beside them. Measured 2026-08-19, the 829 ordered pairs inside those four
split 291 against 537: the better rank holds the higher score about as often as the lower one,
which founds no direction at all where Dressage founds one on 278204 pairs and Eventing on
56782 without a single exception. **Confirmed sport-specific storage semantics** above holds the
measurement and the decision it produced - the observation was left standing and carried into no
check.

This is recorded as open rather than closed because nothing about it was settled; it was only
too small to read. Four events cannot show a direction whichever way they fall, so the question
is not answerable today and no amount of re-reading these four will change that. What would
change it is the population: if `644 Score` spreads to enough Jumping events for a direction to
appear, the question is worth asking again, and the answer decides whether a check can read the
column in this discipline at all. Until then no statement reads `644 Score` in Jumping, and none
should - a rule taken from four events would be asserted over the whole discipline.

The one this file previously carried is answered. Whether `1276 Pair` and the lineup `horseFK`
name the same horse for the same ride was measured on 2026-08-18: they do, on all 1782 rides
where both layers speak, with no exception. **Confirmed sport-specific storage semantics** above
holds the measurement and the two readings that make it mean something.

<!-- MANUAL PASTE ZONE: 37 OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
