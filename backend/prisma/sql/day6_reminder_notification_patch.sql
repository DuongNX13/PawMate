ALTER TYPE "ReminderStatus" ADD VALUE IF NOT EXISTS 'done';

ALTER TABLE reminders
  ADD COLUMN IF NOT EXISTS note TEXT,
  ADD COLUMN IF NOT EXISTS next_trigger_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS last_triggered_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS timezone TEXT NOT NULL DEFAULT 'Asia/Bangkok',
  ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS snoozed_until TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

UPDATE reminders
SET next_trigger_at = reminder_at
WHERE next_trigger_at IS NULL
  AND status = 'scheduled'
  AND deleted_at IS NULL;

ALTER TABLE notifications
  ADD COLUMN IF NOT EXISTS dismissed_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS reminders_pet_deleted_reminder_at_idx
  ON reminders (pet_id, deleted_at, reminder_at);

CREATE INDEX IF NOT EXISTS reminders_created_by_status_next_trigger_idx
  ON reminders (created_by_user_id, status, next_trigger_at);

CREATE INDEX IF NOT EXISTS notifications_user_dismissed_read_created_idx
  ON notifications (user_id, dismissed_at, read_at, created_at DESC);
