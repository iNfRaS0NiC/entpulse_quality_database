SELECT
    -- CheckID - GLOBAL-DQ-007
    -- Name - PARTICIPANT_MISSING_DATE_OF_BIRTH
    -- What it does: Flags athletes with no date of birth.
    'Missing_DOB' AS check_type,
    x.participant_id,
    x.participant_name,
    x.participant_type,
    (
        SELECT c.name
-- What it does, stated in full: Finds people carrying no date_of_birth, reached either
-- through the sport registry or through any of the three participation paths: an event
-- participant row, a lineup place or a Comp.Rank row.
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
          AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
          -- AND t.tournament_templateFK = <tournament_template_id>

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
          AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
          -- AND t.tournament_templateFK = <tournament_template_id>

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
          AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
          -- AND t.tournament_templateFK = <tournament_template_id>

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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
      -- AND t.tournament_templateFK = <tournament_template_id>

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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
      -- AND t.tournament_templateFK = <tournament_template_id>

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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
      -- AND t.tournament_templateFK = <tournament_template_id>

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
    -- What it does: Flags active event participants missing a name or country, or people missing a first name or last name.
    'Missing_Profile_Field' AS check_type,
    p.id AS participant_id,
    p.name AS participant_name,
    p.type AS participant_type,
    (
        SELECT c.name
-- What it does, stated in full: Finds participants taking part in at least one event that
-- are missing a name or a country, or - for people only - a first or last name.
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
        AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
        AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
        -- AND t.tournament_templateFK = <tournament_template_id>
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
        AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
        AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
        -- AND t.tournament_templateFK = <tournament_template_id>
  );


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-009
    -- Name - PARTICIPANT_NO_PARTICIPATION_ANYWHERE
    -- What it does: Flags registered participants who never appear as an event participant, lineup member, or Comp.Rank participant.
    'No_Participation_Anywhere' AS check_type,
    p.id AS participant_id,
    p.name AS participant_name,
    p.type AS participant_type,
    op.active AS registry_active_flag,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds registered participants that take no part in the sport
-- by any of the three paths open to them: an event participant row, a lineup place or a
-- Comp.Rank row.
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
    -- What it does: Finds team lineups whose members do not match the team's gender.
    CASE
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
    x.event_startdate,
    x.stage_name,
    x.stage_gender,
    x.participant_type,
    x.participant_name,
    x.participant_gender,
    x.lineup_male,
    x.lineup_female,
    x.offending_members,
    x.non_competing_members,
    NULL AS eligible_count
-- What it does, stated in full: Finds event participants whose own lineup contradicts their
-- gender: a mixed team whose lineup misses a gender, or a single-gender team holding the
-- other.
-- A lineup belongs to the entry rather than to the team, so a team fielding an incomplete
-- lineup in twelve events has twelve lineups to repair and the event participant is the right
-- object here. The contradiction between a participant's stored gender and the stage it was
-- entered in is not: that is one column on one participant record, repeated once per entry,
-- and it moved to GLOBAL-DQ-123 on 2026-08-12.
-- **Only the people who compete are counted.** A lineup holds more than the team: Ice Hockey
-- enters coaches through lineup type 10, and a women's team with a male coach is not a women's
-- team holding a man. Until 2026-08-20 this counted every lineup row by gender, and measured
-- that day all 320 of Ice Hockey's findings were that and nothing else - not one survived when
-- the count was restricted to athletes. A check whose entire output is one legitimate practice
-- is not reporting a defect, it is reporting the practice.
-- The types that count are PERSON_PARTICIPANT_TYPE_LIST, which every documented sport declares
-- as 'athlete'. The rest are still projected, in non_competing_members, because an exemption
-- nobody can see is indistinguishable from a check that stopped looking.
FROM (
    SELECT
        ep.id AS event_participants_id,
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        ts.name AS stage_name,
        LOWER(TRIM(ts.gender)) AS stage_gender,
        p.name AS participant_name,
        p.type AS participant_type,
        LOWER(TRIM(p.gender)) AS participant_gender,
        COUNT(CASE WHEN lp.type IN ({{PERSON_PARTICIPANT_TYPE_LIST}}) THEN l.id END) AS lineup_rows,
        SUM(CASE WHEN lp.type IN ({{PERSON_PARTICIPANT_TYPE_LIST}})
                  AND LOWER(TRIM(lp.gender)) = 'male' THEN 1 ELSE 0 END) AS lineup_male,
        SUM(CASE WHEN lp.type IN ({{PERSON_PARTICIPANT_TYPE_LIST}})
                  AND LOWER(TRIM(lp.gender)) = 'female' THEN 1 ELSE 0 END) AS lineup_female,
        -- Who they are, so the row is read without a second query. Empty for a mixed team
        -- missing a gender, where the finding is an absence and the counts are what say so.
        SUBSTRING(GROUP_CONCAT(DISTINCT CASE
            WHEN lp.type IN ({{PERSON_PARTICIPANT_TYPE_LIST}})
             AND LOWER(TRIM(p.gender)) IN ('male', 'female')
             AND LOWER(TRIM(lp.gender)) IN ('male', 'female')
             AND LOWER(TRIM(lp.gender)) <> LOWER(TRIM(p.gender))
            THEN CONCAT(lp.name, ' (', lp.id, ', ', LOWER(TRIM(lp.gender)), ')')
        END SEPARATOR ' | '), 1, 300) AS offending_members,
        -- And who was deliberately not counted, so the exemption is visible rather than silent.
        SUBSTRING(GROUP_CONCAT(DISTINCT CASE
            WHEN lp.id IS NOT NULL AND lp.type NOT IN ({{PERSON_PARTICIPANT_TYPE_LIST}})
            THEN CONCAT(lp.name, ' (', lp.type, ')')
        END SEPARATOR ' | '), 1, 200) AS non_competing_members
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY ep.id, e.id, e.name, e.startdate, ts.name, ts.gender, p.name, p.type, p.gender
) x
WHERE
    (x.participant_type = 'team' AND x.participant_gender = 'mixed'
     AND x.lineup_rows > 0 AND (x.lineup_male = 0 OR x.lineup_female = 0))
    OR (x.participant_type = 'team' AND x.participant_gender = 'male'
     AND x.lineup_rows > 0 AND x.lineup_female > 0)
    OR (x.participant_type = 'team' AND x.participant_gender = 'female'
     AND x.lineup_rows > 0 AND x.lineup_male > 0)

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-058
    -- Name - EVENT_TEAM_PARTICIPANT_WITHOUT_LINEUP
    -- What it does: Flags team events where all or some teams have no lineup.
    CASE
        WHEN x.teams_with_lineup = 0 THEN 'EVENT_NO_TEAM_HAS_LINEUP'
        ELSE 'EVENT_SOME_TEAMS_MISSING_LINEUP'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.tournament_template_name,
    x.team_count,
    x.teams_with_lineup,
    x.team_count - x.teams_with_lineup AS teams_without_lineup,
    x.teams_missing_lineup_names,
    NULL AS eligible_count
-- What it does, stated in full: Finds events whose team participants reach no lineup,
-- separating an event where no team does from one where only some do.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY e.id, e.name, e.startdate, tt.name
) x
WHERE x.teams_with_lineup < x.team_count

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-067
    -- Name - EVENT_MIXED_TEAM_LINEUP_GENDER_BALANCE_UNEVEN
    -- What it does: Flags mixed teams with unequal numbers of male and female lineup members.
    'MIXED_TEAM_LINEUP_GENDER_COUNT_UNEVEN' AS check_type,
    x.event_participants_id,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.stage_name,
    x.participant_name,
    x.lineup_rows,
    x.lineup_male,
    x.lineup_female,
    x.lineup_unusable_gender,
    ABS(x.lineup_male - x.lineup_female) AS gender_gap,
    NULL AS eligible_count
