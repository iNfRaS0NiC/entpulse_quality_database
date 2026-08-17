SELECT
    -- CheckID - Triathlon-DQ-068
    -- Name - EVENT_SETTINGS_DISCIPLINE_NAME_MISMATCH
    -- What it does: Finds events whose name gives a discipline that is missing from its relations.
    'EVENT_DISCIPLINE_NOT_MATCHING_NAME' AS check_type,
    x.event_id,
    x.event_name,
    CASE x.expected_discipline_id
        WHEN 144 THEN 'Standard Distance'
        WHEN 799 THEN 'Sprint Distance'
        WHEN 800 THEN 'Mixed Relay'
        WHEN 801 THEN 'Super Sprint Distance'
        WHEN 803 THEN 'Team Relay'
        WHEN 804 THEN 'Long Distance / Ironman'
    END AS expected_discipline_name,
    (SELECT GROUP_CONCAT(DISTINCT d2.name ORDER BY d2.name SEPARATOR ', ')
-- What it does, stated in full: Finds events whose name names a discipline the event's own
-- relations do not carry, resolving Super Sprint before Sprint and both relay formats before
-- either. An Aquathlon-named event is excluded rather than reported, being outside the
-- sport's DQ scope.
       FROM object_discipline od2
       JOIN discipline d2 ON d2.id = od2.disciplineFK AND d2.del = 'no'
      WHERE od2.object_typeFK = 5 AND od2.objectFK = x.event_id AND od2.del = 'no') AS actual_discipline_names,
    COALESCE((SELECT TRIM(pr.value) FROM property pr
               WHERE pr.object = 'event' AND pr.objectFK = x.event_id AND pr.del = 'no'
                 AND LOWER(TRIM(pr.name)) = 'discipline' LIMIT 1), '(none)') AS property_discipline,
    x.template_name,
    x.tournament_name,
    x.stage_name,
    NULL AS eligible_count,
    0 AS sort_order
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        ts.name AS stage_name,
        CASE
            WHEN LOWER(e.name) LIKE '%aquathlon%'     THEN NULL
            WHEN LOWER(e.name) LIKE '%super sprint%'  THEN 801
            WHEN LOWER(e.name) LIKE '%mixed relay%'   THEN 800
            WHEN LOWER(e.name) LIKE '%team relay%'    THEN 803
            WHEN LOWER(e.name) LIKE '%ironman%'       THEN 804
            WHEN LOWER(e.name) LIKE '%long distance%' THEN 804
            WHEN LOWER(e.name) LIKE '%sprint%'        THEN 799
            WHEN LOWER(e.name) LIKE '%standard%'      THEN 144
            ELSE NULL
        END AS expected_discipline_id
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    WHERE e.del = 'no'
      AND tt.sportFK = 50
      AND e.name IS NOT NULL
      AND TRIM(e.name) <> ''
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
      AND EXISTS (
          SELECT 1 FROM object_discipline od
          WHERE od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
            AND od.disciplineFK IN (144, 799, 800, 801, 803, 804)
      )
) x
WHERE x.expected_discipline_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM object_discipline od3
      WHERE od3.object_typeFK = 5 AND od3.objectFK = x.event_id AND od3.del = 'no'
        AND od3.disciplineFK = x.expected_discipline_id
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT c.event_id) AS eligible_count,
    1 AS sort_order
FROM (
    SELECT
        e.id AS event_id,
        CASE
            WHEN LOWER(e.name) LIKE '%aquathlon%'     THEN NULL
            WHEN LOWER(e.name) LIKE '%super sprint%'  THEN 801
            WHEN LOWER(e.name) LIKE '%mixed relay%'   THEN 800
            WHEN LOWER(e.name) LIKE '%team relay%'    THEN 803
            WHEN LOWER(e.name) LIKE '%ironman%'       THEN 804
            WHEN LOWER(e.name) LIKE '%long distance%' THEN 804
            WHEN LOWER(e.name) LIKE '%sprint%'        THEN 799
            WHEN LOWER(e.name) LIKE '%standard%'      THEN 144
            ELSE NULL
        END AS expected_discipline_id
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    WHERE e.del = 'no'
      AND tt.sportFK = 50
      AND e.name IS NOT NULL
      AND TRIM(e.name) <> ''
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
      AND EXISTS (
          SELECT 1 FROM object_discipline od
          WHERE od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
            AND od.disciplineFK IN (144, 799, 800, 801, 803, 804)
      )
) c
WHERE c.expected_discipline_id IS NOT NULL

ORDER BY sort_order, event_id;


