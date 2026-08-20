SELECT
    -- CheckID - Ice-Hockey-DQ-057
    -- Name - EVENT_RESULTS_FINAL_RESULT_NOT_WRITTEN_FOR_BOTH_SIDES
    -- What it does: Flags finished events where an entered side holds no Final Result score.
    CASE
        WHEN b.sides_with_final = 0 AND b.result_rows = 0
            THEN 'FINISHED_EVENT_HOLDS_NO_RESULT_AT_ALL'
        WHEN b.sides_with_final = 0
            THEN 'FINISHED_EVENT_SCORED_BUT_NO_FINAL_RESULT'
        ELSE 'FINAL_RESULT_WRITTEN_FOR_ONE_SIDE_ONLY'
    END AS check_type,
    b.event_id,
    b.event_name,
    b.event_startdate,
    b.template_name,
    b.tournament_name,
    b.stage_name,
    b.status_desc_name,
    b.sides_entered,
    b.sides_with_final,
    b.result_types_present,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds events the sport has closed - every description under
-- status_type 'finished', not the plain one alone - in which at least one entered side does
-- not hold a value in the 4 Final Result event result. The score is what a finished ice
-- hockey match is, so a side without it leaves the match unresolved for every consumer that
-- reads the deciding result rather than the period breakdown.
-- Asked per entered side rather than per event, because the two are different defects: an
-- event where neither side holds the score was never written, and an event where one side
-- holds it was written and interrupted. The check_type column separates them, and separates
-- both from the event that carries no result of any kind.
-- Wider than GLOBAL-DQ-017 and GLOBAL-DQ-114, which this sport also runs. That one asks for
-- any result at all under status_descFK 6; the other asks for the deciding score only where a
-- running score is already present. Neither reaches the event finished after overtime, after
-- penalties or by an awarded win, and 910 of the sport's finished events are one of those
-- three - `SPORTS/Ice-Hockey.md` records the four descriptions.
-- The check is a guard rather than a work list: measured 2026-08-14, all 9596 finished events
-- in the client's boundary hold the score on both sides. The 202 events without it are 182
-- cancelled and 20 not started, which this statement does not audit.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        tt.name AS template_name,
        t.name AS tournament_name,
        ts.name AS stage_name,
        sd.name AS status_desc_name,
        COUNT(DISTINCT ep.id) AS sides_entered,
        COUNT(DISTINCT CASE WHEN r.result_typeFK = 4
                            THEN ep.id END) AS sides_with_final,
        COUNT(r.id) AS result_rows,
        GROUP_CONCAT(DISTINCT rt.name ORDER BY rt.name SEPARATOR ' / ') AS result_types_present
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = 5
    LEFT JOIN status_desc sd ON sd.id = e.status_descFK
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    LEFT JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
         AND TRIM(COALESCE(r.value, '')) <> ''
    LEFT JOIN result_type rt ON rt.id = r.result_typeFK
    WHERE e.del = 'no'
      AND e.status_type = 'finished'
      AND t.tournament_templateFK IN (31, 32, 33, 308, 313, 328, 546, 10083, 10501, 10560, 10568, 10720, 10738, 10849, 11044, 11076, 11077, 11083, 11091, 11092, 11102, 11103, 11104, 11105, 11285)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY e.id, e.name, e.startdate, tt.name, t.name, ts.name, sd.name
    HAVING sides_with_final < sides_entered
) b

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 5
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
WHERE e.del = 'no'
  AND e.status_type = 'finished'
  AND t.tournament_templateFK IN (31, 32, 33, 308, 313, 328, 546, 10083, 10501, 10560, 10568, 10720, 10738, 10849, 11044, 11076, 11077, 11083, 11091, 11092, 11102, 11103, 11104, 11105, 11285)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_startdate, event_id;


-- ================================================================================
SELECT
    -- CheckID - Ice-Hockey-DQ-058
    -- Name - EVENT_RESULTS_SCORE_TIED_IN_A_ROUND_THAT_MUST_PRODUCE_A_WINNER
    -- What it does: Flags finished knockout and placement matches whose two sides hold the same Final Result.
    CASE
        WHEN c.extra_time_values > 1 OR c.shootout_values > 1
            THEN 'TIED_WHILE_EXTRA_TIME_OR_SHOOTOUT_NAMES_A_WINNER'
        ELSE 'TIED_AND_NOTHING_IN_THE_EVENT_RESOLVES_IT'
    END AS check_type,
    c.event_id,
    c.event_name,
    c.event_startdate,
    c.round_name,
    c.template_name,
    c.tournament_name,
    c.status_desc_name,
    c.shared_final,
    c.extra_time_values,
    c.shootout_values,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds finished events in a round that has to separate its two
-- sides - the knockout rounds and the placement matches, which decide one place against
-- another - where both sides hold the same value in the 4 Final Result event result.
-- This is the narrow rule GLOBAL-DQ-084 asks for and this sport cannot assert. That template
-- admits only a head-to-head sport whose format allows no draw, and ice hockey's does: run
-- sport-wide on 2026-08-14 it reported 297 events, 290 of them in the numbered group rounds
-- where a level score is the result and the sport awards points for it. Restricting the
-- population to the rounds that must produce a winner is what makes the same question answerable
-- here, and it is the shape SPORTS/Soccer.md arrived at independently for the same reason.
-- The two check_types are two different repairs and are separated for that reason. Where extra
-- time or the shootout already names a winner, the match was decided and the deciding score was
-- never brought forward - one row, one field. Where nothing in the event separates the sides, the
-- resolution was never imported at all and somebody has to find out what it was.
-- 138 bronze is in the population: it decides third place against fourth, so it separates its
-- sides exactly as the final does. GLOBAL-DQ-093 and -094 own what medal that produces.
FROM (
    SELECT
        b.event_id,
        b.event_name,
        b.event_startdate,
        b.round_name,
        b.template_name,
        b.tournament_name,
        b.status_desc_name,
        MIN(b.final_value) AS shared_final,
        COUNT(DISTINCT b.extra_time_value) AS extra_time_values,
        COUNT(DISTINCT b.shootout_value) AS shootout_values,
        COUNT(DISTINCT b.final_value) AS final_values
    FROM (
        SELECT
            e.id AS event_id,
            e.name AS event_name,
            e.startdate AS event_startdate,
            rt.name AS round_name,
            tt.name AS template_name,
            t.name AS tournament_name,
            sd.name AS status_desc_name,
            MAX(CASE WHEN r.result_typeFK = 4 THEN TRIM(r.value) END) AS final_value,
            MAX(CASE WHEN r.result_typeFK = 2 THEN TRIM(r.value) END) AS extra_time_value,
            MAX(CASE WHEN r.result_typeFK = 3 THEN TRIM(r.value) END) AS shootout_value
        FROM event e
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
             AND tt.sportFK = 5
        LEFT JOIN round_type rt ON rt.id = e.round_typeFK
        LEFT JOIN status_desc sd ON sd.id = e.status_descFK
        JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
        LEFT JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
             AND TRIM(COALESCE(r.value, '')) <> ''
        WHERE e.del = 'no'
          AND e.status_type = 'finished'
          AND e.round_typeFK IN (2, 3, 4, 9, 22, 23, 24, 25, 26, 135, 136, 138)
          AND t.tournament_templateFK IN (31, 32, 33, 308, 313, 328, 546, 10083, 10501, 10560, 10568, 10720, 10738, 10849, 11044, 11076, 11077, 11083, 11091, 11092, 11102, 11103, 11104, 11105, 11285)
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
          -- AND t.tournament_templateFK = <tournament_template_id>
          -- AND e.startdate >= '<from_datetime>'
          -- AND e.startdate <  '<to_datetime>'
        GROUP BY e.id, e.name, e.startdate, rt.name, tt.name, t.name, sd.name, ep.id
    ) b
    GROUP BY b.event_id, b.event_name, b.event_startdate, b.round_name, b.template_name,
             b.tournament_name, b.status_desc_name
    HAVING final_values = 1
) c

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 5
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
WHERE e.del = 'no'
  AND e.status_type = 'finished'
  AND e.round_typeFK IN (2, 3, 4, 9, 22, 23, 24, 25, 26, 135, 136, 138)
  AND t.tournament_templateFK IN (31, 32, 33, 308, 313, 328, 546, 10083, 10501, 10560, 10568, 10720, 10738, 10849, 11044, 11076, 11077, 11083, 11091, 11092, 11102, 11103, 11104, 11105, 11285)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_startdate, event_id;


-- ================================================================================
SELECT
    -- CheckID - Ice-Hockey-DQ-059
    -- Name - EVENT_RESULTS_PERIOD_SCORES_DO_NOT_SUM_TO_THE_FINAL_RESULT
    -- What it does: Flags finished events where a side's three period scores plus overtime and shootout do not add up to its Final Result.
    'PERIOD_SCORES_DO_NOT_SUM_TO_THE_FINAL_RESULT' AS check_type,
    c.event_id,
    c.event_name,
    c.event_startdate,
    c.template_name,
    c.tournament_name,
    c.status_desc_name,
    c.sides_disagreeing,
    c.breakdown,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds finished events in which at least one side's
