-- Khun Aran-Tool-CancelReservation, node "Cancel Reservation" (v2m). Params: $1 confirmation_code, $2 phone,
-- $3 channel, $4 customer_id. Same ownership check as before. New in v2m: logs the cancellation in
-- reservation_change_log ('cancelled') and returns what the automatic cancellation email needs (email_to,
-- guest_name, date_label); the email only goes to the address already stored on that booking.
-- Status: cancelled | not_authorized | already_cancelled
WITH owner AS (
  SELECT r.reservation_id
  FROM reservations r
  JOIN customers c ON c.customer_id = r.customer_id
  WHERE r.confirmation_code = upper(BTRIM($1))
    AND r.reservation_date >= (NOW() AT TIME ZONE 'Asia/Bangkok')::date
    AND (
      ( $3 = 'web'
        AND c.channel = 'web'
        AND c.channel_user_id = 'phone:' || BTRIM(regexp_replace($2,'[[:space:]().-]','','g')) )
      OR
      ( $3 = 'telegram' AND r.customer_id = NULLIF($4,'')::uuid )
    )
),
upd AS (
  UPDATE reservations SET status='cancelled', updated_at=NOW()
  WHERE reservation_id = (SELECT reservation_id FROM owner)
    AND status IN ('confirmed','pending')
  RETURNING reservation_id, confirmation_code, status, customer_id, confirmation_email_to,
            reservation_date, reservation_time, people, zone, special_requests
),
log AS (
  INSERT INTO reservation_change_log (reservation_id, action, old_values, new_values, actor)
  SELECT reservation_id, 'cancelled',
         jsonb_build_object('date', reservation_date, 'time', to_char(reservation_time, 'HH24:MI'), 'people', people, 'zone', zone, 'status', 'confirmed'),
         jsonb_build_object('status', 'cancelled'),
         'khun_aran:' || COALESCE(NULLIF($3, ''), 'unknown')
  FROM upd
  RETURNING id
)
SELECT
  CASE
    WHEN (SELECT reservation_id FROM owner) IS NULL THEN 'not_authorized'
    WHEN (SELECT reservation_id FROM upd)   IS NULL THEN 'already_cancelled'
    ELSE 'cancelled'
  END AS status,
  (SELECT reservation_id FROM upd)                    AS reservation_id,
  (SELECT confirmation_code FROM upd)                 AS confirmation_code,
  (SELECT reservation_date::text FROM upd)            AS reservation_date,
  (SELECT to_char(reservation_time, 'HH24:MI') FROM upd) AS reservation_time,
  (SELECT people FROM upd)                            AS people,
  (SELECT zone FROM upd)                              AS zone,
  (SELECT to_char(reservation_date, 'FMDay FMDD FMMonth YYYY') FROM upd) AS date_label,
  (SELECT confirmation_email_to FROM upd)             AS email_to,
  (SELECT BTRIM(concat_ws(' ', c.name, c.surname)) FROM upd u JOIN customers c USING (customer_id)) AS guest_name,
  (SELECT c.language FROM upd u JOIN customers c USING (customer_id)) AS guest_lang;
