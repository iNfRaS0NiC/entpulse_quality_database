# GLOBAL DQ Template Registry

## Purpose

A GLOBAL DQ template is one approved data-quality check whose logic holds for every
applicable sport, stored once and executed for a selected sport by substituting its
declared parameters. It carries the full `POWERBI.md` contract — identity header,
findings-plus-coverage, audited-object granularity, commented scope filter — and differs
from a sport check only in that its sport-specific values are parameters instead of
literals.

This exists because the alternative does not scale. A hand-copied sport file is ~60 lines
per check; at 110 sports one logic fix would have to be applied 110 times, with nothing
detecting the copies that drifted. A template is fixed once and every sport that
instantiates it follows.

`GLOBAL_QUERIES/` answers *what is stored*. `GLOBAL_DQ/` asserts *what is wrong*. The
boundary between discovery and DQ is unchanged and owned by `POWERBI.md`.

## What is still not automatic

A template is not permission to check a sport. The authorization gate in `POWERBI.md`
applies unchanged: DQ work starts only after the user names a sport and a category, and a
check is instantiated for that sport only after the user approves it.

What changes is what approval produces. Instead of a new ~60-line statement, it produces:

1. one row in `POWERBI_REGISTRY.md` whose `Family` column names the template;
2. the parameter values for that sport in `SPORTS/params.json`, if not already recorded.

No per-sport copy of the SQL is created. A check that genuinely cannot be expressed
through declared parameters stays sport-authored, with `Family` = `—` and its statement in
`POWERBI_QUERIES/<SportSlug>.sql`.

## Parameter contract

Mandatory parameters use the same uppercase double-brace tokens as `GLOBAL_QUERIES/`, and
`WORKFLOW.md` owns the general rule. Two kinds occur:

| Kind | Substitution | Example |
|---|---|---|
| Scalar | A numeric or quoted value in a comparison | `{{SPORT_ID}}`, `{{STATISTIC_TYPE_ID}}` |
| Physical name fragment | Text inside a table or column name | `statistic_participants{{SHARD_ID}}` |
| List | A quoted, comma-separated list inside `IN (...)` | `{{EVENT_PARTICIPANT_TYPE_LIST}}` |

A list parameter's value already contains its quotes: `'athlete'` or `'athlete', 'team'`.
It is a SQL fragment, so it is only ever filled from `SPORTS/params.json`, never from
user-supplied text.

| Parameter | Meaning |
|---|---|
| `{{SPORT_ID}}` | Confirmed numeric `sport.id` |
| `{{EVENT_PARTICIPANT_TYPE_LIST}}` | Participant types the sport uses in `event_participants` |
| `{{REGISTRY_PARTICIPANT_TYPE_LIST}}` | Participant types present in the sport's `object_participants` registry |
| `{{STATISTIC_TYPE_ID}}` | Confirmed `statistic.statistic_typeFK` |
| `{{SHARD_ID}}` | Confirmed physical statistic participant/data shard number |
| `{{DATA_RANK_TYPE_ID}}` | `statistic_data_type.id` of the Rank data field for that statistic type |
| `{{CONFIG_START_DATE_TYPE_ID}}` | `statistic_data_type.id` of the Start date config field |
| `{{CONFIG_END_DATE_TYPE_ID}}` | `statistic_data_type.id` of the End date config field |

Every value is a confirmed structural fact recorded in the sport's file before it reaches
`SPORTS/params.json`. A parameter that is not yet confirmed for a sport means the template
cannot be instantiated for it yet — not that a plausible value may be guessed.

## Sport parameter file

`SPORTS/params.json` maps a sport slug to its confirmed values:

```json
{
  "BMX": {
    "SPORT_ID": 58,
    "EVENT_PARTICIPANT_TYPE_LIST": "'athlete'",
    "REGISTRY_PARTICIPANT_TYPE_LIST": "'athlete', 'team'",
    "STATISTIC_TYPE_ID": 11,
    "SHARD_ID": 11
  }
}
```

`TOOLS/Run-Query.ps1 -Sport <name>` reads it before querying the database, so a recorded
value is preferred over a discovered one: the file holds evidence, discovery holds a
heuristic. An explicit `-SportId` or `-Params` still overrides both.

The file is data, not documentation. The narrative evidence for each value stays in
`SPORTS/<SportSlug>.md`; `TOOLS/Test-Package.ps1` checks that the two agree on `SPORT_ID`.

## Registry

The `Description` column mirrors each statement's `-- What it does:` comment.

