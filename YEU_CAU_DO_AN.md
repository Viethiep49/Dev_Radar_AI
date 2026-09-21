# YÊU CẦU ĐỒ ÁN MÔN HỌC

## CMP177 - LẬP TRÌNH TRÊN THIẾT BỊ DI ĐỘNG

## A. Đề xuất đề tài

Mỗi nhóm tự đề xuất một ý tưởng ứng dụng để thực hiện đồ án. Bản đề xuất phải bao gồm:

1. **Tên đồ án**
2. **Danh sách chức năng:** Liệt kê các chức năng chính của ứng dụng mà nhóm dự định xây dựng, phát triển.

## B. Yêu cầu kỹ thuật

Ứng dụng của các nhóm phải đáp ứng các yêu cầu kỹ thuật tối thiểu sau đây:

### 1. Công nghệ

- Nền tảng: Flutter.
- Ngôn ngữ: Dart.

### 2. Cấu trúc dự án

- Mã nguồn bắt buộc phải được tổ chức theo một cấu trúc rõ ràng, có phân tách các thành phần. Ví dụ: Không được viết tất cả logic và UI trong cùng một tệp.
- Ví dụ tổ chức theo các lớp:
  - **Data:** Chứa Models (mô hình dữ liệu), Repositories (xử lý logic dữ liệu), Data Sources (API, DB).
  - **Presentation (hoặc UI/Features):** Chứa các Screens (màn hình), Widgets (thành phần con), và State Management (Blocs/Providers/Controllers).
  - **App/Core:** Chứa các tệp dùng chung như Routes (điều hướng), Constants (hằng số), Theme (chủ đề).

### 3. Giao diện và Trải nghiệm người dùng (UI/UX)

- **Thiết kế:** Giao diện phải rõ ràng, đồng bộ theo một chủ đề.
- **Thích ứng (Responsive):** Layout phải hiển thị tốt trên nhiều kích thước màn hình điện thoại (không bị vỡ).
- **Hiệu ứng giao diện:** Sử dụng animation (ví dụ: chuyển trang mượt mà, hiệu ứng loading) để tăng trải nghiệm người dùng.

### 4. Yêu cầu dự án

- Dự án bắt buộc phải sử dụng một trong các giải pháp quản lý trạng thái trong chương trình học:
  - Provider
  - BLoC
  - GetX
- Yêu cầu phải tách biệt rõ ràng giao diện (UI) và logic nghiệp vụ (Business Logic). Ví dụ: không được gọi API hay truy vấn CSDL trực tiếp từ tệp UI.
- **Bảo trì:** Thiết kế mã nguồn theo nguyên tắc clean code, dễ mở rộng tính năng trong tương lai.
- **Tối ưu hóa API:** Nếu dùng API, cần xử lý lỗi (timeout, không có mạng) và lưu cache dữ liệu để tăng tốc độ tải.
- **Kiểm thử:** Đảm bảo chất lượng, tính đúng đắn của ứng dụng.
- Sinh viên phải hiểu thuật toán/logic khi sử dụng AI trong quá trình làm đồ án.

### 5. Chức năng bắt buộc

#### a) Chức năng CRUD

- Ứng dụng phải có chức năng CRUD (Tạo - Đọc - Cập nhật - Xóa) đối với đối tượng dữ liệu của ứng dụng (ví dụ: chi tiêu, công việc, bài đăng, sản phẩm...).

#### b) Chức năng cốt lõi (Theo chủ đề)

Dựa trên đề tài của nhóm, phải có các chức năng đặc thù:

| Chủ đề | Chức năng bắt buộc |
|---|---|
| Quản lý cá nhân | Thống kê hoặc vẽ biểu đồ |
| Mạng xã hội | Gửi/nhận dữ liệu |
| Thương mại điện tử | Giỏ hàng và mô phỏng thanh toán |
| Sức khỏe | Theo dõi tiến độ |

#### c) Bảo mật

- Nếu ứng dụng có dữ liệu cá nhân (chi tiêu, nhật ký) phải có cơ chế bảo mật:
  - Sử dụng xác thực sinh trắc học (vân tay/khuôn mặt) hoặc Mã PIN để mở ứng dụng.
- Nếu ứng dụng có dữ liệu online (Firebase/API):
  - Bắt buộc phải có chức năng Đăng nhập/Đăng ký.

#### d) Thông báo của ứng dụng

- Ứng dụng phải có ít nhất một loại thông báo:
  - **Local Notifications:** Cho các app nhắc nhở (công việc, học từ vựng).
  - **Push Notifications:** Cho các app mạng xã hội, chat (ví dụ: "Bạn có tin nhắn mới").

#### e) Tìm kiếm

- Ứng dụng phải có chức năng tìm kiếm (Search) cho danh sách dữ liệu chính (danh sách chi tiêu, sản phẩm, bạn bè...).

#### f) Lưu trữ

Ứng dụng phải có chức năng lưu trữ dữ liệu:

- **Lưu trữ cục bộ (Local):** Ví dụ sử dụng SQLite.
- **Lưu trữ đám mây (Cloud):** Sử dụng Firebase (Firestore/Realtime Database) hoặc gọi REST API (từ server tự xây dựng hoặc API công cộng).

---

## Checklist tổng hợp

- [ ] Đề xuất: Tên đồ án + danh sách chức năng
- [ ] Flutter / Dart
- [ ] Cấu trúc phân lớp (Data / Presentation / Core)
- [ ] UI đồng bộ theo chủ đề, responsive, có animation
- [ ] Quản lý trạng thái: Provider / BLoC / GetX
- [ ] Tách UI và Business Logic, clean code
- [ ] Xử lý lỗi API (timeout, mất mạng) + cache
- [ ] Kiểm thử
- [ ] CRUD
- [ ] Chức năng cốt lõi theo chủ đề
- [ ] Bảo mật (sinh trắc học/PIN hoặc Đăng nhập/Đăng ký)
- [ ] Thông báo (Local hoặc Push)
- [ ] Tìm kiếm
- [ ] Lưu trữ Local (SQLite) + Cloud (Firebase/REST API)
