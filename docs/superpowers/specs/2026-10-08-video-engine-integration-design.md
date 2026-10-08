# Kết nối video-engine vào Dev Radar AI — Vòng 1 (Backend + Docker)

Ngày: 2026-10-08
Trạng thái: đã duyệt thiết kế, chờ viết plan
Phạm vi: backend + docker + run.bat. **Không** gồm Flutter, **không** gồm cron Repo of the Day.

## 1. Mục tiêu

Đưa `video-engine` (FastAPI, cổng 9000) từ chỗ nằm im trong `docker-compose.yml` (bị chặn sau `profiles: [video]`, không gì khởi động) thành một service backend thật sự gọi được: người dùng bấm "Tạo Video Tổng Kết", backend dựng kịch bản từ dữ liệu lộ trình học tập, gọi engine render, lưu file MP4 vào volume chung, và trả cho client một URL phát được.

Kết quả mong đợi: `POST /api/v1/videos/roadmap` trả `job_id` + `url`; `GET /api/v1/videos/{job_id}` phát file MP4.

## 2. Quyết định đã chốt

| # | Quyết định | Lý do |
|---|---|---|
| D1 | Render **đồng bộ** — backend giữ kết nối tới engine, trả kết quả ngay | Tài liệu frontend cho phép "HTTP giữ kết nối dài" là một trong ba cách. Không cần bảng trạng thái, không cần polling. Route `def` (không `async`) chạy trong threadpool của FastAPI nên không chặn event loop — khớp kiểu code backend hiện tại (SQLAlchemy sync). |
| D2 | **Backend tự phục vụ file** bằng `FileResponse` | Bỏ S3/CDN cho đồ án. Đổi sang S3 sau này chỉ thay một hàm. |
| D3 | URL video **công khai, không auth** | Nút Chia sẻ gọi `navigator.share` với URL; link phải mở được mà không kèm header `Authorization`. Bảo vệ bằng `job_id` ngẫu nhiên (UUID4, 122 bit). Video chỉ chứa số liệu học tập. |
| D4 | Bỏ `profiles: [video]`, thêm video-engine vào `run.bat` mặc định | Hiện không có cách nào khởi động service này. |
| D5 | Trả **đường dẫn tương đối**, không phải URL tuyệt đối | Backend không biết host công khai (localhost / IP LAN / `10.0.2.2` cho emulator). Frontend đã có `API_BASE_URL` và tự ghép. |
| D6 | Hoãn cron "Repo of the Day" | Cần luật chọn repo của ngày, chống trùng theo ngày, đổi schema `RepoOut`/`get_feed`. Là tính năng thứ hai, không phải phần nối. |

## 3. Docker + run.bat

`docker-compose.yml`, service `video-engine` — bỏ khối `profiles`:

```yaml
  video-engine:
    build: ./video-engine
    expose: ["9000"]
    volumes:
      - video_data:/data/videos
    environment:
      OUTPUT_DIR: /data/videos
```

**Không** thêm `depends_on` hay `healthcheck` cho service này. Nếu engine build lỗi hoặc chưa boot xong, nó không được kéo sập API — `video_client` đã map lỗi kết nối thành `502 UPSTREAM_ERROR`.

`backend` thêm một volume **read-only** và hai biến môi trường:

```yaml
    volumes:
      - video_data:/data/videos:ro
    environment:
      VIDEO_ENGINE_URL: ${VIDEO_ENGINE_URL:-http://video-engine:9000}
      VIDEO_TIMEOUT_SECONDS: ${VIDEO_TIMEOUT_SECONDS:-300}
```

Read-only là cố ý: backend chỉ đọc file engine ghi ra, không bao giờ ghi vào đó.

`run.bat` dòng 41: `docker compose up -d --build db backend` → `docker compose up -d --build db backend video-engine`.

Hệ quả: lần chạy `run.bat` đầu tiên sẽ build ảnh video-engine (cairo, ffmpeg, model giọng Piper `vi_VN-vais1000-medium`) — lâu hơn hiện tại vài phút.

