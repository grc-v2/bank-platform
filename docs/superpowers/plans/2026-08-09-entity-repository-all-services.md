# Entity + Repository cho 5 service nghiệp vụ — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tạo JPA entity + Spring Data repository cho toàn bộ bảng nghiệp vụ của 5 service (auth, notification, product, customer, core-banking), được chứng minh đúng bằng Hibernate `ddl-auto: validate` + round-trip test trên Postgres Testcontainers chạy đúng `schema.sql`.

**Architecture:** Mức B (auth/product/notification): entity trong `model/`, repository trong `repository/`. Mức A (customer/core-banking): hướng **thực dụng** theo doc javalibs (`project-structure.md` §"Ghi chú thực dụng") — gắn `@Entity` thẳng lên aggregate trong `domain/**/model/`, port repository `extends JpaRepository` đặt trong `domain/port/` (customer) hoặc `domain/<aggregate>/` (core-banking). Schema test được nạp bằng cách chạy nguyên văn `docs/database/schema.sql` (nguồn sự thật duy nhất — quyết định D5) vào container Postgres singleton của `javalibs-test`, một lần mỗi JVM.

**Tech Stack:** Spring Boot 4.1 / Hibernate ORM 7 / Java 21 / PostgreSQL (Testcontainers 16-alpine cho test, 17 cho compose) / javalibs (BOM `io.javalibs:javalibs-dependencies:2.0.0-SNAPSHOT`).

## Ràng buộc toàn cục

- `export JAVA_HOME=$(/usr/libexec/java_home -v 21)` trước **mọi** lệnh `mvn` (shell non-interactive không có sẵn).
- Build bằng `mvn -B -P'!with-libs' ...` (javalibs 2.0.0-SNAPSHOT đã nằm trong local repo; profile này bỏ `platform-libs` khỏi reactor cho nhanh).
- Test **bắt buộc** đặt tên `*Test` (surefire bỏ `*IT` trong im lặng — bài học đã ghi).
- Cần Docker daemon cho Testcontainers. `docker ps` trước khi chạy; máy có container của project khác (`grc-platform`, `certi-hub`) — **không dừng/xoá container không thuộc bank-platform**.
- KHÔNG sửa `platform-libs/**` (quyết định D2), KHÔNG sửa `docs/database/schema.sql`, KHÔNG bật Flyway (spec §7: bật khi cắt migration — vòng sau §9).
- Không Lombok (quy tắc javalibs toàn thư viện). Entity là class thường (JPA cần no-arg constructor); không dùng `record` cho entity.
- Nguồn sự thật cột/kiểu/constraint: `docs/database/schema.sql`. Mỗi task ghi rõ khoảng dòng — **đọc nguyên khối đó trước khi viết code**, đừng suy từ plan này.
- Commit message tiếng Việt, kể *vì sao*. Javadoc/comment tiếng Việt, chỉ ghi ràng buộc mà code không tự nói được.
- `gateway-service` KHÔNG có DB (spec D-starter: "không dùng javalibs, không chạm DB") → ngoài phạm vi.

## Quyết định đã phân xử (ledger)

| # | Quyết định | Căn cứ |
|---|---|---|
| L1 | **Không map** 3 bảng `outbox` (customer/product/core_banking) và 2 bảng `processed_events` (notification/core_banking) | Đây là bảng hạ tầng của vòng eventing. javalibs-datahub (`TransactionalOutbox`, `IdempotentEventProcessor`) dùng bảng riêng (`datahub_outbox_event`, `datahub_processed_event`) khác cấu trúc — map bây giờ là đoán trước một quyết định (dùng datahub hay tự viết publisher) chưa được phân xử. Hibernate validate không đụng bảng không map. Ghi vào README từng service. |
| L2 | Mức A theo hướng **thực dụng** (JPA trên aggregate, port extends JpaRepository) | `project-structure.md` javalibs ghi rõ "khuyến nghị mặc định". Ghi lựa chọn vào README của customer + core-banking (doc bắt buộc). |
| L3 | `journal_lines`: `@Id` chỉ trên `id`, không map composite PK `(id, created_at)` | Hibernate không sinh được một nửa composite key bằng IDENTITY. PK của DB chứa `created_at` **chỉ vì** Postgres bắt PK bảng partition chứa cột partition; `id` vẫn duy nhất toàn cục nhờ một sequence duy nhất. Hibernate validate không so sánh PK, chỉ so bảng/cột/kiểu. |
| L4 | Không map cột `created_txid` (xid8, journal_entries) và `customer_type` ở `individual_details`/`organization_details` | `created_txid` là cơ chế nội bộ DB cho `trg_journal_lines_same_txn` (comment schema cấm đụng); xid8 không có kiểu Hibernate tương ứng. `customer_type` bảng con là hiện vật của FK-theo-cặp (disjoint subtype), DB tự điền qua DEFAULT + CHECK. Cột không map nhưng có DEFAULT thì INSERT vẫn đúng. |
| L5 | Timestamp "đời bản ghi" do **DB giữ** | Schema ghi rõ "updated_at do DB giữ" (trigger `set_updated_at`) và mọi `created_at`/`*_at` sinh lúc INSERT đều có `DEFAULT now()`. Java map `insertable=false, updatable=false` + `@Generated` để Hibernate đọc lại sau flush. Ngày **nghiệp vụ** (value_date, booking_date, accrual_date, effective_from, window_start, expires_at…) luôn do app đặt dù có DEFAULT. |
| L6 | Schema cho test = chạy nguyên văn `schema.sql` vào singleton container, guard idempotent theo tên schema | Giữ D5 (một file, không bản sao, không drift). `BaseIntegrationTest` không có hook init; `postgres()` protected static cho phép static-block của lớp con nạp trước khi Spring context dựng. |
| L7 | `LedgerDirection` là enum nội bộ `core-banking` | Spec §5 dự kiến nó ở `bank-common/type` cùng Money/Currency…, nhưng bank-common còn rỗng và VO nghiệp vụ là phase riêng. Di cư khi làm phase event contract. |
| L8 | `user_roles` = `@ElementCollection` trên `User`, không entity/repository riêng | Bảng chỉ có (user_id, role); vòng đời gắn chặt User; javalibs-security nhận role từ JWT chứ không từ bảng này. |
| L9 | Repository chỉ thêm finder suy ra từ UNIQUE key (findByUsername, findByAccountNumber…) | Phase này là mapping; query nghiệp vụ thuộc phase use-case. |
| L10 | Test round-trip chạy trong `@Transactional` (rollback) | Trigger DEFERRED (cân bút toán) chỉ chạy lúc COMMIT nên không cản test mapping; dữ liệu tự dọn, không đụng seed. |

