# SPORT: Para-Swimming (sport_id=135)

This file is the canonical structural record for Para-Swimming. It contains only confirmed
sport-specific usage, meanings, identifiers, evidence boundaries and open structural
questions. Global database mechanisms belong in `../DATABASE.md`.

For additions, insert approved content immediately before the exact active
`MANUAL PASTE ZONE` marker in the destination subsection. Keep the marker unchanged
and at the end of its subsection. Replace existing rows or paragraphs in place when a
correction is required.

## Identity and evidence

- First discovery date: 2026-09-07
- Latest evidence date: 2026-09-07
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
  every statistics area below is `Not checked` rather than `Not applicable`: the structure is
  there and has not been read.
- The rest of the catalogue was run whole, and every drill-down was taken to full coverage
  rather than left as a sample. `GLOBAL-DISCOVERY-019 EVENT_ROUND_TYPE_USAGE_DETAIL` was run
  for all five round types the sport uses;
  `GLOBAL-DISCOVERY-021 EVENT_NAME_PATTERNS_DETAIL` for all 97 name patterns;
  `GLOBAL-DISCOVERY-023 TOURNAMENT_STAGE_NAME_PATTERNS_DETAIL` for all seven stage patterns;
  and `GLOBAL-DISCOVERY-026 EVENT_RESULTS_VALUE_PATTERNS_SUMMARY` for all five result types,
  which makes it an inventory rather than a sample.
- `GLOBAL-DISCOVERY-027 EVENT_RESULTS_VALUE_PATTERNS_DETAIL` was **not** taken to full
  coverage. Every result type was instead read to exhaustion by ad-hoc profiling on
  2026-09-07, which is where the `104 Comment` and `502 Missed shots` findings below come
  from. The decision is recorded rather than implied, because a later reader comparing
  statement coverage would otherwise find a gap where a deliberate choice was made.
- **The disability class layer is not read by any statement in the GLOBAL catalogue.**
  Everything this file records about it was measured ad hoc on 2026-09-07.

## Structural coverage

| Area | Status | Evidence |
|---|---|---|
| Core hierarchy | Used | Standard five-level path; seven templates, each split into one row per gender, so a competition occupies three template ids |
| Event participants | Used | `athlete` and `team` only; athletes in male and female, teams in male, female and mixed |
| Event results | Used | Five active result types, one of which the sport cannot mean |
| Incidents | Not used | `GLOBAL-DISCOVERY-008 INCIDENT_TYPES_CODES`, a complete-layer query, returned zero active rows |
| Lineups | Not used | `GLOBAL-DISCOVERY-005 LINEUP_TYPES_PARTICIPANT_TYPES`, a complete-layer query, returned zero active rows, although the sport enters relay teams |
| Scope layer | Not used | `GLOBAL-DISCOVERY-009 SCOPE_TYPES` and `GLOBAL-DISCOVERY-010 SCOPE_DATA_TYPES_AND_LAYERS` both returned zero active rows |
| Properties | Used | Four owner objects: `event`, `event_participants`, `participant`, `tournament_stage` |
| object_relation | Used | Two active source/target combinations, neither of them the disability class |
| object_discipline | Used | One discipline vocabulary on events, carrying several ids per discipline |
| Disability class | Used | `object_disability_class` on `event`; on `participant` for one athlete only. Not an area the GLOBAL catalogue reads |
| Statistics | Not checked | Deliberately not read; see the verification boundary |
| Reference values | Used | Round types, event statuses, stage country, city and age-class storage, and the sport's registered disability classes |
| Other tables | Not checked | |

**The competition model is `Listing`, with both individual and team participants.** The
condition `../DATABASE.md` `DB-SEM-015` states was measured rather than assigned, 2026-09-07:
across the 7945 active events that hold any participant, the field ranges from 1 to 20 and
averages 6.39, only 69 events hold exactly two, and 7937 of them populate the event-level rank
result type `100 Rank`. Neither half of the `H2H` condition holds and both halves of the
`LISTING` condition do.

The 355 active events that hold no event participant at all are outside that measurement and
are not evidence of a second model; they are unpopulated events.

## Tables and relation paths used

