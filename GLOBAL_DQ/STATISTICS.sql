SELECT
    -- CheckID - GLOBAL-DQ-010
    -- Name - COMP.RANK_NO_PARTICIPANTS
    -- What it does: Finds Comp.Rank holding no participant rows in the sport's shard.
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
  -- AND t.tournament_templateFK = <tournament_template_id>
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
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-011
    -- Name - COMP.RANK_SETTINGS_MISSING_START_OR_END_DATE
    -- What it does: Finds Comp.Rank with a missing or empty Start date or End date.
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
  -- AND t.tournament_templateFK = <tournament_template_id>
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
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-012
    -- Name - COMP.RANK_RESULTS_RANK_INVALID_OR_MISSING
    -- What it does: Finds Comp.Rank holding a participant whose Rank is not a positive integer, or is missing with no Comment to explain it.
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
  -- AND t.tournament_templateFK = <tournament_template_id>
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
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-022
    -- Name - COMP.RANK_SETTINGS_MISSING_AGE_CLASS
    -- What it does: Finds Comp.Rank with no age-class relation.
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
  -- AND t.tournament_templateFK = <tournament_template_id>
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
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-023
    -- Name - COMP.RANK_SETTINGS_MISSING_DISCIPLINE
    -- What it does: Finds Comp.Rank with no discipline relation, or one naming a discipline that does not resolve.
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
  -- AND t.tournament_templateFK = <tournament_template_id>
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
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-024
    -- Name - COMP.RANK_SETTINGS_DATE_RANGE_MISMATCH_STAGE
    -- What it does: Finds Comp.Rank whose configured date interval is inverted, or is not contained within the stage dates of its own tournament, separating an inverted interval, one crossing both bounds, a start before the earliest stage and an end after the latest.
    CASE
        WHEN DATE(x.config_start_date) > DATE(x.config_end_date)
            THEN 'Config_Date_Range_Inverted'
        WHEN DATE(x.config_start_date) < DATE(x.earliest_stage_startdate)
         AND DATE(x.config_end_date) > DATE(x.latest_stage_enddate)
            THEN 'Config_Outside_Both_Stage_Bounds'
        WHEN DATE(x.config_start_date) < DATE(x.earliest_stage_startdate)
            THEN 'Config_Start_Before_Stage_Span'
        ELSE 'Config_End_After_Stage_Span'
    END AS check_type,
    x.statistic_id,
    x.statistic_name,
    x.template_name,
    x.tournament_name,
    x.config_start_date,
    x.config_end_date,
    x.earliest_stage_startdate,
    x.latest_stage_enddate,
    NULL AS eligible_count
FROM (
    SELECT
        s.id AS statistic_id,
        s.name AS statistic_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        (SELECT MIN(sc1.value) FROM statistic_config sc1 WHERE sc1.statisticFK = s.id AND sc1.statistic_data_typeFK = {{CONFIG_START_DATE_TYPE_ID}} AND sc1.del = 'no') AS config_start_date,
        (SELECT MAX(sc2.value) FROM statistic_config sc2 WHERE sc2.statisticFK = s.id AND sc2.statistic_data_typeFK = {{CONFIG_END_DATE_TYPE_ID}} AND sc2.del = 'no') AS config_end_date,
        MIN(ts.startdate) AS earliest_stage_startdate,
        MAX(ts.enddate) AS latest_stage_enddate
    FROM statistic s
    JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
    WHERE s.del = 'no'
      AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
      AND s.object_typeFK = 3
      AND tt.sportFK = {{SPORT_ID}}
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      -- AND t.tournament_templateFK = <tournament_template_id>
    GROUP BY s.id, s.name, tt.name, t.name
) x
-- Containment, not endpoint equality, is the invariant. A tournament is often a season and a
-- statistic often covers one stage of it, so a window that starts after the earliest stage and
-- ends before the latest one is the normal case, not a finding.
WHERE DATE(x.config_start_date) > DATE(x.config_end_date)
   OR DATE(x.config_start_date) < DATE(x.earliest_stage_startdate)
   OR DATE(x.config_end_date) > DATE(x.latest_stage_enddate)

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
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND EXISTS (
      SELECT 1 FROM statistic_config sc3
      WHERE sc3.statisticFK = s.id AND sc3.statistic_data_typeFK IN ({{CONFIG_START_DATE_TYPE_ID}}, {{CONFIG_END_DATE_TYPE_ID}}) AND sc3.del = 'no'
  );


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-025
    -- Name - COMP.RANK_SETTINGS_DATE_RANGE_MISMATCH_EVENTS
    -- What it does: Finds Comp.Rank whose configured date interval is inverted, or does not contain every event it names through the Event id config, separating the four boundary failures.
    CASE
        WHEN DATE(x.config_start_date) > DATE(x.config_end_date)
            THEN 'Config_Date_Range_Inverted'
        WHEN DATE(x.earliest_linked_event_startdate) < DATE(x.config_start_date)
         AND DATE(x.latest_linked_event_startdate) > DATE(x.config_end_date)
            THEN 'Linked_Events_Outside_Both_Bounds'
        WHEN DATE(x.earliest_linked_event_startdate) < DATE(x.config_start_date)
            THEN 'Linked_Event_Before_Config_Start'
        ELSE 'Linked_Event_After_Config_End'
    END AS check_type,
    x.statistic_id,
    x.statistic_name,
    x.template_name,
    x.tournament_name,
    x.config_start_date,
    x.config_end_date,
    x.earliest_linked_event_startdate,
    x.latest_linked_event_startdate,
    NULL AS eligible_count
FROM (
    SELECT
        s.id AS statistic_id,
        s.name AS statistic_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        (SELECT MIN(sc1.value)
         FROM statistic_config sc1
         WHERE sc1.statisticFK = s.id
           AND sc1.statistic_data_typeFK = {{CONFIG_START_DATE_TYPE_ID}}
           AND sc1.del = 'no') AS config_start_date,
        (SELECT MAX(sc2.value)
         FROM statistic_config sc2
         WHERE sc2.statisticFK = s.id
           AND sc2.statistic_data_typeFK = {{CONFIG_END_DATE_TYPE_ID}}
           AND sc2.del = 'no') AS config_end_date,
        MIN(e.startdate) AS earliest_linked_event_startdate,
        MAX(e.startdate) AS latest_linked_event_startdate
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
      -- AND t.tournament_templateFK = <tournament_template_id>
      AND EXISTS (
          SELECT 1 FROM statistic_config sc3
          WHERE sc3.statisticFK = s.id
            AND sc3.statistic_data_typeFK IN ({{CONFIG_START_DATE_TYPE_ID}}, {{CONFIG_END_DATE_TYPE_ID}})
            AND sc3.del = 'no'
      )
    GROUP BY s.id, s.name, tt.name, t.name
) x
WHERE DATE(x.config_start_date) > DATE(x.config_end_date)
   OR DATE(x.earliest_linked_event_startdate) < DATE(x.config_start_date)
   OR DATE(x.latest_linked_event_startdate) > DATE(x.config_end_date)

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
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND EXISTS (
      SELECT 1 FROM statistic_config sc3
      WHERE sc3.statisticFK = s.id AND sc3.statistic_data_typeFK IN ({{CONFIG_START_DATE_TYPE_ID}}, {{CONFIG_END_DATE_TYPE_ID}}) AND sc3.del = 'no'
  );


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-026
    -- Name - COMP.RANK_SETTINGS_MEDAL_SET_INVALID
    -- What it does: Finds Comp.Rank whose medal set does not follow the places its own Rank rows hold: a type missing, held by more competitors than the place takes, held by fewer, or standing over a podium that never reaches the place it belongs to - counting relay members who share their team's medal as one holder.
    CASE
        -- Nothing to compare the medals with. The missing Rank is GLOBAL-DQ-012's finding and
        -- is not restated here; what this row says is that the medal set was not audited.
        WHEN x.ranked_holders = 0 THEN 'Medal_Set_Unreadable_Without_Rank'
        WHEN x.total_medal_count = 0 THEN 'No_Medals_At_All'
        -- A shared place removes the place below it, so a second gold beside a silver is a
        -- contradiction, while a second gold without one is the shape a tie actually takes.
        -- Which of the two it is comes from the places themselves: a place held by two
        -- competitors is owed two medals of its colour, and one nobody holds is owed none.
        WHEN x.gold_count > x.rank1_count AND x.silver_count > 0 THEN 'Duplicate_Gold_With_Silver_Present'
        WHEN x.silver_count > x.rank2_count AND x.bronze_count > 0 THEN 'Duplicate_Silver_With_Bronze_Present'
        WHEN x.gold_count > x.rank1_count OR x.silver_count > x.rank2_count THEN 'Duplicate_Medal_Tie_Shape'
        WHEN x.bronze_count > x.rank3_count THEN 'Duplicate_Bronze'
        -- The other side of a tie: the place is shared and carries a medal, but not one for
        -- every competitor standing on it.
        WHEN (x.rank1_count > 1 AND x.gold_count   BETWEEN 1 AND x.rank1_count - 1)
          OR (x.rank2_count > 1 AND x.silver_count BETWEEN 1 AND x.rank2_count - 1)
          OR (x.rank3_count > 1 AND x.bronze_count BETWEEN 1 AND x.rank3_count - 1)
             THEN 'Medal_Missing_For_Shared_Place'
        -- An empty place is only legitimate when a tie above it consumed it: after k
        -- competitors starting at first, the next place is k + 1. Without this the two are
        -- indistinguishable, because a shared podium and a truncated one both leave the place
        -- below unheld - and a Comp.Rank that stops after its champion would read as clean.
        WHEN x.rank1_count = 0 THEN 'Podium_Without_First_Place'
        WHEN (x.rank1_count = 1 AND x.rank2_count = 0)
          OR (1 + x.rank1_count + x.rank2_count = 3 AND x.rank3_count = 0)
             THEN 'Podium_Truncated_Below_Medal'
        ELSE 'Missing_Specific_Medal'
    END AS check_type,
    x.statistic_id,
    x.statistic_name,
    x.template_name,
    x.tournament_name,
    CONCAT_WS(', ',
        IF(x.rank1_count > 0, CONCAT('1st x', x.rank1_count), NULL),
        IF(x.rank2_count > 0, CONCAT('2nd x', x.rank2_count), NULL),
        IF(x.rank3_count > 0, CONCAT('3rd x', x.rank3_count), NULL)
    ) AS places_held,
    CONCAT_WS(', ',
        IF(x.gold_count   < x.rank1_count, CONCAT('gold ',   x.gold_count,   ' of ', x.rank1_count), NULL),
        IF(x.silver_count < x.rank2_count, CONCAT('silver ', x.silver_count, ' of ', x.rank2_count), NULL),
        IF(x.bronze_count < x.rank3_count, CONCAT('bronze ', x.bronze_count, ' of ', x.rank3_count), NULL)
    ) AS missing_medals,
    CONCAT_WS(', ',
        IF(x.gold_count   > x.rank1_count, CONCAT('gold x',   x.gold_count,   ' for ', x.rank1_count), NULL),
        IF(x.silver_count > x.rank2_count, CONCAT('silver x', x.silver_count, ' for ', x.rank2_count), NULL),
        IF(x.bronze_count > x.rank3_count, CONCAT('bronze x', x.bronze_count, ' for ', x.rank3_count), NULL)
    ) AS duplicated_medals,
    CONCAT('gold=', x.gold_count, ' silver=', x.silver_count, ' bronze=', x.bronze_count,
           ' first=', x.rank1_count, ' second=', x.rank2_count, ' third=', x.rank3_count) AS medal_holder_counts,
    NULL AS eligible_count
