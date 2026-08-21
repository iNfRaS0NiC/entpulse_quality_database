# SPORT: Golf (sport_id=3)

This file is the canonical structural record for Golf. It contains only confirmed
sport-specific usage, meanings, identifiers, evidence boundaries and open structural
questions. Global database mechanisms belong in `../DATABASE.md`.

For additions, insert approved content immediately before the exact active
`MANUAL PASTE ZONE` marker in the destination subsection. Keep the marker unchanged
and at the end of its subsection. Replace existing rows or paragraphs in place when a
correction is required.

## Identity and evidence

- First discovery date: 2026-08-12
- Latest evidence date: 2026-08-13
- Verification boundary: one GLOBAL discovery sweep, sport-wide and unnarrowed, plus the
  targeted follow-ups named below. `enet_sport_code` is `g`. Two catalogue statements could
  not be run as written and were narrowed; what each narrowing gave up is recorded against
  its area. **Every figure in this file is sport-wide, and the client scope is narrower than
  the sport** — see **Scope** below. A count here is what Golf holds, not what a check now
  returns, and the two differ by roughly a seventh of the events and a third of the event
  participants.

## Structural coverage

| Area | Status | Evidence |
|---|---|---|
| Core hierarchy | Confirmed | `GLOBAL-DISCOVERY-001`, `-002` |
| Event participants | Confirmed | `GLOBAL-DISCOVERY-004`, `-032` |
| Event results | Confirmed | `GLOBAL-DISCOVERY-007` narrowed; `-026` for `31`–`34`, `36`, `100` |
| Incidents | Confirmed absent | `GLOBAL-DISCOVERY-008` |
| Lineups | Confirmed absent | `GLOBAL-DISCOVERY-005` |
| Scope layer | Confirmed | `GLOBAL-DISCOVERY-009`, `-010` narrowed |
| Properties | Confirmed | `GLOBAL-DISCOVERY-011` |
| object_relation | Confirmed | `GLOBAL-DISCOVERY-012` |
| object_discipline | Confirmed | `GLOBAL-DISCOVERY-013`, `-032` |
| Statistics | Confirmed | `GLOBAL-DISCOVERY-015`, `-016`, `-017`, `-030`, `-031` |
| Reference values | Confirmed | `GLOBAL-DISCOVERY-014` |
| Other tables | Not checked | |

## Tables and relation paths used

Core hierarchy through `tournament_template.sportFK = 3` → `tournament` →
`tournament_stage` → `event` → `event_participants` → `result`. 37 active templates, 425
tournaments, 5464 stages, 19443 events, 585083 event participants and 3326056 result rows.
Golf is the largest sport documented here: its event-participant count is roughly two and a
half times Modern Pentathlon's, and its scope layer is an order of magnitude larger again.

`event_scope` → `scope_result` is the sport's heaviest storage by a wide margin, and the
reason two catalogue statements failed on the first sweep. `lineup` is not used at all.
`incident` is not used at all.

`object_relation` carries five active pairs: a sport-level `1 → 153`, a template-level
`2 → 152`, a stage-level `4 → 151` on 5455 of the 5464 stages, and two statistic-level pairs,
`83 → 33` on 3444 statistics and `83 → 151` on 3383.

<!-- MANUAL PASTE ZONE: 3 TABLES AND RELATIONS — insert approved additions immediately before this marker; do not move or delete it. -->

## Participant and lineup structure

Event participants are `athlete` and `team`. Athletes dominate: 14018 male and 5809 female
participant records against 36 male, 32 female and 1 mixed team. The sport registry agrees,
and additionally carries 131 male and 11 female athletes flagged inactive.

**A pair is stored as one `athlete`, not as a team with a lineup.** Golf uses no `lineup` row
anywhere - `GLOBAL-DISCOVERY-005` returns nothing for the sport - yet it contests foursomes and
fourball, and those pairings are stored as a single `athlete` participant whose name holds both
players separated by a slash: `A. Hansen/Olesen`, and at event level
`Aada Rissanen/Emilia Torvinen-Linda Stebernjak/Hannah Mitterberger`. Any check that assumes an
`athlete` participant is one person is therefore wrong here, and any check that looks for a
pair's members in a lineup finds nothing. The `team` participants are a different thing again -
continental and national sides such as `Asia`, `Asia (f)` and `Captains`, used by the cup
competitions.

**`event_participants.number` carries the side, and odd against even is the rule.** Measured
2026-08-14 over every finished Match Play event inside the client boundary. A singles match holds
numbers 1 and 2. A foursome holds 1, 2, 3 and 4 - not 1, 1, 2, 2 - and the pairing is not the
consecutive one it looks like: in all 2008 four-entry events where every competitor is named in
the event name, the two named first carry numbers **1 and 3**. There is no exception and no
second shape.

So a foursome is 1 and 3 against 2 and 4, and the side is readable from the database rather than
only from the event name. This corrects what this file said until today - that nothing in the
database says which two belong together - and the correction is left visible because
`Golf-DQ-092` was written under the old belief and left four-entry events unjudged for exactly
that reason. It was extended to them on 2026-08-14: every count in it is now a count of sides
rather than of rows, and 2132 finished four-player events entered its eligible population.

**A side speaks once, not once per player.** Measured the same day: 2017 of those 2132 events
carry exactly two values in `4 Final Result`, one on each side, and the partner's entry is left
empty. 40 more carry none at all and 71 carry more. So a silent row beside a spoken one is the
convention, and a side is incoherent only when it holds two different words - never when it holds
fewer words than players. Reading it the other way reported all 2089 correct foursomes as
contradictions, which is how the convention was found.

`39 Match Play Score` follows the same habit in singles: 7783 of the 9549 two-sided events that
carry a verdict hold the score on one entry only, and 1766 hold it on both.

The other two paths were re-measured the same day and are genuinely absent: the sport holds zero
`lineup` rows, and the `1429` Team data field is declared for shard 11 and unused. The number was
the one path nobody had read.

**The sport keeps a separate participant record for a national women's team, and
`Golf-DQ-075`'s 18 team findings are entries that missed it rather than a gender field that is
wrong.** Two naming styles are in use for the same thing - `Belgium Female`, `France Female`
beside `England (f)`, `Germany (f)` - and 28 of them exist. Measured 2026-08-19, the European
Girls' Team Championship holds 1068 entries on those records across 534 events from 2004 to
2025, and 54 entries on the plain country record across 27 events, none later than 2010. That is
two per event exactly, and four of the events were read one by one: both sides of every match
carry the plain record. So these are 27 whole matches imported against the men's records in a
run that stopped fifteen years ago, and the record to move them onto already exists. Nothing has
to be created and no gender field should be edited - editing one would break the 48 to 76
correct men's entries each of those records also carries.

The three athlete findings are three different things and only one of them is a defect of the
kind the check names:

- **Maksymilian Saluda** holds 3 entries, all in the European Boys' Team Championship, and none
  that agree with the stored gender. The participant's gender is simply wrong. One field.
- **Joanne Mills** holds 87 entries that agree and 4 in `PGA Tour 1`. On 2006-08-03 she holds
  two entries on the same day, one in `PGA Tour 1` and one in `Ladies European Tour and LPGA
  Tour 1`, and nobody plays two tours in a day. Her four `PGA Tour 1` scores read 5, 0, -4 and
  144, and 144 is a 36-hole total rather than a figure against par. These are another
  competitor's results carried on her id.
- **Michelle Wie West** holds 299 entries that agree and 1 in `PGA Tour 1` on 2008-07-31, which
  is correct. The weeks either side were read: there is no same-day entry anywhere else, and she
  entered that men's event on an exemption. **A woman entering a men's event is a legitimate
  shape in this sport and the database stores nothing that separates it from a misassigned
  entry**, so this row is a false positive `GLOBAL-DQ-123` cannot be taught to avoid. It is one
  row in 21 and the check stays `Actionable`; the row is read and dismissed.

<!-- MANUAL PASTE ZONE: 3 PARTICIPANTS AND LINEUPS — insert approved additions immediately before this marker; do not move or delete it. -->

## Event result types

Seventeen active result types, from `GLOBAL-DISCOVERY-007` narrowed. The narrowing dropped the
three `COUNT(DISTINCT)` columns the statement declares and kept the sport-wide scope, so the
inventory below is complete for the sport and the per-type participant and event counts are
not yet measured. `result_row_count` is what was returned.

| result_code | result_typeFK | Value shape | Confirmed meaning | Evidence |
|---|---:|---|---|---|
| strokes_r1 | 31 | integer, and non-numeric text occurs | Strokes taken in round 1 | 547725 rows |
| par | 36 | signed integer against par | Score against par for the event | 546735 rows |
| strokes_r2 | 32 | integer, and non-numeric text occurs | Strokes taken in round 2 | 540614 rows |
| made_cut | 38 | `yes` / `no` | Whether the player survived the cut | 534976 rows |
| rank | 100 | integer, up to 9999 | Finishing place | 526444 rows |
| strokes_r3 | 33 | integer, and non-numeric text occurs | Strokes taken in round 3 | 311327 rows |
| strokes_r4 | 34 | integer, and non-numeric text occurs | Strokes taken in round 4 | 250309 rows |
| finalresult | 4 | `0` … `won` | Match-play outcome | 25479 rows |
| mpscore | 39 | text, includes `WO` | Match-play score line | 16813 rows |
| comment | 104 | text, includes `WD` | Status comment | 10257 rows |
| prize_money | 540 | decimal, `0` … `99807.62` | Prize money | 9593 rows |
| strokes_points_r1 | 526 | integer | Stableford-style points, round 1 | 1727 rows |
| strokes_points_r2 | 527 | integer | Stableford-style points, round 2 | 1713 rows |
| strokes_points_r3 | 528 | integer | Stableford-style points, round 3 | 961 rows |
| strokes_points_r4 | 529 | integer, `-1` occurs | Stableford-style points, round 4 | 881 rows |
| strokes_r5 | 35 | integer | Strokes taken in a fifth round | 484 rows |
| medal | 501 | `bronze` / `silver` / gold | Medal awarded | 18 rows |

