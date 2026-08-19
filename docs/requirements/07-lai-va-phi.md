# 07 — Nhóm G: Lãi & phí

Service: `core-banking-service` (chính sách đọc từ `product-service`). Giai đoạn 6.

Nguyên tắc kế toán lãi tiền gửi: **dự thu (accrue) hằng ngày, hạch toán (post) định kỳ**.
`interest_accruals` là sổ nháp từng ngày (chưa vào sổ cái); khi trả lãi mới ghi bút toán qua
GL 2110 (lãi phải trả) và 5010 (chi phí lãi). Phí ghi nhận ở `fee_charges`
(PENDING → POSTED/WAIVED) và vào sổ qua GL 4010 (thu phí).

---

### INT-01 — Dự thu lãi hằng ngày

**Nhóm/Service/GĐ** G / core-banking / GĐ6 (trong EOD) · **Actor** Hệ thống · **Trigger** OPS-03 gọi mỗi cuối ngày D · **Ưu tiên** Cao

**Mô tả** — Với từng tài khoản hưởng lãi (ACTIVE/DORMANT/FROZEN — phong tỏa vẫn tính lãi), tính
lãi một ngày và ghi `interest_accruals` (posted = FALSE). Chống chạy trùng bằng
UNIQUE(account_id, accrual_date) — "chạy EOD hai lần" tự vô hại.

**Luồng chính**
1. OPS-03 kích hoạt cho ngày D sau khóa sổ.
2. Hệ thống duyệt tài khoản hưởng lãi; với từng tài khoản:
   a. Cơ sở tính: `principal_base` = số dư cuối ngày D (từ snapshot GL-04).
   b. Chọn lãi suất: biểu của sản phẩm hiệu lực TẠI ngày D (PROD-07 "tại ngày D"); SA chọn bậc
      theo số dư; TD dùng lãi suất CHỐT của sổ (BR-ACCT-02-3); CA lãi phẳng.
   c. Tính: `accrued_amount = principal_base × annual_rate / 365` (quy ước Actual/365, làm tròn
      4 số lẻ).
   d. Ghi dòng accrual (posted = FALSE).
3. Ghi tổng kết chạy job (số tài khoản, tổng dự thu) cho giám sát.

**Luồng thay thế / ngoại lệ**
- E2d. Dòng (account, D) đã tồn tại (chạy lại) → bỏ qua tài khoản đó, không lỗi.
- A1. Số dư 0 hoặc âm (thấu chi) → accrual 0, không ghi dòng (lãi thấu chi: ngoài phạm vi, ghi
  chương 10).
- E-biểu. Không tìm được lãi suất hiệu lực (lỗ hổng cấu hình) → ghi lỗi từng tài khoản, tiếp tục
  các tài khoản khác, cảnh báo Product Admin; ngày sau chạy bù khi biểu đã vá (xem BR-INT-01-3).

**Quy tắc nghiệp vụ**
- BR-INT-01-1: Mỗi (tài khoản, ngày) đúng một dòng dự thu (`uq_accrual`).
- BR-INT-01-2: Dự thu KHÔNG chạm sổ cái, không chạm số dư — chỉ là sổ ghi nhận.
- BR-INT-01-3: Bỏ sót ngày phải chạy bù đủ từng ngày (không gộp "3 ngày một dòng") — mỗi ngày một
  dòng đúng số dư ngày đó.
- BR-INT-01-4: Cơ sở ngày đếm Actual/365 là tham số hệ thống (chuẩn bị đường đổi sang Actual/360).

**Dữ liệu** — Bảng: `core_banking.interest_accruals`; đọc snapshots, biểu lãi (API product).

---

### INT-02 — Trả lãi định kỳ

**Nhóm/Service/GĐ** G / core-banking / GĐ6 · **Actor** Hệ thống (EOD ngày chốt lãi); được gọi lẻ khi đóng tài khoản (ACCT-07) · **Trigger** Kỳ trả lãi của sản phẩm (CA/SA: cuối tháng) / tất toán · **Ưu tiên** Cao

**Mô tả** — Gom mọi dòng dự thu chưa hạch toán của tài khoản trong kỳ, ghi nhận vào sổ cái và
cộng lãi vào tài khoản khách (capitalize) bằng hai bút toán chuẩn qua lãi phải trả:
1. **Ghi nhận chi phí**: Nợ GL 5010 (INTEREST_EXPENSE) / Có GL 2110 (INTEREST_PAYABLE) = tổng dự
   thu kỳ.
