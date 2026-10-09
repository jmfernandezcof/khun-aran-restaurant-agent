-- 018_phone_normalize.sql  (DB maite_flames_kohsamui)
-- Un solo sitio para normalizar teléfonos (antes, 6 consultas repetían regexp_replace(..., '[[:space:]().-]', '')).
-- Bug (chat real en tailandés 2026-10-03): el huésped da "081-234-5678" y el modelo lo pasa como "+66 081-234-5678";
-- se habría guardado +660812345678, un número que no existe (el 0 nacional desaparece con el prefijo), y la reserva no
-- se encontraría después con "+66 83…". Ahora, además de quitar espacios y signos:
--   - "00" inicial → "+";
--   - quita el 0 nacional justo detrás del prefijo de país, para los países donde no se marca en internacional.
--     Italia (+39), San Marino (+378) y el Vaticano (+379) conservan el 0, por eso no están en la lista.
-- Los prefijos de país (E.164) no son prefijo unos de otros, así que la lista no es ambigua.
-- Comprobado antes de aplicar: ningún teléfono guardado lleva ese 0 (los +34 600… son correctos y no cambian).
-- ROLLBACK: DROP FUNCTION IF EXISTS flames_phone(text);  (y volver a poner las consultas anteriores en los 6 workflows)
BEGIN;
CREATE OR REPLACE FUNCTION flames_phone(raw text) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
  SELECT regexp_replace(
           regexp_replace(BTRIM(regexp_replace(COALESCE(raw, ''), '[[:space:]().-]', '', 'g')), '^00', '+'),
           '^[+](1|7|20|27|30|31|32|33|34|36|40|41|43|44|45|46|47|48|49|51|52|53|54|55|56|57|58|60|61|62|63|64|65|66|'
           '81|82|84|86|90|91|92|93|94|95|98|212|213|216|234|254|351|352|353|354|356|357|358|359|370|371|372|380|381|385|'
           '386|420|421|852|853|855|856|880|886|960|961|962|965|966|968|971|972|973|974|977)0',
           '+\1')
$$;
ALTER FUNCTION flames_phone(text) OWNER TO flames_kohsamui;
COMMIT;
