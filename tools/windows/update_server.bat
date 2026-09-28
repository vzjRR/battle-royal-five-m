@echo off
rem EVENT STUDIO: update the local test server once (double-click). Add -Setup to change the saved paths.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0update_server.ps1" %*
pause
