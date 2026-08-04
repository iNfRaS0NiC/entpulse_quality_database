# SPORT: Artistic Gymnastics (sport_id=40)

This file is the canonical structural record for Artistic Gymnastics. It contains only
confirmed sport-specific usage, meanings, identifiers, evidence boundaries and open
structural questions. Global database mechanisms belong in `../DATABASE.md`.

For additions, insert approved content immediately before the exact active
`MANUAL PASTE ZONE` marker in the destination subsection. Keep the marker unchanged
and at the end of its subsection. Replace existing rows or paragraphs in place when a
correction is required.

## Identity and evidence

- First discovery date: 2026-08-04
- Latest evidence date: 2026-08-04
- Verification boundary: GLOBAL discovery summaries `GLOBAL-DISCOVERY-001` through `-018`,
  `-020`, `-022`, `-024`, and `-030` through `-032`, plus round details for IDs `9` and
  `152`, event-result value-pattern summaries for result types `104`, `545`, `567`, `568`,
  and statistic-data value-pattern summaries for data types `1273` and `1456`. Detail
  statements `-021`, `-023`, `-025`, `-027`, and `-029` were not run. Exact database sport
  name `Artistic Gymnastics`; Enet sport code `ga`.

## Structural coverage

| Area | Status | Evidence |
|---|---|---|
| Core hierarchy | Used | `GLOBAL-DISCOVERY-002`, `-003` |
| Event participants | Used | `GLOBAL-DISCOVERY-004`, `-006`, `-032` |
| Event results | Used | `GLOBAL-DISCOVERY-007`, `-026` |
| Incidents | Not used | `GLOBAL-DISCOVERY-008` returned zero active rows |
| Lineups | Used | `GLOBAL-DISCOVERY-005` |
| Scope layer | Used | `GLOBAL-DISCOVERY-009`, `-010` |
| Properties | Used | `GLOBAL-DISCOVERY-011` |
| object_relation | Used | `GLOBAL-DISCOVERY-012`, `-014` |
| object_discipline | Used | `GLOBAL-DISCOVERY-013`, `-032` |
| Statistics | Used | `GLOBAL-DISCOVERY-015`, `-016`, `-017`, `-024`, `-028`, `-031` |
| Reference values | Used | `GLOBAL-DISCOVERY-030`, `-031` and the typed inventories above |
| Other tables | Not checked | |

## Tables and relation paths used

The sport uses the active core path `tournament_template` → `tournament` →
`tournament_stage` → `event` → `event_participants`. Template and stage genders in active
use are `male`, `female`, and `mixed`.

The tournament stage is the sport's **gender** carrier, not a discipline carrier. A stage is
male, female or mixed, and any stage may hold events of any apparatus; discipline lives on
the event through `object_discipline`. `GLOBAL-DQ-082` is therefore `Not applicable` here,
because it asserts a stage-level discipline grouping this sport does not store. That is a
property of how the sport organises competition rather than of the current data.

The IOC-purpose templates `12886` and `12887` (World Championships Artistic (IOC)) and
`12890` and `12891` (World Cup (IOC)) reach active tournaments but no active stage or event
in the current complete hierarchy inventory. Their tournament presence therefore does not
establish event coverage.

<!-- MANUAL PASTE ZONE: 40 TABLES AND RELATIONS — insert approved additions immediately before this marker; do not move or delete it. -->

## Participant and lineup structure

Active event participants are `athlete` rows of male or female gender and `team` rows of
male, female, or mixed gender. The sport registry (`object_participants`, object=`sport`,
objectFK=`40`) uses the participant roles `athlete` and `team`, and contains both `yes` and
`no` active flags; registry membership must therefore be filtered explicitly.

Lineups are used through `14 Starter`. The parent event participant is a `team`, while the
lineup members are male or female `athlete` rows.

Artistic Gymnastics is a listing sport at event level: ranked multi-entry fields are stored
through result type `100 Rank`. Both individuals and teams participate, so the competition
model is `Listing (individual and team)`, not a fixed two-side H2H model.

`GLOBAL-DQ-068` is a `Monitor` for this sport. Two teams with populated Starter lineups in
the same event may legitimately expose different roster sizes, so the difference itself is
population context rather than proof that one team row is defective. A team event participant
with no lineup at all remains an actionable absence under `GLOBAL-DQ-058`.

