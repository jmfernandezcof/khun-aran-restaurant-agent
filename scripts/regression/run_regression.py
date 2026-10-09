#!/usr/bin/env python3
"""Batería de regresión de Khun Aran: ¿sigue todo bien tras cambiar de modelo o de prompt? Run by the owner.

Usage: run_regression.py [--keep] [--only N,M]
  Talks to the PUBLIC chat (https://demo-talay.nomadprompters.es/chat) like a guest, one fresh session per scenario,
  with test phones +447700900nnn (Ofcom range reserved for fiction), paced to 10 msg/min (under our own 12/min limit). Adaptive answers
  (allergies → "ninguna", consent → "Acepto", confirmation → "sí"). Checks the DATABASE, not only the wording.
  Sends no emails. At the end it cancels through the chat every booking it created (this also removes their calendar
  events) and deletes its test rows from the DB, unless --keep.
Cost: a few cents per run. Duration: ~6–10 min. Report: scripts/regression/last_run.json
"""
import json, re, subprocess, sys, time, urllib.request, uuid

URL = "https://demo-talay.nomadprompters.es/chat"
PACE = 6.0                       # seconds between messages (10/min)
RUN = time.strftime("%H%M")      # makes test phones unique per run
ONLY = {int(x) for x in sys.argv[sys.argv.index("--only") + 1].split(",")} if "--only" in sys.argv else None
KEEP = "--keep" in sys.argv
_last = [0.0]


def psql(sql):
    r = subprocess.run(["docker", "exec", "root-n8n-postgres", "psql", "-U", "n8n", "-d", "maite_flames_kohsamui",
                        "-At", "-F", "|", "-c", sql], capture_output=True, text=True)
    return [l.split("|") for l in r.stdout.strip().splitlines() if l]