`tournament_template` → `tournament` → `tournament_stage` → `event` → `event_participants` →
`result` is the spine, and it is fully populated. `property` is used on `event`,
`event_participants`, `participant` and `tournament_stage`. `object_relation` and
`object_discipline` are used from the hierarchy. `object_disability_class` is used from
`event` and, for a single athlete, from `participant`.

`lineup`, `lineup_participants`, `event_scope`, `scope_result` and `incident` are not used by
this sport. The lineup absence is the one worth naming: the sport enters relay teams as event
participants and scores them, but records no member under any of them, so which athlete swam
which leg is not stored anywhere. That is a `Not used` layer rather than a `Not applicable`
one, because the sport has the team entries the layer exists to describe.

<!-- MANUAL PASTE ZONE: 135 TABLES AND RELATIONS — insert approved additions immediately before this marker; do not move or delete it. -->

## Participant and lineup structure

Event participants are `athlete` and `team`. Athletes appear in male and female only; teams
appear in male, female and mixed, mixed being the largest of the three. The sport registry
(`object_participants`) files the same two types and no support role: no coach and no official
is registered anywhere in it, so the registry describes the competitors alone. Every registry
row carries the active flag `yes`.

Lineups are not used at all, so a team entry has no members. See the paragraph above.

<!-- MANUAL PASTE ZONE: 135 PARTICIPANTS AND LINEUPS — insert approved additions immediately before this marker; do not move or delete it. -->

## Event result types

| result_code | result_typeFK | Value shape | Confirmed meaning | Evidence |
|---|---:|---|---|---|
| rank | 100 | Whole numbers, and `-` where no rank was resolved | Rank | `GLOBAL-DISCOVERY-007 EVENT_RESULTS_TYPES_CODES`, `GLOBAL-DISCOVERY-026 EVENT_RESULTS_VALUE_PATTERNS_SUMMARY` |
| duration | 101 | Clock notation `m:ss.ff` and plain seconds with a fraction, side by side | Duration | `GLOBAL-DISCOVERY-007 EVENT_RESULTS_TYPES_CODES`, `GLOBAL-DISCOVERY-026 EVENT_RESULTS_VALUE_PATTERNS_SUMMARY` |
| comment | 104 | Status and progression codes, singly and combined with `/`; also duration-shaped values the field cannot mean | Comment | `GLOBAL-DISCOVERY-007 EVENT_RESULTS_TYPES_CODES`, `GLOBAL-DISCOVERY-026 EVENT_RESULTS_VALUE_PATTERNS_SUMMARY`, ad-hoc profiling 2026-09-07 |
| medal | 501 | `gold`, `silver`, `bronze` and nothing else | Medal | `GLOBAL-DISCOVERY-007 EVENT_RESULTS_TYPES_CODES`, `GLOBAL-DISCOVERY-026 EVENT_RESULTS_VALUE_PATTERNS_SUMMARY` |
| missed_shots | 502 | Plain seconds with a fraction | **Not a meaning this sport has.** See below | `GLOBAL-DISCOVERY-007 EVENT_RESULTS_TYPES_CODES`, `GLOBAL-DISCOVERY-026 EVENT_RESULTS_VALUE_PATTERNS_SUMMARY`, ad-hoc profiling 2026-09-07 |

`104 Comment` is the sport's status field and holds 43 distinct codes, the largest being `Q`,
`Disq.`, `R` and `DNS`, alongside the record marks `WR`, `CR`, `PR` and the continental `AM`,
`AS`, `AF`, `ER` and `OC`. Codes combine with `/`, as in `q/CR` and `Q/PR/AM`.
**Disqualification is written four ways in the same field** — `Disq.`, `Disq`, `DSQ` and `DQ` —
and progression two, `Q` and `q`. A check reading this field by value has to carry every
spelling or it will call a disqualified swimmer unmarked.

The same field also holds values it cannot mean: 154 rows across 54 events hold a duration, in
both the `1:00.56` and the `31.94` shapes, and one row holds the spreadsheet error string
`#NAME?`. Those are a defect in the field rather than a vocabulary to document, and they are
recorded here so the code list above is not read as the field's whole content.

