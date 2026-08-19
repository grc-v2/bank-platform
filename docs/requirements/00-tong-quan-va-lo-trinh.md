# 00 — Tổng quan, phân nhóm chức năng và lộ trình thực hiện

## 1. Bối cảnh và phạm vi

### 1.1. Dự án là gì

`bank-platform` là một **core banking tiền gửi (deposit-side) cho ngân hàng bán lẻ**, xây theo
kiến trúc microservice: 6 service, mỗi service một schema PostgreSQL riêng, giao tiếp bất đồng bộ
qua event (transactional outbox → Kafka). Trái tim hệ thống là **sổ cái bút toán kép** đúng chuẩn
kế toán ngân hàng: mọi dịch chuyển tiền là một bút toán cân Nợ/Có, append-only, đối chiếu được.

### 1.2. Trong phạm vi (in-scope)

| Mảng nghiệp vụ | Ghi chú |
|---|---|
| Định danh, phiên đăng nhập, phân quyền | Người dùng online + người dùng nội bộ (teller, CSO, risk, admin) |
| Hồ sơ khách hàng (CIF), KYC, đánh giá rủi ro | Cá nhân + tổ chức, KYC 3 mức, có hạn hiệu lực |
| Danh mục sản phẩm tiền gửi | Tài khoản thanh toán (CA), tiết kiệm không kỳ hạn (SA), tiền gửi có kỳ hạn (TD) |
| Chính sách giá là dữ liệu | Lãi suất bậc thang, biểu phí, hạn mức, điều kiện mở, ánh xạ GL — tất cả có hiệu lực theo thời gian |
| Tài khoản khách hàng | Mở/đóng, đồng sở hữu, phong tỏa, hold, sao kê |
| Sổ cái & hạch toán | Chart of accounts, posting engine bút toán kép, bút toán đảo, snapshot, đối chiếu |
| Chuyển tiền | Nội bộ (nguyên tử) + liên ngân hàng đi/đến (saga qua tài khoản trung gian GL 1900) |
| Lãi và phí | Dự thu lãi hằng ngày, trả lãi định kỳ, đáo hạn TD, thu phí theo sự kiện/định kỳ, miễn phí |
| Thông báo | Đa kênh (Telegram/Email/Webhook), template, retry, tùy chọn nhận |
| Vận hành & tuân thủ | Outbox, audit log, lịch cuối ngày (EOD), đối chiếu, giám sát |

### 1.3. Ngoài phạm vi (out-of-scope) — có chủ đích

Các quyết định này khắc trong thiết kế DB, không phải "chưa kịp làm":

- **Không FX / đa tiền tệ trong một giao dịch.** Một tài khoản một loại tiền; bút toán không trộn
  loại tiền (nguyên tắc 3 của schema). Mở rộng FX là thay đổi nền tảng, xem [chương 10](10-chan-troi-mo-rong.md).
- **Không tín dụng (cho vay), không thẻ, không chứng khoán/bảo hiểm.** Hold đã chừa sẵn lý do
  `CARD_AUTH` cho tương lai, nhưng phát hành thẻ nằm ngoài phạm vi.
- **Không kênh giao diện khách hàng cuối** (mobile app/internet banking UI). Frontend hiện tại là
  dashboard vận hành dev. Hệ thống expose API qua gateway để kênh nào cũng cắm vào được.
- **Không tích hợp thật với NAPAS/CITAD** — đối tác liên ngân hàng được trừu tượng hóa thành
  "partner" có API confirm/reject, đủ để mô phỏng đúng saga và đối soát.

## 2. Bức tranh chức năng — phân nhóm

9 nhóm chức năng, 64 chức năng. Mã nhóm dùng làm tiền tố mã chức năng.

### Nhóm A — Định danh & truy cập (`auth-service`, `gateway-service`) — 9 chức năng

| Mã | Chức năng | Actor chính |
|---|---|---|
| AUTH-01 | Đăng ký người dùng | Khách hàng |
| AUTH-02 | Đăng nhập & phát hành token | Người dùng |
| AUTH-03 | Làm mới phiên (refresh token rotation) | Hệ thống kênh |
| AUTH-04 | Đăng xuất & thu hồi phiên | Người dùng |
| AUTH-05 | Đổi mật khẩu | Người dùng |
| AUTH-06 | Quản trị người dùng (khóa / mở khóa / vô hiệu) | Admin |
| AUTH-07 | Quản lý vai trò | Admin |
| AUTH-08 | Giám sát đăng nhập & phát hiện dò tài khoản | Risk Officer |
| AUTH-09 | Xác thực & định tuyến tại gateway | Hệ thống |

