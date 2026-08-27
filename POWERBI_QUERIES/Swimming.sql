SELECT
    -- CheckID - Swimming-DQ-046
    -- Name - EVENT_RESULTS_RANK_SEQUENCE_BROKEN_OUTSIDE_SECONDARY_FINAL
    -- What it does: Finds Rank sequences that do not run 1, 2, 3 with ties skipping, accepting that a B final starts where the A final stopped.
    CASE
        WHEN x.start_breaks > 0 THEN 'RANK_SEQUENCE_DOES_NOT_START_AT_ONE'
        WHEN x.gaps > 0 THEN 'RANK_SEQUENCE_GAP'
        ELSE 'RANK_SEQUENCE_TIE_DOES_NOT_SKIP'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.template_name,
    x.tournament_stage_name,
    x.startdate,
    x.breaks,
    x.break_detail,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: This is GLOBAL-DQ-119 asked in the only form that means
-- anything in this sport. That template asserts three things about an event's Rank sequence -
-- that it starts at one, that no place is missing, and that a tie consumes the places it
-- stands for - and the first of them is false here by design.
-- Swimming runs a B final for the swimmers who finished ninth to sixteenth in the heats, and
-- that event legitimately ranks its field 9 to 16. Measured 2026-08-20, GLOBAL-DQ-119 returns
-- 281 events for this sport and 191 of them are B finals reported for starting at nine, which
-- is 68 per cent of its output describing correct data. The other two assertions are sound
-- here and are kept unchanged, so what this statement removes is one branch on one class of
-- event rather than the rule.
-- A B final is recognised from its own name, because the sport does not mark it any other way:
-- the round type is the same 173 Final the A final carries. Five spellings occur - Final B,
-- Final - B, - Final -B, - Final - B and Final -B - so the match is anchored on a trailing B
-- preceded by Final and any spaces or hyphens. Semi Final B is deliberately not exempt: the two
-- semi-finals are parallel heats and each ranks its own field from one, so a semi-final B that
-- starts at nine is the defect this statement is for.
-- The exemption is applied to the start branch alone. A B final whose sequence has a hole in it,
-- or whose tie does not skip, is reported exactly as any other event is, and the break_kind is
-- decided with the same guard so an exempt start is never mislabelled onto a real gap.
-- The audited object is the event and a break is reported where the sequence breaks, not at
-- every place it displaces afterwards; both properties are inherited from the template and the
-- reasoning for them is recorded there.
FROM (
    SELECT
        b.event_id,
        e.name AS event_name,
        tt.name AS template_name,
        ts.name AS tournament_stage_name,
        e.startdate,
        COUNT(*) AS breaks,
        SUM(CASE WHEN b.break_kind = 'START' THEN 1 ELSE 0 END) AS start_breaks,
        SUM(CASE WHEN b.break_kind = 'GAP' THEN 1 ELSE 0 END) AS gaps,
        GROUP_CONCAT(b.break_text ORDER BY b.at_place SEPARATOR ' | ') AS break_detail
    FROM (
        SELECT
            s.event_id,
            s.rank_value AS at_place,
            CASE
                WHEN s.prev_rank IS NULL AND s.rank_value <> 1
                     AND (s.event_name NOT REGEXP 'Final[ -]*B$' OR s.event_name LIKE '%Semi%')
                    THEN 'START'
                WHEN s.next_rank > s.rank_value + s.places_taken THEN 'GAP'
                ELSE 'TIE'
            END AS break_kind,
            CASE
                WHEN s.prev_rank IS NULL AND s.rank_value <> 1
                     AND (s.event_name NOT REGEXP 'Final[ -]*B$' OR s.event_name LIKE '%Semi%')
                    THEN CONCAT('sequence starts at ', s.rank_value, ', expected 1')
                ELSE CONCAT('place ', s.rank_value,
                            CASE WHEN s.places_taken > 1
                                 THEN CONCAT(' shared by ', s.places_taken) ELSE '' END,
                            ' is followed by ', s.next_rank,
                            ', expected ', s.rank_value + s.places_taken)
            END AS break_text
        FROM (
            SELECT
                ranked.event_id,
                ranked.event_name,
                ranked.rank_value,
                ranked.places_taken,
                LAG(ranked.rank_value)  OVER (PARTITION BY ranked.event_id ORDER BY ranked.rank_value) AS prev_rank,
                LEAD(ranked.rank_value) OVER (PARTITION BY ranked.event_id ORDER BY ranked.rank_value) AS next_rank
            FROM (
                SELECT
                    e2.id AS event_id,
                    e2.name AS event_name,
                    CAST(r.value AS UNSIGNED) AS rank_value,
                    COUNT(DISTINCT ep.id) AS places_taken
                FROM event_participants ep
                JOIN event e2 ON e2.id = ep.eventFK AND e2.del = 'no'
                JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
                JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
                JOIN tournament_template tt2 ON tt2.id = t2.tournament_templateFK AND tt2.del = 'no'
                     AND tt2.sportFK = 46
                JOIN result r ON r.event_participantsFK = ep.id AND r.del = 'no'
                     AND r.result_typeFK = 100
                     AND r.value REGEXP '^[1-9][0-9]*$'
                WHERE ep.del = 'no'
                  AND t2.tournament_templateFK NOT IN (10470, 12788, 12791, 12792, 12797, 12799)
                  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t2.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
                  -- AND t2.tournament_templateFK = <tournament_template_id>
                  -- AND e2.startdate >= '<from_datetime>'
                  -- AND e2.startdate <  '<to_datetime>'
                GROUP BY e2.id, e2.name, CAST(r.value AS UNSIGNED)
            ) ranked
        ) s
        WHERE (s.prev_rank IS NULL AND s.rank_value <> 1
               AND (s.event_name NOT REGEXP 'Final[ -]*B$' OR s.event_name LIKE '%Semi%'))
           OR (s.next_rank IS NOT NULL AND s.next_rank <> s.rank_value + s.places_taken)
    ) b
    JOIN event e ON e.id = b.event_id AND e.del = 'no'
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    GROUP BY b.event_id, e.name, tt.name, ts.name, e.startdate
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
     AND tt.sportFK = 46
WHERE e.del = 'no'
  AND t.tournament_templateFK NOT IN (10470, 12788, 12791, 12792, 12797, 12799)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'
  AND EXISTS (
      SELECT 1
      FROM event_participants ep3
      JOIN result r3 ON r3.event_participantsFK = ep3.id AND r3.del = 'no'
           AND r3.result_typeFK = 100
           AND r3.value REGEXP '^[1-9][0-9]*$'
      WHERE ep3.eventFK = e.id AND ep3.del = 'no'
  )

ORDER BY sort_order, event_id;
-- ==============================================================================
SELECT
    -- CheckID - Swimming-DQ-063
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
-- What it does, stated in full: Swimming names the stroke twice for the same event - once in
-- the event's own name and once in the discipline the event is attached to - and the two are
-- the same fact written in two places. Where they disagree one of them is wrong, and nothing
-- else in the record says which, so both are projected and the repair is a reading rather than
-- a rewrite.
-- This is not GLOBAL-DQ-109. That template compares the discipline event property against the
-- object_discipline relation, which is the same id stored twice, and it passes an event whose
-- name contradicts both consistently. This one never reads the id twice; it reads the name.
-- Measured 2026-08-20 the sport holds 64 of these. Forty-two are a Backstroke discipline under
-- an event named Breaststroke, which is one confusable pair doing most of the work; the rest
-- spread across Butterfly against Freestyle, Medley against Freestyle and Freestyle against
-- Breaststroke. Four of the 64 disagree on the distance as well as the stroke, so a reader who
-- assumes the discipline is right and only the wording drifted will be wrong on those.
-- Only the five stroke words the sport actually spells are compared, and an event or discipline
-- naming none of them is left out of both branches rather than reported as a mismatch against
-- nothing. Open water, medley relays entered without a stroke word and the knockout sprint
-- disciplines are therefore silent here by construction, not by exclusion.
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
         AND tt.sportFK = 46
    JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
    JOIN discipline d ON d.id = od.disciplineFK
    WHERE e.del = 'no'
      AND t.tournament_templateFK NOT IN (10470, 12788, 12791, 12792, 12797, 12799)
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
         AND tt.sportFK = 46
    JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
    JOIN discipline d ON d.id = od.disciplineFK
    WHERE e.del = 'no'
      AND t.tournament_templateFK NOT IN (10470, 12788, 12791, 12792, 12797, 12799)
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
    -- CheckID - Swimming-DQ-064
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
-- What it does, stated in full: A date of birth is only checkable against something, and the
-- something this sport supplies is the date of an event the athlete swam. The check reports the
-- contradiction and never decides which of the two dates is wrong: an athlete aged five at a
-- world championship is either carrying somebody else's birth year or attached to an event that
-- is not theirs, and the record does not say which. Both dates are projected for that reason.
-- The bounds were measured before they were chosen, on 2026-08-20, and the lower one is the
-- only one the data argues for. Age at first event runs 17, 15 and 19 athletes at eight, nine
-- and ten, then 53 at eleven, 221 at twelve and 684 at thirteen. Twelve upward is a population
-- that grows smoothly; everything below eleven is a flat floor of fifteen to twenty a year,
-- which is the shape of noise rather than of swimmers. The cut is nonetheless set at eight and
-- not at eleven, by decision of 2026-08-20, because eight is the last value no reading can
-- defend while nine to eleven would put roughly a hundred rows in front of a reviewer that
-- somebody would have to argue about one at a time. It returns 47 athletes.
-- Age-group swimming genuinely fields thirteen-year-olds and occasionally twelve-year-olds, so
-- a bound drawn on the birth year instead would report real competitors: nine athletes born
-- after 2012 are in the data and eight of them swam. That is the check this one deliberately is
-- not.
-- The upper bound catches one athlete today and exists for the other half of the same defect,
-- a birth date old enough to be a placeholder. One value of 1900-01-02 is already stored against
-- a swimmer with four swims.
-- The audited object is the athlete and not the participation: a wrong birth date is one repair
-- however many times that swimmer raced, and swims carries the count as a secondary column.
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
         AND tt.sportFK = 46
    WHERE op.object = 'sport' AND op.objectFK = 46 AND op.del = 'no'
      AND t.tournament_templateFK NOT IN (10470, 12788, 12791, 12792, 12797, 12799)
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
     AND tt.sportFK = 46
WHERE op.object = 'sport' AND op.objectFK = 46 AND op.del = 'no'
  AND t.tournament_templateFK NOT IN (10470, 12788, 12791, 12792, 12797, 12799)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, participant_id;
-- ==============================================================================
SELECT
    -- CheckID - Swimming-DQ-065
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
-- What it does, stated in full: The sport says whether an athlete is still competing in two
-- places - object_participants.active on the sport registry entry, and a status property on the
-- participant - and the two are one fact. Measured 2026-08-20 they agree almost everywhere:
-- 35546 athletes are active and active, 521 are inactive and retired, six are inactive and
-- dead. Eleven disagree, nine flagged active while retired and two flagged active while dead.
-- Both directions are asserted although only one of them has rows today. An athlete flagged
-- inactive while the profile still says active returns nothing at this run, and that is the
-- branch that will catch a retirement recorded on the wrong side of the pair when it happens;
-- removing it because it is empty would remove the half of the rule that is not currently
-- being broken.
-- Two neighbouring shapes are deliberately not reported here. 123 athletes carry no status
-- property at all, which is a missing value rather than a contradiction and belongs to the
-- missing-value checks; and one athlete carries status unattached, which is a vocabulary of one
-- and is recorded in SPORTS/Swimming.md rather than reported, because a single value nobody has
-- defined is a question and not a defect.
-- The audited object is the athlete. event_participations and last_event_date are secondary and
-- are there because they decide the repair: an athlete flagged active and retired who last swam
-- in 2009 is a stale flag, and one who swam last season is a wrong status.
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
    WHERE op.object = 'sport' AND op.objectFK = 46 AND op.del = 'no'
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
WHERE op.object = 'sport' AND op.objectFK = 46 AND op.del = 'no'

ORDER BY sort_order, participant_id;
-- ==============================================================================
SELECT
    -- CheckID - Swimming-DQ-066
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
-- What it does, stated in full: This one does not find a wrong record. The sport names the same
-- discipline in two vocabularies at once - an older set spelling the distance out, 56 to 58 for
-- the relays, and a current set abbreviating it, 365 to
-- 367 - and each vocabulary carries its own way of naming the event. The older
-- ids put the distance first, 4x100m Freestyle Relay; the current ids put it last, Freestyle
-- 4 x 100m. Distance-first is read literally, as a name beginning with a digit. Measured that
-- way on 2026-08-20 the pairing is almost total on the older side, 373 events against 1, and
-- clearly the habit on the current side, 1807 against 91.
-- What this statement reports is the residue where the two halves of that signature disagree,
-- and its signal is Monitor: the proportion is the finding and no single row is a defect. A
-- reviewer driving it to zero would be renaming events to match a convention nobody has
-- declared, which is why the sport file records the count rather than a target.
-- **The half-finished-cleanup reading was tested on 2026-08-27 and is wrong.** It assumed each
-- vocabulary carries its own way of naming the event, so that a row where the two disagree marks
-- a correction that got halfway. Profiling the editions refutes it: inside an edition the names
-- are uniform and the ids are not. All sixteen relays of the 2025 World Junior Championships are
-- named distance-first, eleven of them on the older ids and five on the current ones, so there
-- is nothing half-corrected on the naming side and the whole of the disagreement sits on the id.
-- The one row in the sport that does read like a leftover is event 5408531, Men's Medley
-- 4 x 100m of 2014-12-07, on the older 57 eight years after its own template stopped writing it.
-- **Which vocabulary an event gets belongs to the competition.** The World Championships changed
-- after 2006 and never went back; the World Junior Championships and the Swimming World Cup never
-- changed and are still writing the older ids in 2025 and 2023. It is neither a legacy nor an
-- error made event by event.
-- **The catalogue question this measured was decided on 2026-08-27: the older ids are the defect
-- and fold into the current ones**, 56 into 365, 57 into 367, 58 into 366. That repair is
-- Swimming-DQ-086's list and not this one's - this check stays a Monitor of the naming and goes
-- to zero by construction when the fold is done, rather than by anybody renaming an event.
-- The reason it mattered at all is downstream and is stated in SPORTS/Swimming.md: a Comp.Rank
-- grouped by disciplineFK sees two competitions where the meet ran one. Measured, the split
-- falls between editions of one competition rather than inside a single edition.
-- Only the six discipline ids where the signature was confirmed are read, and the confirmation
-- is what limits them to the relays. 351 and 362 are deliberately not among them:
-- SPORTS/Swimming.md records that those two are written both ways, so neither spelling is the
-- wrong one there. Including them was tried and rejected on 2026-08-20 - it took the output from
-- 92 rows to 2438, because for an individual event 800m Freestyle is simply how the sport writes
-- the name and carries no vocabulary signal at all. Every other discipline is silent for the
-- same reason.
-- **468 and 479 were among the older ids until 2026-08-25 and should never have been.** They
-- were read as the individual twins of the older vocabulary, which made this statement's premise
-- wrong twice over: they are not Swimming disciplines at all - `discipline.sportFK` puts both on
-- sport 135, Para Swimming - and they are individual, which is the one thing the paragraph above
-- gives as the reason for reading nothing but relays. The 67 Swimming events pointing at them
-- are a wrong reference rather than a naming habit, and `GLOBAL-DQ-015` reports them as
-- `Discipline_Belongs_To_Another_Sport` since it was widened the same day.
-- Removing them leaves the findings where they were, 92, and takes the eligible population from
-- 2272 to 2205: those events were being counted as a population this question could be asked of,
-- and it could not.
-- What this does not do is widen the older set to the twenty-five disciplines the sport actually
-- names the older way. That is a different check and a decision nobody has made -
-- `Swimming-DQ-086` lists every event on those ids, and `SPORTS/Swimming.md` open question 1
-- still asks whose habit the naming is.
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
         AND tt.sportFK = 46
    JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
         AND od.disciplineFK IN (56, 57, 58, 365, 366, 367)
    JOIN discipline d ON d.id = od.disciplineFK
    WHERE e.del = 'no'
      AND t.tournament_templateFK NOT IN (10470, 12788, 12791, 12792, 12797, 12799)
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
     AND tt.sportFK = 46
JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
     AND od.disciplineFK IN (56, 57, 58, 365, 366, 367)
WHERE e.del = 'no'
  AND t.tournament_templateFK NOT IN (10470, 12788, 12791, 12792, 12797, 12799)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_id;

-- ==============================================================================

SELECT
    -- CheckID - Swimming-DQ-069
    -- Name - EVENT_RESULTS_FULL_TIME_IMPOSSIBLE_FOR_DISTANCE
    -- What it does: Finds events whose stored Full time is faster than the distance in the discipline name allows anyone to swim.
    CASE
        WHEN y.leg_like = y.offending_participations
            THEN 'FULL_TIME_MATCHES_A_SINGLE_RELAY_LEG'
        WHEN y.leg_like > 0
            THEN 'FULL_TIME_BELOW_FLOOR_SOME_MATCHING_A_RELAY_LEG'
        ELSE 'FULL_TIME_BELOW_PHYSICAL_FLOOR'
    END AS check_type,
    y.event_id,
    y.event_name,
    y.discipline_id,
    y.discipline_name,
    y.metres,
    y.template_name,
    y.startdate,
    y.offending_participations,
    y.values_held,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Asks whether the time stored against a swimmer could have been
-- swum over the distance the event was contested at. Nothing in the package asks it. Every
-- other reading of 557 Full-time duration is relative - Swimming-DQ-040 compares one swimmer
-- with another, Swimming-DQ-041 compares a time with the leader plus the gap - and a whole
-- field can be internally consistent and still impossible. A 200 metre swim stored as 54.200
-- and ranked first is invisible to all of them, because there is nothing above it to contradict.
-- There is no global template for this and there cannot usefully be one: the invariant needs the
-- distance, and this sport is one of the few carrying it in the discipline name. GLOBAL-DQ-045
-- goes as far as a global rule can, asserting that the time is present, readable and not zero.
-- The floor is fifteen seconds per fifty metres, and it is deliberately far below anything a
-- human has done - the world record for 50 metres freestyle is a little over twenty seconds, so
-- the floor sits roughly a third under the fastest swim ever recorded and cannot be reached by a
-- correct row. It is not a performance test and must not be tightened into one: a stricter floor
-- would need the stroke, the gender and the pool length, and would start reporting slow swimmers
-- instead of wrong records.
-- The distance is read from the discipline rather than the event name, because the event name is
-- the half of the pair the sport is inconsistent about - Swimming-DQ-063 and Swimming-DQ-066 both
-- exist because of it. Open water is excluded: its disciplines are named in kilometres and its
-- times are recorded far more coarsely. Mixed Relay carries no distance at all and is silent here.
-- A relay leg is separated from the rest because it is a different repair. Where the stored
-- value would be a plausible time for one leg it is the leg time written into the team field,
-- and where it would not it is a wrong record: measured 2026-08-21, Medley 4 x 100m holds
-- 1:00.430 and Freestyle 4 x 200m holds 2:01.020, both single legs, while Backstroke 200m holds
-- 1.000 and 2.000, which are not times at all.
-- Measured 2026-08-21: 47 events, 41143 eligible.
-- Some of what it returns is the discipline being wrong rather than the time. Event 5229168 is
-- named Freestyle 100m and carries discipline 43 Freestyle 1500 metres, and a 100 metre swim is
-- of course impossible over 1500. The statement reports the pair as inconsistent and does not
-- choose which half to correct, which is the honest thing for it to do; Swimming-DQ-063 names
-- the same events from the other side, comparing the stroke in the name against the discipline,
-- so a reviewer holding both rows can see which of the two is wrong.
-- The audited object is the event. A field imported at the wrong distance is one correction
-- however many swimmers it caught - Freestyle 1500 metres holds ten in a single event -
-- and offending_participations and values_held carry the detail as named secondary columns.
FROM (
    SELECT
        x.event_id,
        x.event_name,
        x.discipline_id,
        x.discipline_name,
        x.metres,
        x.template_name,
        x.startdate,
        COUNT(*) AS offending_participations,
        SUM(CASE WHEN x.leg_metres < x.metres
                  AND x.stored_seconds >= (x.leg_metres / 50) * 15
                 THEN 1 ELSE 0 END) AS leg_like,
        SUBSTRING(GROUP_CONCAT(DISTINCT CONCAT(x.participant_name, ' (', x.stored_value, ')')
            ORDER BY x.participant_name SEPARATOR ' | '), 1, 200) AS values_held
    FROM (
        SELECT
            e.id AS event_id,
            e.name AS event_name,
            e.startdate,
            tt.name AS template_name,
            d.id AS discipline_id,
            d.name AS discipline_name,
            p.name AS participant_name,
            ft.value AS stored_value,
            CASE WHEN d.name LIKE '% x %'
                 THEN CAST(REGEXP_SUBSTR(d.name, '[0-9]+', 1, 1) AS UNSIGNED)
                      * CAST(REGEXP_SUBSTR(d.name, '[0-9]+', 1, 2) AS UNSIGNED)
                 ELSE CAST(REGEXP_SUBSTR(d.name, '[0-9]+', 1, 1) AS UNSIGNED) END AS metres,
            CASE WHEN d.name LIKE '% x %'
                 THEN CAST(REGEXP_SUBSTR(d.name, '[0-9]+', 1, 2) AS UNSIGNED)
                 ELSE CAST(REGEXP_SUBSTR(d.name, '[0-9]+', 1, 1) AS UNSIGNED) END AS leg_metres,
            CASE LENGTH(ft.value) - LENGTH(REPLACE(ft.value, ':', ''))
                 WHEN 0 THEN CAST(ft.value AS DECIMAL(14,3))
                 WHEN 1 THEN CAST(SUBSTRING_INDEX(ft.value, ':', 1) AS DECIMAL(14,3)) * 60
                           + CAST(SUBSTRING_INDEX(ft.value, ':', -1) AS DECIMAL(14,3))
                 ELSE CAST(SUBSTRING_INDEX(ft.value, ':', 1) AS DECIMAL(14,3)) * 3600
                           + CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(ft.value, ':', 2), ':', -1) AS DECIMAL(14,3)) * 60
                           + CAST(SUBSTRING_INDEX(ft.value, ':', -1) AS DECIMAL(14,3)) END AS stored_seconds
        FROM event e
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
             AND tt.sportFK = 46
        JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
        JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
             AND d.name REGEXP '[0-9]'
             AND d.name NOT LIKE '%km%'
        JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
        JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
        JOIN result ft ON ft.event_participantsFK = ep.id AND ft.del = 'no'
             AND ft.result_typeFK = 557
             AND ft.value REGEXP '^[0-9]+(:[0-9]{1,2})*(\\.[0-9]+)?$'
        WHERE e.del = 'no'
          AND e.status_type = 'finished'
          AND t.tournament_templateFK NOT IN (10470, 12788, 12791, 12792, 12797, 12799)
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
          -- AND t.tournament_templateFK = <tournament_template_id>
          -- AND e.startdate >= '<from_datetime>'
          -- AND e.startdate <  '<to_datetime>'
    ) x
    WHERE x.metres > 0
      AND x.stored_seconds > 0
      AND x.stored_seconds < (x.metres / 50) * 15
    GROUP BY x.event_id, x.event_name, x.discipline_id, x.discipline_name,
             x.metres, x.template_name, x.startdate
) y

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
     AND tt.sportFK = 46
JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
     AND d.name REGEXP '[0-9]'
     AND d.name NOT LIKE '%km%'
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
JOIN result ft ON ft.event_participantsFK = ep.id AND ft.del = 'no'
     AND ft.result_typeFK = 557
     AND ft.value REGEXP '^[0-9]+(:[0-9]{1,2})*(\\.[0-9]+)?$'
WHERE e.del = 'no'
  AND e.status_type = 'finished'
  AND t.tournament_templateFK NOT IN (10470, 12788, 12791, 12792, 12797, 12799)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, offending_participations DESC, event_id;

-- ==============================================================================

SELECT
    -- CheckID - Swimming-DQ-070
    -- Name - EVENT_DISCIPLINE_CONTRADICTS_TEMPLATE_COURSE
    -- What it does: Finds events contesting a short-course-only discipline under a template whose name says the pool is fifty metres.
    'Short_Course_Discipline_Under_Long_Course_Template' AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    d.id AS discipline_id,
    d.name AS discipline_name,
    tt.name AS template_name,
    t.name AS tournament_name,
    e.startdate,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Three of the sport disciplines are contested only in a
-- twenty-five metre pool - 368 Medley 4 x 50m, 369 Indv. Medley 100m and 370 Freestyle 4 x 50m.
-- None of them is swum at a long-course championship, so an event holding one under a template
-- whose name says Long Course is either the wrong discipline or the wrong tournament.
-- Two separate facts have to be present for this to be readable, and they are the reason it is a
-- sport statement rather than a global template. The distance comes from the discipline name,
-- which this sport carries and most do not, and the pool length comes from the template name,
-- which no column holds anywhere. The discipline gives the length of the race; it never gives
-- the length of the pool, and only the two together say anything.
-- The empirical side of the classification, measured 2026-08-21: under a template that names its
-- course at all, these three disciplines appear 573 times and every one of them is Short Course.
-- Not one appears under Long Course, which is what the check asserts and what it currently
-- returns nothing against. That is clean data and not a sentinel - the eligible population is
-- 573 and not 0, so the check is reading a real population and finding it correct today.
-- The mirror direction is deliberately not asserted. Open water appears 26 times under World
-- Championships Long Course, and that is not a defect: the long-course World Championships is
-- the championship the open-water events are held at, so the template name describes the meet
-- rather than the pool those races were swum in. Reporting them would be reporting the sport
-- calendar. The 1057 events under Swimming World Cup and the other templates that name no
-- course are outside the population for the same reason - there is no course to contradict.
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 46
JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
     AND od.disciplineFK IN (368, 369, 370)
JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
WHERE e.del = 'no'
  AND tt.name LIKE '%Long Course%'
  AND t.tournament_templateFK NOT IN (10470, 12788, 12791, 12792, 12797, 12799)
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
     AND tt.sportFK = 46
JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
     AND od.disciplineFK IN (368, 369, 370)
WHERE e.del = 'no'
  AND (tt.name LIKE '%Long Course%' OR tt.name LIKE '%Short Course%')
  AND t.tournament_templateFK NOT IN (10470, 12788, 12791, 12792, 12797, 12799)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_id;

-- ==============================================================================

SELECT
    -- CheckID - Swimming-DQ-072
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
-- What it does, stated in full: An event is described twice - once in the text of its own name,
-- once in a setting hung off it - and this reports where the two descriptions cannot both be
-- true. Two settings are read, and they are one check because the repair is the same act: decide
-- which of the two fields was written wrongly and correct that one.
-- **The distance.** Swimming-DQ-063 already compares the stroke in the name against the stroke
-- in the discipline and stops there, so an event named Individual Medley 400m carrying
-- 353 Indv. Medley 200m agrees on every letter it tests and is passed. Swimming-DQ-069 reaches
-- the same rows only when the mismatch also makes the time impossible, and it usually does not:
-- 4:46.620 is an ordinary 400 metre medley and an unremarkable-looking 200. Between the two
-- checks the distance was never asserted.
-- What makes this one decidable rather than merely inconsistent is the third field. The winning
-- time is stored independently of both the name and the discipline, so it can be read as a
-- witness, and it travels with every finding as `corroborating_time` for that reason. Measured
-- 2026-08-21, all 33 events agree with the name and contradict the discipline - 2:31.680 under
-- a name saying Breaststroke 200m and a discipline saying 100m, 50.060 under Freestyle 100m and
-- a discipline saying 1500 metres. The statement still reports the pair rather than naming the
-- guilty half, because the direction is a measurement of today and not an invariant, and the
-- day an event name is wrong is the day a check that assumed otherwise goes quiet.
-- Seven of the 33 are one shape: Individual Medley 400m carrying 353 Indv. Medley 200m instead
-- of 364, across five templates and twenty years. That is the two discipline vocabularies
-- SPORTS/Swimming.md describes, failing in the gap between them.
-- Relays are left out on both sides. A relay distance is a product of two numbers written
-- several ways in each vocabulary, and reading it here would repeat Swimming-DQ-066 badly.
-- **The round.** The same idea against `round_type`, and deliberately much narrower. Only an
-- event whose round type is one the sport actually names is read: the five types named with a
-- bare number - 38 and 89 both '1', 91 '3', 98 '10', 99 '11' - are excluded, because a bare
-- number denies nothing. That exclusion is what separates 3 findings from 581, and the 578 it
-- removes are not defects. Measured 2026-08-21, round type 329 Heats Summary carries 4095 events
-- and not one of them says so in its name, while 578 events say Heats Summary in the name and
-- carry the bare 38. Those are two live conventions, each self-consistent, spread over 22
-- templates from 2006 to 2025 - the same shape Swimming-DQ-066 records as Monitor for the
-- naming vocabularies, and driving it to zero would mean re-typing 578 events to a convention
-- nobody has declared. What survives the exclusion, measured the same day, is 3 events named
-- Heats Summary and typed 173 Final - two fields that both mean something, saying the opposite.
-- A bare Final is not read as a round word, because Final B and Semi Finals both contain it and
-- neither contradicts anything.
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
             AND tt.sportFK = 46
        JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
        JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
             AND d.name REGEXP '[0-9]'
             AND d.name NOT LIKE '%km%'
             AND d.name NOT LIKE '% x %'
        WHERE e.del = 'no'
          AND e.name REGEXP '[0-9]'
          AND e.name NOT LIKE '%x%'
          AND t.tournament_templateFK NOT IN (10470, 12788, 12791, 12792, 12797, 12799)
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
         AND tt.sportFK = 46
    JOIN round_type rt ON rt.id = e.round_typeFK
    WHERE e.del = 'no'
      AND e.round_typeFK NOT IN (38, 89, 91, 98, 99)
      AND t.tournament_templateFK NOT IN (10470, 12788, 12791, 12792, 12797, 12799)
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
     AND tt.sportFK = 46
