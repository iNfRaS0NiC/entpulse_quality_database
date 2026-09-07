-- ==============================================================================
-- Para-Swimming sport-specific DQ statements
--
-- These exist because Swimming, the same competition without the classification, authored them
-- for itself and Para-Swimming inherited none of them. Opening this sport on 2026-09-07 built
-- its candidate list from the GLOBAL catalogue alone and never looked at what the sibling sport
-- had written, which is a third variant of a failure already recorded twice in this package:
-- a list built from one source silently loses whatever only the other source holds.
--
-- Promotion to GLOBAL templates was offered and the user chose copies on 2026-09-07. The cost
-- is stated so nobody has to rediscover it: two copies of one logic will drift, and the next
-- Para aquatic sport opened will need a third.
--
-- Six of Swimming's thirteen own statements are NOT here, each for a structural reason
-- recorded in SPORTS/Para-Swimming.md: `-046` duplicates `Para-Swimming-DQ-057` exactly,
-- `-069` and `-083` read the `557 Full-time duration` result type this sport does not carry,
-- `-070` reads Swimming's short-course discipline ids under a `Long Course` template this sport
-- does not have, `-086` became `GLOBAL-DQ-161`, and `-087` reads a `?` provisional marker
-- absent from this sport's 44-value comment vocabulary.
--
-- Every value carried over from Swimming was re-derived against this sport's own data before
-- being written here, and each statement says which values those were.
-- ==============================================================================
SELECT
    -- CheckID - Para-Swimming-DQ-083
    -- Name - EVENT_NAME_STROKE_CONTRADICTS_DISCIPLINE
    -- What it does: Finds events whose name spells one stroke while the discipline attached to them names another.
    'EVENT_NAME_NAMES_A_DIFFERENT_STROKE' AS check_type,
    x.event_id,
    x.event_name,
    x.stroke_in_event_name,
    x.discipline_id,
    x.discipline_name,
    x.template_name,
    x.startdate,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: The stroke is named twice for the same event - once in the
-- event's own name and once in the discipline the event is attached to - and the two are one
-- fact written in two places. Where they disagree one is wrong and nothing says which, so both
-- are projected and the repair is a reading rather than a rewrite.
--
-- Copied from `Swimming-DQ-063` on 2026-09-07, the sports being the same competition with the
-- same five stroke words, and adapted only in the sport and the client boundary.
--
-- **The two sports disagree in shape, not only in size.** Swimming holds 64 of these and 42 of
-- them are one confusable pair, a Backstroke discipline under an event named Breaststroke.
-- Para-Swimming holds 29 over 14 pairs with none dominant, and in many of them the distance
-- disagrees as well as the stroke - `Butterfly 100m S11 Heat 1` against `Freestyle 4 x 50m` -
-- so the discipline reference is plain wrong rather than a word that drifted. A reader who
-- assumes the discipline is right will be wrong more often here than in Swimming.
--
-- This is not `GLOBAL-DQ-109`, which compares the discipline property against the
-- `object_discipline` relation - the same id stored twice - and passes an event whose name
-- contradicts both consistently. This one never reads the id twice; it reads the name.
--
-- Only the five stroke words the sport spells are compared, and an event or discipline naming
-- none of them is left out of both branches rather than reported as a mismatch against
-- nothing. Two contradictions this sport does hold are therefore silent here by construction
-- and are recorded in `SPORTS/Para-Swimming.md` instead: `Freestyle 100m Fly S7` names two
-- strokes but `Fly` is not `Butterfly`, and `Backstroke 50m SB3` contradicts its class prefix
-- rather than its discipline.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        tt.name AS template_name,
        e.startdate,
        od.disciplineFK AS discipline_id,
        d.name AS discipline_name,
        CASE
            WHEN d.name LIKE 'Medley%'       THEN 'Medley'
            WHEN d.name LIKE 'Freestyle%'    THEN 'Freestyle'
            WHEN d.name LIKE 'Backstroke%'   THEN 'Backstroke'
            WHEN d.name LIKE 'Breaststroke%' THEN 'Breaststroke'
            WHEN d.name LIKE 'Butterfly%'    THEN 'Butterfly'
        END AS stroke_in_discipline,
        CASE
            WHEN e.name LIKE '%Medley%'       THEN 'Medley'
            WHEN e.name LIKE '%Freestyle%'    THEN 'Freestyle'
            WHEN e.name LIKE '%Backstroke%'   THEN 'Backstroke'
            WHEN e.name LIKE '%Breaststroke%' THEN 'Breaststroke'
            WHEN e.name LIKE '%Butterfly%'    THEN 'Butterfly'
        END AS stroke_in_event_name
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = 135
    JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
    JOIN discipline d ON d.id = od.disciplineFK
    WHERE e.del = 'no'
      AND t.tournament_templateFK NOT IN (0)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
) x
WHERE x.stroke_in_discipline IS NOT NULL
  AND x.stroke_in_event_name IS NOT NULL
  AND x.stroke_in_discipline <> x.stroke_in_event_name

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT y.event_id) AS eligible_count,
    1 AS sort_order
