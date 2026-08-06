# SPORT: Modern Pentathlon (sport_id=42)

This file is the canonical structural record for Modern Pentathlon. It contains only confirmed
sport-specific usage, meanings, identifiers, evidence boundaries and open structural
questions. Global database mechanisms belong in `../DATABASE.md`.

For additions, insert approved content immediately before the exact active
`MANUAL PASTE ZONE` marker in the destination subsection. Keep the marker unchanged
and at the end of its subsection. Replace existing rows or paragraphs in place when a
correction is required.

## Identity and evidence

- First discovery date: 2026-08-06
- Latest evidence date: 2026-08-06
- Verification boundary: the GLOBAL discovery catalogue, run for the sport with the runner's
  chaining. Every summary statement covers its whole inventory; the paired detail statements
  were run only on the values each summary ranks first, so per-pattern examples are a sample
  and are recorded here as such. `GLOBAL-DISCOVERY-015` returned a single statistic type and
  owner pair, so nothing about the statistic layer rests on a choice between candidates.

## Structural coverage

| Area | Status | Evidence |
|---|---|---|
| Core hierarchy | Used | `GLOBAL-DISCOVERY-002`, `-003` |
| Event participants | Used | `GLOBAL-DISCOVERY-004` |
| Event results | Used | `GLOBAL-DISCOVERY-007`, `-026`, `-027` |
| Incidents | Not used | `GLOBAL-DISCOVERY-008` returned zero active rows; a probe without the deleted filter found none either |
| Lineups | Used | `GLOBAL-DISCOVERY-005` |
| Scope layer | Not used | `GLOBAL-DISCOVERY-009`, `-010` returned zero active rows; a probe without the deleted filter found none either |
| Properties | Used | `GLOBAL-DISCOVERY-011` |
| object_relation | Used | `GLOBAL-DISCOVERY-012` |
| object_discipline | Used | `GLOBAL-DISCOVERY-013`, `-032` |
| Statistics | Used | `GLOBAL-DISCOVERY-015`, `-016`, `-017`, `-024`, `-028`, `-029` |
| Reference values | Used | `GLOBAL-DISCOVERY-030`, `-031` |
| Other tables | Not checked | |

## Tables and relation paths used

The sport is reached through the standard hierarchy path:
`tournament_template.sportFK` → `tournament` → `tournament_stage` → `event` →
`event_participants` → `result`.

Statistics are reached through the tournament, not the event:
`tournament_template.sportFK` → `tournament` → `statistic` (`object_typeFK = 3`) →
`statistic_participants11` → `statistic_data11`, with `statistic_config` alongside.

<!-- MANUAL PASTE ZONE: 42 TABLES AND RELATIONS — insert approved additions immediately before this marker; do not move or delete it. -->

## Participant and lineup structure

Event participants are of two types: `athlete`, with genders `male` and `female`, and `team`,
with genders `male`, `female` and `mixed`. The sport therefore fields a mixed-gender team
category alongside the single-gender ones.

The sport registry (`object_participants`) holds the same two types under the roles `athlete`
and `team`, and carries both active and inactive rows for each.

One lineup type is in use, `14` (`Starter`). Its members are always `athlete`, male or female;
no other member type appears.

A mixed team is symmetric: it holds the same number of men as women. The rule is read from the
sport's own data rather than from the discipline's rules, and holds independently in the two
places a team's membership is stored. Among the event entries of a `mixed` team the dominant
composition by a wide margin is one man and one woman, and the symmetry is kept at two, three
and four a side; among the teams the Comp.Rank statistic assembles through its `1429` Team
field the same distribution appears again. In both layers an entry holding both genders
unevenly is a small minority, so a balance check reports an exception rather than the sport's
format. A team holding one gender only is a separate state and not a broken balance: the event
layer leaves it to `GLOBAL-DQ-043`, while the statistic layer has no such sibling and
`GLOBAL-DQ-066` reports it there.

<!-- MANUAL PASTE ZONE: 42 PARTICIPANTS AND LINEUPS — insert approved additions immediately before this marker; do not move or delete it. -->

## Event result types

