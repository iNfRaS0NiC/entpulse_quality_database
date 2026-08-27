SELECT
    -- CheckID - Biathlon-DQ-059
    -- Name - EVENT_RELAY_DISCIPLINE_CONTRADICTS_LINEUP_GENDER
    -- What it does: Flags a relay whose discipline says one thing about gender while its own lineup says another.
    CASE
        WHEN y.discipline_id IN (255, 258) THEN 'MIXED_RELAY_WITH_A_SINGLE_GENDER_LINEUP'
        ELSE 'SINGLE_GENDER_RELAY_WITH_A_MIXED_LINEUP'
    END AS check_type,
    y.event_id,
    y.event_name,
    y.startdate,
    y.discipline_name,
    y.lineup_genders,
    y.lineup_athletes,
    y.template_name,
    y.tournament_name,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Reads the athletes actually named in a relay's lineups and asks
-- whether the discipline the event is filed under could have fielded them. 255 Team Mixed Relay
-- and 258 Single Mixed Relay are mixed by definition and cannot be contested by one gender; 257
-- Relay and 259 Single Relay are single-gender and cannot hold both.
-- The lineup is the evidence and the discipline is the claim, which is what separates this from
-- Biathlon-DQ-060. That check reads the event name, and a name can be abbreviated or wrong
-- without anything else being; a lineup naming four men is a recorded fact about who raced.
-- Measured 2026-08-27, 19 events of 513: nine filed Team Mixed Relay with an all-male lineup and
-- nine with an all-female one, every one of them between 2005-03-11 and 2013-02-16, plus a single
-- 3 x 6 km Relay of 2023-03-07 filed as a plain Relay with men and women in it. The 362 plain
-- relays with a single-gender lineup and the 151 mixed relays with a mixed one are correct and
-- are the bulk of the sport.
-- Only 'male' and 'female' are read. A lineup row whose participant carries neither is left out
-- rather than counted as a third gender, so an unfilled gender cannot manufacture a finding.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate,
        d.id AS discipline_id,
        d.name AS discipline_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        GROUP_CONCAT(DISTINCT p.gender ORDER BY p.gender SEPARATOR ' + ') AS lineup_genders,
        COUNT(DISTINCT p.id) AS lineup_athletes
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
    JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    JOIN lineup lu ON lu.event_participantsFK = ep.id AND lu.del = 'no'
    JOIN participant p ON p.id = lu.participantFK AND p.del = 'no'
    WHERE e.del = 'no'
      AND tt.sportFK = 7
      AND t.tournament_templateFK NOT IN (465, 10241, 10820, 11242, 12457, 12458, 12461, 12462, 12477, 12478, 12566, 12567, 12568, 12569, 12570, 12571, 12572, 12573, 12574, 12575, 12576, 12577, 12578, 12579, 12580)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
      AND od.disciplineFK IN (255, 257, 258, 259)
      AND p.gender IN ('male', 'female')
    GROUP BY e.id, e.name, e.startdate, d.id, d.name, tt.name, t.name
    HAVING (d.id IN (255, 258) AND COUNT(DISTINCT p.gender) < 2)
        OR (d.id IN (257, 259) AND COUNT(DISTINCT p.gender) > 1)
) y

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
JOIN lineup lu ON lu.event_participantsFK = ep.id AND lu.del = 'no'
JOIN participant p ON p.id = lu.participantFK AND p.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = 7
  AND t.tournament_templateFK NOT IN (465, 10241, 10820, 11242, 12457, 12458, 12461, 12462, 12477, 12478, 12566, 12567, 12568, 12569, 12570, 12571, 12572, 12573, 12574, 12575, 12576, 12577, 12578, 12579, 12580)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND od.disciplineFK IN (255, 257, 258, 259)
  AND p.gender IN ('male', 'female')
;
-- ==============================================================================

SELECT
    -- CheckID - Biathlon-DQ-060
    -- Name - EVENT_NAME_NAMES_A_DIFFERENT_DISCIPLINE_THAN_THE_ONE_FILED
    -- What it does: Flags an event whose own name names one discipline while the event is filed under another.
    'Name_Discipline_Contradicts_Filed' AS check_type,
    y.event_id,
    y.event_name,
    y.startdate,
    y.filed_discipline,
    y.named_discipline,
    y.template_name,
    y.tournament_name,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Every biathlon event is named after the format it contests -
