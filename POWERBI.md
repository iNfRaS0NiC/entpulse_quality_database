# PowerBI Data Quality

## Purpose

This file defines the permanent policy for user-approved PowerBI data-quality checks.
It is not a registry and does not store full sport SQL.

The PowerBI layer is split into three responsibilities:

| Location | Responsibility |
|---|---|
| `POWERBI.md` | Stable policy, query contract and update workflow |
| `POWERBI_REGISTRY.md` | Compact source of truth for assigned CheckIDs, families, categories, objects, names, query paths and statuses |
| `GLOBAL_DQ/` | Reusable DQ check templates and their parameter contract |
| `POWERBI_QUERIES/<SportSlug>.sql` | Full approved SQL authored for one sport, ordered by CheckID |

Do not copy registry rows or full sport queries back into this file.

## Boundary with structural discovery

Inventories, usage summaries, name-pattern catalogs, value-shape catalogs and drill-down
queries are structural discovery, not DQ violations. Reusable versions belong under
`GLOBAL_QUERIES/` with `GLOBAL-DISCOVERY-NNN` identities.

A DQ check asserts one user-approved missing, wrong, duplicate, invalid or otherwise
actionable condition. Do not assign a DQ CheckID merely because a discovery query
returns counts or unusual values.

## Authorization gate

DQ work starts only after the user explicitly names:

1. the sport;
2. the requested categories or problem areas.

Examples such as `MISSING_VALUES`, `NO_RELATED_RECORDS`, `DATE_RANGE_MISMATCH`,
`WRONG_GENDER` and `WRONG_RESULTS` are category examples, not active requests. Do not propose, name, number or generate DQ checks outside the categories
opened by the user.

**Several categories may be open at once, and the candidates from all of them are brought
back together.** One at a time was never the rule and buys no protection: the gate is the
check, and it does not weaken because the candidate beside it belongs to a different column.
Working them singly costs a round trip per category and hides the overlaps — one measurement
usually decides a missing value and a wrong one at the same time, so splitting by category
means measuring twice and deciding the second half without the first in view. What stays one
at a time is the decision, never the batch it arrives in: each candidate is still named,
explained and approved separately, and an unapproved one is not written.

## Approval and identity workflow

1. The user chooses the sport and one or more DQ categories.
2. Use only confirmed structure for that sport.
3. If evidence is insufficient, return only the required structural SQL and wait for
   its result.
4. Propose candidates only inside the opened categories.
5. Wait for the user to select a concrete candidate.
6. Read `POWERBI_REGISTRY.md` and assign the next unused sport-scoped CheckID only
   after approval.
7. Generate the query under the SQL, coverage and scope contracts below.
8. Retain the approved check as a pending PowerBI update.
9. Do not generate PowerBI copy/paste blocks automatically.

CheckID format:

```text
<SportSlug>-DQ-NNN
```

Rules:

- numbering starts at `DQ-001` independently for each sport;
- the SportSlug uses the documented English sport name with spaces replaced by hyphens;
- assigned IDs are never renumbered, deleted or reused;
- an updated version of the same logical check keeps its CheckID;
- a materially different check receives a new ID after separate user approval.

### The 200-row gate

**A candidate returning more than 200 finding rows is examined before it is assigned a
CheckID, never after.** Run it, read what the rows actually say, and establish what share of
them is the sport behaving normally rather than a defect. A count alone settles nothing: a long
list of genuine defects is a good check, and a long list that turns out to be the sport's own
storage habit is a check that was wrong for this sport before it was ever numbered.

**Where the answer is not certain, the check is not written.** It goes back to the user as a
question. Uncertainty here is about the check and not about the data - "these rows may or may
not be defects" is ordinary review work and belongs on a board; "this rule may not hold for
this sport" is a reason to stop and ask.

The cost being avoided is asymmetric. An unwritten check costs a question. An assigned CheckID
is permanent: it cannot be renumbered, deleted or reused, so withdrawing one leaves a
`Deprecated` row in `POWERBI_REGISTRY.md` for the life of the package, and every reader after
that has to work out why. Writing a check and then withdrawing it is therefore not a neutral
correction, and a habit of it makes the registry harder to read than the database.

