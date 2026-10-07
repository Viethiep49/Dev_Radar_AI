// Dựng slide NHÁP cho buổi báo cáo đồ án DevRadar AI (nội dung cơ bản, nhóm chỉnh kỹ sau).
// Chạy:  cd bao_cao/tao_slide && npm install && node build_slide.js
// Ra:    bao_cao/SLIDE_DO_AN_DEVRADAR_AI.pptx   (chữ trong [ngoặc vuông] = chỗ cần điền)
const path = require("path");
const pptxgen = require("pptxgenjs");

const OUT = path.join(__dirname, "..", "SLIDE_DO_AN_DEVRADAR_AI.pptx");
const IMG = (name) => path.join(__dirname, "..", "hinh", name);

// Bảng màu: xanh đậm (nền tối), trắng xám (nền sáng), xanh dương (giống app), cam (nhấn).
const DARK = "0F1B2B";
const LIGHT = "F3F6F9";
const CARD = "FFFFFF";
const TEXT = "15202B";
const MUTED = "4A5866";
const BLUE = "1F6FEB";
const ORANGE = "C55A11";
const FONT = "Calibri";

const pres = new pptxgen();
pres.layout = "LAYOUT_WIDE"; // 13.33" x 7.5"
pres.title = "DevRadar AI – Báo cáo đồ án";
pres.theme = { headFontFace: FONT, bodyFontFace: FONT };

pres.defineSlideMaster({
  title: "CONTENT",
  background: { color: LIGHT },
  objects: [
    { placeholder: { options: { name: "eyebrow", type: "body", x: 0.6, y: 0.35, w: 12, h: 0.4, fontSize: 14, bold: true, color: BLUE, charSpacing: 2, margin: 0 }, text: "" } },
    { placeholder: { options: { name: "title", type: "title", x: 0.6, y: 0.75, w: 12.1, h: 0.9, fontSize: 34, bold: true, color: TEXT, margin: 0, valign: "top", align: "left" }, text: "" } },
    { text: { text: "DevRadar AI · CMP177", options: { x: 0.6, y: 7.0, w: 6, h: 0.3, fontSize: 11, color: "8A98A6", margin: 0 } } },
  ],
  slideNumber: { x: 12.2, y: 7.0, w: 0.6, h: 0.3, fontSize: 11, color: "8A98A6", align: "right" },
});

function content(eyebrow, title) {
  const s = pres.addSlide({ masterName: "CONTENT" });
  s.addText(eyebrow, { placeholder: "eyebrow" });
  s.addText(title, { placeholder: "title" });
  return s;
}

function card(s, x, y, w, h, heading, body, accent = BLUE) {
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x, y, w, h, rectRadius: 0.12, fill: { color: CARD }, line: { color: "DDE3EA", width: 1 },
    shadow: { type: "outer", color: "000000", opacity: 0.08, blur: 6, offset: 2, angle: 90 },
  });
  s.addText(heading, { x: x + 0.3, y: y + 0.22, w: w - 0.6, h: 0.5, fontSize: 20, bold: true, color: accent, margin: 0, isTextBox: true });
  s.addText(body, { x: x + 0.3, y: y + 0.75, w: w - 0.6, h: h - 0.95, fontSize: 15, color: MUTED, margin: 0, valign: "top", isTextBox: true });
}

function bullets(items) {
  return items.map((t, i) => ({ text: t, options: { bullet: true, breakLine: i < items.length - 1, paraSpaceAfter: 8 } }));
}

// 1. Bìa -------------------------------------------------------------------
{
  const s = pres.addSlide();
  s.background = { color: DARK };
  s.addText("CMP177 · LẬP TRÌNH TRÊN THIẾT BỊ DI ĐỘNG", { x: 0.8, y: 0.9, w: 11, h: 0.4, fontSize: 16, bold: true, color: "6CB4FF", charSpacing: 2, margin: 0, isTextBox: true });
  s.addText("DevRadar AI", { x: 0.8, y: 1.6, w: 11, h: 1.2, fontSize: 60, bold: true, color: "EEF3F8", margin: 0, isTextBox: true });
  s.addText("Ứng dụng theo dõi xu hướng công nghệ và trợ lý tìm hiểu mã nguồn mở", { x: 0.8, y: 2.85, w: 10, h: 1.0, fontSize: 24, color: "C3D2E2", margin: 0, valign: "top", isTextBox: true });
  s.addText([
    { text: "Giảng viên hướng dẫn: ", options: { color: "8AA0B6" } }, { text: "[Tên giảng viên]", options: { color: "EEF3F8", breakLine: true } },
    { text: "Nhóm thực hiện: ", options: { color: "8AA0B6" } }, { text: "[Thành viên 1] · [Thành viên 2] · [Thành viên 3] · [Thành viên 4]", options: { color: "EEF3F8", breakLine: true } },
    { text: "Lớp: ", options: { color: "8AA0B6" } }, { text: "23DTHD5", options: { color: "EEF3F8" } },
  ], { x: 0.8, y: 5.0, w: 11.5, h: 1.5, fontSize: 18, margin: 0, paraSpaceAfter: 6, valign: "top", isTextBox: true });
  s.addNotes("Giới thiệu tên đề tài, môn học, giảng viên hướng dẫn và các thành viên.");
}