| result_code | result_typeFK | Value shape | Confirmed meaning | Evidence |
|---|---:|---|---|---|
| `rank` | 100 | plain positive integer, no other shape observed | finishing place | `GLOBAL-DISCOVERY-007`, `-026`, `-027` |
| `points` | 102 | integer, with a minority tail of status words (`DNS`, `DNF`, `EL`, `Eliminated`), a `nan` sentinel, a bare `-`, a negative integer and a decimal | pentathlon score | `GLOBAL-DISCOVERY-007`, `-026` |
| `comment` | 104 | a status vocabulary (`DNS`, `DNF`, `Eliminated`, `EL`, `DSQ`, `Disq.`, `Dns.`, `Q`, `Q/OR`, `N/A`) mixed with records (`OR`, `WR`), with times shaped `#:#.#`, and with a bare number | why a participant has no ordinary result, or a record marker | `GLOBAL-DISCOVERY-007`, `-026`, `-027` |
| `medal` | 501 | `gold`, `silver`, `bronze` only | medal awarded | `GLOBAL-DISCOVERY-007` |

The `points` and `comment` value shapes are the sport's own vocabulary, not a global one; a
check reading either must be written against the list above rather than against a generic set.

Every spelling in actual use is recorded as a legitimate status code, including the variants,
so a vocabulary check reports what is genuinely unrecognised rather than the sport's own
inconsistency. On this sport that leaves the numbers and the times stored in the `comment`
field as the values such a check reports, which is the intended reading: neither is a status.

`dns` and `dns.` are not interchangeable in the data. `dns.` carries a Rank on every
participant that holds it, while `dns` does so on roughly a tenth — so the two spellings behave
as different states rather than as one state written two ways, and which state `dns.` denotes is
unresolved. `disq.` carries a Rank on none, which is consistent with a disqualification.

`el` and `eliminated` frequently sit beside a stored Rank, so neither is recorded as meaning
the participant has no result; `q`, `or`, `wr` and `q/or` always do, being a qualification or a
record rather than an absence.

The Rank values divide cleanly. The largest field the sport contests holds 75 participants and
ordinary ranks stop there; the only values above it are a handful in the 471 to 561 range, each
occurring once and all on `Team-Relay Mix - After Laser Run` events. Nothing sits between the
two groups, so the sport's plausible maximum is recorded at 100 — inside that gap, with headroom
for a larger field than any contested so far.

<!-- MANUAL PASTE ZONE: 42 EVENT RESULTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Incident types

`Not used`. `GLOBAL-DISCOVERY-008` completed successfully and returned no active incident type
or incident code combination for the sport. A probe of the same relation path without the
`del = 'no'` filter returned no rows either, so the layer has never held a row for this sport,
active or removed, while the identical path reaches incidents for other sports.

That is a statement about what has been stored, not about what can be: the schema permits the
relation and other sports use it. A check reading the incident layer is therefore not
structurally inapplicable here, it simply has nothing to audit today.

<!-- MANUAL PASTE ZONE: 42 INCIDENTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Scope types and data types

`Not used`. `GLOBAL-DISCOVERY-009` and `-010` both completed successfully and returned no
active event-scope container and no active scope value row for the sport. A probe of the same
relation path without the `del = 'no'` filter returned no rows either.

The sport models its segments as separate events carrying a discipline — Fencing, Swimming,
Riding, Laser Run, Obstacle and an Overall event — rather than as a period breakdown inside one
event. The scope layer is thus not the mechanism this sport uses, but, as with incidents, the
schema permits it and the absence is of stored rows rather than of capability.

<!-- MANUAL PASTE ZONE: 42 SCOPES — insert approved additions immediately before this marker; do not move or delete it. -->

## Properties

Confirmed active `property` owners and names, all of `property_type = 'metadata'`:

| Owner | Property names |
|---|---|
| `event` | `discipline`, `discipline_number`, `Live`, `medal_related`, `ParticipantType`, `Round`, `Type` |
| `participant` | `date_of_birth`, `discipline`, `height`, `weight`, `IsNationalTeam`, `sport`, `status`, `ToBeDecided` |
| `tournament_stage` | `Cup`, `Type` |

No `Winner` property is stored on any owner, which is consistent with the sport being a listing
rather than a head-to-head one.

