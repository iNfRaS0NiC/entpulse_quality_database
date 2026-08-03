SELECT
    -- CheckID - GLOBAL-DQ-017
    -- Name - EVENT_RESULTS_MISSING_FOR_FINISHED
    -- What it does: Finds active events with status_type='finished' (status_descFK=6) where none of their event participants has an active, non-empty result row, with template, tournament, stage name and status context, together with a coverage count of all eligible finished events.
    'Missing_Results_For_Finished' AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    ts.name AS stage_name,
    e.status_type,
    e.status_descFK,
    NULL AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND e.status_type = 'finished'
  AND e.status_descFK = 6
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND NOT EXISTS (
      SELECT 1
      FROM event_participants ep
      JOIN result r ON r.event_participantsFK = ep.id
        AND r.del = 'no'
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
  AND tt.sportFK = {{SPORT_ID}}
  AND e.status_type = 'finished'
  AND e.status_descFK = 6
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-018
    -- Name - EVENT_RESULTS_MEDAL_INVALID_VALUE
    -- What it does: Finds active event-participant rows with an active, non-empty Medal result value that is not gold, silver or bronze, together with a coverage count of all eligible event-participants with an active, non-empty Medal value.
    'Medal_Invalid_Value' AS check_type,
    ep.id AS event_participants_id,
    e.id AS event_id,
    e.name AS event_name,
    p.name AS participant_name,
    r.value AS medal_value,
    NULL AS eligible_count
FROM event_participants ep
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
JOIN result r ON r.event_participantsFK = ep.id AND r.result_typeFK = {{RESULT_MEDAL_TYPE_ID}} AND r.del = 'no'
WHERE ep.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND r.value IS NOT NULL
  AND TRIM(r.value) <> ''
  AND LOWER(TRIM(r.value)) NOT IN ('gold', 'silver', 'bronze')

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ep.id) AS eligible_count
FROM event_participants ep
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN result r ON r.event_participantsFK = ep.id AND r.result_typeFK = {{RESULT_MEDAL_TYPE_ID}} AND r.del = 'no'
WHERE ep.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND r.value IS NOT NULL
  AND TRIM(r.value) <> ''
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-019
    -- Name - EVENT_DURATION_FORMAT_MISMATCH_TO_RANK
    -- What it does: Finds active events containing at least one participant whose duration result does not follow the leader/gap convention for their rank result (rank 1 must be a plain absolute time with no plus sign; every other rank must be a plus-prefixed gap value), together with the count, type and per-participant detail of mismatching values per event and a coverage count of all eligible events with at least one participant having both an active rank and an active duration result.
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
                WHEN TRIM(rk.value) = '1' AND TRIM(dur.value) REGEXP '^\\+' THEN 'rank 1 stored with leading + (should be a plain absolute time)'
                WHEN TRIM(rk.value) = '1' THEN 'rank 1 value is not a plain absolute time'
                WHEN TRIM(rk.value) <> '1' AND TRIM(dur.value) NOT REGEXP '^\\+' THEN 'stored as absolute time instead of a + gap value'
                ELSE 'value has + but wrong shape'
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
JOIN result rk ON rk.event_participantsFK = ep.id AND rk.result_typeFK = {{RESULT_RANK_TYPE_ID}} AND rk.del = 'no'
JOIN result dur ON dur.event_participantsFK = ep.id AND dur.result_typeFK = {{RESULT_DURATION_TYPE_ID}} AND dur.del = 'no'
WHERE ep.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND TRIM(rk.value) <> ''
  AND TRIM(dur.value) <> ''
  AND (
      (TRIM(rk.value) = '1' AND TRIM(dur.value) NOT REGEXP '^[0-9]+(:[0-9]+)*(\\.[0-9]+)?$')
      OR
      (TRIM(rk.value) <> '1' AND TRIM(dur.value) NOT REGEXP '^\\+[0-9]+(:[0-9]+)*(\\.[0-9]+)?$')
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
JOIN result rk ON rk.event_participantsFK = ep.id AND rk.result_typeFK = {{RESULT_RANK_TYPE_ID}} AND rk.del = 'no'
JOIN result dur ON dur.event_participantsFK = ep.id AND dur.result_typeFK = {{RESULT_DURATION_TYPE_ID}} AND dur.del = 'no'
WHERE ep.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND TRIM(rk.value) <> ''
  AND TRIM(dur.value) <> ''
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-020
    -- Name - EVENT_RESULTS_RANK_OUTLIER_ABOVE_FIELD_SIZE
    -- What it does: Finds active event-participant rows in finished events whose numeric Rank exceeds the event's active participant count and is disconnected from the next lower Rank in the same event, while carrying no active Comment value that would mark a non-finishing participant, with template and event name context, together with a coverage count of all eligible event-participants holding an active numeric Rank in a finished event.
    'RANK_OUTLIER_ABOVE_FIELD_SIZE' AS check_type,
    y.event_participants_id,
    y.event_id,
    y.event_name,
    y.template_name,
    y.participant_name,
    y.rank_value,
    y.participant_count,
    y.next_lower_rank,
    NULL AS eligible_count
FROM (
    SELECT
        x.event_participants_id,
        x.event_id,
        x.event_name,
        x.template_name,
        x.participant_name,
        x.rank_value,
        x.participant_count,
        (
            SELECT MAX(CAST(r2.value AS UNSIGNED))
            FROM event_participants ep3
            JOIN result r2 ON r2.event_participantsFK = ep3.id
                 AND r2.result_typeFK = {{RESULT_RANK_TYPE_ID}}
                 AND r2.del = 'no'
                 AND r2.value REGEXP '^[1-9][0-9]*$'
            WHERE ep3.eventFK = x.event_id
              AND ep3.del = 'no'
              AND CAST(r2.value AS UNSIGNED) < x.rank_value
        ) AS next_lower_rank
    FROM (
        SELECT
            ep.id AS event_participants_id,
            e.id AS event_id,
            e.name AS event_name,
            tt.name AS template_name,
            p.name AS participant_name,
            CAST(r.value AS UNSIGNED) AS rank_value,
            (
                SELECT COUNT(*)
                FROM event_participants ep2
                WHERE ep2.eventFK = e.id
                  AND ep2.del = 'no'
            ) AS participant_count
        FROM event_participants ep
        JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
        JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
        JOIN result r ON r.event_participantsFK = ep.id
             AND r.result_typeFK = {{RESULT_RANK_TYPE_ID}}
             AND r.del = 'no'
             AND r.value REGEXP '^[1-9][0-9]*$'
        WHERE ep.del = 'no'
          AND tt.sportFK = {{SPORT_ID}}
          AND e.status_type = 'finished'
          AND e.status_descFK = 6
          -- AND tt.id = <tournament_template_id>
          -- AND e.startdate >= '<from_datetime>'
          -- AND e.startdate <  '<to_datetime>'
          AND NOT EXISTS (
              SELECT 1
              FROM result rc
              WHERE rc.event_participantsFK = ep.id
                AND rc.result_typeFK = {{RESULT_COMMENT_TYPE_ID}}
                AND rc.del = 'no'
                AND rc.value IS NOT NULL
                AND TRIM(rc.value) <> ''
          )
    ) x
    WHERE x.rank_value > x.participant_count
) y
WHERE y.next_lower_rank IS NULL
   OR y.rank_value > y.next_lower_rank + 1

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ep.id) AS eligible_count
FROM event_participants ep
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN result r ON r.event_participantsFK = ep.id
     AND r.result_typeFK = {{RESULT_RANK_TYPE_ID}}
     AND r.del = 'no'
     AND r.value REGEXP '^[1-9][0-9]*$'
WHERE ep.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND e.status_type = 'finished'
  AND e.status_descFK = 6
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-021
    -- Name - EVENT_RESULTS_RANK_DUPLICATE_WITHOUT_COMMENT
    -- What it does: Finds active event-participant rows in finished events sharing one numeric Rank value with at least one other participant of the same event where neither row carries an active Comment value, so the shared rank is not explained by a non-finishing sentinel convention, with template and event name context and the count of participants sharing that rank unexplained, together with a coverage count of all eligible event-participants holding an active numeric Rank in a finished event.
    'RANK_DUPLICATE_WITHOUT_COMMENT' AS check_type,
    ep.id AS event_participants_id,
    e.id AS event_id,
    e.name AS event_name,
    tt.name AS template_name,
    p.name AS participant_name,
    CAST(r.value AS UNSIGNED) AS rank_value,
    (
        SELECT COUNT(DISTINCT ep2.id)
        FROM event_participants ep2
        JOIN result r2 ON r2.event_participantsFK = ep2.id
             AND r2.result_typeFK = {{RESULT_RANK_TYPE_ID}}
             AND r2.del = 'no'
             AND r2.value REGEXP '^[1-9][0-9]*$'
        WHERE ep2.eventFK = e.id
          AND ep2.del = 'no'
          AND CAST(r2.value AS UNSIGNED) = CAST(r.value AS UNSIGNED)
          AND NOT EXISTS (
              SELECT 1
              FROM result rc2
              WHERE rc2.event_participantsFK = ep2.id
                AND rc2.result_typeFK = {{RESULT_COMMENT_TYPE_ID}}
                AND rc2.del = 'no'
                AND rc2.value IS NOT NULL
                AND TRIM(rc2.value) <> ''
          )
    ) AS unexplained_duplicate_count,
    NULL AS eligible_count
FROM event_participants ep
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
JOIN result r ON r.event_participantsFK = ep.id
     AND r.result_typeFK = {{RESULT_RANK_TYPE_ID}}
     AND r.del = 'no'
     AND r.value REGEXP '^[1-9][0-9]*$'
WHERE ep.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND e.status_type = 'finished'
  AND e.status_descFK = 6
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND NOT EXISTS (
      SELECT 1
      FROM result rc
      WHERE rc.event_participantsFK = ep.id
        AND rc.result_typeFK = {{RESULT_COMMENT_TYPE_ID}}
        AND rc.del = 'no'
        AND rc.value IS NOT NULL
        AND TRIM(rc.value) <> ''
  )
  AND EXISTS (
      SELECT 1
      FROM event_participants ep3
      JOIN result r3 ON r3.event_participantsFK = ep3.id
           AND r3.result_typeFK = {{RESULT_RANK_TYPE_ID}}
           AND r3.del = 'no'
           AND r3.value REGEXP '^[1-9][0-9]*$'
      WHERE ep3.eventFK = e.id
        AND ep3.del = 'no'
        AND ep3.id <> ep.id
        AND CAST(r3.value AS UNSIGNED) = CAST(r.value AS UNSIGNED)
        AND NOT EXISTS (
            SELECT 1
            FROM result rc3
            WHERE rc3.event_participantsFK = ep3.id
              AND rc3.result_typeFK = {{RESULT_COMMENT_TYPE_ID}}
              AND rc3.del = 'no'
              AND rc3.value IS NOT NULL
              AND TRIM(rc3.value) <> ''
        )
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ep.id) AS eligible_count
FROM event_participants ep
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN result r ON r.event_participantsFK = ep.id
     AND r.result_typeFK = {{RESULT_RANK_TYPE_ID}}
     AND r.del = 'no'
     AND r.value REGEXP '^[1-9][0-9]*$'
WHERE ep.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND e.status_type = 'finished'
  AND e.status_descFK = 6
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-036
    -- Name - EVENT_RESULTS_RANK_INVALID_OR_MISSING
    -- What it does: Finds active event-participant rows in finished events where the Rank value is not a plain positive integer up to the sport's plausible maximum (non-integer, negative, text, or above the maximum), or where Rank is missing and no active Comment value exists either, separating participants that hold no active result row of any type from those that hold some other result, together with a coverage count of all eligible event-participants in finished events.
    CASE
        WHEN r_rank_value IS NOT NULL AND r_rank_value NOT REGEXP '^[1-9][0-9]*$' THEN 'RANK_NOT_INTEGER'
        WHEN r_rank_value IS NOT NULL AND r_rank_value REGEXP '^[1-9][0-9]*$' AND CAST(r_rank_value AS UNSIGNED) > {{RANK_MAX_PLAUSIBLE}} THEN 'RANK_OVER_MAX'
        WHEN r_rank_value IS NULL AND r_comment_value IS NULL AND x.has_any_result = 0 THEN 'NO_RESULT_OF_ANY_TYPE'
        WHEN r_rank_value IS NULL AND r_comment_value IS NULL THEN 'RANK_AND_COMMENT_MISSING_OTHER_RESULT_PRESENT'
    END AS check_type,
    x.event_participants_id,
    x.event_id,
    x.event_name,
    x.participant_name,
    x.r_rank_value AS rank_value,
    x.r_comment_value AS comment_value,
    NULL AS eligible_count
