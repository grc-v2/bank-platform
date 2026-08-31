# Kế hoạch gỡ platform-libs và đưa bank-common vào services/

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xoá hẳn `platform-libs/` khỏi repo và đưa 6 module còn lại về Spring Boot trần vẫn build và chạy được, với `bank-common` chuyển thành `services/bank-common`.

**Architecture:** Thay từng starter javalibs bằng starter chính chủ Spring Boot; 4 kiểu Java duy nhất còn dùng (`Entity`, `AggregateRoot`, `ApiResponse`, `BaseIntegrationTest`) được viết lại tối thiểu trong `bank-common` hoặc inline vào từng service. 9/13 module javalibs là dependency chết, xoá thẳng. Thứ tự: dựng `bank-common` mới trước → chuyển từng service (auth là golden path) → cuối cùng mới `git rm` platform-libs và dọn root pom, để mỗi bước đều build được.

**Tech Stack:** Java 21, Spring Boot 4.1.0, Maven, Postgres 16, Testcontainers 2.0.5, Jackson 3.1.4, springdoc-openapi 3.1.0, JUnit 6.0.3, AssertJ 3.27.7.

**Spec:** [docs/superpowers/specs/2026-09-01-remove-platform-libs-design.md](../specs/2026-09-01-remove-platform-libs-design.md)

## Global Constraints

- Branch: `refactor/remove-platform-libs`, làm tại `/Users/tanvx/Dev/bank-platform` (KHÔNG worktree).
- `export JAVA_HOME=$(/usr/libexec/java_home -v 21)` trước MỌI lệnh `mvn` — shell non-interactive không có sẵn.
- Testcontainers cần Docker: `open -a OrbStack` rồi chờ socket. OrbStack không tự khởi động và có thể mất ~5 phút.
- Không đổi `groupId`/`artifactId`/`version` của bất kỳ module nào. `bank-common` vẫn là `io.bankplatform:bank-common`.
- Tài liệu và commit message viết **tiếng Việt**, kể *vì sao*, không chỉ *cái gì*.
- Mọi comment mô tả cơ chế phải đúng với code sau khi sửa. Repo này đã bắt 11 lần comment mô tả sai cơ chế — comment nhắc `javalibs` sau khi gỡ là sai theo định nghĩa.
- Test đặt tên `*Test`; surefire **bỏ qua `*IT` trong im lặng**. Không đổi tên test thành `*IT`.
- Đổi config runtime (`application*.yml`) phải nằm trong danh sách Files của task và trong commit message. Tiền lệ 2026-08-19: config lọt vào commit dán nhãn `docs:` không khai báo.
- Chỉ **một** artifact cần version tường minh sau khi bỏ BOM javalibs: `org.springdoc:springdoc-openapi-starter-webmvc-ui:3.1.0`. Mọi thứ khác (Flyway, Testcontainers, JUnit, AssertJ, Jackson, springdoc **không**) đều do `spring-boot-starter-parent:4.1.0` quản lý — đã kiểm trên `spring-boot-dependencies-4.1.0.pom`.

### Ràng buộc test bất khả xâm phạm

`ServiceInfoApiTest` của cả 5 service khoá chặt các điểm sau:

| Ràng buộc | Hệ quả nếu phá |
|---|---|
| `ApiResponse` giữ đúng 5 trường `success, data, message, timestamp, traceId` | `body.path("success")` đọc `null` → test đỏ |
| Execution `build-info` ở `pluginManagement` root pom | `version` rơi về `"unknown"` → test đỏ |
| `springBootVersion == "4.1.0"` | Đổi version Boot → test đỏ |
| actuator + health indicator DB còn sống | `statusOf(data,"db") != "UP"` → test đỏ |
| **auth + product PHẢI có** `spring-boot-starter-data-redis` | `dependencies` thiếu `"redis"` → test đỏ |
| **customer + core-banking + notification PHẢI KHÔNG có** Redis | `dependencies` thừa `"redis"` → test đỏ |

---

## Bẫy đã phát hiện khi khảo sát — đọc trước khi bắt đầu

**Jackson 2 biến mất cùng javalibs.** Cả 5 `ServiceInfoApiTest` import `com.fasterxml.jackson.databind.JsonNode` và `ObjectMapper`. Jackson 2 hiện tới classpath test **chỉ qua javalibs**: `javalibs-security-test` → `jjwt-jackson` → `com.fasterxml.jackson.core:jackson-databind:2.21.4` (và ở auth thêm `javalibs-security-issuer`). Gỡ javalibs là 5 file test **lỗi compile**.

Cách xử: chuyển 5 test sang Jackson 3 (`tools.jackson.databind`), đúng Jackson mà Boot 4.1 dùng cho chính HTTP message converter của ứng dụng. Đã kiểm trên `jackson-databind-3.1.4.jar` bằng `javap` — **chỉ cần đổi 2 dòng import**, thân test giữ nguyên:

- `new ObjectMapper()` — constructor public, còn ✓
- `readTree(String)` — còn ✓, ném `JacksonException` **unchecked** (`extends RuntimeException`), nên `throws Exception` sẵn có vẫn hợp lệ
- `path(String)`, `asText()`, `asBoolean()`, `asInt()`, `asLong()` — còn đủ ✓ (`asText()` **không** bị `@Deprecated`; `asString()` là tên mới nhưng không bắt buộc đổi)
- `JsonNode implements Iterable<JsonNode>` ✓ → vòng `for (JsonNode dep : ...)` và `.forEach(...)` trong hai helper `statusOf`/`dependencyNames` chạy nguyên
- ⚠️ `elements()` đã **bị xoá** trong Jackson 3 — không file nào trong repo dùng, nhưng đừng thêm mới

---

## Cấu trúc file sau khi xong

```
pom.xml                                  # bỏ BOM javalibs + profile with-libs; quản springdoc
services/
  bank-common/                           # CHUYỂN TỪ /bank-common
    pom.xml                              # relativePath ../../pom.xml; test-dep junit+assertj
    README.md                            # charter mới: thêm ddd/ và web/
    src/main/java/io/bankplatform/common/
      ddd/Entity.java                    # MỚI
      ddd/AggregateRoot.java             # MỚI
      web/ApiResponse.java               # MỚI
      type/ event/ constant/             # giữ .gitkeep
    src/test/java/io/bankplatform/common/
      ddd/EntityTest.java                # MỚI
      web/ApiResponseTest.java           # MỚI
  auth-service/ product-service/ customer-service/
  core-banking-service/ notification-service/     # pom + yml + import + test
  gateway-service/                       # chỉ sửa 1 comment
platform-libs/                           # XOÁ TOÀN BỘ
```

---

### Task 1: bank-common — chuyển chỗ, ba lớp nền, chuẩn bị root pom

**Files:**
- Move: `bank-common/` → `services/bank-common/` (dùng `git mv`)
- Modify: `pom.xml` (module path + quản lý version springdoc)
- Modify: `services/bank-common/pom.xml`
- Modify: `services/bank-common/README.md`
- Create: `services/bank-common/src/main/java/io/bankplatform/common/ddd/Entity.java`
- Create: `services/bank-common/src/main/java/io/bankplatform/common/ddd/AggregateRoot.java`
- Create: `services/bank-common/src/main/java/io/bankplatform/common/web/ApiResponse.java`
- Test: `services/bank-common/src/test/java/io/bankplatform/common/ddd/EntityTest.java`
- Test: `services/bank-common/src/test/java/io/bankplatform/common/web/ApiResponseTest.java`

**Interfaces:**
- Produces:
  - `io.bankplatform.common.ddd.Entity<ID>` — abstract, `public abstract ID getId()`, `equals`/`hashCode`/`toString` đã hiện thực
  - `io.bankplatform.common.ddd.AggregateRoot<ID> extends Entity<ID>` — abstract, không thêm method
  - `io.bankplatform.common.web.ApiResponse<T>` — `record(boolean success, T data, String message, Instant timestamp, String traceId)` với `static <T> ApiResponse<T> ok(T)`, `ok(T, String)`, `error(String)`, `error(String, String)`
- Consumes: không có (task đầu tiên)

- [ ] **Step 1: Chuyển thư mục và sửa đường dẫn parent**

```bash
cd /Users/tanvx/Dev/bank-platform
git mv bank-common services/bank-common
```

Sửa `services/bank-common/pom.xml`, dòng `<relativePath>`:

```xml
    <relativePath>../../pom.xml</relativePath>
```

Sửa `pom.xml` gốc, trong `<modules>` — đổi `<module>bank-common</module>` thành:

```xml
    <module>services/bank-common</module>
```

Đồng thời xoá comment đã lỗi thời ngay trên `<modules>` ("Danh sách này lớn dần qua từng task; hiện chưa có module nào" — sai từ lâu) và thay bằng:

