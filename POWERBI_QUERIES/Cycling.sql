SELECT
    -- CheckID - Cycling-DQ-001
    -- Name - PARTICIPANT_REGISTERED_BUT_NEVER_ENTERED_IN_THIS_SPORT
    -- What it does: Finds participants registered to cycling that no cycling event or Comp.Rank reaches.
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
    COUNT(DISTINCT p.id) AS eligible_count,
-- Counts the windowed object's own key, so the shardable rule can see what this statement
-- cuts on. It counted op.participantFK until 2026-08-31 - the same number by construction,
-- since the join is p.id = op.participantFK - and the rule could not read it: its pattern was
-- lower-case only against a case-sensitive regex. See GLOBAL-DQ-135 for the full account.
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
    -- What it does: Finds stage names that break a text-hygiene rule, allowing the unspaced hyphen this sport uses.
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
      AND t.tournament_templateFK NOT IN (10350, 10351, 10352, 10353, 12652, 12653, 12654, 12655, 12656, 12657, 12658)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
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
  AND t.tournament_templateFK NOT IN (10350, 10351, 10352, 10353, 12652, 12653, 12654, 12655, 12656, 12657, 12658)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, stage_name;


-- ================================================================================
SELECT
    -- CheckID - Cycling-DQ-010
    -- Name - COMP.RANK_NAME_FORMAT_INVALID_APART_FROM_THE_HYPHEN_CONVENTION
    -- What it does: Finds Comp.Rank names that break a text-hygiene rule, allowing the unspaced hyphen this sport uses.
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
      AND t.tournament_templateFK NOT IN (10350, 10351, 10352, 10353, 12652, 12653, 12654, 12655, 12656, 12657, 12658)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
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
  AND t.tournament_templateFK NOT IN (10350, 10351, 10352, 10353, 12652, 12653, 12654, 12655, 12656, 12657, 12658)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, statistic_name;


-- ================================================================================
SELECT
    -- CheckID - Cycling-DQ-018
    -- Name - EVENT_RESULTS_RANK_OUTLIER_ABOVE_FIELD_SIZE_APART_FROM_THE_SPLIT_HALVES
    -- What it does: Finds unexplained Ranks above the field size that also sit after a gap, skipping the halves of a split stage.
    'RANK_OUTLIER_ABOVE_FIELD_SIZE' AS check_type,
    z.event_id,
    z.event_name,
    z.event_startdate,
    z.template_name,
    -- The edition, carried from GLOBAL-DQ-020 where it was added on 2026-08-17. It matters more
    -- here than anywhere else the template runs: this sport names its events Stage 4, which is
    -- the same string in every tour of every year, so without the tournament a finding row
    -- cannot be placed in time or even in the right race.
    z.tournament_name,
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
        y.event_startdate,
        y.template_name,
        y.tournament_name,
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
        x.event_startdate,
        x.template_name,
        x.tournament_name,
        x.participant_name,
        x.rank_value,
        x.participant_count,
        x.next_lower_rank
    FROM (
        SELECT
            ep.id AS event_participants_id,
            e.id AS event_id,
            e.name AS event_name,
            e.startdate AS event_startdate,
            tt.name AS template_name,
            t.name AS tournament_name,
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
          AND t.tournament_templateFK NOT IN (10350, 10351, 10352, 10353, 12652, 12653, 12654, 12655, 12656, 12657, 12658)
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
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
    GROUP BY y.event_id, y.event_name, y.event_startdate, y.template_name, y.tournament_name
) z

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
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
  AND t.tournament_templateFK NOT IN (10350, 10351, 10352, 10353, 12652, 12653, 12654, 12655, 12656, 12657, 12658)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, affected_count DESC, event_id;


