# SPORT: Biathlon (sport_id=7)

This file is the canonical structural record for Biathlon. It contains only confirmed
sport-specific usage, meanings, identifiers, evidence boundaries and open structural
questions. Global database mechanisms belong in `../DATABASE.md`.

For additions, insert approved content immediately before the exact active
`MANUAL PASTE ZONE` marker in the destination subsection. Keep the marker unchanged
and at the end of its subsection. Replace existing rows or paragraphs in place when a
correction is required.

## Identity and evidence

- First discovery date: 2026-08-27
- Latest evidence date: 2026-08-27
- Verification boundary: the sport was opened **without the Comp.Rank layer**, by the standing
  decision of 2026-08-26 that a sport is documented from its event results first and its
  ranking afterwards, because the ranking is generated from those results. `GLOBAL-DISCOVERY`
  `-015`, `-016`, `-017`, `-024`, `-025`, `-028` through `-031` and `-033` were therefore not
  run, and every statistics area below is `Not checked` rather than `Not applicable`: the
  structure is there and has not been read. The rest of the non-statistics catalogue ran whole.
  `-026` was run by hand for **every one of the ten result types the sport uses**, not chained,
  so the result inventory is coverage rather than a sample. The four detail statements `-019`,
  `-021`, `-023` and `-027` were not run: their summaries answered the structural question on
  their own, and a sport with two round types and eleven event-name patterns has nothing left
  for a drill-down to resolve.

## Structural coverage

| Area | Status | Evidence |
|---|---|---|
| Core hierarchy | Used | Standard five-level path; every competition occupies one template per gender plus a `mixed` template that holds the mixed relays |
| Event participants | Used | `athlete` in two genders and `team` in three, `mixed` included |
| Event results | Used | Ten active result types, four of them specific to the sport |
| Incidents | Not used | The complete-layer query returned zero active rows; non-starts, laps and disqualifications are written into result type `104 Comment` |
| Lineups | Used | Two types, `14 Starter` and `6 Unknown`, athletes under a team parent |
| Scope layer | Used | Eleven checkpoint containers plus `305 final_result`, over three storage layers and eight data types |
| Properties | Used | Four owner objects: `event`, `event_participants`, `participant`, `tournament_stage` |
| object_relation | Used | Six active source/target combinations |
| object_discipline | Used | One discipline vocabulary, on events and on tournament-owned statistics |
| Statistics | Not checked | Deliberately not read; see the verification boundary |
| Reference values | Used | Event statuses, stage country, age class |
| Other tables | Not checked | |

**The competition model is `Listing`, with both individual and team participants.** The
condition `DATABASE.md` `DB-SEM-015` states was measured rather than assigned, 2026-08-27:
an individual event’s field runs from 8 to 207 competitors and averages 84.35, a team
event’s from 3 to 35 averaging 21.85, and 2570 of the sport’s 2571 events populate the
event-level rank result type `100 Rank`. Nothing here is fixed at two and nothing is
head-to-head.

## Tables and relation paths used

`tournament_template` → `tournament` → `tournament_stage` → `event` → `event_participants` →
`result` is the spine and it is fully populated. `lineup` hangs off the team entries.
`event_scope` is used heavily, with values on three layers: `scope_result` owned by an event
participant, `lineup_scope_result` owned by a single lineup row, and `event_scope_detail`
naming the checkpoint. `property` is used on `event`, `event_participants`, `participant`
and `tournament_stage`. `object_relation` and `object_discipline` are used from the hierarchy
and from `statistic`. `incident` is not used by this sport.

<!-- MANUAL PASTE ZONE: 7 TABLES AND RELATIONS — insert approved additions immediately before this marker; do not move or delete it. -->

## Participant and lineup structure

Event participants are `athlete` in `male` and `female`, and `team` in `male`, `female` and
**`mixed`**. The mixed team is not an artefact: 119 distinct mixed teams have contested 3727
participations, and two disciplines exist for them alone.

The sport registry (`object_participants`) files the same two types and **no support role at
all** — no coach and no official is registered anywhere in it, so the registry describes the
competitors alone. Five athletes are filed inactive against 6860 active.

**Lineups use two types, not one.** `14 Starter` carries 39280 rows and `6 Unknown` carries
543, both with a team parent and athlete members, in both genders. What distinguishes the
second from the first is an open question below.

<!-- MANUAL PASTE ZONE: 7 PARTICIPANTS AND LINEUPS — insert approved additions immediately before this marker; do not move or delete it. -->

## Event result types

| result_code | result_typeFK | Value shape | Confirmed meaning | Evidence |
|---|---:|---|---|---|

