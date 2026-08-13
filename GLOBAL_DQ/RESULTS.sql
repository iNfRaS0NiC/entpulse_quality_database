SELECT
    -- CheckID - GLOBAL-DQ-017
    -- Name - EVENT_RESULTS_MISSING_FOR_FINISHED
    -- What it does: Finds finished events (status_descFK=6) where no participant holds a result.
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-018
    -- Name - EVENT_RESULTS_MEDAL_INVALID_VALUE
    -- What it does: Finds event-participant Medal values that are not gold, silver or bronze.
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND r.value IS NOT NULL
  AND TRIM(r.value) <> ''
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-019
    -- Name - EVENT_DURATION_FORMAT_MISMATCH_TO_RANK
    -- What it does: Finds events where a participant's duration breaks the leader/gap convention: rank 1 must be a plain absolute time, every other rank a plus-prefixed gap.
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND TRIM(rk.value) <> ''
  AND TRIM(dur.value) <> ''
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-020
    -- Name - EVENT_RESULTS_RANK_OUTLIER_ABOVE_FIELD_SIZE
    -- What it does: Finds finished events holding a Rank that exceeds the participant count and is disconnected from the next lower Rank, with no Comment to explain it, naming how many of the field are affected and what they hold.
    'RANK_OUTLIER_ABOVE_FIELD_SIZE' AS check_type,
    z.event_id,
    z.event_name,
    z.template_name,
    z.participant_count,
    z.affected_count,
    -- The ranks themselves, deduplicated. A field imported with every place shifted reads as
    -- one list here where it read as one row per competitor before the reshape of 2026-08-13,
    -- and the shift is visible in the list rather than reconstructed from the rows.
    z.ranks_held,
    -- A convenience for the reader, not the finding: GROUP_CONCAT truncates at the server's
    -- group_concat_max_len without saying so, and affected_count is counted separately and is
    -- what the row asserts.
    z.affected_participants,
    NULL AS eligible_count,
    0 AS sort_order
FROM (
    -- Grouped to the event, which is the audited object: a rank above the field size is
    -- normally a whole field imported wrong rather than one competitor, so reported per
    -- competitor it counted the same import once per name in it.
    SELECT
        y.event_id,
        y.event_name,
        y.template_name,
        MAX(y.participant_count) AS participant_count,
        COUNT(*) AS affected_count,
        GROUP_CONCAT(DISTINCT y.rank_value ORDER BY y.rank_value SEPARATOR ', ') AS ranks_held,
        GROUP_CONCAT(DISTINCT CONCAT(y.participant_name, ' (', y.rank_value, ')')
            ORDER BY CONCAT(y.participant_name, ' (', y.rank_value, ')') SEPARATOR ', ')
            AS affected_participants
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
          AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
          -- AND t.tournament_templateFK = <tournament_template_id>
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
    GROUP BY y.event_id, y.event_name, y.template_name
) z

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, affected_count DESC, event_id;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-021
    -- Name - EVENT_RESULTS_RANK_DUPLICATE_WITHOUT_COMMENT
    -- What it does: Finds event participants in finished events sharing a Rank with another where neither row carries a Comment and the values the sport ranks on do not account for the tie, separating a tie whose values disagree from one with no value stored at all.
    CASE
        WHEN tie.rows_with_any_value = 0 THEN 'RANK_DUPLICATE_WITHOUT_VALUE'
        ELSE 'RANK_DUPLICATE_VALUES_DISAGREE'
    END AS check_type,
    ep.id AS event_participants_id,
    e.id AS event_id,
    e.name AS event_name,
    tt.name AS template_name,
    p.name AS participant_name,
    CAST(r.value AS UNSIGNED) AS rank_value,
    tie.tied_count AS unexplained_duplicate_count,
    NULL AS eligible_count