Measured on Golf, 2026-08-13, which is why the rule is written down:

| Check | Reported | Of which the sport behaving normally |
|---|---:|---:|
| `GLOBAL-DQ-076` | 16452 | 9347 correct scores the pattern could not read |
| `GLOBAL-DQ-118` | 6655 | 529 events on a round type that is filed correctly |
| `GLOBAL-DQ-107` | 16334 | all of them - deprecated |
| `GLOBAL-DQ-004` | 5089 | 4969 - held open rather than assigned |
| `GLOBAL-DQ-049` | 13430 | 13340 - held open rather than assigned |

The last two are the rule working. The first three are what it exists to prevent.

One more from 2026-08-14, and it is the clearest case the sport has produced:

| Check | Reported | Of which the sport behaving normally |
|---|---:|---:|
| `Golf-DQ-101` candidate | 9549 | 8424 - three formats the database cannot see |

The candidate flagged every competitor whose score against par did not follow from their own
rounds. Reading the rows found three formats rather than three defects: a tournament played on
more than one course, where each competitor's par is a sum the single stored `Par` cannot
express; Modified Stableford, played for points; and FedExCup Starting Strokes, where the field
begins at a staggered score. Each reaches its whole field - 155 of 156, 209 of 210, 25 of 30 in
six consecutive years - which is what tells a format from a mistake, since a wrong card reaches
one competitor. The check was written on that discriminator and reports 639. A further 486 cards
were left out as undecided rather than counted either way, which is recorded here so the gap is
visible rather than implied.

Two more from the same day, and the second is the rule catching a check that would have been
entirely wrong:

| Check | Reported | Of which the sport behaving normally |
|---|---:|---:|
| `Golf-DQ-103` | 284 | none - written and assigned |
| `Golf-DQ-107` candidate | 24 | all 24 - amateurs, and the check was rewritten |

`Golf-DQ-103` is what the gate looks like when the answer comes back clean. It reports 284 rows
over the threshold, of which 118 are cards commented `mdf` without the matching cut flag. Reading
them rather than counting them is what settled it: the sport writes `mdf` beside `made_cut = yes`
on 1429 cards and beside `no` on 118, and a twelve-to-one majority is a convention, so the
minority is a defect. Had the split been the other way the check would not have been written.

`Golf-DQ-107` never reached 200 and the gate's habit still saved it. The candidate reported 24
cards paid less than somebody who finished behind them, and every one of the 24 was paid zero
while placed high - amateurs, who cannot accept prize money. Twelve of the thirteen events were
2026 LPGA majors and one competitor was placed sixth in the US Women's Open beside a paid
seventh. Counting would have called that 24 defects; reading it called it Rule 3-2b of the Rules
of Amateur Status. The statement now compares only cards that were actually paid and returns
nothing, which is the correct answer to the question the rules ask.

This is the counterpart of `WORKFLOW.md`'s "Zero findings never retires a check": a small count
is no reason to withdraw a check, and a large one is no reason to trust it.

Ice Hockey opened its first two bands on 2026-08-14 by running all 66 candidates its recorded
parameters supported, and thirteen of them crossed the threshold. Three were assigned, ten were
not:

| Check | Reported | Of which the sport behaving normally |
|---|---:|---:|
| `GLOBAL-DQ-030` | 371 | none established - assigned |
| `GLOBAL-DQ-043` | 324 | none established - assigned |
| `GLOBAL-DQ-096` | 593 | none, but 592 are one renaming - assigned |
| `GLOBAL-DQ-009` | 15690 | the whole sport registry, which the client boundary cannot reach |
| `GLOBAL-DQ-107` | 8410 | the scope layer covers 12 per cent of the events |
| `GLOBAL-DQ-058` | 8192 | the lineup layer covers 16 per cent of the events |
| `GLOBAL-DQ-049` | 1767 | `Australia-Finland` is how the sport names every event |
| `GLOBAL-DQ-068` | 554 | 376 differ by one player, which is an ordinary roster |
| `GLOBAL-DQ-084` | 297 | 290 - the sport's format admits a draw, so the check is outside its own prerequisite |
| `GLOBAL-DQ-040` | 261 | 249 undeterminable - the Event id config is on 33 statistics |
| `GLOBAL-DQ-065` | 226 | squads of 24 to 27, which is an ordinary squad |
| `GLOBAL-DQ-090` | 219 | scheduled 2026 fixtures holding a zero running score |
| `GLOBAL-DQ-075` | 250 | all of them - the parameter was wrong, not the data |

