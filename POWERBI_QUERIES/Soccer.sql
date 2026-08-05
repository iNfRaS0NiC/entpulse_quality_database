SELECT
    -- CheckID - Soccer-DQ-022
    -- Name - EVENT_RESULTS_SCORE_TIED_ON_KNOCKOUT_SINGLE_MATCH
    -- What it does: Finds active finished Soccer events on a knockout round type, excluding a leg of a tie decided on aggregate, whose two participants hold an identical deciding score, so the round that must produce a winner produced none, with the shared score, the round type and template, tournament and stage name context, together with a coverage count of all eligible finished knockout single-match events holding exactly two deciding scores.
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
      -- AND tt2.id = <tournament_template_id>
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
  -- AND tt.id = <tournament_template_id>
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
      -- AND tt2.id = <tournament_template_id>
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
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_startdate DESC;