### Nhóm B — Khách hàng & KYC (`customer-service`) — 12 chức năng

| Mã | Chức năng | Actor chính |
|---|---|---|
| CUST-01 | Mở hồ sơ khách hàng cá nhân | Teller / Khách hàng |
| CUST-02 | Mở hồ sơ khách hàng tổ chức | Teller |
| CUST-03 | Cập nhật liên hệ & địa chỉ (có lịch sử hiệu lực) | Teller / Khách hàng |
| CUST-04 | Quản lý giấy tờ định danh | Teller |
| CUST-05 | Xác minh kênh liên hệ (OTP) | Khách hàng |
| CUST-06 | Nộp hồ sơ KYC | Khách hàng / Teller |
| CUST-07 | Thẩm định & phê duyệt KYC | CSO |
| CUST-08 | Theo dõi hiệu lực KYC & tái KYC | Hệ thống |
| CUST-09 | Đánh giá rủi ro khách hàng | Risk Officer / Hệ thống |
| CUST-10 | Vòng đời hồ sơ: đình chỉ / kích hoạt lại / đóng | CSO / Admin |
| CUST-11 | Liên kết hồ sơ với người dùng online | Teller |
| CUST-12 | Tra cứu hồ sơ khách hàng 360° | Teller / CSO |

### Nhóm C — Sản phẩm & chính sách giá (`product-service`) — 7 chức năng

| Mã | Chức năng | Actor chính |
|---|---|---|
| PROD-01 | Vòng đời sản phẩm: tạo / kích hoạt / ngừng bán | Product Admin |
| PROD-02 | Quản lý lãi suất (bậc thang, kỳ hạn, hiệu lực thời gian) | Product Admin |
| PROD-03 | Quản lý biểu phí | Product Admin |
| PROD-04 | Quản lý hạn mức giao dịch | Product Admin |
| PROD-05 | Quản lý điều kiện mở sản phẩm | Product Admin |
| PROD-06 | Quản lý ánh xạ GL | Product Admin |
| PROD-07 | Cung cấp catalog cho kênh & service khác | Hệ thống |

### Nhóm D — Sổ cái & hạch toán (`core-banking-service`) — 5 chức năng

| Mã | Chức năng | Actor chính |
|---|---|---|
| GL-01 | Quản lý hệ thống tài khoản kế toán (chart of accounts) | Kế toán trưởng |
| GL-02 | Ghi bút toán kép (posting engine) | Hệ thống |
| GL-03 | Bút toán đảo | Hệ thống / Kế toán |
| GL-04 | Chốt số dư cuối ngày (snapshot) | Hệ thống |
| GL-05 | Đối chiếu sổ cái — sổ phụ | Hệ thống / Kế toán |

### Nhóm E — Tài khoản tiền gửi (`core-banking-service`) — 8 chức năng

| Mã | Chức năng | Actor chính |
|---|---|---|
| ACCT-01 | Mở tài khoản thanh toán / tiết kiệm | Teller / Khách hàng |
| ACCT-02 | Mở tiền gửi có kỳ hạn | Khách hàng |
| ACCT-03 | Đồng chủ tài khoản & người được ủy quyền | Teller |
| ACCT-04 | Truy vấn số dư & thông tin tài khoản | Khách hàng |
| ACCT-05 | Phong tỏa & quản lý trạng thái tài khoản | CSO / Hệ thống |
| ACCT-06 | Quản lý khoản treo (hold) | Hệ thống / CSO |
| ACCT-07 | Đóng tài khoản / tất toán | Teller / Khách hàng |
| ACCT-08 | Sao kê & lịch sử giao dịch | Khách hàng |

### Nhóm F — Chuyển tiền & thanh toán (`core-banking-service`) — 6 chức năng

