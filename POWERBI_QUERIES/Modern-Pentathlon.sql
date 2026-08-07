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


-- ======================================================================================

SELECT
    -- CheckID - Modern-Pentathlon-DQ-093
    -- Name - EVENT_RESULTS_OVERALL_NOT_SUM_OF_SEGMENTS
    -- What it does: Finds competitors whose Overall score does not equal the sum of their own segment scores in the same phase, separating a segment carrying the whole total from a sum that runs over or under it.
    CASE
        WHEN pa.max_segment = pa.overall_points THEN 'A_SEGMENT_EQUALS_THE_OVERALL'
        WHEN pa.segment_sum > pa.overall_points THEN 'SUM_EXCEEDS_OVERALL'
        ELSE 'SUM_BELOW_OVERALL'
    END AS check_type,
    pa.participant_id,
    pa.participant_name,
    pa.stage_name,
    pa.template_name,
    CASE WHEN pa.prefix = '' THEN pa.phase ELSE CONCAT(pa.prefix, ' / ', pa.phase) END AS phase_group,
    pa.event_year,
    pa.athlete_segments AS segments_scored,
    pa.segment_sum,
    pa.overall_points,
    pa.segment_sum - pa.overall_points AS difference,
    NULL AS eligible_count,
    0 AS sort_order
