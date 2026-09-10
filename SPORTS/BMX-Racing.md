# SPORT: BMX Racing (sport_id=58, disciplines 429 Racing and 776 Time Trial)

This file is the canonical structural record for BMX Racing. It contains only confirmed
sport-specific usage, meanings, identifiers, evidence boundaries and open structural
questions. Global database mechanisms belong in `../DATABASE.md`.

**This sport is two of the three disciplines under `sport.id = 58`, not the whole of it.**
The database calls 58 `BMX` and contests Racing (429), Time Trial (776) and Freestyle (430).
Racing and Time Trial are one sport to anybody reading a board and Freestyle is another, which
is what `SPORTS/BMX-Freestyle.md` documents. They shared one file, one board and one set of
CheckIDs until 2026-09-04; on that day the slug became `BMX-Racing` and every check moved with
it, keeping its number - `BMX-DQ-043` became `BMX-Racing-DQ-043`. No CheckID was renumbered,
deleted or reused.

The boundary is carried by `DISCIPLINE_ID_LIST` in `SPORTS/params.json` and reaches the
database through the commented discipline filter every statement that can reach a discipline
carries. `TOOLS/README.md` owns the mechanism and `POWERBI.md` the query contract.

**The boundary is written as the complement, and that is a decision rather than a detail.**
`DISCIPLINE_EXCLUDE_LIST = 430` is declared beside it, and a statement's filter is activated as
`NOT IN (430)` rather than `IN (429, 776)`. The reason is measured, 2026-09-05: this sport holds
420 of the 438 Comp.Rank statistics under `sport.id` 58, so naming them narrows nothing and
still costs the index path. Five templates - `GLOBAL-DQ-033 COMP.RANK_RESULTS_MISSING_PHASE`,
`GLOBAL-DQ-041 COMP.RANK_RESULTS_MEDAL_ON_NON_MEDAL_ROUND_PHASE`,
`GLOBAL-DQ-113 COMP.RANK_PARTICIPANT_TYPE_MIXED`, and `GLOBAL-DQ-136` and `GLOBAL-DQ-145` on
organization against competitor country - each ran 12 to 15 seconds unfiltered, each went over
the server's 180-second wall written the plain way, and each came back to 12 to 16 seconds
written as the complement. `EXISTS`, `IN` and `JOIN` fail alike, so it is the plan and not the
phrasing.

**This file first said the cause was selectivity - a filter keeping 420 of 438 narrowing nothing -
and that was wrong.** BMX-Freestyle disproved it on 2026-09-05: its filter keeps 18 of 438 and is
still four and a half times slower than its own complement, so it declares one too. The measured
rule is that the positive form is slow and the complement fast, whichever slice is the large one;
why, nobody here has established. `TOOLS/README.md` carries the numbers from both sides.

What the choice costs is small today and real: the two forms are the same rows only while every
object in scope reaches exactly one discipline. All 438 do, measured the same day. An object
reaching none would be dropped by the plain form and kept by this one, appearing on this board
and on no other. That is why the exclusion is declared in the sport's own parameters rather than
worked out by the runner.

Eighteen checks carry no such filter and audit `sport.id` 58 whole. Every one of them looks
for an object with **no** participation - a template with no tournaments, a tournament with no
stages, a stage with no events, a person who never competed - so a filter running through that
participation would remove exactly the rows the check exists to find. They are confined by the
client template list instead, and the run names them in yellow on every execution rather than
leaving the reader to work it out.

For additions, insert approved content immediately before the exact active
`MANUAL PASTE ZONE` marker in the destination subsection. Keep the marker unchanged
and at the end of its subsection. Replace existing rows or paragraphs in place when a
correction is required.

## Identity and evidence
- First discovery date: 2026-07-20
- Latest evidence date: 2026-07-25
- Verification boundary: sport identity, event participants, event results, incidents, lineups, scope layer, properties, object_relation, object_discipline, statistics, reference values and event status mapping all confirmed from active data.

## Structural coverage
| Area | Status | Evidence |
|---|---|---|
| Core hierarchy | Used | sport.id=58, name='BMX', enetSportCode='mx' |
| Event participants | Used | Only participant type `athlete`, genders `male`/`female` observed |
| Event results | Used | 7 result_typeFK/result_code pairs confirmed |
| Incidents | Not used | Complete-layer query returned zero active rows |
| Lineups | Not used | Complete-layer query returned zero active rows |
| Scope layer | Used | scope_typeFK 101, 102, 103 |
| Properties | Used | Confirmed for event, tournament_stage and participant owners; not used for tournament owner |
| object_relation | Used | (2→152) template subset, (4→151) stage age class |
| object_discipline | Used | Owner type 5 (event); disciplineFK 429, 430 and 776 |
| Statistics | Used | statistic_typeFK=11, object_typeFK=3 (tournament-level) confirmed |
| Reference values | Used | result_type, scope_type, discipline, statistic_type and statistic_data_type names confirmed |
| Other tables | Used | event.status_type/status_descFK mapping confirmed |

## Tables and relation paths used