// 2. Đặt vấn đề & mục tiêu -----------------------------------------------
{
  const s = content("01 · ĐẶT VẤN ĐỀ", "Quá nhiều repo mới, quá ít thời gian đọc");
  card(s, 0.6, 1.9, 5.9, 4.6, "Vấn đề", "", ORANGE);
  s.addText(bullets([
    "Hàng nghìn repository mới mỗi ngày trên GitHub",
    "README dài, khó biết repo làm gì, cài đặt ra sao",
    "Tự học thiếu lộ trình, không theo dõi được tiến độ",
  ]), { x: 0.9, y: 2.7, w: 5.3, h: 3.5, fontSize: 18, color: MUTED, valign: "top", margin: 0, isTextBox: true });
  card(s, 6.8, 1.9, 5.9, 4.6, "Mục tiêu", "", BLUE);
  s.addText(bullets([
    "Feed repository xu hướng theo sở thích",
    "Tóm tắt README và hỏi đáp với repo bằng AI",
    "Quản lý lộ trình học, thống kê tiến độ bằng biểu đồ",
  ]), { x: 7.1, y: 2.7, w: 5.3, h: 3.5, fontSize: 18, color: MUTED, valign: "top", margin: 0, isTextBox: true });
  s.addNotes("Chủ đề theo yêu cầu đồ án: Quản lý cá nhân, nên chức năng cốt lõi là thống kê và biểu đồ. Đối tượng: sinh viên CNTT, lập trình viên.");
}

// 3. Chức năng ------------------------------------------------------------
{
  const s = content("02 · CHỨC NĂNG", "Các nhóm chức năng chính");
  const items = [
    ["Tài khoản", "Đăng nhập email, Google, GitHub; tự làm mới token"],
    ["Khám phá", "Feed cá nhân hoá; tìm kiếm, lọc, sắp xếp"],
    ["Trợ lý AI", "Tóm tắt README; chat RAG có trích dẫn nguồn"],
    ["CRUD", "Bộ sưu tập, ghi chú, lộ trình học"],
    ["Thống kê", "Biểu đồ tròn, cột theo tuần, ngôn ngữ"],
    ["Thông báo", "Release mới của repo theo dõi; nhắc học hằng ngày"],
  ];
  items.forEach(([h, b], i) => {
    const col = i % 3, row = Math.floor(i / 3);
    card(s, 0.6 + col * 4.1, 1.9 + row * 2.4, 3.8, 2.1, h, b, i === 4 ? ORANGE : BLUE);
  });
  s.addNotes("Chi tiết từng chức năng: Bảng 3.1 trong báo cáo. Thống kê là chức năng cốt lõi của chủ đề Quản lý cá nhân.");
}