## 4. Cấu hình backend

`backend/app/core/config.py`, thêm cạnh `ai_engine_*`:

```python
    video_engine_url: str = ""              # rỗng = tắt, giống ai_engine_url
    video_timeout_seconds: int = 300
    video_output_dir: str = "/data/videos"
```

Mặc định rỗng (không phải URL compose) là cố ý: test không cần Docker vẫn chạy, và `use_fallback()` trả `True` → `AppError(503, NOT_CONFIGURED)`. Trong compose biến luôn được set nên hành vi thật không đổi.

## 5. `backend/app/services/video_client.py`

Sao chép nguyên mẫu `ai_client.py`:

- `use_fallback()` → `not settings.video_engine_url.strip()`
- `_make_client()` tách riêng để test bơm `httpx.MockTransport`
- `_post()` map `httpx.TimeoutException` → `AppError(504, UPSTREAM_TIMEOUT, ...)`; `(httpx.HTTPError, ValueError)` → `AppError(502, UPSTREAM_ERROR, ...)`
- Gọi `POST {video_engine_url}/render` với payload `VideoSpec`, timeout `video_timeout_seconds`
- Trả `RenderResult` (`path`, `duration_seconds`, `size_bytes`)

Vì `video_timeout_seconds = 300` > thời gian render thực tế (30s–1p), timeout chỉ kích hoạt khi engine thật sự treo.

## 6. `backend/app/services/video_spec.py` — bộ dựng kịch bản

**Hàm thuần**, không DB, không HTTP, nên test được một mình. Đây là chỗ dễ sai nhất vì schema của engine rất chặt.

Đầu vào: danh sách `UserRepo` (kèm `repo`) của người dùng, tên hiển thị, và một `job_id` do caller sinh.
Đầu ra: `dict` khớp `VideoSpec` của engine.

Sáu slide:

| # | `kind` | Nội dung |
|---|---|---|
| 1 | `hook` | title = `Lộ trình của {tên}`, subtitle = `Tổng kết hành trình học tập` |
| 2 | `stat` | label = `Đang học`, value = số repo trạng thái `learning` (chuỗi), unit = `repo` |
| 3 | `stat` | label = `Đã dùng`, value = số repo trạng thái `used` (chuỗi), unit = `repo` |
| 4 | `list` | title = `Ngôn ngữ hàng đầu`, items = top 3 ngôn ngữ |
| 5 | `repo` | repo nhiều sao nhất trong lộ trình (`full_name`, `description`, `language`, `stars`) |
| 6 | `outro` | title = `Tiếp tục cố lên!`, subtitle = tên người dùng |

### Ràng buộc phải tôn trọng (từ `video-engine/app/schemas/spec.py`)

- `narration`: 1–300 ký tự, **mỗi slide đều có**
- `slides`: 2–8 phần tử
- `job_id`: khớp `^[A-Za-z0-9_-]{1,64}$`
- `HookSlide.title` ≤60, `subtitle` ≤90
- `StatSlide.label` ≤40, **`value` là chuỗi** ≤12, `unit` ≤16
- `ListSlide.title` ≤50, `items` **2–4** phần tử
- `RepoSlide.full_name` khớp `^[^/\s]+/[^/\s]+$`, ≤120; `description` ≤300; `language` ≤40; `stars: int >= 0`
- `OutroSlide.title` ≤60, `subtitle` ≤90

### Xử lý thiếu dữ liệu

- Helper `_clip(s, n)` cắt chuỗi về `n` ký tự, dùng cho mọi trường có giới hạn độ dài.
- Slide 4 cần ≥2 phần tử. Nếu <2 ngôn ngữ, thay bằng top 3 tên repo. Nếu vẫn <2, **bỏ slide 4**.
- Slide 5 bỏ nếu lộ trình không có repo nào.
- Sau khi lọc, nếu còn <2 slide → không render được.

**Người dùng chưa có repo nào trong lộ trình → `AppError(400, BAD_REQUEST)`**, không render video rỗng.

