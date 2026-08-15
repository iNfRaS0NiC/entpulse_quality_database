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

#### `category`

Reference table naming a category a sport can belong to, reached only through
`object_relation` (`REL-OBJECT-005`); `sport` carries no `categoryFK` column.

| Important column | Structural meaning |
|---|---|
| `id` | Category identifier |
| `name` | Category name |
| `description` | Free-text purpose of the category |
| `del` | Soft-delete flag |

It holds one active row, `1` `OLYMPIC`, so the relation is a flag in practice rather than a
classification. `DB-SEM-017` owns what the flag does and does not establish, including that
its membership is incomplete.

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

#### `object_round`

Numeric polymorphic bridge attaching a `round_type` to an owner object. A `type` column
discriminates what the attachment means, so one table serves several unrelated purposes.

| Important column | Structural meaning |
|---|---|
| `id` | Link identifier |
| `object_typeFK`, `objectFK` | Owner type and owner ID |
| `round_typeFK` | Attached round type |
| `type` | Purpose of the attachment |
| `del` | Soft-delete flag |

Confirmed active combinations:

| `object_typeFK` | `type` | Meaning |
|---:|---|---|
| `138` | `phase` | The round a Comp.Rank participant's rank was taken from |
| `4` | `indicator` | Round attachment on a tournament stage |

**An event's round is not stored here.** It is the direct column `event.round_typeFK`. Measured
2026-08-15: owner type `5` (event) appears in `object_round` for exactly one sport, `FIFA`, on
949 events, and nowhere else in the database. A statement wanting an event's round reads the
column; `object_round` answers a different question about a different owner.
| `4` | `schedule` | Round attachment on a tournament stage |
| `5` | `week` | Round attachment on an event |

`type = 'phase'` is exclusive to Comp.Rank and is the only storage for the Phase concept.
Across every active `phase` row, the owner resolves to a `statistic_participants11` row
whose parent statistic is `statistic_typeFK = 11`, with no exception and no orphan, and
`objectFK` is unique per row. No sibling object type exists for any other
`statistic_participantsN` shard, so a Comp.Rank held in another shard has nowhere to record
a Phase.

Phase is not a copy of the owning event's `round_typeFK`. It records the round the rank was
*derived from*, which for a participant ranked by an earlier round is not the last round
they took part in.

#### `venue_object`

Numeric polymorphic bridge linking a `venue` to an owner object, structurally parallel to
`city_object`.

| Important column | Structural meaning |
|---|---|
| `id` | Link identifier |
| `object_typeFK`, `objectFK` | Owner type and owner ID |
| `venueFK` | Linked venue |
| `neutral` | Whether the venue is neutral for the owner |
| `del` | Soft-delete flag |

Confirmed active owner types, by population: `5` (event), `4` (tournament_stage), `1`
(sport), `43` (city), `2` (tournament_template), `83` (statistic).

`venue` is a reference table (`id`, `name`, `countryFK`, `venue_typeFK`, `del`) carrying its
own EAV attribute pair `venue_data` / `venue_data_type`.

There is no `venueFK` column anywhere outside the `venue*` tables, so `venue_object` is the
only mechanism attaching a venue to a hierarchy or statistic object. `object_relation` does
not carry it: the only relation targeting `venue` (`19`) is venue-to-venue.

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

### `statistic_type`

Reference catalog selected by `statistic.statistic_typeFK`. Seventeen types exist:

| ID | Name | ID | Name |
|---:|---|---:|---|
| 1 | Player Stats | 10 | Team Performance Statistics |
| 2 | Tennis Stats | 11 | **Competition Stats** |
| 3 | Team Stats | 12 | Player Action Zone Stats |
| 4 | Player Stats Extended | 13 | Team Action Zone Stats |
| 5 | Team Stats Extended | 14 | Player Stats Ratings |
| 6 | Fun Facts Stats | 15 | Team Stats Ratings |
| 7 | Tennis Doubles Stats | 16 | Expected Players stats |
| 8 | Tennis Event Stats | 17 | Expected Team stats |
| 9 | Player Performance Statistics | | |

Type `11` is the only one whose subject is the competition itself; every other type
describes the performance of a player or a team. This project calls it **Comp.Rank**; the
database name is `Competition Stats` and both refer to `statistic.statistic_typeFK = 11`.

