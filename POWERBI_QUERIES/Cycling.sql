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


-- ================================================================================
SELECT
    -- CheckID - Cycling-DQ-009
    -- Name - TOURNAMENT_STAGE_NAME_FORMAT_INVALID_APART_FROM_THE_HYPHEN_CONVENTION
    -- What it does: Flags stage names breaking a text-hygiene rule, accepting the unspaced hyphen this sport names its courses with.
    'Name_Format_Invalid' AS check_type,
    MIN(x.object_name) AS stage_name,
    x.violation_types,
    COUNT(DISTINCT x.object_id) AS affected_object_count,
    MIN(x.object_id) AS sample_object_id,
    MIN(x.template_name) AS sample_template_name,
    MIN(x.tournament_name) AS sample_tournament_name,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds stage names breaking a text-hygiene rule - spacing,
-- control or corrupted characters, capitalisation, a placeholder or a numeric-only name - one
-- row per name, naming every rule it breaks. Every rule GLOBAL-DQ-048 carries is kept except
-- HYPHEN_WITHOUT_SPACES.
-- That one rule is the whole difference and is why the template is not instantiated here. A road
-- race is named after the two places it runs between and the sport writes that join without
-- spaces - Paris-Roubaix, Milano-Sanremo, Gent-Wevelgem, Bayern-Rundfahrt, Arnhem-Veenendaal
-- Classic - and a Dutch or German race name hyphenates inside a single word as well, as
-- 3-daagse van West-Vlaanderen does twice. Run on 2026-08-16 the template reported 59 names, 58
-- of them for that rule alone and one for a trailing space, so the rule fires on the way this
-- sport spells its calendar and hides the thirteen rules that would have found something.
-- Ice Hockey reached the same conclusion from the opposite direction, joining two team names the
-- same way, and Ice-Hockey-DQ-082 is the same statement over events.
-- Not a weaker check. A rule matching almost every row in the population tests nothing.
-- GLOBAL-DQ-050 still owns the case-inconsistency question and is decided separately: it is what
-- reports Milano - Sanremo spelled beside Milano-Sanremo, which is a real disagreement and is
-- not what this rule was firing on.
FROM (
    SELECT
        ts.id AS object_id,
        ts.name AS object_name,
        (CONVERT(ts.name USING utf8mb4) COLLATE utf8mb4_bin) AS name_bin,
        tt.name AS template_name,
        t.name AS tournament_name,
        CONCAT_WS(', ',
            IF(CHAR_LENGTH(ts.name) <> CHAR_LENGTH(TRIM(ts.name)), 'LEADING_OR_TRAILING_SPACE', NULL),
            IF(ts.name LIKE '%  %', 'DOUBLE_SPACE', NULL),
            IF(ts.name REGEXP '[[:cntrl:]]', 'CONTROL_CHARACTER', NULL),
            -- Semicolon as \\x{3B}, never literal: the Pool cuts the statement at the first one.
            IF(ts.name LIKE '%&#%' OR LOWER(ts.name) REGEXP '&(amp|quot|apos|lt|gt|nbsp)\\x{3B}', 'HTML_ENTITY', NULL),
            IF(HEX(ts.name) LIKE '%EFBFBD%', 'REPLACEMENT_CHARACTER', NULL),
            IF(HEX(ts.name) LIKE '%C2A0%', 'NON_BREAKING_SPACE', NULL),
            IF(HEX(ts.name) LIKE '%E2808B%', 'ZERO_WIDTH_SPACE', NULL),
            IF(HEX(ts.name) LIKE '%C383%' OR HEX(ts.name) LIKE '%C382%', 'MOJIBAKE_DOUBLE_ENCODED', NULL),
            IF(LENGTH(ts.name) <> CHAR_LENGTH(ts.name), 'NON_ASCII_CHARACTER', NULL),
            IF((CONVERT(ts.name USING utf8mb4) COLLATE utf8mb4_bin) REGEXP '[A-Za-z][12][0-9][0-9][0-9]|[12][0-9][0-9][0-9][A-Za-z]', 'YEAR_GLUED_TO_WORD', NULL),
            IF((CONVERT(ts.name USING utf8mb4) COLLATE utf8mb4_bin) REGEXP '[A-Z][A-Z][a-z]', 'DOUBLE_CAPITAL', NULL),
            IF((CONVERT(ts.name USING utf8mb4) COLLATE utf8mb4_bin) REGEXP '[A-Za-z]'
               AND (CONVERT(ts.name USING utf8mb4) COLLATE utf8mb4_bin) NOT REGEXP '[a-z]', 'ALL_UPPERCASE', NULL),
            IF((CONVERT(ts.name USING utf8mb4) COLLATE utf8mb4_bin) REGEXP '^[a-z]', 'STARTS_LOWERCASE', NULL),
            IF(LOWER(TRIM(ts.name)) IN ('test','testing','temp','tmp','xxx','asd','qwe','tbd','tba','n/a','undefined','stage','new stage'), 'PLACEHOLDER_NAME', NULL),
            IF(TRIM(ts.name) REGEXP '^[0-9]+$', 'NUMERIC_ONLY_NAME', NULL)
        ) AS violation_types
    FROM tournament_stage ts
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = 30
    WHERE ts.del = 'no'
      AND ts.name IS NOT NULL
      AND TRIM(ts.name) <> ''
      -- AND t.tournament_templateFK = <tournament_template_id>
) x
WHERE x.violation_types <> ''
GROUP BY x.name_bin, x.violation_types

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ts.id) AS eligible_count,
    1 AS sort_order
