@echo off
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0setup-sol-pi.ps1" %*
pause
