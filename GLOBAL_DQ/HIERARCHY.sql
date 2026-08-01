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
    -- What it does: Finds active tournament stages missing at least one of name, gender, country, host country, or an active city link, or carrying a country or host country that resolves only to a placeholder row and therefore reads as populated, together with a coverage count of all eligible stages.
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
        -- A country that resolves to a placeholder row reads as populated to every
        -- IS NULL test, so it is named separately rather than counted as clean.
        IF(EXISTS (
            SELECT 1
            FROM country c
            WHERE c.id = ts.countryFK
              AND c.del = 'no'
              AND c.name IN ({{PLACEHOLDER_COUNTRY_LIST}})
        ), 'country_placeholder', NULL),
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
        IF(EXISTS (
            SELECT 1
            FROM object_relation hc
            JOIN country hcc
              ON hcc.id = hc.rel_objectFK
             AND hcc.del = 'no'
            WHERE hc.object_typeFK = 4
              AND hc.objectFK = ts.id
              AND hc.rel_object_typeFK = 33
              AND hc.del = 'no'
              AND hcc.name IN ({{PLACEHOLDER_COUNTRY_LIST}})
        ), 'host_country_placeholder', NULL),
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
      OR EXISTS (
          SELECT 1
          FROM country c
          WHERE c.id = ts.countryFK
            AND c.del = 'no'
            AND c.name IN ({{PLACEHOLDER_COUNTRY_LIST}})
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
      OR EXISTS (
          SELECT 1
          FROM object_relation hc
          JOIN country hcc
            ON hcc.id = hc.rel_objectFK
           AND hcc.del = 'no'
          WHERE hc.object_typeFK = 4
            AND hc.objectFK = ts.id
            AND hc.rel_object_typeFK = 33
            AND hc.del = 'no'
            AND hcc.name IN ({{PLACEHOLDER_COUNTRY_LIST}})
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


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-048
    -- Name - TOURNAMENT_STAGE_NAME_FORMAT_INVALID
    -- What it does: Finds each distinct active tournament-stage name that breaks at least one text-hygiene rule - edge or doubled spacing, a control character, a definite text corruption such as an HTML entity, a replacement character, a non-breaking or zero-width space or a double-encoded byte sequence, a non-ASCII character, a hyphen without surrounding spaces, a year glued to a word, a capitalisation shape a proof-read name does not take, a placeholder name or a numeric-only name - naming every rule the name breaks and how many objects carry it, reporting one row per offending name rather than one per object repeating it, together with a coverage count of all distinct eligible names.
    'Name_Format_Invalid' AS check_type,
    MIN(x.object_name) AS stage_name,
    x.violation_types,
    COUNT(DISTINCT x.object_id) AS affected_object_count,
    MIN(x.object_id) AS sample_object_id,
    MIN(x.template_name) AS sample_template_name,
    MIN(x.tournament_name) AS sample_tournament_name,
    NULL AS eligible_count,
    0 AS sort_order
FROM (
    SELECT
        ts.id AS object_id,
        ts.name AS object_name,
        -- The grouping key is binary: under the column's case-insensitive collation two
        -- spellings that differ only in case would collapse into one group, which is the
        -- distinction GLOBAL-DQ-050 exists to report.
        (CONVERT(ts.name USING utf8mb4) COLLATE utf8mb4_bin) AS name_bin,
        tt.name AS template_name,
        t.name AS tournament_name,
        CONCAT_WS(', ',
            IF(CHAR_LENGTH(ts.name) <> CHAR_LENGTH(TRIM(ts.name)), 'LEADING_OR_TRAILING_SPACE', NULL),
            IF(ts.name LIKE '%  %', 'DOUBLE_SPACE', NULL),
            IF(ts.name REGEXP '[[:cntrl:]]', 'CONTROL_CHARACTER', NULL),
            -- The five rules below name a definite corruption. NON_ASCII_CHARACTER
            -- that follows cannot: it fires on a legitimate diacritic just as readily,
            -- so a corrupted name is reported under its own verdict as well.
            IF(ts.name LIKE '%&#%' OR LOWER(ts.name) REGEXP '&(amp|quot|apos|lt|gt|nbsp);', 'HTML_ENTITY', NULL),
            IF(HEX(ts.name) LIKE '%EFBFBD%', 'REPLACEMENT_CHARACTER', NULL),
            IF(HEX(ts.name) LIKE '%C2A0%', 'NON_BREAKING_SPACE', NULL),
            IF(HEX(ts.name) LIKE '%E2808B%', 'ZERO_WIDTH_SPACE', NULL),
            IF(HEX(ts.name) LIKE '%C383%' OR HEX(ts.name) LIKE '%C382%', 'MOJIBAKE_DOUBLE_ENCODED', NULL),
            IF(LENGTH(ts.name) <> CHAR_LENGTH(ts.name), 'NON_ASCII_CHARACTER', NULL),
            IF(ts.name REGEXP '[^ ]-|-[^ ]', 'HYPHEN_WITHOUT_SPACES', NULL),
            IF((CONVERT(ts.name USING utf8mb4) COLLATE utf8mb4_bin) REGEXP '[A-Za-z][12][0-9][0-9][0-9]|[12][0-9][0-9][0-9][A-Za-z]', 'YEAR_GLUED_TO_WORD', NULL),
            IF((CONVERT(ts.name USING utf8mb4) COLLATE utf8mb4_bin) REGEXP '[A-Z][A-Z][a-z]', 'DOUBLE_CAPITAL', NULL),
            IF((CONVERT(ts.name USING utf8mb4) COLLATE utf8mb4_bin) REGEXP '[A-Za-z]'
               AND (CONVERT(ts.name USING utf8mb4) COLLATE utf8mb4_bin) NOT REGEXP '[a-z]', 'ALL_UPPERCASE', NULL),
            IF((CONVERT(ts.name USING utf8mb4) COLLATE utf8mb4_bin) REGEXP '^[a-z]', 'STARTS_LOWERCASE', NULL),
            IF(LOWER(TRIM(ts.name)) IN ('test','testing','temp','tmp','xxx','asd','qwe','tbd','tba','n/a','undefined','event','new event'), 'PLACEHOLDER_NAME', NULL),
            IF(TRIM(ts.name) REGEXP '^[0-9]+$', 'NUMERIC_ONLY_NAME', NULL)
        ) AS violation_types
    FROM tournament_stage ts
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    WHERE ts.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      AND ts.name IS NOT NULL
      AND TRIM(ts.name) <> ''
      -- AND tt.id = <tournament_template_id>
) x
WHERE x.violation_types <> ''
GROUP BY x.name_bin, x.violation_types

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT (CONVERT(ts.name USING utf8mb4) COLLATE utf8mb4_bin)) AS eligible_count,
    1 AS sort_order
    FROM tournament_stage ts
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE ts.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND ts.name IS NOT NULL
  AND TRIM(ts.name) <> ''
  -- AND tt.id = <tournament_template_id>

ORDER BY sort_order, violation_types, stage_name;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-049
    -- Name - EVENT_NAME_FORMAT_INVALID
    -- What it does: Finds each distinct active event name that breaks at least one text-hygiene rule - edge or doubled spacing, a control character, a definite text corruption such as an HTML entity, a replacement character, a non-breaking or zero-width space or a double-encoded byte sequence, a non-ASCII character, a hyphen without surrounding spaces, a year glued to a word, a capitalisation shape a proof-read name does not take, a placeholder name or a numeric-only name - naming every rule the name breaks and how many objects carry it, reporting one row per offending name rather than one per object repeating it, together with a coverage count of all distinct eligible names.
    'Name_Format_Invalid' AS check_type,
    MIN(x.object_name) AS event_name,
    x.violation_types,
    COUNT(DISTINCT x.object_id) AS affected_object_count,
    MIN(x.object_id) AS sample_object_id,
    MIN(x.template_name) AS sample_template_name,
    MIN(x.stage_name) AS sample_stage_name,
    NULL AS eligible_count,
    0 AS sort_order
FROM (
    SELECT
        e.id AS object_id,
        e.name AS object_name,
        -- The grouping key is binary: under the column's case-insensitive collation two
        -- spellings that differ only in case would collapse into one group, which is the
        -- distinction GLOBAL-DQ-050 exists to report.
        (CONVERT(e.name USING utf8mb4) COLLATE utf8mb4_bin) AS name_bin,
        tt.name AS template_name,
        ts.name AS stage_name,
        CONCAT_WS(', ',
            IF(CHAR_LENGTH(e.name) <> CHAR_LENGTH(TRIM(e.name)), 'LEADING_OR_TRAILING_SPACE', NULL),
            IF(e.name LIKE '%  %', 'DOUBLE_SPACE', NULL),
            IF(e.name REGEXP '[[:cntrl:]]', 'CONTROL_CHARACTER', NULL),
            -- The five rules below name a definite corruption. NON_ASCII_CHARACTER
            -- that follows cannot: it fires on a legitimate diacritic just as readily,
            -- so a corrupted name is reported under its own verdict as well.
            IF(e.name LIKE '%&#%' OR LOWER(e.name) REGEXP '&(amp|quot|apos|lt|gt|nbsp);', 'HTML_ENTITY', NULL),
            IF(HEX(e.name) LIKE '%EFBFBD%', 'REPLACEMENT_CHARACTER', NULL),
            IF(HEX(e.name) LIKE '%C2A0%', 'NON_BREAKING_SPACE', NULL),
            IF(HEX(e.name) LIKE '%E2808B%', 'ZERO_WIDTH_SPACE', NULL),
            IF(HEX(e.name) LIKE '%C383%' OR HEX(e.name) LIKE '%C382%', 'MOJIBAKE_DOUBLE_ENCODED', NULL),
            IF(LENGTH(e.name) <> CHAR_LENGTH(e.name), 'NON_ASCII_CHARACTER', NULL),
            IF(e.name REGEXP '[^ ]-|-[^ ]', 'HYPHEN_WITHOUT_SPACES', NULL),
            IF((CONVERT(e.name USING utf8mb4) COLLATE utf8mb4_bin) REGEXP '[A-Za-z][12][0-9][0-9][0-9]|[12][0-9][0-9][0-9][A-Za-z]', 'YEAR_GLUED_TO_WORD', NULL),
            IF((CONVERT(e.name USING utf8mb4) COLLATE utf8mb4_bin) REGEXP '[A-Z][A-Z][a-z]', 'DOUBLE_CAPITAL', NULL),
            IF((CONVERT(e.name USING utf8mb4) COLLATE utf8mb4_bin) REGEXP '[A-Za-z]'
               AND (CONVERT(e.name USING utf8mb4) COLLATE utf8mb4_bin) NOT REGEXP '[a-z]', 'ALL_UPPERCASE', NULL),
            IF((CONVERT(e.name USING utf8mb4) COLLATE utf8mb4_bin) REGEXP '^[a-z]', 'STARTS_LOWERCASE', NULL),
            IF(LOWER(TRIM(e.name)) IN ('test','testing','temp','tmp','xxx','asd','qwe','tbd','tba','n/a','undefined','event','new event'), 'PLACEHOLDER_NAME', NULL),
            IF(TRIM(e.name) REGEXP '^[0-9]+$', 'NUMERIC_ONLY_NAME', NULL)
        ) AS violation_types
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    WHERE e.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      AND e.name IS NOT NULL
      AND TRIM(e.name) <> ''
      -- AND tt.id = <tournament_template_id>
) x
WHERE x.violation_types <> ''
GROUP BY x.name_bin, x.violation_types

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT (CONVERT(e.name USING utf8mb4) COLLATE utf8mb4_bin)) AS eligible_count,
    1 AS sort_order
    FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND e.name IS NOT NULL
  AND TRIM(e.name) <> ''
  -- AND tt.id = <tournament_template_id>

