-- Development/test seed for Day 50 Adoption.
-- Do not run this file against production or the shared Supabase cloud project.
BEGIN;

INSERT INTO public.users (
  id,
  email,
  display_name,
  email_verified,
  created_at,
  updated_at
)
VALUES
  (
    '50000000-0000-4000-8000-000000000001',
    'day50-shelter@pawmate.local',
    'Mái ấm Chocomint',
    true,
    '2026-07-27T00:00:00Z',
    '2026-07-27T00:00:00Z'
  ),
  (
    '50000000-0000-4000-8000-000000000002',
    'day50-adopter@pawmate.local',
    'Day 50 Adopter',
    true,
    '2026-07-27T00:00:00Z',
    '2026-07-27T00:00:00Z'
  )
ON CONFLICT (id) DO UPDATE
SET display_name = EXCLUDED.display_name,
    updated_at = EXCLUDED.updated_at;

INSERT INTO public.media_assets (
  id,
  owner_user_id,
  purpose,
  mime_type,
  size_bytes,
  sha256,
  status,
  storage_key,
  public_url,
  width,
  height,
  verification_version,
  verified_at,
  created_at,
  updated_at
)
VALUES (
  '50000000-0000-4000-8000-000000000003',
  '50000000-0000-4000-8000-000000000001',
  'adoption_listing',
  'image/webp',
  4096,
  repeat('5', 64),
  'verified',
  'day50/adoption/golden.webp',
  'https://example.invalid/day50/golden.webp',
  1200,
  900,
  1,
  '2026-07-27T00:01:00Z',
  '2026-07-27T00:01:00Z',
  '2026-07-27T00:01:00Z'
)
ON CONFLICT (id) DO UPDATE
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at;

INSERT INTO public.adoption_listings (
  id,
  shelter_id,
  hero_media_id,
  pet_name,
  species,
  breed,
  age_label,
  description,
  traits,
  health_badges,
  verification_badges,
  latitude,
  longitude,
  status,
  created_at,
  updated_at
)
VALUES (
  '50000000-0000-4000-8000-000000000004',
  '50000000-0000-4000-8000-000000000001',
  '50000000-0000-4000-8000-000000000003',
  'Golden',
  'dog',
  'Golden Retriever',
  '2 tháng tuổi',
  'Hiền lành, thân thiện và đã sẵn sàng về nhà mới.',
  ARRAY['hiền lành', 'thân thiện'],
  ARRAY['đã tiêm phòng'],
  ARRAY['mái ấm đã xác minh'],
  10.776889,
  106.700806,
  'available',
  '2026-07-27T00:02:00Z',
  '2026-07-27T00:02:00Z'
)
ON CONFLICT (id) DO UPDATE
SET status = EXCLUDED.status,
    updated_at = EXCLUDED.updated_at;

COMMIT;
