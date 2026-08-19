# 01 — Nhóm A: Định danh & truy cập

Service: `auth-service` (schema `auth`), `gateway-service`. Giai đoạn 1.

Auth chỉ biết **danh tính** (users, roles, phiên) — không biết gì về khách hàng hay tài khoản
ngân hàng. Liên kết danh tính ↔ hồ sơ khách hàng nằm ở customer-service (CUST-11).

---

### AUTH-01 — Đăng ký người dùng

**Nhóm/Service/GĐ** A / auth-service / GĐ1 · **Actor** Khách hàng (chính); Admin (tạo user nội bộ) · **Trigger** Người dùng gửi form đăng ký · **Ưu tiên** Cao

**Mô tả** — Tạo tài khoản đăng nhập (username + mật khẩu). Đăng ký chỉ tạo *danh tính online*;
chưa phải khách hàng của ngân hàng (chưa có CIF) và chưa dùng được dịch vụ tài chính nào.

**Tiền điều kiện** — Username chưa tồn tại trong hệ thống.

**Luồng chính**
1. Người dùng nhập username, mật khẩu, xác nhận mật khẩu.
2. Hệ thống validate: username 3–100 ký tự (chữ, số, `.` `_`), mật khẩu đạt chính sách (BR-AUTH-01-2).
3. Hệ thống kiểm tra username chưa tồn tại (`uq_users_username`).
4. Hệ thống băm mật khẩu bằng BCrypt, tạo `users` với `status = ACTIVE`.
5. Hệ thống gán vai trò mặc định `CUSTOMER` (`user_roles`).
6. Hệ thống trả về kết quả đăng ký thành công (không tự động đăng nhập).

**Luồng thay thế / ngoại lệ**
- E3. Username đã tồn tại → báo lỗi chung chung "thông tin đăng ký không hợp lệ" (không xác nhận
  username nào đã có — chống dò tài khoản).
- E2. Mật khẩu yếu → trả danh sách tiêu chí chưa đạt.
- A1. Admin tạo user nội bộ: bỏ bước tự đăng ký; Admin nhập username + vai trò
  (TELLER/CSO/RISK_OFFICER/ADMIN), hệ thống sinh mật khẩu tạm buộc đổi ở lần đăng nhập đầu.

**Hậu điều kiện** — Thành công: tồn tại `users` ACTIVE + 1 dòng `user_roles`. Thất bại: không có
dữ liệu mới.

**Quy tắc nghiệp vụ**
- BR-AUTH-01-1: Username duy nhất toàn hệ thống (`uq_users_username`).
- BR-AUTH-01-2: Chính sách mật khẩu tối thiểu: ≥ 8 ký tự, có chữ hoa, chữ thường, chữ số. Không
  lưu mật khẩu thô ở bất kỳ đâu (kể cả log).
- BR-AUTH-01-3: Người tự đăng ký chỉ nhận vai trò `CUSTOMER`; vai trò nội bộ chỉ do Admin gán (AUTH-07).

**Dữ liệu** — Vào: `username` (bắt buộc), `password` (bắt buộc). Ra: user_id. Bảng: `auth.users`,
`auth.user_roles`.

**Điểm mở** — Đăng ký có yêu cầu email/SĐT ngay không? Hiện schema auth không giữ contact (contact
thuộc CIF); phương án: đăng ký tối giản, thu thập liên hệ ở bước mở hồ sơ khách hàng (CUST-01).

---

### AUTH-02 — Đăng nhập & phát hành token

**Nhóm/Service/GĐ** A / auth-service / GĐ1 · **Actor** Người dùng (mọi vai trò) · **Trigger** Gửi username + mật khẩu · **Ưu tiên** Cao

**Mô tả** — Xác thực và phát hành cặp token: access token (JWT, stateless, ngắn hạn ≤ 15 phút,
chứa user_id + roles) và refresh token (chuỗi ngẫu nhiên, dài hạn, lưu **hash** trong DB, thu hồi
được). Mọi lần thử đăng nhập — kể cả bằng username không tồn tại — đều ghi `login_audit`.

