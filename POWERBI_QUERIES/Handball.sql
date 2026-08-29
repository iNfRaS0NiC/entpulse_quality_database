SELECT
    -- CheckID - Handball-DQ-059
    -- Name - PARTICIPANT_DUPLICATE_REGISTRY_ROWS
    -- What it does: Flags athletes the sport registry holds under more than one row for this sport.
    'REGISTERED_MORE_THAN_ONCE' AS check_type,
    p.id AS participant_id,
    p.name AS participant_name,
    p.gender AS participant_gender,
    COUNT(DISTINCT op.id) AS registry_row_count,
    GROUP_CONCAT(DISTINCT op.participant_type ORDER BY op.participant_type SEPARATOR ' | ') AS roles_seen,
    GROUP_CONCAT(DISTINCT op.active ORDER BY op.active SEPARATOR ' | ') AS active_flags_seen,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds a person the sport registry knows under two or more
-- object_participants rows for handball, and reports the roles and active flags those rows
-- disagree on. One person is one registration; a second row makes every count read through the
-- registry ambiguous, because a query grouping by row counts the person twice while one
-- grouping by participant does not.
-- Written 2026-08-28 because no GLOBAL template asks this. GLOBAL-DISCOVERY-033 finds the
-- shape but is discovery and asserts nothing, and it answers a different question: it groups
-- by NAME, so it also reports two distinct people who happen to share one, and a namesake is
-- not a defect. This statement groups by participant id instead, so every row it returns is
-- one person the registry holds twice and there is no namesake among them. Ice-Hockey-DQ-088
-- names these duplicate registry rows as a separate question and deliberately asserts nothing
-- about them; this is that question, asked for this sport.
-- Measured the day it was written: 30 athletes of 27814 registered, found through
-- GLOBAL-DISCOVERY-033 with PERSON_PARTICIPANT_TYPE_LIST set to 'athlete'. Widening the same
-- discovery to coaches raised it to 82, because handball keeps one person as an athlete and as
-- a coach far more often than the other sports in the package - Nikolaj Jacobsen, participant
-- 90202, is both. Whether one person holding an athlete row and a coach row is a duplicate at
-- all is a real question and not one this statement decides, so it audits athletes only and
-- says so; a row here is a person registered twice in the same role space.
-- Sport-wide by construction, like Ice-Hockey-DQ-088. The sport registry has no template
-- relation, so the client boundary cannot narrow it and no boundary filter is written here:
-- a duplicated athlete is duplicated whichever competition they were entered in.
FROM object_participants op
JOIN participant p
  ON p.id = op.participantFK
 AND p.del = 'no'
WHERE op.object = 'sport'
  AND op.objectFK = 20
  AND op.del = 'no'
  AND p.type = 'athlete'
  -- AND p.id BETWEEN <from_participant_id> AND <to_participant_id>
GROUP BY p.id, p.name, p.gender
HAVING COUNT(DISTINCT op.id) > 1

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL AS participant_id,
    NULL AS participant_name,
    NULL AS participant_gender,
    NULL AS registry_row_count,
    NULL AS roles_seen,
    NULL AS active_flags_seen,
    COUNT(DISTINCT p.id) AS eligible_count,
    1 AS sort_order
FROM object_participants op
JOIN participant p
  ON p.id = op.participantFK
 AND p.del = 'no'
WHERE op.object = 'sport'
  AND op.objectFK = 20
  AND op.del = 'no'
  AND p.type = 'athlete'
  -- AND p.id BETWEEN <from_participant_id> AND <to_participant_id>

ORDER BY sort_order, registry_row_count DESC, participant_name;

-- ==============================================================================

SELECT
    -- CheckID - Handball-DQ-060
    -- Name - PARTICIPANT_REGISTRY_ROLE_CONTRADICTS_PARTICIPANT_TYPE
    -- What it does: Flags sport registry rows whose role disagrees with the participant's own type, or carries no role at all.
    CASE
        WHEN op.participant_type IS NULL OR TRIM(op.participant_type) = '' THEN 'REGISTRY_ROLE_EMPTY'
        ELSE 'REGISTRY_ROLE_CONTRADICTS_TYPE'
    END AS check_type,
    op.id AS registry_row_id,
    p.id AS participant_id,
    p.name AS participant_name,
    op.participant_type AS registry_role,
    p.type AS participant_type,
    op.active AS registry_active_flag,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Reads every row of the handball sport registry and asserts that
