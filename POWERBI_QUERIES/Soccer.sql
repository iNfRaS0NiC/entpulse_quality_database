SELECT
    -- CheckID - Soccer-DQ-022
    -- Name - EVENT_RESULTS_SCORE_TIED_ON_KNOCKOUT_SINGLE_MATCH
    -- What it does: Finds finished knockout events whose two participants hold an identical deciding score, so a round that must produce a winner produced none, excluding a leg of a tie decided on aggregate.
    'TIED_SCORE_ON_KNOCKOUT_SINGLE_MATCH' AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    tt.name AS template_name,
    t.name AS tournament_name,
    ts.name AS stage_name,
    rt.name AS round_type_name,
    x.tied_score,
    NULL AS eligible_count,
    0 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
-- round_type.knockout is the discriminator DB-SEM-012 records, and it is what makes this
-- statement possible at all: a group match may legitimately end level, so the rule cannot be
-- asserted for the sport as a whole. It is read from the id the event carries rather than from
-- the round name, because one name exists as both a knockout and a non-knockout row.
JOIN round_type rt ON rt.id = e.round_typeFK AND rt.knockout = 'yes'
-- The deciding score already contains the shootout: Soccer stores 4 Final Result as the sum of
-- ordinary time, extra time and the penalty shootout, so a knockout tie here is not a match
-- still waiting to be decided but one whose stored figures decide nothing.
JOIN (
    SELECT
        ep.eventFK AS event_id,
        COUNT(*) AS score_count,
        COUNT(DISTINCT TRIM(r.value)) AS distinct_scores,
        MIN(TRIM(r.value)) AS tied_score
    FROM event_participants ep
    JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
                 AND r.result_typeFK = 4
                 AND r.value IS NOT NULL
                 AND TRIM(r.value) <> ''
    JOIN event e2 ON e2.id = ep.eventFK AND e2.del = 'no'
    JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
    JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
    JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
    WHERE ep.del = 'no'
      AND tt2.sportFK = 1
      -- AND t2.tournament_templateFK = <tournament_template_id>
    GROUP BY ep.eventFK
) x ON x.event_id = e.id AND x.score_count = 2 AND x.distinct_scores = 1
WHERE e.del = 'no'
  AND e.status_type = 'finished'
  AND tt.sportFK = 1
  -- A leg of a tie decided on aggregate is excluded rather than judged. Such a leg is played
  -- inside a knockout round and may end level by design, because the winner is read from the
  -- two legs together and not from either of them; the BestOf property is what marks one.
  AND NOT EXISTS (
      SELECT 1
      FROM property pr
      WHERE pr.object = 'event'
        AND pr.objectFK = e.id
        AND pr.name = 'BestOf'
        AND pr.del = 'no'
  )
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

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
JOIN round_type rt ON rt.id = e.round_typeFK AND rt.knockout = 'yes'
JOIN (
    SELECT
        ep.eventFK AS event_id,
        COUNT(*) AS score_count
    FROM event_participants ep
    JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
                 AND r.result_typeFK = 4
                 AND r.value IS NOT NULL
                 AND TRIM(r.value) <> ''
    JOIN event e2 ON e2.id = ep.eventFK AND e2.del = 'no'
    JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
    JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
    JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
    WHERE ep.del = 'no'
      AND tt2.sportFK = 1
      -- AND t2.tournament_templateFK = <tournament_template_id>
    GROUP BY ep.eventFK
) x ON x.event_id = e.id AND x.score_count = 2
WHERE e.del = 'no'
  AND e.status_type = 'finished'
  AND tt.sportFK = 1
  AND NOT EXISTS (
      SELECT 1
      FROM property pr
      WHERE pr.object = 'event'
        AND pr.objectFK = e.id
        AND pr.name = 'BestOf'
        AND pr.del = 'no'
  )
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_startdate DESC;


