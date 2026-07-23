[CmdletBinding()]
param(
    [ValidateSet('Snapshot', 'Verify')]
    [string]$Mode = 'Verify',

    [string]$RepoRoot,

    [string]$ConfigPath,

    [string]$BaselineManifest,

    [string]$BaselineJson,

    [string]$OwnerDeltaManifest,

    [string]$OwnerDeltaJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Join-Path $PSScriptRoot '..\..\..\..'
}
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $PSScriptRoot 'protected-paths.json'
}

function Write-ResultAndExit {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Result,

        [Parameter(Mandatory = $true)]
        [int]$ExitCode
    )

    $json = $Result | ConvertTo-Json -Depth 12
    [System.Console]::Out.WriteLine($json)
    [System.Console]::Out.Flush()
    exit $ExitCode
}

function Get-FullPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    return [System.IO.Path]::GetFullPath($Path)
}

function Get-RootWithSeparator {
    param([Parameter(Mandatory = $true)][string]$Root)

    $trimmed = (Get-FullPath -Path $Root).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    return $trimmed + [System.IO.Path]::DirectorySeparatorChar
}

function Assert-PathUnderRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $rootFull = (Get-FullPath -Path $Root).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    $pathFull = Get-FullPath -Path $Path
    $rootPrefix = Get-RootWithSeparator -Root $rootFull

    $isRoot = $pathFull.Equals(
        $rootFull,
        [System.StringComparison]::OrdinalIgnoreCase
    )
    $isChild = $pathFull.StartsWith(
        $rootPrefix,
        [System.StringComparison]::OrdinalIgnoreCase
    )

    if (-not ($isRoot -or $isChild)) {
        throw "$Label resolves outside the repository root: $Path"
    }

    return $pathFull
}

function Get-RelativePathNormalized {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $rootUri = [System.Uri](Get-RootWithSeparator -Root $Root)
    $pathUri = [System.Uri](Get-FullPath -Path $Path)
    $relative = [System.Uri]::UnescapeDataString(
        $rootUri.MakeRelativeUri($pathUri).ToString()
    )
    return $relative.Replace('\', '/')
}

function Assert-NormalizedRelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "$Label contains an empty path."
    }
    if ($Path.Contains('\') -or $Path.StartsWith('/') -or $Path.StartsWith('./')) {
        throw "$Label path is not normalized: $Path"
    }
    if ($Path -match '(^|/)\.\.(/|$)' -or $Path -match '^[A-Za-z]:') {
        throw "$Label path escapes or is absolute: $Path"
    }
}

function Get-FileSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)

    $itemBefore = Get-Item -LiteralPath $Path -Force
    if ($itemBefore.PSIsContainer) {
        throw "Expected a file but found a directory: $Path"
    }
    if (($itemBefore.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Protected files cannot be reparse points: $Path"
    }

    $lengthBefore = [int64]$itemBefore.Length
    $writeTicksBefore = $itemBefore.LastWriteTimeUtc.Ticks
    $hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
    $itemAfter = Get-Item -LiteralPath $Path -Force

    if (
        [int64]$itemAfter.Length -ne $lengthBefore -or
        $itemAfter.LastWriteTimeUtc.Ticks -ne $writeTicksBefore
    ) {
        throw "Protected file changed while it was being hashed: $Path"
    }

    return [pscustomobject]@{
        sha256 = $hash
        length = $lengthBefore
    }
}

function Get-TextSha256 {
    param([AllowEmptyString()][string]$Text)

    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        $hash = $sha256.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hash)).Replace('-', '')
    }
    finally {
        $sha256.Dispose()
    }
}

function Read-JsonDocument {
    param(
        [string]$Path,
        [string]$Json,
        [Parameter(Mandatory = $true)][string]$Label,
        [switch]$Required
    )

    if (-not [string]::IsNullOrWhiteSpace($Path) -and -not [string]::IsNullOrWhiteSpace($Json)) {
        throw "$Label accepts either a manifest path or raw JSON, not both."
    }

    $raw = $null
    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        if ($Path -eq 'STDIN') {
            $raw = [System.Console]::In.ReadToEnd()
        }
        else {
            $fullPath = Get-FullPath -Path $Path
            if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
                throw "$Label was not found: $Path"
            }
            $raw = [System.IO.File]::ReadAllText($fullPath, [System.Text.Encoding]::UTF8)
        }
    }
    elseif (-not [string]::IsNullOrWhiteSpace($Json)) {
        $raw = $Json
    }
    elseif ($Required) {
        throw "$Label is required."
    }
    else {
        return $null
    }

    try {
        return $raw | ConvertFrom-Json
    }
    catch {
        throw "$Label is not valid JSON: $($_.Exception.Message)"
    }
}

