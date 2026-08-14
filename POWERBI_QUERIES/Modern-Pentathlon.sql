SELECT
    -- CheckID - Modern-Pentathlon-DQ-092
    -- Name - EVENT_SETTINGS_DISCIPLINE_CONTRADICTS_EVENT_NAME
    -- What it does: Flags template events where the discipline in the event name differs from the object_discipline relation.
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
-- What it does, stated in full: Finds template events whose name says one discipline while
-- the object_discipline relation says another, one row per template and event name rather
-- than per event.
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
    -- What it does: Flags competitors whose Overall score does not equal the sum of their segment scores in the same phase.
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
-- What it does, stated in full: Finds competitors whose Overall score does not equal the sum
-- of their own segment scores in the same phase, separating a segment carrying the whole
-- total from a sum that runs over or under it.
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

-- ======================================================================================

SELECT
    -- CheckID - Modern-Pentathlon-DQ-094
    -- Name - EVENT_RESULTS_RANK_ORDER_CONTRADICTS_POINTS
    -- What it does: Flags events where a better-ranked competitor has fewer Points than a lower-ranked competitor.
    CASE
        WHEN g.contradicting_participants * 2 >= g.field_size THEN 'RANKING_CONTRADICTS_POINTS_THROUGHOUT'
        ELSE 'RANKING_CONTRADICTS_POINTS_IN_PLACES'
    END AS check_type,
    g.event_id,
    g.event_name,
    g.stage_name,
    g.template_name,
    g.event_year,
    g.stage_gender,
    g.field_size,
    g.contradicting_participants,
    g.largest_contradicted_gap,
    g.worst_example,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds events where a competitor placed ahead of another
