# SPORT: Cycling (sport_id=30)

This file is the canonical structural record for Cycling. It contains only confirmed
sport-specific usage, meanings, identifiers, evidence boundaries and open structural
questions. Global database mechanisms belong in `../DATABASE.md`.

For additions, insert approved content immediately before the exact active
`MANUAL PASTE ZONE` marker in the destination subsection. Keep the marker unchanged
and at the end of its subsection. Replace existing rows or paragraphs in place when a
correction is required.

## Identity and evidence

- First discovery date: 2026-08-16
- Latest evidence date: 2026-08-17
- Verification boundary: **40 of the sport's 51 tournament templates**, 418 tournaments, 3528
  stages, 10578 active events and 1270283 event participations, 2001 to 2026. The eleven outside
  it hold no stage, no event and no participation between them, so the boundary removes 317 empty
  tournaments and nothing else. Nothing below is narrowed further unless the paragraph says so.

`sport.name` is `Cycling` and the provider code is `cy`. `SPORTS.md` maps that to the
repository slug `Cycling`.

**The client takes this sport's racing whole, and that is a decision rather than an absence.**
Soccer and Ice Hockey are limited to the national-team competitions because the league and club
calendar that dominates them is outside what UK Sport asked for. Cycling is not: confirmed on
2026-08-16 that professional road racing is in scope alongside the championships.

**Eleven templates are outside it, and every one of them is a shell.** Confirmed by the review
on 2026-08-17 and written into `OUT_OF_SCOPE_TEMPLATE_ID_LIST`:

- **Seven `(IOC)` twins**, `12652` to `12658`, carrying 181 tournaments and **0 stages, 0 events,
  0 participations**. They exist for the IOC historical project and nothing else. They mirror
  their non-IOC counterparts exactly, tournament count for tournament count - 69, 42, 9 and 16 -
  which is what made them look like duplicates before anybody knew what they were.
- **Four pre-2004 World Championship shells**, `10350` and `10352 World Championship RR` and
  `10351` and `10353 World Championship TT`, carrying 136 tournaments named `1927` through `2002`
  and, again, no stage and no event. The client's window is 2004 to 2025, so these editions were
  never going to be filled here.

**The template boundary removes 317 empty tournaments and not one event.** That is why it
changed nothing below the tournament: measured 2026-08-17,
`Cycling-DQ-004 TOURNAMENT_NO_STAGES` fell from 142 findings of 554 tournaments to 6 of 418,
`Cycling-DQ-020 TEMPLATE_NO_TOURNAMENTS_OR_STAGES` from 8 of 44 to 4 of 40, and
`Cycling-DQ-058` from 42 of 44 to 38 of 40.

**The client's season boundary is the second half and it does reach an event, though barely.**
From 2026-08-20 the scope also starts at the 2004 season, which takes a further 280 tournaments
off this sport - more than any sport but Soccer - and with them **33 events**. Remeasured
2026-08-21, `Cycling-DQ-004` reads **5 of 412** while `-020` and `-058` are unmoved at 4 of 40
and 38 of 40. The 33 events are why the sentence above says *template* boundary: taken together
the two boundaries no longer leave the event layer untouched, and a check reading an event
returns what it returned before only to within those 33.

**The six that remain are a work list rather than noise, and each one is named.** `2002` under
`484 World Championship 1`, which is a year before the window; `2024` under both
`10680 Summer Paralympics` and `11789 Summer Paralympics`, which will not be filled here because
Para Cycling was not a separate sport when they were entered; `2020` under `11049` and
`11050 Asian Championship` and `2025` under `11086 Oceania Championship`, all three cancelled
editions. The review holds that the five cancelled and Paralympic ones are candidates for
deletion rather than for filling.

That decision is what makes cost the sport's central problem, and the shape of the cost is
specific. **Cycling holds fewer events than Ice Hockey and sixty-five times more
participations**: 10578 events against 9803, but 1270283 participations against 19607, because
a road race enters the whole peloton rather than two sides. Five templates carry 9930 of the
events and 1236222 of the participations:

| Template | id | Gender | Events | Participations |
|---|---:|---|---:|---:|
| `Category 1` | 9481 | male | 3116 | 315156 |
| `Category Pro` | 9432 | male | 2317 | 262975 |
| `World Tour 1` | 483 | male | 2192 | 322072 |
| `World Tour 1 Grand Tour` | 10356 | male | 1446 | 257477 |
| `World Tour 1` | 9764 | female | 859 | 78542 |

The remaining 46 templates hold 648 events and about 34000 participations between them, and
they are the national-team calendar: the World Championships, the continental championships
for Africa, Asia, Pan America, Oceania and Europe, the Summer Olympics, the Commonwealth,
Pan American, European, Asian and South East Asian Games, the Youth Olympics, the European
Youth Olympic Festival, and the Danish national championship.

**Sixteen templates hold no event at all.** Seven are IOC-purpose and the standing
`tt.name NOT LIKE '%(IOC)%'` filter removes them anyway. The other nine do not empty so
cleanly: `10350 World Championship RR` (male) holds **69 tournaments and no events**,
`10352 World Championship RR` (female) 42, `10351` and `10353 World Championship TT` 9 and 16,
and the three `Summer Paralympics` templates one each. The `(IOC)` twins carry the same
tournament counts against the same names, which is what an unread structural question looks
like rather than an answered one. Recorded under Open questions.

## Structural coverage

| Area | Status | Evidence |
|---|---|---|
| Core hierarchy | Confirmed | `GLOBAL-DISCOVERY-002` sport-wide, 51 templates |
| Event participants | Confirmed | `GLOBAL-DISCOVERY-004`, `-032` sport-wide |
| Event results | Confirmed | `GLOBAL-DISCOVERY-007` sport-wide, 6 types, and `-026` over all six |
| Incidents | Confirmed absent | `GLOBAL-DISCOVERY-008` returned nothing |
| Lineups | Confirmed absent | `GLOBAL-DISCOVERY-005` returned nothing |
| Scope layer | Confirmed | `GLOBAL-DISCOVERY-009`, `-010` sport-wide; the type list re-measured over `event_scope` on 2026-08-16 and found to be 193 rather than the 48 first read |
| `object_round` | Confirmed absent | no row of any type points at a Comp.Rank participant: 0 across 181997, measured 2026-08-16 |
| Properties | Confirmed | `GLOBAL-DISCOVERY-011` sport-wide, 33 rows |
| object_relation | Confirmed | `GLOBAL-DISCOVERY-012` sport-wide, 5 pairs |
| object_discipline | Confirmed | `GLOBAL-DISCOVERY-013` sport-wide, one discipline |
| Statistics | Confirmed | `GLOBAL-DISCOVERY-015`, `-016`, `-017`, `-028`, `-030`, `-031` |
| Reference values | Confirmed | `GLOBAL-DISCOVERY-018` sport-wide, 24 round types |
| Other tables | Not checked | |

## Tables and relation paths used

The sport is **Listing (individual and team)** by `DATABASE.md` `DB-SEM-015`: an event enters a
field and ranks it, and the field is normally athletes but is teams in the team time trials.
`GLOBAL-DISCOVERY-032` measured 2026-08-16 over the one discipline:

| Discipline | Stage gender | Participant type | Events | Templates | Years |
|---|---|---|---:|---:|---|
| `628 Road Race` | male | `athlete` | 8450 | 19 | 2001-2026 |
| `628 Road Race` | female | `athlete` | 1002 | 15 | 2003-2026 |
| `628 Road Race` | male | `team` | 136 | 8 | 2004-2026 |
| `628 Road Race` | female | `team` | 29 | 3 | 2004-2025 |
| `628 Road Race` | mixed | `team` | 7 | 2 | 2019-2025 |

**Two tables the sport does not use at all**, which is a structural fact rather than a
shortage of rows: `lineup` and `incident` are both empty for Cycling, measured 2026-08-16.
A road race enters each rider directly on the event, so there is no squad to name, and the
sport records no in-race event the way a match records a goal or a card. Every check reading
either layer is therefore not applicable here, and the two heaviest tables in the database do
not participate in this sport's cost.

<!-- MANUAL PASTE ZONE: 30 TABLES AND RELATIONS — insert approved additions immediately before this marker; do not move or delete it. -->

## Participant and lineup structure

There is no lineup layer. Participation is a direct `event_participants` row, and
`GLOBAL-DISCOVERY-004` measured sport-wide on 2026-08-16:

| Participant type | Gender | Participants | Participations |
|---|---|---:|---:|
| `athlete` | male | 14848 | 1178047 |
| `athlete` | female | 4424 | 88973 |
| `team` | male | 325 | 2659 |
| `team` | female | 95 | 407 |
| `team` | mixed | 38 | 102 |

**A `mixed` team is real in this sport**, unlike Ice Hockey where the value does not occur:
38 teams carry it across 102 participations, and `10054 World Championship 1` is a `mixed`
template with 8 events from 2019. The mixed relay is a contested format here.

The sport registry (`object_participants`) holds 12 role-type-gender combinations sport-wide:
15683 active male athletes and 4269 female, 1651 and 365 inactive, 495 active male teams and
147 female, 87 inactive male teams and 1 female, 38 mixed teams, 96 active male coaches and 1
inactive.

**Coaches are out of scope for this sport, decided 2026-08-16.** The registry holds 97 active
and 1 inactive, and no check written here audits one. The exclusion is recorded in
`SPORTS/params.json` as `REGISTRY_PARTICIPANT_TYPE_LIST`, which names `athlete` and `team`
only; `GLOBAL-DQ-009 PARTICIPANT_NO_PARTICIPATION_ANYWHERE` is the sole template that reads
the list. It is also the type that template could never clear: a coach is entered on no event,
this sport writes no lineup, and no coach appears in a Comp.Rank, so all 98 were reported for
the absence of a path rather than for a defect. Ice Hockey answered the same shape differently
because it has a fourth path - `refereeFK` on 270 events - and Cycling's property list holds
no equivalent.

**One registry row disagrees with the participant it registers**: `Mauro Gianetti` (id 75943)
is registered under the role `athlete` while the participant is typed `coach`. One row, and
the same shape Ice Hockey carries on 150. It is recorded rather than checked, since the type
it names is out of scope.

**Every person in the registry appears exactly once.** Measured 2026-08-16 over what
`GLOBAL-DISCOVERY-033` reads - `op.del = 'no'`, `p.del = 'no'`, type `athlete` - Cycling holds
21968 rows for 21968 people. Soccer and Ice Hockey do not: they hold 1644 and 943 more rows
than people. The measurement is recorded in `GLOBAL_QUERIES/PARTICIPANTS.sql` beside the
statement it affects.

**64 events of 9611 carry an entry row pointing at nobody.** `Cycling-DQ-007` carries
`GLOBAL-DQ-104` and every one of the 64 comes back under the single label
`EVENT_PARTICIPANT_REFERENCE_MISSING` with `offending_types` reading `none`, so this is a broken
reference rather than a participant type the sport does not use. One to five such rows per
event, across the stage races - `Tour de Suisse`, `Tour de Pologne`, `Paris - Nice`,
`Tour de Romandie` - and `Milano-Sanremo`, which holds five.

**2791 registered athletes and teams are reached by no event and no Comp.Rank of this sport,
and that number holds two different findings.** Measured 2026-08-16: **2457 are entered nowhere
in the database at all** - 2175 athletes, 2016 of them carrying a date of birth, and 282 teams -
while **334 race in a neighbouring cycling sport**: 131 in `Para Cycling`, 129 in
`Track Cycling`, 52 in `Mountain Bike`, 16 in two of those and 6 across other combinations. The
second group is a work list, since a registration pointing at the wrong sport is one field to
correct; the first is a question about where complete profiles attached to nothing came from.

`GLOBAL-DQ-009 PARTICIPANT_NO_PARTICIPATION_ANYWHERE` cannot separate them, and correctly so:
it asserts the participation paths **inside the sport that registered the participant**, which
is what makes a rider filed under the wrong sport indistinguishable from a stranded record.
`Cycling-DQ-001` reads the same two paths - the third, the lineup, has nothing to read here -
and says which of the two each row is, naming the neighbouring sport where there is one. The
template is therefore not instantiated for this sport and carries no `_checkSignal` entry: none
of the four signal values describes it, since the structure it reads is present and its answer
is correct as far as it goes.

**41 groups of athletes share a name**, and 39 of them carry conflicting dates of birth, which
is what a namesake looks like rather than a duplicate. Two do not: `Isaiah Thompson` (1818611
with one participation, 1875549 with none, both born 2004-05-11) and `Brayan Vargas` (1347817
with eight, 1825040 with none). An empty record beside a used one, on the same date of birth,
is the shape a duplicate has. No coach shares a name with another.