-- ================================================================================
SELECT
    -- CheckID - Soccer-DQ-081
    -- Name - EVENT_STATUS_CONTRADICTS_SCORE_STAGES
    -- What it does: Finds finished matches whose detailed status disagrees with the score stages stored for them - a shootout or extra time the status does not name, or a status naming one that carries no score.
    CASE
        WHEN x.shootout_stored = 1 AND x.status_desc_id <> 13
            THEN 'Shootout_Without_Penalties_Status'
        WHEN x.extra_time_stored = 1 AND x.status_desc_id NOT IN (11, 13, 16, 24)
            THEN 'Extra_Time_Without_A_Status_Naming_One'
        WHEN x.status_desc_id = 13 AND x.shootout_stored = 0
            THEN 'Penalties_Status_Without_Shootout'
        ELSE 'Extra_Time_Status_Without_Extra_Time'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.status_desc_id,
    x.status_desc_name,
    x.template_name,
    x.tournament_name,
    x.stage_name,
    x.extra_time_stored,
    x.shootout_stored,
    NULL AS eligible_count,
    0 AS sort_order
-- The status and the stored stages are two independent records of how the match was decided,
-- so one contradicting the other means a reader cannot tell which to believe. Soccer stores
-- extra time and the shootout as result types of their own rather than as scope periods, which
-- is why GLOBAL-DQ-089 - the check that asserts exactly this for other sports - reads a
-- structure this one does not write and cannot be instantiated here.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        e.status_descFK AS status_desc_id,
        sd.name AS status_desc_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        ts.name AS stage_name,
        MAX(CASE WHEN r.result_typeFK = 2 THEN 1 ELSE 0 END) AS extra_time_stored,
        MAX(CASE WHEN r.result_typeFK = 3 THEN 1 ELSE 0 END) AS shootout_stored
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    LEFT JOIN status_desc sd ON sd.id = e.status_descFK
    LEFT JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    LEFT JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
                      AND r.result_typeFK IN (2, 3)
                      AND r.value IS NOT NULL
                      AND TRIM(r.value) <> ''
    WHERE e.del = 'no'
      AND e.status_type = 'finished'
      AND tt.sportFK = 1
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY e.id, e.name, e.startdate, e.status_descFK, sd.name, tt.name, t.name, ts.name
) x
-- Four rules, and the two the sport does not support are as important as the two it does.
-- A shootout belongs to 13 Finished AP alone. Extra time belongs to 11 Finished AET, 24
-- Finished ASG - the silver-goal status, whose one match is the 2004 semi-final - 16 Finished
-- AGG, and 13, since a tie may go to extra time before penalties. But 13 does NOT require
-- extra time: measured across the scope on 2026-08-05, 72 of 317 matches decided on penalties
-- went straight to them from a level ninety minutes, which is the format several competitions
-- use and not a defect. And 190 Finished after awarded win is left out of the two unexpected
-- stage rules, because an awarded result replaces a match that may genuinely have been
-- abandoned in extra time; the stage stored beside it is then the play, not a contradiction.
WHERE (x.shootout_stored = 1 AND x.status_desc_id NOT IN (13, 190))
   OR (x.extra_time_stored = 1 AND x.status_desc_id NOT IN (11, 13, 16, 24, 190))
   OR (x.status_desc_id = 13 AND x.shootout_stored = 0)
   OR (x.status_desc_id IN (11, 24) AND x.extra_time_stored = 0)

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
WHERE e.del = 'no'
  AND e.status_type = 'finished'
  AND tt.sportFK = 1
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_startdate DESC;


-- ================================================================================
SELECT
    -- CheckID - Soccer-DQ-082
    -- Name - EVENT_RESULTS_FINAL_SCORE_NOT_SUM_OF_STAGES
    -- What it does: Finds participants whose Final Result does not equal their ordinary time plus extra time plus penalty shootout, separating a total above the sum of its stages from one below it.
    CASE
        WHEN x.final_score > x.stage_sum THEN 'Final_Above_Sum_Of_Stages'
        ELSE 'Final_Below_Sum_Of_Stages'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.participant_name,
    x.final_score,
    x.stage_sum,
    x.ordinary_time,
    x.extra_time,
    x.shootout,
    x.template_name,
    x.tournament_name,
    NULL AS eligible_count,
    0 AS sort_order
