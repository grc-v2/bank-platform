# 05 — Nhóm E: Tài khoản tiền gửi

Service: `core-banking-service` (schema `core_banking`). Giai đoạn 4.

Máy trạng thái tài khoản (`accounts.status`) — dùng chung cho cả nhóm:

| Từ | Đến | Chức năng gây ra |
|---|---|---|
| — | PENDING | ACCT-01/02 tạo tài khoản, chưa kích hoạt |
| PENDING | ACTIVE | ACCT-01/02: nộp tiền mở đầu thành công / duyệt kích hoạt |
| ACTIVE | DORMANT | ACCT-05: không giao dịch chủ động trong N tháng (job) |
| DORMANT | ACTIVE | ACCT-05: khách giao dịch trở lại / xác nhận tại quầy |
| ACTIVE, DORMANT | FROZEN | ACCT-05: phong tỏa (lệnh cơ quan, khách bị đình chỉ, nghi gian lận) |
| FROZEN | ACTIVE | ACCT-05: gỡ phong tỏa |
| ACTIVE, DORMANT | CLOSED | ACCT-07: tất toán; một chiều, `closed_at` bắt buộc |

Ba con số của một tài khoản: `ledger_balance` (số dư sổ cái) − `hold_amount` (tiền treo) =
`available_balance` (số dư khả dụng — con số khách nhìn thấy và dùng để duyệt giao dịch).

---

### ACCT-01 — Mở tài khoản thanh toán / tiết kiệm

**Nhóm/Service/GĐ** E / core-banking (+ product, customer) / GĐ4 · **Actor** Teller (quầy), Khách hàng (online) · **Trigger** Yêu cầu mở tài khoản CA/SA · **Ưu tiên** Cao

**Mô tả** — Mở tài khoản trên một sản phẩm CURRENT_ACCOUNT/SAVINGS_ACCOUNT đang ACTIVE, sau khi
khách vượt kiểm tra điều kiện (eligibility). Tài khoản chốt `gl_code` tại thời điểm mở (từ GL
mapping PRINCIPAL hiệu lực) và ghi chủ sở hữu chính.

**Tiền điều kiện** — CIF ACTIVE; sản phẩm ACTIVE; khách đạt eligibility của sản phẩm.

**Luồng chính**
1. Actor chọn sản phẩm; hệ thống hiển thị điều kiện + biểu phí/lãi hiện hành (PROD-07).
2. Hệ thống lấy hồ sơ khách (customer-service): loại khách, ngày sinh, kyc_level, risk_rating.
3. Hệ thống đánh giá eligibility (PROD-05): AND mọi luật; ví dụ CA_STANDARD: tuổi ≥ 18 và
   kyc_level ≥ 1.
4. Hệ thống sinh `account_number` (BR-G9); tra GL mapping PRINCIPAL của sản phẩm tại ngày mở.
5. Hệ thống, trong một transaction: ghi `accounts` (PENDING, currency theo sản phẩm,
   primary_customer_id) + `account_holders` (PRIMARY) — bất biến hai bảng khớp nhau do ứng dụng giữ.
6. Khách nộp tiền mở đầu (quầy: tiền mặt; online: chuyển từ tài khoản khác):
   - Tiền mặt: bút toán OPENING — Nợ GL 1010 / Có TK khách (GL-02).
   - Chuyển khoản: đi luồng TRF-01 tới tài khoản mới.
7. Hệ thống thu phí mở nếu biểu phí có `ACCOUNT_OPEN` (FEE-01).
8. Hệ thống đặt `status = ACTIVE`, `opened_at = now()`; phát `account.opened.v1`.
9. Thông báo khách số tài khoản.

**Luồng thay thế / ngoại lệ**
- E3. Trượt eligibility → từ chối, trả rõ tiêu chí trượt (ví dụ "cần KYC mức 2 — hiện mức 1"),
  gợi ý bước khắc phục (CUST-06).
