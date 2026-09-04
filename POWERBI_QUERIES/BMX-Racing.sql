SELECT
    -- CheckID - BMX-DQ-030
    -- Name - EVENT_DURATION_FORMAT_MISMATCH_TO_RANK
    -- What it does: Flags Duration values that break this rule: rank 1 has the full time, and lower ranks have a plus-prefixed gap with no colon.
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
-- What it does, stated in full: Finds events where a participant's duration breaks the
-- leader/gap convention: rank 1 a plain full time, every other rank a plus-prefixed gap with
-- no colon.
FROM event_participants ep
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN result rk ON rk.event_participantsFK = ep.id AND rk.result_typeFK = 100 AND rk.del = 'no'
JOIN result dur ON dur.event_participantsFK = ep.id AND dur.result_typeFK = 101 AND dur.del = 'no'
WHERE ep.del = 'no'
  AND tt.sportFK = 58
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
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
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND TRIM(rk.value) <> ''
  AND TRIM(dur.value) <> ''
;
