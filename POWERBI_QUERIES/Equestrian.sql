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

-- ================================================================================

SELECT
    -- CheckID - Equestrian-DQ-061
    -- Name - COMP.RANK_PARTICIPANT_NOT_IN_TOURNAMENT_BY_OWN_PATH
    -- What it does: Flags Comp.Rank records ranking a rider or a horse the tournament never fielded.
    'Comp_Rank_Participant_Not_In_Tournament' AS check_type,
    x.statistic_id,
    x.statistic_name,
    x.template_name,
    x.tournament_name,
    x.stray_athlete_count,
    x.stray_horse_count,
    x.sample_participant_name,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds a Comp.Rank holding a participant that no event of the
-- same tournament fielded, asking each participant type by the path that actually reaches it.
-- This is GLOBAL-DQ-030's question, which cannot be instantiated here. That template looks for
-- every Comp.Rank participant in event_participants, and in this sport the horse is never an
-- event participant: the participation names it through a ref:participant property called
-- horseFK. So the template reports every horse in the sport - 376 of 420 statistics measured
-- 2026-08-18 - and says nothing about whether the ride happened.
-- Here the rider is looked for in event_participants and the horse in the horseFK values those
-- same participations carry, so each is asked on its own terms. Measured the same day that is
-- 88 riders across 17 statistics and 184 horses across 38.
FROM (
    SELECT
        s.id AS statistic_id,
        s.name AS statistic_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        SUM(CASE WHEN g.participant_type = 'athlete' THEN 1 ELSE 0 END) AS stray_athlete_count,
        SUM(CASE WHEN g.participant_type = 'horse' THEN 1 ELSE 0 END) AS stray_horse_count,
        MIN(g.participant_name) AS sample_participant_name
    FROM (
        SELECT
            s2.id AS statistic_id,
            p.type AS participant_type,
            p.name AS participant_name
        FROM statistic s2
        JOIN tournament t2
          ON t2.id = s2.objectFK
         AND t2.del = 'no'
        JOIN tournament_template tt2
          ON tt2.id = t2.tournament_templateFK
         AND tt2.del = 'no'
         AND tt2.sportFK = 37
        JOIN statistic_participants11 sp
          ON sp.statisticFK = s2.id
         AND sp.del = 'no'
        JOIN participant p
          ON p.id = sp.participantFK
         AND p.del = 'no'
         AND p.type IN ('athlete', 'horse')
        LEFT JOIN (
            SELECT DISTINCT
                ts4.tournamentFK AS tournament_id,
                ep4.participantFK AS participant_id
            FROM event_participants ep4
            JOIN event e4 ON e4.id = ep4.eventFK AND e4.del = 'no'
            JOIN tournament_stage ts4 ON ts4.id = e4.tournament_stageFK AND ts4.del = 'no'
            JOIN tournament t4 ON t4.id = ts4.tournamentFK AND t4.del = 'no'
            JOIN tournament_template tt4 ON tt4.id = t4.tournament_templateFK
                 AND tt4.del = 'no' AND tt4.sportFK = 37
            WHERE ep4.del = 'no'
        ) rider
          ON rider.tournament_id = t2.id
         AND rider.participant_id = sp.participantFK
        LEFT JOIN (
            SELECT DISTINCT
                ts5.tournamentFK AS tournament_id,
                CAST(pr5.value AS UNSIGNED) AS participant_id
            FROM property pr5
            JOIN event_participants ep5 ON ep5.id = pr5.objectFK AND ep5.del = 'no'
            JOIN event e5 ON e5.id = ep5.eventFK AND e5.del = 'no'
            JOIN tournament_stage ts5 ON ts5.id = e5.tournament_stageFK AND ts5.del = 'no'
            JOIN tournament t5 ON t5.id = ts5.tournamentFK AND t5.del = 'no'
            JOIN tournament_template tt5 ON tt5.id = t5.tournament_templateFK
                 AND tt5.del = 'no' AND tt5.sportFK = 37
            WHERE pr5.object = 'event_participants'
              AND pr5.name = 'horseFK'
              AND pr5.del = 'no'
              AND pr5.value <> ''
              AND pr5.value <> '0'
        ) mount
          ON mount.tournament_id = t2.id
         AND mount.participant_id = sp.participantFK
        WHERE s2.del = 'no'
          AND s2.statistic_typeFK = 11
          AND s2.object_typeFK = 3
          AND (tt2.name IS NULL OR tt2.name NOT LIKE '%(IOC)%')
          AND t2.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
          -- AND t2.tournament_templateFK = <tournament_template_id>
          AND ((p.type = 'athlete' AND rider.participant_id IS NULL)
            OR (p.type = 'horse'   AND mount.participant_id IS NULL))
        GROUP BY
            s2.id,
            p.type,
            p.name,
            sp.participantFK
    ) g
    JOIN statistic s
      ON s.id = g.statistic_id
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

-- ================================================================================

SELECT
    -- CheckID - Equestrian-DQ-062
    -- Name - COMP.RANK_PLACE_SHARED_BY_TWO_RIDES_WITHOUT_COMMENT
    -- What it does: Flags Comp.Rank records where a minority of the field shares a place with no comment explaining it.
    'Comp_Rank_Place_Shared_Without_Comment' AS check_type,
    x.statistic_id,
    s.name AS statistic_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    x.shared_places,
    x.shared_pairs,
    f.total_pairs,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds a Comp.Rank holding a place occupied by two or more
-- distinct Pair values where no participant on that place carries a Comment, and where the
-- rides sitting on such places are under half the field.
-- This is GLOBAL-DQ-095's question and neither half of it survives instantiation here. The
-- template counts participant rows, so the rider and the horse of one ride read as two holders
-- of one place and every ranking in the sport is reported - 341 of 420 measured 2026-08-18. It
-- is therefore counted by Pair, which is what identifies a ride.
-- The field share is the second half and it was measured rather than assumed. Uncommented
-- shared places reach 90 to 100 per cent of the field in 40 rankings and under 20 per cent in
-- 25, with 10 between; the naming does not separate the two, since 22 of the 40 do not call
-- themselves team rankings. A shape reaching a whole field is a format by the discriminator
-- POWERBI.md records for Golf-DQ-101, so the threshold agreed on 2026-08-18 is half the field:
-- above it the ranking shares places by construction, below it the sharing is exceptional and
-- is what this reports.
FROM (
    SELECT
        g.statistic_id,
        COUNT(*) AS shared_places,
        SUM(g.pairs_on_place) AS shared_pairs
    FROM (
        SELECT
            s2.id AS statistic_id,
            rk.value AS rank_value,
            COUNT(DISTINCT pr.value) AS pairs_on_place
        FROM statistic s2
        JOIN tournament t2
          ON t2.id = s2.objectFK
         AND t2.del = 'no'
        JOIN tournament_template tt2
          ON tt2.id = t2.tournament_templateFK
         AND tt2.del = 'no'
         AND tt2.sportFK = 37
        JOIN statistic_participants11 sp
          ON sp.statisticFK = s2.id
         AND sp.del = 'no'
        JOIN statistic_data11 rk
          ON rk.statistic_participants11FK = sp.id
         AND rk.statistic_data_typeFK = 1270
         AND rk.del = 'no'
        JOIN statistic_data11 pr
          ON pr.statistic_participants11FK = sp.id
         AND pr.statistic_data_typeFK = 1276
         AND pr.del = 'no'
        LEFT JOIN statistic_data11 cm
          ON cm.statistic_participants11FK = sp.id
         AND cm.statistic_data_typeFK = 1273
         AND cm.del = 'no'
         AND cm.value IS NOT NULL
         AND cm.value <> ''
        WHERE s2.del = 'no'
          AND s2.statistic_typeFK = 11
          AND s2.object_typeFK = 3
          AND (tt2.name IS NULL OR tt2.name NOT LIKE '%(IOC)%')
          AND t2.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
          -- AND t2.tournament_templateFK = <tournament_template_id>
        GROUP BY
            s2.id,
            rk.value
        HAVING
            COUNT(DISTINCT pr.value) > 1
        AND COUNT(DISTINCT cm.id) = 0
    ) g
    GROUP BY
        g.statistic_id
) x
JOIN (
    SELECT
        sp8.statisticFK AS statistic_id,
        COUNT(DISTINCT pr8.value) AS total_pairs
    FROM statistic_participants11 sp8
    JOIN statistic s8
      ON s8.id = sp8.statisticFK
     AND s8.del = 'no'
     AND s8.statistic_typeFK = 11
     AND s8.object_typeFK = 3
    JOIN tournament t8
      ON t8.id = s8.objectFK
     AND t8.del = 'no'
    JOIN tournament_template tt8
      ON tt8.id = t8.tournament_templateFK
     AND tt8.del = 'no'
     AND tt8.sportFK = 37
    JOIN statistic_data11 pr8
      ON pr8.statistic_participants11FK = sp8.id
     AND pr8.statistic_data_typeFK = 1276
     AND pr8.del = 'no'
    WHERE sp8.del = 'no'
    GROUP BY
        sp8.statisticFK
) f
  ON f.statistic_id = x.statistic_id
 AND f.total_pairs > 0
 AND x.shared_pairs * 100 / f.total_pairs < 50
JOIN statistic s
  ON s.id = x.statistic_id
 AND s.del = 'no'
JOIN tournament t
  ON t.id = s.objectFK
 AND t.del = 'no'
JOIN tournament_template tt
  ON tt.id = t.tournament_templateFK
 AND tt.del = 'no'

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
      FROM statistic_participants11 sp9
      JOIN statistic_data11 pr9
        ON pr9.statistic_participants11FK = sp9.id
       AND pr9.statistic_data_typeFK = 1276
       AND pr9.del = 'no'
      WHERE sp9.statisticFK = s.id
        AND sp9.del = 'no'
  )

ORDER BY sort_order, statistic_id;
