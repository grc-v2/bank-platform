# 06 — Nhóm F: Chuyển tiền & thanh toán

Service: `core-banking-service` (schema `core_banking`). Giai đoạn 5.

Máy trạng thái lệnh chuyển (`transfers.status`):

| Từ | Đến | Khi nào |
|---|---|---|
| — | PENDING | Lệnh được tiếp nhận, đang xử lý |
| PENDING | COMPLETED | Nội bộ: hạch toán xong (cùng transaction) |
| PENDING | PENDING_EXTERNAL | Liên NH: đã hạch toán tiền nguồn vào GL trung gian, chờ đối tác |
| PENDING | FAILED | Trượt validate/hạn mức/số dư — chưa hạch toán gì |
| PENDING_EXTERNAL | COMPLETED | Đối tác xác nhận |
| PENDING_EXTERNAL | REVERSED | Đối tác từ chối / quá hạn → đã ghi bút toán đảo |
| COMPLETED | REVERSED | Tra soát chấp nhận hoàn (TRF-06) |

Bất biến hai máy trạng thái (ghi chú schema): `transfers.status` và
`external_transfers.saga_state` mô tả cùng sự việc, cập nhật trong CÙNG transaction:
PARTNER_CONFIRMED ↔ COMPLETED; PARTNER_REJECTED/TIMED_OUT → COMPENSATED ↔ REVERSED.

---

### TRF-01 — Chuyển tiền nội bộ

**Nhóm/Service/GĐ** F / core-banking / GĐ5 · **Actor** Khách hàng (INTERNET/MOBILE/API), Teller (BRANCH) · **Trigger** Lệnh chuyển tới tài khoản trong cùng ngân hàng · **Ưu tiên** Cao nhất

**Mô tả** — Chuyển giữa hai tài khoản trong hệ thống: **nguyên tử trong một transaction DB** —
kiểm tra, tính phí, hạch toán 3 dòng (Nợ nguồn amount+phí / Có đích amount / Có GL 4010 phí),
cập nhật hai số dư, trừ hạn mức, COMPLETED — tất cả hoặc không gì cả. Chống trùng lệnh bằng
`idempotency_key`.

**Tiền điều kiện** — Người lệnh đã đăng nhập, là holder có quyền giao dịch trên tài khoản nguồn.

**Luồng chính**
1. Khách nhập: tài khoản nguồn, số tài khoản đích, số tiền, nội dung; kênh + `idempotency_key`
   do client sinh.
2. Hệ thống tra tài khoản đích theo số → hiển thị tên chủ tài khoản (che một phần) để khách xác
   nhận đúng người nhận.
3. Khách xác nhận lệnh (kênh online: bước xác nhận giao dịch — xem Điểm mở SCA).
4. Hệ thống validate: nguồn ACTIVE, đích ACTIVE (không DORMANT/FROZEN/CLOSED), nguồn ≠ đích
   (`ck_transfers_self`), cùng loại tiền (BR-G4), amount > 0.
5. Hệ thống tính phí `INTERNAL_TRANSFER` theo biểu phí sản phẩm nguồn tại hôm nay (PROD-07).
6. Hệ thống kiểm hạn mức (TRF-04): PER_TRANSACTION, PER_DAY, PER_MONTH theo kênh.
7. Hệ thống kiểm `available_balance` nguồn ≥ amount + phí.
8. Hệ thống, trong MỘT transaction:
   a. Ghi `transfers` (INTERNAL, PENDING, idempotency_key).
   b. Gọi GL-02: bút toán TRANSFER 3 dòng (2 dòng nếu phí = 0).
   c. Cập nhật `transfer_limit_usage` (TRF-04).
   d. Ghi `fee_charges` (POSTED, source trỏ transfer) nếu có phí.
   e. Đặt transfer COMPLETED + `journal_entry_id` (DB đòi — `ck_transfers_completed_posted`),
      `completed_at`.
   f. Ghi outbox `transfer.completed.v1` (hai bản ghi hướng người gửi + người nhận, hoặc một
      event payload đủ hai phía).