-- ================================================================================
SELECT
    -- CheckID - Triathlon-DQ-069
    -- Name - EVENT_RESULTS_FULL_TIME_OUT_OF_DISCIPLINE_BAND
    -- What it does: Finds Full times that look too short, too long, or more than twice the event's fastest time.
    CASE
        WHEN x.secs < x.floor_secs   THEN 'FULL_TIME_BELOW_DISCIPLINE_FLOOR'
        WHEN x.secs > x.ceiling_secs THEN 'FULL_TIME_ABOVE_DISCIPLINE_CEILING'
        ELSE 'FULL_TIME_OVER_TWICE_EVENT_FASTEST'
    END AS check_type,
    x.event_participants_id,
    x.event_id,
    x.event_name,
    x.participant_name,
    CASE x.discipline_id
        WHEN 144 THEN 'Standard Distance'
        WHEN 799 THEN 'Sprint Distance'
        WHEN 800 THEN 'Mixed Relay'
        WHEN 801 THEN 'Super Sprint Distance'
        WHEN 803 THEN 'Team Relay'
        WHEN 804 THEN 'Long Distance / Ironman'
    END AS discipline_name,
    x.rank_value,
    x.full_time_value,
    x.secs AS full_time_seconds,
    w.fastest_secs AS event_fastest_seconds,
    x.template_name,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds participants whose full time is implausible for the
-- discipline raced: below its floor, above its ceiling, or more than twice the fastest full
-- time in the same event. The bands are judgement values rather than official cut-offs, so a
-- finding is a review candidate.
FROM (
    SELECT
        b.event_participants_id,
        b.event_id,
        b.event_name,
        b.participant_name,
        b.template_name,
        b.discipline_id,
        b.rank_value,
        b.full_time_value,
        b.secs,
        CASE b.discipline_id
            WHEN 801 THEN 600
            WHEN 799 THEN 2100
            WHEN 144 THEN 4800
            WHEN 804 THEN 18000
            WHEN 800 THEN 2700
            WHEN 803 THEN 2700
        END AS floor_secs,
        CASE b.discipline_id
            WHEN 801 THEN 2700
            WHEN 799 THEN 7200
            WHEN 144 THEN 14400
            WHEN 804 THEN 64800
            WHEN 800 THEN 10800
            WHEN 803 THEN 10800
        END AS ceiling_secs
    FROM (
        SELECT
            ep.id AS event_participants_id,
            e.id AS event_id,
            e.name AS event_name,
            p.name AS participant_name,
            tt.name AS template_name,
            TRIM(rr.value) AS rank_value,
            TRIM(rf.value) AS full_time_value,
            (SELECT od2.disciplineFK FROM object_discipline od2
              WHERE od2.object_typeFK = 5 AND od2.objectFK = e.id AND od2.del = 'no'
                AND od2.disciplineFK IN (144, 799, 800, 801, 803, 804)
              ORDER BY od2.disciplineFK LIMIT 1) AS discipline_id,
            CASE
                WHEN TRIM(rf.value) REGEXP '^[0-9]+:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?$'
                    THEN CAST(SUBSTRING_INDEX(TRIM(rf.value), ':', 1) AS DECIMAL(14,3)) * 3600
                       + CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(TRIM(rf.value), ':', 2), ':', -1) AS DECIMAL(14,3)) * 60
                       + CAST(SUBSTRING_INDEX(TRIM(rf.value), ':', -1) AS DECIMAL(14,3))
                WHEN TRIM(rf.value) REGEXP '^[0-9]+:[0-9]{2}(\\.[0-9]+)?$'
                    THEN CAST(SUBSTRING_INDEX(TRIM(rf.value), ':', 1) AS DECIMAL(14,3)) * 60
                       + CAST(SUBSTRING_INDEX(TRIM(rf.value), ':', -1) AS DECIMAL(14,3))
                ELSE CAST(TRIM(rf.value) AS DECIMAL(14,3))
            END AS secs
        FROM event_participants ep
        JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
        JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
        JOIN result rr ON rr.event_participantsFK = ep.id AND rr.result_typeFK = 100 AND rr.del = 'no'
        JOIN result rf ON rf.event_participantsFK = ep.id AND rf.result_typeFK = 557 AND rf.del = 'no'
        WHERE ep.del = 'no'
          AND tt.sportFK = 50
          AND TRIM(rr.value) REGEXP '^[0-9]+$'
          AND TRIM(rf.value) REGEXP '^[0-9]+(:[0-9]{2}){0,2}(\\.[0-9]+)?$'
          -- AND t.tournament_templateFK = <tournament_template_id>
          -- AND e.startdate >= '<from_datetime>'
          -- AND e.startdate <  '<to_datetime>'
          AND EXISTS (
              SELECT 1 FROM object_discipline od
              WHERE od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
                AND od.disciplineFK IN (144, 799, 800, 801, 803, 804)
          )
    ) b
) x
JOIN (
    SELECT wb.event_id, MIN(wb.secs) AS fastest_secs
    FROM (
        SELECT
            e.id AS event_id,
            CASE
                WHEN TRIM(rf.value) REGEXP '^[0-9]+:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?$'
                    THEN CAST(SUBSTRING_INDEX(TRIM(rf.value), ':', 1) AS DECIMAL(14,3)) * 3600
                       + CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(TRIM(rf.value), ':', 2), ':', -1) AS DECIMAL(14,3)) * 60
                       + CAST(SUBSTRING_INDEX(TRIM(rf.value), ':', -1) AS DECIMAL(14,3))
                WHEN TRIM(rf.value) REGEXP '^[0-9]+:[0-9]{2}(\\.[0-9]+)?$'
                    THEN CAST(SUBSTRING_INDEX(TRIM(rf.value), ':', 1) AS DECIMAL(14,3)) * 60
                       + CAST(SUBSTRING_INDEX(TRIM(rf.value), ':', -1) AS DECIMAL(14,3))
                ELSE CAST(TRIM(rf.value) AS DECIMAL(14,3))
            END AS secs
        FROM event_participants ep
        JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
        JOIN result rr ON rr.event_participantsFK = ep.id AND rr.result_typeFK = 100 AND rr.del = 'no'
        JOIN result rf ON rf.event_participantsFK = ep.id AND rf.result_typeFK = 557 AND rf.del = 'no'
        WHERE ep.del = 'no'
          AND tt.sportFK = 50
          AND TRIM(rr.value) REGEXP '^[0-9]+$'
          AND TRIM(rf.value) REGEXP '^[0-9]+(:[0-9]{2}){0,2}(\\.[0-9]+)?$'
          -- AND t.tournament_templateFK = <tournament_template_id>
          -- AND e.startdate >= '<from_datetime>'
          -- AND e.startdate <  '<to_datetime>'
          AND EXISTS (
              SELECT 1 FROM object_discipline od
              WHERE od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
                AND od.disciplineFK IN (144, 799, 800, 801, 803, 804)
          )
    ) wb
    GROUP BY wb.event_id
) w ON w.event_id = x.event_id
WHERE x.secs IS NOT NULL
  AND (
        x.secs < x.floor_secs
     OR x.secs > x.ceiling_secs
     OR (w.fastest_secs > 0 AND x.secs > 2 * w.fastest_secs)
      )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ep.id) AS eligible_count,
    1 AS sort_order