`GLOBAL-DQ-084` is not a case of the gate finding a rule that fails, and it is recorded here so
that nobody reads it as one. **Whether a level score is a result or a defect is a per-sport
question and the template already says so**: its prerequisite admits only a head-to-head sport
whose format admits no draw, and instructs any sport that does admit one to record that instead
of instantiating it. Soccer did exactly that before ice hockey was opened, with the same reason
and its own narrower `Soccer-DQ-022` for knockout rounds; Curling instantiates it because extra
ends leave it nothing to draw. Ice hockey joins the first group, not a new one. The 297 rows were
never evidence against the template - they are what running a check outside its own prerequisite
returns, and reading them is how the prerequisite got applied.

**`Not applicable` is the beginning of the work, not the end of it.** Every one of the three cases
above ends in a written check rather than a gap: Soccer in `Soccer-DQ-022`, ice hockey in
`Ice-Hockey-DQ-058` over the rounds that must produce a winner, which reports the 7 events the
group rounds were hiding. The same happened to `GLOBAL-DQ-085`, which reads a period breakdown
stored as several fields under one scope type and cannot reach a sport that stores each period as
its own type: `Ice-Hockey-DQ-059` asks the same arithmetic of the result layer and reaches 8492
events instead of 898. A signal recorded without the variant beside it leaves the question the
template was asking unasked, which is the one outcome the template layer exists to prevent.

`GLOBAL-DQ-096` is a different shape again - 592 of its 593 rows are the single renaming of Czech
Republic to Czechia, so the count measures one correction rather than 593.

Seven more crossed the threshold on the same sport and were assigned anyway, by decision of
2026-08-14, which is the gate working in the other direction:

| Check | Reported | Of which the sport behaving normally |
|---|---:|---:|
| `GLOBAL-DQ-074` | 9571 | none - an event should name where it was played |
| `GLOBAL-DQ-094` | 737 | none - a medal round decides a medal, and the score already names it |
| `GLOBAL-DQ-033` | 746 | none - the phase should be written and is not, anywhere |
| `GLOBAL-DQ-093` | 463 | none - same as -094 |
| `GLOBAL-DQ-038` | 475 | none - same as -094 |
| `GLOBAL-DQ-026` | 309 | none - a ranking that awards a place awards a medal, group phase included |
| `GLOBAL-DQ-090` | 219 | none - a match nobody has played should hold no score |
| `GLOBAL-DQ-034` | 1348 | none - a stage should say where it was held; 995 lack only the city |
| `GLOBAL-DQ-035` | 560 | none - and 197 statistics are already clean, so the sport does fill these |

`GLOBAL-DQ-034` is the extreme form and was decided the same way on the same day: it reports
every stage in the sport, because no stage carries a city at all. A field unfilled everywhere is
one storage habit and not 1348 defects, which is exactly the reading the gate exists to surface -
and it was still assigned, because the count measures the size of the fill rather than the truth
of the rule. `GLOBAL-DQ-035` asks the same four fields of the Comp.Rank record and is the
counter-example that makes the point: 197 of its 757 are clean, so nothing there is a habit.

Every one of the nine reports a field the sport leaves empty across most or all of a layer, and
in each case the reading that would have kept it off the board - the layer is unused, so its
emptiness is a habit rather than a gap - was put to the user and refused. The medals are the
clearest: 463 of the 483 events in a medal round hold no `501 Medal` at all while the Comp.Rank
medal field holds 10395 values, and the answer was that a medal belongs on the event that
awarded it. `GLOBAL-DQ-033` is the strongest form of the same answer, since it reports 746 of
746 - every Comp.Rank in the sport, with no phase written anywhere - which `SPORTS/Golf.md` and
`SPORTS/Soccer.md` both classify as a structural absence for their own sports. **The same shape
can be a structural absence in one sport and an unfilled field in another, and only the person
who owns the data can say which.** That is the rule the gate protects: the count never decides
it, and neither does the precedent.

