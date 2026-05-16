[CmdletBinding()]
param(
    [string]$Profile = "default",
    [switch]$Json,
    [string]$OutputPath = ""
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

. "$PSScriptRoot\lib\verify.ps1"
. "$PSScriptRoot\lib\manifest.ps1"

$repoRoot = Split-Path -Parent $PSScriptRoot
$checks = @()
$isWindowsValue = $false
if (Get-Variable -Name IsWindows -ErrorAction SilentlyContinue) {
    $isWindowsValue = $IsWindows
} elseif ($PSVersionTable.PSEdition -eq "Desktop") {
    $isWindowsValue = $true
}
$machine = [ordered]@{
    os = [System.Environment]::OSVersion.Platform.ToString()
    is_windows = $isWindowsValue
    powershell = $PSVersionTable.PSVersion.ToString()
    repo_root = $repoRoot
}

function Add-Check {
    param([object[]]$Items)
    foreach ($item in @($Items)) {
        if ($null -ne $item) { $script:checks += $item }
    }
}

try {
    if ($Profile -notmatch '^[a-z0-9][a-z0-9._-]*$') {
        throw "Profile must be a simple profile id, not a path: $Profile"
    }

    $profilePath = Join-Path $repoRoot "manifests\profiles\$Profile.json"
    $toolsPath = Join-Path $repoRoot "manifests\tools.json"
    $openCodePath = Join-Path $repoRoot "manifests\opencode.json"
    $capabilitiesPath = Join-Path $repoRoot "manifests\capabilities.json"

    $profileData = Read-JsonFile -Path $profilePath
    $toolsData = Read-JsonFile -Path $toolsPath
    $openCodeData = Read-JsonFile -Path $openCodePath
    $capabilitiesData = Read-JsonFile -Path $capabilitiesPath

    Add-Check (New-DoctorCheck -Id "json.profile" -Status "pass" -Message "Profile JSON parsed" -Path "manifests/profiles/$Profile.json")
    Add-Check (New-DoctorCheck -Id "json.tools" -Status "pass" -Message "Tools JSON parsed" -Path "manifests/tools.json")
    Add-Check (New-DoctorCheck -Id "json.opencode" -Status "pass" -Message "OpenCode JSON parsed" -Path "manifests/opencode.json")
    Add-Check (New-DoctorCheck -Id "json.capabilities" -Status "pass" -Message "Capabilities JSON parsed" -Path "manifests/capabilities.json")

    foreach ($schema in @("tools.schema.json", "profile.schema.json", "opencode.schema.json", "capabilities.schema.json")) {
        $schemaPath = Join-Path $repoRoot "manifests\$schema"
        if (Test-Path -LiteralPath $schemaPath) {
            Add-Check (New-DoctorCheck -Id "schema.$schema" -Status "pass" -Message "Schema file exists" -Path "manifests/$schema")
        } else {
            Add-Check (New-DoctorCheck -Id "schema.$schema" -Status "fail" -Message "Schema file is missing" -Path "manifests/$schema")
        }
    }

    Add-Check (Test-ManifestSchemaShape -Data $profileData -Kind "profile" -Path "manifests/profiles/$Profile.json")
    Add-Check (Test-ManifestSchemaShape -Data $toolsData -Kind "tools" -Path "manifests/tools.json")
    Add-Check (Test-ManifestSchemaShape -Data $openCodeData -Kind "opencode" -Path "manifests/opencode.json")
    Add-Check (Test-ManifestSchemaShape -Data $capabilitiesData -Kind "capabilities" -Path "manifests/capabilities.json")

    Add-Check (Test-ManifestReferences -RepoRoot $repoRoot -Profile $profileData -Capabilities $capabilitiesData)
    Add-Check (Test-UniqueIds -Items (Get-OptionalArray -Value $toolsData -Name "tools") -Kind "tools" -Path "manifests/tools.json")
    Add-Check (Test-UniqueIds -Items (Get-OptionalArray -Value $capabilitiesData -Name "capabilities") -Kind "capabilities" -Path "manifests/capabilities.json")
    Add-Check (Test-UniqueIds -Items (Get-OptionalArray -Value $openCodeData -Name "assets") -Kind "opencode-assets" -Path "manifests/opencode.json")
    Add-Check (Test-ToolSafetyInvariants -Tools $toolsData -Path "manifests/tools.json")
    Add-Check (Test-OpenCodeSafetyInvariants -RepoRoot $repoRoot -OpenCode $openCodeData -Path "manifests/opencode.json")
    Add-Check (Test-OpenCodeVerifySteps -RepoRoot $repoRoot -OpenCode $openCodeData -Path "manifests/opencode.json")

    foreach ($toolId in (Get-OptionalArray -Value $profileData -Name "tools")) {
        $tool = @($toolsData.tools | Where-Object { $_.id -eq $toolId })
        if ($tool.Count -eq 0) {
            Add-Check (New-DoctorCheck -Id "profile.tool.$toolId" -Status "fail" -Message "Profile references unknown tool" -Path "manifests/profiles/$Profile.json")
            continue
        }

        $toolSpec = $tool[0]
        $result = Invoke-ManifestCommand -CommandSpec $toolSpec.detect
        $sensitiveOutput = ($toolSpec.automation -eq "manual-required") -or ($toolId -match '(?i)auth|credential|secret|token')
        $safeResult = ConvertTo-SafeCommandResult -Result $result -SensitiveOutput $sensitiveOutput
        $combined = "$($result.stdout)`n$($result.stderr)"
        $expected = 0
        if ($toolSpec.detect.PSObject.Properties.Name -contains "expected_exit_code") {
            $expected = [int]$toolSpec.detect.expected_exit_code
        }
        $regexOk = $true
        if ($toolSpec.detect.PSObject.Properties.Name -contains "success_regex") {
            $regexOk = Test-SuccessRegex -Pattern $toolSpec.detect.success_regex -Text $combined
        }

        if (-not $result.available) {
            $status = "blocked"
            if (($toolSpec.automation -eq "auto-safe") -and (-not $toolSpec.required)) { $status = "warn" }
            Add-Check (New-DoctorCheck -Id "tool.$toolId.detect" -Status $status -Message "Tool command not available: $($result.executable)" -Path "manifests/tools.json" -Automation $toolSpec.automation -Data $safeResult)
        } elseif (($result.exit_code -eq $expected) -and $regexOk) {
            Add-Check (New-DoctorCheck -Id "tool.$toolId.detect" -Status "pass" -Message "Tool detection passed" -Path "manifests/tools.json" -Automation $toolSpec.automation -Data $safeResult)
        } elseif ($toolSpec.automation -eq "manual-required") {
            Add-Check (New-DoctorCheck -Id "tool.$toolId.detect" -Status "manual" -Message "Manual-required tool check is pending or not configured" -Path "manifests/tools.json" -Automation $toolSpec.automation -Data $safeResult)
        } else {
            Add-Check (New-DoctorCheck -Id "tool.$toolId.detect" -Status "warn" -Message "Tool detection did not meet expected output" -Path "manifests/tools.json" -Automation $toolSpec.automation -Data $safeResult)
        }
    }

    foreach ($capId in (Get-OptionalArray -Value $profileData -Name "capabilities")) {
        $capability = @($capabilitiesData.capabilities | Where-Object { $_.id -eq $capId })
        if ($capability.Count -eq 0) {
            Add-Check (New-DoctorCheck -Id "profile.capability.$capId" -Status "fail" -Message "Profile references unknown capability" -Path "manifests/profiles/$Profile.json")
        } else {
            Add-Check (New-DoctorCheck -Id "profile.capability.$capId" -Status "pass" -Message "Profile capability is declared" -Path "manifests/capabilities.json" -Automation $capability[0].automation)
        }
    }
} catch {
    Add-Check (New-DoctorCheck -Id "doctor.exception" -Status "fail" -Message $_.Exception.Message)
}

$summary = [ordered]@{
    pass = @($checks | Where-Object { $_.status -eq "pass" }).Count
    warn = @($checks | Where-Object { $_.status -eq "warn" }).Count
    blocked = @($checks | Where-Object { $_.status -eq "blocked" }).Count
    manual = @($checks | Where-Object { $_.status -eq "manual" }).Count
    fail = @($checks | Where-Object { $_.status -eq "fail" }).Count
}

$report = [ordered]@{
    profile = $Profile
    machine = $machine
    summary = $summary
    checks = $checks
}

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $resolvedOutput = if ([System.IO.Path]::IsPathRooted($OutputPath)) { [System.IO.Path]::GetFullPath($OutputPath) } else { Resolve-RepoPath -RepoRoot $repoRoot -RelativePath $OutputPath }
    $root = [System.IO.Path]::GetFullPath($repoRoot).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    if (-not ($resolvedOutput -eq $root -or $resolvedOutput.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase) -or $resolvedOutput.StartsWith($root + [System.IO.Path]::AltDirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase))) {
        throw "OutputPath must stay inside the repository: $OutputPath"
    }
    $parent = Split-Path -Parent $resolvedOutput
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent | Out-Null
    }
    $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedOutput -Encoding UTF8
}

if ($Json) {
    $report | ConvertTo-Json -Depth 12
} else {
    "Doctor profile: $Profile"
    "Pass: $($summary.pass)  Warn: $($summary.warn)  Blocked: $($summary.blocked)  Manual: $($summary.manual)  Fail: $($summary.fail)"
    foreach ($check in $checks) {
        "[$($check.status)] $($check.id) - $($check.message)"
    }
}

if (($summary.fail -gt 0) -or ($summary.blocked -gt 0)) {
    exit 1
}
