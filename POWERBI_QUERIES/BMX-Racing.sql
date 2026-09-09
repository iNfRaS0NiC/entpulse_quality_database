SELECT
    -- CheckID - BMX-Racing-DQ-118
    -- Name - EVENT_NAME_DOES_NOT_FOLLOW_THE_SPORT_PATTERN
    -- What it does: Finds events whose name is not the discipline, the gender, the round and the Run and Heat the event itself stores.
    y.check_type,
    y.event_id,
    y.event_name,
    y.expected_name,
    y.discipline_word,
    y.gender_word,
    y.round_word,
    y.run_value,
    y.heat_value,
    y.round_type_name,
    y.tournament_id,
    y.tournament_name,
    y.template_id,
    y.template_name,
    y.startdate,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: An event is described twice - once in the text of its own
-- name, once in the discipline, the stage gender, the round type and the Run and Heat
-- properties hung off it - and this reports where the name is not what those say it should be.
-- The required form is [Discipline] [Gender] [Round] [Run N] [Heat N], with `Overall` kept
-- where the event carries it.
--
-- **It is a guard, and it took two drafts to become one.** A renaming cron rewrites this
-- sport's event names to the required form, and the first draft of this check disagreed with
-- the cron about the round word: it used the sport's older vocabulary - `Motos`,
-- `Quarterfinal`, `1/8 Finals`, `Last Chance Race` - and so reported the rename as still
-- outstanding on most of the sport after the cron had already done it. The cron reads
-- `round_type.name`, and once this check reads the same thing it falls to almost nothing.
-- What it now reports is what the cron could not fix rather than what it has not reached yet.
--
-- **No counts are recorded here on purpose.** The population is being repaired while it is
-- read, and two measurements twenty minutes apart disagreed for that reason alone.
-- `RUNS/BMX-Racing.json` holds what each run actually returned.
--
-- `check_type` separates what the cron owns from what a person does:
--   RIGHT_WORDS_IN_THE_WRONG_ORDER - the round word is already the right one and only the
--     order differs. These are the rename and nothing else, and the cron closes them. A row
--     here that survives a cron pass is one the cron could not build a name for, such as an
--     event of mixed gender whose name carries no gender word at all.
--   NAME_DOES_NOT_MATCH_DISCIPLINE_GENDER_ROUND_RUN_AND_HEAT - the name says something else.
--     Among them, events whose entire name is `Male` or `Female` and carry no discipline, no
--     round and no number; events named `General Classification`; events saying `Time Trial`
--     under a round type of Qualifier; events reading `Heat 4 Overall` with no round word at
--     all; and events saying `Motos Overall` under a round type of Final.
--   POSSESSIVE_APOSTROPHE_BROKEN - `Men' Racing Motos`, an apostrophe with no s. Wrong under
--     the sport's old convention as well as the new one.
--   HEAT_NUMBER_MISSING_OR_DISAGREES_WITH_THE_HEAT_PROPERTY and its Run twin compare the name
--     against a stored number rather than against a vocabulary, so they stay true whatever is
--     decided about wording.
-- Everything except RIGHT_WORDS_IN_THE_WRONG_ORDER is a defect under any reading of the sport
-- and needs a person rather than another cron pass.
--
-- **The pattern has no slot for `Overall`, and that is the cron's answer rather than this
-- check's.** Two events of the same round, gender and tournament - one plain, one `Overall` -
-- both reduce to the same name under the pattern, and the cron settles that by numbering them
-- from the oldest rather than by keeping a word. So `Overall` is not admitted as a round word,
-- and a trailing number is admitted instead. What the sport loses by that is real and is worth
-- recording: `Motos` and `Motos Overall` were two different events, and `Racing Men Heats 1`
-- and `Racing Men Heats 2` no longer say which is which. That is a consequence of the required
-- form, not a defect this check can report.
--
-- `General Classification` needed no such handling: no tournament holding one holds any other
-- final, so it is that tournament's final under another name and folding it in collides with
-- nothing. Measured 2026-09-09, the same way and with the opposite answer.
--
-- The round word is `round_type.name` as stored, with the two exceptions the cron makes:
-- `Semi Finals` becomes `Semifinal`, and `1` becomes `Round 1`. An earlier draft of this check
-- used the sport's own older vocabulary instead - `Motos`, `Quarterfinal`, `1/8 Finals`,
-- `Last Chance Race` - which disagreed with the cron on most of the sport and reported the
-- rename as still outstanding after it had run. The reference row is the authority here
-- because it is what the cron reads.
FROM (
    SELECT
        x.*,
        TRIM(CONCAT_WS(' ',
            x.discipline_word,
            x.gender_word,
            x.round_word,
            CASE WHEN x.run_value IS NOT NULL THEN CONCAT('Run ', x.run_value) END,
            CASE WHEN x.heat_value IS NOT NULL THEN CONCAT('Heat ', x.heat_value) END
        )) AS expected_name,
        -- The cron settles a collision by putting a number on the end, so a name that is the
        -- expected one plus a trailing number is correct and not a finding. The number is the
        -- cron's to choose - it orders by date - and reproducing that choice here would make
        -- the check disagree with its own correct output.
        CASE WHEN x.event_name REGEXP '[[:space:]][0-9]+$'
             THEN TRIM(SUBSTRING(x.event_name, 1,
                    CHAR_LENGTH(x.event_name) - CHAR_LENGTH(SUBSTRING_INDEX(x.event_name, ' ', -1))))
             ELSE x.event_name
        END AS name_without_group_number,
        CASE
            WHEN x.event_name LIKE 'Men'' %' OR x.event_name LIKE 'Women'' %'
                 THEN 'POSSESSIVE_APOSTROPHE_BROKEN'
            WHEN x.heat_value IS NOT NULL
                 AND x.event_name NOT LIKE CONCAT('%Heat ', x.heat_value)
                 AND x.event_name NOT LIKE CONCAT('%Heat ', x.heat_value, ' %')
                 THEN 'HEAT_NUMBER_MISSING_OR_DISAGREES_WITH_THE_HEAT_PROPERTY'
            WHEN x.run_value IS NOT NULL
                 AND x.event_name NOT LIKE CONCAT('%Run ', x.run_value, '%')
                 THEN 'RUN_NUMBER_MISSING_OR_DISAGREES_WITH_THE_RUN_PROPERTY'
            WHEN x.event_name LIKE CONCAT('%', x.round_word, '%')
                 THEN 'RIGHT_WORDS_IN_THE_WRONG_ORDER'
            ELSE 'NAME_DOES_NOT_MATCH_DISCIPLINE_GENDER_ROUND_RUN_AND_HEAT'
        END AS check_type
    FROM (
        SELECT
            e.id AS event_id,
            e.name AS event_name,
            e.startdate,
            t.id AS tournament_id,
            t.name AS tournament_name,
            tt.id AS template_id,
            tt.name AS template_name,
            rt.id AS round_type_id,
            rt.name AS round_type_name,
            CASE ts.gender
                WHEN 'male' THEN 'Men'
                WHEN 'female' THEN 'Women'
                WHEN 'mixed' THEN 'Mixed'
            END AS gender_word,
            CASE od.disciplineFK
                WHEN 429 THEN 'Racing'
                WHEN 776 THEN 'Time Trial'
            END AS discipline_word,
            -- `round_type.name` as stored, with the only two exceptions the renaming
            -- cron makes: `Semi Finals` is written `Semifinal`, and `1` is written
            -- `Round 1` because a bare number names nothing. Confirmed 2026-09-09
            -- against the events the cron had already rewritten: every other round type
            -- appears in the name exactly as the reference row spells it, plural and
            -- spacing included, and the `Round` event property is a worse source than
            -- the reference row because it carries typos of its own.
            CASE rt.id
                WHEN 2  THEN 'Semifinal'
                WHEN 38 THEN 'Round 1'
                ELSE rt.name
            END AS round_word,
            MAX(CASE WHEN pr.name = 'Run' THEN pr.value END) AS run_value,
            MAX(CASE WHEN pr.name = 'Heat' THEN pr.value END) AS heat_value
        FROM event e
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
        JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
        LEFT JOIN round_type rt ON rt.id = e.round_typeFK
        -- One join for both properties, narrowed to the two names, and collapsed by the
        -- GROUP BY below rather than asked twice per event.
        LEFT JOIN property pr ON pr.object = 'event' AND pr.objectFK = e.id AND pr.del = 'no'
                             AND pr.name IN ('Run', 'Heat')
        WHERE e.del = 'no'
          AND tt.sportFK = 58
          -- sport.id 58 carries two editorially distinct sports. Racing and Time Trial are
          -- this one; Freestyle is discipline 430 and belongs to BMX-Freestyle.
          AND od.disciplineFK IN (429, 776)
          AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
          -- AND t.tournament_templateFK = <tournament_template_id>
        GROUP BY e.id, e.name, e.startdate, t.id, t.name, tt.id, tt.name,
                 rt.id, rt.name, ts.gender, od.disciplineFK
    ) x
    WHERE x.round_word IS NOT NULL
      AND x.gender_word IS NOT NULL
      AND x.discipline_word IS NOT NULL
      AND x.event_name IS NOT NULL
      AND TRIM(x.event_name) <> ''
) y
WHERE BINARY y.event_name <> BINARY y.expected_name
  AND BINARY y.name_without_group_number <> BINARY y.expected_name

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT c.event_id) AS eligible_count,
    1 AS sort_order