- A6. Sản phẩm không yêu cầu số dư mở đầu (tham số sản phẩm) → ACTIVE ngay sau bước 5, bỏ bước 6.
- E6. Nộp tiền mở đầu thất bại → tài khoản ở PENDING; job dọn: PENDING quá N ngày (mặc định 30)
  tự hủy (đóng không phát sinh).

**Hậu điều kiện** — Tài khoản ACTIVE số dư = tiền mở đầu − phí; hoặc PENDING chờ nộp; hoặc không
tạo gì (trượt điều kiện).

**Quy tắc nghiệp vụ**
- BR-ACCT-01-1: Một khách mở nhiều tài khoản cùng sản phẩm được (trừ khi sản phẩm giới hạn —
  tham số, mặc định không giới hạn).
- BR-ACCT-01-2: `accounts.gl_code` chốt tại lúc mở; đổi GL mapping sau đó KHÔNG đổi tài khoản
  hiện hữu (chỉ áp cho tài khoản mở mới) — trừ chiến dịch chuyển đổi có kế hoạch riêng.
- BR-ACCT-01-3: `primary_customer_id` (bảng accounts) và dòng PRIMARY (bảng account_holders)
  luôn khớp — bất biến ứng dụng giữ, kiểm ở test.
- BR-ACCT-01-4: Loại tiền tài khoản = loại tiền sản phẩm; đóng băng từ lúc mở (BR-G4).

**Dữ liệu** — Vào: customer_id, product_code, (số tiền mở đầu). Ra: account_number. Bảng:
`core_banking.accounts`, `account_holders`; qua GL-02: `journal_entries`, `journal_lines`.

**Điểm mở** — Quy tắc sinh số tài khoản (đề xuất: 12 số, tiền tố theo loại sản phẩm). Số dư mở
đầu tối thiểu: chưa có chỗ trong schema product — nếu cần, thêm `product_limits` mã
`MIN_OPENING_BALANCE` hoặc cột riêng; quyết định ở GĐ4.

---

### ACCT-02 — Mở tiền gửi có kỳ hạn (TD)

**Nhóm/Service/GĐ** E / core-banking / GĐ4 · **Actor** Khách hàng (online), Teller · **Trigger** Khách muốn gửi có kỳ hạn · **Ưu tiên** Cao

**Mô tả** — Mở tài khoản trên sản phẩm TERM_DEPOSIT: nhận NGAY khoản gốc (chuyển từ tài khoản
thanh toán của chính khách), kỳ hạn theo sản phẩm (`term_months` của biểu lãi suất), lãi suất
chốt tại ngày mở và giữ nguyên suốt kỳ hạn. Ngày đáo hạn = ngày mở + kỳ hạn.

**Tiền điều kiện** — CIF ACTIVE đạt eligibility (TD_12M yêu cầu kyc_level ≥ 2); khách có tài
khoản CA/SA ACTIVE đủ số dư khả dụng cho khoản gốc.

**Luồng chính**
1. Khách chọn sản phẩm TD, số tiền gốc, tài khoản nguồn; hệ thống hiển thị lãi suất chốt cho kỳ
   hạn + ngày đáo hạn dự kiến.
2. Hệ thống kiểm eligibility (như ACCT-01 bước 2–3) và số dư khả dụng nguồn ≥ gốc.
3. Hệ thống, trong một transaction:
   a. Tạo tài khoản TD (PENDING → ACTIVE ngay trong luồng), gl_code từ mapping PRINCIPAL (2020).
   b. Bút toán TRANSFER: Nợ TK nguồn / Có TK TD, số tiền = gốc (GL-02).
   c. Ghi nhận lãi suất chốt cho tài khoản này tại ngày mở (đọc từ PROD-02 theo term + tier).
4. Phát `account.opened.v1`; thông báo khách (gốc, lãi suất, ngày đáo hạn).

