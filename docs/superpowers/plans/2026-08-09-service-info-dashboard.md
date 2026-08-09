# Service Info API + Dashboard — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mỗi service một API `GET .../info` trả thông tin chi tiết (tĩnh + uptime + trạng thái hạ tầng), và một dashboard React + Vite gọi qua gateway hiển thị 6 thẻ service.

**Architecture:** 5 service nghiệp vụ thêm controller info dưới prefix route có sẵn của mình, trả `ApiResponse` của javalibs-web; gateway thêm controller `/api/gateway/info` (tự viết envelope cùng hình dạng — nó không dùng javalibs) kèm bảng route, và một `CorsFilter` cho origin Vite. Frontend nằm ở `frontend/` ngoài reactor Maven, poll 6 endpoint mỗi 10s bằng `Promise.allSettled`.

**Tech Stack:** Java 21 · Spring Boot 4.1.0 · javalibs 2.0.0-SNAPSHOT · React 19 + Vite · Testcontainers (qua javalibs-test)

**Spec:** [docs/superpowers/specs/2026-08-09-service-info-dashboard-design.md](../specs/2026-08-09-service-info-dashboard-design.md)

## Global Constraints

- **Thư mục gốc:** `/Users/tanvx/Dev/bank-platform`, làm trên branch `feat/service-info-dashboard` (tách từ `master`, KHÔNG dùng worktree — tiền lệ của dự án).
- **`JAVA_HOME` không set sẵn trong shell non-interactive** — export trước mọi lệnh `mvn` (JDK 21 có trên máy).
- **Docker phải chạy** — Testcontainers (test) và compose (nghiệm thu). Máy dùng chung: KHÔNG dừng/xoá container của project khác; không cần `docker compose down -v` ở bất kỳ bước nào.
- **Không sửa `platform-libs/`.** Không đưa gì mới vào `bank-common`.
- Ràng buộc "đúng 6 file `.java`" của phase scaffolding **hết hiệu lực** — số file `.java` tăng là chủ đích của feature này. Đừng "sửa lại cho đủ 6". Cập nhật luôn câu này nếu gặp trong README.
- Comment tiếng Việt, giải thích *vì sao*. Tên test dạng `*Test` (KHÔNG phải `*IT` — surefire mặc định không chạy `*IT`, test sẽ bị bỏ qua trong im lặng).
- Không thêm mã lỗi `ERR-*` mới (API chỉ đọc, không nhánh lỗi nghiệp vụ).
- **Bẫy `permit-all`:** `javalibs.security.permit-all` là list — khai trong yml là THAY THẾ list mặc định, không phải nối thêm. Phải khai lại đủ 7 đường mặc định + đường info (xem code từng task).
- Các API/kết luận sau đã xác minh trên jar thật ngày 2026-08-09, đừng "sửa" lại theo trí nhớ:
  - `HealthEndpoint.health()` trả `HealthDescriptor`; cast `CompositeHealthDescriptor` → `getComponents(): Map<String, HealthDescriptor>` → `getStatus().getCode()`. Package `org.springframework.boot.health.actuate.endpoint` / `...health.contributor`.
  - **Boot 4.1 không có health indicator nào cho Kafka** — reviewer Task 1 soát cả `spring-boot-actuator`, `spring-boot-actuator-autoconfigure`, `spring-boot-kafka` lẫn `spring-kafka` 4.1.0: không jar nào chứa lớp health Kafka (kể cả cho Kafka Streams — đừng viết lại câu "chỉ có cho Streams", nó sai). Bảng dependencies không có dòng `kafka`; whitelist vẫn chứa `"kafka"` để khi nào có indicator là tự hiện.
  - `@AutoConfigureMockMvc` Boot 4.1 nằm ở `org.springframework.boot.webmvc.test.autoconfigure` (jar `spring-boot-webmvc-test`, KHÔNG có trong starter-test).
  - `TestRestTemplate` Boot 4.1 nằm ở `org.springframework.boot.resttestclient`.
  - `GatewayMvcProperties` (`org.springframework.cloud.gateway.server.mvc.config`): `getRoutes(): List<RouteProperties>`; `RouteProperties.getId()/getUri()/getPredicates()`; `PredicateProperties.getName()/getArgs()`.

### Bảng hằng số 5 service nghiệp vụ (dùng xuyên suốt, không tự chế biến)

| | path info | port | db-schema | error-code-prefix | structure-level | package controller/DTO |
|---|---|---|---|---|---|---|
| auth | `/api/auth/info` | 8081 | `auth` | `ERR-AUTH` | `B — layered gọn` | `web` / `web.dto` |
| product | `/api/products/info` | 8083 | `product` | `ERR-PROD` | `B — layered gọn` | `web` / `web.dto` |
| notification | `/api/notifications/info` | 8085 | `notification` | `ERR-NOTI` | `B — layered gọn` | `web` / `web.dto` |
| core-banking | `/api/accounts/info` | 8084 | `core_banking` | `ERR-CORE` | `A — chia theo aggregate` | `api` / `api.dto` |
| customer | `/api/customers/info` | 8082 | `customer` | `ERR-CUST` | `A — phẳng` | `api` / `api.dto` |

`description` (chép nguyên văn từ `<description>` trong pom từng service):
- auth: `Định danh và phát hành token. Không biết gì về tài khoản ngân hàng.`
- product: `Danh mục sản phẩm: lãi suất, biểu phí, hạn mức, điều kiện mở, ánh xạ GL.`
- notification: `Nghe event và gửi thông báo qua Telegram/Email/Webhook.`
- core-banking: `Sổ cái bút toán kép, tài khoản, hold, chuyển tiền, lãi và phí.`
- customer: `CIF: hồ sơ khách hàng, giấy tờ, địa chỉ, liên hệ, KYC, đánh giá rủi ro.`

Redis chỉ có ở **auth** và **product** (hai service duy nhất có `spring.data.redis`) — chỉ hai service đó có dòng `redis` trong dependencies.

---

### Task 1: auth-service — info API (khuôn mẫu) + `build-info` ở root pom

**Files:**
- Modify: `pom.xml` (root — thêm `<build><pluginManagement>`)
- Modify: `services/auth-service/pom.xml` (thêm `spring-boot-starter-data-redis` — xem chú thích trước Step 7)
- Create: `services/auth-service/src/main/java/io/bankplatform/auth/config/ServiceInfoProperties.java`
- Create: `services/auth-service/src/main/java/io/bankplatform/auth/web/dto/ServiceInfoResponse.java`
- Create: `services/auth-service/src/main/java/io/bankplatform/auth/web/dto/DependencyStatus.java`
- Create: `services/auth-service/src/main/java/io/bankplatform/auth/web/ServiceInfoController.java`
- Modify: `services/auth-service/src/main/java/io/bankplatform/auth/AuthApplication.java` (thêm `@ConfigurationPropertiesScan`)
- Modify: `services/auth-service/src/main/resources/application.yml` (khối `bank.info` + `permit-all`)
- Test: `services/auth-service/src/test/java/io/bankplatform/auth/web/ServiceInfoApiTest.java`

**Interfaces:**
- Consumes: `io.javalibs.web.ApiResponse.ok(T)` — record `(boolean success, T data, String message, Instant timestamp, String traceId)`; `io.javalibs.test.BaseIntegrationTest` (bật profile `test` + Postgres Testcontainers, override `spring.datasource.*`).
- Produces: khuôn 4 file mà Task 2 và 3 sao chép; JSON contract mà Task 5 (frontend) đọc: `GET <path> → 200 {"success":true,"data":{serviceName,description,version,port,structureLevel,dbSchema,errorCodePrefix,javaVersion,springBootVersion,startedAt,uptimeSeconds,dependencies:[{name,status}]}}`.

