SELECT
    -- CheckID - GLOBAL-DQ-007
    -- Name - PARTICIPANT_MISSING_DATE_OF_BIRTH
    -- What it does: Finds active participants of the sport's person types, reached through the sport registry or through any of the three ways a person takes part - an event participant row, a lineup place or a Comp.Rank statistic - that carry no active, non-empty date_of_birth property value, with their country and a count of their participations on each of the three paths, ordered by how many they have in total, together with a coverage count of all eligible participants.
    'Missing_DOB' AS check_type,
    x.participant_id,
    x.participant_name,
    x.participant_type,
    (
        SELECT c.name
        FROM country c
        WHERE c.id = x.countryFK
          AND c.del = 'no'
    ) AS participant_country,
    x.event_participations,
    x.lineup_participations,
    x.statistic_participations,
    x.total_participations,
    NULL AS eligible_count,
    0 AS sort_order
-- A person reaches a sport by three different mechanisms and no sport uses all three the
-- same way: one enters athletes directly on the event, one enters teams and carries the
-- athletes in lineups, and one carries them only in the Comp.Rank statistic. Reading a
-- single path leaves the check covering nothing in the sports that use another, which reads
-- as clean data when it means the statement never looked. All three are read, and the sport
-- registry is read beside them so that a registered athlete who has never taken part is
-- still audited: a missing date of birth on a person nobody has entered yet is the cheapest
-- moment to fix it, so a zero count is context and never a reason to leave the row out.
-- The three counts are projected separately rather than summed only, because which path a
-- person is on tells the reader where to go and fix the record.
FROM (
    SELECT
        p.id AS participant_id,
        p.name AS participant_name,
        p.type AS participant_type,
        p.countryFK,
        SUM(u.ev) AS event_participations,
        SUM(u.lu) AS lineup_participations,
        SUM(u.st) AS statistic_participations,
        SUM(u.ev) + SUM(u.lu) + SUM(u.st) AS total_participations
    FROM (
        SELECT ep.participantFK AS participant_id, 1 AS ev, 0 AS lu, 0 AS st
        FROM event_participants ep
        JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
        WHERE ep.del = 'no'
          AND tt.sportFK = {{SPORT_ID}}
          -- AND tt.id = <tournament_template_id>

        UNION ALL

        SELECT l.participantFK, 0, 1, 0
        FROM lineup l
        JOIN event_participants ep ON ep.id = l.event_participantsFK AND ep.del = 'no'
        JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
        WHERE l.del = 'no'
          AND tt.sportFK = {{SPORT_ID}}
          -- AND tt.id = <tournament_template_id>

        UNION ALL

        SELECT sp.participantFK, 0, 0, 1
        FROM statistic_participants{{SHARD_ID}} sp
        JOIN statistic s ON s.id = sp.statisticFK AND s.del = 'no'
             AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
        JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
        WHERE sp.del = 'no'
          AND s.object_typeFK = 3
          AND tt.sportFK = {{SPORT_ID}}
          -- AND tt.id = <tournament_template_id>

        -- REGISTRY BRANCH BEGIN
        UNION ALL

        SELECT op.participantFK, 0, 0, 0
        FROM object_participants op
        WHERE op.object = 'sport'
          AND op.objectFK = {{SPORT_ID}}
          AND op.del = 'no'
        -- REGISTRY BRANCH END
    ) u
    JOIN participant p ON p.id = u.participant_id AND p.del = 'no'
    WHERE p.type IN ({{PERSON_PARTICIPANT_TYPE_LIST}})
      -- AND p.id BETWEEN <from_participant_id> AND <to_participant_id>
    GROUP BY p.id, p.name, p.type, p.countryFK
) x
WHERE NOT EXISTS (
    SELECT 1
    FROM property pr
    WHERE pr.object = 'participant'
      AND pr.objectFK = x.participant_id
      AND pr.name = 'date_of_birth'
      AND pr.del = 'no'
      AND pr.value IS NOT NULL
      AND TRIM(pr.value) <> ''
)

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT y.participant_id) AS eligible_count,
    1 AS sort_order
