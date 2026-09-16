"""GPT-Image-2 批量抠图 - 后端核心"""
import base64
import io
import json
import os
import time
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
    "Clean natural edges, no leftover background fragments, no halos."
)


def _http_json(url, payload=None, retries=5):
    for i in range(retries):
        try:
            data = json.dumps(payload).encode() if payload is not None else None
            headers = {"Authorization": f"Bearer {API_KEY}"}
            if data:
                headers["Content-Type"] = "application/json"
            req = urllib.request.Request(url, data=data, headers=headers)
            with urllib.request.urlopen(req, timeout=120) as r:
                return json.loads(r.read())
        except Exception:
            if i == retries - 1:
                raise
            time.sleep(3)


def _http_bytes(url, retries=5):
    for i in range(retries):
        try:
            with urllib.request.urlopen(url, timeout=180) as r:
                return r.read()
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
            return Image.open(io.BytesIO(_http_bytes(url)))
        if st == "failed":
            raise RuntimeError(f"任务失败: {str(t)[:200]}")
    raise TimeoutError("生成超时")
