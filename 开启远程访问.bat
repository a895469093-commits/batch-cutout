@echo off
chcp 65001 >nul
netsh advfirewall firewall add rule name="Cutout 8400" dir=in action=allow protocol=TCP localport=8400
if %errorlevel%==0 (
  echo ✅ 已放行8400端口,局域网电脑可以访问本机抠图服务了
) else (
  echo ❌ 失败:请右键本文件,选择"以管理员身份运行"
)
pause