FROM (
    SELECT e.id AS event_id
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = 135
    JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
    JOIN discipline d ON d.id = od.disciplineFK
    WHERE e.del = 'no'
      AND t.tournament_templateFK NOT IN (0)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
      AND (d.name LIKE 'Medley%' OR d.name LIKE 'Freestyle%' OR d.name LIKE 'Backstroke%'
           OR d.name LIKE 'Breaststroke%' OR d.name LIKE 'Butterfly%')
      AND (e.name LIKE '%Medley%' OR e.name LIKE '%Freestyle%' OR e.name LIKE '%Backstroke%'
           OR e.name LIKE '%Breaststroke%' OR e.name LIKE '%Butterfly%')
) y

ORDER BY sort_order, event_id;

-- ==============================================================================
SELECT
    -- CheckID - Para-Swimming-DQ-084
    -- Name - PARTICIPANT_AGE_AT_EVENT_IMPLAUSIBLE
    -- What it does: Finds athletes whose stored date of birth makes them younger than eight, or older than seventy, at an event they actually swam.
    CASE
        WHEN x.age_at_first_event < 0 THEN 'BORN_AFTER_THEIR_OWN_EVENT'
        WHEN x.age_at_first_event < 8 THEN 'TOO_YOUNG_AT_FIRST_EVENT'
        ELSE 'TOO_OLD_AT_LAST_EVENT'
    END AS check_type,
    x.participant_id,
    x.participant_name,
    x.participant_country,
    x.date_of_birth,
    x.first_event_date,
    x.last_event_date,
    x.age_at_first_event,
    x.age_at_last_event,
    x.swims,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Reads each competitor's stored date of birth against the start
-- date of an event they actually swam, and reports an age no swimmer has at a competition.
--
-- Copied from `Swimming-DQ-064` on 2026-09-07. The bounds are the same because they are about
-- people rather than about a sport. **Two sport ids had to be changed and not one**: this
-- statement scopes through `object_participants.objectFK` as well as `tournament_template
-- .sportFK`, and correcting only the second left it reading Swimming's registry while
-- reporting under this sport's name.
--
-- 19 findings of 618 eligible, measured 2026-09-07, and they are two different repairs:
-- 17 `TOO_YOUNG_AT_FIRST_EVENT` and 2 `BORN_AFTER_THEIR_OWN_EVENT`. The second pair is the
-- one to read first - a date of birth later than the event the person swam cannot be a
-- borderline case or a young prodigy, it is a wrong date.
--
-- **The eligible count is 618 and not 3060 because that is how many people carry a date of
-- birth at all.** What this check cannot see is the 2442 who carry none, which is
-- `Para-Swimming-DQ-001` and `GLOBAL-DQ-007`'s question, and the two should be read together
-- rather than this one being read as the sport's whole date-of-birth position.
FROM (
    SELECT
        p.id AS participant_id,
        p.name AS participant_name,
        (SELECT c.name FROM country c WHERE c.id = p.countryFK AND c.del = 'no') AS participant_country,
        MIN(pr.value) AS date_of_birth,
        MIN(e.startdate) AS first_event_date,
        MAX(e.startdate) AS last_event_date,
        TIMESTAMPDIFF(YEAR, MIN(pr.value), MIN(e.startdate)) AS age_at_first_event,
        TIMESTAMPDIFF(YEAR, MIN(pr.value), MAX(e.startdate)) AS age_at_last_event,
        COUNT(DISTINCT e.id) AS swims
    FROM object_participants op
    JOIN participant p ON p.id = op.participantFK AND p.del = 'no'
         AND p.type IN ('athlete')
    JOIN property pr ON pr.object = 'participant' AND pr.objectFK = p.id
         AND pr.name = 'date_of_birth' AND pr.del = 'no'
         AND pr.value REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}'
    JOIN event_participants ep ON ep.participantFK = p.id AND ep.del = 'no'
    JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = 135
    WHERE op.object = 'sport' AND op.objectFK = 135 AND op.del = 'no'
  -- AND p.id BETWEEN <from_participant_id> AND <to_participant_id>
      AND t.tournament_templateFK NOT IN (0)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY p.id, p.name, p.countryFK
) x
WHERE x.age_at_first_event < 8
   OR x.age_at_last_event > 70

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT p.id) AS eligible_count,
    1 AS sort_order
