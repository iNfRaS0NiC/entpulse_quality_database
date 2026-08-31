SELECT
    -- CheckID - Speed-Skating-DQ-128
    -- Name - EVENT_TEAM_LINEUP_BELOW_DISCIPLINE_SIZE
    -- What it does: Flags a team event where a team was entered with fewer skaters than its own discipline is ever contested with.
    'Team_Lineup_Below_Discipline_Size' AS check_type,
    y.event_id,
    y.event_name,
    y.event_startdate,
    y.discipline_family,
    y.required_size,
    y.teams_below_size,
    y.team_names,
    y.template_name,
    y.tournament_name,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Counts the athletes named in each team's lineup and compares that
-- against the smallest field the discipline is ever skated with. A Team Pursuit and a Team Sprint
-- are three skaters on the ice, a distance relay is three, and the mixed relay as this sport
-- stores it is two. A team entered below its own discipline's size did not race that way; a
-- skater is missing from the record.
-- This is not GLOBAL-DQ-068 EVENT_TEAM_LINEUP_SIZE_UNEVEN, and the difference is the whole reason
-- the check exists. That one asks whether the teams in one event agree with each other, and in
-- this sport they routinely do not: three skaters race and a fourth is named as reserve, so 3 and
-- 4 sit side by side legitimately and the template reports 161 events of 556, almost all of them
-- correct. The four events below sit inside those 161 and cannot be picked out of them. This
-- check asks a different question - not whether the teams agree, but whether a team is too small
-- to have raced at all - and it answers it against the discipline rather than against the other
-- entries, so an event where every team is short is caught as readily as one where a single team
-- is.
-- The required sizes are measured rather than assumed, 2026-08-31, over the 4210 in-scope team
-- participations that reach a lineup: Team Pursuit runs at 3 and 4, Team Sprint at 3 and 4, the
-- 3000 and 5000 Metres Relays at 3, and the mixed relays at 2 with a single participation at 5.
-- The minimum of each observed range is the required size, so a named reserve never produces a
-- finding.
-- A team reaching no lineup at all is out of scope here and belongs to GLOBAL-DQ-058, which
-- reports 29 such events. Counting them again would say the same thing twice and would bury the
-- short lineups inside a larger number.
-- Measured 2026-08-31: 4 events of 556. Three Team Pursuits and one Team Sprint were entered with
-- two skaters where three race.
-- The audited object is the event. A short entry is one editorial fact about one race however
-- many of its teams are short; `teams_below_size` and `team_names` carry the detail as named
-- secondary columns.
FROM (
    SELECT
        z.event_id,
        z.event_name,
        z.event_startdate,
        z.template_name,
        z.tournament_name,
        z.discipline_family,
        z.required_size,
        COUNT(*) AS teams_below_size,
        SUBSTRING(GROUP_CONCAT(
            CONCAT(z.team_name, ' (', z.athlete_members, ' of ', z.required_size, ')')
            ORDER BY z.team_name SEPARATOR ' | '), 1, 200) AS team_names
    FROM (
        SELECT
            e.id AS event_id,
            e.name AS event_name,
            e.startdate AS event_startdate,
            tt.name AS template_name,
            t.name AS tournament_name,
            p.name AS team_name,
            CASE
                WHEN e.name LIKE 'Team Pursuit%' THEN 'Team Pursuit'
                WHEN e.name LIKE 'Team Sprint%' THEN 'Team Sprint'
                WHEN e.name REGEXP '^[0-9]+ (Metres|Meters) Relay' THEN 'Distance Relay'
                WHEN e.name LIKE '%Mixed%Relay%' OR e.name LIKE 'Relay Mixed%' THEN 'Mixed Relay'
            END AS discipline_family,
            CASE
                WHEN e.name LIKE 'Team Pursuit%' THEN 3
                WHEN e.name LIKE 'Team Sprint%' THEN 3
                WHEN e.name REGEXP '^[0-9]+ (Metres|Meters) Relay' THEN 3
                WHEN e.name LIKE '%Mixed%Relay%' OR e.name LIKE 'Relay Mixed%' THEN 2
            END AS required_size,
            COUNT(DISTINCT mp.id) AS athlete_members
        FROM event_participants ep
        JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
        JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
        JOIN lineup l ON l.event_participantsFK = ep.id AND l.del = 'no'
        JOIN participant mp ON mp.id = l.participantFK AND mp.del = 'no' AND mp.type = 'athlete'
        WHERE ep.del = 'no'
          AND tt.sportFK = 19
          AND p.type = 'team'
          AND t.tournament_templateFK NOT IN (25, 103, 104, 9625, 10081, 10754, 10861, 10867, 10870, 10871, 10883, 10884, 10885, 10887, 10894, 10895, 10896, 10910, 10911, 10912, 10947, 12329, 12330, 12331, 12332, 12335, 12336, 12339, 12340, 12341, 12731, 12732, 12733, 12734, 12735, 12736, 12737, 12738, 12739, 12740, 12741, 12742, 12743, 12744, 12745, 12746, 12747, 12748, 12749, 12750, 12751, 12752, 12753, 12754, 12755, 12756)
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
          -- AND t.tournament_templateFK = <tournament_template_id>
          -- AND e.startdate >= '<from_datetime>'
          -- AND e.startdate <  '<to_datetime>'
        GROUP BY ep.id, e.id, e.name, e.startdate, tt.name, t.name, p.name
    ) z
    WHERE z.discipline_family IS NOT NULL
      AND z.athlete_members < z.required_size
    GROUP BY z.event_id, z.event_name, z.event_startdate, z.template_name, z.tournament_name,
             z.discipline_family, z.required_size
) y

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event_participants ep
JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN lineup l ON l.event_participantsFK = ep.id AND l.del = 'no'
JOIN participant mp ON mp.id = l.participantFK AND mp.del = 'no' AND mp.type = 'athlete'
WHERE ep.del = 'no'
  AND tt.sportFK = 19
  AND p.type = 'team'
  AND (e.name LIKE 'Team Pursuit%'
    OR e.name LIKE 'Team Sprint%'
    OR e.name REGEXP '^[0-9]+ (Metres|Meters) Relay'
    OR e.name LIKE '%Mixed%Relay%'
    OR e.name LIKE 'Relay Mixed%')
  AND t.tournament_templateFK NOT IN (25, 103, 104, 9625, 10081, 10754, 10861, 10867, 10870, 10871, 10883, 10884, 10885, 10887, 10894, 10895, 10896, 10910, 10911, 10912, 10947, 12329, 12330, 12331, 12332, 12335, 12336, 12339, 12340, 12341, 12731, 12732, 12733, 12734, 12735, 12736, 12737, 12738, 12739, 12740, 12741, 12742, 12743, 12744, 12745, 12746, 12747, 12748, 12749, 12750, 12751, 12752, 12753, 12754, 12755, 12756)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_startdate DESC, event_id;
