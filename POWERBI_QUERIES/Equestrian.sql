SELECT
    -- CheckID - Equestrian-DQ-060
    -- Name - COMP.RANK_PARTICIPANT_DUPLICATE_ON_ONE_PAIR
    -- What it does: Flags Comp.Rank records holding the same participant twice on one Pair.
    'Comp_Rank_Participant_Duplicate_On_One_Pair' AS check_type,
    x.statistic_id,
    x.statistic_name,
    x.template_name,
    x.tournament_name,
    x.affected_participant_count,
    x.duplicated_row_count,
    x.sample_group,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds a Comp.Rank in which one participant holds more
-- participant rows than it holds distinct Pair values, so at least two of its rows describe
-- the same ride.
-- This is GLOBAL-DQ-103's question asked in the only form that means anything here. That
-- template counts a participant's rows and reports every count above one, which in this sport
-- reports the sport: a rider entered on two horses legitimately holds two rows, and measured
-- 2026-08-18 that is 151 of the 161 cases it returns. What separates a duplicate from a second
-- ride is field 1276 Pair, which binds a rider to the horse it rode, so the rule asserted here
-- is that a participant's rows and its distinct Pair values must be equal in number. A rider on
-- two horses has two rows and two Pairs and is not reported; a rider written twice against one
-- Pair has two rows and one Pair and is.
-- Rows carrying no Pair at all count as one shared absence rather than as separate rides, which
-- is deliberate: a duplicate that lost its Pair is still a duplicate.
FROM (
    SELECT
        s.id AS statistic_id,
        s.name AS statistic_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        COUNT(*) AS affected_participant_count,
        SUM(g.row_count) AS duplicated_row_count,
        MIN(CONCAT('participant=', g.participantFK,
                   ' rows=', g.row_count,
                   ' pairs=', g.distinct_pairs)) AS sample_group
    FROM (
        SELECT
            sp.statisticFK,
            sp.participantFK,
            COUNT(DISTINCT sp.id) AS row_count,
            COUNT(DISTINCT sd.value) AS distinct_pairs
        FROM statistic_participants11 sp
        JOIN statistic s2
          ON s2.id = sp.statisticFK
         AND s2.del = 'no'
         AND s2.statistic_typeFK = 11
         AND s2.object_typeFK = 3
        JOIN tournament t2
          ON t2.id = s2.objectFK
         AND t2.del = 'no'
        JOIN tournament_template tt2
          ON tt2.id = t2.tournament_templateFK
         AND tt2.del = 'no'
         AND tt2.sportFK = 37
        LEFT JOIN statistic_data11 sd
          ON sd.statistic_participants11FK = sp.id
         AND sd.statistic_data_typeFK = 1276
         AND sd.del = 'no'
        WHERE sp.del = 'no'
          AND (tt2.name IS NULL OR tt2.name NOT LIKE '%(IOC)%')
          AND t2.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
          -- AND t2.tournament_templateFK = <tournament_template_id>
        GROUP BY
            sp.statisticFK,
            sp.participantFK
        HAVING
            COUNT(DISTINCT sp.id) > 1
        AND COUNT(DISTINCT sd.value) < COUNT(DISTINCT sp.id)
    ) g
    JOIN statistic s
      ON s.id = g.statisticFK
     AND s.del = 'no'
    JOIN tournament t
      ON t.id = s.objectFK
     AND t.del = 'no'
    JOIN tournament_template tt
      ON tt.id = t.tournament_templateFK
     AND tt.del = 'no'
    GROUP BY
        s.id,
        s.name,
        tt.name,
        t.name
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count,
    1 AS sort_order
FROM statistic s
JOIN tournament t
  ON t.id = s.objectFK
 AND t.del = 'no'
JOIN tournament_template tt
  ON tt.id = t.tournament_templateFK
 AND tt.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = 11
  AND s.object_typeFK = 3
  AND tt.sportFK = 37
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND t.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND EXISTS (
      SELECT 1
      FROM statistic_participants11 sp2
      WHERE sp2.statisticFK = s.id
        AND sp2.del = 'no'
  )

ORDER BY sort_order, statistic_id;
