import assert from 'node:assert/strict';
import { loadEnv } from '../src/config/env';
import { buildDay137ProductionConfig, validateDay137EffectiveConfigs } from './day137-bootstrap-r20';

const config = buildDay137ProductionConfig(loadEnv(),
  process.argv[2], process.argv[3]);
assert.equal(new URL(config.supabaseUrl!).hostname, 'qeoowayxfqyhfcgnrfnv.supabase.co');
console.log(JSON.stringify(validateDay137EffectiveConfigs({ privateChat: config })));
