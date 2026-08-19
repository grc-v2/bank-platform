# 09 — Nhóm I: Vận hành, đối chiếu & tuân thủ

Xuyên suốt mọi service. OPS-01 dùng từ GĐ2; OPS-03/04 vào GĐ6; OPS-02/05 hoàn thiện GĐ7.

---

### OPS-01 — Phát sự kiện tin cậy (transactional outbox)

**Nhóm/Service/GĐ** I / customer, product, core-banking (mỗi service một bảng outbox riêng) / GĐ2 · **Actor** Hệ thống · **Trigger** Nghiệp vụ phát event; publisher poll định kỳ · **Ưu tiên** Cao

**Mô tả** — Lời giải bài toán dual-write DB↔Kafka: nghiệp vụ ghi event vào bảng `outbox` CÙNG
transaction với dữ liệu; một publisher tách rời poll các dòng chưa publish
(`published_at IS NULL`, qua partial index) và đẩy sang Kafka, xong mới đánh dấu `published_at`.

**Luồng chính**
1. Nghiệp vụ (CUST-07, PROD-01, TRF-01…) ghi dòng outbox (aggregate_type/id, event_type, payload
   tự đủ) trong transaction nghiệp vụ.
2. Publisher poll lô dòng chưa publish theo `created_at`.
3. Publisher đẩy từng event lên Kafka (topic theo event_type; key = aggregate_id để giữ thứ tự
   theo aggregate; envelope mang `event_id` duy nhất).
4. Kafka ack → publisher đặt `published_at = now()`.

**Luồng ngoại lệ**
- E3. Đẩy Kafka lỗi → không đánh dấu; lần poll sau gửi lại → consumer có thể nhận TRÙNG
  (at-least-once) — vì thế mọi consumer bắt buộc idempotent theo `event_id` (NOTI-01,
  `processed_events` của core).
- E-ùn. Số dòng chưa publish vượt ngưỡng/tuổi dòng già nhất vượt ngưỡng → cảnh báo (NFR-9).

**Quy tắc nghiệp vụ**
- BR-OPS-01-1: `event_id` sinh lúc ghi outbox (đề xuất: `<service>-<outbox_id>`), bất biến qua
  các lần gửi lại — chính là khóa idempotency của consumer.
- BR-OPS-01-2: Payload theo hợp đồng versioned (`.v1`); đổi cấu trúc = version mới, không sửa v1.
- BR-OPS-01-3: Dòng đã publish giữ lại N ngày (mặc định 30) rồi job dọn — phục vụ điều tra.

**Dữ liệu** — Bảng: `customer.outbox`, `product.outbox`, `core_banking.outbox` (độc lập nhau).

---

### OPS-02 — Nhật ký kiểm toán (audit log)

**Nhóm/Service/GĐ** I / core-banking (`audit_log`); các service khác theo cùng khuôn / GĐ4, hoàn thiện GĐ7 · **Actor** Hệ thống (ghi); Auditor/CSO/Risk (đọc) · **Trigger** Mọi thao tác ghi nghiệp vụ; truy vấn khi điều tra · **Ưu tiên** Cao

**Mô tả** — Trả lời 5 câu hỏi cho mọi thao tác ghi: **ai** (`actor_user_id`, NULL = hệ thống/batch),
**làm gì** (action), **lên cái gì** (resource_type + resource_id), **khi nào** (at), **chi tiết ra
sao** (detail JSONB — giá trị trước/sau với thao tác nhạy cảm). Append-only.

**Luồng chính**
1. Mọi handler thao tác ghi, sau khi nghiệp vụ thành công trong transaction, ghi một dòng audit
   cùng transaction.
2. Người có quyền đọc tra theo resource (`idx_audit_resource`) hoặc theo actor (`idx_audit_actor`).

**Quy tắc nghiệp vụ**
- BR-OPS-02-1: Audit ghi cùng transaction với nghiệp vụ — nghiệp vụ thành công mà không có audit
  là bug mức cao.
- BR-OPS-02-2: Không ghi dữ liệu nhạy cảm dạng thô vào detail (mật khẩu, token, OTP, số giấy tờ
  đầy đủ).
