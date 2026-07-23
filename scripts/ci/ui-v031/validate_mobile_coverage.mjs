import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { spawnSync } from 'node:child_process';
import { normalizeLcovSourcePath } from './lcov_path_utils.mjs';

const root = process.cwd();
const configPath = path.join(
  root,
  'docs/qa/ui-v031/W8_CHANGED_SOURCE_ALLOWLIST.json',
);
const lcovPath = path.join(root, 'mobile/coverage/lcov.info');
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));

const normalize = (value) => value.replaceAll('\\', '/');
const exclusions = config.excludedPatterns.map((value) => new RegExp(value));
const excluded = (relativePath) =>
  exclusions.some((pattern) => pattern.test(relativePath));

function parseLcov(content) {
  const records = new Map();
  let current = null;
  for (const line of content.split(/\r?\n/)) {
    if (line.startsWith('SF:')) {
      const relativePath = normalizeLcovSourcePath(line.slice(3), {
        repoRoot: root,
      });
      current = { path: relativePath, lines: new Map() };
    } else if (current && line.startsWith('DA:')) {
      const [lineNumber, hits] = line.slice(3).split(',').map(Number);
      current.lines.set(lineNumber, hits);
    } else if (current && line === 'end_of_record') {
      records.set(current.path, current);
      current = null;
    }
  }
  return records;
}

function changedLines(baselinePath, currentPath, instrumentedLines) {
  if (!baselinePath) return new Set(instrumentedLines.keys());
  const diff = spawnSync(
    'git',
    ['diff', '--no-index', '--unified=0', '--', baselinePath, currentPath],
    { encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 },
  );
  if (![0, 1].includes(diff.status)) {
    throw new Error(
      `git diff failed for ${currentPath}: ${diff.stderr || diff.stdout}`,
    );
  }
  const result = new Set();
  for (const line of diff.stdout.split(/\r?\n/)) {
    const match = line.match(/^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@/);
    if (!match) continue;
    const start = Number(match[1]);
    const count = match[2] === undefined ? 1 : Number(match[2]);
    for (let offset = 0; offset < count; offset += 1) {
      result.add(start + offset);
    }
  }
  return result;
}

function diffStats(baselinePath, currentPath) {
  const diff = spawnSync(
    'git',
    ['diff', '--no-index', '--numstat', '--', baselinePath, currentPath],
    { encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 },
  );
  if (![0, 1].includes(diff.status)) {
    throw new Error(
      `git diff --numstat failed for ${currentPath}: ${diff.stderr || diff.stdout}`,
    );
  }
  const line = diff.stdout.split(/\r?\n/).find(Boolean);
  if (!line) return { added: 0, deleted: 0 };
  const [added, deleted] = line.split(/\s+/);
  if (!/^\d+$/.test(added) || !/^\d+$/.test(deleted)) {
    throw new Error(`Non-text diff is not valid deletion-only coverage: ${line}`);
  }
  return { added: Number(added), deleted: Number(deleted) };
}

const records = parseLcov(fs.readFileSync(lcovPath, 'utf8'));
let globalFound = 0;
let globalHit = 0;
for (const [relativePath, record] of records) {
  if (excluded(relativePath)) continue;
  globalFound += record.lines.size;
  globalHit += [...record.lines.values()].filter((hits) => hits > 0).length;
}

const errors = [];
const groups = [];
let changedFound = 0;
let changedHit = 0;

