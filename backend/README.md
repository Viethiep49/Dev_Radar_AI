# backend – REST API

## Chạy backend

FastAPI + SQLAlchemy + PostgreSQL. Quy ước API cho FE và các feature: [docs/API_CONVENTIONS.md](docs/API_CONVENTIONS.md).

### Chạy test (không cần Docker)

```bash
cd backend
py -3.12 -m venv .venv
.venv\Scripts\python -m pip install -r requirements-dev.txt    # macOS/Linux: .venv/bin/python
.venv\Scripts\python -m pytest -q
```

Test dùng SQLite in-memory, không cần PostgreSQL.

### Chạy cả server bằng Docker

```bash
# ở thư mục gốc repo
cp .env.example .env          # rồi sửa JWT_SECRET, GITHUB_TOKEN...
docker compose up --build -d db backend
docker compose exec backend python -m scripts.seed    # tạo user demo@devradar.dev / demo1234 (chạy lại nhiều lần không sao)
```

- Khi khởi động, container tự chạy `alembic upgrade head` rồi mới chạy API.
- Swagger: <http://localhost:8080/docs> – bấm **Authorize** và dán `access_token` để thử API cần đăng nhập.
- Kiểm tra: <http://localhost:8080/health> → `{"status":"ok"}`.
- **Cổng bị chiếm?** Nếu máy đã có PostgreSQL (5432) hoặc app khác (8080), đặt trong `.env`
  `DB_PORT=5433` và `BACKEND_PORT=8081` rồi dùng <http://localhost:8081>. Bên trong Docker vẫn là 5432 / 8080.
- Dừng: `docker compose down` (thêm `-v` nếu muốn xoá luôn dữ liệu DB).

### Chạy API trực tiếp trên máy (không Docker cho backend)

```bash
docker compose up -d db
cd backend
set DATABASE_URL=postgresql+psycopg://devradar:change_me@localhost:5432/devradar   # PowerShell: $env:DATABASE_URL="..."
.venv\Scripts\alembic upgrade head
.venv\Scripts\python -m scripts.seed
.venv\Scripts\uvicorn app.main:app --reload --port 8080
```

### Cấu trúc thư mục

```
app/
  main.py          tạo app, gắn router /api/v1, xử lý lỗi, CORS, scheduler
  core/            config (.env), security (bcrypt, JWT), errors (định dạng lỗi), pagination
  db/              Base, engine, SessionLocal, get_db
  models/          toàn bộ bảng
  schemas/         pydantic request/response
  api/deps.py      get_current_user
  api/routes/      mỗi file một router
  services/        gọi GitHub / AI engine, logic nghiệp vụ
  jobs/            cron job (APScheduler)
alembic/           migration DB
scripts/seed.py    dữ liệu demo
tests/             pytest
```

Đổi model → tạo migration mới: `alembic revision --autogenerate -m "..."` (chạy khi DB đang bật), đọc lại file sinh ra rồi `alembic upgrade head`.

---

Ghi chú thiết kế và kế hoạch cho phần Backend.

> Môn học chấm **app Flutter**. Backend không được chấm trực tiếp nhưng là thứ FE và AI phải dựa vào.
> Mục tiêu: **API ổn định, có sớm, dễ dùng** – không cần kiến trúc phức tạp.

---

## 1. Phạm vi

| Mảng | Việc |
|---|---|
| Xác thực | Đăng ký, đăng nhập, JWT (access + refresh), hash mật khẩu |
| Dữ liệu repo | Cron lấy dữ liệu GitHub, lưu DB, API feed / tìm kiếm / chi tiết |
| Dữ liệu người dùng | CRUD bộ sưu tập, ghi chú, trạng thái học, sở thích, watchlist |
| Thống kê | API trả số liệu sẵn cho FE vẽ biểu đồ |
| Cầu nối AI | Gọi AI engine sinh tóm tắt; chuyển câu hỏi chat từ app sang AI |
| Thông báo | Kiểm tra release mới của repo được theo dõi → gửi push qua FCM |
| Hạ tầng | Dockerfile, docker-compose, `.env`, script seed dữ liệu |

**Không thuộc backend:** Local notification nhắc học (FE tự làm trên máy).

---

## 2. Công nghệ (cần chốt)

- **Ngôn ngữ / framework:** đề xuất **FastAPI (Python)** – cùng ngôn ngữ với AI engine, tự sinh tài liệu Swagger, gọi GitHub dễ. Nếu quen JS/TS hơn thì NestJS / Express cũng được – ưu tiên thứ đã biết.
- **Database:** PostgreSQL (dùng chung container với AI engine, AI dùng schema riêng + pgvector).
- **Cron:** chạy ngay trong backend (ví dụ APScheduler), không tách service.
- **Push:** Firebase Admin SDK (chỉ dùng FCM).
- Cổng mặc định: `8080`.