**The sport scores a round at a time, and the total is not stored at all.** `31`–`35` and
`526`–`529` are per-round fields. The editing interface shows two further columns beside them,
`Total` and `Total Par`, and only the second of the two exists in the database.

`36 Par` is `Total Par`: the score against par for the whole event, and it is measured rather
than inferred. Over every stroke-play participant holding four numeric rounds and a numeric
`36`, the value equals the sum of the rounds minus the course par times four - confirmed on
9023 participants in 2026 with no exception, and on 200572 sport-wide. The course par comes
from the `tournament_stage` property `Par`, which is why that property is not decoration.

`Total` - the raw stroke count, 258 for a 66-65-63-64 - **has no result type.** The interface
computes it from the four rounds. Any check wanting a stroke total has to sum the rounds itself,
and any check comparing "the event's score" against a rank must use `36`, which is signed and
therefore not comparable to a stroke count.

This also explains the shape counts above. `36` writes an over-par score two ways: 310110 values
carry a bare `#` and 9347 carry `+#`, and both mean the same thing. The `-#` majority of 222174
is the under-par side, which needs no sign convention to be unambiguous.

**The value shapes are measured.** `GLOBAL-DISCOVERY-026` was run sport-wide for `36`, `31`,
`32`, `33`, `34` and `100`, one result type per execution.

`36 Par` holds 546735 values in eleven shapes. Three are the sport working correctly: `#`
(310110 values in 4559 events), `-#` with an ASCII hyphen (222174 in 4765) and `+#` (9347 in
124). All three are whole numbers, and confirmed 2026-08-13, that is the whole of what the field
may hold: a score against par is a count of strokes, so `36` joined `INTEGER_RESULT_TYPE_LIST`
alongside the five round totals. Signed, but never fractional. The rest are not:

| Shape | Values | Events | What it is |
|---|---:|---:|---|
| `-` | 4831 | 1743 | a bare hyphen where a number belongs - "no score" written into a numeric field |
| `<EMPTY>` | 163 | 31 | empty string |
| `−#` | 39 | 2 | `U+2212`, the typographic minus |
| `â€™#` | 32 | 3 | the same `U+2212`, double-encoded through UTF-8 |
| `E` | 21 | 4 | a bare letter |
| `–#` | 14 | 1 | `U+2013`, an en dash |
| `N/A` | 3 | 1 | text |
| `#<tab> #` | 1 | 1 | a tab inside the value |

**The field writes a minus four different ways.** The ASCII hyphen accounts for 222174 of them
and the other three for 85 values across 6 events, so a cast that accepts only `-` loses those
85 silently rather than loudly.

`31`–`34 Strokes` are cleaner in proportion but hold two defects of their own:

| Result type | `-#` | `Â<nbsp>` | `D` | `<EMPTY>` |
|---|---:|---:|---:|---:|
| 31 (round 1) | 417 | - | 1 | 133 |
| 32 (round 2) | 398 | - | 3 | 274 |
| 33 (round 3) | 172 | 437 | 2 | 2648 |
| 34 (round 4) | 206 | 356 | - | 3146 |

**A negative stroke count is the larger of the two and cannot be a real score**: 1193 values
across the four rounds record a player taking fewer than nought strokes. The `Â` is
`U+00C2 U+00A0`, a non-breaking space that has been through a UTF-8 round trip twice, and it
occupies 793 values in eleven events. `31` and `32` additionally hold `# #` and `# # #`, two
numbers in one value, and `32` holds `#n`.

`100 Rank` is clean. All 526444 values in 4841 events carry the single shape `#`, with no empty,
no text and no separator. Its maximum of 9999 is a valid integer and a question about the value
rather than about its shape.

**The comment vocabulary, and why two of its values are not "no result".** `104 Comment` holds
10257 rows over nine values and an empty string: `wd` (6824 rows in 2573 events), `mdf` (1711 in
170), empty (809 in 408), `dq` (761 in 580), `mc` (74 in 1), `rtd` (51 in 25), `sub` (16 in 14),
`nr` (7 in 5), `dns` (2 in 1) and `n/r` (2 in 1).

`RESULT_COMMENT_NO_RESULT_LIST` is `wd`, `dq`, `rtd`, `dns`, `nr` and `n/r` - the six that end a
participation without a classification. `mc` and `mdf` are deliberately outside it, and this is
where golf differs from every other sport in the package. A player who missed the cut has valid
round-one and round-two scores, and `mdf` means made the cut and did not finish, so both hold
real results and simply stop earlier than the field. Treating them as "no result" would silence
1785 participations in which a missing rank is a genuine finding.

`nr` and `n/r` are one value written two ways, 7 rows and 2. Both are listed so that neither
reads as an unknown comment, which is a vocabulary defect recorded rather than repaired.

**`wd` is not a no-result marker in golf, and that is the sport speaking rather than the data
being wrong.** A player who withdraws keeps the position the field gave them, so a `wd` sitting
beside a Rank is the convention and not a contradiction. Confirmed 2026-08-12. `wd` was in
`RESULT_COMMENT_NO_RESULT_LIST` when the vocabulary was first recorded, and taking it out moved
`GLOBAL-DQ-117` from 7644 findings to 823 - from four fifths of its eligible population, which
is a proportion, to a list somebody can work through. It moved `GLOBAL-DQ-122` the other way,
47 to 87, and that is the same fact read from the other side: if a withdrawal keeps its place,
the place owes a deciding value like any other.

What remains in the list is `dq`, `rtd`, `dns`, `nr` and `n/r`. A disqualification removes a
result rather than freezing it, which is why `dq` stays in and `wd` does not.

**Two formats break the par arithmetic without breaking any data, and the database cannot see
either of them.** Both were found on 2026-08-14 by reading what disagreed with the equation
above, and in both the disagreement is the sport rather than the storage.

*A tournament played on more than one course.* The stage carries a single `Par`, and a rotation
gives each competitor a different par per round: AT&T Pebble Beach Pro-Am runs Pebble Beach,
Spyglass Hill and Monterey Peninsula, so a card's par for the event is their sum and not four
times any one of them. The difference then fails to divide by the rounds played and every card
in the field looks wrong. Measured: 155 of 156 at Pebble Beach Pro-Am 2017, 209 of 210 at Joburg
Open across five editions, 50 of 99 at Dunhill Links Championships 2003, and 244 to 251 of about
250 at British Boys Amateur Championship across four. Nothing in `tournament_stage` records the
second course; `Par` and `Venue` are single-valued.

*A tournament that starts before it starts.* Tour Championship carries the same shape in exactly
25 of 30 cards, in each of 2019, 2020, 2021, 2022, 2023 and 2024 - the six editions run under
FedExCup Starting Strokes, where the field begins at a staggered score rather than level. Those
strokes are in the Total Par and were never played, so no sum of rounds can reach it. Six
consecutive years of the same shape is a format, not six years of the same mistake.

Both matter to any check written from the rules of the game. The discriminator that keeps them
out is not a threshold: a fact about the course or the format reaches the whole field, and a
wrong card reaches one competitor. `Golf-DQ-101` is scoped on exactly that.

**One tournament is played for points, and its points are stored as strokes.** Barracuda
Championship, and the same tournament under its earlier name Reno-Tahoe Open, is played under
Modified Stableford: the card is scored in points and the higher total wins, which is the
opposite direction to every other event in the sport. The database does not store it that way.
Measured 2026-08-14 over the editions this project has read - Reno-Tahoe Open 2012 and 2013,
Barracuda Championship 2014 through 2018 - each holds around 410 values in the stroke fields
`31`-`34` and **no** `526`-`529` point value at all. Barracuda 2025 is the first edition to carry
the point types, and it carries both: 444 point values beside 442 stroke values.

The International 2006 was a separate tournament played under the same format and shows the same
shape. Two further events - EDS Byron Nelson Championship 2008 and ANZ Championship 2004 - are
ordinary stroke play where part of the field carries a raw total in `36 Par` anyway, so the shape
is not exclusive to the format.

This matters beyond the tournament. A points total in a stroke field defeats the par arithmetic
above, and it defeats the direction of any check that assumes lower is better. `Golf-DQ-100`
reports the eleven events by what the storage shows rather than by the tournament they belong to,
under `TOTAL_PAR_HOLDS_THE_ROUND_TOTAL_NOT_THE_SCORE`.

**The cut is not always after two rounds, and nothing records when it fell.** Found 2026-08-14
while writing `Golf-DQ-102` and `Golf-DQ-103`. Four tournaments cut after 54 holes, so their
eliminated players correctly hold a third round: AT&T Pebble Beach Pro-Am, The American Express,
Alfred Dunhill Links Championship and Office Depot Championship 2005. Measured, the shape reaches
the field - 87 of 156 at The American Express 2024, 106 of 168 at Alfred Dunhill Links 2021, 66
of 144 at Office Depot 2005 - against one to three cards where a flag is simply wrong. 161 events
carry it and 6657 cards, which is why both checks read the field share rather than the card.