FROM (
    SELECT
        e.id AS event_id,
        CASE ts.gender
            WHEN 'male' THEN 'Men'
            WHEN 'female' THEN 'Women'
            WHEN 'mixed' THEN 'Mixed'
        END AS gender_word,
        CASE od.disciplineFK
            WHEN 429 THEN 'Racing'
            WHEN 776 THEN 'Time Trial'
        END AS discipline_word,
        CASE rt.id
            WHEN 2  THEN 'Semifinal'
            WHEN 38 THEN 'Round 1'
            ELSE rt.name
        END AS round_word,
        e.name AS event_name
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
    LEFT JOIN round_type rt ON rt.id = e.round_typeFK
    WHERE e.del = 'no'
      AND tt.sportFK = 58
      AND od.disciplineFK IN (429, 776)
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
) c
WHERE c.round_word IS NOT NULL
  AND c.gender_word IS NOT NULL
  AND c.discipline_word IS NOT NULL
  AND c.event_name IS NOT NULL
  AND TRIM(c.event_name) <> ''

ORDER BY sort_order, event_id;


-- ================================================================================
SELECT
    -- CheckID - BMX-Racing-DQ-119
    -- Name - EVENT_NAME_PATTERN_CANNOT_BE_BUILT
    -- What it does: Flags events for which no expected name exists, because the discipline, the gender, the round type or the name itself is missing.
    z.check_type,
    z.event_id,
    z.event_name,
    z.discipline_word,
    z.gender_word,
    z.round_type_id,
    z.round_type_name,
    z.tournament_id,
    z.tournament_name,
    z.template_id,
    z.template_name,
    z.startdate,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: The companion of EVENT_NAME_DOES_NOT_FOLLOW_THE_SPORT_PATTERN,
