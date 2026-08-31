# Giới hạn đã biết và việc còn lại

Những mục dưới đây được phát hiện trong quá trình review, đã được cân nhắc, và **cố ý
chưa xử lý** ở nền scaffolding này. Ghi lại để không ai phải phát hiện lại lần nữa —
và để không ai tưởng chúng là bỏ sót.

Mỗi mục ghi: hiện trạng, vì sao chưa xử, và điều kiện để xử.

## Database

### Chu trình GL dài không bị chặn

`gl_accounts.parent_gl_code` có `ck_gl_parent_not_self` chặn `A -> A`, nhưng **không**
chặn `A -> B -> A`. Đây là quyết định có ý thức của chủ dự án, không phải bỏ sót.

Hệ quả: mọi đoạn duyệt cây GL để cộng dồn số dư **phải** dùng `WITH RECURSIVE ... CYCLE`,
nếu không sẽ lặp vô hạn. Seed hiện tại không gắn parent cho dòng nào (`gl_with_parent = 0`)
nên rủi ro chỉ xuất hiện khi có người dựng cây GL thật.

### `assert_journal_balanced` chưa đối chiếu tiền tệ cho dòng GL-only

Trigger ép `journal_lines.currency` khớp `accounts.currency`, nhưng dòng có
`account_id IS NULL` (hạch toán thẳng vào GL) thì không có tài khoản để đối chiếu —
và `gl_accounts.currency` chưa được đưa vào phép kiểm.

Xử khi: bắt đầu dùng dòng GL-only thật. Chỗ sửa nằm ngay cạnh phép kiểm hiện có.

### `set_updated_at()` không có guard cho UPDATE không đổi gì

Một `UPDATE` không thay đổi giá trị nào vẫn bump `updated_at`, gây nhiễu cho đúng
loại consumer (CDC, đồng bộ tăng dần) mà cột này sinh ra để phục vụ.

Vì sao chưa xử: cách viết gọn `WHEN (OLD.* IS DISTINCT FROM NEW.*)` bị Postgres **từ chối
thẳng** trên `core_banking.accounts` — `ERROR: A whole-row reference is used and the table
contains generated columns` (bảng có `available_balance` là `GENERATED`). Guard bảy bảng
và bỏ bảng sổ cái sẽ tạo hai ngữ nghĩa `updated_at` khác nhau trong cùng một database,
tệ hơn là không guard cái nào. Liệt kê cột bằng tay thì cột thêm sau sẽ âm thầm rơi ra
ngoài guard, đúng trên bảng nhạy cảm nhất.

Xử khi: chấp nhận so sánh theo danh sách cột tường minh kèm quy trình cập nhật, hoặc
Postgres cho phép whole-row reference trên bảng có cột generated.

### `uq_journal_one_reversal` chặn luôn đảo một phần

Ràng buộc cho phép **một** bút toán đảo cho một bút toán gốc. Đảo một phần — hai bút
toán đảo nhỏ cho cùng một gốc — là nghiệp vụ có thật và hiện không làm được.

Đây là lựa chọn chính sách, không phải bất biến hiển nhiên: `reversal_of_entry_id` chỉ
là con trỏ, không mang số tiền, nên không có cách nào để DB biết tổng các phần đảo có
vượt gốc hay không. Muốn hỗ trợ đảo một phần thì phải thiết kế lại chỗ đó trước.

### Các ràng buộc `ex_*_overlap` không `DEFERRABLE`

`ex_fee_overlap`, `ex_limit_overlap`, `ex_glmap_overlap`, `ex_rate_overlap` đều kiểm ngay
tại câu lệnh. Nghĩa là khi đổi biểu giá phải **đóng dòng cũ trước, chèn dòng mới sau**;
làm ngược lại sẽ đụng dòng còn để ngỏ `effective_to IS NULL`.

Hợp đồng thứ tự này áp cho mọi code ghi vào bốn bảng đó.

## Service

### `/actuator/prometheus` trả 404 ở cả sáu service

