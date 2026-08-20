# SPORT: Swimming (sport_id=46)

This file is the canonical structural record for Swimming. It contains only confirmed
sport-specific usage, meanings, identifiers, evidence boundaries and open structural
questions. Global database mechanisms belong in `../DATABASE.md`.

For additions, insert approved content immediately before the exact active
`MANUAL PASTE ZONE` marker in the destination subsection. Keep the marker unchanged
and at the end of its subsection. Replace existing rows or paragraphs in place when a
correction is required.

## Identity and evidence

- First discovery date: 2026-08-20
- Latest evidence date: 2026-08-20
- Verification boundary: `GLOBAL-DISCOVERY` 001-014, 018, 020, 022, 026 and 032 were run for
  the sport and every statement returned; none failed. Every **summary** named below is
  therefore complete coverage of what the sport stores.

**The Comp.Rank half of the catalogue was deliberately not run.** 015, 016, 017, 024, 025,
028, 029, 030, 031 and 033 were left unexecuted on instruction: this sport's Comp.Rank rows
are to be generated from its event results *after* those results are corrected, so reading
the statistic layer now would document a layer that is about to be rebuilt. The Statistics
area below is `Not checked`, never `Not applicable` - the structure exists and
`GLOBAL-DISCOVERY-012` and `-013` both reach `object_typeFK = 83` for this sport.

Detail statements were run only for values chosen to answer a question: `GLOBAL-DISCOVERY-019`
for round type 0, and `GLOBAL-DISCOVERY-027` for Duration `-#.#`, `DNS` and `#` and for
Comment `#NAME?`, `?` and `R?`. Each is a sample of the value it was run for and nothing
wider. `GLOBAL-DISCOVERY-021` and `-023` were not run at all, so the event-name and
stage-name families below rest on their summaries alone.

## Structural coverage

| Area | Status | Evidence |
|---|---|---|
| Core hierarchy | Used | 85 templates under `tt.sportFK = 46`, standard five-level path |
| Event participants | Used | `athlete` and `team` only |
| Event results | Used | Five active result types |
| Incidents | Not used | The complete-layer query returned zero active rows; the sport writes non-start and disqualification into result type `104 Comment` instead |
| Lineups | Used | One type, `14 Starter`, athletes under a team parent |
| Scope layer | Used | Six container types, checkpoints and a final result, on long-distance events only |
| Properties | Used | Four owner objects |
| object_relation | Used | Six active source/target combinations |
| object_discipline | Used | Two discipline vocabularies in simultaneous use on events |
| Statistics | Not checked | Deliberately not read; see the verification boundary |
| Reference values | Used | Round types, event statuses, the result comment vocabulary |
| Other tables | Not checked | |

**The competition model is `Listing`, with both individual and team participants.**
`DATABASE.md` `DB-SEM-015` states the model as a condition on rows, and the condition was
measured rather than assigned, 2026-08-20: an event's field ranges from 1 to 133 participants
and averages 10.36, so it is not fixed at two, and the sport populates the event-level rank
result type `100 Rank`. Events holding exactly two participants exist and are a field of two,
not a pair: they carry a rank each like any other field.

## Tables and relation paths used

The sport uses the standard hierarchy without deviation:
`tournament_template -> tournament -> tournament_stage -> event -> event_participants`,
anchored on `tt.sportFK = 46`.

**A template is one gender.** Nearly every competition is stored as two or three templates
carrying the same name and differing only in `tournament_template.gender` - `British
Championships` is 12593 male and 12594 female, `World Championships Long Course` is 12589
male, 12590 female and 8864 mixed. A statement that identifies a competition by template name
alone therefore addresses a fraction of it. The mixed template is not always the relay
template: it is also where the older undivided imports sit.

**Five templates carry the `(IOC)` suffix and none of them holds a stage or an event.** They
are 12788, 12791 and 12797 `World Championships Long Course (IOC)`, 12792 `Open Water World
Championships (IOC)` and 12799 `Marathon Swim World Series (IOC)`. They hold tournaments and
nothing beneath them, which is the same shape Equestrian's IOC templates have.

