Set-StrictMode -Version 2.0

function Get-RepoRoot {
    $scriptDir = Split-Path -Parent $PSScriptRoot
    return Split-Path -Parent $scriptDir
}

function Resolve-RepoPath {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )

    return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $RelativePath))
}

function Test-RepoRelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$Value,
        [Parameter(Mandatory = $true)][string]$CheckId,
        [Parameter(Mandatory = $true)][string]$ManifestPath,
        [string]$Automation = ""
    )

    $root = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return New-DoctorCheck -Id $CheckId -Status "fail" -Message "Path must not be empty" -Path $ManifestPath -Automation $Automation -Data @{ value = $Value }
    }
    if ([System.IO.Path]::IsPathRooted($Value)) {
        return New-DoctorCheck -Id $CheckId -Status "fail" -Message "Path must be repo-relative, not rooted" -Path $ManifestPath -Automation $Automation -Data @{ value = $Value }
    }

    $resolved = Resolve-RepoPath -RepoRoot $root -RelativePath $Value
    if (-not ($resolved -eq $root -or $resolved.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase) -or $resolved.StartsWith($root + [System.IO.Path]::AltDirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase))) {
        return New-DoctorCheck -Id $CheckId -Status "fail" -Message "Path escapes repository root" -Path $ManifestPath -Automation $Automation -Data @{ value = $Value; resolved = $resolved }
    }

    return New-DoctorCheck -Id $CheckId -Status "pass" -Message "Path is repo-relative and contained" -Path $ManifestPath -Automation $Automation -Data @{ value = $Value; resolved = $resolved }
}

function Get-ObjectPropertyNames {
    param([object]$Value)
    if ($null -eq $Value -or -not ($Value.PSObject.Properties.Name)) { return @() }
    return @($Value.PSObject.Properties.Name)
}

function Test-ObjectHasProperty {
    param(
        [object]$Value,
        [Parameter(Mandatory = $true)][string]$Name
    )

    return (Get-ObjectPropertyNames -Value $Value) -contains $Name
}