FROM (
    SELECT
        s.id AS statistic_id,
        s.name AS statistic_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        -- A place is held by one competitor, and in a relay that competitor is the team.
        -- Counting medal rows instead would read every member of a winning relay as a
        -- duplicate gold, so each medal is counted over distinct teams where the statistic
        -- assigns one, and over distinct participants where it does not. The places are
        -- counted over the same holder, which is what lets the two be compared at all.
        COUNT(DISTINCT CASE WHEN LOWER(TRIM(sd.value)) = 'gold'
             THEN COALESCE(TRIM(tmd.value), CONCAT('p', sp.id)) END) AS gold_count,
        COUNT(DISTINCT CASE WHEN LOWER(TRIM(sd.value)) = 'silver'
             THEN COALESCE(TRIM(tmd.value), CONCAT('p', sp.id)) END) AS silver_count,
        COUNT(DISTINCT CASE WHEN LOWER(TRIM(sd.value)) = 'bronze'
             THEN COALESCE(TRIM(tmd.value), CONCAT('p', sp.id)) END) AS bronze_count,
        COUNT(DISTINCT CASE WHEN sd.value IS NOT NULL AND TRIM(sd.value) <> ''
             THEN COALESCE(TRIM(tmd.value), CONCAT('p', sp.id)) END) AS total_medal_count,
        COUNT(DISTINCT CASE WHEN rkd.value IS NOT NULL AND TRIM(rkd.value) <> ''
             THEN COALESCE(TRIM(tmd.value), CONCAT('p', sp.id)) END) AS ranked_holders,
        COUNT(DISTINCT CASE WHEN TRIM(rkd.value) = '1'
             THEN COALESCE(TRIM(tmd.value), CONCAT('p', sp.id)) END) AS rank1_count,
        COUNT(DISTINCT CASE WHEN TRIM(rkd.value) = '2'
             THEN COALESCE(TRIM(tmd.value), CONCAT('p', sp.id)) END) AS rank2_count,
        COUNT(DISTINCT CASE WHEN TRIM(rkd.value) = '3'
             THEN COALESCE(TRIM(tmd.value), CONCAT('p', sp.id)) END) AS rank3_count
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
    LEFT JOIN statistic_data{{SHARD_ID}} rkd
      ON rkd.statistic_participants{{SHARD_ID}}FK = sp.id
     AND rkd.del = 'no'
     AND rkd.statistic_data_typeFK = {{DATA_RANK_TYPE_ID}}
    WHERE s.del = 'no'
      AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
      AND s.object_typeFK = 3
      AND tt.sportFK = {{SPORT_ID}}
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      -- AND t.tournament_templateFK = <tournament_template_id>
    GROUP BY s.id, s.name, tt.name, t.name
) x
WHERE x.ranked_holders = 0
   OR x.gold_count   <> x.rank1_count
   OR x.silver_count <> x.rank2_count
   OR x.bronze_count <> x.rank3_count
   OR x.rank1_count = 0
   OR (x.rank1_count = 1 AND x.rank2_count = 0)
   OR (1 + x.rank1_count + x.rank2_count = 3 AND x.rank3_count = 0)

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-027
    -- Name - COMP.RANK_RESULTS_MEDAL_INVALID_VALUE
    -- What it does: Finds Comp.Rank Medal values that are not gold, silver or bronze.
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
  -- AND t.tournament_templateFK = <tournament_template_id>
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
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-028
    -- Name - COMP.RANK_RESULTS_TIME_DIFFERENCE_FORMAT_MISMATCH_TO_RANK
    -- What it does: Finds Comp.Rank holding a participant whose Time Difference breaks the leader/gap convention: rank 1 a plain absolute time, every other rank a plus-prefixed gap.
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
  -- AND t.tournament_templateFK = <tournament_template_id>
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
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND TRIM(rk.value) <> ''
  AND TRIM(td.value) <> ''
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-029
    -- Name - COMP.RANK_RESULTS_DEPRECATED_DURATION_USED
    -- What it does: Finds Comp.Rank still storing a value in the deprecated Duration field, with which of the current Time and Time Difference fields are populated beside it.
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
  -- AND t.tournament_templateFK = <tournament_template_id>
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
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-030
    -- Name - COMP.RANK_RESULTS_PARTICIPANT_NOT_IN_TOURNAMENT
    -- What it does: Finds Comp.Rank statistics holding participants who are neither an event participant nor a lineup member anywhere under their own tournament.
    'PARTICIPANT_NOT_IN_TOURNAMENT' AS check_type,
    s.id AS statistic_id,
    tt.name AS template_name,
    t.name AS tournament_name,
    COUNT(DISTINCT sp.participantFK) AS stray_participants,
    COUNT(DISTINCT sp.id) AS stray_participant_rows,
    GROUP_CONCAT(DISTINCT p.id ORDER BY p.id SEPARATOR ' | ') AS participant_ids,
    GROUP_CONCAT(DISTINCT p.name ORDER BY p.name SEPARATOR ' | ') AS participant_names,
    NULL AS eligible_count
-- One row per Comp.Rank statistic, not per stray participant. The two read very differently:
-- on Triathlon the same 1130 stray rows are 63 statistics, and the row-level shape repeated a
-- tournament's name up to 54 times for what is one table with one thing wrong with it. Whoever
-- fixes this works a statistic at a time, so that is the audited object and the coverage
-- counts statistics to match.
--
-- The two lists are convenience and the counts beside them are authoritative: the server caps
-- GROUP_CONCAT at 1024 characters and truncates silently past it, which the widest group
-- measured already reaches. A list naming fewer people than stray_participants says has been
-- cut, and the ids are the ones to trust first because they are shorter.
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
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND NOT EXISTS (
      SELECT 1
      FROM tournament_stage ts2
      JOIN event e2 ON e2.tournament_stageFK = ts2.id AND e2.del = 'no'
      JOIN event_participants ep2 ON ep2.eventFK = e2.id AND ep2.del = 'no'
      WHERE ts2.tournamentFK = t.id
        AND ts2.del = 'no'
        AND ep2.participantFK = sp.participantFK
  )
  AND NOT EXISTS (
      SELECT 1
      FROM tournament_stage ts3
      JOIN event e3 ON e3.tournament_stageFK = ts3.id AND e3.del = 'no'
      JOIN event_participants ep3 ON ep3.eventFK = e3.id AND ep3.del = 'no'
      JOIN lineup l3 ON l3.event_participantsFK = ep3.id
                    AND l3.del = 'no'
                    AND l3.participantFK = sp.participantFK
      WHERE ts3.tournamentFK = t.id
        AND ts3.del = 'no'
  )
GROUP BY s.id, tt.name, t.name

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
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
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-031
    -- Name - COMP.RANK_RESULTS_RANK_OUTLIER_ABOVE_FIELD_SIZE
    -- What it does: Finds Comp.Rank participants whose Rank exceeds the number ranked and is disconnected from the next lower Rank, with no Comment to explain it.
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
      -- AND t.tournament_templateFK = <tournament_template_id>
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
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-032
    -- Name - COMP.RANK_RESULTS_NO_RANK_DATA_FOR_PARTICIPANTS
    -- What it does: Finds Comp.Rank holding participants but no Rank value for any of them, separating one holding no data at all from one holding other data.
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
      -- AND t.tournament_templateFK = <tournament_template_id>
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
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-033
    -- Name - COMP.RANK_RESULTS_MISSING_PHASE
    -- What it does: Finds Comp.Rank carrying participants with no phase row, naming how many of the field are missing one and who they are.
    'MISSING_PHASE' AS check_type,
    x.statistic_id,
    x.statistic_name,
    x.template_name,
    x.tournament_name,
    x.field_size,
    x.missing_count,
    -- A convenience for the reader, not the finding: GROUP_CONCAT truncates at the server's
    -- group_concat_max_len without saying so, and missing_count is counted separately and is
    -- what the row asserts.
    x.missing_participants,
    NULL AS eligible_count
