SELECT
    -- CheckID - GLOBAL-DISCOVERY-007
    -- Name - EVENT_RESULTS_TYPES_CODES
    -- What it does: Lists active result type and result code combinations used by event participants in the selected sport.
    r.result_typeFK AS result_type_id,
    rt.name AS result_type_name,
    r.result_code,
    COUNT(DISTINCT r.id) AS result_row_count,
    COUNT(DISTINCT ep.id) AS event_participant_count,
    COUNT(DISTINCT e.id) AS event_count,
    MIN(r.value) AS sample_value
FROM result r
JOIN event_participants ep
  ON ep.id = r.event_participantsFK
 AND ep.del = 'no'
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
LEFT JOIN result_type rt
  ON rt.id = r.result_typeFK
WHERE r.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
GROUP BY
    r.result_typeFK,
    rt.name,
    r.result_code
ORDER BY
    r.result_typeFK,
    r.result_code;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DISCOVERY-008
    -- Name - INCIDENT_TYPES_CODES
    -- What it does: Lists active incident type and incident code combinations used by event participants in the selected sport.
    i.incident_typeFK AS incident_type_id,
    it.name AS incident_type_name,
    i.incident_code,
    COUNT(DISTINCT i.id) AS incident_row_count,
    COUNT(DISTINCT ep.id) AS event_participant_count,
    COUNT(DISTINCT e.id) AS event_count
FROM incident i
JOIN event_participants ep
  ON ep.id = i.event_participantsFK
 AND ep.del = 'no'
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
LEFT JOIN incident_type it
  ON it.id = i.incident_typeFK
WHERE i.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
GROUP BY
    i.incident_typeFK,
    it.name,
    i.incident_code
ORDER BY
    i.incident_typeFK,
    i.incident_code;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DISCOVERY-009
    -- Name - SCOPE_TYPES
    -- What it does: Lists active event-scope container types used by events in the selected sport.
    es.scope_typeFK AS scope_type_id,
    st.name AS scope_type_name,
    COUNT(DISTINCT es.id) AS scope_container_count,
    COUNT(DISTINCT e.id) AS event_count,
    MIN(es.id) AS sample_event_scope_id,
    MIN(e.id) AS sample_event_id,
    MIN(e.name) AS sample_event_name
FROM event_scope es
JOIN event e
  ON e.id = es.eventFK
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
LEFT JOIN scope_type st
  ON st.id = es.scope_typeFK
WHERE es.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
GROUP BY
    es.scope_typeFK,
    st.name
ORDER BY
    es.scope_typeFK;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DISCOVERY-010
    -- Name - SCOPE_DATA_TYPES_AND_LAYERS
    -- What it does: Lists participant-owned, lineup-owned and detail value layers used under event scopes in the selected sport.
    x.storage_layer,
    x.scope_type_id,
    x.scope_type_name,
    x.scope_data_type_id,
    x.scope_data_type_name,
    x.detail_name,
    COUNT(*) AS value_row_count,
    COUNT(DISTINCT x.event_scope_id) AS scope_container_count,
    MIN(x.value) AS sample_value
FROM (
    SELECT
        'scope_result' AS storage_layer,
        es.id AS event_scope_id,
        es.scope_typeFK AS scope_type_id,
        st.name AS scope_type_name,
        sr.scope_data_typeFK AS scope_data_type_id,
        sdt.name AS scope_data_type_name,
        NULL AS detail_name,
        sr.value
    FROM scope_result sr
    JOIN event_scope es
      ON es.id = sr.event_scopeFK
     AND es.del = 'no'
    JOIN event e
      ON e.id = es.eventFK
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
    LEFT JOIN scope_type st
      ON st.id = es.scope_typeFK
    LEFT JOIN scope_data_type sdt
      ON sdt.id = sr.scope_data_typeFK
    WHERE sr.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      -- AND tt.id = <tournament_template_id>

    UNION ALL

    SELECT
        'lineup_scope_result' AS storage_layer,
        es.id AS event_scope_id,
        es.scope_typeFK AS scope_type_id,
        st.name AS scope_type_name,
        lsr.scope_data_typeFK AS scope_data_type_id,
        sdt.name AS scope_data_type_name,
        NULL AS detail_name,
        lsr.value
    FROM lineup_scope_result lsr
    JOIN event_scope es
      ON es.id = lsr.event_scopeFK
     AND es.del = 'no'
    JOIN event e
      ON e.id = es.eventFK
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
    LEFT JOIN scope_type st
      ON st.id = es.scope_typeFK
    LEFT JOIN scope_data_type sdt
      ON sdt.id = lsr.scope_data_typeFK
    WHERE lsr.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      -- AND tt.id = <tournament_template_id>

    UNION ALL

    SELECT
        'event_scope_detail' AS storage_layer,
        es.id AS event_scope_id,
        es.scope_typeFK AS scope_type_id,
        st.name AS scope_type_name,
        NULL AS scope_data_type_id,
        NULL AS scope_data_type_name,
        esd.name AS detail_name,
        esd.value
    FROM event_scope_detail esd
    JOIN event_scope es
      ON es.id = esd.event_scopeFK
     AND es.del = 'no'
    JOIN event e
      ON e.id = es.eventFK
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
    LEFT JOIN scope_type st
      ON st.id = es.scope_typeFK
    WHERE esd.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      -- AND tt.id = <tournament_template_id>
) AS x
GROUP BY
    x.storage_layer,
    x.scope_type_id,
    x.scope_type_name,
    x.scope_data_type_id,
    x.scope_data_type_name,
    x.detail_name
ORDER BY
    x.storage_layer,
    x.scope_type_id,
    x.scope_data_type_id,
    x.detail_name;