-- and the reason that check can be strict. An expected name is the discipline, the gender and
-- the round word joined together, so an event missing any of the three has no expected name to
-- be compared against and would otherwise leave the audit without being counted anywhere.
--
-- The four states are one work list rather than four checks: none of them is a naming defect,
-- and none can be repaired by renaming anything. A missing discipline, gender or round type is
-- a gap in the event's own settings. A round type outside the vocabulary is a decision nobody
-- has made yet - the twelve ids in the list are the ones this sport uses today, and a new one
-- arriving here is the check asking for a word rather than reporting a fault.
--
-- It returns nothing on the day it is written, which is what it is for.
FROM (
    SELECT
        x.*,
        CASE
            WHEN x.event_name IS NULL OR TRIM(x.event_name) = '' THEN 'EVENT_NAME_EMPTY'
            WHEN x.gender_word IS NULL                           THEN 'NO_USABLE_GENDER_ON_THE_STAGE'
            WHEN x.round_type_id IS NULL                         THEN 'NO_ROUND_TYPE_ON_THE_EVENT'
            ELSE 'ROUND_TYPE_OUTSIDE_THE_SPORT_VOCABULARY'
        END AS check_type
    FROM (
        SELECT
            e.id AS event_id,
            e.name AS event_name,
            e.startdate,
            t.id AS tournament_id,
            t.name AS tournament_name,
            tt.id AS template_id,
            tt.name AS template_name,
            rt.id AS round_type_id,
            rt.name AS round_type_name,
            CASE ts.gender
                WHEN 'male' THEN 'Men'
                WHEN 'female' THEN 'Women'
                WHEN 'mixed' THEN 'Mixed'
            END AS gender_word,
            CASE od.disciplineFK
                WHEN 429 THEN 'Racing'
                WHEN 776 THEN 'Time Trial'
            END AS discipline_word,
            CASE rt.id
                WHEN 2  THEN 'Semifinal'
                WHEN 38 THEN 'Round 1'
                ELSE rt.name
            END AS round_word
        FROM event e
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
        JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
        LEFT JOIN round_type rt ON rt.id = e.round_typeFK
        WHERE e.del = 'no'
          AND tt.sportFK = 58
          AND od.disciplineFK IN (429, 776)
          AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
          -- AND t.tournament_templateFK = <tournament_template_id>
    ) x
    WHERE x.event_name IS NULL
       OR TRIM(x.event_name) = ''
       OR x.gender_word IS NULL
       OR x.round_type_id IS NULL
       OR x.round_word IS NULL
) z

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
WHERE e.del = 'no'
  AND tt.sportFK = 58
  AND od.disciplineFK IN (429, 776)
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>

ORDER BY sort_order, event_id;
