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

**A status of `cancelled` does not mean no result was ever written.** Measured on Ice Hockey
2026-08-20, every one of its 3938 cancelled events carries the ordinary-time score, the running
score and a first period, and a couple of hundred carry a second and third - a match abandoned
part way, recorded as far as it got. What such an event must not carry is the result type the
sport decides its outcome by, and `GLOBAL-DQ-126` is the check that says so. Reading any result
on a cancelled event as a defect reports the sport's normal practice; reading none of them
misses the ones that were awarded a final score they never played for.

**`participant.type` is the person's role now, not the role they held at any event they appear
in.** There is one row per person and one type on it, so a player who later becomes a coach is
typed `coach` and reads that way in every record going back twenty years. Measured 2026-08-20
on Ice Hockey: **446** people typed `coach` appear in Comp.Rank rankings and **406 of them also
occupy a playing lineup slot**. Martin St. Louis, Daniel Alfredsson and Manny Malhotra are
typed `coach` and hold World Championship medals they won as players.

Nothing in the schema records the role at the time. A statement that reads the type as though
it described the appearance will therefore be wrong about history, and wrong in one direction
only: never about who took part, always about what they were called. `GLOBAL-DQ-113` counted
types across a ranking and read every such squad as a ranking mixing two kinds of competitor -
all 72 of Ice Hockey's findings and all 27 of Soccer's - which is why it now collapses the
person types through `PERSON_ROLE_TYPE_LIST`.

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
| `ref_participantFK` | The person the incident is about, inside the owning team — `participant.id`, confirmed 2026-09-07, `DB-SEM-021` |
| `elapsed`, `elapsed_plus` | Stored elapsed components; meaning/format open, and confirmed per sport rather than globally — `SPORTS/Ice-Hockey.md` establishes seconds there from the distribution of 12713 goals across a 3600-second game |
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

Thirteen owner values are in use, measured 2026-09-07 over 93 538 275 property rows. Nine
of them were unregistered until that date — including the two largest after `event` — so a
statement built from the registry alone was reading a third of the mechanism.

| ID | `object` value | Owner target | Rows | Unresolved `objectFK` | Verification |
|---|---|---|---:|---:|---|
| `REL-PROPERTY-001` | `event` | `event.id` | 40 908 268 | not measured | Confirmed-data |
| `REL-PROPERTY-002` | `tournament` | `tournament.id` | 3 197 | not measured | Confirmed-data |
| `REL-PROPERTY-003` | `tournament_stage` | `tournament_stage.id` | 424 901 | not measured | Confirmed-data |
| `REL-PROPERTY-004` | `participant` | `participant.id` | 3 789 703 | not measured | Confirmed-data |
| `REL-PROPERTY-005` | `incident` | `incident.id` | 31 168 021 | **3** | Confirmed-data |
| `REL-PROPERTY-006` | `event_participants` | `event_participants.id` | 14 447 266 | **1** | Confirmed-data |
| `REL-PROPERTY-007` | `object_participants` | `object_participants.id` | 2 236 958 | **40** | Confirmed-data |
| `REL-PROPERTY-008` | `lineup` | `lineup.id` | 207 569 | 0 | Confirmed-data |
| `REL-PROPERTY-009` | `country` | `country.id` | 491 | 0 | Confirmed-data |
| `REL-PROPERTY-010` | `tournament_template` | `tournament_template.id` | 28 | 0 | Confirmed-data |
| `REL-PROPERTY-011` | `language_type` | `language_type.id` | 1 | 0 | Confirmed-data |
| `REL-PROPERTY-012` | `standing` | `standing.id` | 21 | not measured | Confirmed-data |
| `REL-PROPERTY-013` | `standing_participants` | `standing_participants.id` | 352 680 | not measured | Confirmed-data |

`REL-PROPERTY-012` and `-013` are recorded because the owner values exist, not as an opening
of the `standing` family — that family is out of scope and neither its targets nor its
`standing_modifier` vocabulary were pursued.

Row counts are as of the moment each was read and drift between statements while colleagues
correct the data; `event_participants` was read as 14 447 264 and 14 447 266 minutes apart.
They are context, never a basis for a claim. The **44 unresolved rows** are not context: they
are the defect family `DB-SEM` records under question 1's answer, found again here.

#### The type and name taxonomy

Eight `type` values exist and the whole taxonomy is 26 owner/type pairs over 521
owner/type/name triples and 439 distinct names:

| `type` | Distinct names | Owners it appears on |
|---|---:|---|
| `metadata` | 351 | all thirteen |
| `standing_modifier` | 60 | `standing_participants` only — out of scope |
| `ref:participant` | 36 | `incident`, `event`, `event_participants`, `object_participants`, `lineup`, `participant` |
| `ref:offence_type` | 3 | `incident`, `participant` |
| `nrk:ref` | 2 | `event` |
| `date` | 1 | `participant` |
| `rule` | 1 | `standing` |
| `unknown` | 1 | `incident` |

