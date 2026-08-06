# Thiết kế base project — bank-platform

- **Ngày**: 2026-08-06
- **Trạng thái**: đã được duyệt qua brainstorming, chờ chuyển sang implementation plan
- **Phạm vi**: dựng khung monorepo Spring Boot multi-module + thiết kế database hoàn chỉnh. **Không** viết code nghiệp vụ.

---

## 1. Mục tiêu

Tạo một base project để học nghiệp vụ ngân hàng lõi thông qua việc tự xây dựng nó, gồm:

1. Monorepo Maven multi-module chạy được ngay sau khi clone.
2. `javalibs-4.1` nhúng nguyên vẹn làm một module trong repo.
3. Năm service nghiệp vụ + một gateway + một module `bank-common`, **chỉ có cấu trúc package rỗng**.
4. Một file SQL tổng hợp, chi tiết, có chú giải nghiệp vụ — là nguồn sự thật duy nhất của database.
5. Hạ tầng local bằng Docker Compose, git repo + CI.

### Không nằm trong phạm vi

- Mọi code nghiệp vụ: entity, repository, controller, service, DTO, mapper.
- Mọi Flyway migration (`db/migration/` để rỗng).
- Mọi test.
- Kafka topic definition, consumer, outbox publisher wiring.
- Route thật của gateway.
- Nghiệp vụ thẻ (card), tín dụng (loan), ngoại hối (FX), báo cáo (reporting) — để dành cho vòng sau.

---

## 2. Bối cảnh đầu vào

`docs/` hiện có 6 file SQL dạng "đáp án mẫu" theo lộ trình M1–M6:

| File | Schema | Nội dung |
|---|---|---|
| `01-init-schemas.sql` | — | 3 schema + 3 DB user + revoke public |
| `V1__auth_init.sql` | auth | users, user_roles, refresh_tokens, login_audit |
| `V2__ownership_and_audit.sql` | core_banking | thêm `accounts.owner_user_id`, `audit_log` |
| `V3__outbox_and_external.sql` | core_banking | outbox, external_transfers (saga) |
| `V4__ledger_partition.sql` | core_banking | partition `ledger_entries` theo tháng |
| `V1__notification_init.sql` | notification | processed_events, notifications, delivery_attempts, webhook_endpoints |

**Hai lỗ hổng đã phát hiện:**

1. **`core_banking/V1` không tồn tại** nhưng V2/V3/V4 đều phụ thuộc vào nó (`accounts`, `transfers`, `ledger_entries`, `ledger_entries_id_seq`, constraint `transfers_status_check`). Toàn bộ nền của core banking đang thiếu.
2. Docs trích dẫn `DATABASE-DESIGN §1.2` — tài liệu này chưa tồn tại. Phần nguyên tắc thiết kế sẽ được viết thành comment đầu file `schema.sql` thay cho nó.

`javalibs-4.1` là repo riêng: `io.javalibs:javalibs-root:2.0.0-SNAPSHOT`, 16 module, Spring Boot 4.1 / Java 21, publish lên GitHub Packages. `docs/project-structure.md` của nó định nghĩa hai mức cấu trúc service (A: DDD+CQRS, B: layered) — thiết kế này bám theo.

---

## 3. Quyết định đã chốt

| # | Quyết định | Lý do |
|---|---|---|
| D1 | Phạm vi mở rộng vừa phải: 5 schema / 5 service | Phạm vi 3 schema cũ dạy pattern hệ thống phân tán nhưng gần như không dạy nghiệp vụ ngân hàng. Full core banking (~10 schema) thì phần tăng thêm chủ yếu là lặp lại nguyên lý. |
| D2 | javalibs nhúng nguyên vẹn, chỉ đổi tên thư mục `javalibs-4.1/` → `platform-libs/` | Giữ `groupId io.javalibs`, artifactId, package, prefix config `javalibs.*`. Docs javalibs và skill `dr-jskill` (trigger theo chuỗi `io.javalibs:javalibs-dependencies`) vẫn đúng; vẫn merge được update từ repo gốc. |
| D3 | Cấu trúc package trộn theo độ dày nghiệp vụ | `core-banking` + `customer` dùng Mức A (DDD+CQRS); `auth`, `product`, `notification` dùng Mức B (layered). Đúng tinh thần javalibs: không trả giá DDD cho service CRUD. |
| D4 | `bank-common` phạm vi hẹp | Chỉ value object nghiệp vụ + hợp đồng event + hằng số. Cấm util, JPA entity, REST DTO, Spring bean. |
| D5 | Một file `docs/database/schema.sql` là nguồn sự thật | `db/migration/` của các service để rỗng, sẽ cắt từ file này khi bắt tay vào từng service. Không có bản sao nên không có drift. |
| D6 | Một reactor Maven duy nhất | Root vừa aggregate vừa làm parent cho service; `platform-libs` nằm trong `<modules>` nhưng không kế thừa parent. Clone về là build được, không cần PAT GitHub Packages. |
| D7 | Có docker compose, khung chạy được cho mỗi service, gateway module, git + CI | Bốn hạng mục hạ tầng đều được chọn. |