-- A pentathlon Overall score is the sum of the scores of the disciplines that make it up, and
-- this sport stores each of them as its own event. The two are therefore two records of one
-- arithmetic, and nothing else in the package reads one against the other.
-- The phase group is the unit the arithmetic closes over. It is keyed on the event name prefix
-- and the round type together, because neither alone identifies it: `Qualification A` and
-- `Qualification B` are both round 179 in one stage and only the prefix separates them, while
-- the Final carries no prefix at all and is identified by rounds 38 to 42 with 173.
-- An `After Fencing` event holds that discipline's score and not a running total, verified on
-- competitors across all three phases of a championship, so the segments are summed rather
-- than differenced.
-- Only a competitor holding a score in every segment event of their own group is asserted. One
-- who missed a discipline would otherwise be reported for an arithmetic that was never
-- possible, and why a segment is missing is a different question from whether the sum is right.
-- Read from 2009 onward, the season the combined running and shooting discipline replaced the
-- separate two. Before it the stored segments do not account for the Overall in roughly seven
-- groups in ten, and tracing one 2007 competitor shows the group itself is short a discipline
-- event rather than the arithmetic being wrong - a format this package has not modelled.
-- SPORTS/Modern-Pentathlon.md records that as an open question rather than reporting it here,
-- where six thousand rows would say one thing about data seventeen years old.
-- Exact equality, no tolerance. Pentathlon points are whole numbers and the matching groups
-- agree to the point, so a tolerance would only hide the two- and four-point contradictions.
FROM (
    SELECT ev.stage_id, ev.stage_name, ev.template_name, ev.prefix, ev.phase,
           ep.participantFK AS participant_id, p.name AS participant_name,
           MIN(ev.event_year) AS event_year,
           SUM(CASE WHEN ev.kind = 'segment' THEN CAST(r.value AS SIGNED) END) AS segment_sum,
           MAX(CASE WHEN ev.kind = 'segment' THEN CAST(r.value AS SIGNED) END) AS max_segment,
           MAX(CASE WHEN ev.kind = 'overall' THEN CAST(r.value AS SIGNED) END) AS overall_points,
           COUNT(DISTINCT CASE WHEN ev.kind = 'segment' THEN ev.event_id END) AS athlete_segments,
           COUNT(DISTINCT CASE WHEN ev.kind = 'overall' THEN ev.event_id END) AS overall_events
    FROM (
        SELECT ts.id AS stage_id, ts.name AS stage_name, tt.name AS template_name,
               e.id AS event_id, YEAR(e.startdate) AS event_year,
               CASE WHEN LOCATE(' - ', e.name) > 0 THEN TRIM(SUBSTRING_INDEX(e.name, ' - ', 1)) ELSE '' END AS prefix,
               CASE WHEN e.round_typeFK IN (179,152) THEN 'Qualifier'
                    WHEN e.round_typeFK IN (2,178)   THEN 'Semi Finals'
                    WHEN e.round_typeFK IN (38,39,40,41,42,173) THEN 'Final'
                    ELSE CONCAT('Round ', e.round_typeFK) END AS phase,
               CASE WHEN LOWER(e.name) LIKE '%overall%' THEN 'overall' ELSE 'segment' END AS kind
        FROM tournament_template tt
        JOIN tournament t ON t.tournament_templateFK = tt.id AND t.del = 'no'
        JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
        JOIN event e ON e.tournament_stageFK = ts.id AND e.del = 'no'
        WHERE tt.sportFK = 42 AND tt.del = 'no'
          AND YEAR(e.startdate) >= 2009
          -- AND t.tournament_templateFK = <tournament_template_id>
          -- AND e.startdate >= '<from_datetime>'
          -- AND e.startdate <  '<to_datetime>'
    ) ev
    JOIN event_participants ep ON ep.eventFK = ev.event_id AND ep.del = 'no'
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
    JOIN result r ON r.event_participantsFK = ep.id AND r.result_typeFK = 102 AND r.del = 'no'
         AND r.value REGEXP '^[0-9]+$'
    GROUP BY ev.stage_id, ev.stage_name, ev.template_name, ev.prefix, ev.phase, ep.participantFK, p.name
    HAVING overall_events = 1 AND segment_sum IS NOT NULL AND overall_points IS NOT NULL
) pa
JOIN (
    SELECT ev2.stage_id, ev2.prefix, ev2.phase, COUNT(DISTINCT ev2.event_id) AS group_segments
    FROM (
        SELECT ts.id AS stage_id, e.id AS event_id,
               CASE WHEN LOCATE(' - ', e.name) > 0 THEN TRIM(SUBSTRING_INDEX(e.name, ' - ', 1)) ELSE '' END AS prefix,
               CASE WHEN e.round_typeFK IN (179,152) THEN 'Qualifier'
                    WHEN e.round_typeFK IN (2,178)   THEN 'Semi Finals'
                    WHEN e.round_typeFK IN (38,39,40,41,42,173) THEN 'Final'
                    ELSE CONCAT('Round ', e.round_typeFK) END AS phase,
               CASE WHEN LOWER(e.name) LIKE '%overall%' THEN 'overall' ELSE 'segment' END AS kind
        FROM tournament_template tt
        JOIN tournament t ON t.tournament_templateFK = tt.id AND t.del = 'no'
        JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
        JOIN event e ON e.tournament_stageFK = ts.id AND e.del = 'no'
        WHERE tt.sportFK = 42 AND tt.del = 'no'
          AND YEAR(e.startdate) >= 2009
          -- AND t.tournament_templateFK = <tournament_template_id>
          -- AND e.startdate >= '<from_datetime>'
          -- AND e.startdate <  '<to_datetime>'
    ) ev2
    WHERE ev2.kind = 'segment'
    GROUP BY ev2.stage_id, ev2.prefix, ev2.phase
) gs ON gs.stage_id = pa.stage_id AND gs.prefix = pa.prefix AND gs.phase = pa.phase
WHERE pa.athlete_segments = gs.group_segments
  AND pa.segment_sum <> pa.overall_points

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(*) AS eligible_count,
    1 AS sort_order