- [ ] **Step 1: Tạo branch**

```bash
cd /Users/tanvx/Dev/bank-platform && git checkout -b feat/service-info-dashboard master
```

- [ ] **Step 2: Viết test fail trước**

`services/auth-service/src/test/java/io/bankplatform/auth/web/ServiceInfoApiTest.java`:

```java
package io.bankplatform.auth.web;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.javalibs.test.BaseIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.resttestclient.TestRestTemplate;
import org.springframework.http.ResponseEntity;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Test full-context: chứng minh endpoint đi qua được javalibs-security mà
 * KHÔNG cần JWT (đây là điều slice test không chứng minh nổi — autoconfigure
 * của javalibs không được nạp trong @WebMvcTest).
 */
class ServiceInfoApiTest extends BaseIntegrationTest {

    @Autowired
    TestRestTemplate rest;

    private final ObjectMapper mapper = new ObjectMapper();

    @Test
    void traVeThongTinServiceKhongCanJwt() throws Exception {
        ResponseEntity<String> response = rest.getForEntity("/api/auth/info", String.class);

        assertThat(response.getStatusCode().value()).isEqualTo(200);
        JsonNode body = mapper.readTree(response.getBody());
        assertThat(body.path("success").asBoolean()).isTrue();

        JsonNode data = body.path("data");
        assertThat(data.path("serviceName").asText()).isEqualTo("auth-service");
        assertThat(data.path("description").asText())
                .isEqualTo("Định danh và phát hành token. Không biết gì về tài khoản ngân hàng.");
        assertThat(data.path("port").asInt()).isEqualTo(8081);
        assertThat(data.path("structureLevel").asText()).isEqualTo("B — layered gọn");
        assertThat(data.path("dbSchema").asText()).isEqualTo("auth");
        assertThat(data.path("errorCodePrefix").asText()).isEqualTo("ERR-AUTH");
        assertThat(data.path("version").asText()).isNotBlank();
        // Ghim build-info thật sự chạy: bỏ execution ở root pom thì rơi về
        // fallback "unknown" và dòng dưới phải fail lộ ra ngay, không âm thầm.
        assertThat(data.path("version").asText()).isNotEqualTo("unknown");
        assertThat(data.path("springBootVersion").asText()).isEqualTo("4.1.0");
        assertThat(data.path("uptimeSeconds").asLong()).isGreaterThanOrEqualTo(0);

        // db là Postgres của Testcontainers -> phải UP. redis không chạy trong
        // test nên chỉ cần dòng nó CÓ MẶT (auth có DataRedisHealthIndicator),
        // không assert giá trị.
        assertThat(statusOf(data, "db")).isEqualTo("UP");
        assertThat(dependencyNames(data)).contains("redis");
    }

    private String statusOf(JsonNode data, String name) {
        for (JsonNode dep : data.path("dependencies")) {
            if (name.equals(dep.path("name").asText())) {
                return dep.path("status").asText();
            }
        }
        return null;
    }

    private java.util.List<String> dependencyNames(JsonNode data) {
        var names = new java.util.ArrayList<String>();
        data.path("dependencies").forEach(dep -> names.add(dep.path("name").asText()));
        return names;
    }
}
```

- [ ] **Step 3: Chạy test, xác nhận fail đúng lý do**

```bash
cd /Users/tanvx/Dev/bank-platform && export JAVA_HOME=$(/usr/libexec/java_home -v 21) && mvn -pl services/auth-service -P'!with-libs' test 2>&1 | tail -20
```

Expected: FAIL — 404 cho `/api/auth/info`... **hoặc 401**. Cả hai đều là "chưa có endpoint/chưa mở cửa", đều hợp lệ ở bước này. Nếu fail vì lý do khác (context không boot được), dừng và báo — đừng đi tiếp trên nền hỏng.

- [ ] **Step 4: Thêm `build-info` vào root pom**

Trong `pom.xml` (root), NGAY SAU `</dependencyManagement>` và TRƯỚC `<profiles>`, thêm:

```xml
  <build>
    <pluginManagement>
      <plugins>
        <plugin>
          <groupId>org.springframework.boot</groupId>
          <artifactId>spring-boot-maven-plugin</artifactId>
          <executions>
            <!--
              Sinh build-info.properties để BuildProperties tồn tại lúc runtime —
              nguồn của trường "version" trong API /info. Đặt ở pluginManagement
              nên áp cho MỌI service (chúng đều khai plugin này), một chỗ duy nhất.
              platform-libs không nhận pom này làm parent nên không bị ảnh hưởng.
            -->
            <execution>
              <goals>
                <goal>build-info</goal>
              </goals>
            </execution>
          </executions>
        </plugin>
      </plugins>
    </pluginManagement>
  </build>
```

- [ ] **Step 5: Viết properties + DTO**

`services/auth-service/src/main/java/io/bankplatform/auth/config/ServiceInfoProperties.java`:

```java
package io.bankplatform.auth.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Thông tin service TỰ KHAI về mình (khối bank.info trong application.yml).
 * port ở đây là cổng CÔNG BỐ của service, không đọc từ server.port — vì test
 * chạy RANDOM_PORT làm server.port thành 0, còn dashboard cần cổng thật.
 */
@ConfigurationProperties(prefix = "bank.info")
public record ServiceInfoProperties(
        String description,
        String structureLevel,
        String dbSchema,
        String errorCodePrefix,
        int port) {
}
```

`services/auth-service/src/main/java/io/bankplatform/auth/web/dto/ServiceInfoResponse.java`:

```java
package io.bankplatform.auth.web.dto;

import java.time.Instant;
import java.util.List;

/** Payload của GET /api/auth/info — hợp đồng với frontend dashboard. */
public record ServiceInfoResponse(
        String serviceName,
        String description,
        String version,
        int port,
        String structureLevel,
        String dbSchema,
        String errorCodePrefix,
        String javaVersion,
        String springBootVersion,
        Instant startedAt,
        long uptimeSeconds,
        List<DependencyStatus> dependencies) {
}
```

`services/auth-service/src/main/java/io/bankplatform/auth/web/dto/DependencyStatus.java`:

```java
package io.bankplatform.auth.web.dto;

/** Trạng thái một hạ tầng service phụ thuộc, đọc từ actuator HealthEndpoint. */
public record DependencyStatus(String name, String status) {
}
```

- [ ] **Step 6: Viết controller**

`services/auth-service/src/main/java/io/bankplatform/auth/web/ServiceInfoController.java`:

```java
package io.bankplatform.auth.web;

import io.bankplatform.auth.config.ServiceInfoProperties;
import io.bankplatform.auth.web.dto.DependencyStatus;
import io.bankplatform.auth.web.dto.ServiceInfoResponse;
import io.javalibs.web.ApiResponse;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.SpringBootVersion;
import org.springframework.boot.health.actuate.endpoint.CompositeHealthDescriptor;
import org.springframework.boot.health.actuate.endpoint.HealthEndpoint;
import org.springframework.boot.info.BuildProperties;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.lang.management.ManagementFactory;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;

/**
 * Thông tin chi tiết của service cho dashboard dev.
 *
 * <p>Nằm trong permit-all có chủ đích: chưa tồn tại luồng phát JWT nào
 * (auth-service chưa có nghiệp vụ), nên bắt xác thực ở đây là khoá luôn
 * dashboard. Chỉ trả metadata dev — không secret, không connection string.</p>
 */
@RestController
public class ServiceInfoController {

    /**
     * Chỉ ba hạ tầng này đáng hiển thị — các component còn lại của actuator
     * (diskSpace, ping, ssl) là nhiễu với dashboard. "kafka" nằm sẵn trong
     * danh sách dù Boot 4.1 KHÔNG có health indicator nào cho Kafka — đã soát
     * cả actuator, spring-boot-kafka lẫn spring-kafka 4.1.0, không jar nào
     * chứa lớp health Kafka. Khi nào có indicator (tự viết hay Boot thêm),
     * dòng kafka tự xuất hiện mà không phải sửa code.
     */
    private static final Set<String> WATCHED_DEPENDENCIES = Set.of("db", "redis", "kafka");

    private final ServiceInfoProperties properties;
    private final HealthEndpoint healthEndpoint;
    private final String serviceName;
    private final String version;

    ServiceInfoController(ServiceInfoProperties properties,
                          HealthEndpoint healthEndpoint,
                          @Value("${spring.application.name}") String serviceName,
                          ObjectProvider<BuildProperties> buildProperties) {
        this.properties = properties;
        this.healthEndpoint = healthEndpoint;
        this.serviceName = serviceName;
        // BuildProperties chỉ tồn tại khi goal build-info đã chạy (mvn); chạy
        // từ IDE có thể thiếu — fallback thay vì chết lúc khởi động.
        BuildProperties build = buildProperties.getIfAvailable();
        this.version = build != null ? build.getVersion() : "unknown";
    }

    @GetMapping("/api/auth/info")
    public ApiResponse<ServiceInfoResponse> info() {
        var runtime = ManagementFactory.getRuntimeMXBean();
        return ApiResponse.ok(new ServiceInfoResponse(
                serviceName,
                properties.description(),
                version,
                properties.port(),
                properties.structureLevel(),
                properties.dbSchema(),
                properties.errorCodePrefix(),
                Runtime.version().toString(),
                SpringBootVersion.getVersion(),
                Instant.ofEpochMilli(runtime.getStartTime()),
                runtime.getUptime() / 1000,
                dependencies()));
    }

    private List<DependencyStatus> dependencies() {
        List<DependencyStatus> result = new ArrayList<>();
        if (healthEndpoint.health() instanceof CompositeHealthDescriptor composite) {
            composite.getComponents().forEach((name, descriptor) -> {
                if (WATCHED_DEPENDENCIES.contains(name)) {
                    result.add(new DependencyStatus(name, descriptor.getStatus().getCode()));
                }
            });
        }
        return result;
    }
}
```

**Chú thích bắt buộc trước Step 7 — `spring-boot-starter-data-redis`:** thêm vào `<dependencies>` của `services/auth-service/pom.xml` (cạnh `javalibs-cache-spring-boot-starter`):

```xml
    <!--
      Auth KHÔNG bật @EnableCaching, nên JavalibsRedisCacheAutoConfiguration
      (gate @ConditionalOnBean(CacheAspectSupport.class)) không kích hoạt ở
      đây dù có dependency này — khác với product, nơi comment tương tự nói
      về cache thật sự đúng. Cái auth cần từ dependency này là hai thứ khác:
      (1) bean RedisConnectionFactory/StringRedisTemplate mà
      javalibs.security.blacklist.mode=redis sẽ cần khi bật revoke token
      (mặc định mode là "none" — chưa dùng ngay, nhưng bean phải sẵn để
      chuyển mode không cần đổi dependency sau này); (2) DataRedisHealthIndicator
      của actuator, thứ đưa dòng "redis" vào dependencies của GET
      /api/auth/info — đúng thứ ServiceInfoApiTest assert
      (dependencyNames(data).contains("redis")). application.yml đã cấu hình
      spring.data.redis.* sẵn.
    -->
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-data-redis</artifactId>
    </dependency>
```

Ở **product (Task 2)**, comment cạnh dependency này KHÁC HẲN vì lý do khác:
product CÓ `@EnableCaching` (dùng javalibs-cache cho catalog), nên đây đúng là
trường hợp `JavalibsRedisCacheAutoConfiguration` không có `RedisConnectionFactory`
để inject nên không kích hoạt — giữ nguyên bản comment "mặc định Caffeine,
thiếu dependency thì HealthEndpoint không có component redis, sai với mục
đích cache catalog qua Redis lẫn với application.yml đã cấu hình
spring.data.redis.*". Đừng chép nguyên văn comment của auth sang product hay
ngược lại — hai service kích hoạt Redis theo hai cơ chế khác nhau (security
blacklist mode ở auth vs. cache autoconfiguration ở product). Cùng họ lỗi im
lặng với spring-boot-flyway và spring-boot-kafka của plan trước, nhưng cơ chế
kích hoạt không giống nhau nên comment không được dùng chung.

Áp cho auth (task này) và **product (Task 2)** — hai service duy nhất có `spring.data.redis` trong yml. Notification/core-banking/customer KHÔNG thêm.

- [ ] **Step 7: Bật `@ConfigurationPropertiesScan` và cấu hình yml**

`AuthApplication.java` — thêm import và annotation (giữ nguyên phần còn lại):

```java
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

@SpringBootApplication
@ConfigurationPropertiesScan
public class AuthApplication {
```

`services/auth-service/src/main/resources/application.yml` — thêm khối `bank` ở CUỐI FILE, và thêm `permit-all` vào khối `javalibs.security` có sẵn (giữ nguyên `jwt.secret`):

```yaml
javalibs:
  security:
    jwt:
      secret: ${JWT_SECRET}
    # DANH SÁCH NÀY THAY THẾ danh sách mặc định của javalibs-security, không
    # phải nối thêm — nên phải chép lại đủ 7 đường mặc định. Thiếu một dòng là
    # khoá swagger/actuator trong im lặng.
    permit-all:
      - /actuator/health
      - /actuator/health/**
      - /actuator/info
      - /error
      - /v3/api-docs/**
      - /swagger-ui/**
      - /swagger-ui.html
      # info công khai có chủ đích: chưa có luồng phát JWT, và payload chỉ là
      # metadata dev (không secret, không connection string).
      - /api/auth/info

bank:
  info:
    description: "Định danh và phát hành token. Không biết gì về tài khoản ngân hàng."
    structure-level: "B — layered gọn"
    db-schema: auth
    error-code-prefix: ERR-AUTH
    port: 8081
```

- [ ] **Step 8: Chạy test, xác nhận pass**

```bash
cd /Users/tanvx/Dev/bank-platform && export JAVA_HOME=$(/usr/libexec/java_home -v 21) && mvn -pl services/auth-service -P'!with-libs' test 2>&1 | tail -15
```

Expected: `BUILD SUCCESS`, `Tests run: 1, Failures: 0`.

- [ ] **Step 9: Commit**

