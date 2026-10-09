-- 008_legal_notices_2026_2_email.sql  (DB maite_flames_kohsamui)
-- Aviso PDPA del chat versión 2026.2: añade el correo electrónico (opcional, solo para enviar la confirmación
-- de la reserva). Necesario antes de activar la tool send_confirmation_email.
--
-- Cómo se elige el aviso: create_reservation / save_consent / privacy usan el aviso ACTIVO más reciente por idioma
-- (is_active = true, ORDER BY effective_from DESC). Por eso basta con insertar 2026.2 y desactivar 2026.1 (chat_prompt).
-- Los clientes que ya consintieron 2026.1 conservan pdpa_consent = true (el consentimiento es por cliente, no por
-- versión); el agente, al pedir el email, dice en una frase para qué se usa.
-- La legal_page 2026.1 (es/en) ya incluye "y, si lo facilita, correo electrónico": no cambia.
-- TH: traducción propia, needs_review = true hasta revisión nativa.
--
-- ROLLBACK:
--   BEGIN;
--   DELETE FROM legal_notices WHERE version = '2026.2' AND notice_type = 'chat_prompt';
--   UPDATE legal_notices SET is_active = true WHERE version = '2026.1' AND notice_type = 'chat_prompt';
--   COMMIT;

BEGIN;

UPDATE legal_notices SET is_active = false WHERE version = '2026.1' AND notice_type = 'chat_prompt';

INSERT INTO legal_notices (language, version, notice_type, text, is_active, needs_review) VALUES
('es', '2026.2', 'chat_prompt',
 'Para completar su reserva guardaremos su nombre y teléfono —y, si nos lo facilita, su correo electrónico, solo para enviarle la confirmación— con el fin de gestionarla y contactarle si fuera necesario, conforme a la Ley de Protección de Datos Personales de Tailandia (PDPA). Conservaremos estos datos solo el tiempo necesario para el servicio y no los compartiremos con terceros salvo obligación legal. ¿Me da su consentimiento para continuar con la reserva?',
 true, false),
('en', '2026.2', 'chat_prompt',
 'To complete your reservation we will store your name and phone number — and, if you provide it, your email address, used only to send you the confirmation — to manage it and contact you if needed, in accordance with Thailand''s Personal Data Protection Act (PDPA). We keep this data only as long as necessary and never share it with third parties except where legally required. Do you consent so I may proceed with your reservation?',
 true, false),
('th', '2026.2', 'chat_prompt',
 'เพื่อดำเนินการจองให้เสร็จสมบูรณ์ เราจะจัดเก็บชื่อและหมายเลขโทรศัพท์ของท่าน รวมถึงอีเมลหากท่านให้ไว้ (ใช้เพื่อส่งการยืนยันการจองเท่านั้น) เพื่อจัดการการจองและติดต่อท่านหากจำเป็น ตามพระราชบัญญัติคุ้มครองข้อมูลส่วนบุคคล (PDPA) เราจะเก็บข้อมูลไว้เท่าที่จำเป็นและจะไม่เปิดเผยต่อบุคคลภายนอก เว้นแต่กฎหมายกำหนด ท่านยินยอมให้เราดำเนินการจองต่อหรือไม่',
 true, true);

-- Verificación: exactamente un chat_prompt activo por idioma, todos 2026.2.
DO $$
BEGIN
  IF (SELECT count(*) FROM legal_notices WHERE notice_type = 'chat_prompt' AND is_active) <> 3
     OR EXISTS (SELECT 1 FROM legal_notices WHERE notice_type = 'chat_prompt' AND is_active AND version <> '2026.2') THEN
    RAISE EXCEPTION 'Verificación fallida: avisos chat_prompt activos inesperados';
  END IF;
END $$;

COMMIT;