Core hierarchy through `tournament_template.sportFK=58`; event results via `result`;
scope via `event_scope`/`scope_result`; properties via `property`
(`object='event'|'tournament_stage'|'participant'`); disciplines via
`object_discipline` (owner type 5); statistics via `statistic`
(`object_typeFK=3`) → `statistic_participants11` → `statistic_data11`, with
`statistic_config` for statistic-level metadata.

<!-- MANUAL PASTE ZONE: 58 TABLES AND RELATIONS — insert approved additions immediately before this marker; do not move or delete it. -->

## Participant and lineup structure

BMX event_participants use only participant type `athlete`, with genders `male` and `female`. No lineup rows exist for BMX (Not used). Only participant type `athlete` is linked through `statistic_participants11`.

First and last name are stored via the generic `language` table
(`object='participant'`, `language_typeFK=7` for `first_name`, `language_typeFK=8` for
`last_name`), confirmed active for BMX athletes. `participant.name` (full name) is a
separate, already-confirmed direct column.

<!-- MANUAL PASTE ZONE: 58 PARTICIPANTS AND LINEUPS — insert approved additions immediately before this marker; do not move or delete it. -->

## Event result types
| result_code | result_typeFK | Value shape | Confirmed meaning | Evidence |
|---|---:|---|---|---|
| rank | 100 | | Rank | Confirmed-data |
| duration | 101 | Bare seconds: `+0.038` gap, or plain `98.455` for the leader | Duration | Confirmed-data |
| points | 102 | | Points | Confirmed-data |
| comment | 104 | Closed set of status codes | Comment | Confirmed-data |
| medal | 501 | | Medal | Confirmed-data |
| duration_full_time | 557 | `m:ss.f` or bare seconds; populated in 9 events only | Full-time duration | Confirmed-data |
| wave_1 | 547 | | Wave 1 | Confirmed-data |

`101 Duration` carries the sport's times and follows the leader/gap convention: a full time
for the leader, a `+` gap for every other rider. A gap under a minute is written in bare
seconds, `+0.038`; a gap of a minute or more takes clock notation, `+1:43.043`. Both are
correct, by the user's decision of 2026-09-05. `BMX-Racing-DQ-030` runs the global template
`GLOBAL-DQ-019` and carries no sport statement of its own: the sport statement existed only
to refuse the colon, and that refusal was withdrawn by the same decision.

`557 Full-time duration` is the opposite case. It is present but effectively unused: 421
participant rows across 9 events, against 61 463 rows in 7 994 events for `101`. Its values
take both `m:ss.f` and bare-second shapes. A check whose eligible population requires an
active full time therefore audits nine events for this sport and its coverage count says so
- the finding to read is the coverage, not the absence of violations.

`104 Comment` is not free text. Its whole active population resolves to a closed set of
status codes:

| Value | Meaning | Note |
|---|---|---|
| `Q` | Qualified to the next round | The dominant value by a wide margin; a progression marker, not an invalid result |
| `DNF` | Did not finish | |
| `DNS` | Did not start | |
| `Disq.` | Disqualified | The most common of three spellings of one status |
| `Disqualified` | Disqualified | |
| `DSQ` | Disqualified | |
| `REL` | Relegated | A placing penalty; a relegated rider still holds a classification |
| `DNF/Q` | — | A single row combining two markers; no confirmed meaning |

Three spellings of Disqualified are in use, and which one dominates depends on the layer:
`Disq.` at event level, `DSQ` among Comp.Rank data. Neither is a rare typo of the other, so
the sport stores one status under three spellings rather than mistyping one of them.

`Q` is the sport's dominant Comment value because the format qualifies riders out of heats.
That is the opposite of a sport where the same value appears a handful of times and reads as
leakage, which is why the accepted set is recorded per sport rather than globally.

`REL` marks a placing penalty and not the absence of a result, so a relegated rider is
expected to carry a rank.

`GLOBAL-DQ-122` returns 1 391 findings over 9 325 finished ranked events, and the shape of
the gap matters more than its size. It is neither an era nor a round type: the absence runs
from 2004 to 2025 at roughly one event in ten every year, and it appears in every round the
sport holds — `Heats` 823 of 2 838, `Final` 209 of 539, `Qualifier` 144 of 1 169,
`Semi Finals` 75, `Quarter Finals` 53. The same round type is clean in the majority of its
own events, which rules out the reading that a moto is placed without a time by design.
What is left is a standing coverage gap in the feed: `101 Duration` reaches 7 994 of the
9 325 events, and where it is missing the placing rests on nothing stored.

`RESULT_TIE_VALUE_TYPE_LIST` for this sport is `101` alone, so no second field can stand in
for the duration the way `557` does for Triathlon.

### What shape `101 Duration` is actually written in

Re-measured 2026-09-05 over every active event participant in the database sport, by value
shape:

| Shape | Values | Events | Reading |
|---|---|---|---|
| `+#.#` | 53 269 | 8 004 | the gap, bare seconds |
| `#.#` | 8 007 | 8 006 | the leader's full time, one per event |
| `+#:#.#` | 218 | 203 | the gap, clock notation, a minute or more |
| `-#.#` | 120 | 13 | negative, and every one of the 13 events is Freestyle |
| `#:#.#` | 13 | 13 | full time in clock notation |

**The field keeps the leader/gap convention, and the earlier reading of it was overtaken by
the data.** Measured 2026-08-12, the same field held absolute times at every placing - 51 158
rows across 7 968 events - and the `+` shape appeared in 26 events. That reading was correct
when it was taken and is wrong now: the feed was corrected in the weeks between, and today one
absolute value per event sits against 53 269 gaps. It is recorded here because a reader
meeting the check's convention would otherwise re-derive the same contradiction and reach the
same dead end.

**The one-minute boundary is a notation, not a defect.** A gap of a minute or more is written
`+1:43.043` rather than `+103.043`, in 203 events. Settled 2026-09-05; before that the sport
statement refused the colon and reported all 203.

**The negative values are not this sport's.** All 13 events carrying `-#.#` are Freestyle -
Summer Olympics 2020, Pan American Games 2019 and 2023, BMX Freestyle European Championships
2025 - and the discipline boundary excludes them here. What a negative duration means in a
judged discipline is an open question for `SPORTS/BMX-Freestyle.md`, not for this file.


<!-- MANUAL PASTE ZONE: 58 EVENT RESULTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Incident types

Not used — confirmed zero active incident rows for BMX events.

<!-- MANUAL PASTE ZONE: 58 INCIDENTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Scope types and data types

Used — scope_typeFK values 101 (checkpoint1), 102 (checkpoint2), 103 (checkpoint3) confirmed on BMX event_scope containers.

<!-- MANUAL PASTE ZONE: 58 SCOPES — insert approved additions immediately before this marker; do not move or delete it. -->

## Properties

Confirmed active `property` type='metadata' names by owner:
- `event`: discipline, Live, Round, Type, medal_related, ElapsedTime, Heat, checkpoints, checkpoint_details
- `tournament_stage`: Cup, StatusComment
- `participant`: status, date_of_birth, height, weight
- `tournament`: Not used (complete-owner query returned zero active rows)

<!-- MANUAL PASTE ZONE: 58 PROPERTIES — insert approved additions immediately before this marker; do not move or delete it. -->

## Generic relations and disciplines

`object_relation`: (object_typeFK=2 → rel_object_typeFK=152) and (object_typeFK=4 → rel_object_typeFK=151) both confirmed active for BMX.
`object_discipline`: owner type 5 (event) confirmed active with three disciplines: 429=Racing, 430=Freestyle, 776=Time Trial.
Confirmed active `tournament_age_class` values linked via `object_relation` (4→151) for BMX stages with active events: `SENIOR`, `YOUTH`.

<!-- MANUAL PASTE ZONE: 58 GENERIC RELATIONS AND DISCIPLINES — insert approved additions immediately before this marker; do not move or delete it. -->

## Statistics
| statistic_typeFK | Owner type | Participant shard | Data shard | Fields/config | Evidence |
|---:|---:|---:|---:|---|---|
| 11 (Competition Stats) | tournament (object_typeFK=3) | statistic_participants11 | statistic_data11 | Data: Rank(1270), Points(1271), Duration(1272), Comment(1273), Pair(1276), Medal(1277), Time(1426), Time Difference(1427), Team(1429). Config: Start date(1463), End date(1464), Gender(1470), Event id(1471) | Confirmed-data |

The `1273 Comment` data field holds its own closed set of status codes, and it is not the
same set the event layer uses: `DNF`, `DNS`, `No Time`, `DSQ`, `Disqualified`, `Disq.`,
`REL`, and empty values.

Two differences from the event layer are structural rather than incidental. `Q`, the
dominant event-level Comment value, does not occur here at all, consistent with Comp.Rank
being built from a final classification rather than from round-by-round progression.
`No Time` occurs only here: the source carried no time for a rider who is nonetheless
expected to have finished, so it marks a missing measurement and not a missing result.

The three spellings of Disqualified are present in this layer too, but `DSQ` dominates here
while `Disq.` dominates at event level. A check reading either layer must take its accepted
set from that layer's own inventory.

`1271 Points` is the only data field carrying a measured quantity, and it occurs under
IOC-purpose templates only. A statistics check excludes those templates by contract, so
`GLOBAL-DQ-077` has an empty eligible population here and `NUMERIC_DATA_TYPE_LIST` stays
empty. The event layer is not affected by this: `GLOBAL-DQ-076` does not exclude IOC-purpose
templates, and the event-level `102 Points` result type is recorded in
`NUMERIC_RESULT_TYPE_LIST`.

The sport stores its Comp.Rank times in the deprecated `1272 Duration` field together with
`1427 Time Difference`, leaving the current `1426 Time` field empty. `GLOBAL-DQ-029` is the
check that names this. `GLOBAL-DQ-046` reads the same absence as a rank/time mismatch and
therefore reports its whole eligible population for this sport; it has to be read after
`GLOBAL-DQ-029` and not as an independent finding.

