# 02 — Nhóm B: Khách hàng & KYC

Service: `customer-service` (schema `customer`). Giai đoạn 2.

Ba khái niệm phân biệt rạch ròi: **user** (danh tính đăng nhập, schema auth) ≠ **customer/CIF**
(hồ sơ khách hàng của ngân hàng) ≠ **account** (tài khoản tiền, schema core_banking). Một khách
mở tại quầy có thể chưa có user (`customers.user_id` NULL); một user chưa chắc đã là khách hàng.

Máy trạng thái hồ sơ (`customers.status`) — dùng chung cho cả nhóm:

| Từ | Đến | Chức năng gây ra |
|---|---|---|
| — | DRAFT | CUST-01/02 tạo hồ sơ |
| DRAFT | PENDING_KYC | CUST-06 nộp hồ sơ KYC đầu tiên |
| PENDING_KYC | ACTIVE | CUST-07 duyệt KYC mức ≥ 1 |
| PENDING_KYC | DRAFT | CUST-07 từ chối KYC (hồ sơ về sửa lại) |
| ACTIVE | SUSPENDED | CUST-10 đình chỉ (nghi gian lận, lệnh cơ quan) |
| SUSPENDED | ACTIVE | CUST-10 kích hoạt lại |
| ACTIVE, SUSPENDED | CLOSED | CUST-10 đóng hồ sơ (không đảo ngược) |

---

### CUST-01 — Mở hồ sơ khách hàng cá nhân

**Nhóm/Service/GĐ** B / customer-service / GĐ2 · **Actor** Teller (tại quầy), Khách hàng (online — self-onboarding) · **Trigger** Yêu cầu trở thành khách hàng · **Ưu tiên** Cao

**Mô tả** — Tạo CIF cá nhân: bản ghi chung (`customers`) + chi tiết cá nhân
(`individual_details`) + giấy tờ + liên hệ + địa chỉ. Hồ sơ sinh ra ở `DRAFT`, `kyc_level = 0` —
chưa mở được tài khoản nào cho tới khi KYC đạt mức sản phẩm yêu cầu.

**Tiền điều kiện** — Actor đã đăng nhập (Teller; hoặc user tự đăng ký với self-onboarding).
Giấy tờ định danh của khách chưa gắn với CIF nào khác.

**Luồng chính**
1. Teller nhập: họ tên, ngày sinh, giới tính, quốc tịch, nghề nghiệp, tình trạng hôn nhân.
2. Teller nhập giấy tờ định danh chính (loại, số, ngày cấp, nơi cấp, ngày hết hạn).
3. Teller nhập liên hệ (mobile, email) và địa chỉ (thường trú; nơi ở nếu khác).
4. Hệ thống validate: ngày sinh trong quá khứ (`ck_individual_dob`), tuổi ≥ 15 (độ tuổi được mở
   CIF — BR-CUST-01-2), số giấy tờ chưa tồn tại (`uq_ident`).
5. Hệ thống sinh số CIF (`customer_number`) theo quy tắc đánh số (BR-G9).
6. Hệ thống ghi `customers` (DRAFT, INDIVIDUAL) + `individual_details` +
   `customer_identifications` + `customer_contacts` + `customer_addresses` trong một transaction.
7. Nếu khách mở online: gắn `user_id` của người đang đăng nhập.
8. Hệ thống trả về số CIF; hướng dẫn bước kế: xác minh liên hệ (CUST-05) rồi nộp KYC (CUST-06).

**Luồng thay thế / ngoại lệ**
- E4a. Số giấy tờ đã thuộc CIF khác → từ chối, chỉ dẫn tra cứu hồ sơ hiện có (chống trùng danh tính).
- E4b. Dưới độ tuổi tối thiểu → từ chối (giám hộ nằm ngoài phạm vi — Điểm mở).
- A1. Self-onboarding online: khách tự nhập; một user chỉ gắn được một CIF cá nhân (BR-CUST-01-3).

**Hậu điều kiện** — Thành công: CIF DRAFT đầy đủ chi tiết; chưa phát event (hồ sơ chưa có hiệu lực
với hệ thống khác). Thất bại: không có dữ liệu mới.

**Quy tắc nghiệp vụ**
- BR-CUST-01-1: Một số giấy tờ (loại + số) chỉ thuộc một khách hàng (`uq_ident`).
- BR-CUST-01-2: Tuổi tối thiểu mở CIF: 15 (điều kiện mở từng sản phẩm chặt hơn nằm ở
  `product_eligibility_rules`, ví dụ CA yêu cầu ≥ 18).