FROM (
    SELECT
        ep.id AS event_participants_id,
        e.id AS event_id,
        e.name AS event_name,
        p.name AS participant_name,
        (
            SELECT r1.value
            FROM result r1
            WHERE r1.event_participantsFK = ep.id
              AND r1.result_typeFK = {{RESULT_RANK_TYPE_ID}}
              AND r1.del = 'no'
              AND r1.value IS NOT NULL
              AND TRIM(r1.value) <> ''
            LIMIT 1
        ) AS r_rank_value,
        (
            SELECT r2.value
            FROM result r2
            WHERE r2.event_participantsFK = ep.id
              AND r2.result_typeFK = {{RESULT_COMMENT_TYPE_ID}}
              AND r2.del = 'no'
              AND r2.value IS NOT NULL
              AND TRIM(r2.value) <> ''
            LIMIT 1
        ) AS r_comment_value,
        EXISTS (
            SELECT 1
            FROM result r3
            WHERE r3.event_participantsFK = ep.id
              AND r3.del = 'no'
              AND r3.value IS NOT NULL
              AND TRIM(r3.value) <> ''
        ) AS has_any_result
    FROM event_participants ep
    JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
    WHERE ep.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      AND e.status_type = 'finished'
      AND e.status_descFK = 6
      -- AND tt.id = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
) x
WHERE
    (x.r_rank_value IS NOT NULL AND x.r_rank_value NOT REGEXP '^[1-9][0-9]*$')
    OR (x.r_rank_value IS NOT NULL AND x.r_rank_value REGEXP '^[1-9][0-9]*$' AND CAST(x.r_rank_value AS UNSIGNED) > {{RANK_MAX_PLAUSIBLE}})
    OR (x.r_rank_value IS NULL AND x.r_comment_value IS NULL)

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ep.id) AS eligible_count
FROM event_participants ep
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE ep.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND e.status_type = 'finished'
  AND e.status_descFK = 6
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-037
    -- Name - EVENT_RESULTS_MEDAL_SET_INVALID_FOR_FINAL
    -- What it does: Finds active, finished events on a Final round type whose set of Medal result values is not one gold, one silver and one bronze, because a medal type is absent among event participants or because one is awarded more than once, separating an event with no medals at all, a duplicate contradicted by the place below it, a duplicate shaped like a tie, a duplicated bronze and a missing medal type, together with a coverage count of all eligible Final-round finished events.
    CASE
        WHEN x.total_medal_count = 0 THEN 'No_Medals_At_All'
        -- A shared place removes the place below it, so a second gold beside a silver is a
        -- contradiction, while a second gold without one is the shape a tie actually takes.
        WHEN x.gold_count > 1 AND x.silver_count > 0 THEN 'Duplicate_Gold_With_Silver_Present'
        WHEN x.silver_count > 1 AND x.bronze_count > 0 THEN 'Duplicate_Silver_With_Bronze_Present'
        WHEN x.gold_count > 1 OR x.silver_count > 1 THEN 'Duplicate_Medal_Tie_Shape'
        WHEN x.bronze_count > 1 THEN 'Duplicate_Bronze'
        ELSE 'Missing_Specific_Medal'
    END AS check_type,
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
    CONCAT_WS(', ',
        IF(x.gold_count > 1, CONCAT('gold x', x.gold_count), NULL),
        IF(x.silver_count > 1, CONCAT('silver x', x.silver_count), NULL),
        IF(x.bronze_count > 1, CONCAT('bronze x', x.bronze_count), NULL)
    ) AS duplicated_medals,
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
     AND r.result_typeFK = {{RESULT_MEDAL_TYPE_ID}}
    WHERE e.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      AND e.round_typeFK IN ({{FINAL_ROUND_TYPE_LIST}})
      AND e.status_type = 'finished'
      -- AND tt.id = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY e.id, e.name, tt.name, t.name, ts.name
) x
WHERE x.gold_count = 0 OR x.silver_count = 0 OR x.bronze_count = 0
   OR x.gold_count > 1 OR x.silver_count > 1 OR x.bronze_count > 1

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
  AND tt.sportFK = {{SPORT_ID}}
  AND e.round_typeFK IN ({{FINAL_ROUND_TYPE_LIST}})
  AND e.status_type = 'finished'
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-039
    -- Name - EVENT_RESULTS_UNEXPECTED_MEDAL_FOR_NON_MEDAL_ROUND
    -- What it does: Finds active, finished events whose round type is none of the sport's medal round types that have at least one active, non-empty Medal result row for any event participant, with template, tournament, stage name and round-type context, together with a coverage count of all eligible non-medal-round finished events.
    'Unexpected_Medal_For_Non_Medal_Round' AS check_type,
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
  AND tt.sportFK = {{SPORT_ID}}
  AND (e.round_typeFK IS NULL OR e.round_typeFK NOT IN ({{MEDAL_ROUND_TYPE_LIST}}))
  AND e.status_type = 'finished'
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND EXISTS (
      SELECT 1
      FROM event_participants ep
      JOIN result r ON r.event_participantsFK = ep.id
        AND r.del = 'no'
        AND r.result_typeFK = {{RESULT_MEDAL_TYPE_ID}}
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
  AND tt.sportFK = {{SPORT_ID}}
  AND (e.round_typeFK IS NULL OR e.round_typeFK NOT IN ({{MEDAL_ROUND_TYPE_LIST}}))
  AND e.status_type = 'finished'
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-045
    -- Name - EVENT_DURATION_FULL_TIME_MISMATCH_TO_RANK
    -- What it does: Finds active finished events in the sport's timed disciplines containing at least one participant whose full-time duration result is missing despite an active Rank, present without an active Rank, present with an invalid time format, or present as a zero time, together with the count and type of mismatching participants per event and a coverage count of all eligible events.
    'Duration_Full_Time_Mismatch_Events' AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    COUNT(*) AS mismatching_participants_count,
    GROUP_CONCAT(DISTINCT x.violation_type ORDER BY x.violation_type SEPARATOR ', ') AS violation_types,
    NULL AS eligible_count,
    0 AS sort_order
FROM (
    SELECT
        ep.id AS event_participants_id,
        ep.eventFK AS event_id,
        CASE
            WHEN COUNT(DISTINCT rk.id) > 0 AND COUNT(DISTINCT dft.id) = 0 THEN 'RANK_PRESENT_DURATION_FULL_TIME_MISSING'
            WHEN COUNT(DISTINCT rk.id) = 0 AND COUNT(DISTINCT dft.id) > 0 THEN 'DURATION_FULL_TIME_PRESENT_WITHOUT_RANK'
            WHEN COUNT(DISTINCT rk.id) > 0 AND COUNT(DISTINCT dft.id) > 0
                 AND MAX(dft.value) NOT REGEXP '^[0-9]+(:[0-9]+)*(\\.[0-9]+)?$' THEN 'DURATION_FULL_TIME_INVALID_FORMAT'
            -- A negative value already fails the shape test above. A zero time passes it,
            -- so '0', '0:00' and '00:00.00' are only reachable by asking separately.
            WHEN COUNT(DISTINCT rk.id) > 0 AND COUNT(DISTINCT dft.id) > 0
                 AND MAX(dft.value) NOT REGEXP '[1-9]' THEN 'DURATION_FULL_TIME_NON_POSITIVE'
        END AS violation_type
    FROM event_participants ep
    JOIN event e2 ON e2.id = ep.eventFK AND e2.del = 'no'
    JOIN tournament_stage ts ON ts.id = e2.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    LEFT JOIN result rk
      ON rk.event_participantsFK = ep.id AND rk.result_typeFK = {{RESULT_RANK_TYPE_ID}} AND rk.del = 'no'
     AND rk.value IS NOT NULL AND TRIM(rk.value) <> ''
    LEFT JOIN result dft
      ON dft.event_participantsFK = ep.id AND dft.result_typeFK = {{RESULT_FULL_TIME_TYPE_ID}} AND dft.del = 'no'
     AND dft.value IS NOT NULL AND TRIM(dft.value) <> ''
    WHERE ep.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      AND e2.status_type = 'finished'
      AND e2.status_descFK = 6
      -- AND tt.id = <tournament_template_id>
      -- AND e2.startdate >= '<from_datetime>'
      -- AND e2.startdate <  '<to_datetime>'
      AND EXISTS (
          SELECT 1 FROM object_discipline od
          WHERE od.object_typeFK = 5 AND od.objectFK = e2.id
            AND od.disciplineFK IN ({{TIMED_DISCIPLINE_LIST}}) AND od.del = 'no'
      )
    GROUP BY ep.id, ep.eventFK
    HAVING
        (COUNT(DISTINCT rk.id) > 0 AND COUNT(DISTINCT dft.id) = 0)
        OR (COUNT(DISTINCT rk.id) = 0 AND COUNT(DISTINCT dft.id) > 0)
        OR (COUNT(DISTINCT rk.id) > 0 AND COUNT(DISTINCT dft.id) > 0
            AND MAX(dft.value) NOT REGEXP '^[0-9]+(:[0-9]+)*(\\.[0-9]+)?$')
        OR (COUNT(DISTINCT rk.id) > 0 AND COUNT(DISTINCT dft.id) > 0
            AND MAX(dft.value) NOT REGEXP '[1-9]')
) x
JOIN event e ON e.id = x.event_id
GROUP BY e.id, e.name

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event_participants ep
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE ep.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND e.status_type = 'finished'
  AND e.status_descFK = 6
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND EXISTS (
      SELECT 1 FROM object_discipline od
      WHERE od.object_typeFK = 5 AND od.objectFK = e.id
        AND od.disciplineFK IN ({{TIMED_DISCIPLINE_LIST}}) AND od.del = 'no'
  )

ORDER BY sort_order, mismatching_participants_count DESC;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-047
    -- Name - EVENT_RESULTS_UNEXPECTED_FOR_NOT_STARTED
    -- What it does: Finds active events whose status is one of the sport's not-started detailed statuses that have at least one active, non-empty result row for any event participant, with template, tournament, stage name and status context, together with a coverage count of all eligible not-started events.
    'Unexpected_Results_For_Not_Started' AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    ts.name AS stage_name,
    e.status_type,
    e.status_descFK,
    NULL AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND e.status_type = 'notstarted'
  AND e.status_descFK IN ({{NOT_STARTED_DESC_LIST}})
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND EXISTS (
      SELECT 1
      FROM event_participants ep
      JOIN result r ON r.event_participantsFK = ep.id
        AND r.del = 'no'
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
  AND tt.sportFK = {{SPORT_ID}}
  AND e.status_type = 'notstarted'
  AND e.status_descFK IN ({{NOT_STARTED_DESC_LIST}})
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;



-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-052
    -- Name - EVENT_RESULTS_COMMENT_INVALID_OR_CONTRADICTED
    -- What it does: Finds active event-participant rows whose Comment result value is outside the sport's confirmed set of status codes, or whose Comment marks a participant as having no classified result while a Rank, a time or a Medal is stored for that same participant, together with a coverage count of all eligible event-participants carrying an active, non-empty Comment value.
    CASE
        WHEN LOWER(TRIM(x.comment_value)) IN ({{RESULT_COMMENT_NO_RESULT_LIST}}) AND x.medal_value IS NOT NULL THEN 'COMMENT_NO_RESULT_WITH_MEDAL'
        WHEN LOWER(TRIM(x.comment_value)) IN ({{RESULT_COMMENT_NO_RESULT_LIST}}) AND x.rank_value IS NOT NULL THEN 'COMMENT_NO_RESULT_WITH_RANK'
        WHEN LOWER(TRIM(x.comment_value)) IN ({{RESULT_COMMENT_NO_RESULT_LIST}}) AND (x.full_time_value IS NOT NULL OR x.duration_value IS NOT NULL) THEN 'COMMENT_NO_RESULT_WITH_TIME'
        ELSE 'COMMENT_INVALID_VALUE'
    END AS check_type,
    x.event_participants_id,
    x.event_id,
    x.event_name,
    x.participant_name,
    x.comment_value,
    x.rank_value,
    x.full_time_value,
    x.medal_value,
    x.tournament_template_name,
    NULL AS eligible_count
FROM (
    SELECT
        ep.id AS event_participants_id,
        e.id AS event_id,
        e.name AS event_name,
        p.name AS participant_name,
        tt.name AS tournament_template_name,
        rc.value AS comment_value,
        (SELECT NULLIF(TRIM(r2.value), '') FROM result r2
          WHERE r2.event_participantsFK = ep.id AND r2.result_typeFK = {{RESULT_RANK_TYPE_ID}}
            AND r2.del = 'no' AND r2.value IS NOT NULL LIMIT 1) AS rank_value,
        (SELECT NULLIF(TRIM(r3.value), '') FROM result r3
          WHERE r3.event_participantsFK = ep.id AND r3.result_typeFK = {{RESULT_FULL_TIME_TYPE_ID}}
            AND r3.del = 'no' AND r3.value IS NOT NULL LIMIT 1) AS full_time_value,
        (SELECT NULLIF(TRIM(r4.value), '') FROM result r4
          WHERE r4.event_participantsFK = ep.id AND r4.result_typeFK = {{RESULT_DURATION_TYPE_ID}}
            AND r4.del = 'no' AND r4.value IS NOT NULL LIMIT 1) AS duration_value,
        (SELECT NULLIF(TRIM(r5.value), '') FROM result r5
          WHERE r5.event_participantsFK = ep.id AND r5.result_typeFK = {{RESULT_MEDAL_TYPE_ID}}
            AND r5.del = 'no' AND r5.value IS NOT NULL LIMIT 1) AS medal_value
    FROM event_participants ep
    JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
    JOIN result rc ON rc.event_participantsFK = ep.id AND rc.result_typeFK = {{RESULT_COMMENT_TYPE_ID}} AND rc.del = 'no'
    WHERE ep.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      AND rc.value IS NOT NULL
      AND TRIM(rc.value) <> ''
      -- AND tt.id = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
) x
WHERE LOWER(TRIM(x.comment_value)) NOT IN ({{RESULT_COMMENT_VALUE_LIST}})
   OR (
        LOWER(TRIM(x.comment_value)) IN ({{RESULT_COMMENT_NO_RESULT_LIST}})
        AND (x.rank_value IS NOT NULL OR x.full_time_value IS NOT NULL
             OR x.duration_value IS NOT NULL OR x.medal_value IS NOT NULL)
      )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ep.id) AS eligible_count
FROM event_participants ep
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN result rc ON rc.event_participantsFK = ep.id AND rc.result_typeFK = {{RESULT_COMMENT_TYPE_ID}} AND rc.del = 'no'
WHERE ep.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND rc.value IS NOT NULL
  AND TRIM(rc.value) <> ''
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-053
    -- Name - EVENT_RESULTS_MEDAL_RANK_MISMATCH
    -- What it does: Finds active event-participant rows carrying an active, non-empty Medal result whose Rank does not match the place the medal stands for, or that carry no Rank at all, together with a coverage count of all eligible event-participants carrying an active, non-empty Medal value.
    CASE
        WHEN x.rank_value IS NULL THEN 'MEDAL_WITHOUT_RANK'
        ELSE 'MEDAL_RANK_MISMATCH'
    END AS check_type,
    x.event_participants_id,
    x.event_id,
    x.event_name,
    x.participant_name,
    x.medal_value,
    x.rank_value,
    x.expected_rank,
    NULL AS eligible_count
FROM (
    SELECT
        ep.id AS event_participants_id,
        e.id AS event_id,
        e.name AS event_name,
        p.name AS participant_name,
        rm.value AS medal_value,
        CASE LOWER(TRIM(rm.value))
            WHEN 'gold' THEN '1'
            WHEN 'silver' THEN '2'
            WHEN 'bronze' THEN '3'
            ELSE NULL
        END AS expected_rank,
        (SELECT NULLIF(TRIM(r2.value), '') FROM result r2
          WHERE r2.event_participantsFK = ep.id AND r2.result_typeFK = {{RESULT_RANK_TYPE_ID}}
            AND r2.del = 'no' AND r2.value IS NOT NULL LIMIT 1) AS rank_value
    FROM event_participants ep
    JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
    JOIN result rm ON rm.event_participantsFK = ep.id AND rm.result_typeFK = {{RESULT_MEDAL_TYPE_ID}} AND rm.del = 'no'
    WHERE ep.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      AND rm.value IS NOT NULL
      AND TRIM(rm.value) <> ''
      -- AND tt.id = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
) x
WHERE x.expected_rank IS NOT NULL
  AND (x.rank_value IS NULL OR x.rank_value <> x.expected_rank)

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ep.id) AS eligible_count
FROM event_participants ep
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN result rm ON rm.event_participantsFK = ep.id AND rm.result_typeFK = {{RESULT_MEDAL_TYPE_ID}} AND rm.del = 'no'
WHERE ep.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND rm.value IS NOT NULL
  AND TRIM(rm.value) <> ''
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-054
    -- Name - EVENT_RESULTS_RANK_FULL_TIME_NOT_MONOTONIC
    -- What it does: Finds active events in the sport's timed disciplines holding a pair of participants whose Rank order contradicts their full-time duration order, so a better-ranked competitor is recorded as slower than a worse-ranked one, with the number of contradicting pairs per event, together with a coverage count of all eligible events holding at least two participants with both a numeric Rank and a readable full time.
    'RANK_FULL_TIME_NOT_MONOTONIC' AS check_type,
    a.event_id,
    a.event_name,
    a.tournament_template_name,
    COUNT(*) AS contradicting_pair_count,
    GROUP_CONCAT(DISTINCT CONCAT(a.participant_name, ' #', a.rank_num, ' ', a.time_value,
                                 ' slower than #', b.rank_num, ' ', b.time_value)
                 ORDER BY 1 SEPARATOR ' | ') AS contradiction_detail,
    NULL AS eligible_count