**`502 Missed shots` is a Biathlon result type and this sport has no use for it.** It holds
eight rows, all in the single event 5769225 `Freestyle 400m S7 Heat 2` under
`Summer Paralympics`, with the values 39.36, 40.32, 40.85, 41.56, 42.31, 43.16, 43.75 and
48.12 — ascending in exact rank order, which is what a swim time does and what a count of
missed shots does not. The type is kept in the table above because it is genuinely present in
the sport's data; the meaning column says what it is instead.

`501 Medal` is complete in the sense that only the three medal words occur, but not in the
sense that every medal event carries all three: 1311 events hold a gold, 1299 a silver and
1289 a bronze. The 1314 gold values over 1311 events are what a dead heat produces and are not
by themselves a defect.

**`101 Duration` holds an absolute time on every rank and never a gap to the leader, and that
is recorded as a defect rather than as this sport's convention.** Measured 2026-09-07 across
all eight of its value shapes: `#:#.#`, `#.#`, `#`, `#:#:#`, and then `DSQ`, `DNS`, `Disq.` and
one value reading `Brazil`. Not one carries the `+` prefix. Swimming, the nearest sibling,
stores the same field the other way and its gap form is the largest shape it has - 370536
values of `+#.#` over 41130 events, plus 2689 of `+#:#.#`. The two sports therefore write one
field two ways.

That could have been read either way, and it was decided rather than inferred: on 2026-09-07
the user's ruling is that Para-Swimming is expected to follow the same leader-and-gap
convention Swimming follows, so the difference is a defect and not a second convention. That is
why `Para-Swimming-DQ-026`, instantiating
`GLOBAL-DQ-019 EVENT_DURATION_FORMAT_MISMATCH_TO_RANK`, is `Actionable` while reporting 7515
of 7530 events. Had the ruling gone the other way the template's own prerequisite - a sport
confirmed to follow the convention - would have made it `Not applicable`, and the check would
have been switched off for the day the gaps start being written.

The four status codes in this field - `DSQ`, `DNS`, `Disq.` on 29 values between them - belong
in `104 Comment` and not here, and the single `Brazil` belongs nowhere.

<!-- MANUAL PASTE ZONE: 135 EVENT RESULTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Incident types

The incident layer is not used. `GLOBAL-DISCOVERY-008 INCIDENT_TYPES_CODES` is a
complete-layer query and returned zero active rows. Non-start and disqualification are written
into `104 Comment` instead.

<!-- MANUAL PASTE ZONE: 135 INCIDENTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Scope types and data types

The scope layer is not used. Both `GLOBAL-DISCOVERY-009 SCOPE_TYPES` and
`GLOBAL-DISCOVERY-010 SCOPE_DATA_TYPES_AND_LAYERS` returned zero active rows.

<!-- MANUAL PASTE ZONE: 135 SCOPES — insert approved additions immediately before this marker; do not move or delete it. -->

## Properties

Four owner objects carry properties, all of property type `metadata` except one.

| Owner | Property names |
|---|---|
| `event` | `Class`, `discipline`, `ElapsedTime`, `Heat`, `Live`, `medal_related`, `ParticipantType`, `Round`, `Type` |
| `event_participants` | `organizationFK`, of property type `ref:participant` |
| `participant` | `date_of_birth`, `discipline`, `height`, `IsNationalTeam`, `status`, `weight` |
| `tournament_stage` | `Live` |

`Live` and `Round` are on every active event. `Type` carries the gender word rather than a
type, `Female` being its sample value. `height` and `weight` are on one participant each and
carry no vocabulary worth documenting.

**The `Class` event property duplicates the disability class object and is never the only
copy.** Measured 2026-09-07 across every active event in the sport: 520 events carry both the
property and the object, 7408 carry the object alone, 372 carry neither, and **no event
carries the property without the object**. Of the 520 carrying both, 507 agree and 13
disagree — for example a property reading `S10` on an event whose class object is `S9`. The
object is therefore the store and the property a redundant second copy, which is what makes
the 13 disagreements readable as a defect rather than as two fields that were never meant to
match.

<!-- MANUAL PASTE ZONE: 135 PROPERTIES — insert approved additions immediately before this marker; do not move or delete it. -->

## Generic relations and disciplines