FROM (
    SELECT ev.stage_id, ev.prefix, ev.phase, ep.participantFK AS participant_id,
           SUM(CASE WHEN ev.kind = 'segment' THEN CAST(r.value AS SIGNED) END) AS segment_sum,
           MAX(CASE WHEN ev.kind = 'overall' THEN CAST(r.value AS SIGNED) END) AS overall_points,
           COUNT(DISTINCT CASE WHEN ev.kind = 'segment' THEN ev.event_id END) AS athlete_segments,
           COUNT(DISTINCT CASE WHEN ev.kind = 'overall' THEN ev.event_id END) AS overall_events
    FROM (
        SELECT ts.id AS stage_id, e.id AS event_id,
               CASE WHEN LOCATE(' - ', e.name) > 0 THEN TRIM(SUBSTRING_INDEX(e.name, ' - ', 1)) ELSE '' END AS prefix,
               CASE WHEN e.round_typeFK IN (179,152) THEN 'Qualifier'
                    WHEN e.round_typeFK IN (2,178)   THEN 'Semi Finals'
                    WHEN e.round_typeFK IN (38,39,40,41,42,173) THEN 'Final'
                    ELSE CONCAT('Round ', e.round_typeFK) END AS phase,
               CASE WHEN LOWER(e.name) LIKE '%overall%' THEN 'overall' ELSE 'segment' END AS kind
        FROM tournament_template tt
        JOIN tournament t ON t.tournament_templateFK = tt.id AND t.del = 'no'
        JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
        JOIN event e ON e.tournament_stageFK = ts.id AND e.del = 'no'
        WHERE tt.sportFK = 42 AND tt.del = 'no'
          AND YEAR(e.startdate) >= 2009
          -- AND t.tournament_templateFK = <tournament_template_id>
          -- AND e.startdate >= '<from_datetime>'
          -- AND e.startdate <  '<to_datetime>'
    ) ev
    JOIN event_participants ep ON ep.eventFK = ev.event_id AND ep.del = 'no'
    JOIN result r ON r.event_participantsFK = ep.id AND r.result_typeFK = 102 AND r.del = 'no'
         AND r.value REGEXP '^[0-9]+$'
    GROUP BY ev.stage_id, ev.prefix, ev.phase, ep.participantFK
    HAVING overall_events = 1 AND segment_sum IS NOT NULL AND overall_points IS NOT NULL
) cpa
JOIN (
    SELECT ev3.stage_id, ev3.prefix, ev3.phase, COUNT(DISTINCT ev3.event_id) AS group_segments
    FROM (
        SELECT ts.id AS stage_id, e.id AS event_id,
               CASE WHEN LOCATE(' - ', e.name) > 0 THEN TRIM(SUBSTRING_INDEX(e.name, ' - ', 1)) ELSE '' END AS prefix,
               CASE WHEN e.round_typeFK IN (179,152) THEN 'Qualifier'
                    WHEN e.round_typeFK IN (2,178)   THEN 'Semi Finals'
                    WHEN e.round_typeFK IN (38,39,40,41,42,173) THEN 'Final'
                    ELSE CONCAT('Round ', e.round_typeFK) END AS phase,
               CASE WHEN LOWER(e.name) LIKE '%overall%' THEN 'overall' ELSE 'segment' END AS kind
        FROM tournament_template tt
        JOIN tournament t ON t.tournament_templateFK = tt.id AND t.del = 'no'
        JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
        JOIN event e ON e.tournament_stageFK = ts.id AND e.del = 'no'
        WHERE tt.sportFK = 42 AND tt.del = 'no'
          AND YEAR(e.startdate) >= 2009
          -- AND t.tournament_templateFK = <tournament_template_id>
          -- AND e.startdate >= '<from_datetime>'
          -- AND e.startdate <  '<to_datetime>'
    ) ev3
    WHERE ev3.kind = 'segment'
    GROUP BY ev3.stage_id, ev3.prefix, ev3.phase
) cgs ON cgs.stage_id = cpa.stage_id AND cgs.prefix = cpa.prefix AND cgs.phase = cpa.phase
WHERE cpa.athlete_segments = cgs.group_segments

ORDER BY sort_order, difference DESC;