-- The score types are cumulative into 4 Final Result, which is the sum of ordinary time,
-- extra time and the shootout. That is this sport's own storage semantics and no global
-- template knows it, so nothing else in the package would notice the relation breaking. It is
-- the invariant every other score check rests on. 5 Halftime is deliberately not a term: it is
-- a snapshot taken during ordinary time rather than a stage that adds to the total.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        p.name AS participant_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        MAX(CASE WHEN r.result_typeFK = 1 THEN CAST(TRIM(r.value) AS SIGNED) END) AS ordinary_time,
        MAX(CASE WHEN r.result_typeFK = 2 THEN CAST(TRIM(r.value) AS SIGNED) END) AS extra_time,
        MAX(CASE WHEN r.result_typeFK = 3 THEN CAST(TRIM(r.value) AS SIGNED) END) AS shootout,
        MAX(CASE WHEN r.result_typeFK = 4 THEN CAST(TRIM(r.value) AS SIGNED) END) AS final_score,
        COALESCE(MAX(CASE WHEN r.result_typeFK = 1 THEN CAST(TRIM(r.value) AS SIGNED) END), 0)
      + COALESCE(MAX(CASE WHEN r.result_typeFK = 2 THEN CAST(TRIM(r.value) AS SIGNED) END), 0)
      + COALESCE(MAX(CASE WHEN r.result_typeFK = 3 THEN CAST(TRIM(r.value) AS SIGNED) END), 0) AS stage_sum,
        MAX(CASE WHEN TRIM(r.value) NOT REGEXP '^[0-9]+$' THEN 1 ELSE 0 END) AS unreadable_value
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
    JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
                 AND r.result_typeFK IN (1, 2, 3, 4)
                 AND r.value IS NOT NULL
                 AND TRIM(r.value) <> ''
    WHERE e.del = 'no'
      AND e.status_type = 'finished'
      AND tt.sportFK = 1
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY e.id, e.name, e.startdate, ep.id, p.name, tt.name, t.name
) x
-- A participant holding a value that is not a plain non-negative integer in any of the four
-- types is left out rather than summed, in the findings and in the coverage count alike.
-- Reading such a value as zero would report an arithmetic defect where the real one is the
-- value itself, which Soccer-DQ-088 names. A participant with no Final Result has nothing to
-- compare and is outside the population; that gap belongs to GLOBAL-DQ-017 and GLOBAL-DQ-114.
WHERE x.unreadable_value = 0
  AND x.final_score IS NOT NULL
  AND x.final_score <> x.stage_sum

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT c.ep_id) AS eligible_count,
    1 AS sort_order
FROM (
    SELECT
        ep.id AS ep_id,
        MAX(CASE WHEN r.result_typeFK = 4 THEN 1 ELSE 0 END) AS has_final,
        MAX(CASE WHEN TRIM(r.value) NOT REGEXP '^[0-9]+$' THEN 1 ELSE 0 END) AS unreadable_value
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
                 AND r.result_typeFK IN (1, 2, 3, 4)
                 AND r.value IS NOT NULL
                 AND TRIM(r.value) <> ''
    WHERE e.del = 'no'
      AND e.status_type = 'finished'
      AND tt.sportFK = 1
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY ep.id
) c
WHERE c.unreadable_value = 0
  AND c.has_final = 1

ORDER BY sort_order, event_startdate DESC;


-- ================================================================================
SELECT
    -- CheckID - Soccer-DQ-083
    -- Name - EVENT_RESULTS_TIE_OUTCOME_CONTRADICTS_AGGREGATE
    -- What it does: Finds two-legged ties whose stored outcome is not one side won and the other lost, or names a winner holding the lower aggregate score.
    CASE
        WHEN x.home_outcome IS NULL OR x.away_outcome IS NULL
            THEN 'Outcome_Stored_For_One_Side_Only'
        WHEN x.home_outcome NOT IN ('won', 'lost') OR x.away_outcome NOT IN ('won', 'lost')
            THEN 'Outcome_Value_Outside_Won_And_Lost'
        WHEN x.home_outcome = x.away_outcome
            THEN 'Both_Sides_Carry_The_Same_Outcome'
        WHEN x.home_aggregate IS NULL OR x.away_aggregate IS NULL
            THEN 'Outcome_With_No_Aggregate_To_Read_It_Against'
        ELSE 'Winner_Holds_The_Lower_Aggregate'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.home_outcome,
    x.away_outcome,
    x.home_aggregate,
    x.away_aggregate,
    x.template_name,
    x.tournament_name,
    NULL AS eligible_count,
    0 AS sort_order