-- '10 km Sprint', '4 x 7.5 km Relay', '5 km Super Sprint Final' - so the name carries a claim
-- about the discipline that can be compared with the one on object_discipline. Where the two
-- disagree, one of them is wrong and the event cannot be read correctly through either.
-- The order of the branches matters and is the sport's own hierarchy: 'Single Mixed ... Relay'
-- is read before 'Mixed ... Relay', which is read before 'Single ... Relay', which is read
-- before a plain Relay, because the words are not adjacent in a name like
-- 'Single Mixed 2 x 6 + 2 x 7.5 km Relay' and a naive test files 59 correct events as wrong.
-- 'Super Sprint' is read before 'Sprint' for the same reason.
-- Measured 2026-08-27, 39 events of 2513. The largest families are 19 relays whose name says
-- what gender they were and whose discipline says Team Mixed Relay, 10 named Mixed Relay and
-- filed as a plain Relay, three Mass Start events filed as Pursuit and three Super Sprint
-- qualification heats filed as Sprint.
-- It is deliberately kept beside Biathlon-DQ-059 rather than folded into it. That check reads
-- the lineup and is the stronger evidence where a lineup exists; this one reaches the events
-- that have none and every non-relay discipline, where no lineup is ever written.
-- An event whose name names no discipline at all is outside the scope rather than a finding,
-- and the coverage count says so.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate,
        d.name AS filed_discipline,
        CASE
            WHEN e.name LIKE '%Relay%' AND e.name LIKE '%Single%' AND e.name LIKE '%Mixed%' THEN 'Single Mixed Relay'
            WHEN e.name LIKE '%Relay%' AND e.name LIKE '%Mixed%'                            THEN 'Team Mixed Relay'
            WHEN e.name LIKE '%Relay%' AND e.name LIKE '%Single%'                           THEN 'Single Relay'
            WHEN e.name LIKE '%Relay%'                                                      THEN 'Relay'
            WHEN e.name LIKE '%Super Sprint%'                                               THEN 'Super Sprint'
            WHEN e.name LIKE '%Mass Start%'                                                 THEN 'Mass Start'
            WHEN e.name LIKE '%Pursuit%'                                                    THEN 'Pursuit'
            WHEN e.name LIKE '%Individual%'                                                 THEN 'Individual'
            WHEN e.name LIKE '%Sprint%'                                                     THEN 'Sprint'
        END AS named_discipline,
        tt.name AS template_name,
        t.name AS tournament_name
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
    JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
    WHERE e.del = 'no'
      AND tt.sportFK = 7
      AND t.tournament_templateFK NOT IN (465, 10241, 10820, 11242, 12457, 12458, 12461, 12462, 12477, 12478, 12566, 12567, 12568, 12569, 12570, 12571, 12572, 12573, 12574, 12575, 12576, 12577, 12578, 12579, 12580)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
      AND (e.name LIKE '%Relay%' OR e.name LIKE '%Sprint%' OR e.name LIKE '%Mass Start%'
       OR e.name LIKE '%Pursuit%' OR e.name LIKE '%Individual%')
) y
WHERE y.named_discipline IS NOT NULL
  AND y.named_discipline <> y.filed_discipline

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
JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = 7
  AND t.tournament_templateFK NOT IN (465, 10241, 10820, 11242, 12457, 12458, 12461, 12462, 12477, 12478, 12566, 12567, 12568, 12569, 12570, 12571, 12572, 12573, 12574, 12575, 12576, 12577, 12578, 12579, 12580)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND (e.name LIKE '%Relay%' OR e.name LIKE '%Sprint%' OR e.name LIKE '%Mass Start%'
       OR e.name LIKE '%Pursuit%' OR e.name LIKE '%Individual%')
;
-- ==============================================================================

SELECT
    -- CheckID - Biathlon-DQ-061
    -- Name - EVENT_MISSED_SHOTS_ABOVE_WHAT_THE_DISCIPLINE_FIRES
    -- What it does: Flags an event in which a competitor missed more shots than the discipline gives them to fire.
    'Missed_Shots_Above_The_Discipline_Ceiling' AS check_type,
    y.event_id,
    y.event_name,
    y.startdate,
    y.discipline_name,
    y.shots_fired,
    y.competitors_over,
    y.worst_missed,
    y.sample_competitors,
    y.template_name,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: A biathlon format fixes how many rounds a competitor fires, so