- BR-CUST-01-3: Một `user_id` gắn tối đa một CIF cá nhân đang không CLOSED.
- BR-CUST-01-4: Hồ sơ DRAFT không xuất hiện với các service khác (không event, không mở tài khoản).

**Dữ liệu** — Vào: nhóm trường ở bước 1–3 (họ tên, ngày sinh, giấy tờ, mobile bắt buộc; còn lại
tùy chọn). Ra: `customer_number`. Bảng: `customer.customers`, `individual_details`,
`customer_identifications`, `customer_contacts`, `customer_addresses`.

**Điểm mở** — Quy tắc sinh số CIF (độ dài, tiền tố) chưa chốt; đề xuất `1` + 9 chữ số tăng dần.
Người giám hộ/đại diện cho vị thành niên: ngoài phạm vi.

---

### CUST-02 — Mở hồ sơ khách hàng tổ chức

**Nhóm/Service/GĐ** B / customer-service / GĐ2 · **Actor** Teller · **Trigger** Doanh nghiệp đề nghị mở quan hệ · **Ưu tiên** Trung bình

**Mô tả** — Tạo CIF tổ chức: `customers` (ORGANIZATION) + `organization_details` (tên pháp lý,
tên giao dịch, mã số thuế, ngày thành lập, loại hình) + giấy phép kinh doanh + liên hệ/địa chỉ
trụ sở. Mô hình disjoint subtype: một CIF hoặc cá nhân hoặc tổ chức, DB tự chặn gắn nhầm loại.

**Tiền điều kiện** — Mã số thuế chưa thuộc CIF tổ chức nào (`uq_organization_tax_code`).

**Luồng chính**
1. Teller nhập tên pháp lý, mã số thuế, ngày thành lập, loại hình kinh doanh.
2. Teller nhập giấy tờ `BUSINESS_LICENSE` (số, ngày cấp, nơi cấp).
3. Teller nhập địa chỉ `BUSINESS` và liên hệ của tổ chức.
4. Hệ thống validate mã số thuế (định dạng 10 hoặc 13 số; chưa tồn tại).
5. Hệ thống sinh số CIF, ghi các bảng trong một transaction (như CUST-01 bước 5–6).
6. Trả về số CIF; bước kế: KYC tổ chức (CUST-06, method MANUAL).

**Luồng ngoại lệ**
- E4. Mã số thuế đã tồn tại → từ chối, dẫn về hồ sơ hiện có.

**Hậu điều kiện / Quy tắc / Dữ liệu** — tương tự CUST-01, thay chi tiết cá nhân bằng
`organization_details`.
- BR-CUST-02-1: KYC tổ chức chỉ dùng method `MANUAL` (EKYC là cho cá nhân).
- BR-CUST-02-2: Người đại diện theo pháp luật ghi nhận ở mục liên hệ; mô hình đầy đủ
  (beneficial owner, cổ đông) — Điểm mở, ngoài phạm vi GĐ2.

---

### CUST-03 — Cập nhật liên hệ & địa chỉ

**Nhóm/Service/GĐ** B / customer-service / GĐ2 · **Actor** Teller; Khách hàng (với hồ sơ của mình) · **Trigger** Khách báo thay đổi · **Ưu tiên** Trung bình

**Mô tả** — Địa chỉ là dữ liệu **có lịch sử hiệu lực** (`valid_from/valid_to`): đổi địa chỉ =
đóng dòng cũ + thêm dòng mới, để sao kê kỳ cũ in đúng địa chỉ tại kỳ đó. Liên hệ thêm/bớt theo
dòng; kênh mới nhập vào là CHƯA xác minh.

**Tiền điều kiện** — CIF không ở trạng thái CLOSED.

**Luồng chính (đổi địa chỉ)**
1. Actor chọn loại địa chỉ (PERMANENT/RESIDENTIAL/MAILING/BUSINESS), nhập địa chỉ mới.
2. Hệ thống đóng dòng hiện hành cùng loại: `valid_to = ngày hiệu lực mới`.
3. Hệ thống chèn dòng mới (`valid_from = ngày hiệu lực`, `valid_to = NULL`) — cùng transaction.
   (DB cưỡng chế mỗi loại chỉ một dòng đang hiệu lực: `uq_address_current`.)
