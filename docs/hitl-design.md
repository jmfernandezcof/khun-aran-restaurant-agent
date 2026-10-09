# Diseño HITL (Hallazgo 7 / tarea #9) — borrador 2026-09-30

Estado (2026-10-04, noche): **pasos 1–3 en producción y probados; falta el paso 4.**
- ✅ 1. Tool `Khun Aran-Tool-RequestHuman` (`05H5T8yNvwq2q0sw`) activa y reforzada (3 casos/conversación/hora, textos recortados).
- ✅ 2. `Khun Aran-Staff-Bot` (`csuyowXjNUAvF6wc`): botón "Lo atiendo".
- ✅ 3. `Khun Aran-Staff-Reminders` (`VaVY7BcaDRntsfBG`): urgentes cada 5 min (máx. 3), normales cada 20 (máx. 2), 08:00–23:00.
- ✅ 4. (hecho 2026-10-04 noche, batería 12/12; ver CHANGELOG) Conectar `request_human` al agente (web y Telegram, mismo agente) y reescribir `# Human contact` del prompt (hoy dice que no puede avisar al equipo). Coste: una batería (~1 $) + prueba tipo demo (~0,10 $). Antes de la demo con Noemi (~7–8 oct), que se hará con pantalla compartida (web + Telegram del equipo).

**Decisiones pendientes del dueño antes del paso 4:**
1. En el canal Telegram, ¿vale como contacto el propio usuario de Telegram del huésped sin preguntar? (el equipo solo puede escribirle si tiene `@usuario` público).
2. ¿Abrir también un caso HITL cuando la revisión de salida bloquee una respuesta? Recomendado solo para `unbacked_confirmation` (el huésped podría presentarse sin mesa); hoy esos bloqueos solo mandan email.

Diseño original (2026-09-30):

## Por qué una tool y no solo prompt
El agente solo actúa a través de sus tools. Sin una tool que notifique al equipo, cualquier
"lo paso al equipo" es una promesa falsa (hallazgo 11). El prompt decide **cuándo** pedir un humano;
la tool es la que **avisa**. Solo cuando la tool devuelve `status='sent'` puede el agente decir que lo ha trasladado.

## Alcance
Quejas, eventos adversos (intoxicación, reacción alérgica, accidente, incidencias en sala), alergias graves,
peticiones especiales que no caben en `special_requests`, reservas que no se encuentran, fallos de tools,
y huéspedes que no saben o no quieren usar el chat.

## Canal
- **Bot del equipo** @KhunAranStaffAlert_bot (credencial n8n "Telegram — KhunAranStaffAlert", id `OHL5WqFngp1kkF8I`)
  que publica en el **grupo de Telegram del personal** "Flames Staff (demo)", chat_id `-1001234567890`.
  Privacy mode activo (solo ve comandos y respuestas a sus mensajes; los callbacks de botones sí le llegan).
- Bot de huéspedes **ya sustituido** (2026-09-30) por @KhunAran_bot (credencial "Telegram — KhunAran (clientes)",
  id `fV3A7A4rfFSvjjKg`); ver CHANGELOG. Los bots de Telegram no pueden escribirse entre sí.
- **Pendiente antes de prod:** `/revoke` en BotFather de los tokens de ambos bots (se compartieron en una sesión de demo).
  Los tokens nunca van al repo ni a docs.
- La respuesta al huésped la da siempre **una persona**, por teléfono, email o Telegram. La tool exige
  al menos un contacto del huésped.

## Horario del equipo y promesa al huésped
- Personal disponible **08:00–23:00 (Asia/Bangkok)** — el equipo llega a las 8:00 a preparar; configurable.
- Dentro de horario: "una persona le contactará en menos de 30 minutos".
- Fuera de horario: "le contactarán a partir de las 8:00".

## Urgencia (dos niveles)
| Nivel | Casos | Aviso | Escalado |
|---|---|---|---|
| 🔴 urgente | evento adverso en curso, alergia grave para hoy, queja de alguien que está en el restaurante | alerta destacada en el grupo, botón **"Lo atiendo"** | sin coger en **5 min** → se reenvía (demo: al mismo grupo con alerta reforzada; real: al encargado de turno) |
| 🟡 normal | queja posterior, peticiones especiales, alergia para reserva futura, quiere hablar con alguien | mensaje en el grupo con botón **"Lo atiendo"** | objetivo < 30 min; recordatorio a los **20 min** |

Emergencia médica: el agente indica **primero** avisar al personal en persona y llamar al **1669**
(emergencias médicas de Tailandia). El chat nunca es la vía para una emergencia.

Encargado de turno: **sin definir (demo).** Cuando exista, su Telegram ID va en la configuración.

## Piezas a construir
1. Sub-workflow `Khun Aran-Tool-RequestHuman` conectado al agente. Entrada: motivo, urgencia, resumen,
   contacto del huésped, código FLM y nombre si los hay. Salida: `status='sent'` + número de caso.
2. Tabla en BD de casos (id, motivo, urgencia, estado, quién lo coge, timestamps) para medir los 30 min.
3. Workflow del bot del equipo: callback del botón "Lo atiendo" + temporizadores de escalado/recordatorio.
4. Prompt: cuándo llamar a la tool; reactivar traslados al equipo y lista de espera (retirados en la #6b);
   sustituir el email de contacto provisional.

Cada pieza con backup, diff, OK del dueño y entrada en el CHANGELOG, como el resto.

**Nota (2026-09-30):** antes de conectar `Khun Aran-Tool-RequestHuman` al agente, hay que **activarlo** (`POST /workflows/05H5T8yNvwq2q0sw/activate`). En n8n 2.40, un sub-workflow inactivo usado como tool falla con "Workflow is not active and cannot be executed" (se vio con FindDishes).
