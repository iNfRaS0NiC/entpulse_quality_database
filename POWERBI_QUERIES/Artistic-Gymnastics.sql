SELECT
    -- CheckID - Artistic-Gymnastics-DQ-029
    -- Name - TOURNAMENT_NAME_SEASON_CONTRADICTS_DATES
    -- What it does: Finds active Artistic Gymnastics tournaments, excluding IOC-purpose templates and the two confirmed postponed Summer Olympics 2020 editions, whose name disagrees with the calendar years their own tournament stages occupy, separating the five contradiction shapes, with stage-year and template context and a coverage count of the identical eligible tournament scope.
    CASE
        WHEN x.stage_span > 2 THEN 'STAGES_SPAN_MORE_THAN_TWO_YEARS'
        WHEN x.stage_span = 2 AND x.name_has_span = 0 THEN 'SINGLE_YEAR_NAME_ON_SEASON'
        WHEN x.stage_span = 2 THEN 'NAME_SPAN_DOES_NOT_MATCH_STAGE_YEARS'
        WHEN x.name_has_span = 1 THEN 'SEASON_NAME_ON_SINGLE_YEAR'
        ELSE 'NAME_YEAR_MATCHES_NO_STAGE'
    END AS check_type,
    x.tournament_id,
    x.tournament_name,
    x.template_name,
    x.first_stage_year,
    x.last_stage_year,
    x.stage_span,
    x.stages,
    NULL AS eligible_count,
    0 AS sort_order
FROM (
    SELECT
        t.id AS tournament_id,
        t.name AS tournament_name,
        tt.name AS template_name,
        COUNT(DISTINCT ts.id) AS stages,
        MIN(YEAR(ts.startdate)) AS first_stage_year,
        MAX(YEAR(COALESCE(ts.enddate, ts.startdate))) AS last_stage_year,
        MAX(YEAR(COALESCE(ts.enddate, ts.startdate))) - MIN(YEAR(ts.startdate)) + 1 AS stage_span,
        (t.name REGEXP '[12][0-9][0-9][0-9]') AS name_has_year,
        (t.name REGEXP '[12][0-9][0-9][0-9][/-]([12][0-9][0-9][0-9]|[0-9][0-9])') AS name_has_span
    FROM tournament t
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
     AND ts.startdate IS NOT NULL
    WHERE t.del = 'no'
      AND tt.sportFK = 40
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      AND t.id NOT IN (14678, 36693)
      -- AND tt.id = <tournament_template_id>
    GROUP BY t.id, t.name, tt.name
) x
WHERE x.stage_span > 2
   OR (
        x.name_has_year = 1
        AND (
            (x.stage_span = 2 AND (
                x.name_has_span = 0
                OR x.tournament_name NOT LIKE CONCAT('%', x.first_stage_year, '%')
                OR x.tournament_name NOT LIKE CONCAT('%', x.last_stage_year, '%')
            ))
            OR (x.stage_span = 1 AND (
                x.name_has_span = 1
                OR x.tournament_name NOT LIKE CONCAT('%', x.first_stage_year, '%')
            ))
        )
      )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT t.id) AS eligible_count,
    1 AS sort_order
FROM tournament t
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
 AND ts.startdate IS NOT NULL
WHERE t.del = 'no'
  AND tt.sportFK = 40
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND t.id NOT IN (14678, 36693)
  -- AND tt.id = <tournament_template_id>

ORDER BY sort_order, first_stage_year;


-- ================================================================================
SELECT
    -- CheckID - Artistic-Gymnastics-DQ-089
    -- Name - EVENT_DISCIPLINE_CONTRADICTS_EVENT_NAME
    -- What it does: Finds active Artistic Gymnastics events, excluding IOC-purpose templates, whose stored object_discipline names one apparatus while the event name unambiguously names a different one, with both disciplines, the event name and template and tournament name context, together with a coverage count of all eligible events whose name names an apparatus at all.
    'Event_Discipline_Contradicts_Name' AS check_type,
    x.event_id,
    x.event_name,
    x.stored_discipline,
    x.name_implies,
    x.startdate,
    x.template_name,
    x.tournament_name,
    NULL AS eligible_count,
    0 AS sort_order
