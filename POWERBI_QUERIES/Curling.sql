SELECT
    -- CheckID - Curling-DQ-070
    -- Name - EVENT_SCOPE_END_SCORED_BY_BOTH_TEAMS
    -- What it does: Finds active Curling events holding an end in which both teams are recorded as having scored, which the sport's scoring rule makes impossible because only the team holding the hammer outcome takes points in an end and the other is left on zero, with the offending ends named, how many of them the event holds and template, tournament and stage name context, together with a coverage count of all eligible active events holding at least one active end row in the final_result scope.
    'END_SCORED_BY_BOTH_TEAMS' AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    tt.name AS template_name,
    t.name AS tournament_name,
    ts.name AS stage_name,
    x.offending_end_count,
    x.offending_ends,
    NULL AS eligible_count,
    0 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
-- Counted per end rather than per participant, because the defect is the pair and neither
-- side is wrong on its own. Only a strictly positive number counts as having scored: a
-- blank end is 0-0 and is the sport's normal outcome, and the sentinel X marks an end that
-- was never played, so neither can make a pair. A negative or non-numeric value is not read
-- as a score here; it is left to GLOBAL-DQ-086, which names it for what it is.
JOIN (
    SELECT
        p.event_id,
        COUNT(*) AS offending_end_count,
        GROUP_CONCAT(p.period_name ORDER BY p.scope_data_type_id SEPARATOR ', ') AS offending_ends
    FROM (
        SELECT
            es.eventFK AS event_id,
            sr.scope_data_typeFK AS scope_data_type_id,
            COALESCE(sdt.name, CAST(sr.scope_data_typeFK AS CHAR)) AS period_name,
            COUNT(DISTINCT CASE
                WHEN TRIM(sr.value) REGEXP '^[0-9]+$' AND CAST(TRIM(sr.value) AS SIGNED) > 0
                THEN sr.event_participantsFK
            END) AS scoring_sides
        FROM scope_result sr
        JOIN event_scope es ON es.id = sr.event_scopeFK AND es.del = 'no'
                           AND es.scope_typeFK = 305
        JOIN event e2 ON e2.id = es.eventFK AND e2.del = 'no'
        JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
        JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
        JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
        LEFT JOIN scope_data_type sdt ON sdt.id = sr.scope_data_typeFK
        WHERE sr.del = 'no'
          AND sr.scope_data_typeFK IN (282, 283, 284, 285, 286, 287, 288, 289, 290, 291, 292)
          AND tt2.sportFK = 10
        GROUP BY es.eventFK, sr.scope_data_typeFK, sdt.name
    ) p
    WHERE p.scoring_sides >= 2
    GROUP BY p.event_id
) x ON x.event_id = e.id
WHERE e.del = 'no'
  AND tt.sportFK = 10
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

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
JOIN event_scope es ON es.eventFK = e.id AND es.del = 'no'
                   AND es.scope_typeFK = 305
JOIN scope_result sr ON sr.event_scopeFK = es.id AND sr.del = 'no'
                    AND sr.scope_data_typeFK IN (282, 283, 284, 285, 286, 287, 288, 289, 290, 291, 292)
WHERE e.del = 'no'
  AND tt.sportFK = 10
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_startdate DESC;


-- ================================================================================
SELECT
    -- CheckID - Curling-DQ-073
    -- Name - EVENT_SCOPE_EXTRA_END_WITHOUT_TIED_REGULATION_SCORE
    -- What it does: Finds active Curling events whose extra end is recorded as played while the two teams did not reach it level, because an extra end is what a tie after the regular ends produces and nothing else, with each side's regular-end total and extra-end value and template, tournament, stage and status context, together with a coverage count of all eligible active events holding exactly two participants that each carry a numeric extra-end value and at least one numeric regular end.
    'EXTRA_END_WITHOUT_TIED_REGULATION_SCORE' AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    tt.name AS template_name,
    t.name AS tournament_name,
    ts.name AS stage_name,
    e.status_descFK,
    x.regulation_score_low,
    x.regulation_score_high,
    x.side_scores,
    NULL AS eligible_count,
    0 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
