SELECT
    -- CheckID - GLOBAL-DISCOVERY-011
    -- Name - PROPERTY_USAGE_BY_OWNER
    -- What it does: Lists active property types and names used by known hierarchy and participant owners in the selected sport.
    x.owner_object,
    x.property_type,
    x.property_name,
    COUNT(DISTINCT x.property_id) AS property_row_count,
    COUNT(DISTINCT x.owner_id) AS owner_count,
    MIN(x.property_value) AS sample_value
FROM (
    SELECT
        'event' AS owner_object,
        pr.id AS property_id,
        pr.objectFK AS owner_id,
        pr.type AS property_type,
        pr.name AS property_name,
        pr.value AS property_value
    FROM property pr
    JOIN event e
      ON pr.object = 'event'
     AND e.id = pr.objectFK
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
    WHERE pr.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      -- AND tt.id = <tournament_template_id>

    UNION ALL

    SELECT
        'tournament_stage',
        pr.id,
        pr.objectFK,
        pr.type,
        pr.name,
        pr.value
    FROM property pr
    JOIN tournament_stage ts
      ON pr.object = 'tournament_stage'
     AND ts.id = pr.objectFK
     AND ts.del = 'no'
    JOIN tournament t
      ON t.id = ts.tournamentFK
     AND t.del = 'no'
    JOIN tournament_template tt
      ON tt.id = t.tournament_templateFK
     AND tt.del = 'no'
    WHERE pr.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      -- AND tt.id = <tournament_template_id>

    UNION ALL

    SELECT
        'tournament',
        pr.id,
        pr.objectFK,
        pr.type,
        pr.name,
        pr.value
    FROM property pr
    JOIN tournament t
      ON pr.object = 'tournament'
     AND t.id = pr.objectFK
     AND t.del = 'no'
    JOIN tournament_template tt
      ON tt.id = t.tournament_templateFK
     AND tt.del = 'no'
    WHERE pr.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      -- AND tt.id = <tournament_template_id>

    UNION ALL

    SELECT DISTINCT
        'participant',
        pr.id,
        pr.objectFK,
        pr.type,
        pr.name,
        pr.value
    FROM property pr
    JOIN participant p
      ON pr.object = 'participant'
     AND p.id = pr.objectFK
     AND p.del = 'no'
    JOIN event_participants ep
      ON ep.participantFK = p.id
     AND ep.del = 'no'
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
    WHERE pr.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      -- AND tt.id = <tournament_template_id>
) AS x
GROUP BY
    x.owner_object,
    x.property_type,
    x.property_name
ORDER BY
    x.owner_object,
    x.property_type,
    x.property_name;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DISCOVERY-012
    -- Name - OBJECT_RELATION_USAGE
    -- What it does: Lists active source and target object-type combinations used by known hierarchy and tournament-owned statistic paths in the selected sport.
    x.object_type_id,
    x.related_object_type_id,
    COUNT(DISTINCT x.relation_id) AS relation_row_count,
    COUNT(DISTINCT x.object_id) AS source_object_count,
    COUNT(DISTINCT x.related_object_id) AS related_object_count,
    MIN(x.object_id) AS sample_source_object_id,
    MIN(x.related_object_id) AS sample_related_object_id
