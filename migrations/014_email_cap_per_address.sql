-- 014_email_cap_per_address.sql  (DB maite_flames_kohsamui)
-- El tope de 2 confirmaciones por dirección y día (012) bloqueó a un cliente legítimo que reservó y cambió la reserva
-- el mismo día (prueba 2026-10-01, FLM-4YCFK: 'rate_limited'). Sube a 4: sigue frenando el bombardeo (cada email exige
-- una reserva distinta, limitada por flames_booking_guard) sin castigar al cliente. Los emails de cambio/cancelación
-- (v2m) no cuentan aquí: solo van a la dirección ya guardada en esa reserva.
-- ROLLBACK: UPDATE restaurant_config SET max_emails_per_address_per_day = 2 WHERE internal_id = 'maite_flames_kohsamui';
UPDATE restaurant_config SET max_emails_per_address_per_day = 4 WHERE internal_id = 'maite_flames_kohsamui';
SELECT max_emails_per_address_per_day FROM restaurant_config WHERE internal_id = 'maite_flames_kohsamui';