| rank | 100 | Whole numbers only | Rank | Confirmed-data (`007`, `026`) |
| duration | 101 | A `+` gap to the leader in two scales, and a plain absolute time on one row per event | Duration | Confirmed-data (`007`, `026`) |
| points | 102 | Whole numbers only | Points | Confirmed-data (`007`, `026`) |
| comment | 104 | A near-closed set of status codes, with a timed-penalty sentence | Comment | Confirmed-data (`007`, `026`) |
| startnumber | 408 | Whole numbers only | Start number | Confirmed-data (`007`, `026`) |
| medal | 501 | `gold`, `silver`, `bronze` and nothing else | Medal | Confirmed-data (`007`, `026`) |
| missed_shots | 502 | Whole numbers only | Missed shots | Confirmed-data (`007`, `026`) |
| additional_shots | 503 | Whole numbers only | Additional shots | Confirmed-data (`007`, `026`) |
| secondpoints | 510 | Whole numbers only | Second points | Confirmed-data (`007`, `026`) |
| duration_full_time | 557 | Clock notation in `m:ss.t` and `h:mm:ss.t` | Full-time duration | Confirmed-data (`007`, `026`) |

**`101 Duration` and `557 Full-time duration` are a pair, and the sport keeps it cleanly.**
`557` holds the elapsed time and stands on 2098 events in `m:ss.t` and 804 more in
`h:mm:ss.t`. `101` holds the gap to the leader: measured 2026-08-27 it is written `+m:ss.t`
130799 times and `+ss.t` a further 14220, against only 2099 plain absolute values — almost
exactly one per event, which is the winner. This is the leader-and-gap convention
`GLOBAL-DQ-019` asserts, followed rather than approximated.

**Four of the ten result types are the biathlon and exist in no other documented sport.**
`502 Missed shots` stands on 153602 participations across 2544 events and is the shooting.
`503 Additional shots` is the spare round and stands on 591 events, which are the relays.
`510 Second points` is a second scoring scale beside `102 Points`: measured 2026-08-27 it
runs 1 to 160 in the individual disciplines and 50 to 420 in the relays, on 512 events, which
is the shape of a nations-standings allocation rather than a race result. `408 Startnumber`
records the bib.

<!-- MANUAL PASTE ZONE: 7 EVENT RESULTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Incident types

`Not used`. The complete incident-layer inventory ran and returned no active rows. The
information an incident would carry — a non-start, a lapping, a disqualification, a time
penalty — is written into `104 Comment` instead.

<!-- MANUAL PASTE ZONE: 7 INCIDENTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Scope types and data types

**This sport uses the scope layer more heavily than any documented before it.** Twelve
container types are active: `101 checkpoint1` through `111 checkpoint11`, and `305
final_result`. They are the intermediate splits of a race, and `event_scope_detail` names
each one in words — `1. Shooting`, `1. Leg Exchange`, `1. Shooting (3. Leg)`, `2. Shooting
(4. Leg)`, `Finish`. An individual race reaches five containers; a relay reaches all twelve.

Values sit on two layers rather than one, and the difference is the relay:

| Layer | Owner | Data types | Rows |
|---|---|---|---:|
| `scope_result` | an event participant | `1 rank`, `3 comment`, `4 duration`, `273 missed_shots`, `274 additional_shots`, `296 duration_full_time` | 205218 rank rows |
| `lineup_scope_result` | **a single lineup row** | the same six, plus `978 leg_rank` and `979 leg_time` | 58851 rank rows |

`lineup_scope_result` is what makes a relay readable: each leg’s rider carries their own
checkpoint rank, time, missed shots and spare rounds, under the team that entered them.
`978 leg_rank` and `979 leg_time` exist on that layer alone, on 48 containers.

A statement reading a checkpoint therefore has to know which layer its question lives on. The
individual disciplines answer from `scope_result` and the relays from `lineup_scope_result`,
and neither layer covers the other.

<!-- MANUAL PASTE ZONE: 7 SCOPES — insert approved additions immediately before this marker; do not move or delete it. -->

## Properties

Four owner objects carry active properties.

| Owner | Property names |
|---|---|
| `event` | `checkpoints`, `checkpoint_details`, `discipline`, `last_updated`, `Live`, `medal_related`, `ParticipantType`, `Round`, `topresults`, `Type` |
| `event_participants` | `startnumber`, `organizationFK` |
| `participant` | `date_of_birth`, `height`, `IsNationalTeam`, `status`, `weight` |
| `tournament_stage` | `StatusComment` |