**One participant is not a person: `Peloton`, id `205191`, typed `athlete` and gendered male.**
It is entered on **575 events across 8 templates between 17 June 2010 and 9 August 2026** and
carries **no rank and no duration on any of its 576 entries** - not an empty value, no result
row at all. Confirmed 2026-08-16 that it is a **live-update mechanism**: the feed enters the
bunch as one row while a race is running. It is out of scope for this project and no check is
written on it, but it counts inside every field size read from `event_participants`, so a
statement that measures a field is measuring one row more than the race held. No equivalent
placeholder exists under `Gruppo`, `Group`, `Gruppetto`, `Bunch` or `Autobus`, which were
checked by name and return nothing.

**23 events of 9612 enter the same competitor twice**, and `Cycling-DQ-017` carries
`GLOBAL-DQ-055` whole. Every one is a plain doubling - two rows where there should be one, and
three events double two competitors each. It is not systematic: `Sergio Pardilla` is doubled in
4 events out of the 469 he entered, `Jose Antonio de Segovia` and `Jonas van Genechten` in 3
each, `Alexey Tsatevich`, `Francisco Javier Vila` and `Yurij Metlushenko` in 2. They sit almost
entirely in `World Tour 1` and `Category Pro`.

Two of the 23 are not riders. `1385084 Race` under `World Championship 1` doubles the team
`Pinarello Q36.5 Pro Cycling Team`, and `3748190 Stage 9` under `World Tour 1 Grand Tour`
doubles `Peloton` - the single time in 575 events that the live-update placeholder is written
twice, and the one row here that carries no result either way.

**One rider of 19735 is entered under the wrong stage gender**, and `Cycling-DQ-051` is
`GLOBAL-DQ-123` with `Peloton` excluded for the same reason as `Cycling-DQ-050`: the placeholder
is stored as a male athlete and enters 54 female stages, so it contradicts a stage gender by
construction and was one of the template's two rows. What remains is `Liontin Setiawan`
(participant `917476`), stored female and entered in 4 male stages, first seen on event
`2684897`.

<!-- MANUAL PASTE ZONE: 30 PARTICIPANTS AND LINEUPS — insert approved additions immediately before this marker; do not move or delete it. -->

## Event result types

| result_code | result_typeFK | Value shape | Confirmed meaning | Evidence |
|---|---:|---|---|---|
| `rank` | 100 | `#`, and `<EMPTY>` on 447 events | The finishing place | `GLOBAL-DISCOVERY-007`, `-026`, 1139827 rows over 9608 events |
| `duration` | 101 | 14 shapes, chiefly `+#:#` and `#:#:#` | The rider's time: absolute for the winner, a gap for everybody else | `-007`, `-026`, 1139754 rows over 9605 events |
| `comment` | 104 | 13 vocabulary values | Why a rider holds no time | `-007`, `-026`, 114381 rows over 7520 events |
| `medal` | 501 | `gold`, `silver`, `bronze` | The medal awarded | `-007`, `-026`, 1777 rows over 592 events |
| `points` | 102 | `#` | Not read further | `-007`, `-026`, 31 rows over 12 events |
| `laps_behind` | 222 | `#` | Not read further | `-007`, 31 rows over 12 events |

**`102 Points` and `222 Laps behind` cover the same 12 events and the same 31 rows.** Whether
that is one format written twice or two fields that happen to coincide is not settled, and is
recorded under Open questions.

**The comment vocabulary is where the sport records a rider who did not finish**, and it holds
three spellings of one idea. Measured 2026-08-16 by `GLOBAL-DISCOVERY-026`:

| Value | Rows | Events | Reading |
|---|---:|---:|---|
| `DNF` | 101136 | 6254 | did not finish |
| `DNS` | 8363 | 4015 | did not start |
| `HD` | 3111 | 585 | outside the time limit (hors delai) |
| `Disqualified` | 1400 | 686 | disqualified, spelled as a word |
| `DSQ` | 146 | 107 | disqualified, spelled as a code |
| `OTL` | 137 | 36 | over the time limit |
| `+# lap` | 40 | 1 | a lap down |
| `a` | 19 | 1 | unread |
| `FF#` | 16 | 3 | unread |
| `DQ` | 5 | 1 | disqualified, a third spelling |
| `FTM` | 5 | 5 | unread |
| `HUD` | 2 | 2 | unread |
| `OOT` | 1 | 1 | unread |

**Disqualification is not written three ways, and the first reading of this table was wrong.**
It was recorded here as three spellings of one idea - `Disqualified` 1400, `DSQ` 146, `DQ` 5 -
and the data does not support that. Measured on 2026-08-16 against the Rank and Duration each
row also holds:

| Value | Rows | Also holding a Rank | Also holding a time | Rank range |
|---|---:|---:|---:|---|
| `DNF` | 101190 | 103 | 76 | 10-171 |
| `DNS` | 8364 | 20 | 24 | 10-161 |
| `HD` | 3111 | 47 | 48 | 109-185 |
| **`Disqualified`** | **1400** | **1247** | **1253** | **1-196** |
| `DSQ` | 146 | 3 | 3 | 142 |
| `OTL` | 137 | 2 | 2 | 64-65 |
| `+1 lap` | 40 | 40 | 0 | 100-106 |
| `a` | 19 | 19 | 19 | 10-20 |
| `FF1` to `FF14` | 16 | 16 | 7 | each equals its own number |
| `FTM` | 5 | 0 | 0 | - |
| `DQ` | 5 | 0 | 0 | - |
| `HUD` | 2 | 0 | 0 | - |
| `OOT` | 1 | 0 | 0 | - |

`DSQ` and `DQ` behave like a disqualification and almost never keep a place. **`Disqualified` is
the opposite: 1247 of its 1400 rows keep their finishing place, 1253 keep a time, one holds a
medal, and the places run from 1 to 196.** Either the word is being used for something else, or
1247 riders are marked disqualified while still classified. `Cycling-DQ-077` reports them.

**`FF#` means Photo Finish, and the number is the place the photograph decided.** Answered by the
review on 2026-08-17, and it **corrects what this file said until then**: the agreement between
`FF2` and place 2 was read here as the rank echoed into the wrong column, which is exactly
backwards. It is a code, the number is part of it, and the agreement is the point rather than the
symptom. Measured over both layers: `FF1` to `FF14`, 16 riders on the event layer and 15 on the
ranking layer, **every one on the place its own number names and not one without a place**;
`FF1`, `FF2` and `FF3` also hold a medal, which a mis-typed rank never would.

**The number is unbounded because it is a rank** - the review's own example is that `FF1` and
`FF2000` are the same code on different places - so the vocabulary declares `ff1` through `ff250`,
the ceiling `RANK_MAX_PLAUSIBLE` already sets for a plausible place in this sport. A photo finish
recorded past 250 would be reported, and so would a rank past 250, which is the same boundary
read twice rather than a new one.

**`FF#` is approved vocabulary and is deliberately not a no-result value.** Its holders keep the
place, the time and in three cases the medal.

**`a` is an error, and the review says to keep reporting it.** It sits in **one event of the
sport's 10578**: `Driedaagse De Panne-Koksijde` 2018, the women's race of 22 March 2018, event
`2681702`, a field of 20. The winner holds `3:52:23` and no comment; **all nineteen behind her
hold `+0:00` and `a`** - the whole bunch on the winner's time, annotated once and never again
anywhere in the sport. It stays out of the vocabulary so `Cycling-DQ-077` keeps naming it.

**`+1 lap` is consistent**: 40 rows, every one with a place between 100 and 106 and no time,
which is exactly what a lap down looks like.

Being outside the time limit is written five ways, not two. `HD` 3111 rows and `OTL` 137 were
known; `FTM`, `HUD` and `OOT` were confirmed as the same thing by the review on 2026-08-17,
each read off the published result. All five are in the no-result list.

The counts here differ slightly from the first census of the same column - `DNF` was 101136 and
is now 101190 - because colleagues are correcting the data while we read it.

**The five unread values were read on the row on 2026-08-16** and each is confined:

- `a` is nineteen riders in one event, `Race` under `Driedaagse De Panne-Koksijde` 2018,
  template `9764 World Tour 1` (female). The whole group carries the single letter.
- `FF#` runs `FF1` to `FF14` across three events - Tour de France 2012 stage 7, World
  Championship TT 2024, African Championships 2005 - and the numbers run consecutively inside
  each event rather than across them.
- `FTM` is one rider in each of five `Giro d'Italia` stages: 2012, 2013, 2014, 2015 and 2019.
  It occurs in no other tournament.
- `HUD` is two riders, African Championships 2025 and Santos Tour Down Under WE 2026.
- `OOT` is one rider, Tour of Qinghai Lake 2025 stage 2.

**The leader/gap convention holds, and the forty events that break it break it three ways.**
`101 Duration` writes the winner's absolute time and everybody else's gap behind it with a
leading `+`, and `Cycling-DQ-013` carries `GLOBAL-DQ-019` unchanged to report where that fails.
Run 2026-08-16: **40 events of 9606**, spread over 2004 to 2026 with eight of them from 2023
onwards, so this is not a legacy tail that stopped being written.

| Shape | Events | What stands in the row |
|---|---:|---|
| `RANK1_HAS_PLUS` | 20 | The winner stored as a gap |
| `NON_RANK1_MISSING_PLUS` | 17 | A rider behind the winner carrying a bare time - `0:06`, `0:51`, `10:23`, `12:06` |
| `NON_RANK1_WRONG_FORMAT` | 3 | A space after the plus: `+ 0:52`, `+ 0:02`, `+ 0:00` |

The twenty winners divide again, and the three groups need different corrections. Fourteen hold
`+0:00`, where the gap is right and the winner's time is simply absent. Four hold a real gap -
`+0:26`, `+0:56`, `+1:00`, `+1:14` - so either the rank is wrong or the time belongs to somebody
else. Two, both 2026, hold a full race duration with a stray plus in front of it: `+3:56:55` and
`+4:35:17`.

**None of the three shapes is a convention of the sport, and that was measured rather than
assumed.** A house style would show in thousands of events; the space after the plus appears in
3 of 9606 and `+0:00` on a winner in 14.

<!-- MANUAL PASTE ZONE: 30 EVENT RESULTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Incident types

**The sport records no incident at all.** `GLOBAL-DISCOVERY-008` returned nothing sport-wide
on 2026-08-16. This is structural rather than empty: a road race has no discrete in-race event
of the kind `incident` is built for, and nothing in the sport writes one.

<!-- MANUAL PASTE ZONE: 30 INCIDENTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Scope types and data types

**The scope layer is a chain of checkpoints along the course, and it is unlike any other sport
opened so far.** `GLOBAL-DISCOVERY-009` measured 2026-08-16: scope types `101 checkpoint1`
through at least `148 checkpoint48`, each its own container, one per event. Reach falls along
the chain - `checkpoint1` on 1095 events, `checkpoint10` on 572, `checkpoint30` on 551,
`checkpoint48` on 385 - because a longer race carries more checkpoints than a short one.

Under them `event_scope_detail` carries the course rather than a score:

| Detail name | Sample value | What it holds |
|---|---|---|
| `distance` | `0.0 km` | how far into the course the checkpoint sits |
| `distance_to_go` | `0` | the complement |
| `distance_type` | `finish_line`, `mountain1` | what kind of point it is |
| `distance_name` | `1` | |
| `altitude` | `10 m` | |
| `Yellow jersey group` | | the group holding the race lead at that point |
| `Green jersey group` | | the points classification |
| `Polka dot jersey group` | | the mountains classification |
| `White jersey group` | | the young-rider classification |

**A scope type `0` exists whose name is empty**, on 95 events, and it carries `distance` and
`distance_type` with the sample values `Finish` and `mountain1`. It is not read further.

**The chain is far longer than the first reading of it, which said checkpoint1 to at least
checkpoint48.** Measured directly over `event_scope` on 2026-08-16, the sport writes **193 scope
types**: `101 checkpoint1` to `200 checkpoint100`, then `205 checkpoint101` to
`296 checkpoint192`, with the ids `201` to `204` unused, plus the unnamed `0`. Reach falls the
whole way down - `checkpoint1` on 1095 events, `checkpoint48` on 385, `checkpoint100` on 18,
`checkpoint192` on 1 - because a longer race carries more points. `SCOPE_TYPE_LIST` names the
192 checkpoints and leaves `0` out, since it names nothing.

The same measurement puts scope type `0` on **1 event** rather than the 95 recorded above. The
two counts come from different statements and are **retired rather than reconciled**: the review
confirmed on 2026-08-17 that the client does not need the scope layer for this sport at present,
so neither figure is worth the measurement it would take to settle. The figure the parameter
rests on is the type list, which both agree about, and it stands ready for the day the layer is
wanted.

