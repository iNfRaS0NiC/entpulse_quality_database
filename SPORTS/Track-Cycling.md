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

**Every team format is ridden by a fixed number of riders, and two of them changed that
number without changing their discipline id.** Measured 2026-08-26 across every team entry
carrying a lineup:

| Discipline | Gender | Sizes the sport enters | Sizes also present |
|---|---|---|---|
| Team Pursuit | male | 4 (2530) | 3 (8), 5 (23) |
| Team Pursuit | female | 3 (528), 4 (1385) | 2 (1), 5 (11) |
| Team Sprint | male | 3 (2618) | 1 (2), 2 (3), 4 (30), 6 (1) |
| Team Sprint | female | 2 (1650), 3 (357) | 1 (4), 4 (11) |
| Madison | both | 2 (3389) | 1 (5), 3 (13), 4 (4), 5 (1) |
| Team Elimination, Derny, 20Km Madison, 250m Team Time Trial | both | 2 | none |

The two female rows carry two correct sizes each and neither is a defect: the women’s team
pursuit went from three riders over three kilometres to four over four, and the women’s team
sprint from two riders to three. The discipline id did not change with the distance, so the
record of a discipline’s size has to be a set and not a number. `Track-Cycling-DQ-077` is
written that way and needs no cut-off date. **The same shape appears twice more in this
sport** — in the Omnium’s scoring and in the two women’s record progressions — and it is
recorded here because a check written against a single expected value would be wrong in all
three places.

**Derny is a pair here, not a solo ride.** All 55 Derny lineups hold two riders, because the
sport’s Derny events sit inside six-day meetings and are ridden by the meeting’s pairs. The
`500m Madison Time Trial` filed under `394 Time Trial` is a pair for the same reason. Both
are recorded because the discipline names read as individual formats and are not.
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

**`222 Laps behind` carries one quantity under two sign conventions.** A rider one lap down
is written `-1` in some disciplines and `1` in others, and both mean the same thing.
Measured 2026-08-26:

| Discipline | Events written negative | Events written positive |
|---|---:|---:|
| Scratch | 69 | 26 |
| Omnium - Scratch race | 53 | 7 |
| Madison | 19 | 39 |
| 6-days | 0 | 69 |
| Elimination Race, Stayer 50 km | 2 | 0 |

No event mixes the two inside itself; the disciplines mix them between each other. This is
the same shape `101 Duration` has with its three notations, in a second field.

**The target convention is the unsigned form, decided 2026-08-26** — one lap down is `1`,
which is what the field name says. Roughly 143 events are written the other way and are to be
converted. No check asserts this yet: `Track-Cycling-DQ-075` reads the field as a magnitude
precisely so that it works under either convention and does not have to wait for the
conversion.
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

**The Omnium reversed the direction of its scoring in 2014, and `102 Points` records both
eras in one column.** Through 2013 the classification was a sum of finishing places and the
lowest total won; from 2015 it is accumulated points and the highest wins. Measured
2026-08-26 on `383 Omnium - Overall`:

| Years | Events scored highest-wins | Events scored lowest-wins |
|---|---:|---:|
| 2007 - 2013 | 0 | 43 |
| 2014 | 8 | 4 |
| 2015 - 2024 | 96 | 0 |

Nothing in a row says which rule applies to it, only the date of the event that holds it.
**Any statement reading `102 Points` as good-or-bad must therefore not assert a direction at
all**, which is why `Track-Cycling-DQ-074` asks only that a single event agree with itself.
`378 Point race` was highest-wins in every year measured and did not change.

**In the knockout disciplines the event named `Final` is the competition’s final standings,
not its last race.** A Team Pursuit `Final` holds the whole field ranked 1 to 15, and each
competitor’s `104 Comment` says how far it got — `From Final`, `From Final for Bronze`,
`From First Round`, `DNQ for First Round`. Only the four who contested the medal rides carry
a time. That is why `101 Duration` stands on 29% of Individual pursuit participations and 40%
of Team Sprint ones while standing on 100% of the individual time trials, and it is the
storage model rather than missing data.

