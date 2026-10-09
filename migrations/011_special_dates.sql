-- 011_special_dates.sql  (DB maite_flames_kohsamui)
-- Días especiales (fase 1). Una fila por (día, tipo):
--   gala        → cena de evento con menú cerrado; booking_policy 'team_only': el chat NO reserva mesa normal ese día,
--                 presenta el evento y deriva al equipo (depósito). create_reservation devuelve 'team_only_event'.
--   high_demand → noche muy solicitada; se reserva normal, el agente lo menciona (reservar pronto, terraza).
--   no_alcohol  → festivo budista: prohibida la venta de alcohol; el agente avisa y no sugiere bebidas con alcohol.
-- Textos en inglés (el agente traduce). price_note solo se dice si el huésped pregunta. is_example = datos de DEMO
-- (Talay Cliff es ficticio): galas y precios inventados; se asume que Flames NO está exento de la ley de alcohol.
-- Funciones: flames_special(fecha) jsonb, flames_team_only(fecha) bool; flames_alternatives ya no propone días team_only.
-- Fuentes de fechas: calendario oficial de festivos de Tailandia 2026-2027 (ver CHANGELOG 2026-10-01).
--
-- ROLLBACK:
--   BEGIN;
--   DROP FUNCTION IF EXISTS flames_special(date); DROP FUNCTION IF EXISTS flames_team_only(date);
--   (re-crear flames_alternatives de la migración 010)
--   DROP TABLE IF EXISTS special_dates;
--   COMMIT;

BEGIN;

CREATE TABLE IF NOT EXISTS special_dates (
  day             date NOT NULL,
  kind            text NOT NULL CHECK (kind IN ('gala', 'high_demand', 'no_alcohol')),
  title           text NOT NULL,
  details         text,
  booking_policy  text NOT NULL DEFAULT 'normal' CHECK (booking_policy IN ('normal', 'team_only')),
  deposit_required boolean NOT NULL DEFAULT false,
  price_note      text,
  guest_note      text,
  is_example      boolean NOT NULL DEFAULT true,
  updated_at      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (day, kind)
);
ALTER TABLE special_dates OWNER TO flames_kohsamui;

INSERT INTO special_dates (day, kind, title, details, booking_policy, deposit_required, price_note, guest_note) VALUES
('2026-10-26', 'no_alcohol', 'Ok Phansa (end of Buddhist Lent)', 'Buddhist holy day: by Thai law no alcohol may be sold.', 'normal', false, NULL,
 'The restaurant is open as usual but serves no alcohol that day; the zero-proof list is available.'),
('2026-11-24', 'high_demand', 'Loy Krathong', 'Full-moon festival: krathongs are floated on the sea at the beach in the evening.', 'normal', false, NULL,
 'One of the most special nights of the year; the terrace fills early, so booking ahead is recommended.'),
('2026-12-24', 'gala', 'Christmas Eve Gala Dinner', '7-course festive set menu, single seating at 19:00, live music. No à la carte that evening.', 'team_only', true,
 'THB 6,500++ per adult (example)', 'Places are reserved through the Flames team, with a deposit.'),
('2026-12-25', 'high_demand', 'Christmas Day', 'Regular à la carte dinner; very high demand.', 'normal', false, NULL,
 'A very popular evening; booking ahead is recommended.'),
('2026-12-31', 'gala', 'New Year''s Eve Gala Dinner', '9-course set menu, single seating at 19:30, countdown on the terrace. No à la carte that evening.', 'team_only', true,
 'THB 9,500++ per adult (example)', 'Places are reserved through the Flames team, with a deposit.'),
('2027-01-01', 'high_demand', 'New Year''s Day', 'Regular dinner; high demand.', 'normal', false, NULL, 'Booking ahead is recommended.'),
('2027-02-06', 'high_demand', 'Chinese New Year', 'Regular dinner; many guests celebrating.', 'normal', false, NULL, 'Booking ahead is recommended.'),
('2027-02-14', 'high_demand', 'Valentine''s Day', 'Regular à la carte dinner; mostly couples.', 'normal', false, NULL,
 'Terrace tables at sunset go first; booking ahead is recommended.'),
('2027-02-21', 'no_alcohol', 'Makha Bucha', 'Buddhist holy day: by Thai law no alcohol may be sold.', 'normal', false, NULL,
 'The restaurant is open as usual but serves no alcohol that day; the zero-proof list is available.'),
('2027-04-13', 'high_demand', 'Songkran (Thai New Year)', 'Thai New Year water festival; very busy week on the island.', 'normal', false, NULL, 'Booking ahead is recommended.'),
('2027-04-14', 'high_demand', 'Songkran (Thai New Year)', 'Thai New Year water festival; very busy week on the island.', 'normal', false, NULL, 'Booking ahead is recommended.'),
('2027-04-15', 'high_demand', 'Songkran (Thai New Year)', 'Thai New Year water festival; very busy week on the island.', 'normal', false, NULL, 'Booking ahead is recommended.')
ON CONFLICT (day, kind) DO NOTHING;

CREATE OR REPLACE FUNCTION flames_special(p_date date) RETURNS jsonb
LANGUAGE sql STABLE AS $$
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'kind', kind, 'title', title, 'details', details, 'booking_policy', booking_policy,
           'deposit_required', deposit_required, 'price_note', price_note, 'guest_note', guest_note)
         ORDER BY kind), '[]'::jsonb)
  FROM special_dates WHERE day = p_date
$$;

CREATE OR REPLACE FUNCTION flames_team_only(p_date date) RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT EXISTS (SELECT 1 FROM special_dates WHERE day = p_date AND booking_policy = 'team_only')
$$;

-- Igual que en 010, pero sin proponer nunca un día que solo se reserva a través del equipo.
CREATE OR REPLACE FUNCTION flames_alternatives(p_date date, p_time time, p_people int) RETURNS jsonb
LANGUAGE sql STABLE AS $$
  WITH cfg AS (
    SELECT capacity, max_reservation_days_ahead AS w, opening_hours
    FROM restaurant_config WHERE internal_id = 'maite_flames_kohsamui'
  ),
  now_bkk AS (SELECT (NOW() AT TIME ZONE 'Asia/Bangkok')::timestamp AS n),
  days AS (SELECT p_date AS d, 0 AS k UNION ALL SELECT p_date + 1, 1 UNION ALL SELECT p_date + 2, 2),
  hours AS (
    SELECT days.d, days.k, (oh->>'open')::time AS open_t, (oh->>'close')::time AS close_t
    FROM days, cfg,
         LATERAL (SELECT oh FROM jsonb_array_elements(cfg.opening_hours ->
                    (ARRAY['sunday','monday','tuesday','wednesday','thursday','friday','saturday'])[EXTRACT(DOW FROM days.d)::int + 1]) oh
                  ORDER BY (oh->>'open')::time LIMIT 1) x
  ),
  cand AS (
    SELECT h.d, h.k, t::time AS t
    FROM hours h, LATERAL generate_series(h.d + h.open_t, h.d + h.close_t - INTERVAL '30 minutes', INTERVAL '30 minutes') t
    WHERE ((h.k = 0 AND t::time <> p_time) OR (h.k > 0 AND t::time = p_time))
      AND NOT flames_team_only(h.d)
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

ALTER FUNCTION flames_special(date) OWNER TO flames_kohsamui;
ALTER FUNCTION flames_team_only(date) OWNER TO flames_kohsamui;
ALTER FUNCTION flames_alternatives(date, time, int) OWNER TO flames_kohsamui;

COMMIT;