Cả sáu `application.yml` đều khai `include: health,info,metrics,prometheus`, nhưng
endpoint `prometheus` **không tồn tại**: không service nào có Prometheus registry trên
classpath. Mỗi service tự khai `spring-boot-starter-actuator` (trước đây đến qua
`javalibs-observability-spring-boot-starter`, đã gỡ cùng platform-libs — xem mục
"Hạ tầng gỡ cùng platform-libs" bên dưới); starter đó không kéo theo
`micrometer-registry-prometheus`. `PrometheusMetricsExportAutoConfiguration` bị gate
bởi `@ConditionalOnClass(PrometheusMeterRegistry)`, lớp chỉ có trong
`micrometer-registry-prometheus`. `/actuator/metrics` tự nó vẫn trả dữ liệu
bình thường, nhưng meter của nó thiếu common tags — xem mục "Mất common metric
tags" bên dưới; khi thêm `micrometer-registry-prometheus`, hệ quả đó lộ ra rõ
hơn vì series scrape về sẽ lẫn giữa các service.

Mục khai được giữ lại vì vô hại và giữ được đối xứng giữa sáu service.

Xử bằng cách thêm dependency `micrometer-registry-prometheus` vào **từng** `pom.xml`
của sáu service — không còn "một chỗ sửa cho cả sáu" như thời còn platform-libs, vì
mỗi service giờ tự khai dependency riêng.

### Dockerfile

Cả sáu Dockerfile hardcode `ARG JAR_FILE=target/<svc>-0.1.0-SNAPSHOT.jar`, nên một lệnh
`mvn versions:set` sẽ làm hỏng cả sáu image mà không báo gì. Chúng cũng chạy bằng `root`
(không có `USER`), còn `ENTRYPOINT` không đặt profile nào.

Đây là Dockerfile mức "đủ để build thử", chưa phải mức triển khai.

### `.env.sample` chưa được nối vào đâu

Không có gì trong repo đọc `.env`: `compose.yaml` không có `${}` substitution và không
khai `env_file`, còn Spring Boot không tự đọc `.env`. Làm theo dòng đầu file
("sao chép thành `.env` rồi chỉnh") hiện không có tác dụng gì.

Nó đang là **danh sách tham chiếu các biến cần export**, không phải file cấu hình sống.

### Bảng dependencies của API `/info` không có dòng `kafka`

Boot 4.1 không có health indicator nào cho Kafka — đã soát cả
`spring-boot-actuator`, `spring-boot-actuator-autoconfigure`, `spring-boot-kafka`
lẫn `spring-kafka` 4.1.0: không jar nào chứa lớp health Kafka, kể cả cho Kafka
Streams. Nhưng lý do gần hơn khiến bảng dependencies không có dòng `kafka` là
**không service nào còn Kafka client trên classpath** — xem mục "Kafka client
không còn trên classpath" bên dưới. `customer`, `product`, `core-banking`,
`notification` từng dùng Kafka qua `javalibs-datahub`, giờ không còn.

`WATCHED_DEPENDENCIES` trong các `ServiceInfoController` vẫn cố ý chứa `"kafka"`,
nhưng lời hứa "dòng kafka tự xuất hiện, không phải sửa code" không còn đúng: vì
`KafkaAdmin` (nguồn health indicator tự viết) không còn trên classpath, việc đầu
tiên phải làm là thêm lại dependency Kafka vào `pom.xml`, sau đó mới viết health
indicator. Xem mục "Kafka client không còn trên classpath".

### API `/info` lộ trạng thái từng component hạ tầng cho người gọi ẩn danh

`GET .../info` đọc thẳng `HealthEndpoint.health()`, cái này bỏ qua cờ
`management.endpoint.health.show-details` (cờ đó chưa được set ở service nào —
nghĩa là *never*, `/actuator/health` chỉ trả trạng thái tổng hợp). Kết quả:
`/info` trả từng dòng db/redis kèm UP/DOWN mà `/actuator/health` đang giấu.
Không còn danh sách permit-all nào để nói tới — endpoint này gọi được vì
**không còn xác thực gì cả** trên toàn hệ thống (xem mục "Security bằng 0"),
giống hệt mọi endpoint khác kể cả `/actuator/metrics`. Không lộ chi tiết hay
connection string — chấp nhận được cho môi trường dev. Ai dựng lại xác thực
và bật `show-details` sau này cần biết đường vòng này tồn tại.

### `/actuator/health` của auth + product giờ có thể trả 503 vì Redis

Thêm `spring-boot-starter-data-redis` (xem Task 1/2 của kế hoạch
service-info-dashboard) kéo theo health indicator Redis chạy trong tổ hợp
`HealthEndpoint` mặc định — Redis không lên thì `/actuator/health` của hai
service này chuyển DOWN (503), trước nhánh này thì chúng UP mà không cần
Redis. Chạy local cần `docker compose up -d redis`.