`object_relation` carries two combinations and neither is the disability class:
`tournament_template` (`object_type` 2) → `tournament_sub_set` (152), 17 relations over five
distinct sub-sets, and `tournament_stage` (4) → `tournament_age_class` (151), 59 relations
over a single age class. The disability class does not travel through `object_relation` at
all, which is why `GLOBAL-DISCOVERY-012 OBJECT_RELATION_USAGE` reports nothing about it.

`object_discipline` is used on events and on nothing else, with 55 distinct discipline ids
over 8216 event links.

**The events point at three different catalogues, and only one of them is this sport's
current one.** Measured 2026-09-07 over every classified event:

| Catalogue | Owner | Events | Discipline ids | Years |
|---|---|---:|---:|---|
| `m` spelling, ids 465–492 | Para Swimming | 7275 | 21 | 2004–2025 |
| ids 348–375 | **Swimming, `sport.id` 46** | 788 | 18 | 2004–2025 |
| `metres` spelling, ids 439–463 | Para Swimming | 146 | 15 | 2004–2023 |

`discipline.sportFK` is what separates them, and it makes the three into two different
defects rather than one untidy catalogue:

**The 788 are a foreign reference, not a duplicate.** Those events point into the able-bodied
Swimming catalogue — the very block `SPORTS/Swimming.md` records as *its* canonical one after
the decision of 2026-08-27. `Para-Swimming-DQ-022`, instantiating
`GLOBAL-DQ-015 EVENT_SETTINGS_DISCIPLINE_MISSING_UNRESOLVED_OR_FOREIGN`, reports all 788 as
`Discipline_Belongs_To_Another_Sport`, and the counts match exactly. **268 of them are one
import**: the Summer Paralympics 2024 stages 893765, 893766 and 893767, which filed their
events against Swimming's ids while every earlier edition used this sport's own.

**The 146 are the sport's own superseded spelling**, and until 2026-09-07 nothing reported
them: `GLOBAL-DQ-015` reads a missing, unresolvable or foreign discipline and cannot see one
that resolves correctly inside the sport but on the id the sport has stopped using.
`Para-Swimming-DQ-081` now does, instantiating the
`GLOBAL-DQ-161 EVENT_SETTINGS_DISCIPLINE_ON_SUPERSEDED_CATALOGUE` written for it.

The canonical catalogue is therefore the `m` spelling, ids 465–492, carrying 7275 of the 8209
classified events. That is the same conclusion Swimming reached for its own pair and it is
derived from use rather than declared: the three disciplines that looked genuinely ambiguous
resolve on the count — `Indv. Medley 200m` to 470 over 455, `Freestyle 4 x 100m` to 482 over
457, `Medley 4 x 100m` to 484 over 458.

Seven active events carry `discipline_id` 0, which resolves to no discipline row and no name.

<!-- MANUAL PASTE ZONE: 135 GENERIC RELATIONS AND DISCIPLINES — insert approved additions immediately before this marker; do not move or delete it. -->

## Disability class

This section has no counterpart in `SPORTS/_TEMPLATE.md`. It is here because the layer is
central to how a Para sport stores its competition and because no GLOBAL statement reads it,
so nothing else in this file would record it.

The class is stored in two tables and in neither `property` nor `object_relation`:
`disability_class` is the reference table, holding `id`, `name` and `description`, and
`object_disability_class` is the link table, holding `object_typeFK`, `objectFK` and
`disability_classFK`. The shape is the same generic attach pattern as `object_discipline`.

The sport registers **45 classes** at sport level: `S1` through `S14`, `SB1` through `SB14`,
`SM1` through `SM14`, and the three relay point classes `20 Points`, `34 Points` and
`49 Points`. `S` is the freestyle, backstroke and butterfly class, `SB` the breaststroke class
and `SM` the individual medley class, so the stroke an event contests and the class prefix it
carries are not independent of one another.

| Object level | object_typeFK | Para-Swimming usage |
|---|---:|---|
| `event` | 5 | 7928 of 8300 active events carry a class |
| `participant` | 15 | 1 of 3059 registered participants carries a class |
| `event_participants` | 6 | none |
| `lineup` | 73 | none, and the sport has no lineups at all |
| `object_participants` | 59 | none |