FROM (
    SELECT
        orl.id AS relation_id,
        orl.object_typeFK AS object_type_id,
        orl.objectFK AS object_id,
        orl.rel_object_typeFK AS related_object_type_id,
        orl.rel_objectFK AS related_object_id
    FROM object_relation orl
    WHERE orl.object_typeFK = 1
      AND orl.objectFK = {{SPORT_ID}}
      AND orl.del = 'no'

    UNION ALL

    SELECT orl.id, orl.object_typeFK, orl.objectFK, orl.rel_object_typeFK, orl.rel_objectFK
    FROM object_relation orl
    JOIN tournament_template tt
      ON orl.object_typeFK = 2
     AND tt.id = orl.objectFK
     AND tt.del = 'no'
    WHERE orl.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      -- AND tt.id = <tournament_template_id>

    UNION ALL

    SELECT orl.id, orl.object_typeFK, orl.objectFK, orl.rel_object_typeFK, orl.rel_objectFK
    FROM object_relation orl
    JOIN tournament t
      ON orl.object_typeFK = 3
     AND t.id = orl.objectFK
     AND t.del = 'no'
    JOIN tournament_template tt
      ON tt.id = t.tournament_templateFK
     AND tt.del = 'no'
    WHERE orl.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      -- AND tt.id = <tournament_template_id>

    UNION ALL

    SELECT orl.id, orl.object_typeFK, orl.objectFK, orl.rel_object_typeFK, orl.rel_objectFK
    FROM object_relation orl
    JOIN tournament_stage ts
      ON orl.object_typeFK = 4
     AND ts.id = orl.objectFK
     AND ts.del = 'no'
    JOIN tournament t
      ON t.id = ts.tournamentFK
     AND t.del = 'no'
    JOIN tournament_template tt
      ON tt.id = t.tournament_templateFK
     AND tt.del = 'no'
    WHERE orl.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      -- AND tt.id = <tournament_template_id>

    UNION ALL

    SELECT orl.id, orl.object_typeFK, orl.objectFK, orl.rel_object_typeFK, orl.rel_objectFK
    FROM object_relation orl
    JOIN event e
      ON orl.object_typeFK = 5
     AND e.id = orl.objectFK
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
    WHERE orl.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      -- AND tt.id = <tournament_template_id>

    UNION ALL

    SELECT orl.id, orl.object_typeFK, orl.objectFK, orl.rel_object_typeFK, orl.rel_objectFK
    FROM object_relation orl
    JOIN statistic st
      ON orl.object_typeFK = 83
     AND st.id = orl.objectFK
     AND st.object_typeFK = 3
     AND st.del = 'no'
    JOIN tournament t
      ON t.id = st.objectFK
     AND t.del = 'no'
    JOIN tournament_template tt
      ON tt.id = t.tournament_templateFK
     AND tt.del = 'no'
    WHERE orl.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      -- AND tt.id = <tournament_template_id>
) AS x
GROUP BY
    x.object_type_id,
    x.related_object_type_id
ORDER BY
    x.object_type_id,
    x.related_object_type_id;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DISCOVERY-013
    -- Name - OBJECT_DISCIPLINE_USAGE
    -- What it does: Lists disciplines attached to active events and tournament-owned statistics in the selected sport.
    x.owner_object,
    x.owner_type_id,
    x.discipline_id,
    x.discipline_name,
    COUNT(*) AS relation_row_count,
    COUNT(DISTINCT x.owner_id) AS owner_count
FROM (
    SELECT
        'event' AS owner_object,
        od.object_typeFK AS owner_type_id,
        od.objectFK AS owner_id,
        od.disciplineFK AS discipline_id,
        d.name AS discipline_name
    FROM object_discipline od
    JOIN event e
      ON od.object_typeFK = 5
     AND e.id = od.objectFK
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
    LEFT JOIN discipline d
      ON d.id = od.disciplineFK
     AND d.del = 'no'
    WHERE od.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      -- AND tt.id = <tournament_template_id>

    UNION ALL

    SELECT
        'statistic',
        od.object_typeFK,
        od.objectFK,
        od.disciplineFK,
        d.name
    FROM object_discipline od
    JOIN statistic st
      ON od.object_typeFK = 83
     AND st.id = od.objectFK
     AND st.object_typeFK = 3
     AND st.del = 'no'
    JOIN tournament t
      ON t.id = st.objectFK
     AND t.del = 'no'
    JOIN tournament_template tt
      ON tt.id = t.tournament_templateFK
     AND tt.del = 'no'
    LEFT JOIN discipline d
      ON d.id = od.disciplineFK
     AND d.del = 'no'
    WHERE od.del = 'no'
      AND tt.sportFK = {{SPORT_ID}}
      -- AND tt.id = <tournament_template_id>
) AS x
GROUP BY
    x.owner_object,
    x.owner_type_id,
    x.discipline_id,
    x.discipline_name
