# Hướng dẫn Tích hợp Video Engine dành cho Backend Team

Tài liệu này quy định rõ nhiệm vụ, luồng hoạt động và đặc tả kỹ thuật chi tiết để Backend Service tương tác với **Video Engine** (dịch vụ AI render video nội bộ).

---

## 1. Nhiệm vụ của Backend Team
1. **Quản lý Trigger:** Chủ động kích hoạt quá trình tạo video cho các chức năng "Lộ trình của tôi" (User trigger) và "Repo of the Day" (Cronjob tự động).
2. **Quản lý File & Storage:** Video Engine lưu file mp4 trực tiếp vào volume dùng chung (`/data/videos`). Backend phải đọc file này, tải lên Cloud Storage (S3 / CDN) để phục vụ public.
3. **Quản lý Vòng đời (Lifecycle):** Xử lý lưu trữ metadata (thời lượng, kích thước file, URL CDN) vào Database để trả về cho Frontend.
4. **Xử lý Timeout:** Vì endpoint sinh video là **đồng bộ (Synchronous)** và tốn nhiều thời gian (30s - 1 phút), Backend cần cấu hình HTTP Client có Timeout đủ dài và xem xét chạy Background Job (VD: Celery) để không block Request của Frontend.

---

## 2. Cách thức hoạt động
1. Backend nhận tín hiệu từ Frontend (hoặc từ Cronjob ban đêm).
2. Backend gom nhặt dữ liệu repo, lộ trình học tập, thống kê... của User từ Database.
3. Chuyển đổi dữ liệu thành cấu trúc JSON `VideoSpec`.
4. Gọi HTTP `POST` sang Video Engine qua mạng nội bộ Docker.
5. Đợi Video Engine xử lý xong và trả về đường dẫn vật lý (vd: `/data/videos/abc.mp4`).
6. Upload file đó lên S3, nhận CDN URL, lưu vào DB và trả CDN URL cho Frontend.

---

## 3. Endpoint Chi tiết (Video Engine API)

Video Engine không bộc lộ ra Internet, chỉ được truy cập nội bộ thông qua hostname `video-engine`.

### `POST http://video-engine:9000/render`

**Mô tả:** Endpoint đồng bộ, tiếp nhận kịch bản (`VideoSpec`) và trả về kết quả sinh file.

**Yêu cầu Payload (JSON):**
* `job_id` (string): Mã định danh duy nhất (chỉ gồm chữ, số, gạch ngang, gạch dưới, tối đa 64 ký tự). Dùng làm tên file mp4.
* `title` (string): Tiêu đề job.
* `quality` (string): `"720p"` hoặc `"1080p"`. (Mặc định dùng 720p cho nhẹ).
* `slides` (Array of Objects): Danh sách các slide cấu thành video. Tối thiểu 2 slide, tối đa 8 slide.

Các loại slide được hỗ trợ (`kind`):
1. **HookSlide (`kind: "hook"`):** Slide mở đầu. Gồm `title`, `subtitle` (tùy chọn) và `narration`.
2. **StatSlide (`kind: "stat"`):** Slide khoe chỉ số. Gồm `label`, `value`, `unit` (tùy chọn) và `narration`.
3. **ListSlide (`kind: "list"`):** Slide danh sách. Gồm `title`, mảng `items` (2-4 dòng), `narration`.
4. **RepoSlide (`kind: "repo"`):** Slide chi tiết Github Repo. Gồm `full_name`, `description`, `language`, `stars`, `stars_gained` (tùy chọn), `narration`.
5. **OutroSlide (`kind: "outro"`):** Slide kết thúc. Gồm `title`, `subtitle` và `narration`.

**Lưu ý cực kỳ quan trọng về `narration`:** 
Tất cả các slide BẮT BUỘC phải có trường `narration` (tối đa 300 ký tự). Nội dung này sẽ được AI đọc thành giọng nói tiếng Việt chuẩn xác. Nếu viết số, AI sẽ tự động đọc thành chữ (VD: `12` -> `mười hai`). 

**Ví dụ Payload:**
```json
{
  "job_id": "roadmap_user_123_oct2026",
  "title": "Lộ trình tháng 10",
  "quality": "720p",
  "slides": [
    {
      "kind": "hook",
      "title": "Tổng kết Tháng 10",
      "subtitle": "Xin chào Saket",
      "narration": "Xin chào Saket, đây là tổng kết lộ trình tháng 10 của bạn."
    },
    {
      "kind": "repo",
      "full_name": "tiangolo/fastapi",
      "description": "FastAPI framework, high performance",
      "language": "Python",
      "stars": 75000,
      "stars_gained": 345,
      "narration": "Repo đáng chú ý nhất tháng này của bạn là fast api với ba trăm bốn mươi lăm sao tăng thêm."
    }
  ]
}
```

**Ví dụ Response (`200 OK`):**
```json
{
  "path": "/data/videos/roadmap_user_123_oct2026.mp4",
  "duration_seconds": 15.3,
  "size_bytes": 1048576
}
```

**Các lỗi thường gặp:**
- `422 Unprocessable Entity`: Sai định dạng Payload (VD: `job_id` chứa ký tự đặc biệt, text quá dài).
- `503 Service Unavailable`: Dịch vụ quá tải hoặc thư viện lõi gặp trục trặc (hiếm gặp).
