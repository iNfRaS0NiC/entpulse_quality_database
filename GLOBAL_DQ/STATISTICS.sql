SELECT
    -- CheckID - GLOBAL-DQ-010
    -- Name - COMP.RANK_NO_PARTICIPANTS
    -- What it does: Finds active tournament-owned statistics of the selected statistic type with zero active participant rows in the confirmed physical shard, with template and tournament name context, together with a coverage count of all eligible statistics.
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
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
  AND NOT EXISTS (
      SELECT 1
      FROM statistic_participants{{SHARD_ID}} sp
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
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-011
    -- Name - COMP.RANK_SETTINGS_MISSING_START_OR_END_DATE
    -- What it does: Finds active tournament-owned statistics of the selected statistic type with a missing or empty Start date or End date config value, with template and tournament name context, together with a coverage count of all eligible statistics.
    'Missing_Start_Or_End_Date' AS check_type,
    s.id AS statistic_id,
    s.name AS statistic_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    CONCAT_WS(', ',
        IF(NOT EXISTS (
            SELECT 1 FROM statistic_config sc1
            WHERE sc1.statisticFK = s.id
              AND sc1.statistic_data_typeFK = {{CONFIG_START_DATE_TYPE_ID}}
              AND sc1.del = 'no'
              AND sc1.value IS NOT NULL
              AND TRIM(sc1.value) <> ''
        ), 'start_date', NULL),
        IF(NOT EXISTS (
            SELECT 1 FROM statistic_config sc2
            WHERE sc2.statisticFK = s.id
              AND sc2.statistic_data_typeFK = {{CONFIG_END_DATE_TYPE_ID}}
              AND sc2.del = 'no'
              AND sc2.value IS NOT NULL
              AND TRIM(sc2.value) <> ''
        ), 'end_date', NULL)
    ) AS missing_fields,
    NULL AS eligible_count
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
  AND (
      NOT EXISTS (
          SELECT 1 FROM statistic_config sc3
          WHERE sc3.statisticFK = s.id
            AND sc3.statistic_data_typeFK = {{CONFIG_START_DATE_TYPE_ID}}
            AND sc3.del = 'no'
            AND sc3.value IS NOT NULL
            AND TRIM(sc3.value) <> ''
      )
      OR NOT EXISTS (
          SELECT 1 FROM statistic_config sc4
          WHERE sc4.statisticFK = s.id
            AND sc4.statistic_data_typeFK = {{CONFIG_END_DATE_TYPE_ID}}
            AND sc4.del = 'no'
            AND sc4.value IS NOT NULL
            AND TRIM(sc4.value) <> ''
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
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-012
    -- Name - COMP.RANK_RESULTS_RANK_INVALID_OR_MISSING
    -- What it does: Finds active tournament-owned statistics of the selected statistic type holding at least one participant whose Rank data value is missing, empty, non-numeric or not a positive integer, with template and tournament name context and the count of affected participant rows, together with a coverage count of all eligible statistics.
    'Rank_Invalid_Or_Missing' AS check_type,
    s.id AS statistic_id,
    s.name AS statistic_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    COUNT(DISTINCT sp.id) AS violating_record_count,
    NULL AS eligible_count
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = s.id AND sp.del = 'no'
LEFT JOIN statistic_data{{SHARD_ID}} sd
  ON sd.statistic_participants{{SHARD_ID}}FK = sp.id
 AND sd.statistic_data_typeFK = {{DATA_RANK_TYPE_ID}}
 AND sd.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
  AND (
      sd.id IS NULL
      OR sd.value IS NULL
      OR TRIM(sd.value) = ''
      OR TRIM(sd.value) NOT REGEXP '^[1-9][0-9]*$'
  )
GROUP BY s.id, s.name, tt.name, t.name

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = s.id AND sp.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
;
