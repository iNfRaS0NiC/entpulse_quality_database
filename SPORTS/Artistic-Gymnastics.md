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

The complete current `104 Comment` pattern inventory contains status and progression forms
such as `Q`, `R`, digit-bearing `R#` and `Q#`, `DNS`, `DNF`, `NR`, `NC`, `From Vault #`,
`Disq.`, and `Withdrawn`. These are digit-normalized patterns, not a confirmed closed list
of exact literals or meanings.

Result types `545 Penalties`, `567 Penalty`, `568 DScore`, `569 Escore`, and `645 Bonus`
belong to Extended Results. By explicit decision of 2026-08-04 they remain in the confirmed
structural inventory but are outside the initial Artistic Gymnastics DQ scope. This boundary
assigns no check and does not classify the fields as unused.

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
`Not used` in this evidence. The Extended Results decision above applies only to the five
confirmed event `result_typeFK` values and does not classify these separate scope fields.

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

`1273 Comment` uses active empty rows as a stored state and also carries digit-normalized
status/progression patterns including `DNQ`, `R`, `R#`, `Q`, `Q#`, `DNS`, `DNF`, `NR`, `NC`,
`Disq.`, `Withdrawn`, and `DQB`. The exact literal vocabulary and meanings are not fully
resolved. `1456 Running Score` has active rows, but its complete current value-pattern
inventory contains only the empty state; no non-empty active use was confirmed.

<!-- MANUAL PASTE ZONE: 40 STATISTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Reference values

| Catalog | Confirmed IDs and names |
|---|---|
| `result_type` | `100 Rank`; `102 Points`; `104 Comment`; `501 Medal`; `545 Penalties`; `567 Penalty`; `568 DScore`; `569 Escore`; `645 Bonus` |
| `lineup_type` | `14 Starter` |
| `scope_type` | `101 checkpoint1`; `102 checkpoint2` |
| `scope_data_type` | `1 rank`; `2 points`; `3 comment`; `86 penalties`; `1069 dscore`; `1070 escore`; `1076 penalty`; `1077 bonus` |
| `round_type` | `9 Final`; `152 Qualifier`; `173 Final`; `179 Qualifier` |
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

<!-- MANUAL PASTE ZONE: 40 EVENT AND ROUND REPRESENTATION — insert approved additions immediately before this marker; do not move or delete it. -->

## Confirmed sport-specific storage semantics

In the complete current stage inventory, every active stage has a direct
`tournament_stage.countryFK` and exactly one age-class relation through
`object_relation 4 → 151`. The confirmed age classes are `SENIOR`, `YOUTH`, and `JUNIOR`.
`city_object` is also used for stages, but only on a subset. Host country through
`object_relation 4 → 33` is a separate, sparsely used path; every observed host-country link
agrees with the same stage's direct country.

The sport stores judged output in parallel layers: event-participant `result` rows and
participant-owned checkpoint `scope_result` rows use corresponding rank, points, comment,
penalty, D-score, E-score, and bonus concepts. The two layers are independent storage and
their values were not tested for equality.

Tournament-owned Comp.Rank statistics attach country and age class through
`object_relation` and discipline through `object_discipline`. These are separate metadata
paths from the event hierarchy.

<!-- MANUAL PASTE ZONE: 40 STORAGE SEMANTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Open questions

- Whether event properties `discipline`, `ParticipantType`, `Round`, and `Type` agree with,
  or are derived from, their corresponding typed relations and hierarchy fields.
- What semantic distinction determines use of event result types `545 Penalties` and
  `567 Penalty`; both are Extended Results and their detailed interpretation is deferred.
- Whether the checkpoint containers and the `checkpoints` / `checkpoint_details` event
  properties describe the same exercises, and which path is authoritative.
- Whether `1456 Running Score` is intentionally instantiated as an empty reserved field or
  is expected to receive values in a competition format not present in the current evidence.
- Whether the sparse stage host-country relation is intentional duplication of the direct
  country or a separately maintained field.
- The row-level co-occurrence of country, age class, and discipline metadata on Comp.Rank
  statistics; the three paths are used, but their alignment on the same statistics was not
  tested.
- Event-name, stage-name, statistic-name, and anomalous value-pattern details remain
  unclassified because `GLOBAL-DISCOVERY-021`, `-023`, `-025`, `-027`, and `-029` were not
  run.

<!-- MANUAL PASTE ZONE: 40 OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
