-- Output check 2/3. Params: $1 all codes, $2 codes to check, $3 session_key, $4 customer_id ('-' = none). One row:
--   unknown_codes: codes to check that are neither a real booking nor written by the guest earlier in this conversation;
--   known_codes: codes in the reply that are a confirmed booking;
--   has_active_booking: this customer has a confirmed booking from today (Bangkok) on.
WITH a AS (SELECT unnest(string_to_array(NULLIF($1, '-'), ',')) AS code),
     c AS (SELECT unnest(string_to_array(NULLIF($2, '-'), ',')) AS code)
SELECT
  COALESCE((SELECT array_agg(c.code) FROM c
            WHERE NOT EXISTS (SELECT 1 FROM reservations r WHERE upper(r.confirmation_code) = c.code)
              AND NOT EXISTS (SELECT 1 FROM maite_chat_history h
                              WHERE h.session_id = $3 AND h.message->>'type' = 'human'
                                AND upper(h.message->>'content') LIKE '%' || c.code || '%')), '{}') AS unknown_codes,
  COALESCE((SELECT array_agg(a.code) FROM a
            WHERE EXISTS (SELECT 1 FROM reservations r
                          WHERE upper(r.confirmation_code) = a.code AND r.status = 'confirmed')), '{}') AS known_codes,
  EXISTS (SELECT 1 FROM reservations r
          WHERE r.customer_id::text = $4 AND r.status = 'confirmed'
            AND r.reservation_date >= (now() AT TIME ZONE 'Asia/Bangkok')::date) AS has_active_booking