`statistic_type.id` and `statistic_data_type.id` are separate catalogs whose numbers
collide. `statistic_data_type.id = 11` is `Total games without goal` (`noscorings`),
declared for statistic type `3`. Writing `statistic_data_typeFK = 11` where
`statistic_typeFK = 11` is meant does not fail — it returns an empty result, which reads as
"no data" rather than as a mistake. The field types belonging to type `11` start at `1270`.

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

### `statistic_data_type`

Reference catalog of statistic field types, selected by `statistic_dataN.statistic_data_typeFK`
and `statistic_config.statistic_data_typeFK`.

| Important column | Structural meaning |
|---|---|
| `id` | Field/data-type identifier |
| `name` | Field display name |
| `code` | Stored field code |
| `statistic_typeFK` | Statistic type the field type is declared for |
| `statistic_data_type_categoryFK` | Data-type category reference |

`statistic_typeFK` partitions the catalog, so the declared field set must be read per
statistic type rather than as one global list.

Field names are not unique. The same `name` is declared repeatedly under different IDs,
across statistic types and within a single category. A field type must be matched by
`id`, never by name.

A field type declared for a statistic type is not evidence that any sport fills it.
The declared inventory and the used inventory are separate: `GLOBAL-DISCOVERY-030`
returns the declared catalog and `GLOBAL-DISCOVERY-031` compares it against actual use,
retaining declared-but-unused field types that `GLOBAL-DISCOVERY-017` cannot show.

### `statistic_data_type_category`

Reference grouping selected by `statistic_data_type.statistic_data_type_categoryFK`.

| Important column | Structural meaning |
|---|---|
| `id` | Category identifier |
| `name` | Category name |

Category names are not unique and the used category ID range is not contiguous. Whether
a category belongs to one statistic type or is shared across statistic types is not
confirmed.

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
| 43 | `city` | Confirmed-schema-data |
| 54 | `language` | Confirmed-data |
| 59 | `object_participants` | Confirmed-data |
| 73 | `lineup` | Confirmed-data |
| 83 | `statistic` | Confirmed-data |
| 138 | `statistic_participants11` | Confirmed-schema-data |
| 148 | `discipline` | Confirmed-data |
| 151 | `tournament_age_class` | Confirmed-data |
| 152 | `tournament_sub_set` | Confirmed-data |
| 153 | `category` | Confirmed-data |
| 157 | `tournament_set` | Confirmed-data |
| 158 | `object_discipline` | Confirmed-data |
| 159 | `object_relation` | Confirmed-data |

Only IDs currently relevant to the active sports-content scope are listed.

`object_type` is a real reference table (`id`, `name`), so a numeric owner type can be
resolved by querying it rather than inferred from the owner's ID range or from the table a
join happens to succeed against. Its `name` is the physical table name, which is what makes
`138` unambiguous: the type is bound to one physical shard, not to statistic participants in
general.

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
| `REL-DIRECT-043` | `statistic_data_type.statistic_data_type_categoryFK` | `statistic_data_type_category.id` | Confirmed-data |

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
| `REL-OBJECT-005` | `sport` (`1`) | `category` (`153`) | Confirmed-data — at most one per sport, and every one points at the single `category` row; membership is incomplete, see `DB-SEM-017` |

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

### `DB-SEM-011` — Comp.Rank and event results are different aggregation levels

An event's `result` rows rank participants within one start: a single heat, quarter-final,
semi-final or final, each stored as its own `event`. A Comp.Rank statistic
(`statistic_typeFK = 11`) ranks participants across the whole competition, collecting the
participants of many events into one ordered classification.

The two are therefore not duplicates of each other and neither is derivable from the other
by copying. A Comp.Rank position is ordinal by round reached first and by result within that
round second, so it cannot be validated by comparing it numerically against event results:
a participant eliminated earlier ranks below one eliminated later regardless of the times or
points either recorded.

The ordering unit is the discipline within a stage, not the tournament. One stage can hold
several Comp.Rank statistics, one per competition it contains.

No foreign key joins a Comp.Rank to the events it summarizes, but the two levels are not
unlinked. Both sides identify people through the same `participant` table, and a
tournament-owned Comp.Rank reaches its events through its own owner:

```text
statistic (11) → objectFK = tournament → tournament_stage → event → event_participants → participant
statistic_participantsN → participantFK ───────────────────────────────────────────────────┘
```