**Luồng thay thế / ngoại lệ**
- E2. Không đủ số dư khả dụng → từ chối.
- A-đáo-hạn: xem INT-03 (tất toán đúng hạn, tái tục, rút trước hạn).

**Quy tắc nghiệp vụ**
- BR-ACCT-02-1: Gốc TD nộp một lần lúc mở; không nộp thêm trong kỳ (sản phẩm tích lũy nằm ngoài
  phạm vi).
- BR-ACCT-02-2: Rút trước hạn = tất toán toàn phần, hưởng lãi không kỳ hạn (mô tả sản phẩm
  TD_12M); không rút một phần.
- BR-ACCT-02-3: Lãi suất chốt tại ngày mở từ biểu hiệu lực; biểu đổi sau đó không ảnh hưởng sổ
  TD đang chạy.

**Dữ liệu** — như ACCT-01 + tham chiếu tài khoản nguồn.

**Điểm mở (quan trọng)** — Schema `accounts` CHƯA có cột kỳ hạn/ngày đáo hạn/lãi suất chốt/chỉ
thị tái tục. Phương án khi triển khai GĐ4 (chọn một): (a) thêm bảng
`core_banking.term_deposit_details (account_id PK, term_months, maturity_date, locked_rate,
rollover_instruction)` — khuyến nghị; (b) suy từ `opened_at + term_months` của sản phẩm và tra
biểu lãi lịch sử — mong manh, không giữ được chỉ thị tái tục. Tài liệu này đặc tả theo (a).

---

### ACCT-03 — Đồng chủ tài khoản & người được ủy quyền

**Nhóm/Service/GĐ** E / core-banking / GĐ4 · **Actor** Teller · **Trigger** Yêu cầu thêm đồng sở hữu / ủy quyền · **Ưu tiên** Thấp

**Mô tả** — Quản lý `account_holders`: ngoài chủ chính (PRIMARY — duy nhất, DB cưỡng chế), tài
khoản có thể thêm đồng chủ (JOINT) hoặc người được ủy quyền ký (AUTHORIZED_SIGNATORY).

**Luồng chính**
1. Teller xác minh giấy tờ của chủ chính + người được thêm (cả hai phải có CIF ACTIVE).
2. Teller chọn vai trò JOINT/AUTHORIZED_SIGNATORY; hệ thống ghi dòng `account_holders`.
3. Ghi audit; thông báo chủ chính.

**Luồng thay thế / ngoại lệ**
- A1. Gỡ người đồng chủ/ủy quyền: xóa dòng (giữ audit); không gỡ được PRIMARY.
- E2. Thêm PRIMARY thứ hai → DB chặn (`uq_account_one_primary`).

**Quy tắc nghiệp vụ**
- BR-ACCT-03-1: Đổi chủ chính không thuộc phạm vi (nghiệp vụ thừa kế/chuyển nhượng — quy trình
  pháp lý riêng).
- BR-ACCT-03-2: Quyền thao tác: PRIMARY và JOINT được giao dịch + xem; AUTHORIZED_SIGNATORY được
  giao dịch theo ủy quyền, không được đóng tài khoản hay thêm/gỡ holder.
- BR-ACCT-03-3: Kênh online: user của mọi holder thấy tài khoản; kiểm ownership mở rộng theo
  `account_holders`, không chỉ `primary_customer_id`.

**Dữ liệu** — Bảng: `core_banking.account_holders`.

---

### ACCT-04 — Truy vấn số dư & thông tin tài khoản

**Nhóm/Service/GĐ** E / core-banking / GĐ4 · **Actor** Khách hàng; Teller/CSO · **Trigger** Xem tài khoản · **Ưu tiên** Cao

**Mô tả** — Trả về thông tin tài khoản: số tài khoản, sản phẩm, trạng thái, loại tiền,
`ledger_balance`, `hold_amount`, `available_balance`, hạn mức thấu chi, ngày mở. Số dư đọc từ cột
lưu sẵn (quyết định DB4) — không bao giờ SUM sổ cái lúc đọc.