-- ================================================================================
SELECT
    -- CheckID - Cycling-DQ-050
    -- Name - EVENT_FINAL_PARTICIPANT_NOT_IN_COMP.RANK_APART_FROM_THE_LIVE_UPDATE_PLACEHOLDER
    -- What it does: Finds Final events whose Comp.Rank is missing a rider who took part, skipping the Peloton placeholder.
    'FINAL_PARTICIPANT_NOT_IN_COMP.RANK' AS check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
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
        y.event_startdate,
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
            e.startdate AS event_startdate,
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
              AND tx.tournament_templateFK NOT IN (10350, 10351, 10352, 10353, 12652, 12653, 12654, 12655, 12656, 12657, 12658)
              AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(tx.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(tx.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
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
          AND t.tournament_templateFK NOT IN (10350, 10351, 10352, 10353, 12652, 12653, 12654, 12655, 12656, 12657, 12658)
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
          -- AND t.tournament_templateFK = <tournament_template_id>
          -- AND e.id BETWEEN <from_event_id> AND <to_event_id>
        GROUP BY e.id, e.name, e.startdate, tt.name, t.name, ep.id, p.name
    ) y
    GROUP BY y.event_id, y.event_name, y.event_startdate, y.template_name, y.tournament_name
) x
WHERE x.missing_count > 0

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
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
  AND t.tournament_templateFK NOT IN (10350, 10351, 10352, 10353, 12652, 12653, 12654, 12655, 12656, 12657, 12658)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
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
        AND tx.tournament_templateFK NOT IN (10350, 10351, 10352, 10353, 12652, 12653, 12654, 12655, 12656, 12657, 12658)
        AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(tx.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(tx.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
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
    -- What it does: Finds participants whose gender does not match the gender of a stage they entered, skipping the Peloton placeholder.
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
      AND t.tournament_templateFK NOT IN (10350, 10351, 10352, 10353, 12652, 12653, 12654, 12655, 12656, 12657, 12658)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
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
  AND t.tournament_templateFK NOT IN (10350, 10351, 10352, 10353, 12652, 12653, 12654, 12655, 12656, 12657, 12658)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - Cycling-DQ-068
    -- Name - COMP.RANK_SETTINGS_MEDAL_SET_INVALID_WITH_THE_RIDER_AS_THE_MEDAL_HOLDER
    -- What it does: Finds Comp.Rank medals that do not match the places the ranking holds, counting each rider as its own medal holder.
    CASE
-- What it does, stated in full: GLOBAL-DQ-026 for Cycling, with the relay clause removed. The
-- template counts a medal over the team that holds it where the statistic assigns one and over
-- the participant where it does not, written as COALESCE(team_value, participant), so that the
-- four members of a winning relay read as one gold rather than four duplicates. This sport
-- assigns no team value at all - statistic data type 1429 Team is declared for the statistic
-- type and holds nothing here, measured by GLOBAL-DISCOVERY-031 on 2026-08-16 - and it fields
-- no relay, so the second half of that COALESCE is the only half that can ever apply. Keeping
-- the join would have made the template unrunnable for the want of a parameter the sport has
-- recorded as not applicable, while dropping it changes no row the template would have
-- returned. Every threshold, label and comparison below is the template's, unchanged.
        -- Nothing to compare the medals with. The missing Rank is Cycling-DQ-021's finding and
        -- is not restated here; what this row says is that the medal set was not audited.
        WHEN x.ranked_holders = 0 THEN 'Medal_Set_Unreadable_Without_Rank'
        WHEN x.total_medal_count = 0 THEN 'No_Medals_At_All'
        -- A shared place removes the place below it, so a second gold beside a silver is a
        -- contradiction, while a second gold without one is the shape a tie actually takes.
        WHEN x.gold_count > x.rank1_count AND x.silver_count > 0 THEN 'Duplicate_Gold_With_Silver_Present'
        WHEN x.silver_count > x.rank2_count AND x.bronze_count > 0 THEN 'Duplicate_Silver_With_Bronze_Present'
        WHEN x.gold_count > x.rank1_count OR x.silver_count > x.rank2_count THEN 'Duplicate_Medal_Tie_Shape'
        WHEN x.bronze_count > x.rank3_count THEN 'Duplicate_Bronze'
        -- The other side of a tie: the place is shared and carries a medal, but not one for
        -- every competitor standing on it.
        WHEN (x.rank1_count > 1 AND x.gold_count   BETWEEN 1 AND x.rank1_count - 1)
          OR (x.rank2_count > 1 AND x.silver_count BETWEEN 1 AND x.rank2_count - 1)
          OR (x.rank3_count > 1 AND x.bronze_count BETWEEN 1 AND x.rank3_count - 1)
             THEN 'Medal_Missing_For_Shared_Place'
        -- An empty place is only legitimate when a tie above it consumed it: after k
        -- competitors starting at first, the next place is k + 1.
        WHEN x.rank1_count = 0 THEN 'Podium_Without_First_Place'
        WHEN (x.rank1_count = 1 AND x.rank2_count = 0)
          OR (1 + x.rank1_count + x.rank2_count = 3 AND x.rank3_count = 0)
             THEN 'Podium_Truncated_Below_Medal'
        ELSE 'Missing_Specific_Medal'
    END AS check_type,
    x.statistic_id,
    x.statistic_name,
    x.template_name,
    x.tournament_name,
    CONCAT_WS(', ',
        IF(x.rank1_count > 0, CONCAT('1st x', x.rank1_count), NULL),
        IF(x.rank2_count > 0, CONCAT('2nd x', x.rank2_count), NULL),
        IF(x.rank3_count > 0, CONCAT('3rd x', x.rank3_count), NULL)
    ) AS places_held,
    CONCAT_WS(', ',
        IF(x.gold_count   < x.rank1_count, CONCAT('gold ',   x.gold_count,   ' of ', x.rank1_count), NULL),
        IF(x.silver_count < x.rank2_count, CONCAT('silver ', x.silver_count, ' of ', x.rank2_count), NULL),
        IF(x.bronze_count < x.rank3_count, CONCAT('bronze ', x.bronze_count, ' of ', x.rank3_count), NULL)
    ) AS missing_medals,
    CONCAT_WS(', ',
        IF(x.gold_count   > x.rank1_count, CONCAT('gold x',   x.gold_count,   ' for ', x.rank1_count), NULL),
        IF(x.silver_count > x.rank2_count, CONCAT('silver x', x.silver_count, ' for ', x.rank2_count), NULL),
        IF(x.bronze_count > x.rank3_count, CONCAT('bronze x', x.bronze_count, ' for ', x.rank3_count), NULL)
    ) AS duplicated_medals,
    CONCAT('gold=', x.gold_count, ' silver=', x.silver_count, ' bronze=', x.bronze_count,
           ' first=', x.rank1_count, ' second=', x.rank2_count, ' third=', x.rank3_count) AS medal_holder_counts,
    NULL AS eligible_count
FROM (
    SELECT
        s.id AS statistic_id,
        s.name AS statistic_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        -- A place is held by one competitor, and here that competitor is always the rider:
        -- the sport assigns no team value and fields no relay, so there is no group of
        -- people sharing one medal to collapse.
        COUNT(DISTINCT CASE WHEN LOWER(TRIM(sd.value)) = 'gold' THEN sp.id END) AS gold_count,
        COUNT(DISTINCT CASE WHEN LOWER(TRIM(sd.value)) = 'silver' THEN sp.id END) AS silver_count,
        COUNT(DISTINCT CASE WHEN LOWER(TRIM(sd.value)) = 'bronze' THEN sp.id END) AS bronze_count,
        COUNT(DISTINCT CASE WHEN sd.value IS NOT NULL AND TRIM(sd.value) <> ''
             THEN sp.id END) AS total_medal_count,
        COUNT(DISTINCT CASE WHEN rkd.value IS NOT NULL AND TRIM(rkd.value) <> ''
             THEN sp.id END) AS ranked_holders,
        COUNT(DISTINCT CASE WHEN TRIM(rkd.value) = '1' THEN sp.id END) AS rank1_count,
        COUNT(DISTINCT CASE WHEN TRIM(rkd.value) = '2' THEN sp.id END) AS rank2_count,
        COUNT(DISTINCT CASE WHEN TRIM(rkd.value) = '3' THEN sp.id END) AS rank3_count
    FROM statistic s
    JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN statistic_participants11 sp ON sp.statisticFK = s.id AND sp.del = 'no'
    LEFT JOIN statistic_data11 sd
      ON sd.statistic_participants11FK = sp.id
     AND sd.del = 'no'
     AND sd.statistic_data_typeFK = 1277
    LEFT JOIN statistic_data11 rkd
      ON rkd.statistic_participants11FK = sp.id
     AND rkd.del = 'no'
     AND rkd.statistic_data_typeFK = 1270
    WHERE s.del = 'no'
      AND s.statistic_typeFK = 11
      AND s.object_typeFK = 3
      AND tt.sportFK = 30
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      -- Only the templates that award a medal. The five professional ones - 483 and 9764
      -- World Tour 1, 9432 Category Pro, 9481 Category 1, 10356 World Tour 1 Grand Tour -
      -- award none by the nature of the racing, and unnarrowed they made this statement
      -- report 1271 rankings of 1274 for holding no medal, which is a stage race behaving
      -- correctly. The list names every championship and Games in the sport, including the
      -- ten that hold no medal today, because a template is medal-awarding by what it is
      -- rather than by what it currently stores.
      AND t.tournament_templateFK IN (484, 485, 486, 9513, 9870, 9871, 10054, 11046, 11047, 11048, 11049, 11050, 11052, 11054, 11055, 11056, 11057, 11058, 11059, 11060, 11061, 11062, 11063, 11084, 11085, 11086, 11087, 11101, 11121)
      AND t.tournament_templateFK NOT IN (10350, 10351, 10352, 10353, 12652, 12653, 12654, 12655, 12656, 12657, 12658)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
    GROUP BY s.id, s.name, tt.name, t.name
) x
WHERE x.ranked_holders = 0
   OR x.gold_count   <> x.rank1_count
   OR x.silver_count <> x.rank2_count
   OR x.bronze_count <> x.rank3_count
   OR x.rank1_count = 0
   OR (x.rank1_count = 1 AND x.rank2_count = 0)
   OR (1 + x.rank1_count + x.rank2_count = 3 AND x.rank3_count = 0)

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = 11
  AND s.object_typeFK = 3
  AND tt.sportFK = 30
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND t.tournament_templateFK IN (484, 485, 486, 9513, 9870, 9871, 10054, 11046, 11047, 11048, 11049, 11050, 11052, 11054, 11055, 11056, 11057, 11058, 11059, 11060, 11061, 11062, 11063, 11084, 11085, 11086, 11087, 11101, 11121)
  AND t.tournament_templateFK NOT IN (10350, 10351, 10352, 10353, 12652, 12653, 12654, 12655, 12656, 12657, 12658)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - Cycling-DQ-085
    -- Name - EVENT_RESULTS_RANK_INVALID_OR_MISSING_BY_EVENT
    -- What it does: Finds finished events holding riders with no usable place.
    CASE
        WHEN x.rank_not_integer_count > 0 THEN 'EVENT_RANK_NOT_INTEGER'
        WHEN x.rank_over_max_count > 0 THEN 'EVENT_RANK_OVER_MAX'
        WHEN x.no_result_count = x.field_size THEN 'EVENT_WHOLE_FIELD_HOLDS_NO_RESULT'
        WHEN x.no_result_count > 0 THEN 'EVENT_PART_OF_FIELD_HOLDS_NO_RESULT'
        ELSE 'EVENT_RANK_MISSING_WITH_OTHER_RESULT_PRESENT'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.tournament_stage_name,
    x.template_name,
    x.field_size,
    x.affected_count,
    x.rank_not_integer_count,
    x.rank_over_max_count,
    x.no_result_count,
    x.rank_missing_other_result_count,
    x.sample_offence,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds finished events in which a rider ends with no place that
-- can be used - a Rank that is not a plain positive integer, a Rank past the largest field this
-- sport starts, or no Rank and no Comment to explain its absence - and reports the event rather
-- than the rider.
--
-- The audited object is the event because of what the sport does to the numbers. The global
-- template GLOBAL-DQ-036 EVENT_RESULTS_RANK_INVALID_OR_MISSING audits the participation, which
-- is the right object where a field is small: measured 2026-08-16 it returns 1 row on Triathlon,
-- 44 on BMX, 69 on Artistic-Gymnastics and 357 on Modern-Pentathlon, and on all four the rider's
-- name is exactly what a reviewer needs. Cycling starts 92 to 124 riders per event and the same
-- template returns 23930 rows of 1270517 participations, because one unresolved race contributes
-- its entire start list. Folded to the event that is roughly 1400 rows, and the worst of them
-- says 437 riders in one race rather than appearing 437 times. The template keeps its shape for
-- the other four sports and this statement replaces it here only.
--
-- Whole field against part of it is the distinction worth carrying, and it is why the counts
-- travel as named columns instead of one total. A race where every entered rider holds no result
-- of any kind is a start list imported and never resolved - one act, one thing to fix. A race
-- where three riders of 120 hold nothing is three riders to chase. Reported as one number those
-- read the same, and they are not the same work.
--
-- 250 is RANK_MAX_PLAUSIBLE from SPORTS/params.json, written out because a sport statement in
-- this package carries its values rather than placeholders. It is the largest field this sport
-- starts with room over it, not a limit anybody enforces.
--
-- The result rows are read once per participation through a LEFT JOIN and a MAX(CASE) pass
-- rather than by three correlated subqueries per rider. The LEFT JOIN is not cosmetic: a rider
-- carrying no result row at all is precisely what NO_RESULT_OF_ANY_TYPE names, and an inner join
-- would drop the finding it exists to make.
FROM (
    SELECT
        y.event_id,
        MAX(y.event_name) AS event_name,
        MAX(y.event_startdate) AS event_startdate,
        MAX(y.tournament_stage_name) AS tournament_stage_name,
        MAX(y.template_name) AS template_name,
        COUNT(DISTINCT y.ep_id) AS field_size,
        COUNT(DISTINCT CASE WHEN y.offence IS NOT NULL THEN y.ep_id END) AS affected_count,
        COUNT(DISTINCT CASE WHEN y.offence = 'RANK_NOT_INTEGER' THEN y.ep_id END) AS rank_not_integer_count,
        COUNT(DISTINCT CASE WHEN y.offence = 'RANK_OVER_MAX' THEN y.ep_id END) AS rank_over_max_count,
        COUNT(DISTINCT CASE WHEN y.offence = 'NO_RESULT_OF_ANY_TYPE' THEN y.ep_id END) AS no_result_count,
        COUNT(DISTINCT CASE WHEN y.offence = 'RANK_AND_COMMENT_MISSING_OTHER_RESULT_PRESENT' THEN y.ep_id END) AS rank_missing_other_result_count,
        MIN(CASE WHEN y.offence IS NOT NULL
                 THEN CONCAT(y.participant_name, ' - ', y.offence,
                             COALESCE(CONCAT(', rank = ', y.rank_raw), ''))
            END) AS sample_offence
    FROM (
        SELECT
            g.ep_id,
            g.event_id,
            g.event_name,
            g.event_startdate,
            g.tournament_stage_name,
            g.template_name,
            g.participant_name,
            g.rank_raw,
            CASE
                WHEN g.rank_raw IS NOT NULL AND g.rank_raw NOT REGEXP '^[1-9][0-9]*$'
                     THEN 'RANK_NOT_INTEGER'
                WHEN g.rank_raw IS NOT NULL AND CAST(g.rank_raw AS UNSIGNED) > 250
                     THEN 'RANK_OVER_MAX'
                WHEN g.rank_raw IS NULL AND g.comment_raw IS NULL AND g.has_any_result = 0
                     THEN 'NO_RESULT_OF_ANY_TYPE'
                WHEN g.rank_raw IS NULL AND g.comment_raw IS NULL
                     THEN 'RANK_AND_COMMENT_MISSING_OTHER_RESULT_PRESENT'
            END AS offence
        FROM (
            SELECT
                ep.id AS ep_id,
                e.id AS event_id,
                e.name AS event_name,
                e.startdate AS event_startdate,
                ts.name AS tournament_stage_name,
                tt.name AS template_name,
                p.name AS participant_name,
                NULLIF(TRIM(MAX(CASE WHEN r.result_typeFK = 100 THEN r.value END)), '') AS rank_raw,
                NULLIF(TRIM(MAX(CASE WHEN r.result_typeFK = 104 THEN r.value END)), '') AS comment_raw,
                MAX(CASE WHEN r.value IS NOT NULL AND TRIM(r.value) <> '' THEN 1 ELSE 0 END) AS has_any_result
            FROM event_participants ep
            JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
            JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
            JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
            JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
                 AND tt.sportFK = 30
            JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
            LEFT JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
            WHERE ep.del = 'no'
              AND e.del = 'no'
              AND e.status_type = 'finished'
              AND e.status_descFK = 6
              AND t.tournament_templateFK NOT IN (10350, 10351, 10352, 10353, 12652, 12653, 12654, 12655, 12656, 12657, 12658)
              AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
              -- AND t.tournament_templateFK = <tournament_template_id>
              -- AND e.startdate >= '<from_datetime>'
              -- AND e.startdate <  '<to_datetime>'
            GROUP BY ep.id, e.id, e.name, e.startdate, ts.name, tt.name, p.name
        ) g
    ) y
    GROUP BY y.event_id
    HAVING affected_count > 0
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
-- Coverage counts the finished events that hold at least one entered rider, which is the
-- population the findings branch reads. An event nobody entered cannot hold a rider with no
-- place, and counting it would say the check looked somewhere it did not.
FROM event_participants ep
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 30
WHERE ep.del = 'no'
  AND e.status_type = 'finished'
  AND e.status_descFK = 6
  AND t.tournament_templateFK NOT IN (10350, 10351, 10352, 10353, 12652, 12653, 12654, 12655, 12656, 12657, 12658)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, affected_count DESC, event_id;

-- ================================================================================
SELECT
    -- CheckID - Cycling-DQ-095
    -- Name - EVENT_AVERAGE_SPEED_IMPLAUSIBLE
    -- What it does: Flags finished races where the distance and the winning time give a speed no bicycle race reaches.
    CASE WHEN g.kmh < 15 THEN 'AVERAGE_SPEED_TOO_LOW' ELSE 'AVERAGE_SPEED_TOO_HIGH' END AS check_type,
    g.event_id,
    g.event_name,
    g.template_name,
    g.tournament_stage_name,
    g.event_startdate,
    g.distance_km,
    g.winning_time,
    ROUND(g.kmh, 2) AS average_kmh,
    NULL AS eligible_count
-- What it does, stated in full: Divides the Kilometers property by the winner's Duration and
-- reports the race where the answer is below 15 km/h or above 60. Neither field is checked
-- anywhere else against the other, and each is the only witness the other has: a distance
-- typed with a digit too many and a time typed with one too few produce the same row here and
-- nowhere else in the package.
--
-- The bands were measured over the sport on 2026-08-16 before the thresholds were set. Of 7939
-- races where both values parse, 7771 fall between 30 and 50 km/h, which is road racing; 109
-- sit between 50 and 60, which is a short time trial; and 20 between 15 and 30, which is a
-- mountain stage. Outside those, 7 races run below 15 km/h - the slowest at 0.67 - and 32 above
-- 60, the fastest at 100.7. The two grey bands are deliberately not reported: a 55 km/h prologue
-- and a 28 km/h mountain-top finish are both real, and a check that reports them buries the 39
-- that cannot be.
--
-- Only the winner is read. Every other rider carries a gap rather than an absolute time - the
-- leader/gap convention this sport writes, recorded in SPORTS/Cycling.md - so the winner is the
-- one row from which a speed can be computed at all.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        tt.name AS template_name,
        ts.name AS tournament_stage_name,
        e.startdate AS event_startdate,
        CAST(pr.value AS DECIMAL(10,2)) AS distance_km,
        w.value AS winning_time,
        CAST(pr.value AS DECIMAL(10,2)) /
            ( CAST(SUBSTRING_INDEX(w.value, ':', 1) AS DECIMAL(12,4))
            + CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(w.value, ':', 2), ':', -1) AS DECIMAL(12,4)) / 60
            + CAST(SUBSTRING_INDEX(w.value, ':', -1) AS DECIMAL(12,4)) / 3600 ) AS kmh
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = 30
    -- The distance, as the sport writes it: a metadata property on the event rather than a
    -- column. A value that is not a plain positive number cannot be divided and is left to
    -- Cycling-DQ-096, which reads the malformed distances in the checkpoint layer.
    JOIN property pr ON pr.object = 'event' AND pr.objectFK = e.id AND pr.del = 'no'
         AND pr.name = 'Kilometers'
         AND pr.value REGEXP '^[0-9]+(\\.[0-9]+)?$'
         AND CAST(pr.value AS DECIMAL(10,2)) > 0
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    JOIN result rk ON rk.event_participantsFK = ep.id AND rk.result_typeFK = 100 AND rk.del = 'no'
         AND TRIM(rk.value) = '1'
    -- h:mm:ss only. A prologue written mm:ss is a different shape and reading it as hours
    -- would report every one of them; those races are simply not covered here and the
    -- coverage branch counts the same population so the proportion says so.
    JOIN result w ON w.event_participantsFK = ep.id AND w.result_typeFK = 101 AND w.del = 'no'
         AND w.value REGEXP '^[0-9]+:[0-5][0-9]:[0-5][0-9]$'
    WHERE e.del = 'no'
      AND e.status_type = 'finished'
      AND t.tournament_templateFK NOT IN (10350, 10351, 10352, 10353, 12652, 12653, 12654, 12655, 12656, 12657, 12658)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
) g
WHERE g.kmh < 15 OR g.kmh > 60

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 30
JOIN property pr ON pr.object = 'event' AND pr.objectFK = e.id AND pr.del = 'no'
     AND pr.name = 'Kilometers'
     AND pr.value REGEXP '^[0-9]+(\\.[0-9]+)?$'
     AND CAST(pr.value AS DECIMAL(10,2)) > 0
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
JOIN result rk ON rk.event_participantsFK = ep.id AND rk.result_typeFK = 100 AND rk.del = 'no'
     AND TRIM(rk.value) = '1'