`checkpoints` and `checkpoint_details` are specific to this sport among those documented: the
first counts a race’s splits and the second lists them in order, so the scope containers are
described twice — once as rows and once as a property on the event that owns them.

**`organizationFK` is written**, on 139 event participations. That is a small number against
143681 participations, but it is not zero, which separates this sport from Track Cycling
where the field is empty throughout. **No `Winner` property exists**, consistent with the
listing model.

<!-- MANUAL PASTE ZONE: 7 PROPERTIES — insert approved additions immediately before this marker; do not move or delete it. -->

## Generic relations and disciplines

`object_relation` is active on six source/target pairs, linking the sport to its category,
templates to a reference object, stages to an age class, and statistics to a country, a
participant and an age class.

**Nine disciplines, and the split between individual and team formats is absolute.**
Measured 2026-08-27 across every event the sport holds:

| Contested by one athlete | Contested by a team |
|---|---|
| `252 Individual`, `253 Sprint`, `254 Pursuit`, `256 Mass Start`, `260 Super Sprint` | `255 Team Mixed Relay`, `257 Relay`, `258 Single Mixed Relay`, `259 Single Relay` |

Not one event breaks that split, which is worth recording because it is unusual: the sports
documented before this one all hold at least a handful of events entered with the wrong kind
of competitor. The same vocabulary is attached to tournament-owned statistics.

<!-- MANUAL PASTE ZONE: 7 GENERIC RELATIONS AND DISCIPLINES — insert approved additions immediately before this marker; do not move or delete it. -->

## Statistics

| statistic_typeFK | Owner type | Participant shard | Data shard | Fields/config | Evidence |
|---:|---:|---:|---:|---|---|

`Not checked`, deliberately and by the decision recorded in the verification boundary above.
Tournament-owned statistics exist for this sport and carry disciplines — that much is
visible from `object_discipline`, which was run — but no statistics discovery query was run,
no field inventory was taken, and no statistic parameter is recorded in `SPORTS/params.json`.
This is an unread layer, not an absent one, and nothing here may be treated as evidence that
the sport does or does not use a given statistic shape.

<!-- MANUAL PASTE ZONE: 7 STATISTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Reference values

Active event statuses are `finished` with `6 Finished` on 2575 events, `cancelled` with
`106 Cancelled` on 128, and `notstarted` with `1 Not started` on 70 and `5 Postponed` on 2.

Stage-level reference storage uses a direct country link; the age-class relation is used from
stages and from statistics, and resolves to three values of which `1 SENIOR` is the common
one. No stage carries a city link and none carries a host-country relation.

<!-- MANUAL PASTE ZONE: 7 REFERENCE VALUES — insert approved additions immediately before this marker; do not move or delete it. -->

## Event and round representation

**The sport contests two round types and no more.** `173 Final` carries 2755 events and
`179 Qualifier` carries 20, the Super Sprint qualification heats. There is no bracket, no
repechage and no placement round anywhere in the sport, which makes every round-keyed
parameter here a two-value list.

**An event name states the distance and the format, and states them reliably.** The eleven
name patterns measured 2026-08-27 are `# km Sprint`, `#.# km Sprint`, `# km Individual`,
`#.# km Pursuit`, `# x # km Relay`, `Mixed # x # + # x #.# km Relay`,
`Single Mixed # + #.# km Relay` and their siblings. The name is therefore a usable second
reading of the discipline, unlike the sports where it repeats the competition instead.

<!-- MANUAL PASTE ZONE: 7 EVENT AND ROUND REPRESENTATION — insert approved additions immediately before this marker; do not move or delete it. -->

## Confirmed sport-specific storage semantics

**Every competition occupies one template per gender, and a third for the mixed events.** A
World Cup round is templates 12382 male, 12383 female and 8 mixed. Any list of templates
naming a competition has to carry all three, and a scope built from the single-gender pair
silently drops the mixed relays.

**The client scope excludes 25 of the sport’s 58 templates, decided 2026-08-27.** Fifteen
are the IOC-purpose templates, which hold 352 tournaments between them and not one event.
The other ten are second-tier or memorial competitions the client does not follow: the IBU
Cup, the Norwegian championships `NM`, `Season Start` and `Winter Olympics medal winners`.
The boundary removes 249 events of 2775 and leaves 2526 with 143681 participations.
A 26th template, `89 Norges Cup 1`, was named in the same decision and needs no entry: it is
`del = yes` and holds no tournament, so no statement in this package can read it.

