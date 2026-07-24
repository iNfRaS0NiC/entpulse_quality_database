# Project 2.0 Validation Report

Validation date: **2026-07-24**

## Result

**PASS — ready for controlled migration and bot smoke testing.**

Project 1.x remains unchanged and is the rollback package.

## Package checks

| Check | Result |
|---|---:|
| Expected Project 2.0 files present | PASS |
| UTF-8 text, Unix line endings and final newline | PASS |
| Trailing whitespace | 0 findings |
| Duplicate active SQL CheckIDs | 0 |
| GLOBAL registry versus executable SQL | PASS |
| PowerBI registry versus active BMX SQL | PASS |
| Deprecated BMX DQ SQL still executable | 0 |
| Required manual-paste markers | PASS |
| Required Project 2.0 routing references | PASS |

## SQL checks

| Metric | Result |
|---|---:|
| SQL files parsed | 7 |
| SQL statements parsed | 54 |
| MySQL parser failures | 0 |
| UNION column-count mismatches | 0 |
| GLOBAL discovery statements | 29 |
| Active BMX DQ statements | 25 |
| Reserved deprecated BMX DQ IDs | 6 |

All GLOBAL statements use `{{SPORT_ID}}`; none contains a hard-coded BMX sport ID.
Parameter-dependent GLOBAL statements declare their additional placeholders in
`GLOBAL_QUERIES/README.md`.

Every active BMX DQ statement remains represented by one `Approved` registry row and
contains an `eligible_count` coverage output. `BMX-DQ-023` through `BMX-DQ-028` remain
reserved as `Deprecated` and have no active executable statement.

## Important boundary

This report proves package consistency and static MySQL syntax parsing. It does not
prove live database permissions, runtime cost or result semantics because the
queries were not executed against the production database.

Before final cutover, follow the activation tests in `PROJECT_2.0_MIGRATION.md` and
run a small approved database smoke-test sample.

