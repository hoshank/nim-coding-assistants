<#
.SYNOPSIS
  Master Setup & Diagnostics Script for NVIDIA NIM Coding Assistants (Windows)
  Supports Claude Code, Codex CLI, Aider, and Zed Editor.
#>

[CmdletBinding()]
param(
    [switch]$Doctor,
    [switch]$d,
    [switch]$Help,
    [switch]$h
)

$ScriptDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $ScriptDir

$EnvFile = Join-Path $ScriptDir ".env"
$EnvExample = Join-Path $ScriptDir "env.example"
$DotEnvExample = Join-Path $ScriptDir ".env.example"
$VenvDir = Join-Path $ScriptDir ".venv"
$BinDir = Join-Path $env:USERPROFILE ".local\bin"
$ZedConfigDir = Join-Path $env:APPDATA "Zed"
$ZedSettingsFile = Join-Path $ZedConfigDir "settings.json"
$AiderConf = Join-Path $env:USERPROFILE ".aider.conf.yml"

function Show-Banner {
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "          NVIDIA NIM Coding Assistants Setup" -ForegroundColor Cyan
    Write-Host "  Claude Code | Codex CLI | Aider | Zed Editor Integration" -ForegroundColor Cyan
    Write-Host "  Platform: Windows" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Run-Diagnostics {
    Write-Host "--- Running NIM Environment Diagnostics (--doctor) ---" -ForegroundColor Cyan
    Write-Host ""
    $errors = 0

    # 1. Check Python
    $py = Get-Command python -ErrorAction SilentlyContinue
    if ($py) {
        $pyVer = & python --version 2>&1
        Write-Host "  [OK] Python: " -NoNewline
        Write-Host ($pyVer.ToString() + " (" + $py.Source + ")") -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Python: python not found! Install Python 3.10+ (winget install Python.Python.3.12)" -ForegroundColor Red
        $errors++
    }

    # 2. Check Virtualenv & Packages
    $venvPy = Join-Path $VenvDir "Scripts\python.exe"
    if (Test-Path $venvPy) {
        Write-Host "  [OK] Virtualenv: " -NoNewline
        Write-Host "Found at .venv" -ForegroundColor Green

        $pkgCheck = & $venvPy -c "import fastapi, uvicorn, litellm, httpx, dotenv; print('ok')" 2>$null
        if ($pkgCheck -eq "ok") {
            Write-Host "  [OK] Python Dependencies: " -NoNewline
            Write-Host "fastapi, uvicorn, litellm, httpx, dotenv OK" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] Python Dependencies: Missing or broken packages in .venv. Run setup.bat to reinstall." -ForegroundColor Yellow
            $errors++
        }
    } else {
        Write-Host "  [FAIL] Virtualenv: Not initialized (.venv). Run setup.bat to create." -ForegroundColor Yellow
        $errors++
    }

    # 3. Check Claude Code CLI
    $claude = Get-Command claude -ErrorAction SilentlyContinue
    if ($claude) {
        Write-Host "  [OK] Claude Code CLI: " -NoNewline
        Write-Host ("Installed (" + $claude.Source + ")") -ForegroundColor Green
    } else {
        Write-Host "  [!] Claude Code CLI: Not found in PATH." -ForegroundColor Yellow
        Write-Host "      Install with: npm install -g @anthropic-ai/claude-code" -ForegroundColor Cyan
    }

    # 4. Check Codex CLI
    $codex = Get-Command codex -ErrorAction SilentlyContinue
    if ($codex) {
        Write-Host "  [OK] Codex CLI: " -NoNewline
        Write-Host ("Installed (" + $codex.Source + ")") -ForegroundColor Green
    } else {
        Write-Host "  [!] Codex CLI: Not found in PATH." -ForegroundColor Yellow
    }

    # 5. Check Aider CLI
    $aider = Get-Command aider -ErrorAction SilentlyContinue
    $uvx = Get-Command uvx -ErrorAction SilentlyContinue
    if ($aider) {
        Write-Host "  [OK] Aider CLI: " -NoNewline
        Write-Host ("Installed (" + $aider.Source + ")") -ForegroundColor Green
    } elseif ($uvx) {
        Write-Host "  [OK] Aider CLI: " -NoNewline
        Write-Host "Available via uvx" -ForegroundColor Green
    } else {
        Write-Host "  [!] Aider CLI: Not found in PATH." -ForegroundColor Yellow
        Write-Host "      Install with: pip install aider-chat  or  uv tool install --python 3.12 aider-chat" -ForegroundColor Cyan
    }

    # 5b. Check Pi Coding Agent & SoL-Pi Extension
    $pi = Get-Command pi -ErrorAction SilentlyContinue
    if ($pi) {
        $piVer = & pi --version 2>&1
        Write-Host "  [OK] Pi Coding Agent: " -NoNewline
        Write-Host ("Installed v" + $piVer.ToString() + " (" + $pi.Source + ")") -ForegroundColor Green

        $solPiConfig = Join-Path $env:USERPROFILE ".pi\agent\sol-pi.json"
        if (Test-Path $solPiConfig) {
            Write-Host "  [OK] SoL-Pi Extension Config: " -NoNewline
            Write-Host ("Configured for NIM (" + $solPiConfig + ")") -ForegroundColor Green
        } else {
            Write-Host "  [!] SoL-Pi Extension Config: Not configured yet. Run scripts\windows\setup-sol-pi.bat" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [!] Pi Coding Agent: Not found in PATH (optional)." -ForegroundColor Yellow
        Write-Host "      Install with: npm install -g @earendil-works/pi-coding-agent@0.85.1" -ForegroundColor Cyan
    }

    # 6. Check .env and API Key
    if (Test-Path $EnvFile) {
        Write-Host "  [OK] Environment File: " -NoNewline
        Write-Host ".env exists" -ForegroundColor Green

        $key = ""
        Get-Content $EnvFile | ForEach-Object {
            $line = $_.Trim()
            if ($line -match '^NVIDIA_API_KEY=(.*)') {
                $key = $matches[1].Trim('"').Trim("'").Trim()
            }
        }

        if ($key -and $key -ne "nvapi-your-key-here") {
            $maskedKey = if ($key.Length -gt 14) { $key.Substring(0, 10) + "..." + $key.Substring($key.Length - 4) } else { "***" }
            Write-Host "  [OK] NVIDIA API Key: " -NoNewline
            Write-Host ("Configured (" + $maskedKey + ")") -ForegroundColor Green

            # Live API validation check
            Write-Host "      Verifying API Key with NVIDIA Cloud API... " -NoNewline
            try {
                $headers = @{ "Authorization" = "Bearer $key" }
                $response = Invoke-WebRequest -Uri "https://integrate.api.nvidia.com/v1/models" -Headers $headers -Method Get -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
                if ($response.StatusCode -eq 200) {
                    Write-Host "Active and Valid (HTTP 200)" -ForegroundColor Green
                } else {
                    Write-Host ("Endpoint returned HTTP " + $response.StatusCode) -ForegroundColor Yellow
                }
            } catch {
                Write-Host ("Validation note: " + $_.Exception.Message) -ForegroundColor Yellow
            }
        } else {
            Write-Host "  [FAIL] NVIDIA API Key: Placeholder or empty in .env" -ForegroundColor Red
            $errors++
        }
    } else {
        Write-Host "  [FAIL] Environment File: .env missing! Run setup.bat to configure." -ForegroundColor Red
        $errors++
    }

    # 7. Check Global CLI Launchers
    $claudeCmd = Join-Path $BinDir "claude-nim.cmd"
    $codexCmd = Join-Path $BinDir "codex-nim.cmd"
    $aiderCmd = Join-Path $BinDir "aider-nim.cmd"
    $piCmd = Join-Path $BinDir "pi-nim.cmd"
    if ((Test-Path $claudeCmd) -and (Test-Path $codexCmd) -and (Test-Path $aiderCmd) -and (Test-Path $piCmd)) {
        Write-Host "  [OK] Global CLI Launchers: " -NoNewline
        Write-Host ("Installed in " + $BinDir + " (claude-nim, codex-nim, aider-nim, pi-nim)") -ForegroundColor Green
    } else {
        Write-Host "  [!] Global CLI Launchers: Incomplete in $BinDir" -ForegroundColor Yellow
    }

    # Check User PATH for $BinDir
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -like "*$BinDir*") {
        Write-Host "  [OK] User PATH: " -NoNewline
        Write-Host ("$BinDir is in PATH") -ForegroundColor Green
    } else {
        Write-Host "  [!] User PATH: $BinDir is not yet in User PATH" -ForegroundColor Yellow
    }

    # 8. Check Zed Editor
    $zed = Get-Command zed -ErrorAction SilentlyContinue
    if ($zed -or (Test-Path $ZedConfigDir)) {
        if ((Test-Path $ZedSettingsFile) -and (Select-String -Path $ZedSettingsFile -Pattern '"Nvidia"' -Quiet -ErrorAction SilentlyContinue)) {
            Write-Host "  [OK] Zed Editor: " -NoNewline
            Write-Host ("Detected and configured for NVIDIA NIM (" + $ZedSettingsFile + ")") -ForegroundColor Green
        } else {
            Write-Host "  [!] Zed Editor: Detected, but NIM settings not yet configured." -ForegroundColor Yellow
            Write-Host "      Run: scripts\windows\setup-zed.bat" -ForegroundColor Cyan
        }
    }

    # 9. Check Aider Global Config
    if (Test-Path $AiderConf) {
        Write-Host "  [OK] Aider Global Config: " -NoNewline
        Write-Host ("Found at " + $AiderConf) -ForegroundColor Green
    } else {
        Write-Host "  [!] Aider Global Config: Not configured yet. Run scripts\windows\setup-aider.bat" -ForegroundColor Yellow
    }

    Write-Host ""
    if ($errors -eq 0) {
        Write-Host "All critical checks passed! You are ready to run claude-nim, codex-nim, and aider-nim." -ForegroundColor Green
    } else {
        Write-Host ("Found " + $errors + " item(s) to configure or resolve.") -ForegroundColor Yellow
    }
    Write-Host ""
}

