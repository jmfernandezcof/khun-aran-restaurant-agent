-- seed_october.sql  (DB maite_flames_kohsamui) — carga de prueba de octubre 2026 para validar la disponibilidad.
-- SOLO Postgres (la disponibilidad se calcula únicamente con la tabla reservations); NO crea eventos en Google Calendar.
-- Todo va marcado: reservations.channel = 'loadtest', códigos FLM-T0001…, cliente channel = 'loadtest'.
-- Borrado: data/loadtest/cleanup_october.sql
--
-- Fondo (días sin escenario): entre semana 19:00/20:00/21:00 con 2 mesas de 2-4; vie/sáb 18:30/19:30/20:30/21:30 con
-- 3 mesas de 2-6 (nunca supera la capacidad en ninguna franja). Determinista (setseed) para que sea repetible.
-- Escenarios (resultado esperado en data/loadtest/expected_october.csv):
--   sáb 10  lleno exacto 20:00 (80)        | jue 15  80 cancelados a las 20:00 (no cuentan)
--   vie 16  80 pendientes a las 20:00       | sáb 17  79 a las 20:00 (queda 1 plaza)
--   sáb 24  40 a las 19:00 + 40 a las 21:00 (nunca más de 40 a la vez)
--   sáb 31  lleno toda la noche: 80 a las 18:00, 80 a las 20:00, 80 a las 22:00

BEGIN;
SELECT setseed(0.20261001);

INSERT INTO customers (channel, channel_user_id, name, surname, pdpa_consent, pdpa_consent_at)
VALUES ('loadtest', 'loadtest:seed', 'LOADTEST', 'Octubre', true, now());

CREATE TEMP TABLE lt (d date, t time, people int, status text) ON COMMIT DROP;

-- Fondo
INSERT INTO lt
SELECT d::date, s::time, 2 + floor(random() * (CASE WHEN extract(isodow FROM d) IN (5,6) THEN 5 ELSE 3 END))::int, 'confirmed'
FROM generate_series('2026-10-02'::date, '2026-10-31'::date, '1 day') d
CROSS JOIN LATERAL unnest(CASE WHEN extract(isodow FROM d) IN (5,6)
                               THEN ARRAY['18:30','19:30','20:30','21:30'] ELSE ARRAY['19:00','20:00','21:00'] END) s
CROSS JOIN LATERAL generate_series(1, CASE WHEN extract(isodow FROM d) IN (5,6) THEN 3 ELSE 2 END) n
WHERE d::date NOT IN ('2026-10-10','2026-10-15','2026-10-16','2026-10-17','2026-10-24','2026-10-31');

-- Escenarios (mesas de 4 salvo ajustes)
INSERT INTO lt SELECT '2026-10-10', '20:00', 4, 'confirmed'  FROM generate_series(1,20);              -- 80
INSERT INTO lt SELECT '2026-10-15', '20:00', 4, 'cancelled'  FROM generate_series(1,20);              -- 80 cancelados
INSERT INTO lt SELECT '2026-10-16', '20:00', 4, 'pending'    FROM generate_series(1,20);              -- 80 pendientes
INSERT INTO lt SELECT '2026-10-17', '20:00', 4, 'confirmed'  FROM generate_series(1,19);              -- 76
INSERT INTO lt VALUES ('2026-10-17', '20:00', 3, 'confirmed');                                         -- +3 = 79
INSERT INTO lt SELECT '2026-10-24', '19:00', 4, 'confirmed'  FROM generate_series(1,10);              -- 40
INSERT INTO lt SELECT '2026-10-24', '21:00', 4, 'confirmed'  FROM generate_series(1,10);              -- 40
INSERT INTO lt SELECT '2026-10-31', s::time, 4, 'confirmed'
  FROM unnest(ARRAY['18:00','20:00','22:00']) s CROSS JOIN generate_series(1,20);                     -- 3 x 80

INSERT INTO reservations (customer_id, channel, reservation_date, reservation_time, people, status, special_requests, confirmation_code)
SELECT (SELECT customer_id FROM customers WHERE channel = 'loadtest' AND channel_user_id = 'loadtest:seed'),
       'loadtest', d, t, people, status, 'LOADTEST', 'FLM-T' || lpad((row_number() OVER (ORDER BY d, t, status))::text, 4, '0')
FROM lt;

SELECT count(*) AS reservas_loadtest, sum(people) AS personas, min(reservation_date) AS desde, max(reservation_date) AS hasta
FROM reservations WHERE channel = 'loadtest';
COMMIT;
