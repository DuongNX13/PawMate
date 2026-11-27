import { validateAppConfig, type AppConfig } from '../src/config/env';
import { buildTestConfig } from '../tests/helpers/rescue-read-fixtures';

/** Test-only configuration. Preserve the real provider for every production app. */
export function buildDay137ProductionConfig(
  provider: AppConfig,
  databaseUrl: string,
  redisUrl: string,
): AppConfig {
  const base = buildTestConfig();
  if (new URL(databaseUrl).hostname !== '127.0.0.1' ||
      new URL(redisUrl).hostname !== '127.0.0.1') {
    throw new Error('DAY137_OWNED_LOCAL_INFRASTRUCTURE_REQUIRED');
  }
  const config: AppConfig = {
    ...base,
    nodeEnv: 'production',
    databaseUrl,
    redisUrl,
    supabaseUrl: provider.supabaseUrl,
    supabaseAnonKey: provider.supabaseAnonKey,
    supabaseServiceRoleKey: provider.supabaseServiceRoleKey,
    supabaseBuckets: { ...provider.supabaseBuckets },
    auth: {
      ...base.auth,
      accessTokenSecret: 'day137-local-only-access-fixture-distinct-20261005',
      refreshTokenSecret: 'day137-local-only-refresh-fixture-distinct-20261005',
    },
  };
  // A controlled mutation for RED proof; never permitted in a device/API run.
  if (process.env.DAY137_BOOTSTRAP_COUNTERFACTUAL === '1') {
    config.supabaseUrl = undefined;
    config.supabaseAnonKey = undefined;
    config.supabaseServiceRoleKey = undefined;
  }
  return validateAppConfig(config);
}

export function validateDay137EffectiveConfigs(configs: Record<string, AppConfig>) {
  if (process.env.DAY137_BOOTSTRAP_COUNTERFACTUAL === '1') {
    throw new Error('DAY137_COUNTERFACTUAL_FORBIDDEN_IN_RUNTIME');
  }
  if (Object.keys(configs).length === 0) throw new Error('DAY137_NO_EFFECTIVE_CONFIG');
  for (const config of Object.values(configs)) validateAppConfig(config);
  return Object.entries(configs).map(([name, config]) => ({
    name,
    environment: config.nodeEnv,
    providerHost: new URL(config.supabaseUrl!).hostname,
    providerConfigured: Boolean(config.supabaseAnonKey && config.supabaseServiceRoleKey),
    verdict: 'PASS_CONFIGURATION_ONLY',
  }));
}