-- Only names carrying exactly one apparatus word enter the audit. A name reading
-- "Women Floor Balance Beam Final" holds two, and the longest match wins, which is why the
-- CASE tests the two-word forms before the one-word ones: "parallel bars" and "uneven bars"
-- both contain "bars", and "floor exercise" contains "floor".
-- All-Around is deliberately not in the vocabulary. It is a compound competition rather than
-- an apparatus, its name legitimately appears beside apparatus words, and reading it as one
-- would report the sport's normal naming rather than a contradiction.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate,
        d.name AS stored_discipline,
        tt.name AS template_name,
        t.name AS tournament_name,
        CASE
            WHEN LOWER(e.name) LIKE '%pommel%'         THEN 'Pommel Horse'
            WHEN LOWER(e.name) LIKE '%uneven bars%'    THEN 'Uneven Bars'
            WHEN LOWER(e.name) LIKE '%parallel bars%'  THEN 'Parallel Bars'
            WHEN LOWER(e.name) LIKE '%horizontal bar%' THEN 'Horizontal Bar'
            WHEN LOWER(e.name) LIKE '%high bar%'       THEN 'Horizontal Bar'
            WHEN LOWER(e.name) LIKE '%balance beam%'   THEN 'Balance Beam'
            WHEN LOWER(e.name) LIKE '%rings%'          THEN 'Rings'
            WHEN LOWER(e.name) LIKE '%vault%'          THEN 'Vault'
            WHEN LOWER(e.name) LIKE '%floor%'          THEN 'Floor Exercise'
        END AS name_implies
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN object_discipline od ON od.objectFK = e.id AND od.object_typeFK = 5 AND od.del = 'no'
    JOIN discipline d ON d.id = od.disciplineFK
    WHERE e.del = 'no'
      AND tt.sportFK = 40
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      -- AND tt.id = <tournament_template_id>
) x
WHERE x.name_implies IS NOT NULL
  AND x.name_implies <> x.stored_discipline

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT y.event_id) AS eligible_count,
    1 AS sort_order
FROM (
    SELECT
        e.id AS event_id,
        CASE
            WHEN LOWER(e.name) LIKE '%pommel%'         THEN 'Pommel Horse'
            WHEN LOWER(e.name) LIKE '%uneven bars%'    THEN 'Uneven Bars'
            WHEN LOWER(e.name) LIKE '%parallel bars%'  THEN 'Parallel Bars'
            WHEN LOWER(e.name) LIKE '%horizontal bar%' THEN 'Horizontal Bar'
            WHEN LOWER(e.name) LIKE '%high bar%'       THEN 'Horizontal Bar'
            WHEN LOWER(e.name) LIKE '%balance beam%'   THEN 'Balance Beam'
            WHEN LOWER(e.name) LIKE '%rings%'          THEN 'Rings'
            WHEN LOWER(e.name) LIKE '%vault%'          THEN 'Vault'
            WHEN LOWER(e.name) LIKE '%floor%'          THEN 'Floor Exercise'
        END AS name_implies
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN object_discipline od ON od.objectFK = e.id AND od.object_typeFK = 5 AND od.del = 'no'
    WHERE e.del = 'no'
      AND tt.sportFK = 40
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      -- AND tt.id = <tournament_template_id>
) y
WHERE y.name_implies IS NOT NULL

ORDER BY sort_order, event_id;


-- ================================================================================
SELECT
    -- CheckID - Artistic-Gymnastics-DQ-090
    -- Name - EVENT_RESULT_SET_DUPLICATED_ACROSS_DISCIPLINES
    -- What it does: Finds active finished Artistic Gymnastics events, excluding IOC-purpose templates, whose complete set of participants and Points values is identical to that of an event of a different discipline in the same tournament, so one apparatus field has been written over another, with the partner disciplines and event ids, the participant count and template and tournament name context, together with a coverage count of all eligible events holding at least five participants.
    'Event_Result_Set_Duplicated_Across_Disciplines' AS check_type,
    f.event_id,
    f.event_name,
    f.discipline_name,
    f.startdate,
    f.participants,
    f.participants_with_points,
    g.partner_disciplines,
    g.partner_event_ids,
    f.template_name,
    f.tournament_name,
    NULL AS eligible_count,
    0 AS sort_order