def say(sid, msg):
    wait = PACE - (time.time() - _last[0])
    if wait > 0:
        time.sleep(wait)
    _last[0] = time.time()
    body = json.dumps({"session_id": sid, "message": msg, "lang": "multi"}).encode()
    req = urllib.request.Request(URL, data=body, method="POST",
                                 headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 khun-aran-regression"})
    for attempt in (1, 2):   # one retry: a reply lost between Cloudflare and us is a network blip, not an agent failure
        try:
            with urllib.request.urlopen(req, timeout=90) as r:
                return json.load(r).get("reply", "")
        except Exception as e:
            err = e
            if "timed out" not in str(e) or attempt == 2:
                break
            print(f"   (reintento tras tiempo agotado: {e})")
    return f"__ERROR__ {err}"


TEST_PREFIX = "+447700900"     # UK Ofcom range reserved for fiction: never a real person


def phone(n):
    return f"{TEST_PREFIX}{n:03d}"


def bookings(ph):
    return psql("select r.confirmation_code, r.reservation_date, to_char(r.reservation_time,'HH24:MI'), r.people, r.status, "
                "coalesce(r.special_requests,''), r.reservation_id from reservations r join customers c using(customer_id) "
                f"where c.channel_user_id = 'phone:{ph}' order by r.reservation_id")


def converse(first, ph, max_turns=7, stop=None, facts=None, accept=True, until_booked=True):
    """First message, then a simulated guest that answers ONLY what is asked, from its own scenario facts.
    facts: {'allergies': str, 'zone': str, 'name': str}. accept=False → never agrees to book, choose or confirm
    (scenarios where nothing must be booked); it answers 'No, gracias' instead."""
    f = {"allergies": "Ninguna", "zone": "Interior", "name": "Test Regresion"}
    f.update(facts or {})
    sid, log = str(uuid.uuid4()), []
    reply = say(sid, first); log.append(("guest", first)); log.append(("aran", reply))
    for _ in range(max_turns):
        if stop and stop(reply):
            break
        if until_booked and ph and any(b[4] == "confirmed" for b in bookings(ph)):
            break
        low = reply.lower()
        if "__error__" in low or not re.search(r"\?|¿", reply):
            break                                   # nothing asked → the guest has nothing to answer
        ask = " ".join(re.findall(r"[^.?!¿]*¿?[^.?!¿]*\?", low)) or low       # only the questions, not statements
        if not accept:
            ans = "No, gracias, de momento no."
        elif re.search(r"consent|consentimiento|ยินยอม", ask):
            ans = "Acepto"
        elif re.search(r"apellido|surname|nombre|name|teléfono|telefono|phone", ask):
            ans = f"{f['name']}" + (f", {ph}" if ph else "")
        elif re.search(r"alerg|allerg|restricci|dietary", ask):
            ans = f["allergies"]
        elif re.search(r"terraza|terrace|interior|indoor|zona|zone", ask):
            ans = f["zone"]
        elif re.search(r"ocasi|celebra|occasion", ask):
            ans = "No, ninguna ocasión especial"
        else:
            ans = "Sí, confirmo"
        reply = say(sid, ans); log.append(("guest", ans)); log.append(("aran", reply))
    return log


R = []


def check(n, name, ok, detail, log=None):
    R.append({"n": n, "scenario": name, "ok": bool(ok), "detail": detail, "log": log or []})
    print(f"{'PASS' if ok else 'FAIL'}  {n:>2}. {name} — {detail}")


def want(n):
    return ONLY is None or n in ONLY


def purge_test_rows():
    pat = f"phone:{TEST_PREFIX}%"
    psql("begin; delete from reservation_change_log where reservation_id in (select reservation_id from reservations r join customers c using(customer_id) "
         f"where c.channel_user_id like '{pat}'); delete from reservations where customer_id in (select customer_id from customers where channel_user_id like '{pat}'); "
         f"delete from customer_consents where customer_id in (select customer_id from customers where channel_user_id like '{pat}'); "
         f"delete from customers where channel_user_id like '{pat}'; commit;")


left = psql(f"select count(*) from reservations r join customers c using(customer_id) where c.channel_user_id like 'phone:{TEST_PREFIX}%' and r.status='confirmed'")
if left and left[0][0] != "0":
    sys.exit(f"ABORT: {left[0][0]} confirmed test bookings from a previous --keep run still exist; cancel them in the chat first (their calendar events).")
purge_test_rows()
created = []   # (code, phone) to cancel at the end

# 1. Fecha relativa + reserva completa
if want(1):
    ph = phone(1)
    log = converse(f"Mesa para 2 el segundo domingo de diciembre a las 21:00, a nombre de Test Regresion, teléfono {ph}, interior", ph)
    b = [x for x in bookings(ph) if x[4] == "confirmed"]
    said14 = any(re.search(r"\b14\b", m) for w, m in log if w == "aran")
    check(1, "segundo domingo de diciembre → 13", b and b[0][1] == "2026-12-13" and not said14,
          f"BD={b[0][1] if b else 'sin reserva'}; dijo '14'={said14}", log)
    created += [(x[0], ph) for x in b]

# 2. Alergia mencionada al principio → se guarda
if want(2):
    ph = phone(2)
    log = converse(f"Hola, mesa para 2 el viernes 23 de octubre a las 20:00. Mi pareja es alérgica a los frutos secos. Soy Test Regresion, {ph}", ph,
                   facts={"allergies": "Solo la de mi pareja, frutos secos"})
    b = [x for x in bookings(ph) if x[4] == "confirmed"]
    ok = b and re.search(r"fruto|nut|tree_nut", b[0][5], re.I)
    check(2, "alergia guardada en la reserva", ok, f"special_requests={b[0][5][:80] if b else 'sin reserva'}", log)
    created += [(x[0], ph) for x in b]

# 3. Modificar en el sitio (mismo código, alergia conservada, registro)
if want(3) and any(p == phone(2) for _, p in created):
    code = next(c for c, p in created if p == phone(2)); ph = phone(2)
    before = bookings(ph)
    log = converse(f"Quiero cambiar mi reserva {code}, teléfono {ph}, a las 21:30. Mismo día y mismas personas.", ph, max_turns=3, until_booked=False,
                   stop=lambda r: bool(re.search(r"21:30", r)) and not re.search(r"\?|¿", r))
    after = bookings(ph)
    same = len(after) == len(before) and after and after[-1][0] == code and after[-1][2] == "21:30" and after[-1][4] == "confirmed"
    kept = after and re.search(r"fruto|nut", after[-1][5], re.I)
    logged = psql(f"select count(*) from reservation_change_log l join reservations r using(reservation_id) where r.confirmation_code='{code}' and l.action='modified'")
    check(3, "modificar = misma reserva (sin cancelar)", same and kept and logged and logged[0][0] != "0",
          f"reservas antes/después={len(before)}/{len(after)}; hora={after[-1][2] if after else '-'}; alergia conservada={bool(kept)}; registros={logged[0][0] if logged else 0}", log)

# 4. Noche de gala → al equipo, sin reserva
if want(4):
    ph = phone(4)
    log = converse(f"Mesa para 2 el 24 de diciembre a las 20:00, Test Regresion, {ph}", ph, max_turns=2, accept=False)
    b = bookings(ph); txt = " ".join(m for w, m in log if w == "aran").lower()
    check(4, "gala 24-dic → equipo, sin reserva", not b and re.search(r"gala|nochebuena|christmas", txt) and "np.flames" in txt,
          f"reservas={len(b)}; menciona gala={bool(re.search(r'gala|nochebuena', txt))}; da contacto={'np.flames' in txt}", log)

# 5. Día sin alcohol
if want(5):
    log = converse("¿Tenéis mesa para 2 el 26 de octubre a las 20:00? ¿Qué vino nos recomiendas?", None, max_turns=0)
    txt = " ".join(m for w, m in log if w == "aran").lower()
    check(5, "26-oct avisa: sin alcohol", re.search(r"alcohol", txt) and not re.search(r"le recomiendo (el|un) (vino|tinto|blanco)", txt),
          f"menciona alcohol={'alcohol' in txt}", log)

# 6. Fuera de plazo → equipo, sin reserva
if want(6):
    ph = phone(6)
    log = converse(f"Queremos celebrar nuestro aniversario el 20 de enero, mesa para 2 a las 20:00. Test Regresion {ph}", ph, max_turns=3, accept=False)
    b = bookings(ph); txt = " ".join(m for w, m in log if w == "aran").lower()
    check(6, "fuera de plazo → equipo, sin reserva", not b and "np.flames" in txt, f"reservas={len(b)}; da contacto={'np.flames' in txt}", log)

# 7. Grupo grande → equipo, sin reserva
if want(7):
    ph = phone(7)
    log = converse(f"Mesa para 15 personas el sábado 17 de octubre a las 20:00, Test Regresion, {ph}, sin alergias", ph, max_turns=3, accept=False)
    b = bookings(ph)
    check(7, "grupo de 15 → equipo, sin reserva", not b, f"reservas={len(b)}", log)

# 8. Fuera de horario
if want(8):
    log = converse("Mesa para 2 el martes 20 de octubre a las 17:00", None, max_turns=0)
    txt = " ".join(m for w, m in log if w == "aran")
    check(8, "17:00 fuera de horario → propone otra hora", re.search(r"18:00|18:30|19:00|cena|dinner", txt, re.I),
          "propone hora de cena" if re.search(r"18:00|18:30|19:00", txt) else "no propone hora", log)

# 9. Inglés
if want(9):
    log = converse("Hi! Do you have a table for 2 on Saturday 31 October at 8pm?", None, max_turns=0)
    txt = " ".join(m for w, m in log if w == "aran")
    eng = len(re.findall(r"\b(the|you|your|table|would)\b", txt, re.I)) >= 3 and not re.search(r"\b(usted|mesa|reserva)\b", txt, re.I)
    check(9, "responde en el idioma del huésped (inglés)", eng and re.search(r"Saturday", txt), "inglés y 'Saturday'" if eng else "no responde en inglés", log)

# 10. Consultar la reserva (find)
if want(10) and created:
    code, ph = created[0]
    log = converse(f"¿Me confirmas los datos de mi reserva {code}? Mi teléfono es {ph}", None, max_turns=0)
    txt = " ".join(m for w, m in log if w == "aran")
    check(10, "consultar reserva con código + teléfono", re.search(r"13|23|21:30|21:00", txt), "devuelve fecha/hora" if re.search(r"13|23", txt) else "sin datos", log)

# Limpieza: cancelar por el chat TODA reserva confirmada de teléfonos de prueba (también las no previstas, p. ej. un
# modelo que reserva una alternativa que nadie eligió) → prueba cancel y borra sus eventos de Calendar.
leftover = psql("select r.confirmation_code, c.channel_user_id from reservations r join customers c using(customer_id) "
                f"where c.channel_user_id like 'phone:{TEST_PREFIX}%' and r.status='confirmed' order by r.reservation_id")
for code, cu in ([] if KEEP else leftover):
    ph = cu.replace("phone:", "")
    unexpected = (code, ph) not in created
    log = converse(f"Quiero cancelar mi reserva {code}, teléfono {ph}", ph, max_turns=3, until_booked=False,
                   stop=lambda r: bool(re.search(r"cancelad|cancelled", r, re.I)) and not re.search(r"\?|¿", r))
    st = [b for b in bookings(ph) if b[0] == code]
    check(90, f"cancelar {code} por el chat" + (" (reserva NO prevista)" if unexpected else ""),
          st and st[-1][4] == "cancelled", f"estado={st[-1][4] if st else '-'}", log)
still = psql("select count(*) from reservations r join customers c using(customer_id) "
             f"where c.channel_user_id like 'phone:{TEST_PREFIX}%' and r.status='confirmed'")
if not KEEP and still and still[0][0] != "0":
    print(f"ATENCION: {still[0][0]} reservas de prueba siguen confirmadas: NO se borran filas (sus eventos de Calendar existen).")
    KEEP = True
if not KEEP:
    purge_test_rows()
    pat = f"phone:{TEST_PREFIX}%"
    print("Filas de prueba borradas:", psql(f"select count(*) from customers where channel_user_id like '{pat}'")[0][0], "clientes restantes")

ok = sum(r["ok"] for r in R)
print(f"\nRESULTADO: {ok}/{len(R)} correctos")
json.dump({"run": RUN, "results": R}, open(__file__.replace("run_regression.py", "last_run.json"), "w"), ensure_ascii=False, indent=1)
sys.exit(0 if ok == len(R) else 1)
