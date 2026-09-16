"""GPT-Image-2 批量抠图 Web 服务
启动: uvicorn app.main:app --host 0.0.0.0 --port 8400
"""
import io
import os
import zipfile
from concurrent.futures import ThreadPoolExecutor

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.responses import FileResponse, HTMLResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from PIL import Image

from .cutter import cutout_image, WORKERS

DATA_DIR = os.environ.get("CUTOUT_DATA", os.path.join(os.path.dirname(__file__), "..", "data"))

app = FastAPI(title="批量抠图")

# 批次状态: batch_id -> {"items": {name: status}, "total": n}
BATCHES: dict = {}
EXECUTORS: dict = {}


def _run_one(batch_id: str, name: str, raw: bytes):
    out_dir = os.path.join(DATA_DIR, batch_id)
    os.makedirs(out_dir, exist_ok=True)
    out_name = os.path.splitext(name)[0] + "_透明.png"
    try:
        img = cutout_image(Image.open(io.BytesIO(raw)))
        img.save(os.path.join(out_dir, out_name))
        BATCHES[batch_id]["items"][name] = {"status": "done", "file": out_name}
    except Exception as e:
        BATCHES[batch_id]["items"][name] = {"status": "failed", "error": str(e)[:120]}


@app.post("/api/upload")
async def upload(files: list[UploadFile] = File(...)):
    """批量上传, 立即返回批次号, 后台并发处理"""
    batch_id = f"b_{int(__import__('time').time())}_{os.urandom(3).hex()}"
    BATCHES[batch_id] = {"items": {}, "total": len(files)}
    EXECUTORS[batch_id] = ThreadPoolExecutor(max_workers=WORKERS)
    for f in files:
        raw = await f.read()
        BATCHES[batch_id]["items"][f.filename] = {"status": "queued"}
        EXECUTORS[batch_id].submit(_run_one, batch_id, f.filename, raw)
    return {"batch_id": batch_id, "total": len(files)}


@app.get("/api/status/{batch_id}")
async def status(batch_id: str):
    """轮询进度"""
    b = BATCHES.get(batch_id)
    if not b:
        raise HTTPException(404, "批次不存在")
    done = sum(1 for v in b["items"].values() if v["status"] != "queued" and v["status"] != "running")
    return {"total": b["total"], "finished": done, "items": b["items"]}


@app.get("/api/file/{batch_id}/{name}")
async def get_file(batch_id: str, name: str):
    p = os.path.join(DATA_DIR, batch_id, name)
    if not os.path.isfile(p):
        raise HTTPException(404)
    return FileResponse(p, media_type="image/png", filename=name)


@app.get("/api/zip/{batch_id}")
async def get_zip(batch_id: str):
    d = os.path.join(DATA_DIR, batch_id)
    if not os.path.isdir(d):
        raise HTTPException(404)
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
        for f in os.listdir(d):
            z.write(os.path.join(d, f), f)
    buf.seek(0)
    return StreamingResponse(buf, media_type="application/zip",
                             headers={"Content-Disposition": f"attachment; filename=cutout_{batch_id}.zip"})


@app.get("/", response_class=HTMLResponse)
async def index():
    with open(os.path.join(os.path.dirname(__file__), "..", "static", "index.html"), encoding="utf-8") as f:
        return f.read()
