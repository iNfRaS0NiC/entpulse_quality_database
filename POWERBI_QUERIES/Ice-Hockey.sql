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
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY e.id, ep.id
    HAVING p1 IS NOT NULL AND p2 IS NOT NULL AND p3 IS NOT NULL AND final_value IS NOT NULL
) d

ORDER BY sort_order, event_startdate, event_id;