The 351 `metadata` names are sport vocabulary and stay in the sport files that confirm them;
this section owns the mechanism, not each sport's use of it. The other vocabularies are small
enough to be closed sets, and reading them closed is what exposes the following.

**Four names sit under a type that cannot hold them.** `ref:offence_type` carries
`date_of_birth` on 2 rows, a name belonging to `date`. `ref:participant` carries `Live`,
`gameType` and `AwardedWinner` on one row each — the first two are `nrk:ref` names and none
of the three is a participant reference. And the single `unknown` row is named
`offence_typeFK`, which is a `ref:offence_type` name. A statement that trusts `type` to
constrain `name`, or `name` to imply what `value` holds, is wrong on these rows.

**The same thing is spelled more than one way at the same layer.** `offence_typeFK`
(408 044 rows) and `offense_typeFK` (11 804) are one concept in two spellings.
`ref:participant` holds `team` beside `TeamFK`, and `referee`, `refereeFK`,
`second_referee` and `second_refereeFK` as four separate names. Case and suffix are not
normalised, so a name filter has to be written for the variants that exist rather than the
one a reader expects — the `%Fly%`-matching-`Butterfly` mistake in a different form.

### `object_participants`

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

### The import twin model

Read 2026-09-07. Six scope tables have a parallel `*_import` table, and the pattern is
uniform rather than per-table:

| Live table | Import twin |
|---|---|
| `event_scope` | `event_scope_import` |
| `event_scope_detail` | `event_scope_detail_import` |
| `lineup_scope_result` | `lineup_scope_result_import` |
| `scope_result` | `scope_result_import` |
| `scope_type` | `scope_type_import` |
| `scope_data_type` | `scope_data_type_import` |

Each twin carries its live table's own columns plus exactly three staging columns:

- `importID` — the batch the row arrived in;
- `providerFK` — which provider supplied it, resolving against `provider.id`;
- `status_import` `enum('init','mapped','unmapped','import','ignore','in_sync','error')`.

Three differences between a twin and its live table are worth naming, because each one is a
place a statement written against the wrong side goes quietly wrong:

- **The live scope tables carry no `providerFK` at all.** Provenance exists only in the twin,
  so once a row is imported, which provider supplied it cannot be recovered from the live
  table. No check may attribute a scope defect to a provider.
- **`del` reverses its enum order.** Live tables declare `enum('no','yes')`, twins declare
  `enum('yes','no')`. An `enum` numbers its values from 1, so the two columns sort and cast
  differently despite holding the same two words.
- **Key columns widen.** `int` becomes `int unsigned` throughout, and
  `event_scope_import.eventFK` is `bigint` where `event_scope.eventFK` is `int`.

The small twins are fully settled today — `scope_type_import` is `in_sync` on all 594 rows and
`scope_data_type_import` on all 1 103 — but that is a data state and says nothing about the
other four.

### The provider relation

The provider is four tables, not one:

| Table | Rows | What it holds |
|---|---:|---|
| `provider` | 11 | the reference: `id`, `name`, `del`, `n`, `ut`; all 11 active |
| `object_provider` | 1 164 | `object_typeFK` + `objectFK` + `providerFK` + `active` — which provider covers which object |
| `provider_data` | 114 273 | `providerFK` + `object` + `objectFK` + `type` `enum('coverage','export','rule','name')` + `name`/`value` — per-object provider configuration |
| `provider_object_id` | ~87 774 880 | `providerFK` + `object` `varchar(255)` + `last_updated`, and **no `objectFK`** |

The eleven providers are `Spocosy Scrapers`, `LS`, `A1`, `LTR`, `DR.dk`, `Quick Goal`, `SMT`,
`Roninsport`, `Fabric-BB Media`, `Enetpulse` and `SDC`. `information_schema` estimated the
table at 9 rows; it holds 11, which is one more reason those estimates are not counts.

`provider_object_id` has no column pointing at an object. Its `object` holds a table name and
its own `id` appears to be the identity being allocated — a registry mapping one global id
space to a provider and an object kind. **That reading is an inference from the shape and a
13-row sample and was not confirmed**; `last_updated` was `0000-00-00 00:00:00` on every
sampled row.

The import tables and the provider family stay outside the reach of DQ work, by the user's
decision on 2026-09-07. They are recorded so the model is complete, not opened.

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

### Reference-typed properties

A `property` row can carry a reference to another object instead of a literal value. The
type names the target and the value holds its primary key: `type = 'ref:participant'` means
`value` is a `participant.id`, resolved by whoever reads it rather than by the database.