The counts are large because the gaps are. Where the template can name the correction rather
than only the absence it is worth more - `GLOBAL-DQ-094` says which medal each participation
should hold, because the score already says who won.

`GLOBAL-DQ-075` is the gate catching the reader instead of the data. `SPORTS/params.json`
recorded 11 of the sport's 26 confirmed round types, so the check reported the other 15 as
unexpected. Correcting the parameter to what `GLOBAL-DISCOVERY-018` had already measured returned
it to zero, which is what the check is for: it now reports a round type nobody has confirmed.

## SQL header and name contract

Every approved query begins with `SELECT` as its first word. `SELECT` is alone on the
first line. Exactly three contiguous description comments follow the first outer
`SELECT`, before `DISTINCT`, the first selected column or any other expression:

```sql
SELECT
    -- CheckID - Curling-DQ-002
    -- Name - EVENT_RESULTS_DUPLICATE_ROWS
    -- What it does: Finds active duplicate result rows for Curling events with the same event participant and result type.
    ...
```

Do not place comments before the first `SELECT`. Do not repeat the identity header under
nested `SELECT` statements or later `UNION` branches.

The Name starts with the canonical object, table or logical storage layer actually
checked. The suffix states the concrete purpose in uppercase words.

Preferred prefixes:

| Prefix | Checked layer |
|---|---|
| `EVENT_` | Event row or direct event-level references |
| `EVENT_RESULTS_` | Event-participant `result` rows and result types |
| `EVENT_SETTINGS_` | Event properties, settings or mapped configuration |
| `TOURNAMENT_` | Tournament or tournament-stage structure |
| `TEMPLATE_` | Tournament-template structure |
| `COMP.RANK_RESULTS_` | Competition-ranking result storage |
| `COMP.RANK_SETTINGS_` | Competition-ranking settings or metadata |
| `PARTICIPANT_` | Participant identity, type, relations or properties |

The prefix list is extensible when a new canonical object or storage layer is confirmed.
Do not start a Name with `DISCOVERY`, `MISSING`, `WRONG`, `INVALID`, the sport name,
the DQ category or the CheckID.

The SQL identity header contains only:

1. `CheckID`;
2. `Name`;
3. `What it does`.

Do not add decorative separator lines or extra identity comments such as `Sport`,
`Category`, `Stands on`, `Applies to`, `Positive control`, `Output`, `Coverage`,
`Notes`, `Assumptions` or `Follow-up`.

## Mandatory coverage contract

Every approved DQ query must self-validate its audited scope in the same SQL statement.
Use the established findings-plus-coverage pattern:

- finding rows use their concrete `check_type` and return `NULL AS eligible_count`;
- a `UNION ALL` branch returns one row with `check_type = 'COVERAGE'`;
- the coverage row returns `COUNT(DISTINCT <audited_object_id>) AS eligible_count`;
- the coverage branch uses the same sport scope, active-row conditions and every
  activated scope-limiting filter as the findings branch;
- the coverage branch counts eligible objects before the violation predicate is applied;
- every `UNION ALL` branch returns the same number of columns in the same order.

Interpretation:

| Result | Meaning |
|---|---|
| Finding rows + `eligible_count > 0` | The query reached its scope and found violations |
| No finding rows + `eligible_count > 0` | The scope was checked and no violations were found |
| `eligible_count = 0` | One of three different things; never clean data. Read the next paragraph before acting |
| Missing `COVERAGE` row or failed statement | The result is not validated |

A zero coverage count has three causes and the first two call for opposite responses:

| Cause | What it looks like | What to do |
|---|---|---|
| **Misdirected scope** | The statement anchors on the wrong type, shard, owner level or filter, so it audits objects the rule was never about | Correct the scope. The result proves nothing until you do |
| **Sentinel** | The scope is exactly right and the population it audits is legitimately empty today | Nothing. Zero is the check's correct answer for now, and the check exists to stop being silent when the population appears |
| **Not applicable** | The scope is exactly right and the population cannot arrive without the sport changing what it stores | Record the check as `Not applicable` in `SPORTS/params.json` with the evidence. The zero is still not clean data; the classification says which answer it is |

