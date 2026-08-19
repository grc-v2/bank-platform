# Đặc tả yêu cầu nghiệp vụ — bank-platform

Bộ tài liệu Business Requirement cho toàn bộ chức năng của dự án. Viết theo góc nhìn BA:
mỗi chức năng là một use case đầy đủ (actor, luồng, quy tắc, dữ liệu, trạng thái) để từ đó
**vẽ được sơ đồ** (use case / activity / sequence / state) và **triển khai được** mà không phải đoán.

## Cách đọc

| File | Nội dung |
|---|---|
| [00-tong-quan-va-lo-trinh.md](00-tong-quan-va-lo-trinh.md) | Phạm vi, phân nhóm chức năng, thứ tự thực hiện, actor, quy tắc toàn cục, danh mục sự kiện, NFR, **template đặc tả** |
| [01-dinh-danh-truy-cap.md](01-dinh-danh-truy-cap.md) | Nhóm A — AUTH-01…09 (auth-service, gateway-service) |
| [02-khach-hang-kyc.md](02-khach-hang-kyc.md) | Nhóm B — CUST-01…12 (customer-service) |
| [03-san-pham.md](03-san-pham.md) | Nhóm C — PROD-01…07 (product-service) |
| [04-so-cai-hach-toan.md](04-so-cai-hach-toan.md) | Nhóm D — GL-01…05 (core-banking-service) |
| [05-tai-khoan.md](05-tai-khoan.md) | Nhóm E — ACCT-01…08 (core-banking-service) |
| [06-chuyen-tien.md](06-chuyen-tien.md) | Nhóm F — TRF-01…06 (core-banking-service) |
| [07-lai-va-phi.md](07-lai-va-phi.md) | Nhóm G — INT-01…03, FEE-01…03 (core-banking-service) |
| [08-thong-bao.md](08-thong-bao.md) | Nhóm H — NOTI-01…06 (notification-service) |
| [09-van-hanh-doi-chieu.md](09-van-hanh-doi-chieu.md) | Nhóm I — OPS-01…05 (xuyên suốt) |
| [10-chan-troi-mo-rong.md](10-chan-troi-mo-rong.md) | Các mảng nghiệp vụ ngân hàng NGOÀI phạm vi hiện tại và điều kiện tiên quyết khi mở rộng |

## Nguyên tắc biên soạn

1. **`docs/database/schema.sql` là nguồn sự thật.** Mọi trạng thái, ràng buộc, enum trong đặc tả
   khớp nguyên văn với schema. Chỗ nào nghiệp vụ cần mà schema chưa có, đặc tả ghi rõ ở mục *Điểm mở*
   — không bịa cột, không giả định ngầm.
2. **Mỗi chức năng một mã duy nhất** (`TRF-01`), mỗi quy tắc nghiệp vụ một mã (`BR-TRF-01-1`).
   Sơ đồ, test case, task triển khai tham chiếu bằng các mã này.
3. Luồng viết dạng đánh số từng bước, mỗi bước rõ **ai làm** — chuyển thẳng thành activity/sequence
   diagram. Máy trạng thái viết dạng bảng chuyển trạng thái — chuyển thẳng thành state diagram.
