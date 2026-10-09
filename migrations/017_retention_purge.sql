-- 017_retention_purge.sql  (DB maite_flames_kohsamui)
-- Retención (PDPA: "conservaremos estos datos solo el tiempo necesario"). Cada sesión del chat web crea una fila en
-- customers (nodo "Upsert Customer": solo id de sesión + idioma); al reservar, create_reservation usa otro cliente
-- 'phone:…'. Resultado 2026-10-03: 130 de 140 clientes sin reservas. maite_chat_history guarda el texto de todas las
-- conversaciones sin fecha de caducidad (y sin columna de fecha).
-- flames_purge() borra:
--   1. historial de chat más antiguo que retention_chat_days (90);
--   2. clientes de sesión web (sin teléfono, nombre, email ni consentimiento) inactivos más de
--      retention_session_customer_days (30), con su session_state; nunca si tienen filas en otra tabla que apunte a
--      customers (todas las FK son NO ACTION: un borrado así fallaría, así que se excluyen de antemano).
-- Telegram y los clientes 'phone:' (los que reservan) no se tocan.
-- Las filas de historial anteriores a esta migración reciben created_at = ahora → empiezan a contar desde hoy.
-- ROLLBACK: DROP FUNCTION IF EXISTS flames_purge(); ALTER TABLE restaurant_config DROP COLUMN IF EXISTS retention_chat_days,
--   DROP COLUMN IF EXISTS retention_session_customer_days; ALTER TABLE maite_chat_history DROP COLUMN IF EXISTS created_at;
BEGIN;
ALTER TABLE maite_chat_history ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();
CREATE INDEX IF NOT EXISTS maite_chat_history_created_at_idx ON maite_chat_history (created_at);
ALTER TABLE restaurant_config
  ADD COLUMN IF NOT EXISTS retention_chat_days int NOT NULL DEFAULT 90,
  ADD COLUMN IF NOT EXISTS retention_session_customer_days int NOT NULL DEFAULT 30;

CREATE OR REPLACE FUNCTION flames_purge() RETURNS TABLE (chat_messages_deleted int, session_customers_deleted int)
LANGUAGE plpgsql AS $$
DECLARE
  cfg record;
BEGIN
  SELECT retention_chat_days, retention_session_customer_days INTO cfg
  FROM restaurant_config WHERE internal_id = 'maite_flames_kohsamui';

  DELETE FROM maite_chat_history WHERE created_at < now() - make_interval(days => cfg.retention_chat_days);
  GET DIAGNOSTICS chat_messages_deleted = ROW_COUNT;

  CREATE TEMP TABLE IF NOT EXISTS _purge_ids (customer_id uuid) ON COMMIT DROP;
  TRUNCATE _purge_ids;
  INSERT INTO _purge_ids
  SELECT c.customer_id FROM customers c
  WHERE c.channel = 'web'
    AND c.channel_user_id NOT LIKE 'phone:%'
    AND c.phone IS NULL AND c.email IS NULL AND COALESCE(c.name, '') = ''
    AND NOT COALESCE(c.pdpa_consent, false)
    AND COALESCE(c.updated_at, c.created_at) < LOCALTIMESTAMP - make_interval(days => cfg.retention_session_customer_days)
    AND NOT EXISTS (SELECT 1 FROM reservations x      WHERE x.customer_id = c.customer_id)
    AND NOT EXISTS (SELECT 1 FROM customer_consents x WHERE x.customer_id = c.customer_id)
    AND NOT EXISTS (SELECT 1 FROM orders x            WHERE x.customer_id = c.customer_id)
    AND NOT EXISTS (SELECT 1 FROM events_bookings x   WHERE x.customer_id = c.customer_id)
    AND NOT EXISTS (SELECT 1 FROM call_log x          WHERE x.customer_id = c.customer_id)
    AND NOT EXISTS (SELECT 1 FROM analytics_events x  WHERE x.customer_id = c.customer_id)
    AND NOT EXISTS (SELECT 1 FROM chat_history x      WHERE x.customer_id = c.customer_id);

  DELETE FROM session_state s USING _purge_ids p WHERE s.customer_id = p.customer_id;
  DELETE FROM customers c USING _purge_ids p WHERE c.customer_id = p.customer_id;
  GET DIAGNOSTICS session_customers_deleted = ROW_COUNT;
  RETURN NEXT;
END $$;
ALTER FUNCTION flames_purge() OWNER TO flames_kohsamui;
COMMIT;