FROM object_participants op
JOIN participant p ON p.id = op.participantFK AND p.del = 'no'
     AND p.type IN ('athlete')
JOIN property pr ON pr.object = 'participant' AND pr.objectFK = p.id
     AND pr.name = 'date_of_birth' AND pr.del = 'no'
     AND pr.value REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}'
JOIN event_participants ep ON ep.participantFK = p.id AND ep.del = 'no'
JOIN event e ON e.id = ep.eventFK AND e.del = 'no'
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 135
WHERE op.object = 'sport' AND op.objectFK = 135 AND op.del = 'no'
  -- AND p.id BETWEEN <from_participant_id> AND <to_participant_id>
  AND t.tournament_templateFK NOT IN (0)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, participant_id;

-- ==============================================================================
SELECT
    -- CheckID - Para-Swimming-DQ-085
    -- Name - PARTICIPANT_REGISTRY_ACTIVE_CONTRADICTS_STATUS
    -- What it does: Finds athletes whose registry active flag and status property say opposite things about whether they still compete.
    CASE
        WHEN x.status_value = 'dead' THEN 'ACTIVE_IN_REGISTRY_BUT_DEAD'
        WHEN x.status_value = 'retired' THEN 'ACTIVE_IN_REGISTRY_BUT_RETIRED'
        ELSE 'INACTIVE_IN_REGISTRY_BUT_ACTIVE'
    END AS check_type,
    x.participant_id,
    x.participant_name,
    x.participant_country,
    x.registry_active,
    x.status_value,
    x.event_participations,
    x.last_event_date,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: The sport registry carries an active flag and the person
-- carries a `status` property, and both answer whether the competitor still competes. This
-- reports the people whose two answers are opposite.
--
-- Copied from `Swimming-DQ-065` on 2026-09-07. **Two sport ids had to be changed and not
-- one**: this statement scopes through `object_participants.objectFK` as well as
-- `tournament_template.sportFK`, and correcting only the second left it reading Swimming's
-- registry - 36076 eligible - while reporting under this sport's name.
--
-- **0 findings of 3060 eligible**, measured 2026-09-07, and that is a clean result over a real
-- population rather than an empty scope. It reads clean for a reason worth stating: every
-- registry row in this sport carries `active = yes`, so the registry contradicts nobody, and
-- the `status` property is the only one of the two fields carrying a retirement at all.
--
-- The check is kept rather than dropped for exactly that reason. A registry that starts being
-- maintained, or a status that starts being written against an inactive row, shows up here
-- first - and a check that guards an invariant is not disposable because the invariant holds
-- today.
--
-- The commented filter is the participant primary-key range, which `POWERBI.md` requires of a
-- standalone audited object. `Swimming-DQ-065` carries none; that is its gap and not a
-- convention to copy.
FROM (
    SELECT
        p.id AS participant_id,
        p.name AS participant_name,
        (SELECT c.name FROM country c WHERE c.id = p.countryFK AND c.del = 'no') AS participant_country,
        op.active AS registry_active,
        st.value AS status_value,
        (SELECT COUNT(*) FROM event_participants ep2 WHERE ep2.participantFK = p.id AND ep2.del = 'no') AS event_participations,
        (
            SELECT MAX(e2.startdate)
            FROM event_participants ep3
            JOIN event e2 ON e2.id = ep3.eventFK AND e2.del = 'no'
            WHERE ep3.participantFK = p.id AND ep3.del = 'no'
        ) AS last_event_date
    FROM object_participants op
    JOIN participant p ON p.id = op.participantFK AND p.del = 'no'
         AND p.type IN ('athlete', 'team')
    JOIN property st ON st.object = 'participant' AND st.objectFK = p.id
         AND st.name = 'status' AND st.del = 'no'
         AND TRIM(st.value) <> ''
    WHERE op.object = 'sport' AND op.objectFK = 135 AND op.del = 'no'
  -- AND p.id BETWEEN <from_participant_id> AND <to_participant_id>
) x
WHERE (x.registry_active = 'yes' AND x.status_value IN ('retired', 'dead'))
   OR (x.registry_active = 'no'  AND x.status_value = 'active')

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT p.id) AS eligible_count,
    1 AS sort_order
