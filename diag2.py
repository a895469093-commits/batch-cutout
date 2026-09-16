"""深度诊断:拿到对端证书的真实颁发者 + 测试certifi修复"""
import socket
import ssl
import urllib.request

import certifi
from cryptography import x509

HOST = "api.apimart.ai"

# 1. 无校验握手,拿证书
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE
with socket.create_connection((HOST, 443), timeout=15) as sock:
    with ctx.wrap_socket(sock, server_hostname=HOST) as s:
        der = s.getpeercert(binary_form=True)

cert = x509.load_der_x509_certificate(der)
print("=== 对端证书 ===")
print("颁发者 Issuer:", cert.issuer.rfc4514_string())
print("持有者 Subject:", cert.subject.rfc4514_string())
print("有效期:", cert.not_valid_before_utc, "~", cert.not_valid_after_utc)

# 2. certifi 修复测试
print("\n=== certifi 方式请求 ===")
try:
    c2 = ssl.create_default_context(cafile=certifi.where())
    with urllib.request.urlopen(f"https://{HOST}", timeout=20, context=c2) as r:
        print("OK, status =", r.status)
except Exception as e:
    print("FAIL:", type(e).__name__, e)

# 3. Windows系统库方式(对比)
print("\n=== Windows系统证书库方式 ===")
try:
    c3 = ssl.create_default_context()
    with urllib.request.urlopen(f"https://{HOST}", timeout=20, context=c3) as r:
        print("OK, status =", r.status)
except Exception as e:
    print("FAIL:", type(e).__name__, e)