**`Cycling-DQ-091` and `Cycling-DQ-096` are `Out of client scope` since 2026-08-17, and that is
the client's boundary rather than a judgement about the data.** `-091` carries `GLOBAL-DQ-102`,
asserts that a scope result points at a participant of its own event, and reports **0 of 1067**,
so the layer is referentially sound. `-096` reads the checkpoint chain and holds **104 findings
of 1094** - unreadable distances, remaining distances, finish markers and jersey groups - which
is a real work list held rather than dropped. Both come back with nothing to rebuild the day the
layer is wanted; the structure is documented and the checks are written.

**`GLOBAL-DQ-107` is `Not applicable`**, and for a narrower reason than the period checks beside
it: it asserts that a finished event carries a scope *container*, one row standing for the whole
race, and no such type exists here. A checkpoint is a point along the course, not a wrapper
around it.

<!-- MANUAL PASTE ZONE: 30 SCOPES — insert approved additions immediately before this marker; do not move or delete it. -->

## Properties

`GLOBAL-DISCOVERY-011` measured 33 property rows sport-wide on 2026-08-16, all of type
`metadata`, across three owners.

On the event, 16 names:

| Name | Rows | Sample |
|---|---:|---|
| `Live` | 10578 | `no` |
| `Round` | 10519 | `1` |
| `Kilometers` | 9002 | `0.7` |
| `StartName` | 8997 | `'s-Hertogenbosch` |
| `EndName` | 8997 | `'s-Heerenhoek` |
| `RaceType` | 7897 | `normal` |
| `ParticipantType` | 7739 | `athlete` |
| `StageType` | 7279 | `flat` |
| `Number` | 2050 | `0` |
| `Verified` | 798 | `yes` |
| `medal_related` | 577 | `yes` |
| `track_condition` | 434 | `Dry` |
| `weather` | 434 | `Cloudy` |
| `TopResults` | 117 | `10` |
| `discipline` | 106 | `Road Cycling` |
| `StartTimeToBeDecided` | 56 | `no` |

On the participant, 9 names: `date_of_birth` 18731, `height` 1962, `weight` 1935,
`status` 19272, `IsNationalTeam` 265, `tdf_stage_wins` 140, `bicycles` 68, `HomePage` 65,
`founded` 60, `professional_status` 3.

On the tournament stage, 3: `Live` 3500, `StatusComment` 256 (sample `Cancelled`), `Venue` 33.

**The `discipline` event property is present on 106 events and is the legacy path.**
`DATABASE.md` `DB-SEM-019` records that discipline lives in `object_discipline` and that the
property is superseded; `object_discipline` reaches 10566 events here against the property's
106. The decision taken for Ice Hockey on 2026-08-15 - that no statement reads the property -
applies for the same reason, and is not re-opened by the property existing here.

**`StartName` and `EndName` are the sport's own geography** and reach 8997 events each, which
is a layer no other opened sport carries. Neither is read further yet.

<!-- MANUAL PASTE ZONE: 30 PROPERTIES — insert approved additions immediately before this marker; do not move or delete it. -->

## Generic relations and disciplines

**One discipline, `628 Road Race`**, on 10566 of 10578 events and on 1791 of 2018 statistics,
measured 2026-08-16. Twelve events carry no discipline relation.

`object_relation` holds five source-target pairs sport-wide: `4 -> 151` on 3524 rows (the
stage to its age class, 3 distinct classes), `83 -> 33` on 1791 (the statistic to its
discipline, 44 distinct), `83 -> 151` on 1792 (the statistic to its age class, 2 distinct),
`2 -> 152` on 2 and `1 -> 153` on 1.

Stage reference storage (`GLOBAL-DISCOVERY-014`) shows the country written directly as
`11 International` with the age class `1 SENIOR` on the championship stages read.

<!-- MANUAL PASTE ZONE: 30 GENERIC RELATIONS AND DISCIPLINES — insert approved additions immediately before this marker; do not move or delete it. -->

## Statistics

| statistic_typeFK | Owner type | Participant shard | Data shard | Fields/config | Evidence |
|---:|---:|---:|---:|---|---|
| 11 | 3 (tournament) | `statistic_participants11` | `statistic_data11` | `1270` Rank, `1272` Duration, `1273` Comment, `1277` Medal, `1426` Time, `1427` Time Difference; config `1463` Start date, `1464` End date, `1470` Gender, `1471` Event id, `1472` Standing id | `GLOBAL-DISCOVERY-015`, `-016`, `-017`, `-030` |

`statistic_typeFK = 11` is **Comp.Rank** in this project. 2018 statistics own the type at
`object_typeFK = 3`, and `GLOBAL-DISCOVERY-015` returned that one pair and no other, so the
owner level was not chosen from alternatives.

Data fields measured 2026-08-16: `1270 Rank` 184694 values over 1959 statistics,
`1426 Time` 85959 over 776, `1427 Time Difference` 70676 over 1070, `1273 Comment` 30712 over
737, `1272 Duration` 2592 over 113, `1277 Medal` 2063 over 688.

**`1429 Team` is declared and never written**, which separates this sport from Ice Hockey where
the same field carries the rider's side on 43708 rows. `GLOBAL-DISCOVERY-031` confirms it holds
zero values here, along with `1271 Points`, `1274 Laps Behind`, `1275 Order`, `1276 Pair`,
`1278 Qualification rank`, `1390 Distance`, `1403 Penalties` and `1428 Wind`.

**The two time fields each hold both an absolute time and a gap**, and the difference is the
leading `+`. `GLOBAL-DISCOVERY-028` measured 2026-08-16:

| Field | Shape | Values | Statistics |
|---|---|---:|---:|
| `1426 Time` | `+#:#` | 66665 | 748 |
| `1426 Time` | `+#:#:#` | 15102 | 401 |
| `1426 Time` | `#:#:#` | 3960 | 770 |
| `1426 Time` | `+#h #:#` | 140 | 1 |
| `1426 Time` | `#:#` | 54 | 5 |
| `1426 Time` | `<EMPTY>` | 33 | 1 |
| `1427 Time Difference` | `+#:#` | 64264 | 950 |
| `1427 Time Difference` | `<EMPTY>` | 2790 | 46 |
| `1427 Time Difference` | `+#:#.#` | 2402 | 93 |
| `1427 Time Difference` | `#:#:#` | 693 | 693 |

**`+#h #:#` writes the hour as a letter**, and it occurs in exactly one statistic:
`Tour de France Male - Competition Rank`, 140 riders, values from `+1h 02:43` to `+3h 24:16`.
It is the same quantity as `+#:#:#` in a different notation, and it appears where the gap runs
into hours, which on a Grand Tour is the back of the field.

**`1427 Time Difference` is empty on 2790 riders across 46 statistics**, including
`Summer Olympics Mens Road Race Stage`, `World Championship RR Race` (79 and 33 riders) and
`Paris-Tours`. This is the largest empty population read so far and is the one that does not
look like a notation.

**59 Comp.Rank records of 1795 hold no participant at all, and 52 of them are two seasons.**
`Cycling-DQ-008` carries `GLOBAL-DQ-010`. The split by tournament year is 28 in 2020, 24 in
2025, and 7 across 2004, 2007, 2015 and 2018 together. All of them sit in the professional
templates - `Category 1` 24, `Category Pro` 21, `World Tour 1` 13, `World Tour 1 Grand Tour` 1.

The obvious reading was tested and is wrong: these are not rankings created for races that were
then cancelled. **Every one of the 59 tournaments raced** - each holds finished events, measured
2026-08-16 - so the results exist at event level and the tournament ranking beside them was left
empty. Two bad seasons in the Comp.Rank layer rather than a defect scattered through the sport,
and 2020 being one of them is not the pandemic cancelling the racing, because the racing
happened.

**77 Final events of 599 are reached by no Comp.Rank**, and `Cycling-DQ-006` carries
`GLOBAL-DQ-040`, which labels the three things that number holds: 64
`FINAL_EVENT_NOT_IN_ANY_COMP_RANK` where the tournament ranks but not that final, 11
`TOURNAMENT_HAS_NO_COMP_RANK`, and 2 `COMP.RANK_EVENT_SCOPE_UNDETERMINABLE`. They sit in four
templates - `World Championship 1` holds 52, `African Championship` 20, `Asian Championship` 4
and the `European Youth Olympic Festival` 1. Among the eleven is the 2026 World Championship
road race and mixed relay, which is a race still ahead of us rather than a link anybody failed
to make, so part of this check falls on its own as the season runs.

**`1277 Medal` holds one medal too many in three statistics**: `gold` on 689 values over 688
statistics and `silver` on 689 over 687, against `bronze` on 685 over 685.

**29 Comp.Rank records of 1736 rank a rider who never rode in their tournament**, and
`Cycling-DQ-014` carries `GLOBAL-DQ-030`. Run 2026-08-16, 150 seconds. The 29 are two separate
problems and the row's `stray_participants` count is what tells them apart.

**Two of them are one broken link rather than 325 broken riders.** The
`Omloop Het Nieuwsblad Male - Competition Rank` statistics for 2014 and 2015 hang under the
`Category Pro` season container, and every rider they rank rode that race in the `World Tour 1`
container instead. The match is exact and was measured rather than inferred: all 170 of
statistic `338870` rode tournament `27869` `2014`, stage `Omloop Het Nieuwsblad`, 1 March 2014,
and all 155 of statistic `338912` rode tournament `27870` `2015`, stage `Omloop Het Nieuwsblad`,
28 February 2015. The statistic is attached to the wrong tournament, and the correction is one
foreign key each.

The other 27 hold between 1 and 22 strays, 15 of them exactly one, across `World Tour 1` 17,
`Category Pro` 6, `World Tour 1 Grand Tour` 5 and `Pan American Championship` 1.

**The duplicate-person reading was tested and does not explain them.** Ten stray names were
looked up in `participant`: `Benjamin King`, `Victor Grange`, `Amanda Spratt`,
`Anna van der Breggen`, `Chantal Blaak`, `Christine Majerus` and `Alexis Ryan` each hold exactly
one id in the whole database, so the rider is not a second record of somebody already in the
tournament. `Jose Gutierrez` holds 16 ids and `Francisco Perez` 7, which is a common name across
every sport rather than evidence of a split record.

**One route to a false positive exists here and cannot be closed, which is why it is written
down.** The template looks for the rider either directly on an event or through a team's active
lineup, and this sport writes no lineup at all, so only the direct path is live. Most of these
tournaments do enter teams - between 16 and 67 team entries each, the team time trials - so a
rider ranked individually who entered the tournament only inside a team squad would be reported
here and there is nothing in the database to check the squad against. It does not cover the
findings: `Tour de France` 2007 and `Pan American Championship` 2006 hold **no team entry at
all** and still report a stray, and the two large ones are proven misattachments.

**A Comp.Rank keeps its ranks inside its own field, and that was measured before any check was
written on it.** Across all 1736 tournament-owned Comp.Rank records, measured 2026-08-16:

| Highest rank against the number ranked | Statistics |
|---|---:|
| Fits the field | 1638 |
| Up to 5 above | 90 |
| Up to twice the field | 3 |
| More than twice the field | 5 |

94% hold, so a rank above the field size is an exception in this sport rather than a way of
listing a partial field, and `Cycling-DQ-015` carries `GLOBAL-DQ-031` on that basis. It reports
**27 ranked riders in 8 statistics**, run 2026-08-16.

The eight divide into three shapes, read on the row rather than counted:

- **One is unarguable.** `Asian Championships Race Male` 2017 (statistic `338703`) holds rank
  `1005` in a field of 62, and the same statistic also holds a rank of `0` at the other end.
- **Two are the same broken import that `Cycling-DQ-014` reports from the other side.**
  `Tirreno-Adriatico` 2015 (`343473`) ranks 1 to 20 contiguously and then 49, 50, 72, 86, 111,
  131, 142, 144, and 22 of its riders never rode that tournament. `Paris - Nice` 2015 (`343472`)
  ranks 1 to 20 and then a lone 66, with 14 strays. One correction each clears both checks.
- **Five are a tail sitting above a contiguous block** - `Gent - Wevelgem` 2005 ranks 1 to 23
  then 39 and 69, and the two `Santos Tour Down Under WE`, `Post Danmark Rundt` and
  `Pan American Games WE Race Female` records hold the same shape more mildly.

**21 Comp.Rank records of 522 configure a date range that does not contain the racing they
list**, and `Cycling-DQ-019` carries `GLOBAL-DQ-025`. Every one of them sits in a national-team
template, and two of the shapes repeat rather than scatter.