## Quy ước mapping chung (áp cho MỌI task)

**Kiểu dữ liệu:**

| Postgres | Java |
|---|---|
| BIGSERIAL / BIGINT | `Long` (`@Id @GeneratedValue(strategy = GenerationType.IDENTITY)` cho PK) |
| INT | `Integer` (nullable) / `int` |
| SMALLINT | `Short`/`short` (map `Integer` sẽ fail validate) |
| NUMERIC(19,4), NUMERIC(9,6) | `BigDecimal` (+ `precision`/`scale` trên `@Column` làm tài liệu) |
| VARCHAR / TEXT | `String` |
| CHAR(n) | `String` + `@JdbcTypeCode(SqlTypes.CHAR)` — validate so kiểu CHAR ≠ VARCHAR; nếu vẫn fail, fallback `columnDefinition = "char(n)"` |
| BOOLEAN | `boolean` / `Boolean` (nullable) |
| TIMESTAMPTZ | `OffsetDateTime` |
| DATE | `LocalDate` |
| JSONB | `String` + `@JdbcTypeCode(SqlTypes.JSON)` |
| INET | `String` + `@JdbcTypeCode(SqlTypes.INET)`; nếu validate/round-trip fail thì thử `columnDefinition = "inet"`, bất đắc dĩ mới bỏ map cột (ghi README) |

**Cột DB giữ (L5)** — mẫu chuẩn:

```java
import org.hibernate.annotations.Generated;
import org.hibernate.generator.EventType;

@Generated(event = EventType.INSERT)
@Column(name = "created_at", insertable = false, updatable = false)
private OffsetDateTime createdAt;

@Generated(event = {EventType.INSERT, EventType.UPDATE})
@Column(name = "updated_at", insertable = false, updatable = false)
private OffsetDateTime updatedAt;
```

(Nếu API `@Generated` khác trên version Hibernate trong BOM — sửa theo compile error, giữ nguyên ý: Hibernate không ghi cột, đọc lại sau flush.)

**Enum:** mỗi CHECK `IN (...)` một enum Java cùng package với entity, giá trị **đúng nguyên văn** danh sách CHECK; map:

```java
@Enumerated(EnumType.STRING)
@Column(name = "status", nullable = false)
private UserStatus status;
```

**Optimistic lock:** cột `version` (accounts, transfers) → `@Version @Column(name = "version") private int version;`

**Quan hệ:** trong cùng aggregate → association hai chiều `@OneToMany(mappedBy=..., cascade=..., fetch=LAZY)`; mọi `@ManyToOne`/`@OneToOne` đều `fetch = FetchType.LAZY`. Tham chiếu **ngoài aggregate hoặc xuyên schema** (user_id, customer_id, gl_code, product_code, account_id ở bảng độc lập…) → cột thường `Long`/`String`, KHÔNG association. Bảng/quan hệ append-only → cascade chỉ `PERSIST`, không `orphanRemoval`, không setter.

**Constructor/accessor:** `protected` no-arg cho JPA + constructor public nhận đủ cột NOT NULL do app đặt; getter đủ; setter **chỉ** cho trường app được phép sửa (bảng append-only: login_audit, audit_log, journal_entries, journal_lines, customer_risk_assessments, kyc_documents, delivery_attempts, account_balance_snapshots, interest_accruals(*trừ posted/journal_entry_id*), fee_charges(*trừ status/journal_entry_id*) → không setter ngoài các ngoại lệ ghi chú).

**Mức A:** aggregate root `extends io.javalibs.ddd.AggregateRoot<Long>`, entity con `extends io.javalibs.ddd.Entity<Long>` (được equals/hashCode theo id), override `getId()`. Lớp `@EmbeddedId` là class thường `implements Serializable` + equals/hashCode đủ 2-3 trường. Mức B: POJO thuần (không có dependency ddd).

**Lớp test base mỗi service** (đổi package + tên schema guard; còn lại giữ nguyên văn):

