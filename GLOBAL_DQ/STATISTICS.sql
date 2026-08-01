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
    -- What it does: Finds active tournament-owned statistics of the selected statistic type holding at least one participant whose Rank data value is non-numeric or not a positive integer, or whose Rank is missing or empty while no active Comment value explains it, with template and tournament name context and the count of affected participant rows, together with a coverage count of all eligible statistics.
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
      -- A Rank that is absent or empty is explained by a Comment naming the status the
      -- participant finished under, which is how a sport records a non-finisher; the
      -- event layer already reads it that way in GLOBAL-DQ-036. An invalid value is
      -- explained by nothing, so it is reported whether a Comment exists or not.
      (
          (sd.id IS NULL OR sd.value IS NULL OR TRIM(sd.value) = '')
          AND NOT EXISTS (
              SELECT 1
              FROM statistic_data{{SHARD_ID}} cm
              WHERE cm.statistic_participants{{SHARD_ID}}FK = sp.id
                AND cm.statistic_data_typeFK = {{DATA_COMMENT_TYPE_ID}}
                AND cm.del = 'no'
                AND cm.value IS NOT NULL
                AND TRIM(cm.value) <> ''
          )
      )
      OR (
          sd.value IS NOT NULL
          AND TRIM(sd.value) <> ''
          AND TRIM(sd.value) NOT REGEXP '^[1-9][0-9]*$'
      )
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
    -- Name - COMP.RANK_SETTINGS_MEDAL_SET_INVALID
    -- What it does: Finds active tournament-owned statistics of the selected statistic type whose set of Medal values is not one gold, one silver and one bronze, because a medal type is absent among statistic participants, is held by more participants than a place is held by in that statistic, or is held by fewer, counting the holders of each medal per team wherever the statistic assigns athletes to one through the Team data field and reading the number of holders a place takes from what the medals present agree on, so a relay whose members each carry their team's medal is not read as a duplicate whether or not the team assignment exists, separating a statistic with no medals at all, a duplicate contradicted by the place below it, a duplicate shaped like a tie, a duplicated bronze, a medal held by fewer participants than its place takes and a missing medal type, together with a coverage count of all eligible statistics.
    CASE
        WHEN x.total_medal_count = 0 THEN 'No_Medals_At_All'
        -- A shared place removes the place below it, so a second gold beside a silver is a
        -- contradiction, while a second gold without one is the shape a tie actually takes.
        WHEN x.gold_count > x.medal_holder_norm AND x.silver_count > 0 THEN 'Duplicate_Gold_With_Silver_Present'
        WHEN x.silver_count > x.medal_holder_norm AND x.bronze_count > 0 THEN 'Duplicate_Silver_With_Bronze_Present'
        WHEN x.gold_count > x.medal_holder_norm OR x.silver_count > x.medal_holder_norm THEN 'Duplicate_Medal_Tie_Shape'
        WHEN x.bronze_count > x.medal_holder_norm THEN 'Duplicate_Bronze'
        -- A medal held by fewer than the norm is a team whose medal row is missing for one
        -- of its members, which is the opposite defect and needs the opposite repair.
        WHEN (x.gold_count > 0 AND x.gold_count < x.medal_holder_norm)
          OR (x.silver_count > 0 AND x.silver_count < x.medal_holder_norm)
          OR (x.bronze_count > 0 AND x.bronze_count < x.medal_holder_norm) THEN 'Medal_Holder_Shortfall'
        ELSE 'Missing_Specific_Medal'
    END AS check_type,
    x.statistic_id,
    x.statistic_name,
    x.template_name,
    x.tournament_name,
    CONCAT_WS(', ',
        IF(x.gold_count = 0, 'gold', NULL),
        IF(x.silver_count = 0, 'silver', NULL),
        IF(x.bronze_count = 0, 'bronze', NULL)
    ) AS missing_medals,
    CONCAT_WS(', ',
        IF(x.gold_count > x.medal_holder_norm, CONCAT('gold x', x.gold_count), NULL),
        IF(x.silver_count > x.medal_holder_norm, CONCAT('silver x', x.silver_count), NULL),
        IF(x.bronze_count > x.medal_holder_norm, CONCAT('bronze x', x.bronze_count), NULL)
    ) AS duplicated_medals,
    CONCAT('gold=', x.gold_count, ' silver=', x.silver_count,
           ' bronze=', x.bronze_count, ' holders_per_place=', x.medal_holder_norm) AS medal_holder_counts,
    NULL AS eligible_count