`GLOBAL-DQ-043` is also a `Monitor`. Its athlete and lineup-member gender contradictions
remain actionable drill-down rows, but its complete output also includes mixed team entities
whose generic participant gender is not authoritative for a male or female stage. The team
role must be resolved before those rows can identify a repair.

<!-- MANUAL PASTE ZONE: 40 PARTICIPANTS AND LINEUPS — insert approved additions immediately before this marker; do not move or delete it. -->

## Event result types

| result_code | result_typeFK | Value shape | Confirmed meaning | Evidence |
|---|---:|---|---|---|
| rank | 100 | Not checked | Rank | Confirmed-data |
| points | 102 | Not checked | Points | Confirmed-data |
| comment | 104 | Status/progression text and digit-bearing variants; valid vocabulary not closed | Comment | Confirmed-data (`007`, `026`) |
| medal | 501 | Not checked | Medal | Confirmed-data |
| penalties | 545 | Numeric integer/decimal patterns observed; valid domain not established | Penalties | Confirmed-data (`007`, `026`) |
| penalty | 567 | Numeric integer/decimal patterns observed; valid domain not established | Penalty | Confirmed-data (`007`, `026`) |
| dscore | 568 | Numeric integer/decimal patterns observed; valid domain not established | DScore | Confirmed-data (`007`, `026`) |
| escore | 569 | Not checked | Escore | Confirmed-data |
| bonus | 645 | Not checked | Bonus | Confirmed-data |

The `104 Comment` vocabulary is closed as of 2026-08-04. The exact literals in active use
outside IOC-purpose templates are `Q`, `Q1` through `Q8`, `R`, `R1` through `R4`, `DNS`,
`DNF`, `NR`, `NC`, `Disq.`, `Withdrawn`, and `From Vault 1`. Of these, `DNS`, `DNF`, `Disq.`,
`Withdrawn`, `NC` and `NR` mean the participant holds no classified result; the `Q` and `R`
forms are progression markers and do not.

`From Vault 1` is deliberately left out of `RESULT_COMMENT_VALUE_LIST`: it is a sentence
rather than a status code, so it is surfaced as a finding rather than blessed as vocabulary.
The list also carries the full `Q1`-`Q8` and `R1`-`R4` ranges even where a given member has
no row today, because an unused member of a confirmed range is a row count and not a
structural absence.

The sport is judged rather than timed. No result type records elapsed time or a gap to the
leader, and no apparatus is decided on the clock, so `RESULT_FULL_TIME_TYPE_ID`,
`RESULT_DURATION_TYPE_ID` and `TIMED_DISCIPLINE_LIST` are recorded under `_notApplicable`.
`GLOBAL-DQ-052` reads a full time and a duration alongside the Comment and is therefore
permanently unrunnable here; `GLOBAL-DQ-076` asserts the same numeric-field rule without
them and is instantiated instead. `102 Points` is the sport's only numeric result type
inside DQ scope, Extended Results being outside it by the decision below.

Result types `545 Penalties`, `567 Penalty`, `568 DScore`, `569 Escore`, and `645 Bonus`
belong to Extended Results. By explicit decision of 2026-08-04 they remain in the confirmed
structural inventory but are outside the initial Artistic Gymnastics DQ scope. This boundary
assigns no check and does not classify the fields as unused.

`GLOBAL-DQ-053` is a `Monitor` for this sport. Event-layer Medal and Rank values include
tie and ordinal-storage shapes in which a direct Gold=1, Silver=2, Bronze=3 comparison is
not sufficient to classify one participant row as defective. Exact swapped medal/rank pairs
remain drill-down targets, but the mismatch row alone is not the repair unit.

`GLOBAL-DQ-037` is a `Monitor` for the same tie-aware reason at event-set level. Legitimate
ties and duplicated bronze placements prevent the aggregate invalid-set result from being a
direct repair list; no-medal, contradictory and missing-medal subtypes remain useful
drill-down targets. `GLOBAL-DQ-049` is likewise monitored because legitimate `All-Around`
and `All-Round` compounds dominate its generic name-format output, while double spaces and
Cyrillic lookalikes remain actionable subtypes.