FROM object_participants op
JOIN participant p ON p.id = op.participantFK AND p.del = 'no'
     AND p.type IN ('athlete', 'team')
JOIN property st ON st.object = 'participant' AND st.objectFK = p.id
     AND st.name = 'status' AND st.del = 'no'
     AND TRIM(st.value) <> ''
WHERE op.object = 'sport' AND op.objectFK = 135 AND op.del = 'no'
  -- AND p.id BETWEEN <from_participant_id> AND <to_participant_id>

ORDER BY sort_order, participant_id;

-- ==============================================================================
SELECT
    -- CheckID - Para-Swimming-DQ-086
    -- Name - EVENT_NAME_CONVENTION_CONTRADICTS_DISCIPLINE_VOCABULARY
    -- What it does: Finds events where the distance-first or distance-last naming habit does not match the discipline vocabulary that habit travels with.
    CASE
        WHEN x.discipline_vocabulary = 'older'
            THEN 'OLDER_DISCIPLINE_WITH_DISTANCE_LAST_NAME'
        ELSE 'CURRENT_DISCIPLINE_WITH_DISTANCE_FIRST_NAME'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.discipline_id,
    x.discipline_name,
    x.discipline_vocabulary,
    x.template_name,
    x.startdate,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: The sport names a relay two ways round - the distance first
-- or the distance last - and the discipline vocabulary an event is attached to travels with
-- one habit or the other. This reports the events where the name's habit and the vocabulary
-- disagree.
--
-- Copied from `Swimming-DQ-066` on 2026-09-07. **The relay discipline ids are not Swimming's
-- and were derived from this sport's own event links**: 12 ids carry a relay name here, eight
-- of them belonging to Para-Swimming - `482`, `457`, `485`, `484`, `487`, `458`, `463`, `462` -
-- and four belonging to Swimming, `367`, `365`, `368` and `370`. The foreign four are included
-- deliberately: this check asks about the naming habit and not about whether the discipline
-- reference is right, and the events carrying them are relays whatever catalogue they point
-- at. That they point at another sport's catalogue at all is
-- `Para-Swimming-DQ-022`'s finding, and counting it here as well would report one defect
-- twice.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate,
        tt.name AS template_name,
        od.disciplineFK AS discipline_id,
        d.name AS discipline_name,
        CASE WHEN od.disciplineFK IN (56, 57, 58) THEN 'older' ELSE 'current' END AS discipline_vocabulary,
        CASE WHEN e.name REGEXP '^[0-9]' THEN 'distance-first' ELSE 'distance-last' END AS naming_convention
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = 135
    JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
         AND od.disciplineFK IN (482, 457, 485, 484, 487, 458, 463, 462, 367, 365, 368, 370)
    JOIN discipline d ON d.id = od.disciplineFK
    WHERE e.del = 'no'
      AND t.tournament_templateFK NOT IN (0)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
) x
WHERE (x.discipline_vocabulary = 'older'   AND x.naming_convention = 'distance-last')
   OR (x.discipline_vocabulary = 'current' AND x.naming_convention = 'distance-first')

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
     AND tt.sportFK = 135
JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
     AND od.disciplineFK IN (482, 457, 485, 484, 487, 458, 463, 462, 367, 365, 368, 370)
WHERE e.del = 'no'
  AND t.tournament_templateFK NOT IN (0)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_id;

-- ==============================================================================
SELECT
    -- CheckID - Para-Swimming-DQ-087
    -- Name - EVENT_NAME_CONTRADICTS_DISCIPLINE_DISTANCE_OR_ROUND_TYPE
    -- What it does: Finds events whose own name says a distance or a round that the setting attached to the event denies.
    x.check_type,
    x.event_id,
    x.event_name,
    x.name_says,
    x.setting_says,
    x.corroborating_time,
    x.template_name,
    x.startdate,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: An event's own name states a distance and often a round, and
