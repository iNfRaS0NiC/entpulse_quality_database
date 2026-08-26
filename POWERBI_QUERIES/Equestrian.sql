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
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
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
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
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
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
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
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
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
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
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
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
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

-- ================================================================================

SELECT
    -- CheckID - Equestrian-DQ-067
    -- Name - TOURNAMENT_STAGE_EVENT_OUTSIDE_DATE_RANGE
    -- What it does: Flags tournament stages holding an event that starts outside the stage's own dates.
    'Stage_Event_Outside_Date_Range' AS check_type,
    x.tournament_stage_id,
    x.tournament_stage_name,
    x.template_name,
    x.tournament_name,
    x.stage_startdate,
    x.stage_enddate,
    x.earliest_event_startdate,
    x.latest_event_startdate,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds a stage whose first or last event starts before the stage
-- begins or after it ends, so the stage does not contain the competition it names.
-- This asserts containment on the exact timestamp, where GLOBAL-DQ-004 asserts it on the
-- calendar day, and the statement is kept for that difference. Measured 2026-08-26 the template
-- returns 13 stages and this returns those 13 plus 4 more, where an event falls outside the hours
-- of a stage that was not written as whole days. GLOBAL-DQ-004 is therefore not instantiated on
-- this sport: it would restate a subset of what this already reports.
-- The template asserted equality until 2026-08-26 - the stage dates matching the first and last
-- event exactly - and that is the assertion this statement was written to replace. Equestrian
-- writes a stage as whole days, from 00:00:00 to 23:59:59, so a stage containing every one of its
-- events still differed from their span by the hours at each end: 3303 of the 3338 stages the
-- template reported, measured 2026-08-18, which said only that the sport rounds to the day.
FROM (
    SELECT
        ts.id AS tournament_stage_id,
        ts.name AS tournament_stage_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        ts.startdate AS stage_startdate,
        ts.enddate AS stage_enddate,
        MIN(e.startdate) AS earliest_event_startdate,
        MAX(e.startdate) AS latest_event_startdate
    FROM tournament_stage ts
    JOIN tournament t
      ON t.id = ts.tournamentFK
     AND t.del = 'no'
    JOIN tournament_template tt
      ON tt.id = t.tournament_templateFK
     AND tt.del = 'no'
    JOIN event e
      ON e.tournament_stageFK = ts.id
     AND e.del = 'no'
    WHERE ts.del = 'no'
      AND tt.sportFK = 37
      AND t.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
      AND ts.startdate IS NOT NULL
      AND ts.enddate IS NOT NULL
      AND e.startdate IS NOT NULL
    GROUP BY
        ts.id,
        ts.name,
        tt.name,
        t.name,
        ts.startdate,
        ts.enddate
    HAVING
        MIN(e.startdate) < ts.startdate
     OR MAX(e.startdate) > ts.enddate
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ts.id) AS eligible_count,
    1 AS sort_order
FROM tournament_stage ts
JOIN tournament t
  ON t.id = ts.tournamentFK
 AND t.del = 'no'
JOIN tournament_template tt
  ON tt.id = t.tournament_templateFK
 AND tt.del = 'no'
WHERE ts.del = 'no'
  AND tt.sportFK = 37
  AND t.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND ts.startdate IS NOT NULL
  AND ts.enddate IS NOT NULL
  AND EXISTS (
      SELECT 1
      FROM event e2
      WHERE e2.tournament_stageFK = ts.id
        AND e2.del = 'no'
        AND e2.startdate IS NOT NULL
  )

ORDER BY sort_order, tournament_stage_id;

-- ================================================================================

SELECT
    -- CheckID - Equestrian-DQ-068
    -- Name - PARTICIPANT_NO_PARTICIPATION_BY_OWN_PATH
    -- What it does: Flags registered riders, horses and teams that no path in the sport reaches.
    'No_Participation_By_Own_Path' AS check_type,
    p.id AS participant_id,
    p.name AS participant_name,
    p.type AS participant_type,
    p.gender AS participant_gender,
    op.active AS registry_active_flag,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds a participant the sport registers and never uses, asking
-- each type by the path that can carry it.
-- GLOBAL-DQ-009 asks the same question through event_participants, lineup and the Comp.Rank
-- shard, and a horse enters none of those: a participation names its horse through the horseFK
-- reference property instead. So the template reports 18203 horses, which is most of the
-- register, and measured 2026-08-18 only 967 of them are genuinely unused.
-- Here a rider or a team is looked for in the participation and lineup layers, and a horse in
-- the horseFK values and the Comp.Rank shard. What comes back is 967 horses, 205 riders and 35
-- teams that nothing in the sport reaches.
-- No template filter is marked and none belongs here. The audited object is a registry entry,
-- which has no tournament_template relation to narrow on, exactly as GLOBAL-DQ-009 has none.
FROM object_participants op
JOIN participant p
  ON p.id = op.participantFK
 AND p.del = 'no'
 AND p.type IN ('athlete', 'horse', 'team')
LEFT JOIN (
    SELECT DISTINCT ep.participantFK AS participant_id
    FROM event_participants ep
    JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = 37
    WHERE ep.del = 'no'
) entered
  ON entered.participant_id = p.id
LEFT JOIN (
    SELECT DISTINCT l.participantFK AS participant_id
    FROM lineup l
    JOIN event_participants ep2 ON ep2.id = l.event_participantsFK AND ep2.del = 'no'
    JOIN event e2 ON e2.id = ep2.eventFK AND e2.del = 'no'
    JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
    JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
    JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
         AND tt2.sportFK = 37
    WHERE l.del = 'no'
) listed
  ON listed.participant_id = p.id
LEFT JOIN (
    SELECT DISTINCT sp.participantFK AS participant_id
    FROM statistic_participants11 sp
    JOIN statistic s ON s.id = sp.statisticFK AND s.del = 'no'
         AND s.statistic_typeFK = 11 AND s.object_typeFK = 3
    JOIN tournament t3 ON t3.id = s.objectFK AND t3.del = 'no'
    JOIN tournament_template tt3 ON tt3.id = t3.tournament_templateFK AND tt3.del = 'no'
         AND tt3.sportFK = 37
    WHERE sp.del = 'no'
) ranked
  ON ranked.participant_id = p.id
LEFT JOIN (
    SELECT DISTINCT CAST(pr.value AS UNSIGNED) AS participant_id
    FROM property pr
    JOIN event_participants ep3 ON ep3.id = pr.objectFK AND ep3.del = 'no'
    JOIN event e3 ON e3.id = ep3.eventFK AND e3.del = 'no'
    JOIN tournament_stage ts3 ON ts3.id = e3.tournament_stageFK AND ts3.del = 'no'
    JOIN tournament t4 ON t4.id = ts3.tournamentFK AND t4.del = 'no'
    JOIN tournament_template tt4 ON tt4.id = t4.tournament_templateFK AND tt4.del = 'no'
         AND tt4.sportFK = 37
    WHERE pr.object = 'event_participants'
      AND pr.name = 'horseFK'
      AND pr.del = 'no'
      AND pr.value <> ''
      AND pr.value <> '0'
) mounted
  ON mounted.participant_id = p.id
WHERE op.object = 'sport'
  AND op.objectFK = 37
  AND op.del = 'no'
  -- AND p.id BETWEEN <from_participant_id> AND <to_participant_id>
  AND entered.participant_id IS NULL
  AND listed.participant_id IS NULL
  AND ranked.participant_id IS NULL
  AND mounted.participant_id IS NULL

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT p.id) AS eligible_count,
    1 AS sort_order
FROM object_participants op
JOIN participant p
  ON p.id = op.participantFK
 AND p.del = 'no'
 AND p.type IN ('athlete', 'horse', 'team')
WHERE op.object = 'sport'
  AND op.objectFK = 37
  AND op.del = 'no'
  -- AND p.id BETWEEN <from_participant_id> AND <to_participant_id>

ORDER BY sort_order, participant_id;

-- ================================================================================

SELECT
    -- CheckID - Equestrian-DQ-069
    -- Name - EVENT_PARTICIPANTS_DUPLICATE_ON_ONE_HORSE
    -- What it does: Flags events where a rider is entered more than once without a separate horse for each entry.
    'Participant_Duplicate_Not_Explained_By_Horse' AS check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.template_name,
    x.tournament_name,
    x.offending_rider_count,
    x.offending_entry_count,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds an event in which one rider holds more entries than the
-- distinct horses those entries name, so at least two of the entries describe the same ride or
-- name no horse at all.
-- GLOBAL-DQ-055 reports a rider entered twice however the entries differ, and in this sport a
-- rider commonly rides two horses in one class: measured 2026-08-18 that is 3977 of the 3998
-- rider-and-event pairs it returns, across 1270 of its 1273 events. Entering twice is not the
-- defect here; entering twice on one horse is.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        tt.name AS template_name,
        t.name AS tournament_name,
        COUNT(*) AS offending_rider_count,
        SUM(g.entries) AS offending_entry_count
    FROM (
        SELECT
            ep.eventFK AS event_id,
            ep.participantFK AS participant_id,
            COUNT(DISTINCT ep.id) AS entries,
            COUNT(DISTINCT CASE WHEN pr.value IS NOT NULL AND pr.value <> '' AND pr.value <> '0'
                                THEN pr.value END) AS distinct_horses
        FROM event_participants ep
        JOIN event e2 ON e2.id = ep.eventFK AND e2.del = 'no'
        JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
        JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
        JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
             AND tt2.sportFK = 37
        LEFT JOIN property pr
          ON pr.object = 'event_participants'
         AND pr.objectFK = ep.id
         AND pr.name = 'horseFK'
         AND pr.del = 'no'
        WHERE ep.del = 'no'
          AND t2.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
          -- AND t2.tournament_templateFK = <tournament_template_id>
        GROUP BY
            ep.eventFK,
            ep.participantFK
        HAVING
            COUNT(DISTINCT ep.id) > 1
        AND COUNT(DISTINCT CASE WHEN pr.value IS NOT NULL AND pr.value <> '' AND pr.value <> '0'
                                THEN pr.value END) < COUNT(DISTINCT ep.id)
    ) g
    JOIN event e ON e.id = g.event_id AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    GROUP BY
        e.id,
        e.name,
        e.startdate,
        tt.name,
        t.name
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = 37
  AND t.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND EXISTS (
      SELECT 1 FROM event_participants ep4
      WHERE ep4.eventFK = e.id AND ep4.del = 'no'
  )

