# Enetpulse Sports-Content Database

## Purpose and boundary

This is the single canonical file for global database structure:

- tables and important columns;
- direct relations;
- polymorphic relation models;
- confirmed generic relation triples;
- storage layers and sharding;
- structural behavior that spans several tables.

It does not contain sport-specific usage, PowerBI checks, DQ proposals, validation
thresholds, repair instructions, Builder documentation, audit tooling or the
`standing`, `standing_participants` and `standing_data` table family. Confirmed
competition-ranking structures remain in scope when they describe database storage.

## Verification language

| Status | Meaning |
|---|---|
| `Confirmed-schema` | Table/column/relation shape confirmed from schema metadata |
| `Confirmed-data` | Mechanism confirmed from real database rows |
| `Confirmed-schema-data` | Independently confirmed from both |
| `Observed-sport` | Confirmed only for a named sport; belongs in its sport file |
| `Open question` | Not sufficiently confirmed |

The presence of an FK-like column does not by itself confirm physical FK enforcement,
cardinality, mandatory status, nullability or uniqueness. Unless explicitly stated,
those properties remain open.

## Manual additions

The AI assistant never edits this file. It retains every eligible confirmed global
finding as pending and returns a consolidated ready-to-paste Markdown block only after
an explicit `PREPARE_DOC_UPDATE` command. The block names the exact marker below.
Sport-only evidence belongs in `SPORTS/<SportSlug>.md`, not here.
Every marker is a fixed lower boundary at the end of its section. Insert additions
immediately before the exact marker; never after it. Replace existing content in place.

---

## 1. Core hierarchy

```text
sport
  -> tournament_template
      -> tournament
          -> tournament_stage
              -> event
                  -> event_participants
                      -> participant
```

`event_participants` is the bridge representing one participant's presence in one
event. Results, incidents and lineups attach to this bridge. Scope containers attach to
the event and their value rows identify either an event participant or a lineup row.

### `sport`

Top-level sport reference.

| Important column | Structural meaning |
|---|---|
| `id` | Primary identifier |
| `name` | Sport name |
| `enetSportCode` | External/provider sport code |
| `del` | Soft-delete flag |

### `tournament_template`

Reusable competition definition under a sport.

| Important column | Structural meaning |
|---|---|
| `id` | Primary identifier |
| `sportFK` | Parent sport |
| `name` | Template name |
| `gender` | Template-level gender/category value |
| `del` | Soft-delete flag |

### `tournament`

Competition edition/season created from a tournament template.

| Important column | Structural meaning |
|---|---|
| `id` | Primary identifier |
| `tournament_templateFK` | Parent template |
| `name` | Tournament name |
| `enetSeasonID` | External/provider season identifier |
| `locked` | Stored lock state |
| `del` | Soft-delete flag |

Confirmed date placement: `tournament` does not carry the stage start/end date range.
That range is stored on `tournament_stage`.

### `tournament_stage`

Stage/container inside a tournament.

| Important column | Structural meaning |
|---|---|
| `id` | Primary identifier |
| `tournamentFK` | Parent tournament |
| `name` | Stage name |
| `gender` | Stage-level gender/category value |
| `countryFK` | Direct country reference |
| `startdate`, `enddate` | Stage date range |
| `enetID` | External/provider identifier |
| `locked` | Stored lock state |
| `del` | Soft-delete flag |

Tournament age class is not stored in a direct age-class column. Its confirmed
mechanism is `object_relation 4 -> 151`.

### `event`

Individual match, race, heat, round or other competition event.

| Important column | Structural meaning |
|---|---|
| `id` | Primary identifier |
| `tournament_stageFK` | Parent stage |
| `name` | Event name |
| `startdate` | Event start date/time |
| `status_type` | Coarse status value |
| `status_descFK` | Detailed status reference |
| `round_typeFK` | Round-type reference |
| `locked` | Stored lock state |
| `del` | Soft-delete flag |

The confirmed event table has `startdate`; an event end-date column was not confirmed.

### `event_participants`

Bridge between an event and a participant.

| Important column | Structural meaning |
|---|---|
| `id` | Bridge-row identifier |
| `eventFK` | Event |
| `participantFK` | Participant entered in the event |
| `number` | Separate stored display/order-related value; semantics vary by usage |
| `del` | Soft-delete flag |

Confirmed child mechanisms: `result`, `incident`, `lineup` and the participant-owned
scope value path.

