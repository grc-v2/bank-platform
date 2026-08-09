# javalibs 2.0.x — Breaking changes so với 1.0.x

Dòng 2.0.x chạy trên **Spring Boot 4.1.0** / **Spring Framework 7.0.8** (1.0.x ở Boot 3.5.3 /
Spring Framework 6.2.8). Java baseline giữ nguyên **21**. Hibernate ORM baseline đi kèm Boot
lên **7.4.1.Final** (1.0.x ở 6.6.18.Final). groupId `io.javalibs` và mọi artifactId giữ
nguyên — chỉ dòng version đổi.

## Bắt buộc sửa khi nâng

_(bồi dần theo từng bậc migration)_

- **Spring Boot baseline: 3.5.3 → 4.1.x.** Service dùng javalibs 2.0.x phải chạy trên
  Spring Boot 4.1. Dòng 3.5 đã hết vòng đời OSS ngày 30/06/2026.
- **Java baseline giữ nguyên 21** — không cần nâng JDK khi lên 2.0.x.
- **`spring-boot-starter-web` → `spring-boot-starter-webmvc` (deprecated, nên đổi — chưa bắt
  buộc).** `javalibs-web-spring-boot-starter` đã kéo starter mới. Đã kiểm:
  `spring-boot-starter-web:4.1.0` **vẫn được publish** trên Maven Central (HTTP 200), mô tả
  POM ghi "deprecated in favor of spring-boot-starter-webmvc" — service tự khai
  `spring-boot-starter-web` vẫn resolve và build xanh, không bắt buộc đổi ngay khi bump Boot.
  Nên đổi tên sớm vì artifact cũ đã deprecated, có thể bị gỡ ở một bản Boot sau này.
- **Starter OAuth2 đổi tên (deprecated, nên đổi — chưa bắt buộc):**
  `spring-boot-starter-oauth2-resource-server` → `spring-boot-starter-security-oauth2-resource-server`
  (tương tự cho `-client`, `-authorization-server`). Đã kiểm:
  `spring-boot-starter-oauth2-resource-server:4.1.0` vẫn được publish (HTTP 200), mô tả
  "deprecated in favor of ...". Service dùng mode `oauth2-resource-server` với tên cũ vẫn build
  xanh; nên đổi sớm để tách việc rename khỏi việc bump Boot thay vì đợi artifact cũ ngừng
  publish ở một bản Boot sau.
- **Spring Security 7.** API nội bộ của javalibs-security đã cập nhật; `UserContext`,
  `@RequireRole`, `@CurrentUser` giữ nguyên chữ ký nên service không phải sửa code.
- **Hibernate ORM 6.6.18.Final → 7.4.1.Final.** Baseline đi kèm BOM Spring Boot 4.1, không
  phải property riêng của javalibs. `javalibs-persistence`, `javalibs-search`, `javalibs-authz`
  (bậc 7) build xanh không cần sửa entity/repository — API JPA/Hibernate mà các module này
  và service dùng qua Spring Data JPA không đổi chữ ký. Các dời-chỗ package tự động cấu hình
  liên quan (`HibernateJpaAutoConfiguration`, `@EntityScan`, `@DataJpaTest`/`TestEntityManager`)
  liệt kê riêng ở các mục dưới.
- **springdoc-openapi 2.8.9 → 3.1.0.** Chỉ là version bump ở `javalibs-openapi` — 0 dòng Java
  đổi, springdoc 3.1.0 tự pin `spring-boot-starter-parent:4.1.0` nên resolve sạch về Spring
  Framework 7.0.8, không kéo ngược artifact 6.x nào. Service import
  `javalibs-openapi-spring-boot-starter` không phải làm gì; service tự khai springdoc riêng
  (không qua javalibs) phải tự nâng lên dòng 3.x.
- **Testcontainers 1.x → 2.x.** Artifact `org.testcontainers:postgresql` →
  `org.testcontainers:testcontainers-postgresql`; package
  `org.testcontainers.containers.PostgreSQLContainer` →
  `org.testcontainers.postgresql.PostgreSQLContainer`; `junit-jupiter` không còn cần.
  Service tự khai container riêng phải đổi theo. Thêm nữa: lớp `PostgreSQLContainer` ở
  TC 2.x không còn generic tự-tham-chiếu (`PostgreSQLContainer<Self>`) — service khai kiểu
  tường minh dạng `PostgreSQLContainer<?> pg = ...` phải bỏ tham số generic
  (`PostgreSQLContainer pg = ...`).