LEFT JOIN round_type rt ON rt.id = e.round_typeFK
WHERE e.del = 'no'
  AND t.tournament_templateFK NOT IN (10470, 12788, 12791, 12792, 12797, 12799)
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
     OR (e.round_typeFK NOT IN (38, 89, 91, 98, 99)
         AND (e.name LIKE '%Heats%' OR e.name LIKE '%Summary%'
              OR e.name LIKE '%Semi Final%' OR e.name LIKE '%Swim-Off%'))
      )

ORDER BY sort_order, check_type, event_id;

-- ==============================================================================

SELECT
    -- CheckID - Swimming-DQ-073
    -- Name - EVENT_ROUND_RECORDED_IN_NAME_NOT_IN_ROUND_TYPE
    -- What it does: Measures how many events state their round only in their own name, leaving the round type at one of the five bare numbers.
    'Round_Recorded_In_Name_Not_In_Round_Type' AS check_type,
    e.id AS event_id,
    e.name AS event_name,
    CASE
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
-- What it does, stated in full: This one does not find a wrong record, and its signal is
-- Monitor for the same reason Swimming-DQ-066's is. The proportion is the finding and no single
-- row is a defect.
-- The sport states an event's round in one of two places and never in both. Measured 2026-08-21,
-- round type 329 Heats Summary carries 4095 events and not one of them says so in its name;
-- another 593 events say it in their name and leave the round type at 38 or 89, both of which
-- are named with the bare number 1 and therefore say nothing. Each half is self-consistent, and
-- the second runs across 22 templates from 2006 to 2025, so neither is the wrong one and there
-- is nothing here to correct. A reviewer driving this to zero would be re-typing 593 events to a
-- convention nobody has declared - which is why Swimming-DQ-072 excludes the bare-number round
-- types outright and reports only the three events where two meaningful fields contradict.
-- What the residue is worth is that it marks where one of the two halves was filled in and the
-- other was left, so it is the shortest description available of how far the round vocabulary
-- got. The spelling is part of that description and is projected rather than normalised: the
-- second convention writes Heats Summary, Heat Summary, Heat summary and Slow Heats, four
-- spellings of two rounds across two templates, which is what an unmanaged field looks like.
-- The eligible population is every event that states its round at all - through a round type the
-- sport actually names, or through a round word in its own name. The 10940 events carrying the
-- bare 38 with no round word in their name either are deliberately outside it: those state their
-- round nowhere, which is an absence rather than a choice between two conventions, and
-- SPORTS/params.json records that the bare-number types are left unjudged on purpose.
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 46
JOIN round_type rt ON rt.id = e.round_typeFK
WHERE e.del = 'no'
  AND e.round_typeFK IN (38, 89, 91, 98, 99)
  AND (e.name LIKE '%Heats%' OR e.name LIKE '%Heat Summary%' OR e.name LIKE '%Heat summary%'
       OR e.name LIKE '%Summary%' OR e.name LIKE '%Semi Final%'
       OR e.name LIKE '%Swim-Off%' OR e.name LIKE '%Preliminary%')
  AND t.tournament_templateFK NOT IN (10470, 12788, 12791, 12792, 12797, 12799)
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
     AND tt.sportFK = 46
