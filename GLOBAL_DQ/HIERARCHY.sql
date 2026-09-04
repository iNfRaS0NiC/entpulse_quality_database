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
    tt.name AS template_name,
    t.name AS season,
    ts.startdate AS stage_startdate,
    sc.value AS status_comment,
    NULL AS eligible_count
-- What it does, stated in full: Finds tournament stages holding no events.
-- Four columns beside the stage's own id and name, because an empty stage is not read the same
-- way twice and the id alone cannot tell them apart. The season says whether the stage is a
-- future one that has not been drawn yet - a 2027 stage holding no event is a calendar entry,
-- not a defect - and the template says which competition it belongs to. StatusComment is the
-- only place a cancellation is recorded: `tournament_stage` has no status column at all, its
-- columns being id, name, tournamentFK, gender, countryFK, enetID, startdate, enddate, n,
-- locked, ut and del, so a stage that was called off carries the word in a property or nowhere.
-- Measured on Ice Hockey 2026-08-20, nine of its empty stages read `Cancelled` there.
-- All four are read through a LEFT JOIN or from a column that is always present, so a sport
-- writing no such property loses nothing but sees an empty cell.
FROM tournament_stage ts
JOIN tournament t
  ON t.id = ts.tournamentFK
 AND t.del = 'no'
JOIN tournament_template tt
  ON tt.id = t.tournament_templateFK
 AND tt.del = 'no'
LEFT JOIN property sc
  ON sc.object = 'tournament_stage'
 AND sc.objectFK = ts.id
 AND sc.name = 'StatusComment'
 AND sc.del = 'no'
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
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-004
    -- Name - TOURNAMENT_STAGE_EVENT_OUTSIDE_DATE_RANGE
    -- What it does: Flags tournament stages holding an event that starts outside the stage's own dates.
    'Stage_Event_Outside_Date_Range' AS check_type,
    ts.id AS tournament_stage_id,
    ts.name AS tournament_stage_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    ts.startdate AS stage_startdate,
    ts.enddate AS stage_enddate,
    MIN(e.startdate) AS earliest_event_startdate,
    MAX(e.startdate) AS latest_event_startdate,
    NULL AS eligible_count
-- What it does, stated in full: Finds a stage whose first or last event starts before the
-- stage begins or after it ends, so the stage does not contain the competition it names.
-- The rule is containment, not equality, and the distinction is what the template is worth.
-- Equality - stage dates matching the first and last event exactly - reads the format a sport
-- writes its stages in rather than whether the stage holds its events. A sport writing a stage
-- as whole days, 00:00:00 to 23:59:59, differs from its events' span by the hours at each end
-- while containing every one of them: measured on Equestrian 2026-08-18 that was 3303 of the
-- 3338 stages equality reported, against 18 where an event genuinely fell outside. Changed to
-- containment 2026-08-26 so the template asserts the same thing on every sport regardless of
-- how that sport rounds a stage. Containment is asserted on the calendar day, which the
-- equality form also used: a sport writing a stage from 10:00 and an event in it at 09:00
-- the same morning has recorded the stage's hours loosely, not put the event outside it.
-- A stage or event with no date is not judged here at all;
-- GLOBAL-DQ-005 owns the missing date.
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
  -- AND EXISTS (SELECT 1 FROM object_discipline dsc_e WHERE dsc_e.object_typeFK = 5 AND dsc_e.objectFK = e.id AND dsc_e.disciplineFK IN (<discipline_ids>) AND dsc_e.del = 'no')
  AND ts.startdate IS NOT NULL
  AND ts.enddate IS NOT NULL
  AND e.startdate IS NOT NULL
GROUP BY
    ts.id,
    ts.name,
    tt.name,
    t.name,
    ts.startdate,
    ts.enddate
