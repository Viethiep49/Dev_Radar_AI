# ai-engine – Service AI

Service xử lý ngôn ngữ tự nhiên và vector cho Dev Radar AI, được xây dựng trên FastAPI, Ollama và SentenceTransformers.

## API Endpoints

- `POST /summarize`: Sinh tóm tắt README bằng Ollama.
- `POST /index`: Trích xuất và nhúng (embed) tài liệu (README) vào CSDL dưới dạng vector sử dụng mô hình SentenceTransformers.
- `POST /chat`: RAG chatbot trả lời câu hỏi lập trình, tự động tìm kiếm ngữ cảnh có độ tương đồng cosine hợp lệ (HNSW index).

## Cấu hình Môi trường

- Cấu hình qua biến môi trường:
  - `DATABASE_URL`: Đường dẫn Postgres (Bắt buộc).
  - `OLLAMA_URL`: URL tới máy chủ Ollama (mặc định: `http://ollama:11434/api/generate`).
  - `OLLAMA_MODEL`: Mô hình sinh văn bản (mặc định: `qwen2.5:7b`).
  - `OLLAMA_TIMEOUT_SECONDS`: Thời gian chờ tối đa khi gọi Ollama (mặc định: `25`).
  - `MIN_SIMILARITY`: Ngưỡng cosine similarity tối thiểu để lọc chunk (mặc định: `0.35`).

## Hiệu năng (Performance Benchmarks)

Sau khi kiểm thử thực tế trên hệ thống (chạy qua Docker Desktop môi trường CPU Host):
- **`/summarize`** (LLM inference + Context processing): ~8.6 giây.
- **`/chat`** (Vector Search + LLM streaming): ~0.4 giây.
- **Database Query (HNSW Index Scan)**: ~0.363 ms (Rất nhanh, tránh được vấn đề full-scan của seq scan).

### Chạy bằng GPU

Để đạt tốc độ tối đa, nếu bạn có NVIDIA GPU, bạn có thể chỉnh sửa `docker-compose.yml`:
Thêm đoạn `deploy` vào service `ollama` và `ai-engine` để kích hoạt giao tiếp CUDA:
```yaml
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
```
LLM Inference sẽ cải thiện rõ rệt so với CPU.

## Chạy Kiểm thử
Sử dụng docker để tự động thiết lập Postgres và môi trường:
```bash
docker build --target test -t ai-engine-test ai-engine
docker run --rm -e PYTHONPATH=/app -e DATABASE_URL="postgresql://devradar:change_me@localhost:5432/devradar" -e OLLAMA_URL="http://localhost:11434" --network host ai-engine-test pytest tests/ -v
```