The same structure is the honest discriminator and a count is not: an event in which any card
flagged `made_cut = no` holds a third round did not cut after two, so a 36-hole comparison is the
wrong comparison there whatever its size. `Golf-DQ-102` excludes those events on that test.

**`mdf` sits beside `made_cut = yes` twelve times out of thirteen, and the exceptions cluster.**
Measured 2026-08-14 inside the client boundary: 1429 `mdf` cards carry the flag `yes` and 118
carry `no`, the second group concentrated in 14 events rather than scattered across the sport. The
convention is `yes`, which follows from what the comment means - made the cut, did not finish - so
the 118 are the defect. `Golf-DQ-103` reports them.

**A withdrawal or a disqualification legitimately breaks the cut ordering.** 531 cards inside the
boundary sit on the wrong side of their event's cut line and end `wd`, `dq`, `rtd`, `dns`, `nr` or
`n/r`. A player who withdraws after a good Friday is flagged as not having made the cut whatever
they scored, so the comment explains the card and no check should. This is the same reading that
keeps `wd` out of `RESULT_COMMENT_NO_RESULT_LIST` above, applied to a different question.

**The stroke fields hold three populations, and only one of them is strokes.** Measured
2026-08-14 over 1097936 numeric values in `31`–`35` inside the boundary: 1088665 sit between 59
and 119, which is the sport; 3934 sit under 55, which is Modified Stableford points in a stroke
field; 2976 are `0`; 51 sit between 55 and 58, low but reachable; and 310 sit above 120, up to
224, which is a raw total written into a round.

The zeros are read two different ways by design, and that is the question changing rather than an
inconsistency. Where a statement does arithmetic on strokes - `Golf-DQ-102`, `Golf-DQ-104` - a
zero is absent, because eighteen holes are not played in no strokes. Where a statement asks
whether the field was filled in at all - `Golf-DQ-106` - a zero is present, because somebody wrote
it, and a Stableford round worth no points is a real round.

**A gender that disagrees with its stage is a defect, and a mixed field is not one.** Decided by
the user 2026-08-14, which settles the question `Golf-DQ-075` and `Golf-DQ-073` were held open on.
A woman may not stand in a men's event, and where the two disagree something has to be corrected
rather than tolerated. A team holding a man and a woman is a different thing and is not this rule:
such an event carries `mixed` on its stage, which is a third value and not a disagreement with
either.

That distinction is already what the two checks do, confirmed by measurement the same day. Of the
1680 entries inside the client boundary whose participant gender differs from their stage's, 1540
sit on a stage recorded `mixed` and are correct - 12 stroke play events holding 528 women and 788
men, and 28 match play events holding 112 of each. The two checks exclude them and report the
remaining 140.

What that leaves is two shapes, and neither is a woman quietly playing well. 105 entries over 29
participants are national and continental team entities - `England`, `France`, `Australia`,
`Denmark` - stored once with one gender and entered under both, which is one record needing a
second. 35 more are individual people, and three of them recur across both disciplines with a
gender the name contradicts. Michelle Wie West playing a men's stroke play event is the only
entry in the population that describes something that happened, and under this decision the stage
that admitted her is what is wrong rather than her.

**An amateur is paid nothing, and the finishing order does not care.** Found 2026-08-14 while
writing `Golf-DQ-107`. 24 cards inside the boundary carry a prize of zero beside a place that
would have been paid, across thirteen 2026 LPGA events; Kiara Romero was placed sixth in the US
Women's Open with nothing beside a paid seventh. The Rules of Amateur Status forbid accepting the
money, so the zero is correct and the rank is correct. 123 participants inside the boundary hold
only zero-prize cards and 229 hold both, the second group being professionals who missed cuts.
Any check reading `540 Prize money` against a placing has to compare only cards actually paid.

<!-- MANUAL PASTE ZONE: 3 EVENT RESULTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Incident types

Golf stores no incidents. `GLOBAL-DISCOVERY-008` returns no active incident row for the sport.
This is a structural absence rather than an empty population: the sport has no in-play event
the incident layer models.

<!-- MANUAL PASTE ZONE: 3 INCIDENTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Scope types and data types

**The scope layer holds the round of golf hole by hole, and it is the sport's largest
storage.** Five active scope types, from `GLOBAL-DISCOVERY-009`:

| scope_typeFK | Name | Containers |
|---:|---|---:|
| 305 | final_result | 2721 |
| 462 | round1 | 2028 |
| 463 | round2 | 2024 |
| 464 | round3 | 2010 |
| 465 | round4 | 1595 |

Under them, `scope_result` carries 29653897 active values across 104 distinct
`scope_data_typeFK` values and 324 scope-type/data-type combinations. The families are:

- `strokes1`–`strokes28` (302–361): strokes taken at each hole;
- `par1`–`par30` (320–351): the par of each hole;
- `mpscore1`–`mpscore28` (364–391): the match-play state hole by hole;
- `tee_time` (338), `venueFK` (396) and `starting_hole` (397).

Numbering past eighteen is real and used: `par19`–`par24` and `strokes19`–`strokes27` all carry
values, which is how the sport records extra holes. `mpscore` running to 28 alongside `strokes`
confirms that match play is scored hole by hole in the same layer as stroke play rather than in
a structure of its own.

`GLOBAL-DISCOVERY-010` could not be run as written - it timed out at 180 seconds, and again
when its three storage layers were split apart. What ran is the `scope_result` layer with the
two reference joins and the value samples removed, which is where the numbers above come from.
Two things are therefore not yet measured: the per-combination sample values, and the
`event_scope_detail` and `lineup_scope_result` layers. `lineup_scope_result` is expected to be
empty because the sport writes no lineups, but that is an expectation and not a measurement.

**`scope_data_typeFK = 0` carries 206 values and has no row in `scope_data_type`.** It occurs
under `round1` (2 values), `round2` (35), `round3` (2) and `round4` (167) and never under
`final_result`. An unmapped data type is the scope-layer counterpart of the unmapped
`round_typeFK = 0` recorded below, and neither is a count that will resolve itself.

A further set of `scope_data_typeFK` values under Golf's scopes resolves to names belonging to
other sports' vocabularies - `penalty_stroke_9` (415), `clock_penalty_4` (489),
`clock_penalty_6` (491), `clock_penalty_7` (492), `clock_penalty_15` (500) - alongside
`hole_number_for_stroke_19` through `hole_number_for_stroke_27` (424–426, 457, 459, 461, 474,
476, 747), which do read as golf. Whether the penalty names are a shared generic id or a
misfiled value is an open question below.

**How the layer divides, measured 2026-08-14 inside the client boundary.** `scope_result` holds
21830092 active values under the five types, and 99.1 per cent of them are the hole-by-hole
rounds:

| scope_typeFK | Name | Active values | Share |
|---:|---|---:|---:|
| 462 | round1 | 7005919 | 32.1% |
| 463 | round2 | 6940111 | 31.8% |
| 464 | round3 | 4182206 | 19.2% |
| 465 | round4 | 3515383 | 16.1% |
| 305 | final_result | 186509 | 0.9% |

That proportion is why `GLOBAL-DQ-102` cannot be run for this sport and why `Golf-DQ-097`
replaces it over `final_result` alone: the four round types are the hole-by-hole layer this file
parked on 2026-08-12, so auditing them here would take that decision sideways through a check.
The cost is real as well as procedural - counting the rows takes 140 seconds, and grouping them
by type exhausted the server's temporary disk outright.

`Golf-DQ-097` returns clean, and the zero was checked rather than assumed: all 186509
`final_result` values resolve to an event participant of their own event, none to another
event's and none to a participant row that is missing. What is not covered is stated plainly - a
value under `round1` to `round4` naming another event's competitor is reported by nothing today.

**The two layers this sweep had not measured are now measured.** `event_scope_detail` holds
nothing for Golf. `lineup_scope_result` holds 128 active values, which was not the expectation:
the sport writes no lineup row anywhere, so the layer was expected to be empty by construction.

Every one of the 128 names a lineup place belonging to another sport. They sit on three golf
events, all on 8 and 9 March 2018, and the places they name are in an American Football game and
three football matches - Mississippi State against South Carolina, Lommel against Roeselare,
Maritimo against Rio Ave, Sporting Gijon against Leganes. Two of the three events are under Korn
Ferry Tour and Champions Tour and fall outside the client boundary; the third, the South African
Women's Open under Ladies European Tour, is inside it and holds 36 of them. `Golf-DQ-099` reports
that one and audits exactly one event.

A cross-sport reference that resolves rather than failing is the same shape as the truncated
Event id list, in a different layer. Both succeed at attaching one sport's value to another
sport's fixture, which is what makes them worse than a broken reference. `Golf-DQ-098` reported
the other layer until it was deprecated on 2026-08-20.

<!-- MANUAL PASTE ZONE: 3 SCOPES — insert approved additions immediately before this marker; do not move or delete it. -->

## Properties

Golf's property layer is the busiest of any sport documented here, and much of the sport's
competition context lives in it rather than in a typed column.

At `tournament_stage`: `Par` (4643), `Length` (4601), `Venue` (5176), `Rounds` (5458),
`Cut` (2455) and `ProjectedCut` (1032), `Prize` (3890) and `Currency` (3893),
`tee_time_round_1`–`tee_time_round_4` (2763, 2605, 2487, 2052), `Type` (5459, holding values
such as `Greensomes Matchplay`), `Tourname` (82, holding `Major`), `StatusComment` (253),
`Live`, `status`, `startDate`, `endDate`.

