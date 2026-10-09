-- 019_legal_page_2026_2_voice.sql  (DB maite_flames_kohsamui)
-- Política de privacidad (legal_page, webhook flames-privacy) versión 2026.2. Añade lo que la 2026.1 no decía:
--   - el contenido de la conversación del chat y la entrada por voz (transcrita por OpenAI, el audio no se guarda);
--   - los proveedores que tratan datos por cuenta del restaurante (Anthropic, OpenAI, Google, Cloudflare) y que
--     pueden hacerlo fuera de Tailandia;
--   - plazos reales de la migración 017 (chat 90 días, contactos sin reserva 30 días);
--   - lo que guarda el navegador: sin cookies, solo un identificador anónimo de conversación en localStorage.
-- La 2026.1 decía "no compartimos sus datos con terceros salvo obligación legal": ya no era exacto.
-- Cómo se elige: Maite-Web-Privacy sirve el legal_page ACTIVO más reciente por idioma (sin th → inglés).
-- El aviso corto del chat (chat_prompt 2026.2) no cambia.
--
-- ROLLBACK:
--   BEGIN;
--   DELETE FROM legal_notices WHERE version = '2026.2' AND notice_type = 'legal_page';
--   UPDATE legal_notices SET is_active = true WHERE version = '2026.1' AND notice_type = 'legal_page';
--   COMMIT;

BEGIN;

UPDATE legal_notices SET is_active = false WHERE version = '2026.1' AND notice_type = 'legal_page';

INSERT INTO legal_notices (language, version, notice_type, text, is_active, needs_review) VALUES
('es', '2026.2', 'legal_page',
 'Flames Restaurant — Talay Cliff Resort & Spa, Koh Samui

Aviso de privacidad (PDPA Tailandia, B.E. 2562) — versión 2026.2

Qué datos tratamos: nombre, teléfono y, si lo facilita, correo electrónico, junto con los detalles de su reserva (fecha, hora, número de personas y peticiones especiales, incluidas alergias o necesidades dietéticas si nos las indica). También el contenido de la conversación con nuestro asistente Khun Aran.

Mensajes de voz: si usa el micrófono, el audio se envía a un proveedor de transcripción (OpenAI) y solo conservamos el texto transcrito, que se trata como un mensaje escrito. El audio no se guarda. Usar la voz es opcional: siempre puede escribir.

Finalidad: gestionar su reserva, responder a sus preguntas, contactarle sobre la reserva y atender sus preferencias en el restaurante.

Proveedores: para prestar el servicio, algunos datos los tratan proveedores tecnológicos por cuenta del restaurante y solo para esa finalidad: Anthropic (asistente de conversación), OpenAI (transcripción de voz), Google (correo de confirmación y calendario interno de reservas) y Cloudflare (entrega segura de la web). Algunos tratan los datos fuera de Tailandia. No vendemos ni cedemos sus datos a terceros para otros fines, salvo obligación legal.

Conservación: las conversaciones del chat se borran a los 90 días; los datos de contacto de quien no llega a reservar, a los 30 días; los datos de las reservas, solo el tiempo necesario para prestar el servicio y cumplir obligaciones legales.

Su navegador: esta web no usa cookies de seguimiento ni de publicidad. Guarda en su navegador (almacenamiento local) un identificador anónimo de conversación, necesario para que el asistente recuerde lo que ya le ha dicho; puede borrarlo eliminando los datos del sitio. Al cargar la página, su navegador descarga tipografías y bibliotecas de Google Fonts y jsDelivr, que reciben su dirección IP.

Sus derechos: puede solicitar acceso, rectificación o supresión de sus datos, así como retirar su consentimiento, contactando con el restaurante.

Contacto: a través de la recepción del resort o del propio restaurante Flames.',
 true, false),
('en', '2026.2', 'legal_page',
 'Flames Restaurant — Talay Cliff Resort & Spa, Koh Samui

Privacy Notice (Thailand PDPA, B.E. 2562) — version 2026.2

Data we process: your name, phone number and, if provided, email, together with your reservation details (date, time, party size and special requests, including allergies or dietary needs if you tell us). Also the content of your conversation with our assistant Khun Aran.

Voice messages: if you use the microphone, the audio is sent to a transcription provider (OpenAI) and we keep only the transcribed text, which is handled like a written message. The audio is not stored. Voice is optional: you can always type.

Purpose: to manage your reservation, answer your questions, contact you about it and accommodate your preferences at the restaurant.

Service providers: to provide the service, some data is processed by technology providers on the restaurant''s behalf and only for that purpose: Anthropic (conversational assistant), OpenAI (voice transcription), Google (confirmation email and internal reservations calendar) and Cloudflare (secure delivery of the website). Some of them process data outside Thailand. We do not sell or share your data with third parties for other purposes, except where legally required.

Retention: chat conversations are deleted after 90 days; contact details of guests who do not complete a reservation, after 30 days; reservation data, only as long as necessary to provide the service and meet legal obligations.

Your browser: this website uses no tracking or advertising cookies. It stores an anonymous conversation identifier in your browser (local storage), needed so the assistant remembers what you have already said; you can remove it by clearing the site''s data. When the page loads, your browser downloads fonts and libraries from Google Fonts and jsDelivr, which receive your IP address.

Your rights: you may request access, correction or deletion of your data, and withdraw your consent, by contacting the restaurant.

Contact: via the resort reception or Flames restaurant directly.',
 true, false);

-- Verificación: exactamente un legal_page activo por idioma (es, en), ambos 2026.2.
DO $$
BEGIN
  IF (SELECT count(*) FROM legal_notices WHERE notice_type = 'legal_page' AND is_active) <> 2
     OR EXISTS (SELECT 1 FROM legal_notices WHERE notice_type = 'legal_page' AND is_active AND version <> '2026.2') THEN
    RAISE EXCEPTION 'Verificación fallida: legal_page activos inesperados';
  END IF;
END $$;

COMMIT;