HAVING DATE(MIN(e.startdate)) < DATE(ts.startdate)
    OR DATE(MAX(e.startdate)) > DATE(ts.enddate)

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL,
    NULL,
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
  AND ts.startdate IS NOT NULL
  AND ts.enddate IS NOT NULL
  AND EXISTS (
      SELECT 1
      FROM event e2
      WHERE e2.tournament_stageFK = ts.id
        AND e2.del = 'no'
        AND e2.startdate IS NOT NULL
        -- AND EXISTS (SELECT 1 FROM object_discipline dsc_e2 WHERE dsc_e2.object_typeFK = 5 AND dsc_e2.objectFK = e2.id AND dsc_e2.disciplineFK IN (<discipline_ids>) AND dsc_e2.del = 'no')
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
  -- AND EXISTS (SELECT 1 FROM object_discipline dsc_e WHERE dsc_e.object_typeFK = 5 AND dsc_e.objectFK = e.id AND dsc_e.disciplineFK IN (<discipline_ids>) AND dsc_e.del = 'no')
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
  -- AND EXISTS (SELECT 1 FROM object_discipline dsc_e WHERE dsc_e.object_typeFK = 5 AND dsc_e.objectFK = e.id AND dsc_e.disciplineFK IN (<discipline_ids>) AND dsc_e.del = 'no')
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
    -- Name - EVENT_SETTINGS_DISCIPLINE_MISSING_UNRESOLVED_OR_FOREIGN
    -- What it does: Flags events with no usable discipline - no relation at all, a relation pointing at no discipline, or one naming a discipline that belongs to another sport.
    CASE
        -- Three states and three repairs. A missing relation has to be created and the
        -- discipline chosen; a relation pointing at nothing already names its event and its
        -- intent and needs the reference corrected; a relation naming another sport's
        -- discipline is correct in form and wrong in fact, and the repair is to point it at
        -- this sport's equivalent - or, where there is none, to decide the event is filed
        -- under the wrong sport. Separated rather than merged, because a reviewer filtering
        -- for one would otherwise be handed the others.
        WHEN x.relation_rows = 0 THEN 'Missing_Discipline'
        WHEN x.resolved_rows = 0 THEN 'Discipline_Reference_Unresolved'
        ELSE 'Discipline_Belongs_To_Another_Sport'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.template_name,
    x.tournament_name,
    x.stage_name,
    x.unresolved_discipline_ids,
    x.foreign_sport_disciplines,
    NULL AS eligible_count
-- What it does, stated in full: Finds events from which no discipline of this sport can be
-- read - the relation is absent, or it exists and its disciplineFK selects no row in
-- discipline, or it selects a discipline whose sportFK is a different sport.
-- The second and third states were both added on 2026-08-25 and are the reason this statement
-- was rewritten twice in one day. Until the morning the check asked only whether the relation
-- existed, through a NOT EXISTS over object_discipline, and an event carrying
-- `disciplineFK = 0` satisfied that test: the row is there, so the event passed, while the
-- discipline it names does not exist and nothing downstream can resolve it.
-- The third state came out of a Swimming finding that was first read as a duplicated catalogue
-- entry and was not one. `Freestyle 800m` and `Freestyle 50m` each appear on two discipline
-- ids, and the second id of each pair belongs to sport 135, Para Swimming. Measured across the
-- twelve documented sports there is not one duplicated discipline name inside any single sport;
-- what looked like a duplicate was an event of one sport reaching into another sport's
-- catalogue. The events themselves are ordinary - named `800m Freestyle`, in World
-- Championships Long Course and World Junior Championships, carrying no para classification -
-- so the reference is what is wrong rather than the sport the event is filed under.
-- **Why this belongs here and not in its own statement.** All three states leave the event with
-- no discipline this sport can read, which is one question and one eligible population. It is
-- still a different question from GLOBAL-DQ-082, which asks whether a discipline that reads
-- correctly is the right one; that one measures an event against its stage's other events, and
-- cannot see a reference that resolves outside the sport entirely.
-- Measured 2026-08-25 across the twelve documented sports:
--   `Discipline_Reference_Unresolved` occurs in one - Swimming holds six events on
--     `disciplineFK = 0`, all in one competition inside five days of 2013, which makes it one
--     import that did not write the reference rather than a habit.
--   `Discipline_Belongs_To_Another_Sport` occurs in two - Swimming holds 67 events on Para
--     Swimming's `468 Freestyle 800m` and `479 Freestyle 50m`, spread over three templates and
--     2005-2025, and Equestrian holds one on Mountain Bike's `402 Cross Country`. Equestrian
--     has `347 Cross Country Fences` and `72 3Day Event Cross Country` and no plain
--     `Cross Country` of its own, so that row has a discipline to choose rather than one to
--     correct. The other ten sports gain nothing from either widening.
-- `unresolved_discipline_ids` carries the value the relation actually holds, because `0` and a
-- plausible-looking id that has since been deleted are different stories and the row should not
-- make the reviewer go and look. `foreign_sport_disciplines` does the same for the third state
-- and names the owning sport as well as the discipline, because the id alone cannot tell a
-- reviewer whether the event or the reference is the thing to move.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        tt.name AS template_name,
        t.name AS tournament_name,
        ts.name AS stage_name,
        COUNT(od.id) AS relation_rows,
        COUNT(d.id) AS resolved_rows,
        COUNT(CASE WHEN d.sportFK = {{SPORT_ID}} THEN d.id END) AS own_sport_rows,
        GROUP_CONCAT(DISTINCT CASE WHEN d.id IS NULL THEN od.disciplineFK END
                     ORDER BY od.disciplineFK SEPARATOR ', ') AS unresolved_discipline_ids,
        GROUP_CONCAT(DISTINCT CASE WHEN d.id IS NOT NULL AND d.sportFK <> {{SPORT_ID}}
                                   THEN CONCAT(d.id, ' ', d.name, ' - sport ', d.sportFK, ' ', sp.name) END
                     ORDER BY d.id SEPARATOR ' | ') AS foreign_sport_disciplines
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    LEFT JOIN object_discipline od
           ON od.object_typeFK = 5
          AND od.objectFK = e.id
          AND od.del = 'no'
    LEFT JOIN discipline d ON d.id = od.disciplineFK
    LEFT JOIN sport sp ON sp.id = d.sportFK
    WHERE e.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
      -- AND EXISTS (SELECT 1 FROM object_discipline dsc_e WHERE dsc_e.object_typeFK = 5 AND dsc_e.objectFK = e.id AND dsc_e.disciplineFK IN (<discipline_ids>) AND dsc_e.del = 'no')
    GROUP BY e.id, e.name, e.startdate, tt.name, t.name, ts.name
) x
-- An event holding one readable discipline of its own sport is settled, however many relations
-- it carries. The finding is that not one of them gets that far.
WHERE x.own_sport_rows = 0

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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  -- AND EXISTS (SELECT 1 FROM object_discipline dsc_e WHERE dsc_e.object_typeFK = 5 AND dsc_e.objectFK = e.id AND dsc_e.disciplineFK IN (<discipline_ids>) AND dsc_e.del = 'no')
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
  -- AND EXISTS (SELECT 1 FROM object_discipline dsc_e WHERE dsc_e.object_typeFK = 5 AND dsc_e.objectFK = e.id AND dsc_e.disciplineFK IN (<discipline_ids>) AND dsc_e.del = 'no')
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
  -- AND EXISTS (SELECT 1 FROM object_discipline dsc_e WHERE dsc_e.object_typeFK = 5 AND dsc_e.objectFK = e.id AND dsc_e.disciplineFK IN (<discipline_ids>) AND dsc_e.del = 'no')
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
  -- AND EXISTS (SELECT 1 FROM object_discipline dsc_e WHERE dsc_e.object_typeFK = 5 AND dsc_e.objectFK = e.id AND dsc_e.disciplineFK IN (<discipline_ids>) AND dsc_e.del = 'no')
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
  -- AND EXISTS (SELECT 1 FROM object_discipline dsc_e WHERE dsc_e.object_typeFK = 5 AND dsc_e.objectFK = e.id AND dsc_e.disciplineFK IN (<discipline_ids>) AND dsc_e.del = 'no')
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
      -- AND EXISTS (SELECT 1 FROM object_discipline dsc_e WHERE dsc_e.object_typeFK = 5 AND dsc_e.objectFK = e.id AND dsc_e.disciplineFK IN (<discipline_ids>) AND dsc_e.del = 'no')
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
  -- AND EXISTS (SELECT 1 FROM object_discipline dsc_e WHERE dsc_e.object_typeFK = 5 AND dsc_e.objectFK = e.id AND dsc_e.disciplineFK IN (<discipline_ids>) AND dsc_e.del = 'no')

