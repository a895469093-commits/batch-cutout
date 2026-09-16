@echo off
title Batch Cutout - Start
cd /d %~dp0
setlocal EnableDelayedExpansion

echo ============================================
echo   Batch Cutout (portable)
echo   First run: auto setup. Then: instant start.
echo ============================================
echo.

rem ===== [0] Check Python =====
python --version >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Python not found.
  echo Install Python 3.10+ from https://www.python.org/downloads/
  echo Remember to check "Add Python to PATH" during install.
  pause
  exit /b 1
)

rem ===== [1] First run: venv + deps =====
if not exist ".venv\Scripts\python.exe" (
  echo [SETUP] Creating Python virtual env...
  python -m venv .venv
  if errorlevel 1 (echo venv failed & pause & exit /b 1)
  echo [SETUP] Installing dependencies via mirror, 1-2 min...
  ".venv\Scripts\python.exe" -m pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple -q
  if errorlevel 1 (echo pip install failed, check network & pause & exit /b 1)
)

rem ===== [2] First run: cloudflared =====
if not exist "tools\cloudflared.exe" (
  echo [SETUP] Downloading cloudflared...
  mkdir tools 2>nul
  curl -sL -o "tools\cloudflared.exe" "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
  "tools\cloudflared.exe" --version >nul 2>&1
  if errorlevel 1 (
    echo Download failed. Get it manually into tools\ folder:
    echo https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe
    pause
    exit /b 1
  )
)

rem ===== [3] First run: ask for API key =====
if not exist ".env" (
  echo [SETUP] Config - paste your apimart.ai API Key:
  set "APIKEY="
  set /p "APIKEY=> "
  if "!APIKEY!"=="" (echo empty key, exit & pause & exit /b 1)
  echo.
  echo Does this PC need a local proxy to reach the GPT API?
  echo   No proxy / direct: press Enter
  echo   Clash user: type  http://127.0.0.1:7897
  set "PROXYV="
  set /p "PROXYV=> "
  (
    echo APIMART_API_KEY=!APIKEY!
    echo PROXY_FOR_API=!PROXYV!
  ) > .env
  echo Saved to .env
)

rem ===== [4] Read config =====
set "APIMART_API_KEY="
set "PROXY_FOR_API="
for /f "usebackq tokens=1,* delims==" %%a in (".env") do set "%%a=%%b"
if "%APIMART_API_KEY%"=="" (echo .env missing APIMART_API_KEY & pause & exit /b 1)

rem ===== [5] Start API (optional proxy for GPT calls) =====
if not "%PROXY_FOR_API%"=="" (
  set "HTTPS_PROXY=%PROXY_FOR_API%"
  set "https_proxy=%PROXY_FOR_API%"
  echo [PROXY] GPT API via %PROXY_FOR_API%
)

echo.
echo [START] Cutout service on port 8400...
start "cutout-api" /min ".venv\Scripts\python.exe" -m uvicorn app.main:app --host 0.0.0.0 --port 8400

set /a n=0
:waitloop
timeout /t 1 /nobreak >nul
curl -s -o nul http://127.0.0.1:8400/ && goto ready
set /a n+=1
if %n% lss 30 goto waitloop
echo [ERROR] service failed to start & pause & exit /b 1
:ready
echo        Local ready: http://127.0.0.1:8400
echo.
echo [START] Public tunnel. The https://xxx.trycloudflare.com URL below
echo is the public address - send it to your team.
echo If it never connects: disable TUN mode in your proxy software and retry.
echo.
"tools\cloudflared.exe" tunnel --protocol http2 --edge-ip-version 4 --url http://127.0.0.1:8400
pause