ORDER BY sort_order, violation_types, event_name;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-050
    -- Name - TOURNAMENT_STAGE_NAME_CASE_INCONSISTENT
    -- What it does: Finds each active tournament-stage name spelling that loses to a more common spelling of the same name within the sport - identical once case and spacing are ignored, different byte for byte - reporting only the losing spelling with the dominant one beside it rather than every stage in the disagreeing group, together with a coverage count of all distinct eligible stage name spellings.
    CASE
        WHEN v.occurrence_count = v.dominant_count THEN 'NAME_CASE_NO_DOMINANT_SPELLING'
        ELSE 'NAME_CASE_MINORITY_SPELLING'
    END AS check_type,
    v.stage_name,
    v.dominant_spelling,
    v.occurrence_count,
    v.dominant_count,
    v.variant_count,
    v.sample_tournament_stage_id,
    v.sample_template_name,
    NULL AS eligible_count,
    0 AS sort_order
FROM (
    SELECT
        a.stage_name,
        a.occurrence_count,
        a.sample_tournament_stage_id,
        a.sample_template_name,
        MAX(a.occurrence_count) OVER (PARTITION BY a.name_normalized) AS dominant_count,
        FIRST_VALUE(a.stage_name) OVER (
            PARTITION BY a.name_normalized ORDER BY a.occurrence_count DESC, a.stage_name
        ) AS dominant_spelling,
        ROW_NUMBER() OVER (
            PARTITION BY a.name_normalized ORDER BY a.occurrence_count DESC, a.stage_name
        ) AS spelling_rank,
        COUNT(*) OVER (PARTITION BY a.name_normalized) AS variant_count
    FROM (
        -- One row per distinct spelling. The binary grouping key is what keeps the
        -- variants apart: the column collation folds case, so an ordinary GROUP BY would
        -- merge the very spellings this check exists to separate.
        SELECT
            LOWER(REPLACE(TRIM(ts.name), ' ', '')) AS name_normalized,
            (CONVERT(ts.name USING utf8mb4) COLLATE utf8mb4_bin) AS stage_name,
            COUNT(DISTINCT ts.id) AS occurrence_count,
            MIN(ts.id) AS sample_tournament_stage_id,
            MIN(tt.name) AS sample_template_name
        FROM tournament_stage ts
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
        WHERE ts.del = 'no'
          AND tt.sportFK = {{SPORT_ID}}
          AND ts.name IS NOT NULL
          AND TRIM(ts.name) <> ''
          -- AND tt.id = <tournament_template_id>
        GROUP BY name_normalized, stage_name
    ) a
) v
-- The dominant spelling is context, not a finding: reporting it would put the correct
-- name back among the rows to review, which is what this check was changed to stop.
WHERE v.variant_count > 1
  AND v.spelling_rank > 1

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT (CONVERT(ts.name USING utf8mb4) COLLATE utf8mb4_bin)) AS eligible_count,
    1 AS sort_order