FROM (
    SELECT ep.participantFK AS participant_id
    FROM event_participants ep
    JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    WHERE ep.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      -- AND tt.id = <tournament_template_id>

    UNION ALL

    SELECT l.participantFK
    FROM lineup l
    JOIN event_participants ep ON ep.id = l.event_participantsFK AND ep.del = 'no'
    JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    WHERE l.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      -- AND tt.id = <tournament_template_id>

    UNION ALL

    SELECT sp.participantFK
    FROM statistic_participants{{SHARD_ID}} sp
    JOIN statistic s ON s.id = sp.statisticFK AND s.del = 'no'
         AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
    JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    WHERE sp.del = 'no'
      AND s.object_typeFK = 3
      AND tt.sportFK = {{SPORT_ID}}
      -- AND tt.id = <tournament_template_id>

    -- REGISTRY BRANCH BEGIN
    UNION ALL

    SELECT op.participantFK
    FROM object_participants op
    WHERE op.object = 'sport'
      AND op.objectFK = {{SPORT_ID}}
      AND op.del = 'no'
    -- REGISTRY BRANCH END
) y
JOIN participant p ON p.id = y.participant_id AND p.del = 'no'
WHERE p.type IN ({{PERSON_PARTICIPANT_TYPE_LIST}})
  -- AND p.id BETWEEN <from_participant_id> AND <to_participant_id>

ORDER BY sort_order, total_participations DESC, participant_id;

-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-008
    -- Name - PARTICIPANT_MISSING_PROFILE_FIELDS
    -- What it does: Finds active participants of the selected types that take part in at least one active event of the sport and are missing name or country, or, for the sport's person types only, first_name and/or last_name, with the country projected beside the missing-field list, together with a coverage count of all eligible participants.
    'Missing_Profile_Field' AS check_type,
    p.id AS participant_id,
    p.name AS participant_name,
    p.type AS participant_type,
    (
        SELECT c.name
        FROM country c
        WHERE c.id = p.countryFK
          AND c.del = 'no'
    ) AS participant_country,
    CONCAT_WS(', ',
        IF(p.name IS NULL OR TRIM(p.name) = '', 'name', NULL),
        IF(NOT EXISTS (
            SELECT 1
            FROM country c
            WHERE c.id = p.countryFK
              AND c.del = 'no'
        ), 'country', NULL),
        IF(p.type IN ({{PERSON_PARTICIPANT_TYPE_LIST}}) AND NOT EXISTS (
            SELECT 1
            FROM language fn
            WHERE fn.object = 'participant'
              AND fn.objectFK = p.id
              AND fn.language_typeFK = 7
              AND fn.del = 'no'
              AND fn.name IS NOT NULL
              AND TRIM(fn.name) <> ''
        ), 'first_name', NULL),
        IF(p.type IN ({{PERSON_PARTICIPANT_TYPE_LIST}}) AND NOT EXISTS (
            SELECT 1
            FROM language ln
            WHERE ln.object = 'participant'
              AND ln.objectFK = p.id
              AND ln.language_typeFK = 8
              AND ln.del = 'no'
              AND ln.name IS NOT NULL
              AND TRIM(ln.name) <> ''
        ), 'last_name', NULL)
    ) AS missing_fields,
    NULL AS eligible_count