-- 549 Final Outcome is a field of the two-legged tie rather than of the match under it: every
-- event carrying one carries 550 Overall Score, the BestOf property and a 351 aggregate scope
-- container beside it. So it must be read against the aggregate and never against the leg's own
-- 4 Final Result, where a third of these rows look wrong and are not - the side marked won
-- routinely lost the leg its row sits on. An aggregate that is level is left alone rather than
-- judged: the tie was then settled by away goals or by a shootout, and neither is stored here.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        tt.name AS template_name,
        t.name AS tournament_name,
        MAX(CASE WHEN ep.number = 1 THEN LOWER(TRIM(ro.value)) END) AS home_outcome,
        MAX(CASE WHEN ep.number = 2 THEN LOWER(TRIM(ro.value)) END) AS away_outcome,
        MAX(CASE WHEN ep.number = 1 AND TRIM(ra.value) REGEXP '^[0-9]+$'
                 THEN CAST(TRIM(ra.value) AS SIGNED) END) AS home_aggregate,
        MAX(CASE WHEN ep.number = 2 AND TRIM(ra.value) REGEXP '^[0-9]+$'
                 THEN CAST(TRIM(ra.value) AS SIGNED) END) AS away_aggregate
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    LEFT JOIN result ro ON ro.event_participantsFK = ep.id AND ro.del = 'no'
                       AND ro.result_typeFK = 549
                       AND ro.value IS NOT NULL AND TRIM(ro.value) <> ''
    LEFT JOIN result ra ON ra.event_participantsFK = ep.id AND ra.del = 'no'
                       AND ra.result_typeFK = 550
                       AND ra.value IS NOT NULL AND TRIM(ra.value) <> ''
    WHERE e.del = 'no'
      AND e.status_type = 'finished'
      AND tt.sportFK = 1
      AND EXISTS (
          SELECT 1
          FROM event_participants ep2
          JOIN result r2 ON r2.event_participantsFK = ep2.id AND r2.del = 'no'
                        AND r2.result_typeFK = 549
                        AND r2.value IS NOT NULL AND TRIM(r2.value) <> ''
          WHERE ep2.eventFK = e.id AND ep2.del = 'no'
      )
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY e.id, e.name, e.startdate, tt.name, t.name
) x
WHERE x.home_outcome IS NULL
   OR x.away_outcome IS NULL
   OR x.home_outcome NOT IN ('won', 'lost')
   OR x.away_outcome NOT IN ('won', 'lost')
   OR x.home_outcome = x.away_outcome
   OR x.home_aggregate IS NULL
   OR x.away_aggregate IS NULL
   OR (x.home_outcome = 'won' AND x.home_aggregate < x.away_aggregate)
   OR (x.away_outcome = 'won' AND x.away_aggregate < x.home_aggregate)

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
WHERE e.del = 'no'
  AND e.status_type = 'finished'
  AND tt.sportFK = 1
  AND EXISTS (
      SELECT 1
      FROM event_participants ep2
      JOIN result r2 ON r2.event_participantsFK = ep2.id AND r2.del = 'no'
                    AND r2.result_typeFK = 549
                    AND r2.value IS NOT NULL AND TRIM(r2.value) <> ''
      WHERE ep2.eventFK = e.id AND ep2.del = 'no'
  )
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_startdate DESC;


-- ================================================================================
SELECT
    -- CheckID - Soccer-DQ-084
    -- Name - EVENT_RESULTS_HALFTIME_ABOVE_ORDINARY_TIME
    -- What it does: Finds participants whose half-time score is higher than their own ordinary-time score, so a snapshot taken during the match exceeds the total it was taken from.
    'Halftime_Above_Ordinary_Time' AS check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.participant_name,
    x.halftime,
    x.ordinary_time,
    x.template_name,
    x.tournament_name,
    NULL AS eligible_count,
    0 AS sort_order
-- 5 Halftime is a snapshot taken during ordinary time, not a stage that adds to anything, which
-- is exactly why it is absent from the sum Soccer-DQ-082 asserts. A snapshot cannot exceed the
-- total it was taken from, and nothing else in the package compares the two: every other score
-- check reads a value against its own field or against the deciding score, never against the
-- earlier reading of the same one.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        p.name AS participant_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        MAX(CASE WHEN r.result_typeFK = 5 THEN CAST(TRIM(r.value) AS SIGNED) END) AS halftime,
        MAX(CASE WHEN r.result_typeFK = 1 THEN CAST(TRIM(r.value) AS SIGNED) END) AS ordinary_time
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
    JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
                 AND r.result_typeFK IN (1, 5)
                 AND TRIM(r.value) REGEXP '^[0-9]+$'
    WHERE e.del = 'no'
      AND e.status_type = 'finished'
      AND tt.sportFK = 1
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY e.id, e.name, e.startdate, ep.id, p.name, tt.name, t.name
) x
-- Only a participant holding both readable values is in the population; one holding a single
-- one has nothing to compare and is not a finding here. A value that is not a plain
-- non-negative integer never enters, in the findings and in the coverage count alike, because
-- Soccer-DQ-088 names it as the value defect it is.
WHERE x.halftime IS NOT NULL
  AND x.ordinary_time IS NOT NULL
  AND x.halftime > x.ordinary_time

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT c.ep_id) AS eligible_count,
    1 AS sort_order