**`European Games` has the month wrong four times over, in the same place each time.** The
configured range keeps the correct day of the month and moves it to January:

| Statistic | Configured | The race |
|---|---|---|
| `European Games Race Male` 2015 | 21.01.2015 | 21.06.2015 |
| `European Games Time Trial Male` 2015 | 21.01.2015 | 18.06.2015 |
| `European Games Race Male` 2019 | 23.01.2019 | 23.06.2019 |
| `European Games Time Trial Male` 2019 | 23.01.2019 | 25.06.2019 |

**`Asian Championships WE Time Trial Female` is two days out, every year.** The same statistic
name reports for 2016, 2017, 2018, 2019 and 2022, each time configured for a single day with
the race two days earlier, and 2012 and 2015 hold the same fault at a larger distance. Seven of
the 21 are one recurring mistake in one annual statistic.

The remaining ten are single: `African Championship` 2012, 2015 and 2016, `South East Asian
Games` 2015, 2019 and 2022, `Asian Games` 2018, `Pan American Championship` 2005 and two more.
Nothing here reads as a convention - a configured range that begins before the earliest race or
ends after the latest is allowed by the template and is not what these rows hold.

**Rank `0` exists in this layer**, in statistic `338703` beside the 1005. `GLOBAL-DQ-031` does
not read it because zero is below the field size rather than above it; `Cycling-DQ-021` carries
`GLOBAL-DQ-012`, which is the template that reads an invalid rank, and reports **4 statistics of
1736**: `European Youth Olympic Festival Race Female` 2025 and three from the `World Tour 1`
2012 season - `Vattenfall Cyclassics`, `Milano-Sanremo` and `E3 Harelbeke`, the last with two
records.

**Six further Comp.Rank checks were read together on 2026-08-16 and each holds a small, legible
population.** None needed a sport variant and none is a convention of the sport:

| Check | Carries | Findings | What the rows hold |
|---|---|---:|---|
| `Cycling-DQ-024` | `GLOBAL-DQ-024` COMP.RANK_SETTINGS_DATE_RANGE_MISMATCH_STAGE | 8 / 1795 | **seven are one annual statistic**: `African Championships WE Team Time Trial Female` in 2013, 2015, 2016, 2017, 2018, 2019 and 2021, configured one to three days off its own stages every year |
| `Cycling-DQ-025` | `GLOBAL-DQ-028` COMP.RANK_RESULTS_TIME_DIFFERENCE_FORMAT | 1 / 957 | `African Championships Time Trial Male` 2024, rank 8 holding `4:29` with the `+` missing |
| `Cycling-DQ-026` | `GLOBAL-DQ-044` COMP.RANK_RESULTS_GENDER_MISMATCH | 2 / 1721 | both are a male statistic holding an entirely female field - `Omloop Het Nieuwsblad Male` 2015 with 155 women and no men, and `Zueri Metzgete Male` 2008 with 47 |
| `Cycling-DQ-027` | `GLOBAL-DQ-072` COMP.RANK_RESULTS_MEDAL_RANK_MISMATCH | 3 / 1395 | silver on rank 3 twice and gold on rank 2 once, at the `European Championship TT` 2017 and the `African Championships` 2018 and 2021 |
| `Cycling-DQ-028` | `GLOBAL-DQ-103` COMP.RANK_PARTICIPANT_DUPLICATE | 1 / 1736 | `Pan American Championships Race Male` 2017, one rider with two rows |
| `Cycling-DQ-029` | `GLOBAL-DQ-115` COMP.RANK_PARTICIPANT_REFERENCE_INVALID | 1 / 181997 | `Gennady Mikhaylov` is soft-deleted and still holds 2 live data rows in `Tour of Flanders` 2007 |

**Statistic `338912` is now reported by four separate checks, and it is one broken link.**
`Omloop Het Nieuwsblad Male - Competition Rank` 2015 hangs under the wrong tournament, and that
single fault surfaces as 155 riders who never rode there (`Cycling-DQ-014`), a rank running to
144 in a field of 28 (`Cycling-DQ-015`), and a male statistic whose whole field is female
(`Cycling-DQ-026`). Its 2014 twin `338870` behaves the same way. Repointing each at its
`World Tour 1` tournament clears all of it.

**Five Final events omit a rider from the Comp.Rank covering them, and the sixth thing the
template found was not a rider.** `Cycling-DQ-050` is `GLOBAL-DQ-042` with `Peloton` excluded,
because the live-update placeholder is absent from every Comp.Rank by construction: the template
reported 21 events of which **17 were Peloton and nothing else**, which buried the five that
matter. What remains is entirely Olympic - `Summer Olympics` 2004 missing `Evgeny Vakker` from
both the road race and the time trial and `Jonathan P. McCarty` from the road race, 2008 missing
six riders from one stage and `Ralf Grabsch` from another, and 2020 missing `Yudai Arashiro`.

**The Comp.Rank organization is not filled at all, and `Cycling-DQ-112` is a sentinel because of it.** Measured 2026-08-25 this sport holds 1 736 tournament-owned Comp.Rank records over 181 974 ranked participations and **not one** carries an Organization value on the statistic data type the sport declares for it.

That makes `Cycling-DQ-112 COMP.RANK_PARTICIPANT_ORGANIZATION_COUNTRY_CONTRADICTS_COMPETITOR` return an `eligible_count` of 0. It is the second of the two things a zero can be - a correct scope over a population that is legitimately empty today, not a misdirected one - and the measurement above is what settles which. The check asks whether the organization that is there is the right one; there is none to ask about. `Cycling-DQ-103` is what reports the absence itself.

It is instantiated rather than left off on the ruling of 2026-08-25 that the field is expected to be populated, and the day it is, this is the check that reads what arrives. Four of the twelve documented sports already fill it - Artistic Gymnastics, Triathlon, Golf and Ice Hockey - and those four are exactly the four that carried this check before today.

**`Cycling-DQ-115 COMP.RANK_ATHLETE_RANKING_DISAGREES_WITH_ITS_TEAM_TWIN` audits nothing, and that
is a sentinel rather than a misdirected scope.** Instantiated 2026-08-27 with
`GLOBAL-DQ-143`, it returns `eligible_count = 0`. The reason is measured and not assumed:
of this sport’s 2020 tournament-owned Comp.Rank rankings, **not one** carries `(athletes)`
in its name. That suffix marks a ranking listing the members of a squad, each given the
place their team finished in, and the check compares such a ranking against the team
ranking it was projected from. With no athlete ranking there is no pair to compare.

**It is deliberately not `Not applicable`.** Nothing structural stops this sport from
producing an athlete ranking: the layer, the shard and the Rank data field are all here
and in use. What is absent is rows, and a row count is never the ground for excluding a
check — that would disarm it for the day the first squad ranking arrives, which is the
day it was written for. The zero is the honest reading and the coverage count says so.
<!-- MANUAL PASTE ZONE: 30 STATISTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Reference values

**Statuses**, `GLOBAL-DISCOVERY-003` sport-wide 2026-08-16: `finished` / `6 Finished` on 9608
events, `cancelled` / `106 Cancelled` on 796, `notstarted` / `1 Not started` on 172,
`notstarted` / `5 Postponed` on 1, `interrupted` / `17 Abandoned` on 1. Five combinations, and
796 cancelled events is a population no other opened sport carries at that share.

**967 events carry no participant at all, and 966 of them are races that were never run.**
Measured 2026-08-16: 793 of the 796 `Cancelled`, all 172 `Not started` - which are the 2026
calendar still ahead of us - and the single `Postponed`. A cancelled race has no start list
because it had no start, so none of those rows is correctable, and `Cycling-DQ-002` carries
`GLOBAL-DQ-071` as `Monitor` for that reason. **One row is a defect and the template labels it
separately**, under `NO_PARTICIPANTS_FINISHED_EVENT`: event `1688924`, `Stage 2` of
`Criterium International` 2014 under `Category Pro`, finished on 29 March 2014 with nobody
entered. The three cancelled races that *do* hold participants are the opposite shape - a start
list entered before the race fell - and no check reports them.

**Round types**, `GLOBAL-DISCOVERY-018` sport-wide, 24 of them. Twenty-one are stage numbers
`1` to `21` under ids `38` to `58`, one is `173 Final` on 599 events, and two are neither:

- **`0` carries an empty name** on 53 events across 4 templates and 13 tournaments, 41 of them
  named `Race`.
- **`89` is named `1`** and holds a single event, while `38` is also named `1` and holds 3086.
  `DATABASE.md` `DB-SEM-012` records that one round name exists under two ids; this is that
  case, with one event on the wrong side of it.

**The unspaced hyphen is how this sport spells its calendar, and one text-hygiene rule fires on
it.** A road race is named after the two places it runs between - `Paris-Roubaix`,
`Milano-Sanremo`, `Gent-Wevelgem` - and Dutch and German race names hyphenate inside a word as
well, as `3-daagse van West-Vlaanderen` does twice. Run on 2026-08-16, `GLOBAL-DQ-048` reported
59 stage names of which **58 broke `HYPHEN_WITHOUT_SPACES` and nothing else**, so the rule was
matching the convention and hiding the thirteen rules beside it. `Cycling-DQ-009` keeps those
thirteen and drops the one, and reports **1**: `Gran Premio Citta di Peccioli`, carrying a
trailing space. Ice Hockey reached the same place from the opposite direction, joining two team
names the same way, and `Ice-Hockey-DQ-082` is the same statement over events.

The same rule fires on the Comp.Rank names for the same reason, since a statistic is titled
after the race it ranks: `GLOBAL-DQ-051` reported 43 names, 30 of them for the hyphen alone.
`Cycling-DQ-010` drops that rule and reports **16, every one of them `DOUBLE_SPACE` in the same
place** - immediately before `Male` or `Female`, as in `Amstel Gold Race␣␣Male - Competition
Rank`. One naming template that lost a space, not sixteen separate mistakes.

**The event names keep the rule, and that is a decision rather than an oversight.**
`Cycling-DQ-011` carries `GLOBAL-DQ-049` unchanged, because the sport has only 95 distinct event
names - most events are called `Race`, `Stage 4` or `Prologue` - and the template reports 11 of
them. Seven are the hyphen convention and three are correct diacritics, so ten of the eleven are
right; at that size `violation_types` tells them apart on the row and the rule is not swamping
anything. It is dropped on the stage and Comp.Rank names because there it was 58 of 59 and 30 of
43.

The three diacritic names were checked rather than assumed: `Meisterschaft von Zürich`,
`Züri Metzgete` and `Trofeo Pollença-Port de Andratx` store **valid UTF-8**, one two-byte
character each, and the separate `REPLACEMENT_CHARACTER` and `MOJIBAKE_DOUBLE_ENCODED` rules do
not fire on them. **The one real finding is `HTML_ENTITY`**: `Trofeo Port d&#39;Andratx - Port
d&#39;Pollenca`, where the apostrophe was left as its HTML code.

The rule is dropped for stage and Comp.Rank names. `GLOBAL-DQ-050` still asks whether the same
race is spelled two ways, which is a different question and a real one here - `Cycling-DQ-012`
carries it and reports **9 races each spelled two ways**:

| Minority spelling | Times | Dominant spelling | Times |
|---|---:|---|---:|
| `Milano - Sanremo` | 1 | `Milano-Sanremo` | 25 |
| `Paris - Roubaix Femmes` | 1 | `Paris-Roubaix Femmes` | 6 |
| `Southeast Asian Games` | 2 | `South East Asian Games` | 10 |
| `Gent-Wevelgem` | 4 | `Gent - Wevelgem` | 19 |
| `La Polynormande` | 4 | `La Poly Normande` | 8 |
| `Gent-Wevelgem WE` | 5 | `Gent - Wevelgem WE` | 8 |
| `Paris-Roubaix` | 7 | `Paris - Roubaix` | 19 |
| `Paris-Nice` | 8 | `Paris - Nice` | 15 |
| `Liege-Bastogne-Liege` | 9 | `Liege - Bastogne - Liege` | 17 |

**The sport has no single house style, and that is what makes this check worth keeping.**
`Milano-Sanremo` dominates unspaced while `Paris - Roubaix` and `Gent - Wevelgem` dominate
spaced, so the unspaced hyphen is a convention the sport follows without agreeing on. Dropping
`HYPHEN_WITHOUT_SPACES` from the two format checks above accepts both spellings; this check is
what still reports that one race carries both.

