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
-- The relay disciplines are deliberately out. There the result row belongs to a team rather than
-- a person, so the value may be a sum across four legs, and 24 misses on a team of four is
-- possible where 24 on one athlete is not. Naming a team ceiling would be asserting something
-- this project has not confirmed.
-- Measured 2026-08-27, 4 events of 2437 and 19 competitors. One 15 km Individual of the 2023
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
        CASE WHEN d.id = 253 THEN 10 ELSE 20 END AS shots_fired,
        SUM(CAST(ms.value AS SIGNED) > CASE WHEN d.id = 253 THEN 10 ELSE 20 END) AS competitors_over,
        MAX(CAST(ms.value AS SIGNED)) AS worst_missed,
        SUBSTRING(GROUP_CONCAT(DISTINCT CASE
            WHEN CAST(ms.value AS SIGNED) > CASE WHEN d.id = 253 THEN 10 ELSE 20 END
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
      AND od.disciplineFK IN (252, 253, 254, 256, 260)
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
  AND od.disciplineFK IN (252, 253, 254, 256, 260)
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