-- ==============================================================================

SELECT
    -- CheckID - Speed-Skating-DQ-129
    -- Name - EVENT_RESULTS_DURATION_TOO_FAST_FOR_DISTANCE
    -- What it does: Flags an individual distance holding an absolute time faster than the sport has ever skated that far.
    'Duration_Too_Fast_For_Distance' AS check_type,
    y.event_id,
    y.event_name,
    y.event_startdate,
    y.distance_m,
    y.offending_values,
    y.fastest_sec_per_km,
    y.template_name,
    y.tournament_name,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Reads the distance out of the event's own name, converts each
-- stored time to seconds, and asks whether the resulting pace is one a skater could hold. A time
-- that is too fast for its distance is not a slow entry or a disputed one; it is a value that
-- belongs to a different race.
-- The rule is a pace and not a table of per-distance floors, because a pace needs no maintenance
-- and no judgement about which record stands today. Measured 2026-08-31 over every in-scope
-- individual distance: the fastest pace this sport has ever recorded is 66.78 seconds per
-- kilometre, the 1500 Metres at 1:40.170, and every distance's own fastest sits above it - 500
-- Metres at 67.22, 10000 Metres at 74.57, 100 Metres at 93.50. The threshold is 60 seconds per
-- kilometre, ten per cent clear of the fastest thing ever skated, so a new world record at any
-- distance passes and only the impossible is reported.
-- Only absolute times are read. `101 Duration` holds an absolute time for the leader and a signed
-- gap for everyone behind, the convention DATABASE.md records for this sport, so a value carrying
-- a sign is left out rather than mistaken for a time. `557 Full-time duration` is always absolute.
-- The relays are excluded by matching the name exactly, `<distance> Metres` or `<distance>
-- Meters` and nothing after it. A 3000 Metres Relay is not a 3000 Metres: it is skated by a team
-- in turns and its pace is a different quantity, and reading the two together reported 39 relay
-- events as impossibly fast when none of them was.
-- The slow direction is deliberately not asked. A 500 Metres at 1:20 looks impossible and is not:
-- at the Olympics and the World Single Distances of that era the 500 was skated in two runs and
-- the classification is their sum, so event 71386 of 2006 holds a whole field between 1:16 and
-- 1:20 and every value of it is correct. A ceiling would have reported 35 such events as defects.
-- Measured 2026-08-31: 2 events of 3209, five values between them. Event 1612040, the World Cup
-- 1000 Metres at Salt Lake City on 2013-11-16, holds 16.460 for its leader, and because every
-- other skater's gap is written against that value the whole field carries gaps above 50 seconds
-- in a race of 67. Event 410847, the World Cup 1000 Metres at Erfurt on 2007-12-16, holds 37.88
-- for its leader, a 500 Metres time in a 1000 Metres race.
-- The audited object is the event. One wrong leader time corrupts the field around it, so the
-- event is what has to be repaired; `offending_values` and `fastest_sec_per_km` carry the detail
-- as named secondary columns.
FROM (
    SELECT
        x.event_id,
        x.event_name,
        x.event_startdate,
        x.template_name,
        x.tournament_name,
        x.distance_m,
        SUBSTRING(GROUP_CONCAT(
            CONCAT(x.participant_name, ' ', x.result_type_name, ' = ', x.raw_value)
            ORDER BY x.secs SEPARATOR ' | '), 1, 240) AS offending_values,
        ROUND(MIN(x.secs) / x.distance_m * 1000, 2) AS fastest_sec_per_km
    FROM (
        SELECT
            e.id AS event_id,
            e.name AS event_name,
            e.startdate AS event_startdate,
            tt.name AS template_name,
            t.name AS tournament_name,
            p.name AS participant_name,
            rt.name AS result_type_name,
            r.value AS raw_value,
            CAST(REGEXP_SUBSTR(e.name, '^[0-9]+') AS UNSIGNED) AS distance_m,
            CASE
                WHEN r.value LIKE '%:%'
                    THEN CAST(SUBSTRING_INDEX(r.value, ':', 1) AS DECIMAL(12,3)) * 60
                       + CAST(SUBSTRING_INDEX(r.value, ':', -1) AS DECIMAL(12,3))
                ELSE CAST(r.value AS DECIMAL(12,3))
            END AS secs
        FROM event e
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
        JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
        JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
        JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
                     AND r.result_typeFK IN (101, 557)
        LEFT JOIN result_type rt ON rt.id = r.result_typeFK
        WHERE e.del = 'no'
          AND tt.sportFK = 19
          AND e.status_type = 'finished'
          AND e.name REGEXP '^[0-9]+ (Metres|Meters)$'
          AND r.value REGEXP '^[0-9]+(:[0-9]+)?([.][0-9]+)?$'
          AND t.tournament_templateFK NOT IN (25, 103, 104, 9625, 10081, 10754, 10861, 10867, 10870, 10871, 10883, 10884, 10885, 10887, 10894, 10895, 10896, 10910, 10911, 10912, 10947, 12329, 12330, 12331, 12332, 12335, 12336, 12339, 12340, 12341, 12731, 12732, 12733, 12734, 12735, 12736, 12737, 12738, 12739, 12740, 12741, 12742, 12743, 12744, 12745, 12746, 12747, 12748, 12749, 12750, 12751, 12752, 12753, 12754, 12755, 12756)
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
          -- AND t.tournament_templateFK = <tournament_template_id>
          -- AND e.startdate >= '<from_datetime>'
          -- AND e.startdate <  '<to_datetime>'
    ) x
    WHERE x.distance_m > 0
      AND x.secs > 0
      AND x.secs / x.distance_m * 1000 < 60
    GROUP BY x.event_id, x.event_name, x.event_startdate, x.template_name, x.tournament_name,
             x.distance_m
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
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
             AND r.result_typeFK IN (101, 557)
WHERE e.del = 'no'
  AND tt.sportFK = 19
  AND e.status_type = 'finished'
  AND e.name REGEXP '^[0-9]+ (Metres|Meters)$'
  AND r.value REGEXP '^[0-9]+(:[0-9]+)?([.][0-9]+)?$'
  AND t.tournament_templateFK NOT IN (25, 103, 104, 9625, 10081, 10754, 10861, 10867, 10870, 10871, 10883, 10884, 10885, 10887, 10894, 10895, 10896, 10910, 10911, 10912, 10947, 12329, 12330, 12331, 12332, 12335, 12336, 12339, 12340, 12341, 12731, 12732, 12733, 12734, 12735, 12736, 12737, 12738, 12739, 12740, 12741, 12742, 12743, 12744, 12745, 12746, 12747, 12748, 12749, 12750, 12751, 12752, 12753, 12754, 12755, 12756)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_startdate DESC, event_id;
