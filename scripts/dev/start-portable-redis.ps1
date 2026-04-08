param(
  [int]$Port = 6379
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$workspaceRoot = Split-Path -Parent $repoRoot
$redisHome = if ($env:PAWMATE_REDIS_HOME) { $env:PAWMATE_REDIS_HOME } else { Join-Path $workspaceRoot 'tools\redis-portable' }
$server = Join-Path $redisHome 'redis-server.exe'
$cli = Join-Path $redisHome 'redis-cli.exe'
$pidFile = Join-Path $workspaceRoot 'tools\redis-portable.pid'
$stdoutLogFile = Join-Path $workspaceRoot 'tools\redis-portable.log'
$stderrLogFile = Join-Path $workspaceRoot 'tools\redis-portable.err.log'

if (!(Test-Path $server) -or !(Test-Path $cli)) {
  throw "Portable Redis not found at $redisHome. Download the release zip first."
}

try {
  $pong = & $cli -p $Port ping 2>$null
  if ($pong -eq 'PONG') {
    Write-Output "Portable Redis already responding on port $Port."
    exit 0
  }
} catch {
}

$process = Start-Process -FilePath $server -ArgumentList '--port', $Port, '--appendonly', 'yes' -WorkingDirectory $redisHome -RedirectStandardOutput $stdoutLogFile -RedirectStandardError $stderrLogFile -PassThru -WindowStyle Hidden
$process.Id | Set-Content -Path $pidFile
Start-Sleep -Seconds 2

$pong = & $cli -p $Port ping
if ($pong -ne 'PONG') {
  throw "Portable Redis failed to respond on port $Port. Check $stdoutLogFile and $stderrLogFile."
}

Write-Output "Portable Redis ready at redis://127.0.0.1:$Port"