The third was added by decision of 2026-08-11, with `Modern-Pentathlon` `GLOBAL-DQ-028`. It
differs from a sentinel in what would have to happen for the population to appear. A sentinel
waits for rows that the sport already has the structure to write; this waits for the sport to
change how it scores, which is not a data correction and not something the check is watching
for. Modern pentathlon ranks on points and has never written a Time Difference row, so the
check audits a field that does not exist there.

It is deliberately narrow, because it is the reading `CLAUDE.md` warns against taking cheaply:
"no rows, so it does not apply here" retires a sentinel precisely when the row it waits for
arrives. What separates the two is evidence about the **structure**, gathered across every
layer rather than the one the check reads — the Modern Pentathlon case only settled after the
event-level result types were inventoried as well as the Comp.Rank ones, and it nearly settled
the wrong way because a neighbouring field existed under IOC templates, which every statistic
check excludes.

A check classified this way stops being raised as an open decision by the run. That is the
one thing the classification buys: the question has been answered in the sport file, and
re-asking it every week is the same defect as overwriting a comment somebody wrote.

The distinction is never readable from the number itself, so the sport file must say which
one applies and why, naming the check. Without that sentence a later reader has to re-derive
it, and the cheap conclusion — "no rows, so it does not apply here" — is the one `CLAUDE.md`
forbids: a sentinel retired on its own zero is silent precisely when the row it waits for
arrives. A sentinel is not a `_checkSignal` value. It is an ordinary `Actionable` check with
nothing to act on yet, and `TOOLS/README.md` owns why none of the three signals fits it.

Coverage values are operational evidence only. They are not structural findings and do
not belong in `DATABASE.md` or `SPORTS/<SportSlug>.md`.

### What the check should return next time

The table above reads one run. A re-run after the findings have been corrected asks a further
question the coverage row cannot answer on its own: was this check supposed to come back
empty? Most are, and some are not — a check whose findings are population-wide keeps its rows
however much is corrected, and one with an agreed remainder keeps exactly that many. Left
unwritten, the answer lives in whoever ran it last.

`SPORTS/params.json` records it per sport under `_expected`, in the same shape as
`_checkSignal` and with the same enforcement; `TOOLS/README.md` owns the vocabulary and the
default each signal implies. The rule that matters here is the one this file already applies
to applicability: **the expectation is read off the check's invariant, never off the last
run's count.** A check that returned nothing today is not thereby a `Zero` check, and
recording it as one is how a sentinel gets retired on its own zero.

## Audited-object granularity

Finding rows report the audited object, not raw child records.

- Return one finding row per distinct audited object; collapse join fan-out with
  `GROUP BY` on that object or `EXISTS` before listing or counting, so the same object
  never repeats across finding rows.
- Express counts as `COUNT(DISTINCT <object_id>)`. A raw violating-record count may appear
  only as an explicitly named secondary column such as `violating_record_count`, alongside
  the specific violation breakdown when useful.
- Order finding rows by the audited object ID or by a per-object aggregate such as
  `violating_record_count`; keep the `COVERAGE` row last.

## Statistics (Comp.Rank) query rules

These rules are mandatory for every DQ or discovery query whose audited object is a
`statistic`, `statistic_participants11` or `statistic_data11` row.

- Always project `template_name` (`tt.name`) — and, when a tournament is in scope,
  `tournament_name` (`t.name`) — as context columns, so every finding is traceable to its
  template without a second lookup.
- Always exclude IOC-purpose templates from both the findings and the coverage branch with
  `AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')`. IOC templates carry structurally
  different data and are out of scope for statistics checks. The exclusion is a base-scope
  filter, so it must appear identically in every `UNION ALL` branch and be applied before
  `eligible_count` is computed.

## The client boundary

Two different things narrow a statement and they must not be confused. The commented filters
below are places the scope **can** be narrowed for a single run, by the person running it. The
client boundary is a place it **is** narrowed, on every execution, including the one that
happens inside PowerBI with nobody watching.

So the boundary is written into the statement rather than applied by the runner. Immediately
above each commented template filter, in the same alias and column that filter uses:

```sql
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
```

Rules:

- **every branch that can reach the template carries it**, findings and coverage alike, or
  `eligible_count` is counted over a population the findings never saw;
- **a GLOBAL template reads the token**, because seven sports share one text;
- **a sport statement writes the ids out**, because a sport check takes no parameters and a
  `{{...}}` left in one would reach the client unsubstituted;
- **a statement with no template relation carries neither**, and audits the sport whole. Say so
  in the sport file rather than leaving the reader to notice.

`TOOLS/Test-Package.ps1` fails a statement that filters a template without excluding the
boundary, and a sport statement whose written-out ids have drifted from `SPORTS/params.json`.

A competition outside the boundary is deferred, not unsupported: the check would run against it
unchanged. Where the exclusion leaves a check with nothing to audit, the sport records
`Out of client scope` rather than deprecating the CheckID — `TOOLS/README.md` owns that word,
`README.md` owns why the client is a boundary at all.

## Mandatory scope-limiting contract

Every approved query must include at least one safe commented filter suitable for
large sports. Choose the filter from the actual audited object and confirmed relation
path; do not insert a template filter where the audited population has no valid template
relation.

Preferred filters, in order of applicability:

```sql
-- AND t.tournament_templateFK = <tournament_template_id>
```

Use this only when every eligible audited object reaches the selected template through
the query's confirmed relation path.

**Filter the tournament's foreign key, not the template's primary key**, wherever the
statement already joins the tournament that owns the template. The two select the same rows
and are not the same query; `DATABASE.md` `DB-SEM-016` owns why, and measured it at 2.5 seconds
against 28.3 for an identical result. Where no tournament is in scope — a statement auditing
templates themselves — the primary-key form stays correct:

```sql
-- AND tt.id = <tournament_template_id>
```

Both forms are recognised by `TOOLS/Run-Query.ps1 -TemplateIds`, and the alias and column are
read out of the marker rather than assumed.

```sql
-- AND e.startdate >= '<from_datetime>'
-- AND e.startdate <  '<to_datetime>'
```

Use a half-open date range for event-linked data when template scope is unavailable or
insufficient. Use the date column belonging to the confirmed audited path.

```sql
-- AND p.id BETWEEN <from_participant_id> AND <to_participant_id>
```

Use stable primary-key ranges for standalone objects or checks whose purpose includes
missing relations. Replace `p` with the audited table alias.

Rules:

- repeat every activated filter in the findings and coverage branches;
- calculate `eligible_count` after those filters;
- use non-overlapping primary-key batches, for example `1–1000`, `1001–2000`;
- never use `LIMIT/OFFSET` as the audited-scope mechanism;
- never add a relation-dependent filter that would exclude the missing relation the
  query is designed to find;
- use the confirmed numeric sport ID instead of an ambiguous name search when the ID is
  documented.

## Cost and result-size discipline

Every DQ query follows the query cost and result-size rule in `WORKFLOW.md`. Two
constraints are specific to DQ:

- A DQ statement never applies `LIMIT` to its result. On the outer statement or on a
  `UNION ALL` branch it would truncate finding rows or drop the `COVERAGE` row and
  invalidate the result. Control result size through the activated scope filters and
  through audited-object aggregation instead. `LIMIT` inside a scalar subquery that picks
  one value per audited object — `(SELECT r.value FROM result r WHERE ... LIMIT 1)` — does
  not limit the result and is allowed.
- When a batch still times out or exhausts executor memory, reduce that batch — a shorter
  half-open date window or a smaller primary-key range — and rerun the same statement per
  batch. Report each batch's `eligible_count` separately; never merge batches into one
  claimed coverage figure.

The one exception to that last rule is worth stating precisely, because the distinction is
not the arithmetic but what the arithmetic is allowed to claim. Batches chosen by hand are
reported separately because nothing guarantees they tile the population: they are picked at
different times, may overlap, and may leave a gap between them, so their sum asserts a
coverage the run never had. Windows that partition the audited object's own primary key
within a single execution carry that guarantee by construction — every object falls in
exactly one window, and the marker sits in the coverage branch as well as the findings
branch, so each window counts the same population its findings came from. Their sum is
therefore the coverage, not a claim about it, and may be merged into one `COVERAGE` row.

