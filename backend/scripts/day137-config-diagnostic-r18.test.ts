// Offline diagnostic only. No loadEnv, database, Redis, cloud, or app startup.
import test from 'node:test';
import assert from 'node:assert/strict';
import { validateAppConfig, type AppConfig } from '../src/config/env';
import { buildTestConfig } from '../tests/helpers/rescue-read-fixtures';

const configured = (): AppConfig => {
  const base = buildTestConfig();
  return {
    ...base,
    nodeEnv: 'production',
    databaseUrl: 'postgresql://synthetic@127.0.0.1:55447/synthetic',
    redisUrl: 'redis://127.0.0.1:56387',
    supabaseUrl: 'https://synthetic.invalid',
    // Nonfunctional validation fixtures, not credentials or provider proof.
    supabaseAnonKey: 'offline-validation-anonymous-fixture',
    supabaseServiceRoleKey: 'offline-validation-service-fixture',
    auth: {
      ...base.auth,
      accessTokenSecret: 'offline-diagnostic-access-secret-distinct-20261005',
      refreshTokenSecret: 'offline-diagnostic-refresh-secret-distinct-20261005',
    },
  };
};

test('actual production configuration validator accepts configured offline fixture', () => {
  const config = configured();
  assert.equal(validateAppConfig(config), config);
});

test('both R18 photo configurations fail before dependency wiring', () => {
  for (const correction of [false, true]) {
    const config = {
      ...configured(),
      supabaseUrl: undefined,
      supabaseAnonKey: undefined,
      supabaseServiceRoleKey: undefined,
    };
    const dependencies = correction
      ? { config, emailVerificationGateway: 'actual factory supplied later' }
      : { config };
    assert.throws(
      () => validateAppConfig(dependencies.config),
      (error: unknown) => {
        assert.equal((error as { code: string }).code,
          'CONFIG_EMAIL_VERIFICATION_ADAPTER_REQUIRED');
        return true;
      },
    );
  }
});

test('preflight without actual validator would miss the configuration defect', () => {
  const invalid = { ...configured(), supabaseUrl: undefined };
  assert.doesNotThrow(() => invalid); // Old typecheck-only preflight: not acceptance.
  assert.throws(() => validateAppConfig(invalid), /required in production/);
});