-- The fingerprint is an order-independent sum of CRC32 over participant and Points value,
-- not a GROUP_CONCAT: a concatenated key is silently truncated at group_concat_max_len and
-- two long fields would then collide on their prefix, which turns the check into noise.
-- Rank is deliberately not in the fingerprint. Two apparatus finals contested by the same
-- eight gymnasts legitimately produce the same rank sequence; it is the scores being
-- identical as well that no two apparatus can produce.
-- The audited object is the event, so a duplicated pair reports two rows, each naming the
-- other. Only Points is compared, because the D and E components are Extended Results and
-- outside this sport's DQ scope.
FROM (
    SELECT
        e.id AS event_id, e.name AS event_name, e.startdate,
        t.id AS tournament_id, t.name AS tournament_name, tt.name AS template_name,
        d.id AS discipline_id, d.name AS discipline_name,
        COUNT(DISTINCT ep.id) AS participants,
        COUNT(DISTINCT CASE WHEN r.value IS NOT NULL AND TRIM(r.value) <> '' THEN ep.id END) AS participants_with_points,
        SUM(CRC32(CONCAT(ep.participantFK, ':', COALESCE(r.value, '')))) AS fingerprint
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN object_discipline od ON od.objectFK = e.id AND od.object_typeFK = 5 AND od.del = 'no'
    JOIN discipline d ON d.id = od.disciplineFK
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    LEFT JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no' AND r.result_typeFK = 102
    WHERE e.del = 'no'
      AND e.status_type = 'finished'
      AND tt.sportFK = 40
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      -- AND tt.id = <tournament_template_id>
    GROUP BY e.id, e.name, e.startdate, t.id, t.name, tt.name, d.id, d.name
    HAVING participants >= 5
) f
JOIN (
    SELECT
        z.tournament_id, z.participants, z.fingerprint,
        GROUP_CONCAT(DISTINCT z.discipline_name ORDER BY z.discipline_name SEPARATOR ' + ') AS partner_disciplines,
        GROUP_CONCAT(DISTINCT z.event_id ORDER BY z.event_id) AS partner_event_ids
    FROM (
        SELECT
            e.id AS event_id, t.id AS tournament_id,
            d.id AS discipline_id, d.name AS discipline_name,
            COUNT(DISTINCT ep.id) AS participants,
            SUM(CRC32(CONCAT(ep.participantFK, ':', COALESCE(r.value, '')))) AS fingerprint
        FROM event e
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
        JOIN object_discipline od ON od.objectFK = e.id AND od.object_typeFK = 5 AND od.del = 'no'
        JOIN discipline d ON d.id = od.disciplineFK
        JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
        LEFT JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no' AND r.result_typeFK = 102
        WHERE e.del = 'no'
          AND e.status_type = 'finished'
          AND tt.sportFK = 40
          AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
          -- AND tt.id = <tournament_template_id>
        GROUP BY e.id, t.id, d.id, d.name
        HAVING participants >= 5
    ) z
    GROUP BY z.tournament_id, z.participants, z.fingerprint
    HAVING COUNT(DISTINCT z.discipline_id) > 1
) g
  ON g.tournament_id = f.tournament_id
 AND g.participants = f.participants
 AND g.fingerprint = f.fingerprint

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT c.event_id) AS eligible_count,
    1 AS sort_order
FROM (
    SELECT e.id AS event_id
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN object_discipline od ON od.objectFK = e.id AND od.object_typeFK = 5 AND od.del = 'no'
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    WHERE e.del = 'no'
      AND e.status_type = 'finished'
      AND tt.sportFK = 40
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      -- AND tt.id = <tournament_template_id>
    GROUP BY e.id
    HAVING COUNT(DISTINCT ep.id) >= 5
) c

ORDER BY sort_order, event_id;