-- the role the registry files a person under is the type that person actually is. Two ways it
-- fails: the role names one thing and participant.type another, or the role is absent
-- altogether while the row still claims a place in the registry.
-- The audited object is the registry ROW and not the person, which is the opposite choice from
-- Handball-DQ-059 and deliberate: a person may hold a correct row and a contradicting one at
-- the same time, and reporting the person would hide which row is to be corrected. That is also
-- why the two statements do not restate each other - 059 asks how many rows a person has, this
-- one asks whether a row says the right thing.
-- Measured 2026-08-28: 100 rows of the registry, 54 filing a coach under the role athlete (two
-- of them with del set) and 46 official rows carrying no role at all. Ice Hockey shows the same
-- shape on 150 rows and records it as an observation; this asks it as a check.
-- Sport-wide by construction. The sport registry has no template relation, so the client
-- boundary cannot narrow it and none is written here.
FROM object_participants op
JOIN participant p
  ON p.id = op.participantFK
 AND p.del = 'no'
WHERE op.object = 'sport'
  AND op.objectFK = 20
  AND op.del = 'no'
  -- AND op.id BETWEEN <from_registry_row_id> AND <to_registry_row_id>
  AND (
        op.participant_type IS NULL
     OR TRIM(op.participant_type) = ''
     OR op.participant_type <> p.type
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL AS registry_row_id,
    NULL AS participant_id,
    NULL AS participant_name,
    NULL AS registry_role,
    NULL AS participant_type,
    NULL AS registry_active_flag,
    COUNT(DISTINCT op.id) AS eligible_count,
    1 AS sort_order
FROM object_participants op
JOIN participant p
  ON p.id = op.participantFK
 AND p.del = 'no'
WHERE op.object = 'sport'
  AND op.objectFK = 20
  AND op.del = 'no'
  -- AND op.id BETWEEN <from_registry_row_id> AND <to_registry_row_id>

ORDER BY sort_order, check_type, participant_name;

-- ==============================================================================

SELECT
    -- CheckID - Handball-DQ-061
    -- Name - TOURNAMENT_STAGE_NAME_GROUP_ABBREVIATION_INCONSISTENT
    -- What it does: Flags stages abbreviating a group as Gr. where the sport's own convention is Grp.
    'STAGE_NAME_GROUP_ABBREVIATION_ODD' AS check_type,
    ts.id AS tournament_stage_id,
    ts.name AS tournament_stage_name,
    t.name AS tournament_name,
    tt.name AS template_name,
    ts.startdate AS stage_startdate,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Handball writes the word "group" in a stage name as an
-- abbreviation followed by a letter or a number, and it does not write it the same way
-- everywhere. Measured 2026-08-28 over all 200 digit-normalized stage name patterns in the
-- client boundary: Grp. on 1185 stages, grp. on 98, Gr. on 30. Grp. is the convention by two
-- orders of magnitude and this reports the stages that use Gr. instead.
-- It stops at Gr. deliberately, and the 98 grp. stages are NOT reported here, because they
-- differ from the convention only in case and Handball-DQ-049 (GLOBAL-DQ-050) already audits
-- exactly that. Reporting them in both would put one stage on the board twice under two
-- CheckIDs, which is the shape a reader takes for two separate problems.
-- Not a defect in the data's meaning - a reader understands Gr. A perfectly well - but a
-- report grouping stages by name treats World Championships Gr. A and World Championships
-- Grp. A as two competitions, and that is what this guards.
-- The period is written as the character class [.] rather than as an escape. That is not a
-- style choice: written \. the escape was lost on the way to the server, the pattern read as
-- "Gr, any character, non-letter", and Grp. matched it - 1277 findings of 1922 stages on the
-- first run, measured 2026-08-28, against the 30 the inventory says carry Gr. A class cannot
-- be unescaped by anything, so the pattern means what it reads as.
-- Word boundaries are asserted on both sides so Grp. never matches: a non-letter before Gr,
-- and a non-letter after the period.
FROM tournament_stage ts
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE ts.del = 'no'
  AND tt.sportFK = 20
  AND t.tournament_templateFK IN (363, 364, 380, 381, 387, 388, 9609, 9610, 9611, 10376, 10377, 10382, 10383, 10384, 10385, 10386, 10387, 10495, 10496, 10499, 10500, 10506, 10562, 10590, 10995, 11000, 11075, 11078, 11079, 11108, 11115, 11116, 11117, 11286, 11287, 11546, 11547, 11616, 11617)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND ts.id BETWEEN <from_stage_id> AND <to_stage_id>
  AND ts.name REGEXP '(^|[^A-Za-z])[Gg]r[.][^A-Za-z]'

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL AS tournament_stage_id,
    NULL AS tournament_stage_name,
    NULL AS tournament_name,
    NULL AS template_name,
    NULL AS stage_startdate,
    COUNT(DISTINCT ts.id) AS eligible_count,
    1 AS sort_order
FROM tournament_stage ts
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE ts.del = 'no'
  AND tt.sportFK = 20
  AND t.tournament_templateFK IN (363, 364, 380, 381, 387, 388, 9609, 9610, 9611, 10376, 10377, 10382, 10383, 10384, 10385, 10386, 10387, 10495, 10496, 10499, 10500, 10506, 10562, 10590, 10995, 11000, 11075, 11078, 11079, 11108, 11115, 11116, 11117, 11286, 11287, 11546, 11547, 11616, 11617)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND ts.id BETWEEN <from_stage_id> AND <to_stage_id>

ORDER BY sort_order, template_name, tournament_name, tournament_stage_name;

-- ==============================================================================

SELECT
    -- CheckID - Handball-DQ-062
    -- Name - COMP.RANK_TEAM_ATHLETE_COUNT_GAP_BEYOND_SQUAD_VARIATION
    -- What it does: Flags a Comp.Rank whose team squad sizes differ by four or more, which handball's own squad rules cannot explain.
    'TEAM_SIZE_GAP_BEYOND_SQUAD_VARIATION' AS check_type,
    a.statistic_id,
    a.statistic_name,
    a.template_name,
    a.tournament_name,
    a.team_count,
    a.assigned_athlete_count,
    a.min_athletes_per_team,
    a.max_athletes_per_team,
    a.max_athletes_per_team - a.min_athletes_per_team AS size_gap,
    a.team_size_breakdown,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: The same question GLOBAL-DQ-065 asks, with the threshold this
-- sport actually needs. A handball squad is not a fixed number: the rules have allowed 14, 15
-- and 16 players over the years the boundary covers, and a team may enter fewer, so two teams
-- in one tournament differing by one, two or three players is the sport behaving normally and
-- not a defect anybody can correct.
-- Written 2026-08-28 by decision, after reading what GLOBAL-DQ-065 returns here: 61 findings of
-- 66 eligible statistics, 91 per cent, which is a check reporting the sport rather than a
-- defect in it. Measured the same day, the gap distribution splits cleanly - 12 statistics
-- differ by 1, 13 by 2 and 13 by 3, and then it jumps: 22 statistics differ by 4 or more, up to
-- a gap of 22 in World Championship U21 Male 2025 (6 against 28) and a squad of ONE athlete
-- against 15 in Summer Olympics Female 2008. Four is where squad variation stops explaining it.
-- GLOBAL-DQ-065 keeps its own CheckID here, Handball-DQ-026, and is recorded as Monitor: it
-- still answers the general question and its count is the sport's shape, while this statement
-- is the one with work in it. The two are deliberately not the same population and neither
-- subsumes the other - 065 reports 61, this reports 22, and every one of the 22 is among the 61.
-- CLIENT BOUNDARY EXCLUDING FORM: the including form does not execute. Measured 2026-08-28,
-- the selective IN over the 39 templates the client takes makes the optimiser drive from
-- tournament and lose the index path into the statistic shards, and the gateway times out at
-- 504 rather than returning slowly. Five rewrites were tried and all five timed out: the
-- filter written directly, the filter moved after the aggregation, the same with the coverage
-- branch rewritten as a derived table, STRAIGHT_JOIN pinning statistic as the driving table,
-- and the joins reversed to drive from statistic_data11. Written as the complement the same
-- statement returns in 14.3 seconds. TOOLS/README.md owns the exception and what it costs.
-- IN SCOPE: 363, 364, 380, 381, 387, 388, 9609, 9610, 9611, 10376, 10377, 10382, 10383, 10384, 10385, 10386, 10387, 10495, 10496, 10499, 10500, 10506, 10562, 10590, 10995, 11000, 11075, 11078, 11079, 11108, 11115, 11116, 11117, 11286, 11287, 11546, 11547, 11616, 11617
-- What this form cannot protect against, stated because the checker cannot see it: a template
-- handball gains next season is outside that in-scope list and INSIDE this statement, which is
-- the exact default the including form exists to prevent. When the sport gains a template, this
-- statement's excluded list is edited with the boundary, or it silently widens.
-- Statistics context per POWERBI.md: template_name is projected and IOC-purpose templates are
-- excluded in both branches, and the template filter reads t.tournament_templateFK rather than
-- tt.id so the optimiser keeps its index path into the shards.
FROM (
    SELECT
        g.statistic_id,
        g.statistic_name,
        g.template_name,
        g.tournament_name,
        COUNT(*) AS team_count,
        SUM(g.athlete_count) AS assigned_athlete_count,
        MIN(g.athlete_count) AS min_athletes_per_team,
        MAX(g.athlete_count) AS max_athletes_per_team,
        GROUP_CONCAT(CONCAT(g.team_participant_name, '=', g.athlete_count)
                     ORDER BY g.athlete_count DESC, g.team_participant_name
                     SEPARATOR ', ') AS team_size_breakdown
    FROM (
        SELECT
            s.id AS statistic_id,
            s.name AS statistic_name,
            tt.name AS template_name,
            t.name AS tournament_name,
            tp.id AS team_participant_id,
            tp.name AS team_participant_name,
            COUNT(DISTINCT sp.id) AS athlete_count
        FROM statistic s
        JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
        JOIN statistic_participants11 sp ON sp.statisticFK = s.id AND sp.del = 'no'
        JOIN participant p ON p.id = sp.participantFK AND p.del = 'no' AND p.type = 'athlete'
        JOIN statistic_data11 td
          ON td.statistic_participants11FK = sp.id
         AND td.statistic_data_typeFK = 1429
         AND td.del = 'no'
         AND td.value REGEXP '^[0-9]+$'
        JOIN participant tp ON tp.id = CAST(TRIM(td.value) AS UNSIGNED) AND tp.del = 'no' AND tp.type = 'team'
        WHERE s.del = 'no'
          AND s.statistic_typeFK = 11
          AND s.object_typeFK = 3
          AND tt.sportFK = 20
          AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
          AND t.tournament_templateFK NOT IN (346, 347, 348, 349, 350, 351, 352, 353, 354, 355, 356, 357, 358, 359, 360, 361, 362, 365, 366, 367, 368, 369, 370, 371, 372, 373, 374, 375, 376, 377, 378, 379, 382, 383, 384, 385, 386, 8932, 8933, 8934, 8950, 8951, 8952, 9028, 9029, 9030, 9031, 9032, 9034, 9035, 9036, 9037, 9038, 9041, 9042, 9043, 9044, 9055, 9056, 9073, 9074, 9419, 9614, 9616, 9617, 9618, 9877, 9878, 9911, 9912, 9934, 9959, 9960, 9961, 9962, 9963, 9964, 9965, 9966, 9979, 10006, 10027, 10030, 10040, 10050, 10066, 10080, 10125, 10150, 10151, 10213, 10217, 10224, 10281, 10284, 10303, 10378, 10379, 10380, 10381, 10391, 10392, 10415, 10431, 10451, 10489, 10629, 10630, 10631, 10632, 10633, 10634, 10643, 10644, 10934, 11041, 11071, 11072, 11698, 11760, 11777)
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
          -- AND t.tournament_templateFK = <tournament_template_id>
        GROUP BY s.id, s.name, tt.name, t.name, tp.id, tp.name
    ) g
    GROUP BY g.statistic_id, g.statistic_name, g.template_name, g.tournament_name
) a
WHERE a.max_athletes_per_team - a.min_athletes_per_team >= 4

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count,
    1 AS sort_order
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN statistic_participants11 sp ON sp.statisticFK = s.id AND sp.del = 'no'
JOIN participant p ON p.id = sp.participantFK AND p.del = 'no' AND p.type = 'athlete'
JOIN statistic_data11 td
  ON td.statistic_participants11FK = sp.id
 AND td.statistic_data_typeFK = 1429
 AND td.del = 'no'
 AND td.value REGEXP '^[0-9]+$'
JOIN participant tp ON tp.id = CAST(TRIM(td.value) AS UNSIGNED) AND tp.del = 'no' AND tp.type = 'team'
WHERE s.del = 'no'
  AND s.statistic_typeFK = 11
  AND s.object_typeFK = 3
  AND tt.sportFK = 20
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND t.tournament_templateFK NOT IN (346, 347, 348, 349, 350, 351, 352, 353, 354, 355, 356, 357, 358, 359, 360, 361, 362, 365, 366, 367, 368, 369, 370, 371, 372, 373, 374, 375, 376, 377, 378, 379, 382, 383, 384, 385, 386, 8932, 8933, 8934, 8950, 8951, 8952, 9028, 9029, 9030, 9031, 9032, 9034, 9035, 9036, 9037, 9038, 9041, 9042, 9043, 9044, 9055, 9056, 9073, 9074, 9419, 9614, 9616, 9617, 9618, 9877, 9878, 9911, 9912, 9934, 9959, 9960, 9961, 9962, 9963, 9964, 9965, 9966, 9979, 10006, 10027, 10030, 10040, 10050, 10066, 10080, 10125, 10150, 10151, 10213, 10217, 10224, 10281, 10284, 10303, 10378, 10379, 10380, 10381, 10391, 10392, 10415, 10431, 10451, 10489, 10629, 10630, 10631, 10632, 10633, 10634, 10643, 10644, 10934, 11041, 11071, 11072, 11698, 11760, 11777)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
;

-- ==============================================================================

SELECT
    -- CheckID - Handball-DQ-110
    -- Name - EVENT_RESULTS_FINAL_SCORE_NOT_ORDINARY_PLUS_EXTRA_TIME
    -- What it does: Flags a finished match whose Final Result is not its Ordinary time score plus whatever extra time added.
    'FINAL_NOT_ORDINARY_PLUS_EXTRA' AS check_type,
    a.event_id,
    a.event_name,
    a.event_startdate,
    a.template_name,
    a.tournament_name,
    a.ordinary_total,
    a.extra_total,
    a.final_total,
    a.final_total - (a.ordinary_total + a.extra_total) AS difference,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: A handball match is 2x30 minutes, and if it is still level the
-- teams play extra time. The score the match is decided on is therefore the ordinary-time score
-- with the extra-time goals added, and nothing else - there is no third component and no
-- deduction. This asserts that arithmetic, summed over both teams so one statement covers the
-- pair rather than reporting each side separately.
-- Read off the sport's own data before it was written, 2026-08-28. Sampling eight finished
-- events of every one of the 45 round types the boundary uses showed the rule holding
-- everywhere it could be seen: a bronze match at 26:26 after ordinary time, 7:5 in extra time
-- and 33:31 final. Where a match went no further, Final Result equals Ordinary time exactly.
-- Measured the same day, 162 finished events break it.
-- No GLOBAL template asks this. GLOBAL-DQ-085 sums scope periods against a total and is not
-- applicable here for reasons SPORTS/Handball.md records; this reads the result layer instead,
-- where handball actually stores its periods.
-- Both result types must be present on both sides before the sum means anything, which is what
-- the two counts assert: a match holding only one of them has a different defect and reporting
-- it here would double the work under two CheckIDs.
-- Where it goes was stated wrongly here until 2026-08-29. This text sent such a match to
-- GLOBAL-DQ-017, and it never arrived: that check asks whether the event holds ANY result, and
-- a match missing only Ordinary time holds Final Result and Running score, so Handball-DQ-020
-- returned 0 of 12659 while 54 finished events in the boundary carried no Ordinary time at all.
-- They were reported by neither check for as long as both existed. GLOBAL-DQ-148
-- EVENT_RESULTS_REQUIRED_RESULT_LAYER_MISSING was written for them and this sport carries it as
-- Handball-DQ-121.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        tt.name AS template_name,
        t.name AS tournament_name,
        SUM(CASE WHEN r.result_typeFK = 1 THEN CAST(r.value AS SIGNED) ELSE 0 END) AS ordinary_total,
        SUM(CASE WHEN r.result_typeFK = 2 THEN CAST(r.value AS SIGNED) ELSE 0 END) AS extra_total,
        SUM(CASE WHEN r.result_typeFK = 4 THEN CAST(r.value AS SIGNED) ELSE 0 END) AS final_total,
        SUM(CASE WHEN r.result_typeFK = 1 THEN 1 ELSE 0 END) AS ordinary_rows,
        SUM(CASE WHEN r.result_typeFK = 4 THEN 1 ELSE 0 END) AS final_rows
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
         AND r.result_typeFK IN (1, 2, 4)
         AND r.value REGEXP '^[0-9]+$'
    WHERE e.del = 'no'
      AND tt.sportFK = 20
      AND e.status_type = 'finished'
      AND t.tournament_templateFK IN (363, 364, 380, 381, 387, 388, 9609, 9610, 9611, 10376, 10377, 10382, 10383, 10384, 10385, 10386, 10387, 10495, 10496, 10499, 10500, 10506, 10562, 10590, 10995, 11000, 11075, 11078, 11079, 11108, 11115, 11116, 11117, 11286, 11287, 11546, 11547, 11616, 11617)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND e.id BETWEEN <from_event_id> AND <to_event_id>
    GROUP BY e.id, e.name, e.startdate, tt.name, t.name
) a
WHERE a.ordinary_rows = 2
  AND a.final_rows = 2
  AND a.final_total <> a.ordinary_total + a.extra_total

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
     AND r.result_typeFK = 4
     AND r.value REGEXP '^[0-9]+$'