-- 51 Period 1, 52 Period 2 and 53 Period 3, plus 2 Extra time and 3 Penalty shootout where
-- those exist, do not add up to that side's 4 Final Result.
-- The arithmetic is what makes this checkable without a rule about how many periods a match
-- has: a value that is present has to be accounted for by the total beside it, whatever the
-- format. Measured 2026-08-14, 9589 of 9596 finished events add up, 897 of them only once
-- overtime and the shootout are added, which is why both are in the sum rather than excluded.
-- This is the sport's answer to GLOBAL-DQ-085, which cannot be instantiated here. That template
-- reads a period breakdown stored as several data fields under one scope type, which is how
-- curling stores its ends. Ice hockey stores each period as its own scope type and, far more
-- widely, as its own result type - 51 to 53 reach 8501 to 9803 events against 898 in the scope
-- layer - so the same question has to be asked of the result layer to reach the population.
-- Asked per side and reported per event. A side is the thing whose goals have to add up, but
-- both sides of one match are one correction, so the breakdown column carries each side's
-- arithmetic and the row stays the event.
-- Only sides holding all three periods and a final result are audited. A side missing a period
-- is a different question - 1091 finished events store the whole score in 51 Period 1 and no
-- second or third period at all - and `SPORTS/Ice-Hockey.md` records it as unresolved rather
-- than reporting it here as arithmetic.
FROM (
    SELECT
        b.event_id,
        b.event_name,
        b.event_startdate,
        b.template_name,
        b.tournament_name,
        b.status_desc_name,
        SUM(CASE WHEN b.p1 + b.p2 + b.p3 + b.ot + b.so <> b.final_value THEN 1 ELSE 0 END)
            AS sides_disagreeing,
        GROUP_CONCAT(CONCAT(b.participant_name, ' ', b.p1, '+', b.p2, '+', b.p3,
                            ' +ot', b.ot, ' +so', b.so, ' against ', b.final_value)
                     ORDER BY b.participant_name SEPARATOR ' / ') AS breakdown
    FROM (
        SELECT
            e.id AS event_id,
            e.name AS event_name,
            e.startdate AS event_startdate,
            tt.name AS template_name,
            t.name AS tournament_name,
            sd.name AS status_desc_name,
            p.name AS participant_name,
            MAX(CASE WHEN r.result_typeFK = 51 THEN CAST(r.value AS SIGNED) END) AS p1,
            MAX(CASE WHEN r.result_typeFK = 52 THEN CAST(r.value AS SIGNED) END) AS p2,
            MAX(CASE WHEN r.result_typeFK = 53 THEN CAST(r.value AS SIGNED) END) AS p3,
            COALESCE(MAX(CASE WHEN r.result_typeFK = 2 THEN CAST(r.value AS SIGNED) END), 0) AS ot,
            COALESCE(MAX(CASE WHEN r.result_typeFK = 3 THEN CAST(r.value AS SIGNED) END), 0) AS so,
            MAX(CASE WHEN r.result_typeFK = 4 THEN CAST(r.value AS SIGNED) END) AS final_value
        FROM event e
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
             AND tt.sportFK = 5
        LEFT JOIN status_desc sd ON sd.id = e.status_descFK
        JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
        LEFT JOIN participant p ON p.id = ep.participantFK
        JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
             AND r.result_typeFK IN (2, 3, 4, 51, 52, 53)
             AND TRIM(COALESCE(r.value, '')) REGEXP '^[0-9]+$'
        WHERE e.del = 'no'
          AND e.status_type = 'finished'
          AND t.tournament_templateFK IN (31, 32, 33, 308, 313, 328, 546, 10083, 10501, 10560, 10568, 10720, 10738, 10849, 11044, 11076, 11077, 11083, 11091, 11092, 11102, 11103, 11104, 11105, 11285)
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
          -- AND t.tournament_templateFK = <tournament_template_id>
          -- AND e.startdate >= '<from_datetime>'
          -- AND e.startdate <  '<to_datetime>'
        GROUP BY e.id, e.name, e.startdate, tt.name, t.name, sd.name, ep.id, p.name
        HAVING p1 IS NOT NULL AND p2 IS NOT NULL AND p3 IS NOT NULL AND final_value IS NOT NULL
    ) b
    GROUP BY b.event_id, b.event_name, b.event_startdate, b.template_name, b.tournament_name,
             b.status_desc_name
    HAVING sides_disagreeing > 0
) c

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT d.event_id) AS eligible_count,
    1 AS sort_order
FROM (
    SELECT
        e.id AS event_id,
        MAX(CASE WHEN r.result_typeFK = 51 THEN CAST(r.value AS SIGNED) END) AS p1,
        MAX(CASE WHEN r.result_typeFK = 52 THEN CAST(r.value AS SIGNED) END) AS p2,
        MAX(CASE WHEN r.result_typeFK = 53 THEN CAST(r.value AS SIGNED) END) AS p3,
        MAX(CASE WHEN r.result_typeFK = 4 THEN CAST(r.value AS SIGNED) END) AS final_value
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = 5
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
         AND r.result_typeFK IN (2, 3, 4, 51, 52, 53)
         AND TRIM(COALESCE(r.value, '')) REGEXP '^[0-9]+$'
    WHERE e.del = 'no'
      AND e.status_type = 'finished'
      AND t.tournament_templateFK IN (31, 32, 33, 308, 313, 328, 546, 10083, 10501, 10560, 10568, 10720, 10738, 10849, 11044, 11076, 11077, 11083, 11091, 11092, 11102, 11103, 11104, 11105, 11285)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY e.id, ep.id
    HAVING p1 IS NOT NULL AND p2 IS NOT NULL AND p3 IS NOT NULL AND final_value IS NOT NULL
) d

ORDER BY sort_order, event_startdate, event_id;


-- ================================================================================
SELECT
    -- CheckID - Ice-Hockey-DQ-081
    -- Name - EVENT_LINEUP_WRITTEN_FOR_ONE_TEAM_AND_NOT_THE_OTHER
    -- What it does: Flags events where one team has a lineup and the other does not.
    'LINEUP_WRITTEN_FOR_ONE_TEAM_AND_NOT_THE_OTHER' AS check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.tournament_template_name,
    x.team_count,
    x.teams_with_lineup,
    x.teams_missing_lineup_names,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds events in which at least one entered team has an active
-- lineup and at least one does not, so the two sides of the same match disagree about whether
-- anybody played in it.
-- This is the part of GLOBAL-DQ-058 this sport can act on. That template reports every event
-- where any team lacks a lineup, and ice hockey's lineup layer reaches about a sixth of the
-- boundary: run on 2026-08-14 it returned 8192 events, of which 8187 have no lineup on either
-- side. Those 8187 are the reach of the layer restated, and no correction empties them.
-- The 5 that remain are a different thing entirely. An event where one team is filled in and
-- the other is not was imported and interrupted, and the missing half is nameable - the row
-- carries which team it is. A run that reports both shapes together buries the five in the
-- eight thousand, which is why the sport asks only the narrower question.
-- Deciding what to do about the 8187 is not a check. SPORTS/Ice-Hockey.md records the reach of
-- the layer, and GLOBAL-DQ-058 is signalled in SPORTS/params.json rather than instantiated.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        tt.name AS tournament_template_name,
        COUNT(DISTINCT ep.id) AS team_count,
        COUNT(DISTINCT CASE WHEN l.id IS NOT NULL THEN ep.id END) AS teams_with_lineup,
        GROUP_CONCAT(DISTINCT CASE WHEN l.id IS NULL THEN p.name END
                     ORDER BY 1 SEPARATOR ' / ') AS teams_missing_lineup_names
    FROM event_participants ep
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
    JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = 5
    LEFT JOIN lineup l ON l.event_participantsFK = ep.id AND l.del = 'no'
    WHERE ep.del = 'no'
      AND p.type = 'team'
      AND t.tournament_templateFK IN (31, 32, 33, 308, 313, 328, 546, 10083, 10501, 10560, 10568, 10720, 10738, 10849, 11044, 11076, 11077, 11083, 11091, 11092, 11102, 11103, 11104, 11105, 11285)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY e.id, e.name, e.startdate, tt.name
) x
WHERE x.teams_with_lineup > 0
  AND x.teams_with_lineup < x.team_count

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event_participants ep
JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 5
WHERE ep.del = 'no'
  AND p.type = 'team'
  AND t.tournament_templateFK IN (31, 32, 33, 308, 313, 328, 546, 10083, 10501, 10560, 10568, 10720, 10738, 10849, 11044, 11076, 11077, 11083, 11091, 11092, 11102, 11103, 11104, 11105, 11285)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_startdate, event_id;


