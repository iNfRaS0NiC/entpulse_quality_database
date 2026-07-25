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
| Active BMX DQ statements | 29 |

All GLOBAL statements use `{{SPORT_ID}}`; none contains a hard-coded BMX sport ID.
Parameter-dependent GLOBAL statements declare their additional placeholders in
`GLOBAL_QUERIES/README.md`.

Every active BMX DQ statement remains represented by one `Approved` registry row and
contains an `eligible_count` coverage output. The former `BMX-DQ-023` through
`BMX-DQ-028` PATTERN_CATALOG rows were removed and the CheckIDs after them renumbered
to close the gap.

## Important boundary

This report proves package consistency and static MySQL syntax parsing. It does not
prove live database permissions, runtime cost or result semantics because the
queries were not executed against the production database.

Before final cutover, follow the activation tests in `PROJECT_2.0_MIGRATION.md` and
run a small approved database smoke-test sample.

## Pending re-validation (changes after 2026-07-24)

The PASS result and metrics above are a static snapshot as of the validation date. The
changes below were made afterwards and have **not** been re-checked by the parser and
package-check tooling, so the metrics no longer match the current files. Re-run the static
validation (SQL parse, UNION column-count, registry-versus-SQL, manual-paste markers) and
refresh the metrics before cutover:

- BMX DQ checks added: `BMX-DQ-034` through `BMX-DQ-038` (Comp.Rank result checks), each
  with a matching `Approved` row in `POWERBI_REGISTRY.md`. The active BMX registry now runs
  `BMX-DQ-001` through `BMX-DQ-038`.
- IOC-purpose templates are now excluded in both the findings and coverage branches of the
  existing Comp.Rank checks `BMX-DQ-016` through `BMX-DQ-022` and `BMX-DQ-027`.
- New `Statistics (Comp.Rank) query rules` added to `POWERBI.md` and `AI_INSTRUCTIONS.md`.
- New VSCode direct-editing exception added to `AI_INSTRUCTIONS.md` and referenced from
  `POWERBI.md`.
- `README.md` source-of-truth map corrected to reference `AI_INSTRUCTIONS.md` instead of the
  non-existent `BOT_INSTRUCTIONS_PROJECT_2.0.txt`.