9. Trả kết quả + số tham chiếu (`transfer_reference`); notification báo biến động số dư hai phía.

**Luồng thay thế / ngoại lệ**
- E2. Số tài khoản đích không tồn tại → báo ngay ở bước tra cứu.
- E4a. Đích FROZEN/CLOSED/DORMANT → từ chối "tài khoản đích không nhận được tiền" (không lộ trạng
  thái cụ thể).
- E6. Vượt hạn mức → từ chối, ghi transfer FAILED kèm mã lỗi hạn mức, nêu hạn mức còn lại trong
  ngày.
- E7. Không đủ số dư khả dụng → từ chối, transfer FAILED (hoặc không ghi transfer nếu trượt trước
  khi tiếp nhận — chuẩn hóa: lệnh đã qua xác nhận (bước 3) thì luôn ghi lại, kể cả FAILED, để tra
  soát).
- E8a. `idempotency_key` trùng (client retry): bắt unique violation → TRA và TRẢ VỀ chính transfer
  đã tạo trước đó (đúng ngữ nghĩa idempotent — comment schema); không tạo lệnh mới.
- E8b. Optimistic lock trượt trên accounts → retry nội bộ giới hạn; vẫn trượt → FAILED "hệ thống
  bận, thử lại".

**Hậu điều kiện** — COMPLETED: hai số dư đã dịch chuyển, bút toán cân trong sổ, hạn mức đã trừ,
event đã vào outbox. FAILED: không có bút toán, không trừ hạn mức, có bản ghi lệnh để tra vết.

**Quy tắc nghiệp vụ**
- BR-TRF-01-1: Phí thu người GỬI (đích nhận đủ amount). Chính sách phí người nhận: ngoài phạm vi.
- BR-TRF-01-2: Không có "chuyển tương lai/định kỳ" trong phạm vi này (standing order — chương 10).
- BR-TRF-01-3: Lệnh FAILED không tái kích hoạt — khách lập lệnh mới (idempotency_key mới).
- BR-TRF-01-4: `transfer_reference` sinh duy nhất (BR-G9), hiển thị cho cả hai phía, dùng khi tra
  soát.

**Dữ liệu** — Vào: source_account, destination_account_number (nội bộ tra ra
`destination_account_id` — `ck_transfers_target` bắt INTERNAL phải có id, cấm number/bank_code),
amount, description, channel, idempotency_key. Bảng: `transfers`, `fee_charges`,
`transfer_limit_usage` + qua GL-02.

**Điểm mở** — Xác nhận giao dịch mạnh (SCA: OTP/soft-token khi vượt ngưỡng): phạm vi đầu dựa vào
phiên đăng nhập; thiết kế SCA đầy đủ ở GĐ7 (thực tế VN: bắt buộc theo QĐ 2345 với giao dịch lớn).

---

### TRF-02 — Chuyển tiền liên ngân hàng đi (saga)

**Nhóm/Service/GĐ** F / core-banking / GĐ5 · **Actor** Khách hàng; Hệ thống (saga worker) · **Trigger** Lệnh chuyển tới ngân hàng khác · **Ưu tiên** Cao