FROM tournament_stage ts
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 30
WHERE ts.del = 'no'
  AND ts.name IS NOT NULL
  AND TRIM(ts.name) <> ''
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, stage_name;


-- ================================================================================
SELECT
    -- CheckID - Cycling-DQ-010
    -- Name - COMP.RANK_NAME_FORMAT_INVALID_APART_FROM_THE_HYPHEN_CONVENTION
    -- What it does: Flags Comp.Rank names breaking a text-hygiene rule, accepting the unspaced hyphen this sport names its courses with.
    'Name_Format_Invalid' AS check_type,
    MIN(x.object_name) AS statistic_name,
    x.violation_types,
    COUNT(DISTINCT x.object_id) AS affected_object_count,
    MIN(x.object_id) AS sample_object_id,
    MIN(x.template_name) AS sample_template_name,
    MIN(x.tournament_name) AS sample_tournament_name,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds stage names breaking a text-hygiene rule - spacing,
-- control or corrupted characters, capitalisation, a placeholder or a numeric-only name - one
-- row per name, naming every rule it breaks. Every rule GLOBAL-DQ-048 carries is kept except
-- HYPHEN_WITHOUT_SPACES.
-- That one rule is the whole difference and is why the template is not instantiated here. A road
-- race is named after the two places it runs between and the sport writes that join without
-- spaces - Paris-Roubaix, Milano-Sanremo, Gent-Wevelgem, Bayern-Rundfahrt, Arnhem-Veenendaal
-- Classic - and a Dutch or German race name hyphenates inside a single word as well, as
-- 3-daagse van West-Vlaanderen does twice. Run on 2026-08-16 the template reported 59 names, 58
-- of them for that rule alone and one for a trailing space, so the rule fires on the way this
-- sport spells its calendar and hides the thirteen rules that would have found something.
-- Ice Hockey reached the same conclusion from the opposite direction, joining two team names the
-- same way, and Ice-Hockey-DQ-082 is the same statement over events.
-- Not a weaker check. A rule matching almost every row in the population tests nothing.
-- GLOBAL-DQ-050 still owns the case-inconsistency question and is decided separately: it is what
-- reports Milano - Sanremo spelled beside Milano-Sanremo, which is a real disagreement and is
-- not what this rule was firing on.
FROM (
    SELECT
        st.id AS object_id,
        st.name AS object_name,
        (CONVERT(st.name USING utf8mb4) COLLATE utf8mb4_bin) AS name_bin,
        tt.name AS template_name,
        t.name AS tournament_name,
        CONCAT_WS(', ',
            IF(CHAR_LENGTH(st.name) <> CHAR_LENGTH(TRIM(st.name)), 'LEADING_OR_TRAILING_SPACE', NULL),
            IF(st.name LIKE '%  %', 'DOUBLE_SPACE', NULL),
            IF(st.name REGEXP '[[:cntrl:]]', 'CONTROL_CHARACTER', NULL),
            -- Semicolon as \\x{3B}, never literal: the Pool cuts the statement at the first one.
            IF(st.name LIKE '%&#%' OR LOWER(st.name) REGEXP '&(amp|quot|apos|lt|gt|nbsp)\\x{3B}', 'HTML_ENTITY', NULL),
            IF(HEX(st.name) LIKE '%EFBFBD%', 'REPLACEMENT_CHARACTER', NULL),
            IF(HEX(st.name) LIKE '%C2A0%', 'NON_BREAKING_SPACE', NULL),
            IF(HEX(st.name) LIKE '%E2808B%', 'ZERO_WIDTH_SPACE', NULL),
            IF(HEX(st.name) LIKE '%C383%' OR HEX(st.name) LIKE '%C382%', 'MOJIBAKE_DOUBLE_ENCODED', NULL),
            IF(LENGTH(st.name) <> CHAR_LENGTH(st.name), 'NON_ASCII_CHARACTER', NULL),
            IF((CONVERT(st.name USING utf8mb4) COLLATE utf8mb4_bin) REGEXP '[A-Za-z][12][0-9][0-9][0-9]|[12][0-9][0-9][0-9][A-Za-z]', 'YEAR_GLUED_TO_WORD', NULL),
            IF((CONVERT(st.name USING utf8mb4) COLLATE utf8mb4_bin) REGEXP '[A-Z][A-Z][a-z]', 'DOUBLE_CAPITAL', NULL),
            IF((CONVERT(st.name USING utf8mb4) COLLATE utf8mb4_bin) REGEXP '[A-Za-z]'
               AND (CONVERT(st.name USING utf8mb4) COLLATE utf8mb4_bin) NOT REGEXP '[a-z]', 'ALL_UPPERCASE', NULL),
            IF((CONVERT(st.name USING utf8mb4) COLLATE utf8mb4_bin) REGEXP '^[a-z]', 'STARTS_LOWERCASE', NULL),
            IF(LOWER(TRIM(st.name)) IN ('test','testing','temp','tmp','xxx','asd','qwe','tbd','tba','n/a','undefined','stats','new stats'), 'PLACEHOLDER_NAME', NULL),
            IF(TRIM(st.name) REGEXP '^[0-9]+$', 'NUMERIC_ONLY_NAME', NULL)
        ) AS violation_types
    FROM statistic st
    JOIN tournament t ON t.id = st.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = 30
    WHERE st.del = 'no'
      AND st.statistic_typeFK = 11
      AND st.object_typeFK = 3
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      AND st.name IS NOT NULL
      AND TRIM(st.name) <> ''
      -- AND t.tournament_templateFK = <tournament_template_id>
) x
WHERE x.violation_types <> ''
GROUP BY x.name_bin, x.violation_types

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT st.id) AS eligible_count,
    1 AS sort_order
