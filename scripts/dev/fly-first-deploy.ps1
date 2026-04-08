param(
  [Parameter(Mandatory = $true)]
  [string]$AppName,

  [string]$PrimaryRegion = 'sin',

  [string]$ConfigOutputPath,

  [switch]$GenerateOnly
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$workspaceRoot = Split-Path -Parent $repoRoot
$fly = Join-Path $workspaceRoot 'tools\flyctl\flyctl.exe'
$templatePath = Join-Path $repoRoot 'deploy\fly.staging.template.toml'
$outputPath = if ($ConfigOutputPath) {
  $ConfigOutputPath
} else {
  Join-Path $repoRoot 'fly.staging.generated.toml'
}

if (!(Test-Path $fly)) {
  throw "Portable flyctl not found at $fly."
}

if (!(Test-Path $templatePath)) {
  throw "Fly template not found at $templatePath."
}

$template = Get-Content -Raw $templatePath
$rendered = $template.Replace('__FLY_APP_NAME__', $AppName).Replace('__FLY_PRIMARY_REGION__', $PrimaryRegion)
Set-Content -LiteralPath $outputPath -Value $rendered -Encoding ascii

Write-Output "Generated Fly config at $outputPath"

if ($GenerateOnly) {
  exit 0
}

& $fly auth whoami *> $null
if ($LASTEXITCODE -ne 0 -and !$env:FLY_ACCESS_TOKEN) {
  throw "Fly is not authenticated yet. Run `D:\My Playground\tools\flyctl\flyctl.exe auth login` or set FLY_ACCESS_TOKEN first."
}

& $fly deploy --config $outputPath --remote-only