<!-- MANUAL PASTE ZONE: 46 TABLES AND RELATIONS — insert approved additions immediately before this marker; do not move or delete it. -->

## Participant and lineup structure

**`event_participants` carries only `athlete` and `team`.** Athletes swim individual events
and teams swim relays; a relay's swimmers are reached through the lineup rather than through
the event participation. Team participations exist in all three genders, athlete
participations in two.

**The registry is wider than the event layer.** `object_participants` for `object = 'sport'`,
`objectFK = 46` holds two roles, `athlete` and `team`, each in both active and inactive
states. Measured 2026-08-20, the registry knows about four thousand more athletes than any
event participation reaches. That gap is a population, not a defect, and what it means has
not been established.

**Lineups are the relay's swimmers.** One lineup type is in use, `14 Starter`, its parent
event participant is always a `team`, and its members are always `athlete`. Members carry
their own gender, `male` or `female`, rather than the parent team's - so a mixed relay's
lineup is the only place the sport records which swimmers of which gender made up the team.
No lineup member carries gender `mixed`.

<!-- MANUAL PASTE ZONE: 46 PARTICIPANTS AND LINEUPS — insert approved additions immediately before this marker; do not move or delete it. -->

## Event result types

| result_code | result_typeFK | Value shape | Confirmed meaning | Evidence |
|---|---:|---|---|---|
| `rank` | 100 | A bare integer, one normalized shape and no other | The participant's finishing place in the event's field | `GLOBAL-DISCOVERY-007`, `-026`, 2026-08-20 |
| `duration` | 101 | Two different things: a signed gap `+S.hh` / `-S.hh` / `+M:SS.hh`, and an absolute time `M:SS.hh` / `S.hh` / `H:MM:SS.hh` | Ambiguous by construction - see storage semantics | `GLOBAL-DISCOVERY-007`, `-026`, `-027`, 2026-08-20 |
| `comment` | 104 | Free text, no fixed vocabulary | Qualification, record and non-finish markers, several notations for each | `GLOBAL-DISCOVERY-007`, `-026`, `-027`, 2026-08-20 |
| `medal` | 501 | `gold`, `silver`, `bronze` and nothing else | The medal awarded | `GLOBAL-DISCOVERY-007`, `-026`, 2026-08-20 |
| `duration_full_time` | 557 | `M:SS.hh`, `S.hh` or `H:MM:SS.hh`; no text, no sign | The participant's own total time for the distance | `GLOBAL-DISCOVERY-007`, `-026`, 2026-08-20 |

**Not every event carries every type.** Rank, Duration and Full-time duration each reach
fewer events than the sport holds, and the three counts differ from one another, so a
statement asserting one of them over the whole sport is asserting it over a population that
does not exist. The shortfalls were measured 2026-08-20 and are `DQ_OBSERVATION`s rather than
structure; they are not recorded here.

<!-- MANUAL PASTE ZONE: 46 EVENT RESULTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Incident types

**The sport writes no incidents.** `GLOBAL-DISCOVERY-008` returned zero active rows for the
whole sport. This is `Not used` rather than `Not checked` because the meaning an incident
would carry is demonstrably carried elsewhere: disqualification and non-start are written into
result type `104 Comment` as `Disq.`, `DSQ`, `DSQ*`, `DISQ`, `DQ`, `DNS`, `DNF` and `dns.`.
A check looking for a swimmer's disqualification must read the comment result, not the
incident layer.

<!-- MANUAL PASTE ZONE: 46 INCIDENTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Scope types and data types

**The scope layer is a split-time layer, and only long events have one.** Six container types
are in use: `101 checkpoint1` through `105 checkpoint5`, and `305 final_result`. They appear
on distance and open-water events - 1500m freestyle, 200m backstroke, marathon swims - and on
nothing else. The whole sport holds a low three-figure number of containers, so the layer is
real but marginal.

Two storage layers hang beneath a container:

| Layer | What it holds |
|---|---|
| `event_scope_detail` | One `name` per container, the distance the split was taken at: `1.5KM`, `1200m`, `200m`, `8.3KM`, `Finish` |
| `scope_result` | Per-participant values, data types `1 rank`, `3 comment`, `4 duration`, `296 duration_full_time` |

The `scope_result` data types mirror the event-level result types one for one, including the
same split between a signed gap in `4 duration` and an absolute time in
`296 duration_full_time`. The checkpoint distance labels are free text and are not written to
one convention: `1.5KM`, `1200M` and `1200m` all occur.

<!-- MANUAL PASTE ZONE: 46 SCOPES — insert approved additions immediately before this marker; do not move or delete it. -->

## Properties

Four owner objects carry properties:

| Owner | Type | Names in use |
|---|---|---|
| `event` | `metadata` | `checkpoints`, `checkpoint_details`, `discipline`, `Heat`, `Live`, `medal_related`, `ParticipantType`, `Round`, `Type` |
| `event_participants` | `ref:participant` | `organizationFK`, holding a `participant.id` |
| `participant` | `metadata` | `date_of_birth`, `discipline`, `height`, `IsNationalTeam`, `status`, `weight` |
| `tournament_stage` | `metadata` | `Live`, `StatusComment` |

**`checkpoints` and `checkpoint_details` are the scope layer's index.** `checkpoints` holds a
count and `checkpoint_details` the ordered distance list - `1.5KM, 3.2KM, 4.9KM, 6.6KM, 8.3KM,
Finish` - on exactly the events that carry `event_scope` containers. The same distances are
therefore stored twice, once as a property string on the event and once as
`event_scope_detail` rows beneath it.

**The event's `discipline` property duplicates the `object_discipline` relation.** Both are
written on nearly every event, and they are two independent statements of the same fact.

**`date_of_birth` reaches only part of the athlete registry**, and its earliest value is
`1900-01-02`, which is a placeholder rather than a birth date. Whether the property is
required for this sport has not been decided.

<!-- MANUAL PASTE ZONE: 46 PROPERTIES — insert approved additions immediately before this marker; do not move or delete it. -->

## Generic relations and disciplines

**The sport names its disciplines twice, in two vocabularies, at the same time.** This is the
most consequential structural fact discovered about Swimming, because a Comp.Rank generated
from event results will group by discipline.

| Vocabulary | `discipline.id` range | Spelling | Example |
|---|---|---|---|
| Older | 38-58 | The distance spelled out | `Freestyle 50 metres`, `Medley 4 x 100 metres` |
| Current | 348-374, plus 468, 479, 557, 642 | The distance abbreviated | `Freestyle 50m`, `Medley 4 x 100m` |

The older vocabulary is **not** a closed historical import. Measured 2026-08-20, it is written
from 2004 to 2025, and the relay disciplines hold nearly all of its weight - 307 relay events
against 1898 on the current ids - while its individual disciplines appear in ones and twos.

**The split is per edition of a competition, not per event.** No stage mixes the two relay
vocabularies: a stage tagging its relays `56`, `57` and `58` tags all of them that way, and
across 373, 282 and 386 stages holding each relay, none holds both spellings of it. What a
stage does mix is an old relay beside current individual disciplines, which is why the two
vocabularies appear together at template level and never inside one relay.

Which editions take the older ids is not readable from the database. They are a minority
throughout - between one and ten stages a year against nine to thirty-one - they recur rather
than stop, the most recent being 2025, and they concentrate in a small set of competitions:
`World Junior Championships` most often, then `Swimming World Cup` and `World Championships`
in both courses. That pattern is consistent with certain editions arriving by a different
route, but the route itself is outside the database and nothing here establishes it.

**Three pairs of ids carry the same discipline under one name or two:**

| Pair | Name | How they differ |
|---|---|---|
| 351 and 468 | `Freestyle 800m` | Identical name; 468 occurs in three templates, all male |
| 362 and 479 | `Freestyle 50m` | Identical name; 479 occurs in one template in one year |
| 374 and 557 | `Knockout Sprint 3 km` / `3km Knockout Sprint` | Same discipline, two spellings, different templates, both introduced in 2025 |