FROM (
    SELECT ep.id AS ep_id
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
                 AND r.result_typeFK IN (1, 5)
                 AND TRIM(r.value) REGEXP '^[0-9]+$'
    WHERE e.del = 'no'
      AND e.status_type = 'finished'
      AND tt.sportFK = 1
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY ep.id
    HAVING COUNT(DISTINCT r.result_typeFK) = 2
) c

ORDER BY sort_order, event_startdate DESC;


-- ================================================================================
SELECT
    -- CheckID - Soccer-DQ-085
    -- Name - EVENT_RESULTS_SCORE_TYPE_STORED_FOR_SOME_PARTICIPANTS_ONLY
    -- What it does: Finds matches where a score type is stored for some participants but not all, naming each type and how many of them hold it.
    'Score_Type_Stored_For_Some_Participants_Only' AS check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.participant_count,
    x.one_sided_types,
    x.one_sided_type_count,
    x.template_name,
    x.tournament_name,
    NULL AS eligible_count,
    0 AS sort_order
-- Both sides of a match contest the same stages, so a stage scored for one of them and not the
-- other means the two sides disagree about what was played. GLOBAL-DQ-091 asserts this through
-- the scope layer, where other sports keep their periods; Soccer's scope layer holds the
-- aggregate of a two-legged tie instead, so that check reads a structure this sport does not
-- write. 501 Medal is left out on purpose - a bronze match awards one - and so is 550 Overall
-- Score, which exists only where a tie is played over two legs.
FROM (
    SELECT
        y.event_id,
        y.event_name,
        y.event_startdate,
        y.template_name,
        y.tournament_name,
        y.participant_count,
        SUBSTRING(GROUP_CONCAT(CONCAT(y.result_type_name, ' (', y.holders, ')')
                  ORDER BY y.result_type_id SEPARATOR ', '), 1, 150) AS one_sided_types,
        COUNT(*) AS one_sided_type_count
    FROM (
        SELECT
            e.id AS event_id,
            e.name AS event_name,
            e.startdate AS event_startdate,
            tt.name AS template_name,
            t.name AS tournament_name,
            r.result_typeFK AS result_type_id,
            rt.name AS result_type_name,
            COUNT(DISTINCT ep.id) AS holders,
            (
                SELECT COUNT(*)
                FROM event_participants ep3
                WHERE ep3.eventFK = e.id AND ep3.del = 'no'
            ) AS participant_count
        FROM event e
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
        JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
        JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
                     AND r.result_typeFK IN (1, 2, 3, 4, 5, 6)
                     AND r.value IS NOT NULL
                     AND TRIM(r.value) <> ''
        JOIN result_type rt ON rt.id = r.result_typeFK
        WHERE e.del = 'no'
          AND e.status_type = 'finished'
          AND tt.sportFK = 1
          -- AND t.tournament_templateFK = <tournament_template_id>
          -- AND e.startdate >= '<from_datetime>'
          -- AND e.startdate <  '<to_datetime>'
        GROUP BY e.id, e.name, e.startdate, tt.name, t.name, r.result_typeFK, rt.name
        -- Measured against the match's own participant count rather than against a fixed pair,
        -- so an event entering other than two competitors is not reported twice: that defect is
        -- Soccer-DQ-063. A type no participant stores at all never enters, which is what
        -- separates a stage that was not played from a stage the two sides disagree about.
        HAVING holders < participant_count
    ) y
    GROUP BY y.event_id, y.event_name, y.event_startdate, y.template_name, y.tournament_name,
             y.participant_count
) x

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
WHERE e.del = 'no'
  AND e.status_type = 'finished'
  AND tt.sportFK = 1
  AND EXISTS (
      SELECT 1
      FROM event_participants ep2
      JOIN result r2 ON r2.event_participantsFK = ep2.id AND r2.del = 'no'
                    AND r2.result_typeFK IN (1, 2, 3, 4, 5, 6)
                    AND r2.value IS NOT NULL AND TRIM(r2.value) <> ''
      WHERE ep2.eventFK = e.id AND ep2.del = 'no'
  )
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_startdate DESC;


