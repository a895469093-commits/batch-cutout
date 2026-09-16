@echo off
chcp 65001 >nul
title 批量抠图 - 停止服务
echo 正在停止...
for /f "tokens=5" %%p in ('netstat -ano ^| findstr ":8400" ^| findstr "LISTENING"') do taskkill /PID %%p /F >nul 2>&1
taskkill /IM cloudflared.exe /F >nul 2>&1
echo 已停止抠图服务和隧道。
pause
