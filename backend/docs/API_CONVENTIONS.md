# Quy ước API – DevRadar AI Backend

Tài liệu này là **hợp đồng chung** giữa backend, FE và các phần việc (feature) của backend.
Swagger đầy đủ (tự sinh): `http://localhost:8080/docs`.

---

## 1. Địa chỉ gốc

- Mọi API nằm dưới **`/api/v1`**, ví dụ `POST /api/v1/auth/login`.
- Riêng `GET /health` (không có prefix) → `{"status": "ok"}` để kiểm tra server sống.
- Android emulator gọi `http://10.0.2.2:8080/api/v1/...`.

## 2. Xác thực

- Đăng nhập / đăng ký trả về `access_token` (sống 30 phút) và `refresh_token` (sống 7 ngày).
- API cần đăng nhập: gửi header

  ```
  Authorization: Bearer <access_token>
  ```

- Access token hết hạn → gọi `POST /api/v1/auth/refresh` với `{"refresh_token": "..."}` để lấy cặp token mới.
- Thiếu / sai / hết hạn token → `401 UNAUTHORIZED`.

| Method | Đường dẫn | Mô tả |
|---|---|---|
| POST | `/api/v1/auth/register` | `{email, password (>= 6 ký tự), display_name}` → `201 {user, access_token, refresh_token, token_type}` |
| POST | `/api/v1/auth/login` | `{email, password}` → `200` cùng dạng như register |
| POST | `/api/v1/auth/refresh` | `{refresh_token}` → `200 {access_token, refresh_token, token_type}` |
| GET | `/api/v1/auth/me` | user đang đăng nhập |
| POST | `/api/v1/auth/device-tokens` | `{token, platform: android\|ios\|web}` → `201`, lưu FCM token (gửi lại cùng token thì cập nhật, không tạo trùng) |

## 3. Định dạng lỗi

**Mọi** lỗi đều có cùng dạng JSON:

```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "Repo not found",
    "details": null
  }
}
```

- FE dựa vào `code` để xử lý, `message` chỉ để debug / hiển thị tạm.
- Với `VALIDATION_ERROR`, `details` là danh sách trường sai:
  `[{"field": "body.password", "message": "String should have at least 6 characters"}]`

| HTTP | `code` | Khi nào |
|---|---|---|
| 400 | `BAD_REQUEST` | Yêu cầu không hợp lệ về mặt nghiệp vụ |
| 401 | `UNAUTHORIZED` | Chưa đăng nhập, token sai / hết hạn, sai mật khẩu |
| 403 | `FORBIDDEN` | Đã đăng nhập nhưng không có quyền (ví dụ sửa collection của người khác) |
| 404 | `NOT_FOUND` | Không tìm thấy dữ liệu hoặc đường dẫn |
| 409 | `CONFLICT` | Trùng dữ liệu (email đã đăng ký, repo đã có trong collection, ...) |
| 422 | `VALIDATION_ERROR` | Dữ liệu gửi lên sai kiểu / thiếu trường / sai giới hạn |
| 502 | `UPSTREAM_ERROR` | GitHub hoặc AI engine trả lỗi |
| 504 | `UPSTREAM_TIMEOUT` | GitHub hoặc AI engine quá chậm ("AI đang bận, thử lại") |
| 500 | `INTERNAL_ERROR` | Lỗi không lường trước của server |

Trong code backend, trả lỗi bằng cách:

```python
from app.core.errors import AppError, ErrorCode

raise AppError(404, ErrorCode.NOT_FOUND, "Repo not found")
```

## 4. Phân trang

- Tham số query: `page` (>= 1, mặc định 1), `limit` (1..100, mặc định 20).
- Kết quả dạng:

```json
{ "items": [ ... ], "page": 1, "limit": 20, "total": 137 }
```

Trong code:

```python
from app.core.pagination import Page, PageParams, paginate

@router.get("", response_model=Page[RepoOut])
def list_repos(params: PageParams = Depends(), db: Session = Depends(get_db)):
    stmt = select(Repo).order_by(Repo.stars.desc())
    return paginate(db, stmt, params)
```

(`RepoOut` cần `model_config = ConfigDict(from_attributes=True)`; nhớ luôn có `order_by`.)

## 5. Kiểu dữ liệu

- **Ngày giờ:** ISO 8601, **UTC**, ví dụ `"2026-09-21T13:52:55.608194Z"`. Ngày không giờ: `"2026-09-21"`.
  Trong code dùng `app.db.base.utcnow()`, không dùng `datetime.now()` không có múi giờ.