<!-- MANUAL PASTE ZONE: 42 PROPERTIES — insert approved additions immediately before this marker; do not move or delete it. -->

## Generic relations and disciplines

Confirmed `object_relation` source/target combinations:

| Source | Target | Note |
|---|---|---|
| `sport` (1) | `category` (153) | one relation, from the sport itself; `object_type 153` is `category`, which `DATABASE.md` does not list |
| `tournament_template` (2) | `tournament_sub_set` (152) | `REL-OBJECT-002` |
| `tournament_stage` (4) | `tournament_age_class` (151) | `REL-OBJECT-001` |
| `statistic` (83) | `country` (33) | as `DATABASE.md` records for the statistic layer |
| `statistic` (83) | `tournament_age_class` (151) | `REL-OBJECT-003` |

`object_discipline` is carried on both `event` (5) and `statistic` (83).

Confirmed disciplines:

| discipline | ID | Layer |
|---|---:|---|
| Shooting | 99 | event |
| Fencing | 100 | event, statistic |
| Swimming | 101 | event, statistic |
| Riding | 102 | event, statistic |
| Running | 103 | event, statistic |
| Overall | 104 | event, statistic |
| Laser Run | 549 | event, statistic |
| Obstacle | 550 | event, statistic |

`GLOBAL-DISCOVERY-032` shows the discipline set is not stable across the sport's history:
`Running` is contested only in the earlier years of the record and `Obstacle` only in the later
ones, while `Fencing`, `Swimming`, `Riding`, `Laser Run` and `Overall` span it throughout. A
discipline-scoped check must therefore not read an absent discipline in a given year as a
defect, and must name the disciplines it audits rather than assuming the set is constant.

The discipline population differs between the two layers: every discipline above reaches
events, but the statistic layer is dominated by `Overall`. A discipline-scoped check must be
written against the layer it audits and must not infer one layer's discipline population from
the other.

Within the statistic layer the discipline relation and the `1426` Time field are disjoint:
every Comp.Rank carrying a Time carries no `object_discipline` row, and every Comp.Rank
carrying a discipline holds no Time. Neither is empty on its own — both are populated — but
they are never attached to the same statistic. A check scoping on the sport's timed disciplines
and reading a time therefore audits a population that by construction can hold none, which is
why `GLOBAL-DQ-046` is recorded as `Blocked` rather than approved or declared inapplicable.
The sampled Time values are `00.00` and `99.00`, neither of which reads as a measured time.

<!-- MANUAL PASTE ZONE: 42 GENERIC RELATIONS AND DISCIPLINES — insert approved additions immediately before this marker; do not move or delete it. -->

## Statistics

| statistic_typeFK | Owner type | Participant shard | Data shard | Fields/config | Evidence |
|---:|---:|---:|---:|---|---|
| 11 | 3 (`tournament`) | 11 | 11 | config `1463` Start date, `1464` End date, `1470` Gender, `1471` Event id; data `1270` Rank, `1271` Points, `1273` Comment, `1277` Medal, `1426` Time, `1429` Team, `1456` Running Score | `GLOBAL-DISCOVERY-015`, `-016`, `-017` |

`GLOBAL-DISCOVERY-015` returned this one type and owner pair and no other, so the sport's whole
statistic layer is Comp.Rank owned by the tournament. The shard was confirmed by probing
`statistic_participants11` for a statistic the inventory had already attributed to the sport,
not derived from the statistic type.

Confirmed data value shapes:

| Field | Shape |
|---|---|
| `1270` Rank | plain positive integer, and an empty value on a minority of statistics |
| `1271` Points | integer, an empty value on a substantial minority, and a decimal on a few |
| `1273` Comment | `DNS`, `DNF`, `EL`, `DSQ`, `Disq.`, `Dns.`, `Disqualified`, `OR`, `WR` |
| `1277` Medal | `gold`, `silver`, `bronze` only |
| `1426` Time | `#:#.#` and `#.#` |
| `1429` Team | a participant ID, always numeric |
| `1456` Running Score | empty in every stored row |

