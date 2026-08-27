@echo off
setlocal EnableExtensions
cd /d "%~dp0"
where wsl.exe >nul 2>&1
if errorlevel 1 (
  echo ERROR: WSL is required.
  exit /b 1
)
for /f "delims=" %%I in ('wsl.exe wslpath -a "%CD%"') do set "WSLROOT=%%I"
wsl.exe bash -lc "cd '%WSLROOT%' && chmod +x *.sh code/docker/*.sh code/mim/tests/*.sh && ./build_opensagetv_vibe_builder_image.sh"
exit /b %ERRORLEVEL%