**The athlete level is the gap.** Across the database 7867 participants carry a class and
twenty sports populate the level; Para-Swimming is last of those twenty with a single athlete,
while Para Athletics carries 3122 and Para Table Tennis 1722. At event level the same sport is
third of twenty-seven. The structure is present and reachable at both levels, and only one of
them is filled.

The 372 events with no class object are not one population. Measured 2026-09-07 against what
each event's own name states:

| What the event name states | Events |
|---|---:|
| An `S` class the object does not carry | 37 |
| An `SM` class the object does not carry | 17 |
| An `SB` class the object does not carry | 9 |
| A points class the object does not carry | 20 |
| `EAD`, which is not a class in the registered vocabulary | 12 |
| No class at all | 277 |

**Five checks read this layer, and all five were written for it on 2026-09-07.** Nothing in
the package read the disability class before that date — no discovery statement and no DQ
template — so the whole of what this section records was measured ad hoc. `../DATABASE.md`
`DB-SEM-020` now owns the structure and the templates are keyed on the vocabulary a sport
declares for itself rather than on any class-name pattern, so they apply to all 27 sports that
classify a competition and not to this one alone.

| Check | What it asserts | Para-Swimming |
|---|---|---|
| `Para-Swimming-DQ-076` `GLOBAL-DQ-156 EVENT_DISABILITY_CLASS_MISSING` | an event of a classifying sport carries no class | 372 of 8300, split 65 whose own name names a registered class and 307 that name none |
| `Para-Swimming-DQ-077` `GLOBAL-DQ-157 PARTICIPANT_DISABILITY_CLASS_MISSING` | a registered competitor carries no class | 3059 of 3060 |
| `Para-Swimming-DQ-078` `GLOBAL-DQ-158 EVENT_DISABILITY_CLASS_CONTRADICTED_BY_PROPERTY` | the `Class` property disagrees with the stored class | 13 of 520 |
| `Para-Swimming-DQ-079` `GLOBAL-DQ-159 EVENT_DISABILITY_CLASS_NOT_IN_SPORT_VOCABULARY` | an event carries a class its sport does not register | 0 of 7928 |
| `Para-Swimming-DQ-080` `GLOBAL-DQ-160 EVENT_DISABILITY_CLASS_AMBIGUOUS` | an event carries more than one class | 2 of 7928 |

The 65 in the first row is two higher than the 63 this section's table reaches by reading the
name for an `S`, `SB` or `SM` token. The check is the more correct of the two: it tests the
sport's own registered spellings as whole tokens after normalising punctuation away, so it
also catches a class written hard against a hyphen, which the hand reading missed. The two
figures are both kept because the breakdown by what the name states is still the useful one
for deciding what to repair first.

`Para-Swimming-DQ-079` reads 0 of 7928 and that is a real clean result rather than an empty
scope: every class this sport's events carry is one of the 45 it registers.

<!-- MANUAL PASTE ZONE: 135 DISABILITY CLASS — insert approved additions immediately before this marker; do not move or delete it. -->

## Statistics

Not checked. The Comp.Rank layer was deliberately not read; see the verification boundary. No
statistic type, owner level or shard is recorded here and none is recorded in
`SPORTS/params.json`, because an unread layer has no confirmed values.

When the layer is opened, one thing already known from outside it belongs in the record: **no
disability class is attached to a `statistic` row in any sport in this database.** The
`object_disability_class` link table is used at six object levels and `statistic` is not one
of them, so a Comp.Rank check reading an athlete's class has no structure to read, whatever
the Comp.Rank layer itself turns out to hold.

| statistic_typeFK | Owner type | Participant shard | Data shard | Fields/config | Evidence |
|---:|---:|---:|---:|---|---|

<!-- MANUAL PASTE ZONE: 135 STATISTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Reference values

**Round types.** Five are used: `38` named `1`, `173 Final`, `178 Semi Finals`, and `223` and
`224` **both named `Swim-Off`**. The two Swim-Off ids are distinct active rows in `round_type`
carrying the identical name, and this sport uses both, on 4 events and 2.