<!-- MANUAL PASTE ZONE: 40 EVENT RESULTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Incident types

`Not used`. `GLOBAL-DISCOVERY-008` completed successfully and returned no active incident
type or incident code combination for the sport.

<!-- MANUAL PASTE ZONE: 40 INCIDENTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Scope types and data types

Active event-scope containers use `101 checkpoint1` and `102 checkpoint2`. Both container
types store participant-owned values in `scope_result` with the same field inventory:

| scope_data_typeFK | Name |
|---:|---|
| 1 | rank |
| 2 | points |
| 3 | comment |
| 86 | penalties |
| 1069 | dscore |
| 1070 | escore |
| 1076 | penalty |
| 1077 | bonus |

`event_scope_detail` is used with detail name `name`. No active `lineup_scope_result` layer
was returned by the complete scope-layer inventory; lineup-owned scope values are therefore
`Not used` in this evidence.

The checkpoint layer is a Vault-only structure. Of the 443 finished events carrying an active
container, 442 hold discipline `90 Vault` and one is a single `91 Uneven Bars` event from
2018; the other nine disciplines hold no active container at all. `checkpoint1` and
`checkpoint2` therefore correspond to the two vaults a gymnast performs, not to a general
per-exercise breakdown. The two container types never occur apart: an event holds both or
neither. Containers first appear in 2011 on Finals, are absent across 2015 to 2017, and
resume in 2018 for Finals and Qualifiers alike, where between 54% and 100% of Vault events
carry one depending on the year.

By explicit decision of 2026-08-04 the checkpoint scope layer is outside Artistic Gymnastics
DQ scope. `event_scope`, `scope_result` and `event_scope_detail` stay in the confirmed
structural inventory above, and no DQ check reads them for this sport. `GLOBAL-DQ-102` was
instantiated as `Artistic-Gymnastics-DQ-008` before the decision and is now `Deprecated` in
`POWERBI_REGISTRY.md`; the ID stays permanently reserved. `GLOBAL-DQ-107` and the
period-score templates `GLOBAL-DQ-085`, `-086`, `-089`, `-091` and `-092` are not
instantiated. This boundary assigns no check and does not classify the scope fields as
unused.

<!-- MANUAL PASTE ZONE: 40 SCOPES — insert approved additions immediately before this marker; do not move or delete it. -->

## Properties

Confirmed active `property` names, all with `type='metadata'`:

| Owner | Property names |
|---|---|
| `event` | `checkpoints`, `checkpoint_details`, `discipline`, `ElapsedTime`, `Heat`, `Live`, `medal_related`, `ParticipantType`, `Round`, `Type` |
| `participant` | `date_of_birth`, `discipline`, `height`, `IsNationalTeam`, `status`, `ToBeDecided`, `weight` |
| `tournament_stage` | `Cup`, `StatusComment` |

No active tournament-owned property was returned. The event properties `discipline`,
`ParticipantType`, `Round`, and `Type` exist in parallel with typed relation or hierarchy
fields; their agreement and authority were not tested.

<!-- MANUAL PASTE ZONE: 40 PROPERTIES — insert approved additions immediately before this marker; do not move or delete it. -->

## Generic relations and disciplines

Confirmed active `object_relation` source → target pairs:

- `tournament_template (2) → tournament_sub_set (152)`;
- `tournament_stage (4) → country (33)`;
- `tournament_stage (4) → tournament_age_class (151)`;
- `statistic (83) → country (33)`;
- `statistic (83) → tournament_age_class (151)`.

The same eleven disciplines are attached through `object_discipline` to events (owner type
`5`) and tournament-owned statistics (owner type `83`). The complete observed event matrix is:

| disciplineFK | Discipline | Stage gender | Event participant type |
|---:|---|---|---|
| 82 | Team All-Around | male, female | team |
| 84 | Floor Exercise | male, female | athlete |
| 85 | Pommel Horse | male | athlete |
| 86 | Rings | male | athlete |
| 87 | Balance Beam | female | athlete |
| 88 | Horizontal Bar | male | athlete |
| 89 | Parallel Bars | male | athlete |
| 90 | Vault | male, female | athlete |
| 91 | Uneven Bars | female | athlete |
| 96 | Individual All-Around Artistic | male, female | athlete |
| 798 | Mixed Team | mixed | team |

