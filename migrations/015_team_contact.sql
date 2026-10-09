-- 015_team_contact.sql  (DB maite_flames_kohsamui)
-- El contacto del equipo lo devuelven las tools (campo team_contact) cuando hay que derivar: gala team_only, fuera de
-- plazo, grupo mayor que max_party_online o tope de reservas/cambios. Batería de regresión 2026-10-01: gpt-4.1-mini no
-- daba el email aunque el prompt lo pide; los modelos repiten mejor lo que devuelve una tool. Configurable por cliente.
-- ROLLBACK: DROP FUNCTION IF EXISTS flames_team_contact(); ALTER TABLE restaurant_config DROP COLUMN IF EXISTS team_contact_email;
BEGIN;
ALTER TABLE restaurant_config ADD COLUMN IF NOT EXISTS team_contact_email text NOT NULL DEFAULT 'np.flames.kohsamui@gmail.com';
CREATE OR REPLACE FUNCTION flames_team_contact() RETURNS text
LANGUAGE sql STABLE AS $$ SELECT team_contact_email FROM restaurant_config WHERE internal_id = 'maite_flames_kohsamui' $$;
ALTER FUNCTION flames_team_contact() OWNER TO flames_kohsamui;
COMMIT;