FROM event_participants ep
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN result rr ON rr.event_participantsFK = ep.id AND rr.result_typeFK = 100 AND rr.del = 'no'
JOIN result rf ON rf.event_participantsFK = ep.id AND rf.result_typeFK = 557 AND rf.del = 'no'
WHERE ep.del = 'no'
  AND tt.sportFK = 50
  AND TRIM(rr.value) REGEXP '^[0-9]+$'
  AND TRIM(rf.value) REGEXP '^[0-9]+(:[0-9]{2}){0,2}(\\.[0-9]+)?$'
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND EXISTS (
      SELECT 1 FROM object_discipline od
      WHERE od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
        AND od.disciplineFK IN (144, 799, 800, 801, 803, 804)
  )

ORDER BY sort_order, event_id, full_time_seconds DESC;


-- ================================================================================
SELECT
    -- CheckID - Triathlon-DQ-070
    -- Name - EVENT_RESULTS_DURATION_SHAPE_UNCONFIRMED
    -- What it does: Flags Duration or Full-time values that do not match the approved time formats or contain impossible minute or second values.
    CASE
        WHEN x.plus_prefixed_full_time_count > 0 THEN 'FULL_TIME_PLUS_PREFIXED'
        ELSE 'DURATION_SHAPE_NOT_CONFIRMED'
    END AS check_type,
    x.event_participants_id,
    x.event_id,
    x.event_name,
    x.participant_name,
    x.violating_value_count,
    x.violating_values,
    x.tournament_template_name,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds Duration or Full-time values outside the sport's
