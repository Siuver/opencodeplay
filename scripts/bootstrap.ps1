[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('Auto', 'Online', 'Offline')]
    [string]$Mode = 'Auto',

    [Alias('ManifestPath')]
    [string]$ArtifactCatalogPath = '',

    [string]$ArtifactsRoot = '',

    [string]$InstallRoot = '',

    [switch]$AddToUserPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

if ([string]::IsNullOrWhiteSpace($ArtifactCatalogPath)) {
    $ArtifactCatalogPath = Join-Path $RepoRoot 'manifests\pinned-artifacts.json'
}

if ([string]::IsNullOrWhiteSpace($ArtifactsRoot)) {
    $ArtifactsRoot = Join-Path $RepoRoot 'artifacts'
}

function Resolve-RepoPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
    return $fullPath
}

function Test-PlaceholderValue {
    param([AllowNull()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $true
    }

    return $Value -match 'PIN_|REPLACE_|CHECK_'
}

function Assert-Checksum {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$ExpectedSha256
    )

    if (Test-PlaceholderValue $ExpectedSha256) {
        if ($WhatIfPreference) {
            Write-Warning "Dry run only: $(Split-Path -Leaf $Path) has a placeholder SHA-256."
            return
        }

        throw "Refusing to use '$Path': artifact catalog contains a placeholder SHA-256."
    }

    if ($ExpectedSha256 -notmatch '^[a-fA-F0-9]{64}$') {
        throw "Invalid SHA-256 value for '$Path'. Expected 64 hexadecimal characters."
    }

    if ($WhatIfPreference) {
        Write-Host "Dry run only: skipping checksum verification for $(Split-Path -Leaf $Path)."
        return
    }

    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    $expected = $ExpectedSha256.ToLowerInvariant()

    if ($actual -ne $expected) {
        throw "Checksum mismatch for '$Path'. Expected $expected but found $actual."
    }
}

function Save-OnlineArtifact {
    param(
        [Parameter(Mandatory = $true)][object]$Tool,
        [Parameter(Mandatory = $true)][string]$ArtifactPath
    )

    if (Test-PlaceholderValue $Tool.source.url) {
        throw "Cannot download '$($Tool.name)': source.url is missing or still a placeholder."
    }

    if (Test-PlaceholderValue $Tool.artifact.sha256) {
        throw "Cannot download '$($Tool.name)': artifact.sha256 is missing or still a placeholder."
    }

    $artifactDirectory = Split-Path -Parent $ArtifactPath
    if ($PSCmdlet.ShouldProcess($ArtifactPath, "Download $($Tool.source.url)")) {
        New-Item -ItemType Directory -Force -Path $artifactDirectory | Out-Null
        Invoke-WebRequest -Uri $Tool.source.url -OutFile $ArtifactPath -UseBasicParsing
    }

    if (Test-Path -LiteralPath $ArtifactPath) {
        Assert-Checksum -Path $ArtifactPath -ExpectedSha256 $Tool.artifact.sha256
    }
}

function Resolve-ContainedPath {
    param(
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)][string]$ChildPath
    )

    if ([System.IO.Path]::IsPathRooted($ChildPath)) {
        throw "Install target '$ChildPath' must be relative to the install root."
    }

    $rootFullPath = [System.IO.Path]::GetFullPath($RootPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $targetFullPath = [System.IO.Path]::GetFullPath((Join-Path $rootFullPath $ChildPath))
    $rootPrefix = $rootFullPath + [System.IO.Path]::DirectorySeparatorChar

    if (-not ($targetFullPath.Equals($rootFullPath, [System.StringComparison]::OrdinalIgnoreCase) -or $targetFullPath.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase))) {
        throw "Install target '$ChildPath' resolves outside the install root."
    }

    return $targetFullPath
}