`event_participants` is a property owner in its own right, alongside the owners listed
above, and reference-typed properties are the reason it matters — this is where a sport
stores the second participant an event participation involves when the row itself can hold
only one.

Two things follow, and a check has to work with both:

- **Nothing enforces the reference.** The value is text in a generic table, so it can be
  absent, empty, `0`, a participant that no longer exists, or a participant of the wrong
  type. All five shapes occur in real data and they are different defects with different
  causes; a statement testing only for presence reports the first and misses the others.
- **The name belongs to the sport, the mechanism does not.** Measured 2026-08-18:
  Equestrian binds a rider to a horse as `horseFK`, while Artistic Gymnastics and Triathlon
  bind a competitor to a club as `organizationFK`, all three on `event_participants`. One
  mechanism, three sports, two vocabularies — so a sport file records which names its sport
  uses and this section records only that the mechanism exists.

### Small reference table inventories

Thirteen small reference tables are read across this package and none had a verified column
inventory. All thirteen were read from `information_schema` on 2026-09-07 and are recorded
here in full, because a column list guessed from a name is the kind of error nothing later
catches.

**They share one shape.** Every one of the thirteen carries `id`, `name`, `n`, `ut` and
`del`, and all but `venue_data_type` also carry `description`. `n` and `ut` are the
provider's sequence and update stamp; `del` is the soft-delete flag described by
`DB-SEM-002`.

**Every one of the thirteen has `del`.** None of these catalogues is safe to read as a list
of currently valid values: a retired row is still a row, and a statement that resolves an id
against one of them without excluding `del = 'yes'` will resolve it to a name nobody uses
any more.

`id`, `n` and `del` are `NOT NULL` everywhere. `ut` is `NOT NULL` everywhere except
`scope_type`, `scope_data_type` and `venue_data_type`, where it is nullable — those three
also differ from the rest in column order, placing `del` before `n`. `description` is
nullable only in `language_type`, `scope_type` and `scope_data_type`.

The columns beyond the shared shape are what each table actually contributes:

| Table | Rows | Columns beyond `id`, `name`, `description`, `n`, `ut`, `del` |
|---|---:|---|
| `category` | 0 | — (empty today) |
| `country` | 258 | `enetID` `int unsigned NOT NULL` — the provider's own country key |
| `disability_class` | 212 | — |
| `discipline` | 935 | `sportFK` `int unsigned NOT NULL` — what separates a duplicate name from a foreign catalogue |
| `language_type` | 126 | — (`description` nullable) |
| `object_type` | 160 | `internal` `enum('yes','no')` nullable |
| `round_type` | 301 | `value` `int NOT NULL`, `knockout` `enum('no','yes') NOT NULL` — the pair behind `DB-SEM-012` |
| `scope_data_type` | 977 | — (`description` and `ut` nullable) |
| `scope_type` | 1382 | — (`description` and `ut` nullable; `name` indexed) |
| `tournament_age_class` | 3 | — |
| `tournament_set` | 14 | — |
| `tournament_sub_set` | 97 | `tournament_setFK` `int unsigned NOT NULL` — the only parent-child pair among the thirteen |
| `venue_data_type` | 55 | no `description` at all; `ut` nullable |

Row counts are `information_schema` estimates as of 2026-09-07 and are context, never a
basis for a claim. Types and nullability are declarations and do not move.

Two of these bear directly on checks already written. `discipline.sportFK` is the column
`GLOBAL-DQ-015` and `GLOBAL-DQ-161` both turn on, and it is the reason a duplicate
discipline name and a reference into another sport's catalogue are different defects.
`round_type.knockout` is the second half of the identity `DB-SEM-012` records: one round
name exists twice, once knockout and once not, and only this column tells them apart.

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

**Measured 2026-09-07: today the mapping is nevertheless total.** Every one of the 17
`statistic_participantsN` shards was joined to `statistic` and grouped by
`statistic_typeFK`, over 6 207 616 link rows. The result is exactly 17 rows: shard `N`
holds statistics of type `N` and of no other type, with no exception anywhere.

| Shard | Statistic type | Link rows | | Shard | Statistic type | Link rows |
|---:|---:|---:|---|---:|---:|---:|
| 1 | 1 | 841 137 | | 10 | 10 | 29 609 |
| 2 | 2 | 11 625 | | 11 | 11 | 3 243 256 |
| 3 | 3 | 51 590 | | 12 | 12 | 43 507 |
| 4 | 4 | 356 454 | | 13 | 13 | 2 002 |
| 5 | 5 | 7 729 | | 14 | 14 | 597 826 |
| 6 | 6 | 120 826 | | 15 | 15 | 31 490 |
| 7 | 7 | 9 695 | | 16 | 16 | 38 505 |
| 8 | 8 | 341 026 | | 17 | 17 | 2 464 |
| 9 | 9 | 478 875 | | | | |

