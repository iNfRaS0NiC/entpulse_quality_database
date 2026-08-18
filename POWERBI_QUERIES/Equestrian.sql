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
-- GLOBAL-DQ-004 asserts something stronger and this sport does not store it. That template
-- requires the stage dates to equal the first and last event dates; Equestrian writes a stage as
-- whole days, from 00:00:00 to 23:59:59, so a stage containing every one of its events still
-- differs from their span by the hours at each end. Measured 2026-08-18 that is 3303 of the 3338
-- stages the template reports, and reading them says only that the sport rounds to the day.
-- What is left once the rounding is allowed for is 18 stages where an event genuinely falls
-- outside, and those are what this reports. The 17 stages that contain their events without
-- being written as whole days are not reported either: containment is the rule, not the format.
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
    -- CheckID - Equestrian-DQ-072
    -- Name - TEMPLATE_GENDER_NOT_REFLECTED_IN_ANY_STAGE
    -- What it does: Flags templates declaring a gender that none of their stages carries.
    'Template_Gender_Not_Reflected_In_Any_Stage' AS check_type,
    tt.id AS tournament_template_id,
    tt.name AS template_name,
    tt.gender AS template_gender,
    COUNT(DISTINCT ts.id) AS stage_count,
    MIN(ts.gender) AS sample_stage_gender,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds a template whose gender is a definite one - not mixed and
-- not empty - where no stage beneath it carries that gender.
-- It is the inverse of GLOBAL-DQ-014, which compares a stage against its template and ignores
-- mixed on either side. That template therefore cannot see a template declaring a gender its
-- own stages never carry, and in this sport that is where the disagreement sits: measured
-- 2026-08-18 every one of the 3386 stages is mixed, so the comparison has nothing to audit,
-- while one template of the 81 declares itself male and all 109 of its stages are mixed.
-- Which side is wrong is not asserted here. What is asserted is that the two disagree, which
-- is a thing somebody has to look at either way.
FROM tournament_template tt
JOIN tournament t
  ON t.tournament_templateFK = tt.id
 AND t.del = 'no'
JOIN tournament_stage ts
  ON ts.tournamentFK = t.id
 AND ts.del = 'no'
WHERE tt.del = 'no'
  AND tt.sportFK = 37
  AND tt.gender IS NOT NULL
  AND TRIM(tt.gender) <> ''
  AND LOWER(TRIM(tt.gender)) <> 'mixed'
  AND t.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND NOT EXISTS (
      SELECT 1
      FROM tournament_stage ts2
      JOIN tournament t2
        ON t2.id = ts2.tournamentFK
       AND t2.del = 'no'
      WHERE t2.tournament_templateFK = tt.id
        AND ts2.del = 'no'
        AND LOWER(TRIM(ts2.gender)) = LOWER(TRIM(tt.gender))
  )
GROUP BY
    tt.id,
    tt.name,
    tt.gender

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT tt.id) AS eligible_count,
    1 AS sort_order
FROM tournament_template tt
JOIN tournament t
  ON t.tournament_templateFK = tt.id
 AND t.del = 'no'
JOIN tournament_stage ts
  ON ts.tournamentFK = t.id
 AND ts.del = 'no'
WHERE tt.del = 'no'
  AND tt.sportFK = 37
  AND tt.gender IS NOT NULL
  AND TRIM(tt.gender) <> ''
  AND LOWER(TRIM(tt.gender)) <> 'mixed'
  AND t.tournament_templateFK NOT IN (12779, 12780, 12781, 12785, 12787)
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, tournament_template_id;