```bash
cd /Users/tanvx/Dev/bank-platform
git add pom.xml services/auth-service
git commit -m "feat(auth): API /api/auth/info — khuôn mẫu cho 5 service

Trả metadata tĩnh (bank.info.*), version từ BuildProperties (build-info bật
ở root pom cho cả reactor), uptime từ JVM, trạng thái hạ tầng đọc qua
HealthEndpoint. Endpoint vào permit-all vì chưa có luồng phát JWT.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: product-service + notification-service — áp khuôn (Mức B)

**Files:**
- Create (product): `services/product-service/src/main/java/io/bankplatform/product/config/ServiceInfoProperties.java`, `.../product/web/dto/ServiceInfoResponse.java`, `.../product/web/dto/DependencyStatus.java`, `.../product/web/ServiceInfoController.java`
- Create (notification): `services/notification-service/src/main/java/io/bankplatform/notification/config/ServiceInfoProperties.java`, `.../notification/web/dto/ServiceInfoResponse.java`, `.../notification/web/dto/DependencyStatus.java`, `.../notification/web/ServiceInfoController.java`
- Modify: `ProductApplication.java`, `NotificationApplication.java` (thêm `@ConfigurationPropertiesScan`), `application.yml` của cả hai
- Test: `services/product-service/src/test/java/io/bankplatform/product/web/ServiceInfoApiTest.java`, `services/notification-service/src/test/java/io/bankplatform/notification/web/ServiceInfoApiTest.java`

**Interfaces:**
- Consumes: khuôn 4 file của Task 1 (đọc `services/auth-service/` trên đĩa làm mẫu đối chiếu).
- Produces: `GET /api/products/info` và `GET /api/notifications/info`, cùng JSON contract với Task 1.

Bốn file Java + test của mỗi service **giống hệt Task 1** ngoài các thay thế sau — áp bảng hằng số ở Global Constraints, không tự chế biến:

| Thay | product | notification |
|---|---|---|
| package gốc | `io.bankplatform.product` | `io.bankplatform.notification` |
| `@GetMapping` | `"/api/products/info"` | `"/api/notifications/info"` |
| yml `bank.info` | description/level/schema/prefix/port theo bảng | theo bảng |
| yml `permit-all` dòng cuối | `- /api/products/info` | `- /api/notifications/info` |
| test đường gọi + giá trị assert | theo bảng | theo bảng |
| test dependencies | `db` UP **và** `contains("redis")` (product có redis) | CHỈ `db` UP — notification KHÔNG có redis, thêm `assertThat(dependencyNames(data)).doesNotContain("redis")` |
| pom service | THÊM `spring-boot-starter-data-redis` + comment RIÊNG của product — lý do cache, KHÔNG chép comment của auth (xem chú thích trước Step 7 của Task 1 — thiếu dependency là assertion redis không bao giờ thoả) | KHÔNG thêm gì vào pom |

Ba lưu ý khi chép mà bảng không nói:

1. Javadoc của controller ở dòng "auth-service chưa có nghiệp vụ" — đổi thành lý do đúng của permit-all cho MỌI service: `Nằm trong permit-all có chủ đích: hệ chưa có luồng phát JWT nào, nên bắt xác thực ở đây là khoá luôn dashboard.` (Task 1 dùng câu này luôn cho auth cũng đúng — nếu muốn đồng nhất thì thôi, giữ nguyên văn Task 1.)
2. Khối `javalibs.security` của notification hiện KHÔNG có `permit-all` — thêm mới nguyên khối như Task 1 Step 7 (đổi dòng cuối). Khối của product cũng vậy.
3. `DependencyStatus`/`ServiceInfoResponse` là bản chép nguyên văn đổi mỗi dòng `package` — đó là chủ đích (bank-common cấm REST DTO), đừng "khéo léo" tạo module chung.
4. Test của product sẽ in một stack trace `RedisConnectionException: Unable to connect to localhost:6379` trong lúc VẪN PASS — Redis không chạy trong môi trường test, indicator báo DOWN là đúng thiết kế (test chỉ assert dòng redis CÓ MẶT). Đừng tưởng là fail, đừng "sửa". Auth ở Task 1 cũng in y như vậy.

- [ ] **Step 1: Viết 2 test fail trước** (chép `ServiceInfoApiTest` của Task 1 Step 2, áp bảng thay thế trên)
- [ ] **Step 2: Chạy, xác nhận cả hai fail vì 404/401**

```bash
cd /Users/tanvx/Dev/bank-platform && export JAVA_HOME=$(/usr/libexec/java_home -v 21) && mvn -pl services/product-service,services/notification-service -P'!with-libs' test 2>&1 | tail -20
```

- [ ] **Step 3: Chép 4 file Java vào mỗi service theo bảng thay thế; sửa 2 Application class; sửa 2 application.yml**
- [ ] **Step 4: Chạy test, xác nhận pass**

```bash
cd /Users/tanvx/Dev/bank-platform && export JAVA_HOME=$(/usr/libexec/java_home -v 21) && mvn -pl services/product-service,services/notification-service -P'!with-libs' test 2>&1 | tail -15
```

Expected: `Tests run: 1` × 2 module, 0 failures.

- [ ] **Step 5: Commit**

```bash
cd /Users/tanvx/Dev/bank-platform
git add services/product-service services/notification-service
git commit -m "feat(product,notification): API info theo khuôn auth-service

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: core-banking-service + customer-service — áp khuôn (Mức A)

**Files:**
- Create (core-banking): `services/core-banking-service/src/main/java/io/bankplatform/corebanking/config/ServiceInfoProperties.java`, `.../corebanking/api/dto/ServiceInfoResponse.java`, `.../corebanking/api/dto/DependencyStatus.java`, `.../corebanking/api/ServiceInfoController.java`
- Create (customer): `services/customer-service/src/main/java/io/bankplatform/customer/config/ServiceInfoProperties.java`, `.../customer/api/dto/ServiceInfoResponse.java`, `.../customer/api/dto/DependencyStatus.java`, `.../customer/api/ServiceInfoController.java`
- Modify: `CoreBankingApplication.java`, `CustomerApplication.java`, `application.yml` của cả hai
- Test: `services/core-banking-service/src/test/java/io/bankplatform/corebanking/api/ServiceInfoApiTest.java`, `services/customer-service/src/test/java/io/bankplatform/customer/api/ServiceInfoApiTest.java`

**Interfaces:**
- Consumes: khuôn Task 1.
- Produces: `GET /api/accounts/info` (core-banking) và `GET /api/customers/info` (customer), cùng JSON contract.

Khác Task 2 đúng một điểm cấu trúc: controller và DTO nằm trong **`api/` và `api/dto/`** (không phải `web/`) — đây là cấu trúc Mức A của hai service này; test cũng nằm trong package `...api`. Package `config/` giữ nguyên vai trò chứa `ServiceInfoProperties`. Áp bảng hằng số:

- core-banking: path `/api/accounts/info` (route `/api/accounts/**` có sẵn trỏ về 8084 — **không** thêm route mới, DTO có `serviceName` nên không nhầm); schema `core_banking`; prefix `ERR-CORE`; level `A — chia theo aggregate`; port 8084. Test dependencies: chỉ `db` UP, `doesNotContain("redis")`.
- customer: path `/api/customers/info`; schema `customer`; prefix `ERR-CUST`; level `A — phẳng`; port 8082. Test dependencies: chỉ `db` UP, `doesNotContain("redis")`.
- Chú ý test của core-banking sẽ boot cả các trigger sổ cái qua Testcontainers — schema RỖNG (PostgresContainerSupport tạo DB trống, không mount schema.sql) và service không có entity nên `ddl-auto: validate` qua được; nếu context fail vì lý do khác, dừng và báo.
- `permit-all`: cả hai service thêm nguyên khối 7 đường mặc định + đường info của mình (core-banking: `- /api/accounts/info`; customer: `- /api/customers/info`).

