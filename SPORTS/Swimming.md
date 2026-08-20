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
`GLOBAL-DISCOVERY-012` and `-013` both reach `object_typeFK = 83` for this sport. Three facts
about it were measured on 2026-08-20 by direct statement rather than by the catalogue - the
type, the owner level and the participant shard - because two participant checks cannot be
hydrated without them. The Statistics section states exactly what that covers and what it
does not.

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

**The registry is wider than the event layer, and the surplus is three populations rather than
one.** `object_participants` for `object = 'sport'`, `objectFK = 46` holds two roles, `athlete`
and `team`, each in both active and inactive states. Measured 2026-08-20, 4383 registered
athletes have never appeared in an event, and the registry's own two fields separate them:

| Registry flag | `status` property | Athletes | What it looks like |
|---|---|---:|---|
| active | `active` | 3739 | profiles the sport carries but has never entered; 2490 of them hold no birth date either |
| inactive | `retired` | 512 | swimmers kept for history whose competitions are not in the data |
| active | none | 123 | the status property is simply absent |
| inactive | `dead` | 6 | consistent with the flag |
| **active** | **`dead`** | **2** | the flag and the property contradict each other |

The first two are populations rather than defects and neither needs correcting. The last row is
a contradiction between two fields that describe the same thing, and it raises a structural
question the sport file cannot answer on its own: whether the registry's `active` flag is meant
to agree with the participant's `status` property at all.

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

**No DQ check reads this layer, by decision of 2026-08-20.** Five `GLOBAL-DQ` templates audit
the scope layer, and all five read it as *periods of a score* - a segment of the contest that
every participant plays and that scores, summing to the total on the result row.
`GLOBAL-DQ-085` sum against total, `086` period value against an approved vocabulary, `089`
extra period against detailed status, `091` period stored for every participant, `092` sentinel
position. Swimming stores none of that: a checkpoint is a distance marker carrying a cumulative
time, `scope_result` holds `1 rank`, `3 comment`, `4 duration` and `296 duration_full_time`
rather than a score, and there is no extra-period container among `101`-`105` and `305`. All
five are `Not applicable`, each with its reason in `SPORTS/params.json` `_checkSignal`.

`GLOBAL-DQ-091` is the one worth naming here, because it is the one that nearly applies. Its
question - is the same checkpoint recorded for every swimmer in the race - is a real question
about a split layer, and it was raised and rejected rather than passed over. What it reads to
ask it is `SCOPE_PERIOD_DATA_TYPE_LIST`, and this sport has no per-period score to put there.
A check that would need a different structure to run is not the same check, so this one is
classified out and the question stays open for whoever wants to ask it of the split layer
directly.

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

**`date_of_birth` reaches only part of the athlete registry.** Measured 2026-08-20, 12811 of
the sport's registered athletes carry no such property at all, which is the real gap; the rest
hold plausible dates, 22402 of them from 1980 onward and 985 between 1930 and 1979. The single
value beginning `1900` is one row and not a placeholder convention - an earlier reading of this
file said otherwise and was wrong. The range's other end is the defect worth naming: the highest
value stored is a date a few months old, and a swimmer born then has not competed.

Both halves are now reported. `Swimming-DQ-061` asks whether the property is there and returns
12811 athletes of 36199; `Swimming-DQ-064` asks whether the value it holds can be true, by
checking it against the date of an event the athlete actually swam, and returns 48. The two
were separated on purpose: an absent birth date and an impossible one are different repairs and
the second cannot be found by looking at the property alone.

**`status` is the registry's second opinion, and one value has no definition.** The property
resolves to `active`, `retired` or `dead`, and `object_participants.active` says the same thing
in one flag. Measured 2026-08-20 they agree on 36073 athletes and disagree on 11, which
`Swimming-DQ-065` reports. Two shapes sit beside that and are deliberately not in it: 123
athletes carry no `status` at all, which is an absence rather than a contradiction; and one
athlete carries `status = unattached`, which is a vocabulary of one. Nothing in the database
says what `unattached` asserts or which value of the flag it should agree with, so it is
recorded here and left unreported rather than guessed at.

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

They are a minority throughout - between one and ten stages a year against nine to thirty-one -
they recur rather than stop, the most recent being 2025, and they concentrate in a small set of
competitions: `World Junior Championships` most often, then `Swimming World Cup` and
`World Championships` in both courses.

**The older ids do not travel alone: they carry their own way of naming the event.** The sport
writes a relay two ways, `Freestyle 4 x 100m` and `4x100m Freestyle Relay`, and measured
2026-08-20 the correspondence is nearly total in one direction:

| Discipline id | Event named `4x100m … Relay` | Event named `Freestyle 4 x 100m` |
|---|---:|---:|
| old, 56/57/58 | **306** | 1 |
| current, 365/366/367 | 88 | 1750 |

The same signature marks two of the duplicate pairs below. All 65 events on `468` and both on
`479` put the distance first in the name, while their higher-volume twins `351` and `362` are
written both ways.

