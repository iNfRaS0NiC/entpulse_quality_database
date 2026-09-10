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


-- ================================================================================
SELECT
    -- CheckID - BMX-Racing-DQ-121
    -- Name - EVENT_NAME_CARRIES_A_WORD_THE_RENAMING_PATTERN_WILL_DROP
    -- What it does: Finds events whose name holds a word the required form has no slot for, so the renaming cron will drop it.
    CASE WHEN MAX(g.events_sharing_the_expected_name) > 1
         THEN 'LOSING_IT_COLLIDES_WITH_ANOTHER_EVENT'
         ELSE 'WORD_IS_DROPPED_AND_THE_NAME_STAYS_UNIQUE'
    END AS check_type,
    g.event_id,
    g.event_name,
    g.expected_name,
    GROUP_CONCAT(DISTINCT g.word ORDER BY g.word SEPARATOR ', ') AS words_the_pattern_drops,
    COUNT(DISTINCT g.word) AS word_count,
    MAX(g.round_type_name) AS round_type_name,
    MAX(g.tournament_name) AS tournament_name,
    MAX(g.template_name) AS template_name,
    MAX(g.startdate) AS event_startdate,
    MAX(g.events_sharing_the_expected_name) AS events_sharing_the_expected_name,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: The required form is `[Discipline] [Gender] [Round] [Run N]
-- [Heat N]` and it is built from the event's own settings, so any word the current name carries
-- that the form has no slot for disappears the moment the renaming cron reaches that event.
-- This lists those words while they are still there. `Women's Racing Motos Overall Heat 3`
-- becomes `Racing Women Heats Heat 3`, and this reports `Motos` and `Overall`.
--
-- **It reports a consequence rather than a defect, and that is a change of position.** Until
-- 2026-09-10 `SPORTS/BMX-Racing.md` recorded that the loss of `Overall` was a consequence of the
-- chosen form and not something a check could report. The user reversed that on 2026-09-10:
-- what a rename destroys cannot be recovered from the database afterwards, so it has to be
-- readable before the cron passes, and a board row is where a person will actually see it. The
-- sport file records the reversal.
--
-- `check_type` separates the two, and only the first is a decision anybody has to take:
--   LOSING_IT_COLLIDES_WITH_ANOTHER_EVENT - another event under the same tournament reduces to
--     the same expected name, so this word is part of what tells the two apart and after the
--     rename a trailing number is all that will. That is how `Motos` and `Motos Overall` became
--     `Racing Men Heats 1` and `Racing Men Heats 2`, neither of which says which is the overall
--     standing.
--   WORD_IS_DROPPED_AND_THE_NAME_STAYS_UNIQUE - the word goes and nothing collides. Still worth
--     seeing before it goes, and cheaper to accept.
--
-- **A word is matched normalised and in both numbers.** The comparison lower-cases, drops a
-- possessive `'s`, drops everything that is not a letter or a digit, and accepts a match on the
-- singular or the plural, so `Women's` against `Women` is not a loss and `Finals` against
-- `Final` is not either. What survives that is a word with no counterpart in the expected name
-- at all.
--
-- One row per event, never one per word: the audited object is the event, the words it loses
-- travel as a named column, and `word_count` says how many. An event whose name already is the
-- expected name carries no lost word and is not a finding.
--
-- The eligible population is the one `BMX-Racing-DQ-118` audits - every event whose discipline,
-- stage gender and round type let the required form be built at all. The two answer different
-- questions over it: `-118` asks whether the name is the expected one,
-- `EVENT_NAME_DOES_NOT_FOLLOW_THE_SPORT_PATTERN`, and this asks what becomes of the words when
-- it is made so. `BMX-Racing-DQ-119 EVENT_NAME_PATTERN_CANNOT_BE_BUILT` owns the events that
-- fall out of the population.
FROM (
    SELECT
        b.event_id,
        b.event_name,
        b.expected_name,
        b.round_type_name,
        b.tournament_name,
        b.template_name,
        b.startdate,
        b.events_sharing_the_expected_name,
        TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(b.name_for_the_diff, ' ', seq.n), ' ', -1)) AS word
    FROM (
        SELECT
            a.*,
            COUNT(*) OVER (PARTITION BY a.tournament_id, a.expected_name) AS events_sharing_the_expected_name
        FROM (
            SELECT
                e.id AS event_id,
                TRIM(e.name) AS event_name,
                -- The cron settles a collision by putting a number on the end, so that number
                -- is its own and not a word the name is losing. Split off before the diff, the
                -- same rule `BMX-Racing-DQ-118` applies when it accepts such a name as correct.
                CASE WHEN e.name REGEXP '[[:space:]][0-9]+$'
                     THEN TRIM(SUBSTRING(TRIM(e.name), 1,
                            CHAR_LENGTH(TRIM(e.name)) - CHAR_LENGTH(SUBSTRING_INDEX(TRIM(e.name), ' ', -1))))
                     ELSE TRIM(e.name)
                END AS name_for_the_diff,
                e.startdate,
                t.id AS tournament_id,
                t.name AS tournament_name,
                tt.name AS template_name,
                rt.name AS round_type_name,
                TRIM(CONCAT_WS(' ',
                    CASE od.disciplineFK WHEN 429 THEN 'Racing' WHEN 776 THEN 'Time Trial' END,
                    CASE ts.gender WHEN 'male' THEN 'Men' WHEN 'female' THEN 'Women' WHEN 'mixed' THEN 'Mixed' END,
                    CASE rt.id WHEN 2 THEN 'Semifinal' WHEN 38 THEN 'Round 1' ELSE rt.name END,
                    CASE WHEN MAX(CASE WHEN pr.name = 'Run' THEN pr.value END) IS NOT NULL
                         THEN CONCAT('Run ', MAX(CASE WHEN pr.name = 'Run' THEN pr.value END)) END,
                    CASE WHEN MAX(CASE WHEN pr.name = 'Heat' THEN pr.value END) IS NOT NULL
                         THEN CONCAT('Heat ', MAX(CASE WHEN pr.name = 'Heat' THEN pr.value END)) END
                )) AS expected_name
            FROM event e
            JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
            JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
            JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
            JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
            LEFT JOIN round_type rt ON rt.id = e.round_typeFK
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
              AND rt.name IS NOT NULL
              AND ts.gender IN ('male', 'female', 'mixed')
              AND od.disciplineFK IN (429, 776)
              AND e.name IS NOT NULL
              AND TRIM(e.name) <> ''
            GROUP BY e.id, e.name, e.startdate, t.id, t.name, tt.name,
                     rt.id, rt.name, ts.gender, od.disciplineFK
        ) a
    ) b
    -- One row per word of the name. Twelve is above the longest name the sport carries and the
    -- join stops at the word count of each name, so a short name costs one row.
    JOIN (
        SELECT 1 AS n UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
        UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8
        UNION ALL SELECT 9 UNION ALL SELECT 10 UNION ALL SELECT 11 UNION ALL SELECT 12
    ) seq
      ON seq.n <= CHAR_LENGTH(b.name_for_the_diff) - CHAR_LENGTH(REPLACE(b.name_for_the_diff, ' ', '')) + 1
) g
WHERE TRIM(g.word) <> ''
  AND LOWER(REGEXP_REPLACE(REGEXP_REPLACE(g.word, '''s$', ''), '[^A-Za-z0-9]', '')) <> ''
  AND CONCAT(' ', LOWER(REGEXP_REPLACE(g.expected_name, '[^A-Za-z0-9 ]', '')), ' ')
      NOT LIKE CONCAT('% ', LOWER(REGEXP_REPLACE(REGEXP_REPLACE(g.word, '''s$', ''), '[^A-Za-z0-9]', '')), ' %')
  AND CONCAT(' ', LOWER(REGEXP_REPLACE(g.expected_name, '[^A-Za-z0-9 ]', '')), ' ')
      NOT LIKE CONCAT('% ', TRIM(TRAILING 's' FROM LOWER(REGEXP_REPLACE(REGEXP_REPLACE(g.word, '''s$', ''), '[^A-Za-z0-9]', ''))), ' %')
  AND CONCAT(' ', LOWER(REGEXP_REPLACE(g.expected_name, '[^A-Za-z0-9 ]', '')), ' ')
      NOT LIKE CONCAT('% ', LOWER(REGEXP_REPLACE(REGEXP_REPLACE(g.word, '''s$', ''), '[^A-Za-z0-9]', '')), 's %')
GROUP BY g.event_id, g.event_name, g.expected_name

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
    JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
    LEFT JOIN round_type rt ON rt.id = e.round_typeFK
    WHERE e.del = 'no'
      AND tt.sportFK = 58
      AND od.disciplineFK IN (429, 776)
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
      AND rt.name IS NOT NULL
      AND ts.gender IN ('male', 'female', 'mixed')
      AND e.name IS NOT NULL
      AND TRIM(e.name) <> ''
) c

ORDER BY sort_order, check_type, event_startdate DESC;
