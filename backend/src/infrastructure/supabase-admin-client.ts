import { createClient } from '@supabase/supabase-js';

import { type AppConfig } from '../config/env';

export const createSupabaseAdminClient = (config: AppConfig) => {
  if (!config.supabaseUrl || !config.supabaseServiceRoleKey) {
    return undefined;
  }

  return createClient(config.supabaseUrl, config.supabaseServiceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  });
};