**Mô tả** — Chuyển ra ngoài hệ thống qua đối tác thanh toán (trừu tượng hóa NAPAS). Không có
transaction phân tán — dùng **saga**: hạch toán tiền nguồn vào GL trung gian 1900 TRƯỚC ("tiền đã
rời tài khoản nguồn nhưng chưa tới đích"), gọi đối tác SAU; đối tác từ chối/quá hạn thì ghi bút
toán ĐẢO (không bao giờ xóa bút toán gốc). Trạng thái saga (`external_transfers.saga_state`):

| Từ | Đến | Khi nào |
|---|---|---|
| — | HOLD_PLACED | Đã hạch toán tiền nguồn vào 1900, chưa gọi đối tác |
| HOLD_PLACED | PARTNER_REQUESTED | Worker đã gọi đối tác, chờ trả lời |
| PARTNER_REQUESTED | PARTNER_CONFIRMED | Đối tác báo có — transfer COMPLETED |
| PARTNER_REQUESTED | PARTNER_REJECTED | Đối tác từ chối — chờ đảo |
| HOLD_PLACED, PARTNER_REQUESTED | TIMED_OUT | Quá `deadline_at` (TRF-05) — chờ đảo |
| PARTNER_REJECTED, TIMED_OUT | COMPENSATED | Bút toán đảo đã ghi — transfer REVERSED |

**Tiền điều kiện** — như TRF-01, thêm: mã ngân hàng đối tác thuộc danh mục hỗ trợ.

**Luồng chính**
1. Khách nhập: nguồn, mã ngân hàng đích + số tài khoản đích, số tiền, nội dung
   (+ idempotency_key, kênh).
2. Hệ thống tra tên chủ tài khoản đích qua đối tác (dịch vụ inquiry) để khách xác nhận; khách
   xác nhận.
3. Hệ thống validate + tính phí `EXTERNAL_TRANSFER` (PERCENT kẹp min/max — seed: 0,05%, sàn
   5.500, trần 1.100.000) + kiểm hạn mức + kiểm số dư (như TRF-01 bước 4–7).
4. Hệ thống, trong MỘT transaction (giai đoạn 1 của saga):
   a. Ghi `transfers` (EXTERNAL, destination_account_number + bank_code — `ck_transfers_target`
      cấm destination_account_id).
   b. GL-02: bút toán TRANSFER — Nợ TK nguồn (amount+phí) / Có GL 1900 (amount) / Có GL 4010 (phí);
      gắn `journal_entry_id`.
   c. Cập nhật hạn mức, fee_charges (như TRF-01).
   d. Transfer → PENDING_EXTERNAL; ghi `external_transfers` (HOLD_PLACED,
      `partner_idempotency_key` sinh mới, `deadline_at` = now + SLA đối tác, mặc định 15 phút).
5. Saga worker (bất đồng bộ) lấy saga HOLD_PLACED: gọi API đối tác với
   `partner_idempotency_key`; chuyển PARTNER_REQUESTED.
6. Đối tác trả **CHẤP NHẬN** (đồng bộ hoặc callback): trong một transaction — saga
   PARTNER_CONFIRMED + transfer COMPLETED + `completed_at` + lưu `partner_ref`; outbox
   `transfer.completed.v1`; thông báo khách.

**Luồng thay thế / ngoại lệ**
- E6a. Đối tác **TỪ CHỐI** (sai số tài khoản, tài khoản đích đóng…): saga PARTNER_REJECTED; bước
  đền bù: GL-03 đảo bút toán gốc (tiền + phí về nguồn) → saga COMPENSATED + transfer REVERSED
  cùng transaction; outbox `transfer.reversed.v1`; thông báo khách kèm lý do đối tác trả.
- E5a. Gọi đối tác lỗi mạng/timeout đơn lẻ → retry với ĐÚNG `partner_idempotency_key` (đối tác
  khử trùng); còn hạn deadline thì cứ retry theo backoff.
- E-deadline. Quá `deadline_at` mà chưa có kết cục → TRF-05 xử lý (TIMED_OUT → đền bù).
- E-mập-mờ. Đối tác đã ghi có nhưng ta đã đảo (timeout rồi đối tác confirm muộn) → khoản này lộ
  ra ở phiên ĐỐI SOÁT với đối tác (GL 1900 lệch); xử lý bằng quy trình tra soát TRF-06, không tự
  động.
- E8. idempotency_key client trùng → như TRF-01 E8a.

**Hậu điều kiện** — COMPLETED: tiền ở 1900 chờ quyết toán với đối tác (số dư 1900 clear ở phiên
đối soát). REVERSED: nguồn nhận lại đủ tiền + phí, sổ có đủ bút toán gốc + đảo.

**Quy tắc nghiệp vụ**
- BR-TRF-02-1: Hai idempotency key khác vai: `idempotency_key` (client↔ta), 
  `partner_idempotency_key` (ta↔đối tác) — không dùng lẫn.
- BR-TRF-02-2: Hoàn tiền do lỗi đối tác/quá hạn hoàn cả phí (khách không mất phí cho giao dịch
  không thành).
- BR-TRF-02-3: Mọi chuyển tiếp saga_state và transfers.status cập nhật cùng transaction (bất biến
  hai máy trạng thái).
- BR-TRF-02-4: Số dư GL 1900 = tổng các khoản PENDING_EXTERNAL chưa quyết toán + khoản chờ đối
  soát — phải về 0 sau phiên đối soát (BR-GL-01-3).

**Dữ liệu** — Bảng: `transfers`, `external_transfers`, `fee_charges`, `transfer_limit_usage` +
GL-02/03.

---

### TRF-03 — Nhận tiền liên ngân hàng đến

**Nhóm/Service/GĐ** F / core-banking / GĐ5 · **Actor** Hệ thống (API/callback từ đối tác) · **Trigger** Đối tác báo có khoản tiền chuyển tới khách của ta · **Ưu tiên** Cao

**Mô tả** — Chiều ngược của TRF-02: nhận lệnh ghi có từ đối tác, kiểm tài khoản đích, hạch toán
Nợ GL 1900 / Có TK khách, báo khách. Phải idempotent theo tham chiếu của đối tác và trả lời
được chấp nhận/từ chối để đối tác xử lý phía họ.

**Luồng chính**
1. Đối tác gọi API ghi có: partner_ref (duy nhất), số tài khoản đích, tên đích, số tiền, nội
   dung, ngân hàng nguồn.
2. Hệ thống khử trùng theo partner_ref (đã xử lý → trả lại kết quả cũ).
3. Hệ thống tra tài khoản đích: tồn tại, ACTIVE hoặc DORMANT (ghi có vào DORMANT được phép),
   đúng loại tiền.
4. Hệ thống, trong một transaction: GL-02 bút toán TRANSFER — Nợ GL 1900 / Có TK đích; ghi nhận
   lệnh đến (xem Điểm mở); outbox `transfer.completed.v1` (phía nhận).
5. Trả "chấp nhận" cho đối tác; notification báo khách biến động số dư.

**Luồng ngoại lệ**
- E3a. Tài khoản không tồn tại / CLOSED / FROZEN / sai loại tiền → trả "từ chối" kèm mã lý do
  — đối tác sẽ hoàn cho người gửi phía họ; ta KHÔNG hạch toán gì.
- E-late. Lệnh đến sau khi tài khoản vừa đóng cùng ngày → từ chối như E3a (không có ngoại lệ).

**Quy tắc nghiệp vụ**
- BR-TRF-03-1: Quyết định nhận/từ chối là đồng bộ và dứt khoát tại bước 3 — không giữ tiền lơ
  lửng "chờ xem".
- BR-TRF-03-2: Không thu phí người nhận (chính sách phạm vi này).
- BR-TRF-03-3: Idempotent tuyệt đối theo partner_ref: N lần gọi = 1 bút toán.

**Dữ liệu** — Bảng: qua GL-02; outbox.

**Điểm mở (quan trọng)** — Bảng `transfers` hiện bắt `source_account_id NOT NULL` (tài khoản nội
bộ) nên KHÔNG chứa được lệnh đến. Phương án khi triển khai GĐ5 (chọn một): (a) bảng riêng
`inward_transfers` (partner_ref UNIQUE, destination_account_id, amount, status) — khuyến nghị,
đối xứng với external_transfers; (b) nới transfers (source nullable + source_bank_code) — đụng
nhiều CHECK. Tài liệu này đặc tả theo (a).

---

### TRF-04 — Kiểm soát hạn mức giao dịch (velocity check)

**Nhóm/Service/GĐ** F / core-banking / GĐ5 · **Actor** Hệ thống (TRF-01/02 gọi vào) · **Trigger** Mỗi lệnh chuyển trước khi hạch toán · **Ưu tiên** Cao

**Mô tả** — Đối chiếu lệnh với khuôn hạn mức sản phẩm (`product_limits`, qua PROD-07) và mức đã
tiêu (`transfer_limit_usage`): PER_TRANSACTION so trực tiếp; PER_DAY/PER_MONTH cộng dồn theo cửa
sổ (`window_start` = ngày đó / ngày 01 của tháng). Vừa kiểm vừa TRỪ hạn mức trong cùng
transaction với hạch toán — không có kẽ giữa kiểm và trừ.

**Luồng chính**
1. Caller đưa: account, kênh, số tiền, ngày.
2. Hệ thống lấy bộ hạn mức hiệu lực của sản phẩm tài khoản (ưu tiên kênh cụ thể, rơi về ANY —
   BR-PROD-04-1).
3. PER_TRANSACTION: amount ≤ max_amount, nếu không → vi phạm.
4. PER_DAY/PER_MONTH: đọc-hoặc-tạo dòng usage của cửa sổ (khóa dòng); kiểm
   used_amount + amount ≤ max_amount và used_count + 1 ≤ max_count.
5. Đạt tất cả → cập nhật used_amount/used_count; trả "đạt". (Nằm trong transaction hạch toán của
   caller — rollback thì usage cũng rollback.)

**Luồng ngoại lệ**
- E3/E4. Vi phạm → trả mã hạn mức vi phạm + phần còn lại; caller từ chối lệnh (transfer FAILED).
- A1. Giao dịch bị REVERSED: usage KHÔNG hoàn lại (chính sách: hạn mức đo "mức độ hoạt động",
  chống lách bằng chuyển-hoàn liên tục).

**Quy tắc nghiệp vụ**
- BR-TRF-04-1: Kiểm và trừ nguyên tử theo dòng usage (UNIQUE (account, limit_code,
  window_start) + khóa dòng).
- BR-TRF-04-2: `limit_code` là hợp đồng chuỗi với product (BR-PROD-04-2); job đối chiếu định kỳ
  cảnh báo mã usage không khớp mã khuôn nào.
- BR-TRF-04-3: Không có dòng khuôn áp dụng → không giới hạn (nhưng PROD-01 đã buộc sản phẩm khai
  đủ trước khi ACTIVE).

**Dữ liệu** — Bảng: `core_banking.transfer_limit_usage`; đọc `product.product_limits` (qua API).

---

### TRF-05 — Xử lý saga treo & quá hạn

**Nhóm/Service/GĐ** F / core-banking / GĐ5 · **Actor** Hệ thống (job) · **Trigger** Job định kỳ (mỗi phút) quét `idx_ext_active` · **Ưu tiên** Cao

**Mô tả** — Lưới an toàn của TRF-02: không khoản tiền nào của khách nằm ở GL trung gian vô thời
hạn. Quét saga HOLD_PLACED/PARTNER_REQUESTED quá `deadline_at` → truy vấn đối tác lần cuối →
chốt kết cục.

**Luồng chính**
1. Job lấy các saga đang mở quá deadline.
2. Với từng saga: gọi API TRA CỨU trạng thái đối tác theo partner_idempotency_key (không gửi
   lệnh mới).
3. Đối tác trả "đã ghi có" → đi nhánh confirm của TRF-02 bước 6 (COMPLETED).
4. Đối tác trả "không có lệnh"/"từ chối" hoặc không liên lạc được → saga TIMED_OUT → đền bù:
   GL-03 đảo bút toán gốc → COMPENSATED + transfer REVERSED; outbox `transfer.reversed.v1`;
   thông báo khách.
5. Ghi audit từng kết cục.

**Luồng ngoại lệ**
- E2. API tra cứu đối tác chết → để saga lại, alert vận hành nếu tuổi saga vượt ngưỡng leo thang
  (mặc định 1 giờ); job lần sau thử tiếp. KHÔNG đền bù mù khi chưa loại trừ được "đối tác đã ghi
  có" (tiền tới đích nhưng nguồn được hoàn = mất tiền ngân hàng; trường hợp bất khả kháng chốt
  theo phiên đối soát).