if ($Doctor -or $d) {
    Show-Banner
    Run-Diagnostics
    exit 0
}

if ($Help -or $h) {
    Write-Host "Usage:"
    Write-Host "  setup.bat           Run interactive setup and update on Windows"
    Write-Host "  setup.bat -Doctor   Run diagnostic health checks"
    Write-Host "  setup.bat -Help     Show this help message"
    exit 0
}

Show-Banner

# ------------------------------------------------------------------------------
# 1. Check Python 3
# ------------------------------------------------------------------------------
Write-Host "-> Step 1: Checking Python 3..." -ForegroundColor Cyan
$pythonInstalled = Get-Command python -ErrorAction SilentlyContinue
$pyWorks = if ($pythonInstalled) { try { & python -c "import sys" 2>$null; $LASTEXITCODE -eq 0 } catch { $false } } else { $false }
if (-not $pyWorks) {
    Write-Error "Python 3 is not found or not functional (Windows execution alias may be unconfigured). Please install Python 3.10+ (e.g. 'winget install Python.Python.3.12') and restart your terminal."
    exit 1
}
$pyVer = & python --version 2>&1
Write-Host ("[OK] Python 3 found: " + $pyVer) -ForegroundColor Green
Write-Host ""

# ------------------------------------------------------------------------------
# 2. Setup Virtual Environment & Dependencies
# ------------------------------------------------------------------------------
Write-Host "-> Step 2: Setting up Python virtual environment and dependencies..." -ForegroundColor Cyan
if (-not (Test-Path $VenvDir)) {
    Write-Host "  Creating virtual environment in .venv..." -ForegroundColor Cyan
    python -m venv .venv
}

