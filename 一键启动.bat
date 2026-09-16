@echo off
chcp 65001 >nul
title 批量抠图 - 一键启动
cd /d %~dp0

echo ============================================
echo   批量抠图 一键启动
echo   前提: Clash 保持运行(端口7897) 但关闭 TUN/系统代理
echo ============================================
echo.

rem ---- 读取 .env 里的 key ----
if not exist .env (
  echo [错误] 找不到 .env,请先复制 .env.example 为 .env 并填入 APIMART_API_KEY
  pause
  exit /b 1
)
set APIMART_API_KEY=
for /f "usebackq tokens=1,* delims==" %%a in (".env") do set %%a=%%b
if "%APIMART_API_KEY%"=="" (
  echo [错误] .env 里没有 APIMART_API_KEY
  pause
  exit /b 1
)

rem ---- 抠图服务走代理(调GPT用),隧道走直连 ----
set HTTPS_PROXY=http://127.0.0.1:7897
set https_proxy=http://127.0.0.1:7897

echo [1/2] 启动抠图服务 (端口8400)...
start "cutout-api" /min python -m uvicorn app.main:app --host 0.0.0.0 --port 8400

rem ---- 等服务就绪 ----
set /a n=0
:waitloop
timeout /t 1 /nobreak >nul
curl -s -o nul http://127.0.0.1:8400/ && goto ready
set /a n+=1
if %n% lss 30 goto waitloop
echo [错误] 服务启动失败,请检查 python 和依赖 (pip install -r requirements.txt)
pause
exit /b 1
:ready
echo       服务已就绪: http://127.0.0.1:8400
echo.
echo [2/2] 启动外网隧道,下面的地址就是给同事用的公网网址:
echo.
C:\tools\cloudflared.exe tunnel --protocol http2 --edge-ip-version 4 --url http://127.0.0.1:8400