WHERE e.del = 'no'
  AND tt.sportFK = 20
  AND e.status_type = 'finished'
  AND t.tournament_templateFK IN (363, 364, 380, 381, 387, 388, 9609, 9610, 9611, 10376, 10377, 10382, 10383, 10384, 10385, 10386, 10387, 10495, 10496, 10499, 10500, 10506, 10562, 10590, 10995, 11000, 11075, 11078, 11079, 11108, 11115, 11116, 11117, 11286, 11287, 11546, 11547, 11616, 11617)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND e.id BETWEEN <from_event_id> AND <to_event_id>
;


-- ==============================================================================

SELECT
    -- CheckID - Handball-DQ-111
    -- Name - EVENT_RESULTS_PENALTY_SHOOTOUT_WITHOUT_EXTRA_TIME
    -- What it does: Flags a finished match holding a penalty shootout score but no extra time at all.
    'SHOOTOUT_WITHOUT_EXTRA_TIME' AS check_type,
    b.event_id,
    b.event_name,
    b.event_startdate,
    b.template_name,
    b.tournament_name,
    b.status_desc_name,
    b.shootout_rows,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Handball does not go to a shootout from a draw. A level match
-- plays two periods of extra time, and only if it is still level do the teams take 7-metre
-- throws. A shootout score therefore cannot stand alone: the extra time that had to precede it
-- must be recorded too. This flags the events where it is not.
-- Measured 2026-08-28: 56 finished events in the boundary carry a 3 Penalty Shootout result
-- and no 2 Extra time result of any kind. The sport holds 158 events with extra time and 73
-- with a shootout, so the shape is common enough to read and the exception is a real minority.
-- What it does not decide is which half is wrong - whether the extra-time rows were lost or
-- the shootout was recorded on a match that never had one - and it says so rather than
-- guessing, because both corrections are plausible and they are opposite.
-- The status is projected beside the counts for exactly that reason: an event whose status is
-- 13 Finished AP claims a shootout happened, and one that is plain 6 Finished does not.
-- GLOBAL-DQ-089 asks the neighbouring question - whether an extra-period STATUS matches the
-- scope layer - and is instantiated here as Handball-DQ-105. Neither subsumes the other: that
-- one reads the scope containers, this one reads the result layer, and this sport writes extra
-- time into both.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        tt.name AS template_name,
        t.name AS tournament_name,
        sd.name AS status_desc_name,
        SUM(CASE WHEN r.result_typeFK = 3 THEN 1 ELSE 0 END) AS shootout_rows,
        SUM(CASE WHEN r.result_typeFK = 2 THEN 1 ELSE 0 END) AS extra_rows
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    LEFT JOIN status_desc sd ON sd.id = e.status_descFK
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
         AND r.result_typeFK IN (2, 3)
    WHERE e.del = 'no'
      AND tt.sportFK = 20
      AND e.status_type = 'finished'
      AND t.tournament_templateFK IN (363, 364, 380, 381, 387, 388, 9609, 9610, 9611, 10376, 10377, 10382, 10383, 10384, 10385, 10386, 10387, 10495, 10496, 10499, 10500, 10506, 10562, 10590, 10995, 11000, 11075, 11078, 11079, 11108, 11115, 11116, 11117, 11286, 11287, 11546, 11547, 11616, 11617)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND e.id BETWEEN <from_event_id> AND <to_event_id>
    GROUP BY e.id, e.name, e.startdate, tt.name, t.name, sd.name
) b
WHERE b.shootout_rows > 0
  AND b.extra_rows = 0

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
     AND r.result_typeFK IN (2, 3)
