"""
Nội dung báo cáo đồ án DevRadar AI. build.py đọc file này để dựng .docx.

Khối nội dung: ("h1"|"h2"|"h3"|"para"|"reference", text), ("bullets"|"numbered", [..]),
("table", header, rows, widths, caption), ("code", [dòng], caption), ("figure", caption, gợi ý ảnh),
("toc", tiêu đề), ("caption_list", tiêu đề, style).
Trong đoạn văn: **đậm**, *nghiêng*, `mã`.

Thông tin còn trống ("……") sẽ được tô vàng trên trang bìa để nhóm điền.
"""

LOAI_DO_AN = "MÔN HỌC"
TEN_DE_TAI = "DEVRADAR AI – ỨNG DỤNG THEO DÕI XU HƯỚNG CÔNG NGHỆ VÀ TRỢ LÝ TÌM HIỂU MÃ NGUỒN MỞ"
TEN_NGAN = "DevRadar AI"
MON_HOC = "LẬP TRÌNH TRÊN THIẾT BỊ DI ĐỘNG (CMP177)"
GVHD = "……………………………"
LOP = "23DTHD5"
THANG_NAM = "2026"
THANH_VIEN = [
    ("……………………………", "……………"),
    ("……………………………", "……………"),
    ("……………………………", "……………"),
    ("……………………………", "……………"),
]

# Số liệu kiểm thử (cập nhật khi chạy lại test).
SO_TEST_BACKEND = "240"
SO_TEST_MOBILE = "135"

FIG = "Chu thich hinh"
TBL = "Chu thich bang"

