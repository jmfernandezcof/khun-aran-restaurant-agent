-- 016_special_note_contact.sql  (DB maite_flames_kohsamui)
-- Regresión 2026-10-01: en noches de gala gpt-4.1-mini parafrasea special.guest_note pero no da team_contact aunque la
-- tool lo devuelve. flames_special() añade ahora el email del equipo DENTRO de guest_note en los días team_only, que es
-- el texto que los modelos repiten. El dato sigue saliendo de restaurant_config (flames_team_contact, migración 015).
-- También: el texto de los días sin alcohol hablaba de la ley en general y el agente generalizó ("no se sirve alcohol en
-- ningún establecimiento", falso: los hoteles registrados están exentos). Ahora habla solo de Flames.
-- ROLLBACK: re-crear flames_special de la migración 011; details/title originales en 011_special_dates.sql.
BEGIN;
CREATE OR REPLACE FUNCTION flames_special(p_date date) RETURNS jsonb
LANGUAGE sql STABLE AS $$
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'kind', kind, 'title', title, 'details', details, 'booking_policy', booking_policy,
           'deposit_required', deposit_required, 'price_note', price_note,
           'guest_note', CASE WHEN booking_policy = 'team_only'
                              THEN concat_ws(' ', guest_note, 'To reserve, write to the Flames team at ' || flames_team_contact() || '.')
                              ELSE guest_note END)
         ORDER BY kind), '[]'::jsonb)
  FROM special_dates WHERE day = p_date
$$;
ALTER FUNCTION flames_special(date) OWNER TO flames_kohsamui;
UPDATE special_dates SET details = 'Buddhist holy day: Flames does not serve alcohol that day.', updated_at = now()
WHERE kind = 'no_alcohol';
COMMIT;