WHERE e.del = 'no'
  AND tt.sportFK = 20
  AND e.status_type = 'finished'
  AND t.tournament_templateFK IN (363, 364, 380, 381, 387, 388, 9609, 9610, 9611, 10376, 10377, 10382, 10383, 10384, 10385, 10386, 10387, 10495, 10496, 10499, 10500, 10506, 10562, 10590, 10995, 11000, 11075, 11078, 11079, 11108, 11115, 11116, 11117, 11286, 11287, 11546, 11547, 11616, 11617)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND e.id BETWEEN <from_event_id> AND <to_event_id>
;


-- ==============================================================================

SELECT
    -- CheckID - Handball-DQ-112
    -- Name - EVENT_RESULTS_ELIMINATION_ROUND_DECIDED_BY_A_TIE
    -- What it does: Flags a finished knockout tie whose Final Result is level, so the round it belongs to decided nothing.
    'KNOCKOUT_ROUND_TIED_FINAL' AS check_type,
    c.event_id,
    c.event_name,
    c.event_startdate,
    c.round_type_name,
    c.template_name,
    c.tournament_name,
    c.shared_final_score,
    c.highest_final_score,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: A knockout round exists to send one team home. A semi-final,
-- quarter-final, 1/8, final or bronze match that ends level has therefore decided nothing, and
-- one of two things is missing - the extra time that broke the tie, or the correction to a
-- score that was never level.
-- Measured 2026-08-28: 4 finished events. It is deliberately narrower than GLOBAL-DQ-084
-- EVENT_RESULT_SCORE_TIED, instantiated here as Handball-DQ-090, which reports every tie in the
-- sport - 532 of them, and 528 are group-stage matches that handball allows to end level by
-- rule. Reading 084's output was what showed the 4 inside it. Both are kept: 084 is the census
-- of ties, this is the four that break a rule, and a reviewer who has only the census has to
-- re-derive the rule to find them.
-- The rounds are named through the same vocabulary SPORTS/params.json declares in
-- ELIMINATION_ROUND_NAME_LIST, and that list is where the definition lives - it was corrected
-- on the day it was written, after the first version put the final and the bronze match on the
-- wrong side and GLOBAL-DQ-097 and -118 said so.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        rt.name AS round_type_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        MIN(CAST(r.value AS SIGNED)) AS shared_final_score,
        MAX(CAST(r.value AS SIGNED)) AS highest_final_score,
        COUNT(*) AS score_rows
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN round_type rt ON rt.id = e.round_typeFK
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
         AND r.result_typeFK = 4
         AND r.value REGEXP '^[0-9]+$'
    WHERE e.del = 'no'
      AND tt.sportFK = 20
      AND e.status_type = 'finished'
      AND t.tournament_templateFK IN (363, 364, 380, 381, 387, 388, 9609, 9610, 9611, 10376, 10377, 10382, 10383, 10384, 10385, 10386, 10387, 10495, 10496, 10499, 10500, 10506, 10562, 10590, 10995, 11000, 11075, 11078, 11079, 11108, 11115, 11116, 11117, 11286, 11287, 11546, 11547, 11616, 11617)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND e.id BETWEEN <from_event_id> AND <to_event_id>
      AND LOWER(rt.name) IN ('semi finals', 'quarter finals', '1/8', 'final', 'bronze')
    GROUP BY e.id, e.name, e.startdate, rt.name, tt.name, t.name
) c
WHERE c.score_rows = 2
  AND c.shared_final_score = c.highest_final_score

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN round_type rt ON rt.id = e.round_typeFK
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
     AND r.result_typeFK = 4
     AND r.value REGEXP '^[0-9]+$'
