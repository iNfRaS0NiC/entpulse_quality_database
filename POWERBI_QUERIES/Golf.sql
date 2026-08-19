SELECT
    -- CheckID - Golf-DQ-085
    -- Name - COMP.RANK_SETTINGS_MEDAL_SET_INVALID_IN_MEDAL_TEMPLATE
    -- What it does: Finds Golf Comp.Rank medals that do not match the places the ranking holds.
    CASE
-- What it does, stated in full: Finds Comp.Rank under a Golf template that awards medals
-- whose medal set does not follow the places its own Rank rows hold: a type missing, held by
-- more competitors than the place takes, held by fewer, or standing over a podium that never
-- reaches the place it belongs to.
        -- Nothing to compare the medals with. The missing Rank is Golf-DQ-001's finding and
        -- is not restated here; what this row says is that the medal set was not audited.
        WHEN x.ranked_holders = 0 THEN 'Medal_Set_Unreadable_Without_Rank'
        WHEN x.total_medal_count = 0 THEN 'No_Medals_At_All'
        -- A shared place removes the place below it, so a second gold beside a silver is a
        -- contradiction, while a second gold without one is the shape a tie actually takes.
        WHEN x.gold_count > x.rank1_count AND x.silver_count > 0 THEN 'Duplicate_Gold_With_Silver_Present'
        WHEN x.silver_count > x.rank2_count AND x.bronze_count > 0 THEN 'Duplicate_Silver_With_Bronze_Present'
        WHEN x.gold_count > x.rank1_count OR x.silver_count > x.rank2_count THEN 'Duplicate_Medal_Tie_Shape'
        WHEN x.bronze_count > x.rank3_count THEN 'Duplicate_Bronze'
        WHEN (x.rank1_count > 1 AND x.gold_count   BETWEEN 1 AND x.rank1_count - 1)
          OR (x.rank2_count > 1 AND x.silver_count BETWEEN 1 AND x.rank2_count - 1)
          OR (x.rank3_count > 1 AND x.bronze_count BETWEEN 1 AND x.rank3_count - 1)
             THEN 'Medal_Missing_For_Shared_Place'
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
    NULL AS eligible_count,
    0 AS sort_order
-- GLOBAL-DQ-026 narrowed to the thirteen Golf templates that award medals, and the reason it
-- could not stay global. That template audits every Comp.Rank the sport holds, and Golf's are
-- tournament classifications: 3286 of its 3491 were reported, almost all of them
-- 'No_Medals_At_All' on a competition that awards none. Adding the template list to the
-- template itself would have taken the check away from the six other sports running it, which
-- declare no such list, so the narrowing lives here instead.
--
-- The list is Golf's MEDAL_TEMPLATE_ID_LIST, written out because a sport statement carries its
-- own values. It must be kept the same as the parameter: GLOBAL-DQ-125 asserts the negative
-- half of the same rule - no medal outside these templates - and the two are only coherent
-- while they read the same thirteen. Golf-DQ-044 held the global template and is deprecated.
--
-- Golf writes no row into the 1429 Team field, so the relay-team collapse below always falls
-- back to the participant. The join is kept rather than removed because the field is declared
-- for shard 11 and unused rather than absent, and the day a team medal is written the count
-- has to be over teams; the scope here is small enough that keeping it costs nothing.
FROM (
    SELECT
        s.id AS statistic_id,
        s.name AS statistic_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        -- A place is held by one competitor, and in a relay that competitor is the team.
        -- Counting medal rows instead would read every member of a winning team as a
        -- duplicate gold, so each medal is counted over distinct teams where the statistic
        -- assigns one, and over distinct participants where it does not.
        COUNT(DISTINCT CASE WHEN LOWER(TRIM(sd.value)) = 'gold'
             THEN COALESCE(TRIM(tmd.value), CONCAT('p', sp.id)) END) AS gold_count,
        COUNT(DISTINCT CASE WHEN LOWER(TRIM(sd.value)) = 'silver'
             THEN COALESCE(TRIM(tmd.value), CONCAT('p', sp.id)) END) AS silver_count,
        COUNT(DISTINCT CASE WHEN LOWER(TRIM(sd.value)) = 'bronze'
             THEN COALESCE(TRIM(tmd.value), CONCAT('p', sp.id)) END) AS bronze_count,
        COUNT(DISTINCT CASE WHEN sd.value IS NOT NULL AND TRIM(sd.value) <> ''
             THEN COALESCE(TRIM(tmd.value), CONCAT('p', sp.id)) END) AS total_medal_count,
        COUNT(DISTINCT CASE WHEN rkd.value IS NOT NULL AND TRIM(rkd.value) <> ''
             THEN COALESCE(TRIM(tmd.value), CONCAT('p', sp.id)) END) AS ranked_holders,
        COUNT(DISTINCT CASE WHEN TRIM(rkd.value) = '1'
             THEN COALESCE(TRIM(tmd.value), CONCAT('p', sp.id)) END) AS rank1_count,
        COUNT(DISTINCT CASE WHEN TRIM(rkd.value) = '2'
             THEN COALESCE(TRIM(tmd.value), CONCAT('p', sp.id)) END) AS rank2_count,
        COUNT(DISTINCT CASE WHEN TRIM(rkd.value) = '3'
             THEN COALESCE(TRIM(tmd.value), CONCAT('p', sp.id)) END) AS rank3_count
    FROM statistic s
    JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN statistic_participants11 sp ON sp.statisticFK = s.id AND sp.del = 'no'
    LEFT JOIN statistic_data11 sd
      ON sd.statistic_participants11FK = sp.id
     AND sd.del = 'no'
     AND sd.statistic_data_typeFK = 1277
    LEFT JOIN statistic_data11 tmd
      ON tmd.statistic_participants11FK = sp.id
     AND tmd.del = 'no'
     AND tmd.statistic_data_typeFK = 1429
     AND tmd.value IS NOT NULL
     AND TRIM(tmd.value) <> ''
    LEFT JOIN statistic_data11 rkd
      ON rkd.statistic_participants11FK = sp.id
     AND rkd.del = 'no'
     AND rkd.statistic_data_typeFK = 1270
    WHERE s.del = 'no'
      AND s.statistic_typeFK = 11
      AND s.object_typeFK = 3
      AND tt.sportFK = 3
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      AND tt.id IN (9600, 9601, 9779, 10327, 10328, 10537, 10538, 11498, 11507, 11524, 11525, 11526, 11532)
      AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
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
    COUNT(DISTINCT s.id) AS eligible_count,
    1 AS sort_order
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = 11
  AND s.object_typeFK = 3
  AND tt.sportFK = 3
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND tt.id IN (9600, 9601, 9779, 10327, 10328, 10537, 10538, 11498, 11507, 11524, 11525, 11526, 11532)
  AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, statistic_id;
-- ==============================================================================
SELECT
    -- CheckID - Golf-DQ-087
    -- Name - EVENT_RESULTS_RANK_INVALID_OR_MISSING_STROKE_PLAY
    -- What it does: Finds Stroke Play players whose Rank is missing, unexplained, or not a usable number.
    z.check_type,
    z.event_id,
    z.event_name,
    z.affected_count,
    z.rank_not_integer_count,
    z.rank_over_max_count,
    z.rank_missing_count,
    z.no_result_count,
    z.ranks_held,
    z.affected_participants,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds finished Stroke Play events holding a Rank that is not
-- a plain positive integer up to the sport's maximum, or missing from a player who neither
-- carries a Comment nor is recorded as having missed the cut, counting each verdict and
-- naming who holds it.
-- Golf explains a missing rank with result type 38 Made cut, not with a Comment. A player who
-- misses the cut has no finishing position and never had one, and the sport says so in a field
-- of its own: 351143 of them carry yes or no over 3201 Stroke Play events. The global template
-- knows only the Comment, so it read 23071 ordinary weekends off as findings; honouring Made
-- cut = no leaves 841. This is why the check is written here rather than instantiated.
-- One row per event. The residue concentrates - 841 rows stand for 107 events and one holds 87
-- of them - so the event is the object and the counts travel as named columns. Where an event
-- holds more than one verdict the row carries the invalid stored value, because a rank of 999
-- is read as a result while an absence is visibly an absence; every count stays on the row.
FROM (
    SELECT
        CASE
            WHEN SUM(CASE WHEN y.verdict = 'RANK_NOT_INTEGER' THEN 1 ELSE 0 END) > 0 THEN 'RANK_NOT_INTEGER'
            WHEN SUM(CASE WHEN y.verdict = 'RANK_OVER_MAX' THEN 1 ELSE 0 END) > 0 THEN 'RANK_OVER_MAX'
            WHEN SUM(CASE WHEN y.verdict = 'RANK_AND_COMMENT_MISSING_OTHER_RESULT_PRESENT' THEN 1 ELSE 0 END) > 0
                 THEN 'RANK_AND_COMMENT_MISSING_OTHER_RESULT_PRESENT'
            ELSE 'NO_RESULT_OF_ANY_TYPE'
        END AS check_type,
        y.event_id,
        y.event_name,
        COUNT(*) AS affected_count,
        SUM(CASE WHEN y.verdict = 'RANK_NOT_INTEGER' THEN 1 ELSE 0 END) AS rank_not_integer_count,
        SUM(CASE WHEN y.verdict = 'RANK_OVER_MAX' THEN 1 ELSE 0 END) AS rank_over_max_count,
        SUM(CASE WHEN y.verdict = 'RANK_AND_COMMENT_MISSING_OTHER_RESULT_PRESENT' THEN 1 ELSE 0 END) AS rank_missing_count,
        SUM(CASE WHEN y.verdict = 'NO_RESULT_OF_ANY_TYPE' THEN 1 ELSE 0 END) AS no_result_count,
        GROUP_CONCAT(DISTINCT y.rank_value ORDER BY y.rank_value SEPARATOR ', ') AS ranks_held,
        GROUP_CONCAT(DISTINCT y.participant_name ORDER BY y.participant_name SEPARATOR ' | ') AS affected_participants
    FROM (
SELECT
    CASE
        WHEN r_rank_value IS NOT NULL AND r_rank_value NOT REGEXP '^[1-9][0-9]*$' THEN 'RANK_NOT_INTEGER'
        WHEN r_rank_value IS NOT NULL AND r_rank_value REGEXP '^[1-9][0-9]*$' AND CAST(r_rank_value AS UNSIGNED) > 250 THEN 'RANK_OVER_MAX'
        WHEN r_rank_value IS NULL AND r_comment_value IS NULL AND x.has_any_result = 0 THEN 'NO_RESULT_OF_ANY_TYPE'
        WHEN r_rank_value IS NULL AND r_comment_value IS NULL THEN 'RANK_AND_COMMENT_MISSING_OTHER_RESULT_PRESENT'
    END AS verdict,
    x.event_id,
    x.event_name,
    x.participant_name,
    x.r_rank_value AS rank_value
FROM (
    SELECT
        ep.id AS event_participants_id,
        e.id AS event_id,
        e.name AS event_name,
        p.name AS participant_name,
        (
            SELECT r1.value
            FROM result r1
            WHERE r1.event_participantsFK = ep.id
              AND r1.result_typeFK = 100
              AND r1.del = 'no'
              AND r1.value IS NOT NULL
              AND TRIM(r1.value) <> ''
            LIMIT 1
        ) AS r_rank_value,
        (
            SELECT r2.value
            FROM result r2
            WHERE r2.event_participantsFK = ep.id
              AND r2.result_typeFK = 104
              AND r2.del = 'no'
              AND r2.value IS NOT NULL
              AND TRIM(r2.value) <> ''
            LIMIT 1
        ) AS r_comment_value,
        EXISTS (
            SELECT 1
            FROM result r3
            WHERE r3.event_participantsFK = ep.id
              AND r3.del = 'no'
              AND r3.value IS NOT NULL
              AND TRIM(r3.value) <> ''
        ) AS has_any_result,
        (
            SELECT r4.value
            FROM result r4
            WHERE r4.event_participantsFK = ep.id
              AND r4.result_typeFK = 38
              AND r4.del = 'no'
              AND r4.value IS NOT NULL
              AND TRIM(r4.value) <> ''
            LIMIT 1
        ) AS r_made_cut
    FROM event_participants ep
    JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
         AND od.disciplineFK = 629
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
    WHERE ep.del = 'no'
      AND tt.sportFK = 3
      AND e.status_type = 'finished'
      AND e.status_descFK = 6
      AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
) x
WHERE
    (x.r_rank_value IS NOT NULL AND x.r_rank_value NOT REGEXP '^[1-9][0-9]*$')
    OR (x.r_rank_value IS NOT NULL AND x.r_rank_value REGEXP '^[1-9][0-9]*$' AND CAST(x.r_rank_value AS UNSIGNED) > 250)
    OR (x.r_rank_value IS NULL
        AND x.r_comment_value IS NULL
        AND (x.r_made_cut IS NULL OR LOWER(TRIM(x.r_made_cut)) <> 'no'))
    ) y
    GROUP BY y.event_id, y.event_name
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
JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
     AND od.disciplineFK = 629
WHERE ep.del = 'no'
  AND tt.sportFK = 3
  AND e.status_type = 'finished'
  AND e.status_descFK = 6
  AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, affected_count DESC, event_id;
-- ==============================================================================
SELECT
    -- CheckID - Golf-DQ-088
    -- Name - EVENT_NAME_FORMAT_INVALID_STROKE_PLAY
    -- What it does: Finds Stroke Play event names that break a text-hygiene rule.
    'Name_Format_Invalid' AS check_type,
    MIN(x.object_name) AS event_name,
    x.violation_types,
    COUNT(DISTINCT x.object_id) AS affected_object_count,
    MIN(x.object_id) AS sample_object_id,
    MIN(x.template_name) AS sample_template_name,
    MIN(x.stage_name) AS sample_stage_name,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds Stroke Play event names breaking a text-hygiene rule -
-- spacing, control or corrupted characters, hyphenation, capitalisation, a placeholder or a
-- numeric-only name - one row per name, naming every rule it breaks.
FROM (
    SELECT
        e.id AS object_id,
        e.name AS object_name,
        -- The grouping key is binary: under the column's case-insensitive collation two
        -- spellings that differ only in case would collapse into one group, which is the
        -- distinction GLOBAL-DQ-050 exists to report.
        (CONVERT(e.name USING utf8mb4) COLLATE utf8mb4_bin) AS name_bin,
        tt.name AS template_name,
        ts.name AS stage_name,
        CONCAT_WS(', ',
            IF(CHAR_LENGTH(e.name) <> CHAR_LENGTH(TRIM(e.name)), 'LEADING_OR_TRAILING_SPACE', NULL),
            IF(e.name LIKE '%  %', 'DOUBLE_SPACE', NULL),
            IF(e.name REGEXP '[[:cntrl:]]', 'CONTROL_CHARACTER', NULL),
            -- The five rules below name a definite corruption. NON_ASCII_CHARACTER
            -- that follows cannot: it fires on a legitimate diacritic just as readily,
            -- so a corrupted name is reported under its own verdict as well.
            -- Semicolon as \\x{3B}, never literal: the Pool cuts the statement at the first one.
            IF(e.name LIKE '%&#%' OR LOWER(e.name) REGEXP '&(amp|quot|apos|lt|gt|nbsp)\\x{3B}', 'HTML_ENTITY', NULL),
            IF(HEX(e.name) LIKE '%EFBFBD%', 'REPLACEMENT_CHARACTER', NULL),
            IF(HEX(e.name) LIKE '%C2A0%', 'NON_BREAKING_SPACE', NULL),
            IF(HEX(e.name) LIKE '%E2808B%', 'ZERO_WIDTH_SPACE', NULL),
            IF(HEX(e.name) LIKE '%C383%' OR HEX(e.name) LIKE '%C382%', 'MOJIBAKE_DOUBLE_ENCODED', NULL),
            IF(LENGTH(e.name) <> CHAR_LENGTH(e.name), 'NON_ASCII_CHARACTER', NULL),
            IF(e.name REGEXP '[^ ]-|-[^ ]', 'HYPHEN_WITHOUT_SPACES', NULL),
            IF((CONVERT(e.name USING utf8mb4) COLLATE utf8mb4_bin) REGEXP '[A-Za-z][12][0-9][0-9][0-9]|[12][0-9][0-9][0-9][A-Za-z]', 'YEAR_GLUED_TO_WORD', NULL),
            IF((CONVERT(e.name USING utf8mb4) COLLATE utf8mb4_bin) REGEXP '[A-Z][A-Z][a-z]', 'DOUBLE_CAPITAL', NULL),
            IF((CONVERT(e.name USING utf8mb4) COLLATE utf8mb4_bin) REGEXP '[A-Za-z]'
               AND (CONVERT(e.name USING utf8mb4) COLLATE utf8mb4_bin) NOT REGEXP '[a-z]', 'ALL_UPPERCASE', NULL),
            IF((CONVERT(e.name USING utf8mb4) COLLATE utf8mb4_bin) REGEXP '^[a-z]', 'STARTS_LOWERCASE', NULL),
            IF(LOWER(TRIM(e.name)) IN ('test','testing','temp','tmp','xxx','asd','qwe','tbd','tba','n/a','undefined','event','new event'), 'PLACEHOLDER_NAME', NULL),
            IF(TRIM(e.name) REGEXP '^[0-9]+$', 'NUMERIC_ONLY_NAME', NULL)
        ) AS violation_types
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
         AND od.disciplineFK = 629
    WHERE e.del = 'no'
      AND tt.sportFK = 3
      AND e.name IS NOT NULL
      AND TRIM(e.name) <> ''
      AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
      -- AND t.tournament_templateFK = <tournament_template_id>
) x
WHERE x.violation_types <> ''
GROUP BY x.name_bin, x.violation_types

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT (CONVERT(e.name USING utf8mb4) COLLATE utf8mb4_bin)) AS eligible_count,
    1 AS sort_order
    FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
     AND od.disciplineFK = 629
WHERE e.del = 'no'
  AND tt.sportFK = 3
  AND e.name IS NOT NULL
  AND TRIM(e.name) <> ''
  AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, violation_types, event_name;
-- ==============================================================================
SELECT
    -- CheckID - Golf-DQ-089
    -- Name - EVENT_NAME_DOES_NOT_NAME_ITS_PARTICIPANTS_MATCH_PLAY
    -- What it does: Flags Match Play event names that include none or only some of the competitors.
    CASE
        WHEN x.named_participant_count = 0 THEN 'NAMES_NO_PARTICIPANT'
        ELSE 'NAMES_SOME_PARTICIPANTS_NOT_ALL'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.template_name,
    x.tournament_name,
    x.stage_name,
    x.participant_count,
    x.named_participant_count,
    x.unnamed_participants,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds Match Play events whose name is built from their
-- competitors but does not name one of them, separating naming none of them from naming only
-- some.
-- Containment rather than reconstruction. A sport whose event name is the pairing joins its
-- sides with a separator that varies - a hyphen, a slash inside a side made of two countries
-- - and rebuilding the name from the participants would need that convention as a parameter
-- and would break on the first competition that spells it differently. Asking only whether
-- each participant's name appears somewhere in the event name needs no convention at all,
-- and is exactly strict enough to catch the case worth catching: a side stored under one
-- name and printed under another. A participant with an empty name is left out rather than
-- reported, because there is nothing to look for; that gap is GLOBAL-DQ-008.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        tt.name AS template_name,
        t.name AS tournament_name,
        ts.name AS stage_name,
        COUNT(*) AS participant_count,
        SUM(CASE WHEN LOCATE(LOWER(TRIM(p.name)), LOWER(e.name)) > 0 THEN 1 ELSE 0 END) AS named_participant_count,
        GROUP_CONCAT(CASE WHEN LOCATE(LOWER(TRIM(p.name)), LOWER(e.name)) = 0
                          THEN p.name END ORDER BY p.name SEPARATOR ', ') AS unnamed_participants
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
         AND od.disciplineFK = 630
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
    WHERE e.del = 'no'
      AND tt.sportFK = 3
      AND e.name IS NOT NULL
      AND TRIM(e.name) <> ''
      AND p.name IS NOT NULL
      AND TRIM(p.name) <> ''
      AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY e.id, e.name, e.startdate, tt.name, t.name, ts.name
) x
WHERE x.named_participant_count < x.participant_count

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
     AND od.disciplineFK = 630
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = 3
  AND e.name IS NOT NULL
  AND TRIM(e.name) <> ''
  AND p.name IS NOT NULL
  AND TRIM(p.name) <> ''
  AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_startdate DESC;