---

## 4. Cấu trúc monorepo

`groupId` = `io.bankplatform`, version `0.1.0-SNAPSHOT`, package gốc `io.bankplatform.*`.

```
bank-platform/
├── pom.xml                       io.bankplatform:bank-platform:0.1.0-SNAPSHOT (pom)
│                                 parent → org.springframework.boot:spring-boot-starter-parent:4.1.0
│                                 modules → platform-libs, bank-common, services/*
│                                 dependencyManagement → import io.javalibs:javalibs-dependencies:2.0.0-SNAPSHOT
│                                 profile "fast" → bỏ platform-libs khỏi reactor
├── platform-libs/                javalibs-4.1 nguyên vẹn — KHÔNG sửa một dòng nào
│   ├── pom.xml                   io.javalibs:javalibs-root (không khai <parent>)
│   └── javalibs-*/               16 module
├── bank-common/                  io.bankplatform:bank-common (jar)
├── services/
│   ├── gateway-service/          :8080
│   ├── auth-service/             :8081  schema auth          user auth_svc
│   ├── customer-service/         :8082  schema customer      user customer_svc
│   ├── product-service/          :8083  schema product       user product_svc
│   ├── core-banking-service/     :8084  schema core_banking  user core_svc
│   └── notification-service/     :8085  schema notification  user noti_svc
├── docs/
│   ├── database/schema.sql       ← nguồn sự thật của DB
│   ├── legacy/                   ← 6 file SQL cũ + README giải thích cái gì đã đổi
│   └── superpowers/specs/
├── compose.yaml
├── .github/workflows/ci.yml
└── .gitignore · .editorconfig · .gitattributes · .env.sample
```

### Vì sao aggregation tách khỏi inheritance

`javalibs-root/pom.xml` không có `<parent>` — nó tự là root. Quyết định D2 cấm sửa nó. Maven tách rời hai khái niệm: một module được liệt kê trong `<modules>` **không bắt buộc** khai aggregator đó làm `<parent>`. Nhờ vậy `platform-libs` tham gia reactor (đúng thứ tự build: javalibs → bank-common → services) mà vẫn nguyên vẹn 100%.

### Starter javalibs theo service

Nền chung cho cả 5 service nghiệp vụ: `javalibs-web-spring-boot-starter`, `javalibs-security-spring-boot-starter`, `javalibs-openapi-spring-boot-starter`, `javalibs-observability-spring-boot-starter`, `javalibs-persistence-spring-boot-starter`, cộng `spring-boot-starter-data-jpa` + driver `postgresql`, và `javalibs-test` + `javalibs-security-test` scope `test`.

| Service | Mức | Starter thêm | Lý do |
|---|---|---|---|
| `auth` | B | `javalibs-security-issuer`, `javalibs-cache-spring-boot-starter` | phát hành/rotate token; blacklist revoke qua Redis |
| `customer` | A | `cqrs`, `ddd-spring`, `datahub`, `search` | KYC là state machine có invariant; phát event `customer.*`; lọc động danh sách KH |
| `product` | B | `cache`, `search` | catalog đọc nhiều ghi ít |
| `core-banking` | A | `cqrs`, `ddd-spring`, `datahub`, `resilience`, `search` | bút toán kép + hold có invariant thật; outbox; circuit breaker khi gọi ngân hàng đối tác |
| `notification` | B | `datahub`, `resilience` | idempotent consumer; retry gửi webhook/telegram |
| `gateway` | — | không dùng javalibs | chỉ định tuyến, không nghiệp vụ, không chạm DB |

### Rủi ro đã biết: Spring Cloud Gateway trên Boot 4.1