**`104 Comment` resolves to a near-closed vocabulary, which is unusual for this project.**
The values are `DNS`, `LAP`, `DNF`, `Disqualified`, `LPD`, `FF#`, `NC`, `DSQ`, and a
timed-penalty sentence of the form `Time penalty # minutes`. It is near-closed and not
closed: three spellings of disqualification are in use at once — `Disqualified` on 602 rows,
`DSQ` on 9 and `Disq.` on 2 — and `FF#` and `FF #` differ only by a space. Whether those are
to be unified is an open question below, and until it is answered a check requiring a closed
set can be instantiated but will report the minority spellings.

**The first two DQ categories were opened on 2026-08-27** — `WRONG_STRUCTURE` and
`NO_RELATED_RECORDS`, the first priority band. Of their 33 templates, 16 are instantiated as
`Biathlon-DQ-001` through `-016`, four are `Not applicable` structurally, twelve wait on the
Comp.Rank layer and one was withdrawn after being measured.

**Six of the sixteen return nothing, and that is a finding rather than an absence.**
`GLOBAL-DQ-142` finds no event entered with the wrong kind of competitor, `GLOBAL-DQ-129`
none holding two kinds at once, `GLOBAL-DQ-137` no duplicated start number, `GLOBAL-DQ-104`
no invalid participant reference, `GLOBAL-DQ-102` no scope value owned by the wrong event,
and `GLOBAL-DQ-001` and `-139` nothing at the template level. Each has 2359 or 33 events in
scope, so the population is there and the defect is not.

**`Biathlon-DQ-004 TOURNAMENT_NO_STAGES` returns 76 and every one is a mixed template.**
Measured 2026-08-27, all 76 empty tournaments sit under the mixed-gender template of their
competition — 10876, 11042, 10882, 11040, 8, 9594, 11009, 7, 106 and 11010. The mixed
template carries a tournament for every season the competition has run, and the mixed relay
entered each competition only at some point in its history, so the early seasons hold a
tournament with nothing under it. **It is `Actionable` and not a `Monitor`, decided
2026-08-27**: a tournament with no stage describes nothing and is to be removed, not kept as
a placeholder beside its two single-gender siblings.

**`Biathlon-DQ-005 EVENT_NO_PARTICIPANTS` returns 167 and only 5 of them are a defect.** The
template separates them itself: 90 rows are `cancelled` events, which have no field because
they were never held, and 72 are `notstarted` fixtures reaching into 2027. Five carry
`NO_PARTICIPANTS_FINISHED_EVENT` and those are the ones to read.

**The World Championships is not held in an Olympic year, and `SERIES_SKIP_YEARS` is 0
anyway.** `Biathlon-DQ-006` reports a gap at 2005 to 2007, 2009 to 2011, 2013 to 2015 and so
on for both single-gender World Championships templates, and every one of those gaps is an
Olympic year. Naming 2006, 2010, 2014, 2018, 2022 and 2026 in the parameter clears them and
takes the check from 10 findings to 7 — and then makes the European Youth Olympic Festival
worse, because with those years removed its biennial rhythm reads as annual and it reports
five breaks each on three templates. The parameter is sport-wide and no value is right for
every template here, so it stays at 0 and the Olympic-year rhythm is written down here
instead. Decided 2026-08-27.

**`GLOBAL-DQ-107 EVENT_SCOPE_CONTAINER_MISSING_FOR_FINISHED` is not instantiated, and the
reason is the history of the checkpoint feed rather than the shape of the sport.** Run on
2026-08-27 it returns 1433 of 2363, and reading them splits the number three ways:

| What the rows are | Events |
|---|---:|
| Finished before 2013, when no event in the sport carried a checkpoint | 913 |
| In competitions where the layer has never once appeared | 473 |
| In competitions that do record it | 47 |

From 2013 the layer follows the competition tier exactly and not the calendar. The Winter
Olympics, the mixed World Cup and the Summer World Championships are complete; the
single-gender World Cup and the World Championships are near-complete; and the World Junior,
World Youth, European, European Junior, European Youth Olympic Festival, Winter Youth
Olympics and Asian Winter Games templates carry not one checkpoint between them, ever.

**The 47 are one changeover and not a defect.** Keyed on the tournament rather than the
template the check returns **zero**: no event anywhere lacks a checkpoint in a tournament
that has them, so the layer is all-or-nothing per season. The 47 resolve to exactly five
tournaments — the World Cup 2012/2013 male and female, and the World Championships 2013
male, female and mixed. That is the season the feed was switched on. A sport statement for
them was designed, measured and not written, because it would report the month a feed
started. Recorded so the next reader who measures 1433 does not have to take the same three
steps to find out there is nothing under them.