**`object_discipline` also holds `disciplineFK = 0`**, which resolves to no `discipline` row.
It is a missing reference rather than a discipline the sport contests.

`object_relation` carries six active source/target combinations, from object types 1, 2, 4 and
83 to types 33, 151, 152 and 153. Type 83 is `statistic`: the relation layer reaches this
sport's statistic rows even though the statistic layer itself was not read.

<!-- MANUAL PASTE ZONE: 46 GENERIC RELATIONS AND DISCIPLINES — insert approved additions immediately before this marker; do not move or delete it. -->

## Statistics

| statistic_typeFK | Owner type | Participant shard | Data shard | Fields/config | Evidence |
|---:|---:|---:|---:|---|---|

**Deliberately unread.** No statistic type, owner level or shard is recorded for this sport,
because the discovery statements that establish them were not run. The area is `Not checked`.
It is not `Not applicable`: `GLOBAL-DISCOVERY-012` and `-013` both reach `object_typeFK = 83`
under this sport, so the layer exists and holds rows today. Nothing here may be inferred from
that; the statements must be run before anything is written.

<!-- MANUAL PASTE ZONE: 46 STATISTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Reference values

**Event statuses.** Four `status_type` / `status_desc` combinations occur: `finished` /
`6 Finished`, `notstarted` / `1 Not started`, `cancelled` / `106 Cancelled` and
`interrupted` / `93 To Finish`.

**Medals.** `gold`, `silver`, `bronze`. No fourth value exists in the sport.

**Result comments.** The `104 Comment` vocabulary is open text and holds well over a hundred
distinct normalized forms. Its structure is worth recording even though its values are not:

- qualification markers, `Q` by far the largest, with `q`, `QA`, `QB`, `QFA`, `QFB`, `QSO`,
  and `R` for the reserve;
- record markers, `WR`, `CR`, `OR`, `NR`, `ER`, `GR`, `AM`, `AS`, `AF`, `OC`, `WJ`, `EJ`,
  `MR`, `WJR`, `MNR`, `CGR`, `AR`, and an `=` prefix meaning the record was equalled;
- non-finish markers, `DNS`, `DNF`, `Disq.`, `WD`, `NC`, `Retired`, `OTL`;
- combinations of the above, joined by `/`, `,`, a space or `-` with no single convention.

**`R` is a qualification status, not a non-finish marker**, and reading it as one is the
mistake the data punishes. It is written only on qualifying rounds - heats, heats summaries,
semi-finals, swim-offs - and never on a Final. Against `Q` in the same events, measured
2026-08-20: on a heats summary, where the ranking is the true overall order, `Q` holds places
one to sixteen and averages 4.9 while `R` holds nine to eighteen and averages exactly 10.0;
on a swim-off `q` averages place 1.0 and `R` averages 1.9. `Q` takes the final, `R` takes the
reserve places behind it. The swimmer swam, so the row correctly carries a rank and a real
time, and a check treating `R` as an absent result reports three and a half thousand correct
rows - which `GLOBAL-DQ-052` did until the marker was measured out of the sport's no-result
list.

Several markers have more than one live spelling - `Disq.`, `DSQ`, `DSQ*`, `DISQ` and `DQ`;
`DNS` and `dns.`; `NC`, `N.C.` and `Nc.`. A statement matching a marker literally will match
one spelling and miss the rest.

<!-- MANUAL PASTE ZONE: 46 REFERENCE VALUES — insert approved additions immediately before this marker; do not move or delete it. -->

## Event and round representation

**The sport contests 24 round types, and their names do not identify them.** Six names are
each carried by two different `round_typeFK` values: `Heats` is 320 and 204, `Final` is 173
and 9, `Semi Finals` is 178 and 2, `Swim-Off` is 223 and 224, `Fastest Heats` is 327 and 328,
`Slowest Heats` is 325 and 326. A statement grouping rounds by name merges pairs the database
keeps apart.

