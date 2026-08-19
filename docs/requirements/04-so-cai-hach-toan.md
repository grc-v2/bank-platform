# 04 — Nhóm D: Sổ cái & hạch toán

Service: `core-banking-service` (schema `core_banking`). Giai đoạn 4 (GL-04/05 hoàn thiện ở GĐ6).

Nền tảng kế toán của cả hệ thống. Hai sổ phân biệt: **`gl_accounts` là sổ cái của ngân hàng**
(chart of accounts), **`accounts` là sổ phụ của khách hàng**. Bất biến đối chiếu cơ bản nhất:
tổng số dư mọi tài khoản khách hàng của một sản phẩm = số dư GL PRINCIPAL tương ứng.

Bốn quyết định thiết kế lớn (DB1–DB4, xem đầu `schema.sql`) chi phối toàn bộ nhóm này:
bút toán kép thật (header + lines) · cân Nợ/Có cưỡng chế tại COMMIT · không tài khoản SYSTEM
(dòng nội bộ đi thẳng GL, `account_id` NULL) · số dư lưu sẵn, không tính lại từ sổ cái.

---

### GL-01 — Quản lý hệ thống tài khoản kế toán (chart of accounts)

**Nhóm/Service/GĐ** D / core-banking / GĐ4 · **Actor** Kế toán trưởng (ADMIN) · **Trigger** Khởi tạo hệ thống / thêm tài khoản kế toán · **Ưu tiên** Cao

**Mô tả** — Quản lý `gl_accounts`: mã GL, tên, loại (ASSET/LIABILITY/EQUITY/INCOME/EXPENSE), số
dư bình thường (DEBIT/CREDIT — DB cưỡng chế khớp loại: tài sản/chi phí tăng bên Nợ; nợ phải
trả/vốn/thu nhập tăng bên Có), cây cha–con, cờ `is_postable` (FALSE = tài khoản tổng hợp, chỉ để
gom số — hạch toán thẳng vào nó bị posting engine chặn).

Quy ước đánh số (đã seed): `1xxx` tài sản · `2xxx` nợ phải trả · `3xxx` vốn · `4xxx` thu nhập ·
`5xxx` chi phí. 9 GL khởi điểm gồm 1010 (tiền mặt), 1900 (trung gian thanh toán), 2010/2020
(tiền gửi CA/SA+TD), 2110 (lãi phải trả), 3010/3020 (vốn), 4010 (thu phí), 5010 (chi phí lãi).

**Luồng chính (thêm GL)**
1. Kế toán trưởng nhập mã, tên, loại, cha (nếu có), is_postable, loại tiền.
2. Hệ thống validate: mã duy nhất (`uq_gl_code`); normal_balance khớp loại
   (`ck_gl_class_normal`); cha tồn tại và không phải chính nó (`ck_gl_parent_not_self`).
3. Hệ thống ghi `gl_accounts` (ACTIVE); ghi audit.

**Luồng thay thế / ngoại lệ**
- A1. Đóng GL: chỉ khi số dư = 0 và không còn `accounts`/`product_gl_mappings` hiệu lực trỏ vào
  → `status = CLOSED`; GL CLOSED không nhận bút toán mới.
- E2. Tạo chu trình dài trong cây (A→B→A): DB chỉ chặn vòng độ dài 1 — ứng dụng phải tự kiểm khi
  gán cha (duyệt cây bằng `WITH RECURSIVE ... CYCLE` — ghi chú schema).

**Quy tắc nghiệp vụ**
- BR-GL-01-1: Không xóa GL; không đổi loại/normal_balance sau khi đã có bút toán.
- BR-GL-01-2: Báo cáo cộng dồn theo cây phải dùng truy vấn chống chu trình.
- BR-GL-01-3: Số dư GL 1900 (trung gian) phải về 0 sau mỗi phiên đối soát (kiểm ở GL-05).

**Dữ liệu** — Bảng: `core_banking.gl_accounts`.

---

### GL-02 — Ghi bút toán kép (posting engine)

**Nhóm/Service/GĐ** D / core-banking / GĐ4 · **Actor** Hệ thống (mọi chức năng dịch chuyển tiền gọi vào) · **Trigger** Nghiệp vụ cần hạch toán (mở TK, chuyển tiền, lãi, phí, đảo, điều chỉnh) · **Ưu tiên** Cao nhất

**Mô tả** — Hàm nghiệp vụ trung tâm (KHÔNG phải endpoint công khai): nhận một **lệnh hạch toán**
(loại giao dịch, value_date, mô tả, danh sách dòng Nợ/Có) và ghi trọn vẹn trong MỘT transaction:
header (`journal_entries`) + các dòng (`journal_lines`) + cập nhật `accounts.ledger_balance` của
mọi tài khoản khách hàng bị chạm. Ví dụ chuyển 100.000 phí 2.000 là một bút toán BA dòng:
Nợ TK gửi 102.000 · Có TK nhận 100.000 · Có GL 4010 2.000.

**Tiền điều kiện** — Caller đã validate nghiệp vụ (trạng thái tài khoản, hạn mức…). Posting engine
chỉ giữ bất biến kế toán.

