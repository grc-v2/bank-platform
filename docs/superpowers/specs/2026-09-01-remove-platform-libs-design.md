# Gỡ platform-libs, đưa bank-common vào services/

Ngày: 2026-09-01 · Branch: `refactor/remove-platform-libs`

## Mục tiêu

Chủ dự án muốn **tự tay code lại** phần hạ tầng thay vì dùng thư viện có sẵn, để hiểu
bản chất từng cơ chế. Vì vậy:

1. Xoá hẳn `platform-libs/` (javalibs) khỏi repo.
2. Đưa 5 service nghiệp vụ + gateway về **Spring Boot trần vẫn chạy được** — không giữ
   lại chức năng nào của javalibs, nhưng `mvn clean install` phải xanh và service phải
   khởi động được.
3. Chuyển `bank-common/` thành `services/bank-common/`, ngang hàng các service khác.

Không thuộc phạm vi: viết lại bất kỳ chức năng nào của javalibs (security, envelope lỗi,
correlation-id, outbox…). Chủ dự án sẽ tự làm từng phần khi học tới.

## Hiện trạng đã khảo sát

`platform-libs` là code vendor thẳng vào repo — **431 file tracked, 303 file Java, 17
module**, không phải submodule. Nó không nhận `pom.xml` gốc làm `<parent>`; `pom.xml` gốc
kéo nó vào reactor qua profile `with-libs` (bật mặc định).

Mức độ phụ thuộc, kiểm bằng grep trên source thật:

| Tầng | Mức | Chi tiết |
|---|---|---|
| Java source | Mỏng | 4 kiểu, 33 chỗ |
| pom | Trung bình | 5 service × 5–10 starter |
| Runtime (autoconfiguration) | Dày | 27 class autoconfig / 13 module |
| yml | Trung bình | 22 chỗ `javalibs.*` trong 14 file |

### Phát hiện quyết định: phần lớn dependency là dependency chết

9 trong 13 module javalibs được khai trong pom **không có một dòng Java nào dùng tới**:

| Module | Dùng thật? | Bằng chứng |
|---|---|---|
| `cqrs`, `datahub`, `resilience`, `search`, `ddd-spring` | Không | 0 kết quả cho `KafkaTemplate`, `@KafkaListener`, `CircuitBreaker`, `@Retry`. `JpaSpecificationExecutor` là Spring Data JPA thuần, không phải `javalibs-search` |
| `cache` | Nửa vời | `@EnableCaching` ở `ProductApplication`, chưa có `@Cacheable` nào |
| `ddd-core` | Có | `Entity` (17 chỗ, viết FQN), `AggregateRoot` (6 import) |
| `web-core` | Có | `ApiResponse` (5 import) |
| `test` | Có | `BaseIntegrationTest` (5 import) |
| `security` | Có, chỉ ở runtime | Chặn endpoint; không class nào được import |

Hệ quả: phần lớn công việc là **xoá dependency không ai dùng**, không phải viết lại
chức năng. Chỉ 4 kiểu Java cần bản thay thế, tổng cộng dưới 200 dòng.

`bank-common` hiện **rỗng hoàn toàn** — chỉ có 5 file `.gitkeep`. Việc chuyển nó là thao
tác thuần cơ học.

## Quyết định đã chốt

| Câu hỏi | Chốt |
|---|---|
| Trạng thái đích của service | Spring Boot trần, **chạy được** — không viết lại chức năng javalibs |
| Nơi tham khảo javalibs về sau | **Xoá hẳn khỏi repo**; tra cứu bằng `git show b095cd5:platform-libs/...` |
| Nơi đặt 4 kiểu thay thế | `bank-common`, **mở rộng charter** của nó |
| Security sau khi gỡ | **Bỏ hẳn Spring Security** — mọi endpoint mở, chủ dự án tự dựng lại từ 0 |

## Bảng thay thế

