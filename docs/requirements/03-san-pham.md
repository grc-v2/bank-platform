# 03 — Nhóm C: Sản phẩm & chính sách giá

Service: `product-service` (schema `product`). Giai đoạn 3.

Triết lý của nhóm này: **nghiệp vụ là dữ liệu, không phải hằng số trong code**. Lãi suất, biểu
phí, hạn mức, điều kiện mở, ánh xạ GL đều là bảng cấu hình có hiệu lực theo thời gian — đổi biểu
phí không được phép là một lần deploy. Mọi bảng giá trị tuân BR-G5: thêm dòng, không sửa dòng;
không hai dòng chồng lấn hiệu lực (DB cưỡng chế bằng EXCLUDE trên khoảng ngày).

Ba sản phẩm khởi điểm (seed): `CA_STANDARD` (thanh toán), `SA_STANDARD` (tiết kiệm không kỳ hạn),
`TD_12M` (tiền gửi kỳ hạn 12 tháng).

---

### PROD-01 — Vòng đời sản phẩm: tạo / kích hoạt / ngừng bán

**Nhóm/Service/GĐ** C / product-service / GĐ3 · **Actor** Product Admin (vai trò ADMIN) · **Trigger** Ra sản phẩm mới / ngừng bán · **Ưu tiên** Cao

**Mô tả** — Quản lý `products`: tạo ở DRAFT (soạn cấu hình thoải mái, chưa ai thấy), kích hoạt
sang ACTIVE (kênh bán được), ngừng bán sang RETIRED (không mở mới; tài khoản hiện hữu **tiếp tục
vận hành bình thường** theo cấu hình sản phẩm).

**Tiền điều kiện (kích hoạt)** — Sản phẩm DRAFT đã đủ cấu hình tối thiểu: ≥ 1 dòng lãi suất hiệu
lực, đủ 4 ánh xạ GL (PRINCIPAL, INTEREST_PAYABLE, INTEREST_EXPENSE, FEE_INCOME), điều kiện mở đã
khai (nếu có chủ đích).

**Luồng chính (tạo + kích hoạt)**
1. Admin tạo sản phẩm: mã (`product_code` duy nhất), tên, loại (CURRENT_ACCOUNT/SAVINGS_ACCOUNT/
   TERM_DEPOSIT), loại tiền, mô tả, hiệu lực từ ngày.
2. Hệ thống ghi `products` (DRAFT).
3. Admin cấu hình lãi suất (PROD-02), phí (PROD-03), hạn mức (PROD-04), điều kiện (PROD-05),
   ánh xạ GL (PROD-06).
4. Admin yêu cầu kích hoạt.
5. Hệ thống kiểm tiền điều kiện kích hoạt; đặt `status = ACTIVE`.
6. Hệ thống ghi outbox `product.activated.v1` (payload đủ để consumer vô hiệu cache catalog).

**Luồng thay thế / ngoại lệ**
- E5. Thiếu cấu hình tối thiểu → từ chối kèm danh sách thiếu.
- A1. Ngừng bán: ACTIVE → RETIRED, phát `product.retired.v1`; kênh ngừng hiển thị; ACCT-01/02 từ
  chối mở mới trên sản phẩm RETIRED; tài khoản hiện hữu không bị ảnh hưởng.
- E1. Sửa `category`/`currency` khi đã ACTIVE → từ chối (hai thuộc tính định danh sản phẩm; sai
  thì retire và tạo sản phẩm mới).

**Trạng thái (`products.status`)**

| Từ | Đến | Điều kiện |
|---|---|---|
| — | DRAFT | Tạo mới |
| DRAFT | ACTIVE | Đủ cấu hình tối thiểu; phát event |
| ACTIVE | RETIRED | Quyết định ngừng bán; phát event; một chiều |

**Quy tắc nghiệp vụ**
- BR-PROD-01-1: TERM_DEPOSIT bắt buộc có lãi suất theo `term_months`; CURRENT/SAVINGS bắt buộc
  không (bất biến ứng dụng giữ — DB không với sang bảng khác được, xem comment schema).
- BR-PROD-01-2: RETIRED là một chiều; "bán lại" = sản phẩm mới.
- BR-PROD-01-3: Mọi thay đổi cấu hình trên sản phẩm ACTIVE ghi audit (ai đổi giá nào lúc nào).

**Dữ liệu** — Bảng: `product.products`, `product.outbox`.

