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
