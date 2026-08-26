SELECT
    -- CheckID - Track-Cycling-DQ-074
    -- Name - EVENT_RESULTS_POINTS_RUN_BOTH_DIRECTIONS_AGAINST_RANK
    -- What it does: Flags an event awarding Points by finishing position whose Points run in both directions against the Rank at once.
    'Points_Run_Both_Directions_Against_Rank' AS check_type,
    x.event_id,
    x.event_name,
    x.startdate,
    x.discipline_name,
    x.template_name,
    x.tournament_name,
    x.pairs_better_rank_more_points,
    x.pairs_better_rank_fewer_points,
    x.paired_participants,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds an event in which one competitor is ranked ahead of
-- another while holding more Points, and a second pair in the same event is ranked ahead
-- while holding fewer. One event cannot be scored both ways, so whichever direction that
-- event was decided by, some of its rows disagree with it.
-- The direction itself is deliberately not asserted, and this sport is why. The Omnium
-- reversed its scoring in 2014: through 2013 the classification was a sum of finishing
-- places and the lowest total won - Sarah Hammer took the 2014 world title on 14 - and from
-- 2015 it is accumulated points and the highest wins. Measured 2026-08-26 that is 43 events
-- under Omnium - Overall scored the old way and 96 the new, with 2014 itself holding both.
-- A check asserting either direction would report one era or the other in full. Asking only
-- that a single event agree with itself reads both eras correctly and reports neither.
-- Scoped to the eleven disciplines in which this sport awards Points by finishing position:
-- the points races, the tempo and elimination races, the Omnium and every one of its
-- components, and Omnium - Overall. Madison, 20Km Madison and 6-days are deliberately out.
-- They are classified on laps first and points second, so a pair holding fewer points on a
-- better lap is correctly ranked ahead, and Track-Cycling-DQ-075 is what reads them. The
-- sprint, keirin, scratch and elimination disciplines are out for the other reason: their
-- placing does not come from a stored value at all, and what Points means on the events of
-- theirs that carry it is not established. Measured 2026-08-26, admitting them all on the
-- structural test - every event holding Points and Rank and no laps - raised this from 49
-- events to 178, of which 64 were Madison and 56 were disciplines Points does not decide.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate,
        d.name AS discipline_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        COUNT(DISTINCT ep1.id) AS paired_participants,
        SUM(CASE WHEN CAST(rk1.value AS UNSIGNED) < CAST(rk2.value AS UNSIGNED)
                  AND CAST(pt1.value AS DECIMAL(12,3)) > CAST(pt2.value AS DECIMAL(12,3))
                 THEN 1 ELSE 0 END) AS pairs_better_rank_more_points,
        SUM(CASE WHEN CAST(rk1.value AS UNSIGNED) < CAST(rk2.value AS UNSIGNED)
                  AND CAST(pt1.value AS DECIMAL(12,3)) < CAST(pt2.value AS DECIMAL(12,3))
                 THEN 1 ELSE 0 END) AS pairs_better_rank_fewer_points
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
    JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
    JOIN event_participants ep1 ON ep1.eventFK = e.id AND ep1.del = 'no'
    JOIN result rk1 ON rk1.event_participantsFK = ep1.id AND rk1.result_typeFK = 100 AND rk1.del = 'no'
    JOIN result pt1 ON pt1.event_participantsFK = ep1.id AND pt1.result_typeFK = 102 AND pt1.del = 'no'
    JOIN event_participants ep2 ON ep2.eventFK = e.id AND ep2.del = 'no' AND ep2.id <> ep1.id
    JOIN result rk2 ON rk2.event_participantsFK = ep2.id AND rk2.result_typeFK = 100 AND rk2.del = 'no'
    JOIN result pt2 ON pt2.event_participantsFK = ep2.id AND pt2.result_typeFK = 102 AND pt2.del = 'no'
WHERE e.del = 'no'
      AND tt.sportFK = 55
      AND t.tournament_templateFK NOT IN (12793, 12794, 12795, 12796)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
      AND od.disciplineFK IN (378, 381, 382, 383, 384, 385, 386, 387, 388, 396, 397)
      AND rk1.value REGEXP '^[0-9]+$'
      AND rk2.value REGEXP '^[0-9]+$'
      AND pt1.value REGEXP '^-?[0-9]+([.][0-9]+)?$'
      AND pt2.value REGEXP '^-?[0-9]+([.][0-9]+)?$'
    GROUP BY e.id, e.name, e.startdate, d.name, tt.name, t.name
    HAVING pairs_better_rank_more_points > 0
       AND pairs_better_rank_fewer_points > 0
) x

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
JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
WHERE e.del = 'no'
AND tt.sportFK = 55
AND t.tournament_templateFK NOT IN (12793, 12794, 12795, 12796)
AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
-- AND t.tournament_templateFK = <tournament_template_id>
  AND od.disciplineFK IN (378, 381, 382, 383, 384, 385, 386, 387, 388, 396, 397)
  AND EXISTS (
      SELECT 1
      FROM event_participants ep
      JOIN result rk ON rk.event_participantsFK = ep.id AND rk.result_typeFK = 100 AND rk.del = 'no'
      JOIN result pt ON pt.event_participantsFK = ep.id AND pt.result_typeFK = 102 AND pt.del = 'no'
      WHERE ep.eventFK = e.id AND ep.del = 'no'
        AND rk.value REGEXP '^[0-9]+$'
        AND pt.value REGEXP '^-?[0-9]+([.][0-9]+)?$'
  );