FROM (
    SELECT e.id AS event_id, e.name AS event_name, tt.name AS tournament_template_name,
           p.name AS participant_name,
           CAST(TRIM(rr.value) AS UNSIGNED) AS rank_num,
           TRIM(rf.value) AS time_value,
           CASE
               WHEN TRIM(rf.value) REGEXP '^[0-9]+:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?$'
                   THEN CAST(SUBSTRING_INDEX(TRIM(rf.value), ':', 1) AS DECIMAL(14,3)) * 3600
                      + CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(TRIM(rf.value), ':', 2), ':', -1) AS DECIMAL(14,3)) * 60
                      + CAST(SUBSTRING_INDEX(TRIM(rf.value), ':', -1) AS DECIMAL(14,3))
               WHEN TRIM(rf.value) REGEXP '^[0-9]+:[0-9]{2}(\\.[0-9]+)?$'
                   THEN CAST(SUBSTRING_INDEX(TRIM(rf.value), ':', 1) AS DECIMAL(14,3)) * 60
                      + CAST(SUBSTRING_INDEX(TRIM(rf.value), ':', -1) AS DECIMAL(14,3))
               WHEN TRIM(rf.value) REGEXP '^[0-9]+(\\.[0-9]+)?$'
                   THEN CAST(TRIM(rf.value) AS DECIMAL(14,3))
               ELSE NULL
           END AS secs
    FROM event_participants ep
    JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
    JOIN result rr ON rr.event_participantsFK = ep.id AND rr.result_typeFK = {{RESULT_RANK_TYPE_ID}} AND rr.del = 'no'
    JOIN result rf ON rf.event_participantsFK = ep.id AND rf.result_typeFK = {{RESULT_FULL_TIME_TYPE_ID}} AND rf.del = 'no'
    WHERE ep.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      AND TRIM(rr.value) REGEXP '^[0-9]+$'
      -- AND tt.id = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
      AND EXISTS (
          SELECT 1 FROM object_discipline od
          WHERE od.object_typeFK = 5 AND od.objectFK = e.id
            AND od.disciplineFK IN ({{TIMED_DISCIPLINE_LIST}}) AND od.del = 'no'
      )
) a
JOIN (
    SELECT e.id AS event_id,
           CAST(TRIM(rr.value) AS UNSIGNED) AS rank_num,
           TRIM(rf.value) AS time_value,
           CASE
               WHEN TRIM(rf.value) REGEXP '^[0-9]+:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?$'
                   THEN CAST(SUBSTRING_INDEX(TRIM(rf.value), ':', 1) AS DECIMAL(14,3)) * 3600
                      + CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(TRIM(rf.value), ':', 2), ':', -1) AS DECIMAL(14,3)) * 60
                      + CAST(SUBSTRING_INDEX(TRIM(rf.value), ':', -1) AS DECIMAL(14,3))
               WHEN TRIM(rf.value) REGEXP '^[0-9]+:[0-9]{2}(\\.[0-9]+)?$'
                   THEN CAST(SUBSTRING_INDEX(TRIM(rf.value), ':', 1) AS DECIMAL(14,3)) * 60
                      + CAST(SUBSTRING_INDEX(TRIM(rf.value), ':', -1) AS DECIMAL(14,3))
               WHEN TRIM(rf.value) REGEXP '^[0-9]+(\\.[0-9]+)?$'
                   THEN CAST(TRIM(rf.value) AS DECIMAL(14,3))
               ELSE NULL
           END AS secs
    FROM event_participants ep
    JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN result rr ON rr.event_participantsFK = ep.id AND rr.result_typeFK = {{RESULT_RANK_TYPE_ID}} AND rr.del = 'no'
    JOIN result rf ON rf.event_participantsFK = ep.id AND rf.result_typeFK = {{RESULT_FULL_TIME_TYPE_ID}} AND rf.del = 'no'
    WHERE ep.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      AND TRIM(rr.value) REGEXP '^[0-9]+$'
      AND EXISTS (
          SELECT 1 FROM object_discipline od
          WHERE od.object_typeFK = 5 AND od.objectFK = e.id
            AND od.disciplineFK IN ({{TIMED_DISCIPLINE_LIST}}) AND od.del = 'no'
      )
) b
  ON b.event_id = a.event_id
 AND b.rank_num > a.rank_num
 AND b.secs < a.secs
WHERE a.secs IS NOT NULL
  AND b.secs IS NOT NULL
GROUP BY a.event_id, a.event_name, a.tournament_template_name

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT c.event_id) AS eligible_count
FROM (
    SELECT e.id AS event_id
    FROM event_participants ep
    JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN result rr ON rr.event_participantsFK = ep.id AND rr.result_typeFK = {{RESULT_RANK_TYPE_ID}} AND rr.del = 'no'
    JOIN result rf ON rf.event_participantsFK = ep.id AND rf.result_typeFK = {{RESULT_FULL_TIME_TYPE_ID}} AND rf.del = 'no'
    WHERE ep.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      AND TRIM(rr.value) REGEXP '^[0-9]+$'
      AND TRIM(rf.value) REGEXP '^[0-9]+:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?$|^[0-9]+:[0-9]{2}(\\.[0-9]+)?$|^[0-9]+(\\.[0-9]+)?$'
      -- AND tt.id = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
      AND EXISTS (
          SELECT 1 FROM object_discipline od
          WHERE od.object_typeFK = 5 AND od.objectFK = e.id
            AND od.disciplineFK IN ({{TIMED_DISCIPLINE_LIST}}) AND od.del = 'no'
      )
    GROUP BY e.id
    HAVING COUNT(DISTINCT ep.id) >= 2
) c
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-055
    -- Name - EVENT_PARTICIPANTS_DUPLICATE_IN_EVENT
    -- What it does: Finds active events in which one participant holds more than one active event-participant row, so the same competitor is entered twice in the same event, with the number of duplicated participants and their names, together with a coverage count of all eligible events holding at least one active participant.
    'PARTICIPANT_DUPLICATE_IN_EVENT' AS check_type,
    d.event_id,
    d.event_name,
    d.tournament_template_name,
    COUNT(DISTINCT d.participant_id) AS duplicated_participant_count,
    SUM(d.entry_count) AS duplicated_entry_count,
    GROUP_CONCAT(DISTINCT d.participant_name ORDER BY d.participant_name SEPARATOR ', ') AS duplicated_participants,
    NULL AS eligible_count
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        tt.name AS tournament_template_name,
        p.id AS participant_id,
        p.name AS participant_name,
        COUNT(DISTINCT ep.id) AS entry_count
    FROM event_participants ep
    JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
    WHERE ep.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      -- AND tt.id = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY e.id, e.name, tt.name, p.id, p.name
    HAVING COUNT(DISTINCT ep.id) > 1
) d
GROUP BY d.event_id, d.event_name, d.tournament_template_name

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
WHERE ep.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-056
    -- Name - EVENT_DURATION_FULL_TIME_ARITHMETIC_MISMATCH
    -- What it does: Finds active events in the sport's timed disciplines where a participant's full-time duration does not equal the leader's full time plus that participant's own gap value, beyond the tolerance the sport records, so the two time results disagree with each other rather than merely with their expected shape, with the number of disagreeing participants per event, together with a coverage count of all eligible events holding a readable leader full time and at least one participant carrying both a gap and a full time.
    'DURATION_FULL_TIME_ARITHMETIC_MISMATCH' AS check_type,
    x.event_id,
    x.event_name,
    x.tournament_template_name,
    COUNT(DISTINCT x.event_participants_id) AS disagreeing_participant_count,
    MIN(x.leader_time_value) AS leader_full_time,
    GROUP_CONCAT(DISTINCT CONCAT(x.participant_name, ' #', x.rank_num,
                                 ' gap ', x.gap_value, ' expected ', x.expected_secs,
                                 's but full time ', x.time_value)
                 ORDER BY 1 SEPARATOR ' | ') AS mismatch_detail,
    NULL AS eligible_count