FROM tournament_stage ts
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE ts.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND ts.name IS NOT NULL
  AND TRIM(ts.name) <> ''
  -- AND tt.id = <tournament_template_id>

ORDER BY sort_order, dominant_spelling, stage_name;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-061
    -- Name - EVENT_STATUS_TIME_CONFLICT
    -- What it does: Finds active events whose status contradicts their own start date, being either a finished event dated in the future or a not-started event whose start date is older than the sport's staleness window, with template, stage and status context and the number of days elapsed, together with a coverage count of all eligible finished and not-started events.
    'Status_Time_Conflict' AS check_type,
    CASE
        WHEN e.status_type = 'finished' THEN 'FINISHED_WITH_FUTURE_STARTDATE'
        ELSE 'NOT_STARTED_LONG_PAST'
    END AS conflict_type,
    e.id AS event_id,
    e.name AS event_name,
    tt.name AS tournament_template_name,
    ts.name AS tournament_stage_name,
    e.status_type,
    e.status_descFK,
    CAST(e.startdate AS CHAR) AS startdate,
    DATEDIFF(NOW(), e.startdate) AS days_past_start,
    NULL AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND e.startdate IS NOT NULL
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND (
      (e.status_type = 'finished' AND e.startdate > NOW())
      OR (
          e.status_descFK IN ({{NOT_STARTED_DESC_LIST}})
          AND e.startdate < DATE_SUB(NOW(), INTERVAL {{STALE_NOT_STARTED_DAYS}} DAY)
      )
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND e.startdate IS NOT NULL
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND (
      e.status_type = 'finished'
      OR e.status_descFK IN ({{NOT_STARTED_DESC_LIST}})
  )
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-062
    -- Name - EVENT_DUPLICATE_BY_METADATA
    -- What it does: Finds groups of more than one active event sharing the same tournament stage, discipline set, exact start date, name and identical participant set, separating a group of empty event shells from one repeating the same competitors, so parallel heats that legitimately share a name and slot are excluded by their disjoint participant sets, together with a coverage count of all eligible named events.
    'Event_Duplicate_By_Metadata' AS check_type,
    CASE WHEN d.participant_key = '' THEN 'EMPTY_SHELLS' ELSE 'IDENTICAL_PARTICIPANTS' END AS duplicate_kind,
    d.tournament_template_name,
    d.tournament_stage_id,
    d.tournament_stage_name,
    d.event_name,
    CAST(d.startdate AS CHAR) AS startdate,
    d.discipline_key,
    COUNT(*) AS duplicate_event_count,
    GROUP_CONCAT(d.event_id ORDER BY d.event_id) AS event_ids,
    SUBSTRING(GROUP_CONCAT(DISTINCT d.round_typeFK ORDER BY d.round_typeFK), 1, 50) AS round_types_seen,
    NULL AS eligible_count
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate,
        e.round_typeFK,
        ts.id AS tournament_stage_id,
        ts.name AS tournament_stage_name,
        tt.name AS tournament_template_name,
        COALESCE((
            SELECT GROUP_CONCAT(DISTINCT od.disciplineFK ORDER BY od.disciplineFK)
            FROM object_discipline od
            WHERE od.object_typeFK = 5
              AND od.objectFK = e.id
              AND od.del = 'no'
        ), '') AS discipline_key,
        COALESCE((
            SELECT GROUP_CONCAT(DISTINCT ep.participantFK ORDER BY ep.participantFK)
            FROM event_participants ep
            WHERE ep.eventFK = e.id
              AND ep.del = 'no'
        ), '') AS participant_key
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    WHERE e.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      AND e.name IS NOT NULL
      AND TRIM(e.name) <> ''
      AND e.startdate IS NOT NULL
      -- AND tt.id = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
) d
GROUP BY d.tournament_template_name, d.tournament_stage_id, d.tournament_stage_name,
         d.event_name, d.startdate, d.discipline_key, d.participant_key
