@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install\install.ps1"
exit /b %ERRORLEVEL%
