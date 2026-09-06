SELECT
    -- CheckID - Shooting-DQ-075
    -- Name - EVENT_RESULTS_TIED_SCORE_WITHOUT_SHARED_RANK_IN_MEDAL_ROUND
    -- What it does: Flags finals and bronze rounds where competitors holding the same Points were given different Ranks.
    'Tied_Score_Without_Shared_Rank_In_Medal_Round' AS check_type,
    g.event_id,
    g.event_name,
    g.event_startdate,
    g.round_type_name,
    g.template_name,
    g.tournament_name,
    COUNT(*) AS tied_groups,
    SUM(g.group_size) AS affected_participants,
    SUBSTRING(GROUP_CONCAT(
        CONCAT('102 Points = ', g.shared_value, ' -> ranks ', g.ranks_held)
        ORDER BY g.shared_value SEPARATOR ' | '), 1, 300) AS tied_values,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds a finished final or bronze round in which two or more
-- competitors hold an identical 102 Points and were nonetheless given different places.
-- This is GLOBAL-DQ-127 EVENT_RESULTS_TIED_VALUE_WITHOUT_SHARED_RANK asked of the rounds where
-- the answer costs somebody something, and it exists because that template cannot be narrowed.
-- It reads RESULT_TIE_VALUE_TYPE_LIST and audits the sport whole, with no round-type parameter
-- to restrict it, and five sports instantiate it in that form. Adding one would put the same
-- question to Biathlon, Mountain Bike, Speed Skating, Swimming and Track Cycling, who have not
-- been asked it, so the narrowing is written here instead.
-- Why it is narrowed at all. Equal Points with different Ranks is how this sport ranks: a tie is
-- shot off in a final and counted back in a qualification, and the separator is almost never
-- stored. Measured 2026-09-06 over every finished event: 31 578 such tie groups in 4 620 events,
-- of which four carry anything that records a tie-break - 'pr, s-off 7', 'pr, s-off 8',
-- 's-off: 2' and 'q s-off: 4' in 104 Comment. Seventeen more carry a DNS or a Q in 535 Tops or
-- 536 Zones, which explains nothing, and 31 552 carry nothing anywhere. Run whole, the global
-- template reports 4 620 of 8 586 eligible events, 54% of the sport, and a check reporting half
-- a sport's events is not read by anybody.
-- Restricted to MEDAL_ROUND_TYPE_LIST - 173 Final and 181 bronze - it reports 1 865 tie groups
-- in 968 events, which is the population the user chose on 2026-09-06 after the four narrowings
-- were measured and put to them. The three not chosen are recorded so the choice stays legible:
-- the medal rounds where the tie touches a place 1-3 give 738 groups in 695 events; any round
-- where it touches a place 1-3 gives 3 418 in 3 084; and the tie groups where a medal was
-- actually awarded to one of the tied competitors give 759 in 714.
-- A row here is not a defect on its face and this statement does not claim it is. In a final
-- every place is settled by a shoot-off rather than counted back, so a row is one editorial
-- decision to be read: the two competitors were separated by something, and either that
-- something belongs in the record or the ranking is wrong. Which of the two is what the review
-- decides, one row at a time, on the user's decision of 2026-09-06 that people on the same score
-- should stay in a check rather than be classified away. GLOBAL-DQ-127 stays Not applicable for
-- this sport as written, for the reason above, and SPORTS/Shooting.md carries both halves.
-- Confirmed non-finishers are excluded through the same no-result vocabulary the global template
-- uses, because a field of competitors who did not finish shares no place between them.
-- The audited object is the event. A tie ranked apart is one decision about one round however
-- many competitors it caught, and an event may hold several, so tied_groups,
-- affected_participants and tied_values carry the detail as named secondary columns.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        rt.name AS round_type_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        tv.value AS shared_value,
        COUNT(DISTINCT ep.id) AS group_size,
        SUBSTRING(GROUP_CONCAT(DISTINCT rk.value
            ORDER BY CAST(rk.value AS UNSIGNED) SEPARATOR ', '), 1, 60) AS ranks_held
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN round_type rt ON rt.id = e.round_typeFK
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    JOIN result rk ON rk.event_participantsFK = ep.id AND rk.del = 'no'
                  AND rk.result_typeFK = 100
                  AND rk.value REGEXP '^[0-9]+$'
    JOIN result tv ON tv.event_participantsFK = ep.id AND tv.del = 'no'
                  AND tv.result_typeFK = 102
                  AND tv.value IS NOT NULL
                  AND TRIM(tv.value) <> ''
    LEFT JOIN result cm ON cm.event_participantsFK = ep.id AND cm.del = 'no'
                       AND cm.result_typeFK = 104
    WHERE e.del = 'no'
      AND tt.sportFK = 45
      AND e.status_type = 'finished'
      AND e.round_typeFK IN (173, 181)
      AND (cm.value IS NULL OR LOWER(TRIM(cm.value)) NOT IN ('dns', 'dnf', 'disq.', 'dsq'))
      AND t.tournament_templateFK NOT IN (0)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY e.id, e.name, e.startdate, rt.name, tt.name, t.name, tv.value
    HAVING COUNT(DISTINCT rk.value) > 1
) g
GROUP BY g.event_id, g.event_name, g.event_startdate, g.round_type_name, g.template_name, g.tournament_name

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
JOIN round_type rt ON rt.id = e.round_typeFK
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
JOIN result rk ON rk.event_participantsFK = ep.id AND rk.del = 'no'
              AND rk.result_typeFK = 100
              AND rk.value REGEXP '^[0-9]+$'
JOIN result tv ON tv.event_participantsFK = ep.id AND tv.del = 'no'
              AND tv.result_typeFK = 102
              AND tv.value IS NOT NULL
              AND TRIM(tv.value) <> ''
LEFT JOIN result cm ON cm.event_participantsFK = ep.id AND cm.del = 'no'
                   AND cm.result_typeFK = 104
WHERE e.del = 'no'
  AND tt.sportFK = 45
  AND e.status_type = 'finished'
  AND e.round_typeFK IN (173, 181)
  AND (cm.value IS NULL OR LOWER(TRIM(cm.value)) NOT IN ('dns', 'dnf', 'disq.', 'dsq'))
  AND t.tournament_templateFK NOT IN (0)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, affected_participants DESC, event_id
;
