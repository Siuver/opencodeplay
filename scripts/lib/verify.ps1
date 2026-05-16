Set-StrictMode -Version 2.0

function New-DoctorCheck {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Status,
        [Parameter(Mandatory = $true)][string]$Message,
        [string]$Path = "",
        [string]$Automation = "",
        [object]$Data = $null
    )

    [pscustomobject]@{
        id = $Id
        status = $Status
        message = $Message
        path = $Path
        automation = $Automation
        data = $Data
    }
}

function ConvertTo-SafeCommandResult {
    param(
        [Parameter(Mandatory = $true)][object]$Result,
        [bool]$SensitiveOutput = $false
    )

    $stdout = $Result.stdout
    $stderr = $Result.stderr
    if ($SensitiveOutput) {
        $stdout = "<redacted>"
        $stderr = if ([string]::IsNullOrWhiteSpace($Result.stderr)) { "" } else { "<redacted>" }
    }

    [pscustomobject]@{
        executable = $Result.executable
        exit_code = $Result.exit_code
        stdout = $stdout
        stderr = $stderr
        available = $Result.available
        timed_out = $Result.timed_out
        sensitive_output = $SensitiveOutput
    }
}

function ConvertTo-NativeArgument {
    param([Parameter(Mandatory = $true)][string]$Value)

    if ($Value -notmatch '[\s"&|<>^()]') {
        return $Value
    }

    return '"' + ($Value -replace '([\\]*)"', '$1$1\"' -replace '([\\]+)$', '$1$1') + '"'
}

function Test-CmdArgumentSafe {
    param([Parameter(Mandatory = $true)][string]$Value)

    return $Value -notmatch '[&|<>^%!]'
}

function Invoke-ManifestCommand {
    param(
        [Parameter(Mandatory = $true)][object]$CommandSpec,
        [int]$TimeoutSeconds = 20
    )

    if (-not ($CommandSpec.PSObject.Properties.Name -contains "argv")) {
        return [pscustomobject]@{
            executable = ""
            exit_code = $null
            stdout = ""
            stderr = "argv is missing"
            available = $false
            timed_out = $false
        }
    }

    $argv = @($CommandSpec.argv)
    if ($argv.Count -lt 1) {
        return [pscustomobject]@{
            executable = ""
            exit_code = $null
            stdout = ""
            stderr = "argv is empty"
            available = $false
            timed_out = $false
        }
    }

    $exe = [string]$argv[0]
    $found = Get-Command -Name $exe -ErrorAction SilentlyContinue
    if ($null -eq $found) {
        return [pscustomobject]@{
            executable = $exe
            exit_code = $null
            stdout = ""
            stderr = "command not found"
            available = $false
            timed_out = $false
        }
    }

    $resolvedExe = $exe
    if ($found.PSObject.Properties.Name -contains "Source" -and -not [string]::IsNullOrWhiteSpace($found.Source)) {
        $resolvedExe = $found.Source
    } elseif ($found.PSObject.Properties.Name -contains "Path" -and -not [string]::IsNullOrWhiteSpace($found.Path)) {
        $resolvedExe = $found.Path
    } elseif ($found.PSObject.Properties.Name -contains "Definition" -and -not [string]::IsNullOrWhiteSpace($found.Definition)) {
        $resolvedExe = $found.Definition
    }

    $launcher = $resolvedExe
    $prefixArgs = @()
    $extension = [System.IO.Path]::GetExtension($resolvedExe)
    if ($extension -ieq ".ps1") {
        $launcher = "powershell.exe"
        $prefixArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $resolvedExe)
    } elseif ($extension -ieq ".cmd" -or $extension -ieq ".bat") {
        foreach ($arg in @($argv | Select-Object -Skip 1)) {
            if (-not (Test-CmdArgumentSafe -Value ([string]$arg))) {
                return [pscustomobject]@{
                    executable = $resolvedExe
                    exit_code = $null
                    stdout = ""
                    stderr = "refusing to pass CMD metacharacters to batch wrapper"
                    available = $true
                    timed_out = $false
                }
            }
        }
        $launcher = "cmd.exe"
        $prefixArgs = @("/d", "/c", $resolvedExe)
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $launcher
    $nativeArgs = @($prefixArgs | ForEach-Object { ConvertTo-NativeArgument -Value ([string]$_) })
    for ($i = 1; $i -lt $argv.Count; $i++) {
        $nativeArgs += ConvertTo-NativeArgument -Value ([string]$argv[$i])
    }
    $psi.Arguments = $nativeArgs -join " "
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    try {
        [void]$process.Start()
    } catch {
        return [pscustomobject]@{
            executable = $resolvedExe
            exit_code = $null
            stdout = ""
            stderr = $_.Exception.Message
            available = $true
            timed_out = $false
        }
    }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $completed = $process.WaitForExit($TimeoutSeconds * 1000)

    if (-not $completed) {
        try { $process.Kill() } catch { $null = $_ }
        return [pscustomobject]@{
            executable = $exe
            exit_code = $null
            stdout = if ($stdoutTask.IsCompleted) { $stdoutTask.Result } else { "" }
            stderr = if ($stderrTask.IsCompleted) { $stderrTask.Result } else { "command timed out" }
            available = $true
            timed_out = $true
        }
    }

    $process.WaitForExit()

    [pscustomobject]@{
        executable = $exe
        exit_code = $process.ExitCode
        stdout = $stdoutTask.Result
        stderr = $stderrTask.Result
        available = $true
        timed_out = $false
    }
}

function Test-SuccessRegex {
    param(
        [string]$Pattern,
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Pattern)) {
        return $true
    }

    return [regex]::IsMatch($Text, $Pattern)
}