### `participant`

Generic participant entity used for teams, athletes and other roles.

| Important column | Structural meaning |
|---|---|
| `id` | Participant identifier |
| `name` | Participant name |
| `type` | Participant type |
| `gender` | Participant gender/category value |
| `countryFK` | Direct country reference |
| `enetID`, `enetSportID` | External/provider identifiers |
| `del` | Soft-delete flag |

Observed values are not exhaustive enums. Previously observed participant types include
`team`, `athlete`, `coach`, `official`, `organization`, `horse`, `dog` and `undefined`.
Previously observed gender/category values include `male`, `female`, `mixed`,
`undefined`, `mare`, `stallion` and `gelding`.

<!-- MANUAL PASTE ZONE: DATABASE CORE STRUCTURE — insert approved additions immediately before this marker; do not move or delete it. -->

---

## 2. Event participant data

### `result`

Stores a named result field/value for an `event_participants` row.

| Important column | Structural meaning |
|---|---|
| `id` | Result-row identifier |
| `event_participantsFK` | Parent event-participant row |
| `result_typeFK` | Result-type reference |
| `result_code` | Stored result code |
| `value` | Text result value |
| `del` | Soft-delete flag |

Structural states are distinct:

| State | Row | `del` | `value` |
|---|---|---|---|
| No row | absent | n/a | n/a |
| Soft-deleted row | present | `yes` | any value |
| Active empty row | present | `no` | `NULL` or `''` |
| Active populated row | present | `no` | non-empty text |

`event_participants.number` and a rank-like `result` row are separate storage
locations. Neither proves the other exists or is active. More than one physical active
result row for the same logical code has been observed, so uniqueness must not be
assumed without schema evidence.

The meaning and format of `result_code`, `result_typeFK` and `value` are sport-specific.

### `result_type`

Reference selected by `result.result_typeFK`. The relation is confirmed from data; the
complete table schema and global code-to-type uniqueness remain open.

### `incident`

Stores an incident for one event-participant row.

| Important column | Structural meaning |
|---|---|
| `id` | Incident identifier |
| `event_participantsFK` | Parent event-participant row |
| `incident_typeFK` | Incident-type reference |
| `incident_code` | Stored incident code |
| `ref_participantFK` | Additional participant-like reference; target not globally confirmed |
| `elapsed`, `elapsed_plus` | Stored elapsed components; meaning/format open |
| `sortorder` | Stored ordering value |
| `del` | Soft-delete flag |

### `lineup`

Stores a participant inside an event entry, normally a player/athlete belonging to a
team participant for that event.

| Important column | Structural meaning |
|---|---|
| `id` | Lineup-row identifier |
| `event_participantsFK` | Parent event entry |
| `participantFK` | Participant placed in the lineup |
| `lineup_typeFK` | Lineup-type reference |
| `shirt_number` | Stored shirt number |
| `pos`, `enet_pos` | Stored position values |
| `del` | Soft-delete flag |

The participant types allowed inside lineups must be discovered per sport.

<!-- MANUAL PASTE ZONE: DATABASE EVENT PARTICIPANT DATA — insert approved additions immediately before this marker; do not move or delete it. -->

---

## 3. Generic object models

### Text discriminator model

```text
object   = '<owner table/name>'
objectFK = <ID in that owner table>
```

The same numeric `objectFK` can identify different records under different `object`
values. It must never be interpreted without the discriminator.

#### `property`

Generic key/value metadata.

| Important column | Structural meaning |
|---|---|
| `id` | Property-row identifier |
| `object`, `objectFK` | Text-polymorphic owner |
| `type` | Stored property type/category |
| `name` | Property key |
| `value` | Property value |
| `del` | Soft-delete flag |

Confirmed owner values in current evidence: `event`, `tournament`,
`tournament_stage` and `participant`. Other owners remain open until discovered.

#### `object_participants`

Generic participant-to-owner relation.

| Important column | Structural meaning |
|---|---|
| `id` | Relation-row identifier |
| `object`, `objectFK` | Owner/container |
| `participantFK` | Linked participant |
| `participant_type` | Role in the relation |
| `date_from`, `date_to` | Stored validity interval |
| `active` | Active flag independent from `del` |
| `del` | Soft-delete flag |

Confirmed owner patterns include `sport`, `participant`, `tournament_template`,
`tournament`, `tournament_stage`, `event` and `venue`.

Team-roster shape:

```text
object='participant'
objectFK=<team participant.id>
participantFK=<member participant.id>
```

### Numeric discriminator model

```text
object_typeFK = <numeric owner type>
objectFK      = <ID in the owner table>
```

#### `object_relation`

Directional generic object-to-object relation.

| Important column | Structural meaning |
|---|---|
| `id` | Relation-row identifier |
| `object_typeFK`, `objectFK` | Source type and source ID |
| `rel_object_typeFK`, `rel_objectFK` | Target type and target ID |
| `order` | Stored ordering value |
| `del` | Soft-delete flag |

Relation direction must be queried exactly as confirmed. The existence of an
`object_type` entry does not prove that a corresponding relation triple is populated.

#### `object_discipline`

Specialized relation from an owner object to `discipline`.

| Important column | Structural meaning |
|---|---|
| `object_typeFK`, `objectFK` | Owner type and owner ID |
| `disciplineFK` | Discipline reference |
| `del` | Soft-delete flag |

Confirmed owner types: event (`5`) and, in limited statistic-type evidence, statistic
(`83`). Event discipline and statistic discipline are independent relations.

#### `language`

Generic text-polymorphic translation store, structurally parallel to `property`.

| Important column | Structural meaning |
|---|---|
| `id` | Language-row identifier |
| `object`, `objectFK` | Text-polymorphic owner |
| `language_typeFK` | Reference to `language_type` (field/language variant) |
| `name` | Translated/localized value |
| `locked` | Stored lock state |
| `del` | Soft-delete flag |

Confirmed active owner value: `participant`. `language_type` includes per-language
full-name translations (e.g. `da_dk`, `en_uk`, `ru`, `de`, `fr`, `bg`) and split
first/last name variants: generic `first_name` (7)/`last_name` (8), plus
language-specific splits such as `no_first_name` (97)/`no_last_name` (98) and
`da_dk_first_name` (110)/`da_dk_last_name` (111).

#### `city` and `city_object`

`city` is a reference table (`id, name, countryFK, latitude, longitude, area_code,
population, del`). `city_object` is a numeric polymorphic bridge linking a city to an
owner object:

| Important column | Structural meaning |
|---|---|
| `id` | Link identifier |
| `object_typeFK`, `objectFK` | Owner type and owner ID |
| `cityFK` | Linked city |
| `city_object_typeFK` | Role/type of the city link |
| `latitude`, `longitude` | Stored coordinate override |
| `del` | Soft-delete flag |

Confirmed active owner types: `15` (participant), `83` (statistic), `4` (tournament_stage).

<!-- MANUAL PASTE ZONE: DATABASE GENERIC OBJECT MODELS — insert approved additions immediately before this marker; do not move or delete it. -->

---

## 4. Statistics

### `statistic`

Statistic definition owned through the numeric polymorphic model.

| Important column | Structural meaning |
|---|---|
| `id` | Statistic identifier |
| `object_typeFK`, `objectFK` | Statistic owner type and owner ID |
| `statistic_typeFK` | Statistic category/type identifier |
| `name` | Statistic name |
| `del` | Soft-delete flag |

A statistic type is not globally tied to one owner level. Owner type and owner ID must
be discovered together for each sport/statistic type.

### `statistic_participants1` … `statistic_participants17`

There is no confirmed unnumbered physical participant table. Important columns in a
selected shard `N`:

| Important column | Structural meaning |
|---|---|
| `id` | Statistic-participant identifier |
| `statisticFK` | Parent statistic |
| `participantFK` | Participant in the statistic |
| `del` | Soft-delete flag |

`statistic_typeFK = N` does not prove that shard `N` is used. The physical shard must
be confirmed from data.

### `statistic_data1` … `statistic_data17`

Field values for statistic participants. In shard `N`, the parent column follows the
physical naming pattern:

```text
statistic_dataN.statistic_participantsNFK
```

Important columns:

| Important column | Structural meaning |
|---|---|
| `id` | Statistic-data identifier |
| `statistic_participantsNFK` | Parent row in the matching participant shard |
| `statistic_data_typeFK` | Field/data-type reference |
| `statistic_data_type_detailFK` | Optional detail reference; exact constraints open |
| `value` | Text-capable stored field value |
| `del` | Soft-delete flag |

Identical shard numbers do not prove identical schema metadata or text collation across
all physical shards. Query only the confirmed data shard when possible.

### `statistic_config`

Key/value configuration attached directly to a statistic.