### Netty in WARN `MacOSDnsServerAddressStreamProvider` lúc khởi động auth/product trên macOS

Lettuce (client Redis) dùng resolver DNS của Netty mà không có jar
`netty-resolver-dns-native-macos`, nên in một dòng WARN vô hại lúc khởi động
trên macOS. Cố ý không xử: tắt logger đó thì che luôn WARN Netty thật khác,
còn thêm jar native thì kéo classifier macOS sang cả image Linux chạy CI/prod.

## Quy ước còn lệch

- **Khoá ngoại không đặt tên tường minh.** 44/46 FK dùng tên Postgres tự sinh
  (`customer_identifications_customer_id_fkey`). Global Constraint chỉ yêu cầu đặt tên
  `CHECK` và `UNIQUE`. Tên tự sinh cho FK một cột là tất định (`<bảng>_<cột>_fkey`) nên
  không có rủi ro thật, chỉ lệch thẩm mỹ với phần còn lại của file.
- **Tên constraint lúc viết tắt lúc đầy đủ** — `ck_users_status` và `ck_transfers_status`
  dùng tên bảng đầy đủ, còn `ck_prefs_channel`, `ck_ident_type`, `ck_glmap_purpose` viết
  tắt. Mọi tên đều tường minh nên vô hại hôm nay. Đáng lưu ý: tên `uq_*` và `ex_*` trở
  thành **tên index toàn schema**, nên viết tắt làm tăng rủi ro trùng khi thêm bảng.

## Code nghiệp vụ các service

### Đã hoàn thiện JPA Entity + Spring Data Repository cho 5 service nghiệp vụ

- **Phủ toàn bộ 5 service**: `auth-service`, `notification-service`, `product-service`, `customer-service`, `core-banking-service` đã có đầy đủ Entity + Repository, được xác thực bằng Hibernate `ddl-auto: validate` chạy trên PostgreSQL Testcontainers với schema thật từ `docs/database/schema.sql`.
- **Phạm vi code còn lại**: Các tầng Use-case Service, Controller, DTO, Event Producer/Consumer và Mapper chưa được triển khai (thuộc các phase sau của dự án).
- **Các bảng hạ tầng bị hoãn**: 3 bảng `outbox` (`customer`, `product`, `core_banking`) và 2 bảng `processed_events` (`notification`, `core_banking`) cố ý **chưa map** (quyết định L1). Phán quyết dùng `javalibs-datahub` (bảng riêng `datahub_outbox_event`/`datahub_processed_event`, cấu trúc khác các bảng `outbox`/`processed_events` hiện có) hay tự viết publisher đã được quyết hộ bởi nhánh gỡ platform-libs — `javalibs-datahub` không còn tồn tại, nên hướng còn lại là tự viết publisher trên bảng outbox hiện có.
- **Flyway**: Tiếp tục **tắt** (`spring.flyway.enabled=false`), giữ nguyên cơ chế nạp schema trực tiếp vào container test cho đến phase cắt migration.

## CI

`.github/workflows/ci.yml` **chưa từng chạy thật** — repo chưa có remote. Workflow đã
được đọc kỹ và nhất quán với cách repo build (JDK 21, probe Postgres qua TCP), nhưng
lần push đầu tiên vẫn là lần chạy đầu tiên.

## Hạ tầng gỡ cùng platform-libs (2026-09-01)

`platform-libs` (javalibs) đã bị xoá khỏi repo để chủ dự án tự viết lại phần hạ
tầng — mục tiêu là *học hiểu bản chất*, nên các khoản dưới đây là **nợ cố ý**,
không phải bỏ sót. Tham khảo bản cũ: `git show b095cd5:platform-libs/...`

### Kafka client không còn trên classpath

`grep -rn kafka services/*/pom.xml` không ra dòng nào. Trước khi gỡ
platform-libs, bốn service (`customer`, `product`, `core-banking`,
`notification`) khai `javalibs-datahub-spring-boot-starter` (kéo theo
`spring-kafka`) **và** `org.springframework.boot:spring-boot-kafka` tường
minh. Cả hai đi mất cùng lúc với javalibs — không phải một khoản gỡ riêng.

