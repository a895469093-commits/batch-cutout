"""GPT-Image-2 批量抠图 - 后端核心"""
import base64
import io
import json
import os
import ssl
import time
import urllib.error
import urllib.request

from PIL import Image

API_BASE = os.environ.get("APIMART_API", "https://api.apimart.ai/v1")
API_KEY = os.environ.get("APIMART_API_KEY", "")
RESOLUTION = os.environ.get("CUTOUT_RESOLUTION", "1k")
WORKERS = int(os.environ.get("CUTOUT_WORKERS", "4"))

PROMPT = (
    "Remove the background of this image completely. Output the exact same graphic design "
    "on a fully transparent background. Keep every part of the design exactly as it is: "
    "all letters, all objects and every part of them - including ribbons, bands and stripes "
    "wrapping around objects - all attached artwork, all colors, textures and details, "
    "unchanged in shape, position and size. Only the background becomes transparent. "
    "Clean natural edges, no leftover background fragments, no halos. "
    "Do NOT draw a checkerboard pattern - the transparency must be a real alpha channel, not a painted checkerboard."
)


def _ca_context():
    """优先用 certifi 证书库(apimart 的 WE1 新链不在 Windows 系统库里)"""
    try:
        import certifi
        return ssl.create_default_context(cafile=certifi.where())
    except Exception:
        return ssl.create_default_context()


def _http_json(url, payload=None, retries=5):
    for i in range(retries):
        try:
            data = json.dumps(payload).encode() if payload is not None else None
            headers = {"Authorization": f"Bearer {API_KEY}"}
            if data:
                headers["Content-Type"] = "application/json"
            req = urllib.request.Request(url, data=data, headers=headers)
            with urllib.request.urlopen(req, timeout=120, context=_ca_context()) as r:
                return json.loads(r.read())
        except urllib.error.URLError as e:
            # 证书校验失败(网关/代理做了HTTPS拦截): 自动降级为免校验重试
            if isinstance(getattr(e, "reason", None), ssl.SSLCertVerificationError):
                ctx = ssl._create_unverified_context()
                try:
                    req2 = urllib.request.Request(url, data=data, headers=headers)
                    ctx2 = _ca_context()
                    req2 = urllib.request.Request(url, data=data, headers=headers)
                    with urllib.request.urlopen(req2, timeout=120, context=ctx2) as r:
                        return json.loads(r.read())
                except Exception:
                    pass
            if i == retries - 1:
                raise
            time.sleep(3)
        except Exception:
            if i == retries - 1:
                raise
            time.sleep(3)


def _http_bytes(url, retries=5):
    for i in range(retries):
        try:
            with urllib.request.urlopen(url, timeout=180, context=_ca_context()) as r:
                return r.read()
        except urllib.error.URLError as e:
            if isinstance(getattr(e, "reason", None), ssl.SSLCertVerificationError):
                ctx = ssl._create_unverified_context()
                try:
                    with urllib.request.urlopen(url, timeout=180, context=_ca_context()) as r:
                        return r.read()
                except Exception:
                    pass
            if i == retries - 1:
                raise
            time.sleep(3)
        except Exception:
            if i == retries - 1:
                raise
            time.sleep(3)
    raise RuntimeError("download failed")


def cutout_image(img: Image.Image) -> Image.Image:
    """单张: 上传原图 -> GPT-Image-2 返回透明PNG"""
    if not API_KEY:
        raise RuntimeError("未配置 APIMART_API_KEY")
    buf = io.BytesIO()
    img.convert("RGB").save(buf, "PNG")
    b64 = base64.b64encode(buf.getvalue()).decode()
    r = _http_json(f"{API_BASE}/images/generations", {
        "model": "gpt-image-2",
        "prompt": PROMPT,
        "n": 1,
        "image_urls": [f"data:image/png;base64,{b64}"],
        "resolution": RESOLUTION,
        "background": "transparent",
    })
    task_id = r["data"][0]["task_id"]
    for _ in range(150):
        time.sleep(2)
        t = _http_json(f"{API_BASE}/tasks/{task_id}")
        st = t.get("data", {}).get("status") or t.get("status")
        if st == "completed":
            url = t["data"]["result"]["images"][0]["url"][0]
            img = Image.open(io.BytesIO(_http_bytes(url)))
            return _fix_fake_alpha(img)
        if st == "failed":
            raise RuntimeError(f"任务失败: {str(t)[:200]}")
    raise TimeoutError("生成超时")


def _fix_fake_alpha(img: Image.Image) -> Image.Image:
    """模型有时把透明画成棋盘格像素(无alpha通道)。自动检测并转真透明。"""
    if img.mode in ("RGBA", "LA"):
        return img  # 已有透明通道
    try:
        import tempfile
        from .dechecker import remove_checkerboard
        with tempfile.TemporaryDirectory() as td:
            src_p = os.path.join(td, "in.png")
            img.convert("RGB").save(src_p)
            out_p = remove_checkerboard(src_p, os.path.join(td, "out.png"))
            fixed = Image.open(out_p)
            fixed.load()  # Windows下必须在临时目录删除前完整载入
            return fixed
    except Exception:
        return img
