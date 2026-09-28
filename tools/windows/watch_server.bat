@echo off
rem EVENT STUDIO: keep this window open and every change pushed to GitHub is applied to the local server automatically.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0update_server.ps1" -Watch %*
pause
