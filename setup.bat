@echo off
REM ==============================================================================
REM NVIDIA NIM Coding Assistants Windows Setup Launcher
REM ==============================================================================

cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0scripts\windows\install.ps1"
pause
