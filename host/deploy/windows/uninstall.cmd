@echo off
rem Odinstalowanie hosta RemoteAppTester (dane zostaja; z -Purge tez dane).
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Uninstall %*
pause