-- ==============================================================================

SELECT
    -- CheckID - Track-Cycling-DQ-075
    -- Name - EVENT_RESULTS_LAPS_BEHIND_CONTRADICT_RANK
    -- What it does: Flags an event whose Laps behind, or whose Points inside one lap, disagree with the order the competitors are ranked in.
    CASE
        WHEN x.pairs_better_rank_more_laps > 0
             THEN 'LAPS_BEHIND_CONTRADICT_RANK'
        ELSE 'POINTS_CONTRADICT_RANK_WITHIN_THE_SAME_LAP'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.startdate,
    x.discipline_name,
    x.template_name,
    x.tournament_name,
    x.pairs_better_rank_more_laps,
    x.pairs_better_rank_fewer_points_same_lap,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds an event whose stored classification disagrees with
-- its own Rank, in a discipline decided on laps first and points second - the Madison, the
-- 20Km Madison, the six-day and the mass-start races that record a lapped rider. A pair
-- lapped more times than another cannot be ranked ahead of it, and two pairs on the same lap
-- cannot be ordered against their points.
-- Laps are read as a magnitude and not as a signed number, deliberately. This sport writes
-- one lap down as -1 in some disciplines and as 1 in others: measured 2026-08-26, Scratch
-- holds 69 events negative against 26 positive, Omnium - Scratch race 53 against 7, Madison
-- 19 against 39, and the six-day is positive throughout. No event mixes the two inside
-- itself, so the magnitude is the same quantity under either convention and reading it that
-- way costs nothing. Read as signed instead, the same test returned 39 events of which 37
-- were the convention rather than the order. Which sign the sport should settle on is
-- recorded in SPORTS/Track-Cycling.md and is not what this check asks.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate,
        d.name AS discipline_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        SUM(CASE WHEN CAST(rk1.value AS UNSIGNED) < CAST(rk2.value AS UNSIGNED)
                  AND ABS(CAST(lp1.value AS SIGNED)) > ABS(CAST(lp2.value AS SIGNED))
                 THEN 1 ELSE 0 END) AS pairs_better_rank_more_laps,
        SUM(CASE WHEN CAST(rk1.value AS UNSIGNED) < CAST(rk2.value AS UNSIGNED)
                  AND ABS(CAST(lp1.value AS SIGNED)) = ABS(CAST(lp2.value AS SIGNED))
                  AND CAST(pt1.value AS DECIMAL(12,3)) < CAST(pt2.value AS DECIMAL(12,3))
                 THEN 1 ELSE 0 END) AS pairs_better_rank_fewer_points_same_lap
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
    JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
    JOIN event_participants ep1 ON ep1.eventFK = e.id AND ep1.del = 'no'
    JOIN result rk1 ON rk1.event_participantsFK = ep1.id AND rk1.result_typeFK = 100 AND rk1.del = 'no'
    JOIN result lp1 ON lp1.event_participantsFK = ep1.id AND lp1.result_typeFK = 222 AND lp1.del = 'no'
    LEFT JOIN result pt1 ON pt1.event_participantsFK = ep1.id AND pt1.result_typeFK = 102 AND pt1.del = 'no'
    JOIN event_participants ep2 ON ep2.eventFK = e.id AND ep2.del = 'no' AND ep2.id <> ep1.id
    JOIN result rk2 ON rk2.event_participantsFK = ep2.id AND rk2.result_typeFK = 100 AND rk2.del = 'no'
    JOIN result lp2 ON lp2.event_participantsFK = ep2.id AND lp2.result_typeFK = 222 AND lp2.del = 'no'
    LEFT JOIN result pt2 ON pt2.event_participantsFK = ep2.id AND pt2.result_typeFK = 102 AND pt2.del = 'no'
