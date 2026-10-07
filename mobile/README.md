# mobile – App Flutter (DevRadar AI)

Dự án Flutter cho ứng dụng **DevRadar AI**, được thiết kế theo đúng yêu cầu đề cương môn học CMP177 và tài liệu [DE_XUAT_DE_TAI.md](../DE_XUAT_DE_TAI.md).

---

## 1. Cấu trúc mã nguồn

Phân lớp **UI → Bloc/Cubit → Repository → DataSource**: màn hình không gọi API trực tiếp.

```
lib/
├── core/            # constants (API), database (SQLite), network (Dio + refresh token),
│                    # notifications (local), routes (go_router), theme, utils (secure storage)
├── data/
│   ├── datasources/ # remote/ (REST API), local/ (cache SQLite)
│   ├── models/
│   ├── repositories/# network-first + cache (cache_policy.dart)
│   └── services/    # đăng nhập Google/GitHub, cảnh báo release
├── presentation/
│   ├── screens/     # auth, onboarding, home, search, detail, chat, collections, notes,
│   │                # stats, notifications, watchlist, settings
│   ├── state/       # Bloc/Cubit theo tính năng
│   └── widgets/
└── main.dart        # composition root: tạo repository, provider, router
test/                # unit + bloc + widget test (135 test)
```

## 2. Cách chạy

```bash
flutter pub get
flutter run                     # Android emulator: backend http://10.0.2.2:8080
flutter run -d chrome           # web: http://localhost:8080
# Backend ở cổng khác / điện thoại thật:
flutter run --dart-define=API_BASE_URL=http://<IP-LAN>:8080
flutter analyze && flutter test
```

Nếu `.env` đặt `BACKEND_PORT` khác 8080 (ví dụ 8081 khi cổng 8080 bị chiếm), chạy với
`--dart-define=API_BASE_URL=http://localhost:8081` (web) hoặc `http://10.0.2.2:8081` (emulator).

Tài khoản demo (sau khi chạy `python -m scripts.seed` trong backend): `demo@devradar.dev` / `demo1234`.

## 3. Đăng nhập Google / GitHub

Code đã có sẵn; chỉ cần dán key vào `.env` ở thư mục gốc (`GOOGLE_CLIENT_IDS`, `GITHUB_CLIENT_ID`,
`GITHUB_CLIENT_SECRET`, `GITHUB_REDIRECT_URI=devradar://oauth/github`) rồi build lại backend.
App tự lấy client ID công khai từ `GET /api/v1/auth/oauth/providers`. Chưa có key thì nút báo
"chưa được cấu hình". Hướng dẫn tạo key: [backend/docs/OAUTH_LOGIN.md](../backend/docs/OAUTH_LOGIN.md).