-- ==============================================================================
SELECT
    -- CheckID - Golf-DQ-090
    -- Name - TOURNAMENT_STAGE_DOES_NOT_COVER_ITS_EVENTS
    -- What it does: Flags Golf stages whose dates do not cover their events, or extend more than seven days after the last event.
    z.check_type,
    z.tournament_stage_id,
    z.stage_name,
    z.tournament_name,
    z.template_name,
    z.stage_start,
    z.stage_end,
    z.first_event,
    z.last_event,
    z.event_count,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds Golf tournament stages whose declared dates fail to
-- contain the events they hold - starting after the first, ending before the last, or
-- running more than a week past the last - counting the events and naming the span they
-- occupy.
-- GLOBAL-DQ-004 narrowed to what the invariant means in Golf, and the reason it could not be
-- instantiated. That template asks whether a stage is bounded by its own events, and in this
-- sport it is not: a stroke-play tournament is one event dated on the day it opens, while the
-- stage carries every day played. So the stage legitimately ends after its only event, and the
-- global check reported 4969 of 5089 findings that were the sport working correctly.
--
-- Measured 2026-08-13, inside the client boundary. Stroke play starts its stage on the first
-- event's day in 3476 of 3476 stages, and ends it 0 to 6 days later - three days is the
-- ordinary Thursday-to-Sunday tournament, four the one with a Monday finish. Match play aligns
-- on both ends in 212 of 251. Nothing observed ends before its last event or starts after its
-- first, which is why those two verdicts read zero today and are still worth asserting: they
-- are the shapes that make a stage unable to contain what it holds.
--
-- Seven days rather than six, so the measured maximum is inside the window rather than on its
-- edge. A stage running longer than that is not a golf tournament's span.
--
-- A stage starting up to two days before its first event is deliberately not reported. 88 of
-- the 251 match-play stages do it and they are dated by the tournament's own window rather
-- than by the matches inside it; SPORTS/Golf.md records the measurement so the exclusion can be
-- reversed knowing its size.
--
-- Stages with no date at all belong to Golf-DQ-046, which audits the missing field itself.
FROM (
    SELECT
        CASE
            WHEN DATE(ts.enddate) < DATE(MAX(e.startdate)) THEN 'STAGE_ENDS_BEFORE_ITS_LAST_EVENT'
            WHEN DATE(ts.startdate) > DATE(MIN(e.startdate)) THEN 'STAGE_STARTS_AFTER_ITS_FIRST_EVENT'
            ELSE 'STAGE_RUNS_PAST_ITS_LAST_EVENT'
        END AS check_type,
        ts.id AS tournament_stage_id,
        ts.name AS stage_name,
        t.name AS tournament_name,
        tt.name AS template_name,
        DATE(ts.startdate) AS stage_start,
        DATE(ts.enddate) AS stage_end,
        DATE(MIN(e.startdate)) AS first_event,
        DATE(MAX(e.startdate)) AS last_event,
        COUNT(DISTINCT e.id) AS event_count
    FROM tournament_stage ts
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN event e ON e.tournament_stageFK = ts.id AND e.del = 'no'
    WHERE ts.del = 'no'
      AND tt.sportFK = 3
      AND ts.startdate IS NOT NULL
      AND ts.enddate IS NOT NULL
      AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY ts.id, ts.name, t.name, tt.name, ts.startdate, ts.enddate
    HAVING DATE(ts.enddate) < DATE(MAX(e.startdate))
        OR DATE(ts.startdate) > DATE(MIN(e.startdate))
        OR DATEDIFF(DATE(ts.enddate), DATE(MAX(e.startdate))) > 7
) z

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ts.id) AS eligible_count,
    1 AS sort_order
FROM tournament_stage ts
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN event e ON e.tournament_stageFK = ts.id AND e.del = 'no'
WHERE ts.del = 'no'
  AND tt.sportFK = 3
  AND ts.startdate IS NOT NULL
  AND ts.enddate IS NOT NULL
  AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_count DESC, tournament_stage_id;
-- ==============================================================================
SELECT
    -- CheckID - Golf-DQ-091
    -- Name - TOURNAMENT_NAME_SEASON_OUTSIDE_ITS_SEASON_WINDOW
    -- What it does: Flags Golf events outside the season shown in the tournament name. That season runs from the previous September through the named year.
    z.check_type,
    z.tournament_id,
    z.tournament_name,
    z.template_name,
    z.named_year,
    z.first_event,
    z.last_event,
    z.event_count,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds Golf tournaments named for a single year whose events
-- fall outside the season that year names, which runs from the September before it to the
-- end of it, separating one starting too early from one running past its year.
-- GLOBAL-DQ-080 narrowed to the season Golf actually keeps. That template recognises the
-- written span form 2025/26 and reads a bare 2002 as the calendar year, so the European Tour
-- season opening in November 2001 contradicted its own name: 42 of its 45 findings were that,
-- and the real residue was 3.
--
-- Measured 2026-08-13, inside the client boundary. 37 year-named tournaments hold events
-- outside their year and every one of them opens early rather than finishing late: November
-- for 19 of them, December 6, October 6 and September 4. So the season a year names begins on
-- 1 September of the year before, and nothing here reaches back further.
--
-- The two that run past their year are Tokyo, whose Games kept the name 2020 and were played
-- on 29 July and 4 August 2021. That is the world being unusual rather than the data being
-- wrong, and it is recorded as the expected residual instead of being filtered out: a filter
-- would also hide the next tournament that genuinely runs into the following year.
FROM (
    SELECT
        CASE
            WHEN MIN(DATE(e.startdate)) < MAKEDATE(CAST(t.name AS UNSIGNED) - 1, 244)
                 THEN 'SEASON_STARTS_BEFORE_ITS_WINDOW'
            ELSE 'SEASON_RUNS_PAST_ITS_YEAR'
        END AS check_type,
        t.id AS tournament_id,
        t.name AS tournament_name,
        tt.name AS template_name,
        CAST(t.name AS UNSIGNED) AS named_year,
        MIN(DATE(e.startdate)) AS first_event,
        MAX(DATE(e.startdate)) AS last_event,
        COUNT(DISTINCT e.id) AS event_count
    FROM tournament t
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
    JOIN event e ON e.tournament_stageFK = ts.id AND e.del = 'no'
    WHERE t.del = 'no'
      AND tt.sportFK = 3
      AND t.name REGEXP '^[0-9]{4}$'
      AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY t.id, t.name, tt.name
    HAVING MIN(DATE(e.startdate)) < MAKEDATE(CAST(t.name AS UNSIGNED) - 1, 244)
        OR MAX(DATE(e.startdate)) > MAKEDATE(CAST(t.name AS UNSIGNED), 366)
) z

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT t.id) AS eligible_count,
    1 AS sort_order
FROM tournament t
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
JOIN event e ON e.tournament_stageFK = ts.id AND e.del = 'no'
WHERE t.del = 'no'
  AND tt.sportFK = 3
  AND t.name REGEXP '^[0-9]{4}$'
  AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, named_year, tournament_id;
-- ==============================================================================
SELECT
    -- CheckID - Golf-DQ-092
    -- Name - EVENT_RESULTS_MATCH_PLAY_OUTCOME_INCOHERENT
    -- What it does: Finds a finished Match Play event whose outcome does not hold together.
    z.check_type,
    z.event_id,
    z.event_name,
    z.event_startdate,
    z.template_name,
    z.participant_rows,
    z.final_results_held,
    z.scores_held,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds finished Match Play events whose outcome does not hold
-- together - no verdict recorded though the match was scored, both sides winning, a winner with
-- no loser, a draw on one side only, the two players of one side disagreeing with each other, a
-- word Final Result does not use, or a Match Play Score contradicting the result beside it.
--
-- The first check to read a Match Play outcome at all. GLOBAL-DQ-094 is the template for it and
-- cannot instantiate here, because it reads the placing off a pair of numeric scores and this
-- sport stores words in 4 Final Result - won, lost and draw - with golf's own notation in
-- 39 Match Play Score: 1up, 2&1, A/S.
--
-- A foursome is judged as one match, which is what this statement gained on 2026-08-14. A
-- four-player match holds four participant rows and two sides, and the side is in
-- event_participants.number: odd against even, so 1 and 3 play 2 and 4. That was confirmed on
-- all 2008 four-entry events naming every competitor, and SPORTS/Golf.md owns the fact. Until it
-- was read, 2132 finished four-player events were outside this check entirely - not clean, not
-- dirty, simply unasked - and 2089 of them turned out to carry a verdict all along. Every count
-- here is now a count of sides rather than of rows, which is what makes one statement able to
-- judge both shapes; an event whose rows do not divide into two equal sides is itself reported
-- rather than skipped.
--
-- An all-square match is a result, not a missing one, and that distinction is the second thing
-- this statement gained. A match halved after 18 holes is written A/S in 39 and draw on both
-- sides in 4, and 486 events do exactly that and are correct. 145 more carry the A/S score and
-- no word at all: the match is not unrecorded, its outcome is legible from the score, and only
-- the word is missing. Those are reported as HALVED_MATCH_NOT_WRITTEN_AS_A_DRAW and are a
-- smaller repair than the 1151 events where a deciding score sits beside no verdict and nothing
-- in the row says who won. Reporting the two as one finding was reading a golf draw as an
-- absence.
--
-- Measured 2026-08-14 inside the client boundary: 1447 findings over 12984 events, against 1376
-- over 10848 before the foursomes were read and the halves were separated. 1151 events hold a
-- deciding score and no verdict at all, and they arrive about 63 to a template-season - the size
-- of a 64-player bracket - so what is missing is the ruling on whole draws rather than scattered
-- rows. 185 are halved matches whose draw was never written, 145 singles and 40 foursomes. 6
-- hold no result of any type. The rest are small and sharp: 82 scores reading X&Y where X is not
-- the larger, which is impossible; 13 halved matches carrying a deciding score; 4 all-square
-- scores on a match the result says was won; 4 events whose entries do not divide into two equal
-- sides; and 2 where Final Result holds a number.
--
-- What the foursomes turned out to be worth is worth stating, because it was not obvious before
-- reading them. They contributed 2136 events to the eligible population and only 71 findings, so
-- the shape they were suspected of - a whole class of matches nobody had ever checked - is not
-- what they are. They are largely correct, and knowing that is the point: an unread population
-- reported as neither clean nor dirty is a hole in the coverage figure, and 2132 events is a
-- sixth of this check's ground.
FROM (
    SELECT
        CASE
            WHEN x.sides_seen <> 2 OR x.rows_total NOT IN (2, 4) OR x.sides_uneven > 0
                 THEN 'PARTICIPANT_ROWS_DO_NOT_FORM_TWO_SIDES'
            WHEN x.unknown_words > 0 THEN 'FINAL_RESULT_NOT_A_KNOWN_WORD'
            WHEN x.sides_mixed > 0 THEN 'ONE_SIDE_DISAGREES_WITH_ITSELF'
            WHEN x.sides_won > 1 THEN 'BOTH_SIDES_WON'
            WHEN x.sides_won = 1 AND x.sides_lost <> 1 THEN 'WINNER_WITHOUT_A_LOSER'
            WHEN x.sides_draw = 1 THEN 'DRAW_ON_ONE_SIDE_ONLY'
            WHEN x.sides_draw = 2 AND x.sides_won > 0 THEN 'DRAW_AND_WINNER_TOGETHER'
            WHEN x.sides_won = 0 AND x.sides_draw = 0 AND x.any_results = 0 THEN 'NO_RESULT_OF_ANY_TYPE'
            WHEN x.sides_won = 0 AND x.sides_draw = 0 AND x.all_square > 0 AND x.decided_scores = 0
                 THEN 'HALVED_MATCH_NOT_WRITTEN_AS_A_DRAW'
            WHEN x.sides_won = 0 AND x.sides_draw = 0 THEN 'FINAL_RESULT_MISSING_BUT_MATCH_SCORED'
            WHEN x.all_square > 0 AND x.sides_draw = 0 THEN 'SCORE_ALL_SQUARE_BUT_MATCH_DECIDED'
            WHEN x.sides_draw = 2 AND x.decided_scores > 0 THEN 'DRAW_WITH_A_DECIDING_SCORE'
            WHEN x.malformed_holes > 0 THEN 'SCORE_HOLES_BEFORE_REMAINING'
            ELSE 'OUTCOME_SHAPE_UNCLASSIFIED'
        END AS check_type,
        x.event_id,
        x.event_name,
        x.event_startdate,
        x.template_name,
        x.rows_total AS participant_rows,
        CONCAT('sides won ', x.sides_won, ', lost ', x.sides_lost, ', draw ', x.sides_draw,
               ', silent ', x.sides_silent, ', mixed ', x.sides_mixed) AS final_results_held,
        x.score_values AS scores_held
    FROM (
        SELECT
            xx.*,
            -- What the rest of this load did with the same shape. A template and a season is
            -- one import written by one hand, and the question a halved match with no word
            -- raises is only answerable against it.
            SUM(CASE WHEN xx.all_square > 0 AND xx.sides_draw = 2 THEN 1 ELSE 0 END)
                OVER (PARTITION BY xx.template_name, YEAR(xx.event_startdate))
                AS halves_written_in_this_load
        FROM (
        SELECT
            p.event_id,
            p.event_name,
            p.event_startdate,
            p.template_name,
            p.any_results,
            COUNT(*) AS sides_seen,
            SUM(p.rows_in_side) AS rows_total,
            SUM(CASE WHEN p.rows_in_side <> p.rows_expected THEN 1 ELSE 0 END) AS sides_uneven,
            SUM(CASE WHEN p.verdict = 'won'   THEN 1 ELSE 0 END) AS sides_won,
            SUM(CASE WHEN p.verdict = 'lost'  THEN 1 ELSE 0 END) AS sides_lost,
            SUM(CASE WHEN p.verdict = 'draw'  THEN 1 ELSE 0 END) AS sides_draw,
            SUM(CASE WHEN p.verdict = 'mixed' THEN 1 ELSE 0 END) AS sides_mixed,
            SUM(CASE WHEN p.verdict = 'none'  THEN 1 ELSE 0 END) AS sides_silent,
            SUM(p.unknown_words) AS unknown_words,
            SUM(p.all_square) AS all_square,
            SUM(p.decided_scores) AS decided_scores,
            SUM(p.malformed_holes) AS malformed_holes,
            GROUP_CONCAT(DISTINCT NULLIF(p.score_values, '') ORDER BY p.score_values SEPARATOR ' | ') AS score_values
        FROM (
            SELECT
                q.event_id,
                q.event_name,
                q.event_startdate,
                q.template_name,
                q.any_results,
                q.rows_in_side,
                q.rows_expected,
                q.unknown_words,
                q.all_square,
                q.decided_scores,
                q.malformed_holes,
                q.score_values,
                -- A side speaks once, not once per player. In a foursome the verdict is written
                -- on one of the two entries and the other is left silent - 2017 of the 2132
                -- four-player events carry exactly two words, one a side - so a silent row is
                -- the convention and not a disagreement. What makes a side incoherent is holding
                -- two different words, never holding fewer words than players.
                CASE
                    WHEN q.n_won  > 0 AND q.n_lost = 0 AND q.n_draw = 0 THEN 'won'
                    WHEN q.n_lost > 0 AND q.n_won  = 0 AND q.n_draw = 0 THEN 'lost'
                    WHEN q.n_draw > 0 AND q.n_won  = 0 AND q.n_lost = 0 THEN 'draw'
                    WHEN q.n_won + q.n_lost + q.n_draw + q.unknown_words = 0 THEN 'none'
                    ELSE 'mixed'
                END AS verdict
            FROM (
                SELECT
                    e.id AS event_id,
                    e.name AS event_name,
                    e.startdate AS event_startdate,
                    tt.name AS template_name,
                    MOD(ep.number, 2) AS side,
                    COUNT(DISTINCT ep.id) AS rows_in_side,
                    (SELECT COUNT(DISTINCT epc.id)
                     FROM event_participants epc
                     WHERE epc.eventFK = e.id AND epc.del = 'no') / 2 AS rows_expected,
                    SUM(CASE WHEN LOWER(TRIM(fr.value)) = 'won'  THEN 1 ELSE 0 END) AS n_won,
                    SUM(CASE WHEN LOWER(TRIM(fr.value)) = 'lost' THEN 1 ELSE 0 END) AS n_lost,
                    SUM(CASE WHEN LOWER(TRIM(fr.value)) = 'draw' THEN 1 ELSE 0 END) AS n_draw,
                    SUM(CASE WHEN fr.value IS NOT NULL AND TRIM(fr.value) <> ''
                              AND LOWER(TRIM(fr.value)) NOT IN ('won', 'lost', 'draw')
                             THEN 1 ELSE 0 END) AS unknown_words,
                    SUM(CASE WHEN UPPER(TRIM(ms.value)) = 'A/S' THEN 1 ELSE 0 END) AS all_square,
                    SUM(CASE WHEN ms.value IS NOT NULL AND TRIM(ms.value) <> ''
                              AND UPPER(TRIM(ms.value)) <> 'A/S' THEN 1 ELSE 0 END) AS decided_scores,
                    SUM(CASE WHEN TRIM(ms.value) REGEXP '^[0-9]+&[0-9]+$'
                              AND CAST(SUBSTRING_INDEX(TRIM(ms.value), '&', 1) AS UNSIGNED)
                                  <= CAST(SUBSTRING_INDEX(TRIM(ms.value), '&', -1) AS UNSIGNED)
                             THEN 1 ELSE 0 END) AS malformed_holes,
                    GROUP_CONCAT(DISTINCT NULLIF(TRIM(ms.value), '') ORDER BY TRIM(ms.value) SEPARATOR ' ') AS score_values,
                    (SELECT COUNT(*)
                     FROM result ra
                     JOIN event_participants epa ON epa.id = ra.event_participantsFK AND epa.del = 'no'
                     WHERE epa.eventFK = e.id
                       AND ra.del = 'no'
                       AND ra.value IS NOT NULL
                       AND TRIM(ra.value) <> '') AS any_results
                FROM event e
                JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
                JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
                JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
                JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
                     AND od.disciplineFK = 630
                JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
                LEFT JOIN result fr ON fr.event_participantsFK = ep.id AND fr.result_typeFK = 4 AND fr.del = 'no'
                LEFT JOIN result ms ON ms.event_participantsFK = ep.id AND ms.result_typeFK = 39 AND ms.del = 'no'
                WHERE e.del = 'no'
                  AND tt.sportFK = 3
                  AND e.status_type = 'finished'
                  AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
                  -- AND t.tournament_templateFK = <tournament_template_id>
                  -- AND e.startdate >= '<from_datetime>'
                  -- AND e.startdate <  '<to_datetime>'
                GROUP BY e.id, e.name, e.startdate, tt.name, MOD(ep.number, 2)
            ) q
        ) p
        GROUP BY p.event_id, p.event_name, p.event_startdate, p.template_name, p.any_results
        ) xx
    ) x
    -- A halved match is the sport working: draw on both sides, no winner, no loser. It is
    -- excluded here rather than classified, because a check that reports 486 correct halves
    -- teaches its reader to skip the column they were meant to read.
    WHERE (
          x.sides_seen <> 2
       OR x.rows_total NOT IN (2, 4)
       OR x.sides_uneven > 0
       OR x.unknown_words > 0
       OR x.sides_mixed > 0
       OR NOT ((x.sides_won = 1 AND x.sides_lost = 1 AND x.sides_draw = 0)
            OR (x.sides_won = 0 AND x.sides_lost = 0 AND x.sides_draw = 2))
       OR (x.all_square > 0 AND x.sides_draw = 0)
       OR (x.sides_draw = 2 AND x.decided_scores > 0)
       OR x.malformed_holes > 0
    )
    -- And a halved match whose load never writes the word is not reported at all. Measured
    -- 2026-08-19 over the 114 template-seasons holding a halved match: 69 of them write draw on
    -- both sides every time, 40 never write it once, and only 5 do both. LPGA Tour 2022 is
    -- nineteen halves and no word, European Tour and PGA Tour 2021 is eighteen, Ryder Cup 2006
    -- is seven - a convention of the import rather than a row somebody forgot, which is the
    -- discriminator ../POWERBI.md records for Golf-DQ-101. Reporting them made this class 185
    -- events, of which about 21 were the sport contradicting itself and the rest were the sport
    -- being consistent.
    -- The condition is the load and not the sport, because the sport has no single rule here:
    -- both conventions are in use and neither is wrong on its own. What is wrong is a load that
    -- writes the word for one halved match and not for the next, and that is what survives.
    -- The other two classes the reviewers questioned on the same day are deliberately unchanged:
    -- the four three-competitor play-offs still report as PARTICIPANT_ROWS_DO_NOT_FORM_TWO_SIDES
    -- and the thirteen team matches whose two sides hold the same points total still report as
    -- DRAW_WITH_A_DECIDING_SCORE. Both were measured and both are false positives; neither was
    -- approved for change.
    AND NOT (
            x.sides_seen = 2
        AND x.rows_total IN (2, 4)
        AND x.sides_uneven = 0
        AND x.unknown_words = 0
        AND x.sides_mixed = 0
        AND x.sides_won = 0
        AND x.sides_draw = 0
        AND x.any_results > 0
        AND x.all_square > 0
        AND x.decided_scores = 0
        AND x.halves_written_in_this_load = 0
    )
) z

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
-- Every finished Match Play event inside the client boundary that has anybody entered, singles
-- and foursomes alike. No row count is required here any more: an event whose entries do not
-- divide into two equal sides is a finding of this statement rather than a population outside it.
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
     AND od.disciplineFK = 630
