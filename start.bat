@echo off
chcp 65001 >nul
title 批量抠图服务
cd /d %~dp0
if not exist .env (
  echo 未找到 .env,请先复制 .env.example 为 .env 并填入 APIMART_API_KEY
  pause
  exit /b
)
for /f "usebackq tokens=1,* delims==" %%a in (".env") do set %%a=%%b
echo 服务启动中: http://localhost:8400
uvicorn app.main:app --host 0.0.0.0 --port 8400
pause