ORDER BY sort_order, violation_types, event_name;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-050
    -- Name - TOURNAMENT_STAGE_NAME_CASE_INCONSISTENT
    -- What it does: Finds stages whose name differs from a more common spelling of the same name only by case or spacing.
    CASE
        WHEN v.occurrence_count = v.dominant_count THEN 'NAME_CASE_NO_DOMINANT_SPELLING'
        ELSE 'NAME_CASE_MINORITY_SPELLING'
    END AS check_type,
    st.tournament_stage_id,
    st.stage_name,
    v.dominant_spelling,
    st.tournament_id,
    st.tournament_name,
    st.template_name,
    st.stage_startdate,
    v.occurrence_count,
    v.dominant_count,
    v.variant_count,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds tournament stages whose name loses to a more common
-- spelling of the same name, identical but for case and spacing, with the dominant spelling
-- beside it.
-- **The audited object is the stage, not the spelling.** Until 2026-08-24 this statement
-- returned one row per losing spelling and named a single stage under `MIN(ts.id)`, which
-- is the reason it is being changed: a spelling used on six stages arrived as one row
-- carrying one id, and the other five were invisible to the person expected to repair them.
-- Measured on that day, Ice Hockey's nine rows stood for eighteen stages and Soccer's 382
-- for 1109, so roughly half of the work the check had found was not on the board. The
-- spelling is a fact about the sport and the stage is the thing that gets renamed, so the
-- stage is what a row is now. `occurrence_count`, `dominant_count` and `variant_count`
-- keep the spelling-level picture as context on every row.
-- The row also carries the tournament that owns the stage, by id and by name, because the
-- name is where the season lives in this database and without it a stage cannot be found in
-- the source system. The point is not decorative: Ice Hockey files two Winter Olympics
-- tournaments per games, so `Olympic Games Final` under template `Winter Olympics` names
-- eight different stages across four Olympiads, and only the tournament tells them apart.
-- `stage_startdate` is carried for the same reason and answers the question directly where a
-- tournament name is not a year.
-- The dominant spelling is context, not a finding: the stages spelling it the common way are
-- not reported, which is what keeps the correct name out of the list to review.
-- Where two spellings occur equally often neither is dominant, no rename is implied by the
-- counts alone, and the rows say so under their own `check_type` so the reviewer chooses.
FROM (
    SELECT
        a.name_normalized,
        a.stage_name,
        a.occurrence_count,
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
            COUNT(DISTINCT ts.id) AS occurrence_count
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
-- Back to the stages themselves. The join is on the binary spelling, so a stage spelt the
-- dominant way is never dragged in beside one that is not.
JOIN (
    SELECT
        ts.id AS tournament_stage_id,
        (CONVERT(ts.name USING utf8mb4) COLLATE utf8mb4_bin) AS stage_name,
        LOWER(REPLACE(TRIM(ts.name), ' ', '')) AS name_normalized,
        t.id AS tournament_id,
        t.name AS tournament_name,
        tt.name AS template_name,
        CAST(ts.startdate AS CHAR) AS stage_startdate
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
) st
  ON  st.name_normalized = v.name_normalized
  AND st.stage_name = v.stage_name
WHERE v.variant_count > 1
  AND v.spelling_rank > 1

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ts.id) AS eligible_count,
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

ORDER BY sort_order, dominant_spelling, stage_name, tournament_stage_id;


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
  -- AND EXISTS (SELECT 1 FROM object_discipline dsc_e WHERE dsc_e.object_typeFK = 5 AND dsc_e.objectFK = e.id AND dsc_e.disciplineFK IN (<discipline_ids>) AND dsc_e.del = 'no')
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
  -- AND EXISTS (SELECT 1 FROM object_discipline dsc_e WHERE dsc_e.object_typeFK = 5 AND dsc_e.objectFK = e.id AND dsc_e.disciplineFK IN (<discipline_ids>) AND dsc_e.del = 'no')
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
      -- AND EXISTS (SELECT 1 FROM object_discipline dsc_e WHERE dsc_e.object_typeFK = 5 AND dsc_e.objectFK = e.id AND dsc_e.disciplineFK IN (<discipline_ids>) AND dsc_e.del = 'no')
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
  -- AND EXISTS (SELECT 1 FROM object_discipline dsc_e WHERE dsc_e.object_typeFK = 5 AND dsc_e.objectFK = e.id AND dsc_e.disciplineFK IN (<discipline_ids>) AND dsc_e.del = 'no')
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
  -- AND EXISTS (SELECT 1 FROM object_discipline dsc_e WHERE dsc_e.object_typeFK = 5 AND dsc_e.objectFK = e.id AND dsc_e.disciplineFK IN (<discipline_ids>) AND dsc_e.del = 'no')
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
  -- AND EXISTS (SELECT 1 FROM object_discipline dsc_e WHERE dsc_e.object_typeFK = 5 AND dsc_e.objectFK = e.id AND dsc_e.disciplineFK IN (<discipline_ids>) AND dsc_e.del = 'no')
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
      -- AND EXISTS (SELECT 1 FROM object_discipline dsc_e WHERE dsc_e.object_typeFK = 5 AND dsc_e.objectFK = e.id AND dsc_e.disciplineFK IN (<discipline_ids>) AND dsc_e.del = 'no')
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
  -- AND EXISTS (SELECT 1 FROM object_discipline dsc_e WHERE dsc_e.object_typeFK = 5 AND dsc_e.objectFK = e.id AND dsc_e.disciplineFK IN (<discipline_ids>) AND dsc_e.del = 'no')
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
  -- AND EXISTS (SELECT 1 FROM object_discipline dsc_e WHERE dsc_e.object_typeFK = 5 AND dsc_e.objectFK = e.id AND dsc_e.disciplineFK IN (<discipline_ids>) AND dsc_e.del = 'no')
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
  -- AND EXISTS (SELECT 1 FROM object_discipline dsc_e WHERE dsc_e.object_typeFK = 5 AND dsc_e.objectFK = e.id AND dsc_e.disciplineFK IN (<discipline_ids>) AND dsc_e.del = 'no')
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
      -- AND EXISTS (SELECT 1 FROM object_discipline dsc_e WHERE dsc_e.object_typeFK = 5 AND dsc_e.objectFK = e.id AND dsc_e.disciplineFK IN (<discipline_ids>) AND dsc_e.del = 'no')
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
  -- AND EXISTS (SELECT 1 FROM object_discipline dsc_e WHERE dsc_e.object_typeFK = 5 AND dsc_e.objectFK = e.id AND dsc_e.disciplineFK IN (<discipline_ids>) AND dsc_e.del = 'no')
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-087
    -- Name - EVENT_WINNER_RECORDED_IN_NEITHER_PLACE_THE_SPORT_KEEPS_IT
    -- What it does: Finds finished head-to-head events that name a winner neither in the Winner event property nor in the Event outcome result, having a score that decides one.
    CASE
        WHEN pr.id IS NOT NULL AND TRIM(pr.value) = '' THEN 'WINNER_PROPERTY_VALUE_EMPTY'
        WHEN pr.id IS NOT NULL THEN 'WINNER_PROPERTY_VALUE_INVALID'
        WHEN oc.event_id IS NOT NULL THEN 'EVENT_OUTCOME_VALUE_INVALID'
        ELSE 'WINNER_RECORDED_NOWHERE'
    END AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    tt.name AS template_name,
    t.name AS tournament_name,
    ts.name AS stage_name,
    e.round_typeFK,
    e.status_descFK,
    COALESCE(pr.value, oc.values_seen) AS stored_value,
    NULL AS eligible_count,
    0 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
