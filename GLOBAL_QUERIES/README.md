# GLOBAL Structural Discovery Query Registry

## Purpose

GLOBAL queries are canonical reusable structural-discovery SQL templates. They are
stored once and executed for a selected sport by replacing their declared parameters.

GLOBAL does not mean that a statement scans every sport. It means that the SQL logic is
reusable and has no undocumented sport-specific assumption.

## Execution contract

1. Select only the smallest query that answers the user's request.
2. Copy that one statement from its domain SQL file.
3. Replace every mandatory `{{...}}` token in the working copy.
4. Preserve its `GLOBAL-DISCOVERY-NNN` QueryID.
5. Execute one statement at a time.
6. Never save the substituted sport-specific copy back into the project.
7. Do not run or return the full catalog automatically.

Optional commented filters may be activated when needed. A mandatory placeholder left
unreplaced makes the statement intentionally non-executable.

Steps 2 and 3 may be performed by `TOOLS/Run-Query.ps1`, which copies the statement by
QueryID and substitutes the declared parameters without persisting the result. The
execution contract is unchanged; see `TOOLS/README.md`.

## Parameter meanings

| Parameter | Meaning |
|---|---|
| `{{SPORT_ID}}` | Confirmed numeric `sport.id` |
| `{{ROUND_TYPE_ID}}` | Round type selected from the corresponding summary query |
| `{{NAME_PATTERN}}` | Digit-normalized name pattern selected from a summary query |
| `{{RESULT_TYPE_ID}}` | Result type selected from the event-result inventory |
| `{{STATISTIC_TYPE_ID}}` | Confirmed `statistic.statistic_typeFK` |
| `{{STATISTIC_OWNER_TYPE_ID}}` | Confirmed `statistic.object_typeFK` |
| `{{SHARD_ID}}` | Confirmed physical statistic participant/data shard number |
| `{{STATISTIC_DATA_TYPE_ID}}` | Data type selected from the statistic field inventory |
| `{{VALUE_PATTERN}}` | Digit-normalized value pattern (or `<NULL>`/`<EMPTY>`) selected from the corresponding value-pattern summary query |

`{{SHARD_ID}}` is textual substitution inside table and parent-column names. It is not
an SQL bind variable. Never infer it from `statistic_typeFK`.

String replacements such as `{{NAME_PATTERN}}` are inserted inside SQL quotes and must
be SQL-escaped when the selected value contains a quote or backslash.

## Source declaration

A parameter whose value is chosen from another statement's result names that statement in
the SQL, on the placeholder's own line, in one of two forms:

```sql
AND r.result_typeFK = {{RESULT_TYPE_ID}}  -- select result_type_id from GLOBAL-DISCOVERY-007 (EVENT_RESULTS_TYPES_CODES)
-- {{ROUND_TYPE_ID}}: select round_type_id from GLOBAL-DISCOVERY-018 (EVENT_ROUND_TYPE_USAGE_SUMMARY)
```

The second form is for a placeholder appearing more than once, where no single occurrence is
the one to hang the declaration on. Both name the column to read the value from and the
`GLOBAL-DISCOVERY-NNN` that returns it, and the column name is the one that statement
projects.

A source covering more than the consumer reads narrows itself with a trailing
`where <column> = <value>`, where the value may carry a declared parameter:

```sql
AND sd.statistic_data_typeFK = {{STATISTIC_DATA_TYPE_ID}}  -- select statistic_data_type_id from GLOBAL-DISCOVERY-017 (STATISTIC_DATA_AND_CONFIG_FIELDS) where storage_layer = statistic_data{{SHARD_ID}}
```

`GLOBAL-DISCOVERY-017` inventories `statistic_config` beside the data shard and orders by
storage layer, so its config rows always come first, while `GLOBAL-DISCOVERY-028` and
`GLOBAL-DISCOVERY-029` read the shard alone. The filter is not a way to pick better values —
it is the consumer stating which of its source's rows are about the layer it reads, which no
ordering could have supplied. Without it every fed value returns nothing, and a chain that
audited the wrong layer reports as a clean one.

The declaration is the record of where a value legitimately comes from, and reading it is
what lets `TOOLS/Run-Query.ps1 -Chain` run a drill-down without a pairing list; `TOOLS/README.md`
owns that behaviour. A drill-down added without a declaration fails `TOOLS/Test-Tools.ps1`.
It is documentation first: a reader following the catalogue by hand needs the same answer.

## Registry

The `Description` column mirrors each statement's `-- What it does:` comment in the SQL.
Every query whose `Mandatory parameters` column lists `SPORT_ID` is scoped to the selected
`{{SPORT_ID}}`, so that phrase is omitted below. A query that omits `SPORT_ID` reads a
reference table only and returns the same rows for every sport.

