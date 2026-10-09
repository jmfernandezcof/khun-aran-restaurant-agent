-- Flames / Khun Aran — reservation management v1
-- Adds a public confirmation code without exposing reservation_id.
-- Safe to run more than once.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- These fields are consumed by the active availability/create tools.
-- They were present in production drift but missing from the original template.
ALTER TABLE restaurant_config
  ADD COLUMN IF NOT EXISTS reservation_slot_minutes INTEGER NOT NULL DEFAULT 120;
ALTER TABLE restaurant_config
  ADD COLUMN IF NOT EXISTS max_reservation_days_ahead INTEGER NOT NULL DEFAULT 90;
UPDATE restaurant_config
SET reservation_slot_minutes = 120,
    max_reservation_days_ahead = 90
WHERE internal_id = 'maite_flames_kohsamui';

ALTER TABLE reservations
  ADD COLUMN IF NOT EXISTS confirmation_code VARCHAR(20);

-- Existing rows need a code before the unique index and NOT NULL constraint.
UPDATE reservations
SET confirmation_code = 'FLM-' || upper(substr(replace(uuid_generate_v4()::text, '-', ''), 1, 10))
WHERE confirmation_code IS NULL OR btrim(confirmation_code) = '';

CREATE UNIQUE INDEX IF NOT EXISTS uq_reservations_confirmation_code
  ON reservations (confirmation_code);

ALTER TABLE reservations
  ALTER COLUMN confirmation_code SET NOT NULL;

CREATE TABLE IF NOT EXISTS reservation_change_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reservation_id INTEGER NOT NULL REFERENCES reservations(reservation_id),
  action VARCHAR(20) NOT NULL CHECK (action IN ('created','modified','cancelled')),
  old_values JSONB,
  new_values JSONB,
  actor VARCHAR(50) NOT NULL DEFAULT 'khun_aran',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reservation_change_log_reservation
  ON reservation_change_log (reservation_id, created_at DESC);

-- Public codes are intentionally opaque and never use the numeric reservation ID.
COMMENT ON COLUMN reservations.confirmation_code IS
  'Guest-facing opaque confirmation code, e.g. FLM-7A2C91D4E0';