-- scored fewer points than them, one row per event with the size of the contradiction and
-- its worst example.
-- Pentathlon places competitors by the points they scored, so within one event the ranking and
-- the score are two records of one ordering and each is a check on the other. Nothing else in
-- the package reads them against each other.
-- Where the data is coherent the agreement is exact, not approximate: a 2013 Fencing final runs
-- rank 1 to 1040 points, 2 to 1020, 3 to 960 and on down to 40 to 700 without a single
-- inversion, while the Swimming final of the same stage puts rank 3 above rank 1 by four
-- hundred points. That contrast is why this is a strict ordinal rule with no tolerance. A
-- threshold would need a number that ages with every change to the scoring scale, and the scale
-- has changed more than once inside the period the sport is stored for.
-- Ties are left alone. The rule fires only where one competitor is strictly ahead AND strictly
-- lower scoring, so equal points sharing a rank, or a tie broken by a rule outside the points,
-- is never reported.
-- Reported per event rather than per competitor, because the count is what tells the reviewer
-- which defect they have. Half the field or more contradicted means the ranking as a whole does
-- not follow the points and one of the two orderings has to be replaced; a handful means
-- individual rows are misplaced. The repairs differ, so the verdicts differ.
-- The largest contradicted gap travels as a column rather than as a threshold, so a review can
-- sort by severity without the check itself deciding what counts as severe.
-- A score of zero is kept in scope but pushed to the back of the example. Zero is how a missing
-- score is written here, so it wins the widest gap in almost any event it appears in and would
-- otherwise be the only thing a reviewer ever sees. It is left in because removing it changes
-- 83 contradicted competitors out of 7677 and nine events out of 750, which is not enough to
-- narrow a rule over, and a competitor placed ahead on no score at all is still misplaced.
-- Read across all years. Unlike Modern-Pentathlon-DQ-093 this asserts nothing about how the
-- disciplines add up, so the 2009 change of format does not bear on it.
-- What the ranking means in a contradicted event is not settled. Two readings were tested
-- against the database and both fail: the rank is not the competitor's Overall placing copied
-- onto the segment, and the points are not a running total. SPORTS/Modern-Pentathlon.md records
-- that as an open question, so a reviewer knows the row says the two disagree and does not say
-- which of them is wrong.
FROM (
    SELECT a.event_id,
           MIN(a.event_name)    AS event_name,
           MIN(a.stage_name)    AS stage_name,
           MIN(a.template_name) AS template_name,
           MIN(a.event_year)    AS event_year,
           MIN(a.stage_gender)  AS stage_gender,
           COUNT(DISTINCT a.participant_id) AS field_size,
           COUNT(DISTINCT CASE WHEN b.participant_id IS NOT NULL THEN a.participant_id END) AS contradicting_participants,
           MAX(b.points_value - a.points_value) AS largest_contradicted_gap,
           SUBSTRING_INDEX(GROUP_CONCAT(
               CONCAT(a.participant_name, ' rank ', a.rank_value, ' with ', a.points_value,
                      ' behind ', b.participant_name, ' rank ', b.rank_value, ' with ', b.points_value)
               ORDER BY (a.points_value = 0), (b.points_value - a.points_value) DESC SEPARATOR ' || '), ' || ', 1) AS worst_example
    FROM (
        SELECT ts.name AS stage_name, ts.gender AS stage_gender, tt.name AS template_name,
               e.id AS event_id, e.name AS event_name, YEAR(e.startdate) AS event_year,
               ep.participantFK AS participant_id, p.name AS participant_name,
               CAST(rr.value AS SIGNED) AS rank_value,
               CAST(rs.value AS SIGNED) AS points_value
        FROM tournament_template tt
        JOIN tournament t ON t.tournament_templateFK = tt.id AND t.del = 'no'
        JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
        JOIN event e ON e.tournament_stageFK = ts.id AND e.del = 'no'
        JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
        JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
        JOIN result rr ON rr.event_participantsFK = ep.id AND rr.result_typeFK = 100 AND rr.del = 'no'
             AND rr.value REGEXP '^[0-9]+$'
        JOIN result rs ON rs.event_participantsFK = ep.id AND rs.result_typeFK = 102 AND rs.del = 'no'
             AND rs.value REGEXP '^[0-9]+$'
        WHERE tt.sportFK = 42 AND tt.del = 'no'
          -- AND t.tournament_templateFK = <tournament_template_id>
          -- AND e.startdate >= '<from_datetime>'
          -- AND e.startdate <  '<to_datetime>'
    ) a
    LEFT JOIN (
        SELECT e.id AS event_id, ep.participantFK AS participant_id, p.name AS participant_name,
               CAST(rr.value AS SIGNED) AS rank_value,
               CAST(rs.value AS SIGNED) AS points_value
        FROM tournament_template tt
        JOIN tournament t ON t.tournament_templateFK = tt.id AND t.del = 'no'
        JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
        JOIN event e ON e.tournament_stageFK = ts.id AND e.del = 'no'
        JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
        JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
        JOIN result rr ON rr.event_participantsFK = ep.id AND rr.result_typeFK = 100 AND rr.del = 'no'
             AND rr.value REGEXP '^[0-9]+$'
        JOIN result rs ON rs.event_participantsFK = ep.id AND rs.result_typeFK = 102 AND rs.del = 'no'
             AND rs.value REGEXP '^[0-9]+$'
        WHERE tt.sportFK = 42 AND tt.del = 'no'
          -- AND t.tournament_templateFK = <tournament_template_id>
          -- AND e.startdate >= '<from_datetime>'
          -- AND e.startdate <  '<to_datetime>'
    ) b ON b.event_id = a.event_id
       AND b.rank_value   > a.rank_value
       AND b.points_value > a.points_value
    GROUP BY a.event_id
    HAVING contradicting_participants > 0
) g

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(*) AS eligible_count,
    1 AS sort_order
FROM (
    SELECT e.id AS event_id
    FROM tournament_template tt
    JOIN tournament t ON t.tournament_templateFK = tt.id AND t.del = 'no'
    JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
    JOIN event e ON e.tournament_stageFK = ts.id AND e.del = 'no'
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    JOIN result rr ON rr.event_participantsFK = ep.id AND rr.result_typeFK = 100 AND rr.del = 'no'
         AND rr.value REGEXP '^[0-9]+$'
    JOIN result rs ON rs.event_participantsFK = ep.id AND rs.result_typeFK = 102 AND rs.del = 'no'
         AND rs.value REGEXP '^[0-9]+$'
    WHERE tt.sportFK = 42 AND tt.del = 'no'
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY e.id
    HAVING COUNT(DISTINCT ep.participantFK) >= 2
) c

