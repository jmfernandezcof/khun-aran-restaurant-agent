-- 013_modify_reservation.sql  (DB maite_flames_kohsamui)
-- Modificar una reserva SIN cancelarla (prueba 2026-10-01: "cancelar + crear" dejó al cliente sin reserva al pararse
-- la conversación a mitad, y perdía alergias/código/evento).
--  - flames_max_seated(fecha, hora, excluir_reserva): ocupación real sin contar la propia reserva que se mueve
--    (si no, moverla de 20:00 a 20:30 contaría su propio sitio). La versión de 2 argumentos llama a esta con NULL.
--  - restaurant_config.max_changes_per_booking_per_day (5): tope de modificaciones por reserva y día; evita usar
--    cambios repetidos para bombardear al cliente con emails de aviso.
--
-- ROLLBACK:
--   (re-crear flames_max_seated(date, time) de la migración 010)
--   DROP FUNCTION IF EXISTS flames_max_seated(date, time, int);
--   ALTER TABLE restaurant_config DROP COLUMN IF EXISTS max_changes_per_booking_per_day;

BEGIN;

ALTER TABLE restaurant_config ADD COLUMN IF NOT EXISTS max_changes_per_booking_per_day int NOT NULL DEFAULT 5;

CREATE OR REPLACE FUNCTION flames_max_seated(p_date date, p_time time, p_exclude int) RETURNS int
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
      AND (p_exclude IS NULL OR r.reservation_id <> p_exclude)
  ),
  pts AS (
    SELECT s AS pt FROM req
    UNION SELECT res.s FROM res, req WHERE res.s > req.s AND res.s < req.e
  )
  SELECT COALESCE(MAX((SELECT COALESCE(SUM(res.people), 0) FROM res WHERE res.s <= pts.pt AND pts.pt < res.e)), 0)::int
  FROM pts
$$;

CREATE OR REPLACE FUNCTION flames_max_seated(p_date date, p_time time) RETURNS int
LANGUAGE sql STABLE AS $$ SELECT flames_max_seated(p_date, p_time, NULL::int) $$;

ALTER FUNCTION flames_max_seated(date, time, int) OWNER TO flames_kohsamui;
ALTER FUNCTION flames_max_seated(date, time) OWNER TO flames_kohsamui;

COMMIT;