JOIN result w ON w.event_participantsFK = ep.id AND w.result_typeFK = 101 AND w.del = 'no'
     AND w.value REGEXP '^[0-9]+:[0-5][0-9]:[0-5][0-9]$'
WHERE e.del = 'no'
  AND e.status_type = 'finished'
  AND t.tournament_templateFK NOT IN (10350, 10351, 10352, 10353, 12652, 12653, 12654, 12655, 12656, 12657, 12658)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
;


-- ================================================================================
SELECT
    -- CheckID - Cycling-DQ-096
    -- Name - EVENT_SCOPE_CHECKPOINT_CHAIN_INCONSISTENT
    -- What it does: Flags checkpoints along a course whose distance, remaining distance, finish marker or jersey group cannot be read as written.
    x.check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.template_name,
    x.tournament_stage_name,
    x.offending_rows,
    x.sample_value,
    NULL AS eligible_count
-- What it does, stated in full: Audits the checkpoint chain this sport writes under event_scope
-- and nothing else does. Four shapes, each measured on 2026-08-16 before being written:
--   * a remaining distance below zero, 7 rows over 6 events, the worst at -4.0 km;
--   * a jersey group left blank, 247 rows over 86 events, where every other row names either
--     Peloton or a breakaway group numbered 1 to 13;
--   * more than one finish line in a race, 2 rows over 1 event;
--   * a distance that is neither a number with its unit nor the word Finish, 146 rows over 11
--     events, including 64..0 km with two decimal points.
-- The event is the audited object rather than the checkpoint, because a chain written wrong is
-- written wrong at once; offending_rows carries how far it reaches.
--
-- GLOBAL-DQ-102 already asserts that a scope result points at a participant of its own event and
-- returns nothing here, so the layer is referentially sound; what it cannot see is whether the
-- values inside it make sense as a course. GLOBAL-DQ-107 is Not applicable for this sport
-- because no scope type stands for the whole race - the 193 types are checkpoint1 to
-- checkpoint192 plus an unnamed 0 - which is the same reason this statement had to be written
-- rather than carried.
FROM (
    SELECT
        g.check_type,
        g.event_id,
        MAX(g.event_name) AS event_name,
        MAX(g.event_startdate) AS event_startdate,
        MAX(g.template_name) AS template_name,
        MAX(g.tournament_stage_name) AS tournament_stage_name,
        COUNT(*) AS offending_rows,
        MIN(g.offending_value) AS sample_value
    FROM (
        SELECT
            CASE
                WHEN esd.name = 'distance_to_go' THEN 'CHECKPOINT_DISTANCE_TO_GO_NEGATIVE'
                WHEN esd.name LIKE '%jersey group' THEN 'CHECKPOINT_JERSEY_GROUP_BLANK'
                ELSE 'CHECKPOINT_DISTANCE_MALFORMED'
            END AS check_type,
            e.id AS event_id,
            e.name AS event_name,
            e.startdate AS event_startdate,
            tt.name AS template_name,
            ts.name AS tournament_stage_name,
            CONCAT(esd.name, ' = ', COALESCE(esd.value, '')) AS offending_value
        FROM event_scope es
        JOIN event e ON e.id = es.eventFK AND e.del = 'no'
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
             AND tt.sportFK = 30
        JOIN event_scope_detail esd ON esd.event_scopeFK = es.id AND esd.del = 'no'
        WHERE es.del = 'no'
          AND t.tournament_templateFK NOT IN (10350, 10351, 10352, 10353, 12652, 12653, 12654, 12655, 12656, 12657, 12658)
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
          -- AND t.tournament_templateFK = <tournament_template_id>
          AND (
              (esd.name = 'distance_to_go' AND esd.value LIKE '-%')
              OR
              (esd.name LIKE '%jersey group' AND (esd.value IS NULL OR TRIM(esd.value) = ''))
              OR
              (esd.name = 'distance'
               AND esd.value NOT REGEXP '^[0-9]+(\\.[0-9]+)? km$'
               AND esd.value <> 'Finish')
          )
    ) g
    GROUP BY g.check_type, g.event_id

    UNION ALL

    SELECT
        'CHECKPOINT_MORE_THAN_ONE_FINISH_LINE' AS check_type,
        f.event_id,
        MAX(f.event_name),
        MAX(f.event_startdate),
        MAX(f.template_name),
        MAX(f.tournament_stage_name),
        COUNT(*) AS offending_rows,
        CONCAT('finish_line written ', COUNT(*), ' times') AS sample_value
    FROM (
        SELECT
            e.id AS event_id,
            e.name AS event_name,
            e.startdate AS event_startdate,
            tt.name AS template_name,
            ts.name AS tournament_stage_name
        FROM event_scope es
        JOIN event e ON e.id = es.eventFK AND e.del = 'no'
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
             AND tt.sportFK = 30
        JOIN event_scope_detail esd ON esd.event_scopeFK = es.id AND esd.del = 'no'
             AND esd.name = 'distance_type' AND esd.value = 'finish_line'
        WHERE es.del = 'no'
          AND t.tournament_templateFK NOT IN (10350, 10351, 10352, 10353, 12652, 12653, 12654, 12655, 12656, 12657, 12658)
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
          -- AND t.tournament_templateFK = <tournament_template_id>
    ) f
    GROUP BY f.event_id
    HAVING COUNT(*) > 1
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT es.eventFK) AS eligible_count
FROM event_scope es
JOIN event e ON e.id = es.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 30
JOIN event_scope_detail esd ON esd.event_scopeFK = es.id AND esd.del = 'no'
WHERE es.del = 'no'
  AND t.tournament_templateFK NOT IN (10350, 10351, 10352, 10353, 12652, 12653, 12654, 12655, 12656, 12657, 12658)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - Cycling-DQ-097
    -- Name - EVENT_SPLIT_STAGE_HALF_WITHOUT_ITS_SIBLING
    -- What it does: Flags a lettered half of a split stage that stands alone, with no other half beside it.
    'SPLIT_STAGE_HALF_WITHOUT_SIBLING' AS check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.template_name,
    x.tournament_stage_id,
    x.tournament_stage_name,
    x.stage_number,
    x.half_letter,
    NULL AS eligible_count