// 4. Kiến trúc hệ thống ---------------------------------------------------
{
  const s = content("03 · KIẾN TRÚC HỆ THỐNG", "Ứng dụng chỉ gọi backend");
  const boxes = [["Flutter App", "BLoC · SQLite cache", BLUE], ["Backend", "FastAPI · JWT · cron job", TEXT], ["AI Engine", "Ollama · RAG · pgvector", ORANGE]];
  boxes.forEach(([h, b, c], i) => {
    const x = 0.6 + i * 4.25;
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y: 2.1, w: 3.6, h: 1.7, rectRadius: 0.12, fill: { color: CARD }, line: { color: c, width: 2 } });
    s.addText(h, { x: x + 0.3, y: 2.3, w: 3.0, h: 0.5, fontSize: 22, bold: true, color: TEXT, margin: 0, isTextBox: true });
    s.addText(b, { x: x + 0.3, y: 2.9, w: 3.0, h: 0.6, fontSize: 15, color: MUTED, margin: 0, isTextBox: true });
    if (i < 2) s.addShape(pres.shapes.RIGHT_ARROW, { x: x + 3.7, y: 2.75, w: 0.45, h: 0.4, fill: { color: "9AA8B6" }, line: { color: "9AA8B6" } });
  });
  ["PostgreSQL 16 + pgvector", "GitHub REST API (cron 6 giờ/lần)", "Docker Compose"].forEach((t, i) => {
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 0.6 + i * 4.25, y: 4.4, w: 3.6, h: 0.8, rectRadius: 0.1, fill: { color: "E6EDF4" }, line: { color: "E6EDF4" } });
    s.addText(t, { x: 0.8 + i * 4.25, y: 4.4, w: 3.2, h: 0.8, fontSize: 15, color: TEXT, margin: 0, valign: "middle", isTextBox: true });
  });
  s.addText("App không chứa token GitHub hay khoá OAuth; tóm tắt AI được tạo trước bằng cron nên mở app là có ngay.", { x: 0.6, y: 5.6, w: 12, h: 0.8, fontSize: 16, color: MUTED, margin: 0, isTextBox: true });
  s.addNotes("Trình bày luồng: App -> Backend -> AI Engine; cron định kỳ lấy repo xu hướng, sinh tóm tắt, kiểm tra release.");
}

// 5. Kiến trúc Flutter ----------------------------------------------------
{
  const s = content("04 · KIẾN TRÚC FLUTTER", "UI → Bloc/Cubit → Repository → DataSource");
  [["presentation/", "Screens, widgets, Bloc/Cubit theo từng tính năng"],
   ["data/", "Models, repositories (network-first), remote API + SQLite"],
   ["core/", "Routes (go_router), theme, constants, ApiClient (Dio), database"]].forEach(([k, v], i) => {
    const y = 1.95 + i * 1.15;
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 0.6, y, w: 12.1, h: 0.95, rectRadius: 0.1, fill: { color: CARD }, line: { color: "DDE3EA", width: 1 } });
    s.addText(k, { x: 0.9, y, w: 3.0, h: 0.95, fontSize: 18, bold: true, fontFace: "Courier New", color: BLUE, margin: 0, valign: "middle", isTextBox: true });
    s.addText(v, { x: 4.0, y, w: 8.5, h: 0.95, fontSize: 17, color: MUTED, margin: 0, valign: "middle", isTextBox: true });
  });
  s.addText(bullets([
    "Quản lý trạng thái bằng BLoC (flutter_bloc): Bloc cho feed, tìm kiếm, chat; Cubit cho màn CRUD",
    "Màn hình không gọi API trực tiếp: mỗi màn tự tạo Bloc/Cubit từ repository",
  ]), { x: 0.6, y: 5.5, w: 12, h: 1.2, fontSize: 16, color: MUTED, margin: 0, valign: "top", isTextBox: true });
  s.addNotes("Đáp ứng yêu cầu cấu trúc phân lớp và tách UI/business logic.");
}

// 6. Công nghệ --------------------------------------------------------------
{
  const s = content("05 · CÔNG NGHỆ", "Công nghệ và thư viện sử dụng");
  const rows = [
    ["Thành phần", "Công nghệ"],
    ["Ứng dụng di động", "Flutter 3.47, Dart 3.13"],
    ["Quản lý trạng thái", "flutter_bloc, equatable"],
    ["Mạng, điều hướng", "dio, go_router"],
    ["Lưu trữ cục bộ", "sqflite, flutter_secure_storage, shared_preferences"],
    ["Biểu đồ, thông báo", "fl_chart, flutter_local_notifications"],
    ["Đăng nhập MXH", "google_sign_in, flutter_web_auth_2 (PKCE)"],
    ["Backend / AI", "FastAPI, PostgreSQL + pgvector, Ollama, Docker"],
  ].map((r, i) => r.map((t) => ({ text: t, options: { bold: i === 0, color: i === 0 ? "FFFFFF" : TEXT, fill: { color: i === 0 ? DARK : (i % 2 ? CARD : "EDF1F5") } } })));
  s.addTable(rows, { x: 0.6, y: 1.9, w: 12.1, colW: [3.6, 8.5], fontSize: 16, fontFace: FONT, border: { type: "solid", color: "DDE3EA", pt: 1 }, rowH: 0.52, margin: [0, 0.15, 0, 0.15], valign: "middle" });
  s.addNotes("Có thể rút gọn bảng khi trình bày; chi tiết ở Bảng 2.1 trong báo cáo.");
}

