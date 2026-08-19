# 08 — Nhóm H: Thông báo & tương tác

Service: `notification-service` (schema `notification`). Nền tối thiểu ở GĐ2 (phục vụ OTP +
thông báo KYC), đầy đủ ở GĐ5.

Service này **chỉ nghe event** (consumer thuần): mọi dữ liệu cần để soạn thông báo phải nằm trong
payload event (event-carried state) — không gọi ngược hỏi service khác. Kênh: `TELEGRAM`
(đóng vai SMS/push trong phạm vi học tập), `EMAIL`, `WEBHOOK`.

---

### NOTI-01 — Tiêu thụ sự kiện idempotent

**Nhóm/Service/GĐ** H / notification / GĐ2 · **Actor** Hệ thống · **Trigger** Message đến từ Kafka (các topic trong event catalog, chương 00 §6) · **Ưu tiên** Cao

**Mô tả** — Xương sống của service: nhận event at-least-once từ Kafka và thuần hóa thành
"đúng một lần xử lý" bằng bảng `processed_events`. "Không báo hai lần là em ruột của không trừ
tiền hai lần" (comment schema).

**Luồng chính**
1. Consumer nhận message; đọc `event_id` từ envelope.
2. Hệ thống mở transaction: INSERT `processed_events(event_id)`.
3. INSERT thành công (event mới): xác định người nhận + các kênh theo preferences (NOTI-04),
   chọn template (NOTI-02), render nội dung từ payload, ghi các dòng `notifications` (PENDING)
   — tất cả CÙNG transaction với bước 2.
4. Commit; ack offset Kafka. Việc GỬI đi là của NOTI-03 (bất đồng bộ).

**Luồng ngoại lệ**
- E2. `event_id` đã tồn tại (message giao lại) → bỏ qua message, ack — không tạo thông báo trùng.
- E3a. Payload thiếu trường template cần → ghi notification FAILED kèm lỗi render (nhìn thấy
  được trên NOTI-06), ack message (không retry vô ích — payload sai là sai vĩnh viễn); cảnh báo
  dev.
- E3b. User đã opt-out mọi kênh của event_type → không tạo dòng nào; vẫn ghi processed (đã xử
  lý — kết quả là "không gửi").

**Quy tắc nghiệp vụ**
- BR-NOTI-01-1: INSERT processed_events và tạo notifications cùng transaction — nguyên tử.
- BR-NOTI-01-2: Consumer không gọi API service khác khi xử lý (event-carried state); payload
  thiếu là lỗi hợp đồng của PRODUCER, không vá bằng lookup.
- BR-NOTI-01-3: Thứ tự event không được giả định — mỗi thông báo tự đủ ngữ cảnh.

**Dữ liệu** — Bảng: `notification.processed_events`, `notifications`.

---

### NOTI-02 — Quản lý template thông báo

**Nhóm/Service/GĐ** H / notification / GĐ2 · **Actor** Admin · **Trigger** Thêm/sửa nội dung thông báo · **Ưu tiên** Trung bình

**Mô tả** — Nội dung tách khỏi việc gửi: `notification_templates` theo (template_code, channel,
locale, version). Đổi câu chữ = thêm VERSION mới, không sửa bản cũ — tra lại được thông báo cũ đã
gửi bằng bản nào.

**Luồng chính**
1. Admin soạn template: mã, kênh, locale (mặc định vi-VN), subject (email), body có placeholder
   (`{{amount}}`, `{{account_number_masked}}`…).
2. Hệ thống validate placeholder khớp danh mục biến của event_type tương ứng.
3. Hệ thống ghi version mới (version cũ giữ nguyên), `active = TRUE` cho bản mới, tắt active bản
   cũ cùng khóa.
4. Bản mới áp dụng cho thông báo tạo từ lúc này.

**Luồng ngoại lệ**
- E2. Placeholder không tồn tại trong payload chuẩn → từ chối lưu.
- A1. Rollback: kích hoạt lại version cũ (đổi cờ active), không sửa nội dung.

