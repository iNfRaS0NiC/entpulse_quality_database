SELECT
    -- CheckID - GLOBAL-DISCOVERY-001
    -- Name - SPORT_IDENTITY
    -- What it does: Returns the active sport identity (id, name, enet code) for the selected numeric sport ID.
    s.id AS sport_id,
    s.name AS sport_name,
    s.enetSportCode AS enet_sport_code
FROM sport s
WHERE s.id = {{SPORT_ID}}
  AND s.del = 'no';


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DISCOVERY-002
    -- Name - CORE_HIERARCHY_USAGE
    -- What it does: Summarizes active templates, tournaments, stages, events and event participants under the selected sport.
    tt.id AS tournament_template_id,
    tt.name AS tournament_template_name,
    tt.gender AS template_gender,
    COUNT(DISTINCT t.id) AS tournament_count,
    COUNT(DISTINCT ts.id) AS tournament_stage_count,
    COUNT(DISTINCT e.id) AS event_count,
    COUNT(DISTINCT ep.id) AS event_participant_count
FROM tournament_template tt
LEFT JOIN tournament t
  ON t.tournament_templateFK = tt.id
 AND t.del = 'no'
LEFT JOIN tournament_stage ts
  ON ts.tournamentFK = t.id
 AND ts.del = 'no'
LEFT JOIN event e
  ON e.tournament_stageFK = ts.id
 AND e.del = 'no'
LEFT JOIN event_participants ep
  ON ep.eventFK = e.id
 AND ep.del = 'no'
WHERE tt.sportFK = {{SPORT_ID}}
  AND tt.del = 'no'
  -- AND tt.id = <tournament_template_id>
GROUP BY
    tt.id,
    tt.name,
    tt.gender
ORDER BY
    tt.name,
    tt.id;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DISCOVERY-003
    -- Name - EVENT_STATUS_USAGE
    -- What it does: Lists coarse and detailed status combinations used by active events in the selected sport.
    e.status_type,
    e.status_descFK AS status_desc_id,
    sd.name AS status_desc_name,
    COUNT(DISTINCT e.id) AS event_count,
    MIN(e.id) AS sample_event_id,
    MIN(e.name) AS sample_event_name
FROM event e
JOIN tournament_stage ts
  ON ts.id = e.tournament_stageFK
 AND ts.del = 'no'
JOIN tournament t
  ON t.id = ts.tournamentFK
 AND t.del = 'no'
JOIN tournament_template tt
  ON tt.id = t.tournament_templateFK
 AND tt.del = 'no'
LEFT JOIN status_desc sd
  ON sd.id = e.status_descFK
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
GROUP BY
    e.status_type,
    e.status_descFK,
    sd.name
ORDER BY
    event_count DESC,
    e.status_type,
    e.status_descFK;
