SELECT
    -- CheckID - GLOBAL-DQ-001
    -- Name - TEMPLATE_NO_TOURNAMENTS_OR_STAGES
    -- What it does: Flags tournament templates with no tournaments, or whose tournaments contain no stages.
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
-- What it does, stated in full: Finds tournament templates with no tournaments, or with
-- tournaments but no stages under any of them.
-- The client's season boundary lands on one half of that and not the other, because the halves
-- assert different things. A template holding no tournament at all is broken in any era, so
-- that branch reads every tournament and takes no season condition. A template whose
-- tournaments hold no stage is only a defect for the seasons the client bought, so that branch
-- keeps to them.
-- Between the two sits a template whose every season predates the boundary. It is neither
-- broken nor auditable - it is out of client scope - so it leaves the population instead of
-- being reported as empty. Seven templates across the eleven documented sports sit there,
-- measured 2026-08-20: Cycling 4, Soccer 2, Equestrian 1. Filtering both halves would have put
-- all seven on a board forever with nothing anybody could do about them.
FROM tournament_template tt
WHERE tt.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND tt.id NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND tt.id = <tournament_template_id>
  AND (
      NOT EXISTS (
          SELECT 1 FROM tournament t1
          WHERE t1.tournament_templateFK = tt.id AND t1.del = 'no'
      )
      OR EXISTS (
          SELECT 1 FROM tournament t1
          WHERE t1.tournament_templateFK = tt.id AND t1.del = 'no'
            AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t1.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t1.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
      )
  )
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
            AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t3.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t3.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
  AND tt.id NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND tt.id = <tournament_template_id>
  AND (
      NOT EXISTS (
          SELECT 1 FROM tournament t1
          WHERE t1.tournament_templateFK = tt.id AND t1.del = 'no'
      )
      OR EXISTS (
          SELECT 1 FROM tournament t1
          WHERE t1.tournament_templateFK = tt.id AND t1.del = 'no'
            AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t1.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t1.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
      )
  )
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-002
    -- Name - TOURNAMENT_STAGE_MISSING_AGE_CLASS
    -- What it does: Flags tournament stages that have no age-class relation.
    'Missing_Age_Class' AS check_type,
    ts.id AS tournament_stage_id,
    ts.name AS tournament_stage_name,
    NULL AS eligible_count
-- What it does, stated in full: Finds tournament stages with no age-class relation.
FROM tournament_stage ts
JOIN tournament t
  ON t.id = ts.tournamentFK
 AND t.del = 'no'
JOIN tournament_template tt
  ON tt.id = t.tournament_templateFK
 AND tt.del = 'no'
WHERE ts.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-003
    -- Name - TOURNAMENT_STAGE_NO_EVENTS
    -- What it does: Flags tournament stages that have no events.
    'No_Events' AS check_type,
    ts.id AS tournament_stage_id,
    ts.name AS tournament_stage_name,
    NULL AS eligible_count
-- What it does, stated in full: Finds tournament stages holding no events.
FROM tournament_stage ts
JOIN tournament t
  ON t.id = ts.tournamentFK
 AND t.del = 'no'
JOIN tournament_template tt
  ON tt.id = t.tournament_templateFK
 AND tt.del = 'no'
WHERE ts.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-004
    -- Name - TOURNAMENT_STAGE_DATE_RANGE_MISMATCH
    -- What it does: Flags stages whose dates do not match the first and last event dates inside the stage.
    'Date_Range_Mismatch' AS check_type,
    ts.id AS tournament_stage_id,
    ts.name AS tournament_stage_name,
    ts.startdate AS stage_startdate,
    ts.enddate AS stage_enddate,
    MIN(e.startdate) AS earliest_event_startdate,
    MAX(e.startdate) AS latest_event_startdate,
    NULL AS eligible_count
-- What it does, stated in full: Finds tournament stages whose start or end date does not
-- match the earliest and latest event date inside them.
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
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
    -- What it does: Flags tournament stages with a missing start date or end date.
    'Missing_Start_Or_End_Date' AS check_type,
    ts.id AS tournament_stage_id,
    ts.name AS tournament_stage_name,
    CONCAT_WS(', ',
        IF(ts.startdate IS NULL, 'startdate', NULL),
        IF(ts.enddate IS NULL, 'enddate', NULL)
    ) AS missing_fields,
    NULL AS eligible_count
-- What it does, stated in full: Finds tournament stages with a NULL start or end date.
FROM tournament_stage ts
JOIN tournament t
  ON t.id = ts.tournamentFK
 AND t.del = 'no'
JOIN tournament_template tt
  ON tt.id = t.tournament_templateFK
 AND tt.del = 'no'
WHERE ts.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-006
    -- Name - EVENT_MISSING_ROUND_TYPE
    -- What it does: Flags events with no round type or with a round type that no longer exists.
    'Missing_Round_Type' AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    tt.name AS template_name,
    t.name AS tournament_name,
    ts.name AS stage_name,
    e.round_typeFK,
    NULL AS eligible_count
-- What it does, stated in full: Finds events with no round type, or one that resolves to no
-- round_type row.
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
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
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-013
    -- Name - TEMPLATE_MISSING_SET_SUBSET_GENDER_NAME
    -- What it does: Flags tournament templates missing a name, gender, subset relation, or valid tournament set.
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
-- What it does, stated in full: Finds tournament templates missing a name, a gender, a
-- subset relation or a resolvable tournament set.
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
  AND tt.id NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
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
  AND tt.id NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-014
    -- Name - TEMPLATE_STAGE_GENDER_MISMATCH
    -- What it does: Flags stages whose gender differs from the template gender. Mixed and blank values are ignored.
    'Gender_Mismatch' AS check_type,
    tt.id AS tournament_template_id,
    tt.name AS template_name,
    tt.gender AS template_gender,
    ts.id AS tournament_stage_id,
    ts.name AS stage_name,
    ts.gender AS stage_gender,
    NULL AS eligible_count
-- What it does, stated in full: Finds tournament stages whose gender differs from their
-- template's, ignoring mixed and empty on either side.
FROM tournament_stage ts
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE ts.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND ts.gender IS NOT NULL AND TRIM(ts.gender) <> '' AND LOWER(TRIM(ts.gender)) <> 'mixed'
  AND tt.gender IS NOT NULL AND TRIM(tt.gender) <> '' AND LOWER(TRIM(tt.gender)) <> 'mixed'
  AND LOWER(TRIM(ts.gender)) <> LOWER(TRIM(tt.gender))
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>

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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-015
    -- Name - EVENT_SETTINGS_MISSING_DISCIPLINE
    -- What it does: Flags events with no discipline relation.
    'Missing_Discipline' AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    tt.name AS template_name,
    t.name AS tournament_name,
    ts.name AS stage_name,
    NULL AS eligible_count
