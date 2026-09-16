@echo off
title Batch Cutout - Stop
echo Stopping...
for /f "tokens=5" %%p in ('netstat -ano ^| findstr ":8400" ^| findstr "LISTENING"') do taskkill /PID %%p /F >nul 2>&1
taskkill /IM cloudflared.exe /F >nul 2>&1
echo Done. Service and tunnel stopped.
pause