FROM (
    SELECT
        y.*,
        -- Second guard, for the relay whose athletes carry no team at all. One place is
        -- held by one competitor, unless the statistic lists a relay athlete by athlete,
        -- where every medalled place is held by a whole team of the same size. The norm is
        -- therefore what the medals present agree on: the count two of them share, or the
        -- smallest where no two agree, which is one wherever places are held singly. A
        -- medal above the norm is duplicated, one below it is a team missing a row.
        -- GLOBAL-DQ-064 does not cover the statistic this exists for: its population is the
        -- statistic that uses the Team field at all, and this one does not use it.
        CASE
            WHEN y.gold_count > 0 AND y.gold_count = y.silver_count THEN y.gold_count
            WHEN y.gold_count > 0 AND y.gold_count = y.bronze_count THEN y.gold_count
            WHEN y.silver_count > 0 AND y.silver_count = y.bronze_count THEN y.silver_count
            ELSE LEAST(
                IF(y.gold_count = 0, 999999, y.gold_count),
                IF(y.silver_count = 0, 999999, y.silver_count),
                IF(y.bronze_count = 0, 999999, y.bronze_count)
            )
        END AS medal_holder_norm
    FROM (
    SELECT
        s.id AS statistic_id,
        s.name AS statistic_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        -- A place is held by one competitor, and in a relay that competitor is the team.
        -- Counting medal rows instead would read every member of a winning relay as a
        -- duplicate gold, so each medal is counted over distinct teams where the statistic
        -- assigns one, and over distinct participants where it does not.
        COUNT(DISTINCT CASE WHEN LOWER(TRIM(sd.value)) = 'gold'
             THEN COALESCE(TRIM(tmd.value), CONCAT('p', sp.id)) END) AS gold_count,
        COUNT(DISTINCT CASE WHEN LOWER(TRIM(sd.value)) = 'silver'
             THEN COALESCE(TRIM(tmd.value), CONCAT('p', sp.id)) END) AS silver_count,
        COUNT(DISTINCT CASE WHEN LOWER(TRIM(sd.value)) = 'bronze'
             THEN COALESCE(TRIM(tmd.value), CONCAT('p', sp.id)) END) AS bronze_count,
        SUM(CASE WHEN sd.value IS NOT NULL AND TRIM(sd.value) <> '' THEN 1 ELSE 0 END) AS total_medal_count
    FROM statistic s
    JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = s.id AND sp.del = 'no'
    LEFT JOIN statistic_data{{SHARD_ID}} sd
      ON sd.statistic_participants{{SHARD_ID}}FK = sp.id
     AND sd.del = 'no'
     AND sd.statistic_data_typeFK = {{DATA_MEDAL_TYPE_ID}}
    LEFT JOIN statistic_data{{SHARD_ID}} tmd
      ON tmd.statistic_participants{{SHARD_ID}}FK = sp.id
     AND tmd.del = 'no'
     AND tmd.statistic_data_typeFK = {{DATA_TEAM_TYPE_ID}}
     AND tmd.value IS NOT NULL
     AND TRIM(tmd.value) <> ''
    WHERE s.del = 'no'
      AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
      AND s.object_typeFK = 3
      AND tt.sportFK = {{SPORT_ID}}
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      -- AND tt.id = <tournament_template_id>
    GROUP BY s.id, s.name, tt.name, t.name
    ) y
) x
WHERE x.gold_count <> x.medal_holder_norm
   OR x.silver_count <> x.medal_holder_norm
   OR x.bronze_count <> x.medal_holder_norm

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
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
    -- What it does: Finds active tournament-owned statistics of the selected statistic type missing name, an active non-empty Gender config value, an active country relation (object_relation 83->33), or an active city relation (city_object owner type=83), or carrying a country relation that resolves only to a placeholder row and therefore reads as populated, with template and tournament name context, together with a coverage count of all eligible statistics.
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
        -- A country that resolves to a placeholder row reads as populated to every
        -- IS NULL test, so it is named separately rather than counted as clean.
        IF(EXISTS (
            SELECT 1 FROM object_relation orl
            JOIN country c ON c.id = orl.rel_objectFK AND c.del = 'no'
            WHERE orl.object_typeFK = 83
              AND orl.objectFK = s.id
              AND orl.rel_object_typeFK = 33
              AND orl.del = 'no'
              AND c.name IN ({{PLACEHOLDER_COUNTRY_LIST}})
        ), 'country_placeholder', NULL),
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
      OR EXISTS (
          SELECT 1 FROM object_relation orl
          JOIN country c ON c.id = orl.rel_objectFK AND c.del = 'no'
          WHERE orl.object_typeFK = 83
            AND orl.objectFK = s.id
            AND orl.rel_object_typeFK = 33
            AND orl.del = 'no'
            AND c.name IN ({{PLACEHOLDER_COUNTRY_LIST}})
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
    -- What it does: Finds active tournament-owned statistics of the selected statistic type restricted to the sport's timed disciplines, containing at least one participant whose time storage is inconsistent with their Rank: Time missing despite an active rank, Time Difference missing despite an active rank other than the leader's, either present without an active rank, or Time present with an invalid format or as a zero time, together with the distinct violation types and count of mismatching participants per statistic and a coverage count of all eligible statistics in those disciplines.
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
        IF(MAX(x.f_time_invalid) = 1, 'TIME_INVALID_FORMAT', NULL),
        IF(MAX(x.f_time_non_positive) = 1, 'TIME_NON_POSITIVE', NULL)
    ) AS violation_types,
    NULL AS eligible_count,
    0 AS sort_order
