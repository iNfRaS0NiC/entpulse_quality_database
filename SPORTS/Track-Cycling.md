# SPORT: Track-Cycling (sport_id=55)

This file is the canonical structural record for Track-Cycling. It contains only confirmed
sport-specific usage, meanings, identifiers, evidence boundaries and open structural
questions. Global database mechanisms belong in `../DATABASE.md`.

For additions, insert approved content immediately before the exact active
`MANUAL PASTE ZONE` marker in the destination subsection. Keep the marker unchanged
and at the end of its subsection. Replace existing rows or paragraphs in place when a
correction is required.

## Identity and evidence

- First discovery date: 2026-08-26
- Latest evidence date: 2026-08-26
- Verification boundary: the sport was opened **without the Comp.Rank layer**, by the standing
  decision of 2026-08-26 that a sport is documented from its event results first and its
  ranking afterwards, because the ranking is generated from those results. `GLOBAL-DISCOVERY`
  `-015`, `-016`, `-017`, `-024`, `-025`, `-028` through `-031` and `-033` were therefore not
  run, and every statistics area below is `Not checked` rather than `Not applicable`: the
  structure is there and has not been read. The rest of the catalogue was run whole. `-019`,
  `-021` and `-023` were chained over the eight values each summary ranks first, so they are
  samples of the busiest shapes and never coverage; `-026` was run for every result type the
  sport uses and is an inventory rather than a sample; `-027` cannot be chained at all, because
  it needs a result type and a value shape and no single summary carries both, and it was run
  by hand for chosen pairs.

## Structural coverage

| Area | Status | Evidence |
|---|---|---|
| Core hierarchy | Used | Standard five-level path; every template is one gender, so a competition occupies a template per gender |
| Event participants | Used | `athlete` and `team` only, both genders |
| Event results | Used | Eight active result types |
| Incidents | Not used | The complete-layer query returned zero active rows; non-start, relegation and disqualification are written into result type `104 Comment` |
| Lineups | Used | One type, `14 Starter`, athletes under a team parent |
| Scope layer | Not used | Both the container query and the value-layer query returned zero active rows |
| Properties | Used | Three owner objects: `event`, `participant`, `tournament_stage` |
| object_relation | Used | Six active source/target combinations |
| object_discipline | Used | One discipline vocabulary on events |
| Statistics | Not checked | Deliberately not read; see the verification boundary |
| Reference values | Used | Round types, event statuses, stage country and city storage |
| Other tables | Not checked | |

**The competition model is `Listing`, with both individual and team participants.** The
condition `DATABASE.md` `DB-SEM-015` states was measured rather than assigned, 2026-08-26: an
event's field ranges from 1 to 80 participants and averages 8.12, so it is not fixed at two,
and effectively every active event populates the event-level rank result type `100 Rank`.

The sport is nonetheless unusual for a listing model and the reason is worth stating, because
it will mislead anybody reading the round vocabulary first. Individual Sprint and Keirin are
contested as a knockout, so a large share of the sport's events hold exactly two participants
— a sprint heat. Those are a field of two and not a pair: each side carries its own rank, the
sport writes no `Winner` event property, and no result type holds a home-or-away marker. A
check that assumes a head-to-head shape from the round names alone would be reading the
competition format rather than the storage.

## Tables and relation paths used

`tournament_template` → `tournament` → `tournament_stage` → `event` → `event_participants` →
`result` is the spine, and it is fully populated. `lineup` and `lineup_participants` hang off
the team entries. `property` is used on `event`, `participant` and `tournament_stage`.
`object_relation` and `object_discipline` are used from the hierarchy and from `statistic`.
`event_scope`, `scope_result` and `incident` are not used by this sport.

<!-- MANUAL PASTE ZONE: 55 TABLES AND RELATIONS — insert approved additions immediately before this marker; do not move or delete it. -->

## Participant and lineup structure

Event participants are `athlete` and `team`, in both genders. The sport registry
(`object_participants`) files the same two types and no support role: no coach and no official
is registered anywhere in it, so the registry describes the competitors alone. The registry
carries both active and inactive rows for both types.

Lineups use a single type, `14 Starter`, always a team parent with athlete members, in both
genders. Team Sprint, Team Pursuit and Madison are where they occur.

<!-- MANUAL PASTE ZONE: 55 PARTICIPANTS AND LINEUPS — insert approved additions immediately before this marker; do not move or delete it. -->

## Event result types