-- What it does, stated in full: Finds mixed-gender teams whose lineup holds male and female
-- members in unequal numbers.
FROM (
    SELECT
        ep.id AS event_participants_id,
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY ep.id, e.id, e.name, e.startdate, ts.name, p.name
) x
WHERE x.lineup_male > 0
  AND x.lineup_female > 0
  AND x.lineup_male <> x.lineup_female

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
      -- AND t.tournament_templateFK = <tournament_template_id>
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
    -- What it does: Flags team events where the teams have different lineup sizes.
    CASE
        WHEN x.max_size - x.min_size = 1 THEN 'EVENT_TEAM_LINEUP_SIZE_SHORT_BY_ONE'
        ELSE 'EVENT_TEAM_LINEUP_SIZE_SHORT_BY_MORE'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.stage_name,
    x.tournament_template_name,
    x.teams_measured,
    x.min_size,
    x.max_size,
    x.team_breakdown,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds events whose teams do not all field the same number of
-- lineup members, separating a shortfall of one member from a larger one.
FROM (
    SELECT
        b.event_id,
        b.event_name,
        b.event_startdate,
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
            e.startdate AS event_startdate,
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
          AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
          -- AND t.tournament_templateFK = <tournament_template_id>
          -- AND e.startdate >= '<from_datetime>'
          -- AND e.startdate <  '<to_datetime>'
        GROUP BY ep.id, e.id, e.name, e.startdate, ts.name, tt.name, p.name
    ) b
    GROUP BY b.event_id, b.event_name, b.event_startdate, b.stage_name, b.tournament_template_name
) x
WHERE x.teams_measured > 1
  AND x.max_size > x.min_size

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
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
          AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
          -- AND t.tournament_templateFK = <tournament_template_id>
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
    -- What it does: Finds events with no active participants.
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
-- What it does, stated in full: Finds events holding no participant at all, separating a
-- finished event from an unfinished one, with the soft-deleted participant rows it still
-- carries.
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
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
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_startdate DESC;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-083
    -- Name - EVENT_PARTICIPANT_COUNT_NOT_A_FIELD_THE_SPORT_ENTERS
    -- What it does: Flags head-to-head events holding a number of participants the sport never fields.
    CASE
        WHEN x.participant_count < 2 THEN 'FEWER_THAN_TWO_PARTICIPANTS'
        ELSE 'PARTICIPANT_COUNT_NOT_A_FIELD_THE_SPORT_ENTERS'
    END AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    e.startdate AS event_startdate,
    tt.name AS template_name,
    t.name AS tournament_name,
    ts.name AS stage_name,
    e.status_type,
    x.participant_count,
    x.participants,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds head-to-head events holding a number of participants
