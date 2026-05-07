#!/usr/bin/env node

const rawBaseUrl = process.env.PAWMATE_API_BASE_URL?.trim() ?? '';
const skipValidation =
  process.env.PAWMATE_SKIP_BACKEND_URL_VALIDATION === '1' ||
  process.env.PAWMATE_SKIP_BACKEND_URL_VALIDATION === 'true';
const allowLocal =
  process.env.PAWMATE_ALLOW_LOCAL_BACKEND_URL === '1' ||
  process.env.PAWMATE_ALLOW_LOCAL_BACKEND_URL === 'true';
const timeoutMs = Number(process.env.PAWMATE_BACKEND_HEALTH_TIMEOUT_MS ?? 10000);

const fail = (message) => {
  console.error(`[pawmate-backend-url] ${message}`);
  process.exit(1);
};

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
const controller = new AbortController();
const timeout = setTimeout(() => controller.abort(), timeoutMs);

try {
  const response = await fetch(healthUrl, {
    headers: { Accept: 'application/json' },
    signal: controller.signal,
  });
  if (!response.ok) {
    fail(
      `Backend health check failed: GET ${displayUrl(healthUrl)} returned HTTP ${response.status}.`,
    );
  }
  console.log(
    `[pawmate-backend-url] Backend health check passed: ${displayUrl(healthUrl)}`,
  );
} catch (error) {
  const reason =
    error instanceof Error ? `${error.name}: ${error.message}` : String(error);
  fail(`Backend health check failed: GET ${displayUrl(healthUrl)} -> ${reason}`);
} finally {
  clearTimeout(timeout);
}