- BR-OPS-02-3: Không sửa/xóa; niên hạn lưu tối thiểu theo quy định lưu trữ (mặc định 5 năm —
  tham số).
- BR-OPS-02-4: Các thao tác BẮT BUỘC audit: mọi thao tác quản trị (AUTH-06/07, PROD-*), mọi phê
  duyệt (CUST-07, FEE-03, TRF-06), mọi thao tác nhân viên trên dữ liệu khách (kể cả ĐỌC — 
  BR-CUST-12-2, BR-ACCT-04-2), mọi bút toán thủ công.

**Dữ liệu** — Bảng: `core_banking.audit_log` (+ `auth.login_audit` cho đăng nhập).

---

### OPS-03 — Lịch cuối ngày (EOD orchestration)

**Nhóm/Service/GĐ** I / core-banking (điều phối) / GĐ6 · **Actor** Hệ thống; Ops (theo dõi, chạy lại) · **Trigger** Lịch (mặc định 23:30 giờ hệ thống) hoặc chạy tay · **Ưu tiên** Cao

**Mô tả** — Chuỗi job cuối ngày chạy theo THỨ TỰ bắt buộc, mỗi bước idempotent theo ngày, bước
sau chỉ chạy khi bước trước xong; kết quả từng bước ghi lại để giám sát và chạy bù.

**Luồng chính (ngày nghiệp vụ D)**
1. **Nhả hold hết hạn** (ACCT-06 A3) — trả available cho khách trước khi tính toán.
2. **Quét saga quá hạn** (TRF-05) — chốt kết cục giao dịch treo.
3. **Quét hồ sơ**: KYC hết hạn (CUST-08), tài khoản bất hoạt → DORMANT (ACCT-05 A3), tài khoản
   PENDING quá hạn (ACCT-01 E6).
4. **Dự thu lãi** ngày D (INT-01).
5. **Trả lãi / đáo hạn** nếu D là ngày chốt: INT-02 (cuối tháng), INT-03 (sổ đáo hạn ngày D).
6. **Thu phí định kỳ** nếu D là ngày 01: FEE-02 cho tháng trước; thu nợ phí PENDING.
7. **Snapshot số dư** (GL-04).
8. **Đối chiếu** (GL-05) — pass thì chốt ngày; fail thì cảnh báo mức cao.
9. **Việc nhà**: tạo partition tháng tới nếu cần (OPS-04), dọn outbox đã publish quá hạn, dọn
   refresh token hết hạn.
10. Ghi tổng kết phiên EOD (bắt đầu/kết thúc, kết quả từng bước) — thấy được trên dashboard.

**Luồng ngoại lệ**
- E-bước-fail. Một bước fail → dừng chuỗi tại đó (các bước sau không chạy), cảnh báo Ops kèm
  bước + lỗi; Ops xử lý rồi **chạy lại từ bước fail** (mọi bước idempotent theo ngày nên chạy
  lại từ đầu cũng an toàn, chỉ tốn thời gian).
- E-quá-giờ. EOD chưa xong khi sang ngày mới → giao dịch online VẪN nhận (hệ thống 24/7);
  bút toán mới mang booking_date ngày mới; EOD tiếp tục xử lý trọn ngày D theo booking_date.

**Quy tắc nghiệp vụ**
- BR-OPS-03-1: Thứ tự các bước là cố định như trên; thêm job mới phải khai vị trí tường minh.
- BR-OPS-03-2: Mỗi bước idempotent theo (bước, ngày) — cơ chế cụ thể do từng chức năng đảm bảo
  (UNIQUE theo ngày, trạng thái posted, PK snapshot…).
- BR-OPS-03-3: Không có "đóng cửa hệ thống" trong phạm vi này — EOD chạy song song với giao dịch
  online; ranh giới ngày cắt theo booking_date.

**Dữ liệu** — Ghi kết quả phiên: đề xuất bảng `eod_runs` (Điểm mở — schema chưa có; tối thiểu
dùng audit_log + log có cấu trúc).

---

### OPS-04 — Quản lý partition sổ cái