Statistic names take two shapes: a short category name — `Male Individual`, `Female
Individual`, `Men's team`, `Women's team`, `Men's relay`, `Women's relay` — and a composite
`<tournament> Final Overall Classification <gender> - Competition Rank`. Both shapes appear
again with an `(athletes)` suffix, which pairs a team statistic with the statistic naming its
athletes.

<!-- MANUAL PASTE ZONE: 42 STATISTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Reference values

`GLOBAL-DISCOVERY-030` and `-031` compare the data field types declared for `statistic_type 11`
against their use in this sport's owner level and shard. The seven fields listed under
Statistics above are the ones in use; the remainder of the declared catalogue — including
`1272` Duration, `1274` Laps Behind, `1275` Order and the other declared types — is present in
the reference catalogue and unused here.

`1272` Duration being unused matters beyond the inventory: `DATABASE.md` records it as the
deprecated predecessor of Time and Time Difference, and this sport stores neither Duration nor
Time Difference, only Time.

All three of `1272` Duration, `1426` Time and `1427` Time Difference are declared for
`statistic_type 11`, so the absence of the first and third is a state of this sport's data and
not a structure it lacks. `1272` and `1427` are therefore recorded as parameters rather than
declared not applicable: a check reading either is written for the day those rows appear, and
excluding it now would disable it on exactly that day. Until then a check keyed on Time
Difference alone audits an empty population and reports `eligible_count = 0`, which
`POWERBI.md` classifies as a correct scope over a legitimately empty population — a sentinel,
not a defect and not a misdirected scope.

<!-- MANUAL PASTE ZONE: 42 REFERENCE VALUES — insert approved additions immediately before this marker; do not move or delete it. -->

## Event and round representation

Confirmed `event.round_typeFK` values in use: `2`, `38`, `39`, `40`, `41`, `42`, `77`, `89`,
`92`, `152`, `173`, `178`, `179`, `251`, `260`.

The round-type names are not unique across those IDs. `179` and `152` are both named
`Qualifier`, and `2` and `178` are both named `Semi Finals`. Several are named with a bare
number — `38` through `42` are `1` to `5`, while `89` is also `1` and `92` is also `4`. A check
must therefore key on the round type ID and never on its name.

`251` is `After Disciplines` and `260` is `Bonus Round`, both of which are sport-specific stages
of a multi-discipline competition rather than knockout rounds.

`Final` is the sport's only round that eliminates nobody; every other round it contests is an
elimination round, by decision of 2026-08-06. `DATABASE.md` `DB-SEM-012` records that a round
name exists twice, once with `knockout = 'yes'` and once without, and that the pair is
distinguished by ID rather than by name — so which variant a sport uses is a fact about that
sport. This one uses the non-knockout variant of all ten of its elimination round names, while
the knockout twin of every one of them exists (`38`/`89`, `39`/`90`, `40`/`91`, `41`/`92`,
`42`/`93`, `77`/`128`, `152`/`179`, `2`/`178`, `251`/`252`, `260`/`261`), and for four of those
names the sport already uses the knockout twin on some of its events. The round types are
therefore recorded as they are used, and the mismatch is a finding rather than a shape to
accommodate.

`173` `Final` is the sport's only medal round: nearly every event on it carries a Medal result,
and every medal is awarded inside the Final event itself rather than on a separate bronze
decider. A small number of Medal results sit on other round types, and a small number of Final
events carry none; both are recorded here as the population a medal-round check reads, not as
exceptions to be excluded from it.

Event names follow the discipline the event stages: `Fencing`, `Swimming Final`, `Laser Run
Final`, `Final Overall Classification`, and forms naming a segment boundary such as `Semi-Final
A - After Fencing` and `eam-Relay Mix - After Swimming` — the latter showing a truncated leading
character in the stored name.

Tournament stage names identify the competition and its age band: `World Championships`,
`European Championships U#`, `Junior European Championships`, `World Cup - <city>`.

Event statuses in use are `finished` (detail `6`), `notstarted` (detail `1`), `cancelled`
(detail `106`) and `finished` with detail `11`, `Finished AET`.