ORDER BY
    x.owner_object,
    x.discipline_id;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DISCOVERY-014
    -- Name - TOURNAMENT_STAGE_REFERENCE_STORAGE
    -- What it does: Shows direct country, host-country relation, city link and age-class relation storage for active stages in the selected sport.
    ts.id AS tournament_stage_id,
    ts.name AS tournament_stage_name,
    ts.gender AS stage_gender,
    ts.countryFK AS direct_country_id,
    direct_country.name AS direct_country_name,
    (
        SELECT GROUP_CONCAT(DISTINCT hc.rel_objectFK ORDER BY hc.rel_objectFK)
        FROM object_relation hc
        WHERE hc.object_typeFK = 4
          AND hc.objectFK = ts.id
          AND hc.rel_object_typeFK = 33
          AND hc.del = 'no'
    ) AS host_country_ids,
    (
        SELECT GROUP_CONCAT(DISTINCT c.name ORDER BY c.name SEPARATOR ' | ')
        FROM object_relation hc
        JOIN country c
          ON c.id = hc.rel_objectFK
         AND c.del = 'no'
        WHERE hc.object_typeFK = 4
          AND hc.objectFK = ts.id
          AND hc.rel_object_typeFK = 33
          AND hc.del = 'no'
    ) AS host_country_names,
    (
        SELECT GROUP_CONCAT(DISTINCT co.cityFK ORDER BY co.cityFK)
        FROM city_object co
        WHERE co.object_typeFK = 4
          AND co.objectFK = ts.id
          AND co.del = 'no'
    ) AS city_ids,
    (
        SELECT GROUP_CONCAT(DISTINCT ci.name ORDER BY ci.name SEPARATOR ' | ')
        FROM city_object co
        JOIN city ci
          ON ci.id = co.cityFK
         AND ci.del = 'no'
        WHERE co.object_typeFK = 4
          AND co.objectFK = ts.id
          AND co.del = 'no'
    ) AS city_names,
    (
        SELECT GROUP_CONCAT(DISTINCT ac.rel_objectFK ORDER BY ac.rel_objectFK)
        FROM object_relation ac
        WHERE ac.object_typeFK = 4
          AND ac.objectFK = ts.id
          AND ac.rel_object_typeFK = 151
          AND ac.del = 'no'
    ) AS age_class_ids,
    (
        SELECT GROUP_CONCAT(DISTINCT tac.name ORDER BY tac.name SEPARATOR ' | ')
        FROM object_relation ac
        JOIN tournament_age_class tac
          ON tac.id = ac.rel_objectFK
         AND tac.del = 'no'
        WHERE ac.object_typeFK = 4
          AND ac.objectFK = ts.id
          AND ac.rel_object_typeFK = 151
          AND ac.del = 'no'
    ) AS age_class_names
FROM tournament_stage ts
JOIN tournament t
  ON t.id = ts.tournamentFK
 AND t.del = 'no'
JOIN tournament_template tt
  ON tt.id = t.tournament_templateFK
 AND tt.del = 'no'
LEFT JOIN country direct_country
  ON direct_country.id = ts.countryFK
 AND direct_country.del = 'no'
WHERE ts.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
ORDER BY
    tt.name,
    t.name,
    ts.name,
    ts.id;


-- ================================================================================
SELECT
    -- CheckID - GLOBAL-DISCOVERY-032
    -- Name - EVENT_DISCIPLINE_GENDER_PARTICIPANT_MATRIX
    -- What it does: Lists every combination of discipline, stage gender and event-participant type the selected sport has ever contested, with the number of events, the number of distinct templates carrying it and the first and last year it was seen, so a combination the sport does not contest is read off the matrix rather than asserted by a rule.
    d.name AS discipline_name,
    od.disciplineFK AS discipline_id,
    COALESCE(ts.gender, 'null') AS stage_gender,
    p.type AS participant_type,
    COUNT(DISTINCT e.id) AS event_count,
    COUNT(DISTINCT tt.id) AS template_count,
    MIN(YEAR(e.startdate)) AS first_year,
    MAX(YEAR(e.startdate)) AS last_year
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = {{SPORT_ID}}
  -- AND tt.id = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
GROUP BY d.name, od.disciplineFK, ts.gender, p.type
ORDER BY event_count;