**They are not a duplicate.** Measured 2026-09-07: `223` carries `knockout = no` and `224`
carries `knockout = yes`, which is exactly the pair `../DATABASE.md` `DB-SEM-012` records - one
round name existing under both a knockout and a non-knockout id. A report grouping rounds by
name still merges two different things, and one grouping by id still splits what a reader
thinks of as one round, but neither row is wrong to exist.

**Three of the five carry the wrong knockout flag for what they are.** `173 Final` is
`knockout = no`, which is correct for a listing sport whose final ranks its whole field.
`178 Semi Finals` is `knockout = no` and `223 Swim-Off` is `knockout = no`, and both eliminate:
`Para-Swimming-DQ-073` and `Para-Swimming-DQ-074`, instantiating
`GLOBAL-DQ-097 EVENT_ROUND_TYPE_KNOCKOUT_FLAG_CONTRADICTS_ROUND` and its detail companion,
report those two round types and the 34 events using them. `round_type` is shared across every
sport, so what is repaired is the events rather than the flag. `38`, whose name is the bare
digit `1`, is left in neither the elimination nor the group list: its nature is not readable
from its name, and the template treats an unjudged name as unjudged rather than assuming one.

**Event statuses.** Three combinations: `notstarted` / `1 Not started`, `finished` /
`6 Finished`, and `cancelled` / `106 Cancelled`.

**Stage reference storage.** All 91 active stages carry a direct country. 88 carry a city. 59
carry the age-class relation, all of them `1 SENIOR`, and 32 carry none. The host-country
relation is not used by any stage in this sport.

**Disability classes.** The 45 registered for this sport are listed in the Disability class
section above.

<!-- MANUAL PASTE ZONE: 135 REFERENCE VALUES — insert approved additions immediately before this marker; do not move or delete it. -->

## Event and round representation

Seven tournament templates, each split into one row per gender, so a single competition
occupies three template ids: `World Championships`, `European Championships`,
`Summer Paralympics`, `Parapan American Games`, `Commonwealth Games`, `Asian Para Games` and
`World Championships Short Course`. Stage names repeat the template name exactly and carry no
other pattern, one distinct name per pattern across all seven.

`Summer Paralympics` is the exception to the three-ids rule: it occupies `10682` mixed,
`12092` female and `13434` male, the mixed row being much older than the other two.
`World Championships Short Course` mixed, template `12089`, holds zero events and zero event
participants.

**The event name is load-bearing in this sport and it is not written to one form.** All 97
active name patterns were read on 2026-09-07. The disability class appears inside the event
name in eight distinct forms — `Freestyle 100m S11`, `Freestyle 100m - S11`,
`Freestyle  100m S11` with a doubled space, `Freestyle 100mS11` with none,
`Backstroke100m S11` with none after the stroke, `Freestyle 100m S11  Heat 3`,
`Freestyle 100m S11-2`, and `Butterfly 100 S8` with the distance unit missing. The relay point
class appears in five — `34pts`, `34 pts`, `34pt`, `20 PTS` and `20 Points`.
`Individual Medley` is also written `Indv. Medley` on 24 events and `Ind Medley` on one. A
relay is named in four word orders: `Freestyle Relay 4x100m`, `4x100m Freestyle Relay`,
`Freestyle 4x100m Relay` and `Freestyle 4x100m`.

Ten events carry a name that contradicts itself, read 2026-09-07:

| What the name says | Events | Class object |
|---|---:|---|
| `Backstroke 50m SB3` — `SB` is the breaststroke class, not the backstroke one | 4 | none on any of the four |
| `Freestyle 100m Fly S7` — names two strokes | 4 | `S7` |
| `Butterfly 100 S8` — the distance carries no unit | 2 | `S8` |

**The eight `4x100m S14` relay events are not in that list and must not be read into it.** A
`Freestyle Relay 4x100m S14` and a `Medley Relay 4x100m S14` are genuine contested events: the
`S14` relay is swum by a single class, while the relays for other impairments use the point
classes. An individual class on a relay name is correct in exactly this case.

<!-- MANUAL PASTE ZONE: 135 EVENT AND ROUND REPRESENTATION — insert approved additions immediately before this marker; do not move or delete it. -->

## Confirmed sport-specific storage semantics