FROM participant p
WHERE p.del = 'no'
  AND p.type IN ({{EVENT_PARTICIPANT_TYPE_LIST}})
  -- AND p.id BETWEEN <from_participant_id> AND <to_participant_id>
  AND EXISTS (
      SELECT 1
      FROM event_participants ep
      JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
      JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
      JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
      JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
      WHERE ep.participantFK = p.id
        AND ep.del = 'no'
        AND tt.sportFK = {{SPORT_ID}}
        -- AND tt.id = <tournament_template_id>
  )
  AND (
      p.name IS NULL
      OR TRIM(p.name) = ''
      OR NOT EXISTS (
          SELECT 1
          FROM country c
          WHERE c.id = p.countryFK
            AND c.del = 'no'
      )
      OR (p.type IN ({{PERSON_PARTICIPANT_TYPE_LIST}}) AND NOT EXISTS (
          SELECT 1
          FROM language fn
          WHERE fn.object = 'participant'
            AND fn.objectFK = p.id
            AND fn.language_typeFK = 7
            AND fn.del = 'no'
            AND fn.name IS NOT NULL
            AND TRIM(fn.name) <> ''
      ))
      OR (p.type IN ({{PERSON_PARTICIPANT_TYPE_LIST}}) AND NOT EXISTS (
          SELECT 1
          FROM language ln
          WHERE ln.object = 'participant'
            AND ln.objectFK = p.id
            AND ln.language_typeFK = 8
            AND ln.del = 'no'
            AND ln.name IS NOT NULL
            AND TRIM(ln.name) <> ''
      ))
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    COUNT(DISTINCT p.id) AS eligible_count
FROM participant p
WHERE p.del = 'no'
  AND p.type IN ({{EVENT_PARTICIPANT_TYPE_LIST}})
  -- AND p.id BETWEEN <from_participant_id> AND <to_participant_id>
  AND EXISTS (
      SELECT 1
      FROM event_participants ep
      JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
      JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
      JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
      JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
      WHERE ep.participantFK = p.id
        AND ep.del = 'no'
        AND tt.sportFK = {{SPORT_ID}}
        -- AND tt.id = <tournament_template_id>
  );


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-009
    -- Name - PARTICIPANT_NO_PARTICIPATION_ANYWHERE
    -- What it does: Finds active participants of the selected types linked through active sport-registry rows that take no part in the sport by any of the three mechanisms a participant can be used by - an event participant row, a lineup place or a Comp.Rank statistic - with the registry active flag, together with a coverage count of the same registered population.
    'No_Participation_Anywhere' AS check_type,
    p.id AS participant_id,
    p.name AS participant_name,
    p.type AS participant_type,
    op.active AS registry_active_flag,
    NULL AS eligible_count,
    0 AS sort_order
-- Registration is a claim that the participant belongs to the sport; the three paths are
-- the only ways that claim is ever cashed. Asserting the event path alone reports every
-- athlete of a sport that enters teams and carries its people in lineups or in the
-- Comp.Rank statistic, which is the sport's normal shape rather than a defect, so all
-- three are read and a participant is reported only when none of them holds them.
-- The registry active flag travels with the row because an inactive registration with no
-- participation is a different repair from an active one.
FROM object_participants op
JOIN participant p
  ON p.id = op.participantFK
 AND p.del = 'no'
WHERE op.object = 'sport'
  AND op.del = 'no'
  AND op.objectFK = {{SPORT_ID}}
  AND p.type IN ({{REGISTRY_PARTICIPANT_TYPE_LIST}})
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
        AND tt.sportFK = {{SPORT_ID}}
  )
  AND NOT EXISTS (
      SELECT 1
      FROM lineup l
      JOIN event_participants ep ON ep.id = l.event_participantsFK AND ep.del = 'no'
      JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
      JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
      JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
      JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
      WHERE l.participantFK = p.id
        AND l.del = 'no'
        AND tt.sportFK = {{SPORT_ID}}
  )
  AND NOT EXISTS (
      SELECT 1
      FROM statistic_participants{{SHARD_ID}} sp
      JOIN statistic s ON s.id = sp.statisticFK AND s.del = 'no'
           AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
      JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
      JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
      WHERE sp.participantFK = p.id
        AND sp.del = 'no'
        AND s.object_typeFK = 3
        AND tt.sportFK = {{SPORT_ID}}
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL,
    NULL,
    NULL,
    NULL,
    COUNT(DISTINCT p.id) AS eligible_count,
    1 AS sort_order
FROM object_participants op
JOIN participant p
  ON p.id = op.participantFK
 AND p.del = 'no'
WHERE op.object = 'sport'
  AND op.del = 'no'
  AND op.objectFK = {{SPORT_ID}}
  AND p.type IN ({{REGISTRY_PARTICIPANT_TYPE_LIST}})
  -- AND p.id BETWEEN <from_participant_id> AND <to_participant_id>

ORDER BY sort_order, participant_id;

-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-043
    -- Name - EVENT_PARTICIPANTS_GENDER_MISMATCH
    -- What it does: Finds active event-participant rows whose gender contradicts the parent tournament stage or their own lineup: an athlete whose gender differs from a single-gender stage, a participant whose own gender differs from the stage gender, a mixed team whose lineup does not contain both male and female members, or a single-gender team whose lineup contains a member of the other gender, with stage, event and participant context and the lineup gender counts, together with a coverage count of all eligible event-participants in stages carrying a usable gender.
    CASE
        WHEN x.participant_type = 'athlete' AND x.stage_gender <> 'mixed'
             AND x.participant_gender IS NOT NULL AND x.participant_gender <> ''
             AND x.participant_gender <> x.stage_gender
            THEN 'ATHLETE_GENDER_NOT_STAGE_GENDER'
        WHEN x.participant_type = 'team'
             AND x.participant_gender IS NOT NULL AND x.participant_gender <> ''
             AND x.participant_gender <> x.stage_gender
            THEN 'TEAM_GENDER_NOT_STAGE_GENDER'
        WHEN x.participant_type = 'team' AND x.participant_gender = 'mixed'
             AND x.lineup_rows > 0 AND (x.lineup_male = 0 OR x.lineup_female = 0)
            THEN 'MIXED_TEAM_LINEUP_MISSING_A_GENDER'
        WHEN x.participant_type = 'team' AND x.participant_gender = 'male'
             AND x.lineup_rows > 0 AND x.lineup_female > 0
            THEN 'SINGLE_GENDER_TEAM_LINEUP_HAS_OTHER_GENDER'
        WHEN x.participant_type = 'team' AND x.participant_gender = 'female'
             AND x.lineup_rows > 0 AND x.lineup_male > 0
            THEN 'SINGLE_GENDER_TEAM_LINEUP_HAS_OTHER_GENDER'
    END AS check_type,
    x.event_participants_id,
    x.event_id,
    x.event_name,
    x.stage_name,
    x.stage_gender,
    x.participant_type,
    x.participant_name,
    x.participant_gender,
    x.lineup_male,
    x.lineup_female,
    NULL AS eligible_count
FROM (
    SELECT
        ep.id AS event_participants_id,
        e.id AS event_id,
        e.name AS event_name,
        ts.name AS stage_name,
        LOWER(TRIM(ts.gender)) AS stage_gender,
        p.name AS participant_name,
        p.type AS participant_type,
        LOWER(TRIM(p.gender)) AS participant_gender,
        COUNT(l.id) AS lineup_rows,
        SUM(CASE WHEN LOWER(TRIM(lp.gender)) = 'male' THEN 1 ELSE 0 END) AS lineup_male,
        SUM(CASE WHEN LOWER(TRIM(lp.gender)) = 'female' THEN 1 ELSE 0 END) AS lineup_female
    FROM event_participants ep
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
    JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    LEFT JOIN lineup l ON l.event_participantsFK = ep.id AND l.del = 'no'
    LEFT JOIN participant lp ON lp.id = l.participantFK AND lp.del = 'no'
    WHERE ep.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      AND ts.gender IS NOT NULL
      AND TRIM(ts.gender) <> ''
      AND LOWER(TRIM(ts.gender)) <> 'undefined'
      -- AND tt.id = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY ep.id, e.id, e.name, ts.name, ts.gender, p.name, p.type, p.gender
) x
WHERE
    (x.participant_type = 'athlete' AND x.stage_gender <> 'mixed'
     AND x.participant_gender IS NOT NULL AND x.participant_gender <> ''
     AND x.participant_gender <> x.stage_gender)
    OR (x.participant_type = 'team'
     AND x.participant_gender IS NOT NULL AND x.participant_gender <> ''
     AND x.participant_gender <> x.stage_gender)
    OR (x.participant_type = 'team' AND x.participant_gender = 'mixed'
     AND x.lineup_rows > 0 AND (x.lineup_male = 0 OR x.lineup_female = 0))
    OR (x.participant_type = 'team' AND x.participant_gender = 'male'
     AND x.lineup_rows > 0 AND x.lineup_female > 0)
    OR (x.participant_type = 'team' AND x.participant_gender = 'female'
     AND x.lineup_rows > 0 AND x.lineup_male > 0)

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ep.id) AS eligible_count
FROM event_participants ep
JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE ep.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND ts.gender IS NOT NULL
  AND TRIM(ts.gender) <> ''
  AND LOWER(TRIM(ts.gender)) <> 'undefined'
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-058
    -- Name - EVENT_TEAM_PARTICIPANT_WITHOUT_LINEUP
    -- What it does: Finds active events holding at least one team event participant where the lineup layer is missing, separating an event in which no team resolves to any lineup member from one in which some teams do and others do not, with the number of teams on each side, together with a coverage count of all eligible events holding at least one active team event participant.
    CASE
        WHEN x.teams_with_lineup = 0 THEN 'EVENT_NO_TEAM_HAS_LINEUP'
        ELSE 'EVENT_SOME_TEAMS_MISSING_LINEUP'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.tournament_template_name,
    x.team_count,
    x.teams_with_lineup,
    x.team_count - x.teams_with_lineup AS teams_without_lineup,
    x.teams_missing_lineup_names,
    NULL AS eligible_count
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        tt.name AS tournament_template_name,
        COUNT(DISTINCT ep.id) AS team_count,
        COUNT(DISTINCT CASE WHEN l.id IS NOT NULL THEN ep.id END) AS teams_with_lineup,
        GROUP_CONCAT(DISTINCT CASE WHEN l.id IS NULL THEN p.name END
                     ORDER BY 1 SEPARATOR ', ') AS teams_missing_lineup_names
    FROM event_participants ep
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
    JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    LEFT JOIN lineup l ON l.event_participantsFK = ep.id AND l.del = 'no'
    WHERE ep.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      AND p.type = 'team'
      -- AND tt.id = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY e.id, e.name, tt.name
) x
WHERE x.teams_with_lineup < x.team_count

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count
FROM event_participants ep
JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE ep.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND p.type = 'team'
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-067
    -- Name - EVENT_MIXED_TEAM_LINEUP_GENDER_BALANCE_UNEVEN
    -- What it does: Finds active event-participant rows of mixed-gender teams whose lineup holds both male and female members in unequal numbers, with event, stage and participant context and the lineup gender counts, together with a coverage count of all eligible event-participants of mixed-gender teams whose lineup holds at least one member of each gender.
    'MIXED_TEAM_LINEUP_GENDER_COUNT_UNEVEN' AS check_type,
    x.event_participants_id,
    x.event_id,
    x.event_name,
    x.stage_name,
    x.participant_name,
    x.lineup_rows,
    x.lineup_male,
    x.lineup_female,
    x.lineup_unusable_gender,
    ABS(x.lineup_male - x.lineup_female) AS gender_gap,
    NULL AS eligible_count