- [ ] **Step 1: Viết 2 test fail trước** (chép Task 1 Step 2, áp thay thế)
- [ ] **Step 2: Chạy, xác nhận fail 404/401**

```bash
cd /Users/tanvx/Dev/bank-platform && export JAVA_HOME=$(/usr/libexec/java_home -v 21) && mvn -pl services/core-banking-service,services/customer-service -P'!with-libs' test 2>&1 | tail -20
```

- [ ] **Step 3: Chép 4 file Java mỗi service (package `api`/`api.dto`/`config`); sửa 2 Application class; sửa 2 application.yml**
- [ ] **Step 4: Chạy test, xác nhận pass**

```bash
cd /Users/tanvx/Dev/bank-platform && export JAVA_HOME=$(/usr/libexec/java_home -v 21) && mvn -pl services/core-banking-service,services/customer-service -P'!with-libs' test 2>&1 | tail -15
```

- [ ] **Step 5: Commit**

```bash
cd /Users/tanvx/Dev/bank-platform
git add services/core-banking-service services/customer-service
git commit -m "feat(core-banking,customer): API info theo khuôn, đặt ở api/ (Mức A)

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: gateway — `/api/gateway/info` + CORS + test

**Files:**
- Modify: `services/gateway-service/pom.xml` (thêm 2 dependency test)
- Create: `services/gateway-service/src/main/java/io/bankplatform/gateway/config/CorsConfig.java`
- Create: `services/gateway-service/src/main/java/io/bankplatform/gateway/web/dto/ApiEnvelope.java`
- Create: `services/gateway-service/src/main/java/io/bankplatform/gateway/web/dto/GatewayInfoResponse.java`
- Create: `services/gateway-service/src/main/java/io/bankplatform/gateway/web/dto/RouteInfo.java`
- Create: `services/gateway-service/src/main/java/io/bankplatform/gateway/web/GatewayInfoController.java`
- Test: `services/gateway-service/src/test/java/io/bankplatform/gateway/web/GatewayInfoApiTest.java`

**Interfaces:**
- Consumes: `GatewayMvcProperties.getRoutes()` (đã xác minh chữ ký ở Global Constraints); route yml có sẵn của gateway.
- Produces: `GET /api/gateway/info → {"success":true,"data":{serviceName,description,version,port,javaVersion,springBootVersion,startedAt,uptimeSeconds,routes:[{id,paths,target}]}}`; CORS mở cho `http://localhost:5173` trên `/api/**` — Task 5 phụ thuộc cả hai.

Gateway **không có javalibs** (ràng buộc từ phase trước, giữ nguyên) — envelope tự viết cùng hình dạng, không import `io.javalibs.*`.

- [ ] **Step 1: Thêm dependency test vào `services/gateway-service/pom.xml`** (vào `<dependencies>`, sau actuator):

```xml
    <!-- Boot 4 tách MockMvc ra jar riêng: starter-test KHÔNG chứa
         @AutoConfigureMockMvc (nằm ở spring-boot-webmvc-test). Thiếu jar thứ
         hai là lỗi compile khó hiểu ở import test. -->
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-test</artifactId>
      <scope>test</scope>
    </dependency>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-webmvc-test</artifactId>
      <scope>test</scope>
    </dependency>
```

- [ ] **Step 2: Viết test fail trước**

`services/gateway-service/src/test/java/io/bankplatform/gateway/web/GatewayInfoApiTest.java`:

```java
package io.bankplatform.gateway.web;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * MockMvc (webEnvironment MOCK) thay vì RANDOM_PORT: giữ nguyên server.port
 * 8080 từ yml để assert được, và không cần server thật.
 */
@SpringBootTest
@AutoConfigureMockMvc
class GatewayInfoApiTest {

    @Autowired
    MockMvc mvc;

    @Test
    void traVeThongTinGatewayVaBangRoute() throws Exception {
        mvc.perform(get("/api/gateway/info"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.serviceName").value("gateway-service"))
                .andExpect(jsonPath("$.data.port").value(8080))
                .andExpect(jsonPath("$.data.routes.length()").value(5))
                .andExpect(jsonPath("$.data.routes[?(@.id=='auth')].paths[0]").value("/api/auth/**"))
                // .target KHÔNG có [0]: sau filter, [0] trên trường vô hướng (String)
                // không khớp gì trong Jayway JsonPath — chỉ trường mảng như paths mới
                // index được. Với .target, filter trả list một phần tử và
                // MockMvc value() tự unwrap. Implementer Task 4 bắt được bằng jshell.
                .andExpect(jsonPath("$.data.routes[?(@.id=='core-banking')].target")
                        .value("http://localhost:8084"));
    }
}
```

- [ ] **Step 3: Chạy test, xác nhận fail vì 404**

```bash
cd /Users/tanvx/Dev/bank-platform && export JAVA_HOME=$(/usr/libexec/java_home -v 21) && mvn -pl services/gateway-service -P'!with-libs' test 2>&1 | tail -15
```

- [ ] **Step 4: Viết DTO + controller + CORS**

`services/gateway-service/src/main/java/io/bankplatform/gateway/web/dto/ApiEnvelope.java`:

```java
package io.bankplatform.gateway.web.dto;

import java.time.Instant;

/**
 * Bản sao HÌNH DẠNG của io.javalibs.web.ApiResponse. Gateway cố ý không dùng
 * javalibs (xem README của nó), nhưng frontend cần MỘT hình dạng envelope cho
 * cả sáu service — nên chép hình dạng, không chép thư viện.
 */
public record ApiEnvelope<T>(boolean success, T data, String message, Instant timestamp, String traceId) {

    public static <T> ApiEnvelope<T> ok(T data) {
        return new ApiEnvelope<>(true, data, null, Instant.now(), null);
    }
}
```

`services/gateway-service/src/main/java/io/bankplatform/gateway/web/dto/GatewayInfoResponse.java`:

```java
package io.bankplatform.gateway.web.dto;

import java.time.Instant;
import java.util.List;

/**
 * Payload của GET /api/gateway/info. Khác 5 service nghiệp vụ: không schema,
 * không mã lỗi, không dependencies — thay bằng bảng route đang chạy.
 */
public record GatewayInfoResponse(
        String serviceName,
        String description,
        String version,
        int port,
        String javaVersion,
        String springBootVersion,
        Instant startedAt,
        long uptimeSeconds,
        List<RouteInfo> routes) {
}
```

`services/gateway-service/src/main/java/io/bankplatform/gateway/web/dto/RouteInfo.java`:

```java
package io.bankplatform.gateway.web.dto;

import java.util.List;

/** Một dòng trong bảng route: id, các Path pattern, và đích chuyển tiếp. */
public record RouteInfo(String id, List<String> paths, String target) {
}
```

`services/gateway-service/src/main/java/io/bankplatform/gateway/web/GatewayInfoController.java`:

