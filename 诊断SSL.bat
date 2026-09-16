@echo off
title Diagnose SSL issue
cd /d %~dp0
echo ===== 1. Python SSL default cert paths =====
if exist "runtime\python.exe" (
  "runtime\python.exe" -c "import ssl; print(ssl.get_default_verify_paths())"
) else (
  if exist ".venv\Scripts\python.exe" (
    ".venv\Scripts\python.exe" -c "import ssl; print(ssl.get_default_verify_paths())"
  ) else (
    python -c "import ssl; print(ssl.get_default_verify_paths())"
  )
)
echo.
echo ===== 2. Python direct request to api.apimart.ai =====
if exist "runtime\python.exe" (
  "runtime\python.exe" -c "import urllib.request,traceback;exec(\"try:\n print('OK',urllib.request.urlopen('https://api.apimart.ai',timeout=20).status)\nexcept Exception as e:\n traceback.print_exc()\")"
) else (
  python -c "import urllib.request,traceback;exec(\"try:\n print('OK',urllib.request.urlopen('https://api.apimart.ai',timeout=20).status)\nexcept Exception as e:\n traceback.print_exc()\")"
)
echo.
echo ===== 3. Certificate issuer seen by this PC =====
curl -sv https://api.apimart.ai -o nul 2>&1 | findstr /i "issuer subject SSL"
echo.
echo ===== 4. Windows cert store probe =====
if exist "runtime\python.exe" (
  "runtime\python.exe" -c "import ssl;c=ssl.SSLContext();c.load_default_certs();import socket;print('CA certs loaded OK')"
) else (
  python -c "import ssl;c=ssl.SSLContext();c.load_default_certs();print('CA certs loaded OK')"
)
echo.
echo Done. Copy ALL output above and send it back.
pause