-- confirmed shapes - an optionally plus-prefixed h:mm:ss.f, m:ss.f or ss.f for the gap and
-- the same forms without a plus for the absolute - where only the leading field is
-- unbounded, so an impossible time such as 1:99:99.9 is not read as confirmed.
FROM (
    SELECT
        ep.id AS event_participants_id,
        e.id AS event_id,
        e.name AS event_name,
        p.name AS participant_name,
        tt.name AS tournament_template_name,
        COUNT(DISTINCT r.id) AS violating_value_count,
        SUM(CASE WHEN r.result_typeFK = 557 AND TRIM(r.value) LIKE '+%' THEN 1 ELSE 0 END)
            AS plus_prefixed_full_time_count,
        GROUP_CONCAT(DISTINCT CONCAT(r.result_typeFK, '=', TRIM(r.value))
                     ORDER BY 1 SEPARATOR ' | ') AS violating_values
    FROM event_participants ep
    JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
    JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
         AND r.result_typeFK IN (101, 557)
    WHERE ep.del = 'no'
      AND tt.sportFK = 50
      AND r.value IS NOT NULL
      AND TRIM(r.value) <> ''
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
      AND EXISTS (
          SELECT 1 FROM object_discipline od
          WHERE od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
            AND od.disciplineFK IN (144, 799, 800, 801, 803, 804)
      )
      AND (
            -- The shape set spelled out rather than approximated. [0-9:]+ accepted any
            -- arrangement of digits and colons, so 1:99:99.9 and 1:2:3.4 passed as
            -- confirmed shapes. Only the leading field is unbounded - a race may run past
            -- an hour, and past a hundred minutes when stored without one - while every
            -- field after a colon is a two-digit 0-59. This subsumes the separate empty
            -- field and colon-count guards that used to stand beside it.
            TRIM(r.value) NOT REGEXP '^\\+?([0-9]+:[0-5][0-9]:[0-5][0-9]|[0-9]+:[0-5][0-9]|[0-9]+)\\.[0-9]+$'
         OR (r.result_typeFK = 557 AND TRIM(r.value) LIKE '+%')
          )
    GROUP BY ep.id, e.id, e.name, p.name, tt.name
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ep.id) AS eligible_count,
    1 AS sort_order
FROM event_participants ep
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
     AND r.result_typeFK IN (101, 557)
WHERE ep.del = 'no'
  AND tt.sportFK = 50
  AND r.value IS NOT NULL
  AND TRIM(r.value) <> ''
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND EXISTS (
      SELECT 1 FROM object_discipline od
      WHERE od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
        AND od.disciplineFK IN (144, 799, 800, 801, 803, 804)
  )

ORDER BY sort_order, event_id, event_participants_id;

-- ======================================================================================

SELECT
    -- CheckID - Triathlon-DQ-094
    -- Name - EVENT_MIXED_RELAY_LINEUP_SIZE_NOT_FOUR
    -- What it does: Flags Mixed Relay starter lineups that do not contain exactly four athletes: two men and two women.
    'Mixed_Relay_Lineup_Size_Not_Four' AS check_type,
    x.event_participants_id,
    x.event_id,
    x.event_name,
    x.tournament_stage_name,
    x.lineup_size,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds Mixed Relay teams whose Starter lineup names a number
-- of distinct athletes other than four, the format being two men and two women each racing a
-- leg.
-- Narrowed to discipline 800 alone rather than to relays in general. SPORTS/Triathlon.md
-- records that lineup size is not fixed by discipline for this sport and that Team Relay
-- fields both three- and four-member teams, so a rule written across relays would report the
-- format. Mixed Relay is the one discipline whose four is the definition rather than a habit.
-- A team carrying no lineup is outside the eligible population rather than a finding of size
-- zero. That is a different defect - the membership is absent, not wrong - and folding it in
-- would turn one outlier into a report of every unpopulated team.
FROM (
    SELECT
        ep.id AS event_participants_id,
        e.id AS event_id,
        e.name AS event_name,
        ts.name AS tournament_stage_name,
        COUNT(DISTINCT l.participantFK) AS lineup_size
    FROM event_participants ep
    JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = 50
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no' AND p.type = 'team'
    JOIN lineup l ON l.event_participantsFK = ep.id AND l.del = 'no'
    WHERE ep.del = 'no'
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
      AND EXISTS (
          SELECT 1 FROM object_discipline od
          WHERE od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
            AND od.disciplineFK = 800
      )
    GROUP BY ep.id, e.id, e.name, ts.name
    HAVING COUNT(DISTINCT l.participantFK) <> 4
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ep.id) AS eligible_count,
    1 AS sort_order
FROM event_participants ep
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 50
JOIN participant p ON p.id = ep.participantFK AND p.del = 'no' AND p.type = 'team'
JOIN lineup l ON l.event_participantsFK = ep.id AND l.del = 'no'
WHERE ep.del = 'no'
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND EXISTS (
      SELECT 1 FROM object_discipline od
      WHERE od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
        AND od.disciplineFK = 800
  )

ORDER BY sort_order, event_id, event_participants_id;