That is a signature rather than a source: nothing in the database names an ingestion path, but
one convention writes a distance-first name together with the older discipline id, and another
writes a distance-last name together with the current one. The events where the two halves
disagree are the interesting residue - one of them was corrected there and the other was not.

`Swimming-DQ-066` measures that residue and carries the `Monitor` signal, because neither
spelling has been declared wrong and driving the count to zero would mean renaming events to a
convention nobody has chosen. Reading distance-first literally, as a name beginning with a
digit, it returns 92 of 2272 relay events: 91 on a current id written distance-first and 1 on an
older id written distance-last. The relay ids are the whole of its scope. `351` and `362` are
excluded although they are the current twins of `468` and `479`, because they are written both
ways and neither spelling is the error there - including them was tried on 2026-08-20 and took
the output to 2438 rows, nearly all of them individual events named the ordinary way.

**A different disagreement runs beside it, and that one is a defect.** The stroke is also named
twice - in the event's name and in the discipline attached to it - and on 64 events the two name
different strokes. Forty-two are a `Backstroke` discipline under an event named `Breaststroke`;
four disagree on the distance as well. `Swimming-DQ-063` reports them and projects both sides,
because nothing in the record says which of the two is the wrong one. It is not
`GLOBAL-DQ-109`: that template compares the discipline id stored on the event property against
the same id in `object_discipline`, and passes an event whose name contradicts both.

**Three pairs of ids carry the same discipline under one name or two:**

| Pair | Name | How they differ |
|---|---|---|
| 351 and 468 | `Freestyle 800m` | Identical name; 468 occurs in three templates, all male, and every one of its events is named distance-first |
| 362 and 479 | `Freestyle 50m` | Identical name; 479 occurs in one template in one year, both events named distance-first |
| 374 and 557 | `Knockout Sprint 3 km` / `3km Knockout Sprint` | Same discipline, two spellings, different templates, both introduced in 2025 |

The first two pairs belong to the naming signature described above and are the same story as the
relays. The third is not: both ids are new in 2025, both name their events the same way, and
they differ only in which templates use them - `374` under `World Championships Long Course` and
`557` under `Marathon Swim World Series` and `Open Water World Championships`. That reads as one
discipline entered into the catalogue twice within a single season.

**`object_discipline` also holds `disciplineFK = 0`**, which resolves to no `discipline` row.
It is a missing reference rather than a discipline the sport contests.

`object_relation` carries six active source/target combinations, from object types 1, 2, 4 and
83 to types 33, 151, 152 and 153. Type 83 is `statistic`: the relation layer reaches this
sport's statistic rows even though the statistic layer itself was not read.

<!-- MANUAL PASTE ZONE: 46 GENERIC RELATIONS AND DISCIPLINES — insert approved additions immediately before this marker; do not move or delete it. -->

## Statistics

| statistic_typeFK | Owner type | Participant shard | Data shard | Fields/config | Evidence |
|---:|---:|---:|---:|---|---|
| 11 Comp.Rank | 3 tournament | `statistic_participants11` | Not checked | Not checked | Measured directly 2026-08-20 for the reach path of `GLOBAL-DQ-007` and `GLOBAL-DQ-009`; 841 records, 7179 people, none of them unreachable by the other three paths |

**Deliberately unread, with one narrow exception.** The discovery statements that establish
this area were not run, so the area stays `Not checked`. It is not `Not applicable`:
`GLOBAL-DISCOVERY-012` and `-013` both reach `object_typeFK = 83` under this sport, so the
layer exists and holds rows today.

The exception is the row in the table above, and it covers three facts and no others. On
2026-08-20 the type, the owner level and the participant shard were measured directly, because
`GLOBAL-DQ-007` and `GLOBAL-DQ-009` reach a person through the Comp.Rank shard as one of four
paths and cannot be hydrated without them: **841** tournament-owned records at
`statistic_typeFK = 11`, holding **7179** people in `statistic_participants11`.

The branch does opposite work in the two checks, and the difference is worth stating because
it was nearly recorded wrong. In `GLOBAL-DQ-007` it only widens the population reached, and it
widens it by nobody: every one of the 7179 is also an event participant, a lineup member or a
sport registrant. In `GLOBAL-DQ-009` it is an *exclusion* path, and there it decides the
answer - **1781** athletes are kept out of the findings solely because a Comp.Rank row reaches
them, so the check reports 976 athletes rather than 2757. Reading the layer as irrelevant to
both would have tripled that check's output against a population that has competed.

The data shard, the config and every field remain unmeasured, and the 841 records are *not*
documented as this sport's Comp.Rank usage: they are the layer that is to be rebuilt from the
corrected event results. Their count is a fact about what exists, never a description of what
it should contain. Nothing further may be inferred from the three facts recorded here; the
discovery statements must be run before anything else is written.

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