```java
package io.bankplatform.gateway.web;

import io.bankplatform.gateway.web.dto.ApiEnvelope;
import io.bankplatform.gateway.web.dto.GatewayInfoResponse;
import io.bankplatform.gateway.web.dto.RouteInfo;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.SpringBootVersion;
import org.springframework.boot.info.BuildProperties;
import org.springframework.cloud.gateway.server.mvc.config.GatewayMvcProperties;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.lang.management.ManagementFactory;
import java.time.Instant;
import java.util.List;

/**
 * Thông tin của chính gateway cho dashboard. /api/gateway/** không khớp route
 * chuyển tiếp nào nên rơi xuống controller này — không đụng bảng route.
 */
@RestController
public class GatewayInfoController {

    private static final String DESCRIPTION =
            "Cổng vào duy nhất cho frontend. Chỉ định tuyến — không nghiệp vụ, không DB, không javalibs.";

    private final GatewayMvcProperties gatewayProperties;
    private final String serviceName;
    private final int port;
    private final String version;

    GatewayInfoController(GatewayMvcProperties gatewayProperties,
                          @Value("${spring.application.name}") String serviceName,
                          @Value("${server.port}") int port,
                          ObjectProvider<BuildProperties> buildProperties) {
        this.gatewayProperties = gatewayProperties;
        this.serviceName = serviceName;
        this.port = port;
        BuildProperties build = buildProperties.getIfAvailable();
        this.version = build != null ? build.getVersion() : "unknown";
    }

    @GetMapping("/api/gateway/info")
    public ApiEnvelope<GatewayInfoResponse> info() {
        var runtime = ManagementFactory.getRuntimeMXBean();
        return ApiEnvelope.ok(new GatewayInfoResponse(
                serviceName,
                DESCRIPTION,
                version,
                port,
                Runtime.version().toString(),
                SpringBootVersion.getVersion(),
                Instant.ofEpochMilli(runtime.getStartTime()),
                runtime.getUptime() / 1000,
                routes()));
    }

    private List<RouteInfo> routes() {
        return gatewayProperties.getRoutes().stream()
                .map(route -> new RouteInfo(
                        route.getId(),
                        // Shorthand "Path=/a/**,/b/**" được parser tách thành nhiều
                        // args — flatMap gom lại thành danh sách pattern phẳng.
                        route.getPredicates().stream()
                                .filter(p -> "Path".equals(p.getName()))
                                .flatMap(p -> p.getArgs().values().stream())
                                .toList(),
                        String.valueOf(route.getUri())))
                .toList();
    }
}
```

`services/gateway-service/src/main/java/io/bankplatform/gateway/config/CorsConfig.java`:

```java
package io.bankplatform.gateway.config;

import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import org.springframework.web.filter.CorsFilter;

import java.util.List;

/**
 * CORS cho frontend dev (Vite, cổng 5173) — đặt ở gateway vì mọi request của
 * frontend đều đi qua đây: một chỗ sửa thay vì sáu. Gateway không dùng
 * javalibs nên không có javalibs.web.cors.* — filter tự khai.
 *
 * Dùng servlet Filter ở HIGHEST_PRECEDENCE — theo đúng khuôn của
 * CorsAutoConfiguration bên javalibs-web (một CorsFilter đăng ký qua
 * FilterRegistrationBean, dù bên đó dùng HIGHEST_PRECEDENCE + 10). Autoconfigure
 * đó opt-in (@ConditionalOnProperty javalibs.web.cors.enabled=true, không
 * matchIfMissing) và hiện KHÔNG service nào bật nó — ở đây chỉ mượn cách làm,
 * không phải bản sao của cái đang chạy đâu đó. Mục đích giống nhau: để header
 * CORS được gắn TRƯỚC mọi filter khác có thể tự trả response. Lưu ý cho người
 * sửa sau: addCorsMappings của WebMvcConfigurer CŨNG áp được cho route
 * RouterFunction (RouterFunctionMapping nhận chung map CORS của MVC) — chọn
 * Filter ở đây là vì nhất quán với phần còn lại của repo và thứ tự filter
 * tường minh, không phải vì RouterFunction "cần" Filter.
 */
@Configuration
public class CorsConfig {

    @Bean
    public FilterRegistrationBean<CorsFilter> corsFilter() {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOrigins(List.of("http://localhost:5173"));
        config.setAllowedMethods(List.of("GET", "OPTIONS"));
        config.setAllowedHeaders(List.of("*"));

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/api/**", config);

        FilterRegistrationBean<CorsFilter> bean = new FilterRegistrationBean<>(new CorsFilter(source));
        bean.setOrder(Ordered.HIGHEST_PRECEDENCE);
        return bean;
    }
}
```

**Nếu Step 5 fail vì `GatewayMvcProperties` không phải bean** (`NoSuchBeanDefinitionException`): thêm `@EnableConfigurationProperties(GatewayMvcProperties.class)` lên `CorsConfig` kèm comment `// GatewayMvcProperties không được autoconfig đăng ký làm bean ở version này — tự bật.` Đừng làm trước — chỉ khi lỗi thật.

- [ ] **Step 5: Chạy test, xác nhận pass**

```bash
cd /Users/tanvx/Dev/bank-platform && export JAVA_HOME=$(/usr/libexec/java_home -v 21) && mvn -pl services/gateway-service -P'!with-libs' test 2>&1 | tail -15
```

- [ ] **Step 6: Commit**

```bash
cd /Users/tanvx/Dev/bank-platform
git add services/gateway-service
git commit -m "feat(gateway): API /api/gateway/info kèm bảng route, và CORS cho Vite

Envelope chép hình dạng ApiResponse của javalibs chứ không import thư viện —
gateway giữ nguyên ràng buộc không-javalibs. CORS đặt một chỗ tại gateway.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: frontend — dashboard React + Vite

**Files:**
- Create: `frontend/package.json`, `frontend/vite.config.js`, `frontend/index.html`, `frontend/.gitignore`
- Create: `frontend/src/main.jsx`, `frontend/src/App.jsx`, `frontend/src/App.css`, `frontend/src/services.js`, `frontend/src/api.js`
- Create: `frontend/src/components/ServiceCard.jsx`, `frontend/src/components/RouteTable.jsx`

**Interfaces:**
- Consumes: 6 endpoint info của Task 1–4 qua gateway `http://localhost:8080`; JSON envelope `{success, data}`.
- Produces: dashboard tại `http://localhost:5173`.

Không test frontend ở vòng này (theo spec). Không thêm thư viện ngoài react/react-dom/vite/plugin-react.

- [ ] **Step 1: Tạo các file cấu hình**

`frontend/package.json`:

```json
{
  "name": "bank-dashboard",
  "private": true,
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^19.2.0",
    "react-dom": "^19.2.0"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^5.1.0",
    "vite": "^7.2.0"
  }
}
```

`frontend/vite.config.js`:

```js
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
})
```

`frontend/index.html`:

```html
<!doctype html>
<html lang="vi">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>bank-platform — dashboard</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
```

`frontend/.gitignore`:

```
node_modules/
dist/
```

- [ ] **Step 2: Viết nguồn dữ liệu và client**

`frontend/src/services.js`:

```js
// MỘT nguồn sự thật về sáu service và đường info của chúng. Path của
// core-banking là /api/accounts/info vì gateway không có route
// /api/core-banking/** — xem spec.
export const API_BASE = import.meta.env.VITE_API_BASE ?? 'http://localhost:8080'

export const SERVICES = [
  { key: 'gateway-service', infoPath: '/api/gateway/info' },
  { key: 'auth-service', infoPath: '/api/auth/info' },
  { key: 'customer-service', infoPath: '/api/customers/info' },
  { key: 'product-service', infoPath: '/api/products/info' },
  { key: 'core-banking-service', infoPath: '/api/accounts/info' },
  { key: 'notification-service', infoPath: '/api/notifications/info' },
]
```

