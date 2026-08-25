SELECT
    -- CheckID - GLOBAL-DQ-010
    -- Name - COMP.RANK_NO_PARTICIPANTS
    -- What it does: Flags Comp.Rank records with no participant rows in the sport's shard.
    'No_Participants' AS check_type,
    s.id AS statistic_id,
    s.name AS statistic_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    NULL AS eligible_count
-- What it does, stated in full: Finds Comp.Rank holding no participant rows in the sport's
-- shard.
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-011
    -- Name - COMP.RANK_SETTINGS_MISSING_START_OR_END_DATE
    -- What it does: Flags Comp.Rank records with a missing or empty Start date or End date.
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
-- What it does, stated in full: Finds Comp.Rank with a missing or empty Start date or End
-- date.
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-012
    -- Name - COMP.RANK_RESULTS_RANK_INVALID_OR_MISSING
    -- What it does: Flags Comp.Rank participants whose Rank is missing without a Comment or is not a positive integer.
    'Rank_Invalid_Or_Missing' AS check_type,
    s.id AS statistic_id,
    s.name AS statistic_name,
    cfg.value AS ranking_start_date,
    tt.name AS template_name,
    t.name AS tournament_name,
    COUNT(DISTINCT sp.id) AS violating_record_count,
    NULL AS eligible_count
-- What it does, stated in full: Finds Comp.Rank holding a participant whose Rank is not a
-- positive integer, or is missing with no Comment to explain it.
-- The date the ranking declares for itself travels with the row, at the reviewers' asking on
-- 2026-08-19. A Comp.Rank covers a whole tournament rather than one contest, so it has no event
-- start date to carry; what it has is its own configured start, and without it a finding names a
-- season and nothing narrower. Left joined, so a ranking that never set one is still reported
-- and says so by holding nothing there.
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = s.id AND sp.del = 'no'
LEFT JOIN statistic_data{{SHARD_ID}} sd
  ON sd.statistic_participants{{SHARD_ID}}FK = sp.id
 AND sd.statistic_data_typeFK = {{DATA_RANK_TYPE_ID}}
 AND sd.del = 'no'
LEFT JOIN statistic_config cfg
  ON cfg.statisticFK = s.id
 AND cfg.statistic_data_typeFK = {{CONFIG_START_DATE_TYPE_ID}}
 AND cfg.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
GROUP BY s.id, s.name, cfg.value, tt.name, t.name

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL,
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-022
    -- Name - COMP.RANK_SETTINGS_MISSING_AGE_CLASS
    -- What it does: Flags Comp.Rank records with no age-class relation.
    'Missing_Age_Class' AS check_type,
    s.id AS statistic_id,
    s.name AS statistic_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    NULL AS eligible_count
-- What it does, stated in full: Finds Comp.Rank with no age-class relation.
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-023
    -- Name - COMP.RANK_SETTINGS_DISCIPLINE_MISSING_UNRESOLVED_OR_FOREIGN
    -- What it does: Flags Comp.Rank records with no usable discipline - no relation at all, a relation pointing at no discipline, or one naming a discipline that belongs to another sport.
    CASE
        -- Three states and three repairs, separated for the reason GLOBAL-DQ-015 separates the
        -- same three at the event layer: a reviewer filtering for one would otherwise be handed
        -- the others. Until 2026-08-25 the first two were reported under one check_type and the
        -- third was not reported at all.
        WHEN x.relation_rows = 0 THEN 'Missing_Discipline'
        WHEN x.resolved_rows = 0 THEN 'Discipline_Reference_Unresolved'
        ELSE 'Discipline_Belongs_To_Another_Sport'
    END AS check_type,
    x.statistic_id,
    x.statistic_name,
    x.template_name,
    x.tournament_name,
    x.unresolved_discipline_ids,
    x.foreign_sport_disciplines,
    NULL AS eligible_count
-- What it does, stated in full: Finds Comp.Rank from which no discipline of this sport can be
-- read - the relation is absent, or it exists and its disciplineFK selects no active row in
-- discipline, or it selects a discipline whose sportFK is a different sport.
-- This is GLOBAL-DQ-015 asked one layer down, and the two are independent: DATABASE.md records
-- that event discipline and statistic discipline are separate relations, so a sport can carry a
-- readable discipline on every event and an unreadable one on a ranking.
-- **The third state is written for the invariant, not for the rows.** Measured 2026-08-25 over
-- the twelve documented sports it returns nothing at all, where the same rule at the event layer
-- returns 68 - Swimming reaching into Para Swimming's catalogue for 67 events and Equestrian
-- into Mountain Bike's for one. That is worth knowing rather than worth omitting: a Comp.Rank
-- reaches its discipline through a tournament that already fixes the sport, so a foreign
-- reference here would mean something different from the same reference on an event, and the
-- day one appears is the day somebody needs to be told. An empty result is a sentinel, not
-- clean data proving the check unnecessary.
-- `unresolved_discipline_ids` carries the value the relation actually holds, because `0` and a
-- plausible-looking id that has since been deleted are different stories and the row should not
-- make the reviewer go and look. `foreign_sport_disciplines` names the owning sport as well as
-- the discipline, because the id alone cannot tell a reviewer whether the ranking or the
-- reference is the thing to move.
-- A discipline row carrying `del = 'yes'` does not resolve, which is the behaviour this check
-- has always had and is deliberately kept: a ranking pointing at a retired discipline is as
-- unreadable as one pointing at no discipline.
FROM (
    SELECT
        s.id AS statistic_id,
        s.name AS statistic_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        COUNT(od.id) AS relation_rows,
        COUNT(d.id) AS resolved_rows,
        COUNT(CASE WHEN d.sportFK = {{SPORT_ID}} THEN d.id END) AS own_sport_rows,
        GROUP_CONCAT(DISTINCT CASE WHEN d.id IS NULL THEN od.disciplineFK END
                     ORDER BY od.disciplineFK SEPARATOR ', ') AS unresolved_discipline_ids,
        GROUP_CONCAT(DISTINCT CASE WHEN d.id IS NOT NULL AND d.sportFK <> {{SPORT_ID}}
                                   THEN CONCAT(d.id, ' ', d.name, ' - sport ', d.sportFK, ' ', sp.name) END
                     ORDER BY d.id SEPARATOR ' | ') AS foreign_sport_disciplines
    FROM statistic s
    JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    LEFT JOIN object_discipline od
           ON od.object_typeFK = 83
          AND od.objectFK = s.id
          AND od.del = 'no'
    LEFT JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
    LEFT JOIN sport sp ON sp.id = d.sportFK
    WHERE s.del = 'no'
      AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
      AND s.object_typeFK = 3
      AND tt.sportFK = {{SPORT_ID}}
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
      -- AND t.tournament_templateFK = <tournament_template_id>
    GROUP BY s.id, s.name, tt.name, t.name
) x
-- A ranking holding one readable discipline of its own sport is settled, however many relations
-- it carries. The finding is that not one of them gets that far.
WHERE x.own_sport_rows = 0

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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-024
    -- Name - COMP.RANK_SETTINGS_DATE_RANGE_MISMATCH_STAGE
    -- What it does: Flags Comp.Rank date ranges that are reversed or fall outside the tournament's stage dates.
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
    x.earliest_stage_id,
    x.latest_stage_enddate,
    x.latest_stage_id,
    NULL AS eligible_count