WHERE e.del = 'no'
  AND tt.sportFK = 20
  AND e.status_type = 'finished'
  AND t.tournament_templateFK IN (363, 364, 380, 381, 387, 388, 9609, 9610, 9611, 10376, 10377, 10382, 10383, 10384, 10385, 10386, 10387, 10495, 10496, 10499, 10500, 10506, 10562, 10590, 10995, 11000, 11075, 11078, 11079, 11108, 11115, 11116, 11117, 11286, 11287, 11546, 11547, 11616, 11617)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  AND LOWER(rt.name) IN ('semi finals', 'quarter finals', '1/8', 'final', 'bronze')
  -- AND e.id BETWEEN <from_event_id> AND <to_event_id>
;


-- ==============================================================================

SELECT
    -- CheckID - Handball-DQ-113
    -- Name - EVENT_RESULTS_HALFTIME_SCORE_ABOVE_ORDINARY_TIME_SCORE
    -- What it does: Flags a team credited with more goals at half time than it holds at the end of ordinary time.
    'HALFTIME_ABOVE_ORDINARY' AS check_type,
    d.event_id,
    d.event_name,
    d.event_startdate,
    d.template_name,
    d.tournament_name,
    d.participant_name,
    d.halftime_score,
    d.ordinary_score,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Goals are not taken away. A team's half-time score is its score
