-- Day 51 rollback. Destructive and intentionally fail-closed.
-- Set `SET pawmate.allow_destructive_rollback = 'on';` only after exporting
-- the Adoption chat schema/data and confirming that no chat message/media rows exist.
\set ON_ERROR_STOP on

BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '60s';

DO $$
DECLARE
  message_count bigint;
  media_count bigint;
  allow_destructive boolean :=
    coalesce(current_setting('pawmate.allow_destructive_rollback', true), 'off')
      = 'on';
BEGIN
  IF NOT allow_destructive THEN
    RAISE EXCEPTION
      'Day 51 rollback refused; explicitly enable pawmate.allow_destructive_rollback after backup';
  END IF;

  IF to_regclass('public.adoption_chat_messages') IS NOT NULL THEN
    SELECT count(*) INTO message_count
    FROM public.adoption_chat_messages;
  ELSE
    message_count := 0;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'media_assets'
      AND column_name = 'adoption_chat_message_id'
  ) THEN
    SELECT count(*) INTO media_count
    FROM public.media_assets
    WHERE adoption_chat_message_id IS NOT NULL;
  ELSE
    media_count := 0;
  END IF;

  IF message_count <> 0 OR media_count <> 0 THEN
    RAISE EXCEPTION
      'Day 51 rollback refused; chat messages/media exist (messages %, media %)',
      message_count,
      media_count;
  END IF;
END
$$;

DROP TRIGGER IF EXISTS adoption_chat_participants_role_guard
  ON public.adoption_chat_participants;
DROP FUNCTION IF EXISTS public.enforce_adoption_chat_participant_role();

DROP INDEX IF EXISTS public.media_assets_adoption_chat_message_position_key;
DROP INDEX IF EXISTS public.media_assets_adoption_chat_message_position_idx;

ALTER TABLE public.media_assets
  DROP CONSTRAINT IF EXISTS media_assets_adoption_chat_message_fkey;
ALTER TABLE public.media_assets
  DROP CONSTRAINT media_assets_entity_count_check;
ALTER TABLE public.media_assets
  DROP CONSTRAINT media_assets_purpose_entity_check;
ALTER TABLE public.media_assets
  DROP COLUMN IF EXISTS adoption_chat_message_id;

ALTER TABLE public.media_assets
  ADD CONSTRAINT media_assets_entity_count_check CHECK (
    num_nonnulls(draft_id, case_id, comment_id) <= 1
    AND (
      status <> 'attached'
      OR num_nonnulls(draft_id, case_id, comment_id) = 1
    )
  );
ALTER TABLE public.media_assets
  ADD CONSTRAINT media_assets_purpose_entity_check CHECK (
    (draft_id IS NULL AND case_id IS NULL AND comment_id IS NULL)
    OR (comment_id IS NOT NULL AND purpose = 'rescue_comment')
    OR (
      (draft_id IS NOT NULL OR case_id IS NOT NULL)
      AND purpose = 'rescue_case'
    )
  );

DROP TABLE IF EXISTS public.adoption_chat_messages;
DROP TABLE IF EXISTS public.adoption_chat_participants;
DROP TYPE IF EXISTS "AdoptionChatParticipantRole";

COMMIT;

SELECT 'DAY51_ADOPTION_CHAT_ROLLBACK_PASS' AS status;