-- that the sport does not field, separating a contest with fewer than two sides from one whose
-- field size is simply not one the sport enters.
-- **Two is not the only right answer, and this asserted it was until 2026-08-20.** A doubles
-- sport enters the four players rather than two pairs: measured that day, Badminton holds 48072
-- events with four participants against 40951 with two, so more of its events are doubles than
-- singles, and Table Tennis holds 7788 against 55314. Asserting exactly two would have reported
-- every one of them. The legitimate sizes are named in EVENT_PARTICIPANT_COUNT_LIST, which for a
-- sport that only ever fields a pair is simply 2 and leaves the check exactly as it was.
-- What survives the widening is what the check was always for. Badminton keeps 12 events on
-- three participants and Table Tennis 31 on one, 6 on three and 3 on six - a missing opponent
-- or an entry made twice, in a sport that fields neither of those numbers.
-- Fewer than two is kept as its own branch because it is true in any sport whatever the list
-- says: a contest needs two sides before it needs the right number of them.
-- Who they are is projected beside how many, because the two failures read completely
-- differently and the count alone cannot tell them apart. One participant means the opponent
-- was never entered and the row says which side is present; three or more usually means one
-- side was entered twice, and seeing the same name twice in the list is the whole diagnosis.
-- The name carries its participant id and its type - a type the sport does not field is
-- GLOBAL-DQ-104's finding rather than this one's, but it shows here first. Added 2026-08-20.
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
-- The count is aggregated inside the sport's own hierarchy rather than over the whole
-- event_participants table, so the statement stays scoped the way WORKFLOW.md requires.
JOIN (
    SELECT
        ep.eventFK AS event_id,
        COUNT(*) AS participant_count,
        SUBSTRING(GROUP_CONCAT(
            CONCAT(COALESCE(p.name, CONCAT('participant ', ep.participantFK)),
                   ' (', ep.participantFK, ', ', COALESCE(p.type, 'unresolved'), ')')
            ORDER BY p.name SEPARATOR ' | '), 1, 300) AS participants
    FROM event_participants ep
    LEFT JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
    JOIN event e2 ON e2.id = ep.eventFK AND e2.del = 'no'
    JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
    JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
    JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
    WHERE ep.del = 'no'
      AND tt2.sportFK = {{SPORT_ID}}
    GROUP BY ep.eventFK
    HAVING COUNT(*) NOT IN ({{EVENT_PARTICIPANT_COUNT_LIST}})
) x ON x.event_id = e.id
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

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
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_startdate DESC;

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-104
    -- Name - EVENT_PARTICIPANT_REFERENCE_OR_TYPE_INVALID
    -- What it does: Flags event-participant rows that point to no participant or to a participant type not used by the sport.
    CASE
        WHEN x.reference_missing_count > 0 THEN 'EVENT_PARTICIPANT_REFERENCE_MISSING'
        ELSE 'EVENT_PARTICIPANT_TYPE_OUTSIDE_SPORT_SET'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.tournament_stage_name,
    x.offending_row_count,
    x.offending_types,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds events holding a participant row that resolves to