WHERE e.del = 'no'
  AND tt.sportFK = 3
  AND e.status_type = 'finished'
  AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND EXISTS (
      SELECT 1 FROM event_participants epx
      WHERE epx.eventFK = e.id AND epx.del = 'no'
  )

ORDER BY sort_order, event_startdate DESC, event_id;
-- ==============================================================================
SELECT
    -- CheckID - Golf-DQ-093
    -- Name - COMP.RANK_RESULTS_PARTICIPANT_NOT_IN_TOURNAMENT
    -- What it does: Flags Comp.Rank statistics for participants who did not take part in any event in the same tournament.
    'PARTICIPANT_NOT_IN_TOURNAMENT' AS check_type,
    cr.statistic_id,
    cr.template_name,
    cr.tournament_name,
    COUNT(DISTINCT cr.participant_id) AS stray_participants,
    COUNT(DISTINCT cr.statistic_participants_id) AS stray_participant_rows,
    GROUP_CONCAT(DISTINCT cr.participant_id ORDER BY cr.participant_id SEPARATOR ' | ') AS participant_ids,
    GROUP_CONCAT(DISTINCT cr.participant_name ORDER BY cr.participant_name SEPARATOR ' | ') AS participant_names,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds Comp.Rank statistics holding participants who took no
-- part in any event under their own tournament, counting the strays and naming them.
-- GLOBAL-DQ-030 rewritten for Golf because it could not be run here at all. That template asks
-- the question one Comp.Rank row at a time - for each of the sport's 355654 statistic
-- participants, does this person appear anywhere under this tournament - and each of those
-- questions walks the tournament's stages, events and entries. It timed out at 180 seconds for
-- days, and cutting it into 32 id windows only made it finishable: 843 seconds to return the
-- same 13 findings.
--
-- The rewrite asks it once. Every (tournament, participant) pair the sport actually played is
-- built as one set, and the Comp.Rank rows are left-joined against it; a row with no match is
-- the finding. Measured 2026-08-14: 6.1 seconds, and the findings are identical.
--
-- The lineup half of the global template is gone rather than kept and left idle. That template
-- also excuses a participant who is a lineup member under the tournament, and SPORTS/Golf.md
-- records that this sport writes no lineup row anywhere - so the branch could only ever cost
-- time. If Golf ever stores one, this check reports its members as strays and the branch comes
-- back; that is the price of the speed and it is written down here rather than discovered.
--
-- One row per statistic, not per stray participant. Whoever repairs this works a statistic at a
-- time; the counts beside the lists are authoritative, because the server caps GROUP_CONCAT at
-- 1024 characters and truncates it silently.
--
-- It carries no id window, unlike the template it replaces. A window exists to make a statement
-- the transport cannot carry whole arrive in pieces, and this one arrives whole in nine
-- seconds. The template needed 32 windows to finish at all.
FROM (
    SELECT
        s.id AS statistic_id,
        t.id AS tournament_id,
        tt.name AS template_name,
        t.name AS tournament_name,
        sp.id AS statistic_participants_id,
        sp.participantFK AS participant_id,
        p.name AS participant_name
    FROM statistic s
    JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN statistic_participants11 sp ON sp.statisticFK = s.id AND sp.del = 'no'
    JOIN participant p ON p.id = sp.participantFK AND p.del = 'no'
    WHERE s.del = 'no'
      AND s.statistic_typeFK = 11
      AND s.object_typeFK = 3
      AND tt.sportFK = 3
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
      -- AND t.tournament_templateFK = <tournament_template_id>
) cr
LEFT JOIN (
    SELECT DISTINCT ts2.tournamentFK AS tournament_id, ep2.participantFK AS participant_id
    FROM tournament_stage ts2
    JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
    JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
    JOIN event e2 ON e2.tournament_stageFK = ts2.id AND e2.del = 'no'
    JOIN event_participants ep2 ON ep2.eventFK = e2.id AND ep2.del = 'no'
    WHERE ts2.del = 'no'
      AND tt2.sportFK = 3
      AND t2.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
      -- AND t2.tournament_templateFK = <tournament_template_id>
) played
  ON played.tournament_id = cr.tournament_id
 AND played.participant_id = cr.participant_id
WHERE played.participant_id IS NULL
GROUP BY cr.statistic_id, cr.template_name, cr.tournament_name

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count,
    1 AS sort_order
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN statistic_participants11 sp ON sp.statisticFK = s.id AND sp.del = 'no'
WHERE s.del = 'no'
  AND s.statistic_typeFK = 11
  AND s.object_typeFK = 3
  AND tt.sportFK = 3
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, stray_participants DESC, statistic_id;
-- ==============================================================================
SELECT
    -- CheckID - Golf-DQ-094
    -- Name - COMP.RANK_RESULTS_RANK_ABOVE_PLAUSIBLE_MAXIMUM
    -- What it does: Finds Comp.Rank holding a Rank above the largest place golf can award.
    'RANK_ABOVE_PLAUSIBLE_MAXIMUM' AS check_type,
    s.id AS statistic_id,
    tt.name AS template_name,
    t.name AS tournament_name,
    COUNT(DISTINCT sp.id) AS participant_count,
    COUNT(DISTINCT CASE WHEN CAST(sd.value AS UNSIGNED) > 250 THEN sp.id END) AS affected_count,
    MAX(CASE WHEN CAST(sd.value AS UNSIGNED) > 250 THEN CAST(sd.value AS UNSIGNED) END) AS highest_rank,
    GROUP_CONCAT(CASE WHEN CAST(sd.value AS UNSIGNED) > 250
                      THEN CONCAT(p.name, ' #', sd.value) END
                 ORDER BY CAST(sd.value AS UNSIGNED) SEPARATOR ' | ') AS affected_participants,
    NULL AS eligible_count,
    0 AS sort_order
-- 250 is RANK_MAX_PLAUSIBLE for golf, the largest field the sport puts on a course, and the
-- data leaves no doubt where the line falls: Comp.Rank ranks run to 164 and then jump to 999
-- and 9999. Those two are markers written into the rank itself rather than places anybody
-- finished in, and a marker in a numeric field is read as a number by everything downstream.
--
-- GLOBAL-DQ-036 asks the same question of the event result layer and does not reach here:
-- `result` and `statistic_data11` are separate layers and a value corrected in one stays
-- wrong in the other. This is the Comp.Rank half.
--
-- Held apart from Golf-DQ-095, which reports a rank merely larger than the field the statistic
-- holds. That is an incomplete import; this is a value that was never a place. The two are
-- repaired differently, so a statistic carrying both appears in both with its own row.
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN statistic_participants11 sp ON sp.statisticFK = s.id AND sp.del = 'no'
JOIN participant p ON p.id = sp.participantFK AND p.del = 'no'
LEFT JOIN statistic_data11 sd ON sd.statistic_participants11FK = sp.id
     AND sd.statistic_data_typeFK = 1270
     AND sd.del = 'no'
     AND sd.value REGEXP '^[1-9][0-9]*$'
WHERE s.del = 'no'
  AND s.statistic_typeFK = 11
  AND s.object_typeFK = 3
  AND tt.sportFK = 3
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
  -- AND t.tournament_templateFK = <tournament_template_id>
GROUP BY s.id, tt.name, t.name
HAVING COUNT(DISTINCT CASE WHEN CAST(sd.value AS UNSIGNED) > 250 THEN sp.id END) > 0


UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count,
    1 AS sort_order
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN statistic_participants11 sp ON sp.statisticFK = s.id AND sp.del = 'no'
JOIN statistic_data11 sd ON sd.statistic_participants11FK = sp.id
     AND sd.statistic_data_typeFK = 1270
     AND sd.del = 'no'
     AND sd.value REGEXP '^[1-9][0-9]*$'
WHERE s.del = 'no'
  AND s.statistic_typeFK = 11
  AND s.object_typeFK = 3
  AND tt.sportFK = 3
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, affected_count DESC, statistic_id;
-- ==============================================================================
SELECT
    -- CheckID - Golf-DQ-095
    -- Name - COMP.RANK_RESULTS_RANK_ABOVE_FIELD_SIZE
    -- What it does: Finds Comp.Rank ranking competitors beyond the number it holds, where the rank is also cut off and carries no Comment.
    'RANK_ABOVE_FIELD_SIZE' AS check_type,
    o.statistic_id,
    o.template_name,
    o.tournament_name,
    o.participant_count,
    COUNT(DISTINCT o.statistic_participants_id) AS affected_count,
    MAX(o.rank_value) AS highest_affected_rank,
    GROUP_CONCAT(CONCAT(o.participant_name, ' #', o.rank_value)
                 ORDER BY o.rank_value SEPARATOR ' | ') AS affected_participants,
    NULL AS eligible_count,
    0 AS sort_order
-- A statistic holding 81 competitors and ranking one of them 151 is not ranking a field of
-- 151: it is holding part of one. The rank is evidence of how many there were, and the
-- statistic is the record of who they were, so the two disagreeing means the import stopped
-- early. Golf leaves 163 of these with a top rank more than three times the field it holds.
--
-- Two conditions keep a normal ranking out of this. The rank must also be cut off from the
-- next lower one, because a field where several competitors tie takes the places below them
-- out of use and pushes the last rank past the count legitimately - a tie for 1st in a field
-- of 3 ends at rank 3 with no rank 2, and nothing is wrong. And a rank the sport has explained
-- through the Comment data field is left alone, on the same reasoning as the event result
-- layer: a value with a stated reason is a record, not a defect.
--
-- Ranks above 250 are excluded here and reported by Golf-DQ-094 instead. They are markers
-- rather than places and would otherwise dominate this list while needing a different repair;
-- excluding them from the field-size comparison as well as from the findings keeps the gap
-- test reading real places only.
--
-- One row per statistic, because that is what somebody opens to repair it. The counts beside
-- the list are what the row asserts: the server truncates GROUP_CONCAT at 1024 characters
-- without saying so.
FROM (
    SELECT
        sp.id AS statistic_participants_id,
        f.statistic_id,
        f.template_name,
        f.tournament_name,
        f.participant_count,
        p.name AS participant_name,
        CAST(sd.value AS UNSIGNED) AS rank_value,
        MAX(CAST(sd.value AS UNSIGNED)) OVER (
            PARTITION BY f.statistic_id
            ORDER BY CAST(sd.value AS UNSIGNED)
            RANGE BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) AS next_lower_rank
    FROM (
        SELECT
            s.id AS statistic_id,
            tt.name AS template_name,
            t.name AS tournament_name,
            COUNT(DISTINCT spf.id) AS participant_count
        FROM statistic s
        JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
        JOIN statistic_participants11 spf ON spf.statisticFK = s.id AND spf.del = 'no'
        LEFT JOIN statistic_data11 sdf ON sdf.statistic_participants11FK = spf.id
             AND sdf.statistic_data_typeFK = 1270
             AND sdf.del = 'no'
             AND sdf.value REGEXP '^[1-9][0-9]*$'
             AND CAST(sdf.value AS UNSIGNED) <= 250
        WHERE s.del = 'no'
          AND s.statistic_typeFK = 11
          AND s.object_typeFK = 3
          AND tt.sportFK = 3
          AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
          AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
          -- AND t.tournament_templateFK = <tournament_template_id>
        GROUP BY s.id, tt.name, t.name
        HAVING MAX(CAST(sdf.value AS UNSIGNED)) > COUNT(DISTINCT spf.id)
    ) f
    JOIN statistic_participants11 sp ON sp.statisticFK = f.statistic_id AND sp.del = 'no'
    JOIN participant p ON p.id = sp.participantFK AND p.del = 'no'
    JOIN statistic_data11 sd ON sd.statistic_participants11FK = sp.id
         AND sd.statistic_data_typeFK = 1270
         AND sd.del = 'no'
         AND sd.value REGEXP '^[1-9][0-9]*$'
         AND CAST(sd.value AS UNSIGNED) <= 250
) o
WHERE o.rank_value > o.participant_count
  AND (o.next_lower_rank IS NULL OR o.rank_value > o.next_lower_rank + 1)
  AND NOT EXISTS (
      SELECT 1
      FROM statistic_data11 sdc
      WHERE sdc.statistic_participants11FK = o.statistic_participants_id
        AND sdc.statistic_data_typeFK = 1273
        AND sdc.del = 'no'
        AND sdc.value IS NOT NULL
        AND TRIM(sdc.value) <> ''
  )