**Điểm mở** — Phê duyệt 2 tay (maker–checker) cho kích hoạt/đổi giá: nên có ở ngân hàng thật;
phạm vi đầu chấp nhận 1 tay + audit. Ghi nhận để GĐ7 cân nhắc.

---

### PROD-02 — Quản lý lãi suất

**Nhóm/Service/GĐ** C / product-service / GĐ3 · **Actor** Product Admin · **Trigger** Ra/điều chỉnh biểu lãi suất · **Ưu tiên** Cao

**Mô tả** — Cấu hình `product_interest_rates`: lãi suất %/năm dạng thập phân (0.045 = 4,5%/năm),
**bậc thang theo số dư** (`tier_from`/`tier_to` — SA) hoặc **theo kỳ hạn** (`term_months` — TD),
hiệu lực theo thời gian. INT-01 dùng bảng này chọn lãi suất từng ngày cho từng tài khoản.

**Luồng chính (đổi lãi suất)**
1. Admin chọn sản phẩm, xem biểu lãi hiện hành.
2. Admin nhập biểu mới: các bậc/kỳ hạn + lãi suất + ngày hiệu lực (`effective_from`, thường là
   ngày mai — không đổi lùi ngày quá khứ).
3. Hệ thống, trong MỘT transaction, theo đúng thứ tự bắt buộc:
   a. ĐÓNG các dòng hiện hành bị thay: `effective_to = effective_from mới`.
   b. CHÈN các dòng mới.
   (Làm ngược thứ tự sẽ bị `ex_rate_overlap` chặn ngay tại câu INSERT — ghi chú schema.)
4. Hệ thống ghi audit; biểu mới tự có hiệu lực từ ngày đã đặt (không cần deploy).

**Luồng ngoại lệ**
- E3a. Hai dòng mới chồng bậc (0–100tr và 50–200tr) hoặc chồng ngày → DB từ chối
  (`ex_rate_overlap`) → trả lỗi rõ dòng nào chồng dòng nào.
- E2a. Nhập 4.5 thay vì 0.045 → chặn (`ck_rate_value` < 1) + thông điệp "nhập dạng thập phân".
- E2b. Đổi lùi ngày quá khứ → từ chối: lãi đã dự thu theo biểu cũ; điều chỉnh quá khứ đi đường
  bút toán ADJUSTMENT có phê duyệt (Điểm mở).

**Quy tắc nghiệp vụ**
- BR-PROD-02-1: Tại mọi (sản phẩm, số dư, kỳ hạn, ngày) có ĐÚNG MỘT lãi suất áp dụng. Bậc là
  khoảng `[tier_from, tier_to)`; `tier_to` NULL = không giới hạn trên.
- BR-PROD-02-2: Đổi biểu = đóng dòng cũ + thêm dòng mới cùng transaction (BR-G5).
- BR-PROD-02-3: Biểu quá khứ bất biến — sao kê/tính lại kỳ cũ luôn ra đúng số cũ.

**Dữ liệu** — Bảng: `product.product_interest_rates`.

---

### PROD-03 — Quản lý biểu phí

**Nhóm/Service/GĐ** C / product-service / GĐ3 · **Actor** Product Admin · **Trigger** Ra/điều chỉnh biểu phí · **Ưu tiên** Cao

**Mô tả** — Cấu hình `product_fees`: mỗi dòng một mã phí (`fee_code`) gắn với một sự kiện thu
(`charge_event`: ACCOUNT_OPEN, ACCOUNT_CLOSE, MONTHLY_MAINTENANCE, INTERNAL_TRANSFER,
EXTERNAL_TRANSFER, ATM_WITHDRAWAL, STATEMENT_REQUEST), kiểu FLAT (số tiền cố định) hoặc PERCENT
(% giá trị giao dịch, kẹp `min_amount`/`max_amount`), hiệu lực theo thời gian. FEE-01/02 đọc bảng
này để tính phí.

**Luồng chính** — như PROD-02 (đóng dòng cũ → chèn dòng mới, cùng transaction), với validation:
1. FLAT phải có `amount`, không có `percent`; PERCENT ngược lại (`ck_fee_shape`).
2. `max_amount ≥ min_amount` (`ck_fee_bounds`); khoảng hiệu lực không rỗng (`ck_fee_period`).
3. Không chồng hiệu lực cùng (product, fee_code) (`ex_fee_overlap`).