Spring Cloud đi theo release train riêng, bám sát version Spring Boot. **Chưa xác minh** được có release train tương thích Boot 4.1 tại thời điểm viết spec.

- Kế hoạch: dùng `spring-cloud-gateway-server-webmvc`; **bước đầu tiên khi triển khai gateway là verify version tương thích**.
- Fallback nếu chưa có: khai báo module `gateway-service` nhưng comment lại dependency Spring Cloud, dùng nginx trong `compose.yaml` để định tuyến tạm.
- Ảnh hưởng giới hạn: 5 service nghiệp vụ không phụ thuộc gateway.

---

## 5. Cấu trúc package rỗng

Mọi thư mục rỗng giữ bằng `.gitkeep`. Toàn repo có **đúng 7 file `.java`**, đều là main class `@SpringBootApplication`.

### Mức A — `core-banking-service` (`io.bankplatform.corebanking`)

```
services/core-banking-service/
├── pom.xml · README.md · ERROR-CODES.md · Dockerfile
├── src/main/java/io/bankplatform/corebanking/
│   ├── CoreBankingApplication.java
│   ├── api/dto/
│   ├── application/
│   │   ├── account/{command,query}/
│   │   ├── ledger/{command,query}/
│   │   ├── transfer/{command,query}/
│   │   └── event/
│   ├── domain/
│   │   ├── account/{model,rule,event}/
│   │   ├── ledger/{model,rule,event}/
│   │   ├── transfer/{model,rule,event}/
│   │   └── shared/
│   ├── infrastructure/
│   │   ├── persistence/{account,ledger,transfer}/
│   │   ├── messaging/
│   │   └── client/
│   └── config/
├── src/main/resources/
│   ├── application.yml · application-local.yml
│   └── db/migration/            (rỗng)
└── src/test/
    ├── java/io/bankplatform/corebanking/{domain,application,api}/
    └── resources/application-test.yml
```

### Mức A phẳng — `customer-service` (`io.bankplatform.customer`)

Chỉ 2 aggregate (Customer, KycVerification) nên `domain/` giữ bố cục phẳng theo đúng doc javalibs: `domain/{model,rule,event,port}`, `application/{command,query,event}`.

### Mức B — `auth-service`, `product-service`, `notification-service`

```
src/main/java/io/bankplatform/<service>/
├── <Name>Application.java
├── web/dto/
├── service/
├── repository/
├── model/
└── config/
```

### `bank-common`

```
bank-common/src/main/java/io/bankplatform/common/
├── type/                          Money, Currency, AccountNumber, CustomerNumber, LedgerDirection
├── event/{customer,account,transfer}/
└── constant/                      Topics, ErrorCodePrefix, HeaderNames
```

`README.md` của module ghi 4 điều cấm: không util (đã có `javalibs-internal`), không JPA entity, không REST DTO, không Spring bean.

### `gateway-service`

`io.bankplatform.gateway/` chỉ có `GatewayApplication.java` + `config/`.

### Đi lệch khỏi doc javalibs (đã duyệt)

Doc javalibs minh họa `domain/{model,event,rule}` phẳng — hợp lý vì ví dụ đó chỉ có một aggregate (`Order`). `core-banking` có bốn (Account, Hold, JournalEntry/GLAccount, Transfer); để phẳng thì `domain/model/` chứa ~20 class trộn lẫn và ranh giới aggregate biến mất khỏi cấu trúc thư mục.

**Quy tắc, ghi vào README của mỗi service Mức A: từ 3 aggregate trở lên thì chia `domain/` và `application/` theo aggregate trước, theo loại sau.** Dưới ngưỡng đó giữ bố cục phẳng của javalibs.

---

## 6. Thiết kế database

### 6.1 Nguyên tắc (viết thành comment đầu `schema.sql`)