-- the count of missed shots has a ceiling that is a fact about the discipline rather than about
-- the day. 252 Individual, 254 Pursuit, 256 Mass Start and 260 Super Sprint shoot four bouts of
-- five and cannot exceed 20; 253 Sprint shoots two and cannot exceed 10. A value above the
-- ceiling is not a bad day, it is a number that could not have been produced.
-- 260 Super Sprint fires two different numbers and the round type says which, established
-- 2026-08-27: its qualification shoots two bouts, prone then standing, and cannot exceed 10,
-- while its final shoots four, prone, prone, standing, standing, and cannot exceed 20. Until
-- that day the check gave the whole discipline the final's ceiling of 20 and so let a
-- qualification value of 11 to 20 pass unread. Tightening it changes no finding today - every
-- Super Sprint qualification in the sport tops out at 9 - and closes the gap for the day one
-- arrives.
-- The relay disciplines carry a ceiling of 40, added 2026-08-27 once what their figure counts
-- was established. Measured that day on a 4 x 7.5 km Relay of the 2020 World Championships,
-- Finland's team row holds 4 and the 273 missed_shots value at the final_result scope holds 4
-- as well, with the checkpoints running 2, 2, 2, 2, 2, 2, 4, 4, 4, 4, 4 - a running total that
-- never falls. So the team figure is the cumulative count at the finish rather than a per-leg
-- value or a sum of independent legs, and four legs of two bouts of five rounds is 40.
-- The ceiling is a fact about the format and is deliberately not computed from the lineup.
-- Lineup rows per team run 1, 2, 3, 4, 5 and 8 across the relay disciplines: the eights are
-- what GLOBAL-DQ-068 reports as an uneven lineup and the ones and twos are incomplete, so a
-- leg count read from storage would inherit those defects and move the ceiling with them.
-- 40 is generous on purpose. The highest relay value stored anywhere is 24 and the highest
-- inside the client boundary is 19, so the check returns nothing today and guards the
-- invariant for the day a figure arrives that no relay could have produced.
-- Measured 2026-08-27, 4 events and 19 competitors, every one of them individual. One 15 km Individual of the 2023
-- European Championships holds five competitors at 67, 70, 79, 86 and 88 misses against a
-- ceiling of 20, all of them placed 87th to 91st. One 5 km Super Sprint Final of 2020 holds ten
-- at 21 to 30. The remaining two are the other half of a different defect and are also reported
-- by Biathlon-DQ-060: an event named '15 km Individual' and one named '10 km Pursuit' are both
-- filed under Sprint, so their 11 to 13 misses are correct for the race that was actually run
-- and break only the ceiling of the discipline they were wrongly filed under.
-- Only a plainly numeric value is compared. A missed-shots row holding anything else is left to
-- the value-shape checks rather than read as a number here.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate,
        d.name AS discipline_name,
        tt.name AS template_name,
        CASE WHEN d.id = 253 THEN 10 WHEN d.id = 260 AND e.round_typeFK = 179 THEN 10 WHEN d.id IN (255, 257, 258, 259) THEN 40 ELSE 20 END AS shots_fired,
        SUM(CAST(ms.value AS SIGNED) > CASE WHEN d.id = 253 THEN 10 WHEN d.id = 260 AND e.round_typeFK = 179 THEN 10 WHEN d.id IN (255, 257, 258, 259) THEN 40 ELSE 20 END) AS competitors_over,
        MAX(CAST(ms.value AS SIGNED)) AS worst_missed,
        SUBSTRING(GROUP_CONCAT(DISTINCT CASE
            WHEN CAST(ms.value AS SIGNED) > CASE WHEN d.id = 253 THEN 10 WHEN d.id = 260 AND e.round_typeFK = 179 THEN 10 WHEN d.id IN (255, 257, 258, 259) THEN 40 ELSE 20 END
            THEN CONCAT(p.name, ' = ', ms.value) END
            ORDER BY ms.value DESC SEPARATOR ' | '), 1, 300) AS sample_competitors
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
    JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
    JOIN result ms ON ms.event_participantsFK = ep.id AND ms.result_typeFK = 502 AND ms.del = 'no'
    WHERE e.del = 'no'
      AND tt.sportFK = 7
      AND t.tournament_templateFK NOT IN (465, 10241, 10820, 11242, 12457, 12458, 12461, 12462, 12477, 12478, 12566, 12567, 12568, 12569, 12570, 12571, 12572, 12573, 12574, 12575, 12576, 12577, 12578, 12579, 12580)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
      AND od.disciplineFK IN (252, 253, 254, 255, 256, 257, 258, 259, 260)
      AND ms.value REGEXP '^[0-9]+$'
    GROUP BY e.id, e.name, e.startdate, d.id, d.name, tt.name
    HAVING competitors_over > 0
) y

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
JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
JOIN result ms ON ms.event_participantsFK = ep.id AND ms.result_typeFK = 502 AND ms.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = 7
  AND t.tournament_templateFK NOT IN (465, 10241, 10820, 11242, 12457, 12458, 12461, 12462, 12477, 12478, 12566, 12567, 12568, 12569, 12570, 12571, 12572, 12573, 12574, 12575, 12576, 12577, 12578, 12579, 12580)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND od.disciplineFK IN (252, 253, 254, 255, 256, 257, 258, 259, 260)
  AND ms.value REGEXP '^[0-9]+$'
;
-- ==============================================================================

SELECT
    -- CheckID - Biathlon-DQ-062
    -- Name - EVENT_TIMED_VALUE_SHARED_BY_THREE_OR_MORE_COMPETITORS
    -- What it does: Flags an event where one recorded time is carried by three or more competitors who were given different places.
    'Timed_Value_Shared_By_Three_Or_More' AS check_type,
    y.event_id,
    y.event_name,
    y.startdate,
    y.discipline_name,
    y.shared_groups,
    y.largest_group,
    y.shared_detail,
    y.template_name,
    y.tournament_name,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: This sport writes its times to a tenth of a second, so two