FROM (
    SELECT
        sp.id AS statistic_participants_id,
        sp.statisticFK AS statistic_id,
        (COUNT(DISTINCT rk.id) > 0 AND COUNT(DISTINCT tm.id) = 0) AS f_rank_time_missing,
        -- The leader carries no gap to anybody, so rank 1 owes no Time Difference. Asserting
        -- it there reports every winner in the sport rather than a defect.
        (COUNT(DISTINCT rk.id) > 0 AND MAX(TRIM(rk.value)) <> '1'
             AND COUNT(DISTINCT td.id) = 0) AS f_rank_td_missing,
        (COUNT(DISTINCT rk.id) = 0 AND COUNT(DISTINCT tm.id) > 0) AS f_time_no_rank,
        (COUNT(DISTINCT rk.id) = 0 AND COUNT(DISTINCT td.id) > 0) AS f_td_no_rank,
        (COUNT(DISTINCT rk.id) > 0 AND COUNT(DISTINCT tm.id) > 0
             AND MAX(tm.value) NOT REGEXP '^[0-9]+(:[0-9]+)*(\\.[0-9]+)?$') AS f_time_invalid,
        -- A value that passes the shape test but holds no non-zero digit is a zero time:
        -- '0', '0:00' and '00:00.00' all read as valid until this is asked separately.
        (COUNT(DISTINCT rk.id) > 0 AND COUNT(DISTINCT tm.id) > 0
             AND MAX(tm.value) REGEXP '^[0-9]+(:[0-9]+)*(\\.[0-9]+)?$'
             AND MAX(tm.value) NOT REGEXP '[1-9]') AS f_time_non_positive
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
    HAVING f_rank_time_missing OR f_rank_td_missing OR f_time_no_rank OR f_td_no_rank
        OR f_time_invalid OR f_time_non_positive
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
    -- What it does: Finds each distinct active tournament-owned statistic name that breaks at least one text-hygiene rule - edge or doubled spacing, a control character, a definite text corruption such as an HTML entity, a replacement character, a non-breaking or zero-width space or a double-encoded byte sequence, a non-ASCII character, a hyphen without surrounding spaces, a year glued to a word, a capitalisation shape a proof-read name does not take, a placeholder name or a numeric-only name - naming every rule the name breaks and how many objects carry it, reporting one row per offending name rather than one per object repeating it, together with a coverage count of all distinct eligible names.
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
            -- The five rules below name a definite corruption. NON_ASCII_CHARACTER
            -- that follows cannot: it fires on a legitimate diacritic just as readily,
            -- so a corrupted name is reported under its own verdict as well.
            IF(s.name LIKE '%&#%' OR LOWER(s.name) REGEXP '&(amp|quot|apos|lt|gt|nbsp);', 'HTML_ENTITY', NULL),
            IF(HEX(s.name) LIKE '%EFBFBD%', 'REPLACEMENT_CHARACTER', NULL),
            IF(HEX(s.name) LIKE '%C2A0%', 'NON_BREAKING_SPACE', NULL),
            IF(HEX(s.name) LIKE '%E2808B%', 'ZERO_WIDTH_SPACE', NULL),
            IF(HEX(s.name) LIKE '%C383%' OR HEX(s.name) LIKE '%C382%', 'MOJIBAKE_DOUBLE_ENCODED', NULL),
            IF(LENGTH(s.name) <> CHAR_LENGTH(s.name), 'NON_ASCII_CHARACTER', NULL),
            IF(s.name REGEXP '[^ ]-|-[^ ]', 'HYPHEN_WITHOUT_SPACES', NULL),
            IF((CONVERT(s.name USING utf8mb4) COLLATE utf8mb4_bin) REGEXP '[A-Za-z][12][0-9][0-9][0-9]|[12][0-9][0-9][0-9][A-Za-z]', 'YEAR_GLUED_TO_WORD', NULL),
            IF((CONVERT(s.name USING utf8mb4) COLLATE utf8mb4_bin) REGEXP '[A-Z][A-Z][a-z]', 'DOUBLE_CAPITAL', NULL),
            IF((CONVERT(s.name USING utf8mb4) COLLATE utf8mb4_bin) REGEXP '[A-Za-z]'
               AND (CONVERT(s.name USING utf8mb4) COLLATE utf8mb4_bin) NOT REGEXP '[a-z]', 'ALL_UPPERCASE', NULL),
            IF((CONVERT(s.name USING utf8mb4) COLLATE utf8mb4_bin) REGEXP '^[a-z]', 'STARTS_LOWERCASE', NULL),
            IF(LOWER(TRIM(s.name)) IN ('test','testing','temp','tmp','xxx','asd','qwe','tbd','tba','n/a','undefined','event','new event'), 'PLACEHOLDER_NAME', NULL),
            IF(TRIM(s.name) REGEXP '^[0-9]+$', 'NUMERIC_ONLY_NAME', NULL)
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


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-060
    -- Name - COMP.RANK_RESULTS_DUPLICATE_ROWS
    -- What it does: Finds active tournament-owned statistics of the selected statistic type, excluding IOC-purpose templates, holding more than one active data row for the same statistic participant and data type, separating a duplicate repeating the same value from one storing conflicting values, with template and tournament name context, the number of affected participants and a sample group, together with a coverage count of all eligible statistics holding at least one active data row.
    'Comp_Rank_Duplicate_Rows' AS check_type,
    d.statistic_id,
    d.statistic_name,
    d.template_name,
    d.tournament_name,
    CASE WHEN SUM(d.distinct_values > 1) > 0 THEN 'CONFLICTING_VALUES' ELSE 'DUPLICATE_IDENTICAL' END AS duplicate_kind,
    COUNT(*) AS duplicated_group_count,
    COUNT(DISTINCT d.statistic_participants_id) AS affected_participant_count,
    SUM(d.row_count) AS duplicated_row_count,
    MIN(CONCAT('sp=', d.statistic_participants_id, ' type=', d.statistic_data_typeFK, ' values=', d.value_list)) AS sample_group,
    NULL AS eligible_count
FROM (
    SELECT
        st.id AS statistic_id,
        st.name AS statistic_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        sp.id AS statistic_participants_id,
        sd.statistic_data_typeFK,
        COUNT(*) AS row_count,
        COUNT(DISTINCT TRIM(sd.value)) AS distinct_values,
        SUBSTRING(GROUP_CONCAT(DISTINCT TRIM(sd.value) ORDER BY TRIM(sd.value) SEPARATOR '|'), 1, 100) AS value_list
    FROM statistic_data{{SHARD_ID}} sd
    JOIN statistic_participants{{SHARD_ID}} sp
      ON sp.id = sd.statistic_participants{{SHARD_ID}}FK AND sp.del = 'no'
    JOIN statistic st
      ON st.id = sp.statisticFK AND st.del = 'no'
     AND st.object_typeFK = 3
     AND st.statistic_typeFK = {{STATISTIC_TYPE_ID}}
    JOIN tournament t ON t.id = st.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    WHERE sd.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      -- AND tt.id = <tournament_template_id>
    GROUP BY st.id, st.name, tt.name, t.name, sp.id, sd.statistic_data_typeFK
    HAVING COUNT(*) > 1
) d
GROUP BY d.statistic_id, d.statistic_name, d.template_name, d.tournament_name

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT st.id) AS eligible_count
FROM statistic_data{{SHARD_ID}} sd
JOIN statistic_participants{{SHARD_ID}} sp
  ON sp.id = sd.statistic_participants{{SHARD_ID}}FK AND sp.del = 'no'
