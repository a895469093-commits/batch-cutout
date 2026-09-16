@echo off
title Open LAN access (run as Administrator)
netsh advfirewall firewall add rule name="Cutout 8400" dir=in action=allow protocol=TCP localport=8400
if %errorlevel%==0 (
  echo OK: port 8400 opened. LAN devices can access this PC now.
) else (
  echo FAILED: right-click this file and choose "Run as administrator".
)
pause