-- ================================================================================
SELECT
    -- CheckID - Artistic-Gymnastics-DQ-091
    -- Name - COMP.RANK_TEAM_MEMBERS_DISAGREE_ON_TEAM_RESULT
    -- What it does: Finds active tournament-owned Comp.Rank statistics of Artistic Gymnastics, excluding IOC-purpose templates, in which the athletes the Team data field assigns to one team within one phase do not all carry the same Points or the same Rank, so one member holds a different version of a placing the whole team shares, with the team id, the member count, the differing values and template and tournament name context, together with a coverage count of all eligible statistics holding at least one team-linked member.
    CASE
        WHEN x.distinct_points > 1 AND x.distinct_ranks > 1 THEN 'TEAM_MEMBERS_DISAGREE_ON_POINTS_AND_RANK'
        WHEN x.distinct_points > 1 THEN 'TEAM_MEMBERS_DISAGREE_ON_POINTS'
        ELSE 'TEAM_MEMBERS_DISAGREE_ON_RANK'
    END AS check_type,
    x.statistic_id,
    x.statistic_name,
    x.template_name,
    x.tournament_name,
    x.phase_round_id,
    x.team_id,
    x.members,
    x.points_seen,
    x.ranks_seen,
    NULL AS eligible_count,
    0 AS sort_order
-- A team and the athletes it fields are one placing, so every member of one team must hold
-- the same team Points and the same team Rank. The grouping carries the phase, because the
-- same team legitimately holds a different placing in the Qualifier than in the Final and
-- comparing across the two would report the competition rather than a defect.
-- Phase is read from object_round rather than from a data field: DATABASE.md records
-- object_typeFK 138 with type phase as the only storage for the concept.
-- Members with no Team value are outside the audit; a team-less athlete row is
-- GLOBAL-DQ-064 and is not restated here.
FROM (
    SELECT
        s.id AS statistic_id,
        s.name AS statistic_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        orr.round_typeFK AS phase_round_id,
        team.value AS team_id,
        COUNT(DISTINCT sp.id) AS members,
        COUNT(DISTINCT pts.value) AS distinct_points,
        COUNT(DISTINCT rnk.value) AS distinct_ranks,
        GROUP_CONCAT(DISTINCT pts.value ORDER BY pts.value) AS points_seen,
        GROUP_CONCAT(DISTINCT rnk.value ORDER BY rnk.value) AS ranks_seen
    FROM statistic s
    JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN statistic_participants11 sp ON sp.statisticFK = s.id AND sp.del = 'no'
    JOIN statistic_data11 team ON team.statistic_participants11FK = sp.id AND team.del = 'no'
         AND team.statistic_data_typeFK = 1429
         AND team.value IS NOT NULL AND TRIM(team.value) <> ''
    LEFT JOIN statistic_data11 pts ON pts.statistic_participants11FK = sp.id AND pts.del = 'no'
         AND pts.statistic_data_typeFK = 1271
         AND pts.value IS NOT NULL AND TRIM(pts.value) <> ''
    LEFT JOIN statistic_data11 rnk ON rnk.statistic_participants11FK = sp.id AND rnk.del = 'no'
         AND rnk.statistic_data_typeFK = 1270
         AND rnk.value IS NOT NULL AND TRIM(rnk.value) <> ''
    LEFT JOIN object_round orr ON orr.objectFK = sp.id AND orr.object_typeFK = 138
         AND orr.type = 'phase' AND orr.del = 'no'
    WHERE s.del = 'no'
      AND s.statistic_typeFK = 11
      AND s.object_typeFK = 3
      AND tt.sportFK = 40
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      -- AND tt.id = <tournament_template_id>
    GROUP BY s.id, s.name, tt.name, t.name, orr.round_typeFK, team.value
) x
WHERE x.members > 1
  AND (x.distinct_points > 1 OR x.distinct_ranks > 1)

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count,
    1 AS sort_order
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN statistic_participants11 sp ON sp.statisticFK = s.id AND sp.del = 'no'
JOIN statistic_data11 team ON team.statistic_participants11FK = sp.id AND team.del = 'no'
     AND team.statistic_data_typeFK = 1429
     AND team.value IS NOT NULL AND TRIM(team.value) <> ''
WHERE s.del = 'no'
  AND s.statistic_typeFK = 11
  AND s.object_typeFK = 3
  AND tt.sportFK = 40
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>

