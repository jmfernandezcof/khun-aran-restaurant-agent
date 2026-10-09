// Khun Aran-Tool-SendConfirmation, node "Build Email" (n8n Code, run once for all items).
// Builds subject + HTML + .ics from the "Claim Send" row (DB data only; nothing written by the model).
// Languages: es, en, th (fallback en). The date words come from code, not from the model.
const r = $('Claim Send').first().json;
const lang = ['es', 'en', 'th'].includes(String($('When Called by Agent').first().json.language || '').toLowerCase())
  ? String($('When Called by Agent').first().json.language).toLowerCase() : 'en';

const VENUE = 'Flames · Talay Cliff Resort & Spa, Koh Samui';
const TEAM = 'np.flames.kohsamui@gmail.com';
const WEB = 'https://demo-talay.nomadprompters.es';
const [y, m, d] = r.reservation_date.split('-').map(Number);
const [hh, mi] = r.reservation_time.split(':').map(Number);
const wd = new Date(Date.UTC(y, m - 1, d)).getUTCDay(); // 0 = Sunday

const L = {
  es: { days: ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'],
        months: ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'],
        date: (w, dd, mm, yy) => `${w} ${dd} de ${mm} de ${yy}`,
        subject: 'Su reserva en Flames', hello: n => `Estimado/a ${n}:`, intro: 'Le confirmamos su reserva en Flames. Estos son los detalles:',
        code: 'Código', when: 'Fecha', time: 'Hora', people: 'Comensales', zone: 'Zona', notes: 'Notas para la cocina',
        zones: { indoor: 'Interior', terrace: 'Terraza' },
        change: `Para modificar o cancelar su reserva, escriba a Khun Aran en ${WEB} indicando su código y el teléfono con el que reservó, o al equipo en ${TEAM}.`,
        ics: 'Añada la reserva a su calendario con el archivo adjunto.', bye: 'Le esperamos. Un cordial saludo,', sign: 'Khun Aran · Flames',
        demo: 'Demostración de Nomad Prompters.' },
  en: { days: ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'],
        months: ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'],
        date: (w, dd, mm, yy) => `${w} ${dd} ${mm} ${yy}`,
        subject: 'Your reservation at Flames', hello: n => `Dear ${n},`, intro: 'We are pleased to confirm your reservation at Flames. Here are the details:',
        code: 'Code', when: 'Date', time: 'Time', people: 'Guests', zone: 'Area', notes: 'Notes for the kitchen',
        zones: { indoor: 'Indoor', terrace: 'Terrace' },
        change: `To change or cancel your booking, write to Khun Aran at ${WEB} with your code and the phone number you booked with, or to the team at ${TEAM}.`,
        ics: 'Add the booking to your calendar with the attached file.', bye: 'We look forward to welcoming you. Kind regards,', sign: 'Khun Aran · Flames',
        demo: 'A Nomad Prompters demo.' },
  th: { days: ['วันอาทิตย์', 'วันจันทร์', 'วันอังคาร', 'วันพุธ', 'วันพฤหัสบดี', 'วันศุกร์', 'วันเสาร์'],
        months: ['มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน', 'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'],
        date: (w, dd, mm, yy) => `${w}ที่ ${dd} ${mm} ${yy}`,
        subject: 'การจองของท่านที่ Flames', hello: n => `เรียน คุณ${n}`, intro: 'เรายินดีขอยืนยันการจองของท่านที่ Flames รายละเอียดมีดังนี้',
        code: 'รหัสการจอง', when: 'วันที่', time: 'เวลา', people: 'จำนวนผู้ร่วมรับประทาน', zone: 'โซน', notes: 'หมายเหตุสำหรับห้องครัว',
        zones: { indoor: 'ในร่ม', terrace: 'ระเบียง' },
        change: `หากต้องการเปลี่ยนแปลงหรือยกเลิกการจอง โปรดติดต่อ Khun Aran ที่ ${WEB} พร้อมรหัสการจองและหมายเลขโทรศัพท์ที่ใช้จอง หรือติดต่อทีมงานที่ ${TEAM}`,
        ics: 'ท่านสามารถเพิ่มการจองลงในปฏิทินได้จากไฟล์แนบ', bye: 'เรายินดีที่จะได้ต้อนรับท่าน ด้วยความเคารพ', sign: 'Khun Aran · Flames',
        demo: 'การสาธิตโดย Nomad Prompters' },
}[lang];

const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const dateText = L.date(L.days[wd], d, L.months[m - 1], y);
const time = r.reservation_time;
const rows = [[L.code, r.confirmation_code], [L.when, dateText], [L.time, time], [L.people, r.people]];
if (r.zone) rows.push([L.zone, L.zones[r.zone] || r.zone]);
if (r.special_requests) rows.push([L.notes, r.special_requests]);

const html = `<div style="font-family:Georgia,serif;max-width:560px;margin:auto;color:#2b2b2b;line-height:1.5">
<p style="font-size:13px;letter-spacing:2px;color:#9a6b3f;margin:0 0 16px">FLAMES · TALAY CLIFF</p>
<p>${esc(L.hello(r.guest_name))}</p><p>${esc(L.intro)}</p>
<table style="border-collapse:collapse;width:100%;margin:12px 0">${rows.map(([k, v]) =>
  `<tr><td style="padding:6px 12px 6px 0;color:#777;vertical-align:top;white-space:nowrap">${esc(k)}</td><td style="padding:6px 0"><b>${esc(v)}</b></td></tr>`).join('')}</table>
<p>${esc(L.ics)}</p><p style="font-size:14px">${esc(L.change)}</p>
<p>${esc(L.bye)}<br>${esc(L.sign)}<br><span style="color:#777">${esc(VENUE)}</span></p>
<p style="font-size:11px;color:#aaa;margin-top:24px">${esc(L.demo)}</p></div>`;

// .ics in UTC (Asia/Bangkok is UTC+7 all year, no DST). Duration = 2 h (restaurant_config.reservation_slot_minutes).
const p2 = n => String(n).padStart(2, '0');
const utc = ms => { const t = new Date(ms); return `${t.getUTCFullYear()}${p2(t.getUTCMonth() + 1)}${p2(t.getUTCDate())}T${p2(t.getUTCHours())}${p2(t.getUTCMinutes())}00Z`; };
const start = Date.UTC(y, m - 1, d, hh - 7, mi);
const icsEsc = s => String(s).replace(/\\/g, '\\\\').replace(/;/g, '\;').replace(/,/g, '\\,').replace(/\n/g, '\\n');
const ics = ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//Nomad Prompters//Khun Aran//EN', 'METHOD:PUBLISH', 'BEGIN:VEVENT',
  `UID:${r.confirmation_code}@flames.demo-talay.nomadprompters.es`, `DTSTAMP:${utc(Date.now())}`,
  `DTSTART:${utc(start)}`, `DTEND:${utc(start + 120 * 60000)}`,
  `SUMMARY:${icsEsc(`Flames · ${r.confirmation_code}`)}`, `LOCATION:${icsEsc(VENUE)}`,
  `DESCRIPTION:${icsEsc(`${L.code}: ${r.confirmation_code} · ${L.people}: ${r.people}`)}`,
  'END:VEVENT', 'END:VCALENDAR'].join('\r\n');

return [{
  json: { to: r.email, subject: `${L.subject} · ${dateText} · ${r.confirmation_code}`, html, reservation_id: r.claimed_reservation_id },
  binary: { ics: { data: Buffer.from(ics, 'utf8').toString('base64'), mimeType: 'text/calendar', fileName: `flames-${r.confirmation_code}.ics` } },
}];
