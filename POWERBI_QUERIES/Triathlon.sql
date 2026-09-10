SELECT
    -- CheckID - Triathlon-DQ-068
    -- Name - EVENT_SETTINGS_DISCIPLINE_NAME_MISMATCH
    -- What it does: Finds events whose name gives a discipline that is missing from its relations.
    'EVENT_DISCIPLINE_NOT_MATCHING_NAME' AS check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
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
        e.startdate AS event_startdate,
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
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
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
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
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
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
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
    x.event_startdate,
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
        b.event_startdate,
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
            e.startdate AS event_startdate,
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
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
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
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
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
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
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
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
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
    x.event_startdate,
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
        e.startdate AS event_startdate,
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
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
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
    GROUP BY ep.id, e.id, e.name, e.startdate, p.name, tt.name
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
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
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
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
    x.event_startdate,
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
        e.startdate AS event_startdate,
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
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
      AND EXISTS (
          SELECT 1 FROM object_discipline od
          WHERE od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
            AND od.disciplineFK = 800
      )
    GROUP BY ep.id, e.id, e.name, e.startdate, ts.name
    HAVING COUNT(DISTINCT l.participantFK) <> 4
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL,
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
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND EXISTS (
      SELECT 1 FROM object_discipline od
      WHERE od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
        AND od.disciplineFK = 800
  )

ORDER BY sort_order, event_id, event_participants_id;


-- ================================================================================
SELECT
    -- CheckID - Triathlon-DQ-124
    -- Name - EVENT_NAME_DOES_NOT_FOLLOW_THE_SPORT_PATTERN
    -- What it does: Finds events whose name is not the discipline, the gender and the round the event itself stores.
    y.check_type,
    y.event_id,
    y.event_name,
    y.expected_name,
    y.discipline,
    y.stage_gender,
    y.round_type_name,
    y.tournament_id,
    y.tournament_name,
    y.template_id,
    y.template_name,
    y.startdate,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: An event is described twice - once in the text of its own