```xml
  <!--
    platform-libs đã bị gỡ khỏi repo (2026-09-01) — chủ dự án tự viết lại phần
    hạ tầng để hiểu bản chất. Muốn tham khảo bản javalibs cũ:
      git show b095cd5:platform-libs/<đường-dẫn>
  -->
```

- [ ] **Step 2: Quản lý version springdoc ở root pom**

springdoc là artifact **duy nhất** không được `spring-boot-starter-parent` quản lý. Trước đây version tới từ `platform-libs/pom.xml`. Thêm vào `<properties>` của `pom.xml` gốc, ngay dưới `project.build.sourceEncoding`:

```xml
    <!--
      springdoc KHÔNG nằm trong spring-boot-dependencies (đã kiểm:
      grep -c springdoc spring-boot-dependencies-4.1.0.pom -> 0), nên phải tự
      ghim version. 3.1.0 là bản platform-libs cũ dùng với Boot 4.1 và đã có
      trong ~/.m2. Nâng version thì kiểm lại Swagger UI mở được.
    -->
    <springdoc.version>3.1.0</springdoc.version>
```

Và vào `<dependencyManagement><dependencies>` của root pom, **thay thế** khối `javalibs-dependencies` (xoá nó ở đây luôn, đỡ phải quay lại ở Task 7):

```xml
      <dependency>
        <groupId>org.springdoc</groupId>
        <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
        <version>${springdoc.version}</version>
      </dependency>
```

Xoá luôn property `<javalibs.version>2.0.0-SNAPSHOT</javalibs.version>`.

> Root pom giờ không còn tham chiếu javalibs nào **trừ** profile `with-libs` (Task 7 xoá). Reactor vẫn build được vì `platform-libs` tự khai version cho chính nó.

- [ ] **Step 3: Viết test thất bại cho Entity**

Tạo `services/bank-common/src/test/java/io/bankplatform/common/ddd/EntityTest.java`:

```java
package io.bankplatform.common.ddd;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Ghim hợp đồng định danh của {@link Entity} — thứ 22 entity JPA trong repo
 * dựa vào. Ba tính chất dưới đây là lý do lớp này tồn tại; mất một cái là
 * entity vào Set/Map sai lặng lẽ.
 */
class EntityTest {

    static class Account extends Entity<Long> {
        private final Long id;
        Account(Long id) { this.id = id; }
        @Override public Long getId() { return id; }
    }

    static class Customer extends Entity<Long> {
        private final Long id;
        Customer(Long id) { this.id = id; }
        @Override public Long getId() { return id; }
    }

    @Test
    void haiEntityCungLopCungIdThiBangNhau() {
        assertThat(new Account(1L)).isEqualTo(new Account(1L));
    }

    @Test
    void idNullChiBangChinhNo() {
        Account chuaLuu = new Account(null);
        assertThat(chuaLuu).isEqualTo(chuaLuu);
        assertThat(chuaLuu).isNotEqualTo(new Account(null));
    }

    @Test
    void khacLopThiKhacNhauDuCungId() {
        assertThat(new Account(1L)).isNotEqualTo(new Customer(1L));
    }

    @Test
    void hashCodeOnDinhKhiIdDuocGanLucPersist() {
        // Hibernate gán id SAU khi entity đã nằm trong HashSet. hashCode phụ
        // thuộc id sẽ làm entity "mất tích" khỏi set đó.
        assertThat(new Account(null).hashCode()).isEqualTo(new Account(99L).hashCode());
    }

    @Test
    void toStringCoTenLopVaId() {
        assertThat(new Account(7L)).hasToString("Account[id=7]");
    }
}
```

Tạo `services/bank-common/src/test/java/io/bankplatform/common/web/ApiResponseTest.java`:

```java
package io.bankplatform.common.web;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Ghim HÌNH DẠNG envelope. Năm ServiceInfoApiTest đọc thẳng JSON
 * (body.path("success"), body.path("data")), nên đổi tên hay thứ tự trường ở
 * đây là làm đỏ test của cả năm service — và làm hỏng frontend đang chạy.
 */
class ApiResponseTest {

    @Test
    void okDatSuccessTrueVaGiuNguyenPayload() {
        ApiResponse<String> res = ApiResponse.ok("xin chào");

        assertThat(res.success()).isTrue();
        assertThat(res.data()).isEqualTo("xin chào");
        assertThat(res.message()).isNull();
        assertThat(res.timestamp()).isNotNull();
        assertThat(res.traceId()).isNull();
    }

    @Test
    void okCoMessage() {
        ApiResponse<String> res = ApiResponse.ok("dữ liệu", "đã tạo");

        assertThat(res.success()).isTrue();
        assertThat(res.message()).isEqualTo("đã tạo");
    }

    @Test
    void errorDatSuccessFalseVaDataNull() {
        ApiResponse<String> res = ApiResponse.error("hỏng rồi");

        assertThat(res.success()).isFalse();
        assertThat(res.data()).isNull();
        assertThat(res.message()).isEqualTo("hỏng rồi");
    }

    @Test
    void errorCoTraceId() {
        ApiResponse<String> res = ApiResponse.error("hỏng rồi", "abc-123");

        assertThat(res.traceId()).isEqualTo("abc-123");
    }

    @Test
    void thuTuTruongCuaRecordDungNhuHopDong() {
        // RecordComponents theo đúng thứ tự khai báo. Jackson serialize theo
        // thứ tự này, và đây là thứ frontend/test nhìn thấy.
        assertThat(ApiResponse.class.getRecordComponents())
                .extracting(java.lang.reflect.RecordComponent::getName)
                .containsExactly("success", "data", "message", "timestamp", "traceId");
    }
}
```

- [ ] **Step 4: Thêm dependency test cho bank-common**

Sửa `services/bank-common/pom.xml` — thay khối comment `<!-- Cố ý KHÔNG có <dependencies> ... -->` bằng:

```xml
  <!--
    KHÔNG có dependency compile nào, và phải giữ như vậy: thêm một dependency
    compile ở đây là thêm nó vào cả sáu module cùng lúc.

    Hai dependency dưới đây ở scope test — chúng KHÔNG lan sang consumer, nên
    không phá cam kết trên. Cố ý KHÔNG dùng spring-boot-starter-test: module này
    là Java thuần, kéo cả Spring vào classpath test sẽ che mất việc lỡ tay import
    Spring trong src/main.
  -->
  <dependencies>
    <dependency>
      <groupId>org.junit.jupiter</groupId>
      <artifactId>junit-jupiter</artifactId>
      <scope>test</scope>
    </dependency>
    <dependency>
      <groupId>org.assertj</groupId>
      <artifactId>assertj-core</artifactId>
      <scope>test</scope>
    </dependency>
  </dependencies>
```

Không cần `<version>`: `spring-boot-dependencies:4.1.0` import `junit-bom:6.0.3` và `assertj-bom:3.27.7` (đã kiểm).

- [ ] **Step 5: Chạy test để xác nhận ĐỎ**

```bash
cd /Users/tanvx/Dev/bank-platform && export JAVA_HOME=$(/usr/libexec/java_home -v 21) && mvn -o -pl services/bank-common test
```

Kỳ vọng: FAIL — lỗi compile `cannot find symbol: class Entity` và `class ApiResponse`.

- [ ] **Step 6: Viết Entity.java**

`services/bank-common/src/main/java/io/bankplatform/common/ddd/Entity.java`:

```java
package io.bankplatform.common.ddd;

import java.util.Objects;

/**
 * Lớp nền cho entity DDD: đối tượng được định danh bằng ID chứ không bằng
 * thuộc tính.
 *
 * <p>Hai entity bằng nhau khi cùng lớp cụ thể và cùng ID. Entity chưa có ID
 * (chưa persist) chỉ bằng chính nó — nếu không, mọi entity mới đều bằng nhau
 * và một {@code HashSet} chỉ giữ được đúng một cái.
 *
 * @param <ID> kiểu định danh
 */
public abstract class Entity<ID> {

    /** Định danh của entity; có thể {@code null} trước lần persist đầu tiên. */
    public abstract ID getId();

    @Override
    public boolean equals(Object other) {
        if (this == other) {
            return true;
        }
        if (other == null || getClass() != other.getClass()) {
            return false;
        }
        Entity<?> that = (Entity<?>) other;
        return getId() != null && Objects.equals(getId(), that.getId());
    }

    @Override
    public int hashCode() {
        // Hằng số theo lớp, KHÔNG theo id: Hibernate gán id lúc persist, mà
        // entity có thể đã nằm trong HashSet từ trước. hashCode đổi giữa chừng
        // là entity biến mất khỏi set trong im lặng.
        return getClass().hashCode();
    }

    @Override
    public String toString() {
        return getClass().getSimpleName() + "[id=" + getId() + "]";
    }
}
```