`frontend/src/api.js`:

```js
import { API_BASE } from './services.js'

// Timeout 3s: một service treo không được phép giữ cả vòng poll. Lỗi mạng,
// timeout, hay HTTP != 2xx đều quy về {up: false} — thẻ hiển thị DOWN,
// không throw lên UI.
export async function fetchInfo(infoPath) {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), 3000)
  try {
    const res = await fetch(`${API_BASE}${infoPath}`, { signal: controller.signal })
    if (!res.ok) return { up: false }
    const body = await res.json()
    return { up: true, info: body.data }
  } catch {
    return { up: false }
  } finally {
    clearTimeout(timer)
  }
}
```

- [ ] **Step 3: Viết App + components**

`frontend/src/main.jsx`:

```jsx
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import App from './App.jsx'
import './App.css'

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
```

`frontend/src/App.jsx`:

```jsx
import { useEffect, useState } from 'react'
import { SERVICES } from './services.js'
import { fetchInfo } from './api.js'
import ServiceCard from './components/ServiceCard.jsx'

const POLL_MS = 10_000

export default function App() {
  // state[key] = { up, info } — info giữ lại lần cuối thấy được để thẻ DOWN
  // vẫn hiển thị dữ liệu tĩnh thay vì trống trơn.
  const [state, setState] = useState({})
  const [lastPoll, setLastPoll] = useState(null)

  useEffect(() => {
    let cancelled = false

    async function poll() {
      // allSettled: một service chết không kéo các thẻ khác chết theo.
      const results = await Promise.allSettled(
        SERVICES.map((svc) => fetchInfo(svc.infoPath)),
      )
      if (cancelled) return
      setState((prev) => {
        const next = { ...prev }
        SERVICES.forEach((svc, i) => {
          const r = results[i]
          const value = r.status === 'fulfilled' ? r.value : { up: false }
          next[svc.key] = {
            up: value.up,
            info: value.up ? value.info : prev[svc.key]?.info,
          }
        })
        return next
      })
      setLastPoll(new Date())
    }

    poll()
    const timer = setInterval(poll, POLL_MS)
    return () => {
      cancelled = true
      clearInterval(timer)
    }
  }, [])

  return (
    <main className="app">
      <header>
        <h1>bank-platform</h1>
        <p className="subtitle">
          Dashboard service — tự refresh mỗi {POLL_MS / 1000}s
          {lastPoll && ` · lần cuối: ${lastPoll.toLocaleTimeString('vi-VN')}`}
        </p>
      </header>
      <div className="grid">
        {SERVICES.map((svc) => (
          <ServiceCard key={svc.key} serviceKey={svc.key} state={state[svc.key]} />
        ))}
      </div>
    </main>
  )
}
```

`frontend/src/components/ServiceCard.jsx`:

```jsx
import RouteTable from './RouteTable.jsx'

function formatUptime(seconds) {
  if (seconds == null) return '—'
  const h = Math.floor(seconds / 3600)
  const m = Math.floor((seconds % 3600) / 60)
  const s = seconds % 60
  return h > 0 ? `${h}h ${m}m` : m > 0 ? `${m}m ${s}s` : `${s}s`
}

function Row({ label, value }) {
  return (
    <div className="row">
      <span className="label">{label}</span>
      <span className="value">{value ?? '—'}</span>
    </div>
  )
}

export default function ServiceCard({ serviceKey, state }) {
  const info = state?.info
  const up = state?.up ?? false

  return (
    <section className={`card ${up ? 'up' : 'down'}`}>
      <div className="card-head">
        <h2>{info?.serviceName ?? serviceKey}</h2>
        <span className={`badge ${up ? 'badge-up' : 'badge-down'}`}>
          {up ? 'UP' : 'DOWN'}
        </span>
      </div>
      {info?.description && <p className="desc">{info.description}</p>}
      <Row label="Version" value={info?.version} />
      <Row label="Cổng" value={info?.port} />
      {info?.structureLevel && <Row label="Cấu trúc" value={info.structureLevel} />}
      {info?.dbSchema && <Row label="Schema" value={info.dbSchema} />}
      {info?.errorCodePrefix && <Row label="Mã lỗi" value={info.errorCodePrefix} />}
      <Row label="Spring Boot" value={info?.springBootVersion} />
      <Row label="Java" value={info?.javaVersion} />
      <Row label="Uptime" value={up ? formatUptime(info?.uptimeSeconds) : '—'} />
      {info?.dependencies?.length > 0 && (
        <div className="deps">
          {info.dependencies.map((dep) => (
            <span
              key={dep.name}
              className={`dep ${dep.status === 'UP' ? 'dep-up' : 'dep-down'}`}
            >
              {dep.name}
            </span>
          ))}
        </div>
      )}
      {info?.routes && <RouteTable routes={info.routes} />}
    </section>
  )
}
```

`frontend/src/components/RouteTable.jsx`:

```jsx
// Chỉ thẻ gateway có bảng này — nó là thứ làm thẻ gateway đáng nhìn.
export default function RouteTable({ routes }) {
  return (
    <table className="routes">
      <thead>
        <tr>
          <th>Route</th>
          <th>Path</th>
          <th>Đích</th>
        </tr>
      </thead>
      <tbody>
        {routes.map((r) => (
          <tr key={r.id}>
            <td>{r.id}</td>
            <td>{r.paths.join(', ')}</td>
            <td>{r.target}</td>
          </tr>
        ))}
      </tbody>
    </table>
  )
}
```

`frontend/src/App.css`:

```css
:root {
  color-scheme: light dark;
  font-family: system-ui, -apple-system, sans-serif;
}

body { margin: 0; }

.app { max-width: 1200px; margin: 0 auto; padding: 1.5rem; }
header h1 { margin: 0 0 0.25rem; }
.subtitle { margin: 0 0 1.5rem; opacity: 0.7; font-size: 0.9rem; }

.grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(340px, 1fr));
  gap: 1rem;
}

.card {
  border: 1px solid color-mix(in srgb, currentColor 20%, transparent);
  border-radius: 10px;
  padding: 1rem;
}
.card.down { opacity: 0.6; }

.card-head { display: flex; justify-content: space-between; align-items: center; }
.card-head h2 { margin: 0; font-size: 1.05rem; }

.badge { font-size: 0.75rem; font-weight: 700; padding: 0.15rem 0.5rem; border-radius: 99px; }
.badge-up { background: #16a34a22; color: #16a34a; }
.badge-down { background: #dc262622; color: #dc2626; }

.desc { font-size: 0.85rem; opacity: 0.8; margin: 0.5rem 0; }

.row { display: flex; justify-content: space-between; font-size: 0.85rem; padding: 0.15rem 0; }
.row .label { opacity: 0.6; }

.deps { margin-top: 0.5rem; display: flex; gap: 0.4rem; flex-wrap: wrap; }
.dep { font-size: 0.75rem; padding: 0.1rem 0.5rem; border-radius: 99px; }
.dep-up { background: #16a34a22; color: #16a34a; }
.dep-down { background: #dc262622; color: #dc2626; }

.routes { width: 100%; margin-top: 0.6rem; font-size: 0.78rem; border-collapse: collapse; }
.routes th, .routes td { text-align: left; padding: 0.2rem 0.4rem; border-top: 1px solid color-mix(in srgb, currentColor 15%, transparent); }
.routes th { opacity: 0.6; border-top: none; }
```