FROM (
    SELECT e.id AS event_id, e.name AS event_name, tt.name AS tournament_template_name,
           ep.id AS event_participants_id, p.name AS participant_name,
           CAST(TRIM(rr.value) AS UNSIGNED) AS rank_num,
           TRIM(rd.value) AS gap_value,
           TRIM(rf.value) AS time_value,
           ld.leader_time_value,
           ld.leader_secs
             + CASE
                   WHEN TRIM(LEADING '+' FROM TRIM(rd.value)) REGEXP '^[0-9]+:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?$'
                       THEN CAST(SUBSTRING_INDEX(TRIM(LEADING '+' FROM TRIM(rd.value)), ':', 1) AS DECIMAL(14,3)) * 3600
                          + CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(TRIM(LEADING '+' FROM TRIM(rd.value)), ':', 2), ':', -1) AS DECIMAL(14,3)) * 60
                          + CAST(SUBSTRING_INDEX(TRIM(LEADING '+' FROM TRIM(rd.value)), ':', -1) AS DECIMAL(14,3))
                   WHEN TRIM(LEADING '+' FROM TRIM(rd.value)) REGEXP '^[0-9]+:[0-9]{2}(\\.[0-9]+)?$'
                       THEN CAST(SUBSTRING_INDEX(TRIM(LEADING '+' FROM TRIM(rd.value)), ':', 1) AS DECIMAL(14,3)) * 60
                          + CAST(SUBSTRING_INDEX(TRIM(LEADING '+' FROM TRIM(rd.value)), ':', -1) AS DECIMAL(14,3))
                   WHEN TRIM(LEADING '+' FROM TRIM(rd.value)) REGEXP '^[0-9]+(\\.[0-9]+)?$'
                       THEN CAST(TRIM(LEADING '+' FROM TRIM(rd.value)) AS DECIMAL(14,3))
                   ELSE NULL
               END AS expected_secs,
           CASE
               WHEN TRIM(rf.value) REGEXP '^[0-9]+:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?$'
                   THEN CAST(SUBSTRING_INDEX(TRIM(rf.value), ':', 1) AS DECIMAL(14,3)) * 3600
                      + CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(TRIM(rf.value), ':', 2), ':', -1) AS DECIMAL(14,3)) * 60
                      + CAST(SUBSTRING_INDEX(TRIM(rf.value), ':', -1) AS DECIMAL(14,3))
               WHEN TRIM(rf.value) REGEXP '^[0-9]+:[0-9]{2}(\\.[0-9]+)?$'
                   THEN CAST(SUBSTRING_INDEX(TRIM(rf.value), ':', 1) AS DECIMAL(14,3)) * 60
                      + CAST(SUBSTRING_INDEX(TRIM(rf.value), ':', -1) AS DECIMAL(14,3))
               WHEN TRIM(rf.value) REGEXP '^[0-9]+(\\.[0-9]+)?$'
                   THEN CAST(TRIM(rf.value) AS DECIMAL(14,3))
               ELSE NULL
           END AS actual_secs
    FROM event_participants ep
    JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
    JOIN result rr ON rr.event_participantsFK = ep.id AND rr.result_typeFK = {{RESULT_RANK_TYPE_ID}} AND rr.del = 'no'
    JOIN result rd ON rd.event_participantsFK = ep.id AND rd.result_typeFK = {{RESULT_DURATION_TYPE_ID}} AND rd.del = 'no'
    JOIN result rf ON rf.event_participantsFK = ep.id AND rf.result_typeFK = {{RESULT_FULL_TIME_TYPE_ID}} AND rf.del = 'no'
    JOIN (
        SELECT e2.id AS event_id,
               MIN(TRIM(rf2.value)) AS leader_time_value,
               MIN(CASE
                   WHEN TRIM(rf2.value) REGEXP '^[0-9]+:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?$'
                       THEN CAST(SUBSTRING_INDEX(TRIM(rf2.value), ':', 1) AS DECIMAL(14,3)) * 3600
                          + CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(TRIM(rf2.value), ':', 2), ':', -1) AS DECIMAL(14,3)) * 60
                          + CAST(SUBSTRING_INDEX(TRIM(rf2.value), ':', -1) AS DECIMAL(14,3))
                   WHEN TRIM(rf2.value) REGEXP '^[0-9]+:[0-9]{2}(\\.[0-9]+)?$'
                       THEN CAST(SUBSTRING_INDEX(TRIM(rf2.value), ':', 1) AS DECIMAL(14,3)) * 60
                          + CAST(SUBSTRING_INDEX(TRIM(rf2.value), ':', -1) AS DECIMAL(14,3))
                   WHEN TRIM(rf2.value) REGEXP '^[0-9]+(\\.[0-9]+)?$'
                       THEN CAST(TRIM(rf2.value) AS DECIMAL(14,3))
                   ELSE NULL
               END) AS leader_secs
        FROM event_participants ep2
        JOIN event e2 ON e2.id = ep2.eventFK AND e2.del = 'no'
        JOIN result rr2 ON rr2.event_participantsFK = ep2.id AND rr2.result_typeFK = {{RESULT_RANK_TYPE_ID}} AND rr2.del = 'no'
        JOIN result rf2 ON rf2.event_participantsFK = ep2.id AND rf2.result_typeFK = {{RESULT_FULL_TIME_TYPE_ID}} AND rf2.del = 'no'
        WHERE ep2.del = 'no' AND TRIM(rr2.value) = '1'
        GROUP BY e2.id
    ) ld ON ld.event_id = e.id
    WHERE ep.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      AND TRIM(rr.value) REGEXP '^[0-9]+$'
      AND TRIM(rr.value) <> '1'
      -- AND tt.id = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
      AND EXISTS (
          SELECT 1 FROM object_discipline od
          WHERE od.object_typeFK = 5 AND od.objectFK = e.id
            AND od.disciplineFK IN ({{TIMED_DISCIPLINE_LIST}}) AND od.del = 'no'
      )
) x
WHERE x.expected_secs IS NOT NULL
  AND x.actual_secs IS NOT NULL
  AND ABS(x.actual_secs - x.expected_secs) > {{FULL_TIME_TOLERANCE_SECONDS}}
GROUP BY x.event_id, x.event_name, x.tournament_template_name

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
JOIN result rr ON rr.event_participantsFK = ep.id AND rr.result_typeFK = {{RESULT_RANK_TYPE_ID}} AND rr.del = 'no'
JOIN result rd ON rd.event_participantsFK = ep.id AND rd.result_typeFK = {{RESULT_DURATION_TYPE_ID}} AND rd.del = 'no'
JOIN result rf ON rf.event_participantsFK = ep.id AND rf.result_typeFK = {{RESULT_FULL_TIME_TYPE_ID}} AND rf.del = 'no'
WHERE ep.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND TRIM(rr.value) REGEXP '^[0-9]+$'
  AND TRIM(rr.value) <> '1'
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND EXISTS (
      SELECT 1 FROM object_discipline od
      WHERE od.object_typeFK = 5 AND od.objectFK = e.id
        AND od.disciplineFK IN ({{TIMED_DISCIPLINE_LIST}}) AND od.del = 'no'
  )
  AND EXISTS (
      SELECT 1 FROM event_participants ep3
      JOIN result rr3 ON rr3.event_participantsFK = ep3.id AND rr3.result_typeFK = {{RESULT_RANK_TYPE_ID}} AND rr3.del = 'no'
      JOIN result rf3 ON rf3.event_participantsFK = ep3.id AND rf3.result_typeFK = {{RESULT_FULL_TIME_TYPE_ID}} AND rf3.del = 'no'
      WHERE ep3.eventFK = e.id AND ep3.del = 'no' AND TRIM(rr3.value) = '1'
  )
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-059
    -- Name - EVENT_RESULTS_DUPLICATE_ROWS
    -- What it does: Finds active events holding more than one active result row for the same event participant and result type, separating a duplicate repeating the same value from one storing conflicting values, with the number of affected participants and a sample group, together with a coverage count of all eligible events holding at least one active result.
    'Result_Duplicate_Rows' AS check_type,
    d.event_id,
    d.event_name,
    d.tournament_template_name,
    CASE WHEN SUM(d.distinct_values > 1) > 0 THEN 'CONFLICTING_VALUES' ELSE 'DUPLICATE_IDENTICAL' END AS duplicate_kind,
    COUNT(*) AS duplicated_group_count,
    COUNT(DISTINCT d.event_participants_id) AS affected_participant_count,
    SUM(d.row_count) AS duplicated_row_count,
    MIN(CONCAT('ep=', d.event_participants_id, ' type=', d.result_typeFK, ' values=', d.value_list)) AS sample_group,
    NULL AS eligible_count
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        tt.name AS tournament_template_name,
        ep.id AS event_participants_id,
        r.result_typeFK,
        COUNT(*) AS row_count,
        COUNT(DISTINCT TRIM(r.value)) AS distinct_values,
        SUBSTRING(GROUP_CONCAT(DISTINCT TRIM(r.value) ORDER BY TRIM(r.value) SEPARATOR '|'), 1, 100) AS value_list
    FROM result r
    JOIN event_participants ep ON ep.id = r.event_participantsFK AND ep.del = 'no'
    JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    WHERE r.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      -- AND tt.id = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY e.id, e.name, tt.name, ep.id, r.result_typeFK
    HAVING COUNT(*) > 1
) d
GROUP BY d.event_id, d.event_name, d.tournament_template_name

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count
FROM result r
JOIN event_participants ep ON ep.id = r.event_participantsFK AND ep.del = 'no'
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE r.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-069
    -- Name - EVENT_RESULTS_VALUE_BLANK
    -- What it does: Finds active event-participant rows holding at least one active result row whose value is neither empty nor readable, being made only of ordinary spacing or only of invisible characters such as a non-breaking or zero-width space, separating the two, with the result types affected and the number of such rows, together with a coverage count of all eligible event-participants holding at least one active result row.
    CASE
        WHEN x.invisible_count > 0 THEN 'BLANK_INVISIBLE_CHARACTER'
        ELSE 'BLANK_WHITESPACE_ONLY'
    END AS check_type,
    x.event_participants_id,
    x.event_id,
    x.event_name,
    x.participant_name,
    x.blank_result_type_ids,
    x.blank_result_count,
    x.tournament_template_name,
    NULL AS eligible_count,
    0 AS sort_order
FROM (
    SELECT
        ep.id AS event_participants_id,
        e.id AS event_id,
        e.name AS event_name,
        p.name AS participant_name,
        tt.name AS tournament_template_name,
        COUNT(DISTINCT r.id) AS blank_result_count,
        -- result_type carries no confirmed name column in DATABASE.md, so the field is
        -- named by the ID the sport's parameters already resolve.
        GROUP_CONCAT(DISTINCT r.result_typeFK ORDER BY 1 SEPARATOR ', ') AS blank_result_type_ids,
        -- The two classes differ in how they reach the rest of the catalogue. An invisible
        -- character survives TRIM(), so every value check reads it as populated and blames
        -- its content. Ordinary spacing is removed by TRIM(), which puts it outside both
        -- the findings and the coverage of those checks - the blind spot this statement
        -- exists to close.
        SUM(CASE WHEN TRIM(r.value) <> '' THEN 1 ELSE 0 END) AS invisible_count,
        SUM(CASE WHEN TRIM(r.value) = '' THEN 1 ELSE 0 END) AS whitespace_count
    FROM event_participants ep
    JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
    JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
    WHERE ep.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      -- AND tt.id = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
      -- NULL and '' are one state in DATABASE.md, the active empty row, and a sport uses
      -- it to record that a field does not apply to a participant. Both are therefore out
      -- of scope. What is asserted here is narrower: a value that is neither of them must
      -- carry content, so spacing and invisible characters are the only findings.
      AND r.value IS NOT NULL
      AND r.value <> ''
      AND TRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(r.value,
              UNHEX('C2A0'), ' '), UNHEX('E2808B'), ' '), UNHEX('EFBBBF'), ' '),
              CHAR(9), ' '), CHAR(10), ' '), CHAR(13), ' ')) = ''
    GROUP BY ep.id, e.id, e.name, p.name, tt.name
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ep.id) AS eligible_count,
    1 AS sort_order
FROM event_participants ep
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
WHERE ep.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, blank_result_count DESC;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-076
    -- Name - EVENT_RESULTS_NUMERIC_FIELD_NON_NUMERIC
    -- What it does: Finds active event-participant rows holding a value in one of the sport's numeric result fields that is not a number, separating a value that is one of the sport's own status codes, a value that is a sentinel standing for no data such as nan or n/a, a number written with thousands separators, and any other text, with the result type, the value and event context, together with a coverage count of all eligible event-participants holding an active non-empty value in one of those fields.
    CASE
        WHEN LOWER(TRIM(r.value)) IN ({{RESULT_COMMENT_VALUE_LIST}}) THEN 'STATUS_CODE_IN_NUMERIC_FIELD'
        WHEN LOWER(TRIM(r.value)) IN ('nan', 'null', 'n/a', 'na', '-', '--', '?', 'none') THEN 'SENTINEL_IN_NUMERIC_FIELD'
        -- A grouped number is a number that was written for a reader rather than stored for
        -- one, and it needs a different repair from text: the digits are right and only the
        -- separators have to go.
        WHEN TRIM(r.value) REGEXP '^-?[0-9]{1,3}(,[0-9]{3})+([.][0-9]+)?$' THEN 'GROUPED_NUMBER_IN_NUMERIC_FIELD'
        ELSE 'TEXT_IN_NUMERIC_FIELD'
    END AS check_type,
    ep.id AS event_participants_id,
    e.id AS event_id,
    e.name AS event_name,
    p.name AS participant_name,
    r.result_typeFK,
    r.value AS stored_value,
    tt.name AS tournament_template_name,
    NULL AS eligible_count
FROM event_participants ep
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
 AND r.result_typeFK IN ({{NUMERIC_RESULT_TYPE_LIST}})
WHERE ep.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND r.value IS NOT NULL
  AND TRIM(r.value) <> ''
  -- The mirror of GLOBAL-DQ-052, which asks whether the status vocabulary holds a value it
  -- should not. This asks the opposite: whether a status leaked into a field that carries
  -- a measured quantity, where no reader of that field will look for one.
  AND TRIM(r.value) NOT REGEXP '^-?[0-9]+([.,][0-9]+)?$'

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ep.id) AS eligible_count
FROM event_participants ep
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
 AND r.result_typeFK IN ({{NUMERIC_RESULT_TYPE_LIST}})
WHERE ep.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND r.value IS NOT NULL
  AND TRIM(r.value) <> ''
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-084
    -- Name - EVENT_RESULT_SCORE_TIED
    -- What it does: Finds active events of a head-to-head sport whose two participants hold an identical value in the deciding score result type, so no winner can be read from the pair, separating a tie on a zero score from a tie on a played score, with the shared value and template, tournament, stage and round context, together with a coverage count of all eligible active events holding exactly two active non-empty values of that result type.
    CASE
        WHEN CAST(TRIM(x.min_value) AS SIGNED) = 0 THEN 'TIED_SCORE_BOTH_ZERO'
        ELSE 'TIED_SCORE_PLAYED'
    END AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    tt.name AS template_name,
    t.name AS tournament_name,
    ts.name AS stage_name,
    e.round_typeFK,
    x.min_value AS shared_value,
    NULL AS eligible_count,
    0 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