-- name, once in the discipline, stage gender and round type hung off it - and this reports
-- where the name is not what those three say it should be. The expected form is
-- [Discipline] [Gender] [Round], with a trailing group number kept where sibling rounds share
-- a base name.
--
-- The round word comes from an explicit list keyed on the round type's id, and that list is
-- the vocabulary this sport actually uses rather than a general one. That is deliberate. A
-- guessed mapping enforced spellings the data does not hold, and on 2026-09-09 three of them
-- contradicted the whole population: 175 events named Semifinal against a mapping demanding
-- Semi-Final, 160 named Prelims against Preliminary, and 54 legitimate Final B, Final C and
-- Final Phase events reported as unrecognised. A round type outside the list is therefore not
-- a naming defect here, and belongs to the companion check that says the name cannot be built.
--
-- The comparison is BINARY, so a name differing only in case is a finding. Whitespace and text
-- hygiene are deliberately not read: GLOBAL-DQ-049 EVENT_NAME_FORMAT_INVALID already carries
-- that question for this sport, and asking it again would report one defect twice.
--
-- Measured 2026-09-09: 40 of 3762 events, every one unambiguous - Woman and Female written
-- for Women, the Qualifer typo, a Mixed Relay event with no round word, an event named Final
-- whose round type is Heats, and five sibling rounds sharing a name with no group number. The
-- client scope removes none of them; all 3762 events are inside it.
FROM (
    SELECT
        x.*,
        TRIM(CONCAT_WS(' ', x.discipline, x.gender_label, x.round_word)) AS expected_base,
        TRIM(CONCAT_WS(' ', TRIM(CONCAT_WS(' ', x.discipline, x.gender_label, x.round_word)), x.actual_number)) AS expected_name,
        -- How many events in the same stage share this base name. A window rather than a
        -- correlated count per event: the population is read once, and the question is only
        -- ever asked of rows already in it.
        COUNT(*) OVER (PARTITION BY x.stage_id, x.actual_base) AS siblings_sharing_base,
        CASE
            WHEN x.event_name REGEXP '(Male|Female)'
                 THEN 'NAME_SAYS_MALE_OR_FEMALE_INSTEAD_OF_MEN_OR_WOMEN'
            WHEN x.discipline LIKE '%Mixed%'
                 AND x.event_name REGEXP '(Mixed.*Mixed|Mixed.*(Men|Women))'
                 THEN 'GENDER_ADDED_TO_A_MIXED_DISCIPLINE'
            WHEN COUNT(*) OVER (PARTITION BY x.stage_id, x.actual_base) > 1
                 AND x.actual_number IS NULL
                 THEN 'SIBLING_ROUNDS_SHARE_A_NAME_WITH_NO_GROUP_NUMBER'
            ELSE 'NAME_DOES_NOT_MATCH_DISCIPLINE_GENDER_AND_ROUND'
        END AS check_type
    FROM (
        SELECT
            e.id AS event_id,
            e.name AS event_name,
            e.startdate,
            ts.id AS stage_id,
            ts.gender AS stage_gender,
            t.id AS tournament_id,
            t.name AS tournament_name,
            tt.id AS template_id,
            tt.name AS template_name,
            d.name AS discipline,
            rt.id AS round_type_id,
            rt.name AS round_type_name,
            -- The Mixed exception: a discipline that already says Mixed carries the gender in
            -- its own name, so adding one repeats it. Stated in the rename task and kept here.
            CASE WHEN d.name LIKE '%Mixed%' THEN NULL
                 WHEN ts.gender = 'male'    THEN 'Men'
                 WHEN ts.gender = 'female'  THEN 'Women'
            END AS gender_label,
            -- The round words Triathlon actually uses, keyed on the round type's own id.
            -- Nine ids cover every active event, and they are the same nine as ROUND_TYPE_LIST
            -- in SPORTS/params.json.
            CASE rt.id
                WHEN 173 THEN 'Final'
                WHEN 9   THEN 'Final'
                WHEN 178 THEN 'Semifinal'
                WHEN 179 THEN 'Qualifier'
                WHEN 180 THEN 'Repechage'
                WHEN 284 THEN 'Final B'
                WHEN 283 THEN 'Final C'
                WHEN 267 THEN 'Final Phase'
                WHEN 204 THEN 'Heat'
            END AS round_word,
            -- The trailing group number is part of the pattern rather than of the round word,
            -- so it is split off before the two are compared and put back afterwards.
            CASE WHEN e.name REGEXP '[[:space:]][0-9]+$'
                 THEN TRIM(SUBSTRING(e.name, 1,
                        CHAR_LENGTH(e.name) - CHAR_LENGTH(SUBSTRING_INDEX(e.name, ' ', -1))))
                 ELSE TRIM(e.name)
            END AS actual_base,
            CASE WHEN e.name REGEXP '[[:space:]][0-9]+$'
                 THEN SUBSTRING_INDEX(e.name, ' ', -1)
            END AS actual_number
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    LEFT JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
    LEFT JOIN discipline d ON d.id = od.disciplineFK
    LEFT JOIN round_type rt ON rt.id = e.round_typeFK
    WHERE e.del = 'no'
      AND tt.sportFK = 50
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
    ) x
    WHERE x.round_word IS NOT NULL
      AND x.discipline IS NOT NULL
      AND x.event_name IS NOT NULL
      AND TRIM(x.event_name) <> ''
) y
WHERE BINARY y.actual_base <> BINARY y.expected_base
   OR (y.siblings_sharing_base > 1 AND y.actual_number IS NULL)

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT c.event_id) AS eligible_count,
    1 AS sort_order
FROM (
        SELECT
            e.id AS event_id,
            e.name AS event_name,
            e.startdate,
            ts.id AS stage_id,
            ts.gender AS stage_gender,
            t.id AS tournament_id,
            t.name AS tournament_name,
            tt.id AS template_id,
            tt.name AS template_name,
            d.name AS discipline,
            rt.id AS round_type_id,
            rt.name AS round_type_name,
            -- The Mixed exception: a discipline that already says Mixed carries the gender in
            -- its own name, so adding one repeats it. Stated in the rename task and kept here.
            CASE WHEN d.name LIKE '%Mixed%' THEN NULL
                 WHEN ts.gender = 'male'    THEN 'Men'
                 WHEN ts.gender = 'female'  THEN 'Women'
            END AS gender_label,
            -- The round words Triathlon actually uses, keyed on the round type's own id.
            -- Nine ids cover every active event, and they are the same nine as ROUND_TYPE_LIST
            -- in SPORTS/params.json.
            CASE rt.id
                WHEN 173 THEN 'Final'
                WHEN 9   THEN 'Final'
                WHEN 178 THEN 'Semifinal'
                WHEN 179 THEN 'Qualifier'
                WHEN 180 THEN 'Repechage'
                WHEN 284 THEN 'Final B'
                WHEN 283 THEN 'Final C'
                WHEN 267 THEN 'Final Phase'
                WHEN 204 THEN 'Heat'
            END AS round_word,
            -- The trailing group number is part of the pattern rather than of the round word,
            -- so it is split off before the two are compared and put back afterwards.
            CASE WHEN e.name REGEXP '[[:space:]][0-9]+$'
                 THEN TRIM(SUBSTRING(e.name, 1,
                        CHAR_LENGTH(e.name) - CHAR_LENGTH(SUBSTRING_INDEX(e.name, ' ', -1))))
                 ELSE TRIM(e.name)
            END AS actual_base,
            CASE WHEN e.name REGEXP '[[:space:]][0-9]+$'
                 THEN SUBSTRING_INDEX(e.name, ' ', -1)
            END AS actual_number
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    LEFT JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
    LEFT JOIN discipline d ON d.id = od.disciplineFK
    LEFT JOIN round_type rt ON rt.id = e.round_typeFK
    WHERE e.del = 'no'
      AND tt.sportFK = 50
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
) c
WHERE c.round_word IS NOT NULL
      AND c.discipline IS NOT NULL
      AND c.event_name IS NOT NULL
      AND TRIM(c.event_name) <> ''