- **`io.javalibs.test.PostgresContainerSupport.postgres()` đổi kiểu trả về công khai:**
  `protected static PostgreSQLContainer<?> postgres()` →
  `protected static PostgreSQLContainer postgres()` (hệ quả trực tiếp của việc TC 2.x bỏ
  generic tự-tham-chiếu ở trên). Service kế thừa `BaseIntegrationTest`/`PostgresContainerSupport`
  và gọi `postgres()` để chạy fixture SQL trực tiếp mà khai biến cục bộ kiểu
  `PostgreSQLContainer<?> c = postgres();` phải bỏ `<?>`; gọi qua `var` hoặc chaining method
  không bị ảnh hưởng.
- **`BaseIntegrationTest` nay mang `@AutoConfigureTestRestTemplate`** — Boot 4 không còn
  tự cấp `TestRestTemplate` cho `@SpringBootTest`. Test kế thừa không phải sửa gì;
  test tự khai `@SpringBootTest` mà dùng `TestRestTemplate` thì phải tự thêm annotation.
- **`TestRestTemplate` đổi package:** `org.springframework.boot.test.web.client.TestRestTemplate`
  → `org.springframework.boot.resttestclient.TestRestTemplate` (artifact
  `org.springframework.boot:spring-boot-resttestclient`). Service tự import lớp này (thay vì chỉ
  dùng qua `@Autowired` không khai kiểu tường minh — vẫn phải import đúng lớp) phải đổi.
- **Flyway autoconfigure dời package (bậc 7):** `org.springframework.boot.autoconfigure.flyway.*`
  → `org.springframework.boot.flyway.autoconfigure.*` (tên lớp `FlywayAutoConfiguration`,
  `FlywayConfigurationCustomizer` giữ nguyên). Artifact chứa các lớp này cũng đổi:
  `spring-boot-autoconfigure` → `org.springframework.boot:spring-boot-flyway` (khai
  `<optional>true</optional>` giống `flyway-core`). Service tự khai `@AutoConfiguration(beforeName
  = "...")`/`afterName` trỏ vào lớp Flyway của Boot, hoặc tự import
  `FlywayConfigurationCustomizer`, phải đổi cả chuỗi FQCN lẫn import.
- **`HibernateJpaAutoConfiguration` dời package:**
  `org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration` →
  `org.springframework.boot.hibernate.autoconfigure.HibernateJpaAutoConfiguration` (artifact
  `org.springframework.boot:spring-boot-hibernate`, khai optional).
- **`@EntityScan` dời package:** `org.springframework.boot.autoconfigure.domain.EntityScan` →
  `org.springframework.boot.persistence.autoconfigure.EntityScan` (artifact
  `org.springframework.boot:spring-boot-persistence`, khai optional trong autoconfigure —
  thường đã có sẵn transitively qua `spring-boot-starter-data-jpa` ở runtime/test).
- **`@DataJpaTest`/`TestEntityManager` dời package và tách starter riêng:**
  `org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest` →
  `org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest`;
  `org.springframework.boot.test.autoconfigure.orm.jpa.TestEntityManager` →
  `org.springframework.boot.jpa.test.autoconfigure.TestEntityManager`. `TestEntityManager`
  không còn kéo theo bởi `spring-boot-starter-data-jpa` (scope test) — service dùng
  `@DataJpaTest`/`TestEntityManager` phải đổi dependency test-scope sang
  `org.springframework.boot:spring-boot-starter-data-jpa-test` (kéo theo cả
  `spring-boot-starter-data-jpa` + `spring-boot-starter-test` + hỗ trợ slice test JPA).