function Get-OptionalArray {
    param(
        [object]$Value,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if (Test-ObjectHasProperty -Value $Value -Name $Name) {
        return @($Value.$Name)
    }
    return @()
}

function Get-ManifestItemId {
    param(
        [object]$Value,
        [Parameter(Mandatory = $true)][string]$Fallback
    )

    if ((Test-ObjectHasProperty -Value $Value -Name "id") -and -not [string]::IsNullOrWhiteSpace([string]$Value.id)) {
        return [string]$Value.id
    }
    return $Fallback
}

function Test-OpenCodeVerifyStepShape {
    param(
        [Parameter(Mandatory = $true)][object]$Step,
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $checks = @(Test-ManifestObjectShape -Value $Step -Required @("kind") -Allowed @("kind", "value", "argv", "success_regex") -Id "$Id.shape" -Path $Path)
    $names = Get-ObjectPropertyNames -Value $Step
    if (($names -contains "value") -eq ($names -contains "argv")) {
        $checks += New-DoctorCheck -Id "$Id.value-or-argv" -Status "fail" -Message "Verify step must contain exactly one of value or argv" -Path $Path
    }
    if (($names -contains "kind") -and (@("directory-exists", "file-exists", "command") -notcontains $Step.kind)) {
        $checks += New-DoctorCheck -Id "$Id.kind" -Status "fail" -Message "Unsupported OpenCode verify step kind" -Path $Path
    }
    if ($names -contains "argv") {
        foreach ($arg in @($Step.argv)) {
            if ($arg -isnot [string]) {
                $checks += New-DoctorCheck -Id "$Id.argv.type" -Status "fail" -Message "Verify argv values must be strings" -Path $Path
            }
        }
    }
    return $checks
}

function Test-ManifestObjectShape {
    param(
        [Parameter(Mandatory = $true)][object]$Value,
        [Parameter(Mandatory = $true)][string[]]$Required,
        [Parameter(Mandatory = $true)][string[]]$Allowed,
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $checks = @()
    $names = Get-ObjectPropertyNames -Value $Value
    foreach ($name in $Required) {
        if ($names -notcontains $name) {
            $checks += New-DoctorCheck -Id "$Id.required.$name" -Status "fail" -Message "Required property is missing: $name" -Path $Path
        }
    }
    foreach ($name in $names) {
        if ($Allowed -notcontains $name) {
            $checks += New-DoctorCheck -Id "$Id.additional.$name" -Status "fail" -Message "Unexpected property is present: $name" -Path $Path
        }
    }
    if ($checks.Count -eq 0) {
        $checks += New-DoctorCheck -Id $Id -Status "pass" -Message "Manifest object shape is valid" -Path $Path
    }
    return $checks
}

function Test-ManifestCommandShape {
    param(
        [Parameter(Mandatory = $true)][object]$Command,
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $checks = @(Test-ManifestObjectShape -Value $Command -Required @("argv") -Allowed @("argv", "expected_exit_code", "success_regex") -Id "$Id.shape" -Path $Path)
    if (Get-ObjectPropertyNames -Value $Command -contains "argv") {
        $argv = @($Command.argv)
        if ($argv.Count -lt 1) {
            $checks += New-DoctorCheck -Id "$Id.argv" -Status "fail" -Message "Command argv must contain at least one item" -Path $Path
        }
        foreach ($arg in $argv) {
            if ($arg -isnot [string]) {
                $checks += New-DoctorCheck -Id "$Id.argv.type" -Status "fail" -Message "Command argv values must be strings" -Path $Path
            }
        }
    }
    return $checks
}

function Test-ManifestSchemaShape {
    param(
        [Parameter(Mandatory = $true)][object]$Data,
        [Parameter(Mandatory = $true)][string]$Kind,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $checks = @()
    $automationValues = @("auto-safe", "auto-with-approval", "manual-required", "unsupported")
    $platformValues = @("windows", "wsl", "linux", "macos", "any")

    if ($Kind -eq "profile") {
        $checks += Test-ManifestObjectShape -Value $Data -Required @("schema_version", "id", "description", "tools", "capabilities") -Allowed @("schema_version", "id", "description", "platforms", "network", "tools", "capabilities", "manifest_refs", "manual_steps", "approval_required", "success_criteria") -Id "schema.profile.shape" -Path $Path
        foreach ($platform in (Get-OptionalArray -Value $Data -Name "platforms")) { if ($platformValues -notcontains $platform) { $checks += New-DoctorCheck -Id "schema.profile.platform.$platform" -Status "fail" -Message "Unsupported profile platform" -Path $Path } }
        if ((Get-ObjectPropertyNames -Value $Data -contains "network") -and (@("required", "optional", "forbidden") -notcontains $Data.network)) { $checks += New-DoctorCheck -Id "schema.profile.network" -Status "fail" -Message "Unsupported profile network policy" -Path $Path }
    } elseif ($Kind -eq "capabilities") {
        $checks += Test-ManifestObjectShape -Value $Data -Required @("schema_version", "capabilities") -Allowed @("schema_version", "capabilities") -Id "schema.capabilities.shape" -Path $Path
        $capIndex = 0
        foreach ($capability in (Get-OptionalArray -Value $Data -Name "capabilities")) {
            $capabilityId = Get-ManifestItemId -Value $capability -Fallback "index-$capIndex"
            $checks += Test-ManifestObjectShape -Value $capability -Required @("id", "description", "enabled", "automation", "manifests", "requires") -Allowed @("id", "description", "enabled", "automation", "manifests", "requires", "manual_steps") -Id "schema.capability.$capabilityId.shape" -Path $Path
            if ((Test-ObjectHasProperty -Value $capability -Name "automation") -and ($automationValues -notcontains $capability.automation)) { $checks += New-DoctorCheck -Id "schema.capability.$capabilityId.automation" -Status "fail" -Message "Unsupported capability automation class" -Path $Path }
            $capIndex++
        }
    } elseif ($Kind -eq "tools") {
        $checks += Test-ManifestObjectShape -Value $Data -Required @("schema_version", "tools") -Allowed @("schema_version", "defaults", "tools") -Id "schema.tools.shape" -Path $Path
        $toolIndex = 0
        foreach ($tool in (Get-OptionalArray -Value $Data -Name "tools")) {
            $toolNames = Get-ObjectPropertyNames -Value $tool
            $toolId = Get-ManifestItemId -Value $tool -Fallback "index-$toolIndex"
            $checks += Test-ManifestObjectShape -Value $tool -Required @("id", "enabled", "required", "automation", "detect", "verify") -Allowed @("id", "display_name", "enabled", "required", "automation", "install_if_missing", "update_if_present", "version_policy", "detect", "install_methods", "update_methods", "verify", "artifacts", "manual_instructions", "notes") -Id "schema.tool.$toolId.shape" -Path $Path
            if (($toolNames -contains "automation") -and ($automationValues -notcontains $tool.automation)) { $checks += New-DoctorCheck -Id "schema.tool.$toolId.automation" -Status "fail" -Message "Unsupported tool automation class" -Path $Path }
            if ($toolNames -contains "detect") { $checks += Test-ManifestCommandShape -Command $tool.detect -Id "schema.tool.$toolId.detect" -Path $Path }
            if ($toolNames -contains "verify") { $checks += Test-ManifestCommandShape -Command $tool.verify -Id "schema.tool.$toolId.verify" -Path $Path }
            foreach ($group in @("install_methods", "update_methods")) {
                if ($toolNames -notcontains $group) { continue }
                foreach ($method in @($tool.$group)) {
                    if ($null -eq $method) { continue }
                    $methodId = Get-ManifestItemId -Value $method -Fallback "$group-item"
                    $methodNames = Get-ObjectPropertyNames -Value $method
                    $checks += Test-ManifestObjectShape -Value $method -Required @("id", "platform", "automation", "command") -Allowed @("id", "platform", "automation", "requires_network", "requires_admin", "command", "notes") -Id "schema.tool.$toolId.$methodId.shape" -Path $Path
                    if (($methodNames -contains "platform") -and ($platformValues -notcontains $method.platform)) { $checks += New-DoctorCheck -Id "schema.tool.$toolId.$methodId.platform" -Status "fail" -Message "Unsupported method platform" -Path $Path }
                    if (($methodNames -contains "automation") -and ($automationValues -notcontains $method.automation)) { $checks += New-DoctorCheck -Id "schema.tool.$toolId.$methodId.automation" -Status "fail" -Message "Unsupported method automation class" -Path $Path }
                    if ($methodNames -contains "command") { $checks += Test-ManifestCommandShape -Command $method.command -Id "schema.tool.$toolId.$methodId.command" -Path $Path }
                }
            }
            $toolIndex++
        }
    } elseif ($Kind -eq "opencode") {
        $checks += Test-ManifestObjectShape -Value $Data -Required @("schema_version", "config", "assets") -Allowed @("schema_version", "config", "assets", "auth", "mcp", "notes") -Id "schema.opencode.shape" -Path $Path
        if (Test-ObjectHasProperty -Value $Data -Name "config") {
            $checks += Test-ManifestObjectShape -Value $Data.config -Required @("target", "automation") -Allowed @("target", "path", "automation", "template", "merge_strategy") -Id "schema.opencode.config.shape" -Path $Path
            if (@("project", "global", "custom") -notcontains $Data.config.target) { $checks += New-DoctorCheck -Id "schema.opencode.config.target" -Status "fail" -Message "Unsupported OpenCode config target" -Path $Path }
            if ($automationValues -notcontains $Data.config.automation) { $checks += New-DoctorCheck -Id "schema.opencode.config.automation" -Status "fail" -Message "Unsupported OpenCode config automation class" -Path $Path }
        }
        $assetIndex = 0
        foreach ($asset in @(Get-OptionalArray -Value $Data -Name "assets") + @(Get-OptionalArray -Value $Data -Name "mcp")) {
            if ($null -eq $asset) { continue }
            $assetNames = Get-ObjectPropertyNames -Value $asset
            $assetId = Get-ManifestItemId -Value $asset -Fallback "index-$assetIndex"
            $checks += Test-ManifestObjectShape -Value $asset -Required @("id", "type", "source", "target", "automation", "verify") -Allowed @("id", "type", "enabled", "source", "target", "automation", "merge_strategy", "requires_network", "verify", "notes") -Id "schema.opencode.asset.$assetId.shape" -Path $Path
            if (($assetNames -contains "type") -and (@("agent", "skill", "plugin", "command", "tool", "theme", "config", "mcp") -notcontains $asset.type)) { $checks += New-DoctorCheck -Id "schema.opencode.asset.$assetId.type" -Status "fail" -Message "Unsupported OpenCode asset type" -Path $Path }
            if (($assetNames -contains "automation") -and ($automationValues -notcontains $asset.automation)) { $checks += New-DoctorCheck -Id "schema.opencode.asset.$assetId.automation" -Status "fail" -Message "Unsupported OpenCode asset automation class" -Path $Path }
            foreach ($step in (Get-OptionalArray -Value $asset -Name "verify")) {
                $checks += Test-OpenCodeVerifyStepShape -Step $step -Id "schema.opencode.asset.$assetId.verify" -Path $Path
            }
            $assetIndex++
        }
        $authIndex = 0
        foreach ($auth in (Get-OptionalArray -Value $Data -Name "auth")) {
            if ($null -eq $auth) { continue }
            $authId = Get-ManifestItemId -Value $auth -Fallback "index-$authIndex"
            $checks += Test-ManifestObjectShape -Value $auth -Required @("id", "automation", "instructions", "verify") -Allowed @("id", "automation", "instructions", "verify") -Id "schema.opencode.auth.$authId.shape" -Path $Path
            if ((Test-ObjectHasProperty -Value $auth -Name "automation") -and ($auth.automation -ne "manual-required")) { $checks += New-DoctorCheck -Id "schema.opencode.auth.$authId.automation" -Status "fail" -Message "Auth checks must be manual-required" -Path $Path }
            if (Test-ObjectHasProperty -Value $auth -Name "verify") { $checks += Test-OpenCodeVerifyStepShape -Step $auth.verify -Id "schema.opencode.auth.$authId.verify" -Path $Path }
            $authIndex++
        }
    }

    if ($checks.Count -eq 0) { $checks += New-DoctorCheck -Id "schema.$Kind" -Status "pass" -Message "Manifest schema shape is valid" -Path $Path }
    return $checks
}

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "JSON file not found: $Path"
    }

    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Test-UniqueIds {
    param(
        [Parameter(Mandatory = $true)][object[]]$Items,
        [Parameter(Mandatory = $true)][string]$Kind,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $checks = @()
    $ids = @($Items | Where-Object { Test-ObjectHasProperty -Value $_ -Name "id" } | ForEach-Object { $_.id })
    $dupes = @($ids | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })

    if ($dupes.Count -gt 0) {
        $checks += New-DoctorCheck -Id "manifest.$Kind.unique-ids" -Status "fail" -Message "Duplicate $Kind ids: $($dupes -join ', ')" -Path $Path
    } else {
        $checks += New-DoctorCheck -Id "manifest.$Kind.unique-ids" -Status "pass" -Message "$Kind ids are unique" -Path $Path
    }

    return $checks
}

function Test-ManifestReferences {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][object]$Profile,
        [Parameter(Mandatory = $true)][object]$Capabilities
    )

    $checks = @()
    foreach ($ref in (Get-OptionalArray -Value $Profile -Name "manifest_refs")) {
        $pathCheck = Test-RepoRelativePath -RepoRoot $RepoRoot -Value $ref -CheckId "profile.manifest-ref.$ref.path" -ManifestPath $ref
        $checks += $pathCheck
        if ($pathCheck.status -ne "pass") { continue }
        $path = Resolve-RepoPath -RepoRoot $RepoRoot -RelativePath $ref
        if (Test-Path -LiteralPath $path) {
            $checks += New-DoctorCheck -Id "profile.manifest-ref.$ref" -Status "pass" -Message "Profile manifest reference exists" -Path $ref
        } else {
            $checks += New-DoctorCheck -Id "profile.manifest-ref.$ref" -Status "fail" -Message "Profile manifest reference is missing" -Path $ref
        }
    }

    foreach ($capability in (Get-OptionalArray -Value $Capabilities -Name "capabilities")) {
        $capabilityId = Get-ManifestItemId -Value $capability -Fallback "unknown"
        $capabilityAutomation = if (Test-ObjectHasProperty -Value $capability -Name "automation") { $capability.automation } else { "" }
        foreach ($ref in (Get-OptionalArray -Value $capability -Name "manifests")) {
            $pathCheck = Test-RepoRelativePath -RepoRoot $RepoRoot -Value $ref -CheckId "capability.$capabilityId.manifest-ref.$ref.path" -ManifestPath $ref -Automation $capabilityAutomation
            $checks += $pathCheck
            if ($pathCheck.status -ne "pass") { continue }
            $path = Resolve-RepoPath -RepoRoot $RepoRoot -RelativePath $ref
            if (Test-Path -LiteralPath $path) {
                $checks += New-DoctorCheck -Id "capability.$capabilityId.manifest-ref.$ref" -Status "pass" -Message "Capability manifest reference exists" -Path $ref -Automation $capabilityAutomation
            } else {
                $checks += New-DoctorCheck -Id "capability.$capabilityId.manifest-ref.$ref" -Status "fail" -Message "Capability manifest reference is missing" -Path $ref -Automation $capabilityAutomation
            }
        }
    }

    return $checks
}

function Test-ToolSafetyInvariants {
    param(
        [Parameter(Mandatory = $true)][object]$Tools,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $checks = @()
    $toolIndex = 0
    foreach ($tool in (Get-OptionalArray -Value $Tools -Name "tools")) {
        $toolId = Get-ManifestItemId -Value $tool -Fallback "index-$toolIndex"
        foreach ($group in @("install_methods", "update_methods")) {
            if ($tool.PSObject.Properties.Name -contains $group) {
                foreach ($method in @($tool.$group)) {
                    $methodId = Get-ManifestItemId -Value $method -Fallback "$group-item"
                    $network = ($method.PSObject.Properties.Name -contains "requires_network") -and ($method.requires_network -eq $true)
                    $admin = ($method.PSObject.Properties.Name -contains "requires_admin") -and ($method.requires_admin -eq $true)
                    $automation = if (Test-ObjectHasProperty -Value $method -Name "automation") { $method.automation } else { "" }
                    if (($automation -eq "auto-safe") -and ($network -or $admin)) {
                        $checks += New-DoctorCheck -Id "tool.$toolId.$methodId.safety" -Status "fail" -Message "Network/admin method cannot be auto-safe" -Path $Path -Automation $automation
                    } else {
                        $checks += New-DoctorCheck -Id "tool.$toolId.$methodId.safety" -Status "pass" -Message "Tool method safety classification is acceptable" -Path $Path -Automation $automation
                    }
                }
            }
        }
        $toolIndex++
    }

    return $checks
}

function Test-OpenCodeSafetyInvariants {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][object]$OpenCode,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $checks = @()
    if (-not (Test-ObjectHasProperty -Value $OpenCode -Name "config")) {
        $checks += New-DoctorCheck -Id "opencode.config.safety" -Status "fail" -Message "OpenCode config is missing" -Path $Path
        return $checks
    }

    if (($OpenCode.config.target -ne "project") -and ($OpenCode.config.automation -eq "auto-safe")) {
        $checks += New-DoctorCheck -Id "opencode.config.safety" -Status "fail" -Message "Only project OpenCode config can be auto-safe" -Path $Path -Automation $OpenCode.config.automation
    } else {
        $checks += New-DoctorCheck -Id "opencode.config.safety" -Status "pass" -Message "OpenCode config target safety is acceptable" -Path $Path -Automation $OpenCode.config.automation
    }

    if ((Test-ObjectHasProperty -Value $OpenCode.config -Name "path") -and ($OpenCode.config.automation -eq "auto-safe")) {
        $checks += Test-RepoRelativePath -RepoRoot $RepoRoot -Value $OpenCode.config.path -CheckId "opencode.config.path" -ManifestPath $OpenCode.config.path -Automation $OpenCode.config.automation
    }

    if (Test-ObjectHasProperty -Value $OpenCode.config -Name "template") {
        $checks += Test-RepoRelativePath -RepoRoot $RepoRoot -Value $OpenCode.config.template -CheckId "opencode.config.template.path" -ManifestPath $OpenCode.config.template -Automation $OpenCode.config.automation
        $templatePath = Resolve-RepoPath -RepoRoot $RepoRoot -RelativePath $OpenCode.config.template
        if (Test-Path -LiteralPath $templatePath) {
            $checks += New-DoctorCheck -Id "opencode.config.template" -Status "pass" -Message "OpenCode config template exists" -Path $OpenCode.config.template
        } else {
            $checks += New-DoctorCheck -Id "opencode.config.template" -Status "fail" -Message "OpenCode config template is missing" -Path $OpenCode.config.template
        }
    }

    $assetIndex = 0
    foreach ($asset in @(Get-OptionalArray -Value $OpenCode -Name "assets") + @(Get-OptionalArray -Value $OpenCode -Name "mcp")) {
        if ($null -eq $asset) { continue }
        $assetId = Get-ManifestItemId -Value $asset -Fallback "index-$assetIndex"
        $assetNames = Get-ObjectPropertyNames -Value $asset
        $automation = if ($assetNames -contains "automation") { $asset.automation } else { "" }
        $assetType = if ($assetNames -contains "type") { $asset.type } else { "" }
        $network = ($assetNames -contains "requires_network") -and ($asset.requires_network -eq $true)
        if (($automation -eq "auto-safe") -and ($network -or ($assetType -in @("plugin", "mcp")))) {
            $checks += New-DoctorCheck -Id "opencode.asset.$assetId.safety" -Status "fail" -Message "Network, plugin, or MCP asset cannot be auto-safe" -Path $Path -Automation $automation
        } else {
            $checks += New-DoctorCheck -Id "opencode.asset.$assetId.safety" -Status "pass" -Message "OpenCode asset safety classification is acceptable" -Path $Path -Automation $automation
        }

        if ((Test-ObjectHasProperty -Value $asset -Name "merge_strategy") -and ($asset.merge_strategy -eq "sync-owned") -and ($automation -eq "auto-safe")) {
            $checks += New-DoctorCheck -Id "opencode.asset.$assetId.ownership" -Status "fail" -Message "sync-owned auto-safe asset requires an explicit ownership check before writes" -Path $Path -Automation $automation
        }

        if ($assetNames -contains "source") {
            $checks += Test-RepoRelativePath -RepoRoot $RepoRoot -Value $asset.source -CheckId "opencode.asset.$assetId.source.path" -ManifestPath $asset.source -Automation $automation
            $sourcePath = Resolve-RepoPath -RepoRoot $RepoRoot -RelativePath $asset.source
            if (Test-Path -LiteralPath $sourcePath) {
                $checks += New-DoctorCheck -Id "opencode.asset.$assetId.source" -Status "pass" -Message "OpenCode asset source exists" -Path $asset.source -Automation $automation
            } elseif (($assetNames -contains "enabled") -and ($asset.enabled -eq $false)) {
                $checks += New-DoctorCheck -Id "opencode.asset.$assetId.source" -Status "warn" -Message "Disabled OpenCode asset source is missing" -Path $asset.source -Automation $automation
            } else {
                $checks += New-DoctorCheck -Id "opencode.asset.$assetId.source" -Status "fail" -Message "OpenCode asset source is missing" -Path $asset.source -Automation $automation
            }
        }

        if (($assetNames -contains "target") -and ($asset.target -notmatch '^\.opencode[\\/]')) {
            $checks += New-DoctorCheck -Id "opencode.asset.$assetId.target.path" -Status "fail" -Message "OpenCode asset targets must stay under .opencode/ unless separately approval-gated in implementation" -Path $asset.target -Automation $automation
        } elseif ($assetNames -contains "target") {
            $checks += Test-RepoRelativePath -RepoRoot $RepoRoot -Value $asset.target -CheckId "opencode.asset.$assetId.target.path" -ManifestPath $asset.target -Automation $automation
        }

        $assetIndex++
    }

    return $checks
}

function Test-OpenCodeVerifySteps {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][object]$OpenCode,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $checks = @()
    $assetIndex = 0
    foreach ($asset in @(Get-OptionalArray -Value $OpenCode -Name "assets") + @(Get-OptionalArray -Value $OpenCode -Name "mcp")) {
        if ($null -eq $asset) { continue }
        $assetId = Get-ManifestItemId -Value $asset -Fallback "index-$assetIndex"
        $assetNames = Get-ObjectPropertyNames -Value $asset
        $automation = if ($assetNames -contains "automation") { $asset.automation } else { "" }
        if (($assetNames -contains "enabled") -and ($asset.enabled -eq $false)) {
            $assetIndex++
            continue
        }
        foreach ($step in (Get-OptionalArray -Value $asset -Name "verify")) {
            $kind = if (Test-ObjectHasProperty -Value $step -Name "kind") { $step.kind } else { "" }
            if ($kind -eq "directory-exists" -or $kind -eq "file-exists") {
                if (-not (Test-ObjectHasProperty -Value $step -Name "value")) {
                    $checks += New-DoctorCheck -Id "opencode.asset.$assetId.verify.value" -Status "fail" -Message "Filesystem verify step requires a value" -Path $Path -Automation $automation
                    continue
                }
                $pathCheck = Test-RepoRelativePath -RepoRoot $RepoRoot -Value $step.value -CheckId "opencode.asset.$assetId.verify.$kind.path" -ManifestPath $step.value -Automation $automation
                $checks += $pathCheck
                if ($pathCheck.status -ne "pass") { continue }

                $resolved = Resolve-RepoPath -RepoRoot $RepoRoot -RelativePath $step.value
                if ($kind -eq "directory-exists") {
                    $exists = (Test-Path -LiteralPath $resolved -PathType Container)
                } else {
                    $exists = (Test-Path -LiteralPath $resolved -PathType Leaf)
                }
                if ($exists) {
                    $checks += New-DoctorCheck -Id "opencode.asset.$assetId.verify.$kind" -Status "pass" -Message "OpenCode asset verify step passed" -Path $step.value -Automation $automation
                } else {
                    $checks += New-DoctorCheck -Id "opencode.asset.$assetId.verify.$kind" -Status "blocked" -Message "OpenCode asset target is not present yet; run approved convergence before claiming setup complete" -Path $step.value -Automation $automation
                }
            } elseif ($kind -eq "command") {
                if (-not (Test-ObjectHasProperty -Value $step -Name "argv")) {
                    $checks += New-DoctorCheck -Id "opencode.asset.$assetId.verify.command.argv" -Status "fail" -Message "Command verify step requires argv" -Path $Path -Automation $automation
                    continue
                }
                $result = Invoke-ManifestCommand -CommandSpec $step
                $combined = "$($result.stdout)`n$($result.stderr)"
                $regexOk = $true
                if (Test-ObjectHasProperty -Value $step -Name "success_regex") {
                    $regexOk = Test-SuccessRegex -Pattern $step.success_regex -Text $combined
                }
                if ($result.available -and ($result.exit_code -eq 0) -and $regexOk) {
                    $checks += New-DoctorCheck -Id "opencode.asset.$assetId.verify.command" -Status "pass" -Message "OpenCode asset command verify step passed" -Path $Path -Automation $automation -Data (ConvertTo-SafeCommandResult -Result $result)
                } else {
                    $checks += New-DoctorCheck -Id "opencode.asset.$assetId.verify.command" -Status "blocked" -Message "OpenCode asset command verify step did not pass" -Path $Path -Automation $automation -Data (ConvertTo-SafeCommandResult -Result $result)
                }
            }
        }
        $assetIndex++
    }
    return $checks
}