FROM (
    SELECT
        y.statistic_id,
        y.statistic_name,
        y.template_name,
        y.tournament_name,
        COUNT(*) AS field_size,
        SUM(y.is_missing) AS missing_count,
        GROUP_CONCAT(CASE WHEN y.is_missing = 1 THEN y.participant_name END
                     ORDER BY y.participant_name SEPARATOR ', ') AS missing_participants
    FROM (
        -- One row per participant of the Comp.Rank, carrying whether a phase row exists for
        -- them. The statistic is the audited object: an import that wrote no phases at all is
        -- one repair and not one per competitor, and reported per competitor it read as
        -- twenty - against a coverage count of every Comp.Rank participant in the sport, which
        -- made the proportion wrong in both halves. field_size and missing_count keep the two
        -- shapes apart: equal means the whole Comp.Rank has no phases, lower means the phases
        -- were written for part of the field only, which is a different repair.
        SELECT
            s.id AS statistic_id,
            s.name AS statistic_name,
            tt.name AS template_name,
            t.name AS tournament_name,
            p.name AS participant_name,
            CASE WHEN NOT EXISTS (
                    SELECT 1
                    FROM object_round orr
                    WHERE orr.objectFK = sp.id
                      AND orr.object_typeFK = 138
                      AND orr.type = 'phase'
                      AND orr.del = 'no'
                ) THEN 1 ELSE 0 END AS is_missing
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
          -- AND t.tournament_templateFK = <tournament_template_id>
    ) y
    GROUP BY y.statistic_id, y.statistic_name, y.template_name, y.tournament_name
) x
WHERE x.missing_count > 0

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
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
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-035
    -- Name - COMP.RANK_SETTINGS_MISSING_CORE_FIELDS
    -- What it does: Finds Comp.Rank missing a name, a Gender config, a country or a city relation, or carrying a country that resolves only to a placeholder.
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
  -- AND t.tournament_templateFK = <tournament_template_id>
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
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-040
    -- Name - EVENT_FINAL_WITHOUT_COMP.RANK
    -- What it does: Finds Final-round events that no Comp.Rank under their own tournament names through its Event id config, separating a tournament holding none at all from one whose Comp.Rank declares no event scope.
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
      -- AND t.tournament_templateFK = <tournament_template_id>
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
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-041
    -- Name - COMP.RANK_RESULTS_MEDAL_ON_NON_MEDAL_ROUND_PHASE
    -- What it does: Finds Comp.Rank participants carrying a Medal while their phase names a round the sport awards no medals on.
    'MEDAL_ON_NON_MEDAL_ROUND_PHASE' AS check_type,
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
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND orr.round_typeFK NOT IN ({{MEDAL_ROUND_TYPE_LIST}})

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
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-042
    -- Name - EVENT_FINAL_PARTICIPANT_NOT_IN_COMP.RANK
    -- What it does: Finds Final-round events whose Comp.Rank omits competitors who took part, naming how many of the field are missing from it and who they are.
    'FINAL_PARTICIPANT_NOT_IN_COMP.RANK' AS check_type,
    x.event_id,
    x.event_name,
    x.template_name,
    x.tournament_name,
    x.field_size,
    x.missing_count,
    -- A convenience for the reader, not the finding: GROUP_CONCAT truncates at the server's
    -- group_concat_max_len without saying so, and missing_count is counted separately and is
    -- what the row asserts.
    x.missing_participants,
    NULL AS eligible_count
FROM (
    SELECT
        y.event_id,
        y.event_name,
        y.template_name,
        y.tournament_name,
        COUNT(*) AS field_size,
        SUM(y.is_missing) AS missing_count,
        GROUP_CONCAT(CASE WHEN y.is_missing = 1 THEN y.participant_name END
                     ORDER BY y.participant_name SEPARATOR ', ') AS missing_participants
    FROM (
        -- One row per competitor in the event, carrying whether the Comp.Rank covering that
        -- event lists them. The event is the audited object: a statistic that omits six of
        -- eight finalists is one broken import and not six, and reported per competitor it
        -- read as six - against a coverage count of every Final participant in the sport,
        -- which made the proportion wrong in both halves.
        SELECT
            e.id AS event_id,
            e.name AS event_name,
            tt.name AS template_name,
            t.name AS tournament_name,
            p.name AS participant_name,
            CASE WHEN NOT EXISTS (
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
                ) THEN 1 ELSE 0 END AS is_missing
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
          -- AND t.tournament_templateFK = <tournament_template_id>
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
    ) y
    GROUP BY y.event_id, y.event_name, y.template_name, y.tournament_name
) x
WHERE x.missing_count > 0

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND e.round_typeFK IN ({{FINAL_ROUND_TYPE_LIST}})
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND t.tournament_templateFK = <tournament_template_id>
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
    -- What it does: Finds Comp.Rank whose Gender config does not match the gender of its own participants.
    'Gender_Mismatch' AS check_type,
    elig.statistic_id,
    elig.statistic_name,
    elig.template_name,
    elig.tournament_name,
    elig.statistic_gender,
    MAX(p.type) AS participant_type_seen,
    COUNT(DISTINCT CASE WHEN p.gender = 'male' THEN p.id END) AS male_cnt,
    COUNT(DISTINCT CASE WHEN p.gender = 'female' THEN p.id END) AS female_cnt,
    COUNT(DISTINCT CASE WHEN p.gender = 'mixed' THEN p.id END) AS mixed_cnt,
    COUNT(DISTINCT CASE WHEN p.type = 'team' AND p.gender <> 'mixed' THEN p.id END) AS team_wrong_gender_cnt,
    CASE
        WHEN elig.statistic_gender = 'male'
             AND COUNT(DISTINCT CASE WHEN p.gender <> 'male' THEN p.id END) > 0
            THEN 'MALE_STATISTIC_HAS_NONMALE'
        WHEN elig.statistic_gender = 'female'
             AND COUNT(DISTINCT CASE WHEN p.gender <> 'female' THEN p.id END) > 0
            THEN 'FEMALE_STATISTIC_HAS_NONFEMALE'
        WHEN elig.statistic_gender = 'mixed'
             AND COUNT(DISTINCT CASE WHEN p.type = 'team' THEN p.id END) > 0
             AND COUNT(DISTINCT CASE WHEN p.type = 'team' AND p.gender <> 'mixed' THEN p.id END) > 0
            THEN 'MIXED_TEAM_NOT_MIXED_GENDER'
        WHEN elig.statistic_gender = 'mixed'
             AND COUNT(DISTINCT CASE WHEN p.type = 'athlete' THEN p.id END) > 0
             AND (
                  COUNT(DISTINCT CASE WHEN p.type = 'athlete' AND p.gender = 'male' THEN p.id END) = 0
               OR COUNT(DISTINCT CASE WHEN p.type = 'athlete' AND p.gender = 'female' THEN p.id END) = 0
             )
            THEN 'MIXED_ATHLETES_MISSING_ONE_SIDE'
        ELSE 'OK'
    END AS violation_type,
    NULL AS eligible_count
FROM (
    -- The eligible statistics are resolved in their own materialised step, and the GROUP BY
    -- is what makes it materialise rather than be merged into the query above. Without it,
    -- filtering on sg.value makes the optimiser drive from statistic_config - a table holding
    -- every sport's configuration - and probe the participant shard once per row of it, which
    -- does not finish on a large sport. Resolved first, the statistics are a small known set
    -- and the participants join to them.
    SELECT
        st.id AS statistic_id,
        st.name AS statistic_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        MIN(sg.value) AS statistic_gender
    FROM statistic st
    JOIN tournament t ON t.id = st.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN statistic_config sg ON sg.statisticFK = st.id AND sg.statistic_data_typeFK = {{CONFIG_GENDER_TYPE_ID}} AND sg.del = 'no'
    WHERE st.del = 'no'
      AND st.statistic_typeFK = {{STATISTIC_TYPE_ID}}
      AND st.object_typeFK = 3
      AND tt.sportFK = {{SPORT_ID}}
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      AND sg.value IN ('male','female','mixed')
      -- AND t.tournament_templateFK = <tournament_template_id>
    GROUP BY st.id, st.name, tt.name, t.name
) elig
JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = elig.statistic_id AND sp.del = 'no'
JOIN participant p ON p.id = sp.participantFK AND p.del = 'no'
GROUP BY elig.statistic_id, elig.statistic_name, elig.template_name, elig.tournament_name, elig.statistic_gender
HAVING violation_type <> 'OK'

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT elig.statistic_id) AS eligible_count
FROM (
    -- The eligible statistics are resolved in their own materialised step, and the GROUP BY
    -- is what makes it materialise rather than be merged into the query above. Without it,
    -- filtering on sg.value makes the optimiser drive from statistic_config - a table holding
    -- every sport's configuration - and probe the participant shard once per row of it, which
    -- does not finish on a large sport. Resolved first, the statistics are a small known set
    -- and the participants join to them.
    SELECT
        st.id AS statistic_id,
        st.name AS statistic_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        MIN(sg.value) AS statistic_gender
    FROM statistic st
    JOIN tournament t ON t.id = st.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN statistic_config sg ON sg.statisticFK = st.id AND sg.statistic_data_typeFK = {{CONFIG_GENDER_TYPE_ID}} AND sg.del = 'no'
    WHERE st.del = 'no'
      AND st.statistic_typeFK = {{STATISTIC_TYPE_ID}}
      AND st.object_typeFK = 3
      AND tt.sportFK = {{SPORT_ID}}
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      AND sg.value IN ('male','female','mixed')
      -- AND t.tournament_templateFK = <tournament_template_id>
    GROUP BY st.id, st.name, tt.name, t.name
) elig
JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = elig.statistic_id AND sp.del = 'no'
JOIN participant p ON p.id = sp.participantFK AND p.del = 'no'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-046
    -- Name - COMP.RANK_RESULTS_TIME_FULL_TIME_MISMATCH_TO_RANK
    -- What it does: Finds Comp.Rank in the sport's timed disciplines whose time storage contradicts a Rank: a Time or Time Difference missing where the rank calls for one, either present with no rank, or a Time badly formatted or zero.
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
      -- AND t.tournament_templateFK = <tournament_template_id>
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
  -- AND t.tournament_templateFK = <tournament_template_id>
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
    -- What it does: Finds Comp.Rank names breaking a text-hygiene rule - spacing, control or corrupted characters, hyphenation, capitalisation, a placeholder or a numeric-only name - one row per name, naming every rule it breaks.
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
            -- The terminating semicolon is written \\x{3B} and must stay that way: the Pool cuts
            -- a statement at the first literal ';' even inside quotes, which killed this check
            -- outright. Two backslashes, because the SQL literal eats one before ICU sees it.
            IF(s.name LIKE '%&#%' OR LOWER(s.name) REGEXP '&(amp|quot|apos|lt|gt|nbsp)\\x{3B}', 'HTML_ENTITY', NULL),
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
      -- AND t.tournament_templateFK = <tournament_template_id>
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
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, violation_types, statistic_name;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-057
    -- Name - COMP.RANK_RESULTS_COMMENT_INVALID_OR_CONTRADICTED
    -- What it does: Finds Comp.Rank Comment values outside the sport's status codes, or marking a participant as unclassified while a Rank, a Time or a Medal is stored for that same participant.
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
      -- AND t.tournament_templateFK = <tournament_template_id>
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
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-060
    -- Name - COMP.RANK_RESULTS_DUPLICATE_ROWS
    -- What it does: Finds Comp.Rank holding more than one data row for the same participant and field, separating a duplicate repeating the value from one storing a conflicting one.
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
      -- AND t.tournament_templateFK = <tournament_template_id>
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
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-064
    -- Name - COMP.RANK_ATHLETE_TEAM_MISSING_OR_INVALID
    -- What it does: Finds athletes inside a Comp.Rank that uses the Team field whose own Team value is absent, does not resolve to a team, or is stored twice - repeating a value or contradicting itself.
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
      -- AND t.tournament_templateFK = <tournament_template_id>
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
      -- AND t.tournament_templateFK = <tournament_template_id>
    GROUP BY sp.id
) y
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-065
    -- Name - COMP.RANK_TEAM_ATHLETE_COUNT_UNEVEN
    -- What it does: Finds Comp.Rank whose teams do not all field the same number of athletes, separating a shortfall of one athlete from a larger one.
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
          -- AND t.tournament_templateFK = <tournament_template_id>
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
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-066
    -- Name - COMP.RANK_TEAM_GENDER_BALANCE_UNEVEN
    -- What it does: Finds mixed Comp.Rank holding a team whose athletes are not an equal number of male and female, separating a team fielding one gender only from one fielding both unevenly.
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
          -- AND t.tournament_templateFK = <tournament_template_id>
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
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-070
    -- Name - COMP.RANK_RESULTS_VALUE_BLANK
    -- What it does: Finds Comp.Rank data values that are neither empty nor readable, made only of ordinary spacing or only of invisible characters, separating the two.
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
      -- AND t.tournament_templateFK = <tournament_template_id>
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
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, blank_data_count DESC;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-072
    -- Name - COMP.RANK_RESULTS_MEDAL_RANK_MISMATCH
    -- What it does: Finds Comp.Rank participants whose Medal does not match the place it stands for, or that carry no Rank at all.
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
      -- AND t.tournament_templateFK = <tournament_template_id>
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
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-077
    -- Name - COMP.RANK_RESULTS_NUMERIC_FIELD_NON_NUMERIC
    -- What it does: Finds Comp.Rank holding non-numeric values in the sport's numeric fields, separating one of the sport's own status codes, a no-data sentinel such as nan, a number written with thousands separators, and any other text, and naming how many values are affected and what they hold.
    x.check_type,
    x.statistic_id,
    x.statistic_name,
    x.template_name,
    x.tournament_name,
    -- The data type is named rather than numbered, as in GLOBAL-DQ-076. A reader repairing the
    -- field has to know which field it is, and the id alone sends them back to the catalogue.
    x.data_type_names,
    x.affected_count,
    x.affected_participant_count,
    -- What the field actually holds, deduplicated. A statistic whose whole field stores the
    -- same sentinel is one thing to fix, and the distinct list says so in one cell where a
    -- hundred rows said it a hundred times.
    x.distinct_values,
    -- A convenience for the reader, not the finding: GROUP_CONCAT truncates at the server's
    -- group_concat_max_len without saying so, and affected_count is counted separately and is
    -- what the row asserts.
    x.affected_participants,
    NULL AS eligible_count,
    0 AS sort_order