At `event`: `Type` (19434, holding `Match Play`), `Round` (19363), `Live` (17663),
`gameType` (11652, holding values such as `Doubles 3`), `current_hole` (5945), `Rounds` (4952),
`last_updated` (4504), `discipline` (332), `EventTypeName` (107), `Verified` (13),
`currentRound`, `playoffStarted`, `startDelayed`, `GameStarted`, `GameEnded`,
`SecondHalfEnded`, `medal_related` (4), `EndDate` (911), `Tourname` (9).

At `participant`: `status` (19826), `professional_status` (18921), `date_of_birth` (9765),
`place_of_birth` (4125), `height` (3474), `weight` (2562), `IsNationalTeam` (63),
`position` (4).

Three of these carry values that do not match their own name and are recorded as observed
rather than counted: `place_of_birth` samples as `1991-04-11`, a date in a place field;
`position` samples as `Defensive Line (DL)`, an American-football position on a golf
participant; `tee_time_round_4` samples as `---`.

**`Par` is the one property with a measured value distribution, because a check reads it.**
Sport-wide on 2026-08-14 it holds `72` on 2769 stages, `71` on 1123, `70` on 576, `73` on 143 and
`69` on 4. Those five are course pars and account for 4615 of the 4644 stages that carry the
property.

The other 29 are not. `22` and `24` on ten stages each, `27` on two, and `142`, `45`, `54` and
`65` on one apiece, with three stages holding an empty string. `142` is the only one whose origin
is settled: at PGA Grand Slam of Golf the field's own cards imply 71, so 142 is the par of two
rounds written into a field that holds the par of one. The rest are recorded as observed.

The property is not decoration. `36 Par` is measured against it - the arithmetic recorded under
"Event result types" cannot be checked on a stage that does not carry it, and 592 events holding
43282 participations are in exactly that position.

**`current_hole` is `Thru`, it belongs to match play alone, and it counts holes rather than
reaching 18.** Measured 2026-08-14 across every discipline and status in the sport. 4860 of 12993
finished match play events carry it; **no stroke play event carries it in any status**, which
makes it a property scoped to the discipline that needs it rather than one missing from 3306
stroke play events. This corrects the note taken from the Builder on 2026-08-13, which recorded it
as written for both.

Its value follows the match rather than the round. A match won `2&1` ended two holes up with one
to play, so 17 holes were played; `3&2` ends after 16. Confirmed: of 2936 finished matches holding
both an `X&Y` score and a numeric `current_hole`, 2797 hold exactly `18 − Y`. A rule asserting 18
would have called almost all of them wrong.

Above 18 is also correct. A match tied after eighteen goes to sudden death, so 19 and 20 are the
19th and 20th holes, and the amateur championships play 36-hole finals, so 36 is one match. What
cannot happen is the other direction - a final margin or an `A/S` beside fewer than eighteen
holes. `Golf-DQ-108` is written on exactly that split.

One population inside it is unresolved and is recorded rather than assumed: 60 events read exactly
6 holes played beside a final margin, on `European Tour 1` in clusters of a tournament week across
2010, 2017, 2018, 2019 and 2022. A value frozen mid-match fits the Builder's behaviour; a
short-form match play format would look identical. Not confirmed either way.

<!-- MANUAL PASTE ZONE: 3 PROPERTIES — insert approved additions immediately before this marker; do not move or delete it. -->

## Generic relations and disciplines

**Golf contests two disciplines and both are large.** `object_discipline` attaches
`629 Stroke Play` to 5142 events and `630 Match Play` to 14292, and the same split reaches the
statistic layer: 3196 statistics carry Stroke Play and 248 carry Match Play.

The two are not separate competitions. Thirteen templates carry both, and several carry them in
comparable volume - `429 European Tour 1` holds 984 Stroke Play events and 955 Match Play,
`430 European Tour and PGA Tour 1` holds 180 and 1653, `436 LPGA Tour 1` holds 653 and 1099.
This is what makes the sport `Hybrid` under `DATABASE.md` `DB-SEM-015` rather than two sports
sharing an id, and it is measured from the templates rather than asserted.

`GLOBAL-DISCOVERY-032` gives the full matrix, and the first and last years each combination
occurs: Stroke Play male athlete 3646 events over 21 templates from 2001, Match Play male
athlete 7474 over 11 from 2004, Match Play team male 676 and female 611 from 2004, Stroke Play
mixed athlete 28 from 2018, Match Play mixed athlete 56 in 2018 alone.

**The discipline is stored twice for a small minority of events, and the two copies agree.** The
`object_discipline` relation reaches 19434 events; the `discipline` event property is written on
332. `GLOBAL-DQ-109` audits the 329 of those whose value resolves to an active discipline through
both paths and reports no disagreement, so the property is a partial duplicate of the relation
rather than a competing or stale record of it. The relation remains the path a Golf statement
should read, because it is the one that covers the sport.

The claim also holds upward and sideways. `GLOBAL-DQ-100` finds no Comp.Rank claiming a
discipline that no event under its own tournament contested, over 3444 statistics, and
`GLOBAL-DQ-110` finds none contradicting the events it names through the `1471` Event id config,
over 3194. Together with the stage measurement - no stage mixes disciplines, 5441 of 5441 - the
discipline layer is the one part of this sport that is internally consistent everywhere it was
measured.

<!-- MANUAL PASTE ZONE: 3 GENERIC RELATIONS AND DISCIPLINES — insert approved additions immediately before this marker; do not move or delete it. -->

## Statistics

| statistic_typeFK | Owner type | Participant shard | Data shard | Fields/config | Evidence |
|---:|---:|---:|---:|---|---|
| 11 | 3 (tournament) | 11 | 11 | data `1270`, `1271`, `1277`, `1476`; config `1463`, `1464`, `1470`, `1471` | 3491 statistics |
| 11 | 4 (tournament_stage) | not probed | not probed | not checked | 5 statistics |

`SHARD_ID = 11` is confirmed by probing, not derived: `GLOBAL-DISCOVERY-016` found the sport's
statistics in `statistic_participants11`, which is what `DATABASE.md` `DB-SEM-006` requires.

**Golf's Comp.Rank carries a `Par` field no other documented sport uses.** Of the 42 data types
declared for statistic type 11, Golf populates four: `1476 Par` (341045 values over 3023
statistics), `1270 Rank` (336054 over 3239), `1277 Medal` (315 over 99) and `1271 Points`
(58 over 29). `Par` is therefore not a minor field here - it is used almost as widely as Rank,
and any statistic-layer check that assumes Points is the sport's quantity will read the wrong
column.

Confirmed 2026-08-13: `PRECISION_DATA_TYPE_LIST` is `1476 Par` and stays there. **Golf has no
Points**, whatever the 58 values under `1271` are, so pointing a precision check at that field
would aim it at a column the sport does not keep. That `1476` holds no decimal today is not a
reason to move it: the check guards against a decimal arriving in a field that stores whole
strokes against par, and a check with nothing to report is the check working.

Config is complete and uniform: `1463 Start date`, `1464 End date` and `1470 Gender` on 3445
statistics each, `1471 Event id` on 3444. The one statistic missing an Event id is a gap of
exactly one row against three complete fields.

Statistic names carry the discipline in the text - `100th Open de France - Competition Rank
(stroke play)` - which is a naming convention rather than a typed relation, and the typed
relation exists separately through `object_discipline` on the statistic.

**Five statistics sit at `tournament_stage` level rather than at `tournament`.** They are the
minority pair `GLOBAL-DISCOVERY-015` reported beside the main one and the run did not use them.
Their shard, fields and purpose are not checked.

**The `1270 Rank` field carries two defects that look like one.** Measured 2026-08-14 over the
3125 Comp.Rank statistics that hold a rank at all.

Eighty-nine of them store a rank above any place golf awards. The values run to 164 and then
jump straight to `999` and `9999`, with nothing in between, so these are markers written into
the numeric field rather than places anybody finished in - a field of 157 where 74 competitors
all hold `999`. `Golf-DQ-094` reports them against `RANK_MAX_PLAUSIBLE`, which is 250 for this
sport, and does not excuse a marker that carries a Comment: a value that was never a place is
wrong whether or not somebody explained it. `GLOBAL-DQ-036` asks the same question of the event
result layer and cannot see this one; `result` and `statistic_data11` are separate layers.

Two hundred and eighty-three store ranks larger than the field they hold, markers excluded - a
statistic holding 81 competitors and ranking one of them 151, and in 163 cases a top rank more
than three times the count. The rank is evidence of how many competitors there were and the
statistic is the record of who they were, so the two disagreeing means the import stopped early.
`Golf-DQ-095` reports it, and leaves alone a rank that is merely adjacent to the count, because
ties legitimately push the last place past it: a tie for 1st in a field of 3 ends at rank 3 with
no rank 2.

**Both are historical.** Of the 369 statistics the two checks report between them, 368 are from
2004 to 2014 and one is from 2016; none is later. That is why `Golf-DQ-095` is recorded as
`Monitor` in `SPORTS/params.json` rather than actionable - the volume is a legacy import, and the
invariant is kept for what arrives tomorrow rather than for what is on the list today.

**Every competitor who played is in the Comp.Rank that covers the event.** Measured 2026-08-14
over 345930 pairs of event and competitor across 3050 events, and not one of them is missing from
the statistic covering it. `Golf-DQ-096` asserts it and returns clean.

The zero is the sport, not the check. The same invariant is broken elsewhere - Artistic
Gymnastics reports 52 events, BMX 9, Modern Pentathlon 7, Triathlon 3 - and the anti-join here
demonstrably matches, since all 345930 pairs resolve rather than none. What Golf does have is
`Golf-DQ-048`, which reports 283 Final events that no Comp.Rank names at all: the sport's gap is
whole events with no ranking rather than rankings that lose part of their field.

