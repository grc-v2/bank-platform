# bank-common

Những thứ **nhiều service đều cần** và **không thuộc về riêng service nào**.

Module này **không có dependency compile nào** — Java thuần, không Spring,
không JPA, không Jackson. Hai dependency ở `pom.xml` đều là `scope test`.

## Được phép nằm ở đây

| Package | Nội dung | Ví dụ |
|---|---|---|
| `type/` | Value object nghiệp vụ, immutable, `record` hoặc final class | `Money`, `Currency`, `AccountNumber`, `CustomerNumber` |
| `event/<domain>/` | Hợp đồng event — `record` payload mà publisher và consumer phải hiểu giống nhau | `TransferCompletedV1`, `CustomerKycApprovedV1` |
| `constant/` | Tên topic Kafka, prefix mã lỗi, tên header | `Topics`, `ErrorCodePrefix`, `HeaderNames` |
| `ddd/` | Lớp nền mô hình miền, Java thuần, không annotation | `Entity`, `AggregateRoot` |
| `web/` | Hợp đồng envelope dùng chung cho mọi API | `ApiResponse` |

## KHÔNG được nằm ở đây

1. **JPA entity.** Entity thuộc về service sở hữu bảng đó. Chia sẻ entity là
   chia sẻ schema, và schema là thứ mỗi service phải được tự do đổi.
2. **REST DTO của một API cụ thể.** Request/response là hợp đồng của một API,
   thuộc `api/dto` hoặc `web/dto` của service đó. `ApiResponse` là ngoại lệ
   có chủ đích: nó là *hình dạng bao ngoài* dùng chung, không phải payload.
3. **Spring bean, annotation Spring, `@Component`, `@ConfigurationProperties`.**
   Module này không có dependency Spring và phải giữ như vậy.
4. **Tiện ích chuỗi/ngày/kiểm tra tham số.** Dùng `java.util.Objects`,
   `java.time`, `String` của JDK trước. Chỉ thêm khi JDK thật sự không có.

## Vì sao siết chặt như vậy

Mỗi class ở đây là một điểm coupling: sửa nó là sáu module phải build lại.
Module `common` không có kỷ luật sẽ thành bãi rác trong vài tháng, và khi đó
không ai dám xoá gì khỏi nó nữa.

Quy tắc thực dụng: **nếu chỉ hai service dùng, đừng đưa vào đây** — copy sang
cả hai. Chỉ thăng lên `bank-common` khi cái thứ ba cần tới.

## Versioning hợp đồng event

Tên class mang số phiên bản (`TransferCompletedV1`). Đổi kiểu phá vỡ tương
thích thì **thêm `V2`**, giữ `V1` cho tới khi mọi consumer chuyển xong. Sửa tại
chỗ `V1` là làm hỏng consumer đang chạy.

## Lịch sử

Trước 2026-09-01, ba lớp `ddd/Entity`, `ddd/AggregateRoot`, `web/ApiResponse`
nằm ở thư viện ngoài `platform-libs` (javalibs). Thư viện đó đã bị gỡ khỏi repo
để chủ dự án tự viết lại phần hạ tầng. Xem bản cũ:
`git show b095cd5:platform-libs/javalibs-ddd/...`