- [ ] **Step 7: Viết AggregateRoot.java**

`services/bank-common/src/main/java/io/bankplatform/common/ddd/AggregateRoot.java`:

```java
package io.bankplatform.common.ddd;

/**
 * Đánh dấu gốc aggregate: biên nhất quán của mô hình miền, và là entity duy
 * nhất mà repository được phép nạp/lưu trực tiếp.
 *
 * <p>Hiện lớp này KHÔNG thêm hành vi nào ngoài {@link Entity} — nó là một dấu
 * hiệu kiểu (type marker) để đọc code biết đâu là gốc aggregate, đâu là entity
 * con. Bản javalibs cũ có sẵn cơ chế domain event ({@code registerEvent},
 * {@code pullDomainEvents}) nhưng chưa dòng code nghiệp vụ nào trong repo dùng
 * tới, nên cố ý không chép sang. Thêm khi thật sự publish event đầu tiên —
 * xem docs/KNOWN-LIMITATIONS.md.
 *
 * @param <ID> kiểu định danh
 */
public abstract class AggregateRoot<ID> extends Entity<ID> {
}
```

- [ ] **Step 8: Viết ApiResponse.java**

`services/bank-common/src/main/java/io/bankplatform/common/web/ApiResponse.java`:

```java
package io.bankplatform.common.web;

import java.time.Instant;

/**
 * Envelope chuẩn cho mọi phản hồi API, thành công lẫn thất bại.
 *
 * <p>Là {@code record} Java thuần — không annotation Spring, không annotation
 * Jackson. Jackson 3 của Boot 4.1 serialize record theo đúng thứ tự khai báo
 * component, nên thứ tự năm trường dưới đây LÀ hợp đồng với frontend và với
 * năm {@code ServiceInfoApiTest}. Đổi tên hay thứ tự là phá cả hai.
 *
 * <p>{@code traceId} hiện luôn {@code null}: chưa có correlation-id filter nào
 * sau khi gỡ javalibs-observability. Trường vẫn giữ để khi dựng filter không
 * phải đổi hợp đồng JSON.
 *
 * @param <T>       kiểu payload
 * @param success   {@code true} khi xử lý thành công
 * @param data      payload; {@code null} với phản hồi lỗi
 * @param message   thông điệp cho người đọc, có thể {@code null}
 * @param timestamp thời điểm server tạo phản hồi
 * @param traceId   định danh nối phản hồi với log server, có thể {@code null}
 */
public record ApiResponse<T>(
        boolean success,
        T data,
        String message,
        Instant timestamp,
        String traceId) {

    /** Phản hồi thành công, không kèm thông điệp. */
    public static <T> ApiResponse<T> ok(T data) {
        return new ApiResponse<>(true, data, null, Instant.now(), null);
    }

    /** Phản hồi thành công kèm thông điệp cho người đọc. */
    public static <T> ApiResponse<T> ok(T data, String message) {
        return new ApiResponse<>(true, data, message, Instant.now(), null);
    }

    /** Phản hồi lỗi, chỉ mang thông điệp. */
    public static <T> ApiResponse<T> error(String message) {
        return new ApiResponse<>(false, null, message, Instant.now(), null);
    }

    /** Phản hồi lỗi kèm traceId để người dùng báo lỗi có thứ đối chiếu log. */
    public static <T> ApiResponse<T> error(String message, String traceId) {
        return new ApiResponse<>(false, null, message, Instant.now(), traceId);
    }
}
```

- [ ] **Step 9: Chạy test để xác nhận XANH**

```bash
cd /Users/tanvx/Dev/bank-platform && export JAVA_HOME=$(/usr/libexec/java_home -v 21) && mvn -o -pl services/bank-common test
```

Kỳ vọng: PASS, 10 test (5 `EntityTest` + 5 `ApiResponseTest`).

- [ ] **Step 10: Viết lại README của bank-common**

Ghi đè `services/bank-common/README.md`:

````markdown
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
````

- [ ] **Step 11: Build cả reactor để chắc chưa vỡ gì**

```bash
cd /Users/tanvx/Dev/bank-platform && export JAVA_HOME=$(/usr/libexec/java_home -v 21) && mvn -o clean install -DskipTests
```

Kỳ vọng: BUILD SUCCESS, 24 module (17 javalibs + bank-common + 6 service). `bank-common` xuất hiện với đường dẫn `services/bank-common`.

- [ ] **Step 12: Commit**

```bash
cd /Users/tanvx/Dev/bank-platform
git add pom.xml services/bank-common
git commit -F - <<'EOF'
refactor(bank-common): chuyển vào services/ và tự viết ba lớp nền

Đặt bank-common ngang hàng các service vì nó là một module của hệ, không phải
thứ đứng ngoài — cây thư mục cũ khiến nó trông như hạ tầng dùng chung.

Ba lớp Entity/AggregateRoot/ApiResponse viết lại từ đầu thay cho javalibs.
AggregateRoot CỐ Ý bỏ cơ chế domain event của bản cũ: chưa dòng nghiệp vụ nào
dùng registerEvent/pullDomainEvents, chép sang là chép nợ.

Charter README mở rộng thêm ddd/ và web/, nhưng giữ nguyên cam kết không có
dependency compile — junit và assertj ở scope test nên không lan sang sáu
module consumer.

Root pom nhận việc ghim springdoc 3.1.0: đây là artifact DUY NHẤT mà
spring-boot-dependencies:4.1.0 không quản (đã kiểm bằng grep trên chính file
BOM), trước đây version tới từ platform-libs/pom.xml.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
```

---

### Task 2: auth-service — golden path

Service đầu tiên chuyển. Làm kỹ ở đây, năm task sau chỉ là nhân rộng.

**Files:**
- Modify: `services/auth-service/pom.xml`
- Modify: `services/auth-service/src/main/resources/application.yml`
- Modify: `services/auth-service/src/main/resources/application-local.yml`
- Modify: `services/auth-service/src/test/resources/application-test.yml`
- Modify: `services/auth-service/src/main/java/io/bankplatform/auth/web/ServiceInfoController.java`
- Modify: `services/auth-service/src/test/java/io/bankplatform/auth/AbstractIntegrationTest.java`
- Test: `services/auth-service/src/test/java/io/bankplatform/auth/web/ServiceInfoApiTest.java`

**Interfaces:**
- Consumes: `io.bankplatform.common.web.ApiResponse` (Task 1)
- Produces: khuôn mẫu `<dependencies>` và `AbstractIntegrationTest` mà Task 3–6 nhân bản

- [ ] **Step 1: Chạy test hiện tại để có mốc XANH đối chiếu**

Bật Docker trước (`open -a OrbStack`, chờ tới khi `docker ps` chạy được).

```bash
cd /Users/tanvx/Dev/bank-platform && export JAVA_HOME=$(/usr/libexec/java_home -v 21) && mvn -o -pl services/auth-service test
```

Kỳ vọng: PASS. Đây là refactor — test phải xanh **trước và sau**. Không xanh ở bước này thì dừng, báo, đừng sửa tiếp.

- [ ] **Step 2: Thay toàn bộ `<dependencies>` của auth-service**

Trong `services/auth-service/pom.xml`, thay **toàn bộ** khối `<dependencies>...</dependencies>` (kể cả mọi comment javalibs bên trong) bằng:

```xml
  <dependencies>
    <dependency>
      <groupId>io.bankplatform</groupId>
      <artifactId>bank-common</artifactId>
    </dependency>

    <!-- Bộ nền: mọi service nghiệp vụ đều có đúng bốn starter này -->
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-webmvc</artifactId>
    </dependency>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-validation</artifactId>
    </dependency>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-actuator</artifactId>
    </dependency>
    <dependency>
      <groupId>org.springdoc</groupId>
      <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
    </dependency>

    <!--
      Redis BẮT BUỘC có ở auth (và product), và BẮT BUỘC KHÔNG có ở ba service
      còn lại. Lý do: ServiceInfoApiTest assert
      dependencyNames(data).contains("redis") — dòng "redis" đó tới từ
      DataRedisHealthIndicator của actuator, thứ chỉ tồn tại khi có starter này.
      Ba service kia assert doesNotContain("redis").
    -->
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-data-redis</artifactId>
    </dependency>

    <!--
      Flyway giữ lại dù spring.flyway.enabled=false. Bỏ đi thì khối
      spring.flyway.* trong application.yml (kèm lời giải thích vì sao tắt và
      điều kiện bật lại) trở thành property không ai đọc — âm thầm xoá một
      quyết định đã ghi tài liệu.
      spring-boot-flyway là jar riêng của Boot 4.x chứa FlywayConfigurationCustomizer;
      thiếu nó là NoClassDefFoundError lúc Spring soi @Bean.
    -->
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-flyway</artifactId>
    </dependency>
    <dependency>
      <groupId>org.flywaydb</groupId>
      <artifactId>flyway-core</artifactId>
    </dependency>
    <dependency>
      <groupId>org.flywaydb</groupId>
      <artifactId>flyway-database-postgresql</artifactId>
    </dependency>

    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-data-jpa</artifactId>
    </dependency>
    <dependency>
      <groupId>org.postgresql</groupId>
      <artifactId>postgresql</artifactId>
      <scope>runtime</scope>
    </dependency>

    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-test</artifactId>
      <scope>test</scope>
    </dependency>
    <!--
      Boot 4 tách TestRestTemplate và @AutoConfigureTestRestTemplate sang jar
      riêng spring-boot-resttestclient — starter-test KHÔNG chứa chúng.
    -->
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-resttestclient</artifactId>
      <scope>test</scope>
    </dependency>
    <dependency>
      <groupId>org.testcontainers</groupId>
      <artifactId>testcontainers-postgresql</artifactId>
      <scope>test</scope>
    </dependency>
  </dependencies>
```