HAVING COUNT(*) > 1

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND e.name IS NOT NULL
  AND TRIM(e.name) <> ''
  AND e.startdate IS NOT NULL
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-063
    -- Name - TOURNAMENT_NO_STAGES
    -- What it does: Finds active tournaments, excluding IOC-purpose templates, with zero active tournament stages, so an individual empty tournament is reported even when its own template holds other populated tournaments and therefore never reaches GLOBAL-DQ-001, together with a coverage count of all eligible tournaments.
    'No_Stages' AS check_type,
    t.id AS tournament_id,
    t.name AS tournament_name,
    tt.id AS tournament_template_id,
    tt.name AS tournament_template_name,
    NULL AS eligible_count
FROM tournament t
JOIN tournament_template tt
  ON tt.id = t.tournament_templateFK
 AND tt.del = 'no'
WHERE t.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
  AND NOT EXISTS (
      SELECT 1
      FROM tournament_stage ts
      WHERE ts.tournamentFK = t.id
        AND ts.del = 'no'
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL,
    COUNT(DISTINCT t.id) AS eligible_count
FROM tournament t
JOIN tournament_template tt
  ON tt.id = t.tournament_templateFK
 AND tt.del = 'no'
WHERE t.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-073
    -- Name - EVENT_SETTINGS_UNEXPECTED_MEDAL_RELATED_FOR_NON_FINAL
    -- What it does: Finds active, finished events whose round type is not a Final that carry an active event property named medal_related with value yes, with round type, template, tournament and stage name context, together with a coverage count of all eligible non-Final finished events.
    'Unexpected_Medal_Related_Property' AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    e.round_typeFK,
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
  AND e.round_typeFK NOT IN ({{FINAL_ROUND_TYPE_LIST}})
  AND e.status_type = 'finished'
  AND e.status_descFK = 6
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND EXISTS (
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
    NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND e.round_typeFK NOT IN ({{FINAL_ROUND_TYPE_LIST}})
  AND e.status_type = 'finished'
  AND e.status_descFK = 6
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-074
    -- Name - EVENT_MISSING_VENUE
    -- What it does: Finds active events that resolve to no active venue, either because neither the event nor its tournament stage carries a venue_object link or because a link they do carry names a venue that does not resolve, separating the two, with template, tournament and stage name context, together with a coverage count of all eligible active events.
    CASE
        WHEN x.broken_links > 0 THEN 'VENUE_LINK_UNRESOLVABLE'
        ELSE 'NO_VENUE_ON_EVENT_OR_STAGE'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.template_name,
    x.tournament_name,
    x.stage_name,
    NULL AS eligible_count
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        tt.name AS template_name,
        t.name AS tournament_name,
        ts.name AS stage_name,
        -- venue_object is the only mechanism attaching a venue to a hierarchy object, per
        -- DATABASE.md: no venueFK column exists outside the venue tables and object_relation
        -- does not carry one. The stage is read as well as the event, because a championship
        -- held at one site records it once on the stage rather than on every event under it.
        -- Joined rather than asked per event: a correlated count over venue_object scans it
        -- once for every event in the sport and times the statement out.
        COUNT(DISTINCT ve.id) + COUNT(DISTINCT vt.id) AS resolved_venues,
        COUNT(DISTINCT CASE WHEN ve.id IS NULL THEN voe.id END)
            + COUNT(DISTINCT CASE WHEN vt.id IS NULL THEN vot.id END) AS broken_links
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    LEFT JOIN venue_object voe ON voe.object_typeFK = 5 AND voe.objectFK = e.id AND voe.del = 'no'
    LEFT JOIN venue ve ON ve.id = voe.venueFK AND ve.del = 'no'
    LEFT JOIN venue_object vot ON vot.object_typeFK = 4 AND vot.objectFK = ts.id AND vot.del = 'no'
    LEFT JOIN venue vt ON vt.id = vot.venueFK AND vt.del = 'no'
    WHERE e.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      -- AND tt.id = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY e.id, e.name, e.startdate, tt.name, t.name, ts.name
) x
WHERE x.resolved_venues = 0

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
    -- CheckID - GLOBAL-DQ-075
    -- Name - EVENT_ROUND_TYPE_NOT_IN_EXPECTED_SET
    -- What it does: Finds active events whose round_typeFK resolves to a real round type that is outside the set the sport is confirmed to contest, with the offending round type and its name, template, tournament and stage name context, together with a coverage count of all eligible active events carrying a resolvable round type.
    'Round_Type_Not_Expected' AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    e.round_typeFK,
    rt.name AS round_type_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    ts.name AS stage_name,
    NULL AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN round_type rt ON rt.id = e.round_typeFK
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  -- A NULL or dangling round_typeFK is GLOBAL-DQ-006's finding, so the join to round_type
  -- keeps this statement to the different question: the value resolves, but to a round the
  -- sport does not contest.
  AND e.round_typeFK NOT IN ({{ROUND_TYPE_LIST}})

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN round_type rt ON rt.id = e.round_typeFK
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-078
    -- Name - TOURNAMENT_NAME_FORMAT_INVALID
    -- What it does: Finds each distinct active tournament name, excluding IOC-purpose templates, that breaks at least one text-hygiene rule - edge or doubled spacing, a control character, a definite text corruption such as an HTML entity, a replacement character, a non-breaking or zero-width space or a double-encoded byte sequence, a non-ASCII character, a hyphen without surrounding spaces, a year glued to a word, a capitalisation shape a proof-read name does not take, a placeholder name or a numeric-only name that is not a bare season year - naming every rule the name breaks and how many objects carry it, reporting one row per offending name rather than one per object repeating it, together with a coverage count of all distinct eligible names.
    'Name_Format_Invalid' AS check_type,
    MIN(x.object_name) AS tournament_name,
    x.violation_types,
    COUNT(DISTINCT x.object_id) AS affected_object_count,
    MIN(x.object_id) AS sample_object_id,
    MIN(x.template_name) AS sample_template_name,
    NULL AS eligible_count,
    0 AS sort_order
FROM (
    SELECT
        t.id AS object_id,
        t.name AS object_name,
        (CONVERT(t.name USING utf8mb4) COLLATE utf8mb4_bin) AS name_bin,
        tt.name AS template_name,
        CONCAT_WS(', ',
            IF(CHAR_LENGTH(t.name) <> CHAR_LENGTH(TRIM(t.name)), 'LEADING_OR_TRAILING_SPACE', NULL),
            IF(t.name LIKE '%  %', 'DOUBLE_SPACE', NULL),
            IF(t.name REGEXP '[[:cntrl:]]', 'CONTROL_CHARACTER', NULL),
            IF(t.name LIKE '%&#%' OR LOWER(t.name) REGEXP '&(amp|quot|apos|lt|gt|nbsp);', 'HTML_ENTITY', NULL),
            IF(HEX(t.name) LIKE '%EFBFBD%', 'REPLACEMENT_CHARACTER', NULL),
            IF(HEX(t.name) LIKE '%C2A0%', 'NON_BREAKING_SPACE', NULL),
            IF(HEX(t.name) LIKE '%E2808B%', 'ZERO_WIDTH_SPACE', NULL),
            IF(HEX(t.name) LIKE '%C383%' OR HEX(t.name) LIKE '%C382%', 'MOJIBAKE_DOUBLE_ENCODED', NULL),
            IF(LENGTH(t.name) <> CHAR_LENGTH(t.name), 'NON_ASCII_CHARACTER', NULL),
            IF(t.name REGEXP '[^ ]-|-[^ ]', 'HYPHEN_WITHOUT_SPACES', NULL),
            IF((CONVERT(t.name USING utf8mb4) COLLATE utf8mb4_bin) REGEXP '[A-Za-z][12][0-9][0-9][0-9]|[12][0-9][0-9][0-9][A-Za-z]', 'YEAR_GLUED_TO_WORD', NULL),
            IF((CONVERT(t.name USING utf8mb4) COLLATE utf8mb4_bin) REGEXP '[A-Z][A-Z][a-z]', 'DOUBLE_CAPITAL', NULL),
            IF((CONVERT(t.name USING utf8mb4) COLLATE utf8mb4_bin) REGEXP '[A-Za-z]'
               AND (CONVERT(t.name USING utf8mb4) COLLATE utf8mb4_bin) NOT REGEXP '[a-z]', 'ALL_UPPERCASE', NULL),
            IF((CONVERT(t.name USING utf8mb4) COLLATE utf8mb4_bin) REGEXP '^[a-z]', 'STARTS_LOWERCASE', NULL),
            IF(LOWER(TRIM(t.name)) IN ('test','testing','temp','tmp','xxx','asd','qwe','tbd','tba','n/a','undefined','tournament','new tournament'), 'PLACEHOLDER_NAME', NULL),
            -- A tournament named for its season alone is the norm in this database, so a
            -- bare year is left out of the rule that catches a numeric-only stage name.
            IF(TRIM(t.name) REGEXP '^[0-9]+$' AND TRIM(t.name) NOT REGEXP '^[12][0-9][0-9][0-9]$', 'NUMERIC_ONLY_NAME', NULL)
        ) AS violation_types
    FROM tournament t
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    WHERE t.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      AND t.name IS NOT NULL
      AND TRIM(t.name) <> ''
      -- AND tt.id = <tournament_template_id>
) x
WHERE x.violation_types <> ''
GROUP BY x.name_bin, x.violation_types

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT (CONVERT(t.name USING utf8mb4) COLLATE utf8mb4_bin)) AS eligible_count,
    1 AS sort_order