-- ================================================================================
SELECT
    -- CheckID - Soccer-DQ-086
    -- Name - EVENT_PARTICIPANTS_SIDE_NUMBER_INVALID
    -- What it does: Finds matches whose participants are not numbered as the two sides of a pairing - a number outside one and two, or both competitors holding the same one.
    CASE
        WHEN x.number_outside_the_pair > 0
            THEN 'Side_Number_Outside_One_And_Two'
        ELSE 'Both_Participants_Hold_The_Same_Side_Number'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.event_status,
    x.participant_count,
    x.side_numbers,
    x.template_name,
    x.tournament_name,
    NULL AS eligible_count,
    0 AS sort_order
-- event_participants.number is where the home and away sides are distinguished, and nothing
-- else in the package reads it. GLOBAL-DQ-088 would have asserted it, but that check reads a
-- Winner event property Soccer does not write, so its parameters are recorded Not applicable
-- and the column is left untested. An import writing both sides as 1 would satisfy every
-- approved check - the pair count, the result symmetry, the score arithmetic - while the
-- distinction between home and away disappeared without a finding anywhere.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        e.status_type AS event_status,
        tt.name AS template_name,
        t.name AS tournament_name,
        COUNT(*) AS participant_count,
        COUNT(DISTINCT ep.number) AS distinct_numbers,
        SUM(CASE WHEN ep.number IS NULL OR ep.number NOT IN (1, 2) THEN 1 ELSE 0 END)
            AS number_outside_the_pair,
        SUBSTRING(GROUP_CONCAT(COALESCE(CAST(ep.number AS CHAR), 'NULL')
                  ORDER BY ep.number SEPARATOR ' | '), 1, 60) AS side_numbers
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    WHERE e.del = 'no'
      AND tt.sportFK = 1
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY e.id, e.name, e.startdate, e.status_type, tt.name, t.name
) x
-- Every event with participants is eligible, finished or not: the numbering is written when the
-- fixture is created rather than when it is played. Only the numbering is asserted here. How
-- many participants a match holds is Soccer-DQ-063, so a duplicated number is reported only
-- where the pair itself is intact and the defect is therefore the number and nothing else.
WHERE x.number_outside_the_pair > 0
   OR (x.participant_count = 2 AND x.distinct_numbers < 2)

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
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = 1
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_startdate DESC;


-- ================================================================================
SELECT
    -- CheckID - Soccer-DQ-087
    -- Name - COMP.RANK_RESULTS_TEAM_RANK_MISSING_OR_INVALID
    -- What it does: Finds teams in a Comp.Rank holding no Rank row, an empty Rank or one that is not a positive integer.
    CASE
        WHEN x.rank_rows = 0 THEN 'Team_Holds_No_Rank_Row'
        WHEN x.rank_value IS NULL OR x.rank_value = '' THEN 'Team_Rank_Value_Empty'
        ELSE 'Team_Rank_Not_A_Positive_Integer'
    END AS check_type,
    x.statistic_id,
    x.statistic_name,
    x.participant_id,
    x.participant_name,
    x.rank_value,
    x.template_name,
    x.tournament_name,
    NULL AS eligible_count,
    0 AS sort_order