-- Two places, and a sport keeps the winner in one or the other rather than in both.
--
-- The Winner event property is what most of the database uses - 32 sports write it, Tennis on
-- 425 225 events and Volleyball on 127 496, both still writing today. Not one of the fifteen
-- sports this package documents does: measured 2026-08-29 over 2 613 135 finished events, a
-- single Soccer event carries one, and it sits outside the client boundary.
--
-- They keep it in `668 Event outcome` instead, a result row per side reading won, lost or
-- draw. Ice Hockey carries it on all 286 049 of its events and Curling on all 17 521, so a
-- check reading only the property called both of them defective in full while the winner sat
-- one join away. That is why this asks for either and reports only an event holding neither.
--
-- The property side stays outer-joined because DB-SEM-002 makes an absent row and an empty
-- value different states, and both have to be reportable.
-- Both joins are left outer and unfiltered by value, and the vocabulary is tested in the
-- WHERE rather than in the ON. Filtering in the ON would make a row holding a word nobody
-- declared indistinguishable from no row at all, and those are the two states check_type
-- exists to tell apart: one is a value to correct, the other is a value never written.
LEFT JOIN property pr ON pr.object = 'event' AND pr.objectFK = e.id
                     AND pr.name = 'Winner' AND pr.del = 'no'
LEFT JOIN (
    SELECT ep2.eventFK AS event_id,
           MAX(CASE WHEN LOWER(TRIM(r2.value)) IN ({{EVENT_OUTCOME_VALUE_LIST}}) THEN 1 ELSE 0 END) AS has_usable,
           GROUP_CONCAT(DISTINCT LOWER(TRIM(r2.value)) ORDER BY LOWER(TRIM(r2.value)) SEPARATOR ', ') AS values_seen
    FROM result r2
    JOIN event_participants ep2 ON ep2.id = r2.event_participantsFK AND ep2.del = 'no'
    JOIN event e2 ON e2.id = ep2.eventFK AND e2.del = 'no'
    JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
    JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
    JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
    WHERE r2.del = 'no'
      AND r2.result_typeFK = {{RESULT_EVENT_OUTCOME_TYPE_ID}}
      AND r2.value IS NOT NULL AND TRIM(r2.value) <> ''
      AND tt2.sportFK = {{SPORT_ID}}
      -- The boundary and the narrowing repeated inside the derived table, not only outside it.
      -- Without them this scans the sport's whole outcome layer and then throws away what the
      -- outer scope excludes: on Soccer that is 1.78 million rows to answer a question about
      -- 6 318 events. -TemplateIds activates every marker in the statement, so putting one here
      -- is what lets a narrowed run narrow the join it actually depends on.
      AND t2.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      -- AND t2.tournament_templateFK = <tournament_template_id>
    GROUP BY ep2.eventFK
) oc ON oc.event_id = e.id
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND e.status_type = 'finished'
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND (pr.id IS NULL OR LOWER(TRIM(pr.value)) NOT IN ({{WINNER_VALUE_LIST}}))
  AND (oc.event_id IS NULL OR oc.has_usable = 0)
  -- Only where a winner is there to be recorded. An event holding fewer than two scored sides
  -- has a different defect and its own check, and reporting it here would say the winner was
  -- dropped when it was never determinable. Measured 2026-08-29: this excludes 3 of Handball's
  -- 40 313 and none of Soccer's 4 662, so it changes almost nothing and stops the check from
  -- claiming something it has not established.
  AND (
      SELECT COUNT(DISTINCT ep3.id)
      FROM event_participants ep3
      JOIN result r3 ON r3.event_participantsFK = ep3.id AND r3.del = 'no'
                    AND r3.result_typeFK = {{RESULT_FINAL_SCORE_TYPE_ID}}
                    AND r3.value IS NOT NULL AND TRIM(r3.value) <> ''
      WHERE ep3.eventFK = e.id AND ep3.del = 'no'
  ) >= 2

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
  -- AND EXISTS (SELECT 1 FROM object_discipline dsc_e WHERE dsc_e.object_typeFK = 5 AND dsc_e.objectFK = e.id AND dsc_e.disciplineFK IN (<discipline_ids>) AND dsc_e.del = 'no')
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
  -- AND EXISTS (SELECT 1 FROM object_discipline dsc_e WHERE dsc_e.object_typeFK = 5 AND dsc_e.objectFK = e.id AND dsc_e.disciplineFK IN (<discipline_ids>) AND dsc_e.del = 'no')
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
  -- AND EXISTS (SELECT 1 FROM object_discipline dsc_e WHERE dsc_e.object_typeFK = 5 AND dsc_e.objectFK = e.id AND dsc_e.disciplineFK IN (<discipline_ids>) AND dsc_e.del = 'no')
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
  -- AND EXISTS (SELECT 1 FROM object_discipline dsc_e WHERE dsc_e.object_typeFK = 5 AND dsc_e.objectFK = e.id AND dsc_e.disciplineFK IN (<discipline_ids>) AND dsc_e.del = 'no')
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
  -- AND EXISTS (SELECT 1 FROM object_discipline dsc_e WHERE dsc_e.object_typeFK = 5 AND dsc_e.objectFK = e.id AND dsc_e.disciplineFK IN (<discipline_ids>) AND dsc_e.del = 'no')
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
  -- AND EXISTS (SELECT 1 FROM object_discipline dsc_e WHERE dsc_e.object_typeFK = 5 AND dsc_e.objectFK = e.id AND dsc_e.disciplineFK IN (<discipline_ids>) AND dsc_e.del = 'no')
  AND (
      LOWER(TRIM(rt.name)) IN ({{ELIMINATION_ROUND_NAME_LIST}})
      OR LOWER(TRIM(rt.name)) IN ({{GROUP_ROUND_NAME_LIST}})
  )