-- after 30 minutes and its ordinary-time score is the same tally after 60, so the first can
-- never exceed the second. This is the strongest invariant the result layer has in this sport,
-- because no format, no rule change and no competition can produce an exception to it.
-- Measured 2026-08-28: 1 event. That is the point rather than an objection - the check costs
-- almost nothing to run and a rise in it means the half-time and full-time fields have been
-- crossed somewhere, which is a defect no other statement in the package would notice.
-- The audited object is the event, and the offending side travels with the row: a match has two
-- teams and only one of them is usually wrong, so naming the participant is what makes the row
-- correctable rather than merely true.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        tt.name AS template_name,
        t.name AS tournament_name,
        p.name AS participant_name,
        MAX(CASE WHEN r.result_typeFK = 5 THEN CAST(r.value AS SIGNED) END) AS halftime_score,
        MAX(CASE WHEN r.result_typeFK = 1 THEN CAST(r.value AS SIGNED) END) AS ordinary_score
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
    JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
         AND r.result_typeFK IN (1, 5)
         AND r.value REGEXP '^[0-9]+$'
    WHERE e.del = 'no'
      AND tt.sportFK = 20
      AND e.status_type = 'finished'
      AND t.tournament_templateFK IN (363, 364, 380, 381, 387, 388, 9609, 9610, 9611, 10376, 10377, 10382, 10383, 10384, 10385, 10386, 10387, 10495, 10496, 10499, 10500, 10506, 10562, 10590, 10995, 11000, 11075, 11078, 11079, 11108, 11115, 11116, 11117, 11286, 11287, 11546, 11547, 11616, 11617)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND e.id BETWEEN <from_event_id> AND <to_event_id>
    GROUP BY e.id, e.name, e.startdate, tt.name, t.name, ep.id, p.name
) d
WHERE d.halftime_score IS NOT NULL
  AND d.ordinary_score IS NOT NULL
  AND d.halftime_score > d.ordinary_score

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
     AND r.result_typeFK = 5
     AND r.value REGEXP '^[0-9]+$'