**Name patterns.** The whole tail was read in one statement on 2026-08-16 rather than by
pursuing it value by value, because in road cycling every race carries its own name and the
tail is a list of races rather than a list of forms. `tournament_stage` holds 541 patterns over
3528 stages, 92 of them occurring once; `statistic` holds 305 over 2018, 72 occurring once.
Neither layer holds an untrimmed name, a non-ASCII character, a lower-case opening or a blank.
**Sixteen statistic name patterns hold a double space**, which is the only hygiene breach in
either layer. 55 stage patterns and 2 statistic patterns join words with an unspaced hyphen,
which in this sport is how a course is named - `Polenca - Andratx` spaced, `Paris-Tours` not.

<!-- MANUAL PASTE ZONE: 30 REFERENCE VALUES — insert approved additions immediately before this marker; do not move or delete it. -->

## Event and round representation

**The round number is not the stage number, and the gap is systematic.** Read on 2026-08-16
through `GLOBAL-DISCOVERY-019` over all 24 round types: every numbered round holds a large
majority named for it and a consistent minority named one lower.

| Round type | Name | Events | Most common event name | Next |
|---:|---|---:|---|---|
| 41 | `4` | 1117 | `Stage 4` x921 | `Stage 3` x175 |
| 42 | `5` | 923 | `Stage 5` x753 | `Stage 4` x160 |
| 43 | `6` | 589 | `Stage 6` x472 | `Stage 5` x112 |
| 44 | `7` | 408 | `Stage 7` x329 | `Stage 6` x77 |
| 58 | `21` | 67 | `Stage 21` x61 | `Stage 20` x6 |

The offset is exactly one and runs the length of the chain. What produces it is not confirmed;
it is recorded under Open questions rather than asserted.

**99 stages of 3505 carry dates that do not match the racing inside them**, and `Cycling-DQ-005`
carries `GLOBAL-DQ-004` whole because every shape in them is a wrong date rather than a
convention. Read on 2026-08-16, the 99 fall three ways:

| Shape | Stages | Worst case |
|---|---:|---|
| an event falls outside the stage window | 39 | `World Championship TTT` 2019, stage declared for 20 September, race held on the 23rd |
| the window ends after the last race | 44 | `Tour of Indonesia` 2018, window 25 January to 28 December against racing on 25 to 28 January - 334 days |
| the window starts before the first race | 16 | `Tro-Bro Leon` 2017, window opening 16 April for a race on the 17th |

Two of those are worth naming because they are the same mistake at different sizes. Twenty-nine
of the wide windows overrun by a single day, which on a stage race reads as a calendar rounded
outward - but `Classica Andorra Pirineus` 2024 gives a one-day race a window of 2 June to 2
September, and `Tour of Qinghai Lake` 2019 overruns by 31 days. And the `European Youth Olympic
Festival` repeats a shape of its own: the stage is declared across the whole festival while the
cycling runs on one or two days of it.

**23 stages of 3528 hold no event at all, and the layer cannot say why.** `Cycling-DQ-016`
carries `GLOBAL-DQ-003` as `Monitor`. Every one of the 23 is a named race off the calendar -
`Tour of Hangzhou` 2013, `Giro del Trentino` 2015, `Giro del Piemonte` 2017, `Tour of Japan`
2021, `Trofeo Baracchi` in both 2024 and 2025 - concentrated in `Category 1` 17, `Category Pro`
4, `World Tour 1` 1 and `Summer Paralympics` 1.

**Two of them are races still ahead of us** - `GP Kranj` on 30 August 2026 and
`Gran Premio del Lazio` on 19 September 2026 - so a handful of rows here is what an open season
looks like and the check will never sit at zero for long.

**For the other 21 the database holds nothing that separates a cancelled race from an unimported
one.** `tournament_stage` carries no status column at all, confirmed on 2026-08-16 by asking for
it and being told the column does not exist; status lives on the event, which is precisely what
is missing. `Maryland Cycling Classic` appears for 2020 and for 2021, and that race was called
off in both years, so at least part of this population is a calendar entry for racing that never
happened. The start date is what tells the two halves apart on the row.

**424 finished events hold a broken rank sequence, and none of the three shapes is the sport
behaving normally.** `Cycling-DQ-003` carries `GLOBAL-DQ-119`, which separates them itself:

| Shape | Events | What it reads like |
|---|---:|---|
| `RANK_SEQUENCE_TIE_DOES_NOT_SKIP` | 227 | two riders share a place and the next does not skip - place 72 shared by 2 followed by 73 |
| `RANK_SEQUENCE_GAP` | 191 | a place is missing - place 34 followed by 36, and on the U23 World Championship road race 10 followed by 16 and 16 by 72 |
| `RANK_SEQUENCE_DOES_NOT_START_AT_ONE` | 6 | three are `Stage 1b - B` of `Settimana Internazionale Coppi e Bartali`, starting at 10, 9 and 7, which reads as a split stage continuing the first half's numbering |

Two readings were tested against the data and neither held. The ties are not team time trials
sharing a team place: every one is "shared by 2" deep in a road field, on stages of the Vuelta a
Pais Vasco and the Tour de France. And the gaps are not a disqualified rider's place having been
removed - 130 of the 191 gap events carry a commented rider, which is 68 per cent against a base
rate of 78 per cent across all 9608 finished events, so a gapped event is if anything *less*
likely to hold a comment than an ordinary one.

**Split stages share a round.** `Stage 3b`, `Stage 8a` and `Stage 8b` appear beside their whole
counterparts, which is the sport running two half-stages in one day.

**And the two halves of a split stage share one ranking, which is why one rank check is written
here rather than carried.** At `Settimana Internazionale Coppi e Bartali`, `Stage 1b - A teams`
and `Stage 1b - B teams` hold 25 teams each and between them exactly the places 1 to 50, every
place in one half and in neither the other. Read on 2026-08-16 over all three stages:

| Stage | Half | Places held |
|---:|---|---|
| `838664` | A | 1-9, 11, 12, 14, 15, 17-21, 25, 29, 33, 35, 37, 38, 41 |
| `838664` | B | 10, 13, 16, 22-24, 26-28, 30-32, 34, 36, 39, 40, 42-50 |

So a team placed 41st in a 25-team event is correctly placed, and the field it was placed in is
the other 50. These six events are every event in the sport whose name ends in ` teams`.

`Cycling-DQ-018` is `GLOBAL-DQ-020` with that one shape excluded and everything else carried
unchanged, and reports **16 of 9582** against the template's 22 of 9608, remeasured 2026-08-21. The 16 are two further
things, and the row's `ranks_held` separates them:

- **Twelve are an incomplete import rather than a wrong place.** Nine are `World Championship
  U23` road races and time trials from 2005 to 2009 holding 11 to 22 riders of a field that
  started 150, with their true places - event `346180` stores 15 riders placed 16, 72, 107 and
  115. A reading that they hold one nation only was tested and is wrong: they carry 8 to 14
  nations each. Denmark appears in all nine, which points at the source rather than explaining
  the shape. `346519 Prologue`, `346586 Gent-Wevelgem` and `495050 Stage` hold the same shape.
- **Four are a single place outside its field.** `Eugen Wacker` 1005 in a field of 62, which
  `Cycling-DQ-015` reports from the Comp.Rank side as well; `Klaas Sys` 101 of 100; `Jakob Piil`
  86 of 75; `Tamiko Butler` 32 of 31.

Across the whole sport 134 events of 9608 hold a place above their own field, which is 1.4 per
cent, so the invariant holds here and the exceptions are worth reading one by one.

**No event here is named after the riders in it, and that follows from the competition model
rather than from this sport's habits.** Only a head-to-head sport writes `Team 1 - Team 2`,
because that name is the contest between two entries; a field of 120 riders has nothing to put
in such a name. `GLOBAL-DQ-096 EVENT_NAME_DOES_NOT_NAME_ITS_PARTICIPANTS` therefore does not
apply and is recorded `Not applicable` in `SPORTS/params.json`. Measured 2026-08-16 before the
rule was stated: 9611 of 9611 events, every one naming zero of its 94 to 124 competitors. The
three sports that do instantiate that template - Curling, Ice Hockey and Soccer - are all
`H2H (team)`, and `GLOBAL_DQ/README.md` now carries the rule.

**`173 Final` is the only round that travels**, reaching 599 events across 14 templates and 24
tournaments - `Race` 385, `Time Trial` 199, `Stage` 8. The championships settle on `Final`
while the stage races number their rounds, and rounds `15` to `21` exist in a single template,
`10356 World Tour 1 Grand Tour`.

**Four hierarchy checks were read together on 2026-08-16**, each with a population small enough
to read on the row:

| Check | Carries | Findings | What the rows hold |
|---|---|---:|---|
| `Cycling-DQ-020` | `GLOBAL-DQ-001` TEMPLATE_NO_TOURNAMENTS_OR_STAGES | 8 / 44 | the nine templates already recorded under Identity: five hold tournaments and no stages - `10350` and `10352 World Championship RR`, `10351` and `10353 World Championship TT`, `10680 Summer Paralympics` - and `11051 Asian Championship` and `11053 Asian Games` hold nothing at all |
| `Cycling-DQ-022` | `GLOBAL-DQ-014` TEMPLATE_STAGE_GENDER_MISMATCH | 1 / 3518 | stage `903102 Zueri Metzgete` is female under a male template, and the same race carries a male Comp.Rank holding 47 women under `Cycling-DQ-026` |
| `Cycling-DQ-023` | `GLOBAL-DQ-017` EVENT_RESULTS_MISSING_FOR_FINISHED | 1 / 9610 | `Criterium International` 2014 `Stage 2`, the same event `Cycling-DQ-002` names as its one real defect - finished, nobody entered, so no result either |
| `Cycling-DQ-030` | `GLOBAL-DQ-080` TOURNAMENT_NAME_SEASON_CONTRADICTS_DATES | 4 / 412 | see below - all four are correct today |

**`Cycling-DQ-030` is `Monitor` because every row it holds today is right, and the invariant is
still worth keeping.** Two findings are the professional season container: `Category Pro` names
a tournament for the year it ends in and opens it on **20 October of the year before**, seen on
tournament `8452` named `2013` with stages from 2012, on `8461` named `2014` with stages from
2013, and a third time in the first-event dates of the `Tour of California` and
`Omloop Het Nieuwsblad` statistics. The other two are `Summer Olympics 2020`, whose stages fall
in 2021 because Tokyo was postponed - the name is the right name for those Games. A year
genuinely mistyped would arrive here too, which is what the check is kept for.

**Nineteen further templates were run on 2026-08-16 and returned nothing**, each over a real
population rather than an empty one, and each is instantiated on that basis - a check that
guards an invariant is not disposable for holding no findings on the day it was written:

| Check | Carries | Eligible |
|---|---|---:|
| `Cycling-DQ-031` | `GLOBAL-DQ-018` EVENT_RESULTS_MEDAL_INVALID_VALUE | 1777 |
| `Cycling-DQ-032` | `GLOBAL-DQ-027` COMP.RANK_RESULTS_MEDAL_INVALID_VALUE | 1395 |
| `Cycling-DQ-033` | `GLOBAL-DQ-029` COMP.RANK_RESULTS_DEPRECATED_DURATION_USED | 1795 |
| `Cycling-DQ-034` | `GLOBAL-DQ-043` EVENT_PARTICIPANTS_GENDER_MISMATCH | 1270417 |
| `Cycling-DQ-035` | `GLOBAL-DQ-053` EVENT_RESULTS_MEDAL_RANK_MISMATCH | 1777 |
| `Cycling-DQ-036` | `GLOBAL-DQ-059` EVENT_RESULTS_DUPLICATE_ROWS | 9611 |
| `Cycling-DQ-037` | `GLOBAL-DQ-060` COMP.RANK_RESULTS_DUPLICATE_ROWS | 1736 |
| `Cycling-DQ-038` | `GLOBAL-DQ-075` EVENT_ROUND_TYPE_NOT_IN_EXPECTED_SET | 10527 |
| `Cycling-DQ-039` | `GLOBAL-DQ-078` TOURNAMENT_NAME_FORMAT_INVALID | 93 |
| `Cycling-DQ-040` | `GLOBAL-DQ-079` TEMPLATE_NAME_FORMAT_INVALID | 22 |
| `Cycling-DQ-041` | `GLOBAL-DQ-082` TOURNAMENT_STAGE_EVENT_DISCIPLINE_INCONSISTENT | 3502 |
| `Cycling-DQ-042` | `GLOBAL-DQ-099` COMP.RANK_VALUE_BELONGS_TO_ANOTHER_FIELD | 334779 |
| `Cycling-DQ-043` | `GLOBAL-DQ-100` COMP.RANK_DISCIPLINE_NOT_CONTESTED_IN_TOURNAMENT | 1791 |
| `Cycling-DQ-044` | `GLOBAL-DQ-101` COMP.RANK_SETTINGS_EVENT_ID_INVALID_OR_OUTSIDE_TOURNAMENT | 522 |
| `Cycling-DQ-045` | `GLOBAL-DQ-105` COMP.RANK_SETTINGS_SCALAR_DUPLICATE_ROWS | 1795 |
| `Cycling-DQ-046` | `GLOBAL-DQ-106` COMP.RANK_UNEXPECTED_OWNER_TYPE | 1795 |
| `Cycling-DQ-047` | `GLOBAL-DQ-109` EVENT_SETTINGS_DISCIPLINE_STORAGE_MISMATCH | 64 |
| `Cycling-DQ-048` | `GLOBAL-DQ-110` COMP.RANK_DISCIPLINE_CONTRADICTS_LINKED_EVENT | 522 |
| `Cycling-DQ-049` | `GLOBAL-DQ-113` COMP.RANK_PARTICIPANT_TYPE_MIXED | 1736 |

