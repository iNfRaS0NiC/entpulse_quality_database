SELECT
    -- CheckID - GLOBAL-DISCOVERY-018
    -- Name - EVENT_ROUND_TYPE_USAGE_SUMMARY
    -- What it does: Summarizes round_typeFK values and names used by active events in the selected sport.
    e.round_typeFK AS round_type_id,
    rt.name AS round_type_name,
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
LEFT JOIN round_type rt
  ON rt.id = e.round_typeFK
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
GROUP BY
    e.round_typeFK,
    rt.name
ORDER BY
    event_count DESC,
    e.round_typeFK;


SELECT
    -- CheckID - GLOBAL-DISCOVERY-019
    -- Name - EVENT_ROUND_TYPE_USAGE_DETAIL
    -- What it does: Lists active events using one round_typeFK selected from the corresponding GLOBAL summary query.
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    e.status_type,
    e.status_descFK,
    e.round_typeFK AS round_type_id,
    rt.name AS round_type_name,
    ts.id AS tournament_stage_id,
    ts.name AS tournament_stage_name,
    t.id AS tournament_id,
    t.name AS tournament_name,
    tt.id AS tournament_template_id,
    tt.name AS tournament_template_name
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
LEFT JOIN round_type rt
  ON rt.id = e.round_typeFK
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND (
      e.round_typeFK = {{ROUND_TYPE_ID}}
      OR (e.round_typeFK IS NULL AND {{ROUND_TYPE_ID}} IS NULL)
  )
  -- AND tt.id = <tournament_template_id>
ORDER BY
    tt.name,
    t.name,
    ts.name,
    e.startdate,
    e.id;


SELECT
    -- CheckID - GLOBAL-DISCOVERY-020
    -- Name - EVENT_NAME_PATTERNS_SUMMARY
    -- What it does: Groups active event names by a digit-normalized pattern in the selected sport.
    REGEXP_REPLACE(e.name, '[0-9]+', '#') AS name_pattern,
    COUNT(DISTINCT e.id) AS event_count,
    COUNT(DISTINCT e.name) AS distinct_name_count,
    MIN(e.name) AS sample_name_first,
    MAX(e.name) AS sample_name_last
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
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
GROUP BY
    name_pattern
ORDER BY
    event_count DESC,
    name_pattern;


SELECT
    -- CheckID - GLOBAL-DISCOVERY-021
    -- Name - EVENT_NAME_PATTERNS_DETAIL
    -- What it does: Lists active events matching one digit-normalized name pattern selected from the corresponding GLOBAL summary query.
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    e.status_type,
    e.status_descFK,
    e.round_typeFK,
    ts.id AS tournament_stage_id,
    ts.name AS tournament_stage_name,
    t.id AS tournament_id,
    t.name AS tournament_name,
    tt.id AS tournament_template_id,
    tt.name AS tournament_template_name
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
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND REGEXP_REPLACE(e.name, '[0-9]+', '#') = '{{NAME_PATTERN}}'
  -- AND tt.id = <tournament_template_id>
ORDER BY
    tt.name,
    t.name,
    ts.name,
    e.startdate,
    e.id;


SELECT
    -- CheckID - GLOBAL-DISCOVERY-022
    -- Name - TOURNAMENT_STAGE_NAME_PATTERNS_SUMMARY
    -- What it does: Groups active tournament-stage names by a digit-normalized pattern in the selected sport.
    REGEXP_REPLACE(ts.name, '[0-9]+', '#') AS name_pattern,
    COUNT(DISTINCT ts.id) AS stage_count,
    COUNT(DISTINCT ts.name) AS distinct_name_count,
    COUNT(DISTINCT t.id) AS tournament_count,
    GROUP_CONCAT(DISTINCT ts.gender ORDER BY ts.gender SEPARATOR ', ') AS genders,
    MIN(ts.name) AS sample_name_first,
    MAX(ts.name) AS sample_name_last
FROM tournament_stage ts
JOIN tournament t
  ON t.id = ts.tournamentFK
 AND t.del = 'no'
JOIN tournament_template tt
  ON tt.id = t.tournament_templateFK
 AND tt.del = 'no'
WHERE ts.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
GROUP BY
    name_pattern