-- The regular score is summed from the ends themselves rather than taken as the stored
-- total minus the extra end, so the assertion does not depend on the total being right. It
-- has to be independent: on an awarded win the sport leaves Final Result absent or at zero,
-- which GLOBAL-DQ-085 already reports, and reading the total here would turn that one defect
-- into a second finding wearing a different name. The scheduled number of ends is never
-- asked for, because the extra end has its own column and the sport contests two scheduled
-- lengths - counting ends could not tell an extra end from a game conceded early.
JOIN (
    SELECT
        s.event_id,
        MIN(s.regulation_sum) AS regulation_score_low,
        MAX(s.regulation_sum) AS regulation_score_high,
        GROUP_CONCAT(CONCAT(s.regulation_sum, ' + ', s.extra_value)
                     ORDER BY s.event_participants_id SEPARATOR ' / ') AS side_scores
    FROM (
        SELECT
            es.eventFK AS event_id,
            sr.event_participantsFK AS event_participants_id,
            SUM(CASE
                WHEN sr.scope_data_typeFK BETWEEN 282 AND 291
                 AND TRIM(sr.value) REGEXP '^-?[0-9]+$'
                THEN CAST(TRIM(sr.value) AS SIGNED) ELSE 0
            END) AS regulation_sum,
            SUM(CASE
                WHEN sr.scope_data_typeFK BETWEEN 282 AND 291
                 AND TRIM(sr.value) REGEXP '^-?[0-9]+$'
                THEN 1 ELSE 0
            END) AS regulation_end_count,
            MAX(CASE
                WHEN sr.scope_data_typeFK = 292
                 AND TRIM(sr.value) REGEXP '^-?[0-9]+$'
                THEN CAST(TRIM(sr.value) AS SIGNED)
            END) AS extra_value
        FROM scope_result sr
        JOIN event_scope es ON es.id = sr.event_scopeFK AND es.del = 'no'
                           AND es.scope_typeFK = 305
        JOIN event e2 ON e2.id = es.eventFK AND e2.del = 'no'
        JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
        JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
        JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
        WHERE sr.del = 'no'
          AND sr.scope_data_typeFK IN (282, 283, 284, 285, 286, 287, 288, 289, 290, 291, 292)
          AND tt2.sportFK = 10
        GROUP BY es.eventFK, sr.event_participantsFK
    ) s
    GROUP BY s.event_id
    HAVING COUNT(*) = 2
       AND COUNT(s.extra_value) = 2
       AND MIN(s.regulation_end_count) > 0
       AND MIN(s.regulation_sum) <> MAX(s.regulation_sum)
) x ON x.event_id = e.id
WHERE e.del = 'no'
  AND tt.sportFK = 10
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT y.event_id) AS eligible_count,
    1 AS sort_order
FROM (
    SELECT
        s.event_id
    FROM (
        SELECT
            es.eventFK AS event_id,
            sr.event_participantsFK AS event_participants_id,
            SUM(CASE
                WHEN sr.scope_data_typeFK BETWEEN 282 AND 291
                 AND TRIM(sr.value) REGEXP '^-?[0-9]+$'
                THEN 1 ELSE 0
            END) AS regulation_end_count,
            MAX(CASE
                WHEN sr.scope_data_typeFK = 292
                 AND TRIM(sr.value) REGEXP '^-?[0-9]+$'
                THEN CAST(TRIM(sr.value) AS SIGNED)
            END) AS extra_value
        FROM scope_result sr
        JOIN event_scope es ON es.id = sr.event_scopeFK AND es.del = 'no'
                           AND es.scope_typeFK = 305
        JOIN event e2 ON e2.id = es.eventFK AND e2.del = 'no'
        JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
        JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
        JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
        WHERE sr.del = 'no'
          AND sr.scope_data_typeFK IN (282, 283, 284, 285, 286, 287, 288, 289, 290, 291, 292)
          AND tt2.sportFK = 10
          -- AND e2.startdate >= '<from_datetime>'
          -- AND e2.startdate <  '<to_datetime>'
        GROUP BY es.eventFK, sr.event_participantsFK
    ) s
    GROUP BY s.event_id
    HAVING COUNT(*) = 2
       AND COUNT(s.extra_value) = 2
       AND MIN(s.regulation_end_count) > 0
) y

ORDER BY sort_order, event_startdate DESC;