---

## 3. Database

### Người dùng
| Bảng | Nội dung |
|---|---|
| `users` | email, mật khẩu đã hash, tên hiển thị, ngày tạo |
| `user_preferences` | ngôn ngữ / lĩnh vực quan tâm (chọn lúc onboarding) |
| `device_tokens` | FCM token của từng thiết bị của user |

### Repo (dữ liệu chung, cron cập nhật)
| Bảng | Nội dung |
|---|---|
| `repos` | tên, owner, mô tả, sao, fork, ngôn ngữ, license, topics, avatar owner, ngày cập nhật |
| `repo_summaries` | tóm tắt AI + Quickstart, thời điểm tạo |
| `repo_star_snapshots` | số sao theo ngày → biểu đồ sao theo thời gian |
| `repo_releases` | tag release mới nhất đã thấy → phát hiện release mới |

### Dữ liệu cá nhân (CRUD)
| Bảng | Nội dung |
|---|---|
| `collections` | bộ sưu tập của user |
| `collection_items` | repo nằm trong bộ sưu tập nào |
| `user_repos` | trạng thái học (muốn thử / đang tìm hiểu / đã dùng) + `started_at`, `completed_at` |
| `notes` | ghi chú của user cho từng repo |
| `watchlist` | repo user đang theo dõi |

### Khác
| Bảng | Nội dung |
|---|---|
| `notifications` | lịch sử thông báo đã gửi cho user, trạng thái đã đọc |
| `chat_messages` | lịch sử chat theo user + repo |

### ⚠️ Lưu ý
- **GitHub không cung cấp lịch sử số sao.** Biểu đồ chỉ có dữ liệu từ ngày cron bắt đầu chụp → **bật cron càng sớm càng tốt**, hoặc có dữ liệu seed.
- Biểu đồ "số repo đã tìm hiểu mỗi tuần" cần **thời điểm** chuyển trạng thái → bắt buộc lưu `completed_at`.

---

## 4. API (sơ bộ)

| Nhóm | Chức năng |
|---|---|
| Auth | đăng ký, đăng nhập, refresh token, `/me`, đăng ký FCM token thiết bị |
| Sở thích | xem, sửa lĩnh vực quan tâm |
| Repo | feed theo sở thích (phân trang), tìm kiếm + lọc + sắp xếp, chi tiết, tóm tắt AI, lịch sử sao |
| Bộ sưu tập | tạo, danh sách, chi tiết, sửa, xoá; thêm / gỡ repo |
| Ghi chú | tạo, xem, sửa, xoá |
| Trạng thái học | đặt / đổi trạng thái của một repo |
| Thống kê | theo trạng thái, theo tuần, theo ngôn ngữ |
| Watchlist | theo dõi, bỏ theo dõi, danh sách |
| Thông báo | danh sách, đánh dấu đã đọc |
| Chat | gửi câu hỏi về repo, xem lịch sử |

Chi tiết request / response sẽ viết trong tài liệu OpenAPI (Swagger).

### Quy ước chung (thống nhất với FE)
- **Viết hợp đồng API trước khi code** để FE làm song song.
- **Một định dạng lỗi chung** cho mọi API (mã lỗi + thông báo) → FE xử lý lỗi thống nhất.
- **Phân trang:** `page` + `limit`.
- **Ngày giờ:** ISO 8601, UTC.
- Có **dữ liệu seed** sớm để FE hiển thị.

---

## 5. Cron job

| Job | Tần suất | Việc |
|---|---|---|
| Lấy repo nổi bật | 6–12 giờ | Gọi GitHub Search API theo lĩnh vực, cập nhật `repos`. Repo mới → nhờ AI tóm tắt + index cho chat |
| Chụp số sao | 1 lần/ngày | Ghi số sao hiện tại vào `repo_star_snapshots` |
| Kiểm tra release | 1 giờ | Repo có người theo dõi, có tag mới → tạo thông báo + gửi FCM |

### Lưu ý GitHub API
- **Không có API "trending"** → dùng Search API (ví dụ: repo tạo trong 7 ngày gần đây, sắp xếp theo sao).
- Search API giới hạn khoảng **30 request/phút** kể cả có token → gọi tuần tự, có nghỉ giữa các lần.
- `GITHUB_TOKEN` chỉ nằm trong `.env`, không commit.

---

## 6. Ranh giới với AI engine

- **Backend:** quản lý DB chính, lấy dữ liệu GitHub, là **đầu mối duy nhất** app gọi vào.
- **AI engine** (service nội bộ, app không gọi trực tiếp) cung cấp:
  - **Tóm tắt:** nhận README → trả tóm tắt + Quickstart.
  - **Index:** nhận README + docs → tự chia đoạn, tạo embedding, lưu.
  - **Chat:** nhận câu hỏi + mã repo → trả lời kèm đoạn nguồn.
