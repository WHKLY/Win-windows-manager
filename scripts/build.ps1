[CmdletBinding()]
param(
    [string]$AhkBase = 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe',
    [string]$CompilerPath = ''
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$mainScript = Join-Path $root 'main.ahk'
$distDirectory = Join-Path $root 'dist'
$iconPath = Join-Path $root 'assets\Win-windows-manager.ico'
$outputExe = Join-Path $distDirectory 'Win-windows-manager-v0.1.1.exe'
$configSource = Join-Path $root 'config.ini'
$readmeSource = Join-Path $root 'README.md'
$docsSource = Join-Path $root 'docs'
$releaseDocs = Join-Path $distDirectory 'docs'

if ([string]::IsNullOrWhiteSpace($CompilerPath)) {
    $CompilerPath = Join-Path $root '.tools\Ahk2Exe\Ahk2Exe.exe'
}

if (-not (Test-Path -LiteralPath $AhkBase -PathType Leaf)) {
    throw "AutoHotkey v2 base executable not found: $AhkBase"
}
if (-not (Test-Path -LiteralPath $CompilerPath -PathType Leaf)) {
    throw "Ahk2Exe compiler not found: $CompilerPath"
}
if (-not (Test-Path -LiteralPath $mainScript -PathType Leaf)) {
    throw "Main script not found: $mainScript"
}
if (-not (Test-Path -LiteralPath $iconPath -PathType Leaf)) {
    throw "Application icon not found: $iconPath"
}

New-Item -ItemType Directory -Path $distDirectory -Force | Out-Null
foreach ($obsoleteName in @('WindowswindowsManager.exe', 'WindowswindowsManager-0.1.0.zip')) {
    $obsoletePath = Join-Path $distDirectory $obsoleteName
    if (Test-Path -LiteralPath $obsoletePath -PathType Leaf) {
        Remove-Item -LiteralPath $obsoletePath -Force
    }
}

$compilerArgs = (
    '/in "{0}" /out "{1}" /base "{2}" /icon "{3}" /silent' -f
    $mainScript,
    $outputExe,
    $AhkBase,
    $iconPath
)

Write-Host "Compiling $mainScript"
$compiler = Start-Process `
    -FilePath $CompilerPath `
    -ArgumentList $compilerArgs `
    -WorkingDirectory $root `
    -Wait `
    -PassThru

if ($compiler.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $outputExe -PathType Leaf)) {
    throw "Ahk2Exe failed with exit code $($compiler.ExitCode)"
}

Copy-Item -LiteralPath $configSource -Destination (Join-Path $distDirectory 'config.ini') -Force
Copy-Item -LiteralPath $readmeSource -Destination (Join-Path $distDirectory 'README.md') -Force
New-Item -ItemType Directory -Path $releaseDocs -Force | Out-Null
Get-ChildItem -LiteralPath $docsSource -Recurse -File | ForEach-Object {
    $relativePath = [System.IO.Path]::GetRelativePath($docsSource, $_.FullName)
    $destination = Join-Path $releaseDocs $relativePath
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath $_.FullName -Destination $destination -Force
}

$hash = Get-FileHash -LiteralPath $outputExe -Algorithm SHA256
$hashLine = "$($hash.Hash.ToLowerInvariant())  Win-windows-manager-v0.1.1.exe"
Set-Content -LiteralPath (Join-Path $distDirectory 'SHA256SUMS.txt') -Value $hashLine -Encoding ascii

$releaseName = 'Win-windows-manager-v0.1.1.zip'
$releasePath = Join-Path $distDirectory $releaseName
Compress-Archive `
    -LiteralPath $outputExe, (Join-Path $distDirectory 'config.ini'), (Join-Path $distDirectory 'README.md'), (Join-Path $distDirectory 'SHA256SUMS.txt'), $releaseDocs `
    -DestinationPath $releasePath `
    -Force

Get-Item -LiteralPath $outputExe, $releasePath | Select-Object FullName,Length,LastWriteTime | Format-Table -AutoSize
Get-Content -LiteralPath (Join-Path $distDirectory 'SHA256SUMS.txt')