ORDER BY sort_order, statistic_id;


-- ================================================================================
SELECT
    -- CheckID - Artistic-Gymnastics-DQ-092
    -- Name - EVENT_DISCIPLINE_INCOMPATIBLE_WITH_GENDER
    -- What it does: Finds active Artistic Gymnastics events, excluding IOC-purpose templates, contested on an apparatus the stage gender does not compete, a male stage on Uneven Bars or Balance Beam or a female stage on Pommel Horse, Rings, Parallel Bars or Horizontal Bar, separating the two directions, with the discipline, the stage gender and template and tournament name context, together with a coverage count of all eligible events held on a single-gender stage and a gender-specific apparatus.
    CASE
        WHEN ts.gender = 'male' THEN 'MALE_STAGE_ON_WOMENS_APPARATUS'
        ELSE 'FEMALE_STAGE_ON_MENS_APPARATUS'
    END AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    d.id AS discipline_id,
    d.name AS discipline_name,
    ts.gender AS stage_gender,
    e.startdate,
    tt.name AS template_name,
    t.name AS tournament_name,
    NULL AS eligible_count,
    0 AS sort_order
-- The apparatus programmes are fixed by the sport rather than by this database: men contest
-- Floor Exercise, Pommel Horse, Rings, Vault, Parallel Bars and Horizontal Bar; women
-- contest Vault, Uneven Bars, Balance Beam and Floor Exercise. Floor Exercise and Vault are
-- shared and are therefore outside the audit in both directions.
-- Only the four men-only and two women-only apparatus enter, and only single-gender stages.
-- A mixed stage is excluded rather than reported: Mixed Team is contested on discipline 798,
-- and a mixed stage carrying a gendered apparatus is a separate question this rule cannot
-- answer, because the stage gender is not authoritative for the individual entry there.
-- Team All-Around and Individual All-Around are compound competitions rather than apparatus
-- and are contested by both genders, so they are outside the audit as well.
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN object_discipline od ON od.objectFK = e.id AND od.object_typeFK = 5 AND od.del = 'no'
JOIN discipline d ON d.id = od.disciplineFK
WHERE e.del = 'no'
  AND tt.sportFK = 40
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND ts.gender IN ('male', 'female')
  -- AND tt.id = <tournament_template_id>
  AND (
       (ts.gender = 'male'   AND d.id IN (91, 87))
    OR (ts.gender = 'female' AND d.id IN (85, 86, 89, 88))
  )

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
JOIN object_discipline od ON od.objectFK = e.id AND od.object_typeFK = 5 AND od.del = 'no'
JOIN discipline d ON d.id = od.disciplineFK
WHERE e.del = 'no'
  AND tt.sportFK = 40
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND ts.gender IN ('male', 'female')
  AND d.id IN (85, 86, 87, 88, 89, 91)
  -- AND tt.id = <tournament_template_id>

ORDER BY sort_order, event_id;


-- ================================================================================
SELECT
    -- CheckID - Artistic-Gymnastics-DQ-093
    -- Name - EVENT_RESULTS_NO_RESULT_COMMENT_CARRIES_RANK
    -- What it does: Finds active Artistic Gymnastics event participants, excluding IOC-purpose templates, whose Comment records that the gymnast produced no classified result while a Rank or a Medal is stored beside it, separating a stored rank from a stored medal, with the comment, the contradicting values, the discipline and template and tournament name context, together with a coverage count of all eligible participants carrying one of those comments.
    CASE
        WHEN med.value IS NOT NULL AND TRIM(med.value) <> '' THEN 'NO_RESULT_COMMENT_WITH_MEDAL'
        ELSE 'NO_RESULT_COMMENT_WITH_RANK'
    END AS check_type,
    ep.id AS event_participants_id,
    e.id AS event_id,
    e.name AS event_name,
    d.name AS discipline_name,
    p.name AS participant_name,
    TRIM(cmt.value) AS comment_value,
    rnk.value AS stored_rank,
    med.value AS stored_medal,
    tt.name AS template_name,
    t.name AS tournament_name,
    NULL AS eligible_count,
    0 AS sort_order
