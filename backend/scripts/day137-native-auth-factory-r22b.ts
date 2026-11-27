import { createAuthService, type AuthUserStore, type AuthSessionStore } from '../src/services/auth/auth-service';
import type { AppConfig } from '../src/config/env';
import { createSupabaseEmailVerificationGateway } from '../src/integrations/supabase-auth-gateway';
import { createOAuthVerifier } from '../src/integrations/oauth-verifier';

// QA clock only; dependency factories are the same native provider factories as buildApp.
export function createNativeAuthForDay137(config: AppConfig, userStore: AuthUserStore,
  sessionStore: AuthSessionStore, now: () => Date) {
  const emailVerificationGateway = process.env.DAY137_AUTH_FACTORY_COUNTERFACTUAL === '1'
    ? undefined : createSupabaseEmailVerificationGateway(config);
  return createAuthService({ config, userStore, sessionStore, now,
    emailVerificationGateway, oauthVerifier: createOAuthVerifier(config) });
}