**Not one of the nineteen has an eligible count of zero**, which was checked rather than assumed:
the smallest is 22 templates and the largest 1.27 million participations, so none of them is a
scope pointing at nothing and none is a sentinel over an empty population.

**The missing-value category was read whole on 2026-08-16**, and sixteen templates are carried
unchanged. Seven hold findings:

| Check | Carries | Findings / eligible | What the rows hold |
|---|---|---|---|
| `Cycling-DQ-052` | `GLOBAL-DQ-002` TOURNAMENT_STAGE_MISSING_AGE_CLASS | 4 / 3528 | `Flandrien 0.0 Classic`, `Tour of Istanbul`, `Tour of Holland`, `Summer Paralympics` |
| `Cycling-DQ-054` | `GLOBAL-DQ-006` EVENT_MISSING_ROUND_TYPE | 51 / 10578 | all of them `round_typeFK = 0`, the unnamed round already recorded above |
| `Cycling-DQ-055` | `GLOBAL-DQ-007` PARTICIPANT_MISSING_DATE_OF_BIRTH | 723 / 21973 | see below |
| `Cycling-DQ-058` | `GLOBAL-DQ-013` TEMPLATE_MISSING_SET_SUBSET_GENDER_NAME | **42 / 44** | one field, not four: `tournament_subset` is empty on almost every template in the sport |
| `Cycling-DQ-059` | `GLOBAL-DQ-015` EVENT_SETTINGS_MISSING_DISCIPLINE | 12 / 10578 | mostly the 2026 season, and the same twelve events the discipline census left uncovered |
| `Cycling-DQ-061` and `-062` | `GLOBAL-DQ-022` and `-023` | 3 and 4 / 1795 | the same three Grand Tour statistics - `Tour de France` 2004 and 2025, `Giro d'Italia` 2025 - plus `Giro del Trentino` 2015 on the discipline |
| `Cycling-DQ-121` | `GLOBAL-DQ-151` PARTICIPANT_MISSING_SPLIT_NAME | 4 / 21995 | `Peloton`, `Warseno`, `Habibullah` and `Fitriyani`, each missing `first_name` - the last three are single-name riders from Indonesia and Pakistan. **These four were read here as `Cycling-DQ-056` until 2026-09-01**, when `GLOBAL-DQ-008` gave up the split-name question and `GLOBAL-DQ-151` took it over a population that reaches a person through the sport registry as well as through participation. The rows did not move because anything was repaired: `-056` now returns 0 of 19724 and `-121` returns these same four of 21995, and the wider eligible count is the registry being read |

Eight return nothing today over real populations and are instantiated on that basis:
`Cycling-DQ-053` (`GLOBAL-DQ-005`, 3528 stages), `-057` (`-011`, 1795), `-060` (`-016`, 10578),
`-063` (`-032`, 1736), `-064` (`-037`, 592), `-065` (`-069`, **1246372 result values**) and
`-066` (`-070`, 181997). The eighth is `Cycling-DQ-056`, carrying
`GLOBAL-DQ-008 PARTICIPANT_MISSING_PROFILE_FIELDS` over 19724 entered riders: it asked about the
split first and last name until 2026-09-01 and returned the four rows now listed against
`Cycling-DQ-121`, and what it still asserts - a name and a country on every rider entered - Cycling
fills throughout.

**723 riders of 21973 carry no date of birth, and the row says which of them matter.**
`Cycling-DQ-055` carries `GLOBAL-DQ-007` whole. At 3.3 per cent this is a gap rather than a
convention, and the template projects the participation counts beside the name, so the list
sorts itself: the largest is `Peloton` with 576 entries, which is the live-update placeholder
and not a person, and the largest real one is `Joshua Giddings` of Great Britain with 141 event
entries and 13 Comp.Rank placings. It was read before being numbered because it is over the
200-row gate.

**95 per cent of events carry no venue, and `Cycling-DQ-067` is `Monitor` for that reason.**
`GLOBAL-DQ-074` reports 10002 of 10546, on the event and on its stage together, remeasured
2026-08-21. This was
deliberately not called a structural absence: **544 events do carry a venue**, so the storage
exists and is used. A road race runs between two towns rather than at a ground, so most of the
population has nothing to record. What the check is kept for is the direction of the number.

**Six templates in this category and beside it are not applicable, each for a structural
reason**, recorded in `SPORTS/params.json` and never on a row count alone:

| Template | Reported | The structure it reads |
|---|---|---|
| `GLOBAL-DQ-033` COMP.RANK_RESULTS_MISSING_PHASE | 1736 / 1736 | a phase is a stage inside a ranking, and a mass-start road race has none. `object_round` holds **no row of any type** pointing at a Comp.Rank participant here - 0 across 181997 |
| `GLOBAL-DQ-083` EVENT_PARTICIPANT_COUNT_NOT_TWO | 9614 / 9614 | wants exactly two entries; this sport enters 92 to 124 riders. The same competition-model rule that settles `GLOBAL-DQ-096` |
| `GLOBAL-DQ-058` EVENT_TEAM_PARTICIPANT_WITHOUT_LINEUP | 172 / 172 | every team time trial in the sport, 21 teams each with no lineup, because the sport writes no lineup |
| `GLOBAL-DQ-067`, `-068`, `-112` | eligible **0** | the same lineup layer, audited from three further angles |

The three with an eligible count of zero are the second of the two things `POWERBI.md` allows
that to be: a correct scope over a population that cannot exist in this sport, not a scope
pointing at the wrong place. `GLOBAL-DQ-058` proves it from the other side by reporting 100 per
cent of a population that does exist.

**A timed sport that stores no full time, and the absence is the finding.** `557 Full time` is
the global result type that holds a competitor's absolute finishing time. Cycling writes **not
one row of it**, measured 2026-08-16 against the two other opened sports that are decided on the
clock:

| Sport | `101 Duration` rows | `557 Full time` rows | Events with a duration | Events with a full time |
|---|---:|---:|---:|---:|
| **Cycling** | **1140133** | **0** | 9609 | **0** |
| Triathlon | 112386 | 112386 | 3603 | 3603 |
| BMX | 61620 | 964 | 8014 | 49 |

Triathlon writes one against every duration it holds. **This costs more here than the count
suggests**, because `101 Duration` follows the leader/gap convention: the winner's absolute time
is stored and everybody else carries only a gap, so the actual finishing time of the fiftieth
rider is written down nowhere at this layer. It can be computed from the winner's time and the
gap; it cannot be read.

`Cycling-DQ-069` carries `GLOBAL-DQ-045` as `Monitor` and reports **9610 events of 9610**, every
one `RANK_PRESENT_DURATION_FULL_TIME_MISSING`. It is instantiated rather than called not
applicable **because a timed sport is expected to hold a full time**, and a check that says so is
what makes the gap visible; the number falls the day the field starts being written.

**The ranking layer holds the same gap half-closed.** `1426 Time` is written on **85926 of the
181997 ranked participants** and reaches **776 of 1795 statistics**, so an absolute time does
survive one layer up, for less than half of the placings. `Cycling-DQ-070` carries
`GLOBAL-DQ-046` as `Monitor` and reports **1734 statistics of 1734**, every one
`RANK_PRESENT_TIME_MISSING`: there is no ranking in which every ranked rider carries a time.
`1427 Time Difference` sits on 67886 across 1070 statistics.

`Cycling-DQ-071` carries `GLOBAL-DQ-054`, which compares one rider's full time with another's and
therefore audits **nothing at all today - `eligible_count` is 0**. That is a sentinel rather than
a misdirected scope, and the distinction is the one `POWERBI.md` owns: the sport is timed and the
storage exists globally, so this population is empty today and will not be once the gap above is
closed. It is numbered now so it is already in place on the day the field is filled.

It carries the `Sentinel` signal since 2026-08-17, and did not before because the vocabulary had
no such word - it was recorded as `Monitor` with a reason beginning "A sentinel". That cost
something real: the run reads the signal to decide which `eligible_count = 0` questions are
already answered, so this one and `Cycling-DQ-087` were raised on the `Decisions` tab of every
run while the answer sat here, where the run could not see it. `TOOLS/README.md` owns the word.

**Medals are awarded by 29 templates and by no other, and that list is what makes the medal-set
check readable.** `Cycling-DQ-068` is `GLOBAL-DQ-026` with two changes. The template counts a
medal over the team holding it where the statistic assigns one, so that a winning relay reads as
one gold rather than four; this sport assigns no team value and fields no relay, so that clause
is dropped. And it is narrowed to the medal templates: unnarrowed it reported **1274 rankings of
which 1271 held no medal at all**, which is `Tour de France` and `Giro d'Italia` behaving
correctly, since a stage race awards none. The five professional templates - `483` and `9764
World Tour 1`, `9432 Category Pro`, `9481 Category 1`, `10356 World Tour 1 Grand Tour` - hold
1187 of the sport's 1795 rankings between them and are outside the list.

**Ten championship and Games templates award no medal at all, and naming them is the point.**
The list holds all 29 rather than the 19 that currently award, because a template is
medal-awarding by what it is and not by what it stores today:

| Template | Gender | Rankings holding no medal |
|---|---|---:|
| `11050` Asian Championship | female | 26 |
| `11056` European Youth Olympic Festival | male | 20 |
| `11057` European Youth Olympic Festival | female | 14 |
| `11052` Asian Games | male | 6 |
| `11058` / `11059` European Games | male / female | 4 / 4 |
| `11055` South East Asian Games | female | 2 |
| `11048` African Championship | mixed | 1 |
| `11101` / `11121` Youth Olympics | male / female | 1 / 1 |

Narrowed, `Cycling-DQ-068` reports **87 of 549**: 84 `No_Medals_At_All` - the 79 above plus five
scattered through templates that otherwise award - and **3 `Duplicate_Medal_Tie_Shape`**, which
are the same three `Cycling-DQ-027` reports and the same excess of one gold and one silver
already recorded under `1277 Medal`.

`Cycling-DQ-072` carries `GLOBAL-DQ-125` and asks the reverse - a medal awarded outside a medal
template - and returns **0 of 1246**, which corroborates the list from the other side.

**Twenty-two templates are not applicable, each on a structure the sport does not store**, and
none on a row count. They are recorded one by one in `SPORTS/params.json`:

| Missing structure | Templates | The evidence |
|---|---|---|
| No score of any kind | `-084` `-085` `-090` `-094` `-108` `-114` `-116` `-117` | the six result types are `100 Rank`, `101 Duration`, `104 Comment`, `501 Medal`, `102 Points`, `222 Laps behind` |
| No winner | `-087` `-088` | none of the 16 event property names is a winner, and a winner names one of two sides |
| No period of play | `-086` `-089` `-091` `-092` | the scope layer is the checkpoint chain: `distance`, `altitude`, `distance_type`, the jersey groups |
| No third-place round | `-093` `-094` | the round types are `0`, `38`-`58`, `89` and `173 Final` |
| No elimination or group round | `-097` `-118` | the same 24 round types |
| No team data value | `-064` `-065` `-066` `-095` `-098` | `1429 Team` is declared and empty here |
| No score to read the Comment against | `-117` | `GLOBAL-DQ-052` audits the Comment instead, against the Rank, the time and the Medal |

**The comment vocabulary is declared as eleven approved values and ten that mean no result.**
`RESULT_COMMENT_VALUE_LIST` holds `dnf`, `dns`, `hd`, `disqualified`, `dsq`, `dq`, `otl`, `ftm`,
`hud`, `oot` and `+1 lap`; `RESULT_COMMENT_NO_RESULT_LIST` holds the same minus `+1 lap`, which
keeps its place by design.

