// "Build Change Email" (n8n Code, run once for all items) — used by ModifyReservation and CancelReservation (v2m).
// Input item = the row of "Modify Reservation" / "Cancel Reservation" (status 'modified' | 'cancelled').
// Sent automatically only to email_to, the address already stored on that booking (never one given in the chat).
// The .ics keeps the UID of the original confirmation (<code>@flames.demo-talay...) so calendars update the same
// event (SEQUENCE grows) or remove it (METHOD:CANCEL). Languages es/en/th (fallback en); no model-written text.
// SRC (the query node of the workflow) is prepended at build time; the node before this one is the calendar node.
const r = (typeof SRC !== 'undefined' ? $(SRC) : $input).first().json;
const trig = $('When Called by Agent').first().json;
const want = String(trig.language || r.guest_lang || '').toLowerCase().slice(0, 2);   // tool input, else the guest's stored language
const lang = ['es', 'en', 'th'].includes(want) ? want : 'en';
const cancelled = r.status === 'cancelled';

const VENUE = 'Flames · Talay Cliff Resort & Spa, Koh Samui';
const TEAM = 'np.flames.kohsamui@gmail.com';
const WEB = 'https://demo-talay.nomadprompters.es';
const parse = (d, t) => { const [y, m, dd] = d.split('-').map(Number); const [hh, mi] = t.split(':').map(Number); return { y, m, dd, hh, mi }; };

const L = {
  es: { days: ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'],
        months: ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'],
        date: (w, d, m, y) => `${w} ${d} de ${m} de ${y}`,
        subjMod: 'Su reserva en Flames ha cambiado', subjCan: 'Su reserva en Flames ha sido cancelada',
        hello: n => `Estimado/a ${n}:`, introMod: 'Le confirmamos el cambio en su reserva. Estos son los nuevos detalles:',
        introCan: 'Le confirmamos que su reserva ha sido cancelada:', code: 'Código', when: 'Fecha', time: 'Hora',
        people: 'Comensales', before: 'Antes', notes: 'Notas para la cocina',
        icsMod: 'El archivo adjunto actualiza el evento en su calendario.', icsCan: 'El archivo adjunto elimina el evento de su calendario.',
        notYou: `Si no ha sido usted quien ha hecho este cambio, escriba cuanto antes al equipo: ${TEAM}.`,
        again: `Si desea volver a reservar, Khun Aran le atiende en ${WEB}.`, bye: 'Un cordial saludo,', sign: 'Khun Aran · Flames',
        demo: 'Demostración de Nomad Prompters.' },
  en: { days: ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'],
        months: ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'],
        date: (w, d, m, y) => `${w} ${d} ${m} ${y}`,
        subjMod: 'Your reservation at Flames has changed', subjCan: 'Your reservation at Flames has been cancelled',
        hello: n => `Dear ${n},`, introMod: 'We confirm the change to your reservation. These are the new details:',
        introCan: 'We confirm that your reservation has been cancelled:', code: 'Code', when: 'Date', time: 'Time',
        people: 'Guests', before: 'Before', notes: 'Notes for the kitchen',
        icsMod: 'The attached file updates the event in your calendar.', icsCan: 'The attached file removes the event from your calendar.',
        notYou: `If you did not make this change, please write to the team as soon as possible: ${TEAM}.`,
        again: `If you would like to book again, Khun Aran is at ${WEB}.`, bye: 'Kind regards,', sign: 'Khun Aran · Flames',
        demo: 'A Nomad Prompters demo.' },
  th: { days: ['วันอาทิตย์', 'วันจันทร์', 'วันอังคาร', 'วันพุธ', 'วันพฤหัสบดี', 'วันศุกร์', 'วันเสาร์'],
        months: ['มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน', 'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'],
        date: (w, d, m, y) => `${w}ที่ ${d} ${m} ${y}`,
        subjMod: 'การจองของท่านที่ Flames มีการเปลี่ยนแปลง', subjCan: 'การจองของท่านที่ Flames ถูกยกเลิกแล้ว',
        hello: n => `เรียน คุณ${n}`, introMod: 'เราขอยืนยันการเปลี่ยนแปลงการจองของท่าน รายละเอียดใหม่มีดังนี้',
        introCan: 'เราขอยืนยันว่าการจองของท่านถูกยกเลิกแล้ว', code: 'รหัสการจอง', when: 'วันที่', time: 'เวลา',
        people: 'จำนวนผู้ร่วมรับประทาน', before: 'เดิม', notes: 'หมายเหตุสำหรับห้องครัว',
        icsMod: 'ไฟล์แนบจะอัปเดตกิจกรรมในปฏิทินของท่าน', icsCan: 'ไฟล์แนบจะลบกิจกรรมออกจากปฏิทินของท่าน',
        notYou: `หากท่านไม่ได้ทำการเปลี่ยนแปลงนี้ โปรดติดต่อทีมงานโดยเร็วที่ ${TEAM}`,
        again: `หากต้องการจองใหม่ Khun Aran ยินดีให้บริการที่ ${WEB}`, bye: 'ด้วยความเคารพ', sign: 'Khun Aran · Flames',
        demo: 'การสาธิตโดย Nomad Prompters' },
}[lang];