-- competitors sharing one value is an ordinary tie and eight sharing it is not a tie at all -
-- it is one value written into eight rows. The distinct places are what separate the two
-- readings: where the times agree and the places do not, either the ranking is wrong or the
-- time is a placeholder, and beyond two competitors the second is overwhelmingly the likelier.
-- The threshold is three and not two on purpose. Biathlon-DQ-054 already reads every shared
-- value at two, and reported 701 pairs of 708 groups on 2026-08-27; asking the same question at
-- two here would restate it. What this check adds is the shape that a pair can never show.
-- Measured the same day, 5 events of 2358. One 10 km Pursuit of the 2021 European Championships
-- holds eight competitors at 33:55.400 with a gap of +4:42.700, placed 46th to 53rd; the other
-- four hold three competitors each. Both 101 Duration and 557 Full-time duration are read,
-- because a placeholder written into one is usually written into both, and the event is reported
-- once however many of its fields carry it.
-- A competitor with no place is not in the scope: without a rank there is nothing for the shared
-- value to disagree with.
FROM (
    SELECT
        g.event_id,
        g.event_name,
        g.startdate,
        g.discipline_name,
        g.template_name,
        g.tournament_name,
        COUNT(*) AS shared_groups,
        MAX(g.competitors_sharing) AS largest_group,
        SUBSTRING(GROUP_CONCAT(CONCAT('type ', g.type_id, ' = ', g.shared_value, ' -> ',
            g.competitors_sharing, ' competitors at ', g.distinct_ranks, ' places')
            ORDER BY g.competitors_sharing DESC SEPARATOR ' | '), 1, 400) AS shared_detail
    FROM (
        SELECT
            e.id AS event_id,
            e.name AS event_name,
            e.startdate,
            d.name AS discipline_name,
            tt.name AS template_name,
            t.name AS tournament_name,
            r.result_typeFK AS type_id,
            r.value AS shared_value,
            COUNT(DISTINCT ep.id) AS competitors_sharing,
            COUNT(DISTINCT rk.value) AS distinct_ranks
        FROM event e
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
        JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
        JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
        JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
        JOIN result r ON r.event_participantsFK = ep.id AND r.result_typeFK IN (101, 557) AND r.del = 'no'
            AND r.value IS NOT NULL AND TRIM(r.value) <> ''
        JOIN result rk ON rk.event_participantsFK = ep.id AND rk.result_typeFK = 100 AND rk.del = 'no'
            AND rk.value IS NOT NULL AND TRIM(rk.value) <> ''
        WHERE e.del = 'no'
          AND tt.sportFK = 7
          AND t.tournament_templateFK NOT IN (465, 10241, 10820, 11242, 12457, 12458, 12461, 12462, 12477, 12478, 12566, 12567, 12568, 12569, 12570, 12571, 12572, 12573, 12574, 12575, 12576, 12577, 12578, 12579, 12580)
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
          -- AND t.tournament_templateFK = <tournament_template_id>
        GROUP BY e.id, e.name, e.startdate, d.name, tt.name, t.name, r.result_typeFK, r.value
        HAVING COUNT(DISTINCT ep.id) >= 3 AND COUNT(DISTINCT rk.value) >= 3
    ) g
    GROUP BY g.event_id, g.event_name, g.startdate, g.discipline_name, g.template_name, g.tournament_name
) y

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
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
JOIN result r ON r.event_participantsFK = ep.id AND r.result_typeFK IN (101, 557) AND r.del = 'no'
    AND r.value IS NOT NULL AND TRIM(r.value) <> ''
JOIN result rk ON rk.event_participantsFK = ep.id AND rk.result_typeFK = 100 AND rk.del = 'no'
    AND rk.value IS NOT NULL AND TRIM(rk.value) <> ''
WHERE e.del = 'no'
  AND tt.sportFK = 7
  AND t.tournament_templateFK NOT IN (465, 10241, 10820, 11242, 12457, 12458, 12461, 12462, 12477, 12478, 12566, 12567, 12568, 12569, 12570, 12571, 12572, 12573, 12574, 12575, 12576, 12577, 12578, 12579, 12580)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
;
-- ==============================================================================

SELECT
    -- CheckID - Biathlon-DQ-063
    -- Name - EVENT_SPARE_ROUNDS_IN_A_DISCIPLINE_THAT_FIRES_NONE
    -- What it does: Flags an event holding an Additional shots row in a discipline whose format gives nobody a spare round.
    'Spare_Rounds_In_A_Discipline_Without_Them' AS check_type,
    y.event_id,
    y.event_name,
    y.startdate,
    y.discipline_name,
    y.spare_rows_written,
    y.spare_values,
    y.template_name,
    y.tournament_name,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: A spare round is a relay rule. In 252 Individual, 253 Sprint,