`GLOBAL-DQ-042` cannot be run for this sport and this statement replaces it. That template asks,
for each competitor of each event, whether the covering statistic lists them, which is about half
a million questions here because the Final round type is `225 Main Phase` - every tournament event
- and the fields run to 250. It returns Artistic Gymnastics in 4.6 seconds and times out on Golf.
Asking it once instead, as two sets subtracted from one another, takes 39.

**167 Comp.Rank statistics have a truncated Event id list, and 154 of them look intact.**
Measured 2026-08-14. The column stops at 255 characters and the sport's values pile up against
that number rather than approaching it: 167 sit at exactly 255, five at 239, one at 231, and
nothing at all between 240 and 254. `DATABASE.md` `DB-SEM-011` owns the fact. `Golf-DQ-098`
reported it and separated the two shapes, because they are found differently and repaired the
same way; it was deprecated on 2026-08-20 and nothing reports it now.

The thirteen with six-digit event ids are cut inside a number. 255 characters hold 36 of them
and three characters of the 37th, so the value ends in a fragment - `412`, `135`, `455`, `622`,
`794`, `988`, `1353` - and every one of those fragments is a valid event id belonging to a
football match played in 2000. `Golf-DQ-057` reports these as
`EVENT_ID_LIST_NOT_ALL_UNDER_TOURNAMENT`, which is how the whole defect was found.

The hundred and fifty-four with seven-digit ids are cut on a comma. 255 characters hold exactly
32 of them, the value reads as a complete list, it resolves cleanly against the tournament, and
nothing but its length says the events after the 32nd were ever meant to be named. Nothing else
in the package can see them.

The consequence is the same in both: the statistic's event scope stops early, so every check
that reads which events a Comp.Rank covers is reading a short list. The extra consequence in the
first thirteen is that the list also names an event from another sport, and a join on it
succeeds. This is a schema defect rather than a data one - correcting the values without
widening the column would truncate them again on the next write.

**All 167 are match play, and that is the mechanism rather than a coincidence.** Measured
2026-08-17 over the sport's 3441 rankings: **every one of the 3179 that says stroke play in its
name holds exactly one event id**, without a single exception, so a stroke play list is 6 or 7
characters and cannot reach a limit of 255. The 243 that say match play hold between 1 and 37,
because match play is a bracket and each match is its own event. **167 of those 243 are cut.** The
76 that are not are the small brackets, and nothing protects them beyond their size.

**The true list is recoverable by rule, which is worth recording before anybody assumes it is
lost.** Measured 2026-08-17: the ids that survived the cut span **exactly one tournament stage in
all 167 cases**, and that stage's name is the ranking's own name - `British Boys Amateur
Championship - Match Play` for the ranking of the same name. So a ranking's true event list is
every event of the stage its survivors belong to. Those stages hold **32 to 120 events** against
the 32 the list names, and rebuilding the largest needs **959 characters**. The rule survived the
test rather than being proven: what would disprove it is a ranking whose stage holds events it
should not cover, and that cannot be checked from the database, because the record of where a
ranking ends lived in the field that was cut.

**Applied to all 167 the rule returns 6288 events, a median of 38 per ranking, and it exposes one
false positive the check cannot avoid.** Statistic `336075`, `The Queens` 2016, gains nothing: its
stage holds exactly 32 events, its stored list holds exactly 32, and all 32 resolve. Thirty-two
seven-digit ids plus thirty-one commas come to exactly 255 characters, so **that value reached the
limit by arithmetic rather than by being cut**, and there is nothing to repair in it. From the
stored value alone a list cut at 255 cannot be told from one that is 255 characters long on its
own, so `Golf-DQ-098` reported 167 where 166 were real. Seven further rankings gain only two events
each — `The Presidents Cup` 2005, 2007 and 2009, `The Queens` 2015 and 2017, `International Crown`
2016 and `European Boys' Team Championship Flight C` 2010 — and those are genuine, their stages
holding 34 or 35 against the 32 stored. `output/Golf-DQ-098-rebuild.sql` carries the query and its
own reading notes.

**`Golf-DQ-098` was deprecated on 2026-08-20, and this records what that costs rather than
justifying it.** The decision was that the defect cannot be repaired from this side - widening the
column is somebody else's change - so a check reporting 167 rows on every run until that happens
was not worth the space on the board. The evidence above was gathered and stays; only the check
that reported it is gone.

What is given up is specific. `Golf-DQ-057` does not take over: measured 2026-08-17, it reports
**13 of the 13** cut inside a number and **0 of the 154** cut on a comma, because those resolve
perfectly. So the 154 are now invisible to the whole package. That asymmetry is also a trap in
the order of repair - fixing the thirteen visible fragments alone takes `Golf-DQ-057` to nearly
zero and makes the defect look settled while 154 stand untouched.

The second loss is forward-looking. Once the column is widened and the values rewritten the check
would have returned zero, and it was the only thing here that could have seen the column narrow
again. Nothing watches that now. `output/golf_event_id_list_truncated_for_IT.sql` carries the
three statements the defect was handed to IT with, and re-running them by hand is what replaces
the check until the schema changes.

**It is not promoted to a GLOBAL template, and the reason is a measurement rather than a
judgement about how general the defect is.** Measured across every sport on the server
2026-08-17: Golf holds 167 and **Freestyle Skiing holds 64**, and no other sport holds one. None
of the nine sports documented here except Golf has a single case, so a template would have one
instantiation. The statement carries nothing Golf-specific and can be promoted in an hour on the
day a sport with brackets is opened. **Freestyle Skiing held 49 on 2026-08-14 and 64 on
2026-08-17**, so the population grows as data arrives rather than sitting still in the archive.

**The five `tournament_stage`-owned statistics are Comp.Rank at the wrong owner level.**
Measured 2026-08-14: all five carry `statistic_typeFK = 11` and `object_typeFK = 4`, where the
sport's confirmed owner is the tournament at `object_typeFK = 3`. They are the Hero Cup 2023,
the International Crown Playoffs 2023 and the Bank of Hope LPGA of 2021, 2022 and 2023.

They are not a separate population with its own purpose, which is what the open question asked.
They are the same object attached one level down, and `GLOBAL-DQ-106` is the template that
asserts the owner level.

<!-- MANUAL PASTE ZONE: 3 STATISTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Reference values

`GLOBAL-DISCOVERY-014` returns one row per stage for all 5464 stages, so the sport stores stage
reference data broadly rather than sparsely. The stage-level `object_relation` pair `4 → 151`
covers 5455 of them against just 2 distinct related objects, and the statistic-level `83 → 33`
covers 3444 against 65. Which reference each resolves to is not yet read.

<!-- MANUAL PASTE ZONE: 3 REFERENCE VALUES — insert approved additions immediately before this marker; do not move or delete it. -->

## Event and round representation

Six status combinations, from `GLOBAL-DISCOVERY-003`: `finished`/`6 Finished` on 18416 events,
`finished`/`260 Finished after play-off` on 458, `cancelled`/`106 Cancelled` on 208,
`notstarted`/`1 Not started` on 181, `finished`/`259 Halved` on 179, and
`inprogress`/`101 4th Round Started` on 1.

**`259 Halved` is a match-play status and confirms the hybrid model from a second direction.**
A halved match is a drawn head-to-head result, a state a listing sport has no way to express.

Thirty-two `event.round_typeFK` values are in use, from `GLOBAL-DISCOVERY-018`. The busiest is
`225 Main Phase` on 5020 events, which is where stroke play sits. The rest are the match-play
bracket - `176 Quarter Finals` (3656), `178 Semi Finals` (953), `173 Final` (529),
`188 1/32` (621), `185 1/16` (384), `184 1/8` (336), `186 Small Final` (36) - together with two
separate runs of numbered rounds, `38`–`43` named `1`…`6` (2723, 868, 685, 383, 457, 6) and
`89`–`92` named `1`…`4` (634, 475, 243, 48), the placement rounds `264 5/6` (465),
`263 7/8` (413), `262 5/8` (6), `22 5/6` (2), `23 7/8` (1), and `304`/`305 Playoff` (140, 4).

**`225 Main Phase` is this sport's final round, and `9`/`173 Final` are not.** The distinction
matters because Golf is Hybrid and the two words mean different things in its two disciplines.
Main Phase is where a stroke-play field is classified as a whole: it covers 3186 of the 3440
events a Comp.Rank names through its Event id config, and it holds every one of the sport's 18
medal results, six gold, six silver and six bronze across six events. `173 Final` is a match
between two players; it is named by a Comp.Rank five times in the sport and awards no medal
anywhere. `FINAL_ROUND_TYPE_LIST` is therefore `225` alone, which is unlike every other sport
documented here, and the reason is the model rather than the data being thin.

Including `9` and `173` would not widen the audit, it would make three checks assert something
false - that a two-player match owes a full medal set. The match-play finals are not left
unaudited by the choice: they are ordinary events and every check that does not key on the final
round reads them, which is most of the catalogue.

**The duplicate key drops the event name and keeps the calendar day, and both halves were
measured rather than assumed.** Golf names its match-play events after the competitors -
`Aaron Baddeley-Tiger Woods` - which is the condition `GLOBAL-DQ-062` states for
`DUPLICATE_KEY_INCLUDES_EVENT_NAME = 0`: the name repeats the participant set in an order the
data does not fix, so it splits `A-B` from `B-A` that the participant key has already matched.
Of the 63 groups of match-play events sharing a stage, a calendar day and a participant set, 59
already carry an identical name, so dropping the name costs nothing; the remaining 4 are exactly
the groups a name key would hide.