**A gap is measured from the winner of its own sub-final, not from the winner of the event.**
A Keirin `Final` holding twelve riders holds two races: ranks 1 to 6 comment `From Final 1-6`
and ranks 7 to 12 comment `From Final 7-12`. Within each, the winner carries no value and the
rest carry a gap to it, so rank 8 can hold `+0.074` while rank 3 holds `+0.125` and both are
correct. The same follows for absolute times: a Team Sprint bronze final is a separate ride,
so the bronze medallist legitimately records a faster time than the gold — measured
2026-08-26, `ev 5126345` has the winner on 43.116 and the third place on 42.446. **No check
may assert that a time or a gap is monotonic across a whole event of these disciplines.**

**Three checks were written for this sport on 2026-08-26**, and they are the first statements
it owns; every other check on its board is a GLOBAL template.

`Track-Cycling-DQ-074 EVENT_RESULTS_POINTS_RUN_BOTH_DIRECTIONS_AGAINST_RANK` returns 49 of
1305. It is scoped to the eleven disciplines in which the sport awards points by finishing
position. The counts it projects are what makes it readable: `ev 4365018` holds 228 pairs
agreeing with its direction and 1 against, so the minority column points at the wrong rows
rather than at the event.

`Track-Cycling-DQ-075 EVENT_RESULTS_LAPS_BEHIND_CONTRADICT_RANK` returns 4 of 283, in two
branches: a competitor ranked ahead of one it is lapped further behind than, and two on the
same lap ordered against their points. Small today, and it guards the rule the Madison, the
20Km Madison and the six-day are actually classified by, which nothing else on the board
reads.

`Track-Cycling-DQ-076 EVENT_DURATION_GAP_WITHOUT_AN_ABSOLUTE_TIME` returns 20 of 3235: a
timed event whose every stored time is a gap, with nothing to measure the gaps from.
`Track-Cycling-DQ-053` cannot see this, because `GLOBAL-DQ-019` reaches a competitor through
the Duration row itself and a rank 1 holding no Duration is not a row it joins.

**The sprint and the keirin are why that last check is scoped.** The sport holds 5415 events
whose times are all gaps and 5393 of them are `377 Individual Sprint` or `379 Keirin`, where
the clock settles nothing and the habit is the sport. Running it unscoped would bury the 20.

**`GLOBAL-DQ-142` reads this sport correctly and needed no help.**
`Track-Cycling-DQ-029 EVENT_PARTICIPANT_TYPE_CONTRADICTS_DISCIPLINE` returns 18 of 19231, and
its one-per-cent threshold with a hundred-event floor lands exactly where a hand-written rule
would have had to: it reports the six Team Pursuits entered with individual athletes and the
four Team Sprints, and it stays silent on `391 Derny`, `394 Time Trial` and `389 6-days`,
which hold both kinds legitimately. A six-day Derny is ridden by the meeting’s pairs and a
`500m Madison Time Trial` by a pair as well, so a discipline list naming Derny and Time Trial
as individual formats would have been wrong. Recorded 2026-08-26 because the threshold looks
arbitrary until a sport shows what it is protecting.
**Two disciplines hold the other one’s distance, and the split follows gender.** Measured
2026-08-26 over every well-formed time:

| Discipline | Gender | Times | Range | What that distance is ridden in |
|---|---|---:|---|---|
| `123 1km Individual time trial` | female | 514 | 33.30 - 82.21 | a kilometre is 55.4 at world record |
| `122 500m Individual time trial` | male | 22 | 59.19 - 69.20 | 500 m is about 26 to 45 |
| `396 Omnium - 500m Ind. time trial` | male | 75 | 60.91 - 73.70 | as above |

