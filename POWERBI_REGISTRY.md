# PowerBI DQ Registry

## Purpose

This file is the compact source of truth for assigned PowerBI DQ CheckIDs, their
classification, approval status and SQL location.

Full SQL never belongs here. It is stored in one sport-scoped file under
`POWERBI_QUERIES/`.

## Registry rules

- Keep exactly one row per assigned CheckID.
- Sort rows by Sport and then by CheckID.
- DQ numbering starts at `DQ-001` independently for each sport.
- Assign an ID only after the user approves the concrete check.
- Deprecated rows must be removed and the remaining rows renumbered so CheckIDs stay
  contiguous with no gaps.
- Use `Approved` for an active approved query.
- `Category` identifies the DQ problem family.
- `Object` identifies the canonical object or logical storage layer checked.
- `Name` must match the `-- Name - ...` line in the SQL exactly.
- An `Approved` row's `Query file` must point to the one per-sport SQL file containing
  the full active query.
- Insert new approved rows immediately before the exact registry marker. Never place a
  row after, move or delete the marker. Replace an existing CheckID row in place.

## Approved DQ checks

| CheckID | Sport | Category | Object | Name | Query file | Status |
|---|---|---|---|---|---|---|
| BMX-DQ-001 | BMX | MISSING_VALUES | PARTICIPANT | PARTICIPANT_MISSING_DATE_OF_BIRTH | `POWERBI_QUERIES/BMX.sql` | Approved |
| BMX-DQ-002 | BMX | MISSING_VALUES | PARTICIPANT | PARTICIPANT_MISSING_PROFILE_FIELDS | `POWERBI_QUERIES/BMX.sql` | Approved |
| BMX-DQ-003 | BMX | MISSING_VALUES | PARTICIPANT | PARTICIPANT_NO_EVENT_PARTICIPATION | `POWERBI_QUERIES/BMX.sql` | Approved |
| BMX-DQ-004 | BMX | MISSING_VALUES | TOURNAMENT_STAGE | TOURNAMENT_STAGE_MISSING_AGE_CLASS | `POWERBI_QUERIES/BMX.sql` | Approved |
| BMX-DQ-005 | BMX | MISSING_VALUES | TOURNAMENT_STAGE | TOURNAMENT_STAGE_NO_EVENTS | `POWERBI_QUERIES/BMX.sql` | Approved |
| BMX-DQ-006 | BMX | MISSING_VALUES | TOURNAMENT_STAGE | TOURNAMENT_STAGE_DATE_RANGE_MISMATCH | `POWERBI_QUERIES/BMX.sql` | Approved |
| BMX-DQ-007 | BMX | MISSING_VALUES | TOURNAMENT_STAGE | TOURNAMENT_STAGE_MISSING_START_OR_END_DATE | `POWERBI_QUERIES/BMX.sql` | Approved |
| BMX-DQ-008 | BMX | MISSING_VALUES | TEMPLATE | TEMPLATE_MISSING_SET_SUBSET_GENDER_NAME | `POWERBI_QUERIES/BMX.sql` | Approved |
| BMX-DQ-009 | BMX | MISSING_VALUES | TOURNAMENT_STAGE | TOURNAMENT_STAGE_MISSING_CORE_FIELDS | `POWERBI_QUERIES/BMX.sql` | Approved |
| BMX-DQ-010 | BMX | MISSING_VALUES | EVENT | EVENT_SETTINGS_MISSING_DISCIPLINE | `POWERBI_QUERIES/BMX.sql` | Approved |
| BMX-DQ-011 | BMX | MISSING_VALUES | EVENT | EVENT_MISSING_ROUND_TYPE | `POWERBI_QUERIES/BMX.sql` | Approved |
| BMX-DQ-012 | BMX | MISSING_VALUES | EVENT | EVENT_SETTINGS_MISSING_GENDER | `POWERBI_QUERIES/BMX.sql` | Approved |
| BMX-DQ-013 | BMX | MISSING_VALUES | TEMPLATE | TEMPLATE_NO_TOURNAMENTS_OR_STAGES | `POWERBI_QUERIES/BMX.sql` | Approved |
| BMX-DQ-014 | BMX | WRONG_RESULTS | EVENT_RESULTS | EVENT_RESULTS_MISSING_FOR_FINISHED | `POWERBI_QUERIES/BMX.sql` | Approved |
| BMX-DQ-015 | BMX | WRONG_RESULTS | EVENT_RESULTS | EVENT_RESULTS_UNEXPECTED_FOR_NOT_STARTED | `POWERBI_QUERIES/BMX.sql` | Approved |
| BMX-DQ-016 | BMX | MISSING_VALUES | COMP.RANK | COMP.RANK_SETTINGS_MISSING_AGE_CLASS | `POWERBI_QUERIES/BMX.sql` | Approved |
| BMX-DQ-017 | BMX | MISSING_VALUES | COMP.RANK | COMP.RANK_NO_PARTICIPANTS | `POWERBI_QUERIES/BMX.sql` | Approved |
| BMX-DQ-018 | BMX | MISSING_VALUES | COMP.RANK | COMP.RANK_SETTINGS_DATE_RANGE_MISMATCH_STAGE | `POWERBI_QUERIES/BMX.sql` | Approved |
| BMX-DQ-019 | BMX | MISSING_VALUES | COMP.RANK | COMP.RANK_SETTINGS_DATE_RANGE_MISMATCH_EVENTS | `POWERBI_QUERIES/BMX.sql` | Approved |
| BMX-DQ-020 | BMX | MISSING_VALUES | COMP.RANK | COMP.RANK_SETTINGS_MISSING_START_OR_END_DATE | `POWERBI_QUERIES/BMX.sql` | Approved |
| BMX-DQ-021 | BMX | MISSING_VALUES | COMP.RANK | COMP.RANK_SETTINGS_MISSING_CORE_FIELDS | `POWERBI_QUERIES/BMX.sql` | Approved |
| BMX-DQ-022 | BMX | MISSING_VALUES | COMP.RANK | COMP.RANK_SETTINGS_MISSING_DISCIPLINE | `POWERBI_QUERIES/BMX.sql` | Approved |
| BMX-DQ-023 | BMX | WRONG_GENDER | TOURNAMENT_STAGE | TEMPLATE_STAGE_GENDER_MISMATCH | `POWERBI_QUERIES/BMX.sql` | Approved |
| BMX-DQ-024 | BMX | WRONG_GENDER | EVENT | EVENT_PARTICIPANTS_GENDER_MISMATCH | `POWERBI_QUERIES/BMX.sql` | Approved |
| BMX-DQ-025 | BMX | WRONG_GENDER | COMP.RANK | COMP.RANK_RESULTS_GENDER_MISMATCH | `POWERBI_QUERIES/BMX.sql` | Approved |
| BMX-DQ-026 | BMX | WRONG_RESULTS | EVENT_RESULTS | EVENT_RESULTS_MISSING_MEDAL_FOR_FINAL | `POWERBI_QUERIES/BMX.sql` | Approved |
| BMX-DQ-027 | BMX | MISSING_VALUES | COMP.RANK | COMP.RANK_SETTINGS_MISSING_MEDAL | `POWERBI_QUERIES/BMX.sql` | Approved |
| BMX-DQ-028 | BMX | MISSING_VALUES | EVENT | EVENT_SETTINGS_MISSING_MEDAL_RELATED_FOR_FINAL | `POWERBI_QUERIES/BMX.sql` | Approved |
| BMX-DQ-029 | BMX | WRONG_RESULTS | EVENT_RESULTS | EVENT_RESULTS_UNEXPECTED_MEDAL_FOR_NON_FINAL | `POWERBI_QUERIES/BMX.sql` | Approved |
<!-- MANUAL PASTE ZONE: POWERBI DQ REGISTRY — insert approved additions immediately before this marker; do not move or delete it. -->
