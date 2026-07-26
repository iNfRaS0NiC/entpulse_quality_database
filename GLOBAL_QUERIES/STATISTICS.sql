SELECT
    -- CheckID - GLOBAL-DISCOVERY-015
    -- Name - STATISTIC_TYPES_AND_OWNERS
    -- What it does: Lists statistic types and owner levels reachable through known sport hierarchy and sport-registry paths for the selected sport.
    st.statistic_typeFK AS statistic_type_id,
    stt.name AS statistic_type_name,
    st.object_typeFK AS statistic_owner_type_id,
    CASE st.object_typeFK
        WHEN 1 THEN 'sport'
        WHEN 2 THEN 'tournament_template'
        WHEN 3 THEN 'tournament'
        WHEN 4 THEN 'tournament_stage'
        WHEN 5 THEN 'event'
        WHEN 6 THEN 'event_participants'
        WHEN 15 THEN 'participant_via_sport_registry'
        ELSE 'unsupported_owner_path'
    END AS owner_path,
    COUNT(DISTINCT st.id) AS statistic_count,
    MIN(st.id) AS sample_statistic_id,
    MIN(st.name) AS sample_statistic_name
FROM statistic st
LEFT JOIN statistic_type stt
  ON stt.id = st.statistic_typeFK
LEFT JOIN sport sport_owner
  ON st.object_typeFK = 1
 AND sport_owner.id = st.objectFK
 AND sport_owner.del = 'no'
LEFT JOIN tournament_template tt2
  ON st.object_typeFK = 2
 AND tt2.id = st.objectFK
 AND tt2.del = 'no'
LEFT JOIN tournament t3
  ON st.object_typeFK = 3
 AND t3.id = st.objectFK
 AND t3.del = 'no'
LEFT JOIN tournament_template tt3
  ON tt3.id = t3.tournament_templateFK
 AND tt3.del = 'no'
LEFT JOIN tournament_stage ts4
  ON st.object_typeFK = 4
 AND ts4.id = st.objectFK
 AND ts4.del = 'no'
LEFT JOIN tournament t4
  ON t4.id = ts4.tournamentFK
 AND t4.del = 'no'
LEFT JOIN tournament_template tt4
  ON tt4.id = t4.tournament_templateFK
 AND tt4.del = 'no'
LEFT JOIN event e5
  ON st.object_typeFK = 5
 AND e5.id = st.objectFK
 AND e5.del = 'no'
LEFT JOIN tournament_stage ts5
  ON ts5.id = e5.tournament_stageFK
 AND ts5.del = 'no'
LEFT JOIN tournament t5
  ON t5.id = ts5.tournamentFK
 AND t5.del = 'no'
LEFT JOIN tournament_template tt5
  ON tt5.id = t5.tournament_templateFK
 AND tt5.del = 'no'
LEFT JOIN event_participants ep6
  ON st.object_typeFK = 6
 AND ep6.id = st.objectFK
 AND ep6.del = 'no'
LEFT JOIN event e6
  ON e6.id = ep6.eventFK
 AND e6.del = 'no'
LEFT JOIN tournament_stage ts6
  ON ts6.id = e6.tournament_stageFK
 AND ts6.del = 'no'
LEFT JOIN tournament t6
  ON t6.id = ts6.tournamentFK
 AND t6.del = 'no'
LEFT JOIN tournament_template tt6
  ON tt6.id = t6.tournament_templateFK
 AND tt6.del = 'no'
LEFT JOIN participant p15
  ON st.object_typeFK = 15
 AND p15.id = st.objectFK
 AND p15.del = 'no'
LEFT JOIN object_participants op15
  ON op15.object = 'sport'
 AND op15.participantFK = p15.id
 AND op15.del = 'no'
WHERE st.del = 'no'
  AND (
      sport_owner.id = {{SPORT_ID}}
      OR tt2.sportFK = {{SPORT_ID}}
      OR tt3.sportFK = {{SPORT_ID}}
      OR tt4.sportFK = {{SPORT_ID}}
      OR tt5.sportFK = {{SPORT_ID}}
      OR tt6.sportFK = {{SPORT_ID}}
      OR op15.objectFK = {{SPORT_ID}}
  )
