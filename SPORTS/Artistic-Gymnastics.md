# SPORT: Artistic Gymnastics (sport_id=40)

This file is the canonical structural record for Artistic Gymnastics. It contains only
confirmed sport-specific usage, meanings, identifiers, evidence boundaries and open
structural questions. Global database mechanisms belong in `../DATABASE.md`.

For additions, insert approved content immediately before the exact active
`MANUAL PASTE ZONE` marker in the destination subsection. Keep the marker unchanged
and at the end of its subsection. Replace existing rows or paragraphs in place when a
correction is required.

## Identity and evidence

- First discovery date: 2026-08-04
- Latest evidence date: 2026-08-04
- Verification boundary: GLOBAL discovery summaries `GLOBAL-DISCOVERY-001` through `-018`,
  `-020`, `-022`, `-024`, and `-030` through `-032`, plus round details for IDs `9` and
  `152`, event-result value-pattern summaries for result types `104`, `545`, `567`, `568`,
  and statistic-data value-pattern summaries for data types `1273` and `1456`. Detail
  statements `-021`, `-023`, `-025`, `-027`, and `-029` were not run. Exact database sport
  name `Artistic Gymnastics`; Enet sport code `ga`.

## Structural coverage

| Area | Status | Evidence |
|---|---|---|
| Core hierarchy | Used | `GLOBAL-DISCOVERY-002`, `-003` |
| Event participants | Used | `GLOBAL-DISCOVERY-004`, `-006`, `-032` |
| Event results | Used | `GLOBAL-DISCOVERY-007`, `-026` |
| Incidents | Not used | `GLOBAL-DISCOVERY-008` returned zero active rows |
| Lineups | Used | `GLOBAL-DISCOVERY-005` |
| Scope layer | Used | `GLOBAL-DISCOVERY-009`, `-010` |
| Properties | Used | `GLOBAL-DISCOVERY-011` |
| object_relation | Used | `GLOBAL-DISCOVERY-012`, `-014` |
| object_discipline | Used | `GLOBAL-DISCOVERY-013`, `-032` |
| Statistics | Used | `GLOBAL-DISCOVERY-015`, `-016`, `-017`, `-024`, `-028`, `-031` |
| Reference values | Used | `GLOBAL-DISCOVERY-030`, `-031` and the typed inventories above |
| Other tables | Not checked | |

## Tables and relation paths used

The sport uses the active core path `tournament_template` → `tournament` →
`tournament_stage` → `event` → `event_participants`. Template and stage genders in active
use are `male`, `female`, and `mixed`.

The tournament stage is the sport's **gender** carrier, not a discipline carrier. A stage is
male, female or mixed, and any stage may hold events of any apparatus; discipline lives on
the event through `object_discipline`. `GLOBAL-DQ-082` is therefore `Not applicable` here,
because it asserts a stage-level discipline grouping this sport does not store. That is a
property of how the sport organises competition rather than of the current data.

The IOC-purpose templates `12886` and `12887` (World Championships Artistic (IOC)) and
`12890` and `12891` (World Cup (IOC)) reach active tournaments but no active stage or event
in the current complete hierarchy inventory. Their tournament presence therefore does not
establish event coverage.

<!-- MANUAL PASTE ZONE: 40 TABLES AND RELATIONS — insert approved additions immediately before this marker; do not move or delete it. -->

## Participant and lineup structure

Active event participants are `athlete` rows of male or female gender and `team` rows of
male, female, or mixed gender. The sport registry (`object_participants`, object=`sport`,
objectFK=`40`) uses the participant roles `athlete` and `team`, and contains both `yes` and
`no` active flags; registry membership must therefore be filtered explicitly.

Lineups are used through `14 Starter`. The parent event participant is a `team`, while the
lineup members are male or female `athlete` rows.

Artistic Gymnastics is a listing sport at event level: ranked multi-entry fields are stored
through result type `100 Rank`. Both individuals and teams participate, so the competition
model is `Listing (individual and team)`, not a fixed two-side H2H model.

`GLOBAL-DQ-068` is a `Monitor` for this sport. Two teams with populated Starter lineups in
the same event may legitimately expose different roster sizes, so the difference itself is
population context rather than proof that one team row is defective. A team event participant
with no lineup at all remains an actionable absence under `GLOBAL-DQ-058`.