ORDER BY sort_order, event_id;


-- ================================================================================
SELECT
    -- CheckID - Triathlon-DQ-125
    -- Name - EVENT_NAME_PATTERN_CANNOT_BE_BUILT
    -- What it does: Flags events for which no expected name exists, because the discipline, the round type or the name itself is missing.
    z.check_type,
    z.event_id,
    z.event_name,
    z.discipline,
    z.stage_gender,
    z.round_type_id,
    z.round_type_name,
    z.tournament_id,
    z.tournament_name,
    z.template_id,
    z.template_name,
    z.startdate,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: The companion of EVENT_NAME_DOES_NOT_FOLLOW_THE_SPORT_PATTERN,
-- and the reason that check can be strict. An expected name is the discipline, the gender and
-- the round word joined together, so an event missing any of the three has no expected name to
-- be compared against and would otherwise leave the audit without being counted anywhere.
--
-- The four states are one work list rather than four checks: none of them is a naming defect,
-- and none can be repaired by renaming anything. A missing discipline or round type is a gap
-- in the event's own settings. A round type outside the vocabulary is a decision nobody has
-- made yet - the nine ids in the list are the ones this sport uses today, and a new one
-- arriving here is the check asking for a word rather than reporting a fault.
--
-- It returns nothing on the day it is written, which is what it is for. The population it
-- guards is every active event in the sport, so it sits at its coverage count with no findings
-- until one of the four states appears.
FROM (
    SELECT
        x.*,
        CASE
            WHEN x.event_name IS NULL OR TRIM(x.event_name) = '' THEN 'EVENT_NAME_EMPTY'
            WHEN x.discipline IS NULL                            THEN 'NO_DISCIPLINE_ON_THE_EVENT'
            WHEN x.round_type_id IS NULL                         THEN 'NO_ROUND_TYPE_ON_THE_EVENT'
            ELSE 'ROUND_TYPE_OUTSIDE_THE_SPORT_VOCABULARY'
        END AS check_type
    FROM (
        SELECT
            e.id AS event_id,
            e.name AS event_name,
            e.startdate,
            ts.id AS stage_id,
            ts.gender AS stage_gender,
            t.id AS tournament_id,
            t.name AS tournament_name,
            tt.id AS template_id,
            tt.name AS template_name,
            d.name AS discipline,
            rt.id AS round_type_id,
            rt.name AS round_type_name,
            -- The Mixed exception: a discipline that already says Mixed carries the gender in
            -- its own name, so adding one repeats it. Stated in the rename task and kept here.
            CASE WHEN d.name LIKE '%Mixed%' THEN NULL
                 WHEN ts.gender = 'male'    THEN 'Men'
                 WHEN ts.gender = 'female'  THEN 'Women'
            END AS gender_label,
            -- The round words Triathlon actually uses, keyed on the round type's own id.
            -- Nine ids cover every active event, and they are the same nine as ROUND_TYPE_LIST
            -- in SPORTS/params.json.
            CASE rt.id
                WHEN 173 THEN 'Final'
                WHEN 9   THEN 'Final'
                WHEN 178 THEN 'Semifinal'
                WHEN 179 THEN 'Qualifier'
                WHEN 180 THEN 'Repechage'
                WHEN 284 THEN 'Final B'
                WHEN 283 THEN 'Final C'
                WHEN 267 THEN 'Final Phase'
                WHEN 204 THEN 'Heat'
            END AS round_word,
            -- The trailing group number is part of the pattern rather than of the round word,
            -- so it is split off before the two are compared and put back afterwards.
            CASE WHEN e.name REGEXP '[[:space:]][0-9]+$'
                 THEN TRIM(SUBSTRING(e.name, 1,
                        CHAR_LENGTH(e.name) - CHAR_LENGTH(SUBSTRING_INDEX(e.name, ' ', -1))))
                 ELSE TRIM(e.name)
            END AS actual_base,
            CASE WHEN e.name REGEXP '[[:space:]][0-9]+$'
                 THEN SUBSTRING_INDEX(e.name, ' ', -1)
            END AS actual_number
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    LEFT JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
    LEFT JOIN discipline d ON d.id = od.disciplineFK
    LEFT JOIN round_type rt ON rt.id = e.round_typeFK
    WHERE e.del = 'no'
      AND tt.sportFK = 50
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
    ) x
    WHERE x.event_name IS NULL
       OR TRIM(x.event_name) = ''
       OR x.discipline IS NULL
       OR x.round_type_id IS NULL
       OR x.round_word IS NULL
) z

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT c.event_id) AS eligible_count,
    1 AS sort_order