function Test-IsExcluded {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][object[]]$Patterns
    )

    foreach ($pattern in $Patterns) {
        if ($pattern.IsMatch($RelativePath)) {
            return $true
        }
    }
    return $false
}

function Get-RuleFiles {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRootFull,
        [Parameter(Mandatory = $true)][object]$Config
    )

    $excludePatterns = @(
        foreach ($patternText in @($Config.excludeGlobs)) {
            [System.Management.Automation.WildcardPattern]::new(
                [string]$patternText,
                [System.Management.Automation.WildcardOptions]::IgnoreCase
            )
        }
    )

    $filesByKey = @{}

    foreach ($rule in @($Config.rules)) {
        if (-not ($rule.PSObject.Properties.Name -contains 'type')) {
            throw 'A protected-path rule is missing type.'
        }
        if (-not ($rule.PSObject.Properties.Name -contains 'path')) {
            throw 'A protected-path rule is missing path.'
        }

        $ruleType = [string]$rule.type
        $ruleRelativePath = ([string]$rule.path).Replace('\', '/')
        Assert-NormalizedRelativePath -Path $ruleRelativePath -Label 'Config rule'
        $ruleFullPath = Assert-PathUnderRoot `
            -Root $RepoRootFull `
            -Path (Join-Path $RepoRootFull $ruleRelativePath) `
            -Label 'Config rule'

        $candidates = @()
        switch ($ruleType) {
            'file' {
                if (Test-Path -LiteralPath $ruleFullPath -PathType Leaf) {
                    $candidates = @(Get-Item -LiteralPath $ruleFullPath -Force)
                }
            }
            'tree' {
                if (Test-Path -LiteralPath $ruleFullPath -PathType Container) {
                    $candidates = @(
                        Get-ChildItem `
                            -LiteralPath $ruleFullPath `
                            -Recurse `
                            -File `
                            -Force
                    )
                }
            }
            'glob' {
                if (-not ($rule.PSObject.Properties.Name -contains 'patterns')) {
                    throw "Glob rule is missing patterns: $ruleRelativePath"
                }

                $recursive = $false
                if ($rule.PSObject.Properties.Name -contains 'recursive') {
                    $recursive = [bool]$rule.recursive
                }

                if (Test-Path -LiteralPath $ruleFullPath -PathType Container) {
                    $globPatterns = @(
                        foreach ($globText in @($rule.patterns)) {
                            [System.Management.Automation.WildcardPattern]::new(
                                [string]$globText,
                                [System.Management.Automation.WildcardOptions]::IgnoreCase
                            )
                        }
                    )

                    $available = if ($recursive) {
                        @(Get-ChildItem -LiteralPath $ruleFullPath -Recurse -File -Force)
                    }
                    else {
                        @(Get-ChildItem -LiteralPath $ruleFullPath -File -Force)
                    }

                    $candidates = @(
                        foreach ($candidate in $available) {
                            $matchTarget = if ($recursive) {
                                Get-RelativePathNormalized `
                                    -Root $ruleFullPath `
                                    -Path $candidate.FullName
                            }
                            else {
                                $candidate.Name
                            }

                            foreach ($globPattern in $globPatterns) {
                                if ($globPattern.IsMatch($matchTarget)) {
                                    $candidate
                                    break
                                }
                            }
                        }
                    )
                }
            }
            default {
                throw "Unknown protected-path rule type: $ruleType"
            }
        }

        foreach ($candidate in $candidates) {
            $candidateFullPath = Assert-PathUnderRoot `
                -Root $RepoRootFull `
                -Path $candidate.FullName `
                -Label 'Protected file'
            $relativePath = Get-RelativePathNormalized `
                -Root $RepoRootFull `
                -Path $candidateFullPath
            Assert-NormalizedRelativePath -Path $relativePath -Label 'Protected file'

            if (Test-IsExcluded -RelativePath $relativePath -Patterns $excludePatterns) {
                continue
            }

            $key = $relativePath.ToLowerInvariant()
            if (-not $filesByKey.ContainsKey($key)) {
                $filesByKey[$key] = [pscustomobject]@{
                    path = $relativePath
                    fullPath = $candidateFullPath
                }
            }
        }
    }

    return @(
        $filesByKey.Values |
            Sort-Object -Property path
    )
}

