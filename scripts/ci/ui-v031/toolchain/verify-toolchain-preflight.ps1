[CmdletBinding()]
param(
  [string]$RepoRoot,
  [string]$LockFile
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
  $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
} else {
  $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
}

if ([string]::IsNullOrWhiteSpace($LockFile)) {
  $LockFile = Join-Path $RepoRoot 'docs\qa\ui-v031\toolchain\TOOLCHAIN_LOCK.json'
}
$LockFile = (Resolve-Path -LiteralPath $LockFile).Path
$lock = Get-Content -LiteralPath $LockFile -Encoding utf8 | ConvertFrom-Json

$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)]$Expected,
    [Parameter(Mandatory = $true)]$Actual,
    [bool]$Required = $true
  )

  $expectedText = [string]$Expected
  $actualText = [string]$Actual
  $checks.Add([pscustomobject]@{
    name = $Name
    required = $Required
    expected = $expectedText
    actual = $actualText
    passed = $expectedText -ceq $actualText
  })
}

function Get-FileHashOrMissing {
  param([Parameter(Mandatory = $true)][string]$Path)
  if (!(Test-Path -LiteralPath $Path -PathType Leaf)) {
    return '<missing>'
  }
  return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash
}

function Get-ForwardSlashPath {
  param([Parameter(Mandatory = $true)][string]$Path)
  return $Path.Replace('\', '/')
}

$approvedLauncher = [string]$lock.local.flutter.launcher
$launcherWindows = $approvedLauncher.Replace('/', '\')
Add-Check -Name 'flutter.launcher.exists' -Expected 'True' -Actual (Test-Path -LiteralPath $launcherWindows -PathType Leaf)
Add-Check -Name 'flutter.launcher.path' -Expected $approvedLauncher -Actual (Get-ForwardSlashPath (Resolve-Path -LiteralPath $launcherWindows).Path)
Add-Check -Name 'flutter.launcher.sha256' -Expected $lock.local.flutter.launcher_sha256 -Actual (Get-FileHashOrMissing $launcherWindows)

$flutterOutput = & $launcherWindows --version --machine 2>&1
if ($LASTEXITCODE -ne 0) {
  throw "Flutter version probe failed with exit code $LASTEXITCODE."
}
$flutter = ($flutterOutput -join [Environment]::NewLine) | ConvertFrom-Json
Add-Check -Name 'flutter.version' -Expected $lock.local.flutter.framework_version -Actual $flutter.frameworkVersion
Add-Check -Name 'flutter.channel' -Expected $lock.local.flutter.channel -Actual $flutter.channel
Add-Check -Name 'flutter.framework_revision' -Expected $lock.local.flutter.framework_revision -Actual $flutter.frameworkRevision
Add-Check -Name 'flutter.engine_revision' -Expected $lock.local.flutter.engine_revision -Actual $flutter.engineRevision
Add-Check -Name 'flutter.engine_content_hash' -Expected $lock.local.flutter.engine_content_hash -Actual $flutter.engineContentHash
Add-Check -Name 'dart.version' -Expected $lock.local.dart.version -Actual $flutter.dartSdkVersion
Add-Check -Name 'devtools.version' -Expected $lock.local.flutter.devtools_version -Actual $flutter.devToolsVersion

$dartWindows = ([string]$lock.local.dart.executable).Replace('/', '\')
$javaWindows = ([string]$lock.local.java.executable).Replace('/', '\')
Add-Check -Name 'dart.executable.sha256' -Expected $lock.local.dart.executable_sha256 -Actual (Get-FileHashOrMissing $dartWindows)
Add-Check -Name 'java.executable.sha256' -Expected $lock.local.java.executable_sha256 -Actual (Get-FileHashOrMissing $javaWindows)

$javaCommand = '"{0}" -version 2>&1' -f $javaWindows
$javaOutput = & $env:ComSpec /d /c $javaCommand
if ($LASTEXITCODE -ne 0) {
  throw "Java version probe failed with exit code $LASTEXITCODE."
}
$javaMatch = [regex]::Match(($javaOutput -join ' '), 'version\s+"([^"]+)"')
$javaVersion = if ($javaMatch.Success) { $javaMatch.Groups[1].Value } else { '<unparsed>' }
Add-Check -Name 'java.version' -Expected $lock.local.java.version -Actual $javaVersion

foreach ($property in $lock.source_file_hashes.PSObject.Properties) {
  $sourcePath = Join-Path $RepoRoot $property.Name
  Add-Check -Name "source.sha256:$($property.Name)" -Expected $property.Value -Actual (Get-FileHashOrMissing $sourcePath)
}

foreach ($font in $lock.fonts) {
  $fontPath = Join-Path $RepoRoot ([string]$font.path)
  Add-Check -Name "font.sha256:$($font.path)" -Expected $font.sha256 -Actual (Get-FileHashOrMissing $fontPath)
  if (Test-Path -LiteralPath $fontPath -PathType Leaf) {
    Add-Check -Name "font.bytes:$($font.path)" -Expected $font.bytes -Actual (Get-Item -LiteralPath $fontPath).Length
  }
}

$flutterExtensionPath = Join-Path ([string]$lock.local.flutter.root).Replace('/', '\') 'packages\flutter_tools\gradle\src\main\kotlin\FlutterExtension.kt'
Add-Check -Name 'android.flutter_extension.sha256' -Expected 'CDB7C4E296C353DCBEBD409157759CC552DD1A041603F79F9ED81618C8B44EA5' -Actual (Get-FileHashOrMissing $flutterExtensionPath)

$head = (& git -C $RepoRoot rev-parse HEAD 2>&1 | Select-Object -First 1)
$branch = (& git -C $RepoRoot branch --show-current 2>&1 | Select-Object -First 1)
$dirtyEntries = @(& git -C $RepoRoot status --porcelain=v1).Count

$failedRequired = @($checks | Where-Object { $_.required -and !$_.passed })
$knownGaps = @($lock.known_gaps)
$result = if ($failedRequired.Count -gt 0) {
  'FAIL'
} elseif ($knownGaps.Count -gt 0) {
  'PASS_WITH_KNOWN_GAPS'
} else {
  'PASS'
}

$report = [ordered]@{
  schema_version = '1.0'
  checked_at = (Get-Date).ToString('o')
  baseline_id = $lock.baseline_id
  result = $result
  repository = [ordered]@{
    root = Get-ForwardSlashPath $RepoRoot
    expected_head = $lock.repository.head
    actual_head = [string]$head
    expected_branch = $lock.repository.branch
    actual_branch = [string]$branch
    dirty_entries_informational = $dirtyEntries
  }
  approved_flutter_launcher = $approvedLauncher
  lock_file = Get-ForwardSlashPath $LockFile
  checks = @($checks)
  failed_required_checks = @($failedRequired | ForEach-Object { $_.name })
  known_gaps = $knownGaps
  contains_secrets = $false
  mutates_repository = $false
}

$report | ConvertTo-Json -Depth 10
if ($failedRequired.Count -gt 0) {
  exit 2
}
exit 0