`PRECISION_DATA_TYPE_LIST` is `1272` for the same reason, and it is the one parameter here
that deliberately names a deprecated field. The alternatives are both empty: `1426 Time` holds
nothing, and `1271 Points` occurs under IOC-purpose templates only, which every statistics
statement excludes — the absence `NUMERIC_DATA_TYPE_LIST` already records. Auditing the
superseded field is not an endorsement of it; 321 statistics hold 6 171 duration values there
and anything reading this sport's Comp.Rank times reads them from `1272`.

**The Comp.Rank organization is not filled at all, and `BMX-Racing-DQ-106` is a sentinel because of it.** Measured 2026-08-25 this sport holds 424 tournament-owned Comp.Rank records over 21 150 ranked participations and **not one** carries an Organization value on the statistic data type the sport declares for it.

That makes `BMX-Racing-DQ-106 COMP.RANK_PARTICIPANT_ORGANIZATION_COUNTRY_CONTRADICTS_COMPETITOR` return an `eligible_count` of 0. It is the second of the two things a zero can be - a correct scope over a population that is legitimately empty today, not a misdirected one - and the measurement above is what settles which. The check asks whether the organization that is there is the right one; there is none to ask about. `BMX-Racing-DQ-097` is what reports the absence itself.

It is instantiated rather than left off on the ruling of 2026-08-25 that the field is expected to be populated, and the day it is, this is the check that reads what arrives. Four of the twelve documented sports already fill it - Artistic Gymnastics, Triathlon, Golf and Ice Hockey - and those four are exactly the four that carried this check before today.

**`BMX-Racing-DQ-109 COMP.RANK_ATHLETE_RANKING_DISAGREES_WITH_ITS_TEAM_TWIN` audits nothing, and that
is a sentinel rather than a misdirected scope.** Instantiated 2026-08-27 with
`GLOBAL-DQ-143`, it returns `eligible_count = 0`. The reason is measured and not assumed:
of this sport’s 632 tournament-owned Comp.Rank rankings, **not one** carries `(athletes)`
in its name. That suffix marks a ranking listing the members of a squad, each given the
place their team finished in, and the check compares such a ranking against the team
ranking it was projected from. With no athlete ranking there is no pair to compare.

**It is deliberately not `Not applicable`.** Nothing structural stops this sport from
producing an athlete ranking: the layer, the shard and the Rank data field are all here
and in use. What is absent is rows, and a row count is never the ground for excluding a
check — that would disarm it for the day the first squad ranking arrives, which is the
day it was written for. The zero is the honest reading and the coverage count says so.
<!-- MANUAL PASTE ZONE: 58 STATISTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Reference values

| Code type | id | name |
|---|---:|---|
| result_type | 100 | Rank |
| result_type | 101 | Duration |
| result_type | 102 | Points |
| result_type | 104 | Comment |
| result_type | 501 | Medal |
| result_type | 547 | Wave 1 |
| result_type | 557 | Full-time duration |
| scope_type | 101 | checkpoint1 |
| scope_type | 102 | checkpoint2 |
| scope_type | 103 | checkpoint3 |
| discipline | 429 | Racing |
| discipline | 430 | Freestyle |
| discipline | 776 | Time Trial |
| statistic_type | 11 | Competition Stats |
| statistic_data_type (data) | 1270 | Rank |
| statistic_data_type (data) | 1271 | Points |
| statistic_data_type (data) | 1272 | Duration |
| statistic_data_type (data) | 1273 | Comment |
| statistic_data_type (data) | 1276 | Pair |
| statistic_data_type (data) | 1277 | Medal |
| statistic_data_type (data) | 1426 | Time |
| statistic_data_type (data) | 1427 | Time Difference |
| statistic_data_type (data) | 1429 | Team |
| statistic_data_type (config) | 1463 | Start date |
| statistic_data_type (config) | 1464 | End date |
| statistic_data_type (config) | 1470 | Gender |
| statistic_data_type (config) | 1471 | Event id |

<!-- MANUAL PASTE ZONE: 58 REFERENCE VALUES — insert approved additions immediately before this marker; do not move or delete it. -->

## Event and round representation

event.status_type/status_descFK combinations confirmed: finished/6, notstarted/1, cancelled/106.

event.round_typeFK is confirmed active for BMX events, referencing the round_type table. Round type names are not unique identifiers — multiple round_type IDs share identical name text (e.g., two IDs named 'Heats', two named 'Quarter Finals', two named 'Final'); queries must reference round_typeFK by ID, not name. An unmapped value round_typeFK=0, with no matching round_type row and distinct from a NULL round_typeFK, was confirmed when this sport was documented and is gone as of 2026-09-06 - see the entry below.

A single round_typeFK value can be attached to events representing logically different rounds. Confirmed for round_typeFK=189 (Seeding), which is used by events named as Time Trial Superfinal, Seeding Run and Semifinal Heat across different tournament templates. Round type identity must not be treated as a reliable indicator of the actual round an event represents