function Get-BaselineIdFromFiles {
    param([Parameter(Mandatory = $true)][object[]]$Files)

    $rows = @(
        foreach ($file in ($Files | Sort-Object -Property path)) {
            '{0}|{1}|{2}' -f $file.path, $file.sha256, ([int64]$file.length)
        }
    )
    return Get-TextSha256 -Text ($rows -join "`n")
}

function New-ProtectedSnapshot {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRootFull,
        [Parameter(Mandatory = $true)][object]$Config,
        [Parameter(Mandatory = $true)][string]$ConfigSha256
    )

    $manifestFiles = @(
        foreach ($file in (Get-RuleFiles -RepoRootFull $RepoRootFull -Config $Config)) {
            $hashRecord = Get-FileSha256 -Path $file.fullPath
            [pscustomobject]@{
                path = $file.path
                sha256 = $hashRecord.sha256
                length = [int64]$hashRecord.length
            }
        }
    )

    return [pscustomobject]@{
        schemaVersion = 1
        kind = 'pawmate-protected-paths-baseline'
        policyId = [string]$Config.policyId
        baselineId = Get-BaselineIdFromFiles -Files $manifestFiles
        generatedAtUtc = [System.DateTimeOffset]::UtcNow.ToString('o')
        configSha256 = $ConfigSha256
        files = $manifestFiles
    }
}