GROUP BY
    st.statistic_typeFK,
    stt.name,
    st.object_typeFK,
    owner_path
ORDER BY
    st.statistic_typeFK,
    st.object_typeFK;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DISCOVERY-016
    -- Name - STATISTIC_PARTICIPANT_SHARD_USAGE
    -- What it does: Tests one physical participant shard for a confirmed statistic type and owner level in the selected sport.
    st.id AS statistic_id,
    st.name AS statistic_name,
    st.statistic_typeFK AS statistic_type_id,
    st.object_typeFK AS statistic_owner_type_id,
    COUNT(DISTINCT sp.id) AS statistic_participant_count,
    COUNT(DISTINCT sp.participantFK) AS participant_count,
    MIN(sp.id) AS sample_statistic_participant_id,
    MIN(sp.participantFK) AS sample_participant_id
FROM statistic st
LEFT JOIN sport sport_owner
  ON st.object_typeFK = 1
 AND sport_owner.id = st.objectFK
 AND sport_owner.del = 'no'
LEFT JOIN tournament_template tt2
  ON st.object_typeFK = 2
 AND tt2.id = st.objectFK
 AND tt2.del = 'no'
LEFT JOIN tournament t3
  ON st.object_typeFK = 3
 AND t3.id = st.objectFK
 AND t3.del = 'no'
LEFT JOIN tournament_template tt3
  ON tt3.id = t3.tournament_templateFK
 AND tt3.del = 'no'
LEFT JOIN tournament_stage ts4
  ON st.object_typeFK = 4
 AND ts4.id = st.objectFK
 AND ts4.del = 'no'
LEFT JOIN tournament t4
  ON t4.id = ts4.tournamentFK
 AND t4.del = 'no'
LEFT JOIN tournament_template tt4
  ON tt4.id = t4.tournament_templateFK
 AND tt4.del = 'no'
LEFT JOIN event e5
  ON st.object_typeFK = 5
 AND e5.id = st.objectFK
 AND e5.del = 'no'
LEFT JOIN tournament_stage ts5
  ON ts5.id = e5.tournament_stageFK
 AND ts5.del = 'no'
LEFT JOIN tournament t5
  ON t5.id = ts5.tournamentFK
 AND t5.del = 'no'
LEFT JOIN tournament_template tt5
  ON tt5.id = t5.tournament_templateFK
 AND tt5.del = 'no'
LEFT JOIN event_participants ep6
  ON st.object_typeFK = 6
 AND ep6.id = st.objectFK
 AND ep6.del = 'no'
LEFT JOIN event e6
  ON e6.id = ep6.eventFK
 AND e6.del = 'no'
LEFT JOIN tournament_stage ts6
  ON ts6.id = e6.tournament_stageFK
 AND ts6.del = 'no'
LEFT JOIN tournament t6
  ON t6.id = ts6.tournamentFK
 AND t6.del = 'no'
LEFT JOIN tournament_template tt6
  ON tt6.id = t6.tournament_templateFK
 AND tt6.del = 'no'
LEFT JOIN participant p15
  ON st.object_typeFK = 15
 AND p15.id = st.objectFK
 AND p15.del = 'no'
LEFT JOIN object_participants op15
  ON op15.object = 'sport'
 AND op15.participantFK = p15.id
 AND op15.del = 'no'
-- {{SHARD_ID}}: physical shard number being tested here; confirm it, then reuse the same value in GLOBAL-DISCOVERY-017/028/029
LEFT JOIN statistic_participants{{SHARD_ID}} sp
  ON sp.statisticFK = st.id
 AND sp.del = 'no'
