SELECT
    -- CheckID - GLOBAL-DISCOVERY-004
    -- Name - EVENT_PARTICIPANT_TYPES_GENDERS
    -- What it does: Lists participant types and genders used by active event participants in the selected sport.
    p.type AS participant_type,
    p.gender AS participant_gender,
    COUNT(DISTINCT p.id) AS participant_count,
    COUNT(DISTINCT ep.id) AS event_participation_count,
    MIN(p.id) AS sample_participant_id,
    MIN(p.name) AS sample_participant_name
FROM event_participants ep
JOIN participant p
  ON p.id = ep.participantFK
 AND p.del = 'no'
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
WHERE ep.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND t.tournament_templateFK = <tournament_template_id>
GROUP BY
    p.type,
    p.gender
ORDER BY
    event_participation_count DESC,
    p.type,
    p.gender;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DISCOVERY-005
    -- Name - LINEUP_TYPES_PARTICIPANT_TYPES
    -- What it does: Lists active lineup types and member participant types and genders used in the selected sport.
    l.lineup_typeFK AS lineup_type_id,
    lt.name AS lineup_type_name,
    parent_p.type AS parent_event_participant_type,
    member_p.type AS lineup_member_type,
    member_p.gender AS lineup_member_gender,
    COUNT(DISTINCT l.id) AS lineup_row_count,
    COUNT(DISTINCT member_p.id) AS member_count
FROM lineup l
JOIN event_participants ep
  ON ep.id = l.event_participantsFK
 AND ep.del = 'no'
JOIN participant parent_p
  ON parent_p.id = ep.participantFK
 AND parent_p.del = 'no'
JOIN participant member_p
  ON member_p.id = l.participantFK
 AND member_p.del = 'no'
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
LEFT JOIN lineup_type lt
  ON lt.id = l.lineup_typeFK
WHERE l.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND t.tournament_templateFK = <tournament_template_id>
GROUP BY
    l.lineup_typeFK,
    lt.name,
    parent_p.type,
    member_p.type,
    member_p.gender
ORDER BY
    lineup_row_count DESC,
    l.lineup_typeFK,
    member_p.type,
    member_p.gender;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DISCOVERY-006
    -- Name - SPORT_REGISTRY_PARTICIPANT_TYPES
    -- What it does: Lists participant roles, types, genders and active flags stored in the selected sport's object_participants registry.
    op.participant_type AS registry_participant_role,
    op.active AS registry_active_flag,
    p.type AS participant_type,
    p.gender AS participant_gender,
    COUNT(DISTINCT op.id) AS registry_row_count,
    COUNT(DISTINCT p.id) AS participant_count,
    MIN(p.id) AS sample_participant_id,
    MIN(p.name) AS sample_participant_name
FROM object_participants op
JOIN participant p
  ON p.id = op.participantFK
 AND p.del = 'no'
WHERE op.object = 'sport'
  AND op.objectFK = {{SPORT_ID}}
  AND op.del = 'no'
GROUP BY
    op.participant_type,
    op.active,
    p.type,
    p.gender
ORDER BY
    registry_row_count DESC,
    op.participant_type,
    p.type,
    p.gender;

-- ==============================================================================
SELECT
    -- CheckID - GLOBAL-DISCOVERY-033
    -- Name - PARTICIPANT_DUPLICATE_CANDIDATES_BY_NAME
    -- What it does: Groups a sport's registered people whose names hold the same parts in any order, and reports each group's dates of birth and how much history every record carries, so a duplicate can be told from a namesake and a merge aimed at the record worth keeping.
    CASE
        WHEN y.people_with_dob = 0 THEN 'NO_DOB_EITHER_SIDE'
        WHEN y.distinct_dobs > 1 THEN 'DOB_CONFLICT'
        WHEN y.people_with_dob < y.people THEN 'DOB_ON_ONE_SIDE_ONLY'
        ELSE 'DOB_MATCH'
    END AS match_class,
    CASE WHEN y.distinct_raw_names > 1 THEN 'YES' ELSE 'no' END AS name_order_differs,
    y.name_key,
    y.names_seen,
    y.people,
    y.id_and_appearances,
    y.busiest_appearances,
    y.people_never_seen,
    y.dobs_seen,
    y.people_with_dob,
    y.distinct_countries,
    y.genders