-- ================================================================================
SELECT
    -- CheckID - Ice-Hockey-DQ-082
    -- Name - EVENT_NAME_FORMAT_INVALID_APART_FROM_THE_HYPHEN_CONVENTION
    -- What it does: Finds event names that break a text-hygiene rule, allowing the unspaced hyphen between the two team names.
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
-- control or corrupted characters, capitalisation, a placeholder or a numeric-only name - one
-- row per name, naming every rule it breaks. Every rule GLOBAL-DQ-049 carries is kept except
-- HYPHEN_WITHOUT_SPACES.
-- That one rule is the whole difference, and it is why the template is not instantiated here.
-- Ice hockey names an event by joining its two teams with an unspaced hyphen - Australia-Finland
-- - so the rule fires on the sport's own convention: run on 2026-08-14 the template reported
-- 1767 names of 1767, which is every distinct event name in the boundary. Dropping the rule
-- leaves 11 names, all of them ALL_UPPERCASE, and restores the other thirteen rules as guards
-- that currently report nothing.
-- What those 11 are, read on 2026-08-14: ten are bracket placeholders - A1-B3, A1/B4-B2/A3 -
-- which name a knockout event by the group positions that will fill it and were never replaced
-- by the teams that did. One, USA-ROC, is a legitimate abbreviation and is the check's known
-- residual; the rule cannot tell an acronym from shouting, and one row is a cheaper price than
-- a rule that stops looking.
-- Not a weaker check. A rule that fires on every row in the population tests nothing, and it
-- hides the twelve rules that would have fired on something real. GLOBAL-DQ-050 still owns the
-- case-inconsistency question and is instantiated unchanged.
FROM (
    SELECT
        e.id AS object_id,
        e.name AS object_name,
        e.startdate AS object_startdate,
        (CONVERT(e.name USING utf8mb4) COLLATE utf8mb4_bin) AS name_bin,
        tt.name AS template_name,
        ts.name AS stage_name,
        CONCAT_WS(', ',
            IF(CHAR_LENGTH(e.name) <> CHAR_LENGTH(TRIM(e.name)), 'LEADING_OR_TRAILING_SPACE', NULL),
            IF(e.name LIKE '%  %', 'DOUBLE_SPACE', NULL),
            IF(e.name REGEXP '[[:cntrl:]]', 'CONTROL_CHARACTER', NULL),
            -- Semicolon as \\x{3B}, never literal: the Pool cuts the statement at the first one.
            IF(e.name LIKE '%&#%' OR LOWER(e.name) REGEXP '&(amp|quot|apos|lt|gt|nbsp)\\x{3B}', 'HTML_ENTITY', NULL),
            IF(HEX(e.name) LIKE '%EFBFBD%', 'REPLACEMENT_CHARACTER', NULL),
            IF(HEX(e.name) LIKE '%C2A0%', 'NON_BREAKING_SPACE', NULL),
            IF(HEX(e.name) LIKE '%E2808B%', 'ZERO_WIDTH_SPACE', NULL),
            IF(HEX(e.name) LIKE '%C383%' OR HEX(e.name) LIKE '%C382%', 'MOJIBAKE_DOUBLE_ENCODED', NULL),
            IF(LENGTH(e.name) <> CHAR_LENGTH(e.name), 'NON_ASCII_CHARACTER', NULL),
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
         AND tt.sportFK = 5
    WHERE e.del = 'no'
      AND e.name IS NOT NULL
      AND TRIM(e.name) <> ''
      AND t.tournament_templateFK IN (31, 32, 33, 308, 313, 328, 546, 10083, 10501, 10560, 10568, 10720, 10738, 10849, 11044, 11076, 11077, 11083, 11091, 11092, 11102, 11103, 11104, 11105, 11285)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
) x
WHERE x.violation_types <> ''
GROUP BY x.name_bin, x.violation_types

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 5
WHERE e.del = 'no'
  AND e.name IS NOT NULL
  AND TRIM(e.name) <> ''
  AND t.tournament_templateFK IN (31, 32, 33, 308, 313, 328, 546, 10083, 10501, 10560, 10568, 10720, 10738, 10849, 11044, 11076, 11077, 11083, 11091, 11092, 11102, 11103, 11104, 11105, 11285)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, event_name;


-- ================================================================================
SELECT
    -- CheckID - Ice-Hockey-DQ-088
    -- Name - PARTICIPANT_TEAM_COACH_OR_OFFICIAL_NO_PARTICIPATION_ANYWHERE
    -- What it does: Flags registered teams, coaches and officials that no event, lineup, Comp.Rank or referee link reaches.
    'REGISTERED_AND_NEVER_USED' AS check_type,
    p.id AS participant_id,
    p.name AS participant_name,
    p.type AS participant_type,
    c.name AS country_name,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds participants the sport registry knows, other than
-- athletes, that appear as no event participant, no lineup member, no Comp.Rank participant and
-- on no event's refereeFK property.
-- Two departures from GLOBAL-DQ-009, and each is why this statement exists.
-- The referee path is the first. That template asserts three participation paths and this sport
-- has a fourth: refereeFK is a ref:participant property on 270 events, and it is how an official
-- is attached to the match they worked. Measured 2026-08-14, 160 of the 224 officials the
-- template reported as unattached referee an event, so two thirds of its officials were reported
-- for lacking a link the template does not read.
-- Athletes are the second. The template reported 15201 of them, and reading those rows found
-- something a check cannot act on: every one is entered nowhere in the database, in this sport or
-- any other, and 15187 carry both a date of birth and a country. Complete profiles never attached
-- to a match are a question about where they came from, not a list anybody works through, and
-- only 552 of them sit in a duplicate-name group so merging will not clear them either.
-- SPORTS/Ice-Hockey.md records the measurement and the question.
-- What is left is 329 rows and readable: 136 teams, 129 coaches and 64 officials.
-- Sport-wide by construction. The registry has no template relation, so the client boundary
-- cannot narrow it, and the participation paths are read sport-wide to match: a team entered
-- only in a league the client does not take has still been used, and reporting it would be
-- false. The referee subquery joins the hierarchy solely to reach sportFK, which is what keeps
-- it off a full scan of property.
FROM object_participants op
JOIN participant p ON p.id = op.participantFK AND p.del = 'no'
LEFT JOIN country c ON c.id = p.countryFK
LEFT JOIN (
    SELECT DISTINCT TRIM(pr.value) AS pid
    FROM property pr
    JOIN event e ON e.id = pr.objectFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = 5
    WHERE pr.object = 'event'
      AND pr.name = 'refereeFK'
      AND pr.del = 'no'
      AND TRIM(COALESCE(pr.value, '')) <> ''
) ref ON ref.pid = CAST(p.id AS CHAR)
WHERE op.object = 'sport'
  AND op.objectFK = 5
  AND op.del = 'no'
  AND p.type IN ('team', 'coach', 'official')
  -- AND p.id BETWEEN <from_participant_id> AND <to_participant_id>
  AND ref.pid IS NULL
  AND NOT EXISTS (
      SELECT 1 FROM event_participants ep
      WHERE ep.participantFK = p.id AND ep.del = 'no'
  )
  AND NOT EXISTS (
      SELECT 1 FROM lineup l
      WHERE l.participantFK = p.id AND l.del = 'no'
  )
  AND NOT EXISTS (
      SELECT 1 FROM statistic_participants11 sp
      JOIN statistic s ON s.id = sp.statisticFK AND s.del = 'no'
           AND s.statistic_typeFK = 11
      WHERE sp.participantFK = p.id AND sp.del = 'no'
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL,
    COUNT(DISTINCT op.participantFK) AS eligible_count,
    1 AS sort_order
FROM object_participants op
JOIN participant p ON p.id = op.participantFK AND p.del = 'no'
WHERE op.object = 'sport'
  AND op.objectFK = 5
  AND op.del = 'no'
  AND p.type IN ('team', 'coach', 'official')
  -- AND p.id BETWEEN <from_participant_id> AND <to_participant_id>

ORDER BY sort_order, participant_type, participant_name;


-- ================================================================================
SELECT
    -- CheckID - Ice-Hockey-DQ-089
    -- Name - EVENT_SCOPE_PERIOD_NOT_STORED_FOR_BOTH_SIDES
    -- What it does: Flags events where a period is missing for some participants or stored more than once for one participant.
    CASE
        WHEN x.short_period_count > 0 THEN 'PERIOD_MISSING_FOR_SOME_PARTICIPANTS'
        ELSE 'PERIOD_STORED_MORE_THAN_ONCE'
    END AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    tt.name AS template_name,
    t.name AS tournament_name,
    ts.name AS stage_name,
    x.event_participant_count,
    x.short_period_count,
    x.short_periods,
    x.duplicated_period_count,
    x.duplicated_periods,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds events where one period of the boxscore is stored for
-- some sides and not all, or twice for one side, so the two teams disagree about which
-- periods exist.
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
-- The sport variant of GLOBAL-DQ-091, and it exists because the template cannot be
-- instantiated here at all. That template reads a period as a scope_data_type inside one
-- scope container, which is how most sports store a period-by-period score. Ice hockey
-- inverts it: the period is the container - 322 period1, 323 period2, 324 period3 - and
-- carries a single 162 goals field. The question is identical and the axis is not, so the
-- grouping is on es.scope_typeFK where the template groups on sr.scope_data_typeFK.
-- SPORTS/Ice-Hockey.md records the inversion and POWERBI.md the Not applicable it produced.
JOIN (
    SELECT
        p.event_id,
        p.event_participant_count,
        SUM(CASE WHEN p.sides_with_row < p.event_participant_count THEN 1 ELSE 0 END) AS short_period_count,
        GROUP_CONCAT(CASE WHEN p.sides_with_row < p.event_participant_count THEN p.period_name END
                     ORDER BY p.period_id SEPARATOR ', ') AS short_periods,
        SUM(CASE WHEN p.row_count > p.sides_with_row THEN 1 ELSE 0 END) AS duplicated_period_count,
        GROUP_CONCAT(CASE WHEN p.row_count > p.sides_with_row THEN p.period_name END
                     ORDER BY p.period_id SEPARATOR ', ') AS duplicated_periods
    FROM (
        SELECT
            es.eventFK AS event_id,
            es.scope_typeFK AS period_id,
            COALESCE(st.name, CAST(es.scope_typeFK AS CHAR)) AS period_name,
            COUNT(DISTINCT sr.event_participantsFK) AS sides_with_row,
            COUNT(*) AS row_count,
            (
                SELECT COUNT(*)
                FROM event_participants epc
                WHERE epc.eventFK = es.eventFK AND epc.del = 'no'
            ) AS event_participant_count
        FROM scope_result sr
        JOIN event_scope es ON es.id = sr.event_scopeFK AND es.del = 'no'
                           AND es.scope_typeFK IN (322, 323, 324)
        JOIN event e2 ON e2.id = es.eventFK AND e2.del = 'no'
        JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
        JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
        JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
             AND tt2.sportFK = 5
        LEFT JOIN scope_type st ON st.id = es.scope_typeFK
        WHERE sr.del = 'no'
          AND sr.scope_data_typeFK = 162
          AND t2.tournament_templateFK IN (31, 32, 33, 308, 313, 328, 546, 10083, 10501, 10560, 10568, 10720, 10738, 10849, 11044, 11076, 11077, 11083, 11091, 11092, 11102, 11103, 11104, 11105, 11285)
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
          -- AND t2.tournament_templateFK = <tournament_template_id>
        GROUP BY es.eventFK, es.scope_typeFK, st.name
    ) p
    GROUP BY p.event_id, p.event_participant_count
) x ON x.event_id = e.id
WHERE e.del = 'no'
  AND (x.short_period_count > 0 OR x.duplicated_period_count > 0)

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT es.eventFK) AS eligible_count,
    1 AS sort_order
FROM scope_result sr
JOIN event_scope es ON es.id = sr.event_scopeFK AND es.del = 'no'
                   AND es.scope_typeFK IN (322, 323, 324)
JOIN event e ON e.id = es.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 5
WHERE sr.del = 'no'
  AND sr.scope_data_typeFK = 162
  AND t.tournament_templateFK IN (31, 32, 33, 308, 313, 328, 546, 10083, 10501, 10560, 10568, 10720, 10738, 10849, 11044, 11076, 11077, 11083, 11091, 11092, 11102, 11103, 11104, 11105, 11285)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, event_startdate, event_id;


-- ================================================================================
SELECT
    -- CheckID - Ice-Hockey-DQ-101
    -- Name - EVENT_RESULTS_PERIOD_SCORE_DISAGREES_WITH_THE_BOXSCORE
    -- What it does: Flags participations whose period goals differ between the result layer and the boxscore.
    'PERIOD_SCORE_DISAGREES_BETWEEN_THE_TWO_LAYERS' AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    tt.name AS template_name,
    t.name AS tournament_name,
    st.name AS period_name,
    pt.name AS participant_name,
    sr.value AS boxscore_says,
    r.value AS result_says,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds a participation whose goals in one period are stored
-- twice and differently - once in the result layer as type 51, 52 or 53, and once in the
-- boxscore as the 162 goals field of the matching period scope.
FROM scope_result sr
JOIN event_scope es ON es.id = sr.event_scopeFK AND es.del = 'no'
                   AND es.scope_typeFK IN (322, 323, 324)
JOIN scope_type st ON st.id = es.scope_typeFK
JOIN event e ON e.id = es.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 5
-- The period scope ids run 271 above their result types - 322 to 51, 323 to 52, 324 to 53 -
-- and the arithmetic is written out rather than hidden in a CASE so that a fourth period
-- arriving under a scope type that does not continue the run is simply not matched, instead
-- of being matched to the wrong result type. SPORTS/Ice-Hockey.md records both vocabularies.
JOIN result r ON r.event_participantsFK = sr.event_participantsFK AND r.del = 'no'
     AND r.result_typeFK = es.scope_typeFK - 271
     AND TRIM(COALESCE(r.value, '')) REGEXP '^[0-9]+$'
JOIN event_participants ep ON ep.id = sr.event_participantsFK AND ep.del = 'no'
JOIN participant pt ON pt.id = ep.participantFK AND pt.del = 'no'
WHERE sr.del = 'no'
  AND sr.scope_data_typeFK = 162
  AND TRIM(COALESCE(sr.value, '')) REGEXP '^[0-9]+$'
  AND CAST(sr.value AS SIGNED) <> CAST(r.value AS SIGNED)
  AND t.tournament_templateFK IN (31, 32, 33, 308, 313, 328, 546, 10083, 10501, 10560, 10568, 10720, 10738, 10849, 11044, 11076, 11077, 11083, 11091, 11092, 11102, 11103, 11104, 11105, 11285)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT es.eventFK) AS eligible_count,
    1 AS sort_order