GROUP BY o.statistic_id, o.template_name, o.tournament_name, o.participant_count

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count,
    1 AS sort_order
FROM statistic s
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN statistic_participants11 sp ON sp.statisticFK = s.id AND sp.del = 'no'
JOIN statistic_data11 sd ON sd.statistic_participants11FK = sp.id
     AND sd.statistic_data_typeFK = 1270
     AND sd.del = 'no'
     AND sd.value REGEXP '^[1-9][0-9]*$'
     AND CAST(sd.value AS UNSIGNED) <= 250
WHERE s.del = 'no'
  AND s.statistic_typeFK = 11
  AND s.object_typeFK = 3
  AND tt.sportFK = 3
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, affected_count DESC, statistic_id;
-- ==============================================================================
SELECT
    -- CheckID - Golf-DQ-096
    -- Name - EVENT_COMP.RANK_OMITS_COMPETITORS_WHO_PLAYED
    -- What it does: Finds events whose covering Comp.Rank leaves out competitors who took part.
    'COMP.RANK_OMITS_COMPETITORS_WHO_PLAYED' AS check_type,
    x.event_id,
    x.event_name,
    x.template_name,
    x.tournament_name,
    x.field_size,
    x.missing_count,
    x.missing_participants,
    NULL AS eligible_count,
    0 AS sort_order
-- GLOBAL-DQ-042 rewritten for Golf because it cannot be run here. That template asks, for each
-- competitor of each event, whether the covering statistic lists them - and Golf answers that
-- question about half a million times, because its Final round type is 225 Main Phase, which is
-- every tournament event, and its fields run to 250. The template is not slow in itself: the
-- same statement returns Artistic Gymnastics in 4.6 seconds.
--
-- So the question is asked once instead. Every (event, competitor) pair the sport played is one
-- set, every (event, competitor) pair its Comp.Rank statistics cover is another, and the finding
-- is the first minus the second. Nothing is looked up per row.
--
-- The audited object is the event. A statistic omitting six of eight finalists is one broken
-- import and not six defects, and missing_count is what the row asserts: the server truncates
-- GROUP_CONCAT at 1024 characters without saying so.
FROM (
    SELECT
        f.event_id,
        f.event_name,
        f.template_name,
        f.tournament_name,
        COUNT(DISTINCT f.participant_id) AS field_size,
        COUNT(DISTINCT CASE WHEN c.participant_id IS NULL THEN f.participant_id END) AS missing_count,
        GROUP_CONCAT(DISTINCT CASE WHEN c.participant_id IS NULL THEN f.participant_name END
                     ORDER BY f.participant_name SEPARATOR ' | ') AS missing_participants
    FROM (
        -- Who played, for every event a Comp.Rank covers.
        SELECT
            e.id AS event_id,
            e.name AS event_name,
            tt.name AS template_name,
            t.name AS tournament_name,
            p.id AS participant_id,
            p.name AS participant_name
        FROM event e
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
        JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
        JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
        WHERE e.del = 'no'
          AND tt.sportFK = 3
          AND e.round_typeFK IN (225)
          AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
          AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
          -- AND t.tournament_templateFK = <tournament_template_id>
          AND EXISTS (
              SELECT 1
              FROM statistic_config scg
              JOIN statistic sg ON sg.id = scg.statisticFK AND sg.del = 'no'
                   AND sg.statistic_typeFK = 11 AND sg.object_typeFK = 3
                   AND sg.objectFK = t.id
              WHERE scg.statistic_data_typeFK = 1471 AND scg.del = 'no'
                AND FIND_IN_SET(e.id, scg.value) > 0
                -- An event covered only by an empty statistic omits everyone, which is
                -- GLOBAL-DQ-010 reported once rather than this reported per competitor.
                AND EXISTS (
                    SELECT 1 FROM statistic_participants11 spg
                    WHERE spg.statisticFK = sg.id AND spg.del = 'no'
                )
          )
    ) f
    LEFT JOIN (
        -- Who the covering statistics rank, as one set for the whole sport.
        SELECT DISTINCT
            ex.id AS event_id,
            spx.participantFK AS participant_id
        FROM statistic_config scx
        JOIN statistic sx ON sx.id = scx.statisticFK AND sx.del = 'no'
             AND sx.statistic_typeFK = 11 AND sx.object_typeFK = 3
        JOIN tournament tx ON tx.id = sx.objectFK AND tx.del = 'no'
        JOIN tournament_template ttx ON ttx.id = tx.tournament_templateFK AND ttx.del = 'no'
             AND ttx.sportFK = 3
        JOIN tournament_stage tsx ON tsx.tournamentFK = tx.id AND tsx.del = 'no'
        JOIN event ex ON ex.tournament_stageFK = tsx.id AND ex.del = 'no'
             AND FIND_IN_SET(ex.id, scx.value) > 0
        JOIN statistic_participants11 spx ON spx.statisticFK = sx.id AND spx.del = 'no'
        WHERE scx.statistic_data_typeFK = 1471
          AND scx.del = 'no'
          AND tx.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
          -- AND tx.tournament_templateFK = <tournament_template_id>
    ) c
      ON c.event_id = f.event_id
     AND c.participant_id = f.participant_id
    GROUP BY f.event_id, f.event_name, f.template_name, f.tournament_name
) x
WHERE x.missing_count > 0

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = 3
  AND e.round_typeFK IN (225)
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND EXISTS (
      SELECT 1
      FROM statistic_config scg
      JOIN statistic sg ON sg.id = scg.statisticFK AND sg.del = 'no'
           AND sg.statistic_typeFK = 11 AND sg.object_typeFK = 3
           AND sg.objectFK = t.id
      WHERE scg.statistic_data_typeFK = 1471 AND scg.del = 'no'
        AND FIND_IN_SET(e.id, scg.value) > 0
        AND EXISTS (
            SELECT 1 FROM statistic_participants11 spg
            WHERE spg.statisticFK = sg.id AND spg.del = 'no'
        )
  )

ORDER BY sort_order, missing_count DESC, event_id;
-- ==============================================================================
SELECT
    -- CheckID - Golf-DQ-097
    -- Name - EVENT_SCOPE_RESULT_OWNER_EVENT_MISMATCH_FINAL_RESULT
    -- What it does: Finds final_result scope values naming an event participant from another event, or one that is not active.
    CASE
        WHEN x.participant_row_missing_count > 0 THEN 'SCOPE_RESULT_PARTICIPANT_ROW_MISSING'
        ELSE 'SCOPE_RESULT_OWNER_EVENT_MISMATCH'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.tournament_stage_name,
    x.offending_row_count,
    x.sample_row,
    NULL AS eligible_count,
    0 AS sort_order
-- GLOBAL-DQ-102 narrowed to one scope type, because the whole layer cannot be read. The
-- invariant is the same and is a pure relational one: a scope value reaches an event twice
-- over, once through the container it hangs off and once through the participant it names, and
-- the two have to arrive at the same event. Nothing a sport does with rounds or holes can make
-- them disagree legitimately.
--
-- Golf writes five scope types and 21830092 active values under them, measured 2026-08-14, and
-- 99.1 per cent of that sits under round1 to round4: 7005919, 6940111, 4182206 and 3515383
-- against 186509 for final_result. Those four are the hole-by-hole layer, which SPORTS/Golf.md
-- parked on 2026-08-12 as deliberately outside the DQ work - so reading them here would be a
-- decision taken sideways by a check rather than the one already on record. It is also not
-- affordable: counting the rows takes 140 seconds and grouping them exhausted the server's
-- temporary disk outright.
--
-- What that gives up is written down rather than implied. A scope value under round1 to round4
-- naming another event's competitor is not reported by anything. The day the hole-by-hole layer
-- is taken up, this check is where the other four types belong, and its whole shape already
-- fits them.
--
-- The missing participant row is reported by the same check because it is the same failed
-- resolution: a scope value whose participant cannot be reached is attached to nobody, and
-- separating it into its own CheckID would split one broken reference in two.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        ts.name AS tournament_stage_name,
        COUNT(*) AS offending_row_count,
        SUM(CASE WHEN ep.id IS NULL THEN 1 ELSE 0 END) AS participant_row_missing_count,
        MIN(CONCAT('scope=', es.id,
                   ' scope_event=', es.eventFK,
                   ' ep=', sr.event_participantsFK,
                   ' ep_event=', COALESCE(CAST(ep.eventFK AS CHAR), 'none'))) AS sample_row
    FROM scope_result sr
    JOIN event_scope es ON es.id = sr.event_scopeFK AND es.del = 'no'
         AND es.scope_typeFK IN (305)
    JOIN event e ON e.id = es.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = 3
    LEFT JOIN event_participants ep ON ep.id = sr.event_participantsFK AND ep.del = 'no'
    WHERE sr.del = 'no'
      AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
      AND (ep.id IS NULL OR ep.eventFK <> es.eventFK)
    GROUP BY e.id, e.name, ts.name
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM scope_result sr
JOIN event_scope es ON es.id = sr.event_scopeFK AND es.del = 'no'
     AND es.scope_typeFK IN (305)
JOIN event e ON e.id = es.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 3
WHERE sr.del = 'no'
  AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_id;
-- ==============================================================================
SELECT
    -- CheckID - Golf-DQ-098
    -- Name - COMP.RANK_SETTINGS_EVENT_ID_LIST_TRUNCATED
    -- What it does: Finds Comp.Rank whose Event id list is exactly 255 characters, so the column cut it short, and says whether the cut fell inside an id or on a comma.
    CASE
        WHEN NOT EXISTS (
                SELECT 1
                FROM tournament_stage tsl
                JOIN event el ON el.tournament_stageFK = tsl.id AND el.del = 'no'
                WHERE tsl.tournamentFK = t.id AND tsl.del = 'no'
                  AND el.id = CAST(SUBSTRING_INDEX(sc.value, ',', -1) AS UNSIGNED)
            ) THEN 'EVENT_ID_LIST_CUT_MID_NUMBER'
        ELSE 'EVENT_ID_LIST_CUT_AT_A_NUMBER_BOUNDARY'
    END AS check_type,
    s.id AS statistic_id,
    s.name AS statistic_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    -- How many pieces the text breaks into when split on commas, which is not how many events
    -- the ranking covers. At a boundary cut the two agree; at a mid-number cut the last piece is
    -- a fragment, so the event count is one lower. The column said ids_named until 2026-08-17
    -- and that name asserted the thing this check exists to disprove.
    (LENGTH(sc.value) - LENGTH(REPLACE(sc.value, ',', '')) + 1) AS items_after_split,
    SUBSTRING_INDEX(sc.value, ',', -1) AS last_item_in_the_list,
    NULL AS eligible_count,
    0 AS sort_order
-- The Event id config holds a comma-separated list, and the column it holds it in stops at 255
-- characters. Measured on Golf 2026-08-14: 167 values are exactly 255 characters long, nothing
-- in the sport is longer, and between 240 and 254 there is nothing at all - one value sits at
-- 231 and five at 239. A distribution of list lengths does not have a cliff; a column limit
-- does. Freestyle Skiing holds 49 of the same, and no other sport on the server holds any.
--
-- What the statistic loses is every event after the cut. What the database gains is worse, and
-- only in the first of the two shapes below.
--
-- EVENT_ID_LIST_CUT_MID_NUMBER is the visible half: the cut fell inside an id and left its
-- leading digits behind as a token of their own. Thirteen Golf statistics carry one, all of
-- them with six-digit event ids, because 255 characters hold 36 of those and three characters
-- of the 37th. Every one of those fragments is a valid event id - 412, 135, 455, 622, 794, 988
-- and 1353 are football matches played in 2000 - so a join on this field attaches a golf
-- ranking to a football fixture rather than failing. GLOBAL-DQ-042 did exactly that until
-- 2026-08-14.
--
-- EVENT_ID_LIST_CUT_AT_A_NUMBER_BOUNDARY is the invisible half, and it is the larger one: 154
-- statistics whose ids are seven digits, where 255 characters hold exactly 32 of them and the
-- cut lands on a comma. The value reads as a complete list and resolves cleanly, and nothing
-- but its length says the events after the 32nd were ever meant to be there. That is why this
-- check reads the length rather than the resolution: Golf-DQ-057 already reports what fails to
-- resolve, and it sees thirteen of these hundred and sixty-seven.
--
-- This is a schema defect rather than a data one. Correcting the values without widening the
-- column would truncate them again on the next write.
FROM statistic_config sc
JOIN statistic s ON s.id = sc.statisticFK AND s.del = 'no'
     AND s.statistic_typeFK = 11
     AND s.object_typeFK = 3
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE sc.statistic_data_typeFK = 1471
  AND sc.del = 'no'
  AND tt.sportFK = 3
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND LENGTH(sc.value) = 255

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT s.id) AS eligible_count,
    1 AS sort_order
FROM statistic_config sc
JOIN statistic s ON s.id = sc.statisticFK AND s.del = 'no'
     AND s.statistic_typeFK = 11
     AND s.object_typeFK = 3
JOIN tournament t ON t.id = s.objectFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
WHERE sc.statistic_data_typeFK = 1471
  AND sc.del = 'no'
  AND tt.sportFK = 3
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
  -- AND t.tournament_templateFK = <tournament_template_id>
  AND TRIM(COALESCE(sc.value, '')) <> ''

ORDER BY sort_order, items_after_split DESC, statistic_id;
-- ==============================================================================
SELECT
    -- CheckID - Golf-DQ-099
    -- Name - EVENT_SCOPE_LINEUP_RESULT_OWNER_EVENT_MISMATCH
    -- What it does: Finds scope values attached to a lineup place from another event, or one that is not active.
    CASE
        WHEN x.lineup_row_missing_count > 0 THEN 'LINEUP_SCOPE_RESULT_LINEUP_ROW_MISSING'
        ELSE 'LINEUP_SCOPE_RESULT_OWNER_EVENT_MISMATCH'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.tournament_stage_name,
    x.offending_row_count,
    x.sample_row,
    NULL AS eligible_count,
    0 AS sort_order
-- The lineup half of the invariant Golf-DQ-097 asserts over the participant half. A scope value
-- reaches an event twice over, once through the container it hangs off and once through the
-- lineup place it names, and the two have to arrive at the same event.
--
-- Golf writes no lineup row anywhere - measured 2026-08-14, zero for the whole sport - so no
-- value here can ever be legitimate: every one of them names somebody else's lineup. Sport-wide
-- there are 128 such values on three events, and the lineup places they name belong to an
-- American Football game and three football matches - Mississippi State against South Carolina,
-- Lommel against Roeselare, Maritimo against Rio Ave, Sporting Gijon against Leganes. A
-- cross-sport reference that resolves rather than failing is the same defect the truncated Event
-- id produces in Golf-DQ-098, in a different layer.
--
-- All three golf events fall on 8 and 9 March 2018, which makes this an import incident on two
-- days rather than a habit. Two of them sit under Korn Ferry Tour and Champions Tour, outside the
-- client boundary; the third is the South African Women's Open under Ladies European Tour and is
-- inside it, holding 36 of the 128. So this check audits one event and reports it, and its
-- eligible count is 1 rather than 0 - it is not a sentinel.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        ts.name AS tournament_stage_name,
        COUNT(*) AS offending_row_count,
        SUM(CASE WHEN l.id IS NULL THEN 1 ELSE 0 END) AS lineup_row_missing_count,
        MIN(CONCAT('scope=', es.id,
                   ' scope_event=', es.eventFK,
                   ' lineup=', lsr.lineupFK,
                   ' lineup_event=', COALESCE(CAST(ep.eventFK AS CHAR), 'none'))) AS sample_row
    FROM lineup_scope_result lsr
    JOIN event_scope es ON es.id = lsr.event_scopeFK AND es.del = 'no'
         AND es.scope_typeFK IN (305, 462, 463, 464, 465)
    JOIN event e ON e.id = es.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = 3
    LEFT JOIN lineup l ON l.id = lsr.lineupFK AND l.del = 'no'
    LEFT JOIN event_participants ep ON ep.id = l.event_participantsFK AND ep.del = 'no'
    WHERE lsr.del = 'no'
      AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
      AND (l.id IS NULL OR ep.id IS NULL OR ep.eventFK <> es.eventFK)
    GROUP BY e.id, e.name, ts.name
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM lineup_scope_result lsr
JOIN event_scope es ON es.id = lsr.event_scopeFK AND es.del = 'no'
     AND es.scope_typeFK IN (305, 462, 463, 464, 465)
