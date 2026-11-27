import type { SupabaseClient } from '@supabase/supabase-js';
import type { FinalProviderGuard } from './day137-final-provider-boundary-r24.mjs';
export function cleanupOwnedProviderFixtures(options: {
  runId: string;
  guard: FinalProviderGuard;
  cloud: SupabaseClient;
  buckets: string[];
  journal: unknown[];
  write: (name: string, value: unknown) => void;
  safeError: (error: unknown) => string;
  fatalCheck: () => void;
}): Promise<{ verdict: string; runId: string; cloudCalls?: number }>;
