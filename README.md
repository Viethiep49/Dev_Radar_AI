# Dev Radar AI

Đồ án môn **CMP177 – Lập trình trên thiết bị di động**. Yêu cầu chi tiết: [YEU_CAU_DO_AN.md](YEU_CAU_DO_AN.md).

## Cấu trúc repo

| Thư mục | Nội dung | Phụ trách |
|---|---|---|
| `mobile/` | App Flutter (Dart) | Frontend ×2 |
| `backend/` | REST API (chạy bằng Docker) | Backend |
| `ai-engine/` | Service AI (chạy bằng Docker, chỉ backend gọi vào) | AI |
| `docker-compose.yml` | Chạy DB + backend + AI engine cùng lúc | Backend |

```
Flutter app ──HTTP──▶ backend ──▶ ai-engine
                        │
                        └──▶ database
```

## Chạy server (backend + AI + DB)

Yêu cầu: Docker Desktop (Windows cần bật WSL2).

```bash
cp .env.example .env      # rồi điền giá trị thật
docker compose up --build
```

## Chạy app Flutter

```bash
cd mobile
flutter pub get
flutter run
```

Địa chỉ backend khi chạy app:
- Android emulator: `http://10.0.2.2:8080`
- Điện thoại thật: `http://<IP LAN của máy chạy Docker>:8080` (cùng Wi-Fi)

## Quy trình làm việc

Xem [CONTRIBUTING.md](CONTRIBUTING.md).