FROM (
    SELECT
        y.check_type,
        y.statistic_id,
        y.statistic_name,
        y.template_name,
        y.tournament_name,
        GROUP_CONCAT(DISTINCT y.data_type_name ORDER BY y.data_type_name SEPARATOR ', ')
            AS data_type_names,
        COUNT(*) AS affected_count,
        COUNT(DISTINCT y.statistic_participants_id) AS affected_participant_count,
        GROUP_CONCAT(DISTINCT y.stored_value ORDER BY y.stored_value SEPARATOR ', ')
            AS distinct_values,
        GROUP_CONCAT(DISTINCT y.participant_name ORDER BY y.participant_name SEPARATOR ', ')
            AS affected_participants
    FROM (
        -- One row per offending value, grouped to the statistic below, on the same grain and
        -- for the same reason as GLOBAL-DQ-076: a field written the wrong way across a whole
        -- classification is one storage habit, and reported per participant it counted the
        -- same defect once per name in the field.
        SELECT
            CASE
                WHEN LOWER(TRIM(sd.value)) IN ({{DATA_COMMENT_VALUE_LIST}}) THEN 'STATUS_CODE_IN_NUMERIC_FIELD'
                WHEN LOWER(TRIM(sd.value)) IN ('nan', 'null', 'n/a', 'na', '-', '--', '?', 'none') THEN 'SENTINEL_IN_NUMERIC_FIELD'
                -- As in GLOBAL-DQ-076: a grouped number is a number written for a reader, and
                -- the repair is to drop the separators rather than to find the value again.
                WHEN TRIM(sd.value) REGEXP '^[-+]?[0-9]{1,3}(,[0-9]{3})+([.][0-9]+)?$' THEN 'GROUPED_NUMBER_IN_NUMERIC_FIELD'
                ELSE 'TEXT_IN_NUMERIC_FIELD'
            END AS check_type,
            s.id AS statistic_id,
            s.name AS statistic_name,
            tt.name AS template_name,
            t.name AS tournament_name,
            sdt.name AS data_type_name,
            sp.id AS statistic_participants_id,
            p.name AS participant_name,
            sd.value AS stored_value
        FROM statistic_data{{SHARD_ID}} sd
        JOIN statistic_participants{{SHARD_ID}} sp ON sp.id = sd.statistic_participants{{SHARD_ID}}FK AND sp.del = 'no'
        JOIN statistic s ON s.id = sp.statisticFK AND s.del = 'no'
        JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
        JOIN participant p ON p.id = sp.participantFK AND p.del = 'no'
        LEFT JOIN statistic_data_type sdt ON sdt.id = sd.statistic_data_typeFK
        WHERE sd.del = 'no'
          AND sd.statistic_data_typeFK IN ({{NUMERIC_DATA_TYPE_LIST}})
          AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
          AND s.object_typeFK = 3
          AND tt.sportFK = {{SPORT_ID}}
          AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
          -- AND t.tournament_templateFK = <tournament_template_id>
          AND sd.value IS NOT NULL
          AND TRIM(sd.value) <> ''
          -- The mirror of GLOBAL-DQ-057, and inventoried separately from the event layer
          -- because a field is declared numeric per statistic type, not across the two layers.
          --
          -- The sign is part of the number, as in GLOBAL-DQ-076. A Comp.Rank field carrying a
          -- score against a reference holds the positive direction as readily as the negative
          -- one - measured on Golf, 9019 of that field's 340991 values are written +N, and a
          -- pattern accepting only the minus reported every one of them as text.
          AND TRIM(sd.value) NOT REGEXP '^[-+]?[0-9]+([.,][0-9]+)?$'
    ) y
    GROUP BY
        y.check_type,
        y.statistic_id,
        y.statistic_name,
        y.template_name,
        y.tournament_name
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count,
    1 AS sort_order
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
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND sd.value IS NOT NULL
  AND TRIM(sd.value) <> ''

ORDER BY sort_order, affected_count DESC, statistic_id;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-095
    -- Name - COMP.RANK_RESULTS_RANK_DUPLICATE_WITHOUT_COMMENT
    -- What it does: Finds a Comp.Rank place held by more participants than its teams field athletes, with no Comment to explain it, while the place that sharing consumes is still awarded - so the place is occupied twice over rather than being a joint place the ranking stops at.
    CASE
        WHEN x.duplicated_rank_count = 1 THEN 'ONE_RANK_HELD_TWICE'
        ELSE 'SEVERAL_RANKS_HELD_TWICE'
    END AS check_type,
    x.statistic_id,
    x.statistic_name,
    x.template_name,
    x.tournament_name,
    x.holders_per_place,
    x.duplicated_rank_count,
    x.duplicated_ranks,
    NULL AS eligible_count,
    0 AS sort_order
-- The statistic-layer twin of GLOBAL-DQ-021, which reads the event layer and cannot see a
-- Comp.Rank. The layer forces two differences, and both are what keep it usable.
-- An event enters a team as one participant while a Comp.Rank lists it athlete by athlete,
-- so a place is legitimately held by as many participants as a team fields. That number is
-- read from the statistic itself - the largest team the Team data field assigns, and one
-- where it assigns none - rather than assumed, which is what stops every relay from being
-- reported.
-- And a Comp.Rank ranks a whole competition rather than one contest, so it stops ranking
-- individually where the play-offs begin and enters everyone below as one joint place. A
-- place shared by k entries consumes the k-1 places under it, so a well-formed sharing
-- leaves them empty and the next place stored is R+k; a place stored inside that span is the
-- contradiction. Without that condition the check reports the convention and buries the
-- defect inside it - and a whole second sequence of places, which is what a statistic
-- holding two competitions at once looks like, is exactly what the condition finds.
-- Every subquery carries the sport filter rather than inheriting it from the outer join,
-- because the participant and data shards are shared by every sport and a subquery without
-- it scans all of them.
FROM (
    SELECT
        s.id AS statistic_id,
        s.name AS statistic_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        v.holders_per_place,
        COUNT(*) AS duplicated_rank_count,
        GROUP_CONCAT(CONCAT('rank ', v.rank_value, ' x', v.holder_count)
                     ORDER BY v.rank_value SEPARATOR ', ') AS duplicated_ranks
    FROM (
        SELECT DISTINCT
            r.statistic_id,
            r.rank_value,
            r.holder_count,
            h.holders_per_place
        FROM (
            SELECT
                sp.statisticFK AS statistic_id,
                CAST(TRIM(sd.value) AS SIGNED) AS rank_value,
                COUNT(DISTINCT sp.id) AS holder_count
            FROM statistic sx
            JOIN tournament tx ON tx.id = sx.objectFK AND tx.del = 'no'
            JOIN tournament_template ttx ON ttx.id = tx.tournament_templateFK AND ttx.del = 'no'
            JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = sx.id AND sp.del = 'no'
            JOIN statistic_data{{SHARD_ID}} sd ON sd.statistic_participants{{SHARD_ID}}FK = sp.id
                 AND sd.statistic_data_typeFK = {{DATA_RANK_TYPE_ID}}
                 AND sd.del = 'no'
                 AND sd.value IS NOT NULL
                 AND TRIM(sd.value) REGEXP '^[1-9][0-9]*$'
            WHERE sx.del = 'no'
              AND sx.statistic_typeFK = {{STATISTIC_TYPE_ID}}
              AND sx.object_typeFK = 3
              AND ttx.sportFK = {{SPORT_ID}}
              AND (ttx.name IS NULL OR ttx.name NOT LIKE '%(IOC)%')
              -- AND tx.tournament_templateFK = <tournament_template_id>
              AND NOT EXISTS (
                  SELECT 1
                  FROM statistic_data{{SHARD_ID}} sc
                  WHERE sc.statistic_participants{{SHARD_ID}}FK = sp.id
                    AND sc.statistic_data_typeFK = {{DATA_COMMENT_TYPE_ID}}
                    AND sc.del = 'no'
                    AND sc.value IS NOT NULL
                    AND TRIM(sc.value) <> ''
              )
            GROUP BY sp.statisticFK, CAST(TRIM(sd.value) AS SIGNED)
        ) r
        JOIN (
            SELECT
                sy.id AS statistic_id,
                COALESCE(MAX(tm.team_size), 1) AS holders_per_place
            FROM statistic sy
            JOIN tournament ty ON ty.id = sy.objectFK AND ty.del = 'no'
            JOIN tournament_template tty ON tty.id = ty.tournament_templateFK AND tty.del = 'no'
            LEFT JOIN (
                SELECT
                    sp3.statisticFK AS statistic_id,
                    sd3.value AS team_id,
                    COUNT(DISTINCT sp3.id) AS team_size
                FROM statistic sz
                JOIN tournament tz ON tz.id = sz.objectFK AND tz.del = 'no'
                JOIN tournament_template ttz ON ttz.id = tz.tournament_templateFK AND ttz.del = 'no'
                JOIN statistic_participants{{SHARD_ID}} sp3 ON sp3.statisticFK = sz.id AND sp3.del = 'no'
                JOIN statistic_data{{SHARD_ID}} sd3 ON sd3.statistic_participants{{SHARD_ID}}FK = sp3.id
                     AND sd3.statistic_data_typeFK = {{DATA_TEAM_TYPE_ID}}
                     AND sd3.del = 'no'
                     AND sd3.value IS NOT NULL
                     AND TRIM(sd3.value) <> ''
                WHERE sz.del = 'no'
                  AND sz.statistic_typeFK = {{STATISTIC_TYPE_ID}}
                  AND sz.object_typeFK = 3
                  AND ttz.sportFK = {{SPORT_ID}}
                GROUP BY sp3.statisticFK, sd3.value
            ) tm ON tm.statistic_id = sy.id
            WHERE sy.del = 'no'
              AND sy.statistic_typeFK = {{STATISTIC_TYPE_ID}}
              AND sy.object_typeFK = 3
              AND tty.sportFK = {{SPORT_ID}}
            GROUP BY sy.id
        ) h ON h.statistic_id = r.statistic_id
        JOIN (
            SELECT DISTINCT
                sp4.statisticFK AS statistic_id,
                CAST(TRIM(sd4.value) AS SIGNED) AS rank_value
            FROM statistic sw
            JOIN tournament tw ON tw.id = sw.objectFK AND tw.del = 'no'
            JOIN tournament_template ttw ON ttw.id = tw.tournament_templateFK AND ttw.del = 'no'
            JOIN statistic_participants{{SHARD_ID}} sp4 ON sp4.statisticFK = sw.id AND sp4.del = 'no'
            JOIN statistic_data{{SHARD_ID}} sd4 ON sd4.statistic_participants{{SHARD_ID}}FK = sp4.id
                 AND sd4.statistic_data_typeFK = {{DATA_RANK_TYPE_ID}}
                 AND sd4.del = 'no'
                 AND sd4.value IS NOT NULL
                 AND TRIM(sd4.value) REGEXP '^[1-9][0-9]*$'
            WHERE sw.del = 'no'
              AND sw.statistic_typeFK = {{STATISTIC_TYPE_ID}}
              AND sw.object_typeFK = 3
              AND ttw.sportFK = {{SPORT_ID}}
        ) allr ON allr.statistic_id = r.statistic_id
              AND allr.rank_value > r.rank_value
              AND allr.rank_value < r.rank_value + (r.holder_count DIV h.holders_per_place)
        WHERE r.holder_count > h.holders_per_place
    ) v
    JOIN statistic s ON s.id = v.statistic_id AND s.del = 'no'
    JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    GROUP BY s.id, s.name, tt.name, t.name, v.holders_per_place
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count,
    1 AS sort_order
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = s.id AND sp.del = 'no'
JOIN statistic_data{{SHARD_ID}} sd ON sd.statistic_participants{{SHARD_ID}}FK = sp.id
     AND sd.statistic_data_typeFK = {{DATA_RANK_TYPE_ID}}
     AND sd.del = 'no'
     AND sd.value IS NOT NULL
     AND TRIM(sd.value) REGEXP '^[1-9][0-9]*$'
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-098
    -- Name - COMP.RANK_TEAM_FIELD_UNUSED_IN_TEAM_STATISTIC
    -- What it does: Finds Comp.Rank where every athlete shares a place with the same number of others and none carries a Team value, so teams of that size are scored without recording which team each athlete belongs to.
    'TEAM_FIELD_UNUSED_FOR_WHOLE_FIELD' AS check_type,
    x.statistic_id,
    x.statistic_name,
    x.template_name,
    x.tournament_name,
    x.athlete_count,
    x.shared_place_count,
    x.holders_per_shared_place,
    x.shared_places,
    NULL AS eligible_count,
    0 AS sort_order
-- Several athletes on one place is what a team competition looks like from the athlete side,
-- and the Team data field is what says which team each of them was on. A statistic showing
-- the first without the second has lost that link entirely, and the loss is invisible to
-- GLOBAL-DQ-064, whose eligible population is the statistic that uses the field at all - a
-- statistic using it for nobody is excluded there rather than reported.
-- It also explains a finding rather than repeating one: GLOBAL-DQ-095 reads how many
-- participants a place may legitimately hold from this same field, so where the field is
-- unused it can only assume one and reports every team member beyond the first. Populating
-- the field is what fixes both, which is why this names the cause rather than loosening the
-- other check.
-- Restricted to athlete participants, because a statistic ranking teams shares a place by a
-- different mechanism - the joint place a competition stops ranking at - and a team does not
-- belong to a team.
-- What is asserted is deliberately narrow: every athlete in a group, and every group the
-- same size. That is a relay or team format and nothing else. Sharing that covers only part
-- of the field, or covers it in ragged groups, is the joint placing an elimination round
-- produces - everyone knocked out in one round entered on one place - and reporting it here
-- would name a convention rather than a missing link, which is the mistake this check exists
-- to avoid making on behalf of GLOBAL-DQ-095.
FROM (
    SELECT
        st.statistic_id,
        st.statistic_name,
        st.template_name,
        st.tournament_name,
        st.athlete_count,
        COUNT(*) AS shared_place_count,
        MIN(rk.holder_count) AS holders_per_shared_place,
        SUBSTRING(GROUP_CONCAT(CONCAT('rank ', rk.rank_value, ' x', rk.holder_count)
                               ORDER BY rk.rank_value SEPARATOR ', '), 1, 200) AS shared_places
    FROM (
        SELECT
            sp.statisticFK AS statistic_id,
            CAST(TRIM(sd.value) AS SIGNED) AS rank_value,
            COUNT(DISTINCT sp.id) AS holder_count
        FROM statistic sx
        JOIN tournament tx ON tx.id = sx.objectFK AND tx.del = 'no'
        JOIN tournament_template ttx ON ttx.id = tx.tournament_templateFK AND ttx.del = 'no'
        JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = sx.id AND sp.del = 'no'
        JOIN participant px ON px.id = sp.participantFK AND px.del = 'no' AND px.type = 'athlete'
        JOIN statistic_data{{SHARD_ID}} sd ON sd.statistic_participants{{SHARD_ID}}FK = sp.id
             AND sd.statistic_data_typeFK = {{DATA_RANK_TYPE_ID}}
             AND sd.del = 'no'
             AND sd.value IS NOT NULL
             AND TRIM(sd.value) REGEXP '^[1-9][0-9]*$'
        WHERE sx.del = 'no'
          AND sx.statistic_typeFK = {{STATISTIC_TYPE_ID}}
          AND sx.object_typeFK = 3
          AND ttx.sportFK = {{SPORT_ID}}
          AND (ttx.name IS NULL OR ttx.name NOT LIKE '%(IOC)%')
          -- AND tx.tournament_templateFK = <tournament_template_id>
        GROUP BY sp.statisticFK, CAST(TRIM(sd.value) AS SIGNED)
        HAVING COUNT(DISTINCT sp.id) > 1
    ) rk
    JOIN (
        SELECT
            sy.id AS statistic_id,
            sy.name AS statistic_name,
            tty.name AS template_name,
            ty.name AS tournament_name,
            COUNT(DISTINCT sp2.id) AS athlete_count,
            COUNT(DISTINCT CASE WHEN sdt.value IS NOT NULL AND TRIM(sdt.value) <> ''
                                THEN sp2.id END) AS team_users
        FROM statistic sy
        JOIN tournament ty ON ty.id = sy.objectFK AND ty.del = 'no'
        JOIN tournament_template tty ON tty.id = ty.tournament_templateFK AND tty.del = 'no'
        JOIN statistic_participants{{SHARD_ID}} sp2 ON sp2.statisticFK = sy.id AND sp2.del = 'no'
        JOIN participant py ON py.id = sp2.participantFK AND py.del = 'no' AND py.type = 'athlete'
        LEFT JOIN statistic_data{{SHARD_ID}} sdt ON sdt.statistic_participants{{SHARD_ID}}FK = sp2.id
             AND sdt.statistic_data_typeFK = {{DATA_TEAM_TYPE_ID}}
             AND sdt.del = 'no'
        WHERE sy.del = 'no'
          AND sy.statistic_typeFK = {{STATISTIC_TYPE_ID}}
          AND sy.object_typeFK = 3
          AND tty.sportFK = {{SPORT_ID}}
          AND (tty.name IS NULL OR tty.name NOT LIKE '%(IOC)%')
          -- AND ty.tournament_templateFK = <tournament_template_id>
        GROUP BY sy.id, sy.name, tty.name, ty.name
        HAVING COUNT(DISTINCT CASE WHEN sdt.value IS NOT NULL AND TRIM(sdt.value) <> ''
                                   THEN sp2.id END) = 0
    ) st ON st.statistic_id = rk.statistic_id
    GROUP BY st.statistic_id, st.statistic_name, st.template_name, st.tournament_name, st.athlete_count
    HAVING COUNT(DISTINCT rk.holder_count) = 1
       AND COUNT(*) * MIN(rk.holder_count) = st.athlete_count
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count,
    1 AS sort_order
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = s.id AND sp.del = 'no'
JOIN participant p ON p.id = sp.participantFK AND p.del = 'no' AND p.type = 'athlete'
JOIN statistic_data{{SHARD_ID}} sd ON sd.statistic_participants{{SHARD_ID}}FK = sp.id
     AND sd.statistic_data_typeFK = {{DATA_RANK_TYPE_ID}}
     AND sd.del = 'no'
     AND sd.value IS NOT NULL
     AND TRIM(sd.value) REGEXP '^[1-9][0-9]*$'
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, shared_place_count DESC;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-099
    -- Name - COMP.RANK_VALUE_BELONGS_TO_ANOTHER_FIELD
    -- What it does: Finds a Comp.Rank value that is exactly what another field owns: a medal word stored outside the Medal field, or a plain place number stored inside it.
    CASE
        WHEN sd.statistic_data_typeFK = {{DATA_MEDAL_TYPE_ID}} THEN 'RANK_NUMBER_IN_MEDAL_FIELD'
        ELSE 'MEDAL_WORD_OUTSIDE_MEDAL_FIELD'
    END AS check_type,
    sp.id AS statistic_participants_id,
    s.id AS statistic_id,
    s.name AS statistic_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    p.name AS participant_name,
    sd.statistic_data_typeFK AS data_type_id,
    COALESCE(sdt.name, CAST(sd.statistic_data_typeFK AS CHAR)) AS data_type_name,
    sd.value AS stored_value,
    NULL AS eligible_count,
    0 AS sort_order
-- Every value check in this catalogue asks whether a value fits the field holding it -
-- GLOBAL-DQ-012 for Rank, -027 for Medal, -057 for Comment, -077 for a numeric field. None
-- of them asks whose value it is, so a medal word in a rank field is reported as "not a
-- rank" and the reader is left to notice that it is a perfectly good medal one column away.
-- That difference is the difference between correcting a value and moving it, which is why
-- this is worth its own statement rather than another shape test.
-- Only exact matches count, on the closed vocabulary the medal checks already assert
-- everywhere: gold, silver and bronze, compared after trimming and lowercasing. A field
-- whose text merely contains one of the words is left alone, because a free-text comment
-- legitimately might.
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
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND sd.value IS NOT NULL
  AND TRIM(sd.value) <> ''
  AND (
      (sd.statistic_data_typeFK <> {{DATA_MEDAL_TYPE_ID}}
       AND LOWER(TRIM(sd.value)) IN ('gold', 'silver', 'bronze'))
      OR
      (sd.statistic_data_typeFK = {{DATA_MEDAL_TYPE_ID}}
       AND TRIM(sd.value) REGEXP '^[0-9]+$')
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT sd.id) AS eligible_count,
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
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND sd.value IS NOT NULL
  AND TRIM(sd.value) <> ''

ORDER BY sort_order;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-100
    -- Name - COMP.RANK_DISCIPLINE_NOT_CONTESTED_IN_TOURNAMENT
    -- What it does: Finds Comp.Rank claiming a discipline that no event under its own tournament was contested in.
    'DISCIPLINE_NOT_CONTESTED_IN_TOURNAMENT' AS check_type,
    x.statistic_id,
    x.statistic_name,
    x.template_name,
    x.tournament_name,
    x.claimed_disciplines,
    x.contested_disciplines,
    NULL AS eligible_count,
    0 AS sort_order
-- Asked against the tournament's own events rather than against the statistic's name, which
-- is what makes it global: a name-to-discipline map has to be written per sport and is the
-- kind of parameter GLOBAL_DQ/README.md warns turns one template into a configuration
-- exercise. The events are the record of what was actually contested, so the statistic is
-- measured against its own competition and no vocabulary is needed.
-- A tournament running several disciplines is not reported for the difference between them:
-- the claim only has to appear somewhere among the events. What is reported is a claim no
-- event supports at all. A tournament whose events carry no discipline is outside the
-- eligible population rather than a finding, because there is nothing to measure against -
-- that gap is GLOBAL-DQ-015.
FROM (
    SELECT
        s.id AS statistic_id,
        s.name AS statistic_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        GROUP_CONCAT(DISTINCT dc.name ORDER BY dc.name SEPARATOR ', ') AS claimed_disciplines,
        (SELECT GROUP_CONCAT(DISTINCT de.name ORDER BY de.name SEPARATOR ', ')
           FROM tournament_stage ts2
           JOIN event e2 ON e2.tournament_stageFK = ts2.id AND e2.del = 'no'
           JOIN object_discipline od2 ON od2.object_typeFK = 5 AND od2.objectFK = e2.id AND od2.del = 'no'
           JOIN discipline de ON de.id = od2.disciplineFK AND de.del = 'no'
          WHERE ts2.tournamentFK = t.id AND ts2.del = 'no'
        ) AS contested_disciplines,
        SUM(CASE WHEN NOT EXISTS (
                SELECT 1
                FROM tournament_stage ts3
                JOIN event e3 ON e3.tournament_stageFK = ts3.id AND e3.del = 'no'
                JOIN object_discipline od3 ON od3.object_typeFK = 5 AND od3.objectFK = e3.id AND od3.del = 'no'
                WHERE ts3.tournamentFK = t.id AND ts3.del = 'no'
                  AND od3.disciplineFK = od.disciplineFK
            ) THEN 1 ELSE 0 END) AS unsupported_claims
    FROM statistic s
    JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN object_discipline od ON od.object_typeFK = 83 AND od.objectFK = s.id AND od.del = 'no'
    JOIN discipline dc ON dc.id = od.disciplineFK AND dc.del = 'no'
    WHERE s.del = 'no'
      AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
      AND s.object_typeFK = 3
      AND tt.sportFK = {{SPORT_ID}}
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      -- AND t.tournament_templateFK = <tournament_template_id>
      AND EXISTS (
          SELECT 1
          FROM tournament_stage ts4
          JOIN event e4 ON e4.tournament_stageFK = ts4.id AND e4.del = 'no'
          JOIN object_discipline od4 ON od4.object_typeFK = 5 AND od4.objectFK = e4.id AND od4.del = 'no'
          WHERE ts4.tournamentFK = t.id AND ts4.del = 'no'
      )
    GROUP BY s.id, s.name, tt.name, t.name, t.id
    HAVING SUM(CASE WHEN NOT EXISTS (
                SELECT 1
                FROM tournament_stage ts5
                JOIN event e5 ON e5.tournament_stageFK = ts5.id AND e5.del = 'no'
                JOIN object_discipline od5 ON od5.object_typeFK = 5 AND od5.objectFK = e5.id AND od5.del = 'no'
                WHERE ts5.tournamentFK = t.id AND ts5.del = 'no'
                  AND od5.disciplineFK = od.disciplineFK
            ) THEN 1 ELSE 0 END) > 0
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count,
    1 AS sort_order
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN object_discipline od ON od.object_typeFK = 83 AND od.objectFK = s.id AND od.del = 'no'
JOIN discipline dc ON dc.id = od.disciplineFK AND dc.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND EXISTS (
      SELECT 1
      FROM tournament_stage ts4
      JOIN event e4 ON e4.tournament_stageFK = ts4.id AND e4.del = 'no'
      JOIN object_discipline od4 ON od4.object_typeFK = 5 AND od4.objectFK = e4.id AND od4.del = 'no'
      WHERE ts4.tournamentFK = t.id AND ts4.del = 'no'
  )

ORDER BY sort_order;

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-101
    -- Name - COMP.RANK_SETTINGS_EVENT_ID_INVALID_OR_OUTSIDE_TOURNAMENT
    -- What it does: Finds Comp.Rank whose Event id config does not resolve to an event under its own tournament, separating a value that is not a number, one naming no event, and one naming an event another tournament owns.
    CASE
        WHEN x.not_numeric_count > 0 THEN 'EVENT_ID_NOT_NUMERIC'
        WHEN x.no_active_event_count > 0 THEN 'EVENT_ID_NO_ACTIVE_EVENT'
        ELSE 'EVENT_ID_OUTSIDE_TOURNAMENT'
    END AS check_type,
    x.statistic_id,
    x.statistic_name,
    x.template_name,
    x.tournament_name,
    x.invalid_config_count,
    x.sample_values,
    NULL AS eligible_count,
    0 AS sort_order
-- The Event id is the only path from a Comp.Rank statistic to the event it summarises, and
-- every check that walks it joins through it. A join drops the row it cannot match, so an id
-- naming nothing and an id naming another tournament's event are both invisible to those
-- checks: they narrow the population silently instead of reporting it. That is what makes
-- this worth asserting separately rather than trusting the joins to surface it.
-- Three defects, one audited object. They are separated by check_type rather than by CheckID
-- because they are one question - does this id point where it claims - and a statistic
-- carrying two kinds at once should be one row rather than two.
FROM (
    SELECT
        s.id AS statistic_id,
        s.name AS statistic_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        COUNT(*) AS invalid_config_count,
        SUM(CASE WHEN TRIM(sc.value) NOT REGEXP '^[0-9]+$' THEN 1 ELSE 0 END) AS not_numeric_count,
        SUM(CASE WHEN TRIM(sc.value) REGEXP '^[0-9]+$' AND e.id IS NULL THEN 1 ELSE 0 END) AS no_active_event_count,
        SUBSTRING(GROUP_CONCAT(DISTINCT LEFT(TRIM(sc.value), 20) ORDER BY TRIM(sc.value) SEPARATOR ' | '), 1, 100) AS sample_values
    FROM statistic_config sc
    JOIN statistic s ON s.id = sc.statisticFK AND s.del = 'no'
         AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
         AND s.object_typeFK = 3
    JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    LEFT JOIN event e ON TRIM(sc.value) REGEXP '^[0-9]+$'
         AND e.id = CAST(TRIM(sc.value) AS UNSIGNED) AND e.del = 'no'
    LEFT JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    WHERE sc.del = 'no'
      AND sc.statistic_data_typeFK = {{CONFIG_EVENT_ID_TYPE_ID}}
      AND TRIM(COALESCE(sc.value, '')) <> ''
      AND tt.sportFK = {{SPORT_ID}}
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      -- AND t.tournament_templateFK = <tournament_template_id>
      AND (
            TRIM(sc.value) NOT REGEXP '^[0-9]+$'
         OR e.id IS NULL
         OR ts.tournamentFK <> s.objectFK
          )
    GROUP BY s.id, s.name, tt.name, t.name
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count,
    1 AS sort_order
FROM statistic_config sc
JOIN statistic s ON s.id = sc.statisticFK AND s.del = 'no'
     AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
     AND s.object_typeFK = 3
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE sc.del = 'no'
  AND sc.statistic_data_typeFK = {{CONFIG_EVENT_ID_TYPE_ID}}
  AND TRIM(COALESCE(sc.value, '')) <> ''
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, statistic_id;

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-103
    -- Name - COMP.RANK_PARTICIPANT_DUPLICATE_IN_STATISTIC
    -- What it does: Finds Comp.Rank holding the same participant twice, so one competitor occupies a place in the ranking two times over.
    'Comp_Rank_Participant_Duplicate' AS check_type,
    x.statistic_id,
    x.statistic_name,
    x.template_name,
    x.tournament_name,
    x.affected_participant_count,
    x.duplicated_row_count,
    x.sample_group,
    NULL AS eligible_count,
    0 AS sort_order
-- Not the question GLOBAL-DQ-060 asks. That one groups by statistic_participants id and data
-- type, so it sees several data rows hanging off one participant row. This sees one
-- participant holding two participant rows in the same ranking, which that grouping cannot
-- reach: each of the two rows can carry a perfectly well-formed single set of data.
FROM (
    SELECT
        s.id AS statistic_id,
        s.name AS statistic_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        COUNT(*) AS affected_participant_count,
        SUM(g.row_count) AS duplicated_row_count,
        MIN(CONCAT('participant=', g.participantFK, ' rows=', g.row_count)) AS sample_group
    FROM (
        SELECT sp.statisticFK, sp.participantFK, COUNT(*) AS row_count
        FROM statistic_participants{{SHARD_ID}} sp
        JOIN statistic s2 ON s2.id = sp.statisticFK AND s2.del = 'no'
             AND s2.statistic_typeFK = {{STATISTIC_TYPE_ID}}
             AND s2.object_typeFK = 3
        JOIN tournament t2 ON t2.id = s2.objectFK AND t2.del = 'no'
        JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
             AND tt2.sportFK = {{SPORT_ID}}
        WHERE sp.del = 'no'
          AND (tt2.name IS NULL OR tt2.name NOT LIKE '%(IOC)%')
          -- AND t2.tournament_templateFK = <tournament_template_id>
        GROUP BY sp.statisticFK, sp.participantFK
        HAVING COUNT(*) > 1
    ) g
    JOIN statistic s ON s.id = g.statisticFK AND s.del = 'no'
    JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    GROUP BY s.id, s.name, tt.name, t.name
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count,
    1 AS sort_order
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND EXISTS (
      SELECT 1 FROM statistic_participants{{SHARD_ID}} sp2
      WHERE sp2.statisticFK = s.id AND sp2.del = 'no'
  )

ORDER BY sort_order, statistic_id;

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-105
    -- Name - COMP.RANK_SETTINGS_SCALAR_DUPLICATE_ROWS
    -- What it does: Finds Comp.Rank holding more than one config row for a setting that takes one value - start date, end date or gender - separating a repeat of the same value from two that contradict each other.
    CASE
        WHEN x.conflicting_groups > 0 THEN 'SETTINGS_CONFLICTING_VALUES'
        ELSE 'SETTINGS_DUPLICATE_IDENTICAL'
    END AS check_type,
    x.statistic_id,
    x.statistic_name,
    x.template_name,
    x.tournament_name,
    x.duplicate_groups,
    x.sample_group,
    NULL AS eligible_count,
    0 AS sort_order
-- The Event id config is deliberately outside the scope of this check. It is the one
-- setting a statistic may legitimately hold several times, naming each event the ranking
-- covers, so including it would report the normal shape of every multi-event statistic.
-- Whether those ids point anywhere is GLOBAL-DQ-101's question, not this one.
-- Two identical rows and two contradicting rows are not the same defect: the first is
-- redundant storage a reader can ignore, the second means no reader can tell which value
-- the statistic actually carries. They are separated rather than counted together.
FROM (
    SELECT
        s.id AS statistic_id,
        s.name AS statistic_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        COUNT(*) AS duplicate_groups,
        SUM(CASE WHEN g.distinct_values > 1 THEN 1 ELSE 0 END) AS conflicting_groups,
        MIN(CONCAT('type=', g.statistic_data_typeFK, ' rows=', g.row_count, ' values=', g.value_list)) AS sample_group
    FROM (
        SELECT
            sc.statisticFK,
            sc.statistic_data_typeFK,
            COUNT(*) AS row_count,
            COUNT(DISTINCT TRIM(sc.value)) AS distinct_values,
            SUBSTRING(GROUP_CONCAT(DISTINCT TRIM(sc.value) ORDER BY TRIM(sc.value) SEPARATOR '|'), 1, 60) AS value_list
        FROM statistic_config sc
        JOIN statistic s2 ON s2.id = sc.statisticFK AND s2.del = 'no'
             AND s2.statistic_typeFK = {{STATISTIC_TYPE_ID}}
             AND s2.object_typeFK = 3
        JOIN tournament t2 ON t2.id = s2.objectFK AND t2.del = 'no'
        JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
             AND tt2.sportFK = {{SPORT_ID}}
        WHERE sc.del = 'no'
          AND sc.statistic_data_typeFK IN (
              {{CONFIG_START_DATE_TYPE_ID}}, {{CONFIG_END_DATE_TYPE_ID}}, {{CONFIG_GENDER_TYPE_ID}})
          AND (tt2.name IS NULL OR tt2.name NOT LIKE '%(IOC)%')
          -- AND t2.tournament_templateFK = <tournament_template_id>
        GROUP BY sc.statisticFK, sc.statistic_data_typeFK
        HAVING COUNT(*) > 1
    ) g
    JOIN statistic s ON s.id = g.statisticFK AND s.del = 'no'
    JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    GROUP BY s.id, s.name, tt.name, t.name
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count,
    1 AS sort_order
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND EXISTS (
      SELECT 1 FROM statistic_config sc2
      WHERE sc2.statisticFK = s.id AND sc2.del = 'no'
        AND sc2.statistic_data_typeFK IN (
            {{CONFIG_START_DATE_TYPE_ID}}, {{CONFIG_END_DATE_TYPE_ID}}, {{CONFIG_GENDER_TYPE_ID}})
  )

ORDER BY sort_order, statistic_id;

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-106
    -- Name - COMP.RANK_UNEXPECTED_OWNER_TYPE
    -- What it does: Finds Comp.Rank hanging off an owner level other than the one the sport is confirmed to use.
    'Comp_Rank_Unexpected_Owner_Type' AS check_type,
    s.id AS statistic_id,
    s.name AS statistic_name,
    s.object_typeFK AS owner_type_found,
    s.objectFK AS owner_object_id,
    tt.name AS template_name,
    NULL AS eligible_count,
    0 AS sort_order
-- Reached through both owner paths rather than through the tournament alone, which is the
-- whole point: a statistic on the wrong level cannot be found by a statement that joins
-- through the level it is supposed to be on. Every other Comp.Rank check in this file
-- anchors on object_typeFK = 3 and therefore cannot see this at all.
FROM statistic s
LEFT JOIN tournament t3 ON s.object_typeFK = 3 AND t3.id = s.objectFK AND t3.del = 'no'
LEFT JOIN tournament_stage ts4 ON s.object_typeFK = 4 AND ts4.id = s.objectFK AND ts4.del = 'no'
LEFT JOIN tournament t4 ON t4.id = ts4.tournamentFK AND t4.del = 'no'
JOIN tournament_template tt ON tt.id = COALESCE(t3.tournament_templateFK, t4.tournament_templateFK)
     AND tt.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
  AND s.object_typeFK <> {{STATISTIC_OWNER_TYPE_ID}}

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count,
    1 AS sort_order
FROM statistic s
LEFT JOIN tournament t3 ON s.object_typeFK = 3 AND t3.id = s.objectFK AND t3.del = 'no'
LEFT JOIN tournament_stage ts4 ON s.object_typeFK = 4 AND ts4.id = s.objectFK AND ts4.del = 'no'
LEFT JOIN tournament t4 ON t4.id = ts4.tournamentFK AND t4.del = 'no'
JOIN tournament_template tt ON tt.id = COALESCE(t3.tournament_templateFK, t4.tournament_templateFK)
     AND tt.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>

ORDER BY sort_order, statistic_id;

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-110
    -- Name - COMP.RANK_DISCIPLINE_CONTRADICTS_LINKED_EVENT
    -- What it does: Finds Comp.Rank whose claimed discipline was contested by none of the events it names through the Event id config, so the two paths disagree about the same competition.
    'Comp_Rank_Discipline_Contradicts_Linked_Event' AS check_type,
    x.statistic_id,
    x.statistic_name,
    x.template_name,
    x.tournament_name,
    x.claimed_disciplines,
    x.linked_event_disciplines,
    NULL AS eligible_count,
    0 AS sort_order
-- Narrower than GLOBAL-DQ-100 and asking a different question. That one measures the claim
-- against everything the whole tournament contested, which is the loosest possible test and
-- the only one available when no Event id is recorded. Where the ids are recorded the
-- statistic names its own events, and the claim can be measured against those instead - a
-- statistic claiming Racing whose linked events are all Freestyle passes the tournament-wide
-- test whenever that tournament also ran Racing somewhere.
-- Eligibility requires both paths. A statistic with no discipline relation is GLOBAL-DQ-023
-- and one whose Event id points nowhere is GLOBAL-DQ-101; neither is this.
FROM (
    SELECT
        s.id AS statistic_id,
        s.name AS statistic_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        SUBSTRING(GROUP_CONCAT(DISTINCT dc.name ORDER BY dc.name SEPARATOR ', '), 1, 80) AS claimed_disciplines,
        SUBSTRING(GROUP_CONCAT(DISTINCT de.name ORDER BY de.name SEPARATOR ', '), 1, 80) AS linked_event_disciplines,
        MAX(CASE WHEN od.disciplineFK = ode.disciplineFK THEN 1 ELSE 0 END) AS supported
    FROM statistic s
    JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = {{SPORT_ID}}
    JOIN object_discipline od ON od.object_typeFK = 83 AND od.objectFK = s.id AND od.del = 'no'
    JOIN discipline dc ON dc.id = od.disciplineFK AND dc.del = 'no'
    JOIN statistic_config sc ON sc.statisticFK = s.id AND sc.del = 'no'
         AND sc.statistic_data_typeFK = {{CONFIG_EVENT_ID_TYPE_ID}}
         AND TRIM(COALESCE(sc.value, '')) <> ''
         AND TRIM(sc.value) REGEXP '^[0-9]+$'
    JOIN event e ON e.id = CAST(TRIM(sc.value) AS UNSIGNED) AND e.del = 'no'
    JOIN object_discipline ode ON ode.object_typeFK = 5 AND ode.objectFK = e.id AND ode.del = 'no'
    JOIN discipline de ON de.id = ode.disciplineFK AND de.del = 'no'
    WHERE s.del = 'no'
      AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
      AND s.object_typeFK = 3
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      -- AND t.tournament_templateFK = <tournament_template_id>
    GROUP BY s.id, s.name, tt.name, t.name
    HAVING MAX(CASE WHEN od.disciplineFK = ode.disciplineFK THEN 1 ELSE 0 END) = 0
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count,
    1 AS sort_order
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = {{SPORT_ID}}
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND EXISTS (
      SELECT 1 FROM object_discipline od2
      WHERE od2.object_typeFK = 83 AND od2.objectFK = s.id AND od2.del = 'no'
  )
  AND EXISTS (
      SELECT 1 FROM statistic_config sc2
      JOIN event e2 ON e2.id = CAST(TRIM(sc2.value) AS UNSIGNED) AND e2.del = 'no'
      JOIN object_discipline ode2 ON ode2.object_typeFK = 5 AND ode2.objectFK = e2.id AND ode2.del = 'no'
      WHERE sc2.statisticFK = s.id AND sc2.del = 'no'
        AND sc2.statistic_data_typeFK = {{CONFIG_EVENT_ID_TYPE_ID}}
        AND TRIM(COALESCE(sc2.value, '')) <> ''
        AND TRIM(sc2.value) REGEXP '^[0-9]+$'
  )

ORDER BY sort_order, statistic_id;

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-113
    -- Name - COMP.RANK_PARTICIPANT_TYPE_MIXED
    -- What it does: Finds Comp.Rank holding participants of more than one kind, so one place sequence ranks teams against individuals.
    'Comp_Rank_Participant_Type_Mixed' AS check_type,
    x.statistic_id,
    x.statistic_name,
    x.template_name,
    x.tournament_name,
    x.types_held,
    x.distinct_types,
    NULL AS eligible_count,
    0 AS sort_order
-- A ranking answers one question about one kind of competitor, so two kinds under one place
-- sequence means either the ranking is two rankings or somebody is counted in both. Asked
-- without naming which kinds are legitimate, which is what keeps it global: the sport's own
-- participant vocabulary is GLOBAL-DQ-104's business, and a sport fielding both teams and
-- individuals is normal - what is not normal is one statistic holding both.
FROM (
    SELECT
        s.id AS statistic_id,
        s.name AS statistic_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        COUNT(DISTINCT p.type) AS distinct_types,
        SUBSTRING(GROUP_CONCAT(DISTINCT p.type ORDER BY p.type SEPARATOR ', '), 1, 60) AS types_held
    FROM statistic s
    JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = {{SPORT_ID}}
    JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = s.id AND sp.del = 'no'
    JOIN participant p ON p.id = sp.participantFK AND p.del = 'no'
    WHERE s.del = 'no'
      AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
      AND s.object_typeFK = 3
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      -- AND t.tournament_templateFK = <tournament_template_id>
    GROUP BY s.id, s.name, tt.name, t.name
    HAVING COUNT(DISTINCT p.type) > 1
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count,
    1 AS sort_order
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = {{SPORT_ID}}
JOIN statistic_participants{{SHARD_ID}} sp2 ON sp2.statisticFK = s.id AND sp2.del = 'no'
JOIN participant p2 ON p2.id = sp2.participantFK AND p2.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, statistic_id;

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-115
    -- Name - COMP.RANK_PARTICIPANT_REFERENCE_INVALID
    -- What it does: Finds Comp.Rank participants whose reference resolves to no participant row, or to a soft-deleted one, separating the two, with the data rows still attached to them.
    CASE
        WHEN p.id IS NULL THEN 'PARTICIPANT_REFERENCE_MISSING'
        ELSE                   'PARTICIPANT_REFERENCE_SOFT_DELETED'
    END AS check_type,
    sp.id AS statistic_participants_id,
    s.id AS statistic_id,
    s.name AS statistic_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    sp.participantFK AS participant_id,
    p.name AS participant_name,
    p.type AS participant_type,
    p.del AS participant_del,
    (
        SELECT COUNT(DISTINCT sd.id)
        FROM statistic_data{{SHARD_ID}} sd
        WHERE sd.statistic_participants{{SHARD_ID}}FK = sp.id
          AND sd.del = 'no'
    ) AS active_data_row_count,
    NULL AS eligible_count,
    0 AS sort_order
-- The reference is tested rather than used as a scope join. An inner join to participant
-- would make a missing reference disappear from both findings and coverage, which is the
-- false-clean shape this statement exists to prevent. The data-row count is context only:
-- a dangling participant row is invalid whether it still owns data or not.
FROM statistic_participants{{SHARD_ID}} sp
JOIN statistic s ON s.id = sp.statisticFK AND s.del = 'no'
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = {{SPORT_ID}}
LEFT JOIN participant p ON p.id = sp.participantFK
WHERE sp.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND (p.id IS NULL OR p.del <> 'no')

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT sp.id) AS eligible_count,
    1 AS sort_order
FROM statistic_participants{{SHARD_ID}} sp
JOIN statistic s ON s.id = sp.statisticFK AND s.del = 'no'
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = {{SPORT_ID}}
WHERE sp.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, statistic_participants_id;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-121
    -- Name - COMP.RANK_RESULTS_NUMERIC_PRECISION_INCONSISTENT
    -- What it does: Finds Comp.Rank whose participants' values in one numeric data field are not all written to the same number of decimal places, separating a value stored with no decimal point at all from a fraction shorter than its neighbours.
    CASE
        -- A value with no point at all is a different repair from a short fraction: the
        -- separator has to be added as well as the digits, and it is the shape a feed
        -- produces when it drops a trailing zero group rather than one digit.
        WHEN y.types_with_integer > 0 THEN 'PRECISION_MIXED_WITH_INTEGER'
        ELSE 'PRECISION_MIXED_DECIMAL_PLACES'
    END AS check_type,
    y.statistic_id,
    y.statistic_name,
    y.template_name,
    y.tournament_name,
    y.affected_data_types,
    y.decimal_places_seen,
    y.worst_shape_count,
    NULL AS eligible_count
FROM (
    SELECT
        x.statistic_id,
        x.statistic_name,
        x.template_name,
        x.tournament_name,
        GROUP_CONCAT(DISTINCT x.statistic_data_typeFK) AS affected_data_types,
        GROUP_CONCAT(DISTINCT x.places_seen SEPARATOR ' | ') AS decimal_places_seen,
        MAX(x.shape_count) AS worst_shape_count,
        SUM(CASE WHEN x.has_integer = 1 THEN 1 ELSE 0 END) AS types_with_integer
    FROM (
        SELECT
            s.id AS statistic_id,
            s.name AS statistic_name,
            tt.name AS template_name,
            t.name AS tournament_name,
            sd.statistic_data_typeFK,
            -- The written form, not the value. The event-layer twin is GLOBAL-DQ-120 and
            -- reads the same invariant one layer down.
            COUNT(DISTINCT CASE WHEN sd.value LIKE '%.%'
                    THEN LENGTH(SUBSTRING_INDEX(sd.value, '.', -1)) ELSE 0 END) AS shape_count,
            MAX(CASE WHEN sd.value LIKE '%.%' THEN 0 ELSE 1 END) AS has_integer,
            GROUP_CONCAT(DISTINCT CASE WHEN sd.value LIKE '%.%'
                    THEN LENGTH(SUBSTRING_INDEX(sd.value, '.', -1)) ELSE 0 END) AS places_seen
        FROM statistic s
        JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
        JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = s.id AND sp.del = 'no'
        JOIN statistic_data{{SHARD_ID}} sd
          ON sd.statistic_participants{{SHARD_ID}}FK = sp.id
         AND sd.del = 'no'
         AND sd.statistic_data_typeFK IN ({{PRECISION_DATA_TYPE_LIST}})
         AND sd.value REGEXP '^[0-9]+(:[0-9]{1,2})*([.][0-9]+)?$'
        WHERE s.del = 'no'
          AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
          AND s.object_typeFK = 3
          AND tt.sportFK = {{SPORT_ID}}
          AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
          -- AND t.tournament_templateFK = <tournament_template_id>
        GROUP BY s.id, s.name, tt.name, t.name, sd.statistic_data_typeFK
        HAVING shape_count > 1
    ) x
    GROUP BY x.statistic_id, x.statistic_name, x.template_name, x.tournament_name
) y

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = s.id AND sp.del = 'no'
JOIN statistic_data{{SHARD_ID}} sd
  ON sd.statistic_participants{{SHARD_ID}}FK = sp.id
 AND sd.del = 'no'
 AND sd.statistic_data_typeFK IN ({{PRECISION_DATA_TYPE_LIST}})
 AND sd.value REGEXP '^[0-9]+(:[0-9]{1,2})*([.][0-9]+)?$'
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND t.tournament_templateFK = <tournament_template_id>
;