| Important column | Structural meaning |
|---|---|
| `id` | Config-row identifier |
| `statisticFK` | Parent statistic |
| `statistic_data_typeFK` | Config key/data-type reference |
| `value` | Stored config value |
| `del` | Soft-delete flag |

Multiple active rows for one statistic/key combination have been observed; uniqueness
must not be assumed.

### Statistic metadata paths

Current confirmed mechanisms include:

| Metadata | Storage path | Verification boundary |
|---|---|---|
| Config fields | `statistic_config` | Mechanism confirmed globally; concrete keys sport/type-specific |
| Discipline | `object_discipline`, owner type `83` | Confirmed for limited statistic-type evidence |
| Tournament age class | `object_relation 83 -> 151` | Confirmed for limited statistic-type evidence |
| Country | `object_relation 83 -> 33` | Confirmed for limited statistic-type evidence |

These paths are not automatically mandatory for every statistic type.

<!-- MANUAL PASTE ZONE: DATABASE STATISTICS — insert approved additions immediately before this marker; do not move or delete it. -->

---

## 5. Event scope model

```text
event
  -> event_scope
      -> scope_result             (owner: event_participants)
      -> lineup_scope_result      (owner: lineup)
      -> event_scope_detail       (name/value metadata)
```

### `event_scope`

Event-level scope/segmentation container.

| Important column | Structural meaning |
|---|---|
| `id` | Scope-container identifier |
| `eventFK` | Parent event |
| `scope_typeFK` | Scope-type reference |
| `del` | Soft-delete flag |

Container existence and populated child-value existence are separate storage states.

### `scope_result`

Participant-owned value inside an event scope.

| Important column | Structural meaning |
|---|---|
| `id` | Scope-result identifier |
| `event_participantsFK` | Owner event-participant row |
| `event_scopeFK` | Scope container |
| `scope_data_typeFK` | Segment/checkpoint/data-point reference |
| `value` | Text stored value |
| `del` | Soft-delete flag |

Both parent contexts are structurally significant: whose value it is and which scope
container it belongs to.

### `lineup_scope_result`

Parallel scope-value layer whose owner is a `lineup` row.

| Important column | Structural meaning |
|---|---|
| `id` | Lineup-scope identifier |
| `lineupFK` | Owner lineup row |
| `event_scopeFK` | Scope container |
| `scope_data_typeFK` | Segment/checkpoint/data-point reference |
| `value` | Stored value |
| `del` | Soft-delete flag |

Use of `scope_result` does not prove use of `lineup_scope_result`, or vice versa.

### `event_scope_detail`

Name/value metadata attached to an event-scope container.

| Important column | Structural meaning |
|---|---|
| `id` | Detail-row identifier |
| `event_scopeFK` | Parent scope container |
| `name` | Detail key |
| `value` | Detail value |
| `del` | Soft-delete flag |

### Scope references

- `scope_type` defines the scope/segmentation kind.
- `scope_data_type` defines the individual segment/checkpoint/data point.
- A direct taxonomy relation between those two reference tables has not been confirmed.

Parallel `*_import` tables with `providerFK` have been observed. Their complete schema
and canonical/import synchronization behavior remain open.

<!-- MANUAL PASTE ZONE: DATABASE SCOPES — insert approved additions immediately before this marker; do not move or delete it. -->

---

## 6. Properties and reference mechanisms

Metadata displayed together in an application can be split across different database
mechanisms.

| Concept | Confirmed storage mechanism |
|---|---|
| Generic key/value metadata | `property` using `object + objectFK` |
| Stage age class | `object_relation 4 -> 151` |
| Template subset | `object_relation 2 -> 152` |
| Set derived from subset | `tournament_sub_set.tournament_setFK` |
| Event discipline | `object_discipline`, owner type `5` |
| Statistic discipline | `object_discipline`, owner type `83`, limited evidence |
| Participant country | `participant.countryFK` |
| Stage country | `tournament_stage.countryFK` |
| Event detailed status | `event.status_descFK` |
| Status values mapped to a sport | `map_sport_status_desc` |
| Event round type | `event.round_typeFK` |

### Set and subset path

```text
tournament_template
  -> object_relation 2 -> 152
      -> tournament_sub_set
          -> tournament_set via tournament_setFK
```

No active generic relation using object type `157` for `tournament_set` was confirmed
in the inspected data. The confirmed Set path is the direct FK from Subset.

