# Đăng nhập bằng Google / GitHub

Backend đã có sẵn code. Chỉ cần **tạo key rồi dán vào `.env`** là dùng được. Key nào để trống thì cách đăng nhập đó tắt: endpoint trả `503 NOT_CONFIGURED`, còn đăng nhập bằng email/mật khẩu vẫn chạy bình thường.

## 1. Cách hoạt động

```
Google:  App ──google_sign_in──▶ Google ──ID token──▶ App ──POST /auth/google {id_token}──▶ Backend
                                                                         kiểm tra chữ ký + aud + iss + exp
GitHub:  App ──mở trình duyệt──▶ github.com/login/oauth/authorize ──redirect devradar://oauth/github?code=..──▶ App
         App ──POST /auth/github {code, code_verifier}──▶ Backend ──đổi code lấy token (dùng client secret)──▶ GitHub
                                                               └──GET /user, /user/emails──▶ GitHub
```

Cả hai cách đều kết thúc giống nhau: backend tìm hoặc tạo user, rồi trả về **JWT của backend** (`access_token`, `refresh_token`) **cùng định dạng như `/auth/login`**. Vì vậy phần còn lại của app không phải sửa gì.

**Quy tắc gộp tài khoản**
- Khóa định danh là **id của user phía nhà cung cấp** (Google `sub`, GitHub `id`), không dùng email vì user có thể đổi email.
- Lần đầu đăng nhập mà **email đã được xác minh** trùng với một tài khoản sẵn có thì gộp vào tài khoản đó. Mật khẩu cũ vẫn dùng được.
- Email **chưa xác minh** thì không gộp và không tạo tài khoản (trả `400`). Nhờ vậy không ai chiếm được tài khoản người khác bằng cách ghi email của họ vào hồ sơ GitHub.
- Tài khoản tạo từ Google/GitHub không có mật khẩu (`password_hash = NULL`), nên đăng nhập bằng mật khẩu sẽ nhận `401`.

## 2. Tạo key và dán vào `.env`

### Google
1. Vào <https://console.cloud.google.com/> → tạo project, rồi **APIs & Services → OAuth consent screen**: chọn loại *External*, thêm email test.
2. **Credentials → Create credentials → OAuth client ID**:
   - **Web application**: lấy client ID này (app Flutter truyền nó vào `serverClientId`, và `aud` của ID token sẽ là ID này).
   - **Android**: khai báo package name và SHA-1 (`cd mobile/android && ./gradlew signingReport`). Không cần dán ID của client này vào backend, trừ khi token được cấp cho nó.
3. Dán vào `.env`:
   ```env
   GOOGLE_CLIENT_IDS=1234-abc.apps.googleusercontent.com
   ```
   Nếu có nhiều client ID thì ngăn cách bằng dấu phẩy, **đặt Web client ID đầu tiên**.

### GitHub
1. Vào <https://github.com/settings/developers> → **OAuth Apps → New OAuth App**:
   - *Homepage URL*: điền gì cũng được, ví dụ link repo.
   - *Authorization callback URL*: `devradar://oauth/github`
2. **Generate a new client secret**.
3. Dán vào `.env`:
   ```env
   GITHUB_CLIENT_ID=Ov23li...
   GITHUB_CLIENT_SECRET=...        # CHỈ để ở backend, không bao giờ đưa vào app
   GITHUB_REDIRECT_URI=devradar://oauth/github
   ```

### Áp dụng
```bash
docker compose up -d --build backend   # container tự chạy `alembic upgrade head` (migration 0002) khi khởi động
curl http://localhost:8080/api/v1/auth/oauth/providers
```
Nếu `enabled: true` là đã bật.

## 3. API

| Method | Đường dẫn | Body | Kết quả |
|---|---|---|---|
| GET | `/api/v1/auth/oauth/providers` | – | `{google: {enabled, client_id}, github: {enabled, client_id, redirect_uri, authorize_url, scope}}` |
| POST | `/api/v1/auth/google` | `{"id_token": "..."}` | `200` giống `/auth/login` |
| POST | `/api/v1/auth/github` | `{"code": "...", "code_verifier": "..."}` | `200` giống `/auth/login` |

| Mã lỗi | Khi nào |
|---|---|
| `401 UNAUTHORIZED` | ID token sai, hết hạn hoặc cấp cho app khác; code GitHub sai hoặc đã dùng |
| `400 BAD_REQUEST` | Tài khoản không có email đã xác minh |
| `502 UPSTREAM_ERROR` | Không kết nối được Google/GitHub |
| `503 NOT_CONFIGURED` | Chưa dán key cho cách đăng nhập này |

## 4. Gợi ý phía Flutter

**Google** (package `google_sign_in`):
```dart
final google = GoogleSignIn(serverClientId: providers.google.clientId, scopes: ['email']);
final account = await google.signIn();
final idToken = (await account!.authentication).idToken;
await dio.post('/auth/google', data: {'id_token': idToken});
```
Cú pháp đúng tùy phiên bản `google_sign_in` (bản 7.x đổi API), nên xem README của package.

**GitHub** (ví dụ `flutter_web_auth_2`):
1. Tạo `state` và `code_verifier` ngẫu nhiên (43–128 ký tự), rồi tính `code_challenge = base64url(sha256(code_verifier))` (không có dấu `=` ở cuối).
2. Mở `authorize_url?client_id=..&redirect_uri=..&scope=read:user user:email&state=..&code_challenge=..&code_challenge_method=S256`, callback scheme là `devradar`.
3. Kiểm tra `state` trả về có khớp không, lấy `code`, rồi `POST /auth/github {code, code_verifier}`.
4. Đăng ký scheme `devradar` trong `AndroidManifest.xml` / `Info.plist` theo hướng dẫn của package.

## 5. Nguồn tham khảo
- Google: [Authenticate with a backend server](https://developers.google.com/identity/sign-in/android/backend-auth) (xác minh bằng `google.oauth2.id_token.verify_oauth2_token`, và dùng `sub` làm khóa, không dùng email).
- GitHub: [Authorizing OAuth apps](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps) (web flow, PKCE), và [`GET /user/emails`](https://docs.github.com/en/rest/users/emails) (cần scope `user:email`, có trường `verified`).
