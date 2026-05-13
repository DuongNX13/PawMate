#!/usr/bin/env node

const rawBaseUrl = process.env.PAWMATE_API_BASE_URL?.trim() ?? '';
const skipValidation =
  process.env.PAWMATE_SKIP_BACKEND_URL_VALIDATION === '1' ||
  process.env.PAWMATE_SKIP_BACKEND_URL_VALIDATION === 'true';
const allowLocal =
  process.env.PAWMATE_ALLOW_LOCAL_BACKEND_URL === '1' ||
  process.env.PAWMATE_ALLOW_LOCAL_BACKEND_URL === 'true';

const fail = (message) => {
  console.error(`[pawmate-backend-url] ${message}`);
  process.exit(1);
};

const readPositiveMs = (name, fallback) => {
  const raw = process.env[name]?.trim();

  if (!raw) {
    return fallback;
  }

  const parsed = Number(raw);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    fail(`${name} must be a positive integer number of milliseconds.`);
  }

  return parsed;
};

const timeoutMs = readPositiveMs('PAWMATE_BACKEND_HEALTH_TIMEOUT_MS', 10000);
const retryIntervalMs = readPositiveMs(
  'PAWMATE_BACKEND_HEALTH_RETRY_INTERVAL_MS',
  3000,
);

const displayUrl = (url) => {
  const copy = new URL(url.toString());
  copy.username = '';
  copy.password = '';
  return copy.toString();
};

const isPrivateIpv4 = (host) => {
  return (
    /^127\./.test(host) ||
    /^10\./.test(host) ||
    /^192\.168\./.test(host) ||
    /^172\.(1[6-9]|2\d|3[0-1])\./.test(host) ||
    host === '0.0.0.0'
  );
};

const isLocalOrPlaceholderHost = (host) => {
  const normalized = host.toLowerCase();
  return (
    normalized === 'localhost' ||
    normalized === '::1' ||
    normalized.endsWith('.local') ||
    normalized.endsWith('.internal') ||
    normalized.endsWith('.invalid') ||
    normalized.includes('placeholder') ||
    isPrivateIpv4(normalized)
  );
};

if (skipValidation) {
  console.warn(
    '[pawmate-backend-url] Skipping validation by explicit PAWMATE_SKIP_BACKEND_URL_VALIDATION flag.',
  );
  process.exit(0);
}

if (!rawBaseUrl) {
  fail(
    'PAWMATE_API_BASE_URL is required for backend-backed mobile smoke. Set it to a public HTTPS backend URL before building.',
  );
}

let baseUrl;
try {
  baseUrl = new URL(rawBaseUrl);
} catch {
  fail(`PAWMATE_API_BASE_URL is not a valid URL: ${rawBaseUrl}`);
}

if (baseUrl.protocol !== 'https:' && !allowLocal) {
  fail(
    `PAWMATE_API_BASE_URL must use https for Appetize/BrowserStack. Received: ${displayUrl(baseUrl)}`,
  );
}

if (isLocalOrPlaceholderHost(baseUrl.hostname) && !allowLocal) {
  fail(
    `PAWMATE_API_BASE_URL must be a reachable public host, not local/private/placeholder: ${displayUrl(baseUrl)}`,
  );
}

const healthUrl = new URL('/health', baseUrl);
const startedAt = Date.now();
let lastFailure = 'no request attempted';
let healthCheckPassed = false;

const sleep = (ms) =>
  new Promise((resolve) => {
    setTimeout(resolve, ms);
  });

while (Date.now() - startedAt < timeoutMs) {
  const remainingMs = timeoutMs - (Date.now() - startedAt);
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), remainingMs);

  try {
    const response = await fetch(healthUrl, {
      headers: { Accept: 'application/json' },
      signal: controller.signal,
    });
    if (response.ok) {
      console.log(
        `[pawmate-backend-url] Backend health check passed: ${displayUrl(healthUrl)}`,
      );
      healthCheckPassed = true;
    } else {
      lastFailure = `HTTP ${response.status}`;
    }
  } catch (error) {
    const reason =
      error instanceof Error ? `${error.name}: ${error.message}` : String(error);
    lastFailure = reason;
  } finally {
    clearTimeout(timeout);
  }

  if (healthCheckPassed) {
    break;
  }

  const elapsedMs = Date.now() - startedAt;
  const pauseMs = Math.min(retryIntervalMs, timeoutMs - elapsedMs);
  if (pauseMs > 0) {
    await sleep(pauseMs);
  }
}

if (healthCheckPassed) {
  process.exitCode = 0;
} else if (lastFailure.startsWith('HTTP ')) {
  const status = lastFailure.replace('HTTP ', '');
  fail(
    `Backend health check failed: GET ${displayUrl(healthUrl)} returned HTTP ${status} within ${timeoutMs}ms.`,
  );
} else {
  fail(
    `Backend health check failed: GET ${displayUrl(healthUrl)} -> ${lastFailure} within ${timeoutMs}ms.`,
  );
}