-- What it does, stated in full: A split stage is one day's racing run as two events, and this
-- sport writes them as a number and a letter - Stage 1a and Stage 1b, Stage 8a and Stage 8b,
-- Stage 5A and Stage 5B, Stage 1b - A teams and Stage 1b - B teams. A half with no sibling is
-- either a missing import or a stage lettered by mistake. Measured 2026-08-16: 1 of 30 lettered
-- events, Stage 3b at Vuelta Ciclista a la Provincia de San Juan with no Stage 3a.
--
-- The number and the letter are cut out with SUBSTRING and CAST rather than a REGEXP_REPLACE
-- backreference, which does not survive this package's execution path: \1 arrives at the server
-- as a literal 1 and every name parses to the same value. Found on 2026-08-16 while writing
-- this statement, and the first draft reported every half as an orphan because of it.
-- The letter is lowered before comparison, because the sport writes both cases.
FROM (
    SELECT
        ts.id AS tournament_stage_id,
        ts.name AS tournament_stage_name,
        tt.name AS template_name,
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        CAST(SUBSTRING(e.name, 7) AS UNSIGNED) AS stage_number,
        LOWER(SUBSTRING(REGEXP_REPLACE(e.name, '^Stage [0-9]+', ''), 1, 1)) AS half_letter
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = 30
    WHERE e.del = 'no'
      AND e.name REGEXP '^Stage [0-9]+[ABab]([^A-Za-z0-9]|$)'
      AND t.tournament_templateFK NOT IN (10350, 10351, 10352, 10353, 12652, 12653, 12654, 12655, 12656, 12657, 12658)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
) x
LEFT JOIN (
    SELECT
        e2.tournament_stageFK AS tournament_stage_id,
        CAST(SUBSTRING(e2.name, 7) AS UNSIGNED) AS stage_number,
        LOWER(SUBSTRING(REGEXP_REPLACE(e2.name, '^Stage [0-9]+', ''), 1, 1)) AS half_letter,
        COUNT(*) AS held
    FROM event e2
    WHERE e2.del = 'no'
      AND e2.name REGEXP '^Stage [0-9]+[ABab]([^A-Za-z0-9]|$)'
    GROUP BY e2.tournament_stageFK, stage_number, half_letter
) sib
  ON sib.tournament_stage_id = x.tournament_stage_id
 AND sib.stage_number = x.stage_number
 AND sib.half_letter <> x.half_letter