**`Biathlon-DQ-007` and `-011` are the same defect at two grains, and both are kept.**
`GLOBAL-DQ-097` names the round type to repair — `179 Qualifier` is stored as not a
knockout when a qualifier eliminates, and the template even names `152` as the correct id
— and `GLOBAL-DQ-118` lists the 20 events that carry it. Track Cycling declined the second
of that pair on 2026-08-26 because it amplified 13 round types into 10158 event rows; here
one round type produces 20, so the consequence is readable and the pair is worth having.

**Four templates are `Not applicable`, structurally, and none reserves a CheckID.** Decided
2026-08-27. `GLOBAL-DQ-083` needs the set of field sizes the sport enters and there is no
such set: an individual field runs from 8 to 207. `GLOBAL-DQ-089` needs an extra-period
scope and this sport’s scope layer holds checkpoints, not periods. `GLOBAL-DQ-091` asserts
that a period is stored for both sides of a match and a listing sport has no two sides.
`GLOBAL-DQ-135` needs coaches or officials in the registry and this sport registers none.

**Twelve templates are `Not checked` and none is `Not applicable`.** `GLOBAL-DQ-009`, `-010`,
`-030`, `-040`, `-042`, `-101`, `-103`, `-105`, `-106`, `-113`, `-115` and `-136` all need a
Comp.Rank parameter, and that layer was deliberately left unread. The structure exists and
the pause is expected to lift.
**The next two DQ categories were opened on 2026-08-27** — `WRONG_RESULTS` and
`MISSING_VALUES`, the second and third priority bands. Of their 58 templates that do not
read the Comp.Rank layer, 42 are instantiated as `Biathlon-DQ-017` through `-058`, fifteen
are `Not applicable` structurally and one waits on the paused layer. Twenty-three of the
forty-two return nothing today over a populated scope, and that is a reading rather than an
absence.

**Three checks report almost their whole population, because the sport does not fill the
field anywhere.** `Biathlon-DQ-056` finds no organization on 2359 event participants of
2359, `-046` no venue on 2410 events of 2526, and `-029` names one missing stage field and
it is the same one every time — `city`, on all 848 stages, with 2 of them also missing
`host_country`. **All three are `Actionable`, decided 2026-08-27**, which follows the
standing rule that an unfilled organization is a defect and never `Not applicable`, and
matches Track Cycling, where the same two checks stand at 19665 of 19665 and 19245 of 19245.
Three field-wide absences are three repairs, not five and a half thousand.

**A lapped biathlete has a place and no time, and two checks are `Monitor` because of it.**
Measured 2026-08-27, 1712 ranked competitors carry no full time and 1504 of them are marked
`LAP` or `LPD`:

| Comment on a ranked competitor holding no full time | Competitors | Events |
|---|---:|---:|
| `LAP` — lapped in a mass start, pursuit or relay | 926 | 178 |
| `LPD` — lapped, relays only | 578 | 134 |
| `DNS` — did not start, yet holds a place | 147 | 27 |
| no Comment row at all, in one Individual | 19 | 1 |
| `DNF`, `NC`, `Disq.` and the `LPD FFn` forms | 42 | 15 |

A competitor stopped on the course never crosses the line, so the time is correctly absent
while the classification stands. `Biathlon-DQ-034` asks for a full time wherever a Rank is
stored and `-052` asks whether a ranked competitor holds the value the place was built from;
both read the same population from opposite sides and both are dominated by it, at 327 and
312 events. **Neither is `Actionable` and neither is dropped, decided 2026-08-27**: the rows
worth reading are the 147 `DNS` holding a place, the 16 `DNF` and the 19 uncommented
competitors, and a `Monitor` keeps them visible without asking anybody to drive a correct
population to zero.

**Adding `lap` and `lpd` to `RESULT_COMMENT_NO_RESULT_LIST` would clear both, and was
rejected the same day.** The parameter names the spellings meaning the competitor has no
classified result, and a lapped one has a place. The edit would make `Biathlon-DQ-036` report
all 926 `LAP` and 578 `LPD` rows as a no-result status stored beside a rank — trading two
Monitors for 1504 false findings. The parameter describes the sport correctly and the signal
carries the consequence instead.

**The Comment vocabulary is sixty codes and the data holds ninety-seven spellings of them.**
`RESULT_COMMENT_VALUE_LIST` admits `FF1` through `FF45`, `LPD FF18` through `LPD FF23`,
`DNS`, `DNF`, `Disqualified`, `LAP`, `LPD`, `NC` and the three time penalties. Left out on
purpose, so `Biathlon-DQ-036` reports them:

| Spelling left out | Rows | First seen | Last seen |
|---|---:|---|---|
| `FF n` with a space, against the current `FFn` | 79 | 2009-12-12 | 2013-03-23 |
| `DSQ`, against `Disqualified` | 9 | 2004-02-22 | 2026-01-11 |
| `Disq.`, against `Disqualified` | 2 | 2009-04-03 | 2009-04-03 |

**The spaced form and the empty Comment are the same era.** It ran only from December 2009 to
March 2013, and the unspaced form runs from 2006 to 2025 and is current — so the spacing is
a window and not a convention. The 8502 Comment rows written empty close on 2013-03-23, the
same day. Three spellings of one status is what the check exists to name, so the canonical
sixty were chosen over the ninety-seven on 2026-08-27. `Biathlon-DQ-036` reports 97 of 7530:
85 unrecognised values and 12 `DNS` holding a place.

**`RESULT_COMMENT_NO_RESULT_LIST` names three spellings and not five, and the package test is
why.** `GLOBAL_DQ/README.md` says the list may hold a spelling the value list rejects, so that
a contradiction is found however the status is written. `TOOLS/Test-Package.ps1` refuses that
combination and is right on this package: the same check would report the value invalid and
honour it as a no-result marker in one run. `DSQ` and `Disq.` were dropped from the no-result
list rather than admitted to the value list, because admitting them would stop the sport being
told it spells one status three ways. Nothing goes unseen — both still arrive, under
`COMMENT_INVALID_VALUE` instead of `COMMENT_NO_RESULT_WITH_TIME`, and exactly one row changes
its reading: a single `DSQ` stored beside a full time.

**`Biathlon-DQ-054` reports 295 events and 701 of its 708 tied groups are a plain pair.**
Two competitors carry an identical recorded time and were given different places; in a sport
settled by the clock an equal time is a shared place. Five groups hold three competitors and
two hold eight, and those two are worth a separate look, but they are 2 groups of 708 and the
shape is otherwise uniform. `Actionable`, decided 2026-08-27.

**`GLOBAL-DQ-082 TOURNAMENT_STAGE_EVENT_DISCIPLINE_INCONSISTENT` is `Not applicable`, and
the count is not why.** Its prerequisite admits only a sport whose stage groups one
discipline. A biathlon stage is a whole competition week: `Winter Olympics 2006` holds
Individual, Mass Start, Pursuit, Sprint and Team Mixed Relay under one stage, and an
`Oestersund` World Cup week holds Pursuit, Relay and Sprint. All 788 of 843 read like that.

**Three more scope templates are `Not applicable` for the reason `GLOBAL-DQ-089` and `-091`
already were.** `GLOBAL-DQ-085` needs the periods to sum to the total and excludes a
checkpoint split by name; `-086` and `-092` need a score stored period by period and a
sentinel for a period nobody played. This sport stores neither. Measured 2026-08-27, the
twelve containers hold `1 rank`, `3 comment`, `4 duration`, `273 missed_shots`,
`274 additional_shots` and `296 duration_full_time` and nothing else — split times and shots
at a point on the course, never a period with a score. The exclusion is structural and is not
the client boundary: the UK Sport scope does not need the checkpoints, but that would have
been a signal rather than an applicability, and `Biathlon-DQ-008` stays on the board unchanged.

**Nine templates need a head-to-head contest or a deciding score, and a listing sport ranked
on the clock stores neither.** `GLOBAL-DQ-084`, `-087`, `-088`, `-090`, `-094`, `-108`,
`-114` and `-126` all read a `RESULT_FINAL_SCORE_TYPE_ID`, a mirrored pair of score fields or
a `Winner` event property, and this sport has no scalar score at all: `102 Points` and
`510 Second points` are awarded from the finishing place rather than deciding it.
`GLOBAL-DQ-093` needs a sport deciding bronze in its own match, and a biathlon race awards
all three medals at once, which is what `Biathlon-DQ-031` already asserts.

**Two more are excluded by the templates themselves rather than by the sport.**
`GLOBAL-DQ-116` is superseded by `GLOBAL-DQ-021` and is never to be instantiated anywhere.
`GLOBAL-DQ-117` may not stand beside `GLOBAL-DQ-052`, and the choice between them is not a
preference: this sport stores a time on its result, so `-052` is the one whose time arm can
run, and it carries `Biathlon-DQ-036`.

**`GLOBAL-DQ-007 PARTICIPANT_MISSING_DATE_OF_BIRTH` is `Not checked`, not `Not applicable`.**
It counts an athlete history through a statistic shard and needs a `STATISTIC_TYPE_ID` and a
`SHARD_ID`, so it belongs to the paused Comp.Rank layer with the twelve from the first two
categories.
**Five sport statements were written on 2026-08-27, `Biathlon-DQ-059` through `-063`.** They
came out of reading the shooting and timing data rather than out of a template, and each
asserts something no GLOBAL template can express because it depends on what a biathlon
format physically allows.

