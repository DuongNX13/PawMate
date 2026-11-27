const fs = require('node:fs');
const path = require('node:path');

function loadEnvFile(filePath) {
  if (!fs.existsSync(filePath)) return {};

  return Object.fromEntries(
    fs
      .readFileSync(filePath, 'utf8')
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter((line) => line && !line.startsWith('#') && line.includes('='))
      .map((line) => {
        const index = line.indexOf('=');
        return [line.slice(0, index), line.slice(index + 1)];
      }),
  );
}

function requireValue(env, key) {
  const value = env[key] ?? process.env[key];
  if (!value || value.trim() === '') {
    throw new Error(`Missing required environment variable: ${key}`);
  }
  return value.trim();
}

async function requestStatus(name, url, headers) {
  const response = await fetch(url, { headers });
  console.log(`${name}: ${response.status} ${response.statusText}`);

  if (response.status === 540) {
    throw new Error('Supabase project is paused. Open Supabase Studio and restore it before running keepalive again.');
  }

  if (response.status === 402) {
    throw new Error('Supabase project is restricted by billing/fair-use policy. Check the Supabase dashboard.');
  }

  if (response.status >= 500) {
    throw new Error(`${name} returned ${response.status}. Supabase did not accept the keepalive cleanly.`);
  }

  return response.status;
}

async function main() {
  const envFile = process.env.PAWMATE_SUPABASE_ENV_FILE
    ? path.resolve(process.env.PAWMATE_SUPABASE_ENV_FILE)
    : path.resolve(__dirname, '../.env.local');
  const fileEnv = loadEnvFile(envFile);
  const env = { ...fileEnv, ...process.env };

  const supabaseUrl = requireValue(env, 'SUPABASE_URL').replace(/\/$/, '');
  const publishableKey =
    env.SUPABASE_PUBLISHABLE_KEY ||
    env.SUPABASE_ANON_KEY ||
    env.SUPABASE_SECRET_KEY ||
    env.SUPABASE_SERVICE_ROLE_KEY;
  const adminKey = env.SUPABASE_SECRET_KEY || env.SUPABASE_SERVICE_ROLE_KEY;

  if (!publishableKey) {
    throw new Error('Missing Supabase API key. Set SUPABASE_PUBLISHABLE_KEY, SUPABASE_ANON_KEY, SUPABASE_SECRET_KEY, or SUPABASE_SERVICE_ROLE_KEY.');
  }

  await requestStatus('auth-health', `${supabaseUrl}/auth/v1/health`, {
    apikey: publishableKey,
  });

  if (adminKey) {
    await requestStatus(
      'auth-admin-list-users',
      `${supabaseUrl}/auth/v1/admin/users?page=1&per_page=1`,
      {
        apikey: adminKey,
        Authorization: `Bearer ${adminKey}`,
      },
    );
  }

  console.log(`supabase-keepalive: ok ${new Date().toISOString()}`);
}

main().catch((error) => {
  console.error(`supabase-keepalive: failed - ${error.message}`);
  process.exitCode = 1;
});
