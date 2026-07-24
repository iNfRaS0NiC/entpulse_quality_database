SELECT
    -- CheckID - BMX-DQ-001
    -- Name - PARTICIPANT_MISSING_DATE_OF_BIRTH
    -- What it does: Finds active BMX athlete participants without an active, non-empty date_of_birth property value, together with their BMX participation count, count of participations having at least one active event result, count of active Comp.Rank statistic data rows, and a coverage count of all eligible BMX athletes.
    'Missing_DOB' AS check_type,
    p.id AS participant_id,
    p.name AS participant_name,
    (
        SELECT COUNT(*)
        FROM event_participants ep2
        JOIN event e2 ON e2.id = ep2.eventFK AND e2.del = 'no'
        JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
        JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
        JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
        WHERE ep2.participantFK = p.id
          AND ep2.del = 'no'
          AND tt2.sportFK = 58
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
          AND tt3.sportFK = 58
          AND EXISTS (
              SELECT 1
              FROM result r3
              WHERE r3.event_participantsFK = ep3.id
                AND r3.del = 'no'
                AND r3.value IS NOT NULL
                AND TRIM(r3.value) <> ''
          )
    ) AS participations_with_any_result,
    (
        SELECT COUNT(*)
        FROM statistic_data11 sd4
        JOIN statistic_participants11 sp4
          ON sp4.id = sd4.statistic_participants11FK
         AND sp4.del = 'no'
        JOIN statistic s4 ON s4.id = sp4.statisticFK AND s4.del = 'no'
        JOIN tournament t4
          ON t4.id = s4.objectFK
         AND s4.object_typeFK = 3
         AND t4.del = 'no'
        JOIN tournament_template tt4
          ON tt4.id = t4.tournament_templateFK
         AND tt4.del = 'no'
        WHERE sp4.participantFK = p.id
          AND sd4.del = 'no'
          AND sd4.value IS NOT NULL
          AND TRIM(sd4.value) <> ''
          AND s4.statistic_typeFK = 11
          AND tt4.sportFK = 58
    ) AS statistic_results_count,
    NULL AS eligible_count
FROM participant p
WHERE p.del = 'no'
  AND p.type = 'athlete'
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
        AND tt.sportFK = 58
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
  AND p.type = 'athlete'
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
        AND tt.sportFK = 58
        -- AND tt.id = <tournament_template_id>
  );


-- ================================================================================
SELECT
    -- CheckID - BMX-DQ-002
    -- Name - PARTICIPANT_MISSING_PROFILE_FIELDS
    -- What it does: Finds active BMX athlete participants missing name, country, first_name and/or last_name, together with a coverage count of all eligible BMX athletes.
    'Missing_Profile_Field' AS check_type,
    p.id AS participant_id,
    p.name AS participant_name,
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
  AND p.type = 'athlete'
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
        AND tt.sportFK = 58
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
    COUNT(DISTINCT p.id) AS eligible_count
FROM participant p
WHERE p.del = 'no'
  AND p.type = 'athlete'
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
        AND tt.sportFK = 58
        -- AND tt.id = <tournament_template_id>
  );


-- ================================================================================
SELECT
    -- CheckID - BMX-DQ-003
    -- Name - PARTICIPANT_NO_EVENT_PARTICIPATION
    -- What it does: Finds active athlete and team participant records linked through non-deleted BMX sport-registry rows but having zero active event_participants rows within BMX, together with a coverage count of the same registered population.
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
  AND op.objectFK = 58
  AND p.type IN ('athlete', 'team')
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
        AND tt.sportFK = 58
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
  AND op.objectFK = 58
  AND p.type IN ('athlete', 'team')
  -- AND p.id BETWEEN <from_participant_id> AND <to_participant_id>
;


-- ================================================================================
SELECT
    -- CheckID - BMX-DQ-004
    -- Name - TOURNAMENT_STAGE_MISSING_AGE_CLASS
    -- What it does: Finds active BMX tournament stages without an active tournament_age_class relation via object_relation, together with a coverage count of all eligible BMX stages.
    'Missing_Age_Class' AS check_type,
    ts.id AS tournament_stage_id,
    ts.name AS tournament_stage_name,
    NULL AS eligible_count
FROM tournament_stage ts
JOIN tournament t
  ON t.id = ts.tournamentFK
 AND t.del = 'no'
JOIN tournament_template tt
  ON tt.id = t.tournament_templateFK
 AND tt.del = 'no'