JOIN event e ON e.id = es.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 3
WHERE lsr.del = 'no'
  AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_id;
-- ==============================================================================
SELECT
    -- CheckID - Golf-DQ-100
    -- Name - EVENT_RESULTS_TOTAL_PAR_CONTRADICTS_THE_STAGE_PAR
    -- What it does: Flags events whose competitors' cards agree on a course par the stage does not record.
    CASE
        WHEN d.implied_par BETWEEN 69 AND 73 THEN 'STAGE_PAR_CONTRADICTED_BY_ITS_FIELD'
        WHEN d.implied_par = 0 THEN 'TOTAL_PAR_HOLDS_THE_ROUND_TOTAL_NOT_THE_SCORE'
        ELSE 'FIELD_IMPLIES_A_PAR_THAT_IS_NOT_A_COURSE_PAR'
    END AS check_type,
    d.event_id,
    d.event_name,
    d.stage_id AS tournament_stage_id,
    d.stage_name AS tournament_stage_name,
    d.tournament_name,
    d.template_name,
    d.stage_par AS the_stage_says,
    d.implied_par AS the_field_says,
    d.competitors_behind_it,
    d.competitors_measured,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds a stroke-play event where the course par most of its own
-- competitors' cards imply is not the par recorded on its stage, separating a field that agrees
-- on a real course par, from one whose Total Par is the round total itself, from one that agrees
-- on a number no course has.
--
-- The arithmetic is the sport's own and it is exact. 36 Total Par is the strokes taken minus the
-- course par once per round played, confirmed on 200572 participations with no exception -
-- SPORTS/Golf.md owns that fact - so a card that disagrees is wrong on one side or the other.
-- Measured inside the client boundary 2026-08-14: 294095 of 315703 testable participations
-- satisfy it exactly.
--
-- What makes this an event-level finding rather than a per-card one is that the disagreement is
-- shared. Where 154 competitors all imply 71 and the stage says 70 - The RSM Classic, in eight
-- separate editions - a hundred and fifty-four cards are not wrong the same way. One number is.
-- So the statement reads the par the field agrees on and reports where that is not the recorded
-- one, without claiming which of the two is the value to correct.
--
-- A card only votes when its difference divides by the rounds it played, because a wrong par
-- shifts every round by the same amount. A card whose difference does not divide is a wrong
-- score rather than a wrong par: it carries no vote here, and the events where such cards are
-- the whole story are left to a check of their own rather than folded into this one.
--
-- The mode rather than unanimity, and the difference is not academic. Requiring every card to
-- agree finds 68 events; the most common implied par finds 112. The 44 it adds are fields where
-- a handful of bad cards sat beside a hundred good ones, and under unanimity one wrong score
-- would have protected a wrong par.
--
-- 69 to 73 is measured rather than assumed. The sport's own Par property holds 72 on 2769
-- stages, 71 on 1123, 70 on 576, 73 on 143 and 69 on 4, and everything else it holds - 22, 24,
-- 27, 45, 54, 65, 142 and three empty strings - is not a course par. A field agreeing on a
-- number outside that band is saying something else again, most legibly at PGA Grand Slam of
-- Golf, where the stage records 142 and the field says 71: the par of two rounds written into a
-- field that holds the par of one.
--
-- An implied par of nought is the third shape and it is not a par at all. It says Total Par
-- equals the round values added up, so the field holds a raw total where a score against par
-- belongs - a subtraction that never happened. Eleven events carry it, and eight of them are one
-- tournament: Barracuda Championship, under that name and its earlier one Reno-Tahoe Open, is
-- the tour's Modified Stableford event, played for points rather than strokes. Measured
-- 2026-08-14, the database stores those points in the stroke fields 31-34 and writes no 526-529
-- point value at all for any edition from 2012 to 2018; 2025 is the first to carry the point
-- types, and carries both. The International 2006 was a separate tournament played under the
-- same format. So for these the rounds are not stroke counts, the arithmetic this check asserts
-- does not apply to them, and what wants correcting is the result type rather than the par.
--
-- The remaining two - EDS Byron Nelson Championship 2008 and ANZ Championship 2004 - are
-- ordinary stroke play where part of the field carries a raw total anyway, which is why the
-- shape is reported by what it is rather than by the tournament it usually belongs to.
--
-- Stages carrying no Par at all are not audited and are not eligible. 43282 participations sit
-- under 592 such events, and what they need is the value entered rather than corrected.
FROM (
    SELECT
        b.event_id,
        b.event_name,
        b.stage_id,
        b.stage_name,
        b.tournament_name,
        b.template_name,
        b.stage_par,
        b.implied_par,
        COUNT(*) AS competitors_behind_it,
        MAX(b.testable) AS competitors_measured,
        ROW_NUMBER() OVER (PARTITION BY b.event_id ORDER BY COUNT(*) DESC, b.implied_par) AS rn
    FROM (
        SELECT
            a.event_id,
            a.event_name,
            a.stage_id,
            a.stage_name,
            a.tournament_name,
            a.template_name,
            CAST(pp.par_value AS SIGNED) AS stage_par,
            CASE WHEN MOD(a.par_total - (a.sum_rounds - CAST(pp.par_value AS SIGNED) * a.n_rounds), a.n_rounds) = 0
                 THEN CAST(CAST(pp.par_value AS SIGNED)
                           - (a.par_total - (a.sum_rounds - CAST(pp.par_value AS SIGNED) * a.n_rounds)) / a.n_rounds
                           AS SIGNED)
            END AS implied_par,
            COUNT(*) OVER (PARTITION BY a.event_id) AS testable
        FROM (
            SELECT
                ep.id AS ep_id,
                e.id AS event_id,
                e.name AS event_name,
                ts.id AS stage_id,
                ts.name AS stage_name,
                t.name AS tournament_name,
                tt.name AS template_name,
                SUM(CASE WHEN r.result_typeFK IN (31, 32, 33, 34, 35)
                          AND TRIM(r.value) REGEXP '^[0-9]+$'
                         THEN CAST(TRIM(r.value) AS SIGNED) ELSE 0 END) AS sum_rounds,
                SUM(CASE WHEN r.result_typeFK IN (31, 32, 33, 34, 35)
                          AND TRIM(r.value) REGEXP '^[0-9]+$'
                         THEN 1 ELSE 0 END) AS n_rounds,
                MAX(CASE WHEN r.result_typeFK = 36
                          AND TRIM(r.value) REGEXP '^[+-]?[0-9]+$'
                         THEN CAST(REPLACE(TRIM(r.value), '+', '') AS SIGNED) END) AS par_total
            FROM event_participants ep
            JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
                 AND e.status_type = 'finished'
            JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
            JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
            JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
                 AND tt.sportFK = 3
            JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id
                 AND od.del = 'no' AND od.disciplineFK = 629
            JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
                 AND r.result_typeFK IN (31, 32, 33, 34, 35, 36)
            WHERE ep.del = 'no'
              AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
              -- AND t.tournament_templateFK = <tournament_template_id>
              -- AND e.startdate >= '<from_datetime>'
              -- AND e.startdate <  '<to_datetime>'
            GROUP BY ep.id, e.id, e.name, ts.id, ts.name, t.name, tt.name
        ) a
        JOIN (
            SELECT objectFK AS stage_id, MAX(value) AS par_value
            FROM property
            WHERE object = 'tournament_stage' AND name = 'Par' AND del = 'no'
            GROUP BY objectFK
        ) pp ON pp.stage_id = a.stage_id AND pp.par_value REGEXP '^[0-9]+$'
        WHERE a.n_rounds > 0
          AND a.par_total IS NOT NULL
    ) b
    WHERE b.implied_par IS NOT NULL
    GROUP BY b.event_id, b.event_name, b.stage_id, b.stage_name, b.tournament_name,
             b.template_name, b.stage_par, b.implied_par
) d
WHERE d.rn = 1
  AND d.implied_par <> d.stage_par

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
-- The same population reached without aggregating it. An event is eligible when its stage
-- records a numeric Par and at least one of its competitors holds both a numeric round and a
-- numeric Total Par - which is what n_rounds > 0 and par_total IS NOT NULL say above, one
-- competitor at a time. Asking whether such a competitor exists lets the event stop at the
-- first one instead of grouping all 362000 participations a second time. The branch runs in
-- 0.7 seconds alone and takes the whole statement from 45.9 to 30.6, for the identical 2698.
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 3
JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id
     AND od.del = 'no' AND od.disciplineFK = 629
JOIN property pp ON pp.object = 'tournament_stage' AND pp.objectFK = ts.id
     AND pp.name = 'Par' AND pp.del = 'no' AND pp.value REGEXP '^[0-9]+$'
WHERE e.del = 'no'
  AND e.status_type = 'finished'
  AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND EXISTS (
      SELECT 1
      FROM event_participants ep
      JOIN result rr ON rr.event_participantsFK = ep.id AND rr.del = 'no'
           AND rr.result_typeFK IN (31, 32, 33, 34, 35)
           AND TRIM(rr.value) REGEXP '^[0-9]+$'
      JOIN result rp ON rp.event_participantsFK = ep.id AND rp.del = 'no'
           AND rp.result_typeFK = 36
           AND TRIM(rp.value) REGEXP '^[+-]?[0-9]+$'
      WHERE ep.eventFK = e.id AND ep.del = 'no'
  )

ORDER BY sort_order, competitors_behind_it DESC, event_id;
-- ==============================================================================
SELECT
    -- CheckID - Golf-DQ-101
    -- Name - EVENT_RESULTS_CARD_TOTAL_PAR_CONTRADICTS_ITS_OWN_ROUNDS
    -- What it does: Flags a competitor whose score against par does not follow from their own rounds, in an event where nearly every other card does.
    'CARD_TOTAL_PAR_CONTRADICTS_ITS_OWN_ROUNDS' AS check_type,
    w.event_id,
    w.event_name,
    w.season,
    w.participant_name,
    w.field_par AS the_field_par,
    w.n_rounds AS rounds_played,
    w.sum_rounds AS strokes_recorded,
    w.par_total AS total_par_recorded,
    w.sum_rounds - w.field_par * w.n_rounds AS total_par_expected,
    w.cards_wrong_here,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Finds a competitor whose Total Par is not their strokes minus the
-- course par once per round played, in an event where at most three cards disagree - so the par
-- is not in question and the card is.
--
-- The other half of Golf-DQ-100, and it has to be a separate statement because it audits a
-- different object. That one reads the par a whole field agrees on and reports the event whose
-- stage records something else; this one takes that same agreed par as settled and reports the
-- individual card that does not reach it. Its finding is one competitor, and the row carries what
-- the Total Par should have been so the correction is legible without opening anything.
--
-- Why at most three, and why that is not a threshold dressed up as a rule. Two formats break this
-- arithmetic while breaking no data, and neither is visible in the database. A tournament played
-- on more than one course gives each competitor a different par per round against a stage that
-- records one - Pebble Beach Pro-Am, Joburg Open, Dunhill Links, British Boys Amateur. Tour
-- Championship has started its field at a staggered score under FedExCup Starting Strokes since
-- 2019, so a Total Par contains strokes nobody played. Both reach the whole field: 155 of 156,
-- 209 of 210, 25 of 30 in each of six consecutive years. A wrong card reaches one competitor.
-- Counting how many cards in the event disagree is therefore what tells a format apart from a
-- mistake, and three is where the sport's own populations leave a gap rather than where a
-- convenient line falls. SPORTS/Golf.md records both formats.
--
-- Measured 2026-08-14 inside the client boundary. Of 2680 events whose stage records a numeric
-- Par, 2081 have no disagreeing card at all and 415 have one, two or three - 639 cards, which is
-- this check. The remaining 184 events are the formats above and a residue that has not been read
-- yet; they are deliberately outside this statement rather than silently absent from it, and none
-- of them is audited here.
--
-- Two things a round field can hold that are not a round, both found by the reviewers on
-- 2026-08-19 and both fixed here rather than by a threshold.
--
-- A zero is not a round of nought strokes, it is a round nobody played: 3699 of them across 157
-- events, and a card reading 68, 71, 0, 0 is a competitor who missed the cut after two rounds.
-- Counting the zeros made that card four rounds against two rounds of strokes, so the arithmetic
-- could not hold and 39 cards were reported for having missed a cut. A round now counts only if
-- it is a positive whole number.
--
-- Some events store the score against par in the round fields instead of the strokes. There are
-- 1193 negative values across 29 events, and 28 of those events hold no stroke count at all -
-- Barracuda Championship, Reno-Tahoe Open, Blue Label Challenge, The International - which are
-- Modified Stableford, where a competitor collects points rather than strokes. ANZ Championship
-- 2004 is the same shape without the name: Steve Webster reads 14, 13, 12, -2 and his Total Par
-- is 37, which is their sum. The subtraction this statement performs has no meaning on any of
-- them.
--
-- The test for it is the course par rather than a number chosen here. A field playing strokes
-- always contains somebody who took at least par on a round; a field collecting points never
-- reaches it, because the totals are single digits against a par of seventy. So an event where
-- no card's best round reaches the par its stage records is not audited, and rounds_are_strokes_here
-- carries that decision from the event down to the card. The sport's own populations say the same
-- thing without the test: 1643476 round values sit between 60 and 99 across 4825 events, and
-- below 60 there are fewer than 8000 across at most 112.
--
-- Both changes together took this class from 574 findings to 528. What moved is not only the
-- subtraction: 16 cards became visible that the zeros had been hiding, because an event whose
-- cards were all zero-inflated exceeded the at-most-three rule and was dropped whole. Those
-- events are now auditable and only their outliers surface. Eight of the sixteen are off by one
-- or two strokes in events this statement already names as multi-course formats, and they have
-- not been read one by one.
--
-- The par the field agrees on is the same construction Golf-DQ-100 uses, and it is built here
-- with window functions rather than a second pass: each distinct implied par is counted within
-- its event, and the first one under a descending vote is taken. A card whose difference does not
-- divide by the rounds it played implies no par, casts no vote - COUNT over the column rather
-- than over the row is what makes that true - and is a finding rather than an authority.
FROM (
    SELECT
        f.event_id,
        f.event_name,
        f.season,
        f.participant_name,
        f.n_rounds,
        f.sum_rounds,
        f.par_total,
        f.implied_par,
        f.field_par,
        f.rounds_are_strokes_here,
        SUM(CASE WHEN f.implied_par IS NULL OR f.implied_par <> f.field_par THEN 1 ELSE 0 END)
            OVER (PARTITION BY f.event_id) AS cards_wrong_here
    FROM (
        SELECT
            v.event_id,
            v.event_name,
            v.season,
            v.participant_name,
            v.n_rounds,
            v.sum_rounds,
            v.par_total,
            v.implied_par,
            v.rounds_are_strokes_here,
            FIRST_VALUE(v.implied_par) OVER (
                PARTITION BY v.event_id
                ORDER BY v.votes DESC, v.implied_par
                ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS field_par
        FROM (
            SELECT
                b.event_id,
                b.event_name,
                b.season,
                b.participant_name,
                b.n_rounds,
                b.sum_rounds,
                b.par_total,
                b.implied_par,
                b.rounds_are_strokes_here,
                COUNT(b.implied_par) OVER (PARTITION BY b.event_id, b.implied_par) AS votes
            FROM (
                SELECT
                    a.event_id,
                    a.event_name,
                    a.season,
                    a.participant_name,
                    a.n_rounds,
                    a.sum_rounds,
                    a.par_total,
                    MAX(CASE WHEN a.best_round >= CAST(pp.par_value AS SIGNED) THEN 1 ELSE 0 END)
                        OVER (PARTITION BY a.event_id) AS rounds_are_strokes_here,
                    CASE WHEN MOD(a.par_total - (a.sum_rounds - CAST(pp.par_value AS SIGNED) * a.n_rounds), a.n_rounds) = 0
                         THEN CAST(CAST(pp.par_value AS SIGNED)
                                   - (a.par_total - (a.sum_rounds - CAST(pp.par_value AS SIGNED) * a.n_rounds)) / a.n_rounds
                                   AS SIGNED)
                    END AS implied_par
                FROM (
                    SELECT
                        ep.id AS ep_id,
                        e.id AS event_id,
                        e.name AS event_name,
                        t.name AS season,
                        p.name AS participant_name,
                        ts.id AS stage_id,
                        SUM(CASE WHEN r.result_typeFK IN (31, 32, 33, 34, 35)
                                  AND TRIM(r.value) REGEXP '^[1-9][0-9]*$'
                                 THEN CAST(TRIM(r.value) AS SIGNED) ELSE 0 END) AS sum_rounds,
                        SUM(CASE WHEN r.result_typeFK IN (31, 32, 33, 34, 35)
                                  AND TRIM(r.value) REGEXP '^[1-9][0-9]*$'
                                 THEN 1 ELSE 0 END) AS n_rounds,
                        MAX(CASE WHEN r.result_typeFK IN (31, 32, 33, 34, 35)
                                  AND TRIM(r.value) REGEXP '^[1-9][0-9]*$'
                                 THEN CAST(TRIM(r.value) AS SIGNED) END) AS best_round,
                        MAX(CASE WHEN r.result_typeFK = 36
                                  AND TRIM(r.value) REGEXP '^[+-]?[0-9]+$'
                                 THEN CAST(REPLACE(TRIM(r.value), '+', '') AS SIGNED) END) AS par_total
                    FROM event_participants ep
                    JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
                         AND e.status_type = 'finished'
                    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
                    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
                    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
                         AND tt.sportFK = 3
                    JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id
                         AND od.del = 'no' AND od.disciplineFK = 629
                    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
                    JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
                         AND r.result_typeFK IN (31, 32, 33, 34, 35, 36)
                    WHERE ep.del = 'no'
                      AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
                      -- AND t.tournament_templateFK = <tournament_template_id>
                      -- AND e.startdate >= '<from_datetime>'
                      -- AND e.startdate <  '<to_datetime>'
                    GROUP BY ep.id, e.id, e.name, t.name, p.name, ts.id
                ) a
                JOIN (
                    SELECT objectFK AS stage_id, MAX(value) AS par_value
                    FROM property
                    WHERE object = 'tournament_stage' AND name = 'Par' AND del = 'no'
                    GROUP BY objectFK
                ) pp ON pp.stage_id = a.stage_id AND pp.par_value REGEXP '^[0-9]+$'
                WHERE a.n_rounds > 0
                  AND a.par_total IS NOT NULL
            ) b
        ) v
    ) f
) w
WHERE (w.implied_par IS NULL OR w.implied_par <> w.field_par)
  AND w.cards_wrong_here BETWEEN 1 AND 3
  AND w.rounds_are_strokes_here = 1

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ep.id) AS eligible_count,
    1 AS sort_order