Không dependency nào cần `<version>` — `spring-boot-starter-parent:4.1.0` quản Flyway và import `testcontainers-bom:2.0.5`; springdoc do root pom quản (Task 1).

- [ ] **Step 3: Xoá cấu hình javalibs khỏi ba file yml**

`services/auth-service/src/main/resources/application.yml` — xoá **toàn bộ** khối `javalibs:` (từ dòng `javalibs:` tới hết `- /api/auth/info`, gồm cả comment). Các khối `spring:`, `server:`, `management:`, `bank:` giữ nguyên không đổi.

`services/auth-service/src/main/resources/application-local.yml` — xoá khối `javalibs:`, còn lại:

```yaml
# Profile local: chạy với hạ tầng của compose.yaml.
#   mvn -pl services/auth-service spring-boot:run -Dspring-boot.run.profiles=local
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/bank

logging:
  level:
    io.bankplatform: DEBUG
```

`services/auth-service/src/test/resources/application-test.yml` — ghi đè toàn bộ (comment cũ nhắc `BaseIntegrationTest của javalibs-test`, giờ sai):

```yaml
# Profile test do @ActiveProfiles("test") trên AbstractIntegrationTest kích hoạt.
spring:
  flyway:
    enabled: false
```

- [ ] **Step 4: Đổi import ApiResponse trong ServiceInfoController**

`services/auth-service/src/main/java/io/bankplatform/auth/web/ServiceInfoController.java`, đổi dòng import:

```java
import io.bankplatform.common.web.ApiResponse;
```

Và sửa Javadoc của lớp — câu "Nằm trong permit-all có chủ đích" giờ sai (không còn permit-all). Thay bằng:

```java
/**
 * Thông tin chi tiết của service cho dashboard dev.
 *
 * <p>Không có xác thực nào chặn endpoint này — từ 2026-09-01 service không còn
 * Spring Security (xem docs/KNOWN-LIMITATIONS.md). Kể cả khi dựng lại
 * security, endpoint này nên để mở: payload chỉ là metadata dev, không secret,
 * không connection string.</p>
 */
```

- [ ] **Step 5: Inline Testcontainers vào AbstractIntegrationTest**

Ghi đè `services/auth-service/src/test/java/io/bankplatform/auth/AbstractIntegrationTest.java`:

```java
package io.bankplatform.auth;

import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureTestRestTemplate;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.postgresql.PostgreSQLContainer;

import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;

/**
 * Nền cho mọi test full-context của auth-service.
 *
 * <p>Container Postgres theo mẫu singleton: khởi động MỘT lần cho cả JVM test
 * của module này, Ryuk của Testcontainers dọn khi JVM thoát. Mỗi module Maven
 * chạy một JVM surefire riêng nên container KHÔNG chia sẻ được giữa các module —
 * đó là lý do lớp này được chép vào từng service thay vì đóng thành test-jar
 * dùng chung.
 *
 * <p>Static block nạp docs/database/schema.sql (nguồn sự thật duy nhất — quyết
 * định D5) đúng một lần, idempotent, và phải xong TRƯỚC khi Spring context dựng
 * vì {@code ddl-auto: validate} cần bảng đã tồn tại.
 *
 * <p>Cần Docker daemon đang chạy (OrbStack).
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@ActiveProfiles("test")
public abstract class AbstractIntegrationTest {

    private static final String IMAGE = "postgres:16-alpine";
    private static final String SCHEMA_NAME = "auth";

    private static final PostgreSQLContainer POSTGRES;

    static {
        POSTGRES = new PostgreSQLContainer(IMAGE)
                .withDatabaseName("it_db")
                .withUsername("it_user")
                .withPassword("it_pass");
        POSTGRES.start();

        try (Connection conn = DriverManager.getConnection(
                POSTGRES.getJdbcUrl(), POSTGRES.getUsername(), POSTGRES.getPassword());
             Statement st = conn.createStatement()) {
            try (ResultSet rs = st.executeQuery(
                    "SELECT 1 FROM information_schema.schemata WHERE schema_name = '" + SCHEMA_NAME + "'")) {
                if (!rs.next()) {
                    st.execute(Files.readString(schemaSql()));
                }
            }
        } catch (Exception e) {
            throw new IllegalStateException("Không nạp được schema.sql vào container test", e);
        }
    }

    @DynamicPropertySource
    static void registerDatasourceProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
    }

    // Surefire chạy với cwd = thư mục module -> đi ngược lên tìm repo root,
    // để test vẫn chạy được khi IDE đặt cwd khác.
    private static Path schemaSql() {
        Path dir = Path.of("").toAbsolutePath();
        for (int i = 0; i < 6 && dir != null; i++, dir = dir.getParent()) {
            Path candidate = dir.resolve("docs/database/schema.sql");
            if (Files.exists(candidate)) {
                return candidate;
            }
        }
        throw new IllegalStateException("Không tìm thấy docs/database/schema.sql từ " + Path.of("").toAbsolutePath());
    }
}
```

- [ ] **Step 6: Chuyển ServiceInfoApiTest sang Jackson 3**

`services/auth-service/src/test/java/io/bankplatform/auth/web/ServiceInfoApiTest.java` — đổi hai dòng import:

```java
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
```

**Thân test giữ nguyên hoàn toàn.** Đã kiểm trên `jackson-databind-3.1.4.jar`: `new ObjectMapper()`, `readTree(String)`, `path`, `asText`, `asBoolean`, `asInt`, `asLong` và `Iterable<JsonNode>` đều còn.

Và sửa Javadoc của lớp — hai câu hiện tại nhắc `javalibs-security` và `BaseIntegrationTest`, cả hai đều không còn:

```java
/**
 * Test full-context: chứng minh endpoint /api/auth/info trả đúng envelope và
 * đúng metadata khi Spring context dựng đầy đủ.
 *
 * <p>Extends {@link AbstractIntegrationTest} vì từ khi có entity, Spring context
 * nào cũng cần schema `auth` đã tồn tại trong container để
 * {@code ddl-auto: validate} không chết lúc khởi động.
 */
```

- [ ] **Step 7: Chạy test — phải XANH y như Step 1**

```bash
cd /Users/tanvx/Dev/bank-platform && export JAVA_HOME=$(/usr/libexec/java_home -v 21) && mvn -o -pl services/bank-common,services/auth-service clean install
```

Kỳ vọng: PASS — `AuthPersistenceMappingTest` và `ServiceInfoApiTest` xanh. Đặc biệt phải thấy `dependencies` chứa `"redis"`.

- [ ] **Step 8: Xác nhận auth-service sạch javalibs**

```bash
cd /Users/tanvx/Dev/bank-platform && grep -rn "javalibs" services/auth-service/ ; echo "exit=$?"
```

Kỳ vọng: không có dòng nào, `exit=1`.

- [ ] **Step 9: Commit**