WHERE e.del = 'no'
      AND tt.sportFK = 55
      AND t.tournament_templateFK NOT IN (12793, 12794, 12795, 12796)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
      AND rk1.value REGEXP '^[0-9]+$'
      AND rk2.value REGEXP '^[0-9]+$'
      AND lp1.value REGEXP '^-?[0-9]+$'
      AND lp2.value REGEXP '^-?[0-9]+$'
    GROUP BY e.id, e.name, e.startdate, d.name, tt.name, t.name
    HAVING pairs_better_rank_more_laps > 0
        OR pairs_better_rank_fewer_points_same_lap > 0
) x

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
JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
WHERE e.del = 'no'
AND tt.sportFK = 55
AND t.tournament_templateFK NOT IN (12793, 12794, 12795, 12796)
AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
-- AND t.tournament_templateFK = <tournament_template_id>
  AND EXISTS (
      SELECT 1
      FROM event_participants ep
      JOIN result rk ON rk.event_participantsFK = ep.id AND rk.result_typeFK = 100 AND rk.del = 'no'
      JOIN result lp ON lp.event_participantsFK = ep.id AND lp.result_typeFK = 222 AND lp.del = 'no'
      WHERE ep.eventFK = e.id AND ep.del = 'no'
        AND rk.value REGEXP '^[0-9]+$'
        AND lp.value REGEXP '^-?[0-9]+$'
  );

-- ==============================================================================

SELECT
    -- CheckID - Track-Cycling-DQ-076
    -- Name - EVENT_DURATION_GAP_WITHOUT_AN_ABSOLUTE_TIME
    -- What it does: Flags a timed event whose Duration values are all gaps to a leader, with no absolute time anywhere to measure them from.
    'Duration_Gap_Without_An_Absolute_Time' AS check_type,
    x.event_id,
    x.event_name,
    x.startdate,
    x.discipline_name,
    x.template_name,
    x.tournament_name,
    x.gap_values,
    x.sample_values,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds an event in a discipline decided on the clock where
-- every stored Duration carries a leading plus and none is a plain time. The sport writes
-- the winner's elapsed time and everybody else's gap to it into one field, so a field of
-- gaps with no absolute time is a set of numbers measured from nothing: not one rider on
-- that card has a time that can be recovered.
-- Track-Cycling-DQ-053 cannot see this. GLOBAL-DQ-019 tests the shape of a Duration value
-- against the rank that holds it and reaches a competitor only through the Duration row
-- itself, so a rank 1 carrying no Duration at all is not a row it joins. That is exactly the
-- shape here.
-- Scoped to the fourteen disciplines TIMED_DISCIPLINE_LIST names, and the sprint and the
-- keirin are the reason the scope exists. Measured 2026-08-26 the sport holds 5415 events
-- whose Duration values are all gaps, and 5393 of them are Individual Sprint or Keirin,
-- where a heat is won by whoever crosses the line first and the clock settles nothing. What
-- those two do with the field is the sport rather than a defect, and reporting them would
-- bury the 22 events in disciplines that are decided on the time they failed to store.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate,
        d.name AS discipline_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        COUNT(*) AS gap_values,
        SUBSTRING_INDEX(GROUP_CONCAT(DISTINCT r.value ORDER BY r.value SEPARATOR ' | '), ' | ', 8) AS sample_values
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
    JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    JOIN result r ON r.event_participantsFK = ep.id AND r.result_typeFK = 101 AND r.del = 'no'
WHERE e.del = 'no'
      AND tt.sportFK = 55
      AND t.tournament_templateFK NOT IN (12793, 12794, 12795, 12796)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
      AND od.disciplineFK IN (122, 123, 124, 130, 376, 382, 385, 387, 392, 393, 394, 395, 396, 548)
    GROUP BY e.id, e.name, e.startdate, d.name, tt.name, t.name
    HAVING SUM(CASE WHEN TRIM(r.value) LIKE '+%' THEN 1 ELSE 0 END) > 0
       AND SUM(CASE WHEN TRIM(r.value) NOT LIKE '+%' AND TRIM(r.value) NOT LIKE '-%' THEN 1 ELSE 0 END) = 0
) x

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
JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
WHERE e.del = 'no'
AND tt.sportFK = 55
AND t.tournament_templateFK NOT IN (12793, 12794, 12795, 12796)
AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
-- AND t.tournament_templateFK = <tournament_template_id>
  AND od.disciplineFK IN (122, 123, 124, 130, 376, 382, 385, 387, 392, 393, 394, 395, 396, 548)
  AND EXISTS (
      SELECT 1
      FROM event_participants ep
      JOIN result r ON r.event_participantsFK = ep.id AND r.result_typeFK = 101 AND r.del = 'no'
      WHERE ep.eventFK = e.id AND ep.del = 'no'
  );

-- ==============================================================================

SELECT
    -- CheckID - Track-Cycling-DQ-077
    -- Name - EVENT_TEAM_LINEUP_SIZE_NOT_A_FIELD_THE_DISCIPLINE_ENTERS
    -- What it does: Flags a team entry whose lineup holds a number of riders its discipline does not field.
    'Team_Lineup_Size_Not_A_Field_The_Discipline_Enters' AS check_type,
    y.event_id,
    y.event_name,
    y.startdate,
    y.discipline_name,
    y.gender,
    y.template_name,
    y.team_name,
    y.members,
    y.member_names,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds a team entered in one of this sport’s team formats