-- Aggregated inside the sport's own hierarchy so the statement stays scoped, and keyed on
-- exactly two values because a pair is what a head-to-head result is: an event holding one
-- or three of them is a different defect and GLOBAL-DQ-083 is the check that names it.
JOIN (
    SELECT
        ep.eventFK AS event_id,
        MIN(TRIM(r.value)) AS min_value
    FROM result r
    JOIN event_participants ep ON ep.id = r.event_participantsFK AND ep.del = 'no'
    JOIN event e2 ON e2.id = ep.eventFK AND e2.del = 'no'
    JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
    JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
    JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
    WHERE r.del = 'no'
      AND r.result_typeFK = {{RESULT_FINAL_SCORE_TYPE_ID}}
      AND tt2.sportFK = {{SPORT_ID}}
      AND r.value IS NOT NULL
      AND TRIM(r.value) <> ''
      AND TRIM(r.value) REGEXP '^-?[0-9]+$'
    GROUP BY ep.eventFK
    HAVING COUNT(*) = 2 AND MIN(TRIM(r.value)) = MAX(TRIM(r.value))
) x ON x.event_id = e.id
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT x.event_id) AS eligible_count,
    1 AS sort_order
FROM (
    SELECT ep.eventFK AS event_id
    FROM result r
    JOIN event_participants ep ON ep.id = r.event_participantsFK AND ep.del = 'no'
    JOIN event e2 ON e2.id = ep.eventFK AND e2.del = 'no'
    JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
    JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
    JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
    WHERE r.del = 'no'
      AND r.result_typeFK = {{RESULT_FINAL_SCORE_TYPE_ID}}
      AND tt2.sportFK = {{SPORT_ID}}
      AND r.value IS NOT NULL
      AND TRIM(r.value) <> ''
      AND TRIM(r.value) REGEXP '^-?[0-9]+$'
    GROUP BY ep.eventFK
    HAVING COUNT(*) = 2
) x

ORDER BY sort_order, event_startdate DESC;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-085
    -- Name - EVENT_SCOPE_PERIOD_SUM_MISMATCH_TOTAL
    -- What it does: Finds active event participants whose period-by-period scope values do not add up to the total they hold in the deciding score result type, so the two storage layers disagree about the same competitor, separating a total above the sum of its periods from one below it, with both figures, the number of periods carrying a value and event context, together with a coverage count of all eligible event participants holding both a numeric total and at least one numeric period value.
    CASE
        WHEN CAST(TRIM(r.value) AS SIGNED) > x.period_sum THEN 'TOTAL_ABOVE_PERIOD_SUM'
        ELSE 'TOTAL_BELOW_PERIOD_SUM'
    END AS check_type,
    ep.id AS event_participants_id,
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    p.name AS participant_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    CAST(TRIM(r.value) AS SIGNED) AS stored_total,
    x.period_sum,
    x.period_count,
    NULL AS eligible_count,
    0 AS sort_order
FROM result r
JOIN event_participants ep ON ep.id = r.event_participantsFK AND ep.del = 'no'
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
-- The periods are summed per owning event participant, inside the sport's own hierarchy.
-- Only plainly numeric values are added: a period holding text would otherwise cast to zero
-- and turn a storage defect into an arithmetic one, reporting the wrong thing about it.
JOIN (
    SELECT
        sr.event_participantsFK AS event_participants_id,
        SUM(CAST(TRIM(sr.value) AS SIGNED)) AS period_sum,
        COUNT(*) AS period_count
    FROM scope_result sr
    JOIN event_scope es ON es.id = sr.event_scopeFK AND es.del = 'no'
                       AND es.scope_typeFK = {{SCOPE_TYPE_ID}}
    JOIN event e2 ON e2.id = es.eventFK AND e2.del = 'no'
    JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
    JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
    JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
    WHERE sr.del = 'no'
      AND sr.scope_data_typeFK IN ({{SCOPE_PERIOD_DATA_TYPE_LIST}})
      AND tt2.sportFK = {{SPORT_ID}}
      AND sr.value IS NOT NULL
      AND TRIM(sr.value) <> ''
      AND TRIM(sr.value) REGEXP '^-?[0-9]+$'
    GROUP BY sr.event_participantsFK
) x ON x.event_participants_id = ep.id
WHERE r.del = 'no'
  AND r.result_typeFK = {{RESULT_FINAL_SCORE_TYPE_ID}}
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND r.value IS NOT NULL
  AND TRIM(r.value) <> ''
  AND TRIM(r.value) REGEXP '^-?[0-9]+$'
  AND CAST(TRIM(r.value) AS SIGNED) <> x.period_sum

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ep.id) AS eligible_count,
    1 AS sort_order
FROM result r
JOIN event_participants ep ON ep.id = r.event_participantsFK AND ep.del = 'no'
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN (
    SELECT sr.event_participantsFK AS event_participants_id
    FROM scope_result sr
    JOIN event_scope es ON es.id = sr.event_scopeFK AND es.del = 'no'
                       AND es.scope_typeFK = {{SCOPE_TYPE_ID}}
    JOIN event e2 ON e2.id = es.eventFK AND e2.del = 'no'
    JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
    JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
    JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
    WHERE sr.del = 'no'
      AND sr.scope_data_typeFK IN ({{SCOPE_PERIOD_DATA_TYPE_LIST}})
      AND tt2.sportFK = {{SPORT_ID}}
      AND sr.value IS NOT NULL
      AND TRIM(sr.value) <> ''
      AND TRIM(sr.value) REGEXP '^-?[0-9]+$'
    GROUP BY sr.event_participantsFK
) x ON x.event_participants_id = ep.id
WHERE r.del = 'no'
  AND r.result_typeFK = {{RESULT_FINAL_SCORE_TYPE_ID}}
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND r.value IS NOT NULL
  AND TRIM(r.value) <> ''
  AND TRIM(r.value) REGEXP '^-?[0-9]+$'

ORDER BY sort_order, event_startdate DESC;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-086
    -- Name - EVENT_SCOPE_PERIOD_VALUE_UNRECOGNISED
    -- What it does: Finds active event participants holding a scope period value that is neither a non-negative number nor one of the sport's confirmed sentinels, separating a participant whose offending values are all empty active rows, one whose offending values are all negative numbers, and one holding an unrecognised token, with the offending values, how many rows carry them and event context, together with a coverage count of all eligible event participants holding at least one active period row.
    CASE
        WHEN bad.empty_count = bad.unrecognised_count THEN 'EMPTY_PERIOD_VALUE'
        WHEN bad.negative_count = bad.unrecognised_count THEN 'NEGATIVE_PERIOD_VALUE'
        ELSE 'UNRECOGNISED_PERIOD_VALUE'
    END AS check_type,
    ep.id AS event_participants_id,
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    p.name AS participant_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    bad.unrecognised_values,
    bad.unrecognised_count,
    NULL AS eligible_count,
    0 AS sort_order
FROM event_participants ep
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
-- The offending rows are selected and aggregated per owning event participant, so the
-- audited object stays the participant rather than becoming one row per period value.
-- An active row left empty is a different storage state from one holding a token
-- (DB-SEM-002), and the two are repaired differently, so they are separated rather than
-- merged into one verdict.
JOIN (
    SELECT
        sr.event_participantsFK AS event_participants_id,
        COUNT(*) AS unrecognised_count,
        SUM(CASE WHEN sr.value IS NULL OR TRIM(sr.value) = '' THEN 1 ELSE 0 END) AS empty_count,
        SUM(CASE WHEN TRIM(sr.value) REGEXP '^-[0-9]+$' THEN 1 ELSE 0 END) AS negative_count,
        GROUP_CONCAT(DISTINCT sr.value ORDER BY sr.value SEPARATOR ', ') AS unrecognised_values
    FROM scope_result sr
    JOIN event_scope es ON es.id = sr.event_scopeFK AND es.del = 'no'
                       AND es.scope_typeFK = {{SCOPE_TYPE_ID}}
    JOIN event e2 ON e2.id = es.eventFK AND e2.del = 'no'
    JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
    JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
    JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
    WHERE sr.del = 'no'
      AND sr.scope_data_typeFK IN ({{SCOPE_PERIOD_DATA_TYPE_LIST}})
      AND tt2.sportFK = {{SPORT_ID}}
      AND (
          sr.value IS NULL
          OR TRIM(sr.value) = ''
          -- A negative period is caught here rather than left to the arithmetic, because it
          -- passes every numeric test and would be summed as a real value: the sum check
          -- would then report a total that disagrees with its periods and say nothing about
          -- why. A period holds a score, and a score is not negative in any sport that
          -- stores one this way.
          OR TRIM(sr.value) REGEXP '^-[0-9]+$'
          OR (
              TRIM(sr.value) NOT REGEXP '^-?[0-9]+$'
              AND LOWER(TRIM(sr.value)) NOT IN ({{SCOPE_PERIOD_SENTINEL_LIST}})
          )
      )
    GROUP BY sr.event_participantsFK
) bad ON bad.event_participants_id = ep.id
WHERE ep.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ep.id) AS eligible_count,
    1 AS sort_order
FROM event_participants ep
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN scope_result sr ON sr.event_participantsFK = ep.id AND sr.del = 'no'
                    AND sr.scope_data_typeFK IN ({{SCOPE_PERIOD_DATA_TYPE_LIST}})
JOIN event_scope es ON es.id = sr.event_scopeFK AND es.del = 'no'
                   AND es.scope_typeFK = {{SCOPE_TYPE_ID}}
WHERE ep.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_startdate DESC;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-088
    -- Name - EVENT_WINNER_CONTRADICTS_SCORE
    -- What it does: Finds active finished events of a head-to-head sport whose recorded Winner names the side holding the lower score, or names a side at all while the two scores are equal, with the winner value, both scores and template, tournament, stage and round context, together with a coverage count of all eligible finished events holding a side-naming Winner and exactly two numeric values of the deciding score result type.
    CASE
        WHEN x.score_1 = x.score_2 THEN 'WINNER_NAMED_ON_EQUAL_SCORE'
        ELSE 'WINNER_CONTRADICTS_SCORE'
    END AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    tt.name AS template_name,
    t.name AS tournament_name,
    ts.name AS stage_name,
    e.round_typeFK,
    pr.value AS winner_value,
    x.score_1,
    x.score_2,
    NULL AS eligible_count,
    0 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN property pr ON pr.object = 'event' AND pr.objectFK = e.id
                AND pr.name = 'Winner' AND pr.del = 'no'
-- event_participants.number is the side discriminator: 1 is the home side and 2 the away
-- side, confirmed by the agreement between the stored Winner and the higher score wherever
-- both exist. The vocabulary naming those two sides differs per sport - Home/Away, a/b, A/B
-- - so it is two declared lists rather than a literal.
JOIN (
    SELECT
        ep.eventFK AS event_id,
        MAX(CASE WHEN ep.number = 1 THEN CAST(TRIM(r.value) AS SIGNED) END) AS score_1,
        MAX(CASE WHEN ep.number = 2 THEN CAST(TRIM(r.value) AS SIGNED) END) AS score_2
    FROM result r
    JOIN event_participants ep ON ep.id = r.event_participantsFK AND ep.del = 'no'
    JOIN event e2 ON e2.id = ep.eventFK AND e2.del = 'no'
    JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
    JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
    JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
    WHERE r.del = 'no'
      AND r.result_typeFK = {{RESULT_FINAL_SCORE_TYPE_ID}}
      AND tt2.sportFK = {{SPORT_ID}}
      AND TRIM(r.value) REGEXP '^-?[0-9]+$'
      AND ep.number IN (1, 2)
    GROUP BY ep.eventFK
    HAVING COUNT(*) = 2
) x ON x.event_id = e.id
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND e.status_type = 'finished'
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND LOWER(TRIM(pr.value)) IN ({{WINNER_HOME_VALUE_LIST}}, {{WINNER_AWAY_VALUE_LIST}})
  AND (
      x.score_1 = x.score_2
      OR (LOWER(TRIM(pr.value)) IN ({{WINNER_HOME_VALUE_LIST}}) AND x.score_1 < x.score_2)
      OR (LOWER(TRIM(pr.value)) IN ({{WINNER_AWAY_VALUE_LIST}}) AND x.score_2 < x.score_1)
  )

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
JOIN property pr ON pr.object = 'event' AND pr.objectFK = e.id
                AND pr.name = 'Winner' AND pr.del = 'no'
JOIN (
    SELECT ep.eventFK AS event_id
    FROM result r
    JOIN event_participants ep ON ep.id = r.event_participantsFK AND ep.del = 'no'
    JOIN event e2 ON e2.id = ep.eventFK AND e2.del = 'no'
    JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
    JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
    JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
    WHERE r.del = 'no'
      AND r.result_typeFK = {{RESULT_FINAL_SCORE_TYPE_ID}}
      AND tt2.sportFK = {{SPORT_ID}}
      AND TRIM(r.value) REGEXP '^-?[0-9]+$'
      AND ep.number IN (1, 2)
    GROUP BY ep.eventFK
    HAVING COUNT(*) = 2
) x ON x.event_id = e.id
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND e.status_type = 'finished'
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND LOWER(TRIM(pr.value)) IN ({{WINNER_HOME_VALUE_LIST}}, {{WINNER_AWAY_VALUE_LIST}})