4. Ghi audit thay đổi.

**Luồng chính (thêm/đổi liên hệ)**
1. Actor thêm liên hệ mới (EMAIL/MOBILE/PHONE, giá trị).
2. Hệ thống validate định dạng; ghi dòng mới `verified_at = NULL`.
3. Nếu là kênh chính (`is_primary`): chỉ được đặt primary sau khi xác minh (CUST-05).

**Luồng ngoại lệ**
- E1. Khách hàng online sửa hồ sơ người khác → 403 (kiểm ownership qua `user_id`).
- E2. Đổi các trường ĐỊNH DANH (họ tên, ngày sinh, số giấy tờ) → KHÔNG đi qua chức năng này;
  yêu cầu quy trình có phê duyệt + giấy tờ chứng minh (Điểm mở — thiết kế ở GĐ7).

**Quy tắc nghiệp vụ**
- BR-CUST-03-1: Không UPDATE đè giá trị địa chỉ — chỉ đóng dòng + thêm dòng (BR-G5).
- BR-CUST-03-2: Liên hệ mới nhập luôn ở trạng thái chưa xác minh; hệ thống không gửi OTP tới kênh
  chưa xác minh (trừ chính luồng xác minh CUST-05).
- BR-CUST-03-3: Không xóa kênh liên hệ đã xác minh cuối cùng của hồ sơ ACTIVE.

**Dữ liệu** — Bảng: `customer.customer_addresses`, `customer.customer_contacts`.

---

### CUST-04 — Quản lý giấy tờ định danh

**Nhóm/Service/GĐ** B / customer-service / GĐ2 · **Actor** Teller · **Trigger** Khách bổ sung / thay giấy tờ (đổi CCCD, hộ chiếu mới…) · **Ưu tiên** Trung bình

**Mô tả** — Thêm giấy tờ mới cho CIF (NATIONAL_ID/PASSPORT/DRIVER_LICENSE/BUSINESS_LICENSE).
Giấy tờ cũ không xóa (bằng chứng tuân thủ, BR-G6) — giấy tờ hết hạn tự mất giá trị theo
`expiry_date`.

**Luồng chính**
1. Teller nhập loại, số, ngày cấp, nơi cấp, ngày hết hạn.
2. Hệ thống validate: `expiry_date > issued_date` (`ck_ident_expiry`); (loại, số) chưa thuộc CIF
   khác (`uq_ident`).
3. Hệ thống ghi dòng mới; ghi audit.

**Luồng ngoại lệ**
- E2a. Trùng (loại, số) với CIF khác → từ chối — điều tra trùng danh tính thủ công.
- E2b. Trùng (loại, số) với chính CIF này → báo "đã tồn tại", không tạo bản sao.

**Quy tắc nghiệp vụ**
- BR-CUST-04-1: Giao dịch cần giấy tờ hợp lệ phải kiểm `expiry_date` tại thời điểm giao dịch;
  giấy tờ hết hạn không chặn lịch sử nhưng chặn nghiệp vụ mới.
- BR-CUST-04-2: Không sửa số giấy tờ trên dòng đã ghi — nhập sai thì thêm dòng đúng, dòng sai đánh
  dấu vô hiệu qua quy trình phê duyệt (Điểm mở: schema chưa có cột trạng thái dòng giấy tờ).

**Dữ liệu** — Bảng: `customer.customer_identifications`.

---

### CUST-05 — Xác minh kênh liên hệ (OTP)

**Nhóm/Service/GĐ** B / customer-service (+ notification-service) / GĐ2 · **Actor** Khách hàng · **Trigger** Sau khi thêm liên hệ / trước nghiệp vụ cần kênh đã xác minh · **Ưu tiên** Cao

**Mô tả** — Chứng minh khách thực sự sở hữu email/số điện thoại bằng OTP. Chỉ kênh có
`verified_at` khác NULL mới được dùng nhận OTP giao dịch và thông báo nhạy cảm. "Gửi OTP tới kênh
chưa xác minh là lỗ hổng, không phải tiện ích" (comment schema).

**Tiền điều kiện** — Kênh liên hệ tồn tại trong hồ sơ, chưa xác minh.