FROM statistic st
JOIN tournament t ON t.id = st.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 30
WHERE st.del = 'no'
  AND st.statistic_typeFK = 11
  AND st.object_typeFK = 3
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND st.name IS NOT NULL
  AND TRIM(st.name) <> ''
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, statistic_name;


-- ================================================================================
SELECT
    -- CheckID - Cycling-DQ-018
    -- Name - EVENT_RESULTS_RANK_OUTLIER_ABOVE_FIELD_SIZE_APART_FROM_THE_SPLIT_HALVES
    -- What it does: Flags unexplained Ranks above the participant count when there is also a gap from the previous Rank, excluding the halves of a split stage that share one ranking.
    'RANK_OUTLIER_ABOVE_FIELD_SIZE' AS check_type,
    z.event_id,
    z.event_name,
    z.template_name,
    z.participant_count,
    z.affected_count,
-- What it does, stated in full: GLOBAL-DQ-020 for Cycling, minus the one shape in this sport
-- that breaks the rule by design. A split stage is run as two events over the same field and
-- the two halves share a single ranking: `Stage 1b - A teams` and `Stage 1b - B teams` at
-- `Settimana Internazionale Coppi e Bartali` hold 25 teams each and between them exactly the
-- ranks 1 to 50, every rank in one half and not the other. Measured 2026-08-16 over three
-- stages and six events, which are all the events in the sport whose name ends in ` teams`.
-- Reported by the template, that is 6 of 22 findings, none of them a wrong rank. Everything
-- else in GLOBAL-DQ-020 is carried unchanged, including the window that reads the next lower
-- rank across the whole field and the Comment exclusion sitting beside the outlier filter.
    z.ranks_held,
    -- A convenience for the reader, not the finding: GROUP_CONCAT truncates at the server's
    -- group_concat_max_len without saying so, and affected_count is what the row asserts.
    z.affected_participants,
    NULL AS eligible_count,
    0 AS sort_order
