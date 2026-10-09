WITH cfg AS (
  SELECT capacity, max_reservation_days_ahead AS w, opening_hours, max_party_online, max_changes_per_booking_per_day AS max_changes
  FROM restaurant_config WHERE internal_id = 'maite_flames_kohsamui'
),
r AS (
  SELECT r.*, BTRIM(concat_ws(' ', c.name, c.surname)) AS guest_name, c.language AS guest_lang
  FROM reservations r
  JOIN customers c ON c.customer_id = r.customer_id
  WHERE r.confirmation_code = upper(BTRIM($1))
    AND r.status IN ('confirmed', 'pending')
    AND r.reservation_date >= (NOW() AT TIME ZONE 'Asia/Bangkok')::date
    AND (
      ( $3 = 'web' AND c.channel = 'web'
        AND c.channel_user_id = 'phone:' || flames_phone($2) )
      OR ( $3 = 'telegram' AND r.customer_id = NULLIF($4, '')::uuid )
    )
),
n AS (
  SELECT r.reservation_id,
         COALESCE(NULLIF(BTRIM($5), '')::date, r.reservation_date) AS d,
         COALESCE(NULLIF(BTRIM($6), '')::time, r.reservation_time) AS t,
         COALESCE(NULLIF(BTRIM($7), '')::int, r.people) AS p,
         CASE WHEN lower(BTRIM($8)) IN ('indoor', 'terrace') THEN lower(BTRIM($8)) ELSE r.zone END AS z,
         CASE WHEN NULLIF(BTRIM($9), '') IS NULL THEN r.special_requests
              ELSE concat_ws('; ', NULLIF(r.special_requests, ''), BTRIM($9)) END AS sr
  FROM r
),
hrs AS (
  SELECT (oh->>'open')::time AS open_t, (oh->>'close')::time AS close_t
  FROM cfg, n, LATERAL jsonb_array_elements(cfg.opening_hours ->
    (ARRAY['sunday','monday','tuesday','wednesday','thursday','friday','saturday'])[EXTRACT(DOW FROM n.d)::int + 1]) oh
  ORDER BY (oh->>'open')::time LIMIT 1
),
st AS (
  SELECT CASE
    WHEN NOT EXISTS (SELECT 1 FROM r) THEN 'not_found'
    WHEN (SELECT (n.d, n.t, n.p, n.z, n.sr) IS NOT DISTINCT FROM (r.reservation_date, r.reservation_time, r.people, r.zone, r.special_requests) FROM n, r) THEN 'no_changes'
    WHEN (SELECT (n.d + n.t) < (NOW() AT TIME ZONE 'Asia/Bangkok')::timestamp FROM n) THEN 'past_date'
    WHEN (SELECT n.d > (NOW() AT TIME ZONE 'Asia/Bangkok')::date + cfg.w FROM n, cfg) THEN 'too_far_ahead'
    WHEN NOT EXISTS (SELECT 1 FROM hrs)
      OR (SELECT n.t < hrs.open_t OR n.t > hrs.close_t - INTERVAL '30 minutes' FROM n, hrs) THEN 'outside_hours'
    WHEN (SELECT flames_team_only(n.d) FROM n) THEN 'team_only_event'
    WHEN (SELECT n.p > cfg.max_party_online FROM n, cfg) THEN 'party_too_large'
    WHEN (SELECT count(*) FROM reservation_change_log l, r WHERE l.reservation_id = r.reservation_id
            AND l.action = 'modified' AND l.created_at > now() - INTERVAL '24 hours') >= (SELECT max_changes FROM cfg) THEN 'limit_reached'
    WHEN (SELECT cfg.capacity - flames_max_seated(n.d, n.t, n.reservation_id) < n.p FROM n, cfg) THEN 'no_availability'
    ELSE 'modified' END AS status
),
upd AS (
  UPDATE reservations res SET reservation_date = n.d, reservation_time = n.t, people = n.p, zone = n.z,
                              special_requests = n.sr, updated_at = NOW()
  FROM n
  WHERE res.reservation_id = n.reservation_id AND (SELECT status FROM st) = 'modified'
  RETURNING res.reservation_id
),
log AS (
  INSERT INTO reservation_change_log (reservation_id, action, old_values, new_values, actor)
  SELECT r.reservation_id, 'modified',
         jsonb_build_object('date', r.reservation_date, 'time', to_char(r.reservation_time, 'HH24:MI'), 'people', r.people, 'zone', r.zone, 'special_requests', r.special_requests),
         jsonb_build_object('date', n.d, 'time', to_char(n.t, 'HH24:MI'), 'people', n.p, 'zone', n.z, 'special_requests', n.sr),
         'khun_aran:' || COALESCE(NULLIF($3, ''), 'unknown')
  FROM r, n WHERE EXISTS (SELECT 1 FROM upd)
  RETURNING id
)
SELECT
  (SELECT status FROM st) AS status,
  (SELECT reservation_id FROM upd) AS reservation_id,
  r.confirmation_code,
  CASE WHEN (SELECT status FROM st) = 'modified' THEN n.d ELSE r.reservation_date END::text AS reservation_date,
  to_char(CASE WHEN (SELECT status FROM st) = 'modified' THEN n.t ELSE r.reservation_time END, 'HH24:MI') AS reservation_time,
  CASE WHEN (SELECT status FROM st) = 'modified' THEN n.p ELSE r.people END AS people,
  CASE WHEN (SELECT status FROM st) = 'modified' THEN n.z ELSE r.zone END AS zone,
  CASE WHEN (SELECT status FROM st) = 'modified' THEN n.sr ELSE r.special_requests END AS special_requests,
  to_char(CASE WHEN (SELECT status FROM st) = 'modified' THEN n.d ELSE r.reservation_date END, 'FMDay FMDD FMMonth YYYY') AS date_label,
  to_char(r.reservation_date, 'FMDay FMDD FMMonth YYYY') AS old_date_label,
  r.reservation_date::text AS old_reservation_date,
  to_char(r.reservation_time, 'HH24:MI') AS old_time,
  r.people AS old_people,
  to_char(n.d, 'FMDay FMDD FMMonth YYYY') AS requested_date_label,
  r.guest_name,
  r.guest_lang,
  r.confirmation_email_to AS email_to,
  (SELECT count(*) FROM reservation_change_log l WHERE l.reservation_id = r.reservation_id AND l.action = 'modified') + 1 AS change_seq,
  CASE WHEN (SELECT status FROM st) = 'no_availability' THEN flames_alternatives(n.d, n.t, n.p) END AS alternatives,
  CASE WHEN n.d IS NOT NULL THEN flames_special(n.d) END AS special,
  CASE WHEN (SELECT status FROM st) IN ('team_only_event', 'party_too_large', 'limit_reached', 'too_far_ahead')
       THEN flames_team_contact() END AS team_contact
FROM (SELECT 1) one LEFT JOIN r ON true LEFT JOIN n ON true