WHERE e.del = 'no'
  AND (
        e.round_typeFK NOT IN (38, 89, 91, 98, 99)
     OR e.name LIKE '%Heats%' OR e.name LIKE '%Heat Summary%' OR e.name LIKE '%Heat summary%'
     OR e.name LIKE '%Summary%' OR e.name LIKE '%Semi Final%'
     OR e.name LIKE '%Swim-Off%' OR e.name LIKE '%Preliminary%'
      )
  AND t.tournament_templateFK NOT IN (10470, 12788, 12791, 12792, 12797, 12799)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, name_says, event_id;

-- ==============================================================================
SELECT
    -- CheckID - Swimming-DQ-083
    -- Name - EVENT_RESULTS_WINNING_TIME_TOO_SLOW_FOR_DISTANCE
    -- What it does: Finds events won in a time nobody could take over the distance the discipline names.
    'Winning_Time_Too_Slow_For_Distance' AS check_type,
    y.event_id,
    y.event_name,
    y.discipline_id,
    y.discipline_name,
    y.metres,
    y.winning_time,
    y.seconds_per_50m,
    y.shortest_distance_that_fits,
    y.field_size,
    y.template_name,
    y.tournament_name,
    y.event_startdate,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Asks whether the event's *winner* could have taken that long
-- over the distance the discipline names. It is the ceiling `Swimming-DQ-069` deliberately
-- does not have: that check has a floor of fifteen seconds per fifty metres and nothing above,
-- so a time too fast for the distance is reported and a time too slow for it is not.
-- **The winner is read rather than the field, and that is what makes it safe.** A slow
-- swimmer is one row in a normal event and no business of a data-quality check; a slow
-- *winner* means every competitor behind was slower still, which no correct record of an
-- elite meet produces. Measured 2026-08-25, the events this returns are not slow fields at
-- all - almost every one is a field swimming a different distance from the one the discipline
-- names, and the time matches a distance one step up: `Butterfly 50m` won in 2:13.700 is a
-- 200, `Freestyle 200m` won in 7:52.440 is an 800, `Indv. Medley 200m` won in 4:55.370 is a
-- 400, `Freestyle 4 x 50m` won in 3:03.540 is a 4 x 100. Not all of them are: `Breaststroke
-- 200m` won in 4:20.340 is roughly double the distance too, and the sport contests no 400
-- metre breaststroke, so that one is a wrong time rather than a wrong discipline. The row
-- reports the disagreement and does not choose which half to correct.
-- Reading the whole field instead would report the same events plus every slow swimmer in
-- the sport, which is the failure `Swimming-DQ-069` warns against in writing.
-- The ceiling is forty-five seconds per fifty metres, three times that check's floor. It is
-- not a performance test: the slowest ordinary swim in the sport sits under it by a wide
-- margin - 41114 events of the 41142 that hold a winning time are under it - and the twenty
-- eight above it are separated from the rest by a clear gap rather than a chosen cut.
-- `shortest_distance_that_fits` is the distance the winning time would need before it became
-- a plausible swim, at that same ceiling. It is a floor and never an estimate of the real
-- distance - the ceiling is a very slow pace, so the figure sits well under whatever was
-- actually swum - but it is the column that names the repair: an event labelled 50 metres
-- whose winning time needs at least 149 is not a 50 metre event, and the statement says so
-- without having to guess a discipline id.
-- The rows deliberately carry one check_type and not two. A split on whether that floor
-- reaches twice the labelled distance was written and removed on 2026-08-25: because the
-- floor is computed at the ceiling pace it understates every case, so `Indv. Medley 200m`
-- won in 4:55.370 - a 400 metre time - reported a floor of 329 and landed in the weaker
-- class beside the strong ones. A distinction that misfiles the obvious cases is worse than
-- none, and `seconds_per_50m` already lets a reviewer sort by severity.
-- Open water is out of scope, matched on the km in its name exactly as `Swimming-DQ-069`
-- matches it. Its disciplines are named in kilometres, and its knockout format contests
-- three different distances under one name - 1500 metres, 1000 and a 500 metre final - so
-- a pace read against the 3 km would be wrong for all three. `642 Mixed Relay` carries no
-- distance at all and is excluded by the same digit test that finds the others theirs.
-- A winning time of zero is excluded and is `GLOBAL-DQ-045`'s finding, which tests for it.
FROM (
    SELECT
        x.event_id,
        x.event_name,
        x.discipline_id,
        x.discipline_name,
        x.metres,
        x.winning_time,
        x.field_size,
        x.template_name,
        x.tournament_name,
        x.event_startdate,
        ROUND(x.winner_seconds / (x.metres / 50), 1) AS seconds_per_50m,
        CEIL(x.winner_seconds / 45 * 50) AS shortest_distance_that_fits
    FROM (
        SELECT
            e.id AS event_id,
            e.name AS event_name,
            d.id AS discipline_id,
            d.name AS discipline_name,
            tt.name AS template_name,
            t.name AS tournament_name,
            e.startdate AS event_startdate,
            (SELECT COUNT(*) FROM event_participants epx WHERE epx.eventFK = e.id AND epx.del = 'no') AS field_size,
            -- The distance the discipline names. A relay multiplies its two figures; an
            -- individual event takes the first. The same parsing Swimming-DQ-069 uses, and
            -- for the same reason: the event name is the half of the pair this sport is
            -- inconsistent about, so the discipline is what the time is read against.
            CASE WHEN d.name LIKE '% x %'
                 THEN CAST(REGEXP_SUBSTR(d.name, '[0-9]+', 1, 1) AS UNSIGNED)
                      * CAST(REGEXP_SUBSTR(d.name, '[0-9]+', 1, 2) AS UNSIGNED)
                 ELSE CAST(REGEXP_SUBSTR(d.name, '[0-9]+', 1, 1) AS UNSIGNED) END AS metres,
            MIN(ft.value) AS winning_time,
            MIN(CASE LENGTH(ft.value) - LENGTH(REPLACE(ft.value, ':', ''))
                     WHEN 0 THEN CAST(ft.value AS DECIMAL(14,3))
                     WHEN 1 THEN CAST(SUBSTRING_INDEX(ft.value, ':', 1) AS DECIMAL(14,3)) * 60
                               + CAST(SUBSTRING_INDEX(ft.value, ':', -1) AS DECIMAL(14,3))
                     ELSE CAST(SUBSTRING_INDEX(ft.value, ':', 1) AS DECIMAL(14,3)) * 3600
                               + CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(ft.value, ':', 2), ':', -1) AS DECIMAL(14,3)) * 60
                               + CAST(SUBSTRING_INDEX(ft.value, ':', -1) AS DECIMAL(14,3)) END) AS winner_seconds
        FROM event e
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
        JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
        JOIN discipline d ON d.id = od.disciplineFK
        JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
        JOIN result rk ON rk.event_participantsFK = ep.id AND rk.del = 'no'
                      AND rk.result_typeFK = 100
                      AND TRIM(rk.value) = '1'
        JOIN result ft ON ft.event_participantsFK = ep.id AND ft.del = 'no'
                      AND ft.result_typeFK = 557
                      AND ft.value IS NOT NULL
                      AND TRIM(ft.value) <> ''
                      AND ft.value <> '0.000'
        WHERE e.del = 'no'
          AND tt.sportFK = 46
          AND e.status_type = 'finished'
          AND d.name NOT LIKE '%km%'
          AND d.name REGEXP '[0-9]'
          AND t.tournament_templateFK NOT IN (10470, 12788, 12791, 12792, 12797, 12799)
          AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
          -- AND t.tournament_templateFK = <tournament_template_id>
          -- AND e.startdate >= '<from_datetime>'
          -- AND e.startdate <  '<to_datetime>'
        GROUP BY e.id, e.name, d.id, d.name, tt.name, t.name, e.startdate, metres
    ) x
    WHERE x.metres > 0
) y
WHERE y.seconds_per_50m >= 45

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
-- The eligible population is every pool event this can be asked of: one that names a
-- distance and holds a winning time to read against it.
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
JOIN discipline d ON d.id = od.disciplineFK
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
JOIN result rk ON rk.event_participantsFK = ep.id AND rk.del = 'no'
              AND rk.result_typeFK = 100
              AND TRIM(rk.value) = '1'