1. **Không FK xuyên schema.** Tham chiếu sang schema khác là cột thường + index; toàn vẹn do ứng dụng/saga đảm bảo. Kế thừa nguyên tắc của docs hiện có.
2. **Tiền tệ `NUMERIC(19,4)`**, không bao giờ dùng float. Bốn chữ số thập phân để dự thu lãi không mất số lẻ. `currency CHAR(3)` theo ISO-4217.
3. **Một tài khoản một loại tiền. Một bút toán các dòng cùng loại tiền.** Không có FX trong phạm vi này.
4. **`TIMESTAMPTZ` cho thời điểm, `DATE` cho ngày nghiệp vụ** (`value_date`, `booking_date`, `accrual_date`).
5. **Sổ cái append-only**: `journal_entries` / `journal_lines` không UPDATE, không DELETE. Sai thì ghi bút toán đảo trỏ về bản gốc.
6. **Mọi CHECK constraint đặt tên tường minh** `ck_<bảng>_<cột>`. Bài học từ `V3`: Postgres tự đặt tên `transfers_status_check`, đến lúc ALTER mới lộ ra.
7. **Partial index cho bảng hàng đợi**: outbox chưa publish, hold còn ACTIVE, notification PENDING.
8. **Idempotency key UNIQUE** trên mọi lệnh làm dịch chuyển tiền.
9. **Dữ liệu có hiệu lực theo thời gian thì thêm dòng, không sửa dòng** (biểu phí, lãi suất, địa chỉ). Sửa tại chỗ sẽ làm sao kê kỳ cũ tính lại ra số khác.

### 6.2 Bốn quyết định thiết kế lớn

**DB1 — Nâng `ledger_entries` lên bút toán kép thật.**
Bảng `ledger_entries` trong docs cũ (transfer_id, account_id, DEBIT/CREDIT, amount, balance_after) ghi được nhưng **không cân đối được**: không có phía đối ứng, không có GL, không diễn tả được giao dịch nhiều dòng (chuyển 100, người nhận được 98, thu nhập phí 2). Thay bằng cặp `journal_entries` (header) + `journal_lines` (các dòng Nợ/Có). Đây là thay đổi lớn nhất so với docs.

**DB2 — Ràng buộc "tổng Nợ = tổng Có" bằng constraint trigger hoãn.**
Ràng buộc này là **liên hàng**, không CHECK nào biểu diễn được. Dùng `CREATE CONSTRAINT TRIGGER ... AFTER INSERT ON journal_entries DEFERRABLE INITIALLY DEFERRED`, kiểm tại COMMIT (lúc đó các dòng đã insert xong): số dòng ≥ 2 và `SUM(debit) = SUM(credit)`.
Đặt trigger trên `journal_entries` (bảng thường) chứ không trên `journal_lines` (bảng partition) để né giới hạn của Postgres với trigger trên bảng partition. **Điểm này chưa được xác minh bằng thực nghiệm — nó là một bước nghiệm thu tường minh, không phải một khẳng định.**

**DB3 — Bỏ `accounts.type = 'SYSTEM'`.**
`journal_lines.gl_code` luôn NOT NULL; `journal_lines.account_id` NULL nghĩa là dòng đó chỉ chạm GL nội bộ (tiền mặt, clearing, thu nhập phí, chi phí lãi). Đúng cách core banking thật hoạt động: `accounts` là sổ phụ của khách hàng, `gl_accounts` là sổ cái. Hệ quả: ràng buộc `CHECK (type='SYSTEM' OR owner_user_id IS NOT NULL)` mà `V2` dự kiến thêm ở bước CONTRACT không còn cần thiết.

**DB4 — Số dư lưu sẵn, không tính lại từ ledger.**
`accounts.ledger_balance` và `accounts.hold_amount` là cột thật, cập nhật cùng transaction với bút toán; `available_balance` là **GENERATED column** `= ledger_balance - hold_amount`. Tính lại từ hàng triệu dòng mỗi lần đọc là không khả thi. Lưới an toàn là `account_balance_snapshots` + job đối chiếu định kỳ.

### 6.3 Schema `auth` — 4 bảng

Giữ nguyên thiết kế `V1__auth_init.sql`, chỉ mở rộng danh sách role.

| Bảng | Cột chính |
|---|---|
| `users` | `id`, `username` UNIQUE, `password_hash`, `status` (ACTIVE/LOCKED/DISABLED), `created_at`, `updated_at` |
| `user_roles` | PK `(user_id, role)`; role ∈ CUSTOMER, TELLER, CSO, RISK_OFFICER, ADMIN, SYSTEM |
| `refresh_tokens` | `token_hash` UNIQUE (lưu hash, không lưu token thô), `expires_at`, `revoked_at` |
| `login_audit` | append-only; `username` không FK để giữ được lần đăng nhập với username không tồn tại; `ip INET`, `user_agent` |

Auth vẫn không biết gì về ngân hàng: các schema khác trỏ **vào** `auth.users`, nó không trỏ ra.

### 6.4 Schema `customer` — 10 bảng (CIF)