**Quy tắc nghiệp vụ**
- BR-TRF-05-1: Đền bù chỉ sau khi đã hỏi đối tác lần cuối và nhận câu trả lời phủ định rõ ràng,
  hoặc theo quyết định tra soát.
- BR-TRF-05-2: Job idempotent: saga đã kết cục bị bỏ qua (index chỉ chứa saga mở).

**Dữ liệu** — Bảng: `external_transfers`, `transfers` + GL-03.

---

### TRF-06 — Tra soát & hoàn trả giao dịch

**Nhóm/Service/GĐ** F / core-banking / GĐ7 · **Actor** CSO (tiếp nhận), Kế toán (phê duyệt hoàn) · **Trigger** Khách khiếu nại (chuyển nhầm, không nhận được tiền, trừ hai lần) hoặc yêu cầu tra soát từ ngân hàng đối tác · **Ưu tiên** Trung bình

**Mô tả** — Quy trình nghiệp vụ có con người: tiếp nhận khiếu nại theo `transfer_reference`,
điều tra bằng dữ liệu sổ cái/saga/đối tác, kết luận, và nếu chấp nhận hoàn thì thực hiện bằng bút
toán đảo có phê duyệt. Với chuyển NHẦM nội bộ (đúng lệnh, sai người nhận do khách): hoàn cần sự
ĐỒNG THUẬN của người đã nhận — ngân hàng không tự trừ tiền người nhận.