FROM (
    SELECT
        y.event_id,
        y.event_name,
        y.template_name,
        MAX(y.participant_count) AS participant_count,
        COUNT(*) AS affected_count,
        GROUP_CONCAT(DISTINCT y.rank_value ORDER BY y.rank_value SEPARATOR ', ') AS ranks_held,
        GROUP_CONCAT(DISTINCT CONCAT(y.participant_name, ' (', y.rank_value, ')')
            ORDER BY CONCAT(y.participant_name, ' (', y.rank_value, ')') SEPARATOR ', ')
            AS affected_participants
    FROM (
    SELECT
        x.event_participants_id,
        x.event_id,
        x.event_name,
        x.template_name,
        x.participant_name,
        x.rank_value,
        x.participant_count,
        x.next_lower_rank
    FROM (
        SELECT
            ep.id AS event_participants_id,
            e.id AS event_id,
            e.name AS event_name,
            tt.name AS template_name,
            p.name AS participant_name,
            CAST(r.value AS UNSIGNED) AS rank_value,
            pc.participant_count,
            MAX(CAST(r.value AS UNSIGNED)) OVER (
                PARTITION BY e.id
                ORDER BY CAST(r.value AS UNSIGNED)
                RANGE BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
            ) AS next_lower_rank
        FROM event_participants ep
        JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
        JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
        JOIN (
            SELECT ep2.eventFK AS eventFK, COUNT(*) AS participant_count
            FROM event_participants ep2
            JOIN event e2 ON e2.id = ep2.eventFK AND e2.del = 'no'
            JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
            JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
            JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
                 AND tt2.sportFK = 30
            WHERE ep2.del = 'no'
            GROUP BY ep2.eventFK
        ) pc ON pc.eventFK = e.id
        JOIN result r ON r.event_participantsFK = ep.id
             AND r.result_typeFK = 100
             AND r.del = 'no'
             AND r.value REGEXP '^[1-9][0-9]*$'
        WHERE ep.del = 'no'
          AND tt.sportFK = 30
          AND e.status_type = 'finished'
          AND e.status_descFK = 6
          -- The one shape in this sport that breaks the rule by design, excluded here and
          -- nowhere else: the two halves of a split stage share one ranking.
          AND e.name NOT LIKE '% teams'
          -- AND t.tournament_templateFK = <tournament_template_id>
          -- AND e.startdate >= '<from_datetime>'
          -- AND e.startdate <  '<to_datetime>'
    ) x
    WHERE x.rank_value > x.participant_count
      AND NOT EXISTS (
          SELECT 1
          FROM result rc
          WHERE rc.event_participantsFK = x.event_participants_id
            AND rc.result_typeFK = 104
            AND rc.del = 'no'
            AND rc.value IS NOT NULL
            AND TRIM(rc.value) <> ''
      )
    ) y
    WHERE y.next_lower_rank IS NULL
       OR y.rank_value > y.next_lower_rank + 1
    GROUP BY y.event_id, y.event_name, y.template_name
) z

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event_participants ep
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN result r ON r.event_participantsFK = ep.id
     AND r.result_typeFK = 100
     AND r.del = 'no'
     AND r.value REGEXP '^[1-9][0-9]*$'