JOIN statistic st
  ON st.id = sp.statisticFK AND st.del = 'no'
 AND st.object_typeFK = 3
 AND st.statistic_typeFK = {{STATISTIC_TYPE_ID}}
JOIN tournament t ON t.id = st.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE sd.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-064
    -- Name - COMP.RANK_ATHLETE_TEAM_MISSING_OR_INVALID
    -- What it does: Finds active athlete statistic-participant rows of the selected statistic type, excluding IOC-purpose templates, inside a statistic that uses the Team data field, whose own Team value is absent, does not resolve to an active team participant, is stored more than once with conflicting values, or is stored more than once repeating one value, separating the four cases, with statistic, template and tournament name context, together with a coverage count of all eligible athlete statistic-participant rows inside statistics that use the Team data field.
    CASE
        WHEN x.team_value IS NULL   THEN 'TEAM_VALUE_MISSING'
        WHEN tp.id IS NULL          THEN 'TEAM_VALUE_UNRESOLVED'
        WHEN x.team_value_count > 1 THEN 'TEAM_VALUE_CONFLICTING'
        ELSE                             'TEAM_VALUE_DUPLICATED'
    END AS check_type,
    x.statistic_participants_id,
    x.statistic_id,
    x.statistic_name,
    x.template_name,
    x.tournament_name,
    x.participant_id,
    x.participant_name,
    x.team_value,
    x.team_row_count,
    NULL AS eligible_count
FROM (
    SELECT
        sp.id AS statistic_participants_id,
        -- Grouped by the participant id alone, with the context columns taken through MIN
        -- because each participant has exactly one of each. Naming them in the GROUP BY
        -- instead makes the key three strings wide and the statement took 102 seconds
        -- rather than four: same rows, same values, a temporary table nobody needs.
        MIN(s.id) AS statistic_id,
        MIN(s.name) AS statistic_name,
        MIN(tt.name) AS template_name,
        MIN(t.name) AS tournament_name,
        MIN(p.id) AS participant_id,
        MIN(p.name) AS participant_name,
        -- The three facts about a participant's Team rows, read in the one pass that
        -- already visits them. Asked as three correlated subqueries instead, this scanned
        -- the data shard once per athlete and timed the statement out on a sport holding a
        -- hundred thousand of them. The LEFT JOIN is what keeps a participant with no Team
        -- row at all: that is the TEAM_VALUE_MISSING case, not a row to drop.
        MIN(TRIM(td.value)) AS team_value,
        COUNT(td.id) AS team_row_count,
        COUNT(DISTINCT TRIM(td.value)) AS team_value_count
    FROM statistic s
    JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = s.id AND sp.del = 'no'
    JOIN participant p ON p.id = sp.participantFK AND p.del = 'no'
    -- The eligible population: a statistic that uses the Team data field at all. Asked as a
    -- correlated EXISTS this was re-evaluated for every athlete row in the sport; resolved
    -- once here, it is one pass the athlete rows then join against.
    JOIN (
        SELECT sp3.statisticFK AS statistic_id
        FROM statistic_participants{{SHARD_ID}} sp3
        JOIN statistic s3 ON s3.id = sp3.statisticFK AND s3.del = 'no'
         AND s3.statistic_typeFK = {{STATISTIC_TYPE_ID}}
         AND s3.object_typeFK = 3
        JOIN tournament t3 ON t3.id = s3.objectFK AND t3.del = 'no'
        JOIN tournament_template tt3 ON tt3.id = t3.tournament_templateFK AND tt3.del = 'no'
         AND tt3.sportFK = {{SPORT_ID}}
         AND (tt3.name IS NULL OR tt3.name NOT LIKE '%(IOC)%')
        JOIN statistic_data{{SHARD_ID}} td3
          ON td3.statistic_participants{{SHARD_ID}}FK = sp3.id
         AND td3.statistic_data_typeFK = {{DATA_TEAM_TYPE_ID}}
         AND td3.del = 'no'
         AND td3.value IS NOT NULL
         AND TRIM(td3.value) <> ''
        WHERE sp3.del = 'no'
        GROUP BY sp3.statisticFK
    ) uses ON uses.statistic_id = s.id
    LEFT JOIN statistic_data{{SHARD_ID}} td
      ON td.statistic_participants{{SHARD_ID}}FK = sp.id
     AND td.statistic_data_typeFK = {{DATA_TEAM_TYPE_ID}}
     AND td.del = 'no'
     AND td.value IS NOT NULL
     AND TRIM(td.value) <> ''
    WHERE s.del = 'no'
      AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
      AND s.object_typeFK = 3
      AND tt.sportFK = {{SPORT_ID}}
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      AND p.type = 'athlete'
      -- AND tt.id = <tournament_template_id>
    GROUP BY sp.id
) x
LEFT JOIN participant tp
       ON x.team_value REGEXP '^[0-9]+$'
      AND tp.id = CAST(x.team_value AS UNSIGNED)
      AND tp.del = 'no'
      AND tp.type = 'team'