`GLOBAL-DQ-043` is also a `Monitor`. Its athlete and lineup-member gender contradictions
remain actionable drill-down rows, but its complete output also includes mixed team entities
whose generic participant gender is not authoritative for a male or female stage. The team
role must be resolved before those rows can identify a repair.

`GLOBAL-DQ-112` stays `Actionable`, and what it finds here is worth naming because the finding
and its repair sit in different layers. Every row this sport has returned is
`LINEUP_ATHLETE_IN_TWO_TEAMS`, always in a Team All-Around event, always one `participant` row
placed in the Starter lineups of two different national teams at once — Brazil and Bangladesh,
Singapore and North Korea, India and Bangladesh, Argentina and Colombia. Reviewed by colleagues,
these are not one gymnast entered twice: they are two different people sharing a surname or a
first name, for whom a single participant record was reused instead of a second one created. So
the reading a bare id invites - "the lineup is wrong" - is the wrong one, and the correction
belongs to the `participant` layer rather than to `lineup`. The check projects the athlete name
and both team names for exactly this reason; two national teams beside one name is the shape
that identifies the defect on sight.

<!-- MANUAL PASTE ZONE: 40 PARTICIPANTS AND LINEUPS — insert approved additions immediately before this marker; do not move or delete it. -->

## Event result types

| result_code | result_typeFK | Value shape | Confirmed meaning | Evidence |
|---|---:|---|---|---|
| rank | 100 | Not checked | Rank | Confirmed-data |
| points | 102 | Not checked | Points | Confirmed-data |
| comment | 104 | Status/progression text and digit-bearing variants; valid vocabulary not closed | Comment | Confirmed-data (`007`, `026`) |
| medal | 501 | Not checked | Medal | Confirmed-data |
| penalties | 545 | Numeric integer/decimal patterns observed; valid domain not established | Penalties | Confirmed-data (`007`, `026`) |
| penalty | 567 | Numeric integer/decimal patterns observed; valid domain not established | Penalty | Confirmed-data (`007`, `026`) |
| dscore | 568 | Numeric integer/decimal patterns observed; valid domain not established | DScore | Confirmed-data (`007`, `026`) |
| escore | 569 | Not checked | Escore | Confirmed-data |
| bonus | 645 | Not checked | Bonus | Confirmed-data |

The `104 Comment` vocabulary is closed as of 2026-08-04. The exact literals in active use
outside IOC-purpose templates are `Q`, `Q1` through `Q8`, `R`, `R1` through `R4`, `DNS`,
`DNF`, `NR`, `NC`, `Disq.`, `Withdrawn`, and `From Vault 1`. Only four of them mean the
participant holds no classified result: `DNS`, `DNF`, `Disq.` and `Withdrawn`. The `Q` and
`R` forms are progression markers and do not.

`NR` and `NC` were briefly recorded as no-result markers and are not. Every one of the 117
active `NR` rows carries both a Points value and a Rank, and 42 of the 68 `NC` rows carry
Points while exactly one carries a Rank. Both therefore describe a gymnast who competed and
was left out of a classification, not one with nothing to classify, and both are excluded
from `RESULT_COMMENT_NO_RESULT_LIST` and `DATA_COMMENT_NO_RESULT_LIST`.

`From Vault 1` is deliberately left out of `RESULT_COMMENT_VALUE_LIST`: it is a sentence
rather than a status code, so it is surfaced as a finding rather than blessed as vocabulary.
The list also carries the full `Q1`-`Q8` and `R1`-`R4` ranges even where a given member has
no row today, because an unused member of a confirmed range is a row count and not a
structural absence.

The sport is judged rather than timed. No result type records elapsed time or a gap to the
leader, and no apparatus is decided on the clock, so `RESULT_FULL_TIME_TYPE_ID`,
`RESULT_DURATION_TYPE_ID` and `TIMED_DISCIPLINE_LIST` are recorded under `_notApplicable`.
`GLOBAL-DQ-052` reads a full time and a duration alongside the Comment and is therefore
permanently unrunnable here; `GLOBAL-DQ-076` asserts the same numeric-field rule without
them and is instantiated instead. `102 Points` is the sport's only numeric result type
inside DQ scope, Extended Results being outside it by the decision below.