| QueryID | Name | File | Description | Mandatory parameters | Applicability/prerequisite | Primary documentation destination |
|---|---|---|---|---|---|---|
| GLOBAL-DISCOVERY-001 | SPORT_IDENTITY | `CORE.sql` | Returns the sport identity (id, name, enet code) for the numeric sport ID. | `SPORT_ID` | None | `SPORTS/<SportSlug>.md` Identity |
| GLOBAL-DISCOVERY-002 | CORE_HIERARCHY_USAGE | `CORE.sql` | Summarizes active templates, tournaments, stages, events and event participants under the sport. | `SPORT_ID` | None | Structural coverage / Tables and relations |
| GLOBAL-DISCOVERY-003 | EVENT_STATUS_USAGE | `CORE.sql` | Lists coarse and detailed status combinations used by active events. | `SPORT_ID` | Active hierarchy events | Event and round representation |
| GLOBAL-DISCOVERY-004 | EVENT_PARTICIPANT_TYPES_GENDERS | `PARTICIPANTS.sql` | Lists participant types and genders used by active event participants. | `SPORT_ID` | Active event participants | Participant and lineup structure |
| GLOBAL-DISCOVERY-005 | LINEUP_TYPES_PARTICIPANT_TYPES | `PARTICIPANTS.sql` | Lists active lineup types and member participant types and genders. | `SPORT_ID` | Active lineups | Participant and lineup structure |
| GLOBAL-DISCOVERY-006 | SPORT_REGISTRY_PARTICIPANT_TYPES | `PARTICIPANTS.sql` | Lists participant roles, types, genders and active flags from the sport's object_participants registry. | `SPORT_ID` | Active sport registry rows | Participant and lineup structure |
| GLOBAL-DISCOVERY-007 | EVENT_RESULTS_TYPES_CODES | `EVENT_DATA.sql` | Lists active result type and result code combinations used by event participants. | `SPORT_ID` | Active event result rows | Event result types |
| GLOBAL-DISCOVERY-008 | INCIDENT_TYPES_CODES | `EVENT_DATA.sql` | Lists active incident type and incident code combinations used by event participants. | `SPORT_ID` | Active incidents | Incident types |
| GLOBAL-DISCOVERY-009 | SCOPE_TYPES | `EVENT_DATA.sql` | Lists active event-scope container types used by events. | `SPORT_ID` | Active event-scope containers | Scope types and data types |
| GLOBAL-DISCOVERY-010 | SCOPE_DATA_TYPES_AND_LAYERS | `EVENT_DATA.sql` | Lists participant-owned, lineup-owned and detail value layers used under event scopes. | `SPORT_ID` | Active scope value rows | Scope types and data types |
| GLOBAL-DISCOVERY-011 | PROPERTY_USAGE_BY_OWNER | `METADATA.sql` | Lists active property types and names used by known hierarchy, event-participation and participant owners. | `SPORT_ID` | Known sport hierarchy, event-participation and participant owner paths | Properties |
| GLOBAL-DISCOVERY-012 | OBJECT_RELATION_USAGE | `METADATA.sql` | Lists active source/target object-type combinations used by hierarchy and tournament-owned statistic paths. | `SPORT_ID` | Known hierarchy owner paths | Generic relations and disciplines |
| GLOBAL-DISCOVERY-013 | OBJECT_DISCIPLINE_USAGE | `METADATA.sql` | Lists disciplines attached to active events and tournament-owned statistics. | `SPORT_ID` | Known hierarchy/statistic owner paths | Generic relations and disciplines |
| GLOBAL-DISCOVERY-014 | TOURNAMENT_STAGE_REFERENCE_STORAGE | `METADATA.sql` | Shows direct country, host-country relation, city link and age-class relation storage for active stages. | `SPORT_ID` | Active stages | Tables and relations / Storage semantics |
| GLOBAL-DISCOVERY-015 | STATISTIC_TYPES_AND_OWNERS | `STATISTICS.sql` | Lists statistic types and owner levels reachable through known sport hierarchy and sport-registry paths. | `SPORT_ID` | Known owner paths 1,2,3,4,5,6,15 | Statistics |
| GLOBAL-DISCOVERY-016 | STATISTIC_PARTICIPANT_SHARD_USAGE | `STATISTICS.sql` | Tests one physical participant shard for a confirmed statistic type and owner level. | `SPORT_ID`, `STATISTIC_TYPE_ID`, `STATISTIC_OWNER_TYPE_ID`, `SHARD_ID` | Run 015 first; test one physical shard | Statistics |
| GLOBAL-DISCOVERY-017 | STATISTIC_DATA_AND_CONFIG_FIELDS | `STATISTICS.sql` | Lists active data and config field types for a confirmed statistic type, owner level and physical shard. | `SPORT_ID`, `STATISTIC_TYPE_ID`, `STATISTIC_OWNER_TYPE_ID`, `SHARD_ID` | Run 016 first and confirm shard | Statistics / Reference values |
| GLOBAL-DISCOVERY-018 | EVENT_ROUND_TYPE_USAGE_SUMMARY | `PATTERNS.sql` | Summarizes round_typeFK values and names used by active events. | `SPORT_ID` | Active events | Event and round representation |
| GLOBAL-DISCOVERY-019 | EVENT_ROUND_TYPE_USAGE_DETAIL | `PATTERNS.sql` | Lists active events using one round_typeFK selected from 018. | `SPORT_ID`, `ROUND_TYPE_ID` | Select ID from 018 | Event and round representation |
| GLOBAL-DISCOVERY-020 | EVENT_NAME_PATTERNS_SUMMARY | `PATTERNS.sql` | Groups active event names by a digit-normalized pattern. | `SPORT_ID` | Active events | Event and round representation |
| GLOBAL-DISCOVERY-021 | EVENT_NAME_PATTERNS_DETAIL | `PATTERNS.sql` | Lists active events matching one digit-normalized name pattern selected from 020. | `SPORT_ID`, `NAME_PATTERN` | Select pattern from 020 | Event and round representation |
| GLOBAL-DISCOVERY-022 | TOURNAMENT_STAGE_NAME_PATTERNS_SUMMARY | `PATTERNS.sql` | Groups active tournament-stage names by a digit-normalized pattern. | `SPORT_ID` | Active stages | Event and round representation |
| GLOBAL-DISCOVERY-023 | TOURNAMENT_STAGE_NAME_PATTERNS_DETAIL | `PATTERNS.sql` | Lists active stages matching one digit-normalized name pattern selected from 022. | `SPORT_ID`, `NAME_PATTERN` | Select pattern from 022 | Event and round representation |
| GLOBAL-DISCOVERY-024 | STATISTIC_NAME_PATTERNS_SUMMARY | `PATTERNS.sql` | Groups statistic names by a digit-normalized pattern for a confirmed statistic type and owner level. | `SPORT_ID`, `STATISTIC_TYPE_ID`, `STATISTIC_OWNER_TYPE_ID` | Run 015 first | Statistics |
| GLOBAL-DISCOVERY-025 | STATISTIC_NAME_PATTERNS_DETAIL | `PATTERNS.sql` | Lists statistics matching one digit-normalized name pattern selected from 024. | `SPORT_ID`, `STATISTIC_TYPE_ID`, `STATISTIC_OWNER_TYPE_ID`, `NAME_PATTERN` | Select pattern from 024 | Statistics |
| GLOBAL-DISCOVERY-026 | EVENT_RESULTS_VALUE_PATTERNS_SUMMARY | `PATTERNS.sql` | Groups event-result values by a digit-normalized pattern, for one result type chosen from the inventory (GLOBAL-DISCOVERY-007). | `SPORT_ID`, `RESULT_TYPE_ID` | Run 007 first | Event result types |
| GLOBAL-DISCOVERY-027 | EVENT_RESULTS_VALUE_PATTERNS_DETAIL | `PATTERNS.sql` | Lists events holding a result that matches the chosen result type and value pattern, one row per event. | `SPORT_ID`, `RESULT_TYPE_ID`, `VALUE_PATTERN` | Select pattern from 026 | Event result types |
| GLOBAL-DISCOVERY-028 | STATISTIC_DATA_VALUE_PATTERNS_SUMMARY | `PATTERNS.sql` | Groups statistic-data values by a digit-normalized pattern, for one statistic type, owner level, shard and data type chosen from the field inventory (GLOBAL-DISCOVERY-017). | `SPORT_ID`, `STATISTIC_TYPE_ID`, `STATISTIC_OWNER_TYPE_ID`, `SHARD_ID`, `STATISTIC_DATA_TYPE_ID` | Run 015–017 first | Statistics |
| GLOBAL-DISCOVERY-029 | STATISTIC_DATA_VALUE_PATTERNS_DETAIL | `PATTERNS.sql` | Lists statistics holding a data value that matches the chosen data type and value pattern, one row per statistic. | `SPORT_ID`, `STATISTIC_TYPE_ID`, `STATISTIC_OWNER_TYPE_ID`, `SHARD_ID`, `STATISTIC_DATA_TYPE_ID`, `VALUE_PATTERN` | Select pattern from 028 | Statistics |
| GLOBAL-DISCOVERY-030 | STATISTIC_DATA_TYPE_CATALOG | `STATISTICS.sql` | Lists the data field types declared for one statistic type, with code and data-type category. | `STATISTIC_TYPE_ID` | Run 015 first; reads the reference catalog only and is not sport-scoped | Statistics / Reference values |
| GLOBAL-DISCOVERY-031 | STATISTIC_DATA_TYPE_DECLARED_VS_USED | `STATISTICS.sql` | Compares the data field types declared for one statistic type against their use in one owner level and shard, keeping declared but unused types. | `SPORT_ID`, `STATISTIC_TYPE_ID`, `STATISTIC_OWNER_TYPE_ID`, `SHARD_ID` | Run 015–016 first and confirm shard | Statistics / Reference values |
| GLOBAL-DISCOVERY-032 | EVENT_DISCIPLINE_GENDER_PARTICIPANT_MATRIX | `METADATA.sql` | Lists every combination of discipline, stage gender and participant type the sport has contested, with event and template counts and the years first and last seen, so an uncontested combination is read off rather than assumed. | `SPORT_ID` | Sport carrying disciplines on events | Generic relations and disciplines |
| GLOBAL-DISCOVERY-033 | PARTICIPANT_DUPLICATE_CANDIDATES_BY_NAME | `PARTICIPANTS.sql` | Groups a sport's registered people whose names hold the same parts in any order, reporting each group's dates of birth and how much history every record carries. | `SPORT_ID`, `PERSON_PARTICIPANT_TYPE_LIST`, `STATISTIC_TYPE_ID`, `SHARD_ID` | Sport registry; a name of two parts or more | Participant and lineup structure |

