<#
.SYNOPSIS
  Launch Claude Code with NVIDIA NIM Bridge on Windows (PowerShell)
#>

$ScriptDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$EnvFile = Join-Path $ScriptDir ".env"
$PidFile = Join-Path $ScriptDir ".proxy.pid"
$LogFile = Join-Path $ScriptDir ".proxy.log"
$ErrLogFile = Join-Path $ScriptDir ".proxy.err.log"
$VenvPython = Join-Path $ScriptDir ".venv\Scripts\python.exe"

$PythonBin = if (Test-Path $VenvPython) { $VenvPython } else { "python" }

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
$Port = if ($EnvMap["NIM_PROXY_PORT"]) { $EnvMap["NIM_PROXY_PORT"] } else { "8000" }
$Model = $DefaultModel
$ApiKey = if ($env:NVIDIA_API_KEY) { $env:NVIDIA_API_KEY } else { $EnvMap["NVIDIA_API_KEY"] }
$BaseUrl = if ($EnvMap["NIM_BASE_URL"]) { $EnvMap["NIM_BASE_URL"] } else { "https://integrate.api.nvidia.com/v1" }

# Parse arguments
$ClaudeArgs = @()
$i = 0
while ($i -lt $args.Count) {
    $arg = $args[$i]
    switch ($arg) {
        "--help" {
            Write-Host "Claude Code with NVIDIA NIM Bridge (Windows)" -ForegroundColor Cyan
            Write-Host "Usage: claude-nim [options] [claude options...]"
            Write-Host "Options:"
            Write-Host "  --model <name>  Specify the model (default: meta/llama-3.3-70b-instruct)"
            Write-Host "  --port <port>   Specify proxy port (default: 8000)"
            Write-Host "  --key <key>     Set NVIDIA API Key"
            Write-Host "  --stop          Stop background proxy"
            Write-Host "  --status        Check proxy status"
            Write-Host "  --logs          View background proxy logs"
            exit 0
        }
        "-h" {
            Write-Host "Claude Code with NVIDIA NIM Bridge (Windows)" -ForegroundColor Cyan
            exit 0
        }
        "--model" {
            $i++; $Model = $args[$i]
        }
        "-m" {
            $i++; $Model = $args[$i]
        }
        "--port" {
            $i++; $Port = $args[$i]
        }
        "--key" {
            $i++; $ApiKey = $args[$i]
        }
        "--status" {
            if (Test-Path $PidFile) {
                $pidVal = (Get-Content $PidFile -ErrorAction SilentlyContinue)
                if ($pidVal -and ($proc = Get-Process -Id $pidVal -ErrorAction SilentlyContinue)) {
                    Write-Host "NIM Proxy is RUNNING (PID: $pidVal, Port: $Port)" -ForegroundColor Green
                    exit 0
                }
            }
            Write-Host "NIM Proxy is STOPPED" -ForegroundColor Yellow
            exit 0
        }
        "--stop" {
            if (Test-Path $PidFile) {
                $pidVal = (Get-Content $PidFile -ErrorAction SilentlyContinue)
                if ($pidVal) {
                    Stop-Process -Id $pidVal -ErrorAction SilentlyContinue
                }
                Remove-Item $PidFile -ErrorAction SilentlyContinue
                Write-Host "Stopped NIM Proxy$(if ($pidVal) { " (PID: $pidVal)" })" -ForegroundColor Green
            } else {
                Write-Host "No running proxy found." -ForegroundColor Yellow
            }
            exit 0
        }
        "--logs" {
            if (Test-Path $LogFile) {
                Write-Host "=== Output Log ($LogFile) ===" -ForegroundColor Cyan
                Get-Content $LogFile -Tail 50
            }
            if (Test-Path $ErrLogFile) {
                Write-Host "=== Error Log ($ErrLogFile) ===" -ForegroundColor Cyan
                Get-Content $ErrLogFile -Tail 50
            }
            if (-not (Test-Path $LogFile) -and -not (Test-Path $ErrLogFile)) {
                Write-Host "No log file found." -ForegroundColor Yellow
            }
            exit 0
        }
        Default {
            $ClaudeArgs += $arg
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
NIM_PROXY_PORT="$Port"
"@ | Set-Content $EnvFile -Encoding UTF8

$env:NVIDIA_API_KEY = $ApiKey
$env:NIM_MODEL = $Model
$env:NIM_PROXY_PORT = $Port

# Function to test proxy health
function Test-ProxyRunning {
    try {
        $resp = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/health" -TimeoutSec 1 -ErrorAction SilentlyContinue
        return ($null -ne $resp)
    } catch {
        return $false
    }
}

# Start proxy if not active
if (-not (Test-ProxyRunning)) {
    $pyWorks = try { & $PythonBin -c "import sys" 2>$null; $LASTEXITCODE -eq 0 } catch { $false }
    if (-not $pyWorks) {
        Write-Error "Python is not installed or not working properly. Please install Python 3.10+ (e.g., 'winget install Python.Python.3.12') and run install.ps1 to set up the environment."
        exit 1
    }

    Write-Host "Starting NIM background proxy on port $Port..." -ForegroundColor Cyan
    $ProxyScript = Join-Path $ScriptDir "proxy.py"
    $proc = Start-Process -FilePath $PythonBin -ArgumentList "-u `"$ProxyScript`" --port $Port" -WindowStyle Hidden -PassThru -RedirectStandardOutput $LogFile -RedirectStandardError $ErrLogFile
    if ($proc -and $proc.Id) {
        $proc.Id | Set-Content $PidFile
    }

    $ready = $false
    for ($attempt = 0; $attempt -lt 25; $attempt++) {
        Start-Sleep -Milliseconds 200
        if (Test-ProxyRunning) {
            $ready = $true
            break
        }
    }
    if (-not $ready) {
        Write-Warning "Proxy startup took longer than expected. Check logs at $LogFile or $ErrLogFile"
    }
}

# Export environment variables for Claude Code
$env:ANTHROPIC_BASE_URL = "http://127.0.0.1:$Port"
$env:ANTHROPIC_API_KEY = "not-used"
$env:ANTHROPIC_MODEL = $Model
$env:CLAUDE_MODEL = $Model
$env:MODEL_NAME = $Model
$env:ANTHROPIC_CUSTOM_MODEL_OPTION = $Model
$env:ANTHROPIC_DEFAULT_HAIKU_MODEL = $Model
$env:ANTHROPIC_DEFAULT_SONNET_MODEL = $Model
$env:ANTHROPIC_DEFAULT_OPUS_MODEL = $Model
$env:CLAUDE_CODE_SUBAGENT_MODEL = $Model


Write-Host "==========================================================" -ForegroundColor Green
Write-Host " Launching Claude Code with NVIDIA NIM (Windows)" -ForegroundColor Green
Write-Host " Model:     $Model"
Write-Host " Endpoint:  $BaseUrl"
Write-Host " Proxy:     http://127.0.0.1:$Port"
Write-Host "==========================================================" -ForegroundColor Green

& claude @ClaudeArgs