## 7. Model + migration

`backend/app/models/personal.py`:

```python
class GeneratedVideo(Base):
    __tablename__ = "generated_videos"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    job_id: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    duration_seconds: Mapped[float] = mapped_column(Float)
    size_bytes: Mapped[int] = mapped_column(Integer)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
```

Re-export trong `backend/app/models/__init__.py`.

Migration `backend/alembic/versions/0004_generated_videos.py`, `revision = "0004"`, `down_revision = "0003"` (head hiện tại). Docstring theo đúng mẫu `0003`.

## 8. Route

`backend/app/api/routes/videos.py`, prefix `/videos`, đăng ký trong `create_app()` (danh sách router hiện có 10 cái).

### `POST /api/v1/videos/roadmap` — có auth

1. Đọc `UserRepo` của người dùng (kèm `repo`).
2. Rỗng → `AppError(400, BAD_REQUEST)`.
3. Sinh `job_id = uuid4().hex`.
4. Dựng spec (§6).
5. Gọi `video_client.render(spec)`.
6. Ghi một dòng `GeneratedVideo`.
7. Trả:

```json
{
  "job_id": "...",
  "url": "/api/v1/videos/<job_id>",
  "duration_seconds": 12.4,
  "size_bytes": 1834021
}
```

Đường dẫn lệch tài liệu (`POST /api/v1/users/me/roadmap-video` → `POST /api/v1/videos/roadmap`). Tài liệu ghi "Ví dụ:", và backend này dùng prefix phẳng một-router-một-tính-năng (`/learning`, `/stats`, `/repos`) — không có router `/users/me` nào.

### `GET /api/v1/videos/{job_id}` — KHÔNG auth

```python
@router.get("/{job_id}")
def get_video(job_id: str):
    if not re.fullmatch(r"[A-Za-z0-9_-]{1,64}", job_id):
        raise AppError(404, ErrorCode.NOT_FOUND, "Không tìm thấy video")
    path = Path(settings.video_output_dir) / f"{job_id}.mp4"
    if not path.is_file():
        raise AppError(404, ErrorCode.NOT_FOUND, "Không tìm thấy video")
    return FileResponse(path, media_type="video/mp4")
```

Chặn path traversal bằng regex **trước khi** chạm filesystem. `FileResponse` của Starlette hỗ trợ `Range` sẵn nên thẻ `<video>` seek được.

## 9. Test

- `backend/tests/test_video_spec.py` — hàm thuần: mọi ràng buộc độ dài, cắt chuỗi, ca 0 repo, số slide sau khi lọc, `StatSlide.value` là chuỗi.
- `backend/tests/test_videos.py` — route với `httpx.MockTransport` giả engine và `tmp_path` cho thư mục video. Ca: render thành công, engine timeout → 504, engine lỗi → 502, lộ trình rỗng → 400, `GET` job_id không tồn tại → 404, `GET` job_id sai định dạng → 404.

Theo layout `backend/tests/` hiện có (`conftest.py` cung cấp `db`, `app`, `client`, `user`, `auth_headers`).

## 10. Ngoài phạm vi vòng này

- Cron "Repo of the Day" + sửa `RepoOut`/`get_feed` (D6).
- Toàn bộ Flutter: player 9:16, loading UX, `share_plus`.
- S3/CDN, xác thực cho URL video, dọn file cũ.
- `python-multipart` — không cần, vì không có endpoint upload.

## 11. Rủi ro đã biết

- Request render đầu tiên ngay sau `docker compose up` có thể nhận 502 nếu engine chưa boot xong (đã chấp nhận, xem §3).
- `get_db` không có autocommit: dòng `GeneratedVideo` và file trên đĩa không nằm trong cùng một giao dịch. Nếu ghi DB lỗi sau khi render xong, file mồ côi còn lại trên volume — chấp nhận được ở quy mô đồ án.
- Không có cơ chế dọn file cũ; volume `video_data` phình dần.