NOI_DUNG = [
    # =====================================================================
    ("h1", "LỜI CẢM ƠN"),
    ("para",
     "Nhóm chúng em xin chân thành cảm ơn Thầy/Cô ……………………………, giảng viên môn Lập trình trên thiết bị di động, "
     "đã tận tình hướng dẫn và góp ý cho nhóm trong suốt quá trình thực hiện đồ án."),
    ("para",
     "Chúng em cũng xin cảm ơn quý Thầy Cô Khoa Công nghệ Thông tin, Trường Đại học Công nghệ TP. Hồ Chí Minh đã "
     "truyền đạt những kiến thức nền tảng giúp nhóm hoàn thành đề tài này."),
    ("para",
     "Do thời gian và kinh nghiệm còn hạn chế, báo cáo không tránh khỏi thiếu sót. Nhóm rất mong nhận được ý kiến "
     "đóng góp của quý Thầy Cô để đề tài được hoàn thiện hơn."),

    ("toc", "MỤC LỤC"),
    ("caption_list", "DANH MỤC HÌNH ẢNH", FIG),
    ("caption_list", "DANH MỤC BẢNG BIỂU", TBL),

    # =====================================================================
    ("h1", "CHƯƠNG 1. GIỚI THIỆU ĐỀ TÀI"),
    ("h2", "1.1. Lý do chọn đề tài"),
    ("para",
     "Mỗi ngày có hàng nghìn repository mới xuất hiện trên GitHub. Sinh viên và lập trình viên khó biết công cụ nào "
     "đáng chú ý, và thường mất nhiều thời gian đọc README dài để hiểu một repository làm gì, cài đặt ra sao, có phù hợp "
     "với nhu cầu của mình hay không. Bên cạnh đó, việc tự học công nghệ mới thường thiếu một lộ trình rõ ràng: người học "
     "lưu rất nhiều đường dẫn nhưng không theo dõi được mình đã thử, đang tìm hiểu hay đã sử dụng công cụ nào."),
    ("para",
     "Từ thực tế đó, nhóm xây dựng **DevRadar AI** – ứng dụng di động giúp người dùng theo dõi các repository nổi bật "
     "theo lĩnh vực quan tâm, đọc tóm tắt do AI tạo thay vì đọc toàn bộ README, hỏi đáp trực tiếp với tài liệu của "
     "repository và quản lý lộ trình học công nghệ của cá nhân kèm thống kê tiến độ."),

    ("h2", "1.2. Mục tiêu đề tài"),
    ("bullets", [
        "Xây dựng ứng dụng di động bằng **Flutter/Dart** đáp ứng đầy đủ yêu cầu kỹ thuật của môn học CMP177.",
        "Cung cấp feed repository xu hướng được cá nhân hoá theo ngôn ngữ và chủ đề người dùng quan tâm.",
        "Tóm tắt README và tạo hướng dẫn nhanh (Quickstart) bằng mô hình ngôn ngữ lớn (LLM).",
        "Hỏi đáp với repository theo kỹ thuật RAG (Retrieval-Augmented Generation), có trích dẫn đoạn nguồn.",
        "Quản lý bộ sưu tập, ghi chú và trạng thái học tập (CRUD), kèm thống kê bằng biểu đồ.",
        "Thông báo khi repository đang theo dõi có phiên bản mới và nhắc học hằng ngày.",
        "Hoạt động được khi mất mạng nhờ bộ nhớ đệm SQLite.",
    ]),

    ("h2", "1.3. Đối tượng và phạm vi"),
    ("para",
     "**Đối tượng sử dụng:** sinh viên ngành Công nghệ Thông tin và lập trình viên muốn cập nhật xu hướng công nghệ."),
    ("para",
     "**Chủ đề theo yêu cầu đồ án:** *Quản lý cá nhân* (quản lý lộ trình tìm hiểu công nghệ), do đó chức năng cốt lõi "
     "bắt buộc là **thống kê và vẽ biểu đồ**."),
    ("para",
     "**Phạm vi:** ứng dụng chạy trên Android và iOS (có thể chạy thử trên trình duyệt để demo). Dữ liệu repository "
     "lấy từ GitHub REST API thông qua backend; trợ lý AI chỉ dùng README của repository, không đọc mã nguồn."),

    ("h2", "1.4. Thành viên và phân công"),
    ("table", ["STT", "Họ và tên", "MSSV", "Vai trò / công việc chính"], [
        ["1", "……………………………", "……………", "Frontend 1: đăng nhập/đăng ký, onboarding, trang chủ, tìm kiếm, chi tiết repo, chat"],
        ["2", "……………………………", "……………", "Frontend 2: bộ sưu tập, ghi chú, thống kê, thông báo, cài đặt, cache SQLite"],
        ["3", "……………………………", "……………", "Backend: REST API, xác thực JWT/OAuth, cron job GitHub, Docker"],
        ["4", "……………………………", "……………", "AI Engine: tóm tắt README, pipeline RAG, API chat"],
    ], [9, 27, 16, 48], "Bảng 1.1: Thành viên nhóm và phân công công việc"),

    # =====================================================================
    ("h1", "CHƯƠNG 2. CƠ SỞ LÝ THUYẾT VÀ CÔNG NGHỆ SỬ DỤNG"),
    ("h2", "2.1. Flutter và ngôn ngữ Dart"),
    ("para",
     "Flutter là bộ công cụ phát triển giao diện đa nền tảng của Google. Một mã nguồn Dart duy nhất được biên dịch "
     "thành ứng dụng Android, iOS và web. Giao diện được xây dựng từ cây *widget*; Flutter tự vẽ toàn bộ giao diện "
     "bằng engine riêng nên giao diện đồng nhất trên mọi nền tảng và hỗ trợ animation mượt."),
    ("h2", "2.2. Quản lý trạng thái với BLoC"),
    ("para",
     "BLoC (Business Logic Component) tách logic nghiệp vụ khỏi giao diện. Giao diện chỉ gửi **sự kiện (event)** vào "
     "Bloc và vẽ lại theo **trạng thái (state)** mà Bloc phát ra. Nhóm dùng thư viện `flutter_bloc` với hai dạng: "
     "`Bloc` (event → state, dùng cho luồng phức tạp như feed, tìm kiếm có debounce, chat) và `Cubit` (gọi hàm → "
     "state, dùng cho các màn hình CRUD đơn giản hơn). Nhờ vậy giao diện không bao giờ gọi API hay truy vấn CSDL trực "
     "tiếp, đúng yêu cầu tách UI và business logic của đồ án."),
    ("h2", "2.3. REST API, JWT và OAuth 2.0"),
    ("para",
     "Ứng dụng giao tiếp với backend qua REST API (JSON). Sau khi đăng nhập, backend trả về cặp **access token** (thời "
     "hạn ngắn) và **refresh token** (thời hạn dài) theo chuẩn JWT. Khi access token hết hạn, ứng dụng tự gọi "
     "`/auth/refresh` để lấy token mới mà người dùng không phải đăng nhập lại."),
    ("para",
     "Đăng nhập bằng Google dùng *ID token* do Google ký; backend kiểm tra chữ ký, issuer, audience và thời hạn. "
     "Đăng nhập bằng GitHub dùng luồng *Authorization Code* kèm **PKCE** và tham số `state` để chống giả mạo; "
     "client secret chỉ nằm ở backend, không bao giờ đưa vào ứng dụng."),
    ("h2", "2.4. SQLite và chiến lược cache"),
    ("para",
     "SQLite là CSDL nhúng chạy ngay trên thiết bị. Ứng dụng dùng thư viện `sqflite` để lưu bản sao các phản hồi API "
     "(feed, chi tiết repo, bộ sưu tập, ghi chú, thống kê...). Chiến lược được dùng là **network-first**: luôn gọi API "
     "trước để có dữ liệu mới nhất; nếu mất mạng, quá thời gian chờ hoặc server lỗi 5xx thì trả về bản đã lưu kèm "
     "thời điểm lưu để giao diện hiển thị thông báo \"đang offline\"."),
    ("h2", "2.5. Mô hình ngôn ngữ lớn và RAG"),
    ("para",
     "Tóm tắt README được sinh bởi mô hình ngôn ngữ lớn chạy cục bộ qua **Ollama** (mặc định `qwen2.5:7b`). Chức năng "
     "hỏi đáp dùng kỹ thuật **RAG**: README được chia thành các đoạn nhỏ, mỗi đoạn được chuyển thành vector bằng mô "
     "hình `paraphrase-multilingual-MiniLM-L12-v2` (384 chiều) và lưu trong PostgreSQL với tiện ích **pgvector**. Khi "
     "người dùng hỏi, câu hỏi cũng được chuyển thành vector, hệ thống lấy các đoạn gần nhất theo độ tương đồng cosine "
     "rồi đưa vào prompt, yêu cầu LLM chỉ trả lời dựa trên các đoạn đó và trả về kèm nguồn trích dẫn."),
    ("h2", "2.6. Các thư viện chính"),
    ("table", ["Thành phần", "Công nghệ / thư viện", "Mục đích"], [
        ["Ứng dụng di động", "Flutter, Dart", "Giao diện đa nền tảng"],
        ["Quản lý trạng thái", "flutter_bloc, equatable", "Bloc/Cubit, so sánh state"],
        ["Gọi API", "dio", "HTTP client, interceptor gắn token, tự refresh, xử lý lỗi"],
        ["Điều hướng", "go_router", "Định tuyến khai báo, hiệu ứng chuyển trang"],
        ["Lưu trữ cục bộ", "sqflite, shared_preferences, flutter_secure_storage", "Cache SQLite, cài đặt, token an toàn"],
        ["Biểu đồ", "fl_chart", "Biểu đồ tròn, cột, đường"],
        ["Thông báo", "flutter_local_notifications, timezone", "Thông báo cục bộ, nhắc học theo giờ"],
        ["Đăng nhập MXH", "google_sign_in, flutter_web_auth_2, crypto", "Google Sign-In, GitHub OAuth + PKCE"],
        ["Hiển thị", "flutter_markdown, google_fonts, url_launcher", "README Markdown, phông chữ, mở GitHub"],
        ["Kiểm thử", "flutter_test, bloc_test, mocktail, sqflite_common_ffi", "Unit test, bloc test, widget test"],
        ["Backend", "FastAPI, SQLAlchemy, Alembic, APScheduler", "REST API, ORM, migration, cron job"],
        ["AI Engine", "FastAPI, Ollama, sentence-transformers, pgvector", "Tóm tắt, embedding, RAG"],
        ["Hạ tầng", "PostgreSQL 16 + pgvector, Docker Compose", "CSDL, triển khai"],
    ], [22, 40, 38], "Bảng 2.1: Công nghệ và thư viện sử dụng"),

    # =====================================================================
    ("h1", "CHƯƠNG 3. PHÂN TÍCH YÊU CẦU"),
    ("h2", "3.1. Yêu cầu chức năng"),
    ("table", ["Nhóm chức năng", "Chức năng chi tiết"], [
        ["Tài khoản và bảo mật",
         "Đăng ký, đăng nhập bằng email/mật khẩu, Google hoặc GitHub; tự đăng nhập lại khi còn phiên; tự làm mới token; "
         "đổi mật khẩu, đổi ảnh đại diện; đăng xuất (xoá token và cache)"],
        ["Onboarding và cá nhân hoá", "Lần đầu đăng nhập chọn ngôn ngữ và chủ đề quan tâm; sửa lại trong Cài đặt"],
        ["Khám phá repository",
         "Feed \"Dành cho bạn\" theo sở thích, lọc theo ngôn ngữ, nhãn Hot, kéo để làm mới, cuộn vô hạn"],
        ["Tìm kiếm", "Tìm theo tên/mô tả, lọc theo ngôn ngữ và chủ đề, sắp xếp theo sao, tăng trưởng, cập nhật, mới nhất"],
        ["Chi tiết repository",
         "Sao, fork, issue, license, ngày cập nhật; tóm tắt AI; Quickstart (sao chép được); README; biểu đồ sao 30 ngày; "
         "mở trên GitHub"],
        ["Chat với repository", "Đặt câu hỏi, câu trả lời kèm trích dẫn nguồn, gợi ý câu hỏi, lưu và xoá lịch sử"],
        ["Bộ sưu tập (CRUD)", "Tạo, xem, sửa, xoá bộ sưu tập; thêm/gỡ repository; tìm kiếm bộ sưu tập"],
        ["Ghi chú (CRUD)", "Tạo, xem, sửa, xoá ghi chú cho từng repository; tìm kiếm ghi chú"],
        ["Lộ trình học", "Gán trạng thái Muốn thử → Đang tìm hiểu → Đã sử dụng; lọc theo trạng thái"],
        ["Thống kê (cốt lõi)",
         "Biểu đồ tròn theo trạng thái học; biểu đồ cột số repo bắt đầu/hoàn thành theo tuần; ngôn ngữ quan tâm nhiều nhất"],
        ["Theo dõi và thông báo",
         "Theo dõi/bỏ theo dõi repository; thông báo khi có release mới; nhắc học hằng ngày; danh sách thông báo"],
        ["Cài đặt", "Giao diện sáng/tối/hệ thống; bật/tắt thông báo, chọn giờ nhắc; xoá cache"],
        ["Offline và xử lý lỗi", "Cache SQLite; thông báo lỗi rõ ràng (timeout, mất mạng, lỗi server) và nút thử lại"],
    ], [26, 74], "Bảng 3.1: Danh sách chức năng của ứng dụng"),

    ("h2", "3.2. Yêu cầu phi chức năng"),
    ("bullets", [
        "**Kiến trúc:** mã nguồn phân lớp Core / Data / Presentation, giao diện không gọi API trực tiếp.",
        "**Giao diện:** đồng bộ theo một chủ đề (phong cách *glass* lấy cảm hứng từ GitHub), hỗ trợ sáng/tối, "
        "responsive trên nhiều kích thước điện thoại, có animation chuyển trang và hiệu ứng loading.",
        "**Hiệu năng và độ tin cậy:** timeout kết nối 15 giây; cache SQLite để tải nhanh và dùng khi offline.",
        "**Bảo mật:** token lưu trong Keystore/Keychain qua `flutter_secure_storage`; app không chứa secret nào; "
        "chỉ gọi backend, không gọi trực tiếp GitHub hay LLM.",
        "**Kiểm thử:** unit test cho repository và Bloc/Cubit, widget test cho màn hình chính; backend có bộ test tự động.",
    ]),

    ("h2", "3.3. Tác nhân và ca sử dụng"),
    ("para",
     "Hệ thống có hai tác nhân: **Người dùng** (sử dụng ứng dụng) và **Hệ thống định kỳ** (các cron job của backend "
     "tự lấy dữ liệu GitHub, sinh tóm tắt AI và kiểm tra release mới)."),
    ("table", ["Ca sử dụng", "Tác nhân", "Mô tả ngắn"], [
        ["Đăng ký / đăng nhập", "Người dùng", "Tạo tài khoản hoặc đăng nhập bằng email, Google, GitHub"],
        ["Chọn sở thích", "Người dùng", "Chọn ngôn ngữ, chủ đề để cá nhân hoá feed"],
        ["Xem feed, tìm kiếm", "Người dùng", "Duyệt repository nổi bật, tìm và lọc"],
        ["Xem chi tiết, hỏi đáp AI", "Người dùng", "Đọc tóm tắt, Quickstart, README; chat với repository"],
        ["Quản lý bộ sưu tập, ghi chú", "Người dùng", "CRUD bộ sưu tập, ghi chú"],
        ["Cập nhật lộ trình học", "Người dùng", "Đổi trạng thái học của repository"],
        ["Xem thống kê", "Người dùng", "Xem biểu đồ tiến độ học"],
        ["Theo dõi repository", "Người dùng", "Nhận thông báo khi có release mới"],
        ["Lấy repo xu hướng", "Hệ thống định kỳ", "6 giờ/lần tìm repo nổi bật trên GitHub, lưu README"],
        ["Sinh tóm tắt AI", "Hệ thống định kỳ", "30 phút/lần tóm tắt các repo chưa có tóm tắt và đánh chỉ mục RAG"],
        ["Kiểm tra release", "Hệ thống định kỳ", "60 phút/lần, tạo thông báo cho người theo dõi"],
        ["Chụp số sao", "Hệ thống định kỳ", "Mỗi ngày lưu số sao để vẽ biểu đồ tăng trưởng"],
    ], [28, 18, 54], "Bảng 3.2: Các ca sử dụng chính"),
    ("figure", "Hình 3.1: Sơ đồ ca sử dụng tổng quát", "sơ đồ use case (vẽ bằng draw.io / StarUML)"),

    # =====================================================================
    ("h1", "CHƯƠNG 4. THIẾT KẾ HỆ THỐNG"),
    ("h2", "4.1. Kiến trúc tổng thể"),
    ("para",
     "Hệ thống gồm ba dịch vụ chạy bằng Docker Compose và ứng dụng Flutter. Ứng dụng **chỉ gọi backend**; backend gọi "
     "GitHub API và AI Engine. Cách tổ chức này giúp không lộ token GitHub hay khoá OAuth trong ứng dụng và dễ kiểm "
     "soát chi phí gọi LLM."),
    ("code", [
        "┌──────────────┐  REST/JSON  ┌──────────────┐   HTTP   ┌──────────────┐",
        "│ Flutter App  │ ──────────▶ │   Backend    │ ───────▶ │  AI Engine   │",
        "│ BLoC, SQLite │ ◀────────── │ FastAPI, JWT │          │ Ollama, RAG  │",
        "└──────────────┘             │ cron jobs    │          └──────┬───────┘",
        "                             └──────┬───────┘                 │",
        "                    ┌───────────────▼─────────────────────────▼──┐",
        "                    │        PostgreSQL 16 + pgvector             │",
        "                    └─────────────────────────────────────────────┘",
        "                             ▲ cron định kỳ: GitHub REST API",
    ], "Hình 4.1: Kiến trúc tổng thể của hệ thống"),

    ("h2", "4.2. Kiến trúc ứng dụng Flutter"),
    ("para",
     "Mã nguồn ứng dụng được tổ chức theo ba lớp. Luồng phụ thuộc chỉ đi một chiều: **UI → Bloc/Cubit → Repository → "
     "DataSource**. Mỗi màn hình tự tạo Bloc/Cubit của mình từ các Repository được cung cấp ở gốc ứng dụng "
     "(`main.dart` đóng vai trò *composition root*)."),
    ("code", [
        "lib/",
        "├── core/            # dùng chung: constants, database (SQLite), network (Dio),",
        "│                    # notifications, routes (go_router), theme, utils",
        "├── data/",
        "│   ├── datasources/ # remote/ (gọi REST API), local/ (cache SQLite)",
        "│   ├── models/      # RepoModel, CollectionModel, NoteModel, ...",
        "│   ├── repositories/# kết hợp remote + cache, chính sách network-first",
        "│   └── services/    # đăng nhập Google/GitHub, cảnh báo release",
        "├── presentation/",
        "│   ├── screens/     # các màn hình",
        "│   ├── state/       # Bloc / Cubit theo từng tính năng",
        "│   └── widgets/     # thành phần giao diện dùng lại",
        "└── main.dart        # khởi tạo DI, provider, MaterialApp.router",
    ], "Hình 4.2: Cấu trúc thư mục mã nguồn Flutter"),
    ("table", ["Lớp", "Thành phần", "Trách nhiệm"], [
        ["Presentation", "Screens, Widgets", "Vẽ giao diện theo state, gửi event; không chứa logic gọi API"],
        ["Presentation", "Bloc / Cubit", "Logic nghiệp vụ của màn hình: tải, phân trang, debounce, cập nhật lạc quan"],
        ["Data", "Repository", "Quyết định lấy dữ liệu từ API hay cache; làm mất hiệu lực cache sau khi ghi"],
        ["Data", "RemoteDataSource", "Gọi REST API qua ApiClient, trả JSON"],
        ["Data", "CacheLocalDataSource", "Đọc/ghi bảng cache trong SQLite"],
        ["Core", "ApiClient", "Gắn token, tự refresh khi 401, chuyển lỗi Dio thành thông báo dễ hiểu"],
    ], [18, 26, 56], "Bảng 4.1: Trách nhiệm của từng lớp"),
    ("h3", "4.2.1. Các Bloc/Cubit chính"),
    ("table", ["Bloc / Cubit", "Màn hình", "Nhiệm vụ"], [
        ["AuthBloc", "Splash, Đăng nhập, Đăng ký", "Kiểm tra phiên, đăng nhập/đăng ký/OAuth, hết phiên, đăng xuất"],
        ["FeedBloc", "Trang chủ", "Feed cá nhân hoá, lọc ngôn ngữ, làm mới, tải thêm khi cuộn"],
        ["SearchBloc", "Tìm kiếm", "Debounce từ khoá, bộ lọc, sắp xếp, phân trang"],
        ["RepoDetailCubit", "Chi tiết repo", "Tải chi tiết + lịch sử sao, theo dõi, trạng thái học"],
        ["ChatBloc", "Chat với repo", "Lịch sử, gửi câu hỏi, trạng thái đang trả lời, thử lại, xoá lịch sử"],
        ["CollectionsCubit, CollectionDetailCubit", "Bộ sưu tập", "CRUD bộ sưu tập, thêm/gỡ repo"],
        ["NotesCubit, NoteEditorCubit", "Ghi chú", "CRUD ghi chú, tìm kiếm"],
        ["LearningCubit", "Lộ trình học", "Lọc và đổi trạng thái học"],
        ["StatsCubit", "Thống kê", "Tổng quan, theo tuần, theo ngôn ngữ"],
        ["NotificationsCubit", "Thông báo", "Danh sách, đánh dấu đã đọc, xoá"],
        ["OnboardingCubit, SettingsCubit", "Onboarding, Cài đặt", "Sở thích, thông báo, giờ nhắc, xoá cache"],
    ], [30, 24, 46], "Bảng 4.2: Các Bloc/Cubit trong ứng dụng"),

    ("h2", "4.3. Thiết kế cơ sở dữ liệu"),
    ("h3", "4.3.1. CSDL máy chủ (PostgreSQL)"),
    ("table", ["Bảng", "Nội dung"], [
        ["users, oauth_accounts", "Tài khoản; liên kết Google/GitHub theo id của nhà cung cấp"],
        ["user_preferences", "Ngôn ngữ, chủ đề quan tâm"],
        ["repos, repo_star_snapshots", "Thông tin repository, README; số sao theo ngày"],
        ["repo_summaries", "Tóm tắt AI và Quickstart"],
        ["repo_releases", "Release mới nhất đã ghi nhận"],
        ["collections, collection_items", "Bộ sưu tập và repository trong bộ sưu tập"],
        ["notes", "Ghi chú của người dùng cho từng repository"],
        ["user_repos", "Trạng thái học: want_to_try, learning, used (kèm thời điểm bắt đầu/hoàn thành)"],
        ["watchlist", "Repository đang theo dõi"],
        ["notifications, device_tokens", "Thông báo đã tạo; token thiết bị"],
        ["chat_messages", "Lịch sử hỏi đáp theo repository"],
        ["document_chunks (AI Engine)", "Đoạn README + vector embedding 384 chiều (pgvector, chỉ mục HNSW)"],
    ], [32, 68], "Bảng 4.3: Các bảng chính trong CSDL máy chủ"),
    ("figure", "Hình 4.3: Sơ đồ quan hệ thực thể (ERD)", "sơ đồ ERD của PostgreSQL"),
    ("h3", "4.3.2. CSDL cục bộ (SQLite)"),
    ("para",
     "Trên thiết bị, ứng dụng dùng một bảng `cache` dạng khoá – giá trị để lưu bản sao phản hồi API dưới dạng JSON. "
     "Mỗi khoá đại diện cho một tài nguyên, ví dụ `feed:page=1`, `repo_detail:42`, `collections`, `notes:all`. Sau "
     "khi người dùng thêm/sửa/xoá, repository xoá các khoá liên quan để lần đọc sau lấy dữ liệu mới. Khi đăng xuất, "
     "toàn bộ cache bị xoá để tài khoản khác không thấy dữ liệu cũ."),
    ("code", [
        "CREATE TABLE cache (",
        "  key        TEXT PRIMARY KEY,   -- ví dụ \"repo_detail:42\"",
        "  json       TEXT NOT NULL,      -- phản hồi API",
        "  updated_at INTEGER NOT NULL    -- thời điểm lưu (ms)",
        ");",
    ], "Hình 4.4: Lược đồ bảng cache trong SQLite"),

    ("h2", "4.4. Thiết kế API"),
    ("table", ["Nhóm", "Endpoint (tiền tố /api/v1)"], [
        ["Xác thực", "POST auth/register, auth/login, auth/refresh, auth/google, auth/github; GET auth/me, "
                     "auth/oauth/providers; POST auth/change-password; PUT auth/avatar"],
        ["Repository", "GET repos/feed, repos (q, language, topic, sort), repos/filters, repos/{id}, "
                       "repos/{id}/summary, repos/{id}/stars"],
        ["Chat", "POST / GET / DELETE chat/{repo_id}"],
        ["Cá nhân", "GET, PUT preferences; CRUD collections, collections/{id}/items; CRUD notes; "
                    "GET learning, PUT/DELETE learning/{repo_id}; GET watchlist, POST/DELETE watchlist/{repo_id}"],
        ["Thống kê", "GET stats/overview, stats/weekly, stats/languages"],
        ["Thông báo", "GET notifications, notifications/unread-count; POST notifications/read-all; "
                      "PATCH notifications/{id}/read; DELETE notifications/{id}"],
    ], [18, 82], "Bảng 4.4: Các nhóm API của backend"),
    ("para",
     "Mọi lỗi trả về cùng định dạng `{\"error\": {\"code\", \"message\", \"details\"}}`; ứng dụng đọc trường "
     "`message` để hiển thị cho người dùng. Danh sách được phân trang với `page`, `limit` và trả về `total`."),

    ("h2", "4.5. Các luồng xử lý quan trọng"),
    ("h3", "4.5.1. Đăng nhập và tự làm mới token"),
    ("numbered", [
        "Người dùng đăng nhập; backend trả access token, refresh token và thông tin người dùng.",
        "Token được lưu bằng `flutter_secure_storage` (Android Keystore / iOS Keychain).",
        "Mỗi request, interceptor của Dio gắn header `Authorization: Bearer <access token>`.",
        "Khi nhận lỗi 401, ApiClient gọi `/auth/refresh` một lần (dùng chung cho các request song song), lưu token mới "
        "và gửi lại request.",
        "Nếu refresh token cũng hết hạn, ứng dụng xoá phiên, AuthBloc phát trạng thái hết phiên và chuyển về màn hình "
        "đăng nhập.",
    ]),
    ("h3", "4.5.2. Đăng nhập bằng GitHub (OAuth + PKCE)"),
    ("numbered", [
        "Ứng dụng lấy `client_id`, `redirect_uri` công khai từ `GET /auth/oauth/providers`.",
        "Sinh `state` và `code_verifier` ngẫu nhiên; tính `code_challenge = base64url(SHA-256(code_verifier))`.",
        "Mở trang đăng nhập GitHub; GitHub chuyển hướng về `devradar://oauth/github?code=...&state=...`.",
        "Ứng dụng kiểm tra `state` khớp rồi gửi `code` và `code_verifier` lên `POST /auth/github`.",
        "Backend đổi code lấy token bằng client secret, đọc email đã xác minh, tìm hoặc tạo tài khoản và trả JWT.",
    ]),
    ("h3", "4.5.3. Đọc dữ liệu có cache (network-first)"),
    ("code", [
        "Future<Cached<T>> fetchWithCache(key, fetch, parse) async {",
        "  try {",
        "    final json = await fetch();          // gọi API",
        "    await cache.put(key, json);          // lưu bản mới vào SQLite",
        "    return Cached(parse(json));",
        "  } on ApiException catch (e) {",
        "    if (!isOfflineError(e)) rethrow;     // 401, 404... không dùng cache",
        "    final entry = await cache.get(key);",
        "    if (entry == null) rethrow;",
        "    return Cached(parse(entry.json), fromCache: true, cachedAt: entry.updatedAt);",
        "  }",
        "}",
    ], "Hình 4.5: Hàm đọc dữ liệu network-first với SQLite"),
    ("h3", "4.5.4. Hỏi đáp với repository (RAG)"),
    ("numbered", [
        "Cron job của backend gửi README sang AI Engine để chia đoạn, tạo embedding và lưu vào pgvector.",
        "Người dùng gửi câu hỏi; ChatBloc hiển thị ngay câu hỏi và bong bóng \"AI đang suy nghĩ\".",
        "Backend chuyển câu hỏi kèm lịch sử hội thoại tới AI Engine.",
        "AI Engine tìm các đoạn có độ tương đồng cosine cao nhất (bỏ đoạn dưới ngưỡng 0.35), ghép vào prompt và gọi LLM.",
        "Câu trả lời và các đoạn nguồn được lưu vào lịch sử rồi trả về ứng dụng để hiển thị kèm trích dẫn.",
    ]),
    ("h3", "4.5.5. Thông báo"),
    ("para",
     "Backend kiểm tra release mới của các repository được theo dõi mỗi giờ và tạo bản ghi thông báo. Ứng dụng kiểm "
     "tra thông báo chưa đọc khi mở hoặc quay lại ứng dụng và hiển thị **thông báo cục bộ** cho release mới "
     "(`flutter_local_notifications`). Người dùng cũng có thể bật **nhắc học hằng ngày** vào giờ tự chọn. Hạ tầng "
     "push (bảng `device_tokens`, API đăng ký token) đã sẵn sàng để tích hợp Firebase Cloud Messaging khi có cấu hình."),

    # =====================================================================
    ("h1", "CHƯƠNG 5. CÀI ĐẶT VÀ GIAO DIỆN ỨNG DỤNG"),
    ("h2", "5.1. Môi trường cài đặt"),
    ("table", ["Thành phần", "Phiên bản / yêu cầu"], [
        ["Flutter SDK", "3.47 (Dart 3.13)"],
        ["Android", "Android 5.0 (API 21) trở lên"],
        ["Docker Desktop", "Chạy PostgreSQL, backend, AI Engine, Ollama"],
        ["GPU (khuyến nghị)", "NVIDIA để LLM trả lời nhanh; có cấu hình chạy bằng CPU"],
    ], [30, 70], "Bảng 5.1: Môi trường cài đặt"),
    ("h2", "5.2. Hướng dẫn chạy"),
    ("code", [
        "# 1. Khởi động server (thư mục gốc repo)",
        "copy .env.example .env      # điền GOOGLE_CLIENT_IDS, GITHUB_CLIENT_ID... nếu dùng đăng nhập MXH",
        "docker compose up -d --build",
        "",
        "# 2. Chạy ứng dụng",
        "cd mobile",
        "flutter pub get",
        "flutter run                 # emulator Android dùng http://10.0.2.2:8080",
        "flutter run --dart-define=API_BASE_URL=http://<IP-LAN>:8080   # điện thoại thật",
    ], "Hình 5.1: Các lệnh khởi động hệ thống"),

    ("h2", "5.3. Giao diện các màn hình"),
    ("para",
     "Giao diện dùng phong cách *glassmorphism* với bảng màu lấy cảm hứng từ GitHub, hỗ trợ chế độ sáng và tối. "
     "Các màn hình dùng chung một bộ thành phần (thẻ kính, nút, thanh tìm kiếm, khung skeleton khi tải, khung báo "
     "lỗi có nút thử lại, banner offline) nên giao diện đồng bộ. Chuyển trang có hiệu ứng mờ dần và trượt nhẹ; ảnh "
     "đại diện repository chuyển tiếp bằng Hero animation từ danh sách sang trang chi tiết."),
    ("para",
     "Các hình dưới đây được chụp từ ứng dụng chạy thật với backend (dữ liệu repository lấy từ GitHub, tài khoản "
     "demo). Ứng dụng mặc định dùng giao diện tối."),
    ("image", "bao_cao/hinh/h5_1_dang_nhap_onboarding.jpg", 12, "Hình 5.2: Đăng nhập (email, Google, GitHub) và chọn sở thích lần đầu"),
    ("para",
     "Màn hình đăng nhập hỗ trợ email/mật khẩu và đăng nhập bằng Google, GitHub. Lần đầu đăng nhập, người dùng chọn "
     "ngôn ngữ và chủ đề quan tâm; lựa chọn này dùng để cá nhân hoá feed và có thể sửa lại trong Cài đặt."),
    ("image", "bao_cao/hinh/h5_2_trang_chu_tim_kiem.jpg", 12, "Hình 5.3: Trang chủ (feed xu hướng) và tìm kiếm"),
    ("para",
     "Trang chủ hiển thị feed \"Dành cho bạn\" và các chip lọc theo ngôn ngữ, nhãn **HOT** cho repo tăng sao nhanh, "
     "số sao tăng trong 7 ngày, chuông thông báo có số chưa đọc. Màn tìm kiếm có debounce, bộ lọc ngôn ngữ/chủ đề, "
     "sắp xếp và gợi ý chủ đề xu hướng lấy từ dữ liệu thật."),
    ("image", "bao_cao/hinh/h5_3_chi_tiet.jpg", 12, "Hình 5.4: Chi tiết repository – thông số, trạng thái học, tóm tắt AI"),
    ("para",
     "Trang chi tiết gồm thông số (sao, fork, issue, license, ngày cập nhật), các nút Theo dõi, Lưu vào bộ sưu tập, "
     "mở GitHub, bộ chọn trạng thái học, các tab Tổng quan (biểu đồ sao 30 ngày) · Tóm tắt AI · Quickstart · README, "
     "phần ghi chú và nút mở trợ lý AI."),
    ("image", "bao_cao/hinh/h5_4_chat.jpg", 6, "Hình 5.5: Chat với repository"),
    ("image", "bao_cao/hinh/h5_5_bo_suu_tap_ghi_chu_lo_trinh.jpg", 15.5, "Hình 5.6: Bộ sưu tập, ghi chú và lộ trình học (CRUD)"),
    ("para",
     "Tab Bộ sưu tập gom ba phần: bộ sưu tập (tạo, sửa, xoá, tìm kiếm), ghi chú của tất cả repository (sửa, xoá, tìm "
     "kiếm) và lộ trình học lọc theo trạng thái Muốn thử / Đang tìm hiểu / Đã sử dụng."),
    ("image", "bao_cao/hinh/h5_6_thong_ke.jpg", 12, "Hình 5.7: Thống kê học tập – chức năng cốt lõi"),
    ("para",
     "Màn thống kê hiển thị các chỉ số tổng quan, biểu đồ tròn phân bố trạng thái học, biểu đồ cột số repo bắt đầu và "
     "hoàn thành theo tuần (chọn 4/8/12 tuần) và các ngôn ngữ người dùng quan tâm nhiều nhất."),
    ("image", "bao_cao/hinh/h5_7_thong_bao_theo_doi.jpg", 12, "Hình 5.8: Danh sách thông báo và repository đang theo dõi"),
    ("image", "bao_cao/hinh/h5_8_cai_dat.jpg", 6, "Hình 5.9: Cài đặt"),
    ("para",
     "Cài đặt cho phép đổi ảnh đại diện, sửa sở thích, bật/tắt thông báo release và nhắc học hằng ngày (chọn giờ), "
     "đổi giao diện sáng/tối/hệ thống, xoá cache SQLite, đổi mật khẩu và đăng xuất."),
    ("image", "bao_cao/hinh/h5_9_offline.jpg", 12, "Hình 5.10: Xử lý mất mạng – báo lỗi có nút thử lại và dữ liệu từ cache"),
    ("para",
     "Khi mất kết nối, nếu chưa có dữ liệu đã lưu, ứng dụng hiển thị thông báo lỗi rõ ràng và nút **Thử lại**; nếu đã "
     "có dữ liệu trong SQLite, ứng dụng vẫn hiển thị nội dung kèm banner \"Đang offline – hiển thị dữ liệu đã lưu\" "
     "và thời điểm lưu."),

    # =====================================================================
    ("h1", "CHƯƠNG 6. KIỂM THỬ"),
    ("h2", "6.1. Chiến lược kiểm thử"),
    ("bullets", [
        "**Unit test cho Repository:** giả lập RemoteDataSource bằng `mocktail` và dùng cache trong bộ nhớ; kiểm tra "
        "chuyển đổi dữ liệu, chính sách network-first (mất mạng thì lấy cache, lỗi 401 thì không), xoá cache sau khi ghi.",
        "**Bloc test:** dùng `bloc_test` kiểm tra chuỗi state phát ra, ví dụ tải → thành công, phân trang, debounce tìm "
        "kiếm, cập nhật lạc quan và hoàn tác khi lỗi.",
        "**Widget test:** dựng màn hình với repository giả, kiểm tra hiển thị dữ liệu, trạng thái lỗi và không tràn "
        "layout ở màn hình nhỏ (320×640).",
        "**Backend:** bộ test tự động bằng pytest cho toàn bộ API (CSDL SQLite trong bộ nhớ, không gọi mạng thật).",
        "**Phân tích tĩnh:** `flutter analyze` không còn cảnh báo.",
    ]),
    ("h2", "6.2. Kết quả kiểm thử tự động"),
    ("table", ["Phần", "Số test", "Kết quả"], [
        ["Ứng dụng Flutter (unit + bloc + widget)", SO_TEST_MOBILE, "Đạt toàn bộ"],
        ["Backend (pytest)", SO_TEST_BACKEND, "Đạt toàn bộ"],
        ["Phân tích tĩnh (flutter analyze)", "–", "Không có lỗi/cảnh báo"],
    ], [50, 20, 30], "Bảng 6.1: Kết quả kiểm thử tự động"),
    ("h2", "6.3. Kiểm thử thủ công"),
    ("table", ["STT", "Kịch bản", "Kết quả mong đợi", "Kết quả"], [
        ["1", "Đăng ký tài khoản mới", "Vào màn hình Onboarding", "……"],
        ["2", "Đăng nhập sai mật khẩu", "Báo \"Wrong email or password\"", "……"],
        ["3", "Tắt mạng rồi mở Trang chủ", "Hiện dữ liệu đã lưu kèm banner offline", "……"],
        ["4", "Tắt backend rồi kéo làm mới", "Báo không kết nối được, có nút Thử lại", "……"],
        ["5", "Tạo / sửa / xoá bộ sưu tập", "Danh sách cập nhật đúng", "……"],
        ["6", "Thêm repo vào bộ sưu tập từ trang chi tiết", "Repo xuất hiện trong bộ sưu tập", "……"],
        ["7", "Tạo / sửa / xoá ghi chú", "Ghi chú cập nhật đúng, tìm kiếm được", "……"],
        ["8", "Đổi trạng thái học", "Biểu đồ thống kê thay đổi tương ứng", "……"],
        ["9", "Hỏi \"Cài đặt thế nào?\" trong Chat", "Trả lời kèm trích dẫn nguồn", "……"],
        ["10", "Bật nhắc học, đặt giờ", "Nhận thông báo cục bộ đúng giờ", "……"],
        ["11", "Để access token hết hạn", "Tự làm mới, không phải đăng nhập lại", "……"],
        ["12", "Đổi giao diện sáng/tối", "Toàn bộ màn hình đổi theo", "……"],
    ], [8, 36, 38, 18], "Bảng 6.2: Các kịch bản kiểm thử thủ công"),

    # =====================================================================
    ("h1", "CHƯƠNG 7. ĐỐI CHIẾU YÊU CẦU ĐỒ ÁN"),
    ("table", ["Yêu cầu", "Cách đáp ứng trong DevRadar AI"], [
        ["Flutter / Dart", "Toàn bộ ứng dụng viết bằng Flutter 3.47, Dart 3.13"],
        ["Cấu trúc phân lớp", "core / data (models, repositories, datasources) / presentation (screens, widgets, state)"],
        ["UI đồng bộ, responsive, animation",
         "Một bộ theme và widget dùng chung, sáng/tối; widget test 320×640; chuyển trang fade+slide, Hero, skeleton loading, biểu đồ có animation"],
        ["Quản lý trạng thái", "BLoC (flutter_bloc): Bloc và Cubit cho từng tính năng"],
        ["Tách UI và logic", "UI → Bloc/Cubit → Repository → DataSource; màn hình không gọi API trực tiếp"],
        ["Xử lý lỗi API + cache", "Timeout, mất mạng, lỗi server có thông báo + nút thử lại; cache SQLite network-first"],
        ["Kiểm thử", "Unit, bloc, widget test (Flutter) và pytest (backend)"],
        ["CRUD", "Bộ sưu tập và Ghi chú (tạo, xem, sửa, xoá); lộ trình học"],
        ["Chức năng cốt lõi – Quản lý cá nhân", "Thống kê: biểu đồ tròn, biểu đồ cột theo tuần, ngôn ngữ"],
        ["Bảo mật (dữ liệu online)", "Đăng ký/đăng nhập (email, Google, GitHub), JWT + refresh, token trong secure storage"],
        ["Thông báo", "Local notification: release mới của repo theo dõi, nhắc học hằng ngày"],
        ["Tìm kiếm", "Tìm repo (lọc, sắp xếp); tìm trong bộ sưu tập và ghi chú"],
        ["Lưu trữ Local + Cloud", "SQLite (sqflite) trên thiết bị + REST API tự xây dựng (PostgreSQL)"],
    ], [30, 70], "Bảng 7.1: Đối chiếu với yêu cầu đồ án CMP177"),

    # =====================================================================
    ("h1", "CHƯƠNG 8. KẾT LUẬN VÀ HƯỚNG PHÁT TRIỂN"),
    ("h2", "8.1. Kết quả đạt được"),
    ("bullets", [
        "Hoàn thành ứng dụng DevRadar AI với đầy đủ chức năng đã đề xuất và đáp ứng các yêu cầu kỹ thuật của môn học.",
        "Kiến trúc phân lớp rõ ràng, dễ mở rộng; logic nghiệp vụ có kiểm thử tự động.",
        "Tích hợp AI thực tế: tóm tắt README và hỏi đáp RAG có trích dẫn nguồn, chạy bằng mô hình cục bộ.",
        "Ứng dụng vẫn dùng được khi mất mạng nhờ cache SQLite.",
    ]),
    ("h2", "8.2. Hạn chế"),
    ("bullets", [
        "Thông báo push qua Firebase Cloud Messaging chưa bật vì cần cấu hình Firebase; hiện dùng thông báo cục bộ.",
        "Tốc độ trả lời của LLM phụ thuộc phần cứng máy chủ (chậm khi không có GPU).",
        "Trợ lý AI chỉ dựa trên README, chưa đọc thư mục docs và mã nguồn.",
    ]),
    ("h2", "8.3. Hướng phát triển"),
    ("bullets", [
        "Tích hợp Firebase Cloud Messaging cho push notification thời gian thực.",
        "So sánh hai repository bằng AI; tóm tắt thay đổi giữa các phiên bản.",
        "Hỏi đáp dựa trên cả thư mục docs và mã nguồn.",
        "Gợi ý repository theo lịch sử học của người dùng.",
    ]),

    # =====================================================================
    ("h1", "TÀI LIỆU THAM KHẢO"),
    ("reference", "[1] Flutter documentation. https://docs.flutter.dev"),
    ("reference", "[2] Bloc library documentation. https://bloclibrary.dev"),
    ("reference", "[3] sqflite package. https://pub.dev/packages/sqflite"),
    ("reference", "[4] flutter_local_notifications package. https://pub.dev/packages/flutter_local_notifications"),
    ("reference", "[5] GitHub REST API documentation. https://docs.github.com/en/rest"),
    ("reference", "[6] GitHub Docs – Authorizing OAuth apps. https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps"),
    ("reference", "[7] Google Identity – Authenticate with a backend server. https://developers.google.com/identity/sign-in/android/backend-auth"),
    ("reference", "[8] RFC 7636 – Proof Key for Code Exchange by OAuth Public Clients. https://www.rfc-editor.org/rfc/rfc7636"),
    ("reference", "[9] FastAPI documentation. https://fastapi.tiangolo.com"),
    ("reference", "[10] pgvector – Open-source vector similarity search for Postgres. https://github.com/pgvector/pgvector"),
    ("reference", "[11] P. Lewis et al., \"Retrieval-Augmented Generation for Knowledge-Intensive NLP Tasks\", NeurIPS 2020."),
    ("reference", "[12] Ollama. https://ollama.com"),
]