BMX Comp.Rank participants carry a Phase through `object_round` (object_typeFK=138, type='phase'), recording the round the participant's rank was taken from. Phase is close to universal here and the gaps are scattered: 90 of the sport's 20763 active Comp.Rank participant rows carry no phase row, and they sit in 21 of its 413 Comp.Rank. Every one of those 21 is a field phased in part - between one and sixteen competitors of a field of ten to two hundred and twenty-two - and none is a Comp.Rank with no phases at all. `GLOBAL-DQ-033` is therefore an ordinary repair list for BMX rather than a proportion to watch, and is signalled `Actionable` on that basis. The wording this paragraph carried until 2026-08-12 called the gap a large share of the population, which the counts do not support at either object.

The round types used by BMX Phase values are not the set BMX events use, and comparing a BMX Phase
against its event's `round_typeFK` by ID alone reports much of the population as mismatched and is
not a valid check. **The reason is no longer the one this paragraph gave until 2026-09-10, and the
wording it carried has been replaced rather than corrected.** It said BMX events use the
non-knockout variants - 176 Quarter Finals, 178 Semi Finals, 184 1/8, 185 1/16, 188 1/32, 173 Final
- while Phase mostly uses the knockout variants 3, 2, 4, 5, 6, 9, so that the split followed the
knockout flag (`DB-SEM-012`). Re-measured 2026-09-10 that is inverted for five of the six: events
now sit on 3, 2, 4, 5 and 6, and 176, 178, 184, 185 and 188 carry no event at all. Only `173 Final`
is still where the old wording put it.

What survives the re-measurement is the mismatch itself, arriving from the other direction. **The
events have settled on one member of each name pair and Phase still uses both.** Phase spans
seventeen round types where events span twelve, and four names appear on it twice over: Final as
`9` on 3545 phase rows and `173` on 628, Semi Finals as `2` on 2096 and `178` on 335, Qualifier as
`179` on 2674 and `152` on 67, Heats as `204` on 1636 and `320` on 3. Phase also carries `19 Small
Final` on 12 rows, which no event uses, while events use `168 Repechage` where Phase uses the
non-knockout `180` on 1869. The `0` the old wording named as a Phase-only value is gone with the
unmapped `round_typeFK` itself.

The complete set of `event.round_typeFK` values BMX Racing events carry, by inventory of
2026-09-10: 2 (Semi Finals) on 650 events, 3 (Quarter Finals) on 964, 4 (1/8) on 651, 5 (1/16) on
320, 6 (1/32) on 109, 38 (1) on 1275, 152 (Qualifier) on 1074, 168 (Repechage) on 734, 171
(Preliminary) on 14, 173 (Final) on 426, 189 (Seeding) on 31 and 320 (Heats) on 2870. Twelve, and
every one but 38, 171, 173 and 189 is flagged `knockout = yes`.

**A different fifteen stood here until that date** - 3, 9, 38, 171, 173, 176, 178, 179, 180, 184,
185, 188, 189, 204, 320, plus the unmapped 0 - recorded when the sport was opened, and
`SPORTS/params.json` carried the same fifteen as `ROUND_TYPE_LIST`. Nine of them now carry no
event: 9, 176, 178, 179, 180, 184, 185, 188 and 204. Six the sport does contest were missing: 2, 4,
5, 6, 152 and 168, holding 3538 events between them. `BMX-Racing-DQ-069`, running `GLOBAL-DQ-075
EVENT_ROUND_TYPE_NOT_IN_EXPECTED_SET` - events whose round type is outside the set the sport is
confirmed to contest - reported exactly those 3538 of 9118 eligible for as long as the gap stood.
The user settled it on 2026-09-10: the parameter was stale, not the data wrong, so
`ROUND_TYPE_LIST` is now the twelve above and the check returns nothing while keeping its
population, ready for a thirteenth id.

Round names still occur under two IDs each - Final as 173 and 9, Semi Finals as 178 and 2,
Quarter Finals as 176 and 3, Heats as 204 and 320, Qualifier as 179 and 152, Repechage as 180 and
168 - which is the duplication the paragraph above warns about. What changed is which member the
events sit on, not that the pairs exist.

`38` resolves to a `round_type` row named `1`, and the round it stands for is **Round 1**,
the first racing round. Confirmed two ways. Every one of the 37 distinct event names carried
by `38` has the shape `Men's Racing Round 1 Heat 4` or `Women's Racing Round 1 Heat 1`, with
no other shape present, across 3 templates and the years 2017 to 2025. And 138 tournament
stages carry `38` beside the full bracket in the same stage - `173`, `176`, `178`, `180`,
`184`, `185` and `188` - which places it before the 1/32 rather than beside it.

The bare `1` is therefore a weakness of the `round_type` reference row, not of the events
using it: the name does not say which round it is, while the events do.

### The event name is a sentence the event's own settings can be read back from

