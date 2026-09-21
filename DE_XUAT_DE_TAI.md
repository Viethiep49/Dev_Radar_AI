# ĐỀ XUẤT ĐỀ TÀI ĐỒ ÁN

**Môn học:** CMP177 – Lập trình trên thiết bị di động
**Nhóm:** 4 thành viên

| Thành viên | MSSV | Vai trò |
|---|---|---|
| ... | ... | Frontend (Flutter) |
| ... | ... | Frontend (Flutter) |
| ... | ... | Backend |
| ... | ... | AI Engine |

---

## 1. Tên đồ án

**DevRadar AI – Ứng dụng theo dõi xu hướng công nghệ và trợ lý tìm hiểu mã nguồn mở**

## 2. Giới thiệu

Mỗi ngày có hàng nghìn repository mới trên GitHub. Sinh viên và lập trình viên khó biết công cụ nào đáng chú ý, và mất nhiều thời gian đọc README dài để hiểu một repo làm gì, cài đặt ra sao.

DevRadar AI là ứng dụng di động giúp người dùng:

- Xem các repository nổi bật theo lĩnh vực mình quan tâm (Flutter, AI, Web...).
- Đọc **tóm tắt do AI tạo** thay vì đọc toàn bộ README.
- **Hỏi đáp với repo** (chat) để hiểu nhanh cách dùng.
- Lưu, phân loại, ghi chú các repo theo **lộ trình học cá nhân** và xem **thống kê tiến độ**.
- Nhận **thông báo** khi repo đang theo dõi có phiên bản mới.

**Chủ đề:** Quản lý cá nhân (quản lý lộ trình tìm hiểu công nghệ) → chức năng cốt lõi: **thống kê và biểu đồ**.

**Đối tượng sử dụng:** sinh viên CNTT, lập trình viên.

## 3. Danh sách chức năng

### 3.1. Tài khoản và bảo mật
1. Đăng ký tài khoản (email, mật khẩu).
2. Đăng nhập, đăng xuất; tự động đăng nhập lại khi token còn hạn.
3. Lưu token an toàn trên thiết bị (`flutter_secure_storage`).

### 3.2. Onboarding và cá nhân hoá
4. Lần đầu sử dụng: chọn lĩnh vực và ngôn ngữ lập trình quan tâm.
5. Chỉnh sửa lại sở thích trong Cài đặt.

### 3.3. Khám phá repository
6. **Trang chủ – Feed xu hướng:** danh sách repo nổi bật theo sở thích (tên, mô tả, số sao, ngôn ngữ, nhãn "Hot"). Hỗ trợ kéo để làm mới và tải thêm khi cuộn.
7. **Tìm kiếm** repo theo tên hoặc từ khoá; **lọc** theo ngôn ngữ, lĩnh vực; **sắp xếp** theo số sao, mức tăng trưởng, ngày cập nhật.
8. **Chi tiết repo:**
   - Thông tin cơ bản: sao, fork, license, lần cập nhật gần nhất.
   - **Tóm tắt AI** (đọc trong khoảng 1 phút) và **hướng dẫn nhanh (Quickstart)** do AI tạo.
   - **Biểu đồ số sao theo thời gian.**
   - Mở repo trên GitHub.

### 3.4. Chat với Repo (AI – RAG đơn giản)
9. Đặt câu hỏi về một repo, ví dụ "Cài đặt thế nào?", "Dùng được với Flutter không?".
10. AI trả lời dựa trên nội dung README và tài liệu của repo, **kèm trích dẫn đoạn nguồn**.
11. Lưu lịch sử hội thoại theo từng repo.

### 3.5. Bộ sưu tập và Ghi chú (CRUD)
12. **Tạo / xem / sửa / xoá bộ sưu tập** (ví dụ "Học Flutter", "Công cụ cho đồ án").
13. Thêm repo vào bộ sưu tập, gỡ repo khỏi bộ sưu tập.
14. **Tạo / xem / sửa / xoá ghi chú** cho từng repo.
15. Gán **trạng thái học tập** cho repo: *Muốn thử → Đang tìm hiểu → Đã sử dụng*.
16. Tìm kiếm trong bộ sưu tập và ghi chú của mình.