Cố ý không thêm lại: không dòng code nào dùng `KafkaTemplate`/`@KafkaListener`,
nên thêm lại dependency lúc này chỉ là thêm dependency chết, trái tinh thần
"Spring Boot trần" của nhánh này.

Hệ quả cụ thể còn sờ được:

- Khối `spring.kafka.*` vẫn còn trong 4 `application.yml` (`customer`,
  `product`, `core-banking`, `notification`) nhưng **không có
  `KafkaAutoConfiguration` nào để bind** — đây là property chết, giữ lại kèm
  comment tại chỗ để không ai tưởng hạ tầng đã sẵn sàng.
- `compose.yaml` vẫn dựng broker `apache/kafka:3.9.0` mà không service nào
  kết nối tới.
- `WATCHED_DEPENDENCIES` trong 5 `ServiceInfoController` vẫn giữ `"kafka"` cho
  tương lai, nhưng bảng dependencies của `GET .../info` sẽ không có dòng đó —
  xem mục "Bảng dependencies của API `/info` không có dòng `kafka`" ở trên.

Xử khi: viết consumer/producer Kafka đầu tiên. Lúc đó thêm lại
`spring-boot-kafka` + `spring-kafka` vào `pom.xml` của service cần dùng.

### Security bằng 0

Không xác thực, không phân quyền. Mọi endpoint của cả 5 service đều mở. Trước
đây `javalibs-security` chặn tất cả trừ một danh sách permit-all, xác thực bằng
JWT HS256. `JWT_SECRET` đã gỡ khỏi `.env.sample` và mọi `application*.yml`.

Xử khi: viết luồng phát token ở auth-service. Lúc đó thêm lại
`spring-boot-starter-oauth2-resource-server` và một `SecurityConfig` cho mỗi
service.

### Không có envelope lỗi thống nhất

Exception ném ra trả về định dạng lỗi mặc định của Spring Boot, không phải
`ApiResponse.error(...)`. `bank.info.error-code-prefix` trong `application.yml`
hiện chỉ là metadata hiển thị trên dashboard — chưa cơ chế nào dùng nó để sinh
mã lỗi.

Xử khi: viết `@RestControllerAdvice` đầu tiên.

### Không có correlation-id

Trường `traceId` của `ApiResponse` luôn `null`; log không có MDC để nối các dòng
của cùng một request. Trường vẫn giữ trong record để khi dựng filter không phải
đổi hợp đồng JSON với frontend.

### Không còn log request mặc định

`RequestLoggingAutoConfiguration` của `javalibs-web` đăng ký filter log mọi
request/response và **mặc định bật** — `@ConditionalOnProperty(prefix =
"javalibs.web.logging", name = "enabled", havingValue = "true", matchIfMissing = true)`,
đã kiểm trên source. Bộ starter thay thế không có gì tương đương, và không test
nào assert nó, nên mất im lặng.

Hệ quả: không còn access-log cho mỗi HTTP call. Cùng với mục correlation-id ở
trên, khả năng quan sát của cả 5 service hiện bằng 0.

Xử khi: viết filter log đầu tiên — nên làm cùng lúc với correlation-id, hai thứ
này chỉ hữu ích khi đi cùng nhau.

### CORS: KHÔNG mất gì

Ghi lại để không ai đi tìm nhầm. `CorsAutoConfiguration` của `javalibs-web` là
**opt-in**: `@ConditionalOnProperty(prefix = "javalibs.web.cors", name = "enabled",
havingValue = "true")` — không có `matchIfMissing`. Chưa service nào từng đặt
property đó (đã grep toàn bộ `application*.yml`). Nghĩa là **trước khi gỡ javalibs
cũng đã không có cấu hình CORS nào hoạt động** — đây không phải hồi quy.

Frontend hiện đi qua gateway nên chưa cần. Khi nào gọi thẳng service thì phải tự
cấu hình CORS, nhưng đó là việc mới.

### Mất chuẩn hoá OpenAPI

`JavalibsOpenApiAutoConfiguration` bật mặc định (`matchIfMissing = true`) và
không service nào từng override, nên trước đây mọi service đều nhận: title
`<spring.application.name> API`, version `v1`, security scheme `bearerAuth`
toàn cục (nút **Authorize** trên Swagger UI), và error response
400/401/403/404/409/500 document trên **mọi** operation.