- **Jackson 2 → 3 (bậc 8).** Class API chuyển sang `tools.jackson.*` (annotation vẫn ở
  `com.fasterxml.jackson.annotation.*`). Service tự inject `ObjectMapper` phải đổi import.
  Artifact `com.fasterxml.jackson.core:jackson-databind` → `tools.jackson.core:jackson-databind`;
  `com.fasterxml.jackson.datatype:jackson-datatype-jsr310` không còn tồn tại — hỗ trợ
  `java.time` nay có sẵn trong `jackson-databind`, không cần đăng ký module. Ngoại lệ:
  `jjwt-jackson:0.12.6` (JJWT) chưa lên Jackson 3, tự khai
  `com.fasterxml.jackson.core:jackson-databind` (Jackson 2, runtime) làm dependency riêng của
  nó. Module khai `jjwt-jackson` là **`javalibs-security-core`** (không phải
  `javalibs-security-issuer`) — đã xác nhận bằng `mvn dependency:tree` trên
  `javalibs-security-spring-boot-starter`: cây chỉ đi qua `javalibs-security-core`, không hề có
  `javalibs-security-issuer` (module này khai `<optional>true</optional>`, không tự kéo vào cây
  của consumer). Vì vậy `jackson-databind` 2.x runtime lan sang **mọi** consumer của
  `javalibs-security-spring-boot-starter`, kể cả service chỉ validate JWT (không phát hành
  token, không dùng issuer) — không liên quan tới `ObjectMapper` Jackson 3 mà service tự inject
  qua DI. Xem mục **"Jackson 2.x còn sót trong dependency tree"** ở dưới — bức tranh đầy đủ.
- **`DataSourceAutoConfiguration`/`DataSourceTransactionManagerAutoConfiguration` dời package:**
  `org.springframework.boot.autoconfigure.jdbc.*` → `org.springframework.boot.jdbc.autoconfigure.*`
  (artifact `org.springframework.boot:spring-boot-jdbc`, khai optional).
- **`KafkaAutoConfiguration` dời package:** `org.springframework.boot.autoconfigure.kafka.*` →
  `org.springframework.boot.kafka.autoconfigure.*` (artifact `org.springframework.boot:spring-boot-kafka`,
  khai optional).
- **`CacheAutoConfiguration` dời package:** `org.springframework.boot.autoconfigure.cache.*` →
  `org.springframework.boot.cache.autoconfigure.*` (artifact `org.springframework.boot:spring-boot-cache`,
  khai optional).
- **`RedisCacheConfigurations.jsonSerializer()` đổi kiểu trả về:**
  `GenericJackson2JsonRedisSerializer` → `GenericJacksonJsonRedisSerializer` (Spring Data Redis
  đổi tên lớp serializer theo phiên bản Jackson). Tên method và danh sách tham số (rỗng) giữ
  nguyên. Service gọi qua `var` hoặc chaining không bị ảnh hưởng; service khai kiểu tường minh
  `GenericJackson2JsonRedisSerializer` phải đổi.
- **resilience4j 2.3.0 → 2.4.0 (bậc 9), artifact `resilience4j-spring-boot3` →
  `resilience4j-spring-boot4`.** Artifact mới bị bỏ sót khỏi `resilience4j-bom` 2.4.0
  (resilience4j#2427; đã kiểm bằng cách tải trực tiếp `resilience4j-bom-2.4.0.pom` từ Maven
  Central và grep — BOM chỉ liệt kê `resilience4j-spring-boot3`, không có `-spring-boot4`) nên
  javalibs pin version tường minh trong `<dependencyManagement>` của `pom.xml` gốc — service
  import BOM `javalibs-dependencies` không phải làm gì thêm. Team dùng style annotation-driven
  (`@CircuitBreaker`/`@Retry`) phải tự đổi dependency sang `resilience4j-spring-boot4`.
  **Lưu ý package đổi khác quy luật thông thường:** artifact mới **không** dùng package
  `io.github.resilience4j.springboot4.*` như tên artifact gợi ý — package thực tế là
  `io.github.resilience4j.springboot.*` (bỏ hẳn số phiên bản Boot). Service tự khai
  `@AutoConfiguration(beforeName = "...")`/`afterName` trỏ vào lớp
  `CircuitBreakerAutoConfiguration`/`RetryAutoConfiguration`/`RateLimiterAutoConfiguration` của
  resilience4j phải đổi cả ba chuỗi FQCN.