ORDER BY sort_order, event_startdate DESC;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-090
    -- Name - EVENT_RESULT_MIRRORED_SCORE_TYPES_DISAGREE
    -- What it does: Finds active event participants for whom the two result types the sport stores the same figure in do not agree, separating a pair holding two different values from a pair where one of the two is absent altogether, with both stored values and event context, together with a coverage count of all eligible event participants holding at least one of the two result types.
    CASE
        WHEN r_primary.id IS NULL THEN 'PRIMARY_SCORE_MISSING'
        WHEN r_mirror.id IS NULL THEN 'MIRROR_SCORE_MISSING'
        ELSE 'MIRRORED_VALUES_DIFFER'
    END AS check_type,
    ep.id AS event_participants_id,
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    p.name AS participant_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    e.status_descFK,
    r_primary.value AS primary_value,
    r_mirror.value AS mirror_value,
    NULL AS eligible_count,
    0 AS sort_order
FROM event_participants ep
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
-- Both joins are left outer, because one of the pair being absent is the finding rather than
-- a reason to drop the row: an absent result row and a differing value are separate storage
-- states (DB-SEM-002) and they are repaired differently.
LEFT JOIN result r_primary ON r_primary.event_participantsFK = ep.id AND r_primary.del = 'no'
                          AND r_primary.result_typeFK = {{RESULT_FINAL_SCORE_TYPE_ID}}
LEFT JOIN result r_mirror  ON r_mirror.event_participantsFK = ep.id AND r_mirror.del = 'no'
                          AND r_mirror.result_typeFK = {{RESULT_MIRROR_SCORE_TYPE_ID}}
WHERE ep.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND (r_primary.id IS NOT NULL OR r_mirror.id IS NOT NULL)
  AND (
      r_primary.id IS NULL
      OR r_mirror.id IS NULL
      OR TRIM(r_primary.value) <> TRIM(r_mirror.value)
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ep.id) AS eligible_count,
    1 AS sort_order
FROM event_participants ep
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
             AND r.result_typeFK IN ({{RESULT_FINAL_SCORE_TYPE_ID}}, {{RESULT_MIRROR_SCORE_TYPE_ID}})
WHERE ep.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_startdate DESC;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-091
    -- Name - EVENT_SCOPE_PERIOD_NOT_STORED_FOR_BOTH_SIDES
    -- What it does: Finds active events in which a competition period is stored for some of their participants but not for all of them, or is stored more than once for one participant, so the two sides of the same contest disagree about which periods exist, separating the two, with the offending periods named, the number of participants the event holds and template, tournament and stage name context, together with a coverage count of all eligible active events holding at least one active period row in the selected scope type.
    CASE
        WHEN x.short_period_count > 0 THEN 'PERIOD_MISSING_FOR_SOME_PARTICIPANTS'
        ELSE 'PERIOD_STORED_MORE_THAN_ONCE'
    END AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    tt.name AS template_name,
    t.name AS tournament_name,
    ts.name AS stage_name,
    x.event_participant_count,
    x.short_period_count,
    x.short_periods,
    x.duplicated_period_count,
    x.duplicated_periods,
    NULL AS eligible_count,
    0 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
-- Measured per period rather than per participant, because the defect is an asymmetry
-- between the two sides of one contest and neither side is wrong on its own. The event's
-- own participant count is the expected number of rows, so an event holding other than the
-- usual number of entries is judged against itself: that defect is GLOBAL-DQ-083 and is not
-- restated here. A period no participant stores at all is silent by construction, which is
-- correct - an unplayed period is absence, not disagreement.
JOIN (
    SELECT
        p.event_id,
        p.event_participant_count,
        SUM(CASE WHEN p.sides_with_row < p.event_participant_count THEN 1 ELSE 0 END) AS short_period_count,
        GROUP_CONCAT(CASE WHEN p.sides_with_row < p.event_participant_count THEN p.period_name END
                     ORDER BY p.scope_data_type_id SEPARATOR ', ') AS short_periods,
        SUM(CASE WHEN p.row_count > p.sides_with_row THEN 1 ELSE 0 END) AS duplicated_period_count,
        GROUP_CONCAT(CASE WHEN p.row_count > p.sides_with_row THEN p.period_name END
                     ORDER BY p.scope_data_type_id SEPARATOR ', ') AS duplicated_periods
    FROM (
        SELECT
            es.eventFK AS event_id,
            sr.scope_data_typeFK AS scope_data_type_id,
            COALESCE(sdt.name, CAST(sr.scope_data_typeFK AS CHAR)) AS period_name,
            COUNT(DISTINCT sr.event_participantsFK) AS sides_with_row,
            COUNT(*) AS row_count,
            (
                SELECT COUNT(*)
                FROM event_participants epc
                WHERE epc.eventFK = es.eventFK AND epc.del = 'no'
            ) AS event_participant_count
        FROM scope_result sr
        JOIN event_scope es ON es.id = sr.event_scopeFK AND es.del = 'no'
                           AND es.scope_typeFK = {{SCOPE_TYPE_ID}}
        JOIN event e2 ON e2.id = es.eventFK AND e2.del = 'no'
        JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
        JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
        JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
        LEFT JOIN scope_data_type sdt ON sdt.id = sr.scope_data_typeFK
        WHERE sr.del = 'no'
          AND sr.scope_data_typeFK IN ({{SCOPE_PERIOD_DATA_TYPE_LIST}})
          AND tt2.sportFK = {{SPORT_ID}}
        GROUP BY es.eventFK, sr.scope_data_typeFK, sdt.name
    ) p
    GROUP BY p.event_id, p.event_participant_count
    HAVING short_period_count > 0 OR duplicated_period_count > 0
) x ON x.event_id = e.id
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN event_scope es ON es.eventFK = e.id AND es.del = 'no'
                   AND es.scope_typeFK = {{SCOPE_TYPE_ID}}
JOIN scope_result sr ON sr.event_scopeFK = es.id AND sr.del = 'no'
                    AND sr.scope_data_typeFK IN ({{SCOPE_PERIOD_DATA_TYPE_LIST}})
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_startdate DESC;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-092
    -- Name - EVENT_SCOPE_PERIOD_SENTINEL_NOT_TRAILING
    -- What it does: Finds active events whose sentinel for a period that was not played is contradicted by the periods around it, either because a participant stores a scored period after their own first sentinel or because one side marks a period unplayed while the other stores a value for it, separating the two, with the number of participants carrying a trailing defect, the periods the two sides disagree about and template, tournament and stage name context, together with a coverage count of all eligible active events holding at least one active sentinel value in the selected scope type.
    CASE
        WHEN tr.trailing_defect_sides > 0 THEN 'SENTINEL_FOLLOWED_BY_SCORE'
        ELSE 'SENTINEL_NOT_MATCHED_BY_OPPONENT'
    END AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    tt.name AS template_name,
    t.name AS tournament_name,
    ts.name AS stage_name,
    COALESCE(tr.trailing_defect_sides, 0) AS trailing_defect_sides,
    COALESCE(um.unmatched_period_count, 0) AS unmatched_period_count,
    um.unmatched_periods,
    NULL AS eligible_count,
    0 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
-- The sentinel means the period was not played, and two things follow from that alone. A
-- participant cannot score after their own first sentinel, and the opponent cannot have
-- played a period their opponent did not: both sides of one contest play the same periods.
-- Playing order is read from the ascending period data type id, which is what makes the
-- first comparison possible; a sport whose ids do not ascend in playing order cannot
-- instantiate this. The two verdicts are separated because they are repaired differently -
-- one is a stray value, the other a disagreement about where the contest ended.
LEFT JOIN (
    SELECT
        s.event_id,
        COUNT(*) AS trailing_defect_sides
    FROM (
        SELECT
            es.eventFK AS event_id,
            sr.event_participantsFK AS event_participants_id,
            MIN(CASE WHEN LOWER(TRIM(sr.value)) IN ({{SCOPE_PERIOD_SENTINEL_LIST}})
                     THEN sr.scope_data_typeFK END) AS first_sentinel_id,
            MAX(CASE WHEN TRIM(sr.value) REGEXP '^-?[0-9]+$'
                     THEN sr.scope_data_typeFK END) AS last_scored_id
        FROM scope_result sr
        JOIN event_scope es ON es.id = sr.event_scopeFK AND es.del = 'no'
                           AND es.scope_typeFK = {{SCOPE_TYPE_ID}}
        JOIN event e2 ON e2.id = es.eventFK AND e2.del = 'no'
        JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
        JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
        JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
        WHERE sr.del = 'no'
          AND sr.scope_data_typeFK IN ({{SCOPE_PERIOD_DATA_TYPE_LIST}})
          AND tt2.sportFK = {{SPORT_ID}}
        GROUP BY es.eventFK, sr.event_participantsFK
    ) s
    WHERE s.first_sentinel_id IS NOT NULL
      AND s.last_scored_id IS NOT NULL
      AND s.last_scored_id > s.first_sentinel_id
    GROUP BY s.event_id
) tr ON tr.event_id = e.id
LEFT JOIN (
    SELECT
        q.event_id,
        COUNT(*) AS unmatched_period_count,
        GROUP_CONCAT(q.period_name ORDER BY q.scope_data_type_id SEPARATOR ', ') AS unmatched_periods
    FROM (
        SELECT
            es.eventFK AS event_id,
            sr.scope_data_typeFK AS scope_data_type_id,
            COALESCE(sdt.name, CAST(sr.scope_data_typeFK AS CHAR)) AS period_name,
            COUNT(DISTINCT CASE WHEN LOWER(TRIM(sr.value)) IN ({{SCOPE_PERIOD_SENTINEL_LIST}})
                                THEN sr.event_participantsFK END) AS sentinel_sides,
            COUNT(DISTINCT sr.event_participantsFK) AS sides_with_row
        FROM scope_result sr
        JOIN event_scope es ON es.id = sr.event_scopeFK AND es.del = 'no'
                           AND es.scope_typeFK = {{SCOPE_TYPE_ID}}
        JOIN event e2 ON e2.id = es.eventFK AND e2.del = 'no'
        JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
        JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
        JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
        LEFT JOIN scope_data_type sdt ON sdt.id = sr.scope_data_typeFK
        WHERE sr.del = 'no'
          AND sr.scope_data_typeFK IN ({{SCOPE_PERIOD_DATA_TYPE_LIST}})
          AND tt2.sportFK = {{SPORT_ID}}
        GROUP BY es.eventFK, sr.scope_data_typeFK, sdt.name
    ) q
    WHERE q.sentinel_sides > 0
      AND q.sentinel_sides < q.sides_with_row
    GROUP BY q.event_id
) um ON um.event_id = e.id
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND (tr.event_id IS NOT NULL OR um.event_id IS NOT NULL)

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
JOIN event_scope es ON es.eventFK = e.id AND es.del = 'no'
                   AND es.scope_typeFK = {{SCOPE_TYPE_ID}}
JOIN scope_result sr ON sr.event_scopeFK = es.id AND sr.del = 'no'
                    AND sr.scope_data_typeFK IN ({{SCOPE_PERIOD_DATA_TYPE_LIST}})
                    AND LOWER(TRIM(sr.value)) IN ({{SCOPE_PERIOD_SENTINEL_LIST}})
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_startdate DESC;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-093
    -- Name - EVENT_RESULTS_MEDAL_SET_INVALID_FOR_MEDAL_ROUND
    -- What it does: Finds active finished events on one of the sport's medal rounds whose set of Medal result values is not the set that round decides, being one gold and one silver on a Final and one bronze on a bronze match, separating an event carrying no medal at all, one carrying a medal the round does not decide, one carrying a medal type more than once and one missing a medal type, with the medal counts, the round type and template, tournament and stage name context, together with a coverage count of all eligible finished medal-round events.
    CASE
        WHEN x.is_final = 1 AND x.total_medal_count = 0 THEN 'FINAL_NO_MEDALS_AT_ALL'
        WHEN x.is_final = 1 AND x.bronze_count > 0 THEN 'FINAL_UNEXPECTED_BRONZE'
        WHEN x.is_final = 1 AND (x.gold_count > 1 OR x.silver_count > 1) THEN 'FINAL_MEDAL_DUPLICATED'
        WHEN x.is_final = 1 THEN 'FINAL_MISSING_GOLD_OR_SILVER'
        WHEN x.total_medal_count = 0 THEN 'BRONZE_ROUND_NO_MEDALS_AT_ALL'
        WHEN x.gold_count > 0 OR x.silver_count > 0 THEN 'BRONZE_ROUND_UNEXPECTED_MEDAL'
        WHEN x.bronze_count > 1 THEN 'BRONZE_ROUND_MEDAL_DUPLICATED'
        ELSE 'BRONZE_ROUND_MISSING_BRONZE'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.template_name,
    x.tournament_name,
    x.stage_name,
    x.round_typeFK,
    x.gold_count,
    x.silver_count,
    x.bronze_count,
    x.participant_count,
    NULL AS eligible_count,
    0 AS sort_order
