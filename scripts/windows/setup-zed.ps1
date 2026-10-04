<#
.SYNOPSIS
  Configure Zed Editor with NVIDIA NIM on Windows (PowerShell)
#>

$ScriptDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$ZedConfigDir = Join-Path $env:APPDATA "Zed"
$ZedSettingsFile = Join-Path $ZedConfigDir "settings.json"
$ExampleFile = Join-Path $ScriptDir "config\zed_settings.example.json"
$MergeScript = Join-Path $ScriptDir "scripts\merge_zed_settings.py"

if (-not (Test-Path $ZedConfigDir)) {
    New-Item -ItemType Directory -Path $ZedConfigDir -Force | Out-Null
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Configuring Zed Editor for NVIDIA NIM (Windows)" -ForegroundColor Cyan
Write-Host " Target: $ZedSettingsFile" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

if (Test-Path $ZedSettingsFile) {
    $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
    $backupFile = "$ZedSettingsFile.backup.$timestamp"
    Copy-Item $ZedSettingsFile $backupFile
    Write-Host "Created backup of existing settings at: $backupFile" -ForegroundColor Yellow
}

$VenvPython = Join-Path $ScriptDir ".venv\Scripts\python.exe"
$pyExe = if (Test-Path $VenvPython) { $VenvPython } else { "python" }

if (Test-Path $MergeScript) {
    & $pyExe $MergeScript $ZedSettingsFile $ExampleFile
} else {
    Copy-Item $ExampleFile $ZedSettingsFile -Force
}

Write-Host ""
Write-Host "----------------------------------------------------------" -ForegroundColor Yellow
Write-Host " Important: Set your NVIDIA API Key in Zed" -ForegroundColor Yellow
Write-Host "----------------------------------------------------------" -ForegroundColor Yellow
Write-Host "1. Open Zed Editor."
Write-Host "2. Open Command Palette (Ctrl+Shift+P)."
Write-Host "3. Type and select: 'zed: set api key'."
Write-Host "4. Choose provider 'Nvidia'."
Write-Host "5. Paste your NVIDIA API Key (nvapi-...)."
Write-Host "==========================================================" -ForegroundColor Green