**Luồng chính**
1. Actor yêu cầu danh sách tài khoản (theo customer) hoặc chi tiết một tài khoản.
2. Hệ thống kiểm ownership (khách chỉ thấy tài khoản mình đứng tên/đồng chủ — BR-ACCT-03-3).
3. Hệ thống trả dữ liệu; kèm chi tiết hold ACTIVE (ai treo, bao nhiêu, lý do) khi xem chi tiết.

**Quy tắc nghiệp vụ**
- BR-ACCT-04-1: Con số hiển thị mặc định cho khách là `available_balance`, kèm ledger + hold khi
  xem chi tiết.
- BR-ACCT-04-2: Nhân viên tra cứu tài khoản người khác → ghi audit (như BR-CUST-12-2).

**Dữ liệu** — Đọc `core_banking.accounts`, `account_holds`.

---

### ACCT-05 — Phong tỏa & quản lý trạng thái tài khoản

**Nhóm/Service/GĐ** E / core-banking / GĐ4 · **Actor** CSO (thủ công); Hệ thống (event, job DORMANT) · **Trigger** Lệnh cơ quan / nghi gian lận / event `customer.status.changed.v1` / job quét bất hoạt · **Ưu tiên** Cao

**Mô tả** — Điều khiển máy trạng thái tài khoản (bảng đầu chương). FROZEN chặn MỌI giao dịch ghi
(nợ lẫn có, trừ bút toán do lệnh cơ quan yêu cầu); DORMANT chặn giao dịch chủ động của khách cho
tới khi kích hoạt lại nhưng không chặn lãi/phí hệ thống.

**Luồng chính (phong tỏa thủ công)**
1. CSO chọn tài khoản, nhập căn cứ (số văn bản lệnh cơ quan / mã cảnh báo gian lận).
2. Hệ thống đặt `status = FROZEN`; ghi audit kèm căn cứ.
3. Phát `account.status.changed.v1`; thông báo khách (trừ khi lệnh cơ quan yêu cầu không báo).

**Luồng thay thế**
- A1. Phong tỏa hàng loạt theo event: consumer nhận `customer.status.changed.v1`
  (SUSPENDED) → FROZEN mọi tài khoản ACTIVE/DORMANT của customer đó; idempotent theo event_id
  (`processed_events`).
- A2. Gỡ phong tỏa: FROZEN → ACTIVE; chỉ người/nguồn tương xứng với căn cứ phong tỏa (lệnh cơ
  quan gỡ bằng văn bản gỡ; phong tỏa theo customer gỡ khi customer ACTIVE lại).
- A3. Job DORMANT: quét tài khoản ACTIVE không có giao dịch CHỦ ĐỘNG (không tính lãi/phí hệ
  thống) trong N tháng (tham số, mặc định 12) → DORMANT + thông báo khách.
- A4. Đánh thức: khách giao dịch tại quầy/xác minh online → DORMANT → ACTIVE.

**Quy tắc nghiệp vụ**
- BR-ACCT-05-1: Phong tỏa TOÀN tài khoản (status) khác phong tỏa MỘT PHẦN số dư (hold LEGAL,
  ACCT-06) — lệnh cơ quan chỉ định số tiền thì dùng hold, chỉ định toàn tài khoản thì dùng FROZEN.
- BR-ACCT-05-2: FROZEN không chặn bút toán REVERSAL/ADJUSTMENT của kế toán và không chặn đối chiếu.
- BR-ACCT-05-3: Mọi chuyển trạng thái ghi audit + phát event.

**Dữ liệu** — Bảng: `core_banking.accounts`, `processed_events`, `outbox`.

---

### ACCT-06 — Quản lý khoản treo (hold)

