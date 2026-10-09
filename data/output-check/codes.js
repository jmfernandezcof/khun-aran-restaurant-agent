// Output check 1/3 (2026-10-04): FLM codes in Khun Aran's reply.
// all_codes: every code (to know whether the reply cites a real booking).
// check_codes: those the guest did not just type (e.g. "no encuentro FLM-ABCDE" is legitimate to repeat).
const reply = $input.first().json;
const output = String(reply.output ?? '');
const guestText = String($('Normalize').first().json.text || '').toUpperCase();
const found = [...new Set((output.match(/\bFLM-[A-Z0-9]{4,8}\b/gi) || []).map((c) => c.toUpperCase()))];
const toCheck = found.filter((c) => !guestText.includes(c));
return [{ json: { ...reply, output, all_codes: found.join(',') || '-', check_codes: toCheck.join(',') || '-' } }];