$venvPip = Join-Path $VenvDir "Scripts\pip.exe"
Write-Host "  Installing required Python packages (fastapi, uvicorn, litellm, httpx, dotenv)..." -ForegroundColor Cyan
& $venvPip install --upgrade pip -q
& $venvPip install -r requirements.txt -q
Write-Host "[OK] Python virtual environment and dependencies ready." -ForegroundColor Green
Write-Host ""

# ------------------------------------------------------------------------------
# 3. Configure .env & Safe API Key Prompt
# ------------------------------------------------------------------------------
Write-Host "-> Step 3: Configuring Environment and API Key..." -ForegroundColor Cyan
if (-not (Test-Path $EnvFile)) {
    if (Test-Path $EnvExample) {
        Copy-Item $EnvExample $EnvFile
    } elseif (Test-Path $DotEnvExample) {
        Copy-Item $DotEnvExample $EnvFile
    }
}

$currentKey = ""
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -match '^NVIDIA_API_KEY=(.*)') {
            $currentKey = $matches[1].Trim('"').Trim("'").Trim()
        }
    }
}

if (-not $currentKey -or $currentKey -eq "nvapi-your-key-here") {
    Write-Host "----------------------------------------------------------" -ForegroundColor Yellow
    Write-Host " NVIDIA NIM API Key Required" -ForegroundColor Yellow
    Write-Host " Get your free key at: https://build.nvidia.com/" -ForegroundColor Yellow
    Write-Host "----------------------------------------------------------" -ForegroundColor Yellow
    $secureKey = Read-Host -AsSecureString "Paste your NVIDIA API Key (nvapi-...)"
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
    $plainKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)

    if ($plainKey) {
        if (Test-Path $EnvFile) {
            (Get-Content $EnvFile) -replace '^NVIDIA_API_KEY=.*', "NVIDIA_API_KEY=$plainKey" | Set-Content $EnvFile -Encoding UTF8
        } else {
            $defEnv = @(
                "# NVIDIA NIM Configuration",
                "NVIDIA_API_KEY=`"$plainKey`"",
                "NIM_BASE_URL=`"https://integrate.api.nvidia.com/v1`"",
                "NIM_MODEL=`"nvidia/nemotron-3-ultra-550b-a55b`"",
                "NIM_PROXY_PORT=`"8000`""
            ) -join "`r`n"
            Set-Content -Path $EnvFile -Value $defEnv -Encoding UTF8
        }
        Write-Host "[OK] NVIDIA API Key saved to .env" -ForegroundColor Green
    } else {
        Write-Host "[!] No key entered. You can add it later to .env." -ForegroundColor Yellow
    }
} else {
    Write-Host "[OK] NVIDIA API Key is already configured in .env." -ForegroundColor Green
}
Write-Host ""