```bash
cd /Users/tanvx/Dev/bank-platform
git add services/auth-service
git commit -F - <<'EOF'
refactor(auth): gỡ javalibs, về Spring Boot trần

Service đầu tiên chuyển — khuôn mẫu cho bốn service còn lại.

Bảy starter javalibs đổi thành bốn starter chính chủ (webmvc, validation,
actuator, springdoc). javalibs-security-issuer và javalibs-cache bị bỏ hẳn:
auth chưa có luồng phát JWT nào, còn @EnableCaching thì auth không bật.
spring-boot-starter-data-redis giữ lại vì ServiceInfoApiTest assert
dependencies chứa "redis" — dòng đó tới từ DataRedisHealthIndicator.

ServiceInfoApiTest chuyển sang Jackson 3 (tools.jackson.databind). BẮT BUỘC,
không phải dọn dẹp tuỳ hứng: Jackson 2 tới classpath test CHỈ qua
javalibs-security-test -> jjwt-jackson, gỡ javalibs là lỗi compile. Đã kiểm
trên jar 3.1.4 rằng thân test không phải đổi dòng nào.

Testcontainers inline vào AbstractIntegrationTest thay vì kế thừa
BaseIntegrationTest: mỗi module Maven chạy JVM surefire riêng nên container
singleton không chia sẻ được giữa module, test-jar dùng chung không được lợi gì.

application.yml/-local/-test: xoá khối javalibs.security (secret JWT và
permit-all). Từ commit này auth-service KHÔNG còn xác thực — nợ cố ý, ghi ở
docs/KNOWN-LIMITATIONS.md tại task cuối.

Ba Javadoc nhắc javalibs-security và BaseIntegrationTest đã viết lại: sau khi
gỡ, chúng mô tả một cơ chế không còn tồn tại.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
```

---

### Task 3: product-service

**Files:**
- Modify: `services/product-service/pom.xml`
- Modify: `services/product-service/src/main/resources/application.yml`
- Modify: `services/product-service/src/main/resources/application-local.yml`
- Modify: `services/product-service/src/test/resources/application-test.yml`
- Modify: `services/product-service/src/main/java/io/bankplatform/product/web/ServiceInfoController.java`
- Modify: `services/product-service/src/main/java/io/bankplatform/product/ProductApplication.java`
- Modify: `services/product-service/src/test/java/io/bankplatform/product/AbstractIntegrationTest.java`
- Test: `services/product-service/src/test/java/io/bankplatform/product/web/ServiceInfoApiTest.java`

**Interfaces:**
- Consumes: `io.bankplatform.common.web.ApiResponse` (Task 1); khuôn `<dependencies>` và `AbstractIntegrationTest` từ Task 2

- [ ] **Step 1: Mốc xanh trước khi sửa**

```bash
cd /Users/tanvx/Dev/bank-platform && export JAVA_HOME=$(/usr/libexec/java_home -v 21) && mvn -o -pl services/product-service test
```

Kỳ vọng: PASS.

- [ ] **Step 2: Thay `<dependencies>`**

Dùng **nguyên văn khối `<dependencies>` của Task 2 Step 2** (product cũng cần Redis — `ServiceInfoApiTest` của nó assert `contains("redis")`), rồi **thêm** một dependency nữa vào ngay sau khối Redis:

```xml
    <!--
      ProductApplication có @EnableCaching. Với starter này cộng với
      spring-boot-starter-data-redis ở trên, Boot tự chọn RedisCacheManager —
      không cần cấu hình gì thêm và không cần Caffeine như bản javalibs cũ.
    -->
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-cache</artifactId>
    </dependency>
```

- [ ] **Step 3: Xoá cấu hình javalibs khỏi ba file yml**

`application.yml` — xoá toàn bộ khối `javalibs:` (kết thúc ở dòng `- /api/products/info`).

`application-local.yml` — xoá khối `javalibs:`, còn lại:

```yaml
# Profile local: chạy với hạ tầng của compose.yaml.
#   mvn -pl services/product-service spring-boot:run -Dspring-boot.run.profiles=local
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/bank

logging:
  level:
    io.bankplatform: DEBUG
```

`application-test.yml` — ghi đè:

```yaml
# Profile test do @ActiveProfiles("test") trên AbstractIntegrationTest kích hoạt.
spring:
  flyway:
    enabled: false
```

- [ ] **Step 4: Sửa import và Javadoc ServiceInfoController**

Đổi import thành `import io.bankplatform.common.web.ApiResponse;` và thay Javadoc lớp bằng:

```java
/**
 * Thông tin chi tiết của service cho dashboard dev.
 *
 * <p>Không có xác thực nào chặn endpoint này — từ 2026-09-01 service không còn
 * Spring Security (xem docs/KNOWN-LIMITATIONS.md). Kể cả khi dựng lại
 * security, endpoint này nên để mở: payload chỉ là metadata dev, không secret,
 * không connection string.</p>
 */
```

- [ ] **Step 5: Sửa comment `@EnableCaching` trong ProductApplication**

`ProductApplication.java` — comment hiện tại là `/** {@code @EnableCaching} vì service này dùng javalibs-cache cho catalog. */`, giờ sai. Thay bằng:

```java
/**
 * {@code @EnableCaching} để cache catalog sản phẩm. Cache backend là Redis:
 * spring-boot-starter-cache + spring-boot-starter-data-redis đủ để Boot tự
 * chọn RedisCacheManager. Chưa có @Cacheable nào — bật sẵn để khi thêm không
 * phải đụng lớp khởi động.
 */
```

- [ ] **Step 6: Inline Testcontainers vào AbstractIntegrationTest**

Chép **nguyên văn** file ở Task 2 Step 5, đổi đúng hai dòng:

```java
package io.bankplatform.product;
```

```java
    private static final String SCHEMA_NAME = "product";
```

Và trong Javadoc, đổi "auth-service" thành "product-service", `schema \`auth\`` thành `schema \`product\``.

- [ ] **Step 7: Chuyển ServiceInfoApiTest sang Jackson 3**

Đổi hai dòng import thành:

```java
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
```

Thân test giữ nguyên. Javadoc lớp hiện nói "chứng minh endpoint đi qua được javalibs-security mà KHÔNG cần JWT" — sai kể từ commit này. Thay bằng:

```java
/**
 * Test full-context: chứng minh endpoint /api/products/info trả đúng envelope
 * và đúng metadata khi Spring context dựng đầy đủ.
 *
 * <p>Extends {@link AbstractIntegrationTest} vì từ khi entity/repository có mặt,
 * mọi Spring context đều cần schema `product` tồn tại sẵn trong container để
 * {@code ddl-auto: validate} không chết lúc khởi động.
 */
```

- [ ] **Step 8: Chạy test — phải XANH**

```bash
cd /Users/tanvx/Dev/bank-platform && export JAVA_HOME=$(/usr/libexec/java_home -v 21) && mvn -o -pl services/product-service test
```

Kỳ vọng: PASS, `dependencies` chứa `"redis"`.

- [ ] **Step 9: Xác nhận sạch và commit**

```bash
cd /Users/tanvx/Dev/bank-platform && grep -rn "javalibs" services/product-service/ ; echo "exit=$?"
```

Kỳ vọng: rỗng, `exit=1`. Rồi:

```bash
git add services/product-service
git commit -F - <<'EOF'
refactor(product): gỡ javalibs, về Spring Boot trần

Theo khuôn auth-service. Riêng product giữ @EnableCaching nên thêm
spring-boot-starter-cache; cộng với starter-data-redis đã có, Boot tự chọn
RedisCacheManager — không cần Caffeine như bản javalibs-cache cũ.

javalibs-search bỏ hẳn: ProductRepository dùng JpaSpecificationExecutor của
Spring Data JPA thuần, không dính gì tới thư viện đó. javalibs-datahub và
spring-boot-kafka cũng bỏ — không dòng nào dùng KafkaTemplate hay
@KafkaListener.

application.yml/-local/-test: xoá khối javalibs.security. Test chuyển sang
Jackson 3 vì Jackson 2 tới classpath chỉ qua javalibs.

Comment @EnableCaching viết lại: nó đang nói service dùng javalibs-cache, sai
kể từ commit này.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
```

---

### Task 4: customer-service

**Files:**
- Modify: `services/customer-service/pom.xml`
- Modify: `services/customer-service/src/main/resources/application.yml`
- Modify: `services/customer-service/src/main/resources/application-local.yml`
- Modify: `services/customer-service/src/test/resources/application-test.yml`
- Modify: `services/customer-service/src/main/java/io/bankplatform/customer/api/ServiceInfoController.java`
- Modify: 9 file trong `services/customer-service/src/main/java/io/bankplatform/customer/domain/model/`
- Modify: `services/customer-service/src/test/java/io/bankplatform/customer/AbstractIntegrationTest.java`
- Test: `services/customer-service/src/test/java/io/bankplatform/customer/api/ServiceInfoApiTest.java`

**Interfaces:**
- Consumes: `io.bankplatform.common.ddd.Entity`, `io.bankplatform.common.ddd.AggregateRoot`, `io.bankplatform.common.web.ApiResponse` (Task 1)

- [ ] **Step 1: Mốc xanh trước khi sửa**

```bash
cd /Users/tanvx/Dev/bank-platform && export JAVA_HOME=$(/usr/libexec/java_home -v 21) && mvn -o -pl services/customer-service test
```

Kỳ vọng: PASS.