```java
package io.bankplatform.auth; // đổi theo service

import io.javalibs.test.BaseIntegrationTest;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;

/**
 * Nạp docs/database/schema.sql (nguồn sự thật duy nhất — quyết định D5) vào
 * container Postgres singleton của javalibs-test, đúng MỘT lần mỗi JVM test.
 * Idempotent: schema của service đã tồn tại thì bỏ qua. Phải chạy trong static
 * block để xong TRƯỚC khi Spring context dựng (ddl-auto: validate cần bảng).
 */
public abstract class AbstractIntegrationTest extends BaseIntegrationTest {

    private static final String SCHEMA_NAME = "auth"; // đổi theo service

    static {
        try (Connection conn = DriverManager.getConnection(
                postgres().getJdbcUrl(), postgres().getUsername(), postgres().getPassword());
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

`it_user` của container là superuser nên `CREATE ROLE`/`CREATE EXTENSION`/`SET ROLE` trong schema.sql chạy được; PgJDBC hiểu dollar-quoting nên nguyên file đi qua một `Statement.execute` được.

**Test mapping mỗi service:** một class `<Tên>PersistenceMappingTest extends AbstractIntegrationTest`, đánh dấu `@Transactional` (rollback, L10), `@Autowired` các repository + `EntityManager em`. Mỗi bảng map ít nhất một round-trip: dựng entity → `repository.saveAndFlush(...)` → `em.clear()` → đọc lại bằng finder/`findById` → assert vài cột đặc trưng + cột DB-giữ không null. Việc context khởi động được (Hibernate validate) đã là phép kiểm mapping quan trọng nhất — ServiceInfoApiTest hiện có cũng phải đổi sang extends `AbstractIntegrationTest` vì từ giờ context nào cũng cần schema.

**Lệnh kiểm mỗi service:**

```bash
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
cd /Users/tanvx/Dev/bank-platform
mvn -B -P'!with-libs' -pl services/<service> -am test
```

---

### Task 1: auth-service (Mức B) — schema `auth`, dòng 167–233 của schema.sql

**Files:**
- Create: `services/auth-service/src/main/java/io/bankplatform/auth/model/{User,UserStatus,UserRole,RefreshToken,LoginAudit}.java`
- Create: `services/auth-service/src/main/java/io/bankplatform/auth/repository/{UserRepository,RefreshTokenRepository,LoginAuditRepository}.java`
- Create: `services/auth-service/src/test/java/io/bankplatform/auth/AbstractIntegrationTest.java`
- Create: `services/auth-service/src/test/java/io/bankplatform/auth/AuthPersistenceMappingTest.java`
- Modify: `services/auth-service/src/test/java/io/bankplatform/auth/web/ServiceInfoApiTest.java` (extends `AbstractIntegrationTest`)
- Modify: `services/auth-service/README.md` (ghi: bảng đã map, `user_roles` là ElementCollection — L8; không có bảng bỏ qua)

**Interfaces (produces):**
- `UserRepository extends JpaRepository<User, Long>` + `Optional<User> findByUsername(String username)`
- `RefreshTokenRepository extends JpaRepository<RefreshToken, Long>` + `Optional<RefreshToken> findByTokenHash(String tokenHash)`
- `LoginAuditRepository extends JpaRepository<LoginAudit, Long>` (append-only, không finder thêm)

Điểm gai: `users.status` enum ACTIVE/LOCKED/DISABLED; `user_roles` ElementCollection enum `UserRole` (CUSTOMER, TELLER, CSO, RISK_OFFICER, ADMIN, SYSTEM):

```java
@ElementCollection(fetch = FetchType.LAZY)
@CollectionTable(name = "user_roles", joinColumns = @JoinColumn(name = "user_id"))
@Enumerated(EnumType.STRING)
@Column(name = "role", nullable = false)
private Set<UserRole> roles = new HashSet<>();
```

`refresh_tokens.user_id` → `Long userId` (không association — User là aggregate khác vòng đời token). `login_audit`: append-only, không setter; cột `ip INET` theo quy ước chung; cột `at` → field `occurredAt` (`@Column(name = "at")`), DB giữ; `user_id` nullable; **không FK** sang users (cố ý — giữ được đăng nhập bằng username không tồn tại).

- [ ] **Bước 1:** Đọc schema.sql dòng 167–233 + phần Quy ước chung của plan này
- [ ] **Bước 2:** Tạo `AbstractIntegrationTest` (mẫu ở Quy ước, `SCHEMA_NAME = "auth"`), đổi `ServiceInfoApiTest` extends nó
- [ ] **Bước 3:** Viết `AuthPersistenceMappingTest` (RED — chưa compile vì entity chưa tồn tại):

```java
package io.bankplatform.auth;

import io.bankplatform.auth.model.*;
import io.bankplatform.auth.repository.*;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;

@Transactional
class AuthPersistenceMappingTest extends AbstractIntegrationTest {

    @Autowired UserRepository users;
    @Autowired RefreshTokenRepository refreshTokens;
    @Autowired LoginAuditRepository loginAudits;
    @Autowired EntityManager em;

    @Test
    void userRoundTrip_kemRoles() {
        User u = new User("teller01", "$2a$10$hash-gia-du-60-ky-tu");
        u.getRoles().add(UserRole.TELLER);
        u.getRoles().add(UserRole.ADMIN);
        users.saveAndFlush(u);
        em.clear();

        User loaded = users.findByUsername("teller01").orElseThrow();
        assertThat(loaded.getStatus()).isEqualTo(UserStatus.ACTIVE);
        assertThat(loaded.getRoles()).containsExactlyInAnyOrder(UserRole.TELLER, UserRole.ADMIN);
        assertThat(loaded.getCreatedAt()).isNotNull(); // DB giữ, Hibernate đọc lại
        assertThat(loaded.getUpdatedAt()).isNotNull();
    }

