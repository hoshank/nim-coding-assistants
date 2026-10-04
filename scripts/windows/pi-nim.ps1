<#
.SYNOPSIS
  Launch Pi Coding Agent with NVIDIA NIM & SoL-Pi on Windows (PowerShell)
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

$DefaultModel = if ($EnvMap["NIM_MODEL"]) { $EnvMap["NIM_MODEL"] } else { "nvidia/nemotron-3-super-120b-a12b" }
$Model = $DefaultModel
$ApiKey = if ($env:NVIDIA_API_KEY) { $env:NVIDIA_API_KEY } else { $EnvMap["NVIDIA_API_KEY"] }
$BaseUrl = if ($EnvMap["NIM_BASE_URL"]) { $EnvMap["NIM_BASE_URL"] } else { "https://integrate.api.nvidia.com/v1" }

$PiArgs = @()
$ChooseModel = $false
$RunInteractive = ($args.Count -eq 0)

$i = 0
while ($i -lt $args.Count) {
    $arg = $args[$i]
    switch ($arg) {
        "--help" {
            Write-Host "Pi Coding Agent with NVIDIA NIM & SoL-Pi (Windows)" -ForegroundColor Cyan
            Write-Host "Usage: pi-nim [options] [pi options...]"
            Write-Host "Options:"
            Write-Host "  --model, -m <name>   Specify the model (default: nvidia/nemotron-3-super-120b-a12b)"
            Write-Host "  --choose, -c         Interactively choose a model from the supported NIM catalog"
            Write-Host "  --interactive, -i    Run interactive TUI dropdown setup menu"
            Write-Host "  --key <key>          Set NVIDIA API Key"
            Write-Host "  --url <url>          Set NVIDIA Base URL"
            Write-Host "  --doctor             Run environment and configuration diagnostics"
            Write-Host ""
            Write-Host "All other arguments are forwarded directly to 'pi'."
            exit 0
        }
        "-h" {
            Write-Host "Pi Coding Agent with NVIDIA NIM & SoL-Pi (Windows)" -ForegroundColor Cyan
            exit 0
        }
        "--interactive" {
            $RunInteractive = $true
        }
        "-i" {
            $RunInteractive = $true
        }
        "--choose" {
            $ChooseModel = $true
        }
        "-c" {
            $ChooseModel = $true
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
            $PiArgs += $arg
        }
    }
    $i++
}

# Resolve Python for interactive menu
$VenvPy = Join-Path $ScriptDir ".venv\Scripts\python.exe"
$PythonBin = if (Test-Path $VenvPy) { $VenvPy } else { "python" }

if ($RunInteractive -or $ChooseModel) {
    $ConfigTmp = [System.IO.Path]::GetTempFileName()
    & $PythonBin (Join-Path $ScriptDir "scripts\interactive_menu.py") --app pi --output $ConfigTmp
    if ($LASTEXITCODE -eq 0 -and (Test-Path $ConfigTmp)) {
        Get-Content $ConfigTmp | ForEach-Object {
            $line = $_.Trim()
            if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
                $parts = $line.Split("=", 2)
                $k = $parts[0].Trim()
                $v = $parts[1].Trim().Trim('"').Trim("'")
                if ($k -eq "MODEL" -and $v) { $Model = $v }
                if ($k -eq "THINKING" -and $v) {
                    $PiArgs += @("--thinking", $v)
                }
            }
        }
        Remove-Item $ConfigTmp -Force -ErrorAction SilentlyContinue
    } elseif ($LASTEXITCODE -ne 0) {
        Remove-Item $ConfigTmp -Force -ErrorAction SilentlyContinue
        exit 130
    }
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

# Save key to .env if needed
if (Test-Path $EnvFile) {
    $envContent = Get-Content $EnvFile -Raw
    if ($envContent -notmatch "NVIDIA_API_KEY=") {
        Add-Content -Path $EnvFile -Value "`nNVIDIA_API_KEY=`"$ApiKey`""
    }
}

# Sync to ~/.pi/agent/auth.json
$PiAgentDir = Join-Path $env:USERPROFILE ".pi\agent"
if (-not (Test-Path $PiAgentDir)) {
    New-Item -ItemType Directory -Path $PiAgentDir -Force | Out-Null
}
$AuthJsonPath = Join-Path $PiAgentDir "auth.json"
$authData = @{}
if (Test-Path $AuthJsonPath) {
    try {
        $authData = Get-Content $AuthJsonPath -Raw | ConvertFrom-Json -AsHashtable
    } catch {
        $authData = @{}
    }
}
$authData["nvidia"] = @{
    "type" = "api_key"
    "key" = $ApiKey
}
$authData | ConvertTo-Json -Depth 5 | Set-Content -Path $AuthJsonPath -Encoding UTF8

$env:NVIDIA_API_KEY = $ApiKey

# Ensure model has provider prefix for Pi if not already present
$PiModel = if ($Model -notlike "*/*") {
    "nvidia/$Model"
} elseif ($Model.StartsWith("nvidia/")) {
    $Model
} else {
    # e.g. deepseek-ai/..., minimaxai/..., etc. under nvidia provider
    $Model
}

Write-Host "==========================================================" -ForegroundColor Green
Write-Host " Launching Pi Coding Agent with NVIDIA NIM (Windows)" -ForegroundColor Green
Write-Host " Model:       $PiModel"
Write-Host " Provider:    nvidia"
Write-Host " Endpoint:    $BaseUrl"
Write-Host "==========================================================" -ForegroundColor Green

& pi --provider nvidia --model $PiModel @PiArgs
