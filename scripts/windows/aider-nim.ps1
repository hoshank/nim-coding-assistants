<#
.SYNOPSIS
  Launch Aider with NVIDIA NIM on Windows (PowerShell)
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
$DefaultEditorModel = "nvidia/nemotron-3-super-120b-a12b"
$Model = $DefaultModel
$EditorModel = $DefaultEditorModel
$ApiKey = if ($env:NVIDIA_API_KEY) { $env:NVIDIA_API_KEY } else { $EnvMap["NVIDIA_API_KEY"] }
$BaseUrl = if ($EnvMap["NIM_BASE_URL"]) { $EnvMap["NIM_BASE_URL"] } else { "https://integrate.api.nvidia.com/v1" }
$Effort = if ($EnvMap["NIM_EFFORT"]) { $EnvMap["NIM_EFFORT"] } else { "medium" }
$UseArchitect = $false
$AutoCommits = $true
$EditFormat = $null

# Run interactive mode by default if user simply types `aider-nim` with no args
$RunInteractive = ($args.Count -eq 0)

# Parse arguments
$AiderArgs = @()
$ChooseModel = $false
$i = 0
while ($i -lt $args.Count) {
    $arg = $args[$i]
    switch ($arg) {
        "--help" {
            Write-Host "Aider with NVIDIA NIM (Windows)" -ForegroundColor Cyan
            Write-Host "Usage: aider-nim [options] [aider options...]"
            Write-Host "Options:"
            Write-Host "  --model, -m <name>       Specify primary model (default: nvidia/nemotron-3-ultra-550b-a55b)"
            Write-Host "  --interactive, -i        Run interactive TUI dropdown setup menu"
            Write-Host "  --yes, -y                Run non-interactively with default options"
            Write-Host "  --choose, -c             Interactively choose model and mode from the NIM catalog"
            Write-Host "  --architect, -A          Run in Architect mode (Ultra plans, Super 120B edits)"
            Write-Host "  --editor-model <name>    Specify editor model for architect mode"
            Write-Host "  --effort, -e <level>     Specify reasoning effort (low, medium, high)"
            Write-Host "  --edit-format <format>   Specify edit format (diff, whole, udiff)"
            Write-Host "  --no-auto-commits        Disable automatic git commits"
            Write-Host "  --key <key>              Set NVIDIA API Key"
            Write-Host "  --url <url>              Set NVIDIA Base URL"
            exit 0
        }
        "-h" {
            Write-Host "Aider with NVIDIA NIM (Windows)" -ForegroundColor Cyan
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
        "--architect" {
            $UseArchitect = $true
        }
        "-A" {
            $UseArchitect = $true
        }
        "--editor-model" {
            $i++; $EditorModel = $args[$i]
        }
        "--effort" {
            $i++; $Effort = $args[$i]
        }
        "-e" {
            $i++; $Effort = $args[$i]
        }
        "--edit-format" {
            $i++; $EditFormat = $args[$i]
        }
        "--no-auto-commits" {
            $AutoCommits = $false
        }
        "--key" {
            $i++; $ApiKey = $args[$i]
        }
        "--url" {
            $i++; $BaseUrl = $args[$i]
        }
        default {
            $AiderArgs += $arg
        }
    }
    $i++
}

# Run interactive TUI dropdown selection if requested
if ($RunInteractive -or $ChooseModel) {
    $VenvPython = Join-Path $ScriptDir ".venv\Scripts\python.exe"
    $PythonExe = if (Test-Path $VenvPython) { $VenvPython } else { "python" }
    $InteractiveScript = Join-Path $ScriptDir "scripts\interactive_menu.py"
    $TmpConfig = [System.IO.Path]::GetTempFileName()

    if (Test-Path $InteractiveScript) {
        & $PythonExe $InteractiveScript --app aider --output $TmpConfig
        if ($LASTEXITCODE -eq 0 -and (Test-Path $TmpConfig)) {
            Get-Content $TmpConfig | ForEach-Object {
                $line = $_.Trim()
                if ($line.StartsWith("MODEL=")) {
                    $Model = $line.Substring(6).Trim('"')
                }
                elseif ($line.StartsWith("EFFORT=")) {
                    $Effort = $line.Substring(7).Trim('"')
                }
                elseif ($line.StartsWith("AIDER_MODE=")) {
                    $mVal = $line.Substring(11).Trim('"')
                    if ($mVal -eq "architect") { $UseArchitect = $true }
                }
                elseif ($line.StartsWith("AIDER_AUTO_COMMITS=")) {
                    $acVal = $line.Substring(19).Trim('"')
                    if ($acVal -eq "false") { $AutoCommits = $false }
                }
            }
            Remove-Item $TmpConfig -Force -ErrorAction SilentlyContinue
        } else {
            Remove-Item $TmpConfig -Force -ErrorAction SilentlyContinue
            exit 130
        }
    }
}

# Ensure API Key
if (-not $ApiKey -or $ApiKey -eq "nvapi-your-key-here") {
    Write-Host "==========================================================" -ForegroundColor Yellow
    Write-Host " NVIDIA NIM API Key Required" -ForegroundColor Yellow
    Write-Host " Get your key from: https://build.nvidia.com/" -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Yellow
    $ApiKey = Read-Host -AsSecureString "Enter your NVIDIA API Key (nvapi-...)"
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ApiKey)
    $ApiKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    if (-not $ApiKey) {
        Write-Host "Error: NVIDIA API Key is required." -ForegroundColor Red
        exit 1
    }
}