WHERE st.del = 'no'
  AND st.statistic_typeFK = {{STATISTIC_TYPE_ID}}  -- select statistic_type_id from GLOBAL-DISCOVERY-015 (STATISTIC_TYPES_AND_OWNERS)
  AND st.object_typeFK = {{STATISTIC_OWNER_TYPE_ID}}  -- select statistic_owner_type_id from GLOBAL-DISCOVERY-015 (STATISTIC_TYPES_AND_OWNERS)
  AND (
      sport_owner.id = {{SPORT_ID}}
      OR tt2.sportFK = {{SPORT_ID}}
      OR tt3.sportFK = {{SPORT_ID}}
      OR tt4.sportFK = {{SPORT_ID}}
      OR tt5.sportFK = {{SPORT_ID}}
      OR tt6.sportFK = {{SPORT_ID}}
      OR op15.objectFK = {{SPORT_ID}}
  )
GROUP BY
    st.id,
    st.name,
    st.statistic_typeFK,
    st.object_typeFK
ORDER BY
    statistic_participant_count DESC,
    st.id;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DISCOVERY-017
    -- Name - STATISTIC_DATA_AND_CONFIG_FIELDS
    -- What it does: Lists active data and config field types for a confirmed statistic type, owner level and physical shard in the selected sport.
    x.storage_layer,
    x.statistic_data_type_id,
    x.statistic_data_type_name,
    x.statistic_data_type_detail_id,
    COUNT(*) AS value_row_count,
    COUNT(DISTINCT x.statistic_id) AS statistic_count,
    MIN(x.value) AS sample_value