-- the discipline and round type attached to it state the same two things. This reports the
-- events where the name and the setting disagree.
--
-- Copied from `Swimming-DQ-072` on 2026-09-07. **The bare-number round list is `38` alone and
-- was derived rather than carried over.** Swimming leaves a round unstated on five round types,
-- `38`, `89`, `91`, `98` and `99`; this sport uses five round types in total and only `38` is a
-- bare number, its name being the single character `1`. Carrying Swimming's five over would
-- have named four ids this sport never uses, which reads as a wider scope than the statement
-- has.
FROM (
    SELECT
        'NAME_DISTANCE_CONTRADICTS_DISCIPLINE' AS check_type,
        y.event_id,
        y.event_name,
        CONCAT(y.name_distance, ' m from the event name') AS name_says,
        CONCAT(y.discipline_id, ' ', y.discipline_name) AS setting_says,
        y.corroborating_time,
        y.template_name,
        y.startdate
    FROM (
        SELECT
            e.id AS event_id,
            e.name AS event_name,
            e.startdate,
            tt.name AS template_name,
            d.id AS discipline_id,
            d.name AS discipline_name,
            CAST(REGEXP_SUBSTR(e.name, '[0-9]+') AS UNSIGNED) AS name_distance,
            CAST(REGEXP_SUBSTR(d.name, '[0-9]+', 1, 1) AS UNSIGNED) AS discipline_distance,
            (SELECT MIN(r.value) FROM event_participants ep2
             JOIN result r ON r.event_participantsFK = ep2.id AND r.result_typeFK = 557 AND r.del = 'no'
             WHERE ep2.eventFK = e.id AND ep2.del = 'no') AS corroborating_time
        FROM event e
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
             AND tt.sportFK = 135
        JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
        JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
             AND d.name REGEXP '[0-9]'
             AND d.name NOT LIKE '%km%'
             AND d.name NOT LIKE '% x %'
        WHERE e.del = 'no'
          AND e.name REGEXP '[0-9]'
          AND e.name NOT LIKE '%x%'
          AND t.tournament_templateFK NOT IN (0)
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
          -- AND t.tournament_templateFK = <tournament_template_id>
          -- AND e.startdate >= '<from_datetime>'
          -- AND e.startdate <  '<to_datetime>'
    ) y
    WHERE y.name_distance > 0
      AND y.discipline_distance > 0
      AND y.name_distance <> y.discipline_distance

    UNION ALL

    SELECT
        'NAME_ROUND_CONTRADICTS_ROUND_TYPE' AS check_type,
        e.id AS event_id,
        e.name AS event_name,
        CASE
            WHEN e.name LIKE '%Heats Summary%'  THEN 'Heats Summary from the event name'
            WHEN e.name LIKE '%Finals Summary%' THEN 'Finals Summary from the event name'
            WHEN e.name LIKE '%Semi Final%'     THEN 'Semi Finals from the event name'
            WHEN e.name LIKE '%Swim-Off%'       THEN 'Swim-Off from the event name'
            ELSE 'Heats from the event name'
        END AS name_says,
        CONCAT(e.round_typeFK, ' ', rt.name) AS setting_says,
        NULL AS corroborating_time,
        tt.name AS template_name,
        e.startdate
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = 135
    JOIN round_type rt ON rt.id = e.round_typeFK
    WHERE e.del = 'no'
      AND e.round_typeFK NOT IN (38)
      AND t.tournament_templateFK NOT IN (0)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
      AND (
            e.name LIKE '%Heats Summary%'
         OR e.name LIKE '%Finals Summary%'
         OR e.name LIKE '%Semi Final%'
         OR e.name LIKE '%Swim-Off%'
         OR e.name LIKE '%Heats%'
          )
      -- A name is only contradicted when NOT ONE of the round words it carries matches the type.
      -- An event named Breaststroke 50m Swim-Off Semi Final carries two of them and is correct:
      -- it is the swim-off that decides a place in the semi-final, and its round type says
      -- Swim-Off. Tested word by word this reads as a Semi Finals event typed Swim-Off and is
      -- reported, which it was on 2026-08-21 before this was written the other way round.
      AND NOT (
            (e.name LIKE '%Heats Summary%'  AND rt.name = 'Heats Summary')
         OR (e.name LIKE '%Finals Summary%' AND rt.name = 'Finals Summary')
         OR (e.name LIKE '%Semi Final%'     AND rt.name = 'Semi Finals')
         OR (e.name LIKE '%Swim-Off%'       AND rt.name = 'Swim-Off')
         OR (e.name LIKE '%Heats%'          AND rt.name IN ('Heats', 'Fastest Heats',
                                                            'Slowest Heats', 'Heats Summary'))
          )
) x

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
     AND tt.sportFK = 135