**A rank is written long before the event is marked as having happened.** Measured 2026-09-07
over every active event: 6474 events with status `notstarted` / `1 Not started` carry a
`100 Rank` result, against 1463 with status `finished` / `6 Finished` that do. A further 328
notstarted events carry no rank, 10 finished events carry none, and all 25 cancelled events
carry none. Status and result are therefore close to independent in this sport, and a check
treating `Not started` as meaning "no result yet" reports four fifths of it.

**That independence is recorded as a defect, not as this sport's convention.** The ruling is
the user's, 2026-09-07, on the same reasoning applied to the duration convention above: an
event holding a rank and a time has been swum, so its status is wrong rather than its results
early. `Para-Swimming-DQ-069`, instantiating
`GLOBAL-DQ-047 EVENT_RESULTS_UNEXPECTED_FOR_NOT_STARTED`, is therefore `Actionable` and
reports 6474 of 6802, with no signal recorded because `Actionable` is the default. Recorded
here because the alternative was `Monitor` - watch the proportion, work no rows - and a later
reader meeting a six-thousand-row check needs to know which of the two was chosen and why.

The cancelled population behaves the opposite way and is clean: no cancelled event carries a
rank.

<!-- MANUAL PASTE ZONE: 135 STORAGE SEMANTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Open questions

**Nothing here is open.** Every question this file raised was worked through on 2026-09-07 and
closed, and each is kept with what closed it rather than deleted: the reason a question stopped
being open is the part nobody can reconstruct from the answer alone, and a file that deletes
its answered questions invites the same work twice.

Three of the nine were closed by measurement against data nobody had looked at, and two of
those closed in the opposite direction to the question — `EAD` and the timeless events both
turned out to be the wrong question rather than an unanswered one. Four were closed by a
decision of the user's, recorded with the alternative that was rejected. Two closed by pointing
at a check that already covers them.

1. **Is the athlete-level disability class expected to be filled?** *Closed.* Measured across
   every Para sport: ten fill it for the majority of their registered athletes — Para Biathlon
   and Para Table Tennis at 85.3 per cent, Para Shooting 84.3, down to Para Judo at 43.8 — and
   seven fill none at all. Para-Swimming is in the second group, at 1 of 3060. The field is in
   real use, so `Para-Swimming-DQ-077` stays `Actionable` and its 3059 findings are a repair
   list, by the user's decision. The counter-argument was weighed and rejected: **no sport
   reaches 100 per cent**, the best being 85.3, so the expectation of zero that `Actionable`
   implies is not evidenced by any sport's practice, and `Monitor` was the alternative.
2. **Are the events whose name states no class meant to carry one?** *Closed: yes.* Every
   individual race in this sport is contested in one class and every relay in a points class
   or `S14`, so 360 of the 372 unclassified events owe one; the other 12 are question 3. The
   breakdown, against each event's own name and round:

   | Kind | Round | Events | Has a classified sibling in the same stage and discipline |
   |---|---|---:|---:|
   | individual, class nowhere | heats | 139 | 38 |
   | relay | final | 112 | 4 |
   | relay | heats | 42 | 0 |
   | individual, class nowhere | final | 36 | 5 |
   | individual, class nowhere | semi-final | 30 | 0 |
   | `EAD` | heats | 8 | 0 |
   | `EAD` | final | 4 | 0 |
   | individual, class nowhere | swim-off | 1 | 1 |

   **What the question became is where the class can be found**, and that is question 8.
   65 events name a registered class themselves and 48 have a classified sibling in the same
   stage and discipline to read one from, but the two sets overlap: **69 of the 372 are
   recoverable from inside the database and 303 are not.** An earlier draft of this section
   added the two figures and said 113, which double-counted the overlap.
3. **Is `EAD` a class this database should hold?** *Closed, and it was the wrong question.*
   All 12 `EAD` events are Commonwealth Games 2006, both genders, Freestyle 50m and 100m,
   heats and finals — and every one holds **no participant and no result**, status
   `notstarted`. There is no competition recorded to classify, so the vocabulary question has
   nothing to bite on. `EAD` appears in no `disability_class` row, in 12 event names, in one
   sport. The real finding is 12 empty shells, reported by
   `Para-Swimming-DQ-006 EVENT_NO_PARTICIPANTS` among the sport's 355.
