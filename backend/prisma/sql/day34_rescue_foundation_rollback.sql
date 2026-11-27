-- Day 34 rollback for a failed initial Rescue rollout.
-- DESTRUCTIVE: this removes every Rescue draft/case/media/comment/status row.
-- Take a schema/data backup and obtain release approval before running remotely.
BEGIN;

DROP TABLE IF EXISTS public.rescue_status_events;
DROP TABLE IF EXISTS public.media_assets;
DROP TABLE IF EXISTS public.rescue_comments;
DROP TABLE IF EXISTS public.rescue_case_private_locations;
DROP TABLE IF EXISTS public.rescue_cases;
DROP TABLE IF EXISTS public.rescue_case_drafts;

DROP FUNCTION IF EXISTS public.pawmate_request_user_id();

DROP TYPE IF EXISTS "MediaLifecycleStatus";
DROP TYPE IF EXISTS "MediaPurpose";
DROP TYPE IF EXISTS "RescueCommentModerationState";
DROP TYPE IF EXISTS "RescueContactPreference";
DROP TYPE IF EXISTS "RescueCaseStatus";

COMMIT;