**Luồng chính**
1. Caller (TRF-01, INT-02, FEE-01…) truyền lệnh hạch toán trong transaction nghiệp vụ đang mở.
2. Hệ thống sinh `entry_reference` duy nhất; ghi header (transaction_type, value_date,
   booking_date, source_type/source_id trỏ về nghiệp vụ nguồn).
3. Hệ thống ghi từng dòng: line_no tăng dần; mỗi dòng mang gl_code (bắt buộc), account_id (NULL
   nếu chỉ chạm GL nội bộ), direction, amount > 0, currency.
4. Với mỗi dòng có account_id: hệ thống cập nhật `accounts.ledger_balance` (± theo chiều so với
   bản chất tài khoản tiền gửi: Có tăng, Nợ giảm) và ghi `balance_after` vào dòng; optimistic
   lock qua `accounts.version`.
5. COMMIT — tại đây DB kiểm lần cuối: ≥ 2 dòng, tổng Nợ = tổng Có, một loại tiền, không dính GL
   tổng hợp, loại tiền dòng khớp tài khoản (`trg_journal_balanced`).

**Luồng ngoại lệ**
- E5. Bút toán không cân / trộn tiền / GL tổng hợp → transaction rollback toàn bộ — không tồn tại
  bút toán ghi dở.
- E4a. Vi phạm `ck_accounts_available` (số dư khả dụng âm quá thấu chi) → rollback; caller báo lỗi
  "không đủ số dư".
- E4b. Optimistic lock trượt (version đổi) → caller retry theo chính sách (tối đa N lần).
- E-any. Ý đồ UPDATE/DELETE bút toán, hoặc chèn dòng vào bút toán đã commit → DB từ chối
  (`trg_*_immutable`, `trg_journal_lines_same_txn`) — không có đường sửa sổ, chỉ có GL-03.

**Hậu điều kiện** — Bút toán cân nằm trong sổ, số dư mọi tài khoản chạm khớp bút toán trong cùng
transaction; hoặc không có gì cả.

**Quy tắc nghiệp vụ**
- BR-GL-02-1: Ghi bút toán và cập nhật số dư là MỘT transaction (quyết định DB4).
- BR-GL-02-2: `value_date` do nghiệp vụ đưa (ngày tính lãi); `booking_date` mặc định hôm nay
  (kỳ sổ) — không trộn hai khái niệm (BR-G10).
- BR-GL-02-3: `source_type`/`source_id` bắt buộc với bút toán sinh từ nghiệp vụ (truy ngược
  transfer/fee/accrual từ bút toán và ngược lại).
- BR-GL-02-4: Chọn gl_code cho tài khoản khách hàng: theo `accounts.gl_code` (đã chốt lúc mở TK
  từ product_gl_mappings); dòng phí/lãi: tra mapping theo value_date (BR-PROD-06-2).

**Dữ liệu** — Vào: lệnh hạch toán. Bảng: `core_banking.journal_entries`, `journal_lines`,
`accounts`.

---

### GL-03 — Bút toán đảo

**Nhóm/Service/GĐ** D / core-banking / GĐ4 · **Actor** Hệ thống (saga, tra soát); Kế toán (điều chỉnh thủ công có phê duyệt) · **Trigger** Giao dịch cần hoàn (TRF-05/06), hạch toán sai cần sửa · **Ưu tiên** Cao

**Mô tả** — Cách DUY NHẤT sửa sổ cái: ghi bút toán mới `transaction_type = REVERSAL`, các dòng
đảo chiều Nợ↔Có nguyên số tiền, `reversal_of_entry_id` trỏ về bản gốc. Một bút toán chỉ được đảo
MỘT lần (`uq_journal_one_reversal`); không có đảo từng phần (lựa chọn chính sách — ghi chú schema).

**Tiền điều kiện** — Bút toán gốc tồn tại, chưa từng bị đảo.

**Luồng chính**
1. Caller yêu cầu đảo bút toán X kèm lý do.
2. Hệ thống đọc trọn các dòng của X; dựng lệnh hạch toán mới: mỗi dòng giữ nguyên account/GL/số
   tiền, đảo chiều; value_date = ngày hiệu lực của việc hoàn (thường là hôm nay).
3. Hệ thống gọi GL-02 với transaction_type REVERSAL + `reversal_of_entry_id = X`.
4. DB cưỡng chế: REVERSAL bắt buộc trỏ gốc (`ck_journal_reversal`); X chưa bị đảo
   (`uq_journal_one_reversal`).
5. Ghi audit (lý do, người/tiến trình yêu cầu).

**Luồng ngoại lệ**
- E4. X đã bị đảo → từ chối (unique violation) — chống hoàn tiền hai lần.
- A1. Đảo một bút toán đảo (khôi phục giao dịch đã hoàn nhầm): hợp lệ — C đảo B, B đảo A.
- A2. Điều chỉnh thủ công không tương ứng 1-1 với bút toán gốc → dùng `ADJUSTMENT` (bút toán
  thường, có phê duyệt kế toán), không lạm dụng REVERSAL.