-- The vocabulary is the four literals that mean the gymnast produced nothing to classify.
-- NR and NC are deliberately not among them and are not a defect here: NR carries a Points
-- value and a Rank on every one of its rows, and NC carries Points on most of them while
-- almost never carrying a Rank, so both describe a gymnast who competed and was left out of
-- a classification rather than one who has no result. SPORTS/Artistic-Gymnastics.md owns
-- that reading.
-- Points is not asserted alongside Rank. A withdrawn gymnast can legitimately retain the
-- score already earned on an earlier apparatus; what cannot follow is a placing.
FROM result cmt
JOIN event_participants ep ON ep.id = cmt.event_participantsFK AND ep.del = 'no'
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
LEFT JOIN object_discipline od ON od.objectFK = e.id AND od.object_typeFK = 5 AND od.del = 'no'
LEFT JOIN discipline d ON d.id = od.disciplineFK
LEFT JOIN result rnk ON rnk.event_participantsFK = ep.id AND rnk.del = 'no'
     AND rnk.result_typeFK = 100 AND rnk.value IS NOT NULL AND TRIM(rnk.value) <> ''
LEFT JOIN result med ON med.event_participantsFK = ep.id AND med.del = 'no'
     AND med.result_typeFK = 501 AND med.value IS NOT NULL AND TRIM(med.value) <> ''
WHERE cmt.del = 'no'
  AND cmt.result_typeFK = 104
  AND LOWER(TRIM(cmt.value)) IN ('dns', 'dnf', 'disq.', 'withdrawn')
  AND tt.sportFK = 40
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
  AND (rnk.value IS NOT NULL OR med.value IS NOT NULL)

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ep.id) AS eligible_count,
    1 AS sort_order
FROM result cmt
JOIN event_participants ep ON ep.id = cmt.event_participantsFK AND ep.del = 'no'
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE cmt.del = 'no'
  AND cmt.result_typeFK = 104
  AND LOWER(TRIM(cmt.value)) IN ('dns', 'dnf', 'disq.', 'withdrawn')
  AND tt.sportFK = 40
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>

ORDER BY sort_order, event_participants_id;


-- ================================================================================
SELECT
    -- CheckID - Artistic-Gymnastics-DQ-094
    -- Name - EVENT_RESULTS_NUMERIC_LEAKED_TO_COMMENT
    -- What it does: Finds active Artistic Gymnastics event participants, excluding IOC-purpose templates, whose Comment holds a gymnastics score rather than a status code, separating a comma-decimal shape from a dot-decimal one, with the stored value, whether a Points value exists beside it, the discipline and template and tournament name context, together with a coverage count of all eligible participants carrying an active non-empty Comment.
    CASE
        WHEN TRIM(cmt.value) REGEXP '^[0-9]+,[0-9]{1,3}$' THEN 'SCORE_WITH_COMMA_DECIMAL_IN_COMMENT'
        ELSE 'SCORE_WITH_DOT_DECIMAL_IN_COMMENT'
    END AS check_type,
    ep.id AS event_participants_id,
    e.id AS event_id,
    e.name AS event_name,
    d.name AS discipline_name,
    p.name AS participant_name,
    TRIM(cmt.value) AS comment_value,
    pts.value AS stored_points,
    tt.name AS template_name,
    t.name AS tournament_name,
    NULL AS eligible_count,
    0 AS sort_order
-- The Comment field holds a closed status vocabulary for this sport, so a value shaped like
-- a score is a score written into the wrong column. Both decimal shapes are audited because
-- the sport's own scores use a dot while the leaked ones observed so far use a comma, and a
-- rule keyed on the comma alone would stop working the moment the source changes separator.
-- The Points value travels with the row because it decides the repair: a participant already
-- holding a score has a duplicate to delete, one holding none has a score to move.
-- The statistic-layer twin of this rule is GLOBAL-DQ-099, instantiated as
-- Artistic-Gymnastics-DQ-043; the event layer has no template that reaches it, because
-- GLOBAL-DQ-052 reads a full time and a duration this sport does not store.
FROM result cmt
JOIN event_participants ep ON ep.id = cmt.event_participantsFK AND ep.del = 'no'
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
LEFT JOIN object_discipline od ON od.objectFK = e.id AND od.object_typeFK = 5 AND od.del = 'no'
LEFT JOIN discipline d ON d.id = od.disciplineFK
LEFT JOIN result pts ON pts.event_participantsFK = ep.id AND pts.del = 'no'
     AND pts.result_typeFK = 102 AND pts.value IS NOT NULL AND TRIM(pts.value) <> ''