-- ================================================================================
SELECT
    -- CheckID - Curling-DQ-074
    -- Name - EVENT_SCOPE_ENDS_BELOW_MINIMUM
    -- What it does: Finds active Curling events holding fewer than six scored regular ends, which is below the shortest game either scheduled length can legitimately produce once a conceded game is allowed for, separating an event whose status records an awarded win and therefore explains the shortfall from one that finished normally and does not, with the number of ends scored, the number of end rows stored and template, tournament, stage and status context, together with a coverage count of all eligible active events holding at least one active regular end row in the final_result scope.
    CASE
        WHEN e.status_descFK = 190 THEN 'FEW_ENDS_AWARDED_WIN'
        ELSE 'FEW_ENDS_PLAIN_FINISHED'
    END AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    tt.name AS template_name,
    t.name AS tournament_name,
    ts.name AS stage_name,
    e.status_descFK,
    x.scored_end_count,
    x.stored_end_count,
    NULL AS eligible_count,
    0 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
-- Six is the floor rather than eight or ten, because the sport contests two scheduled
-- lengths and a conceded game legitimately stops early: the scored-end count runs from six
-- to eleven across the active population, so a game under six is short of every shape the
-- sport produces. The extra end is left out of the count, since it can only follow a full
-- regular game and would mask a short one. An awarded win is separated rather than excluded:
-- the status explains a short game, so those rows are a review list while the rest are the
-- finding. Counted per event and not per participant, because a side missing a whole end is
-- GLOBAL-DQ-091 and is not restated here.
JOIN (
    SELECT
        es.eventFK AS event_id,
        COUNT(DISTINCT CASE
            WHEN TRIM(sr.value) REGEXP '^-?[0-9]+$' THEN sr.scope_data_typeFK
        END) AS scored_end_count,
        COUNT(DISTINCT sr.scope_data_typeFK) AS stored_end_count
    FROM scope_result sr
    JOIN event_scope es ON es.id = sr.event_scopeFK AND es.del = 'no'
                       AND es.scope_typeFK = 305
    JOIN event e2 ON e2.id = es.eventFK AND e2.del = 'no'
    JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
    JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
    JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
    WHERE sr.del = 'no'
      AND sr.scope_data_typeFK IN (282, 283, 284, 285, 286, 287, 288, 289, 290, 291)
      AND tt2.sportFK = 10
    GROUP BY es.eventFK
    HAVING scored_end_count < 6
) x ON x.event_id = e.id
WHERE e.del = 'no'
  AND tt.sportFK = 10
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

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
JOIN event_scope es ON es.eventFK = e.id AND es.del = 'no'
                   AND es.scope_typeFK = 305
JOIN scope_result sr ON sr.event_scopeFK = es.id AND sr.del = 'no'
                    AND sr.scope_data_typeFK IN (282, 283, 284, 285, 286, 287, 288, 289, 290, 291)
WHERE e.del = 'no'
  AND tt.sportFK = 10
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_startdate DESC;


-- ================================================================================
SELECT
    -- CheckID - Curling-DQ-077
    -- Name - EVENT_SETTINGS_DISCIPLINE_CONTRADICTS_COMPETITION_NAME
    -- What it does: Finds active Curling events whose competition names it as a Mixed Doubles competition while the event carries no Mixed Doubles discipline relation, or the reverse, so the name and the discipline disagree about which format was contested, with the disciplines actually related and template, tournament and stage name context, together with a coverage count of all eligible active events carrying at least one active discipline relation. The name is read from the template, tournament and stage together, because the format is named by the competition rather than by the event, whose name is only the pairing that played it.
    CASE
        WHEN x.name_says_mixed_doubles = 1 THEN 'NAME_SAYS_MIXED_DOUBLES_DISCIPLINE_DOES_NOT'
        ELSE 'DISCIPLINE_MIXED_DOUBLES_NAME_DOES_NOT'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.template_name,
    x.tournament_name,
    x.stage_name,
    x.stage_gender,
    x.actual_discipline_names,
    NULL AS eligible_count,
    0 AS sort_order