FROM (
    SELECT
        ep.id AS event_participants_id,
        e.id AS event_id,
        e.name AS event_name,
        ts.name AS stage_name,
        p.name AS participant_name,
        COUNT(l.id) AS lineup_rows,
        SUM(CASE WHEN LOWER(TRIM(lp.gender)) = 'male' THEN 1 ELSE 0 END) AS lineup_male,
        SUM(CASE WHEN LOWER(TRIM(lp.gender)) = 'female' THEN 1 ELSE 0 END) AS lineup_female,
        SUM(CASE WHEN lp.gender IS NULL
                   OR LOWER(TRIM(lp.gender)) NOT IN ('male', 'female') THEN 1 ELSE 0 END) AS lineup_unusable_gender
    FROM event_participants ep
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
         AND p.type = 'team' AND LOWER(TRIM(p.gender)) = 'mixed'
    JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN lineup l ON l.event_participantsFK = ep.id AND l.del = 'no'
    JOIN participant lp ON lp.id = l.participantFK AND lp.del = 'no'
    WHERE ep.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      -- AND tt.id = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY ep.id, e.id, e.name, ts.name, p.name
) x
WHERE x.lineup_male > 0
  AND x.lineup_female > 0
  AND x.lineup_male <> x.lineup_female

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT y.event_participants_id) AS eligible_count
FROM (
    SELECT
        ep.id AS event_participants_id,
        SUM(CASE WHEN LOWER(TRIM(lp.gender)) = 'male' THEN 1 ELSE 0 END) AS lineup_male,
        SUM(CASE WHEN LOWER(TRIM(lp.gender)) = 'female' THEN 1 ELSE 0 END) AS lineup_female
    FROM event_participants ep
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
         AND p.type = 'team' AND LOWER(TRIM(p.gender)) = 'mixed'
    JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN lineup l ON l.event_participantsFK = ep.id AND l.del = 'no'
    JOIN participant lp ON lp.id = l.participantFK AND lp.del = 'no'
    WHERE ep.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      -- AND tt.id = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY ep.id
) y
WHERE y.lineup_male > 0
  AND y.lineup_female > 0
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-068
    -- Name - EVENT_TEAM_LINEUP_SIZE_UNEVEN
    -- What it does: Finds active events in which the team event participants that resolve to a lineup do not all field the same number of members, so one team enters fewer competitors than another inside the same event, separating a shortfall of one member from a larger one, with the smallest and largest lineup, the number of teams measured and the per-team breakdown, together with a coverage count of all eligible events holding at least two team event participants that each resolve to at least one active lineup member.
    CASE
        WHEN x.max_size - x.min_size = 1 THEN 'EVENT_TEAM_LINEUP_SIZE_SHORT_BY_ONE'
        ELSE 'EVENT_TEAM_LINEUP_SIZE_SHORT_BY_MORE'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.stage_name,
    x.tournament_template_name,
    x.teams_measured,
    x.min_size,
    x.max_size,
    x.team_breakdown,
    NULL AS eligible_count,
    0 AS sort_order