-- Eligible is an event storing a period in both layers for the same participation, which is
-- the only population where the two can be compared at all. An event holding the period in
-- one layer only is not a disagreement and is counted nowhere here.
FROM scope_result sr
JOIN event_scope es ON es.id = sr.event_scopeFK AND es.del = 'no'
                   AND es.scope_typeFK IN (322, 323, 324)
JOIN event e ON e.id = es.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 5
JOIN result r ON r.event_participantsFK = sr.event_participantsFK AND r.del = 'no'
     AND r.result_typeFK = es.scope_typeFK - 271
     AND TRIM(COALESCE(r.value, '')) REGEXP '^[0-9]+$'
WHERE sr.del = 'no'
  AND sr.scope_data_typeFK = 162
  AND TRIM(COALESCE(sr.value, '')) REGEXP '^[0-9]+$'
  AND t.tournament_templateFK IN (31, 32, 33, 308, 313, 328, 546, 10083, 10501, 10560, 10568, 10720, 10738, 10849, 11044, 11076, 11077, 11083, 11091, 11092, 11102, 11103, 11104, 11105, 11285)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, event_startdate, event_id, period_name;


-- ================================================================================
SELECT
    -- CheckID - Ice-Hockey-DQ-102
    -- Name - COMP.RANK_TOURNAMENT_MISSING_THE_TEAM_OR_THE_ATHLETE_RANKING
    -- What it does: Flags tournaments that hold matches but not both the team and the athlete Comp.Rank.
    CASE
        WHEN x.comp_ranks = 0 THEN 'TOURNAMENT_HAS_NO_COMP.RANK_AT_ALL'
        WHEN x.athlete_comp_ranks = 0 THEN 'TOURNAMENT_HAS_NO_ATHLETE_COMP.RANK'
        ELSE 'TOURNAMENT_HAS_NO_TEAM_COMP.RANK'
    END AS check_type,
    x.tournament_id,
    x.tournament_name,
    x.template_name,
    x.first_event_date,
    x.events,
    x.comp_ranks,
    x.team_comp_ranks,
    x.athlete_comp_ranks,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds a tournament that staged at least one match and does not
-- carry both shapes of Comp.Rank the sport is confirmed to keep - one ranking the teams and one
-- ranking the players.
FROM (
    SELECT
        t.id AS tournament_id,
        MIN(t.name) AS tournament_name,
        MIN(tt.name) AS template_name,
        MIN(DATE(e.startdate)) AS first_event_date,
        COUNT(DISTINCT e.id) AS events,
        COUNT(DISTINCT s.id) AS comp_ranks,
        COUNT(DISTINCT CASE WHEN p.type = 'team' THEN s.id END) AS team_comp_ranks,
        COUNT(DISTINCT CASE WHEN p.type <> 'team' THEN s.id END) AS athlete_comp_ranks
    FROM tournament t
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = 5
    JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
    JOIN event e ON e.tournament_stageFK = ts.id AND e.del = 'no'
    LEFT JOIN statistic s ON s.objectFK = t.id AND s.del = 'no'
         AND s.statistic_typeFK = 11 AND s.object_typeFK = 3
    LEFT JOIN statistic_participants11 sp ON sp.statisticFK = s.id AND sp.del = 'no'
    LEFT JOIN participant p ON p.id = sp.participantFK AND p.del = 'no'
    WHERE t.del = 'no'
      AND t.tournament_templateFK IN (31, 32, 33, 308, 313, 328, 546, 10083, 10501, 10560, 10568, 10720, 10738, 10849, 11044, 11076, 11077, 11083, 11091, 11092, 11102, 11103, 11104, 11105, 11285)
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
    GROUP BY t.id
) x
-- The join to event is inner on purpose: a tournament that staged nothing cannot be asked for a
-- ranking of it, and 55 of the sport's tournaments hold no event at all. That is a separate
-- defect and SPORTS/Ice-Hockey.md records it rather than this check reporting it here.
WHERE x.comp_ranks = 0 OR x.team_comp_ranks = 0 OR x.athlete_comp_ranks = 0

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT t.id) AS eligible_count,
    1 AS sort_order
FROM tournament t
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 5
JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
JOIN event e ON e.tournament_stageFK = ts.id AND e.del = 'no'
WHERE t.del = 'no'
  AND t.tournament_templateFK IN (31, 32, 33, 308, 313, 328, 546, 10083, 10501, 10560, 10568, 10720, 10738, 10849, 11044, 11076, 11077, 11083, 11091, 11092, 11102, 11103, 11104, 11105, 11285)
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, first_event_date, tournament_id;


-- ================================================================================
SELECT
    -- CheckID - Ice-Hockey-DQ-103
    -- Name - COMP.RANK_ATHLETE_ROW_DOES_NOT_NAME_ITS_TEAM
    -- What it does: Flags athlete Comp.Rank rows whose Team field is empty or does not name a team.
    CASE
        WHEN x.rows_without_team > 0 AND x.rows_bad_team > 0
            THEN 'ATHLETE_ROWS_BOTH_MISSING_A_TEAM_AND_NAMING_A_NON_TEAM'
        WHEN x.rows_without_team > 0
            THEN 'ATHLETE_ROW_HOLDS_NO_TEAM'
        ELSE 'ATHLETE_ROW_TEAM_DOES_NOT_NAME_A_TEAM'
    END AS check_type,
    x.statistic_id,
    x.statistic_name,
    x.template_name,
    x.tournament_name,
    x.ranked_rows,
    x.rows_without_team,
    x.rows_bad_team,
    x.affected_participants,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds a Comp.Rank that ranks people and does not say which side
