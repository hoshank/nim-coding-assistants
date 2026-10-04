<#
.SYNOPSIS
  Configure Pi Coding Agent and NVlabs SoL-Pi extension for NVIDIA NIM (Windows)
#>

[CmdletBinding()]
param(
    [string]$Model = "nvidia/nemotron-3-super-120b-a12b",
    [string]$ApiKey = "",
    [switch]$Help
)

if ($Help) {
    Write-Host "Setup Pi & NVlabs SoL-Pi with NVIDIA NIM" -ForegroundColor Cyan
    Write-Host "Usage: .\setup-sol-pi.ps1 [-Model <id>] [-ApiKey <key>]"
    exit 0
}

$ScriptDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$EnvFile = Join-Path $ScriptDir ".env"

# Read key from .env if not supplied
if (-not $ApiKey -and (Test-Path $EnvFile)) {
    Get-Content $EnvFile | ForEach-Object {
        $line = $_.Trim()
        if ($line.StartsWith("NVIDIA_API_KEY=")) {
            $ApiKey = $line.Substring(15).Trim().Trim('"').Trim("'")
        }
    }
}

if (-not $ApiKey -and $env:NVIDIA_API_KEY) {
    $ApiKey = $env:NVIDIA_API_KEY
}

if (-not $ApiKey) {
    Write-Host "==========================================================" -ForegroundColor Yellow
    Write-Host " NVIDIA NIM API Key Required" -ForegroundColor Yellow
    Write-Host " Get your key from: https://build.nvidia.com/" -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Yellow
    $ApiKey = Read-Host "Enter your NVIDIA API Key (nvapi-...)"
    if (-not $ApiKey) {
        Write-Error "NVIDIA API Key is required."
        exit 1
    }
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Configuring Pi Coding Agent & SoL-Pi with NVIDIA NIM" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

function Write-JsonNoBom {
    param([string]$Path, [string]$Content)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

# 1. Configure ~/.pi/agent/auth.json
$PiAgentDir = Join-Path $env:USERPROFILE ".pi\agent"
if (-not (Test-Path $PiAgentDir)) {
    New-Item -ItemType Directory -Path $PiAgentDir -Force | Out-Null
}
$AuthPath = Join-Path $PiAgentDir "auth.json"
$authData = @{}
if (Test-Path $AuthPath) {
    try {
        $authData = Get-Content $AuthPath -Raw | ConvertFrom-Json -AsHashtable
    } catch {
        $authData = @{}
    }
}
$authData["nvidia"] = @{
    "type" = "api_key"
    "key" = $ApiKey
}
Write-JsonNoBom -Path $AuthPath -Content ($authData | ConvertTo-Json -Depth 5)
Write-Host "[OK] Updated Pi authentication in $AuthPath" -ForegroundColor Green

# 2. Configure ~/.pi/agent/sol-pi.json
$SolPiConfigPath = Join-Path $PiAgentDir "sol-pi.json"
$solPiConfig = @{
    "version" = 1
    "actionFusion" = $true
    "observationPack" = $true
    "evidencePreservingReducer" = $true
    "evidencePreservingReducerProvider" = "nvidia"
    "evidencePreservingReducerModel" = $Model
    "onlineContextCompact" = $true
    "cacheWriteReadRatio" = 12.5
}
Write-JsonNoBom -Path $SolPiConfigPath -Content ($solPiConfig | ConvertTo-Json -Depth 5)
Write-Host "[OK] Configured SoL-Pi in $SolPiConfigPath" -ForegroundColor Green
Write-Host "     Evidence-Preserving Reducer Route: nvidia / $Model" -ForegroundColor Gray

# 3. Verify SoL-Pi Package & Retry Settings in Pi Settings
$SettingsPath = Join-Path $PiAgentDir "settings.json"
$settingsData = @{}
if (Test-Path $SettingsPath) {
    try {
        $settingsData = Get-Content $SettingsPath -Raw | ConvertFrom-Json -AsHashtable
    } catch {
        $settingsData = @{}
    }
}

# Ensure retry policy is set to 20 retries
$settingsData["retry"] = @{
    "enabled" = $true
    "maxRetries" = 20
    "baseDelayMs" = 2000
    "provider" = @{
        "maxRetries" = 20
        "maxRetryDelayMs" = 60000
    }
}

if (-not $settingsData.ContainsKey("packages")) {
    $settingsData["packages"] = @("git:github.com/NVlabs/SoL-Pi")
} elseif ($settingsData["packages"] -notcontains "git:github.com/NVlabs/SoL-Pi") {
    $settingsData["packages"] += "git:github.com/NVlabs/SoL-Pi"
}

Write-JsonNoBom -Path $SettingsPath -Content ($settingsData | ConvertTo-Json -Depth 5)
Write-Host "[OK] Configured Pi retry policy (up to 20 retries) & SoL-Pi package in $SettingsPath" -ForegroundColor Green

# 4. Run preflight validation if SoL-Pi checkout exists
$SolPiCheckout = Join-Path $PiAgentDir "git\github.com\NVlabs\SoL-Pi"
$CheckerScript = Join-Path $SolPiCheckout "scripts\check-sol-pi-config.mjs"
if (Test-Path $CheckerScript) {
    Write-Host "Running SoL-Pi config preflight..." -ForegroundColor Cyan
    & node $CheckerScript --config $SolPiConfigPath --require-all-enabled
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] SoL-Pi preflight check passed: all 4 mechanisms enabled!" -ForegroundColor Green
    } else {
        Write-Host "[!] Preflight check failed." -ForegroundColor Yellow
    }
}

Write-Host "==========================================================" -ForegroundColor Green
Write-Host " Setup Complete! You can now run Pi with NVIDIA NIM using:" -ForegroundColor Green
Write-Host "   pi-nim" -ForegroundColor Yellow
Write-Host "   pi --provider nvidia --model $Model" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Green
