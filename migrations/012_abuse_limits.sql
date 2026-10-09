-- 012_abuse_limits.sql  (DB maite_flames_kohsamui)
-- Límites anti-abuso (auditoría de seguridad 2026-10-01). Un atacante podía llenar el restaurante con reservas falsas
-- por el chat o usar las confirmaciones por email para bombardear a un tercero desde la cuenta del restaurante.
-- Límites configurables por restaurante (restaurant_config):
--   max_party_online              grupos mayores → los gestiona el equipo ('party_too_large')
--   max_active_bookings_per_phone reservas futuras activas por teléfono ('limit_reached')
--   max_web_bookings_per_hour     reservas creadas por el chat en la última hora, todas juntas ('limit_reached')
--   max_emails_per_address_per_day / max_emails_per_hour   confirmaciones por email ('rate_limited')
-- Funciones: flames_booking_guard(teléfono_normalizado, personas) y flames_email_guard(email) → 'ok' o el motivo.
--
-- ROLLBACK:
--   DROP FUNCTION IF EXISTS flames_booking_guard(text, int); DROP FUNCTION IF EXISTS flames_email_guard(text);
--   ALTER TABLE restaurant_config DROP COLUMN IF EXISTS max_party_online, DROP COLUMN IF EXISTS max_active_bookings_per_phone,
--     DROP COLUMN IF EXISTS max_web_bookings_per_hour, DROP COLUMN IF EXISTS max_emails_per_address_per_day,
--     DROP COLUMN IF EXISTS max_emails_per_hour;

BEGIN;

ALTER TABLE restaurant_config
  ADD COLUMN IF NOT EXISTS max_party_online int NOT NULL DEFAULT 12,
  ADD COLUMN IF NOT EXISTS max_active_bookings_per_phone int NOT NULL DEFAULT 3,
  ADD COLUMN IF NOT EXISTS max_web_bookings_per_hour int NOT NULL DEFAULT 10,
  ADD COLUMN IF NOT EXISTS max_emails_per_address_per_day int NOT NULL DEFAULT 2,
  ADD COLUMN IF NOT EXISTS max_emails_per_hour int NOT NULL DEFAULT 20;

CREATE OR REPLACE FUNCTION flames_booking_guard(p_phone_norm text, p_people int) RETURNS text
LANGUAGE sql STABLE AS $$
  WITH cfg AS (
    SELECT max_party_online, max_active_bookings_per_phone, max_web_bookings_per_hour
    FROM restaurant_config WHERE internal_id = 'maite_flames_kohsamui'
  )
  SELECT CASE
    WHEN p_people > (SELECT max_party_online FROM cfg) THEN 'party_too_large'
    WHEN (SELECT count(*) FROM reservations r JOIN customers c USING (customer_id)
          WHERE c.channel = 'web' AND c.channel_user_id = 'phone:' || p_phone_norm
            AND r.status IN ('confirmed', 'pending')
            AND r.reservation_date >= (NOW() AT TIME ZONE 'Asia/Bangkok')::date)
         >= (SELECT max_active_bookings_per_phone FROM cfg) THEN 'limit_reached'
    WHEN (SELECT count(*) FROM reservations
          -- created_at es timestamp SIN zona rellenado con now() en la zona de la sesión (UTC): comparar con LOCALTIMESTAMP
          WHERE channel = 'web' AND created_at > LOCALTIMESTAMP - INTERVAL '1 hour')
         >= (SELECT max_web_bookings_per_hour FROM cfg) THEN 'limit_reached'
    ELSE 'ok'
  END
$$;

CREATE OR REPLACE FUNCTION flames_email_guard(p_email text) RETURNS text
LANGUAGE sql STABLE AS $$
  WITH cfg AS (
    SELECT max_emails_per_address_per_day, max_emails_per_hour
    FROM restaurant_config WHERE internal_id = 'maite_flames_kohsamui'
  )
  SELECT CASE
    WHEN (SELECT count(*) FROM reservations
          WHERE lower(confirmation_email_to) = lower(BTRIM(p_email)) AND confirmation_email_sent_at > now() - INTERVAL '24 hours')
         >= (SELECT max_emails_per_address_per_day FROM cfg) THEN 'rate_limited'
    WHEN (SELECT count(*) FROM reservations WHERE confirmation_email_sent_at > now() - INTERVAL '1 hour')
         >= (SELECT max_emails_per_hour FROM cfg) THEN 'rate_limited'
    ELSE 'ok'
  END
$$;

ALTER FUNCTION flames_booking_guard(text, int) OWNER TO flames_kohsamui;
ALTER FUNCTION flames_email_guard(text) OWNER TO flames_kohsamui;

COMMIT;