-- each of them played for - the 1429 Team field empty, or holding a value that is not an active
-- team participant.
FROM (
    SELECT
        s.id AS statistic_id,
        MIN(s.name) AS statistic_name,
        MIN(tt.name) AS template_name,
        MIN(t.name) AS tournament_name,
        COUNT(DISTINCT sp.id) AS ranked_rows,
        COUNT(DISTINCT CASE WHEN td.id IS NULL THEN sp.id END) AS rows_without_team,
        COUNT(DISTINCT CASE WHEN td.id IS NOT NULL AND (tp.id IS NULL OR tp.type <> 'team')
                            THEN sp.id END) AS rows_bad_team,
        SUBSTRING(GROUP_CONCAT(DISTINCT CASE
            WHEN td.id IS NULL OR tp.id IS NULL OR tp.type <> 'team' THEN p.name
        END ORDER BY p.name SEPARATOR ', '), 1, 300) AS affected_participants
    FROM statistic s
    JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = 5
    JOIN statistic_participants11 sp ON sp.statisticFK = s.id AND sp.del = 'no'
    JOIN participant p ON p.id = sp.participantFK AND p.del = 'no' AND p.type <> 'team'
    LEFT JOIN statistic_data11 td ON td.statistic_participants11FK = sp.id AND td.del = 'no'
         AND td.statistic_data_typeFK = 1429 AND TRIM(COALESCE(td.value, '')) <> ''
    LEFT JOIN participant tp ON tp.id = TRIM(td.value) AND tp.del = 'no'
    WHERE s.del = 'no'
      AND s.statistic_typeFK = 11
      AND s.object_typeFK = 3
      AND t.tournament_templateFK IN (31, 32, 33, 308, 313, 328, 546, 10083, 10501, 10560, 10568, 10720, 10738, 10849, 11044, 11076, 11077, 11083, 11091, 11092, 11102, 11103, 11104, 11105, 11285)
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
    GROUP BY s.id
) x
-- Only a Comp.Rank ranking people is eligible, which is why the participant join excludes the
-- team type rather than filtering the statistic: a standings table is the other half of the
-- pair the sport keeps and carries no affiliation by design. Ice-Hockey-DQ-102 asserts that both
-- halves exist; this one asserts that the half naming people is complete.
WHERE x.rows_without_team > 0 OR x.rows_bad_team > 0

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count,
    1 AS sort_order
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 5
JOIN statistic_participants11 sp ON sp.statisticFK = s.id AND sp.del = 'no'
JOIN participant p ON p.id = sp.participantFK AND p.del = 'no' AND p.type <> 'team'
WHERE s.del = 'no'
  AND s.statistic_typeFK = 11
  AND s.object_typeFK = 3
  AND t.tournament_templateFK IN (31, 32, 33, 308, 313, 328, 546, 10083, 10501, 10560, 10568, 10720, 10738, 10849, 11044, 11076, 11077, 11083, 11091, 11092, 11102, 11103, 11104, 11105, 11285)
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, template_name, tournament_name, statistic_id;


-- ================================================================================
SELECT
    -- CheckID - Ice-Hockey-DQ-104
    -- Name - EVENT_RESULTS_REGULATION_AND_FINAL_SCORE_DO_NOT_ADD_UP
    -- What it does: Flags finished events where regulation time is not the three periods, or the final result is not regulation plus overtime plus the shootout.
    CASE
        WHEN x.sides_failing_regulation > 0 AND x.sides_failing_final > 0
            THEN 'REGULATION_AND_FINAL_BOTH_DISAGREE'
        WHEN x.sides_failing_regulation > 0
            THEN 'ORDINARY_TIME_IS_NOT_THE_THREE_PERIODS'
        ELSE 'FINAL_RESULT_IS_NOT_ORDINARY_TIME_PLUS_EXTRA_TIME_AND_SHOOTOUT'
    END AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    tt.name AS template_name,
    t.name AS tournament_name,
    sd.name AS status_desc_name,
    x.sides_entered,
    x.sides_failing_regulation,
    x.sides_failing_final,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds a finished event whose score does not add up along the
-- two links the sport stores it in - the three periods into 1 Ordinary time, and ordinary time
-- with 2 Extra time and 3 Penalty shootout into 4 Final Result.
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
LEFT JOIN status_desc sd ON sd.id = e.status_descFK
-- Two assertions in one statement because they are one arithmetic read in two steps, and
-- separating them would report the same import twice. Ice-Hockey-DQ-059 sums the periods
-- straight into the final result and would pass an event whose two errors cancel; this one
-- names which link broke. 1 Ordinary time is read by no other check in the sport.
JOIN (
    SELECT
        b.event_id,
        COUNT(*) AS sides_entered,
        SUM(CASE WHEN b.ordinary <> b.p1 + b.p2 + b.p3 THEN 1 ELSE 0 END) AS sides_failing_regulation,
        SUM(CASE WHEN b.final <> b.ordinary + b.ot + b.so THEN 1 ELSE 0 END) AS sides_failing_final
    FROM (
        SELECT
            e2.id AS event_id,
            ep.id AS ep_id,
            MAX(CASE WHEN r.result_typeFK = 1 THEN CAST(r.value AS SIGNED) END) AS ordinary,
            MAX(CASE WHEN r.result_typeFK = 51 THEN CAST(r.value AS SIGNED) END) AS p1,
            MAX(CASE WHEN r.result_typeFK = 52 THEN CAST(r.value AS SIGNED) END) AS p2,
            MAX(CASE WHEN r.result_typeFK = 53 THEN CAST(r.value AS SIGNED) END) AS p3,
            COALESCE(MAX(CASE WHEN r.result_typeFK = 2 THEN CAST(r.value AS SIGNED) END), 0) AS ot,
            COALESCE(MAX(CASE WHEN r.result_typeFK = 3 THEN CAST(r.value AS SIGNED) END), 0) AS so,
            MAX(CASE WHEN r.result_typeFK = 4 THEN CAST(r.value AS SIGNED) END) AS final
        FROM event e2
        JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
        JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
        JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
             AND tt2.sportFK = 5
        JOIN event_participants ep ON ep.eventFK = e2.id AND ep.del = 'no'
        JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
             AND r.result_typeFK IN (1, 2, 3, 4, 51, 52, 53)
             AND TRIM(COALESCE(r.value, '')) REGEXP '^[0-9]+$'
        WHERE e2.del = 'no'
          AND e2.status_type = 'finished'
          AND t2.tournament_templateFK IN (31, 32, 33, 308, 313, 328, 546, 10083, 10501, 10560, 10568, 10720, 10738, 10849, 11044, 11076, 11077, 11083, 11091, 11092, 11102, 11103, 11104, 11105, 11285)
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
          -- AND t2.tournament_templateFK = <tournament_template_id>
        GROUP BY e2.id, ep.id
        HAVING ordinary IS NOT NULL AND final IS NOT NULL
           AND p1 IS NOT NULL AND p2 IS NOT NULL AND p3 IS NOT NULL
    ) b
    GROUP BY b.event_id
    HAVING sides_failing_regulation > 0 OR sides_failing_final > 0
) x ON x.event_id = e.id
WHERE e.del = 'no'

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT b2.event_id) AS eligible_count,
    1 AS sort_order
FROM (
    SELECT
        e3.id AS event_id,
        ep3.id AS ep_id,
        MAX(CASE WHEN r3.result_typeFK = 1 THEN CAST(r3.value AS SIGNED) END) AS ordinary,
        MAX(CASE WHEN r3.result_typeFK = 51 THEN CAST(r3.value AS SIGNED) END) AS p1,
        MAX(CASE WHEN r3.result_typeFK = 52 THEN CAST(r3.value AS SIGNED) END) AS p2,
        MAX(CASE WHEN r3.result_typeFK = 53 THEN CAST(r3.value AS SIGNED) END) AS p3,
        MAX(CASE WHEN r3.result_typeFK = 4 THEN CAST(r3.value AS SIGNED) END) AS final
    FROM event e3
    JOIN tournament_stage ts3 ON ts3.id = e3.tournament_stageFK AND ts3.del = 'no'
    JOIN tournament t3 ON t3.id = ts3.tournamentFK AND t3.del = 'no'
    JOIN tournament_template tt3 ON tt3.id = t3.tournament_templateFK AND tt3.del = 'no'
         AND tt3.sportFK = 5
    JOIN event_participants ep3 ON ep3.eventFK = e3.id AND ep3.del = 'no'
    JOIN result r3 ON r3.event_participantsFK = ep3.id AND r3.del = 'no'
         AND r3.result_typeFK IN (1, 4, 51, 52, 53)
         AND TRIM(COALESCE(r3.value, '')) REGEXP '^[0-9]+$'
    WHERE e3.del = 'no'
      AND e3.status_type = 'finished'
      AND t3.tournament_templateFK IN (31, 32, 33, 308, 313, 328, 546, 10083, 10501, 10560, 10568, 10720, 10738, 10849, 11044, 11076, 11077, 11083, 11091, 11092, 11102, 11103, 11104, 11105, 11285)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t3.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t3.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t3.tournament_templateFK = <tournament_template_id>
    GROUP BY e3.id, ep3.id
    HAVING ordinary IS NOT NULL AND final IS NOT NULL
       AND p1 IS NOT NULL AND p2 IS NOT NULL AND p3 IS NOT NULL
) b2

ORDER BY sort_order, event_startdate, event_id;