FROM (
    SELECT
        b.event_id,
        b.event_name,
        b.stage_name,
        b.tournament_template_name,
        COUNT(*) AS teams_measured,
        MIN(b.lineup_rows) AS min_size,
        MAX(b.lineup_rows) AS max_size,
        GROUP_CONCAT(CONCAT(b.participant_name, '=', b.lineup_rows)
                     ORDER BY b.lineup_rows, b.participant_name SEPARATOR ' | ') AS team_breakdown
    FROM (
        SELECT
            e.id AS event_id,
            e.name AS event_name,
            ts.name AS stage_name,
            tt.name AS tournament_template_name,
            p.name AS participant_name,
            COUNT(l.id) AS lineup_rows
        FROM event_participants ep
        JOIN participant p ON p.id = ep.participantFK AND p.del = 'no' AND p.type = 'team'
        JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
        JOIN lineup l ON l.event_participantsFK = ep.id AND l.del = 'no'
        WHERE ep.del = 'no'
          AND tt.sportFK = {{SPORT_ID}}
          -- AND tt.id = <tournament_template_id>
          -- AND e.startdate >= '<from_datetime>'
          -- AND e.startdate <  '<to_datetime>'
        GROUP BY ep.id, e.id, e.name, ts.name, tt.name, p.name
    ) b
    GROUP BY b.event_id, b.event_name, b.stage_name, b.tournament_template_name
) x
WHERE x.teams_measured > 1
  AND x.max_size > x.min_size

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT y.event_id) AS eligible_count,
    1 AS sort_order