-- The medal set is asserted per round rather than per event or per stage, because a
-- head-to-head sport decides its medals in more than one match: the Final settles gold and
-- silver between its two participants and a bronze match settles bronze. No single event can
-- hold all three, which is why GLOBAL-DQ-037 cannot be used here, and a stage holds no medal
-- of its own - the value is a result row on an event participant, so the round the event sits
-- on is what says which medal it should carry. The detailed status is deliberately not
-- narrowed to the plain finished code: a Final decided in an extra period or awarded is
-- still a Final, and narrowing would drop it from the audit without saying so.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        tt.name AS template_name,
        t.name AS tournament_name,
        ts.name AS stage_name,
        e.round_typeFK,
        CASE WHEN e.round_typeFK IN ({{FINAL_ROUND_TYPE_LIST}}) THEN 1 ELSE 0 END AS is_final,
        COUNT(DISTINCT ep.id) AS participant_count,
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
     AND r.result_typeFK = {{RESULT_MEDAL_TYPE_ID}}
    WHERE e.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      AND e.status_type = 'finished'
      AND e.round_typeFK IN ({{FINAL_ROUND_TYPE_LIST}}, {{BRONZE_ROUND_TYPE_LIST}})
      -- AND tt.id = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY e.id, e.name, e.startdate, tt.name, t.name, ts.name, e.round_typeFK
) x
WHERE (x.is_final = 1 AND NOT (x.gold_count = 1 AND x.silver_count = 1 AND x.bronze_count = 0))
   OR (x.is_final = 0 AND NOT (x.bronze_count = 1 AND x.gold_count = 0 AND x.silver_count = 0))

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND e.status_type = 'finished'
  AND e.round_typeFK IN ({{FINAL_ROUND_TYPE_LIST}}, {{BRONZE_ROUND_TYPE_LIST}})
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_startdate DESC;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-094
    -- Name - EVENT_RESULTS_MEDAL_CONTRADICTS_SCORE
    -- What it does: Finds active event participants on one of the sport's medal rounds whose stored Medal does not match the place their own score gives them, the winner of a Final taking gold and the loser silver, the winner of a bronze match taking bronze and the loser none, separating a medal that is missing, one that is stored where the round awards none and one naming the wrong place, with both scores, the expected and the stored medal and event context, together with a coverage count of all eligible event participants in finished medal-round events holding exactly two numeric scores that differ.
    CASE
        WHEN m.stored_medal = '' THEN 'MEDAL_MISSING_FOR_PLACE'
        WHEN m.expected_medal = '' THEN 'MEDAL_UNEXPECTED_FOR_PLACE'
        ELSE 'MEDAL_WRONG_FOR_PLACE'
    END AS check_type,
    m.event_participants_id,
    m.event_id,
    m.event_name,
    m.event_startdate,
    m.participant_name,
    m.template_name,
    m.tournament_name,
    m.round_typeFK,
    m.own_score,
    m.opponent_score,
    m.expected_medal,
    m.stored_medal,
    NULL AS eligible_count,
    0 AS sort_order
-- The winner is read from the pair of scores, never from a stored rank or a Winner property:
-- a head-to-head sport that stores neither still decides its medals, and the score is what
-- decides them. A tie is excluded rather than judged, because no place can be read from it -
-- GLOBAL-DQ-084 is the check that names a tie. The medal is read through an aggregate so a
-- participant carrying two Medal rows still produces one row here; that duplication is
-- GLOBAL-DQ-059 and is not restated.
FROM (
    SELECT
        ep.id AS event_participants_id,
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        p.name AS participant_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        e.round_typeFK,
        CAST(TRIM(rs.value) AS SIGNED) AS own_score,
        CASE WHEN CAST(TRIM(rs.value) AS SIGNED) = sc.max_score
             THEN sc.min_score ELSE sc.max_score END AS opponent_score,
        CASE
            WHEN e.round_typeFK IN ({{FINAL_ROUND_TYPE_LIST}})
                 AND CAST(TRIM(rs.value) AS SIGNED) = sc.max_score THEN 'gold'
            WHEN e.round_typeFK IN ({{FINAL_ROUND_TYPE_LIST}}) THEN 'silver'
            WHEN CAST(TRIM(rs.value) AS SIGNED) = sc.max_score THEN 'bronze'
            ELSE ''
        END AS expected_medal,
        COALESCE((
            SELECT MIN(LOWER(TRIM(rm.value)))
            FROM result rm
            WHERE rm.event_participantsFK = ep.id
              AND rm.del = 'no'
              AND rm.result_typeFK = {{RESULT_MEDAL_TYPE_ID}}
              AND rm.value IS NOT NULL
              AND TRIM(rm.value) <> ''
        ), '') AS stored_medal
    FROM event_participants ep
    JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
    JOIN result rs ON rs.event_participantsFK = ep.id AND rs.del = 'no'
                  AND rs.result_typeFK = {{RESULT_FINAL_SCORE_TYPE_ID}}
                  AND rs.value IS NOT NULL
                  AND TRIM(rs.value) REGEXP '^-?[0-9]+$'
    JOIN (
        SELECT
            ep2.eventFK AS event_id,
            MIN(CAST(TRIM(r2.value) AS SIGNED)) AS min_score,
            MAX(CAST(TRIM(r2.value) AS SIGNED)) AS max_score
        FROM result r2
        JOIN event_participants ep2 ON ep2.id = r2.event_participantsFK AND ep2.del = 'no'
        JOIN event e2 ON e2.id = ep2.eventFK AND e2.del = 'no'
        JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
        JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
        JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
        WHERE r2.del = 'no'
          AND r2.result_typeFK = {{RESULT_FINAL_SCORE_TYPE_ID}}
          AND tt2.sportFK = {{SPORT_ID}}
          AND e2.status_type = 'finished'
          AND e2.round_typeFK IN ({{FINAL_ROUND_TYPE_LIST}}, {{BRONZE_ROUND_TYPE_LIST}})
          AND r2.value IS NOT NULL
          AND TRIM(r2.value) REGEXP '^-?[0-9]+$'
        GROUP BY ep2.eventFK
        HAVING COUNT(*) = 2
           AND MIN(CAST(TRIM(r2.value) AS SIGNED)) <> MAX(CAST(TRIM(r2.value) AS SIGNED))
    ) sc ON sc.event_id = e.id
    WHERE ep.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      AND e.status_type = 'finished'
      AND e.round_typeFK IN ({{FINAL_ROUND_TYPE_LIST}}, {{BRONZE_ROUND_TYPE_LIST}})
      -- AND tt.id = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
) m
WHERE m.expected_medal <> m.stored_medal

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ep.id) AS eligible_count,
    1 AS sort_order
FROM event_participants ep
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN result rs ON rs.event_participantsFK = ep.id AND rs.del = 'no'
              AND rs.result_typeFK = {{RESULT_FINAL_SCORE_TYPE_ID}}
              AND rs.value IS NOT NULL
              AND TRIM(rs.value) REGEXP '^-?[0-9]+$'
JOIN (
    SELECT ep2.eventFK AS event_id
    FROM result r2
    JOIN event_participants ep2 ON ep2.id = r2.event_participantsFK AND ep2.del = 'no'
    JOIN event e2 ON e2.id = ep2.eventFK AND e2.del = 'no'
    JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
    JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
    JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
    WHERE r2.del = 'no'
      AND r2.result_typeFK = {{RESULT_FINAL_SCORE_TYPE_ID}}
      AND tt2.sportFK = {{SPORT_ID}}
      AND e2.status_type = 'finished'
      AND e2.round_typeFK IN ({{FINAL_ROUND_TYPE_LIST}}, {{BRONZE_ROUND_TYPE_LIST}})
      AND r2.value IS NOT NULL
      AND TRIM(r2.value) REGEXP '^-?[0-9]+$'
    GROUP BY ep2.eventFK
    HAVING COUNT(*) = 2
       AND MIN(CAST(TRIM(r2.value) AS SIGNED)) <> MAX(CAST(TRIM(r2.value) AS SIGNED))
) sc ON sc.event_id = e.id
WHERE ep.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND e.status_type = 'finished'
  AND e.round_typeFK IN ({{FINAL_ROUND_TYPE_LIST}}, {{BRONZE_ROUND_TYPE_LIST}})
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_startdate DESC;

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-102
    -- Name - EVENT_SCOPE_RESULT_OWNER_EVENT_MISMATCH
    -- What it does: Finds active events of the selected sport holding a scope container of the confirmed scope type whose scope results name an event participant belonging to a different event, or name an event-participant row that is not active at all, so the per-period value is attached to a competitor who did not play that event, with the number of offending rows and a sample and the container and stage name context, together with a coverage count of all eligible events holding at least one active scope result in such a container.
    CASE
        WHEN x.participant_row_missing_count > 0 THEN 'SCOPE_RESULT_PARTICIPANT_ROW_MISSING'
        ELSE 'SCOPE_RESULT_OWNER_EVENT_MISMATCH'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.tournament_stage_name,
    x.offending_row_count,
    x.sample_row,
    NULL AS eligible_count,
    0 AS sort_order
-- A relational invariant rather than a reading of the sport's semantics: a scope result
-- reaches an event twice over, once through the container it hangs off and once through the
-- participant it names, and the two have to arrive at the same event. Nothing a sport does
-- with periods, ends or checkpoints can make them disagree legitimately, which is why this
-- needs no vocabulary parameter and carries no false-positive risk from format.
-- The missing participant row is reported by the same check because it is the same failed
-- resolution: a scope result whose participant cannot be reached is attached to nobody, and
-- separating it into its own CheckID would split one broken reference in two.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        ts.name AS tournament_stage_name,
        COUNT(*) AS offending_row_count,
        SUM(CASE WHEN ep.id IS NULL THEN 1 ELSE 0 END) AS participant_row_missing_count,
        MIN(CONCAT('scope=', es.id,
                   ' scope_event=', es.eventFK,
                   ' ep=', sr.event_participantsFK,
                   ' ep_event=', COALESCE(CAST(ep.eventFK AS CHAR), 'none'))) AS sample_row
    FROM scope_result sr
    JOIN event_scope es ON es.id = sr.event_scopeFK AND es.del = 'no'
         AND es.scope_typeFK = {{SCOPE_TYPE_ID}}
    JOIN event e ON e.id = es.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = {{SPORT_ID}}
    LEFT JOIN event_participants ep ON ep.id = sr.event_participantsFK AND ep.del = 'no'
    WHERE sr.del = 'no'
      -- AND tt.id = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
      AND (ep.id IS NULL OR ep.eventFK <> es.eventFK)
    GROUP BY e.id, e.name, ts.name
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM scope_result sr
JOIN event_scope es ON es.id = sr.event_scopeFK AND es.del = 'no'
     AND es.scope_typeFK = {{SCOPE_TYPE_ID}}
JOIN event e ON e.id = es.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = {{SPORT_ID}}
WHERE sr.del = 'no'
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_id;

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-107
    -- Name - EVENT_SCOPE_CONTAINER_MISSING_FOR_FINISHED
    -- What it does: Finds active finished events of the selected sport holding no active scope container of the confirmed scope type, so a match that was played records no period-by-period breakdown at all, with the event start year and template and stage name context, together with a coverage count of all eligible finished events of the sport.
    'Event_Scope_Container_Missing' AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    YEAR(e.startdate) AS event_year,
    ts.name AS tournament_stage_name,
    tt.name AS template_name,
    NULL AS eligible_count,
    0 AS sort_order
