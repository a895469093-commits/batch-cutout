# 批量抠图 Web 服务

基于 GPT-Image-2 的印花/图案批量去背景工具:上传一批图片,云端移除背景,返回透明 PNG,支持打包下载。

## 功能

- 🖼️ **批量上传**:网页拖拽或点多选,一次一批
- ⚡ **4 路并发**:多张同时处理,平均约 60~80 秒/张
- 📦 **批量下载**:单张下载或一键打包 ZIP
- 🔄 **断网自动重试**,失败单张标红不影响整批
- 💰 单张成本约 $0.0085(1k 档)

## 快速开始

```bash
# 1. 安装依赖
pip install -r requirements.txt

# 2. 配置密钥
copy .env.example .env    # Windows
# 编辑 .env 填入你的 APIMART_API_KEY

# 3. 启动(Windows)
start.bat
# 或手动:
# set APIMART_API_KEY=你的key
# uvicorn app.main:app --host 0.0.0.0 --port 8400
```

浏览器打开 http://localhost:8400

> Linux/macOS 启动:
> ```bash
> export $(cat .env | xargs) && uvicorn app.main:app --host 0.0.0.0 --port 8400
> ```

## API

| 接口 | 说明 |
|---|---|
| `POST /api/upload` | multipart 上传多图(`files` 字段),返回 `batch_id` |
| `GET /api/status/{batch_id}` | 查询进度与每张状态 |
| `GET /api/file/{batch_id}/{name}` | 下载单张透明 PNG |
| `GET /api/zip/{batch_id}` | 打包下载整批 ZIP |

## 配置项(环境变量)

| 变量 | 默认 | 说明 |
|---|---|---|
| `APIMART_API_KEY` | 无(必填) | apimart.ai 的 API Key |
| `CUTOUT_RESOLUTION` | `1k` | `1k` / `2k` / `4k` |
| `CUTOUT_WORKERS` | `4` | 并发数,过高可能触发限流 |
| `CUTOUT_DATA` | `./data` | 结果保存目录 |

## 项目结构

```
├── app/
│   ├── main.py      # FastAPI 路由(上传/进度/下载)
│   └── cutter.py    # GPT-Image-2 调用与重试
├── static/
│   └── index.html   # 上传页(拖拽/进度/预览/打包下载)
├── data/            # 运行时结果(gitignore)
├── requirements.txt
└── .env.example
```

## 注意

- API Key 只放在 `.env` 或环境变量里,**不要提交到仓库**
- 提示词在 `app/cutter.py` 顶部的 `PROMPT`,可按需调整
- 图片经第三方 API 处理,涉密图片请勿上传

## License

MIT