| Mã | Chức năng | Actor chính |
|---|---|---|
| TRF-01 | Chuyển tiền nội bộ | Khách hàng |
| TRF-02 | Chuyển tiền liên ngân hàng đi (saga) | Khách hàng |
| TRF-03 | Nhận tiền liên ngân hàng đến | Hệ thống |
| TRF-04 | Kiểm soát hạn mức giao dịch (velocity check) | Hệ thống |
| TRF-05 | Xử lý saga treo & quá hạn | Hệ thống |
| TRF-06 | Tra soát & hoàn trả giao dịch | CSO / Kế toán |

### Nhóm G — Lãi & phí (`core-banking-service` + chính sách từ `product-service`) — 6 chức năng

| Mã | Chức năng | Actor chính |
|---|---|---|
| INT-01 | Dự thu lãi hằng ngày | Hệ thống (EOD) |
| INT-02 | Trả lãi định kỳ | Hệ thống (EOD) |
| INT-03 | Đáo hạn tiền gửi có kỳ hạn | Hệ thống / Khách hàng |
| FEE-01 | Thu phí theo sự kiện giao dịch | Hệ thống |
| FEE-02 | Thu phí duy trì định kỳ | Hệ thống (EOD) |
| FEE-03 | Miễn / giảm phí | CSO |

### Nhóm H — Thông báo & tương tác (`notification-service`) — 6 chức năng

| Mã | Chức năng | Actor chính |
|---|---|---|
| NOTI-01 | Tiêu thụ sự kiện idempotent | Hệ thống |
| NOTI-02 | Quản lý template thông báo | Admin |
| NOTI-03 | Gửi thông báo & retry đa kênh | Hệ thống |
| NOTI-04 | Tùy chọn nhận thông báo | Khách hàng |
| NOTI-05 | Quản lý webhook | Khách hàng (API) |
| NOTI-06 | Lịch sử & giám sát gửi | Admin |

### Nhóm I — Vận hành, đối chiếu & tuân thủ (xuyên suốt) — 5 chức năng

| Mã | Chức năng | Actor chính |
|---|---|---|
| OPS-01 | Phát sự kiện tin cậy (transactional outbox) | Hệ thống |
| OPS-02 | Nhật ký kiểm toán (audit log) | Hệ thống / Auditor |
| OPS-03 | Lịch cuối ngày (EOD orchestration) | Hệ thống |
| OPS-04 | Quản lý partition sổ cái | Hệ thống / DBA |
| OPS-05 | Giám sát & dashboard vận hành | Dev / Ops |

## 3. Thứ tự thực hiện — 7 giai đoạn

Nguyên tắc xếp thứ tự: **(1)** cái bị phụ thuộc làm trước cái phụ thuộc; **(2)** đường đi của một
đồng tiền thật (mở user → có hồ sơ KYC → có sản phẩm → có tài khoản → có giao dịch → có lãi/phí)
chính là đường găng; **(3)** mỗi giai đoạn kết thúc bằng một luồng nghiệp vụ chạy được từ đầu tới
cuối (vertical slice), không kết thúc bằng "xong tầng kỹ thuật".

> Giai đoạn 0 (nền tảng: gateway, schema DB, dashboard, entity + repository 5 service) **đã xong**
> trong repo hiện tại.