LEFT JOIN round_type rt ON rt.id = e.round_typeFK
WHERE e.del = 'no'
  AND t.tournament_templateFK NOT IN (0)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND (
        (e.name REGEXP '[0-9]' AND e.name NOT LIKE '%x%'
         AND EXISTS (
             SELECT 1 FROM object_discipline od2
             JOIN discipline d2 ON d2.id = od2.disciplineFK AND d2.del = 'no'
                  AND d2.name REGEXP '[0-9]' AND d2.name NOT LIKE '%km%' AND d2.name NOT LIKE '% x %'
             WHERE od2.object_typeFK = 5 AND od2.objectFK = e.id AND od2.del = 'no'))
     OR (e.round_typeFK NOT IN (38)
         AND (e.name LIKE '%Heats%' OR e.name LIKE '%Summary%'
              OR e.name LIKE '%Semi Final%' OR e.name LIKE '%Swim-Off%'))
      )

ORDER BY sort_order, check_type, event_id;

-- ==============================================================================
SELECT
    -- CheckID - Para-Swimming-DQ-088
    -- Name - EVENT_ROUND_RECORDED_IN_NAME_NOT_IN_ROUND_TYPE
    -- What it does: Measures how many events state their round only in their own name, leaving the round type at one of the five bare numbers.
    'Round_Recorded_In_Name_Not_In_Round_Type' AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    CASE
        WHEN e.name REGEXP 'Heat [0-9]' THEN 'Heat n (singular)'
        WHEN e.name LIKE '%Heats Summary%'  THEN 'Heats Summary'
        WHEN e.name LIKE '%Heat Summary%'   THEN 'Heat Summary (singular)'
        WHEN e.name LIKE '%Heat summary%'   THEN 'Heat summary (lower case)'
        WHEN e.name LIKE '%Finals Summary%' THEN 'Finals Summary'
        WHEN e.name LIKE '%Fastest Heats%'  THEN 'Fastest Heats'
        WHEN e.name LIKE '%Slowest Heats%'  THEN 'Slowest Heats'
        WHEN e.name LIKE '%Slow Heats%'     THEN 'Slow Heats'
        WHEN e.name LIKE '%Semi Final%'     THEN 'Semi Finals'
        WHEN e.name LIKE '%Swim-Off%'       THEN 'Swim-Off'
        WHEN e.name LIKE '%Preliminary%'    THEN 'Preliminary'
        ELSE 'Heats'
    END AS name_says,
    CONCAT(e.round_typeFK, ' named "', rt.name, '"') AS round_type_says,
    tt.name AS template_name,
    t.name AS tournament_name,
    e.startdate,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Measures the events that state their round only in their own
-- name, leaving the round type at a bare number that says nothing.
--
-- Copied from `Swimming-DQ-073` on 2026-09-07, with two changes, and the second is the reason
-- this statement exists separately rather than being Swimming's run against another sport.
--
-- **The bare-number round list is `38` alone**, this sport's only such round type, named `1`.
--
-- **`Heat <n>` in the singular was added to the vocabulary, and without it the check reads
-- almost clean when it should read almost entirely.** Swimming writes `Heats`, `Heats Summary`
-- and `Fastest Heats`; this sport writes `Heat 1`, `Heat 2`, `Heat 3`. Run with Swimming's
-- vocabulary unchanged it returned 2 findings of 4411 - only the semi-finals and the swim-offs
-- matched - and with the singular form it returns 3572. A vocabulary carried between two sports
-- without being measured is how a check reports nothing and looks like clean data.
--
-- **81 per cent is the sport's habit and it is reported anyway, on the user's decision of
-- 2026-09-07.** Measured the same day: Swimming leaks the round into the name on 593 events of
-- 35408, which is 1.7 per cent, while this sport does it on 3572 of 4411. Swimming records the
-- round in the round type and this sport records it in the name. The alternative was `Monitor`,
-- watching the proportion fall; it was rejected because the round type has a place for the heat
-- number and the name is not it. Recorded here because a later reader meeting a check that
-- reports four fifths of its population needs to know it was chosen and not overlooked.
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 135
JOIN round_type rt ON rt.id = e.round_typeFK
WHERE e.del = 'no'
  AND e.round_typeFK IN (38)
  AND (e.name REGEXP 'Heat [0-9]' OR e.name LIKE '%Heats%' OR e.name LIKE '%Heat Summary%' OR e.name LIKE '%Heat summary%'
       OR e.name LIKE '%Summary%' OR e.name LIKE '%Semi Final%'
       OR e.name LIKE '%Swim-Off%' OR e.name LIKE '%Preliminary%')
  AND t.tournament_templateFK NOT IN (0)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

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
     AND tt.sportFK = 135