- **`RestClientCustomizer` dời package:**
  `org.springframework.boot.web.client.RestClientCustomizer` →
  `org.springframework.boot.restclient.RestClientCustomizer` (artifact
  `org.springframework.boot:spring-boot-restclient`, khai optional). Service tự implement
  `RestClientCustomizer` (ví dụ để tùy biến `RestClient.Builder` do Boot cấp) phải đổi import.
- **`spring-boot-starter-aop` không còn tồn tại ở Boot 4.1 — đổi tên thành
  `spring-boot-starter-aspectj`.** Đã kiểm: `spring-boot-starter-aop:4.1.0` trả **HTTP 404**
  trên Maven Central; BOM `spring-boot-dependencies:4.1.0`
  (`spring-boot-dependencies-4.1.0.pom` trong `~/.m2`) không quản `spring-boot-starter-aop` mà
  quản `spring-boot-starter-aspectj` (và `spring-boot-starter-aspectj-test`), cả hai đều
  publish thật (HTTP 200). Team dùng style annotation-driven
  (`@CircuitBreaker`/`@Retry`/`@RateLimiter` — xem mục resilience4j ở trên) phải khai
  `spring-boot-starter-aspectj` thay vì `spring-boot-starter-aop`, nếu không sẽ gặp
  `Could not resolve dependencies ... spring-boot-starter-aop:jar:4.1.0 was not found`.
- **`org.springframework.retry:spring-retry` không còn tới tay consumer của
  `javalibs-datahub-spring-boot-starter` qua đường transitive.** spring-kafka 3.3.7 (1.0.x) →
  4.1.0 (2.0.x) bỏ phụ thuộc `spring-retry` — đã kiểm bằng `mvn dependency:tree` (không dùng cờ
  `-q`): ở 1.0.x, `spring-kafka:jar:3.3.7:compile` kéo
  `org.springframework.retry:spring-retry:jar:2.0.12:compile`; ở 2.0.x,
  `spring-kafka:jar:4.1.0:compile` không còn dòng `spring-retry` nào trong cây. javalibs không
  tự dùng `spring-retry` (grep toàn repo: 0 kết quả) nên javalibs không bị ảnh hưởng, nhưng
  service nào đang dùng `@Retryable`/`RetryTemplate` (Spring Retry) mà trước giờ ăn ké
  `spring-retry` transitively qua `javalibs-datahub-spring-boot-starter` sẽ vỡ build/runtime khi
  nâng lên 2.0.x — phải tự khai `org.springframework.retry:spring-retry` tường minh trong pom
  của service.

## Thay đổi hành vi

_(mọi test bị sửa vì hành vi đổi — loại (b) — phải có mục ở đây)_

**Rỗng, có chủ đích — đã kiểm chứng qua toàn bộ 12 task migration (bậc 0–9 + test bảo vệ),
không phải bỏ sót.** Mọi sửa đổi test trong suốt migration đều được phân loại (a) — API dời
chỗ/đổi arity do Boot 4/Spring 7/Jackson 3/Testcontainers 2 tự đổi, không phải javalibs chủ
động đổi hành vi; assertion và kỳ vọng của test giữ nguyên. Bằng chứng cụ thể nhất, ở đúng chỗ
rủi ro hành vi cao nhất (serialize cache): `RedisSerializerFormatTest` — chụp hình dạng JSON
trên Boot 3.5.3/Jackson 2 và **không được sửa** khi Task 10 chuyển sang Jackson 3 — vẫn xanh
sau migration (xem mục "Mốc định dạng cache Redis" bên dưới). Nếu một task tương lai đổi hành
vi thật (ví dụ xử lý nợ kỹ thuật ở mục "Để lại cho sau" dưới đây), mục này phải có entry.

## Để lại cho sau