-- Only the Mixed Doubles name is asserted, and only in one direction each way, because the
-- sport's other formats are not named uniquely enough to judge: a competition named "Mixed"
-- alone is the four-player mixed team event and is legitimately 4aSide, so a rule keyed on
-- "mixed" would report the whole of that format. "Mixed doubles" is the one phrase that
-- names exactly one discipline, which is what makes it checkable at all. The discipline is
-- read through EXISTS rather than by comparing one id, so an event carrying more than one
-- relation is judged on whether Mixed Doubles is among them.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        tt.name AS template_name,
        t.name AS tournament_name,
        ts.name AS stage_name,
        ts.gender AS stage_gender,
        CASE WHEN LOWER(CONCAT_WS(' ', tt.name, t.name, ts.name)) LIKE '%mixed doubles%'
             THEN 1 ELSE 0 END AS name_says_mixed_doubles,
        CASE WHEN EXISTS (
                 SELECT 1 FROM object_discipline od
                 WHERE od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
                   AND od.disciplineFK = 752
             ) THEN 1 ELSE 0 END AS has_mixed_doubles_discipline,
        (SELECT GROUP_CONCAT(DISTINCT d2.name ORDER BY d2.name SEPARATOR ', ')
           FROM object_discipline od2
           JOIN discipline d2 ON d2.id = od2.disciplineFK AND d2.del = 'no'
          WHERE od2.object_typeFK = 5 AND od2.objectFK = e.id AND od2.del = 'no'
        ) AS actual_discipline_names
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    WHERE e.del = 'no'
      AND tt.sportFK = 10
      -- AND tt.id = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
      AND EXISTS (
          SELECT 1 FROM object_discipline od3
          WHERE od3.object_typeFK = 5 AND od3.objectFK = e.id AND od3.del = 'no'
      )
) x
WHERE x.name_says_mixed_doubles <> x.has_mixed_doubles_discipline

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
WHERE e.del = 'no'
  AND tt.sportFK = 10
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND EXISTS (
      SELECT 1 FROM object_discipline od
      WHERE od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
  )

ORDER BY sort_order, event_startdate DESC;


-- ================================================================================
SELECT
    -- CheckID - Curling-DQ-078
    -- Name - COMP.RANK_TEAM_ROSTER_SIZE_CONTRADICTS_DISCIPLINE
    -- What it does: Finds active tournament-owned Comp.Rank statistics of Curling, excluding IOC-purpose templates, holding a team whose number of assigned athletes contradicts the discipline the statistic itself carries, separating a Mixed Doubles team that is not a pair, a 4aSide statistic in which most teams are pairs and which is therefore a doubles competition carrying the wrong discipline, and a 4aSide team short of four where the rest of the statistic is not, with the offending teams and their sizes, the discipline and template and tournament name context, together with a coverage count of all eligible statistics carrying a discipline and at least one athlete assigned to a resolvable team.
    CASE
        WHEN x.doubles_team_not_two > 0 THEN 'MIXED_DOUBLES_TEAM_NOT_TWO'
        WHEN x.four_a_side_sized_like_doubles * 2 > x.team_count THEN 'FOUR_A_SIDE_STATISTIC_IS_DOUBLES_SHAPED'
        ELSE 'FOUR_A_SIDE_TEAM_BELOW_MINIMUM'
    END AS check_type,
    x.statistic_id,
    x.statistic_name,
    x.template_name,
    x.tournament_name,
    x.disciplineFK,
    x.discipline_name,
    x.team_count,
    x.doubles_team_not_two,
    x.four_a_side_sized_like_doubles,
    x.four_a_side_below_minimum,
    x.offending_teams,
    NULL AS eligible_count,
    0 AS sort_order