The required form is **`[Discipline] [Gender] [Round] [Run N] [Heat N]`** - `Racing Men Motos
Run 1 Heat 1` - with `Overall` kept after the round word where the event carries it. Chosen by
the user on 2026-09-09 for the renaming cron, and it is what
`BMX-Racing-DQ-118 EVENT_NAME_DOES_NOT_FOLLOW_THE_SPORT_PATTERN` compares against.

**Run comes before Heat.** That part the sport has never disagreed about: names ending
`Run 1 Heat 1` are common and not one ends `Heat 1 Run 1`. Both numbers come from event
properties of the same names, `Run` carrying 1 to 3 and `Heat` a larger range, so the check can
compare the name against a stored number rather than against a vocabulary - the only part of
the pattern that needs no editorial decision at all.

**The sport ran several conventions at once when this was written**, and the required form was
the smallest of them. Most events opened with a possessive gender - `Men's Racing Motos Run 1
Heat 1`, with the round word before Run and Heat - some with a plain gender, a minority with
the discipline, and a few with neither. The chosen form is one of the sport's own, not one
imposed from outside, but it was the minority one, so the check reports most of the sport until
the cron has passed.

**The round word is `round_type.name` as stored**, with exactly two exceptions the renaming
cron makes: `Semi Finals` is written `Semifinal`, and `1` is written `Round 1` because a bare
number names nothing. Every other round type appears in the name exactly as the reference row
spells it, plural and spacing included - `Quarter Finals`, `1/8`, `Heats`, `Qualifier`,
`Repechage`, `Preliminary`, `Final`, `Seeding`. Confirmed 2026-09-09 against the events the
cron had already rewritten.

**The `Round` event property is not the source, and is a worse one.** It agrees with
`round_type.name` almost everywhere and carries typos of its own where it does not - `Qualfier`
for `Qualifier` - so a check reading it would report the reference row's spelling as wrong.

**This replaced the sport's older vocabulary**, which is worth recording because a check was
written against it first. Before the rename the sport called round type 320 `Motos`, 3
`Quarterfinal`, 4 `1/8 Finals`, 168 `Last Chance Race` and 152 `Qualification`. Those words are
gone from the required form, and a check asserting them disagreed with the cron on most of the
sport - reporting the rename as outstanding after it had already run.

**Collisions are settled with a trailing number, not with a word.** Two events of the same
round, gender and tournament reduce to the same name under the pattern, and the cron numbers
them from the oldest: `Racing Men Qualifier` and `Racing Men Qualifier 2`. The check therefore
accepts the expected name followed by a number, and does not try to reproduce which number the
cron chose.

**That is how `Overall` disappeared, and the loss is real.** Before the rename, most tournament
/ gender / round-type groups holding an `Overall` event also held a plain one - the same shape
as `Combined` in Artistic Gymnastics, two different events told apart by name alone. The
required form has no slot for the word, so `Motos` and `Motos Overall` both became
`Racing Men Heats` and are now told apart by a number that does not say which is the overall
standing. This is a consequence of the form, not a defect any check can report.

**`General Classification` needed no such handling**, and that is the opposite answer to the
same question asked the same way: no tournament holding one holds any other final, so it was
that tournament's final under another name and folding it in collided with nothing.

### Two checks read that sentence

Approved 2026-09-09, sport-specific rather than global because the pattern is the sport's own,
and the first entries in `POWERBI_QUERIES/BMX-Racing.sql`, which did not exist before them.

`BMX-Racing-DQ-118 EVENT_NAME_DOES_NOT_FOLLOW_THE_SPORT_PATTERN` is a guard, and it took two
drafts to become one. The first read the sport's older vocabulary and so reported the rename as
outstanding across most of the sport after the cron had already done it; reading
`round_type.name`, as the cron does, takes it to almost nothing. What survives a cron pass is
what the cron could not fix - the first such row found was an event of mixed gender whose name
carries no gender word at all, so the cron had nothing to place there.

Its `check_type` column separates the two kinds. `RIGHT_WORDS_IN_THE_WRONG_ORDER` is the rename
and the cron owns it. Everything else needs a person: `POSSESSIVE_APOSTROPHE_BROKEN`, an
apostrophe with no `s`; and `HEAT_NUMBER_MISSING_OR_DISAGREES_WITH_THE_HEAT_PROPERTY` with its
`Run` twin, which compare the name against a stored number rather than against a vocabulary and
so stay true whatever is decided about wording.

`BMX-Racing-DQ-119 EVENT_NAME_PATTERN_CANNOT_BE_BUILT` is its companion - no gender on the
stage, no round type, an empty name, or a round type outside the twelve - and returns nothing
today.

**No counts are recorded for either.** The renaming cron runs against this sport continuously,
and two measurements twenty minutes apart disagreed for that reason alone.
`RUNS/BMX-Racing.json` holds what each run returned, and it is a run record rather than
evidence.

Neither reads whitespace or text hygiene. `BMX-Racing-DQ-049` carries
`GLOBAL-DQ-049 EVENT_NAME_FORMAT_INVALID` and already asks that question.

### A round named Final is not a knockout round in this sport

**`173 Final` carrying `knockout = no` is correct, and the expectation for the name is `no`.**
Recorded by decision on 2026-09-10, against the shape of the data rather than from it, and the
measurement is here so the decision is legible.