That exception is what `TOOLS/Run-Query.ps1` relies on when it answers a result too large by
cutting the id range up; `TOOLS/README.md` owns the runner behaviour. It does not extend to
date windows, to ranges typed in by a person, or to pieces run across separate invocations —
in each of those the guarantee is an intention rather than a property of the run.

Prefer `EXISTS` over `JOIN` plus `DISTINCT` in the violation predicate, and keep the
findings and coverage branches on the same indexed scope so neither branch scans more
than the other.

## Reusable templates

Before authoring a sport statement, check `GLOBAL_DQ/README.md`. A check whose violation
condition holds for every applicable sport belongs there once, parameterized, rather than
copied per sport: at 110 sports a hand-copied check means 110 places to fix and no way to
detect the copies that drifted.

Instantiating a template for a sport produces a registry row and, when needed, parameter
values in `SPORTS/params.json` — not a new statement. The authorization gate above is
unchanged: a template is not permission to check a sport.

A check stays sport-authored when its condition cannot be expressed through declared
parameters. `GLOBAL_DQ/README.md` owns the qualification rule and the promotion sequence.

## Query-file contract

- Store all active approved sport-authored checks for one sport in
  `POWERBI_QUERIES/<SportSlug>.sql`.
- Never create one SQL file per check.
- Order statements by CheckID.
- The file begins with the first query's `SELECT`; do not add a file header before it.
- Keep each check as one complete statement ending in `;`.
- Separate consecutive statements with the
  `-- ================================================================================`
  banner line used across the repository. `TOOLS/Run-Query.ps1` and
  `TOOLS/Test-Package.ps1` split the file on that banner, so a missing one merges two
  statements into a single unrunnable block. Do not wrap SQL in Markdown fences.
- Execute or paste one statement at a time because the Pool accepts one statement per
  execution. `TOOLS/Run-Query.ps1` observes the same constraint and can run a sport's
  approved checks in one pass; see `TOOLS/README.md`.
- Event-result and statistic-result checks remain separate unless the user explicitly
  approves a combined query.

## Registry contract

`POWERBI_REGISTRY.md` uses this exact column order:

```markdown
| CheckID | Sport | Family | Category | Object | Name | Query file | Status |
```

`Category` identifies the DQ problem family. `Object` identifies the canonical object or
logical storage layer. `Name` must match the SQL identity header exactly.

### Category and the priority it implies

Every category belongs to one of four bands, and the band says what a reviewer works
through first. A broken structure outranks a wrong value, and a wrong value outranks an
empty field: a relation that does not resolve breaks everything read through it, whereas an
empty field is one fact nobody has entered yet. Recorded by decision of 2026-08-05.

The fourth band is not a defect family and is not ranked against the other three. A pattern
summary reports how something is spelled or used, so its rows are groups with counts rather
than things to correct; it takes a number instead of a blank so that it sorts below the work
rather than into the middle of it. Added by decision of 2026-08-10, when the four PATTERNS.sql
summaries a whole run injects reached the board with no priority and no category at all. The
category is derived from the statement's file, which holds nothing else, rather than authored
per CheckID - the same rule by which those statements are selected.

| Band | Categories | What is wrong |
|---|---|---|
| `1 Structure` | `WRONG_STRUCTURE`, `NO_RELATED_RECORDS` | the shape or the relation itself |
| `2 Wrong value` | `WRONG_RESULTS`, `WRONG_GENDER`, `WRONG_DISCIPLINE`, `DATE_RANGE_MISMATCH`, `MALFORMED_NAME`, `DUPLICATE_RECORD` | the value is present and wrong |
| `3 Missing value` | `MISSING_VALUES` | the field is empty |
| `4 Patterns` | `PATTERNS` | nothing is wrong — the rows are a census of how something is spelled or used, and a group with a count is not a thing to correct |

`DUPLICATE_RECORD` sits in the second band and not the first. Two records for one person do
not break a relation — each resolves perfectly well — but every count read through either is
short by whatever the other carries, which is a value that is present and wrong. Added by
decision of 2026-08-11, with `GLOBAL-DISCOVERY-033`.