4. **Which discipline id is the one to keep?** *Closed: the `m` block, ids 465–492.* Generic
   relations and disciplines above holds the three-way split and the two separate defects it
   resolves into. `GLOBAL-DQ-161` was written on 2026-09-07 for the half of it that nothing
   reported.
5. **Are round types `223` and `224`, both named `Swim-Off`, meant to be one row?** *Closed:
   no.* They are the knockout and non-knockout halves of one name, per `../DATABASE.md`
   `DB-SEM-012`. Recorded under Reference values.
6. **Was the Asian Para Games contested in 2014?** *Closed: yes, and the edition is missing
   here.* The 2014 games are in the database — 6 sports, 11 tournaments, 772 events, of which
   Para Table Tennis alone holds 736 — so `Para-Swimming-DQ-072` reports a real absence rather
   than an artefact of the cadence. Two findings came with it. This sport holds an **Asian Para
   Games 2007 edition of three tournaments and zero events**, under a template whose first
   real edition was 2010 and whose 2007 predecessor was a different competition, the FESPIC
   Games. And the template carries **one games under three season names at once** — `2022`,
   `2023` and `Hangzhou 2022` — the Hangzhou edition having been postponed from 2022 to 2023.

7. **Are the 162 finished events holding a place but no time the ones where nobody finished?**
   *Closed: no.* Across all 162, over 758 competitors, **not one carries a `DNS`, `DNF` or
   `Disq.` marker**. They are not events nobody finished; the time is simply absent and
   nothing explains it. The population is bounded to two editions and both are missing their
   medals as well:

   | Edition | Timeless events | Of those, also holding no medal |
   |---|---:|---:|
   | Asian Para Games 2018 | 93 | 93 |
   | Parapan American Games 2007 | 69 | 69 |

   So two imports recorded the finishing order and nothing else. `Para-Swimming-DQ-075` stays
   `Actionable`: this is a real gap and not a correct emptiness. A sample makes the shape
   plain — event 5778620, `Backstroke 100m S10` at Parapan American Games 2007, holds three
   competitors ranked 1, 2 and 3 with no time, no comment and no medal between them.
8. **Are the 303 events whose class neither their name nor a sibling can supply pursued
   through an external source, or accepted as unrecoverable?** *Closed: pursued, and with a
   priority.* The 69 recoverable from inside the database come first. Of the 303 that are not,
   **161 are a single edition, Commonwealth Games 2006**, so one source closes over half the
   remainder; the rest are spread thinly across 22 editions, the largest being Summer
   Paralympics 2004 with 24 and no other above 11.
9. **Are the `Asian Para Games` season names reconciled?** *Closed for this sport: it is not
   affected.* Para-Swimming holds only the `2023` season, 97 events dated 22-27 October 2023,
   which is when the Hangzhou games were actually held.

**A finding about other sports, made here because this is where it surfaced.** The
`Asian Para Games` template carries one games under three season names at once, and the
naming is the smaller half of it. Measured 2026-09-07:

| Season | Sport | Events | Dated |
|---|---|---:|---|
| `2022` | Para Judo | 163 | October **2022** |
| `2022` | Para Sitting Volleyball | 33 | October **2022** |
| `2022` | Para Boccia | 0 | October **2022** |
| `2022` | Para Table Tennis | 51 | October 2023 |
| `2023` | six sports | 750 | October 2023 |
| `Hangzhou 2022` | `Reference Sport` | 0 | no dates |

The Hangzhou games were held 22-28 October 2023 after a year's postponement. **196 events
across Para Judo and Para Sitting Volleyball are therefore dated a year before the competition
took place**, which is a wrong date and not a naming preference; Para Table Tennis has the
right dates under the wrong season name; and `Hangzhou 2022` hangs under a sport called
`Reference Sport` holding nothing. None of those four sports is documented in this repository,
so there is no sport file for the finding to live in and it is recorded here rather than lost.

Comp.Rank was not read; see the verification boundary. That is a deferral rather than an open
question, and it closes when the layer is opened.

<!-- MANUAL PASTE ZONE: 135 OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