// 7–8. Giao diện -------------------------------------------------------------
function screens(eyebrow, title, a, capA, b, capB, note) {
  const s = content(eyebrow, title);
  [[a, capA, 0.6], [b, capB, 6.8]].forEach(([img, cap, x]) => {
    s.addImage({ path: IMG(img), x, y: 1.85, w: 5.9, h: 4.6, sizing: { type: "contain", w: 5.9, h: 4.6 } });
    s.addText(cap, { x, y: 6.5, w: 5.9, h: 0.4, fontSize: 14, italic: true, color: MUTED, align: "center", margin: 0, isTextBox: true });
  });
  s.addNotes(note);
}
screens("06 · GIAO DIỆN", "Khám phá và chi tiết repository",
  "h5_2_trang_chu_tim_kiem.jpg", "Trang chủ và tìm kiếm", "h5_3_chi_tiet.jpg", "Chi tiết repo, tóm tắt AI",
  "Demo: feed Dành cho bạn, nhãn HOT, tìm kiếm có bộ lọc; trang chi tiết có biểu đồ sao, trạng thái học, nút hỏi đáp AI. [Thay bằng ảnh/video demo mới nếu cần]");
screens("06 · GIAO DIỆN", "Quản lý cá nhân và thống kê",
  "h5_5_bo_suu_tap_ghi_chu_lo_trinh.jpg", "Bộ sưu tập, ghi chú, lộ trình (CRUD)", "h5_6_thong_ke.jpg", "Thống kê học tập",
  "CRUD bộ sưu tập và ghi chú; thống kê là chức năng cốt lõi: biểu đồ tròn theo trạng thái, cột theo tuần, ngôn ngữ.");

// 9. Offline & bảo mật -------------------------------------------------------
{
  const s = content("07 · ĐỘ TIN CẬY VÀ BẢO MẬT", "Dùng được khi mất mạng, token được bảo vệ");
  s.addImage({ path: IMG("h5_9_offline.jpg"), x: 0.6, y: 1.85, w: 5.4, h: 4.9, sizing: { type: "contain", w: 5.4, h: 4.9 } });
  card(s, 6.4, 1.9, 6.3, 2.3, "Offline với SQLite", "Network-first: gọi API trước, mất mạng / timeout / lỗi 5xx thì hiển thị dữ liệu đã lưu kèm banner và nút Thử lại.", BLUE);
  card(s, 6.4, 4.4, 6.3, 2.3, "Bảo mật", "JWT + tự làm mới token khi hết hạn; token trong Keystore/Keychain; OAuth GitHub dùng PKCE, secret chỉ ở backend.", ORANGE);
  s.addNotes("Đáp ứng yêu cầu xử lý lỗi API (timeout, mất mạng), cache, và đăng nhập/đăng ký cho dữ liệu online.");
}

// 10. Kiểm thử ---------------------------------------------------------------
{
  const s = content("08 · KIỂM THỬ", "Kiểm thử tự động");
  [["135", "test Flutter", "unit, bloc, widget"], ["240", "test backend", "pytest, toàn bộ API"], ["0", "cảnh báo", "flutter analyze"]].forEach(([n, l, d], i) => {
    const x = 0.6 + i * 4.1;
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y: 2.0, w: 3.8, h: 2.8, rectRadius: 0.12, fill: { color: CARD }, line: { color: "DDE3EA", width: 1 } });
    s.addText(n, { x, y: 2.2, w: 3.8, h: 1.3, fontSize: 60, bold: true, color: i === 1 ? ORANGE : BLUE, align: "center", margin: 0, isTextBox: true });
    s.addText(l, { x, y: 3.5, w: 3.8, h: 0.5, fontSize: 20, bold: true, color: TEXT, align: "center", margin: 0, isTextBox: true });
    s.addText(d, { x, y: 4.0, w: 3.8, h: 0.5, fontSize: 15, color: MUTED, align: "center", margin: 0, isTextBox: true });
  });
  s.addText("Repository test với mocktail + cache trong bộ nhớ (kiểm tra offline); bloc_test cho chuỗi state; widget test ở màn hình 320×640. Kiểm thử thủ công: Bảng 6.2 trong báo cáo.", { x: 0.6, y: 5.3, w: 12, h: 1.0, fontSize: 16, color: MUTED, margin: 0, isTextBox: true });
  s.addNotes("Tất cả test đều đạt. Có thể bổ sung kết quả kiểm thử thủ công của nhóm.");
}