**Luồng chính**
1. Khách yêu cầu xác minh một kênh liên hệ.
2. Hệ thống sinh OTP (6 số, TTL 5 phút, tối đa 5 lần thử), lưu hash OTP + hạn.
3. Hệ thống gửi OTP tới CHÍNH kênh đó (qua notification-service — đây là ngoại lệ hợp lệ duy nhất
   của việc gửi tới kênh chưa xác minh).
4. Khách nhập OTP.
5. Hệ thống so khớp, đặt `verified_at = now()`; ghi audit.

**Luồng ngoại lệ**
- E4a. Sai OTP → còn n lần thử; hết lượt → hủy OTP, phải yêu cầu lại (bước 1) sau thời gian nguội.
- E4b. OTP hết hạn → yêu cầu gửi lại; giới hạn tần suất gửi (≤ 3 lần/15 phút/kênh).

**Quy tắc nghiệp vụ**
- BR-CUST-05-1: OTP lưu dạng hash, dùng một lần, không log giá trị.
- BR-CUST-05-2: Giới hạn tần suất phát OTP theo kênh và theo user (chống spam/bombing).

**Dữ liệu** — Bảng: `customer.customer_contacts` (+ nơi lưu OTP tạm: bảng/cache riêng — Điểm mở:
schema chưa có bảng OTP; đề xuất lưu ở cache có TTL thay vì bảng).

---

### CUST-06 — Nộp hồ sơ KYC

**Nhóm/Service/GĐ** B / customer-service / GĐ2 · **Actor** Khách hàng (EKYC), Teller (MANUAL) · **Trigger** Sau mở CIF, hoặc khi cần nâng mức KYC, hoặc tái KYC · **Ưu tiên** Cao

**Mô tả** — Tạo một lượt xác minh KYC (`kyc_verifications`) ở mức đăng ký 1–3 kèm tài liệu chứng
minh (`kyc_documents` — ảnh giấy tờ, selfie, chứng từ; file nằm trên object storage, DB giữ khóa +
checksum SHA-256). Mức KYC càng cao, hạn mức/sản phẩm mở càng rộng (quy tắc ở
`product_eligibility_rules`).

**Tiền điều kiện** — CIF ở DRAFT (KYC đầu tiên) hoặc ACTIVE (nâng mức/tái KYC); không có lượt KYC
đang PENDING/IN_REVIEW cho cùng CIF.

**Luồng chính**
1. Actor chọn mức đăng ký (1–3) và phương thức: EKYC (khách tự chụp, online) hoặc MANUAL (quầy).
2. Actor tải lên tài liệu theo checklist của mức (ví dụ mức 1: ảnh 2 mặt giấy tờ + selfie; mức 2:
   thêm xác minh nơi cư trú; mức 3: thẩm định trực tiếp).
3. Hệ thống lưu file lên object storage, tính checksum SHA-256, ghi `kyc_documents`.
4. Hệ thống tạo `kyc_verifications` (PENDING, level, method, submitted_at).
5. Nếu CIF đang DRAFT: chuyển `customers.status = PENDING_KYC`.
6. Hệ thống đưa hồ sơ vào hàng đợi thẩm định (CUST-07); báo khách "đang xử lý".

**Luồng thay thế / ngoại lệ**
- E-tiền-điều-kiện. Đang có lượt PENDING/IN_REVIEW → từ chối tạo lượt mới, trả về lượt hiện có.
- A1. EKYC có bước đối chiếu tự động (OCR đọc giấy tờ, so khớp khuôn mặt) trước khi vào hàng đợi;
  kết quả tự động là THAM KHẢO cho CSO, không tự duyệt (Điểm mở: tích hợp nhà cung cấp eKYC).
- E2. Thiếu tài liệu bắt buộc của mức → từ chối nộp, trả checklist còn thiếu.

**Hậu điều kiện** — Lượt KYC PENDING + tài liệu đầy đủ; CIF ở PENDING_KYC nếu là lần đầu.

**Quy tắc nghiệp vụ**
- BR-CUST-06-1: Mỗi CIF tối đa một lượt KYC đang mở (PENDING/IN_REVIEW).
- BR-CUST-06-2: Mức đăng ký chỉ được cao hơn mức hiện tại (nâng dần); tái KYC do hết hạn nộp lại
  đúng mức cũ.
- BR-CUST-06-3: Checksum để phát hiện file bị thay sau khi duyệt — mọi lần đọc lại tài liệu phải
  đối chiếu checksum.

