# Idea futura — Memoria del huésped (reconocimiento de clientes recurrentes)

Estado: **idea**, sin implementar. Propuesta de José María, 2026-09-30.

## Qué

Que Khun Aran reconozca a quien ya ha venido y lo trate como un maître de lujo: qué comió, en qué mesa o zona se sentó, alergias, valoraciones e incidencias pasadas, y ocasiones (aniversarios, cumpleaños).

Ejemplo: *"Qué alegría tenerle de vuelta, señor Regresion. ¿Le reservo de nuevo en la terraza? Y seguimos teniendo presente su alergia al marisco, ¿verdad?"*

## Lo que ya existe en la BD

- `customers` (upsert por canal/teléfono) → `customer_id` estable.
- `reservations`: `zone`, `table_number`, `special_requests`, `status`, `pos_order_id` (enganche previsto con el TPV = qué comieron).
- `reservation_change_log`: historial de altas, cambios y cancelaciones.

## Piezas que faltarían

1. **Modelo de datos**
   - `guest_profile`: alergias, preferencias (zona, vino, mesa favorita), ocasiones, nivel VIP, notas del equipo.
   - `guest_feedback`: valoración, comentario, incidencia (sí/no), resuelta (sí/no), fecha y reserva.
   - Visitas = reservas con estado completado + mesa + pedido del TPV.
2. **Captura** (lo difícil no es leer, es llenar los datos)
   - Tras el servicio, el equipo marca mesa, incidencias y notas: formulario n8n o bot de Telegram para el personal.
   - Platos: integración TPV vía `pos_order_id`.
   - Valoración: mensaje al día siguiente (email/WhatsApp) con 1–5 y comentario → `guest_feedback`.
   - Alergias y ocasiones: las que el huésped cuenta en el chat se guardan con su consentimiento.
3. **Uso en el agente**
   - Tool nueva `get_guest_profile(customer_id)` que devuelve un **resumen corto**, no filas crudas.
   - Reglas de prompt: mencionarlo con sutileza; lo negativo nunca de frente ("esta vez nos aseguraremos de que todo esté perfecto"); alergias siempre confirmadas, nunca dadas por supuestas.

## Pregunta "¿es su primera vez en Flames?"

Propuesta de José María (2026-09-30). Sí, pero como **gesto de hospitalidad dentro del flujo de reserva**, no como control de identidad al entrar:
- Preguntarlo al reservar, justo cuando ya se pide el teléfono. Pedir el teléfono antes, sin reserva de por medio, añade fricción y choca con la minimización de datos de la PDPA (hay que avisar del propósito al recogerlo).
- La respuesta del huésped no es prueba de identidad: sirve para el tono ("¡bienvenido de nuevo!") y para la estadística, no para revelar historial.
- Si dice que ya vino y el teléfono coincide con una ficha, se vincula en silencio; mostrar datos de esa ficha (alergias, mesa, visitas) solo tras verificar (OTP o código de reserva).

## Ficha de cliente con PIN elegido por el huésped

Propuesta de José María (2026-09-30): al terminar la primera reserva, tras el consentimiento, ofrecer abrir ficha ("Flames Club") con un PIN personal para identificarse en futuras conversaciones.

Encaja bien (verificación sin coste de SMS, opt-in, sensación de exclusividad), con estas condiciones:
- **El PIN nunca pasa por el chat.** Todo mensaje del chat va al modelo y se guarda en la memoria de Postgres. El PIN se introduce en un **campo propio del widget** que llama a un webhook aparte (no al agente) y devuelve "verificado" para esa sesión.
- **Guardar solo el hash** (bcrypt/argon2), nunca el PIN en claro.
- **Límite de intentos** por teléfono (p. ej. 5 fallos → bloqueo temporal), porque un PIN de 4–6 cifras se adivina probando.
- **Recuperación** si lo olvida: hace falta un segundo canal (SMS/WhatsApp/email), así que el OTP acaba siendo necesario igualmente.
- **"Acuerdo firmado"** = consentimiento electrónico de perfilado con su versión en `legal_notices`, fecha, canal y aceptación explícita; separado del consentimiento de la reserva y del de alergias. Validar el texto con asesoría legal para cliente real.
- Alternativa más moderna a valorar: enlace mágico o OTP por WhatsApp (sin memorizar nada).

## Privacidad (PDPA) — no negociable

- **Verificar identidad antes de revelar nada.** En la web cualquiera puede escribir un teléfono ajeno: sin verificar (código de reserva, OTP por SMS/WhatsApp) no se muestra historial ni alergias.
- **Las alergias son datos de salud = datos sensibles** (PDPA, sección 26): exigen consentimiento **explícito** y separado del de la reserva.
- Consentimiento de perfilado ("personalizar su experiencia") con su propia versión en `legal_notices`, retención definida y derecho a borrado.

## Camino sugerido

1. **Para la demo (rápido):** sembrar un huésped ficticio con historial (2 visitas, alergia, una incidencia resuelta, aniversario) y la tool de lectura. Enseña el "efecto maître" sin integrar TPV ni encuestas.
2. **Piloto real:** consentimientos PDPA + captura por el equipo + encuesta post-visita.
3. **Completo:** integración TPV (platos) y OTP para reconocer en la web antes de reservar.