| GĐ | Tên | Chức năng | Phụ thuộc / lý do đứng ở đây | Tiêu chí hoàn thành (DoD) |
|---|---|---|---|---|
| 1 | Định danh & truy cập | AUTH-01…09 | Mọi API nghiệp vụ phía sau cần JWT + vai trò. Không có auth thì mọi thứ khác phải mở permit-all | Đăng ký → đăng nhập → gọi API bảo vệ qua gateway → refresh → logout; khóa user thì phiên chết |
| 2 | Khách hàng & KYC | CUST-01…12, NOTI-01/02/03 (tối thiểu) | Mở tài khoản cần CIF ACTIVE + kyc_level; OTP xác minh liên hệ cần notification chạy sớm | Mở CIF → nộp KYC → CSO duyệt → customer ACTIVE, event `customer.kyc.approved.v1` phát ra và notification nhận được |
| 3 | Sản phẩm & chính sách giá | PROD-01…07 | Mở tài khoản cần eligibility + GL mapping; chuyển tiền cần phí + hạn mức; lãi cần bảng lãi suất | Seed 3 sản phẩm quản trị được qua API; đổi lãi suất/biểu phí đúng quy trình đóng-dòng-cũ-trước |
| 4 | Sổ cái & tài khoản | GL-01…03, ACCT-01…08 | Sổ cái trước giao dịch: posting engine là hạ tầng của MỌI dịch chuyển tiền. Mở tài khoản dùng eligibility (GĐ3) + posting (GL-02) | Mở tài khoản (kiểm eligibility thật) → nộp tiền mặt (bút toán OPENING) → số dư đúng, sao kê đúng, đóng tài khoản được |
| 5 | Chuyển tiền | TRF-01…06, NOTI-04/05/06 | Cần tài khoản ACTIVE (GĐ4), phí + hạn mức (GĐ3) | Chuyển nội bộ nguyên tử có phí, chống trùng lệnh; chuyển liên NH đủ 3 kết cục confirm/reject/timeout; biến động số dư báo qua notification |
| 6 | Lãi, phí & cuối ngày | INT-01…03, FEE-01…03, GL-04/05, OPS-03/04 | Cần sổ cái + giao dịch chạy ổn; EOD gom tất cả job định kỳ về một lịch có thứ tự | EOD chạy trọn: nhả hold hết hạn → quét saga → dự thu lãi → thu phí → snapshot → đối chiếu khớp 100% |
| 7 | Vận hành & làm cứng | OPS-02/05 hoàn thiện, AUTH-08, TRF-06, GL-05 nâng cao | Có dữ liệu thật từ GĐ5-6 mới có gì để giám sát, tra soát, đối chiếu | Audit đầy đủ thao tác ghi; dashboard tỉ lệ fail notification; kịch bản tra soát – hoàn trả chạy được |

Ghi chú đường găng: **AUTH → CUST → PROD → (GL + ACCT) → TRF → INT/FEE**. Nhóm H và I không có
giai đoạn riêng — chúng được kéo vào đúng giai đoạn đầu tiên cần đến (NOTI tối thiểu ở GĐ2,
outbox OPS-01 dùng ngay từ GĐ2, EOD ở GĐ6).

## 4. Actor và ma trận phân quyền

Vai trò khớp `auth.user_roles.role`:

| Actor | Vai trò hệ thống | Mô tả |
|---|---|---|
| Khách hàng | `CUSTOMER` | Người dùng online (web/app/API) thao tác trên hồ sơ và tài khoản CỦA MÌNH |
| Giao dịch viên | `TELLER` | Tại quầy: mở hồ sơ, mở tài khoản, nộp/rút tiền mặt, thu thập giấy tờ |
| Chuyên viên dịch vụ KH | `CSO` | Duyệt KYC, phong tỏa, tra soát, miễn phí — các thao tác cần thẩm quyền |
| Cán bộ rủi ro | `RISK_OFFICER` | Đánh giá rủi ro, giám sát đăng nhập/giao dịch bất thường |
| Quản trị viên | `ADMIN` | Quản trị người dùng, vai trò, template, tham số |
| Hệ thống | `SYSTEM` | Batch job, consumer event, saga worker — mọi thao tác không do người bấm |

Ma trận (C = tạo, R = xem, U = sửa, A = phê duyệt, X = thực thi):

| Tài nguyên | CUSTOMER | TELLER | CSO | RISK_OFFICER | ADMIN | SYSTEM |
|---|---|---|---|---|---|---|
| Người dùng, vai trò | R (mình) | — | — | R | CRUA | — |
| Hồ sơ KH, giấy tờ | R/U (mình) | CRU | RU·A (KYC) | R | R | U (status) |
| Đánh giá rủi ro | — | — | R | CR | R | C |
| Sản phẩm, giá, phí, hạn mức | R (catalog) | R | R | R | CRUA | R |
| Tài khoản | R (mình) | CR | RU (phong tỏa) | R | R | U (status, số dư) |
| Chuyển tiền | C (mình) | C (tại quầy) | R·A (tra soát) | R | R | X (saga, đảo) |
| Sổ cái GL, bút toán | — | — | R | R | R·A (COA) | X (posting) |
| Template, webhook, thông báo | RU (của mình) | — | — | — | CRU | X (gửi) |
| Audit log | — | — | R | R | R | C |

## 5. Quy tắc nghiệp vụ toàn cục (BR-G)