This matrix records confirmed observed combinations; it does not assert that an unobserved
combination is impossible in the sport.

<!-- MANUAL PASTE ZONE: 40 GENERIC RELATIONS AND DISCIPLINES — insert approved additions immediately before this marker; do not move or delete it. -->

## Statistics

| statistic_typeFK | Owner type | Participant shard | Data shard | Fields/config | Evidence |
|---:|---:|---:|---:|---|---|
| 11 (Comp.Rank) | 3 (tournament) | 11 | 11 | data 1270, 1271, 1273, 1277, 1278, 1429, 1456; config 1463, 1464, 1470, 1471 | Confirmed-schema-data |

Comp.Rank is the only statistic type returned by the known owner-path inventory and
`tournament` is its only confirmed owner level. Physical shard `11` was established
empirically rather than inferred from the statistic type (`DB-SEM-006`).

Active `statistic_data11` fields are `1270 Rank`, `1271 Points`, `1273 Comment`, `1277 Medal`,
`1278 Qualification rank`, `1429 Team`, and `1456 Running Score`. Active `statistic_config`
fields are `1463 Start date`, `1464 End date`, `1470 Gender`, and `1471 Event id`.

Only five of those data fields are in DQ scope: `1270 Rank`, `1271 Points`, `1273 Comment`,
`1277 Medal` and `1429 Team`. `1278 Qualification rank` is an IOC-purpose field — all 29514
of its active rows sit under IOC-purpose templates, which every statistics statement
excludes, so it is unreachable by a DQ check rather than merely unused. `1456 Running Score`
is a different case and is not IOC-only: it holds 128024 active rows outside those templates,
every one of them empty.

**Phase is used, and is not a `statistic_data` field.** It is stored in `object_round` with
`object_typeFK = 138` and `type = 'phase'`, the mechanism `DATABASE.md` records as the only
storage for the concept: the round a Comp.Rank participant's rank was taken from. Outside
IOC-purpose templates, 159088 of the sport's 159096 Comp.Rank participant rows carry one, so
`GLOBAL-DQ-033` is actionable rather than population-wide — the eight rows without a phase
are a repair list.

Confirmed active phase rounds are `179 Qualifier`, `173 Final`, `9 Final`, `172 Tie-breaker`
and `152 Qualifier`. `172 Tie-breaker` occurs **only** as a Comp.Rank phase and never as an
event `round_typeFK`, so it belongs to the sport's round inventory through this path alone.
Its `knockout = yes` flag is correct: a tie-breaker is an elimination round, unlike the
sport's Final and Qualifier rounds, which is why `tie-breaker` is the sole member of
`ELIMINATION_ROUND_NAME_LIST` here. `GLOBAL-DQ-083` does not judge it today, because
`GLOBAL-DQ-097` reaches round types through events and no event is contested under `172`.

`1273 Comment` uses active empty rows as a stored state. Its literal vocabulary outside
IOC-purpose templates is `R`, `R1` through `R4`, `Q`, `Q4`, `Q7`, `Q8`, `DNS`, `DNF`, `NR`,
`NC`, `Disq.` and `Withdrawn`, and the same six of those mean no classified result as at the
event layer. `DNQ` and `DQB` appear in the sport's overall inventory but not in this
population: they occur under IOC-purpose templates, which every statistics statement
excludes. Both stay in `DATA_COMMENT_VALUE_LIST` together with the full `Q1`-`Q8` and
`R1`-`R4` ranges, because a member with no row in the audited population is a row count
rather than a structural absence.

`GLOBAL-DQ-057` is the statistic-layer twin of the Comment rule and reads a Time data field
this sport does not store, so it is permanently unrunnable here for the same reason
`GLOBAL-DQ-052` is at the event layer.

`1456 Running Score` has active rows, but its complete current value-pattern
inventory contains only the empty state; no non-empty active use was confirmed.