-- 254 Pursuit and 256 Mass Start a competitor shoots what they are given and skis a penalty for
-- every miss, so 503 Additional shots is a field the format has no way to fill. A row there is
-- storage that does not correspond to anything that happened.
-- 260 Super Sprint is deliberately not in the list and the data is why. It carries spare rounds
-- on 18 of its 27 events with values up to 4, measured 2026-08-27, which is a format in use and
-- not a stray write. The four disciplines named here carry the field on 4 events between them
-- and every one of those rows holds 0 - the shape of an empty row created by an import rather
-- than a figure anybody recorded.
-- Measured 2026-08-27, 4 events of 1962: two Sprints and two Pursuits. spare_values carries what
-- the rows actually hold, because a zero and a real count are the same defect caught at two
-- different moments and are repaired differently.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate,
        d.name AS discipline_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        COUNT(*) AS spare_rows_written,
        SUBSTRING(GROUP_CONCAT(DISTINCT ash.value ORDER BY ash.value SEPARATOR ' | '), 1, 120) AS spare_values
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
    JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    JOIN result ash ON ash.event_participantsFK = ep.id AND ash.result_typeFK = 503 AND ash.del = 'no'
    WHERE e.del = 'no'
      AND tt.sportFK = 7
      AND t.tournament_templateFK NOT IN (465, 10241, 10820, 11242, 12457, 12458, 12461, 12462, 12477, 12478, 12566, 12567, 12568, 12569, 12570, 12571, 12572, 12573, 12574, 12575, 12576, 12577, 12578, 12579, 12580)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
      AND od.disciplineFK IN (252, 253, 254, 256)
    GROUP BY e.id, e.name, e.startdate, d.name, tt.name, t.name
) y

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = 7
  AND t.tournament_templateFK NOT IN (465, 10241, 10820, 11242, 12457, 12458, 12461, 12462, 12477, 12478, 12566, 12567, 12568, 12569, 12570, 12571, 12572, 12573, 12574, 12575, 12576, 12577, 12578, 12579, 12580)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND od.disciplineFK IN (252, 253, 254, 256)
;
-- ==============================================================================

SELECT
    -- CheckID - Biathlon-DQ-079
    -- Name - EVENT_RELAY_PENALTY_LOOP_WITHOUT_A_FULL_BOUT_OF_SPARES
    -- What it does: Flags a relay whose team was sent round the penalty loop without having fired a full bout of spare rounds first.
    'Penalty_Loop_Without_A_Full_Bout_Of_Spares' AS check_type,
    y.event_id,
    y.event_name,
    y.startdate,
    y.discipline_name,
    y.teams_affected,
    y.sample_teams,
    y.template_name,
    y.tournament_name,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: In a relay the two stored shooting figures are not independent.
-- 503 Additional shots counts the spare rounds a team used and 502 Missed shots counts the
-- penalty loops it was sent round, and the rule that ties them is that a loop is given only for
-- a target still standing after all three spares of that bout have been fired. So a team with at
-- least one penalty loop must have used at least three spare rounds, and a row holding a loop
-- beside fewer than three spares records something that could not have happened on the course.
-- Only the floor of three is asserted, not the exact arithmetic. A team's figures are cumulative
-- totals at the finish across eight bouts, so the count of bouts that produced a loop cannot be
-- recovered from them and a stronger claim would be a guess.
-- 260 Super Sprint is deliberately outside the scope. It fires spare rounds too, but 444 of its
-- rows break this rule, which says its formats settle a standing target some other way rather
-- than that its data is wrong. Only 255 Team Mixed Relay, 257 Relay, 258 Single Mixed Relay and
-- 259 Single Relay are read.
-- Measured 2026-08-27, 9 team rows across 7 events of 526. Three are teams that finished and
-- were placed: a 3 x 6 km Relay of 2018 where Finland took second with 2 loops and no spares,
-- and a Mixed Relay of 2022 where Sweden holds 1 loop with 1 spare and Austria 2 loops with
-- none. The other six carry DNF, LAP or LPD, where the shooting figures are as suspect as the
-- placing, and are reported for the same reason rather than a different one.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate,
        d.name AS discipline_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        COUNT(*) AS teams_affected,
        SUBSTRING(GROUP_CONCAT(CONCAT(x.team, ' = ', x.loops, ' loop(s), ', x.spares, ' spare(s)')
            ORDER BY x.loops DESC SEPARATOR ' | '), 1, 300) AS sample_teams
    FROM (
        SELECT
            ep.id AS epid,
            e2.id AS eid,
            p.name AS team,
            MAX(CASE WHEN r.result_typeFK = 502 THEN CAST(r.value AS SIGNED) END) AS loops,
            MAX(CASE WHEN r.result_typeFK = 503 THEN CAST(r.value AS SIGNED) END) AS spares
        FROM event e2
        JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
        JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
        JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
        JOIN object_discipline od2 ON od2.object_typeFK = 5 AND od2.objectFK = e2.id AND od2.del = 'no'
        JOIN event_participants ep ON ep.eventFK = e2.id AND ep.del = 'no'
        JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
        JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
            AND r.result_typeFK IN (502, 503) AND r.value REGEXP '^[0-9]+$'
        WHERE e2.del = 'no'
          AND tt2.sportFK = 7
          AND t2.tournament_templateFK NOT IN (465, 10241, 10820, 11242, 12457, 12458, 12461, 12462, 12477, 12478, 12566, 12567, 12568, 12569, 12570, 12571, 12572, 12573, 12574, 12575, 12576, 12577, 12578, 12579, 12580)
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
          -- AND t2.tournament_templateFK = <tournament_template_id>
          AND od2.disciplineFK IN (255, 257, 258, 259)
        GROUP BY ep.id, e2.id, p.name
        HAVING loops > 0 AND spares < 3
    ) x
    JOIN event e ON e.id = x.eid AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
    JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
    WHERE tt.sportFK = 7
      AND t.tournament_templateFK NOT IN (465, 10241, 10820, 11242, 12457, 12458, 12461, 12462, 12477, 12478, 12566, 12567, 12568, 12569, 12570, 12571, 12572, 12573, 12574, 12575, 12576, 12577, 12578, 12579, 12580)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
      AND od.disciplineFK IN (255, 257, 258, 259)
    GROUP BY e.id, e.name, e.startdate, d.name, tt.name, t.name
) y

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
    AND r.result_typeFK IN (502, 503) AND r.value REGEXP '^[0-9]+$'