-- Every card the arithmetic can be asked about: a competitor holding at least one numeric round
-- and a numeric Total Par, under a stage that records a numeric Par. The two result joins say
-- exactly what n_rounds > 0 and par_total IS NOT NULL say above, one competitor at a time, and
-- reaching them by existence rather than by aggregation keeps the branch off the group-by.
FROM event_participants ep
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
     AND e.status_type = 'finished'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 3
JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id
     AND od.del = 'no' AND od.disciplineFK = 629
JOIN property pp ON pp.object = 'tournament_stage' AND pp.objectFK = ts.id
     AND pp.name = 'Par' AND pp.del = 'no' AND pp.value REGEXP '^[0-9]+$'
WHERE ep.del = 'no'
  AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND EXISTS (
      SELECT 1
      FROM result rr
      WHERE rr.event_participantsFK = ep.id AND rr.del = 'no'
        AND rr.result_typeFK IN (31, 32, 33, 34, 35)
        AND TRIM(rr.value) REGEXP '^[0-9]+$'
  )
  AND EXISTS (
      SELECT 1
      FROM result rp
      WHERE rp.event_participantsFK = ep.id AND rp.del = 'no'
        AND rp.result_typeFK = 36
        AND TRIM(rp.value) REGEXP '^[+-]?[0-9]+$'
  )

ORDER BY sort_order, event_id, participant_name;
-- ==============================================================================
SELECT
    -- CheckID - Golf-DQ-102
    -- Name - EVENT_RESULTS_CUT_FLAG_CONTRADICTS_THE_36_HOLE_ORDER
    -- What it does: Finds a card whose cut flag does not fit where its 36-hole total sits.
    CASE WHEN c.made_cut = 'no' THEN 'MISSED_CUT_CARD_BEATS_THE_CUT_LINE'
         ELSE 'MADE_CUT_CARD_TRAILS_THE_BEST_MISSED_CARD' END AS check_type,
    c.event_id,
    c.event_name,
    c.season,
    c.participant_name,
    c.made_cut AS made_cut_recorded,
    c.total36 AS thirty_six_hole_total,
    c.cut_line_yes AS worst_total_that_made_the_cut,
    c.best_missed AS best_total_that_missed,
    CASE WHEN c.made_cut = 'no' THEN c.n_no_better ELSE c.n_yes_worse END AS cards_on_this_side,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: The cut divides the field by score, so after 36 holes nobody who
-- missed it can be ahead of anybody who made it. This finds the cards where that ordering is
-- broken, and reports whichever side of the line holds fewer of them.
--
-- Why the smaller side is the finding, and not the cards that break the order. The cut line is
-- not stored; it is read off the field as the worst 36-hole total among the players flagged as
-- having made the cut. One player wrongly flagged as having made it therefore moves the line to
-- their own score, and every correctly missed player between the true line and that score then
-- looks wrong. Measured on John Deere Classic 2011: 63 cards appear to beat the line, and the
-- shorter explanation is a single made-cut card sitting seven strokes behind the last real
-- qualifier. Counting both sides and reporting the smaller one names the card that has to change
-- rather than the crowd it displaced.
--
-- Two populations are outside the question rather than clean inside it, and both are the sport
-- rather than the storage. A card ending wd, dq, rtd, dns, nr or n/r stops mid-tournament and is
-- flagged as not having made the cut whatever it scored, so a withdrawal after a good Friday is
-- the convention; 531 such cards break the order legitimately. A card commented mdf made the cut
-- and did not finish, and Golf-DQ-103 owns the flag it should carry. SPORTS/Golf.md owns the
-- comment vocabulary and why wd is not a no-result marker in this sport.
--
-- The cut is not always after 36 holes, and that is read structurally rather than guessed. Where
-- any card flagged as having missed the cut holds a round-three score, the cut in that event came
-- later - AT&T Pebble Beach Pro-Am, The American Express and Alfred Dunhill Links all cut after
-- 54 holes - and a 36-hole comparison is simply the wrong comparison there. Those events are
-- excluded by that structure and not by a count.
--
-- A round of zero strokes is read as absent rather than as a score, which is arithmetic and not
-- a threshold: eighteen holes cannot be completed in no strokes. 2976 such values sit in 119
-- events, and two of them reached this statement as a 36-hole total of 0 that would have been
-- reported against the cut flag instead of against itself.
--
-- Measured 2026-08-14 inside the client boundary: 48 events hold one to three cards on the
-- smaller side, 43 findings on the missed-cut side and 14 on the made-cut side, for 57 in all,
-- over 342070 cards the question can be asked about. Fifteen further events hold four or more;
-- they are Barracuda Championship and the other Modified Stableford fields, where a higher total
-- is better and the whole order inverts, and they are left out of this statement deliberately.
-- POWERBI.md records that decision.
FROM (
    SELECT
        b.event_id,
        b.event_name,
        b.season,
        b.participant_name,
        b.made_cut,
        b.total36,
        b.cut_line_yes,
        b.best_missed,
        b.late_after_cut,
        SUM(CASE WHEN b.made_cut = 'no' AND b.total36 < b.cut_line_yes THEN 1 ELSE 0 END)
            OVER (PARTITION BY b.event_id) AS n_no_better,
        SUM(CASE WHEN b.made_cut = 'yes' AND b.total36 > b.best_missed THEN 1 ELSE 0 END)
            OVER (PARTITION BY b.event_id) AS n_yes_worse
    FROM (
        SELECT
            a.event_id,
            a.event_name,
            a.season,
            a.participant_name,
            a.made_cut,
            a.total36,
            MAX(CASE WHEN a.made_cut = 'yes' THEN a.total36 END)
                OVER (PARTITION BY a.event_id) AS cut_line_yes,
            MIN(CASE WHEN a.made_cut = 'no' THEN a.total36 END)
                OVER (PARTITION BY a.event_id) AS best_missed,
            SUM(CASE WHEN a.made_cut = 'no' AND a.late_rounds > 0 THEN 1 ELSE 0 END)
                OVER (PARTITION BY a.event_id) AS late_after_cut
        FROM (
            SELECT
                e.id AS event_id,
                e.name AS event_name,
                t.name AS season,
                p.name AS participant_name,
                MAX(CASE WHEN r.result_typeFK = 38 THEN LOWER(TRIM(r.value)) END) AS made_cut,
                MAX(CASE WHEN r.result_typeFK = 104 THEN LOWER(TRIM(r.value)) END) AS comment_value,
                SUM(CASE WHEN r.result_typeFK IN (31, 32) AND TRIM(r.value) REGEXP '^[1-9][0-9]*$'
                         THEN CAST(TRIM(r.value) AS SIGNED) ELSE 0 END) AS total36,
                SUM(CASE WHEN r.result_typeFK IN (31, 32) AND TRIM(r.value) REGEXP '^[1-9][0-9]*$'
                         THEN 1 ELSE 0 END) AS n36,
                SUM(CASE WHEN r.result_typeFK IN (33, 34, 35) AND TRIM(r.value) REGEXP '^[0-9]+$'
                         THEN 1 ELSE 0 END) AS late_rounds
            FROM event_participants ep
            JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
                 AND e.status_type = 'finished'
            JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
            JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
            JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
                 AND tt.sportFK = 3
            JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id
                 AND od.del = 'no' AND od.disciplineFK = 629
            JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
            JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
                 AND r.result_typeFK IN (31, 32, 33, 34, 35, 38, 104)
            WHERE ep.del = 'no'
              AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
              -- AND t.tournament_templateFK = <tournament_template_id>
              -- AND e.startdate >= '<from_datetime>'
              -- AND e.startdate <  '<to_datetime>'
            GROUP BY ep.id, e.id, e.name, t.name, p.name
            HAVING n36 = 2
               AND made_cut IN ('yes', 'no')
               AND (comment_value IS NULL
                    OR comment_value NOT IN ('wd', 'dq', 'rtd', 'dns', 'nr', 'n/r', 'mdf', 'mc'))
        ) a
    ) b
) c
WHERE c.late_after_cut = 0
  AND (
        (c.made_cut = 'no'  AND c.total36 < c.cut_line_yes
         AND c.n_no_better <= c.n_yes_worse AND c.n_no_better BETWEEN 1 AND 3)
     OR (c.made_cut = 'yes' AND c.total36 > c.best_missed
         AND c.n_yes_worse <  c.n_no_better AND c.n_yes_worse BETWEEN 1 AND 3)
      )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ep.id) AS eligible_count,
    1 AS sort_order
-- Every card the cut can be asked about: a competitor holding both a numeric first and second
-- round, a cut flag of yes or no, and no comment that ends the participation early. The four
-- existence tests say what n36 = 2, made_cut IN ('yes','no') and the comment exclusion say above,
-- one competitor at a time, which keeps the branch off the group-by.
FROM event_participants ep
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
     AND e.status_type = 'finished'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 3
JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id
     AND od.del = 'no' AND od.disciplineFK = 629
WHERE ep.del = 'no'
  AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND EXISTS (
      SELECT 1 FROM result r1
      WHERE r1.event_participantsFK = ep.id AND r1.del = 'no'
        AND r1.result_typeFK = 31 AND TRIM(r1.value) REGEXP '^[1-9][0-9]*$'
  )
  AND EXISTS (
      SELECT 1 FROM result r2
      WHERE r2.event_participantsFK = ep.id AND r2.del = 'no'
        AND r2.result_typeFK = 32 AND TRIM(r2.value) REGEXP '^[1-9][0-9]*$'
  )
  AND EXISTS (
      SELECT 1 FROM result r3
      WHERE r3.event_participantsFK = ep.id AND r3.del = 'no'
        AND r3.result_typeFK = 38 AND LOWER(TRIM(r3.value)) IN ('yes', 'no')
  )
  AND NOT EXISTS (
      SELECT 1 FROM result r4
      WHERE r4.event_participantsFK = ep.id AND r4.del = 'no'
        AND r4.result_typeFK = 104
        AND LOWER(TRIM(r4.value)) IN ('wd', 'dq', 'rtd', 'dns', 'nr', 'n/r', 'mdf', 'mc')
  )

ORDER BY sort_order, event_id, participant_name;
-- ==============================================================================
SELECT
    -- CheckID - Golf-DQ-103
    -- Name - EVENT_RESULTS_CUT_FLAG_CONTRADICTS_THE_ROUNDS_THE_CARD_HOLDS
    -- What it does: Flags a card flagged as having missed the cut that nevertheless holds a round played after it, and a card commented mdf that is not flagged as having made the cut.
    CASE WHEN b.comment_value = 'mdf' AND (b.made_cut IS NULL OR b.made_cut <> 'yes')
              THEN 'MDF_COMMENT_WITHOUT_A_MADE_CUT_FLAG'
         ELSE 'MISSED_CUT_CARD_HOLDS_A_ROUND_PLAYED_AFTER_THE_CUT' END AS check_type,
    b.event_id,
    b.event_name,
    b.season,
    b.participant_name,
    b.made_cut AS made_cut_recorded,
    b.comment_value AS comment_recorded,
    b.late_rounds AS rounds_after_the_cut,
    b.cards_like_this_here AS cards_like_this_in_the_event,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: A player who misses the cut goes home, so the rounds they hold
-- and the flag that says whether they survived have to agree. Two disagreements are reported.
-- A card flagged as not having made the cut that holds a third, fourth or fifth round played
-- one of them after being sent home. A card commented mdf made the cut and did not finish -
-- SPORTS/Golf.md owns that reading - so it cannot also be flagged as having missed it.
--
-- Why the first branch counts the event, and the second does not. A cut is not always after two
-- rounds. AT&T Pebble Beach Pro-Am, The American Express and Alfred Dunhill Links cut after 54
-- holes, so their missed-cut players correctly hold a third round and the whole field carries
-- the shape - 66 to 106 cards at a time. That is the same discriminator Golf-DQ-101 is built on
-- and for the same reason: a fact about the format reaches every card in the event, and a wrong
-- flag reaches one. The mdf branch needs no such guard, because no format makes mdf mean
-- anything other than what it means.
--
-- Counting the cards is not enough on its own, and the reviewers found where it fails: an event
-- that cuts after 54 holes and sends only one, two or three players home has a whole missed-cut
-- group holding a third round, and the count reads that group as three individual mistakes.
-- Measured 2026-08-19, that is 26 events and 30 cards out of the 166 this branch reported. The
-- second condition asks the question the count was standing in for - whether anybody in the
-- event's missed-cut group went home after two rounds - so the format is recognised at any field
-- size, down to a group of one.
--
-- What the count still decides, and what it therefore still lets through: 87 events where some of
-- the missed-cut group holds a third round and the rest do not, 3541 cards, each event carrying
-- more than three of them. Those are the sport contradicting itself inside one event and they are
-- not reported here, because lifting the count is a separate decision against the 200-row gate
-- rather than a repair of this one. Measured 2026-08-19 and recorded so the number is not
-- rediscovered as a surprise.
--
-- Measured 2026-08-14 inside the client boundary, 284 findings over 350235 cards. 166 of them
-- were cards flagged as having missed the cut while holding a later round, one to three per
-- event, and 136 remain after the 54-hole cuts with small groups were separated out on
-- 2026-08-19; the events holding more are outside the statement. 118 are mdf cards,
-- and the sport itself settles those: of 1547 mdf cards inside the boundary, 1429 carry the flag
-- yes and 118 carry no, the second group concentrated in 14 events rather than scattered. A
-- twelve-to-one majority is the convention, so the minority is the defect and not a second
-- reading. Where the flag is absent altogether rather than wrong - 11728 cards in 151 events,
-- whole fields at a time - the shape is an event that never stored the flag, which is a different
-- finding and not this one. POWERBI.md records this statement against the 200-row gate.
FROM (
    SELECT
        a.event_id,
        a.event_name,
        a.season,
        a.participant_name,
        a.made_cut,
        a.comment_value,
        a.late_rounds,
        SUM(CASE WHEN a.made_cut = 'no' AND a.late_rounds > 0
                  AND (a.comment_value IS NULL OR a.comment_value <> 'mdf')
                 THEN 1 ELSE 0 END) OVER (PARTITION BY a.event_id) AS cards_like_this_here,
        SUM(CASE WHEN a.made_cut = 'no'
                  AND (a.comment_value IS NULL OR a.comment_value <> 'mdf')
                 THEN 1 ELSE 0 END) OVER (PARTITION BY a.event_id) AS missed_cut_cards_here
    FROM (
        SELECT
            e.id AS event_id,
            e.name AS event_name,
            t.name AS season,
            p.name AS participant_name,
            MAX(CASE WHEN r.result_typeFK = 38 THEN LOWER(TRIM(r.value)) END) AS made_cut,
            MAX(CASE WHEN r.result_typeFK = 104 THEN LOWER(TRIM(r.value)) END) AS comment_value,
            SUM(CASE WHEN r.result_typeFK IN (33, 34, 35) AND TRIM(r.value) REGEXP '^[1-9][0-9]*$'
                     THEN 1 ELSE 0 END) AS late_rounds
        FROM event_participants ep
        JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
             AND e.status_type = 'finished'
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
             AND tt.sportFK = 3
        JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id
             AND od.del = 'no' AND od.disciplineFK = 629
        JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
        JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
             AND r.result_typeFK IN (33, 34, 35, 38, 104)
        WHERE ep.del = 'no'
          AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
          -- AND t.tournament_templateFK = <tournament_template_id>
          -- AND e.startdate >= '<from_datetime>'
          -- AND e.startdate <  '<to_datetime>'
        GROUP BY ep.id, e.id, e.name, t.name, p.name
    ) a
) b
WHERE (
        (b.made_cut = 'no' AND b.late_rounds > 0
         AND (b.comment_value IS NULL OR b.comment_value <> 'mdf')
         AND b.cards_like_this_here BETWEEN 1 AND 3
         AND b.cards_like_this_here < b.missed_cut_cards_here)
     OR (b.comment_value = 'mdf' AND (b.made_cut IS NULL OR b.made_cut <> 'yes'))
      )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ep.id) AS eligible_count,
    1 AS sort_order
-- Every card either branch can speak about: a competitor carrying a cut flag, or carrying the
-- mdf comment that implies one. A card with neither holds nothing for this statement to read,
-- and the absent-flag population is counted in the note above rather than audited here.
FROM event_participants ep
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
     AND e.status_type = 'finished'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 3
JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id
     AND od.del = 'no' AND od.disciplineFK = 629
WHERE ep.del = 'no'
  AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND EXISTS (
      SELECT 1 FROM result rf
      WHERE rf.event_participantsFK = ep.id AND rf.del = 'no'
        AND (
              (rf.result_typeFK = 38 AND LOWER(TRIM(rf.value)) IN ('yes', 'no'))
           OR (rf.result_typeFK = 104 AND LOWER(TRIM(rf.value)) = 'mdf')
            )
  )