**`-059 EVENT_RELAY_DISCIPLINE_CONTRADICTS_LINEUP_GENDER` reads the lineup and not the
name.** A relay names the athletes who skied it, so the genders in the lineup are a recorded
fact about the race, and `255 Team Mixed Relay` and `258 Single Mixed Relay` cannot have been
contested by one gender. Measured 2026-08-27:

| Filed discipline | Lineup holds | Events | Reading |
|---|---|---:|---|
| `Team Mixed Relay` | male only | 9 | wrong, 2005-03-12 to 2013-02-16 |
| `Team Mixed Relay` | female only | 9 | wrong, 2005-03-11 to 2013-02-15 |
| `Relay` | male and female | 1 | wrong, a `3 x 6 km Relay` of 2023-03-07 |
| `Relay` | one gender | 362 | correct |
| `Team Mixed` and `Single Mixed` | male and female | 151 | correct |

Eighteen of the nineteen sit inside the same 2005 to 2013 window that the spaced `FF n`
comment and the empty Comment rows occupy. Only `male` and `female` are read, so a lineup
whose participant carries neither cannot manufacture a finding.

**The first reading of this was wrong and the correction is the point.** Grouped by event
*name* rather than by event, `4 x 6 km Relay` reported `male | female` and looked like ten
mixed races carrying an abbreviated name. Grouped by event, each of the ten is single-gender.
The name was right and the discipline was wrong, which is the opposite conclusion, and only
the per-event grouping can tell them apart.

**`-060 EVENT_NAME_NAMES_A_DIFFERENT_DISCIPLINE_THAN_THE_ONE_FILED` reaches where no lineup
exists.** Every event here is named after its format, so the name carries a claim that can be
compared with `object_discipline`. It is kept beside `-059` rather than folded into it,
because a lineup is written only for a relay and this check reads every individual discipline
as well. Measured 2026-08-27, 29 events of 2526 inside the client boundary and 39 across the
whole sport: three Mass Start events filed as Pursuit, three Super Sprint qualification heats
filed as Sprint, one `7.5 km Sprint` filed as Mass Start, one `15 km Individual` and one
`10 km Pursuit` both filed as Sprint, and the relay families `-059` also reports.

**The branch order is the sport’s own hierarchy and getting it wrong costs 69 false
findings.** `Single Mixed 2 x 6 + 2 x 7.5 km Relay` does not contain the words
`Single Mixed Relay` next to each other, and neither does `Single 6 + 7.5 km Relay` contain
`Single Relay`. Tested for adjacency, 59 correct Single Mixed Relays and 10 correct Single
Relays reported as wrong. The statement tests for the words separately and reads the most
specific form first: Single Mixed, then Mixed, then Single, then plain Relay; and
`Super Sprint` before `Sprint`.

**`-061 EVENT_MISSED_SHOTS_ABOVE_WHAT_THE_DISCIPLINE_FIRES` uses a ceiling that is a fact
about the format.** A competitor cannot miss more rounds than they are given to fire:

| Discipline | Bouts | Rounds fired | Highest miss count stored |
|---|---:|---:|---:|
| `252 Individual` | 4 | 20 | **88** |
| `253 Sprint` | 2 | 10 | **13** |
| `260 Super Sprint` | 4 | 20 | **30** |
| `254 Pursuit` | 4 | 20 | 20 |
| `256 Mass Start` | 4 | 20 | 18 |

Measured 2026-08-27, 4 events of 1832 and 19 competitors. One `15 km Individual` of the 2023
European Championships holds five at 67, 70, 79, 86 and 88 against a ceiling of 20, all of
them placed 87th to 91st; one `5 km Super Sprint Final` of 2020 holds ten at 21 to 30. The
other two are the other half of `-060`: their 11 to 13 misses are correct for the race that
was run and break only the ceiling of the discipline they were wrongly filed under.

**The relay disciplines are deliberately outside `-061`.** There the result row belongs to a
team, so 24 misses across four legs is possible where 24 by one athlete is not, and this
project has not confirmed what a team row counts. Asserting a team ceiling would be asserting
something nobody has checked.