-- The independent witness of a wrong discipline. GLOBAL-DQ-065 measures whether the teams
-- inside one statistic field the same number of athletes, which passes when every team is
-- the wrong size in the same way; this measures each team against the size its own
-- discipline requires, which is the only way a uniformly mislabelled competition shows up.
-- What separates a wrong discipline from an incomplete entry is the proportion, not the
-- size: one team of two among twenty-eight is a roster nobody finished, while most of the
-- teams being pairs is a doubles competition wearing the wrong discipline. The two are
-- repaired in different places - one statistic's discipline against many teams' rosters -
-- so reading them as one verdict would send the whole list to the wrong desk. Five athletes
-- is the sport's most common 4aSide roster, four players and an alternate, so the floor is
-- four and no ceiling is asserted.
FROM (
    SELECT
        s.id AS statistic_id,
        s.name AS statistic_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        r.disciplineFK,
        d.name AS discipline_name,
        COUNT(*) AS team_count,
        SUM(CASE WHEN r.disciplineFK = 752 AND r.athletes_per_team <> 2 THEN 1 ELSE 0 END) AS doubles_team_not_two,
        SUM(CASE WHEN r.disciplineFK = 753 AND r.athletes_per_team = 2 THEN 1 ELSE 0 END) AS four_a_side_sized_like_doubles,
        SUM(CASE WHEN r.disciplineFK = 753 AND r.athletes_per_team < 4 THEN 1 ELSE 0 END) AS four_a_side_below_minimum,
        GROUP_CONCAT(CASE
            WHEN (r.disciplineFK = 752 AND r.athletes_per_team <> 2)
              OR (r.disciplineFK = 753 AND r.athletes_per_team < 4)
            THEN CONCAT(COALESCE(tp.name, r.team_participant_id), ' = ', r.athletes_per_team)
        END ORDER BY r.athletes_per_team SEPARATOR '; ') AS offending_teams
    FROM (
        SELECT
            s2.id AS statistic_id,
            (SELECT MIN(od.disciplineFK) FROM object_discipline od
              WHERE od.object_typeFK = 83 AND od.objectFK = s2.id AND od.del = 'no') AS disciplineFK,
            sd.value AS team_participant_id,
            COUNT(DISTINCT sp.id) AS athletes_per_team
        FROM statistic s2
        JOIN tournament t2 ON t2.id = s2.objectFK AND t2.del = 'no'
        JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
        JOIN statistic_participants11 sp ON sp.statisticFK = s2.id AND sp.del = 'no'
        JOIN statistic_data11 sd ON sd.statistic_participants11FK = sp.id
             AND sd.statistic_data_typeFK = 1429
             AND sd.del = 'no'
             AND sd.value IS NOT NULL
             AND TRIM(sd.value) <> ''
        WHERE s2.del = 'no'
          AND s2.statistic_typeFK = 11
          AND s2.object_typeFK = 3
          AND tt2.sportFK = 10
          AND (tt2.name IS NULL OR tt2.name NOT LIKE '%(IOC)%')
          -- AND tt2.id = <tournament_template_id>
        GROUP BY s2.id, sd.value
    ) r
    JOIN statistic s ON s.id = r.statistic_id
    JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN discipline d ON d.id = r.disciplineFK AND d.del = 'no'
    LEFT JOIN participant tp ON tp.id = r.team_participant_id AND tp.del = 'no'
    GROUP BY s.id, s.name, tt.name, t.name, r.disciplineFK, d.name
    HAVING doubles_team_not_two > 0
        OR four_a_side_sized_like_doubles > 0
        OR four_a_side_below_minimum > 0
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count,
    1 AS sort_order
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN statistic_participants11 sp ON sp.statisticFK = s.id AND sp.del = 'no'
JOIN statistic_data11 sd ON sd.statistic_participants11FK = sp.id
     AND sd.statistic_data_typeFK = 1429
     AND sd.del = 'no'
     AND sd.value IS NOT NULL
     AND TRIM(sd.value) <> ''
WHERE s.del = 'no'
  AND s.statistic_typeFK = 11
  AND s.object_typeFK = 3
  AND tt.sportFK = 10
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
  AND EXISTS (
      SELECT 1 FROM object_discipline od
      JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
      WHERE od.object_typeFK = 83 AND od.objectFK = s.id AND od.del = 'no'
  )

ORDER BY sort_order;


-- ================================================================================
SELECT
    -- CheckID - Curling-DQ-082
    -- Name - EVENT_SCOPE_CONTAINER_SHAPE_CONTRADICTS_DISCIPLINE
    -- What it does: Finds active Curling events whose end-by-end container is shaped like no length the sport schedules, holding an end_9 column without the end_10 that a ten-end game would also carry, or is shaped for ten ends while the event is contested as Mixed Doubles, which is played over eight, separating the two, with the shape found, the highest end column stored and template, tournament, stage and discipline context, together with a coverage count of all eligible active events holding at least one active regular end row in the final_result scope.
    CASE
        WHEN x.container_shape = '9-end' THEN 'CONTAINER_SHAPE_NOT_A_SCHEDULED_LENGTH'
        ELSE 'MIXED_DOUBLES_WITH_TEN_END_CONTAINER'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.template_name,
    x.tournament_name,
    x.stage_name,
    x.discipline_names,
    x.container_shape,
    x.highest_end_stored,
    NULL AS eligible_count,
    0 AS sort_order
-- The shape is read from which end columns exist, not from how many were scored: a conceded
-- game leaves fewer scored ends without changing what the container was built for, so only
-- the columns say which length was scheduled. Two shapes are legitimate, eight and ten, and
-- the sport is confirmed to play both. A container carrying end_9 but not end_10 is neither:
-- the ninth end of an eight-end game is the extra end, which has its own column, so end_9
-- can only belong to a ten-end game and cannot appear without end_10 beside it.
-- The second branch reads the discipline rather than the shape alone, because ten ends is a
-- perfectly good container - just not for a format played over eight.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        tt.name AS template_name,
        t.name AS tournament_name,
        ts.name AS stage_name,
        (SELECT GROUP_CONCAT(DISTINCT d2.name ORDER BY d2.name SEPARATOR ', ')
           FROM object_discipline od2
           JOIN discipline d2 ON d2.id = od2.disciplineFK AND d2.del = 'no'
          WHERE od2.object_typeFK = 5 AND od2.objectFK = e.id AND od2.del = 'no'
        ) AS discipline_names,
        CASE
            WHEN MAX(CASE WHEN sr.scope_data_typeFK = 291 THEN 1 ELSE 0 END) = 1 THEN '10-end'
            WHEN MAX(CASE WHEN sr.scope_data_typeFK = 290 THEN 1 ELSE 0 END) = 1 THEN '9-end'
            ELSE '8-end'
        END AS container_shape,
        MAX(sr.scope_data_typeFK) AS highest_end_stored,
        MAX(CASE WHEN EXISTS (
                SELECT 1 FROM object_discipline od
                WHERE od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
                  AND od.disciplineFK = 752
            ) THEN 1 ELSE 0 END) AS is_mixed_doubles
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN event_scope es ON es.eventFK = e.id AND es.del = 'no'
                       AND es.scope_typeFK = 305
    JOIN scope_result sr ON sr.event_scopeFK = es.id AND sr.del = 'no'
                        AND sr.scope_data_typeFK BETWEEN 282 AND 291
    WHERE e.del = 'no'
      AND tt.sportFK = 10
      -- AND tt.id = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY e.id, e.name, e.startdate, tt.name, t.name, ts.name
) x
WHERE x.container_shape = '9-end'
   OR (x.container_shape = '10-end' AND x.is_mixed_doubles = 1)

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
JOIN event_scope es ON es.eventFK = e.id AND es.del = 'no'
                   AND es.scope_typeFK = 305