FROM (
    SELECT
        x.name_key,
        COUNT(*) AS people,
        COUNT(DISTINCT x.participant_name) AS distinct_raw_names,
        GROUP_CONCAT(DISTINCT x.participant_name ORDER BY x.participant_name SEPARATOR ' | ') AS names_seen,
        -- Each id with what it would cost to lose it. A merge goes towards the record holding
        -- the history, and the empty one beside it is what somebody entered twice.
        GROUP_CONCAT(CONCAT(x.participant_id, ' (', x.appearances, ')')
            ORDER BY x.appearances DESC, x.participant_id SEPARATOR ' | ') AS id_and_appearances,
        MAX(x.appearances) AS busiest_appearances,
        SUM(CASE WHEN x.appearances = 0 THEN 1 ELSE 0 END) AS people_never_seen,
        GROUP_CONCAT(DISTINCT x.date_of_birth ORDER BY x.date_of_birth SEPARATOR ' | ') AS dobs_seen,
        COUNT(x.date_of_birth) AS people_with_dob,
        COUNT(DISTINCT x.date_of_birth) AS distinct_dobs,
        COUNT(DISTINCT x.countryFK) AS distinct_countries,
        GROUP_CONCAT(DISTINCT x.gender ORDER BY x.gender SEPARATOR ' | ') AS genders
    FROM (
        SELECT
            w.participant_id,
            w.participant_name,
            w.countryFK,
            w.gender,
            w.date_of_birth,
            w.appearances,
            -- Every part of the name, put in a fixed order, so a record entered
            -- surname-first meets the same key as one entered given-name-first and nothing
            -- else does. Keying on the outer two alone was tried first and is wrong: it
            -- collapsed ten separate swimmers named Tsz <something> Chan into one group,
            -- which is a worse answer than missing them. Four parts or more therefore keeps
            -- the whole name in its own order - a middle name dropped or added is a
            -- different record to a reviewer anyway, and guessing is how that group happened.
            CASE w.parts
                WHEN 2 THEN CONCAT_WS(' ', LEAST(w.t1, w.t2), GREATEST(w.t1, w.t2))
                WHEN 3 THEN CONCAT_WS(' ',
                        LEAST(w.t1, w.t2, w.t3),
                        CASE
                            WHEN w.t1 > LEAST(w.t1, w.t2, w.t3) AND w.t1 < GREATEST(w.t1, w.t2, w.t3) THEN w.t1
                            WHEN w.t2 > LEAST(w.t1, w.t2, w.t3) AND w.t2 < GREATEST(w.t1, w.t2, w.t3) THEN w.t2
                            ELSE w.t3
                        END,
                        GREATEST(w.t1, w.t2, w.t3))
                ELSE w.whole
            END AS name_key
        FROM (
            SELECT
                p.id AS participant_id,
                p.name AS participant_name,
                p.countryFK,
                p.gender,
                LENGTH(TRIM(p.name)) - LENGTH(REPLACE(TRIM(p.name), ' ', '')) + 1 AS parts,
                LOWER(SUBSTRING_INDEX(TRIM(p.name), ' ', 1)) AS t1,
                LOWER(SUBSTRING_INDEX(SUBSTRING_INDEX(TRIM(p.name), ' ', 2), ' ', -1)) AS t2,
                LOWER(SUBSTRING_INDEX(SUBSTRING_INDEX(TRIM(p.name), ' ', 3), ' ', -1)) AS t3,
                LOWER(TRIM(p.name)) AS whole,
                (
                    SELECT MIN(TRIM(pr.value))
                    FROM property pr
                    WHERE pr.object = 'participant'
                      AND pr.objectFK = p.id
                      AND pr.name = 'date_of_birth'
                      AND pr.del = 'no'
                      AND pr.value IS NOT NULL
                      AND TRIM(pr.value) <> ''
                ) AS date_of_birth,
                -- All three paths a person reaches a sport by, summed, because no two sports
                -- use them the same way: one enters athletes on the event, one enters teams
                -- and carries the athletes in lineups, and one carries them only in the
                -- Comp.Rank statistic. Counting a single path calls a busy record empty in
                -- every sport that uses another, and empty is what this column is read for.
                (
                    SELECT COUNT(*)
                    FROM event_participants ep
                    JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
                    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
                    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
                    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
                    WHERE ep.participantFK = p.id
                      AND ep.del = 'no'
                      AND tt.sportFK = {{SPORT_ID}}
                ) + (
                    SELECT COUNT(*)
                    FROM lineup l
                    JOIN event_participants ep2 ON ep2.id = l.event_participantsFK AND ep2.del = 'no'
                    JOIN event e2 ON e2.id = ep2.eventFK AND e2.del = 'no'
                    JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
                    JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
                    JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
                    WHERE l.participantFK = p.id
                      AND l.del = 'no'
                      AND tt2.sportFK = {{SPORT_ID}}
                ) + (
                    SELECT COUNT(*)
                    FROM statistic_participants{{SHARD_ID}} sp
                    JOIN statistic s ON s.id = sp.statisticFK AND s.del = 'no'
                         AND s.statistic_typeFK = {{STATISTIC_TYPE_ID}}
                    JOIN tournament t3 ON t3.id = s.objectFK AND t3.del = 'no'
                    JOIN tournament_template tt3 ON tt3.id = t3.tournament_templateFK AND tt3.del = 'no'
                    WHERE sp.participantFK = p.id
                      AND sp.del = 'no'
                      AND s.object_typeFK = 3
                      AND tt3.sportFK = {{SPORT_ID}}
                ) AS appearances
            FROM object_participants op
            JOIN participant p ON p.id = op.participantFK AND p.del = 'no'
            WHERE op.object = 'sport'
              AND op.objectFK = {{SPORT_ID}}
              AND op.del = 'no'
              -- Every type here has to name a natural person: two records for one person is a
              -- thing to merge, whereas two teams of the same name in different years are two
              -- teams. 006 lists the roles a sport registers alongside the types, and the
              -- athlete role is the one that answers for a person.
              -- {{PERSON_PARTICIPANT_TYPE_LIST}}: select participant_type from GLOBAL-DISCOVERY-006 (SPORT_REGISTRY_PARTICIPANT_TYPES) where registry_participant_role = athlete
              AND p.type IN ({{PERSON_PARTICIPANT_TYPE_LIST}})
              AND p.name IS NOT NULL
              -- A single-part name has no order to differ in and no surname to match on,
              -- so it would group every one-word entry that happens to repeat.
              AND TRIM(p.name) LIKE '% %'
        ) w
    ) x
    GROUP BY x.name_key
    HAVING COUNT(*) > 1
) y
ORDER BY
    FIELD(CASE
        WHEN y.people_with_dob = 0 THEN 'NO_DOB_EITHER_SIDE'
        WHEN y.distinct_dobs > 1 THEN 'DOB_CONFLICT'
        WHEN y.people_with_dob < y.people THEN 'DOB_ON_ONE_SIDE_ONLY'
        ELSE 'DOB_MATCH'
    END, 'DOB_MATCH', 'DOB_ON_ONE_SIDE_ONLY', 'NO_DOB_EITHER_SIDE', 'DOB_CONFLICT'),
    y.people DESC,
    y.busiest_appearances DESC,
    y.name_key;
