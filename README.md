# bank-platform

Monorepo core banking dùng để học nghiệp vụ ngân hàng bằng cách tự xây nó. Spring Boot 4.1 · Java 21 · PostgreSQL 17.

**Đây là base project: không có code nghiệp vụ.** Toàn repo có 6 main class + code nghiệp vụ tăng dần theo feature. Cấu trúc package đã dựng sẵn và rỗng; database đã thiết kế đầy đủ.

## Cấu trúc

| Module | Vai trò | Cổng | Schema |
|---|---|---|---|
| `platform-libs/` | [javalibs](https://github.com/tanvx-training/javalibs-4.1) nhúng nguyên vẹn — **không sửa** | | |
| `bank-common/` | Value object nghiệp vụ, hợp đồng event, hằng số | | |
| `services/gateway-service` | Định tuyến tập trung | 8080 | — |
| `services/auth-service` | Định danh, token | 8081 | `auth` |
| `services/customer-service` | CIF, KYC, đánh giá rủi ro | 8082 | `customer` |
| `services/product-service` | Lãi suất, phí, hạn mức, ánh xạ GL | 8083 | `product` |
| `services/core-banking-service` | Sổ cái bút toán kép, tài khoản, chuyển tiền | 8084 | `core_banking` |
| `services/notification-service` | Nghe event, gửi thông báo | 8085 | `notification` |

## Bắt đầu

```bash
docker compose up -d
mvn clean install
```

Lần build đầu đi qua cả javalibs (khoảng 40 artifact). Những lần sau, khi javalibs đã nằm trong local repo:

```bash
mvn -P'!with-libs' clean install
```

Chạy một service:

```bash
mvn -pl services/core-banking-service spring-boot:run -Dspring-boot.run.profiles=local
```

## Database

**`docs/database/schema.sql` là nguồn sự thật duy nhất.** 5 schema, 42 bảng, tự chứa phần tạo schema/user/quyền nên `compose.yaml` mount thẳng vào `docker-entrypoint-initdb.d`.

Sửa file đó xong phải dựng lại từ đầu — script initdb chỉ chạy khi data directory còn rỗng:

```bash
docker compose down -v && docker compose up -d postgres
```

`db/migration/` của các service đang **rỗng** và `spring.flyway.enabled=false`. Khi bắt tay vào một service, cắt khối schema của nó từ `schema.sql` thành migration Flyway đầu tiên rồi bật lên.

Đọc phần đầu `schema.sql` để hiểu 9 nguyên tắc thiết kế và 4 quyết định lớn. Bản thiết kế cũ nằm ở `docs/legacy/` kèm giải thích cái gì đã đổi.

## Frontend dashboard

Dashboard dev hiển thị thông tin 6 service (`frontend/`, React + Vite):

```bash
# backend phải chạy trước: docker compose up -d rồi bật các service
cd frontend && npm install && npm run dev
```

Mở http://localhost:5173. Mỗi service có API `GET .../info` công khai
(permit-all — chưa có luồng phát JWT) trả metadata dev: version, cổng, schema,
uptime, trạng thái hạ tầng. Route qua gateway: xem thẻ gateway trên dashboard.
Lưu ý: bảng dependencies chưa có dòng `kafka` — Boot 4.1 không có health
indicator cho Kafka client thường (xem docs/KNOWN-LIMITATIONS.md).

## Hai mức cấu trúc service

| Mức | Dùng cho | Package |
|---|---|---|
| **A** — DDD + CQRS | `core-banking`, `customer` | `api / application / domain / infrastructure / config` |
| **B** — Layered gọn | `auth`, `product`, `notification` | `web / service / repository / model / config` |

Trong Mức A: **từ 3 aggregate trở lên thì chia `domain/` và `application/` theo aggregate trước, theo loại sau** (`core-banking` chia; `customer` giữ phẳng).

Chi tiết ở `platform-libs/docs/project-structure.md`.

## Tài liệu

- Thiết kế: `docs/superpowers/specs/2026-08-06-bank-platform-base-design.md`
- Kế hoạch triển khai: `docs/superpowers/plans/2026-08-06-bank-platform-base.md`
- javalibs: `platform-libs/docs/index.md`