**Luồng chính**
1. CSO tạo hồ sơ tra soát: transfer_reference, loại khiếu nại, mô tả, chứng từ khách cung cấp.
2. Hệ thống hiển thị chuỗi bằng chứng: transfer → journal_entry → các dòng → saga/đối tác (nếu
   external) → trạng thái hiện tại.
3. CSO điều tra; với external: gửi điện tra soát tới đối tác, chờ trả lời (SLA theo quy định
   song phương).
4. Kết luận **CHẤP NHẬN HOÀN**: CSO lập đề nghị → Kế toán phê duyệt (maker–checker) → hệ thống
   GL-03 đảo bút toán (transfer → REVERSED), outbox `transfer.reversed.v1`, thông báo hai phía.
5. Kết luận **TỪ CHỐI**: ghi lý do, trả lời khách, đóng hồ sơ.

**Luồng thay thế / ngoại lệ**
- E4a. Bút toán đã bị đảo trước đó → DB chặn hoàn lần hai (`uq_journal_one_reversal`) — trả kết
  quả đã hoàn.
- A1. Chuyển nhầm nội bộ: hệ thống hỗ trợ gửi yêu cầu đồng thuận tới người nhận; đồng ý → hoàn
  bằng lệnh chuyển ngược (TRF-01 mới, phí 0) thay vì REVERSAL nếu người nhận đã tiêu một phần
  (hoàn phần còn lại — quyết định của CSO/kế toán).

**Quy tắc nghiệp vụ**
- BR-TRF-06-1: Mọi hoàn tiền qua phê duyệt hai người (người lập ≠ người duyệt), có hồ sơ.
- BR-TRF-06-2: Hồ sơ tra soát có SLA phản hồi khách (mặc định 3 ngày làm việc nội bộ, 7–10 ngày
  liên NH) — theo dõi trạng thái và nhắc hạn.
- BR-TRF-06-3: Toàn bộ hồ sơ + kết luận lưu vĩnh viễn (BR-G6).

**Dữ liệu** — Đọc chuỗi transfers/journal/saga; ghi hồ sơ tra soát (Điểm mở: schema chưa có bảng
`disputes` — đề xuất thêm ở GĐ7: id, transfer_id, type, status
OPEN/INVESTIGATING/RESOLVED_REFUND/RESOLVED_REJECT, opened_by, approved_by, resolution, timestamps).
