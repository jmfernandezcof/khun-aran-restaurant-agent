-- Staff bot · Claim Case (HITL, 2026-10-04). "Lo atiendo" button → callback_data 'claim:<id>'.
-- Params: $1 case id, $2 staff name, $3 staff Telegram id, $4 chat id of the pressed message.
-- One atomic UPDATE: if two people press at once, only one wins. Returns one row:
--   claimed  → you got it;   already → someone else has it (claimed_by_name);   not_found → no such case in this chat.
WITH upd AS (
  UPDATE human_requests
     SET status = 'claimed', claimed_by_name = left($2::text, 80), claimed_by_tg_id = $3::bigint, claimed_at = now()
   WHERE id = $1::bigint AND status = 'open' AND staff_chat_id = $4::bigint
  RETURNING id, claimed_by_name, claimed_at
)
SELECT 'claimed' AS result, id, claimed_by_name,
       to_char(claimed_at AT TIME ZONE 'Asia/Bangkok', 'HH24:MI') AS claimed_time FROM upd
UNION ALL
SELECT CASE WHEN h.id IS NULL THEN 'not_found' ELSE 'already' END, $1::bigint, h.claimed_by_name,
       to_char(h.claimed_at AT TIME ZONE 'Asia/Bangkok', 'HH24:MI')
FROM (SELECT 1) one
LEFT JOIN human_requests h ON h.id = $1::bigint AND h.staff_chat_id = $4::bigint
WHERE NOT EXISTS (SELECT 1 FROM upd);
