SELECT
    -- CheckID - GLOBAL-DQ-007
    -- Name - PARTICIPANT_MISSING_DATE_OF_BIRTH
    -- What it does: Finds active participants of the selected types that take part in at least one active event of the sport but have no active, non-empty date_of_birth property value, with their participation count and the count of participations carrying at least one active result, together with a coverage count of all eligible participants.
    'Missing_DOB' AS check_type,
    p.id AS participant_id,
    p.name AS participant_name,
    p.type AS participant_type,
    (
        SELECT COUNT(DISTINCT ep2.id)
        FROM event_participants ep2
        JOIN event e2 ON e2.id = ep2.eventFK AND e2.del = 'no'
        JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
        JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
        JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
        WHERE ep2.participantFK = p.id
          AND ep2.del = 'no'
          AND tt2.sportFK = {{SPORT_ID}}
    ) AS participation_count,
    (
        SELECT COUNT(DISTINCT ep3.id)
        FROM event_participants ep3
        JOIN event e3 ON e3.id = ep3.eventFK AND e3.del = 'no'
        JOIN tournament_stage ts3 ON ts3.id = e3.tournament_stageFK AND ts3.del = 'no'
        JOIN tournament t3 ON t3.id = ts3.tournamentFK AND t3.del = 'no'
        JOIN tournament_template tt3 ON tt3.id = t3.tournament_templateFK AND tt3.del = 'no'
        WHERE ep3.participantFK = p.id
          AND ep3.del = 'no'
          AND tt3.sportFK = {{SPORT_ID}}
          AND EXISTS (
              SELECT 1
              FROM result r3
              WHERE r3.event_participantsFK = ep3.id
                AND r3.del = 'no'
                AND r3.value IS NOT NULL
                AND TRIM(r3.value) <> ''
          )
    ) AS participations_with_any_result,
    NULL AS eligible_count
