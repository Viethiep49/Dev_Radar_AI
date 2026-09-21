# Hợp đồng API – AI engine ↔ Backend

Tài liệu cho bạn phụ trách **AI engine**. Backend đã viết sẵn phần gọi sang AI engine
(`app/services/ai_client.py`) theo đúng hợp đồng dưới đây. AI engine chỉ cần làm đúng
các endpoint này là nối được, không cần sửa backend.

---

## 1. Tổng quan

- AI engine là **service nội bộ** (container Python riêng). **App Flutter không bao giờ gọi AI engine**,
  app chỉ gọi backend; backend gọi AI engine.
- Địa chỉ gốc lấy từ biến môi trường **`AI_ENGINE_URL`** của backend, ví dụ trong docker-compose:
  `AI_ENGINE_URL=http://ai-engine:8000`.
- Giao tiếp: **JSON qua HTTP**, `Content-Type: application/json`, UTF-8 (tiếng Việt không cần escape).
- Không có xác thực (chỉ chạy trong mạng Docker nội bộ, không mở cổng ra ngoài).
- LLM API key **chỉ nằm ở AI engine**, backend không biết.
- Bảng embedding thuộc AI engine (chung PostgreSQL nhưng **schema riêng**), backend không đụng vào.

| Method | Đường dẫn | Ai gọi | Khi nào |
|---|---|---|---|
| POST | `/summarize` | job `generate_summaries` (30 phút/lần) | repo có README nhưng chưa có tóm tắt |
| POST | `/index` | cùng job, ngay sau `/summarize` | để chat tìm được nội dung README |
| POST | `/chat` | `POST /api/v1/chat/{repo_id}` của app | người dùng hỏi về một repo |
| GET | `/health` | kiểm tra tay / docker healthcheck | |

`repo_id` là id của repo **trong DB backend** (số nguyên), dùng làm khoá để AI engine lưu/tìm chunk.
`full_name` là `owner/name` trên GitHub, chỉ để log / đưa vào prompt.

---

## 2. Các endpoint

### 2.1. `POST /summarize` – tóm tắt README

Request:

````json
{
  "repo_id": 42,
  "full_name": "tiangolo/fastapi",
  "readme": "# FastAPI\n\nFastAPI framework, high performance, easy to learn...\n\n## Installation\n\n```console\npip install fastapi\n```\n..."
}
````

Response `200`:

````json
{
  "summary": "FastAPI là framework web Python hiệu năng cao để xây dựng API, dựa trên type hint, tự sinh tài liệu OpenAPI...",
  "quickstart": "```bash\npip install \"fastapi[standard]\"\nfastapi dev main.py\n```",
  "model": "gpt-4o-mini"
}
````

- `summary`: 3–5 câu **tiếng Việt**, dạng text/markdown đơn giản, khoảng ≤ 600 ký tự.
- `quickstart`: markdown ngắn (các lệnh cài đặt + chạy thử). Nếu README không có thì trả
  `"Chưa có hướng dẫn nhanh"` (không trả `null`).
- `model`: tên model đã dùng (backend lưu vào cột `repo_summaries.model`).

### 2.2. `POST /index` – chia đoạn + embedding tài liệu của repo

Request:

```json
{
  "repo_id": 42,
  "full_name": "tiangolo/fastapi",
  "documents": [
    {"path": "README.md", "content": "# FastAPI\n\n..."}
  ]
}
```

Response `200`:

```json
{"chunks": 37}
```

- Hiện backend chỉ gửi `README.md`; sau này có thể gửi thêm file trong `docs/` (cùng dạng `{path, content}`).
- **Gọi lại cho cùng `repo_id` = index lại**: AI engine xoá chunk cũ của repo đó rồi lưu chunk mới
  (không được nhân đôi dữ liệu).
- `chunks`: số đoạn đã lưu.

### 2.3. `POST /chat` – hỏi đáp về một repo (RAG)

Request:

```json
{
  "repo_id": 42,
  "full_name": "tiangolo/fastapi",
  "question": "Làm sao để chạy server ở chế độ dev?",
  "history": [
    {"role": "user", "content": "FastAPI hỗ trợ async không?"},
    {"role": "assistant", "content": "Có, bạn có thể khai báo endpoint bằng async def..."}
  ]
}
```

Response `200`:

```json
{
  "answer": "Bạn chạy `fastapi dev main.py`, server sẽ tự reload khi sửa code.",
  "sources": [
    {"path": "README.md", "excerpt": "Run the server with: fastapi dev main.py ..."}
  ]
}
```

- `history`: tối đa **6 tin nhắn gần nhất** của user với repo này, **cũ trước – mới sau**,
  `role` là `"user"` hoặc `"assistant"`. Không chứa câu hỏi hiện tại. Có thể rỗng `[]`.
- `answer`: tiếng Việt, markdown đơn giản.
- `sources`: các đoạn tài liệu đã dùng để trả lời (1–5 phần tử), `excerpt` ≤ ~300 ký tự.
  Không tìm thấy thì `sources: []`.
- Repo **chưa được index** (chưa gọi `/index`): trả `200` với câu trả lời
  "không tìm thấy trong tài liệu" và `sources: []`, **không** trả lỗi.

