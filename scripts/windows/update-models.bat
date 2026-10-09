@echo off
setlocal
set "SCRIPT_DIR=%~dp0..\.."
cd /d "%SCRIPT_DIR%"

set "PYTHON_BIN=python"
if exist "%SCRIPT_DIR%\.venv\Scripts\python.exe" (
    set "PYTHON_BIN=%SCRIPT_DIR%\.venv\Scripts\python.exe"
)

"%PYTHON_BIN%" "%SCRIPT_DIR%\scripts\update_models.py" %*
endlocal