ORDER BY
    stage_count DESC,
    name_pattern;


SELECT
    -- CheckID - GLOBAL-DISCOVERY-023
    -- Name - TOURNAMENT_STAGE_NAME_PATTERNS_DETAIL
    -- What it does: Lists active stages matching one digit-normalized name pattern selected from the corresponding GLOBAL summary query.
    ts.id AS tournament_stage_id,
    ts.name AS tournament_stage_name,
    ts.gender AS stage_gender,
    ts.startdate AS stage_startdate,
    ts.enddate AS stage_enddate,
    ts.countryFK,
    t.id AS tournament_id,
    t.name AS tournament_name,
    tt.id AS tournament_template_id,
    tt.name AS tournament_template_name
FROM tournament_stage ts
JOIN tournament t
  ON t.id = ts.tournamentFK
 AND t.del = 'no'
JOIN tournament_template tt
  ON tt.id = t.tournament_templateFK
 AND tt.del = 'no'
WHERE ts.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND REGEXP_REPLACE(ts.name, '[0-9]+', '#') = '{{NAME_PATTERN}}'
  -- AND tt.id = <tournament_template_id>
ORDER BY
    tt.name,
    t.name,
    ts.startdate,
    ts.id;


SELECT
    -- CheckID - GLOBAL-DISCOVERY-024
    -- Name - STATISTIC_NAME_PATTERNS_SUMMARY
    -- What it does: Groups statistic names by a digit-normalized pattern for one confirmed statistic type and owner level in the selected sport.
    REGEXP_REPLACE(st.name, '[0-9]+', '#') AS name_pattern,
    COUNT(DISTINCT st.id) AS statistic_count,
    COUNT(DISTINCT st.name) AS distinct_name_count,
    MIN(st.name) AS sample_name_first,
    MAX(st.name) AS sample_name_last
FROM statistic st
LEFT JOIN sport sport_owner
  ON st.object_typeFK = 1
 AND sport_owner.id = st.objectFK
 AND sport_owner.del = 'no'
LEFT JOIN tournament_template tt2
  ON st.object_typeFK = 2
 AND tt2.id = st.objectFK
 AND tt2.del = 'no'
LEFT JOIN tournament t3
  ON st.object_typeFK = 3
 AND t3.id = st.objectFK
 AND t3.del = 'no'
LEFT JOIN tournament_template tt3
  ON tt3.id = t3.tournament_templateFK
 AND tt3.del = 'no'
LEFT JOIN tournament_stage ts4
  ON st.object_typeFK = 4
 AND ts4.id = st.objectFK
 AND ts4.del = 'no'
LEFT JOIN tournament t4
  ON t4.id = ts4.tournamentFK
 AND t4.del = 'no'
LEFT JOIN tournament_template tt4
  ON tt4.id = t4.tournament_templateFK
 AND tt4.del = 'no'
LEFT JOIN event e5
  ON st.object_typeFK = 5
 AND e5.id = st.objectFK
 AND e5.del = 'no'
LEFT JOIN tournament_stage ts5
  ON ts5.id = e5.tournament_stageFK
 AND ts5.del = 'no'
LEFT JOIN tournament t5
  ON t5.id = ts5.tournamentFK
 AND t5.del = 'no'
LEFT JOIN tournament_template tt5
  ON tt5.id = t5.tournament_templateFK
 AND tt5.del = 'no'
LEFT JOIN event_participants ep6
  ON st.object_typeFK = 6
 AND ep6.id = st.objectFK
 AND ep6.del = 'no'
LEFT JOIN event e6
  ON e6.id = ep6.eventFK
 AND e6.del = 'no'
LEFT JOIN tournament_stage ts6
  ON ts6.id = e6.tournament_stageFK
 AND ts6.del = 'no'
LEFT JOIN tournament t6
  ON t6.id = ts6.tournamentFK
 AND t6.del = 'no'
LEFT JOIN tournament_template tt6
  ON tt6.id = t6.tournament_templateFK
 AND tt6.del = 'no'
LEFT JOIN participant p15
  ON st.object_typeFK = 15
 AND p15.id = st.objectFK
 AND p15.del = 'no'