### `status_desc` and `map_sport_status_desc`

`event.status_type` and `event.status_descFK` are separate stored layers:

- `status_type` is coarse status text/category;
- `status_descFK` selects a reference row with more detailed identity;
- `map_sport_status_desc` relates a sport to status-detail values available to it.

Allowed/mapped values and values currently used by events are separate inventories.
The behavior attached to a concrete status detail is sport-specific until confirmed.

<!-- MANUAL PASTE ZONE: DATABASE REFERENCE MECHANISMS — insert approved additions immediately before this marker; do not move or delete it. -->

---

## 7. Numeric object-type registry

| ID | Object/table meaning | Status |
|---:|---|---|
| 1 | `sport` | Confirmed-data |
| 2 | `tournament_template` | Confirmed-data |
| 3 | `tournament` | Confirmed-data |
| 4 | `tournament_stage` | Confirmed-data |
| 5 | `event` | Confirmed-data |
| 6 | `event_participants` | Confirmed-data |
| 7 | `result` | Confirmed-data |
| 15 | `participant` | Confirmed-data |
| 19 | `venue` | Confirmed-data |
| 33 | `country` | Confirmed-data |
| 54 | `language` | Confirmed-data |
| 59 | `object_participants` | Confirmed-data |
| 73 | `lineup` | Confirmed-data |
| 83 | `statistic` | Confirmed-data |
| 148 | `discipline` | Confirmed-data |
| 151 | `tournament_age_class` | Confirmed-data |
| 152 | `tournament_sub_set` | Confirmed-data |
| 157 | `tournament_set` | Confirmed-data |
| 158 | `object_discipline` | Confirmed-data |
| 159 | `object_relation` | Confirmed-data |

Only IDs currently relevant to the active sports-content scope are listed.

<!-- MANUAL PASTE ZONE: DATABASE OBJECT TYPES — insert approved additions immediately before this marker; do not move or delete it. -->

---

## 8. Direct relation registry

Cardinality, mandatory status and physical FK enforcement are not claimed by this
registry unless separately verified.