FROM (
    SELECT
        c.event_id,
        COUNT(*) AS teams_measured
    FROM (
        SELECT
            e.id AS event_id,
            ep.id AS event_participants_id
        FROM event_participants ep
        JOIN participant p ON p.id = ep.participantFK AND p.del = 'no' AND p.type = 'team'
        JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
        JOIN lineup l ON l.event_participantsFK = ep.id AND l.del = 'no'
        WHERE ep.del = 'no'
          AND tt.sportFK = {{SPORT_ID}}
          -- AND tt.id = <tournament_template_id>
          -- AND e.startdate >= '<from_datetime>'
          -- AND e.startdate <  '<to_datetime>'
        GROUP BY e.id, ep.id
    ) c
    GROUP BY c.event_id
) y
WHERE y.teams_measured > 1

ORDER BY sort_order, event_id;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-071
    -- Name - EVENT_NO_PARTICIPANTS
    -- What it does: Finds active events holding no active event-participant row at all, separating a finished event from one that has not finished, with the number of soft-deleted participant rows the event still carries and template, tournament, stage and status context, together with a coverage count of all eligible active events.
    CASE
        WHEN e.status_type = 'finished' AND e.status_descFK = 6 THEN 'NO_PARTICIPANTS_FINISHED_EVENT'
        ELSE 'NO_PARTICIPANTS_NOT_FINISHED_EVENT'
    END AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    tt.name AS template_name,
    t.name AS tournament_name,
    ts.name AS stage_name,
    e.status_type,
    e.status_descFK,
    -- An event whose entries were all soft-deleted is a different history from one that
    -- never had any, and the two are repaired differently, so the count is carried rather
    -- than left to a second query.
    (SELECT COUNT(*) FROM event_participants epd
      WHERE epd.eventFK = e.id AND epd.del = 'yes') AS deleted_participant_count,
    NULL AS eligible_count,
    0 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND NOT EXISTS (
      SELECT 1
      FROM event_participants ep
      WHERE ep.eventFK = e.id
        AND ep.del = 'no'
  )

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
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_startdate DESC;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-083
    -- Name - EVENT_PARTICIPANT_COUNT_NOT_TWO
    -- What it does: Finds active events of a head-to-head sport that hold participants but not exactly two, separating an event short of the pair from one holding more than two, with the participant count and template, tournament, stage and status context, together with a coverage count of all eligible active events holding at least one active participant.
    CASE
        WHEN x.participant_count < 2 THEN 'FEWER_THAN_TWO_PARTICIPANTS'
        ELSE 'MORE_THAN_TWO_PARTICIPANTS'
    END AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    tt.name AS template_name,
    t.name AS tournament_name,
    ts.name AS stage_name,
    e.status_type,
    x.participant_count,
    NULL AS eligible_count,
    0 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
