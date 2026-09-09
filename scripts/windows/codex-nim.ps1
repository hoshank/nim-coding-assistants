<#
.SYNOPSIS
  Launch Codex CLI with NVIDIA NIM on Windows (PowerShell)
#>

$ScriptDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$EnvFile = Join-Path $ScriptDir ".env"

# Load .env if present
$EnvMap = @{}
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
            $parts = $line.Split("=", 2)
            $EnvMap[$parts[0].Trim()] = $parts[1].Trim().Trim('"').Trim("'")
        }
    }
}

$DefaultModel = if ($EnvMap["NIM_MODEL"]) { $EnvMap["NIM_MODEL"] } else { "nvidia/nemotron-3-ultra-550b-a55b" }
$Model = $DefaultModel
$ApiKey = if ($env:NVIDIA_API_KEY) { $env:NVIDIA_API_KEY } else { $EnvMap["NVIDIA_API_KEY"] }
$BaseUrl = if ($EnvMap["NIM_BASE_URL"]) { $EnvMap["NIM_BASE_URL"] } else { "https://integrate.api.nvidia.com/v1" }

# Parse arguments
$CodexArgs = @()
$i = 0
while ($i -lt $args.Count) {
    $arg = $args[$i]
    switch ($arg) {
        "--help" {
            Write-Host "Codex CLI with NVIDIA NIM (Windows)" -ForegroundColor Cyan
            Write-Host "Usage: codex-nim [options] [codex options...]"
            Write-Host "Options:"
            Write-Host "  --model <name>  Specify the model (default: meta/llama-3.3-70b-instruct)"
            Write-Host "  --key <key>     Set NVIDIA API Key"
            Write-Host "  --url <url>     Set NVIDIA Base URL"
            exit 0
        }
        "-h" {
            Write-Host "Codex CLI with NVIDIA NIM (Windows)" -ForegroundColor Cyan
            exit 0
        }
        "--model" {
            $i++; $Model = $args[$i]
        }
        "-m" {
            $i++; $Model = $args[$i]
        }
        "--key" {
            $i++; $ApiKey = $args[$i]
        }
        "--url" {
            $i++; $BaseUrl = $args[$i]
        }
        Default {
            $CodexArgs += $arg
        }
    }
    $i++
}

# Prompt for key if missing
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

# Save to .env
@"
# NVIDIA NIM Configuration for Claude Code & Codex CLI
NVIDIA_API_KEY="$ApiKey"
NIM_BASE_URL="$BaseUrl"
NIM_MODEL="$Model"
NIM_PROXY_PORT="${env:NIM_PROXY_PORT:-8000}"
"@ | Set-Content $EnvFile -Encoding UTF8

$env:NVIDIA_API_KEY = $ApiKey
$env:OPENAI_BASE_URL = $BaseUrl
$env:OPENAI_API_KEY = $ApiKey
$env:CODEX_MODEL = $Model

# Ensure nim profile is maintained in ~/.codex/nim.config.toml
$CodexDir = Join-Path $env:USERPROFILE ".codex"
if (-not (Test-Path $CodexDir)) {
    New-Item -ItemType Directory -Path $CodexDir -Force | Out-Null
}
$NimProfilePath = Join-Path $CodexDir "nim.config.toml"
@"
model = "$Model"
model_provider = "nvidia_nim"

[model_providers.nvidia_nim]
name = "NVIDIA NIM"
base_url = "$BaseUrl"
env_key = "NVIDIA_API_KEY"
wire_api = "responses"
"@ | Set-Content $NimProfilePath -Encoding UTF8

$NimConfigArgs = @(
    "-c", "model_provider=`"nvidia_nim`"",
    "-c", "model=`"$Model`"",
    "-c", "model_providers.nvidia_nim.name=`"NVIDIA NIM`"",
    "-c", "model_providers.nvidia_nim.base_url=`"$BaseUrl`"",
    "-c", "model_providers.nvidia_nim.env_key=`"NVIDIA_API_KEY`"",
    "-c", "model_providers.nvidia_nim.wire_api=`"responses`""
)

Write-Host "==========================================================" -ForegroundColor Green
Write-Host " Launching Codex CLI with NVIDIA NIM (Windows)" -ForegroundColor Green
Write-Host " Model:     $Model"
Write-Host " Endpoint:  $BaseUrl"
Write-Host " Provider:  nvidia_nim"
Write-Host "==========================================================" -ForegroundColor Green

& codex @NimConfigArgs @CodexArgs

