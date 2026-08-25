@echo off
setlocal EnableExtensions
cd /d "%~dp0"
call build_all_sagetv_ffmpeg_static.bat
exit /b %ERRORLEVEL%