-- The count is aggregated inside the sport's own hierarchy rather than over the whole
-- event_participants table, so the statement stays scoped the way WORKFLOW.md requires.
JOIN (
    SELECT ep.eventFK AS event_id, COUNT(*) AS participant_count
    FROM event_participants ep
    JOIN event e2 ON e2.id = ep.eventFK AND e2.del = 'no'
    JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
    JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
    JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
    WHERE ep.del = 'no'
      AND tt2.sportFK = {{SPORT_ID}}
    GROUP BY ep.eventFK
    HAVING COUNT(*) <> 2
) x ON x.event_id = e.id
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

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
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_startdate DESC;

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-104
    -- Name - EVENT_PARTICIPANT_REFERENCE_OR_TYPE_INVALID
    -- What it does: Finds active events of the selected sport holding an event-participant row whose participant is not an active participant at all, or whose participant type is not one of the types the sport is confirmed to field, separating a reference that resolves to nothing from one resolving to a participant of the wrong kind, with the offending types and the stage name context, together with a coverage count of all eligible events holding at least one active event-participant row.
    CASE
        WHEN x.reference_missing_count > 0 THEN 'EVENT_PARTICIPANT_REFERENCE_MISSING'
        ELSE 'EVENT_PARTICIPANT_TYPE_OUTSIDE_SPORT_SET'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.tournament_stage_name,
    x.offending_row_count,
    x.offending_types,
    NULL AS eligible_count,
    0 AS sort_order