# ------------------------------------------------------------------------------
# 4. Create Global CMD Launchers
# ------------------------------------------------------------------------------
Write-Host "-> Step 4: Creating global CLI launchers..." -ForegroundColor Cyan
if (-not (Test-Path $BinDir)) {
    New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
}

$claudeCmd = Join-Path $BinDir "claude-nim.cmd"
$codexCmd = Join-Path $BinDir "codex-nim.cmd"
$aiderCmd = Join-Path $BinDir "aider-nim.cmd"
$piCmd = Join-Path $BinDir "pi-nim.cmd"

$psClaude = Join-Path $ScriptDir "scripts\windows\claude-nim.ps1"
$psCodex = Join-Path $ScriptDir "scripts\windows\codex-nim.ps1"
$psAider = Join-Path $ScriptDir "scripts\windows\aider-nim.ps1"
$psPi = Join-Path $ScriptDir "scripts\windows\pi-nim.ps1"

$cmdClaudeText = "@echo off`r`npowershell -ExecutionPolicy Bypass -File `"$psClaude`" %*"
$cmdCodexText = "@echo off`r`npowershell -ExecutionPolicy Bypass -File `"$psCodex`" %*"
$cmdAiderText = "@echo off`r`npowershell -ExecutionPolicy Bypass -File `"$psAider`" %*"
$cmdPiText = "@echo off`r`npowershell -ExecutionPolicy Bypass -File `"$psPi`" %*"

Set-Content -Path $claudeCmd -Value $cmdClaudeText -Encoding ASCII
Set-Content -Path $codexCmd -Value $cmdCodexText -Encoding ASCII
Set-Content -Path $aiderCmd -Value $cmdAiderText -Encoding ASCII
Set-Content -Path $piCmd -Value $cmdPiText -Encoding ASCII