function Test-ArchiveEntries {
    param(
        [Parameter(Mandatory = $true)][string]$ArtifactPath
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($ArtifactPath)
    try {
        foreach ($entry in $archive.Entries) {
            if ([string]::IsNullOrWhiteSpace($entry.FullName)) {
                continue
            }

            if ([System.IO.Path]::IsPathRooted($entry.FullName) -or $entry.FullName -match '(^|[\\/])\.\.([\\/]|$)') {
                throw "Archive '$ArtifactPath' contains an unsafe path: $($entry.FullName)"
            }
        }
    }
    finally {
        $archive.Dispose()
    }
}

function Assert-ManifestTool {
    param([Parameter(Mandatory = $true)][object]$Tool)

    foreach ($property in @('name', 'enabled', 'stageOnly', 'version', 'source', 'artifact', 'install', 'validate')) {
        if (-not ($Tool.PSObject.Properties.Name -contains $property)) {
            throw "Manifest tool entry is missing required property '$property'."
        }
    }

    if (-not ($Tool.artifact.PSObject.Properties.Name -contains 'fileName')) {
        throw "Manifest tool '$($Tool.name)' is missing artifact.fileName."
    }

    if (-not ($Tool.artifact.PSObject.Properties.Name -contains 'sha256')) {
        throw "Manifest tool '$($Tool.name)' is missing artifact.sha256."
    }

    if (-not ($Tool.install.PSObject.Properties.Name -contains 'type')) {
        throw "Manifest tool '$($Tool.name)' is missing install.type."
    }
}

function Get-BooleanProperty {
    param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if (-not ($Object.PSObject.Properties.Name -contains $Name)) {
        return $false
    }

    return [bool]$Object.$Name
}

function ConvertTo-PowerShellSingleQuotedString {
    param([Parameter(Mandatory = $true)][string]$Value)

    return "'$($Value.Replace("'", "''"))'"
}

function Expand-ToolArtifact {
    param(
        [Parameter(Mandatory = $true)][string]$ArtifactPath,
        [Parameter(Mandatory = $true)][string]$TargetPath,
        [Parameter(Mandatory = $true)][string]$InstallType
    )

    if ($InstallType -eq 'archive') {
        if ($PSCmdlet.ShouldProcess($TargetPath, "Extract $ArtifactPath")) {
            Test-ArchiveEntries -ArtifactPath $ArtifactPath
            New-Item -ItemType Directory -Force -Path $TargetPath | Out-Null
            Expand-Archive -LiteralPath $ArtifactPath -DestinationPath $TargetPath -Force
        }
        return
    }

    if ($InstallType -eq 'copy') {
        if ($PSCmdlet.ShouldProcess($TargetPath, "Copy $ArtifactPath")) {
            New-Item -ItemType Directory -Force -Path $TargetPath | Out-Null
            Copy-Item -LiteralPath $ArtifactPath -Destination $TargetPath -Force
        }
        return
    }

    throw "Unsupported install.type '$InstallType'. Supported values: archive, copy."
}

function Save-State {
    param(
        [Parameter(Mandatory = $true)][string]$StatePath,
        [Parameter(Mandatory = $true)][object[]]$InstalledTools
    )

    $state = [ordered]@{
        generatedAt = (Get-Date).ToUniversalTime().ToString('o')
        mode = $Mode
        installedTools = $InstalledTools
    }

    if ($PSCmdlet.ShouldProcess($StatePath, 'Write bootstrap state')) {
        $stateDir = Split-Path -Parent $StatePath
        New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
        $state | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $StatePath -Encoding UTF8
    }
}

function Save-OfflineEnvScript {
    param([Parameter(Mandatory = $true)][string]$EnvPath)

    $content = @(
        '# Generated by opencodeplay bootstrap. Do not edit by hand.',
        '$env:OPENCODE_DISABLE_AUTOUPDATE = ''1''',
        '$env:OPENCODE_DISABLE_MODELS_FETCH = ''1''',
        '$env:OPENCODE_DISABLE_LSP_DOWNLOAD = ''1'''
    )

    if ($PSCmdlet.ShouldProcess($EnvPath, 'Write offline environment defaults')) {
        $envDir = Split-Path -Parent $EnvPath
        New-Item -ItemType Directory -Force -Path $envDir | Out-Null
        $content | Set-Content -LiteralPath $EnvPath -Encoding ASCII
    }
}

function Save-ActivationScript {
    param(
        [Parameter(Mandatory = $true)][string]$ActivationPath,
        [Parameter(Mandatory = $true)][string]$ToolPath
    )

    $toolPathLiteral = ConvertTo-PowerShellSingleQuotedString -Value $ToolPath
    $content = @(
        '# Generated by opencodeplay bootstrap. Dot-source this file in PowerShell:',
        '# . .\.opencodeplay\activate-opencodeplay.ps1',
        '$envScript = Join-Path $PSScriptRoot ''env.ps1''',
        'if (Test-Path -LiteralPath $envScript) {',
        '    . $envScript',
        '}',
        "`$toolPath = $toolPathLiteral",
        'if (Test-Path -LiteralPath $toolPath) {',
        '    $pathEntries = @($env:Path -split '';'' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })',
        '    if (-not ($pathEntries | Where-Object { $_.TrimEnd(''\'', ''/'') -ieq $toolPath.TrimEnd(''\'', ''/'') })) {',
        '        $env:Path = $toolPath + '';'' + $env:Path',
        '    }',
        '}',
        'Write-Host "opencodeplay environment activated for this PowerShell session."'
    )

    if ($PSCmdlet.ShouldProcess($ActivationPath, 'Write activation script')) {
        $activationDir = Split-Path -Parent $ActivationPath
        New-Item -ItemType Directory -Force -Path $activationDir | Out-Null
        $content | Set-Content -LiteralPath $ActivationPath -Encoding ASCII
    }
}