-- ================================================================================
SELECT
    -- CheckID - Ice-Hockey-DQ-105
    -- Name - EVENT_STATUS_CONTRADICTS_THE_OVERTIME_OR_SHOOTOUT_SCORE
    -- What it does: Flags finished events whose detailed status disagrees with whether an overtime or shootout score exists.
    CASE
        WHEN x.has_shootout = 1 AND e.status_descFK = 59
            THEN 'SHOOTOUT_SCORED_WHILE_THE_STATUS_SAYS_DECIDED_IN_OVERTIME'
        WHEN x.has_shootout = 1 AND e.status_descFK NOT IN (13, 59)
            THEN 'SHOOTOUT_SCORED_WHILE_THE_STATUS_SAYS_REGULATION'
        WHEN x.has_extra_time = 1 AND e.status_descFK NOT IN (13, 59)
            THEN 'OVERTIME_SCORED_WHILE_THE_STATUS_SAYS_REGULATION'
        WHEN x.has_shootout = 0 AND e.status_descFK = 13
            THEN 'STATUS_SAYS_DECIDED_ON_PENALTIES_AND_NO_SHOOTOUT_IS_SCORED'
        ELSE 'STATUS_SAYS_DECIDED_IN_OVERTIME_AND_NO_OVERTIME_IS_SCORED'
    END AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    tt.name AS template_name,
    t.name AS tournament_name,
    sd.name AS status_desc_name,
    x.has_extra_time,
    x.has_shootout,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds a finished event where how it was decided and how it is