// 11. Đối chiếu yêu cầu --------------------------------------------------------
{
  const s = content("09 · ĐỐI CHIẾU YÊU CẦU", "Đáp ứng yêu cầu đồ án CMP177");
  const req = [
    ["Yêu cầu", "Đáp ứng"],
    ["Flutter/Dart, phân lớp, BLoC", "core / data / presentation; flutter_bloc"],
    ["UI đồng bộ, responsive, animation", "Theme chung sáng/tối; Hero, fade/slide, skeleton"],
    ["Xử lý lỗi API + cache", "Thông báo lỗi + Thử lại; cache SQLite"],
    ["Kiểm thử", "135 test Flutter, 240 test backend"],
    ["CRUD", "Bộ sưu tập, ghi chú"],
    ["Cốt lõi: Quản lý cá nhân", "Thống kê bằng biểu đồ"],
    ["Bảo mật", "Đăng ký / đăng nhập, JWT, secure storage"],
    ["Thông báo", "Local notification: release mới, nhắc học"],
    ["Tìm kiếm · Lưu trữ", "Tìm repo, bộ sưu tập, ghi chú · SQLite + REST API"],
  ].map((r, i) => r.map((t) => ({ text: t, options: { bold: i === 0, color: i === 0 ? "FFFFFF" : TEXT, fill: { color: i === 0 ? DARK : (i % 2 ? CARD : "EDF1F5") } } })));
  s.addTable(req, { x: 0.6, y: 1.85, w: 12.1, colW: [4.6, 7.5], fontSize: 15, fontFace: FONT, border: { type: "solid", color: "DDE3EA", pt: 1 }, rowH: 0.47, margin: [0, 0.15, 0, 0.15], valign: "middle" });
  s.addNotes("Bám theo checklist trong YEU_CAU_DO_AN.md.");
}

// 12. Kết luận -----------------------------------------------------------------
{
  const s = content("10 · KẾT LUẬN", "Kết quả và hướng phát triển");
  card(s, 0.6, 1.9, 5.9, 4.6, "Đạt được", "", BLUE);
  s.addText(bullets([
    "Đủ chức năng đề xuất, đáp ứng yêu cầu môn học",
    "Tích hợp AI thực tế: tóm tắt, hỏi đáp RAG",
    "Chạy được khi mất mạng nhờ SQLite",
  ]), { x: 0.9, y: 2.7, w: 5.3, h: 3.5, fontSize: 18, color: MUTED, valign: "top", margin: 0, isTextBox: true });
  card(s, 6.8, 1.9, 5.9, 4.6, "Hướng phát triển", "", ORANGE);
  s.addText(bullets([
    "Push notification qua Firebase Cloud Messaging",
    "So sánh repo, tóm tắt thay đổi giữa các phiên bản",
    "Hỏi đáp dựa trên cả docs và mã nguồn",
  ]), { x: 7.1, y: 2.7, w: 5.3, h: 3.5, fontSize: 18, color: MUTED, valign: "top", margin: 0, isTextBox: true });
  s.addNotes("Hạn chế: chưa bật FCM (cần cấu hình Firebase), tốc độ LLM phụ thuộc GPU máy chủ.");
}

// 13. Cảm ơn ---------------------------------------------------------------------
{
  const s = pres.addSlide();
  s.background = { color: DARK };
  s.addText("Cảm ơn Thầy/Cô và các bạn đã lắng nghe", { x: 0.8, y: 2.6, w: 11.7, h: 1.2, fontSize: 40, bold: true, color: "EEF3F8", align: "center", margin: 0, isTextBox: true });
  s.addText("Hỏi & đáp", { x: 0.8, y: 3.9, w: 11.7, h: 0.6, fontSize: 24, color: "6CB4FF", align: "center", margin: 0, isTextBox: true });
  s.addNotes("Chuẩn bị sẵn demo trên điện thoại/emulator.");
}

pres.writeFile({ fileName: OUT }).then(() => console.log("Đã ghi", OUT));
