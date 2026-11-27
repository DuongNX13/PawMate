const { spawnSync } = require('child_process');
const path = require('path');

const backendRoot = path.resolve(__dirname, '..');

const runGenerate = () => {
  const args = ['prisma', 'generate', ...process.argv.slice(2)];
  const command = process.platform === 'win32' ? process.env.ComSpec || 'cmd.exe' : 'npx';
  const spawnArgs =
    process.platform === 'win32'
      ? [
          '/d',
          '/s',
          '/c',
          ['npx.cmd', ...args].join(' '),
        ]
      : args;
  const result = spawnSync(command, spawnArgs, {
    cwd: backendRoot,
    env: process.env,
    stdio: 'inherit',
    shell: false,
  });

  if (result.error) throw result.error;
  process.exitCode = result.status ?? 1;
};

const readWindowsHolders = () => {
  const tasklist = spawnSync(
    'tasklist.exe',
    ['/m', 'query_engine-windows.dll.node', '/fo', 'csv', '/nh'],
    { encoding: 'utf8', windowsHide: true },
  );
  if (tasklist.error || tasklist.status !== 0) return [];

  const pids = [...tasklist.stdout.matchAll(/"node\.exe","(\d+)"/gi)].map((match) => match[1]);
  if (pids.length === 0) return [];

  const powershellScript = [
    '$ids = @(' + pids.join(',') + ')',
    '$all = @(Get-CimInstance Win32_Process)',
    '$all | Where-Object { $ids -contains $_.ProcessId } | ForEach-Object {',
    '  $parentPid = $_.ParentProcessId',
    '  [PSCustomObject]@{',
    '    pid = $_.ProcessId',
    '    parentPid = $_.ParentProcessId',
    '    parentAlive = [bool]($all | Where-Object { $_.ProcessId -eq $parentPid })',
    '    commandLine = $_.CommandLine',
    '  }',
    '} | ConvertTo-Json -Compress',
  ].join(';');
  const details = spawnSync(
    'powershell.exe',
    ['-NoProfile', '-NonInteractive', '-Command', powershellScript],
    { encoding: 'utf8', windowsHide: true },
  );
  if (details.error || details.status !== 0 || !details.stdout.trim()) return [];

  try {
    const parsed = JSON.parse(details.stdout.trim());
    return Array.isArray(parsed) ? parsed : [parsed];
  } catch {
    return [];
  }
};

const stopVerifiedStaleProof = (holder) => {
  const commandLine = String(holder.commandLine || '');
  const normalized = commandLine.toLowerCase().replaceAll('/', '\\');
  const isPawMateProof =
    normalized.includes('pawmate\\temp\\proof\\') &&
    normalized.includes('start-no-supabase.cjs');
  if (!isPawMateProof || holder.parentAlive) return false;

  const stop = spawnSync(
    'powershell.exe',
    [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      `Stop-Process -Id ${Number(holder.pid)} -Force -ErrorAction Stop`,
    ],
    { encoding: 'utf8', windowsHide: true },
  );
  if (stop.error || stop.status !== 0) {
    throw new Error(`Unable to stop stale PawMate proof PID ${holder.pid}.`);
  }
  console.log(`Stopped stale PawMate proof process PID ${holder.pid} before Prisma generate.`);
  return true;
};

if (process.platform !== 'win32') {
  runGenerate();
} else {
  const holders = readWindowsHolders();
  const activeHolders = holders.filter((holder) => !stopVerifiedStaleProof(holder));
  if (activeHolders.length > 0) {
    const detail = activeHolders
      .map((holder) => `PID ${holder.pid}: ${String(holder.commandLine || '').trim()}`)
      .join('\n');
    throw new Error(
      `Prisma query-engine DLL is in use by an active PawMate process. Stop it, then rerun npm run prisma:generate.\n${detail}`,
    );
  }
  runGenerate();
}
