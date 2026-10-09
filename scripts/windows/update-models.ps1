# PowerShell wrapper for scripts/update_models.py
$ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $ScriptDir

$PythonBin = "python"
if (Test-Path "$ScriptDir\.venv\Scripts\python.exe") {
    $PythonBin = "$ScriptDir\.venv\Scripts\python.exe"
}

& $PythonBin "$ScriptDir\scripts\update_models.py" $args