-- nothing, or to a participant of a type the sport does not field, separating the two.
-- EVENT_PARTICIPANT_TYPE_LIST is declared for every documented sport, but until now it was
-- only ever a scope filter - GLOBAL-DQ-007 and -008 use it to decide which participants to
-- look at. Filtering on a value never tests it: a participant of the wrong kind leaves the
-- population silently, which is the opposite of being reported. This asserts the same list
-- the other checks trust.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
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
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
      AND (p.id IS NULL OR p.type NOT IN ({{EVENT_PARTICIPANT_TYPE_LIST}}))
    GROUP BY e.id, e.name, e.startdate, ts.name
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event_participants ep
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = {{SPORT_ID}}
WHERE ep.del = 'no'
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_id;

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-112
    -- Name - EVENT_LINEUP_ATHLETE_ASSIGNED_MORE_THAN_ONCE
    -- What it does: Flags athletes listed twice in team lineups, either within one team or across two teams in the same event.
    CASE
        WHEN x.max_teams_holding > 1 THEN 'LINEUP_ATHLETE_IN_TWO_TEAMS'
        ELSE 'LINEUP_ATHLETE_REPEATED_IN_ONE_TEAM'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.tournament_stage_name,
    x.affected_athletes,
    x.affected_athlete_detail,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds events where one athlete occupies two places at once,