**Tiền điều kiện** — Không (endpoint công khai).

**Luồng chính**
1. Người dùng gửi username + mật khẩu (kèm IP, user-agent do hệ thống thu).
2. Hệ thống tìm user theo username, so mật khẩu với hash BCrypt.
3. Hệ thống kiểm tra `status = ACTIVE`.
4. Hệ thống sinh access token (JWT ký, TTL ngắn) + refresh token (TTL dài, ví dụ 30 ngày); lưu
   SHA-256 của refresh token vào `refresh_tokens`.
5. Hệ thống ghi `login_audit` (success = true, user_id, ip, user_agent).
6. Hệ thống trả về cặp token.

**Luồng thay thế / ngoại lệ**
- E2a. Username không tồn tại → ghi `login_audit` (success = false, user_id NULL, giữ nguyên
  username đã gõ) → trả "sai thông tin đăng nhập". Vẫn chạy so khớp mật khẩu giả (dummy hash) để
  thời gian phản hồi không tiết lộ username tồn tại hay không.
- E2b. Sai mật khẩu → ghi audit thất bại → trả cùng thông báo với E2a.
- E3. `status = LOCKED` hoặc `DISABLED` → ghi audit thất bại → báo "tài khoản không khả dụng, liên
  hệ ngân hàng" (không phân biệt hai trạng thái trong thông báo).
- E2c. Sai liên tiếp ≥ N lần (mặc định 5) trong 15 phút → tự chuyển `status = LOCKED` (xem
  BR-AUTH-02-3) và đi tiếp như E3.

**Hậu điều kiện** — Thành công: 1 dòng `refresh_tokens` mới + audit success. Thất bại: chỉ có audit.

**Quy tắc nghiệp vụ**
- BR-AUTH-02-1: Không bao giờ lưu/log refresh token thô — chỉ hash (`uq_refresh_tokens_hash`).
- BR-AUTH-02-2: Thông báo lỗi không phân biệt "sai username" và "sai mật khẩu".
- BR-AUTH-02-3: Tự khóa sau N lần sai liên tiếp; đếm theo `login_audit`. Mở khóa: qua AUTH-06
  hoặc tự mở sau thời gian nguội (tham số, mặc định 30 phút — chọn khi triển khai).
- BR-AUTH-02-4: Access token chứa tối thiểu: user_id (sub), roles, iat/exp, jti. KHÔNG chứa PII.

**Dữ liệu** — Vào: username, password. Ra: access_token, refresh_token, expires_in. Bảng:
`auth.users`, `auth.refresh_tokens`, `auth.login_audit`.

---

### AUTH-03 — Làm mới phiên (refresh token rotation)

**Nhóm/Service/GĐ** A / auth-service / GĐ1 · **Actor** Hệ thống kênh (client) · **Trigger** Access token sắp/đã hết hạn · **Ưu tiên** Cao

**Mô tả** — Đổi refresh token hợp lệ lấy access token mới. Áp dụng **rotation**: mỗi lần dùng,
refresh token cũ bị thu hồi và cấp cái mới — token bị đánh cắp chỉ dùng được một lần.

**Tiền điều kiện** — Client đang giữ refresh token.

**Luồng chính**
1. Client gửi refresh token.
2. Hệ thống băm và tìm trong `refresh_tokens` theo hash.
3. Hệ thống kiểm: chưa `revoked_at`, chưa quá `expires_at`, user tương ứng còn `ACTIVE`.
4. Hệ thống đặt `revoked_at = now()` cho token cũ, phát cặp token mới (như AUTH-02 bước 4).
5. Trả về cặp token mới.