| result_code | result_typeFK | Value shape | Confirmed meaning | Evidence |
|---|---:|---|---|---|
| rank | 100 | Whole numbers only | Rank | Confirmed-data (`007`, `026`) |
| duration | 101 | Plain seconds with a fraction, clock notation, and a signed gap-to-leader form; also a small number of shapes the field cannot mean | Duration | Confirmed-data (`007`, `026`, `027`) |
| points | 102 | Whole numbers and signed negatives, with decimal fractions on some templates; also several shapes the field cannot mean | Points | Confirmed-data (`007`, `026`, `027`) |
| comment | 104 | Status codes, progression sentences, and combined forms separated by `/` | Comment | Confirmed-data (`007`, `026`) |
| laps_behind | 222 | Whole numbers, signed and unsigned | Laps behind | Confirmed-data (`007`, `026`) |
| medal | 501 | `gold`, `silver`, `bronze` and nothing else | Medal | Confirmed-data (`007`, `026`) |
| classificationpoints | 534 | Whole numbers only | Classification Points | Confirmed-data (`007`, `026`) |
| duration_full_time | 557 | Clock notation and plain seconds with a fraction, side by side | Full-time duration | Confirmed-data (`007`, `026`) |

`101 Duration` is the sport's clock field and carries three notations at once: plain seconds
with a fraction, `m:ss.fff`, and a signed form giving the gap to the leader rather than an
elapsed time. The two are not distributed by discipline or by era but sit side by
side: absolute times and signed gaps each appear in thousands of events.

**The target convention is the signed gap, decided 2026-08-26.** The winner holds an absolute
time and everyone else holds `+` their gap to it, which is what
`Track-Cycling-DQ-053 EVENT_DURATION_FORMAT_MISMATCH_TO_RANK` asserts. It is `Actionable`, not a
`Monitor`: the events storing an absolute time for every competitor are to be converted rather
than accepted as a second convention. Until they are, the check carries a large count, and that
count is the work rather than noise. The signed form is a different quantity written into the same field, which is a
structural fact about the sport and not a defect; a check reading the field as an elapsed time
has to account for it. `557 Full-time duration` carries the first two notations and not the
third.

**The `104 Comment` vocabulary is open, not closed.** Beside the short status codes it holds
whole sentences describing where a competitor came from — the progression through a knockout
— and record markers. Combined values exist and are separated by a forward slash, never by a
comma. A check that requires a closed set of status codes cannot be instantiated against this
field as it stands; `GLOBAL-DQ-052` and `GLOBAL-DQ-117` are therefore left open rather than
assigned, and the question is recorded below.

<!-- MANUAL PASTE ZONE: 55 EVENT RESULTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Incident types

`Not used`. The complete incident-layer inventory ran and returned no active rows. The
information an incident would carry — a non-start, a relegation, a disqualification — is
written into `104 Comment` instead.

<!-- MANUAL PASTE ZONE: 55 INCIDENTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Scope types and data types

`Not used`. Both the container inventory and the participant-, lineup- and detail-layer
inventory ran and returned no active rows, so the sport records no sub-event breakdown of any
kind. A sprint heat's two rides and an omnium's component races are represented as events in
their own right rather than as scopes under one event.

<!-- MANUAL PASTE ZONE: 55 SCOPES — insert approved additions immediately before this marker; do not move or delete it. -->

## Properties

Three owner objects carry active properties.

| Owner | Property names |
|---|---|
| `event` | `discipline`, `Heat`, `Live`, `medal_related`, `ParticipantType`, `Race`, `Round`, `Type`, `Verified` |
| `participant` | `date_of_birth`, `discipline`, `height`, `IsNationalTeam`, `status`, `tdf_stage_wins`, `weight` |
| `tournament_stage` | `Live`, `StatusComment` |

`Race` is specific to this sport among those documented and sits beside `Heat`, so a
competitor's position in a session is recorded on two axes. `tdf_stage_wins` is a road-cycling
property carried on participants shared with that sport and says nothing about track results.

**No `Winner` property exists**, consistent with the listing model recorded above, and no
`organizationFK` property is written on event participants.

<!-- MANUAL PASTE ZONE: 55 PROPERTIES — insert approved additions immediately before this marker; do not move or delete it. -->

## Generic relations and disciplines

`object_relation` is active on six source/target pairs, linking the sport to its category,
templates to a reference object, and events and statistics to age classes and to a further
object type.

`object_discipline` attaches a single discipline vocabulary to events, and the same vocabulary
to tournament-owned statistics. The vocabulary is large and describes the format rather than
the apparatus: the sprint and endurance events each have their own id, the omnium's component
races are separate disciplines from the omnium itself, and several distances of time trial and
several named formats such as Madison, Keirin, Derny and the six-day are distinct entries.

