# mobile – App Flutter (DevRadar AI)

Dự án Flutter cho ứng dụng **DevRadar AI**, được thiết kế theo đúng yêu cầu đề cương môn học CMP177 và tài liệu [DE_XUAT_DE_TAI.md](../DE_XUAT_DE_TAI.md).

---

## 1. Cấu trúc mã nguồn

Mã nguồn được tổ chức theo mô hình phân lớp rõ ràng (Clean Layered Architecture):

```
lib/
├── core/                           # Thành phần dùng chung toàn ứng dụng
│   ├── constants/
│   │   └── api_constants.dart      # URL API, storage keys, timeouts
│   ├── network/
│   │   ├── api_client.dart         # Dio HTTP client, Auth Interceptor
│   │   └── api_exceptions.dart     # Xử lý lỗi mất mạng, timeout, unauthorized
│   ├── routes/
│   │   └── app_router.dart         # Điều hướng GoRouter (/splash, /login, /register, /home)
│   ├── theme/
│   │   ├── app_colors.dart         # Bảng màu DevRadar AI (Cyber Dark & Light)
│   │   └── app_theme.dart          # ThemeData, typography, Material 3
│   └── utils/
│       └── storage_service.dart    # Lưu JWT token & thông tin người dùng
├── data/                           # Lớp xử lý dữ liệu (Data Layer)
│   ├── datasources/
│   │   ├── local/                  # SQLite cache cục bộ
│   │   └── remote/
│   │       ├── auth_remote_datasource.dart  # Gọi API đăng nhập, đăng ký
│   │       └── repo_remote_datasource.dart  # Gọi API feed repo, tìm kiếm
│   ├── models/
│   │   ├── auth_response_model.dart
│   │   ├── repo_model.dart
│   │   └── user_model.dart
│   └── repositories/
│       ├── auth_repository.dart    # Logic xác thực và lưu token
│       └── repo_repository.dart    # Logic lấy repo (kết hợp remote + local cache)
├── presentation/                   # Lớp giao diện (Presentation Layer)
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── login_screen.dart   # Màn hình đăng nhập (có nút điền tài khoản demo)
│   │   │   └── register_screen.dart# Màn hình đăng ký
│   │   ├── collections/
│   │   │   └── collections_screen.dart # Quản lý bộ sưu tập (CRUD)
│   │   ├── home/
│   │   │   └── home_feed_screen.dart   # Feed xu hướng repo, lọc ngôn ngữ, pull-to-refresh
│   │   ├── main/
│   │   │   └── main_navigation_screen.dart # Shell BottomNavigationBar 4 tab
│   │   ├── search/
│   │   │   └── search_screen.dart  # Tìm kiếm repo
│   │   ├── splash/
│   │   │   └── splash_screen.dart  # Màn hình khởi động với animation radar
│   │   └── stats/
│   │       └── stats_screen.dart   # Biểu đồ thống kê học tập (PieChart & BarChart fl_chart)
│   ├── state/                      # Quản lý trạng thái bằng BLoC (flutter_bloc)
│   │   ├── auth/
│   │   │   ├── auth_bloc.dart
│   │   │   ├── auth_event.dart
│   │   │   └── auth_state.dart
│   │   └── repo/
│   │       ├── repo_bloc.dart
│   │       ├── repo_event.dart
│   │       └── repo_state.dart
│   └── widgets/
│       ├── custom_text_field.dart
│       ├── primary_button.dart
│       ├── radar_logo.dart         # Animation quét radar
│       └── repo_card.dart          # Thẻ hiển thị repo (Hot badge, sao, fork, ngôn ngữ)
└── main.dart                       # Khởi tạo DI, BLoC Providers và MaterialApp.router
```

---

## 2. Cách chạy ứng dụng

### Chạy trực tiếp từ thư mục gốc:
```bash
# Chạy script tương tác chọn thiết bị:
..\run_mobile.bat
```

### Hoặc chạy lệnh Flutter trong thư mục `mobile/`:
```bash
# Xem ngay trên trình duyệt (Chrome):
flutter run -d chrome

# Chạy trên máy ảo Android (Emulator) hoặc điện thoại cắm cáp:
flutter run -d android

# Kiểm tra phân tích mã nguồn (0 cảnh báo):
flutter analyze

# Chạy kiểm thử tự động:
flutter test
```

---

## 3. Kết nối với Backend

Ứng dụng tự động điều chỉnh địa chỉ Backend theo nền tảng đang chạy:
- **Trình duyệt (Web / Chrome):** `http://localhost:8080`
- **Máy ảo Android (Emulator):** `http://10.0.2.2:8080`
- **Điện thoại thật:** Điền IP máy tính trong mạng LAN tại [api_constants.dart](lib/core/constants/api_constants.dart).

Tài khoản demo sẵn có:
- **Email:** `demo@devradar.dev`
- **Mật khẩu:** `demo1234`
