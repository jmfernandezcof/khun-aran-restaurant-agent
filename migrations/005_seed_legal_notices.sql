-- 005_seed_legal_notices.sql
-- Reseed de la tabla legal_notices (DB maite_flames_kohsamui), vacía tras la mudanza a Contabo.
-- Sin este contenido, create_reservation devuelve 'error_invalid_notice' para todo
-- cliente nuevo y la página /webhook/flames-privacy sale en blanco.
--
-- Versión del aviso: 2026.1 (la que ya referencia el prompt del agente y el link de privacidad).
-- notice_type 'chat_prompt' = texto que el maître recita en el chat antes de guardar datos.
-- notice_type 'legal_page'  = página completa que sirve el webhook de privacidad.
--
-- NOTA: texto reconstruido (no había backup del original). Para un cliente real
-- (p.ej. El Capricho) el texto legal debe ser el suyo, revisado por su asesor.
-- El TH está pendiente de revisión por nativo.
--
-- ROLLBACK:
--   DELETE FROM legal_notices WHERE version = '2026.1';

INSERT INTO legal_notices (language, version, notice_type, text, is_active) VALUES
('es', '2026.1', 'chat_prompt',
 'Para completar su reserva guardaremos su nombre y teléfono con el fin de gestionarla y contactarle si fuera necesario, conforme a la Ley de Protección de Datos Personales de Tailandia (PDPA). Conservaremos estos datos solo el tiempo necesario para el servicio y no los compartiremos con terceros salvo obligación legal. ¿Me da su consentimiento para continuar con la reserva?',
 true),
('en', '2026.1', 'chat_prompt',
 'To complete your reservation we will store your name and phone number to manage it and contact you if needed, in accordance with Thailand''s Personal Data Protection Act (PDPA). We keep this data only as long as necessary and never share it with third parties except where legally required. Do you consent so I may proceed with your reservation?',
 true),
('th', '2026.1', 'chat_prompt',
 'เพื่อดำเนินการจองให้เสร็จสมบูรณ์ เราจะจัดเก็บชื่อและหมายเลขโทรศัพท์ของท่านเพื่อจัดการการจองและติดต่อท่านหากจำเป็น ตามพระราชบัญญัติคุ้มครองข้อมูลส่วนบุคคล (PDPA) เราจะเก็บข้อมูลไว้เท่าที่จำเป็นและจะไม่เปิดเผยต่อบุคคลภายนอก เว้นแต่กฎหมายกำหนด ท่านยินยอมให้เราดำเนินการจองต่อหรือไม่',
 true),
('es', '2026.1', 'legal_page',
 E'Flames Restaurant — Talay Cliff Resort & Spa, Koh Samui\n\nAviso de privacidad (PDPA Tailandia, B.E. 2562)\n\nQué datos tratamos: nombre, teléfono y, si lo facilita, correo electrónico, junto con los detalles de su reserva (fecha, hora, número de personas y peticiones especiales).\n\nFinalidad: gestionar su reserva, contactarle sobre ella y atender sus preferencias en el restaurante.\n\nConservación: mantenemos sus datos solo el tiempo necesario para prestar el servicio y cumplir obligaciones legales.\n\nCesión: no compartimos sus datos con terceros salvo obligación legal.\n\nSus derechos: puede solicitar acceso, rectificación o supresión de sus datos, así como retirar su consentimiento, contactando con el restaurante.\n\nContacto: a través de la recepción del resort o del propio restaurante Flames.',
 true),
('en', '2026.1', 'legal_page',
 E'Flames Restaurant — Talay Cliff Resort & Spa, Koh Samui\n\nPrivacy Notice (Thailand PDPA, B.E. 2562)\n\nData we process: your name, phone number and, if provided, email, together with your reservation details (date, time, party size and special requests).\n\nPurpose: to manage your reservation, contact you about it and accommodate your preferences at the restaurant.\n\nRetention: we keep your data only as long as necessary to provide the service and meet legal obligations.\n\nSharing: we do not share your data with third parties except where legally required.\n\nYour rights: you may request access, correction or deletion of your data, and withdraw your consent, by contacting the restaurant.\n\nContact: via the resort reception or Flames restaurant directly.',
 true);