`statistic_config` Event id (`1471`) additionally enumerates the specific events a statistic
covers, where the sport populates it. The ownership path is the coarser of the two: it
reaches every event of the tournament rather than only the competition the statistic ranks,
so it supports asking whether a ranked participant appears in the tournament at all, but not
whether every event participant was ranked.

**The value holds a list, not an id.** "Enumerates" is literal: the column is text and a
statistic covering several events stores their ids comma-separated, without spaces and without
padding. Measured across the whole server on 2026-08-14, seven sports write multi-id values —
Alpine on 1062 of its 2488, Cross Country Skiing on 783, Short Track Speed Skating on 231 of
362, Golf on 246 of 3444 with up to 37 ids in one value, and Freestyle Skiing, Ski
Mountaineering and Swimming on fewer. Every value on the server is a clean list of digits and
commas, so `FIND_IN_SET(<event>.id, <config>.value)` is the exact membership test and is
correct for a single id too. `CAST(value AS UNSIGNED)`, and the implicit conversion an
`e.id = sc.value` join performs, both read only the id before the first comma — the events a
statistic covers are then silently undercounted, and a well-formed list reads as a value that
is not a number. Five DQ templates did exactly that until 2026-08-14; `GLOBAL_DQ/README.md`
records which.

**And the column cannot hold a long one.** No value of this field anywhere on the server exceeds
255 characters, and the lengths pile up against that number rather than approaching it: measured
on Golf 2026-08-14, 167 values sit at exactly 255, one at 231, five at 239, and nothing at all
between 240 and 254. A distribution of list lengths has no cliff in it; a column limit does. The
write is cut silently and every event after the cut is lost from the statistic's scope.

Which half of the defect is visible depends on how long the sport's event ids are. Seven-digit
ids pack 32 to a 255-character value with the cut landing on a comma, so the value reads as a
complete list and only its length betrays it - 154 of Golf's. Six-digit ids pack 36 and leave
three characters of the 37th behind as a token of its own, and that fragment is itself a valid
event id: `412`, `135`, `455`, `622`, `794`, `988` and `1353` are football matches played in
2000. A join on such a value attaches one sport's ranking to another sport's fixture rather than
failing, which is the more dangerous half and the smaller one at thirteen.

Freestyle Skiing holds 49 values at the limit. No other sport on the server holds one. Golf runs
`Golf-DQ-098` against it; correcting the values without widening the column would truncate them
again on the next write.

### `DB-SEM-012` — One round name exists as a knockout and a non-knockout round type

`round_type.knockout` is the discriminator that separates two rows sharing one `name`. Of
the active round type names, 104 carry both a `knockout = 'yes'` and a `knockout = 'no'`
row under different IDs; 97 names exist only as knockout and 69 only as non-knockout. A
round type is therefore identified by `id`, and a name plus the knockout flag — never a name
alone.

Confirmed pairs include Final (`9` yes, `173` no), Semi Finals (`2` yes, `178` no), Quarter
Finals (`3` yes, `176` no), 1/8 (`4` yes, `184` no), 1/16 (`5` yes, `185` no) and 1/32
(`6` yes, `188` no).

Which variant a sport uses is a per-sport fact and must be recorded per sport. The two sides
of one relation can disagree: a sport's events may carry the non-knockout variant while the
Phase attached to that sport's Comp.Rank participants carries the knockout one, so both
describe the same round while holding different IDs. A check comparing a Phase against an
event's `round_typeFK` must treat the pair as equivalent, or it reports the whole population
as mismatched.

A check asking whether a round is a Final therefore accepts every variant of it. The Final
round set is a declared parameter rather than a literal, and a sport records both IDs of the
pair even when its own events use only one, so the check is unaffected by which side a given
row carries. Which variant is stored where is a known inconsistency in the data, tracked for
cleanup rather than reported by the checks; a check that distinguished the two would report
the inconsistency instead of the defect it was written for.

`round_type.value` is populated only on the main-bracket knockout rounds, where it holds the
bracket size — Final `1`, Semi Finals `2`, Quarter Finals `4`, 1/8 `8`, 1/16 `16`, 1/32
`32`. It is `0` on the non-knockout variants and on knockout rounds outside the main bracket
such as Small Final, bronze and Qualifier.

