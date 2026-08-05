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