const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const fmt = (d) => { const p = parse(d, '00:00'); const wd = new Date(Date.UTC(p.y, p.m - 1, p.dd)).getUTCDay(); return L.date(L.days[wd], p.dd, L.months[p.m - 1], p.y); };
const rows = [[L.code, r.confirmation_code], [L.when, fmt(r.reservation_date)], [L.time, r.reservation_time], [L.people, r.people]];
if (!cancelled && (r.old_time !== r.reservation_time || r.old_people !== r.people || r.old_date_label !== r.date_label)) {
  rows.push([L.before, `${r.old_reservation_date ? fmt(r.old_reservation_date) : r.old_date_label} · ${r.old_time} · ${r.old_people}`]);
}
if (!cancelled && r.special_requests) rows.push([L.notes, r.special_requests]);

const html = `<div style="font-family:Georgia,serif;max-width:560px;margin:auto;color:#2b2b2b;line-height:1.5">
<p style="font-size:13px;letter-spacing:2px;color:#9a6b3f;margin:0 0 16px">FLAMES · TALAY CLIFF</p>
<p>${esc(L.hello(r.guest_name || ''))}</p><p>${esc(cancelled ? L.introCan : L.introMod)}</p>
<table style="border-collapse:collapse;width:100%;margin:12px 0">${rows.map(([k, v]) =>
  `<tr><td style="padding:6px 12px 6px 0;color:#777;vertical-align:top;white-space:nowrap">${esc(k)}</td><td style="padding:6px 0"><b>${esc(v)}</b></td></tr>`).join('')}</table>
<p>${esc(cancelled ? L.icsCan : L.icsMod)}</p>
<p style="font-size:14px"><b>${esc(L.notYou)}</b></p>${cancelled ? `<p style="font-size:14px">${esc(L.again)}</p>` : ''}
<p>${esc(L.bye)}<br>${esc(L.sign)}<br><span style="color:#777">${esc(VENUE)}</span></p>
<p style="font-size:11px;color:#aaa;margin-top:24px">${esc(L.demo)}</p></div>`;

const p2 = n => String(n).padStart(2, '0');
const utc = ms => { const t = new Date(ms); return `${t.getUTCFullYear()}${p2(t.getUTCMonth() + 1)}${p2(t.getUTCDate())}T${p2(t.getUTCHours())}${p2(t.getUTCMinutes())}00Z`; };
const p = parse(r.reservation_date, r.reservation_time);
const start = Date.UTC(p.y, p.m - 1, p.dd, p.hh - 7, p.mi);   // Asia/Bangkok = UTC+7, no DST
const icsEsc = s => String(s).replace(/\\/g, '\\\\').replace(/;/g, '\\;').replace(/,/g, '\\,').replace(/\n/g, '\\n');
const ics = ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//Nomad Prompters//Khun Aran//EN', `METHOD:${cancelled ? 'CANCEL' : 'PUBLISH'}`, 'BEGIN:VEVENT',
  `UID:${r.confirmation_code}@flames.demo-talay.nomadprompters.es`, `SEQUENCE:${cancelled ? 99 : Number(r.change_seq || 1)}`,
  `DTSTAMP:${utc(Date.now())}`, `DTSTART:${utc(start)}`, `DTEND:${utc(start + 120 * 60000)}`,
  `SUMMARY:${icsEsc(`Flames · ${r.confirmation_code}`)}`, `LOCATION:${icsEsc(VENUE)}`,
  ...(cancelled ? ['STATUS:CANCELLED'] : ['STATUS:CONFIRMED']), 'END:VEVENT', 'END:VCALENDAR'].join('\r\n');

return [{
  json: { to: r.email_to, subject: `${cancelled ? L.subjCan : L.subjMod} · ${fmt(r.reservation_date)} · ${r.confirmation_code}`, html },
  binary: { ics: { data: Buffer.from(ics, 'utf8').toString('base64'), mimeType: 'text/calendar', fileName: `flames-${r.confirmation_code}.ics` } },
}];