-- A tie the sport actually contested is not a defect, and the database can say which is which.
-- Where every participant sharing a rank also carries the same value on one of the fields the
-- sport ranks by, the duplicate is the result: two gymnasts on the same score share a place, two
-- triathletes on the same time cross together. Only a duplicate the values fail to account for
-- is reported.
-- RESULT_TIE_VALUE_TYPE_LIST names those fields, and it is a list rather than one field because
-- a sport may rank on more than one and store them unevenly. A tie is accounted for when the
-- whole tied group agrees on at least one of the declared fields; agreement on one is enough,
-- since any one of them being equal is the tie.
-- Every tied row must carry the field, not merely the ones that have it. A group of three where
-- two share a time and the third has none is not accounted for, because nothing says why the
-- third is there.
-- Where no tied row carries any declared value the finding stands and says so in its own
-- verdict. Nothing justifies the duplicate, which is a different thing from values that
-- disagree, and the two are repaired differently.
-- Values are compared as quantities where they are numbers, so 13.800 and 13.8 are one value
-- rather than two. A value that is not a plain number - a stored time such as 1:27:05.000 -
-- keeps its own identity as text.
-- The eligible population is every event whose status_type is finished, not only the one
-- carrying the plain finished detail. A contest decided after extra time or awarded on appeal
-- is finished and its ranking is as assertable as any other; restricting to the one detail
-- silently dropped those events. This absorbs GLOBAL-DQ-116, which asked the same question of
-- a single score over exactly this population and is superseded here.
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
JOIN (
    -- One row per event and shared rank, counting only the participants that carry no Comment,
    -- with how many of the declared value fields the whole group agrees on. Built once for the
    -- sport rather than asked again for every row, because the same tie is read by each of its
    -- own members.
    SELECT sz.event_id, sz.rank_value, sz.tied_count,
           COALESCE(MAX(va.rows_with_value), 0) AS rows_with_any_value,
           COALESCE(SUM(CASE WHEN va.rows_with_value = sz.tied_count AND va.distinct_values = 1
                             THEN 1 ELSE 0 END), 0) AS agreeing_value_types
    FROM (
        SELECT ep2.eventFK AS event_id,
               CAST(r2.value AS UNSIGNED) AS rank_value,
               COUNT(DISTINCT ep2.id) AS tied_count
        FROM event_participants ep2
        JOIN event e2 ON e2.id = ep2.eventFK AND e2.del = 'no'
        JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
        JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
        JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
        JOIN result r2 ON r2.event_participantsFK = ep2.id
             AND r2.result_typeFK = {{RESULT_RANK_TYPE_ID}}
             AND r2.del = 'no'
             AND r2.value REGEXP '^[1-9][0-9]*$'
        WHERE ep2.del = 'no'
          AND tt2.sportFK = {{SPORT_ID}}
          AND e2.status_type = 'finished'
          AND t2.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
          -- AND t2.tournament_templateFK = <tournament_template_id>
          -- AND e2.startdate >= '<from_datetime>'
          -- AND e2.startdate <  '<to_datetime>'
          AND NOT EXISTS (
              SELECT 1
              FROM result rc2
              WHERE rc2.event_participantsFK = ep2.id
                AND rc2.result_typeFK = {{RESULT_COMMENT_TYPE_ID}}
                AND rc2.del = 'no'
                AND rc2.value IS NOT NULL
                AND TRIM(rc2.value) <> ''
          )
        GROUP BY ep2.eventFK, CAST(r2.value AS UNSIGNED)
        HAVING tied_count >= 2
    ) sz
    LEFT JOIN (
        SELECT ep4.eventFK AS event_id,
               CAST(r4.value AS UNSIGNED) AS rank_value,
               rv.result_typeFK AS value_type,
               COUNT(DISTINCT ep4.id) AS rows_with_value,
               COUNT(DISTINCT CASE
                         WHEN TRIM(rv.value) REGEXP '^-?[0-9]+([.][0-9]+)?$'
                              THEN CAST(CAST(TRIM(rv.value) AS DECIMAL(20,6)) AS CHAR)
                         ELSE NULLIF(TRIM(rv.value), '')
                     END) AS distinct_values
        FROM event_participants ep4
        JOIN event e4 ON e4.id = ep4.eventFK AND e4.del = 'no'
        JOIN tournament_stage ts4 ON ts4.id = e4.tournament_stageFK AND ts4.del = 'no'
        JOIN tournament t4 ON t4.id = ts4.tournamentFK AND t4.del = 'no'
        JOIN tournament_template tt4 ON tt4.id = t4.tournament_templateFK AND tt4.del = 'no'
        JOIN result r4 ON r4.event_participantsFK = ep4.id
             AND r4.result_typeFK = {{RESULT_RANK_TYPE_ID}}
             AND r4.del = 'no'
             AND r4.value REGEXP '^[1-9][0-9]*$'
        JOIN result rv ON rv.event_participantsFK = ep4.id
             AND rv.result_typeFK IN ({{RESULT_TIE_VALUE_TYPE_LIST}})
             AND rv.del = 'no'
             AND rv.value IS NOT NULL
             AND TRIM(rv.value) <> ''
        WHERE ep4.del = 'no'
          AND tt4.sportFK = {{SPORT_ID}}
          AND e4.status_type = 'finished'
          AND t4.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
          -- AND t4.tournament_templateFK = <tournament_template_id>
          -- AND e4.startdate >= '<from_datetime>'
          -- AND e4.startdate <  '<to_datetime>'
          AND NOT EXISTS (
              SELECT 1
              FROM result rc4
              WHERE rc4.event_participantsFK = ep4.id
                AND rc4.result_typeFK = {{RESULT_COMMENT_TYPE_ID}}
                AND rc4.del = 'no'
                AND rc4.value IS NOT NULL
                AND TRIM(rc4.value) <> ''
          )
        GROUP BY ep4.eventFK, CAST(r4.value AS UNSIGNED), rv.result_typeFK
    ) va ON va.event_id = sz.event_id AND va.rank_value = sz.rank_value
    GROUP BY sz.event_id, sz.rank_value, sz.tied_count
) tie ON tie.event_id = e.id AND tie.rank_value = CAST(r.value AS UNSIGNED)
WHERE ep.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND e.status_type = 'finished'
  AND tie.agreeing_value_types = 0
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-036
    -- Name - EVENT_RESULTS_RANK_INVALID_OR_MISSING
    -- What it does: Finds event participants in finished events whose Rank is not a plain positive integer up to the sport's maximum, or is missing with no Comment either, separating a participant holding no result at all from one holding another.
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      -- AND t.tournament_templateFK = <tournament_template_id>
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-037
    -- Name - EVENT_RESULTS_MEDAL_SET_INVALID_FOR_FINAL
    -- What it does: Finds finished Final-round events whose Medal set does not follow the places its own Rank results hold, separating an unreadable set, no medals at all, a duplicate contradicted by the place below it, a duplicate shaped like a tie, a duplicated bronze, a shared place carrying too few medals and a missing type.
    CASE
        -- Nothing to compare the medals with. The missing Rank is GLOBAL-DQ-036's finding and
        -- is not restated here; what this row says is that the medal set was not audited.
        WHEN x.ranked_count = 0 THEN 'Medal_Set_Unreadable_Without_Rank'
        WHEN x.total_medal_count = 0 THEN 'No_Medals_At_All'
        -- A shared place removes the place below it, so a second gold beside a silver is a
        -- contradiction, while a second gold without one is the shape a tie actually takes.
        -- The expectation is read from the places themselves rather than assumed to be one
        -- each: a place held by two competitors is owed two medals, and a place nobody holds
        -- is owed none.
        WHEN x.gold_count > x.rank1_count AND x.silver_count > 0 THEN 'Duplicate_Gold_With_Silver_Present'
        WHEN x.silver_count > x.rank2_count AND x.bronze_count > 0 THEN 'Duplicate_Silver_With_Bronze_Present'
        WHEN x.gold_count > x.rank1_count OR x.silver_count > x.rank2_count THEN 'Duplicate_Medal_Tie_Shape'
        WHEN x.bronze_count > x.rank3_count THEN 'Duplicate_Bronze'
        -- The other side of a tie: the place is shared and carries a medal, but not one for
        -- every competitor standing on it.
        WHEN (x.rank1_count > 1 AND x.gold_count   BETWEEN 1 AND x.rank1_count - 1)
          OR (x.rank2_count > 1 AND x.silver_count BETWEEN 1 AND x.rank2_count - 1)
          OR (x.rank3_count > 1 AND x.bronze_count BETWEEN 1 AND x.rank3_count - 1)
             THEN 'Medal_Missing_For_Shared_Place'
        ELSE 'Missing_Specific_Medal'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.template_name,
    x.tournament_name,
    x.stage_name,
    CONCAT_WS(', ',
        IF(x.rank1_count > 0, CONCAT('1st x', x.rank1_count), NULL),
        IF(x.rank2_count > 0, CONCAT('2nd x', x.rank2_count), NULL),
        IF(x.rank3_count > 0, CONCAT('3rd x', x.rank3_count), NULL)
    ) AS places_held,
    CONCAT_WS(', ',
        IF(x.gold_count   < x.rank1_count, CONCAT('gold ',   x.gold_count,   ' of ', x.rank1_count), NULL),
        IF(x.silver_count < x.rank2_count, CONCAT('silver ', x.silver_count, ' of ', x.rank2_count), NULL),
        IF(x.bronze_count < x.rank3_count, CONCAT('bronze ', x.bronze_count, ' of ', x.rank3_count), NULL)
    ) AS missing_medals,
    CONCAT_WS(', ',
        IF(x.gold_count   > x.rank1_count, CONCAT('gold x',   x.gold_count,   ' for ', x.rank1_count), NULL),
        IF(x.silver_count > x.rank2_count, CONCAT('silver x', x.silver_count, ' for ', x.rank2_count), NULL),
        IF(x.bronze_count > x.rank3_count, CONCAT('bronze x', x.bronze_count, ' for ', x.rank3_count), NULL)
    ) AS duplicated_medals,
    NULL AS eligible_count
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        ts.name AS stage_name,
        -- Counted per competitor rather than per result row, so a place and a medal are each
        -- read once however many rows the participant carries. The place is matched on the
        -- literal figure, which GLOBAL-DQ-036 is what asserts is a plain positive integer.
        COUNT(DISTINCT CASE WHEN r.result_typeFK = {{RESULT_RANK_TYPE_ID}} AND TRIM(r.value) <> '' THEN ep.id END) AS ranked_count,
        COUNT(DISTINCT CASE WHEN r.result_typeFK = {{RESULT_RANK_TYPE_ID}} AND TRIM(r.value) = '1' THEN ep.id END) AS rank1_count,
        COUNT(DISTINCT CASE WHEN r.result_typeFK = {{RESULT_RANK_TYPE_ID}} AND TRIM(r.value) = '2' THEN ep.id END) AS rank2_count,
        COUNT(DISTINCT CASE WHEN r.result_typeFK = {{RESULT_RANK_TYPE_ID}} AND TRIM(r.value) = '3' THEN ep.id END) AS rank3_count,
        COUNT(DISTINCT CASE WHEN r.result_typeFK = {{RESULT_MEDAL_TYPE_ID}} AND LOWER(TRIM(r.value)) = 'gold' THEN ep.id END) AS gold_count,
        COUNT(DISTINCT CASE WHEN r.result_typeFK = {{RESULT_MEDAL_TYPE_ID}} AND LOWER(TRIM(r.value)) = 'silver' THEN ep.id END) AS silver_count,
        COUNT(DISTINCT CASE WHEN r.result_typeFK = {{RESULT_MEDAL_TYPE_ID}} AND LOWER(TRIM(r.value)) = 'bronze' THEN ep.id END) AS bronze_count,
        COUNT(DISTINCT CASE WHEN r.result_typeFK = {{RESULT_MEDAL_TYPE_ID}} AND TRIM(r.value) <> '' THEN ep.id END) AS total_medal_count
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    LEFT JOIN result r
      ON r.event_participantsFK = ep.id
     AND r.del = 'no'
     AND r.result_typeFK IN ({{RESULT_MEDAL_TYPE_ID}}, {{RESULT_RANK_TYPE_ID}})
    WHERE e.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      AND e.round_typeFK IN ({{FINAL_ROUND_TYPE_LIST}})
      AND e.status_type = 'finished'
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY e.id, e.name, tt.name, t.name, ts.name
) x
WHERE x.ranked_count = 0
   OR x.gold_count   <> x.rank1_count
   OR x.silver_count <> x.rank2_count
   OR x.bronze_count <> x.rank3_count

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND e.round_typeFK IN ({{FINAL_ROUND_TYPE_LIST}})
  AND e.status_type = 'finished'
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-039
    -- Name - EVENT_RESULTS_UNEXPECTED_MEDAL_FOR_NON_MEDAL_ROUND
    -- What it does: Finds finished events off a medal round type that carry a Medal result.
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-045
    -- Name - EVENT_DURATION_FULL_TIME_MISMATCH_TO_RANK
    -- What it does: Finds finished events in the sport's timed disciplines where a participant's full time is missing despite a Rank, present without one, badly formatted, or zero.
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      -- AND t.tournament_templateFK = <tournament_template_id>
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
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
    -- What it does: Finds events in a not-started status that carry a result.
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;