LEFT JOIN object_participants op15
  ON op15.object = 'sport'
 AND op15.participantFK = p15.id
 AND op15.del = 'no'
WHERE st.del = 'no'
  AND st.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND st.object_typeFK = {{STATISTIC_OWNER_TYPE_ID}}
  AND (
      sport_owner.id = {{SPORT_ID}}
      OR tt2.sportFK = {{SPORT_ID}}
      OR tt3.sportFK = {{SPORT_ID}}
      OR tt4.sportFK = {{SPORT_ID}}
      OR tt5.sportFK = {{SPORT_ID}}
      OR tt6.sportFK = {{SPORT_ID}}
      OR op15.objectFK = {{SPORT_ID}}
  )
GROUP BY
    name_pattern
ORDER BY
    statistic_count DESC,
    name_pattern;


SELECT
    -- CheckID - GLOBAL-DISCOVERY-025
    -- Name - STATISTIC_NAME_PATTERNS_DETAIL
    -- What it does: Lists statistics matching one digit-normalized name pattern selected from the corresponding GLOBAL summary query.
    st.id AS statistic_id,
    st.name AS statistic_name,
    st.statistic_typeFK AS statistic_type_id,
    st.object_typeFK AS statistic_owner_type_id,
    st.objectFK AS statistic_owner_id
FROM statistic st
LEFT JOIN sport sport_owner
  ON st.object_typeFK = 1
 AND sport_owner.id = st.objectFK
 AND sport_owner.del = 'no'
LEFT JOIN tournament_template tt2
  ON st.object_typeFK = 2
 AND tt2.id = st.objectFK
 AND tt2.del = 'no'
LEFT JOIN tournament t3
  ON st.object_typeFK = 3
 AND t3.id = st.objectFK
 AND t3.del = 'no'
LEFT JOIN tournament_template tt3
  ON tt3.id = t3.tournament_templateFK
 AND tt3.del = 'no'
LEFT JOIN tournament_stage ts4
  ON st.object_typeFK = 4
 AND ts4.id = st.objectFK
 AND ts4.del = 'no'
LEFT JOIN tournament t4
  ON t4.id = ts4.tournamentFK
 AND t4.del = 'no'
LEFT JOIN tournament_template tt4
  ON tt4.id = t4.tournament_templateFK
 AND tt4.del = 'no'
LEFT JOIN event e5
  ON st.object_typeFK = 5
 AND e5.id = st.objectFK
 AND e5.del = 'no'
LEFT JOIN tournament_stage ts5
  ON ts5.id = e5.tournament_stageFK
 AND ts5.del = 'no'
LEFT JOIN tournament t5
  ON t5.id = ts5.tournamentFK
 AND t5.del = 'no'
LEFT JOIN tournament_template tt5
  ON tt5.id = t5.tournament_templateFK
 AND tt5.del = 'no'
LEFT JOIN event_participants ep6
  ON st.object_typeFK = 6
 AND ep6.id = st.objectFK
 AND ep6.del = 'no'
LEFT JOIN event e6
  ON e6.id = ep6.eventFK
 AND e6.del = 'no'
LEFT JOIN tournament_stage ts6
  ON ts6.id = e6.tournament_stageFK
 AND ts6.del = 'no'
LEFT JOIN tournament t6
  ON t6.id = ts6.tournamentFK
 AND t6.del = 'no'
LEFT JOIN tournament_template tt6
  ON tt6.id = t6.tournament_templateFK
 AND tt6.del = 'no'
LEFT JOIN participant p15
  ON st.object_typeFK = 15
 AND p15.id = st.objectFK
 AND p15.del = 'no'
LEFT JOIN object_participants op15
  ON op15.object = 'sport'
 AND op15.participantFK = p15.id
 AND op15.del = 'no'
WHERE st.del = 'no'
  AND st.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND st.object_typeFK = {{STATISTIC_OWNER_TYPE_ID}}
  AND REGEXP_REPLACE(st.name, '[0-9]+', '#') = '{{NAME_PATTERN}}'
  AND (
      sport_owner.id = {{SPORT_ID}}
      OR tt2.sportFK = {{SPORT_ID}}
      OR tt3.sportFK = {{SPORT_ID}}
      OR tt4.sportFK = {{SPORT_ID}}
      OR tt5.sportFK = {{SPORT_ID}}
      OR tt6.sportFK = {{SPORT_ID}}
      OR op15.objectFK = {{SPORT_ID}}
  )