| ID | Source column | Target column | Verification |
|---|---|---|---|
| `REL-DIRECT-001` | `tournament_template.sportFK` | `sport.id` | Confirmed-schema |
| `REL-DIRECT-002` | `tournament.tournament_templateFK` | `tournament_template.id` | Confirmed-schema |
| `REL-DIRECT-003` | `tournament_stage.tournamentFK` | `tournament.id` | Confirmed-schema |
| `REL-DIRECT-004` | `event.tournament_stageFK` | `tournament_stage.id` | Confirmed-schema |
| `REL-DIRECT-005` | `event_participants.eventFK` | `event.id` | Confirmed-schema-data |
| `REL-DIRECT-006` | `event_participants.participantFK` | `participant.id` | Confirmed-schema-data |
| `REL-DIRECT-007` | `participant.countryFK` | `country.id` | Confirmed-schema |
| `REL-DIRECT-008` | `tournament_stage.countryFK` | `country.id` | Confirmed-schema |
| `REL-DIRECT-009` | `event.status_descFK` | `status_desc.id` | Confirmed-schema-data |
| `REL-DIRECT-010` | `event.round_typeFK` | `round_type.id` | Confirmed-schema-data |
| `REL-DIRECT-011` | `tournament_sub_set.tournament_setFK` | `tournament_set.id` | Confirmed-schema-data |
| `REL-DIRECT-012` | `result.event_participantsFK` | `event_participants.id` | Confirmed-schema-data |
| `REL-DIRECT-013` | `result.result_typeFK` | `result_type.id` | Confirmed-data |
| `REL-DIRECT-014` | `incident.event_participantsFK` | `event_participants.id` | Confirmed-schema-data |
| `REL-DIRECT-015` | `incident.incident_typeFK` | `incident_type.id` | Confirmed-schema-data |
| `REL-DIRECT-016` | `lineup.event_participantsFK` | `event_participants.id` | Confirmed-schema-data |
| `REL-DIRECT-017` | `lineup.participantFK` | `participant.id` | Confirmed-schema-data |
| `REL-DIRECT-018` | `lineup.lineup_typeFK` | `lineup_type.id` | Confirmed-data |
| `REL-DIRECT-019` | `object_participants.participantFK` | `participant.id` | Confirmed-schema-data |
| `REL-DIRECT-020` | `object_relation.object_typeFK` | `object_type.id` | Confirmed-data |
| `REL-DIRECT-021` | `object_relation.rel_object_typeFK` | `object_type.id` | Confirmed-data |
| `REL-DIRECT-022` | `statistic.object_typeFK` | `object_type.id` | Confirmed-data |
| `REL-DIRECT-023` | `statistic_participantsN.statisticFK` | `statistic.id` | Confirmed-schema-data |
| `REL-DIRECT-024` | `statistic_participantsN.participantFK` | `participant.id` | Confirmed-schema-data |
| `REL-DIRECT-025` | `statistic_dataN.statistic_participantsNFK` | `statistic_participantsN.id` | Confirmed-schema-data |
| `REL-DIRECT-026` | `statistic_dataN.statistic_data_typeFK` | `statistic_data_type.id` | Confirmed-data |
| `REL-DIRECT-027` | `statistic_dataN.statistic_data_type_detailFK` | `statistic_data_type_detail.id` | Confirmed-data |
| `REL-DIRECT-028` | `statistic_config.statisticFK` | `statistic.id` | Confirmed-schema-data |
| `REL-DIRECT-029` | `statistic_config.statistic_data_typeFK` | `statistic_data_type.id` | Confirmed-data |
| `REL-DIRECT-030` | `event_scope.eventFK` | `event.id` | Confirmed-schema-data |
| `REL-DIRECT-031` | `event_scope.scope_typeFK` | `scope_type.id` | Confirmed-schema-data |
| `REL-DIRECT-032` | `scope_result.event_participantsFK` | `event_participants.id` | Confirmed-schema-data |
| `REL-DIRECT-033` | `scope_result.event_scopeFK` | `event_scope.id` | Confirmed-schema-data |
| `REL-DIRECT-034` | `scope_result.scope_data_typeFK` | `scope_data_type.id` | Confirmed-schema-data |
| `REL-DIRECT-035` | `lineup_scope_result.lineupFK` | `lineup.id` | Confirmed-schema-data |
| `REL-DIRECT-036` | `lineup_scope_result.event_scopeFK` | `event_scope.id` | Confirmed-schema-data |
| `REL-DIRECT-037` | `lineup_scope_result.scope_data_typeFK` | `scope_data_type.id` | Confirmed-schema-data |
| `REL-DIRECT-038` | `event_scope_detail.event_scopeFK` | `event_scope.id` | Confirmed-schema-data |
| `REL-DIRECT-039` | `object_discipline.object_typeFK` | `object_type.id` | Confirmed-data |
| `REL-DIRECT-040` | `object_discipline.disciplineFK` | `discipline.id` | Confirmed-data |
| `REL-DIRECT-041` | `map_sport_status_desc.sportFK` | `sport.id` | Confirmed-schema-data |
| `REL-DIRECT-042` | `map_sport_status_desc.status_descFK` | `status_desc.id` | Confirmed-schema-data |

`incident.ref_participantFK -> participant.id` is not registered as confirmed because
its target was not independently verified in the active evidence.

<!-- MANUAL PASTE ZONE: DATABASE DIRECT RELATIONS — insert approved additions immediately before this marker; do not move or delete it. -->

---

## 9. Confirmed generic relation registry

### `object_relation`

| ID | Source | Target | Verification boundary |
|---|---|---|---|
| `REL-OBJECT-001` | `tournament_stage` (`4`) | `tournament_age_class` (`151`) | Confirmed-data |
| `REL-OBJECT-002` | `tournament_template` (`2`) | `tournament_sub_set` (`152`) | Confirmed-data |
| `REL-OBJECT-003` | `statistic` (`83`) | `tournament_age_class` (`151`) | Confirmed-data; limited statistic-type evidence |
| `REL-OBJECT-004` | `tournament_stage` (`4`) | `country` (`33`) | Confirmed-data — represents Host Country, distinct from the direct `tournament_stage.countryFK` column |

### `object_discipline`

| ID | Source | Target | Verification boundary |
|---|---|---|---|
| `REL-DISC-001` | `event` (`5`) | `discipline` | Confirmed-data |
| `REL-DISC-002` | `statistic` (`83`) | `discipline` | Confirmed-data; limited statistic-type evidence |

### `property`