for (const group of config.groups) {
  const newPaths = new Set(group.newPaths);
  const deletionOnlyPaths = new Set(group.deletionOnlyPaths ?? []);
  const rows = [];
  const deletionOnlyRows = [];
  let groupFound = 0;
  let groupHit = 0;

  for (const relativePath of deletionOnlyPaths) {
    if (group.paths.includes(relativePath) || newPaths.has(relativePath)) {
      errors.push(
        `${group.wave}: deletion-only path must not also be in paths/newPaths: ${relativePath}`,
      );
      continue;
    }
    if (excluded(relativePath)) {
      errors.push(`${group.wave}: deletion-only generated file ${relativePath}`);
      continue;
    }
    const currentPath = path.join(root, relativePath);
    const baselinePath = path.join(root, group.baselineRoot, relativePath);
    if (!fs.existsSync(currentPath) || !fs.existsSync(baselinePath)) {
      errors.push(
        `${group.wave}: deletion-only path requires current and baseline files: ${relativePath}`,
      );
      continue;
    }
    const stats = diffStats(baselinePath, currentPath);
    if (stats.added !== 0 || stats.deleted === 0) {
      errors.push(
        `${group.wave}: expected a deletion-only diff for ${relativePath}, got +${stats.added}/-${stats.deleted}`,
      );
    }
    deletionOnlyRows.push({
      path: relativePath,
      baseline: normalize(path.relative(root, baselinePath)),
      addedLines: stats.added,
      deletedLines: stats.deleted,
      coverage: 'NOT_APPLICABLE_DELETION_ONLY',
    });
  }

  for (const relativePath of group.paths) {
    if (excluded(relativePath)) {
      errors.push(`${group.wave}: allowlisted generated file ${relativePath}`);
      continue;
    }
    const currentPath = path.join(root, relativePath);
    if (!fs.existsSync(currentPath)) {
      errors.push(`${group.wave}: current file missing: ${relativePath}`);
      continue;
    }
    const record = records.get(relativePath);
    if (!record) {
      errors.push(`${group.wave}: LCOV record missing: ${relativePath}`);
      continue;
    }
    const candidateBaseline = path.join(root, group.baselineRoot, relativePath);
    const baselineExists = fs.existsSync(candidateBaseline);
    if (!baselineExists && !newPaths.has(relativePath)) {
      errors.push(
        `${group.wave}: baseline missing without newPaths declaration: ${relativePath}`,
      );
      continue;
    }
    if (baselineExists && newPaths.has(relativePath)) {
      errors.push(
        `${group.wave}: path is declared new but baseline exists: ${relativePath}`,
      );
      continue;
    }
    const changed = changedLines(
      baselineExists ? candidateBaseline : null,
      currentPath,
      record.lines,
    );
    const coveredChanged = [...changed].filter((line) => record.lines.has(line));
    const missedChangedLines = coveredChanged.filter(
      (line) => record.lines.get(line) === 0,
    );
    const hit = coveredChanged.length - missedChangedLines.length;
    const found = coveredChanged.length;
    if (changed.size === 0) {
      errors.push(`${group.wave}: allowlisted file has no source change: ${relativePath}`);
    }
    rows.push({
      path: relativePath,
      baseline: baselineExists
        ? normalize(path.relative(root, candidateBaseline))
        : 'NEW_FILE',
      changedSourceLines: changed.size,
      instrumentedChangedLines: found,
      hitChangedLines: hit,
      missedChangedLines,
      percent: found === 0 ? null : Number(((hit / found) * 100).toFixed(2)),
    });
    groupFound += found;
    groupHit += hit;
  }
  groups.push({
    wave: group.wave,
    files: rows.length,
    deletionOnlyFiles: deletionOnlyRows.length,
    deletionOnlyRows,
    instrumentedChangedLines: groupFound,
    hitChangedLines: groupHit,
    percent:
      groupFound === 0 ? null : Number(((groupHit / groupFound) * 100).toFixed(2)),
    rows,
  });
  changedFound += groupFound;
  changedHit += groupHit;
}

const globalPercent = Number(((globalHit / globalFound) * 100).toFixed(2));
const changedPercent = Number(((changedHit / changedFound) * 100).toFixed(2));
const groupThresholds = groups.map((group) => ({
  wave: group.wave,
  actual: group.percent,
  minimum: config.changedMinimumPercent,
  status:
    group.percent !== null && group.percent >= config.changedMinimumPercent
      ? 'PASS'
      : 'FAIL',
}));
const thresholds = {
  global: {
    actual: globalPercent,
    minimum: config.globalMinimumPercent,
    status: globalPercent >= config.globalMinimumPercent ? 'PASS' : 'FAIL',
  },
  changed: {
    actual: changedPercent,
    minimum: config.changedMinimumPercent,
    status: changedPercent >= config.changedMinimumPercent ? 'PASS' : 'FAIL',
  },
  groups: groupThresholds,
};
const status =
  errors.length === 0 &&
  thresholds.global.status === 'PASS' &&
  thresholds.changed.status === 'PASS' &&
  groupThresholds.every((group) => group.status === 'PASS')
    ? 'PASS'
    : 'FAIL';

console.log(
  JSON.stringify(
    {
      status,
      coverageKind: config.coverageKind,
      baselineId: config.baselineId,
      lcovPath: normalize(path.relative(root, lcovPath)),
      global: { found: globalFound, hit: globalHit, percent: globalPercent },
      changed: { found: changedFound, hit: changedHit, percent: changedPercent },
      thresholds,
      exclusions: config.excludedPatterns,
      groups,
      errors,
    },
    null,
    2,
  ),
);

if (status !== 'PASS') process.exitCode = 1;