`102 Points` is also the value the placing inside an event is decided from, and is recorded
as `RESULT_SCORE_TYPE_ID` on that basis. Two gymnasts sharing a place must therefore share a
score; where they do not, the placing contradicts the number it was derived from, which is
what `GLOBAL-DQ-021` asserts through `RESULT_TIE_VALUE_TYPE_LIST`. `GLOBAL-DQ-116` carried that
assertion until 2026-08-07 and is superseded by it; `Artistic-Gymnastics-DQ-097` is `Deprecated`
and `Artistic-Gymnastics-DQ-071` is where the sport now reads it. The score is stored with
inconsistent precision — `13.800` and
`13.8` both occur — so the check compares it as a quantity rather than as text; that is a
property of the template rather than of this sport, recorded here because this sport is where
it was found.

Result types `545 Penalties`, `567 Penalty`, `568 DScore`, `569 Escore`, and `645 Bonus`
belong to Extended Results. By explicit decision of 2026-08-04 they remain in the confirmed
structural inventory but are outside the initial Artistic Gymnastics DQ scope. This boundary
assigns no check and does not classify the fields as unused.

`GLOBAL-DQ-053` is `Actionable`. A medal that does not stand for the place it was awarded
for, or a medal row carrying no Rank at all, is one defective participant row and is repaired
as one, so a corrected sport returns the `COVERAGE` row alone.

It was a `Monitor` until 2026-08-10, on the argument that event-layer Medal and Rank values
include tie and ordinal-storage shapes in which a direct Gold=1, Silver=2, Bronze=3
comparison is not sufficient to classify one participant row as defective. That argument
describes how a *set* of medals can legitimately be read; it does not make a single
mismatched row correct. The classification was withdrawn on that ground.

`GLOBAL-DQ-037` is a `Monitor` at event-set level, for a reason of its own rather than the
one above: legitimate ties and duplicated bronze placements prevent the aggregate
invalid-set result from being a direct repair list, and no-medal, contradictory and
missing-medal subtypes remain useful drill-down targets.

`GLOBAL-DQ-049` is likewise monitored because legitimate `All-Around`
and `All-Round` compounds dominate its generic name-format output, while double spaces and
Cyrillic lookalikes remain actionable subtypes.

`GLOBAL-DQ-122` audits the field the placing is read from rather than the placing itself.
Every check that touches `102 Points` reads it only where it is there, so an event holding
Rank and Medal while Points is wholly absent passes all of them: `GLOBAL-DQ-017` counts the
Rank as a result and calls the event covered, `GLOBAL-DQ-069` needs a row before it can read
a value, and `Artistic-Gymnastics-DQ-099` joins the score and falls silent without it. What
that combination looks like in the data is a placing derived from nothing stored.

The sport upholds the rule almost perfectly: 2 findings over 7 242 finished ranked events.
Event `5723515`, a 2005 Southeast Asian Games final, ranks six athletes and awards three
medals with no Points row at all; event `5651206`, a 2012 World Championships qualifier,
ranks six and comments them `Q`, `Q`, `Q`, `Q`, `R1`, `R2` — qualified from a score the
record does not hold. The third event the raw shape turns up, `5736212`, is not a finding:
its one participant without a score is commented `DNF`, and `RESULT_COMMENT_NO_RESULT_LIST`
excuses exactly that. The excuse is what separates a non-finisher from a lost value, and it
is why the check reads the Comment at all.

<!-- MANUAL PASTE ZONE: 40 EVENT RESULTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Incident types

`Not used`. `GLOBAL-DISCOVERY-008` completed successfully and returned no active incident
type or incident code combination for the sport.

<!-- MANUAL PASTE ZONE: 40 INCIDENTS — insert approved additions immediately before this marker; do not move or delete it. -->

## Scope types and data types

Active event-scope containers use `101 checkpoint1` and `102 checkpoint2`. Both container
types store participant-owned values in `scope_result` with the same field inventory:

| scope_data_typeFK | Name |
|---:|---|
| 1 | rank |
| 2 | points |
| 3 | comment |
| 86 | penalties |
| 1069 | dscore |
| 1070 | escore |
| 1076 | penalty |
| 1077 | bonus |