ORDER BY sort_order, event_id;

-- ================================================================================

SELECT
    -- CheckID - Equestrian-DQ-070
    -- Name - EVENT_RESULTS_RANK_TIE_CONTRADICTED_BY_SCORE_WHERE_SCORED
    -- What it does: Flags events where competitors share a place while their scores disagree.
    'Rank_Tie_Contradicted_By_Score' AS check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.template_name,
    x.tournament_name,
    x.contradicted_places,
    x.contradicted_competitors,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds an event holding a place shared by competitors whose
-- Score values differ, counted only where every competitor on that place actually carries a
-- Score.
-- GLOBAL-DQ-116 asks the same thing and cannot separate a contradiction from an absence. It
-- reports RANK_TIE_SCORE_MISSING wherever a shared place has no Score to compare, and this
-- sport writes Score on 2125 of its 5511 ranked events, so measured 2026-08-18 that class is
-- 6226 of the 6308 rows it returns and says only that most events are not scored on 644.
-- The 82 rows of the other class are the finding, and this reports the events holding them.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        tt.name AS template_name,
        t.name AS tournament_name,
        COUNT(*) AS contradicted_places,
        SUM(g.holders) AS contradicted_competitors
    FROM (
        SELECT
            ep.eventFK AS event_id,
            rk.value AS rank_value,
            COUNT(DISTINCT ep.id) AS holders,
            COUNT(DISTINCT sc.value) AS distinct_scores
        FROM event_participants ep
        JOIN event e2 ON e2.id = ep.eventFK AND e2.del = 'no'
        JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
        JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
        JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
             AND tt2.sportFK = 37
        JOIN result rk
          ON rk.event_participantsFK = ep.id
         AND rk.result_typeFK = 100
         AND rk.del = 'no'
         AND rk.value IS NOT NULL
         AND rk.value <> ''
        JOIN result sc
          ON sc.event_participantsFK = ep.id
         AND sc.result_typeFK = 644
         AND sc.del = 'no'
         AND sc.value IS NOT NULL
         AND sc.value <> ''
        WHERE ep.del = 'no'
          AND t2.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
          -- AND t2.tournament_templateFK = <tournament_template_id>
        GROUP BY
            ep.eventFK,
            rk.value
        HAVING
            COUNT(DISTINCT ep.id) > 1
        AND COUNT(DISTINCT sc.value) > 1
    ) g
    JOIN event e ON e.id = g.event_id AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    GROUP BY
        e.id,
        e.name,
        e.startdate,
        tt.name,
        t.name
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = 37
  AND t.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND EXISTS (
      SELECT 1
      FROM event_participants ep5
      JOIN result sc5
        ON sc5.event_participantsFK = ep5.id
       AND sc5.result_typeFK = 644
       AND sc5.del = 'no'
      WHERE ep5.eventFK = e.id
        AND ep5.del = 'no'
  )

ORDER BY sort_order, event_id;

-- ================================================================================

SELECT
    -- CheckID - Equestrian-DQ-092
    -- Name - EVENT_RESULTS_RANK_DUPLICATE_WITHOUT_COMMENT_WHERE_SCORED
    -- What it does: Flags scored events sharing a place with nothing on the card to explain it.
    'Rank_Duplicate_Unexplained' AS check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.template_name,
    x.tournament_name,
    x.shared_places,
    x.shared_competitors,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds an event that writes result type 644 Score and still
-- holds a place shared by competitors whose scores disagree or who carry no score at all, with
-- no comment on any of them to account for it.
-- GLOBAL-DQ-021 asks this of every ranked event, and the sport writes Score on 2125 of its 5511
-- ranked events, so 665 of the 704 it returns are the RANK_DUPLICATE_WITHOUT_VALUE class and
-- say only that the event was never scored on that field. Restricting the audit to the events
-- that carry a Score leaves the question it was asking.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        tt.name AS template_name,
        t.name AS tournament_name,
        COUNT(*) AS shared_places,
        SUM(g.holders) AS shared_competitors
    FROM (
        SELECT
            ep.eventFK AS event_id,
            rk.value AS rank_value,
            COUNT(DISTINCT ep.id) AS holders,
            COUNT(DISTINCT sc.value) AS distinct_scores,
            COUNT(DISTINCT sc.id) AS scored_holders,
            COUNT(DISTINCT cm.id) AS comment_rows
        FROM event_participants ep
        JOIN event e2 ON e2.id = ep.eventFK AND e2.del = 'no'
        JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
        JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
        JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
             AND tt2.sportFK = 37
        JOIN (
            SELECT DISTINCT ep8.eventFK AS event_id
            FROM event_participants ep8
            JOIN result sc8
              ON sc8.event_participantsFK = ep8.id
             AND sc8.result_typeFK = 644
             AND sc8.del = 'no'
            WHERE ep8.del = 'no'
        ) scored
          ON scored.event_id = ep.eventFK
        JOIN result rk
          ON rk.event_participantsFK = ep.id
         AND rk.result_typeFK = 100
         AND rk.del = 'no'
         AND rk.value IS NOT NULL
         AND rk.value <> ''
        LEFT JOIN result sc
          ON sc.event_participantsFK = ep.id
         AND sc.result_typeFK = 644
         AND sc.del = 'no'
         AND sc.value IS NOT NULL
         AND sc.value <> ''
        LEFT JOIN result cm
          ON cm.event_participantsFK = ep.id
         AND cm.result_typeFK = 104
         AND cm.del = 'no'
         AND cm.value IS NOT NULL
         AND cm.value <> ''
        WHERE ep.del = 'no'
          AND t2.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
          -- AND t2.tournament_templateFK = <tournament_template_id>
        GROUP BY
            ep.eventFK,
            rk.value
        HAVING
            COUNT(DISTINCT ep.id) > 1
        AND COUNT(DISTINCT cm.id) = 0
        AND (COUNT(DISTINCT sc.value) > 1 OR COUNT(DISTINCT sc.id) < COUNT(DISTINCT ep.id))
    ) g
    JOIN event e ON e.id = g.event_id AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    GROUP BY
        e.id, e.name, e.startdate, tt.name, t.name
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = 37
  AND t.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND EXISTS (
      SELECT 1
      FROM event_participants ep5
      JOIN result sc5 ON sc5.event_participantsFK = ep5.id
           AND sc5.result_typeFK = 644 AND sc5.del = 'no'
      WHERE ep5.eventFK = e.id AND ep5.del = 'no'
  )

ORDER BY sort_order, event_id;

-- ================================================================================

SELECT
    -- CheckID - Equestrian-DQ-093
    -- Name - EVENT_RESULTS_RANK_WITHOUT_DECIDING_VALUE_WHERE_SCORED
    -- What it does: Flags scored events where part of the ranked field carries no score.
    'Rank_Without_Deciding_Value' AS check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.template_name,
    x.tournament_name,
    x.ranked_competitors,
    x.unscored_competitors,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds an event that writes result type 644 Score for some of
-- its ranked competitors and not for others, so the field is ranked on a value part of it does
-- not hold.
-- GLOBAL-DQ-122 asks this of every ranked event, and 3373 of the 3700 rows it returns are the
-- DECIDING_VALUE_ABSENT_FROM_EVENT class, where the event carries no Score at all. That is the
-- sport writing its result somewhere else, not a gap in a card. The 327 rows left are events
-- that scored some competitors and not the rest, and that is what this reports.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        tt.name AS template_name,
        t.name AS tournament_name,
        COUNT(DISTINCT ep.id) AS ranked_competitors,
        COUNT(DISTINCT CASE WHEN sc.id IS NULL THEN ep.id END) AS unscored_competitors
    FROM event_participants ep
    JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = 37
    JOIN result rk
      ON rk.event_participantsFK = ep.id
     AND rk.result_typeFK = 100
     AND rk.del = 'no'
     AND rk.value IS NOT NULL
     AND rk.value <> ''
    LEFT JOIN result sc
      ON sc.event_participantsFK = ep.id
     AND sc.result_typeFK = 644
     AND sc.del = 'no'
     AND sc.value IS NOT NULL
     AND sc.value <> ''
    WHERE ep.del = 'no'
      AND t.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
    GROUP BY
        e.id, e.name, e.startdate, tt.name, t.name
    HAVING
        COUNT(DISTINCT CASE WHEN sc.id IS NOT NULL THEN ep.id END) > 0
    AND COUNT(DISTINCT CASE WHEN sc.id IS NULL THEN ep.id END) > 0
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = 37
  AND t.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND EXISTS (
      SELECT 1
      FROM event_participants ep6
      JOIN result sc6 ON sc6.event_participantsFK = ep6.id
           AND sc6.result_typeFK = 644 AND sc6.del = 'no'
      WHERE ep6.eventFK = e.id AND ep6.del = 'no'
  )

ORDER BY sort_order, event_id;

-- ================================================================================

SELECT
    -- CheckID - Equestrian-DQ-094
    -- Name - EVENT_FINAL_MISSING_FROM_ITS_TOURNAMENT_COMP.RANK
    -- What it does: Flags finals whose tournament keeps a Comp.Rank that the final is absent from.
    'Final_Missing_From_Comp_Rank' AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    tt.name AS template_name,
    t.name AS tournament_name,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds an event on a final round type whose tournament does hold
