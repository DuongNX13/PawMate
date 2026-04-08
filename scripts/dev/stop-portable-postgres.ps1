$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$workspaceRoot = Split-Path -Parent $repoRoot
$pgHome = if ($env:PAWMATE_PG_HOME) { $env:PAWMATE_PG_HOME } else { Join-Path $workspaceRoot 'tools\pgsql' }
$dataDir = if ($env:PAWMATE_PG_DATA) { $env:PAWMATE_PG_DATA } else { Join-Path $workspaceRoot 'tools\pgsql-data' }
$pgCtl = Join-Path $pgHome 'bin\pg_ctl.exe'

if (!(Test-Path $pgCtl) -or !(Test-Path $dataDir)) {
  Write-Output 'Portable PostgreSQL is not provisioned locally.'
  exit 0
}

& $pgCtl -D $dataDir status *> $null
if ($LASTEXITCODE -eq 0) {
  & $pgCtl -D $dataDir stop
} else {
  Write-Output 'Portable PostgreSQL is already stopped.'
}