2. **Chi trả**: Nợ GL 2110 / Có TK khách = số lãi thực trả (làm tròn theo quy tắc tiền tệ).

**Luồng chính**
1. OPS-03 kích hoạt vào ngày chốt lãi (cuối tháng) — hoặc ACCT-07/INT-03 gọi cho một tài khoản.
2. Hệ thống gom các `interest_accruals` posted = FALSE của tài khoản tới hết ngày chốt; tổng =
   Σ accrued_amount, làm tròn thành số thực trả (VND: 0 lẻ — xem Điểm mở).
3. Hệ thống, trong một transaction: hai bút toán INTEREST (GL-02, source trỏ về lô accrual);
   đánh dấu các dòng accrual posted = TRUE + `journal_entry_id` (DB đòi — `ck_accrual_posted`).
4. Outbox `interest.posted.v1`; notification báo khách "+lãi tháng".

**Luồng thay thế / ngoại lệ**
- E2. Tổng lãi kỳ = 0 → không bút toán, không đánh dấu gì.
- E3. Chạy lại kỳ đã trả → các dòng đã posted không được gom lại (điều kiện posted = FALSE) —
  idempotent tự nhiên.
- A1. Tài khoản FROZEN vẫn được trả lãi (cộng vào số dư — khoản có không bị chặn bởi nghiệp vụ
  phong tỏa chi).

**Quy tắc nghiệp vụ**
- BR-INT-02-1: Không trả lãi mà không có đủ dòng dự thu làm căn cứ; chênh lệch làm tròn giữa
  Σ accrual và số thực trả ghi nhận về GL chênh lệch (Điểm mở) hoặc dồn kỳ sau — chọn một, nhất
  quán.
- BR-INT-02-2: value_date của bút toán trả lãi = ngày chốt kỳ (dù giờ chạy máy là ngày hôm sau).
- BR-INT-02-3: Kỳ trả lãi là tham số theo sản phẩm (mặc định: CA/SA cuối tháng; TD tại đáo hạn).

**Dữ liệu** — Bảng: `interest_accruals` + GL-02; outbox.

**Điểm mở** — Làm tròn VND (0 số lẻ khi trả nhưng accrual giữ 4 số lẻ): chốt quy tắc làm tròn
(half-up từng tài khoản) + nơi hạch toán phần lẻ khi triển khai.

---

### INT-03 — Đáo hạn tiền gửi có kỳ hạn

**Nhóm/Service/GĐ** G / core-banking / GĐ6 · **Actor** Hệ thống (EOD ngày đáo hạn); Khách hàng (rút trước hạn) · **Trigger** `maturity_date` tới / khách yêu cầu tất toán sớm · **Ưu tiên** Cao

**Mô tả** — Kết thúc/quay vòng sổ TD theo chỉ thị tái tục khách đã đặt:
- **Tất toán về TK thanh toán**: trả gốc + lãi kỳ hạn về tài khoản CA chỉ định, đóng sổ.
- **Tái tục gốc** (mặc định): trả lãi về CA, gốc quay vòng kỳ mới với lãi suất hiệu lực TẠI ngày
  tái tục.
- **Tái tục gốc + lãi**: nhập lãi vào gốc, quay vòng kỳ mới.
- **Rút trước hạn**: toàn bộ kỳ hưởng lãi KHÔNG KỲ HẠN (theo mô tả sản phẩm TD_12M) — tính lại
  từ đầu kỳ bằng lãi suất không kỳ hạn, phần dự thu theo lãi kỳ hạn chưa post thì hủy tương ứng.

**Luồng chính (đáo hạn tự động, chỉ thị mặc định)**
1. Job EOD quét sổ TD có `maturity_date` = ngày D.
2. Hệ thống trả lãi kỳ hạn: INT-02 cho tài khoản TD (dồn tích cả kỳ), tiền lãi Có vào TK nhận
   lãi đã chỉ định.
3. Theo chỉ thị: tái tục gốc → mở kỳ mới trên chính sổ (cập nhật term_details: kỳ mới, lãi suất
   chốt mới); ghi nhận sự kiện tái tục.
4. Thông báo khách (lãi đã trả, kỳ mới + lãi suất mới nếu tái tục).

**Luồng thay thế / ngoại lệ**
- A1. Chỉ thị "tất toán": sau bước 2, chuyển gốc về TK chỉ định (bút toán TRANSFER) và đóng sổ
  (ACCT-07 rút gọn — không phí ACCOUNT_CLOSE cho đáo hạn đúng hạn, tham số).