The data layer inherits the same split from the schema rather than from the data: each
`statistic_dataN` carries a column named `statistic_participantsNFK`, confirmed for all 17,
so a data shard cannot reach another shard's participants by construction.

**This rule stays as written even so, and that is deliberate.** Nothing in the schema
enforces the mapping — there is no constraint, and question 1's answer records that the
database has no `FOREIGN KEY` anywhere — so the agreement is a property of today's data and
not a guarantee. A statement still confirms its shard from data rather than deriving it from
`statistic_typeFK`, because the day the two diverge is the day a derived statement reads the
wrong table silently. The measurement is recorded to say what the current state is, not to
license the shortcut.

**Type-to-owner is a different matter and is not a rule at all.** The same reading found the
17 types spread across four owner levels — `tournament` (3), `tournament_stage` (4), `event`
(5) and `participant` (15) — in 33 type/owner pairs. No type uses more than two levels, but
which two does not follow from the type, so the owner level must be confirmed per type and
per sport. Comp.Rank, `statistic_typeFK = 11`, sits on `tournament` for 81 502 statistics and
on `tournament_stage` for 1 844.

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

**The five vocabularies were read from the schema on 2026-09-07 and they are not one
vocabulary.** Each is a declared `enum`, so the allowed values are complete and do not move:

| Layer and column | Declared values | Used |
|---|---|---|
| `participant.type` | `team`, `official`, `undefined`, `coach`, `athlete`, `organization`, `horse` | all seven |
| `participant.gender` | `undefined`, `male`, `female`, `mixed`, `mare`, `gelding`, `stallion` | all seven |
| `object_participants.participant_type` | `coach`, `team`, `assistant`, `manager`, `athlete`, `official`, `organization`, `horse` | six — `assistant` and `manager` have no rows |
| `tournament_template.gender` | `undefined`, `male`, `female`, `mixed` | all four |
| `tournament_stage.gender` | `undefined`, `male`, `female`, `mixed` | all four |

Two mismatches follow, and both are the kind a statement gets wrong by assuming the layers
agree:

- **The two type vocabularies differ in both directions.** `object_participants` knows
  `assistant` and `manager`, which `participant` cannot express; `participant` knows
  `undefined`, which `object_participants` cannot. Eight values against seven, and the
  overlap is six.
- **Participant gender and tournament gender are different scales, not one scale read at two
  levels.** The participant column carries three equine sexes — `mare`, `gelding`,
  `stallion`, together 13 854 rows — that no tournament layer can hold. A mare entered in a
  `female` stage is not a contradiction, and a check comparing the two columns directly would
  report one.

`participant.undefined` is nearly unused, at 4 rows of 2 192 216; `object_participants`
`assistant` and `manager` are unused entirely. Neither is grounds for treating the value as
absent — `Applicability is structural, never a row count`.

**187 rows in `object_participants` carry a `participant_type` outside its own
declaration**, spread across 24 sports. They sit at enum index 0, the slot MySQL uses for a
value that was never valid, so the column stores something none of its eight names covers.
Measured 2026-09-07; recorded as a finding, and no check was opened for it.

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

Freestyle Skiing holds 49 values at the limit, and 64 three days later. No other sport on the
server holds one. Correcting the values without widening the column would truncate them again on
the next write, which is why this is a schema fact rather than a correctable one.

**Nothing in the package reports it.** `Golf-DQ-098` did, and was deprecated on 2026-08-20 by
decision: the defect cannot be repaired from here, so a check that reports 167 rows on every run
until somebody else widens a column was judged not worth the space on the board. What that costs
is recorded with the deprecation in `SPORTS/Golf.md`, and the short version is that the 154
values cut on a comma are invisible to every other statement here.

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
  that happens the sport file records the split; `SPORTS/BMX-Racing.md` is the confirmed case.

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

### `DB-SEM-020` — A disability class is its own generic attachment, not a property and not an `object_relation`

The class a Para competition is contested in is stored in a dedicated pair of tables:
`disability_class` is the reference table, holding `id`, `name` and `description`, and
`object_disability_class` is the link, holding `object_typeFK`, `objectFK` and
`disability_classFK`. The shape is the same generic attachment pattern as `object_discipline`
and `object_participants`, and it is the only mechanism the database has for the class.

**It travels through neither of the two paths a reader is likely to try first.** It is not a
`property`, so `GLOBAL-DISCOVERY-011 PROPERTY_USAGE_BY_OWNER` says nothing about it, and it is
not an `object_relation`, so `GLOBAL-DISCOVERY-012 OBJECT_RELATION_USAGE` says nothing either.
Recorded here because that silence reads exactly like an answer: opening Para-Swimming on
2026-09-07, both statements returned no class and the sport was one step from being documented
as not storing one, which is the opposite of the truth.

