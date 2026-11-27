export const RESCUE_IMAGE_MAX_BYTES = 10 * 1024 * 1024;

// Supabase Free projects cap the global and per-bucket file size at 50 MB.
// Keep the product contract at that ceiling so API validation, database
// constraints and bucket configuration cannot drift apart.
export const RESCUE_VIDEO_MAX_BYTES = 50 * 1024 * 1024;

export const RESCUE_BUCKET_MAX_BYTES = RESCUE_VIDEO_MAX_BYTES;