Write-Host ("[OK] Created launchers in " + $BinDir + ":") -ForegroundColor Green
Write-Host "  * claude-nim.cmd -> Run Claude Code with NVIDIA NIM Bridge"
Write-Host "  * codex-nim.cmd  -> Run Codex CLI with NVIDIA NIM"
Write-Host "  * aider-nim.cmd  -> Run Aider Pair Programmer with NVIDIA NIM"
Write-Host "  * pi-nim.cmd     -> Run Pi Coding Agent & SoL-Pi with NVIDIA NIM"
Write-Host ""

# ------------------------------------------------------------------------------
# 5. Check and Add to User PATH
# ------------------------------------------------------------------------------
Write-Host "-> Step 5: Checking User PATH..." -ForegroundColor Cyan
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$BinDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$BinDir", "User")
    Write-Host ("[OK] Added " + $BinDir + " to User PATH.") -ForegroundColor Green
} else {
    Write-Host ("[OK] " + $BinDir + " is already in User PATH.") -ForegroundColor Green
}
Write-Host ""

# ------------------------------------------------------------------------------
# 6. Configure Aider for NVIDIA NIM
# ------------------------------------------------------------------------------
Write-Host "-> Step 6: Configuring Aider Global Settings..." -ForegroundColor Cyan
$setupAiderPs1 = Join-Path $ScriptDir "scripts\windows\setup-aider.ps1"
if (Test-Path $setupAiderPs1) {
    & powershell -ExecutionPolicy Bypass -File $setupAiderPs1
}
Write-Host ""

# ------------------------------------------------------------------------------
# 7. Configure Zed Editor if Installed
# ------------------------------------------------------------------------------
Write-Host "-> Step 7: Checking Zed Editor Integration..." -ForegroundColor Cyan
$zed = Get-Command zed -ErrorAction SilentlyContinue
if ($zed -or (Test-Path $ZedConfigDir)) {
    $setupZedPs1 = Join-Path $ScriptDir "scripts\windows\setup-zed.ps1"
    if (Test-Path $setupZedPs1) {
        & powershell -ExecutionPolicy Bypass -File $setupZedPs1
    }
} else {
    Write-Host "Zed Editor not detected. Run scripts\windows\setup-zed.bat anytime if you install Zed." -ForegroundColor Yellow
}
Write-Host ""

# ------------------------------------------------------------------------------
# 8. Configure Pi Coding Agent & SoL-Pi if Installed
# ------------------------------------------------------------------------------
Write-Host "-> Step 8: Checking Pi Coding Agent & SoL-Pi Integration..." -ForegroundColor Cyan
$piInstalled = Get-Command pi -ErrorAction SilentlyContinue
if ($piInstalled) {
    $setupSolPiPs1 = Join-Path $ScriptDir "scripts\windows\setup-sol-pi.ps1"
    if (Test-Path $setupSolPiPs1) {
        & powershell -ExecutionPolicy Bypass -File $setupSolPiPs1
    }
} else {
    Write-Host "Pi Coding Agent not detected (optional). Install with: npm install -g @earendil-works/pi-coding-agent@0.85.1" -ForegroundColor Yellow
}
Write-Host ""

# ------------------------------------------------------------------------------
# 9. Diagnostics Summary
# ------------------------------------------------------------------------------
Run-Diagnostics

Write-Host "==========================================================" -ForegroundColor Green
Write-Host " Installation and Update Complete on Windows!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "You can now run:"
Write-Host "  claude-nim             Start Claude Code with NVIDIA NIM bridge" -ForegroundColor Cyan
Write-Host "  codex-nim              Start Codex CLI with NVIDIA NIM" -ForegroundColor Cyan
Write-Host "  aider-nim              Start Aider with interactive dropdown and Architect mode" -ForegroundColor Cyan
Write-Host "  pi-nim                 Start Pi Coding Agent with NVIDIA NIM & SoL-Pi" -ForegroundColor Cyan
Write-Host "  setup.bat -Doctor      Run diagnostic health checks on this machine" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Green