`GLOBAL-DQ-072` is a `Monitor` for this sport. Comp.Rank medal rows commonly occur in
tie-aware, ordinal or team-inherited result shapes, so a medal whose stored Rank is shifted
from the simple 1/2/3 mapping is not automatically one independent defect. Non-standard
deltas and broken ranking sequences remain the rows to prioritise within that monitored
population.

`GLOBAL-DQ-026` monitors the aggregate Comp.Rank medal-set population because legitimate
ties, duplicated bronze placements and team-inherited medal rows can all create repeated
holders. Missing and contradictory medal subtypes remain drill-down targets.

`GLOBAL-DQ-044` is a `Monitor`: athlete-statistic gender contradictions are actionable, but
mixed-gender team entities require team-role semantics before their appearance in a male or
female Comp.Rank can be called defective. `GLOBAL-DQ-051` is also monitored because the
generic statistic-name rule includes legitimate hyphenated and diacritic-bearing names;
double spaces and Cyrillic lookalikes remain actionable drill-down subtypes.

`GLOBAL-DQ-065` is a `Monitor` for the same reason its event-layer twin `GLOBAL-DQ-068` is.
Teams competing in one Artistic Gymnastics competition legitimately field different numbers
of gymnasts, so an uneven athlete count across the teams of one Comp.Rank is population
context rather than proof that one team is entered incompletely. The proportion of uneven
teams is the reading; a single team row is not the repair unit.

<!-- MANUAL PASTE ZONE: 40 STATISTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Reference values

| Catalog | Confirmed IDs and names |
|---|---|
| `result_type` | `100 Rank`; `102 Points`; `104 Comment`; `501 Medal`; `545 Penalties`; `567 Penalty`; `568 DScore`; `569 Escore`; `645 Bonus` |
| `lineup_type` | `14 Starter` |
| `scope_type` | `101 checkpoint1`; `102 checkpoint2` |
| `scope_data_type` | `1 rank`; `2 points`; `3 comment`; `86 penalties`; `1069 dscore`; `1070 escore`; `1076 penalty`; `1077 bonus` |
| `round_type` | `9 Final`; `152 Qualifier`; `173 Final`; `179 Qualifier`; `172 Tie-breaker` (Comp.Rank phase only) |
| `discipline` | `82 Team All-Around`; `84 Floor Exercise`; `85 Pommel Horse`; `86 Rings`; `87 Balance Beam`; `88 Horizontal Bar`; `89 Parallel Bars`; `90 Vault`; `91 Uneven Bars`; `96 Individual All-Around Artistic`; `798 Mixed Team` |
| `tournament_age_class` | `1 SENIOR`; `2 YOUTH`; `3 JUNIOR` |
| `statistic_type` | `11 Comp.Rank` |
| `statistic_data_type` (data) | `1270 Rank`; `1271 Points`; `1273 Comment`; `1277 Medal`; `1278 Qualification rank`; `1429 Team`; `1456 Running Score` |
| `statistic_data_type` (config) | `1463 Start date`; `1464 End date`; `1470 Gender`; `1471 Event id` |
| `status_desc` | `6 Finished`; `106 Cancelled` |

<!-- MANUAL PASTE ZONE: 40 REFERENCE VALUES — insert approved additions immediately before this marker; do not move or delete it. -->

## Event and round representation

Confirmed active coarse/detailed event-status pairs are `finished → 6 Finished` and
`cancelled → 106 Cancelled`.

The complete active event-round inventory contains two different IDs named `Final` (`9`,
`173`) and two named `Qualifier` (`152`, `179`). Round identity must therefore be read from
`round_typeFK`, not from the display name alone. Detail runs for `9` and `152` confirm both
as active event values across more than one competition context; they are not unused legacy
references.

Both confirmed Final IDs, `9` and `173`, are medal-awarding rounds for this sport and form
the approved `MEDAL_ROUND_TYPE_LIST`. The non-medal Qualifier IDs remain outside that list.

<!-- MANUAL PASTE ZONE: 40 EVENT AND ROUND REPRESENTATION — insert approved additions immediately before this marker; do not move or delete it. -->

## Confirmed sport-specific storage semantics

