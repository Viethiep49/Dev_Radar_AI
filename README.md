# Dev Radar AI

Đồ án môn **CMP177 – Lập trình trên thiết bị di động**. Yêu cầu chi tiết: [YEU_CAU_DO_AN.md](YEU_CAU_DO_AN.md).

## Cấu trúc repo

| Thư mục | Nội dung | Phụ trách |
|---|---|---|
| `mobile/` | App Flutter (Dart) | Frontend ×2 |
| `backend/` | REST API (chạy bằng Docker) | Backend |
| `ai-engine/` | Service AI (chạy bằng Docker, chỉ backend gọi vào) | AI |
| `docker-compose.yml` | Chạy DB + backend + AI engine cùng lúc | Backend |



## Chạy nhanh (Windows) – bấm đúp `run.bat`

1. Mở **Docker Desktop**.
2. Bấm đúp `run.bat` ở thư mục gốc (hoặc gõ `run.bat` trong terminal). Script tự:
   tạo `.env` nếu chưa có → bật DB + backend bằng Docker → đợi server sẵn sàng → nạp dữ liệu demo
   → hỏi chạy app ở đâu: **1** Chrome · **2** máy ảo Android (tự bật AVD `devradar_api36`) · **3** điện thoại thật cùng Wi-Fi · **4** chỉ bật server.
3. Đăng nhập bằng tài khoản demo `demo@devradar.dev` / `demo1234`.

| Lệnh | Tác dụng |
|---|---|
| `run.bat` | DB + backend + chạy app |
| `run.bat ai` | thêm AI engine + Ollama (tóm tắt/chat AI thật, nên có GPU) |
| `run.bat stop` | tắt các container |

Cổng backend lấy từ `BACKEND_PORT` trong `.env` (máy đang bị chiếm cổng 8080 thì đặt 8081); app tự dùng đúng cổng.

## Chạy server (backend + AI + DB)

Yêu cầu: Docker Desktop (Windows cần bật WSL2).



### GPU

AI engine dùng Ollama để sinh câu trả lời. Để `/chat` trả lời **dưới 30 giây** (khớp timeout của backend), mặc định compose yêu cầu **GPU NVIDIA**.

- **Máy có GPU NVIDIA**: cần cài driver NVIDIA + [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html), rồi chạy lệnh ở trên.
- **Máy không có GPU (chỉ để thử)**: dùng override CPU — Ollama sẽ chạy bằng CPU và **chậm hơn nhiều**:



## Chạy app Flutter



Địa chỉ backend khi chạy app:
- Android emulator: `http://10.0.2.2:8080`
- Điện thoại thật: `http://<IP LAN của máy chạy Docker>:8080` (cùng Wi-Fi)

## Quy trình làm việc

Xem [CONTRIBUTING.md](CONTRIBUTING.md).