`DUPLICATE_KEY_USES_CALENDAR_DAY` is `1`. Twenty-three of those 63 groups carry different
timestamps on the same day for the same pairing, and two golfers do not play two separate matches
in a day - that is a re-import arriving with a shifted start, which a timestamp key never groups
at all and therefore never reports.

**Round type names are not unique identifiers here, the same way they are not in BMX.** Quarter
Finals occurs as both `176` and `3`, Semi Finals as `178` and `2`, Final as `173` and `9`,
Small Final as `186` and `19`, `1/8` as `184` and `4`, Playoff as `304` and `305`, and the
numbered rounds `1`…`4` occur twice over under two different id runs. A statement must reference
`round_typeFK` by id and never by name.

**`round_typeFK = 0` is carried by 80 events and resolves to no `round_type` row**, and
`1 no round` by a further 79. The first is unmapped, the second is a named round type meaning
the absence of one; they are different states and are not interchangeable.

**Golf stores the knockout flag on the wrong side of that pair for every elimination round it
uses, and `Golf-DQ-059` and `Golf-DQ-066` are one finding read at two grains rather than two
findings.** Measured 2026-08-19: eight round types are wrong and 6000 events sit on them -
`176 Quarter Finals` (3535), `178 Semi Finals` (927), `188 1/32` (621), `185 1/16` (384),
`184 1/8` (336), `304 Playoff` (140) and `186 Small Final` (29) all carry `knockout = no` where
the name is an elimination round, and `9 Final` carries `yes` where this sport's Final is a
stroke-play round nobody leaves. The `event_count` column of the eight summary rows sums to
exactly the 6000 the detail reports, and neither statement names a round type the other misses.

The two are a summary and its detail, not a duplicate. `Golf-DQ-059` reports one row per round
type, which is where the defect lives and where the decision is made; `Golf-DQ-066` reports one
row per event, which is where it is repaired, because `round_type` is shared by every sport and
its flag cannot be corrected without moving rounds in sports nobody here has looked at. What is
changed is the events, onto the id `correct_round_type_id` names - and that id is the other half
of each pair this section already records: `176`→`3`, `178`→`2`, `188`→`6`, `185`→`5`,
`184`→`4`, `304`→`305`, `186`→`19`, `9`→`173`.

Both stay `Actionable`. Every row names something correctable and the statement hands over the
id to correct it to, so the population is meant to reach zero; `Monitor` would say the opposite,
and saying it of either row would tell a reviewer to stop driving down 6000 events that have a
known fix. Read `Golf-DQ-059` first - eight rows carry the whole decision - and pull
`Golf-DQ-066` as the worklist once the decision is made.

<!-- MANUAL PASTE ZONE: 3 EVENT AND ROUND REPRESENTATION — insert approved additions immediately before this marker; do not move or delete it. -->

## Scope

**UK Sport does not take twenty of the sport's tournament templates, and every Golf check
excludes them.** Recorded 2026-08-13, replacing the opposite conclusion this file carried until
that day — that the client took the sport whole. The ids live in `SPORTS/params.json` under
`OUT_OF_SCOPE_TEMPLATE_ID_LIST` and are written into the statements themselves rather than
applied at run time, because the statement is what PowerBI executes; `POWERBI.md` owns that
contract.

| Out of scope | Templates |
|---|---|
| Professional tours below the top flight | `9692 Challenge Tour 1`, `9418 Champions Tour 1`, `9633 Korn Ferry Tour`, `9691 Asian Tour 1`, `9693 Sunshine Tour 1`, `9201 PGA Tour of Australasia 1` |
| Breakaway tour | `10305 LIV Golf` |
| Team match-play cups | `432 Ryder Cup 1`, `438` and `435 Solheim Cup 1`, `9142 Solheim Cup`, `10341 Presidents Cup`, `9645 Walker Cup 1` |
| Amateur world team championships | `11528 Eisenhower Trophy`, `11529 Espirito Santo Trophy` |
| Short-form and test data | `9831 GolfSixes`, `10333 GolfSixes alt test`, `10334 GolfSixes test kris`, `9932 Mixed`, `12649 TEST` |

Four of them — `435`, `9142`, `10333`, `10334` — are already `del = 'yes'` and carry nothing.
They are listed anyway, so the boundary states a decision rather than the current state of a
flag.

**Deferred, not unsupported.** These competitions will be looked at; they are not being looked at
now. The data is there, the sport fills it, and every check would run against it unchanged — the
exclusion is a list of ids, so the day the boundary moves the list moves and nothing else does.
`README.md` owns why the client is a boundary of its own.

What it costs, measured on 2026-08-13:

| Layer | In scope | Out | Out |
|---|---|---|---|
| Events | 16,544 | 2,899 | 14.9% |
| Event participants | 393,722 | 191,441 | **32.7%** |
| Comp.Rank statistics | 3,440 | 51 | 1.5% |
| Comp.Rank participants | 355,654 | 3,690 | 1.0% |

The second row is the one to remember: a seventh of the events but a third of the participants,
because a tour field is 144 players and a cup is 24. A participant-level check loses a third of
its population and a Comp.Rank check loses almost nothing.

**One check the boundary does not reach.** `Golf-DQ-036` (`GLOBAL-DQ-009`) audits people the
sport registry knows and no participation path reaches. The registry has no template relation —
that is precisely what it audits — so there is nothing to exclude, and its 742 findings over
20,638 registered people stay sport-wide. A person who competed only under an excluded template
is not among them: they have participation, and this check reports having none.

## Confirmed sport-specific storage semantics

**`-TemplateIds` is not the scope mechanism for this sport.** It is how Soccer keeps its
statements affordable; Golf's boundary is in the statements and its remaining 21 live templates
are read whole, so narrowing further here would not be a scope decision but a hole in the audit.
What is left for cost is the rest of
`WORKFLOW.md`'s cost rule, and it has to do all the work on the largest sport in the package:
a half-open `startdate` window, a primary-key range, one round type or one result type per
execution, `EXISTS` in place of `JOIN` plus `DISTINCT`, and no `COUNT(DISTINCT)` where a plain
`COUNT(*)` answers the question.

This is measured rather than cautionary. Two of the 24 catalogue statements that ran against
Golf failed on cost alone - `GLOBAL-DISCOVERY-007` exhausted the server's temporary space and
`GLOBAL-DISCOVERY-010` timed out twice - and both are ordinary statements that every other sport
runs without trouble. A Golf DQ statement written to the shape that works on Curling should be
expected to fail here until it is sized.

**A medal event is identified by its template, not by its round type, and no parameter can say
so.** Every one of the sport's 18 medal results sits in round type `225 Main Phase`, which is
also the round every stroke-play tournament on every professional tour uses. Only
`9600`/`9601 Summer Olympics` awards a medal, in 6 events; the other 5014 events carrying that
round type award none.

`MEDAL_ROUND_TYPE_LIST = 225` is therefore correct in one direction and false in the other. Read
as "a medal may only appear on these rounds" it holds, and `GLOBAL-DQ-039` and `GLOBAL-DQ-073`
both return clean on it. Read as "these rounds award medals" it fails, and `GLOBAL-DQ-037` and
`GLOBAL-DQ-038` report 4751 and 4764 of 4768 - the whole population. Both are `Not applicable`
here for that reason, and the asymmetry is the sport's, not the templates'.

This is a consequence of the client scope reaching well past the Games. The twenty templates it
excludes are cups and secondary tours, not the stroke-play tours that hold `225 Main Phase`, so
the asymmetry survives the boundary unchanged: a sport narrowed to its Games templates alone
would have a medal round that means what the parameter assumes, and this one still does not.

**The template can say it, and on 2026-08-13 it was written down.** The sentence above holds
about round types and was too broad about parameters: what no *round-type* list can express, a
template list can. Thirteen templates award medals in this sport and were confirmed by decision,
not measured - `9600` and `9601 Summer Olympics`, `11498 Summer Youth Olympics`,
`9779 European Championships 1`, `10327 Pan American Games`, `10328 Asian Games`,
`10537`/`10538 Pacific Games`, `11532 Southeast Asian Games`, `11507 British Boys Amateur
Championship`, `11524 British Girls Amateur Championship`, `11525 European Girls' Team
Championship`, `11526 European Boys' Team Championship`. Every other template awards none.

`MEDAL_TEMPLATE_ID_LIST` records them and `GLOBAL-DQ-125` asserts the negative half of the rule:
a Comp.Rank outside those templates holds no medal. It reports 43 statistics over 3240, holding
130 medals between them, from three templates:

| Template | Comp.Rank holding medals |
|---|---:|
| `430 European Tour and PGA Tour 1` | 21 |
| `11528 Eisenhower Trophy` | 11 |
| `11529 Espirito Santo Trophy` | 11 |

`430` is a professional tour and the finding is the plain one. The two trophies are the World
Amateur Team Championships and sit beside four amateur championships that *are* on the list, so
whether they were meant to be excluded is a question for the reviewer rather than a defect this
file should assert either way. One further oddity is visible in the same rows and is not what
the check was looking for: statistics named `Espirito Santo Trophy - Competition Rank` are filed
under template `11528 Eisenhower Trophy`.

Five of the thirteen hold no medal at all today - `11525`, `11526`, `9779`, `10537`, `10538`.
The rule as recorded is one-directional, so that is not a finding for `GLOBAL-DQ-125`. It is a
finding for the check on the other side of the list, which is where it now lands.