| javalibs | Thay bằng | Mất gì thật sự |
|---|---|---|
| `javalibs-web-spring-boot-starter` | `spring-boot-starter-webmvc` + `spring-boot-starter-validation` | Global exception handler → envelope lỗi; request logging (cả hai mặc định bật). KHÔNG mất CORS: `CorsAutoConfiguration` là opt-in và chưa service nào bật |
| `javalibs-security-spring-boot-starter`, `javalibs-security-issuer`, `javalibs-security-test` | *(bỏ hẳn)* | JWT + permit-all → **mọi endpoint mở**; `JwtTestFactory`, `TestUserContexts` |
| `javalibs-openapi-spring-boot-starter` | `springdoc-openapi-starter-webmvc-ui` | Tự điền title/version/security scheme cho OpenAPI |
| `javalibs-observability-spring-boot-starter` | `spring-boot-starter-actuator` | Correlation-id filter + MDC; bỏ luôn `micrometer-tracing-bridge-otel` (chưa ai dùng) |
| `javalibs-persistence-spring-boot-starter` | `spring-boot-flyway` + `flyway-core` + `flyway-database-postgresql` | Lưới an toàn Flyway: `clean-disabled`, kiểm quy ước đặt tên migration |
| `javalibs-cache-spring-boot-starter` | product: `spring-boot-starter-cache`; auth: bỏ | Cấu hình cache hai tầng Caffeine/Redis |
| `javalibs-datahub`, `-resilience`, `-search`, `-cqrs`, `javalibs-ddd-spring` | *(bỏ hẳn)* | Không gì — chưa dòng code nào dùng |
| `io.javalibs.ddd.Entity` / `.AggregateRoot` | Tự viết → `io.bankplatform.common.ddd` | — |
| `io.javalibs.web.ApiResponse` | Tự viết → `io.bankplatform.common.web` | — |
| `io.javalibs.test.BaseIntegrationTest` | Inline vào `AbstractIntegrationTest` từng service | — |

### Hai quyết định kỹ thuật kèm lý do

**Giữ Flyway** (artifact chính chủ Flyway/Boot, không dính javalibs) dù
`spring.flyway.enabled: false`. Bỏ đi là âm thầm xoá một quyết định đã ghi tài liệu —
`application.yml` của cả 5 service có khối `spring.flyway.*` kèm lời giải thích vì sao
tắt và điều kiện bật lại. Không còn Flyway trên classpath thì khối config đó trở thành
property không ai đọc, gây hiểu nhầm.

**`BaseIntegrationTest` inline vào từng service** thay vì đóng test-jar ở `bank-common`.
Mỗi module Maven chạy một JVM surefire riêng, nên singleton container **không** chia sẻ
được giữa các module — test-jar chỉ thêm rắc rối (dependency test-scope không lan truyền
qua test-jar, mỗi service vẫn phải tự khai đủ 4 dependency test) mà không được lợi gì.
Đổi lại, `src/main` của `bank-common` giữ được đúng cam kết **không có dependency nào**.

## Ràng buộc test phải giữ nguyên

`ServiceInfoApiTest` (cả 5 service) khoá chặt các điểm sau. Vi phạm là test đỏ:

- Đọc `body.path("success")` ở JSON gốc → `ApiResponse` tự viết **phải giữ nguyên 5
  trường theo đúng thứ tự**: `success`, `data`, `message`, `timestamp`, `traceId`.
- `springBootVersion == "4.1.0"` và `version != "unknown"` → phải giữ execution
  `build-info` của `spring-boot-maven-plugin` ở `pluginManagement` gốc.
- `statusOf(data, "db") == "UP"` → actuator + health indicator DB phải còn.
- auth-service và product-service: danh sách `dependencies` **phải chứa** `"redis"` →
  giữ `spring-boot-starter-data-redis` ở hai service này.
- customer, core-banking, notification: **phải KHÔNG chứa** `"redis"` → không được thêm
  dependency Redis vào ba service này.

Không test nào assert envelope lỗi, CORS, hay correlation-id — nên gỡ chúng không làm đỏ
test nào.

## Phạm vi thay đổi

| Nhóm | Việc |
|---|---|
| Xoá | `git rm -r platform-libs/` (431 file) |
| `pom.xml` gốc | Gỡ import BOM `javalibs-dependencies`, property `javalibs.version`, profile `with-libs`; đổi `<module>bank-common</module>` → `services/bank-common` |
| `bank-common` | `git mv` vào `services/`; `relativePath` → `../../pom.xml`; thêm `ddd/Entity`, `ddd/AggregateRoot`, `web/ApiResponse`; viết lại README theo charter mới |
| 5 pom service | Thay toàn bộ khối javalibs bằng starter chính chủ theo bảng trên |
| 27 file Java | `io.javalibs.ddd.Entity` → `io.bankplatform.common.ddd.Entity`; tương tự `AggregateRoot`, `ApiResponse`. (Tổng cộng 33 file Java chạm `io.javalibs`, trừ 5 `AbstractIntegrationTest` và 1 comment ở gateway được xử lý riêng bên dưới) |
| 5 `AbstractIntegrationTest` | Inline `@SpringBootTest(RANDOM_PORT)` + `@AutoConfigureTestRestTemplate` + `@ActiveProfiles("test")` + Testcontainers Postgres singleton |
| 14 file yml | Xoá khối `javalibs.*` (kể cả `application-local.yml` và `application-test.yml`) |
| `.env.sample` | Gỡ `JWT_SECRET` |
| `.github/workflows/ci.yml` | Gỡ comment về profile `with-libs` |
| Tài liệu | `README.md`, `services/bank-common/README.md`, `docs/KNOWN-LIMITATIONS.md` |
| Gateway | Không đụng code; chỉ sửa comment `ApiEnvelope.java` đang nhắc javalibs |

