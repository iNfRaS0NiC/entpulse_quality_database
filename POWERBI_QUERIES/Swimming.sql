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
-- the relays with 468 and 479 as individual twins, and a current set abbreviating it, 365 to
-- 367 - and each vocabulary carries its own way of naming the event. The older
-- ids put the distance first, 4x100m Freestyle Relay; the current ids put it last, Freestyle
-- 4 x 100m. Distance-first is read literally, as a name beginning with a digit. Measured that
-- way on 2026-08-20 the pairing is almost total on the older side, 373 events against 1, and
-- clearly the habit on the current side, 1807 against 91.
-- What this statement reports is the residue where the two halves of that signature disagree,
-- and its signal is Monitor: the proportion is the finding and no single row is a defect. A
-- reviewer driving it to zero would be renaming events to match a convention nobody has
-- declared, which is why the sport file records the count rather than a target. What the
-- residue is worth is that it marks where one of the two halves was corrected and the other was
-- not, so it is the shortest description available of how far a half-finished cleanup got.
-- The reason it matters at all is downstream and is stated in SPORTS/Swimming.md: a Comp.Rank
-- grouped by disciplineFK will split one competition's relay across two rankings from one
-- edition to the next, because the edition and not the event chooses the vocabulary. Until that
-- is settled this is the measurement of how large the split will be.
-- Only the eight discipline ids where the signature was confirmed are read, and the confirmation
-- is what limits them to the relays. 351 and 362, the current-vocabulary twins of 468 and 479,
-- are deliberately not among them: SPORTS/Swimming.md records that those two are written both
-- ways, so neither spelling is the wrong one there. Including them was tried and rejected on
-- 2026-08-20 - it took the output from 92 rows to 2438, because for an individual event
-- 800m Freestyle is simply how the sport writes the name and carries no vocabulary signal at
-- all. Every other discipline is silent here for the same reason.
FROM (
    SELECT
        e.id AS event_id,
        e.name AS event_name,
        e.startdate,
        tt.name AS template_name,
        od.disciplineFK AS discipline_id,
        d.name AS discipline_name,
        CASE WHEN od.disciplineFK IN (56, 57, 58, 468, 479) THEN 'older' ELSE 'current' END AS discipline_vocabulary,
        CASE WHEN e.name REGEXP '^[0-9]' THEN 'distance-first' ELSE 'distance-last' END AS naming_convention
    FROM event e
    JOIN tournament_stage ts ON ts.id = e.tournament_stageFK AND ts.del = 'no'
    JOIN tournament t ON t.id = ts.tournamentFK AND t.del = 'no'
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
         AND tt.sportFK = 46
    JOIN object_discipline od ON od.object_typeFK = 5 AND od.objectFK = e.id AND od.del = 'no'
         AND od.disciplineFK IN (56, 57, 58, 468, 479, 365, 366, 367)
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
     AND od.disciplineFK IN (56, 57, 58, 468, 479, 365, 366, 367)
WHERE e.del = 'no'
  AND t.tournament_templateFK NOT IN (10470, 12788, 12791, 12792, 12797, 12799)
  AND CAST(COALESCE(NULLIF(REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 2), ''), REGEXP_SUBSTR(t.name, '(19|20)[0-9]{2}', 1, 1)) AS UNSIGNED) >= 2004
  -- AND t.tournament_templateFK = <tournament_template_id>
  -- AND e.startdate >= '<from_datetime>'
  -- AND e.startdate <  '<to_datetime>'

ORDER BY sort_order, event_id;
