@echo off
rem Stock Brain one-click launcher: starts API server if needed, then opens the web UI.
cd /d "%~dp0"
if not exist logs mkdir logs

curl -s -m 2 http://127.0.0.1:8787/api/health >nul 2>&1
if %errorlevel%==0 goto open

echo Starting Stock Brain server (first time takes a few seconds)...
start "stock-brain server" /min cmd /c "npx tsx server/index.ts >> logs\server.log 2>&1"

:wait
ping -n 3 127.0.0.1 >nul
curl -s -m 2 http://127.0.0.1:8787/api/health >nul 2>&1
if not %errorlevel%==0 goto wait

:open
start "" http://127.0.0.1:8787/
echo Stock Brain is running at http://127.0.0.1:8787 (server window minimized; closing it stops the app)
ping -n 4 127.0.0.1 >nul
exit