ORDER BY sort_order, event_id, participant_name;
-- ==============================================================================
SELECT
    -- CheckID - Golf-DQ-104
    -- Name - EVENT_RESULTS_RANK_CONTRADICTS_THE_TOTAL_PAR_IT_IS_BUILT_ON
    -- What it does: Flags a card finishing ahead of another card that scored better over the same number of rounds, in an event where at most three cards do.
    'RANK_CONTRADICTS_THE_TOTAL_PAR_IT_IS_BUILT_ON' AS check_type,
    d.event_id,
    d.event_name,
    d.season,
    d.participant_name,
    d.rank_value AS rank_recorded,
    d.par_total AS total_par_recorded,
    d.n_rounds AS rounds_played,
    d.best_rank_among_worse AS rank_held_by_a_worse_score,
    d.cards_wrong_here,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: In stroke play the finishing order is the scoring order, so a
-- card cannot be placed behind a card that scored worse. This compares each competitor with
-- every competitor in the same event who played the same number of rounds and returned a
-- strictly worse Total Par, and reports the card whose rank is worse than the best rank any of
-- them holds.
--
-- It asks about order and never about the number. An expected rank cannot be computed here: the
-- field also contains withdrawals and disqualifications that hold places this statement does not
-- read, so any counting of positions ahead would be short by however many of those are in front.
-- Ties make the same trouble from the other side, since a shared place can be written as the
-- first of the tied positions or as each of them. Comparing two cards with each other is immune
-- to both, and it is the whole of what the rule says.
--
-- Rounds played is part of the comparison and not a filter on it. A Total Par over two rounds and
-- a Total Par over four are two different measurements, and a player who missed the cut is
-- correctly placed behind a player who finished with a worse four-round score. Partitioning on
-- the round count compares only what is comparable, which is why no cut flag appears here at all.
--
-- Cards ending wd, dq, rtd, dns, nr, n/r, mc or mdf are outside the population. Their place is
-- assigned by where the field left them rather than by their score - SPORTS/Golf.md records that
-- a withdrawal keeps its position in this sport - so their rank owes the score nothing.
--
-- Measured 2026-08-14 inside the client boundary: 15 events hold one to three such cards, for 16
-- findings over 331329 cards. 37 further events hold four or more, 2106 cards, and they are not
-- a longer version of the same defect. In 22 of them the order is not disturbed but reversed,
-- because the card is scored in Stableford points where the higher total wins - Barracuda
-- Championship in twelve editions, Reno-Tahoe Open in two, The International in four, ANZ
-- Championship in three and Asian Mixed Stableford Challenge 2022, together 1838 cards.
-- Golf-DQ-105 reports those once per event, which is where the decision actually sits, and this
-- statement leaves them out. The remaining 15 events hold 268 cards; Zurich Classic of New
-- Orleans 2023 and Women's World Cup of Golf 2005 are team formats and T-Mobile Match Play 2024
-- is match play, so a stroke ordering does not apply to them, and the rest have not been read.
-- They are recorded as undecided rather than counted clean. SPORTS/Golf.md owns the formats and
-- POWERBI.md the decision.
FROM (
    SELECT
        c.event_id,
        c.event_name,
        c.season,
        c.participant_name,
        c.rank_value,
        c.par_total,
        c.n_rounds,
        c.best_rank_among_worse,
        SUM(CASE WHEN c.best_rank_among_worse < c.rank_value THEN 1 ELSE 0 END)
            OVER (PARTITION BY c.event_id) AS cards_wrong_here
    FROM (
        SELECT
            b.event_id,
            b.event_name,
            b.season,
            b.participant_name,
            b.rank_value,
            b.par_total,
            b.n_rounds,
            MIN(b.rank_value) OVER (PARTITION BY b.event_id, b.n_rounds ORDER BY b.par_total
                                    RANGE BETWEEN 1 FOLLOWING AND UNBOUNDED FOLLOWING)
                AS best_rank_among_worse
        FROM (
            SELECT
                e.id AS event_id,
                e.name AS event_name,
                t.name AS season,
                p.name AS participant_name,
                MAX(CASE WHEN r.result_typeFK = 104 THEN LOWER(TRIM(r.value)) END) AS comment_value,
                MAX(CASE WHEN r.result_typeFK = 100 AND TRIM(r.value) REGEXP '^[0-9]+$'
                         THEN CAST(TRIM(r.value) AS SIGNED) END) AS rank_value,
                MAX(CASE WHEN r.result_typeFK = 36 AND TRIM(r.value) REGEXP '^[+-]?[0-9]+$'
                         THEN CAST(REPLACE(TRIM(r.value), '+', '') AS SIGNED) END) AS par_total,
                SUM(CASE WHEN r.result_typeFK IN (31, 32, 33, 34, 35)
                          AND TRIM(r.value) REGEXP '^[1-9][0-9]*$'
                         THEN 1 ELSE 0 END) AS n_rounds
            FROM event_participants ep
            JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
                 AND e.status_type = 'finished'
            JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
            JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
            JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
                 AND tt.sportFK = 3
            JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id
                 AND od.del = 'no' AND od.disciplineFK = 629
            JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
            JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
                 AND r.result_typeFK IN (31, 32, 33, 34, 35, 36, 100, 104)
            WHERE ep.del = 'no'
              AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
              -- AND t.tournament_templateFK = <tournament_template_id>
              -- AND e.startdate >= '<from_datetime>'
              -- AND e.startdate <  '<to_datetime>'
            GROUP BY ep.id, e.id, e.name, t.name, p.name
            HAVING rank_value IS NOT NULL
               AND par_total IS NOT NULL
               AND n_rounds > 0
               AND (comment_value IS NULL
                    OR comment_value NOT IN ('wd', 'dq', 'rtd', 'dns', 'nr', 'n/r', 'mdf', 'mc'))
        ) b
    ) c
) d
WHERE d.best_rank_among_worse < d.rank_value
  AND d.cards_wrong_here BETWEEN 1 AND 3

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ep.id) AS eligible_count,
    1 AS sort_order
-- Every card the comparison can be made on: a competitor holding a numeric rank, a numeric Total
-- Par, at least one round actually played, and no comment that ends the participation early. The
-- four tests say what the HAVING above says, one competitor at a time.
FROM event_participants ep
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
     AND e.status_type = 'finished'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 3
JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id
     AND od.del = 'no' AND od.disciplineFK = 629
WHERE ep.del = 'no'
  AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND EXISTS (
      SELECT 1 FROM result rk
      WHERE rk.event_participantsFK = ep.id AND rk.del = 'no'
        AND rk.result_typeFK = 100 AND TRIM(rk.value) REGEXP '^[0-9]+$'
  )
  AND EXISTS (
      SELECT 1 FROM result rp
      WHERE rp.event_participantsFK = ep.id AND rp.del = 'no'
        AND rp.result_typeFK = 36 AND TRIM(rp.value) REGEXP '^[+-]?[0-9]+$'
  )
  AND EXISTS (
      SELECT 1 FROM result rr
      WHERE rr.event_participantsFK = ep.id AND rr.del = 'no'
        AND rr.result_typeFK IN (31, 32, 33, 34, 35) AND TRIM(rr.value) REGEXP '^[1-9][0-9]*$'
  )
  AND NOT EXISTS (
      SELECT 1 FROM result rc
      WHERE rc.event_participantsFK = ep.id AND rc.del = 'no'
        AND rc.result_typeFK = 104
        AND LOWER(TRIM(rc.value)) IN ('wd', 'dq', 'rtd', 'dns', 'nr', 'n/r', 'mdf', 'mc')
  )

ORDER BY sort_order, event_id, rank_recorded;
-- ==============================================================================
SELECT
    -- CheckID - Golf-DQ-105
    -- Name - EVENT_RESULTS_THE_WINNER_DOES_NOT_HOLD_THE_BEST_TOTAL_PAR
    -- What it does: Finds an event whose first-placed card is not the best score in its own field.
    CASE WHEN d.leader_par = d.worst_par
              THEN 'WINNER_HOLDS_THE_WORST_TOTAL_PAR_SO_THE_FIELD_IS_ORDERED_THE_OTHER_WAY'
         ELSE 'WINNER_DOES_NOT_HOLD_THE_BEST_TOTAL_PAR' END AS check_type,
    d.event_id,
    d.event_name,
    d.season,
    d.template_name,
    d.leader_par AS total_par_of_the_first_place,
    d.best_par AS best_total_par_in_the_field,
    d.worst_par AS worst_total_par_in_the_field,
    d.cards_read,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: One sentence of the rules decides a stroke-play event - the
-- lowest score wins - so whoever is written into first place must hold the lowest Total Par in
-- their own field. This reads each event's field once and reports the event where they do not.
--
-- The audited object is the event, and that is the point rather than a convenience. Golf-DQ-104
-- asks the same question of a single card and is answered by a single card; this one is answered
-- by a decision taken over the whole field, so 146 rows saying the same thing about Barracuda
-- Championship 2023 would be 146 copies of one finding. Reporting the event once puts the
-- decision where somebody can actually take it.
--
-- The two check types are two different findings sharing one test. Where the first place holds
-- the worst score in the field, the order is not damaged but inverted, and the field is not being
-- read wrongly - it is being scored in Stableford points, where the higher total wins and the
-- points are stored in the stroke fields this project reads as strokes. Where the first place
-- holds neither the best nor the worst, one card is wrong and the event needs opening.
--
-- Measured 2026-08-14 inside the client boundary, over 3281 events carrying a first place and a
-- Total Par: 3257 are clean, 22 are inverted and 2 are neither. Every one of the 22 is a Modified
-- Stableford field - Barracuda Championship in eleven editions, Reno-Tahoe Open in two, The
-- International in four, ANZ Championship in three and Asian Mixed Stableford Challenge 2022.
-- The statement is expected to keep returning them for as long as the sport stores points in
-- stroke fields, and that is its value: it names every such event without being told which
-- tournaments they are, which is how the format was found in the first place.
--
-- Of the two events where the first place holds neither the best nor the worst score, Ladies
-- Scottish Open 2010 is a card to open - the winner is written at +1 in a field whose best is 0 -
-- and T-Mobile Match Play 2024 is match play, where a stroke total decides nothing. A format
-- reaching the second check type is expected: the test is what the field is ordered by, and match
-- play is not ordered by strokes at all. SPORTS/Golf.md owns both formats.
FROM (
    SELECT
        b.event_id,
        b.event_name,
        b.season,
        b.template_name,
        COUNT(*) AS cards_read,
        MIN(b.par_total) AS best_par,
        MAX(b.par_total) AS worst_par,
        MIN(CASE WHEN b.rank_value = 1 THEN b.par_total END) AS leader_par
    FROM (
        SELECT
            e.id AS event_id,
            e.name AS event_name,
            t.name AS season,
            tt.name AS template_name,
            MAX(CASE WHEN r.result_typeFK = 104 THEN LOWER(TRIM(r.value)) END) AS comment_value,
            MAX(CASE WHEN r.result_typeFK = 100 AND TRIM(r.value) REGEXP '^[0-9]+$'
                     THEN CAST(TRIM(r.value) AS SIGNED) END) AS rank_value,
            MAX(CASE WHEN r.result_typeFK = 36 AND TRIM(r.value) REGEXP '^[+-]?[0-9]+$'
                     THEN CAST(REPLACE(TRIM(r.value), '+', '') AS SIGNED) END) AS par_total,
            SUM(CASE WHEN r.result_typeFK IN (31, 32, 33, 34, 35)
                      AND TRIM(r.value) REGEXP '^[1-9][0-9]*$'
                     THEN 1 ELSE 0 END) AS n_rounds
        FROM event_participants ep
        JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
             AND e.status_type = 'finished'
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
             AND tt.sportFK = 3
        JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id
             AND od.del = 'no' AND od.disciplineFK = 629
        JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
             AND r.result_typeFK IN (31, 32, 33, 34, 35, 36, 100, 104)
        WHERE ep.del = 'no'
          AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
          -- AND t.tournament_templateFK = <tournament_template_id>
          -- AND e.startdate >= '<from_datetime>'
          -- AND e.startdate <  '<to_datetime>'
        GROUP BY ep.id, e.id, e.name, t.name, tt.name
        HAVING rank_value IS NOT NULL
           AND par_total IS NOT NULL
           AND n_rounds > 0
           AND (comment_value IS NULL
                OR comment_value NOT IN ('wd', 'dq', 'rtd', 'dns', 'nr', 'n/r', 'mdf', 'mc'))
    ) b
    GROUP BY b.event_id, b.event_name, b.season, b.template_name
) d
WHERE d.leader_par IS NOT NULL
  AND d.leader_par <> d.best_par

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
-- Every event the question can be put to: one holding at least one card written into first place
-- that also carries a numeric Total Par, a round actually played, and no comment ending the
-- participation early. An event whose first place is missing or unscored is not clean here and
-- not dirty either - there is nothing to compare - and GLOBAL-DQ-122 owns the missing value.
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 3
JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id
     AND od.del = 'no' AND od.disciplineFK = 629
WHERE e.del = 'no'
  AND e.status_type = 'finished'
  AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND EXISTS (
      SELECT 1
      FROM event_participants ep
      JOIN result rk ON rk.event_participantsFK = ep.id AND rk.del = 'no'
           AND rk.result_typeFK = 100 AND TRIM(rk.value) = '1'
      JOIN result rp ON rp.event_participantsFK = ep.id AND rp.del = 'no'
           AND rp.result_typeFK = 36 AND TRIM(rp.value) REGEXP '^[+-]?[0-9]+$'
      WHERE ep.eventFK = e.id AND ep.del = 'no'
  )

ORDER BY sort_order, event_id;
-- ==============================================================================
SELECT
    -- CheckID - Golf-DQ-106
    -- Name - EVENT_RESULTS_A_ROUND_IS_SKIPPED_IN_THE_ROUND_SEQUENCE
    -- What it does: Finds an event holding a card that carries a round without the round before it.
    'A_ROUND_IS_SKIPPED_IN_THE_ROUND_SEQUENCE' AS check_type,
    b.event_id,
    b.event_name,
    b.season,
    b.template_name,
    GROUP_CONCAT(DISTINCT NULLIF(b.gap_kind, '') ORDER BY b.gap_kind SEPARATOR ' / ') AS gaps_found,
    SUM(CASE WHEN b.gap_kind <> '' THEN 1 ELSE 0 END) AS cards_affected,
    COUNT(*) AS cards_in_the_event,
    MIN(CASE WHEN b.gap_kind <> '' THEN b.participant_name END) AS one_of_the_players,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Rounds are played in order, so a card holding a fourth round must
-- hold a third, and a card holding a second must hold a first. This reads every card in the sport
-- and reports the event where one of them does not, together with how many of its field carry the
-- same gap and which round is missing.
--
-- The audited object is the event because the two shapes it finds are both event decisions. Where
-- a single card skips a round, the event is where the other rounds are and where somebody has to
-- look; where the whole field skips one, nothing about the individual card is wrong and the
-- storage of the event is. Reporting the card instead would have turned 21 events into 1027 rows
-- carrying one decision each, so the row says how many cards and names one of them, which is
-- enough to find the rest.
--
-- No threshold decides anything here, which is why this statement needs none of the field-share
-- reasoning Golf-DQ-101 and Golf-DQ-103 carry. Every gap is reported; the cards_affected and
-- cards_in_the_event columns beside it are what tell a storage decision apart from a lost score,
-- and the reader makes that call rather than the WHERE clause.
--
-- A zero counts as a round that is present here, which is the opposite of what Golf-DQ-102 and
-- Golf-DQ-104 do with the same value, and the difference is the question rather than an
-- inconsistency. Those statements do arithmetic on a stroke count, and no eighteen holes are
-- played in no strokes. This one asks whether the field was filled in at all, and a zero is
-- something somebody wrote. Reading a zero as absent here reported every Modified Stableford
-- event a second time - a round worth no points is a real round in that format - which is
-- Golf-DQ-105's finding and not this one.
--
-- Measured 2026-08-14 inside the client boundary: 18 events of 3302. Office Depot Championship
-- 2005 is the clearest single decision - 66 of 143 cards hold a fourth round with no third - and
-- Marathon Classic 2018, European Girls' Team Championship 2025 and Portugal Masters 2014 hold
-- one to three cards each, which is a lost score rather than a decision. Twelve of the eighteen
-- are the Modified Stableford tournaments Golf-DQ-105 also reports, and the two findings are not
-- the same: that one says the field is ordered the other way, this one says a round slot inside
-- it was never filled. Both are true of those events and both need doing.
FROM (
    SELECT
        a.event_id,
        a.event_name,
        a.season,
        a.template_name,
        a.participant_name,
        TRIM(COALESCE(CONCAT_WS(' / ',
            CASE WHEN a.h2 = 1 AND a.h1 = 0 THEN 'round 2 without round 1' END,
            CASE WHEN a.h3 = 1 AND a.h2 = 0 THEN 'round 3 without round 2' END,
            CASE WHEN a.h4 = 1 AND a.h3 = 0 THEN 'round 4 without round 3' END,
            CASE WHEN a.h5 = 1 AND a.h4 = 0 THEN 'round 5 without round 4' END), '')) AS gap_kind
    FROM (
        SELECT
            e.id AS event_id,
            e.name AS event_name,
            t.name AS season,
            tt.name AS template_name,
            p.name AS participant_name,
            MAX(CASE WHEN r.result_typeFK = 31 THEN 1 ELSE 0 END) AS h1,
            MAX(CASE WHEN r.result_typeFK = 32 THEN 1 ELSE 0 END) AS h2,
            MAX(CASE WHEN r.result_typeFK = 33 THEN 1 ELSE 0 END) AS h3,
            MAX(CASE WHEN r.result_typeFK = 34 THEN 1 ELSE 0 END) AS h4,
            MAX(CASE WHEN r.result_typeFK = 35 THEN 1 ELSE 0 END) AS h5
        FROM event_participants ep
        JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
             AND e.status_type = 'finished'
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
             AND tt.sportFK = 3
        JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id
             AND od.del = 'no' AND od.disciplineFK = 629
        JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
        JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
             AND r.result_typeFK IN (31, 32, 33, 34, 35)
             AND TRIM(r.value) REGEXP '^[0-9]+$'
        WHERE ep.del = 'no'
          AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
          -- AND t.tournament_templateFK = <tournament_template_id>
          -- AND e.startdate >= '<from_datetime>'
          -- AND e.startdate <  '<to_datetime>'
        GROUP BY ep.id, e.id, e.name, t.name, tt.name, p.name
    ) a
) b
GROUP BY b.event_id, b.event_name, b.season, b.template_name
HAVING cards_affected > 0

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
-- Every event holding at least one round actually played by somebody. An event storing no round
-- score has no sequence to be out of order, and Golf-DQ-063 owns the event with no results at all.
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 3
JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id
     AND od.del = 'no' AND od.disciplineFK = 629
