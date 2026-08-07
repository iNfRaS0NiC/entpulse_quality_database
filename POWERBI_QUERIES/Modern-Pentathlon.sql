SELECT
    -- CheckID - Modern-Pentathlon-DQ-092
    -- Name - EVENT_SETTINGS_DISCIPLINE_CONTRADICTS_EVENT_NAME
    -- What it does: Finds template events whose name says one discipline while the object_discipline relation says another, one row per template and event name rather than per event.
    'DISCIPLINE_CONTRADICTS_EVENT_NAME' AS check_type,
    x.template_name,
    x.event_name,
    x.attached_discipline,
    x.name_says AS discipline_the_name_says,
    COUNT(DISTINCT x.event_id) AS event_count,
    MIN(YEAR(x.startdate)) AS first_year,
    MAX(YEAR(x.startdate)) AS last_year,
    SUBSTRING(GROUP_CONCAT(DISTINCT x.stage_gender ORDER BY x.stage_gender SEPARATOR ', '), 1, 60) AS genders,
    NULL AS eligible_count,
    0 AS sort_order
-- Reported per template and event name rather than per event, because that is the shape the
-- defect actually has here: the same template mislabels the same event every edition, so a
-- Swimming Final carrying the Shooting discipline is one mapping to repair and not twenty-four
-- separate ones. The event count and the year span travel with the row, so the size and the age
-- of the exposure stay visible.
-- The name is read for a discipline word rather than parsed, because the sport's event names
-- carry a phase prefix and a segment suffix around it - `Qualification A - After Fencing`,
-- `Team-Relay Mix - After Obstacle` - and only the discipline word inside is asserted here.
-- Overall is treated as a discipline like the others because the sport stores it as one: it is
-- an `object_discipline` value in its own right, and dropping it would silence the largest
-- single case, a Final Overall Classification carrying Obstacle.
-- Laser Run is exempt from the Shooting word. Laser Run *is* combined shooting and running, and
-- the events named `Combined (Shooting/Running)` at the 2012 and 2016 Summer Olympics carry the
-- Laser Run discipline correctly. That is a fact about the sport rather than a tuning value, so
-- it is written into the statement instead of being declared as a parameter.
-- This reads the state of the data rather than a structure, so the finding shrinks as the
-- mislabelled events are repaired. Coverage therefore counts every template and event name the
-- check can judge - a discipline attached and a discipline word in the name - and not only the
-- ones it reports, in the same unit the findings use.
FROM (
    SELECT tt.name AS template_name, e.name AS event_name, d.name AS attached_discipline,
           e.id AS event_id, e.startdate, ts.gender AS stage_gender,
           CASE
             WHEN LOWER(e.name) LIKE '%laser%run%' THEN 'Laser Run'
             WHEN LOWER(e.name) LIKE '%obstacle%'  THEN 'Obstacle'
             WHEN LOWER(e.name) LIKE '%fencing%'   THEN 'Fencing'
             WHEN LOWER(e.name) LIKE '%swimming%'  THEN 'Swimming'
             WHEN LOWER(e.name) LIKE '%riding%'    THEN 'Riding'
             WHEN LOWER(e.name) LIKE '%shooting%'  THEN 'Shooting'
             WHEN LOWER(e.name) LIKE '%running%'   THEN 'Running'
             WHEN LOWER(e.name) LIKE '%overall%'   THEN 'Overall'
             ELSE NULL
           END AS name_says
    FROM tournament_template tt
    JOIN tournament t ON t.tournament_templateFK = tt.id AND t.del = 'no'
    JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
    JOIN event e ON e.tournament_stageFK = ts.id AND e.del = 'no'
    JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
    JOIN discipline d ON d.id = od.disciplineFK
    WHERE tt.sportFK = 42 AND tt.del = 'no'
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
) x
WHERE x.name_says IS NOT NULL
  AND x.name_says <> x.attached_discipline
  AND NOT (x.attached_discipline = 'Laser Run' AND x.name_says = 'Shooting')
GROUP BY x.template_name, x.event_name, x.attached_discipline, x.name_says

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT CONCAT(y.template_name, '|', y.event_name, '|', y.attached_discipline)) AS eligible_count,
    1 AS sort_order
FROM (
    SELECT tt.name AS template_name, e.name AS event_name, d.name AS attached_discipline,
           CASE
             WHEN LOWER(e.name) LIKE '%laser%run%' THEN 'Laser Run'
             WHEN LOWER(e.name) LIKE '%obstacle%'  THEN 'Obstacle'
             WHEN LOWER(e.name) LIKE '%fencing%'   THEN 'Fencing'
             WHEN LOWER(e.name) LIKE '%swimming%'  THEN 'Swimming'
             WHEN LOWER(e.name) LIKE '%riding%'    THEN 'Riding'
             WHEN LOWER(e.name) LIKE '%shooting%'  THEN 'Shooting'
             WHEN LOWER(e.name) LIKE '%running%'   THEN 'Running'
             WHEN LOWER(e.name) LIKE '%overall%'   THEN 'Overall'
             ELSE NULL
           END AS name_says
    FROM tournament_template tt
    JOIN tournament t ON t.tournament_templateFK = tt.id AND t.del = 'no'
    JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
    JOIN event e ON e.tournament_stageFK = ts.id AND e.del = 'no'
    JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
    JOIN discipline d ON d.id = od.disciplineFK
    WHERE tt.sportFK = 42 AND tt.del = 'no'
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
) y
WHERE y.name_says IS NOT NULL

ORDER BY sort_order, event_count DESC;
