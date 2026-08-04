SELECT
    -- CheckID - Artistic-Gymnastics-DQ-029
    -- Name - TOURNAMENT_NAME_SEASON_CONTRADICTS_DATES
    -- What it does: Finds active Artistic Gymnastics tournaments, excluding IOC-purpose templates and the two confirmed postponed Summer Olympics 2020 editions, whose name disagrees with the calendar years their own tournament stages occupy, separating the five contradiction shapes, with stage-year and template context and a coverage count of the identical eligible tournament scope.
    CASE
        WHEN x.stage_span > 2 THEN 'STAGES_SPAN_MORE_THAN_TWO_YEARS'
        WHEN x.stage_span = 2 AND x.name_has_span = 0 THEN 'SINGLE_YEAR_NAME_ON_SEASON'
        WHEN x.stage_span = 2 THEN 'NAME_SPAN_DOES_NOT_MATCH_STAGE_YEARS'
        WHEN x.name_has_span = 1 THEN 'SEASON_NAME_ON_SINGLE_YEAR'
        ELSE 'NAME_YEAR_MATCHES_NO_STAGE'
    END AS check_type,
    x.tournament_id,
    x.tournament_name,
    x.template_name,
    x.first_stage_year,
    x.last_stage_year,
    x.stage_span,
    x.stages,
    NULL AS eligible_count,
    0 AS sort_order
FROM (
    SELECT
        t.id AS tournament_id,
        t.name AS tournament_name,
        tt.name AS template_name,
        COUNT(DISTINCT ts.id) AS stages,
        MIN(YEAR(ts.startdate)) AS first_stage_year,
        MAX(YEAR(COALESCE(ts.enddate, ts.startdate))) AS last_stage_year,
        MAX(YEAR(COALESCE(ts.enddate, ts.startdate))) - MIN(YEAR(ts.startdate)) + 1 AS stage_span,
        (t.name REGEXP '[12][0-9][0-9][0-9]') AS name_has_year,
        (t.name REGEXP '[12][0-9][0-9][0-9][/-]([12][0-9][0-9][0-9]|[0-9][0-9])') AS name_has_span
    FROM tournament t
    JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
    JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
     AND ts.startdate IS NOT NULL
    WHERE t.del = 'no'
      AND tt.sportFK = 40
      AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
      AND t.id NOT IN (14678, 36693)
      -- AND tt.id = <tournament_template_id>
    GROUP BY t.id, t.name, tt.name
) x
WHERE x.stage_span > 2
   OR (
        x.name_has_year = 1
        AND (
            (x.stage_span = 2 AND (
                x.name_has_span = 0
                OR x.tournament_name NOT LIKE CONCAT('%', x.first_stage_year, '%')
                OR x.tournament_name NOT LIKE CONCAT('%', x.last_stage_year, '%')
            ))
            OR (x.stage_span = 1 AND (
                x.name_has_span = 1
                OR x.tournament_name NOT LIKE CONCAT('%', x.first_stage_year, '%')
            ))
        )
      )

UNION ALL

SELECT
    'COVERAGE' AS check_type,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    COUNT(DISTINCT t.id) AS eligible_count,
    1 AS sort_order
FROM tournament t
JOIN tournament_template tt ON tt.id = t.tournament_templateFK AND tt.del = 'no'
JOIN tournament_stage ts ON ts.tournamentFK = t.id AND ts.del = 'no'
 AND ts.startdate IS NOT NULL
WHERE t.del = 'no'
  AND tt.sportFK = 40
  AND (tt.name IS NULL OR tt.name NOT LIKE '%(IOC)%')
  AND t.id NOT IN (14678, 36693)
  -- AND tt.id = <tournament_template_id>

ORDER BY sort_order, first_stage_year;