FROM tournament t
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE t.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND t.name IS NOT NULL
  AND TRIM(t.name) <> ''
  -- AND tt.id = <tournament_template_id>

ORDER BY sort_order, violation_types, tournament_name;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-079
    -- Name - TEMPLATE_NAME_FORMAT_INVALID
    -- What it does: Finds each distinct active tournament template name, excluding IOC-purpose templates, that breaks at least one text-hygiene rule - edge or doubled spacing, a control character, a definite text corruption such as an HTML entity, a replacement character, a non-breaking or zero-width space or a double-encoded byte sequence, a non-ASCII character, a hyphen without surrounding spaces, a year glued to a word, a capitalisation shape a proof-read name does not take, a placeholder name or a numeric-only name - naming every rule the name breaks and how many objects carry it, reporting one row per offending name rather than one per object repeating it, together with a coverage count of all distinct eligible names.
    'Name_Format_Invalid' AS check_type,
    MIN(x.object_name) AS template_name,
    x.violation_types,
    COUNT(DISTINCT x.object_id) AS affected_object_count,
    MIN(x.object_id) AS sample_object_id,
    NULL AS eligible_count,
    0 AS sort_order
FROM (
    SELECT
        tt.id AS object_id,
        tt.name AS object_name,
        (CONVERT(tt.name USING utf8mb4) COLLATE utf8mb4_bin) AS name_bin,
        CONCAT_WS(', ',
            IF(CHAR_LENGTH(tt.name) <> CHAR_LENGTH(TRIM(tt.name)), 'LEADING_OR_TRAILING_SPACE', NULL),
            IF(tt.name LIKE '%  %', 'DOUBLE_SPACE', NULL),
            IF(tt.name REGEXP '[[:cntrl:]]', 'CONTROL_CHARACTER', NULL),
            IF(tt.name LIKE '%&#%' OR LOWER(tt.name) REGEXP '&(amp|quot|apos|lt|gt|nbsp);', 'HTML_ENTITY', NULL),
            IF(HEX(tt.name) LIKE '%EFBFBD%', 'REPLACEMENT_CHARACTER', NULL),
            IF(HEX(tt.name) LIKE '%C2A0%', 'NON_BREAKING_SPACE', NULL),
            IF(HEX(tt.name) LIKE '%E2808B%', 'ZERO_WIDTH_SPACE', NULL),
            IF(HEX(tt.name) LIKE '%C383%' OR HEX(tt.name) LIKE '%C382%', 'MOJIBAKE_DOUBLE_ENCODED', NULL),
            IF(LENGTH(tt.name) <> CHAR_LENGTH(tt.name), 'NON_ASCII_CHARACTER', NULL),
            IF(tt.name REGEXP '[^ ]-|-[^ ]', 'HYPHEN_WITHOUT_SPACES', NULL),
            IF((CONVERT(tt.name USING utf8mb4) COLLATE utf8mb4_bin) REGEXP '[A-Za-z][12][0-9][0-9][0-9]|[12][0-9][0-9][0-9][A-Za-z]', 'YEAR_GLUED_TO_WORD', NULL),
            IF((CONVERT(tt.name USING utf8mb4) COLLATE utf8mb4_bin) REGEXP '[A-Z][A-Z][a-z]', 'DOUBLE_CAPITAL', NULL),
            IF((CONVERT(tt.name USING utf8mb4) COLLATE utf8mb4_bin) REGEXP '[A-Za-z]'
               AND (CONVERT(tt.name USING utf8mb4) COLLATE utf8mb4_bin) NOT REGEXP '[a-z]', 'ALL_UPPERCASE', NULL),
            IF((CONVERT(tt.name USING utf8mb4) COLLATE utf8mb4_bin) REGEXP '^[a-z]', 'STARTS_LOWERCASE', NULL),
            IF(LOWER(TRIM(tt.name)) IN ('test','testing','temp','tmp','xxx','asd','qwe','tbd','tba','n/a','undefined','template','new template'), 'PLACEHOLDER_NAME', NULL),
            IF(TRIM(tt.name) REGEXP '^[0-9]+$', 'NUMERIC_ONLY_NAME', NULL)
        ) AS violation_types
    FROM tournament_template tt
    WHERE tt.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      AND TRIM(tt.name) <> ''
      -- AND tt.id = <tournament_template_id>
) x
WHERE x.violation_types <> ''
GROUP BY x.name_bin, x.violation_types

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL,
    COUNT(DISTINCT (CONVERT(tt.name USING utf8mb4) COLLATE utf8mb4_bin)) AS eligible_count,
    1 AS sort_order