<!-- MANUAL PASTE ZONE: GLOBAL QUERY REGISTRY — insert approved additions immediately before this marker; do not move or delete it. -->

## Qualification rule

A query qualifies as GLOBAL only when:

- its relation path is supported by `DATABASE.md`;
- its output meaning is stable across applicable sports;
- every varying input is declared;
- it contains no hard-coded sport ID or sport name;
- it contains no DQ requiredness, violation or tolerance assumption;
- one QueryID identifies exactly one executable statement.

If the logic differs by sport, use an ad-hoc query or an approved sport-specific
discovery exception.

## Evidence rule

Counts and samples returned by discovery queries are operational evidence. Document the
stable mechanism, IDs, usage or value shapes—not transient counts or example row IDs.

## Aggregation and ordering rule

Every registered query returns one row per distinct audited object (event, statistic,
stage, participant, value pattern) — never one row per raw child record. Collapse join
fan-out with `GROUP BY` on the object before counting. Express counts as
`COUNT(DISTINCT <object_id>)`; raw record counts appear only as named secondary columns.
Order by the audited object ID, or by a per-object aggregate when ranking is more useful.

## Query cost rule

The database is large enough that an unscoped statement fails with a request timeout or
with `Allowed memory size of 134217728 bytes exhausted`. Execute the smallest statement
that answers the question: keep the sport anchor, activate a narrowing filter (template,
half-open date range or primary-key range) for a large sport, run a summary query before
its detail counterpart, use one confirmed `{{SHARD_ID}}` per execution, and cap ad-hoc
detail output with `LIMIT`. The full rule is in `WORKFLOW.md`.

## BMX migration mapping

Historical record of a one-time migration performed before the current identity rule. The
former `BMX-DQ-023` through `BMX-DQ-028` PATTERN_CATALOG identities were retired, removed
from the PowerBI registry, and their CheckIDs reclaimed by renumbering the remaining rows.
Their reusable purposes are represented by `GLOBAL-DISCOVERY-018` through
`GLOBAL-DISCOVERY-029`.

That renumbering is not a precedent. `POWERBI.md` now forbids renumbering, deleting or
reusing an assigned CheckID; a deprecated check keeps its row and its ID.

The `BMX-DQ-` above is left spelled as it was. The sport's slug became `BMX-Racing` on
2026-09-04 when `sport.id` 58 was separated into the two sports it holds, and every live check
moved with it - `BMX-DQ-023` became `BMX-Racing-DQ-023`, number unchanged. Rewriting the
identities in this paragraph would say the retirement happened to checks that did not exist
under those names at the time, and the old spelling now points at nothing else.

## Manual registry-rule additions

Registry-policy changes are inserted immediately before the marker below.

<!-- MANUAL PASTE ZONE: GLOBAL QUERY RULES — insert approved additions immediately before this marker; do not move or delete it. -->
