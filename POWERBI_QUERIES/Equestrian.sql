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
-- agree on every single pair, and not once does one side carry a value the other lacks. Only
-- Team and Medal disagree at all, on 20 and 2 pairs.
-- A pair holding two riders or two horses is not audited here: that is a different defect and
-- Equestrian-DQ-060 and Equestrian-DQ-100 own it. Fields the pair does not use are skipped
-- rather than reported, so an unwritten field is never read as a contradiction.
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