FROM tournament_template tt
WHERE tt.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND TRIM(tt.name) <> ''
  -- AND tt.id = <tournament_template_id>

ORDER BY sort_order, violation_types, template_name;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-080
    -- Name - TOURNAMENT_NAME_SEASON_CONTRADICTS_DATES
    -- What it does: Finds active tournaments, excluding IOC-purpose templates, whose name carries a year that none of their own events falls in, or whose name carries a two-year season span while every one of their events falls in a single calendar year, separating the two, with the years the events actually occupy and template name context, together with a coverage count of all eligible tournaments whose name carries a year and that hold at least one dated active event.
    CASE
        WHEN x.name_has_season = 1 AND x.event_years = 1 THEN 'SEASON_NAME_ON_SINGLE_YEAR'
        ELSE 'NAME_YEAR_MATCHES_NO_EVENT'
    END AS check_type,
    x.tournament_id,
    x.tournament_name,
    x.template_name,
    x.years_present,
    x.event_count,
    NULL AS eligible_count
FROM (
    SELECT
        t.id AS tournament_id,
        t.name AS tournament_name,
        tt.name AS template_name,
        COUNT(DISTINCT YEAR(e.startdate)) AS event_years,
        COUNT(DISTINCT e.id) AS event_count,
        GROUP_CONCAT(DISTINCT YEAR(e.startdate) ORDER BY 1 SEPARATOR ', ') AS years_present,
        -- REGEXP_SUBSTR is not assumed to exist, so the name is tested for a shape rather
        -- than parsed. A season span is two four-digit years joined by a separator.
        (t.name REGEXP '[12][0-9][0-9][0-9][/-][12][0-9][0-9][0-9]') AS name_has_season,
        MAX(t.name LIKE CONCAT('%', YEAR(e.startdate), '%')) AS name_matches_an_event_year
    FROM tournament t
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
    JOIN event e ON e.tournament_stageFK = ts.id AND e.del = 'no' AND e.startdate IS NOT NULL
    WHERE t.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      AND t.name REGEXP '[12][0-9][0-9][0-9]'
      -- AND tt.id = <tournament_template_id>
    GROUP BY t.id, t.name, tt.name
) x
WHERE x.name_matches_an_event_year = 0
   OR (x.name_has_season = 1 AND x.event_years = 1)

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT t.id) AS eligible_count
FROM tournament t
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
JOIN event e ON e.tournament_stageFK = ts.id AND e.del = 'no' AND e.startdate IS NOT NULL
WHERE t.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND t.name REGEXP '[12][0-9][0-9][0-9]'
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-081
    -- Name - TEMPLATE_TOURNAMENT_YEAR_GAP
    -- What it does: Finds active tournament templates, excluding IOC-purpose templates, that run annually by holding a dated event in more than half the calendar years they span and reach the confirmed minimum number of years, yet have at least one interior year with no event at all, with the first and last year, the number of years present, the span, the number missing and the years themselves, together with a coverage count of all eligible templates reaching that minimum.
    'Template_Year_Gap' AS check_type,
    x.template_id,
    x.template_name,
    x.first_year,
    x.last_year,
    x.years_with_tournaments,
    x.span_years,
    x.span_years - x.years_with_tournaments AS years_missing,
    x.years_present,
    NULL AS eligible_count
