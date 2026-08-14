SELECT
    -- CheckID - Golf-DQ-085
    -- Name - COMP.RANK_SETTINGS_MEDAL_SET_INVALID_IN_MEDAL_TEMPLATE
    -- What it does: Finds Comp.Rank under a Golf template that awards medals whose medal set does not follow the places its own Rank rows hold: a type missing, held by more competitors than the place takes, held by fewer, or standing over a podium that never reaches the place it belongs to.
    CASE
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
    -- What it does: Finds finished Stroke Play events holding a Rank that is not a plain positive integer up to the sport's maximum, or missing from a player who neither carries a Comment nor is recorded as having missed the cut, counting each verdict and naming who holds it.
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
    -- What it does: Finds Stroke Play event names breaking a text-hygiene rule - spacing, control or corrupted characters, hyphenation, capitalisation, a placeholder or a numeric-only name - one row per name, naming every rule it breaks.
    'Name_Format_Invalid' AS check_type,
    MIN(x.object_name) AS event_name,
    x.violation_types,
    COUNT(DISTINCT x.object_id) AS affected_object_count,
    MIN(x.object_id) AS sample_object_id,
    MIN(x.template_name) AS sample_template_name,
    MIN(x.stage_name) AS sample_stage_name,
    NULL AS eligible_count,
    0 AS sort_order
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
    -- What it does: Finds Match Play events whose name is built from their competitors but does not name one of them, separating naming none of them from naming only some.
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
    -- What it does: Finds Golf tournament stages whose declared dates fail to contain the events they hold - starting after the first, ending before the last, or running more than a week past the last - counting the events and naming the span they occupy.
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
    -- What it does: Finds Golf tournaments named for a single year whose events fall outside the season that year names, which runs from the September before it to the end of it, separating one starting too early from one running past its year.
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
    -- What it does: Finds finished two-sided Match Play events whose outcome does not hold together - no winner recorded though the match was scored, both sides winning, a winner with no loser, a draw on one side only, a word Final Result does not use, or a Match Play Score contradicting the result it sits beside.
    z.check_type,
    z.event_id,
    z.event_name,
    z.event_startdate,
    z.template_name,
    z.final_results_held,
    z.scores_held,
    NULL AS eligible_count,
    0 AS sort_order
