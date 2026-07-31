SELECT
    -- CheckID - BMX-DQ-026
    -- Name - EVENT_RESULTS_MISSING_MEDAL_FOR_FINAL
    -- What it does: Finds active, finished BMX events with round_typeFK=173 (Final) where at least one of gold/silver/bronze Medal (result_typeFK=501) values is absent among event participants, distinguishing events with no medals at all from events missing only specific medal type(s), together with a coverage count of all eligible Final-round finished BMX events.
    CASE WHEN x.total_medal_count = 0 THEN 'No_Medals_At_All' ELSE 'Missing_Specific_Medal' END AS check_type,
    x.event_id,
    x.event_name,
    x.template_name,
    x.tournament_name,
    x.stage_name,
    CONCAT_WS(', ',
        IF(x.gold_count = 0, 'gold', NULL),
        IF(x.silver_count = 0, 'silver', NULL),
        IF(x.bronze_count = 0, 'bronze', NULL)
    ) AS missing_medals,
    NULL AS eligible_count
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        ts.name AS stage_name,
        SUM(CASE WHEN LOWER(TRIM(r.value)) = 'gold' THEN 1 ELSE 0 END) AS gold_count,
        SUM(CASE WHEN LOWER(TRIM(r.value)) = 'silver' THEN 1 ELSE 0 END) AS silver_count,
        SUM(CASE WHEN LOWER(TRIM(r.value)) = 'bronze' THEN 1 ELSE 0 END) AS bronze_count,
        SUM(CASE WHEN r.value IS NOT NULL AND TRIM(r.value) <> '' THEN 1 ELSE 0 END) AS total_medal_count
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    LEFT JOIN result r
      ON r.event_participantsFK = ep.id
     AND r.del = 'no'
     AND r.result_typeFK = 501
    WHERE e.del = 'no'
      AND tt.sportFK = 58
      AND e.round_typeFK = 173
      AND e.status_type = 'finished'
      AND e.status_descFK = 6
      -- AND tt.id = <tournament_template_id>
    GROUP BY e.id, e.name, tt.name, t.name, ts.name
) x
WHERE x.gold_count = 0 OR x.silver_count = 0 OR x.bronze_count = 0

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = 58
  AND e.round_typeFK = 173
  AND e.status_type = 'finished'
  AND e.status_descFK = 6
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - BMX-DQ-028
    -- Name - EVENT_SETTINGS_MISSING_MEDAL_RELATED_FOR_FINAL
    -- What it does: Finds active, finished BMX events with round_typeFK=173 (Final) that have no active event property named medal_related with value yes, with template, tournament and stage name context, together with a coverage count of all eligible Final-round finished BMX events.
    'Missing_Medal_Related_Property' AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    ts.name AS stage_name,
    NULL AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = 58
  AND e.round_typeFK = 173
  AND e.status_type = 'finished'
  AND e.status_descFK = 6
  -- AND tt.id = <tournament_template_id>
  AND NOT EXISTS (
      SELECT 1
      FROM property p
      WHERE p.object = 'event'
        AND p.objectFK = e.id
        AND p.del = 'no'
        AND LOWER(TRIM(p.name)) = 'medal_related'
        AND LOWER(TRIM(p.value)) = 'yes'
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = 58
  AND e.round_typeFK = 173
  AND e.status_type = 'finished'
  AND e.status_descFK = 6
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - BMX-DQ-029
    -- Name - EVENT_RESULTS_UNEXPECTED_MEDAL_FOR_NON_FINAL
    -- What it does: Finds active, finished BMX events with round_typeFK other than 173 (Final) that have at least one active, non-empty Medal (result_typeFK=501) result row for any event participant, with template, tournament, stage name and round-type context, together with a coverage count of all eligible non-Final finished BMX events.
    'Unexpected_Medal_For_Non_Final' AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    ts.name AS stage_name,
    e.round_typeFK AS round_type_id,
    rt.name AS round_type_name,
    NULL AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
LEFT JOIN round_type rt ON rt.id = e.round_typeFK
WHERE e.del = 'no'
  AND tt.sportFK = 58
  AND (e.round_typeFK IS NULL OR e.round_typeFK <> 173)
  AND e.status_type = 'finished'
  AND e.status_descFK = 6
  -- AND tt.id = <tournament_template_id>
  AND EXISTS (
      SELECT 1
      FROM event_participants ep
      JOIN result r ON r.event_participantsFK = ep.id
        AND r.del = 'no'
        AND r.result_typeFK = 501
        AND r.value IS NOT NULL
        AND TRIM(r.value) <> ''
      WHERE ep.eventFK = e.id
        AND ep.del = 'no'
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = 58
  AND (e.round_typeFK IS NULL OR e.round_typeFK <> 173)
  AND e.status_type = 'finished'
  AND e.status_descFK = 6
  -- AND tt.id = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - BMX-DQ-030
    -- Name - EVENT_DURATION_FORMAT_MISMATCH_TO_RANK
    -- What it does: Finds active BMX events containing at least one participant whose duration result format does not match the expected shape for their rank result (rank 1 must be a plain full time with no plus sign; every other rank must be a plus-prefixed gap value with no colon), together with the count, type and per-participant detail of mismatching values per event and a coverage count of all eligible BMX events with at least one participant having both an active rank and an active duration result.
    'Duration_Format_Mismatch_Events' AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    COUNT(DISTINCT ep.id) AS mismatching_participants_count,
    GROUP_CONCAT(DISTINCT
        CASE
            WHEN TRIM(rk.value) = '1' AND TRIM(dur.value) REGEXP '^\\+' THEN 'RANK1_HAS_PLUS'
            WHEN TRIM(rk.value) = '1' THEN 'RANK1_WRONG_FORMAT'
            WHEN TRIM(rk.value) <> '1' AND TRIM(dur.value) NOT REGEXP '^\\+' THEN 'NON_RANK1_MISSING_PLUS'
            ELSE 'NON_RANK1_WRONG_FORMAT'
        END
        ORDER BY 1 SEPARATOR ', '
    ) AS mismatch_types,
    GROUP_CONCAT(
        CONCAT(
            'rank=', TRIM(rk.value),
            ' value=''', TRIM(dur.value), '''',
            ' reason=',
            CASE
                WHEN TRIM(rk.value) = '1' AND TRIM(dur.value) REGEXP '^\\+' THEN 'rank 1 stored with leading + (should be plain full time)'
                WHEN TRIM(rk.value) = '1' THEN 'rank 1 value is not a plain numeric/mm:ss full time'
                WHEN TRIM(rk.value) <> '1' AND TRIM(dur.value) NOT REGEXP '^\\+' THEN 'stored as absolute time instead of a + gap value'
                ELSE 'value has + but wrong shape (colon or trailing +)'
            END
        )
        ORDER BY CAST(TRIM(rk.value) AS UNSIGNED)
        SEPARATOR ' | '
    ) AS mismatch_details,
    NULL AS eligible_count
FROM event_participants ep
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN result rk ON rk.event_participantsFK = ep.id AND rk.result_typeFK = 100 AND rk.del = 'no'
JOIN result dur ON dur.event_participantsFK = ep.id AND dur.result_typeFK = 101 AND dur.del = 'no'
WHERE ep.del = 'no'
  AND tt.sportFK = 58
  -- AND tt.id = <tournament_template_id>
  AND TRIM(rk.value) <> ''
  AND TRIM(dur.value) <> ''
  AND (
      (TRIM(rk.value) = '1' AND TRIM(dur.value) NOT REGEXP '^[0-9]+(:[0-9]+)?\\.[0-9]+$')
      OR
      (TRIM(rk.value) <> '1' AND TRIM(dur.value) NOT REGEXP '^\\+[0-9]+\\.[0-9]+$')
  )
GROUP BY e.id, e.name, e.startdate

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count
FROM event_participants ep
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN result rk ON rk.event_participantsFK = ep.id AND rk.result_typeFK = 100 AND rk.del = 'no'
JOIN result dur ON dur.event_participantsFK = ep.id AND dur.result_typeFK = 101 AND dur.del = 'no'
WHERE ep.del = 'no'
  AND tt.sportFK = 58
  -- AND tt.id = <tournament_template_id>
  AND TRIM(rk.value) <> ''
  AND TRIM(dur.value) <> ''
;