WHERE e.del = 'no'
  AND tt.sportFK = 20
  AND e.status_type = 'finished'
  AND t.tournament_templateFK IN (363, 364, 380, 381, 387, 388, 9609, 9610, 9611, 10376, 10377, 10382, 10383, 10384, 10385, 10386, 10387, 10495, 10496, 10499, 10500, 10506, 10562, 10590, 10995, 11000, 11075, 11078, 11079, 11108, 11115, 11116, 11117, 11286, 11287, 11546, 11547, 11616, 11617)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND e.id BETWEEN <from_event_id> AND <to_event_id>
;

-- ==============================================================================

SELECT
    -- CheckID - Handball-DQ-114
    -- Name - EVENT_RESULTS_OUTCOME_WORD_CONTRADICTS_FINAL_SCORE
    -- What it does: Flags a team whose Event outcome word disagrees with the Final Result the same match recorded.
    CASE
        WHEN f.outcome = 'draw' THEN 'DRAW_WORD_ON_A_DECIDED_MATCH'
        WHEN f.low_score = f.high_score THEN 'DECIDED_WORD_ON_A_LEVEL_MATCH'
        ELSE 'OUTCOME_WORD_ON_THE_WRONG_SIDE'
    END AS check_type,
    f.event_id,
    f.event_name,
    f.event_startdate,
    f.template_name,
    f.tournament_name,
    f.participant_name,
    f.outcome,
    f.final_score,
    f.low_score,
    f.high_score,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: 668 Event outcome carries won, lost or draw for each team, and
