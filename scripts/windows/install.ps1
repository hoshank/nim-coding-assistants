<#
.SYNOPSIS
  Installer for NVIDIA NIM Bridge for Claude Code & Codex CLI (Windows)
#>

$ScriptDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $ScriptDir

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Setting up NVIDIA NIM Bridge for Claude Code & Codex CLI" -ForegroundColor Cyan
Write-Host " Platform: Windows" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Check Python
$pythonInstalled = Get-Command python -ErrorAction SilentlyContinue
$pyWorks = if ($pythonInstalled) { try { & python -c "import sys" 2>$null; $LASTEXITCODE -eq 0 } catch { $false } } else { $false }
if (-not $pyWorks) {
    Write-Error "Python 3 is not found or not functional (Windows execution alias may be unconfigured). Please install Python 3.10+ (e.g. 'winget install Python.Python.3.12') and restart your terminal."
    exit 1
}

# 2. Setup Virtual Environment
$venvPath = Join-Path $ScriptDir ".venv"
if (-not (Test-Path $venvPath)) {
    Write-Host "Creating virtual environment in .venv..." -ForegroundColor Cyan
    python -m venv .venv
}

$venvPip = Join-Path $venvPath "Scripts\pip.exe"
Write-Host "Installing required Python packages..." -ForegroundColor Cyan
& $venvPip install --upgrade pip
& $venvPip install -r requirements.txt

# 3. Configure .env
$envFile = Join-Path $ScriptDir ".env"
if (-not (Test-Path $envFile)) {
    Write-Host ""
    Write-Host "----------------------------------------------------------" -ForegroundColor Yellow
    Write-Host " Enter your NVIDIA API Key (from https://build.nvidia.com/)" -ForegroundColor Yellow
    Write-Host "----------------------------------------------------------" -ForegroundColor Yellow
    $apiKey = Read-Host "NVIDIA API Key (nvapi-...)"
@"
# NVIDIA NIM Configuration
NVIDIA_API_KEY="$apiKey"
NIM_BASE_URL="https://integrate.api.nvidia.com/v1"
NIM_MODEL="meta/llama-3.3-70b-instruct"
NIM_PROXY_PORT="8000"
"@ | Set-Content $envFile -Encoding UTF8
}

# 4. Create CMD wrappers in user profile bin or WindowsApps
$binDir = Join-Path $env:USERPROFILE ".local\bin"
if (-not (Test-Path $binDir)) {
    New-Item -ItemType Directory -Path $binDir -Force | Out-Null
}

$claudeCmd = Join-Path $binDir "claude-nim.cmd"
$codexCmd = Join-Path $binDir "codex-nim.cmd"

$psClaude = Join-Path $ScriptDir "scripts\windows\claude-nim.ps1"
$psCodex = Join-Path $ScriptDir "scripts\windows\codex-nim.ps1"

"@echo off`r`npowershell -ExecutionPolicy Bypass -File `"$psClaude`" %*" | Set-Content $claudeCmd -Encoding ASCII
"@echo off`r`npowershell -ExecutionPolicy Bypass -File `"$psCodex`" %*" | Set-Content $codexCmd -Encoding ASCII

# Check user PATH for $binDir
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$binDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$binDir", "User")
    Write-Host "Added $binDir to User PATH." -ForegroundColor Green
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host " Installation Complete on Windows!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "Commands installed:"
Write-Host "  • claude-nim  -> Run Claude Code with NVIDIA NIM"
Write-Host "  • codex-nim   -> Run Codex CLI with NVIDIA NIM"
Write-Host ""
Write-Host "Restart your terminal and try:"
Write-Host "  claude-nim --help"
Write-Host "  codex-nim --help"
Write-Host "==========================================================" -ForegroundColor Green