**Nhóm/Service/GĐ** I / core-banking / GĐ6 · **Actor** Hệ thống (job trong EOD); DBA (lưu trữ) · **Trigger** EOD bước 9; chính sách lưu trữ dữ liệu · **Ưu tiên** Trung bình

**Mô tả** — `journal_lines` partition theo tháng (`created_at`); partition DEFAULT chỉ là lưới
an toàn. Job tạo partition TRƯỚC khi cần; ngày nào dữ liệu rơi vào DEFAULT là ngày cảnh báo.

**Luồng chính**
1. Job (EOD, tuần cuối tháng) kiểm partition tháng M+1 đã tồn tại chưa.
2. Chưa có → `CREATE TABLE journal_lines_<yyyy_mm> PARTITION OF ... FOR VALUES FROM ... TO ...`.
3. Job kiểm partition DEFAULT: có dòng nào không → cảnh báo (ai đó đã quên tạo trước) + quy trình
   tách dữ liệu ra partition đúng (thao tác DBA có kế hoạch, không tự động).

**Luồng thay thế**
- A1. Lưu trữ dữ liệu cũ: DROP partition tháng đã quá niên hạn lưu TRỰC TUYẾN (sau khi export
  lưu trữ lạnh) — lưu trữ tức thì thay cho DELETE hàng triệu dòng. Quyết định DROP là của DBA +
  Kế toán trưởng, có biên bản; niên hạn tổng thể tuân BR-OPS-02-3.

**Quy tắc nghiệp vụ**
- BR-OPS-04-1: Luôn tồn tại partition cho tháng hiện tại + tháng kế tiếp.
- BR-OPS-04-2: DEFAULT có dữ liệu = sự cố vận hành mức trung bình, xử lý trong tuần.

**Dữ liệu** — DDL trên `core_banking.journal_lines_*`.

---

### OPS-05 — Giám sát & dashboard vận hành

**Nhóm/Service/GĐ** I / mọi service + frontend dashboard / GĐ0 (đã có nền) → GĐ7 · **Actor** Dev/Ops · **Trigger** Theo dõi liên tục · **Ưu tiên** Trung bình

**Mô tả** — Mở rộng dashboard dev hiện có (React, 6 thẻ service) thành màn giám sát vận hành:
health/uptime từng service (đã có), cộng thêm các chỉ số nghiệp vụ phản ánh sức khỏe dòng tiền
và hàng đợi.

**Chỉ số yêu cầu (nguồn: NFR-9 + các cảnh báo định nghĩa rải trong đặc tả)**
1. Outbox: số dòng chưa publish + tuổi dòng già nhất, theo service (OPS-01 E-ùn).
2. Saga: số saga đang mở, số quá deadline, tuổi già nhất (TRF-05 E2).
3. Notification: tỉ lệ FAILED theo kênh, PENDING già nhất (NOTI-06).
4. EOD: trạng thái phiên gần nhất, bước fail nếu có (OPS-03).
5. Đối chiếu: PASS/FAIL phiên gần nhất, chênh lệch nếu FAIL (GL-05).
6. Đăng nhập: tỉ lệ fail bất thường (AUTH-08).
7. Hold: tổng tiền đang treo, hold sắp hết hạn không ai xử lý (ACCT-06).

**Luồng chính**
1. Mỗi service expose endpoint metrics nội bộ cho các chỉ số thuộc mình.
2. Dashboard poll qua gateway, hiển thị + tô ngưỡng (xanh/vàng/đỏ theo tham số).
3. Chỉ số đỏ → phát cảnh báo kênh vận hành (Telegram ops — dùng chính notification-service).

**Quy tắc nghiệp vụ**
- BR-OPS-05-1: Endpoint metrics yêu cầu quyền (không permit-all như `/info` hiện tại — cùng món
  nợ ở AUTH-09 Điểm mở).
- BR-OPS-05-2: Ngưỡng cảnh báo là cấu hình, có giá trị mặc định ghi trong tài liệu vận hành.

**Dữ liệu** — Đọc tổng hợp từ các bảng đã nêu; không bảng mới.