FROM (
        SELECT
            e.id AS event_id,
            e.name AS event_name,
            e.startdate,
            ts.id AS stage_id,
            ts.gender AS stage_gender,
            t.id AS tournament_id,
            t.name AS tournament_name,
            tt.id AS template_id,
            tt.name AS template_name,
            d.name AS discipline,
            rt.id AS round_type_id,
            rt.name AS round_type_name,
            -- The Mixed exception: a discipline that already says Mixed carries the gender in
            -- its own name, so adding one repeats it. Stated in the rename task and kept here.
            CASE WHEN d.name LIKE '%Mixed%' THEN NULL
                 WHEN ts.gender = 'male'    THEN 'Men'
                 WHEN ts.gender = 'female'  THEN 'Women'
            END AS gender_label,
            -- The round words Triathlon actually uses, keyed on the round type's own id.
            -- Nine ids cover every active event, and they are the same nine as ROUND_TYPE_LIST
            -- in SPORTS/params.json.
            CASE rt.id
                WHEN 173 THEN 'Final'
                WHEN 9   THEN 'Final'
                WHEN 178 THEN 'Semifinal'
                WHEN 179 THEN 'Qualifier'
                WHEN 180 THEN 'Repechage'
                WHEN 284 THEN 'Final B'
                WHEN 283 THEN 'Final C'
                WHEN 267 THEN 'Final Phase'
                WHEN 204 THEN 'Heat'
            END AS round_word,
            -- The trailing group number is part of the pattern rather than of the round word,
            -- so it is split off before the two are compared and put back afterwards.
            CASE WHEN e.name REGEXP '[[:space:]][0-9]+$'
                 THEN TRIM(SUBSTRING(e.name, 1,
                        CHAR_LENGTH(e.name) - CHAR_LENGTH(SUBSTRING_INDEX(e.name, ' ', -1))))
                 ELSE TRIM(e.name)
            END AS actual_base,
            CASE WHEN e.name REGEXP '[[:space:]][0-9]+$'
                 THEN SUBSTRING_INDEX(e.name, ' ', -1)
            END AS actual_number
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    LEFT JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
    LEFT JOIN discipline d ON d.id = od.disciplineFK
    LEFT JOIN round_type rt ON rt.id = e.round_typeFK
    WHERE e.del = 'no'
      AND tt.sportFK = 50
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
) c

ORDER BY sort_order, event_id;


-- ================================================================================
SELECT
    -- CheckID - Triathlon-DQ-127
    -- Name - EVENT_NAME_CARRIES_A_WORD_THE_RENAMING_PATTERN_WILL_DROP
    -- What it does: Finds events whose name holds a word the required form has no slot for, so a rename to that form will drop it.
    CASE WHEN MAX(g.siblings_sharing_the_expected_base) > 1
         THEN 'LOSING_IT_COLLIDES_WITH_ANOTHER_EVENT'
         ELSE 'WORD_IS_DROPPED_AND_THE_NAME_STAYS_UNIQUE'
    END AS check_type,
    g.event_id,
    g.event_name,
    g.expected_base,
    GROUP_CONCAT(DISTINCT g.word ORDER BY g.word SEPARATOR ', ') AS words_the_pattern_drops,
    COUNT(DISTINCT g.word) AS word_count,
    MAX(g.discipline) AS discipline,
    MAX(g.round_type_name) AS round_type_name,
    MAX(g.tournament_name) AS tournament_name,
    MAX(g.template_name) AS template_name,
    MAX(g.startdate) AS event_startdate,
    MAX(g.siblings_sharing_the_expected_base) AS siblings_sharing_the_expected_base,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: The required form is `[Discipline] [Gender] [Round]` and it is