Gateway-service đã sạch javalibs từ trước (chỉ có một comment) — nó là bản mẫu cho hình
dạng pom sau khi dọn.

## Charter mới của bank-common

README hiện tại cấm Spring dependency, cấm REST DTO, chỉ cho `type/`, `event/`,
`constant/`. Charter mới thêm hai package và giữ nguyên tinh thần siết chặt:

| Package | Nội dung |
|---|---|
| `type/` | Value object nghiệp vụ, immutable |
| `event/<domain>/` | Hợp đồng event giữa publisher và consumer |
| `constant/` | Tên topic, prefix mã lỗi, tên header |
| `ddd/` | **Mới** — `Entity`, `AggregateRoot`: Java thuần, không annotation |
| `web/` | **Mới** — `ApiResponse`: envelope dùng chung, `record` thuần, không Spring |

Vẫn giữ nguyên: không dependency, không JPA entity, không Spring bean, không REST DTO
của một API cụ thể. Lý do siết chặt không đổi — mỗi class ở đây là một điểm coupling,
sửa nó là sáu module phải build lại.

Cần cập nhật README ở hai chỗ nữa: mục "KHÔNG được nằm ở đây" đang trỏ sang
`javalibs-internal` cho tiện ích chuỗi/ngày — thư viện đó không còn tồn tại.

## Bằng chứng hoàn thành

1. `grep -rn "io\.javalibs\|javalibs" --exclude-dir=.git .` trả về rỗng, trừ những chỗ
   tài liệu cố ý nhắc tới lịch sử.
2. `mvn clean install` xanh trên toàn reactor (7 module).
3. 5 `ServiceInfoApiTest` + các `*PersistenceMappingTest` chạy thật và xanh — cần Docker
   (OrbStack) đang chạy cho Testcontainers.
4. Khởi động thật ít nhất một service với profile `local` và gọi được endpoint `/info`.

## Nợ kỹ thuật sinh ra (ghi vào docs/KNOWN-LIMITATIONS.md)

Đây là nợ **cố ý**, không phải bỏ sót — chủ dự án sẽ tự trả từng khoản khi học tới:

- **Security bằng 0.** Không xác thực, không phân quyền. Mọi endpoint của cả 5 service
  đều mở. Trước đây javalibs-security chặn tất cả trừ danh sách permit-all.
- **Không có envelope lỗi thống nhất.** Exception ném ra trả về định dạng lỗi mặc định
  của Spring Boot, không phải `ApiResponse.error(...)`. `errorCodePrefix` trong
  `application.yml` hiện chỉ là metadata hiển thị, chưa có cơ chế nào dùng.
- **Không có correlation-id.** Trường `traceId` của `ApiResponse` luôn `null`; log không
  có MDC để nối các dòng của cùng một request.
- **Không còn log request mặc định.** `RequestLoggingAutoConfiguration` của `javalibs-web`
  mặc định bật (`matchIfMissing = true`) và đăng ký filter log mọi request/response. Không
  test nào assert nó nên mất im lặng.
- **CORS: không mất gì.** `CorsAutoConfiguration` là opt-in (`havingValue = "true"`, không
  `matchIfMissing`) và chưa service nào bật — trước khi gỡ cũng đã không có CORS nào chạy.
  Bản spec đầu ghi đây là mất mát; sai, đã sửa sau khi kiểm source.
- **Mất lưới an toàn Flyway.** `clean-disabled` và kiểm quy ước tên migration phải tự
  cấu hình lại khi bật Flyway. `spring.flyway.clean-disabled: true` đã có sẵn trong yml,
  nhưng phần kiểm tên migration thì không.
- **Mất tiện ích test JWT.** `JwtTestFactory`, `TestUserContexts` không còn; test nào
  cần token phải tự dựng.