# Prefix model names
$PrefixedModel = if ($Model.StartsWith("openai/") -or $Model.StartsWith("nvidia_nim/")) { $Model } else { "openai/$Model" }
$PrefixedEditorModel = if ($EditorModel.StartsWith("openai/") -or $EditorModel.StartsWith("nvidia_nim/")) { $EditorModel } else { "openai/$EditorModel" }

# Export environment variables
$env:NVIDIA_API_KEY = $ApiKey
$env:NVIDIA_NIM_API_KEY = $ApiKey
$env:OPENAI_API_KEY = $ApiKey
$env:OPENAI_API_BASE = $BaseUrl
$env:AIDER_MODEL = $PrefixedModel

$SettingsFile = Join-Path $ScriptDir "config\aider.model.settings.yml"
$MetadataFile = Join-Path $ScriptDir "config\aider.model.metadata.json"

$ConfigArgs = @(
    "--model", $PrefixedModel,
    "--openai-api-base", $BaseUrl,
    "--no-show-model-warnings"
)

if (Test-Path $SettingsFile) {
    $ConfigArgs += @("--model-settings-file", $SettingsFile)
}

if (Test-Path $MetadataFile) {
    $ConfigArgs += @("--model-metadata-file", $MetadataFile)
}

if ($EditFormat) {
    $ConfigArgs += @("--edit-format", $EditFormat)
}

if ($UseArchitect) {
    $ConfigArgs += @(
        "--architect",
        "--editor-model", $PrefixedEditorModel,
        "--editor-edit-format", "editor-diff"
    )
}

if (-not $AutoCommits) {
    $ConfigArgs += "--no-auto-commits"
}

if ($Effort) {
    $ConfigArgs += @("--reasoning-effort", $Effort)
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Launching Aider with NVIDIA NIM" -ForegroundColor Cyan
Write-Host " Model:       $PrefixedModel"
if ($UseArchitect) {
    Write-Host " Editor:      $PrefixedEditorModel"
    Write-Host " Mode:        Architect Mode"
} else {
    Write-Host " Mode:        Standard Pair Programming (Diff format)"
}
Write-Host " Effort:      $Effort"
Write-Host " Endpoint:    $BaseUrl"
Write-Host "==========================================================" -ForegroundColor Cyan

& aider @ConfigArgs @AiderArgs
