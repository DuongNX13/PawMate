export function normalizeLcovSourcePath(value, { repoRoot }) {
  const normalized = value.replaceAll('\\', '/');
  const normalizedRoot = repoRoot.replaceAll('\\', '/').replace(/\/+$/, '');
  const lower = normalized.toLowerCase();
  const rootPrefix = `${normalizedRoot}/`.toLowerCase();

  if (lower.startsWith(rootPrefix)) {
    return normalized.slice(rootPrefix.length);
  }
  if (lower.startsWith('lib/')) {
    return `mobile/${normalized}`;
  }
  if (lower.startsWith('mobile/')) {
    return normalized;
  }

  const mobileMarker = '/mobile/';
  const markerIndex = lower.lastIndexOf(mobileMarker);
  if (markerIndex >= 0) {
    return `mobile/${normalized.slice(markerIndex + mobileMarker.length)}`;
  }
  return normalized;
}