**Luồng ngoại lệ**
- E1. Cần phí bậc thang (TIERED) → KHÔNG nhét vào kiểu hiện có; phải thêm bảng
  `product_fee_tiers` trước rồi mở enum (ghi chú schema) — coi là thay đổi thiết kế, không phải
  cấu hình.

**Quy tắc nghiệp vụ**
- BR-PROD-03-1: Phí = 0 là dòng hợp lệ (miễn phí có chủ đích, ví dụ TRF_INTERNAL của CA_STANDARD)
  — khác với "không có dòng phí" (không thu, không ghi vết).
- BR-PROD-03-2: Phí PERCENT tính trên số tiền giao dịch, làm tròn theo quy tắc tiền tệ, rồi kẹp
  min/max.
- BR-PROD-03-3: Một sự kiện có thể gắn nhiều mã phí (phí chuyển + phí điện báo) — cộng dồn khi thu.

**Dữ liệu** — Bảng: `product.product_fees`.

---

### PROD-04 — Quản lý hạn mức giao dịch

**Nhóm/Service/GĐ** C / product-service / GĐ3 · **Actor** Product Admin · **Trigger** Chính sách hạn mức thay đổi · **Ưu tiên** Cao

**Mô tả** — Cấu hình `product_limits`: khuôn hạn mức theo sản phẩm — mã hạn mức, phạm vi
(PER_TRANSACTION/PER_DAY/PER_MONTH), kênh (ANY/INTERNET/MOBILE/ATM/BRANCH), trần số tiền
(`max_amount`) và/hoặc trần số lượt (`max_count`), hiệu lực theo thời gian. Mức ĐÃ TIÊU thực tế
nằm bên core-banking (`transfer_limit_usage`) — TRF-04 đối chiếu hai bảng này khi duyệt giao dịch.

**Luồng chính** — như PROD-02/03 (đóng dòng cũ → chèn dòng mới): validation `max_amount` hoặc
`max_count` phải có ít nhất một (`ck_limit_value`); không chồng hiệu lực cùng (product,
limit_code, channel) (`ex_limit_overlap`).

**Quy tắc nghiệp vụ**
- BR-PROD-04-1: Hạn mức theo kênh cụ thể ĐÈ hạn mức kênh ANY cùng mã (kênh MOBILE có dòng riêng
  thì áp dòng đó; không thì rơi về ANY).
- BR-PROD-04-2: `limit_code` là hợp đồng chuỗi với core-banking (tham chiếu mềm, không FK xuyên
  schema) — đổi tên mã phải có kế hoạch đồng bộ hai phía, nếu không hạn mức âm thầm không được đếm
  (ghi chú schema).
- BR-PROD-04-3: Không có dòng hạn mức áp dụng = không giới hạn — vì vậy sản phẩm cho phép giao
  dịch bắt buộc khai đủ bộ hạn mức trước khi kích hoạt (kiểm ở PROD-01 bước 5).

**Dữ liệu** — Bảng: `product.product_limits`.

---

### PROD-05 — Quản lý điều kiện mở sản phẩm

**Nhóm/Service/GĐ** C / product-service / GĐ3 · **Actor** Product Admin · **Trigger** Chính sách điều kiện thay đổi · **Ưu tiên** Trung bình

**Mô tả** — Cấu hình `product_eligibility_rules`: bộ luật khách nào được mở sản phẩm — MIN_AGE,
MAX_AGE, MIN_KYC_LEVEL, CUSTOMER_TYPE, MAX_RISK_RATING với toán tử EQ/NEQ/GTE/LTE/IN. Cố ý KHÔNG
có hiệu lực thời gian: điều kiện chỉ đánh giá **tại thời điểm mở**, không tra ngược (ghi chú schema).
ACCT-01/02 gọi đánh giá bộ luật này trước khi mở tài khoản.

**Luồng chính**
1. Admin chọn sản phẩm, thêm/sửa/xóa luật (mỗi `rule_type` một dòng — `uq_rule`).
2. Hệ thống validate `rule_value` khớp kiểu của `rule_type` (MIN_AGE là số; CUSTOMER_TYPE thuộc
   {INDIVIDUAL, ORGANIZATION}; MAX_RISK_RATING thuộc {LOW, MEDIUM, HIGH}).
3. Hệ thống ghi thay đổi + audit; hiệu lực NGAY với lượt mở tiếp theo.