**Quy tắc nghiệp vụ**
- BR-NOTI-02-1: Mỗi (code, channel, locale) đúng một version active.
- BR-NOTI-02-2: Template chứa dữ liệu nhạy cảm phải dùng biến đã che (số tài khoản 4 số cuối);
  danh mục biến quy định mức che ngay từ payload.

**Dữ liệu** — Bảng: `notification.notification_templates`.

---

### NOTI-03 — Gửi thông báo & retry đa kênh

**Nhóm/Service/GĐ** H / notification / GĐ2 · **Actor** Hệ thống (worker) · **Trigger** Có dòng `notifications` PENDING (quét `idx_noti_pending`) · **Ưu tiên** Cao

**Mô tả** — Worker lấy thông báo PENDING, gửi qua adapter kênh (Telegram Bot API, SMTP, HTTP
webhook), ghi từng lần thử vào `delivery_attempts`, chốt SENT/FAILED theo chính sách retry.

**Luồng chính**
1. Worker lấy lô PENDING theo thứ tự tạo.
2. Với từng thông báo: gọi adapter kênh gửi nội dung đã render.
3. Thành công → ghi `delivery_attempts` (attempt_no, SUCCESS) + `notifications.status = SENT`.

**Luồng ngoại lệ**
- E2a. Gửi lỗi tạm (timeout, 5xx, rate limit) → ghi attempt FAILED kèm lỗi; retry theo backoff
  lũy tiến (1', 5', 30'…) tối đa N lần (mặc định 5); hết lượt → status FAILED.
- E2b. Lỗi vĩnh viễn (địa chỉ không tồn tại, webhook 4xx, bot bị chặn) → FAILED ngay, không retry.
- E-webhook. Gửi webhook: ký HMAC-SHA256 payload bằng `secret` của endpoint (NOTI-05), gửi kèm
  header chữ ký; cập nhật `last_status/last_checked_at` của endpoint.

**Quy tắc nghiệp vụ**
- BR-NOTI-03-1: attempt_no liên tục tăng, UNIQUE theo notification (`uq_attempts`) — lịch sử
  retry đọc được là nguyên liệu dashboard NOTI-06.
- BR-NOTI-03-2: Thông báo giao dịch (biến động số dư, OTP) ưu tiên gửi trước thông báo chăm sóc;
  SLA gửi OTP ≤ 30 giây.
- BR-NOTI-03-3: Nội dung đã render lưu đủ trong payload/notification để đọc lại đúng những gì đã
  gửi.

**Dữ liệu** — Bảng: `notifications`, `delivery_attempts`, `webhook_endpoints`.

---

### NOTI-04 — Tùy chọn nhận thông báo

**Nhóm/Service/GĐ** H / notification / GĐ5 · **Actor** Khách hàng · **Trigger** Khách chỉnh cài đặt thông báo · **Ưu tiên** Thấp

**Mô tả** — Opt-out theo TỪNG (event_type, channel): `user_notification_preferences`, vắng dòng =
mặc định BẬT. NOTI-01 tra bảng này khi quyết định tạo thông báo.

**Luồng chính**
1. Khách xem ma trận cài đặt: hàng = loại sự kiện, cột = kênh, ô = bật/tắt (mặc định bật).
2. Khách tắt/bật ô; hệ thống upsert dòng preference tương ứng.
3. Hiệu lực với event tạo SAU thời điểm đổi.

**Luồng ngoại lệ**
- E2. Loại sự kiện bắt buộc (OTP, cảnh báo bảo mật, biến động số dư — danh mục cấu hình) → không
  cho tắt, UI khóa ô; server vẫn kiểm (BR-NOTI-04-1).

**Quy tắc nghiệp vụ**
- BR-NOTI-04-1: Danh mục event_type bắt buộc không thể opt-out, cưỡng chế phía server.
- BR-NOTI-04-2: Preference gắn user_id (tham chiếu mềm sang auth.users).

**Dữ liệu** — Bảng: `notification.user_notification_preferences`.

---

### NOTI-05 — Quản lý webhook

**Nhóm/Service/GĐ** H / notification / GĐ5 · **Actor** Khách hàng (API — khách tích hợp hệ thống) · **Trigger** Đăng ký/đổi/tắt endpoint nhận sự kiện · **Ưu tiên** Thấp

**Mô tả** — Khách đăng ký URL nhận sự kiện dạng máy-với-máy. URL do người dùng nhập là **bề mặt
SSRF chính của service** — bắt buộc lọc đích trước khi chấp nhận và trước mỗi lần gửi.

**Luồng chính**
1. Khách đăng ký URL (https bắt buộc).
2. Hệ thống validate chống SSRF: phân giải DNS, chặn IP private/loopback/link-local/metadata;
   chặn cổng lạ; giới hạn scheme https.
3. Hệ thống sinh `secret` (64 hex, hiển thị MỘT lần cho khách lưu), ghi `webhook_endpoints`
   (active).
4. Hệ thống gửi sự kiện thử `webhook.test` có ký HMAC; khách xác nhận endpoint hoạt động.

**Luồng thay thế / ngoại lệ**
- E2. URL trỏ đích nội bộ → từ chối. Kiểm lại MỖI LẦN gửi (DNS rebinding) — không chỉ lúc đăng ký.
- A1. Đổi secret: sinh mới, hiển thị một lần; grace period chấp nhận chữ ký cũ 24h (Điểm mở:
  cần 2 secret song song — schema hiện 1 cột; phạm vi đầu: đổi là cắt ngay).
- A2. Tắt endpoint: `active = FALSE` — giữ lịch sử.
- A3. Endpoint fail liên tục (theo `last_status`) quá ngưỡng → tự tắt + thông báo khách qua kênh
  khác.

**Quy tắc nghiệp vụ**
- BR-NOTI-05-1: Payload webhook luôn ký HMAC-SHA256 bằng secret của endpoint; tài liệu công khai
  cách xác minh.
- BR-NOTI-05-2: Mỗi (user, url) duy nhất (`uq_webhook`).
- BR-NOTI-05-3: Không gửi PII đầy đủ qua webhook — cùng mức che như template (BR-NOTI-02-2).

**Dữ liệu** — Bảng: `notification.webhook_endpoints`.

---

### NOTI-06 — Lịch sử & giám sát gửi

**Nhóm/Service/GĐ** H / notification / GĐ7 · **Actor** Admin (dashboard); Khách hàng (lịch sử của mình) · **Trigger** Xem lịch sử / theo dõi chất lượng kênh · **Ưu tiên** Thấp

**Mô tả** — Hai góc nhìn: (1) khách xem lịch sử thông báo của mình (đã gửi gì, khi nào, kênh
nào); (2) Admin xem dashboard chất lượng: tỉ lệ FAILED theo kênh/khoảng thời gian, top lỗi,
thông báo kẹt PENDING lâu — dựng từ `notifications` + `delivery_attempts`.

**Luồng chính (dashboard)**
1. Admin chọn khoảng thời gian.
2. Hệ thống tổng hợp: đếm theo status × channel; phân bố attempt; danh sách FAILED gần nhất kèm
   lỗi; tuổi PENDING già nhất.
3. Vượt ngưỡng (tỉ lệ fail > X%, PENDING > Y phút) → cảnh báo vận hành (NFR-9).

**Quy tắc nghiệp vụ**
- BR-NOTI-06-1: Khách chỉ thấy thông báo `user_id` của mình; nội dung hiển thị lại đúng bản đã
  gửi (theo version template lúc đó).
- BR-NOTI-06-2: Dữ liệu notification giữ tối thiểu 12 tháng; dọn cũ bằng job có chính sách, không
  DELETE tay.

**Dữ liệu** — Đọc: `notifications`, `delivery_attempts`, `notification_templates`.