**Luồng thay thế / ngoại lệ**
- E2. Không tìm thấy hash → 401.
- E3a. Token đã revoked → **nghi ngờ bị đánh cắp và replay**: thu hồi TOÀN BỘ refresh token còn
  hiệu lực của user đó, trả 401 (buộc đăng nhập lại mọi thiết bị).
- E3b. Token hết hạn → 401, xóa được dòng (dọn rác định kỳ).
- E3c. User không còn ACTIVE → 401.

**Hậu điều kiện** — Thành công: token cũ revoked, token mới tồn tại. E3a: mọi phiên của user bị hủy.

**Quy tắc nghiệp vụ**
- BR-AUTH-03-1: Rotation bắt buộc — không cấp access token mới mà giữ nguyên refresh token cũ.
- BR-AUTH-03-2: Dùng lại token đã revoked = tín hiệu tấn công → hủy mọi phiên (reuse detection).

**Dữ liệu** — Vào: refresh_token. Ra: cặp token mới. Bảng: `auth.refresh_tokens`.

---

### AUTH-04 — Đăng xuất & thu hồi phiên

**Nhóm/Service/GĐ** A / auth-service / GĐ1 · **Actor** Người dùng · **Trigger** Bấm đăng xuất / "đăng xuất mọi thiết bị" · **Ưu tiên** Trung bình

**Mô tả** — Thu hồi refresh token của phiên hiện tại (hoặc mọi phiên). Access token stateless nên
không thu hồi được — nó tự chết trong ≤ TTL; đây là lý do TTL phải ngắn.

**Luồng chính**
1. Người dùng gọi đăng xuất kèm refresh token hiện tại.
2. Hệ thống đặt `revoked_at = now()` cho token đó.
3. Trả về thành công (kể cả khi token đã revoked từ trước — idempotent).

**Luồng thay thế**
- A1. "Đăng xuất mọi thiết bị": revoke mọi refresh token chưa revoked của user (yêu cầu access
  token còn hiệu lực).

**Hậu điều kiện** — Refresh token không dùng được nữa; access token hiện hành còn sống tối đa TTL.

**Quy tắc nghiệp vụ** — BR-AUTH-04-1: Đăng xuất là idempotent, không lộ trạng thái token qua mã lỗi.

**Dữ liệu** — Bảng: `auth.refresh_tokens`.

---

### AUTH-05 — Đổi mật khẩu

**Nhóm/Service/GĐ** A / auth-service / GĐ1 · **Actor** Người dùng · **Trigger** Yêu cầu đổi mật khẩu · **Ưu tiên** Trung bình

**Mô tả** — Người dùng đã đăng nhập tự đổi mật khẩu; buộc xác nhận bằng mật khẩu cũ.

**Luồng chính**
1. Người dùng nhập mật khẩu hiện tại + mật khẩu mới (×2).
2. Hệ thống xác thực mật khẩu hiện tại; validate mật khẩu mới theo BR-AUTH-01-2 và khác mật khẩu cũ.
3. Hệ thống cập nhật `password_hash`.
4. Hệ thống thu hồi mọi refresh token TRỪ phiên hiện tại (các thiết bị khác phải đăng nhập lại).
5. Ghi audit (không ghi giá trị mật khẩu).

**Luồng ngoại lệ**
- E2a. Sai mật khẩu hiện tại → từ chối; sai ≥ N lần áp cơ chế khóa BR-AUTH-02-3.
- E2b. Mật khẩu mới không đạt chính sách → trả tiêu chí chưa đạt.

**Hậu điều kiện** — Hash mới có hiệu lực; các phiên khác bị hủy.

**Điểm mở** — "Quên mật khẩu" (reset không cần mật khẩu cũ) cần kênh liên hệ đã xác minh, mà
contact thuộc CIF → chỉ làm được sau CUST-05; đưa vào backlog GĐ2 với luồng: yêu cầu reset → OTP
tới kênh đã xác minh → đặt mật khẩu mới → thu hồi mọi phiên.