WHERE e.del = 'no'
  AND (
        e.round_typeFK NOT IN (38)
     OR e.name LIKE '%Heats%' OR e.name LIKE '%Heat Summary%' OR e.name LIKE '%Heat summary%'
     OR e.name LIKE '%Summary%' OR e.name LIKE '%Semi Final%'
     OR e.name LIKE '%Swim-Off%' OR e.name LIKE '%Preliminary%'
      )
  AND t.tournament_templateFK NOT IN (0)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, name_says, event_id;

-- ==============================================================================
SELECT
    -- CheckID - Para-Swimming-DQ-089
    -- Name - EVENT_RESULTS_QUALIFICATION_NOT_HONOURED_BY_LATER_ROUND
    -- What it does: Finds heats and semi-finals whose qualifiers do not appear in any later round of the same stage and discipline.
    CASE
        -- Two states and two repairs. Where later rounds were held, an entry is missing from
        -- one of them; where the stage holds none at all for this discipline, the round
        -- itself was never written and the qualifiers have nowhere to be. The second is
        -- GLOBAL-DQ-063's shape seen from the results side, and separating it keeps a
        -- reviewer from looking for a swimmer in an event that does not exist.
        WHEN y.later_events_in_stage = 0 THEN 'Qualified_With_No_Later_Round_Held'
        WHEN y.qualified_count > y.largest_later_field THEN 'More_Qualifiers_Than_A_Later_Round_Holds'
        ELSE 'Qualifier_Absent_From_Every_Later_Round'
    END AS check_type,
    y.event_id,
    y.event_name,
    y.round_type_id,
    y.round_type_name,
    y.discipline_id,
    y.discipline_name,
    y.qualified_count,
    y.unhonoured_count,
    y.unhonoured_competitors,
    y.later_events_in_stage,
    y.largest_later_field,
    y.template_name,
    y.tournament_name,
    y.stage_id,
    y.event_startdate,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: A swimmer marked as qualifying from a heat or a semi-final is