| CheckID | Name | File | Description | Mandatory parameters | Applicability/prerequisite | Category |
|---|---|---|---|---|---|---|
| GLOBAL-DQ-001 | TEMPLATE_NO_TOURNAMENTS_OR_STAGES | `HIERARCHY.sql` | Finds active tournament templates, excluding IOC-purpose templates, with zero active tournaments, or with tournaments but zero active tournament stages across all of them, together with a coverage count of all eligible templates. | `SPORT_ID` | Any sport with active templates | NO_RELATED_RECORDS |
| GLOBAL-DQ-002 | TOURNAMENT_STAGE_MISSING_AGE_CLASS | `HIERARCHY.sql` | Finds active tournament stages without an active tournament_age_class relation via object_relation, together with a coverage count of all eligible stages. | `SPORT_ID` | Sport whose stages are expected to carry an age class (`object_relation 4 -> 151`) | MISSING_VALUES |
| GLOBAL-DQ-003 | TOURNAMENT_STAGE_NO_EVENTS | `HIERARCHY.sql` | Finds active tournament stages with zero active events, together with a coverage count of all eligible stages. | `SPORT_ID` | Any sport with active stages | NO_RELATED_RECORDS |
| GLOBAL-DQ-004 | TOURNAMENT_STAGE_DATE_RANGE_MISMATCH | `HIERARCHY.sql` | Finds active tournament stages whose start or end date does not match the earliest and latest active event start date within the stage, together with a coverage count of all eligible stages with at least one event. | `SPORT_ID` | Sport whose stage date range is expected to bound its events | DATE_RANGE_MISMATCH |
| GLOBAL-DQ-005 | TOURNAMENT_STAGE_MISSING_START_OR_END_DATE | `HIERARCHY.sql` | Finds active tournament stages with a NULL start date or end date, together with a coverage count of all eligible stages. | `SPORT_ID` | Any sport with active stages | MISSING_VALUES |
| GLOBAL-DQ-006 | EVENT_MISSING_ROUND_TYPE | `HIERARCHY.sql` | Finds active events with a NULL round_typeFK or a round_typeFK not matching any round_type row, with template, tournament and stage name context, together with a coverage count of all eligible events. | `SPORT_ID` | Sport confirmed to use `event.round_typeFK` | MISSING_VALUES |
| GLOBAL-DQ-007 | PARTICIPANT_MISSING_DATE_OF_BIRTH | `PARTICIPANTS.sql` | Finds active participants of the selected types that take part in at least one active event of the sport but have no active, non-empty date_of_birth property value, with their participation count and the count of participations carrying at least one active result, together with a coverage count of all eligible participants. | `SPORT_ID`, `EVENT_PARTICIPANT_TYPE_LIST` | Sport whose participants are expected to carry a `date_of_birth` property | MISSING_VALUES |
| GLOBAL-DQ-008 | PARTICIPANT_MISSING_PROFILE_FIELDS | `PARTICIPANTS.sql` | Finds active participants of the selected types that take part in at least one active event of the sport and are missing name, country, first_name and/or last_name, together with a coverage count of all eligible participants. | `SPORT_ID`, `EVENT_PARTICIPANT_TYPE_LIST` | Sport confirmed to store split first/last name via `language` types 7 and 8 | MISSING_VALUES |
| GLOBAL-DQ-009 | PARTICIPANT_NO_EVENT_PARTICIPATION | `PARTICIPANTS.sql` | Finds active participants of the selected types linked through active sport-registry rows but having zero active event_participants rows within the sport, together with a coverage count of the same registered population. | `SPORT_ID`, `REGISTRY_PARTICIPANT_TYPE_LIST` | Sport with an active `object_participants` registry (`object='sport'`) | NO_RELATED_RECORDS |
| GLOBAL-DQ-010 | COMP.RANK_NO_PARTICIPANTS | `STATISTICS.sql` | Finds active tournament-owned statistics of the selected statistic type with zero active participant rows in the confirmed physical shard, with template and tournament name context, together with a coverage count of all eligible statistics. | `SPORT_ID`, `STATISTIC_TYPE_ID`, `SHARD_ID` | Tournament-owned statistics only (`statistic.object_typeFK=3`); shard confirmed per `DB-SEM-006` | NO_RELATED_RECORDS |
| GLOBAL-DQ-011 | COMP.RANK_SETTINGS_MISSING_START_OR_END_DATE | `STATISTICS.sql` | Finds active tournament-owned statistics of the selected statistic type with a missing or empty Start date or End date config value, with template and tournament name context, together with a coverage count of all eligible statistics. | `SPORT_ID`, `STATISTIC_TYPE_ID`, `CONFIG_START_DATE_TYPE_ID`, `CONFIG_END_DATE_TYPE_ID` | Tournament-owned statistics only; both config field IDs confirmed for the statistic type | MISSING_VALUES |
| GLOBAL-DQ-012 | COMP.RANK_RESULTS_RANK_INVALID_OR_MISSING | `STATISTICS.sql` | Finds active tournament-owned statistics of the selected statistic type holding at least one participant whose Rank data value is missing, empty, non-numeric or not a positive integer, with template and tournament name context and the count of affected participant rows, together with a coverage count of all eligible statistics. | `SPORT_ID`, `STATISTIC_TYPE_ID`, `SHARD_ID`, `DATA_RANK_TYPE_ID` | Tournament-owned statistics only; sport confirmed to store a positive-integer Rank data field | WRONG_RESULTS |

<!-- MANUAL PASTE ZONE: GLOBAL DQ REGISTRY — insert approved additions immediately before this marker; do not move or delete it. -->

## Qualification rule

A check qualifies as a GLOBAL DQ template only when:

- its relation path is supported by `DATABASE.md`;
- the violation it asserts is wrong in every applicable sport, not only in the sport it was
  first written for;
- every sport-varying input is a declared parameter;
- it contains no hard-coded sport ID or sport name;
- its applicability prerequisite is stated, so a sport where the condition is legitimately
  absent is excluded rather than reported as violating;
- one CheckID identifies exactly one executable statement.

The last point matters most in practice. "Every stage has an age class" is true for some
sports and meaningless for others; such a check is global only because the prerequisite
column says where it applies.

## Promoting a sport check to a template

Only after explicit user approval:

1. prove the violation condition is not sport-specific;
2. replace every sport literal with a declared parameter;
3. state the applicability prerequisite;
4. assign the next unused `GLOBAL-DQ-NNN`;
5. insert the statement in its domain file by CheckID order;
6. insert the registry row immediately before the marker above;
7. set the originating sport's registry `Family` to the new template ID;
8. run `TOOLS/Test-Package.ps1`.

A sport check keeps its own CheckID after promotion. `Family` records that the two are the
same logical check; the sport CheckID is never renumbered or reused.

## Manual registry-rule additions

Registry-policy changes are inserted immediately before the marker below.

<!-- MANUAL PASTE ZONE: GLOBAL DQ RULES — insert approved additions immediately before this marker; do not move or delete it. -->