-- The first check to read a Match Play outcome at all. Golf contests 12984 finished Match Play
-- events inside the client boundary and until this nothing asked whether their results were
-- coherent; GLOBAL-DQ-094 is the template for it and cannot instantiate here, because it reads
-- the placing off a pair of numeric scores and this sport stores words in 4 Final Result -
-- won, lost and draw - with golf's own notation in 39 Match Play Score: 1up, 2&1, A/S.
--
-- Two-sided matches only, and that is a limitation rather than a filter. 2132 finished Match
-- Play events carry four participant rows because a foursome is two players a side, and
-- nothing in the database says which two belong together - no lineup, no team field. Until
-- SPORTS/Golf.md's first open question is answered those events cannot be judged: one row per
-- side is exactly what this check counts, and a four-row event has no side it can count.
--
-- Measured 2026-08-13. 1293 of the findings are one shape: a match scored in 39 with no winner
-- named in 4, and they arrive about 63 to a template-season - the size of a 64-player bracket -
-- so what is missing is the verdict on whole draws rather than scattered rows. 6 more hold no
-- result of any type. The rest are small and sharp: 60 scores reading X&Y where X is not the
-- larger, 13 draws carrying a deciding score, 2 events where Final Result holds a number, and
-- 2 all-square scores on a match the result says was won.
FROM (
    SELECT
        CASE
            WHEN x.unknown_words > 0 THEN 'FINAL_RESULT_NOT_A_KNOWN_WORD'
            WHEN x.won > 1 THEN 'BOTH_SIDES_WON'
            WHEN x.won = 1 AND x.lost <> 1 THEN 'WINNER_WITHOUT_A_LOSER'
            WHEN x.draws = 1 THEN 'DRAW_ON_ONE_SIDE_ONLY'
            WHEN x.draws = 2 AND x.won > 0 THEN 'DRAW_AND_WINNER_TOGETHER'
            WHEN x.won = 0 AND x.draws = 0 AND x.any_results = 0 THEN 'NO_RESULT_OF_ANY_TYPE'
            WHEN x.won = 0 AND x.draws = 0 THEN 'FINAL_RESULT_MISSING_BUT_MATCH_SCORED'
            WHEN x.all_square > 0 AND x.draws = 0 THEN 'SCORE_ALL_SQUARE_BUT_MATCH_DECIDED'
            WHEN x.draws = 2 AND x.decided_scores > 0 THEN 'DRAW_WITH_A_DECIDING_SCORE'
            WHEN x.malformed_holes > 0 THEN 'SCORE_HOLES_BEFORE_REMAINING'
            ELSE 'OUTCOME_SHAPE_UNCLASSIFIED'
        END AS check_type,
        x.event_id,
        x.event_name,
        x.event_startdate,
        x.template_name,
        CONCAT('won ', x.won, ', lost ', x.lost, ', draw ', x.draws) AS final_results_held,
        x.score_values AS scores_held
    FROM (
        SELECT
            e.id AS event_id,
            e.name AS event_name,
            e.startdate AS event_startdate,
            tt.name AS template_name,
            COUNT(DISTINCT ep.id) AS sides,
            SUM(CASE WHEN LOWER(TRIM(fr.value)) = 'won' THEN 1 ELSE 0 END) AS won,
            SUM(CASE WHEN LOWER(TRIM(fr.value)) = 'lost' THEN 1 ELSE 0 END) AS lost,
            SUM(CASE WHEN LOWER(TRIM(fr.value)) = 'draw' THEN 1 ELSE 0 END) AS draws,
            SUM(CASE WHEN fr.value IS NOT NULL AND TRIM(fr.value) <> ''
                      AND LOWER(TRIM(fr.value)) NOT IN ('won', 'lost', 'draw') THEN 1 ELSE 0 END) AS unknown_words,
            SUM(CASE WHEN UPPER(TRIM(ms.value)) = 'A/S' THEN 1 ELSE 0 END) AS all_square,
            SUM(CASE WHEN ms.value IS NOT NULL AND TRIM(ms.value) <> ''
                      AND UPPER(TRIM(ms.value)) <> 'A/S' THEN 1 ELSE 0 END) AS decided_scores,
            SUM(CASE WHEN TRIM(ms.value) REGEXP '^[0-9]+&[0-9]+$'
                      AND CAST(SUBSTRING_INDEX(TRIM(ms.value), '&', 1) AS UNSIGNED)
                          <= CAST(SUBSTRING_INDEX(TRIM(ms.value), '&', -1) AS UNSIGNED)
                     THEN 1 ELSE 0 END) AS malformed_holes,
            GROUP_CONCAT(DISTINCT NULLIF(TRIM(ms.value), '') ORDER BY TRIM(ms.value) SEPARATOR ' | ') AS score_values,
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
        GROUP BY e.id, e.name, e.startdate, tt.name
        HAVING COUNT(DISTINCT ep.id) = 2
    ) x
    -- A halved match is the sport working: draw on both sides, no winner, no loser. It is
    -- excluded here rather than classified, because a check that reports 565 correct halves
    -- teaches its reader to skip the column they were meant to read.
    WHERE x.unknown_words > 0
       OR NOT ((x.won = 1 AND x.lost = 1 AND x.draws = 0)
            OR (x.won = 0 AND x.lost = 0 AND x.draws = 2))
       OR (x.all_square > 0 AND x.draws = 0)
       OR (x.draws = 2 AND x.decided_scores > 0)
       OR x.malformed_holes > 0
) z

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT y.event_id) AS eligible_count,
    1 AS sort_order
FROM (
    SELECT e.id AS event_id
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
         AND od.disciplineFK = 630
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    WHERE e.del = 'no'
      AND tt.sportFK = 3
      AND e.status_type = 'finished'
      AND t.tournament_templateFK NOT IN (432, 435, 438, 9142, 9201, 9418, 9633, 9645, 9691, 9692, 9693, 9831, 9932, 10305, 10333, 10334, 10341, 11528, 11529, 12649)
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY e.id
    HAVING COUNT(DISTINCT ep.id) = 2
) y

ORDER BY sort_order, event_startdate DESC, event_id;

-- ==============================================================================
SELECT
    -- CheckID - Golf-DQ-093
    -- Name - COMP.RANK_RESULTS_PARTICIPANT_NOT_IN_TOURNAMENT
    -- What it does: Finds Comp.Rank statistics holding participants who took no part in any event under their own tournament, counting the strays and naming them.
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
    -- What it does: Finds Comp.Rank statistics holding a Rank above the largest place golf can award, counting the affected competitors and naming them with the value each carries.
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
    -- What it does: Finds Comp.Rank statistics ranking competitors beyond the number of competitors they hold, where the rank is also cut off from the next lower one and carries no Comment.
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
    -- What it does: Finds events whose covering Comp.Rank leaves out competitors who took part, naming how many of the field are missing and who they are.
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
    -- What it does: Finds final_result scope values naming an event participant from a different event, or one that is not active, so the value is attached to a competitor who did not play it.
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
