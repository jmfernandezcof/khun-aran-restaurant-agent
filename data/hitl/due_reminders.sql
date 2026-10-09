-- Staff reminders (HITL, 2026-10-04), run every minute. Open cases nobody claimed in time, only in staff hours
-- (08:00–23:00 Bangkok; a case raised at night is reminded at 08:00). Urgent: every 5 min, max 3 reminders.
-- Normal: every 20 min, max 2. Marks and returns the due cases in one statement (SKIP LOCKED: never reminded twice).
WITH due AS (
  SELECT id FROM human_requests
  WHERE status = 'open'
    AND (now() AT TIME ZONE 'Asia/Bangkok')::time >= time '08:00'
    AND (now() AT TIME ZONE 'Asia/Bangkok')::time <  time '23:00'
    AND (   (urgency = 'urgent' AND escalation_count < 3
             AND COALESCE(last_escalated_at, created_at) <= now() - interval '5 minutes')
         OR (urgency = 'normal' AND escalation_count < 2
             AND COALESCE(last_escalated_at, created_at) <= now() - interval '20 minutes'))
  ORDER BY id
  FOR UPDATE SKIP LOCKED
)
UPDATE human_requests h
   SET escalation_count = h.escalation_count + 1, last_escalated_at = now()
  FROM due
 WHERE h.id = due.id
RETURNING h.id, h.urgency, h.reason, h.guest_name, h.staff_chat_id, h.staff_message_id, h.escalation_count,
          CASE WHEN h.urgency = 'urgent' THEN 3 ELSE 2 END AS max_reminders,
          floor(extract(epoch FROM now() - h.created_at) / 60)::int AS minutes_open;