**Nhóm/Service/GĐ** E / core-banking / GĐ4–5 · **Actor** Hệ thống (saga TRF-02); CSO (hold LEGAL/FEE thủ công) · **Trigger** Cần giữ tiền trước khi hạch toán · **Ưu tiên** Cao

**Mô tả** — Hold = tiền bị giữ nhưng CHƯA hạch toán: giảm `available_balance` ngay, không đổi
`ledger_balance`. Vòng đời: đặt (ACTIVE) → capture (chuyển thành bút toán thật) / release (nhả
không hạch toán) / expire (quá hạn, job tự nhả). Lý do: TRANSFER (saga liên NH), CARD_AUTH (chừa
cho tương lai), LEGAL (phong tỏa một phần theo lệnh cơ quan — duy nhất được vô hạn), FEE.

**Luồng chính (đặt hold)**
1. Caller yêu cầu hold: account, amount > 0, reason, tham chiếu nguồn, `expires_at` (bắt buộc
   trừ LEGAL — `ck_hold_expiry`).
2. Hệ thống kiểm `available_balance ≥ amount` (trong cùng lock với accounts).
3. Hệ thống ghi `account_holds` (ACTIVE) + tăng `accounts.hold_amount` cùng transaction.

**Luồng thay thế**
- A1. **Capture**: caller hạch toán bút toán thật (GL-02) + đặt hold `CAPTURED`,
  `released_at = now()`, giảm `hold_amount` — cùng transaction với bút toán.
- A2. **Release**: hold → `RELEASED`, giảm `hold_amount`; không có bút toán.
- A3. **Expire** (job EOD/định kỳ quét `idx_holds_expiry`): hold ACTIVE quá `expires_at` →
  `EXPIRED`, giảm `hold_amount`; cảnh báo nguồn đặt hold (saga phải tự xử lý trước hạn — đây là
  lưới an toàn "tiền của khách không bị treo vĩnh viễn").
- E2. Không đủ available → từ chối đặt hold.

**Trạng thái (`account_holds.status`)**: ACTIVE → CAPTURED | RELEASED | EXPIRED (cả ba là cuối).

**Quy tắc nghiệp vụ**
- BR-ACCT-06-1: `hold_amount` của accounts luôn = SUM(amount các hold ACTIVE) — bất biến ứng
  dụng, kiểm ở đối chiếu GL-05 mở rộng.
- BR-ACCT-06-2: Hold LEGAL chỉ CSO đặt/nhả theo văn bản; không job nào tự nhả.
- BR-ACCT-06-3: Capture chỉ bởi đúng nguồn đã đặt (khớp reference_type/reference_id).

**Dữ liệu** — Bảng: `core_banking.account_holds`, `accounts`.

---

### ACCT-07 — Đóng tài khoản / tất toán

**Nhóm/Service/GĐ** E / core-banking / GĐ4 · **Actor** Teller, Khách hàng (online với điều kiện); Hệ thống (INT-03 tất toán TD) · **Trigger** Khách yêu cầu đóng · **Ưu tiên** Trung bình

**Mô tả** — Kết thúc vòng đời tài khoản: trả nốt lãi dồn tích, thu phí đóng (nếu có), chuyển hết
số dư về đích khách chỉ định (tài khoản khác/tiền mặt tại quầy), đưa về CLOSED. CLOSED là một
chiều; dữ liệu tài khoản và sổ cái giữ nguyên vĩnh viễn (BR-G6).

**Tiền điều kiện** — Tài khoản ACTIVE/DORMANT; không có hold ACTIVE; không có giao dịch treo
(transfer PENDING/PENDING_EXTERNAL liên quan).

**Luồng chính**
1. Actor yêu cầu đóng, chỉ định đích nhận số dư còn lại.
2. Hệ thống kiểm tiền điều kiện.
3. Hệ thống tính lãi dồn tích chưa trả tới ngày đóng → hạch toán trả lãi (INT-02 gọi cho một
   tài khoản).