Measured 2026-09-07, six owner levels are in use:

| Owner | `object_typeFK` | Links | What the attachment means |
|---|---:|---:|---|
| `event` | 5 | 59 339 | the class this event was contested in |
| `participant` | 15 | 7 870 | the class this competitor holds |
| `object_participants` | 59 | 2 276 | the class on a competitor's registry row for a sport |
| `lineup` | 73 | 1 203 | the class of a place in a team entry |
| `sport` | 1 | 398 | **the vocabulary declaration** — which classes belong to this sport |
| `event_participants` | 6 | 30 | the class of one entry into one event |

**The sport-level attachment is a declaration, not a classification**, and it is what makes any
other level checkable. A sport attaches its own classes to itself and that set is the
vocabulary its events and competitors may draw on; 27 sports declare one and all 27 also
classify events, so a check reading an event's class against its sport's vocabulary has a
reference wherever it applies. `GLOBAL-DQ-156` through `GLOBAL-DQ-160` are written against
that declaration rather than against any class-name pattern, because a class is spelled `S9`
in Para Swimming, `T54` in Para Athletics and `C3` in Para Cycling.

**No class is attached to a `statistic` row in any sport.** The Comp.Rank layer has no
disability class and there is no mechanism by which it could carry one, so a ranking check
reading a competitor's class has nothing to read — a structural absence rather than an
unfilled field, and one that no Comp.Rank work will change on its own.

### `DB-SEM-021` — An incident names a person inside a team, not a second participant

`incident` hangs off `event_participants`, and on a team sport that parent row is the
**team's** participation in the event. `ref_participantFK` is what supplies the person:
it holds a `participant.id`, and its role is the competitor the incident is about.

Measured 2026-09-07 over all 14 405 259 incident rows:

| Reading | Rows |
|---|---:|
| `ref_participantFK` is `NULL` | 0 |
| `ref_participantFK` is `0` | 562 410 |
| `ref_participantFK` resolves to an existing `participant` | 13 842 849 |
| `ref_participantFK` resolves to nothing | **0** |

By participant type, with the owning `event_participants` row always a `team`:
13 560 824 `athlete`, 281 764 `coach`, 261 `official`, and 22 `team`.

**The name invites the wrong reading and the data refutes it.** "Additional participant-like
reference" suggests a second person alongside a first — the assisting player, the player
replaced. It is not: the column is populated across every incident type, including ones that
involve one person only, because the parent row never held a person to begin with. `Assist`
carries it on 947 518 of 950 299 rows, `Yellow card` on 1 370 808 of 1 407 769.

Two consequences for a statement reading this table:

- **`0` is the absence marker, not `NULL`.** The column is `NOT NULL` and unset rows carry
  zero, so `IS NULL` finds nothing and a join without `> 0` silently drops them.
- **The type is part of the contract.** 22 rows hold a `team` where every other row holds a
  person, and 19 of those point at the owning team itself. That is a defect shape rather than
  a second convention, and it is recorded here so a check that wants it has the measurement
  it was found by. No check was written for it on 2026-09-07 — the user closed this as a
  structural fact and left the DQ question unopened.

Whether the named person belongs to that team's lineup for that event is a further question
and was not measured.

### `DB-SEM-022` — A statistic field is identified by type, category and name together

`statistic_data_type` is the field catalogue. Read whole on 2026-09-07: 1 236 rows, 506
distinct names, 17 distinct `statistic_typeFK` values, every one of which resolves against
`statistic_type.id` with no zeros and nothing dangling.

**The per-type field sets are not disjoint.** 224 of the 506 names appear under more than one
statistic type, and one name appears under seven. A name alone says nothing about which type
a field belongs to.

**Nor does type plus name identify a field.** `statistic_data_type_categoryFK` is the third
part of the key, and it is what separates rows that otherwise look identical:

| Key tried | Duplicated groups among `del = 'no'` rows |
|---|---:|
| `statistic_typeFK` + `name` | 80 |
| `statistic_typeFK` + `statistic_data_type_categoryFK` + `name` | **0** |

Twenty-one categories exist and every `statistic_data_type_categoryFK` resolves. The same
field name legitimately occurs in two sections of one statistic type, so a lookup keyed on
type and name returns two rows where the author expected one — and silently takes whichever
the optimiser returned first if it was written as a scalar.

Including soft-deleted rows the triple collides exactly once, against one of the 5 rows the
catalogue marks `del = 'yes'`.

### `DB-SEM-023` — The statistic shards are not interchangeable, in columns or in collation