FROM participant p
WHERE p.del = 'no'
  AND p.type IN ({{EVENT_PARTICIPANT_TYPE_LIST}})
  -- AND p.id BETWEEN <from_participant_id> AND <to_participant_id>
  AND EXISTS (
      SELECT 1
      FROM event_participants ep
      JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
      JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
      JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
      JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
      WHERE ep.participantFK = p.id
        AND ep.del = 'no'
        AND tt.sportFK = {{SPORT_ID}}
        -- AND tt.id = <tournament_template_id>
  )
  AND NOT EXISTS (
      SELECT 1
      FROM property pr
      WHERE pr.object = 'participant'
        AND pr.objectFK = p.id
        AND pr.name = 'date_of_birth'
        AND pr.del = 'no'
        AND pr.value IS NOT NULL
        AND TRIM(pr.value) <> ''
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    COUNT(DISTINCT p.id) AS eligible_count
FROM participant p
WHERE p.del = 'no'
  AND p.type IN ({{EVENT_PARTICIPANT_TYPE_LIST}})
  -- AND p.id BETWEEN <from_participant_id> AND <to_participant_id>
  AND EXISTS (
      SELECT 1
      FROM event_participants ep
      JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
      JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
      JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
      JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
      WHERE ep.participantFK = p.id
        AND ep.del = 'no'
        AND tt.sportFK = {{SPORT_ID}}
        -- AND tt.id = <tournament_template_id>
  );


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-008
    -- Name - PARTICIPANT_MISSING_PROFILE_FIELDS
    -- What it does: Finds active participants of the selected types that take part in at least one active event of the sport and are missing name, country, first_name and/or last_name, together with a coverage count of all eligible participants.
    'Missing_Profile_Field' AS check_type,
    p.id AS participant_id,
    p.name AS participant_name,
    p.type AS participant_type,
    CONCAT_WS(', ',
        IF(p.name IS NULL OR TRIM(p.name) = '', 'name', NULL),
        IF(NOT EXISTS (
            SELECT 1
            FROM country c
            WHERE c.id = p.countryFK
              AND c.del = 'no'
        ), 'country', NULL),
        IF(NOT EXISTS (
            SELECT 1
            FROM language fn
            WHERE fn.object = 'participant'
              AND fn.objectFK = p.id
              AND fn.language_typeFK = 7
              AND fn.del = 'no'
              AND fn.name IS NOT NULL
              AND TRIM(fn.name) <> ''
        ), 'first_name', NULL),
        IF(NOT EXISTS (
            SELECT 1
            FROM language ln
            WHERE ln.object = 'participant'
              AND ln.objectFK = p.id
              AND ln.language_typeFK = 8
              AND ln.del = 'no'
              AND ln.name IS NOT NULL
              AND TRIM(ln.name) <> ''
        ), 'last_name', NULL)
    ) AS missing_fields,
    NULL AS eligible_count
FROM participant p
WHERE p.del = 'no'
  AND p.type IN ({{EVENT_PARTICIPANT_TYPE_LIST}})
  -- AND p.id BETWEEN <from_participant_id> AND <to_participant_id>
  AND EXISTS (
      SELECT 1
      FROM event_participants ep
      JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
      JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
      JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
      JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
      WHERE ep.participantFK = p.id
        AND ep.del = 'no'
        AND tt.sportFK = {{SPORT_ID}}
        -- AND tt.id = <tournament_template_id>
  )
  AND (
      p.name IS NULL
      OR TRIM(p.name) = ''
      OR NOT EXISTS (
          SELECT 1
          FROM country c
          WHERE c.id = p.countryFK
            AND c.del = 'no'
      )
      OR NOT EXISTS (
          SELECT 1
          FROM language fn
          WHERE fn.object = 'participant'
            AND fn.objectFK = p.id
            AND fn.language_typeFK = 7
            AND fn.del = 'no'
            AND fn.name IS NOT NULL
            AND TRIM(fn.name) <> ''
      )
      OR NOT EXISTS (
          SELECT 1
          FROM language ln
          WHERE ln.object = 'participant'
            AND ln.objectFK = p.id
            AND ln.language_typeFK = 8
            AND ln.del = 'no'
            AND ln.name IS NOT NULL
            AND TRIM(ln.name) <> ''
      )
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL,
    NULL,
    NULL,
    NULL,
    COUNT(DISTINCT p.id) AS eligible_count
FROM participant p
WHERE p.del = 'no'
  AND p.type IN ({{EVENT_PARTICIPANT_TYPE_LIST}})
  -- AND p.id BETWEEN <from_participant_id> AND <to_participant_id>
  AND EXISTS (
      SELECT 1
      FROM event_participants ep
      JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
      JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
      JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
      JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
      WHERE ep.participantFK = p.id
        AND ep.del = 'no'
        AND tt.sportFK = {{SPORT_ID}}
        -- AND tt.id = <tournament_template_id>
  );


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-009
    -- Name - PARTICIPANT_NO_EVENT_PARTICIPATION
    -- What it does: Finds active participants of the selected types linked through active sport-registry rows but having zero active event_participants rows within the sport, together with a coverage count of the same registered population.
    'No_Event_Participation' AS check_type,
    p.id AS participant_id,
    p.name AS participant_name,
    p.type AS participant_type,
    op.active AS registry_active_flag,
    NULL AS eligible_count
FROM object_participants op
JOIN participant p
  ON p.id = op.participantFK
 AND p.del = 'no'
WHERE op.object = 'sport'
  AND op.del = 'no'
  AND op.objectFK = {{SPORT_ID}}
  AND p.type IN ({{REGISTRY_PARTICIPANT_TYPE_LIST}})
  -- AND p.id BETWEEN <from_participant_id> AND <to_participant_id>
  AND NOT EXISTS (
      SELECT 1
      FROM event_participants ep
      JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
      JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
      JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
      JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
      WHERE ep.participantFK = p.id
        AND ep.del = 'no'
        AND tt.sportFK = {{SPORT_ID}}
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL,
    NULL,
    NULL,
    NULL,
    COUNT(DISTINCT p.id) AS eligible_count
FROM object_participants op
JOIN participant p
  ON p.id = op.participantFK
 AND p.del = 'no'
WHERE op.object = 'sport'
  AND op.del = 'no'
  AND op.objectFK = {{SPORT_ID}}
  AND p.type IN ({{REGISTRY_PARTICIPANT_TYPE_LIST}})
  -- AND p.id BETWEEN <from_participant_id> AND <to_participant_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-043
    -- Name - EVENT_PARTICIPANTS_GENDER_MISMATCH
    -- What it does: Finds active event-participant rows whose gender contradicts the parent tournament stage or their own lineup: an athlete whose gender differs from a single-gender stage, a participant whose own gender differs from the stage gender, a mixed team whose lineup does not contain both male and female members, or a single-gender team whose lineup contains a member of the other gender, with stage, event and participant context and the lineup gender counts, together with a coverage count of all eligible event-participants in stages carrying a usable gender.
    CASE
        WHEN x.participant_type = 'athlete' AND x.stage_gender <> 'mixed'
             AND x.participant_gender IS NOT NULL AND x.participant_gender <> ''
             AND x.participant_gender <> x.stage_gender
            THEN 'ATHLETE_GENDER_NOT_STAGE_GENDER'
        WHEN x.participant_type = 'team'
             AND x.participant_gender IS NOT NULL AND x.participant_gender <> ''
             AND x.participant_gender <> x.stage_gender
            THEN 'TEAM_GENDER_NOT_STAGE_GENDER'
        WHEN x.participant_type = 'team' AND x.participant_gender = 'mixed'
             AND x.lineup_rows > 0 AND (x.lineup_male = 0 OR x.lineup_female = 0)
            THEN 'MIXED_TEAM_LINEUP_MISSING_A_GENDER'
        WHEN x.participant_type = 'team' AND x.participant_gender = 'male'
             AND x.lineup_rows > 0 AND x.lineup_female > 0
            THEN 'SINGLE_GENDER_TEAM_LINEUP_HAS_OTHER_GENDER'
        WHEN x.participant_type = 'team' AND x.participant_gender = 'female'
             AND x.lineup_rows > 0 AND x.lineup_male > 0
            THEN 'SINGLE_GENDER_TEAM_LINEUP_HAS_OTHER_GENDER'
    END AS check_type,
    x.event_participants_id,
    x.event_id,
    x.event_name,
    x.stage_name,
    x.stage_gender,
    x.participant_type,
    x.participant_name,
    x.participant_gender,
    x.lineup_male,
    x.lineup_female,
    NULL AS eligible_count
FROM (
    SELECT
        ep.id AS event_participants_id,
        e.id AS event_id,
        e.name AS event_name,
        ts.name AS stage_name,
        LOWER(TRIM(ts.gender)) AS stage_gender,
        p.name AS participant_name,
        p.type AS participant_type,
        LOWER(TRIM(p.gender)) AS participant_gender,
        COUNT(l.id) AS lineup_rows,
        SUM(CASE WHEN LOWER(TRIM(lp.gender)) = 'male' THEN 1 ELSE 0 END) AS lineup_male,
        SUM(CASE WHEN LOWER(TRIM(lp.gender)) = 'female' THEN 1 ELSE 0 END) AS lineup_female
    FROM event_participants ep
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
    JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    LEFT JOIN lineup l ON l.event_participantsFK = ep.id AND l.del = 'no'
    LEFT JOIN participant lp ON lp.id = l.participantFK AND lp.del = 'no'
    WHERE ep.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      AND ts.gender IS NOT NULL
      AND TRIM(ts.gender) <> ''
      AND LOWER(TRIM(ts.gender)) <> 'undefined'
      -- AND tt.id = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY ep.id, e.id, e.name, ts.name, ts.gender, p.name, p.type, p.gender
) x
WHERE
    (x.participant_type = 'athlete' AND x.stage_gender <> 'mixed'
     AND x.participant_gender IS NOT NULL AND x.participant_gender <> ''
     AND x.participant_gender <> x.stage_gender)
    OR (x.participant_type = 'team'
     AND x.participant_gender IS NOT NULL AND x.participant_gender <> ''
     AND x.participant_gender <> x.stage_gender)
    OR (x.participant_type = 'team' AND x.participant_gender = 'mixed'
     AND x.lineup_rows > 0 AND (x.lineup_male = 0 OR x.lineup_female = 0))
    OR (x.participant_type = 'team' AND x.participant_gender = 'male'
     AND x.lineup_rows > 0 AND x.lineup_female > 0)
    OR (x.participant_type = 'team' AND x.participant_gender = 'female'
     AND x.lineup_rows > 0 AND x.lineup_male > 0)

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ep.id) AS eligible_count
FROM event_participants ep
JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE ep.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND ts.gender IS NOT NULL
  AND TRIM(ts.gender) <> ''
  AND LOWER(TRIM(ts.gender)) <> 'undefined'
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-058
    -- Name - EVENT_TEAM_PARTICIPANT_WITHOUT_LINEUP
    -- What it does: Finds active events holding at least one team event participant where the lineup layer is missing, separating an event in which no team resolves to any lineup member from one in which some teams do and others do not, with the number of teams on each side, together with a coverage count of all eligible events holding at least one active team event participant.
    CASE
        WHEN x.teams_with_lineup = 0 THEN 'EVENT_NO_TEAM_HAS_LINEUP'
        ELSE 'EVENT_SOME_TEAMS_MISSING_LINEUP'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.tournament_template_name,
    x.team_count,
    x.teams_with_lineup,
    x.team_count - x.teams_with_lineup AS teams_without_lineup,
    x.teams_missing_lineup_names,
    NULL AS eligible_count
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        tt.name AS tournament_template_name,
        COUNT(DISTINCT ep.id) AS team_count,
        COUNT(DISTINCT CASE WHEN l.id IS NOT NULL THEN ep.id END) AS teams_with_lineup,
        GROUP_CONCAT(DISTINCT CASE WHEN l.id IS NULL THEN p.name END
                     ORDER BY 1 SEPARATOR ', ') AS teams_missing_lineup_names
    FROM event_participants ep
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
    JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    LEFT JOIN lineup l ON l.event_participantsFK = ep.id AND l.del = 'no'
    WHERE ep.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      AND p.type = 'team'
      -- AND tt.id = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY e.id, e.name, tt.name
) x
WHERE x.teams_with_lineup < x.team_count

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count
FROM event_participants ep
JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE ep.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND p.type = 'team'
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-067
    -- Name - EVENT_MIXED_TEAM_LINEUP_GENDER_BALANCE_UNEVEN
    -- What it does: Finds active event-participant rows of mixed-gender teams whose lineup holds both male and female members in unequal numbers, with event, stage and participant context and the lineup gender counts, together with a coverage count of all eligible event-participants of mixed-gender teams whose lineup holds at least one member of each gender.
    'MIXED_TEAM_LINEUP_GENDER_COUNT_UNEVEN' AS check_type,
    x.event_participants_id,
    x.event_id,
    x.event_name,
    x.stage_name,
    x.participant_name,
    x.lineup_rows,
    x.lineup_male,
    x.lineup_female,
    x.lineup_unusable_gender,
    ABS(x.lineup_male - x.lineup_female) AS gender_gap,
    NULL AS eligible_count
FROM (
    SELECT
        ep.id AS event_participants_id,
        e.id AS event_id,
        e.name AS event_name,
        ts.name AS stage_name,
        p.name AS participant_name,
        COUNT(l.id) AS lineup_rows,
        SUM(CASE WHEN LOWER(TRIM(lp.gender)) = 'male' THEN 1 ELSE 0 END) AS lineup_male,
        SUM(CASE WHEN LOWER(TRIM(lp.gender)) = 'female' THEN 1 ELSE 0 END) AS lineup_female,
        SUM(CASE WHEN lp.gender IS NULL
                   OR LOWER(TRIM(lp.gender)) NOT IN ('male', 'female') THEN 1 ELSE 0 END) AS lineup_unusable_gender
    FROM event_participants ep
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
         AND p.type = 'team' AND LOWER(TRIM(p.gender)) = 'mixed'
    JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN lineup l ON l.event_participantsFK = ep.id AND l.del = 'no'
    JOIN participant lp ON lp.id = l.participantFK AND lp.del = 'no'
    WHERE ep.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      -- AND tt.id = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY ep.id, e.id, e.name, ts.name, p.name
) x
WHERE x.lineup_male > 0
  AND x.lineup_female > 0
  AND x.lineup_male <> x.lineup_female

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT y.event_participants_id) AS eligible_count
FROM (
    SELECT
        ep.id AS event_participants_id,
        SUM(CASE WHEN LOWER(TRIM(lp.gender)) = 'male' THEN 1 ELSE 0 END) AS lineup_male,
        SUM(CASE WHEN LOWER(TRIM(lp.gender)) = 'female' THEN 1 ELSE 0 END) AS lineup_female
    FROM event_participants ep
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
         AND p.type = 'team' AND LOWER(TRIM(p.gender)) = 'mixed'
    JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN lineup l ON l.event_participantsFK = ep.id AND l.del = 'no'
    JOIN participant lp ON lp.id = l.participantFK AND lp.del = 'no'
    WHERE ep.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      -- AND tt.id = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY ep.id
) y
WHERE y.lineup_male > 0
  AND y.lineup_female > 0
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-068
    -- Name - EVENT_TEAM_LINEUP_SIZE_UNEVEN
    -- What it does: Finds active events in which the team event participants that resolve to a lineup do not all field the same number of members, so one team enters fewer competitors than another inside the same event, separating a shortfall of one member from a larger one, with the smallest and largest lineup, the number of teams measured and the per-team breakdown, together with a coverage count of all eligible events holding at least two team event participants that each resolve to at least one active lineup member.
    CASE
        WHEN x.max_size - x.min_size = 1 THEN 'EVENT_TEAM_LINEUP_SIZE_SHORT_BY_ONE'
        ELSE 'EVENT_TEAM_LINEUP_SIZE_SHORT_BY_MORE'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.stage_name,
    x.tournament_template_name,
    x.teams_measured,
    x.min_size,
    x.max_size,
    x.team_breakdown,
    NULL AS eligible_count,
    0 AS sort_order
