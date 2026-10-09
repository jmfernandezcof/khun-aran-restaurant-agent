-- Calendar reference for the agent prompt: for each month in the booking window (Asia/Bangkok), the day numbers of
-- every weekday. The model reads dates from here instead of computing them. Months are always complete (a partial
-- month would give a wrong 'last Thursday'). The window comes from restaurant_config.max_reservation_days_ahead
-- (fallback 90), the same value the tools enforce, so changing it there keeps prompt and tools in sync.
-- Also lists special_dates (migration 011) in the displayed months, with [GALA]/[HIGH DEMAND]/[NO ALCOHOL] tags.
-- Returns one row with calendar_text. Used by the "Load Menu" node of TNMHHaKWEoO0rLhf (column calendar_text).
WITH t AS (
  SELECT (now() AT TIME ZONE 'Asia/Bangkok')::date AS d,
         COALESCE((SELECT max_reservation_days_ahead FROM restaurant_config LIMIT 1), 90)::int AS w
),
days AS (
  SELECT g::date AS day
  FROM t, generate_series(date_trunc('month', t.d), date_trunc('month', t.d + t.w) + INTERVAL '1 month - 1 day', INTERVAL '1 day') g
),
wd AS (
  SELECT date_trunc('month', day) AS m, extract(isodow FROM day)::int AS dow, to_char(day, 'FMDy') AS dname,
         string_agg(extract(day FROM day)::int::text, ', ' ORDER BY day) AS nums
  FROM days GROUP BY 1, 2, 3
),
months AS (
  SELECT m, to_char(m, 'FMMonth YYYY') || ': ' || string_agg(dname || ' ' || nums, ' | ' ORDER BY dow) AS line
  FROM wd GROUP BY m
)
SELECT concat_ws(E'\n',
  '# Calendar (weekday -> day numbers; read dates from here, never work them out yourself)',
  'Today is ' || (SELECT to_char(d, 'FMDay FMDD FMMonth YYYY') FROM t) || ' (Asia/Bangkok).',
  'Table bookings open ' || (SELECT w FROM t) || ' days ahead: the last bookable date today is '
    || (SELECT to_char(d + w, 'FMDay FMDD FMMonth YYYY') FROM t) || '.',
  (SELECT string_agg(line, E'\n' ORDER BY m) FROM months),
  'Special dates (details come from check_availability.special): ' || COALESCE((
    SELECT string_agg(to_char(sd.day, 'FMDay FMDD FMMonth YYYY') || ' [' || upper(replace(sd.kind, '_', ' ')) || '] ' || sd.title
                      || CASE WHEN sd.booking_policy = 'team_only' THEN ' (bookings through the team only)' ELSE '' END, '; ' ORDER BY sd.day, sd.kind)
    FROM special_dates sd, t
    WHERE sd.day BETWEEN t.d AND (date_trunc('month', t.d + t.w) + INTERVAL '1 month - 1 day')::date), 'none') || '.'
) AS calendar_text;
