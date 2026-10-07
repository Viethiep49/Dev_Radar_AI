# ai-engine – Service AI

Service xử lý ngôn ngữ tự nhiên và vector cho Dev Radar AI, được xây dựng trên FastAPI, Ollama và SentenceTransformers.

## API Endpoints

- `POST /summarize`: Sinh tóm tắt README bằng Ollama.
- `POST /index`: Trích xuất và nhúng (embed) tài liệu (README) vào CSDL dưới dạng vector sử dụng mô hình SentenceTransformers.
- `POST /chat`: RAG chatbot trả lời câu hỏi lập trình, tự động lọc chunk theo `repo_id` (B-tree index `repo_embeddings_repo_id_idx`) rồi tính cosine distance chính xác (không dùng index vector — mỗi repo chỉ vài chục chunk nên exact search đủ nhanh và luôn đúng).

## Cấu hình Môi trường

- Cấu hình qua biến môi trường:
  - `DATABASE_URL`: Đường dẫn Postgres (Bắt buộc).
  - `OLLAMA_URL`: URL tới máy chủ Ollama (mặc định: `http://ollama:11434/api/generate`).
  - `OLLAMA_MODEL`: Mô hình sinh văn bản (mặc định: `qwen2.5:7b`).
  - `OLLAMA_TIMEOUT_SECONDS`: Thời gian chờ tối đa khi gọi Ollama (mặc định: `25`).
  - `MIN_SIMILARITY`: Ngưỡng cosine similarity tối thiểu để lọc chunk (mặc định: `0.35`).

## Hiệu năng

Số liệu đo thật (máy, model, cold/warm) được ghi ở mục **Kết quả đo** bên dưới.
Lưu ý khi đo `/chat`: chỉ tính các câu hỏi **có** chunk liên quan (có gọi LLM);
câu trả lời "Không tìm thấy trong tài liệu" không gọi LLM nên luôn rất nhanh.

### GPU / CPU

`docker-compose.yml` **mặc định dùng GPU NVIDIA** cho service `ollama`
(cần driver NVIDIA + NVIDIA Container Toolkit / Docker Desktop WSL2):

```bash
docker compose up -d --build
```

Máy không có GPU dùng override CPU (chậm hơn nhiều, có thể vượt timeout 25s):

```bash
docker compose -f docker-compose.yml -f docker-compose.cpu.yml up -d --build
```

Nếu `/chat` vượt timeout, thử model nhỏ hơn: `OLLAMA_MODEL=qwen2.5:3b` trong `.env`.

### Kết quả đo

Đo ngày 06/10/2026 — Docker Desktop (WSL2), GPU **RTX 3060 12GB** (`ollama ps`: 100% GPU),
model `qwen2.5:7b`, Ollama 0.5.7, README thật của `fastapi/fastapi` (~94 chunk). Model đã nạp sẵn (warm,
`OLLAMA_KEEP_ALIVE=-1`).

| Request | Thời gian | Ghi chú |
|---|---|---|
| `/index` (1 README) | ~1.8 s | embed 94 chunk trên CPU |
| `/summarize` | ~6.0–6.3 s | có gọi LLM (JSON) |
| `/chat` có chunk liên quan | ~0.7–2.4 s | có gọi LLM |
| `/chat` không có chunk vượt ngưỡng | ~0.02–0.35 s | **không** gọi LLM |
| Truy vấn retrieval (`EXPLAIN ANALYZE`) | ~0.07 ms | Seq Scan + lọc `repo_id` + top-N heapsort trên vài chục dòng; bảng còn nhỏ nên planner chưa chọn `repo_embeddings_repo_id_idx` |

Chưa đo: chạy CPU (`docker-compose.cpu.yml`) và cold start (lần nạp model đầu).

Chunk: chia theo **token** của chính tokenizer model embedding (120 token, overlap 15). Đo trên README
FastAPI: chunk lớn nhất 116 token ≤ `max_seq_length = 128`. Trước đây chia 450 ký tự có 24/66 chunk
vượt 128 token (tối đa 174) → phần đuôi bị cắt khi embed.

## Chạy Kiểm thử
Sử dụng docker để tự động thiết lập Postgres và môi trường:
```bash
docker build --target test -t ai-engine-test ai-engine
docker run --rm -e PYTHONPATH=/app -e DATABASE_URL="postgresql://devradar:change_me@localhost:5432/devradar" -e OLLAMA_URL="http://localhost:11434" --network host ai-engine-test pytest tests/ -v
```
