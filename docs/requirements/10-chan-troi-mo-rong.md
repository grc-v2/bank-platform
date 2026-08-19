# 10 — Chân trời mở rộng: các mảng banking ngoài phạm vi hiện tại

Một ngân hàng thật còn nhiều mảng nữa. Chương này liệt kê chúng để bức tranh "banking hoàn
chỉnh" đầy đủ, xếp theo mức độ tự nhiên khi mở rộng từ nền hiện tại, và ghi rõ **điều kiện tiên
quyết** — thứ phải có/phải sửa trong thiết kế hiện tại trước khi làm. Các mục này CHƯA có đặc tả
chi tiết; khi quyết định làm mảng nào, viết bổ sung một chương đặc tả theo đúng template chương 00.

## Vòng 1 — Mở rộng tự nhiên trên nền tiền gửi & chuyển tiền

| Mảng | Nội dung chính | Điều kiện tiên quyết trên nền hiện tại |
|---|---|---|
| **Chuyển tiền định kỳ / tương lai (standing order)** | Đặt lịch chuyển (hằng tháng, ngày cố định), quản lý lệnh chờ, xử lý thiếu số dư | Bảng lệnh định kỳ + job trong EOD; tái dùng trọn TRF-01/02 |
| **Thanh toán hóa đơn & nạp tiền (billing/topup)** | Danh mục nhà cung cấp, truy vấn nợ cước, thanh toán, đối soát nhà cung cấp | Khung đối tác giống TRF-02 (saga + idempotency + đối soát); GL phải thu/phải trả nhà cung cấp |
| **QR thanh toán (VietQR)** | Sinh/đọc QR chuẩn NAPAS, thanh toán bằng QR | TRF-01/02 sẵn dùng; thêm tầng sinh/parse QR |
| **Xác thực giao dịch mạnh (SCA)** | OTP/soft-token/biometric theo ngưỡng giao dịch (QĐ 2345 NHNN) | Điểm mở đã ghi ở TRF-01; cần bảng thiết bị tin cậy + luồng thách thức |
| **Sản phẩm tiết kiệm nâng cao** | Tiết kiệm tích lũy (nộp thêm định kỳ), rút gốc từng phần, lãi bậc thang theo kỳ hạn thực gửi | Nới BR-ACCT-02-1/2; thiết kế lại term_deposit_details |
| **Thấu chi có lãi (overdraft interest)** | Tính lãi trên số dư âm trong hạn mức `overdraft_limit` | INT-01 nhánh số dư âm (đang bỏ qua); GL thu nhập lãi cho vay |

## Vòng 2 — Mảng nghiệp vụ mới, kiến trúc hiện tại chứa được

| Mảng | Nội dung chính | Điều kiện tiên quyết |
|---|---|---|
| **Thẻ (card issuing)** | Phát hành thẻ ghi nợ, kích hoạt/khóa, hạn mức thẻ, authorization–clearing–settlement | Hold `CARD_AUTH` đã chừa sẵn; cần card-service mới + tích hợp switch; luồng auth/capture dùng ACCT-06 |
| **Cho vay (lending)** | Khởi tạo khoản vay, thẩm định, giải ngân, lịch trả nợ, dự thu lãi vay, nhóm nợ, dự phòng | Service mới + nhóm GL 1xxx cho vay/4xxx lãi vay; tái dùng posting engine, product-service (biểu lãi vay), CUST (thẩm định) |
| **AML/CFT giám sát giao dịch** | Sàng lọc danh sách (sanction/PEP), luật phát hiện giao dịch đáng ngờ, hồ sơ STR/CTR | Nền risk (CUST-09) + event stream giao dịch đã có; cần rule engine + case management |
| **Báo cáo cơ quan quản lý** | Báo cáo NHNN (TT35 và các chế độ báo cáo), dự trữ bắt buộc, bảo hiểm tiền gửi | Kho dữ liệu báo cáo tách khỏi DB giao dịch (đọc từ snapshot + sổ cái) |
| **Kênh khách hàng cuối** | Mobile app / Internet banking đầy đủ (đăng ký eKYC, quản lý thiết bị, push notification) | API đã sẵn qua gateway; cần app + device management + push channel thật thay Telegram |

## Vòng 3 — Đụng vào nền tảng (thay đổi nguyên tắc thiết kế)

| Mảng | Nội dung chính | Vì sao đụng nền |
|---|---|---|
| **Đa tiền tệ & FX** | Tài khoản ngoại tệ, mua bán ngoại tệ, trạng thái ngoại hối, đánh giá lại tỷ giá | Phá nguyên tắc 3 của schema (một bút toán một loại tiền): cần cặp bút toán qua GL position từng loại tiền + bảng tỷ giá — sửa trigger cân đối, KHÔNG "nới" mà thiết kế lại có chủ đích |
| **Đối tác thanh toán thật (NAPAS/CITAD/SWIFT)** | Chuẩn điện (ISO 8583/ISO 20022), phiên quyết toán, đối soát file, tranh chấp theo quy chế | Trừu tượng "partner" hiện tại phải cụ thể hóa từng rail; GL 1900 tách theo rail |
| **Sổ cái đa chi nhánh & liên chi nhánh** | Hạch toán theo chi nhánh, điều chuyển vốn nội bộ | Thêm chiều branch vào GL + bút toán; ảnh hưởng mọi báo cáo |
| **Ngân hàng mở (Open Banking)** | API chuẩn cho bên thứ ba, đồng ý dữ liệu (consent), OAuth2 | Consent management + phân quyền theo scope — mở rộng lớn của nhóm A |

## Nguyên tắc khi mở rộng

1. Mảng mới đi qua đúng khung đã có: nghiệp vụ là dữ liệu (product-service), tiền đi qua posting
   engine (GL-02), event qua outbox, consumer idempotent.
2. Mảng nào phá một nguyên tắc thiết kế của schema (đầu file `schema.sql`) thì sửa nguyên tắc
   TRƯỚC — có chủ đích, có ghi chép — rồi mới viết code.
3. Mỗi mảng bắt đầu bằng một chương đặc tả mới theo template chương 00 §8, nối vào lộ trình như
   một giai đoạn 8+.