WHERE e.del = 'no'
  AND tt.sportFK = 7
  AND t.tournament_templateFK NOT IN (465, 10241, 10820, 11242, 12457, 12458, 12461, 12462, 12477, 12478, 12566, 12567, 12568, 12569, 12570, 12571, 12572, 12573, 12574, 12575, 12576, 12577, 12578, 12579, 12580)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND od.disciplineFK IN (255, 257, 258, 259)
;
-- ==============================================================================

SELECT
    -- CheckID - Biathlon-DQ-080
    -- Name - EVENT_MISSED_SHOTS_HOLD_A_DIFFERENT_VALUE_FOR_EVERY_COMPETITOR
    -- What it does: Flags an event whose Missed shots column gives every competitor a different number, which shooting cannot produce.
    'Missed_Shots_Different_For_Every_Competitor' AS check_type,
    y.event_id,
    y.event_name,
    y.startdate,
    y.discipline_name,
    y.competitors,
    y.distinct_values,
    y.lowest_value,
    y.highest_value,
    y.template_name,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: A missed-shots count is drawn from a small set. The most a
-- competitor can fire is twenty rounds, so at most twenty-one different values exist however
-- large the field, and in a field of thirty the values must repeat many times over. An event in
-- which every competitor holds a different number is therefore not reporting shooting: some
-- other column has been written into this one, and the check says so without having to know
-- which column it was or how many rounds the discipline fires.
-- The audited object is the event, because the defect is a property of the whole column rather
-- than of any one competitor. A field of fewer than fifteen is left out: with twenty-one values
-- available a small field can hold all-different counts by chance, and there the shape carries
-- no information.
-- It is deliberately not stated as a ceiling. Biathlon-DQ-061 already asks whether a value
-- exceeds what the discipline fires and catches only the part of such a column that happens to
-- run high; this one reads the shape of the column and catches the whole event.
-- Measured 2026-08-27, 1 event of 2358. A 5 km Super Sprint Final of 2020-02-26 holds thirty
-- competitors whose Missed shots values are exactly the numbers 1 to 30, each once. Every other
-- Super Sprint in the sport tops out at 9. Biathlon-DQ-061 reports eleven of that event's rows,
-- the ones above the ceiling of 20; the other nineteen are just as wrong and only this check
-- sees them.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate,
        d.name AS discipline_name,
        tt.name AS template_name,
        COUNT(*) AS competitors,
        COUNT(DISTINCT CAST(ms.value AS SIGNED)) AS distinct_values,
        MIN(CAST(ms.value AS SIGNED)) AS lowest_value,
        MAX(CAST(ms.value AS SIGNED)) AS highest_value
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
    JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    JOIN result ms ON ms.event_participantsFK = ep.id AND ms.result_typeFK = 502 AND ms.del = 'no'
    WHERE e.del = 'no'
      AND tt.sportFK = 7
      AND t.tournament_templateFK NOT IN (465, 10241, 10820, 11242, 12457, 12458, 12461, 12462, 12477, 12478, 12566, 12567, 12568, 12569, 12570, 12571, 12572, 12573, 12574, 12575, 12576, 12577, 12578, 12579, 12580)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
      AND ms.value REGEXP '^[0-9]+$'
    GROUP BY e.id, e.name, e.startdate, d.name, tt.name
    HAVING competitors >= 15 AND distinct_values = competitors
) y

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
JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
JOIN result ms ON ms.event_participantsFK = ep.id AND ms.result_typeFK = 502 AND ms.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = 7
  AND t.tournament_templateFK NOT IN (465, 10241, 10820, 11242, 12457, 12458, 12461, 12462, 12477, 12478, 12566, 12567, 12568, 12569, 12570, 12571, 12572, 12573, 12574, 12575, 12576, 12577, 12578, 12579, 12580)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND ms.value REGEXP '^[0-9]+$'
;
-- ==============================================================================

SELECT
    -- CheckID - Biathlon-DQ-081
    -- Name - EVENT_START_NUMBER_HELD_BY_MORE_THAN_ONE_COMPETITOR
    -- What it does: Flags an event in which one start number is carried by two or more competitors.
    'Start_Number_Held_By_More_Than_One' AS check_type,
    y.event_id,
    y.event_name,
    y.startdate,
    y.discipline_name,
    y.numbers_shared,
    y.competitors_involved,
    y.sample_numbers,
    y.template_name,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: A start number is the bib a competitor wears, and in a biathlon