- A2. Rút trước hạn (khách chủ động, bất kỳ ngày nào trước đáo hạn):
  a. Hệ thống tính lãi lại: số ngày thực gửi × lãi suất không kỳ hạn hiện hành của sản phẩm SA
     tham chiếu (tham số sản phẩm).
  b. Hủy giá trị dự thu chưa post của sổ (đánh dấu lô accrual bị thay thế — ghi chú kỹ thuật khi
     triển khai; phần đã post nếu có thì điều chỉnh bằng ADJUSTMENT).
  c. Trả gốc + lãi tính lại về TK chỉ định; đóng sổ; thông báo.
- E2. TK nhận lãi/gốc đã đóng → giữ tiền tại sổ TD, chuyển trạng thái chờ chỉ thị, thông báo
  khách ra quầy cập nhật (không tự chọn tài khoản khác).

**Quy tắc nghiệp vụ**
- BR-INT-03-1: Chỉ thị tái tục thay đổi được tới TRƯỚC ngày đáo hạn (qua kênh online/quầy);
  mặc định khi mở là "tái tục gốc".
- BR-INT-03-2: Lãi suất kỳ tái tục = biểu hiệu lực tại ngày tái tục (không phải lãi suất kỳ cũ);
  nếu sản phẩm đã RETIRED và không có kỳ tương ứng → ép chỉ thị "tất toán" + thông báo trước
  (nhắc từ T-7).
- BR-INT-03-3: Rút trước hạn là tất toán TOÀN PHẦN (BR-ACCT-02-2).

**Dữ liệu** — Bảng: accounts, term_deposit_details (đề xuất ở ACCT-02), interest_accruals + GL-02;
outbox.

---

### FEE-01 — Thu phí theo sự kiện giao dịch

**Nhóm/Service/GĐ** G / core-banking / GĐ5 (cùng TRF), GĐ4 (phí mở/đóng TK) · **Actor** Hệ thống (nghiệp vụ nguồn gọi vào) · **Trigger** Sự kiện có phí xảy ra: mở/đóng TK, chuyển nội bộ/liên NH, rút ATM, yêu cầu sao kê · **Ưu tiên** Cao

**Mô tả** — Thành phần dùng chung: khi một sự kiện thu phí xảy ra, tính phí theo biểu
(`product_fees` của sản phẩm tài khoản, hiệu lực tại ngày sự kiện), ghi nhận `fee_charges` và
hạch toán Nợ TK khách / Có GL 4010. Với sự kiện gắn giao dịch (chuyển tiền), phí đi CÙNG bút toán
giao dịch (dòng thứ 3) — không tách bút toán.

**Luồng chính (gọi từ nghiệp vụ nguồn)**
1. Nghiệp vụ nguồn hỏi biểu phí: (product, charge_event, ngày) → các dòng phí áp dụng.
2. Hệ thống tính từng dòng: FLAT lấy amount; PERCENT = số tiền × percent, kẹp [min, max]; cộng
   dồn nếu nhiều mã (BR-PROD-03-3).
3. Nghiệp vụ nguồn quyết định cách hạch toán:
   - Gắn giao dịch: thêm dòng Có 4010 vào bút toán giao dịch (TRF-01/02); ghi `fee_charges`
     POSTED cùng transaction, source trỏ giao dịch.
   - Độc lập (phí sao kê, phí đóng TK): bút toán FEE riêng — Nợ TK / Có 4010; `fee_charges`
     POSTED.
4. Outbox `fee.charged.v1` (nếu phí > 0); dòng phí hiển thị trong lịch sử giao dịch.

**Luồng ngoại lệ**
- E2. Biểu không có dòng cho sự kiện → phí 0, không ghi gì (khác dòng phí amount 0 — BR-PROD-03-1
  vẫn ghi vết `fee_charges` 0 khi có dòng biểu).
- E3. Phí độc lập nhưng available không đủ → `fee_charges` PENDING (nợ phí), job thu lại (xem
  FEE-02 E3 cùng cơ chế).

**Quy tắc nghiệp vụ**
- BR-FEE-01-1: `fee_charges` là vết đầy đủ của MỌI lần phát sinh phí, kể cả 0 đồng và WAIVED —
  trả lời được "sao tháng này không thu phí khách này" (comment schema).