- **`RedisCacheConfigurations` dùng `activateDefaultTyping` với validator chấp nhận mọi
  subtype.** Ở dòng 1.0.x đây là `LaissezFaireSubTypeValidator` của Jackson 2 (public API).
  Jackson 3 vẫn có lớp y hệt về logic
  (`tools.jackson.databind.jsontype.impl.LaissezFaireSubTypeValidator`) nhưng đã thu hẹp
  xuống package-private, không còn là API tương thích để gọi từ ngoài — nên
  `javalibs-cache-spring` (bậc 8, `RedisCacheConfigurations.java`) tự viết lớp thay thế
  `UnsafeAnySubTypeValidator` (private, nội bộ module), sao lại đúng ba phương thức
  (`validateBaseType` → `INDETERMINATE`, `validateSubClassName`/`validateSubType` →
  `ALLOWED`) đã disassemble để xác nhận khớp bytecode gốc. Đây là mẫu có rủi ro
  deserialization (chấp nhận mọi subtype khi polymorphic deserialize). **Nợ kỹ thuật không
  đổi, chỉ đổi chỗ ở** — giữ nguyên ở 2.0.0 vì sửa nó (thu hẹp danh sách subtype được phép) là
  đổi hành vi thật; xử lý ở một thay đổi riêng có chủ đích, không lẫn vào migration này.
- **`javalibs-security-issuer` khai `com.fasterxml.jackson.datatype:jackson-datatype-jsr310`
  (Jackson 2) ở scope compile, không `<optional>`, mà không ai dùng.** `grep` toàn bộ
  `javalibs-security-issuer/src` ra 0 tham chiếu Jackson; `jjwt-jackson:0.12.6` — thứ duy nhất
  trong module thật sự cần Jackson — tự khai `jackson-databind` riêng của nó (đã kiểm
  `jjwt-jackson-0.12.6.pom`), không cần `jackson-datatype-jsr310`. Hệ quả: `jackson-databind`
  2.x lọt lên **compile classpath** của `javalibs-authz-jpa` và mọi service phụ thuộc issuer
  (transitively, vì `javalibs-authz-jpa` khai `javalibs-security-issuer` là
  `<optional>true</optional>`). **Cạm bẫy "biên dịch xanh nhưng chết lúc chạy":** lập trình
  viên gõ `import com.fasterxml.jackson.databind.ObjectMapper` sẽ biên dịch xanh (class có mặt
  trên compile classpath), nhưng bean `ObjectMapper` mà Boot 4.1 autowire là
  `tools.jackson.databind.ObjectMapper` (Jackson 3) →
  `NoSuchBeanDefinitionException`/`BeanNotOfRequiredTypeException` lúc khởi động nếu code lỡ
  khai kiểu tường minh theo `com.fasterxml.jackson.databind.ObjectMapper`. Đây là nợ mang từ
  1.0.x, không phải hồi quy của migration Boot 4.1 — gỡ dependency này khỏi pom là thay đổi
  phụ thuộc có chủ đích, để ở một đợt riêng, không lẫn vào migration này.

## Jackson 2.x còn sót trong dependency tree (không kiểm soát được)

**Sự thật, không diễn giải cho qua:** `mvn dependency:tree` ở dòng 2.0.x vẫn liệt kê nhiều
artifact `com.fasterxml.jackson.*` phiên bản 2.x. Code Java của javalibs **hoàn toàn** ở
Jackson 3 (`tools.jackson.*`) từ bậc 8 — không còn `import com.fasterxml.jackson.databind.*`
nào trong `src/main` của javalibs. Nhưng hai lớp lý do khiến Jackson 2 vẫn nằm trên classpath
runtime của một số module, ngoài tầm kiểm soát của javalibs:

1. **`com.fasterxml.jackson.core:jackson-annotations:2.21` — xuất hiện ở HẦU HẾT module dùng
   Jackson.** Đây không phải lỗi hay sót của javalibs: bản thân `tools.jackson.core:jackson-databind`
   (Jackson 3.1.4, artifact CHÍNH THỐNG của Jackson 3) khai `jackson-annotations` như một
   dependency bắt buộc, và annotations module giữ nguyên groupId/artifactId lịch sử
   (`com.fasterxml.jackson.core:jackson-annotations`) với dòng version riêng 2.x — annotations
   dùng chung được cho cả hệ Jackson 2 lẫn 3 nên không cần rearchitect. Bằng chứng: Spring Boot
   4.1 tự import CẢ HAI BOM `com.fasterxml.jackson:jackson-bom:2.21.4` lẫn
   `tools.jackson:jackson-bom:3.1.4` trong `spring-boot-dependencies` (thấy ở
   `spring-boot-dependencies-4.1.0.pom`, property `jackson-2-bom.version` / `jackson-bom.version`),
   tức Boot 4.1 CHÍNH THỨC coi việc Jackson 2 và 3 cùng tồn tại trên classpath là trạng thái
   bình thường của hệ sinh thái trong giai đoạn chuyển tiếp. **Đây không phải "còn sót Jackson
   2.x" theo nghĩa DoD lo ngại** (không có `jackson-databind`/`jackson-core` 2.x nào bị dùng để
   serialize dữ liệu của javalibs) — chỉ là artifact annotation dùng chung, an toàn.
2. **Full stack Jackson 2 (`jackson-core` + `jackson-databind`, 2.21.4) — hai nguồn thật, có chủ
   đích, không gỡ được; cộng thêm một khoản nợ compile-scope không ai dùng, tách riêng bên dưới:**
   - `javalibs-security-core`: thư viện `io.jsonwebtoken:jjwt-jackson:0.12.6` (serializer JSON
     cho JJWT) chỉ hỗ trợ Jackson 2, chưa có bản Jackson 3; bản thân `jjwt-jackson` tự khai
     `com.fasterxml.jackson.core:jackson-databind` (đã kiểm `jjwt-jackson-0.12.6.pom` trong
     `~/.m2`: chỉ có `jjwt-api` + `jackson-databind`, **không** có `jackson-datatype-jsr310`).
     `jjwt-jackson` được khai ở **`javalibs-security-core`** — module gốc mà
     `javalibs-security-spring-boot-starter` phụ thuộc trực tiếp — **không phải**
     `javalibs-security-issuer` như bản CHANGELOG trước đây ghi nhầm. Đã xác nhận bằng
     `mvn dependency:tree` trên `javalibs-security-spring-boot-starter`: cây chỉ đi qua
     `javalibs-security-core`, hoàn toàn không có `javalibs-security-issuer` (module này khai
     `<optional>true</optional>`, không tự kéo vào cây của consumer trừ khi tự thêm). Kết quả:
     `jackson-databind` 2.21.4 (runtime) có mặt trên classpath của **mọi** consumer của
     `javalibs-security-spring-boot-starter`, kể cả service chỉ validate JWT (không phát hành
     token, không dùng issuer) — không liên quan tới `ObjectMapper` Jackson 3 mà service tự
     inject qua DI.
   - `javalibs-openapi`: springdoc-openapi 3.1.0 → `io.swagger.core.v3:swagger-core-jakarta:2.2.52`
     → `io.swagger.core.v3:swagger-models-jakarta:2.2.52`, kéo **compile-scope** (không phải
     optional) `jackson-databind`/`jackson-core`/`jackson-dataformat-yaml`/
     `jackson-datatype-jsr310` ở 2.21.4 vì swagger-models-jakarta bản thân chưa nâng Jackson 3.
     Dependency `springdoc-openapi` của javalibs vẫn khai `<optional>true</optional>` đúng quy
     ước, nhưng bản thân stack Jackson 2 mà nó kéo theo là compile scope trong cây phụ thuộc của
     swagger, không optional.

**Ý nghĩa với người nâng cấp:** **mọi** service dùng `javalibs-security-spring-boot-starter`
(qua `javalibs-security-core` — không cần dùng `javalibs-security-issuer`) hoặc
`javalibs-openapi-spring-boot-starter` sẽ có **hai stack Jackson cùng nằm trên classpath
runtime** — Jackson 3 (`tools.jackson.*`, dùng cho `ObjectMapper` chính, cache Redis, REST
request/response body) và Jackson 2 (`com.fasterxml.jackson.*`, chỉ dùng nội bộ bởi JJWT và bởi
swagger-models khi springdoc build tài liệu OpenAPI). Hai stack không tương tác, không đọc/ghi
chung dữ liệu, không xung đột runtime. Không cần hành động gì để "dọn sạch" — cả hai nguồn đều
là phụ thuộc bên thứ ba javalibs không kiểm soát; theo dõi `jjwt-jackson` (JJWT project) và
`swagger-models-jakarta` (springdoc/swagger-core project) để biết khi nào họ phát hành bản
Jackson 3. (Về khoản `jackson-datatype-jsr310` compile-scope riêng, không ai dùng, mà
`javalibs-security-issuer` tự khai — xem mục **"Để lại cho sau"** ở trên, đây là nợ khác, không
liên quan tới hai nguồn ở trên.)