-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-052
    -- Name - EVENT_RESULTS_COMMENT_INVALID_OR_CONTRADICTED
    -- What it does: Finds Comment values outside the sport's status codes, or marking a participant as unclassified while a Rank, a time or a Medal is stored for that same participant.
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      -- AND t.tournament_templateFK = <tournament_template_id>
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-053
    -- Name - EVENT_RESULTS_MEDAL_RANK_MISMATCH
    -- What it does: Finds event participants whose Medal does not match the place it stands for, or that carry no Rank at all.
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      -- AND t.tournament_templateFK = <tournament_template_id>
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-054
    -- Name - EVENT_RESULTS_RANK_FULL_TIME_NOT_MONOTONIC
    -- What it does: Finds events in the sport's timed disciplines holding a pair whose Rank order contradicts their full-time order, so a better-ranked competitor is recorded as slower.
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      -- AND t.tournament_templateFK = <tournament_template_id>
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      -- AND t.tournament_templateFK = <tournament_template_id>
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
    -- What it does: Finds events where one participant holds more than one participant row, so the same competitor is entered twice.
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      -- AND t.tournament_templateFK = <tournament_template_id>
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-056
    -- Name - EVENT_DURATION_FULL_TIME_ARITHMETIC_MISMATCH
    -- What it does: Finds events in the sport's timed disciplines where a participant's full time does not equal the leader's full time plus their own gap, beyond the sport's tolerance.
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      -- AND t.tournament_templateFK = <tournament_template_id>
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
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
    -- What it does: Finds events holding more than one result row for the same participant and result type, separating a duplicate repeating the value from one storing a conflicting one.
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      -- AND t.tournament_templateFK = <tournament_template_id>
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-069
    -- Name - EVENT_RESULTS_VALUE_BLANK
    -- What it does: Finds result values that are neither empty nor readable, made only of ordinary spacing or only of invisible characters, separating the two.
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      -- AND t.tournament_templateFK = <tournament_template_id>
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, blank_result_count DESC;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-076
    -- Name - EVENT_RESULTS_NUMERIC_FIELD_NON_NUMERIC
    -- What it does: Finds events holding non-numeric values in the sport's numeric result fields, separating one of the sport's own status codes, a no-data sentinel such as nan, a number written with thousands separators, and any other text, and naming how many values are affected and what they hold.
    x.check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.template_name,
    x.tournament_name,
    -- The result type is named rather than numbered. A reader repairing the field has to know
    -- which field it is, and the id alone sends them back to the catalogue for every row.
    x.result_type_names,
    x.affected_count,
    x.affected_participant_count,
    -- What the field actually holds, deduplicated. An event whose whole stroke-play field
    -- stores the same sentinel is one thing to fix, and the distinct list says so in one cell
    -- where a hundred rows said it a hundred times.
    x.distinct_values,
    -- A convenience for the reader, not the finding: GROUP_CONCAT truncates at the server's
    -- group_concat_max_len without saying so, and affected_count is counted separately and is
    -- what the row asserts.
    x.affected_participants,
    NULL AS eligible_count,
    0 AS sort_order
