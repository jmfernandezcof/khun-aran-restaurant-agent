-- RequestHuman · Insert Case (HITL, 2026-10-04). Always returns ONE row with `result`:
--   created          → the case row (id, …) to notify the staff group;
--   missing_contact  → no phone/email/Telegram given: the agent must ask for one;
--   existing         → this conversation already has an open/claimed case with the same reason from the last
--                      15 minutes: no new case, no new alert (the model sometimes calls the tool twice);
--   limit_reached    → this conversation already raised 3 cases in the last hour (anti-spam of the staff group).
-- Params: $1 channel, $2 session_key, $3 reason, $4 urgency, $5 summary, $6 guest_name, $7 guest_contact,
--         $8 confirmation_code, $9 language. Texts are clipped (Telegram messages max out at 4096 chars).
WITH input AS (
  SELECT
    CASE WHEN $1::text IN ('web','telegram') THEN $1::text ELSE 'web' END AS channel,
    NULLIF(trim($2::text), '') AS session_key,
    CASE WHEN $3::text IN ('complaint','adverse_event','severe_allergy','special_request',
                           'reservation_not_found','tool_failure','wants_human')
         THEN $3::text ELSE 'wants_human' END AS reason,
    CASE WHEN $4::text = 'urgent' THEN 'urgent' ELSE 'normal' END AS urgency,
    left(COALESCE(NULLIF(trim($5::text), ''), '(sin resumen)'), 1000) AS summary,
    left(NULLIF(trim($6::text), ''), 120) AS guest_name,
    left(NULLIF(trim($7::text), ''), 200) AS guest_contact,
    left(NULLIF(upper(trim($8::text)), ''), 20) AS confirmation_code,
    left(NULLIF(lower(trim($9::text)), ''), 10) AS language
), recent AS (
  SELECT count(*) AS n FROM human_requests h, input i
  WHERE h.session_key = i.session_key AND h.status <> 'cancelled' AND h.created_at > now() - interval '1 hour'
), existing AS (
  SELECT h.id, h.within_hours FROM human_requests h, input i
  WHERE h.session_key = i.session_key AND h.reason = i.reason AND h.status IN ('open', 'claimed')
    AND h.created_at > now() - interval '15 minutes'
  ORDER BY h.id DESC LIMIT 1
), ins AS (
  INSERT INTO human_requests
    (channel, session_key, reason, urgency, summary, guest_name, guest_contact,
     confirmation_code, language, within_hours, staff_chat_id)
  SELECT i.channel, i.session_key, i.reason, i.urgency, i.summary, i.guest_name, i.guest_contact,
         i.confirmation_code, i.language,
         (now() AT TIME ZONE 'Asia/Bangkok')::time >= time '08:00'
           AND (now() AT TIME ZONE 'Asia/Bangkok')::time < time '23:00',
         -1001234567890
  FROM input i, recent r
  WHERE i.guest_contact IS NOT NULL AND r.n < 3 AND NOT EXISTS (SELECT 1 FROM existing)
  RETURNING id, channel, reason, urgency, summary, guest_name, guest_contact,
            confirmation_code, language, within_hours
)
SELECT ins.*, 'created' AS result FROM ins
UNION ALL
SELECT e.id, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, e.within_hours, 'existing' FROM existing e
UNION ALL
SELECT NULL::bigint, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL::boolean,
       CASE WHEN i.guest_contact IS NULL THEN 'missing_contact' ELSE 'limit_reached' END
FROM input i WHERE NOT EXISTS (SELECT 1 FROM ins) AND NOT EXISTS (SELECT 1 FROM existing);