Sau khi gỡ, springdoc-openapi (dependency `springdoc-openapi-starter-webmvc-ui`
vẫn còn trong `pom.xml` của cả 5 service) rơi về document mặc định của chính
nó: không có bean `OpenAPI` nào, không service nào khai `springdoc.*` trong
`application.yml`.

Kịch bản đáng ghi: chạy đúng lệnh trong `services/auth-service/README.md` rồi
mở `http://localhost:8081/swagger-ui.html` sẽ thấy tiêu đề "OpenAPI definition
v0", không có nút Authorize, không có error response nào được document — dễ bị
báo nhầm là bug thay vì nợ kỹ thuật đã biết.

Xử khi: viết `OpenApiCustomizer`/bean `OpenAPI` riêng cho từng service, hoặc
dựng lại một auto-configuration dùng chung nếu số service tăng lên.

### AggregateRoot không có cơ chế domain event

Bản javalibs cũ có `registerEvent`/`pullDomainEvents`/`DomainEvent`.
`io.bankplatform.common.ddd.AggregateRoot` hiện chỉ là dấu hiệu kiểu.

Xử khi: publish domain event đầu tiên.

### Mất common metric tags

`ObservabilityAutoConfiguration.MetricsCommonTagsConfiguration` của
`javalibs-observability` (bật mặc định) gắn tag `application` (lấy từ
`spring.application.name`) và `environment` lên **mọi** meter đăng ký vào
`MeterRegistry`. Bản thay thế (`spring-boot-starter-actuator` trần) không có
gì tương đương — không service nào tự khai `MeterFilter`/`MeterRegistryCustomizer`
để bù lại.

`/actuator/metrics` tự nó vẫn hoạt động bình thường (đọc từng meter theo tên),
nhưng meter trả về không còn tag `application`/`environment`. Hệ quả cụ thể:
khi thêm `micrometer-registry-prometheus` cho sáu service (xem mục
"`/actuator/prometheus` trả 404" ở trên) để scrape thật, các series kéo về từ
nhiều service sẽ trộn lẫn — không có label `application` để phân biệt series
nào của service nào trên cùng một Prometheus/Grafana.

Xử khi: thêm `micrometer-registry-prometheus`. Lúc đó khai một
`MeterRegistryCustomizer<MeterRegistry>` gắn `commonTags("application",
${spring.application.name})` (và `environment` nếu cần) cho từng service.

### Cache của product-service đổi ngữ nghĩa, chưa lộ ra

`javalibs-cache` tạo `RedisCacheManager` riêng, chạy TRƯỚC `CacheAutoConfiguration`
của Boot (`@AutoConfiguration(before = ...)` + `@ConditionalOnMissingBean`), nên
cấu hình gốc của Boot **chưa từng chạy** khi thư viện đó còn.

Sau khi gỡ, `org.springframework.boot.cache.autoconfigure.RedisCacheConfiguration`
của Boot thắng. Hai khác biệt đã kiểm trên source/bytecode:

| | javalibs-cache | Boot mặc định |
|---|---|---|
| Serializer giá trị | JSON (không ràng buộc kiểu) | `JdkSerializationRedisSerializer` — **giá trị phải `implements Serializable`** |
| TTL mặc định | `Duration.ofMinutes(10)` (`JavalibsCacheProperties:39`) | **không có** trừ khi đặt `spring.cache.redis.time-to-live` — chưa service nào đặt |

Hiện **chưa lộ ra** vì `product-service` có `@EnableCaching` nhưng chưa `@Cacheable`
nào. Người viết `@Cacheable` đầu tiên sẽ thừa hưởng một cache không bao giờ hết hạn,
và nếu trả về `record`/DTO thường thì vỡ ngay lần ghi đầu bằng `SerializationException`.

Xử khi: viết `@Cacheable` đầu tiên. Lúc đó đặt `spring.cache.redis.time-to-live` và
cân nhắc `RedisCacheConfiguration` bean riêng dùng serializer JSON.

### Mất lưới an toàn Flyway

`clean-disabled` và phép kiểm quy ước đặt tên migration của
`javalibs-persistence` không còn. `spring.flyway.clean-disabled: true` vẫn có
trong cả 5 `application.yml`, nhưng phần kiểm tên migration thì không.

Xử khi: cắt migration đầu tiên từ `schema.sql`.

### Mất tiện ích test JWT

`JwtTestFactory` và `TestUserContexts` của `javalibs-security-test` không còn.
Test nào cần token phải tự dựng.