Áp cho MỌI chức năng; đặc tả từng chức năng chỉ nhắc lại khi có điểm riêng.

- **BR-G1 — Tiền tệ chính xác tuyệt đối.** Mọi số tiền là `NUMERIC(19,4)`, không bao giờ dùng số
  thực dấu phẩy động; tiền tệ mã ISO-4217. Số tiền trên bút toán luôn **dương**, chiều Nợ/Có nằm ở
  cột `direction`.
- **BR-G2 — Sổ cái append-only.** Không UPDATE/DELETE bút toán. Sai thì ghi bút toán đảo
  (`REVERSAL`) trỏ về bản gốc; một bút toán chỉ được đảo một lần.
- **BR-G3 — Idempotency trên mọi lệnh dịch chuyển tiền.** Client gửi kèm `idempotency_key`;
  gửi lại cùng key phải nhận lại đúng kết quả cũ, không tạo giao dịch thứ hai.
- **BR-G4 — Không FX.** Một tài khoản một loại tiền; một bút toán một loại tiền; loại tiền dòng
  bút toán phải khớp loại tiền tài khoản được hạch toán.
- **BR-G5 — Dữ liệu có hiệu lực thời gian thì thêm dòng, không sửa dòng** (lãi suất, phí, hạn mức,
  GL mapping, địa chỉ). Không có hai dòng cùng hiệu lực chồng lấn. Khi thay đổi: đóng dòng cũ
  (`effective_to`) **trước**, chèn dòng mới **sau** trong cùng transaction.
- **BR-G6 — Bằng chứng tuân thủ không bị xóa.** Hồ sơ KYC, giấy tờ, đánh giá rủi ro, audit log,
  login audit sống sót qua việc đóng hồ sơ/tài khoản. Đóng = đổi trạng thái, không DELETE.
- **BR-G7 — Event-carried state.** Sự kiện phát ra tự đủ dữ liệu cho consumer, phát qua outbox
  trong cùng transaction với nghiệp vụ; consumer xử lý idempotent theo `event_id`.
- **BR-G8 — Mọi thao tác ghi có dấu vết**: ai (actor_user_id, NULL = hệ thống), làm gì, lên tài
  nguyên nào, lúc nào — ghi `audit_log` (nhóm core) hoặc bảng audit tương ứng.
- **BR-G9 — Số hiển thị tách khỏi khóa kỹ thuật.** Số CIF, số tài khoản, số tham chiếu giao dịch
  là mã nghiệp vụ riêng (đổi quy tắc đánh số không đụng khóa ngoại), sinh duy nhất, không tái sử dụng.
- **BR-G10 — Ngày nghiệp vụ tách khỏi thời điểm hệ thống.** `value_date` quyết định tính lãi,
  `booking_date` quyết định kỳ sổ, `TIMESTAMPTZ` cho thời điểm máy.

## 6. Danh mục sự kiện nghiệp vụ (event catalog)

| Sự kiện | Producer | Consumer chính | Phát khi |
|---|---|---|---|
| `customer.kyc.approved.v1` | customer | core-banking, notification | KYC được duyệt, kyc_level tăng (CUST-07) |
| `customer.status.changed.v1` | customer | core-banking (phong tỏa TK), notification | Hồ sơ đổi trạng thái (CUST-10) |
| `product.activated.v1` | product | core-banking, kênh (vô hiệu cache) | Sản phẩm kích hoạt (PROD-01) |
| `product.retired.v1` | product | core-banking, kênh | Sản phẩm ngừng bán (PROD-01) |
| `account.opened.v1` ⁽ᵈ⁾ | core-banking | notification | Tài khoản kích hoạt (ACCT-01/02) |
| `account.status.changed.v1` ⁽ᵈ⁾ | core-banking | notification | Phong tỏa/đóng (ACCT-05/07) |
| `transfer.completed.v1` | core-banking | notification | Chuyển tiền thành công (TRF-01/02/03) |
| `transfer.reversed.v1` | core-banking | notification | Giao dịch bị hoàn (TRF-05/06) |
| `interest.posted.v1` ⁽ᵈ⁾ | core-banking | notification | Trả lãi (INT-02/03) |
| `fee.charged.v1` ⁽ᵈ⁾ | core-banking | notification | Thu phí (FEE-01/02) |

