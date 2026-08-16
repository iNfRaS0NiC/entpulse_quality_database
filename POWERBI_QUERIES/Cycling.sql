SELECT
    -- CheckID - Cycling-DQ-001
    -- Name - PARTICIPANT_REGISTERED_BUT_NEVER_ENTERED_IN_THIS_SPORT
    -- What it does: Flags participants registered to the sport that no event and no Comp.Rank of this sport reaches, separating the ones that race in another sport from the ones entered nowhere at all.
    CASE WHEN (
        SELECT COUNT(*)
        FROM event_participants ep4
        JOIN event e4 ON e4.id = ep4.eventFK AND e4.del = 'no'
        JOIN tournament_stage ts4 ON ts4.id = e4.tournament_stageFK AND ts4.del = 'no'
        JOIN tournament t4 ON t4.id = ts4.tournamentFK AND t4.del = 'no'
        JOIN tournament_template tt4 ON tt4.id = t4.tournament_templateFK AND tt4.del = 'no'
        WHERE ep4.participantFK = p.id
          AND ep4.del = 'no'
    ) > 0 THEN 'REGISTERED_HERE_AND_ENTERED_IN_ANOTHER_SPORT'
    ELSE 'REGISTERED_AND_ENTERED_NOWHERE_AT_ALL' END AS check_type,
    p.id AS participant_id,
    p.name AS participant_name,
    p.type AS participant_type,
    op.active AS registry_active_flag,
    (
        SELECT GROUP_CONCAT(DISTINCT s5.name ORDER BY s5.name SEPARATOR ' | ')
        FROM event_participants ep5
        JOIN event e5 ON e5.id = ep5.eventFK AND e5.del = 'no'
        JOIN tournament_stage ts5 ON ts5.id = e5.tournament_stageFK AND ts5.del = 'no'
        JOIN tournament t5 ON t5.id = ts5.tournamentFK AND t5.del = 'no'
        JOIN tournament_template tt5 ON tt5.id = t5.tournament_templateFK AND tt5.del = 'no'
        JOIN sport s5 ON s5.id = tt5.sportFK
        WHERE ep5.participantFK = p.id
          AND ep5.del = 'no'
    ) AS sports_entered,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds a participant the sport registry claims, that no event
-- of this sport and no Comp.Rank of this sport ever reaches, and says which of two different
-- things that is.
-- The split is the whole reason this exists beside GLOBAL-DQ-009. That template asserts the
-- three participation paths inside the sport that registered the participant, which is correct
-- and is also why it cannot tell a stranded record from a rider filed under the wrong sport.
-- Measured 2026-08-16 over 2791 reported participants: 2457 are entered nowhere in the database
-- at all - 2175 athletes, 2016 of them carrying a date of birth, and 282 teams - while 334 race
-- perfectly well next door, 131 in Para Cycling, 129 in Track Cycling, 52 in Mountain Bike, 16
-- in two of those and 6 across other combinations. The second group is a work list and the
-- first is a question about where the records came from, and reported together they are neither.
-- sports_entered names them rather than counting them, because which neighbour it is decides
-- whether the registration is wrong or the rider genuinely rides both.
-- Two paths, not three: the sport writes no lineup at all, so the third the template asserts
-- has nothing to read here. Coaches are out of scope for this sport by decision of 2026-08-16
-- and are not registered types here; SPORTS/Cycling.md records both.
FROM object_participants op
JOIN participant p ON p.id = op.participantFK AND p.del = 'no'
WHERE op.object = 'sport'
  AND op.objectFK = 30
  AND op.del = 'no'
  AND p.type IN ('athlete', 'team')
  -- AND p.id BETWEEN <from_participant_id> AND <to_participant_id>
  AND NOT EXISTS (
      SELECT 1
      FROM event_participants ep
      JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
      JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
      JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
      JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
      WHERE ep.participantFK = p.id
        AND ep.del = 'no'
        AND tt.sportFK = 30
  )
  AND NOT EXISTS (
      SELECT 1
      FROM statistic_participants11 sp
      JOIN statistic s ON s.id = sp.statisticFK AND s.del = 'no'
           AND s.statistic_typeFK = 11
      JOIN tournament t3 ON t3.id = s.objectFK AND t3.del = 'no'
      JOIN tournament_template tt3 ON tt3.id = t3.tournament_templateFK AND tt3.del = 'no'
      WHERE sp.participantFK = p.id
        AND sp.del = 'no'
        AND s.object_typeFK = 3
        AND tt3.sportFK = 30
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT op.participantFK) AS eligible_count,
    1 AS sort_order
FROM object_participants op
JOIN participant p ON p.id = op.participantFK AND p.del = 'no'
WHERE op.object = 'sport'
  AND op.objectFK = 30
  AND op.del = 'no'
  AND p.type IN ('athlete', 'team')
  -- AND p.id BETWEEN <from_participant_id> AND <to_participant_id>

ORDER BY sort_order, check_type, participant_type, participant_name;