-- repeated inside a single team's lineup or held by two teams, naming every affected athlete
-- and the teams holding them.
-- The two shapes are one question asked of the same row set, so they share a CheckID and
-- separate by check_type. They are not equally serious and the distinction is the point: a
-- repeated row inside one lineup is redundant storage, while an athlete held by two teams in
-- the same event changes which team fielded whom and therefore what the result means.
-- Eligibility is events holding a lineup at all. A sport that uses lineups thinly - and this
-- one does, over about a hundred events - gets a small coverage count, and that number is
-- itself the thing to read before any finding count is interpreted.
-- The detail column names the athlete and the teams rather than only the id, because the id
-- alone cannot be read: the shape this check most often finds is one participant record
-- standing for two different people, and it is the two team names beside the name that say so.
-- The lookups sit above the grouped set, so they run once per finding and never touch the scan.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        ts.name AS tournament_stage_name,
        COUNT(*) AS affected_athletes,
        MAX(ga.teams_holding) AS max_teams_holding,
        GROUP_CONCAT(CONCAT(COALESCE(ga.athlete_name, CONCAT('participantFK=', ga.participantFK)),
                            ' (id=', ga.participantFK, ')',
                            ' rows=', ga.lineup_rows,
                            ' teams=', ga.teams_holding,
                            ': ', COALESCE(ga.team_names, '(team name unavailable)'))
                     ORDER BY ga.participantFK SEPARATOR ' | ') AS affected_athlete_detail
    FROM (
        SELECT
            g.event_id,
            g.participantFK,
            g.lineup_rows,
            g.teams_holding,
            pa.name AS athlete_name,
            (SELECT GROUP_CONCAT(DISTINCT tp.name ORDER BY tp.name SEPARATOR ', ')
             FROM event_participants ep4
             JOIN lineup l4 ON l4.event_participantsFK = ep4.id AND l4.del = 'no'
                  AND l4.participantFK = g.participantFK
             LEFT JOIN participant tp ON tp.id = ep4.participantFK
             WHERE ep4.eventFK = g.event_id AND ep4.del = 'no') AS team_names
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
              AND t2.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
              AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
              -- AND t2.tournament_templateFK = <tournament_template_id>
              -- AND e2.startdate >= '<from_datetime>'
              -- AND e2.startdate <  '<to_datetime>'
            GROUP BY ep.eventFK, l.participantFK
            HAVING COUNT(*) > 1
        ) g
        LEFT JOIN participant pa ON pa.id = g.participantFK
    ) ga
    JOIN event e ON e.id = ga.event_id AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    GROUP BY e.id, e.name, e.startdate, ts.name
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = {{SPORT_ID}}
WHERE e.del = 'no'
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND EXISTS (
      SELECT 1
      FROM event_participants ep3
      JOIN lineup l3 ON l3.event_participantsFK = ep3.id AND l3.del = 'no'
      WHERE ep3.eventFK = e.id AND ep3.del = 'no'
  )

ORDER BY sort_order, event_id;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DQ-123
    -- Name - PARTICIPANT_GENDER_CONTRADICTS_STAGE_ENTERED
    -- What it does: Flags participants whose stored gender conflicts with the gender of a stage they entered.
    CASE
        WHEN x.participant_type = 'athlete' THEN 'ATHLETE_GENDER_NOT_STAGE_GENDER'
        ELSE 'TEAM_GENDER_NOT_STAGE_GENDER'
    END AS check_type,
    x.participant_id,
    x.participant_name,
    x.participant_type,
    x.participant_gender,
    x.stage_genders,
    x.entry_count,
    x.example_event_id,
    x.events_entered,
    NULL AS eligible_count
-- What it does, stated in full: Finds participants whose stored gender contradicts a stage
-- they were entered in, naming how many entries repeat the contradiction and which stage
-- genders they sit under.
FROM (
    -- The participant is the audited object, not the entry. Gender is one column on one
    -- participant row, so a team recorded as male and entered in ten mixed stages is one
    -- field to repair and was reported as ten - measured on Modern Pentathlon, 154 rows over
    -- 60 participant records. entry_count carries how far the same contradiction reaches.
    -- Split from GLOBAL-DQ-043 on 2026-08-12, which keeps the lineup contradictions because
    -- a lineup belongs to the entry and is genuinely repaired one entry at a time.
    SELECT
        p.id AS participant_id,
        p.name AS participant_name,
        p.type AS participant_type,
        LOWER(TRIM(p.gender)) AS participant_gender,
        GROUP_CONCAT(DISTINCT LOWER(TRIM(ts.gender))
                     ORDER BY LOWER(TRIM(ts.gender)) SEPARATOR ', ') AS stage_genders,
        COUNT(DISTINCT ep.id) AS entry_count,
        MIN(e.id) AS example_event_id,
        -- Every event the contradiction reaches, asked for by the reviewers on
        -- 2026-08-19: one example told them the participant was wrong and nothing
        -- about how far it went. example_event_id stays because a reviewer's note is
        -- keyed on the columns whose names end in _id, and dropping it would unhook
        -- every note already written against these rows.
        -- A convenience for the reader, not the finding: GROUP_CONCAT truncates at the
        -- server's group_concat_max_len without saying so, and entry_count is what the
        -- row asserts. No DISTINCT, so the list is as long as entry_count and an event
        -- entered twice says so.
        GROUP_CONCAT(CONCAT(DATE(e.startdate), ' ', e.id)
                     ORDER BY e.startdate, e.id SEPARATOR ' | ') AS events_entered
    FROM event_participants ep
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
    JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    WHERE ep.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      AND p.type IN ('athlete', 'team')
      AND ts.gender IS NOT NULL
      AND TRIM(ts.gender) <> ''
      AND LOWER(TRIM(ts.gender)) <> 'undefined'
      AND p.gender IS NOT NULL
      AND TRIM(p.gender) <> ''
      AND LOWER(TRIM(p.gender)) <> LOWER(TRIM(ts.gender))
      -- An athlete under a mixed stage is not a contradiction: a mixed stage is contested by
      -- both genders. A team is, because a team entity carries the gender of the squad it
      -- fields, and a mixed stage is contested by teams recorded as mixed.
      AND (p.type <> 'athlete' OR LOWER(TRIM(ts.gender)) <> 'mixed')
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY p.id, p.name, p.type, LOWER(TRIM(p.gender))
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT p.id) AS eligible_count
FROM event_participants ep
JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE ep.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND p.type IN ('athlete', 'team')
  AND ts.gender IS NOT NULL
  AND TRIM(ts.gender) <> ''
  AND LOWER(TRIM(ts.gender)) <> 'undefined'
  AND p.gender IS NOT NULL
  AND TRIM(p.gender) <> ''
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-129
    -- Name - EVENT_PARTICIPANT_TYPE_MIXED
    -- What it does: Flags events that enter participants of more than one kind, such as a team against an individual.
    'Event_Participant_Type_Mixed' AS check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.template_name,
    x.tournament_name,
    x.types_held,
    x.distinct_types,
    x.field_size,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds an event whose field holds competitors of more than one