WHERE cmt.del = 'no'
  AND cmt.result_typeFK = 104
  AND cmt.value IS NOT NULL
  AND TRIM(cmt.value) <> ''
  AND tt.sportFK = 40
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>
  AND (
       TRIM(cmt.value) REGEXP '^[0-9]+,[0-9]{1,3}$'
    OR TRIM(cmt.value) REGEXP '^[0-9]+[.][0-9]{1,3}$'
  )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ep.id) AS eligible_count,
    1 AS sort_order
FROM result cmt
JOIN event_participants ep ON ep.id = cmt.event_participantsFK AND ep.del = 'no'
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE cmt.del = 'no'
  AND cmt.result_typeFK = 104
  AND cmt.value IS NOT NULL
  AND TRIM(cmt.value) <> ''
  AND tt.sportFK = 40
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>

ORDER BY sort_order, event_participants_id;


-- ================================================================================
SELECT
    -- CheckID - Artistic-Gymnastics-DQ-095
    -- Name - EVENT_VAULT_COMMENT_OUTSIDE_VAULT
    -- What it does: Finds active Artistic Gymnastics event participants, excluding IOC-purpose templates, whose Comment records that the score was taken from the first vault while the event is contested on an apparatus other than Vault, so a Vault-only marker has been carried onto a discipline that performs one exercise, with the discipline, the stored comment and template and tournament name context, together with a coverage count of all eligible participants carrying that comment on any discipline.
    'Vault_Comment_Outside_Vault' AS check_type,
    ep.id AS event_participants_id,
    e.id AS event_id,
    e.name AS event_name,
    d.id AS discipline_id,
    d.name AS discipline_name,
    p.name AS participant_name,
    TRIM(cmt.value) AS comment_value,
    tt.name AS template_name,
    t.name AS tournament_name,
    NULL AS eligible_count,
    0 AS sort_order
-- Vault is the only apparatus on which a gymnast performs two exercises, and the marker
-- records which of the two the stored score came from. Every other apparatus is a single
-- exercise with nothing for the marker to distinguish, so its presence there is either the
-- wrong discipline on the event or the wrong comment on the participant.
-- The marker is matched by prefix rather than as a literal, so a second vault or a differently
-- numbered variant is caught by the same rule. It is deliberately absent from
-- RESULT_COMMENT_VALUE_LIST in SPORTS/params.json: it is a sentence rather than a status
-- code, and leaving it out is what makes it visible here.
-- The two-vault average itself cannot be asserted. It lives in the checkpoint scope layer,
-- which is outside this sport's DQ scope by the decision recorded in
-- SPORTS/Artistic-Gymnastics.md.
FROM result cmt
JOIN event_participants ep ON ep.id = cmt.event_participantsFK AND ep.del = 'no'
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN object_discipline od ON od.objectFK = e.id AND od.object_typeFK = 5 AND od.del = 'no'
JOIN discipline d ON d.id = od.disciplineFK
WHERE cmt.del = 'no'
  AND cmt.result_typeFK = 104
  AND LOWER(TRIM(cmt.value)) LIKE 'from vault%'
  AND tt.sportFK = 40
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND d.id <> 90
  -- AND tt.id = <tournament_template_id>

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ep.id) AS eligible_count,
    1 AS sort_order
FROM result cmt
JOIN event_participants ep ON ep.id = cmt.event_participantsFK AND ep.del = 'no'
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN object_discipline od ON od.objectFK = e.id AND od.object_typeFK = 5 AND od.del = 'no'
WHERE cmt.del = 'no'
  AND cmt.result_typeFK = 104
  AND LOWER(TRIM(cmt.value)) LIKE 'from vault%'
  AND tt.sportFK = 40
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  -- AND tt.id = <tournament_template_id>