| Bảng | Cột chính | Điểm đáng học |
|---|---|---|
| `customers` | `id`, `customer_number` UNIQUE (số CIF), `user_id` (mềm → auth.users), `customer_type` (INDIVIDUAL/ORGANIZATION), `status`, `kyc_level`, `risk_rating`, `created_at`, `updated_at` | `customer_number` tách khỏi `id`; status là vòng đời DRAFT → PENDING_KYC → ACTIVE → SUSPENDED → CLOSED |
| `individual_details` | PK = `customer_id` FK; `first_name`, `last_name`, `date_of_birth`, `gender`, `nationality`, `occupation`, `marital_status` | Mô hình **party**: bảng chung + bảng chi tiết theo loại |
| `organization_details` | PK = `customer_id` FK; `legal_name`, `trade_name`, `tax_code`, `incorporation_date`, `business_type` | thay cho một bảng 40 cột nửa NULL |
| `customer_identifications` | `id_type` (NATIONAL_ID/PASSPORT/DRIVER_LICENSE/BUSINESS_LICENSE), `id_number`, `issued_date`, `issued_place`, `expiry_date`; `UNIQUE(id_type, id_number)` | một CMND không thuộc hai người |
| `customer_addresses` | `address_type`, các cột địa chỉ, `country_code`, `is_primary`, `valid_from`, `valid_to` | địa chỉ là dữ liệu **có lịch sử** |
| `customer_contacts` | `contact_type` (EMAIL/MOBILE/PHONE), `value`, `is_primary`, `verified_at` | |
| `kyc_verifications` | `level`, `status` (PENDING/IN_REVIEW/APPROVED/REJECTED/EXPIRED), `method` (MANUAL/EKYC), `submitted_at`, `decided_at`, `decided_by` (mềm → auth.users), `reject_reason`, `expires_at` | KYC là state machine có người duyệt và có **hạn** |
| `kyc_documents` | `kyc_verification_id` FK, `doc_type`, `storage_key`, `checksum`, `uploaded_at` | |
| `customer_risk_assessments` | append-only; `rating`, `score`, `assessed_at`, `assessed_by`, `reason JSONB` | risk rating đổi theo thời gian, giữ lịch sử để giải trình |
| `outbox` | như `V3` | phát `customer.kyc.approved.v1`, `customer.status.changed.v1` |

### 6.5 Schema `product` — 7 bảng

| Bảng | Cột chính |
|---|---|
| `products` | `product_code` UNIQUE, `name`, `category` (CURRENT_ACCOUNT/SAVINGS_ACCOUNT/TERM_DEPOSIT), `currency`, `status` (DRAFT/ACTIVE/RETIRED), `effective_from`, `effective_to` |
| `product_interest_rates` | bậc thang: `tier_from`, `tier_to`, `term_months`, `annual_rate NUMERIC(9,6)`, `effective_from/to` |
| `product_fees` | `fee_code`, `fee_type` (FLAT/PERCENT/TIERED), `amount`, `percent`, `min_amount`, `max_amount`, `charge_event`, `effective_from/to` |
| `product_limits` | `limit_code`, `scope` (PER_TRANSACTION/PER_DAY/PER_MONTH), `channel` (ANY/INTERNET/MOBILE/ATM/BRANCH), `max_amount`, `max_count`, `effective_from/to` |
| `product_eligibility_rules` | `rule_type` (MIN_AGE/MAX_AGE/MIN_KYC_LEVEL/CUSTOMER_TYPE/MIN_RISK_RATING), `operator`, `value` |
| `product_gl_mappings` | `product_id`, `purpose` (PRINCIPAL/INTEREST_PAYABLE/INTEREST_EXPENSE/FEE_INCOME), `gl_code` |
| `outbox` | phát `product.activated.v1` để service khác vô hiệu cache |

`product_gl_mappings` là cầu nối quan trọng nhất giữa `product` và sổ cái: sản phẩm nào thì gốc vào GL nào, lãi phải trả vào GL nào, phí thu vào GL nào. Không có bảng này thì mã hạch toán bị hardcode trong code — lỗi kinh điển của core banking tự viết.

### 6.6 Schema `core_banking` — 15 bảng

**Sổ cái & hạch toán**