ORDER BY sort_order, event_startdate DESC;

-- ================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-133
    -- Name - TEMPLATE_GENDER_NOT_REFLECTED_IN_ITS_STAGES
    -- What it does: Flags templates whose declared gender is contradicted by the stages beneath them, in either direction.
    CASE
        WHEN LOWER(TRIM(tt.gender)) = 'mixed'
            THEN 'Template_Mixed_But_Not_Every_Stage_Is'
        ELSE 'Template_Gender_Not_Reflected_In_Any_Stage'
    END AS check_type,
    tt.id AS tournament_template_id,
    tt.name AS template_name,
    tt.gender AS template_gender,
    GROUP_CONCAT(DISTINCT ts.gender ORDER BY ts.gender SEPARATOR ', ') AS stage_genders_found,
    COUNT(DISTINCT ts.id) AS stage_count,
    SUM(CASE WHEN LOWER(TRIM(ts.gender)) <> LOWER(TRIM(tt.gender)) OR ts.gender IS NULL THEN 1 ELSE 0 END) AS stages_not_matching,
    COUNT(DISTINCT t.id) AS tournament_count,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: A template declares a gender and the stages beneath it carry
-- one each. This reads the two against each other from the template's side and reports where
-- the declaration is not what the stages say, which is two different contradictions.
-- **It is the inverse of `GLOBAL-DQ-014` and exists because that check cannot see either of
-- them.** `GLOBAL-DQ-014` compares one stage against its template and skips mixed on either
-- side, so a template declaring male whose every stage is mixed passes it silently - each
-- comparison is skipped, one at a time, and nothing is left to report. Read from the template
-- instead, the same rows say plainly that a declaration is contradicted by the whole population
-- beneath it. The two are not redundant: `GLOBAL-DQ-014` catches the odd stage inside a
-- correctly declared template, this catches the declaration itself.
-- **`mixed` means competitors of both genders together, and it means that at every level.** A
-- template declared mixed is therefore expected to hold mixed stages and nothing else, which is
-- what the database does: measured 2026-08-21 across the eleven documented sports, 173 of the
-- 178 mixed templates carry only mixed stages - Curling's `11418 European Mixed Championships`
-- and `11395 World Mixed Championships`, all 227 stages of Equestrian's `10853 FEI Jumping World
-- Cup Western European League`, and so on. The five exceptions are all in Golf and not one of
-- them holds a single mixed stage: `10328 Asian Games` carries 5 male stages and 5 female,
-- `10327 Pan American Games` 3 and 3, `11532 Southeast Asian Games` 3 and 3, `11498 Summer Youth
-- Olympics` 2 and 2, and `9831 GolfSixes` 15 male and no female. A men's event and a women's
-- event are two competitions and belong under two templates, which is how every other sport in
-- the package models them - Ice Hockey pairs `31 Winter Olympics` female with `32` male and
-- `33 World Championship 1` male with `10083` female. Using mixed to mean "covers both genders
-- separately" overloads the word that elsewhere means "contested by both together", and reading
-- one as the other is the mistake this branch exists to stop.
-- **Golf settles it against itself, which is why the repair is not in doubt here.** The sport
-- already models the same shape both ways, inside one list of medal templates, measured
-- 2026-08-21: `9600 Summer Olympics` male and `9601 Summer Olympics` female are two templates,
-- `10537` and `10538 Pacific Games` are two, `11507 British Boys Amateur Championship` and
-- `11524 British Girls Amateur Championship` are two, `11526 European Boys' Team Championship`
-- and `11525 European Girls' Team Championship` are two - and the four reported here are the
-- same kind of Games entered as one. So the correction is to split them, and it is the sport's
-- own established practice rather than a convention imposed from outside. `9779 European
-- Championships 1` shows the other side of the line intact: mixed, holding a genuinely mixed
-- stage, and correctly left alone.
-- **The audited object is the template**, and that is the reason the check reads the way it
-- does. A template's gender is one setting, so one wrong setting is one repair however many
-- stages sit under it: measured 2026-08-21 the six templates reported cover 149 stages, and
-- reported per stage the same six one-word corrections would arrive as 149 findings.
-- `stage_count`, `stages_not_matching`, `stage_genders_found` and `tournament_count` carry the
-- exposure as named secondary columns.
-- **Which side is wrong is not asserted.** A template declaring male over mixed stages is either
-- a template set to the wrong gender or a population of stages mislabelled, and the database
-- cannot say which; what is asserted is that the two disagree, which is a thing somebody has to
-- look at either way. Where the entrants settle it they are worth reading: `11379 FEI Jumping
-- World Cup New Zealand League` is declared male and its events hold 44 male and 74 female
-- entrants, so there the template is the wrong side, since equestrian sport is contested by both
-- genders together. In Golf's four Games templates it is the template that is wrong in the other
-- direction - the stages correctly say Men's Individual and Women's Individual, and it is the
-- one template covering both that should be two.
-- Promoted from `Equestrian-DQ-072` on 2026-08-21 after profiling the 182 stages the mixed
-- exclusion in `GLOBAL-DQ-014` hides across the documented sports. Three of the four shapes
-- found there are already covered elsewhere - genuinely mixed events correctly labelled, the
-- same template's other stages reported by `GLOBAL-DQ-014`, and women entered in male stages
-- reported by `GLOBAL-DQ-123` - and the fourth is the first branch here. The mixed branch was
-- added the same day, after the first version excluded mixed templates outright on the argument
-- that mixed is satisfied by any stage gender. That argument holds for one stage and fails for a
-- template: a declaration nothing beneath it carries is contradicted whatever the word is.
-- The client boundary is applied to the stages the template is judged on, so a template that ran
-- male stages before the cutoff and mixed ones ever since is read on the window the client
-- actually asked for rather than on a season nobody is looking at.
FROM tournament_template tt
JOIN tournament t
  ON t.tournament_templateFK = tt.id
 AND t.del = 'no'