**`Golf-DQ-085` is `GLOBAL-DQ-026` narrowed to those thirteen templates, and `Golf-DQ-044` is
deprecated.** The global template audits every Comp.Rank a sport holds, and Golf's are tournament
classifications: it reported 3286 of 3491, almost all of them `No_Medals_At_All` on competitions
that award none. Narrowing it inside the template would have taken the check from the six other
sports that run it and declare no medal-template list, so the narrowing lives in
`POWERBI_QUERIES/Golf.sql` and carries Golf's values written out. The two must be kept the same:
`GLOBAL-DQ-125` asserts no medal outside the thirteen, `Golf-DQ-085` audits the medal set inside
them, and they are only coherent while they read the same list.

It reports 152 of 251, remeasured 2026-08-21 after the client's 2004 boundary was applied, and
the composition is what makes it readable where 3286 of 3491 was not:

| What it found | Rows |
|---|---:|
| `No_Medals_At_All` - a medal template awarding none | 111 |
| `Medal_Set_Unreadable_Without_Rank` - no Rank to compare the medals with | 32 |
| `Medal_Missing_For_Shared_Place` | 5 |
| `Duplicate_Bronze` | 2 |
| `Duplicate_Gold_With_Silver_Present` | 1 |
| `Duplicate_Silver_With_Bronze_Present` | 1 |

The two large branches changed places, and it is worth saying why rather than only that they
did. The boundary took 6 tournaments off the sport, but `Medal_Set_Unreadable_Without_Rank` fell
from 101 to 32 while `No_Medals_At_All` rose from 87 to 111 - so what moved is not only which
statistics are audited but which branch each falls into, the two being decided in order and the
missing Rank tested first. The 111 are the reverse direction of the rule, arriving without a
check being written for it, and they still sit mostly under `11526 European Boys' Team
Championship` and `11525 European Girls' Team Championship`, which is the same five-template gap
named above seen from the other side. The 32 belong to `Golf-DQ-001` and are not restated here.
Nine rows are medal-set defects in the sense the check was written for, against four before.

**Test data is inside the scope, not beside it.** Because no template is excluded,
`12649 TEST` and its 899 event participants are part of every sport-wide count a Golf check will
return, as is the `TEST - ISCO Championship` event. Any Golf finding list will contain them, and
they are not a defect the check found - they are the population it was pointed at.

**`12649 TEST` is a template named TEST, and it is populated.** Seven tournaments, seven stages,
seven events and 899 event participants. The event inventory also returns
`TEST - ISCO Championship` as the sole `inprogress` event in the sport. This is test data in the
production population, and any sport-wide count in this file includes it.

**`10341 Presidents Cup` has nine tournaments and no stages, events or participants.** It is an
empty branch of the hierarchy rather than a missing template, which is the state
`GLOBAL-DQ-001` exists to report.

**A stroke-play tournament is one event dated on its opening day, and the stage carries the days
it was actually played.** The four rounds are not four events: `810110 Omega Hong Kong Open` runs
`2001-11-29` to `2001-12-02` on the stage and holds a single event dated `2001-11-29`. So the
stage end date is later than the last event start date by the length of the tournament, and it is
supposed to be.

`GLOBAL-DQ-004` reports 5089 of 5450 stages on that account. 4969 of them are exactly this shape -
stage start equal to the earliest event, stage end one to four days later - and 4975 hold their
events on one single date. The template's invariant, that a stage is bounded by its own events,
is false for a sport whose event is a container for several days of play. The residue is 120
stages: 89 whose start disagrees while the end matches, 24 running five days or more past their
last event, and 7 disagreeing at both ends.

**Match play names an event after its two competitors and joins them with a hyphen carrying no
spaces**, as in `A-Lim Kim-Andrea Lee`. The separator between the two players and the hyphen
inside one player's own name are the same character, which is why the name cannot be split back
into its parts and why `DUPLICATE_KEY_INCLUDES_EVENT_NAME` is `0` for this sport.

It also means the sport's own naming convention breaks a text-hygiene rule on every match-play
event. `GLOBAL-DQ-049` reports 13430 of 14720 distinct event names, and 13340 of those break
`HYPHEN_WITHOUT_SPACES` and nothing else. Ninety names break something a reviewer would want:
10 hold a corrupted character, 3 are all uppercase, 3 start lowercase, 2 double a capital and one
doubles a space, with a further 71 corrupted names that also carry the separator.

**Stroke play names an event after the tournament and names no competitor at all.** `5035212
Boeing Classic` carries 78 players and none of them in its name. This is the Hybrid model showing
up in the naming layer the way it already shows up in the result layer: `GLOBAL-DQ-096` asserts
that an event names the competitors that play it, which is true of the sport's match-play half
and false of its stroke-play half, and it reports 4875 events for naming no participant.

The 602 rows it reports for naming only some of them are the finding the check exists for -
`4315561 Benjamin James-Mark Power` is a match against a participant recorded as `Ben James`, so
the event name and the participant register disagree about the same person's name.

**A tour season is named for one year and played across two.** Tournament `2663`, named `2002`
under `European Tour 1`, holds 37 stages that begin in 2001 and end in 2002, and the same holds
for every European Tour season in the file. `GLOBAL-DQ-080` reports 45 tournaments and 42 of them
are this: a single-year name over a season the stages carry into a second year. The template
recognises the written span form `2025/26`; the sport does not use it, so a straddling season is
indistinguishable from a misnamed one by name alone.

**A woman entering a men's field is golf, and it is not distinguishable from a mis-stored gender
by structure.** `Michelle Wie West`, `Carlota Ciganda`, `Charley Hull`, `Georgia Hall` and
`Catriona Matthew` are all recorded `female` and all entered in stages recorded `male`, which is
what happened. It surfaces in two places: `GLOBAL-DQ-123` reports 31 athletes that way, and
`GLOBAL-DQ-044` reports 17 male Comp.Rank each holding exactly one female among 119 to 191 men -
`Legends Reno-Tahoe Open`, `John Deere Classic`, `B.C. Open`, `84 Lumber Classic`.

The same finding lists hold rows that read as genuine defects, and they are told apart by what
carries the gender rather than by the count. A national team entity - `England`, `France`,
`Spain`, `Scotland` - is stored once with one gender and entered under both, which puts 26 team
rows in `GLOBAL-DQ-123`; and the European Boys' and Girls' Team Championships hold 3 to 10
wrong-gender team members each in `GLOBAL-DQ-044`. Neither check can make the distinction itself.

**A round named Final is not a knockout round in this sport, and `173 Final` carrying
`knockout = no` is correct.** Recorded by decision on 2026-08-13, against the shape of the data
rather than from it, and the measurement is here so the decision is legible.

Golf files 529 events on `173 Final`, all of them Match Play, and 28 on `9 Final`, also all
Match Play. Two round types, one name, opposite flags, and the sport uses both. Read from the
data alone the larger population would have looked like the defect; the reading is the other way
round, so `'final'` moved from `ELIMINATION_ROUND_NAME_LIST` to `GROUP_ROUND_NAME_LIST` and the
expectation for the name is now `no`.

The consequence is deliberate and is the point of stating it: `GLOBAL-DQ-118` stops reporting the
529 events on `173` and starts reporting the 28 on `9`, which is a repair list a person can
finish. `GLOBAL-DQ-097` follows it, as the two are written to always agree on which round types
are wrong.

Nothing else in the pair moved. `176 Quarter Finals`, `178 Semi Finals`, `188 1/32`, `185 1/16`,
`184 1/8`, `186 Small Final` and `304 Playoff` all carry `knockout = no` and all remain findings,
6126 events between them: those names are elimination rounds in this sport as in any other, and
the sport's own knockout-flagged twins - `3`, `2`, `4`, `19`, `305` - are what they should sit on.

**The scope container is stored by fourteen templates and not by twenty-two, and the client
reads neither.** `Golf-DQ-058`, running `GLOBAL-DQ-107`, was deprecated on 2026-08-13 by
decision, not by measurement, and the measurement is recorded here so the decision can be
reversed knowing what it gave up.

Of the 36 templates holding finished events, 14 carry an `event_scope` container of type `305`
on at least some of them - `430 European Tour and PGA Tour 1` on 811 of 1829, `436 LPGA Tour 1`
on 663 of 1710, `9645 Walker Cup 1` on 130 of 135, `10305 LIV Golf` on 111 of 172. Twenty-two
carry none at all, including every amateur team championship and **every Games template**:
`9600`/`9601 Summer Olympics` 0 of 3, `11498 Summer Youth Olympics` 0 of 4, `10328 Asian Games`
0 of 10, `10327 Pan American Games` 0 of 6, `11532 Southeast Asian Games` 0 of 6.

Measured sport-wide, on 2026-08-13, before the client boundary was recorded. Two of the four
best-covered templates named above — `9645 Walker Cup 1` and `10305 LIV Golf` — are outside it,
so a re-measurement inside the boundary would find the container rarer still. Anyone reversing
the deprecation should re-measure rather than read these numbers as the population the check
would now see.

So the structure exists and is used, and the check is not `Not applicable` under this project's
rule - it would have reported 16334 of 19053 finished events forever, and a scope container
arriving tomorrow is exactly what it was written to notice. It is deprecated instead, which
keeps the CheckID reserved and the row in the registry, because the client does not read scope
results and a permanent 86 per cent finding is noise on a board somebody has to work through.
The hole-by-hole scope layer is outside the DQ work by the decision of 2026-08-12, and this is
the same decision reaching the one check that could see it.

