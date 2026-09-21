# mobile – App Flutter

Chưa khởi tạo project Flutter. Người đầu tiên chạy (trong thư mục `mobile/`):

```bash
flutter create --org com.devradar --project-name dev_radar_ai .
```

Lệnh này giữ nguyên các thư mục có sẵn trong `lib/`. Sau đó xoá các file `.gitkeep` ở thư mục đã có code.

## Cấu trúc `lib/`

```
lib/
├── core/                 # dùng chung
│   ├── routes/           # điều hướng
│   ├── theme/            # màu, font, ThemeData
│   ├── constants/        # base URL, key...
│   ├── network/          # HTTP client, xử lý timeout / mất mạng
│   └── utils/
├── data/
│   ├── models/           # model + fromJson/toJson
│   ├── repositories/     # kết hợp remote + local (cache)
│   └── datasources/
│       ├── remote/       # gọi REST API backend
│       └── local/        # SQLite
└── presentation/
    ├── screens/
    ├── widgets/
    └── state/            # Provider / BLoC / GetX
```

`test/` – unit test cho repository và state.
