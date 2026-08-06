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

Ask for the exact database sport name if the user gave an informal one. `-Sport` accepts a
documented repository slug too, but a new sport has no mapping yet, so its exact `sport.name`
is required and a near miss still fails during live discovery. Resolve it now rather than
mid-batch.

## Stage 1 - run the catalogue

```powershell
.\TOOLS\Run-Query.ps1 GLOBAL-DISCOVERY-* -Sport "<Exact Sport Name>" -MaxChecks 8 -Format xlsx
```

Start capped. Read what the first batch cost before letting the rest go: `WORKFLOW.md`'s
cost rule is not weakened by running many statements at once, and a large sport can time out
check by check.

Then run the remainder, and let it carry the drill-downs with it:

```powershell
.\TOOLS\Run-Query.ps1 GLOBAL-DISCOVERY-* -Sport "<Exact Sport Name>" -Chain -Format xlsx
```

`-Chain` fills each drill-down from the summary the statement itself names as its source and
runs it once per value that summary ranks first. It replaces the hand-run follow-ups stage 2
used to be, not the reading of them. Drop it, or lower `-ChainTop`, on a sport whose first
batch was slow.

Report to the user: which checks returned rows, which returned nothing, which failed with
what message, and which were skipped. A failed check is `Not checked`, never `Not used`.

## Stage 2 - read the chain, and run what it left

A chained result is a sample of the busiest shapes, never coverage. The Overview says so in
its own rows: `SKIPPED: N further value(s) … not pursued`, and `SKIPPED` for any drill-down
the chain could not fill at all. Read those before anything else, because they are the
difference between "this sport uses these shapes" and "these are the shapes it uses most".

Where a value the chain skipped matters to a structural question, let the user pick it and
run that statement on its own:

```powershell
.\TOOLS\Run-Query.ps1 GLOBAL-DISCOVERY-019 -Sport "<Exact Sport Name>" -Params ROUND_TYPE_ID=5
```

`GLOBAL_QUERIES/README.md` records which summary each detail statement depends on. Stop when
the structural question is answered; a full catalogue sweep is not the goal.

Classify every result with the `WORKFLOW.md` evidence vocabulary as you go. A result whose
row count equals the limit is truncated and supports only "these examples exist". A chained
one supports only "these examples exist among the values pursued".

## Stage 2b - settle every open decision before writing anything

A run decides some things by itself and defers others. Both are fine while they stay execution
output. Stage 3 is where they stop being that: a value written into `SPORTS/params.json` is read
by every later run as confirmed evidence, and a heuristic recorded there is indistinguishable
from a fact anybody checked.

So before the `PREPARE_DOC_UPDATE` command, list every open decision and put them to the user
**one at a time, each with its actual alternatives** — taken from the run's own output, not
invented. Do not proceed on silence, and do not fold two decisions into one question.

The recurring ones, and where the alternatives come from:

| Decision | Alternatives to offer |
|---|---|
| Which statistic type and owner level the sport is documented on | every row `GLOBAL-DISCOVERY-015` returned; the runner takes the busiest and prints the rest as "other pairs not used" |
| Values `-Chain` did not pursue | the count in each `SKIPPED: N further value(s) …` row: pursue more, or record the sample as a sample |
| A drill-down left `SKIPPED` with no source | run it by hand with a chosen value, or record the area as `Not checked` |
| A check whose `eligible_count` is 0 | a misdirected scope to correct, or a legitimately empty population to record as a sentinel — `POWERBI.md` owns the distinction and it is never a third thing |
| A check that failed | re-run it, or record the area as `Not checked` — never `Not used` |

A decision the user has not made stays out of `params.json`. Recording the area as `Not checked`
is always available and is the honest answer; guessing to fill a row is not.

## Stage 3 - record what was confirmed

Only after the user issues:

```text
PREPARE_DOC_UPDATE SPORT=<Sport>
```

Then, in this order:

1. add one row to `SPORTS.md` immediately before the `SPORT INDEX` marker, with the slug
   derived by the slug rule in that file and the exact database `sport.name` in the final
   `Database sport name` column;
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
- report a chained result as the sport's whole use of a shape: `-Chain` pursues the values a
  summary ranks first and says what it left, and that report is part of the finding;
- fill a `params.json` value the sport file does not document as confirmed;
- carry a value the runner chose for itself into `params.json` without the user having been
  offered the alternatives and having picked one - that is the step where a heuristic becomes
  evidence, and it is the one thing here that cannot be undone by reading the file later;
- report a narrowed or truncated result as complete sport coverage.