A discovery statement carries no category, because a census has no defect family. That rule
has a named exception list in `TOOLS/Run-Query.ps1`: a statement whose rows *are* correctable
takes a real category and the band that follows from it, while keeping the `Informational`
signal that puts it on a board as `Monitor Only` expecting a non-zero count. The two say
different things — the category says what kind of defect this is, the signal says whether
anyone is driving it to zero — and a duplicate-candidate list is the case where the answers
differ.

The band is **derived** from the category, never authored per check, so a check cannot
disagree with its own category. The numeric prefix is what makes an ordinary sort produce
the priority order, since the names do not sort that way on their own.

`TOOLS/Run-Query.ps1` carries the map into the workbook and `TOOLS/Test-Package.ps1`
declares the same one, failing any registry `Category` that is missing from it — so a new
category cannot reach a reviewer as a blank on the column meant to say what to do first.
Adding a category means adding it here and in both scripts.

`Family` and `Query file` answer two independent questions and must not be conflated:

| Column | Question |
|---|---|
| `Family` | Which logical check is this? A `GLOBAL-DQ-NNN` template ID, or `—` when the check has no template |
| `Query file` | Which file holds the executable statement? |

`Family` is what lets PowerBI group and compare one check across sports, whose own CheckIDs
differ because numbering restarts per sport. Assign it whenever a template expresses the
same logical check, even when the sport runs its own statement.

For `Approved` rows, `Query file` points either to a `GLOBAL_DQ/` template — the row is an
instantiation and no per-sport statement exists — or to `POWERBI_QUERIES/<SportSlug>.sql`,
which must then contain a statement with that CheckID. A row cannot have both. For
`Deprecated` rows, `Query file` may be `—` when executable SQL was intentionally removed;
the CheckID remains permanently reserved.

The registry is the authority for assigned IDs and statuses. The sport SQL file is the
authority for executable query text. If the two disagree, treat the PowerBI update as
incomplete and ask the user to provide or correct the missing counterpart.

## Manual PowerBI update command

Approved pending checks are converted into file updates only after:

```text
PREPARE_POWERBI_UPDATE SPORT=<Sport>
```

Example:

```text
PREPARE_POWERBI_UPDATE SPORT=Curling
```

When this command is received:

1. review only user-approved checks for the named sport;
2. compare CheckIDs and semantic meaning with the latest `POWERBI_REGISTRY.md`;
3. compare executable SQL with the latest `POWERBI_QUERIES/<SportSlug>.sql`, if it
   exists;
4. remove checks already present and unchanged;
5. validate the header, coverage and scope contracts for every missing or changed query;
6. return one consolidated registry block and one consolidated sport-query block when
   both destinations change;
7. place new registry rows immediately before the exact `POWERBI DQ REGISTRY` marker;
8. if the sport query file does not exist, return its complete initial content;
9. for an existing sport query file, identify the exact CheckID statement to replace or
   the exact CheckID after which a new statement is inserted;
10. never add full SQL to `POWERBI.md`;
11. never edit project files directly, except under the VSCode direct-editing exception
    in `AI_INSTRUCTIONS.md`, when running inside a local IDE and the user has explicitly
    confirmed the specific change.

The registry block uses `POWERBI_REGISTRY.md`. The SQL block uses the exact
`POWERBI_QUERIES/<SportSlug>.sql` path. DQ observations, violation counts, unapproved
ideas and unrelated structural findings are not eligible.

If no approved PowerBI change is missing, answer exactly:

```text
No PowerBI update required.
```

## SQL execution constraints

- Use one SQL statement per Pool execution.
- The first word is `SELECT`, alone on the first line.
- Place the required three comments immediately below the first outer `SELECT`.
- Never write a CTE. The Pool rejects `WITH` outright, because `SELECT` must be the first
  word; nest derived tables instead. `TOOLS/README.md` owns the server-side rule.
- Use the exact approved sport and scope.
- Never carry example IDs from another sport.
- Do not append unrelated queries or suggestions when the user requests one query.

## PowerBI open questions

Only stable questions explicitly raised during authorized PowerBI work belong here.

<!-- MANUAL PASTE ZONE: POWERBI OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