ORDER BY sort_order, contradicting_participants DESC;

-- ======================================================================================

SELECT
    -- CheckID - Modern-Pentathlon-DQ-095
    -- Name - EVENT_NAME_MIXED_CONTRADICTS_STAGE_GENDER
    -- What it does: Flags events named as mixed when their stage has one gender or no gender.
    CASE
        WHEN ts.gender IS NULL OR TRIM(ts.gender) = '' THEN 'MIXED_NAME_ON_STAGE_WITHOUT_GENDER'
        ELSE 'MIXED_NAME_CONTRADICTED_BY_STAGE_GENDER'
    END AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    ts.name AS stage_name,
    ts.gender AS stage_gender,
    tt.name AS template_name,
    YEAR(e.startdate) AS event_year,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds events whose name says the format is mixed while the
-- stage holding them is recorded as a single gender or carries no gender at all.
-- The event name and the stage gender are two records of one fact wherever the name names the
-- format. This sport says it exactly one way - the relay events carry Mix in their name - and
-- nothing else in the package reads a name against a gender. GLOBAL-DQ-014 compares the stage
-- with its template, GLOBAL-DQ-043 compares the participants with the stage, and neither looks
-- at what the event calls itself.
-- Returns nothing today: all 663 events naming the mixed format sit on a mixed stage. That is a
-- sentinel over a populated scope and not an empty one, so the eligible count says 663 rather
-- than zero, and the day a mixed relay is filed under a single-gender stage the check is already
-- in place. POWERBI.md owns that distinction.
-- The missing gender is a separate verdict from the contradicting one because they are repaired
-- differently: one stage has the wrong value, the other has none. The column is nullable, so the
-- branch is structural even though no row reaches it now.
FROM tournament_template tt
JOIN tournament t ON t.tournament_templateFK = tt.id AND t.del = 'no'
JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
JOIN event e ON e.tournament_stageFK = ts.id AND e.del = 'no'
WHERE tt.sportFK = 42 AND tt.del = 'no'
  AND LOWER(e.name) LIKE '%mix%'
  AND (ts.gender IS NULL OR TRIM(ts.gender) = '' OR LOWER(TRIM(ts.gender)) <> 'mixed')
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM tournament_template tt
JOIN tournament t ON t.tournament_templateFK = tt.id AND t.del = 'no'
JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
JOIN event e ON e.tournament_stageFK = ts.id AND e.del = 'no'
WHERE tt.sportFK = 42 AND tt.del = 'no'
  AND LOWER(e.name) LIKE '%mix%'
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_year, event_id;

-- ======================================================================================

SELECT
    -- CheckID - Modern-Pentathlon-DQ-096
    -- Name - EVENT_RESULTS_ZERO_SCORE_WITHOUT_STATUS
    -- What it does: Flags competitors with a zero score and no Comment explaining it, whether it affects one, several, or all competitors.
    CASE
        WHEN g.zero_scored_participants * 2 >= g.field_size THEN 'ZERO_SCORE_ACROSS_THE_FIELD'
        WHEN g.zero_scored_participants > 1                 THEN 'ZERO_SCORE_FOR_SEVERAL'
        ELSE 'ZERO_SCORE_FOR_ONE'
    END AS check_type,
    g.event_id,
    g.event_name,
    g.stage_name,
    g.template_name,
    g.event_year,
    g.field_size,
    g.zero_scored_participants,
    g.examples,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds events holding competitors scored zero with no comment
