---
name: new-sport
description: Open an undocumented sport in this repository - run the GLOBAL discovery catalogue for it, read the results, draft its sport file and parameter entry, and stop before DQ work. Use when the user names a sport that has no SPORTS/<Slug>.md yet, or says "open", "start" or "add" a sport.
---

# Opening a new sport

`WORKFLOW.md` "Starting a new sport" is the canonical sequence; this skill executes it in
order without skipping the gates that keep results from being mistaken for evidence.

The user drives. Do not run stage 3 or 4 without the explicit command each requires.

## Before starting

Confirm the sport is actually undocumented: check `SPORTS.md` for a row and
`SPORTS/` for a file. If either exists, this is an update to an existing sport, not an
opening — target the smallest relevant part of the existing file instead.

Ask for the exact database sport name if the user gave an informal one. `-Sport` matches
`sport.name` exactly and fails on a near miss, which is cheaper to resolve now than
mid-batch.

## Stage 1 - run the catalogue

```powershell
.\TOOLS\Run-Query.ps1 GLOBAL-DISCOVERY-* -Sport "<Exact Sport Name>" -MaxChecks 8 -Format xlsx
```

Start capped. Read what the first batch cost before letting the rest go: `WORKFLOW.md`'s
cost rule is not weakened by running many statements at once, and a large sport can time out
check by check.

Then run the remainder. Statements needing a value chosen from a summary result are listed
and skipped, and appear as `SKIPPED` in the workbook — a run is never full coverage.

Report to the user: which checks returned rows, which returned nothing, which failed with
what message, and which were skipped. A failed check is `Not checked`, never `Not used`.

## Stage 2 - run the drill-downs the findings justify

For each skipped statement worth pursuing, read its summary result, let the user pick the
value, then run the paired detail statement with it:

```powershell
.\TOOLS\Run-Query.ps1 GLOBAL-DISCOVERY-019 -Sport "<Exact Sport Name>" -Params ROUND_TYPE_ID=5
```

`GLOBAL_QUERIES/README.md` records which summary each detail statement depends on. Stop when
the structural question is answered; a full catalogue sweep is not the goal.

Classify every result with the `WORKFLOW.md` evidence vocabulary as you go. A result whose
row count equals the limit is truncated and supports only "these examples exist".

## Stage 3 - record what was confirmed

Only after the user issues:

```text
PREPARE_DOC_UPDATE SPORT=<Sport>
```

Then, in this order:

1. add one row to `SPORTS.md` immediately before the `SPORT INDEX` marker, with the slug
   derived by the slug rule in that file;
2. create `SPORTS/<SportSlug>.md` from `SPORTS/_TEMPLATE.md`, replacing every `<SPORT_ID>`
   placeholder with the confirmed numeric sport ID — including the ones inside the paste
   markers;
3. fill only confirmed areas; leave every other area `Not checked`;
4. add the sport's confirmed values to `SPORTS/params.json`, recording only what the sport
   file now documents as confirmed;
5. run `.\TOOLS\Test-Package.ps1` and report the result.

Do not carry transient counts, percentages, example row IDs or status distributions into the
sport file. `WORKFLOW.md` owns the eligibility gate.

## Stage 4 - open DQ work

Only after stage 3, and only for a category the user opens. `POWERBI.md` owns the gate.

For each candidate, check `GLOBAL_DQ/README.md` first. When a template's applicability
prerequisite matches the sport's confirmed structure, the approved check is a registry row
with `Family` set and `Query file` pointing at the template — not a new statement. Author a
sport statement only when the condition cannot be expressed through declared parameters.

A structural finding never becomes a DQ check automatically.

## What this skill must not do

- run stage 3 or 4 without its explicit command;
- treat execution output as evidence;
- guess a parameter the runner reported as skipped;
- fill a `params.json` value the sport file does not document as confirmed;
- report a narrowed or truncated result as complete sport coverage.