**`FTM`, `HUD` and `OOT` joined both lists on 2026-08-17, when the review read them off the
published results and confirmed all three mean outside the time limit** - the same thing `HD` and
`OTL` already meant. `FTM` on Mareczko Jakub at the 2019 Giro stage 12, `HUD` at the 2026 Santos
Women's Tour stage 1, `OOT` at the 2025 Tour of Qinghai stage 2, each checked against Pro Cycling
Stats. **So the sport writes being outside the time limit five different ways**: `HD` 3111 rows,
`OTL` 137, and a handful each of the three. That is not a defect any check can assert, and it is
recorded here for whoever maintains the vocabulary.

**`ff1` through `ff250` are approved on both layers and are on neither no-result list.** Photo
Finish annotates a place that was decided by the photograph, so its holder has a result by
definition. The ceiling is `RANK_MAX_PLAUSIBLE`, for the reason given in the results section.

**One value is left out deliberately so the check reports it: `a`, on 19 rows in one event.** The
review's verdict of 2026-08-17 is that it is an error, and it stays outside the vocabulary for
that reason rather than because nobody has read it.

The ranking layer writes a narrower set and is declared separately: `DNF` 28951 rows, `HD` 928,
`DNS` 617, `Disqualified` 116, `DSQ` 29 and `HUD` 1 mean no result there, and the `FF` ladder
sits beside them as an annotation on 15 rows. **`Disqualified` holds a rank on 34 of its 116**,
which is the Comp.Rank face of the same defect the event layer shows on 1247.

`Cycling-DQ-077` carries `GLOBAL-DQ-052` and reports **1459 of 114372**, remeasured 2026-08-21:
1421 `COMMENT_NO_RESULT_WITH_RANK` - 1246 `Disqualified` plus 103 `DNF`, 47 `HD`, 20 `DNS`,
3 `DSQ` and 2 `OTL` - 19 `COMMENT_INVALID_VALUE`, 18 with a time and 1 with a medal.
`Cycling-DQ-078` carries `GLOBAL-DQ-057` on the ranking layer and reports **42 of 30656**:
41 with a rank and 1 with a time.

**Eight further templates were unblocked by three parameter decisions** and are carried whole:

| Check | Carries | Findings / eligible | What the rows hold |
|---|---|---|---|
| `Cycling-DQ-073` | `GLOBAL-DQ-021` EVENT_RESULTS_RANK_DUPLICATE_WITHOUT_COMMENT | 38 / 9612 | a shared place whose times disagree. The worst is `Stage 11` of a Grand Tour with **164 riders all on place 2** |
| `Cycling-DQ-074` | `GLOBAL-DQ-038` EVENT_SETTINGS_MISSING_MEDAL_RELATED | 16 / 588 | Olympic road races and time trials carrying no `medal_related` property |
| `Cycling-DQ-075` and `-079` | `GLOBAL-DQ-039` and `-073` | 1 / 9001 each | the same event seen twice: `4119091 Race`, `World Championship RR` 2011, awarding a medal on round type `38` which is stage 1 |
| `Cycling-DQ-076` | `GLOBAL-DQ-041` | 0 / 1395 | |
| `Cycling-DQ-080` | `GLOBAL-DQ-076` | 0 / 9589 | |
| `Cycling-DQ-081` | `GLOBAL-DQ-077` | 0 / 1736 | |
| `Cycling-DQ-082` | `GLOBAL-DQ-122` EVENT_RESULTS_RANK_WITHOUT_DECIDING_VALUE | 4 / 9588 | three events rank a whole field with no time at all - `Oceania Championships` 2011 twice and `African Championships` 2005 - and `Ronde van Drenthe` 2015 has 40 of 106 ranked riders without one |

The three parameters those rest on: `MEDAL_ROUND_TYPE_LIST` is `173 Final` alone, since a stage
of a tour awards nothing; `NUMERIC_RESULT_TYPE_LIST` is `100 Rank`, `102 Points` and
`222 Laps behind`, with `101 Duration` deliberately outside because it is a time and reading it
as a number would report the whole sport; and `RESULT_TIE_VALUE_TYPE_LIST` is `101 Duration`,
because two riders share a place when they record the same time.

**The city is never written, on either layer, and two checks say so at 100 per cent.**
`Cycling-DQ-083` carries `GLOBAL-DQ-034` and reports **3528 stages of 3528**; `Cycling-DQ-084`
carries `GLOBAL-DQ-035` and reports **1795 statistics of 1795**. Every row on both is
`city` and nothing else. The geography of a road race also lives in the `StartName` and `EndName`
event properties, on 8997 events each.

**That looked like a convention and it is not.** Both checks were `Monitor` until 2026-08-17 on
the reading that a race running between two towns has no one city to name. **The review settled
it the other way: the column is simply not filled for this sport and it should be.** Both are
ordinary checks now, reporting a defect, and they will read 100 per cent until somebody fills it.
The other fields they assert - the name, the country, the Gender setting and the host-country
rule - are audited and clean today, so `missing_fields` stays the column to read first at every
run: a row naming anything beyond `city` is a new finding.

**23930 participations of 1270517 hold no usable place**, and `Cycling-DQ-085` reports them
**one row per event** rather than one per rider. It is the sport variant
`EVENT_RESULTS_RANK_INVALID_OR_MISSING_BY_EVENT`, not `GLOBAL-DQ-036` whole, and the reason is
the size of a cycling field. The template audits the participation, which is right where a field
is small - measured 2026-08-16 it returns 1 row on Triathlon, 44 on BMX, 69 on
Artistic-Gymnastics and 357 on Modern-Pentathlon, and on all four the rider's name is what a
reviewer needs. Here it returned 23930, because one unresolved race contributes its whole start
list. Folded to the event that is **1361 rows of 9612 events**, and the counts still sum to
23930: nothing is dropped, only gathered.

| Shape | Events |
|---|---:|
| `EVENT_PART_OF_FIELD_HOLDS_NO_RESULT` | 1359 |
| `EVENT_RANK_OVER_MAX` | 1 - `Eugen Wacker` at 1005, the same row `Cycling-DQ-015` and `Cycling-DQ-018` report |
| `EVENT_RANK_MISSING_WITH_OTHER_RESULT_PRESENT` | 1 - `Magdalena Polanska`, holding other results |
| `EVENT_WHOLE_FIELD_HOLDS_NO_RESULT` | 0 |

**The fold corrected a claim this file used to make.** Read per participation, the 23930 looked
like whole start lists entered and never resolved, because the worst events hold 437 apiece and
supplied most of the rows. With `field_size` standing beside `affected_count` that reading does
not survive: **not one event of 9612 has its whole field unresolved**, and half the reported
events are a single rider.

| How much of the field is unresolved | Events |
|---|---:|
| exactly 1 rider | 690 |
| 2 to 3 riders | 92 |
| under 10 per cent of the field | 279 |
| 10 to 50 per cent | 260 |
| half the field or more | 40 |

The 40 heaviest events supplied 23025 of the 23930 participations, which is why the 690
single-rider cases were invisible before. Those two are different work - one race to look at
against one rider to chase - and the check now says which it is. Overall this is 1.9 per cent of
the sport's participations. The statement costs 51 seconds against the template's 33.

**Nine further templates were carried on the last parameter decisions.** Six return nothing over
real populations - `Cycling-DQ-086` (`GLOBAL-DQ-047`, 168 not-started events), `-089`
(`GLOBAL-DQ-062`, 10578), `-091` (`GLOBAL-DQ-102`, 1067), `-092` (`GLOBAL-DQ-120`, 9600), `-093`
(`GLOBAL-DQ-121`, 1730) and `-094` (`GLOBAL-DQ-124`, 9613). Two hold findings:

- **`Cycling-DQ-088`** carries `GLOBAL-DQ-061` and reports **1 of 9749**: `Classic Grand Besancon
  Doubs`, due 16 April 2021, still standing `Postponed` **1948 days later**.
- **`Cycling-DQ-090`** carries `GLOBAL-DQ-081` and reports **14 templates of 29** whose editions
  skip years. All are annual championships: `Asian Championship` jumps 2004 to 2011 and 2019 to
  2022, `Oceania Championship` 2005 to 2009 and again 2009 to 2011, `African Championship` 2013
  to 2015 and 2019 to 2021. `SERIES_SKIP_YEARS` is deliberately `0` here - unlike the rest of
  the package, which skips 2020 - because cycling raced through 2020 and the Tour de France was
  held, so a hole that year is a hole worth reporting.

**`Cycling-DQ-087`** carries `GLOBAL-DQ-056` and audits nothing today, `eligible_count` 0. It is
the second sentinel beside `Cycling-DQ-071`, for the same reason: it adds the leader's full time
to a rider's gap, and there are no full times to add. It carries the `Sentinel` signal from the
same day and for the same reason as its twin.

**`GLOBAL-DQ-111` runs whole for this sport since 2026-08-17 and is `Cycling-DQ-101`, carried as
`Monitor`.** It compares one finisher's effective time with another's, and it spent a day as
`Not checked` because it timed out at 504 after 180 seconds. Two rebuilds closed that, the first
for cost and the second for a defect.

The 2026-08-16 rebuild removed three costs, each work done per row that belonged somewhere else:
an all-pairs self-join inside each event, about 69 million pairs here; a correlated `NOT EXISTS`
over `result` for the Comment, asked once per participant; and an `EXISTS` over
`object_discipline` asked once per participant for a property of the event. It was not enough
here.

**The 2026-08-17 rebuild started from a defect, not a cost. The parser accepted at most one
colon**, so it read `M:SS` and plain seconds and voided everything else - and a road stage lasts
four to seven hours, so its winner's time always carries two. **8956 of this sport's 1140293
`101 Duration` values were being read as unreadable**, which did more than inflate the count: an
unparseable time leaves the comparison, so every stage leader was silently removed from the
audit that exists to compare him. Reading hours dropped one measured window from 1780 findings to
173. Triathlon, whose races also run past the hour, went from 3210 findings of 3603 events to **0
of 3603** - the whole of its result had been the parser. BMX, which races in under a minute, is
unchanged at 47 of 8001, and that is what says the `M:SS` path was not disturbed.

Three further costs came out in the same pass and are what brings this sport inside the limit.
The largest by far: coverage was aggregating all 1140293 participations a second time only to
learn whether each event holds at least one eligible one, which `EXISTS` answers by stopping at
the first. The other two are small - the per-participation grouping no longer carries
`event_name` and `tournament_stage_name` through 1270283 rows, and the two counters are `SUM`
rather than `COUNT(DISTINCT)` over a row that is already one per participation.

**It finishes in 176.5 seconds against the server's 180, and that margin is the second reason it
is `Monitor` rather than a plain check.** It runs today; a busy server returns a 504 and the run
reports it failed. Two further ideas were tried and both are recorded because they are the
obvious next ones and both are wrong: narrowing the `result` join to the four types the statement
reads saves nothing, because those four are 99.9 per cent of the rows; and lifting the repeated
`TRIM(LEADING '+' ...)` into a derived table of its own made the statement time out again, since
MariaDB materialises every level and a new level costs more than the eight scalar evaluations it
removes. **It was never sharded to make it fit** - `WORKFLOW.md` owns that rule. Four date windows
were run only to measure, and they returned the identical 1300 findings of 9609 events that the
whole statement returns.

What it reports is 1300 events of 9609 in the `628 Road Race` discipline. Two thirds are
`EFFECTIVE_TIME_UNPARSEABLE` and every one of those is a value written wrong rather than a race
run wrong: a winner's time truncated to `4:20:1` where `4:20:01` belongs, a gap of `+27:72` where
seconds cannot be 72, a stray space or underscore. Those are **271 rows of 1133607** and they are
a work list. The rest are `RANK_EFFECTIVE_TIME_NOT_MONOTONIC` and are not all defects, for the
reason recorded above: the same-time rule credits a whole group with the leader's time while the
places inside it follow the order the riders crossed.

<!-- MANUAL PASTE ZONE: 30 EVENT AND ROUND REPRESENTATION — insert approved additions immediately before this marker; do not move or delete it. -->

## Confirmed sport-specific storage semantics

**Cost lives in `event_participants` and `result`, not in the event count.** With 120
participations to an event and 1.14 million rows in each of `100 Rank` and `101 Duration`, a
statement that walks the sport once per person does not return: `GLOBAL-DISCOVERY-033` failed
on both its runs on 2026-08-16 for exactly that reason, and was rewritten to group each
participation path once rather than count it per person. Any statement written here is read
against that shape first.

**Six checks are written for this sport because no template asks what cycling asks.** They were
designed on 2026-08-16 and 2026-08-17 from the confirmed structure above, and each was measured
before it was numbered.