-- at least one Comp.Rank, where no Comp.Rank of that tournament names the event.
-- GLOBAL-DQ-040 reports a final without a Comp.Rank whether or not the tournament keeps one,
-- and this sport keeps 630 rankings against 915 tournaments, so 4602 of the 4649 rows it
-- returns are the TOURNAMENT_HAS_NO_COMP_RANK class. That is how much of the sport the ranking
-- layer covers, which is worth knowing once and is not a defect per final. Where the tournament
-- does keep a ranking and its final is missing from it, something was left out, and that is the
-- 47 this reports.
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
  AND tt.sportFK = 37
  AND e.round_typeFK IN (9, 173)
  AND t.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND EXISTS (
      SELECT 1
      FROM statistic s2
      WHERE s2.objectFK = t.id
        AND s2.object_typeFK = 3
        AND s2.statistic_typeFK = 11
        AND s2.del = 'no'
  )
  AND NOT EXISTS (
      SELECT 1
      FROM statistic s3
      JOIN statistic_config sc3
        ON sc3.statisticFK = s3.id
       AND sc3.statistic_data_typeFK = 1471
      WHERE s3.objectFK = t.id
        AND s3.object_typeFK = 3
        AND s3.statistic_typeFK = 11
        AND s3.del = 'no'
        AND sc3.value = e.id
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
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
  AND tt.sportFK = 37
  AND e.round_typeFK IN (9, 173)
  AND t.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND EXISTS (
      SELECT 1
      FROM statistic s4
      WHERE s4.objectFK = t.id
        AND s4.object_typeFK = 3
        AND s4.statistic_typeFK = 11
        AND s4.del = 'no'
  )

ORDER BY sort_order, event_id;

-- ================================================================================

SELECT
    -- CheckID - Equestrian-DQ-098
    -- Name - COMP.RANK_PAIR_SIDES_CONTRADICT_EACH_OTHER
    -- What it does: Flags Comp.Rank records where the rider row and the horse row of one Pair carry different values in the same data field.
    'Comp_Rank_Pair_Sides_Contradict' AS check_type,
    x.statistic_id,
    x.statistic_name,
    x.template_name,
    x.tournament_name,
    x.contradicting_pair_count,
    x.field_list,
    x.sample_group,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Takes every Comp.Rank Pair holding exactly one rider and one
-- horse, and reports the fields in which the two rows disagree.
-- The rule is the sport's own and no GLOBAL template can express it, because no other sport
-- stores a ride as two participant rows. A rider and the horse it rode are one result written
-- twice, so the two rows are a mirror: measured 2026-08-18 across 10741 pairs and eleven data
-- fields, Rank, Comment, Penalties, Score, Time, Points, Percentage and both Jump Off fields
-- agree on every single pair where both sides carry the field. Only Team and Medal disagree at
-- all, on 20 and 2 pairs.
-- A pair holding two riders or two horses is not audited here: that is a different defect and
-- Equestrian-DQ-060 and Equestrian-DQ-100 own it.
-- What this statement cannot see, and what it must not be read as clearing: a field written on
-- one side and absent from the other. Comparing needs both values to exist, so a pair where
-- only the rider carries Team forms no group here at all and falls silently outside the
-- question rather than passing it. Measured 2026-08-18 that is 255 pairs on Team, one on
-- Comment and one on Medal, none of which this returns. Equestrian-DQ-108 owns them, and this
-- comment claimed the opposite until it was measured on 2026-08-18.
FROM (
    SELECT
        s.id AS statistic_id,
        s.name AS statistic_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        COUNT(DISTINCT c.pair_value) AS contradicting_pair_count,
        GROUP_CONCAT(DISTINCT c.field_name ORDER BY c.field_name SEPARATOR ', ') AS field_list,
        MIN(CONCAT('pair=', c.pair_value,
                   ' field=', c.field_name,
                   ' rider=', c.athlete_value,
                   ' horse=', c.horse_value)) AS sample_group
    FROM (
        SELECT
            s2.id AS statistic_id,
            sd.value AS pair_value,
            sdt.name AS field_name,
            MAX(CASE WHEN p.type = 'athlete' THEN v.value END) AS athlete_value,
            MAX(CASE WHEN p.type = 'horse' THEN v.value END) AS horse_value
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
        JOIN statistic_data11 sd
          ON sd.statistic_participants11FK = sp.id
         AND sd.statistic_data_typeFK = 1276
         AND sd.del = 'no'
         AND sd.value IS NOT NULL
         AND sd.value <> ''
        JOIN participant p
          ON p.id = sp.participantFK
         AND p.del = 'no'
        JOIN statistic_data11 v
          ON v.statistic_participants11FK = sp.id
         AND v.del = 'no'
         AND v.statistic_data_typeFK <> 1276
         AND v.value IS NOT NULL
         AND v.value <> ''
        JOIN statistic_data_type sdt
          ON sdt.id = v.statistic_data_typeFK
        WHERE s2.del = 'no'
          AND s2.statistic_typeFK = 11
          AND s2.object_typeFK = 3
          AND (tt2.name IS NULL OR tt2.name NOT LIKE '%(IOC)%')
          AND t2.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
          -- AND t2.tournament_templateFK = <tournament_template_id>
        GROUP BY
            s2.id,
            sd.value,
            sdt.name
        HAVING
            COUNT(DISTINCT CASE WHEN p.type = 'athlete' THEN sp.id END) = 1
        AND COUNT(DISTINCT CASE WHEN p.type = 'horse' THEN sp.id END) = 1
        AND MAX(CASE WHEN p.type = 'athlete' THEN v.value END) IS NOT NULL
        AND MAX(CASE WHEN p.type = 'horse' THEN v.value END) IS NOT NULL
        AND MAX(CASE WHEN p.type = 'athlete' THEN v.value END)
         <> MAX(CASE WHEN p.type = 'horse' THEN v.value END)
    ) c
    JOIN statistic s
      ON s.id = c.statistic_id
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
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
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

-- ================================================================================

SELECT
    -- CheckID - Equestrian-DQ-099
    -- Name - EVENT_PARTICIPATION_WITHOUT_A_VALID_HORSE
    -- What it does: Flags event participations by a rider that do not name an active horse through the horseFK reference property.
    f.check_type,
    f.participation_id,
    f.event_id,
    f.event_name,
    f.event_startdate,
    f.template_name,
    f.tournament_name,
    f.rider_name,
    f.horse_reference,
    CASE
        WHEN COUNT(*) OVER (PARTITION BY f.event_id) >= f.field_size
        THEN 'whole field'
        ELSE 'part of the field'
    END AS field_reach,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Every ride in this sport is a rider and a horse, and the
-- participation stores only the rider: the horse is reached through a property of type
-- ref:participant named horseFK, whose value is a participant.id. A rider participation that
-- does not resolve to an active horse is therefore half a ride.
-- ../DATABASE.md section 6 owns the mechanism and ../SPORTS/Equestrian.md records that team
-- participations carry no horseFK and correctly so, which is why only athlete participations
-- are audited here.
-- The four classes are four different defects with four different causes and are reported
-- apart rather than as one absence: the property missing entirely, present but holding nothing
-- usable, holding an id no active participant answers to, and holding a participant that is
-- not a horse. A statement testing only for presence reports the first and misses the rest.
-- Measured 2026-08-18 that is 736 participations against 114507 that resolve, so 99.4 percent
-- of the sport names its horse and the reported rows are not the sport.
-- field_reach is why the count is not the finding. Dangling references and most empty ones sit
-- beside riders whose horse resolves, and each is one rider's defect: 272 and 183 of them,
-- spread over 242 and 105 events from 2005 to 2026. The remaining 281 take an entire field at
-- once - seven events from 2004 to 2016 with no horse layer written at all, two more holding
-- nothing usable, and one 2026 event whose whole field points at participants that are not
-- horses. Those are ten events to load again rather than 281 rows to correct one by one, and
-- the column says which a row is without the reviewer counting.
FROM (
    SELECT
        CASE
            WHEN pr.id IS NULL THEN 'Event_Participation_Horse_Reference_Absent'
            WHEN pr.value IS NULL OR TRIM(pr.value) = '' OR TRIM(pr.value) = '0'
              OR pr.value NOT REGEXP '^[0-9]+$' THEN 'Event_Participation_Horse_Reference_Empty'
            WHEN h.id IS NULL THEN 'Event_Participation_Horse_Reference_Dangling'
            ELSE 'Event_Participation_Horse_Reference_Not_A_Horse'
        END AS check_type,
        ep.id AS participation_id,
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        tt.name AS template_name,
        t.name AS tournament_name,
        p.name AS rider_name,
        pr.value AS horse_reference,
        (SELECT COUNT(DISTINCT ep9.id)
           FROM event_participants ep9
           JOIN participant p9
             ON p9.id = ep9.participantFK
            AND p9.del = 'no'
            AND p9.type = 'athlete'
          WHERE ep9.eventFK = e.id
            AND ep9.del = 'no') AS field_size
    FROM event_participants ep
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
     AND tt.sportFK = 37
    JOIN participant p
      ON p.id = ep.participantFK
     AND p.del = 'no'
     AND p.type = 'athlete'
    LEFT JOIN property pr
      ON pr.objectFK = ep.id
     AND pr.object = 'event_participants'
     AND pr.name = 'horseFK'
     AND pr.del = 'no'
    LEFT JOIN participant h
      ON pr.value REGEXP '^[0-9]+$'
     AND h.id = CAST(pr.value AS UNSIGNED)
     AND h.del = 'no'
    WHERE ep.del = 'no'
      AND t.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      AND (
            pr.id IS NULL
         OR pr.value IS NULL
         OR TRIM(pr.value) = ''
         OR TRIM(pr.value) = '0'
         OR pr.value NOT REGEXP '^[0-9]+$'
         OR h.id IS NULL
         OR h.type <> 'horse'
      )
) f

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ep.id) AS eligible_count,
    1 AS sort_order
FROM event_participants ep
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
 AND tt.sportFK = 37
JOIN participant p
  ON p.id = ep.participantFK
 AND p.del = 'no'
 AND p.type = 'athlete'
WHERE ep.del = 'no'
  AND t.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'

ORDER BY sort_order, check_type, participation_id;

-- ================================================================================

SELECT
    -- CheckID - Equestrian-DQ-100
    -- Name - COMP.RANK_PAIR_MISSING_ONE_OF_ITS_TWO_SIDES
    -- What it does: Flags Comp.Rank records holding a Pair that is not one rider and one horse.
    'Comp_Rank_Pair_Missing_One_Side' AS check_type,
    x.statistic_id,
    x.statistic_name,
    x.template_name,
    x.tournament_name,
    x.pairs_horse_without_rider,
    x.pairs_rider_without_horse,
    x.pairs_neither_shape,
    x.sample_group,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: A ride in this sport is a rider and the horse it rode, stored
-- as two participant rows bound by data field 1276 Pair. A Pair that carries only one of the
-- two names half a ride, and the half that is missing says which.
-- Measured 2026-08-18, 11978 Pairs hold exactly one rider and one horse, 418 hold a horse with
-- no rider, 27 a rider with no horse, and 2 hold two horses and no rider at all. So 96.4
-- percent of the sport is the well-formed shape and the reported Pairs are not the sport.
-- Team participant rows carry no Pair value and are therefore never audited here: a team
-- classification row is not a ride. Equestrian-DQ-060 owns the opposite defect, a Pair holding
-- one participant twice, and Equestrian-DQ-098 owns a well-formed Pair whose two rows disagree.
FROM (
    SELECT
        s.id AS statistic_id,
        s.name AS statistic_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        SUM(CASE WHEN g.athletes = 0 AND g.horses = 1 THEN 1 ELSE 0 END) AS pairs_horse_without_rider,
        SUM(CASE WHEN g.athletes = 1 AND g.horses = 0 THEN 1 ELSE 0 END) AS pairs_rider_without_horse,
        SUM(CASE WHEN NOT (g.athletes = 0 AND g.horses = 1)
                  AND NOT (g.athletes = 1 AND g.horses = 0) THEN 1 ELSE 0 END) AS pairs_neither_shape,
        MIN(CONCAT('pair=', g.pair_value,
                   ' riders=', g.athletes,
                   ' horses=', g.horses)) AS sample_group
    FROM (
        SELECT
            s2.id AS statistic_id,
            sd.value AS pair_value,
            COUNT(DISTINCT CASE WHEN p.type = 'athlete' THEN sp.participantFK END) AS athletes,
            COUNT(DISTINCT CASE WHEN p.type = 'horse' THEN sp.participantFK END) AS horses
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
        JOIN statistic_data11 sd
          ON sd.statistic_participants11FK = sp.id
         AND sd.statistic_data_typeFK = 1276
         AND sd.del = 'no'
         AND sd.value IS NOT NULL
         AND sd.value <> ''
        JOIN participant p
          ON p.id = sp.participantFK
         AND p.del = 'no'
        WHERE s2.del = 'no'
          AND s2.statistic_typeFK = 11
          AND s2.object_typeFK = 3
          AND (tt2.name IS NULL OR tt2.name NOT LIKE '%(IOC)%')
          AND t2.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
          -- AND t2.tournament_templateFK = <tournament_template_id>
        GROUP BY
            s2.id,
            sd.value
        HAVING
            COUNT(DISTINCT CASE WHEN p.type = 'athlete' THEN sp.participantFK END) <> 1
         OR COUNT(DISTINCT CASE WHEN p.type = 'horse' THEN sp.participantFK END) <> 1
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
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
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
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
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

-- ================================================================================

SELECT
    -- CheckID - Equestrian-DQ-101
    -- Name - EVENT_LINEUP_MEMBER_WITHOUT_A_VALID_HORSE
    -- What it does: Flags lineup members that do not name an active horse through the horseFK reference property.
    CASE
        WHEN pr.id IS NULL THEN 'Lineup_Member_Horse_Reference_Absent'
        WHEN pr.value IS NULL OR TRIM(pr.value) = '' OR TRIM(pr.value) = '0'
          OR pr.value NOT REGEXP '^[0-9]+$' THEN 'Lineup_Member_Horse_Reference_Empty'
        WHEN h.id IS NULL THEN 'Lineup_Member_Horse_Reference_Dangling'
        ELSE 'Lineup_Member_Horse_Reference_Not_A_Horse'
    END AS check_type,
    l.id AS lineup_id,
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    tt.name AS template_name,
    t.name AS tournament_name,
    tp.name AS team_name,
    p.name AS rider_name,
    pr.value AS horse_reference,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: A team here does not field riders, it fields pairs. The lineup
-- of a team participation lists its riders one by one, and each member carries its own horseFK
-- reference, so the lineup is a list of rider-and-horse pairs rather than a list of people.
-- ../SPORTS/Equestrian.md records the structure and ../DATABASE.md section 6 the mechanism.
-- A member whose reference does not resolve to an active horse is half a pair, and the team it
-- rides for is short one mount.
-- This is the lineup half of Equestrian-DQ-099, and it is a separate statement because the
-- audited object is a lineup row rather than an event participation: the property owner is
-- different, the failure counts are different, and one statement cannot cover both objects.
-- Measured 2026-08-18, 17967 of 18145 lineup rows resolve to an active horse, 154 carry no
-- property at all and 24 point at a participant that does not exist. The two classes that
-- return nothing today are kept because they are structural: the sport stores the same
-- reference in the same way on both owners, so a lineup can fail in the same four ways an
-- event participation already does.
FROM lineup l
JOIN event_participants ep
  ON ep.id = l.event_participantsFK
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
 AND tt.sportFK = 37
JOIN participant p
  ON p.id = l.participantFK
 AND p.del = 'no'
LEFT JOIN participant tp
  ON tp.id = ep.participantFK
 AND tp.del = 'no'
LEFT JOIN property pr
  ON pr.objectFK = l.id
 AND pr.object = 'lineup'
 AND pr.name = 'horseFK'
 AND pr.del = 'no'
LEFT JOIN participant h
  ON pr.value REGEXP '^[0-9]+$'
 AND h.id = CAST(pr.value AS UNSIGNED)
 AND h.del = 'no'
WHERE l.del = 'no'
  AND t.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  AND (
        pr.id IS NULL
     OR pr.value IS NULL
     OR TRIM(pr.value) = ''
     OR TRIM(pr.value) = '0'
     OR pr.value NOT REGEXP '^[0-9]+$'
     OR h.id IS NULL
     OR h.type <> 'horse'
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT l.id) AS eligible_count,
    1 AS sort_order
FROM lineup l
JOIN event_participants ep
  ON ep.id = l.event_participantsFK
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
 AND tt.sportFK = 37
WHERE l.del = 'no'
  AND t.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'

ORDER BY sort_order, check_type, lineup_id;

-- ================================================================================

SELECT
    -- CheckID - Equestrian-DQ-102
    -- Name - OBJECT_DISCIPLINE_NOT_ONE_OF_THE_SPORT_FOUR_DISCIPLINES
    -- What it does: Flags discipline assignments on an event or a Comp.Rank that name a test, a phase or a renamed discipline instead of one of the sport's four.
    'Event_Discipline_Not_One_Of_The_Four' AS check_type,
    od.id AS assignment_id,
    od.object_typeFK AS owner_type_id,
    od.objectFK AS owner_id,
    d.id AS discipline_id,
    d.name AS discipline_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: This sport is four sports in one container - Dressage, Jumping,
-- Eventing and Driving - and object_discipline is what separates them. ../DATABASE.md
-- DB-SEM-019 owns the storage: an event's discipline lives in object_discipline with owner type
-- 5, a Comp.Rank's in owner type 83, and the discipline property is a legacy path.
-- The four are discipline 424 Eventing, 425 Dressage, 426 Jumping and 428 Driving. Everything
-- else the sport writes into that column is one of three things and none of them is a fifth
-- discipline: 69 Show Jumping is a second name for 426 Jumping; 70, 71 and 75 name a dressage
-- test - Grand Prix Freestyle, Grand Prix, Grand Prix Special; and 72, 73, 74, 347 and 402 name
-- a phase inside eventing - Cross Country, Dressage, Jumping, Cross Country Fences.
-- A test and a phase are real things and they belong somewhere. They do not belong here,
-- because anything reading the four to tell one sub-sport from another cannot place them, and
-- the separation the whole sport rests on silently fails for those objects.
-- Measured 2026-08-18 that is 370 events and 31 Comp.Rank records against 5675 and 434, so the
-- four cover 93 percent of events and 93 percent of the ranking layer. The vocabulary was read
-- whole before this was written: all twenty-one values the sport uses are accounted for above,
-- so the reported rows are not a sample of an unknown list.
-- The two owners are asked in separate branches on purpose. object_discipline is one table for
-- every sport and every owner type, so a statement that reaches it first and works out the
-- owner afterwards drives from the whole table: written that way this took 53 seconds against
-- the 3 it takes driving from the sport's own events and statistics.
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
 AND tt.sportFK = 37
JOIN object_discipline od
  ON od.object_typeFK = 5
 AND od.objectFK = e.id
 AND od.del = 'no'
JOIN discipline d
  ON d.id = od.disciplineFK
WHERE e.del = 'no'
  AND od.disciplineFK NOT IN (424, 425, 426, 428)
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND t.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>

UNION ALL

SELECT
    'Comp_Rank_Discipline_Not_One_Of_The_Four' AS check_type,
    od2.id,
    od2.object_typeFK,
    od2.objectFK,
    d2.id,
    d2.name,
    tt2.name,
    t2.name,
    NULL,
    0
FROM statistic s
JOIN tournament t2
  ON t2.id = s.objectFK
 AND t2.del = 'no'
JOIN tournament_template tt2
  ON tt2.id = t2.tournament_templateFK
 AND tt2.del = 'no'
 AND tt2.sportFK = 37
JOIN object_discipline od2
  ON od2.object_typeFK = 83
 AND od2.objectFK = s.id
 AND od2.del = 'no'
JOIN discipline d2
  ON d2.id = od2.disciplineFK
WHERE s.del = 'no'
  AND s.statistic_typeFK = 11
  AND s.object_typeFK = 3
  AND od2.disciplineFK NOT IN (424, 425, 426, 428)
  AND (tt2.name IS NULL OR tt2.name NOT LIKE '%(IOC)%')
  AND t2.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t2.tournament_templateFK = <tournament_template_id>

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT cov.assignment_id) AS eligible_count,
    1 AS sort_order
FROM (
    SELECT od3.id AS assignment_id
    FROM event e3
    JOIN tournament_stage ts3
      ON ts3.id = e3.tournament_stageFK
     AND ts3.del = 'no'
    JOIN tournament t3
      ON t3.id = ts3.tournamentFK
     AND t3.del = 'no'
    JOIN tournament_template tt3
      ON tt3.id = t3.tournament_templateFK
     AND tt3.del = 'no'
     AND tt3.sportFK = 37
    JOIN object_discipline od3
      ON od3.object_typeFK = 5
     AND od3.objectFK = e3.id
     AND od3.del = 'no'
    WHERE e3.del = 'no'
      AND (tt3.name IS NULL OR tt3.name NOT LIKE '%(IOC)%')
      AND t3.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t3.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t3.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t3.tournament_templateFK = <tournament_template_id>

    UNION ALL

    SELECT od4.id
    FROM statistic s4
    JOIN tournament t4
      ON t4.id = s4.objectFK
     AND t4.del = 'no'
    JOIN tournament_template tt4
      ON tt4.id = t4.tournament_templateFK
     AND tt4.del = 'no'
     AND tt4.sportFK = 37
    JOIN object_discipline od4
      ON od4.object_typeFK = 83
     AND od4.objectFK = s4.id
     AND od4.del = 'no'
    WHERE s4.del = 'no'
      AND s4.statistic_typeFK = 11
      AND s4.object_typeFK = 3
      AND (tt4.name IS NULL OR tt4.name NOT LIKE '%(IOC)%')
      AND t4.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t4.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t4.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t4.tournament_templateFK = <tournament_template_id>
) cov

ORDER BY sort_order, check_type, assignment_id;

-- ================================================================================

SELECT
    -- CheckID - Equestrian-DQ-103
    -- Name - EVENT_HORSE_RIDDEN_BY_MORE_THAN_ONE_RIDER
    -- What it does: Flags events in which one horse is entered under more than one rider.
    'Event_Horse_Ridden_By_More_Than_One_Rider' AS check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.template_name,
    x.tournament_name,
    x.affected_horse_count,
    x.horse_list,
    x.sample_group,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: A horse contests a class once and under one rider. A horse
-- carrying two riders inside one event is therefore not a shape the sport can produce, whatever
-- the discipline: the pair is the competitor, and two pairs cannot share the animal.
-- Equestrian-DQ-069 owns the mirror defect, a rider entered twice without a second horse. This
-- is the same rule read from the other side, and neither implies the other: a rider on two
-- horses is normal here and a horse under two riders never is.
-- Measured 2026-08-18 it returns 44 events holding 46 such horses - two events hold two, the
-- rest one each - and every one of the 46 carries exactly two riders and never three. They are
-- spread across all four disciplines, 20 Jumping, 18 Dressage, 5 Eventing and 3 on the legacy
-- Show Jumping value, and across every year from 2004 to 2026. A defect that appears at the
-- same low rate in every discipline and every season is not a format one discipline uses.
-- Only a horse reference that resolves to an active participant is audited. A reference
-- pointing nowhere is a different defect and Equestrian-DQ-099 owns it; counted here it would
-- add 12 more that say nothing about who rode what.
-- Three of the 46 are worth naming because they are not what they look like: the two riders
-- carry the same name. A rider recorded twice splits one entry into two under one horse, so
-- this check reaches the duplicate-participant question from a side no DUPLICATE template does.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        tt.name AS template_name,
        t.name AS tournament_name,
        COUNT(*) AS affected_horse_count,
        GROUP_CONCAT(DISTINCT g.horse_name ORDER BY g.horse_name SEPARATOR ' / ') AS horse_list,
        MIN(CONCAT('horse=', g.horse_name, ' riders=', g.rider_names)) AS sample_group
    FROM (
        SELECT
            ep.eventFK AS event_id,
            h.id AS horse_id,
            h.name AS horse_name,
            GROUP_CONCAT(DISTINCT p.name ORDER BY p.name SEPARATOR ' + ') AS rider_names
        FROM event_participants ep
        JOIN event e2
          ON e2.id = ep.eventFK
         AND e2.del = 'no'
        JOIN tournament_stage ts2
          ON ts2.id = e2.tournament_stageFK
         AND ts2.del = 'no'
        JOIN tournament t2
          ON t2.id = ts2.tournamentFK
         AND t2.del = 'no'
        JOIN tournament_template tt2
          ON tt2.id = t2.tournament_templateFK
         AND tt2.del = 'no'
         AND tt2.sportFK = 37
        JOIN participant p
          ON p.id = ep.participantFK
         AND p.del = 'no'
        JOIN property pr
          ON pr.object = 'event_participants'
         AND pr.objectFK = ep.id
         AND pr.name = 'horseFK'
         AND pr.del = 'no'
         AND pr.value REGEXP '^[0-9]+$'
        JOIN participant h
          ON h.id = CAST(pr.value AS UNSIGNED)
         AND h.del = 'no'
        WHERE ep.del = 'no'
          AND t2.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
          -- AND t2.tournament_templateFK = <tournament_template_id>
        GROUP BY
            ep.eventFK,
            h.id,
            h.name
        HAVING
            COUNT(DISTINCT ep.participantFK) > 1
    ) g
    JOIN event e
      ON e.id = g.event_id
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
    GROUP BY
        e.id,
        e.name,
        e.startdate,
        tt.name,
        t.name
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
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
  AND tt.sportFK = 37
  AND t.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND EXISTS (
      SELECT 1
      FROM event_participants ep4
      JOIN property pr4
        ON pr4.object = 'event_participants'
       AND pr4.objectFK = ep4.id
       AND pr4.name = 'horseFK'
       AND pr4.del = 'no'
      WHERE ep4.eventFK = e.id
        AND ep4.del = 'no'
  )

ORDER BY sort_order, event_id;

-- ================================================================================

SELECT
    -- CheckID - Equestrian-DQ-104
    -- Name - EVENT_LINEUP_HORSE_RIDDEN_BY_MORE_THAN_ONE_MEMBER
    -- What it does: Flags events in which one horse is named by more than one lineup member.
    'Lineup_Horse_Ridden_By_More_Than_One_Member' AS check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.template_name,
    x.tournament_name,
    x.affected_horse_count,
    x.horse_list,
    x.sample_group,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: The lineup half of Equestrian-DQ-103, and a separate statement
-- because the audited population is different: a lineup names the members of a team, so a horse
-- shared here is shared inside one squad or between two squads of the same event, and the
-- coverage denominator is the events that field teams rather than every event with a horse.
-- A team fields pairs, not riders. Two members of a team, or two teams in one event, naming the
-- same animal is the same impossibility the event layer reports and is reached by a different
-- path, so neither statement finds the other's rows.
-- Measured 2026-08-18 it returns 11 horse-and-event pairs across 8 events. The number is small
-- because the layer is: 18145 lineup rows against 115243 participations.
-- Only a horse reference that resolves to an active participant is audited; a reference
-- pointing nowhere is Equestrian-DQ-101's defect, not this one.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        tt.name AS template_name,
        t.name AS tournament_name,
        COUNT(*) AS affected_horse_count,
        GROUP_CONCAT(DISTINCT g.horse_name ORDER BY g.horse_name SEPARATOR ' / ') AS horse_list,
        MIN(CONCAT('horse=', g.horse_name, ' riders=', g.rider_names)) AS sample_group
    FROM (
        SELECT
            ep.eventFK AS event_id,
            h.id AS horse_id,
            h.name AS horse_name,
            GROUP_CONCAT(DISTINCT p.name ORDER BY p.name SEPARATOR ' + ') AS rider_names
        FROM lineup l
        JOIN event_participants ep
          ON ep.id = l.event_participantsFK
         AND ep.del = 'no'
        JOIN event e2
          ON e2.id = ep.eventFK
         AND e2.del = 'no'
        JOIN tournament_stage ts2
          ON ts2.id = e2.tournament_stageFK
         AND ts2.del = 'no'
        JOIN tournament t2
          ON t2.id = ts2.tournamentFK
         AND t2.del = 'no'
        JOIN tournament_template tt2
          ON tt2.id = t2.tournament_templateFK
         AND tt2.del = 'no'
         AND tt2.sportFK = 37
        JOIN participant p
          ON p.id = l.participantFK
         AND p.del = 'no'
        JOIN property pr
          ON pr.object = 'lineup'
         AND pr.objectFK = l.id
         AND pr.name = 'horseFK'
         AND pr.del = 'no'
         AND pr.value REGEXP '^[0-9]+$'
        JOIN participant h
          ON h.id = CAST(pr.value AS UNSIGNED)
         AND h.del = 'no'
        WHERE l.del = 'no'
          AND t2.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
          -- AND t2.tournament_templateFK = <tournament_template_id>
        GROUP BY
            ep.eventFK,
            h.id,
            h.name
        HAVING
            COUNT(DISTINCT l.participantFK) > 1
    ) g
    JOIN event e
      ON e.id = g.event_id
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
    GROUP BY
        e.id,
        e.name,
        e.startdate,
        tt.name,
        t.name
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
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
  AND tt.sportFK = 37
  AND t.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND EXISTS (
      SELECT 1
      FROM lineup l4
      JOIN event_participants ep4
        ON ep4.id = l4.event_participantsFK
       AND ep4.del = 'no'
      WHERE ep4.eventFK = e.id
        AND l4.del = 'no'
  )

ORDER BY sort_order, event_id;

-- ================================================================================

SELECT
    -- CheckID - Equestrian-DQ-105
    -- Name - EVENT_LINEUP_COMPOSED_OF_THE_WRONG_PARTICIPANT_TYPES
    -- What it does: Flags lineup rows whose parent participation is not a team or whose member is not an athlete.
    CASE
        WHEN pp.type <> 'team' AND lp.type <> 'athlete' THEN 'Lineup_Parent_And_Member_Both_Wrong_Type'
        WHEN pp.type <> 'team' THEN 'Lineup_Parent_Participation_Not_A_Team'
        ELSE 'Lineup_Member_Not_An_Athlete'
    END AS check_type,
    l.id AS lineup_id,
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    tt.name AS template_name,
    t.name AS tournament_name,
    pp.name AS parent_name,
    pp.type AS parent_type,
    lp.name AS member_name,
    lp.type AS member_type,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: A lineup here has one shape and only one. Its parent event
-- participation is a team, and every member of it is an athlete who brings a horse of their
-- own through the horseFK reference. That is what makes a team in this sport a set of pairs
-- rather than a set of people, and ../SPORTS/Equestrian.md records it.
-- The rule holds without exception today: measured 2026-08-18, none of the sport's 18145
-- lineup rows sits under a participation that is not a team, and none names a member that is
-- not an athlete. Zero is the whole point. The columns exist, they are populated, and one
-- lineup type is in use, so a horse written straight into a lineup or a lineup hung under an
-- individual entry would be audited the moment it appeared. This check is the guard on a shape
-- nothing else in the package asserts: Equestrian-DQ-030 asks whether a team has a lineup at
-- all, -054 whether a member repeats, -058 whether the squads are the same size and -065 how
-- the genders balance. None of them asks who is allowed inside.
-- A member that is a horse would be reported as Lineup_Member_Not_An_Athlete, and that is the
-- failure this is really written for: the horse belongs in the reference property, never in the
-- member column, and the two are one edit apart in any loader.
-- Coverage is 18144 rather than 18145 because both participants must resolve for a row to be
-- audited at all, and one lineup row names a participant that is soft-deleted. That row is
-- outside this statement's question rather than a finding it missed: whether a participation
-- may reference a deleted participant is Equestrian-DQ-055's, and the two branches here count
-- the same population so the contract holds.
FROM lineup l
JOIN event_participants ep
  ON ep.id = l.event_participantsFK
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
 AND tt.sportFK = 37
JOIN participant pp
  ON pp.id = ep.participantFK
 AND pp.del = 'no'
JOIN participant lp
  ON lp.id = l.participantFK
 AND lp.del = 'no'
WHERE l.del = 'no'
  AND t.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  AND (pp.type <> 'team' OR lp.type <> 'athlete')

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT l.id) AS eligible_count,
    1 AS sort_order
FROM lineup l
JOIN event_participants ep
  ON ep.id = l.event_participantsFK
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
 AND tt.sportFK = 37
JOIN participant pp
  ON pp.id = ep.participantFK
 AND pp.del = 'no'
JOIN participant lp
  ON lp.id = l.participantFK
 AND lp.del = 'no'
WHERE l.del = 'no'
  AND t.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'

ORDER BY sort_order, check_type, lineup_id;

-- ================================================================================

SELECT
    -- CheckID - Equestrian-DQ-106
    -- Name - COMP.RANK_TEAM_FIELD_NOT_NAMING_A_TEAM
    -- What it does: Flags Comp.Rank rows whose Team data field does not resolve to an active participant of type team.
    CASE
        WHEN sd.value NOT REGEXP '^[0-9]+$' THEN 'Comp_Rank_Team_Reference_Not_Numeric'
        WHEN tp.id IS NULL THEN 'Comp_Rank_Team_Reference_Dangling'
        ELSE 'Comp_Rank_Team_Reference_Not_A_Team'
    END AS check_type,
    sp.id AS participant_row_id,
    s.id AS statistic_id,
    s.name AS statistic_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    p.name AS participant_name,
    p.type AS participant_type,
    sd.value AS team_reference,
    tp.type AS referenced_type,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Data field 1429 Team holds a participant.id, not a name and not
-- a squad number, so it is a reference like any other and it can fail like any other. The
-- database does not resolve it: whoever reads it does, and nothing stops the value being a
-- number that answers to nobody, or to somebody who is not a team.
-- ../SPORTS/Equestrian.md records the field as carrying a participant.id and this is the
-- statement that holds it to that. Measured 2026-08-18 every one of the rows carrying a Team
-- value resolves to an active team, so it returns nothing today, which is what a guard on a
-- reference is supposed to do until the day it does not.
-- The three classes separate three different causes, in the order they can be told apart: a
-- value that is not a number at all was never a reference; a number nobody answers to is a
-- deleted or never-loaded team; and a number answering to an athlete or a horse is the wrong
-- column read into the right one.
-- Equestrian-DQ-098 asks a different question of the same field - whether the rider and the
-- horse of one Pair name the same team - and found 20 that do not. That check compares two
-- values and cannot tell whether either is a team; this one never compares and only asks what
-- the value points at. Neither covers the other.
FROM statistic_participants11 sp
JOIN statistic s
  ON s.id = sp.statisticFK
 AND s.del = 'no'
 AND s.statistic_typeFK = 11
 AND s.object_typeFK = 3
JOIN tournament t
  ON t.id = s.objectFK
 AND t.del = 'no'
JOIN tournament_template tt
  ON tt.id = t.tournament_templateFK
 AND tt.del = 'no'
 AND tt.sportFK = 37
JOIN participant p
  ON p.id = sp.participantFK
 AND p.del = 'no'
JOIN statistic_data11 sd
  ON sd.statistic_participants11FK = sp.id
 AND sd.statistic_data_typeFK = 1429
 AND sd.del = 'no'
 AND sd.value IS NOT NULL
 AND sd.value <> ''
LEFT JOIN participant tp
  ON sd.value REGEXP '^[0-9]+$'
 AND tp.id = CAST(sd.value AS UNSIGNED)
 AND tp.del = 'no'
WHERE sp.del = 'no'
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND t.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND (
        sd.value NOT REGEXP '^[0-9]+$'
     OR tp.id IS NULL
     OR tp.type <> 'team'
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT sp.id) AS eligible_count,
    1 AS sort_order
FROM statistic_participants11 sp
JOIN statistic s
  ON s.id = sp.statisticFK
 AND s.del = 'no'
 AND s.statistic_typeFK = 11
 AND s.object_typeFK = 3
JOIN tournament t
  ON t.id = s.objectFK
 AND t.del = 'no'
JOIN tournament_template tt
  ON tt.id = t.tournament_templateFK
 AND tt.del = 'no'
 AND tt.sportFK = 37
JOIN statistic_data11 sd
  ON sd.statistic_participants11FK = sp.id
 AND sd.statistic_data_typeFK = 1429
 AND sd.del = 'no'
 AND sd.value IS NOT NULL
 AND sd.value <> ''
WHERE sp.del = 'no'
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND t.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, check_type, participant_row_id;

-- ================================================================================

SELECT
    -- CheckID - Equestrian-DQ-107
    -- Name - PARTICIPANT_RECORDED_TWICE_UNDER_ONE_RIDE
    -- What it does: Flags a horse or a rider held as two participant records, proved by the two records meeting inside one ride rather than by their names alone.
    'Horse_Recorded_Twice_Under_One_Rider' AS check_type,
    ha.id AS participant_id,
    ha.name AS participant_name,
    ha.type AS participant_type,
    ha.gender,
    ha.countryFK AS country_id,
    GROUP_CONCAT(DISTINCT CONCAT(hb.id, ' ', hb.name) ORDER BY hb.id SEPARATOR ' | ') AS twin_records,
    GROUP_CONCAT(DISTINCT rp.name ORDER BY rp.name SEPARATOR ' | ') AS shared_with,
    COUNT(DISTINCT g.tournament_id) AS tournaments,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: The name alone never proves a duplicate, and in this sport it
-- proves less than usual: horse names carry a stable or a sponsor at the front, so Castle Forbes
-- Libertina and Castle Forbes Cosma share three words and are two animals. What proves it here
-- is the ride. One rider, inside one tournament, cannot be mounted on two different horses that
-- carry the same name, so two records meeting under one rider is the evidence and the name only
-- says which two to compare.
-- Measured 2026-08-18, 713 pairs of horse records share their first word under one rider in one
-- tournament. Of those, 258 carry an identical name and 40 have one name extending the other -
-- Clooney and Clooney 51, Charmeur and Charmeur 344, Bacardi and Bacardi Old - and the other
-- 415 share only that first word and are the stable prefixes, which is why the first word alone
-- is not the condition. So 298 pairs are reported and 415 are not, and the split was read
-- before it was written rather than chosen by a threshold.
-- The rider class is the same evidence with the roles swapped: two rider records of one name
-- entered on one horse in one event. It returns one duplicated rider, met in three separate
-- events, which Equestrian-DQ-103 already reaches from the other side where it looks like a
-- horse carrying two riders.
-- Together the two classes report 573 records: 571 horses standing in 315 distinct pairs, and
-- the 2 rider records. A record appears once however many pairs it belongs to, so the row count
-- is records to merge rather than comparisons to read.
-- One thing the output says that no count does. Of the 315 horse pairs, 106 carry the horse
-- gender vocabulary on one side and the person vocabulary on the other - Absolut is gelding on
-- one record and male on the other, Active Walero undefined against gelding - and a further 41
-- pair person against undefined. Where the two records are provably one animal, the two
-- vocabularies are two spellings of one fact rather than two meanings. ../SPORTS/Equestrian.md
-- records the vocabulary split; this is the evidence that it is a split and not a distinction.
-- GLOBAL-DISCOVERY-033 groups a sport's people by name and is discovery, not a check: it reads
-- athletes only, so the horse register - 25571 rows and the largest of the sport's three roles -
-- is outside it entirely. Every DUPLICATE template in GLOBAL_DQ asserts one participant recorded
-- twice in one place; this asserts two records that are one being, which is not the same
-- statement and cannot be reached by parameterising one.
-- A pair whose names differ past the first word is not reported even when it is real: Caramia 34
-- and Caramia FRH are one mare and this statement misses her, because a rule loose enough to
-- catch that shape also catches the 415. The limit is named here rather than left to be found.
FROM (
    SELECT
        r1.tournament_id,
        r1.rider_id,
        r1.horse_id AS horse_a,
        r2.horse_id AS horse_b
    FROM (
        SELECT DISTINCT
               ts.tournamentFK AS tournament_id,
               ep.participantFK AS rider_id,
               h.id AS horse_id,
               LOWER(TRIM(h.name)) AS horse_name,
               LOWER(SUBSTRING_INDEX(TRIM(h.name), ' ', 1)) AS stem
        FROM event_participants ep
        JOIN property pr
          ON pr.object = 'event_participants'
         AND pr.objectFK = ep.id
         AND pr.name = 'horseFK'
         AND pr.del = 'no'
         AND pr.value REGEXP '^[0-9]+$'
        JOIN participant h
          ON h.id = CAST(pr.value AS UNSIGNED)
         AND h.del = 'no'
         AND h.type = 'horse'
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
         AND tt.sportFK = 37
        WHERE ep.del = 'no'
          AND t.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
          -- AND t.tournament_templateFK = <tournament_template_id>
    ) r1
    JOIN (
        SELECT DISTINCT
               ts.tournamentFK AS tournament_id,
               ep.participantFK AS rider_id,
               h.id AS horse_id,
               LOWER(TRIM(h.name)) AS horse_name,
               LOWER(SUBSTRING_INDEX(TRIM(h.name), ' ', 1)) AS stem
        FROM event_participants ep
        JOIN property pr
          ON pr.object = 'event_participants'
         AND pr.objectFK = ep.id
         AND pr.name = 'horseFK'
         AND pr.del = 'no'
         AND pr.value REGEXP '^[0-9]+$'
        JOIN participant h
          ON h.id = CAST(pr.value AS UNSIGNED)
         AND h.del = 'no'
         AND h.type = 'horse'
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
         AND tt.sportFK = 37
        WHERE ep.del = 'no'
          AND t.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
          -- AND t.tournament_templateFK = <tournament_template_id>
    ) r2
      ON r2.tournament_id = r1.tournament_id
     AND r2.rider_id = r1.rider_id
     AND r2.stem = r1.stem
     AND r2.horse_id <> r1.horse_id
     AND (
            r2.horse_name = r1.horse_name
         OR r2.horse_name LIKE CONCAT(r1.horse_name, ' %')
         OR r1.horse_name LIKE CONCAT(r2.horse_name, ' %')
     )
) g
JOIN participant ha
  ON ha.id = g.horse_a
 AND ha.del = 'no'
JOIN participant hb
  ON hb.id = g.horse_b
 AND hb.del = 'no'
JOIN participant rp
  ON rp.id = g.rider_id
 AND rp.del = 'no'
GROUP BY
    ha.id,
    ha.name,
    ha.type,
    ha.gender,
    ha.countryFK

UNION ALL

SELECT
    'Rider_Recorded_Twice_On_One_Horse' AS check_type,
    pa.id,
    pa.name,
    pa.type,
    pa.gender,
    pa.countryFK,
    GROUP_CONCAT(DISTINCT CONCAT(pb.id, ' ', pb.name) ORDER BY pb.id SEPARATOR ' | '),
    GROUP_CONCAT(DISTINCT hz.name ORDER BY hz.name SEPARATOR ' | '),
    COUNT(DISTINCT k.event_id),
    NULL,
    0
FROM (
    SELECT
        q1.event_id,
        q1.horse_id,
        q1.rider_id AS rider_a,
        q2.rider_id AS rider_b
    FROM (
        SELECT DISTINCT
               ep.eventFK AS event_id,
               CAST(pr.value AS UNSIGNED) AS horse_id,
               ep.participantFK AS rider_id,
               LOWER(TRIM(p.name)) AS rider_name
        FROM event_participants ep
        JOIN property pr
          ON pr.object = 'event_participants'
         AND pr.objectFK = ep.id
         AND pr.name = 'horseFK'
         AND pr.del = 'no'
         AND pr.value REGEXP '^[0-9]+$'
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
         AND tt.sportFK = 37
        WHERE ep.del = 'no'
          AND t.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
          -- AND t.tournament_templateFK = <tournament_template_id>
    ) q1
    JOIN (
        SELECT DISTINCT
               ep.eventFK AS event_id,
               CAST(pr.value AS UNSIGNED) AS horse_id,
               ep.participantFK AS rider_id,
               LOWER(TRIM(p.name)) AS rider_name
        FROM event_participants ep
        JOIN property pr
          ON pr.object = 'event_participants'
         AND pr.objectFK = ep.id
         AND pr.name = 'horseFK'
         AND pr.del = 'no'
         AND pr.value REGEXP '^[0-9]+$'
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
         AND tt.sportFK = 37
        WHERE ep.del = 'no'
          AND t.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
          -- AND t.tournament_templateFK = <tournament_template_id>
    ) q2
      ON q2.event_id = q1.event_id
     AND q2.horse_id = q1.horse_id
     AND q2.rider_name = q1.rider_name
     AND q2.rider_id <> q1.rider_id
) k
JOIN participant pa
  ON pa.id = k.rider_a
 AND pa.del = 'no'
JOIN participant pb
  ON pb.id = k.rider_b
 AND pb.del = 'no'
JOIN participant hz
  ON hz.id = k.horse_id
 AND hz.del = 'no'
GROUP BY
    pa.id,
    pa.name,
    pa.type,
    pa.gender,
    pa.countryFK

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT p.id) AS eligible_count,
    1 AS sort_order
