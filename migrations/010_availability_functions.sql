-- 010_availability_functions.sql  (DB maite_flames_kohsamui)
-- Una sola lógica de disponibilidad para check_availability y create_reservation (antes cada query tenía la suya).
--
-- flames_max_seated(fecha, hora): máximo de comensales sentados A LA VEZ durante la franja pedida
--   [hora, hora + reservation_slot_minutes). Antes se sumaban TODAS las reservas que se solapaban con la franja aunque
--   nunca coincidieran entre sí (40 a las 19:00 + 40 a las 21:00 = "80, lleno" para las 20:00, cuando nunca hay más de
--   40 sentados): falso "completo". La ocupación solo sube cuando empieza una reserva, así que basta con evaluarla en el
--   inicio de la franja y en cada inicio de reserva dentro de ella. Cuenta 'confirmed' y 'pending'.
-- flames_alternatives(fecha, hora, personas): jsonb con hasta 3 horas libres ese día (las más cercanas; turnos cada 30 min
--   dentro del horario) y la misma hora los 2 días siguientes si están libres. Respeta horario, pasado y ventana de reserva.
--   El agente solo puede ofrecer estas alternativas (nunca las calcula él).
--
-- ROLLBACK:
--   DROP FUNCTION IF EXISTS flames_alternatives(date, time, int);
--   DROP FUNCTION IF EXISTS flames_max_seated(date, time);
--   (y restaurar las queries pre de check_availability / create_reservation)

BEGIN;

CREATE OR REPLACE FUNCTION flames_max_seated(p_date date, p_time time) RETURNS int
LANGUAGE sql STABLE AS $$
  WITH cfg AS (
    SELECT (reservation_slot_minutes::int * INTERVAL '1 minute') AS slot
    FROM restaurant_config WHERE internal_id = 'maite_flames_kohsamui'
  ),
  req AS (SELECT (p_date + p_time)::timestamp AS s, (p_date + p_time)::timestamp + (SELECT slot FROM cfg) AS e),
  res AS (
    SELECT (r.reservation_date + r.reservation_time)::timestamp AS s,
           (r.reservation_date + r.reservation_time)::timestamp + (SELECT slot FROM cfg) AS e, r.people
    FROM reservations r
    WHERE r.reservation_date BETWEEN p_date - 1 AND p_date AND r.status IN ('confirmed', 'pending')
  ),
  pts AS (
    SELECT s AS pt FROM req
    UNION SELECT res.s FROM res, req WHERE res.s > req.s AND res.s < req.e
  )
  SELECT COALESCE(MAX((SELECT COALESCE(SUM(res.people), 0) FROM res WHERE res.s <= pts.pt AND pts.pt < res.e)), 0)::int
  FROM pts
$$;

CREATE OR REPLACE FUNCTION flames_alternatives(p_date date, p_time time, p_people int) RETURNS jsonb
LANGUAGE sql STABLE AS $$
  WITH cfg AS (
    SELECT capacity, max_reservation_days_ahead AS w, opening_hours
    FROM restaurant_config WHERE internal_id = 'maite_flames_kohsamui'
  ),
  now_bkk AS (SELECT (NOW() AT TIME ZONE 'Asia/Bangkok')::timestamp AS n),
  days AS (SELECT p_date AS d, 0 AS k UNION ALL SELECT p_date + 1, 1 UNION ALL SELECT p_date + 2, 2),
  hours AS (   -- primer tramo de apertura de cada día (igual que las tools)
    SELECT days.d, days.k, (oh->>'open')::time AS open_t, (oh->>'close')::time AS close_t
    FROM days, cfg,
         LATERAL (SELECT oh FROM jsonb_array_elements(cfg.opening_hours ->
                    (ARRAY['sunday','monday','tuesday','wednesday','thursday','friday','saturday'])[EXTRACT(DOW FROM days.d)::int + 1]) oh
                  ORDER BY (oh->>'open')::time LIMIT 1) x
  ),
  cand AS (
    SELECT h.d, h.k, t::time AS t
    FROM hours h, LATERAL generate_series(h.d + h.open_t, h.d + h.close_t - INTERVAL '30 minutes', INTERVAL '30 minutes') t
    WHERE (h.k = 0 AND t::time <> p_time) OR (h.k > 0 AND t::time = p_time)
  ),
  ok AS (
    SELECT c.* FROM cand c, cfg, now_bkk
    WHERE (c.d + c.t) >= now_bkk.n
      AND c.d <= now_bkk.n::date + cfg.w
      AND cfg.capacity - flames_max_seated(c.d, c.t) >= p_people
  ),
  pick AS (
    (SELECT d, t, 0 AS grp, abs(extract(epoch FROM (t - p_time))) AS dist FROM ok WHERE k = 0 ORDER BY dist, t LIMIT 3)
    UNION ALL
    (SELECT d, t, 1, k FROM ok WHERE k > 0 ORDER BY k)
  )
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'date', d::text, 'time', to_char(t, 'HH24:MI'), 'date_label', to_char(d, 'FMDay FMDD FMMonth YYYY'))
         ORDER BY grp, d, t), '[]'::jsonb)
  FROM pick
$$;

ALTER FUNCTION flames_max_seated(date, time) OWNER TO flames_kohsamui;
ALTER FUNCTION flames_alternatives(date, time, int) OWNER TO flames_kohsamui;

COMMIT;