In the complete current stage inventory, every active stage has a direct
`tournament_stage.countryFK` and exactly one age-class relation through
`object_relation 4 → 151`. The confirmed age classes are `SENIOR`, `YOUTH`, and `JUNIOR`.
`city_object` is also used for stages, but only on a subset. Host country through
`object_relation 4 → 33` is a separate, sparsely used path; every observed host-country link
agrees with the same stage's direct country.

`GLOBAL-DQ-034` is a `Monitor` for that reason. It asserts five stage fields at once, and
822 of the sport's 824 stages are reported for the host-country relation alone while their
direct `tournament_stage.countryFK` is present. The proportion carrying the separate relation
is the reading; a single stage row is not a repair unit.

The sport stores judged output in parallel layers: event-participant `result` rows and
participant-owned checkpoint `scope_result` rows use corresponding rank, points, comment,
penalty, D-score, E-score, and bonus concepts. The two layers are independent storage and
their values were not tested for equality.

Tournament-owned Comp.Rank statistics attach country and age class through
`object_relation` and discipline through `object_discipline`. These are separate metadata
paths from the event hierarchy.

Tournament-stage dates are a containing competition window: they may begin before the
earliest event start or end after the latest one. `GLOBAL-DQ-004` is therefore a `Monitor`
for this sport while it compares exact endpoints; a wider containing stage interval is not
itself a boundary defect.

The generic name-format checks require language-aware interpretation. `GLOBAL-DQ-048` is a
`Monitor` because valid compound and geographic names include forms such as `All-Around`,
`Tel-Aviv`, and `São Paulo`. `GLOBAL-DQ-079` is a `Monitor` because the legitimate template
compound `World Cup All-Around` is sufficient to trigger its generic rule.

Summer Olympics tournaments `14678` and `36693` are the confirmed postponed editions whose
stored tournament name is `2020` while their stages took place in 2021. The
`Artistic-Gymnastics-DQ-029` instance of `GLOBAL-DQ-080` excludes exactly those two IDs from
both findings and coverage; the check remains active for every future tournament-season
contradiction.

<!-- MANUAL PASTE ZONE: 40 STORAGE SEMANTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Open questions

- Whether event properties `discipline`, `ParticipantType`, `Round`, and `Type` agree with,
  or are derived from, their corresponding typed relations and hierarchy fields.
- What semantic distinction determines use of event result types `545 Penalties` and
  `567 Penalty`; both are Extended Results and their detailed interpretation is deferred.
- Whether the `checkpoints` and `checkpoint_details` event properties describe the same two
  vaults the checkpoint containers hold, and which path is authoritative. The containers are
  now confirmed Vault-only, but the two properties were not profiled and the layer is outside
  DQ scope, so the question stays open without a check attached to it.
- Whether `1456 Running Score` is intentionally instantiated as an empty reserved field or
  is expected to receive values in a competition format not present in the current evidence.
  Its shape is now measured — 128024 active rows outside IOC-purpose templates, every one of
  them empty — which rules out the field being merely IOC-confined but does not say why it is
  instantiated at all.
- Whether the sparse stage host-country relation is intentional duplication of the direct
  country or a separately maintained field. The proportion is now measured: 822 of 824 stages
  carry no host-country relation while their direct `countryFK` is present, which is why
  `GLOBAL-DQ-034` is a `Monitor`. Whether the relation is meant to be populated at all is the
  part still open.
- The row-level co-occurrence of country, age class, and discipline metadata on Comp.Rank
  statistics; the three paths are used, but their alignment on the same statistics was not
  tested.
- Why `172 Tie-breaker` appears only as a Comp.Rank phase and never as an event
  `round_typeFK`. The round is a legitimate elimination round and its `knockout = yes` flag is
  correct, but no event in the sport is contested under it, so a rank derived from a
  tie-breaker has no event to point back to.
- Whether the eight Comp.Rank rows without a phase and the 18 medals recorded against a
  Qualifier phase share one cause. Both sets are now reported by `Artistic-Gymnastics-DQ-087`
  and `-088`; the first is confined to a single statistic, which reads as one broken import.
- Event-name, stage-name, statistic-name, and anomalous value-pattern details remain
  unclassified because `GLOBAL-DISCOVERY-021`, `-023`, `-025`, `-027`, and `-029` were not
  run.

<!-- MANUAL PASTE ZONE: 40 OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