    @Test
    void refreshTokenRoundTrip() {
        User u = users.saveAndFlush(new User("cust01", "$2a$10$hash"));
        RefreshToken t = new RefreshToken(u.getId(), "a".repeat(64), OffsetDateTime.now().plusDays(30));
        refreshTokens.saveAndFlush(t);
        em.clear();

        RefreshToken loaded = refreshTokens.findByTokenHash("a".repeat(64)).orElseThrow();
        assertThat(loaded.getUserId()).isEqualTo(u.getId());
        assertThat(loaded.getRevokedAt()).isNull();
        assertThat(loaded.getCreatedAt()).isNotNull();
    }

    @Test
    void loginAuditRoundTrip_inet() {
        LoginAudit a = new LoginAudit("ai-do", null, false, "203.0.113.7", "curl/8");
        loginAudits.saveAndFlush(a);
        em.clear();

        LoginAudit loaded = loginAudits.findById(a.getId()).orElseThrow();
        assertThat(loaded.isSuccess()).isFalse();
        assertThat(loaded.getIp()).isEqualTo("203.0.113.7");
        assertThat(loaded.getOccurredAt()).isNotNull();
    }
}
```

- [ ] **Bước 4:** Chạy `mvn -B -P'!with-libs' -pl services/auth-service -am test` → FAIL (compile error — entity chưa có)
- [ ] **Bước 5:** Viết 3 enum + 3 entity + 3 repository theo schema + quy ước (User có constructor `(String username, String passwordHash)` tự đặt `status = ACTIVE`; LoginAudit constructor `(String username, Long userId, boolean success, String ip, String userAgent)`)
- [ ] **Bước 6:** Chạy lại lệnh trên → PASS toàn bộ (kể cả ServiceInfoApiTest)
- [ ] **Bước 7:** Cập nhật README.md của service (mục "Persistence": bảng map, quyết định L8)
- [ ] **Bước 8:** Commit: `feat(auth): entity + repository schema auth — validate trên schema.sql thật qua Testcontainers`

---

### Task 2: notification-service (Mức B) — schema `notification`, dòng 235–339

**Files:**
- Create: `services/notification-service/src/main/java/io/bankplatform/notification/model/{NotificationTemplate,Notification,NotificationStatus,NotificationChannel,DeliveryAttempt,DeliveryAttemptStatus,WebhookEndpoint,NotificationPreference,NotificationPreferenceId}.java`
- Create: `services/notification-service/src/main/java/io/bankplatform/notification/repository/{NotificationTemplateRepository,NotificationRepository,DeliveryAttemptRepository,WebhookEndpointRepository,NotificationPreferenceRepository}.java`
- Create: `services/notification-service/src/test/java/io/bankplatform/notification/AbstractIntegrationTest.java` (`SCHEMA_NAME = "notification"`)
- Create: `services/notification-service/src/test/java/io/bankplatform/notification/NotificationPersistenceMappingTest.java`
- Modify: `services/notification-service/src/test/java/io/bankplatform/notification/web/ServiceInfoApiTest.java`
- Modify: `services/notification-service/README.md` (bảng bỏ qua: `processed_events` — L1)

**Interfaces (produces):**
- `NotificationTemplateRepository extends JpaRepository<NotificationTemplate, Long>`
- `NotificationRepository extends JpaRepository<Notification, Long>`
- `DeliveryAttemptRepository extends JpaRepository<DeliveryAttempt, Long>`
- `WebhookEndpointRepository extends JpaRepository<WebhookEndpoint, Long>`
- `NotificationPreferenceRepository extends JpaRepository<NotificationPreference, NotificationPreferenceId>`

Điểm gai: `NotificationChannel` (TELEGRAM/EMAIL/WEBHOOK) dùng chung cho templates/notifications/prefs — một enum duy nhất. `notifications.payload` JSONB NOT NULL. `DeliveryAttempt` trong aggregate Notification? KHÔNG — giữ độc lập (job retry ghi attempt không cần load Notification), `notification_id` là `Long`. `delivery_attempts`/`notifications` append-only về attempt/audit nhưng `notifications.status` app cập nhật → setter cho status. `user_notification_preferences` PK 3 cột:

```java
@Embeddable
public class NotificationPreferenceId implements Serializable {
    @Column(name = "user_id")    private Long userId;
    @Column(name = "event_type") private String eventType;
    @Enumerated(EnumType.STRING)
    @Column(name = "channel")    private NotificationChannel channel;
    // no-arg protected + constructor đủ 3 trường + equals/hashCode trên cả 3
}
```

`user_notification_preferences.updated_at` DB giữ (có trigger riêng — dòng 333). `webhook_endpoints.last_status` `Integer` nullable, `secret` KHÔNG bao giờ log ra (chỉ field thường).

- [ ] **Bước 1:** Đọc schema.sql dòng 235–339 + Quy ước chung
- [ ] **Bước 2:** `AbstractIntegrationTest` + đổi `ServiceInfoApiTest`
- [ ] **Bước 3:** Viết `NotificationPersistenceMappingTest` (RED). Round-trip: (a) template save→findById assert version/active default từ constructor; (b) notification payload JSONB `{"amount":100000,"currency":"VND"}` → đọc lại assert chứa `"amount"`; (c) attempt với notificationId + attemptNo 1; (d) webhook endpoint; (e) preference composite id save → `findById(new NotificationPreferenceId(9L, "transfer.completed.v1", NotificationChannel.EMAIL))` assert enabled + updatedAt not null
- [ ] **Bước 4:** Chạy test → FAIL
- [ ] **Bước 5:** Viết entity/enum/repository
- [ ] **Bước 6:** Chạy → PASS
- [ ] **Bước 7:** README (mục Persistence + lý do bỏ `processed_events`)
- [ ] **Bước 8:** Commit: `feat(notification): entity + repository schema notification — bỏ processed_events chờ phán quyết datahub`

---

### Task 3: product-service (Mức B) — schema `product`, dòng 562–790

**Files:**
- Create: `services/product-service/src/main/java/io/bankplatform/product/model/{Product,ProductCategory,ProductStatus,ProductInterestRate,ProductFee,FeeType,ChargeEvent,ProductLimit,LimitScope,LimitChannel,ProductEligibilityRule,EligibilityRuleType,RuleOperator,ProductGlMapping,GlMappingPurpose}.java`
- Create: `services/product-service/src/main/java/io/bankplatform/product/repository/{ProductRepository,ProductInterestRateRepository,ProductFeeRepository,ProductLimitRepository,ProductEligibilityRuleRepository,ProductGlMappingRepository}.java`
- Create: `services/product-service/src/test/java/io/bankplatform/product/AbstractIntegrationTest.java` (`SCHEMA_NAME = "product"`)
- Create: `services/product-service/src/test/java/io/bankplatform/product/ProductPersistenceMappingTest.java`
- Modify: `services/product-service/src/test/java/io/bankplatform/product/web/ServiceInfoApiTest.java`
- Modify: `services/product-service/README.md` (bỏ qua `outbox` — L1)

**Interfaces (produces):**
- `ProductRepository extends JpaRepository<Product, Long>, JpaSpecificationExecutor<Product>` + `Optional<Product> findByProductCode(String productCode)` (service có javalibs-search)
- 5 repository con `extends JpaRepository<<Entity>, Long>` + mỗi cái một finder `List<...> findByProductId(Long productId)`

Điểm gai: 5 bảng con FK `product_id ON DELETE CASCADE` — vẫn map `Long productId` (KHÔNG association hai chiều): catalog đọc nhiều ghi ít, các bảng con được query theo `product_id` + effective date ở phase nghiệp vụ, không cần object graph. Product vì thế không có collection con — ghi rõ trong README (đây là lựa chọn có chủ đích, khác mặc định "aggregate ôm hết"). `annual_rate NUMERIC(9,6)`, `percent NUMERIC(9,6)` → BigDecimal. EXCLUDE constraint (ex_rate_overlap…) không ảnh hưởng mapping nhưng ảnh hưởng **test data**: seed đã có CA_STANDARD/SA_STANDARD/TD_12M kèm rate/fee/limit — test phải tạo product MỚI (`TEST_PROD`) rồi treo bảng con vào đó, không đụng seed. `effective_from` ngày nghiệp vụ → app đặt (constructor nhận, hoặc mặc định `LocalDate.now()` tường minh trong constructor).

- [ ] **Bước 1:** Đọc schema.sql dòng 562–790 + Quy ước chung (đọc kỹ comment EXCLUDE + seed dòng 1492–1551)
- [ ] **Bước 2:** `AbstractIntegrationTest` + đổi `ServiceInfoApiTest`
- [ ] **Bước 3:** Viết `ProductPersistenceMappingTest` (RED). Round-trip: (a) đọc seed `findByProductCode("CA_STANDARD")` assert category CURRENT_ACCOUNT, status ACTIVE — chứng minh mapping đọc được dữ liệu thật; (b) tạo `TEST_PROD` + 1 rate (tier 0→null, term null, rate 0.012) + 1 fee FLAT 5000 MONTHLY_MAINTENANCE + 1 limit PER_DAY ANY maxAmount 10^9 + 1 rule MIN_AGE GTE "18" + 1 glMapping PRINCIPAL "2010" → flush, clear, đọc lại bằng `findByProductId` assert từng loại
- [ ] **Bước 4:** Chạy test → FAIL
- [ ] **Bước 5:** Viết entity/enum/repository
- [ ] **Bước 6:** Chạy → PASS
- [ ] **Bước 7:** README (Persistence + lý do không collection con + bỏ outbox)
- [ ] **Bước 8:** Commit: `feat(product): entity + repository schema product — bảng con tham chiếu productId, không object graph`

---

### Task 4: customer-service (Mức A phẳng) — schema `customer`, dòng 341–560

**Files:**
- Create: `services/customer-service/src/main/java/io/bankplatform/customer/domain/model/{Customer,CustomerType,CustomerStatus,RiskRating,IndividualDetails,Gender,MaritalStatus,OrganizationDetails,CustomerIdentification,IdentificationType,CustomerAddress,AddressType,CustomerContact,ContactType,KycVerification,KycStatus,KycMethod,KycDocument,CustomerRiskAssessment}.java`
- Create: `services/customer-service/src/main/java/io/bankplatform/customer/domain/port/{CustomerRepository,KycVerificationRepository,CustomerRiskAssessmentRepository}.java`
- Create: `services/customer-service/src/test/java/io/bankplatform/customer/AbstractIntegrationTest.java` (`SCHEMA_NAME = "customer"`)
- Create: `services/customer-service/src/test/java/io/bankplatform/customer/CustomerPersistenceMappingTest.java`
- Modify: `services/customer-service/src/test/java/io/bankplatform/customer/web/ServiceInfoApiTest.java`
- Modify: `services/customer-service/README.md` (L2 hướng thực dụng + bỏ `outbox`)

**Interfaces (produces):**
- `CustomerRepository extends JpaRepository<Customer, Long>, JpaSpecificationExecutor<Customer>` + `Optional<Customer> findByCustomerNumber(String customerNumber)`
- `KycVerificationRepository extends JpaRepository<KycVerification, Long>` + `List<KycVerification> findByCustomerIdOrderBySubmittedAtDesc(Long customerId)`
- `CustomerRiskAssessmentRepository extends JpaRepository<CustomerRiskAssessment, Long>` + `List<CustomerRiskAssessment> findByCustomerIdOrderByAssessedAtDesc(Long customerId)`

Hai aggregate (đúng spec §5): **Customer** = customers + individual/organization_details + identifications + addresses + contacts; **KycVerification** = kyc_verifications + kyc_documents. `CustomerRiskAssessment` là bản ghi append-only độc lập (L9, repo riêng, không setter).

Điểm gai:
- Root `Customer extends AggregateRoot<Long>`; entity con extends `Entity<Long>` (riêng detail: id là customerId).
- Details dùng derived id (`customer_type` KHÔNG map — L4):

```java
@Entity
@Table(name = "individual_details")
public class IndividualDetails extends io.javalibs.ddd.Entity<Long> {
    @Id
    @Column(name = "customer_id")
    private Long customerId;