**Some round types are named with a bare number** - 38 is `1`, 89 is also `1`, 98 is `10`, 99
is `11`, 91 is `3`. These are positions rather than phases, and 38 alone reaches five figures
of events, so they cannot be dismissed as noise.

**`round_typeFK = 0` is a gap, not a round.** It resolves to no `round_type` row. Every event
carrying it, measured 2026-08-20, sits in one competition across two gendered stages, which
makes it one import that did not write the round rather than a habit of the sport.

**Event names are written in two competing families.** The same event is named `100m
Freestyle` in one place and `Freestyle 100m` in another, and both families are large; the same
inversion holds for Butterfly, Breaststroke, Backstroke and Medley. Relay names add a third
and fourth form, `Freestyle 4 x 100m` and `4x100m Freestyle Relay`. Round information is
appended to the name in some templates - `Freestyle 100m Final A`, `Freestyle 100m Heats
Summary` - and carried only in `round_typeFK` in others.

**Stage names repeat the template name** for most competitions, so a stage is identified by
its tournament's year rather than by its own name. `Swimming World Cup` is the exception: its
stages are named `Swimming World Cup <year> - <city>`, which is the only place the leg's city
is stored as text.

<!-- MANUAL PASTE ZONE: 46 EVENT AND ROUND REPRESENTATION — insert approved additions immediately before this marker; do not move or delete it. -->

## Confirmed sport-specific storage semantics

**`101 Duration` and `557 Full-time duration` are not two names for one measurement.**
Full-time duration holds the participant's own total time and never anything else - no sign,
no text, three time shapes and nothing more. Duration holds the *gap to the leader*, written
with an explicit sign, for most of its values - and holds an absolute time for a large
minority of them, in the same field, with no marker separating the two. Reading `101` as a
time is wrong for most rows; reading it as a gap is wrong for the rest. Which one a row holds
can only be told from the value's own shape.

Duration also holds values that are neither: negative gaps, a bare integer with no decimal
part, and at least one purely textual token. Each was drilled into on 2026-08-20 and each is
spread across templates and years rather than confined to one import, except the textual token
which is a single row.

**A stage's country is stored directly and is almost always `International`.** Every stage
carries `tournament_stage.countryFK`; the host-country object relation and the city link are
each used by a handful of stages and nothing more, so the stage's actual location is not
reliably recoverable from the reference layer. Age class is carried as an object relation and
resolves to `SENIOR`, `JUNIOR` or `YOUTH`.

<!-- MANUAL PASTE ZONE: 46 STORAGE SEMANTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Open questions

1. **Why do certain editions take the older relay ids?** The question is narrower than it
   first looked: the choice is made per edition and held consistently within it, so it is not
   an error made event by event, and it is still being made in 2025, so it is not a legacy
   import either. What decides it is not visible from inside the database. Until it is
   answered, a Comp.Rank grouping by `disciplineFK` will split one competition's relay across
   two rankings from one edition to the next.
2. **Should 351/468, 362/479 and 374/557 be merged?** Each pair is the same discipline under
   two ids; 374 and 557 are also two spellings of one name.
3. **Is `101 Duration` meant to hold an absolute time at all**, or is every absolute value in
   it a row that belongs in `557`?
4. **What do the comment markers `?` and `R?` mean?** `R` itself is settled - it is the
   reserve, and the Reference values section records the measurement - which makes `R?` read
   plausibly as an uncertain reserve, but that is a reading and not a measurement. Both are
   written mostly in the last two seasons, so whatever produces them is running now.
5. **Is `date_of_birth` required for this sport's athletes**, and is `1900-01-02` a sentinel
   the sport uses deliberately?
6. **What is the registry's surplus of athletes over event participants?** Retired swimmers,
   duplicate people, or imports that never reached an event - not established.
7. **The whole Comp.Rank layer**, unread by design and to be opened once event results are
   corrected.

<!-- MANUAL PASTE ZONE: 46 OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