`round_type` carries no round-order column — its columns are `id`, `name`, `value`,
`knockout`, `n`, `ut` and `del` — and `value` is not one: it *decreases* as the competition
advances and is `0` for most rows. Round order therefore cannot be read from `round_type`.
A process that needs rounds in competition order must carry that order itself. Ordering by
name is equally unsafe, because names vary by sport and competition (`Final`, `Final A`,
`Gold Medal Match`, `Main Final`) and are not unique across IDs.

### `DB-SEM-013` — A Comp.Rank is identified by tournament, discipline and gender

`tournament` is a season — `2002`, `2003/2004` — always reached from a sport and a
tournament template. A Comp.Rank never spans more than one of them: a season-long series
holds one Comp.Rank per stop and per unique competition within that season, not one covering
several seasons.

The attributes intended to identify a Comp.Rank are tournament, discipline and gender; age
class does not distinguish two otherwise identical statistics, because a differing age class
is not expected alongside an identical gender.

Those three do not form a unique key in practice. A season holds one Comp.Rank per stop, all
sharing the same tournament, and a single stage can hold several competitions of the same
discipline and gender. What additionally separates two such statistics is not yet confirmed
and is recorded as an open question below.

Every event carrying a Final round type is expected to have its own Comp.Rank. The relation
between the two is not stored as a foreign key, so this is an expectation about population
completeness rather than a constraint the schema enforces.

The owner is normally `tournament` (`object_typeFK = 3`). A minority of statistics are owned
by `tournament_stage` (`4`) instead; this is a per-sport exception and must be confirmed for
a sport before a check assumes either owner level.

Discipline granularity varies by sport and is not a reliable proxy for "one competition".
For Ski Jumping the disciplines are Ski Jumping, Team Ski Jumping and Super Team Ski Jumping,
so two competitions of the same discipline and gender — a normal-hill and a large-hill
event — are distinguished by neither. Uniqueness checks must therefore be written per sport.

### `DB-SEM-014` — A rank is a strictly positive integer

Rank is stored as text in both layers that carry it: `result` rows of the sport's rank result
type, and `statistic_data<N>` rows of the rank data type. Neither column constrains the
value, so a value is a rank only by convention.

The convention is a strictly positive integer with no leading zeros, no sign, no decimal part
and no surrounding text. `0` is not a rank, and `007` is not the same stored value as `7`
even though both denote seventh place. A check testing rank validity therefore matches
`^[1-9][0-9]*$`, and so does any filter selecting the rows that hold a numeric rank.
The two must agree: a looser filter makes a check reason about values that a stricter
validity check reports as invalid, so the same value is treated as a rank in one statement
and as a defect in another.

How a sport marks a participant that did not finish is a separate, per-sport fact. Some
sports issue a sentinel rank outside the finishing order alongside a comment value. That rank
is still a positive integer, so the convention above is not weakened by it: what a rank
*means* is per-sport, what shape it has is not.

### `DB-SEM-015` — A sport's competition model decides which checks can apply to it

How a sport resolves a result governs which storage it fills, and therefore which checks have
an eligible population at all. The model is not an editorial label: each one is stated below
as a condition on rows, so a sport's model is measured from its data rather than asserted, and
a wrong classification is contradicted by the sport's own tables.

| Model | Observable condition |
|---|---|
| `H2H` | An event holds exactly two event participants, and each result type the sport scores carries one value per participant. The classification is the pair, so no event-level rank result type is populated. |
| `LISTING` | An event holds the whole field competing at once, so its event-participant count varies with entries rather than being fixed at two, and the sport populates an event-level rank result type. |
| `HYBRID` | Both conditions hold inside one competition: some of the sport's stages resolve a field into a ranked listing and others resolve pairs head to head, and both event shapes occur under the same tournament template. |

`H2H` is additionally recorded as `H2H Team` or `H2H Individual` by the participant type its
event participants carry, and `LISTING` likewise. That distinction changes which participant
and lineup checks apply, not which result checks do.

Three things this rule is not:

- **It is not a scoring mechanism.** A field judged into points is `LISTING` exactly as a
  field timed into seconds is: everyone competes, everyone is scored, the field is ranked. The
  model describes how a result is resolved, never how a value is produced.
