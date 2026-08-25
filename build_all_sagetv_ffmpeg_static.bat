@echo off
setlocal EnableExtensions
cd /d "%~dp0"

where wsl.exe >nul 2>&1
if errorlevel 1 (
  echo ERROR: WSL is required. Docker Desktop WSL integration must also be enabled.
  exit /b 1
)

for /f "delims=" %%I in ('wsl.exe wslpath -a "%CD%"') do set "WSLROOT=%%I"
if not defined WSLROOT (
  echo ERROR: Could not convert project path to WSL path.
  exit /b 1
)

echo Building Windows x64 only using the unified SageTV Docker builder...
wsl.exe bash -lc "cd '%WSLROOT%' && chmod +x *.sh code/docker/*.sh code/mim/tests/*.sh code/tools/*.py && ./build_windows_sagetv_ffmpeg_static.sh"
exit /b %ERRORLEVEL%