`BMX-Racing-DQ-090`, running `GLOBAL-DQ-118
EVENT_ROUND_TYPE_KNOCKOUT_FLAG_CONTRADICTS_ROUND_DETAIL` - the per-event repair list for a round
type whose knockout flag contradicts the round - reported 426 events of 7843 eligible, and every
one of the 426 was the same row: round type `173 Final`, stored `knockout = no`, expected `yes`,
pointed at `9 Final`. The check was asking for 426 events to be moved onto the knockout twin of
their own name. It is the reading that is wrong, not the events: a BMX final ranks the eight
riders who reached it and eliminates nobody, which is what the non-knockout member of the pair
says.

So `'final'` moved from `ELIMINATION_ROUND_NAME_LIST` to `GROUP_ROUND_NAME_LIST` in
`SPORTS/params.json`. Golf recorded the same reading for its own finals on 2026-08-13, Speed
Skating on 2026-08-22 and Track Cycling on 2026-08-26; Handball recorded the opposite on
2026-08-28, because there a final is a tie whose loser goes out of the contest that round decides.

The consequence is deliberate and is the point of stating it: `BMX-Racing-DQ-090` stops reporting
the 426 events on `173` and starts reporting whatever sits on `9 Final`, which is nothing today.
`BMX-Racing-DQ-076`, running `GLOBAL-DQ-097 EVENT_ROUND_TYPE_KNOCKOUT_FLAG_CONTRADICTS_ROUND` -
the same judgement reported once per round type instead of once per event - follows it and drops
from 1 finding to 0, as the two are written to always agree on which round types are wrong. Both
keep a live eligible population, so neither is a sentinel: the day a BMX final is filed under `9`,
they say so.

Nothing else moved. `'semi finals'`, `'quarter finals'`, `'1/8'`, `'1/16'`, `'1/32'`, `'heats'`,
`'qualifier'`, `'repechage'`, `'playoff'`, `'tie-breaker'` and `'small final'` stay on the
elimination list: those names are rounds a rider goes out of, in this sport as in any other.
`38 1` stays in neither list, because a round type named with the bare digit `1` cannot be
classified from its name at all.

<!-- MANUAL PASTE ZONE: 58 EVENT AND ROUND REPRESENTATION — insert approved additions immediately before this marker; do not move or delete it. -->

## Confirmed sport-specific storage semantics
City for a BMX tournament stage is stored via `city_object` (object_typeFK=4, objectFK=tournament_stage.id) linking to `city`, not via a direct column.

Venue is unpopulated for BMX. `venue_object` holds no active row for any BMX tournament stage (object_typeFK=4), event (5) or Comp.Rank statistic (83), and the venue field visible on the Comp.Rank edit form is unpopulated for the sport. The layer was queried complete at all three levels and returned zero active links.

That is a row count, not a structure the sport lacks: `venue_object` is the global mechanism `DATABASE.md` records, available to every sport, and `SPORTS/Curling.md` establishes that venue is newly populated in this database with the backfill still ahead. BMX is at nought per cent of that backfill. `GLOBAL-DQ-074` is therefore a `Monitor` rather than `Not applicable` — it covers every event, reports every event, and the figure to read is the proportion, which is expected to fall as the backfill reaches the sport. An earlier revision classified it away on the zero, which `CLAUDE.md` forbids: the check would then have stayed silent on the day the first venue arrived.

Host Country for a BMX tournament stage is stored via `object_relation` (object_typeFK=4 → rel_object_typeFK=33), distinct from the direct `tournament_stage.countryFK` column. Confirmed active and functional for BMX via manual positive control (stage 920060).

The sport-level registry (`object_participants`, object='sport', objectFK=58) contains both `athlete` and `team` type participants, even though `event_participants` for BMX confirms only `athlete` type usage (team event participation is Not used). Registered team participants exist at the sport registry level without corresponding event participation.

Event-level `property` value under name='discipline' matches exactly the discipline name confirmed via `object_discipline` (Racing, Freestyle, Time Trial) — both mechanisms are consistent and refer to the same three disciplines under sport_id=58.

BMX (sport_id=58) covers three disciplines with distinct result_type and scope_type coverage:

| Discipline (disciplineFK) | result_typeFK used | scope_typeFK used |
|---|---|---|
| Racing (429) | 100, 101, 102, 104, 501, 547, 557 | 101, 102, 103 |
| Freestyle (430) | 100, 101, 102, 104, 501 | 101, 102 |
| Time Trial (776) | 100, 101, 104, 501, 557 | Not used |

Structural and DQ checks for BMX should be scoped per discipline (via `object_discipline`), not only per sport_id, since result_type and scope_type usage vary by discipline.

Sport 58 carries two editorially distinct sports across its three disciplines: Racing and Time Trial together form BMX Racing, while Freestyle is BMX Freestyle. A structure spanning Racing and Time Trial therefore stays inside one sport; one spanning Racing and Freestyle would cross both, which is why the two cases must not be treated as the same condition.