function Add-UserPathEntry {
    param([Parameter(Mandatory = $true)][string]$PathEntry)

    if ((-not $WhatIfPreference) -and (-not (Test-Path -LiteralPath $PathEntry))) {
        throw "Cannot add missing path to user PATH: $PathEntry"
    }

    $currentPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $entries = @($currentPath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $normalizedEntry = $PathEntry.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $alreadyPresent = $false

    foreach ($entry in $entries) {
        $normalizedExisting = $entry.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
        if ($normalizedExisting.Equals($normalizedEntry, [System.StringComparison]::OrdinalIgnoreCase)) {
            $alreadyPresent = $true
            break
        }
    }

    if ($alreadyPresent) {
        Write-Host "User PATH already contains $PathEntry"
        return
    }

    $updatedPath = if ([string]::IsNullOrWhiteSpace($currentPath)) { $PathEntry } else { "$PathEntry;$currentPath" }
    if ($PSCmdlet.ShouldProcess('User PATH', "Prepend $PathEntry")) {
        [Environment]::SetEnvironmentVariable('Path', $updatedPath, 'User')
        Write-Host "Added $PathEntry to the user PATH. Open a new terminal for persistent PATH changes to apply."
    }
}

$artifactCatalogFullPath = [System.IO.Path]::GetFullPath($ArtifactCatalogPath)
$artifactsFullPath = [System.IO.Path]::GetFullPath($ArtifactsRoot)

if (-not (Test-Path -LiteralPath $artifactCatalogFullPath)) {
    throw "Artifact catalog not found: $artifactCatalogFullPath"
}

$artifactCatalog = Get-Content -LiteralPath $artifactCatalogFullPath -Raw | ConvertFrom-Json

if ([string]::IsNullOrWhiteSpace($InstallRoot)) {
    $InstallRoot = Resolve-RepoPath $artifactCatalog.installRoot
}
else {
    $InstallRoot = [System.IO.Path]::GetFullPath($InstallRoot)
}

$installedTools = @()
$missingArtifacts = @()
$opencodeToolPath = ''

foreach ($tool in $artifactCatalog.artifacts) {
    Assert-ManifestTool -Tool $tool

    if (-not $tool.enabled) {
        Write-Host "Skipping disabled tool: $($tool.name)"
        continue
    }

    $artifactName = $tool.artifact.fileName
    $artifactPath = Join-Path $artifactsFullPath $artifactName
    $hasArtifact = Test-Path -LiteralPath $artifactPath

    if (-not $hasArtifact) {
        if ($Mode -eq 'Offline') {
            $missingArtifacts += [ordered]@{
                name = $tool.name
                version = $tool.version
                fileName = $artifactName
                expectedPath = $artifactPath
            }
            continue
        }

        if ($Mode -in @('Auto', 'Online')) {
            Save-OnlineArtifact -Tool $tool -ArtifactPath $artifactPath
            $hasArtifact = Test-Path -LiteralPath $artifactPath
        }
    }

    if (-not $hasArtifact) {
        $missingArtifacts += [ordered]@{
            name = $tool.name
            version = $tool.version
            fileName = $artifactName
            expectedPath = $artifactPath
        }
        continue
    }

    Assert-Checksum -Path $artifactPath -ExpectedSha256 $tool.artifact.sha256

    $targetSubdir = $tool.install.targetSubdir
    if ([string]::IsNullOrWhiteSpace($targetSubdir)) {
        $targetSubdir = $tool.name
    }

    $targetPath = Resolve-ContainedPath -RootPath $InstallRoot -ChildPath $targetSubdir
    Expand-ToolArtifact -ArtifactPath $artifactPath -TargetPath $targetPath -InstallType $tool.install.type

    $installedTools += [ordered]@{
        name = $tool.name
        version = $tool.version
        targetPath = $targetPath
        artifact = $artifactName
        stageOnly = Get-BooleanProperty -Object $tool -Name 'stageOnly'
    }

    if ($tool.name -eq 'opencode') {
        $opencodeToolPath = $targetPath
    }

    Write-Host "Prepared $($tool.name) at $targetPath"
}

if ($missingArtifacts.Count -gt 0) {
    $missingText = $missingArtifacts | ConvertTo-Json -Depth 5
    throw "Missing required artifacts:`n$missingText"
}

$statePath = Resolve-RepoPath '.opencodeplay/state.json'
$envPath = Resolve-RepoPath '.opencodeplay/env.ps1'
$activationPath = Resolve-RepoPath '.opencodeplay/activate-opencodeplay.ps1'
Save-State -StatePath $statePath -InstalledTools $installedTools
Save-OfflineEnvScript -EnvPath $envPath

if (-not [string]::IsNullOrWhiteSpace($opencodeToolPath)) {
    Save-ActivationScript -ActivationPath $activationPath -ToolPath $opencodeToolPath
    if ($AddToUserPath) {
        Add-UserPathEntry -PathEntry $opencodeToolPath
    }
}

Write-Host "Bootstrap complete. State written to $statePath"
Write-Host "Offline environment defaults written to $envPath"
if (-not [string]::IsNullOrWhiteSpace($opencodeToolPath)) {
    Write-Host "PowerShell activation script written to $activationPath"
}
