# SPORT: Triathlon (sport_id=50)

This file is the canonical structural record for Triathlon. It contains only confirmed
sport-specific usage, meanings, identifiers, evidence boundaries and open structural
questions. Global database mechanisms belong in `../DATABASE.md`.

For additions, insert approved content immediately before the exact active
`MANUAL PASTE ZONE` marker in the destination subsection. Keep the marker unchanged
and at the end of its subsection. Replace existing rows or paragraphs in place when a
correction is required.

## Identity and evidence

- First discovery date: 2026-07-30
- Latest evidence date: 2026-07-31
- Verification boundary: GLOBAL discovery catalogue executed for sport_id=50, plus the
  round-type and value-pattern drill-downs named below. Enet sport code `tn`. Detail
  statements for event names, stage names, statistic names and event-result value patterns
  (`GLOBAL-DISCOVERY-021`, `-023`, `-025`, `-027`, `-029`) were not run, so no per-object
  example inventory exists for those areas.

## Structural coverage

| Area | Status | Evidence |
|---|---|---|
| Core hierarchy | Used | `GLOBAL-DISCOVERY-002`, `-003` |
| Event participants | Used | `GLOBAL-DISCOVERY-004`, `-006` |
| Event results | Used | `GLOBAL-DISCOVERY-007`, `-026` |
| Incidents | Not used | `GLOBAL-DISCOVERY-008` returned zero active rows |
| Lineups | Used | `GLOBAL-DISCOVERY-005` |
| Scope layer | Not used | `GLOBAL-DISCOVERY-009`, `-010` returned zero active rows |
| Properties | Used | `GLOBAL-DISCOVERY-011` |
| object_relation | Used | `GLOBAL-DISCOVERY-012` |
| object_discipline | Used | `GLOBAL-DISCOVERY-013` |
| Statistics | Used | `GLOBAL-DISCOVERY-015`, `-016`, `-017`, `-028` |
| Reference values | Used | `GLOBAL-DISCOVERY-030`, `-031` |
| Other tables | Not checked | |

## Tables and relation paths used

Core hierarchy is fully populated: `tournament_template` → `tournament` → `tournament_stage`
→ `event` → `event_participants`, with active rows at every level.

Tournament template carries the gender. A single competition name exists as separate
templates per gender — `male`, `female` and `mixed` variants of the same name are distinct
templates rather than one template with gendered stages.

<!-- MANUAL PASTE ZONE: 50 TABLES AND RELATIONS — insert approved additions immediately before this marker; do not move or delete it. -->

## Participant and lineup structure

Active `event_participants` types and genders: `athlete` (male, female) and `team` (mixed,
male, female). Both participant types are in active use, unlike sports where only athletes
compete.

The sport registry (`object_participants`, object='sport', objectFK=50) holds the same five
type/gender combinations. It also contains at least one row with the active flag set to `no`,
so registry membership must be filtered on that flag rather than assumed active.

Lineups are used. One lineup type is active, `14 Starter`, whose parent event participant is
a `team` and whose members are `athlete` rows of male or female gender. A team event
participant therefore resolves to its individual athletes through the lineup layer.

Split first and last name are stored through `language` types `7 first_name` and
`8 last_name`, populated for effectively the whole registered population. Many localized
full-name variants are also present, including `117 en_uk_full_name`, `9 ru`, `11 de`,
`15 se`, `77 fi`, `1 da_dk`, `5 no`, `29 fr`, `41 bg`, `17 es`, `13 it`, `3 en_uk`, `55 tc`,
`57 sc`, `84 ko`, `23 pl`, `37 pt` and `63 ge`, each covering a small subset.

`date_of_birth` coverage is the opposite case: the property exists but is populated for a
small fraction of the registered athletes. Its absence is the normal state for this sport
rather than a per-row defect, so a check asserting it reports almost the entire population.