WHERE sib.held IS NULL

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 30
WHERE e.del = 'no'
  AND e.name REGEXP '^Stage [0-9]+[ABab]([^A-Za-z0-9]|$)'
  AND t.tournament_templateFK NOT IN (10350, 10351, 10352, 10353, 12652, 12653, 12654, 12655, 12656, 12657, 12658)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - Cycling-DQ-098
    -- Name - EVENT_RIDER_OLDER_THAN_THE_STAGE_AGE_CLASS_ALLOWS
    -- What it does: Flags races run under an age class whose field contains a rider too old for it.
    'RIDER_OVER_THE_AGE_CLASS_CEILING' AS check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.template_name,
    x.tournament_stage_name,
    x.age_class_name,
    COUNT(DISTINCT x.participant_id) AS over_age_riders,
    -- A convenience for the reader, not the finding: GROUP_CONCAT truncates at the server's
    -- group_concat_max_len without saying so, and over_age_riders is what the row asserts.
    GROUP_CONCAT(DISTINCT CONCAT(x.participant_name, ' aged ', x.age_in_the_year)
                 ORDER BY x.participant_name SEPARATOR ', ') AS over_age_participants,
    NULL AS eligible_count
-- What it does, stated in full: The sport attaches an age class to the stage through
-- object_relation 4 -> 151, and stores each rider's date of birth as a participant property.
-- Read together they say whether the field matches the race, and nothing in the package reads
-- them together.
--
-- The two ceilings come from the data and not from the labels, which is the whole difficulty
-- here. Measured 2026-08-16 across every JUNIOR and YOUTH stage: the JUNIOR class is attached to
-- the World Championship U23 races, and its field is 419 riders aged 19, 669 aged 20, 844 aged
-- 21 and 911 aged 22 - so JUNIOR means under 23 in this database whatever the word says, and a
-- ceiling of 18 taken from the UCI would report 2843 riders racing correctly. YOUTH sits on the
-- European Youth Olympic Festival and the Youth Olympics with 98 riders aged 15, 350 aged 16,
-- 36 aged 17 and 44 aged 18.
--
-- Above those two ceilings there are 13 riders, and they are not borderline: ten over the U23
-- line including Raimondas Rumsas, born 1972, in a U23 World Championship road race, and three
-- over the YOUTH line including Benjamin Noval, born 1979, at a European Youth Olympic Festival.
-- Age is counted as the year of the race minus the year of birth, which is how cycling defines a
-- category, rather than as a birthday that may not have come round yet.
--
-- The event is the audited object rather than the rider, because a field imported into the
-- wrong race is one fault and not one per name in it.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        tt.name AS template_name,
        ts.name AS tournament_stage_name,
        ac.name AS age_class_name,
        p.id AS participant_id,
        p.name AS participant_name,
        YEAR(e.startdate) - YEAR(STR_TO_DATE(pr.value, '%Y-%m-%d')) AS age_in_the_year
    FROM object_relation orr
    JOIN tournament_age_class ac ON ac.id = orr.rel_objectFK
    JOIN tournament_stage ts ON ts.id = orr.objectFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = 30
    JOIN event e ON e.tournament_stageFK = ts.id AND e.del = 'no'
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no' AND p.type = 'athlete'
    JOIN property pr ON pr.object = 'participant' AND pr.objectFK = p.id AND pr.del = 'no'
         AND pr.name = 'date_of_birth'
         AND pr.value REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
    WHERE orr.del = 'no'
      AND orr.object_typeFK = 4
      AND orr.rel_object_typeFK = 151
      AND ac.name IN ('JUNIOR', 'YOUTH')
      AND t.tournament_templateFK NOT IN (10350, 10351, 10352, 10353, 12652, 12653, 12654, 12655, 12656, 12657, 12658)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
) x
WHERE (x.age_class_name = 'JUNIOR' AND x.age_in_the_year > 22)
   OR (x.age_class_name = 'YOUTH'  AND x.age_in_the_year > 18)