**Dữ liệu** — Vào: level, method, danh sách file. Bảng: `customer.kyc_verifications`,
`customer.kyc_documents`, `customer.customers`.

---

### CUST-07 — Thẩm định & phê duyệt KYC

**Nhóm/Service/GĐ** B / customer-service / GĐ2 · **Actor** CSO · **Trigger** Có hồ sơ trong hàng đợi thẩm định · **Ưu tiên** Cao

**Mô tả** — CSO nhận hồ sơ, đối chiếu tài liệu với thông tin khai, ra quyết định duyệt/từ chối.
Đây là điểm **maker–checker**: người nộp (khách/teller) khác người duyệt. Duyệt xong hồ sơ có HẠN
hiệu lực — không phải "duyệt một lần là xong đời".

**Tiền điều kiện** — Lượt KYC ở PENDING.

**Luồng chính**
1. CSO nhận hồ sơ từ hàng đợi → hệ thống chuyển `IN_REVIEW` (khóa mềm: một hồ sơ một người thẩm định).
2. CSO đối chiếu: tài liệu khớp thông tin khai; giấy tờ còn hạn; ảnh selfie khớp giấy tờ (EKYC có
   điểm số tự động tham khảo).
3. CSO quyết định **DUYỆT**: hệ thống, trong một transaction:
   a. `kyc_verifications`: APPROVED, `decided_at`, `decided_by`, `expires_at` = now + niên hạn
      theo mức (BR-CUST-07-2).
   b. `customers.kyc_level` = mức vừa duyệt; nếu đang PENDING_KYC → `status = ACTIVE`.
   c. Ghi outbox `customer.kyc.approved.v1` (payload: customer_id, customer_number, kyc_level,
      risk_rating hiện hành).
4. Hệ thống thông báo khách (qua event → notification).

**Luồng thay thế / ngoại lệ**
- A3. **TỪ CHỐI**: `REJECTED` + `reject_reason` bắt buộc (`ck_kyc_reject`); CIF đang PENDING_KYC
  → về DRAFT; thông báo khách kèm lý do và hướng khắc phục; khách nộp lại từ CUST-06.
- E2. Nghi giả mạo tài liệu → từ chối + chuyển cảnh báo Risk Officer (CUST-09).
- A1. CSO trả hồ sơ về hàng đợi (không quyết định) → về PENDING.

**Hậu điều kiện** — Duyệt: `kyc_level` mới có hiệu lực toàn hệ thống qua event; CIF ACTIVE.
Từ chối: mức cũ giữ nguyên, lượt đóng ở REJECTED.

**Quy tắc nghiệp vụ**
- BR-CUST-07-1: Người duyệt ≠ người nộp; `decided_by` bắt buộc khi có quyết định (`ck_kyc_decided`).
- BR-CUST-07-2: Niên hạn KYC theo mức (tham số): mức 1 = 5 năm, mức 2 = 3 năm, mức 3 = 1 năm
  (đề xuất — chốt theo chính sách tuân thủ).
- BR-CUST-07-3: Từ chối bắt buộc có lý do; lý do hiển thị cho khách.
- BR-CUST-07-4: Không hạ mức KYC qua chức năng này (hạ chỉ xảy ra khi hết hạn — CUST-08).

**Dữ liệu** — Bảng: `customer.kyc_verifications`, `customer.customers`, `customer.outbox`.

---

### CUST-08 — Theo dõi hiệu lực KYC & tái KYC

**Nhóm/Service/GĐ** B / customer-service / GĐ6 (job EOD) · **Actor** Hệ thống · **Trigger** Job hằng ngày · **Ưu tiên** Trung bình

**Mô tả** — Quét lượt KYC APPROVED sắp/đã quá `expires_at`: nhắc trước khi hết hạn; quá hạn thì
chuyển EXPIRED và hạ hiệu lực KYC của khách cho tới khi tái KYC xong.

**Luồng chính**
1. Job hằng ngày quét `kyc_verifications` APPROVED có `expires_at` trong cửa sổ nhắc (T-30, T-7).
2. Hệ thống gửi thông báo nhắc tái KYC (qua notification).
3. Với lượt đã quá hạn: đặt `status = EXPIRED`; đặt `customers.kyc_level` về mức của lượt
  APPROVED còn hiệu lực cao nhất (0 nếu không còn); phát `customer.status.changed.v1` nếu điều đó
  làm thay đổi năng lực giao dịch.
