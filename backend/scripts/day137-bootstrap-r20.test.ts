import test from 'node:test';
import assert from 'node:assert/strict';
import { buildTestConfig } from '../tests/helpers/rescue-read-fixtures';
import { buildDay137ProductionConfig, validateDay137EffectiveConfigs } from './day137-bootstrap-r20';

const provider = {
  ...buildTestConfig(),
  supabaseUrl: 'https://qeoowayxfqyhfcgnrfnv.supabase.co',
  // Nonfunctional validation inputs; no provider traffic in this file.
  supabaseAnonKey: 'offline-anonymous-validation-value',
  supabaseServiceRoleKey: 'offline-service-validation-value',
  supabaseBuckets: { ...buildTestConfig().supabaseBuckets, reviewPhotos: 'review-photos' },
};
const make = () => buildDay137ProductionConfig(provider,
  'postgresql://synthetic@127.0.0.1:55447/synthetic', 'redis://127.0.0.1:56387');

test('every production surface preserves provider configuration before bootstrap', () => {
  const config = make();
  assert.equal(config.supabaseUrl, provider.supabaseUrl);
  assert.equal(config.supabaseAnonKey, provider.supabaseAnonKey);
  assert.equal(config.supabaseServiceRoleKey, provider.supabaseServiceRoleKey);
  assert.deepEqual(config.supabaseBuckets, provider.supabaseBuckets);
  assert.notEqual(config.auth.accessTokenSecret, config.auth.refreshTokenSecret);
  const result = validateDay137EffectiveConfigs({ privateChat: config, reviewPhoto: config });
  assert.equal(result.length, 2);
  assert(result.every(x => x.verdict === 'PASS_CONFIGURATION_ONLY'));
  assert(!JSON.stringify(result).includes(provider.supabaseServiceRoleKey));
});

test('guard catches a caller deleting provider config after the builder', () => {
  const config = { ...make(), supabaseUrl: undefined };
  assert.throws(() => validateDay137EffectiveConfigs({ photo: config }), /required in production/);
});

test('empty config inventory and nonlocal infrastructure fail before startup', () => {
  assert.throws(() => validateDay137EffectiveConfigs({}), /NO_EFFECTIVE_CONFIG/);
  assert.throws(() => buildDay137ProductionConfig(provider,
    'postgresql://synthetic@remote.invalid/synthetic', 'redis://127.0.0.1:56387'),
    /OWNED_LOCAL_INFRASTRUCTURE_REQUIRED/);
});
