import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(scriptDirectory, '../../..');
const baselineId = 'UI-CC-2026-07-21-G4B';
const evidenceRoot = path.join(
  repoRoot,
  'output-evidence',
  'ui-v031',
  baselineId,
  'W8',
);
const backupRoot = path.resolve(
  repoRoot,
  '..',
  'PawMate-local-sensitive-evidence',
  baselineId,
  'W8',
);
const reportPath = path.join(evidenceRoot, 'redaction-actions.json');

const textExtensions = new Set([
  '.csv',
  '.html',
  '.json',
  '.log',
  '.md',
  '.txt',
  '.xml',
]);
const syntheticDomains = new Set([
  'example.com',
  'example.net',
  'example.org',
  'pawmate.test',
  'test.invalid',
]);

function walkFiles(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const absolute = path.join(directory, entry.name);
    return entry.isDirectory() ? walkFiles(absolute) : [absolute];
  });
}

function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex').toUpperCase();
}

function redactEmail(match, domain) {
  const normalizedDomain = domain.toLowerCase();
  if (
    syntheticDomains.has(normalizedDomain) ||
    /^[123]x\.(?:png|webp|jpe?g)$/.test(normalizedDomain)
  ) {
    return match;
  }
  return '[REDACTED_EMAIL]';
}

if (!fs.existsSync(evidenceRoot)) {
  throw new Error(`W8 evidence root is missing: ${evidenceRoot}`);
}

const actions = [];
for (const filePath of walkFiles(evidenceRoot)) {
  if (
    filePath === reportPath ||
    !textExtensions.has(path.extname(filePath).toLowerCase())
  ) {
    continue;
  }

  const before = fs.readFileSync(filePath, 'utf8');
  let nonSyntheticEmailCount = 0;
  let windowsUserPathCount = 0;
  let after = before.replace(
    /\b[A-Z0-9._%+-]+@([A-Z0-9.-]+\.[A-Z]{2,})\b/gi,
    (match, domain) => {
      const replacement = redactEmail(match, domain);
      if (replacement !== match) nonSyntheticEmailCount += 1;
      return replacement;
    },
  );
  after = after.replace(/C:[\\/]+Users[\\/]+[^\\/\r\n]+/gi, () => {
    windowsUserPathCount += 1;
    return '[REDACTED_WINDOWS_USER_PATH]';
  });

  if (after === before) continue;

  const relative = path.relative(evidenceRoot, filePath);
  const backupPath = path.join(backupRoot, relative);
  fs.mkdirSync(path.dirname(backupPath), { recursive: true });
  if (!fs.existsSync(backupPath)) {
    fs.copyFileSync(filePath, backupPath);
  }

  const temporaryPath = `${filePath}.redacting`;
  fs.writeFileSync(temporaryPath, after, 'utf8');
  fs.renameSync(temporaryPath, filePath);
  actions.push({
    path: relative.replaceAll('\\', '/'),
    non_synthetic_email_replacements: nonSyntheticEmailCount,
    windows_user_path_replacements: windowsUserPathCount,
    before_sha256: sha256(Buffer.from(before)),
    after_sha256: sha256(Buffer.from(after)),
    raw_backup_preserved: true,
  });
}

const report = {
  schema: 'pawmate.w8-redaction-actions.v1',
  baseline_id: baselineId,
  generated_at_utc: new Date().toISOString(),
  files_changed: actions.length,
  non_synthetic_email_replacements: actions.reduce(
    (total, action) => total + action.non_synthetic_email_replacements,
    0,
  ),
  windows_user_path_replacements: actions.reduce(
    (total, action) => total + action.windows_user_path_replacements,
    0,
  ),
  raw_backups_preserved_outside_repo_evidence: true,
  actions,
};
fs.writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
console.log(
  JSON.stringify({
    status: 'PASS',
    report: path.relative(repoRoot, reportPath).replaceAll('\\', '/'),
    filesChanged: report.files_changed,
    emailReplacements: report.non_synthetic_email_replacements,
    windowsUserPathReplacements: report.windows_user_path_replacements,
    rawBackupsPreservedOutsideRepoEvidence:
      report.raw_backups_preserved_outside_repo_evidence,
  }),
);