WHERE x.team_value IS NULL
   OR tp.id IS NULL
   OR x.team_row_count > 1

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    -- The block above already is the eligible population, one row per athlete inside a
    -- statistic that uses the Team field, so the coverage counts that rather than rebuilding
    -- the joins beside it. Rebuilt, the count took 102 seconds against the finding block's
    -- four, and the contract asks for the identical scope in any case.
    COUNT(DISTINCT y.statistic_participants_id) AS eligible_count
FROM (
    SELECT
        sp.id AS statistic_participants_id,
        -- Grouped by the participant id alone, with the context columns taken through MIN
        -- because each participant has exactly one of each. Naming them in the GROUP BY
        -- instead makes the key three strings wide and the statement took 102 seconds
        -- rather than four: same rows, same values, a temporary table nobody needs.
        MIN(s.id) AS statistic_id,
        MIN(s.name) AS statistic_name,
        MIN(tt.name) AS template_name,
        MIN(t.name) AS tournament_name,
        MIN(p.id) AS participant_id,
        MIN(p.name) AS participant_name,
        -- The three facts about a participant's Team rows, read in the one pass that
        -- already visits them. Asked as three correlated subqueries instead, this scanned
        -- the data shard once per athlete and timed the statement out on a sport holding a
        -- hundred thousand of them. The LEFT JOIN is what keeps a participant with no Team
        -- row at all: that is the TEAM_VALUE_MISSING case, not a row to drop.
        MIN(TRIM(td.value)) AS team_value,
        COUNT(td.id) AS team_row_count,
        COUNT(DISTINCT TRIM(td.value)) AS team_value_count
    FROM statistic s
    JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = s.id AND sp.del = 'no'
    JOIN participant p ON p.id = sp.participantFK AND p.del = 'no'
    -- The eligible population: a statistic that uses the Team data field at all. Asked as a
    -- correlated EXISTS this was re-evaluated for every athlete row in the sport; resolved
    -- once here, it is one pass the athlete rows then join against.
    JOIN (
        SELECT sp3.statisticFK AS statistic_id
        FROM statistic_participants{{SHARD_ID}} sp3
        JOIN statistic s3 ON s3.id = sp3.statisticFK AND s3.del = 'no'
         AND s3.statistic_typeFK = {{STATISTIC_TYPE_ID}}
         AND s3.object_typeFK = 3
        JOIN tournament t3 ON t3.id = s3.objectFK AND t3.del = 'no'
        JOIN tournament_template tt3 ON tt3.id = t3.tournament_templateFK AND tt3.del = 'no'
         AND tt3.sportFK = {{SPORT_ID}}
         AND (tt3.name IS NULL OR tt3.name NOT LIKE '%(IOC)%')
        JOIN statistic_data{{SHARD_ID}} td3
          ON td3.statistic_participants{{SHARD_ID}}FK = sp3.id
         AND td3.statistic_data_typeFK = {{DATA_TEAM_TYPE_ID}}
         AND td3.del = 'no'
         AND td3.value IS NOT NULL
         AND TRIM(td3.value) <> ''
        WHERE sp3.del = 'no'
        GROUP BY sp3.statisticFK
    ) uses ON uses.statistic_id = s.id
    LEFT JOIN statistic_data{{SHARD_ID}} td
      ON td.statistic_participants{{SHARD_ID}}FK = sp.id
     AND td.statistic_data_typeFK = {{DATA_TEAM_TYPE_ID}}
     AND td.del = 'no'
     AND td.value IS NOT NULL
     AND TRIM(td.value) <> ''
    WHERE s.del = 'no'
      AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
      AND s.object_typeFK = 3
      AND tt.sportFK = {{SPORT_ID}}
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      AND p.type = 'athlete'
      -- AND tt.id = <tournament_template_id>
    GROUP BY sp.id
) y
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-065
    -- Name - COMP.RANK_TEAM_ATHLETE_COUNT_UNEVEN
    -- What it does: Finds active tournament-owned statistics of the selected statistic type, excluding IOC-purpose templates, whose athletes are assigned to teams through the Team data field in unequal numbers, so one team fields fewer athletes than another inside one statistic, separating a shortfall of one athlete from a larger one, with the team by team breakdown and template and tournament name context, together with a coverage count of all eligible statistics holding at least one athlete assigned to a resolvable team.
    CASE
        WHEN a.max_athletes_per_team - a.min_athletes_per_team = 1 THEN 'TEAM_SIZE_UNEVEN_BY_ONE'
        ELSE 'TEAM_SIZE_UNEVEN_BY_MORE'
    END AS check_type,
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
    NULL AS eligible_count
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
        JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = s.id AND sp.del = 'no'
        JOIN participant p ON p.id = sp.participantFK AND p.del = 'no' AND p.type = 'athlete'
        JOIN statistic_data{{SHARD_ID}} td
          ON td.statistic_participants{{SHARD_ID}}FK = sp.id
         AND td.statistic_data_typeFK = {{DATA_TEAM_TYPE_ID}}
         AND td.del = 'no'
         AND td.value REGEXP '^[0-9]+$'
        JOIN participant tp ON tp.id = CAST(TRIM(td.value) AS UNSIGNED) AND tp.del = 'no' AND tp.type = 'team'
        WHERE s.del = 'no'
          AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
          AND s.object_typeFK = 3
          AND tt.sportFK = {{SPORT_ID}}
          AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
          -- AND tt.id = <tournament_template_id>
        GROUP BY s.id, s.name, tt.name, t.name, tp.id, tp.name
    ) g
    GROUP BY g.statistic_id, g.statistic_name, g.template_name, g.tournament_name
) a
WHERE a.min_athletes_per_team <> a.max_athletes_per_team

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = s.id AND sp.del = 'no'
JOIN participant p ON p.id = sp.participantFK AND p.del = 'no' AND p.type = 'athlete'
JOIN statistic_data{{SHARD_ID}} td
  ON td.statistic_participants{{SHARD_ID}}FK = sp.id
 AND td.statistic_data_typeFK = {{DATA_TEAM_TYPE_ID}}
 AND td.del = 'no'
 AND td.value REGEXP '^[0-9]+$'