function Convert-ManifestFilesToMap {
    param(
        [Parameter(Mandatory = $true)][object[]]$Files,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $map = @{}
    foreach ($file in $Files) {
        foreach ($field in @('path', 'sha256', 'length')) {
            if (-not ($file.PSObject.Properties.Name -contains $field)) {
                throw "$Label file entry is missing $field."
            }
        }

        $path = [string]$file.path
        Assert-NormalizedRelativePath -Path $path -Label $Label
        $sha256 = ([string]$file.sha256).ToUpperInvariant()
        if ($sha256 -notmatch '^[0-9A-F]{64}$') {
            throw "$Label contains an invalid SHA-256 for $path."
        }

        $length = [int64]$file.length
        if ($length -lt 0) {
            throw "$Label contains a negative length for $path."
        }

        $key = $path.ToLowerInvariant()
        if ($map.ContainsKey($key)) {
            throw "$Label contains a duplicate path: $path"
        }

        $map[$key] = [pscustomobject]@{
            path = $path
            sha256 = $sha256
            length = $length
        }
    }
    return $map
}

function Assert-BaselineManifest {
    param(
        [Parameter(Mandatory = $true)][object]$Baseline,
        [Parameter(Mandatory = $true)][object]$Config,
        [Parameter(Mandatory = $true)][string]$ConfigSha256
    )

    foreach ($field in @(
        'schemaVersion',
        'kind',
        'policyId',
        'baselineId',
        'configSha256',
        'files'
    )) {
        if (-not ($Baseline.PSObject.Properties.Name -contains $field)) {
            throw "Baseline manifest is missing $field."
        }
    }

    if ([int]$Baseline.schemaVersion -ne 1) {
        throw 'Baseline schemaVersion must be 1.'
    }
    if ([string]$Baseline.kind -ne 'pawmate-protected-paths-baseline') {
        throw 'Baseline kind is invalid.'
    }
    if ([string]$Baseline.policyId -ne [string]$Config.policyId) {
        throw 'Baseline policyId does not match the current policy.'
    }
    if (-not ([string]$Baseline.configSha256).Equals(
        $ConfigSha256,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        throw 'Protected-path config changed; an explicit reviewed baseline is required.'
    }

    $baselineMap = Convert-ManifestFilesToMap `
        -Files @($Baseline.files) `
        -Label 'Baseline manifest'
    $calculatedId = Get-BaselineIdFromFiles -Files @($baselineMap.Values)
    if (-not ([string]$Baseline.baselineId).Equals(
        $calculatedId,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        throw 'Baseline ID does not match its file manifest.'
    }
}

function Get-ProtectedDelta {
    param(
        [Parameter(Mandatory = $true)][hashtable]$BaselineMap,
        [Parameter(Mandatory = $true)][hashtable]$CurrentMap
    )

    $allKeys = @(
        @($BaselineMap.Keys) + @($CurrentMap.Keys) |
            Sort-Object -Unique
    )

    return @(
        foreach ($key in $allKeys) {
            $before = if ($BaselineMap.ContainsKey($key)) { $BaselineMap[$key] } else { $null }
            $after = if ($CurrentMap.ContainsKey($key)) { $CurrentMap[$key] } else { $null }

            if ($null -eq $before) {
                [pscustomobject]@{
                    path = $after.path
                    changeType = 'added'
                    beforeSha256 = $null
                    afterSha256 = $after.sha256
                    beforeLength = $null
                    afterLength = $after.length
                }
            }
            elseif ($null -eq $after) {
                [pscustomobject]@{
                    path = $before.path
                    changeType = 'removed'
                    beforeSha256 = $before.sha256
                    afterSha256 = $null
                    beforeLength = $before.length
                    afterLength = $null
                }
            }
            elseif (
                -not $before.sha256.Equals(
                    $after.sha256,
                    [System.StringComparison]::OrdinalIgnoreCase
                ) -or
                $before.length -ne $after.length
            ) {
                [pscustomobject]@{
                    path = $before.path
                    changeType = 'modified'
                    beforeSha256 = $before.sha256
                    afterSha256 = $after.sha256
                    beforeLength = $before.length
                    afterLength = $after.length
                }
            }
        }
    )
}

function Get-NullableSha256 {
    param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string]$Property,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if (-not ($Object.PSObject.Properties.Name -contains $Property)) {
        throw "$Label is missing $Property."
    }

    $value = $Object.$Property
    if ($null -eq $value) {
        return $null
    }

    $textValue = ([string]$value).ToUpperInvariant()
    if ($textValue -notmatch '^[0-9A-F]{64}$') {
        throw "$Label contains an invalid $Property."
    }
    return $textValue
}

function Test-NullableStringEqual {
    param(
        [AllowNull()][string]$Left,
        [AllowNull()][string]$Right
    )

    if ($null -eq $Left -and $null -eq $Right) {
        return $true
    }
    if ($null -eq $Left -or $null -eq $Right) {
        return $false
    }
    return $Left.Equals($Right, [System.StringComparison]::OrdinalIgnoreCase)
}

function Assert-OwnerDeltaManifest {
    param(
        [Parameter(Mandatory = $true)][object]$OwnerDelta,
        [Parameter(Mandatory = $true)][object]$Config,
        [Parameter(Mandatory = $true)][object]$Baseline,
        [Parameter(Mandatory = $true)][object[]]$ActualDelta
    )

    foreach ($field in @($Config.ownerDeltaRequiredFields)) {
        if (-not ($OwnerDelta.PSObject.Properties.Name -contains [string]$field)) {
            throw "Owner delta manifest is missing $field."
        }
    }

    if ([int]$OwnerDelta.schemaVersion -ne 1) {
        throw 'Owner delta schemaVersion must be 1.'
    }
    if ([string]$OwnerDelta.kind -ne 'pawmate-protected-path-owner-delta') {
        throw 'Owner delta kind is invalid.'
    }
    if ([string]$OwnerDelta.policyId -ne [string]$Config.policyId) {
        throw 'Owner delta policyId does not match the current policy.'
    }
    if (-not ([string]$OwnerDelta.baselineId).Equals(
        [string]$Baseline.baselineId,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        throw 'Owner delta baselineId does not match the verified baseline.'
    }

    foreach ($field in @('owner', 'approvedBy', 'reason', 'approvedAtUtc', 'expiresAtUtc')) {
        if ([string]::IsNullOrWhiteSpace([string]$OwnerDelta.$field)) {
            throw "Owner delta $field must be non-empty."
        }
    }

    try {
        $approvedAt = [System.DateTimeOffset]::Parse(
            [string]$OwnerDelta.approvedAtUtc,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::RoundtripKind
        )
        $expiresAt = [System.DateTimeOffset]::Parse(
            [string]$OwnerDelta.expiresAtUtc,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::RoundtripKind
        )
    }
    catch {
        throw "Owner delta approval timestamps are invalid: $($_.Exception.Message)"
    }

    $now = [System.DateTimeOffset]::UtcNow
    if ($approvedAt -gt $now) {
        throw 'Owner delta approval is not effective yet.'
    }
    if ($expiresAt -le $now) {
        throw 'Owner delta approval is expired.'
    }
    if ($expiresAt -le $approvedAt) {
        throw 'Owner delta expiresAtUtc must be after approvedAtUtc.'
    }

    $approvedMap = @{}
    foreach ($change in @($OwnerDelta.changes)) {
        foreach ($field in @('path', 'changeType', 'beforeSha256', 'afterSha256')) {
            if (-not ($change.PSObject.Properties.Name -contains $field)) {
                throw "Owner delta change entry is missing $field."
            }
        }

        $path = [string]$change.path
        Assert-NormalizedRelativePath -Path $path -Label 'Owner delta'
        $changeType = [string]$change.changeType
        if ($changeType -notin @('added', 'removed', 'modified')) {
            throw "Owner delta changeType is invalid for $path."
        }

        $beforeSha256 = Get-NullableSha256 `
            -Object $change `
            -Property 'beforeSha256' `
            -Label "Owner delta $path"
        $afterSha256 = Get-NullableSha256 `
            -Object $change `
            -Property 'afterSha256' `
            -Label "Owner delta $path"

        if ($changeType -eq 'added' -and $null -ne $beforeSha256) {
            throw "Added owner delta must have beforeSha256 null: $path"
        }
        if ($changeType -eq 'removed' -and $null -ne $afterSha256) {
            throw "Removed owner delta must have afterSha256 null: $path"
        }
        if ($changeType -eq 'modified' -and ($null -eq $beforeSha256 -or $null -eq $afterSha256)) {
            throw "Modified owner delta requires both hashes: $path"
        }

        $key = $path.ToLowerInvariant()
        if ($approvedMap.ContainsKey($key)) {
            throw "Owner delta contains a duplicate path: $path"
        }
        $approvedMap[$key] = [pscustomobject]@{
            path = $path
            changeType = $changeType
            beforeSha256 = $beforeSha256
            afterSha256 = $afterSha256
        }
    }

    if ($approvedMap.Count -ne $ActualDelta.Count) {
        throw 'Owner delta paths do not exactly match the observed protected-path delta.'
    }

    foreach ($actual in $ActualDelta) {
        $key = $actual.path.ToLowerInvariant()
        if (-not $approvedMap.ContainsKey($key)) {
            throw "Observed delta is not owner-approved: $($actual.path)"
        }

        $approved = $approvedMap[$key]
        if ($approved.changeType -ne $actual.changeType) {
            throw "Owner delta changeType does not match for $($actual.path)."
        }
        if (-not (Test-NullableStringEqual `
            -Left $approved.beforeSha256 `
            -Right $actual.beforeSha256)) {
            throw "Owner delta beforeSha256 does not match for $($actual.path)."
        }
        if (-not (Test-NullableStringEqual `
            -Left $approved.afterSha256 `
            -Right $actual.afterSha256)) {
            throw "Owner delta afterSha256 does not match for $($actual.path)."
        }
    }
}

try {
    $repoRootFull = Get-FullPath -Path $RepoRoot
    if (-not (Test-Path -LiteralPath $repoRootFull -PathType Container)) {
        throw "Repository root was not found: $RepoRoot"
    }

    $configFullPath = Assert-PathUnderRoot `
        -Root $repoRootFull `
        -Path $ConfigPath `
        -Label 'Protected-path config'
    if (-not (Test-Path -LiteralPath $configFullPath -PathType Leaf)) {
        throw "Protected-path config was not found: $ConfigPath"
    }

    $configRaw = [System.IO.File]::ReadAllText(
        $configFullPath,
        [System.Text.Encoding]::UTF8
    )
    $config = $configRaw | ConvertFrom-Json

    foreach ($field in @(
        'schemaVersion',
        'policyId',
        'rules',
        'excludeGlobs',
        'ownerDeltaRequiredFields'
    )) {
        if (-not ($config.PSObject.Properties.Name -contains $field)) {
            throw "Protected-path config is missing $field."
        }
    }
    if ([int]$config.schemaVersion -ne 1) {
        throw 'Protected-path config schemaVersion must be 1.'
    }
    if ([string]::IsNullOrWhiteSpace([string]$config.policyId)) {
        throw 'Protected-path config policyId must be non-empty.'
    }

    $configSha256 = (Get-FileHash `
        -LiteralPath $configFullPath `
        -Algorithm SHA256).Hash.ToUpperInvariant()
    $currentSnapshot = New-ProtectedSnapshot `
        -RepoRootFull $repoRootFull `
        -Config $config `
        -ConfigSha256 $configSha256

    if ($Mode -eq 'Snapshot') {
        Write-ResultAndExit -Result $currentSnapshot -ExitCode 0
    }

    $baseline = Read-JsonDocument `
        -Path $BaselineManifest `
        -Json $BaselineJson `
        -Label 'Baseline manifest' `
        -Required
    Assert-BaselineManifest `
        -Baseline $baseline `
        -Config $config `
        -ConfigSha256 $configSha256

    $baselineMap = Convert-ManifestFilesToMap `
        -Files @($baseline.files) `
        -Label 'Baseline manifest'
    $currentMap = Convert-ManifestFilesToMap `
        -Files @($currentSnapshot.files) `
        -Label 'Current snapshot'
    $delta = @(Get-ProtectedDelta -BaselineMap $baselineMap -CurrentMap $currentMap)

    $ownerDelta = Read-JsonDocument `
        -Path $OwnerDeltaManifest `
        -Json $OwnerDeltaJson `
        -Label 'Owner delta manifest'

    if ($delta.Count -eq 0) {
        Write-ResultAndExit -Result ([pscustomobject]@{
            status = 'PASS'
            exitCode = 0
            policyId = [string]$config.policyId
            baselineId = [string]$baseline.baselineId
            configSha256 = $configSha256
            protectedFileCount = $currentMap.Count
            added = 0
            removed = 0
            modified = 0
            approvedOwnerDelta = $false
            verifiedAtUtc = [System.DateTimeOffset]::UtcNow.ToString('o')
        }) -ExitCode 0
    }

    if ($null -eq $ownerDelta) {
        Write-ResultAndExit -Result ([pscustomobject]@{
            status = 'FAIL'
            exitCode = 2
            reason = 'UNAPPROVED_PROTECTED_PATH_DELTA'
            policyId = [string]$config.policyId
            baselineId = [string]$baseline.baselineId
            configSha256 = $configSha256
            protectedFileCount = $currentMap.Count
            added = @($delta | Where-Object { $_.changeType -eq 'added' }).Count
            removed = @($delta | Where-Object { $_.changeType -eq 'removed' }).Count
            modified = @($delta | Where-Object { $_.changeType -eq 'modified' }).Count
            approvedOwnerDelta = $false
            changes = $delta
            verifiedAtUtc = [System.DateTimeOffset]::UtcNow.ToString('o')
        }) -ExitCode 2
    }

    Assert-OwnerDeltaManifest `
        -OwnerDelta $ownerDelta `
        -Config $config `
        -Baseline $baseline `
        -ActualDelta $delta

    Write-ResultAndExit -Result ([pscustomobject]@{
        status = 'PASS_WITH_APPROVED_OWNER_DELTA'
        exitCode = 0
        policyId = [string]$config.policyId
        baselineId = [string]$baseline.baselineId
        configSha256 = $configSha256
        protectedFileCount = $currentMap.Count
        added = @($delta | Where-Object { $_.changeType -eq 'added' }).Count
        removed = @($delta | Where-Object { $_.changeType -eq 'removed' }).Count
        modified = @($delta | Where-Object { $_.changeType -eq 'modified' }).Count
        approvedOwnerDelta = $true
        approval = [pscustomobject]@{
            owner = [string]$ownerDelta.owner
            approvedBy = [string]$ownerDelta.approvedBy
            reason = [string]$ownerDelta.reason
            approvedAtUtc = [string]$ownerDelta.approvedAtUtc
            expiresAtUtc = [string]$ownerDelta.expiresAtUtc
        }
        changes = $delta
        verifiedAtUtc = [System.DateTimeOffset]::UtcNow.ToString('o')
    }) -ExitCode 0
}
catch {
    Write-ResultAndExit -Result ([pscustomobject]@{
        status = 'ERROR'
        exitCode = 3
        message = $_.Exception.Message
        verifiedAtUtc = [System.DateTimeOffset]::UtcNow.ToString('o')
    }) -ExitCode 3
}