`event_scope_detail` is used with detail name `name`. No active `lineup_scope_result` layer
was returned by the complete scope-layer inventory; lineup-owned scope values are therefore
`Not used` in this evidence.

The checkpoint layer is a Vault-only structure. Of the 443 finished events carrying an active
container, 442 hold discipline `90 Vault` and one is a single `91 Uneven Bars` event from
2018; the other nine disciplines hold no active container at all. `checkpoint1` and
`checkpoint2` therefore correspond to the two vaults a gymnast performs, not to a general
per-exercise breakdown. The two container types never occur apart: an event holds both or
neither. Containers first appear in 2011 on Finals, are absent across 2015 to 2017, and
resume in 2018 for Finals and Qualifiers alike, where between 54% and 100% of Vault events
carry one depending on the year.

By explicit decision of 2026-08-04 the checkpoint scope layer is outside Artistic Gymnastics
DQ scope. `event_scope`, `scope_result` and `event_scope_detail` stay in the confirmed
structural inventory above, and no DQ check reads them for this sport. `GLOBAL-DQ-102` was
instantiated as `Artistic-Gymnastics-DQ-008` before the decision and is now `Deprecated` in
`POWERBI_REGISTRY.md`; the ID stays permanently reserved. `GLOBAL-DQ-107` and the
period-score templates `GLOBAL-DQ-085`, `-086`, `-089`, `-091` and `-092` are not
instantiated. This boundary assigns no check and does not classify the scope fields as
unused.

<!-- MANUAL PASTE ZONE: 40 SCOPES — insert approved additions immediately before this marker; do not move or delete it. -->

## Properties

Confirmed active `property` names, all with `type='metadata'`:

| Owner | Property names |
|---|---|
| `event` | `checkpoints`, `checkpoint_details`, `discipline`, `ElapsedTime`, `Heat`, `Live`, `medal_related`, `ParticipantType`, `Round`, `Type` |
| `participant` | `date_of_birth`, `discipline`, `height`, `IsNationalTeam`, `status`, `ToBeDecided`, `weight` |
| `tournament_stage` | `Cup`, `StatusComment` |

No active tournament-owned property was returned. The event properties `discipline`,
`ParticipantType`, `Round`, and `Type` exist in parallel with typed relation or hierarchy
fields; their agreement and authority were not tested.

<!-- MANUAL PASTE ZONE: 40 PROPERTIES — insert approved additions immediately before this marker; do not move or delete it. -->

## Generic relations and disciplines

Confirmed active `object_relation` source → target pairs:

- `tournament_template (2) → tournament_sub_set (152)`;
- `tournament_stage (4) → country (33)`;
- `tournament_stage (4) → tournament_age_class (151)`;
- `statistic (83) → country (33)`;
- `statistic (83) → tournament_age_class (151)`.

The same eleven disciplines are attached through `object_discipline` to events (owner type
`5`) and tournament-owned statistics (owner type `83`). The complete observed event matrix is:

| disciplineFK | Discipline | Stage gender | Event participant type |
|---:|---|---|---|
| 82 | Team All-Around | male, female | team |
| 84 | Floor Exercise | male, female | athlete |
| 85 | Pommel Horse | male | athlete |
| 86 | Rings | male | athlete |
| 87 | Balance Beam | female | athlete |
| 88 | Horizontal Bar | male | athlete |
| 89 | Parallel Bars | male | athlete |
| 90 | Vault | male, female | athlete |
| 91 | Uneven Bars | female | athlete |
| 96 | Individual All-Around Artistic | male, female | athlete |
| 798 | Mixed Team | mixed | team |

This matrix records confirmed observed combinations; it does not assert that an unobserved
combination is impossible in the sport.

<!-- MANUAL PASTE ZONE: 40 GENERIC RELATIONS AND DISCIPLINES — insert approved additions immediately before this marker; do not move or delete it. -->

## Statistics

| statistic_typeFK | Owner type | Participant shard | Data shard | Fields/config | Evidence |
|---:|---:|---:|---:|---|---|
| 11 (Comp.Rank) | 3 (tournament) | 11 | 11 | data 1270, 1271, 1273, 1277, 1278, 1429, 1456; config 1463, 1464, 1470, 1471 | Confirmed-schema-data |

Comp.Rank is the only statistic type returned by the known owner-path inventory and
`tournament` is its only confirmed owner level. Physical shard `11` was established
empirically rather than inferred from the statistic type (`DB-SEM-006`).

