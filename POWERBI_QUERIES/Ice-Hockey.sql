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