GROUP BY x.event_id, x.event_name, x.event_startdate, x.template_name, x.tournament_stage_name, x.age_class_name

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count
FROM object_relation orr
JOIN tournament_age_class ac ON ac.id = orr.rel_objectFK
JOIN tournament_stage ts ON ts.id = orr.objectFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 30
JOIN event e ON e.tournament_stageFK = ts.id AND e.del = 'no'
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
JOIN participant p ON p.id = ep.participantFK AND p.del = 'no' AND p.type = 'athlete'
JOIN property pr ON pr.object = 'participant' AND pr.objectFK = p.id AND pr.del = 'no'
     AND pr.name = 'date_of_birth'
     AND pr.value REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
WHERE orr.del = 'no'
  AND orr.object_typeFK = 4
  AND orr.rel_object_typeFK = 151
  AND ac.name IN ('JUNIOR', 'YOUTH')
  AND t.tournament_templateFK NOT IN (10350, 10351, 10352, 10353, 12652, 12653, 12654, 12655, 12656, 12657, 12658)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - Cycling-DQ-099
    -- Name - COMP.RANK_CLASSIFIES_A_RIDER_WHO_ABANDONED
    -- What it does: Flags rankings that give a place to a rider who did not finish an event that same ranking covers.
    'CLASSIFIED_AFTER_ABANDONING' AS check_type,
    x.statistic_id,
    x.statistic_name,
    x.template_name,
    x.tournament_name,
    COUNT(DISTINCT x.participant_id) AS riders,
    -- A convenience for the reader, not the finding: GROUP_CONCAT truncates at the server's
    -- group_concat_max_len without saying so, and riders is what the row asserts.
    GROUP_CONCAT(DISTINCT CONCAT(x.participant_name, ' placed ', x.rank_value,
                                 ' but ', x.comment_value, ' on event ', x.event_id,
                                 ' of ', DATE(x.event_startdate))
                 ORDER BY x.participant_name SEPARATOR ' | ') AS contradicted_riders,
    NULL AS eligible_count