Gender is consistent across the participant layers. A tournament stage whose gender is
`mixed` carries only `team` event participants, all of them of gender `mixed`; no athlete
takes part directly in a mixed stage. `mixed` exists as a participant gender at team level
only — no active participant of type `athlete` carries it, so an athlete is always male or
female.

A team's own gender and the gender composition of its lineup agree without exception: a
`mixed` team's lineup holds both male and female athletes, a `male` team's lineup holds only
male athletes and a `female` team's only female. The lineup is therefore the layer that
substantiates a team's declared gender, and a gender check that stops at
`event_participants` cannot see a violation of it.

Lineup size is not fixed by discipline. `Team Relay` fields both three-member and
four-member lineups, in separate events rather than mixed inside one, which is consistent
with the sport running more than one relay format under a single discipline. `Mixed Relay`
fields four. An expectation of one size per discipline therefore contradicts the confirmed
data, and size unevenness is meaningful only when measured between the teams of one event.

Team event participants are not confined to the relay disciplines. `Sprint Distance` also
carries team entries with full lineups, so the participant type of an entry cannot be
inferred from its discipline.

<!-- MANUAL PASTE ZONE: 50 PARTICIPANTS AND LINEUPS — insert approved additions immediately before this marker; do not move or delete it. -->

## Event result types

| result_code | result_typeFK | Value shape | Confirmed meaning | Evidence |
|---|---:|---|---|---|
| rank | 100 | Positive integer | Rank | Confirmed-data |
| duration | 101 | `+m:ss.f` gap, or plain full time for the leader | Duration | Confirmed-schema-data |
| comment | 104 | Closed set of status codes | Comment | Confirmed-data |
| medal | 501 | `gold` / `silver` / `bronze` | Medal | Confirmed-data |
| duration_full_time | 557 | `h:mm:ss.f` or `m:ss.f`, never plus-prefixed | Full-time duration | Confirmed-schema-data |

`101 Duration` follows the leader/gap convention: the leading participant stores a plain full
time and every other participant stores a plus-prefixed gap. Confirmed by value-pattern
distribution, where the two plain full-time patterns occur exactly once per event while the
plus-prefixed patterns occur many times per event.

`557 Full-time duration` is never plus-prefixed in any confirmed pattern; it always holds an
absolute time.

`104 Comment` is not free text. Its whole active population resolves to a closed set of
status codes marking a participant who did not finish in the classified order:

| Value | Meaning | Note |
|---|---|---|
| `DNF` | Did not finish | The dominant value by a wide margin |
| `LAP` | Lapped | |
| `DNS` | Did not start | |
| `DSQ` | Disqualified | |
| `Disq.` | Disqualified | A second spelling of `DSQ`, not a distinct status |
| `NC` | Not classified | |
| `Q` | Qualified | A progression marker rather than an invalid-result status; a negligible number of rows |

`DSQ` and `Disq.` carry the same meaning and occur in comparable volume, so neither is a
rare typo of the other; the sport stores one status under two spellings. A check reading
the Comment value must therefore treat the pair as one status, and the closed set is what
makes an allowed-value check legitimate for this field at all.

`NE` does not occur. A check keyed on it would audit an empty population.

The confirmed shape set of both time types is wider than the two forms named above. `557`
also occurs as `ss.f` with no colon at all, and `101` occurs as a plus-prefixed `ss.f` gap,
so the colon count varies from zero to two inside one result type. A check reading either
type must accept `h:mm:ss.f`, `m:ss.f` and `ss.f` alike rather than keying on a fixed number
of colons. A fractional part is present in effectively every value of both types; a value
without one is the exception rather than a parallel convention.

Shape does not imply scale. The same `ss.f` form carries a value of a few seconds in one
discipline and of tens of minutes in another, so a stored time can be judged only against
the discipline it was raced in. `Aquathlon` is the clearest case: it stores `ss.f` and
`m:ss.f` only, in both time types.