ORDER BY
    st.name,
    st.id;


SELECT
    -- CheckID - GLOBAL-DISCOVERY-026
    -- Name - EVENT_RESULTS_VALUE_PATTERNS_SUMMARY
    -- What it does: Classifies active event-result values by shape for each result type used in the selected sport.
    r.result_typeFK AS result_type_id,
    rt.name AS result_type_name,
    r.result_code,
    CASE
        WHEN r.value IS NULL THEN 'null'
        WHEN TRIM(r.value) = '' THEN 'empty'
        WHEN r.value REGEXP '^[+-]?[0-9]+$' THEN 'integer'
        WHEN r.value REGEXP '^[+-]?[0-9]+\\.[0-9]+$' THEN 'decimal'
        WHEN r.value REGEXP '^[+-]?[0-9]{1,3}:[0-9]{2}(:[0-9]{2})?(\\.[0-9]+)?$' THEN 'time_format'
        ELSE 'text_or_other'
    END AS value_shape,
    COUNT(DISTINCT r.id) AS value_count,
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
    r.result_code,
    value_shape
ORDER BY
    r.result_typeFK,
    r.result_code,
    value_count DESC;


SELECT
    -- CheckID - GLOBAL-DISCOVERY-027
    -- Name - EVENT_RESULTS_VALUE_PATTERNS_DETAIL
    -- What it does: Lists active event-result rows for one result type selected from the corresponding GLOBAL summary query.
    r.id AS result_id,
    r.result_typeFK AS result_type_id,
    rt.name AS result_type_name,
    r.result_code,
    r.value,
    ep.id AS event_participant_id,
    ep.participantFK AS participant_id,
    e.id AS event_id,
    e.name AS event_name,
    ts.id AS tournament_stage_id,
    ts.name AS tournament_stage_name,
    t.id AS tournament_id,
    t.name AS tournament_name,
    tt.id AS tournament_template_id,
    tt.name AS tournament_template_name
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
  AND r.result_typeFK = {{RESULT_TYPE_ID}}
  -- Optional: uncomment one value-shape filter.
  -- AND r.value REGEXP '^[+-]?[0-9]+$'
  -- AND r.value REGEXP '^[+-]?[0-9]+\\.[0-9]+$'
  -- AND r.value REGEXP '^[+-]?[0-9]{1,3}:[0-9]{2}(:[0-9]{2})?(\\.[0-9]+)?$'
  -- AND r.value IS NULL
  -- AND TRIM(r.value) = ''
  -- AND tt.id = <tournament_template_id>
ORDER BY
    tt.name,
    t.name,
    ts.name,
    e.id,
    ep.id,
    r.id;


SELECT
    -- CheckID - GLOBAL-DISCOVERY-028
    -- Name - STATISTIC_DATA_VALUE_PATTERNS_SUMMARY
    -- What it does: Classifies statistic-data values by shape for one confirmed type, owner level and physical shard in the selected sport.
    sd.statistic_data_typeFK AS statistic_data_type_id,
    sdt.name AS statistic_data_type_name,
    CASE
        WHEN sd.value IS NULL THEN 'null'
        WHEN TRIM(sd.value) = '' THEN 'empty'
        WHEN sd.value REGEXP '^[+-]?[0-9]+$' THEN 'integer'
        WHEN sd.value REGEXP '^[+-]?[0-9]+\\.[0-9]+$' THEN 'decimal'
        WHEN sd.value REGEXP '^[+-]?[0-9]{1,3}:[0-9]{2}(:[0-9]{2})?(\\.[0-9]+)?$' THEN 'time_format'
        ELSE 'text_or_other'
    END AS value_shape,
    COUNT(DISTINCT sd.id) AS value_count,
    COUNT(DISTINCT st.id) AS statistic_count,
    MIN(sd.value) AS sample_value
FROM statistic_data{{SHARD_ID}} sd
JOIN statistic_participants{{SHARD_ID}} sp
  ON sp.id = sd.statistic_participants{{SHARD_ID}}FK
 AND sp.del = 'no'
