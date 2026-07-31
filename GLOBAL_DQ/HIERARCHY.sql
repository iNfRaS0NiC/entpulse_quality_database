SELECT
    -- CheckID - GLOBAL-DQ-001
    -- Name - TEMPLATE_NO_TOURNAMENTS_OR_STAGES
    -- What it does: Finds active tournament templates, excluding IOC-purpose templates, with zero active tournaments, or with tournaments but zero active tournament stages across all of them, together with a coverage count of all eligible templates.
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
  AND tt.sportFK = {{SPORT_ID}}
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
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-002
    -- Name - TOURNAMENT_STAGE_MISSING_AGE_CLASS
    -- What it does: Finds active tournament stages without an active tournament_age_class relation via object_relation, together with a coverage count of all eligible stages.
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
  AND tt.sportFK = {{SPORT_ID}}
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
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-003
    -- Name - TOURNAMENT_STAGE_NO_EVENTS
    -- What it does: Finds active tournament stages with zero active events, together with a coverage count of all eligible stages.
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
  AND tt.sportFK = {{SPORT_ID}}
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
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-004
    -- Name - TOURNAMENT_STAGE_DATE_RANGE_MISMATCH
    -- What it does: Finds active tournament stages whose start or end date does not match the earliest and latest active event start date within the stage, together with a coverage count of all eligible stages with at least one event.
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
  AND tt.sportFK = {{SPORT_ID}}
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
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
  AND EXISTS (
      SELECT 1
      FROM event e2
      WHERE e2.tournament_stageFK = ts.id
        AND e2.del = 'no'
  );


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-005
    -- Name - TOURNAMENT_STAGE_MISSING_START_OR_END_DATE
    -- What it does: Finds active tournament stages with a NULL start date or end date, together with a coverage count of all eligible stages.
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
  AND tt.sportFK = {{SPORT_ID}}
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
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-006
    -- Name - EVENT_MISSING_ROUND_TYPE
    -- What it does: Finds active events with a NULL round_typeFK or a round_typeFK not matching any round_type row, with template, tournament and stage name context, together with a coverage count of all eligible events.
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
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
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
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-013
    -- Name - TEMPLATE_MISSING_SET_SUBSET_GENDER_NAME
    -- What it does: Finds active tournament templates, excluding IOC-purpose templates, missing name, gender, an active subset relation, or a resolvable tournament set, together with a coverage count of all eligible templates.
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
  AND tt.sportFK = {{SPORT_ID}}
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
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-014
    -- Name - TEMPLATE_STAGE_GENDER_MISMATCH
    -- What it does: Finds active tournament stages whose gender differs from their parent template gender, excluding cases where either side is mixed or empty, together with a coverage count of all eligible stages.
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
  AND tt.sportFK = {{SPORT_ID}}
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
  AND tt.sportFK = {{SPORT_ID}}
  AND ts.gender IS NOT NULL AND TRIM(ts.gender) <> '' AND LOWER(TRIM(ts.gender)) <> 'mixed'
  AND tt.gender IS NOT NULL AND TRIM(tt.gender) <> '' AND LOWER(TRIM(tt.gender)) <> 'mixed'
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-015
    -- Name - EVENT_SETTINGS_MISSING_DISCIPLINE
    -- What it does: Finds active events without an active object_discipline relation (owner type=5), with template, tournament and stage name context, together with a coverage count of all eligible events.
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
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
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
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-016
    -- Name - EVENT_SETTINGS_MISSING_GENDER
    -- What it does: Finds active events whose parent tournament stage has a NULL, empty or undefined gender value, with template, tournament and stage name context, together with a coverage count of all eligible events.
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
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
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
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-034
    -- Name - TOURNAMENT_STAGE_MISSING_CORE_FIELDS
    -- What it does: Finds active tournament stages missing at least one of name, gender, country, host country, or an active city link, together with a coverage count of all eligible stages.
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
 AND tt.sportFK = {{SPORT_ID}}
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
 AND tt.sportFK = {{SPORT_ID}}
WHERE ts.del = 'no'
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-038
    -- Name - EVENT_SETTINGS_MISSING_MEDAL_RELATED_FOR_FINAL
    -- What it does: Finds active, finished events on a Final round type that have no active event property named medal_related with value yes, with template, tournament and stage name context, together with a coverage count of all eligible Final-round finished events.
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
  AND tt.sportFK = {{SPORT_ID}}
  AND e.round_typeFK IN ({{FINAL_ROUND_TYPE_LIST}})
  AND e.status_type = 'finished'
  AND e.status_descFK = 6
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
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
  AND tt.sportFK = {{SPORT_ID}}
  AND e.round_typeFK IN ({{FINAL_ROUND_TYPE_LIST}})
  AND e.status_type = 'finished'
  AND e.status_descFK = 6
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;