JOIN scope_result sr ON sr.event_scopeFK = es.id AND sr.del = 'no'
                    AND sr.scope_data_typeFK BETWEEN 282 AND 291
WHERE e.del = 'no'
  AND tt.sportFK = 10
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_startdate DESC;


-- ================================================================================
SELECT
    -- CheckID - Curling-DQ-083
    -- Name - COMP.RANK_TEAM_ATHLETE_RANK_DISAGREE
    -- What it does: Finds active tournament-owned Comp.Rank statistics of Curling, excluding IOC-purpose templates, whose team and athlete halves do not agree, either because an athlete is ranked differently from the team the Team data field assigns them to, or because one half of the pair does not exist at all, separating an athlete-side disagreement from a team statistic with no athlete partner and an athlete statistic with no team partner, with the number of disagreeing athletes and a sample of the ranks involved and template and tournament name context, together with a coverage count of all eligible statistics.
    CASE
        WHEN x.kind = 'team' AND x.partner_id IS NULL THEN 'TEAM_STATISTIC_WITHOUT_ATHLETE_PARTNER'
        WHEN x.kind = 'athlete' AND x.partner_id IS NULL THEN 'ATHLETE_STATISTIC_WITHOUT_TEAM_PARTNER'
        ELSE 'ATHLETE_RANK_DISAGREES_WITH_TEAM_RANK'
    END AS check_type,
    x.statistic_id,
    x.statistic_name,
    x.kind,
    x.template_name,
    x.tournament_name,
    x.partner_id,
    x.disagreeing_athletes,
    x.rank_sample,
    NULL AS eligible_count,
    0 AS sort_order