Active `statistic_data11` fields are `1270 Rank`, `1271 Points`, `1273 Comment`, `1277 Medal`,
`1278 Qualification rank`, `1429 Team`, and `1456 Running Score`. Active `statistic_config`
fields are `1463 Start date`, `1464 End date`, `1470 Gender`, and `1471 Event id`.

Only five of those data fields are in DQ scope: `1270 Rank`, `1271 Points`, `1273 Comment`,
`1277 Medal` and `1429 Team`. `1278 Qualification rank` is an IOC-purpose field — all 29514
of its active rows sit under IOC-purpose templates, which every statistics statement
excludes, so it is unreachable by a DQ check rather than merely unused. `1456 Running Score`
is a different case and is not IOC-only: it holds 128024 active rows outside those templates,
every one of them empty.

**Phase is used, and is not a `statistic_data` field.** It is stored in `object_round` with
`object_typeFK = 138` and `type = 'phase'`, the mechanism `DATABASE.md` records as the only
storage for the concept: the round a Comp.Rank participant's rank was taken from. Outside
IOC-purpose templates, 159088 of the sport's 159096 Comp.Rank participant rows carry one, so
`GLOBAL-DQ-033` is actionable rather than population-wide — the eight rows without a phase
are a repair list.

Confirmed active phase rounds are `179 Qualifier`, `173 Final`, `9 Final`, `172 Tie-breaker`
and `152 Qualifier`. `172 Tie-breaker` occurs **only** as a Comp.Rank phase and never as an
event `round_typeFK`, so it belongs to the sport's round inventory through this path alone.
Its `knockout = yes` flag is correct: a tie-breaker is an elimination round, unlike the
sport's Final and Qualifier rounds, which is why `tie-breaker` is the sole member of
`ELIMINATION_ROUND_NAME_LIST` here. `GLOBAL-DQ-083` does not judge it today, because
`GLOBAL-DQ-097` reaches round types through events and no event is contested under `172`.

`1273 Comment` uses active empty rows as a stored state. Its literal vocabulary outside
IOC-purpose templates is `R`, `R1` through `R4`, `Q`, `Q4`, `Q7`, `Q8`, `DNS`, `DNF`, `NR`,
`NC`, `Disq.` and `Withdrawn`, and the same six of those mean no classified result as at the
event layer. `DNQ` and `DQB` appear in the sport's overall inventory but not in this
population: they occur under IOC-purpose templates, which every statistics statement
excludes. Both stay in `DATA_COMMENT_VALUE_LIST` together with the full `Q1`-`Q8` and
`R1`-`R4` ranges, because a member with no row in the audited population is a row count
rather than a structural absence.

`GLOBAL-DQ-057` is the statistic-layer twin of the Comment rule and reads a Time data field
this sport does not store, so it is permanently unrunnable here for the same reason
`GLOBAL-DQ-052` is at the event layer.

`1456 Running Score` has active rows, but its complete current value-pattern
inventory contains only the empty state; no non-empty active use was confirmed.

`GLOBAL-DQ-072` is `Actionable`. It is the Comp.Rank twin of `GLOBAL-DQ-053` at the event
layer and carries the same invariant: a medal whose stored Rank does not stand for the place
it was awarded for is one defective statistic row, and a corrected sport returns the
`COVERAGE` row alone.

It was a `Monitor` until 2026-08-10, on the argument that Comp.Rank medal rows occur in
tie-aware, ordinal or team-inherited result shapes in which a Rank shifted from the simple
1/2/3 mapping is not automatically one independent defect. That was withdrawn with the same
reasoning as its event-layer twin: those shapes describe how a *set* of medals is arranged,
and none of them makes an individual medal stand for a place it was not awarded for. The
five rows it reports are repairs.

`GLOBAL-DQ-026` monitors the aggregate Comp.Rank medal-set population because legitimate
ties, duplicated bronze placements and team-inherited medal rows can all create repeated
holders. Missing and contradictory medal subtypes remain drill-down targets.