-- EVENT_PARTICIPANT_TYPE_LIST is declared for every documented sport, but until now it was
-- only ever a scope filter - GLOBAL-DQ-007 and -008 use it to decide which participants to
-- look at. Filtering on a value never tests it: a participant of the wrong kind leaves the
-- population silently, which is the opposite of being reported. This asserts the same list
-- the other checks trust.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        ts.name AS tournament_stage_name,
        COUNT(*) AS offending_row_count,
        SUM(CASE WHEN p.id IS NULL THEN 1 ELSE 0 END) AS reference_missing_count,
        SUBSTRING(GROUP_CONCAT(DISTINCT COALESCE(p.type, 'none') ORDER BY p.type SEPARATOR ', '), 1, 80) AS offending_types
    FROM event_participants ep
    JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = {{SPORT_ID}}
    LEFT JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
    WHERE ep.del = 'no'
      -- AND tt.id = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
      AND (p.id IS NULL OR p.type NOT IN ({{EVENT_PARTICIPANT_TYPE_LIST}}))
    GROUP BY e.id, e.name, ts.name
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event_participants ep
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = {{SPORT_ID}}
WHERE ep.del = 'no'
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_id;

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-112
    -- Name - EVENT_LINEUP_ATHLETE_ASSIGNED_MORE_THAN_ONCE
    -- What it does: Finds active events of the selected sport where one athlete is listed more than once across the event's active lineups, either repeated inside a single team's lineup or held by two teams at the same time, so one competitor occupies two places in one event, with the number of athletes affected and the number of teams involved and a sample and the stage name context, together with a coverage count of all eligible events holding at least one active lineup row.
    CASE
        WHEN x.max_teams_holding > 1 THEN 'LINEUP_ATHLETE_IN_TWO_TEAMS'
        ELSE 'LINEUP_ATHLETE_REPEATED_IN_ONE_TEAM'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.tournament_stage_name,
    x.affected_athletes,
    x.sample_athlete,
    NULL AS eligible_count,
    0 AS sort_order
-- The two shapes are one question asked of the same row set, so they share a CheckID and
-- separate by check_type. They are not equally serious and the distinction is the point: a
-- repeated row inside one lineup is redundant storage, while an athlete held by two teams in
-- the same event changes which team fielded whom and therefore what the result means.
-- Eligibility is events holding a lineup at all. A sport that uses lineups thinly - and this
-- one does, over about a hundred events - gets a small coverage count, and that number is
-- itself the thing to read before any finding count is interpreted.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        ts.name AS tournament_stage_name,
        COUNT(*) AS affected_athletes,
        MAX(g.teams_holding) AS max_teams_holding,
        MIN(CONCAT('athlete=', g.participantFK,
                   ' rows=', g.lineup_rows,
                   ' teams=', g.teams_holding)) AS sample_athlete
    FROM (
        SELECT
            ep.eventFK AS event_id,
            l.participantFK,
            COUNT(*) AS lineup_rows,
            COUNT(DISTINCT ep.id) AS teams_holding
        FROM lineup l
        JOIN event_participants ep ON ep.id = l.event_participantsFK AND ep.del = 'no'
        JOIN event e2 ON e2.id = ep.eventFK AND e2.del = 'no'
        JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
        JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
        JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
             AND tt2.sportFK = {{SPORT_ID}}
        WHERE l.del = 'no'
          -- AND tt2.id = <tournament_template_id>
          -- AND e2.startdate >= '<from_datetime>'
          -- AND e2.startdate <  '<to_datetime>'
        GROUP BY ep.eventFK, l.participantFK
        HAVING COUNT(*) > 1
    ) g
    JOIN event e ON e.id = g.event_id AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    GROUP BY e.id, e.name, ts.name
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = {{SPORT_ID}}
WHERE e.del = 'no'
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND EXISTS (
      SELECT 1
      FROM event_participants ep3
      JOIN lineup l3 ON l3.event_participantsFK = ep3.id AND l3.del = 'no'
      WHERE ep3.eventFK = e.id AND ep3.del = 'no'
  )

ORDER BY sort_order, event_id;