ORDER BY sort_order, event_participants_id;


-- ================================================================================
SELECT
    -- CheckID - Artistic-Gymnastics-DQ-096
    -- Name - EVENT_RESULT_SCALE_CONTRADICTS_DISCIPLINE
    -- What it does: Finds active finished Artistic Gymnastics All-Around events, excluding IOC-purpose templates, whose Points values sit in the range a single apparatus produces rather than the multi-apparatus total the competition is, separating an Individual All-Around from a Team All-Around, with the median-scale figures, the participant counts and template and tournament name context, together with a coverage count of all eligible All-Around events holding at least five scored participants.
    CASE
        WHEN x.discipline_id = 96 THEN 'INDIVIDUAL_ALL_AROUND_ON_SINGLE_APPARATUS_SCALE'
        ELSE 'TEAM_ALL_AROUND_ON_SINGLE_APPARATUS_SCALE'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.discipline_name,
    x.stage_gender,
    x.startdate,
    x.scored_participants,
    x.max_points,
    x.points_at_or_below_20,
    x.template_name,
    x.tournament_name,
    NULL AS eligible_count,
    0 AS sort_order
-- An All-Around score is a sum over apparatus - six for men, four for women - so it cannot
-- sit where a single exercise sits. A single apparatus score has not exceeded 20 under any
-- scoring code the sport has used, the perfect 10 before 2006 and the open-ended D plus E
-- since, so 20 separates the two scales without needing a ceiling for either.
-- The whole event is judged rather than the individual row, and only when four fifths of its
-- scored field sits on the wrong scale. One gymnast with a single apparatus score inside a
-- multi-apparatus field is a withdrawal after one rotation, which is competition rather than
-- a defect; a whole field on that scale is the wrong result set on the event.
-- Zero is excluded from the scale test rather than counted low: it is the stored form of a
-- gymnast who scored nothing, and counting it would push a legitimate field over the
-- threshold.
FROM (
    SELECT
        e.id AS event_id, e.name AS event_name, e.startdate,
        d.id AS discipline_id, d.name AS discipline_name,
        ts.gender AS stage_gender,
        tt.name AS template_name, t.name AS tournament_name,
        COUNT(DISTINCT ep.id) AS scored_participants,
        MAX(CAST(r.value AS DECIMAL(12,3))) AS max_points,
        COUNT(DISTINCT CASE WHEN CAST(r.value AS DECIMAL(12,3)) <= 20 THEN ep.id END) AS points_at_or_below_20
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN object_discipline od ON od.objectFK = e.id AND od.object_typeFK = 5 AND od.del = 'no'
    JOIN discipline d ON d.id = od.disciplineFK
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no' AND r.result_typeFK = 102
         AND r.value REGEXP '^[0-9]+([.][0-9]+)?$'
         AND CAST(r.value AS DECIMAL(12,3)) > 0
    WHERE e.del = 'no'
      AND e.status_type = 'finished'
      AND tt.sportFK = 40
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      AND d.id IN (96, 82)
      -- AND tt.id = <tournament_template_id>
    GROUP BY e.id, e.name, e.startdate, d.id, d.name, ts.gender, tt.name, t.name
    HAVING scored_participants >= 5
) x
WHERE x.points_at_or_below_20 >= x.scored_participants * 0.8

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT c.event_id) AS eligible_count,
    1 AS sort_order
FROM (
    SELECT e.id AS event_id
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN object_discipline od ON od.objectFK = e.id AND od.object_typeFK = 5 AND od.del = 'no'
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no' AND r.result_typeFK = 102
         AND r.value REGEXP '^[0-9]+([.][0-9]+)?$'
         AND CAST(r.value AS DECIMAL(12,3)) > 0
    WHERE e.del = 'no'
      AND e.status_type = 'finished'
      AND tt.sportFK = 40
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      AND od.disciplineFK IN (96, 82)
      -- AND tt.id = <tournament_template_id>
    GROUP BY e.id
    HAVING COUNT(DISTINCT ep.id) >= 5
) c

ORDER BY sort_order, event_id;