-- The two halves are joined by name, because nothing else joins them: statistic_config
-- records no Event id for this sport, so a Comp.Rank cannot be resolved to what it came
-- from, and the athlete half carries its team only through the Team data field. The naming
-- convention was measured before it was used - it resolves for the large majority of the
-- population, and the statistics it does not resolve for are a finding here rather than a
-- silent gap, which is what keeps the convention honest.
-- A team and the athletes it fields are one placing, so the two halves must agree on it. The
-- comparison is per athlete against their own team, not per statistic, because a statistic
-- can be right about most of its teams and wrong about one.
FROM (
    SELECT
        s.id AS statistic_id,
        s.name AS statistic_name,
        CASE WHEN s.name LIKE '%(athletes)%' THEN 'athlete' ELSE 'team' END AS kind,
        tt.name AS template_name,
        t.name AS tournament_name,
        pr.partner_id,
        COALESCE(dg.disagreeing_athletes, 0) AS disagreeing_athletes,
        dg.rank_sample
    FROM statistic s
    JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    LEFT JOIN (
        SELECT
            sa.id AS statistic_id,
            MIN(sb.id) AS partner_id
        FROM statistic sa
        JOIN tournament ta ON ta.id = sa.objectFK AND ta.del = 'no'
        JOIN tournament_template tta ON tta.id = ta.tournament_templateFK AND tta.del = 'no'
        JOIN statistic sb ON sb.objectFK = sa.objectFK AND sb.del = 'no'
             AND sb.statistic_typeFK = 11 AND sb.object_typeFK = 3
             AND TRIM(sb.name) = CASE
                 WHEN sa.name LIKE '%(athletes)%' THEN TRIM(REPLACE(sa.name, ' (athletes)', ''))
                 ELSE CONCAT(TRIM(sa.name), ' (athletes)')
             END
        WHERE sa.del = 'no'
          AND sa.statistic_typeFK = 11
          AND sa.object_typeFK = 3
          AND tta.sportFK = 10
        GROUP BY sa.id
    ) pr ON pr.statistic_id = s.id
    LEFT JOIN (
        SELECT
            teamst.statistic_id,
            COUNT(*) AS disagreeing_athletes,
            SUBSTRING(GROUP_CONCAT(DISTINCT CONCAT('team ', teamst.team_rank, ' vs athlete ', athst.athlete_rank)
                                   ORDER BY teamst.team_rank SEPARATOR ', '), 1, 200) AS rank_sample
        FROM (
            SELECT
                sp.statisticFK AS statistic_id,
                sp.participantFK AS team_participant_id,
                CAST(TRIM(sd.value) AS SIGNED) AS team_rank
            FROM statistic s2
            JOIN tournament t2 ON t2.id = s2.objectFK AND t2.del = 'no'
            JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
            JOIN statistic_participants11 sp ON sp.statisticFK = s2.id AND sp.del = 'no'
            JOIN statistic_data11 sd ON sd.statistic_participants11FK = sp.id
                 AND sd.statistic_data_typeFK = 1270 AND sd.del = 'no'
                 AND TRIM(sd.value) REGEXP '^[1-9][0-9]*$'
            WHERE s2.del = 'no' AND s2.statistic_typeFK = 11 AND s2.object_typeFK = 3
              AND tt2.sportFK = 10
              AND s2.name NOT LIKE '%(athletes)%'
        ) teamst
        JOIN (
            SELECT
                sa2.id AS athlete_statistic_id,
                sa2.objectFK AS tournament_id,
                TRIM(REPLACE(sa2.name, ' (athletes)', '')) AS partner_name,
                CAST(TRIM(sdteam.value) AS SIGNED) AS team_participant_id,
                CAST(TRIM(sdrank.value) AS SIGNED) AS athlete_rank
            FROM statistic sa2
            JOIN tournament t3 ON t3.id = sa2.objectFK AND t3.del = 'no'
            JOIN tournament_template tt3 ON tt3.id = t3.tournament_templateFK AND tt3.del = 'no'
            JOIN statistic_participants11 spa ON spa.statisticFK = sa2.id AND spa.del = 'no'
            JOIN statistic_data11 sdteam ON sdteam.statistic_participants11FK = spa.id
                 AND sdteam.statistic_data_typeFK = 1429 AND sdteam.del = 'no'
                 AND TRIM(sdteam.value) REGEXP '^[1-9][0-9]*$'
            JOIN statistic_data11 sdrank ON sdrank.statistic_participants11FK = spa.id
                 AND sdrank.statistic_data_typeFK = 1270 AND sdrank.del = 'no'
                 AND TRIM(sdrank.value) REGEXP '^[1-9][0-9]*$'
            WHERE sa2.del = 'no' AND sa2.statistic_typeFK = 11 AND sa2.object_typeFK = 3
              AND tt3.sportFK = 10
              AND sa2.name LIKE '%(athletes)%'
        ) athst ON athst.team_participant_id = teamst.team_participant_id
               AND athst.athlete_rank <> teamst.team_rank
               AND athst.tournament_id = (SELECT s4.objectFK FROM statistic s4 WHERE s4.id = teamst.statistic_id)
               AND athst.partner_name = (SELECT TRIM(s5.name) FROM statistic s5 WHERE s5.id = teamst.statistic_id)
        GROUP BY teamst.statistic_id
    ) dg ON dg.statistic_id = s.id
    WHERE s.del = 'no'
      AND s.statistic_typeFK = 11
      AND s.object_typeFK = 3
      AND tt.sportFK = 10
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      -- AND tt.id = <tournament_template_id>
) x
WHERE x.partner_id IS NULL
   OR x.disagreeing_athletes > 0

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count,
    1 AS sort_order
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = 11
  AND s.object_typeFK = 3
  AND tt.sportFK = 10
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>