| Bảng | Cột chính |
|---|---|
| `gl_accounts` | `gl_code` UNIQUE, `name`, `account_class` (ASSET/LIABILITY/EQUITY/INCOME/EXPENSE), `normal_balance` (DEBIT/CREDIT), `parent_gl_code`, `is_postable`, `currency`, `status` |
| `journal_entries` | `entry_reference` UNIQUE, `transaction_type` (TRANSFER/FEE/INTEREST/REVERSAL/ADJUSTMENT/OPENING), `source_type`, `source_id`, `value_date DATE`, `booking_date DATE`, `posted_at`, `description`, `reversal_of_entry_id` → chính nó |
| `journal_lines` | `journal_entry_id` FK, `line_no`, `account_id` NULL, `gl_code` NOT NULL, `direction` (DEBIT/CREDIT), `amount > 0`, `currency`, `balance_after`, `created_at`; PK `(id, created_at)`; `UNIQUE(journal_entry_id, line_no, created_at)`; **PARTITION BY RANGE (created_at)** |
| `account_balance_snapshots` | PK `(account_id, as_of_date)`; `opening_balance`, `closing_balance`, `total_debit`, `total_credit` |

`value_date` (ngày hiệu lực, quyết định lãi) khác `booking_date` (ngày hạch toán) — bài học riêng.
`journal_lines` partition ngay từ đầu, không đi qua bước expand-swap như `V4` (bài học đó vẫn còn trong `docs/legacy/`).

**Ràng buộc UNIQUE trên bảng partition.** Postgres bắt buộc mọi UNIQUE/PK trên bảng partition phải **chứa cột partition** — đúng điều `V4` đã cảnh báo. Vì vậy PK là `(id, created_at)` và unique của dòng là `(journal_entry_id, line_no, created_at)` chứ không phải `(journal_entry_id, line_no)`.
Trên bố cục này ràng buộc yếu hơn ấy vẫn đủ mạnh: `created_at` mặc định `now()`, mà `now()` trong Postgres trả về **thời điểm bắt đầu transaction** và không đổi trong suốt transaction. Mọi dòng của một bút toán được insert trong cùng một transaction nên có `created_at` giống hệt nhau — unique bộ ba khi đó tương đương unique bộ đôi. Ràng buộc này sẽ đổ vỡ nếu có ai insert bổ sung dòng cho một bút toán ở transaction khác, và đó chính là điều nguyên tắc append-only (§6.1 mục 5) cấm.

**Tài khoản khách hàng**

| Bảng | Cột chính |
|---|---|
| `accounts` | `account_number` UNIQUE, `product_code` (mềm → product), `primary_customer_id` (mềm → customer), `currency`, `status` (PENDING/ACTIVE/DORMANT/FROZEN/CLOSED), `gl_code`, `ledger_balance`, `hold_amount`, `available_balance` GENERATED `= ledger_balance - hold_amount`, `overdraft_limit`, `version`, `opened_at`, `closed_at` |
| `account_holders` | PK `(account_id, customer_id)`; `holder_role` (PRIMARY/JOINT/AUTHORIZED_SIGNATORY) |
| `account_holds` | `account_id` FK, `amount > 0`, `reason` (TRANSFER/CARD_AUTH/LEGAL/FEE), `reference_type`, `reference_id`, `status` (ACTIVE/RELEASED/CAPTURED/EXPIRED), `placed_at`, `expires_at`, `released_at`; partial index `WHERE status='ACTIVE'` |

**Bỏ `accounts.owner_user_id` của `V2`.** Cột đó trỏ mềm sang `auth.users`; giờ chủ tài khoản là **khách hàng**, không phải tài khoản đăng nhập, và `customer.customers.user_id` đã giữ liên kết sang `auth`. Giữ cả hai đường là hai nguồn sự thật cho cùng một quan hệ. `schema.sql` thay thế `V2` nên không có ràng buộc tương thích ngược nào cần giữ.

`accounts.primary_customer_id` cố ý trùng lặp với dòng `PRIMARY` trong `account_holders`: nó là phi chuẩn hóa có chủ đích để truy vấn "tài khoản của tôi" không phải join. Quy tắc: mỗi `accounts` có đúng một dòng `account_holders` với `holder_role='PRIMARY'` và `customer_id` của dòng đó bằng `primary_customer_id`. Bất biến này do ứng dụng giữ, không có constraint DB nào biểu diễn được — ghi vào comment của bảng.

