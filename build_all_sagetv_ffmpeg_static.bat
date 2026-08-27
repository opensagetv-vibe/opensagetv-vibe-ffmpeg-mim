@echo off
setlocal EnableExtensions
cd /d "%~dp0"
set "DEV=%~dp0..\opensagetv-vibe-build-env\opensagetv-vibe-dev.ps1"
if not exist "%DEV%" (
  echo ERROR: Unified build wrapper not found: %DEV%
  echo Check out opensagetv-vibe-build-env beside this repository.
  exit /b 1
)
echo Building Windows x64 in the reusable opensagetv-vibe-dev container...
powershell -NoProfile -ExecutionPolicy Bypass -File "%DEV%" ffmpeg-windows
exit /b %ERRORLEVEL%