- **JSON:** tên trường dạng `snake_case` (`display_name`, `created_at`, ...).
- `id` là số nguyên.
- Tạo mới trả `201`, xoá thành công trả `204` (không có body).

## 6. Router và phần việc phụ trách

Tất cả router **đã được gắn sẵn trong `app/main.py`** – không ai cần sửa `main.py`.

| File router | Prefix | Phụ trách (feature) |
|---|---|---|
| `api/routes/auth.py` | `/auth` | Foundation (đã xong) |
| `api/routes/preferences.py` | `/preferences` | repos |
| `api/routes/repos.py` | `/repos` | repos |
| `api/routes/collections.py` | `/collections` | personal |
| `api/routes/notes.py` | `/notes` | personal |
| `api/routes/learning.py` | `/learning` | personal |
| `api/routes/stats.py` | `/stats` | personal |
| `api/routes/watchlist.py` | `/watchlist` | AI & thông báo |
| `api/routes/notifications.py` | `/notifications` | AI & thông báo |
| `api/routes/chat.py` | `/chat` | AI & thông báo |

File dùng chung khác theo feature:

| Feature | Service | Job | Khác |
|---|---|---|---|
| repos | `services/github_client.py`, `services/repo_service.py` | `jobs/repo_jobs.py` | `seed_repos()` trong `scripts/seed.py` |
| AI & thông báo | `services/ai_client.py` | `jobs/ai_jobs.py` (sinh tóm tắt → bảng `repo_summaries`), `jobs/release_jobs.py` | |
| personal | – | – | |

Dùng chung (mọi feature được import, không ai tự đổi): `schemas/repo_brief.py` (`RepoBrief`), `services/repo_service.py` → `get_repo_or_404`, chữ ký hàm trong `services/github_client.py` (feature repos viết phần thân).

Tóm tắt AI được lưu trong `repo_summaries`; router `/repos` chỉ **đọc** bảng này để trả về.

## 7. Cách một feature thêm endpoint

1. Chỉ sửa các file của mình: `api/routes/<router>.py`, `schemas/<router>.py`, service / job của mình, và test `tests/test_<router>.py`.
2. **Không** sửa `main.py`, `core/`, `db/`, `models/`, `api/deps.py`, `tests/conftest.py`. Bảng đã được tạo đủ trong `models/` và migration `0001`. Nếu thật sự cần đổi → báo người phụ trách foundation.
3. Mẫu endpoint:

```python
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.errors import AppError, ErrorCode
from app.db.session import get_db
from app.models import Note, User
from app.schemas.notes import NoteOut

router = APIRouter(prefix="/notes", tags=["notes"])

@router.get("/{note_id}", response_model=NoteOut)
def get_note(note_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    note = db.get(Note, note_id)
    if note is None or note.user_id != current_user.id:
        raise AppError(404, ErrorCode.NOT_FOUND, "Note not found")
    return note
```

4. Dữ liệu cá nhân luôn lọc theo `current_user.id`.
5. Test dùng fixture có sẵn trong `tests/conftest.py`: `client`, `db`, `user`, `auth_headers`.

```python
def test_list_notes(client, auth_headers):
    response = client.get("/api/v1/notes", headers=auth_headers)
    assert response.status_code == 200
```

Test chạy trên SQLite in-memory: lưu ý giá trị `DateTime` đọc lại từ SQLite **không có múi giờ** (PostgreSQL thì có).

## 8. Cách thêm cron job

Thêm vào danh sách `JOBS` trong module job của feature mình (`jobs/repo_jobs.py`, `jobs/ai_jobs.py`, `jobs/release_jobs.py`):

```python
from app.db.session import SessionLocal

def snapshot_stars_job() -> None:
    # Job không chạy trong request → tự mở session
    with SessionLocal() as db:
        snapshot_stars(db)   # logic thật nhận db → dễ test bằng fixture `db`
        db.commit()

JOBS = [
    {"id": "snapshot_stars", "func": snapshot_stars_job, "trigger": "cron", "kwargs": {"hour": 1, "minute": 0}},
    # interval: {"trigger": "interval", "kwargs": {"hours": 6}}
]
```

- `kwargs` được truyền thẳng vào `scheduler.add_job` (tham số trigger của APScheduler).
- Lỗi trong job được ghi log, **không** làm dừng scheduler (`jobs/scheduler.py`).
- Scheduler chỉ chạy khi `ENABLE_SCHEDULER=true` (mặc định bật trong docker-compose, tắt khi test).
- Gọi GitHub / AI thật chỉ trong service, test thì giả lập (monkeypatch), không gọi mạng thật.
