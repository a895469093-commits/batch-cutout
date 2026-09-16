@echo off
title Batch Cutout - Start
cd /d %~dp0
setlocal EnableDelayedExpansion

echo ============================================
echo   Batch Cutout (portable)
echo   First run: auto setup. Then: instant start.
echo ============================================
echo.

set "PY="

rem ===== [0a] Try system Python =====
python --version >nul 2>&1
if not errorlevel 1 (
  if not exist ".venv\Scripts\python.exe" (
    echo [SETUP] Creating venv + dependencies (1-2 min)...
    python -m venv .venv
    if errorlevel 1 (echo venv failed & pause & exit /b 1)
    ".venv\Scripts\python.exe" -m pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple -q
    if errorlevel 1 (echo pip install failed & pause & exit /b 1)
  )
  set "PY=.venv\Scripts\python.exe"
  goto pyready
)

rem ===== [0b] No system Python: portable runtime =====
echo [SETUP] No system Python. Using portable runtime.
if not exist "runtime\python.exe" (
  echo [SETUP] Downloading portable Python ~15MB, please wait...
  mkdir runtime 2>nul
  curl -sL -o "runtime\py.zip" "https://mirrors.huaweicloud.com/python/3.12.6/python-3.12.6-embed-amd64.zip"
  if errorlevel 1 goto pyfail
  tar -xf "runtime\py.zip" -C runtime
  if errorlevel 1 goto pyfail
  del "runtime\py.zip"
  echo import site>> "runtime\python312._pth"
  curl -sL -o "runtime\get-pip.py" "https://mirrors.aliyun.com/pypi/get-pip.py"
  if errorlevel 1 goto pyfail
  "runtime\python.exe" "runtime\get-pip.py" -i https://pypi.tuna.tsinghua.edu.cn/simple -q
  if errorlevel 1 goto pyfail
)
set "PY=runtime\python.exe"
:pyready
"%PY%" --version
goto pyok
:pyfail
echo.
echo [ERROR] Portable Python download failed.
echo Please install Python 3.10+ manually: https://www.python.org/downloads/
echo (check "Add Python to PATH"), then run this again.
pause
exit /b 1
:pyok

rem ===== [1] Dependencies for portable runtime =====
if "%PY%"=="runtime\python.exe" (
  if not exist "runtime\.deps_done" (
    echo [SETUP] Installing dependencies (1-2 min)...
    "%PY%" -m pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple -q
    if errorlevel 1 (echo pip install failed & pause & exit /b 1)
    echo ok> "runtime\.deps_done"
  )
)

rem ===== [2] cloudflared =====
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

rem ===== [5] Start API =====
if not "%PROXY_FOR_API%"=="" (
  set "HTTPS_PROXY=%PROXY_FOR_API%"
  set "https_proxy=%PROXY_FOR_API%"
  echo [PROXY] GPT API via %PROXY_FOR_API%
)

echo.
echo [START] Cutout service on port 8400...
start "cutout-api" /min "%PY%" -m uvicorn app.main:app --host 0.0.0.0 --port 8400

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
