param(
  [int]$Port = 5432
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$workspaceRoot = Split-Path -Parent $repoRoot
$pgHome = if ($env:PAWMATE_PG_HOME) { $env:PAWMATE_PG_HOME } else { Join-Path $workspaceRoot 'tools\pgsql' }
$dataDir = if ($env:PAWMATE_PG_DATA) { $env:PAWMATE_PG_DATA } else { Join-Path $workspaceRoot 'tools\pgsql-data' }
$logFile = Join-Path $workspaceRoot 'tools\pgsql.log'
$patchFile = Join-Path $repoRoot 'backend\prisma\sql\day1_postgis_patch.sql'

$pgCtl = Join-Path $pgHome 'bin\pg_ctl.exe'
$initdb = Join-Path $pgHome 'bin\initdb.exe'
$createdb = Join-Path $pgHome 'bin\createdb.exe'
$psql = Join-Path $pgHome 'bin\psql.exe'

if (!(Test-Path $pgCtl)) {
  throw "Portable PostgreSQL not found at $pgHome. Download the EDB Windows binaries first."
}

if (!(Test-Path $patchFile)) {
  throw "PostGIS patch file not found at $patchFile."
}

if (!(Test-Path $dataDir)) {
  & $initdb -D $dataDir -U pawmate -A trust --locale=C
  if ($LASTEXITCODE -ne 0) {
    throw "initdb failed for $dataDir."
  }
}

& $pgCtl -D $dataDir status *> $null
if ($LASTEXITCODE -ne 0) {
  & $pgCtl -D $dataDir -l $logFile -o "-p $Port" start
  if ($LASTEXITCODE -ne 0) {
    throw "Portable PostgreSQL failed to start. See $logFile."
  }
  Start-Sleep -Seconds 3
}

$dbExists = & $psql -p $Port -U pawmate -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = 'pawmate';"
if ($LASTEXITCODE -ne 0) {
  throw "Failed to query PostgreSQL for database existence."
}

if ($dbExists.Trim() -ne '1') {
  & $createdb -p $Port -U pawmate pawmate
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to create database 'pawmate'."
  }
}

& $psql -p $Port -U pawmate -d pawmate -f $patchFile
if ($LASTEXITCODE -ne 0) {
  throw "Failed to apply PostGIS patch file $patchFile."
}

Write-Output "Portable PostgreSQL/PostGIS ready at postgresql://pawmate@127.0.0.1:$Port/pawmate"
