# DevRadar AI

Ứng dụng di động theo dõi xu hướng công nghệ và trợ lý tìm hiểu mã nguồn mở.
Đồ án môn **CMP177 – Lập trình trên thiết bị di động** · Lớp 23DTHD5.

Đề xuất: [DE_XUAT_DE_TAI.md](DE_XUAT_DE_TAI.md) · Yêu cầu: [YEU_CAU_DO_AN.md](YEU_CAU_DO_AN.md) ·
Báo cáo: [bao_cao/BAO_CAO_DO_AN_DEVRADAR_AI.docx](bao_cao/BAO_CAO_DO_AN_DEVRADAR_AI.docx) ·
Slide: [bao_cao/SLIDE_DO_AN_DEVRADAR_AI.pptx](bao_cao/SLIDE_DO_AN_DEVRADAR_AI.pptx)

## Chạy nhanh (Windows)

1. Mở **Docker Desktop**.
2. Bấm đúp **`run.bat`** → chọn **1** Chrome · **2** máy ảo Android · **3** điện thoại thật · **4** chỉ bật server.
3. Đăng nhập: `demo@devradar.dev` / `demo1234`.

| Lệnh | Tác dụng |
|---|---|
| `run.bat` | DB + backend (Docker), nạp dữ liệu demo, chạy app |
| `run.bat ai` | thêm AI engine + Ollama (tóm tắt / chat AI thật, nên có GPU NVIDIA) |
| `run.bat stop` | tắt các container |

<details>
<summary>Chạy thủ công</summary>

```bash
copy .env.example .env                       # BACKEND_PORT, khoá OAuth (tuỳ chọn)
docker compose up -d --build db backend      # thêm ai-engine ollama để có AI thật
docker compose -f docker-compose.yml -f docker-compose.cpu.yml up -d   # máy không có GPU
docker compose exec backend python -m scripts.seed                     # dữ liệu demo

cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080    # emulator (localhost:8080 trên web)
```

API docs: `http://localhost:<BACKEND_PORT>/docs`. Đăng nhập Google/GitHub: dán khoá vào `.env`
theo [backend/docs/OAUTH_LOGIN.md](backend/docs/OAUTH_LOGIN.md).
</details>

## Đáp ứng yêu cầu đồ án

| Yêu cầu | Đáp ứng |
|---|---|
| Flutter / Dart | Flutter 3.47, Dart 3.13 – thư mục `mobile/` |
| Cấu trúc phân lớp | `lib/core` · `lib/data` (models, repositories, datasources) · `lib/presentation` (screens, widgets, state) |
| UI đồng bộ, responsive, animation | Một theme sáng/tối; widget test 320×640; chuyển trang fade/slide, Hero, skeleton loading, biểu đồ động |
| Quản lý trạng thái | **BLoC** (`flutter_bloc`): Bloc + Cubit cho từng tính năng |
| Tách UI và logic | UI → Bloc/Cubit → Repository → DataSource; màn hình không gọi API |
| Xử lý lỗi API + cache | Timeout / mất mạng / lỗi server có thông báo + **Thử lại**; cache **SQLite** network-first |
| Kiểm thử | 135 test Flutter (unit, bloc, widget) · 240 test backend · 15 test AI engine |
| CRUD | Bộ sưu tập, ghi chú (tạo / xem / sửa / xoá), lộ trình học |
| Cốt lõi – Quản lý cá nhân | **Thống kê**: biểu đồ tròn theo trạng thái, cột theo tuần, top ngôn ngữ |
| Bảo mật | Đăng ký / đăng nhập (email, Google, GitHub + PKCE), JWT tự làm mới, token trong secure storage |
| Thông báo | Local notification: release mới của repo theo dõi, nhắc học hằng ngày |
| Tìm kiếm | Tìm repo (lọc ngôn ngữ, chủ đề, sắp xếp); tìm trong bộ sưu tập và ghi chú |
| Lưu trữ Local + Cloud | SQLite (`sqflite`) + REST API tự xây dựng (PostgreSQL) |

## Chức năng

- **Khám phá:** feed "Dành cho bạn" theo sở thích, nhãn Hot, kéo làm mới, cuộn vô hạn.
- **Chi tiết repo:** sao, fork, license, biểu đồ sao 30 ngày, tóm tắt AI, Quickstart, README, mở GitHub.
- **Chat với repo:** hỏi đáp RAG trên README, có trích dẫn nguồn, lưu lịch sử.
- **Cá nhân:** bộ sưu tập, ghi chú, lộ trình *Muốn thử → Đang tìm hiểu → Đã sử dụng*, theo dõi repo.
- **Khác:** onboarding chọn sở thích, danh sách thông báo, cài đặt (giao diện, giờ nhắc, xoá cache, đổi mật khẩu).

## Kiến trúc

```
Flutter App ──REST──▶ Backend (FastAPI, JWT, cron) ──▶ AI Engine (Ollama, RAG)
 BLoC · SQLite              │                                 │
                            └────── PostgreSQL 16 + pgvector ─┘   ◀── GitHub API (cron)
```

| Thư mục | Nội dung |
|---|---|
| `mobile/` | App Flutter – xem [mobile/README.md](mobile/README.md) |
| `backend/` | REST API FastAPI, SQLAlchemy, Alembic, APScheduler |
| `ai-engine/` | Tóm tắt README + RAG (sentence-transformers, pgvector, Ollama) |
| `video-engine/` | Dịch vụ tạo video (backend gọi qua `VIDEO_ENGINE_URL`) – [VIDEO_GENERATOR.md](VIDEO_GENERATOR.md) |
| `bao_cao/` | Báo cáo, slide và script dựng lại (`tao_bao_cao/`, `tao_slide/`) |

## Kiểm thử

```bash
cd mobile && flutter analyze && flutter test        # 147 test
cd backend && pytest                                 # 276 test
cd ai-engine && pytest tests                         # 21 test
cd video-engine && pytest                            # 38 test
```

Quy trình làm việc nhóm: [CONTRIBUTING.md](CONTRIBUTING.md).