No confirmed result type carries a measured quantity. Every type the sport uses is a place,
a time, a status vocabulary or a medal code, so a check auditing a numeric result field has
nothing to read here. `GLOBAL-DQ-076` is skipped for this sport because its prerequisite is
absent, not because a parameter is unrecorded, and `NUMERIC_RESULT_TYPE_LIST` stays empty.

<!-- MANUAL PASTE ZONE: 50 EVENT RESULTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Incident types

`Not used`. `GLOBAL-DISCOVERY-008` completed successfully and returned no active incident
type or incident code combination for the sport.

<!-- MANUAL PASTE ZONE: 50 INCIDENTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Scope types and data types

`Not used`. `GLOBAL-DISCOVERY-009` and `-010` both completed successfully and returned no
active event-scope container and no active scope value row for the sport. Triathlon events
carry no internal period or segment breakdown in the scope layer.

<!-- MANUAL PASTE ZONE: 50 SCOPES — insert approved additions immediately before this marker; do not move or delete it. -->

## Properties

Confirmed active `property` owners and names, all of `property_type = 'metadata'`:

| Owner | Property names |
|---|---|
| `event` | `discipline`, `Live`, `medal_related`, `ParticipantType`, `Round`, `StartDateTimeToBeDecided`, `Type` |
| `participant` | `date_of_birth`, `height`, `IsNationalTeam`, `position`, `status`, `ToBeDecided`, `weight` |
| `tournament_stage` | `Cup`, `StatusComment` |

`Round` and `Type` exist as event properties in parallel with `event.round_typeFK` and the
gender carried by the template. They are a separate storage path and must not be assumed to
agree with the structural columns; which one is authoritative is an open question below.

`date_of_birth` is present for a small minority of the sport's active athletes, so a check
over that property covers a much smaller population than the athlete count suggests.

The `discipline` event property is not authoritative and is not a second spelling of the
`object_discipline` relation. It is absent from the majority of active events; where it is
present it disagrees with the relation on part of the population; and it carries at least
one value, `Olympic distance`, naming no row in the `discipline` catalogue at all. The
relation is the source. The property may be projected as context for a reader, but no check
may assert against it.

<!-- MANUAL PASTE ZONE: 50 PROPERTIES — insert approved additions immediately before this marker; do not move or delete it. -->

## Generic relations and disciplines

Confirmed active `object_relation` source → target pairs: `sport (1) → 153`,
`tournament_template (2) → tournament_sub_set (152)`, `tournament_stage (4) →
tournament_age_class (151)`, `statistic (83) → country (33)` and `statistic (83) →
tournament_age_class (151)`.

Seven disciplines are active, reachable from both `event` (owner type 5) and `statistic`
(owner type 83):

| Discipline | disciplineFK |
|---|---:|
| Standard Distance | 144 |
| Sprint Distance | 799 |
| Mixed Relay | 800 |
| Super Sprint Distance | 801 |
| Team Relay | 803 |
| Long Distance / Ironman | 804 |
| Aquathlon | 806 |

Discipline coverage differs sharply between the event and statistic layers. Standard Distance
dominates the statistic layer while Sprint Distance is well represented among events yet
almost absent among statistics, and Aquathlon reaches events only. A discipline-scoped check
must therefore be written against the layer it audits and must not infer one layer's
discipline population from the other.

`Aquathlon` (806) is out of DQ scope by decision of 2026-07-31. It stays documented here
because its structural evidence is confirmed; what the decision withdraws is the writing of
checks against it. A discipline-scoped check therefore names the six remaining disciplines
explicitly rather than excluding one, so a discipline added later is absent by default
instead of silently audited.

The decision is not expressed through `TIMED_DISCIPLINE_LIST`, which keeps 806. That
parameter records whether the sport measures a time in the discipline, not whether the
discipline is in scope, and narrowing it would silently restrict the already approved
`GLOBAL-DQ-045`, `-054` and `-056` instantiations. The statistic layer is unaffected in
either case: Aquathlon reaches events only.

<!-- MANUAL PASTE ZONE: 50 GENERIC RELATIONS AND DISCIPLINES — insert approved additions immediately before this marker; do not move or delete it. -->