`CHECK`: `ck_accounts_hold_non_negative` (`hold_amount >= 0`) và `ck_accounts_overdraft` (`ledger_balance - hold_amount >= -overdraft_limit`). CHECK viết bằng biểu thức gốc chứ **không** tham chiếu cột `available_balance` — Postgres hạn chế việc dùng cột generated trong ràng buộc, và biểu thức gốc thì luôn hợp lệ.

`version` phục vụ optimistic lock — hai giao dịch cùng trừ một tài khoản là tình huống thật.

**Giao dịch**

| Bảng | Cột chính |
|---|---|
| `transfers` | `transfer_reference` UNIQUE, `idempotency_key` UNIQUE, `transfer_type` (INTERNAL/EXTERNAL), `source_account_id`, `destination_account_id` NULL, `destination_account_number`, `destination_bank_code`, `amount > 0`, `currency`, `fee_amount`, `channel`, `description`, `status` với constraint đặt tên `ck_transfers_status` (PENDING/PENDING_EXTERNAL/COMPLETED/FAILED/REVERSED), `journal_entry_id`, `initiated_by_user_id`, `version` |
| `external_transfers` | giữ nguyên `V3`: `partner_code`, `partner_ref`, `saga_state`, `partner_idempotency_key` UNIQUE, `deadline_at`; partial index trên saga chưa kết thúc |
| `transfer_limit_usage` | `UNIQUE(account_id, limit_code, window_start)`; `used_amount`, `used_count` — velocity check theo cửa sổ ngày/tháng |

**Lãi & phí**

| Bảng | Cột chính |
|---|---|
| `interest_accruals` | `UNIQUE(account_id, accrual_date)` — chống chạy EOD hai lần; `principal_base`, `annual_rate`, `accrued_amount`, `posted`, `journal_entry_id` |
| `fee_charges` | `fee_code`, `source_type`, `source_id`, `amount`, `status` (PENDING/POSTED/WAIVED), `journal_entry_id`, `charged_at` |

`WAIVED` cho phép miễn phí mà vẫn lưu vết đã từng phát sinh.

**Hạ tầng**: `outbox` và `audit_log` giữ nguyên `V3`/`V2`; `processed_events` cho idempotent consumer (core_banking nghe `customer.status.changed.v1` để phong tỏa tài khoản).

### 6.7 Schema `notification` — 6 bảng

Giữ nguyên 4 bảng của `V1__notification_init.sql` (`processed_events`, `notifications`, `delivery_attempts`, `webhook_endpoints`), thêm:

| Bảng | Cột chính |
|---|---|
| `notification_templates` | `template_code`, `channel`, `locale`, `subject`, `body_template`, `version`, `active` |
| `user_notification_preferences` | PK `(user_id, event_type, channel)`; `enabled` — opt-out |

### 6.8 Bố cục và seed của `schema.sql`

```
[0] Header: nguyên tắc thiết kế (§6.1) + 4 quyết định lớn (§6.2)
[1] CREATE SCHEMA × 5 + CREATE USER × 5 + GRANT + search_path + REVOKE CREATE ON public FROM PUBLIC
[2] auth          (SET ROLE auth_svc ... RESET ROLE)
[3] customer
[4] product
[5] core_banking  (gl_accounts → accounts → holds → journal → transfers → interest/fee → outbox/audit)
[6] notification
[7] Seed data
[8] Ghi chú vận hành: tạo partition tháng mới, đánh index theo bằng chứng EXPLAIN
```

Mỗi khối schema dùng `SET ROLE <svc_user>` để bảng thuộc sở hữu đúng service user, `RESET ROLE` ở cuối. Nhờ thế file tự đủ: chạy một lần là có đủ schema, user, quyền, bảng, seed.

**Seed data**: chart of accounts tối thiểu **9 GL** — tiền mặt, tiền gửi KH thanh toán, tiền gửi KH tiết kiệm, lãi phải trả, thu nhập phí, chi phí lãi, clearing/suspense, vốn điều lệ, lợi nhuận giữ lại; 3 sản phẩm mẫu `CA_STANDARD` / `SA_STANDARD` / `TD_12M` kèm rate + fee + limit + GL mapping; và 4 partition `journal_lines` (2026-08, 2026-09, 2026-10, DEFAULT). **Không** seed khách hàng, **không** seed tài khoản.

Ba bảng `outbox` (ở `customer`, `product`, `core_banking`) có cấu trúc giống hệt nhau nhưng là **ba bảng độc lập**, mỗi bảng thuộc sở hữu của service tương ứng. Không dùng chung, không FK giữa chúng.