FROM (
    SELECT
        b.event_id,
        b.event_name,
        b.stage_name,
        b.tournament_template_name,
        COUNT(*) AS teams_measured,
        MIN(b.lineup_rows) AS min_size,
        MAX(b.lineup_rows) AS max_size,
        GROUP_CONCAT(CONCAT(b.participant_name, '=', b.lineup_rows)
                     ORDER BY b.lineup_rows, b.participant_name SEPARATOR ' | ') AS team_breakdown
    FROM (
        SELECT
            e.id AS event_id,
            e.name AS event_name,
            ts.name AS stage_name,
            tt.name AS tournament_template_name,
            p.name AS participant_name,
            COUNT(l.id) AS lineup_rows
        FROM event_participants ep
        JOIN participant p ON p.id = ep.participantFK AND p.del = 'no' AND p.type = 'team'
        JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
        JOIN lineup l ON l.event_participantsFK = ep.id AND l.del = 'no'
        WHERE ep.del = 'no'
          AND tt.sportFK = {{SPORT_ID}}
          -- AND tt.id = <tournament_template_id>
          -- AND e.startdate >= '<from_datetime>'
          -- AND e.startdate <  '<to_datetime>'
        GROUP BY ep.id, e.id, e.name, ts.name, tt.name, p.name
    ) b
    GROUP BY b.event_id, b.event_name, b.stage_name, b.tournament_template_name
) x
WHERE x.teams_measured > 1
  AND x.max_size > x.min_size

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT y.event_id) AS eligible_count,
    1 AS sort_order
FROM (
    SELECT
        c.event_id,
        COUNT(*) AS teams_measured
    FROM (
        SELECT
            e.id AS event_id,
            ep.id AS event_participants_id
        FROM event_participants ep
        JOIN participant p ON p.id = ep.participantFK AND p.del = 'no' AND p.type = 'team'
        JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
        JOIN lineup l ON l.event_participantsFK = ep.id AND l.del = 'no'
        WHERE ep.del = 'no'
          AND tt.sportFK = {{SPORT_ID}}
          -- AND tt.id = <tournament_template_id>
          -- AND e.startdate >= '<from_datetime>'
          -- AND e.startdate <  '<to_datetime>'
        GROUP BY e.id, ep.id
    ) c
    GROUP BY c.event_id
) y
WHERE y.teams_measured > 1

ORDER BY sort_order, event_id;