JOIN tournament_stage ts
  ON ts.tournamentFK = t.id
 AND ts.del = 'no'
WHERE tt.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND tt.gender IS NOT NULL
  AND TRIM(tt.gender) <> ''
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
GROUP BY
    tt.id,
    tt.name,
    tt.gender
-- The two branches are mutually exclusive because `tt.gender` decides which applies, so a
-- template is reported once and under one check_type. A mixed template is judged on every stage
-- and a definite one on whether any stage agrees at all - deliberately not the same test, since
-- a male template legitimately holds mixed stages for a mixed event inside a men's competition,
-- and a mixed template holding a single-gender stage has no such reading.
HAVING (
        LOWER(TRIM(tt.gender)) = 'mixed'
    AND SUM(CASE WHEN LOWER(TRIM(ts.gender)) = 'mixed' THEN 1 ELSE 0 END) < COUNT(DISTINCT ts.id)
       )
    OR (
        LOWER(TRIM(tt.gender)) <> 'mixed'
    AND SUM(CASE WHEN LOWER(TRIM(ts.gender)) = LOWER(TRIM(tt.gender)) THEN 1 ELSE 0 END) = 0
       )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT tt.id) AS eligible_count,
    1 AS sort_order
FROM tournament_template tt
JOIN tournament t
  ON t.tournament_templateFK = tt.id
 AND t.del = 'no'
JOIN tournament_stage ts
  ON ts.tournamentFK = t.id
 AND ts.del = 'no'
WHERE tt.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND tt.gender IS NOT NULL
  AND TRIM(tt.gender) <> ''
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, stage_count DESC, tournament_template_id;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-139
    -- Name - TEMPLATE_TOURNAMENT_YEAR_CLAIMED_BY_SPAN_AND_SINGLE_SEASON
    -- What it does: Finds templates where one year is claimed both by a two-year season name and by a single-year one.
    'Year_Claimed_By_Span_And_Single_Season' AS check_type,
    x.template_id,
    x.template_name,
    (
        SELECT COUNT(DISTINCT t9.id)
        FROM tournament t9
        WHERE t9.tournament_templateFK = x.template_id AND t9.del = 'no'
    ) AS tournaments_in_template,
    x.colliding_years,
    x.first_colliding_year,
    x.collision_detail,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds tournament templates holding two editions that lay