`GLOBAL-DQ-044` is a `Monitor`: athlete-statistic gender contradictions are actionable, but
mixed-gender team entities require team-role semantics before their appearance in a male or
female Comp.Rank can be called defective. `GLOBAL-DQ-051` is also monitored because the
generic statistic-name rule includes legitimate hyphenated and diacritic-bearing names;
double spaces and Cyrillic lookalikes remain actionable drill-down subtypes.

`GLOBAL-DQ-065` is a `Monitor` for the same reason its event-layer twin `GLOBAL-DQ-068` is.
Teams competing in one Artistic Gymnastics competition legitimately field different numbers
of gymnasts, so an uneven athlete count across the teams of one Comp.Rank is population
context rather than proof that one team is entered incompletely. The proportion of uneven
teams is the reading; a single team row is not the repair unit.

<!-- MANUAL PASTE ZONE: 40 STATISTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Reference values

| Catalog | Confirmed IDs and names |
|---|---|
| `result_type` | `100 Rank`; `102 Points`; `104 Comment`; `501 Medal`; `545 Penalties`; `567 Penalty`; `568 DScore`; `569 Escore`; `645 Bonus` |
| `lineup_type` | `14 Starter` |
| `scope_type` | `101 checkpoint1`; `102 checkpoint2` |
| `scope_data_type` | `1 rank`; `2 points`; `3 comment`; `86 penalties`; `1069 dscore`; `1070 escore`; `1076 penalty`; `1077 bonus` |
| `round_type` | `9 Final`; `152 Qualifier`; `173 Final`; `179 Qualifier`; `172 Tie-breaker` (Comp.Rank phase only) |
| `discipline` | `82 Team All-Around`; `84 Floor Exercise`; `85 Pommel Horse`; `86 Rings`; `87 Balance Beam`; `88 Horizontal Bar`; `89 Parallel Bars`; `90 Vault`; `91 Uneven Bars`; `96 Individual All-Around Artistic`; `798 Mixed Team` |
| `tournament_age_class` | `1 SENIOR`; `2 YOUTH`; `3 JUNIOR` |
| `statistic_type` | `11 Comp.Rank` |
| `statistic_data_type` (data) | `1270 Rank`; `1271 Points`; `1273 Comment`; `1277 Medal`; `1278 Qualification rank`; `1429 Team`; `1456 Running Score` |
| `statistic_data_type` (config) | `1463 Start date`; `1464 End date`; `1470 Gender`; `1471 Event id` |
| `status_desc` | `6 Finished`; `106 Cancelled` |

<!-- MANUAL PASTE ZONE: 40 REFERENCE VALUES — insert approved additions immediately before this marker; do not move or delete it. -->

## Event and round representation

Confirmed active coarse/detailed event-status pairs are `finished → 6 Finished` and
`cancelled → 106 Cancelled`.

No event currently carries a not-started status, and that is a row count rather than a
missing structure: `event.status_descFK` is in active use here and `status_desc.status_type`
carries a `notstarted` value the sport can receive with any import. `Artistic-Gymnastics-DQ-084`
is therefore a **sentinel** in the sense `POWERBI.md` defines: its scope is correct, its
population is legitimately empty today, and its `eligible_count = 0` is the right answer
rather than a scope to correct. It exists to stop being silent when the first not-started
event arrives holding results. `Artistic-Gymnastics-DQ-085` reads the same status family but
also audits finished events, so its coverage is not zero.

What separates the two readings of a zero is whether the statement can see the population at
all, and here it demonstrably can: the same template reaches it in the sibling sports, holding
10 not-started events in Modern Pentathlon, 11 in BMX and 3 in Triathlon. The zero is this
sport's own state rather than a template blind to what it audits. Measured on 2026-08-07 over
7 421 events running from 2003 to July 2026, 7 380 of them finished and 41 cancelled, with
none dated in the future and none of the cancelled ones carrying a result.

The complete active event-round inventory contains two different IDs named `Final` (`9`,
`173`) and two named `Qualifier` (`152`, `179`). Round identity must therefore be read from
`round_typeFK`, not from the display name alone. Detail runs for `9` and `152` confirm both
as active event values across more than one competition context; they are not unused legacy
references.

Both confirmed Final IDs, `9` and `173`, are medal-awarding rounds for this sport and form
the approved `MEDAL_ROUND_TYPE_LIST`. The non-medal Qualifier IDs remain outside that list.