**Cảnh báo về lệnh nghiệm thu DoD của spec** — chạy đúng nguyên văn:

```
mvn -q dependency:tree 2>&1 | grep -E ":(3\.[0-9]+\.[0-9]+)" | grep -E "spring-boot|jackson|testcontainers" \
  || echo "SẠCH: không còn Boot 3.x / Jackson 2.x / Testcontainers 1.x"
```

lệnh này **IN RA "SẠCH"** — nhưng đó là kết quả giả, không phải bằng chứng thật. Cờ `-q` của
Maven làm goal `dependency:tree` (in qua logger mức INFO) **im lặng hoàn toàn** trên reactor
nhiều module — `mvn -q dependency:tree` một mình, không qua grep gì cả, đã cho ra **0 dòng output**
(đã tự kiểm chứng). Vì grep không nhận được input nào để khớp, `||` luôn rơi vào nhánh
`echo "SẠCH"`, **bất kể dependency tree thật sự chứa gì**. Đây không phải lỗi diễn giải regex —
đây là lệnh không hề chạy phép kiểm nào cả.

Chạy đúng cách (bỏ `-q`, hoặc dùng `-DoutputFile` không kèm `-q`) mới cho kết quả thật:
Spring Boot 3.x và Testcontainers 1.x **sạch tuyệt đối** — 0 artifact của hai nhóm này ở bất kỳ
module nào. Nhưng Jackson 2.x thì **không sạch** — các dòng `2.21.4`/`2.21` nêu ở trên có thật
trong `javalibs-security-core` (và mọi consumer của `javalibs-security-spring-boot-starter`,
transitively), thêm khoản riêng ở `javalibs-security-issuer`/`javalibs-authz-jpa`
(transitively) do dependency `jackson-datatype-jsr310` không ai dùng, và trong
`javalibs-openapi`.
Thêm một lớp nhiễu thứ hai nếu ai đó sửa lại lệnh bằng cách bỏ `-q`: regex `3\.[0-9]+\.[0-9]+`
của DoD khớp nhầm chính các dòng `tools.jackson.core:...:jar:3.1.4` (Jackson 3 — ĐÚNG, không
phải lỗi) vì nó không phân biệt groupId `tools.jackson` (mới) với `com.fasterxml.jackson` (cũ);
diễn giải đúng đòi hỏi lọc theo groupId, không chỉ theo số phiên bản. Xem báo cáo Task 14
(`task-14-report.md`) để có output thật (cả hai cách chạy) kèm phân tích từng dòng.

## Mốc định dạng cache Redis ở dòng 1.0.x

Chụp trên Boot 3.5.3 / Jackson 2 bằng `RedisSerializerFormatTest`. Task 10 đối chiếu với
mốc này để biết Jackson 3 có làm đổi định dạng hay không:

```json
{"@class":"DumpFormat$Sample","name":"tour","day":["java.time.LocalDate","2026-08-02"]}
```

**Kết luận: định dạng KHÔNG đổi — byte-for-byte giống 1.0.x.** `RedisSerializerFormatTest`
giữ nguyên nội dung từ trước migration (không được sửa để "vừa" hành vi mới — xem mục "Thay
đổi hành vi" ở trên) và vẫn xanh trên Jackson 3: entry vẫn nhúng `"@class"` với FQCN đầy đủ,
`java.time.LocalDate` vẫn serialize dạng mảng ISO `["java.time.LocalDate","2026-08-02"]`.
**Service nâng lên javalibs 2.0.x không cần flush cache Redis** — entry cũ (ghi bởi 1.0.x)
deserialize được bình thường bởi code 2.0.x, và ngược lại trong giai đoạn rolling upgrade.
