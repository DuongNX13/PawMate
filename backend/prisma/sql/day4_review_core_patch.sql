-- Day 4 patch for review core, helpful votes, reports, and rating aggregate.

DO $$
BEGIN
  CREATE TYPE "ReviewStatus" AS ENUM ('visible', 'hidden');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE "ReviewSentiment" AS ENUM ('UNPROCESSED', 'POSITIVE', 'NEGATIVE', 'NEUTRAL');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE "ReviewReportReason" AS ENUM (
    'spam',
    'false_information',
    'abusive',
    'off_topic',
    'other'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE "ReviewReportStatus" AS ENUM ('pending', 'approved', 'rejected');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE public.reviews
  ADD COLUMN IF NOT EXISTS photo_urls jsonb DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS is_verified_visit boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS helpful_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS report_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS status "ReviewStatus" NOT NULL DEFAULT 'visible',
  ADD COLUMN IF NOT EXISTS sentiment "ReviewSentiment" NOT NULL DEFAULT 'UNPROCESSED',
  ADD COLUMN IF NOT EXISTS is_flagged boolean NOT NULL DEFAULT false;

CREATE UNIQUE INDEX IF NOT EXISTS reviews_user_id_vet_id_uidx
  ON public.reviews (user_id, vet_id);

CREATE INDEX IF NOT EXISTS reviews_vet_id_helpful_count_idx
  ON public.reviews (vet_id, helpful_count DESC);

CREATE TABLE IF NOT EXISTS public.review_helpful_votes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id uuid NOT NULL REFERENCES public.reviews(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at timestamp(3) NOT NULL DEFAULT now(),
  CONSTRAINT review_helpful_votes_review_id_user_id_key UNIQUE (review_id, user_id)
);

CREATE INDEX IF NOT EXISTS review_helpful_votes_user_id_idx
  ON public.review_helpful_votes (user_id);

CREATE TABLE IF NOT EXISTS public.review_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id uuid NOT NULL REFERENCES public.reviews(id) ON DELETE CASCADE,
  reporter_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  reason "ReviewReportReason" NOT NULL,
  description text,
  status "ReviewReportStatus" NOT NULL DEFAULT 'pending',
  resolved_at timestamp(3),
  resolver_id uuid,
  created_at timestamp(3) NOT NULL DEFAULT now(),
  updated_at timestamp(3) NOT NULL DEFAULT now(),
  CONSTRAINT review_reports_review_id_reporter_id_key UNIQUE (review_id, reporter_id)
);

CREATE INDEX IF NOT EXISTS review_reports_review_id_status_idx
  ON public.review_reports (review_id, status);

CREATE INDEX IF NOT EXISTS review_reports_reporter_id_idx
  ON public.review_reports (reporter_id);

CREATE OR REPLACE FUNCTION public.update_vet_rating()
RETURNS trigger AS $$
DECLARE
  affected_vet_id uuid;
BEGIN
  affected_vet_id := COALESCE(NEW.vet_id, OLD.vet_id);

  UPDATE public.vets v
  SET
    average_rating = stats.average_rating,
    review_count = stats.review_count,
    updated_at = now()
  FROM (
    SELECT
      CASE
        WHEN COUNT(*) = 0 THEN NULL
        ELSE ROUND(AVG(rating)::numeric, 2)
      END AS average_rating,
      COUNT(*)::int AS review_count
    FROM public.reviews
    WHERE vet_id = affected_vet_id AND status = 'visible'
  ) stats
  WHERE v.id = affected_vet_id;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS reviews_rating_aggregate_trigger ON public.reviews;

CREATE TRIGGER reviews_rating_aggregate_trigger
AFTER INSERT OR UPDATE OF rating, status OR DELETE ON public.reviews
FOR EACH ROW
EXECUTE FUNCTION public.update_vet_rating();