| ID | `object` value | Owner target | Verification |
|---|---|---|---|
| `REL-PROPERTY-001` | `event` | `event.id` | Confirmed-data |
| `REL-PROPERTY-002` | `tournament` | `tournament.id` | Confirmed-data |
| `REL-PROPERTY-003` | `tournament_stage` | `tournament_stage.id` | Confirmed-data |
| `REL-PROPERTY-004` | `participant` | `participant.id` | Confirmed-data |

### `object_participants`

| ID | `object` value | Owner target | Verification |
|---|---|---|---|
| `REL-OBJPART-001` | `sport` | `sport.id` | Confirmed-data |
| `REL-OBJPART-002` | `participant` | `participant.id` | Confirmed-data; roster/container pattern |
| `REL-OBJPART-003` | `tournament_template` | `tournament_template.id` | Confirmed-data |
| `REL-OBJPART-004` | `tournament` | `tournament.id` | Confirmed-data |
| `REL-OBJPART-005` | `tournament_stage` | `tournament_stage.id` | Confirmed-data |
| `REL-OBJPART-006` | `event` | `event.id` | Confirmed-data |
| `REL-OBJPART-007` | `venue` | `venue.id` | Confirmed-data |

<!-- MANUAL PASTE ZONE: DATABASE GENERIC RELATIONS — insert approved additions immediately before this marker; do not move or delete it. -->

---

## 10. Global structural semantics

These rules describe storage identity and interpretation. They do not classify data
quality.

### `DB-SEM-001` — Polymorphic IDs require their discriminator

An `objectFK` value alone is not an object identity. Interpret it with `object` or
`object_typeFK`, depending on the table.

### `DB-SEM-002` — Soft-delete, row existence and value presence are separate

No row, a soft-deleted row, an active empty row and an active populated row are four
different database states.

### `DB-SEM-003` — Display/order and result rows are independent

`event_participants.number` is not the same storage location as a `result` row. Their
semantic relationship must be documented per sport/use case.

### `DB-SEM-004` — Parallel value layers do not inherit from one another

Event results, statistic data, participant-owned scope values and lineup-owned scope
values are separate physical layers. Presence in one layer does not prove presence in
another.

### `DB-SEM-005` — Scope values carry two contexts

`scope_result` identifies both the event-participant owner and the event-scope
container. `lineup_scope_result` identifies both the lineup owner and container.

### `DB-SEM-006` — Statistic shard selection is empirical

The statistic type ID does not automatically determine participant/data shard number.
The physical shard and shard-specific parent column must be confirmed together.

### `DB-SEM-007` — Coarse and detailed event statuses are separate fields

`event.status_type` and `event.status_descFK` store different levels of status identity.
Concrete behavior attached to a detailed status belongs in sport-specific evidence.

### `DB-SEM-008` — Metadata is split across mechanisms

Properties, generic relations, disciplines, direct reference columns and statistic
configuration are distinct storage paths. An application screen does not imply one
physical metadata table.

### `DB-SEM-009` — Participant type and gender exist at several layers

Template, stage, event participant, participant and lineup structures can carry
different type/gender context. Their relationship and meaning are sport-specific.

### `DB-SEM-010` — Event/round representation is sport-specific

An event row may represent a match, race, heat, round or another competition unit. The
round/event model must be documented from the sport's actual rows and reference IDs.

<!-- MANUAL PASTE ZONE: DATABASE STRUCTURAL SEMANTICS — insert approved additions immediately before this marker; do not move or delete it. -->

---

## 11. Global open questions

- Physical FK enforcement for the registered logical relations.
- Confirmed cardinality, uniqueness and mandatory status for most relations.
- Full verified column inventories for several small reference tables.
- Target semantics of `incident.ref_participantFK`.
- Complete allowed values for participant type and gender/category fields.
- Complete property owner/type/name taxonomy.
- `saved_json_player` (columns: id, atp_id, name, firstname, lastname, gender, country_code, dob, active, mapped, del, ut, n) has no direct foreign key to `participant`; observed linkage is only a heuristic exact-text match on `name`. The `mapped` flag does not reliably indicate match status. Duplicate `saved_json_player` rows with the same name have been observed mapping to the same `participant.id` (name-collision risk). The table's relationship to `participant`, its canonical-vs-staging role, and its sport scope are not confirmed.
- Universal statistic type-to-owner and type-to-shard rules, if any.
- Schema and collation equality across all statistic data shards.
- Complete scope import-table model and provider relation.
- Taxonomy relationship between `scope_type` and `scope_data_type`.

<!-- MANUAL PASTE ZONE: DATABASE OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