-- race it is handed out once. Two entries carrying the same number is not a close call about
-- what the number means; it is the one thing a number identifying an entry cannot do.
-- This reads the 408 Startnumber result, which is a different column from the one
-- GLOBAL-DQ-137 audits. That check reads event_participants.number and finds nothing here.
-- The rule is stated only as the duplicate, deliberately. Looking at the rows shows the usual
-- cause is the Rank having been written into this column for part of the field - in a 7.5 km
-- Sprint of the 2024 European Championships, Linda Zingerle holds start number 10 with rank 10
-- and Marlene Fichtner 11 with rank 11, while Elena Chirkova holds the real bib 10 with rank 66
-- - but 'the start number equals the rank' is not a defect on its own, since a bib and a place
-- coincide legitimately all the time. The duplicate is what can be asserted, and it is what
-- found these.
-- Measured 2026-08-27, 34 events of 1885, 100 shared numbers and 200 competitors. Two events
-- carry the defect wholesale: a 12.5 km Individual at the 2019 European Junior Championships
-- with 27 shared numbers in a field of 107, and the Sprint above with 23 in a field of 119. The
-- other 32 hold one or two each. No relay is among them; a relay's number belongs to the team.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate,
        d.name AS discipline_name,
        tt.name AS template_name,
        COUNT(*) AS numbers_shared,
        SUM(x.holders) AS competitors_involved,
        SUBSTRING(GROUP_CONCAT(CONCAT(x.startno, ' x', x.holders)
            ORDER BY CAST(x.startno AS UNSIGNED) SEPARATOR ' | '), 1, 300) AS sample_numbers
    FROM (
        SELECT
            e2.id AS eid,
            r.value AS startno,
            COUNT(DISTINCT ep.id) AS holders
        FROM event e2
        JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
        JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
        JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
        JOIN event_participants ep ON ep.eventFK = e2.id AND ep.del = 'no'
        JOIN result r ON r.event_participantsFK = ep.id AND r.result_typeFK = 408 AND r.del = 'no'
        WHERE e2.del = 'no'
          AND tt2.sportFK = 7
          AND t2.tournament_templateFK NOT IN (465, 10241, 10820, 11242, 12457, 12458, 12461, 12462, 12477, 12478, 12566, 12567, 12568, 12569, 12570, 12571, 12572, 12573, 12574, 12575, 12576, 12577, 12578, 12579, 12580)
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
          -- AND t2.tournament_templateFK = <tournament_template_id>
          AND r.value <> ''
        GROUP BY e2.id, r.value
        HAVING holders > 1
    ) x
    JOIN event e ON e.id = x.eid AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
    JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
    WHERE tt.sportFK = 7
      AND t.tournament_templateFK NOT IN (465, 10241, 10820, 11242, 12457, 12458, 12461, 12462, 12477, 12478, 12566, 12567, 12568, 12569, 12570, 12571, 12572, 12573, 12574, 12575, 12576, 12577, 12578, 12579, 12580)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
    GROUP BY e.id, e.name, e.startdate, d.name, tt.name
) y

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
JOIN result r ON r.event_participantsFK = ep.id AND r.result_typeFK = 408 AND r.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = 7
  AND t.tournament_templateFK NOT IN (465, 10241, 10820, 11242, 12457, 12458, 12461, 12462, 12477, 12478, 12566, 12567, 12568, 12569, 12570, 12571, 12572, 12573, 12574, 12575, 12576, 12577, 12578, 12579, 12580)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND r.value <> ''
;
-- ==============================================================================

SELECT
    -- CheckID - Biathlon-DQ-082
    -- Name - EVENT_DURATION_HOLDS_A_GAP_WHERE_A_TIME_BELONGS_OR_THE_REVERSE
    -- What it does: Flags a competitor whose Duration breaks the leader-and-gap convention, holding a gap while leading or a plain time while not.
    CASE
        WHEN y.rank_value = '1' THEN 'LEADER_HOLDS_A_GAP_INSTEAD_OF_A_TIME'
        ELSE 'A_PLACED_COMPETITOR_HOLDS_A_TIME_INSTEAD_OF_A_GAP'
    END AS check_type,
    y.event_id,
    y.event_name,
    y.startdate,
    y.discipline_name,
    y.competitor,
    y.rank_value,
    y.duration_value,
    y.full_time_value,
    y.template_name,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: This sport writes its two time columns to a fixed convention.