ORDER BY sort_order;


-- ================================================================================
SELECT
    -- CheckID - Curling-DQ-084
    -- Name - EVENT_DUPLICATE_BY_RESULT_ACROSS_DATES
    -- What it does: Finds groups of more than one active Curling event inside one tournament stage that record the identical result - the same two teams holding the same score each - while sitting on different calendar days, so the same game appears twice under dates that keep it out of the metadata duplicate check, with the scores, the dates and names the group carries and how many events it holds, together with a coverage count of all eligible active events holding exactly two participants with a numeric Final Result.
    'DUPLICATE_BY_RESULT_ACROSS_DATES' AS check_type,
    d.template_name,
    d.tournament_name,
    d.stage_id AS tournament_stage_id,
    d.stage_name,
    GROUP_CONCAT(DISTINCT d.event_name ORDER BY d.event_name SEPARATOR ' | ') AS event_names,
    GROUP_CONCAT(DISTINCT DATE(d.startdate) ORDER BY DATE(d.startdate) SEPARATOR ', ') AS event_dates,
    d.score_key,
    COUNT(*) AS duplicate_event_count,
    GROUP_CONCAT(d.event_id ORDER BY d.event_id) AS event_ids,
    NULL AS eligible_count,
    0 AS sort_order
-- The key is the result itself, tied to the side that holds it: a participant id joined to
-- its own score, ordered by participant so the pairing reads the same whichever side was
-- entered first. That is what makes the check safe where a plain participant key is not - a
-- double round robin has the same two teams meeting twice inside one stage by design, and
-- only the scores separate a second meeting from a second copy. Two curling games between
-- one pair ending on the same score each way is possible; it is rare enough to be worth
-- reading, and the row carries the scores so the reader decides.
-- Restricted to groups spanning more than one calendar day, because a group inside one day
-- is already GLOBAL-DQ-062 and would otherwise be reported twice under two names. The stage
-- bounds the group so a preliminary meeting and a play-off meeting are never compared.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate,
        ts.id AS stage_id,
        ts.name AS stage_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        GROUP_CONCAT(CONCAT(ep.participantFK, '=', TRIM(r.value))
                     ORDER BY ep.participantFK SEPARATOR '; ') AS score_key
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
                 AND r.result_typeFK = 4
                 AND r.value IS NOT NULL
                 AND TRIM(r.value) REGEXP '^-?[0-9]+$'
    WHERE e.del = 'no'
      AND tt.sportFK = 10
      AND e.startdate IS NOT NULL
      -- AND tt.id = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY e.id, e.name, e.startdate, ts.id, ts.name, tt.name, t.name
    HAVING COUNT(*) = 2
) d
GROUP BY d.template_name, d.tournament_name, d.stage_id, d.stage_name, d.score_key
HAVING COUNT(*) > 1
   AND COUNT(DISTINCT DATE(d.startdate)) > 1

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(*) AS eligible_count,
    1 AS sort_order
FROM (
    SELECT e.id
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
                 AND r.result_typeFK = 4
                 AND r.value IS NOT NULL
                 AND TRIM(r.value) REGEXP '^-?[0-9]+$'
    WHERE e.del = 'no'
      AND tt.sportFK = 10
      AND e.startdate IS NOT NULL
      -- AND tt.id = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY e.id
    HAVING COUNT(*) = 2
) c

ORDER BY sort_order, duplicate_event_count DESC;