-- kind, so one contest is between a team and an individual.
-- This is GLOBAL-DQ-113 asked one layer down. That one reads the Comp.Rank statistic and asks
-- whether one place sequence ranks teams against individuals; this one reads the event and asks
-- whether one race did. The two are not each other: a sport can rank correctly and field wrongly,
-- and the statistic layer does not exist for every sport that holds events. Nothing else asks it -
-- GLOBAL-DQ-104 asks whether a participant type belongs to the sport vocabulary at all, which is
-- a different question and passes an event that mixes two legitimate types.
-- Asked without naming which kinds are legitimate, which is what keeps it global. A sport
-- fielding both teams and individuals is entirely normal - Swimming swims relays and individual
-- events under one template - and what is not normal is one event holding both.
-- **A person is a person whichever role they hold now.** The person types are collapsed through
-- PERSON_ROLE_TYPE_LIST for the reason GLOBAL-DQ-113 records at length: participant.type carries
-- a person's *current* role and not the one they held at the event, so a squad entered in 2004
-- whose players have since become coaches reads as two kinds and is one. Collapsing them leaves
-- team against athlete, and horse against athlete, exactly where they were. The types actually
-- stored are still projected, so nothing is hidden - only the count is corrected.
-- The audited object is the event, and field_size travels with it because the two shapes want
-- different repairs: one stray entry in a field of eight is a wrong participant, and a field
-- evenly split is a whole event entered at the wrong level.
-- Measured 2026-08-21 over the seven documented sports that field more than one kind at all:
-- Cycling holds 14 events, every one of them a team beside an athlete, and Golf, Equestrian,
-- Swimming, Triathlon, Artistic Gymnastics and Modern Pentathlon hold none.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        tt.name AS template_name,
        t.name AS tournament_name,
        COUNT(DISTINCT ep.id) AS field_size,
        COUNT(DISTINCT CASE WHEN p.type IN ({{PERSON_ROLE_TYPE_LIST}})
                            THEN 'person' ELSE p.type END) AS distinct_types,
        SUBSTRING(GROUP_CONCAT(DISTINCT p.type ORDER BY p.type SEPARATOR ', '), 1, 60) AS types_held
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
    WHERE e.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY e.id, e.name, e.startdate, tt.name, t.name
    HAVING COUNT(DISTINCT CASE WHEN p.type IN ({{PERSON_ROLE_TYPE_LIST}})
                               THEN 'person' ELSE p.type END) > 1
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
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_startdate DESC, event_id;

-- ======================================================================================

