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


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-022
    -- Name - COMP.RANK_SETTINGS_MISSING_AGE_CLASS
    -- What it does: Finds active tournament-owned statistics of the selected statistic type without an active tournament_age_class relation via object_relation (owner type=83), with template and tournament name context, together with a coverage count of all eligible statistics.
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
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
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
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-023
    -- Name - COMP.RANK_SETTINGS_MISSING_DISCIPLINE
    -- What it does: Finds active tournament-owned statistics of the selected statistic type with zero active object_discipline relations (owner type=83), or with an active relation whose disciplineFK does not resolve to any active discipline row, with template and tournament name context, together with a coverage count of all eligible statistics.
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
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
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
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-024
    -- Name - COMP.RANK_SETTINGS_DATE_RANGE_MISMATCH_STAGE
    -- What it does: Finds active tournament-owned statistics of the selected statistic type whose Start date and End date config values do not match the earliest and latest active tournament_stage start and end date under the statistic's tournament, with template and tournament name context, together with a coverage count of all eligible statistics carrying at least one active config date.
    'Date_Range_Mismatch_Stage' AS check_type,
    s.id AS statistic_id,
    s.name AS statistic_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    (SELECT MIN(sc1.value) FROM statistic_config sc1 WHERE sc1.statisticFK = s.id AND sc1.statistic_data_typeFK = {{CONFIG_START_DATE_TYPE_ID}} AND sc1.del = 'no') AS config_start_date,
    (SELECT MAX(sc2.value) FROM statistic_config sc2 WHERE sc2.statisticFK = s.id AND sc2.statistic_data_typeFK = {{CONFIG_END_DATE_TYPE_ID}} AND sc2.del = 'no') AS config_end_date,
    MIN(ts.startdate) AS earliest_stage_startdate,
    MAX(ts.enddate) AS latest_stage_enddate,
    NULL AS eligible_count
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
GROUP BY s.id, s.name, tt.name, t.name
HAVING (
    DATE((SELECT MIN(sc1.value) FROM statistic_config sc1 WHERE sc1.statisticFK = s.id AND sc1.statistic_data_typeFK = {{CONFIG_START_DATE_TYPE_ID}} AND sc1.del = 'no')) <> DATE(MIN(ts.startdate))
    OR DATE((SELECT MAX(sc2.value) FROM statistic_config sc2 WHERE sc2.statisticFK = s.id AND sc2.statistic_data_typeFK = {{CONFIG_END_DATE_TYPE_ID}} AND sc2.del = 'no')) <> DATE(MAX(ts.enddate))
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
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
  AND EXISTS (
      SELECT 1 FROM statistic_config sc3
      WHERE sc3.statisticFK = s.id AND sc3.statistic_data_typeFK IN ({{CONFIG_START_DATE_TYPE_ID}}, {{CONFIG_END_DATE_TYPE_ID}}) AND sc3.del = 'no'
  );


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-025
    -- Name - COMP.RANK_SETTINGS_DATE_RANGE_MISMATCH_EVENTS
    -- What it does: Finds active tournament-owned statistics of the selected statistic type whose Start date and End date config values do not match the earliest and latest startdate of the events referenced through the Event id config field, with template and tournament name context, together with a coverage count of all eligible statistics with at least one linked event and at least one active config date.
    'Date_Range_Mismatch_Events' AS check_type,
    s.id AS statistic_id,
    s.name AS statistic_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    (SELECT MIN(sc1.value) FROM statistic_config sc1 WHERE sc1.statisticFK = s.id AND sc1.statistic_data_typeFK = {{CONFIG_START_DATE_TYPE_ID}} AND sc1.del = 'no') AS config_start_date,
    (SELECT MAX(sc2.value) FROM statistic_config sc2 WHERE sc2.statisticFK = s.id AND sc2.statistic_data_typeFK = {{CONFIG_END_DATE_TYPE_ID}} AND sc2.del = 'no') AS config_end_date,
    MIN(e.startdate) AS earliest_linked_event_startdate,
    MAX(e.startdate) AS latest_linked_event_startdate,
    NULL AS eligible_count
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN statistic_config sce ON sce.statisticFK = s.id AND sce.statistic_data_typeFK = {{CONFIG_EVENT_ID_TYPE_ID}} AND sce.del = 'no'
JOIN event e ON e.id = sce.value AND e.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
GROUP BY s.id, s.name, tt.name, t.name
HAVING (
    DATE((SELECT MIN(sc1.value) FROM statistic_config sc1 WHERE sc1.statisticFK = s.id AND sc1.statistic_data_typeFK = {{CONFIG_START_DATE_TYPE_ID}} AND sc1.del = 'no')) <> DATE(MIN(e.startdate))
    OR DATE((SELECT MAX(sc2.value) FROM statistic_config sc2 WHERE sc2.statisticFK = s.id AND sc2.statistic_data_typeFK = {{CONFIG_END_DATE_TYPE_ID}} AND sc2.del = 'no')) <> DATE(MAX(e.startdate))
)

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN statistic_config sce ON sce.statisticFK = s.id AND sce.statistic_data_typeFK = {{CONFIG_EVENT_ID_TYPE_ID}} AND sce.del = 'no'
JOIN event e ON e.id = sce.value AND e.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
  AND EXISTS (
      SELECT 1 FROM statistic_config sc3
      WHERE sc3.statisticFK = s.id AND sc3.statistic_data_typeFK IN ({{CONFIG_START_DATE_TYPE_ID}}, {{CONFIG_END_DATE_TYPE_ID}}) AND sc3.del = 'no'
  );


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-026
    -- Name - COMP.RANK_SETTINGS_MISSING_MEDAL
    -- What it does: Finds active tournament-owned statistics of the selected statistic type where at least one of the gold, silver or bronze Medal values is absent among statistic participants, distinguishing statistics with no medals at all from statistics missing only specific medal types, together with a coverage count of all eligible statistics.
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
    JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = s.id AND sp.del = 'no'
    LEFT JOIN statistic_data{{SHARD_ID}} sd
      ON sd.statistic_participants{{SHARD_ID}}FK = sp.id
     AND sd.del = 'no'
     AND sd.statistic_data_typeFK = {{DATA_MEDAL_TYPE_ID}}
    WHERE s.del = 'no'
      AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
      AND s.object_typeFK = 3
      AND tt.sportFK = {{SPORT_ID}}
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
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
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-027
    -- Name - COMP.RANK_RESULTS_MEDAL_INVALID_VALUE
    -- What it does: Finds active statistic-participant Medal rows of the selected statistic type, excluding IOC-purpose templates, whose value is present but not one of the accepted values gold, silver or bronze, together with a coverage count of all eligible statistic-participant rows carrying any active, non-empty Medal value.
    'Medal_Invalid_Value' AS check_type,
    s.id AS statistic_id,
    s.name AS statistic_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    p.name AS participant_name,
    sd.value AS medal_value,
    NULL AS eligible_count
FROM statistic_data{{SHARD_ID}} sd
JOIN statistic_participants{{SHARD_ID}} sp ON sp.id = sd.statistic_participants{{SHARD_ID}}FK AND sp.del = 'no'
JOIN statistic s ON s.id = sp.statisticFK AND s.del = 'no'
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN participant p ON p.id = sp.participantFK AND p.del = 'no'
WHERE sd.del = 'no'
  AND sd.statistic_data_typeFK = {{DATA_MEDAL_TYPE_ID}}
  AND sd.value IS NOT NULL
  AND TRIM(sd.value) <> ''
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
  AND LOWER(TRIM(sd.value)) NOT IN ('gold', 'silver', 'bronze')

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT sp.id) AS eligible_count
FROM statistic_data{{SHARD_ID}} sd
JOIN statistic_participants{{SHARD_ID}} sp ON sp.id = sd.statistic_participants{{SHARD_ID}}FK AND sp.del = 'no'
JOIN statistic s ON s.id = sp.statisticFK AND s.del = 'no'
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE sd.del = 'no'
  AND sd.statistic_data_typeFK = {{DATA_MEDAL_TYPE_ID}}
  AND sd.value IS NOT NULL
  AND TRIM(sd.value) <> ''
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-028
    -- Name - COMP.RANK_RESULTS_TIME_DIFFERENCE_FORMAT_MISMATCH_TO_RANK
    -- What it does: Finds active tournament-owned statistics of the selected statistic type, excluding IOC-purpose templates, containing at least one participant whose Time Difference value does not follow the leader/gap convention for their Rank value (rank 1 must be a plain absolute time with no plus sign while every other rank must be a plus-prefixed gap value), together with the count, type and per-participant detail of mismatching values per statistic and a coverage count of all eligible statistics with at least one participant having both an active rank and an active time-difference value.
    'Time_Difference_Format_Mismatch' AS check_type,
    s.id AS statistic_id,
    s.name AS statistic_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    COUNT(DISTINCT sp.id) AS violating_record_count,
    GROUP_CONCAT(DISTINCT
        CASE
            WHEN TRIM(rk.value) = '1' AND TRIM(td.value) REGEXP '^\\+' THEN 'RANK1_HAS_PLUS'
            WHEN TRIM(rk.value) = '1' THEN 'RANK1_WRONG_FORMAT'
            WHEN TRIM(rk.value) <> '1' AND TRIM(td.value) NOT REGEXP '^\\+' THEN 'NON_RANK1_MISSING_PLUS'
            ELSE 'NON_RANK1_WRONG_FORMAT'
        END
        ORDER BY 1 SEPARATOR ', '
    ) AS mismatch_types,
    GROUP_CONCAT(
        CONCAT('rank=', TRIM(rk.value), ' value=''', TRIM(td.value), '''')
        ORDER BY CAST(TRIM(rk.value) AS UNSIGNED) SEPARATOR ' | '
    ) AS mismatch_details,
    NULL AS eligible_count
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = s.id AND sp.del = 'no'
JOIN statistic_data{{SHARD_ID}} rk ON rk.statistic_participants{{SHARD_ID}}FK = sp.id AND rk.statistic_data_typeFK = {{DATA_RANK_TYPE_ID}} AND rk.del = 'no'
JOIN statistic_data{{SHARD_ID}} td ON td.statistic_participants{{SHARD_ID}}FK = sp.id AND td.statistic_data_typeFK = {{DATA_TIME_DIFFERENCE_TYPE_ID}} AND td.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
  AND TRIM(rk.value) <> ''
  AND TRIM(td.value) <> ''
  AND (
      (TRIM(rk.value) = '1' AND TRIM(td.value) NOT REGEXP '^[0-9]+(:[0-9]+)*(\\.[0-9]+)?$')
      OR
      (TRIM(rk.value) <> '1' AND TRIM(td.value) NOT REGEXP '^\\+[0-9]+(:[0-9]+)*(\\.[0-9]+)?$')
  )
GROUP BY s.id, s.name, tt.name, t.name

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = s.id AND sp.del = 'no'
JOIN statistic_data{{SHARD_ID}} rk ON rk.statistic_participants{{SHARD_ID}}FK = sp.id AND rk.statistic_data_typeFK = {{DATA_RANK_TYPE_ID}} AND rk.del = 'no'
JOIN statistic_data{{SHARD_ID}} td ON td.statistic_participants{{SHARD_ID}}FK = sp.id AND td.statistic_data_typeFK = {{DATA_TIME_DIFFERENCE_TYPE_ID}} AND td.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
  AND TRIM(rk.value) <> ''
  AND TRIM(td.value) <> ''
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-029
    -- Name - COMP.RANK_RESULTS_DEPRECATED_DURATION_USED
    -- What it does: Finds active tournament-owned statistics of the selected statistic type, excluding IOC-purpose templates, where at least one participant still stores an active, non-empty value in the deprecated Duration data field, reporting the count of participants using it and which of the current Time and Time Difference fields are also populated in the same statistic, together with a coverage count of all eligible statistics.
    'Deprecated_Duration_Used' AS check_type,
    s.id AS statistic_id,
    s.name AS statistic_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    COUNT(DISTINCT CASE WHEN sd.statistic_data_typeFK = {{DATA_DEPRECATED_DURATION_TYPE_ID}} THEN sp.id END) AS deprecated_duration_participant_count,
    CONCAT_WS(', ',
        IF(MAX(CASE WHEN sd.statistic_data_typeFK = {{DATA_TIME_TYPE_ID}} THEN 1 ELSE 0 END) = 1, 'Time', NULL),
        IF(MAX(CASE WHEN sd.statistic_data_typeFK = {{DATA_TIME_DIFFERENCE_TYPE_ID}} THEN 1 ELSE 0 END) = 1, 'Time_Difference', NULL)
    ) AS other_time_fields_used,
    NULL AS eligible_count
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = s.id AND sp.del = 'no'
JOIN statistic_data{{SHARD_ID}} sd
  ON sd.statistic_participants{{SHARD_ID}}FK = sp.id
 AND sd.del = 'no'
 AND sd.statistic_data_typeFK IN ({{DATA_DEPRECATED_DURATION_TYPE_ID}}, {{DATA_TIME_TYPE_ID}}, {{DATA_TIME_DIFFERENCE_TYPE_ID}})
 AND sd.value IS NOT NULL
 AND TRIM(sd.value) <> ''
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
GROUP BY s.id, s.name, tt.name, t.name
HAVING deprecated_duration_participant_count > 0

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL,
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
    -- CheckID - GLOBAL-DQ-030
    -- Name - COMP.RANK_RESULTS_PARTICIPANT_NOT_IN_TOURNAMENT
    -- What it does: Finds active statistic-participant rows of the selected statistic type, excluding IOC-purpose templates, whose participant takes part in no active event anywhere under the statistic's own tournament, with template and tournament name context, together with a coverage count of all eligible statistic-participant rows.
    'PARTICIPANT_NOT_IN_TOURNAMENT' AS check_type,
    sp.id AS statistic_participants_id,
    s.id AS statistic_id,
    tt.name AS template_name,
    t.name AS tournament_name,
    p.id AS participant_id,
    p.name AS participant_name,
    NULL AS eligible_count
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = s.id AND sp.del = 'no'
JOIN participant p ON p.id = sp.participantFK AND p.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
  AND NOT EXISTS (
      SELECT 1
      FROM tournament_stage ts2
      JOIN event e2 ON e2.tournament_stageFK = ts2.id AND e2.del = 'no'
      JOIN event_participants ep2 ON ep2.eventFK = e2.id AND ep2.del = 'no'
      WHERE ts2.tournamentFK = t.id
        AND ts2.del = 'no'
        AND ep2.participantFK = sp.participantFK
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT sp.id) AS eligible_count
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


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-031
    -- Name - COMP.RANK_RESULTS_RANK_OUTLIER_ABOVE_FIELD_SIZE
    -- What it does: Finds active statistic-participant rows of the selected statistic type, excluding IOC-purpose templates, whose numeric Rank value exceeds the number of active participants in their own statistic and is disconnected from the next lower Rank in that statistic, while carrying no active Comment value, with template and tournament name context, together with a coverage count of all eligible statistic-participant rows holding an active numeric Rank.
    'RANK_OUTLIER_ABOVE_FIELD_SIZE' AS check_type,
    sp.id AS statistic_participants_id,
    f.statistic_id,
    f.template_name,
    f.tournament_name,
    p.name AS participant_name,
    CAST(sd.value AS UNSIGNED) AS rank_value,
    f.participant_count,
    (
        SELECT MAX(CAST(sd2.value AS UNSIGNED))
        FROM statistic_participants{{SHARD_ID}} sp2
        JOIN statistic_data{{SHARD_ID}} sd2 ON sd2.statistic_participants{{SHARD_ID}}FK = sp2.id
             AND sd2.statistic_data_typeFK = {{DATA_RANK_TYPE_ID}}
             AND sd2.del = 'no'
             AND sd2.value REGEXP '^[1-9][0-9]*$'
        WHERE sp2.statisticFK = f.statistic_id
          AND sp2.del = 'no'
          AND CAST(sd2.value AS UNSIGNED) < CAST(sd.value AS UNSIGNED)
    ) AS next_lower_rank,
    NULL AS eligible_count
FROM (
    SELECT
        s.id AS statistic_id,
        tt.name AS template_name,
        t.name AS tournament_name,
        COUNT(DISTINCT spf.id) AS participant_count
    FROM statistic s
    JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN statistic_participants{{SHARD_ID}} spf ON spf.statisticFK = s.id AND spf.del = 'no'
    LEFT JOIN statistic_data{{SHARD_ID}} sdf ON sdf.statistic_participants{{SHARD_ID}}FK = spf.id
         AND sdf.statistic_data_typeFK = {{DATA_RANK_TYPE_ID}}
         AND sdf.del = 'no'
         AND sdf.value REGEXP '^[1-9][0-9]*$'
    WHERE s.del = 'no'
      AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
      AND s.object_typeFK = 3
      AND tt.sportFK = {{SPORT_ID}}
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      -- AND tt.id = <tournament_template_id>
    GROUP BY s.id, tt.name, t.name
    HAVING MAX(CAST(sdf.value AS UNSIGNED)) > COUNT(DISTINCT spf.id)
) f
JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = f.statistic_id AND sp.del = 'no'
JOIN participant p ON p.id = sp.participantFK AND p.del = 'no'
JOIN statistic_data{{SHARD_ID}} sd ON sd.statistic_participants{{SHARD_ID}}FK = sp.id
     AND sd.statistic_data_typeFK = {{DATA_RANK_TYPE_ID}}
     AND sd.del = 'no'
     AND sd.value REGEXP '^[1-9][0-9]*$'
WHERE CAST(sd.value AS UNSIGNED) > f.participant_count
  AND NOT EXISTS (
      SELECT 1
      FROM statistic_data{{SHARD_ID}} sdc
      WHERE sdc.statistic_participants{{SHARD_ID}}FK = sp.id
        AND sdc.statistic_data_typeFK = {{DATA_COMMENT_TYPE_ID}}
        AND sdc.del = 'no'
        AND sdc.value IS NOT NULL
        AND TRIM(sdc.value) <> ''
  )
HAVING next_lower_rank IS NULL
    OR rank_value > next_lower_rank + 1

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT sp.id) AS eligible_count
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = s.id AND sp.del = 'no'
JOIN statistic_data{{SHARD_ID}} sd ON sd.statistic_participants{{SHARD_ID}}FK = sp.id
     AND sd.statistic_data_typeFK = {{DATA_RANK_TYPE_ID}}
     AND sd.del = 'no'
     AND sd.value REGEXP '^[1-9][0-9]*$'
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-032
    -- Name - COMP.RANK_RESULTS_NO_RANK_DATA_FOR_PARTICIPANTS
    -- What it does: Finds active tournament-owned statistics of the selected statistic type, excluding IOC-purpose templates, that hold at least one active participant but no active non-empty Rank data value for any of them, separating statistics holding no data value of any type from those holding other data but no Rank, with template and tournament name context, together with a coverage count of all eligible statistics holding at least one active participant.
    CASE
        WHEN y.data_rows = 0 THEN 'PARTICIPANTS_BUT_NO_DATA_AT_ALL'
        ELSE 'DATA_BUT_NO_RANK_AT_ALL'
    END AS check_type,
    y.statistic_id,
    y.statistic_name,
    y.template_name,
    y.tournament_name,
    y.participant_count,
    NULL AS eligible_count
FROM (
    SELECT
        s.id AS statistic_id,
        s.name AS statistic_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        COUNT(DISTINCT sp.id) AS participant_count,
        COUNT(sd.id) AS data_rows,
        COUNT(CASE WHEN sd.statistic_data_typeFK = {{DATA_RANK_TYPE_ID}} THEN sd.id END) AS rank_rows
    FROM statistic s
    JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = s.id AND sp.del = 'no'
    LEFT JOIN statistic_data{{SHARD_ID}} sd ON sd.statistic_participants{{SHARD_ID}}FK = sp.id
         AND sd.del = 'no'
         AND sd.value IS NOT NULL
         AND TRIM(sd.value) <> ''
    WHERE s.del = 'no'
      AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
      AND s.object_typeFK = 3
      AND tt.sportFK = {{SPORT_ID}}
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      -- AND tt.id = <tournament_template_id>
    GROUP BY s.id, s.name, tt.name, t.name
) y
WHERE y.rank_rows = 0

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


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-033
    -- Name - COMP.RANK_RESULTS_MISSING_PHASE
    -- What it does: Finds active statistic-participant rows of the selected statistic type, excluding IOC-purpose templates, carrying no active object_round phase row (object_typeFK=138, type='phase'), with template and tournament name context and the participant's Rank value, together with a coverage count of all eligible statistic-participant rows.
    'MISSING_PHASE' AS check_type,
    sp.id AS statistic_participants_id,
    s.id AS statistic_id,
    tt.name AS template_name,
    t.name AS tournament_name,
    p.name AS participant_name,
    (
        SELECT sd.value
        FROM statistic_data{{SHARD_ID}} sd
        WHERE sd.statistic_participants{{SHARD_ID}}FK = sp.id
          AND sd.statistic_data_typeFK = {{DATA_RANK_TYPE_ID}}
          AND sd.del = 'no'
        LIMIT 1
    ) AS rank_value,
    NULL AS eligible_count
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = s.id AND sp.del = 'no'
JOIN participant p ON p.id = sp.participantFK AND p.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
  AND NOT EXISTS (
      SELECT 1
      FROM object_round orr
      WHERE orr.objectFK = sp.id
        AND orr.object_typeFK = 138
        AND orr.type = 'phase'
        AND orr.del = 'no'
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT sp.id) AS eligible_count
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


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-035
    -- Name - COMP.RANK_SETTINGS_MISSING_CORE_FIELDS
    -- What it does: Finds active tournament-owned statistics of the selected statistic type missing name, an active non-empty Gender config value, an active country relation (object_relation 83->33), or an active city relation (city_object owner type=83), with template and tournament name context, together with a coverage count of all eligible statistics.
    'Missing_Statistic_Field' AS check_type,
    s.id AS statistic_id,
    s.name AS statistic_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    CONCAT_WS(', ',
        IF(s.name IS NULL OR TRIM(s.name) = '', 'name', NULL),
        IF(NOT EXISTS (
            SELECT 1 FROM statistic_config sc
            WHERE sc.statisticFK = s.id AND sc.statistic_data_typeFK = {{CONFIG_GENDER_TYPE_ID}}
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
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
  AND (
      s.name IS NULL OR TRIM(s.name) = ''
      OR NOT EXISTS (
          SELECT 1 FROM statistic_config sc
          WHERE sc.statisticFK = s.id AND sc.statistic_data_typeFK = {{CONFIG_GENDER_TYPE_ID}}
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
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-040
    -- Name - EVENT_FINAL_WITHOUT_COMP.RANK
    -- What it does: Finds active events on a Final round type, excluding IOC-purpose templates, that no statistic of the selected type under their own tournament references through its Event id config field, separating tournaments holding no such statistic at all and tournaments whose statistics declare no event scope, with template, tournament and stage name context, together with a coverage count of all eligible Final-round events.
    CASE
        WHEN x.tournament_statistics = 0 THEN 'TOURNAMENT_HAS_NO_COMP_RANK'
        WHEN x.statistics_with_event_config = 0 THEN 'COMP.RANK_EVENT_SCOPE_UNDETERMINABLE'
        ELSE 'FINAL_EVENT_NOT_IN_ANY_COMP_RANK'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.template_name,
    x.tournament_name,
    x.stage_name,
    NULL AS eligible_count
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        ts.name AS stage_name,
        (
            SELECT COUNT(DISTINCT s.id)
            FROM statistic s
            JOIN statistic_config sc ON sc.statisticFK = s.id
                 AND sc.statistic_data_typeFK = {{CONFIG_EVENT_ID_TYPE_ID}}
                 AND sc.del = 'no'
            WHERE s.del = 'no'
              AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
              AND s.object_typeFK = 3
              AND s.objectFK = t.id
              AND CAST(sc.value AS UNSIGNED) = e.id
        ) AS referencing_statistics,
        (
            SELECT COUNT(*)
            FROM statistic s2
            WHERE s2.del = 'no'
              AND s2.statistic_typeFK = {{STATISTIC_TYPE_ID}}
              AND s2.object_typeFK = 3
              AND s2.objectFK = t.id
        ) AS tournament_statistics,
        (
            SELECT COUNT(DISTINCT s3.id)
            FROM statistic s3
            JOIN statistic_config sc3 ON sc3.statisticFK = s3.id
                 AND sc3.statistic_data_typeFK = {{CONFIG_EVENT_ID_TYPE_ID}}
                 AND sc3.del = 'no'
            WHERE s3.del = 'no'
              AND s3.statistic_typeFK = {{STATISTIC_TYPE_ID}}
              AND s3.object_typeFK = 3
              AND s3.objectFK = t.id
        ) AS statistics_with_event_config
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    WHERE e.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      AND e.round_typeFK IN ({{FINAL_ROUND_TYPE_LIST}})
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      -- AND tt.id = <tournament_template_id>
) x
WHERE x.referencing_statistics = 0

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
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-041
    -- Name - COMP.RANK_RESULTS_MEDAL_ON_NON_FINAL_PHASE
    -- What it does: Finds active statistic-participant rows of the selected statistic type, excluding IOC-purpose templates, carrying an active non-empty Medal value while their object_round phase names a round type that is not a Final, with template and tournament name context and the offending phase, together with a coverage count of all eligible statistic-participant rows carrying an active non-empty Medal value.
    'MEDAL_ON_NON_FINAL_PHASE' AS check_type,
    sp.id AS statistic_participants_id,
    s.id AS statistic_id,
    tt.name AS template_name,
    t.name AS tournament_name,
    p.name AS participant_name,
    sd.value AS medal_value,
    orr.round_typeFK AS phase_round_type_id,
    rt.name AS phase_round_name,
    NULL AS eligible_count
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = s.id AND sp.del = 'no'
JOIN participant p ON p.id = sp.participantFK AND p.del = 'no'
JOIN statistic_data{{SHARD_ID}} sd ON sd.statistic_participants{{SHARD_ID}}FK = sp.id
     AND sd.statistic_data_typeFK = {{DATA_MEDAL_TYPE_ID}}
     AND sd.del = 'no'
     AND sd.value IS NOT NULL
     AND TRIM(sd.value) <> ''
JOIN object_round orr ON orr.objectFK = sp.id
     AND orr.object_typeFK = 138
     AND orr.type = 'phase'
     AND orr.del = 'no'
LEFT JOIN round_type rt ON rt.id = orr.round_typeFK
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
  AND orr.round_typeFK NOT IN ({{FINAL_ROUND_TYPE_LIST}})

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT sp.id) AS eligible_count
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = s.id AND sp.del = 'no'
JOIN statistic_data{{SHARD_ID}} sd ON sd.statistic_participants{{SHARD_ID}}FK = sp.id
     AND sd.statistic_data_typeFK = {{DATA_MEDAL_TYPE_ID}}
     AND sd.del = 'no'
     AND sd.value IS NOT NULL
     AND TRIM(sd.value) <> ''
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-042
    -- Name - EVENT_FINAL_PARTICIPANT_NOT_IN_COMP.RANK
    -- What it does: Finds active event-participant rows in Final-round events, excluding IOC-purpose templates, whose participant appears in none of the populated statistics of the selected type that reference their event through the Event id config field, with template, tournament and event name context, together with a coverage count of all eligible Final-round event-participants whose event is referenced by at least one populated statistic.
    'FINAL_PARTICIPANT_NOT_IN_COMP.RANK' AS check_type,
    ep.id AS event_participants_id,
    e.id AS event_id,
    e.name AS event_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    p.name AS participant_name,
    NULL AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND e.round_typeFK IN ({{FINAL_ROUND_TYPE_LIST}})
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
  AND EXISTS (
      SELECT 1
      FROM statistic_config sc2
      JOIN statistic s2 ON s2.id = sc2.statisticFK
           AND s2.del = 'no'
           AND s2.statistic_typeFK = {{STATISTIC_TYPE_ID}}
           AND s2.object_typeFK = 3
      WHERE sc2.statistic_data_typeFK = {{CONFIG_EVENT_ID_TYPE_ID}}
        AND sc2.del = 'no'
        AND CAST(sc2.value AS UNSIGNED) = e.id
        AND EXISTS (
            SELECT 1
            FROM statistic_participants{{SHARD_ID}} spx
            WHERE spx.statisticFK = s2.id AND spx.del = 'no'
        )
  )
  AND NOT EXISTS (
      SELECT 1
      FROM statistic_config sc
      JOIN statistic s ON s.id = sc.statisticFK
           AND s.del = 'no'
           AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
           AND s.object_typeFK = 3
      JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = s.id
           AND sp.del = 'no'
           AND sp.participantFK = ep.participantFK
      WHERE sc.statistic_data_typeFK = {{CONFIG_EVENT_ID_TYPE_ID}}
        AND sc.del = 'no'
        AND CAST(sc.value AS UNSIGNED) = e.id
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ep.id) AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND e.round_typeFK IN ({{FINAL_ROUND_TYPE_LIST}})
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
  AND EXISTS (
      SELECT 1
      FROM statistic_config sc2
      JOIN statistic s2 ON s2.id = sc2.statisticFK
           AND s2.del = 'no'
           AND s2.statistic_typeFK = {{STATISTIC_TYPE_ID}}
           AND s2.object_typeFK = 3
      WHERE sc2.statistic_data_typeFK = {{CONFIG_EVENT_ID_TYPE_ID}}
        AND sc2.del = 'no'
        AND CAST(sc2.value AS UNSIGNED) = e.id
        AND EXISTS (
            SELECT 1
            FROM statistic_participants{{SHARD_ID}} spx
            WHERE spx.statisticFK = s2.id AND spx.del = 'no'
        )
  )
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-044
    -- Name - COMP.RANK_RESULTS_GENDER_MISMATCH
    -- What it does: Finds active tournament-owned statistics of the selected statistic type whose Gender config value does not match the gender composition of their statistic participants, classifying each violation type, together with a coverage count of all eligible statistics.
    'Gender_Mismatch' AS check_type,
    st.id AS statistic_id,
    st.name AS statistic_name,
    tt.name AS template_name,
    t.name AS tournament_name,
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
FROM statistic st
JOIN tournament t ON t.id = st.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN statistic_config sg ON sg.statisticFK = st.id AND sg.statistic_data_typeFK = {{CONFIG_GENDER_TYPE_ID}} AND sg.del = 'no'
     AND sg.value IN ('male','female','mixed')
JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = st.id AND sp.del = 'no'
JOIN participant p ON p.id = sp.participantFK AND p.del = 'no'
WHERE st.del = 'no'
  AND st.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND st.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
GROUP BY st.id, st.name, tt.name, t.name, sg.value
HAVING violation_type <> 'OK'

UNION ALL

SELECT
    'COVERAGE', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT st.id) AS eligible_count
FROM statistic st
JOIN tournament t ON t.id = st.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN statistic_config sg ON sg.statisticFK = st.id AND sg.statistic_data_typeFK = {{CONFIG_GENDER_TYPE_ID}} AND sg.del = 'no'
     AND sg.value IN ('male','female','mixed')
JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = st.id AND sp.del = 'no'
JOIN participant p ON p.id = sp.participantFK AND p.del = 'no'
WHERE st.del = 'no'
  AND st.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND st.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-046
    -- Name - COMP.RANK_RESULTS_TIME_FULL_TIME_MISMATCH_TO_RANK
    -- What it does: Finds active tournament-owned statistics of the selected statistic type restricted to the sport's timed disciplines, containing at least one participant whose time storage is inconsistent with their Rank: Time or Time Difference missing despite an active rank, either present without an active rank, or Time present with an invalid format, together with the distinct violation types and count of mismatching participants per statistic and a coverage count of all eligible statistics in those disciplines.
    'Time_Full_Time_Mismatch_Statistics' AS check_type,
    s.id AS statistic_id,
    s.name AS statistic_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    COUNT(DISTINCT x.statistic_participants_id) AS violating_record_count,
    CONCAT_WS(', ',
        IF(MAX(x.f_rank_time_missing) = 1, 'RANK_PRESENT_TIME_MISSING', NULL),
        IF(MAX(x.f_rank_td_missing) = 1, 'RANK_PRESENT_TIME_DIFFERENCE_MISSING', NULL),
        IF(MAX(x.f_time_no_rank) = 1, 'TIME_PRESENT_WITHOUT_RANK', NULL),
        IF(MAX(x.f_td_no_rank) = 1, 'TIME_DIFFERENCE_PRESENT_WITHOUT_RANK', NULL),
        IF(MAX(x.f_time_invalid) = 1, 'TIME_INVALID_FORMAT', NULL)
    ) AS violation_types,
    NULL AS eligible_count,
    0 AS sort_order
FROM (
    SELECT
        sp.id AS statistic_participants_id,
        sp.statisticFK AS statistic_id,
        (COUNT(DISTINCT rk.id) > 0 AND COUNT(DISTINCT tm.id) = 0) AS f_rank_time_missing,
        (COUNT(DISTINCT rk.id) > 0 AND COUNT(DISTINCT td.id) = 0) AS f_rank_td_missing,
        (COUNT(DISTINCT rk.id) = 0 AND COUNT(DISTINCT tm.id) > 0) AS f_time_no_rank,
        (COUNT(DISTINCT rk.id) = 0 AND COUNT(DISTINCT td.id) > 0) AS f_td_no_rank,
        (COUNT(DISTINCT rk.id) > 0 AND COUNT(DISTINCT tm.id) > 0
             AND MAX(tm.value) NOT REGEXP '^[0-9]+(:[0-9]+)*(\\.[0-9]+)?$') AS f_time_invalid
    FROM statistic_participants{{SHARD_ID}} sp
    JOIN statistic s2 ON s2.id = sp.statisticFK AND s2.del = 'no'
    JOIN tournament t ON t.id = s2.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    LEFT JOIN statistic_data{{SHARD_ID}} rk
      ON rk.statistic_participants{{SHARD_ID}}FK = sp.id AND rk.statistic_data_typeFK = {{DATA_RANK_TYPE_ID}} AND rk.del = 'no'
     AND rk.value IS NOT NULL AND TRIM(rk.value) <> ''
    LEFT JOIN statistic_data{{SHARD_ID}} tm
      ON tm.statistic_participants{{SHARD_ID}}FK = sp.id AND tm.statistic_data_typeFK = {{DATA_TIME_TYPE_ID}} AND tm.del = 'no'
     AND tm.value IS NOT NULL AND TRIM(tm.value) <> ''
    LEFT JOIN statistic_data{{SHARD_ID}} td
      ON td.statistic_participants{{SHARD_ID}}FK = sp.id AND td.statistic_data_typeFK = {{DATA_TIME_DIFFERENCE_TYPE_ID}} AND td.del = 'no'
     AND td.value IS NOT NULL AND TRIM(td.value) <> ''
    WHERE sp.del = 'no'
      AND s2.statistic_typeFK = {{STATISTIC_TYPE_ID}}
      AND s2.object_typeFK = 3
      AND tt.sportFK = {{SPORT_ID}}
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      -- AND tt.id = <tournament_template_id>
      AND EXISTS (
          SELECT 1 FROM object_discipline od
          WHERE od.object_typeFK = 83 AND od.objectFK = s2.id
            AND od.disciplineFK IN ({{TIMED_DISCIPLINE_LIST}}) AND od.del = 'no'
      )
    GROUP BY sp.id, sp.statisticFK
    HAVING f_rank_time_missing OR f_rank_td_missing OR f_time_no_rank OR f_td_no_rank OR f_time_invalid
) x
JOIN statistic s ON s.id = x.statistic_id
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
GROUP BY s.id, s.name, tt.name, t.name

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count,
    1 AS sort_order
FROM statistic_participants{{SHARD_ID}} sp
JOIN statistic s ON s.id = sp.statisticFK AND s.del = 'no'
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE sp.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
  AND EXISTS (
      SELECT 1 FROM object_discipline od
      WHERE od.object_typeFK = 83 AND od.objectFK = s.id
        AND od.disciplineFK IN ({{TIMED_DISCIPLINE_LIST}}) AND od.del = 'no'
  )

ORDER BY sort_order, violating_record_count DESC;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-051
    -- Name - COMP.RANK_NAME_FORMAT_INVALID
    -- What it does: Finds each distinct active tournament-owned statistic name that breaks at least one text-hygiene rule - edge or doubled spacing, a control or non-ASCII character, a hyphen without surrounding spaces, a year glued to a word, or a capitalisation shape a proof-read name does not take - naming every rule the name breaks and how many objects carry it, reporting one row per offending name rather than one per object repeating it, together with a coverage count of all distinct eligible names.
    'Name_Format_Invalid' AS check_type,
    MIN(x.object_name) AS statistic_name,
    x.violation_types,
    COUNT(DISTINCT x.object_id) AS affected_object_count,
    MIN(x.object_id) AS sample_object_id,
    MIN(x.template_name) AS template_name,
    MIN(x.tournament_name) AS sample_tournament_name,
    NULL AS eligible_count,
    0 AS sort_order
FROM (
    SELECT
        s.id AS object_id,
        s.name AS object_name,
        -- The grouping key is binary: under the column's case-insensitive collation two
        -- spellings that differ only in case would collapse into one group, which is the
        -- distinction GLOBAL-DQ-050 exists to report.
        (CONVERT(s.name USING utf8mb4) COLLATE utf8mb4_bin) AS name_bin,
        tt.name AS template_name,
        t.name AS tournament_name,
        CONCAT_WS(', ',
            IF(CHAR_LENGTH(s.name) <> CHAR_LENGTH(TRIM(s.name)), 'LEADING_OR_TRAILING_SPACE', NULL),
            IF(s.name LIKE '%  %', 'DOUBLE_SPACE', NULL),
            IF(s.name REGEXP '[[:cntrl:]]', 'CONTROL_CHARACTER', NULL),
            IF(LENGTH(s.name) <> CHAR_LENGTH(s.name), 'NON_ASCII_CHARACTER', NULL),
            IF(s.name REGEXP '[^ ]-|-[^ ]', 'HYPHEN_WITHOUT_SPACES', NULL),
            IF((CONVERT(s.name USING utf8mb4) COLLATE utf8mb4_bin) REGEXP '[A-Za-z][12][0-9][0-9][0-9]|[12][0-9][0-9][0-9][A-Za-z]', 'YEAR_GLUED_TO_WORD', NULL),
            IF((CONVERT(s.name USING utf8mb4) COLLATE utf8mb4_bin) REGEXP '[A-Z][A-Z][a-z]', 'DOUBLE_CAPITAL', NULL),
            IF((CONVERT(s.name USING utf8mb4) COLLATE utf8mb4_bin) REGEXP '[A-Za-z]'
               AND (CONVERT(s.name USING utf8mb4) COLLATE utf8mb4_bin) NOT REGEXP '[a-z]', 'ALL_UPPERCASE', NULL),
            IF((CONVERT(s.name USING utf8mb4) COLLATE utf8mb4_bin) REGEXP '^[a-z]', 'STARTS_LOWERCASE', NULL)
        ) AS violation_types
    FROM statistic s
    JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    WHERE s.del = 'no'
      AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
      AND s.object_typeFK = 3
      AND tt.sportFK = {{SPORT_ID}}
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      AND s.name IS NOT NULL
      AND TRIM(s.name) <> ''
      -- AND tt.id = <tournament_template_id>
) x
WHERE x.violation_types <> ''
GROUP BY x.name_bin, x.violation_types

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT (CONVERT(s.name USING utf8mb4) COLLATE utf8mb4_bin)) AS eligible_count,
    1 AS sort_order
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND s.name IS NOT NULL
  AND TRIM(s.name) <> ''
  -- AND tt.id = <tournament_template_id>

ORDER BY sort_order, violation_types, statistic_name;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-057
    -- Name - COMP.RANK_RESULTS_COMMENT_INVALID_OR_CONTRADICTED
    -- What it does: Finds active statistic-participant rows of the selected statistic type, excluding IOC-purpose templates, whose Comment data value is outside the sport's confirmed set of status codes, or whose Comment marks a participant as having no classified result while a Rank, a Time or a Medal is stored for that same participant, together with a coverage count of all eligible statistic-participant rows carrying an active, non-empty Comment value.
    CASE
        WHEN LOWER(TRIM(x.comment_value)) IN ({{DATA_COMMENT_NO_RESULT_LIST}}) AND x.medal_value IS NOT NULL THEN 'COMMENT_NO_RESULT_WITH_MEDAL'
        WHEN LOWER(TRIM(x.comment_value)) IN ({{DATA_COMMENT_NO_RESULT_LIST}}) AND x.rank_value IS NOT NULL THEN 'COMMENT_NO_RESULT_WITH_RANK'
        WHEN LOWER(TRIM(x.comment_value)) IN ({{DATA_COMMENT_NO_RESULT_LIST}}) AND x.time_value IS NOT NULL THEN 'COMMENT_NO_RESULT_WITH_TIME'
        ELSE 'COMMENT_INVALID_VALUE'
    END AS check_type,
    x.statistic_id,
    x.statistic_name,
    x.template_name,
    x.tournament_name,
    x.participant_name,
    x.comment_value,
    x.rank_value,
    x.time_value,
    x.medal_value,
    NULL AS eligible_count
FROM (
    SELECT
        s.id AS statistic_id,
        s.name AS statistic_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        p.name AS participant_name,
        sd.value AS comment_value,
        (SELECT NULLIF(TRIM(sd2.value), '') FROM statistic_data{{SHARD_ID}} sd2
          WHERE sd2.statistic_participants{{SHARD_ID}}FK = sp.id
            AND sd2.statistic_data_typeFK = {{DATA_RANK_TYPE_ID}}
            AND sd2.del = 'no' AND sd2.value IS NOT NULL LIMIT 1) AS rank_value,
        (SELECT NULLIF(TRIM(sd3.value), '') FROM statistic_data{{SHARD_ID}} sd3
          WHERE sd3.statistic_participants{{SHARD_ID}}FK = sp.id
            AND sd3.statistic_data_typeFK = {{DATA_TIME_TYPE_ID}}
            AND sd3.del = 'no' AND sd3.value IS NOT NULL LIMIT 1) AS time_value,
        (SELECT NULLIF(TRIM(sd4.value), '') FROM statistic_data{{SHARD_ID}} sd4
          WHERE sd4.statistic_participants{{SHARD_ID}}FK = sp.id
            AND sd4.statistic_data_typeFK = {{DATA_MEDAL_TYPE_ID}}
            AND sd4.del = 'no' AND sd4.value IS NOT NULL LIMIT 1) AS medal_value
    FROM statistic_data{{SHARD_ID}} sd
    JOIN statistic_participants{{SHARD_ID}} sp ON sp.id = sd.statistic_participants{{SHARD_ID}}FK AND sp.del = 'no'
    JOIN statistic s ON s.id = sp.statisticFK AND s.del = 'no'
    JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN participant p ON p.id = sp.participantFK AND p.del = 'no'
    WHERE sd.del = 'no'
      AND sd.statistic_data_typeFK = {{DATA_COMMENT_TYPE_ID}}
      AND sd.value IS NOT NULL
      AND TRIM(sd.value) <> ''
      AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
      AND s.object_typeFK = 3
      AND tt.sportFK = {{SPORT_ID}}
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      -- AND tt.id = <tournament_template_id>
) x
WHERE LOWER(TRIM(x.comment_value)) NOT IN ({{DATA_COMMENT_VALUE_LIST}})
   OR (
        LOWER(TRIM(x.comment_value)) IN ({{DATA_COMMENT_NO_RESULT_LIST}})
        AND (x.rank_value IS NOT NULL OR x.time_value IS NOT NULL OR x.medal_value IS NOT NULL)
      )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT sp.id) AS eligible_count
FROM statistic_data{{SHARD_ID}} sd
JOIN statistic_participants{{SHARD_ID}} sp ON sp.id = sd.statistic_participants{{SHARD_ID}}FK AND sp.del = 'no'
JOIN statistic s ON s.id = sp.statisticFK AND s.del = 'no'
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE sd.del = 'no'
  AND sd.statistic_data_typeFK = {{DATA_COMMENT_TYPE_ID}}
  AND sd.value IS NOT NULL
  AND TRIM(sd.value) <> ''
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
;
