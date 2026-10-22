[CmdletBinding()]
param(
    [string]$AhkPath = 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path -LiteralPath $AhkPath -PathType Leaf)) {
    throw "AutoHotkey v2 runner not found: $AhkPath"
}

$testSuites = @(
    @{ Name = 'syntax'; Path = 'main.ahk'; Arguments = @('/ErrorStdOut', '/validate', 'main.ahk') },
    @{ Name = 'core'; Path = 'tests\run_tests.ahk'; Arguments = @('/ErrorStdOut', 'tests\run_tests.ahk') },
    @{
        Name = 'motion'
        Path = 'tests\motion_integration.ahk'
        Arguments = @('/ErrorStdOut', 'tests\motion_integration.ahk')
    },
    @{
        Name = 'registry'
        Path = 'tests\window_registry_integration.ahk'
        Arguments = @('/ErrorStdOut', 'tests\window_registry_integration.ahk')
    },
    @{
        Name = 'new-window'
        Path = 'tests\new_window_integration.ahk'
        Arguments = @('/ErrorStdOut', 'tests\new_window_integration.ahk')
    },
    @{
        Name = 'manual-undo'
        Path = 'tests\manual_undo_integration.ahk'
        Arguments = @('/ErrorStdOut', 'tests\manual_undo_integration.ahk')
    },
    @{
        Name = 'window-churn'
        Path = 'tests\window_churn_regression.ahk'
        Arguments = @('/ErrorStdOut', 'tests\window_churn_regression.ahk')
    },
    @{
        Name = 'destroy-race'
        Path = 'tests\window_destroy_race_regression.ahk'
        Arguments = @('/ErrorStdOut', 'tests\window_destroy_race_regression.ahk')
    },
    @{ Name = 'startup'; Path = 'tests\app_smoke.ahk'; Arguments = @('/ErrorStdOut', 'tests\app_smoke.ahk') }
)

foreach ($suite in $testSuites) {
    Write-Host "==> $($suite.Name)"
    $process = Start-Process `
        -FilePath $AhkPath `
        -ArgumentList $suite.Arguments `
        -WorkingDirectory $root `
        -Wait `
        -PassThru `
        -NoNewWindow
    if ($process.ExitCode -ne 0) {
        throw "Test suite failed: $($suite.Name), exit code $($process.ExitCode)"
    }
}

Write-Host 'All test suites passed.'