## Statistics

| statistic_typeFK | Owner type | Participant shard | Data shard | Fields/config | Evidence |
|---:|---:|---:|---:|---|---|
| 11 (Comp.Rank) | 3 (tournament) | 11 | 11 | data 1270, 1271, 1272, 1273, 1277, 1426, 1427, 1429; config 1463, 1464, 1470, 1471 | Confirmed-schema-data |

Comp.Rank is the only statistic type the sport uses, and `tournament` is its only owner
level. The physical shard is 11 for both participants and data, confirmed by probing rather
than derived from the type (`DB-SEM-006`).

Active `statistic_data11` field types: `1270` Rank, `1271` Points, `1272` Duration, `1273`
Comment, `1277` Medal, `1426` Time, `1427` Time Difference, `1429` Team. Active
`statistic_config` field types: `1463` Start date, `1464` End date, `1470` Gender, `1471`
Event id.

`1272 Duration` is the deprecated time field and still carries active values for the sport,
in parallel with the current `1426 Time` and `1427 Time Difference`.

`1271 Points` and `1429 Team` are used by a small minority of statistics only. `1429 Team`
holds a participant ID, consistent with the team event participation confirmed above.

Rank values in `statistic_data11` are either a plain positive integer or empty; no
non-numeric rank shape occurs. Empty Rank values are present in a large share of the sport's
statistics.

Comp.Rank separates team results from athlete results, and the separation is structural
rather than only editorial: a statistic holds either `team` participants or `athlete`
participants, never both. A statistic whose name carries the `(athletes)` suffix holds the
individual athletes competing for the teams of the matching team statistic, in the same role
the lineup plays at event level. Every such statistic holds athlete participants only, and
where it declares gender `mixed` its athletes include both male and female. The suffix is a
reliable label for that population but is not exclusive to mixed events — single-gender
athlete statistics carry it as well, so gender must be read from the config value rather
than inferred from the name.

Team-holding statistics declaring gender `mixed` carry only teams of gender `mixed`.

A minority of statistics declare no Gender config value at all, at both the team and the
athlete level.

The `1273 Comment` data field resolves to the same closed set of status codes as the event
layer's `104 Comment`, including the duplicated `DSQ` / `Disq.` spelling pair and the `Q`
progression marker. The two layers are inventoried separately because nothing guarantees
they share a vocabulary, but for this sport they do, so one confirmed value set describes
both.

`1271 Points` is the only data field carrying a measured quantity, and it is an IOC-purpose
field. Outside IOC templates the field is present but holds no value at all; every value it
carries sits under an IOC template. A statistics check excludes IOC-purpose templates by
contract, so `GLOBAL-DQ-077` has an empty eligible population here by construction and
`NUMERIC_DATA_TYPE_LIST` stays empty. Recording the field would add a check whose coverage
is permanently zero, which reads as misdirected scope rather than as clean data.

<!-- MANUAL PASTE ZONE: 50 STATISTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Reference values

The `statistic_data_type` catalogue declares 40 field types for statistic type 11, of which
the sport uses 8. The remaining 32 are declared but unused, including `Laps Behind`, `Order`,
`Pair`, `Qualification rank`, `Distance`, `Penalties`, `Wind`, `Intermediate Rank`,
`Intermediate Time` and `Total time`. A declared field type is not evidence that the sport
fills it.

<!-- MANUAL PASTE ZONE: 50 REFERENCE VALUES — insert approved additions immediately before this marker; do not move or delete it. -->

## Event and round representation

Confirmed `event.status_type` / `status_descFK` combinations: `finished`/6,
`cancelled`/106, `notstarted`/1 and `notstarted`/5 (Postponed). The `notstarted` coarse
status resolves to two distinct detailed statuses, so a check keyed on the coarse value alone
conflates not-started with postponed events.

Confirmed active `event.round_typeFK` values:

| round_typeFK | Name | Note |
|---:|---|---|
| 173 | Final | The dominant round for the sport |
| 178 | Semi Finals | |
| 179 | Qualifier | |
| 180 | Repechage | |
| 284 | Final B | Placement final below the main final |
| 283 | Final C | Placement final below Final B |
| 267 | Final Phase | Multi-heat final; see below |
| 9 | Final | Knockout variant of 173, used by a handful of events |

Both members of the Final pair defined in `DB-SEM-012` occur: `173` non-knockout and `9`
knockout. The sport therefore does not use one variant consistently, and a check treating
"Final" as one ID would miss part of the population.

`267 Final Phase` does not name a single event. Its events are named `Final Stage 1`,
`Final Stage 2` and similar, with several such events under one tournament stage, so the
round represents a multi-heat final rather than one decisive race. An expectation of one
classification per Final event does not hold for this round type. At least one event under
`267` is instead named `Final 1`, so the round type also covers a differently-shaped case.

`284 Final B` and `283 Final C` are used consistently with their names, on events explicitly
named Final B and Final C.

Comp.Rank participants carry a Phase through `object_round` (object_typeFK=138,
type='phase'). Two facts distinguish the sport from one where the parallel-variant problem in
`DB-SEM-012` applies:

- Phase uses `173`, the same non-knockout Final variant the sport's events use, so Phase and
  `event.round_typeFK` agree on ID as well as on meaning. The knockout variant `9` appears in
  a negligible number of statistics.
- Phase is effectively always a Final. No Semi Finals, Qualifier, Repechage or placement round
  appears as a Phase, so the sport's Comp.Rank is built from the final round alone rather than
  from each participant's last round reached.

A minority of statistic-participant rows carry no phase row at all.

A ninth value, `204 Heats`, is carried by two events in November 2023. It is absent from the
table above because the inventory that built the table did not reach it; it is inside the
sport's contested set, so `GLOBAL-DQ-075` does not report it.

<!-- MANUAL PASTE ZONE: 50 EVENT AND ROUND REPRESENTATION — insert approved additions immediately before this marker; do not move or delete it. -->

## Confirmed sport-specific storage semantics

Tournament stages carry a direct country reference and an active `tournament_age_class`
relation. In the confirmed evidence the age class resolves to a small closed set including
`SENIOR`, and the host-country relation and city link are unpopulated where the direct
country column is filled.

Team participation is real and reaches individual athletes only through the lineup layer.
A participant-level check that joins `event_participants` directly to `participant` therefore
audits a mixture of athletes and teams, and must filter on participant type when the two
require different treatment.

<!-- MANUAL PASTE ZONE: 50 STORAGE SEMANTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Open questions

- Whether the `Round` and `Type` event properties are authoritative, derived from
  `event.round_typeFK` and the template gender, or independently maintained. They cover
  almost every active event, so a disagreement between the property and the structural column
  would be systematic rather than incidental. Their sibling `discipline` property is now
  confirmed not to be authoritative, which makes independent maintenance the more likely
  reading for the property family as a whole but does not settle it for these two.
- Why `Sprint Distance` (799) is well represented among events but almost absent among
  Comp.Rank statistics, while `Standard Distance` (144) dominates the statistic layer. Whether
  this is a real editorial difference or missing statistic coverage is not confirmed.
- Whether `Aquathlon` (806) is expected to have Comp.Rank statistics at all; it currently
  reaches the event layer only.
- Whether the `101 Duration` values that carry no plus prefix and no decimal fraction are a
  distinct storage convention or a defect. Across the six disciplines inside the sport's DQ
  scope the shape is now confirmed to be near-absent rather than frequent, so the earlier
  reading of many occurrences within a few events does not describe them. The measurement
  required an active `object_discipline` relation, so events carrying none were outside it
  and the question stays open for that remainder.
- Which round types the sport treats as decisive for a Comp.Rank, given that `267 Final Phase`
  splits one final across several events and that both Final variants `173` and `9` are in use.

<!-- MANUAL PASTE ZONE: 50 OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