Read from `information_schema` on 2026-09-07 over all 34 shard tables. Every one is InnoDB.

**`statistic_participantsN` agrees on columns everywhere** — `id`, `statisticFK`,
`participantFK`, `del`, `n`, `ut`, with identical types and nullability across all 17.

**`statistic_dataN` does not.** It has five distinct column signatures:

| Shards | Columns | `value` collation | `del` collation |
|---|---|---|---|
| 1–9 | base 8 | `utf8mb3_general_ci` | `latin1_swedish_ci` |
| 10–11 | base 8 | `utf8mb3_general_ci` | `utf8mb3_general_ci` |
| 12–13 | base 8 **+ `sub_param`** | `utf8mb3_general_ci` | `utf8mb3_general_ci` |
| 14–15 | base 8 **+ `sub_param`** | `utf8mb4_0900_ai_ci` | `utf8mb4_0900_ai_ci` |
| 16–17 | base 8 | `utf8mb4_general_ci` | `utf8mb4_general_ci` |

`sub_param` `varchar(255)` nullable exists on four shards and on no other. It carries data on
two of them: shard 13 fills it on all 1 472 067 rows and shard 12 on 1 470 058 of 1 512 609,
while shards 14 and 15 declare it and leave it empty on every row. Types 12 and 13 are
`Player Action Zone Stats` and `Team Action Zone Stats`, so the extra column is the zone
parameter those two types need.

**Collation splits the same way on both families, 13 / 2 / 2**: shards 1–13
`utf8mb3_general_ci`, 14–15 `utf8mb4_0900_ai_ci`, 16–17 `utf8mb4_general_ci` — at table level
and on every text column.

Three consequences for a statement:

- **A `UNION ALL` across shards cannot project a uniform column list** unless it names the
  base eight explicitly. Selecting `sub_param` breaks on 13 of 17 shards, and `SELECT *`
  produces branches of different width.
- **String comparison is not the same operation in every shard.** `utf8mb3_general_ci`,
  `utf8mb4_general_ci` and `utf8mb4_0900_ai_ci` differ in sort order and in accent handling,
  so an equality or an `ORDER BY` on `value` is shard-dependent, and comparing a value from a
  `utf8mb3` shard against one from a `utf8mb4` shard forces a coercion or fails outright as an
  illegal mix.
- **`del` in shards 1–9 is `latin1_swedish_ci` while its own table is `utf8mb3`.** It is an
  `enum` so the practical effect is nil, but it is the clearest sign that these tables were
  not created together and should not be assumed to have been.

A caution measured alongside this: `information_schema.TABLE_ROWS` estimated
`statistic_data12` at 453 337 rows against an actual 1 512 609, a factor of 3.3. Shard row
estimates are unusable as counts.

<!-- MANUAL PASTE ZONE: DATABASE STRUCTURAL SEMANTICS — insert approved additions immediately before this marker; do not move or delete it. -->

---

## 11. Global open questions

- ~~Physical FK enforcement for the registered logical relations.~~ **Answered 2026-09-07:
  there is none, anywhere.** The schema holds **zero** `FOREIGN KEY` constraints across its
  501 base tables, and all 501 are InnoDB — so the absence is a choice rather than an engine
  limitation. Every `...FK` column is a naming convention and nothing else.

  The consequence is why half this package exists, and it is stated here rather than left to
  be inferred: **an unresolved reference is a permanent defect family and never a transient
  state.** Nothing prevents a link to a deleted row, to no row at all, or to a row belonging
  to another sport, so each has to be asked by a check. All three were found in Para-Swimming
  on the day this was measured — 7 events on `discipline_id` 0, 788 pointing into Swimming's
  discipline catalogue, and classes outside the sport's own registered vocabulary.
- ~~Confirmed cardinality, uniqueness and mandatory status for most relations.~~
  **Answered 2026-09-07 from the schema itself.** Across the 501 base tables there are
  **835** columns named `...FK`, in **397** tables:

  | Property | Count | Share |
  |---|---:|---:|
  | Declared `NOT NULL` | 800 | 96% |
  | Nullable | 35 | 4% |
  | Named in some unique index | 87 | 10% |
  | Named only in non-unique indexes | 533 | 64% |
  | Named in no index at all | 215 | 26% |
  | The leading column of some index | 355 | 43% |

  **Mandatory status is therefore declared almost everywhere, and uniqueness effectively
  nowhere.** The sharpest form of that second reading: **not one FK-named column in the
  schema is unique on its own.** All 87 that touch a unique index do so as one member of a
  composite — so the schema constrains combinations and never once declares "this table
  holds one row per referenced object".

  The consequence for this package, which is the part that must not be re-derived:
  **cardinality is never inherited from the schema, only measured.** A statement may not
  assume one child per parent, one class per event, one result per participant. Where a rule
  depends on it, the rule is what asserts it, and a check has to ask. `GLOBAL-DQ-160` exists
  because `object_disability_class` permits several classes on one event, and `GLOBAL-DQ-162`
  had to be rewritten from a per-pair inequality into set membership for the same reason —
  both on the day this was measured.

  The 215 unindexed and the 480 that lead no index are also a cost fact, not only a
  correctness one: a lookup keyed on one of those columns alone has no index path. That is
  the same mechanism `DB-SEM-016` records for the template filter, generalised.