4. Khách tái KYC qua CUST-06 → CUST-07.

**Quy tắc nghiệp vụ**
- BR-CUST-08-1: Hết hạn KYC không tự đóng/đình chỉ CIF — chỉ hạ `kyc_level`; các nghiệp vụ đòi mức
  cao hơn tự bị chặn bởi eligibility.
- BR-CUST-08-2: Job idempotent theo ngày — chạy lại không gửi trùng thông báo (đối chiếu đã gửi).

**Dữ liệu** — Bảng: `customer.kyc_verifications`, `customer.customers`, `customer.outbox`.

---

### CUST-09 — Đánh giá rủi ro khách hàng

**Nhóm/Service/GĐ** B / customer-service / GĐ2 (nền) – GĐ7 (nâng cao) · **Actor** Risk Officer; Hệ thống (chấm tự động) · **Trigger** Sau KYC duyệt lần đầu; định kỳ; khi có cảnh báo · **Ưu tiên** Trung bình

**Mô tả** — Chấm điểm rủi ro khách hàng 0–100 → xếp hạng LOW/MEDIUM/HIGH, **append-only**
(`customer_risk_assessments`): mỗi lần đánh giá là một dòng mới kèm căn cứ (JSONB `reason`), để
giải trình được "tại thời điểm mở tài khoản, khách này được đánh giá thế nào". Hạng hiện hành
đồng bộ về `customers.risk_rating`.

**Luồng chính (chấm tự động sau KYC)**
1. Hệ thống nhận tín hiệu KYC vừa duyệt (nội bộ service).
2. Hệ thống chấm điểm theo bộ tiêu chí tham số hóa: loại khách, nghề nghiệp, quốc tịch, độ đầy đủ
   hồ sơ… (phạm vi đầu: bảng điểm tĩnh).
3. Hệ thống ghi dòng `customer_risk_assessments` (score, rating, reason, assessed_by = NULL).
4. Hệ thống cập nhật `customers.risk_rating` = rating mới.

**Luồng thay thế**
- A1. Risk Officer đánh giá thủ công (override): nhập score/rating + căn cứ; `assessed_by` = user
  của Risk Officer; dòng mới đè hạng hiện hành.
- A2. Hạng chuyển sang HIGH → cảnh báo CSO cân nhắc đình chỉ (CUST-10); các sản phẩm có
  `MAX_RISK_RATING` tự chặn khách này khi mở mới.

**Quy tắc nghiệp vụ**
- BR-CUST-09-1: Không sửa/xóa dòng đánh giá cũ (BR-G6); hạng hiện hành = dòng mới nhất.
- BR-CUST-09-2: `reason` bắt buộc ghi đủ căn cứ tính điểm (input từng tiêu chí) — phục vụ giải trình.
- BR-CUST-09-3: Đổi rating phải phát tín hiệu cho eligibility (rating nằm trong payload event
  `customer.kyc.approved.v1` / `customer.status.changed.v1`).

**Dữ liệu** — Bảng: `customer.customer_risk_assessments`, `customer.customers`.

---

### CUST-10 — Vòng đời hồ sơ: đình chỉ / kích hoạt lại / đóng

**Nhóm/Service/GĐ** B / customer-service / GĐ2 · **Actor** CSO (đề xuất), Admin (phê duyệt đóng) · **Trigger** Nghi gian lận, lệnh cơ quan, khách yêu cầu chấm dứt quan hệ · **Ưu tiên** Cao

**Mô tả** — Điều khiển máy trạng thái CIF (bảng đầu chương). Trạng thái CIF là **nguồn phát** cho
việc phong tỏa tài khoản bên core-banking: đình chỉ khách → core-banking nghe event và FROZEN mọi
tài khoản của khách đó (ACCT-05).

**Luồng chính (đình chỉ)**
1. CSO chọn CIF ACTIVE, nhập lý do đình chỉ.
2. Hệ thống đặt `status = SUSPENDED`; ghi audit.
3. Hệ thống phát `customer.status.changed.v1` (payload: customer_id, old_status, new_status, lý
   do phân loại, danh sách user_id liên quan).
4. core-banking tiêu thụ event → phong tỏa tài khoản (ACCT-05); notification báo khách.