-- {{SHARD_ID}}: confirmed physical shard number from GLOBAL-DISCOVERY-016 (STATISTIC_PARTICIPANT_SHARD_USAGE)
FROM (
    SELECT
        'statistic_data{{SHARD_ID}}' AS storage_layer,
        st.id AS statistic_id,
        sd.statistic_data_typeFK AS statistic_data_type_id,
        sdt.name AS statistic_data_type_name,
        sd.statistic_data_type_detailFK AS statistic_data_type_detail_id,
        sd.value
    FROM statistic_data{{SHARD_ID}} sd
    JOIN statistic_participants{{SHARD_ID}} sp
      ON sp.id = sd.statistic_participants{{SHARD_ID}}FK
     AND sp.del = 'no'
    JOIN statistic st
      ON st.id = sp.statisticFK
     AND st.del = 'no'
    LEFT JOIN statistic_data_type sdt
      ON sdt.id = sd.statistic_data_typeFK
    LEFT JOIN sport sport_owner
      ON st.object_typeFK = 1
     AND sport_owner.id = st.objectFK
     AND sport_owner.del = 'no'
    LEFT JOIN tournament_template tt2
      ON st.object_typeFK = 2
     AND tt2.id = st.objectFK
     AND tt2.del = 'no'
    LEFT JOIN tournament t3
      ON st.object_typeFK = 3
     AND t3.id = st.objectFK
     AND t3.del = 'no'
    LEFT JOIN tournament_template tt3
      ON tt3.id = t3.tournament_templateFK
     AND tt3.del = 'no'
    LEFT JOIN tournament_stage ts4
      ON st.object_typeFK = 4
     AND ts4.id = st.objectFK
     AND ts4.del = 'no'
    LEFT JOIN tournament t4
      ON t4.id = ts4.tournamentFK
     AND t4.del = 'no'
    LEFT JOIN tournament_template tt4
      ON tt4.id = t4.tournament_templateFK
     AND tt4.del = 'no'
    LEFT JOIN event e5
      ON st.object_typeFK = 5
     AND e5.id = st.objectFK
     AND e5.del = 'no'
    LEFT JOIN tournament_stage ts5
      ON ts5.id = e5.tournament_stageFK
     AND ts5.del = 'no'
    LEFT JOIN tournament t5
      ON t5.id = ts5.tournamentFK
     AND t5.del = 'no'
    LEFT JOIN tournament_template tt5
      ON tt5.id = t5.tournament_templateFK
     AND tt5.del = 'no'
    LEFT JOIN event_participants ep6
      ON st.object_typeFK = 6
     AND ep6.id = st.objectFK
     AND ep6.del = 'no'
    LEFT JOIN event e6
      ON e6.id = ep6.eventFK
     AND e6.del = 'no'
    LEFT JOIN tournament_stage ts6
      ON ts6.id = e6.tournament_stageFK
     AND ts6.del = 'no'
    LEFT JOIN tournament t6
      ON t6.id = ts6.tournamentFK
     AND t6.del = 'no'
    LEFT JOIN tournament_template tt6
      ON tt6.id = t6.tournament_templateFK
     AND tt6.del = 'no'
    LEFT JOIN participant p15
      ON st.object_typeFK = 15
     AND p15.id = st.objectFK
     AND p15.del = 'no'
    LEFT JOIN object_participants op15
      ON op15.object = 'sport'
     AND op15.participantFK = p15.id
     AND op15.del = 'no'
    WHERE sd.del = 'no'
      AND st.statistic_typeFK = {{STATISTIC_TYPE_ID}}  -- select statistic_type_id from GLOBAL-DISCOVERY-015 (STATISTIC_TYPES_AND_OWNERS)
      AND st.object_typeFK = {{STATISTIC_OWNER_TYPE_ID}}  -- select statistic_owner_type_id from GLOBAL-DISCOVERY-015 (STATISTIC_TYPES_AND_OWNERS)
      AND (
          sport_owner.id = {{SPORT_ID}}
          OR tt2.sportFK = {{SPORT_ID}}
          OR tt3.sportFK = {{SPORT_ID}}
          OR tt4.sportFK = {{SPORT_ID}}
          OR tt5.sportFK = {{SPORT_ID}}
          OR tt6.sportFK = {{SPORT_ID}}
          OR op15.objectFK = {{SPORT_ID}}
      )

    UNION ALL

    SELECT
        'statistic_config' AS storage_layer,
        st.id AS statistic_id,
        sc.statistic_data_typeFK AS statistic_data_type_id,
        sdt.name AS statistic_data_type_name,
        NULL AS statistic_data_type_detail_id,
        sc.value
    FROM statistic_config sc
    JOIN statistic st
      ON st.id = sc.statisticFK
     AND st.del = 'no'
    LEFT JOIN statistic_data_type sdt
      ON sdt.id = sc.statistic_data_typeFK
    LEFT JOIN sport sport_owner
      ON st.object_typeFK = 1
     AND sport_owner.id = st.objectFK
     AND sport_owner.del = 'no'
    LEFT JOIN tournament_template tt2
      ON st.object_typeFK = 2
     AND tt2.id = st.objectFK
     AND tt2.del = 'no'
    LEFT JOIN tournament t3
      ON st.object_typeFK = 3
     AND t3.id = st.objectFK
     AND t3.del = 'no'
    LEFT JOIN tournament_template tt3
      ON tt3.id = t3.tournament_templateFK
     AND tt3.del = 'no'
    LEFT JOIN tournament_stage ts4
      ON st.object_typeFK = 4
     AND ts4.id = st.objectFK
     AND ts4.del = 'no'
    LEFT JOIN tournament t4
      ON t4.id = ts4.tournamentFK
     AND t4.del = 'no'
    LEFT JOIN tournament_template tt4
      ON tt4.id = t4.tournament_templateFK
     AND tt4.del = 'no'
    LEFT JOIN event e5
      ON st.object_typeFK = 5
     AND e5.id = st.objectFK
     AND e5.del = 'no'
    LEFT JOIN tournament_stage ts5
      ON ts5.id = e5.tournament_stageFK
     AND ts5.del = 'no'
    LEFT JOIN tournament t5
      ON t5.id = ts5.tournamentFK
     AND t5.del = 'no'
    LEFT JOIN tournament_template tt5
      ON tt5.id = t5.tournament_templateFK
     AND tt5.del = 'no'
    LEFT JOIN event_participants ep6
      ON st.object_typeFK = 6
     AND ep6.id = st.objectFK
     AND ep6.del = 'no'
    LEFT JOIN event e6
      ON e6.id = ep6.eventFK
     AND e6.del = 'no'
    LEFT JOIN tournament_stage ts6
      ON ts6.id = e6.tournament_stageFK
     AND ts6.del = 'no'
    LEFT JOIN tournament t6
      ON t6.id = ts6.tournamentFK
     AND t6.del = 'no'
    LEFT JOIN tournament_template tt6
      ON tt6.id = t6.tournament_templateFK
     AND tt6.del = 'no'
    LEFT JOIN participant p15
      ON st.object_typeFK = 15
     AND p15.id = st.objectFK
     AND p15.del = 'no'
    LEFT JOIN object_participants op15
      ON op15.object = 'sport'
     AND op15.participantFK = p15.id
     AND op15.del = 'no'
    WHERE sc.del = 'no'
      AND st.statistic_typeFK = {{STATISTIC_TYPE_ID}}  -- select statistic_type_id from GLOBAL-DISCOVERY-015 (STATISTIC_TYPES_AND_OWNERS)
      AND st.object_typeFK = {{STATISTIC_OWNER_TYPE_ID}}  -- select statistic_owner_type_id from GLOBAL-DISCOVERY-015 (STATISTIC_TYPES_AND_OWNERS)
      AND (
          sport_owner.id = {{SPORT_ID}}
          OR tt2.sportFK = {{SPORT_ID}}
          OR tt3.sportFK = {{SPORT_ID}}
          OR tt4.sportFK = {{SPORT_ID}}
          OR tt5.sportFK = {{SPORT_ID}}
          OR tt6.sportFK = {{SPORT_ID}}
          OR op15.objectFK = {{SPORT_ID}}
      )
) AS x
GROUP BY
    x.storage_layer,
    x.statistic_data_type_id,
    x.statistic_data_type_name,
    x.statistic_data_type_detail_id