- **It is not a discipline-level property.** A sport whose disciplines resolve results
  differently is `HYBRID` at sport level, because one competition contains both. A sport whose
  disciplines are separate competitions that each resolve the same way is not.
- **It does not follow from one `sport` row.** A single `sport.id` can carry two editorially
  distinct sports across its disciplines, and each is classified on its own condition. Where
  that happens the sport file records the split; `SPORTS/BMX.md` is the confirmed case.

`SPORTS.md` records the model per sport. A model is recorded only once the sport file
documents the evidence for it, on the same terms as any other confirmed structure.

### `DB-SEM-016` — `REL-DIRECT-002` is traversed from the tournament, not from the template

The relation between a tournament and its template is one relation and two directions, and the
database does not treat them alike. Restricting a scope by `tournament.tournament_templateFK`
and restricting it by `tournament_template.id` select exactly the same rows. They do not cost
the same, and the difference is not marginal.

Keyed on the template's primary key, the optimiser drives from `tournament_template` — a small
table — and reaches everything else through it. That reads like the better plan and is not: the
path from a handful of template rows outward loses the index route into
`statistic_participants{{SHARD_ID}}` and `statistic_data{{SHARD_ID}}`, and the shards are then
scanned. Keyed on the tournament's foreign key, `tournament` anchors the scope and the shards
are reached by index.

Measured on Soccer over twenty-eight templates, returning an identical 20293 rows: 28.3 seconds
one way, 2.5 seconds the other. Across the approved checks of one sport the same asymmetry cost
about a minute per statistic-layer check, and made `GLOBAL-DQ-044` fail to return at all.

Two things this rule is not:

- **It is not about the sport's size.** Soccer's Comp.Rank layer is the smallest of the five
  documented sports — 492 statistics and about twenty thousand data rows against 8.8 million in
  the shard. The cost came from the direction of the traversal, not from the volume traversed.
- **It is not a licence to rewrite a statement for speed.** Only this one substitution is
  established. `GLOBAL-DQ-044` also needed its eligible statistics resolved in a materialised
  step, and that is a property of `statistic_config`, recorded with the check rather than here.

`POWERBI.md` owns the resulting query rule and `TOOLS/Test-Tools.ps1` enforces it against the
package.

### `DB-SEM-017` — `category` marks a sport as Olympic, and the marking is incomplete

`category` is a reference table holding one active row: `1`, named `OLYMPIC` and described as
"Used for Olympic sports". Because it holds one row, the relation reaching it is in practice a
flag rather than a classification — a sport either carries it or does not, and no sport carries
more than one. It is reached only through `object_relation` as `REL-OBJECT-005`; no `categoryFK`
column exists on `sport`.

53 of the 128 active sports carry it. **The set must not be read as authoritative**, because
sports plainly inside the Olympic programme are missing from it: none of the three gymnastics
sports carries the flag — `Artistic Gymnastics` (`40`), `Rhythmic Gymnastics` (`140`),
`Trampoline Gymnastics` (`139`) — and `BMX` (`58`) does not, while `Cycling` (`30`) and
`Track Cycling` (`55`) both do. Para sports carry none, which may be intentional rather than a
gap: no row exists for them to point at.

The distinction that matters when reading it: a sport without the flag is not thereby a
non-Olympic sport. Absence means only that nothing was recorded. A check or a scope that treats
the flag as the definition of the Olympic programme reports the recording gap as a fact about
the sport, which is why the completeness statement belongs here rather than being left for a
reader to discover.

Whether the gap is a data state to be corrected or a deliberate scope of the marking is not
established, and this file does not decide it.

### `DB-SEM-018` — Whether a stage produces a Comp.Rank is not stored on the stage

The editing tool offers a per-stage `Competition Rank` yes/no setting. **Nothing in this
schema holds it.** `tournament_stage` has no column for it — its columns are `id`, `name`,
`tournamentFK`, `gender`, `countryFK`, `enetID`, `startdate`, `enddate`, `n`, `locked`, `ut`,
`del` and nothing else — and no `property` row carries it either: the only property name
observed on `tournament_stage` objects is `Cup`. Do not go looking for the flag here.

What the database holds is the consequence: a `statistic` row with `statistic_typeFK = 11`.
The check that answers "is Comp.Rank set" is therefore an existence test against `statistic`,
and it answers a question one step removed from the setting — a stage whose flag is on but
whose statistic was never generated is indistinguishable here from one whose flag is off.