JOIN result ft ON ft.event_participantsFK = ep.id AND ft.del = 'no'
              AND ft.result_typeFK = 557
              AND ft.value IS NOT NULL
              AND TRIM(ft.value) <> ''
              AND ft.value <> '0.000'
WHERE e.del = 'no'
  AND tt.sportFK = 46
  AND e.status_type = 'finished'
  AND d.name NOT LIKE '%km%'
  AND d.name REGEXP '[0-9]'
  AND t.tournament_templateFK NOT IN (10470, 12788, 12791, 12792, 12797, 12799)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, seconds_per_50m DESC, event_id;

-- ==============================================================================
SELECT
    -- CheckID - Swimming-DQ-084
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
-- What it does, stated in full: Finds finished heats and semi-finals holding a competitor
-- whose Comment says they went through, where no later round of the same stage and the same
-- discipline holds that competitor at all.
-- `Q` is a claim about a place in the next round, and the record either bears it out or it
-- does not. SPORTS/Swimming.md already establishes what the marker means and that `R` marks
-- a reserve rather than a qualifier - which is why `R` is not read here. Nothing else in the
-- package compares one round with the next; every other results check reads a single event.
-- **The audited object is the event.** Measured 2026-08-25 the 954 competitors this finds
-- live in 647 events of 11316 eligible, about one and a half each, and a heat whose
-- qualifiers are missing is one entry list to repair rather than several unrelated ones.
-- **A withdrawal reads the same way and the database does not appear to record one.** A
-- swimmer may qualify and scratch, and nothing distinguishes that from an entry the record
-- lost. The rate is what makes the finding readable rather than any single row: 577 of the
-- sport's heats and 70 of its semi-finals, in a population of 11316. The check was written
-- on the ruling that every heat and semi-final has its own placings and a `Q` must be
-- followed, so the proportion is the finding and a row is a question rather than a verdict.
-- `unhonoured_competitors` names them so the question can be asked of the right swimmer.
-- A swim-off counts as a later round for both. `QSO` sends a competitor to one, and the
-- sport's swim-off is where a place the heats left tied is decided, so a qualifier appearing
-- there and nowhere else has been honoured.
-- Heats Summary is not read. It is the merged view of the heats rather than a round of its
-- own, so its qualifiers are the same people counted a second time.
-- The three classes were measured on 2026-08-25 and are three different repairs.
--   619 events, 770 competitors: a qualifier absent from rounds that had room for them.
--     537 of the 647 events lose exactly one qualifier out of two to five, which is the
--     shape a single withdrawal takes and equally the shape a lost entry takes; nothing in
--     the record separates the two, which is why the rate carries the finding.
--    24 events, 168 competitors: more qualifiers than the largest later round could hold -
--     sixteen going through to one final of eight. No swimmer is missing here at all; the
--     semi-final was never written, and `largest_later_field` is what tells this apart from
--     the class above.
--     4 events, 16 competitors: qualifiers with no later round of any kind.
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
                AND ( (e.round_typeFK IN (320, 204) AND e2.round_typeFK IN (178, 2, 173, 9, 223, 224))
                   OR (e.round_typeFK IN (178, 2)   AND e2.round_typeFK IN (173, 9, 223, 224)) )
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
                   AND ( (e.round_typeFK IN (320, 204) AND e5.round_typeFK IN (178, 2, 173, 9, 223, 224))
                      OR (e.round_typeFK IN (178, 2)   AND e5.round_typeFK IN (173, 9, 223, 224)) )
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
                AND ( (e.round_typeFK IN (320, 204) AND e3.round_typeFK IN (178, 2, 173, 9, 223, 224))
                   OR (e.round_typeFK IN (178, 2)   AND e3.round_typeFK IN (173, 9, 223, 224)) )
            ) AS later_events_for_competitor
        FROM event e
        JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
        JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
        JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
             AND tt.sportFK = 46
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
          AND e.round_typeFK IN (320, 204, 178, 2)
          AND t.tournament_templateFK NOT IN (10470, 12788, 12791, 12792, 12797, 12799)
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
     AND tt.sportFK = 46
JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
JOIN result cm ON cm.event_participantsFK = ep.id AND cm.del = 'no'
              AND cm.result_typeFK = 104
              AND cm.value LIKE 'Q%'
WHERE e.del = 'no'
  AND e.status_type = 'finished'
  AND e.round_typeFK IN (320, 204, 178, 2)
  AND t.tournament_templateFK NOT IN (10470, 12788, 12791, 12792, 12797, 12799)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, unhonoured_count DESC, event_startdate DESC, event_id;

-- ==============================================================================
SELECT
    -- CheckID - Swimming-DQ-086
    -- Name - EVENT_SETTINGS_DISCIPLINE_ON_SUPERSEDED_CATALOGUE
    -- What it does: Finds events filed under the older of the two discipline catalogues the sport keeps for the same events.
    CASE
        -- Two states and two repairs. Where the sport also holds the same discipline under its
        -- current name, the event has somewhere to be repointed and the row names it. Where it
        -- does not, nobody can repoint anything and the catalogue decision has to be made first.
        WHEN x.twin_discipline_id IS NOT NULL THEN 'Superseded_Discipline_With_A_Current_Twin'
        ELSE 'Superseded_Discipline_With_No_Current_Twin'
    END AS check_type,
    x.event_id,
    x.event_name,
    x.event_startdate,
    x.discipline_id,
    x.discipline_name,
    x.twin_discipline_id,
    x.twin_discipline_name,
    x.twin_events_in_same_template,
    x.template_name,
    x.tournament_name,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: Swimming keeps two discipline catalogues for the same races.
-- One names them `Freestyle 100 metres` and the other `Freestyle 100m`, and both are in use.
-- This finds every event still filed under the first.
-- **The two catalogues are not a legacy and a successor.** Measured 2026-08-25 the `metres`
-- disciplines carry ids 38 to 62 and were last touched in December 2008; the `m` disciplines
-- carry ids 348 to 374 and were last touched in 2025. That reads like an abandoned convention
-- until the events are counted: 374 events sit on the `metres` ids, the earliest in 2004 and
-- the latest in 2026, and they are still arriving. Twenty-five `metres` disciplines exist and
-- twenty-three of them have an exact equivalent under the current names; fourteen carry events.
-- **What makes it a defect rather than an untidy catalogue is that one template uses both.**
-- Twenty-three template-and-discipline pairs hold events on each id at once. World
-- Championships Long Course files 5 events on `56 Freestyle 4 x 100 metres` and 28 on
-- `365 Freestyle 4 x 100m`; Commonwealth Games files 15 on `54 Individual Medley 200 metres`
-- and 8 on `353 Indv. Medley 200m`, which is one competition split almost in half. Anything
-- grouping by discipline - a Comp.Rank, a season table, a record list - sees two competitions
-- where the meet ran one.
-- **The twin is derived rather than listed**, so a discipline added to either catalogue is
-- picked up without editing this statement. Two substitutions turn a `metres` name into its
-- current form: ` metres` becomes `m`, and `Individual Medley` becomes `Indv. Medley`, which is
-- the one place the two catalogues disagree on more than the unit. Measured 2026-08-25 that
-- pairs twenty-three of the twenty-five; the two it does not pair are
-- `59 Freestyle 100 metres handicap` and `60 Freestyle 50 metres handicap`, which have no
-- equivalent because the sport no longer contests a handicap race, and neither holds an event.
-- **The 200-row gate.** This returns 374 rows, and they were run and read before the CheckID
-- was assigned. None of the 374 is the sport behaving normally: every one sits on a discipline
-- the sport also keeps under a second id, and the template splits above are what settles it.
-- The check does not say which catalogue is the right one. That is a decision for the people who
-- own the catalogue, and if it goes the other way this statement is the one that gets inverted -
-- but either way the events cannot stay on both.
-- **The decision was made on 2026-08-27 and it goes this way**: the current `m` catalogue is
-- canonical and the `metres` one folds into it, for all fourteen disciplines carrying events and
-- not only for the relays. This statement is not inverted, and every one of its 374 findings is
-- a row of one repair list. The three relays are 307 of them - 152 on 57 Medley 4 x 100 metres,
-- 106 on 56 Freestyle 4 x 100 metres, 49 on 58 Freestyle 4 x 200 metres - and the other 67 sit
-- on eleven individual disciplines, led by 31 on 54 Individual Medley 200 metres and 20 on
-- 55 Individual Medley 400 metres.
-- Measured the same day, every one of the 374 carries a current twin: the
-- Superseded_Discipline_With_No_Current_Twin branch returns nothing, so the decision leaves no
-- row without somewhere to go and the second verdict is a sentinel for a state the sport is not
-- in today.
-- Not `GLOBAL-DQ-015`'s question: these references resolve, and they resolve to a discipline of
-- this sport. Not `GLOBAL-DQ-082`'s either - that one asks whether a stage's events disagree
-- with each other, and a stage filed entirely on the older catalogue agrees with itself.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        d.id AS discipline_id,
        d.name AS discipline_name,
        d2.id AS twin_discipline_id,
        d2.name AS twin_discipline_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        -- How many events of the same meet are already on the current id. A number above zero is
        -- the sharp case: one template, one discipline, two ids, and the competition split.
        (SELECT COUNT(DISTINCT e2.id)
           FROM event e2
           JOIN tournament_stage ts2 ON ts2.id = e2.tournament_stageFK AND ts2.del = 'no'
           JOIN tournament t2 ON t2.id = ts2.tournamentFK AND t2.del = 'no'
           JOIN object_discipline od2 ON od2.object_typeFK = 5 AND od2.objectFK = e2.id AND od2.del = 'no'
          WHERE e2.del = 'no'
            AND t2.tournament_templateFK = t.tournament_templateFK
            AND od2.disciplineFK = d2.id
        ) AS twin_events_in_same_template
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = 46
    JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
    JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
    LEFT JOIN discipline d2
           ON d2.sportFK = d.sportFK
          AND d2.del = 'no'
          AND d2.id <> d.id
          AND d2.name = REPLACE(REPLACE(d.name, 'Individual Medley', 'Indv. Medley'), ' metres', 'm')
    WHERE e.del = 'no'
      AND d.name LIKE '% metres%'
      AND t.tournament_templateFK NOT IN (10470, 12788, 12791, 12792, 12797, 12799)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
) x

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
-- The eligible population is every event of the sport carrying a discipline at all. An event
-- with no discipline cannot be on either catalogue, and is `GLOBAL-DQ-015`'s finding.
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 46
JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
JOIN discipline d ON d.id = od.disciplineFK AND d.del = 'no'
WHERE e.del = 'no'
  AND t.tournament_templateFK NOT IN (10470, 12788, 12791, 12792, 12797, 12799)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, twin_events_in_same_template DESC, event_startdate DESC, event_id;