- [ ] **Step 4: Cài và xác nhận build được**

```bash
cd /Users/tanvx/Dev/bank-platform/frontend && npm install 2>&1 | tail -3 && npm run build 2>&1 | tail -5
```

Expected: `vite build` kết thúc `✓ built in ...` không lỗi. (Build là bằng chứng compile; hiển thị thật kiểm ở Task 6.)

- [ ] **Step 5: Commit**

```bash
cd /Users/tanvx/Dev/bank-platform
git add frontend
git commit -m "feat(frontend): dashboard React + Vite gọi 6 API info qua gateway

Poll 10s bằng Promise.allSettled — service chết hiển thị DOWN, giữ dữ liệu
tĩnh lần cuối thấy được, không vỡ trang. Không router, không state manager.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: README + nghiệm thu end-to-end

**Files:**
- Modify: `README.md` (gốc — thêm mục "Frontend dashboard", sửa câu "đúng 6 file .java" nếu có)

**Interfaces:**
- Consumes: mọi thứ Task 1–5.
- Produces: bằng chứng cả hệ chạy thật.

- [ ] **Step 1: Build toàn reactor (chạy cả test mới)**

```bash
cd /Users/tanvx/Dev/bank-platform && export JAVA_HOME=$(/usr/libexec/java_home -v 21) && mvn -B -P'!with-libs' clean install 2>&1 | tail -25
```

Expected: `BUILD SUCCESS`, 6 test class chạy (5 service nghiệp vụ + gateway), 0 failures.

- [ ] **Step 2: Bật hạ tầng + cả 6 service**

```bash
cd /Users/tanvx/Dev/bank-platform && docker compose up -d && sleep 10
for svc in gateway auth customer product core-banking notification; do
  (export JAVA_HOME=$(/usr/libexec/java_home -v 21) && mvn -pl services/${svc}-service spring-boot:run -Dspring-boot.run.profiles=local > /tmp/${svc}-info.log 2>&1 &)
done
sleep 90
for p in 8080 8081 8082 8083 8084 8085; do
  printf "%s -> " "$p"; curl -s --max-time 5 http://localhost:$p/actuator/health; echo
done
```

Expected: cả 6 trả `{"status":"UP"...}`. Cổng nào không lên: đọc `/tmp/<tên>-info.log`, báo lỗi thật. (Máy dùng chung — nếu cổng bị chiếm, kiểm `docker ps` trước khi đổ lỗi cho code.)

- [ ] **Step 3: Nghiệm thu 6 API info QUA GATEWAY + CORS preflight**

```bash
for path in /api/gateway/info /api/auth/info /api/customers/info /api/products/info /api/accounts/info /api/notifications/info; do
  printf "%-28s %s\n" "$path" "$(curl -s --max-time 5 http://localhost:8080$path | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["data"]["serviceName"], "-", "UP" if d["success"] else "??")')"
done
curl -s -i -X OPTIONS "http://localhost:8080/api/auth/info" \
  -H "Origin: http://localhost:5173" -H "Access-Control-Request-Method: GET" | head -12
```

Expected: 6 dòng in đúng tên service (`/api/accounts/info` phải in `core-banking-service`); preflight trả `Access-Control-Allow-Origin: http://localhost:5173`.

- [ ] **Step 4: Nghiệm thu frontend**

```bash
cd /Users/tanvx/Dev/bank-platform/frontend && (npm run dev > /tmp/vite-dev.log 2>&1 &) && sleep 5 && curl -s http://localhost:5173 | grep -o "<title>[^<]*</title>"
```

Expected: `<title>bank-platform — dashboard</title>`. Mở `http://localhost:5173` xem 6 thẻ hiện UP (nếu chạy được browser tool thì chụp; không thì ghi nhận curl là đủ ở môi trường headless).

- [ ] **Step 5: Dọn tiến trình**

```bash
pkill -f "spring-boot:run" || true
pkill -f "vite" || true
```

- [ ] **Step 6a: Thêm mục Kafka vào `docs/KNOWN-LIMITATIONS.md`** — README ở Step 6b trỏ tới file này cho chuyện Kafka, nên mục phải TỒN TẠI trước khi con trỏ được ship. Thêm vào cuối phần `## Service`:

```markdown
### Bảng dependencies của API `/info` không có dòng `kafka`

Boot 4.1 không có health indicator nào cho Kafka — đã soát cả
`spring-boot-actuator`, `spring-boot-actuator-autoconfigure`, `spring-boot-kafka`
lẫn `spring-kafka` 4.1.0: không jar nào chứa lớp health Kafka, kể cả cho Kafka
Streams. Vì vậy các service dùng Kafka (customer, product, core-banking,
notification) không có dòng `kafka` trong bảng dependencies của `GET .../info`.

`WATCHED_DEPENDENCIES` trong các `ServiceInfoController` vẫn cố ý chứa `"kafka"`:
khi nào có indicator — tự viết bằng `KafkaAdmin.describeCluster` với timeout
ngắn, hoặc Boot bổ sung — dòng kafka tự xuất hiện, không phải sửa code.
```

- [ ] **Step 6b: Cập nhật `README.md` gốc** — thêm mục sau (đặt sau mục "Database" hoặc cuối "Bắt đầu"), và nếu README còn câu khẳng định "đúng 6 file `.java`" thì sửa thành "6 main class + code nghiệp vụ tăng dần theo feature":

```markdown
## Frontend dashboard

Dashboard dev hiển thị thông tin 6 service (`frontend/`, React + Vite):

​```bash
# backend phải chạy trước: docker compose up -d rồi bật các service
cd frontend && npm install && npm run dev
​```

Mở http://localhost:5173. Mỗi service có API `GET .../info` công khai
(permit-all — chưa có luồng phát JWT) trả metadata dev: version, cổng, schema,
uptime, trạng thái hạ tầng. Route qua gateway: xem thẻ gateway trên dashboard.
Lưu ý: bảng dependencies chưa có dòng `kafka` — Boot 4.1 không có health
indicator cho Kafka (xem docs/KNOWN-LIMITATIONS.md).
```

(Bỏ dấu `​` nếu có khi chép — fence lồng trong fence.)

- [ ] **Step 7: Commit**

```bash
cd /Users/tanvx/Dev/bank-platform
git add README.md docs/KNOWN-LIMITATIONS.md
git commit -m "docs: mục Frontend dashboard trong README gốc

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Đối chiếu spec

| Yêu cầu trong spec | Task |
|---|---|
| API info 5 service nghiệp vụ, `ApiResponse`, nguồn dữ liệu từng trường | 1, 2, 3 |
| `bank.info.*` + `@ConfigurationPropertiesScan` | 1, 2, 3 |
| `build-info` một lần ở root pom | 1 Step 4 |
| Bẫy permit-all (chép lại list mặc định) | 1 Step 7; 2, 3 lặp lại |
| Kafka không có indicator → chấp nhận vắng, whitelist giữ `kafka` | 1 Step 6 (comment trong code) |
| Gateway info + bảng route + envelope tự viết, không javalibs | 4 |
| CORS một chỗ tại gateway cho 5173 | 4 |
| Frontend React+Vite, poll 10s, allSettled, DOWN không vỡ trang | 5 |
| Test controller mỗi service + gateway; tên `*Test` cho surefire | 1–4 |
| README mục Frontend dashboard | 6 |
| Nghiệm thu qua gateway + preflight CORS | 6 |
