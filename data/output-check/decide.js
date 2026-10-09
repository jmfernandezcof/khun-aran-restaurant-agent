// Output check 3/3. Rules, in order (the first that applies blocks the reply):
//   leak                  - tool or internal status names, the internal identifier, raw JSON;
//   unknown_code          - an FLM code that does not exist (and the guest did not write);
//   unbacked_confirmation - "your booking is confirmed" with no real code cited and no confirmed booking for this guest.
// A blocked reply is replaced by a careful message in the guest's language; "Blocked?" then fixes the chat memory
// and emails the team. Not blocked: internal labels ("ALERGIA/DIETA:", "Ocasion:") become plain words.
// If the lookup failed, only the leak rule applies and the reply otherwise goes out as is.
const reply = $('Output Check: Codes').first().json;
const look = $input.first().json;
const { all_codes, check_codes, ...clean } = reply;
const output = String(reply.output ?? '');
const text = String($('Normalize').first().json.text || '');
const TEAM = 'np.flames.kohsamui@gmail.com';
let lang = 'en';
if (/[฀-๿]/.test(text)) lang = 'th';
else if (/[¿¡ñáéíóú]|\b(hola|buen[oa]s|mesa|reserva|quiero|quisiera|para|gracias|cancelar|cambiar|tenéis|teneis)\b/i.test(text)) lang = 'es';

const LEAK = [
  /\b(check_availability|create_reservation|find_my_reservations|cancel_reservation|modify_reservation|save_consent|send_confirmation_email|find_dishes)\b/i,
  /\b(missing_required_fields|consent_required|no_availability|past_date|outside_hours|too_far_ahead|team_only_event|party_too_large|limit_reached|error_invalid_notice|error_unknown_customer|already_sent|invalid_email|rate_limited|send_failed|not_found|no_changes|notice_text|notice_version|date_label|special_requests|customer_id|reservation_id|team_contact|suits_guest)\b/i,
  /FLAMES-KHS-KHUNARAN/i,
  /\{\s*"[a-z_]+"\s*:/i,
];
const CLAIM = [
  /\b(su |la )?reserva (ya )?(está|esta|queda|ha quedado) (confirmada|hecha|registrada)/i,
  /\bhe (hecho|realizado|confirmado|registrado) (su|la) reserva/i,
  /\ble he reservado\b/i,
  /\b(reservation|booking|table) (is|has been) (now )?(confirmed|booked|reserved)\b/i,
  /\bI(?:'ve| have) (booked|reserved|confirmed)\b/i,
];

const lookupOk = !look.error && Array.isArray(look.unknown_codes);
const unknown = lookupOk ? look.unknown_codes : [];
const known = lookupOk && Array.isArray(look.known_codes) ? look.known_codes : [];
let reason = '';
if (LEAK.some((re) => re.test(output))) reason = 'leak';
else if (unknown.length) reason = 'unknown_code';
else if (lookupOk && CLAIM.some((re) => re.test(output)) && !known.length && look.has_active_booking !== true) reason = 'unbacked_confirmation';

if (!reason) {
  const LABELS = { es: ['Alergias y dieta:', 'Ocasión:'], en: ['Allergies and diet:', 'Occasion:'], th: ['Allergies and diet:', 'Occasion:'] }[lang];
  const relabeled = output.replace(/ALERGIA\/DIETA:/g, LABELS[0]).replace(/\bOcasion:/g, LABELS[1]);
  return [{ json: { ...clean, output: relabeled, output_check: lookupOk ? (relabeled === output ? 'ok' : 'relabeled') : 'lookup_failed' } }];
}

const SAFE = {
  unknown_code: {
    es: `Disculpe, quiero asegurarme de no darle un dato equivocado: no he podido verificar ese código de reserva. ¿Me permite comprobarlo de nuevo? Si lo prefiere, puede escribir al equipo de Flames a ${TEAM}.`,
    en: `My apologies, I want to be sure I don't give you incorrect details: I couldn't verify that reservation code. May I check it again? If you prefer, you can write to the Flames team at ${TEAM}.`,
    th: `ขออภัยครับ ผมต้องการให้ข้อมูลที่ถูกต้องแก่ท่าน แต่ไม่สามารถยืนยันรหัสการจองนั้นได้ ขออนุญาตตรวจสอบอีกครั้งนะครับ หรือท่านสามารถติดต่อทีมงาน Flames ได้ที่ ${TEAM}`,
  },
  unbacked_confirmation: {
    es: `Disculpe, quiero ser preciso: su reserva todavía no figura como confirmada en nuestro sistema. ¿Me permite revisar los datos y completarla ahora? Si lo prefiere, puede escribir al equipo de Flames a ${TEAM}.`,
    en: `My apologies, I want to be precise: your reservation does not yet appear as confirmed in our system. May I review the details and complete it now? If you prefer, you can write to the Flames team at ${TEAM}.`,
    th: `ขออภัยครับ ขอแจ้งให้ชัดเจนว่าการจองของท่านยังไม่ปรากฏว่าได้รับการยืนยันในระบบของเรา ขออนุญาตตรวจสอบรายละเอียดและดำเนินการให้เสร็จเลยนะครับ หรือท่านสามารถติดต่อทีมงาน Flames ได้ที่ ${TEAM}`,
  },
  leak: {
    es: `Disculpe, algo no ha salido bien al preparar mi respuesta. ¿Me permite intentarlo de nuevo? Si lo prefiere, puede escribir al equipo de Flames a ${TEAM}.`,
    en: `My apologies, something went wrong while preparing my reply. May I try again? If you prefer, you can write to the Flames team at ${TEAM}.`,
    th: `ขออภัยครับ เกิดข้อผิดพลาดระหว่างเตรียมคำตอบ ขออนุญาตลองอีกครั้งนะครับ หรือท่านสามารถติดต่อทีมงาน Flames ได้ที่ ${TEAM}`,
  },
};
return [{ json: { ...clean, output: SAFE[reason][lang], output_check: 'blocked', block_reason: reason,
                  unknown_codes: unknown, blocked_output: output } }];