-- Only the missing container is reported. More than one container for an event would be the
-- other half of a cardinality rule, but it does not occur in any confirmed sport, and a
-- statement asserting a condition with no observed population is a rule nobody can test.
-- The event year is projected because a defect concentrated in one season is an import and a
-- defect spread across twenty is a storage habit; the reader needs to tell them apart.
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = {{SPORT_ID}}
WHERE e.del = 'no'
  AND e.status_type = 'finished'
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND NOT EXISTS (
      SELECT 1 FROM event_scope es
      WHERE es.eventFK = e.id AND es.del = 'no'
        AND es.scope_typeFK = {{SCOPE_TYPE_ID}}
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = {{SPORT_ID}}
WHERE e.del = 'no'
  AND e.status_type = 'finished'
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_id;

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-108
    -- Name - EVENT_RESULTS_SCORE_NEGATIVE_OR_FRACTIONAL
    -- What it does: Finds active event-participant rows of the selected sport whose deciding score or its mirror holds a value that is negative or carries a fractional part, so a count of scoring units is stored as something no count can be, separating a negative value from a fractional one, with the offending values and their result types and event name context, together with a coverage count of all eligible event-participants holding at least one active, non-empty value of either type.
    CASE
        WHEN x.negative_count > 0 THEN 'SCORE_NEGATIVE'
        ELSE 'SCORE_FRACTIONAL'
    END AS check_type,
    x.event_participants_id,
    x.event_id,
    x.event_name,
    x.offending_values,
    NULL AS eligible_count,
    0 AS sort_order
-- Tighter than GLOBAL-DQ-076, which asks only whether the value is numeric at all and
-- therefore accepts -3 and 4.5. A score is a count of scoring units, so the domain is the
-- non-negative integers and nothing else; the two ways of leaving it are separated because a
-- negative score is a sign error and a fractional one is a unit error.
FROM (
    SELECT
        ep.id AS event_participants_id,
        e.id AS event_id,
        e.name AS event_name,
        SUM(CASE WHEN TRIM(r.value) REGEXP '^-[0-9]' THEN 1 ELSE 0 END) AS negative_count,
        SUBSTRING(GROUP_CONCAT(DISTINCT CONCAT(r.result_typeFK, '=', LEFT(TRIM(r.value), 20))
                  ORDER BY r.result_typeFK SEPARATOR ' | '), 1, 100) AS offending_values
    FROM result r
    JOIN event_participants ep ON ep.id = r.event_participantsFK AND ep.del = 'no'
    JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = {{SPORT_ID}}
    WHERE r.del = 'no'
      AND r.result_typeFK IN ({{RESULT_FINAL_SCORE_TYPE_ID}}, {{RESULT_MIRROR_SCORE_TYPE_ID}})
      AND TRIM(COALESCE(r.value, '')) <> ''
      -- AND tt.id = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
      AND (TRIM(r.value) REGEXP '^-[0-9]' OR TRIM(r.value) REGEXP '^-?[0-9]+\\.[0-9]+$')
    GROUP BY ep.id, e.id, e.name
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ep.id) AS eligible_count,
    1 AS sort_order
FROM result r
JOIN event_participants ep ON ep.id = r.event_participantsFK AND ep.del = 'no'
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = {{SPORT_ID}}
WHERE r.del = 'no'
  AND r.result_typeFK IN ({{RESULT_FINAL_SCORE_TYPE_ID}}, {{RESULT_MIRROR_SCORE_TYPE_ID}})
  AND TRIM(COALESCE(r.value, '')) <> ''
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_id, event_participants_id;

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-111
    -- Name - EVENT_RESULTS_RANK_EFFECTIVE_TIME_NOT_MONOTONIC
    -- What it does: Finds active events of the selected sport in its timed disciplines where a finishing participant placed behind another records a strictly faster time, or where the time it records cannot be read as a time at all, taking the effective time to be the Full time where one is stored and the Duration otherwise, ignoring participants whose Comment marks them as not finishing, with the offending pair or value and the stage name context, together with a coverage count of all eligible events holding at least two ranked finishers carrying a time.
    x.check_type,
    x.event_id,
    x.event_name,
    x.tournament_stage_name,
    x.offending_count,
    x.sample_offence,
    NULL AS eligible_count,
    0 AS sort_order
-- The effective time is Full time where one exists and Duration otherwise, because the
-- Duration column carries two different facts depending on that: where a Full time is stored
-- beside it, Duration is the gap to the winner; where it stands alone, it is the absolute
-- time itself. Comparing the column directly would therefore compare a gap against an
-- absolute and report the whole field.
-- Only values of the same kind are compared, which is what is_gap carries. Within one event
-- the winner is often stored as an absolute time while everyone behind is stored as a gap to
-- that winner, so an absolute and a gap sit side by side under the same rank sequence. Read
-- as two absolutes they say the second rider finished in a fraction of a second, and the
-- first draft of this check reported exactly that. A gap rises with rank for the same reason
-- an absolute time does, so gap against gap is a sound comparison; only the mixed pair is
-- meaningless, and it is dropped rather than resolved by guessing which base it counts from.
-- An unreadable value is reported by the same statement rather than filtered out. A row
-- whose time cannot be parsed would otherwise leave the comparison silently, which is the
-- same failure the checks joining through a broken reference already had: the population
-- narrows and the result still reads as clean.
FROM (
    SELECT
        CASE WHEN a.seconds IS NULL OR b.seconds IS NULL
             THEN 'EFFECTIVE_TIME_UNPARSEABLE'
             ELSE 'RANK_EFFECTIVE_TIME_NOT_MONOTONIC' END AS check_type,
        a.event_id,
        a.event_name,
        a.tournament_stage_name,
        COUNT(*) AS offending_count,
        MIN(CONCAT('rank ', a.rank_value, ' = ', a.effective_raw,
                   ' vs rank ', b.rank_value, ' = ', b.effective_raw)) AS sample_offence
    FROM (
        SELECT
            ep.id AS ep_id,
            e.id AS event_id,
            e.name AS event_name,
            ts.name AS tournament_stage_name,
            CAST(TRIM(MAX(CASE WHEN r.result_typeFK = {{RESULT_RANK_TYPE_ID}} THEN r.value END)) AS UNSIGNED) AS rank_value,
            COALESCE(
                NULLIF(TRIM(MAX(CASE WHEN r.result_typeFK = {{RESULT_FULL_TIME_TYPE_ID}} THEN r.value END)), ''),
                NULLIF(TRIM(MAX(CASE WHEN r.result_typeFK = {{RESULT_DURATION_TYPE_ID}} THEN r.value END)), '')
            ) AS effective_raw,
            CASE WHEN COALESCE(
                    NULLIF(TRIM(MAX(CASE WHEN r.result_typeFK = {{RESULT_FULL_TIME_TYPE_ID}} THEN r.value END)), ''),
                    NULLIF(TRIM(MAX(CASE WHEN r.result_typeFK = {{RESULT_DURATION_TYPE_ID}} THEN r.value END)), '')
                 ) LIKE '+%' THEN 1 ELSE 0 END AS is_gap,
            CASE
                WHEN TRIM(LEADING '+' FROM COALESCE(
                        NULLIF(TRIM(MAX(CASE WHEN r.result_typeFK = {{RESULT_FULL_TIME_TYPE_ID}} THEN r.value END)), ''),
                        NULLIF(TRIM(MAX(CASE WHEN r.result_typeFK = {{RESULT_DURATION_TYPE_ID}} THEN r.value END)), '')
                     )) NOT REGEXP '^[0-9]+(:[0-5][0-9])?(\\.[0-9]+)?$' THEN NULL
                WHEN TRIM(LEADING '+' FROM COALESCE(
                        NULLIF(TRIM(MAX(CASE WHEN r.result_typeFK = {{RESULT_FULL_TIME_TYPE_ID}} THEN r.value END)), ''),
                        NULLIF(TRIM(MAX(CASE WHEN r.result_typeFK = {{RESULT_DURATION_TYPE_ID}} THEN r.value END)), '')
                     )) LIKE '%:%'
                THEN CAST(SUBSTRING_INDEX(TRIM(LEADING '+' FROM COALESCE(
                            NULLIF(TRIM(MAX(CASE WHEN r.result_typeFK = {{RESULT_FULL_TIME_TYPE_ID}} THEN r.value END)), ''),
                            NULLIF(TRIM(MAX(CASE WHEN r.result_typeFK = {{RESULT_DURATION_TYPE_ID}} THEN r.value END)), '')
                         )), ':', 1) AS DECIMAL(14,3)) * 60
                   + CAST(SUBSTRING_INDEX(TRIM(LEADING '+' FROM COALESCE(
                            NULLIF(TRIM(MAX(CASE WHEN r.result_typeFK = {{RESULT_FULL_TIME_TYPE_ID}} THEN r.value END)), ''),
                            NULLIF(TRIM(MAX(CASE WHEN r.result_typeFK = {{RESULT_DURATION_TYPE_ID}} THEN r.value END)), '')
                         )), ':', -1) AS DECIMAL(14,3))
                ELSE CAST(TRIM(LEADING '+' FROM COALESCE(
                        NULLIF(TRIM(MAX(CASE WHEN r.result_typeFK = {{RESULT_FULL_TIME_TYPE_ID}} THEN r.value END)), ''),
                        NULLIF(TRIM(MAX(CASE WHEN r.result_typeFK = {{RESULT_DURATION_TYPE_ID}} THEN r.value END)), '')
                     )) AS DECIMAL(14,3))
            END AS seconds
        FROM event_participants ep
        JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
             AND tt.sportFK = {{SPORT_ID}}
        JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
        WHERE ep.del = 'no'
          -- AND tt.id = <tournament_template_id>
          -- AND e.startdate >= '<from_datetime>'
          -- AND e.startdate <  '<to_datetime>'
          AND EXISTS (
              SELECT 1 FROM object_discipline od
              WHERE od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
                AND od.disciplineFK IN ({{TIMED_DISCIPLINE_LIST}})
          )
          AND NOT EXISTS (
              SELECT 1 FROM result rc
              WHERE rc.event_participantsFK = ep.id AND rc.del = 'no'
                AND rc.result_typeFK = {{RESULT_COMMENT_TYPE_ID}}
                AND LOWER(TRIM(rc.value)) IN ({{RESULT_COMMENT_NO_RESULT_LIST}})
          )
        GROUP BY ep.id, e.id, e.name, ts.name
        HAVING rank_value IS NOT NULL AND effective_raw IS NOT NULL
    ) a
    JOIN (
        SELECT
            ep.id AS ep_id,
            e.id AS event_id,
            CAST(TRIM(MAX(CASE WHEN r.result_typeFK = {{RESULT_RANK_TYPE_ID}} THEN r.value END)) AS UNSIGNED) AS rank_value,
            COALESCE(
                NULLIF(TRIM(MAX(CASE WHEN r.result_typeFK = {{RESULT_FULL_TIME_TYPE_ID}} THEN r.value END)), ''),
                NULLIF(TRIM(MAX(CASE WHEN r.result_typeFK = {{RESULT_DURATION_TYPE_ID}} THEN r.value END)), '')
            ) AS effective_raw,
            CASE WHEN COALESCE(
                    NULLIF(TRIM(MAX(CASE WHEN r.result_typeFK = {{RESULT_FULL_TIME_TYPE_ID}} THEN r.value END)), ''),
                    NULLIF(TRIM(MAX(CASE WHEN r.result_typeFK = {{RESULT_DURATION_TYPE_ID}} THEN r.value END)), '')
                 ) LIKE '+%' THEN 1 ELSE 0 END AS is_gap,
            CASE
                WHEN TRIM(LEADING '+' FROM COALESCE(
                        NULLIF(TRIM(MAX(CASE WHEN r.result_typeFK = {{RESULT_FULL_TIME_TYPE_ID}} THEN r.value END)), ''),
                        NULLIF(TRIM(MAX(CASE WHEN r.result_typeFK = {{RESULT_DURATION_TYPE_ID}} THEN r.value END)), '')
                     )) NOT REGEXP '^[0-9]+(:[0-5][0-9])?(\\.[0-9]+)?$' THEN NULL
                WHEN TRIM(LEADING '+' FROM COALESCE(
                        NULLIF(TRIM(MAX(CASE WHEN r.result_typeFK = {{RESULT_FULL_TIME_TYPE_ID}} THEN r.value END)), ''),
                        NULLIF(TRIM(MAX(CASE WHEN r.result_typeFK = {{RESULT_DURATION_TYPE_ID}} THEN r.value END)), '')
                     )) LIKE '%:%'
                THEN CAST(SUBSTRING_INDEX(TRIM(LEADING '+' FROM COALESCE(
                            NULLIF(TRIM(MAX(CASE WHEN r.result_typeFK = {{RESULT_FULL_TIME_TYPE_ID}} THEN r.value END)), ''),
                            NULLIF(TRIM(MAX(CASE WHEN r.result_typeFK = {{RESULT_DURATION_TYPE_ID}} THEN r.value END)), '')
                         )), ':', 1) AS DECIMAL(14,3)) * 60
                   + CAST(SUBSTRING_INDEX(TRIM(LEADING '+' FROM COALESCE(
                            NULLIF(TRIM(MAX(CASE WHEN r.result_typeFK = {{RESULT_FULL_TIME_TYPE_ID}} THEN r.value END)), ''),
                            NULLIF(TRIM(MAX(CASE WHEN r.result_typeFK = {{RESULT_DURATION_TYPE_ID}} THEN r.value END)), '')
                         )), ':', -1) AS DECIMAL(14,3))
                ELSE CAST(TRIM(LEADING '+' FROM COALESCE(
                        NULLIF(TRIM(MAX(CASE WHEN r.result_typeFK = {{RESULT_FULL_TIME_TYPE_ID}} THEN r.value END)), ''),
                        NULLIF(TRIM(MAX(CASE WHEN r.result_typeFK = {{RESULT_DURATION_TYPE_ID}} THEN r.value END)), '')
                     )) AS DECIMAL(14,3))
            END AS seconds
        FROM event_participants ep
        JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
             AND tt.sportFK = {{SPORT_ID}}
        JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
        WHERE ep.del = 'no'
          -- AND tt.id = <tournament_template_id>
          -- AND e.startdate >= '<from_datetime>'
          -- AND e.startdate <  '<to_datetime>'
          AND EXISTS (
              SELECT 1 FROM object_discipline od
              WHERE od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
                AND od.disciplineFK IN ({{TIMED_DISCIPLINE_LIST}})
          )
          AND NOT EXISTS (
              SELECT 1 FROM result rc
              WHERE rc.event_participantsFK = ep.id AND rc.del = 'no'
                AND rc.result_typeFK = {{RESULT_COMMENT_TYPE_ID}}
                AND LOWER(TRIM(rc.value)) IN ({{RESULT_COMMENT_NO_RESULT_LIST}})
          )
        GROUP BY ep.id, e.id
        HAVING rank_value IS NOT NULL AND effective_raw IS NOT NULL
    ) b
      ON b.event_id = a.event_id
     AND b.rank_value > a.rank_value
     AND b.is_gap = a.is_gap
     AND (a.seconds IS NULL OR b.seconds IS NULL OR b.seconds < a.seconds)
    GROUP BY
        CASE WHEN a.seconds IS NULL OR b.seconds IS NULL
             THEN 'EFFECTIVE_TIME_UNPARSEABLE'
             ELSE 'RANK_EFFECTIVE_TIME_NOT_MONOTONIC' END,
        a.event_id, a.event_name, a.tournament_stage_name
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = {{SPORT_ID}}
WHERE e.del = 'no'
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND EXISTS (
      SELECT 1 FROM object_discipline od
      WHERE od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
        AND od.disciplineFK IN ({{TIMED_DISCIPLINE_LIST}})
  )
  AND (
      SELECT COUNT(DISTINCT ep.id)
      FROM event_participants ep
      JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
           AND r.result_typeFK IN ({{RESULT_DURATION_TYPE_ID}}, {{RESULT_FULL_TIME_TYPE_ID}})
           AND TRIM(COALESCE(r.value, '')) <> ''
      WHERE ep.eventFK = e.id AND ep.del = 'no'
        AND EXISTS (
            SELECT 1 FROM result rr
            WHERE rr.event_participantsFK = ep.id AND rr.del = 'no'
              AND rr.result_typeFK = {{RESULT_RANK_TYPE_ID}}
              AND TRIM(COALESCE(rr.value, '')) <> ''
        )
  ) >= 2

ORDER BY sort_order, event_id;