-- to say why, separating a whole field scored zero from a few competitors and from one.
-- Zero is how a missing score is written in this sport, and nothing separates it from a score
-- that really was zero except the comment beside it. A competitor scored zero and carrying any
-- comment at all is therefore left alone here: the state is recorded, whatever it says.
-- Deliberately counts rather than judging by discipline. The obvious rule - fencing and swimming
-- cannot reach zero - does not survive contact with the sport: under the pre-2022 fencing scale
-- a competitor winning no bouts in a field of seventy-five reaches zero and below arithmetically,
-- so a per-discipline exemption would be a guess dressed as a fact. The count needs no such
-- claim. A 2007 Fencing final scored zero on fifty-eight competitors out of fifty-eight is not a
-- competition result under any scale that has ever been used.
-- Three verdicts because they are three defects. A whole field is an event whose scores were
-- never imported and is repaired in one move. A few competitors is a gap in an event that
-- otherwise loaded. One competitor is where the legitimate zero lives - a rider eliminated on
-- the show-jumping course scores zero by the rules - so it is kept separate rather than mixed
-- into the same verdict as the other two, and it is the verdict a review can set aside first.
-- The field size travels with the row so the proportion stays readable, and the competitors
-- travel with it so the reviewer does not have to open the event to see who is affected.
FROM (
    SELECT z.event_id,
           MIN(z.event_name)    AS event_name,
           MIN(z.stage_name)    AS stage_name,
           MIN(z.template_name) AS template_name,
           MIN(z.event_year)    AS event_year,
           COUNT(DISTINCT z.participant_id) AS field_size,
           COUNT(DISTINCT CASE WHEN z.scored_zero = 1 AND z.has_comment = 0 THEN z.participant_id END) AS zero_scored_participants,
           SUBSTRING(GROUP_CONCAT(CASE WHEN z.scored_zero = 1 AND z.has_comment = 0 THEN z.participant_name END
                     ORDER BY z.participant_name SEPARATOR ', '), 1, 150) AS examples
    FROM (
        SELECT ts.name AS stage_name, tt.name AS template_name,
               e.id AS event_id, e.name AS event_name, YEAR(e.startdate) AS event_year,
               ep.participantFK AS participant_id, p.name AS participant_name,
               MAX(CASE WHEN TRIM(rs.value) = '0' THEN 1 ELSE 0 END) AS scored_zero,
               MAX(CASE WHEN rc.id IS NOT NULL AND TRIM(rc.value) <> '' THEN 1 ELSE 0 END) AS has_comment
        FROM tournament_template tt
        JOIN tournament t ON t.tournament_templateFK = tt.id AND t.del = 'no'
        JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
        JOIN event e ON e.tournament_stageFK = ts.id AND e.del = 'no'
        JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
        JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
        JOIN result rs ON rs.event_participantsFK = ep.id AND rs.result_typeFK = 102 AND rs.del = 'no'
        LEFT JOIN result rc ON rc.event_participantsFK = ep.id AND rc.result_typeFK = 104 AND rc.del = 'no'
        WHERE tt.sportFK = 42 AND tt.del = 'no'
          -- AND t.tournament_templateFK = <tournament_template_id>
          -- AND e.startdate >= '<from_datetime>'
          -- AND e.startdate <  '<to_datetime>'
        GROUP BY e.id, ep.participantFK
    ) z
    GROUP BY z.event_id
    HAVING zero_scored_participants > 0
) g

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM tournament_template tt
JOIN tournament t ON t.tournament_templateFK = tt.id AND t.del = 'no'
JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
JOIN event e ON e.tournament_stageFK = ts.id AND e.del = 'no'
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
JOIN result rs ON rs.event_participantsFK = ep.id AND rs.result_typeFK = 102 AND rs.del = 'no'
WHERE tt.sportFK = 42 AND tt.del = 'no'
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, zero_scored_participants DESC;

-- ======================================================================================

SELECT
    -- CheckID - Modern-Pentathlon-DQ-097
    -- Name - EVENT_RESULTS_SEGMENT_SCORE_MISSING_WITHOUT_STATUS
    -- What it does: Flags competitors missing a score in one or more discipline events of their phase when no Comment explains it.
    CASE
        WHEN (gs.group_segments - pa.segments_scored) * 2 > gs.group_segments THEN 'MOST_SEGMENTS_MISSING_WITHOUT_STATUS'
        ELSE 'SEGMENT_MISSING_WITHOUT_STATUS'
    END AS check_type,
    pa.participant_id,
    pa.participant_name,
    pa.stage_name,
    pa.template_name,
    CASE WHEN pa.prefix = '' THEN pa.phase ELSE CONCAT(pa.prefix, ' / ', pa.phase) END AS phase_group,
    pa.event_year,
    gs.group_segments,
    pa.segments_scored,
    gs.group_segments - pa.segments_scored AS segments_missing,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds competitors holding no score in one or more discipline