451 of the female kilometre times fall under 50 seconds, across 31 events named
`1 KM Time Trial`, `Individual 1 km time trial` and `Time Trial`. No woman rides a kilometre
in 33 seconds; those are five-hundred-metre times. Every male 500 m time in the sport, and
every male Omnium 500 m time, is a kilometre. Historically the championship distance was
500 m for women and 1 km for men, and the two disciplines look to have been assigned from
that expectation rather than from the race that was ridden.
`Track-Cycling-DQ-079` reports them, and whether the repair belongs to the discipline or to
the event name is an open question below.

**Three more checks were written on 2026-08-26**, taking the sport’s own statements to six.

`Track-Cycling-DQ-077 EVENT_TEAM_LINEUP_SIZE_NOT_A_FIELD_THE_DISCIPLINE_ENTERS` returns 118
of 13829 team entries. `Track-Cycling-DQ-022` cannot reach what it finds: `GLOBAL-DQ-068`
compares the teams inside one event against each other, so an event where every squad is the
wrong size passes it. `ev 4706595` holds four team pursuit squads of five and `ev 4706594`
four team sprint squads of four, all typed `14 Starter` — a squad list with its reserve
recorded where the starters belong.

`Track-Cycling-DQ-078 EVENT_DURATION_WRITTEN_IN_A_NOTATION_THE_SPORT_DOES_NOT_USE` returns 12
of 12629 events in three branches: 10 write the minute separator as a dot (`4.30.752`), 1
writes the fraction separator as a colon (`46:17:00`), and 1 writes a clock value with no
fraction at all (`13:40` for a flying 200 m). All ten of the first branch come from one
template, the Oceania Track Championship, between 2017 and 2025, so the repair is one feed.
Neither existing check sees any of it: `GLOBAL-DQ-120` excludes a two-dot value from its
numeric pattern outright and `GLOBAL-DQ-019` tests only the leading plus.

`Track-Cycling-DQ-079 EVENT_DURATION_IMPLAUSIBLE_FOR_ITS_DISCIPLINE` returns 64 of 3053,
holding 608 values. Its bands are placed in gaps in the measured distribution and are wide
enough for every level the sport is raced at; only the fixed-distance disciplines are read,
because a scratch race has no expected duration and the sprint stores three different
quantities in the field depending on the round.

**A check on the record markers was written, measured and withdrawn on 2026-08-26.** The idea
was that a `WR` or `OR` must stand on a time no slower than the record before it. Tested
against the best of its own year it returned 33 of 71, and most of those are correct: a
record set in qualifying is beaten later the same day by the record that succeeds it, which
is what a progression looks like. Tested against everything before it, it breaks on the two
distance changes above — every women’s team pursuit record from 2016 is slower than the
2012 ones because the race became a kilometre longer, and the same for the team sprint in
2024. The comparison set is also polluted by the times `Track-Cycling-DQ-079` exists to
report: the best male team sprint time of 2021 reads as 0.000. It is recorded as withdrawn
rather than left unmentioned, because the idea is a natural one and the next reader should
not have to measure it again to find out why it does not work.
**Three more checks were written on 2026-08-26, taking the sport’s own statements to nine.**

`Track-Cycling-DQ-080 EVENT_TIMED_FINISHER_WITHOUT_A_TIME` returns 172 of 671 and
`Track-Cycling-DQ-081 EVENT_POINTS_FINISHER_WITHOUT_POINTS` 188 of 1854. Between them they
ask per discipline the question `Track-Cycling-DQ-056` can only ask of the sport as a whole.
That template asks whether a ranked competitor holds any deciding value and can never reach
zero here, because a keirin, a scratch and an elimination rider each carry a rank and nothing
else, correctly. Asked of a discipline the question has an answer: a kilometre is settled by
the clock and a points race by the points, and where the figure is missing the placing rests
on nothing stored. The two are kept apart on purpose - together they return 360 events, past
the point where a board row is read.

