@echo off
rem Double-click to install (Windows).
cd /d "%~dp0"
where node >nul 2>nul || (echo Install Node.js first from https://nodejs.org then run this again. & pause & exit /b 1)
call npm install --omit=dev && node setup.js
pause