Every BMX tournament-level Comp.Rank statistic (statistic_typeFK=11, object_typeFK=3) that reaches a discipline resolves to exactly one. Measured independently through both confirmed paths — `statistic_config` Event id (1471) → event → `object_discipline` (owner type 5), and the direct `object_discipline` relation on the statistic (owner type 83) — no statistic maps to more than one discipline. This replaces an earlier conclusion that some BMX statistics span two disciplines, which the current data does not reproduce through either path.

The measurement is bounded by the discipline-orphan open question below. The two paths cover a similar but not identical population, and a substantial minority of active BMX Comp.Rank statistics reach neither, so they are outside this evidence and remain unclassified. A discipline-scoped check must verify that a path exists rather than assume it.

`statistic.name` for BMX tournament-level Comp.Rank statistics has no fixed taxonomy — it is a free-text label typically embedding tournament, discipline and round context. Do not treat `statistic.name` as an enum when writing checks.

A single BMX `event_participants` row can have multiple active `result` rows with
different `result_typeFK` values. Do not assume a 1:1 ratio between participation count
and result-row count when building coverage or ratio-based checks.

Confirmed active `tournament_stage.gender` values for BMX stages with active events: `male`, `female`, `mixed` — no `NULL`, empty or `undefined` values observed in this evidence.

BMX Rank (`result_typeFK=100`) values within one event are not a contiguous `1..N` sequence. A participant who did not start or did not finish keeps an active Rank row holding a sentinel value outside the finishing order, paired with an active `comment` (`result_typeFK=104`) value such as `DNS` or `DNF`. The same convention produces duplicate Rank values, where several non-finishing participants share one sentinel. Confirmed positive control: event 5124031 stores ranks `1,2,3,4,5,7,7,10`, where both `7` rows carry `DNF` and the `10` row carries `DNS`. A check asserting rank-sequence completeness must exclude participants carrying an active comment value, or it reports this convention as a defect.

Confirmed active BMX `comment` (`result_typeFK=104`) values: `Q`, `DNF`, `DNS`, `DISQ.`, `REL`, `DISQUALIFIED`, `DSQ` and `DNF/Q`. `Q` marks a participant who advanced from a qualifying heat; it accompanies a normal finishing rank and is not a non-finishing marker.

The comment field is free text with no normalized vocabulary. Disqualification alone is written four ways — `DISQ.`, `DISQUALIFIED`, `DSQ` and, in one case, the compound `DNF/Q`. Any logic that classifies a participant status by comment must match a confirmed value set, never a single token, and must be re-derived from data when the sport's evidence is refreshed.

A BMX event's Rank sequence may legitimately exceed its own participant count when the event stores competition-wide classification positions rather than within-event finishing order. Confirmed positive control: event 5221729 holds 114 active participants ranked `1..121` with interior gaps. Rank magnitude alone therefore does not identify a defect; an invalid rank is one that is both above the event's participant count and disconnected from the next lower rank in the same event.

**An event with no round type is a defect, never a sentinel for "not assigned".** The user
settled this for Shooting on 2026-09-06 and the rule is the sport-independent half of that
answer: a round the reference table does not name is not a round. It is recorded here because
this file carried the same question open, in the form of `round_typeFK=0`, and a question that
closes leaves nothing behind unless somebody writes down the answer.

**The population it was about is gone.** Measured 2026-09-06 across the whole database sport 58,
both disciplines together, with no client-period or template filter: no event holds a
`round_typeFK` that is NULL or resolves to no `round_type` row. `BMX-Racing-DQ-011` and
`BMX-Freestyle-DQ-008 GLOBAL-DQ-006 EVENT_MISSING_ROUND_TYPE` agree, each returning 0 findings
over its own half of the sport - 9 118 eligible events for Racing and 272 for Freestyle. Whether
the rows were repaired during the colleague review or read differently when this file was written
is not established here. Nothing changes in the package: the check stays live on both boards,
which is the point of recording a rule rather than a count - it is now known what to do on the day
such an event appears, and the check will report it.

<!-- MANUAL PASTE ZONE: 58 STORAGE SEMANTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Open questions

- Some BMX Comp.Rank statistics (statistic_typeFK=11, object_typeFK=3) have no reliable path to a discipline: neither `statistic_config` Event id (1471) → event → `object_discipline`, nor a direct `object_discipline` relation (owner type=83) on the statistic itself, is guaranteed to exist. A statistic can be fully discipline-orphaned from both mechanisms (confirmed example: statistic_id=166712, name "Female Park"). Discipline-scoped checks and analysis for BMX Comp.Rank statistics must not assume either path is universal.
- Whether the sentinel Rank value paired with a `DNS` or `DNF` comment follows a fixed rule is not confirmed. Observed values do not resolve to one: in event 5124031 `DNF` maps to `7` and `DNS` to `10` within an eight-participant heat. Until the rule is confirmed, a check must recognise a non-finishing participant by the presence of an active comment, never by the rank value itself.
<!-- MANUAL PASTE ZONE: 58 OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