FROM object_participants op
JOIN participant p
  ON p.id = op.participantFK
 AND p.del = 'no'
 AND p.type IN ('athlete', 'horse')
WHERE op.object = 'sport'
  AND op.objectFK = 37
  AND op.del = 'no'

ORDER BY sort_order, check_type, participant_name;

-- ================================================================================

SELECT
    -- CheckID - Equestrian-DQ-108
    -- Name - COMP.RANK_PAIR_FIELD_CARRIED_BY_ONE_SIDE_ONLY
    -- What it does: Flags Comp.Rank pairs holding a data field on the rider row or the horse row alone, where the same record writes that field on both sides for other pairs.
    CASE
        WHEN g.athlete_rows > 0 THEN 'Comp_Rank_Field_On_The_Rider_Row_Only'
        ELSE 'Comp_Rank_Field_On_The_Horse_Row_Only'
    END AS check_type,
    g.statistic_id,
    s.name AS statistic_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    g.pair_value,
    sdt.name AS field_name,
    g.pairs_with_both_sides AS same_field_on_both_sides_here,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: A rider and the horse it rode are two rows and one competitor,
-- so the sport writes the ride's result into both. Equestrian-DQ-098 asks whether the two rows
-- disagree; this asks whether one of them is simply absent, which is a different defect and one
-- that check cannot see - it compares two values and needs both to exist before it can compare.
-- Measured 2026-08-18, 255 pairs carry Team on the rider row alone, one carries Comment on the
-- horse row alone and one carries Medal on the rider row alone.
-- Most of the 255 are not reported and the condition is why. Summer Olympics 2016 and 2020 write
-- Team on the rider row for their entire field and never on a horse row at all - 107 and 100
-- pairs, no exceptions - so within those records the one-sided form is the convention rather
-- than an omission, and a shape reaching a whole field is a format. The condition therefore
-- reports a one-sided value only where the same Comp.Rank record writes that field on both
-- sides for some other pair, which is the record contradicting itself rather than following a
-- convention this project does not own. That leaves 10: nine on the rider row and one on the
-- horse row.
-- The grain is the Comp.Rank record and not the tournament, which is what makes it 10 rather
-- than 48. Eventing European Championships 2017 holds two records, and one of them writes Team
-- one-sidedly throughout while the other writes it both ways; read per tournament that is 40
-- findings, read per record it is none, because neither record contradicts itself. The record
-- is the right grain because it is what a convention belongs to - one load, one writer.
-- Pairs holding two riders or two horses are not audited: Equestrian-DQ-100 owns that.
FROM (
  SELECT
      w.*,
      SUM(CASE WHEN w.athlete_rows > 0 AND w.horse_rows > 0 THEN 1 ELSE 0 END)
          OVER (PARTITION BY w.statistic_id, w.field_id) AS pairs_with_both_sides
  FROM (
    SELECT
        pr.statistic_id,
        pr.pair_value,
        v.statistic_data_typeFK AS field_id,
        SUM(CASE WHEN pr.athlete_row = v.statistic_participants11FK THEN 1 ELSE 0 END) AS athlete_rows,
        SUM(CASE WHEN pr.horse_row = v.statistic_participants11FK THEN 1 ELSE 0 END) AS horse_rows
    FROM (
        SELECT
            s2.id AS statistic_id,
            sd2.value AS pair_value,
            MAX(CASE WHEN p2.type = 'athlete' THEN sp2.id END) AS athlete_row,
            MAX(CASE WHEN p2.type = 'horse' THEN sp2.id END) AS horse_row
        FROM statistic s2
        JOIN tournament t2
          ON t2.id = s2.objectFK
         AND t2.del = 'no'
        JOIN tournament_template tt2
          ON tt2.id = t2.tournament_templateFK
         AND tt2.del = 'no'
         AND tt2.sportFK = 37
        JOIN statistic_participants11 sp2
          ON sp2.statisticFK = s2.id
         AND sp2.del = 'no'
        JOIN statistic_data11 sd2
          ON sd2.statistic_participants11FK = sp2.id
         AND sd2.statistic_data_typeFK = 1276
         AND sd2.del = 'no'
         AND sd2.value IS NOT NULL
         AND sd2.value <> ''
        JOIN participant p2
          ON p2.id = sp2.participantFK
         AND p2.del = 'no'
        WHERE s2.del = 'no'
          AND s2.statistic_typeFK = 11
          AND s2.object_typeFK = 3
          AND (tt2.name IS NULL OR tt2.name NOT LIKE '%(IOC)%')
          AND t2.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
          -- AND t2.tournament_templateFK = <tournament_template_id>
        GROUP BY
            s2.id,
            sd2.value
        HAVING
            COUNT(DISTINCT CASE WHEN p2.type = 'athlete' THEN sp2.id END) = 1
        AND COUNT(DISTINCT CASE WHEN p2.type = 'horse' THEN sp2.id END) = 1
    ) pr
    JOIN statistic_data11 v
      ON v.statistic_participants11FK IN (pr.athlete_row, pr.horse_row)
     AND v.del = 'no'
     AND v.statistic_data_typeFK <> 1276
     AND v.value IS NOT NULL
     AND v.value <> ''
    GROUP BY
        pr.statistic_id,
        pr.pair_value,
        v.statistic_data_typeFK
  ) w
) g
JOIN statistic_data_type sdt
  ON sdt.id = g.field_id
