-- 009_reservation_confirmation_email.sql  (DB maite_flames_kohsamui)
-- Soporte para la tool send_confirmation_email (Khun Aran-Tool-SendConfirmation):
--   confirmation_email_sent_at: cuándo se envió (NULL = no enviado). La tool lo "reclama" con
--     UPDATE ... WHERE confirmation_email_sent_at IS NULL, así que como máximo sale UN email por reserva
--     (anti-abuso: nadie puede usar el chat para mandar correos en bucle ni a varias direcciones).
--   confirmation_email_to: a qué dirección se envió (para que el equipo pueda verlo/reenviarlo).
-- Sin cambios de owner: ADD COLUMN mantiene reservations en flames_kohsamui (la credencial de n8n).
-- Requiere 008 (aviso PDPA 2026.2 con el email) antes de activar la tool.
--
-- ROLLBACK:
--   ALTER TABLE reservations DROP COLUMN IF EXISTS confirmation_email_sent_at,
--                            DROP COLUMN IF EXISTS confirmation_email_to;

BEGIN;
ALTER TABLE reservations
  ADD COLUMN IF NOT EXISTS confirmation_email_sent_at timestamptz,
  ADD COLUMN IF NOT EXISTS confirmation_email_to varchar(254);
COMMIT;