### 6.9 Xử lý 6 file SQL cũ

Chuyển sang `docs/legacy/` kèm `README.md` giải thích cái gì đã đổi và vì sao. Giữ lại vì `V4` (dựng partition bằng expand-swap trên dữ liệu đang chạy) là bài học không có trong `schema.sql` — file mới sinh partition ngay từ đầu, không có bước migrate online.

---

## 7. Hạ tầng local

### `compose.yaml`

| Service | Image | Cổng | Ghi chú |
|---|---|---|---|
| `postgres` | `postgres:17` | 5432 | healthcheck `pg_isready`; named volume; **mount `./docs/database/schema.sql` vào `/docker-entrypoint-initdb.d/`** |
| `kafka` | `apache/kafka:3.9` | 9092 | KRaft, không ZooKeeper |
| `redis` | `redis:7-alpine` | 6379 | cho `javalibs-cache` và blacklist token |

Không có thư mục `docker/initdb/`: `schema.sql` tự chứa phần tạo schema/user/grant nên được mount thẳng. Một file, không bản sao, không drift — nhất quán với D5.

### Khung mỗi service

`application.yml`: `spring.application.name`, datasource trỏ DB user riêng của service, `spring.jpa.hibernate.ddl-auto: validate`, `hibernate.default_schema`, `javalibs.security.jwt.secret` qua biến môi trường, `server.port`.
`application-local.yml`: ghi đè host và mức log.

**`spring.flyway.enabled: false`** kèm comment giải thích: schema do `schema.sql` dựng qua initdb, `db/migration/` đang rỗng. Bật Flyway lúc này trên schema đã có bảng mà chưa có bảng lịch sử sẽ làm service chết ngay lúc khởi động. Bật lên khi bắt đầu cắt migration đầu tiên từ `schema.sql`.

Mỗi service còn có `Dockerfile` (multi-stage, `eclipse-temurin:21`), `README.md` ghi mức cấu trúc đã chọn (A hay B) và quy tắc ≥3 aggregate ở §5, `ERROR-CODES.md` rỗng chờ điền.

### Git và CI

`git init` tại `bank-platform`; `.gitignore` / `.editorconfig` / `.gitattributes` / `.env.sample` theo template của skill `dr-jskill`.
`.github/workflows/ci.yml`: JDK 21 (khớp `java.version` của javalibs), `mvn -B clean verify` từ root.
`platform-libs` nằm trong reactor nên CI build cả javalibs — chậm hơn nhưng đảm bảo bản javalibs trong repo thực sự compile được. Profile `-P fast` để dev bỏ qua sau lần install đầu.

---

## 8. Cách nghiệm thu

1. `mvn -B clean install` từ root: xanh, build đủ artifact javalibs + `bank-common` + 6 service.
2. `docker compose up -d`: Postgres healthy; `psql` đếm đủ 5 schema và **42 bảng** (auth 4 + customer 10 + product 7 + core_banking 15 + notification 6); seed có 9 GL account và 3 sản phẩm; `\d+ journal_lines` thấy đúng 4 partition.
3. **Kiểm chứng DB2**: insert một `journal_entries` kèm 2 dòng có tổng Nợ ≠ tổng Có → `COMMIT` phải bị từ chối. Nếu constraint trigger hoãn không hoạt động như mong đợi trên bố cục này, ghi lại và chọn phương án thay thế (kiểm ở tầng application, hoặc đổi cách đặt trigger) trước khi coi là xong.
4. Mỗi service `mvn spring-boot:run` khởi động được, `/actuator/health` trả `UP`, `/swagger-ui.html` mở được.
5. `git log` có commit đầu tiên; CI workflow chạy xanh.

---

## 9. Vòng sau (ngoài phạm vi spec này)

- Cắt `schema.sql` thành Flyway migration cho từng service và bật `spring.flyway.enabled`.
- Nghiệp vụ thẻ: phát hành → authorization (hold) → clearing → settlement.
- Nghiệp vụ tín dụng: khả vấn, giải ngân, lịch trả nợ, phân loại nợ.
- Ngoại hối: tài khoản đa tiền tệ, tỷ giá, bút toán quy đổi.
- Thay `auth.user_roles` bằng `javalibs-authz` (Permission → Role → Grant → Scope) khi phân quyền per-resource trở nên cần thiết.