-- claim to the same calendar year by their names, where one of the two names is a two-year
-- season such as `2003/2004` and the other is a single year such as `2004`.
-- A template is one recurring competition and its editions are its seasons, so a year belongs
-- to one edition of it. The two naming forms are each fine on their own and the check says
-- nothing against either: a season crossing the new year is written `2003/2004` and a season
-- inside one is written `2004`. What cannot be true is both at once for the same year.
-- Measured 2026-08-24 across the twelve documented sports, exactly two name forms exist in
-- this database - `2003/2004` on 8149 tournaments and a single year on 12166 - with no
-- two-digit span, no dash form and no tournament without a year, so the statement needs no
-- branch for a shape that does not occur.
-- **Two neighbouring spans sharing a year is not this defect and is not reported.** In a
-- season-crossing series `2003/2004` and `2004/2005` share 2004 by construction, which is
-- what the naming means, and a statement flagging it would report every properly named league
-- in the database. The collision has to be between the two forms, which is why one side of
-- the join is spans and the other is single years rather than both sides being everything.
-- Nor is a clean change of calendar this defect: a series running `2003/2004` through
-- `2005/2006` and then `2007`, `2008` onwards has switched its calendar and left no year
-- claimed twice, and that shape is silent here.
-- Measured on the same day, 124 templates in the twelve sports report - 107 of them Soccer,
-- 8 Ice Hockey, 4 Equestrian, 2 Artistic Gymnastics, and one each in Curling, Speed Skating
-- and Swimming. Soccer is where the signal needs reading rather than believing: a league that
-- moved from a season-crossing calendar to a calendar year genuinely held both `2013/2014` and
-- `2014`, and several countries file a half-season such as `2008 Fall` beside the whole
-- `2008/2009`. Both are history rather than a defect, so a sport whose findings are of that
-- kind records the signal its file decides on instead of a repair.
-- The audited object is the template. One template is one decision about how its series is
-- named, and `collision_detail` names both tournaments of every colliding year so the reader
-- can see which edition is the odd one without opening the template.
-- Editions absent from the series are GLOBAL-DQ-081's finding, a name contradicting its own
-- dates is GLOBAL-DQ-080's, and a name breaking text hygiene is GLOBAL-DQ-078's. None of the
-- three compares one edition's name with another's, which is what this one does.
FROM (
    SELECT
        c.template_id,
        MIN(c.template_name) AS template_name,
        COUNT(*) AS colliding_years,
        MIN(c.yr) AS first_colliding_year,
        SUBSTRING(GROUP_CONCAT(CONCAT(c.yr, ': ', c.span_name, ' and ', c.single_name)
            ORDER BY c.yr SEPARATOR ' | '), 1, 400) AS collision_detail
    FROM (
        SELECT
            a.template_id,
            a.template_name,
            a.yr,
            MIN(a.tournament_name) AS span_name,
            MIN(b.tournament_name) AS single_name
        FROM (
            SELECT
                tt.id AS template_id,
                tt.name AS template_name,
                t.name AS tournament_name,
                CAST(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1) AS UNSIGNED) AS yr
            FROM tournament t
            JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
                 AND tt.sportFK = {{SPORT_ID}}
            WHERE t.del = 'no'
              AND t.name REGEXP '(19|20)[0-9]{2}/(19|20)[0-9]{2}'
              AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
              AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
              AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
              -- AND t.tournament_templateFK = <tournament_template_id>

            UNION ALL

            -- The second year the same span name claims. A span is one edition holding two
            -- calendar years, so it is compared on both of them rather than on the one the
            -- client boundary happens to read.
            SELECT
                tt.id,
                tt.name,
                t.name,
                CAST(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2) AS UNSIGNED)
            FROM tournament t
            JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
                 AND tt.sportFK = {{SPORT_ID}}
            WHERE t.del = 'no'
              AND t.name REGEXP '(19|20)[0-9]{2}/(19|20)[0-9]{2}'
              AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
              AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
              AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
              -- AND t.tournament_templateFK = <tournament_template_id>
        ) a
        JOIN (
            SELECT
                tt.id AS template_id,
                t.name AS tournament_name,
                CAST(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1) AS UNSIGNED) AS yr
            FROM tournament t
            JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
                 AND tt.sportFK = {{SPORT_ID}}
            WHERE t.del = 'no'
              AND t.name REGEXP '(19|20)[0-9]{2}'
              AND t.name NOT REGEXP '(19|20)[0-9]{2}/(19|20)[0-9]{2}'
              AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
              AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
              AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
              -- AND t.tournament_templateFK = <tournament_template_id>
        ) b ON b.template_id = a.template_id AND b.yr = a.yr
        GROUP BY a.template_id, a.template_name, a.yr
    ) c
    GROUP BY c.template_id
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT tt.id) AS eligible_count,
    1 AS sort_order
FROM tournament_template tt
JOIN tournament t ON t.tournament_templateFK = tt.id AND t.del = 'no'
WHERE tt.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND t.name REGEXP '(19|20)[0-9]{2}'
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, colliding_years DESC, template_id;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-140
    -- Name - TEMPLATE_TOURNAMENT_EDITIONS_OVERLAP_IN_TIME
    -- What it does: Finds templates holding two editions whose stages run at the same time.
    'Editions_Overlap_In_Time' AS check_type,
    x.template_id,
    x.template_name,
    (
        SELECT COUNT(DISTINCT t9.id)
        FROM tournament t9
        WHERE t9.tournament_templateFK = x.template_id AND t9.del = 'no'
    ) AS tournaments_in_template,
    x.overlapping_pairs,
    x.overlap_detail,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds tournament templates two of whose tournaments cover the
-- same days, measured from the stages each one holds rather than from what its name says.
-- A template is one recurring competition and its tournaments are its editions, so they follow
-- one another: an edition ends before the next begins. Two of them running at once means one
-- of two things - either a single edition has been entered twice under different names, or a
-- stage has been filed under the neighbouring edition and dragged its dates across.
-- This is the companion of GLOBAL-DQ-139 and deliberately not the same question. 139 reads
-- the names and asks whether two of them claim one year; this reads the days and asks whether
-- two editions actually ran together. Neither subsumes the other and the gap between them is
-- real in both directions. A template can be named consistently and still overlap, which 139
-- cannot see. And an edition carrying no stage at all has no days to compare, so it is
-- invisible here however wrong its name is - the Artistic Gymnastics World Cup Apparatus
-- templates that started this pair of checks are exactly that case, their `2004/2005` and
-- `2020/2021` holding no stage between them. A tournament with no stages at all is
-- GLOBAL-DQ-063's finding and is not restated here.
-- Measured 2026-08-24 across the twelve documented sports, 53 templates report: 38 in Soccer,
-- 5 each in Equestrian and Ice Hockey, 3 in Golf, and one each in Cycling and Speed Skating.
-- The audited object is the template, and `overlapping_pairs` counts the pairs rather than the
-- tournaments, because one edition overlapping three others is three facts about one template
-- and one repair to plan. `overlap_detail` names both editions of each pair with the days each
-- one covers, so the reader can tell a duplicated edition from a stray stage without opening
-- either.
-- The comparison is inclusive at both ends: two editions sharing a single day overlap. An
-- edition ending on the last minute of a year and the next starting in the new one do not.
FROM (
    SELECT
        a.template_id,
        MIN(a.template_name) AS template_name,
        COUNT(*) AS overlapping_pairs,
        SUBSTRING(GROUP_CONCAT(
            CONCAT(a.tournament_name, ' ', DATE(a.first_day), '..', DATE(a.last_day),
                   ' with ', b.tournament_name, ' ', DATE(b.first_day), '..', DATE(b.last_day))
            ORDER BY a.first_day SEPARATOR ' | '), 1, 400) AS overlap_detail
    FROM (
        SELECT
            tt.id AS template_id,
            tt.name AS template_name,
            t.id AS tournament_id,
            t.name AS tournament_name,
            MIN(ts.startdate) AS first_day,
            MAX(ts.enddate) AS last_day
        FROM tournament t
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
             AND tt.sportFK = {{SPORT_ID}}
        JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
             AND ts.startdate IS NOT NULL AND ts.enddate IS NOT NULL
        WHERE t.del = 'no'
          AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
          AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
          -- AND t.tournament_templateFK = <tournament_template_id>
        GROUP BY tt.id, tt.name, t.id, t.name
    ) a
    JOIN (
        SELECT
            tt.id AS template_id,
            t.id AS tournament_id,
            t.name AS tournament_name,
            MIN(ts.startdate) AS first_day,
            MAX(ts.enddate) AS last_day
        FROM tournament t
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
             AND tt.sportFK = {{SPORT_ID}}
        JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
             AND ts.startdate IS NOT NULL AND ts.enddate IS NOT NULL
        WHERE t.del = 'no'
          AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
          AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
          -- AND t.tournament_templateFK = <tournament_template_id>
        GROUP BY tt.id, t.id, t.name
    ) b
      ON  b.template_id = a.template_id
      AND b.tournament_id > a.tournament_id
      AND a.first_day <= b.last_day
      AND b.first_day <= a.last_day
    GROUP BY a.template_id
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT tt.id) AS eligible_count,
    1 AS sort_order