-- said to have been decided do not agree - a shootout score under a status that names overtime
-- or regulation, an overtime score under a status that names regulation, or either status
-- standing over a score that was never written.
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
LEFT JOIN status_desc sd ON sd.id = e.status_descFK
-- The pairing is the sport's own: 13 Finished AP means the shootout decided it and 59 Finished
-- OT means overtime did, and a shootout is only ever reached through overtime, so 13 legitimately
-- carries both scores while 59 carries only the overtime one. 190 Finished after awarded win is
-- left out of the assertion in both directions - an awarded win is not a way of playing the game
-- out - and 6 Finished must carry neither. SPORTS/Ice-Hockey.md records the four descriptions.
-- This is the sport variant of GLOBAL-DQ-089, which reads an extra-period scope column this
-- sport does not have; the same question is asked of the result layer instead.
JOIN (
    SELECT
        ep.eventFK AS event_id,
        MAX(CASE WHEN r.result_typeFK = 2 THEN 1 ELSE 0 END) AS has_extra_time,
        MAX(CASE WHEN r.result_typeFK = 3 THEN 1 ELSE 0 END) AS has_shootout
    FROM event_participants ep
    JOIN event e2 ON e2.id = ep.eventFK AND e2.del = 'no'
    JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
    JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
    JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
         AND tt2.sportFK = 5
    LEFT JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
         AND r.result_typeFK IN (2, 3)
    WHERE ep.del = 'no'
      AND e2.status_type = 'finished'
      AND e2.status_descFK IN (6, 13, 59)
      AND t2.tournament_templateFK IN (31, 32, 33, 308, 313, 328, 546, 10083, 10501, 10560, 10568, 10720, 10738, 10849, 11044, 11076, 11077, 11083, 11091, 11092, 11102, 11103, 11104, 11105, 11285)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t2.tournament_templateFK = <tournament_template_id>
    GROUP BY ep.eventFK
) x ON x.event_id = e.id
WHERE e.del = 'no'
  AND (
      (e.status_descFK = 6 AND (x.has_extra_time = 1 OR x.has_shootout = 1))
   OR (e.status_descFK = 59 AND (x.has_extra_time = 0 OR x.has_shootout = 1))
   OR (e.status_descFK = 13 AND (x.has_extra_time = 0 OR x.has_shootout = 0))
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 5
WHERE e.del = 'no'
  AND e.status_type = 'finished'
  AND e.status_descFK IN (6, 13, 59)
  AND t.tournament_templateFK IN (31, 32, 33, 308, 313, 328, 546, 10083, 10501, 10560, 10568, 10720, 10738, 10849, 11044, 11076, 11077, 11083, 11091, 11092, 11102, 11103, 11104, 11105, 11285)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, event_startdate, event_id;


-- ================================================================================
SELECT
    -- CheckID - Ice-Hockey-DQ-106
    -- Name - EVENT_GOAL_INCIDENTS_DO_NOT_ADD_UP_TO_THE_SCORE
    -- What it does: Flags events where the number of goal incidents recorded for a side differs from that side's final result.
    CASE
        WHEN x.sides_short > 0 AND x.sides_over > 0 THEN 'ONE_SIDE_HAS_TOO_FEW_GOALS_AND_THE_OTHER_TOO_MANY'
        WHEN x.sides_short > 0 THEN 'FEWER_GOAL_INCIDENTS_THAN_THE_SCORE'
        ELSE 'MORE_GOAL_INCIDENTS_THAN_THE_SCORE'
    END AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    tt.name AS template_name,
    t.name AS tournament_name,
    x.sides_entered,
    x.sides_short,
    x.sides_over,
    x.goals_of_difference,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds an event whose timed goals and whose scoreline disagree,
-- by counting the goal incidents written against each side and comparing that count with the
-- side's 4 Final Result.
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
-- Only an event that carries at least one goal incident is eligible. The incident layer reaches
-- roughly a fifth of the boundary, so asserting it everywhere would report the coverage of the
-- layer rather than a defect - SPORTS/Ice-Hockey.md records the reach. Five incident types are
-- goals and a sixth shares their code while being a miss: 7, 21, 22 and 8 are scored in play and
-- 12 is a converted shootout attempt, while 11 Penalty shootout missed is excluded by id because
-- its code cannot be trusted.
JOIN (
    SELECT
        b.event_id,
        COUNT(*) AS sides_entered,
        SUM(CASE WHEN b.goal_incidents < b.final THEN 1 ELSE 0 END) AS sides_short,
        SUM(CASE WHEN b.goal_incidents > b.final THEN 1 ELSE 0 END) AS sides_over,
        SUM(ABS(b.goal_incidents - b.final)) AS goals_of_difference
    FROM (
        SELECT
            e2.id AS event_id,
            ep.id AS ep_id,
            MAX(CASE WHEN r.result_typeFK = 4 THEN CAST(r.value AS SIGNED) END) AS final,
            (
                SELECT COUNT(*)
                FROM incident i
                WHERE i.event_participantsFK = ep.id AND i.del = 'no'
                  AND i.incident_typeFK IN (7, 8, 12, 21, 22)
            ) AS goal_incidents
        FROM event e2
        JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
        JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
        JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
             AND tt2.sportFK = 5
        JOIN event_participants ep ON ep.eventFK = e2.id AND ep.del = 'no'
        JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
             AND r.result_typeFK = 4 AND TRIM(COALESCE(r.value, '')) REGEXP '^[0-9]+$'
        WHERE e2.del = 'no'
          AND e2.status_type = 'finished'
          AND t2.tournament_templateFK IN (31, 32, 33, 308, 313, 328, 546, 10083, 10501, 10560, 10568, 10720, 10738, 10849, 11044, 11076, 11077, 11083, 11091, 11092, 11102, 11103, 11104, 11105, 11285)
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
          -- AND t2.tournament_templateFK = <tournament_template_id>
          AND EXISTS (
              SELECT 1 FROM incident i2
              JOIN event_participants ep2 ON ep2.id = i2.event_participantsFK AND ep2.del = 'no'
              WHERE ep2.eventFK = e2.id AND i2.del = 'no'
                AND i2.incident_typeFK IN (7, 8, 12, 21, 22)
          )
        GROUP BY e2.id, ep.id
    ) b
    GROUP BY b.event_id
    HAVING sides_short > 0 OR sides_over > 0
) x ON x.event_id = e.id
WHERE e.del = 'no'

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
     AND tt.sportFK = 5
WHERE e.del = 'no'
  AND e.status_type = 'finished'
  AND t.tournament_templateFK IN (31, 32, 33, 308, 313, 328, 546, 10083, 10501, 10560, 10568, 10720, 10738, 10849, 11044, 11076, 11077, 11083, 11091, 11092, 11102, 11103, 11104, 11105, 11285)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND EXISTS (
      SELECT 1 FROM incident i3
      JOIN event_participants ep3 ON ep3.id = i3.event_participantsFK AND ep3.del = 'no'
      WHERE ep3.eventFK = e.id AND i3.del = 'no'
        AND i3.incident_typeFK IN (7, 8, 12, 21, 22)
  )

ORDER BY sort_order, event_startdate, event_id;


-- ================================================================================
SELECT
    -- CheckID - Ice-Hockey-DQ-107
    -- Name - COMP.RANK_ATHLETE_TEAM_IS_NOT_A_SIDE_THE_PLAYER_PLAYED_FOR
    -- What it does: Flags athlete Comp.Rank rows whose Team names a side the player never appeared for in that tournament.
    'ATHLETE_TEAM_IS_NOT_A_SIDE_THE_PLAYER_PLAYED_FOR' AS check_type,
    s.id AS statistic_id,
    s.name AS statistic_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    p.id AS participant_id,
    p.name AS participant_name,
    tp.name AS team_named,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds a player ranked in a tournament's Comp.Rank whose 1429
-- Team field names a team that the player never appeared in the lineup of, inside that same
-- tournament.
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 5
JOIN statistic_participants11 sp ON sp.statisticFK = s.id AND sp.del = 'no'
JOIN participant p ON p.id = sp.participantFK AND p.del = 'no' AND p.type = 'athlete'
JOIN statistic_data11 sd ON sd.statistic_participants11FK = sp.id AND sd.del = 'no'
     AND sd.statistic_data_typeFK = 1429 AND TRIM(COALESCE(sd.value, '')) <> ''
JOIN participant tp ON tp.id = TRIM(sd.value) AND tp.del = 'no' AND tp.type = 'team'
-- Ice-Hockey-DQ-103 asserts that the Team field is filled and names a team; this asserts that it
-- names the right one, which only the lineup can say. The eligible population is therefore a
-- player who appears in a lineup somewhere in this tournament: without one there is nothing to
-- check against, and 194 rows measured on 2026-08-15 are in that position rather than wrong.
-- The lineup EXISTS is also what keeps the statement runnable - the layer reaches 43 tournaments
-- of 414, and evaluating the comparison over the rest returned a gateway timeout twice.
WHERE s.del = 'no'
  AND s.statistic_typeFK = 11
  AND s.object_typeFK = 3
  AND t.tournament_templateFK IN (31, 32, 33, 308, 313, 328, 546, 10083, 10501, 10560, 10568, 10720, 10738, 10849, 11044, 11076, 11077, 11083, 11091, 11092, 11102, 11103, 11104, 11105, 11285)
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND EXISTS (
      SELECT 1
      FROM lineup l9
      JOIN event_participants ep9 ON ep9.id = l9.event_participantsFK AND ep9.del = 'no'
      JOIN event e9 ON e9.id = ep9.eventFK AND e9.del = 'no'
      JOIN tournament_stage ts9 ON ts9.id = e9.tournament_stageFK AND ts9.del = 'no'
      WHERE l9.participantFK = sp.participantFK AND l9.del = 'no'
        AND ts9.tournamentFK = s.objectFK
  )
  AND NOT EXISTS (
      SELECT 1
      FROM lineup l8
      JOIN event_participants ep8 ON ep8.id = l8.event_participantsFK AND ep8.del = 'no'
      JOIN event e8 ON e8.id = ep8.eventFK AND e8.del = 'no'
      JOIN tournament_stage ts8 ON ts8.id = e8.tournament_stageFK AND ts8.del = 'no'
      WHERE l8.participantFK = sp.participantFK AND l8.del = 'no'
        AND ts8.tournamentFK = s.objectFK
        AND ep8.participantFK = tp.id
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT sp.id) AS eligible_count,
    1 AS sort_order
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 5
JOIN statistic_participants11 sp ON sp.statisticFK = s.id AND sp.del = 'no'
JOIN participant p ON p.id = sp.participantFK AND p.del = 'no' AND p.type = 'athlete'
JOIN statistic_data11 sd ON sd.statistic_participants11FK = sp.id AND sd.del = 'no'
     AND sd.statistic_data_typeFK = 1429 AND TRIM(COALESCE(sd.value, '')) <> ''
JOIN participant tp ON tp.id = TRIM(sd.value) AND tp.del = 'no' AND tp.type = 'team'
WHERE s.del = 'no'
  AND s.statistic_typeFK = 11
  AND s.object_typeFK = 3
  AND t.tournament_templateFK IN (31, 32, 33, 308, 313, 328, 546, 10083, 10501, 10560, 10568, 10720, 10738, 10849, 11044, 11076, 11077, 11083, 11091, 11092, 11102, 11103, 11104, 11105, 11285)
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND EXISTS (
      SELECT 1
      FROM lineup l7
      JOIN event_participants ep7 ON ep7.id = l7.event_participantsFK AND ep7.del = 'no'
      JOIN event e7 ON e7.id = ep7.eventFK AND e7.del = 'no'
      JOIN tournament_stage ts7 ON ts7.id = e7.tournament_stageFK AND ts7.del = 'no'
      WHERE l7.participantFK = sp.participantFK AND l7.del = 'no'
        AND ts7.tournamentFK = s.objectFK
  )

ORDER BY sort_order, template_name, tournament_name, participant_name;



-- ================================================================================
SELECT
    -- CheckID - Ice-Hockey-DQ-108
    -- Name - COMP.RANK_PLAYER_RANKING_COVERS_NEITHER_EVERY_TEAM_NOR_THE_MEDALLISTS
    -- What it does: Flags tournaments whose player Comp.Rank lists players for some teams only, covering neither every ranked team nor exactly the medallists.
    CASE
        WHEN x.teams_named > x.ranked_teams
            THEN 'PLAYERS_NAME_A_TEAM_THE_RANKING_DOES_NOT_HOLD'
        WHEN x.teams_named < x.medal_teams
            THEN 'NOT_EVEN_EVERY_MEDAL_TEAM_HAS_PLAYERS'
        ELSE 'PLAYERS_STOP_PART_WAY_THROUGH_THE_RANKED_TEAMS'
    END AS check_type,
    x.tournament_id,
    x.tournament_name,
    x.template_name,
    x.ranked_teams,
    x.teams_named,
    x.medal_teams,
    x.medal_teams_named,
    x.ranked_teams_without_players,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds a tournament where the two Comp.Rank shapes disagree about
-- which teams took part - the player ranking listing players for some of the ranked teams but
-- neither for all of them nor for exactly the ones that won a medal.
FROM (
    SELECT
        s.objectFK AS tournament_id,
        MIN(t.name) AS tournament_name,
        MIN(tt.name) AS template_name,
        COUNT(DISTINCT CASE WHEN p.type = 'team' THEN sp.participantFK END) AS ranked_teams,
        COUNT(DISTINCT CASE WHEN p.type <> 'team' THEN CAST(TRIM(td.value) AS UNSIGNED) END) AS teams_named,
        COUNT(DISTINCT CASE WHEN p.type = 'team' AND md.id IS NOT NULL THEN sp.participantFK END) AS medal_teams,
        COUNT(DISTINCT CASE WHEN p.type = 'team' AND md.id IS NOT NULL AND pn.team_id IS NOT NULL
                            THEN sp.participantFK END) AS medal_teams_named,
        SUBSTRING(GROUP_CONCAT(DISTINCT CASE
            WHEN p.type = 'team' AND pn.team_id IS NULL THEN p.name
        END ORDER BY p.name SEPARATOR ', '), 1, 300) AS ranked_teams_without_players
    FROM statistic s
    JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = 5
    JOIN statistic_participants11 sp ON sp.statisticFK = s.id AND sp.del = 'no'
    JOIN participant p ON p.id = sp.participantFK AND p.del = 'no'
    LEFT JOIN statistic_data11 td ON td.statistic_participants11FK = sp.id AND td.del = 'no'
         AND td.statistic_data_typeFK = 1429 AND TRIM(COALESCE(td.value, '')) <> ''
    LEFT JOIN statistic_data11 md ON md.statistic_participants11FK = sp.id AND md.del = 'no'
         AND md.statistic_data_typeFK = 1277 AND TRIM(COALESCE(md.value, '')) <> ''
    -- The set of teams a tournament's player rows name is built once here rather than asked
    -- again for every row of every statistic. Asked per row it is two correlated subqueries over
    -- 43708 player rows and the server returns a gateway timeout; built once it is roughly two
    -- thousand pairs. WORKFLOW.md owns the rule that a statement which will not run is
    -- redesigned rather than cut into pieces.
    LEFT JOIN (
        SELECT DISTINCT
            s7.objectFK AS tournament_id,
            CAST(TRIM(td7.value) AS UNSIGNED) AS team_id
        FROM statistic s7
        JOIN tournament t7 ON t7.id = s7.objectFK AND t7.del = 'no'
        JOIN tournament_template tt7 ON tt7.id = t7.tournament_templateFK AND tt7.del = 'no'
             AND tt7.sportFK = 5
        JOIN statistic_participants11 sp7 ON sp7.statisticFK = s7.id AND sp7.del = 'no'
        JOIN statistic_data11 td7 ON td7.statistic_participants11FK = sp7.id AND td7.del = 'no'
             AND td7.statistic_data_typeFK = 1429 AND TRIM(COALESCE(td7.value, '')) <> ''
        WHERE s7.del = 'no' AND s7.statistic_typeFK = 11 AND s7.object_typeFK = 3
          AND t7.tournament_templateFK IN (31, 32, 33, 308, 313, 328, 546, 10083, 10501, 10560, 10568, 10720, 10738, 10849, 11044, 11076, 11077, 11083, 11091, 11092, 11102, 11103, 11104, 11105, 11285)
          AND (tt7.name IS NULL OR tt7.name NOT LIKE '%(IOC)%')
    ) pn ON pn.tournament_id = s.objectFK AND pn.team_id = sp.participantFK
    WHERE s.del = 'no' AND s.statistic_typeFK = 11 AND s.object_typeFK = 3
      AND t.tournament_templateFK IN (31, 32, 33, 308, 313, 328, 546, 10083, 10501, 10560, 10568, 10720, 10738, 10849, 11044, 11076, 11077, 11083, 11091, 11092, 11102, 11103, 11104, 11105, 11285)
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
    GROUP BY s.objectFK
    HAVING ranked_teams > 0 AND teams_named > 0
) x
-- Two shapes are correct and the sport uses both. Since 1999 every ranked team carries a squad,
-- and from 1920 to 2004 only the medallists did - 75 tournaments where exactly gold, silver and
-- bronze hold a full 22 to 25 man roster and nobody else holds one. Neither is a defect, so the
-- check asserts the pair rather than one of them: a tournament covering some teams but not all,
-- and not exactly the ones that medalled, is an import that stopped part way. Measured
-- 2026-08-15 that is 4 tournaments of 233, and two of them are a silver medallist whose whole
-- squad is absent. SPORTS/Ice-Hockey.md records the two conventions and where each applies.
WHERE NOT (x.teams_named = x.ranked_teams)
  AND NOT (x.teams_named = x.medal_teams AND x.teams_named = x.medal_teams_named)

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT y.tournament_id) AS eligible_count,
    1 AS sort_order