-- What it does, stated in full: A rider who abandons is out of the classification - that is what
-- abandoning means in this sport, on a one-day race and in a general classification alike. This
-- reports a rider holding a numeric place in a Comp.Rank while carrying DNF or DNS on an event
-- the same Comp.Rank names in its Event id setting.
--
-- The link through the Event id setting is what makes the rule true, and the first draft did not
-- have it. Asked against every event of the tournament instead, the statement reported 700 riders
-- across every championship template, all of them correct: a championship holds a road race and a
-- time trial, and abandoning one has nothing to do with a placing in the other. Tied to the
-- events a ranking actually covers, measured 2026-08-16, it reports nothing at all - the sport is
-- clean on this - and the check is kept for the invariant rather than for a population.
--
-- FIND_IN_SET because the Event id config holds a comma-separated list, which DATABASE.md
-- DB-SEM-011 owns; a numeric cast would read only the id before the first comma.
FROM (
    SELECT
        s.id AS statistic_id,
        s.name AS statistic_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        p.id AS participant_id,
        p.name AS participant_name,
        TRIM(rk.value) AS rank_value,
        UPPER(TRIM(cm.value)) AS comment_value,
        e2.id AS event_id,
        e2.startdate AS event_startdate
    FROM statistic s
    JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = 30
    JOIN statistic_config sc ON sc.statisticFK = s.id AND sc.statistic_data_typeFK = 1471
         AND sc.del = 'no'
    JOIN statistic_participants11 sp ON sp.statisticFK = s.id AND sp.del = 'no'
    JOIN participant p ON p.id = sp.participantFK AND p.del = 'no'
    JOIN statistic_data11 rk ON rk.statistic_participants11FK = sp.id
         AND rk.statistic_data_typeFK = 1270 AND rk.del = 'no'
         AND TRIM(rk.value) REGEXP '^[0-9]+$'
    JOIN event e2 ON FIND_IN_SET(e2.id, sc.value) > 0 AND e2.del = 'no'
    JOIN event_participants ep2 ON ep2.eventFK = e2.id AND ep2.del = 'no'
         AND ep2.participantFK = sp.participantFK
    JOIN result cm ON cm.event_participantsFK = ep2.id AND cm.result_typeFK = 104
         AND cm.del = 'no'
         AND LOWER(TRIM(cm.value)) IN ('dnf', 'dns')
    WHERE s.del = 'no'
      AND s.statistic_typeFK = 11
      AND s.object_typeFK = 3
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      AND t.tournament_templateFK NOT IN (10350, 10351, 10352, 10353, 12652, 12653, 12654, 12655, 12656, 12657, 12658)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
) x
GROUP BY x.statistic_id, x.statistic_name, x.template_name, x.tournament_name

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 30
JOIN statistic_config sc ON sc.statisticFK = s.id AND sc.statistic_data_typeFK = 1471
     AND sc.del = 'no'