**Luồng thay thế**
- A1. Kích hoạt lại: SUSPENDED → ACTIVE (lý do gỡ); event tương ứng → core-banking gỡ phong tỏa
  các tài khoản bị FROZEN *bởi lý do khách bị đình chỉ* (không gỡ FROZEN do lệnh cơ quan trực tiếp
  trên tài khoản).
- A2. Đóng hồ sơ: điều kiện — mọi tài khoản của khách đã CLOSED (kiểm qua core-banking); Admin phê
  duyệt; `status = CLOSED` vĩnh viễn; user liên kết bị DISABLED nếu không còn CIF nào khác.
- E-A2. Còn tài khoản chưa đóng → từ chối, trả danh sách tài khoản còn mở.

**Quy tắc nghiệp vụ**
- BR-CUST-10-1: CLOSED là trạng thái cuối, không đảo ngược; muốn quay lại làm khách hàng → mở CIF mới.
- BR-CUST-10-2: Không DELETE hồ sơ (FK từ bảng bằng chứng tuân thủ cưỡng chế); yêu cầu xóa dữ liệu
  cá nhân là quy trình phê duyệt riêng, ngoài phạm vi.
- BR-CUST-10-3: Đình chỉ có hiệu lực nghiệp vụ ngay khi event được tiêu thụ; SLA lan truyền ≤ 1 phút.

**Dữ liệu** — Bảng: `customer.customers`, `customer.outbox`.

---

### CUST-11 — Liên kết hồ sơ với người dùng online

**Nhóm/Service/GĐ** B / customer-service / GĐ2 · **Actor** Teller · **Trigger** Khách mở tại quầy muốn dùng kênh online · **Ưu tiên** Trung bình

**Mô tả** — Gắn `customers.user_id` cho CIF được mở tại quầy (user_id NULL). Khách tự đăng ký user
(AUTH-01) rồi ra quầy/hoặc qua luồng định danh online để gắn.

**Luồng chính**
1. Khách cung cấp username + giấy tờ định danh tại quầy.
2. Teller tra CIF theo giấy tờ, xác minh chính chủ.
3. Hệ thống kiểm user tồn tại, ACTIVE, chưa gắn CIF cá nhân nào khác (BR-CUST-01-3).
4. Hệ thống đặt `customers.user_id`; ghi audit.
5. Từ đây user đăng nhập thấy hồ sơ + tài khoản của CIF này.

**Luồng ngoại lệ**
- E3a. User đã gắn CIF khác → từ chối.
- E3b. CIF đã có user khác → quy trình ĐỔI user (gỡ + gắn) yêu cầu phê duyệt CSO.

**Quy tắc nghiệp vụ** — BR-CUST-11-1: Gắn/gỡ user là thao tác nhạy cảm: bắt buộc xác minh chính
chủ và ghi audit đầy đủ (đây là đường chiếm đoạt tài khoản nếu lỏng).

**Dữ liệu** — Bảng: `customer.customers`.

---

### CUST-12 — Tra cứu hồ sơ khách hàng 360°

**Nhóm/Service/GĐ** B / customer-service / GĐ2 · **Actor** Teller, CSO, Risk Officer; Khách hàng (hồ sơ của mình) · **Trigger** Cần xem hồ sơ · **Ưu tiên** Trung bình

**Mô tả** — Một màn hình/API tổng hợp: thông tin chung + chi tiết theo loại + giấy tờ + liên hệ +
địa chỉ hiện hành + trạng thái KYC (mức, hạn) + hạng rủi ro + (tham chiếu) danh sách tài khoản từ
core-banking.

**Luồng chính**
1. Actor tìm theo: số CIF / số giấy tờ / tên + ngày sinh / mã số thuế / username.
2. Hệ thống trả danh sách khớp (phân trang); actor chọn một hồ sơ.
3. Hệ thống trả hồ sơ 360°; phần tài khoản gọi API core-banking theo customer_id (tham chiếu mềm).
4. Khách hàng online: bỏ bước tìm — luôn là hồ sơ gắn user đang đăng nhập.

**Quy tắc nghiệp vụ**
- BR-CUST-12-1: Kết quả che bớt dữ liệu theo vai trò: Teller thấy đủ; Risk thấy thêm lịch sử đánh
  giá; khách chỉ thấy hồ sơ của mình, số giấy tờ che một phần.
- BR-CUST-12-2: Mọi lần tra cứu của nhân viên ghi audit (chống tò mò dữ liệu khách).

**Dữ liệu** — Đọc các bảng schema customer + API core-banking.