- [ ] **Step 2: Thay `<dependencies>`**

Dùng khối của Task 2 Step 2 nhưng **XOÁ khối `spring-boot-starter-data-redis`** — `ServiceInfoApiTest` của customer assert `doesNotContain("redis")`. Thay comment Redis đó bằng:

```xml
    <!--
      CỐ Ý KHÔNG có spring-boot-starter-data-redis: ServiceInfoApiTest assert
      dependencyNames(data).doesNotContain("redis"). Thêm starter này vào là
      DataRedisHealthIndicator xuất hiện và test đỏ ngay.
    -->
```

- [ ] **Step 3: Xoá cấu hình javalibs khỏi ba file yml**

`application.yml` — xoá toàn bộ khối `javalibs:` (kết thúc ở `- /api/customers/info`).

`application-local.yml` — xoá khối `javalibs:`, còn lại:

```yaml
# Profile local: chạy với hạ tầng của compose.yaml.
#   mvn -pl services/customer-service spring-boot:run -Dspring-boot.run.profiles=local
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/bank

logging:
  level:
    io.bankplatform: DEBUG
```

`application-test.yml` — ghi đè:

```yaml
# Profile test do @ActiveProfiles("test") trên AbstractIntegrationTest kích hoạt.
spring:
  flyway:
    enabled: false
```

- [ ] **Step 4: Đổi package DDD trong 9 file domain model**

7 file dùng FQN `io.javalibs.ddd.Entity<...>` trong khai báo `extends`, 2 file import `AggregateRoot`. Đổi bằng `sed` rồi kiểm lại bằng mắt:

```bash
cd /Users/tanvx/Dev/bank-platform
grep -rl "io\.javalibs\.ddd" services/customer-service/src/main/java \
  | xargs sed -i '' 's/io\.javalibs\.ddd\./io.bankplatform.common.ddd./g'
grep -rl "io\.bankplatform\.common\.ddd" services/customer-service/src/main/java | wc -l
grep -rn "io\.javalibs\.ddd" services/customer-service/src/main/java
```

Kỳ vọng: `9`, rồi lệnh thứ hai không in gì.

- [ ] **Step 5: Sửa import và Javadoc ServiceInfoController**

Đổi import thành `import io.bankplatform.common.web.ApiResponse;` và thay Javadoc lớp bằng:

```java
/**
 * Thông tin chi tiết của service cho dashboard dev.
 *
 * <p>Không có xác thực nào chặn endpoint này — từ 2026-09-01 service không còn
 * Spring Security (xem docs/KNOWN-LIMITATIONS.md). Kể cả khi dựng lại
 * security, endpoint này nên để mở: payload chỉ là metadata dev, không secret,
 * không connection string.</p>
 */
```

- [ ] **Step 6: Inline Testcontainers vào AbstractIntegrationTest**

Chép nguyên văn file ở Task 2 Step 5, đổi:

```java
package io.bankplatform.customer;
```

```java
    private static final String SCHEMA_NAME = "customer";
```

Và trong Javadoc đổi "auth-service" → "customer-service", `schema \`auth\`` → `schema \`customer\``.

- [ ] **Step 7: Chuyển ServiceInfoApiTest sang Jackson 3**

Đổi hai dòng import thành `tools.jackson.databind.JsonNode` / `ObjectMapper`. Thân test giữ nguyên. Javadoc lớp hiện nói "chứng minh endpoint đi qua được javalibs-security mà KHÔNG cần JWT" — sai kể từ commit này. Thay bằng:

```java
/**
 * Test full-context: chứng minh endpoint /api/customers/info trả đúng envelope
 * và đúng metadata khi Spring context dựng đầy đủ.
 *
 * <p>Extends {@link AbstractIntegrationTest} vì từ khi entity/repository có mặt,
 * mọi Spring context đều cần schema `customer` tồn tại sẵn trong container để
 * {@code ddl-auto: validate} không chết lúc khởi động.
 */
```

- [ ] **Step 8: Chạy test — phải XANH**

```bash
cd /Users/tanvx/Dev/bank-platform && export JAVA_HOME=$(/usr/libexec/java_home -v 21) && mvn -o -pl services/customer-service test
```

Kỳ vọng: PASS, `dependencies` **không** chứa `"redis"`.

- [ ] **Step 9: Xác nhận sạch và commit**

```bash
cd /Users/tanvx/Dev/bank-platform && grep -rn "javalibs" services/customer-service/ ; echo "exit=$?"
```

Kỳ vọng: rỗng, `exit=1`. Rồi:

```bash
git add services/customer-service
git commit -F - <<'EOF'
refactor(customer): gỡ javalibs, về Spring Boot trần

Theo khuôn auth-service, trừ Redis: ServiceInfoApiTest của customer assert
dependencies KHÔNG chứa "redis", nên service này cố ý không có
spring-boot-starter-data-redis. Đã ghi thành comment trong pom để lần sau
không ai "thống nhất" nó với auth/product rồi làm đỏ test.

Chín entity đổi io.javalibs.ddd.Entity/AggregateRoot sang
io.bankplatform.common.ddd. Bảy file dùng FQN ngay trong extends chứ không
import, nên phải sửa bằng thay chuỗi chứ không chỉ sửa dòng import.

javalibs-cqrs, -ddd-spring, -datahub, -search bỏ hẳn: không dòng code nào
dùng. application.yml/-local/-test xoá khối javalibs.security.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
```

---

### Task 5: core-banking-service

**Files:**
- Modify: `services/core-banking-service/pom.xml`
- Modify: `services/core-banking-service/src/main/resources/application.yml`
- Modify: `services/core-banking-service/src/main/resources/application-local.yml`
- Modify: `services/core-banking-service/src/test/resources/application-test.yml`
- Modify: `services/core-banking-service/src/main/java/io/bankplatform/corebanking/api/ServiceInfoController.java`
- Modify: 13 file trong `services/core-banking-service/src/main/java/io/bankplatform/corebanking/domain/`
- Modify: `services/core-banking-service/src/test/java/io/bankplatform/corebanking/AbstractIntegrationTest.java`
- Test: `services/core-banking-service/src/test/java/io/bankplatform/corebanking/api/ServiceInfoApiTest.java`

**Interfaces:**
- Consumes: `io.bankplatform.common.ddd.Entity`, `io.bankplatform.common.ddd.AggregateRoot`, `io.bankplatform.common.web.ApiResponse` (Task 1)

- [ ] **Step 1: Mốc xanh trước khi sửa**

```bash
cd /Users/tanvx/Dev/bank-platform && export JAVA_HOME=$(/usr/libexec/java_home -v 21) && mvn -o -pl services/core-banking-service test
```

Kỳ vọng: PASS.

- [ ] **Step 2: Thay `<dependencies>`**

Dùng khối `<dependencies>` viết đầy đủ ở **Task 2 Step 2**, nhưng **xoá dependency `spring-boot-starter-data-redis`** và thay comment Redis ở đó bằng:

```xml
    <!--
      CỐ Ý KHÔNG có spring-boot-starter-data-redis: ServiceInfoApiTest assert
      dependencyNames(data).doesNotContain("redis"). Thêm starter này vào là
      DataRedisHealthIndicator xuất hiện và test đỏ ngay.
    -->
```

- [ ] **Step 3: Xoá cấu hình javalibs khỏi ba file yml**

`application.yml` — xoá toàn bộ khối `javalibs:` (kết thúc ở `- /api/accounts/info`).

`application-local.yml` — xoá khối `javalibs:`, còn lại:

```yaml
# Profile local: chạy với hạ tầng của compose.yaml.
#   mvn -pl services/core-banking-service spring-boot:run -Dspring-boot.run.profiles=local
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/bank

logging:
  level:
    io.bankplatform: DEBUG
```

`application-test.yml` — ghi đè:

```yaml
# Profile test do @ActiveProfiles("test") trên AbstractIntegrationTest kích hoạt.
spring:
  flyway:
    enabled: false
```

- [ ] **Step 4: Đổi package DDD trong 13 file domain**

```bash
cd /Users/tanvx/Dev/bank-platform
grep -rl "io\.javalibs\.ddd" services/core-banking-service/src/main/java \
  | xargs sed -i '' 's/io\.javalibs\.ddd\./io.bankplatform.common.ddd./g'
grep -rl "io\.bankplatform\.common\.ddd" services/core-banking-service/src/main/java | wc -l
grep -rn "io\.javalibs\.ddd" services/core-banking-service/src/main/java
```

Kỳ vọng: `13`, rồi lệnh thứ hai không in gì.

- [ ] **Step 5: Sửa import và Javadoc ServiceInfoController**

Đổi import thành `import io.bankplatform.common.web.ApiResponse;` và thay Javadoc lớp bằng mẫu ở Task 4 Step 5.