<!-- MANUAL PASTE ZONE: 55 GENERIC RELATIONS AND DISCIPLINES — insert approved additions immediately before this marker; do not move or delete it. -->

## Statistics

| statistic_typeFK | Owner type | Participant shard | Data shard | Fields/config | Evidence |
|---:|---:|---:|---:|---|---|

`Not checked`, deliberately and by the decision recorded in the verification boundary above.
Tournament-owned statistics exist for this sport and carry disciplines — that much is visible
from `object_discipline`, which was run — but no statistics discovery query was run, no field
inventory was taken, and no statistic parameter is recorded in `SPORTS/params.json`. This is
an unread layer, not an absent one, and nothing here may be treated as evidence that the sport
does or does not use a given statistic shape.

<!-- MANUAL PASTE ZONE: 55 STATISTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Reference values

Active event statuses are `finished` with `6 Finished`, `cancelled` with `106 Cancelled`, and
`notstarted` with `1 Not started` and `5 Postponed`.

Stage-level reference storage uses a direct country link and a city link; the age-class
relation is used from both events and statistics.

<!-- MANUAL PASTE ZONE: 55 REFERENCE VALUES — insert approved additions immediately before this marker; do not move or delete it. -->

## Event and round representation

**The sport contests two parallel round-type vocabularies at once.** Several rounds exist
under two different `round_type` ids carrying the same name — the Final, the Semi Finals, the
1/8 and 1/16, the first-round repechage and more. One id of each pair carries the great
majority of the sport's events and the other carries a handful. This is a structural fact
about the data and not a reading of counts: both ids are in active use, so any parameter
naming a round has to name both, and a list built from the busier id alone silently excludes
the other. Which of each pair is canonical is an open question below.

A number of round types carry a purely numeric name — `1` through `6` — and the commonest
round in the sport is one of them. They sit beside the named rounds rather than replacing
them, so a check keying on a round's name rather than its id will read them as unnamed.

Some active events carry `round_typeFK = 0`, which resolves to no round type at all.

**A placement round ranks from its own place range, not from one.** The sport contests finals
for places 5–8, 7–12 and 9–12 under round types of those names, plus a Small Final and a
separate bronze round. Six riders in a final for places 7–12 hold ranks 7 through 12, so the
sequence correctly starts above one and every rank correctly exceeds the field size. This is
the sport's format and not a defect, and it is written down here because two checks read it as
one: `Track-Cycling-DQ-030 EVENT_RESULTS_RANK_OUTLIER_ABOVE_FIELD_SIZE` and
`Track-Cycling-DQ-031 EVENT_RESULTS_RANK_SEQUENCE_BROKEN` were both approved on 2026-08-26
with that stated. Measured the same day, placement rounds account for a little over half the
events either of them reports; the remainder — events under the generic `173 Final` and under
round type `1`, where a field of fifteen holds a rank of nineteen — is the part worth reading,
and what a rank means in round type `1` is an open question below.

Event names repeat the discipline and frequently append the competition, so the name is not a
stable key for the format; the discipline relation is.

<!-- MANUAL PASTE ZONE: 55 EVENT AND ROUND REPRESENTATION — insert approved additions immediately before this marker; do not move or delete it. -->

## Confirmed sport-specific storage semantics

Every `tournament_template` belongs to exactly one gender, so a competition that exists for
both occupies two templates with two ids and one name. Any list of templates naming a
competition has to carry both, and a client scope built by name will silently take one gender.

`101 Duration` holds an elapsed time and a gap-to-leader in the same field, distinguished only
by the leading sign. See the result-type section above.

**`GLOBAL-DQ-082 TOURNAMENT_STAGE_EVENT_DISCIPLINE_INCONSISTENT` is `Not applicable` here,
structurally.** The template asserts that a tournament stage contests one discipline, and this
sport's stage is a whole championship: one Olympic stage holds eight disciplines across
seventy-nine events, and the shape repeats across the World Cup, the Nations Cup and every
continental championship. The prerequisite the template names is not met by the sport's model
rather than by its current rows, so no CheckID is assigned and none is reserved. Decided
2026-08-26.

**`GLOBAL-DQ-096 EVENT_NAME_DOES_NOT_NAME_ITS_PARTICIPANTS` is `Not applicable` here, and the
template says so itself.** It is written for head-to-head sports by the competition model, on
the reasoning that naming an event after the competitors is what `Team 1 - Team 2` is, and a
sport that lines a field up and ranks it has nothing to put in such a name. The rule was stated
on 2026-08-16 after road Cycling reported its whole population, and this sport reports its whole
population for exactly that reason: every event is named for its discipline. No CheckID is
assigned. Decided 2026-08-26.

