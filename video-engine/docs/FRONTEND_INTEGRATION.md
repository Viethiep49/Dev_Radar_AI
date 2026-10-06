# Hướng dẫn Tích hợp Video Feature dành cho Frontend Team

Tài liệu này quy định rõ nhiệm vụ, luồng trải nghiệm (UX) và kỹ thuật tích hợp hiển thị Video (được tạo bởi hệ thống AI) trên nền tảng Web và Mobile App.

---

## 1. Nhiệm vụ của Frontend Team
1. **Thiết kế & Cài đặt Video Player:** Xây dựng giao diện phát video định dạng dọc (Tỷ lệ 9:16 - Short/Reels form factor) để xem trước các video sinh ra.
2. **Xử lý Luồng Đợi (Loading UX):** Giao tiếp với Backend qua API, hiển thị các trạng thái loading đẹp mắt và giữ chân người dùng trong lúc chờ video render (vì tác vụ này mất 30s - 1 phút).
3. **Tích hợp Native Share Sheet:** Video không tự động upload lên Tiktok/Reels, mà phải gọi **System Share Sheet** của hệ điều hành để người dùng chủ động tải về hoặc chia sẻ lên mọi MXH họ muốn.
4. **Hiển thị Video tự động (Cronjob):** Với tính năng "Repo of the Day", lấy trực tiếp URL từ Backend và phát luôn (không cần chờ render).

---

## 2. Cách thức hoạt động (Luồng UX)

### Kịch bản A: Lộ trình của tôi (On-Demand)
1. Người dùng vào tab **"Lộ trình học tập"**.
2. Người dùng nhấn nút **"Tạo Video Tổng Kết"**.
3. Frontend gọi API lên Backend (Ví dụ: `POST /api/v1/users/me/roadmap-video`).
4. **Màn hình Loading:** Trong lúc chờ Backend trả về (có thể qua Polling, WebSockets, hoặc HTTP giữ kết nối dài), Frontend hiển thị vòng quay loading hoặc các tip nhỏ để người dùng không thoát app.
5. Backend trả về thông tin file Video (URL CDN S3).
6. Frontend tự động chuyển sang giao diện Video Player, tự động phát (Auto-play) video để người dùng xem trước.
7. Người dùng nhấn nút **"Chia sẻ"**, Frontend gọi tính năng Share Sheet gốc của thiết bị.

### Kịch bản B: Repo of the Day
1. Người dùng mở trang chủ App.
2. Frontend gọi API lấy thông tin trang chủ (Ví dụ: `GET /api/v1/feed`).
3. Dữ liệu trả về có sẵn URL của video "Repo of the Day" (do Backend đã render âm thầm từ đêm hôm trước).
4. Frontend hiển thị khối Video, phát tự động không tiếng (muted auto-play) tương tự như luồng feed TikTok.

---

## 3. Chi tiết Tích hợp Kỹ thuật

### 3.1 Giao diện Video Player
- Video xuất ra từ AI luôn có định dạng: `MP4 (H.264 + AAC)`.
- Kích thước: `720 x 1280` pixels (9:16).
- Thẻ `<video>` trên web cần hỗ trợ `playsinline` (đặc biệt quan trọng trên iOS) để video chạy mượt mà trên nền tảng di động:
  ```html
  <video src="https://cdn.domain.com/videos/abc.mp4" playsinline controls loop autoplay muted>
  </video>
  ```

### 3.2 Tích hợp Native Share (Web Share API)
Đừng tự xây dựng UI chia sẻ tùy chỉnh rườm rà. Hãy dùng API gốc của thiết bị (System Share Sheet) để người dùng có trải nghiệm quen thuộc nhất.

**Ví dụ code Javascript cho Web/PWA:**
```javascript
async function handleShareVideo(videoUrl, title) {
  if (navigator.share) {
    try {
      await navigator.share({
        title: title,
        text: 'Xem tổng kết Lộ trình học tập Dev Radar của tôi!',
        url: videoUrl, // Link public đến trang xem video hoặc link mp4 trực tiếp
      });
      console.log('Đã mở Share Sheet thành công');
    } catch (error) {
      console.error('Người dùng hủy chia sẻ hoặc có lỗi:', error);
    }
  } else {
    // Fallback cho Desktop / Trình duyệt cũ: Tự động tạo link tải xuống
    const a = document.createElement('a');
    a.href = videoUrl;
    a.download = 'dev-radar-summary.mp4';
    a.click();
  }
}
```
*Lưu ý cho Mobile Team (Flutter/React Native):* Hãy dùng thư viện `share_plus` (Flutter) hoặc `react-native-share` để đẩy file MP4 (hoặc URL của file) vào Share Intent của Android / iOS.

### 3.3 Khuyến nghị về UX
- Trong thời gian 30s-1p chờ render ở kịch bản A, Frontend có thể hiện một thanh tiến trình giả lập (Fake Progress Bar) chạy đến 90% rồi dừng, đợi API trả về thì chạy nốt 10% để đánh lừa cảm giác chờ đợi.
- Nút "Chia sẻ" cần được làm thật to và nổi bật ngay bên dưới Video Player để call-to-action người dùng lan truyền ứng dụng.