-- What it does, stated in full: Finds Comp.Rank whose configured date interval is inverted,
-- or is not contained within the stage dates of its own tournament, separating an inverted
-- interval, one crossing both bounds, a start before the earliest stage and an end after the
-- latest.
FROM (
    SELECT
        s.id AS statistic_id,
        s.name AS statistic_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        (SELECT MIN(sc1.value) FROM statistic_config sc1 WHERE sc1.statisticFK = s.id AND sc1.statistic_data_typeFK = {{CONFIG_START_DATE_TYPE_ID}} AND sc1.del = 'no') AS config_start_date,
        (SELECT MAX(sc2.value) FROM statistic_config sc2 WHERE sc2.statisticFK = s.id AND sc2.statistic_data_typeFK = {{CONFIG_END_DATE_TYPE_ID}} AND sc2.del = 'no') AS config_end_date,
        MIN(ts.startdate) AS earliest_stage_startdate,
        -- The stage that holds each bound, not just the date. A reader checking one of these
        -- rows has a Comp.Rank id and two dates and no way to reach the stage the date came
        -- from except by listing every stage of the tournament and comparing by eye; a
        -- tournament runs a dozen. The id is the shortest route from the finding to the row
        -- that has to be looked at. Added 2026-08-20.
        SUBSTRING_INDEX(GROUP_CONCAT(ts.id ORDER BY ts.startdate ASC), ',', 1) AS earliest_stage_id,
        MAX(ts.enddate) AS latest_stage_enddate,
        SUBSTRING_INDEX(GROUP_CONCAT(ts.id ORDER BY ts.enddate DESC), ',', 1) AS latest_stage_id
    FROM statistic s
    JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
    WHERE s.del = 'no'
      AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
      AND s.object_typeFK = 3
      AND tt.sportFK = {{SPORT_ID}}
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND EXISTS (
      SELECT 1 FROM statistic_config sc3
      WHERE sc3.statisticFK = s.id AND sc3.statistic_data_typeFK IN ({{CONFIG_START_DATE_TYPE_ID}}, {{CONFIG_END_DATE_TYPE_ID}}) AND sc3.del = 'no'
  );


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-025
    -- Name - COMP.RANK_SETTINGS_DATE_RANGE_MISMATCH_EVENTS
    -- What it does: Flags Comp.Rank date ranges that are reversed or do not contain every event listed in the Event id setting.
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
-- What it does, stated in full: Finds Comp.Rank whose configured date interval is inverted,
-- or does not contain every event it names through the Event id config, separating the four
-- boundary failures.
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
    -- The Event id config enumerates events rather than naming one, as DATABASE.md DB-SEM-011
    -- says and Golf demonstrates with up to 37 ids in a single value. Equality against the
    -- whole string reads only the first of them, so the events a statistic covers were
    -- undercounted wherever a sport stores a list. FIND_IN_SET reads all of them and is exact
    -- for a single value too. The events are reached through the statistic's own tournament so
    -- the membership test runs against that tournament's events rather than the whole sport.
    JOIN tournament_stage tse ON tse.tournamentFK = t.id AND tse.del = 'no'
    JOIN event e ON e.tournament_stageFK = tse.id AND e.del = 'no'
         AND FIND_IN_SET(e.id, sce.value) > 0
    WHERE s.del = 'no'
      AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
      AND s.object_typeFK = 3
      AND tt.sportFK = {{SPORT_ID}}
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
JOIN tournament_stage tse ON tse.tournamentFK = t.id AND tse.del = 'no'
JOIN event e ON e.tournament_stageFK = tse.id AND e.del = 'no'
     AND FIND_IN_SET(e.id, sce.value) > 0
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND EXISTS (
      SELECT 1 FROM statistic_config sc3
      WHERE sc3.statisticFK = s.id AND sc3.statistic_data_typeFK IN ({{CONFIG_START_DATE_TYPE_ID}}, {{CONFIG_END_DATE_TYPE_ID}}) AND sc3.del = 'no'
  );


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-026
    -- Name - COMP.RANK_SETTINGS_MEDAL_SET_INVALID
    -- What it does: Finds Comp.Rank medals that do not match the places the ranking holds.
    CASE
-- What it does, stated in full: Finds Comp.Rank whose medal set does not follow the places
-- its own Rank rows hold: a type missing, held by more competitors than the place takes,
-- held by fewer, or standing over a podium that never reaches the place it belongs to -
-- counting relay members who share their team's medal as one holder.
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-027
    -- Name - COMP.RANK_RESULTS_MEDAL_INVALID_VALUE
    -- What it does: Flags Comp.Rank Medal values other than gold, silver, or bronze.
    'Medal_Invalid_Value' AS check_type,
-- What it does, stated in full: Finds Comp.Rank Medal values that are not gold, silver or
-- bronze.
    -- The audited object leads the row, and it is the participant rather than the statistic
    -- the participant sits in: a medal is held by one competitor and repaired on that one row,
    -- which is also how the event-layer twin GLOBAL-DQ-018 is keyed. The statistic stays
    -- beside it as context. Before 2026-08-13 the statistic led and the participant id was
    -- absent, so a statistic holding two invalid medals would have appeared twice under one
    -- id - the shape corrected in GLOBAL-DQ-077 on the same day. It has never happened in any
    -- documented sport, all seven returning clean, and is closed here rather than waited for.
    sp.id AS statistic_participants_id,
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND LOWER(TRIM(sd.value)) NOT IN ('gold', 'silver', 'bronze')

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-028
    -- Name - COMP.RANK_RESULTS_TIME_DIFFERENCE_FORMAT_MISMATCH_TO_RANK
    -- What it does: Flags Comp.Rank Time Difference values that break this rule: rank 1 has an absolute time and lower ranks have a plus-prefixed gap.
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
-- What it does, stated in full: Finds Comp.Rank holding a participant whose Time Difference
-- breaks the leader/gap convention: rank 1 a plain absolute time, every other rank a plus-
-- prefixed gap.
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND TRIM(rk.value) <> ''
  AND TRIM(td.value) <> ''
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-029
    -- Name - COMP.RANK_RESULTS_DEPRECATED_DURATION_USED
    -- What it does: Finds Comp.Rank records still using the old Duration field.
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
-- What it does, stated in full: Finds Comp.Rank still storing a value in the deprecated
-- Duration field, with which of the current Time and Time Difference fields are populated
-- beside it.
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-030
    -- Name - COMP.RANK_RESULTS_PARTICIPANT_NOT_IN_TOURNAMENT
    -- What it does: Flags Comp.Rank statistics for participants who are never event participants or lineup members in the same tournament.
    'PARTICIPANT_NOT_IN_TOURNAMENT' AS check_type,
    s.id AS statistic_id,
    tt.name AS template_name,
    t.name AS tournament_name,
    COUNT(DISTINCT sp.participantFK) AS stray_participants,
    COUNT(DISTINCT sp.id) AS stray_participant_rows,
    GROUP_CONCAT(DISTINCT p.id ORDER BY p.id SEPARATOR ' | ') AS participant_ids,
    GROUP_CONCAT(DISTINCT p.name ORDER BY p.name SEPARATOR ' | ') AS participant_names,
    NULL AS eligible_count
-- What it does, stated in full: Finds Comp.Rank statistics holding participants who are
-- neither an event participant nor a lineup member anywhere under their own tournament.
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND s.id BETWEEN <from_statistic_id> AND <to_statistic_id>
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND s.id BETWEEN <from_statistic_id> AND <to_statistic_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-031
    -- Name - COMP.RANK_RESULTS_RANK_OUTLIER_ABOVE_FIELD_SIZE
    -- What it does: Flags Comp.Rank participants with an unexplained Rank above the number of ranked participants and a gap from the previous Rank.
    'RANK_OUTLIER_ABOVE_FIELD_SIZE' AS check_type,
    z.statistic_participants_id,
    z.statistic_id,
    z.template_name,
    z.tournament_name,
    p.name AS participant_name,
    z.rank_value,
    z.participant_count,
    z.next_lower_rank,
    NULL AS eligible_count
-- What it does, stated in full: Finds Comp.Rank participants whose Rank exceeds the number
-- ranked and is disconnected from the next lower Rank, with no Comment to explain it.
--
-- next_lower_rank is a window over the statistic's own ranks, computed once. It was a
-- correlated subquery until 2026-08-16, and that shape did not survive a large sport: on
-- Cycling the statement answered 504 twice, once inside a batch and once alone. Two things
-- were wrong with it and the measurement separated them. The subquery correlated on
-- f.statistic_id, a derived-table column, which can make the server rebuild f once per
-- candidate row; pointing it at sp.statisticFK instead brought the same answer back in 94.9
-- seconds, which proves the rebuild and is still far too slow. What remains is the subquery
-- itself, run once per row over a shard table every sport shares. The window does the work in
-- one pass and the statement returns in 11.2 seconds.
--
-- The window is deliberately computed before rank_value > participant_count is applied. The
-- rank it looks for is the next lower one anywhere in the statistic, not the next lower one
-- among the outliers, and filtering first would compare an outlier against another outlier.
FROM (
    SELECT
        g.statistic_participants_id,
        g.statistic_id,
        g.template_name,
        g.tournament_name,
        g.participant_id,
        g.rank_value,
        g.participant_count,
        MAX(g.rank_value) OVER (
            PARTITION BY g.statistic_id
            ORDER BY g.rank_value
            RANGE BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) AS next_lower_rank
    FROM (
        SELECT
            sp.id AS statistic_participants_id,
            f.statistic_id,
            f.template_name,
            f.tournament_name,
            sp.participantFK AS participant_id,
            CAST(sd.value AS UNSIGNED) AS rank_value,
            f.participant_count
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND s.id BETWEEN <from_statistic_id> AND <to_statistic_id>
    GROUP BY s.id, tt.name, t.name
    HAVING MAX(CAST(sdf.value AS UNSIGNED)) > COUNT(DISTINCT spf.id)
        ) f
        JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = f.statistic_id AND sp.del = 'no'
        JOIN statistic_data{{SHARD_ID}} sd ON sd.statistic_participants{{SHARD_ID}}FK = sp.id
             AND sd.statistic_data_typeFK = {{DATA_RANK_TYPE_ID}}
             AND sd.del = 'no'
             AND sd.value REGEXP '^[1-9][0-9]*$'
    ) g
) z
JOIN participant p ON p.id = z.participant_id AND p.del = 'no'
WHERE z.rank_value > z.participant_count
  AND (z.next_lower_rank IS NULL
       OR z.rank_value > z.next_lower_rank + 1)
  AND NOT EXISTS (
      SELECT 1
      FROM statistic_data{{SHARD_ID}} sdc
      WHERE sdc.statistic_participants{{SHARD_ID}}FK = z.statistic_participants_id
        AND sdc.statistic_data_typeFK = {{DATA_COMMENT_TYPE_ID}}
        AND sdc.del = 'no'
        AND sdc.value IS NOT NULL
        AND TRIM(sdc.value) <> ''
  )

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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND s.id BETWEEN <from_statistic_id> AND <to_statistic_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-032
    -- Name - COMP.RANK_RESULTS_NO_RANK_DATA_FOR_PARTICIPANTS
    -- What it does: Flags Comp.Rank records with participants but no Rank value for anyone.
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
-- What it does, stated in full: Finds Comp.Rank holding participants but no Rank value for
-- any of them, separating one holding no data at all from one holding other data.
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-033
    -- Name - COMP.RANK_RESULTS_MISSING_PHASE
    -- What it does: Flags Comp.Rank participants with no phase row.
    'MISSING_PHASE' AS check_type,
    x.statistic_id,
    x.statistic_name,
    x.template_name,
    x.tournament_name,
    x.field_size,
    x.missing_count,
-- What it does, stated in full: Finds Comp.Rank carrying participants with no phase row,
-- naming how many of the field are missing one and who they are.
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
          AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-035
    -- Name - COMP.RANK_SETTINGS_MISSING_CORE_FIELDS
    -- What it does: Flags Comp.Rank records missing a name, Gender setting, country, or city, or using a placeholder country.
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
-- What it does, stated in full: Finds Comp.Rank missing a name, a Gender config, a country
-- or a city relation, or carrying a country that resolves only to a placeholder.
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-040
    -- Name - EVENT_FINAL_WITHOUT_COMP.RANK
    -- What it does: Finds Final events that no Comp.Rank in their tournament lists.
    CASE
        WHEN x.tournament_statistics = 0 THEN 'TOURNAMENT_HAS_NO_COMP_RANK'
        WHEN x.statistics_with_event_config = 0 THEN 'COMP.RANK_EVENT_SCOPE_UNDETERMINABLE'
        ELSE 'FINAL_EVENT_NOT_IN_ANY_COMP_RANK'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.template_name,
    x.tournament_id,
    x.tournament_name,
    x.stage_name,
    NULL AS eligible_count