FROM (
    SELECT
        tt.id AS template_id,
        tt.name AS template_name,
        MIN(YEAR(e.startdate)) AS first_year,
        MAX(YEAR(e.startdate)) AS last_year,
        COUNT(DISTINCT YEAR(e.startdate)) AS years_with_tournaments,
        MAX(YEAR(e.startdate)) - MIN(YEAR(e.startdate)) + 1 AS span_years,
        GROUP_CONCAT(DISTINCT YEAR(e.startdate) ORDER BY 1 SEPARATOR ', ') AS years_present
    FROM tournament_template tt
    JOIN tournament t ON t.tournament_templateFK = tt.id AND t.del = 'no'
    JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
    JOIN event e ON e.tournament_stageFK = ts.id AND e.del = 'no' AND e.startdate IS NOT NULL
    WHERE tt.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      -- AND tt.id = <tournament_template_id>
    GROUP BY tt.id, tt.name
) x
-- Absence is not provable from inside the database, but a hole in a series that is
-- otherwise annual is. Annual is defined here rather than parameterised: a series holding
-- an event in more than half the years it spans runs every year, while a biennial or
-- quadrennial one cannot reach that ratio and is therefore never reported.
WHERE x.years_with_tournaments >= {{SERIES_MIN_YEARS}}
  AND x.years_with_tournaments < x.span_years
  AND x.years_with_tournaments * 2 > x.span_years

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT y.template_id) AS eligible_count
FROM (
    SELECT
        tt.id AS template_id,
        COUNT(DISTINCT YEAR(e.startdate)) AS years_with_tournaments
    FROM tournament_template tt
    JOIN tournament t ON t.tournament_templateFK = tt.id AND t.del = 'no'
    JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
    JOIN event e ON e.tournament_stageFK = ts.id AND e.del = 'no' AND e.startdate IS NOT NULL
    WHERE tt.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      -- AND tt.id = <tournament_template_id>
    GROUP BY tt.id
) y
WHERE y.years_with_tournaments >= {{SERIES_MIN_YEARS}}
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-082
    -- Name - TOURNAMENT_STAGE_EVENT_DISCIPLINE_INCONSISTENT
    -- What it does: Finds active tournament stages whose own active events do not agree on a discipline, so one stage groups events contested in more than one, with the disciplines involved, the number of events and template and tournament name context, together with a coverage count of all eligible stages holding at least one active event that carries a discipline.
    'Stage_Event_Discipline_Inconsistent' AS check_type,
    x.stage_id,
    x.stage_name,
    x.template_name,
    x.tournament_name,
    x.distinct_disciplines,
    x.discipline_list,
    x.event_count,
    NULL AS eligible_count
FROM (
    SELECT
        ts.id AS stage_id,
        ts.name AS stage_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        COUNT(DISTINCT od.disciplineFK) AS distinct_disciplines,
        COUNT(DISTINCT e.id) AS event_count,
        GROUP_CONCAT(DISTINCT d.name ORDER BY 1 SEPARATOR ', ') AS discipline_list
    FROM tournament_stage ts
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN event e ON e.tournament_stageFK = ts.id AND e.del = 'no'
    JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
    JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
    WHERE ts.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      -- AND tt.id = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY ts.id, ts.name, tt.name, t.name
) x
-- Asks whether a discipline is right, where GLOBAL-DQ-015 only asks whether one is there.
-- The stage is what makes the question answerable without a vocabulary: its own events
-- disagree with each other, which needs no judgement about which of them is correct.
WHERE x.distinct_disciplines > 1

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ts.id) AS eligible_count
FROM tournament_stage ts
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN event e ON e.tournament_stageFK = ts.id AND e.del = 'no'
JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
WHERE ts.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;