<!-- MANUAL PASTE ZONE: 40 EVENT AND ROUND REPRESENTATION — insert approved additions immediately before this marker; do not move or delete it. -->

## Confirmed sport-specific storage semantics

In the complete current stage inventory, every active stage has a direct
`tournament_stage.countryFK` and exactly one age-class relation through
`object_relation 4 → 151`. The confirmed age classes are `SENIOR`, `YOUTH`, and `JUNIOR`.
`city_object` is also used for stages, but only on a subset. Host country through
`object_relation 4 → 33` is a separate, sparsely used path; every observed host-country link
agrees with the same stage's direct country.

`GLOBAL-DQ-034` is a `Monitor` for that reason. It asserts five stage fields at once, and
822 of the sport's 824 stages are reported for the host-country relation alone while their
direct `tournament_stage.countryFK` is present. The proportion carrying the separate relation
is the reading; a single stage row is not a repair unit.

The sport stores judged output in parallel layers: event-participant `result` rows and
participant-owned checkpoint `scope_result` rows use corresponding rank, points, comment,
penalty, D-score, E-score, and bonus concepts. The two layers are independent storage and
their values were not tested for equality.

Tournament-owned Comp.Rank statistics attach country and age class through
`object_relation` and discipline through `object_discipline`. These are separate metadata
paths from the event hierarchy.

Tournament-stage dates are a containing competition window: they may begin before the
earliest event start or end after the latest one. `GLOBAL-DQ-004` is therefore a `Monitor`
for this sport while it compares exact endpoints; a wider containing stage interval is not
itself a boundary defect.

The generic name-format checks require language-aware interpretation. `GLOBAL-DQ-048` is a
`Monitor` because valid compound and geographic names include forms such as `All-Around`,
`Tel-Aviv`, and `São Paulo`. `GLOBAL-DQ-079` is a `Monitor` because the legitimate template
compound `World Cup All-Around` is sufficient to trigger its generic rule.

Summer Olympics tournaments `14678` and `36693` are the confirmed postponed editions whose
stored tournament name is `2020` while their stages took place in 2021. The
`Artistic-Gymnastics-DQ-029` instance of `GLOBAL-DQ-080` excludes exactly those two IDs from
both findings and coverage; the check remains active for every future tournament-season
contradiction.

The `100` rank in a qualifying event records the competitor's qualification position and not
their position on the score. The sport admits at most two gymnasts per country to a final, so
the field is ordered in blocks: the qualifiers first, then the reserves, then everyone else,
and each block is ordered on the score within itself. A reserve therefore legitimately holds a
better score than a gymnast ranked above them. The `104` comment carries the block — `Q` for a
qualifier, `R` for a reserve, empty for the rest — so it is the comment and not the rank that
says which population a row belongs to.

The consequence for any check reading the two together is that the ranking and the score may
only be compared inside one comment value. A 2005 World Championships all-around qualification
holds 24 rows on `Q` ranked 1 to 24, then four on `R` ranked 25 to 28 whose scores overlap the
`Q` block: Mark Holyoake is 25th on 50.887 while four qualifiers scored less, because he was
his country's third entry. Comparing across the whole field reports all 72 of them and every
one is correct. `Artistic-Gymnastics-DQ-099` groups on the comment for this reason.

<!-- MANUAL PASTE ZONE: 40 STORAGE SEMANTICS — insert approved additions immediately before this marker; do not move or delete it. -->

## Sport-specific DQ wave

Eight checks were approved on 2026-08-04 from an analysis of the event and Comp.Rank sample
extracts. `Artistic-Gymnastics-DQ-089` through `-096` live in
`POWERBI_QUERIES/Artistic-Gymnastics.sql` and read no Extended Results field, which stays
outside DQ scope.

Four of them report against real rows: 5 events whose stored discipline contradicts an
unambiguous apparatus in their own name (`-089`); 12 pairs of events, spanning 2005 to 2026,
whose complete participant and Points set is identical across two different disciplines of
one tournament, reported as 24 rows because the audited object is the event (`-090`); 3
Comp.Rank teams whose members disagree on the team Points within one phase (`-091`); 69
participants whose Comment records no classified result while a Rank is stored beside it
(`-093`); 9 scores written into the Comment field with a comma decimal (`-094`); and 2
Individual All-Around events whose Points sit on a single-apparatus scale (`-096`).