**`?` and `R?` are the provisional forms of those two statuses.** They sit on qualifying rounds
only, like the statuses they qualify, and both carry a rank and a real time. On a heats summary
`?` is written at place eight and nowhere else - all 37 of them, on the last place that reaches
the final - so it marks a qualification the record never settled, and the sport's `Swim-Off`
round is where such a place is normally decided. `R?` sits where `R` sits, places nine to
seventeen averaging 10.5 against `R`'s 10.0, so it marks an unsettled reserve.

Both are deliberately left out of the sport's comment vocabulary and are reported by
`Swimming-DQ-039`. Knowing what a marker was written for is not the same as knowing it was
meant to stay: `?` has been written since 2007, and a record that still says the question is
open eighteen years later is unfinished rather than valid.

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

**`101 Duration` holds two different measurements, and the participant's own rank says which.**
The convention was measured on 2026-08-20 and the sport keeps it closely:

| Rank | What `101` holds | Measured |
|---|---|---|
| 1 | the winner's own time, **the identical string** stored in `557` | 41491 participations over 41203 events |
| 2 and below | the gap to the winner, written with an explicit `+` | 373217 participations over 41146 events |

So the field is not ambiguous and a reader is not left to guess from the value's shape: the
rank is the marker, and the sign confirms it. `557 Full-time duration` carries the absolute
time for every place, with no sign and no text, which is what makes it the field to read when
a time is wanted.

The consequence for a check is that `101` may not simply be read as a time or simply as a gap.
An event's leader is expected to hold the same value in both fields, and everyone behind is
expected to hold a signed gap in one and a time in the other.

Four shapes depart from that, all small and each a different repair. A time sits in `101` with
no `557` beside it at all, which is where the time exists in one field only; 96 participations
carry an unsigned value below first place; eight winners carry a signed gap as though they were
behind somebody; and two participations below first place hold a value identical to their
`557`. Each was drilled into on 2026-08-20 and each is spread across templates and years rather
than confined to one import.

**A stage's country is stored directly and is almost always `International`.** Every stage
carries `tournament_stage.countryFK`; the host-country object relation and the city link are
each used by a handful of stages and nothing more, so the stage's actual location is not
reliably recoverable from the reference layer. Age class is carried as an object relation and
resolves to `SENIOR`, `JUNIOR` or `YOUTH`.

<!-- MANUAL PASTE ZONE: 46 STORAGE SEMANTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Open questions

1. **What writes a distance-first event name together with an older discipline id?** The
   question has narrowed twice. The choice is made per edition of a competition and held
   consistently within it, so it is not an error made event by event; it is still being made in
   2025, so it is not a legacy import; and it carries its own naming convention, so it is one
   habit rather than two. What the database cannot say is whose habit it is. Until that is
   answered, a Comp.Rank grouping by `disciplineFK` will split one competition's relay across
   two rankings from one edition to the next. `Swimming-DQ-066` now measures how large that
   split will be; it does not answer the question.
2. **Should `468` and `479` be folded into `351` and `362`, and `374` and `557` into one?**
   The first two belong to question 1 and would be resolved with it. The third is independent:
   one discipline entered twice in 2025, and merging it is a decision about the catalogue rather
   than about this sport.
3. **Are the events holding a distance-first name with a current discipline id a stalled
   correction?** They are the only place the two halves of the signature disagree, which is what
   a half-finished cleanup would look like. There are 91 of them under the literal reading, and
   `Swimming-DQ-066` keeps the count visible so the answer can be read off whether it moves.
4. **Are `?` and `R?` meant to be resolved, or left standing?** What they mark is settled and
   the Reference values section records it. What is not settled is whether a qualification the
   record has left open since 2007 is ever expected to close.
5. ~~**Is `date_of_birth` required for this sport's athletes, and what bounds a plausible one?**~~
   Answered on 2026-08-20 and both halves are now checks. Required: yes, and `Swimming-DQ-061`
   reports the 12811 athletes carrying none. Bounded: not by a birth year, which would report
   real thirteen-year-olds, but by the athlete's age at an event they actually swam.
   `Swimming-DQ-064` cuts below eight and above seventy and returns 48.
6. ~~**Is the registry's `active` flag meant to agree with the participant's `status` property?**~~
   Answered yes on 2026-08-20 and stated as `Swimming-DQ-065`, which returns 11 - nine flagged
   active while retired and two while dead. What the answer did not settle is `unattached`,
   carried by one athlete and defined nowhere; the Properties section records it and no check
   reads it.
7. ~~**Should the sport carry 3739 active athlete profiles that have never entered an event?**~~
   Withdrawn on 2026-08-20: the count was reading a normal shape as a defect. Remeasured, 3865
   active athletes hold no `event_participants` row of their own and **1626 of them are relay
   swimmers reached through a lineup**, which is how this sport enters a relay leg and is not a
   missing participation at all. What remains of the question is already `Swimming-DQ-062`, and
   the 976 athletes it reports are the population that was actually being asked about.
8. **The whole Comp.Rank layer**, unread by design and to be opened once event results are
   corrected.

<!-- MANUAL PASTE ZONE: 46 OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