-- 4 Final Result carries the score the match was decided on. The two say the same thing twice,
-- so either can be checked against the other. Three ways they can disagree, and the check_type
-- names which: a team called the winner without the higher score, the word draw on a match one
-- side actually won, and a decided word on a match that ended level.
-- **It returns nothing today and is approved on that basis rather than despite it**, by
-- decision of 2026-08-28. Measured the same day across every finished event in the boundary
-- carrying both fields, the two agree everywhere. What the check guards is the day they stop
-- agreeing: 668 is written by a different path from 4, on 1418 events against 13375, and a
-- redundant field that has never disagreed is exactly the kind that drifts unnoticed once it
-- does. A zero here is the invariant holding, not the check being idle.
-- No GLOBAL template covers it for this sport. GLOBAL-DQ-088 EVENT_WINNER_CONTRADICTS_SCORE
-- asks the same question of the Winner property, which handball does not store at all -
-- recorded under WINNER_VALUE_LIST in SPORTS/params.json - so the question would go unasked
-- here without this statement.
-- A level match is not reported for carrying draw on both sides, which is handball's ordinary
-- group-stage result and what Handball-DQ-090 counts.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        tt.name AS template_name,
        t.name AS tournament_name,
        p.name AS participant_name,
        MAX(CASE WHEN r.result_typeFK = 668 THEN LOWER(TRIM(r.value)) END) AS outcome,
        MAX(CASE WHEN r.result_typeFK = 4 THEN CAST(r.value AS SIGNED) END) AS final_score,
        MIN(w.low_score) AS low_score,
        MAX(w.high_score) AS high_score
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
    JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
         AND r.result_typeFK IN (4, 668)
    JOIN (
        SELECT
            ep2.eventFK AS scored_event_id,
            MIN(CAST(r2.value AS SIGNED)) AS low_score,
            MAX(CAST(r2.value AS SIGNED)) AS high_score
        FROM event_participants ep2
        JOIN result r2 ON r2.event_participantsFK = ep2.id AND r2.del = 'no'
             AND r2.result_typeFK = 4
             AND r2.value REGEXP '^[0-9]+$'
        WHERE ep2.del = 'no'
        GROUP BY ep2.eventFK
    ) w ON w.scored_event_id = e.id
    WHERE e.del = 'no'
      AND tt.sportFK = 20
      AND e.status_type = 'finished'
      AND t.tournament_templateFK IN (363, 364, 380, 381, 387, 388, 9609, 9610, 9611, 10376, 10377, 10382, 10383, 10384, 10385, 10386, 10387, 10495, 10496, 10499, 10500, 10506, 10562, 10590, 10995, 11000, 11075, 11078, 11079, 11108, 11115, 11116, 11117, 11286, 11287, 11546, 11547, 11616, 11617)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND e.id BETWEEN <from_event_id> AND <to_event_id>
    GROUP BY e.id, e.name, e.startdate, tt.name, t.name, ep.id, p.name
) f
WHERE f.outcome IS NOT NULL
  AND f.final_score IS NOT NULL
  AND (
        (f.outcome = 'won'  AND (f.low_score = f.high_score OR f.final_score <> f.high_score))
     OR (f.outcome = 'lost' AND (f.low_score = f.high_score OR f.final_score <> f.low_score))
     OR (f.outcome = 'draw' AND f.low_score <> f.high_score)
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
     AND r.result_typeFK = 668
WHERE e.del = 'no'
  AND tt.sportFK = 20
  AND e.status_type = 'finished'
  AND t.tournament_templateFK IN (363, 364, 380, 381, 387, 388, 9609, 9610, 9611, 10376, 10377, 10382, 10383, 10384, 10385, 10386, 10387, 10495, 10496, 10499, 10500, 10506, 10562, 10590, 10995, 11000, 11075, 11078, 11079, 11108, 11115, 11116, 11117, 11286, 11287, 11546, 11547, 11616, 11617)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND e.id BETWEEN <from_event_id> AND <to_event_id>
;
