"""SSL 诊断:定位证书报错的根因。双击 诊断SSL.bat 运行本文件。"""
import os
import socket
import ssl
import sys
import traceback
import urllib.request

HOST = "api.apimart.ai"

print("===== 0. 版本信息 =====")
print("Python:", sys.version.split()[0])
print("verify paths:", ssl.get_default_verify_paths())
try:
    print("cutter.py 修改时间:", os.path.getmtime(os.path.join("app", "cutter.py")))
except OSError:
    print("app/cutter.py 不存在")

print("\n===== 1. 握手时看到的证书问题(带校验) =====")
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_REQUIRED
try:
    with socket.create_connection((HOST, 443), timeout=15) as sock:
        with ctx.wrap_socket(sock, server_hostname=HOST):
            pass
    print("证书校验通过(那问题不在这)")
except Exception as e:
    print("错误类型:", type(e).__name__)
    print("错误信息:", e)

print("\n===== 2. Python 默认方式请求 =====")
try:
    print("OK, status =", urllib.request.urlopen(f"https://{HOST}", timeout=20).status)
except Exception:
    traceback.print_exc()

print("\n===== 3. 用 certifi 证书库请求 =====")
try:
    import certifi
    print("certifi 路径:", certifi.where())
    ctx2 = ssl.create_default_context(cafile=certifi.where())
    req = urllib.request.Request(f"https://{HOST}")
    with urllib.request.urlopen(req, timeout=20, context=ctx2) as r:
        print("OK, status =", r.status)
except ImportError:
    print("certifi 未安装")
except Exception:
    traceback.print_exc()

print("\n===== 4. Windows 证书库加载 =====")
try:
    c = ssl.SSLContext()
    c.load_default_certs()
    print("OK")
except Exception as e:
    print("FAIL:", e)

print("\n===== 结论判读 =====")
print("若 1 显示 self-signed/unknown CA  -> 公司网关拦截(MITM)")
print("若 1 显示 unable to get local issuer -> 证书链不全")
print("若 2 失败但 3 成功                -> 用 certifi 即可修复")
print("\n诊断完成,请把以上全部输出复制发回。")