**Four more templates are `Not applicable` here, and each for its own reason.** None is
assigned a CheckID and none reserves one; decided 2026-08-26.

`GLOBAL-DQ-117 EVENT_RESULTS_COMMENT_INVALID_OR_CONTRADICTED_BY_SCORE` is excluded by the rule
`GLOBAL_DQ/README.md` states: a sport instantiates it or `GLOBAL-DQ-052`, never both, because
the two read the same population and would report every unrecognised status twice under two
CheckIDs. This sport stores a time on its result, so `GLOBAL-DQ-052` is the stronger of the two
and is what `Track-Cycling-DQ-055` runs.

`GLOBAL-DQ-087 EVENT_WINNER_MISSING_OR_INVALID` needs a `Winner` event property and the sport
writes none anywhere, which the property inventory confirms.

`GLOBAL-DQ-083 EVENT_PARTICIPANT_COUNT_NOT_A_FIELD_THE_SPORT_ENTERS` needs the set of field
sizes the sport enters, and there is no such set: a field runs from one competitor to eighty
without settling on fixed sizes.

`GLOBAL-DQ-118 EVENT_ROUND_TYPE_KNOCKOUT_FLAG_CONTRADICTS_ROUND_DETAIL` reports the same defect
as `Track-Cycling-DQ-072` once per event rather than once per round type. Measured the same day,
the thirteen mis-flagged round types it rests on produce 10 158 event rows — `176 Quarter Finals`
alone carries 2640 of them — and correcting the thirteen clears every one. The repair list is
the other check; this one would put the size of the consequence on the board and nothing to act
on.

**Fourteen disciplines are decided on the clock and the sprint is not one of them.** The
pursuits, the team sprint, the time trials at every distance and the omnium's timed components
are ridden against the watch. `377 Individual Sprint` and `379 Keirin` record a time and are
not settled by it: a heat is won by whoever crosses first, and a tactical sprint is routinely
won slower. `TIMED_DISCIPLINE_LIST` therefore leaves both out, decided 2026-08-26 with the cost
of the other reading measured — admitting them raised one check from 3922 findings to 16277.

**`557 Full-time duration` is a field the sport has barely begun to fill.** It stands on fifteen
events where `101 Duration` stands on more than twelve thousand. It is declared as
`RESULT_FULL_TIME_TYPE_ID` anyway, and `Track-Cycling-DQ-059
EVENT_DURATION_FULL_TIME_MISMATCH_TO_RANK` is `Actionable` rather than a `Monitor`: the full
time is expected on a timed event and its absence is the defect the check exists to report.
Decided 2026-08-26, which means the check reports very nearly its whole scope until the field is
filled, and that count is the work rather than noise.

**A points race separates equal scores rather than sharing a place.** Riders finishing an
Omnium on the same points are ordered by their finish in the last race, so equal points at
different ranks is the rule there and not a defect. The timed formats are the opposite: equal
times do have to share a place. `RESULT_TIE_VALUE_TYPE_LIST` therefore names both `101 Duration`
and `102 Points` — a shared place does have to agree on whichever figure its event was decided
by — and `Track-Cycling-DQ-057 EVENT_RESULTS_TIED_VALUE_WITHOUT_SHARED_RANK` is a `Monitor`
because it reads that agreement the other way round and reports every points tie. Decided
2026-08-26; the timed half of what it audits is what to read in it.

**In much of the sport the placing is not derived from a stored value.** A sprint or a keirin
heat is settled by who crosses the line first, and its riders carry a rank and nothing else: no
time and no points. The timed formats and the points races do store the figure their placing
comes from, but the heats are the larger share of the sport's events.

`Track-Cycling-DQ-056 EVENT_RESULTS_RANK_WITHOUT_DECIDING_VALUE` is a `Monitor` for that reason,
decided 2026-08-26. It cannot reach zero while the sport keeps that model, and narrowing
`RESULT_TIE_VALUE_TYPE_LIST` makes it worse rather than better. It is kept because a missing
value in the events that *are* decided on one is a real defect, and that is what to read in it.

**The sport awards its medals under two conventions at once.** A points race, a scratch or a
madison final is one race with the whole field and the finish decides gold, silver and bronze
together. A sprint or a keirin final is two riders deciding gold and silver, and bronze falls to
a separate round — `186 Small Final` or `181 bronze`, both of which award bronze and never gold.
`MEDAL_ROUND_TYPE_LIST` therefore names five rounds and `BRONZE_ROUND_TYPE_LIST` two, and neither
list describes the whole sport on its own.