-- whose lineup does not hold the number of riders that format is ridden by. The sizes are
-- the rules of the discipline and not a shape read out of the data: a Madison is ridden by
-- two, a men’s team pursuit by four and a men’s team sprint by three.
-- Two of them are written as a pair of sizes rather than one, because the rule changed and
-- the discipline id did not. The women's team pursuit went from three riders over three
-- kilometres to four over four, and the women's team sprint from two riders to three. Both
-- sizes are correct in this sport’s history, so both are accepted and no cut-off date has
-- to be carried. The same pattern is why Track-Cycling-DQ-074 asserts no direction.
-- `Track-Cycling-DQ-022` cannot find this. GLOBAL-DQ-068 compares the teams inside one event
-- against each other and reports the ones that disagree, so an event in which every team is
-- the wrong size passes it untouched. Measured 2026-08-26, `ev 4706595` holds four team
-- pursuit squads of five and `ev 4706594` four team sprint squads of four, all typed
-- `14 Starter`: a squad list with its reserve recorded where the starters belong. That is
-- the shape this reports and the other check is blind to, the same way GLOBAL-DQ-142 stands
-- to GLOBAL-DQ-129.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate,
        d.name AS discipline_name,
        od.disciplineFK AS discipline_id,
        ts.gender,
        tt.name AS template_name,
        p.name AS team_name,
        COUNT(l.id) AS members,
        SUBSTRING_INDEX(GROUP_CONCAT(DISTINCT lm.name ORDER BY lm.name SEPARATOR ' | '), ' | ', 8) AS member_names
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
    JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no' AND p.type = 'team'
    JOIN lineup l ON l.event_participantsFK = ep.id AND l.del = 'no'
    LEFT JOIN participant lm ON lm.id = l.participantFK AND lm.del = 'no'
WHERE e.del = 'no'
      AND tt.sportFK = 55
      AND t.tournament_templateFK NOT IN (12793, 12794, 12795, 12796)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
      AND od.disciplineFK IN (130, 376, 380, 389, 390, 391, 392, 400)
    GROUP BY e.id, e.name, e.startdate, d.name, od.disciplineFK, ts.gender, tt.name,
             ep.id, p.name
) y
WHERE NOT (
      (y.discipline_id = 130 AND y.gender = 'male'   AND y.members = 4)
   OR (y.discipline_id = 130 AND y.gender = 'female' AND y.members IN (3, 4))
   OR (y.discipline_id = 376 AND y.gender = 'male'   AND y.members = 3)
   OR (y.discipline_id = 376 AND y.gender = 'female' AND y.members IN (2, 3))
   OR (y.discipline_id IN (380, 389, 390, 391, 392, 400) AND y.members = 2)
)

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ep.id) AS eligible_count,
    1 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
JOIN participant p ON p.id = ep.participantFK AND p.del = 'no' AND p.type = 'team'
JOIN lineup l ON l.event_participantsFK = ep.id AND l.del = 'no'
WHERE e.del = 'no'
AND tt.sportFK = 55
AND t.tournament_templateFK NOT IN (12793, 12794, 12795, 12796)
AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
-- AND t.tournament_templateFK = <tournament_template_id>
  AND od.disciplineFK IN (130, 376, 380, 389, 390, 391, 392, 400);

-- ==============================================================================

SELECT
    -- CheckID - Track-Cycling-DQ-078
    -- Name - EVENT_DURATION_WRITTEN_IN_A_NOTATION_THE_SPORT_DOES_NOT_USE
    -- What it does: Flags an event storing a Duration written with the wrong separator, or a clock value carrying no fraction of a second at all.
    y.check_type,
    y.event_id,
    y.event_name,
    y.startdate,
    y.discipline_name,
    y.template_name,
    y.tournament_name,
    y.values_seen,
    y.sample_values,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds a stored time written in a notation this sport does
