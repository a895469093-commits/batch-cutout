@echo off
cd /d %~dp0
set "PY=python"
if exist "runtime\python.exe" set "PY=runtime\python.exe"
if exist ".venv\Scripts\python.exe" set "PY=.venv\Scripts\python.exe"
"%PY%" diag.py
echo.
pause