WHERE ts.del = 'no'
  AND tt.sportFK = 58
  -- AND tt.id = <tournament_template_id>
  AND NOT EXISTS (
      SELECT 1
      FROM object_relation orl
      WHERE orl.object_typeFK = 4
        AND orl.objectFK = ts.id
        AND orl.rel_object_typeFK = 151
        AND orl.del = 'no'
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL,
    NULL,
    COUNT(DISTINCT ts.id) AS eligible_count
FROM tournament_stage ts
JOIN tournament t
  ON t.id = ts.tournamentFK
 AND t.del = 'no'
JOIN tournament_template tt
  ON tt.id = t.tournament_templateFK
 AND tt.del = 'no'
WHERE ts.del = 'no'
  AND tt.sportFK = 58
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - BMX-DQ-005
    -- Name - TOURNAMENT_STAGE_NO_EVENTS
    -- What it does: Finds active BMX tournament stages with zero active events, together with a coverage count of all eligible BMX stages.
    'No_Events' AS check_type,
    ts.id AS tournament_stage_id,
    ts.name AS tournament_stage_name,
    NULL AS eligible_count
FROM tournament_stage ts
JOIN tournament t
  ON t.id = ts.tournamentFK
 AND t.del = 'no'
JOIN tournament_template tt
  ON tt.id = t.tournament_templateFK
 AND tt.del = 'no'
WHERE ts.del = 'no'
  AND tt.sportFK = 58
  -- AND tt.id = <tournament_template_id>
  AND NOT EXISTS (
      SELECT 1
      FROM event e
      WHERE e.tournament_stageFK = ts.id
        AND e.del = 'no'
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL,
    NULL,
    COUNT(DISTINCT ts.id) AS eligible_count
FROM tournament_stage ts
JOIN tournament t
  ON t.id = ts.tournamentFK
 AND t.del = 'no'
JOIN tournament_template tt
  ON tt.id = t.tournament_templateFK
 AND tt.del = 'no'
WHERE ts.del = 'no'
  AND tt.sportFK = 58
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - BMX-DQ-006
    -- Name - TOURNAMENT_STAGE_DATE_RANGE_MISMATCH
    -- What it does: Finds active BMX tournament stages whose start or end date does not match the earliest and latest active event start date within the stage, together with a coverage count of all eligible BMX stages with at least one event.
    'Date_Range_Mismatch' AS check_type,
    ts.id AS tournament_stage_id,
    ts.name AS tournament_stage_name,
    ts.startdate AS stage_startdate,
    ts.enddate AS stage_enddate,
    MIN(e.startdate) AS earliest_event_startdate,
    MAX(e.startdate) AS latest_event_startdate,
    NULL AS eligible_count
FROM tournament_stage ts
JOIN tournament t
  ON t.id = ts.tournamentFK
 AND t.del = 'no'
JOIN tournament_template tt
  ON tt.id = t.tournament_templateFK
 AND tt.del = 'no'
JOIN event e
  ON e.tournament_stageFK = ts.id
 AND e.del = 'no'
WHERE ts.del = 'no'
  AND tt.sportFK = 58
  -- AND tt.id = <tournament_template_id>
GROUP BY
    ts.id,
    ts.name,
    ts.startdate,
    ts.enddate
HAVING DATE(ts.startdate) <> DATE(MIN(e.startdate))
    OR DATE(ts.enddate) <> DATE(MAX(e.startdate))

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    COUNT(DISTINCT ts.id) AS eligible_count
FROM tournament_stage ts
JOIN tournament t
  ON t.id = ts.tournamentFK
 AND t.del = 'no'
JOIN tournament_template tt
  ON tt.id = t.tournament_templateFK
 AND tt.del = 'no'
WHERE ts.del = 'no'
  AND tt.sportFK = 58
  -- AND tt.id = <tournament_template_id>
  AND EXISTS (
      SELECT 1
      FROM event e2
      WHERE e2.tournament_stageFK = ts.id
        AND e2.del = 'no'
  );


-- ================================================================================
SELECT
    -- CheckID - BMX-DQ-007
    -- Name - TOURNAMENT_STAGE_MISSING_START_OR_END_DATE
    -- What it does: Finds active BMX tournament stages with a NULL start date or end date, together with a coverage count of all eligible BMX stages.
    'Missing_Start_Or_End_Date' AS check_type,
    ts.id AS tournament_stage_id,
    ts.name AS tournament_stage_name,
    CONCAT_WS(', ',
        IF(ts.startdate IS NULL, 'startdate', NULL),
        IF(ts.enddate IS NULL, 'enddate', NULL)
    ) AS missing_fields,
    NULL AS eligible_count
FROM tournament_stage ts
JOIN tournament t
  ON t.id = ts.tournamentFK
 AND t.del = 'no'
JOIN tournament_template tt
  ON tt.id = t.tournament_templateFK
 AND tt.del = 'no'
WHERE ts.del = 'no'
  AND tt.sportFK = 58
  -- AND tt.id = <tournament_template_id>
  AND (ts.startdate IS NULL OR ts.enddate IS NULL)

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL,
    NULL,
    NULL,
    COUNT(DISTINCT ts.id) AS eligible_count
FROM tournament_stage ts
JOIN tournament t
  ON t.id = ts.tournamentFK
 AND t.del = 'no'
JOIN tournament_template tt
  ON tt.id = t.tournament_templateFK
 AND tt.del = 'no'
WHERE ts.del = 'no'
  AND tt.sportFK = 58
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - BMX-DQ-008
    -- Name - TEMPLATE_MISSING_SET_SUBSET_GENDER_NAME
    -- What it does: Finds active BMX tournament templates, excluding IOC-purpose templates, missing name, gender, an active subset relation, or a resolvable tournament set, together with a coverage count of all eligible BMX templates.
    'Missing_Template_Field' AS check_type,
    tt.id AS tournament_template_id,
    tt.name AS tournament_template_name,
    CONCAT_WS(', ',
        IF(tt.name IS NULL OR TRIM(tt.name) = '', 'name', NULL),
        IF(
            tt.gender IS NULL
            OR TRIM(tt.gender) = ''
            OR LOWER(TRIM(tt.gender)) = 'undefined',
            'gender',
            NULL
        ),
        IF(NOT EXISTS (
            SELECT 1
            FROM object_relation orl
            JOIN tournament_sub_set sub
              ON sub.id = orl.rel_objectFK
             AND sub.del = 'no'
            WHERE orl.object_typeFK = 2
              AND orl.objectFK = tt.id
              AND orl.rel_object_typeFK = 152
              AND orl.del = 'no'
        ), 'tournament_subset', NULL),
        IF(
            EXISTS (
                SELECT 1
                FROM object_relation orl
                JOIN tournament_sub_set sub
                  ON sub.id = orl.rel_objectFK
                 AND sub.del = 'no'
                WHERE orl.object_typeFK = 2
                  AND orl.objectFK = tt.id
                  AND orl.rel_object_typeFK = 152
                  AND orl.del = 'no'
            )
            AND NOT EXISTS (
                SELECT 1
                FROM object_relation orl
                JOIN tournament_sub_set sub
                  ON sub.id = orl.rel_objectFK
                 AND sub.del = 'no'
                JOIN tournament_set tset
                  ON tset.id = sub.tournament_setFK
                 AND tset.del = 'no'
                WHERE orl.object_typeFK = 2
                  AND orl.objectFK = tt.id
                  AND orl.rel_object_typeFK = 152
                  AND orl.del = 'no'
            ),
            'tournament_set',
            NULL
        )
    ) AS missing_fields,
    NULL AS eligible_count
FROM tournament_template tt
WHERE tt.del = 'no'
  AND tt.sportFK = 58
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
  AND (
      tt.name IS NULL
      OR TRIM(tt.name) = ''
      OR tt.gender IS NULL
      OR TRIM(tt.gender) = ''
      OR LOWER(TRIM(tt.gender)) = 'undefined'
      OR NOT EXISTS (
          SELECT 1
          FROM object_relation orl
          JOIN tournament_sub_set sub
            ON sub.id = orl.rel_objectFK
           AND sub.del = 'no'
          WHERE orl.object_typeFK = 2
            AND orl.objectFK = tt.id
            AND orl.rel_object_typeFK = 152
            AND orl.del = 'no'
      )
      OR NOT EXISTS (
          SELECT 1
          FROM object_relation orl
          JOIN tournament_sub_set sub
            ON sub.id = orl.rel_objectFK
           AND sub.del = 'no'
          JOIN tournament_set tset
            ON tset.id = sub.tournament_setFK
           AND tset.del = 'no'
          WHERE orl.object_typeFK = 2
            AND orl.objectFK = tt.id
            AND orl.rel_object_typeFK = 152
            AND orl.del = 'no'
      )
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL,
    NULL,
    NULL,
    COUNT(DISTINCT tt.id) AS eligible_count
FROM tournament_template tt
WHERE tt.del = 'no'
  AND tt.sportFK = 58
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - BMX-DQ-009
    -- Name - TOURNAMENT_STAGE_MISSING_CORE_FIELDS
    -- What it does: Finds active BMX tournament stages missing at least one of name, gender, country, host country, or an active city link, together with a coverage count of all eligible BMX stages.
    'Missing_Stage_Field' AS check_type,
    ts.id AS tournament_stage_id,
    ts.name AS tournament_stage_name,
    CONCAT_WS(', ',
        IF(ts.name IS NULL OR TRIM(ts.name) = '', 'name', NULL),
        IF(
            ts.gender IS NULL
            OR TRIM(ts.gender) = ''
            OR LOWER(TRIM(ts.gender)) = 'undefined',
            'gender',
            NULL
        ),
        IF(NOT EXISTS (
            SELECT 1
            FROM country c
            WHERE c.id = ts.countryFK
              AND c.del = 'no'
        ), 'country', NULL),
        IF(NOT EXISTS (
            SELECT 1
            FROM object_relation hc
            JOIN country hcc
              ON hcc.id = hc.rel_objectFK
             AND hcc.del = 'no'
            WHERE hc.object_typeFK = 4
              AND hc.objectFK = ts.id
              AND hc.rel_object_typeFK = 33
              AND hc.del = 'no'
        ), 'host_country', NULL),
        IF(NOT EXISTS (
            SELECT 1
            FROM city_object co
            JOIN city ci
              ON ci.id = co.cityFK
             AND ci.del = 'no'
            WHERE co.object_typeFK = 4
              AND co.objectFK = ts.id
              AND co.del = 'no'
        ), 'city', NULL)
    ) AS missing_fields,
    NULL AS eligible_count
FROM tournament_stage ts
JOIN tournament t
  ON t.id = ts.tournamentFK
 AND t.del = 'no'
JOIN tournament_template tt
  ON tt.id = t.tournament_templateFK
 AND tt.del = 'no'
 AND tt.sportFK = 58
WHERE ts.del = 'no'
  -- AND tt.id = <tournament_template_id>
  AND (
      ts.name IS NULL
      OR TRIM(ts.name) = ''
      OR ts.gender IS NULL
      OR TRIM(ts.gender) = ''
      OR LOWER(TRIM(ts.gender)) = 'undefined'
      OR NOT EXISTS (
          SELECT 1
          FROM country c
          WHERE c.id = ts.countryFK
            AND c.del = 'no'
      )
      OR NOT EXISTS (
          SELECT 1
          FROM object_relation hc
          JOIN country hcc
            ON hcc.id = hc.rel_objectFK
           AND hcc.del = 'no'
          WHERE hc.object_typeFK = 4
            AND hc.objectFK = ts.id
            AND hc.rel_object_typeFK = 33
            AND hc.del = 'no'
      )
      OR NOT EXISTS (
          SELECT 1
          FROM city_object co
          JOIN city ci
            ON ci.id = co.cityFK
           AND ci.del = 'no'
          WHERE co.object_typeFK = 4
            AND co.objectFK = ts.id
            AND co.del = 'no'
      )
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL,
    NULL,
    NULL,
    COUNT(DISTINCT ts.id) AS eligible_count
FROM tournament_stage ts
JOIN tournament t
  ON t.id = ts.tournamentFK
 AND t.del = 'no'
JOIN tournament_template tt
  ON tt.id = t.tournament_templateFK
 AND tt.del = 'no'
 AND tt.sportFK = 58
WHERE ts.del = 'no'
  -- AND tt.id = <tournament_template_id>
;

-- ================================================================================
SELECT
    -- CheckID - BMX-DQ-010
    -- Name - EVENT_SETTINGS_MISSING_DISCIPLINE
    -- What it does: Finds active BMX events without an active object_discipline relation (owner type=5), with template, tournament and stage name context, together with a coverage count of all eligible BMX events.
    'Missing_Discipline' AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    ts.name AS stage_name,
    NULL AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = 58
  -- AND tt.id = <tournament_template_id>
  AND NOT EXISTS (
      SELECT 1
      FROM object_discipline od
      WHERE od.object_typeFK = 5
        AND od.objectFK = e.id
        AND od.del = 'no'
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = 58
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - BMX-DQ-011
    -- Name - EVENT_MISSING_ROUND_TYPE
    -- What it does: Finds active BMX events with a NULL round_typeFK or a round_typeFK not matching any round_type row, with template, tournament and stage name context, together with a coverage count of all eligible BMX events.
    'Missing_Round_Type' AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    ts.name AS stage_name,
    e.round_typeFK,
    NULL AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = 58
  -- AND tt.id = <tournament_template_id>
  AND (
      e.round_typeFK IS NULL
      OR NOT EXISTS (
          SELECT 1
          FROM round_type rt
          WHERE rt.id = e.round_typeFK
      )
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = 58
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - BMX-DQ-012
    -- Name - EVENT_SETTINGS_MISSING_GENDER
    -- What it does: Finds active BMX events whose parent tournament stage has a NULL, empty or undefined gender value, with template, tournament and stage name context, together with a coverage count of all eligible BMX events.
    'Missing_Gender' AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    ts.name AS stage_name,
    ts.gender,
    NULL AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = 58
  -- AND tt.id = <tournament_template_id>
  AND (
      ts.gender IS NULL
      OR TRIM(ts.gender) = ''
      OR LOWER(TRIM(ts.gender)) = 'undefined'
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = 58
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - BMX-DQ-013
    -- Name - TEMPLATE_NO_TOURNAMENTS_OR_STAGES
    -- What it does: Finds active BMX tournament templates, excluding IOC-purpose templates, with zero active tournaments, or with tournaments but zero active tournament stages across all of them, together with a coverage count of all eligible BMX templates.
    'Missing_Tournaments_Or_Stages' AS check_type,
    tt.id AS tournament_template_id,
    tt.name AS tournament_template_name,
    CASE
        WHEN NOT EXISTS (
            SELECT 1 FROM tournament t2
            WHERE t2.tournament_templateFK = tt.id AND t2.del = 'no'
        ) THEN 'No_Tournaments'
        ELSE 'No_Stages'
    END AS missing_reason,
    NULL AS eligible_count
FROM tournament_template tt
WHERE tt.del = 'no'
  AND tt.sportFK = 58
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
  AND (
      NOT EXISTS (
          SELECT 1 FROM tournament t2
          WHERE t2.tournament_templateFK = tt.id AND t2.del = 'no'
      )
      OR NOT EXISTS (
          SELECT 1
          FROM tournament t3
          JOIN tournament_stage ts3 ON ts3.tournamentFK = t3.id AND ts3.del = 'no'
          WHERE t3.tournament_templateFK = tt.id AND t3.del = 'no'
      )
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL,
    COUNT(DISTINCT tt.id) AS eligible_count
FROM tournament_template tt
WHERE tt.del = 'no'
  AND tt.sportFK = 58
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - BMX-DQ-014
    -- Name - EVENT_RESULTS_MISSING_FOR_FINISHED
    -- What it does: Finds active BMX events with status_type='finished' (status_descFK=6) where none of their event participants has an active, non-empty result row, with template, tournament, stage name and status context, together with a coverage count of all eligible finished BMX events.
    'Missing_Results_For_Finished' AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    ts.name AS stage_name,
    e.status_type,
    e.status_descFK,
    NULL AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = 58
  AND e.status_type = 'finished'
  AND e.status_descFK = 6
  -- AND tt.id = <tournament_template_id>
  AND NOT EXISTS (
      SELECT 1
      FROM event_participants ep
      JOIN result r ON r.event_participantsFK = ep.id
        AND r.del = 'no'
        AND r.value IS NOT NULL
        AND TRIM(r.value) <> ''
      WHERE ep.eventFK = e.id
        AND ep.del = 'no'
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = 58
  AND e.status_type = 'finished'
  AND e.status_descFK = 6
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - BMX-DQ-015
    -- Name - EVENT_RESULTS_UNEXPECTED_FOR_NOT_STARTED
    -- What it does: Finds active BMX events with status_type='notstarted' (status_descFK=1) that have at least one active, non-empty result row for any event participant, with template, tournament, stage name and status context, together with a coverage count of all eligible not-started BMX events.
    'Unexpected_Results_For_Not_Started' AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    ts.name AS stage_name,
    e.status_type,
    e.status_descFK,
    NULL AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = 58
  AND e.status_type = 'notstarted'
  AND e.status_descFK = 1
  -- AND tt.id = <tournament_template_id>
  AND EXISTS (
      SELECT 1
      FROM event_participants ep
      JOIN result r ON r.event_participantsFK = ep.id
        AND r.del = 'no'
        AND r.value IS NOT NULL
        AND TRIM(r.value) <> ''
      WHERE ep.eventFK = e.id
        AND ep.del = 'no'
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = 58
  AND e.status_type = 'notstarted'
  AND e.status_descFK = 1
  -- AND tt.id = <tournament_template_id>
;

-- ================================================================================
SELECT
    -- CheckID - BMX-DQ-016
    -- Name - COMP.RANK_SETTINGS_MISSING_AGE_CLASS
    -- What it does: Finds active BMX Comp.Rank statistics (statistic_typeFK=11, object_typeFK=3) without an active tournament_age_class relation via object_relation (owner type=83), with template and tournament name context, together with a coverage count of all eligible BMX statistics.
    'Missing_Age_Class' AS check_type,
    s.id AS statistic_id,
    s.name AS statistic_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    NULL AS eligible_count
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = 11
  AND s.object_typeFK = 3
  AND tt.sportFK = 58
  -- AND tt.id = <tournament_template_id>
  AND NOT EXISTS (
      SELECT 1
      FROM object_relation orl
      WHERE orl.object_typeFK = 83
        AND orl.objectFK = s.id
        AND orl.rel_object_typeFK = 151
        AND orl.del = 'no'
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = 11
  AND s.object_typeFK = 3
  AND tt.sportFK = 58
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - BMX-DQ-017
    -- Name - COMP.RANK_NO_PARTICIPANTS
    -- What it does: Finds active BMX Comp.Rank statistics with zero active statistic_participants11 rows, with template and tournament name context, together with a coverage count of all eligible BMX statistics.
    'No_Participants' AS check_type,
    s.id AS statistic_id,
    s.name AS statistic_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    NULL AS eligible_count
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = 11
  AND s.object_typeFK = 3
  AND tt.sportFK = 58
  -- AND tt.id = <tournament_template_id>
  AND NOT EXISTS (
      SELECT 1
      FROM statistic_participants11 sp
      WHERE sp.statisticFK = s.id
        AND sp.del = 'no'
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = 11
  AND s.object_typeFK = 3
  AND tt.sportFK = 58
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - BMX-DQ-018
    -- Name - COMP.RANK_SETTINGS_DATE_RANGE_MISMATCH_STAGE
    -- What it does: Finds active BMX Comp.Rank statistics whose statistic_config Start date/End date (1463/1464) do not match the earliest and latest active tournament_stage start/end date under the statistic's tournament, with template and tournament name context, together with a coverage count of all eligible BMX statistics with at least one active config date.
    'Date_Range_Mismatch_Stage' AS check_type,
    s.id AS statistic_id,
    s.name AS statistic_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    (SELECT MIN(sc1.value) FROM statistic_config sc1 WHERE sc1.statisticFK = s.id AND sc1.statistic_data_typeFK = 1463 AND sc1.del = 'no') AS config_start_date,
    (SELECT MAX(sc2.value) FROM statistic_config sc2 WHERE sc2.statisticFK = s.id AND sc2.statistic_data_typeFK = 1464 AND sc2.del = 'no') AS config_end_date,
    MIN(ts.startdate) AS earliest_stage_startdate,
    MAX(ts.enddate) AS latest_stage_enddate,
    NULL AS eligible_count
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = 11
  AND s.object_typeFK = 3
  AND tt.sportFK = 58
  -- AND tt.id = <tournament_template_id>
GROUP BY s.id, s.name, tt.name, t.name
HAVING (
    DATE((SELECT MIN(sc1.value) FROM statistic_config sc1 WHERE sc1.statisticFK = s.id AND sc1.statistic_data_typeFK = 1463 AND sc1.del = 'no')) <> DATE(MIN(ts.startdate))
    OR DATE((SELECT MAX(sc2.value) FROM statistic_config sc2 WHERE sc2.statisticFK = s.id AND sc2.statistic_data_typeFK = 1464 AND sc2.del = 'no')) <> DATE(MAX(ts.enddate))
)

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = 11
  AND s.object_typeFK = 3
  AND tt.sportFK = 58
  -- AND tt.id = <tournament_template_id>
  AND EXISTS (
      SELECT 1 FROM statistic_config sc3
      WHERE sc3.statisticFK = s.id AND sc3.statistic_data_typeFK IN (1463, 1464) AND sc3.del = 'no'
  );


-- ================================================================================
SELECT
    -- CheckID - BMX-DQ-019
    -- Name - COMP.RANK_SETTINGS_DATE_RANGE_MISMATCH_EVENTS
    -- What it does: Finds active BMX Comp.Rank statistics whose statistic_config Start date/End date (1463/1464) do not match the earliest and latest startdate of the events referenced via statistic_config Event id (1471), with template and tournament name context, together with a coverage count of all eligible BMX statistics with at least one linked event and at least one active config date.
    'Date_Range_Mismatch_Events' AS check_type,
    s.id AS statistic_id,
    s.name AS statistic_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    (SELECT MIN(sc1.value) FROM statistic_config sc1 WHERE sc1.statisticFK = s.id AND sc1.statistic_data_typeFK = 1463 AND sc1.del = 'no') AS config_start_date,
    (SELECT MAX(sc2.value) FROM statistic_config sc2 WHERE sc2.statisticFK = s.id AND sc2.statistic_data_typeFK = 1464 AND sc2.del = 'no') AS config_end_date,
    MIN(e.startdate) AS earliest_linked_event_startdate,
    MAX(e.startdate) AS latest_linked_event_startdate,
    NULL AS eligible_count
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN statistic_config sce ON sce.statisticFK = s.id AND sce.statistic_data_typeFK = 1471 AND sce.del = 'no'
JOIN event e ON e.id = sce.value AND e.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = 11
  AND s.object_typeFK = 3
  AND tt.sportFK = 58
  -- AND tt.id = <tournament_template_id>
GROUP BY s.id, s.name, tt.name, t.name
HAVING (
    DATE((SELECT MIN(sc1.value) FROM statistic_config sc1 WHERE sc1.statisticFK = s.id AND sc1.statistic_data_typeFK = 1463 AND sc1.del = 'no')) <> DATE(MIN(e.startdate))
    OR DATE((SELECT MAX(sc2.value) FROM statistic_config sc2 WHERE sc2.statisticFK = s.id AND sc2.statistic_data_typeFK = 1464 AND sc2.del = 'no')) <> DATE(MAX(e.startdate))
)

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN statistic_config sce ON sce.statisticFK = s.id AND sce.statistic_data_typeFK = 1471 AND sce.del = 'no'
JOIN event e ON e.id = sce.value AND e.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = 11
  AND s.object_typeFK = 3
  AND tt.sportFK = 58
  -- AND tt.id = <tournament_template_id>
  AND EXISTS (
      SELECT 1 FROM statistic_config sc3
      WHERE sc3.statisticFK = s.id AND sc3.statistic_data_typeFK IN (1463, 1464) AND sc3.del = 'no'
  );


-- ================================================================================
SELECT
    -- CheckID - BMX-DQ-020
    -- Name - COMP.RANK_SETTINGS_MISSING_START_OR_END_DATE
    -- What it does: Finds active BMX Comp.Rank statistics missing an active, non-empty Start date (1463) or End date (1464) statistic_config value, with template and tournament name context, together with a coverage count of all eligible BMX statistics.
    'Missing_Start_Or_End_Date' AS check_type,
    s.id AS statistic_id,
    s.name AS statistic_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    CONCAT_WS(', ',
        IF(NOT EXISTS (
            SELECT 1 FROM statistic_config sc1
            WHERE sc1.statisticFK = s.id AND sc1.statistic_data_typeFK = 1463
              AND sc1.del = 'no' AND sc1.value IS NOT NULL AND TRIM(sc1.value) <> ''
        ), 'start_date', NULL),
        IF(NOT EXISTS (
            SELECT 1 FROM statistic_config sc2
            WHERE sc2.statisticFK = s.id AND sc2.statistic_data_typeFK = 1464
              AND sc2.del = 'no' AND sc2.value IS NOT NULL AND TRIM(sc2.value) <> ''
        ), 'end_date', NULL)
    ) AS missing_fields,
    NULL AS eligible_count
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = 11
  AND s.object_typeFK = 3
  AND tt.sportFK = 58
  -- AND tt.id = <tournament_template_id>
  AND (
      NOT EXISTS (
          SELECT 1 FROM statistic_config sc1
          WHERE sc1.statisticFK = s.id AND sc1.statistic_data_typeFK = 1463
            AND sc1.del = 'no' AND sc1.value IS NOT NULL AND TRIM(sc1.value) <> ''
      )
      OR NOT EXISTS (
          SELECT 1 FROM statistic_config sc2
          WHERE sc2.statisticFK = s.id AND sc2.statistic_data_typeFK = 1464
            AND sc2.del = 'no' AND sc2.value IS NOT NULL AND TRIM(sc2.value) <> ''
      )
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = 11
  AND s.object_typeFK = 3
  AND tt.sportFK = 58
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - BMX-DQ-021
    -- Name - COMP.RANK_SETTINGS_MISSING_CORE_FIELDS
    -- What it does: Finds active BMX Comp.Rank statistics missing name, an active non-empty Gender config value (1470), an active country relation (object_relation 83->33), or an active city relation (city_object owner type=83), with template and tournament name context, together with a coverage count of all eligible BMX statistics.
    'Missing_Statistic_Field' AS check_type,
    s.id AS statistic_id,
    s.name AS statistic_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    CONCAT_WS(', ',
        IF(s.name IS NULL OR TRIM(s.name) = '', 'name', NULL),
        IF(NOT EXISTS (
            SELECT 1 FROM statistic_config sc
            WHERE sc.statisticFK = s.id AND sc.statistic_data_typeFK = 1470
              AND sc.del = 'no' AND sc.value IS NOT NULL AND TRIM(sc.value) <> ''
              AND LOWER(TRIM(sc.value)) <> 'undefined'
        ), 'gender', NULL),
        IF(NOT EXISTS (
            SELECT 1 FROM object_relation orl
            JOIN country c ON c.id = orl.rel_objectFK AND c.del = 'no'
            WHERE orl.object_typeFK = 83
              AND orl.objectFK = s.id
              AND orl.rel_object_typeFK = 33
              AND orl.del = 'no'
        ), 'country', NULL),
        IF(NOT EXISTS (
            SELECT 1 FROM city_object co
            JOIN city ci ON ci.id = co.cityFK AND ci.del = 'no'
            WHERE co.object_typeFK = 83
              AND co.objectFK = s.id
              AND co.del = 'no'
        ), 'city', NULL)
    ) AS missing_fields,
    NULL AS eligible_count
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = 11
  AND s.object_typeFK = 3
  AND tt.sportFK = 58
  -- AND tt.id = <tournament_template_id>
  AND (
      s.name IS NULL OR TRIM(s.name) = ''
      OR NOT EXISTS (
          SELECT 1 FROM statistic_config sc
          WHERE sc.statisticFK = s.id AND sc.statistic_data_typeFK = 1470
            AND sc.del = 'no' AND sc.value IS NOT NULL AND TRIM(sc.value) <> ''
            AND LOWER(TRIM(sc.value)) <> 'undefined'
      )
      OR NOT EXISTS (
          SELECT 1 FROM object_relation orl
          JOIN country c ON c.id = orl.rel_objectFK AND c.del = 'no'
          WHERE orl.object_typeFK = 83
            AND orl.objectFK = s.id
            AND orl.rel_object_typeFK = 33
            AND orl.del = 'no'
      )
      OR NOT EXISTS (
          SELECT 1 FROM city_object co
          JOIN city ci ON ci.id = co.cityFK AND ci.del = 'no'
          WHERE co.object_typeFK = 83
            AND co.objectFK = s.id
            AND co.del = 'no'
      )
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = 11
  AND s.object_typeFK = 3
  AND tt.sportFK = 58
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - BMX-DQ-022
    -- Name - COMP.RANK_SETTINGS_MISSING_DISCIPLINE
    -- What it does: Finds active BMX Comp.Rank statistics with zero active object_discipline relations (owner type=83), or with an active relation whose disciplineFK does not resolve to any active discipline row, with template and tournament name context, together with a coverage count of all eligible BMX statistics.
    'Missing_Discipline' AS check_type,
    s.id AS statistic_id,
    s.name AS statistic_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    NULL AS eligible_count
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = 11
  AND s.object_typeFK = 3
  AND tt.sportFK = 58
  -- AND tt.id = <tournament_template_id>
  AND (
      NOT EXISTS (
          SELECT 1 FROM object_discipline od
          WHERE od.object_typeFK = 83
            AND od.objectFK = s.id
            AND od.del = 'no'
      )
      OR EXISTS (
          SELECT 1 FROM object_discipline od2
          WHERE od2.object_typeFK = 83
            AND od2.objectFK = s.id
            AND od2.del = 'no'
            AND NOT EXISTS (
                SELECT 1 FROM discipline d
                WHERE d.id = od2.disciplineFK AND d.del = 'no'
            )
      )
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = 11
  AND s.object_typeFK = 3
  AND tt.sportFK = 58
  -- AND tt.id = <tournament_template_id>
;

-- ================================================================================
SELECT
    -- CheckID - BMX-DQ-029
    -- Name - TEMPLATE_STAGE_GENDER_MISMATCH
    -- What it does: Finds active BMX tournament stages whose gender differs from their parent template gender, excluding cases where either side is mixed or empty, together with a coverage count of eligible stages.
    'Gender_Mismatch' AS check_type,
    tt.id AS tournament_template_id,
    tt.name AS template_name,
    tt.gender AS template_gender,
    ts.id AS tournament_stage_id,
    ts.name AS stage_name,
    ts.gender AS stage_gender,
    NULL AS eligible_count
FROM tournament_stage ts
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE ts.del = 'no'
  AND tt.sportFK = 58
  AND ts.gender IS NOT NULL AND TRIM(ts.gender) <> '' AND LOWER(TRIM(ts.gender)) <> 'mixed'
  AND tt.gender IS NOT NULL AND TRIM(tt.gender) <> '' AND LOWER(TRIM(tt.gender)) <> 'mixed'
  AND LOWER(TRIM(ts.gender)) <> LOWER(TRIM(tt.gender))
  -- AND tt.id = <tournament_template_id>

UNION ALL

SELECT
    'COVERAGE', NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ts.id) AS eligible_count
FROM tournament_stage ts
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE ts.del = 'no'
  AND tt.sportFK = 58
  AND ts.gender IS NOT NULL AND TRIM(ts.gender) <> '' AND LOWER(TRIM(ts.gender)) <> 'mixed'
  AND tt.gender IS NOT NULL AND TRIM(tt.gender) <> '' AND LOWER(TRIM(tt.gender)) <> 'mixed'
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - BMX-DQ-030
    -- Name - EVENT_PARTICIPANTS_GENDER_MISMATCH
    -- What it does: Finds active BMX events whose athlete event participants include at least one gender different from the parent tournament stage gender, with per-event male/female/other participant counts, excluding stages with mixed or empty gender, together with a coverage count of eligible events.
    'Gender_Mismatch' AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    ts.id AS tournament_stage_id,
    ts.name AS stage_name,
    ts.gender AS stage_gender,
    COUNT(DISTINCT CASE WHEN LOWER(TRIM(p.gender)) = 'male' THEN p.id END) AS male_cnt,
    COUNT(DISTINCT CASE WHEN LOWER(TRIM(p.gender)) = 'female' THEN p.id END) AS female_cnt,
    COUNT(DISTINCT CASE WHEN LOWER(TRIM(p.gender)) NOT IN ('male','female') OR p.gender IS NULL THEN p.id END) AS other_or_missing_gender_cnt,
    NULL AS eligible_count
FROM event_participants ep
JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE ep.del = 'no'
  AND p.type = 'athlete'
  AND tt.sportFK = 58
  AND ts.gender IS NOT NULL AND TRIM(ts.gender) <> '' AND LOWER(TRIM(ts.gender)) <> 'mixed'
  -- AND tt.id = <tournament_template_id>
GROUP BY e.id, e.name, ts.id, ts.name, ts.gender
HAVING COUNT(DISTINCT CASE
    WHEN p.gender IS NOT NULL
     AND TRIM(p.gender) <> ''
     AND LOWER(TRIM(p.gender)) <> LOWER(TRIM(ts.gender))
    THEN p.id END) > 0

UNION ALL

SELECT
    'COVERAGE', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count
FROM event_participants ep
JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE ep.del = 'no'
  AND p.type = 'athlete'
  AND tt.sportFK = 58
  AND ts.gender IS NOT NULL AND TRIM(ts.gender) <> '' AND LOWER(TRIM(ts.gender)) <> 'mixed'
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - BMX-DQ-031
    -- Name - COMP.RANK_RESULTS_GENDER_MISMATCH
    -- What it does: Finds active BMX Comp.Rank statistics whose Gender config value does not match the gender composition of their statistic participants, classifying each violation type, together with a coverage count of all eligible statistics.
    'Gender_Mismatch' AS check_type,
    st.id AS statistic_id,
    st.name AS statistic_name,
    sg.value AS statistic_gender,
    MAX(p.type) AS participant_type_seen,
    COUNT(DISTINCT CASE WHEN p.gender = 'male' THEN p.id END) AS male_cnt,
    COUNT(DISTINCT CASE WHEN p.gender = 'female' THEN p.id END) AS female_cnt,
    COUNT(DISTINCT CASE WHEN p.gender = 'mixed' THEN p.id END) AS mixed_cnt,
    COUNT(DISTINCT CASE WHEN p.type = 'team' AND p.gender <> 'mixed' THEN p.id END) AS team_wrong_gender_cnt,
    CASE
        WHEN sg.value = 'male'
             AND COUNT(DISTINCT CASE WHEN p.gender <> 'male' THEN p.id END) > 0
            THEN 'MALE_STATISTIC_HAS_NONMALE'
        WHEN sg.value = 'female'
             AND COUNT(DISTINCT CASE WHEN p.gender <> 'female' THEN p.id END) > 0
            THEN 'FEMALE_STATISTIC_HAS_NONFEMALE'
        WHEN sg.value = 'mixed'
             AND COUNT(DISTINCT CASE WHEN p.type = 'team' THEN p.id END) > 0
             AND COUNT(DISTINCT CASE WHEN p.type = 'team' AND p.gender <> 'mixed' THEN p.id END) > 0
            THEN 'MIXED_TEAM_NOT_MIXED_GENDER'
        WHEN sg.value = 'mixed'
             AND COUNT(DISTINCT CASE WHEN p.type = 'athlete' THEN p.id END) > 0
             AND (
                  COUNT(DISTINCT CASE WHEN p.type = 'athlete' AND p.gender = 'male' THEN p.id END) = 0
               OR COUNT(DISTINCT CASE WHEN p.type = 'athlete' AND p.gender = 'female' THEN p.id END) = 0
             )
            THEN 'MIXED_ATHLETES_MISSING_ONE_SIDE'
        ELSE 'OK'
    END AS violation_type,
    NULL AS eligible_count
FROM sport s
JOIN tournament_template tt ON tt.sportFK = s.id AND tt.del = 'no'
JOIN tournament t ON t.tournament_templateFK = tt.id AND t.del = 'no'
JOIN statistic st ON st.object_typeFK = 3 AND st.objectFK = t.id AND st.statistic_typeFK = 11 AND st.del = 'no'
JOIN statistic_config sg ON sg.statisticFK = st.id AND sg.statistic_data_typeFK = 1470 AND sg.del = 'no'
     AND sg.value IN ('male','female','mixed')
JOIN statistic_participants11 sp ON sp.statisticFK = st.id AND sp.del = 'no'
JOIN participant p ON p.id = sp.participantFK AND p.del = 'no'
WHERE s.id = 58 AND s.del = 'no'
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
GROUP BY st.id, st.name, sg.value
HAVING violation_type <> 'OK'

UNION ALL

SELECT
    'COVERAGE', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT st.id) AS eligible_count
FROM sport s
JOIN tournament_template tt ON tt.sportFK = s.id AND tt.del = 'no'
JOIN tournament t ON t.tournament_templateFK = tt.id AND t.del = 'no'
JOIN statistic st ON st.object_typeFK = 3 AND st.objectFK = t.id AND st.statistic_typeFK = 11 AND st.del = 'no'
JOIN statistic_config sg ON sg.statisticFK = st.id AND sg.statistic_data_typeFK = 1470 AND sg.del = 'no'
     AND sg.value IN ('male','female','mixed')
JOIN statistic_participants11 sp ON sp.statisticFK = st.id AND sp.del = 'no'
JOIN participant p ON p.id = sp.participantFK AND p.del = 'no'
WHERE s.id = 58 AND s.del = 'no'
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
;
-- ================================================================================
SELECT
    -- CheckID - BMX-DQ-032
    -- Name - EVENT_RESULTS_MISSING_MEDAL_FOR_FINAL
    -- What it does: Finds active, finished BMX events with round_typeFK=173 (Final) where at least one of gold/silver/bronze Medal (result_typeFK=501) values is absent among event participants, distinguishing events with no medals at all from events missing only specific medal type(s), together with a coverage count of all eligible Final-round finished BMX events.
    CASE WHEN x.total_medal_count = 0 THEN 'No_Medals_At_All' ELSE 'Missing_Specific_Medal' END AS check_type,
    x.event_id,
    x.event_name,
    x.template_name,
    x.tournament_name,
    x.stage_name,
    CONCAT_WS(', ',
        IF(x.gold_count = 0, 'gold', NULL),
        IF(x.silver_count = 0, 'silver', NULL),
        IF(x.bronze_count = 0, 'bronze', NULL)
    ) AS missing_medals,
    NULL AS eligible_count
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        ts.name AS stage_name,
        SUM(CASE WHEN LOWER(TRIM(r.value)) = 'gold' THEN 1 ELSE 0 END) AS gold_count,
        SUM(CASE WHEN LOWER(TRIM(r.value)) = 'silver' THEN 1 ELSE 0 END) AS silver_count,
        SUM(CASE WHEN LOWER(TRIM(r.value)) = 'bronze' THEN 1 ELSE 0 END) AS bronze_count,
        SUM(CASE WHEN r.value IS NOT NULL AND TRIM(r.value) <> '' THEN 1 ELSE 0 END) AS total_medal_count
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    LEFT JOIN result r
      ON r.event_participantsFK = ep.id
     AND r.del = 'no'
     AND r.result_typeFK = 501
    WHERE e.del = 'no'
      AND tt.sportFK = 58
      AND e.round_typeFK = 173
      AND e.status_type = 'finished'
      AND e.status_descFK = 6
      -- AND tt.id = <tournament_template_id>
    GROUP BY e.id, e.name, tt.name, t.name, ts.name
) x
WHERE x.gold_count = 0 OR x.silver_count = 0 OR x.bronze_count = 0

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = 58
  AND e.round_typeFK = 173
  AND e.status_type = 'finished'
  AND e.status_descFK = 6
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - BMX-DQ-033
    -- Name - COMP.RANK_SETTINGS_MISSING_MEDAL
    -- What it does: Finds active BMX Comp.Rank statistics (statistic_typeFK=11, object_typeFK=3) where at least one of gold/silver/bronze Medal (statistic_data_typeFK=1277) values is absent among statistic participants, distinguishing statistics with no medals at all from statistics missing only specific medal type(s), together with a coverage count of all eligible BMX Comp.Rank statistics.
    CASE WHEN x.total_medal_count = 0 THEN 'No_Medals_At_All' ELSE 'Missing_Specific_Medal' END AS check_type,
    x.statistic_id,
    x.statistic_name,
    x.template_name,
    x.tournament_name,
    CONCAT_WS(', ',
        IF(x.gold_count = 0, 'gold', NULL),
        IF(x.silver_count = 0, 'silver', NULL),
        IF(x.bronze_count = 0, 'bronze', NULL)
    ) AS missing_medals,
    NULL AS eligible_count
FROM (
    SELECT
        s.id AS statistic_id,
        s.name AS statistic_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        SUM(CASE WHEN LOWER(TRIM(sd.value)) = 'gold' THEN 1 ELSE 0 END) AS gold_count,
        SUM(CASE WHEN LOWER(TRIM(sd.value)) = 'silver' THEN 1 ELSE 0 END) AS silver_count,
        SUM(CASE WHEN LOWER(TRIM(sd.value)) = 'bronze' THEN 1 ELSE 0 END) AS bronze_count,
        SUM(CASE WHEN sd.value IS NOT NULL AND TRIM(sd.value) <> '' THEN 1 ELSE 0 END) AS total_medal_count
    FROM statistic s
    JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN statistic_participants11 sp ON sp.statisticFK = s.id AND sp.del = 'no'
    LEFT JOIN statistic_data11 sd
      ON sd.statistic_participants11FK = sp.id
     AND sd.del = 'no'
     AND sd.statistic_data_typeFK = 1277
    WHERE s.del = 'no'
      AND s.statistic_typeFK = 11
      AND s.object_typeFK = 3
      AND tt.sportFK = 58
      -- AND tt.id = <tournament_template_id>
    GROUP BY s.id, s.name, tt.name, t.name
) x
WHERE x.gold_count = 0 OR x.silver_count = 0 OR x.bronze_count = 0

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = 11
  AND s.object_typeFK = 3
  AND tt.sportFK = 58
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - BMX-DQ-034
    -- Name - EVENT_SETTINGS_MISSING_MEDAL_RELATED_FOR_FINAL
    -- What it does: Finds active, finished BMX events with round_typeFK=173 (Final) that have no active event property named medal_related with value yes, with template, tournament and stage name context, together with a coverage count of all eligible Final-round finished BMX events.
    'Missing_Medal_Related_Property' AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    ts.name AS stage_name,
    NULL AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = 58
  AND e.round_typeFK = 173
  AND e.status_type = 'finished'
  AND e.status_descFK = 6
  -- AND tt.id = <tournament_template_id>
  AND NOT EXISTS (
      SELECT 1
      FROM property p
      WHERE p.object = 'event'
        AND p.objectFK = e.id
        AND p.del = 'no'
        AND LOWER(TRIM(p.name)) = 'medal_related'
        AND LOWER(TRIM(p.value)) = 'yes'
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = 58
  AND e.round_typeFK = 173
  AND e.status_type = 'finished'
  AND e.status_descFK = 6
  -- AND tt.id