-- events of their own phase with no comment anywhere in that phase to say why, separating
-- most of the phase missing from part of it.
-- A competitor entered in a phase is entered in its disciplines, so a discipline holding no score
-- for them is either a withdrawal or a gap. The database can tell the two apart, because a
-- withdrawal is written as a comment - DNS, DNF, DSQ - and this reads exactly that: the score is
-- absent and nothing in the phase says why.
-- The defect is therefore the missing status and not the missing score. A competitor who pulled
-- out after the fencing legitimately has no swim time, and the row that should exist is the one
-- recording that they pulled out. Repairing the status is what closes this, not inventing a
-- score.
-- The comment is read across the whole phase rather than the one event, because a withdrawal is
-- recorded once and explains every discipline after it. Requiring it on each missing event would
-- report the same competitor several times for one already-recorded fact.
-- Two verdicts. More than half the phase missing is a competitor who barely appears in it and is
-- very likely an entry that was never withdrawn; part of the phase is a narrower gap. Both are
-- reported because both leave the sport unable to say why a discipline is blank.
-- Reported per competitor and phase, the same unit Modern-Pentathlon-DQ-093 uses, so the two read
-- together: 093 asserts the arithmetic only where every segment is present, and this is what it
-- steps over.
-- Read from 2009 onward for the reason 093 records: before that season the stored phases are
-- short an entire discipline event, so every competitor in them would be reported for a format
-- this package has not modelled rather than for a missing status.
-- Groups of a single segment are out of scope. One discipline standing alone carries no
-- expectation that a competitor appears in another, so there is nothing to be missing from.
FROM (
    SELECT ev.stage_id, ev.stage_name, ev.template_name, ev.prefix, ev.phase,
           ep.participantFK AS participant_id, p.name AS participant_name,
           MIN(ev.event_year) AS event_year,
           COUNT(DISTINCT CASE WHEN ev.kind = 'segment' AND rs.id IS NOT NULL THEN ev.event_id END) AS segments_scored,
           MAX(CASE WHEN LOWER(TRIM(rc.value)) IN ('dns', 'dns.', 'dnf', 'dsq', 'disq.', 'n/a') THEN 1 ELSE 0 END) AS has_no_result_status
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
    LEFT JOIN result rs ON rs.event_participantsFK = ep.id AND rs.result_typeFK = 102 AND rs.del = 'no'
         AND rs.value REGEXP '^[0-9]+$'
    LEFT JOIN result rc ON rc.event_participantsFK = ep.id AND rc.result_typeFK = 104 AND rc.del = 'no'
    GROUP BY ev.stage_id, ev.prefix, ev.phase, ep.participantFK
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
    HAVING group_segments >= 2
) gs ON gs.stage_id = pa.stage_id AND gs.prefix = pa.prefix AND gs.phase = pa.phase
WHERE pa.segments_scored < gs.group_segments
  AND pa.has_no_result_status = 0

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(*) AS eligible_count,
    1 AS sort_order
FROM (
    SELECT ev.stage_id, ev.prefix, ev.phase, ep.participantFK AS participant_id
    FROM (
        SELECT ts.id AS stage_id, e.id AS event_id,
               CASE WHEN LOCATE(' - ', e.name) > 0 THEN TRIM(SUBSTRING_INDEX(e.name, ' - ', 1)) ELSE '' END AS prefix,
               CASE WHEN e.round_typeFK IN (179,152) THEN 'Qualifier'
                    WHEN e.round_typeFK IN (2,178)   THEN 'Semi Finals'
                    WHEN e.round_typeFK IN (38,39,40,41,42,173) THEN 'Final'
                    ELSE CONCAT('Round ', e.round_typeFK) END AS phase
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
    GROUP BY ev.stage_id, ev.prefix, ev.phase, ep.participantFK
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
    HAVING group_segments >= 2
) cgs ON cgs.stage_id = cpa.stage_id AND cgs.prefix = cpa.prefix AND cgs.phase = cpa.phase

ORDER BY sort_order, segments_missing DESC, event_year DESC;