`-092` and `-095` return nothing today over non-empty coverage — 3990 gendered-apparatus
events and 66 `From Vault` comments respectively — which is the sport being correct on both
rules rather than a scope to correct.

Two rules deliberately do **not** exist. A generic *rank follows points* assertion must not
be written for Vault: an apparatus qualifier legitimately mixes two-vault averages for
gymnasts contesting the Vault final with first-vault-only scores for those contesting
All-Around and Team, so a lower-ranked gymnast can hold a higher single score. And a
qualifier-count rule keyed on `rank <= 8` would be wrong at every level, because the FIG
per-federation quota lets a gymnast outside the top eight qualify while one inside it does
not; a real version needs a per-template, per-year expected count this package has no
mechanism for.

`GLOBAL-DQ-113`, instantiated as `Artistic-Gymnastics-DQ-005`, already reports the one
statistic mixing team and athlete rows on two incompatible scales, so no sport-specific check
restates it.

A ninth check, `Artistic-Gymnastics-DQ-099`, was approved on 2026-08-07 from a second sample
of the event and Comp.Rank layers. It asserts that the ranking follows the score, which the
2026-08-04 wave declined to write, and it is only writable because the two obstacles that
stopped it then are now separated rather than argued away. The per-federation quota is handled
by comparing inside one `104` comment value, so the Q, the R and the unmarked blocks are each
read on their own. The Vault mixing is handled by exclusion: Vault is dropped outside a final,
because there the comment cannot separate the two score bases and the rule above still holds.
That costs 17 rows the check would otherwise report and leaves 44 over 156587 competitor
entries, among them a 2015 World Championships team final placing a score of 360.035 seventh
behind one of 261.660. The single Vault row that survives is a Vault final, which is the arm
the exclusion keeps.

<!-- MANUAL PASTE ZONE: 40 SPORT-SPECIFIC DQ WAVE — insert approved additions immediately before this marker; do not move or delete it. -->

## Open questions

- Whether event properties `discipline`, `ParticipantType`, `Round`, and `Type` agree with,
  or are derived from, their corresponding typed relations and hierarchy fields.
- What semantic distinction determines use of event result types `545 Penalties` and
  `567 Penalty`; both are Extended Results and their detailed interpretation is deferred.
- Whether the `checkpoints` and `checkpoint_details` event properties describe the same two
  vaults the checkpoint containers hold, and which path is authoritative. The containers are
  now confirmed Vault-only, but the two properties were not profiled and the layer is outside
  DQ scope, so the question stays open without a check attached to it.
- Whether `1456 Running Score` is intentionally instantiated as an empty reserved field or
  is expected to receive values in a competition format not present in the current evidence.
  Its shape is now measured — 128024 active rows outside IOC-purpose templates, every one of
  them empty — which rules out the field being merely IOC-confined but does not say why it is
  instantiated at all.
- Whether the sparse stage host-country relation is intentional duplication of the direct
  country or a separately maintained field. The proportion is now measured: 822 of 824 stages
  carry no host-country relation while their direct `countryFK` is present, which is why
  `GLOBAL-DQ-034` is a `Monitor`. Whether the relation is meant to be populated at all is the
  part still open.
- The row-level co-occurrence of country, age class, and discipline metadata on Comp.Rank
  statistics; the three paths are used, but their alignment on the same statistics was not
  tested.
- Why `172 Tie-breaker` appears only as a Comp.Rank phase and never as an event
  `round_typeFK`. The round is a legitimate elimination round and its `knockout = yes` flag is
  correct, but no event in the sport is contested under it, so a rank derived from a
  tie-breaker has no event to point back to.
- Whether the eight Comp.Rank rows without a phase and the 18 medals recorded against a
  Qualifier phase share one cause. Both sets are now reported by `Artistic-Gymnastics-DQ-087`
  and `-088`; the first is confined to a single statistic, which reads as one broken import.
- Event-name, stage-name, statistic-name, and anomalous value-pattern details remain
  unclassified because `GLOBAL-DISCOVERY-021`, `-023`, `-025`, `-027`, and `-029` were not
  run.

<!-- MANUAL PASTE ZONE: 40 OPEN QUESTIONS — insert approved additions immediately before this marker; do not move or delete it. -->
