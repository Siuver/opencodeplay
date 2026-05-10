[CmdletBinding()]
param(
    [string]$ManifestPath = '',

    [string]$StatePath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $ManifestPath = Join-Path $RepoRoot 'manifests\tools.json'
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

$manifestFullPath = [System.IO.Path]::GetFullPath($ManifestPath)
if (-not (Test-Path -LiteralPath $manifestFullPath)) {
    throw "Manifest not found: $manifestFullPath"
}

$manifest = Get-Content -LiteralPath $manifestFullPath -Raw | ConvertFrom-Json
$stateFullPath = [System.IO.Path]::GetFullPath($StatePath)
$state = $null
if (Test-Path -LiteralPath $stateFullPath) {
    $state = Get-Content -LiteralPath $stateFullPath -Raw | ConvertFrom-Json
}

$failures = @()

foreach ($tool in $manifest.tools) {
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