| Check | What it asserts | Findings / eligible |
|---|---|---|
| `Cycling-DQ-095` EVENT_AVERAGE_SPEED_IMPLAUSIBLE | the distance and the winning time give a speed a bicycle race reaches | 39 / 7937 |
| `Cycling-DQ-096` EVENT_SCOPE_CHECKPOINT_CHAIN_INCONSISTENT | a checkpoint's distance, remaining distance, finish marker and jersey group read as written | 104 / 1094 |
| `Cycling-DQ-097` EVENT_SPLIT_STAGE_HALF_WITHOUT_ITS_SIBLING | a lettered half of a split stage has another half beside it | 1 / 68 |
| `Cycling-DQ-098` EVENT_RIDER_OLDER_THAN_THE_STAGE_AGE_CLASS_ALLOWS | the field matches the age class the stage is run under | 14 / 77 |
| `Cycling-DQ-099` COMP.RANK_CLASSIFIES_A_RIDER_WHO_ABANDONED | a rider placed in a ranking finished the events it covers | 0 / 522 |
| `Cycling-DQ-100` TOURNAMENT_STAGE_NUMBERS_NOT_CONTIGUOUS | a tour's stage numbers run without a hole | 1 / 1218 |

**The speed check reads two fields nothing else compares, and each is the other's only witness.**
`Kilometers` is a metadata property on the event and the winner's `101 Duration` is the one
absolute time a race stores; a distance typed with a digit too many and a time typed with one
too few produce a row here and nowhere else. The bands were measured before the thresholds were
set: of 7939 races where both values parse, **7771 fall between 30 and 50 km/h**, 109 between 50
and 60 - a short time trial - and 20 between 15 and 30, a mountain stage. Outside those, **7 run
below 15 km/h, the slowest at 0.67, and 32 above 60, the fastest at 100.7**. The two grey bands
are deliberately not reported, because a 55 km/h prologue and a 28 km/h summit finish are both
real and reporting them would bury the 39 that cannot be.

**The checkpoint check audits the one layer this sport has to itself**, in four shapes:
`distance_to_go` below zero on 6 events, worst at `-4.0 km`; a jersey group left blank on 86,
where every other row names `Peloton` or a breakaway numbered 1 to 13; two finish lines in one
race, on 1; and a distance that is neither a number with its unit nor the word `Finish` on 11,
including **`64..0 km` with two decimal points**.

**The age-class check takes its ceilings from the data and not from the labels, and that is the
whole difficulty.** The class named `JUNIOR` is attached to the `World Championship U23` races:
its field is 419 riders aged 19, 669 aged 20, 844 aged 21 and 911 aged 22, so **`JUNIOR` means
under 23 here whatever the word says**, and the UCI's junior ceiling of 18 would have reported
2843 riders racing correctly. `YOUTH` sits on the `European Youth Olympic Festival` and the
`Youth Olympics` at 15 to 18. Above the two lines there are 13 riders in 14 events, none of them
borderline: `Raimondas Rumsas`, born 1972, in a U23 World Championship road race, and
`Benjamin Noval`, born 1979, at a European Youth Olympic Festival.

**Three drafts were wrong and the data said so before anything was numbered**, which is recorded
here because each mistake is repeatable:

- **A rider abandoning does not contradict a placing in another race of the same meeting.** Asked
  against every event of the tournament, the abandonment check reported 700 riders across every
  championship template - a championship holds a road race and a time trial, and the two are
  independent. Tied through the ranking's own `1471 Event id` list it reports nothing, and the
  sport is clean on the rule.
- **A `REGEXP_REPLACE` backreference does not survive this package's execution path.** `\1`
  arrives at the server as a literal `1`, so every name parsed to the same value: the split-stage
  check reported all 30 halves as orphans and the stage-number check reported none at all. Both
  are parsed with `SUBSTRING` and `CAST` instead.
- **A gap does not have to grow with the place, and that is the sport rather than a defect.** A
  check asserting it reported **1267 events and 29003 riders**, a median of 14 per event,
  concentrated in `Category 1`, `Category Pro`, `World Tour 1` and the Grand Tours - the mass
  finishes. Riders crossing the line together are credited with their group's time while their
  placing is where they actually finished, so a rider placed 150th can hold `+0:00` while the
  hundredth holds `+1:21`. The check was **not written**.

<!-- MANUAL PASTE ZONE: 30 STORAGE SEMANTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Open questions

**All twelve are answered and closed**, put to the review together on 2026-08-17 and settled the
same day. The numbering is kept rather than compacted, because answers given against these
numbers exist outside this file, and each entry keeps its question above its answer so that a
reader a year from now can see what was being asked.

**Two answers corrected this file rather than adding to it**, and both are marked where they
sit: the `(IOC)` twins are out of the client scope rather than a curiosity, and `FF#` is Photo
Finish rather than a rank in the wrong column.

1. ~~**What produces the one-stage offset between the round type and the event name?**~~
   **Answered 2026-08-17: there is no Prologue round type in the system.** Where a tournament
   stage holds a prologue, the round type carries the **sequence of the event** rather than the
   number of the stage, and every following round is one out. That is the whole of the 175 of
   1117 on round `41`, the 160 of 923 on `42` and the rest of the chain.
   **The round number therefore cannot check the stage number, and no check in this package
   tries to.** `Cycling-DQ-100 TOURNAMENT_STAGE_NUMBERS_NOT_CONTIGUOUS` reads the numbers out of
   the event names for exactly this reason, which was luck rather than judgement at the time and
   is now the documented reason. Nothing is written on the round type as a stage reference, and
   nothing should be until a Prologue type exists.
2. ~~**Are `102 Points` and `222 Laps behind` one field or two?**~~ **Answered 2026-08-16: they
   are one field written twice.** All 31 participations hold **both** types, all 62 values are
   `0`, and the 12 events are the four Olympic starts of 2004, 2008 and 2012 - road race and
   time trial, men and women. The holders are the podium: 12 firsts, 9 seconds, 8 thirds and 2
   with no rank. It is a vestige of the Olympic import for three Games rather than two
   measurements, and no check is written on either type.
3. ~~**Why do 136 World Championship editions hold no stage at all?**~~ **Answered 2026-08-17 and
   it moved the sport's client boundary.** The 136 are historical editions entered for the IOC
   project and empty because they fall outside the client's 2004 to 2025 window - their
   tournaments are named `1927` through `2002`. The `(IOC)` twin templates are the same thing
   under their own name and **are used exclusively for that project**. Both groups are now
   outside the client scope, eleven templates in all, and the section above records what that
   removed. Of the six empty tournaments left, the review names each: `2002` predates the window,
   the two `Summer Paralympics` 2024 editions will not be filled here because Para Cycling was
   not a separate sport when they were entered, and `Asian Championship` 2020 twice and
   `Oceania Championship` 2025 were cancelled. **The review holds that those five are candidates
   for deletion rather than for filling**, which is a decision for whoever owns the data and is
   recorded here rather than acted on.
4. ~~**Why does `Disqualified` keep the rider's place?**~~ **Answered 2026-08-17 in two halves,
   and the package follows only one of them.** What happens to *the rest of the field* is a rule
   of the sport: when a rider is disqualified **nobody below him is renumbered**, so the places
   stand as they were raced. Lance Armstrong struck from the 2002 Tour de France is the review's
   example, and the second-placed rider stays second rather than inheriting the win. An unshifted
   field is therefore not a defect and nothing here treats it as one.
   What happens to *the disqualified rider himself* depends on the source, and the review's
   instruction for this package is unambiguous: **for the check, a `Disqualified` rider must hold
   no rank.** So `Disqualified` stays in both no-result lists and the finding stands.
   **That makes 1247 of `Disqualified`'s 1400 event rows a work list** - they keep the place,
   1253 keep the time and one holds a medal, over places 1 to 196 - and **34 of its 116 Comp.Rank
   records besides**, measured 2026-08-17. `Cycling-DQ-077` reports the event layer and the
   ranking checks report the other.
   Being outside the time limit is settled and moves to question 5.
5. ~~**What do `a`, `FTM`, `HUD` and `OOT` mean?**~~ **Three of the four answered 2026-08-17:
   `FTM`, `HUD` and `OOT` all mean outside the time limit**, the same thing `HD` and `OTL`
   already meant, each confirmed on the row against the published result. All three join
   `RESULT_COMMENT_VALUE_LIST` and `RESULT_COMMENT_NO_RESULT_LIST`, so the riders carrying them
   leave the rank and time comparisons as the rule intends. **The sport therefore writes being
   outside the time limit in five different ways** - `HD` 3111 rows, `OTL` 137, `FTM`, `HUD` and
   `OOT` a handful each - which is not a defect any check can assert but is worth one sentence to
   whoever maintains the vocabulary.
   **`a` is answered too: it is an error, and the review says to keep reporting it.** Read in
   full on 2026-08-17, it sits in **one event of the sport's 10578** - the women's
   `Driedaagse De Panne-Koksijde` of 22 March 2018, event `2681702` - where the winner holds
   `3:52:23` and no comment and **all nineteen riders behind her hold `+0:00` and `a`**. The whole
   bunch on the winner's time, annotated once and never again anywhere in the sport, which is what
   a one-off import artefact looks like rather than a code. It stays outside the vocabulary so
   `Cycling-DQ-077` keeps naming it.
   **And `FF#` is not what this file said it was.** It was read here as the rank echoed into the
   wrong column; the review answered on 2026-08-17 that it means **Photo Finish** and the number
   is the place the photograph decided, so the agreement with the rank is the code working rather
   than a symptom of a mistake. `ff1` through `ff250` are approved on both layers and are on
   neither no-result list. The results section carries the measurement and the reason for the
   ceiling.
6. ~~**Why is `1427 Time Difference` empty on 2790 riders across 46 statistics?**~~ **Answered
   2026-08-17 as the Comp.Rank face of question 7**, and it closes with it. Nothing separate.
7. ~~**Why does a timed sport store no full time?**~~ **Answered 2026-08-17: the sport is missing
   `557 Full time` and it should have it.** This is a gap in the import rather than a convention
   of the sport, so the leader/gap reading of `101 Duration` is what exists rather than what was
   intended. The review asks for the absence to be reported in full against Triathlon, which
   writes one for every one of its 112386 durations, and expects the finding to stay at 100 per
   cent until the field is populated.
   `Cycling-DQ-069` reports **9611 events of 9611** and `Cycling-DQ-070` **1734 Comp.Rank records
   of 1734**, and both stay `Monitor` for that reason: a total finding that is waiting on one
   import is a state to watch, not a list anybody can work through row by row. `Cycling-DQ-071`
   and `Cycling-DQ-087` stay sentinels at `eligible_count` 0 and become real checks on the day
   the first full time is written.
8. ~~**What is scope type `0`?**~~ **Answered 2026-08-16 as a single malformed row**, on event
   `828866`, `Stage 8` of the Tour de France on 11 July 2010. It carries two details,
   `distance = Finish` and `distance_type = mountain1`, so the distance field holds a word where
   a number belongs. **The discrepancy between the 95 events recorded earlier and the one read
   from `event_scope` is retired rather than resolved**: the review confirmed on 2026-08-17 that
   the client does not need the scope layer for this sport at present, so neither figure is worth
   the measurement it would take. `Cycling-DQ-091` and `Cycling-DQ-096` are `Out of client scope`
   and hold their 0 and 104 findings until it is wanted again.
9. ~~**Why do 1359 events hold riders with no result of any kind?**~~ **Answered 2026-08-17 and
   the answer is the rule the check already follows**: a rider with no rank and no comment is a
   problem to report; a rider with a comment and no rank is correct and must not be. That is
   exactly what `Cycling-DQ-085` asserts - its finding conditions require both to be absent - so
   the check needed no change and both halves of it stand. The 40 races that lose half their
   field and the 690 that leave one rider unresolved are both real, and the fold to the event is
   what lets a reviewer tell them apart.
10. ~~**Why do 79 rankings in championship and Games templates award no medal?**~~ **Answered
    2026-08-17: the medals are missing from the data and must be added.** The check is sound as
    written and the medal-template list needs no narrowing. `Cycling-DQ-068` stays `Actionable`.
11. ~~**Why is `city` never written?**~~ **Answered 2026-08-17: it is not written for this sport
    and it should be.** Not a convention of road racing, then, but an unfilled column, so
    `Cycling-DQ-083` and `Cycling-DQ-084` stop being `Monitor` and become ordinary checks
    reporting a defect. They read **3528 stages of 3528 and 1795 Comp.Rank records of 1795**, and
    they will read that until the column is filled. `missing_fields` stays the column to read
    first at every run: a row naming anything beyond `city` is a new finding.
12. ~~**Was the round type usable as a stage reference?**~~ Folded into question 1, which answers
    it.

<!-- MANUAL PASTE ZONE: 30 OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