- [ ] **Step 6: Inline Testcontainers vào AbstractIntegrationTest**

Chép nguyên văn file ở Task 2 Step 5, đổi:

```java
package io.bankplatform.corebanking;
```

```java
    private static final String SCHEMA_NAME = "core_banking";
```

Javadoc đổi "auth-service" → "core-banking-service", `schema \`auth\`` → `schema \`core_banking\``.

- [ ] **Step 7: Chuyển ServiceInfoApiTest sang Jackson 3**

Đổi hai dòng import thành `tools.jackson.databind.JsonNode` / `ObjectMapper`. Thân test giữ nguyên. Javadoc lớp hiện nói "chứng minh endpoint đi qua được javalibs-security mà KHÔNG cần JWT" — sai kể từ commit này. Thay bằng:

```java
/**
 * Test full-context: chứng minh endpoint /api/accounts/info trả đúng envelope
 * và đúng metadata khi Spring context dựng đầy đủ.
 *
 * <p>Extends {@link AbstractIntegrationTest} vì từ khi entity/repository có mặt,
 * mọi Spring context đều cần schema `core_banking` tồn tại sẵn trong container
 * để {@code ddl-auto: validate} không chết lúc khởi động.
 */
```

- [ ] **Step 8: Chạy test — phải XANH**

```bash
cd /Users/tanvx/Dev/bank-platform && export JAVA_HOME=$(/usr/libexec/java_home -v 21) && mvn -o -pl services/core-banking-service test
```

Kỳ vọng: PASS, `dependencies` **không** chứa `"redis"`.

- [ ] **Step 9: Xác nhận sạch và commit**

```bash
cd /Users/tanvx/Dev/bank-platform && grep -rn "javalibs" services/core-banking-service/ ; echo "exit=$?"
```

Kỳ vọng: rỗng, `exit=1`. Rồi:

```bash
git add services/core-banking-service
git commit -F - <<'EOF'
refactor(core-banking): gỡ javalibs, về Spring Boot trần

Theo khuôn auth-service, không Redis (ServiceInfoApiTest assert doesNotContain).

Mười một entity sổ cái/tài khoản/chuyển tiền đổi io.javalibs.ddd sang
io.bankplatform.common.ddd. Phần lớn dùng FQN ngay trong extends.

Service này khai nhiều javalibs nhất (cqrs, ddd-spring, datahub, resilience,
search) và không dùng cái nào — bỏ toàn bộ. Đã kiểm bằng grep
KafkaTemplate/@KafkaListener/CircuitBreaker/@Retry: không kết quả.

application.yml/-local/-test xoá khối javalibs.security.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
```

---

### Task 6: notification-service

**Files:**
- Modify: `services/notification-service/pom.xml`
- Modify: `services/notification-service/src/main/resources/application.yml`
- Modify: `services/notification-service/src/main/resources/application-local.yml`
- Modify: `services/notification-service/src/test/resources/application-test.yml`
- Modify: `services/notification-service/src/main/java/io/bankplatform/notification/web/ServiceInfoController.java`
- Modify: `services/notification-service/src/test/java/io/bankplatform/notification/AbstractIntegrationTest.java`
- Test: `services/notification-service/src/test/java/io/bankplatform/notification/web/ServiceInfoApiTest.java`

**Interfaces:**
- Consumes: `io.bankplatform.common.web.ApiResponse` (Task 1)

> Service này **không có** entity kế thừa `Entity`/`AggregateRoot` — không có bước đổi package DDD.

- [ ] **Step 1: Mốc xanh trước khi sửa**

```bash
cd /Users/tanvx/Dev/bank-platform && export JAVA_HOME=$(/usr/libexec/java_home -v 21) && mvn -o -pl services/notification-service test
```

Kỳ vọng: PASS.

- [ ] **Step 2: Thay `<dependencies>`**

Dùng khối `<dependencies>` viết đầy đủ ở **Task 2 Step 2**, nhưng **xoá dependency `spring-boot-starter-data-redis`** và thay comment Redis ở đó bằng:

```xml
    <!--
      CỐ Ý KHÔNG có spring-boot-starter-data-redis: ServiceInfoApiTest assert
      dependencyNames(data).doesNotContain("redis"). Thêm starter này vào là
      DataRedisHealthIndicator xuất hiện và test đỏ ngay.
    -->
```

- [ ] **Step 3: Xoá cấu hình javalibs khỏi ba file yml**

`application.yml` — xoá toàn bộ khối `javalibs:` (kết thúc ở `- /api/notifications/info`).

`application-local.yml` — xoá khối `javalibs:`, còn lại:

```yaml
# Profile local: chạy với hạ tầng của compose.yaml.
#   mvn -pl services/notification-service spring-boot:run -Dspring-boot.run.profiles=local
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/bank

logging:
  level:
    io.bankplatform: DEBUG
```

`application-test.yml` — ghi đè:

```yaml
# Profile test do @ActiveProfiles("test") trên AbstractIntegrationTest kích hoạt.
spring:
  flyway:
    enabled: false
```

- [ ] **Step 4: Sửa import và Javadoc ServiceInfoController**

Đổi import thành `import io.bankplatform.common.web.ApiResponse;` và thay Javadoc lớp bằng mẫu ở Task 4 Step 5.

- [ ] **Step 5: Inline Testcontainers vào AbstractIntegrationTest**

Chép nguyên văn file ở Task 2 Step 5, đổi:

```java
package io.bankplatform.notification;
```

```java
    private static final String SCHEMA_NAME = "notification";
```

Javadoc đổi "auth-service" → "notification-service", `schema \`auth\`` → `schema \`notification\``.

- [ ] **Step 6: Chuyển ServiceInfoApiTest sang Jackson 3**

Đổi hai dòng import thành `tools.jackson.databind.JsonNode` / `ObjectMapper`. Thân test giữ nguyên. Javadoc lớp hiện nói "chứng minh endpoint đi qua được javalibs-security mà KHÔNG cần JWT" — sai kể từ commit này. Thay bằng:

```java
/**
 * Test full-context: chứng minh endpoint /api/notifications/info trả đúng
 * envelope và đúng metadata khi Spring context dựng đầy đủ.
 *
 * <p>Extends {@link AbstractIntegrationTest} vì từ khi entity/repository có mặt,
 * mọi Spring context đều cần schema `notification` tồn tại sẵn trong container
 * để {@code ddl-auto: validate} không chết lúc khởi động.
 */
```

- [ ] **Step 7: Chạy test — phải XANH**

```bash
cd /Users/tanvx/Dev/bank-platform && export JAVA_HOME=$(/usr/libexec/java_home -v 21) && mvn -o -pl services/notification-service test
```

Kỳ vọng: PASS, `dependencies` **không** chứa `"redis"`.

- [ ] **Step 8: Xác nhận sạch và commit**

```bash
cd /Users/tanvx/Dev/bank-platform && grep -rn "javalibs" services/notification-service/ ; echo "exit=$?"
```

Kỳ vọng: rỗng, `exit=1`. Rồi:

```bash
git add services/notification-service
git commit -F - <<'EOF'
refactor(notification): gỡ javalibs, về Spring Boot trần

Service cuối cùng, theo khuôn auth-service, không Redis.

javalibs-datahub và -resilience bỏ hẳn dù đây là service "gửi thông báo" —
nghe như đúng chỗ cần Kafka và circuit breaker, nhưng chưa dòng code nào tồn
tại để dùng chúng. Thêm lại khi viết luồng gửi thật.

Service này không có entity kế thừa Entity/AggregateRoot nên không phải đổi
package DDD như customer và core-banking.

application.yml/-local/-test xoá khối javalibs.security.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
```

---

### Task 7: Xoá platform-libs, dọn root pom, CI và tài liệu

Task cuối. Sau task này `grep -rn javalibs` toàn repo chỉ còn những chỗ tài liệu **cố ý** nhắc tới lịch sử.

**Files:**
- Delete: `platform-libs/` (431 file tracked)
- Modify: `pom.xml`
- Modify: `services/gateway-service/src/main/java/io/bankplatform/gateway/web/dto/ApiEnvelope.java`
- Modify: `.env.sample`
- Modify: `.github/workflows/ci.yml`
- Modify: `README.md`
- Modify: `docs/KNOWN-LIMITATIONS.md`

**Interfaces:**
- Consumes: mọi thứ từ Task 1–6 (không service nào còn tham chiếu javalibs)

- [ ] **Step 1: Chứng minh không còn ai dùng javalibs trước khi xoá**

```bash
cd /Users/tanvx/Dev/bank-platform && grep -rn "javalibs" --exclude-dir=.git --exclude-dir=platform-libs --exclude-dir=node_modules . | grep -v "^./docs/superpowers/"
```