**Quy tắc nghiệp vụ**
- BR-GL-03-1: Đảo nguyên vẹn 100% số tiền bản gốc; cần hoàn một phần → ADJUSTMENT.
- BR-GL-03-2: Đảo bút toán của kỳ sổ đã đóng: booking_date của bút toán đảo là kỳ hiện tại
  (không mở lại kỳ cũ).
- BR-GL-03-3: Đảo thủ công yêu cầu vai trò kế toán + lý do; đảo tự động (saga) ghi rõ nguồn.

**Dữ liệu** — Bảng: `core_banking.journal_entries`, `journal_lines`, `accounts`.

---

### GL-04 — Chốt số dư cuối ngày (snapshot)

**Nhóm/Service/GĐ** D / core-banking / GĐ6 (trong lịch EOD) · **Actor** Hệ thống · **Trigger** OPS-03 gọi trong lịch cuối ngày · **Ưu tiên** Cao

**Mô tả** — Ghi `account_balance_snapshots` cho MỌI tài khoản: số dư mở/đóng ngày, tổng Nợ/Có
phát sinh trong ngày. Hai công dụng: sao kê không phải quét sổ cái từ đầu; đối chiếu (GL-05) có
mốc để so.

**Luồng chính**
1. OPS-03 kích hoạt sau giờ khóa sổ ngày D.
2. Hệ thống, với từng tài khoản: opening = closing của snapshot D-1 (hoặc 0 nếu chưa có);
   total_debit/total_credit = tổng dòng bút toán trong ngày D; closing = opening − Nợ + Có.
3. Hệ thống ghi snapshot (PK (account_id, as_of_date) — chạy lại ngày D là idempotent: đã có thì
   bỏ qua hoặc so khớp).
4. Hệ thống so `closing` với `accounts.ledger_balance` hiện hành → lệch thì gắn cờ cho GL-05.

**Luồng ngoại lệ**
- E3. Snapshot ngày D đã tồn tại nhưng số khác số vừa tính → KHÔNG ghi đè; sinh cảnh báo đối chiếu
  (dữ liệu đã bị chạm sau khóa sổ).

**Quy tắc nghiệp vụ**
- BR-GL-04-1: Snapshot bất biến sau khi ghi.
- BR-GL-04-2: Ranh giới "trong ngày D" tính theo booking_date của bút toán.
- BR-GL-04-3: EOD chưa xong ngày D thì không mở ngày D+1 (thứ tự do OPS-03 giữ).

**Dữ liệu** — Bảng: `core_banking.account_balance_snapshots`, đọc `journal_lines`, `accounts`.

---

### GL-05 — Đối chiếu sổ cái — sổ phụ

**Nhóm/Service/GĐ** D / core-banking / GĐ6, chạy định kỳ mãi mãi · **Actor** Hệ thống; Kế toán (xử lý lệch) · **Trigger** Trong lịch EOD sau GL-04; chạy tay khi nghi ngờ · **Ưu tiên** Cao

**Mô tả** — Lưới an toàn cuối cùng. Ba phép kiểm bất biến (ghi chú vận hành [8] của schema):
1. **Từng bút toán cân**: SUM(DEBIT) = SUM(CREDIT) mỗi journal_entry (trigger đã giữ lúc ghi —
   quét lại để bắt can thiệp trực tiếp DB).
2. **Sổ phụ khớp sổ cái**: với mỗi gl_code, SUM(ledger_balance các accounts trỏ vào) = số dư GL
   tính từ journal_lines.
3. **GL trung gian 1900 về 0** sau phiên đối soát liên ngân hàng (theo chu kỳ đối soát).

**Luồng chính**
1. Hệ thống chạy 3 phép kiểm trên dữ liệu tới cuối ngày D.
2. Tất cả khớp → ghi kết quả phiên đối chiếu "PASS ngày D" (log/bảng kết quả).
3. Có lệch → sinh **báo cáo lệch** chi tiết (bút toán nào, GL nào, chênh bao nhiêu), cảnh báo
   mức cao tới Kế toán + Ops; **không tự sửa bất kỳ số nào**.
4. Kế toán điều tra, xử lý bằng bút toán ADJUSTMENT/REVERSAL có phê duyệt; phiên sau kiểm lại.

**Quy tắc nghiệp vụ**
- BR-GL-05-1: Đối chiếu chỉ ĐỌC — mọi sửa chữa đi qua bút toán có phê duyệt.
- BR-GL-05-2: Lệch là sự cố mức cao: chặn phát hành báo cáo ngày, không chặn giao dịch online
  (trừ khi Kế toán quyết định phong tỏa cụ thể).
- BR-GL-05-3: Kết quả từng phiên lưu lại được để chứng minh với kiểm toán "ngày nào cũng đối chiếu".

**Dữ liệu** — Đọc: `journal_entries`, `journal_lines`, `accounts`, `gl_accounts`,
`account_balance_snapshots`. Ghi: kết quả phiên đối chiếu (Điểm mở: schema chưa có bảng
`reconciliation_runs` — đề xuất thêm khi triển khai GĐ6, hoặc tối thiểu ghi audit_log).