-- not use, in three shapes that are one repair.
-- MINUTE_SEPARATOR_IS_A_DOT is `4.30.752` where `4:30.752` belongs. Measured 2026-08-26 that
-- is 89 values over ten events and every one of them comes from a single template, the
-- Oceania Track Championship, between 2017 and 2025: one feed writing minutes with a dot.
-- FRACTION_SEPARATOR_IS_A_COLON is `46:17:00` for forty-six minutes and seventeen seconds,
-- and CLOCK_VALUE_WITH_NO_FRACTION is `13:40` for a flying two hundred metres. A sport
-- timing to the thousandth does not record a time to the whole second, so a clock value with
-- no fraction is a decimal point written as a colon rather than a coarser measurement.
-- Neither existing check reaches these. GLOBAL-DQ-120 excludes a value carrying two dots
-- from its numeric pattern outright, so the dotted-minute form is invisible to it, and
-- GLOBAL-DQ-019 tests only whether a value carries a leading plus for the rank that holds
-- it. The comma form is a different matter and is already reported: GLOBAL-DQ-120 was
-- extended on 2026-08-26 to read a comma in a clock field, which is what catches `33,588`.
FROM (
    SELECT
        CASE
            WHEN TRIM(r.value) REGEXP '^[0-9]+[.][0-9]{2}[.][0-9]+$'
                 THEN 'MINUTE_SEPARATOR_IS_A_DOT'
            WHEN TRIM(r.value) REGEXP '^[0-9]+:[0-9]{1,2}:[0-9]{1,2}$'
                 THEN 'FRACTION_SEPARATOR_IS_A_COLON'
            ELSE 'CLOCK_VALUE_WITH_NO_FRACTION'
        END AS check_type,
        e.id AS event_id,
        e.name AS event_name,
        e.startdate,
        d.name AS discipline_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        COUNT(*) AS values_seen,
        SUBSTRING_INDEX(GROUP_CONCAT(DISTINCT TRIM(r.value) ORDER BY TRIM(r.value) SEPARATOR ' | '), ' | ', 8) AS sample_values
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
    JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    JOIN result r ON r.event_participantsFK = ep.id AND r.result_typeFK IN (101, 557) AND r.del = 'no'
WHERE e.del = 'no'
      AND tt.sportFK = 55
      AND t.tournament_templateFK NOT IN (12793, 12794, 12795, 12796)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
      AND (TRIM(r.value) REGEXP '^[0-9]+[.][0-9]{2}[.][0-9]+$'
        OR TRIM(r.value) REGEXP '^[0-9]+:[0-9]{1,2}:[0-9]{1,2}$'
        OR TRIM(r.value) REGEXP '^[0-9]+:[0-9]{1,2}$')
    GROUP BY check_type, e.id, e.name, e.startdate, d.name, tt.name, t.name
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
JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
WHERE e.del = 'no'
AND tt.sportFK = 55
AND t.tournament_templateFK NOT IN (12793, 12794, 12795, 12796)
AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
-- AND t.tournament_templateFK = <tournament_template_id>
  AND EXISTS (
      SELECT 1
      FROM event_participants ep
      JOIN result r ON r.event_participantsFK = ep.id AND r.result_typeFK IN (101, 557) AND r.del = 'no'
      WHERE ep.eventFK = e.id AND ep.del = 'no'
  );

-- ==============================================================================

SELECT
    -- CheckID - Track-Cycling-DQ-079
    -- Name - EVENT_DURATION_IMPLAUSIBLE_FOR_ITS_DISCIPLINE
    -- What it does: Flags an event whose stored times fall outside the range its discipline can physically be ridden in.
    'Duration_Implausible_For_Its_Discipline' AS check_type,
    y.event_id,
    y.event_name,
    y.startdate,
    y.discipline_name,
    y.gender,
    y.template_name,
    y.implausible_values,
    y.sample_values,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds an event of a fixed-distance discipline holding a time
-- that distance cannot be covered in. Each band is placed in a gap in the measured
-- distribution rather than around a mean, and each is wide enough to hold every level the
-- sport is raced at, from a world record to a national junior championship:
--   500 m and Omnium 500 m       25 to 50 seconds
--   1 km and Omnium 1 km         50 to 150
--   pursuits, team and solo      120 to 600
--   team sprint                  30 to 120
--   flying laps and 250 m TT     8 to 30
-- Measured 2026-08-26 the bands hold 608 values over 64 events, and the largest block is not
-- scattered error but one systematic mix-up. The women’s `123 1km Individual time trial`
-- holds 514 times of which 451 run from 33.296 to 42.044 across 31 events, and the world
-- record for a kilometre is 55.4 seconds: those are five-hundred-metre times filed under the
-- kilometre, in events named `1 KM Time Trial`. The mirror sits beside it - every one of the
-- 22 men’s `122 500m Individual time trial` times and all 75 men’s
-- `396 Omnium - 500m Ind. time trial` times run from 59 to 74 seconds, which is a kilometre.
-- Historically the championship distance was 500 m for women and 1 km for men, and the two
-- disciplines appear to have been assigned by that expectation rather than by the race.
-- Only the disciplines whose distance is fixed are read. The mass-start formats are out
-- because a scratch or a points race has no fixed duration, and the sprint and the keirin
-- are out because what they store in this field is a flying two hundred, a heat time or a
-- gap depending on the round, with no single band that could be right for all three.
FROM (
    SELECT
        y0.event_id,
        y0.event_name,
        y0.startdate,
        y0.discipline_name,
        y0.gender,
        y0.template_name,
        COUNT(*) AS implausible_values,
        SUBSTRING_INDEX(GROUP_CONCAT(DISTINCT y0.raw ORDER BY y0.raw SEPARATOR ' | '), ' | ', 8) AS sample_values
    FROM (
        SELECT
            e.id AS event_id,
            e.name AS event_name,
            e.startdate,
            d.name AS discipline_name,
            od.disciplineFK AS discipline_id,
            ts.gender,
            tt.name AS template_name,
            TRIM(r.value) AS raw,
            CASE WHEN TRIM(r.value) LIKE '%:%'
                 THEN CAST(SUBSTRING_INDEX(TRIM(r.value), ':', 1) AS DECIMAL(12,4)) * 60
                    + CAST(SUBSTRING_INDEX(TRIM(r.value), ':', -1) AS DECIMAL(12,4))
                 ELSE CAST(TRIM(r.value) AS DECIMAL(12,4)) END AS secs
        FROM event e
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
        JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
        JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
        JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
        JOIN result r ON r.event_participantsFK = ep.id AND r.result_typeFK = 101 AND r.del = 'no'
    WHERE e.del = 'no'
          AND tt.sportFK = 55
          AND t.tournament_templateFK NOT IN (12793, 12794, 12795, 12796)
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
          -- AND t.tournament_templateFK = <tournament_template_id>
          AND od.disciplineFK IN (122, 123, 124, 130, 376, 382, 385, 387, 392, 393, 395, 396)
          AND TRIM(r.value) REGEXP '^[0-9]+(:[0-9]{2})?[.][0-9]+$'
    ) y0
    WHERE
      (y0.discipline_id IN (122, 396) AND (y0.secs < 25  OR y0.secs > 50))
   OR (y0.discipline_id IN (123, 387) AND (y0.secs < 50  OR y0.secs > 150))
   OR (y0.discipline_id IN (124, 130, 385) AND (y0.secs < 120 OR y0.secs > 600))
   OR (y0.discipline_id = 376 AND (y0.secs < 30  OR y0.secs > 120))
   OR (y0.discipline_id IN (382, 392, 393, 395) AND (y0.secs < 8 OR y0.secs > 30))
    GROUP BY y0.event_id, y0.event_name, y0.startdate, y0.discipline_name, y0.gender,
             y0.template_name
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
JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
WHERE e.del = 'no'
AND tt.sportFK = 55
AND t.tournament_templateFK NOT IN (12793, 12794, 12795, 12796)
AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
-- AND t.tournament_templateFK = <tournament_template_id>
  AND od.disciplineFK IN (122, 123, 124, 130, 376, 382, 385, 387, 392, 393, 395, 396)
  AND EXISTS (
      SELECT 1
      FROM event_participants ep
      JOIN result r ON r.event_participantsFK = ep.id AND r.result_typeFK = 101 AND r.del = 'no'
      WHERE ep.eventFK = e.id AND ep.del = 'no'
        AND TRIM(r.value) REGEXP '^[0-9]+(:[0-9]{2})?[.][0-9]+$'
  );

-- ==============================================================================

SELECT
    -- CheckID - Track-Cycling-DQ-080
    -- Name - EVENT_TIMED_FINISHER_WITHOUT_A_TIME
    -- What it does: Flags a finisher ranked in a discipline decided on the clock who carries no Duration at all.
    'Timed_Finisher_Without_A_Time' AS check_type,
    y.event_id,
    y.event_name,
    y.startdate,
    y.discipline_name,
    y.template_name,
    y.tournament_name,
    y.finishers_without_the_value,
    y.ranked_finishers,
    y.sample_competitors,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds a competitor holding a rank, in a finished event of
-- a discipline ridden alone against the watch, with no `101 Duration` stored and no status
-- saying they did not finish. The time is the thing that placed them and it is not there.
-- `Track-Cycling-DQ-056` asks a weaker question and can never reach zero for it. That
-- template asks whether a ranked competitor holds any deciding value at all, and half this
-- sport is settled by who crosses the line first: a keirin rider, a scratch rider and an
-- elimination rider each carry a rank and nothing else, correctly. Asked per discipline the
-- question has an answer, and this is the half of it that can be driven to zero.
-- The pursuits and the team sprint are deliberately out. Their event named `Final` is the
-- whole competition’s closing classification rather than a race, so it holds the entire
-- field with only the medal rides timed, and reporting those would be reporting the storage
-- model. Measured 2026-08-26 admitting them raises this from 172 events to more than 1200.
-- What is left is the disciplines where every rider starts alone and every finisher must
-- have a time: the two individual time trials, the flying laps, the Omnium’s timed
-- components, the team time trial and the stayer.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate,
        d.name AS discipline_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        SUM(CASE WHEN v.id IS NULL THEN 1 ELSE 0 END) AS finishers_without_the_value,
        COUNT(DISTINCT ep.id) AS ranked_finishers,
        SUBSTRING_INDEX(GROUP_CONCAT(DISTINCT CASE WHEN v.id IS NULL THEN p.name END ORDER BY p.name SEPARATOR ' | '), ' | ', 8) AS sample_competitors
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
    JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
    JOIN result rk ON rk.event_participantsFK = ep.id AND rk.result_typeFK = 100 AND rk.del = 'no'
    LEFT JOIN result v ON v.event_participantsFK = ep.id AND v.result_typeFK = 101 AND v.del = 'no'
    LEFT JOIN result cmt ON cmt.event_participantsFK = ep.id AND cmt.result_typeFK = 104 AND cmt.del = 'no'
WHERE e.del = 'no'
      AND tt.sportFK = 55
      AND t.tournament_templateFK NOT IN (12793, 12794, 12795, 12796)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
      AND e.status_type = 'finished'
      AND od.disciplineFK IN (122, 123, 382, 385, 387, 392, 393, 394, 395, 396, 548)
      AND rk.value REGEXP '^[0-9]+$'
      AND (cmt.value IS NULL OR LOWER(TRIM(cmt.value)) NOT REGEXP '(dnf|dns|dsq|disq|abd|dq)')
    GROUP BY e.id, e.name, e.startdate, d.name, tt.name, t.name
    HAVING finishers_without_the_value > 0
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
JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
WHERE e.del = 'no'
AND tt.sportFK = 55
AND t.tournament_templateFK NOT IN (12793, 12794, 12795, 12796)
AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
-- AND t.tournament_templateFK = <tournament_template_id>
  AND e.status_type = 'finished'
  AND od.disciplineFK IN (122, 123, 382, 385, 387, 392, 393, 394, 395, 396, 548)
  AND EXISTS (
      SELECT 1
      FROM event_participants ep
      JOIN result rk ON rk.event_participantsFK = ep.id AND rk.result_typeFK = 100 AND rk.del = 'no'
      WHERE ep.eventFK = e.id AND ep.del = 'no'
        AND rk.value REGEXP '^[0-9]+$'
  );

-- ==============================================================================

SELECT
    -- CheckID - Track-Cycling-DQ-081
    -- Name - EVENT_POINTS_FINISHER_WITHOUT_POINTS
    -- What it does: Flags a finisher ranked in a discipline decided on points who carries no Points at all.
    'Points_Finisher_Without_Points' AS check_type,
    y.event_id,
    y.event_name,
    y.startdate,
    y.discipline_name,
    y.template_name,
    y.tournament_name,
    y.finishers_without_the_value,
    y.ranked_finishers,
    y.sample_competitors,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds a competitor holding a rank, in a finished event of a
-- discipline classified on points, with no `102 Points` stored and no status saying they
-- did not finish. The points races, the tempo race, the Omnium and its overall, the Madison
-- and the six-day are all placed from that figure, and where it is absent the placing rests
-- on nothing the database holds.
-- A missing row does not mean a score of zero. This sport writes the zero: measured
-- 2026-08-26, `ev 5025645` records `Frank Longstaff 0` in twelfth place, and negative totals
-- are written too, down to -37 for a lapped Madison pair. An absent Points row is therefore
-- a value that was never entered rather than a rider who scored none.
-- This is the other half of the question `Track-Cycling-DQ-056` can only monitor, and it is
-- kept separate from `Track-Cycling-DQ-080` on purpose. Together they return 360 events,
-- past the point where a board row is read; apart, each stands under it and each names one
-- field to repair.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate,
        d.name AS discipline_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        SUM(CASE WHEN v.id IS NULL THEN 1 ELSE 0 END) AS finishers_without_the_value,
        COUNT(DISTINCT ep.id) AS ranked_finishers,
        SUBSTRING_INDEX(GROUP_CONCAT(DISTINCT CASE WHEN v.id IS NULL THEN p.name END ORDER BY p.name SEPARATOR ' | '), ' | ', 8) AS sample_competitors
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
    JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
    JOIN result rk ON rk.event_participantsFK = ep.id AND rk.result_typeFK = 100 AND rk.del = 'no'
    LEFT JOIN result v ON v.event_participantsFK = ep.id AND v.result_typeFK = 102 AND v.del = 'no'
    LEFT JOIN result cmt ON cmt.event_participantsFK = ep.id AND cmt.result_typeFK = 104 AND cmt.del = 'no'
WHERE e.del = 'no'
      AND tt.sportFK = 55
      AND t.tournament_templateFK NOT IN (12793, 12794, 12795, 12796)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
      AND e.status_type = 'finished'
      AND od.disciplineFK IN (378, 380, 381, 383, 388, 389, 397, 400)
      AND rk.value REGEXP '^[0-9]+$'
      AND (cmt.value IS NULL OR LOWER(TRIM(cmt.value)) NOT REGEXP '(dnf|dns|dsq|disq|abd|dq)')
    GROUP BY e.id, e.name, e.startdate, d.name, tt.name, t.name
    HAVING finishers_without_the_value > 0
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
JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
WHERE e.del = 'no'
AND tt.sportFK = 55
AND t.tournament_templateFK NOT IN (12793, 12794, 12795, 12796)
AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
-- AND t.tournament_templateFK = <tournament_template_id>
  AND e.status_type = 'finished'
  AND od.disciplineFK IN (378, 380, 381, 383, 388, 389, 397, 400)
  AND EXISTS (
      SELECT 1
      FROM event_participants ep
      JOIN result rk ON rk.event_participantsFK = ep.id AND rk.result_typeFK = 100 AND rk.del = 'no'
      WHERE ep.eventFK = e.id AND ep.del = 'no'
        AND rk.value REGEXP '^[0-9]+$'
  );

-- ==============================================================================

SELECT
    -- CheckID - Track-Cycling-DQ-082
    -- Name - EVENT_TIMED_SPREAD_TOO_WIDE_FOR_ONE_RACE
    -- What it does: Flags a timed event whose slowest time is more than 1.6 times its fastest, which no single race of that discipline produces.
    'Timed_Spread_Too_Wide_For_One_Race' AS check_type,
    y.event_id,
    y.event_name,
    y.startdate,
    y.discipline_name,
    y.template_name,
    y.times_seen,
    y.fastest,
    y.slowest,
    ROUND(y.slowest / y.fastest, 2) AS spread,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds an event of a fixed-distance discipline whose stored
-- times are too far apart to have come from one race. The threshold sits in a gap in the
-- measured distribution rather than at a round number: of the 1704 timed events holding three
-- times or more, 1499 spread by less than 1.15, another 176 reach 1.30, then 17 reach 1.60,
-- 8 reach 2.00 and 4 go beyond. Measured 2026-08-26, a cut at 1.60 returns 12 events.
-- It is a `Monitor` and not an `Actionable` check. A wide spread is a symptom rather than a
-- defect: it can be a time in the wrong unit, a gap stored without its plus, a rider from
-- another discipline, or a genuine field mixing a world-class rider with a novice at a small
-- meeting. The row says the card does not read like one race and the reading decides which.
-- Its far end overlaps `Track-Cycling-DQ-079`, which reports what no rider of that discipline
-- could have ridden at all. This one exists for what is possible and still does not belong,
-- and the overlap is the point where the two agree rather than a duplication.
FROM (
    SELECT
        x.event_id,
        x.event_name,
        x.startdate,
        x.discipline_name,
        x.template_name,
        COUNT(*) AS times_seen,
        MIN(x.secs) AS fastest,
        MAX(x.secs) AS slowest
    FROM (
        SELECT
            e.id AS event_id,
            e.name AS event_name,
            e.startdate,
            d.name AS discipline_name,
            tt.name AS template_name,
            CASE WHEN TRIM(r.value) LIKE '%:%'
                 THEN CAST(SUBSTRING_INDEX(TRIM(r.value), ':', 1) AS DECIMAL(12,4)) * 60
                    + CAST(SUBSTRING_INDEX(TRIM(r.value), ':', -1) AS DECIMAL(12,4))
                 ELSE CAST(TRIM(r.value) AS DECIMAL(12,4)) END AS secs
        FROM event e
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
        JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
        JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
        JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
        JOIN result r ON r.event_participantsFK = ep.id AND r.result_typeFK = 101 AND r.del = 'no'
    WHERE e.del = 'no'
          AND tt.sportFK = 55
          AND t.tournament_templateFK NOT IN (12793, 12794, 12795, 12796)
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
          -- AND t.tournament_templateFK = <tournament_template_id>
          AND od.disciplineFK IN (122, 123, 124, 130, 376, 382, 385, 387, 392, 393, 395, 396)
          AND TRIM(r.value) REGEXP '^[0-9]+(:[0-9]{2})?[.][0-9]+$'
    ) x
    GROUP BY x.event_id, x.event_name, x.startdate, x.discipline_name, x.template_name
    HAVING COUNT(*) >= 3
       AND MIN(x.secs) > 0
       AND MAX(x.secs) / MIN(x.secs) >= 1.6
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
JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
WHERE e.del = 'no'
AND tt.sportFK = 55
AND t.tournament_templateFK NOT IN (12793, 12794, 12795, 12796)
AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
-- AND t.tournament_templateFK = <tournament_template_id>
  AND od.disciplineFK IN (122, 123, 124, 130, 376, 382, 385, 387, 392, 393, 395, 396)
  AND EXISTS (
      SELECT 1
      FROM event_participants ep
      JOIN result r ON r.event_participantsFK = ep.id AND r.result_typeFK = 101 AND r.del = 'no'
      WHERE ep.eventFK = e.id AND ep.del = 'no'
        AND TRIM(r.value) REGEXP '^[0-9]+(:[0-9]{2})?[.][0-9]+$'
  );