- ~~Full verified column inventories for several small reference tables.~~
  **Answered 2026-09-07.** All thirteen are recorded in full under § 6
  "Small reference table inventories", with the shape they share and each one's deviations
  from it. The finding worth carrying out of that section: **every one of the thirteen has a
  `del` column**, so none of them is a list of currently valid values until `del = 'yes'` is
  excluded.
- ~~Target semantics of `incident.ref_participantFK`.~~ **Answered 2026-09-07: it is
  `participant.id`, and it names the person the incident is about inside the owning team.**
  `DB-SEM-021` holds the measurement and the two traps — `0` rather than `NULL` marks
  absence, and 22 rows hold a team where 13.8 million hold a person.
- ~~Complete allowed values for participant type and gender/category fields.~~
  **Answered 2026-09-07.** All five are declared `enum`s, so the complete lists are in
  `DB-SEM-009` along with what each layer actually uses. The two findings that change how a
  statement is written: the two type vocabularies differ in both directions, and participant
  gender is a different scale from tournament gender rather than the same one read twice.
- ~~Complete property owner/type/name taxonomy.~~ **Answered 2026-09-07** under § 9
  `property`: 13 owner values, 8 types, 26 owner/type pairs, 521 triples, 439 names. The
  registry grew from 4 rows to 13 — `incident` and `event_participants`, the second and third
  largest owners, were unregistered. Four names sit under a type that cannot hold them, and
  `offence_typeFK`/`offense_typeFK` are one concept in two spellings. The 351 `metadata`
  names stay with the sport files that confirm them.
- ~~`saved_json_player` (columns: id, atp_id, name, firstname, lastname, gender, country_code, dob, active, mapped, del, ut, n) has no direct foreign key to `participant`; observed linkage is only a heuristic exact-text match on `name`. The `mapped` flag does not reliably indicate match status. Duplicate `saved_json_player` rows with the same name have been observed mapping to the same `participant.id` (name-collision risk). The table's relationship to `participant`, its canonical-vs-staging role, and its sport scope are not confirmed.~~

  **Answered 2026-09-07: it is a provider staging table, it sits outside the confirmed model,
  and nothing in this package may read it.** 18 832 rows, every one `active = 'yes'`, not one
  `del = 'yes'`, `ut` spanning 2012-11-05 to 2026-01-19.

  **Its key is `atp_id`, not `name`.** `varchar(30)`, `NOT NULL`, indexed, and distinct
  across all 18 832 rows. It carries two provider id systems under one column name: every one
  of the 7 210 `female` rows is numeric, while 11 585 of the 11 622 `male` rows are
  alphanumeric.

  **`name` is not identity, and `mapped` is wrong in both directions.** Matched against
  `participant` rows of type `athlete` by exact name:

  | `mapped` | Rows | No name match at all | Exactly one | More than one |
  |---|---:|---:|---:|---:|
  | `yes` | 9 098 | **508** | 7 107 | 1 483, worst case 22 |
  | `no` | 9 734 | 6 504 | **2 476** | 754, worst case 33 |

  So 508 rows claim a mapping to a name no athlete holds, and 3 230 rows claim none while
  holding a name that matches. Where a match exists it is often not unique: 2 237 rows resolve
  to more than one athlete. The table also collides with itself — 157 names appear on 317
  rows.

  **The sport scope is not stored anywhere in the table.** The two id systems are ATP's and
  WTA's, which points at tennis; `Tennis` is `sport.id` 2, and `Wheelchair Tennis` (141) and
  `Para Table Tennis` (121) exist alongside it. That is an inference from the shape of the
  identifiers and was not measured as a relation, which is precisely why the table cannot
  anchor anything.

  The conclusion is the usable part: **a check may not join through this table, and its
  `mapped` flag is not evidence of anything.** Any true mapping to `participant` lives in the
  import process, not in the schema.
