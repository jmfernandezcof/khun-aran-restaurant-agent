-- Khun Aran-Tool-SendConfirmation, node "Claim Send". Params: $1 confirmation_code, $2 phone, $3 channel,
-- $4 customer_id, $5 email. Same ownership check as find/cancel (web: code + booking phone; telegram: code + customer).
-- Claims the single email of the reservation (confirmation_email_sent_at IS NULL) and returns the data for the
-- template straight from the DB, never from the model. Status: ok | not_found | invalid_email | already_sent | rate_limited (flames_email_guard, migration 012).
WITH inp AS (
  SELECT upper(BTRIM($1)) AS code, lower(BTRIM($5)) AS email
),
r AS (
  SELECT r.reservation_id, r.confirmation_code, r.reservation_date, r.reservation_time, r.people, r.zone,
         r.special_requests, r.confirmation_email_sent_at, r.confirmation_email_to, c.customer_id, c.name, c.surname
  FROM reservations r
  JOIN customers c ON c.customer_id = r.customer_id, inp
  WHERE r.confirmation_code = inp.code
    AND r.status IN ('confirmed','pending')
    AND r.reservation_date >= (NOW() AT TIME ZONE 'Asia/Bangkok')::date
    AND (
      ( $3 = 'web'
        AND c.channel = 'web'
        AND c.channel_user_id = 'phone:' || BTRIM(regexp_replace($2,'[[:space:]().-]','','g')) )
      OR
      ( $3 = 'telegram' AND r.customer_id = NULLIF($4,'')::uuid )
    )
),
chk AS (
  SELECT CASE
    WHEN NOT EXISTS (SELECT 1 FROM r) THEN 'not_found'
    WHEN length((SELECT email FROM inp)) > 254
      OR (SELECT email FROM inp) !~ '^[a-z0-9._%+''-]+@[a-z0-9-]+(\.[a-z0-9-]+)*\.[a-z]{2,}$' THEN 'invalid_email'
    WHEN (SELECT confirmation_email_sent_at FROM r) IS NOT NULL THEN 'already_sent'
    WHEN flames_email_guard((SELECT email FROM inp)) <> 'ok' THEN 'rate_limited'
    ELSE 'ok' END AS status
),
claim AS (
  UPDATE reservations SET confirmation_email_sent_at = now(), confirmation_email_to = (SELECT email FROM inp),
         updated_at = now()
  WHERE reservation_id = (SELECT reservation_id FROM r) AND confirmation_email_sent_at IS NULL
    AND (SELECT status FROM chk) = 'ok'
  RETURNING reservation_id
),
cust AS (
  UPDATE customers SET email = (SELECT email FROM inp), updated_at = now()
  WHERE customer_id = (SELECT customer_id FROM r) AND EXISTS (SELECT 1 FROM claim)
  RETURNING customer_id
)
SELECT
  CASE WHEN (SELECT status FROM chk) = 'ok' AND NOT EXISTS (SELECT 1 FROM claim) THEN 'already_sent'
       ELSE (SELECT status FROM chk) END AS status,
  (SELECT reservation_id FROM claim) AS claimed_reservation_id,
  r.confirmation_code,
  r.reservation_date::text AS reservation_date,
  to_char(r.reservation_date, 'FMDay FMDD FMMonth YYYY') AS date_label,
  to_char(r.reservation_time, 'HH24:MI') AS reservation_time,
  r.people, r.zone, r.special_requests,
  BTRIM(concat_ws(' ', r.name, r.surname)) AS guest_name,
  (SELECT email FROM inp) AS email,
  -- already_sent: only the masked address it went to (never reveal someone else's full email)
  regexp_replace(r.confirmation_email_to, '^(.).*(@.*)$', '\1***\2') AS sent_to_masked
FROM (SELECT 1) one LEFT JOIN r ON true;
