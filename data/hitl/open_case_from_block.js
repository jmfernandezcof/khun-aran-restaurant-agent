// Output check → HITL (2026-10-04): when a reply was blocked as unbacked_confirmation ("your booking is confirmed"
// with no confirmed booking), open a staff case too: that guest might turn up expecting a table.
const d = $input.first().json;
const n = $('Normalize').first().json;
const u = $('Upsert Customer').first().json;
let tg = '';
if (n.channel === 'telegram') {
  try { const f = $('Telegram Trigger').first().json.message.from; if (f.username) tg = 'Telegram @' + f.username; } catch (e) {}
}
const name = [u.name, u.surname].filter(Boolean).join(' ');
return [{ json: {
  channel: n.channel, session_key: n.session_key, reason: 'tool_failure', urgency: 'normal',
  summary: 'Automatic check: Khun Aran told the guest the booking was confirmed, but this guest has no confirmed booking. '
    + 'The reply was blocked and the guest was asked to review the details. Blocked reply: ' + String(d.blocked_output || '').slice(0, 600),
  guest_name: name, guest_contact: u.phone || u.email || tg || ('No contact yet: check the conversation ' + n.session_key),
  confirmation_code: '', language: n.lang || '',
} }];