---

### AUTH-06 — Quản trị người dùng (khóa / mở khóa / vô hiệu)

**Nhóm/Service/GĐ** A / auth-service / GĐ1 · **Actor** Admin · **Trigger** Yêu cầu quản trị (khiếu nại, nghi gian lận, nghỉ việc…) · **Ưu tiên** Cao

**Mô tả** — Chuyển trạng thái user: `ACTIVE ⇄ LOCKED` (tạm, đảo ngược được) và `→ DISABLED`
(vô hiệu dài hạn: nhân viên nghỉ việc, khách đóng quan hệ). Khóa/vô hiệu phải giết phiên ngay.

**Luồng chính (khóa)**
1. Admin chọn user, nhập lý do, xác nhận khóa.
2. Hệ thống đặt `status = LOCKED`.
3. Hệ thống thu hồi mọi refresh token của user (cùng transaction).
4. Ghi audit (actor = Admin, lý do).

**Luồng thay thế**
- A1. Mở khóa: `LOCKED → ACTIVE`; không tự khôi phục phiên cũ.
- A2. Vô hiệu: `ACTIVE/LOCKED → DISABLED` + thu hồi phiên. Kích hoạt lại từ DISABLED yêu cầu quy
  trình phê duyệt riêng (ghi rõ lý do), không phải thao tác một nút.
- E1. Admin tự khóa chính mình → từ chối (chống tự khóa toàn bộ quản trị).

**Trạng thái (`users.status`)**

| Từ | Đến | Điều kiện / hành động kèm theo |
|---|---|---|
| ACTIVE | LOCKED | Admin khóa, hoặc tự động do sai mật khẩu (BR-AUTH-02-3); revoke mọi refresh token |
| LOCKED | ACTIVE | Admin mở khóa, hoặc hết thời gian nguội (nếu khóa tự động) |
| ACTIVE, LOCKED | DISABLED | Admin vô hiệu; revoke mọi refresh token |
| DISABLED | ACTIVE | Quy trình phê duyệt riêng |

**Quy tắc nghiệp vụ**
- BR-AUTH-06-1: Đổi trạng thái và thu hồi phiên là MỘT transaction — không tồn tại khoảnh khắc
  "đã khóa nhưng phiên còn sống" quá TTL access token.
- BR-AUTH-06-2: Mọi thao tác quản trị bắt buộc có lý do và ghi audit.

**Dữ liệu** — Bảng: `auth.users`, `auth.refresh_tokens`.

---

### AUTH-07 — Quản lý vai trò

**Nhóm/Service/GĐ** A / auth-service / GĐ1 · **Actor** Admin · **Trigger** Yêu cầu gán/thu hồi vai trò · **Ưu tiên** Trung bình

**Mô tả** — Gán/thu hồi vai trò cho user. Một user nhiều vai trò là bình thường (TELLER kiêm ADMIN).
Tập vai trò cố định: `CUSTOMER, TELLER, CSO, RISK_OFFICER, ADMIN, SYSTEM`.

**Luồng chính**
1. Admin chọn user, chọn vai trò cần gán/bỏ.
2. Hệ thống validate vai trò thuộc tập cho phép (`ck_user_roles_role`).
3. Hệ thống thêm/xóa dòng `user_roles`; ghi audit.
4. Vai trò mới có hiệu lực từ access token TIẾP THEO (JWT đang sống giữ roles cũ đến khi hết hạn).

**Luồng ngoại lệ**
- E2a. Thu hồi ADMIN của admin cuối cùng còn ACTIVE → từ chối.
- E2b. Gán `SYSTEM` cho người thật → từ chối; SYSTEM chỉ dành cho service account.

**Quy tắc nghiệp vụ**
- BR-AUTH-07-1: Hệ thống phải luôn còn ≥ 1 user ACTIVE mang vai trò ADMIN.
- BR-AUTH-07-2: Độ trễ hiệu lực = TTL access token; thao tác cần hiệu lực tức thì phải kèm khóa
  user (AUTH-06).