A missing `102 Points` row is not a score of zero. The sport writes the zero: `ev 5025645`
records `Frank Longstaff 0` in twelfth, and negative totals go down to -37 for a lapped
Madison pair.

`Track-Cycling-DQ-082 EVENT_TIMED_SPREAD_TOO_WIDE_FOR_ONE_RACE` is a `Monitor` returning 12
of 3053. Of the 1704 timed events holding three times or more, 1499 spread by less than 1.15
and another 176 reach 1.30, then 17 reach 1.60, 8 reach 2.00 and 4 go beyond, so the cut is
placed in a gap. It is a Monitor because a wide spread is a symptom rather than a defect and
the reading decides which: `ev 5171646` is a Team Pursuit holding 4.877 against 257.318, and
`ev 4706591` an Individual pursuit holding 2:18 against 4:29.

**The Omnium’s components cannot be tied to their own overall, and a check that would have
summed them was withdrawn on 2026-08-26.** What was learned in the attempt is worth keeping.

A stage holding an Omnium holds, measured that day on `stage 897000`: two `Omnium` events with
the `Round` property `Qualifier`, then `Omnium - Scratch race`, `Omnium - Tempo race` and
`Omnium - Elimination race` each with `Round = 1`, then **an `Omnium` event with `Round = 1`,
which is the points race** - filed under the container discipline `397 Omnium` rather than
under `381 Omnium - Point race` - and finally an `Omnium` with `Round = Final`, the overall.
So `Round` is what separates an overall from a component, and the discipline id alone is not.

It is still not a key. `object_relation` is written on none of these events, and grouping by
stage over-collects because a stage here is a whole championship: of 199 overall events, 51
reach only one component, 83 reach two, 50 reach three, 12 reach four and 3 reach more than
four. Even among the twelve the total agrees for 3 events and 103 riders of 189. The
components are not there, and where they are they are not provably the right ones.
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

12. Whether four disciplines are duplicates of four others rather than formats in their own
    right: `401 10Km Scratch Race` holds one event beside `398 Scratch` with 507,
    `400 20Km Madison` holds four beside `380 Madison` with 496, `392 250m Team Time Trial`
    holds two, and `548 Stayer 50 km` holds one while the Steherrennen races of the
    six-day meetings are filed under `389 6-days`. Each names a distance where the
    discipline it resembles names none.
13. What `102 Points` means on the events of `377 Individual Sprint`, `379 Keirin`,
    `398 Scratch` and `399 Elimination Race` that carry it. None of those four is decided on
    points, and the value is left unread rather than guessed: `Track-Cycling-DQ-074` is
    scoped away from them for that reason: measured 2026-08-26, admitting them adds the
    56 events those four hold to its 49.
14. Whether a non-finisher should hold a rank. Measured 2026-08-26 the sport answers both
    ways for the same status: `DNS` holds one on 324 participations and none on 412, `DNF`
    1730 against 981, `Disq.` 138 against 135. `Track-Cycling-DQ-055` reports the
    status-with-a-rank half under the existing vocabulary; which half is correct is not
    settled here.
15. Whether the 500 m and 1 km time trials are to be repaired by moving the events to the
    other discipline or by correcting the times, and what the events named `1 KM Time Trial`
    that hold 500 m times should be called afterwards.
16. Whether a lineup should ever hold a rider who did not start. All lineups in this sport
    are typed `14 Starter`, and the oversized squads read as a full selection with its
    reserve. If a reserve is to be recorded, it needs a second lineup type rather than a
    fifth starter.
17. What ties an Omnium component race to the overall it counts towards. The `Round` property
    separates the overall from the components and the stage does not narrow far enough, so
    today a competition’s four races cannot be identified as belonging together. Until they
    can, no check can assert that the overall equals their sum.
18. Why the Omnium points race is filed under `397 Omnium` with `Round = 1` while its three
    sibling races have disciplines of their own, and whether `381 Omnium - Point race` was
    meant to carry it.
<!-- MANUAL PASTE ZONE: 55 OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
