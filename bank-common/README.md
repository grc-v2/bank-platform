# bank-common

Những thứ **cả nhiều service đều cần** và **javalibs không thể chứa** (vì javalibs là hạ tầng chung cho mọi hệ sinh thái, nó không biết gì về ngân hàng).

## Được phép nằm ở đây

| Package | Nội dung | Ví dụ |
|---|---|---|
| `type/` | Value object nghiệp vụ, immutable, `record` hoặc final class | `Money`, `Currency`, `AccountNumber`, `CustomerNumber`, `LedgerDirection` |
| `event/<domain>/` | Hợp đồng event — `record` payload mà publisher và consumer phải hiểu giống nhau | `TransferCompletedV1`, `CustomerKycApprovedV1` |
| `constant/` | Tên topic Kafka, prefix mã lỗi, tên header | `Topics`, `ErrorCodePrefix`, `HeaderNames` |

## KHÔNG được nằm ở đây

1. **Tiện ích chuỗi/ngày/kiểm tra tham số.** Đã có `javalibs-internal`: `Strings`, `Dates`, `Checks`, `Ids`. Viết lại là tạo hai nguồn sự thật.
2. **JPA entity.** Entity thuộc về service sở hữu bảng đó. Chia sẻ entity là chia sẻ schema, và schema là thứ mỗi service phải được tự do đổi.
3. **REST DTO / client DTO.** Request/response là hợp đồng của một API cụ thể, thuộc `api/dto` của service đó.
4. **Spring bean, annotation Spring, `@Component`, `@ConfigurationProperties`.** Module này không có dependency Spring và phải giữ như vậy.

## Vì sao siết chặt như vậy

Mỗi class ở đây là một điểm coupling: sửa nó là sáu service phải build lại. Module `common` không có kỷ luật sẽ thành bãi rác trong vài tháng, và khi đó không ai dám xóa gì khỏi nó nữa.

Quy tắc thực dụng: **nếu chỉ hai service dùng, đừng đưa vào đây** — copy sang cả hai. Chỉ thăng lên `bank-common` khi cái thứ ba cần tới.

## Versioning hợp đồng event

Tên class mang số phiên bản (`TransferCompletedV1`). Đổi kiểu phá vỡ tương thích thì **thêm `V2`**, giữ `V1` cho tới khi mọi consumer chuyển xong. Sửa tại chỗ `V1` là làm hỏng consumer đang chạy.