### 3.6. Thống kê cá nhân (chức năng cốt lõi)
17. Biểu đồ tròn: số repo theo trạng thái học tập.
18. Biểu đồ cột: số repo đã tìm hiểu theo từng tuần hoặc tháng.
19. Thống kê ngôn ngữ và lĩnh vực mình quan tâm nhiều nhất.

### 3.7. Theo dõi và Thông báo
20. Theo dõi (watch) hoặc bỏ theo dõi một repo.
21. **Push notification** (Firebase Cloud Messaging) khi repo đang theo dõi có release mới.
22. **Local notification** nhắc học theo lịch người dùng đặt (ví dụ "Hôm nay bạn chưa xem repo nào trong 'Đang tìm hiểu'").
23. Màn hình danh sách thông báo đã nhận.

### 3.8. Cài đặt
24. Giao diện sáng / tối.
25. Bật / tắt từng loại thông báo, chọn giờ nhắc học.
26. Xoá dữ liệu cache.

### 3.9. Offline và xử lý lỗi
27. Lưu cache feed, chi tiết repo, bộ sưu tập và ghi chú vào **SQLite** → vẫn xem được khi mất mạng.
28. Xử lý **timeout, mất mạng, lỗi server**: hiển thị thông báo rõ ràng và nút thử lại.

## 4. Công nghệ sử dụng

| Thành phần | Công nghệ |
|---|---|
| Ứng dụng di động | **Flutter / Dart** |
| Quản lý trạng thái | **BLoC** (`flutter_bloc`) |
| Gọi API | Dio (interceptor xử lý token, timeout, lỗi mạng) |
| Lưu trữ cục bộ | **SQLite** (`sqflite`) |
| Điều hướng | go_router |
| Biểu đồ | fl_chart |
| Thông báo | firebase_messaging, flutter_local_notifications |
| Backend | REST API, xác thực JWT, cron job lấy dữ liệu GitHub |
| AI Engine | Service Python: tóm tắt bằng LLM, RAG (embedding + tìm kiếm tương đồng) |
| Cơ sở dữ liệu | PostgreSQL (+ pgvector cho RAG) |
| Triển khai | Docker, docker-compose |
| Nguồn dữ liệu | GitHub REST API |

## 5. Kiến trúc hệ thống

```
┌──────────────┐   REST/JSON   ┌──────────────┐   HTTP   ┌──────────────┐
│ Flutter App  │ ────────────▶ │   Backend    │ ───────▶ │  AI Engine   │
│ (BLoC,       │               │ (Auth, CRUD, │          │ (Tóm tắt,    │
│  SQLite)     │ ◀── FCM ───── │  cron, FCM)  │          │  RAG chat)   │
└──────────────┘               └──────┬───────┘          └──────┬───────┘
                                      │                         │
                               ┌──────▼─────────────────────────▼──┐
                               │     PostgreSQL (+ pgvector)       │
                               └───────────────────────────────────┘
                                      ▲
                                      │ cron định kỳ
                               ┌──────┴───────┐
                               │  GitHub API  │
                               └──────────────┘
```

- App **chỉ gọi Backend**, không gọi trực tiếp GitHub hay LLM, để không lộ token và dễ kiểm soát chi phí.
- Tóm tắt AI được **tạo trước bằng cron** rồi lưu DB, nên app mở ra là có ngay.

### Cấu trúc mã nguồn Flutter

```
lib/
├── core/          # routes, theme, constants, network (Dio), utils
├── data/          # models, repositories, datasources (remote API, local SQLite)
└── presentation/  # screens, widgets, blocs
```

