-- cleanup_test_bookings_20261001.sql — reservas de prueba del 2026-10-01 (chat) y sus clientes de prueba.
-- FLM-SJ5WM (#16), FLM-JQYPE (#17), FLM-X9TKN (#18), FLM-P7QK2 (#19). Los 4 clientes se crearon hoy solo para estas
-- pruebas (Ana Pérez +34600111333/77/78 y "Prueba Email" +34600111222) y no tienen otras reservas.
-- Google Calendar NO se toca desde aquí: borrar a mano los eventos flamesres16..19 (12/12 20:00 y 3 x 13/12 21:00).
BEGIN;
CREATE TEMP TABLE tc ON COMMIT DROP AS
  SELECT DISTINCT customer_id FROM reservations WHERE reservation_id IN (16,17,18,19)
    AND confirmation_code IN ('FLM-SJ5WM','FLM-JQYPE','FLM-X9TKN','FLM-P7QK2');
DO $$ BEGIN
  IF (SELECT count(*) FROM tc) <> 4
     OR EXISTS (SELECT 1 FROM reservations WHERE customer_id IN (SELECT customer_id FROM tc) AND reservation_id NOT IN (16,17,18,19)) THEN
    RAISE EXCEPTION 'Los clientes de prueba no son los esperados: no se borra nada';
  END IF;
END $$;
DELETE FROM reservation_change_log WHERE reservation_id IN (16,17,18,19);
DELETE FROM reservations WHERE reservation_id IN (16,17,18,19);
DELETE FROM customer_consents WHERE customer_id IN (SELECT customer_id FROM tc);
DELETE FROM customers WHERE customer_id IN (SELECT customer_id FROM tc);
SELECT (SELECT count(*) FROM reservations WHERE confirmation_code IN ('FLM-SJ5WM','FLM-JQYPE','FLM-X9TKN','FLM-P7QK2')) AS reservas_restantes;
COMMIT;