FROM (
    SELECT
        s.objectFK AS tournament_id,
        COUNT(DISTINCT CASE WHEN p.type = 'team' THEN sp.participantFK END) AS ranked_teams,
        COUNT(DISTINCT CASE WHEN p.type <> 'team' THEN CAST(TRIM(td.value) AS UNSIGNED) END) AS teams_named
    FROM statistic s
    JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = 5
    JOIN statistic_participants11 sp ON sp.statisticFK = s.id AND sp.del = 'no'
    JOIN participant p ON p.id = sp.participantFK AND p.del = 'no'
    LEFT JOIN statistic_data11 td ON td.statistic_participants11FK = sp.id AND td.del = 'no'
         AND td.statistic_data_typeFK = 1429 AND TRIM(COALESCE(td.value, '')) <> ''
    WHERE s.del = 'no' AND s.statistic_typeFK = 11 AND s.object_typeFK = 3
      AND t.tournament_templateFK IN (31, 32, 33, 308, 313, 328, 546, 10083, 10501, 10560, 10568, 10720, 10738, 10849, 11044, 11076, 11077, 11083, 11091, 11092, 11102, 11103, 11104, 11105, 11285)
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
    GROUP BY s.objectFK
    HAVING ranked_teams > 0 AND teams_named > 0
) y

ORDER BY sort_order, template_name, tournament_name;


-- ================================================================================
SELECT
    -- CheckID - Ice-Hockey-DQ-109
    -- Name - EVENT_RESULTS_PERIOD_BREAKDOWN_INCOMPLETE
    -- What it does: Finds finished events that store some periods and not all three.
    CASE
        WHEN x.has_p1 = 1 AND x.has_p2 = 0 AND x.has_p3 = 0
             AND x.sides_equal_to_final = x.sides_entered
            THEN 'PERIOD_1_STANDS_ALONE_AND_EQUALS_THE_FINAL_RESULT'
        WHEN x.has_p1 = 1 AND x.has_p2 = 0 AND x.has_p3 = 0
            THEN 'PERIOD_1_STANDS_ALONE_AND_DIFFERS_FROM_THE_FINAL_RESULT'
        WHEN x.has_p1 = 0
            THEN 'A_LATER_PERIOD_IS_STORED_WITHOUT_THE_FIRST'
        ELSE 'THE_PERIOD_SET_STOPS_BEFORE_THE_THIRD'
    END AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    tt.name AS template_name,
    t.name AS tournament_name,
    sd.name AS status_desc_name,
    x.has_p1,
    x.has_p2,
    x.has_p3,
    x.sides_entered,
    x.sides_equal_to_final,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds a finished event whose period-by-period score is not the
-- three periods the sport plays - most often a first period standing alone whose value is the
-- whole match score.
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
LEFT JOIN status_desc sd ON sd.id = e.status_descFK
-- The dominant shape is not a thin period breakdown but an unanswered question, and the check
-- exists to keep it visible rather than to state its correction. On 1091 of these events the
-- first period equals 4 Final Result on every side, which reads either as the whole score
-- written into a period field or as a first period whose remaining two never arrived - two
-- readings needing opposite repairs. Nothing inside the database separates them: the events
-- carry no goal incident, no lineup row and no period scope container, measured 2026-08-15.
-- Because no further query can settle it, the population is reported rather than investigated,
-- and whoever reads the findings decides what the field means. Until that is settled no
-- statement may treat 51 as a first period, which is why Ice-Hockey-DQ-059 and
-- Ice-Hockey-DQ-104 both audit only sides holding all three. SPORTS/Ice-Hockey.md records it.
JOIN (
    SELECT
        e2.id AS event_id,
        COUNT(DISTINCT ep.id) AS sides_entered,
        MAX(CASE WHEN r.result_typeFK = 51 THEN 1 ELSE 0 END) AS has_p1,
        MAX(CASE WHEN r.result_typeFK = 52 THEN 1 ELSE 0 END) AS has_p2,
        MAX(CASE WHEN r.result_typeFK = 53 THEN 1 ELSE 0 END) AS has_p3,
        SUM(CASE WHEN r.result_typeFK = 51 AND CAST(r.value AS SIGNED) = (
                SELECT CAST(r2.value AS SIGNED)
                FROM result r2
                WHERE r2.event_participantsFK = ep.id AND r2.del = 'no'
                  AND r2.result_typeFK = 4
                LIMIT 1
            ) THEN 1 ELSE 0 END) AS sides_equal_to_final
    FROM event e2
    JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
    JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
    JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
         AND tt2.sportFK = 5
    JOIN event_participants ep ON ep.eventFK = e2.id AND ep.del = 'no'
    JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
         AND r.result_typeFK IN (51, 52, 53)
    WHERE e2.del = 'no'
      AND e2.status_type = 'finished'
      AND t2.tournament_templateFK IN (31, 32, 33, 308, 313, 328, 546, 10083, 10501, 10560, 10568, 10720, 10738, 10849, 11044, 11076, 11077, 11083, 11091, 11092, 11102, 11103, 11104, 11105, 11285)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t2.tournament_templateFK = <tournament_template_id>
    GROUP BY e2.id
    HAVING has_p1 = 0 OR has_p2 = 0 OR has_p3 = 0
) x ON x.event_id = e.id
WHERE e.del = 'no'

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 5
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
     AND r.result_typeFK IN (51, 52, 53)
WHERE e.del = 'no'
  AND e.status_type = 'finished'
  AND t.tournament_templateFK IN (31, 32, 33, 308, 313, 328, 546, 10083, 10501, 10560, 10568, 10720, 10738, 10849, 11044, 11076, 11077, 11083, 11091, 11092, 11102, 11103, 11104, 11105, 11285)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, event_startdate, event_id;


-- ================================================================================
SELECT
    -- CheckID - Ice-Hockey-DQ-110
    -- Name - COMP.RANK_RESULTS_PARTICIPANT_NOT_IN_TOURNAMENT_WITH_LINEUPS
    -- What it does: Flags Comp.Rank participants who never appear in their own tournament, read only where that tournament records who took the ice.
    'PARTICIPANT_NOT_IN_TOURNAMENT' AS check_type,
    s.id AS statistic_id,
    tt.name AS template_name,
    t.name AS tournament_name,
    COUNT(DISTINCT sp.participantFK) AS stray_participants,
    COUNT(DISTINCT sp.id) AS stray_participant_rows,
    GROUP_CONCAT(DISTINCT p.id ORDER BY p.id SEPARATOR ' | ') AS participant_ids,
    GROUP_CONCAT(DISTINCT p.name ORDER BY p.name SEPARATOR ' | ') AS participant_names,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds a Comp.Rank statistic holding participants who are neither
-- an event participant nor a lineup member anywhere under their own tournament, confined to
-- tournaments that store at least one lineup.
-- The confinement is the whole difference from GLOBAL-DQ-030 and is structural rather than a cost
-- measure. The template asserts two participation paths, and in a team sport only one of them can
-- ever succeed for a player: the side entered against event_participants is the team, so an
-- athlete reaches their tournament through lineup or not at all. Ice Hockey writes a lineup for
-- 1616 of its 9803 events, so under a tournament that stores none the template reports every
-- ranked player by construction - measured 2026-08-15, 341 of its 371 statistics and 16650 of the
-- athletes named in them sit in exactly that state, which is the absence of a layer and not a
-- stray entry. Where the layer is present the same rule reads correctly and returns 24
-- statistics over 198 participants. SPORTS/Ice-Hockey.md records the measurement, and
-- SPORTS/params.json classifies GLOBAL-DQ-030 Not applicable for this sport in favour of this
-- statement.
-- Coaches travel with the players and are read the same way: 165 of them hold a lineup row, so
-- the path is theirs too and no participant type is excluded here.
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN statistic_participants11 sp ON sp.statisticFK = s.id AND sp.del = 'no'
JOIN participant p ON p.id = sp.participantFK AND p.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = 11
  AND s.object_typeFK = 3
  AND tt.sportFK = 5
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND t.tournament_templateFK IN (31, 32, 33, 308, 313, 328, 546, 10083, 10501, 10560, 10568, 10720, 10738, 10849, 11044, 11076, 11077, 11083, 11091, 11092, 11102, 11103, 11104, 11105, 11285)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND EXISTS (
      SELECT 1
      FROM tournament_stage ts4
      JOIN event e4 ON e4.tournament_stageFK = ts4.id AND e4.del = 'no'
      JOIN event_participants ep4 ON ep4.eventFK = e4.id AND ep4.del = 'no'
      JOIN lineup l4 ON l4.event_participantsFK = ep4.id AND l4.del = 'no'
      WHERE ts4.tournamentFK = t.id
        AND ts4.del = 'no'
  )
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
    COUNT(DISTINCT s.id) AS eligible_count,
    1 AS sort_order
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN statistic_participants11 sp ON sp.statisticFK = s.id AND sp.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = 11
  AND s.object_typeFK = 3
  AND tt.sportFK = 5
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND t.tournament_templateFK IN (31, 32, 33, 308, 313, 328, 546, 10083, 10501, 10560, 10568, 10720, 10738, 10849, 11044, 11076, 11077, 11083, 11091, 11092, 11102, 11103, 11104, 11105, 11285)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND EXISTS (
      SELECT 1
      FROM tournament_stage ts4
      JOIN event e4 ON e4.tournament_stageFK = ts4.id AND e4.del = 'no'
      JOIN event_participants ep4 ON ep4.eventFK = e4.id AND ep4.del = 'no'
      JOIN lineup l4 ON l4.event_participantsFK = ep4.id AND l4.del = 'no'
      WHERE ts4.tournamentFK = t.id
        AND ts4.del = 'no'
  )

ORDER BY sort_order, template_name, tournament_name;