WHERE ep.del = 'no'
  AND tt.sportFK = 30
  AND e.status_type = 'finished'
  AND e.status_descFK = 6
  AND e.name NOT LIKE '% teams'
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, affected_count DESC, event_id;


-- ================================================================================
SELECT
    -- CheckID - Cycling-DQ-050
    -- Name - EVENT_FINAL_PARTICIPANT_NOT_IN_COMP.RANK_APART_FROM_THE_LIVE_UPDATE_PLACEHOLDER
    -- What it does: Flags Final events where Comp.Rank is missing a competitor who took part, ignoring the Peloton placeholder that is never ranked.
    'FINAL_PARTICIPANT_NOT_IN_COMP.RANK' AS check_type,
    x.event_id,
    x.event_name,
    x.template_name,
    x.tournament_name,
    x.field_size,
    x.missing_count,
-- What it does, stated in full: GLOBAL-DQ-042 for Cycling, minus the one entry in this sport
-- that is not a competitor. Peloton, participant 205191, is the live-update mechanism: the
-- feed enters the bunch as one row while a race is running, and it carries no rank and no
-- duration on any of its 576 entries across 575 events. It is therefore absent from every
-- Comp.Rank by design. Measured 2026-08-16, the template reported 21 events of which 17 were
-- Peloton and nothing else, which buried the five events that are missing an actual rider.
-- The exclusion is applied to both branches so the two read one population.
    -- A convenience for the reader, not the finding: GROUP_CONCAT truncates at the server's
    -- group_concat_max_len without saying so, and missing_count is what the row asserts.
    x.missing_participants,
    NULL AS eligible_count
FROM (
    SELECT
        y.event_id,
        y.event_name,
        y.template_name,
        y.tournament_name,
        COUNT(*) AS field_size,
        SUM(y.is_missing) AS missing_count,
        GROUP_CONCAT(CASE WHEN y.is_missing = 1 THEN y.participant_name END
                     ORDER BY y.participant_name SEPARATOR ', ') AS missing_participants
    FROM (
        SELECT
            e.id AS event_id,
            e.name AS event_name,
            tt.name AS template_name,
            t.name AS tournament_name,
            p.name AS participant_name,
            CASE WHEN MAX(CASE WHEN sp.id IS NOT NULL THEN 1 ELSE 0 END) = 0
                 THEN 1 ELSE 0 END AS is_missing
        FROM event e
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
        JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
        JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
        JOIN (
            SELECT DISTINCT
                ex.id AS event_id,
                sx.id AS statistic_id
            FROM statistic_config scx
            JOIN statistic sx ON sx.id = scx.statisticFK
                 AND sx.del = 'no'
                 AND sx.statistic_typeFK = 11
                 AND sx.object_typeFK = 3
            JOIN tournament tx ON tx.id = sx.objectFK AND tx.del = 'no'
            JOIN tournament_template ttx ON ttx.id = tx.tournament_templateFK AND ttx.del = 'no'
                 AND ttx.sportFK = 30
            JOIN tournament_stage tsx ON tsx.tournamentFK = tx.id AND tsx.del = 'no'
            JOIN event ex ON ex.tournament_stageFK = tsx.id AND ex.del = 'no'
                 AND FIND_IN_SET(ex.id, scx.value) > 0
            WHERE scx.statistic_data_typeFK = 1471
              AND scx.del = 'no'
              -- AND tx.tournament_templateFK = <tournament_template_id>
              AND EXISTS (
                  SELECT 1
                  FROM statistic_participants11 spx
                  WHERE spx.statisticFK = sx.id AND spx.del = 'no'
              )
        ) m ON m.event_id = e.id
        LEFT JOIN statistic_participants11 sp ON sp.statisticFK = m.statistic_id
             AND sp.participantFK = ep.participantFK
             AND sp.del = 'no'
        WHERE e.del = 'no'
          AND tt.sportFK = 30
          AND e.round_typeFK IN (173)
          AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
          -- The live-update placeholder, which is never ranked and is not a competitor.
          AND ep.participantFK <> 205191
          -- AND t.tournament_templateFK = <tournament_template_id>
          -- AND e.id BETWEEN <from_event_id> AND <to_event_id>
        GROUP BY e.id, e.name, tt.name, t.name, ep.id, p.name
    ) y
    GROUP BY y.event_id, y.event_name, y.template_name, y.tournament_name
) x
WHERE x.missing_count > 0

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = 30
  AND e.round_typeFK IN (173)
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND ep.participantFK <> 205191
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.id BETWEEN <from_event_id> AND <to_event_id>
  AND e.id IN (
      SELECT ex.id
      FROM statistic_config scx
      JOIN statistic sx ON sx.id = scx.statisticFK
           AND sx.del = 'no'
           AND sx.statistic_typeFK = 11
           AND sx.object_typeFK = 3
      JOIN tournament tx ON tx.id = sx.objectFK AND tx.del = 'no'
      JOIN tournament_template ttx ON ttx.id = tx.tournament_templateFK AND ttx.del = 'no'
           AND ttx.sportFK = 30
      JOIN tournament_stage tsx ON tsx.tournamentFK = tx.id AND tsx.del = 'no'
      JOIN event ex ON ex.tournament_stageFK = tsx.id AND ex.del = 'no'
           AND FIND_IN_SET(ex.id, scx.value) > 0
      WHERE scx.statistic_data_typeFK = 1471
        AND scx.del = 'no'
        -- AND tx.tournament_templateFK = <tournament_template_id>
        AND EXISTS (
            SELECT 1
            FROM statistic_participants11 spx
            WHERE spx.statisticFK = sx.id AND spx.del = 'no'
        )
  )