⁽ᵈ⁾ = đề xuất mới trong tài liệu này; các event không đánh dấu đã được ghi nhận trong comment schema.
Chốt danh sách cuối cùng khi triển khai từng giai đoạn.

## 7. Yêu cầu phi chức năng (NFR)

| Mã | Yêu cầu |
|---|---|
| NFR-1 | **Bảo mật xác thực**: mật khẩu băm BCrypt (sẵn sàng nâng Argon2); access token stateless ngắn hạn (≤ 15 phút); refresh token lưu dạng hash, thu hồi được; khóa user = thu hồi mọi refresh token |
| NFR-2 | **Phân quyền**: mọi endpoint nghiệp vụ yêu cầu vai trò tối thiểu theo ma trận §4; khách hàng chỉ chạm được dữ liệu của mình (kiểm ownership ở tầng ứng dụng) |
| NFR-3 | **Toàn vẹn tiền bạc**: bút toán cân Nợ/Có do DB cưỡng chế tại COMMIT; số dư khả dụng không âm quá thấu chi; optimistic lock (`version`) trên accounts/transfers chống ghi đè song song |
| NFR-4 | **Idempotency & at-least-once**: BR-G3 cho lệnh client; consumer Kafka idempotent theo `processed_events`; retry gọi đối tác dùng lại `partner_idempotency_key` |
| NFR-5 | **Khả năng kiểm toán**: mọi thao tác ghi truy vết được 5 câu hỏi ai/làm gì/lên gì/lúc nào/kết quả; sổ cái tái lập được số dư tại mọi thời điểm |
| NFR-6 | **Hiệu năng**: truy vấn số dư đọc từ cột lưu sẵn (không SUM sổ cái); sao kê theo kỳ đi từ snapshot + delta; bảng hàng đợi quét qua partial index; sổ cái partition theo tháng |
| NFR-7 | **Độ bền dữ liệu**: không mất event (outbox), không mất bút toán; EOD chạy lại được (mọi job idempotent theo ngày) |
| NFR-8 | **PII**: ảnh giấy tờ để trên object storage (DB chỉ giữ khóa + checksum SHA-256); không log số giấy tờ/mật khẩu/token; OTP chỉ gửi tới kênh liên hệ đã xác minh |
| NFR-9 | **Quan trắc**: mỗi service expose health/info; số liệu tỉ lệ fail theo kênh notification; cảnh báo khi đối chiếu lệch hoặc outbox ùn |

## 8. Template đặc tả (áp dụng cho mọi chức năng ở chương 01–09)

```markdown
### <MÃ> — <Tên chức năng>
**Nhóm/Service/GĐ** · **Actor** (chính, phụ) · **Trigger** · **Ưu tiên**

**Mô tả** — chức năng làm gì, vì sao tồn tại.
**Tiền điều kiện** — điều phải đúng trước khi luồng bắt đầu.
**Luồng chính** — các bước đánh số; mỗi bước ghi rõ ai làm.
**Luồng thay thế / ngoại lệ** — Ax = rẽ nhánh hợp lệ, Ex = lỗi; đánh số bám bước của luồng chính.
**Hậu điều kiện** — trạng thái hệ thống khi thành công / khi thất bại.
**Quy tắc nghiệp vụ** — BR-<MÃ>-n, đối chiếu ràng buộc DB tương ứng nếu có.
**Dữ liệu** — đầu vào (trường, bắt buộc, validation), đầu ra, bảng liên quan.
**Trạng thái** — bảng chuyển trạng thái (nếu chức năng sở hữu state machine).
**Sự kiện phát ra** — event + thời điểm phát.
**Điểm mở** — chỗ schema/thiết kế hiện tại chưa chốt, cần quyết định khi triển khai.
```

Hướng dẫn dùng cho vẽ sơ đồ:

- **Use case diagram**: mỗi nhóm A–I là một package; actor lấy từ §4; use case là các mã chức năng.
- **Activity/sequence diagram**: vẽ theo *Luồng chính* + *Luồng thay thế*; swimlane = actor + các
  service tham gia (ghi trong từng bước).
- **State diagram**: vẽ theo bảng *Trạng thái* (các bảng này khớp CHECK constraint trong schema).
- **ERD**: đã có sẵn — sinh từ `docs/database/schema.sql`.