-- ==============================================================================

SELECT
    -- CheckID - Swimming-DQ-087
    -- Name - EVENT_RESULTS_PROVISIONAL_QUALIFICATION_LEFT_UNSETTLED
    -- What it does: Finds swimmers still marked with a provisional qualification in a meet whose swim-off for that very discipline was swum.
    'Provisional_Qualification_Left_Unsettled' AS check_type,
    y.event_id,
    y.event_name,
    y.event_startdate,
    y.round_type_name,
    y.discipline_id,
    y.discipline_name,
    y.swimmers_marked,
    y.sample_swimmers,
    y.swim_off_events,
    y.template_name,
    y.tournament_name,
    NULL AS eligible_count,
    0 AS sort_order
-- What it does, stated in full: `?` is this sport's provisional qualification. SPORTS/Swimming.md
-- records what it marks: on a heats summary it is written at place eight and nowhere else, the
-- last place that reaches the final, so it says the record never settled who took that place. The
-- sport settles such a place in a Swim-Off, round types 223 and 224.
-- **This does not report the marker. It reports the marker surviving its own answer.** For every
-- row it finds, the meet ran a Swim-Off in the same discipline, so the thing that would have
-- settled the question was swum and the row was never updated. A provisional value is legitimate
-- while it is provisional; what makes these a defect is that they are not.
-- Measured 2026-08-27 the coincidence is total: all 56 `?` rows in the sport sit in a tournament
-- that held a Swim-Off in that row's own discipline, 56 of 56. They run from 2007-11-09 to
-- 2025-10-18, thirty-nine of them between 2007 and 2011 and the rest a thin tail, so this is an
-- old habit that never quite stopped rather than a current one.
-- **`R?` is deliberately not read.** Decided 2026-08-27: it is the provisional reserve marker and
-- a live convention rather than a residue - it appears first in 2022 and grows, 1 then 12 then 28
-- - and 29 of its 41 rows sit in a meet that held no Swim-Off in their discipline at all, so
-- most of them have nothing to be settled against. Reading it here would report a marker doing
-- its job.
-- The audited object is the event and the swimmers are named in a column, because one heats
-- summary can carry more than one unsettled place and the repair is made once per event.
-- Not `Swimming-DQ-039`'s question. `GLOBAL-DQ-052` reports `?` for being outside the comment
-- vocabulary, which is true of every one of them and says nothing about whether it was answered.
-- Not `Swimming-DQ-084`'s either: that one asks whether a `Q` was honoured by a later round, and
-- a `?` is not a `Q`.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate AS event_startdate,
        rt.name AS round_type_name,
        od.disciplineFK AS discipline_id,
        d.name AS discipline_name,
        tt.name AS template_name,
        t.name AS tournament_name,
        COUNT(DISTINCT ep.id) AS swimmers_marked,
        SUBSTRING(GROUP_CONCAT(DISTINCT CONCAT(p.name, ' (', COALESCE(rk.value, 'no place'), ')')
            ORDER BY p.name SEPARATOR ' | '), 1, 300) AS sample_swimmers,
        (SELECT COUNT(DISTINCT e2.id)
           FROM tournament_stage ts2
           JOIN event e2 ON e2.tournament_stageFK = ts2.id AND e2.del = 'no'
                        AND e2.round_typeFK IN (223, 224)
           JOIN object_discipline od2 ON od2.object_typeFK = 5 AND od2.objectFK = e2.id
                                     AND od2.del = 'no'
          WHERE ts2.tournamentFK = t.id AND ts2.del = 'no'
            AND od2.disciplineFK = od.disciplineFK) AS swim_off_events
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = 46
    JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
    JOIN discipline d ON d.id = od.disciplineFK
    LEFT JOIN round_type rt ON rt.id = e.round_typeFK
    JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
    JOIN participant p ON p.id = ep.participantFK AND p.del = 'no'
    JOIN result cm ON cm.event_participantsFK = ep.id AND cm.del = 'no'
                  AND cm.result_typeFK = 104 AND cm.value = '?'
    LEFT JOIN result rk ON rk.event_participantsFK = ep.id AND rk.del = 'no'
                       AND rk.result_typeFK = 100
    WHERE e.del = 'no'
      AND t.tournament_templateFK NOT IN (10470, 12788, 12791, 12792, 12797, 12799)
      AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
      -- AND t.tournament_templateFK = <tournament_template_id>
      -- AND e.startdate >= '<from_datetime>'
      -- AND e.startdate <  '<to_datetime>'
    GROUP BY e.id, e.name, e.startdate, rt.name, od.disciplineFK, d.name, tt.name, t.name, t.id
) y
WHERE y.swim_off_events > 0

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT e.id) AS eligible_count,
    1 AS sort_order
-- The eligible population is every event carrying the provisional qualification marker at all.
-- An event that never wrote a `?` has no question left open on it, and the coverage count is
-- therefore what says how many of the marked events had their answer swum.
FROM event e
JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
     AND tt.sportFK = 46
JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
JOIN event_participants ep ON ep.eventFK = e.id AND ep.del = 'no'
JOIN result cm ON cm.event_participantsFK = ep.id AND cm.del = 'no'
              AND cm.result_typeFK = 104 AND cm.value = '?'
WHERE e.del = 'no'
  AND t.tournament_templateFK NOT IN (10470, 12788, 12791, 12792, 12797, 12799)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, swimmers_marked DESC, event_startdate DESC, event_id;