    @MapsId
    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "customer_id")
    private Customer customer;
    // ... các cột còn lại theo schema dòng 382–398
    @Override public Long getId() { return customerId; }
}
```

- Customer: `@OneToOne(mappedBy = "customer", cascade = ALL, fetch = LAZY)` cho từng detail (chỉ một trong hai non-null — bất biến app giữ, kiểm ở phase nghiệp vụ); `@OneToMany(mappedBy = "customer", cascade = {PERSIST, MERGE})` cho identifications/addresses/contacts — **không orphanRemoval** (identifications là bằng chứng tuân thủ — comment schema dòng 414; addresses/contacts là dữ liệu có lịch sử: đóng bằng `valid_to`/thay `is_primary`, không xoá).
- Con của Customer mang `@ManyToOne(fetch = LAZY) @JoinColumn(name = "customer_id") Customer customer`.
- KycVerification: `decided_by`/`customer_id` là `Long` (KHÔNG association sang Customer — khác aggregate); `@OneToMany documents cascade = PERSIST` + `KycDocument.kycVerification` `@ManyToOne LAZY`; `level SMALLINT` → `short`.
- `customers.kyc_level SMALLINT` → `short`; `risk_rating` nullable enum.
- `customer_risk_assessments.reason JSONB` nullable.
- UNIQUE cần né trong test: `uq_ident (id_type, id_number)`, `uq_address_current (customer_id, address_type) WHERE valid_to IS NULL`, `uq_contact`.

- [ ] **Bước 1:** Đọc schema.sql dòng 341–560 + Quy ước chung
- [ ] **Bước 2:** `AbstractIntegrationTest` + đổi `ServiceInfoApiTest`
- [ ] **Bước 3:** Viết `CustomerPersistenceMappingTest` (RED). Round-trip: (a) Customer INDIVIDUAL + IndividualDetails + 1 identification NATIONAL_ID + 1 address PERMANENT (validFrom hôm nay, validTo null) + 1 contact EMAIL → save root, flush, clear → `findByCustomerNumber` assert graph đủ (details.firstName, 1 identification, 1 address isPrimary, 1 contact) + createdAt/updatedAt not null; (b) Customer ORGANIZATION + OrganizationDetails (taxCode duy nhất) → assert legalName; (c) KycVerification level 2 MANUAL + 1 KycDocument → save, clear → `findByCustomerIdOrderBySubmittedAtDesc` assert status PENDING + document checksum + submittedAt not null; (d) CustomerRiskAssessment reason JSONB `{"nguon":"test"}` → assert rating + assessedAt not null
- [ ] **Bước 4:** Chạy test → FAIL
- [ ] **Bước 5:** Viết entity/enum/port theo schema + quy ước
- [ ] **Bước 6:** Chạy → PASS
- [ ] **Bước 7:** README (L2, ranh giới 2 aggregate, lý do không orphanRemoval, bỏ outbox)
- [ ] **Bước 8:** Commit: `feat(customer): aggregate Customer + KycVerification map JPA thực dụng theo doc javalibs`

---

### Task 5: core-banking-service (Mức A theo aggregate) — schema `core_banking`, dòng 792–1459 (+ seed GL 1468–1490)

**Files:**
- Create trong `services/core-banking-service/src/main/java/io/bankplatform/corebanking/`:
  - `domain/account/model/{Account,AccountStatus,AccountHolder,AccountHolderId,HolderRole,AccountHold,HoldReason,HoldStatus}.java`
  - `domain/account/{AccountRepository,AccountHoldRepository}.java`
  - `domain/ledger/model/{GlAccount,GlAccountClass,NormalBalance,GlAccountStatus,JournalEntry,TransactionType,JournalLine,LedgerDirection,AccountBalanceSnapshot,AccountBalanceSnapshotId,InterestAccrual,FeeCharge,FeeChargeStatus}.java`
  - `domain/ledger/{GlAccountRepository,JournalEntryRepository,JournalLineRepository,AccountBalanceSnapshotRepository,InterestAccrualRepository,FeeChargeRepository}.java`
  - `domain/transfer/model/{Transfer,TransferType,TransferStatus,TransferChannel,ExternalTransfer,SagaState,TransferLimitUsage}.java`
  - `domain/transfer/{TransferRepository,ExternalTransferRepository,TransferLimitUsageRepository}.java`
  - `domain/shared/{AuditLog,AuditLogRepository}.java`
- Create: `services/core-banking-service/src/test/java/io/bankplatform/corebanking/AbstractIntegrationTest.java` (`SCHEMA_NAME = "core_banking"`)
- Create: `services/core-banking-service/src/test/java/io/bankplatform/corebanking/CoreBankingPersistenceMappingTest.java`
- Modify: `services/core-banking-service/src/test/java/io/bankplatform/corebanking/web/ServiceInfoApiTest.java`
- Modify: `services/core-banking-service/README.md` (L2, L3, L4, bỏ `outbox`+`processed_events`)

**Interfaces (produces):**
- `AccountRepository extends JpaRepository<Account, Long>, JpaSpecificationExecutor<Account>` + `Optional<Account> findByAccountNumber(String accountNumber)`
- `AccountHoldRepository extends JpaRepository<AccountHold, Long>` + `List<AccountHold> findByAccountIdAndStatus(Long accountId, HoldStatus status)`
- `GlAccountRepository extends JpaRepository<GlAccount, Long>` + `Optional<GlAccount> findByGlCode(String glCode)`
- `JournalEntryRepository extends JpaRepository<JournalEntry, Long>` + `Optional<JournalEntry> findByEntryReference(String entryReference)`
- `JournalLineRepository extends JpaRepository<JournalLine, Long>` + `List<JournalLine> findByJournalEntryIdOrderByLineNo(Long journalEntryId)` (đọc; ghi đi qua cascade từ JournalEntry)
- `AccountBalanceSnapshotRepository extends JpaRepository<AccountBalanceSnapshot, AccountBalanceSnapshotId>`
- `InterestAccrualRepository extends JpaRepository<InterestAccrual, Long>` + `Optional<InterestAccrual> findByAccountIdAndAccrualDate(Long accountId, LocalDate accrualDate)`
- `FeeChargeRepository extends JpaRepository<FeeCharge, Long>` + `List<FeeCharge> findByAccountIdOrderByChargedAtDesc(Long accountId)`
- `TransferRepository extends JpaRepository<Transfer, Long>, JpaSpecificationExecutor<Transfer>` + `Optional<Transfer> findByTransferReference(String ref)` + `Optional<Transfer> findByIdempotencyKey(String key)`
- `ExternalTransferRepository extends JpaRepository<ExternalTransfer, Long>` + `Optional<ExternalTransfer> findByTransferId(Long transferId)`
- `TransferLimitUsageRepository extends JpaRepository<TransferLimitUsage, Long>` + `Optional<TransferLimitUsage> findByAccountIdAndLimitCodeAndWindowStart(Long accountId, String limitCode, LocalDate windowStart)`
- `AuditLogRepository extends JpaRepository<AuditLog, Long>`

Điểm gai (đọc kỹ comment schema từng bảng — chúng là đặc tả):
- **Account**: `available_balance` GENERATED STORED → `@Generated(event = {INSERT, UPDATE}) @Column(insertable = false, updatable = false)`; `version` → `@Version int`; `gl_code` là `String` (FK sang gl_accounts nhưng GL là aggregate khác); `product_code`/`primary_customer_id` tham chiếu mềm → String/Long; `opened_at`/`closed_at` app đặt; `status` mặc định PENDING đặt trong constructor.
- **AccountHolder**: PK (account_id, customer_id) → `@EmbeddedId AccountHolderId` + `@MapsId("accountId") @ManyToOne(fetch = LAZY) Account account`; Account có `@OneToMany(mappedBy = "account", cascade = ALL, orphanRemoval = true) Set<AccountHolder>` (holder là dòng quan hệ thuần của aggregate, xoá holder JOINT là nghiệp vụ hợp lệ); `added_at` DB giữ.
- **AccountHold**: entity độc lập trong aggregate account (job quét hold không load Account); `account_id` → `Long`; `placed_at` DB giữ; `expires_at`/`released_at` app đặt.
- **GlAccount**: `parent_gl_code String` (không self-association — duyệt cây là việc của SQL `WITH RECURSIVE`, comment dòng 830–838).
- **JournalEntry + JournalLine** (L3, L4): append-only tuyệt đối — không setter; `JournalEntry.lines` `@OneToMany(mappedBy = "journalEntry", cascade = PERSIST)`; `JournalLine.journalEntry` `@ManyToOne(fetch = LAZY, optional = false)`; `JournalLine.id` `@Id @GeneratedValue(IDENTITY)` đơn; `created_at` DB giữ (routing partition dựa vào DEFAULT now()); KHÔNG map `created_txid`; `balance_after` nullable app đặt; `account_id` `Long` nullable (NULL = dòng chỉ chạm GL — quyết định DB3); `reversal_of_entry_id` → `Long` (không self-association); `value_date`/`booking_date` app đặt (constructor bắt buộc), `posted_at` DB giữ.
- **Transfer**: `@Version`; hai nhánh CHECK `ck_transfers_target` — constructor tĩnh gợi ý `Transfer.internal(...)`/`Transfer.external(...)` để không tạo được dữ liệu vi phạm; `journal_entry_id` `Long` nullable; `completed_at` app đặt; `updated_at` DB giữ (trigger).
- **ExternalTransfer**: `transfer_id Long` UNIQUE; `saga_state` enum 6 giá trị (dòng 1335–1341); `deadline_at` app đặt NOT NULL.
- **AccountBalanceSnapshot**: `@EmbeddedId AccountBalanceSnapshotId(accountId, asOfDate)`; append-only.
- **InterestAccrual/FeeCharge**: setter chỉ cho (`posted`, `journalEntryId`) / (`status`, `journalEntryId`) — chuyển trạng thái hạch toán; còn lại bất biến.
- **AuditLog**: append-only, `detail` JSONB nullable, `at` → `occurredAt` DB giữ.

- [ ] **Bước 1:** Đọc schema.sql dòng 792–1490 + Quy ước chung (các khối comment DB1–DB4, trigger — bắt buộc đọc hết)
- [ ] **Bước 2:** `AbstractIntegrationTest` + đổi `ServiceInfoApiTest`
- [ ] **Bước 3:** Viết `CoreBankingPersistenceMappingTest` (RED — `@Transactional`, rollback nên trigger DEFERRED không chạy, L10). Round-trip:
  - (a) `GlAccountRepository.findByGlCode("2010")` đọc seed → assert class LIABILITY, normalBalance CREDIT;
  - (b) Account glCode "2010", ledger 500000, hold 200000 → saveAndFlush → assert `availableBalance` = 300000 (Hibernate đọc lại cột GENERATED) + version 0 + createdAt not null; đổi ledger → saveAndFlush → assert version tăng;
  - (c) thêm AccountHolder PRIMARY vào account, save qua root, clear → đọc lại assert holder role + addedAt not null;
  - (d) AccountHold TRANSFER amount 100000 expiresAt +1h → round-trip `findByAccountIdAndStatus(..., ACTIVE)`;
  - (e) JournalEntry TRANSFER valueDate/bookingDate hôm nay + 2 line cân (DEBIT 2010 accountId, CREDIT 4010 accountId null) → saveAndFlush → clear → `findByEntryReference` assert 2 line đúng thứ tự lineNo, line.createdAt not null, line.id not null;
  - (f) Transfer.internal(...) idempotencyKey duy nhất → round-trip `findByIdempotencyKey` + assert status PENDING, version 0; ExternalTransfer cho một transfer EXTERNAL → round-trip saga HOLD_PLACED;
  - (g) AccountBalanceSnapshot composite id hôm nay → `findById(new AccountBalanceSnapshotId(accId, today))`;
  - (h) InterestAccrual accrualDate hôm nay → round-trip finder; FeeCharge PENDING → round-trip; TransferLimitUsage windowStart hôm nay → round-trip `findByAccountIdAndLimitCodeAndWindowStart`; AuditLog detail JSONB → assert occurredAt not null
- [ ] **Bước 4:** Chạy `mvn -B -P'!with-libs' -pl services/core-banking-service -am test` → FAIL
- [ ] **Bước 5:** Viết 13 entity + enum + 11 repository theo schema + quy ước (root: Account, GlAccount, JournalEntry, Transfer extends `AggregateRoot<Long>`; ExternalTransfer/AccountHold/InterestAccrual/FeeCharge/AuditLog/TransferLimitUsage/AccountBalanceSnapshot extends `Entity<Long>` hoặc POJO khi id composite; JournalLine/AccountHolder extends `Entity<Long>`-style tùy id)
- [ ] **Bước 6:** Chạy → PASS (kể cả ServiceInfoApiTest)
- [ ] **Bước 7:** README (L2, L3, L4, ranh giới aggregate account/ledger/transfer/shared, bỏ outbox + processed_events)
- [ ] **Bước 8:** Commit: `feat(core-banking): entity + repository sổ cái kép, tài khoản, chuyển tiền — JournalLine map @Id đơn vì PK partition`

---

### Task 6: Tài liệu + kiểm toàn bộ

**Files:**
- Modify: `docs/KNOWN-LIMITATIONS.md` (dòng ~21: entity/repository đã xong — thu hẹp mục "mọi code nghiệp vụ" còn controller/service/DTO/mapper; thêm mục: outbox/processed_events chưa map — chờ phán quyết datahub; Flyway vẫn tắt theo D5)
- Modify: `docs/superpowers/plans/2026-08-09-entity-repository-all-services.md` (tick checkbox, ghi chú lệch nếu có)

- [ ] **Bước 1:** Cập nhật `docs/KNOWN-LIMITATIONS.md` đúng thực tế sau 5 task
- [ ] **Bước 2:** Chạy từ root: `export JAVA_HOME=$(/usr/libexec/java_home -v 21) && mvn -B -P'!with-libs' clean verify` → toàn reactor xanh
- [ ] **Bước 3:** Soát ledger L1–L10: mỗi quyết định đã được phản ánh trong code/README chưa
- [ ] **Bước 4:** Commit: `docs: cập nhật KNOWN-LIMITATIONS sau khi phủ entity + repository 5 service`

## Ghi chú cho reviewer

- Phép kiểm mạnh nhất là **context khởi động được** với `ddl-auto: validate` trên schema thật — mọi cột map sai kiểu/tên sẽ chết ngay lúc boot.
- Repo này săn "comment mô tả sai cơ chế": mọi câu *vì sao* trong Javadoc phải khớp schema.sql/tài liệu javalibs. Reviewer đối chiếu từng câu.
- Đối chiếu danh sách enum với CHECK constraint **từng giá trị** — lệch một giá trị là bug nằm chờ.