SELECT
    -- CheckID - GLOBAL-DQ-130
    -- Name - EVENT_PARTICIPANT_ORGANIZATION_MISSING
    -- What it does: Finds tournaments whose event participants carry no organization, either none of them at all or only some.
    CASE
        WHEN x.with_organization = 0 THEN 'TOURNAMENT_CARRIES_NO_ORGANIZATION_AT_ALL'
        ELSE 'TOURNAMENT_ORGANIZATION_PARTLY_FILLED'
    END AS check_type,
    x.tournament_id,
    x.tournament_name,
    x.template_name,
    x.participations,
    x.with_organization,
    x.without_organization,
    x.first_event_date,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Every competitor entered into an event is supposed to carry the
-- organization it competes for, and this finds where none does.
-- The organization is a reference-typed property on `event_participants` - `name` is
-- `organizationFK`, `type` is `ref:participant` and `value` holds a `participant.id`, the
-- mechanism DATABASE.md describes under "Reference-typed properties". The name is not
-- parameterised because there is nothing to choose between: measured 2026-08-21 across the whole
-- database, 24 sports carry such a property and every one of them spells it `organizationFK`,
-- with no second spelling anywhere. A sport that ever adopts another spelling reads here as
-- carrying none, which is the safe direction for this check to fail in.
-- **An unfilled organization is a defect, not an inapplicable check.** Most sports fill none of
-- it, and that is what this exists to report rather than a reason to switch it off. The
-- structure is present everywhere the property table is, and Artistic Gymnastics and Triathlon
-- fill it, so nothing about any other sport makes the rule inapplicable there. Recording an
-- empty population as `Not applicable` or `Monitor` would disable the check for exactly the
-- sports it was written for. Measured 2026-08-21 over the eleven documented sports inside the
-- client boundary: about 7.4 million participations of 7.75 million carry no organization, and
-- seven of the eleven carry not one.
-- The value shape is not tested and does not need to be. Where the property exists it always
-- holds something - 0 of the 319 000 rows in the database are empty, blank or zero - so the
-- defect is the absent row and nothing else. Whether the id it holds resolves to a live
-- participant of the right type is `GLOBAL-DQ-104`'s kind of question and is left there.
-- **The audited object is the tournament**, decided 2026-08-21 and not the participation the
-- rule is stated about. A feed either supplies the organization for a competition or it does
-- not, so the correction is made a tournament at a time; reported per participation the same
-- missing feed field would be counted four million times in Soccer alone, which the
-- audited-object rule exists to prevent. `participations`, `with_organization` and
-- `without_organization` carry the proportion as named secondary columns.
-- The two branches want different work and are separated for that reason. A tournament carrying
-- none at all is a feed that never sent the field. A tournament carrying some is a feed that
-- sends it and dropped part of the field, which is the harder defect to see and the one nobody
-- would find by looking at a sport total: Artistic Gymnastics and Triathlon are the only two
-- sports where it occurs, and they are also the only two where the total looks healthy.
FROM (
    SELECT
        t.id AS tournament_id,
        t.name AS tournament_name,
        tt.name AS template_name,
        COUNT(*) AS participations,
        SUM(CASE WHEN og.id IS NOT NULL THEN 1 ELSE 0 END) AS with_organization,
        SUM(CASE WHEN og.id IS NULL THEN 1 ELSE 0 END) AS without_organization,
        MIN(e.startdate) AS first_event_date
    FROM event_participants ep
    JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    LEFT JOIN property og ON og.object = 'event_participants'
                         AND og.objectFK = ep.id
                         AND og.name = 'organizationFK'
                         AND og.del = 'no'
    WHERE ep.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY t.id, t.name, tt.name
    HAVING SUM(CASE WHEN og.id IS NULL THEN 1 ELSE 0 END) > 0
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT t.id) AS eligible_count,
    1 AS sort_order
FROM event_participants ep
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE ep.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  AND t.tournament_templateFK NOT IN ({{OUT_OF_SCOPE_TEMPLATE_ID_LIST}})
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= {{CLIENT_FROM_SEASON}}
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, without_organization DESC, tournament_id;
