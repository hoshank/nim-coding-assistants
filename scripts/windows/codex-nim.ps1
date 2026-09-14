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

# Run interactive mode by default if user simply types `codex-nim` with no args
$RunInteractive = ($args.Count -eq 0)

# Parse arguments
$CodexArgs = @()
$Profile = $null
$ChooseModel = $false
$i = 0
while ($i -lt $args.Count) {
    $arg = $args[$i]
    switch ($arg) {
        "--help" {
            Write-Host "Codex CLI with NVIDIA NIM (Windows)" -ForegroundColor Cyan
            Write-Host "Usage: codex-nim [options] [codex options...]"
            Write-Host "Options:"
            Write-Host "  --model, -m <name>   Specify the model (default: nvidia/nemotron-3-ultra-550b-a55b)"
            Write-Host "  --interactive, -i    Run interactive TUI dropdown setup menu"
            Write-Host "  --yes, -y            Run non-interactively with default options"
            Write-Host "  --choose, -c         Interactively choose a model from the supported NIM catalog"
            Write-Host "  --profile, -p <name> Specify profile name (built-ins: danger-full-access, workspace-write, read-only)"
            Write-Host "  --key <key>          Set NVIDIA API Key"
            Write-Host "  --url <url>          Set NVIDIA Base URL"
            Write-Host ""
            Write-Host "Permission & Sandbox Shortcuts:"
            Write-Host "  -p danger-full-access                          Skip sandboxing and permissions via full-access profile"
            Write-Host "  --dangerously-bypass-approvals-and-sandbox     Bypass all approval prompts and sandboxing"
            Write-Host "  -a never                                       Never ask for approval before executing commands"
            exit 0
        }
        "-h" {
            Write-Host "Codex CLI with NVIDIA NIM (Windows)" -ForegroundColor Cyan
            exit 0
        }
        "--interactive" {
            $RunInteractive = $true
        }
        "-i" {
            $RunInteractive = $true
        }
        "--yes" {
            $RunInteractive = $false
        }
        "-y" {
            $RunInteractive = $false
        }
        "--quick" {
            $RunInteractive = $false
        }
        "--model" {
            $i++; $Model = $args[$i]
        }
        "-m" {
            $i++; $Model = $args[$i]
        }
        "--choose" {
            $ChooseModel = $true
        }
        "-c" {
            $ChooseModel = $true
        }
        "--profile" {
            $i++; $Profile = $args[$i]
            $CodexArgs += @("-p", $Profile)
        }
        "-p" {
            $i++; $Profile = $args[$i]
            $CodexArgs += @("-p", $Profile)
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

if ($RunInteractive -or $ChooseModel) {
    $ConfigTmp = [System.IO.Path]::GetTempFileName()
    & $PythonBin (Join-Path $ScriptDir "scripts\interactive_menu.py") --app codex --output $ConfigTmp
    if ($LASTEXITCODE -eq 0 -and (Test-Path $ConfigTmp)) {
        Get-Content $ConfigTmp | ForEach-Object {
            $line = $_.Trim()
            if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
                $parts = $line.Split("=", 2)
                $k = $parts[0].Trim()
                $v = $parts[1].Trim().Trim('"').Trim("'")
                if ($k -eq "MODEL" -and $v) { $Model = $v }
                if ($k -eq "PROFILE" -and $v) {
                    $Profile = $v
                    $CodexArgs += @("-p", $Profile)
                }
                if ($k -eq "EFFORT" -and $v) { $Effort = $v }
                if ($k -eq "CODEX_PERM_FLAGS" -and $v) {
                    $CodexArgs += $v.Split(" ")
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
Write-Host " Model:       $Model"
if ($Profile) {
    Write-Host " Profile:     $Profile" -ForegroundColor Cyan
} else {
    Write-Host " Profile:     default"
}
$permDisplay = "Standard manual confirmation prompts"
foreach ($a in $CodexArgs) {
    if ($a -like "*--dangerously-bypass-approvals-and-sandbox*") {
        $permDisplay = "--dangerously-bypass-approvals-and-sandbox (full bypass)"
        break
    } elseif ($a -eq "never") {
        $permDisplay = "-a never (auto-approved commands)"
        break
    } elseif ($a -like "*--approve-for-me*") {
        $permDisplay = "--approve-for-me (workspace review)"
        break
    }
}
Write-Host " Permissions: $permDisplay" -ForegroundColor Yellow
Write-Host " Endpoint:    $BaseUrl"
Write-Host " Provider:    nvidia_nim"
Write-Host "==========================================================" -ForegroundColor Green

& codex @NimConfigArgs @CodexArgs