ORDER BY
    x.storage_layer,
    x.statistic_data_type_id,
    x.statistic_data_type_detail_id;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DISCOVERY-030
    -- Name - STATISTIC_DATA_TYPE_CATALOG
    -- What it does: Lists the data field types declared for one statistic type, with code and data-type category.
    sdt.id AS statistic_data_type_id,
    sdt.name AS statistic_data_type_name,
    sdt.code AS statistic_data_type_code,
    sdt.statistic_data_type_categoryFK AS statistic_data_type_category_id,
    sdtc.name AS statistic_data_type_category_name
FROM statistic_data_type sdt
LEFT JOIN statistic_data_type_category sdtc
  ON sdtc.id = sdt.statistic_data_type_categoryFK
WHERE sdt.statistic_typeFK = {{STATISTIC_TYPE_ID}}  -- select statistic_type_id from GLOBAL-DISCOVERY-015 (STATISTIC_TYPES_AND_OWNERS)
ORDER BY
    sdt.statistic_data_type_categoryFK,
    sdt.id
LIMIT 1000;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DISCOVERY-031
    -- Name - STATISTIC_DATA_TYPE_DECLARED_VS_USED
    -- What it does: Compares the data field types declared for one statistic type against their use in one confirmed owner level and physical shard, keeping declared but unused field types.
    sdt.id AS statistic_data_type_id,
    sdt.name AS statistic_data_type_name,
    sdt.code AS statistic_data_type_code,
    sdt.statistic_data_type_categoryFK AS statistic_data_type_category_id,
    COALESCE(used.statistic_count, 0) AS statistic_count,
    COALESCE(used.statistic_participant_count, 0) AS statistic_participant_count,
    COALESCE(used.value_row_count, 0) AS value_row_count,
    used.sample_value AS sample_value
