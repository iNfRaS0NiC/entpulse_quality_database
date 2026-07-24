SELECT
    -- CheckID - GLOBAL-DISCOVERY-004
    -- Name - EVENT_PARTICIPANT_TYPES_GENDERS
    -- What it does: Lists participant types and genders used by active event participants in the selected sport.
    p.type AS participant_type,
    p.gender AS participant_gender,
    COUNT(DISTINCT p.id) AS participant_count,
    COUNT(DISTINCT ep.id) AS event_participation_count,
    MIN(p.id) AS sample_participant_id,
    MIN(p.name) AS sample_participant_name
FROM event_participants ep
JOIN participant p
  ON p.id = ep.participantFK
 AND p.del = 'no'
JOIN event e
  ON e.id = ep.eventFK
 AND e.del = 'no'
JOIN tournament_stage ts
  ON ts.id = e.tournament_stageFK
 AND ts.del = 'no'
JOIN tournament t
  ON t.id = ts.tournamentFK
 AND t.del = 'no'
JOIN tournament_template tt
  ON tt.id = t.tournament_templateFK
 AND tt.del = 'no'
WHERE ep.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
GROUP BY
    p.type,
    p.gender
ORDER BY
    event_participation_count DESC,
    p.type,
    p.gender;


SELECT
    -- CheckID - GLOBAL-DISCOVERY-005
    -- Name - LINEUP_TYPES_PARTICIPANT_TYPES
    -- What it does: Lists active lineup types and member participant types and genders used in the selected sport.
    l.lineup_typeFK AS lineup_type_id,
    lt.name AS lineup_type_name,
    parent_p.type AS parent_event_participant_type,
    member_p.type AS lineup_member_type,
    member_p.gender AS lineup_member_gender,
    COUNT(DISTINCT l.id) AS lineup_row_count,
    COUNT(DISTINCT member_p.id) AS member_count
FROM lineup l
JOIN event_participants ep
  ON ep.id = l.event_participantsFK
 AND ep.del = 'no'
JOIN participant parent_p
  ON parent_p.id = ep.participantFK
 AND parent_p.del = 'no'
JOIN participant member_p
  ON member_p.id = l.participantFK
 AND member_p.del = 'no'
JOIN event e
  ON e.id = ep.eventFK
 AND e.del = 'no'
JOIN tournament_stage ts
  ON ts.id = e.tournament_stageFK
 AND ts.del = 'no'
JOIN tournament t
  ON t.id = ts.tournamentFK
 AND t.del = 'no'
JOIN tournament_template tt
  ON tt.id = t.tournament_templateFK
 AND tt.del = 'no'
LEFT JOIN lineup_type lt
  ON lt.id = l.lineup_typeFK
WHERE l.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
GROUP BY
    l.lineup_typeFK,
    lt.name,
    parent_p.type,
    member_p.type,
    member_p.gender
ORDER BY
    lineup_row_count DESC,
    l.lineup_typeFK,
    member_p.type,
    member_p.gender;


SELECT
    -- CheckID - GLOBAL-DISCOVERY-006
    -- Name - SPORT_REGISTRY_PARTICIPANT_TYPES
    -- What it does: Lists participant roles, types, genders and active flags stored in the selected sport's object_participants registry.
    op.participant_type AS registry_participant_role,
    op.active AS registry_active_flag,
    p.type AS participant_type,
    p.gender AS participant_gender,
    COUNT(DISTINCT op.id) AS registry_row_count,
    COUNT(DISTINCT p.id) AS participant_count,
    MIN(p.id) AS sample_participant_id,
    MIN(p.name) AS sample_participant_name
FROM object_participants op
JOIN participant p
  ON p.id = op.participantFK
 AND p.del = 'no'
WHERE op.object = 'sport'
  AND op.objectFK = {{SPORT_ID}}
  AND op.del = 'no'
GROUP BY
    op.participant_type,
    op.active,
    p.type,
    p.gender
ORDER BY
    registry_row_count DESC,
    op.participant_type,
    p.type,
    p.gender;