JOIN statistic_participants11 sp ON sp.statisticFK = s.id AND sp.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = 11
  AND s.object_typeFK = 3
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND t.tournament_templateFK NOT IN (10350, 10351, 10352, 10353, 12652, 12653, 12654, 12655, 12656, 12657, 12658)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
;


-- ================================================================================
SELECT
    -- CheckID - Cycling-DQ-100
    -- Name - TOURNAMENT_STAGE_NUMBERS_NOT_CONTIGUOUS
    -- What it does: Flags stage races whose numbered stages skip a number between the first and the last.
    'STAGE_NUMBERS_SKIP_A_VALUE' AS check_type,
    g.tournament_stage_id,
    g.tournament_stage_name,
    g.template_name,
    g.tournament_name,
    g.lowest_number,
    g.highest_number,
    g.numbers_held_count,
    g.numbers_held,
    NULL AS eligible_count
-- What it does, stated in full: A tour runs its stages consecutively, so the numbers between the
-- first and the last are all present. A hole is a stage nobody imported.
--
-- The lettered halves are counted towards their own number, and getting that wrong is what a
-- first draft did: reading only names of the exact shape 'Stage N', it reported 9 tours as
-- holding a gap - Tour of Britain at 1,2,3,4,5,6,8 and Circuit Sarthe at 1,3,4 among them - and
-- every one of the nine was a split stage whose halves are named Stage 3a and Stage 3b. Counted
-- properly the sport reports nothing at all, measured 2026-08-16, which is the answer rather
-- than a failure: this sport numbers its stages correctly.
--
-- Kept for the invariant. A tour that loses a stage in an import will show here on the day it
-- happens, and there is no other statement in the package that would notice.
--
-- Only races with more than two numbered stages are read, because two stages cannot skip
-- anything and a one-day race numbers nothing.
FROM (
    SELECT
        ts.id AS tournament_stage_id,
        ts.name AS tournament_stage_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        MIN(CAST(SUBSTRING(e.name, 7) AS UNSIGNED)) AS lowest_number,
        MAX(CAST(SUBSTRING(e.name, 7) AS UNSIGNED)) AS highest_number,
        COUNT(DISTINCT CAST(SUBSTRING(e.name, 7) AS UNSIGNED)) AS numbers_held_count,
        GROUP_CONCAT(DISTINCT CAST(SUBSTRING(e.name, 7) AS UNSIGNED)
                     ORDER BY CAST(SUBSTRING(e.name, 7) AS UNSIGNED) SEPARATOR ',') AS numbers_held
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = 30
    WHERE e.del = 'no'
      AND e.name REGEXP '^Stage [0-9]+'
      AND t.tournament_templateFK NOT IN (10350, 10351, 10352, 10353, 12652, 12653, 12654, 12655, 12656, 12657, 12658)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
    GROUP BY ts.id, ts.name, tt.name, t.name
    HAVING numbers_held_count > 2
       AND highest_number - lowest_number + 1 > numbers_held_count
) g

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT c.tournament_stage_id) AS eligible_count
FROM (
    SELECT ts.id AS tournament_stage_id
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = 30
    WHERE e.del = 'no'
      AND e.name REGEXP '^Stage [0-9]+'
      AND t.tournament_templateFK NOT IN (10350, 10351, 10352, 10353, 12652, 12653, 12654, 12655, 12656, 12657, 12658)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
    GROUP BY ts.id
    HAVING COUNT(DISTINCT CAST(SUBSTRING(e.name, 7) AS UNSIGNED)) > 2
) c
;
