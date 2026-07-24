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

`{{SHARD_ID}}` is textual substitution inside table and parent-column names. It is not
an SQL bind variable. Never infer it from `statistic_typeFK`.

String replacements such as `{{NAME_PATTERN}}` are inserted inside SQL quotes and must
be SQL-escaped when the selected value contains a quote or backslash.

## Registry

| QueryID | Name | File | Mandatory parameters | Applicability/prerequisite | Primary documentation destination |
|---|---|---|---|---|---|
| GLOBAL-DISCOVERY-001 | SPORT_IDENTITY | `CORE.sql` | `SPORT_ID` | None | `SPORTS/<SportSlug>.md` Identity |
| GLOBAL-DISCOVERY-002 | CORE_HIERARCHY_USAGE | `CORE.sql` | `SPORT_ID` | None | Structural coverage / Tables and relations |
| GLOBAL-DISCOVERY-003 | EVENT_STATUS_USAGE | `CORE.sql` | `SPORT_ID` | Active hierarchy events | Event and round representation |
| GLOBAL-DISCOVERY-004 | EVENT_PARTICIPANT_TYPES_GENDERS | `PARTICIPANTS.sql` | `SPORT_ID` | Active event participants | Participant and lineup structure |
| GLOBAL-DISCOVERY-005 | LINEUP_TYPES_PARTICIPANT_TYPES | `PARTICIPANTS.sql` | `SPORT_ID` | Active lineups | Participant and lineup structure |
| GLOBAL-DISCOVERY-006 | SPORT_REGISTRY_PARTICIPANT_TYPES | `PARTICIPANTS.sql` | `SPORT_ID` | Active sport registry rows | Participant and lineup structure |
| GLOBAL-DISCOVERY-007 | EVENT_RESULTS_TYPES_CODES | `EVENT_DATA.sql` | `SPORT_ID` | Active event result rows | Event result types |
| GLOBAL-DISCOVERY-008 | INCIDENT_TYPES_CODES | `EVENT_DATA.sql` | `SPORT_ID` | Active incidents | Incident types |
| GLOBAL-DISCOVERY-009 | SCOPE_TYPES | `EVENT_DATA.sql` | `SPORT_ID` | Active event-scope containers | Scope types and data types |
| GLOBAL-DISCOVERY-010 | SCOPE_DATA_TYPES_AND_LAYERS | `EVENT_DATA.sql` | `SPORT_ID` | Active scope value rows | Scope types and data types |
| GLOBAL-DISCOVERY-011 | PROPERTY_USAGE_BY_OWNER | `METADATA.sql` | `SPORT_ID` | Known sport hierarchy and participant owner paths | Properties |
| GLOBAL-DISCOVERY-012 | OBJECT_RELATION_USAGE | `METADATA.sql` | `SPORT_ID` | Known hierarchy owner paths | Generic relations and disciplines |
| GLOBAL-DISCOVERY-013 | OBJECT_DISCIPLINE_USAGE | `METADATA.sql` | `SPORT_ID` | Known hierarchy/statistic owner paths | Generic relations and disciplines |
| GLOBAL-DISCOVERY-014 | TOURNAMENT_STAGE_REFERENCE_STORAGE | `METADATA.sql` | `SPORT_ID` | Active stages | Tables and relations / Storage semantics |
| GLOBAL-DISCOVERY-015 | STATISTIC_TYPES_AND_OWNERS | `STATISTICS.sql` | `SPORT_ID` | Known owner paths 1,2,3,4,5,6,15 | Statistics |
| GLOBAL-DISCOVERY-016 | STATISTIC_PARTICIPANT_SHARD_USAGE | `STATISTICS.sql` | `SPORT_ID`, `STATISTIC_TYPE_ID`, `STATISTIC_OWNER_TYPE_ID`, `SHARD_ID` | Run 015 first; test one physical shard | Statistics |
| GLOBAL-DISCOVERY-017 | STATISTIC_DATA_AND_CONFIG_FIELDS | `STATISTICS.sql` | `SPORT_ID`, `STATISTIC_TYPE_ID`, `STATISTIC_OWNER_TYPE_ID`, `SHARD_ID` | Run 016 first and confirm shard | Statistics / Reference values |
| GLOBAL-DISCOVERY-018 | EVENT_ROUND_TYPE_USAGE_SUMMARY | `PATTERNS.sql` | `SPORT_ID` | Active events | Event and round representation |
| GLOBAL-DISCOVERY-019 | EVENT_ROUND_TYPE_USAGE_DETAIL | `PATTERNS.sql` | `SPORT_ID`, `ROUND_TYPE_ID` | Select ID from 018 | Event and round representation |
| GLOBAL-DISCOVERY-020 | EVENT_NAME_PATTERNS_SUMMARY | `PATTERNS.sql` | `SPORT_ID` | Active events | Event and round representation |
| GLOBAL-DISCOVERY-021 | EVENT_NAME_PATTERNS_DETAIL | `PATTERNS.sql` | `SPORT_ID`, `NAME_PATTERN` | Select pattern from 020 | Event and round representation |
| GLOBAL-DISCOVERY-022 | TOURNAMENT_STAGE_NAME_PATTERNS_SUMMARY | `PATTERNS.sql` | `SPORT_ID` | Active stages | Event and round representation |
| GLOBAL-DISCOVERY-023 | TOURNAMENT_STAGE_NAME_PATTERNS_DETAIL | `PATTERNS.sql` | `SPORT_ID`, `NAME_PATTERN` | Select pattern from 022 | Event and round representation |
| GLOBAL-DISCOVERY-024 | STATISTIC_NAME_PATTERNS_SUMMARY | `PATTERNS.sql` | `SPORT_ID`, `STATISTIC_TYPE_ID`, `STATISTIC_OWNER_TYPE_ID` | Run 015 first | Statistics |
| GLOBAL-DISCOVERY-025 | STATISTIC_NAME_PATTERNS_DETAIL | `PATTERNS.sql` | `SPORT_ID`, `STATISTIC_TYPE_ID`, `STATISTIC_OWNER_TYPE_ID`, `NAME_PATTERN` | Select pattern from 024 | Statistics |
| GLOBAL-DISCOVERY-026 | EVENT_RESULTS_VALUE_PATTERNS_SUMMARY | `PATTERNS.sql` | `SPORT_ID` | Active result rows | Event result types |
| GLOBAL-DISCOVERY-027 | EVENT_RESULTS_VALUE_PATTERNS_DETAIL | `PATTERNS.sql` | `SPORT_ID`, `RESULT_TYPE_ID` | Select type from 026 | Event result types |
| GLOBAL-DISCOVERY-028 | STATISTIC_DATA_VALUE_PATTERNS_SUMMARY | `PATTERNS.sql` | `SPORT_ID`, `STATISTIC_TYPE_ID`, `STATISTIC_OWNER_TYPE_ID`, `SHARD_ID` | Run 015–017 first | Statistics |
| GLOBAL-DISCOVERY-029 | STATISTIC_DATA_VALUE_PATTERNS_DETAIL | `PATTERNS.sql` | `SPORT_ID`, `STATISTIC_TYPE_ID`, `STATISTIC_OWNER_TYPE_ID`, `SHARD_ID`, `STATISTIC_DATA_TYPE_ID` | Select type from 028 | Statistics |

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

## BMX migration mapping

The former `BMX-DQ-023` through `BMX-DQ-028` PATTERN_CATALOG identities were retired and
removed from the PowerBI registry; their CheckIDs were reclaimed by renumbering the
remaining rows. Their reusable purposes are represented by `GLOBAL-DISCOVERY-018`
through `GLOBAL-DISCOVERY-029`.

## Manual registry-rule additions

Registry-policy changes are inserted immediately before the marker below.

<!-- MANUAL PASTE ZONE: GLOBAL QUERY RULES — insert approved additions immediately before this marker; do not move or delete it. -->
