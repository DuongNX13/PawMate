-- Additive hardening for databases that applied the first Day 51 patch before
-- the concurrent mark-read regression was found by repository self-review.
\set ON_ERROR_STOP on

BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '60s';

CREATE OR REPLACE FUNCTION public.enforce_adoption_chat_participant_role()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  expected_user_id uuid;
BEGIN
  IF (
    TG_OP = 'UPDATE'
    AND NEW.last_read_sequence < OLD.last_read_sequence
  ) THEN
    RAISE EXCEPTION
      'Chat read sequence cannot move backwards'
      USING ERRCODE = '23514';
  END IF;

  SELECT CASE
    WHEN NEW.role = 'adopter' THEN adopter_user_id
    WHEN NEW.role = 'shelter' THEN shelter_id
  END
  INTO expected_user_id
  FROM public.adoption_chat_threads
  WHERE id = NEW.thread_id;

  IF expected_user_id IS NULL OR expected_user_id <> NEW.user_id THEN
    RAISE EXCEPTION
      'Chat participant does not match the thread role'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END
$$;

REVOKE ALL
  ON FUNCTION public.enforce_adoption_chat_participant_role()
  FROM PUBLIC;

DROP TRIGGER IF EXISTS adoption_chat_participants_role_guard
  ON public.adoption_chat_participants;
CREATE TRIGGER adoption_chat_participants_role_guard
BEFORE INSERT OR UPDATE OF thread_id, user_id, role, last_read_sequence
ON public.adoption_chat_participants
FOR EACH ROW
EXECUTE FUNCTION public.enforce_adoption_chat_participant_role();

COMMIT;

SELECT 'DAY51_ADOPTION_CHAT_MONOTONIC_HARDENING_PASS' AS status;