**Dữ liệu** — Bảng: `auth.user_roles`.

---

### AUTH-08 — Giám sát đăng nhập & phát hiện dò tài khoản

**Nhóm/Service/GĐ** A / auth-service / GĐ7 (nền từ GĐ1) · **Actor** Risk Officer · **Trigger** Định kỳ / cảnh báo · **Ưu tiên** Trung bình

**Mô tả** — Khai thác `login_audit` (append-only, giữ cả lần đăng nhập bằng username không tồn tại)
để phát hiện: dò username (nhiều username lạ từ một IP), brute force (một username sai liên tiếp),
đăng nhập bất thường (IP/thiết bị mới).

**Luồng chính**
1. Hệ thống (job định kỳ) quét `login_audit` theo cửa sổ thời gian, tính các chỉ báo:
   tỉ lệ fail theo IP, số username distinct thất bại theo IP, chuỗi fail theo username.
2. Vượt ngưỡng → sinh cảnh báo (notification tới Risk Officer, event nội bộ).
3. Risk Officer xem màn hình tra cứu: lọc theo username / IP / khoảng thời gian / kết quả.
4. Risk Officer quyết định hành động: yêu cầu Admin khóa user (AUTH-06), chặn IP ở gateway (AUTH-09).

**Quy tắc nghiệp vụ**
- BR-AUTH-08-1: `login_audit` không sửa, không xóa; niên hạn lưu tối thiểu 12 tháng.
- BR-AUTH-08-2: Ngưỡng cảnh báo là tham số cấu hình, không hardcode.

**Dữ liệu** — Bảng: `auth.login_audit`. Ra: báo cáo/cảnh báo.

**Điểm mở** — Chặn IP là năng lực gateway; phạm vi đầu chỉ cần cảnh báo + khóa user.

---

### AUTH-09 — Xác thực & định tuyến tại gateway

**Nhóm/Service/GĐ** A / gateway-service / GĐ1 · **Actor** Hệ thống · **Trigger** Mọi request từ ngoài · **Ưu tiên** Cao

**Mô tả** — Gateway là cửa duy nhất từ ngoài vào: xác minh chữ ký + hạn JWT, gắn danh tính đã
xác minh vào request chuyển tiếp (header nội bộ), định tuyến về đúng service, chặn tại cửa những
request không hợp lệ. Service nghiệp vụ tin danh tính từ gateway nhưng vẫn tự kiểm vai trò
(defense in depth).

**Luồng chính**
1. Client gọi API kèm `Authorization: Bearer <access_token>`.
2. Gateway xác minh chữ ký, hạn, định dạng token (không gọi auth-service — stateless).
3. Gateway gắn user_id + roles vào header nội bộ, xóa header giả mạo do client tự gắn.
4. Gateway định tuyến theo path prefix về service tương ứng.
5. Service kiểm vai trò theo ma trận §4 chương 00 rồi xử lý.

**Luồng ngoại lệ**
- E2. Token thiếu/sai/hết hạn → 401 ngay tại gateway (trừ danh sách endpoint công khai: đăng ký,
  đăng nhập, refresh, health/info).
- E4. Path không khớp route nào → 404.
- E1. Vượt rate limit theo IP/user (tham số) → 429.

**Quy tắc nghiệp vụ**
- BR-AUTH-09-1: Danh sách endpoint công khai là cấu hình tường minh, mặc định mọi route yêu cầu token.
- BR-AUTH-09-2: Request nội bộ service-to-service không đi vòng ra gateway.
- BR-AUTH-09-3: Gateway không log token, không log body chứa credential.

**Điểm mở** — Các API `GET .../info` của dashboard đang permit-all; khi GĐ1 xong phải thu về sau
JWT (đã ghi ở README repo).