-- A statistic ranking teams holds the placing, so a team in one without a readable place is a
-- ranking with a hole in it. GLOBAL-DQ-012 asserts exactly this and cannot be instantiated
-- here: it reports a missing Rank only where no Comment explains it, and this sport's Comp.Rank
-- stores no Comment field at all, so DATA_COMMENT_TYPE_ID is recorded Not applicable and the
-- template has nothing to read. GLOBAL-DQ-032 sees only a statistic where nobody holds a rank;
-- one team missing among thirty-one is invisible to it. No upper bound is asserted:
-- RANK_MAX_PLAUSIBLE is a judgement about the client's own competitions, and outside them the
-- Nations League ranks all fifty-one UEFA federations in one statistic, correctly.
FROM (
    SELECT
        s.id AS statistic_id,
        s.name AS statistic_name,
        p.id AS participant_id,
        p.name AS participant_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        COUNT(sd.id) AS rank_rows,
        MIN(TRIM(sd.value)) AS rank_value
    FROM statistic s
    JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = 1
    JOIN statistic_participants11 sp ON sp.statisticFK = s.id AND sp.del = 'no'
    JOIN participant p ON p.id = sp.participantFK AND p.del = 'no'
         AND p.type = 'team'
    LEFT JOIN statistic_data11 sd ON sd.statistic_participants11FK = sp.id AND sd.del = 'no'
                                 AND sd.statistic_data_typeFK = 1270
    WHERE s.del = 'no'
      AND s.statistic_typeFK = 11
      AND s.object_typeFK = 3
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      -- AND t.tournament_templateFK = <tournament_template_id>
    GROUP BY s.id, s.name, sp.id, p.id, p.name, tt.name, t.name
) x
-- The population is the team participant, read from participant.type rather than from the
-- statistic's name: the two kinds of Comp.Rank divide the work structurally, and a squad list
-- carries athletes and coaches who hold no place by design. A team holding the Rank twice is
-- left to Soccer-DQ-008, so one row is never reported under two verdicts.
WHERE x.rank_rows = 0
   OR x.rank_value IS NULL
   OR x.rank_value = ''
   OR (x.rank_rows = 1 AND x.rank_value NOT REGEXP '^[1-9][0-9]*$')

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT sp.id) AS eligible_count,
    1 AS sort_order
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 1
JOIN statistic_participants11 sp ON sp.statisticFK = s.id AND sp.del = 'no'
JOIN participant p ON p.id = sp.participantFK AND p.del = 'no'
     AND p.type = 'team'
WHERE s.del = 'no'
  AND s.statistic_typeFK = 11
  AND s.object_typeFK = 3
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, statistic_id, participant_name;


-- ================================================================================
SELECT
    -- CheckID - Soccer-DQ-088
    -- Name - EVENT_RESULTS_SCORE_VALUE_SHAPE_INVALID
    -- What it does: Finds score values that are not a count of goals - text, a negative number or one carrying a fractional part.
    CASE
        WHEN TRIM(r.value) NOT REGEXP '^-?[0-9]+([.,][0-9]+)?$' THEN 'Score_Value_Not_Numeric'
        WHEN TRIM(r.value) LIKE '-%' THEN 'Score_Value_Negative'
        ELSE 'Score_Value_Fractional'
    END AS check_type,
    r.id AS result_id,
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    p.name AS participant_name,
    r.result_typeFK AS result_type_id,
    rt.name AS result_type_name,
    TRIM(r.value) AS result_value,
    tt.name AS template_name,
    t.name AS tournament_name,
    NULL AS eligible_count,
    0 AS sort_order
-- Every score type here is a count of goals, so the only shape it can take is a plain
-- non-negative integer. GLOBAL-DQ-076 asserts this and cannot be instantiated: it reads the
-- sport's status vocabulary to name a leaked status code, and this sport records no Comment
-- result type, so RESULT_COMMENT_VALUE_LIST is Not applicable. That leaves five of the seven
-- score types read by nothing at all. It also guards Soccer-DQ-082, whose arithmetic can only
-- sum what it can read - the same reason GLOBAL-DQ-086 stands in front of GLOBAL-DQ-085.
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
             AND r.result_typeFK IN (1, 2, 3, 4, 5, 6, 550)
             AND r.value IS NOT NULL
             AND TRIM(r.value) <> ''
JOIN result_type rt ON rt.id = r.result_typeFK
WHERE e.del = 'no'
  AND tt.sportFK = 1
  AND TRIM(r.value) NOT REGEXP '^[0-9]+$'
  -- A sign or a fractional part on 4 Final Result or 6 Running score is already Soccer-DQ-020,
  -- so those two types are asserted here only for a value that is not a number at all - which
  -- that check does not test. An empty or blank value belongs to Soccer-DQ-055 and never
  -- enters, in the findings and in the coverage count alike.
  AND (
        TRIM(r.value) NOT REGEXP '^-?[0-9]+([.,][0-9]+)?$'
     OR r.result_typeFK NOT IN (4, 6)
  )
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT r.id) AS eligible_count,
    1 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
             AND r.result_typeFK IN (1, 2, 3, 4, 5, 6, 550)
             AND r.value IS NOT NULL
             AND TRIM(r.value) <> ''
