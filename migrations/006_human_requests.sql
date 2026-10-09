-- 006_human_requests.sql
-- HITL (hallazgo 7 / tarea #9): casos que el agente traslada al equipo vía
-- Khun Aran-Tool-RequestHuman. Diseño en docs/hitl-design.md.
--
-- Una fila por aviso. El sub-workflow la crea (status 'open') y publica en el grupo
-- del personal; el botón "Lo atiendo" la pasa a 'claimed'; los temporizadores leen
-- las filas 'open' para reenviar (urgente, 5 min) o recordar (normal, 20 min).
-- Objetivo de atención: claimed_at - created_at < 30 min (dentro de horario).
--
-- Contiene PII (nombre y contacto del huésped): mismo tratamiento PDPA que customers.
-- Sin FK a reservations/customers a propósito: el caso debe poder crearse aunque la
-- reserva no exista o la tool de reservas falle (son dos de los motivos).
--
-- Se ejecuta como n8n, pero la tabla debe pertenecer a flames_kohsamui: es el usuario de la
-- credencial Postgres de n8n y dueño del resto de tablas. Si no, falla con "permission denied".
--
-- ROLLBACK:
--   DROP TABLE IF EXISTS human_requests;

CREATE TABLE IF NOT EXISTS human_requests (
    id                BIGSERIAL PRIMARY KEY,
    channel           TEXT        NOT NULL CHECK (channel IN ('web', 'telegram')),
    session_key       TEXT,
    reason            TEXT        NOT NULL CHECK (reason IN (
                          'complaint', 'adverse_event', 'severe_allergy', 'special_request',
                          'reservation_not_found', 'tool_failure', 'wants_human')),
    urgency           TEXT        NOT NULL CHECK (urgency IN ('urgent', 'normal')),
    summary           TEXT        NOT NULL,
    guest_name        TEXT,
    guest_contact     TEXT        NOT NULL,          -- teléfono, email o @telegram (al menos uno)
    confirmation_code TEXT,                          -- FLM-… si lo hay
    language          TEXT,
    within_hours      BOOLEAN     NOT NULL,          -- 08:00–23:00 Asia/Bangkok al crearse
    status            TEXT        NOT NULL DEFAULT 'open'
                          CHECK (status IN ('open', 'claimed', 'resolved', 'cancelled')),
    staff_chat_id     BIGINT,                        -- grupo donde se publicó
    staff_message_id  BIGINT,                        -- mensaje con el botón "Lo atiendo"
    claimed_by_name   TEXT,
    claimed_by_tg_id  BIGINT,
    escalation_count  INTEGER     NOT NULL DEFAULT 0, -- reenvíos (urgente) o recordatorios (normal)
    last_escalated_at TIMESTAMPTZ,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    claimed_at        TIMESTAMPTZ,
    resolved_at       TIMESTAMPTZ
);

-- Para los temporizadores: casos abiertos por antigüedad.
CREATE INDEX IF NOT EXISTS human_requests_open_idx
    ON human_requests (created_at) WHERE status = 'open';

-- Mismo propietario que el resto de tablas (usuario de la credencial de n8n).
ALTER TABLE human_requests OWNER TO flames_kohsamui;