-- asserted to appear in a later round of the same stage and discipline. This reports the ones
-- who do not.
--
-- Copied from `Swimming-DQ-084` on 2026-09-07. **All four of its round-type lists were derived
-- from this sport rather than carried over**, and the fourth was almost missed: it lives in the
-- coverage branch alone, and leaving it as Swimming's made the statement audit nothing while
-- looking like a clean result. This sport's rounds are `38` for the heats, `178` for the
-- semi-finals and `173`, `223` and `224` for the finals and swim-offs; Swimming's `320`, `204`,
-- `2` and `9` do not occur here at all.
--
-- **The eligible population is 409 and not the sport's 8300 events**, because it counts only a
-- finished heat or semi-final holding a competitor marked `Q`. This sport marks 6474 events
-- `notstarted` while they carry results, so most of its heats never reach the population at
-- all - see `Para-Swimming-DQ-069`, which is that defect, and read the two together rather
-- than reading 45 of 409 as the whole picture.
FROM (
    SELECT
        x.event_id,
        x.event_name,
        x.round_type_id,
        x.round_type_name,
        x.discipline_id,
        x.discipline_name,
        x.stage_id,
        x.template_name,
        x.tournament_name,
        x.event_startdate,
        x.later_events_in_stage,
        x.largest_later_field,
        COUNT(*) AS qualified_count,
        SUM(CASE WHEN x.later_events_for_competitor = 0 THEN 1 ELSE 0 END) AS unhonoured_count,
        SUBSTRING(GROUP_CONCAT(CASE WHEN x.later_events_for_competitor = 0 THEN x.participant_name END
                               ORDER BY x.participant_name SEPARATOR ', '), 1, 300) AS unhonoured_competitors
    FROM (
        SELECT
            e.id AS event_id,
            e.name AS event_name,
            e.round_typeFK AS round_type_id,
            rt.name AS round_type_name,
            d.id AS discipline_id,
            d.name AS discipline_name,
            ts.id AS stage_id,
            tt.name AS template_name,
            t.name AS tournament_name,
            e.startdate AS event_startdate,
            pa.name AS participant_name,
            -- Does the stage hold any later round for this discipline at all
            (SELECT COUNT(DISTINCT e2.id)
               FROM event e2
               JOIN object_discipline od2 ON od2.object_typeFK = 5 AND od2.objectFK = e2.id AND od2.del = 'no'
              WHERE e2.del = 'no'
                AND e2.tournament_stageFK = e.tournament_stageFK
                AND od2.disciplineFK = od.disciplineFK
                AND e2.id <> e.id
                AND ( (e.round_typeFK IN (38) AND e2.round_typeFK IN (178, 173, 223, 224))
                   OR (e.round_typeFK IN (178)   AND e2.round_typeFK IN (173, 223, 224)) )
            ) AS later_events_in_stage,
            -- and how many competitors the biggest of them could take. The largest is used
            -- rather than the sum, because a swimmer reaching the final swam the semi too
            -- and adding the two fields would count them twice.
            (SELECT COALESCE(MAX(f.field_size), 0) FROM (
                SELECT COUNT(DISTINCT ep5.id) AS field_size
                  FROM event e5
                  JOIN object_discipline od5 ON od5.object_typeFK = 5 AND od5.objectFK = e5.id AND od5.del = 'no'
                  JOIN event_participants ep5 ON ep5.eventFK = e5.id AND ep5.del = 'no'
                 WHERE e5.del = 'no'
                   AND e5.tournament_stageFK = e.tournament_stageFK
                   AND od5.disciplineFK = od.disciplineFK
                   AND e5.id <> e.id
                   AND ( (e.round_typeFK IN (38) AND e5.round_typeFK IN (178, 173, 223, 224))
                      OR (e.round_typeFK IN (178)   AND e5.round_typeFK IN (173, 223, 224)) )
                 GROUP BY e5.id
            ) f) AS largest_later_field,
            -- and does one of them hold this competitor
            (SELECT COUNT(DISTINCT e3.id)
               FROM event e3
               JOIN object_discipline od3 ON od3.object_typeFK = 5 AND od3.objectFK = e3.id AND od3.del = 'no'
               JOIN event_participants ep3 ON ep3.eventFK = e3.id AND ep3.del = 'no'
              WHERE e3.del = 'no'
                AND e3.tournament_stageFK = e.tournament_stageFK
                AND od3.disciplineFK = od.disciplineFK
                AND e3.id <> e.id
                AND ep3.participantFK = ep.participantFK
                AND ( (e.round_typeFK IN (38) AND e3.round_typeFK IN (178, 173, 223, 224))
                   OR (e.round_typeFK IN (178)   AND e3.round_typeFK IN (173, 223, 224)) )
            ) AS later_events_for_competitor
        FROM event e
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
             AND tt.sportFK = 135
        JOIN round_type rt ON rt.id = e.round_typeFK
        JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
        JOIN discipline d ON d.id = od.disciplineFK
        JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
        JOIN participant pa ON pa.id = ep.participantFK
        -- The qualification marker in every spelling the sport uses. The column collation
        -- folds case, so this reads `Q`, `q/CR`, `QA`, `QFB` and `QSO` alike, and the sport's
        -- vocabulary holds no comment beginning with Q that means anything else.
        JOIN result cm ON cm.event_participantsFK = ep.id AND cm.del = 'no'
                      AND cm.result_typeFK = 104
                      AND cm.value LIKE 'Q%'
        WHERE e.del = 'no'
          AND e.status_type = 'finished'
          AND e.round_typeFK IN (38, 178)
          AND t.tournament_templateFK NOT IN (0)
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
          -- AND t.tournament_templateFK = <tournament_template_id>
          -- AND e.startdate >= '<from_datetime>'
          -- AND e.startdate <  '<to_datetime>'
    ) x
    GROUP BY x.event_id, x.event_name, x.round_type_id, x.round_type_name,
             x.discipline_id, x.discipline_name, x.stage_id, x.template_name,
             x.tournament_name, x.event_startdate, x.later_events_in_stage, x.largest_later_field
) y
WHERE y.unhonoured_count > 0

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
-- The eligible population is every finished heat and semi-final holding at least one
-- qualifier. An event nobody qualified from has no claim to test.
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 135
JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
JOIN result cm ON cm.event_participantsFK = ep.id AND cm.del = 'no'
              AND cm.result_typeFK = 104
              AND cm.value LIKE 'Q%'
WHERE e.del = 'no'
  AND e.status_type = 'finished'
  AND e.round_typeFK IN (38, 178)
  AND t.tournament_templateFK NOT IN (0)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, unhonoured_count DESC, event_startdate DESC, event_id;
