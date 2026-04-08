param(
  [Parameter(Mandatory = $true)]
  [string]$Owner,

  [string]$Repo = 'PawMate',

  [ValidateSet('public', 'private')]
  [string]$Visibility = 'private',

  [string]$RemoteName = 'origin',

  [switch]$CreateRepo,

  [switch]$PushBranches,

  [switch]$OpenRepoPages,

  [string]$LocalAuthorName,

  [string]$LocalAuthorEmail
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$workspaceRoot = Split-Path -Parent $repoRoot
$gh = Join-Path $workspaceRoot 'tools\gh\bin\gh.exe'

if (!(Test-Path $gh)) {
  throw "Portable GitHub CLI not found at $gh."
}

& $gh auth status *> $null
if ($LASTEXITCODE -ne 0) {
  throw "GitHub CLI is not authenticated yet. Run `D:\My Playground\tools\gh\bin\gh.exe auth login --web` first."
}

if ($LocalAuthorName) {
  git -C $repoRoot config user.name $LocalAuthorName
}

if ($LocalAuthorEmail) {
  git -C $repoRoot config user.email $LocalAuthorEmail
}

$repoSlug = "$Owner/$Repo"
$remoteUrl = "https://github.com/$repoSlug.git"
$existingRemote = git -C $repoRoot remote get-url $RemoteName 2>$null

if (!$existingRemote) {
  if ($CreateRepo) {
    & $gh repo create $repoSlug "--$Visibility" --source $repoRoot --remote $RemoteName
    if ($LASTEXITCODE -ne 0) {
      throw "Failed to create GitHub repository $repoSlug."
    }
  } else {
    git -C $repoRoot remote add $RemoteName $remoteUrl
  }
} else {
  git -C $repoRoot remote set-url $RemoteName $remoteUrl
}

$currentBranch = git -C $repoRoot symbolic-ref --short HEAD 2>$null
$hasCommit = $true
git -C $repoRoot rev-parse --verify HEAD *> $null
if ($LASTEXITCODE -ne 0) {
  $hasCommit = $false
}

if ($PushBranches) {
  if (!$hasCommit) {
    throw 'This repo does not have a first commit yet. Create a local commit before pushing to GitHub.'
  }

  $branches = @(git -C $repoRoot for-each-ref --format='%(refname:short)' refs/heads)
  if ($currentBranch -and $branches -notcontains $currentBranch) {
    $branches += $currentBranch
  }

  $branches = $branches | Where-Object { $_ } | Select-Object -Unique

  foreach ($branch in $branches) {
    git -C $repoRoot push -u $RemoteName $branch
  }
}

if ($OpenRepoPages) {
  Start-Process "https://github.com/$repoSlug"
  Start-Process "https://github.com/$repoSlug/settings/branches"
}

$protectionUrl = "https://github.com/$repoSlug/settings/branches"
$authorName = git -C $repoRoot config --get user.name
$authorEmail = git -C $repoRoot config --get user.email

Write-Output "GitHub remote prepared: $remoteUrl"
Write-Output "Current branch: $currentBranch"
Write-Output "Has first commit: $hasCommit"
Write-Output "Local git author: $authorName <$authorEmail>"
Write-Output "Branch protection URL: $protectionUrl"