FROM tournament_template tt
JOIN tournament t ON t.tournament_templateFK = tt.id AND t.del = 'no'
JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
     AND ts.startdate IS NOT NULL AND ts.enddate IS NOT NULL
WHERE tt.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, overlapping_pairs DESC, template_id;
-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-150
    -- Name - TOURNAMENT_STAGE_DATE_RANGE_WIDER_THAN_ITS_EVENTS
    -- What it does: Flags a stage declaring more whole calendar days than its events occupy, beyond the slack the sport's format allows.
    CASE
        WHEN x.empty_days_before > 0 AND x.empty_days_after > 0 THEN 'STAGE_RANGE_WIDE_AT_BOTH_ENDS'
        WHEN x.empty_days_before > 0 THEN 'STAGE_RANGE_STARTS_TOO_EARLY'
        ELSE 'STAGE_RANGE_ENDS_TOO_LATE'
    END AS check_type,
    x.tournament_stage_id,
    x.tournament_stage_name,
    x.template_name,
    x.tournament_name,
    x.stage_startdate,
    x.stage_enddate,
    x.event_count,
    x.earliest_event_startdate,
    x.latest_event_startdate,
    x.empty_days_before,
    x.empty_days_after,
    NULL AS eligible_count
-- What it does, stated in full: Finds a stage whose declared range contains its events and is
-- still wider than them, counted in whole calendar days at each end. A stage is the container
-- for the competition it names, and days it claims but never uses are days the calendar is
-- wrong about.
-- This is the other half of GLOBAL-DQ-004 and the two do not overlap. That one finds an event
-- outside the stage and this one only judges a stage that already contains every one of its
-- events, which is why a stage reported there is never reported here.
-- STAGE_DATE_TOLERANCE_DAYS is how much unused width the sport's format allows, and it exists
-- because one measure cannot serve every format. Most sports write a stage as the day or days
-- their events are actually held, so 0 is correct for them and any unused day is a defect.
-- Golf is the exception the parameter was measured on: a tournament runs Thursday to Sunday and
-- the whole of it is stored as one event, so a correct four-day stage carries three unused days
-- by construction. Measured 2026-08-31 across 5313 Golf stages, 5019 hold exactly one event and
-- the arithmetic is exact for them - unused days are the span minus one - so a tolerance of 3
-- is precisely the rule that a golf stage may not run longer than four days. It also spares a
-- genuinely long stage whose events fill it, which a rule written on the span alone would not.
-- Hours are not read at either end. A sport writing a stage as whole days, 00:00:00 to
-- 23:59:59, differs from its events by hours while using every day it claims, and counting that
-- as width would report the format instead of the defect. This is the same trap equality fell
-- into before GLOBAL-DQ-004 was changed to containment on 2026-08-26.
-- A stage or event with no date is not judged here at all; GLOBAL-DQ-005 owns the missing date.
-- The audited object is the stage. Coverage counts every dated stage holding at least one dated
-- event, whatever its width, so eligible does not move when the data is corrected.
FROM (
    SELECT
        ts.id AS tournament_stage_id,
        ts.name AS tournament_stage_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        ts.startdate AS stage_startdate,
        ts.enddate AS stage_enddate,
        COUNT(DISTINCT e.id) AS event_count,
        MIN(e.startdate) AS earliest_event_startdate,
        MAX(e.startdate) AS latest_event_startdate,
        DATEDIFF(DATE(MIN(e.startdate)), DATE(ts.startdate)) AS empty_days_before,
        DATEDIFF(DATE(ts.enddate), DATE(MAX(e.startdate))) AS empty_days_after
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
      -- AND EXISTS (SELECT 1 FROM object_discipline dsc_e WHERE dsc_e.object_typeFK = 5 AND dsc_e.objectFK = e.id AND dsc_e.disciplineFK IN (<discipline_ids>) AND dsc_e.del = 'no')
      AND ts.startdate IS NOT NULL
      AND ts.enddate IS NOT NULL
      AND e.startdate IS NOT NULL
    GROUP BY
        ts.id,
        ts.name,
        tt.name,
        t.name,
        ts.startdate,
        ts.enddate
) x
WHERE x.empty_days_before >= 0
  AND x.empty_days_after >= 0
  AND x.empty_days_before + x.empty_days_after > {{STAGE_DATE_TOLERANCE_DAYS}}

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
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
  AND ts.startdate IS NOT NULL
  AND ts.enddate IS NOT NULL
  AND EXISTS (
      SELECT 1
      FROM event e2
      WHERE e2.tournament_stageFK = ts.id
        AND e2.del = 'no'
        AND e2.startdate IS NOT NULL
        -- AND EXISTS (SELECT 1 FROM object_discipline dsc_e2 WHERE dsc_e2.object_typeFK = 5 AND dsc_e2.objectFK = e2.id AND dsc_e2.disciplineFK IN (<discipline_ids>) AND dsc_e2.del = 'no')
  );
