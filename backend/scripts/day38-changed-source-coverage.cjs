const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const backendRoot = path.resolve(__dirname, '..');
const repoRoot = path.resolve(backendRoot, '..');

const readArg = (name) => {
  const prefix = `--${name}=`;
  const value = process.argv.find((argument) => argument.startsWith(prefix));
  return value ? value.slice(prefix.length) : null;
};

const baselineReportRoot = path.resolve(
  repoRoot,
  readArg('baseline-report') ||
    'output-evidence/day37/final-20260722-1510/coverage/lcov-report',
);
const coverageLcov = path.resolve(
  repoRoot,
  readArg('coverage-lcov') || 'backend/coverage/lcov.info',
);
const outputFile = path.resolve(
  repoRoot,
  readArg('output') || 'output-evidence/day38/changed-source-coverage.json',
);

const sourceFiles = [
  'src/services/rescue/rescue-location-privacy.ts',
  'src/features/rescue/persistence/prisma-rescue-repository.ts',
];

const sha256 = (filePath) =>
  crypto.createHash('sha256').update(fs.readFileSync(filePath)).digest('hex');

const decodeHtml = (value) =>
  value
    // Istanbul injects a one-letter I/E marker before uncovered if/else
    // branches. The marker is presentation metadata, not part of the source.
    .replace(
      /<span class="(?:missing|skip)-if-branch"[^>]*>[\s\S]*?<\/span>/gu,
      '',
    )
    .replace(/<[^>]+>/gu, '')
    .replace(/&nbsp;/gu, ' ')
    .replace(/&quot;/gu, '"')
    .replace(/&#x27;|&#39;/gu, "'")
    .replace(/&lt;/gu, '<')
    .replace(/&gt;/gu, '>')
    .replace(/&amp;/gu, '&')
    .replace(/&#(\d+);/gu, (_, code) => String.fromCodePoint(Number(code)))
    .replace(/&#x([0-9a-f]+);/giu, (_, code) =>
      String.fromCodePoint(Number.parseInt(code, 16)),
    );

const extractBaselineSource = (htmlFile) => {
  const html = fs.readFileSync(htmlFile, 'utf8');
  const match = html.match(
    /<pre class="prettyprint lang-js">([\s\S]*?)<\/pre>/u,
  );
  if (!match) {
    throw new Error(`Could not find Istanbul source block in ${htmlFile}.`);
  }
  return decodeHtml(match[1]).replace(/\r\n/gu, '\n');
};

const parseLcov = (filePath) => {
  const records = new Map();
  let current = null;
  for (const line of fs.readFileSync(filePath, 'utf8').split(/\r?\n/u)) {
    if (line.startsWith('SF:')) {
      current = {
        source: line.slice(3).replaceAll('\\', '/'),
        lines: new Map(),
      };
      continue;
    }
    if (line === 'end_of_record') {
      if (current) records.set(current.source, current.lines);
      current = null;
      continue;
    }
    if (current && line.startsWith('DA:')) {
      const [lineNumber, hitCount] = line.slice(3).split(',');
      current.lines.set(Number(lineNumber), Number(hitCount));
    }
  }
  return records;
};

const findCoverageRecord = (records, relativeSource) => {
  const normalized = relativeSource.replaceAll('\\', '/');
  const candidates = [...records.entries()].filter(([source]) =>
    source.endsWith(normalized),
  );
  if (candidates.length !== 1) {
    throw new Error(
      `Expected one LCOV record ending in ${normalized}; found ${candidates.length}.`,
    );
  }
  return candidates[0];
};

const changedCurrentLines = (baselineFile, currentFile) => {
  const diff = spawnSync(
    'git',
    [
      'diff',
      '--no-index',
      '--unified=0',
      '--ignore-cr-at-eol',
      '--ignore-space-at-eol',
      '--',
      baselineFile,
      currentFile,
    ],
    { encoding: 'utf8', windowsHide: true, maxBuffer: 16 * 1024 * 1024 },
  );
  if (![0, 1].includes(diff.status)) {
    throw new Error(
      `git diff failed for ${currentFile}: ${diff.stderr || diff.error?.message}`,
    );
  }

  const changed = new Set();
  for (const line of diff.stdout.split(/\r?\n/u)) {
    const match = line.match(/^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@/u);
    if (!match) continue;
    const start = Number(match[1]);
    const count = match[2] === undefined ? 1 : Number(match[2]);
    for (let offset = 0; offset < count; offset += 1) {
      changed.add(start + offset);
    }
  }
  return [...changed].sort((left, right) => left - right);
};

if (!fs.existsSync(coverageLcov)) {
  throw new Error(`LCOV file does not exist: ${coverageLcov}`);
}
fs.mkdirSync(path.dirname(outputFile), { recursive: true });
const reconstructedRoot = path.join(
  path.dirname(outputFile),
  'baseline-reconstructed',
);
fs.mkdirSync(reconstructedRoot, { recursive: true });

const lcovRecords = parseLcov(coverageLcov);
const files = sourceFiles.map((sourceFile) => {
  const baselineHtml = path.join(baselineReportRoot, `${sourceFile}.html`);
  const currentFile = path.join(backendRoot, sourceFile);
  if (!fs.existsSync(baselineHtml)) {
    throw new Error(`Baseline Istanbul HTML does not exist: ${baselineHtml}`);
  }
  if (!fs.existsSync(currentFile)) {
    throw new Error(`Current source does not exist: ${currentFile}`);
  }

  const reconstructedFile = path.join(reconstructedRoot, sourceFile);
  fs.mkdirSync(path.dirname(reconstructedFile), { recursive: true });
  fs.writeFileSync(
    reconstructedFile,
    extractBaselineSource(baselineHtml),
    'utf8',
  );

  const changedLines = changedCurrentLines(reconstructedFile, currentFile);
  const [lcovSource, executableLines] = findCoverageRecord(
    lcovRecords,
    sourceFile,
  );
  const changedExecutableLines = changedLines.filter((line) =>
    executableLines.has(line),
  );
  const missedLines = changedExecutableLines.filter(
    (line) => (executableLines.get(line) || 0) === 0,
  );
  const coveredLines = changedExecutableLines.length - missedLines.length;
  const lineCoveragePct = changedExecutableLines.length
    ? Number(((coveredLines / changedExecutableLines.length) * 100).toFixed(2))
    : 100;

  return {
    sourceFile: `backend/${sourceFile}`,
    baselineHtml: path.relative(repoRoot, baselineHtml).replaceAll('\\', '/'),
    reconstructedBaseline: path
      .relative(repoRoot, reconstructedFile)
      .replaceAll('\\', '/'),
    lcovSource,
    baselineSha256: sha256(reconstructedFile),
    currentSha256: sha256(currentFile),
    changedSourceLineCount: changedLines.length,
    changedExecutableLineCount: changedExecutableLines.length,
    coveredChangedExecutableLineCount: coveredLines,
    missedChangedExecutableLines: missedLines,
    lineCoveragePct,
  };
});

const totals = files.reduce(
  (summary, file) => ({
    changedSourceLineCount:
      summary.changedSourceLineCount + file.changedSourceLineCount,
    changedExecutableLineCount:
      summary.changedExecutableLineCount + file.changedExecutableLineCount,
    coveredChangedExecutableLineCount:
      summary.coveredChangedExecutableLineCount +
      file.coveredChangedExecutableLineCount,
  }),
  {
    changedSourceLineCount: 0,
    changedExecutableLineCount: 0,
    coveredChangedExecutableLineCount: 0,
  },
);
totals.lineCoveragePct = totals.changedExecutableLineCount
  ? Number(
      (
        (totals.coveredChangedExecutableLineCount /
          totals.changedExecutableLineCount) *
        100
      ).toFixed(2),
    )
  : 100;

const result = {
  schemaVersion: 1,
  generatedAt: new Date().toISOString(),
  metric: 'Istanbul executable line coverage for current lines added or modified since the frozen Day 37 source snapshot',
  gate: { minimumPct: 90, pass: totals.lineCoveragePct >= 90 },
  baselineReportRoot: path
    .relative(repoRoot, baselineReportRoot)
    .replaceAll('\\', '/'),
  coverageLcov: path.relative(repoRoot, coverageLcov).replaceAll('\\', '/'),
  coverageLcovSha256: sha256(coverageLcov),
  files,
  totals,
};

fs.writeFileSync(outputFile, `${JSON.stringify(result, null, 2)}\n`, 'utf8');
process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
if (!result.gate.pass) process.exitCode = 2;
