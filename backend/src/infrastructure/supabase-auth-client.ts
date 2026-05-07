import { createClient } from '@supabase/supabase-js';

import { type AppConfig } from '../config/env';

export const createSupabaseAuthClient = (config: AppConfig) => {
  if (!config.supabaseUrl || !config.supabaseAnonKey) {
    return undefined;
  }

  return createClient(config.supabaseUrl, config.supabaseAnonKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  }).auth;
};