-- What it does, stated in full: Finds Final-round events that no Comp.Rank under their own
-- tournament names through its Event id config, separating a tournament holding none at all
-- from one whose Comp.Rank declares no event scope.
-- The tournament id is projected beside its name because the name is a season and repeats
-- across editions - `World Championship 1` names one row per year - so a reader counting
-- distinct names cannot tell how many tournaments the output actually describes, and a
-- hundred rows on one name reads the same as a hundred names. Added 2026-08-20.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        tt.name AS template_name,
        t.id AS tournament_id,
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
              -- The value enumerates events; equality against the whole string would see only
              -- the first, so an event named second in a list read as unreferenced.
              AND FIND_IN_SET(e.id, sc.value) > 0
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
      -- AND t.tournament_templateFK = <tournament_template_id>
) x
WHERE x.referencing_statistics = 0

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
  AND e.round_typeFK IN ({{FINAL_ROUND_TYPE_LIST}})
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-041
    -- Name - COMP.RANK_RESULTS_MEDAL_ON_NON_MEDAL_ROUND_PHASE
    -- What it does: Flags Comp.Rank participants with a Medal in a phase that does not award medals.
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
-- What it does, stated in full: Finds Comp.Rank participants carrying a Medal while their
-- phase names a round the sport awards no medals on.
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-042
    -- Name - EVENT_FINAL_PARTICIPANT_NOT_IN_COMP.RANK
    -- What it does: Flags Final events where Comp.Rank is missing one or more competitors who took part.
    'FINAL_PARTICIPANT_NOT_IN_COMP.RANK' AS check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.template_name,
    x.tournament_name,
    x.field_size,
    x.missing_count,
-- What it does, stated in full: Finds Final-round events whose Comp.Rank omits competitors
-- who took part, naming how many of the field are missing from it and who they are.
    -- A convenience for the reader, not the finding: GROUP_CONCAT truncates at the server's
    -- group_concat_max_len without saying so, and missing_count is counted separately and is
    -- what the row asserts.
    x.missing_participants,
    NULL AS eligible_count
