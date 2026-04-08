param(
  [Parameter(Mandatory = $true)]
  [string]$SupabaseUrl,

  [Parameter(Mandatory = $true)]
  [string]$PublishableKey,

  [Parameter(Mandatory = $true)]
  [string]$SecretKey,

  [string]$ProjectRef,

  [string]$RedirectUrl = 'https://app.pawmate.example/auth/callback',

  [string]$MobileRedirectUrl = 'pawmate://auth/callback',

  [string]$EnvFilePath
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$targetPath = if ($EnvFilePath) {
  $EnvFilePath
} else {
  Join-Path $repoRoot 'backend\.env.local'
}

$projectRefValue = if ($ProjectRef) {
  $ProjectRef
} else {
  try {
    ([Uri]$SupabaseUrl).Host.Split('.')[0]
  } catch {
    ''
  }
}

$lines = @(
  'APP_NAME=PawMate Backend'
  'NODE_ENV=development'
  'HOST=0.0.0.0'
  'PORT=3000'
  'LOG_LEVEL=info'
  ''
  '# Local runtime defaults'
  'DATABASE_URL=postgresql://pawmate:pawmate@localhost:5432/pawmate'
  'REDIS_URL=redis://localhost:6379'
  ''
  '# Supabase'
  "SUPABASE_PROJECT_REF=$projectRefValue"
  "SUPABASE_URL=$SupabaseUrl"
  "SUPABASE_PUBLISHABLE_KEY=$PublishableKey"
  "SUPABASE_SECRET_KEY=$SecretKey"
  'SUPABASE_ANON_KEY='
  'SUPABASE_SERVICE_ROLE_KEY='
  "SUPABASE_AUTH_REDIRECT_URL=$RedirectUrl"
  "SUPABASE_AUTH_MOBILE_REDIRECT_URL=$MobileRedirectUrl"
  'SUPABASE_BUCKET_AVATARS=avatars'
  'SUPABASE_BUCKET_PET_PHOTOS=pet-photos'
  'SUPABASE_BUCKET_POSTS=posts'
)

$parent = Split-Path -Parent $targetPath
if (!(Test-Path $parent)) {
  New-Item -ItemType Directory -Path $parent | Out-Null
}

Set-Content -LiteralPath $targetPath -Value $lines -Encoding ascii

Write-Output "Supabase env file created at $targetPath"
Write-Output 'Next step: cd backend && npm run supabase:bootstrap'