JOIN statistic st
  ON st.id = sp.statisticFK
 AND st.del = 'no'
LEFT JOIN statistic_data_type sdt
  ON sdt.id = sd.statistic_data_typeFK
LEFT JOIN sport sport_owner
  ON st.object_typeFK = 1
 AND sport_owner.id = st.objectFK
 AND sport_owner.del = 'no'
LEFT JOIN tournament_template tt2
  ON st.object_typeFK = 2
 AND tt2.id = st.objectFK
 AND tt2.del = 'no'
LEFT JOIN tournament t3
  ON st.object_typeFK = 3
 AND t3.id = st.objectFK
 AND t3.del = 'no'
LEFT JOIN tournament_template tt3
  ON tt3.id = t3.tournament_templateFK
 AND tt3.del = 'no'
LEFT JOIN tournament_stage ts4
  ON st.object_typeFK = 4
 AND ts4.id = st.objectFK
 AND ts4.del = 'no'
LEFT JOIN tournament t4
  ON t4.id = ts4.tournamentFK
 AND t4.del = 'no'
LEFT JOIN tournament_template tt4
  ON tt4.id = t4.tournament_templateFK
 AND tt4.del = 'no'
LEFT JOIN event e5
  ON st.object_typeFK = 5
 AND e5.id = st.objectFK
 AND e5.del = 'no'
LEFT JOIN tournament_stage ts5
  ON ts5.id = e5.tournament_stageFK
 AND ts5.del = 'no'
LEFT JOIN tournament t5
  ON t5.id = ts5.tournamentFK
 AND t5.del = 'no'
LEFT JOIN tournament_template tt5
  ON tt5.id = t5.tournament_templateFK
 AND tt5.del = 'no'
LEFT JOIN event_participants ep6
  ON st.object_typeFK = 6
 AND ep6.id = st.objectFK
 AND ep6.del = 'no'
LEFT JOIN event e6
  ON e6.id = ep6.eventFK
 AND e6.del = 'no'
LEFT JOIN tournament_stage ts6
  ON ts6.id = e6.tournament_stageFK
 AND ts6.del = 'no'
LEFT JOIN tournament t6
  ON t6.id = ts6.tournamentFK
 AND t6.del = 'no'
LEFT JOIN tournament_template tt6
  ON tt6.id = t6.tournament_templateFK
 AND tt6.del = 'no'
LEFT JOIN participant p15
  ON st.object_typeFK = 15
 AND p15.id = st.objectFK
 AND p15.del = 'no'
LEFT JOIN object_participants op15
  ON op15.object = 'sport'
 AND op15.participantFK = p15.id
 AND op15.del = 'no'
WHERE sd.del = 'no'
  AND st.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND st.object_typeFK = {{STATISTIC_OWNER_TYPE_ID}}
  AND (
      sport_owner.id = {{SPORT_ID}}
      OR tt2.sportFK = {{SPORT_ID}}
      OR tt3.sportFK = {{SPORT_ID}}
      OR tt4.sportFK = {{SPORT_ID}}
      OR tt5.sportFK = {{SPORT_ID}}
      OR tt6.sportFK = {{SPORT_ID}}
      OR op15.objectFK = {{SPORT_ID}}
  )
GROUP BY
    sd.statistic_data_typeFK,
    sdt.name,
    value_shape
ORDER BY
    sd.statistic_data_typeFK,
    value_count DESC;


SELECT
    -- CheckID - GLOBAL-DISCOVERY-029
    -- Name - STATISTIC_DATA_VALUE_PATTERNS_DETAIL
    -- What it does: Lists statistic-data rows for one data type selected from the corresponding GLOBAL summary query.
    sd.id AS statistic_data_id,
    sd.statistic_data_typeFK AS statistic_data_type_id,
    sdt.name AS statistic_data_type_name,
    sd.statistic_data_type_detailFK,
    sd.value,
    sp.id AS statistic_participant_id,
    sp.participantFK AS participant_id,
    st.id AS statistic_id,
    st.name AS statistic_name,
    st.statistic_typeFK AS statistic_type_id,
    st.object_typeFK AS statistic_owner_type_id,
    st.objectFK AS statistic_owner_id