**The owner is the tournament in practice, not the stage.** `DB-SEM-013` records that a
minority of statistics are owned by `tournament_stage` (`object_typeFK = 4`) rather than
`tournament` (`3`); for Comp.Rank the split measured on 2026-08-10 is 78 084 tournament-owned
against 1 778 stage-owned, and across the twenty sports with the most stages since 2025 the
stage-owned count is zero. The stage-owned minority is not the current shape. An existence
test must still read both, because it is a per-sport exception rather than a retired one.

**Presence is nowhere near universal, and that is the point of measuring it.** Over stages
starting from 2025, the proportion whose tournament carries a Comp.Rank ranges from all of
them to none: Triathlon 186 of 186, Snowboarding 125 of 238, Cycling 238 of 469, Basketball
267 of 1 084, Soccer 32 of 2 563, and none at all for Tennis, Motorsports, Badminton, Horse
Racing, Table Tennis, Athletics, Darts or League of Legends. Artistic Swimming (`47`) carries
none across 18 tournaments in 2024 to 2026, which is why its numeric Comp.Rank fields sit
under IOC-purpose templates alone.

These are counts from one reading and go stale on their own; they are recorded to establish
the shape — that Comp.Rank presence is a per-sport population fact — rather than as figures
to be cited. A check asserting that every stage has one would report the shape of the feed
for most sports rather than a defect.

### `DB-SEM-019` — An event's discipline belongs in `object_discipline`, and the `discipline` property is a legacy path

Two storage paths exist and they are not equal. **The relation is the one the database
means**: `object_discipline` with `object_typeFK = 5` is where an event's discipline is
recorded, and it is where a sport's own vocabulary is visible — Ice Hockey holds `6aSide` on
312 717 events, Artistic Gymnastics holds `Vault` on 1 424, `Floor Exercise` on 1 388 and each
remaining apparatus on its own rows, Golf holds `Match Play` and `Stroke Play`, Curling holds
`4aSide` and `Mixed Doubles`. A sport whose events lack the relation has a gap, and that is
what `GLOBAL-DQ-015` and `GLOBAL-DQ-023` report.

The `discipline` **event property** is the older path. Measured 2026-08-15 it survives in 64
sports, and its size separates the two populations cleanly: it is substantial only where a
sport never moved to the relation — Fencing 319 645 events, Swimming 45 839, Short Track
24 191 — while every team sport carries a remnant of a handful, Ice Hockey 7, Curling 9,
Handball 14, Volleyball 5, Cricket 8. A remnant of that size is not a second opinion about the
discipline; it is what is left of an abandoned convention.

The consequence for a check: **the relation is asserted and the property is not read**. A
statement wanting an event's discipline joins `object_discipline`; one wanting to know whether
the discipline is recorded at all tests that relation and never the property. `GLOBAL-DQ-109`
compares the two paths and is therefore instantiable only in a sport that genuinely writes
both — it is recorded `Not applicable` for Ice Hockey on 2026-08-15 for exactly this reason,
and any sport reaching the same conclusion should record it the same way rather than leaving
the check to audit an empty population.

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
- Target of `statistic_data_type.statistic_typeFK`. The column filters the field catalog
  per statistic type, but its resolution against `statistic_type.id` was not independently
  verified, and it is unknown whether the per-type field sets are disjoint.
- Soft-delete behavior of `statistic_type`, `statistic_data_type` and
  `statistic_data_type_category`. No `del` column was confirmed, so the reference catalogs
  may include retired rows.
- Schema and collation equality across all statistic data shards.
- Complete scope import-table model and provider relation.
- Taxonomy relationship between `scope_type` and `scope_data_type`.
- What distinguishes two Comp.Rank statistics sharing one tournament, discipline and gender.
  Those three are the intended identifying attributes (`DB-SEM-013`), but a season holds one
  statistic per stop and a stage can hold several competitions of the same discipline and
  gender, so no uniqueness check can be built on them until the additional discriminator is
  confirmed.
- Where the relation between a Comp.Rank and the events it covers will be stored once
  `statistic_config` Event id (`1471`) becomes mandatory. It is populated for part of the
  current data only, and statistics without it currently declare no event scope at all.

<!-- MANUAL PASTE ZONE: DATABASE OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
