@echo off
chcp 65001 >nul
title 批量抠图 - 一键启动
cd /d %~dp0
setlocal EnableDelayedExpansion

echo ============================================
echo   批量抠图 便携版
echo   首次运行自动安装环境,之后秒开
echo ============================================
echo.

rem ========== [0] 检查 Python ==========
python --version >nul 2>&1
if errorlevel 1 (
  echo [错误] 这台电脑没有安装 Python。
  echo 请先安装 Python 3.10 以上: https://www.python.org/downloads/
  echo 安装时务必勾选 "Add Python to PATH"
  pause
  exit /b 1
)

rem ========== [1] 首次:创建虚拟环境+装依赖 ==========
if not exist ".venv\Scripts\python.exe" (
  echo [首次] 创建 Python 虚拟环境...
  python -m venv .venv
  if errorlevel 1 (echo 创建虚拟环境失败 & pause & exit /b 1)
  echo [首次] 安装依赖(清华镜像,约1-2分钟)...
  ".venv\Scripts\python.exe" -m pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple -q
  if errorlevel 1 (echo 依赖安装失败,检查网络 & pause & exit /b 1)
)

rem ========== [2] 首次:下载隧道工具 ==========
if not exist "tools\cloudflared.exe" (
  echo [首次] 下载隧道工具 cloudflared...
  mkdir tools 2>nul
  curl -sL -o "tools\cloudflared.exe" "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
  "tools\cloudflared.exe" --version >nul 2>&1
  if errorlevel 1 (
    echo 下载失败。请手动下载后放到 tools\ 文件夹:
    echo https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe
    pause
    exit /b 1
  )
)

rem ========== [3] 首次:配置密钥 ==========
if not exist ".env" (
  echo [首次] 配置 API 密钥:
  set /p APIKEY=请粘贴 apimart.ai 的 API Key:
  if "!APIKEY!"=="" (echo 未输入 Key,已退出 & pause & exit /b 1)
  echo.
  echo 这台电脑上调 GPT 接口是否需要走本地代理(Clash)?
  echo   没有代理/不需要: 直接回车
  echo   有 Clash: 输入 http://127.0.0.1:7897
  set /p PROXY=代理地址(回车跳过):
  (
    echo APIMART_API_KEY=!APIKEY!
    echo PROXY_FOR_API=!PROXY!
  ) > .env
  echo 配置已保存到 .env
)

rem ========== [4] 读取配置 ==========
set APIMART_API_KEY=
set PROXY_FOR_API=
for /f "usebackq tokens=1,* delims==" %%a in (".env") do set %%a=%%b
if "%APIMART_API_KEY%"=="" (echo .env 缺少 APIMART_API_KEY & pause & exit /b 1)

rem ========== [5] 启动服务(按需走代理) ==========
if not "%PROXY_FOR_API%"=="" (
  set HTTPS_PROXY=%PROXY_FOR_API%
  set https_proxy=%PROXY_FOR_API%
  echo [代理] GPT接口走 %PROXY_FOR_API%
)

echo.
echo [启动] 抠图服务 (端口8400)...
start "cutout-api" /min ".venv\Scripts\python.exe" -m uvicorn app.main:app --host 0.0.0.0 --port 8400

set /a n=0
:waitloop
timeout /t 1 /nobreak >nul
curl -s -o nul http://127.0.0.1:8400/ && goto ready
set /a n+=1
if %n% lss 30 goto waitloop
echo [错误] 服务启动失败 & pause & exit /b 1
:ready
echo       本地已就绪: http://127.0.0.1:8400
echo.
echo [启动] 外网隧道,下面出现的 https://xxx.trycloudflare.com 就是公网地址:
echo (如果一直连不上:这电脑的代理/TUN 可能拦截了隧道,关闭代理软件的 TUN 模式再试)
echo.
"tools\cloudflared.exe" tunnel --protocol http2 --edge-ip-version 4 --url http://127.0.0.1:8400