FROM statistic_data{{SHARD_ID}} sd
JOIN statistic_participants{{SHARD_ID}} sp
  ON sp.id = sd.statistic_participants{{SHARD_ID}}FK
 AND sp.del = 'no'
JOIN statistic st
  ON st.id = sp.statisticFK
 AND st.del = 'no'
LEFT JOIN statistic_data_type sdt
  ON sdt.id = sd.statistic_data_typeFK
LEFT JOIN sport sport_owner
  ON st.object_typeFK = 1
 AND sport_owner.id = st.objectFK
 AND sport_owner.del = 'no'
LEFT JOIN tournament_template tt2
  ON st.object_typeFK = 2
 AND tt2.id = st.objectFK
 AND tt2.del = 'no'
LEFT JOIN tournament t3
  ON st.object_typeFK = 3
 AND t3.id = st.objectFK
 AND t3.del = 'no'
LEFT JOIN tournament_template tt3
  ON tt3.id = t3.tournament_templateFK
 AND tt3.del = 'no'
LEFT JOIN tournament_stage ts4
  ON st.object_typeFK = 4
 AND ts4.id = st.objectFK
 AND ts4.del = 'no'
LEFT JOIN tournament t4
  ON t4.id = ts4.tournamentFK
 AND t4.del = 'no'
LEFT JOIN tournament_template tt4
  ON tt4.id = t4.tournament_templateFK
 AND tt4.del = 'no'
LEFT JOIN event e5
  ON st.object_typeFK = 5
 AND e5.id = st.objectFK
 AND e5.del = 'no'
LEFT JOIN tournament_stage ts5
  ON ts5.id = e5.tournament_stageFK
 AND ts5.del = 'no'
LEFT JOIN tournament t5
  ON t5.id = ts5.tournamentFK
 AND t5.del = 'no'
LEFT JOIN tournament_template tt5
  ON tt5.id = t5.tournament_templateFK
 AND tt5.del = 'no'
LEFT JOIN event_participants ep6
  ON st.object_typeFK = 6
 AND ep6.id = st.objectFK
 AND ep6.del = 'no'
LEFT JOIN event e6
  ON e6.id = ep6.eventFK
 AND e6.del = 'no'
LEFT JOIN tournament_stage ts6
  ON ts6.id = e6.tournament_stageFK
 AND ts6.del = 'no'
LEFT JOIN tournament t6
  ON t6.id = ts6.tournamentFK
 AND t6.del = 'no'
LEFT JOIN tournament_template tt6
  ON tt6.id = t6.tournament_templateFK
 AND tt6.del = 'no'
LEFT JOIN participant p15
  ON st.object_typeFK = 15
 AND p15.id = st.objectFK
 AND p15.del = 'no'
LEFT JOIN object_participants op15
  ON op15.object = 'sport'
 AND op15.participantFK = p15.id
 AND op15.del = 'no'
WHERE sd.del = 'no'
  AND st.statistic_typeFK = {{STATISTIC_TYPE_ID}}
  AND st.object_typeFK = {{STATISTIC_OWNER_TYPE_ID}}
  AND sd.statistic_data_typeFK = {{STATISTIC_DATA_TYPE_ID}}
  AND (
      sport_owner.id = {{SPORT_ID}}
      OR tt2.sportFK = {{SPORT_ID}}
      OR tt3.sportFK = {{SPORT_ID}}
      OR tt4.sportFK = {{SPORT_ID}}
      OR tt5.sportFK = {{SPORT_ID}}
      OR tt6.sportFK = {{SPORT_ID}}
      OR op15.objectFK = {{SPORT_ID}}
  )
  -- Optional: uncomment one value-shape filter.
  -- AND sd.value REGEXP '^[+-]?[0-9]+$'
  -- AND sd.value REGEXP '^[+-]?[0-9]+\\.[0-9]+$'
  -- AND sd.value REGEXP '^[+-]?[0-9]{1,3}:[0-9]{2}(:[0-9]{2})?(\\.[0-9]+)?$'
  -- AND sd.value IS NULL
  -- AND TRIM(sd.value) = ''
ORDER BY
    st.id,
    sp.id,
    sd.id;