`Track-Cycling-DQ-050 EVENT_RESULTS_MEDAL_SET_INVALID_FOR_MEDAL_ROUND` is a `Monitor` for exactly
this reason, decided 2026-08-26. The template reads a final as a two-sided match and reports
every listing final that carries a bronze, which is the great majority of what it returns and is
the sport behaving normally. It is kept rather than dropped because its other four branches are
sound — a final holding places and no medal at all, a bronze round with none, a final missing
gold or silver, and a medal awarded twice — and those are what to read in it.

**A stage is often declared wider than the events it holds** — an Olympic stage running to the
9th whose last event starts on the 8th, because the Games run to the 9th and the track program
finishes earlier. That is the sport, not a defect, and
`Track-Cycling-DQ-033 TOURNAMENT_STAGE_EVENT_OUTSIDE_DATE_RANGE` does not report it: the
template asserts that a stage contains its events, not that it matches them exactly. It asserted
the exact match until 2026-08-26, when it was changed to containment for every sport at once,
because equality reads how a sport rounds a stage rather than whether the stage holds its
competition.

**It is `Actionable`, decided 2026-08-26**, and what it now returns is the other direction only:
an event starting before its stage begins or after it ends, measured that day at 53 stages of
510. A stage the sport declares generously is silent here.

**Two checks audit nothing today, and both are sentinels rather than misdirected scopes.**

`Track-Cycling-DQ-032` has an eligible count of zero because it reads the organization a competitor is entered
under, the sport enters nobody under one, and the scope is exactly right for the day that
changes. `Track-Cycling-DQ-015` is the check that demands the field be filled, and this one
starts working the moment it is.

`Track-Cycling-DQ-039 EVENT_MIXED_TEAM_LINEUP_GENDER_BALANCE_UNEVEN` has an eligible count of
zero because the sport has contested no mixed-gender team event. The structure allows one: a
template of gender `mixed` exists under this sport, and it holds a tournament and a stage. It
holds no events yet, and the day it does the check has something to audit. An empty population
under a structure that exists is a data state, which is why this is recorded here and not as
`Not applicable`.

**Two fields the sport populates nowhere at all.** No event carries a venue, and no event
participant carries an `organizationFK` property. Neither is recorded here as unused: a field
nothing fills is a data state and not a structural absence, and both are reported as defects by
`Track-Cycling-DQ-014 EVENT_MISSING_VENUE` and `Track-Cycling-DQ-015
EVENT_PARTICIPANT_ORGANIZATION_MISSING`, which is where the population is read. Between them
they account for the great majority of the sport's finding rows, and that is the two feeds
saying the same thing once per event rather than a crowd of separate defects.

<!-- MANUAL PASTE ZONE: 55 STORAGE SEMANTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Open questions

1. Which id of each duplicated round-type pair is canonical, and whether the minority id is a
   defect to be corrected or a second vocabulary to be carried. The user's reading of
   2026-08-26 is that it is a defect to be repaired; until it is, both ids are in use.
2. What `round_typeFK = 0` means on the events that carry it.
3. Whether the numeric round names `1` through `6` denote a session, a heat number or a
   round, and how they relate to the `Heat` and `Race` event properties.
4. Whether `104 Comment` can be reduced to a closed vocabulary, and if not, which checks that
   require one are permanently inapplicable here.
5. Which disciplines are decided on the clock and which on points or on a judged placing, so
   that a timed-discipline list can be recorded.
6. Which field the placing is derived from in each discipline — `101 Duration` for the timed
   formats, `102 Points` for the points races — since the sport has no single deciding value.
7. Whether the two templates that hold tournaments but no stages or events at all, and the
   three that hold a single stage and no events, are a client-scope boundary or an import
   defect. The user's reading of 2026-08-26 is that they are a defect, while the IOC-purpose
   templates are out of client scope.
8. Whether a venue is expected on this sport's events at all. It is recorded on none of
   them, and the check that reports it was opened on 2026-08-26 with that stated rather
   than assumed.
9. Why half of the sport's team entries carry no lineup, when every one of them is a genuine
   team format — Team Sprint, Team Pursuit, Madison.
10. What a rank means under round type `1`, where a field of fifteen can hold a rank of
    nineteen. The reading that fits is an overall classification written into a heat, which
    would make the rank correct and the field the wrong denominator for it, but that is a
    reading and not evidence.
11. The Comp.Rank layer in full, deferred by the decision in the verification boundary.

<!-- MANUAL PASTE ZONE: 55 OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