-- 557 Full-time duration is the absolute time for everybody, and 101 Duration is the absolute
-- time for the competitor placed first and the gap behind that leader, written with a leading
-- plus, for everybody else. The convention is what makes the two columns mean different things,
-- and a row that breaks it is a value read as the wrong quantity by anything downstream.
-- It is not a restatement of Biathlon-DQ-040. GLOBAL-DQ-056 checks the arithmetic - leader's
-- time plus this competitor's gap against their own full time - and to do that it has to be able
-- to read the leader's time, so an event whose leader holds a gap is exactly the event that
-- check cannot audit. This one asks the prior question of which column holds which kind of value
-- and needs no arithmetic to answer it.
-- Measured 2026-08-27, 5 competitors of 2358 events. Three are leaders holding '+0.0': a 10 km
-- Sprint of 2009, one of 2014 and a 2019 summer Sprint whose full time is 0.000 as well. Two are
-- placed second and hold a plain value where a gap belongs: a Mass Start of 2015 where Quentin
-- Fillon Maillet holds 0.000 against a full time of 42.000, and a Pursuit of 2026 where Eric
-- Perrot holds -31.000 against a full time of 0.000. Those two rows are broken in more ways than
-- this and are reported by the full-time checks as well; the convention is what this one names.
-- A competitor with no Duration row at all is outside the scope rather than a finding, and an
-- empty value is left to Biathlon-DQ-044.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate,
        d.name AS discipline_name,
        tt.name AS template_name,
        p.name AS competitor,
        MAX(CASE WHEN r.result_typeFK = 100 THEN r.value END) AS rank_value,
        MAX(CASE WHEN r.result_typeFK = 101 THEN r.value END) AS duration_value,
        MAX(CASE WHEN r.result_typeFK = 557 THEN r.value END) AS full_time_value
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
    JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
    JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
        AND r.result_typeFK IN (100, 101, 557)
    WHERE e.del = 'no'
      AND tt.sportFK = 7
      AND t.tournament_templateFK NOT IN (465, 10241, 10820, 11242, 12457, 12458, 12461, 12462, 12477, 12478, 12566, 12567, 12568, 12569, 12570, 12571, 12572, 12573, 12574, 12575, 12576, 12577, 12578, 12579, 12580)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
    GROUP BY e.id, e.name, e.startdate, d.name, tt.name, p.name, ep.id
    HAVING (rank_value = '1' AND duration_value LIKE '+%')
        OR (rank_value REGEXP '^[2-9][0-9]*$' AND duration_value IS NOT NULL
            AND duration_value <> '' AND duration_value NOT LIKE '+%')
) y

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
JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
    AND r.result_typeFK IN (100, 101, 557)
WHERE e.del = 'no'
  AND tt.sportFK = 7
  AND t.tournament_templateFK NOT IN (465, 10241, 10820, 11242, 12457, 12458, 12461, 12462, 12477, 12478, 12566, 12567, 12568, 12569, 12570, 12571, 12572, 12573, 12574, 12575, 12576, 12577, 12578, 12579, 12580)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
;
-- ==============================================================================

SELECT
    -- CheckID - Biathlon-DQ-083
    -- Name - EVENT_RESULTS_DID_NOT_START_BUT_FIRED_SHOTS
    -- What it does: Flags a competitor recorded as not having started who nevertheless holds a shooting figure above zero.
    'Did_Not_Start_But_Fired_Shots' AS check_type,
    y.event_id,
    y.event_name,
    y.startdate,
    y.discipline_name,
    y.competitor,
    y.comment_value,
    y.missed_shots,
    y.spare_rounds,
    y.template_name,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: A competitor whose Comment says DNS never reached the range, so
-- every shooting figure they carry has to be absent or zero. A count above zero says they fired,
-- and the two statements cannot both be true of the same entry.
-- Only a figure above zero is read, and that is the whole of the design. Measured 2026-08-27,
-- 2824 competitor rows across 1059 events hold a DNS beside a shooting figure, and 2823 of them
-- hold zero: that is the feed writing a default into a column it has nothing to put in, not a
-- claim that anybody shot. Reporting those would bury the one row that means something under
-- three orders of magnitude of noise, and would be the same reading GLOBAL-DQ-052 already gives
-- of a no-result comment stored beside a Rank, a time or a Medal.
-- Measured the same day, 1 competitor of 2358 events: Jacob Weel Rosbo, a 10 km Sprint of
-- 2024-08-24, carries DNS with 6 missed shots and no time and no place.
-- Only 'dns' is read, not the wider no-result list. A DNF fired at every range they reached
-- before stopping, so their shooting figure is expected rather than contradictory.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate,
        d.name AS discipline_name,
        tt.name AS template_name,
        p.name AS competitor,
        MAX(CASE WHEN r.result_typeFK = 104 THEN r.value END) AS comment_value,
        MAX(CASE WHEN r.result_typeFK = 502 THEN r.value END) AS missed_shots,
        MAX(CASE WHEN r.result_typeFK = 503 THEN r.value END) AS spare_rounds
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
    JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
    JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
        AND r.result_typeFK IN (104, 502, 503)
    WHERE e.del = 'no'
      AND tt.sportFK = 7
      AND t.tournament_templateFK NOT IN (465, 10241, 10820, 11242, 12457, 12458, 12461, 12462, 12477, 12478, 12566, 12567, 12568, 12569, 12570, 12571, 12572, 12573, 12574, 12575, 12576, 12577, 12578, 12579, 12580)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
    GROUP BY e.id, e.name, e.startdate, d.name, tt.name, p.name, ep.id
    HAVING LOWER(TRIM(comment_value)) = 'dns'
       AND (CAST(missed_shots AS SIGNED) > 0 OR CAST(spare_rounds AS SIGNED) > 0)
) y

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
JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
    AND r.result_typeFK IN (104, 502, 503)
WHERE e.del = 'no'
  AND tt.sportFK = 7
  AND t.tournament_templateFK NOT IN (465, 10241, 10820, 11242, 12457, 12458, 12461, 12462, 12477, 12478, 12566, 12567, 12568, 12569, 12570, 12571, 12572, 12573, 12574, 12575, 12576, 12577, 12578, 12579, 12580)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
;