-- What it does, stated in full: Finds events with no discipline relation.
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
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
    NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-016
    -- Name - EVENT_SETTINGS_MISSING_GENDER
    -- What it does: Flags events whose parent stage has no valid gender.
    'Missing_Gender' AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    tt.name AS template_name,
    t.name AS tournament_name,
    ts.name AS stage_name,
    ts.gender,
    NULL AS eligible_count
-- What it does, stated in full: Finds events whose parent stage carries no usable gender.
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
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
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-034
    -- Name - TOURNAMENT_STAGE_MISSING_CORE_FIELDS
    -- What it does: Flags stages with missing basic data, a placeholder country, or an incorrect host-country setup for International or national stages.
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
-- What it does, stated in full: Finds tournament stages missing a name, gender, country or
-- city, carrying a placeholder country, or holding the host country wrongly - absent where
-- the country is International, or present where the country already names a nation.
            FROM country c
            WHERE c.id = ts.countryFK
              AND c.del = 'no'
        ), 'country', NULL),
        -- A country that resolves to a placeholder row reads as populated to every
        -- IS NULL test, so it is named separately rather than counted as clean.
        -- International is deliberately not one of them here: it is a legitimate value
        -- meaning the stage belongs to no single nation, and it is what makes the host
        -- country required below. The rest of the placeholder list still applies.
        IF(EXISTS (
            SELECT 1
            FROM country c
            WHERE c.id = ts.countryFK
              AND c.del = 'no'
              AND c.name IN ({{PLACEHOLDER_COUNTRY_LIST}})
              AND c.name <> 'International'
        ), 'country_placeholder', NULL),
        -- The host country carries the location only where the country cannot: it exists
        -- to say where an International stage was actually held. Asserting it everywhere
        -- reported every stage of every sport whose country already names a nation.
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
        ) AND EXISTS (
            SELECT 1
            FROM country c
            WHERE c.id = ts.countryFK
              AND c.del = 'no'
              AND c.name = 'International'
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
        ) AND EXISTS (
            SELECT 1
            FROM country c
            WHERE c.id = ts.countryFK
              AND c.del = 'no'
              AND c.name = 'International'
        ), 'host_country_placeholder', NULL),
        -- The mirror: a host country where the country already names the nation adds
        -- nothing and can contradict it.
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
        ) AND NOT EXISTS (
            SELECT 1
            FROM country c
            WHERE c.id = ts.countryFK
              AND c.del = 'no'
              AND c.name = 'International'
        ), 'host_country_unexpected', NULL),
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
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
            AND c.name <> 'International'
      )
      OR (
          NOT EXISTS (
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
          AND EXISTS (
              SELECT 1
              FROM country c
              WHERE c.id = ts.countryFK
                AND c.del = 'no'
                AND c.name = 'International'
          )
      )
      OR (
          EXISTS (
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
          AND EXISTS (
              SELECT 1
              FROM country c
              WHERE c.id = ts.countryFK
                AND c.del = 'no'
                AND c.name = 'International'
          )
      )
      OR (
          EXISTS (
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
          AND NOT EXISTS (
              SELECT 1
              FROM country c
              WHERE c.id = ts.countryFK
                AND c.del = 'no'
                AND c.name = 'International'
          )
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-038
    -- Name - EVENT_SETTINGS_MISSING_MEDAL_RELATED_FOR_MEDAL_ROUND
    -- What it does: Flags finished medal-round events where medal_related is not set to Yes.
    'Missing_Medal_Related_Property' AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    e.round_typeFK AS round_type_id,
    rt.name AS round_type_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    ts.name AS stage_name,
    NULL AS eligible_count
-- What it does, stated in full: Finds finished events on a medal round type carrying no
-- medal_related property set to yes.
-- The round is projected by id and by name together. A sport whose medal list holds more than
-- one round cannot act on the finding without knowing which round it landed on, and the id
-- alone does not say: several sports carry two round_type rows under one name, so a bare
-- number is a decision made blind. The join is a LEFT JOIN because a dangling round_typeFK is
-- GLOBAL-DQ-006's finding, not this one's, and must not silently drop a row from this audit.
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
LEFT JOIN round_type rt ON rt.id = e.round_typeFK AND rt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND e.round_typeFK IN ({{MEDAL_ROUND_TYPE_LIST}})
  AND e.status_type = 'finished'
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
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
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND e.round_typeFK IN ({{MEDAL_ROUND_TYPE_LIST}})
  AND e.status_type = 'finished'
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-048
    -- Name - TOURNAMENT_STAGE_NAME_FORMAT_INVALID
    -- What it does: Finds stage names that break a text-hygiene rule.
    'Name_Format_Invalid' AS check_type,
    MIN(x.object_name) AS stage_name,
    x.violation_types,
    COUNT(DISTINCT x.object_id) AS affected_object_count,
    MIN(x.object_id) AS sample_object_id,
    MIN(x.template_name) AS sample_template_name,
    MIN(x.tournament_name) AS sample_tournament_name,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds tournament-stage names breaking a text-hygiene rule -
-- spacing, control or corrupted characters, hyphenation, capitalisation, a placeholder or a
-- numeric-only name - one row per name, naming every rule it breaks.
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
            -- The terminating semicolon is written \\x{3B} and must stay that way: the Pool cuts
            -- a statement at the first literal ';' even inside quotes, which killed this check
            -- outright. Two backslashes, because the SQL literal eats one before ICU sees it.
            IF(ts.name LIKE '%&#%' OR LOWER(ts.name) REGEXP '&(amp|quot|apos|lt|gt|nbsp)\\x{3B}', 'HTML_ENTITY', NULL),
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
      -- AND t.tournament_templateFK = <tournament_template_id>
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, violation_types, stage_name;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-049
    -- Name - EVENT_NAME_FORMAT_INVALID
    -- What it does: Finds event names that break a text-hygiene rule.
    'Name_Format_Invalid' AS check_type,
    MIN(x.object_name) AS event_name,
    MIN(x.object_startdate) AS earliest_event_startdate,
    MAX(x.object_startdate) AS latest_event_startdate,
    x.violation_types,
    COUNT(DISTINCT x.object_id) AS affected_object_count,
    MIN(x.object_id) AS sample_object_id,
    MIN(x.template_name) AS sample_template_name,
    MIN(x.stage_name) AS sample_stage_name,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds event names breaking a text-hygiene rule - spacing,
-- control or corrupted characters, hyphenation, capitalisation, a placeholder or a numeric-
-- only name - one row per name, naming every rule it breaks.
FROM (
    SELECT
        e.id AS object_id,
        e.name AS object_name,
        e.startdate AS object_startdate,
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
            -- Semicolon as \\x{3B}, never literal: the Pool cuts the statement at the first one.
            IF(e.name LIKE '%&#%' OR LOWER(e.name) REGEXP '&(amp|quot|apos|lt|gt|nbsp)\\x{3B}', 'HTML_ENTITY', NULL),
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
      -- AND t.tournament_templateFK = <tournament_template_id>
) x
WHERE x.violation_types <> ''
GROUP BY x.name_bin, x.violation_types

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, violation_types, event_name;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-050
    -- Name - TOURNAMENT_STAGE_NAME_CASE_INCONSISTENT
    -- What it does: Finds stage names that differ from another only by case or spacing.
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
-- What it does, stated in full: Finds tournament-stage name spellings that lose to a more
-- common spelling of the same name, identical but for case and spacing, with the dominant
-- spelling beside it.
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
          AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
          -- AND t.tournament_templateFK = <tournament_template_id>
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, dominant_spelling, stage_name;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-061
    -- Name - EVENT_STATUS_TIME_CONFLICT
    -- What it does: Finds events whose status does not fit their date.
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
-- What it does, stated in full: Finds events whose status contradicts their own date:
-- finished but dated in the future, or not started and older than the sport's staleness
-- window.
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND e.startdate IS NOT NULL
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
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
    -- What it does: Finds events that look like the same event entered twice: same stage, discipline, date and competitors.
    CASE
        WHEN COUNT(DISTINCT d.startdate) = 1 THEN 'DUPLICATE_SAME_TIMESTAMP'
        ELSE 'DUPLICATE_SAME_DAY_DIFFERENT_TIME'
    END AS check_type,
    CASE WHEN d.participant_key = '' THEN 'EMPTY_SHELLS' ELSE 'IDENTICAL_PARTICIPANTS' END AS duplicate_kind,
    d.tournament_template_name,
    d.tournament_stage_id,
    d.tournament_stage_name,
    GROUP_CONCAT(DISTINCT d.event_name ORDER BY d.event_name SEPARATOR ' | ') AS event_names,
    CAST(MIN(DATE(d.startdate)) AS CHAR) AS event_date,
    GROUP_CONCAT(DISTINCT TIME(d.startdate) ORDER BY TIME(d.startdate) SEPARATOR ', ') AS start_times,
    d.discipline_key,
    COUNT(*) AS duplicate_event_count,
    GROUP_CONCAT(d.event_id ORDER BY d.event_id) AS event_ids,
    SUBSTRING(GROUP_CONCAT(DISTINCT d.round_typeFK ORDER BY d.round_typeFK), 1, 50) AS round_types_seen,
    NULL AS eligible_count
-- What it does, stated in full: Finds events sharing a stage, discipline, calendar day and
-- participant set, separating an exact timestamp match from a same-day one, and empty shells
-- from a repeated competition.
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
) d
-- Two parts of the key are facts about the sport rather than about duplicates, and both are
-- declared because getting either wrong turns the check into noise in one direction or
-- silence in the other.
-- Whether the name belongs in it: a sport whose event name is the pairing that plays it -
-- the sports GLOBAL-DQ-096 applies to - carries nothing in the name that the participant set
-- does not, and its ordering is arbitrary, so the same meeting appears as "A-B" in one row
-- and "B-A" in the other and the name splits apart what the participant key has matched.
-- Those sports record 0. A sport whose names distinguish one entry from another records 1.
-- Whether the slot is the day or the exact moment: a sport that runs the same competitors
-- several times in one day - three motos of one field, all named alike - is separated only
-- by the time they started, so it records 0 and keeps the timestamp. A sport in which one
-- meeting happens once a day records 1, because there a re-import carries a different
-- kick-off and a timestamp key lets every one of those through: the pair differs in a field
-- the key contains, so it never forms a group at all. The exact-timestamp case stays
-- separable either way, and is the stronger of the two, so it keeps its own verdict.
GROUP BY d.tournament_template_name, d.tournament_stage_id, d.tournament_stage_name,
         CASE WHEN {{DUPLICATE_KEY_INCLUDES_EVENT_NAME}} = 1 THEN d.event_name ELSE '' END,
         CASE WHEN {{DUPLICATE_KEY_USES_CALENDAR_DAY}} = 1
              THEN CAST(DATE(d.startdate) AS CHAR) ELSE CAST(d.startdate AS CHAR) END,
         d.discipline_key, d.participant_key
HAVING COUNT(*) > 1

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-063
    -- Name - TOURNAMENT_NO_STAGES
    -- What it does: Flags tournaments that have no stages, even when other tournaments under the same template do have stages.
    'No_Stages' AS check_type,
    t.id AS tournament_id,
    t.name AS tournament_name,
    tt.id AS tournament_template_id,
    tt.name AS tournament_template_name,
    NULL AS eligible_count
-- What it does, stated in full: Finds tournaments holding no stages, including those whose
-- template holds other populated tournaments and so never reaches GLOBAL-DQ-001.
FROM tournament t
JOIN tournament_template tt
  ON tt.id = t.tournament_templateFK
 AND tt.del = 'no'
WHERE t.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-073
    -- Name - EVENT_SETTINGS_UNEXPECTED_MEDAL_RELATED_FOR_NON_MEDAL_ROUND
    -- What it does: Flags finished non-medal-round events where medal_related is incorrectly set to Yes.
    'Unexpected_Medal_Related_Property' AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    e.round_typeFK,
    tt.name AS template_name,
    t.name AS tournament_name,
    ts.name AS stage_name,
    NULL AS eligible_count
-- What it does, stated in full: Finds finished events off a medal round type carrying a
-- medal_related property set to yes.
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND e.round_typeFK NOT IN ({{MEDAL_ROUND_TYPE_LIST}})
  AND e.status_type = 'finished'
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
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
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND e.round_typeFK NOT IN ({{MEDAL_ROUND_TYPE_LIST}})
  AND e.status_type = 'finished'
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-074
    -- Name - EVENT_MISSING_VENUE
    -- What it does: Flags events with no venue link or with a venue link that does not resolve.
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
-- What it does, stated in full: Finds events resolving to no venue, separating no venue link
-- at all from a link naming a venue that does not resolve.
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
      -- AND t.tournament_templateFK = <tournament_template_id>
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-075
    -- Name - EVENT_ROUND_TYPE_NOT_IN_EXPECTED_SET
    -- What it does: Flags events using a round type that is not approved for the sport.
    'Round_Type_Not_Expected' AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    e.round_typeFK,
    rt.name AS round_type_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    ts.name AS stage_name,
    NULL AS eligible_count
-- What it does, stated in full: Finds events whose round type is outside the set the sport
-- is confirmed to contest.
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN round_type rt ON rt.id = e.round_typeFK
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  -- A NULL or dangling round_typeFK is GLOBAL-DQ-006's finding, so the join to round_type
  -- keeps this statement to the different question: the value resolves, but to a round the
  -- sport does not contest.
  AND e.round_typeFK NOT IN ({{ROUND_TYPE_LIST}})

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN round_type rt ON rt.id = e.round_typeFK
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-078
    -- Name - TOURNAMENT_NAME_FORMAT_INVALID
    -- What it does: Finds tournament names that break a text-hygiene rule.
    'Name_Format_Invalid' AS check_type,
    MIN(x.object_name) AS tournament_name,
    x.violation_types,
    COUNT(DISTINCT x.object_id) AS affected_object_count,
    MIN(x.object_id) AS sample_object_id,
    MIN(x.template_name) AS sample_template_name,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds tournament names breaking a text-hygiene rule -
-- spacing, control or corrupted characters, hyphenation, capitalisation, a placeholder, or a
-- numeric-only name that is not a bare season year - one row per name, naming every rule it
-- breaks.
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
            -- Semicolon as \\x{3B}, never literal: the Pool cuts the statement at the first one.
            IF(t.name LIKE '%&#%' OR LOWER(t.name) REGEXP '&(amp|quot|apos|lt|gt|nbsp)\\x{3B}', 'HTML_ENTITY', NULL),
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
      -- AND t.tournament_templateFK = <tournament_template_id>
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, violation_types, tournament_name;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-079
    -- Name - TEMPLATE_NAME_FORMAT_INVALID
    -- What it does: Finds template names that break a text-hygiene rule.
    'Name_Format_Invalid' AS check_type,
    MIN(x.object_name) AS template_name,
    x.violation_types,
    COUNT(DISTINCT x.object_id) AS affected_object_count,
    MIN(x.object_id) AS sample_object_id,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds tournament template names breaking a text-hygiene rule
-- - spacing, control or corrupted characters, hyphenation, capitalisation, a placeholder or
-- a numeric-only name - one row per name, naming every rule it breaks.
FROM (
    SELECT
        tt.id AS object_id,
        tt.name AS object_name,
        (CONVERT(tt.name USING utf8mb4) COLLATE utf8mb4_bin) AS name_bin,
        CONCAT_WS(', ',
            IF(CHAR_LENGTH(tt.name) <> CHAR_LENGTH(TRIM(tt.name)), 'LEADING_OR_TRAILING_SPACE', NULL),
            IF(tt.name LIKE '%  %', 'DOUBLE_SPACE', NULL),
            IF(tt.name REGEXP '[[:cntrl:]]', 'CONTROL_CHARACTER', NULL),
            -- Semicolon as \\x{3B}, never literal: the Pool cuts the statement at the first one.
            IF(tt.name LIKE '%&#%' OR LOWER(tt.name) REGEXP '&(amp|quot|apos|lt|gt|nbsp)\\x{3B}', 'HTML_ENTITY', NULL),
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
      AND tt.id NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
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
  AND tt.id NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND tt.id = <tournament_template_id>

ORDER BY sort_order, violation_types, template_name;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-080
    -- Name - TOURNAMENT_NAME_SEASON_CONTRADICTS_DATES
    -- What it does: Finds tournaments whose name says one year and whose stages run in another.
    CASE
        WHEN x.stage_span > 2 THEN 'STAGES_SPAN_MORE_THAN_TWO_YEARS'
        WHEN x.stage_span = 2 AND x.name_has_span = 0 THEN 'SINGLE_YEAR_NAME_ON_SEASON'
        WHEN x.stage_span = 2 THEN 'NAME_SPAN_DOES_NOT_MATCH_STAGE_YEARS'
        WHEN x.name_has_span = 1 THEN 'SEASON_NAME_ON_SINGLE_YEAR'
        ELSE 'NAME_YEAR_MATCHES_NO_STAGE'
    END AS check_type,
    x.tournament_id,
    x.tournament_name,
    x.template_name,
    x.first_stage_year,
    x.last_stage_year,
    x.stage_span,
    x.stages,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds tournaments whose name disagrees with the calendar
-- years their stages occupy, separating a season span against a single year, a single year
-- against a span, years the stages never reach, and stages crossing more than two years.
FROM (
    SELECT
        t.id AS tournament_id,
        t.name AS tournament_name,
        tt.name AS template_name,
        COUNT(DISTINCT ts.id) AS stages,
        MIN(YEAR(ts.startdate)) AS first_stage_year,
        MAX(YEAR(COALESCE(ts.enddate, ts.startdate))) AS last_stage_year,
        MAX(YEAR(COALESCE(ts.enddate, ts.startdate))) - MIN(YEAR(ts.startdate)) + 1 AS stage_span,
        -- The season a tournament belongs to is decided by the stages it holds, not by the
        -- events under them: an event dated outside its own stage is a different defect and
        -- belongs to GLOBAL-DQ-004. The name is tested for a shape rather than parsed,
        -- because REGEXP_SUBSTR is not assumed to exist.
        (t.name REGEXP '[12][0-9][0-9][0-9]') AS name_has_year,
        (t.name REGEXP '[12][0-9][0-9][0-9][/-]([12][0-9][0-9][0-9]|[0-9][0-9])') AS name_has_span
    FROM tournament t
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
     AND ts.startdate IS NOT NULL
    WHERE t.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
      -- AND t.tournament_templateFK = <tournament_template_id>
    GROUP BY t.id, t.name, tt.name
) x
-- A name carrying no year at all is left alone: there is no season label to contradict, and
-- asking for one is a different request from checking the label that exists.
WHERE x.stage_span > 2
   OR (
        x.name_has_year = 1
        AND (
            (x.stage_span = 2 AND (
                x.name_has_span = 0
                OR x.tournament_name NOT LIKE CONCAT('%', x.first_stage_year, '%')
                OR x.tournament_name NOT LIKE CONCAT('%', x.last_stage_year, '%')
            ))
            OR (x.stage_span = 1 AND (
                x.name_has_span = 1
                OR x.tournament_name NOT LIKE CONCAT('%', x.first_stage_year, '%')
            ))
        )
      )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT t.id) AS eligible_count,
    1 AS sort_order
FROM tournament t
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
 AND ts.startdate IS NOT NULL
WHERE t.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, first_stage_year;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-081
    -- Name - TEMPLATE_TOURNAMENT_YEAR_GAP
    -- What it does: Finds tournament editions that skip a year the template usually runs.
    'Template_Edition_Gap' AS check_type,
    r.template_id,
    r.template_name,
    r.editions,
    r.first_year,
    r.last_year,
    r.rhythm_years,
    COUNT(*) AS breaks_found,
    SUM((g.gap DIV r.rhythm_years) - 1) AS editions_skipped,
    GROUP_CONCAT(CONCAT(g.y, ' -> ', g.y_next) ORDER BY g.y SEPARATOR ' | ') AS break_detail,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds tournament templates whose editions break the
-- template's own rhythm, so a four-yearly series is measured against four years, and a gap
-- is not counted for a year the sport is recorded as not having run.
FROM (
        SELECT
            g0.template_id,
            g0.y,
            g0.y_next,
            g0.y_next - g0.y - (
                SELECT COUNT(*)
                FROM (
                SELECT DISTINCT YEAR(ts9.startdate) AS sy
                FROM tournament_template tt9
                JOIN tournament t9 ON t9.tournament_templateFK = tt9.id AND t9.del = 'no'
                JOIN tournament_stage ts9 ON ts9.tournamentFK = t9.id AND ts9.del = 'no'
                 AND ts9.startdate IS NOT NULL
                WHERE tt9.del = 'no'
                  AND tt9.sportFK = {{SPORT_ID}}
                  AND YEAR(ts9.startdate) IN ({{SERIES_SKIP_YEARS}})
                ) sk
                WHERE sk.sy > g0.y AND sk.sy < g0.y_next
            ) AS gap
        FROM (
            SELECT
                a.template_id,
                a.y,
                MIN(b.y) AS y_next
            FROM (
            SELECT
                tt.id AS template_id,
                tt.name AS template_name,
                YEAR(ts.startdate) AS y
            FROM tournament_template tt
            JOIN tournament t ON t.tournament_templateFK = tt.id AND t.del = 'no'
            JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
             AND ts.startdate IS NOT NULL
            WHERE tt.del = 'no'
              AND tt.sportFK = {{SPORT_ID}}
              AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
              AND tt.id NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
              AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
              -- AND tt.id = <tournament_template_id>
            GROUP BY tt.id, tt.name, YEAR(ts.startdate)
            ) a
            JOIN (
            SELECT
                tt.id AS template_id,
                tt.name AS template_name,
                YEAR(ts.startdate) AS y
            FROM tournament_template tt
            JOIN tournament t ON t.tournament_templateFK = tt.id AND t.del = 'no'
            JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
             AND ts.startdate IS NOT NULL
            WHERE tt.del = 'no'
              AND tt.sportFK = {{SPORT_ID}}
              AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
              AND tt.id NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
              AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
              -- AND tt.id = <tournament_template_id>
            GROUP BY tt.id, tt.name, YEAR(ts.startdate)
            ) b ON b.template_id = a.template_id AND b.y > a.y
            GROUP BY a.template_id, a.y
        ) g0
) g
JOIN (
    SELECT
        e.template_id,
        MIN(e.template_name) AS template_name,
        COUNT(*) AS editions,
        MIN(e.y) AS first_year,
        MAX(e.y) AS last_year,
        -- The rhythm is read from the series rather than assumed: the interval its editions
        -- most often keep, and the smaller one where two are equally common, which reports
        -- less. Without it an every-fourth-year series reads as three editions missing
        -- between each pair it actually held.
        (SELECT gm.gap
         FROM (
        SELECT
            g0.template_id,
            g0.y,
            g0.y_next,
            g0.y_next - g0.y - (
                SELECT COUNT(*)
                FROM (
                SELECT DISTINCT YEAR(ts9.startdate) AS sy
                FROM tournament_template tt9
                JOIN tournament t9 ON t9.tournament_templateFK = tt9.id AND t9.del = 'no'
                JOIN tournament_stage ts9 ON ts9.tournamentFK = t9.id AND ts9.del = 'no'
                 AND ts9.startdate IS NOT NULL
                WHERE tt9.del = 'no'
                  AND tt9.sportFK = {{SPORT_ID}}
                  AND YEAR(ts9.startdate) IN ({{SERIES_SKIP_YEARS}})
                ) sk
                WHERE sk.sy > g0.y AND sk.sy < g0.y_next
            ) AS gap
        FROM (
            SELECT
                a.template_id,
                a.y,
                MIN(b.y) AS y_next
            FROM (
            SELECT
                tt.id AS template_id,
                tt.name AS template_name,
                YEAR(ts.startdate) AS y
            FROM tournament_template tt
            JOIN tournament t ON t.tournament_templateFK = tt.id AND t.del = 'no'
            JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
             AND ts.startdate IS NOT NULL
            WHERE tt.del = 'no'
              AND tt.sportFK = {{SPORT_ID}}
              AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
              AND tt.id NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
              AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
              -- AND tt.id = <tournament_template_id>
            GROUP BY tt.id, tt.name, YEAR(ts.startdate)
            ) a
            JOIN (
            SELECT
                tt.id AS template_id,
                tt.name AS template_name,
                YEAR(ts.startdate) AS y
            FROM tournament_template tt
            JOIN tournament t ON t.tournament_templateFK = tt.id AND t.del = 'no'
            JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
             AND ts.startdate IS NOT NULL
            WHERE tt.del = 'no'
              AND tt.sportFK = {{SPORT_ID}}
              AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
              AND tt.id NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
              AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
              -- AND tt.id = <tournament_template_id>
            GROUP BY tt.id, tt.name, YEAR(ts.startdate)
            ) b ON b.template_id = a.template_id AND b.y > a.y
            GROUP BY a.template_id, a.y
        ) g0
         ) gm
         WHERE gm.template_id = e.template_id
         GROUP BY gm.gap
         ORDER BY COUNT(*) DESC, gm.gap ASC
         LIMIT 1) AS rhythm_years
    FROM (
            SELECT
                tt.id AS template_id,
                tt.name AS template_name,
                YEAR(ts.startdate) AS y
            FROM tournament_template tt
            JOIN tournament t ON t.tournament_templateFK = tt.id AND t.del = 'no'
            JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
             AND ts.startdate IS NOT NULL
            WHERE tt.del = 'no'
              AND tt.sportFK = {{SPORT_ID}}
              AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
              AND tt.id NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
              AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
              -- AND tt.id = <tournament_template_id>
            GROUP BY tt.id, tt.name, YEAR(ts.startdate)
    ) e
    GROUP BY e.template_id
    HAVING COUNT(*) >= {{SERIES_MIN_YEARS}}
) r ON r.template_id = g.template_id
WHERE g.gap > r.rhythm_years
GROUP BY r.template_id, r.template_name, r.editions, r.first_year, r.last_year, r.rhythm_years

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT c.template_id) AS eligible_count,
    1 AS sort_order
FROM (
    SELECT
        e2.template_id,
        COUNT(*) AS editions
    FROM (
            SELECT
                tt.id AS template_id,
                tt.name AS template_name,
                YEAR(ts.startdate) AS y
            FROM tournament_template tt
            JOIN tournament t ON t.tournament_templateFK = tt.id AND t.del = 'no'
            JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
             AND ts.startdate IS NOT NULL
            WHERE tt.del = 'no'
              AND tt.sportFK = {{SPORT_ID}}
              AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
              AND tt.id NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
              AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
              -- AND tt.id = <tournament_template_id>
            GROUP BY tt.id, tt.name, YEAR(ts.startdate)
    ) e2
    GROUP BY e2.template_id
    HAVING COUNT(*) >= {{SERIES_MIN_YEARS}}
) c

ORDER BY sort_order, editions_skipped DESC;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-082
    -- Name - TOURNAMENT_STAGE_EVENT_DISCIPLINE_INCONSISTENT
    -- What it does: Flags tournament stages whose events use different disciplines.
    'Stage_Event_Discipline_Inconsistent' AS check_type,
    x.stage_id,
    x.stage_name,
    x.template_name,
    x.tournament_name,
    x.distinct_disciplines,
    x.discipline_list,
    x.event_count,
    NULL AS eligible_count
-- What it does, stated in full: Finds tournament stages whose own events do not agree on a
-- discipline.
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
      -- AND t.tournament_templateFK = <tournament_template_id>
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-087
    -- Name - EVENT_WINNER_MISSING_OR_INVALID
    -- What it does: Finds finished head-to-head events with no usable Winner value.
    CASE
        WHEN pr.id IS NULL THEN 'WINNER_MISSING'
        WHEN TRIM(pr.value) = '' THEN 'WINNER_VALUE_EMPTY'
        ELSE 'WINNER_VALUE_INVALID'
    END AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    tt.name AS template_name,
    t.name AS tournament_name,
    ts.name AS stage_name,
    e.round_typeFK,
    e.status_descFK,
    pr.value AS stored_value,
    NULL AS eligible_count,
    0 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
-- The Winner side is stored as an event property rather than on either result row, so a
-- missing one is an absent row and not an empty value: DB-SEM-002 makes those different
-- states, and the join is left outer precisely so the absent case is reportable at all.
LEFT JOIN property pr ON pr.object = 'event' AND pr.objectFK = e.id
                     AND pr.name = 'Winner' AND pr.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND e.status_type = 'finished'
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND (
      pr.id IS NULL
      OR TRIM(pr.value) = ''
      OR LOWER(TRIM(pr.value)) NOT IN ({{WINNER_VALUE_LIST}})
  )

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
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND e.status_type = 'finished'
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_startdate DESC;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-089
    -- Name - EVENT_EXTRA_PERIOD_STATUS_MISMATCH
    -- What it does: Flags events where the extra-period score and detailed status do not agree.
    CASE
        WHEN extra.event_id IS NOT NULL THEN 'EXTRA_PERIOD_PLAYED_STATUS_NOT_MARKED'
        ELSE 'STATUS_MARKED_WITHOUT_EXTRA_PERIOD'
    END AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    tt.name AS template_name,
    t.name AS tournament_name,
    ts.name AS stage_name,
    e.round_typeFK,
    e.status_type,
    e.status_descFK,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds events whose extra period and detailed status
-- disagree: a period scored while the status does not say the event went to one, or the
-- status saying it did with no period scored.
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
-- Whether the extra period was played is read from its own scope column rather than from a
-- count of periods carrying a value: a period count cannot tell an extra period from a
-- contest that ended early, because both leave the same number of scored periods behind.
LEFT JOIN (
    SELECT DISTINCT es.eventFK AS event_id
    FROM scope_result sr
    JOIN event_scope es ON es.id = sr.event_scopeFK AND es.del = 'no'
                       AND es.scope_typeFK = {{SCOPE_TYPE_ID}}
    JOIN event e2 ON e2.id = es.eventFK AND e2.del = 'no'
    JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
    JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
    JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
    WHERE sr.del = 'no'
      AND tt2.sportFK = {{SPORT_ID}}
      AND sr.scope_data_typeFK = {{SCOPE_EXTRA_PERIOD_DATA_TYPE_ID}}
      AND TRIM(sr.value) REGEXP '^-?[0-9]+$'
) extra ON extra.event_id = e.id
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND EXISTS (
      SELECT 1 FROM event_scope esx
      WHERE esx.eventFK = e.id AND esx.del = 'no'
        AND esx.scope_typeFK = {{SCOPE_TYPE_ID}}
  )
  AND (
      (extra.event_id IS NOT NULL AND e.status_descFK NOT IN ({{EXTRA_PERIOD_STATUS_DESC_LIST}}))
      OR (extra.event_id IS NULL AND e.status_descFK IN ({{EXTRA_PERIOD_STATUS_DESC_LIST}}))
  )

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
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND EXISTS (
      SELECT 1 FROM event_scope esx
      WHERE esx.eventFK = e.id AND esx.del = 'no'
        AND esx.scope_typeFK = {{SCOPE_TYPE_ID}}
  )

ORDER BY sort_order, event_startdate DESC;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-096
    -- Name - EVENT_NAME_DOES_NOT_NAME_ITS_PARTICIPANTS
    -- What it does: Flags participant-based event names that include none or only some of the competitors.
    CASE
        WHEN x.named_participant_count = 0 THEN 'NAMES_NO_PARTICIPANT'
        ELSE 'NAMES_SOME_PARTICIPANTS_NOT_ALL'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.template_name,
    x.tournament_name,
    x.stage_name,
    x.participant_count,
    x.named_participant_count,
    x.unnamed_participants,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds events whose name is built from their competitors but
-- does not name one of them, separating naming none of them from naming only some.
-- Containment rather than reconstruction. A sport whose event name is the pairing joins its
-- sides with a separator that varies - a hyphen, a slash inside a side made of two countries
-- - and rebuilding the name from the participants would need that convention as a parameter
-- and would break on the first competition that spells it differently. Asking only whether
-- each participant's name appears somewhere in the event name needs no convention at all,
-- and is exactly strict enough to catch the case worth catching: a side stored under one
-- name and printed under another. A participant with an empty name is left out rather than
-- reported, because there is nothing to look for; that gap is GLOBAL-DQ-008.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        tt.name AS template_name,
        t.name AS tournament_name,
        ts.name AS stage_name,
        COUNT(*) AS participant_count,
        SUM(CASE WHEN LOCATE(LOWER(TRIM(p.name)), LOWER(e.name)) > 0 THEN 1 ELSE 0 END) AS named_participant_count,
        GROUP_CONCAT(CASE WHEN LOCATE(LOWER(TRIM(p.name)), LOWER(e.name)) = 0
                          THEN p.name END ORDER BY p.name SEPARATOR ', ') AS unnamed_participants
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
    WHERE e.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      AND e.name IS NOT NULL
      AND TRIM(e.name) <> ''
      AND p.name IS NOT NULL
      AND TRIM(p.name) <> ''
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY e.id, e.name, e.startdate, tt.name, t.name, ts.name
) x
WHERE x.named_participant_count < x.participant_count

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
JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND e.name IS NOT NULL
  AND TRIM(e.name) <> ''
  AND p.name IS NOT NULL
  AND TRIM(p.name) <> ''
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_startdate DESC;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-097
    -- Name - EVENT_ROUND_TYPE_KNOCKOUT_FLAG_CONTRADICTS_ROUND
    -- What it does: Finds round types whose knockout setting is wrong for that round.
    CASE
        WHEN LOWER(TRIM(rt.name)) IN ({{ELIMINATION_ROUND_NAME_LIST}}) THEN 'ELIMINATION_ROUND_NOT_MARKED_KNOCKOUT'
        ELSE 'NON_ELIMINATION_ROUND_MARKED_KNOCKOUT'
    END AS check_type,
    rt.id AS round_type_id,
    rt.name AS round_type_name,
    rt.knockout AS knockout_stored,
    CASE
        WHEN LOWER(TRIM(rt.name)) IN ({{ELIMINATION_ROUND_NAME_LIST}}) THEN 'yes'
        ELSE 'no'
    END AS knockout_expected,
    (
        SELECT GROUP_CONCAT(DISTINCT rt2.id ORDER BY rt2.id)
-- What it does, stated in full: Finds round types whose knockout flag contradicts the round:
-- an elimination round marked not knockout, or a round nobody leaves marked as one.
        FROM round_type rt2
        WHERE rt2.del = 'no'
          AND LOWER(TRIM(rt2.name)) = LOWER(TRIM(rt.name))
          AND rt2.knockout <> rt.knockout
    ) AS correct_round_type_id,
    COUNT(DISTINCT e.id) AS event_count,
    SUBSTRING(GROUP_CONCAT(DISTINCT tt.name ORDER BY tt.name SEPARATOR ', '), 1, 200) AS templates,
    MIN(e.startdate) AS first_event_startdate,
    MAX(e.startdate) AS last_event_startdate,
    NULL AS eligible_count,
    0 AS sort_order
-- Reported per round type rather than per event, because that is where the defect lives and
-- where it is repaired: every event pointing at one round type carries it identically, so a
-- row per event would repeat one fact thousands of times. The count travels with the row so
-- the size of the exposure is still visible.
-- What a round is cannot be read from the database - `round_type` carries a name, a bracket
-- value and the flag, and nothing that says whether entries go out - so the two lists are
-- the judgement this check rests on. A name in neither list is silent rather than assumed,
-- which is what keeps a placement or qualification round, where the answer depends on the
-- format rather than the name, out of the finding.
-- `DB-SEM-012` records that one round name exists under both a knockout and a non-knockout
-- id, so a sport storing the wrong member of a pair reports the whole population that uses
-- it. That is the finding, not noise: the pair exists so that a round can be marked
-- correctly, and using the wrong side is the defect this names.
-- `correct_round_type_id` names the other side of that pair - the active round types sharing
-- this name and carrying the flag this round should have. It is there because `round_type` is
-- shared by every sport, so the flag on the reported row cannot be corrected without moving
-- rounds in sports this run never looked at; what is repaired is the events, by pointing them
-- at the id named here. It is `NULL` where no active counterpart exists, which is a different
-- finding - the name has only the one variant and the flag is the only thing that can change.
FROM round_type rt
JOIN event e ON e.round_typeFK = rt.id AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE tt.sportFK = {{SPORT_ID}}
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND (
      (LOWER(TRIM(rt.name)) IN ({{ELIMINATION_ROUND_NAME_LIST}}) AND rt.knockout = 'no')
      OR (LOWER(TRIM(rt.name)) IN ({{GROUP_ROUND_NAME_LIST}}) AND rt.knockout = 'yes')
  )
GROUP BY rt.id, rt.name, rt.knockout

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT rt.id) AS eligible_count,
    1 AS sort_order
FROM round_type rt
JOIN event e ON e.round_typeFK = rt.id AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE tt.sportFK = {{SPORT_ID}}
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND (
      LOWER(TRIM(rt.name)) IN ({{ELIMINATION_ROUND_NAME_LIST}})
      OR LOWER(TRIM(rt.name)) IN ({{GROUP_ROUND_NAME_LIST}})
  )

ORDER BY sort_order, event_count DESC;

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-109
    -- Name - EVENT_SETTINGS_DISCIPLINE_STORAGE_MISMATCH
    -- What it does: Flags events where the discipline property and object_discipline relation do not match.
    'Event_Discipline_Storage_Mismatch' AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    (
        SELECT GROUP_CONCAT(
                   DISTINCT LOWER(TRIM(pd.name))
                   ORDER BY LOWER(TRIM(pd.name)) SEPARATOR ', '
               )
-- What it does, stated in full: Finds events whose discipline differs between the two
-- storage paths, the discipline event property and the object_discipline relation.
        FROM property pr
        JOIN discipline pd
          ON pd.del = 'no'
         AND LOWER(TRIM(pd.name)) = LOWER(TRIM(pr.value))
        WHERE pr.object = 'event'
          AND pr.objectFK = e.id
          AND pr.name = 'discipline'
          AND pr.del = 'no'
          AND TRIM(COALESCE(pr.value, '')) <> ''
    ) AS property_disciplines,
    (
        SELECT GROUP_CONCAT(
                   DISTINCT LOWER(TRIM(rd.name))
                   ORDER BY LOWER(TRIM(rd.name)) SEPARATOR ', '
               )
        FROM object_discipline od
        JOIN discipline rd ON rd.id = od.disciplineFK AND rd.del = 'no'
        WHERE od.object_typeFK = 5
          AND od.objectFK = e.id
          AND od.del = 'no'
          AND TRIM(COALESCE(rd.name, '')) <> ''
    ) AS relation_disciplines,
    tt.name AS template_name,
    NULL AS eligible_count,
    0 AS sort_order
-- Only events carrying an active value that resolves to an active discipline through both
-- paths are eligible. An event with one path is not a disagreement, and an unresolvable value
-- is outside this comparison of two resolved paths. Each correlated aggregate reduces
-- its path to one distinct normalized set before the sets are compared. That keeps one row
-- per event when either storage layer contains duplicate or multiple active records, and it
-- also avoids treating one unequal pair from two otherwise equal multi-value sets as a defect.
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = {{SPORT_ID}}
WHERE e.del = 'no'
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND EXISTS (
      SELECT 1
      FROM property pr2
      JOIN discipline pd2
        ON pd2.del = 'no'
       AND LOWER(TRIM(pd2.name)) = LOWER(TRIM(pr2.value))
      WHERE pr2.object = 'event'
        AND pr2.objectFK = e.id
        AND pr2.name = 'discipline'
        AND pr2.del = 'no'
        AND TRIM(COALESCE(pr2.value, '')) <> ''
  )
  AND EXISTS (
      SELECT 1
      FROM object_discipline od2
      JOIN discipline rd2 ON rd2.id = od2.disciplineFK AND rd2.del = 'no'
      WHERE od2.object_typeFK = 5
        AND od2.objectFK = e.id
        AND od2.del = 'no'
        AND TRIM(COALESCE(rd2.name, '')) <> ''
  )
HAVING property_disciplines <> relation_disciplines

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = {{SPORT_ID}}
WHERE e.del = 'no'
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND EXISTS (
      SELECT 1
      FROM property pr2
      JOIN discipline pd2
        ON pd2.del = 'no'
       AND LOWER(TRIM(pd2.name)) = LOWER(TRIM(pr2.value))
      WHERE pr2.object = 'event'
        AND pr2.objectFK = e.id
        AND pr2.name = 'discipline'
        AND pr2.del = 'no'
        AND TRIM(COALESCE(pr2.value, '')) <> ''
  )
  AND EXISTS (
      SELECT 1
      FROM object_discipline od2
      JOIN discipline rd2 ON rd2.id = od2.disciplineFK AND rd2.del = 'no'
      WHERE od2.object_typeFK = 5
        AND od2.objectFK = e.id
        AND od2.del = 'no'
        AND TRIM(COALESCE(rd2.name, '')) <> ''
  )

ORDER BY sort_order, event_id;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-118
    -- Name - EVENT_ROUND_TYPE_KNOCKOUT_FLAG_CONTRADICTS_ROUND_DETAIL
    -- What it does: Lists events using a round type with an incorrect knockout setting, so they can be repaired.
    CASE
        WHEN LOWER(TRIM(rt.name)) IN ({{ELIMINATION_ROUND_NAME_LIST}}) THEN 'ELIMINATION_ROUND_NOT_MARKED_KNOCKOUT'
        ELSE 'NON_ELIMINATION_ROUND_MARKED_KNOCKOUT'
    END AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    ts.name AS tournament_stage_name,
    t.name AS tournament_name,
    tt.name AS template_name,
    rt.id AS round_type_id,
    rt.name AS round_type_name,
    rt.knockout AS knockout_stored,
    CASE
        WHEN LOWER(TRIM(rt.name)) IN ({{ELIMINATION_ROUND_NAME_LIST}}) THEN 'yes'
        ELSE 'no'
    END AS knockout_expected,
    (
        SELECT GROUP_CONCAT(DISTINCT rt2.id ORDER BY rt2.id)
-- What it does, stated in full: Lists the events contested under a round type whose knockout
-- flag contradicts the round, so the round types GLOBAL-DQ-097 names arrive as a repair
-- list.
        FROM round_type rt2
        WHERE rt2.del = 'no'
          AND LOWER(TRIM(rt2.name)) = LOWER(TRIM(rt.name))
          AND rt2.knockout <> rt.knockout
    ) AS correct_round_type_id,
    NULL AS eligible_count,
    0 AS sort_order
-- The detail companion of `GLOBAL-DQ-097`, which reports one row per round type because that
-- is where the defect lives. This one exists because that is not where it is repaired:
-- `round_type` is shared by every sport, so the flag on the reported row cannot be corrected
-- without moving rounds in sports the run never looked at, and what is changed instead is the
-- events, one at a time, onto the id `correct_round_type_id` names. A summary row saying
-- 67298 events is the size of the work; this is the work.
-- The judgement is `GLOBAL-DQ-097`'s unchanged - the same two name lists, the same silence
-- over a name in neither - so the two statements always agree on which round types are wrong
-- and differ only in what one row stands for.
-- No narrowing beyond the sport is written in, because the population is the summary's event
-- count and that is a per-sport fact: a sport reporting a hundred events is read whole, and a
-- sport reporting a hundred thousand activates the commented template or date filter and is
-- read a template at a time. `WORKFLOW.md` owns that rule.
FROM event e
JOIN round_type rt ON rt.id = e.round_typeFK
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND (
      (LOWER(TRIM(rt.name)) IN ({{ELIMINATION_ROUND_NAME_LIST}}) AND rt.knockout = 'no')
      OR (LOWER(TRIM(rt.name)) IN ({{GROUP_ROUND_NAME_LIST}}) AND rt.knockout = 'yes')
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event e
JOIN round_type rt ON rt.id = e.round_typeFK
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND (
      LOWER(TRIM(rt.name)) IN ({{ELIMINATION_ROUND_NAME_LIST}})
      OR LOWER(TRIM(rt.name)) IN ({{GROUP_ROUND_NAME_LIST}})
  )

ORDER BY sort_order, event_startdate DESC;