**Quy tắc nghiệp vụ**
- BR-PROD-05-1: Đánh giá eligibility là AND của mọi luật; không có luật = không ràng buộc tiêu chí đó.
- BR-PROD-05-2: Sửa luật không ảnh hưởng tài khoản đã mở (không tra ngược).
- BR-PROD-05-3: Chuẩn hóa so sánh: tuổi tính theo ngày sinh tại ngày mở; risk so theo thứ tự
  LOW < MEDIUM < HIGH.

**Dữ liệu** — Bảng: `product.product_eligibility_rules`.

---

### PROD-06 — Quản lý ánh xạ GL

**Nhóm/Service/GĐ** C / product-service / GĐ3 · **Actor** Product Admin (phối hợp Kế toán trưởng) · **Trigger** Sản phẩm mới / tái cấu trúc hệ thống tài khoản kế toán · **Ưu tiên** Cao

**Mô tả** — Cấu hình `product_gl_mappings`: cầu nối quan trọng nhất giữa sản phẩm và sổ cái —
sản phẩm này hạch toán GỐC vào GL nào (PRINCIPAL), lãi phải trả vào đâu (INTEREST_PAYABLE), chi
phí lãi vào đâu (INTEREST_EXPENSE), phí thu về đâu (FEE_INCOME). Có hiệu lực thời gian để trả lời
được "giao dịch tháng trước hạch toán vào tài khoản nào" sau khi đổi mapping.

**Luồng chính**
1. Admin chọn sản phẩm, khai 4 purpose → gl_code (gl_code phải tồn tại và postable bên
   core-banking — kiểm qua API, vì tham chiếu là mềm).
2. Đổi mapping: đóng dòng cũ + chèn dòng mới (BR-G5; `ex_glmap_overlap` cưỡng chế không chồng).
3. Ghi audit.

**Luồng ngoại lệ**
- E1. gl_code không tồn tại / không postable / sai loại (PRINCIPAL của sản phẩm tiền gửi phải là
  GL LIABILITY) → từ chối.

**Quy tắc nghiệp vụ**
- BR-PROD-06-1: Sản phẩm ACTIVE luôn có đủ 4 purpose hiệu lực tại mọi ngày (không khoảng trống).
- BR-PROD-06-2: Posting engine (GL-02) tra mapping theo **ngày hiệu lực của bút toán**
  (value_date), không phải ngày hiện tại.

**Dữ liệu** — Bảng: `product.product_gl_mappings`. Tham chiếu mềm: `core_banking.gl_accounts.gl_code`.

---

### PROD-07 — Cung cấp catalog cho kênh & service khác

**Nhóm/Service/GĐ** C / product-service / GĐ3 · **Actor** Hệ thống (core-banking, kênh, dashboard) · **Trigger** Truy vấn catalog / cần cấu hình để xử lý giao dịch · **Ưu tiên** Cao

**Mô tả** — API đọc phục vụ hai đối tượng: (1) **kênh bán** — danh sách sản phẩm ACTIVE kèm lãi
suất/phí/điều kiện hiển thị cho khách; (2) **core-banking** — cấu hình chi tiết một sản phẩm
(eligibility, phí theo sự kiện, hạn mức theo kênh, GL mapping, lãi suất) tại một ngày hiệu lực
cho việc xử lý nghiệp vụ.

**Luồng chính**
1. Consumer gọi API: `danh sách sản phẩm ACTIVE` hoặc `cấu hình sản phẩm X tại ngày D`.
2. Hệ thống trả cấu hình hiệu lực tại ngày D (mặc định hôm nay): mỗi bảng giá trị lấy dòng có
   `effective_from ≤ D < effective_to`.
3. Consumer cache kết quả; vô hiệu cache khi nhận `product.activated.v1` / `product.retired.v1`.

**Quy tắc nghiệp vụ**
- BR-PROD-07-1: API đọc theo ngày hiệu lực là hợp đồng chính — mọi tính toán tiền (phí, lãi, hạn
  mức) phía core-banking phải hỏi "tại ngày D" chứ không "hiện giờ".
- BR-PROD-07-2: Catalog công khai chỉ lộ sản phẩm ACTIVE; DRAFT/RETIRED chỉ Admin thấy.
- BR-PROD-07-3: core-banking phải chịu được product-service chết ngắn hạn: cache TTL + serve-stale
  cho cấu hình đọc thường xuyên (mức độ: quyết định khi triển khai GĐ5).

**Dữ liệu** — Đọc mọi bảng schema product.
