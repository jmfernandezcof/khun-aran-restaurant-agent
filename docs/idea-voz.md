# Voz en el chat web — plan (2026-10-03)

Estado: **construido y en producción el 2026-10-04** (ver CHANGELOG: `/voice` solo transcribe y la web manda el texto por `/chat`). Lo de abajo es el plan original. Objetivo: que el huésped pueda hablar en vez de teclear, listo antes de la demo con Noemi (~7–8 de octubre).

## Decisiones
- Transcripción con **OpenAI** (Anthropic no transcribe audio). Credencial n8n **"OpenAI - Khun Aran - Voice"** (`meVoCWa85pLdKZvx`), creada por el dueño el 2026-10-03 en una cuenta con saldo (no la de Fernando, sin saldo). La clave nunca pasa por el chat ni el repo.
- La respuesta sigue siendo **texto**; leerla en voz alta (TTS) sería una fase 2 opcional.
- **No se guarda el audio**: solo el texto transcrito, que entra a Khun Aran igual que un mensaje escrito.

## Piezas
1. **n8n**: workflow nuevo que recibe el audio, lo transcribe y pasa el texto al agente (mismo `session_id`), devolviendo transcripción + respuesta.
2. **nginx + Traefik**: ruta `/voice` aparte (hoy `/chat` admite 8 KB): solo POST, tamaño máximo para ~60 s de audio, límite de mensajes por minuto por visitante (`CF-Connecting-IP`). Requiere recrear el contenedor web (segundos sin servicio).
3. **Web** (`app/static/index.html`): botón 🎤, grabación con MediaRecorder (webm/opus; Safari/iPhone graba mp4), máximo ~60 s, mostrar la transcripción como mensaje del huésped.
4. **Privacidad**: añadir al aviso que la voz se transcribe con un proveedor externo y que el audio no se conserva. En la cuenta de OpenAI, límite de gasto (p. ej. 5 $/mes).

## Pruebas
- Audio de ejemplo contra el workflow (céntimos).
- Móvil real: Android (Chrome) e iPhone (Safari).
- Abuso: audio > tamaño máximo → 413; ráfaga → 429; sin audio → error claro.

## Riesgos
- Errores de transcripción en teléfonos y nombres: Khun Aran ya lee los datos antes de reservar.
- Toca la web pública a pocos días de la demo: hacerlo con rollback (copias de `nginx.conf`, compose e `index.html`).