Kỳ vọng: chỉ còn `pom.xml` (profile `with-libs`), `.github/workflows/ci.yml`, `README.md`, `docs/KNOWN-LIMITATIONS.md`, và comment ở `ApiEnvelope.java`. **Không** file nào dưới `services/*/src/`. Nếu còn, quay lại task tương ứng.

- [ ] **Step 2: Xoá platform-libs**

```bash
cd /Users/tanvx/Dev/bank-platform && git rm -r --quiet platform-libs && git status --short | head -5
```

- [ ] **Step 3: Xoá profile `with-libs` khỏi root pom**

Xoá **toàn bộ** khối `<profiles>...</profiles>` ở cuối `pom.xml` (gồm cả comment dài giải thích vì sao là profile "thêm vào"). Root pom sau bước này không còn chữ `javalibs` nào.

Đồng thời sửa `<description>` — nó đang nói repo gồm platform-libs:

```xml
  <description>Monorepo core banking: bank-common, 5 service nghiệp vụ + gateway.</description>
```

- [ ] **Step 4: Sửa comment ApiEnvelope của gateway**

`services/gateway-service/src/main/java/io/bankplatform/gateway/web/dto/ApiEnvelope.java`, dòng nhắc `io.javalibs.web.ApiResponse` — đổi thành:

```java
 * Bản sao HÌNH DẠNG của io.bankplatform.common.web.ApiResponse. Gateway cố ý không
```

Giữ nguyên phần còn lại của câu (lý do gateway không phụ thuộc bank-common).

- [ ] **Step 5: Gỡ JWT_SECRET khỏi .env.sample**

Xoá hai dòng:

```
# Bí mật ký JWT. Tối thiểu 32 byte. Mỗi môi trường một giá trị khác nhau.
JWT_SECRET=change-me-to-at-least-32-bytes-of-random-data
```

Thay bằng:

```
# JWT_SECRET đã bỏ (2026-09-01): không service nào còn Spring Security.
# Thêm lại khi dựng xong luồng xác thực — xem docs/KNOWN-LIMITATIONS.md.
```

- [ ] **Step 6: Sửa CI**

`.github/workflows/ci.yml` — thay khối comment trên bước "Build toàn reactor":

```yaml
      # platform-libs đã gỡ khỏi repo (2026-09-01); reactor giờ chỉ còn
      # bank-common + 6 service.
      - name: Build toàn reactor
        run: mvn -B clean install -DskipTests
```

Phần "Kiểm tra schema.sql chạy được" giữ nguyên hoàn toàn.

- [ ] **Step 7: Cập nhật README**

Sửa mọi chỗ nhắc `platform-libs`/`javalibs` trong `README.md` cho khớp cây thư mục mới (`services/bank-common`, không còn `platform-libs/`). Nếu README có lệnh `mvn -P'!with-libs'`, xoá — profile đó không còn.

- [ ] **Step 8: Ghi nợ kỹ thuật vào KNOWN-LIMITATIONS**

Thêm mục mới vào `docs/KNOWN-LIMITATIONS.md`:

````markdown
## Hạ tầng gỡ cùng platform-libs (2026-09-01)

`platform-libs` (javalibs) đã bị xoá khỏi repo để chủ dự án tự viết lại phần hạ
tầng — mục tiêu là *học hiểu bản chất*, nên các khoản dưới đây là **nợ cố ý**,
không phải bỏ sót. Tham khảo bản cũ: `git show b095cd5:platform-libs/...`

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

### Không có cấu hình CORS

Frontend gọi thẳng service (không qua gateway) sẽ bị chặn. Hiện frontend đi qua
gateway nên chưa lộ ra.

### AggregateRoot không có cơ chế domain event

Bản javalibs cũ có `registerEvent`/`pullDomainEvents`/`DomainEvent`.
`io.bankplatform.common.ddd.AggregateRoot` hiện chỉ là dấu hiệu kiểu.

Xử khi: publish domain event đầu tiên.

### Mất lưới an toàn Flyway

`clean-disabled` và phép kiểm quy ước đặt tên migration của
`javalibs-persistence` không còn. `spring.flyway.clean-disabled: true` vẫn có
trong cả 5 `application.yml`, nhưng phần kiểm tên migration thì không.

Xử khi: cắt migration đầu tiên từ `schema.sql`.

### Mất tiện ích test JWT

`JwtTestFactory` và `TestUserContexts` của `javalibs-security-test` không còn.
Test nào cần token phải tự dựng.
````

- [ ] **Step 9: Build sạch toàn reactor**

```bash
cd /Users/tanvx/Dev/bank-platform && export JAVA_HOME=$(/usr/libexec/java_home -v 21) && mvn clean install -DskipTests
```

Dùng `mvn` **không** `-o`: lần đầu sau khi bỏ BOM javalibs cần resolve lại từ mạng. Kỳ vọng: BUILD SUCCESS, **7 module** (bank-common + 6 service), không còn 17 module javalibs.

- [ ] **Step 10: Chạy toàn bộ test thật**

Docker phải đang chạy.

```bash
cd /Users/tanvx/Dev/bank-platform && export JAVA_HOME=$(/usr/libexec/java_home -v 21) && mvn test 2>&1 | tail -40
```

Kỳ vọng: BUILD SUCCESS, không test nào lỗi hay bị skip.

- [ ] **Step 11: Xác nhận repo sạch javalibs**

```bash
cd /Users/tanvx/Dev/bank-platform && grep -rn "javalibs" --exclude-dir=.git --exclude-dir=node_modules . | grep -v "docs/superpowers/\|docs/KNOWN-LIMITATIONS.md\|services/bank-common/README.md"
```

Kỳ vọng: **rỗng**. Ba đường dẫn được loại trừ là nơi cố ý nhắc tới lịch sử.

- [ ] **Step 12: Khởi động thật một service**

Bằng chứng cuối: service không chỉ compile mà còn boot được.

```bash
cd /Users/tanvx/Dev/bank-platform && docker compose up -d postgres redis
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
mvn -pl services/auth-service spring-boot:run -Dspring-boot.run.profiles=local
```

Ở terminal khác:

```bash
curl -s localhost:8081/api/auth/info | head -c 400
```

Kỳ vọng: JSON có `"success":true` và `"serviceName":"auth-service"`, **không** bị 401 (đã hết security). Xong thì `Ctrl+C` và `docker compose down`.

- [ ] **Step 13: Commit**

```bash
cd /Users/tanvx/Dev/bank-platform
git add -A
git commit -F - <<'EOF'
refactor!: xoá platform-libs khỏi repo

Chủ dự án tự viết lại phần hạ tầng để hiểu bản chất, nên javalibs bị xoá hẳn
chứ không giữ lại tham khảo — lịch sử git đã đủ:
  git show b095cd5:platform-libs/<đường-dẫn>

431 file, 303 file Java, 17 module. Sáu task trước đã gỡ hết tham chiếu nên
bước này chỉ còn xoá và dọn: profile with-libs ở root pom, comment CI về
with-libs, JWT_SECRET ở .env.sample, và comment ApiEnvelope của gateway.

BREAKING: cả 5 service giờ KHÔNG có xác thực — mọi endpoint mở. Cùng với sáu
khoản nợ cố ý khác (envelope lỗi, correlation-id, CORS, domain event, lưới an
toàn Flyway, tiện ích test JWT), đã ghi thành mục riêng ở
docs/KNOWN-LIMITATIONS.md kèm điều kiện xử từng khoản.

Bằng chứng: mvn clean install xanh với 7 module; toàn bộ test xanh trên
Testcontainers thật; auth-service boot với profile local và GET
/api/auth/info trả 200 không cần token.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
```

---

## Sau khi xong

1. Chạy `superpowers:requesting-code-review` cho toàn branch. Soát cả file **ngoài** danh sách Files đã khai — tiền lệ 2026-08-19: config runtime lọt vào commit không khai báo, chỉ final review toàn branch mới bắt được.
2. Săn comment mô tả sai cơ chế trên toàn diff. Repo này đã bắt 11 lần; task này sửa/xoá comment ở ít nhất 20 chỗ nên rủi ro cao.
3. Merge `--no-ff` vào `master`, xoá branch `refactor/remove-platform-libs`, xoá worktree rỗng
   `.claude/worktrees/remove-platform-libs-move-bank-common-79fb3a` và branch
   `claude/remove-platform-libs-move-bank-common-79fb3a` mà harness tạo lúc đầu phiên.
4. Cập nhật memory `bank-platform-env-gotchas`: mục "họ lỗi im lặng của javalibs" đã hết
   hiệu lực; thay bằng bẫy mới "Jackson 2 chỉ tới qua dependency của bên thứ ba".