- BR-FEE-01-2: GL phí lấy từ mapping FEE_INCOME của sản phẩm tại ngày sự kiện (BR-PROD-06-2) —
  không hardcode 4010.
- BR-FEE-01-3: `ck_fee_charge_posted`: POSTED bắt buộc có bút toán.

**Dữ liệu** — Bảng: `fee_charges` + GL-02; đọc biểu phí (API product).

---

### FEE-02 — Thu phí duy trì định kỳ

**Nhóm/Service/GĐ** G / core-banking / GĐ6 (EOD ngày đầu tháng) · **Actor** Hệ thống · **Trigger** OPS-03, ngày 01 hằng tháng cho tháng trước · **Ưu tiên** Trung bình

**Mô tả** — Thu `MONTHLY_MAINTENANCE` (seed: 11.000 đ/tháng cho CA_STANDARD) trên các tài khoản
thuộc sản phẩm có dòng phí này hiệu lực trong tháng vừa qua.

**Luồng chính**
1. Job quét tài khoản ACTIVE/DORMANT của các sản phẩm có phí duy trì hiệu lực tháng T.
2. Với từng tài khoản: kiểm miễn (BR-FEE-02-2), tạo `fee_charges`; available đủ → bút toán FEE
   (Nợ TK / Có GL FEE_INCOME) → POSTED.
3. Outbox `fee.charged.v1`; dòng phí lên lịch sử giao dịch.

**Luồng ngoại lệ**
- E2a. Available không đủ → `fee_charges` PENDING; job "thu nợ phí" các EOD sau thu tiếp khi có
  tiền (quét `idx_fee_pending`); quá 3 tháng treo → cảnh báo CSO cân nhắc DORMANT/đóng.
- E-double. Chạy lại tháng T → không tạo dòng trùng: kiểm tồn tại fee_charge (account, fee_code,
  kỳ) trước khi tạo (Điểm mở: thêm cột kỳ thu hoặc dùng source_id = "2026-08"; chốt khi triển
  khai).

**Quy tắc nghiệp vụ**
- BR-FEE-02-1: Tài khoản mở giữa tháng: thu đủ tháng hay theo tỷ lệ — tham số, mặc định thu đủ
  từ tháng kế tiếp tháng mở.
- BR-FEE-02-2: Miễn tự động theo điều kiện sản phẩm (ví dụ số dư bình quân ≥ ngưỡng): phạm vi
  đầu KHÔNG có — mọi miễn đi qua FEE-03; ghi chương 10 nếu cần tự động.
- BR-FEE-02-3: FROZEN: không thu (tránh đội nợ phí trên tài khoản tranh chấp) — tích lũy PENDING.

**Dữ liệu** — Bảng: `fee_charges` + GL-02.

---

### FEE-03 — Miễn / giảm phí

**Nhóm/Service/GĐ** G / core-banking / GĐ6 · **Actor** CSO (đề nghị), cấp phê duyệt theo ngưỡng · **Trigger** Khiếu nại hợp lệ / chính sách chăm sóc khách hàng · **Ưu tiên** Thấp

**Mô tả** — Miễn một khoản phí ĐANG PENDING: chuyển `fee_charges` → WAIVED, giữ nguyên vết. Phí
đã POSTED muốn hoàn phải đi đường bút toán đảo/điều chỉnh có phê duyệt (GL-03), không sửa trạng
thái.

**Luồng chính**
1. CSO chọn khoản phí PENDING, nhập lý do miễn.
2. Cấp phê duyệt duyệt (maker–checker; ngưỡng tự duyệt của CSO là tham số, mặc định 0 — mọi miễn
   cần duyệt).
3. Hệ thống đặt WAIVED; ghi audit người đề nghị + người duyệt + lý do.
4. Thông báo khách nếu khoản phí trước đó đã được báo nợ.

**Luồng ngoại lệ**
- E1. Khoản phí đã POSTED → từ chối miễn; hướng dẫn lập hồ sơ hoàn phí (GL-03 + phê duyệt kế toán).
- E1b. Đã WAIVED → idempotent, trả kết quả cũ.

**Quy tắc nghiệp vụ**
- BR-FEE-03-1: WAIVED là trạng thái cuối; không quay lại PENDING.
- BR-FEE-03-2: Báo cáo tháng tổng số phí miễn theo người duyệt — kiểm soát lạm quyền.

**Dữ liệu** — Bảng: `core_banking.fee_charges`.