The sport uses one of the 37 detailed statuses the reference table marks `notstarted`, but the
vocabulary recorded for it is the curated set of `Not started` and `Postponed` codes rather than
that single value: classifying from today's population would blind the check to every other
status the day it arrives. `Abandoned` is deliberately outside the set — an abandoned event
started and stopped, which is not the same as one that never began.

An event still marked not started 48 hours after its own date is treated as stale. That is a
tighter window than the 30 days the other five documented sports carry, by decision of
2026-08-06; the parameter's unit is days, so the value is recorded as `2`.

Tournament names are the season and nothing else: every active tournament in the sport is named
by a bare four-digit year. The name therefore carries a label a date check can contradict, which
is the structure `GLOBAL-DQ-080` reads, and it carries no other content for a naming check to
judge.

<!-- MANUAL PASTE ZONE: 42 EVENT AND ROUND REPRESENTATION — insert approved additions immediately before this marker; do not move or delete it. -->

## Confirmed sport-specific storage semantics

A tournament stage carries its country in two places at once: directly in
`tournament_stage.countryFK`, and through the host-country relation. It also carries a city link
and an age-class relation, with `SENIOR` among the age classes in use. `DATABASE.md` records
that the two country paths are distinct, and this sport uses both.

`International` and `Unknown` are the two placeholder rows the `country` table holds. Neither
reaches this sport through the direct column, the host-country relation or the statistic country
relation, so a placeholder-country check reads a population that is empty today. They are
recorded as the sport's placeholder vocabulary all the same: the list says what would count as
one, not that any exists.

Statistics are owned by the tournament (`object_typeFK = 3`) and name their event through the
`1471` Event id config rather than through a foreign key, which is the only path from a
statistic to the event it describes.

<!-- MANUAL PASTE ZONE: 42 STORAGE SEMANTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Open questions

- `object_type 153` is `category`, and the `sport` → `category` relation this sport carries is
  absent from `DATABASE.md`'s `object_relation` table. Whether the relation is sport-specific or
  a global mechanism nobody has documented is unresolved, and `DATABASE.md` owns the answer.
- `1456` Running Score is instantiated on a large number of statistics and empty in every one of
  them. Whether the field is written by a process that has stopped, or was never populated at
  all, is unknown; its stored-row count closely tracks that of the empty `1271` Points rows,
  which suggests the two are the same population.
- `1271` Points is empty on a substantial minority of statistics while `1270` Rank is empty on
  very few. Whether a placed competitor is expected to carry a score is not settled.
- The `1273` Comment and the `104` comment result both carry several spellings of one state —
  `DSQ`, `Disq.` and `Disqualified`; `DNS` and `Dns.` — so any check reading them must either
  normalise or list every spelling. Whether the spellings should be reconciled at source is for
  the data owners.
- `Finished AET` (status detail `11`) is stored on a small number of events in a sport that
  contests no head-to-head fixtures. What an extra period means here is unresolved.
- `1271` Points holds a decimal value on a few rows while the field is otherwise integral, and
  the `102` points result additionally holds `nan`, a bare `-` and a negative integer. Whether
  any of these is a legitimate score is unresolved.
- Event names include at least one with a truncated leading character (`eam-Relay Mix - After
  Swimming`). Whether this is isolated or systematic has not been measured.
- The `1426` Time values sampled are `00.00` and `99.00`, and every statistic holding one lacks
  a discipline while every statistic holding a discipline lacks a Time. Whether the time field
  is being written by a path that does not set the discipline, or the values are placeholders
  rather than measurements, is unresolved and blocks `GLOBAL-DQ-046`.
- `dns.` carries a Rank on every participant that holds it while `dns` does so on roughly a
  tenth, so the two spellings behave as different states. What `dns.` denotes is unresolved.
- Around a hundred distinct numbers and times are stored in the `104` comment result, each
  beside a Rank. Whether they belong in a field of their own is for the data owners.
- Ten of the sport's fifteen round types sit on the non-knockout variant of a name whose
  knockout twin exists and, for four of them, is already in use on other events of the same
  sport. Whether the events should move to the twin or the flag on those rows is wrong is for
  the data owners; `DB-SEM-012` makes the pair deliberate, so this is a choice of variant
  rather than a missing row.

<!-- MANUAL PASTE ZONE: 42 OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