-- built from the event's own settings, so any word the current name carries that the form has
-- no slot for disappears the moment the name is made to follow it. This lists those words while
-- they are still there, and it exists because nothing recovers them afterwards: once a name is
-- rewritten from the settings, the settings are all that is left and a name that disagreed with
-- them can no longer be told from one that agreed.
--
-- It is the companion of ``Triathlon-DQ-124` EVENT_NAME_DOES_NOT_FOLLOW_THE_SPORT_PATTERN`, over
-- the same population and with the same expected name. That check asks whether the name is the
-- expected one; this asks what the name is carrying that the expected one does not.
--
-- `check_type` separates the two, and only the first is a decision anybody has to take:
--   LOSING_IT_COLLIDES_WITH_ANOTHER_EVENT - another event in the same stage reduces to the same
--     expected name, so this word is part of what tells the two apart and after a rename a
--     trailing number is all that will.
--   WORD_IS_DROPPED_AND_THE_NAME_STAYS_UNIQUE - the word goes and nothing collides.
--
-- **A word is matched normalised and in both numbers.** The comparison lower-cases, drops a
-- possessive `'s`, drops everything that is not a letter or a digit, and accepts a match on the
-- singular or the plural, so `Women's` against `Women` is not a loss and `Finals` against
-- `Final` is not either. The trailing group number is not a word of the name: it is the
-- pattern's own, split off before the diff exactly as the pattern check splits it.
--
-- One row per event, never one per word: the audited object is the event, the words it loses
-- travel as a named column, and `word_count` says how many. An event whose name already is the
-- expected one carries no lost word and is not a finding.
FROM (
    SELECT
        b.event_id,
        b.event_name,
        b.expected_base,
        b.discipline,
        b.round_type_name,
        b.tournament_name,
        b.template_name,
        b.startdate,
        b.siblings_sharing_the_expected_base,
        b.expected_words,
        TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(b.actual_base, ' ', seq.n), ' ', -1)) AS word
    FROM (
        SELECT
            a.*,
            COUNT(*) OVER (PARTITION BY a.stage_id, a.expected_base) AS siblings_sharing_the_expected_base
        FROM (
            SELECT
                e.id AS event_id,
                TRIM(e.name) AS event_name,
                e.startdate,
                ts.id AS stage_id,
                t.name AS tournament_name,
                tt.name AS template_name,
                d.name AS discipline,
                rt.name AS round_type_name,
                TRIM(CONCAT_WS(' ',
                    d.name,
                    CASE WHEN d.name LIKE '%Mixed%' THEN NULL
                         WHEN ts.gender = 'male'    THEN 'Men'
                         WHEN ts.gender = 'female'  THEN 'Women'
                    END,
                    CASE rt.id
                        WHEN 173 THEN 'Final'
                        WHEN 9   THEN 'Final'
                        WHEN 178 THEN 'Semifinal'
                        WHEN 179 THEN 'Qualifier'
                        WHEN 180 THEN 'Repechage'
                        WHEN 284 THEN 'Final B'
                        WHEN 283 THEN 'Final C'
                        WHEN 267 THEN 'Final Phase'
                        WHEN 204 THEN 'Heat'
                    END
                )) AS expected_base,
                -- Every word the expected name may legitimately hold, which is the expected
                -- name itself.
                TRIM(CONCAT_WS(' ',
                    d.name,
                    CASE WHEN d.name LIKE '%Mixed%' THEN NULL
                         WHEN ts.gender = 'male'    THEN 'Men'
                         WHEN ts.gender = 'female'  THEN 'Women'
                    END,
                    CASE rt.id
                        WHEN 173 THEN 'Final'
                        WHEN 9   THEN 'Final'
                        WHEN 178 THEN 'Semifinal'
                        WHEN 179 THEN 'Qualifier'
                        WHEN 180 THEN 'Repechage'
                        WHEN 284 THEN 'Final B'
                        WHEN 283 THEN 'Final C'
                        WHEN 267 THEN 'Final Phase'
                        WHEN 204 THEN 'Heat'
                    END
                )) AS expected_words,
                -- The trailing group number belongs to the pattern rather than to the name, so
                -- it is split off before the diff, the same rule `Triathlon-DQ-124` applies.
                CASE WHEN e.name REGEXP '[[:space:]][0-9]+$'
                     THEN TRIM(SUBSTRING(TRIM(e.name), 1,
                            CHAR_LENGTH(TRIM(e.name)) - CHAR_LENGTH(SUBSTRING_INDEX(TRIM(e.name), ' ', -1))))
                     ELSE TRIM(e.name)
                END AS actual_base
            FROM event e
            JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
            JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
            JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
            LEFT JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
            LEFT JOIN discipline d ON d.id = od.disciplineFK
            LEFT JOIN round_type rt ON rt.id = e.round_typeFK
            WHERE e.del = 'no'
              AND tt.sportFK = 50
              AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
              AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
              -- AND t.tournament_templateFK = <tournament_template_id>
              AND d.name IS NOT NULL
              AND e.name IS NOT NULL
              AND TRIM(e.name) <> ''
              AND CASE rt.id
                        WHEN 173 THEN 'Final'
                        WHEN 9   THEN 'Final'
                        WHEN 178 THEN 'Semifinal'
                        WHEN 179 THEN 'Qualifier'
                        WHEN 180 THEN 'Repechage'
                        WHEN 284 THEN 'Final B'
                        WHEN 283 THEN 'Final C'
                        WHEN 267 THEN 'Final Phase'
                        WHEN 204 THEN 'Heat'
                    END IS NOT NULL
        ) a
    ) b
    -- One row per word of the name. Twelve is above the longest name the sport carries and the
    -- join stops at the word count of each name, so a short name costs one row.
    JOIN (
        SELECT 1 AS n UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
        UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8
        UNION ALL SELECT 9 UNION ALL SELECT 10 UNION ALL SELECT 11 UNION ALL SELECT 12
    ) seq
      ON seq.n <= CHAR_LENGTH(b.actual_base) - CHAR_LENGTH(REPLACE(b.actual_base, ' ', '')) + 1
) g
WHERE TRIM(g.word) <> ''
  AND LOWER(REGEXP_REPLACE(REGEXP_REPLACE(g.word, '''s$', ''), '[^A-Za-z0-9]', '')) <> ''
  AND CONCAT(' ', LOWER(REGEXP_REPLACE(g.expected_words, '[^A-Za-z0-9 ]', '')), ' ')
      NOT LIKE CONCAT('% ', LOWER(REGEXP_REPLACE(REGEXP_REPLACE(g.word, '''s$', ''), '[^A-Za-z0-9]', '')), ' %')
  AND CONCAT(' ', LOWER(REGEXP_REPLACE(g.expected_words, '[^A-Za-z0-9 ]', '')), ' ')
      NOT LIKE CONCAT('% ', TRIM(TRAILING 's' FROM LOWER(REGEXP_REPLACE(REGEXP_REPLACE(g.word, '''s$', ''), '[^A-Za-z0-9]', ''))), ' %')
  AND CONCAT(' ', LOWER(REGEXP_REPLACE(g.expected_words, '[^A-Za-z0-9 ]', '')), ' ')
      NOT LIKE CONCAT('% ', LOWER(REGEXP_REPLACE(REGEXP_REPLACE(g.word, '''s$', ''), '[^A-Za-z0-9]', '')), 's %')
GROUP BY g.event_id, g.event_name, g.expected_base

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT c.event_id) AS eligible_count,
    1 AS sort_order
FROM (
    SELECT e.id AS event_id
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    LEFT JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
    LEFT JOIN discipline d ON d.id = od.disciplineFK
    LEFT JOIN round_type rt ON rt.id = e.round_typeFK
    WHERE e.del = 'no'
      AND tt.sportFK = 50
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
      AND d.name IS NOT NULL
      AND e.name IS NOT NULL
      AND TRIM(e.name) <> ''
      AND CASE rt.id
                        WHEN 173 THEN 'Final'
                        WHEN 9   THEN 'Final'
                        WHEN 178 THEN 'Semifinal'
                        WHEN 179 THEN 'Qualifier'
                        WHEN 180 THEN 'Repechage'
                        WHEN 284 THEN 'Final B'
                        WHEN 283 THEN 'Final C'
                        WHEN 267 THEN 'Final Phase'
                        WHEN 204 THEN 'Heat'
                    END IS NOT NULL
) c

ORDER BY sort_order, check_type, event_startdate DESC;