**`-062 EVENT_TIMED_VALUE_SHARED_BY_THREE_OR_MORE_COMPETITORS` is set at three and not two on
purpose.** This sport writes to a tenth of a second, so two competitors sharing a value is an
ordinary tie and `Biathlon-DQ-054` already reads every one of them - 701 pairs of 708 groups.
Three or more sharing one value while holding different places is a shape a pair can never
show. Measured 2026-08-27, 4 events of 2358: one `10 km Pursuit` of the 2021 European
Championships holds **eight competitors at `33:55.400` with a gap of `+4:42.700`, placed 46th
to 53rd**, and the other three hold three each. Both `101 Duration` and `557 Full-time
duration` are read, because a placeholder written into one is usually written into both.

**`-063 EVENT_SPARE_ROUNDS_IN_A_DISCIPLINE_THAT_FIRES_NONE`, and the fact that decided its
scope.** A spare round is a relay rule, so `503 Additional shots` is a field that
`252 Individual`, `253 Sprint`, `254 Pursuit` and `256 Mass Start` have no way to fill.
**`260 Super Sprint` does fire spare rounds and is not in the list**, established 2026-08-27
from the data itself: it carries the field on 18 of its 27 events with values up to 4, which
is a format in use. The four disciplines named carry it on 4 events between them and every
one of those rows holds `0` - an empty row an import created, not a figure anybody recorded.
Measured the same day, 4 events of 1926: two Sprints and two Pursuits.

**`WRONG_DISCIPLINE` was opened by these two checks rather than by the category being named.**
`-059` and `-060` fall in it, and the two categories opened on 2026-08-27 were `WRONG_RESULTS`
and `MISSING_VALUES`. The checks themselves were approved concretely, by what each asserts,
and the category follows from what they assert rather than the other way round. Its three
GLOBAL templates - `GLOBAL-DQ-100`, `-109` and `-110` - are still unread, and two of the
three need the Comp.Rank layer.
<!-- MANUAL PASTE ZONE: 7 STORAGE SEMANTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Open questions

1. What separates lineup type `6 Unknown` from `14 Starter`. The second carries 39280 rows
   and the first 543, both with the same parent and member types.
2. Whether `Disqualified`, `DSQ` and `Disq.` are to be unified, and likewise `FF#` and
   `FF #`. Until they are, `104 Comment` is near-closed rather than closed.
3. What `LPD` means beside `LAP`, and whether the two are the same status written twice.
   Measured 2026-08-27, `LAP` stands on 1446 rows over 337 events and `LPD` on 599 over 139.
4. Why two `101 Duration` values are written as a negative gap. A gap measured from the
   leader cannot be below zero.
5. Why 88 `100 Rank` values over 25 events, 90 `101 Duration` values over 27 and 8502
   `104 Comment` values over 229 are stored empty rather than absent.
6. Why `255 Team Mixed Relay` was contested in single-gender stages — 9 male events and 9
   female between 2005 and 2013 — and why `257 Relay`, a single-gender format, appears in a
   mixed stage 9 times from 2017. One of the two is a stage gender that does not match its
   discipline, and which is not settled here.
7. Why the medal set is uneven at the sport level: 2340 events carry a gold, 2336 a silver
   and 2336 a bronze.
8. What `510 Second points` is the standing for, and whether its two ranges — 1 to 160
   individually and 50 to 420 in relays — are one allocation read at two scales or two
   separate competitions.
9. Whether `125 Para Biathlon`, a separate `sport` row holding 2 templates and 42 events from
   2022, is inside the client’s interest. It is a distinct sport and would be its own
   opening.
10. The Comp.Rank layer in full, deferred by the decision in the verification boundary.

11. What a relay’s `502 Missed shots` counts. A team row reaches 24, which is exactly the
    ceiling on spare rounds for four legs, so it may be penalty loops rather than missed
    rounds, and it may be a sum across the legs or the worst single leg. Until it is settled,
    `Biathlon-DQ-061` reads only the individual disciplines and the relays are unaudited on it.
12. Whether the ten events named `Mixed Relay` and filed under `257 Relay` were mixed. This is
    question 6 read from the lineup rather than from the stage, and the lineup disagrees with
    both: only one plain Relay in the whole sport holds male and female athletes together, and
    it is a different event, of 2023. So either the name is wrong on all ten or their lineups
    are single-gender by mistake. `Biathlon-DQ-060` reports them and `-059` does not, and that
    disagreement between the two checks is the open question rather than a defect in either.
13. Why `Mixed Relay 3 х 6 km` is written with a Cyrillic х where a Latin x belongs. Noticed
    2026-08-27 while reading `Biathlon-DQ-060`. No check asserts it: `MALFORMED_NAME` is not an
    opened category for this sport, and the name is not what `-060` compares.
<!-- MANUAL PASTE ZONE: 7 OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
