@echo off
rem Instalator hosta RemoteAppTester (Windows) - uruchamia install.ps1 obok tego pliku.
rem Parametry przekazywane dalej, np.: install.cmd -ProjectsRoot D:\Dev\Projects
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
set RT_EXIT=%ERRORLEVEL%
echo.
pause
exit /b %RT_EXIT%