- Bảng embedding thuộc AI engine (chung PostgreSQL, **schema riêng**) – backend không đụng vào.
- LLM API key chỉ nằm ở AI engine.
- Chat có thể mất 5–15 giây → backend đặt **timeout** khi gọi AI và trả lỗi rõ ràng ("AI đang bận, thử lại").

---

## 7. Firebase (chỉ dùng FCM cho push)

> ⏸ **Để sau** – làm và kiểm tra ở giai đoạn gần bảo vệ. Trước đó chỉ cần lưu thông báo vào bảng `notifications` (app vẫn xem được danh sách), chưa gửi push.

- Firebase **chỉ dùng để gửi push notification**, không dùng làm DB hay đăng nhập.
- Luồng: `Backend phát hiện release mới → FCM (Google) → điện thoại hiện thông báo`.
- Miễn phí. **Chạy được với server local** vì backend chỉ gửi ra ngoài, Google không cần gọi vào.
- Một người tạo project Firebase chung:
  - FE lấy file cấu hình cho app.
  - Backend lấy **service account** để gửi push – file này **để ngoài git**.
- iOS cần tài khoản Apple Developer trả phí → **demo trên Android**.
- Token FCM thay đổi / hết hạn → khi gửi lỗi thì xoá token đó khỏi `device_tokens`.

---

## 8. Chạy local và demo

Server chạy local bằng `docker compose up` – dùng được cả khi phát triển lẫn khi demo.

### Kết nối app → server
| Cách | Độ an toàn khi demo |
|---|---|
| Emulator trên chính laptop chạy server, gọi `http://10.0.2.2:8080` | ⭐ An toàn nhất |
| Điện thoại thật + laptop cùng bắt **hotspot điện thoại**, gọi IP LAN của laptop | Ổn |
| Điện thoại thật qua **Wi-Fi trường** | ⚠️ Rủi ro – Wi-Fi trường thường chặn các máy thấy nhau |
| **Cloudflare Tunnel / ngrok** tạo URL public tới laptop | Dự phòng tốt |

### ⚠️ Lưu ý
1. **Vẫn cần Internet** (GitHub, LLM, FCM). Trước demo: chạy sẵn cron để có tóm tắt trong DB, thử trước vài câu chat.
2. **Cron chỉ chạy khi laptop bật** → dữ liệu sao bị thiếu ngày. Xử lý: script seed dữ liệu cho các repo dùng khi demo, hoặc giai đoạn cuối chạy trên server thuê / free tier.
3. **Android chặn `http://` mặc định** → FE phải bật cleartext cho bản debug, nếu không app báo lỗi mạng khó hiểu. **Dặn FE từ đầu.**
4. **Mỗi người chạy Docker có DB riêng** → viết **script seed** (tài khoản test + vài chục repo) để ai chạy cũng thấy cùng dữ liệu.

---

## 9. Kế hoạch thực hiện

1. **Mở đường cho FE:** chốt stack, thiết kế DB, viết hợp đồng API, Docker chạy được DB, script seed.
2. **Xác thực:** đăng ký / đăng nhập / JWT (FE 1 cần đầu tiên).
3. **Cron GitHub + API repo** (feed, tìm kiếm, chi tiết). **Bật cron chụp sao ngay từ đây.**
4. **CRUD** bộ sưu tập, ghi chú, trạng thái học + **API thống kê** (FE 2 cần).
5. **Nối AI engine:** tóm tắt + chat.
6. **Watchlist + kiểm tra release + danh sách thông báo** (chỉ lưu DB, chưa gửi push).
7. **Hoàn thiện:** test các API chính, dữ liệu demo, README hướng dẫn chạy.
8. **Gần bảo vệ:** tạo project Firebase, gửi push FCM khi có release mới, test trên máy Android thật, chạy thử kịch bản demo.

---

## 10. Việc cần chốt

- [ ] Ngôn ngữ / framework backend
- [ ] Ranh giới API với AI engine (mục 6) – chốt với bạn AI
- [ ] Hợp đồng API + định dạng lỗi – chốt với 2 bạn FE
- [ ] Ai tạo project Firebase *(để gần bảo vệ)*
- [ ] Cách chạy khi demo (emulator / hotspot / tunnel)

---

## 11. Checklist khi bắt đầu code

- [ ] `Dockerfile` – lắng nghe cổng `8080`
- [ ] Đọc cấu hình từ biến môi trường: `DATABASE_URL`, `AI_ENGINE_URL`, `JWT_SECRET`, `GITHUB_TOKEN` (service account Firebase thêm sau, khi làm FCM)
- [ ] Cập nhật `.env.example` khi thêm biến mới
- [ ] Bỏ comment service `backend` trong `docker-compose.yml`