JOIN statistic s
  ON s.id = g.statistic_id
 AND s.del = 'no'
JOIN tournament t
  ON t.id = s.objectFK
 AND t.del = 'no'
JOIN tournament_template tt
  ON tt.id = t.tournament_templateFK
 AND tt.del = 'no'
WHERE (g.athlete_rows = 0 OR g.horse_rows = 0)
  AND g.pairs_with_both_sides > 0

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
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
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

ORDER BY sort_order, statistic_id, pair_value;

-- ================================================================================

SELECT
    -- CheckID - Equestrian-DQ-109
    -- Name - EVENT_RANKED_PARTICIPATION_HOLDING_NO_MEASURE_WHERE_THE_FIELD_IS_MEASURED
    -- What it does: Flags ranked event participations carrying none of the sport's measuring result types, in events where part of the field carries one.
    'Ranked_Participation_Without_Any_Measure' AS check_type,
    f.participation_id,
    f.event_id,
    f.event_name,
    f.event_startdate,
    f.discipline,
    f.template_name,
    f.tournament_name,
    f.rider_name,
    f.rank_value,
    f.ranked_field,
    f.measured_in_field,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: A place in a ranked field is produced by something - a mark, a
-- fault count, a time, a points total. This asks whether the participation carrying the place
-- also carries any of them: 644 Score, 312 Errors, 101 Duration, 102 Points, 6 Running Score,
-- 515 and 516 Jump Off, 545 Penalties. Eight result types, and the participation must hold none.
-- Equestrian-DQ-093 asks a narrower form of this and returns 336: it reads 644 Score alone, so
-- it cannot see a dressage card measured on points or an eventing card measured on penalties.
-- Reading all eight raises it to 1418 across 385 events, and the extra thousand are Dressage and
-- Eventing rather than more of the same.
-- The condition that makes it mean anything is the last one. Measured 2026-08-18, 66282 ranked
-- participations across 2867 events carry no measure at all and take the whole ranked field with
-- them - 55513 of those in Jumping, where the sport is loaded with a place and nothing else.
-- That is the format and it is not reported. What is reported is the 1418 sitting in a field
-- whose other members are measured, where the event itself proves a measure was available and
-- this card did not get one.
-- 0xC2A0 is replaced before the emptiness test because ../SPORTS/Equestrian.md records 69 Score
-- values whose entire content is one non-breaking space; TRIM does not remove it and a naive
-- test reads those cards as measured.
FROM (
    SELECT
        ep.id AS participation_id,
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        COALESCE(d.name, '(none)') AS discipline,
        tt.name AS template_name,
        t.name AS tournament_name,
        p.name AS rider_name,
        CAST(rk.value AS UNSIGNED) AS rank_value,
        COUNT(*) OVER (PARTITION BY e.id) AS ranked_field,
        SUM(CASE WHEN mv.measured = 1 THEN 1 ELSE 0 END) OVER (PARTITION BY e.id) AS measured_in_field,
        mv.measured AS this_one_measured
    FROM event_participants ep
    JOIN result rk
      ON rk.event_participantsFK = ep.id
     AND rk.result_typeFK = 100
     AND rk.del = 'no'
     AND rk.value REGEXP '^[0-9]+$'
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
     AND tt.sportFK = 37
    JOIN participant p
      ON p.id = ep.participantFK
     AND p.del = 'no'
    LEFT JOIN object_discipline od
      ON od.object_typeFK = 5
     AND od.objectFK = e.id
     AND od.del = 'no'
    LEFT JOIN discipline d
      ON d.id = od.disciplineFK
    JOIN (
        SELECT
            ep3.id AS participation_id,
            MAX(CASE WHEN m.id IS NULL THEN 0 ELSE 1 END) AS measured
        FROM event_participants ep3
        JOIN event e3
          ON e3.id = ep3.eventFK
         AND e3.del = 'no'
        JOIN tournament_stage ts3
          ON ts3.id = e3.tournament_stageFK
         AND ts3.del = 'no'
        JOIN tournament t3
          ON t3.id = ts3.tournamentFK
         AND t3.del = 'no'
        JOIN tournament_template tt3
          ON tt3.id = t3.tournament_templateFK
         AND tt3.del = 'no'
         AND tt3.sportFK = 37
        LEFT JOIN result m
          ON m.event_participantsFK = ep3.id
         AND m.del = 'no'
         AND m.result_typeFK IN (644, 312, 101, 102, 6, 515, 516, 545)
         AND m.value IS NOT NULL
         AND TRIM(REPLACE(m.value, 0xC2A0, '')) <> ''
        WHERE ep3.del = 'no'
          AND t3.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t3.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t3.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
          -- AND t3.tournament_templateFK = <tournament_template_id>
        GROUP BY
            ep3.id
    ) mv
      ON mv.participation_id = ep.id
    WHERE ep.del = 'no'
      AND t.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
) f
WHERE f.this_one_measured = 0
  AND f.measured_in_field > 0

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ep.id) AS eligible_count,
    1 AS sort_order
