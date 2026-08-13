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

ORDER BY sort_order, statistic_id;