JOIN participant tp ON tp.id = CAST(TRIM(td.value) AS UNSIGNED) AND tp.del = 'no' AND tp.type = 'team'
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-066
    -- Name - COMP.RANK_TEAM_GENDER_BALANCE_UNEVEN
    -- What it does: Finds active tournament-owned statistics of the selected statistic type whose Gender config value is mixed, excluding IOC-purpose templates, holding at least one team whose athletes assigned through the Team data field are not an equal number of male and female, separating a team fielding one gender only from one fielding both in unequal numbers, with the offending teams and their gender counts and template and tournament name context, together with a coverage count of all eligible mixed statistics holding at least one athlete assigned to a resolvable team.
    CASE
        WHEN a.teams_missing_a_gender > 0 THEN 'STATISTIC_TEAM_MISSING_A_GENDER'
        ELSE 'STATISTIC_TEAM_GENDER_COUNT_UNEVEN'
    END AS check_type,
    a.statistic_id,
    a.statistic_name,
    a.template_name,
    a.tournament_name,
    a.statistic_gender,
    a.team_count,
    a.teams_with_uneven_gender,
    a.teams_missing_a_gender,
    a.athletes_with_unusable_gender,
    a.uneven_team_breakdown,
    NULL AS eligible_count
FROM (
    SELECT
        g.statistic_id,
        g.statistic_name,
        g.template_name,
        g.tournament_name,
        g.statistic_gender,
        COUNT(*) AS team_count,
        SUM(g.male_cnt <> g.female_cnt) AS teams_with_uneven_gender,
        SUM(g.male_cnt = 0 OR g.female_cnt = 0) AS teams_missing_a_gender,
        SUM(g.other_cnt) AS athletes_with_unusable_gender,
        GROUP_CONCAT(CASE WHEN g.male_cnt <> g.female_cnt
                          THEN CONCAT(g.team_participant_name, '=M', g.male_cnt, '/F', g.female_cnt)
                     END
                     ORDER BY ABS(g.male_cnt - g.female_cnt) DESC, g.team_participant_name
                     SEPARATOR ', ') AS uneven_team_breakdown
    FROM (
        SELECT
            s.id AS statistic_id,
            s.name AS statistic_name,
            tt.name AS template_name,
            t.name AS tournament_name,
            LOWER(TRIM(sg.value)) AS statistic_gender,
            tp.id AS team_participant_id,
            tp.name AS team_participant_name,
            COUNT(DISTINCT CASE WHEN LOWER(TRIM(p.gender)) = 'male' THEN sp.id END) AS male_cnt,
            COUNT(DISTINCT CASE WHEN LOWER(TRIM(p.gender)) = 'female' THEN sp.id END) AS female_cnt,
            COUNT(DISTINCT CASE WHEN p.gender IS NULL
                                  OR LOWER(TRIM(p.gender)) NOT IN ('male', 'female') THEN sp.id END) AS other_cnt
        FROM statistic s
        JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
        JOIN statistic_config sg ON sg.statisticFK = s.id AND sg.del = 'no'
             AND sg.statistic_data_typeFK = {{CONFIG_GENDER_TYPE_ID}}
             AND LOWER(TRIM(sg.value)) = 'mixed'
        JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = s.id AND sp.del = 'no'
        JOIN participant p ON p.id = sp.participantFK AND p.del = 'no' AND p.type = 'athlete'
        JOIN statistic_data{{SHARD_ID}} td
          ON td.statistic_participants{{SHARD_ID}}FK = sp.id
         AND td.statistic_data_typeFK = {{DATA_TEAM_TYPE_ID}}
         AND td.del = 'no'
         AND td.value REGEXP '^[0-9]+$'
        JOIN participant tp ON tp.id = CAST(TRIM(td.value) AS UNSIGNED) AND tp.del = 'no' AND tp.type = 'team'
        WHERE s.del = 'no'
          AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
          AND s.object_typeFK = 3
          AND tt.sportFK = {{SPORT_ID}}
          AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
          -- AND tt.id = <tournament_template_id>
        GROUP BY s.id, s.name, tt.name, t.name, sg.value, tp.id, tp.name
    ) g
    GROUP BY g.statistic_id, g.statistic_name, g.template_name, g.tournament_name, g.statistic_gender
) a
WHERE a.teams_with_uneven_gender > 0

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN statistic_config sg ON sg.statisticFK = s.id AND sg.del = 'no'
     AND sg.statistic_data_typeFK = {{CONFIG_GENDER_TYPE_ID}}
     AND LOWER(TRIM(sg.value)) = 'mixed'
JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = s.id AND sp.del = 'no'
JOIN participant p ON p.id = sp.participantFK AND p.del = 'no' AND p.type = 'athlete'
JOIN statistic_data{{SHARD_ID}} td
  ON td.statistic_participants{{SHARD_ID}}FK = sp.id
 AND td.statistic_data_typeFK = {{DATA_TEAM_TYPE_ID}}
 AND td.del = 'no'
 AND td.value REGEXP '^[0-9]+$'
JOIN participant tp ON tp.id = CAST(TRIM(td.value) AS UNSIGNED) AND tp.del = 'no' AND tp.type = 'team'
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-070
    -- Name - COMP.RANK_RESULTS_VALUE_BLANK
    -- What it does: Finds active statistic-participant rows of the selected statistic type, excluding IOC-purpose templates, holding at least one active data row whose value is neither empty nor readable, being made only of ordinary spacing or only of invisible characters such as a non-breaking or zero-width space, separating the two, with the data fields affected and template and tournament name context, together with a coverage count of all eligible statistic-participant rows holding at least one active data row.
    CASE
        WHEN x.invisible_count > 0 THEN 'BLANK_INVISIBLE_CHARACTER'
        ELSE 'BLANK_WHITESPACE_ONLY'
    END AS check_type,
    x.statistic_participants_id,
    x.statistic_id,
    x.statistic_name,
    x.template_name,
    x.tournament_name,
    x.participant_name,
    x.blank_data_fields,
    x.blank_data_count,
    NULL AS eligible_count,
    0 AS sort_order
FROM (
    SELECT
        sp.id AS statistic_participants_id,
        s.id AS statistic_id,
        s.name AS statistic_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        p.name AS participant_name,
        COUNT(DISTINCT sd.id) AS blank_data_count,
        -- A field name is not unique in statistic_data_type, so the ID is carried beside it.
        GROUP_CONCAT(DISTINCT CONCAT(COALESCE(sdt.name, 'unnamed'), ' #', sd.statistic_data_typeFK)
                     ORDER BY 1 SEPARATOR ', ') AS blank_data_fields,
        -- The class boundary is the one GLOBAL-DQ-069 states for the event layer: the
        -- invisible-character class survives TRIM() and therefore reaches the other data
        -- checks as a false value, while ordinary spacing is dropped by their findings and
        -- their coverage alike.
        SUM(CASE WHEN TRIM(sd.value) <> '' THEN 1 ELSE 0 END) AS invisible_count,
        SUM(CASE WHEN TRIM(sd.value) = '' THEN 1 ELSE 0 END) AS whitespace_count
    FROM statistic_data{{SHARD_ID}} sd
    JOIN statistic_participants{{SHARD_ID}} sp ON sp.id = sd.statistic_participants{{SHARD_ID}}FK AND sp.del = 'no'
    JOIN statistic s ON s.id = sp.statisticFK AND s.del = 'no'
    JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN participant p ON p.id = sp.participantFK AND p.del = 'no'
    LEFT JOIN statistic_data_type sdt ON sdt.id = sd.statistic_data_typeFK
    WHERE sd.del = 'no'
      AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
      AND s.object_typeFK = 3
      AND tt.sportFK = {{SPORT_ID}}
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      -- AND tt.id = <tournament_template_id>
      -- NULL and '' are one state in DATABASE.md, the active empty row, which is how this
      -- layer records that a field does not apply to a participant - a Comp.Rank field set
      -- is declared per statistic type, not per participant. Both are out of scope.
      AND sd.value IS NOT NULL
      AND sd.value <> ''
      AND TRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(sd.value,
              UNHEX('C2A0'), ' '), UNHEX('E2808B'), ' '), UNHEX('EFBBBF'), ' '),
              CHAR(9), ' '), CHAR(10), ' '), CHAR(13), ' ')) = ''
    GROUP BY sp.id, s.id, s.name, tt.name, t.name, p.name
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT sp.id) AS eligible_count,
    1 AS sort_order
FROM statistic_data{{SHARD_ID}} sd
JOIN statistic_participants{{SHARD_ID}} sp ON sp.id = sd.statistic_participants{{SHARD_ID}}FK AND sp.del = 'no'
JOIN statistic s ON s.id = sp.statisticFK AND s.del = 'no'
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE sd.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>

ORDER BY sort_order, blank_data_count DESC;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-072
    -- Name - COMP.RANK_RESULTS_MEDAL_RANK_MISMATCH
    -- What it does: Finds active statistic-participant rows of the selected statistic type, excluding IOC-purpose templates, carrying an active non-empty Medal value whose Rank does not match the place the medal stands for, or that carry no Rank at all, with template and tournament name context, together with a coverage count of all eligible statistic-participant rows carrying an active non-empty Medal value.
    CASE
        WHEN x.rank_value IS NULL THEN 'MEDAL_WITHOUT_RANK'
        ELSE 'MEDAL_RANK_MISMATCH'
    END AS check_type,
    x.statistic_participants_id,
    x.statistic_id,
    x.statistic_name,
    x.template_name,
    x.tournament_name,
    x.participant_name,
    x.medal_value,
    x.rank_value,
    x.expected_rank,
    NULL AS eligible_count