4. Hệ thống thu phí `ACCOUNT_CLOSE` nếu biểu phí có (FEE-01).
5. Hệ thống chuyển số dư còn lại: bút toán TRANSFER về tài khoản đích (hoặc Nợ TK / Có GL 1010
   nếu chi tiền mặt tại quầy).
6. Hệ thống đặt `status = CLOSED`, `closed_at = now()` (DB đòi — `ck_accounts_closed`); phát
   `account.status.changed.v1`; thông báo khách.

**Luồng ngoại lệ**
- E2a. Còn hold ACTIVE → từ chối, liệt kê hold; hold LEGAL thì không thể đóng cho tới khi gỡ.
- E2b. Còn transfer treo → từ chối, chờ saga kết thúc.
- E5. Số dư = 0 → bỏ bước 5.
- E-âm. Số dư < 0 (thấu chi) → khách phải nộp đủ trước khi đóng.

**Hậu điều kiện** — Tài khoản CLOSED, số dư 0, không nhận giao dịch mới; lịch sử tra cứu được mãi.

**Quy tắc nghiệp vụ**
- BR-ACCT-07-1: Trình tự bắt buộc: lãi → phí → chuyển số dư → CLOSED, tất cả trong ngày nghiệp vụ
  đóng (các bút toán có thể là nhiều transaction nhưng trạng thái CLOSED chỉ đặt khi số dư đã 0).
- BR-ACCT-07-2: Đóng TD trước hạn đi qua INT-03 (tính lại lãi không kỳ hạn) rồi mới vào luồng này.

**Dữ liệu** — Bảng: `core_banking.accounts` + qua GL-02.

---

### ACCT-08 — Sao kê & lịch sử giao dịch

**Nhóm/Service/GĐ** E / core-banking / GĐ4 · **Actor** Khách hàng; Teller/CSO · **Trigger** Xem lịch sử / yêu cầu sao kê kỳ · **Ưu tiên** Cao

**Mô tả** — Hai mức: (1) **lịch sử giao dịch** trực tuyến: các dòng bút toán chạm tài khoản
(`journal_lines` theo account_id, mới nhất trước, phân trang) kèm mô tả, đối tác, `balance_after`;
(2) **sao kê kỳ** (tháng/khoảng ngày): số dư đầu kỳ (từ snapshot), liệt kê phát sinh, số dư cuối
kỳ — xuất file (PDF/CSV) đóng dấu thông tin ngân hàng + địa chỉ khách TẠI KỲ ĐÓ.

**Luồng chính (sao kê kỳ)**
1. Actor chọn tài khoản + kỳ.
2. Hệ thống lấy opening từ `account_balance_snapshots` (ngày đầu kỳ), phát sinh từ
   `journal_lines` trong kỳ (theo booking_date), closing từ snapshot cuối kỳ.
3. Hệ thống lấy địa chỉ khách hiệu lực tại cuối kỳ (customer_addresses theo valid_from/to).
4. Hệ thống dựng sao kê, thu phí `STATEMENT_REQUEST` nếu biểu phí quy định (FEE-01, thường miễn
   bản điện tử).
5. Trả file cho actor.

**Quy tắc nghiệp vụ**
- BR-ACCT-08-1: Sao kê kỳ đã phát hành phải tái lập ra ĐÚNG số cũ mãi mãi (sổ cái append-only +
  biểu giá trị bất biến + địa chỉ theo lịch sử — cả ba đảm bảo điều này).
- BR-ACCT-08-2: Tổng phát sinh trên sao kê phải khớp snapshot (total_debit/total_credit) — lệch
  là bug đối chiếu, chặn phát hành.
- BR-ACCT-08-3: Khách chỉ xuất sao kê tài khoản mình đứng tên (BR-ACCT-03-3).

**Dữ liệu** — Đọc: `journal_lines`, `account_balance_snapshots`, `transfers` (mô tả đối tác),
customer-service (địa chỉ).