FROM (
    SELECT
        y.check_type,
        y.event_id,
        y.event_name,
        y.event_startdate,
        y.template_name,
        y.tournament_name,
        GROUP_CONCAT(DISTINCT y.result_type_name ORDER BY y.result_type_name SEPARATOR ', ')
            AS result_type_names,
        COUNT(*) AS affected_count,
        COUNT(DISTINCT y.event_participants_id) AS affected_participant_count,
        GROUP_CONCAT(DISTINCT y.stored_value ORDER BY y.stored_value SEPARATOR ', ')
            AS distinct_values,
        GROUP_CONCAT(DISTINCT y.participant_name ORDER BY y.participant_name SEPARATOR ', ')
            AS affected_participants
    FROM (
        -- One row per offending result value, grouped to the event below. The event is the
        -- audited object because a field-wide storage habit is one thing to repair: a
        -- stroke-play event storing the same sentinel for every competitor reported once per
        -- competitor, which on Golf turned 1895 events into 16452 rows. The four states stay
        -- separate check_types because they are repaired differently, so an event holding two
        -- of them is two findings and not one.
        SELECT
            CASE
                WHEN LOWER(TRIM(r.value)) IN ({{RESULT_COMMENT_VALUE_LIST}}) THEN 'STATUS_CODE_IN_NUMERIC_FIELD'
                WHEN LOWER(TRIM(r.value)) IN ('nan', 'null', 'n/a', 'na', '-', '--', '?', 'none') THEN 'SENTINEL_IN_NUMERIC_FIELD'
                -- A grouped number is a number that was written for a reader rather than
                -- stored for one, and it needs a different repair from text: the digits are
                -- right and only the separators have to go.
                WHEN TRIM(r.value) REGEXP '^[-+]?[0-9]{1,3}(,[0-9]{3})+([.][0-9]+)?$' THEN 'GROUPED_NUMBER_IN_NUMERIC_FIELD'
                ELSE 'TEXT_IN_NUMERIC_FIELD'
            END AS check_type,
            e.id AS event_id,
            e.name AS event_name,
            e.startdate AS event_startdate,
            tt.name AS template_name,
            t.name AS tournament_name,
            rt.name AS result_type_name,
            ep.id AS event_participants_id,
            p.name AS participant_name,
            r.value AS stored_value
        FROM event_participants ep
        JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
        JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
        JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
         AND r.result_typeFK IN ({{NUMERIC_RESULT_TYPE_LIST}})
        LEFT JOIN result_type rt ON rt.id = r.result_typeFK
        WHERE ep.del = 'no'
          AND tt.sportFK = {{SPORT_ID}}
          AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
          -- AND t.tournament_templateFK = <tournament_template_id>
          -- AND e.startdate >= '<from_datetime>'
          -- AND e.startdate <  '<to_datetime>'
          AND r.value IS NOT NULL
          AND TRIM(r.value) <> ''
          -- The mirror of GLOBAL-DQ-052, which asks whether the status vocabulary holds a
          -- value it should not. This asks the opposite: whether a status leaked into a field
          -- that carries a measured quantity, where no reader of that field will look for one.
          --
          -- The sign is part of the number. A score written against a reference rather than
          -- from zero is stored signed in both directions - golf's Total Par holds +2 as
          -- readily as -2 - and a pattern accepting only the minus reported every positive one
          -- as text: 9347 of Golf's 16452 findings were correct data the rule could not read.
          AND TRIM(r.value) NOT REGEXP '^[-+]?[0-9]+([.,][0-9]+)?$'
    ) y
    GROUP BY
        y.check_type,
        y.event_id,
        y.event_name,
        y.event_startdate,
        y.template_name,
        y.tournament_name
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event_participants ep
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
 AND r.result_typeFK IN ({{NUMERIC_RESULT_TYPE_LIST}})
WHERE ep.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND r.value IS NOT NULL
  AND TRIM(r.value) <> ''

ORDER BY sort_order, affected_count DESC, event_id;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-084
    -- Name - EVENT_RESULT_SCORE_TIED
    -- What it does: Finds head-to-head events whose two participants hold an identical deciding score, so no winner can be read, separating a tie on a zero score from one on a played score.
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
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
    -- What it does: Finds participants whose period-by-period scope values do not add up to their deciding score, separating a total above the sum of its periods from one below it.
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
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
    -- What it does: Finds scope period values that are neither a non-negative number nor one of the sport's sentinels, separating empty active rows, negative numbers and unrecognised tokens.
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_startdate DESC;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-088
    -- Name - EVENT_WINNER_CONTRADICTS_SCORE
    -- What it does: Finds finished head-to-head events whose Winner names the lower-scoring side, or names a side at all while the two scores are equal.
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND LOWER(TRIM(pr.value)) IN ({{WINNER_HOME_VALUE_LIST}}, {{WINNER_AWAY_VALUE_LIST}})

ORDER BY sort_order, event_startdate DESC;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-090
    -- Name - EVENT_RESULT_MIRRORED_SCORE_TYPES_DISAGREE
    -- What it does: Finds events whose participants' two mirrored score types disagree, separating a pair holding different values from one where a side of the pair is absent, and naming how many of the field are affected and who they are.
    x.check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.template_name,
    x.tournament_name,
    x.status_descFK,
    x.field_size,
    x.affected_count,
    -- A convenience for the reader, not the finding: each entry is the participant with the
    -- pair as stored, primary/mirror, a dash standing for the absent side. GROUP_CONCAT
    -- truncates at the server's group_concat_max_len without saying so, and affected_count is
    -- counted separately and is what the row asserts.
    x.affected_participants,
    NULL AS eligible_count,
    0 AS sort_order
FROM (
    SELECT
        y.check_type,
        y.event_id,
        y.event_name,
        y.event_startdate,
        y.template_name,
        y.tournament_name,
        y.status_descFK,
        MAX(y.field_size) AS field_size,
        COUNT(*) AS affected_count,
        GROUP_CONCAT(y.participant_label ORDER BY y.participant_label SEPARATOR ', ')
            AS affected_participants
    FROM (
        -- One row per participant whose pair disagrees, grouped to the event below. The event
        -- is the audited object: in a head-to-head sport a score the import never wrote is
        -- missing on both sides at once, so reported per participant the same defect counted
        -- twice - measured on Curling, 29 of 30 events reported exactly two rows. The three
        -- states stay separate check_types because they are repaired differently, so an event
        -- holding two of them is two findings and not one.
        SELECT
            CASE
                WHEN r_primary.id IS NULL THEN 'PRIMARY_SCORE_MISSING'
                WHEN r_mirror.id IS NULL THEN 'MIRROR_SCORE_MISSING'
                ELSE 'MIRRORED_VALUES_DIFFER'
            END AS check_type,
            e.id AS event_id,
            e.name AS event_name,
            e.startdate AS event_startdate,
            tt.name AS template_name,
            t.name AS tournament_name,
            e.status_descFK,
            (
                SELECT COUNT(DISTINCT ep2.id)
                FROM event_participants ep2
                WHERE ep2.eventFK = e.id AND ep2.del = 'no'
            ) AS field_size,
            CONCAT(p.name, ' (', COALESCE(r_primary.value, '-'), '/',
                   COALESCE(r_mirror.value, '-'), ')') AS participant_label
        FROM event_participants ep
        JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
        JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
        -- Both joins are left outer, because one of the pair being absent is the finding rather
        -- than a reason to drop the row: an absent result row and a differing value are separate
        -- storage states (DB-SEM-002) and they are repaired differently.
        LEFT JOIN result r_primary ON r_primary.event_participantsFK = ep.id AND r_primary.del = 'no'
                                  AND r_primary.result_typeFK = {{RESULT_FINAL_SCORE_TYPE_ID}}
        LEFT JOIN result r_mirror  ON r_mirror.event_participantsFK = ep.id AND r_mirror.del = 'no'
                                  AND r_mirror.result_typeFK = {{RESULT_MIRROR_SCORE_TYPE_ID}}
        WHERE ep.del = 'no'
          AND tt.sportFK = {{SPORT_ID}}
          AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
          -- AND t.tournament_templateFK = <tournament_template_id>
          -- AND e.startdate >= '<from_datetime>'
          -- AND e.startdate <  '<to_datetime>'
          AND (r_primary.id IS NOT NULL OR r_mirror.id IS NOT NULL)
          AND (
              r_primary.id IS NULL
              OR r_mirror.id IS NULL
              OR TRIM(r_primary.value) <> TRIM(r_mirror.value)
          )
    ) y
    GROUP BY y.check_type, y.event_id, y.event_name, y.event_startdate,
             y.template_name, y.tournament_name, y.status_descFK
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_startdate DESC;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-091
    -- Name - EVENT_SCOPE_PERIOD_NOT_STORED_FOR_BOTH_SIDES
    -- What it does: Finds events where a period is stored for some participants but not all, or twice for one, so the two sides disagree about which periods exist.
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_startdate DESC;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-092
    -- Name - EVENT_SCOPE_PERIOD_SENTINEL_NOT_TRAILING
    -- What it does: Finds events whose unplayed-period sentinel is contradicted by its neighbours: a scored period after a participant's own first sentinel, or one side marking a period unplayed while the other scores it.
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_startdate DESC;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-093
    -- Name - EVENT_RESULTS_MEDAL_SET_INVALID_FOR_MEDAL_ROUND
    -- What it does: Finds finished medal-round events whose Medal set is not what the round decides - gold and silver on a Final, bronze on a bronze match - separating no medal at all, a medal the round does not decide, a repeated type and a missing one.
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      -- AND t.tournament_templateFK = <tournament_template_id>
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_startdate DESC;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-094
    -- Name - EVENT_RESULTS_MEDAL_CONTRADICTS_SCORE
    -- What it does: Finds participants on a medal round whose Medal does not match the place their own score gives them, separating a missing medal, one stored where the round awards none, and one naming the wrong place.
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      -- AND t.tournament_templateFK = <tournament_template_id>
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_startdate DESC;

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-102
    -- Name - EVENT_SCOPE_RESULT_OWNER_EVENT_MISMATCH
    -- What it does: Finds scope results naming an event participant from a different event, or one that is not active, so the value is attached to a competitor who did not play it.
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
         AND es.scope_typeFK IN ({{SCOPE_TYPE_LIST}})
    JOIN event e ON e.id = es.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = {{SPORT_ID}}
    LEFT JOIN event_participants ep ON ep.id = sr.event_participantsFK AND ep.del = 'no'
    WHERE sr.del = 'no'
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      -- AND t.tournament_templateFK = <tournament_template_id>
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
     AND es.scope_typeFK IN ({{SCOPE_TYPE_LIST}})
JOIN event e ON e.id = es.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = {{SPORT_ID}}
WHERE sr.del = 'no'
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_id;

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-107
    -- Name - EVENT_SCOPE_CONTAINER_MISSING_FOR_FINISHED
    -- What it does: Finds finished events holding no scope container, so a match that was played records no period-by-period breakdown.
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_id;

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-108
    -- Name - EVENT_RESULTS_SCORE_NEGATIVE_OR_FRACTIONAL
    -- What it does: Finds deciding or mirrored score values that are negative or carry a fractional part, so a count of scoring units is stored as something no count can be.
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      -- AND t.tournament_templateFK = <tournament_template_id>
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_id, event_participants_id;

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-111
    -- Name - EVENT_RESULTS_RANK_EFFECTIVE_TIME_NOT_MONOTONIC
    -- What it does: Finds events in the sport's timed disciplines where a finisher placed behind another records a faster time, or whose effective time cannot be read at all - the Full time where stored, the Duration otherwise - ignoring participants a Comment marks as not finishing.
    CASE
        WHEN x.unreadable_count > 0 AND x.non_monotonic_pair_count > 0
            THEN 'EFFECTIVE_TIME_UNPARSEABLE_AND_NOT_MONOTONIC'
        WHEN x.unreadable_count > 0 THEN 'EFFECTIVE_TIME_UNPARSEABLE'
        ELSE 'RANK_EFFECTIVE_TIME_NOT_MONOTONIC'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.tournament_stage_name,
    x.unreadable_count + x.non_monotonic_pair_count AS offending_count,
    COALESCE(x.sample_unreadable, x.sample_non_monotonic) AS sample_offence,
    NULL AS eligible_count,
    0 AS sort_order
-- The Duration column follows the leader/gap convention: the leader carries an absolute time
-- and everyone behind carries a gap to it, marked by a leading plus. SPORTS/BMX.md owns that
-- statement for BMX. The Full time is preferred where one is stored only because it is
-- unambiguously absolute; for a sport that populates it thinly, as BMX does over nine events,
-- almost every row is read from Duration and the convention is what matters.
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
-- The participant dataset below is also the coverage scope: a ranked participant carrying
-- an effective time, excluding every Comment value that means they did not finish. Every
-- unreadable value is counted directly from the left side before any pair is required; the
-- self-join exists only for readable same-kind values whose ranks differ. The outer aggregate
-- then collapses both possible violation kinds to one row for their event.
FROM (
    SELECT
        a.event_id,
        MAX(a.event_name) AS event_name,
        MAX(a.tournament_stage_name) AS tournament_stage_name,
        COUNT(DISTINCT CASE WHEN a.seconds IS NULL THEN a.ep_id END) AS unreadable_count,
        COUNT(DISTINCT CASE
            WHEN a.seconds IS NOT NULL AND b.seconds IS NOT NULL AND b.seconds < a.seconds
            THEN CONCAT(a.ep_id, ':', b.ep_id)
        END) AS non_monotonic_pair_count,
        MIN(CASE WHEN a.seconds IS NULL
            THEN CONCAT('rank ', a.rank_value, ' = ', a.effective_raw)
        END) AS sample_unreadable,
        MIN(CASE
            WHEN a.seconds IS NOT NULL AND b.seconds IS NOT NULL AND b.seconds < a.seconds
            THEN CONCAT('rank ', a.rank_value, ' = ', a.effective_raw,
                        ' vs rank ', b.rank_value, ' = ', b.effective_raw)
        END) AS sample_non_monotonic
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
          AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
          -- AND t.tournament_templateFK = <tournament_template_id>
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
    LEFT JOIN (
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
          AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
          -- AND t.tournament_templateFK = <tournament_template_id>
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
     AND a.seconds IS NOT NULL
     AND b.seconds IS NOT NULL
     AND b.seconds < a.seconds
    GROUP BY a.event_id
    HAVING unreadable_count > 0 OR non_monotonic_pair_count > 0
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT eligible.event_id) AS eligible_count,
    1 AS sort_order
FROM (
    -- Coverage deliberately counts the whole format-audit population, not only events that
    -- happen to offer a monotonic comparison. This is the same ranked-finisher/effective-time
    -- dataset as the findings branch, including the no-result Comment exclusion below. A
    -- single unreadable time therefore cannot become a finding outside coverage, while an
    -- event with only one readable time is truthfully covered for format but not compared.
    SELECT DISTINCT
        c.event_id
    FROM (
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
          AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
          -- AND t.tournament_templateFK = <tournament_template_id>
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
    ) c
) eligible

ORDER BY sort_order, event_id;

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-114
    -- Name - EVENT_RESULTS_MIRROR_SCORE_WITHOUT_DECIDING_SCORE
    -- What it does: Finds finished events holding a running or mirrored score while no participant holds the deciding score, so the event was scored but never resolved.
    'Event_Mirror_Score_Without_Deciding_Score' AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    ts.name AS tournament_stage_name,
    tt.name AS template_name,
    YEAR(e.startdate) AS event_year,
    NULL AS eligible_count,
    0 AS sort_order
-- Not what GLOBAL-DQ-017 asks. That one reports a finished event with no result at all,
-- so an event holding a running score leaves its population and is never seen again. The
-- partially written event is the harder case precisely because it looks populated: a
-- consumer reading the deciding score finds nothing and a consumer reading the running
-- score finds a match that appears to have been played.
-- Asked at event level rather than per participation, because a deciding score is a
-- property of the event: one side holding it and the other not is a different defect, and
-- GLOBAL-DQ-091 already asks that of the scope layer.
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = {{SPORT_ID}}
WHERE e.del = 'no'
  AND e.status_type = 'finished'
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND EXISTS (
      SELECT 1 FROM result rm
      JOIN event_participants epm ON epm.id = rm.event_participantsFK AND epm.del = 'no'
      WHERE epm.eventFK = e.id AND rm.del = 'no'
        AND rm.result_typeFK = {{RESULT_MIRROR_SCORE_TYPE_ID}}
        AND TRIM(COALESCE(rm.value, '')) <> ''
  )
  AND NOT EXISTS (
      SELECT 1 FROM result rf
      JOIN event_participants epf ON epf.id = rf.event_participantsFK AND epf.del = 'no'
      WHERE epf.eventFK = e.id AND rf.del = 'no'
        AND rf.result_typeFK = {{RESULT_FINAL_SCORE_TYPE_ID}}
        AND TRIM(COALESCE(rf.value, '')) <> ''
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND EXISTS (
      SELECT 1 FROM result rc
      JOIN event_participants epc ON epc.id = rc.event_participantsFK AND epc.del = 'no'
      WHERE epc.eventFK = e.id AND rc.del = 'no'
        AND rc.result_typeFK IN ({{RESULT_FINAL_SCORE_TYPE_ID}}, {{RESULT_MIRROR_SCORE_TYPE_ID}})
        AND TRIM(COALESCE(rc.value, '')) <> ''
  )

ORDER BY sort_order, event_id;

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-116
    -- Name - EVENT_RESULTS_RANK_TIE_CONTRADICTED_BY_SCORE
    -- What it does: Finds event participants sharing a Rank with another in a finished event while the score that decides the ranking does not agree across the tie, separating a tie whose scores differ from one where a tied participant holds no score at all.
    'RANK_TIE_SCORE_DIFFERS' AS check_type,
    ep.id AS event_participants_id,
    e.id AS event_id,
    e.name AS event_name,
    tt.name AS template_name,
    p.name AS participant_name,
    CAST(r.value AS UNSIGNED) AS rank_value,
    NULLIF(TRIM(COALESCE(rs.value, '')), '') AS score_value,
    g.distinct_scores AS distinct_scores_at_rank,
    NULL AS eligible_count,
    0 AS sort_order
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
LEFT JOIN result rs ON rs.event_participantsFK = ep.id
     AND rs.result_typeFK = {{RESULT_SCORE_TYPE_ID}}
     AND rs.del = 'no'
JOIN (
    SELECT ep2.eventFK AS event_id,
           CAST(r2.value AS UNSIGNED) AS rank_value,
           COUNT(DISTINCT ep2.id) AS tied_count,
           -- Compared as a quantity where the value is one, so 13.800 and 13.8 are one score
           -- rather than two. A value that is not a plain number stays text and keeps its own
           -- identity, which a sport storing a status word in its score field depends on.
           COUNT(DISTINCT CASE
                     WHEN TRIM(rs2.value) REGEXP '^-?[0-9]+([.][0-9]+)?$'
                          THEN CAST(CAST(TRIM(rs2.value) AS DECIMAL(20,6)) AS CHAR)
                     ELSE NULLIF(TRIM(rs2.value), '')
                 END) AS distinct_scores,
           COUNT(DISTINCT CASE WHEN TRIM(COALESCE(rs2.value, '')) = '' THEN ep2.id END) AS scoreless_count
    FROM event_participants ep2
    JOIN event e2 ON e2.id = ep2.eventFK AND e2.del = 'no'
    JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
    JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
    JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
    JOIN result r2 ON r2.event_participantsFK = ep2.id
         AND r2.result_typeFK = {{RESULT_RANK_TYPE_ID}}
         AND r2.del = 'no'
         AND r2.value REGEXP '^[1-9][0-9]*$'
    LEFT JOIN result rs2 ON rs2.event_participantsFK = ep2.id
         AND rs2.result_typeFK = {{RESULT_SCORE_TYPE_ID}}
         AND rs2.del = 'no'
    WHERE ep2.del = 'no'
      AND tt2.sportFK = {{SPORT_ID}}
      AND e2.status_type = 'finished'
      AND t2.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      -- AND t2.tournament_templateFK = <tournament_template_id>
      -- AND e2.startdate >= '<from_datetime>'
      -- AND e2.startdate <  '<to_datetime>'
      AND NOT EXISTS (
          SELECT 1
          FROM result rc2
          WHERE rc2.event_participantsFK = ep2.id
            AND rc2.result_typeFK = {{RESULT_COMMENT_TYPE_ID}}
            AND rc2.del = 'no'
            AND TRIM(COALESCE(rc2.value, '')) <> ''
      )
    GROUP BY ep2.eventFK, CAST(r2.value AS UNSIGNED)
    HAVING COUNT(DISTINCT ep2.id) > 1
) g ON g.event_id = e.id AND g.rank_value = CAST(r.value AS UNSIGNED)
WHERE ep.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND e.status_type = 'finished'
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND g.scoreless_count = 0
  AND g.distinct_scores > 1
  AND NOT EXISTS (
      SELECT 1
      FROM result rc
      WHERE rc.event_participantsFK = ep.id
        AND rc.result_typeFK = {{RESULT_COMMENT_TYPE_ID}}
        AND rc.del = 'no'
        AND TRIM(COALESCE(rc.value, '')) <> ''
  )

UNION ALL

SELECT
    'RANK_TIE_SCORE_MISSING' AS check_type,
    ep.id AS event_participants_id,
    e.id AS event_id,
    e.name AS event_name,
    tt.name AS template_name,
    p.name AS participant_name,
    CAST(r.value AS UNSIGNED) AS rank_value,
    NULLIF(TRIM(COALESCE(rs.value, '')), '') AS score_value,
    g.distinct_scores AS distinct_scores_at_rank,
    NULL AS eligible_count,
    0 AS sort_order
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
LEFT JOIN result rs ON rs.event_participantsFK = ep.id
     AND rs.result_typeFK = {{RESULT_SCORE_TYPE_ID}}
     AND rs.del = 'no'
JOIN (
    SELECT ep2.eventFK AS event_id,
           CAST(r2.value AS UNSIGNED) AS rank_value,
           COUNT(DISTINCT ep2.id) AS tied_count,
           -- Compared as a quantity where the value is one, so 13.800 and 13.8 are one score
           -- rather than two. A value that is not a plain number stays text and keeps its own
           -- identity, which a sport storing a status word in its score field depends on.
           COUNT(DISTINCT CASE
                     WHEN TRIM(rs2.value) REGEXP '^-?[0-9]+([.][0-9]+)?$'
                          THEN CAST(CAST(TRIM(rs2.value) AS DECIMAL(20,6)) AS CHAR)
                     ELSE NULLIF(TRIM(rs2.value), '')
                 END) AS distinct_scores,
           COUNT(DISTINCT CASE WHEN TRIM(COALESCE(rs2.value, '')) = '' THEN ep2.id END) AS scoreless_count
    FROM event_participants ep2
    JOIN event e2 ON e2.id = ep2.eventFK AND e2.del = 'no'
    JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
    JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
    JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
    JOIN result r2 ON r2.event_participantsFK = ep2.id
         AND r2.result_typeFK = {{RESULT_RANK_TYPE_ID}}
         AND r2.del = 'no'
         AND r2.value REGEXP '^[1-9][0-9]*$'
    LEFT JOIN result rs2 ON rs2.event_participantsFK = ep2.id
         AND rs2.result_typeFK = {{RESULT_SCORE_TYPE_ID}}
         AND rs2.del = 'no'
    WHERE ep2.del = 'no'
      AND tt2.sportFK = {{SPORT_ID}}
      AND e2.status_type = 'finished'
      AND t2.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      -- AND t2.tournament_templateFK = <tournament_template_id>
      -- AND e2.startdate >= '<from_datetime>'
      -- AND e2.startdate <  '<to_datetime>'
      AND NOT EXISTS (
          SELECT 1
          FROM result rc2
          WHERE rc2.event_participantsFK = ep2.id
            AND rc2.result_typeFK = {{RESULT_COMMENT_TYPE_ID}}
            AND rc2.del = 'no'
            AND TRIM(COALESCE(rc2.value, '')) <> ''
      )
    GROUP BY ep2.eventFK, CAST(r2.value AS UNSIGNED)
    HAVING COUNT(DISTINCT ep2.id) > 1
) g ON g.event_id = e.id AND g.rank_value = CAST(r.value AS UNSIGNED)
WHERE ep.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND e.status_type = 'finished'
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND g.scoreless_count > 0
  AND NOT EXISTS (
      SELECT 1
      FROM result rc
      WHERE rc.event_participantsFK = ep.id
        AND rc.result_typeFK = {{RESULT_COMMENT_TYPE_ID}}
        AND rc.del = 'no'
        AND TRIM(COALESCE(rc.value, '')) <> ''
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ep.id) AS eligible_count,
    1 AS sort_order
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_id;

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-117
    -- Name - EVENT_RESULTS_COMMENT_INVALID_OR_CONTRADICTED_BY_SCORE
    -- What it does: Finds Comment values outside the sport's status codes, or marking a participant as unclassified while a Rank, a Medal or a score is stored for that same participant.
    CASE
        WHEN LOWER(TRIM(x.comment_value)) IN ({{RESULT_COMMENT_NO_RESULT_LIST}}) AND x.medal_value IS NOT NULL THEN 'COMMENT_NO_RESULT_WITH_MEDAL'
        WHEN LOWER(TRIM(x.comment_value)) IN ({{RESULT_COMMENT_NO_RESULT_LIST}}) AND x.rank_value IS NOT NULL THEN 'COMMENT_NO_RESULT_WITH_RANK'
        WHEN LOWER(TRIM(x.comment_value)) IN ({{RESULT_COMMENT_NO_RESULT_LIST}}) AND x.score_value IS NOT NULL THEN 'COMMENT_NO_RESULT_WITH_SCORE'
        ELSE 'COMMENT_INVALID_VALUE'
    END AS check_type,
    x.event_participants_id,
    x.event_id,
    x.event_name,
    x.participant_name,
    x.comment_value,
    x.rank_value,
    x.score_value,
    x.medal_value,
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
        rc.value AS comment_value,
        (SELECT NULLIF(TRIM(r2.value), '') FROM result r2
          WHERE r2.event_participantsFK = ep.id AND r2.result_typeFK = {{RESULT_RANK_TYPE_ID}}
            AND r2.del = 'no' AND r2.value IS NOT NULL LIMIT 1) AS rank_value,
        (SELECT NULLIF(TRIM(r3.value), '') FROM result r3
          WHERE r3.event_participantsFK = ep.id AND r3.result_typeFK = {{RESULT_SCORE_TYPE_ID}}
            AND r3.del = 'no' AND r3.value IS NOT NULL LIMIT 1) AS score_value,
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
) x
WHERE LOWER(TRIM(x.comment_value)) NOT IN ({{RESULT_COMMENT_VALUE_LIST}})
   OR (
        LOWER(TRIM(x.comment_value)) IN ({{RESULT_COMMENT_NO_RESULT_LIST}})
        AND (x.rank_value IS NOT NULL OR x.score_value IS NOT NULL
             OR x.medal_value IS NOT NULL)
      )

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
JOIN result rc ON rc.event_participantsFK = ep.id AND rc.result_typeFK = {{RESULT_COMMENT_TYPE_ID}} AND rc.del = 'no'
WHERE ep.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND rc.value IS NOT NULL
  AND TRIM(rc.value) <> ''
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_id;

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-119
    -- Name - EVENT_RESULTS_RANK_SEQUENCE_BROKEN
    -- What it does: Finds events whose Rank sequence is not a standard competition ranking - a place nobody holds, a tie that does not consume the places it stands for, or a sequence that does not start at one - naming each break where the sequence actually breaks rather than every place it shifts afterwards, together with a coverage count of all eligible events holding at least one usable Rank.
    CASE
        WHEN x.start_breaks > 0 THEN 'RANK_SEQUENCE_DOES_NOT_START_AT_ONE'
        WHEN x.gaps > 0 THEN 'RANK_SEQUENCE_GAP'
        ELSE 'RANK_SEQUENCE_TIE_DOES_NOT_SKIP'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.tournament_stage_name,
    x.startdate,
    x.breaks,
    x.break_detail,
    NULL AS eligible_count,
    0 AS sort_order
-- The assertion is the sequence as a whole, which is what separates this from the two
-- Rank statements that already exist: GLOBAL-DQ-020 reads a single place against the field
-- size and therefore cannot see a missing place in the middle of a full field, and
-- GLOBAL-DQ-021 asks whether a tie is explained rather than what follows it.
-- A break is reported where the sequence breaks, not at every place it displaces. The two
-- are easy to confuse and produce wildly different output: asking instead whether each place
-- equals one plus the number of competitors below it restates a single missing place once
-- for every place after it, and one measured Artistic Gymnastics event turned five breaks
-- into 212 rows. The event set is identical either way - verified row for row - so the
-- cheaper and more legible form is the one kept, and it also runs in seconds rather than a
-- minute because the sequence is walked once instead of counted per place.
-- The start-at-one branch is not redundant with the step branch: a sequence running 2, 3, 4
-- has correct steps throughout and is invisible without it. No sport currently holds one,
-- which is a data state rather than a structural absence, so the branch stays.
FROM (
    SELECT
        b.event_id,
        e.name AS event_name,
        ts.name AS tournament_stage_name,
        e.startdate,
        COUNT(*) AS breaks,
        SUM(CASE WHEN b.break_kind = 'START' THEN 1 ELSE 0 END) AS start_breaks,
        SUM(CASE WHEN b.break_kind = 'GAP' THEN 1 ELSE 0 END) AS gaps,
        GROUP_CONCAT(b.break_text ORDER BY b.at_place SEPARATOR ' | ') AS break_detail
    FROM (
        SELECT
            s.event_id,
            s.rank_value AS at_place,
            CASE
                WHEN s.prev_rank IS NULL AND s.rank_value <> 1 THEN 'START'
                WHEN s.next_rank > s.rank_value + s.places_taken THEN 'GAP'
                ELSE 'TIE'
            END AS break_kind,
            CASE
                WHEN s.prev_rank IS NULL AND s.rank_value <> 1
                    THEN CONCAT('sequence starts at ', s.rank_value, ', expected 1')
                ELSE CONCAT('place ', s.rank_value,
                            CASE WHEN s.places_taken > 1
                                 THEN CONCAT(' shared by ', s.places_taken) ELSE '' END,
                            ' is followed by ', s.next_rank,
                            ', expected ', s.rank_value + s.places_taken)
            END AS break_text
        FROM (
            SELECT
                ranked.event_id,
                ranked.rank_value,
                ranked.places_taken,
                LAG(ranked.rank_value)  OVER (PARTITION BY ranked.event_id ORDER BY ranked.rank_value) AS prev_rank,
                LEAD(ranked.rank_value) OVER (PARTITION BY ranked.event_id ORDER BY ranked.rank_value) AS next_rank
            FROM (
                SELECT
                    e2.id AS event_id,
                    CAST(r.value AS UNSIGNED) AS rank_value,
                    COUNT(DISTINCT ep.id) AS places_taken
                FROM event_participants ep
                JOIN event e2 ON e2.id = ep.eventFK AND e2.del = 'no'
                JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
                JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
                JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
                     AND tt2.sportFK = {{SPORT_ID}}
                JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
                     AND r.result_typeFK = {{RESULT_RANK_TYPE_ID}}
                     AND r.value REGEXP '^[1-9][0-9]*$'
                WHERE ep.del = 'no'
                  AND t2.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
                  -- AND t2.tournament_templateFK = <tournament_template_id>
                  -- AND e2.startdate >= '<from_datetime>'
                  -- AND e2.startdate <  '<to_datetime>'
                GROUP BY e2.id, CAST(r.value AS UNSIGNED)
            ) ranked
        ) s
        WHERE (s.prev_rank IS NULL AND s.rank_value <> 1)
           OR (s.next_rank IS NOT NULL AND s.next_rank <> s.rank_value + s.places_taken)
    ) b
    JOIN event e ON e.id = b.event_id AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    GROUP BY b.event_id, e.name, ts.name, e.startdate
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = {{SPORT_ID}}
WHERE e.del = 'no'
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND EXISTS (
      SELECT 1
      FROM event_participants ep3
      JOIN result r3 ON r3.event_participantsFK = ep3.id AND r3.del = 'no'
           AND r3.result_typeFK = {{RESULT_RANK_TYPE_ID}}
           AND r3.value REGEXP '^[1-9][0-9]*$'
      WHERE ep3.eventFK = e.id AND ep3.del = 'no'
  )

ORDER BY sort_order, event_id;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-120
    -- Name - EVENT_RESULTS_NUMERIC_PRECISION_INCONSISTENT
    -- What it does: Finds events whose participants' values in one numeric result field are not all written to the same number of decimal places, separating a value stored with no decimal point at all from a fraction shorter than its neighbours.
    CASE
        -- A value with no point at all is a different repair from a short fraction: the
        -- separator has to be added as well as the digits, and it is the shape a feed
        -- produces when it drops a trailing zero group rather than one digit.
        WHEN y.types_with_integer > 0 THEN 'PRECISION_MIXED_WITH_INTEGER'
        ELSE 'PRECISION_MIXED_DECIMAL_PLACES'
    END AS check_type,
    y.event_id,
    y.event_name,
    y.template_name,
    y.tournament_name,
    y.affected_result_types,
    y.decimal_places_seen,
    y.worst_shape_count,
    NULL AS eligible_count
FROM (
    SELECT
        x.event_id,
        x.event_name,
        x.template_name,
        x.tournament_name,
        GROUP_CONCAT(DISTINCT x.result_typeFK) AS affected_result_types,
        GROUP_CONCAT(DISTINCT x.places_seen SEPARATOR ' | ') AS decimal_places_seen,
        MAX(x.shape_count) AS worst_shape_count,
        SUM(CASE WHEN x.has_integer = 1 THEN 1 ELSE 0 END) AS types_with_integer
    FROM (
        SELECT
            e.id AS event_id,
            e.name AS event_name,
            tt.name AS template_name,
            t.name AS tournament_name,
            r.result_typeFK,
            -- The written form, not the value. A number carries its precision in how it was
            -- typed, and 13.6 beside 13.733 is one score written to a different scale rather
            -- than a different score - the two are equal to a reader and unequal to anything
            -- that compares the strings. A value with no point counts as zero places.
            COUNT(DISTINCT CASE WHEN r.value LIKE '%.%'
                    THEN LENGTH(SUBSTRING_INDEX(r.value, '.', -1)) ELSE 0 END) AS shape_count,
            MAX(CASE WHEN r.value LIKE '%.%' THEN 0 ELSE 1 END) AS has_integer,
            GROUP_CONCAT(DISTINCT CASE WHEN r.value LIKE '%.%'
                    THEN LENGTH(SUBSTRING_INDEX(r.value, '.', -1)) ELSE 0 END) AS places_seen
        FROM event e
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
        JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
        JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
         AND r.result_typeFK IN ({{PRECISION_RESULT_TYPE_LIST}})
         -- Plain decimals and clock notation alike, because a duration written 1:20.616 and
         -- one written 26.567 are both three places and neither is this check's business.
         -- Whether two notations may stand side by side is a separate question about
         -- magnitudes, and anything that is not a number at all belongs to GLOBAL-DQ-076.
         AND r.value REGEXP '^[0-9]+(:[0-9]{1,2})*([.][0-9]+)?$'
        WHERE e.del = 'no'
          AND tt.sportFK = {{SPORT_ID}}
          AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
          -- AND t.tournament_templateFK = <tournament_template_id>
          -- AND e.startdate >= '<from_datetime>'
          -- AND e.startdate <  '<to_datetime>'
        GROUP BY e.id, e.name, tt.name, t.name, r.result_typeFK
        HAVING shape_count > 1
    ) x
    GROUP BY x.event_id, x.event_name, x.template_name, x.tournament_name
) y

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
 AND r.result_typeFK IN ({{PRECISION_RESULT_TYPE_LIST}})
 AND r.value REGEXP '^[0-9]+(:[0-9]{1,2})*([.][0-9]+)?$'
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-122
    -- Name - EVENT_RESULTS_RANK_WITHOUT_DECIDING_VALUE
    -- What it does: Finds finished events whose ranked participants hold no value in any result field their placing is read from, separating an event holding none at all from one holding them for part of the field, and excusing a participant whose Comment records that they did not finish.
    CASE
        -- An event holding none at all and an event holding some are two different repairs.
        -- The first lost a whole result set and its ranking rests on nothing stored; the
        -- second has the set and is short of rows in it, which is what a feed produces when
        -- a late entrant or a corrected place is appended without its value.
        WHEN x.with_value = 0 THEN 'DECIDING_VALUE_ABSENT_FROM_EVENT'
        ELSE 'DECIDING_VALUE_MISSING_FOR_PART_OF_FIELD'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.template_name,
    x.tournament_name,
    x.stage_name,
    x.event_startdate,
    x.ranked_participants,
    x.with_value,
    x.excused_participants,
    (x.ranked_participants - x.with_value - x.excused_participants) AS missing_unexcused,
    NULL AS eligible_count,
    0 AS sort_order
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        ts.name AS stage_name,
        e.startdate AS event_startdate,
        COUNT(DISTINCT ep.id) AS ranked_participants,
        COUNT(DISTINCT CASE WHEN rv.id IS NOT NULL THEN ep.id END) AS with_value,
        -- Excused only where the value is absent. A participant who did not finish and still
        -- holds a value is neither a finding nor an excuse, and counting them here would let
        -- one missing row hide behind another participant's Comment.
        COUNT(DISTINCT CASE WHEN rv.id IS NULL AND rc.id IS NOT NULL THEN ep.id END)
            AS excused_participants
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    -- The Rank is what makes a participant auditable here. A field entry carrying no place
    -- was never classified, which is GLOBAL-DQ-036's question rather than this one's.
    JOIN result rr ON rr.event_participantsFK = ep.id AND rr.del = 'no'
     AND rr.result_typeFK = {{RESULT_RANK_TYPE_ID}}
     AND rr.value IS NOT NULL
     AND TRIM(rr.value) <> ''
    -- Any one of the sport's deciding fields accounts for the place, which is the same
    -- reading GLOBAL-DQ-116 gave the list: a timed sport storing both a duration and a full
    -- time is not short of a result because it kept only one of them for a participant.
    LEFT JOIN result rv ON rv.event_participantsFK = ep.id AND rv.del = 'no'
     AND rv.result_typeFK IN ({{RESULT_TIE_VALUE_TYPE_LIST}})
     AND rv.value IS NOT NULL
     AND TRIM(rv.value) <> ''
    LEFT JOIN result rc ON rc.event_participantsFK = ep.id AND rc.del = 'no'
     AND LOWER(TRIM(rc.value)) IN ({{RESULT_COMMENT_NO_RESULT_LIST}})
     AND rc.result_typeFK = {{RESULT_COMMENT_TYPE_ID}}
    WHERE e.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      AND e.status_type = 'finished'
      AND e.status_descFK = 6
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY e.id, e.name, tt.name, t.name, ts.name, e.startdate
) x
WHERE x.with_value + x.excused_participants < x.ranked_participants

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
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
JOIN result rr ON rr.event_participantsFK = ep.id AND rr.del = 'no'
 AND rr.result_typeFK = {{RESULT_RANK_TYPE_ID}}
 AND rr.value IS NOT NULL
 AND TRIM(rr.value) <> ''
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND e.status_type = 'finished'
  AND e.status_descFK = 6
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, missing_unexcused DESC, event_startdate DESC;

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-124
    -- Name - EVENT_RESULTS_INTEGER_FIELD_FRACTIONAL
    -- What it does: Finds events whose whole-number result fields hold a value carrying a fractional part, separating a decimal point from a decimal comma, and naming how many values are affected and what they hold.
    x.check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.template_name,
    x.tournament_name,
    x.result_type_names,
    x.affected_count,
    x.affected_participant_count,
    x.distinct_values,
    -- A convenience for the reader, not the finding: GROUP_CONCAT truncates at the server's
    -- group_concat_max_len without saying so, and affected_count is counted separately and is
    -- what the row asserts.
    x.affected_participants,
    NULL AS eligible_count,
    0 AS sort_order
FROM (
    SELECT
        y.check_type,
        y.event_id,
        y.event_name,
        y.event_startdate,
        y.template_name,
        y.tournament_name,
        GROUP_CONCAT(DISTINCT y.result_type_name ORDER BY y.result_type_name SEPARATOR ', ')
            AS result_type_names,
        COUNT(*) AS affected_count,
        COUNT(DISTINCT y.event_participants_id) AS affected_participant_count,
        GROUP_CONCAT(DISTINCT y.stored_value ORDER BY y.stored_value SEPARATOR ', ')
            AS distinct_values,
        GROUP_CONCAT(DISTINCT y.participant_name ORDER BY y.participant_name SEPARATOR ', ')
            AS affected_participants
    FROM (
        -- One row per fractional value, grouped to the event below, on the same grain as
        -- GLOBAL-DQ-076 and for the same reason: a field written the wrong way is one storage
        -- habit and not one defect per competitor.
        --
        -- The two separators are separate check_types because they are repaired differently.
        -- A decimal point is a value that should never have carried a fraction. A comma is
        -- ambiguous by itself - it reads as a decimal comma in one locale and a thousands
        -- separator in another - so a reader has to see which it is before deciding, and
        -- 4,07 in a field counting strokes is a different mistake from 4,070.
        SELECT
            CASE
                WHEN TRIM(r.value) REGEXP '^[-+]?[0-9]+[.][0-9]+$' THEN 'DECIMAL_POINT_IN_INTEGER_FIELD'
                ELSE 'DECIMAL_COMMA_IN_INTEGER_FIELD'
            END AS check_type,
            e.id AS event_id,
            e.name AS event_name,
            e.startdate AS event_startdate,
            tt.name AS template_name,
            t.name AS tournament_name,
            rt.name AS result_type_name,
            ep.id AS event_participants_id,
            p.name AS participant_name,
            r.value AS stored_value
        FROM event_participants ep
        JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
        JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
        JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
         AND r.result_typeFK IN ({{INTEGER_RESULT_TYPE_LIST}})
        LEFT JOIN result_type rt ON rt.id = r.result_typeFK
        WHERE ep.del = 'no'
          AND tt.sportFK = {{SPORT_ID}}
          AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
          -- AND t.tournament_templateFK = <tournament_template_id>
          -- AND e.startdate >= '<from_datetime>'
          -- AND e.startdate <  '<to_datetime>'
          AND r.value IS NOT NULL
          AND TRIM(r.value) <> ''
          -- Disjoint from GLOBAL-DQ-076 by construction. That check reports a value that is
          -- not a number at all; this one reports a value that is a number the field cannot
          -- hold, so a value reported here is never reported there and the two never restate
          -- each other. An empty field is not a finding either - a round that was not played
          -- stores nothing, and whether it should is GLOBAL-DQ-069.
          AND TRIM(r.value) REGEXP '^[-+]?[0-9]+[.,][0-9]+$'
    ) y
    GROUP BY
        y.check_type,
        y.event_id,
        y.event_name,
        y.event_startdate,
        y.template_name,
        y.tournament_name
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event_participants ep
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
 AND r.result_typeFK IN ({{INTEGER_RESULT_TYPE_LIST}})
WHERE ep.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND r.value IS NOT NULL
  AND TRIM(r.value) <> ''

ORDER BY sort_order, affected_count DESC, event_id;