WHERE e.del = 'no'
  AND tt.sportFK = 1
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_startdate DESC;


-- ================================================================================
SELECT
    -- CheckID - Soccer-DQ-089
    -- Name - EVENT_SCOPE_TIE_REFERENCE_INVALID
    -- What it does: Finds two-legged ties whose reference to the other leg is not an event id, names its own event, or names an event that does not exist or belongs to another tournament.
    CASE
        WHEN x.not_an_id = 1 THEN 'Tie_Reference_Is_Not_An_Event_Id'
        WHEN x.self_reference = 1 THEN 'Tie_Reference_Names_Its_Own_Event'
        WHEN x.unresolved_reference = 1 THEN 'Tie_Reference_Resolves_To_No_Active_Event'
        ELSE 'Tie_Reference_Leaves_Its_Own_Tournament'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.referenced_value,
    x.reference_rows,
    x.template_name,
    x.tournament_name,
    NULL AS eligible_count,
    0 AS sort_order
-- A tie played over two legs is assembled under a 351 aggregate_score container, and the other
-- leg is named by an event_scope_detail called ref_eventFK - a name and value pair rather than a
-- column, so nothing in the database enforces that the value is an event at all. No check reads
-- this layer today: GLOBAL-DQ-102 asserts the scope result's owner and never the container's own
-- detail, and every other scope template reads periods, which this sport does not store.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        tt.name AS template_name,
        t.name AS tournament_name,
        COUNT(esd.id) AS reference_rows,
        SUBSTRING(GROUP_CONCAT(DISTINCT TRIM(esd.value) SEPARATOR ', '), 1, 60) AS referenced_value,
        MAX(CASE WHEN TRIM(esd.value) NOT REGEXP '^[1-9][0-9]*$'
                 THEN 1 ELSE 0 END) AS not_an_id,
        MAX(CASE WHEN TRIM(esd.value) REGEXP '^[1-9][0-9]*$'
                  AND CAST(TRIM(esd.value) AS SIGNED) = e.id
                 THEN 1 ELSE 0 END) AS self_reference,
        MAX(CASE WHEN TRIM(esd.value) REGEXP '^[1-9][0-9]*$'
                  AND CAST(TRIM(esd.value) AS SIGNED) <> e.id
                  AND e2.id IS NULL
                 THEN 1 ELSE 0 END) AS unresolved_reference,
        MAX(CASE WHEN e2.id IS NOT NULL
                  AND ts2.tournamentFK <> ts.tournamentFK
                 THEN 1 ELSE 0 END) AS foreign_tournament
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN event_scope es ON es.eventFK = e.id AND es.del = 'no'
                       AND es.scope_typeFK = 351
    JOIN event_scope_detail esd ON esd.event_scopeFK = es.id AND esd.del = 'no'
                               AND esd.name = 'ref_eventFK'
    LEFT JOIN event e2 ON e2.id = CAST(TRIM(esd.value) AS SIGNED) AND e2.del = 'no'
    LEFT JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
    WHERE e.del = 'no'
      AND tt.sportFK = 1
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY e.id, e.name, e.startdate, tt.name, t.name
) x
-- Four assertions and no fifth. What is deliberately NOT asserted is the direction: measured
-- sport-wide on 2026-08-06, 17368 of 17604 containers name a leg that carries no container of
-- its own, so a reference that is not reciprocated is the norm rather than a defect. The second
-- leg holds the container because the aggregate is only known once it has been played. A rule
-- requiring the other leg to point back would report the whole population and describe the
-- design instead of finding anything in it. Every event carrying a container is eligible,
-- finished or not, because the tie is assembled before its second leg is played.
WHERE x.not_an_id = 1
   OR x.self_reference = 1
   OR x.unresolved_reference = 1
   OR x.foreign_tournament = 1

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN event_scope es ON es.eventFK = e.id AND es.del = 'no'
                   AND es.scope_typeFK = 351
JOIN event_scope_detail esd ON esd.event_scopeFK = es.id AND esd.del = 'no'
                           AND esd.name = 'ref_eventFK'
WHERE e.del = 'no'
  AND tt.sportFK = 1
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_startdate DESC;
