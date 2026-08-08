# customer-service

CIF (Customer Information File): hồ sơ khách hàng cá nhân và tổ chức, giấy tờ tùy thân, địa chỉ, liên hệ, KYC, đánh giá rủi ro.

- **Cổng:** 8082
- **Schema:** `customer` · **DB user:** `customer_svc`
- **Mức cấu trúc: A (DDD + CQRS), bố cục phẳng.**

## Vì sao Mức A nhưng phẳng

Service này có **hai** aggregate: `Customer` (kèm chi tiết, giấy tờ, địa chỉ, liên hệ) và `KycVerification` (kèm tài liệu). Dưới ngưỡng 3 aggregate nên giữ bố cục phẳng `domain/{model,rule,event,port}` đúng như tài liệu javalibs — chia theo aggregate lúc này chỉ tạo thêm thư mục mà không làm rõ thêm điều gì.

So sánh với `core-banking-service` (4 aggregate, chia theo aggregate) để thấy quy tắc: **từ 3 aggregate trở lên mới chia.**

Chọn Mức A chứ không phải B vì KYC là state machine thật, có invariant thật (không thể APPROVED mà thiếu người duyệt, không thể REJECTED mà thiếu lý do), và vì việc duyệt KYC phát domain event mà `core-banking` phải nghe.

## Ba khái niệm đừng nhầm lẫn

| Khái niệm | Ở đâu | Là gì |
|---|---|---|
| **User** | `auth.users` | tài khoản đăng nhập |
| **Customer** | `customer.customers` | con người/tổ chức có quan hệ với ngân hàng |
| **Account** | `core_banking.accounts` | tài khoản ngân hàng chứa tiền |

Một người có thể là customer mà chưa có user (mở tại quầy), có nhiều account, và một account có nhiều customer (đồng sở hữu).

## Bất biến phải bảo vệ trong domain

1. **Không hai khách hàng cùng một giấy tờ.** DB có `uq_ident`, nhưng domain phải báo lỗi nghiệp vụ tử tế trước khi chạm DB.
2. **KYC `APPROVED`/`REJECTED` bắt buộc có `decided_at`; `REJECTED` bắt buộc có lý do.**
3. **`customers.kyc_level` chỉ tăng khi có một `kyc_verifications` APPROVED ở mức đó và chưa hết hạn.**
4. **`INDIVIDUAL` có `individual_details`, `ORGANIZATION` có `organization_details`** — không có cái ngược lại. DB không ràng buộc được điều này (nó ở hai bảng), domain phải giữ.

## Event phát ra

`customer.kyc.approved.v1`, `customer.status.changed.v1` — qua outbox, cùng transaction với thay đổi nghiệp vụ. Payload phải **tự đủ**: consumer không được gọi ngược lại hỏi thêm.

## Chạy local

```bash
docker compose up -d postgres kafka
mvn -pl services/customer-service -am spring-boot:run -Dspring-boot.run.profiles=local
```

## Migration

`db/migration/` rỗng, `spring.flyway.enabled=false`. Schema do `docs/database/schema.sql` khối `[3]` dựng.
