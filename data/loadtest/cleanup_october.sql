-- cleanup_october.sql — borra TODO lo creado por seed_october.sql (y nada más).
BEGIN;
DELETE FROM reservation_change_log WHERE reservation_id IN (SELECT reservation_id FROM reservations WHERE channel = 'loadtest');
DELETE FROM reservations WHERE channel = 'loadtest';
DELETE FROM customers WHERE channel = 'loadtest' AND channel_user_id = 'loadtest:seed';
SELECT (SELECT count(*) FROM reservations WHERE channel = 'loadtest') AS reservas_restantes,
       (SELECT count(*) FROM customers WHERE channel = 'loadtest') AS clientes_restantes;
COMMIT;
