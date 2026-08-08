# core-banking-service

Sổ cái bút toán kép, tài khoản khách hàng, hold, chuyển tiền nội bộ và liên ngân hàng, lãi và phí.

- **Cổng:** 8084
- **Schema:** `core_banking` · **DB user:** `core_svc`
- **Mức cấu trúc: A (DDD + CQRS), chia theo aggregate.**

## Chiều phụ thuộc giữa package

```
api ──────►  application  ──────►  domain
                  ▲                   ▲
                  └── infrastructure ─┘   (implement port của domain)
```

- `domain` **không import gì** ngoài JDK, `javalibs-ddd-core`, `javalibs-internal`, `bank-common`. Không Spring, không Kafka. Nhờ vậy unit test domain chạy bằng mili-giây.
- `application` gọi domain + port, đánh dấu transaction, **không** biết HTTP.
- `api` chỉ chuyển đổi HTTP ⇄ command/query, **không** chứa nghiệp vụ.
- `infrastructure` là nơi duy nhất biết JPA/Kafka/RestClient.
- **Không package nào import `api`.**

## Vì sao chia theo aggregate

Tài liệu javalibs minh họa `domain/{model,event,rule}` phẳng — đúng cho ví dụ chỉ có một aggregate. Service này có **bốn**: `Account` (kèm `Hold`), `JournalEntry` (kèm `GLAccount`), `Transfer` (kèm saga `ExternalTransfer`), và các value object dùng chung. Để phẳng thì `domain/model/` sẽ chứa khoảng 20 class trộn lẫn và ranh giới aggregate — thứ quan trọng nhất khi làm DDD — biến mất khỏi cấu trúc thư mục.

**Quy tắc chung của repo: từ 3 aggregate trở lên thì chia `domain/` và `application/` theo aggregate trước, theo loại sau.** Dưới ngưỡng đó giữ bố cục phẳng (xem `customer-service`).

## JPA và domain model

Chọn hướng **thực dụng**: gắn `@Entity`/`@Table` trực tiếp lên aggregate trong `domain/<aggregate>/model`, repository port `extends JpaRepository`. Đổi lại `domain` có dependency JPA — chấp nhận được, và dùng được ngay `javalibs-search`.

Hướng này áp dụng cho **toàn bộ** service. Đừng trộn với hướng thuần khiết (entity riêng + mapper hai chiều) trong cùng một codebase.

## Bất biến phải bảo vệ trong domain

1. **Tổng Nợ = tổng Có** trong mỗi bút toán. DB đã có constraint trigger chặn ở lớp cuối, nhưng domain phải chặn trước — lỗi phát hiện tại COMMIT là lỗi phát hiện quá muộn để báo cho người dùng tử tế.
2. **Số dư khả dụng không âm quá `overdraft_limit`.** Kiểm trên `available_balance` (đã trừ hold), không phải `ledger_balance`.
3. **Hold không vượt quá số dư khả dụng** tại thời điểm đặt.
4. **Sổ cái append-only.** Sai thì ghi bút toán đảo, không UPDATE, không DELETE.
5. **`accounts.primary_customer_id` khớp dòng `PRIMARY` trong `account_holders`.** DB giữ được "chỉ một PRIMARY", không giữ được "bằng nhau" — đây là việc của domain.

## Phụ thuộc sang service khác

- `product-service`: đọc biểu phí, lãi suất, hạn mức, và **`product_gl_mappings`** để biết hạch toán vào GL nào. Gọi qua `infrastructure/client`, bọc circuit breaker.
- `customer-service`: nghe `customer.status.changed.v1` để phong tỏa tài khoản khi khách bị đình chỉ. Xử lý trong `application/event`, idempotent qua bảng `processed_events`.

## Chạy local

```bash
docker compose up -d postgres kafka
mvn -pl services/core-banking-service -am spring-boot:run -Dspring-boot.run.profiles=local
```

## Migration

`db/migration/` rỗng, `spring.flyway.enabled=false`. Schema do `docs/database/schema.sql` khối `[5a]`–`[5c]` dựng.
