import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(scriptDirectory, '../../..');
const mobileRoot = path.join(repoRoot, 'mobile');

function parseArgs(argv) {
  const separator = argv.indexOf('--');
  if (separator < 0) {
    throw new Error('Usage: --output <repo-relative-path> -- <flutter arguments>');
  }
  const control = argv.slice(0, separator);
  const flutterArgs = argv.slice(separator + 1);
  const outputIndex = control.indexOf('--output');
  if (outputIndex < 0 || !control[outputIndex + 1] || flutterArgs.length === 0) {
    throw new Error('Both --output and Flutter arguments are required.');
  }
  const output = control[outputIndex + 1].replaceAll('\\', '/');
  if (
    path.posix.isAbsolute(output) ||
    output.split('/').includes('..') ||
    !output.startsWith('output-evidence/')
  ) {
    throw new Error('--output must be a traversal-free repo-relative output-evidence path.');
  }
  return { output, flutterArgs };
}

function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex').toUpperCase();
}

function main() {
  const { output, flutterArgs } = parseArgs(process.argv.slice(2));
  const flutterBin = process.env.FLUTTER_BIN || 'D:\\mp\\tools\\flutter\\bin\\flutter.bat';
  if (!fs.existsSync(flutterBin)) {
    throw new Error(`Flutter executable is missing: ${flutterBin}`);
  }
  const startedAt = new Date().toISOString();
  const quoteForCmd = (value) => {
    const text = String(value);
    return /\s/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
  };
  const commandLine = [flutterBin, ...flutterArgs].map(quoteForCmd).join(' ');
  const result = spawnSync('cmd.exe', ['/d', '/s', '/c', commandLine], {
    cwd: mobileRoot,
    encoding: 'utf8',
    windowsHide: true,
  });
  if (result.error) {
    throw result.error;
  }
  const finishedAt = new Date().toISOString();
  const raw = [result.stdout, result.stderr].filter(Boolean).join('\n');
  const outputPath = path.join(repoRoot, output);
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, raw, 'utf8');
  const metadata = {
    schema: 'pawmate.flutter-evidence.v1',
    command: [flutterBin, ...flutterArgs],
    working_directory: 'mobile',
    started_at: startedAt,
    finished_at: finishedAt,
    exit_code: result.status,
    evidence_path: output,
    evidence_sha256: sha256(Buffer.from(raw)),
    evidence_bytes: Buffer.byteLength(raw),
  };
  fs.writeFileSync(
    `${outputPath}.metadata.json`,
    `${JSON.stringify(metadata, null, 2)}\n`,
    'utf8',
  );
  console.log(JSON.stringify(metadata));
  process.exitCode = result.status ?? 1;
}

main();
