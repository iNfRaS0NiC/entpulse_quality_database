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

**Ask whether this opening includes the Comp.Rank layer, and wait for the answer.** Since
2026-08-26 the standing default is **without it**: the layer is paused for a month or two while
event results are corrected, because Comp.Rank is generated from those results and reading it
now would document a layer that is about to be rebuilt. Paused, not cancelled — the sport comes
back to it, which is why the omission is `Not checked` and never `Not applicable`.

The answer decides which catalogue stage 1 runs, which decisions stage 2b puts to the user, and
what stage 3 writes. Never infer it from the sport, from what the data turns out to hold, or
from what an earlier sport did.

## Stage 1 - run the catalogue

Which set runs depends on the answer taken above.

**Without the Comp.Rank layer — the default.** Twenty-three statements: the whole
non-statistics catalogue, summaries and their drill-downs together.

```powershell
$NoCompRank = @(1..14) + @(18..23) + @(26, 27, 32) | ForEach-Object { 'GLOBAL-DISCOVERY-{0:D3}' -f $_ }
.\TOOLS\Run-Query.ps1 $NoCompRank -Sport "<Exact Sport Name>" -MaxChecks 8 -Format xlsx
```

The four detail statements — `019 EVENT_ROUND_TYPE_USAGE_DETAIL`,
`021 EVENT_NAME_PATTERNS_DETAIL`, `023 TOURNAMENT_STAGE_NAME_PATTERNS_DETAIL` and
`027 EVENT_RESULTS_VALUE_PATTERNS_DETAIL` — belong in the list even though they cannot run
without a value, because `-Chain` is what fills them and it can only fill what was selected.
Leaving them out was the mistake found while opening Track Cycling on 2026-08-26: the batch
looked complete, reported nothing as skipped, and had silently run no detail at all.

Ten statements stay unrun, and each is named here because a bare number decides nothing:
`015 STATISTIC_TYPES_AND_OWNERS`, `016 STATISTIC_PARTICIPANT_SHARD_USAGE`,
`017 STATISTIC_DATA_AND_CONFIG_FIELDS`, `024 STATISTIC_NAME_PATTERNS_SUMMARY`,
`025 STATISTIC_NAME_PATTERNS_DETAIL`, `028 STATISTIC_DATA_VALUE_PATTERNS_SUMMARY`,
`029 STATISTIC_DATA_VALUE_PATTERNS_DETAIL`, `030 STATISTIC_DATA_TYPE_CATALOG`,
`031 STATISTIC_DATA_TYPE_DECLARED_VS_USED`, and `033 PARTICIPANT_DUPLICATE_CANDIDATES_BY_NAME`.
The last one carries no statistic name but counts an athlete's history through a statistic
shard, so on a sport whose ranking is not generated yet it reports every athlete as having
none.

**With the Comp.Rank layer.** Only on the user's explicit answer:

```powershell
.\TOOLS\Run-Query.ps1 GLOBAL-DISCOVERY-* -Sport "<Exact Sport Name>" -MaxChecks 8 -Format xlsx
```

Either way, start capped. Read what the first batch cost before letting the rest go:
`WORKFLOW.md`'s cost rule is not weakened by running many statements at once, and a large sport
can time out check by check.

Then run the remainder with the same selection, and let it carry the drill-downs with it —
`$NoCompRank` or `GLOBAL-DISCOVERY-*`, whichever stage 1 used:

```powershell
.\TOOLS\Run-Query.ps1 $NoCompRank -Sport "<Exact Sport Name>" -Chain -Format xlsx
```

`-Chain` fills each drill-down from the summary the statement itself names as its source and
runs it once per value that summary ranks first. It replaces the hand-run follow-ups stage 2
used to be, not the reading of them. Drop it, or lower `-ChainTop`, on a sport whose first
batch was slow. Five statements in the list take a value from an earlier summary —
`019`, `021`, `023`, `026` and `027` — so the capped first batch reports them as skipped for
want of it. That is correct and not a failure; `-Chain` is where they run.

`-ChainTop` is 3 by default, which is a sample and says so. Raise it when the user wants a
whole inventory covered rather than its busiest values: `026 EVENT_RESULTS_VALUE_PATTERNS_SUMMARY`
pursues one result type per run, so a sport with eight of them needs `-ChainTop 8` before the
result is coverage rather than the three most populated fields.

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

The run writes them down for you: a `Decisions` tab straight after Overview and a
`_decisions.json` beside the workbook, each row carrying what the run chose, why, and the real
alternatives. Read that list first — it is the agenda for this stage, and it exists so the gate
does not depend on anybody noticing a grey console line.

Then put them to the user **one at a time, each with its actual alternatives** — the ones in the
file, not invented. Do not proceed on silence, and do not fold two decisions into one question.
Check each item's premise before asking: a decision whose answer is already visible in a summary
the run completed is not open, and saying so is better than manufacturing a question.

The recurring ones, and where the alternatives come from:

| Decision | Alternatives to offer |
|---|---|
| Which statistic type and owner level the sport is documented on — **only in a with-Comp.Rank opening**; in the default one `015 STATISTIC_TYPES_AND_OWNERS` was never run, so there is nothing to decide and manufacturing the question is worse than saying so | every row `GLOBAL-DISCOVERY-015` returned; the runner takes the busiest and prints the rest as "other pairs not used" |
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

In a without-Comp.Rank opening, the statistics areas of the sport file stay `Not checked`, and
the file says in its own words that the omission was deliberate and on what date. No
`STATISTIC_TYPE_ID`, `STATISTIC_OWNER_TYPE_ID`, `SHARD_ID` or `statistic_data*` parameter is
written into `SPORTS/params.json`: an unread layer has no confirmed values, and a parameter
recorded there is read by every later run as evidence somebody checked it.

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

- open a sport without having asked whether the Comp.Rank layer is in or out, or answer that
  question for the user from the sport, the data or an earlier opening;
- run a statistics discovery statement, instantiate a `COMP.RANK_*` DQ template, or write a
  statistic parameter into `SPORTS/params.json`, in a without-Comp.Rank opening;
- record the unread statistics areas as `Not applicable` or `Not used` — the structure exists
  and is merely unread, and the pause is expected to lift;
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
