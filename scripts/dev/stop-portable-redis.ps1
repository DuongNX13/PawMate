$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$workspaceRoot = Split-Path -Parent $repoRoot
$pidFile = Join-Path $workspaceRoot 'tools\redis-portable.pid'

if (!(Test-Path $pidFile)) {
  Write-Output 'Portable Redis pid file not found. Nothing to stop.'
  exit 0
}

$redisPid = Get-Content -Path $pidFile | Select-Object -First 1
if ($redisPid) {
  Stop-Process -Id ([int]$redisPid) -Force -ErrorAction SilentlyContinue
}

Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
Write-Output 'Portable Redis stopped.'
