# Quy trình làm việc nhóm

## 1. Fork và clone (làm một lần)

Repo gốc (**upstream**): `https://github.com/Viethiep49/Dev_Radar_AI`

1. Vào repo gốc → bấm **Fork** (để nguyên ô *"Copy the `develop` branch only"* cũng được – chỉ cần `develop`).
2. Clone bản fork của mình về và nối với repo gốc:

```bash
git clone https://github.com/<username-cua-ban>/Dev_Radar_AI.git
cd Dev_Radar_AI
git remote add upstream https://github.com/Viethiep49/Dev_Radar_AI.git
git fetch upstream
git checkout -b develop upstream/develop
```

- `origin` = bản fork của mình (push lên đây)
- `upstream` = repo gốc của nhóm (chỉ pull về, merge qua Pull Request)

## 2. Các nhánh

| Nhánh | Mục đích |
|---|---|
| `main` (upstream) | Bản ổn định để nộp/demo. Chỉ merge từ `develop`. |
| `develop` (upstream) | Nhánh tích hợp. Mọi PR đều merge vào đây. |
| `feature/<phần>-<tên>` (trên fork) | Nhánh làm việc của từng người. |

Tiền tố `<phần>`: `fe`, `be`, `ai`, `infra`. Ví dụ:

```
feature/fe-login-screen
feature/fe-search
feature/be-auth-api
feature/ai-recommend
fix/fe-crash-on-offline
```

## 3. Làm một tính năng

```bash
# Lấy code mới nhất của nhóm
git checkout develop
git pull upstream develop

# Tạo nhánh làm việc
git checkout -b feature/fe-login-screen
# ... code ...
git add .
git commit -m "feat(fe): add login screen"

# Push lên fork của mình
git push -u origin feature/fe-login-screen
```

Sau đó lên GitHub mở **Pull Request**: từ `<username>/Dev_Radar_AI : feature/fe-login-screen` → `Viethiep49/Dev_Radar_AI : develop`. Cần ít nhất 1 người khác review trước khi merge.

Nếu `develop` của nhóm có thay đổi trong lúc đang làm:

```bash
git fetch upstream
git merge upstream/develop      # trên nhánh feature của mình
git push
```

## 4. Quy ước commit

`<loại>(<phần>): <mô tả ngắn>`

- `feat` – tính năng mới
- `fix` – sửa lỗi
- `refactor` – sửa code không đổi hành vi
- `test` – thêm/sửa test
- `docs` – tài liệu
- `chore` – cấu hình, build, Docker…

## 5. Lưu ý

- **Không commit file `.env`** hay API key. Thêm biến mới thì cập nhật `.env.example`.
- Kéo `develop` của nhóm về thường xuyên (`git pull upstream develop`) để tránh conflict lớn.
- Không push thẳng lên repo gốc – mọi thay đổi đi qua Pull Request từ fork.
- Flutter: không gọi API/DB trực tiếp từ file UI – đi qua `data/repositories` và state management.