FROM (
    SELECT
        sp.id AS statistic_participants_id,
        s.id AS statistic_id,
        s.name AS statistic_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        p.name AS participant_name,
        sm.value AS medal_value,
        CASE LOWER(TRIM(sm.value))
            WHEN 'gold' THEN '1'
            WHEN 'silver' THEN '2'
            WHEN 'bronze' THEN '3'
            ELSE NULL
        END AS expected_rank,
        (SELECT NULLIF(TRIM(sd2.value), '') FROM statistic_data{{SHARD_ID}} sd2
          WHERE sd2.statistic_participants{{SHARD_ID}}FK = sp.id
            AND sd2.statistic_data_typeFK = {{DATA_RANK_TYPE_ID}}
            AND sd2.del = 'no' AND sd2.value IS NOT NULL LIMIT 1) AS rank_value
    FROM statistic_data{{SHARD_ID}} sm
    JOIN statistic_participants{{SHARD_ID}} sp ON sp.id = sm.statistic_participants{{SHARD_ID}}FK AND sp.del = 'no'
    JOIN statistic s ON s.id = sp.statisticFK AND s.del = 'no'
    JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN participant p ON p.id = sp.participantFK AND p.del = 'no'
    WHERE sm.del = 'no'
      AND sm.statistic_data_typeFK = {{DATA_MEDAL_TYPE_ID}}
      AND sm.value IS NOT NULL
      AND TRIM(sm.value) <> ''
      AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
      AND s.object_typeFK = 3
      AND tt.sportFK = {{SPORT_ID}}
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      -- AND tt.id = <tournament_template_id>
) x
-- A value outside gold, silver and bronze resolves to no expected rank and is left to
-- GLOBAL-DQ-027, so the two do not report the same row under different verdicts.
WHERE x.expected_rank IS NOT NULL
  AND (x.rank_value IS NULL OR x.rank_value <> x.expected_rank)

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT sp.id) AS eligible_count
FROM statistic_data{{SHARD_ID}} sm
JOIN statistic_participants{{SHARD_ID}} sp ON sp.id = sm.statistic_participants{{SHARD_ID}}FK AND sp.del = 'no'
JOIN statistic s ON s.id = sp.statisticFK AND s.del = 'no'
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE sm.del = 'no'
  AND sm.statistic_data_typeFK = {{DATA_MEDAL_TYPE_ID}}
  AND sm.value IS NOT NULL
  AND TRIM(sm.value) <> ''
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-077
    -- Name - COMP.RANK_RESULTS_NUMERIC_FIELD_NON_NUMERIC
    -- What it does: Finds active statistic-participant rows of the selected statistic type, excluding IOC-purpose templates, holding a value in one of the sport's numeric data fields that is not a number, separating a value that is one of the sport's own status codes, a value that is a sentinel standing for no data such as nan or n/a, a number written with thousands separators, and any other text, with the data field, the value and template and tournament name context, together with a coverage count of all eligible statistic-participant rows holding an active non-empty value in one of those fields.
    CASE
        WHEN LOWER(TRIM(sd.value)) IN ({{DATA_COMMENT_VALUE_LIST}}) THEN 'STATUS_CODE_IN_NUMERIC_FIELD'
        WHEN LOWER(TRIM(sd.value)) IN ('nan', 'null', 'n/a', 'na', '-', '--', '?', 'none') THEN 'SENTINEL_IN_NUMERIC_FIELD'
        -- As in GLOBAL-DQ-076: a grouped number is a number written for a reader, and the
        -- repair is to drop the separators rather than to find the value again.
        WHEN TRIM(sd.value) REGEXP '^-?[0-9]{1,3}(,[0-9]{3})+([.][0-9]+)?$' THEN 'GROUPED_NUMBER_IN_NUMERIC_FIELD'
        ELSE 'TEXT_IN_NUMERIC_FIELD'
    END AS check_type,
    sp.id AS statistic_participants_id,
    s.id AS statistic_id,
    s.name AS statistic_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    p.name AS participant_name,
    sd.statistic_data_typeFK,
    sd.value AS stored_value,
    NULL AS eligible_count
FROM statistic_data{{SHARD_ID}} sd
JOIN statistic_participants{{SHARD_ID}} sp ON sp.id = sd.statistic_participants{{SHARD_ID}}FK AND sp.del = 'no'
JOIN statistic s ON s.id = sp.statisticFK AND s.del = 'no'
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN participant p ON p.id = sp.participantFK AND p.del = 'no'
WHERE sd.del = 'no'
  AND sd.statistic_data_typeFK IN ({{NUMERIC_DATA_TYPE_LIST}})
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
  AND sd.value IS NOT NULL
  AND TRIM(sd.value) <> ''
  -- The mirror of GLOBAL-DQ-057, and inventoried separately from the event layer because
  -- a field is declared numeric per statistic type, not across the two layers.
  AND TRIM(sd.value) NOT REGEXP '^-?[0-9]+([.,][0-9]+)?$'

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT sp.id) AS eligible_count
FROM statistic_data{{SHARD_ID}} sd
JOIN statistic_participants{{SHARD_ID}} sp ON sp.id = sd.statistic_participants{{SHARD_ID}}FK AND sp.del = 'no'
JOIN statistic s ON s.id = sp.statisticFK AND s.del = 'no'
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE sd.del = 'no'
  AND sd.statistic_data_typeFK IN ({{NUMERIC_DATA_TYPE_LIST}})
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
  AND sd.value IS NOT NULL
  AND TRIM(sd.value) <> ''
;