### 2.4. `GET /health`

Response `200`:

```json
{"status": "ok"}
```

---

## 3. Timeout và lỗi

- Backend đặt **timeout = `AI_TIMEOUT_SECONDS`** (mặc định **30 giây**) cho mọi request sang AI engine
  (gồm cả thời gian kết nối và chờ trả lời). Chat thường mất 5–15 giây là ổn.
- Backend xử lý như sau (app nhận lỗi theo định dạng chung trong `API_CONVENTIONS.md`):

| AI engine | Backend trả cho app |
|---|---|
| `2xx` + JSON đúng dạng | kết quả bình thường |
| quá thời gian timeout | `504 UPSTREAM_TIMEOUT` – "AI đang bận, vui lòng thử lại" |
| mọi mã **khác 2xx** (400, 422, 500, 503...) | `502 UPSTREAM_ERROR` |
| không kết nối được / trả về không phải JSON | `502 UPSTREAM_ERROR` |

- Vì vậy AI engine **chỉ cần trả mã HTTP đúng**; nội dung lỗi (ví dụ `{"detail": "..."}` của FastAPI)
  backend chỉ ghi log, không chuyển cho app.
- Khi LLM bị rate limit / lỗi tạm thời: trả `503` là đủ.
- Với chat, nếu AI lỗi thì câu hỏi của user **vẫn được lưu** trong lịch sử, chỉ không có câu trả lời.
- Với job tóm tắt, repo bị lỗi sẽ được bỏ qua và **thử lại ở lần chạy sau** (30 phút).

---

## 4. RAG đơn giản mà AI engine nên làm

Không cần phức tạp, chỉ cần giải thích được:

1. **Chia đoạn (`/index`)**: tách README/docs theo heading và đoạn văn, mỗi chunk khoảng
   **~500 token** (có thể chồng lấn ~50 token). Giữ nguyên code block trong một chunk nếu được.
2. **Embedding**: tạo vector cho từng chunk (model embedding của nhà cung cấp LLM hoặc
   sentence-transformers), lưu vào bảng riêng có `repo_id`, `path`, `content`, `embedding`
   (pgvector, schema riêng của AI engine).
3. **Tìm kiếm (`/chat`)**: embedding câu hỏi, lấy **top 3–5 chunk** của đúng `repo_id` có
   **cosine similarity** cao nhất.
4. **Trả lời**: đưa các chunk đó + `history` + câu hỏi vào prompt, yêu cầu LLM
   **chỉ trả lời dựa trên ngữ cảnh**; nếu ngữ cảnh không có thông tin thì trả lời
   **"Không tìm thấy trong tài liệu"** (không bịa). Trả lời bằng tiếng Việt.
5. `sources` = các chunk đã đưa vào prompt (`path` + đoạn trích ngắn).

Gợi ý prompt:

```
Bạn là trợ lý giải thích repo GitHub "{full_name}" cho sinh viên.
Chỉ dùng thông tin trong phần TÀI LIỆU bên dưới. Nếu tài liệu không có câu trả lời,
hãy nói "Không tìm thấy trong tài liệu". Trả lời ngắn gọn bằng tiếng Việt.

TÀI LIỆU:
{chunk_1}
---
{chunk_2}
...
```

---

## 5. Chế độ dự phòng của backend (khi chưa có AI engine)

Nếu **`AI_ENGINE_URL` để trống**, backend **không gọi mạng** mà dùng `app/services/fallback_ai.py`,
nên cả app vẫn chạy được trước khi AI engine xong:

| Chức năng | Cách làm của fallback |
|---|---|
| summarize | lấy 1–2 đoạn văn đầu tiên có nghĩa của README (bỏ badge, ảnh, thẻ HTML), cắt còn ~600 ký tự; quickstart = code block dưới heading "install" / "usage" / "getting started", không có thì "Chưa có hướng dẫn nhanh"; `model = "fallback"` |
| index | không làm gì, trả số đoạn văn |
| chat | chia README thành đoạn, chấm điểm theo **số từ khoá trùng** với câu hỏi (bỏ từ quá ngắn), lấy top 3 đoạn; câu trả lời có tiền tố "(Chế độ dự phòng, chưa có AI engine)"; không đoạn nào trùng → "Không tìm thấy thông tin này trong tài liệu của repo." |

- Tóm tắt tạo bởi fallback có `model = "fallback"` trong bảng `repo_summaries`. Khi đã có AI engine,
  có thể xoá các dòng này (`DELETE FROM repo_summaries WHERE model = 'fallback'`) để job tạo lại bằng AI thật.
- Repo không có README: backend trả lời chat luôn là "chưa có tài liệu", không gọi AI engine.

---

## 6. Thử nhanh

```bash
curl http://localhost:8000/health
curl -X POST http://localhost:8000/chat -H "Content-Type: application/json" \
  -d '{"repo_id": 1, "full_name": "tiangolo/fastapi", "question": "Cài đặt thế nào?", "history": []}'
```

Bật nối với backend: đặt `AI_ENGINE_URL=http://ai-engine:8000` trong `.env` rồi khởi động lại backend.