**Two `statistic_data11` fields are declared for the shard and never written.** `1427` Time
difference and `1429` Team both resolve for statistic type 11 and Golf stores no row in either, so
`GLOBAL-DQ-028`, `GLOBAL-DQ-064`, `GLOBAL-DQ-065` and `GLOBAL-DQ-066` all audit an empty
population. That is a sentinel rather than a misdirected scope: the field exists, the sport has
not used it, and the day it does the check is already pointed at it.

All four carry the `Sentinel` signal since 2026-08-17. They were recorded as `Monitor` with
reasons that already began "this is a sentinel", which is what a missing word looks like in a
file: the run reads the signal rather than the reason, so it asked about all four on the
`Decisions` tab of every run while this paragraph had answered them. The signal also changes
what is expected of them — `Sentinel` implies `Zero`, and when the Team and Time difference
fields are first written, every row these four return is a defect.

**A missing finishing position is explained by `38 Made cut`, not by a Comment.** Confirmed
2026-08-13. The field holds `yes` or `no` on 351045 participants over 3201 Stroke Play events —
near-complete coverage of the discipline — and a player who missed the cut carries `no` and no
Rank, which is the correct record of a weekend he did not play.

This is a sport-specific answer to a question the global layer asks differently. `GLOBAL-DQ-036`
requires a Comment to account for an absent Rank, because that is where every other documented
sport puts it; read against Golf it reported 23071 ordinary missed cuts as defects. Honouring
`Made cut` leaves 841 participants over 107 events, which is the population actually worth
reading. `Golf-DQ-087` is the statement that does it, and the reason it is a Golf statement
rather than an instantiated template: no parameter can tell a template to look in a field the
template does not know about.

**A stage is not bounded by its own events, and the offsets are measured.** Stroke play starts
its stage on the first event's day in **3476 of 3476** stages, and ends it 0 to 6 days later —
three days for the ordinary Thursday-to-Sunday tournament, four where a Monday finish is
recorded. Match play aligns on both ends in 212 of its 251. Nothing in the sport ends a stage
before its last event or, apart from three stages, starts one after its first.

Two shapes are therefore deliberately not defects here: a stage ending after its only event,
which is a stroke-play tournament's whole span, and a stage starting up to two days before its
first match, which 88 of the 251 match-play stages do because the stage is dated by the
tournament's window rather than by the matches inside it. `Golf-DQ-090` asserts what is left —
a stage that cannot contain what it holds — and returns 1 of 3588, remeasured 2026-08-21.

**A Match Play outcome is two words and a notation, and until 2026-08-13 nothing read it.**
`4 Final Result` holds `won` on 11075 rows, `lost` on 11077 and `draw` on 1130 - two per halved
match, which is the sport working - and `0` on 4 rows, which is not a word it uses.
`39 Match Play Score` holds golf's own notation: `1up` on 2771, `2&1` on 1763, `3&2` on 1511,
`A/S` on 1472, alongside the point values a team match awards (`3`, `1.5`, `0.5`) and `WO` and
`WD` for a walkover and a withdrawal.

That is why `GLOBAL-DQ-094` cannot be instantiated here: it reads the placing off a pair of
numeric scores, and neither of these fields is one. `Golf-DQ-092` asks the question in the
sport's own vocabulary and reports 1192 of 12975 two-sided matches, remeasured 2026-08-21.
**1151 of them are a match scored in `39` with no winner named in `4`**, arriving about 63 to a template-season — the size
of a 64-player bracket, so what is missing is the verdict on whole draws rather than scattered
rows. The rest are sharp and few: 60 scores reading `X&Y` where `X` is not the larger, which is
impossible; 13 halved matches carrying a deciding score; 2 events where `4` holds a number; and
2 all-square scores on a match the result says was won.

**A bare `-` in `36 Par` is a defect, not the sport's way of writing "no score".** Settled
2026-08-13. It is the fourth most common shape in the field at 4831 values over 1743 events, and
`Golf-DQ-019` already reports it: 916 of that check's 931 event rows carry one among their
values. No new check follows from the answer — what follows is that those rows are to be
corrected rather than explained.

**A season named for one year begins in the September before it.** 37 year-named tournaments
hold events outside their year and every one of them opens early rather than finishing late:
November for 19, December 6, October 6 and September 4. The European Tour season called `2002`
opens on 22 November 2001 and closes on 7 November 2002.

The two that run past their year are Tokyo, whose Games kept the name `2020` and were played on
29 July and 4 August 2021. `Golf-DQ-091` records those as its expected residual rather than
filtering them out, because a filter would also hide the next tournament that genuinely runs
into the following year.

**The sport carries two conventions for a competition contested by both genders, and one of
them is wrong.** Measured 2026-08-21 over the client's medal templates. The established practice
is a pair of templates, one per gender: `9600 Summer Olympics` male beside `9601` female,
`10537 Pacific Games` male beside `10538` female, `11507 British Boys Amateur Championship`
beside `11524 British Girls Amateur Championship`, `11526 European Boys' Team Championship`
beside `11525 European Girls' Team Championship`. That is also how every other sport in the
package models it - Ice Hockey pairs `31 Winter Olympics` female with `32` male.

Four templates do it the other way, as one template declared `mixed` holding a male stage set
and a female one:

| Template | Tournaments | Stages | Stage genders |
|---|---:|---:|---|
| `10328 Asian Games` | 7 | 10 | 5 male, 5 female |
| `10327 Pan American Games` | 3 | 6 | 3 male, 3 female |
| `11532 Southeast Asian Games` | 3 | 6 | 3 male, 3 female |
| `11498 Summer Youth Olympics` | 2 | 4 | 2 male, 2 female |

Not one of the four holds a single mixed stage, and the stage names say plainly what they are -
`Men's Individual` and `Women's Individual`, sitting side by side in the same tournament.
**`mixed` in this database means competitors of both genders together**, which is what
`9779 European Championships 1` uses it for, correctly, on a genuinely mixed stage. Using it to
mean "covers both genders separately" is a second reading of the same word, and the two cannot
both be true of one column.

`Golf-DQ-112` reports the four, on `GLOBAL-DQ-133`. **The correction is to split each into a
male and a female template**, confirmed 2026-08-21, and it is the sport's own practice rather
than a convention imposed from outside - the Olympics and the Pacific Games are already stored
that way. That makes the repair larger than a one-word edit, since it moves tournaments and
stages onto new templates, so it is a finding for the provider rather than something derivable
here. A fifth template of the same shape, `9831 GolfSixes`, sits outside the client's boundary
and is therefore not reported; it is recorded so nobody re-measures it.

<!-- MANUAL PASTE ZONE: 3 STORAGE SEMANTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Open questions

1. ~~**How is a pair participant meant to be read?**~~ Answered 2026-08-14. The two players are
   reachable: a foursome is four `event_participants` rows, and `number` carries the side.
   **Participant and lineup structure** above records the rule and what it corrects.
2. ~~**What are the five `tournament_stage`-owned statistics?**~~ Answered 2026-08-14: Comp.Rank
   at `object_typeFK = 4` instead of 3. **Statistics** above records which five and what asserts it.
3. ~~**Are `penalty_stroke_9` and the four `clock_penalty_*` data types genuinely Golf's?**~~
   Answered 2026-08-14 by size: they hold five values between them, one each, all reading `1`.
   `penalty_stroke_9` sits on one event in 2019 and reads as golf - a penalty stroke at the ninth.
   The four `clock_penalty_*` sit on a single event on a single day, 2018-06-07, which is the
   shape of a misfiled write rather than a vocabulary. Five values among 29653897 is not a
   population a check can be built on.
4. ~~**What do `event_scope_detail` and `lineup_scope_result` hold for Golf?**~~ Answered
   2026-08-14, and the expectation was wrong: `event_scope_detail` is empty, `lineup_scope_result`
   holds 128 values and all of them name another sport's lineup. **Scope types and data types**
   above records it; `Golf-DQ-099` reports the one event inside the client boundary.
5. ~~**Which round is "the" score?**~~ Answered 2026-08-14: `36 Par`. Of 338799 ranked stroke
   play competitors 335334 hold it - 99.0 per cent - while only 177821 hold a fourth-round stroke
   count and 176859 hold all four rounds, and no total-strokes result type exists. Par is the only
   figure present for the whole population, which is what `RESULT_SCORE_TYPE_ID` already records.
   Whether the Par order agrees with the stored Rank is a separate question and is not measured.
6. ~~**How is a foursome's side to be read?**~~ Answered 2026-08-14 together with question 1:
   odd numbers are one side and even the other, confirmed on all 2008 four-entry events that name
   every competitor. `Golf-DQ-092` was extended to them on 2026-08-14 and the gap is closed.

**The hole-by-hole scope layer is not audited for now.** Decided 2026-08-12. Its 29653897 values
are counted sport-wide; most of them sit inside the client's boundary, and they are deliberately
left outside the DQ work rather than overlooked. This is a decision about where the effort goes and not a
statement about the data: the layer is the sport's largest storage and the two catalogue
failures both came from it, so a check written against it later has to be sized before it is
written. Nothing here classifies it `Not applicable` - the structure is present and the sport
fills it.

Settled since this file was opened, then reversed: the client scope was recorded as the whole
sport until 2026-08-13, when UK Sport named twenty templates it does not take. **Scope** above
owns the list and what it costs. The reversal is left visible rather than tidied away, because
several conclusions in this file were reached while the wider boundary was believed, and a
reader meeting one of them deserves to know which assumption it was written under.

<!-- MANUAL PASTE ZONE: 3 OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