UI chỉ giao tiếp với BLoC; BLoC gọi Repository; Repository quyết định lấy dữ liệu từ API hay SQLite.

## 6. Chat với Repo – cách hoạt động (RAG mức cơ bản)

1. **Chuẩn bị (chạy trong cron):** lấy README và các file tài liệu (`docs/*.md`) của repo, chia thành các đoạn khoảng 500 token, tạo embedding cho từng đoạn và lưu vào PostgreSQL (pgvector).
2. **Khi người dùng hỏi:** tạo embedding cho câu hỏi, lấy **3–5 đoạn gần nhất** (cosine similarity).
3. Ghép các đoạn đó vào prompt, yêu cầu LLM **chỉ trả lời dựa trên nội dung được cung cấp**. Nếu không có thông tin thì nói "không tìm thấy trong tài liệu".
4. Trả về câu trả lời kèm các đoạn nguồn để người dùng đối chiếu.

**Giới hạn phạm vi:** chỉ hỗ trợ repo đã có trong hệ thống, chỉ dùng README và thư mục `docs/`, không đọc mã nguồn.

## 7. Danh sách màn hình

1. Splash
2. Onboarding (chọn sở thích)
3. Đăng nhập / Đăng ký
4. Trang chủ – Feed xu hướng
5. Tìm kiếm và lọc
6. Chi tiết repo (tab: Tổng quan · Tóm tắt AI · Quickstart)
7. Chat với repo
8. Bộ sưu tập (danh sách, chi tiết, tạo và sửa)
9. Ghi chú (tạo và sửa)
10. Thống kê
11. Thông báo
12. Cài đặt / Hồ sơ

## 8. Đối chiếu yêu cầu đồ án

| Yêu cầu | Đáp ứng bởi |
|---|---|
| Flutter / Dart | Toàn bộ ứng dụng |
| Cấu trúc phân lớp | `core` / `data` / `presentation` |
| Quản lý trạng thái | BLoC |
| Tách UI và logic nghiệp vụ | UI → BLoC → Repository → DataSource |
| UI đồng bộ, responsive, animation | Material 3, sáng/tối, Hero animation, skeleton loading, chuyển trang |
| Xử lý lỗi API và cache | Dio interceptor + cache SQLite (mục 27, 28) |
| Kiểm thử | Unit test cho BLoC và Repository; widget test cho màn hình chính |
| CRUD | Bộ sưu tập và Ghi chú (mục 12–16) |
| Chức năng cốt lõi – Quản lý cá nhân | Thống kê và biểu đồ (mục 17–19) |
| Bảo mật (dữ liệu online) | Đăng ký / Đăng nhập (mục 1–3) |
| Thông báo | Push (mục 21) và Local (mục 22) |
| Tìm kiếm | Tìm repo (mục 7), tìm trong bộ sưu tập (mục 16) |
| Lưu trữ Local + Cloud | SQLite + REST API tự xây dựng |

## 9. Phân công công việc

| Thành viên | Phụ trách |
|---|---|
| Frontend 1 | Đăng nhập/Đăng ký, Onboarding, Trang chủ, Tìm kiếm, Chi tiết repo, Chat UI, animation |
| Frontend 2 | Bộ sưu tập và Ghi chú, Thống kê và biểu đồ, Thông báo, Cài đặt, cache SQLite |
| Backend | API xác thực (JWT), API CRUD, cron lấy dữ liệu GitHub, gửi push FCM, Docker |
| AI Engine | Sinh tóm tắt và Quickstart, pipeline RAG (chia đoạn, embedding, truy vấn), API chat |

Cả nhóm cùng viết kiểm thử cho phần mình phụ trách.

## 10. Hướng phát triển (ngoài phạm vi đồ án)

- So sánh hai repo bằng AI.
- Tóm tắt thay đổi giữa các phiên bản (release diff).
- Hỏi đáp dựa trên cả mã nguồn, không chỉ tài liệu.
- Gợi ý repo theo lịch sử học của người dùng.