FROM event_participants ep
JOIN result rk
  ON rk.event_participantsFK = ep.id
 AND rk.result_typeFK = 100
 AND rk.del = 'no'
 AND rk.value REGEXP '^[0-9]+$'
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
 AND tt.sportFK = 37
WHERE ep.del = 'no'
  AND t.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'

ORDER BY sort_order, event_id, rank_value;

-- ================================================================================

SELECT
    -- CheckID - Equestrian-DQ-110
    -- Name - TEMPLATE_NAME_STOPPED_AT_THE_STORAGE_CEILING
    -- What it does: Flags tournament templates whose name is as long as any name the sport stores, which is where a name clipped by the column stops rather than where it ends.
    'Template_Name_At_The_Storage_Ceiling' AS check_type,
    tt.id AS template_id,
    tt.name AS template_name,
    LENGTH(tt.name) AS name_length,
    SUBSTRING_INDEX(tt.name, ' ', -1) AS last_word,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: A name that stops exactly where the storage stops has not
-- ended, it has been cut, and nothing downstream can tell the difference: the clipped name
-- travels into every report, every board tab and every join anybody makes on it.
-- Measured 2026-08-18 the sport's template names reach 50 characters and no further, and four
-- sit at 50. Two of them end mid-word - FEI Jumping World Cup Northern Central European Le and
-- the Southern one beside it, each missing the rest of League - while the two North America
-- names reach exactly 50 and end on a complete League. So the ceiling is real and it clips some
-- names and merely touches others, which is why last_word is projected: it turns the finding
-- into a one-glance decision instead of a measurement the reviewer has to repeat.
-- The ceiling is read from the data rather than written in, so the statement keeps working if
-- the column is widened: it reports the names at whatever the current maximum is, and where that
-- maximum is a real title rather than a cut one the finding is read and dismissed. That is the
-- honest form. A hard-coded 50 would go silently blind the day the column changes, which is the
-- day this check is most needed.
-- No GLOBAL template asks this. It is written here because Equestrian is where it was found;
-- the question is not sport-specific and belongs in GLOBAL_DQ if anybody promotes it.
FROM tournament_template tt
WHERE tt.del = 'no'
  AND tt.sportFK = 37
  AND tt.id NOT IN (12779, 12780, 12781, 12785, 12787)
  -- AND tt.id = <tournament_template_id>
  AND LENGTH(tt.name) = (
      SELECT MAX(LENGTH(tt2.name))
      FROM tournament_template tt2
      WHERE tt2.del = 'no'
        AND tt2.sportFK = 37
        AND tt2.id NOT IN (12779, 12780, 12781, 12785, 12787)
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL,
    COUNT(DISTINCT tt.id) AS eligible_count,
    1 AS sort_order
FROM tournament_template tt
WHERE tt.del = 'no'
  AND tt.sportFK = 37
  AND tt.id NOT IN (12779, 12780, 12781, 12785, 12787)
  -- AND tt.id = <tournament_template_id>
  AND tt.name IS NOT NULL
  AND tt.name <> ''

ORDER BY sort_order, template_id;
