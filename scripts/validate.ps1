[CmdletBinding()]
param(
    [Alias('ManifestPath')]
    [string]$ArtifactCatalogPath = '',

    [string]$StatePath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

if ([string]::IsNullOrWhiteSpace($ArtifactCatalogPath)) {
    $ArtifactCatalogPath = Join-Path $RepoRoot 'manifests\pinned-artifacts.json'
}

if ([string]::IsNullOrWhiteSpace($StatePath)) {
    $StatePath = Join-Path $RepoRoot '.opencodeplay\state.json'
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

function Get-ValidationArguments {
    param([Parameter(Mandatory = $true)][object]$Validation)

    if (-not ($Validation.PSObject.Properties.Name -contains 'args')) {
        return @()
    }

    return @($Validation.args)
}

function Test-FileContainsLine {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Pattern
    )

    $content = Get-Content -LiteralPath $Path -Raw
    return $content -match $Pattern
}

$artifactCatalogFullPath = [System.IO.Path]::GetFullPath($ArtifactCatalogPath)
if (-not (Test-Path -LiteralPath $artifactCatalogFullPath)) {
    throw "Artifact catalog not found: $artifactCatalogFullPath"
}

$artifactCatalog = Get-Content -LiteralPath $artifactCatalogFullPath -Raw | ConvertFrom-Json
$stateFullPath = [System.IO.Path]::GetFullPath($StatePath)
$generatedRoot = Split-Path -Parent $stateFullPath
$envScriptPath = Join-Path $generatedRoot 'env.ps1'
$activationScriptPath = Join-Path $generatedRoot 'activate-opencodeplay.ps1'
$state = $null
if (Test-Path -LiteralPath $stateFullPath) {
    $state = Get-Content -LiteralPath $stateFullPath -Raw | ConvertFrom-Json
}

$failures = @()

if ($null -ne $state) {
    if (-not (Test-Path -LiteralPath $envScriptPath)) {
        $failures += "Generated offline environment script is missing: $envScriptPath"
    }
    else {
        foreach ($expectedPattern in @(
            '\$env:OPENCODE_DISABLE_AUTOUPDATE\s*=\s*''1''',
            '\$env:OPENCODE_DISABLE_MODELS_FETCH\s*=\s*''1''',
            '\$env:OPENCODE_DISABLE_LSP_DOWNLOAD\s*=\s*''1'''
        )) {
            if (-not (Test-FileContainsLine -Path $envScriptPath -Pattern $expectedPattern)) {
                $failures += "Generated offline environment script is missing expected setting pattern: $expectedPattern"
            }
        }
    }

    if (-not (Test-Path -LiteralPath $activationScriptPath)) {
        $failures += "Generated activation script is missing: $activationScriptPath"
    }
    else {
        foreach ($expectedPattern in @(
            'Join-Path\s+\$PSScriptRoot\s+''env\.ps1''',
            '\.\s+\$envScript',
            '\$env:Path\s*=\s*\$toolPath\s*\+\s*'';''\s*\+\s*\$env:Path'
        )) {
            if (-not (Test-FileContainsLine -Path $activationScriptPath -Pattern $expectedPattern)) {
                $failures += "Generated activation script is missing expected behavior pattern: $expectedPattern"
            }
        }
    }
}

foreach ($tool in $artifactCatalog.artifacts) {
    if (-not $tool.enabled) {
        continue
    }

    if (Get-BooleanProperty -Object $tool -Name 'stageOnly') {
        if ($null -eq $state) {
            $failures += "Stage-only tool '$($tool.name)' has no bootstrap state file at $stateFullPath. Run bootstrap successfully first."
            continue
        }

        $stateTool = @($state.installedTools | Where-Object { $_.name -eq $tool.name }) | Select-Object -First 1
        if ($null -eq $stateTool) {
            $failures += "Stage-only tool '$($tool.name)' was not found in bootstrap state."
            continue
        }

        if (-not (Test-Path -LiteralPath $stateTool.targetPath)) {
            $failures += "Stage-only tool '$($tool.name)' target path is missing: $($stateTool.targetPath)"
            continue
        }

        Write-Host "Stage-only tool present: $($tool.name) at $($stateTool.targetPath). Validation note: $($tool.validate.notes)"
        continue
    }

    if (-not ($tool.validate.PSObject.Properties.Name -contains 'executable')) {
        $failures += "No validation executable declared for $($tool.name)."
        continue
    }

    $executable = $tool.validate.executable
    if ([string]::IsNullOrWhiteSpace($executable)) {
        $failures += "No validation executable declared for $($tool.name)."
        continue
    }

    $arguments = Get-ValidationArguments -Validation $tool.validate
    Write-Host "Validate $($tool.name): $executable $($arguments -join ' ')"
    $process = Start-Process -FilePath $executable -ArgumentList $arguments -Wait -PassThru -NoNewWindow
    if ($process.ExitCode -ne 0) {
        $failures += "Validation failed for $($tool.name) with exit code $($process.ExitCode)."
    }
}

if ($failures.Count -gt 0) {
    throw ($failures -join [Environment]::NewLine)
}

Write-Host 'Validation complete.'
