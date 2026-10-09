-- Output check, blocked branch: replace Khun Aran's last reply in the chat memory (saved by the agent moments ago)
-- with the careful message, so the next turn does not build on the invented code. Always returns one row.
WITH target AS (
  SELECT id FROM maite_chat_history
  WHERE session_id = $1 AND message->>'type' = 'ai' AND created_at > now() - interval '10 minutes'
  ORDER BY id DESC LIMIT 1
), u AS (
  UPDATE maite_chat_history h SET message = jsonb_set(h.message, '{content}', to_jsonb($2::text))
  FROM target WHERE h.id = target.id RETURNING h.id
)
SELECT $2::text AS output, 'blocked' AS output_check, (SELECT count(*) FROM u) AS memory_fixed