;


-- ================================================================================
SELECT
    -- CheckID - Cycling-DQ-051
    -- Name - PARTICIPANT_GENDER_CONTRADICTS_STAGE_ENTERED_APART_FROM_THE_LIVE_UPDATE_PLACEHOLDER
    -- What it does: Flags participants whose stored gender conflicts with the gender of a stage they entered, ignoring the Peloton placeholder that enters stages of both genders.
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
    NULL AS eligible_count
-- What it does, stated in full: GLOBAL-DQ-123 for Cycling, minus the one entry in this sport
-- that is not a person. Peloton, participant 205191, is the live-update mechanism: the feed
-- enters the bunch as one row while a race is running. It is stored as a male athlete and is
-- entered in 54 female stages, so it contradicts a stage gender by construction rather than by
-- mistake. Measured 2026-08-16, the template reported 2 rows and that was one of them. The
-- exclusion is applied to both branches so the two read one population.
FROM (
    SELECT
        p.id AS participant_id,
        p.name AS participant_name,
        p.type AS participant_type,
        LOWER(TRIM(p.gender)) AS participant_gender,
        GROUP_CONCAT(DISTINCT LOWER(TRIM(ts.gender))
                     ORDER BY LOWER(TRIM(ts.gender)) SEPARATOR ', ') AS stage_genders,
        COUNT(DISTINCT ep.id) AS entry_count,
        MIN(e.id) AS example_event_id
    FROM event_participants ep
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
    JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    WHERE ep.del = 'no'
      AND tt.sportFK = 30
      AND p.type IN ('athlete', 'team')
      AND ts.gender IS NOT NULL
      AND TRIM(ts.gender) <> ''
      AND LOWER(TRIM(ts.gender)) <> 'undefined'
      AND p.gender IS NOT NULL
      AND TRIM(p.gender) <> ''
      AND LOWER(TRIM(p.gender)) <> LOWER(TRIM(ts.gender))
      AND (p.type <> 'athlete' OR LOWER(TRIM(ts.gender)) <> 'mixed')
      -- The live-update placeholder, which is not a person and enters both genders.
      AND p.id <> 205191
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY p.id, p.name, p.type, LOWER(TRIM(p.gender))
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT p.id) AS eligible_count
FROM event_participants ep
JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE ep.del = 'no'
  AND tt.sportFK = 30
  AND p.type IN ('athlete', 'team')
  AND ts.gender IS NOT NULL
  AND TRIM(ts.gender) <> ''
  AND LOWER(TRIM(ts.gender)) <> 'undefined'
  AND p.gender IS NOT NULL
  AND TRIM(p.gender) <> ''
  AND p.id <> 205191
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;