FROM statistic_data_type sdt
-- {{SHARD_ID}}: confirmed physical shard number from GLOBAL-DISCOVERY-016 (STATISTIC_PARTICIPANT_SHARD_USAGE)
-- Two things keep this statement inside its budget, and both matter. The sport scope is
-- resolved over `statistic` first, so the owner-path joins run once per statistic rather
-- than once per value row. And the usage side is aggregated here, so the outer join meets
-- one row per data type instead of every value row in the shard.
LEFT JOIN (
    SELECT
        sd.statistic_data_typeFK AS statistic_data_type_id,
        COUNT(DISTINCT sp.statisticFK) AS statistic_count,
        COUNT(DISTINCT sp.id) AS statistic_participant_count,
        COUNT(sd.id) AS value_row_count,
        MIN(sd.value) AS sample_value
    FROM (
        SELECT DISTINCT st.id AS statistic_id
        FROM statistic st
        LEFT JOIN sport sport_owner
          ON st.object_typeFK = 1
         AND sport_owner.id = st.objectFK
         AND sport_owner.del = 'no'
        LEFT JOIN tournament_template tt2
          ON st.object_typeFK = 2
         AND tt2.id = st.objectFK
         AND tt2.del = 'no'
        LEFT JOIN tournament t3
          ON st.object_typeFK = 3
         AND t3.id = st.objectFK
         AND t3.del = 'no'
        LEFT JOIN tournament_template tt3
          ON tt3.id = t3.tournament_templateFK
         AND tt3.del = 'no'
        LEFT JOIN tournament_stage ts4
          ON st.object_typeFK = 4
         AND ts4.id = st.objectFK
         AND ts4.del = 'no'
        LEFT JOIN tournament t4
          ON t4.id = ts4.tournamentFK
         AND t4.del = 'no'
        LEFT JOIN tournament_template tt4
          ON tt4.id = t4.tournament_templateFK
         AND tt4.del = 'no'
        LEFT JOIN event e5
          ON st.object_typeFK = 5
         AND e5.id = st.objectFK
         AND e5.del = 'no'
        LEFT JOIN tournament_stage ts5
          ON ts5.id = e5.tournament_stageFK
         AND ts5.del = 'no'
        LEFT JOIN tournament t5
          ON t5.id = ts5.tournamentFK
         AND t5.del = 'no'
        LEFT JOIN tournament_template tt5
          ON tt5.id = t5.tournament_templateFK
         AND tt5.del = 'no'
        LEFT JOIN event_participants ep6
          ON st.object_typeFK = 6
         AND ep6.id = st.objectFK
         AND ep6.del = 'no'
        LEFT JOIN event e6
          ON e6.id = ep6.eventFK
         AND e6.del = 'no'
        LEFT JOIN tournament_stage ts6
          ON ts6.id = e6.tournament_stageFK
         AND ts6.del = 'no'
        LEFT JOIN tournament t6
          ON t6.id = ts6.tournamentFK
         AND t6.del = 'no'
        LEFT JOIN tournament_template tt6
          ON tt6.id = t6.tournament_templateFK
         AND tt6.del = 'no'
        LEFT JOIN participant p15
          ON st.object_typeFK = 15
         AND p15.id = st.objectFK
         AND p15.del = 'no'
        LEFT JOIN object_participants op15
          ON op15.object = 'sport'
         AND op15.participantFK = p15.id
         AND op15.del = 'no'
        WHERE st.del = 'no'
          AND st.statistic_typeFK = {{STATISTIC_TYPE_ID}}  -- select statistic_type_id from GLOBAL-DISCOVERY-015 (STATISTIC_TYPES_AND_OWNERS)
          AND st.object_typeFK = {{STATISTIC_OWNER_TYPE_ID}}  -- select statistic_owner_type_id from GLOBAL-DISCOVERY-015 (STATISTIC_TYPES_AND_OWNERS)
          AND (
              sport_owner.id = {{SPORT_ID}}
              OR tt2.sportFK = {{SPORT_ID}}
              OR tt3.sportFK = {{SPORT_ID}}
              OR tt4.sportFK = {{SPORT_ID}}
              OR tt5.sportFK = {{SPORT_ID}}
              OR tt6.sportFK = {{SPORT_ID}}
              OR op15.objectFK = {{SPORT_ID}}
          )
    ) scoped
    JOIN statistic_participants{{SHARD_ID}} sp
      ON sp.statisticFK = scoped.statistic_id
     AND sp.del = 'no'
    JOIN statistic_data{{SHARD_ID}} sd
      ON sd.statistic_participants{{SHARD_ID}}FK = sp.id
     AND sd.del = 'no'
    GROUP BY sd.statistic_data_typeFK
) used
  ON used.statistic_data_type_id = sdt.id
WHERE sdt.statistic_typeFK = {{STATISTIC_TYPE_ID}}  -- same statistic_type_id as the inner filter
ORDER BY
    value_row_count DESC,
    sdt.id
LIMIT 1000;