FROM (
    SELECT
        y.event_id,
        y.event_name,
        y.event_startdate,
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
        -- The Event id config is a list, so membership is FIND_IN_SET rather than a numeric
        -- comparison. That function cannot use an index and is evaluated per row, so asking it
        -- inside a correlated EXISTS - once per competitor per event, twice over - made this
        -- statement unrunnable: Artistic Gymnastics returned in 19 seconds on 2026-08-12 and
        -- timed out at 180 after the operator changed. The map from event to covering statistic
        -- is therefore built once for the sport and joined, which asks the list question once
        -- per statistic instead of once per competitor.
        SELECT
            e.id AS event_id,
            e.name AS event_name,
            e.startdate AS event_startdate,
            tt.name AS template_name,
            t.name AS tournament_name,
            p.name AS participant_name,
            CASE WHEN MAX(CASE WHEN sp.id IS NOT NULL THEN 1 ELSE 0 END) = 0
                 THEN 1 ELSE 0 END AS is_missing
        FROM event e
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
        JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
        JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
        -- Every (event, covering statistic) pair the sport holds, built once. Restricted to
        -- statistics that hold participants, which is also what makes an event eligible: an
        -- empty statistic omits everyone and is GLOBAL-DQ-010 rather than this.
        JOIN (
            SELECT DISTINCT
                ex.id AS event_id,
                sx.id AS statistic_id
            FROM statistic_config scx
            JOIN statistic sx ON sx.id = scx.statisticFK
                 AND sx.del = 'no'
                 AND sx.statistic_typeFK = {{STATISTIC_TYPE_ID}}
                 AND sx.object_typeFK = 3
            JOIN tournament tx ON tx.id = sx.objectFK AND tx.del = 'no'
            JOIN tournament_template ttx ON ttx.id = tx.tournament_templateFK AND ttx.del = 'no'
                 AND ttx.sportFK = {{SPORT_ID}}
            JOIN tournament_stage tsx ON tsx.tournamentFK = tx.id AND tsx.del = 'no'
            JOIN event ex ON ex.tournament_stageFK = tsx.id AND ex.del = 'no'
                 AND FIND_IN_SET(ex.id, scx.value) > 0
            WHERE scx.statistic_data_typeFK = {{CONFIG_EVENT_ID_TYPE_ID}}
              AND scx.del = 'no'
              AND tx.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
              AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(tx.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(tx.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
              -- AND tx.tournament_templateFK = <tournament_template_id>
              AND EXISTS (
                  SELECT 1
                  FROM statistic_participants{{SHARD_ID}} spx
                  WHERE spx.statisticFK = sx.id AND spx.del = 'no'
              )
        ) m ON m.event_id = e.id
        LEFT JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = m.statistic_id
             AND sp.participantFK = ep.participantFK
             AND sp.del = 'no'
        WHERE e.del = 'no'
          AND tt.sportFK = {{SPORT_ID}}
          AND e.round_typeFK IN ({{FINAL_ROUND_TYPE_LIST}})
          AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
          AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
          -- AND t.tournament_templateFK = <tournament_template_id>
          -- AND e.id BETWEEN <from_event_id> AND <to_event_id>
        -- One row per competitor, whatever how many statistics cover the event: a competitor
        -- listed by any of them is not missing.
        GROUP BY e.id, e.name, e.startdate, tt.name, t.name, ep.id, p.name
    ) y
    GROUP BY y.event_id, y.event_name, y.event_startdate, y.template_name, y.tournament_name
) x
WHERE x.missing_count > 0

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.id BETWEEN <from_event_id> AND <to_event_id>
  -- The same map the findings branch joins, so both halves read one population. Built once
  -- rather than asked per event: FIND_IN_SET is a per-row function with no index behind it.
  AND e.id IN (
      SELECT ex.id
      FROM statistic_config scx
      JOIN statistic sx ON sx.id = scx.statisticFK
           AND sx.del = 'no'
           AND sx.statistic_typeFK = {{STATISTIC_TYPE_ID}}
           AND sx.object_typeFK = 3
      JOIN tournament tx ON tx.id = sx.objectFK AND tx.del = 'no'
      JOIN tournament_template ttx ON ttx.id = tx.tournament_templateFK AND ttx.del = 'no'
           AND ttx.sportFK = {{SPORT_ID}}
      JOIN tournament_stage tsx ON tsx.tournamentFK = tx.id AND tsx.del = 'no'
      JOIN event ex ON ex.tournament_stageFK = tsx.id AND ex.del = 'no'
           AND FIND_IN_SET(ex.id, scx.value) > 0
      WHERE scx.statistic_data_typeFK = {{CONFIG_EVENT_ID_TYPE_ID}}
        AND scx.del = 'no'
        AND tx.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
        AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(tx.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(tx.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
        -- AND tx.tournament_templateFK = <tournament_template_id>
        AND EXISTS (
            SELECT 1
            FROM statistic_participants{{SHARD_ID}} spx
            WHERE spx.statisticFK = sx.id AND spx.del = 'no'
        )
  )
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-044
    -- Name - COMP.RANK_RESULTS_GENDER_MISMATCH
    -- What it does: Flags Comp.Rank Gender settings that do not match the participants' gender.
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
-- What it does, stated in full: Finds Comp.Rank whose Gender config does not match the
-- gender of its own participants.
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
    -- What it does: Flags timed Comp.Rank records where Rank, Time, and Time Difference do not agree, or where Time is invalid or zero.
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
-- What it does, stated in full: Finds Comp.Rank in the sport's timed disciplines whose time
-- storage contradicts a Rank: a Time or Time Difference missing where the rank calls for
-- one, either present with no rank, or a Time badly formatted or zero.
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
    -- What it does: Finds Comp.Rank names that break a text-hygiene rule.
    'Name_Format_Invalid' AS check_type,
    MIN(x.object_name) AS statistic_name,
    x.violation_types,
    COUNT(DISTINCT x.object_id) AS affected_object_count,
    MIN(x.object_id) AS sample_object_id,
    MIN(x.template_name) AS template_name,
    MIN(x.tournament_name) AS sample_tournament_name,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds Comp.Rank names breaking a text-hygiene rule -
-- spacing, control or corrupted characters, hyphenation, capitalisation, a placeholder or a
-- numeric-only name - one row per name, naming every rule it breaks.
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, violation_types, statistic_name;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-057
    -- Name - COMP.RANK_RESULTS_COMMENT_INVALID_OR_CONTRADICTED
    -- What it does: Flags invalid Comp.Rank Comment values, or an unclassified Comment stored together with a Rank, Time, or Medal.
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
-- What it does, stated in full: Finds Comp.Rank Comment values outside the sport's status
-- codes, or marking a participant as unclassified while a Rank, a Time or a Medal is stored
-- for that same participant.
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-060
    -- Name - COMP.RANK_RESULTS_DUPLICATE_ROWS
    -- What it does: Finds a Comp.Rank participant holding the same field twice.
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
-- What it does, stated in full: Finds Comp.Rank holding more than one data row for the same
-- participant and field, separating a duplicate repeating the value from one storing a
-- conflicting one.
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-064
    -- Name - COMP.RANK_ATHLETE_TEAM_MISSING_OR_INVALID
    -- What it does: Finds athletes in a team-based Comp.Rank without a usable Team value.
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
-- What it does, stated in full: Finds athletes inside a Comp.Rank that uses the Team field
-- whose own Team value is absent, does not resolve to a team, or is stored twice - repeating
-- a value or contradicting itself.
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
      -- AND t.tournament_templateFK = <tournament_template_id>
    GROUP BY sp.id
) y
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-065
    -- Name - COMP.RANK_TEAM_ATHLETE_COUNT_UNEVEN
    -- What it does: Flags Comp.Rank teams that have different roster sizes.
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
-- What it does, stated in full: Finds Comp.Rank whose teams do not all field the same number
-- of athletes, separating a shortfall of one athlete from a larger one.
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
          AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-066
    -- Name - COMP.RANK_TEAM_GENDER_BALANCE_UNEVEN
    -- What it does: Flags mixed Comp.Rank teams with only one gender or unequal numbers of male and female athletes.
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
-- What it does, stated in full: Finds mixed Comp.Rank holding a team whose athletes are not
-- an equal number of male and female, separating a team fielding one gender only from one
-- fielding both unevenly.
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
          AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-070
    -- Name - COMP.RANK_RESULTS_VALUE_BLANK
    -- What it does: Flags Comp.Rank values that contain only spaces or only invisible characters.
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
-- What it does, stated in full: Finds Comp.Rank data values that are neither empty nor
-- readable, made only of ordinary spacing or only of invisible characters, separating the
-- two.
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, blank_data_count DESC;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-072
    -- Name - COMP.RANK_RESULTS_MEDAL_RANK_MISMATCH
    -- What it does: Flags Comp.Rank participants whose Medal does not match their Rank, or who have a Medal without a Rank.
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
-- What it does, stated in full: Finds Comp.Rank participants whose Medal does not match the
-- place it stands for, or that carry no Rank at all.
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-077
    -- Name - COMP.RANK_RESULTS_NUMERIC_FIELD_NON_NUMERIC
    -- What it does: Finds text stored in numeric Comp.Rank fields.
    x.check_type,
    x.statistic_id,
    x.statistic_name,
    x.template_name,
    x.tournament_name,
-- What it does, stated in full: Finds Comp.Rank holding non-numeric values in the sport's
-- numeric fields, separating one of the sport's own status codes, a no-data sentinel such as
-- nan, a number written with thousands separators, and any other text, and naming how many
-- values are affected and what they hold.
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
          AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND sd.value IS NOT NULL
  AND TRIM(sd.value) <> ''

ORDER BY sort_order, affected_count DESC, statistic_id;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-095
    -- Name - COMP.RANK_RESULTS_RANK_DUPLICATE_WITHOUT_COMMENT
    -- What it does: Flags a shared Comp.Rank place with more holders than the team size when the next place is still awarded and no Comment explains it.
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
-- What it does, stated in full: Finds a Comp.Rank place held by more participants than its
-- teams field athletes, with no Comment to explain it, while the place that sharing consumes
-- is still awarded - so the place is occupied twice over rather than being a joint place the
-- ranking stops at.
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
-- Where the Team field assigns nobody, the team size is read out of the ranking itself. Added
-- 2026-08-19 after the reviewers asked why Golf's pairs tournaments were reported: Golf assigns
-- a Team zero times across 3371 Comp.Rank records and 360910 participant rows, so every place a
-- pair holds looked like a place held twice. Zurich Classic of New Orleans 2024 is the shape -
-- McIlroy and Lowry at 1, Ramey and Trainer at 2, Hubbard and Brehm at 3, four teams at 4, two
-- at 8, one at 10 - which is flawless read as teams and contradicts itself on every line read as
-- people.
-- The candidate is how many hold the lowest place, and it is taken only if the whole sequence
-- then holds together: every stored place divisible by it, and the next place stored exactly
-- where that many entries leave it. That is what stops an ordinary tie of two from being read as
-- a pair - a ranking holding any place with a single holder fails the test at once, because half
-- an entry never lands on a stored place. The authored field still wins wherever it says
-- anything; this reads nothing where it does.
-- Measured across the six sports running this template. Of the 3204 Golf rankings holding a
-- shared place, 2317 hold together read as people, 872 hold together neither way and are the
-- contradictions this reports, and 15 hold together only read as pairs - every one of the 15 a
-- real pairs tournament: Zurich Classic, Dow Great Lakes Bay Invitational, Dow Championship,
-- Grant Thornton Invitational, ISPS Handa Melbourne World Cup of Golf. Two more rankings leave
-- Curling and three leave Modern Pentathlon, and those five are Winter Youth Olympics Mixed and
-- Youth Summer Olympics Team-Relay Mix, which say what they are in their own names. Artistic
-- Gymnastics, BMX and Ice Hockey do not move at all.
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
            GREATEST(h.holders_per_place,
                CASE WHEN h.holders_per_place = 1 THEN COALESCE(hk.implied_team_size, 1) ELSE 1 END)
                AS holders_per_place
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
              AND tx.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
              AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(tx.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(tx.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
        -- The team size the ranking itself implies, read only where the Team field assigns
        -- nothing at all. The candidate is how many hold the lowest place, and it is accepted
        -- only if the whole sequence then holds together: every stored place divisible by it,
        -- and the next place stored exactly where that many entries would leave it. A ranking
        -- holding any place with a single holder fails at once, which is what stops an ordinary
        -- tie of two from being read as a pair.
        LEFT JOIN (
            SELECT
                k.statistic_id,
                MAX(k.candidate) AS implied_team_size
            FROM (
                SELECT
                    seq.statistic_id,
                    seq.candidate,
                    SUM(CASE WHEN MOD(seq.holder_count, seq.candidate) <> 0
                              OR (seq.next_rank IS NOT NULL
                                  AND seq.next_rank <> seq.rank_value + seq.holder_count / seq.candidate)
                             THEN 1 ELSE 0 END) AS breaks
                FROM (
                    SELECT
                        g5.statistic_id,
                        g5.rank_value,
                        g5.holder_count,
                        LEAD(g5.rank_value) OVER (
                            PARTITION BY g5.statistic_id ORDER BY g5.rank_value) AS next_rank,
                        FIRST_VALUE(g5.holder_count) OVER (
                            PARTITION BY g5.statistic_id ORDER BY g5.rank_value
                            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS candidate
                    FROM (
                        SELECT
                            sp5.statisticFK AS statistic_id,
                            CAST(TRIM(sd5.value) AS SIGNED) AS rank_value,
                            COUNT(DISTINCT sp5.id) AS holder_count
                        FROM statistic s5
                        JOIN tournament t5 ON t5.id = s5.objectFK AND t5.del = 'no'
                        JOIN tournament_template tt5 ON tt5.id = t5.tournament_templateFK
                             AND tt5.del = 'no'
                        JOIN statistic_participants{{SHARD_ID}} sp5 ON sp5.statisticFK = s5.id
                             AND sp5.del = 'no'
                        JOIN statistic_data{{SHARD_ID}} sd5
                             ON sd5.statistic_participants{{SHARD_ID}}FK = sp5.id
                             AND sd5.statistic_data_typeFK = {{DATA_RANK_TYPE_ID}}
                             AND sd5.del = 'no'
                             AND sd5.value IS NOT NULL
                             AND TRIM(sd5.value) REGEXP '^[1-9][0-9]*$'
                        WHERE s5.del = 'no'
                          AND s5.statistic_typeFK = {{STATISTIC_TYPE_ID}}
                          AND s5.object_typeFK = 3
                          AND tt5.sportFK = {{SPORT_ID}}
                        GROUP BY sp5.statisticFK, CAST(TRIM(sd5.value) AS SIGNED)
                    ) g5
                ) seq
                WHERE seq.candidate > 1
                GROUP BY seq.statistic_id, seq.candidate
                HAVING breaks = 0
            ) k
            GROUP BY k.statistic_id
        ) hk ON hk.statistic_id = r.statistic_id
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
              AND allr.rank_value < r.rank_value
                  + (r.holder_count DIV GREATEST(h.holders_per_place,
                        CASE WHEN h.holders_per_place = 1 THEN COALESCE(hk.implied_team_size, 1) ELSE 1 END))
        WHERE r.holder_count > GREATEST(h.holders_per_place,
                  CASE WHEN h.holders_per_place = 1 THEN COALESCE(hk.implied_team_size, 1) ELSE 1 END)
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-098
    -- Name - COMP.RANK_TEAM_FIELD_UNUSED_IN_TEAM_STATISTIC
    -- What it does: Flags rankings that look team-based because places are shared equally, but no athlete has a Team value.
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
-- What it does, stated in full: Finds Comp.Rank where every athlete shares a place with the
-- same number of others and none carries a Team value, so teams of that size are scored
-- without recording which team each athlete belongs to.
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
          AND tx.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(tx.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(tx.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
          AND ty.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(ty.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(ty.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, shared_place_count DESC;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-099
    -- Name - COMP.RANK_VALUE_BELONGS_TO_ANOTHER_FIELD
    -- What it does: Flags Comp.Rank values stored in the wrong field, such as a medal word outside Medal or a place number inside Medal.
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
-- What it does, stated in full: Finds a Comp.Rank value that is exactly what another field
-- owns: a medal word stored outside the Medal field, or a plain place number stored inside
-- it.
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND sd.value IS NOT NULL
  AND TRIM(sd.value) <> ''

ORDER BY sort_order;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-100
    -- Name - COMP.RANK_DISCIPLINE_NOT_CONTESTED_IN_TOURNAMENT
    -- What it does: Flags Comp.Rank disciplines not contested by any event in the same tournament.
    'DISCIPLINE_NOT_CONTESTED_IN_TOURNAMENT' AS check_type,
    x.statistic_id,
    x.statistic_name,
    x.template_name,
    x.tournament_name,
    x.claimed_disciplines,
    x.contested_disciplines,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds Comp.Rank claiming a discipline that no event under
-- its own tournament was contested in.
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
    -- What it does: Finds Comp.Rank whose Event id setting names an event that does not exist or belongs to another tournament.
    CASE
        WHEN x.not_numeric_count > 0 THEN 'EVENT_ID_NOT_NUMERIC'
        WHEN x.no_active_event_count > 0 THEN 'EVENT_ID_NO_ACTIVE_EVENT'
        WHEN x.outside_tournament_count > 0 THEN 'EVENT_ID_OUTSIDE_TOURNAMENT'
        ELSE 'EVENT_ID_LIST_NOT_ALL_UNDER_TOURNAMENT'
    END AS check_type,
    x.statistic_id,
    x.statistic_name,
    x.template_name,
    x.tournament_name,
    x.invalid_config_count,
    x.sample_values,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds Comp.Rank whose Event id config does not resolve to
-- events under its own tournament, separating a malformed value, one naming no event, one
-- naming an event another tournament owns, and a list not all of whose ids land under the
-- tournament.
-- The Event id is the only path from a Comp.Rank statistic to the event it summarises, and
-- every check that walks it joins through it. A join drops the row it cannot match, so an id
-- naming nothing and an id naming another tournament's event are both invisible to those
-- checks: they narrow the population silently instead of reporting it. That is what makes
-- this worth asserting separately rather than trusting the joins to surface it.
-- Three defects, one audited object. They are separated by check_type rather than by CheckID
-- because they are one question - does this id point where it claims - and a statistic
-- carrying two kinds at once should be one row rather than two.
-- The value is a list, not an id. DATABASE.md DB-SEM-011 says the config enumerates the
-- events a statistic covers, and Golf writes up to 37 ids into one value; reading it as a
-- single number matched only the first and reported every list as a value that is not a
-- number. Measured on Golf 2026-08-14: 246 of 250 findings were well-formed lists.
--
-- So a clean list is the accepted shape, and a list is resolved the only way it can be
-- without expanding it into rows - by counting how many of the tournament's own events it
-- names and comparing that with how many ids it holds. A shortfall means an id that resolves
-- to nothing or to another tournament's event, and the two cannot be told apart this way:
-- separating them would need an unbounded lookup of every id against the whole event table,
-- which is the cost this package refuses. A single id keeps the indexed primary-key lookup and
-- so keeps the finer answer.
FROM (
    SELECT
        v.statistic_id,
        v.statistic_name,
        v.template_name,
        v.tournament_name,
        COUNT(*) AS invalid_config_count,
        SUM(v.not_numeric) AS not_numeric_count,
        SUM(v.no_active_event) AS no_active_event_count,
        SUM(v.outside_tournament) AS outside_tournament_count,
        SUBSTRING(GROUP_CONCAT(DISTINCT LEFT(v.config_value, 20) ORDER BY v.config_value SEPARATOR ' | '), 1, 100) AS sample_values
    FROM (
        SELECT
            sc.id AS config_id,
            s.id AS statistic_id,
            s.name AS statistic_name,
            tt.name AS template_name,
            t.name AS tournament_name,
            TRIM(sc.value) AS config_value,
            CASE WHEN TRIM(sc.value) NOT REGEXP '^[0-9]+(,[0-9]+)*$'
                 THEN 1 ELSE 0 END AS not_numeric,
            CASE WHEN TRIM(sc.value) REGEXP '^[0-9]+$' AND e.id IS NULL
                 THEN 1 ELSE 0 END AS no_active_event,
            CASE WHEN TRIM(sc.value) REGEXP '^[0-9]+$' AND e.id IS NOT NULL
                      AND ts.tournamentFK <> s.objectFK
                 THEN 1 ELSE 0 END AS outside_tournament,
            CASE WHEN TRIM(sc.value) REGEXP '^[0-9]+(,[0-9]+)+$'
                      AND COUNT(DISTINCT ex.id) <
                          (LENGTH(TRIM(sc.value)) - LENGTH(REPLACE(TRIM(sc.value), ',', '')) + 1)
                 THEN 1 ELSE 0 END AS list_unresolved
        FROM statistic_config sc
        JOIN statistic s ON s.id = sc.statisticFK AND s.del = 'no'
             AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
             AND s.object_typeFK = 3
        JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
        LEFT JOIN event e ON TRIM(sc.value) REGEXP '^[0-9]+$'
             AND e.id = CAST(TRIM(sc.value) AS UNSIGNED) AND e.del = 'no'
        LEFT JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        LEFT JOIN tournament_stage tsx ON tsx.tournamentFK = s.objectFK AND tsx.del = 'no'
        LEFT JOIN event ex ON ex.tournament_stageFK = tsx.id AND ex.del = 'no'
             AND FIND_IN_SET(ex.id, TRIM(sc.value)) > 0
        WHERE sc.del = 'no'
          AND sc.statistic_data_typeFK = {{CONFIG_EVENT_ID_TYPE_ID}}
          AND TRIM(COALESCE(sc.value, '')) <> ''
          AND tt.sportFK = {{SPORT_ID}}
          AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
          AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
          -- AND t.tournament_templateFK = <tournament_template_id>
        GROUP BY sc.id, s.id, s.name, s.objectFK, tt.name, t.name,
                 TRIM(sc.value), e.id, ts.tournamentFK
    ) v
    WHERE v.not_numeric = 1
       OR v.no_active_event = 1
       OR v.outside_tournament = 1
       OR v.list_unresolved = 1
    GROUP BY v.statistic_id, v.statistic_name, v.template_name, v.tournament_name
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, statistic_id;

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-103
    -- Name - COMP.RANK_PARTICIPANT_DUPLICATE_IN_STATISTIC
    -- What it does: Flags Comp.Rank records where the same participant appears more than once.
    'Comp_Rank_Participant_Duplicate' AS check_type,
    x.statistic_id,
    x.statistic_name,
    x.template_name,
    x.tournament_name,
    x.affected_participant_count,
    x.duplicated_row_count,
    x.duplicated_participants,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds Comp.Rank holding the same participant twice, so one
-- competitor occupies a place in the ranking two times over.
-- Not the question GLOBAL-DQ-060 asks. That one groups by statistic_participants id and data
-- type, so it sees several data rows hanging off one participant row. This sees one
-- participant holding two participant rows in the same ranking, which that grouping cannot
-- reach: each of the two rows can carry a perfectly well-formed single set of data.
-- The duplicated competitors are named, not sampled. This column held
-- MIN(CONCAT('participant=', id, ' rows=', n)) until 2026-08-20, which gave a reader one id
-- out of however many and no name at all, so checking a row meant looking up a number
-- before the work could even start. It now lists every duplicated competitor with the name
-- beside the id and how many rows each holds, heaviest first. GROUP_CONCAT truncates at the
-- server's limit without saying so, which is why affected_participant_count is the number
-- the row asserts and this column is the convenience.
FROM (
    SELECT
        s.id AS statistic_id,
        s.name AS statistic_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        COUNT(*) AS affected_participant_count,
        SUM(g.row_count) AS duplicated_row_count,
        SUBSTRING(GROUP_CONCAT(
            CONCAT(COALESCE(p.name, CONCAT('participant ', g.participantFK)),
                   ' (', g.participantFK, ') x', g.row_count)
            ORDER BY g.row_count DESC, p.name SEPARATOR ' | '), 1, 300) AS duplicated_participants
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
          AND t2.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
          -- AND t2.tournament_templateFK = <tournament_template_id>
        GROUP BY sp.statisticFK, sp.participantFK
        HAVING COUNT(*) > 1
    ) g
    LEFT JOIN participant p ON p.id = g.participantFK AND p.del = 'no'
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
    -- What it does: Finds a Comp.Rank setting stored more than once for start date, end date or gender.
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
-- What it does, stated in full: Finds Comp.Rank holding more than one config row for a
-- setting that takes one value - start date, end date or gender - separating a repeat of the
-- same value from two that contradict each other.
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
          AND t2.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
    -- What it does: Flags Comp.Rank records attached to an owner level not approved for the sport.
    'Comp_Rank_Unexpected_Owner_Type' AS check_type,
    s.id AS statistic_id,
    s.name AS statistic_name,
    COALESCE(ot.name, CONCAT('object_typeFK ', s.object_typeFK)) AS owner_type_found,
    s.objectFK AS owner_object_id,
    COALESCE(t3.name, ts4.name) AS owner_object_name,
    COALESCE(t3.name, t4.name) AS tournament_name,
    tt.name AS template_name,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds Comp.Rank hanging off an owner level other than the
-- one the sport is confirmed to use.
-- Reached through both owner paths rather than through the tournament alone, which is the
-- whole point: a statistic on the wrong level cannot be found by a statement that joins
-- through the level it is supposed to be on. Every other Comp.Rank check in this file
-- anchors on object_typeFK = 3 and therefore cannot see this at all.
-- The finding is meant to be corrected by hand, so it names what it found rather than
-- numbering it: the level through object_type, the owner it hangs off, and the tournament
-- that owner belongs to. Where the owner is a stage the last two differ and both are
-- needed - the stage says which row to move, the tournament says where it should have
-- hung. The owner id stays as the handle to find the row by. object_type is reached
-- through a LEFT JOIN because a level absent from the reference table is the one finding
-- least worth dropping; the number is shown when the name is missing.
FROM statistic s
LEFT JOIN object_type ot ON ot.id = s.object_typeFK
LEFT JOIN tournament t3 ON s.object_typeFK = 3 AND t3.id = s.objectFK AND t3.del = 'no'
LEFT JOIN tournament_stage ts4 ON s.object_typeFK = 4 AND ts4.id = s.objectFK AND ts4.del = 'no'
LEFT JOIN tournament t4 ON t4.id = ts4.tournamentFK AND t4.del = 'no'
JOIN tournament_template tt ON tt.id = COALESCE(t3.tournament_templateFK, t4.tournament_templateFK)
     AND tt.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND tt.id NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(COALESCE(t3.name, t4.name), '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(COALESCE(t3.name, t4.name), '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND tt.id = <tournament_template_id>
  AND s.object_typeFK <> {{STATISTIC_OWNER_TYPE_ID}}

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
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
  AND tt.id NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(COALESCE(t3.name, t4.name), '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(COALESCE(t3.name, t4.name), '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND tt.id = <tournament_template_id>

ORDER BY sort_order, statistic_id;

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-110
    -- Name - COMP.RANK_DISCIPLINE_CONTRADICTS_LINKED_EVENT
    -- What it does: Flags Comp.Rank disciplines not contested by any event listed in the Event id setting.
    'Comp_Rank_Discipline_Contradicts_Linked_Event' AS check_type,
    x.statistic_id,
    x.statistic_name,
    x.template_name,
    x.tournament_name,
    x.claimed_disciplines,
    x.linked_event_disciplines,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds Comp.Rank whose claimed discipline was contested by
-- none of the events it names through the Event id config, so the two paths disagree about
-- the same competition.
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
         AND TRIM(sc.value) REGEXP '^[0-9]+(,[0-9]+)*$'
    -- Every event the value names, not the first one. Reading it as a single number excluded
    -- a sport's list-valued statistics from this check outright - Golf's 246 of them - and
    -- compared the claimed discipline against one event where several were named. The events
    -- are reached through the statistic's own tournament: an id landing outside it is a
    -- resolution defect and belongs to GLOBAL-DQ-101, not to a discipline contradiction.
    JOIN tournament_stage tse ON tse.tournamentFK = t.id AND tse.del = 'no'
    JOIN event e ON e.tournament_stageFK = tse.id AND e.del = 'no'
         AND FIND_IN_SET(e.id, TRIM(sc.value)) > 0
    JOIN object_discipline ode ON ode.object_typeFK = 5 AND ode.objectFK = e.id AND ode.del = 'no'
    JOIN discipline de ON de.id = ode.disciplineFK AND de.del = 'no'
    WHERE s.del = 'no'
      AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
      AND s.object_typeFK = 3
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND EXISTS (
      SELECT 1 FROM object_discipline od2
      WHERE od2.object_typeFK = 83 AND od2.objectFK = s.id AND od2.del = 'no'
  )
  AND EXISTS (
      SELECT 1 FROM statistic_config sc2
      JOIN tournament_stage tse2 ON tse2.tournamentFK = t.id AND tse2.del = 'no'
      JOIN event e2 ON e2.tournament_stageFK = tse2.id AND e2.del = 'no'
           AND FIND_IN_SET(e2.id, TRIM(sc2.value)) > 0
      JOIN object_discipline ode2 ON ode2.object_typeFK = 5 AND ode2.objectFK = e2.id AND ode2.del = 'no'
      WHERE sc2.statisticFK = s.id AND sc2.del = 'no'
        AND sc2.statistic_data_typeFK = {{CONFIG_EVENT_ID_TYPE_ID}}
        AND TRIM(COALESCE(sc2.value, '')) <> ''
        AND TRIM(sc2.value) REGEXP '^[0-9]+(,[0-9]+)*$'
  )

ORDER BY sort_order, statistic_id;

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-113
    -- Name - COMP.RANK_PARTICIPANT_TYPE_MIXED
    -- What it does: Flags Comp.Rank records that mix participant types, such as teams and athletes in one ranking.
    'Comp_Rank_Participant_Type_Mixed' AS check_type,
    x.statistic_id,
    x.statistic_name,
    x.template_name,
    x.tournament_name,
    x.types_held,
    x.distinct_types,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds Comp.Rank holding participants of more than one kind,
-- so one place sequence ranks teams against individuals.
-- A ranking answers one question about one kind of competitor, so two kinds under one place
-- sequence means either the ranking is two rankings or somebody is counted in both. Asked
-- without naming which kinds are legitimate, which is what keeps it global: the sport's own
-- participant vocabulary is GLOBAL-DQ-104's business, and a sport fielding both teams and
-- individuals is normal - what is not normal is one statistic holding both.
-- **A person is a person whichever role they hold now.** This counted participant.type
-- literally until 2026-08-20, and that field holds a person's *current* role rather than the
-- one they had at the event: 446 people typed coach appear in Ice Hockey's rankings and 406 of
-- them also occupy a playing lineup slot. Martin St. Louis, Daniel Alfredsson and Manny
-- Malhotra are typed coach and hold World Championship medals they won as players. All 60 of
-- the sport's findings were that and nothing else - not one was a team ranked against an
-- individual, which is what the check is for.
-- The person types are PERSON_ROLE_TYPE_LIST, which is neither of the two lists that already
-- existed: PERSON_PARTICIPANT_TYPE_LIST names who competes and a coach does not, while
-- REGISTRY_PARTICIPANT_TYPE_LIST includes team and, for Equestrian, horse. Collapsing the
-- person types leaves team against athlete and horse against athlete exactly where they were.
FROM (
    SELECT
        s.id AS statistic_id,
        s.name AS statistic_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        -- Every person type counts as one kind. participant.type carries a person's current
        -- role, not the role they held at the event, so a squad ranked in 2004 whose players
        -- have since become coaches reads as two kinds and is one. The types actually stored
        -- are still projected below, so nothing is hidden - only the count is corrected.
        COUNT(DISTINCT CASE WHEN p.type IN ({{PERSON_ROLE_TYPE_LIST}})
                            THEN 'person' ELSE p.type END) AS distinct_types,
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
      -- AND t.tournament_templateFK = <tournament_template_id>
    GROUP BY s.id, s.name, tt.name, t.name
    HAVING COUNT(DISTINCT CASE WHEN p.type IN ({{PERSON_ROLE_TYPE_LIST}})
                               THEN 'person' ELSE p.type END) > 1
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, statistic_id;

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-115
    -- Name - COMP.RANK_PARTICIPANT_REFERENCE_INVALID
    -- What it does: Flags Comp.Rank participants whose reference is missing or points to a deleted participant.
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
-- What it does, stated in full: Finds Comp.Rank participants whose reference resolves to no
-- participant row, or to a soft-deleted one, separating the two, with the data rows still
-- attached to them.
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, statistic_participants_id;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-121
    -- Name - COMP.RANK_RESULTS_NUMERIC_PRECISION_INCONSISTENT
    -- What it does: Flags numeric Comp.Rank fields where participants use different numbers of decimal places.
    CASE
-- What it does, stated in full: Finds Comp.Rank whose participants' values in one numeric
-- data field are not all written to the same number of decimal places, separating a value
-- stored with no decimal point at all from a fraction shorter than its neighbours.
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
          AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
;

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-125
    -- Name - COMP.RANK_MEDAL_AWARDED_OUTSIDE_MEDAL_TEMPLATE
    -- What it does: Flags Comp.Rank medals awarded under a tournament template that does not award medals in that sport.
    'MEDAL_OUTSIDE_MEDAL_TEMPLATE' AS check_type,
    x.statistic_id,
    x.statistic_name,
    x.template_id,
    x.template_name,
    x.tournament_name,
    x.medal_holder_count,
    x.distinct_medals,
-- What it does, stated in full: Finds Comp.Rank awarding a medal under a tournament template
-- that does not award medals in this sport, naming how many competitors hold one and which
-- medals were given.
    -- A convenience for the reader, not the finding: GROUP_CONCAT truncates at the server's
    -- group_concat_max_len without saying so, and medal_holder_count is counted separately and
    -- is what the row asserts.
    x.medal_holders,
    NULL AS eligible_count,
    0 AS sort_order
-- The companion of GLOBAL-DQ-026, and the other half of the same question. That check asks
-- whether a medal set follows the places its own Rank rows hold; it cannot ask whether the
-- competition was one that awards medals at all, because nothing in a statistic says so.
--
-- In a sport whose medal events are identified by their template rather than by their round
-- type, that is the only place the answer lives. MEDAL_TEMPLATE_ID_LIST names the templates
-- whose competitions award a medal, and every Comp.Rank outside them is asserted to award
-- none. A sport that has not confirmed such a list simply does not instantiate this check, and
-- GLOBAL-DQ-026 is unaffected either way.
--
-- The list states which competitions award medals and is not read off the data: a template
-- that awards medals and happens to hold none today still belongs in it, and a template
-- holding medals it should not is exactly what this check reports.
FROM (
    SELECT
        s.id AS statistic_id,
        s.name AS statistic_name,
        tt.id AS template_id,
        tt.name AS template_name,
        t.name AS tournament_name,
        COUNT(DISTINCT sp.id) AS medal_holder_count,
        GROUP_CONCAT(DISTINCT sd.value ORDER BY sd.value SEPARATOR ', ') AS distinct_medals,
        GROUP_CONCAT(DISTINCT CONCAT(p.name, ' (', sd.value, ')') ORDER BY p.name SEPARATOR ', ')
            AS medal_holders
    FROM statistic s
    JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = s.id AND sp.del = 'no'
    JOIN participant p ON p.id = sp.participantFK AND p.del = 'no'
    JOIN statistic_data{{SHARD_ID}} sd ON sd.statistic_participants{{SHARD_ID}}FK = sp.id AND sd.del = 'no'
     AND sd.statistic_data_typeFK = {{DATA_MEDAL_TYPE_ID}}
    WHERE s.del = 'no'
      AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
      AND s.object_typeFK = 3
      AND tt.sportFK = {{SPORT_ID}}
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      AND tt.id NOT IN ({{MEDAL_TEMPLATE_ID_LIST}})
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
      -- AND t.tournament_templateFK = <tournament_template_id>
      AND sd.value IS NOT NULL
      AND TRIM(sd.value) <> ''
    GROUP BY s.id, s.name, tt.id, tt.name, t.name
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
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND tt.sportFK = {{SPORT_ID}}
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND tt.id NOT IN ({{MEDAL_TEMPLATE_ID_LIST}})
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, medal_holder_count DESC, statistic_id;

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-131
    -- Name - COMP.RANK_PARTICIPANT_ORGANIZATION_MISSING
    -- What it does: Finds tournaments whose Comp.Rank participants carry no Organization value, either none of them at all or only some.
    CASE
        WHEN x.with_organization = 0 THEN 'TOURNAMENT_COMP.RANK_CARRIES_NO_ORGANIZATION_AT_ALL'
        ELSE 'TOURNAMENT_COMP.RANK_ORGANIZATION_PARTLY_FILLED'
    END AS check_type,
    x.tournament_id,
    x.tournament_name,
    x.template_name,
    x.statistics,
    x.ranked_participants,
    x.with_organization,
    x.without_organization,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: The same rule as GLOBAL-DQ-130 asked of the Comp.Rank layer, and
-- a separate statement because the storage has nothing in common with it. The event layer keeps
-- the organization as a reference-typed `property` row hanging off `event_participants`; the
-- statistic layer keeps it as an ordinary data field, `statistic_data_type` 1465 Organization,
-- declared for statistic type 11 and holding a participant id. One rule, two mechanisms, two
-- CheckIDs - and a sport can fill either without the other.
-- **An unfilled Organization is a defect, not an inapplicable check**, for the reason
-- GLOBAL-DQ-130 states at length: the field is declared for the statistic type, Artistic
-- Gymnastics and Triathlon fill it, and reading an empty population as `Not applicable` would
-- switch the check off for the sports it exists to catch. Measured 2026-08-21 over the eleven
-- documented sports, about 908 000 ranked participations of 1.15 million carry no Organization,
-- and nine of the eleven carry not one.
-- **The audited object is the tournament**, matching GLOBAL-DQ-130 and departing from the usual
-- convention of this file, which audits the statistic. The departure is deliberate: what is
-- missing here is a feed field for a whole competition, and one tournament's rankings are one
-- feed however many statistics it holds - Golf averages roughly eight per tournament, so the
-- statistic as the object would report the same absent field eight times over. `statistics`,
-- `ranked_participants`, `with_organization` and `without_organization` carry the detail as
-- named secondary columns.
-- Tournament-owned statistics only, and IOC-purpose templates excluded in both branches, as
-- every statistic statement in this file does.
FROM (
    SELECT
        t.id AS tournament_id,
        t.name AS tournament_name,
        tt.name AS template_name,
        COUNT(DISTINCT s.id) AS statistics,
        COUNT(*) AS ranked_participants,
        SUM(CASE WHEN og.id IS NOT NULL THEN 1 ELSE 0 END) AS with_organization,
        SUM(CASE WHEN og.id IS NULL THEN 1 ELSE 0 END) AS without_organization
    FROM statistic s
    JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = {{SPORT_ID}}
    JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = s.id AND sp.del = 'no'
    LEFT JOIN statistic_data{{SHARD_ID}} og
           ON og.statistic_participants{{SHARD_ID}}FK = sp.id
          AND og.statistic_data_typeFK = {{DATA_ORGANIZATION_TYPE_ID}}
          AND og.del = 'no'
    WHERE s.del = 'no'
      AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
      AND s.object_typeFK = 3
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
      -- AND t.tournament_templateFK = <tournament_template_id>
    GROUP BY t.id, t.name, tt.name
    HAVING SUM(CASE WHEN og.id IS NULL THEN 1 ELSE 0 END) > 0
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT t.id) AS eligible_count,
    1 AS sort_order
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = {{SPORT_ID}}
JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = s.id AND sp.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, without_organization DESC, tournament_id;

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-134
    -- Name - COMP.RANK_RESULTS_RANK_SEQUENCE_BROKEN
    -- What it does: Finds Comp.Rank sequences that do not run 1, 2, 3 with ties skipping the places they consume.
    CASE
        WHEN x.start_breaks > 0 THEN 'RANK_SEQUENCE_DOES_NOT_START_AT_ONE'
        WHEN x.gaps > 0 THEN 'RANK_SEQUENCE_GAP'
        ELSE 'RANK_SEQUENCE_TIE_DOES_NOT_SKIP'
    END AS check_type,
    x.statistic_id,
    x.statistic_name,
    x.ranking_start_date,
    x.template_name,
    x.tournament_name,
    x.breaks,
    x.break_detail,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds Comp.Rank whose Rank sequence is not a standard
-- competition ranking - a place nobody holds, a tie that does not consume the places it
-- stands for, or a sequence that does not start at one - naming each break where the
-- sequence actually breaks rather than every place it shifts afterwards, together with a
-- coverage count of all eligible rankings holding at least one usable Rank.
-- This is the Comp.Rank counterpart of GLOBAL-DQ-119 and asks the same question one layer
-- up, where until 2026-08-24 nothing asked it at all. The gap it closes is not theoretical:
-- Triathlon statistic 318568, World Cup - Ishigaki Female - Competition Rank, hands out
-- places 1 to 46 with place 34 held by nobody, and every existing statement is silent on it.
-- GLOBAL-DQ-012 is silent because the twelve unranked competitors there each carry a dnf,
-- which that statement accepts as the explanation for a missing Rank and is right to accept;
-- GLOBAL-DQ-031 is silent because the highest place, 46, is below the field of 57;
-- GLOBAL-DQ-032 is silent because the ranking does hold Rank data; and GLOBAL-DQ-095 is
-- silent because no place is duplicated. A missing place in the middle of a ranking is
-- invisible to all four, which is what this statement is for.
-- A break is reported where the sequence breaks, not at every place it displaces, for the
-- reason GLOBAL-DQ-119 records in full: restating a single missing place once for every
-- place after it turned five breaks into 212 rows on one measured event, and the object set
-- is identical either way.
-- Ties are what make the naive form of this question wrong rather than merely noisy. A
-- standard ranking of 1, 2, 3, 3, 5 leaves place 4 held by nobody and is entirely correct,
-- so comparing the count of distinct places against the highest one reports it as a defect:
-- measured on Triathlon 2026-08-24, that form returns 235 rankings where this statement
-- returns 18, and 217 of the 235 are the sport ranking correctly.
-- The start-at-one branch is not redundant with the step branch: a sequence running 2, 3, 4
-- has correct steps throughout and is invisible without it. Neither sport measured on
-- 2026-08-24 holds one, which is a data state rather than a structural absence, so the
-- branch stays.
-- A place is counted by its holders, not by its rows, and this is the one thing the event
-- layer never had to face. On the Comp.Rank layer a team's athletes each carry a row of their
-- own holding the team's place, so counting rows reads a relay squad of three as three
-- competitors tied on one place and then reports the ranking for not skipping two places it
-- never consumed. Measured on Triathlon 2026-08-24: counting rows returned 122 findings, 104
-- of them team rankings behaving correctly - statistic 319037 among them, whose places 1 to 5
-- are each held by three athletes carrying one and the same Team value. Holders are counted
-- the way GLOBAL-DQ-072 counts them, by the Team field where one is written and by the
-- participant where none is. A place whose rows carry no Team at all is still counted per row,
-- which is the honest reading: with the field empty nothing in the data says they are one
-- team, and GLOBAL-DQ-064 is the statement that reports the empty field.
-- The audited object is the ranking, not the competitor. A place nobody holds is one repair
-- to one ranking, and breaks and break_detail carry the detail as named secondary columns.
-- The date the ranking declares for itself travels with the row, as it does in GLOBAL-DQ-012
-- and for the same reason: a Comp.Rank covers a whole tournament rather than one contest, so
-- without its configured start a finding names a season and nothing narrower.
-- **A Comp.Rank whose name carries `(athletes)` is not read at all.** Such a ranking lists the
-- members of each squad and gives every one of them the place their team finished in, so a
-- squad of twenty holds rank 1 twenty times and the next team's members hold rank 2. That is
-- the format working, not a sequence with nineteen places missing. The holder count already
-- collapses them where the Team field is filled, which is why this was invisible until it was
-- looked for: measured 2026-08-25 across the twelve documented sports, 52 athlete rankings
-- reported 352 breaks purely because some of their participants carry no Team value and could
-- not be collapsed - 250 of them in Triathlon alone, where 1540 of 5199 athlete rows have no
-- Team. Filling that field would silence those, but it would not make the rankings worth
-- reading here: an athlete ranking's places are its team ranking's places, so a real gap in it
-- is a gap the team ranking already reports, and reporting it twice asks for one repair in two
-- places. 3168 of the 3179 athlete rankings have a team twin under the same tournament, so
-- excluding them costs coverage on eleven rankings and no invariant at all.
-- What the exclusion does **not** do is check that an athlete ranking agrees with its twin.
-- Nothing does today; `GLOBAL_DQ/README.md` records it as a candidate.
FROM (
    SELECT
        b.statistic_id,
        s.name AS statistic_name,
        cfg.value AS ranking_start_date,
        tt.name AS template_name,
        t.name AS tournament_name,
        COUNT(*) AS breaks,
        SUM(CASE WHEN b.break_kind = 'START' THEN 1 ELSE 0 END) AS start_breaks,
        SUM(CASE WHEN b.break_kind = 'GAP' THEN 1 ELSE 0 END) AS gaps,
        GROUP_CONCAT(b.break_text ORDER BY b.at_place SEPARATOR ' | ') AS break_detail
    FROM (
        SELECT
            w.statistic_id,
            w.rank_value AS at_place,
            CASE
                WHEN w.prev_rank IS NULL AND w.rank_value <> 1 THEN 'START'
                WHEN w.next_rank > w.rank_value + (w.places_taken DIV w.entry_size) THEN 'GAP'
                ELSE 'TIE'
            END AS break_kind,
            CASE
                WHEN w.prev_rank IS NULL AND w.rank_value <> 1
                    THEN CONCAT('sequence starts at ', w.rank_value, ', expected 1')
                ELSE CONCAT('place ', w.rank_value,
                            CASE WHEN (w.places_taken DIV w.entry_size) > 1
                                 THEN CONCAT(' shared by ', w.places_taken DIV w.entry_size) ELSE '' END,
                            CASE WHEN w.entry_size > 1
                                 THEN CONCAT(' (entries of ', w.entry_size, ')') ELSE '' END,
                            ' is followed by ', w.next_rank,
                            ', expected ', w.rank_value + (w.places_taken DIV w.entry_size))
            END AS break_text
        FROM (
            SELECT
                w1.statistic_id,
                w1.rank_value,
                w1.places_taken,
                w1.prev_rank,
                w1.next_rank,
                -- The size of one entry, read from the ranking itself and accepted only if the
                -- sport has declared it. A ranking whose every group divides its own step by one
                -- constant is describing an entry of that many competitors: a rider and a horse
                -- ranked as one, or a pair sharing a place in a team golf event. Where no single
                -- constant fits, or the one that fits is not a size this sport enters, the entry
                -- is one competitor and the strict rule applies unchanged.
                CASE WHEN MIN(w1.divides)     OVER (PARTITION BY w1.statistic_id) = 1
                      AND MIN(w1.entry_guess) OVER (PARTITION BY w1.statistic_id)
                        = MAX(w1.entry_guess) OVER (PARTITION BY w1.statistic_id)
                      AND MIN(w1.entry_guess) OVER (PARTITION BY w1.statistic_id)
                            IN ({{COMP_RANK_ENTRY_SIZE_LIST}})
                     THEN MIN(w1.entry_guess) OVER (PARTITION BY w1.statistic_id)
                     ELSE 1 END AS entry_size
            FROM (
                SELECT
                    w0.statistic_id,
                    w0.rank_value,
                    w0.places_taken,
                    w0.prev_rank,
                    w0.next_rank,
                    CASE WHEN w0.next_rank - w0.rank_value > 0
                          AND w0.places_taken MOD (w0.next_rank - w0.rank_value) = 0
                         THEN w0.places_taken DIV (w0.next_rank - w0.rank_value) END AS entry_guess,
                    CASE WHEN w0.next_rank IS NULL THEN 1
                         WHEN w0.next_rank - w0.rank_value > 0
                          AND w0.places_taken MOD (w0.next_rank - w0.rank_value) = 0 THEN 1
                         ELSE 0 END AS divides
                FROM (
            SELECT
                ranked.statistic_id,
                ranked.rank_value,
                ranked.places_taken,
                LAG(ranked.rank_value)  OVER (PARTITION BY ranked.statistic_id ORDER BY ranked.rank_value) AS prev_rank,
                LEAD(ranked.rank_value) OVER (PARTITION BY ranked.statistic_id ORDER BY ranked.rank_value) AS next_rank
            FROM (
                SELECT
                    s2.id AS statistic_id,
                    CAST(sd.value AS UNSIGNED) AS rank_value,
                    COUNT(DISTINCT COALESCE(TRIM(tmd.value), CONCAT('p', sp.id))) AS places_taken
                FROM statistic s2
                JOIN tournament t2 ON t2.id = s2.objectFK AND t2.del = 'no'
                JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
                     AND tt2.sportFK = {{SPORT_ID}}
                JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = s2.id AND sp.del = 'no'
                JOIN statistic_data{{SHARD_ID}} sd
                  ON sd.statistic_participants{{SHARD_ID}}FK = sp.id
                 AND sd.del = 'no'
                 AND sd.statistic_data_typeFK = {{DATA_RANK_TYPE_ID}}
                 AND sd.value REGEXP '^[1-9][0-9]*$'
                LEFT JOIN statistic_data{{SHARD_ID}} tmd
                  ON tmd.statistic_participants{{SHARD_ID}}FK = sp.id
                 AND tmd.del = 'no'
                 AND tmd.statistic_data_typeFK = {{DATA_TEAM_TYPE_ID}}
                 AND tmd.value IS NOT NULL
                 AND TRIM(tmd.value) <> ''
                WHERE s2.del = 'no'
                  AND s2.statistic_typeFK = {{STATISTIC_TYPE_ID}}
                  AND s2.object_typeFK = 3
                  AND (tt2.name IS NULL OR tt2.name NOT LIKE '%(IOC)%')
                  AND LOWER(s2.name) NOT LIKE '%(athletes)%'
                  AND t2.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
                  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
                  -- AND t2.tournament_templateFK = <tournament_template_id>
                GROUP BY s2.id, CAST(sd.value AS UNSIGNED)
            ) ranked
                ) w0
            ) w1
        ) w
        WHERE (w.prev_rank IS NULL AND w.rank_value <> 1)
           OR (w.next_rank IS NOT NULL AND w.next_rank <> w.rank_value + (w.places_taken DIV w.entry_size))
    ) b
    JOIN statistic s ON s.id = b.statistic_id AND s.del = 'no'
    JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    LEFT JOIN statistic_config cfg
           ON cfg.statisticFK = s.id
          AND cfg.statistic_data_typeFK = {{CONFIG_START_DATE_TYPE_ID}}
          AND cfg.del = 'no'
    GROUP BY b.statistic_id, s.name, cfg.value, tt.name, t.name
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
     AND tt.sportFK = {{SPORT_ID}}
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND LOWER(s.name) NOT LIKE '%(athletes)%'
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND EXISTS (
      SELECT 1
      FROM statistic_participants{{SHARD_ID}} sp3
      JOIN statistic_data{{SHARD_ID}} sd3
        ON sd3.statistic_participants{{SHARD_ID}}FK = sp3.id
       AND sd3.del = 'no'
       AND sd3.statistic_data_typeFK = {{DATA_RANK_TYPE_ID}}
       AND sd3.value REGEXP '^[1-9][0-9]*$'
      WHERE sp3.statisticFK = s.id AND sp3.del = 'no'
  )

ORDER BY sort_order, statistic_id;

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-136
    -- Name - COMP.RANK_PARTICIPANT_ORGANIZATION_COUNTRY_CONTRADICTS_COMPETITOR
    -- What it does: Finds Comp.Rank organizations whose country is not the country of the competitors ranked under them.
    CASE
        WHEN x.organization_name = x.competitor_country
            THEN 'ORGANIZATION_NAMED_FOR_THE_COMPETITOR_COUNTRY'
        ELSE 'ORGANIZATION_COUNTRY_CONTRADICTS_COMPETITOR'
    END AS check_type,
    x.organization_id,
    x.organization_name,
    x.organization_country,
    x.competitor_country_id,
    x.competitor_country,
    x.template_id,
    x.template_name,
    x.competitors,
    x.ranked_participations,
    x.sample_competitors,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: A competitor ranked under an organization is normally ranked
-- under their own country's, and this reports where the two countries disagree.
-- **The competitor country travels with its id**, added 2026-08-25, because the audited object
-- is the organization together with that country and the name alone cannot key it. The live
-- sheet ties a reviewer's note to a finding by the result's id columns, so a dimension carried
-- only as a name is invisible to it: two findings about one organization under two countries
-- read as one, and before `TOOLS/Sheets.ps1` learned to refuse that, the second reviewer's
-- conclusion was written over the first without reaching the Review log. The repository rule is
-- older than the sheet - an id travels with the name of the thing it identifies - and this is
-- what it is for.
-- **The template is part of the audited object here, and it was made so deliberately on
-- 2026-08-25 rather than left as an accident of the GROUP BY.** `template_name` had been in the
-- GROUP BY since the statement was written, which made a finding row one per organization,
-- competitor country and template while the COVERAGE branch counted one per organization and
-- competitor country - a finding finer than an eligible one, which the coverage contract does
-- not allow. Two ways out and they are different checks: aggregate the templates and report one
-- row per organization and country, as `GLOBAL-DQ-132` does on the event layer, or keep the
-- template and make the coverage agree. The second was chosen, so `template_id` is now projected
-- beside its name and the COVERAGE branch counts organization, competitor country and template.
-- **Why the template earns its place here and not on the event layer.** A Comp.Rank is one
-- competition's ranking and the organization is declared inside it, so the same organization
-- ranked under two competitions is two declarations somebody made and two places to correct
-- them. An event participation carries the organization as a property of the entry itself, and
-- `GLOBAL-DQ-132` is right to gather those into one row per organization and country.
-- Without the id this was also the reason a reviewer's note could not be kept: measured
-- 2026-08-25 on Artistic-Gymnastics-DQ-111, organization 1611294 returns two findings under two
-- templates, and the key built from the id columns could not tell them apart. `TOOLS/Sheets.ps1`
-- reported both notes to the Review log rather than guessing; with the id it no longer has to.
-- It is the Comp.Rank counterpart of GLOBAL-DQ-132 and asks that template's question one layer
-- up, where until 2026-08-24 nothing asked it. The two are the same rule over two mechanisms
-- and a sport can fill either without the other, which is the same pairing GLOBAL-DQ-130 and
-- GLOBAL-DQ-131 already record for the presence of the field: on the event layer the
-- organization is the `organizationFK` property of a participation, here it is the
-- Organization data type declared for the statistic type, holding a participant id.
-- GLOBAL-DQ-131 asserts that the field is filled; this asks whether what is in it is right.
-- A sport filling none of it has an eligible population of 0, which is a sentinel rather than
-- clean data, and GLOBAL-DQ-131 is what reports the absence.
-- **Its signal is Monitor and it expects a non-zero count forever**, for the reason
-- GLOBAL-DQ-132 records: a neutral athlete ranked under `Individual Neutral Athletes`, whose
-- country is `International`, is recorded exactly as it should be, and a refugee team is the
-- same shape. It is worth having anyway because agreement is overwhelmingly the rule.
-- **The audited object is the organization together with the competitor country**, not the
-- ranked participation and not the competitor, exactly as in GLOBAL-DQ-132. One disagreement is
-- one decision however many people it caught, and on this layer the difference is larger than on
-- the event layer rather than smaller: a Comp.Rank lists a relay athlete by athlete where an
-- event enters the team as one participant, so the same decision gathers more rows here.
-- `competitors`, `ranked_participations` and `sample_competitors` carry the detail as named
-- secondary columns.
-- The two branches separate two quite different repairs, and the split is GLOBAL-DQ-132's:
-- where the organization's own name is the competitor's country, the two are one place held
-- under two `country` rows, which is a single reference-layer correction and not a crowd of
-- misfiled competitors. Where the names differ it is a competitor question - a federation
-- change, a neutral entry, or an error.
-- An Organization value that does not resolve to a live participant drops out of both branches
-- rather than being reported here, because an unresolvable reference is a different defect and
-- GLOBAL-DQ-115 is where this layer's participant references are judged.
-- Tournament-owned statistics only, template_name projected and IOC-purpose templates excluded
-- in both branches, as every statistic statement in this file does.
FROM (
    SELECT
        org.id AS organization_id,
        org.name AS organization_name,
        oc.name AS organization_country,
        pc.id AS competitor_country_id,
        pc.name AS competitor_country,
        tt.id AS template_id,
        tt.name AS template_name,
        COUNT(DISTINCT sp.participantFK) AS competitors,
        COUNT(*) AS ranked_participations,
        SUBSTRING(GROUP_CONCAT(DISTINCT pt.name ORDER BY pt.name SEPARATOR ', '), 1, 200) AS sample_competitors
    FROM statistic s
    JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = {{SPORT_ID}}
    JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = s.id AND sp.del = 'no'
    JOIN statistic_data{{SHARD_ID}} og
      ON og.statistic_participants{{SHARD_ID}}FK = sp.id
     AND og.statistic_data_typeFK = {{DATA_ORGANIZATION_TYPE_ID}}
     AND og.del = 'no'
     AND og.value REGEXP '^[1-9][0-9]*$'
    JOIN participant pt ON pt.id = sp.participantFK AND pt.del = 'no'
    JOIN participant org ON org.id = CAST(og.value AS UNSIGNED) AND org.del = 'no'
    JOIN country oc ON oc.id = org.countryFK
    JOIN country pc ON pc.id = pt.countryFK
    WHERE s.del = 'no'
      AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
      AND s.object_typeFK = 3
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      AND org.countryFK <> pt.countryFK
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
      -- AND t.tournament_templateFK = <tournament_template_id>
    GROUP BY org.id, org.name, oc.name, pc.id, pc.name, tt.id, tt.name
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT CONCAT(org.id, '#', pt.countryFK, '#', t.tournament_templateFK)) AS eligible_count,
    1 AS sort_order
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = {{SPORT_ID}}
JOIN statistic_participants{{SHARD_ID}} sp ON sp.statisticFK = s.id AND sp.del = 'no'
JOIN statistic_data{{SHARD_ID}} og
  ON og.statistic_participants{{SHARD_ID}}FK = sp.id
 AND og.statistic_data_typeFK = {{DATA_ORGANIZATION_TYPE_ID}}
 AND og.del = 'no'
 AND og.value REGEXP '^[1-9][0-9]*$'
JOIN participant pt ON pt.id = sp.participantFK AND pt.del = 'no'
JOIN participant org ON org.id = CAST(og.value AS UNSIGNED) AND org.del = 'no'
JOIN country oc ON oc.id = org.countryFK
JOIN country pc ON pc.id = pt.countryFK
WHERE s.del = 'no'
  AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND s.object_typeFK = 3
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, competitors DESC, organization_id;