- ~~Universal statistic type-to-owner and type-to-shard rules, if any.~~
  **Answered 2026-09-07: one of the two exists.** Shard `N` holds statistic type `N` and
  nothing else, across all 17 shards and 6 207 616 link rows with no exception, and each
  `statistic_dataN` names `statistic_participantsNFK` so the data layer splits the same way by
  schema. Type-to-owner is not a rule: 17 types over four owner levels in 33 pairs, never more
  than two levels per type, and which two does not follow from the type.

  `DB-SEM-006` keeps its requirement to confirm the shard from data even so — the user's
  decision, and the reason is recorded there: nothing enforces the mapping, so it is today's
  state rather than a guarantee.
- ~~Target of `statistic_data_type.statistic_typeFK`. The column filters the field catalog
  per statistic type, but its resolution against `statistic_type.id` was not independently
  verified, and it is unknown whether the per-type field sets are disjoint.~~
  **Answered 2026-09-07: it resolves against `statistic_type.id` completely, and the field
  sets are not disjoint.** 224 of 506 names appear under more than one type, one under seven.
  `DB-SEM-022` records what does identify a field — type, category and name together, which
  leaves zero duplicated groups where type and name alone leave 80.
- ~~Soft-delete behavior of `statistic_type`, `statistic_data_type` and
  `statistic_data_type_category`. No `del` column was confirmed, so the reference catalogs
  may include retired rows.~~

  **Answered 2026-09-07: all three carry `del enum('no','yes') NOT NULL`, and two of the
  three do hold retired rows.**

  | Catalogue | Rows | `del = 'yes'` |
  |---|---:|---:|
  | `statistic_type` | 17 | 0 |
  | `statistic_data_type` | 1 236 | 5 |
  | `statistic_data_type_category` | 21 | 1 |

  The retired rows are `Goals ratio` (id 7, type 3), `Minutes per goal` (42, type 3),
  `Goals interval` (146, type 1), `Goals interval (%)` (148, type 1) and `Winners 2s`
  (1469, type 8); the retired category is `General` (23), which holds exactly one field and
  that field is 1469, itself retired.

  **This is live, not latent: 310 `statistic_data` rows carry values under four of those five
  retired field definitions** — 76 on `Goals interval`, 76 on `Goals interval (%)`, 16 on
  `Minutes per goal` and 142 on `Winners 2s`. Only `Goals ratio` has none. So a statement that
  resolves a field id through this catalogue without excluding `del = 'yes'` will present a
  retired definition as a current one.

  Thirteen places in the package read these catalogues today with no `del` filter:
  `GLOBAL-DQ-070 COMP.RANK_RESULTS_VALUE_BLANK`,
  `GLOBAL-DQ-077 COMP.RANK_RESULTS_NUMERIC_FIELD_NON_NUMERIC`,
  `GLOBAL-DQ-099 COMP.RANK_VALUE_BELONGS_TO_ANOTHER_FIELD`,
  `Equestrian-DQ-098 COMP.RANK_PAIR_SIDES_CONTRADICT_EACH_OTHER`,
  `Equestrian-DQ-108 COMP.RANK_PAIR_FIELD_CARRIED_BY_ONE_SIDE_ONLY`, and the discovery
  statements `GLOBAL-DISCOVERY-015 STATISTIC_TYPES_AND_OWNERS`,
  `-017 STATISTIC_DATA_AND_CONFIG_FIELDS` (twice),
  `-028 STATISTIC_DATA_VALUE_PATTERNS_SUMMARY`,
  `-029 STATISTIC_DATA_VALUE_PATTERNS_DETAIL`,
  `-030 STATISTIC_DATA_TYPE_CATALOG` (twice) and
  `-031 STATISTIC_DATA_TYPE_DECLARED_VS_USED`.

  **No statement was changed on the strength of this**, by the user's decision on
  2026-09-07. The two halves are not the same problem: a discovery statement describing what
  the catalogue contains arguably wants the retired rows in view, while a DQ statement
  resolving a field ought to exclude them. Deciding that is separate work, and the five DQ
  statements are all Comp.Rank, which is paused.
- ~~Schema and collation equality across all statistic data shards.~~ **Answered 2026-09-07:
  neither holds.** `statistic_dataN` has five distinct column signatures and four shards carry
  a `sub_param` column the other thirteen do not; collation splits 13 / 2 / 2 across three
  different collations on both shard families. `DB-SEM-023` holds the full map and the three
  consequences — a cross-shard `UNION` must name its columns, string comparison is
  shard-dependent, and the shards were plainly not created together.
- ~~Complete scope import-table model and provider relation.~~ **Answered 2026-09-07** under
  § 5. Six scope tables have an import twin and the pattern is uniform: live columns plus
  `importID`, `providerFK` and a seven-value `status_import`. The provider is four tables and
  11 named providers. The consequence that binds a check: **the live scope tables carry no
  `providerFK`**, so a scope defect can never be attributed to a provider. The import tables
  and provider family are recorded, not opened.
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