WHERE e.del = 'no'
  AND e.status_type = 'finished'
  AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND EXISTS (
      SELECT 1
      FROM event_participants ep
      JOIN result rr ON rr.event_participantsFK = ep.id AND rr.del = 'no'
           AND rr.result_typeFK IN (31, 32, 33, 34, 35)
           AND TRIM(rr.value) REGEXP '^[0-9]+$'
      WHERE ep.eventFK = e.id AND ep.del = 'no'
  )

ORDER BY sort_order, event_id;
-- ==============================================================================
SELECT
    -- CheckID - Golf-DQ-107
    -- Name - EVENT_RESULTS_PRIZE_MONEY_CONTRADICTS_THE_FINISHING_ORDER
    -- What it does: Flags a card paid less than a card that finished behind it in the same event.
    'PRIZE_MONEY_CONTRADICTS_THE_FINISHING_ORDER' AS check_type,
    d.event_id,
    d.event_name,
    d.season,
    d.template_name,
    d.participant_name,
    d.rank_value AS rank_recorded,
    d.prize AS prize_money_recorded,
    d.best_prize_behind AS most_paid_to_a_worse_finish,
    d.cards_wrong_here,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: A purse is paid down the finishing order, so nobody is paid less
-- than somebody who finished behind them. This compares each card with every card in the same
-- event holding a strictly worse rank, and reports the card paid less than the most any of them
-- received.
--
-- Ties need no handling and get none. Players sharing a position share the combined money for the
-- positions they cover and are paid equally, so the comparison is made against strictly worse
-- ranks only and two cards on the same place never test each other. That also means a tie paid
-- unequally is outside this statement rather than hidden by it.
--
-- A card paid nothing is not a low point on the purse curve, it is off the curve, and leaving it
-- in was the difference between this statement being right and being noise. Two entirely correct
-- populations carry a zero: a player who missed the cut earns nothing, and an amateur cannot
-- accept prize money however well they finish. The second is the one that bites, because an
-- amateur's zero sits beside a good finishing place. Run with zeros included, this statement
-- returned 24 rows and all 24 were the same fact - Asterisk Talley, Kiara Romero, Maria Marin,
-- Farah O'Keefe and nine other amateurs across thirteen 2026 LPGA events, one of them placed
-- sixth in the US Women's Open beside a paid seventh. Rule 3-2b of the Rules of Amateur Status
-- is not a data-quality finding. Comparing only cards that were actually paid is what the rule
-- about purses actually says. SPORTS/Golf.md records the measurement.
--
-- Prize money is a thin layer in this sport and the coverage count says so rather than hiding it.
-- 9593 values exist sport-wide and 5449 paid cards inside the client boundary carry a rank too,
-- over 78 events of the 3302 that stored a result. A small eligible population is not a weak
-- check here: where the money is stored, it is stored for the whole field.
--
-- Measured 2026-08-14 inside the client boundary: no findings. That is the check working rather
-- than the check being empty - the purse ran down the order in every event that recorded one -
-- and the invariant it guards does not need a population to be worth guarding. No golf format
-- pays backwards, so unlike Golf-DQ-101 and Golf-DQ-103 this statement applies no field-share
-- test and would report every card it found.
FROM (
    SELECT
        c.event_id,
        c.event_name,
        c.season,
        c.template_name,
        c.participant_name,
        c.rank_value,
        c.prize,
        c.best_prize_behind,
        SUM(CASE WHEN c.best_prize_behind > c.prize THEN 1 ELSE 0 END)
            OVER (PARTITION BY c.event_id) AS cards_wrong_here
    FROM (
        SELECT
            b.event_id,
            b.event_name,
            b.season,
            b.template_name,
            b.participant_name,
            b.rank_value,
            b.prize,
            MAX(b.prize) OVER (PARTITION BY b.event_id ORDER BY b.rank_value
                               RANGE BETWEEN 1 FOLLOWING AND UNBOUNDED FOLLOWING) AS best_prize_behind
        FROM (
            SELECT
                e.id AS event_id,
                e.name AS event_name,
                t.name AS season,
                tt.name AS template_name,
                p.name AS participant_name,
                MAX(CASE WHEN r.result_typeFK = 100 AND TRIM(r.value) REGEXP '^[0-9]+$'
                         THEN CAST(TRIM(r.value) AS SIGNED) END) AS rank_value,
                MAX(CASE WHEN r.result_typeFK = 540 AND TRIM(r.value) REGEXP '^[0-9]+(\\.[0-9]+)?$'
                         THEN CAST(TRIM(r.value) AS DECIMAL(14,2)) END) AS prize
            FROM event_participants ep
            JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
                 AND e.status_type = 'finished'
            JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
            JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
            JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
                 AND tt.sportFK = 3
            JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id
                 AND od.del = 'no' AND od.disciplineFK = 629
            JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
            JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
                 AND r.result_typeFK IN (100, 540)
            WHERE ep.del = 'no'
              AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
              -- AND t.tournament_templateFK = <tournament_template_id>
              -- AND e.startdate >= '<from_datetime>'
              -- AND e.startdate <  '<to_datetime>'
            GROUP BY ep.id, e.id, e.name, t.name, tt.name, p.name
            HAVING rank_value IS NOT NULL AND prize > 0
        ) b
    ) c
) d
WHERE d.best_prize_behind > d.prize

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT ep.id) AS eligible_count,
    1 AS sort_order
-- Every card carrying both a finishing place and money actually paid, which is what the comparison
-- needs on each side. A card holding a rank and a zero is outside the question and not a finding
-- of it, for the reason given above; most of the sport stores no purse at all, and an
-- eligible_count far below the sport's card count is the layer being thin rather than the scope
-- being wrong.
FROM event_participants ep
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
     AND e.status_type = 'finished'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 3
JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id
     AND od.del = 'no' AND od.disciplineFK = 629
WHERE ep.del = 'no'
  AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND EXISTS (
      SELECT 1 FROM result rk
      WHERE rk.event_participantsFK = ep.id AND rk.del = 'no'
        AND rk.result_typeFK = 100 AND TRIM(rk.value) REGEXP '^[0-9]+$'
  )
  AND EXISTS (
      SELECT 1 FROM result rm
      WHERE rm.event_participantsFK = ep.id AND rm.del = 'no'
        AND rm.result_typeFK = 540 AND TRIM(rm.value) REGEXP '^[0-9]+(\\.[0-9]+)?$'
        AND CAST(TRIM(rm.value) AS DECIMAL(14,2)) > 0
  )

ORDER BY sort_order, event_id, rank_recorded;
-- ==============================================================================
SELECT
    -- CheckID - Golf-DQ-108
    -- Name - EVENT_HOLES_PLAYED_CONTRADICTS_THE_MATCH_PLAY_SCORE
    -- What it does: Flags a finished Match Play event whose recorded holes played do not follow from the margin its own score reports.
    CASE WHEN d.expected_thru IS NOT NULL THEN 'HOLES_PLAYED_DOES_NOT_MATCH_THE_MARGIN'
         ELSE 'MATCH_WENT_THE_DISTANCE_BUT_STOPPED_EARLY' END AS check_type,
    d.event_id,
    d.event_name,
    d.event_startdate,
    d.template_name,
    d.round_type,
    d.score_value AS match_play_score,
    d.thru_num AS holes_played_recorded,
    COALESCE(d.expected_thru, 18) AS holes_played_expected,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: A match play score says when the match ended as well as who won.
-- 2&1 means two holes up with one to play, so the match stopped after 17 holes; 3&2 after 16.
-- A/S and Nup mean it went the full distance. The event property current_hole records how many
-- holes were played, so the two have to agree, and this reports the events where they do not.
--
-- The rule is not that a finished match reads 18. That is what it looked like from the Builder,
-- where current_hole moves 17 to 18 in the same edit that moves status_type to finished, and
-- measuring it on 2026-08-14 replaced the guess with the arithmetic: of 2936 finished matches
-- carrying both an X&Y score and a numeric current_hole, 2797 hold exactly 18 minus the holes
-- remaining. A check asserting 18 would have called those 2797 defects, which is most of the
-- population it was meant to protect.
--
-- Nor is more than 18 wrong. A match tied after 18 goes to sudden death, so 19 and 20 are the
-- 19th and 20th holes, and the amateur championships play 36-hole finals, so 36 is a full match
-- rather than double one. Both are correct and both are why the second check type asks for at
-- least 18 rather than for 18. What it forbids is the impossible direction: a match reported all
-- square or won by a margin at the last hole, with fewer than eighteen holes played.
--
-- current_hole belongs to match play alone, which corrects what was written from the Builder.
-- Measured across every discipline in the sport: 4860 of 12993 finished match play events carry
-- it and no stroke play event carries it at all, in any status. That is a property scoped to the
-- discipline that needs it rather than a property missing from 3306 stroke play events, and it is
-- why this statement's scope is disciplineFK 630.
--
-- The 8133 finished match play events holding no current_hole are outside this comparison and
-- are not counted clean by it. Whether the property should be there at all is a question about
-- the layer rather than about these events, and it is not asked here.
--
-- Measured 2026-08-14 inside the client boundary: 278 findings over 4686 events, 139 on each
-- branch. The margin branch is unambiguous - a match reported won 2&1 with 18 holes played, or
-- 3&2 with 13 - and it is 139 against 2797 that agree exactly, so the arithmetic is the rule and
-- the disagreement is the exception.
--
-- Two populations the arithmetic cannot be asked about at all, both found by the reviewers on
-- 2026-08-19 and both excluded here rather than reported.
--
-- A sudden-death play-off plays until somebody wins a hole, so 1up after one hole is the result
-- and not a match that stopped early. The round type says so - round_typeFK 305, Playoff - and
-- 31 events carried it, every one of them on the distance branch. Lauren Coughlin against Lucy
-- Li is the shape: one hole played, 1up, won and lost written on the two cards, nothing wrong
-- with any of it.
--
-- A match somebody walked out of did not go the distance either. WD and WO are written in the
-- Match Play Score field of the card that left - 20 and 27 events hold one - while the other
-- card carries the margin, so the event still entered through the surviving score and was
-- judged as though both had played on. Two of the findings were that. The COVERAGE note below
-- already said these are outside the statement; it was only true where no other card carried a
-- notation the arithmetic reads.
--
-- Both exclusions reach the eligible population as well as the findings, because an event this
-- statement cannot judge is not an event it found clean. 278 findings over 4686 events become
-- 245 over 4640.
--
-- The round type travels as a column at the reviewers' asking, so an event that should have been
-- excluded and was not can be seen without opening anything. Only the name; the id would have
-- ended in _id and moved the key a reviewer's row-level notes are held by.
--
-- The distance branch carries one thing this project has not settled, and it is left visible
-- rather than resolved by assertion. 60 of its 139 events read exactly 6 holes played beside a
-- final margin, on European Tour 1 across 2010, 2017, 2018, 2019 and 2022, in clusters of a
-- tournament week at a time. A value frozen mid-match and never updated on finishing is what the
-- Builder's own behaviour suggests - it moves current_hole to its final value in the same edit
-- that finishes the event - but a 6-hole match play format would produce the same shape and this
-- has not been confirmed either way. If those weeks turn out to be a short-form format, they
-- belong in SPORTS/Golf.md beside the Modified Stableford and 54-hole-cut entries and out of this
-- statement. Reported as findings meanwhile, because an unexplained 6 is a question somebody
-- should answer rather than a population to drop.
FROM (
    SELECT
        c.event_id,
        c.event_name,
        c.event_startdate,
        c.template_name,
        c.round_type,
        c.score_value,
        c.thru_num,
        c.expected_thru
    FROM (
        SELECT
            b.event_id,
            b.event_name,
            b.event_startdate,
            b.template_name,
            b.round_type,
            b.score_value,
            b.thru_num,
            CASE WHEN b.score_value REGEXP '^[0-9]+&[0-9]+$'
                 THEN 18 - CAST(SUBSTRING_INDEX(b.score_value, '&', -1) AS SIGNED)
            END AS expected_thru,
            CASE WHEN UPPER(b.score_value) = 'A/S' OR LOWER(b.score_value) REGEXP '^[0-9]+up$'
                 THEN 1 ELSE 0 END AS went_the_distance
        FROM (
            SELECT
                e.id AS event_id,
                e.name AS event_name,
                e.startdate AS event_startdate,
                tt.name AS template_name,
                rt.name AS round_type,
                SUM(CASE WHEN UPPER(REPLACE(REPLACE(TRIM(ms.value), '/', ''), '&', '')) IN ('WD', 'WO')
                         THEN 1 ELSE 0 END) AS abandoned_cards,
                MAX(CASE WHEN TRIM(pr.value) REGEXP '^[0-9]+$'
                         THEN CAST(TRIM(pr.value) AS SIGNED) END) AS thru_num,
                MAX(CASE WHEN TRIM(ms.value) REGEXP '^[0-9]+&[0-9]+$'
                           OR UPPER(TRIM(ms.value)) = 'A/S'
                           OR LOWER(TRIM(ms.value)) REGEXP '^[0-9]+up$'
                         THEN TRIM(ms.value) END) AS score_value
            FROM event e
            JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
            JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
            JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
                 AND tt.sportFK = 3
            JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id
                 AND od.del = 'no' AND od.disciplineFK = 630
            LEFT JOIN round_type rt ON rt.id = e.round_typeFK
            JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
            LEFT JOIN result ms ON ms.event_participantsFK = ep.id AND ms.result_typeFK = 39
                 AND ms.del = 'no' AND TRIM(ms.value) <> ''
            LEFT JOIN property pr ON pr.object = 'event' AND pr.objectFK = e.id
                 AND pr.name = 'current_hole' AND pr.del = 'no'
            WHERE e.del = 'no'
              AND e.status_type = 'finished'
              AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
              -- AND t.tournament_templateFK = <tournament_template_id>
              -- AND e.startdate >= '<from_datetime>'
              -- AND e.startdate <  '<to_datetime>'
            GROUP BY e.id, e.name, e.startdate, tt.name, rt.name
        ) b
        WHERE b.thru_num IS NOT NULL
          AND b.score_value IS NOT NULL
          AND b.abandoned_cards = 0
          AND (b.round_type IS NULL OR b.round_type <> 'Playoff')
    ) c
    WHERE (c.expected_thru IS NOT NULL AND c.thru_num <> c.expected_thru)
       OR (c.expected_thru IS NULL AND c.thru_num < 18)
) d

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT y.event_id) AS eligible_count,
    1 AS sort_order
-- Every finished Match Play event that answers both halves of the question: a numeric
-- current_hole, and a score in a notation that implies how many holes were played. Scores the
-- notation does not settle - WO for a walkover, WD for a withdrawal, and the point values a team
-- match awards - are outside this statement because no number of holes follows from them.
FROM (
    SELECT e.id AS event_id
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = 3
    JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id
         AND od.del = 'no' AND od.disciplineFK = 630
    JOIN property pr ON pr.object = 'event' AND pr.objectFK = e.id
         AND pr.name = 'current_hole' AND pr.del = 'no'
         AND TRIM(pr.value) REGEXP '^[0-9]+$'
    LEFT JOIN round_type rtc ON rtc.id = e.round_typeFK
    WHERE e.del = 'no'
      AND e.status_type = 'finished'
      AND (rtc.name IS NULL OR rtc.name <> 'Playoff')
      AND NOT EXISTS (
          SELECT 1
          FROM event_participants epw
          JOIN result msw ON msw.event_participantsFK = epw.id AND msw.result_typeFK = 39
               AND msw.del = 'no'
               AND UPPER(REPLACE(REPLACE(TRIM(msw.value), '/', ''), '&', '')) IN ('WD', 'WO')
          WHERE epw.eventFK = e.id AND epw.del = 'no'
      )
      AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
      AND EXISTS (
          SELECT 1
          FROM event_participants epx
          JOIN result msx ON msx.event_participantsFK = epx.id AND msx.result_typeFK = 39
               AND msx.del = 'no'
          WHERE epx.eventFK = e.id AND epx.del = 'no'
            AND (TRIM(msx.value) REGEXP '^[0-9]+&[0-9]+$'
                 OR UPPER(TRIM(msx.value)) = 'A/S'
                 OR LOWER(TRIM(msx.value)) REGEXP '^[0-9]+up$')
      )
    GROUP BY e.id
) y

ORDER BY sort_order, event_startdate DESC, event_id;
