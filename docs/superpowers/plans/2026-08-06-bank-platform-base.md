# bank-platform Base Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dựng monorepo Maven multi-module cho bank-platform — javalibs nhúng nguyên vẹn, `bank-common`, 5 service nghiệp vụ + gateway với cấu trúc package rỗng, và một file SQL tổng hợp 42 bảng trên 5 schema.

**Architecture:** Một reactor Maven duy nhất: root POM vừa aggregate vừa làm parent cho các service; `platform-libs` (javalibs) nằm trong `<modules>` nhưng **không** khai root làm `<parent>` nên giữ nguyên 100%. Database là một file `docs/database/schema.sql` tự đủ, được mount thẳng vào `docker-entrypoint-initdb.d` của Postgres. Không có code nghiệp vụ, không có test, không có Flyway migration.

**Tech Stack:** Java 21 · Spring Boot 4.1.0 · Maven · PostgreSQL 17 · Kafka (KRaft) · Redis 7 · Docker Compose · io.javalibs 2.0.0-SNAPSHOT

**Spec:** [docs/superpowers/specs/2026-08-06-bank-platform-base-design.md](../specs/2026-08-06-bank-platform-base-design.md)

## Global Constraints

Mọi task đều phải tuân thủ, không nhắc lại trong từng task:

- **Thư mục gốc:** `/Users/tanvx/Dev/bank-platform`. Git repo đã init, branch `master`, đã có 1 commit.
- **Maven coordinates:** `groupId io.bankplatform`, `version 0.1.0-SNAPSHOT`, package gốc `io.bankplatform.*`.
- **javalibs:** `groupId io.javalibs`, `version 2.0.0-SNAPSHOT`, BOM `javalibs-dependencies`. **Không sửa một dòng nào trong `platform-libs/`.**
- **Java 21** (`java.version`, `maven.compiler.release`). Spring Boot **4.1.0**.
- **Không viết file `.java` nào ngoài 6 main class** (`GatewayApplication`, `AuthApplication`, `CustomerApplication`, `ProductApplication`, `CoreBankingApplication`, `NotificationApplication`). Không entity, không repository, không controller, không service, không DTO, không test.
- **Thư mục rỗng giữ bằng file `.gitkeep` rỗng.**
- **Tiền tệ luôn `NUMERIC(19,4)`**, tiền tệ `CHAR(3)`, thời điểm `TIMESTAMPTZ`, ngày nghiệp vụ `DATE`.
- **Mọi CHECK constraint đặt tên tường minh** dạng `ck_<bảng>_<ý nghĩa>`; mọi UNIQUE constraint đặt tên `uq_<...>`.
- **Không FK xuyên schema.** Cột trỏ sang schema khác là cột thường + `COMMENT ON COLUMN` ghi rõ "tham chiếu MỀM".
- **Comment SQL viết bằng tiếng Việt**, giải thích *vì sao* chứ không mô tả lại cột.
- **Mật khẩu DB dev** cố định: `auth_svc/auth_dev`, `customer_svc/customer_dev`, `product_svc/product_dev`, `core_svc/core_dev`, `noti_svc/noti_dev`; superuser `postgres/postgres`, database `bank`.
- **Cổng service:** gateway 8080, auth 8081, customer 8082, product 8083, core-banking 8084, notification 8085.

### Lệnh dùng lại nhiều lần

Reset database từ đầu (bắt buộc mỗi lần đổi `schema.sql` — initdb chỉ chạy khi data directory rỗng):

```bash
cd /Users/tanvx/Dev/bank-platform && docker compose down -v && docker compose up -d postgres && sleep 8
```

Chạy SQL kiểm tra:

```bash
docker compose exec -T postgres psql -U postgres -d bank -tAc "SELECT 1"
```

Xem log lỗi initdb (nếu container không healthy):

```bash
docker compose logs postgres | tail -40
```

## File Structure

| Đường dẫn | Trách nhiệm |
|---|---|
| `pom.xml` | Aggregator + parent cho service. Chốt Java 21, import BOM javalibs, khai `bank-common` trong dependencyManagement. |
| `platform-libs/` | javalibs nguyên vẹn. Chỉ được copy vào, không sửa. |
| `bank-common/` | Value object nghiệp vụ + hợp đồng event + hằng số. Package rỗng. |
| `services/<name>-service/` | Một service = một module. pom + main class + package rỗng + yml + Dockerfile + README + ERROR-CODES.md. |
| `docs/database/schema.sql` | **Nguồn sự thật duy nhất của DB.** Tự đủ: schema, user, grant, DDL, seed. Được mount vào initdb. |
| `docs/legacy/` | 6 file SQL cũ + README giải thích cái gì đã đổi. |
| `compose.yaml` | Postgres + Kafka + Redis cho dev local. |
| `.github/workflows/ci.yml` | Build + verify mọi push/PR. |

`schema.sql` được xây dần qua Task 2→10, mỗi task **append** một khối vào cuối file (trước khối seed). Thứ tự khối là bắt buộc vì FK nội schema phụ thuộc thứ tự tạo bảng.

---

### Task 1: Nhúng javalibs thành `platform-libs` và dựng root POM

**Files:**
- Create: `platform-libs/` (copy từ `/Users/tanvx/Dev/javalibs-4.1`)
- Create: `pom.xml`

**Interfaces:**
- Consumes: không
- Produces: reactor Maven gốc `io.bankplatform:bank-platform:0.1.0-SNAPSHOT` (packaging `pom`, parent `spring-boot-starter-parent:4.1.0`); artifact `io.javalibs:*:2.0.0-SNAPSHOT` có trong local repo; property `${javalibs.version}` = `2.0.0-SNAPSHOT`; profile `with-libs` (activeByDefault) chứa module `platform-libs`.

- [ ] **Step 1: Kiểm tra trạng thái xuất phát — build phải thất bại vì chưa có POM**

```bash
cd /Users/tanvx/Dev/bank-platform && mvn -B -q clean install
```

Expected: FAIL — `The goal you specified requires a project to execute but there is no POM in this directory`.

- [ ] **Step 2: Copy javalibs source vào `platform-libs/`**

```bash
cd /Users/tanvx/Dev/bank-platform
rsync -a --exclude '.git' --exclude '.github' --exclude '.idea' --exclude 'target' \
      /Users/tanvx/Dev/javalibs-4.1/ platform-libs/
```

Loại `.git` (repo con sẽ làm git gốc bối rối), `.github` (GitHub chỉ đọc workflow ở gốc repo, để lại chỉ gây nhầm), `.idea` và `target` (rác build/IDE). Toàn bộ `pom.xml` và source Java giữ nguyên tuyệt đối.

- [ ] **Step 3: Xác nhận javalibs còn nguyên vẹn**

```bash
cd /Users/tanvx/Dev/bank-platform
diff -r --exclude='.git' --exclude='.github' --exclude='.idea' --exclude='target' \
     /Users/tanvx/Dev/javalibs-4.1 platform-libs && echo "NGUYÊN VẸN"
```

Expected: in ra `NGUYÊN VẸN`, không có dòng diff nào.

- [ ] **Step 4: Viết root `pom.xml`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>4.1.0</version>
    <relativePath/>
  </parent>

  <groupId>io.bankplatform</groupId>
  <artifactId>bank-platform</artifactId>
  <version>0.1.0-SNAPSHOT</version>
  <packaging>pom</packaging>

  <name>bank-platform</name>
  <description>Monorepo core banking: platform-libs (javalibs), bank-common, 5 service nghiệp vụ + gateway.</description>

  <properties>
    <java.version>21</java.version>
    <maven.compiler.release>${java.version}</maven.compiler.release>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    <javalibs.version>2.0.0-SNAPSHOT</javalibs.version>
  </properties>

  <!--
    modules gốc CỐ Ý không chứa platform-libs: xem profile with-libs bên dưới.
    Danh sách này lớn dần qua từng task; hiện chưa có module nào.
  -->
  <modules>
  </modules>

  <dependencyManagement>
    <dependencies>
      <dependency>
        <groupId>io.javalibs</groupId>
        <artifactId>javalibs-dependencies</artifactId>
        <version>${javalibs.version}</version>
        <type>pom</type>
        <scope>import</scope>
      </dependency>
      <dependency>
        <groupId>io.bankplatform</groupId>
        <artifactId>bank-common</artifactId>
        <version>${project.version}</version>
      </dependency>
    </dependencies>
  </dependencyManagement>

  <profiles>
    <!--
      platform-libs là javalibs nguyên vẹn: nó KHÔNG khai POM này làm <parent>
      (javalibs-root tự là root và quyết định D2 cấm sửa nó). Maven cho phép
      điều đó: <modules> quyết định thứ tự build, <parent> quyết định kế thừa —
      hai chuyện độc lập.

      Vì sao là profile "thêm vào" chứ không phải profile "bỏ ra": Maven chỉ
      cho profile THÊM module, không cho BỚT. Muốn build nhanh sau khi javalibs
      đã nằm trong local repo:  mvn -P'!with-libs' clean install
    -->
    <profile>
      <id>with-libs</id>
      <activation>
        <activeByDefault>true</activeByDefault>
      </activation>
      <modules>
        <module>platform-libs</module>
      </modules>
    </profile>
  </profiles>
</project>
```

- [ ] **Step 5: Build và xác nhận javalibs vào được local repo**

```bash
cd /Users/tanvx/Dev/bank-platform && mvn -B clean install -DskipTests
```

Expected: `BUILD SUCCESS`, reactor summary liệt kê `javalibs-root` và các module con.

```bash
ls ~/.m2/repository/io/javalibs/javalibs-dependencies/2.0.0-SNAPSHOT/*.pom
```

Expected: có file `.pom`.

- [ ] **Step 6: Xác nhận profile tắt được**

```bash
cd /Users/tanvx/Dev/bank-platform && mvn -B -P'!with-libs' clean install -DskipTests
```

Expected: `BUILD SUCCESS`, reactor chỉ còn `bank-platform` — không có module javalibs nào.

- [ ] **Step 7: Commit**

```bash
cd /Users/tanvx/Dev/bank-platform
git add pom.xml platform-libs
git commit -m "feat: nhúng javalibs thành platform-libs và dựng root POM

platform-libs là bản copy nguyên vẹn của javalibs-4.1 (trừ .git/.github/
.idea/target). Nó nằm trong reactor qua profile with-libs nhưng không kế
thừa root POM — javalibs-root tự là root.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: Docker Compose và khung `schema.sql` (schema, user, quyền)

**Files:**
- Create: `compose.yaml`
- Create: `docs/database/schema.sql`

**Interfaces:**
- Consumes: không
- Produces: Postgres 17 tại `localhost:5432`, database `bank`, superuser `postgres/postgres`; 5 schema `auth`, `customer`, `product`, `core_banking`, `notification`; 5 role `auth_svc`, `customer_svc`, `product_svc`, `core_svc`, `noti_svc`; Kafka tại `localhost:9092`; Redis tại `localhost:6379`. File `schema.sql` kết thúc bằng dòng đánh dấu `-- <<< HẾT KHỐI [1]` để các task sau biết chỗ append.

- [ ] **Step 1: Viết `compose.yaml`**

```yaml
# Hạ tầng dev local. schema.sql được mount THẲNG từ docs/ — không có bản sao
# trong docker/, nên không có chuyện hai bản lệch nhau.
#
# LƯU Ý: script trong docker-entrypoint-initdb.d chỉ chạy khi data directory
# còn rỗng. Sửa schema.sql xong phải: docker compose down -v && docker compose up -d
services:
  postgres:
    image: postgres:17-alpine
    container_name: bank-postgres
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: bank
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./docs/database/schema.sql:/docker-entrypoint-initdb.d/01-schema.sql:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d bank"]
      interval: 5s
      timeout: 5s
      retries: 12

  kafka:
    image: apache/kafka:3.9.0
    container_name: bank-kafka
    ports:
      - "9092:9092"
    environment:
      KAFKA_NODE_ID: 1
      KAFKA_PROCESS_ROLES: broker,controller
      KAFKA_LISTENERS: PLAINTEXT://:9092,CONTROLLER://:9093
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@localhost:9093
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1
      KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS: 0

  redis:
    image: redis:7-alpine
    container_name: bank-redis
    ports:
      - "6379:6379"

volumes:
  pgdata:
```

- [ ] **Step 2: Chạy compose và xác nhận CHƯA có schema nào**

```bash
cd /Users/tanvx/Dev/bank-platform && docker compose up -d postgres && sleep 8
docker compose exec -T postgres psql -U postgres -d bank -tAc \
  "SELECT count(*) FROM information_schema.schemata WHERE schema_name IN ('auth','customer','product','core_banking','notification')"
```

Expected: `0` — hoặc container không khởi động được vì `schema.sql` chưa tồn tại (mount một file không có → Docker tạo thư mục). Cả hai đều là thất bại mong đợi; Step 3 sửa.

- [ ] **Step 3: Viết `docs/database/schema.sql` — khối [0] và [1]**

```sql
-- =====================================================================
--  bank-platform — SCHEMA TỔNG HỢP
--  Nguồn sự thật DUY NHẤT của database. Không có bản sao ở nơi khác.
--
--  Chạy: compose.yaml mount file này vào /docker-entrypoint-initdb.d/,
--        Postgres tự chạy MỘT LẦN khi data directory còn rỗng.
--  Chạy lại sau khi sửa:  docker compose down -v && docker compose up -d
--
--  Thư mục db/migration/ của các service đang RỖNG. Khi bắt tay vào một
--  service, cắt phần schema của nó từ file này thành migration Flyway đầu
--  tiên rồi bật spring.flyway.enabled.
-- =====================================================================
--
--  NGUYÊN TẮC THIẾT KẾ
--
--  1. KHÔNG FK XUYÊN SCHEMA. Cột trỏ sang schema khác là cột thường + index;
--     toàn vẹn do ứng dụng/saga đảm bảo. Mỗi service chỉ thấy schema của mình,
--     nên một FK xuyên schema là một ràng buộc mà service kia không biết nó tồn tại.
--
--  2. TIỀN TỆ LUÔN NUMERIC(19,4), KHÔNG BAO GIỜ float. Bốn chữ số thập phân để
--     dự thu lãi hằng ngày không mất số lẻ. currency CHAR(3) theo ISO-4217.
--
--  3. MỘT TÀI KHOẢN MỘT LOẠI TIỀN, MỘT BÚT TOÁN CÁC DÒNG CÙNG LOẠI TIỀN.
--     Không có FX trong phạm vi này — trigger cân đối sẽ từ chối bút toán trộn tiền.
--
--  4. TIMESTAMPTZ CHO THỜI ĐIỂM, DATE CHO NGÀY NGHIỆP VỤ. value_date quyết định
--     lãi, booking_date quyết định kỳ sổ — hai thứ khác nhau, đừng trộn.
--
--  5. SỔ CÁI APPEND-ONLY. journal_entries/journal_lines không UPDATE, không DELETE.
--     Sai thì ghi bút toán đảo trỏ về bản gốc (reversal_of_entry_id).
--
--  6. MỌI CHECK CONSTRAINT ĐẶT TÊN TƯỜNG MINH ck_<bảng>_<ý nghĩa>. Bài học từ
--     bản cũ: CHECK inline được Postgres tự đặt tên 'transfers_status_check',
--     đến lúc cần ALTER mới phát hiện mình không biết nó tên gì.
--
--  7. PARTIAL INDEX CHO BẢNG HÀNG ĐỢI: outbox chưa publish, hold còn ACTIVE,
--     notification PENDING. Bảng lớn dần nhưng phần đang quét thì không.
--
--  8. IDEMPOTENCY KEY UNIQUE trên mọi lệnh làm dịch chuyển tiền.
--
--  9. DỮ LIỆU CÓ HIỆU LỰC THEO THỜI GIAN THÌ THÊM DÒNG, KHÔNG SỬA DÒNG
--     (biểu phí, lãi suất, địa chỉ). Sửa tại chỗ làm sao kê kỳ cũ tính lại ra số khác.
--
-- ---------------------------------------------------------------------
--  BỐN QUYẾT ĐỊNH THIẾT KẾ LỚN
--
--  DB1. Sổ cái là BÚT TOÁN KÉP thật: journal_entries (header) + journal_lines
--       (các dòng Nợ/Có), thay cho bảng ledger_entries phẳng của bản cũ. Bảng
--       phẳng không có phía đối ứng, không có GL, và không diễn tả nổi một
--       giao dịch ba dòng (trừ người gửi 100, cộng người nhận 98, thu phí 2).
--
--  DB2. Ràng buộc "tổng Nợ = tổng Có" là ràng buộc LIÊN HÀNG — không CHECK nào
--       biểu diễn được. Dùng CONSTRAINT TRIGGER DEFERRABLE INITIALLY DEFERRED
--       trên journal_entries, kiểm tại COMMIT (lúc đó các dòng đã insert xong).
--       Đặt trên bảng thường chứ không trên bảng partition để né giới hạn của
--       Postgres với trigger trên bảng partition.
--
--  DB3. KHÔNG có tài khoản 'SYSTEM' trong bảng accounts. journal_lines.gl_code
--       luôn NOT NULL; journal_lines.account_id NULL nghĩa là dòng đó chỉ chạm
--       GL nội bộ (tiền mặt, clearing, thu nhập phí). Đúng cách core banking
--       thật hoạt động: accounts là sổ phụ của khách hàng, gl_accounts là sổ cái.
--
--  DB4. SỐ DƯ LƯU SẴN, không tính lại từ ledger. accounts.ledger_balance và
--       hold_amount là cột thật, cập nhật cùng transaction với bút toán;
--       available_balance là cột GENERATED. Tính lại từ hàng triệu dòng mỗi lần
--       đọc là không khả thi. Lưới an toàn là account_balance_snapshots + job đối chiếu.
-- =====================================================================


-- ---------------------------------------------------------------------
-- [1] SCHEMA, ROLE, QUYỀN
--     Ranh giới service dựng từ ngày đầu: mỗi service một schema, một DB user,
--     và search_path khóa vào đúng schema của mình nên không "đi lạc" được.
-- ---------------------------------------------------------------------

CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS customer;
CREATE SCHEMA IF NOT EXISTS product;
CREATE SCHEMA IF NOT EXISTS core_banking;
CREATE SCHEMA IF NOT EXISTS notification;

-- Mật khẩu dev. Lên K8s thì bơm qua Secret, không dùng lại các giá trị này.
CREATE USER auth_svc     WITH PASSWORD 'auth_dev';
CREATE USER customer_svc WITH PASSWORD 'customer_dev';
CREATE USER product_svc  WITH PASSWORD 'product_dev';
CREATE USER core_svc     WITH PASSWORD 'core_dev';
CREATE USER noti_svc     WITH PASSWORD 'noti_dev';

-- ALL gồm cả CREATE: Flyway cần tạo bảng lịch sử khi service bật migration.
GRANT ALL ON SCHEMA auth         TO auth_svc;
GRANT ALL ON SCHEMA customer     TO customer_svc;
GRANT ALL ON SCHEMA product      TO product_svc;
GRANT ALL ON SCHEMA core_banking TO core_svc;
GRANT ALL ON SCHEMA notification TO noti_svc;

ALTER USER auth_svc     SET search_path = auth;
ALTER USER customer_svc SET search_path = customer;
ALTER USER product_svc  SET search_path = product;
ALTER USER core_svc     SET search_path = core_banking;
ALTER USER noti_svc     SET search_path = notification;

-- Chặn quyền mặc định trên public để không ai tạo bảng "tạm" ngoài schema của mình.
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- <<< HẾT KHỐI [1]
```

- [ ] **Step 4: Reset DB và xác nhận 5 schema + 5 role**

```bash
cd /Users/tanvx/Dev/bank-platform && docker compose down -v && docker compose up -d postgres && sleep 8
docker compose exec -T postgres psql -U postgres -d bank -tAc \
  "SELECT count(*) FROM information_schema.schemata WHERE schema_name IN ('auth','customer','product','core_banking','notification')"
docker compose exec -T postgres psql -U postgres -d bank -tAc \
  "SELECT count(*) FROM pg_roles WHERE rolname IN ('auth_svc','customer_svc','product_svc','core_svc','noti_svc')"
```

Expected: `5` rồi `5`.

- [ ] **Step 5: Xác nhận Kafka và Redis lên được**

```bash
cd /Users/tanvx/Dev/bank-platform && docker compose up -d && sleep 15 && docker compose ps
```

Expected: cả `bank-postgres`, `bank-kafka`, `bank-redis` đều `running`; postgres `healthy`.

- [ ] **Step 6: Commit**

```bash
cd /Users/tanvx/Dev/bank-platform
git add compose.yaml docs/database/schema.sql
git commit -m "feat: docker compose và khung schema.sql

Postgres/Kafka/Redis cho dev local. schema.sql mount thẳng từ docs/ nên
không có bản sao nào để lệch. Khối [0] nguyên tắc thiết kế + [1] schema,
role, quyền cho 5 service.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: Schema `auth` — 4 bảng

**Files:**
- Modify: `docs/database/schema.sql` (append khối `[2]` sau dòng `-- <<< HẾT KHỐI [1]`)

**Interfaces:**
- Consumes: role `auth_svc` và schema `auth` từ Task 2
- Produces: `auth.users(id BIGSERIAL)` — mọi schema khác trỏ mềm vào cột này. `auth.user_roles`, `auth.refresh_tokens`, `auth.login_audit`.

- [ ] **Step 1: Xác nhận bảng chưa tồn tại**

```bash
cd /Users/tanvx/Dev/bank-platform
docker compose exec -T postgres psql -U postgres -d bank -tAc \
  "SELECT count(*) FROM information_schema.tables WHERE table_schema='auth'"
```

Expected: `0`.

- [ ] **Step 2: Append khối `[2]` vào `docs/database/schema.sql`**

```sql

-- ---------------------------------------------------------------------
-- [2] SCHEMA auth — CHỈ biết danh tính. Không biết gì về tài khoản ngân hàng.
--     Các schema khác trỏ VÀO auth.users; auth không trỏ ra ngoài.
-- ---------------------------------------------------------------------
SET ROLE auth_svc;
SET search_path = auth;

CREATE TABLE users (
    id            BIGSERIAL    PRIMARY KEY,
    username      VARCHAR(100) NOT NULL,
    password_hash VARCHAR(100) NOT NULL,
    status        VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE',
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_users_username UNIQUE (username),
    CONSTRAINT ck_users_status   CHECK (status IN ('ACTIVE', 'LOCKED', 'DISABLED'))
);
COMMENT ON COLUMN users.password_hash IS
    'BCrypt cho ra chuỗi 60 ký tự; để 100 phòng khi đổi sang argon2 (dài hơn)';

-- Bảng nối thay vì cột role: một người kiêm TELLER + ADMIN là chuyện bình thường.
CREATE TABLE user_roles (
    user_id BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    role    VARCHAR(20) NOT NULL,
    PRIMARY KEY (user_id, role),
    CONSTRAINT ck_user_roles_role CHECK (
        role IN ('CUSTOMER', 'TELLER', 'CSO', 'RISK_OFFICER', 'ADMIN', 'SYSTEM'))
);

-- Access token ngắn hạn stateless; khả năng THU HỒI đặt ở refresh token.
-- Khóa một user = revoke mọi refresh token của họ.
CREATE TABLE refresh_tokens (
    id         BIGSERIAL   PRIMARY KEY,
    user_id    BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    token_hash VARCHAR(64) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_refresh_tokens_hash UNIQUE (token_hash)
);
COMMENT ON COLUMN refresh_tokens.token_hash IS
    'Lưu HASH chứ không lưu token thô: lộ DB không đồng nghĩa lộ phiên đăng nhập';

-- Append-only. Cố ý KHÔNG FK sang users để giữ được cả lần đăng nhập
-- bằng username không tồn tại — đó chính là dữ liệu để phát hiện dò tài khoản.
CREATE TABLE login_audit (
    id         BIGSERIAL    PRIMARY KEY,
    username   VARCHAR(100) NOT NULL,
    user_id    BIGINT,
    success    BOOLEAN      NOT NULL,
    ip         INET,
    user_agent VARCHAR(500),
    at         TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_refresh_user   ON refresh_tokens (user_id);
CREATE INDEX idx_refresh_active ON refresh_tokens (expires_at) WHERE revoked_at IS NULL;
CREATE INDEX idx_login_user_at  ON login_audit (username, at DESC);

RESET ROLE;
SET search_path = public;

-- <<< HẾT KHỐI [2]
```

- [ ] **Step 3: Reset DB và đếm bảng**

```bash
cd /Users/tanvx/Dev/bank-platform && docker compose down -v && docker compose up -d postgres && sleep 8
docker compose exec -T postgres psql -U postgres -d bank -tAc \
  "SELECT count(*) FROM information_schema.tables WHERE table_schema='auth' AND table_type='BASE TABLE'"
```

Expected: `4`.

- [ ] **Step 4: Xác nhận bảng thuộc sở hữu `auth_svc`**

```bash
docker compose exec -T postgres psql -U postgres -d bank -tAc \
  "SELECT count(*) FROM pg_tables WHERE schemaname='auth' AND tableowner='auth_svc'"
```

Expected: `4`. Nếu ra `0` thì `SET ROLE` đã không có tác dụng — kiểm tra lại vị trí `SET ROLE auth_svc;` nằm TRƯỚC các `CREATE TABLE`.

- [ ] **Step 5: Commit**

```bash
cd /Users/tanvx/Dev/bank-platform
git add docs/database/schema.sql
git commit -m "feat(db): schema auth — users, roles, refresh tokens, login audit

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: Schema `notification` — 6 bảng

**Files:**
- Modify: `docs/database/schema.sql` (append khối `[6]` sau `-- <<< HẾT KHỐI [2]`)

**Interfaces:**
- Consumes: role `noti_svc` và schema `notification` từ Task 2
- Produces: `notification.processed_events(event_id VARCHAR(64) PK)` — khuôn idempotent consumer dùng lại ở `core_banking`. `notification.notifications`, `delivery_attempts`, `webhook_endpoints`, `notification_templates`, `user_notification_preferences`.

> Khối này đánh số `[6]` (không phải `[3]`) vì thứ tự khối trong file cuối cùng là `[2] auth · [3] customer · [4] product · [5] core_banking · [6] notification`. Task 4 append vào cuối file lúc này; Task 5–9 sẽ **chèn vào trước** nó. Để tránh phải chèn giữa file, thực hiện theo Step 2 bên dưới.

- [ ] **Step 1: Xác nhận bảng chưa tồn tại**

```bash
cd /Users/tanvx/Dev/bank-platform
docker compose exec -T postgres psql -U postgres -d bank -tAc \
  "SELECT count(*) FROM information_schema.tables WHERE table_schema='notification'"
```

Expected: `0`.

- [ ] **Step 2: Append khối `[6]` vào cuối `docs/database/schema.sql`**

Khối này ở cuối file là ĐÚNG và giữ nguyên như vậy đến hết plan: `notification` không có FK sang schema nào khác (mọi tham chiếu đều mềm), nên vị trí của nó trong file không ràng buộc gì. Task 5–9 sẽ append tiếp SAU khối này. Thứ tự vật lý trong file khác thứ tự đánh số — điều đó chấp nhận được vì mỗi khối tự đủ; ghi rõ trong comment để người đọc sau không bối rối.

```sql

-- ---------------------------------------------------------------------
-- [6] SCHEMA notification — service này CHỈ NGHE event.
--     Mọi dữ liệu cần thiết phải nằm trong payload của event (event-carried
--     state): consumer không gọi ngược lại hỏi thêm.
--
--     Ghi chú vị trí: khối này nằm trước [3][4][5] trong file. Không sao —
--     notification không FK sang schema nào nên thứ tự tạo không ràng buộc.
-- ---------------------------------------------------------------------
SET ROLE noti_svc;
SET search_path = notification;

-- Xương sống của idempotent consumer. "Không báo hai lần" là em ruột của
-- "không trừ tiền hai lần". INSERT vào bảng này phải nằm CÙNG transaction với
-- việc tạo notification; trùng event_id nghĩa là đã xử lý -> bỏ qua message.
-- Đây là chỗ at-least-once của Kafka được thuần hóa.
CREATE TABLE processed_events (
    event_id     VARCHAR(64) PRIMARY KEY,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Nội dung thông báo tách khỏi việc gửi: đổi câu chữ không cần deploy lại code.
-- version + active để sửa template mà vẫn tra được thông báo cũ đã gửi bằng bản nào.
CREATE TABLE notification_templates (
    id            BIGSERIAL    PRIMARY KEY,
    template_code VARCHAR(50)  NOT NULL,
    channel       VARCHAR(20)  NOT NULL,
    locale        VARCHAR(10)  NOT NULL DEFAULT 'vi-VN',
    subject       VARCHAR(200),
    body_template TEXT         NOT NULL,
    version       INT          NOT NULL DEFAULT 1,
    active        BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT ck_templates_channel CHECK (channel IN ('TELEGRAM', 'EMAIL', 'WEBHOOK')),
    CONSTRAINT uq_templates UNIQUE (template_code, channel, locale, version)
);

CREATE TABLE notifications (
    id            BIGSERIAL   PRIMARY KEY,
    user_id       BIGINT      NOT NULL,
    event_type    VARCHAR(50) NOT NULL,
    channel       VARCHAR(20) NOT NULL,
    template_code VARCHAR(50),
    payload       JSONB       NOT NULL,
    status        VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_notifications_channel CHECK (channel IN ('TELEGRAM', 'EMAIL', 'WEBHOOK')),
    CONSTRAINT ck_notifications_status  CHECK (status IN ('PENDING', 'SENT', 'FAILED'))
);
COMMENT ON COLUMN notifications.user_id IS
    'Tham chiếu MỀM sang auth.users — không FK xuyên schema';
COMMENT ON COLUMN notifications.payload IS
    'Mỗi loại thông báo một hình dạng dữ liệu — một trong số ít chỗ JSONB thực sự đúng';

-- Tách attempts khỏi notifications: một thông báo nhiều lần thử, và lịch sử
-- retry đọc được chính là nguyên liệu cho dashboard tỉ lệ fail theo kênh.
CREATE TABLE delivery_attempts (
    id              BIGSERIAL     PRIMARY KEY,
    notification_id BIGINT        NOT NULL REFERENCES notifications (id) ON DELETE CASCADE,
    attempt_no      INT           NOT NULL,
    status          VARCHAR(20)   NOT NULL,
    error           VARCHAR(1000),
    at              TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT ck_attempts_status CHECK (status IN ('SUCCESS', 'FAILED')),
    CONSTRAINT ck_attempts_no     CHECK (attempt_no > 0),
    CONSTRAINT uq_attempts UNIQUE (notification_id, attempt_no)
);

-- URL do người dùng nhập = bề mặt SSRF chính của service này.
-- secret dùng ký HMAC payload để endpoint nhận xác minh được nguồn.
CREATE TABLE webhook_endpoints (
    id              BIGSERIAL     PRIMARY KEY,
    user_id         BIGINT        NOT NULL,
    url             VARCHAR(2048) NOT NULL,
    secret          VARCHAR(64)   NOT NULL,
    active          BOOLEAN       NOT NULL DEFAULT TRUE,
    last_status     INT,
    last_checked_at TIMESTAMPTZ,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT uq_webhook UNIQUE (user_id, url)
);

-- Opt-out theo từng loại event và từng kênh. Vắng dòng = mặc định BẬT.
CREATE TABLE user_notification_preferences (
    user_id    BIGINT      NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    channel    VARCHAR(20) NOT NULL,
    enabled    BOOLEAN     NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, event_type, channel),
    CONSTRAINT ck_prefs_channel CHECK (channel IN ('TELEGRAM', 'EMAIL', 'WEBHOOK'))
);

CREATE INDEX idx_noti_user_at  ON notifications (user_id, created_at DESC);
CREATE INDEX idx_noti_pending  ON notifications (created_at) WHERE status = 'PENDING';
CREATE INDEX idx_attempts_noti ON delivery_attempts (notification_id);
CREATE INDEX idx_webhook_user  ON webhook_endpoints (user_id) WHERE active;

RESET ROLE;
SET search_path = public;

-- <<< HẾT KHỐI [6]
```

- [ ] **Step 3: Reset DB và đếm bảng**

```bash
cd /Users/tanvx/Dev/bank-platform && docker compose down -v && docker compose up -d postgres && sleep 8
docker compose exec -T postgres psql -U postgres -d bank -tAc \
  "SELECT count(*) FROM information_schema.tables WHERE table_schema='notification' AND table_type='BASE TABLE'"
docker compose exec -T postgres psql -U postgres -d bank -tAc \
  "SELECT count(*) FROM pg_tables WHERE schemaname='notification' AND tableowner='noti_svc'"
```

Expected: `6` rồi `6`.

- [ ] **Step 4: Xác nhận partial index chỉ bao PENDING**

```bash
docker compose exec -T postgres psql -U postgres -d bank -tAc \
  "SELECT indexdef FROM pg_indexes WHERE indexname='idx_noti_pending'"
```

Expected: chuỗi trả về chứa `WHERE (status::text = 'PENDING'::text)`.

- [ ] **Step 5: Commit**

```bash
cd /Users/tanvx/Dev/bank-platform
git add docs/database/schema.sql
git commit -m "feat(db): schema notification — 6 bảng

Giữ 4 bảng của bản cũ, thêm notification_templates (tách nội dung khỏi
việc gửi) và user_notification_preferences (opt-out theo event x kênh).

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: Schema `customer` — 10 bảng (CIF)

**Files:**
- Modify: `docs/database/schema.sql` (append khối `[3]` vào cuối file)

**Interfaces:**
- Consumes: role `customer_svc` và schema `customer` từ Task 2
- Produces: `customer.customers(id BIGSERIAL, customer_number VARCHAR(20) UNIQUE)` — `core_banking.accounts.primary_customer_id` và `account_holders.customer_id` trỏ mềm vào `customers.id`. Chín bảng còn lại: `individual_details`, `organization_details`, `customer_identifications`, `customer_addresses`, `customer_contacts`, `kyc_verifications`, `kyc_documents`, `customer_risk_assessments`, `outbox`.

- [ ] **Step 1: Xác nhận bảng chưa tồn tại**

```bash
cd /Users/tanvx/Dev/bank-platform
docker compose exec -T postgres psql -U postgres -d bank -tAc \
  "SELECT count(*) FROM information_schema.tables WHERE table_schema='customer'"
```

Expected: `0`.

- [ ] **Step 2: Append khối `[3]` vào cuối `docs/database/schema.sql`**

```sql

-- ---------------------------------------------------------------------
-- [3] SCHEMA customer — CIF (Customer Information File).
--     Khách hàng KHÁC tài khoản đăng nhập, và KHÁC tài khoản ngân hàng.
--     Ba khái niệm, ba schema.
-- ---------------------------------------------------------------------
SET ROLE customer_svc;
SET search_path = customer;

CREATE TABLE customers (
    id              BIGSERIAL   PRIMARY KEY,
    customer_number VARCHAR(20) NOT NULL,
    user_id         BIGINT,
    customer_type   VARCHAR(20) NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
    kyc_level       SMALLINT    NOT NULL DEFAULT 0,
    risk_rating     VARCHAR(10),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_customers_number    UNIQUE (customer_number),
    -- Khoá phụ này tồn tại CHỈ để hai bảng chi tiết bên dưới FK vào được theo cặp
    -- (id, customer_type). Nhờ nó, DB tự chặn việc gắn hồ sơ tổ chức cho khách
    -- hàng cá nhân — mẫu "disjoint subtype" kinh điển của mô hình party.
    CONSTRAINT uq_customers_id_type   UNIQUE (id, customer_type),
    CONSTRAINT ck_customers_type      CHECK (customer_type IN ('INDIVIDUAL', 'ORGANIZATION')),
    CONSTRAINT ck_customers_status    CHECK (status IN ('DRAFT', 'PENDING_KYC', 'ACTIVE', 'SUSPENDED', 'CLOSED')),
    CONSTRAINT ck_customers_kyc_level CHECK (kyc_level BETWEEN 0 AND 3),
    CONSTRAINT ck_customers_risk      CHECK (risk_rating IS NULL OR risk_rating IN ('LOW', 'MEDIUM', 'HIGH'))
);
COMMENT ON COLUMN customers.customer_number IS
    'Số CIF hiển thị cho người dùng. Tách khỏi id để đổi quy tắc đánh số mà không đụng khóa ngoại';
COMMENT ON COLUMN customers.user_id IS
    'Tham chiếu MỀM sang auth.users. NULL hợp lệ: khách hàng mở tại quầy chưa có tài khoản online';
COMMENT ON COLUMN customers.kyc_level IS
    '0 = chưa KYC. Mức càng cao hạn mức giao dịch càng lớn — quy tắc nằm ở product.product_eligibility_rules';

-- Mô hình PARTY: bảng chung + bảng chi tiết theo loại. Thay cho một bảng 40 cột
-- mà nửa số cột luôn NULL tùy loại khách hàng.
-- customer_type lặp lại ở bảng con KHÔNG phải dư thừa: nó là nửa còn lại của FK
-- theo cặp. CHECK ghim nó bằng 'INDIVIDUAL', FK bắt cặp phải khớp customers,
-- nên một khách hàng ORGANIZATION không thể có dòng ở đây. DB tự chặn, không
-- cần trigger, không đẩy bất biến sang code chưa viết.
CREATE TABLE individual_details (
    customer_id    BIGINT       PRIMARY KEY,
    customer_type  VARCHAR(20)  NOT NULL DEFAULT 'INDIVIDUAL',
    first_name     VARCHAR(100) NOT NULL,
    last_name      VARCHAR(100) NOT NULL,
    date_of_birth  DATE         NOT NULL,
    gender         VARCHAR(10),
    nationality    CHAR(2)      NOT NULL DEFAULT 'VN',
    occupation     VARCHAR(100),
    marital_status VARCHAR(20),
    CONSTRAINT fk_individual_customer FOREIGN KEY (customer_id, customer_type)
        REFERENCES customers (id, customer_type) ON DELETE CASCADE,
    CONSTRAINT ck_individual_type    CHECK (customer_type = 'INDIVIDUAL'),
    CONSTRAINT ck_individual_gender  CHECK (gender IS NULL OR gender IN ('MALE', 'FEMALE', 'OTHER')),
    CONSTRAINT ck_individual_marital CHECK (marital_status IS NULL OR marital_status IN ('SINGLE', 'MARRIED', 'DIVORCED', 'WIDOWED')),
    CONSTRAINT ck_individual_dob     CHECK (date_of_birth < CURRENT_DATE)
);

CREATE TABLE organization_details (
    customer_id        BIGINT       PRIMARY KEY,
    customer_type      VARCHAR(20)  NOT NULL DEFAULT 'ORGANIZATION',
    legal_name         VARCHAR(200) NOT NULL,
    trade_name         VARCHAR(200),
    tax_code           VARCHAR(20)  NOT NULL,
    incorporation_date DATE,
    business_type      VARCHAR(100),
    CONSTRAINT fk_organization_customer FOREIGN KEY (customer_id, customer_type)
        REFERENCES customers (id, customer_type) ON DELETE CASCADE,
    CONSTRAINT ck_organization_type     CHECK (customer_type = 'ORGANIZATION'),
    CONSTRAINT uq_organization_tax_code UNIQUE (tax_code)
);

-- KHÔNG CASCADE. Bốn bảng tiếp theo (giấy tờ, KYC, tài liệu KYC, đánh giá rủi ro)
-- là BẰNG CHỨNG TUÂN THỦ: chúng phải sống sót qua việc đóng hồ sơ khách hàng, vì
-- nghĩa vụ lưu trữ KYC/AML không kết thúc khi quan hệ với khách hàng kết thúc.
-- Hệ quả cố ý: `DELETE FROM customers` sẽ bị FK từ chối. Đóng khách hàng đi bằng
-- `status = 'CLOSED'`, không xoá vật lý. Nếu thật sự phải xoá (yêu cầu xoá dữ liệu
-- cá nhân), đó là một quy trình có phê duyệt, không phải một câu lệnh DELETE.
CREATE TABLE customer_identifications (
    id           BIGSERIAL    PRIMARY KEY,
    customer_id  BIGINT       NOT NULL REFERENCES customers (id),
    id_type      VARCHAR(30)  NOT NULL,
    id_number    VARCHAR(50)  NOT NULL,
    issued_date  DATE,
    issued_place VARCHAR(100),
    expiry_date  DATE,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT ck_ident_type   CHECK (id_type IN ('NATIONAL_ID', 'PASSPORT', 'DRIVER_LICENSE', 'BUSINESS_LICENSE')),
    CONSTRAINT ck_ident_expiry CHECK (expiry_date IS NULL OR issued_date IS NULL OR expiry_date > issued_date),
    CONSTRAINT uq_ident UNIQUE (id_type, id_number)
);
COMMENT ON CONSTRAINT uq_ident ON customer_identifications IS
    'Một số CMND/hộ chiếu không thể thuộc hai người — ràng buộc chống trùng danh tính';

-- valid_from/valid_to: địa chỉ là dữ liệu CÓ LỊCH SỬ, không phải cột ghi đè.
-- Sao kê in ra phải mang địa chỉ tại thời điểm đó, không phải địa chỉ hôm nay.
CREATE TABLE customer_addresses (
    id           BIGSERIAL    PRIMARY KEY,
    customer_id  BIGINT       NOT NULL REFERENCES customers (id) ON DELETE CASCADE,
    address_type VARCHAR(20)  NOT NULL,
    line1        VARCHAR(200) NOT NULL,
    line2        VARCHAR(200),
    ward         VARCHAR(100),
    district     VARCHAR(100),
    province     VARCHAR(100),
    country_code CHAR(2)      NOT NULL DEFAULT 'VN',
    is_primary   BOOLEAN      NOT NULL DEFAULT FALSE,
    valid_from   DATE         NOT NULL DEFAULT CURRENT_DATE,
    valid_to     DATE,
    CONSTRAINT ck_address_type  CHECK (address_type IN ('PERMANENT', 'RESIDENTIAL', 'MAILING', 'BUSINESS')),
    CONSTRAINT ck_address_range CHECK (valid_to IS NULL OR valid_to > valid_from)
);

CREATE TABLE customer_contacts (
    id            BIGSERIAL    PRIMARY KEY,
    customer_id   BIGINT       NOT NULL REFERENCES customers (id) ON DELETE CASCADE,
    contact_type  VARCHAR(20)  NOT NULL,
    contact_value VARCHAR(200) NOT NULL,
    is_primary    BOOLEAN      NOT NULL DEFAULT FALSE,
    verified_at   TIMESTAMPTZ,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT ck_contact_type CHECK (contact_type IN ('EMAIL', 'MOBILE', 'PHONE')),
    CONSTRAINT uq_contact UNIQUE (customer_id, contact_type, contact_value)
);
COMMENT ON COLUMN customer_contacts.verified_at IS
    'NULL = chưa xác minh. Gửi OTP tới số/email chưa xác minh là một lỗ hổng, không phải tiện ích';

-- KYC là STATE MACHINE có người duyệt và có HẠN. Hết hạn thì phải làm lại,
-- không phải "đã duyệt một lần là xong đời".
CREATE TABLE kyc_verifications (
    id            BIGSERIAL    PRIMARY KEY,
    customer_id   BIGINT       NOT NULL REFERENCES customers (id),
    level         SMALLINT     NOT NULL,
    status        VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
    method        VARCHAR(20)  NOT NULL,
    submitted_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    decided_at    TIMESTAMPTZ,
    decided_by    BIGINT,
    reject_reason VARCHAR(500),
    expires_at    TIMESTAMPTZ,
    CONSTRAINT ck_kyc_status  CHECK (status IN ('PENDING', 'IN_REVIEW', 'APPROVED', 'REJECTED', 'EXPIRED')),
    CONSTRAINT ck_kyc_method  CHECK (method IN ('MANUAL', 'EKYC')),
    CONSTRAINT ck_kyc_level   CHECK (level BETWEEN 1 AND 3),
    CONSTRAINT ck_kyc_decided CHECK (
        status NOT IN ('APPROVED', 'REJECTED') OR decided_at IS NOT NULL),
    CONSTRAINT ck_kyc_reject  CHECK (
        status <> 'REJECTED' OR reject_reason IS NOT NULL)
);
COMMENT ON COLUMN kyc_verifications.decided_by IS
    'Tham chiếu MỀM sang auth.users — ai duyệt hồ sơ này';

CREATE TABLE kyc_documents (
    id                  BIGSERIAL    PRIMARY KEY,
    kyc_verification_id BIGINT       NOT NULL REFERENCES kyc_verifications (id),
    doc_type            VARCHAR(50)  NOT NULL,
    storage_key         VARCHAR(500) NOT NULL,
    checksum            VARCHAR(64)  NOT NULL,
    uploaded_at         TIMESTAMPTZ  NOT NULL DEFAULT now()
);
COMMENT ON COLUMN kyc_documents.storage_key IS
    'Khóa trên object storage. Ảnh giấy tờ KHÔNG nằm trong DB';
COMMENT ON COLUMN kyc_documents.checksum IS
    'SHA-256 của file: phát hiện file bị thay sau khi đã duyệt';

-- Append-only: risk rating đổi theo thời gian và phải giải trình được
-- "tại thời điểm mở tài khoản, khách này được đánh giá thế nào".
CREATE TABLE customer_risk_assessments (
    id          BIGSERIAL   PRIMARY KEY,
    customer_id BIGINT      NOT NULL REFERENCES customers (id),
    rating      VARCHAR(10) NOT NULL,
    score       INT         NOT NULL,
    reason      JSONB,
    assessed_by BIGINT,
    assessed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_risk_rating CHECK (rating IN ('LOW', 'MEDIUM', 'HIGH')),
    CONSTRAINT ck_risk_score  CHECK (score BETWEEN 0 AND 100)
);

-- Transactional Outbox: event ghi CÙNG transaction với nghiệp vụ; một publisher
-- tách rời poll rồi đẩy sang Kafka. Đây là lời giải cho bài dual-write DB<->Kafka.
CREATE TABLE outbox (
    id             BIGSERIAL    PRIMARY KEY,
    aggregate_type VARCHAR(50)  NOT NULL,
    aggregate_id   VARCHAR(100) NOT NULL,
    event_type     VARCHAR(100) NOT NULL,
    payload        JSONB        NOT NULL,
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    published_at   TIMESTAMPTZ
);
COMMENT ON TABLE outbox IS
    'Phát customer.kyc.approved.v1, customer.status.changed.v1. Độc lập hoàn toàn với bảng outbox của product và core_banking';
COMMENT ON COLUMN outbox.payload IS
    'Payload TỰ ĐỦ (event-carried state): consumer không gọi ngược lại hỏi thêm';

CREATE INDEX idx_customers_user      ON customers (user_id);
CREATE INDEX idx_customers_status    ON customers (status);
CREATE INDEX idx_ident_customer      ON customer_identifications (customer_id);
CREATE INDEX idx_address_customer    ON customer_addresses (customer_id);
-- Mỗi khách hàng, mỗi loại địa chỉ, tại một thời điểm chỉ có MỘT dòng đang hiệu lực.
-- Không có ràng buộc này thì hai dòng cùng valid_to IS NULL là hợp lệ với DB, và
-- truy vấn "địa chỉ tại ngày X" không còn đảm bảo trả về đúng một kết quả — đúng
-- cái làm hỏng việc in sao kê theo địa chỉ tại kỳ đó.
CREATE UNIQUE INDEX uq_address_current ON customer_addresses (customer_id, address_type)
    WHERE valid_to IS NULL;
CREATE INDEX idx_contact_customer    ON customer_contacts (customer_id);
CREATE INDEX idx_kyc_customer        ON kyc_verifications (customer_id, submitted_at DESC);
CREATE INDEX idx_kyc_open            ON kyc_verifications (submitted_at) WHERE status IN ('PENDING', 'IN_REVIEW');
CREATE INDEX idx_kycdoc_verification ON kyc_documents (kyc_verification_id);
CREATE INDEX idx_risk_customer       ON customer_risk_assessments (customer_id, assessed_at DESC);
CREATE INDEX idx_cust_outbox_unpub   ON outbox (created_at) WHERE published_at IS NULL;

RESET ROLE;
SET search_path = public;

-- <<< HẾT KHỐI [3]
```

- [ ] **Step 3: Reset DB và đếm bảng**

```bash
cd /Users/tanvx/Dev/bank-platform && docker compose down -v && docker compose up -d postgres && sleep 8
docker compose exec -T postgres psql -U postgres -d bank -tAc \
  "SELECT count(*) FROM information_schema.tables WHERE table_schema='customer' AND table_type='BASE TABLE'"
docker compose exec -T postgres psql -U postgres -d bank -tAc \
  "SELECT count(*) FROM pg_tables WHERE schemaname='customer' AND tableowner='customer_svc'"
```

Expected: `10` rồi `10`.

- [ ] **Step 4: Kiểm chứng ràng buộc chống trùng danh tính**

```bash
docker compose exec -T postgres psql -U postgres -d bank -c "
INSERT INTO customer.customers (customer_number, customer_type) VALUES ('CIF001','INDIVIDUAL'), ('CIF002','INDIVIDUAL');
INSERT INTO customer.customer_identifications (customer_id, id_type, id_number)
  SELECT id, 'NATIONAL_ID', '001199001234' FROM customer.customers WHERE customer_number='CIF001';
INSERT INTO customer.customer_identifications (customer_id, id_type, id_number)
  SELECT id, 'NATIONAL_ID', '001199001234' FROM customer.customers WHERE customer_number='CIF002';
"
```

Expected: FAIL với `duplicate key value violates unique constraint "uq_ident"`.

**Bẫy:** nhiều câu lệnh ngăn cách bằng dấu `;` trong **một** `psql -c` đi qua simple query protocol và thành **một transaction ngầm** — câu cuối fail sẽ rollback cả hai câu INSERT trước đó. Step 4b cần các dòng đó tồn tại, nên hãy chạy từng câu bằng một `-c` riêng (mỗi lệnh tự commit), hoặc chấp nhận rằng phải insert lại trước khi sang Step 4b.

- [ ] **Step 4b: Kiểm chứng ba ràng buộc nghiệp vụ vừa thêm**

Mô hình disjoint subtype — khách hàng cá nhân không thể có hồ sơ tổ chức:

```bash
docker compose exec -T postgres psql -U postgres -d bank -c "
INSERT INTO customer.organization_details (customer_id, legal_name, tax_code)
  SELECT id, 'Cty TNHH Sai', '0101234567' FROM customer.customers WHERE customer_number='CIF001';"
```

Expected: FAIL với `violates foreign key constraint "fk_organization_customer"` — `CIF001` là `INDIVIDUAL`, cặp `(id, 'ORGANIZATION')` không tồn tại trong `customers`.

Bằng chứng tuân thủ không bị xoá theo khách hàng:

```bash
docker compose exec -T postgres psql -U postgres -d bank -c \
  "DELETE FROM customer.customers WHERE customer_number='CIF001';"
```

Expected: FAIL với `violates foreign key constraint` trên `customer_identifications` — đúng như thiết kế: đóng khách hàng bằng `status='CLOSED'`, không xoá vật lý.

Một địa chỉ hiện tại cho mỗi loại:

```bash
docker compose exec -T postgres psql -U postgres -d bank -c "
INSERT INTO customer.customer_addresses (customer_id, address_type, line1)
  SELECT id, 'PERMANENT', 'Số 1 Đường A' FROM customer.customers WHERE customer_number='CIF002';
INSERT INTO customer.customer_addresses (customer_id, address_type, line1)
  SELECT id, 'PERMANENT', 'Số 2 Đường B' FROM customer.customers WHERE customer_number='CIF002';"
```

Expected: dòng đầu thành công, dòng thứ hai FAIL với `duplicate key value violates unique constraint "uq_address_current"`.

- [ ] **Step 5: Reset lại DB cho sạch dữ liệu thử**

```bash
cd /Users/tanvx/Dev/bank-platform && docker compose down -v && docker compose up -d postgres && sleep 8
docker compose exec -T postgres psql -U postgres -d bank -tAc "SELECT count(*) FROM customer.customers"
```

Expected: `0`.

- [ ] **Step 6: Commit**

```bash
cd /Users/tanvx/Dev/bank-platform
git add docs/database/schema.sql
git commit -m "feat(db): schema customer — CIF 10 bảng

Mô hình party (customers + individual_details/organization_details),
giấy tờ chống trùng danh tính, địa chỉ có lịch sử, KYC là state machine
có hạn, risk assessment append-only, outbox riêng.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: Schema `product` — 7 bảng

**Files:**
- Modify: `docs/database/schema.sql` (append khối `[4]` vào cuối file)

**Interfaces:**
- Consumes: role `product_svc` và schema `product` từ Task 2
- Produces: `product.products(id BIGSERIAL, product_code VARCHAR(30) UNIQUE)` — `core_banking.accounts.product_code` trỏ mềm vào `products.product_code`. `product.product_gl_mappings(product_id, purpose, gl_code)` — `gl_code` trỏ mềm sang `core_banking.gl_accounts.gl_code`. Sáu bảng còn lại: `product_interest_rates`, `product_fees`, `product_limits`, `product_eligibility_rules`, `outbox`.

- [ ] **Step 1: Xác nhận bảng chưa tồn tại**

```bash
cd /Users/tanvx/Dev/bank-platform
docker compose exec -T postgres psql -U postgres -d bank -tAc \
  "SELECT count(*) FROM information_schema.tables WHERE table_schema='product'"
```

Expected: `0`.

- [ ] **Step 2: Append khối `[4]` vào cuối `docs/database/schema.sql`**

```sql

-- ---------------------------------------------------------------------
-- [4] SCHEMA product — nơi NGHIỆP VỤ SỐNG.
--     Lãi suất, biểu phí, hạn mức, điều kiện mở: tất cả là DỮ LIỆU, không phải
--     hằng số trong code. Đổi biểu phí không được phép là một lần deploy.
--
--     Mọi bảng GIÁ TRỊ (rates, fees, limits, gl_mappings) đều có effective_from/
--     effective_to: đổi thì THÊM DÒNG, không sửa dòng cũ — nếu không, sao kê tháng
--     trước tính lại sẽ ra số khác. Riêng product_eligibility_rules CỐ Ý không có:
--     điều kiện mở tài khoản chỉ được đánh giá tại thời điểm mở, không cần tra ngược.
--
--     Ràng buộc "không hai dòng cùng hiệu lực" KHÔNG phải UNIQUE trên effective_from
--     — cái đó chỉ chặn trùng đúng ngày bắt đầu. Phải là EXCLUDE trên khoảng ngày.
-- ---------------------------------------------------------------------

-- btree_gist cho phép trộn toán tử '=' (trên BIGINT, VARCHAR) với '&&' (trên
-- daterange) trong cùng một EXCLUDE. Chạy dưới quyền superuser, TRƯỚC SET ROLE.
CREATE EXTENSION IF NOT EXISTS btree_gist;

SET ROLE product_svc;
SET search_path = product;

CREATE TABLE products (
    id             BIGSERIAL     PRIMARY KEY,
    product_code   VARCHAR(30)   NOT NULL,
    name           VARCHAR(200)  NOT NULL,
    category       VARCHAR(30)   NOT NULL,
    currency       CHAR(3)       NOT NULL DEFAULT 'VND',
    status         VARCHAR(20)   NOT NULL DEFAULT 'DRAFT',
    description    VARCHAR(1000),
    effective_from DATE          NOT NULL DEFAULT CURRENT_DATE,
    effective_to   DATE,
    created_at     TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT uq_products_code     UNIQUE (product_code),
    CONSTRAINT ck_products_category CHECK (category IN ('CURRENT_ACCOUNT', 'SAVINGS_ACCOUNT', 'TERM_DEPOSIT')),
    CONSTRAINT ck_products_status   CHECK (status IN ('DRAFT', 'ACTIVE', 'RETIRED')),
    CONSTRAINT ck_products_period   CHECK (effective_to IS NULL OR effective_to > effective_from)
);

-- Lãi suất BẬC THANG: theo số dư (tier_from/tier_to) hoặc theo kỳ hạn (term_months).
CREATE TABLE product_interest_rates (
    id             BIGSERIAL     PRIMARY KEY,
    product_id     BIGINT        NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    tier_from      NUMERIC(19,4) NOT NULL DEFAULT 0,
    tier_to        NUMERIC(19,4),
    term_months    INT,
    annual_rate    NUMERIC(9,6)  NOT NULL,
    effective_from DATE          NOT NULL DEFAULT CURRENT_DATE,
    effective_to   DATE,
    CONSTRAINT ck_rate_tier   CHECK (tier_to IS NULL OR tier_to > tier_from),
    CONSTRAINT ck_rate_value  CHECK (annual_rate >= 0 AND annual_rate < 1),
    CONSTRAINT ck_rate_term   CHECK (term_months IS NULL OR term_months > 0),
    CONSTRAINT ck_rate_period CHECK (effective_to IS NULL OR effective_to > effective_from)
);
COMMENT ON COLUMN product_interest_rates.annual_rate IS
    'Tỉ lệ thập phân: 0.045000 = 4.5%/năm. CHECK < 1 chặn lỗi nhập 4.5 thay vì 0.045';
COMMENT ON COLUMN product_interest_rates.tier_to IS
    'NULL = bậc cao nhất, không giới hạn trên';
COMMENT ON COLUMN product_interest_rates.term_months IS
    'NULL với sản phẩm không kỳ hạn. BẤT BIẾN DO ỨNG DỤNG GIỮ: TERM_DEPOSIT phải có term_months, CURRENT/SAVINGS phải không — CHECK không với sang bảng products được nên DB không chặn nổi';

CREATE TABLE product_fees (
    id             BIGSERIAL     PRIMARY KEY,
    product_id     BIGINT        NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    fee_code       VARCHAR(30)   NOT NULL,
    fee_type       VARCHAR(20)   NOT NULL,
    amount         NUMERIC(19,4),
    percent        NUMERIC(9,6),
    min_amount     NUMERIC(19,4),
    max_amount     NUMERIC(19,4),
    charge_event   VARCHAR(40)   NOT NULL,
    currency       CHAR(3)       NOT NULL DEFAULT 'VND',
    effective_from DATE          NOT NULL DEFAULT CURRENT_DATE,
    effective_to   DATE,
    -- TIERED CỐ Ý KHÔNG có trong danh sách: phí bậc thang cần một bảng
    -- product_fee_tiers để chứa các bậc, mà bảng đó chưa tồn tại. Thêm một enum
    -- value không dùng được chỉ tạo ra một lỗ trong ck_fee_shape. Khi nào thực sự
    -- cần phí bậc thang thì thêm bảng tier TRƯỚC, rồi mới mở enum.
    CONSTRAINT ck_fee_type  CHECK (fee_type IN ('FLAT', 'PERCENT')),
    CONSTRAINT ck_fee_event CHECK (charge_event IN (
        'ACCOUNT_OPEN', 'ACCOUNT_CLOSE', 'MONTHLY_MAINTENANCE',
        'INTERNAL_TRANSFER', 'EXTERNAL_TRANSFER', 'ATM_WITHDRAWAL', 'STATEMENT_REQUEST')),
    CONSTRAINT ck_fee_shape CHECK (
           (fee_type = 'FLAT'    AND amount  IS NOT NULL AND percent IS NULL)
        OR (fee_type = 'PERCENT' AND percent IS NOT NULL AND amount  IS NULL)),
    CONSTRAINT ck_fee_bounds CHECK (min_amount IS NULL OR max_amount IS NULL OR max_amount >= min_amount),
    CONSTRAINT uq_fee UNIQUE (product_id, fee_code, effective_from),
    -- Hai biểu phí cùng fee_code không được PHỦ NHAU về thời gian. UNIQUE trên
    -- effective_from chỉ chặn trùng đúng ngày bắt đầu, không chặn được
    -- (01/01 -> 31/12) chồng lên (01/06 -> mở) — và khi đó không ai trả lời được
    -- tháng 6 thu phí theo dòng nào.
    CONSTRAINT ex_fee_overlap EXCLUDE USING gist (
        product_id WITH =,
        fee_code   WITH =,
        daterange(effective_from, effective_to, '[)') WITH &&)
);
COMMENT ON CONSTRAINT ck_fee_shape ON product_fees IS
    'FLAT dùng amount, PERCENT dùng percent — không cho điền cả hai rồi cãi nhau cái nào thắng';

CREATE TABLE product_limits (
    id             BIGSERIAL     PRIMARY KEY,
    product_id     BIGINT        NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    limit_code     VARCHAR(30)   NOT NULL,
    scope          VARCHAR(20)   NOT NULL,
    channel        VARCHAR(20)   NOT NULL DEFAULT 'ANY',
    max_amount     NUMERIC(19,4),
    max_count      INT,
    currency       CHAR(3)       NOT NULL DEFAULT 'VND',
    effective_from DATE          NOT NULL DEFAULT CURRENT_DATE,
    effective_to   DATE,
    CONSTRAINT ck_limit_scope   CHECK (scope IN ('PER_TRANSACTION', 'PER_DAY', 'PER_MONTH')),
    CONSTRAINT ck_limit_channel CHECK (channel IN ('ANY', 'INTERNET', 'MOBILE', 'ATM', 'BRANCH')),
    CONSTRAINT ck_limit_value   CHECK (max_amount IS NOT NULL OR max_count IS NOT NULL),
    -- channel PHẢI nằm trong khoá: cùng một limit_code hoàn toàn có thể có mức khác
    -- nhau theo kênh (chuyển qua mobile hạn mức thấp hơn qua quầy). Thiếu channel ở
    -- đây thì uq_limit mâu thuẫn với ex_limit_overlap ngay bên dưới, và seed hai hạn
    -- mức TRF_PER_TXN khác kênh sẽ không insert nổi.
    CONSTRAINT uq_limit UNIQUE (product_id, limit_code, channel, effective_from),
    -- Cùng lý do như ex_fee_overlap: hai hạn mức cùng mã không được phủ nhau.
    -- channel nằm trong khoá vì cùng một limit_code có thể khác nhau theo kênh.
    CONSTRAINT ex_limit_overlap EXCLUDE USING gist (
        product_id WITH =,
        limit_code WITH =,
        channel    WITH =,
        daterange(effective_from, effective_to, '[)') WITH &&)
);
COMMENT ON TABLE product_limits IS
    'Khuôn hạn mức theo sản phẩm. Mức đã dùng thực tế nằm ở core_banking.transfer_limit_usage';

CREATE TABLE product_eligibility_rules (
    id         BIGSERIAL    PRIMARY KEY,
    product_id BIGINT       NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    rule_type  VARCHAR(30)  NOT NULL,
    operator   VARCHAR(10)  NOT NULL,
    rule_value VARCHAR(100) NOT NULL,
    CONSTRAINT ck_rule_type     CHECK (rule_type IN ('MIN_AGE', 'MAX_AGE', 'MIN_KYC_LEVEL', 'CUSTOMER_TYPE', 'MAX_RISK_RATING')),
    CONSTRAINT ck_rule_operator CHECK (operator IN ('EQ', 'NEQ', 'GTE', 'LTE', 'IN')),
    CONSTRAINT uq_rule UNIQUE (product_id, rule_type)
);

-- CẦU NỐI QUAN TRỌNG NHẤT giữa product và sổ cái: sản phẩm nào thì gốc hạch
-- toán vào GL nào, lãi phải trả vào GL nào, phí thu vào GL nào.
-- Không có bảng này thì mã GL bị hardcode trong code — lỗi kinh điển của
-- core banking tự viết, và là thứ khiến việc thêm sản phẩm mới phải sửa code.
-- CÓ effective_from/effective_to, và đó là điểm quan trọng nhất của bảng này.
-- Nếu chỉ UNIQUE (product_id, purpose) thì đổi mã GL buộc phải UPDATE dòng cũ —
-- và ngay lúc đó mất khả năng trả lời "giao dịch tháng trước hạch toán vào tài
-- khoản nào". Với sổ cái, mất lịch sử ánh xạ là mất khả năng đối chiếu kỳ cũ.
CREATE TABLE product_gl_mappings (
    id             BIGSERIAL   PRIMARY KEY,
    product_id     BIGINT      NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    purpose        VARCHAR(30) NOT NULL,
    gl_code        VARCHAR(20) NOT NULL,
    effective_from DATE        NOT NULL DEFAULT CURRENT_DATE,
    effective_to   DATE,
    CONSTRAINT ck_glmap_purpose CHECK (purpose IN ('PRINCIPAL', 'INTEREST_PAYABLE', 'INTEREST_EXPENSE', 'FEE_INCOME')),
    CONSTRAINT ck_glmap_period  CHECK (effective_to IS NULL OR effective_to > effective_from),
    CONSTRAINT uq_glmap UNIQUE (product_id, purpose, effective_from),
    CONSTRAINT ex_glmap_overlap EXCLUDE USING gist (
        product_id WITH =,
        purpose    WITH =,
        daterange(effective_from, effective_to, '[)') WITH &&)
);
COMMENT ON COLUMN product_gl_mappings.gl_code IS
    'Tham chiếu MỀM sang core_banking.gl_accounts.gl_code — không FK xuyên schema';

CREATE TABLE outbox (
    id             BIGSERIAL    PRIMARY KEY,
    aggregate_type VARCHAR(50)  NOT NULL,
    aggregate_id   VARCHAR(100) NOT NULL,
    event_type     VARCHAR(100) NOT NULL,
    payload        JSONB        NOT NULL,
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    published_at   TIMESTAMPTZ
);
COMMENT ON TABLE outbox IS
    'Phát product.activated.v1 / product.retired.v1 để service khác vô hiệu cache catalog. Độc lập với outbox của customer và core_banking';

CREATE INDEX idx_products_status      ON products (status) WHERE status = 'ACTIVE';
CREATE INDEX idx_rates_product        ON product_interest_rates (product_id, effective_from DESC);
CREATE INDEX idx_fees_product         ON product_fees (product_id, charge_event);
CREATE INDEX idx_limits_product       ON product_limits (product_id, scope, channel);
CREATE INDEX idx_rules_product        ON product_eligibility_rules (product_id);
CREATE INDEX idx_glmap_product        ON product_gl_mappings (product_id);
CREATE INDEX idx_prod_outbox_unpub    ON outbox (created_at) WHERE published_at IS NULL;

RESET ROLE;
SET search_path = public;

-- <<< HẾT KHỐI [4]
```

- [ ] **Step 3: Reset DB và đếm bảng**

```bash
cd /Users/tanvx/Dev/bank-platform && docker compose down -v && docker compose up -d postgres && sleep 8
docker compose exec -T postgres psql -U postgres -d bank -tAc \
  "SELECT count(*) FROM information_schema.tables WHERE table_schema='product' AND table_type='BASE TABLE'"
docker compose exec -T postgres psql -U postgres -d bank -tAc \
  "SELECT count(*) FROM pg_tables WHERE schemaname='product' AND tableowner='product_svc'"
```

Expected: `7` rồi `7`.

- [ ] **Step 4: Kiểm chứng `ck_fee_shape` và `ck_rate_value`**

```bash
docker compose exec -T postgres psql -U postgres -d bank -c "
INSERT INTO product.products (product_code, name, category) VALUES ('TMP','tạm','CURRENT_ACCOUNT');
INSERT INTO product.product_fees (product_id, fee_code, fee_type, amount, percent, charge_event)
  SELECT id, 'BAD', 'FLAT', 1000, 0.01, 'ACCOUNT_OPEN' FROM product.products WHERE product_code='TMP';
"
```

Expected: FAIL với `new row for relation "product_fees" violates check constraint "ck_fee_shape"`.

```bash
docker compose exec -T postgres psql -U postgres -d bank -c "
INSERT INTO product.product_interest_rates (product_id, annual_rate)
  SELECT id, 4.5 FROM product.products WHERE product_code='TMP';
"
```

Expected: FAIL với `violates check constraint "ck_rate_value"` — đây chính là lỗi nhập `4.5` thay vì `0.045` mà constraint sinh ra để chặn.

- [ ] **Step 4b: Kiểm chứng EXCLUDE chặn biểu phí chồng lấn**

Chạy từng lệnh bằng một `-c` riêng (nhiều lệnh trong một `-c` là một transaction ngầm, lệnh cuối fail sẽ rollback cả lô):

```bash
docker compose exec -T postgres psql -U postgres -d bank -c "
INSERT INTO product.product_fees (product_id, fee_code, fee_type, amount, charge_event, effective_from, effective_to)
  SELECT id, 'MAINT_MONTHLY', 'FLAT', 11000, 'MONTHLY_MAINTENANCE', DATE '2026-01-01', DATE '2026-12-31'
  FROM product.products WHERE product_code='TMP';"
docker compose exec -T postgres psql -U postgres -d bank -c "
INSERT INTO product.product_fees (product_id, fee_code, fee_type, amount, charge_event, effective_from, effective_to)
  SELECT id, 'MAINT_MONTHLY', 'FLAT', 15000, 'MONTHLY_MAINTENANCE', DATE '2026-06-01', NULL
  FROM product.products WHERE product_code='TMP';"
```

Expected: lệnh đầu thành công; lệnh thứ hai FAIL với `conflicting key value violates exclusion constraint "ex_fee_overlap"` — hai biểu phí cùng `MAINT_MONTHLY` phủ nhau tháng 6–12.

Kiểm luôn `TIERED` đã bị loại khỏi enum:

```bash
docker compose exec -T postgres psql -U postgres -d bank -c "
INSERT INTO product.product_fees (product_id, fee_code, fee_type, charge_event)
  SELECT id, 'TIER_TEST', 'TIERED', 'ACCOUNT_OPEN' FROM product.products WHERE product_code='TMP';"
```

Expected: FAIL với `violates check constraint` — tên constraint là **`ck_fee_shape` hoặc `ck_fee_type`**, cả hai đều chấp nhận được. Dòng đó vi phạm cả hai (`TIERED` không nằm trong enum, và cũng không khớp nhánh `FLAT` lẫn `PERCENT` của `ck_fee_shape`), và Postgres không đảm bảo báo cái nào trước. Điều cần chứng minh là INSERT bị từ chối, không phải nó bị từ chối bởi constraint nào.

- [ ] **Step 5: Reset lại DB cho sạch dữ liệu thử**

```bash
cd /Users/tanvx/Dev/bank-platform && docker compose down -v && docker compose up -d postgres && sleep 8
docker compose exec -T postgres psql -U postgres -d bank -tAc "SELECT count(*) FROM product.products"
```

Expected: `0`.

- [ ] **Step 6: Commit**

```bash
cd /Users/tanvx/Dev/bank-platform
git add docs/database/schema.sql
git commit -m "feat(db): schema product — 7 bảng

Lãi suất bậc thang, biểu phí, hạn mức, điều kiện mở đều là dữ liệu có
hiệu lực theo thời gian. product_gl_mappings là cầu nối sang sổ cái,
thay cho việc hardcode mã GL trong code.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 7: `core_banking` phần 1 — chart of accounts, tài khoản, hold

**Files:**
- Modify: `docs/database/schema.sql` (append khối `[5a]` vào cuối file)

**Interfaces:**
- Consumes: role `core_svc` và schema `core_banking` từ Task 2
- Produces: `core_banking.gl_accounts(gl_code VARCHAR(20) UNIQUE)` — Task 8/9 FK vào cột này. `core_banking.accounts(id BIGSERIAL)` — Task 8/9 FK vào `accounts.id`. `core_banking.account_holders`, `core_banking.account_holds`.

- [ ] **Step 1: Xác nhận bảng chưa tồn tại**

```bash
cd /Users/tanvx/Dev/bank-platform
docker compose exec -T postgres psql -U postgres -d bank -tAc \
  "SELECT count(*) FROM information_schema.tables WHERE table_schema='core_banking'"
```

Expected: `0`.

- [ ] **Step 2: Append khối `[5a]` vào cuối `docs/database/schema.sql`**

```sql

-- =====================================================================
-- [5] SCHEMA core_banking — TRÁI TIM.
--     Thứ tự tạo bảng trong khối này là BẮT BUỘC: gl_accounts trước (mọi thứ
--     FK vào gl_code), rồi accounts, rồi sổ cái, rồi giao dịch.
-- =====================================================================
SET ROLE core_svc;
SET search_path = core_banking;

-- ---------------------------------------------------------------------
-- [5a] Chart of accounts, tài khoản khách hàng, hold
-- ---------------------------------------------------------------------

-- SỔ CÁI. Phân biệt với accounts: gl_accounts là sổ cái của ngân hàng,
-- accounts là sổ phụ của khách hàng. Số dư mọi tài khoản khách hàng của cùng
-- một sản phẩm cộng lại phải bằng số dư GL tương ứng — đó là phép đối chiếu
-- cơ bản nhất của core banking.
CREATE TABLE gl_accounts (
    id             BIGSERIAL    PRIMARY KEY,
    gl_code        VARCHAR(20)  NOT NULL,
    name           VARCHAR(200) NOT NULL,
    account_class  VARCHAR(20)  NOT NULL,
    normal_balance VARCHAR(6)   NOT NULL,
    parent_gl_code VARCHAR(20)  REFERENCES gl_accounts (gl_code),
    is_postable    BOOLEAN      NOT NULL DEFAULT TRUE,
    currency       CHAR(3)      NOT NULL DEFAULT 'VND',
    status         VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE',
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    -- UNIQUE đặt tên tường minh: accounts.gl_code và journal_lines.gl_code đều
    -- FK vào cột này, nên nó là một hợp đồng công khai chứ không phải chi tiết nội bộ.
    CONSTRAINT uq_gl_code   UNIQUE (gl_code),
    CONSTRAINT ck_gl_class  CHECK (account_class IN ('ASSET', 'LIABILITY', 'EQUITY', 'INCOME', 'EXPENSE')),
    CONSTRAINT ck_gl_normal CHECK (normal_balance IN ('DEBIT', 'CREDIT')),
    CONSTRAINT ck_gl_status CHECK (status IN ('ACTIVE', 'CLOSED')),
    -- Nguyên lý kế toán kép, viết thành ràng buộc thay vì để trong đầu người ta:
    -- TÀI SẢN và CHI PHÍ tăng bên NỢ; NỢ PHẢI TRẢ, VỐN và THU NHẬP tăng bên CÓ.
    CONSTRAINT ck_gl_class_normal CHECK (
           (account_class IN ('ASSET', 'EXPENSE')              AND normal_balance = 'DEBIT')
        OR (account_class IN ('LIABILITY', 'EQUITY', 'INCOME') AND normal_balance = 'CREDIT'))
);
COMMENT ON COLUMN gl_accounts.is_postable IS
    'FALSE = tài khoản tổng hợp, chỉ để gom số. Hạch toán thẳng vào nó là sai';

CREATE TABLE accounts (
    id                  BIGSERIAL     PRIMARY KEY,
    account_number      VARCHAR(20)   NOT NULL,
    product_code        VARCHAR(30)   NOT NULL,
    primary_customer_id BIGINT        NOT NULL,
    currency            CHAR(3)       NOT NULL DEFAULT 'VND',
    status              VARCHAR(20)   NOT NULL DEFAULT 'PENDING',
    gl_code             VARCHAR(20)   NOT NULL REFERENCES gl_accounts (gl_code),
    ledger_balance      NUMERIC(19,4) NOT NULL DEFAULT 0,
    hold_amount         NUMERIC(19,4) NOT NULL DEFAULT 0,
    available_balance   NUMERIC(19,4) GENERATED ALWAYS AS (ledger_balance - hold_amount) STORED,
    overdraft_limit     NUMERIC(19,4) NOT NULL DEFAULT 0,
    version             INT           NOT NULL DEFAULT 0,
    opened_at           TIMESTAMPTZ,
    closed_at           TIMESTAMPTZ,
    created_at          TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT uq_accounts_number    UNIQUE (account_number),
    CONSTRAINT ck_accounts_status    CHECK (status IN ('PENDING', 'ACTIVE', 'DORMANT', 'FROZEN', 'CLOSED')),
    CONSTRAINT ck_accounts_hold      CHECK (hold_amount >= 0),
    CONSTRAINT ck_accounts_overdraft CHECK (overdraft_limit >= 0),
    -- Viết bằng biểu thức GỐC chứ không tham chiếu cột available_balance.
    -- (Postgres CHO PHÉP CHECK tham chiếu cột GENERATED STORED — đã kiểm chứng.)
    -- Lý do là tính độc lập: ràng buộc đọc được mà không cần biết
    -- available_balance được định nghĩa thế nào, và không phụ thuộc thứ tự tính cột.
    CONSTRAINT ck_accounts_available CHECK (ledger_balance - hold_amount >= -overdraft_limit),
    CONSTRAINT ck_accounts_closed    CHECK (status <> 'CLOSED' OR closed_at IS NOT NULL)
);
COMMENT ON TABLE accounts IS
    'CHỈ tài khoản khách hàng. KHÔNG có tài khoản SYSTEM (quyết định DB3): phía nội bộ của bút toán đi thẳng vào gl_code với account_id NULL';
COMMENT ON COLUMN accounts.product_code IS
    'Tham chiếu MỀM sang product.products.product_code';
COMMENT ON COLUMN accounts.primary_customer_id IS
    'Tham chiếu MỀM sang customer.customers.id. Cố ý trùng lặp với dòng PRIMARY trong account_holders để truy vấn "tài khoản của tôi" không phải join. BẤT BIẾN do ứng dụng giữ: luôn tồn tại account_holders(id, primary_customer_id, PRIMARY)';
COMMENT ON COLUMN accounts.ledger_balance IS
    'Số dư sổ cái, lưu sẵn (quyết định DB4). Cập nhật CÙNG transaction với bút toán, không bao giờ tính lại từ journal_lines lúc đọc';
COMMENT ON COLUMN accounts.available_balance IS
    'Số dư KHẢ DỤNG = sổ cái trừ tiền đang treo. Đây là con số khách hàng nhìn thấy và là con số dùng để duyệt giao dịch';
COMMENT ON COLUMN accounts.version IS
    'Optimistic lock cho JPA @Version. Hai giao dịch cùng trừ một tài khoản là tình huống thật, không phải giả định';

-- Một tài khoản NHIỀU CHỦ: đồng sở hữu, người được ủy quyền ký.
CREATE TABLE account_holders (
    account_id  BIGINT      NOT NULL REFERENCES accounts (id) ON DELETE CASCADE,
    customer_id BIGINT      NOT NULL,
    holder_role VARCHAR(30) NOT NULL,
    added_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (account_id, customer_id),
    CONSTRAINT ck_holder_role CHECK (holder_role IN ('PRIMARY', 'JOINT', 'AUTHORIZED_SIGNATORY'))
);
COMMENT ON COLUMN account_holders.customer_id IS
    'Tham chiếu MỀM sang customer.customers.id';

-- Partial unique index: mỗi tài khoản CHỈ MỘT chủ chính. Đây là nửa ràng buộc
-- mà DB giữ được; nửa còn lại (customer_id của dòng này == accounts.primary_customer_id)
-- nằm ở hai bảng nên ứng dụng phải giữ.
CREATE UNIQUE INDEX uq_account_one_primary
    ON account_holders (account_id) WHERE holder_role = 'PRIMARY';

-- HOLD = tiền đã bị giữ nhưng CHƯA hạch toán. Đây là lý do quẹt thẻ xong tiền
-- "treo" mà số dư sổ cái chưa đổi. Hold hết hạn mà không capture thì tự nhả.
CREATE TABLE account_holds (
    id             BIGSERIAL     PRIMARY KEY,
    account_id     BIGINT        NOT NULL REFERENCES accounts (id),
    amount         NUMERIC(19,4) NOT NULL,
    reason         VARCHAR(20)   NOT NULL,
    reference_type VARCHAR(30),
    reference_id   VARCHAR(100),
    status         VARCHAR(20)   NOT NULL DEFAULT 'ACTIVE',
    placed_at      TIMESTAMPTZ   NOT NULL DEFAULT now(),
    expires_at     TIMESTAMPTZ,
    released_at    TIMESTAMPTZ,
    CONSTRAINT ck_hold_amount   CHECK (amount > 0),
    CONSTRAINT ck_hold_reason   CHECK (reason IN ('TRANSFER', 'CARD_AUTH', 'LEGAL', 'FEE')),
    CONSTRAINT ck_hold_status   CHECK (status IN ('ACTIVE', 'RELEASED', 'CAPTURED', 'EXPIRED')),
    CONSTRAINT ck_hold_released CHECK (status = 'ACTIVE' OR released_at IS NOT NULL),
    -- Chỉ phong toả theo lệnh cơ quan (LEGAL) mới được vô hạn. Mọi hold còn lại
    -- BẮT BUỘC có hạn — không có expires_at thì job quét (đi qua idx_holds_expiry)
    -- không nhìn thấy nó, và tiền của khách bị treo vĩnh viễn không đường về.
    CONSTRAINT ck_hold_expiry   CHECK (reason = 'LEGAL' OR expires_at IS NOT NULL)
);
COMMENT ON COLUMN account_holds.status IS
    'CAPTURED = đã chuyển thành bút toán thật. RELEASED = nhả không hạch toán. EXPIRED = quá hạn, job quét nhả';

CREATE INDEX idx_accounts_customer ON accounts (primary_customer_id);
CREATE INDEX idx_accounts_product  ON accounts (product_code);
CREATE INDEX idx_accounts_gl       ON accounts (gl_code);
CREATE INDEX idx_holders_customer  ON account_holders (customer_id);
-- Hai partial index cùng lọc ACTIVE nhưng phục vụ hai truy vấn khác nhau:
-- một cho "tổng tiền treo của tài khoản này", một cho job quét hold quá hạn.
CREATE INDEX idx_holds_active ON account_holds (account_id) WHERE status = 'ACTIVE';
CREATE INDEX idx_holds_expiry ON account_holds (expires_at) WHERE status = 'ACTIVE';

-- <<< HẾT KHỐI [5a]
```

Lưu ý: khối `[5a]` **không** có `RESET ROLE` ở cuối — Task 8 và 9 append tiếp trong cùng phiên `SET ROLE core_svc`. `RESET ROLE` chỉ xuất hiện một lần, ở cuối khối `[5c]` (Task 9).

- [ ] **Step 3: Reset DB và đếm bảng**

```bash
cd /Users/tanvx/Dev/bank-platform && docker compose down -v && docker compose up -d postgres && sleep 8
docker compose exec -T postgres psql -U postgres -d bank -tAc \
  "SELECT count(*) FROM information_schema.tables WHERE table_schema='core_banking' AND table_type='BASE TABLE'"
```

Expected: `4`.

- [ ] **Step 4: Kiểm chứng ràng buộc nguyên lý kế toán kép**

```bash
docker compose exec -T postgres psql -U postgres -d bank -c \
  "INSERT INTO core_banking.gl_accounts (gl_code, name, account_class, normal_balance)
   VALUES ('9999', 'sai nguyên lý', 'ASSET', 'CREDIT');"
```

Expected: FAIL với `violates check constraint "ck_gl_class_normal"` — tài sản không thể có số dư thường bên Có.

- [ ] **Step 5: Kiểm chứng `available_balance` và ràng buộc thấu chi**

```bash
docker compose exec -T postgres psql -U postgres -d bank -c "
INSERT INTO core_banking.gl_accounts (gl_code, name, account_class, normal_balance)
VALUES ('2010', 'Tiền gửi KH - thanh toán', 'LIABILITY', 'CREDIT');
INSERT INTO core_banking.accounts (account_number, product_code, primary_customer_id, gl_code, ledger_balance, hold_amount)
VALUES ('0000000001', 'CA_STANDARD', 1, '2010', 1000000, 250000);
SELECT ledger_balance, hold_amount, available_balance FROM core_banking.accounts WHERE account_number='0000000001';"
```

Expected: một dòng `1000000.0000 | 250000.0000 | 750000.0000` — cột GENERATED tự tính.

```bash
docker compose exec -T postgres psql -U postgres -d bank -c \
  "UPDATE core_banking.accounts SET hold_amount = 1200000 WHERE account_number='0000000001';"
```

Expected: FAIL với `violates check constraint "ck_accounts_available"` — treo nhiều hơn số dư mà `overdraft_limit` = 0.

- [ ] **Step 6: Kiểm chứng "mỗi tài khoản một chủ chính"**

```bash
docker compose exec -T postgres psql -U postgres -d bank -c "
INSERT INTO core_banking.account_holders (account_id, customer_id, holder_role)
  SELECT id, 1, 'PRIMARY' FROM core_banking.accounts WHERE account_number='0000000001';
INSERT INTO core_banking.account_holders (account_id, customer_id, holder_role)
  SELECT id, 2, 'PRIMARY' FROM core_banking.accounts WHERE account_number='0000000001';"
```

Expected: FAIL với `duplicate key value violates unique constraint "uq_account_one_primary"`.

- [ ] **Step 6b: Kiểm chứng hold bắt buộc có hạn, trừ LEGAL**

```bash
docker compose exec -T postgres psql -U postgres -d bank -c "
INSERT INTO core_banking.account_holds (account_id, amount, reason)
  SELECT id, 50000, 'CARD_AUTH' FROM core_banking.accounts WHERE account_number='0000000001';"
```

Expected: FAIL với `violates check constraint "ck_hold_expiry"` — hold thẻ không hạn là tiền treo vĩnh viễn.

```bash
docker compose exec -T postgres psql -U postgres -d bank -c "
INSERT INTO core_banking.account_holds (account_id, amount, reason)
  SELECT id, 50000, 'LEGAL' FROM core_banking.accounts WHERE account_number='0000000001';"
```

Expected: thành công — phong toả theo lệnh cơ quan đúng là không có hạn định trước.

- [ ] **Step 7: Reset lại DB cho sạch dữ liệu thử**

```bash
cd /Users/tanvx/Dev/bank-platform && docker compose down -v && docker compose up -d postgres && sleep 8
docker compose exec -T postgres psql -U postgres -d bank -tAc "SELECT count(*) FROM core_banking.accounts"
```

Expected: `0`.

- [ ] **Step 8: Commit**

```bash
cd /Users/tanvx/Dev/bank-platform
git add docs/database/schema.sql
git commit -m "feat(db): core_banking phần 1 — chart of accounts, accounts, holds

gl_accounts mã hóa nguyên lý kế toán kép thành CHECK constraint.
accounts có available_balance GENERATED = sổ cái trừ tiền treo, và
partial unique index đảm bảo mỗi tài khoản đúng một chủ chính.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 8: `core_banking` phần 2 — sổ cái bút toán kép và trigger cân đối

**Files:**
- Modify: `docs/database/schema.sql` (append khối `[5b]` vào cuối file)

**Interfaces:**
- Consumes: `gl_accounts.gl_code`, `accounts.id` từ Task 7
- Produces: `core_banking.journal_entries(id BIGSERIAL, entry_reference VARCHAR(40) UNIQUE)` — Task 9 FK vào `journal_entries.id` từ `transfers`, `interest_accruals`, `fee_charges`. `core_banking.journal_lines` (partition theo tháng). `core_banking.account_balance_snapshots`. Function `core_banking.assert_journal_balanced()` và constraint trigger `trg_journal_balanced`.

**Đây là task quan trọng nhất của phần database.** Nó kiểm chứng quyết định DB2 — điều mà spec đã ghi rõ là *chưa* được xác minh.

- [ ] **Step 1: Xác nhận bảng chưa tồn tại**

```bash
cd /Users/tanvx/Dev/bank-platform
docker compose exec -T postgres psql -U postgres -d bank -tAc \
  "SELECT count(*) FROM information_schema.tables WHERE table_schema='core_banking' AND table_name IN ('journal_entries','journal_lines','account_balance_snapshots')"
```

Expected: `0`.

- [ ] **Step 2: Append khối `[5b]` vào cuối `docs/database/schema.sql`**

```sql

-- ---------------------------------------------------------------------
-- [5b] SỔ CÁI BÚT TOÁN KÉP (quyết định DB1)
--
--      Một giao dịch = MỘT journal_entries (header) + NHIỀU journal_lines.
--      Chuyển 100.000 và thu phí 2.000 là một bút toán BA dòng:
--        Nợ  tài khoản người gửi   102.000
--        Có  tài khoản người nhận  100.000
--        Có  GL thu nhập phí         2.000
--      Bảng ledger_entries phẳng của bản cũ không diễn tả nổi việc này.
-- ---------------------------------------------------------------------

CREATE TABLE journal_entries (
    id                   BIGSERIAL    PRIMARY KEY,
    entry_reference      VARCHAR(40)  NOT NULL,
    transaction_type     VARCHAR(20)  NOT NULL,
    source_type          VARCHAR(30),
    source_id            VARCHAR(100),
    value_date           DATE         NOT NULL,
    booking_date         DATE         NOT NULL DEFAULT CURRENT_DATE,
    posted_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    description          VARCHAR(500),
    reversal_of_entry_id BIGINT       REFERENCES journal_entries (id),
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_journal_reference UNIQUE (entry_reference),
    CONSTRAINT ck_journal_txn_type CHECK (transaction_type IN (
        'TRANSFER', 'FEE', 'INTEREST', 'REVERSAL', 'ADJUSTMENT', 'OPENING')),
    -- REVERSAL bắt buộc trỏ về bản gốc; loại khác bắt buộc không trỏ.
    CONSTRAINT ck_journal_reversal CHECK (
           (transaction_type =  'REVERSAL' AND reversal_of_entry_id IS NOT NULL)
        OR (transaction_type <> 'REVERSAL' AND reversal_of_entry_id IS NULL))
);
COMMENT ON COLUMN journal_entries.value_date IS
    'NGÀY HIỆU LỰC — quyết định tính lãi. Khác booking_date: giao dịch cuối ngày 31 có thể value_date 31 nhưng booking_date 01 tháng sau';
COMMENT ON COLUMN journal_entries.booking_date IS
    'NGÀY HẠCH TOÁN — quyết định bút toán rơi vào kỳ sổ nào';
COMMENT ON COLUMN journal_entries.reversal_of_entry_id IS
    'Sổ cái APPEND-ONLY: sai thì ghi bút toán đảo trỏ về bản gốc, không bao giờ UPDATE hay DELETE bút toán cũ';

CREATE TABLE journal_lines (
    id               BIGSERIAL,
    journal_entry_id BIGINT        NOT NULL REFERENCES journal_entries (id),
    line_no          INT           NOT NULL,
    account_id       BIGINT        REFERENCES accounts (id),
    gl_code          VARCHAR(20)   NOT NULL REFERENCES gl_accounts (gl_code),
    direction        VARCHAR(6)    NOT NULL,
    amount           NUMERIC(19,4) NOT NULL,
    currency         CHAR(3)       NOT NULL DEFAULT 'VND',
    balance_after    NUMERIC(19,4),
    created_at       TIMESTAMPTZ   NOT NULL DEFAULT now(),
    PRIMARY KEY (id, created_at),
    CONSTRAINT uq_journal_line   UNIQUE (journal_entry_id, line_no, created_at),
    CONSTRAINT ck_line_direction CHECK (direction IN ('DEBIT', 'CREDIT')),
    CONSTRAINT ck_line_amount    CHECK (amount > 0),
    CONSTRAINT ck_line_no        CHECK (line_no > 0)
) PARTITION BY RANGE (created_at);

COMMENT ON COLUMN journal_lines.account_id IS
    'NULL = dòng này chỉ chạm GL nội bộ (tiền mặt, clearing, thu nhập phí). Quyết định DB3: không có tài khoản SYSTEM trong bảng accounts';
COMMENT ON COLUMN journal_lines.amount IS
    'LUÔN DƯƠNG. Nợ hay Có do cột direction quyết định, không dùng dấu âm — số âm trong sổ cái là nguồn gốc của những đêm mất ngủ';
COMMENT ON CONSTRAINT uq_journal_line ON journal_lines IS
    'Postgres bắt UNIQUE/PK trên bảng partition PHẢI chứa cột partition, nên có created_at ở đây. ĐẢM BẢO NÀY CHỈ TRONG PHẠM VI MỘT TRANSACTION: now() không đổi suốt transaction nên mọi dòng của một bút toán có created_at giống hệt nhau, và line_no trùng bị chặn. Transaction KHÁC insert lại line_no cũ sẽ có created_at khác và LỌT — chặn chuyện đó là việc của trg_journal_lines_immutable, không phải của ràng buộc này';

-- Partition theo tháng. Sinh sẵn ba tháng để hiểu cơ chế; sinh tự động về sau
-- là việc của job hoặc pg_partman. DEFAULT hứng dữ liệu ngoài khoảng để INSERT
-- không chết khi ai đó quên tạo partition tháng mới.
CREATE TABLE journal_lines_2026_08 PARTITION OF journal_lines
    FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE journal_lines_2026_09 PARTITION OF journal_lines
    FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE journal_lines_2026_10 PARTITION OF journal_lines
    FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE journal_lines_default PARTITION OF journal_lines DEFAULT;

CREATE INDEX idx_lines_entry   ON journal_lines (journal_entry_id);
CREATE INDEX idx_lines_account ON journal_lines (account_id, created_at DESC);
CREATE INDEX idx_lines_gl      ON journal_lines (gl_code, created_at DESC);

-- ---------------------------------------------------------------------
-- QUYẾT ĐỊNH DB2 — ràng buộc "tổng Nợ = tổng Có"
--
-- Đây là ràng buộc LIÊN HÀNG: nó nói về tập các dòng của một bút toán, không
-- nói về từng dòng. Không CHECK nào biểu diễn được (CHECK chỉ thấy một hàng).
--
-- Giải pháp: CONSTRAINT TRIGGER DEFERRABLE INITIALLY DEFERRED. Nó chạy tại
-- COMMIT chứ không tại INSERT — đúng lúc mọi dòng đã nằm trong bảng.
--
-- Trigger đặt trên journal_entries (bảng THƯỜNG) chứ không trên journal_lines
-- (bảng PARTITION) để né các giới hạn của Postgres với trigger trên bảng partition.
-- Hệ quả: một bút toán đã cân rồi mà sau đó có ai chèn thêm dòng ở transaction
-- KHÁC thì trigger không chạy lại. Đó chính là điều nguyên tắc append-only cấm.
-- ---------------------------------------------------------------------
CREATE FUNCTION core_banking.assert_journal_balanced() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
    v_lines        INT;
    v_net          NUMERIC(19,4);
    v_currencies   INT;
    v_non_postable INT;
BEGIN
    SELECT COUNT(*),
           COALESCE(SUM(CASE WHEN direction = 'DEBIT' THEN amount ELSE -amount END), 0),
           COUNT(DISTINCT currency)
      INTO v_lines, v_net, v_currencies
      FROM core_banking.journal_lines
     WHERE journal_entry_id = NEW.id;

    IF v_lines < 2 THEN
        RAISE EXCEPTION 'Bút toán % có % dòng — tối thiểu 2 (một Nợ, một Có)',
            NEW.entry_reference, v_lines;
    END IF;

    IF v_currencies > 1 THEN
        RAISE EXCEPTION 'Bút toán % trộn % loại tiền — ngoài phạm vi (không có FX)',
            NEW.entry_reference, v_currencies;
    END IF;

    IF v_net <> 0 THEN
        RAISE EXCEPTION 'Bút toán % KHÔNG CÂN: tổng Nợ - tổng Có = %',
            NEW.entry_reference, v_net;
    END IF;

    -- Không được hạch toán thẳng vào tài khoản GL TỔNG HỢP (is_postable = FALSE).
    -- Bút toán kiểu đó vẫn cân, nên nếu không chặn ở đây thì sai chỉ lộ ra ở khâu
    -- đối chiếu — lúc đó đã lẫn vào hàng nghìn bút toán đúng. FK chỉ kiểm gl_code
    -- có tồn tại, không kiểm nó có được phép hạch toán hay không.
    SELECT COUNT(*)
      INTO v_non_postable
      FROM core_banking.journal_lines l
      JOIN core_banking.gl_accounts  g ON g.gl_code = l.gl_code
     WHERE l.journal_entry_id = NEW.id
       AND NOT g.is_postable;

    IF v_non_postable > 0 THEN
        RAISE EXCEPTION 'Bút toán % có % dòng hạch toán vào GL tổng hợp (is_postable = FALSE)',
            NEW.entry_reference, v_non_postable;
    END IF;

    RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER trg_journal_balanced
    AFTER INSERT ON journal_entries
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION core_banking.assert_journal_balanced();

-- ---------------------------------------------------------------------
-- APPEND-ONLY, ÉP BẰNG DB CHỨ KHÔNG CHỈ BẰNG LỜI
--
-- Nguyên tắc số 5 ở đầu file nói sổ cái không UPDATE, không DELETE. Cho tới
-- đây đó mới chỉ là một câu văn: trg_journal_balanced chỉ chạy khi INSERT vào
-- journal_entries, nên một UPDATE lên journal_lines làm lệch bút toán đã cân
-- sẽ đi lọt hoàn toàn và không gì phát hiện được.
--
-- Và không thể thay bằng REVOKE: core_svc SỞ HỮU các bảng này, mà chủ sở hữu
-- đi xuyên qua mọi GRANT. Chỉ trigger mới chặn được.
--
-- Còn hai đường vòng mà trigger không với tới: TRUNCATE và DROP TABLE. Cả hai
-- đều cần quyền chủ sở hữu và đều là hành động có chủ ý, không phải tai nạn của
-- một câu UPDATE viết vội — chấp nhận được ở tầng này.
-- ---------------------------------------------------------------------
CREATE FUNCTION core_banking.reject_ledger_mutation() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION
        'Sổ cái là APPEND-ONLY: % lên %.% bị từ chối. Sai thì ghi bút toán ĐẢO (transaction_type = ''REVERSAL'', reversal_of_entry_id trỏ về bản gốc)',
        TG_OP, TG_TABLE_SCHEMA, TG_TABLE_NAME;
END;
$$;

CREATE TRIGGER trg_journal_entries_immutable
    BEFORE UPDATE OR DELETE ON journal_entries
    FOR EACH ROW EXECUTE FUNCTION core_banking.reject_ledger_mutation();

CREATE TRIGGER trg_journal_lines_immutable
    BEFORE UPDATE OR DELETE ON journal_lines
    FOR EACH ROW EXECUTE FUNCTION core_banking.reject_ledger_mutation();

-- Chốt số dư cuối ngày. Hai công dụng: sao kê không phải quét lại sổ cái từ đầu,
-- và job đối chiếu có mốc để so accounts.ledger_balance với tổng bút toán.
CREATE TABLE account_balance_snapshots (
    account_id      BIGINT        NOT NULL REFERENCES accounts (id),
    as_of_date      DATE          NOT NULL,
    opening_balance NUMERIC(19,4) NOT NULL,
    closing_balance NUMERIC(19,4) NOT NULL,
    total_debit     NUMERIC(19,4) NOT NULL DEFAULT 0,
    total_credit    NUMERIC(19,4) NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT now(),
    PRIMARY KEY (account_id, as_of_date),
    CONSTRAINT ck_snapshot_totals CHECK (total_debit >= 0 AND total_credit >= 0)
);

-- <<< HẾT KHỐI [5b]
```

- [ ] **Step 3: Reset DB và xác nhận partition**

```bash
cd /Users/tanvx/Dev/bank-platform && docker compose down -v && docker compose up -d postgres && sleep 8
docker compose exec -T postgres psql -U postgres -d bank -tAc \
  "SELECT count(*) FROM pg_inherits i JOIN pg_class p ON p.oid = i.inhparent WHERE p.relname = 'journal_lines'"
```

Expected: `4`.

- [ ] **Step 4: KIỂM CHỨNG DB2 — bút toán lệch phải bị từ chối tại COMMIT**

```bash
cd /Users/tanvx/Dev/bank-platform
docker compose exec -T postgres psql -U postgres -d bank -v ON_ERROR_STOP=0 <<'SQL'
BEGIN;
INSERT INTO core_banking.gl_accounts (gl_code, name, account_class, normal_balance)
VALUES ('1010', 'Tiền mặt tại quỹ', 'ASSET', 'DEBIT'),
       ('2010', 'Tiền gửi KH - thanh toán', 'LIABILITY', 'CREDIT');

INSERT INTO core_banking.journal_entries (entry_reference, transaction_type, value_date, description)
VALUES ('TEST-LECH', 'ADJUSTMENT', CURRENT_DATE, 'bút toán cố ý lệch 10');

INSERT INTO core_banking.journal_lines (journal_entry_id, line_no, gl_code, direction, amount)
SELECT id, 1, '1010', 'DEBIT',  100 FROM core_banking.journal_entries WHERE entry_reference='TEST-LECH'
UNION ALL
SELECT id, 2, '2010', 'CREDIT',  90 FROM core_banking.journal_entries WHERE entry_reference='TEST-LECH';
COMMIT;
SQL
```

Expected: `COMMIT` thất bại với `ERROR: Bút toán TEST-LECH KHÔNG CÂN: tổng Nợ - tổng Có = 10.0000`. Vì mọi thứ nằm trong một transaction, hai dòng `gl_accounts` cũng bị rollback theo.

**Nếu bước này không lỗi như mong đợi**, DB2 sai. Không đi tiếp. Ghi lại lỗi thực tế rồi chọn một trong hai đường: (a) đổi cách đặt trigger, (b) bỏ trigger và chuyển ràng buộc lên tầng application, ghi rõ vào `schema.sql` và cập nhật spec §6.2 DB2. Đây là điều spec đã báo trước là chưa xác minh.

- [ ] **Step 5: Xác nhận trigger KHÔNG từ chối bút toán cân**

```bash
cd /Users/tanvx/Dev/bank-platform
docker compose exec -T postgres psql -U postgres -d bank -v ON_ERROR_STOP=1 <<'SQL'
BEGIN;
INSERT INTO core_banking.gl_accounts (gl_code, name, account_class, normal_balance)
VALUES ('1010', 'Tiền mặt tại quỹ', 'ASSET', 'DEBIT'),
       ('2010', 'Tiền gửi KH - thanh toán', 'LIABILITY', 'CREDIT');

INSERT INTO core_banking.journal_entries (entry_reference, transaction_type, value_date, description)
VALUES ('TEST-CAN', 'OPENING', CURRENT_DATE, 'nộp tiền mặt 100');

INSERT INTO core_banking.journal_lines (journal_entry_id, line_no, gl_code, direction, amount)
SELECT id, 1, '1010', 'DEBIT',  100 FROM core_banking.journal_entries WHERE entry_reference='TEST-CAN'
UNION ALL
SELECT id, 2, '2010', 'CREDIT', 100 FROM core_banking.journal_entries WHERE entry_reference='TEST-CAN';
COMMIT;
SQL
docker compose exec -T postgres psql -U postgres -d bank -tAc \
  "SELECT count(*) FROM core_banking.journal_lines WHERE journal_entry_id = (SELECT id FROM core_banking.journal_entries WHERE entry_reference='TEST-CAN')"
```

Expected: `COMMIT` thành công, rồi in ra `2`.

- [ ] **Step 6: Xác nhận bút toán một dòng bị từ chối**

```bash
cd /Users/tanvx/Dev/bank-platform
docker compose exec -T postgres psql -U postgres -d bank -v ON_ERROR_STOP=0 <<'SQL'
BEGIN;
INSERT INTO core_banking.journal_entries (entry_reference, transaction_type, value_date)
VALUES ('TEST-MOT-DONG', 'ADJUSTMENT', CURRENT_DATE);
INSERT INTO core_banking.journal_lines (journal_entry_id, line_no, gl_code, direction, amount)
SELECT id, 1, '1010', 'DEBIT', 100 FROM core_banking.journal_entries WHERE entry_reference='TEST-MOT-DONG';
COMMIT;
SQL
```

Expected: FAIL với `Bút toán TEST-MOT-DONG có 1 dòng — tối thiểu 2`.

- [ ] **Step 6b: Kiểm chứng sổ cái thật sự append-only**

Chạy sau Step 5 (cần bút toán `TEST-CAN` đã commit):

```bash
docker compose exec -T postgres psql -U postgres -d bank -c \
  "UPDATE core_banking.journal_lines SET amount = 999 WHERE journal_entry_id =
     (SELECT id FROM core_banking.journal_entries WHERE entry_reference='TEST-CAN');"
docker compose exec -T postgres psql -U postgres -d bank -c \
  "DELETE FROM core_banking.journal_entries WHERE entry_reference='TEST-CAN';"
```

Expected: cả hai FAIL với `Sổ cái là APPEND-ONLY: UPDATE ...` và `... DELETE ...`. Đây là bằng chứng cho điều mà cho tới trước bản sửa này mới chỉ là một câu trong comment.

Lưu ý rủi ro kỹ thuật: `journal_lines` là bảng partition. Postgres chỉ hỗ trợ `BEFORE ROW` trigger trên bảng partition từ phiên bản 13; ta đang chạy 17 nên phải được. Nếu `CREATE TRIGGER trg_journal_lines_immutable` báo lỗi, **dừng lại và báo cáo** — đừng chuyển sang tạo trigger trên từng partition con, vì partition tháng mới sinh sau này sẽ không có trigger và lỗ hổng quay lại im lặng.

- [ ] **Step 6c: Kiểm chứng chặn hạch toán vào GL tổng hợp**

```bash
docker compose exec -T postgres psql -U postgres -d bank -c \
  "INSERT INTO core_banking.gl_accounts (gl_code, name, account_class, normal_balance, is_postable)
   VALUES ('1000', 'TÀI SẢN (tổng hợp)', 'ASSET', 'DEBIT', FALSE);"
docker compose exec -T postgres psql -U postgres -d bank -v ON_ERROR_STOP=0 <<'SQL'
BEGIN;
INSERT INTO core_banking.journal_entries (entry_reference, transaction_type, value_date)
VALUES ('TEST-TONGHOP', 'ADJUSTMENT', CURRENT_DATE);
INSERT INTO core_banking.journal_lines (journal_entry_id, line_no, gl_code, direction, amount)
SELECT id, 1, '1000', 'DEBIT',  100 FROM core_banking.journal_entries WHERE entry_reference='TEST-TONGHOP'
UNION ALL
SELECT id, 2, '2010', 'CREDIT', 100 FROM core_banking.journal_entries WHERE entry_reference='TEST-TONGHOP';
COMMIT;
SQL
```

Expected: `COMMIT` FAIL với `Bút toán TEST-TONGHOP có 1 dòng hạch toán vào GL tổng hợp (is_postable = FALSE)`. Bút toán này **cân** — nếu chỉ kiểm cân đối thì nó lọt.

- [ ] **Step 7: Xác nhận dòng rơi đúng partition tháng 8**

```bash
docker compose exec -T postgres psql -U postgres -d bank -tAc \
  "SELECT count(*) FROM core_banking.journal_lines_2026_08"
```

Expected: `2` (hai dòng của `TEST-CAN`). Nếu ra `0` và `journal_lines_default` có 2 dòng thì ngày hệ thống nằm ngoài khoảng 2026-08→2026-11 — ghi nhận và điều chỉnh khoảng partition cho khớp.

- [ ] **Step 8: Reset lại DB cho sạch dữ liệu thử**

```bash
cd /Users/tanvx/Dev/bank-platform && docker compose down -v && docker compose up -d postgres && sleep 8
docker compose exec -T postgres psql -U postgres -d bank -tAc "SELECT count(*) FROM core_banking.journal_entries"
```

Expected: `0`.

- [ ] **Step 9: Commit**

```bash
cd /Users/tanvx/Dev/bank-platform
git add docs/database/schema.sql
git commit -m "feat(db): core_banking phần 2 — sổ cái bút toán kép

journal_entries + journal_lines (partition theo tháng) thay cho bảng
ledger_entries phẳng. Ràng buộc tổng Nợ = tổng Có do CONSTRAINT TRIGGER
DEFERRABLE kiểm tại COMMIT — đã kiểm chứng cả trường hợp lệch, cân, và
bút toán một dòng.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 9: `core_banking` phần 3 — giao dịch, lãi/phí, hạ tầng

**Files:**
- Modify: `docs/database/schema.sql` (append khối `[5c]` vào cuối file)

**Interfaces:**
- Consumes: `accounts.id` (Task 7), `journal_entries.id` (Task 8)
- Produces: tám bảng cuối của `core_banking` — `transfers`, `external_transfers`, `transfer_limit_usage`, `interest_accruals`, `fee_charges`, `outbox`, `processed_events`, `audit_log`. Sau task này `core_banking` có đủ **15 bảng** và toàn DB có đủ **42 bảng**.

- [ ] **Step 1: Đếm bảng hiện tại để có mốc**

```bash
cd /Users/tanvx/Dev/bank-platform
docker compose exec -T postgres psql -U postgres -d bank -tAc \
  "SELECT count(*) FROM information_schema.tables WHERE table_schema='core_banking' AND table_type='BASE TABLE'"
```

Expected: `7` (4 từ Task 7 + 3 từ Task 8). Bảng partition con không tính vì `information_schema.tables` chỉ liệt kê `journal_lines` cha... **nếu ra `11` thì partition con ĐANG được đếm** — dùng truy vấn dưới đây làm chuẩn cho mọi lần đếm về sau:

```bash
docker compose exec -T postgres psql -U postgres -d bank -tAc \
  "SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
   WHERE n.nspname='core_banking' AND c.relkind IN ('r','p')
     AND c.oid NOT IN (SELECT inhrelid FROM pg_inherits)"
```

Expected: `7`. Truy vấn này loại partition con (chúng có mặt trong `pg_inherits`) và giữ lại bảng cha `journal_lines` (`relkind='p'`). **Dùng đúng truy vấn này ở mọi bước đếm bảng còn lại của plan.**

- [ ] **Step 2: Append khối `[5c]` vào cuối `docs/database/schema.sql`**

```sql

-- ---------------------------------------------------------------------
-- [5c] Giao dịch, lãi, phí, hạ tầng
-- ---------------------------------------------------------------------

CREATE TABLE transfers (
    id                         BIGSERIAL     PRIMARY KEY,
    transfer_reference         VARCHAR(40)   NOT NULL,
    idempotency_key            VARCHAR(64)   NOT NULL,
    transfer_type              VARCHAR(20)   NOT NULL,
    source_account_id          BIGINT        NOT NULL REFERENCES accounts (id),
    destination_account_id     BIGINT        REFERENCES accounts (id),
    destination_account_number VARCHAR(34),
    destination_bank_code      VARCHAR(20),
    amount                     NUMERIC(19,4) NOT NULL,
    currency                   CHAR(3)       NOT NULL DEFAULT 'VND',
    fee_amount                 NUMERIC(19,4) NOT NULL DEFAULT 0,
    channel                    VARCHAR(20)   NOT NULL,
    description                VARCHAR(500),
    status                     VARCHAR(20)   NOT NULL DEFAULT 'PENDING',
    journal_entry_id           BIGINT        REFERENCES journal_entries (id),
    initiated_by_user_id       BIGINT,
    version                    INT           NOT NULL DEFAULT 0,
    created_at                 TIMESTAMPTZ   NOT NULL DEFAULT now(),
    completed_at               TIMESTAMPTZ,
    updated_at                 TIMESTAMPTZ   NOT NULL DEFAULT now(),
    -- Constraint ĐẶT TÊN TƯỜNG MINH. Bản cũ để CHECK inline, Postgres tự đặt
    -- tên 'transfers_status_check', và đến migration sau mới phát hiện mình
    -- không biết nó tên gì. Bài học đó nằm ở đây.
    CONSTRAINT uq_transfers_reference   UNIQUE (transfer_reference),
    -- UNIQUE trên idempotency_key LÀ toàn bộ cơ chế chống trùng lệnh. Đặt tên
    -- tường minh vì đây là ràng buộc mà code sẽ bắt lỗi theo tên khi client retry.
    CONSTRAINT uq_transfers_idempotency UNIQUE (idempotency_key),
    CONSTRAINT ck_transfers_status  CHECK (status IN ('PENDING', 'PENDING_EXTERNAL', 'COMPLETED', 'FAILED', 'REVERSED')),
    CONSTRAINT ck_transfers_type    CHECK (transfer_type IN ('INTERNAL', 'EXTERNAL')),
    CONSTRAINT ck_transfers_channel CHECK (channel IN ('INTERNET', 'MOBILE', 'ATM', 'BRANCH', 'API')),
    CONSTRAINT ck_transfers_amount  CHECK (amount > 0 AND fee_amount >= 0),
    -- Chuyển nội bộ phải có tài khoản đích trong hệ thống; chuyển liên ngân hàng
    -- phải có số tài khoản + mã ngân hàng đối tác. Mỗi nhánh vừa BẮT BUỘC trường
    -- của loại mình, vừa CẤM trường của loại kia — nếu chỉ bắt buộc mà không cấm
    -- thì một dòng EXTERNAL vẫn mang được destination_account_id, và nó trông như
    -- cả hai loại giao dịch cùng lúc.
    CONSTRAINT ck_transfers_target  CHECK (
           (transfer_type = 'INTERNAL'
                AND destination_account_id     IS NOT NULL
                AND destination_account_number IS NULL
                AND destination_bank_code      IS NULL)
        OR (transfer_type = 'EXTERNAL'
                AND destination_account_number IS NOT NULL
                AND destination_bank_code      IS NOT NULL
                AND destination_account_id     IS NULL)),
    CONSTRAINT ck_transfers_self    CHECK (destination_account_id IS NULL OR destination_account_id <> source_account_id),
    -- COMPLETED nghĩa là tiền ĐÃ dịch chuyển. Không có journal_entry_id thì không
    -- có bút toán nào phía sau — tức là báo tiền đã chuyển mà sổ cái không biết.
    -- Cùng khuôn với ck_accrual_posted và ck_fee_charge_posted bên dưới.
    CONSTRAINT ck_transfers_completed_posted CHECK (
        status <> 'COMPLETED' OR journal_entry_id IS NOT NULL)
);
COMMENT ON COLUMN transfers.idempotency_key IS
    'Client gửi lại cùng key = cùng một lệnh. UNIQUE ở đây đảm bảo AN TOÀN TIỀN BẠC (không bao giờ trừ hai lần) mà không cần code kiểm tra trước. Nhưng nó CHƯA làm endpoint idempotent: lần gọi lại nhận unique_violation chứ không nhận lại kết quả cũ. Muốn idempotent thật, tầng ứng dụng phải bắt vi phạm đó rồi tra và trả về chính transfer đã tạo';
COMMENT ON COLUMN transfers.journal_entry_id IS
    'NULL khi chưa hạch toán (PENDING). Bút toán là sự thật; transfers chỉ là ý định';

-- Saga chuyển tiền liên ngân hàng.
-- PENDING_EXTERNAL = đã treo tiền nguồn, đang chờ đối tác xác nhận.
-- Thất bại hoặc quá hạn -> bút toán ĐẢO, không bao giờ xóa bút toán gốc.
CREATE TABLE external_transfers (
    id                      BIGSERIAL   PRIMARY KEY,
    transfer_id             BIGINT      NOT NULL REFERENCES transfers (id),
    partner_code            VARCHAR(20) NOT NULL,
    partner_ref             VARCHAR(100),
    saga_state              VARCHAR(30) NOT NULL DEFAULT 'HOLD_PLACED',
    partner_idempotency_key VARCHAR(64) NOT NULL,
    deadline_at             TIMESTAMPTZ NOT NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- Một transfer chỉ có tối đa một saga liên ngân hàng.
    CONSTRAINT uq_ext_transfer     UNIQUE (transfer_id),
    CONSTRAINT uq_ext_idempotency  UNIQUE (partner_idempotency_key),
    CONSTRAINT ck_ext_saga_state CHECK (saga_state IN (
        'HOLD_PLACED',        -- đã treo tiền nguồn, chưa gọi đối tác
        'PARTNER_REQUESTED',  -- đã gọi, đang chờ trả lời
        'PARTNER_CONFIRMED',  -- xong -> transfer COMPLETED
        'PARTNER_REJECTED',   -- bị từ chối -> đảo bút toán
        'TIMED_OUT',          -- quá hạn -> đảo bút toán
        'COMPENSATED'))       -- bút toán đảo đã ghi
);
COMMENT ON COLUMN external_transfers.partner_idempotency_key IS
    'Idempotency với ĐỐI TÁC (khác idempotency_key với client): retry gọi partner dùng lại đúng key này';
COMMENT ON COLUMN external_transfers.saga_state IS
    'BẤT BIẾN DO ỨNG DỤNG GIỮ: saga_state và transfers.status là hai máy trạng thái mô tả cùng một sự việc và phải khớp nhau (PARTNER_CONFIRMED <-> COMPLETED, PARTNER_REJECTED/TIMED_OUT -> COMPENSATED <-> REVERSED). CHECK không với sang bảng khác được nên DB không chặn nổi việc chúng trôi lệch — cập nhật cả hai trong CÙNG transaction';

-- Velocity check: đã dùng bao nhiêu hạn mức trong cửa sổ nào.
-- Khuôn hạn mức nằm ở product.product_limits; bảng này là mức đã tiêu.
CREATE TABLE transfer_limit_usage (
    id           BIGSERIAL     PRIMARY KEY,
    account_id   BIGINT        NOT NULL REFERENCES accounts (id),
    limit_code   VARCHAR(30)   NOT NULL,
    window_start DATE          NOT NULL,
    used_amount  NUMERIC(19,4) NOT NULL DEFAULT 0,
    used_count   INT           NOT NULL DEFAULT 0,
    updated_at   TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT uq_limit_usage UNIQUE (account_id, limit_code, window_start),
    CONSTRAINT ck_limit_usage CHECK (used_amount >= 0 AND used_count >= 0)
);
COMMENT ON COLUMN transfer_limit_usage.window_start IS
    'Ngày đầu cửa sổ: hạn mức ngày thì là chính ngày đó, hạn mức tháng thì là ngày 01';
COMMENT ON COLUMN transfer_limit_usage.limit_code IS
    'Khớp product.product_limits.limit_code nhưng KHÔNG có FK (xuyên schema). Cái giá của ranh giới service: giá trị ở đây là chuỗi tự do, gõ sai hoặc đổi tên bên product mà không đồng bộ sẽ làm hạn mức âm thầm không được đếm. Đối chiếu định kỳ là việc của ứng dụng';

-- Dự thu lãi HẰNG NGÀY, hạch toán định kỳ. UNIQUE(account_id, accrual_date)
-- là toàn bộ cơ chế chống chạy EOD hai lần — không cần cờ "đã chạy chưa".
CREATE TABLE interest_accruals (
    id               BIGSERIAL     PRIMARY KEY,
    account_id       BIGINT        NOT NULL REFERENCES accounts (id),
    accrual_date     DATE          NOT NULL,
    principal_base   NUMERIC(19,4) NOT NULL,
    annual_rate      NUMERIC(9,6)  NOT NULL,
    accrued_amount   NUMERIC(19,4) NOT NULL,
    posted           BOOLEAN       NOT NULL DEFAULT FALSE,
    journal_entry_id BIGINT        REFERENCES journal_entries (id),
    created_at       TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT uq_accrual        UNIQUE (account_id, accrual_date),
    CONSTRAINT ck_accrual_posted CHECK (NOT posted OR journal_entry_id IS NOT NULL),
    CONSTRAINT ck_accrual_rate   CHECK (annual_rate >= 0 AND annual_rate < 1)
);
COMMENT ON COLUMN interest_accruals.posted IS
    'FALSE = đã tính, chưa hạch toán. Lãi dồn từng ngày nhưng chỉ nhập sổ khi trả — đó là lý do tách bảng này khỏi journal_lines';

CREATE TABLE fee_charges (
    id               BIGSERIAL     PRIMARY KEY,
    account_id       BIGINT        NOT NULL REFERENCES accounts (id),
    fee_code         VARCHAR(30)   NOT NULL,
    source_type      VARCHAR(30),
    source_id        VARCHAR(100),
    amount           NUMERIC(19,4) NOT NULL,
    currency         CHAR(3)       NOT NULL DEFAULT 'VND',
    status           VARCHAR(20)   NOT NULL DEFAULT 'PENDING',
    journal_entry_id BIGINT        REFERENCES journal_entries (id),
    charged_at       TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT ck_fee_charge_status CHECK (status IN ('PENDING', 'POSTED', 'WAIVED')),
    CONSTRAINT ck_fee_charge_amount CHECK (amount >= 0),
    CONSTRAINT ck_fee_charge_posted CHECK (status <> 'POSTED' OR journal_entry_id IS NOT NULL)
);
COMMENT ON COLUMN fee_charges.status IS
    'WAIVED = miễn phí nhưng VẪN LƯU VẾT đã từng phát sinh. Xóa dòng đi là mất khả năng trả lời "sao tháng này không thu phí khách này"';

CREATE TABLE outbox (
    id             BIGSERIAL    PRIMARY KEY,
    aggregate_type VARCHAR(50)  NOT NULL,
    aggregate_id   VARCHAR(100) NOT NULL,
    event_type     VARCHAR(100) NOT NULL,
    payload        JSONB        NOT NULL,
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    published_at   TIMESTAMPTZ
);
COMMENT ON TABLE outbox IS
    'Phát transfer.completed.v1, transfer.reversed.v1... Độc lập với outbox của customer và product';

-- core_banking cũng là CONSUMER: nghe customer.status.changed.v1 để phong tỏa
-- tài khoản khi khách hàng bị đình chỉ.
CREATE TABLE processed_events (
    event_id     VARCHAR(64) PRIMARY KEY,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Append-only cho mọi thao tác ghi của core.
CREATE TABLE audit_log (
    id            BIGSERIAL    PRIMARY KEY,
    actor_user_id BIGINT,
    action        VARCHAR(50)  NOT NULL,
    resource_type VARCHAR(50)  NOT NULL,
    resource_id   VARCHAR(100) NOT NULL,
    detail        JSONB,
    at            TIMESTAMPTZ  NOT NULL DEFAULT now()
);
COMMENT ON COLUMN audit_log.actor_user_id IS
    'NULL = hệ thống hoặc batch job, không phải người';

CREATE INDEX idx_transfers_source   ON transfers (source_account_id, created_at DESC);
CREATE INDEX idx_transfers_dest     ON transfers (destination_account_id, created_at DESC);
CREATE INDEX idx_transfers_pending  ON transfers (created_at) WHERE status IN ('PENDING', 'PENDING_EXTERNAL');
-- Job quét saga treo: chỉ index những dòng chưa kết thúc.
CREATE INDEX idx_ext_active         ON external_transfers (deadline_at)
    WHERE saga_state IN ('HOLD_PLACED', 'PARTNER_REQUESTED');
CREATE INDEX idx_accrual_unposted   ON interest_accruals (accrual_date) WHERE NOT posted;
CREATE INDEX idx_fee_account        ON fee_charges (account_id, charged_at DESC);
CREATE INDEX idx_fee_pending        ON fee_charges (charged_at) WHERE status = 'PENDING';
CREATE INDEX idx_core_outbox_unpub  ON outbox (created_at) WHERE published_at IS NULL;
CREATE INDEX idx_audit_resource     ON audit_log (resource_type, resource_id, at DESC);
CREATE INDEX idx_audit_actor        ON audit_log (actor_user_id, at DESC);

RESET ROLE;
SET search_path = public;

-- <<< HẾT KHỐI [5c] — kết thúc schema core_banking
```

- [ ] **Step 3: Reset DB và đếm bảng từng schema**

```bash
cd /Users/tanvx/Dev/bank-platform && docker compose down -v && docker compose up -d postgres && sleep 8
docker compose exec -T postgres psql -U postgres -d bank -c "
SELECT n.nspname AS schema, count(*) AS bang
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname IN ('auth','customer','product','core_banking','notification')
  AND c.relkind IN ('r','p')
  AND c.oid NOT IN (SELECT inhrelid FROM pg_inherits)
GROUP BY n.nspname ORDER BY n.nspname;"
```

Expected:

```
    schema    | bang
--------------+------
 auth         |    4
 core_banking |   15
 customer     |   10
 notification |    6
 product      |    7
```

- [ ] **Step 4: Xác nhận tổng 42 bảng**

```bash
docker compose exec -T postgres psql -U postgres -d bank -tAc "
SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname IN ('auth','customer','product','core_banking','notification')
  AND c.relkind IN ('r','p') AND c.oid NOT IN (SELECT inhrelid FROM pg_inherits)"
```

Expected: `42`.

- [ ] **Step 4b: Kiểm chứng hai ràng buộc vừa siết**

```bash
docker compose exec -T postgres psql -U postgres -d bank -c "
INSERT INTO core_banking.transfers
  (transfer_reference, idempotency_key, transfer_type, source_account_id,
   destination_account_number, destination_bank_code, destination_account_id, amount, channel)
VALUES ('T-LAI', 'K-LAI', 'EXTERNAL', 1, '9999', 'MOCKBANK', 2, 1000, 'API');"
```

Expected: FAIL với `violates check constraint "ck_transfers_target"` — dòng EXTERNAL mang thêm `destination_account_id` là dòng trông như cả hai loại.

```bash
docker compose exec -T postgres psql -U postgres -d bank -c "
INSERT INTO core_banking.transfers
  (transfer_reference, idempotency_key, transfer_type, source_account_id,
   destination_account_number, destination_bank_code, amount, channel, status)
VALUES ('T-XONG', 'K-XONG', 'EXTERNAL', 1, '9999', 'MOCKBANK', 1000, 'API', 'COMPLETED');"
```

Expected: FAIL với `violates check constraint "ck_transfers_completed_posted"` — báo COMPLETED mà không có `journal_entry_id` là báo tiền đã chuyển trong khi sổ cái không biết.

Hai lệnh này chỉ cần constraint từ chối; không cần `accounts` id 1/2 tồn tại, vì CHECK được đánh giá trước FK.

- [ ] **Step 5: Xác nhận không có FK nào xuyên schema**

```bash
docker compose exec -T postgres psql -U postgres -d bank -tAc "
SELECT count(*) FROM pg_constraint con
JOIN pg_class src ON src.oid = con.conrelid
JOIN pg_class tgt ON tgt.oid = con.confrelid
WHERE con.contype = 'f' AND src.relnamespace <> tgt.relnamespace"
```

Expected: `0`. Đây là kiểm tra máy móc cho nguyên tắc số 1 — nếu ra khác 0, có ai đó đã tạo FK xuyên schema.

- [ ] **Step 6: Commit**

```bash
cd /Users/tanvx/Dev/bank-platform
git add docs/database/schema.sql
git commit -m "feat(db): core_banking phần 3 — giao dịch, lãi, phí, hạ tầng

transfers với idempotency key, saga liên ngân hàng, velocity check,
dự thu lãi hằng ngày, phí có trạng thái WAIVED, outbox + audit.
core_banking đủ 15 bảng, toàn DB đủ 42 bảng, 0 FK xuyên schema.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 10: Seed data và ghi chú vận hành

**Files:**
- Modify: `docs/database/schema.sql` (append khối `[7]` và `[8]` vào cuối file)

**Interfaces:**
- Consumes: `core_banking.gl_accounts`, `product.products` và các bảng con của nó
- Produces: 9 dòng `gl_accounts`; 3 dòng `products` (`CA_STANDARD`, `SA_STANDARD`, `TD_12M`) kèm lãi suất, phí, hạn mức, GL mapping. Không seed khách hàng, không seed tài khoản.

- [ ] **Step 1: Xác nhận chưa có seed**

```bash
cd /Users/tanvx/Dev/bank-platform
docker compose exec -T postgres psql -U postgres -d bank -tAc \
  "SELECT count(*) FROM core_banking.gl_accounts"
docker compose exec -T postgres psql -U postgres -d bank -tAc \
  "SELECT count(*) FROM product.products"
```

Expected: `0` rồi `0`.

- [ ] **Step 2: Append khối `[7]` và `[8]` vào cuối `docs/database/schema.sql`**

```sql

-- =====================================================================
-- [7] SEED DATA
--     Chỉ dữ liệu THAM CHIẾU: hệ thống tài khoản và danh mục sản phẩm.
--     KHÔNG seed khách hàng, KHÔNG seed tài khoản — hai thứ đó là dữ liệu
--     nghiệp vụ, phải đi qua đúng luồng mở hồ sơ và mở tài khoản.
-- =====================================================================

SET ROLE core_svc;
SET search_path = core_banking;

-- Chart of accounts tối thiểu. Quy ước đánh số:
--   1xxx TÀI SẢN · 2xxx NỢ PHẢI TRẢ · 3xxx VỐN · 4xxx THU NHẬP · 5xxx CHI PHÍ
-- Tiền gửi của khách hàng là NỢ PHẢI TRẢ của ngân hàng — đây là chỗ người mới
-- hay nhầm nhất: khách gửi tiền vào thì ngân hàng NỢ khách số tiền đó.
INSERT INTO gl_accounts (gl_code, name, account_class, normal_balance, is_postable) VALUES
    ('1010', 'Tiền mặt tại quỹ',                  'ASSET',     'DEBIT',  TRUE),
    ('1900', 'Tài khoản trung gian thanh toán',   'ASSET',     'DEBIT',  TRUE),
    ('2010', 'Tiền gửi khách hàng - thanh toán',  'LIABILITY', 'CREDIT', TRUE),
    ('2020', 'Tiền gửi khách hàng - tiết kiệm',   'LIABILITY', 'CREDIT', TRUE),
    ('2110', 'Lãi phải trả khách hàng',           'LIABILITY', 'CREDIT', TRUE),
    ('3010', 'Vốn điều lệ',                       'EQUITY',    'CREDIT', TRUE),
    ('3020', 'Lợi nhuận giữ lại',                 'EQUITY',    'CREDIT', TRUE),
    ('4010', 'Thu nhập từ phí dịch vụ',           'INCOME',    'CREDIT', TRUE),
    ('5010', 'Chi phí lãi tiền gửi',              'EXPENSE',   'DEBIT',  TRUE);

COMMENT ON TABLE gl_accounts IS
    '1900 là tài khoản trung gian: tiền đã rời tài khoản nguồn nhưng chưa tới đích (chuyển liên ngân hàng đang chờ đối tác). Số dư của nó phải về 0 sau mỗi phiên đối chiếu';

RESET ROLE;
SET search_path = public;

SET ROLE product_svc;
SET search_path = product;

INSERT INTO products (product_code, name, category, currency, status, description) VALUES
    ('CA_STANDARD', 'Tài khoản thanh toán chuẩn',      'CURRENT_ACCOUNT', 'VND', 'ACTIVE', 'Tài khoản dùng hằng ngày, lãi suất không kỳ hạn'),
    ('SA_STANDARD', 'Tài khoản tiết kiệm không kỳ hạn', 'SAVINGS_ACCOUNT', 'VND', 'ACTIVE', 'Rút bất cứ lúc nào, lãi bậc thang theo số dư'),
    ('TD_12M',      'Tiền gửi có kỳ hạn 12 tháng',      'TERM_DEPOSIT',    'VND', 'ACTIVE', 'Rút trước hạn hưởng lãi không kỳ hạn');

-- Lãi suất. CA phẳng; SA bậc thang theo số dư; TD theo kỳ hạn.
INSERT INTO product_interest_rates (product_id, tier_from, tier_to, term_months, annual_rate)
SELECT id, 0, NULL, NULL, 0.001000 FROM products WHERE product_code = 'CA_STANDARD';

INSERT INTO product_interest_rates (product_id, tier_from, tier_to, term_months, annual_rate)
-- NULL::INT ở nhánh ĐẦU của chuỗi UNION là bắt buộc: Postgres phân giải kiểu theo
-- cặp, một cột toàn NULL không có kiểu sẽ thành text rồi không ép ngầm sang INT được.
SELECT id, 0, 100000000, NULL::INT, 0.005000 FROM products WHERE product_code = 'SA_STANDARD'
UNION ALL
SELECT id, 100000000, NULL, NULL, 0.008000 FROM products WHERE product_code = 'SA_STANDARD';

INSERT INTO product_interest_rates (product_id, tier_from, tier_to, term_months, annual_rate)
SELECT id, 0, NULL, 12, 0.055000 FROM products WHERE product_code = 'TD_12M';

-- Biểu phí của tài khoản thanh toán.
INSERT INTO product_fees (product_id, fee_code, fee_type, amount, percent, min_amount, max_amount, charge_event)
SELECT id, 'MAINT_MONTHLY', 'FLAT',    11000, NULL::NUMERIC, NULL::NUMERIC, NULL::NUMERIC, 'MONTHLY_MAINTENANCE' FROM products WHERE product_code = 'CA_STANDARD'
UNION ALL
SELECT id, 'TRF_INTERNAL',  'FLAT',        0, NULL,    NULL,    NULL, 'INTERNAL_TRANSFER'   FROM products WHERE product_code = 'CA_STANDARD'
UNION ALL
SELECT id, 'TRF_EXTERNAL',  'PERCENT',  NULL, 0.000500, 5500, 1100000, 'EXTERNAL_TRANSFER'  FROM products WHERE product_code = 'CA_STANDARD';

-- Hạn mức chuyển tiền của tài khoản thanh toán.
INSERT INTO product_limits (product_id, limit_code, scope, channel, max_amount, max_count)
SELECT id, 'TRF_PER_TXN', 'PER_TRANSACTION', 'ANY',      500000000, NULL FROM products WHERE product_code = 'CA_STANDARD'
UNION ALL
SELECT id, 'TRF_PER_DAY', 'PER_DAY',         'ANY',     1000000000,   20 FROM products WHERE product_code = 'CA_STANDARD'
UNION ALL
SELECT id, 'TRF_PER_TXN', 'PER_TRANSACTION', 'MOBILE',   100000000, NULL FROM products WHERE product_code = 'CA_STANDARD';

-- Điều kiện mở tài khoản.
INSERT INTO product_eligibility_rules (product_id, rule_type, operator, rule_value)
SELECT id, 'MIN_AGE',       'GTE', '18' FROM products WHERE product_code = 'CA_STANDARD'
UNION ALL
SELECT id, 'MIN_KYC_LEVEL', 'GTE', '1'  FROM products WHERE product_code = 'CA_STANDARD'
UNION ALL
SELECT id, 'MIN_KYC_LEVEL', 'GTE', '2'  FROM products WHERE product_code = 'TD_12M';

-- CẦU NỐI sang sổ cái: mỗi sản phẩm hạch toán vào GL nào.
INSERT INTO product_gl_mappings (product_id, purpose, gl_code)
SELECT id, 'PRINCIPAL',        '2010' FROM products WHERE product_code = 'CA_STANDARD'
UNION ALL SELECT id, 'INTEREST_PAYABLE', '2110' FROM products WHERE product_code = 'CA_STANDARD'
UNION ALL SELECT id, 'INTEREST_EXPENSE', '5010' FROM products WHERE product_code = 'CA_STANDARD'
UNION ALL SELECT id, 'FEE_INCOME',       '4010' FROM products WHERE product_code = 'CA_STANDARD'
UNION ALL SELECT id, 'PRINCIPAL',        '2020' FROM products WHERE product_code = 'SA_STANDARD'
UNION ALL SELECT id, 'INTEREST_PAYABLE', '2110' FROM products WHERE product_code = 'SA_STANDARD'
UNION ALL SELECT id, 'INTEREST_EXPENSE', '5010' FROM products WHERE product_code = 'SA_STANDARD'
UNION ALL SELECT id, 'FEE_INCOME',       '4010' FROM products WHERE product_code = 'SA_STANDARD'
UNION ALL SELECT id, 'PRINCIPAL',        '2020' FROM products WHERE product_code = 'TD_12M'
UNION ALL SELECT id, 'INTEREST_PAYABLE', '2110' FROM products WHERE product_code = 'TD_12M'
UNION ALL SELECT id, 'INTEREST_EXPENSE', '5010' FROM products WHERE product_code = 'TD_12M'
UNION ALL SELECT id, 'FEE_INCOME',       '4010' FROM products WHERE product_code = 'TD_12M';

RESET ROLE;
SET search_path = public;


-- =====================================================================
-- [8] GHI CHÚ VẬN HÀNH
--
--  TẠO PARTITION THÁNG MỚI. journal_lines có partition tới hết 2026-10 và một
--  DEFAULT hứng phần còn lại. DEFAULT là lưới an toàn, không phải chỗ để dữ liệu
--  ở lâu: nó không được prune nên mọi truy vấn đều phải quét nó.
--    CREATE TABLE core_banking.journal_lines_2026_11
--        PARTITION OF core_banking.journal_lines
--        FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
--  Nếu DEFAULT đã có dữ liệu thuộc khoảng đó, lệnh trên sẽ bị từ chối — phải
--  tách dữ liệu ra trước. Đó là lý do tạo partition TRƯỚC khi cần, bằng job.
--
--  XÓA DỮ LIỆU CŨ. DROP một partition tháng = lưu trữ tức thì, thay cho DELETE
--  hàng triệu dòng. Đây là lợi ích lớn nhất của partition ở bảng sổ cái.
--
--  ĐÁNH INDEX THEO BẰNG CHỨNG. Các index trong file này phục vụ những truy vấn
--  đã biết chắc sẽ có (sao kê theo tài khoản, quét outbox chưa publish, quét
--  saga treo). Index tiếp theo chỉ thêm sau khi EXPLAIN trên dữ liệu thật cho
--  thấy cần — index thừa làm chậm mọi lệnh ghi trên bảng nóng.
--
--  ĐỐI CHIẾU. Hai phép kiểm phải luôn đúng, chạy định kỳ:
--    1. Với mỗi bút toán: SUM(DEBIT) = SUM(CREDIT). Trigger đã đảm bảo lúc ghi,
--       nhưng vẫn nên quét lại để phát hiện can thiệp trực tiếp vào DB.
--    2. Với mỗi GL: SUM(số dư các accounts trỏ vào gl_code đó) = số dư GL tính
--       từ journal_lines. Lệch nghĩa là accounts.ledger_balance đã trôi khỏi sổ cái.
--
--  KHI BẬT FLYWAY. Cắt phần schema của service từ file này thành
--  V<yyyyMMddHHmm>__<mô_tả>.sql trong db/migration/, rồi đổi
--  spring.flyway.enabled thành true. Với database đã có sẵn bảng do file này
--  tạo, cần thêm spring.flyway.baseline-on-migrate=true cho lần chạy đầu —
--  hoặc sạch hơn: docker compose down -v rồi để Flyway dựng lại từ đầu.
-- =====================================================================
```

- [ ] **Step 3: Reset DB và xác nhận seed**

```bash
cd /Users/tanvx/Dev/bank-platform && docker compose down -v && docker compose up -d postgres && sleep 10
docker compose exec -T postgres psql -U postgres -d bank -tAc "SELECT count(*) FROM core_banking.gl_accounts"
docker compose exec -T postgres psql -U postgres -d bank -tAc "SELECT count(*) FROM product.products"
docker compose exec -T postgres psql -U postgres -d bank -tAc "SELECT count(*) FROM product.product_gl_mappings"
```

Expected: `9`, `3`, `12`.

- [ ] **Step 4: Xác nhận mọi `gl_code` trong product mapping đều tồn tại thật**

Đây là chỗ nguy hiểm của tham chiếu mềm: không có FK nên không ai chặn gõ sai mã GL. Kiểm tra thủ công:

```bash
docker compose exec -T postgres psql -U postgres -d bank -tAc "
SELECT count(*) FROM product.product_gl_mappings m
WHERE NOT EXISTS (SELECT 1 FROM core_banking.gl_accounts g WHERE g.gl_code = m.gl_code)"
```

Expected: `0`.

- [ ] **Step 5: Xác nhận toàn bộ file chạy sạch, không warning**

```bash
cd /Users/tanvx/Dev/bank-platform && docker compose logs postgres 2>&1 | grep -iE "error|fatal|warning" | grep -v "listening on" || echo "SẠCH"
```

Expected: chỉ còn hai cảnh báo hạ tầng của Postgres lúc khởi tạo (locale và trust-auth) — chúng xuất hiện trước khi `schema.sql` chạy và có ở mọi container. Điều cần chứng minh là **không có dòng `ERROR` hay `FATAL` nào**. Literal `SẠCH` không đạt được trong môi trường này.

- [ ] **Step 6: Commit**

```bash
cd /Users/tanvx/Dev/bank-platform
git add docs/database/schema.sql
git commit -m "feat(db): seed chart of accounts, 3 sản phẩm mẫu, ghi chú vận hành

9 GL account theo quy ước 1xxx-5xxx, 3 sản phẩm kèm lãi suất bậc thang,
biểu phí, hạn mức và GL mapping. Khối [8] ghi cách tạo partition tháng
mới, hai phép đối chiếu bắt buộc, và cách bật Flyway sau này.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 11: Module `bank-common`

**Files:**
- Create: `bank-common/pom.xml`
- Create: `bank-common/README.md`
- Create: `bank-common/src/main/java/io/bankplatform/common/{type,event/customer,event/account,event/transfer,constant}/.gitkeep`
- Modify: `pom.xml` (thêm `<module>bank-common</module>`)

**Interfaces:**
- Consumes: root POM từ Task 1 (đã khai `bank-common` trong `dependencyManagement`)
- Produces: artifact `io.bankplatform:bank-common:0.1.0-SNAPSHOT` (jar rỗng). Các service khai `<dependency><groupId>io.bankplatform</groupId><artifactId>bank-common</artifactId></dependency>` **không kèm version**.

- [ ] **Step 1: Xác nhận module chưa có trong reactor**

```bash
cd /Users/tanvx/Dev/bank-platform && mvn -B -q -P'!with-libs' clean install 2>&1 | tail -5
ls bank-common 2>&1
```

Expected: build thành công nhưng `ls` báo `No such file or directory`.

- [ ] **Step 2: Tạo cây thư mục rỗng**

```bash
cd /Users/tanvx/Dev/bank-platform
for d in type event/customer event/account event/transfer constant; do
  mkdir -p "bank-common/src/main/java/io/bankplatform/common/$d"
  touch "bank-common/src/main/java/io/bankplatform/common/$d/.gitkeep"
done
```

- [ ] **Step 3: Viết `bank-common/pom.xml`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <parent>
    <groupId>io.bankplatform</groupId>
    <artifactId>bank-platform</artifactId>
    <version>0.1.0-SNAPSHOT</version>
    <relativePath>../pom.xml</relativePath>
  </parent>

  <artifactId>bank-common</artifactId>
  <name>bank-platform :: bank-common</name>
  <description>
    Value object nghiệp vụ, hợp đồng event, và hằng số dùng chung giữa các service.
    KHÔNG có dependency: đây là Java thuần, không Spring, không JPA, không Jackson.
    Xem README.md để biết cái gì được phép nằm ở đây và cái gì không.
  </description>

  <!--
    Cố ý KHÔNG có <dependencies>. Thêm dependency vào module này là thêm nó vào
    cả sáu service cùng lúc — cân nhắc thật kỹ trước khi làm.
  -->
</project>
```

- [ ] **Step 4: Viết `bank-common/README.md`**

```markdown
# bank-common

Những thứ **cả nhiều service đều cần** và **javalibs không thể chứa** (vì javalibs là hạ tầng chung cho mọi hệ sinh thái, nó không biết gì về ngân hàng).

## Được phép nằm ở đây

| Package | Nội dung | Ví dụ |
|---|---|---|
| `type/` | Value object nghiệp vụ, immutable, `record` hoặc final class | `Money`, `Currency`, `AccountNumber`, `CustomerNumber`, `LedgerDirection` |
| `event/<domain>/` | Hợp đồng event — `record` payload mà publisher và consumer phải hiểu giống nhau | `TransferCompletedV1`, `CustomerKycApprovedV1` |
| `constant/` | Tên topic Kafka, prefix mã lỗi, tên header | `Topics`, `ErrorCodePrefix`, `HeaderNames` |

## KHÔNG được nằm ở đây

1. **Tiện ích chuỗi/ngày/kiểm tra tham số.** Đã có `javalibs-internal`: `Strings`, `Dates`, `Checks`, `Ids`. Viết lại là tạo hai nguồn sự thật.
2. **JPA entity.** Entity thuộc về service sở hữu bảng đó. Chia sẻ entity là chia sẻ schema, và schema là thứ mỗi service phải được tự do đổi.
3. **REST DTO / client DTO.** Request/response là hợp đồng của một API cụ thể, thuộc `api/dto` của service đó.
4. **Spring bean, annotation Spring, `@Component`, `@ConfigurationProperties`.** Module này không có dependency Spring và phải giữ như vậy.

## Vì sao siết chặt như vậy

Mỗi class ở đây là một điểm coupling: sửa nó là sáu service phải build lại. Module `common` không có kỷ luật sẽ thành bãi rác trong vài tháng, và khi đó không ai dám xóa gì khỏi nó nữa.

Quy tắc thực dụng: **nếu chỉ hai service dùng, đừng đưa vào đây** — copy sang cả hai. Chỉ thăng lên `bank-common` khi cái thứ ba cần tới.

## Versioning hợp đồng event

Tên class mang số phiên bản (`TransferCompletedV1`). Đổi kiểu phá vỡ tương thích thì **thêm `V2`**, giữ `V1` cho tới khi mọi consumer chuyển xong. Sửa tại chỗ `V1` là làm hỏng consumer đang chạy.
```

- [ ] **Step 5: Thêm module vào root `pom.xml`**

Thay khối `<modules>` rỗng trong `pom.xml` bằng:

```xml
  <modules>
    <module>bank-common</module>
  </modules>
```

- [ ] **Step 6: Build và xác nhận artifact ra lò**

```bash
cd /Users/tanvx/Dev/bank-platform && mvn -B -P'!with-libs' clean install
ls ~/.m2/repository/io/bankplatform/bank-common/0.1.0-SNAPSHOT/*.jar
```

Expected: `BUILD SUCCESS` (có warning `JAR will be empty` — đúng như thiết kế, chưa có class nào), và `ls` in ra file jar.

- [ ] **Step 7: Xác nhận `.gitkeep` không lọt vào jar**

```bash
cd /Users/tanvx/Dev/bank-platform && unzip -l bank-common/target/bank-common-0.1.0-SNAPSHOT.jar | grep -c gitkeep || echo "SẠCH"
```

Expected: `SẠCH` — Maven không copy file phi-Java từ `src/main/java`.

- [ ] **Step 8: Commit**

```bash
cd /Users/tanvx/Dev/bank-platform
git add pom.xml bank-common
git commit -m "feat: module bank-common với cấu trúc package rỗng

Value object nghiệp vụ + hợp đồng event + hằng số. Không dependency,
không Spring. README ghi rõ 4 điều cấm và quy tắc chỉ thăng lên common
khi service thứ ba cần tới.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 12: `auth-service` — khuôn Mức B

**Files:**
- Create: `services/auth-service/pom.xml`
- Create: `services/auth-service/README.md`
- Create: `services/auth-service/ERROR-CODES.md`
- Create: `services/auth-service/Dockerfile`
- Create: `services/auth-service/src/main/java/io/bankplatform/auth/AuthApplication.java`
- Create: `services/auth-service/src/main/java/io/bankplatform/auth/{web/dto,service,repository,model,config}/.gitkeep`
- Create: `services/auth-service/src/main/resources/application.yml`
- Create: `services/auth-service/src/main/resources/application-local.yml`
- Create: `services/auth-service/src/main/resources/db/migration/.gitkeep`
- Create: `services/auth-service/src/test/resources/application-test.yml`
- Modify: `pom.xml` (thêm `<module>services/auth-service</module>`)

**Interfaces:**
- Consumes: `io.bankplatform:bank-common` (Task 11), BOM `javalibs-dependencies` (Task 1), schema `auth` (Task 3)
- Produces: **khuôn Mức B** mà Task 13 sao lại cho `product-service` và `notification-service`. Main class `io.bankplatform.auth.AuthApplication`. Cổng 8081.

- [ ] **Step 1: Xác nhận module chưa tồn tại**

```bash
cd /Users/tanvx/Dev/bank-platform && ls services/auth-service 2>&1
```

Expected: `No such file or directory`.

- [ ] **Step 2: Tạo cây thư mục**

```bash
cd /Users/tanvx/Dev/bank-platform
for d in web/dto service repository model config; do
  mkdir -p "services/auth-service/src/main/java/io/bankplatform/auth/$d"
  touch "services/auth-service/src/main/java/io/bankplatform/auth/$d/.gitkeep"
done
mkdir -p services/auth-service/src/main/resources/db/migration
touch    services/auth-service/src/main/resources/db/migration/.gitkeep
mkdir -p services/auth-service/src/test/resources
```

- [ ] **Step 3: Viết `services/auth-service/pom.xml`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <parent>
    <groupId>io.bankplatform</groupId>
    <artifactId>bank-platform</artifactId>
    <version>0.1.0-SNAPSHOT</version>
    <relativePath>../../pom.xml</relativePath>
  </parent>

  <artifactId>auth-service</artifactId>
  <name>bank-platform :: auth-service</name>
  <description>Định danh và phát hành token. Không biết gì về tài khoản ngân hàng.</description>

  <dependencies>
    <dependency>
      <groupId>io.bankplatform</groupId>
      <artifactId>bank-common</artifactId>
    </dependency>

    <!-- Bộ nền javalibs: mọi service nghiệp vụ đều có đúng năm starter này -->
    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-web-spring-boot-starter</artifactId>
    </dependency>
    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-security-spring-boot-starter</artifactId>
    </dependency>
    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-openapi-spring-boot-starter</artifactId>
    </dependency>
    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-observability-spring-boot-starter</artifactId>
    </dependency>
    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-persistence-spring-boot-starter</artifactId>
    </dependency>

    <!-- Riêng auth: phát hành/rotate token, và blacklist revoke qua Redis -->
    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-security-issuer</artifactId>
    </dependency>
    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-cache-spring-boot-starter</artifactId>
    </dependency>

    <!--
      BẮT BUỘC, kể cả khi spring.flyway.enabled=false.
      javalibs-persistence-spring-boot-starter kéo flyway-core KHÔNG optional, nên
      @ConditionalOnClass(Flyway.class) của JavalibsFlywayAutoConfiguration luôn thỏa.
      Nhưng autoconfigure lại để spring-boot-flyway ở scope optional, mà Boot 4.1 đã
      dời FlywayConfigurationCustomizer vào đúng jar đó -> NoClassDefFoundError lúc
      Spring soi @Bean của lớp cấu hình.

      Lưu ý hai cờ KHÁC NHAU: spring.flyway.enabled gate FlywayAutoConfiguration của
      Spring Boot; JavalibsFlywayAutoConfiguration bị gate bởi cờ riêng
      javalibs.persistence.flyway.enabled (mặc định true). Tắt cờ thứ hai có thể cũng
      né được lỗi — nhưng ta CỐ Ý không làm vậy: để nó bật thì lưới an toàn Flyway của
      javalibs (clean-disabled, kiểm quy ước đặt tên migration) đã sẵn sàng, và tự động
      có hiệu lực ngay khi bật spring.flyway.enabled ở task sau. Tắt đi thì phải nhớ
      bật lại — thứ rất dễ quên trên một nền tảng ngân hàng.
    -->
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-flyway</artifactId>
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
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-test</artifactId>
      <scope>test</scope>
    </dependency>
    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-security-test</artifactId>
      <scope>test</scope>
    </dependency>
  </dependencies>

  <build>
    <plugins>
      <plugin>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-maven-plugin</artifactId>
      </plugin>
    </plugins>
  </build>
</project>
```

- [ ] **Step 4: Viết main class**

`services/auth-service/src/main/java/io/bankplatform/auth/AuthApplication.java`:

```java
package io.bankplatform.auth;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Không cần {@code @Import} hay {@code @ComponentScan} cho javalibs:
 * mỗi starter tự đăng ký auto-configuration qua file
 * {@code META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports}.
 */
@SpringBootApplication
public class AuthApplication {

    public static void main(String[] args) {
        SpringApplication.run(AuthApplication.class, args);
    }
}
```

- [ ] **Step 5: Viết `application.yml`**

```yaml
spring:
  application:
    name: auth-service

  datasource:
    url: jdbc:postgresql://${DB_HOST:localhost}:${DB_PORT:5432}/${DB_NAME:bank}
    username: ${DB_USER:auth_svc}
    password: ${DB_PASSWORD:auth_dev}

  jpa:
    hibernate:
      # Schema do docs/database/schema.sql dựng. Hibernate chỉ được KIỂM TRA,
      # không bao giờ được sinh hay sửa DDL.
      ddl-auto: validate
    properties:
      hibernate:
        default_schema: auth

  flyway:
    # TẮT có chủ đích. Schema đã do docs/database/schema.sql dựng qua
    # docker-entrypoint-initdb.d, còn db/migration/ thì đang rỗng. Bật Flyway
    # lúc này trên một schema đã có bảng mà chưa có bảng lịch sử sẽ làm service
    # chết ngay khi khởi động.
    # Bật lên khi cắt migration đầu tiên từ schema.sql (xem khối [8] của file đó).
    enabled: false
    schemas: auth
    default-schema: auth
    clean-disabled: true

  data:
    redis:
      host: ${REDIS_HOST:localhost}
      port: ${REDIS_PORT:6379}

server:
  port: 8081

javalibs:
  security:
    jwt:
      secret: ${JWT_SECRET}

management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
```

- [ ] **Step 6: Viết `application-local.yml`**

```yaml
# Profile local: chạy với hạ tầng của compose.yaml.
#   mvn -pl services/auth-service spring-boot:run -Dspring-boot.run.profiles=local
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/bank

javalibs:
  security:
    jwt:
      # Secret dev, chỉ dùng ở máy local. Production bơm qua biến môi trường.
      secret: local-dev-only-secret-please-change-me-at-least-32-bytes

logging:
  level:
    io.bankplatform: DEBUG
```

- [ ] **Step 7: Viết `src/test/resources/application-test.yml`**

```yaml
# Profile test được BaseIntegrationTest của javalibs-test kích hoạt sẵn.
javalibs:
  security:
    jwt:
      secret: test-only-secret-please-change-me-at-least-32-bytes

spring:
  flyway:
    enabled: false
```

- [ ] **Step 8: Viết `Dockerfile`**

```dockerfile
# Build context là thư mục service này. Jar phải được build TRƯỚC:
#   mvn -pl services/auth-service -am -DskipTests package
#   docker build -t bank/auth-service:0.1.0 services/auth-service
FROM eclipse-temurin:21-jre
WORKDIR /app
ARG JAR_FILE=target/auth-service-0.1.0-SNAPSHOT.jar
COPY ${JAR_FILE} app.jar
EXPOSE 8081
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
```

- [ ] **Step 9: Viết `README.md`**

```markdown
# auth-service

Định danh, xác thực, phát hành token. **Không biết gì về tài khoản ngân hàng** — các service khác trỏ vào `auth.users`, service này không trỏ ra ngoài.

- **Cổng:** 8081
- **Schema:** `auth` · **DB user:** `auth_svc`
- **Mức cấu trúc: B (layered gọn).** Chiều phụ thuộc: `web → service → repository/model`; `config` đứng ngoài.

## Vì sao Mức B chứ không phải DDD

`javalibs-security` đã lo phần khó: parse token, filter, `UserContext`, `@RequireRole`, rotation + reuse detection của refresh token. Phần còn lại của service này là CRUD người dùng và vai trò — trả giá DDD ở đây là trả giá cho một bài toán không có.

Nếu về sau phần nghiệp vụ dày lên (chính sách mật khẩu, MFA, khóa tài khoản theo quy tắc), nâng lên Mức A là bình thường và **không phải đổi starter nào**.

## Quy tắc tối thiểu vẫn phải giữ

- Controller không chứa nghiệp vụ.
- Exception ném ra là `ApiException` / `ResourceNotFoundException` của javalibs — **đừng tự viết `GlobalExceptionHandler`**, javalibs đã có.
- Mọi mã lỗi khai trong `ERROR-CODES.md` và class `AuthErrors`.
- `config/` lý tưởng là **rỗng**. Có bean trong đó nghĩa là service này lệch chuẩn ở chỗ nào đó — reviewer sẽ hỏi.

## Chạy local

```bash
docker compose up -d postgres redis
mvn -pl services/auth-service -am spring-boot:run -Dspring-boot.run.profiles=local
```

Kiểm tra: <http://localhost:8081/actuator/health> và <http://localhost:8081/swagger-ui.html>

## Migration

`src/main/resources/db/migration/` đang **rỗng** và `spring.flyway.enabled=false`. Schema do `docs/database/schema.sql` dựng. Khi bắt tay vào service này: cắt khối `[2]` của file đó thành migration đầu tiên rồi bật Flyway.
```

- [ ] **Step 10: Viết `ERROR-CODES.md`**

```markdown
# Mã lỗi — auth-service

Prefix: `ERR-AUTH-xxx`. Mỗi mã khai một lần trong class `io.bankplatform.auth.web.AuthErrors` bằng `BusinessErrorCode.of(...)`, và javalibs tự đưa chúng vào OpenAPI docs.

Mã là **hợp đồng với frontend**: đã phát hành thì không đổi ý nghĩa, không tái sử dụng cho lỗi khác. Hết ý nghĩa thì đánh dấu deprecated, không xóa.

| Mã | HTTP | Ý nghĩa |
|---|---|---|
| _(chưa có)_ | | |
```

- [ ] **Step 11: Thêm module vào root `pom.xml`**

```xml
  <modules>
    <module>bank-common</module>
    <module>services/auth-service</module>
  </modules>
```

- [ ] **Step 12: Build**

```bash
cd /Users/tanvx/Dev/bank-platform && mvn -B -P'!with-libs' clean install
```

Expected: `BUILD SUCCESS`, có `auth-service` trong reactor summary.

- [ ] **Step 13: Chạy service và kiểm tra health**

```bash
cd /Users/tanvx/Dev/bank-platform && docker compose up -d postgres redis && sleep 8
mvn -pl services/auth-service spring-boot:run -Dspring-boot.run.profiles=local > /tmp/auth-run.log 2>&1 &
sleep 45
curl -s http://localhost:8081/actuator/health
```

Expected: `{"status":"UP"...}`. Nếu không lên, đọc `/tmp/auth-run.log`.

- [ ] **Step 14: Kiểm tra Swagger UI**

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8081/swagger-ui/index.html
curl -s http://localhost:8081/v3/api-docs | head -c 300
```

Expected: `200`, và JSON OpenAPI có `"openapi":"3...`.

- [ ] **Step 15: Dừng service**

```bash
pkill -f "spring-boot:run" || true
```

- [ ] **Step 16: Commit**

```bash
cd /Users/tanvx/Dev/bank-platform
git add pom.xml services/auth-service
git commit -m "feat: auth-service — khuôn Mức B (layered)

pom với bộ nền 5 starter javalibs + security-issuer + cache, main class,
cấu trúc package rỗng web/service/repository/model/config, application.yml
với flyway tắt có chủ đích, Dockerfile, README ghi rõ vì sao chọn Mức B.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 13: `product-service` và `notification-service` — áp khuôn Mức B

**Files:**
- Create: `services/product-service/**` và `services/notification-service/**` (cùng bộ file như Task 12)
- Modify: `pom.xml`

**Interfaces:**
- Consumes: khuôn Mức B từ Task 12
- Produces: `io.bankplatform.product.ProductApplication` (cổng 8083, schema `product`), `io.bankplatform.notification.NotificationApplication` (cổng 8085, schema `notification`).

Hai service này giống `auth-service` về cấu trúc. Khác nhau ở đúng bốn chỗ: `artifactId`, package, cổng, và starter riêng. Bảng dưới là toàn bộ khác biệt — mọi thứ khác sao chép nguyên từ Task 12 rồi thay thế theo bảng.

| | `product-service` | `notification-service` |
|---|---|---|
| `artifactId` | `product-service` | `notification-service` |
| package | `io.bankplatform.product` | `io.bankplatform.notification` |
| main class | `ProductApplication` | `NotificationApplication` |
| `server.port` | 8083 | 8085 |
| schema / DB user / mật khẩu | `product` / `product_svc` / `product_dev` | `notification` / `noti_svc` / `noti_dev` |
| starter riêng | `javalibs-cache-spring-boot-starter`, `javalibs-search-spring-boot-starter` | `javalibs-datahub-spring-boot-starter`, `javalibs-resilience-spring-boot-starter` |
| bỏ khỏi pom | `javalibs-security-issuer` | `javalibs-security-issuer`, `javalibs-cache-spring-boot-starter` |
| `spring.data.redis` | giữ (dùng cache catalog) | **bỏ** (không dùng Redis) |
| prefix mã lỗi | `ERR-PROD-xxx` | `ERR-NOTI-xxx` |
| class mã lỗi | `io.bankplatform.product.web.ProductErrors` | `io.bankplatform.notification.web.NotificationErrors` |

- [ ] **Step 1: Xác nhận hai module chưa tồn tại**

```bash
cd /Users/tanvx/Dev/bank-platform && ls services/product-service services/notification-service 2>&1
```

Expected: `No such file or directory` cho cả hai.

- [ ] **Step 2: Tạo cây thư mục cho cả hai**

```bash
cd /Users/tanvx/Dev/bank-platform
for svc in product notification; do
  for d in web/dto service repository model config; do
    mkdir -p "services/${svc}-service/src/main/java/io/bankplatform/${svc}/$d"
    touch    "services/${svc}-service/src/main/java/io/bankplatform/${svc}/$d/.gitkeep"
  done
  mkdir -p "services/${svc}-service/src/main/resources/db/migration"
  touch    "services/${svc}-service/src/main/resources/db/migration/.gitkeep"
  mkdir -p "services/${svc}-service/src/test/resources"
done
```

- [ ] **Step 3: Viết `services/product-service/pom.xml`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <parent>
    <groupId>io.bankplatform</groupId>
    <artifactId>bank-platform</artifactId>
    <version>0.1.0-SNAPSHOT</version>
    <relativePath>../../pom.xml</relativePath>
  </parent>

  <artifactId>product-service</artifactId>
  <name>bank-platform :: product-service</name>
  <description>Danh mục sản phẩm: lãi suất, biểu phí, hạn mức, điều kiện mở, ánh xạ GL.</description>

  <dependencies>
    <dependency>
      <groupId>io.bankplatform</groupId>
      <artifactId>bank-common</artifactId>
    </dependency>

    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-web-spring-boot-starter</artifactId>
    </dependency>
    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-security-spring-boot-starter</artifactId>
    </dependency>
    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-openapi-spring-boot-starter</artifactId>
    </dependency>
    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-observability-spring-boot-starter</artifactId>
    </dependency>
    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-persistence-spring-boot-starter</artifactId>
    </dependency>

    <!-- Catalog đọc nhiều ghi ít: cache đáng giá. search cho lọc động danh mục. -->
    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-cache-spring-boot-starter</artifactId>
    </dependency>
    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-search-spring-boot-starter</artifactId>
    </dependency>

    <!--
      BẮT BUỘC, kể cả khi spring.flyway.enabled=false.
      javalibs-persistence-spring-boot-starter kéo flyway-core KHÔNG optional, nên
      @ConditionalOnClass(Flyway.class) của JavalibsFlywayAutoConfiguration luôn thỏa.
      Nhưng autoconfigure lại để spring-boot-flyway ở scope optional, mà Boot 4.1 đã
      dời FlywayConfigurationCustomizer vào đúng jar đó -> NoClassDefFoundError lúc
      Spring soi @Bean của lớp cấu hình.

      Lưu ý hai cờ KHÁC NHAU: spring.flyway.enabled gate FlywayAutoConfiguration của
      Spring Boot; JavalibsFlywayAutoConfiguration bị gate bởi cờ riêng
      javalibs.persistence.flyway.enabled (mặc định true). Tắt cờ thứ hai có thể cũng
      né được lỗi — nhưng ta CỐ Ý không làm vậy: để nó bật thì lưới an toàn Flyway của
      javalibs (clean-disabled, kiểm quy ước đặt tên migration) đã sẵn sàng, và tự động
      có hiệu lực ngay khi bật spring.flyway.enabled ở task sau. Tắt đi thì phải nhớ
      bật lại — thứ rất dễ quên trên một nền tảng ngân hàng.
    -->
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-flyway</artifactId>
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
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-test</artifactId>
      <scope>test</scope>
    </dependency>
    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-security-test</artifactId>
      <scope>test</scope>
    </dependency>
  </dependencies>

  <build>
    <plugins>
      <plugin>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-maven-plugin</artifactId>
      </plugin>
    </plugins>
  </build>
</project>
```

- [ ] **Step 4: Viết `services/notification-service/pom.xml`**

Giống Step 3 với ba thay đổi: `<artifactId>notification-service</artifactId>`, `<name>bank-platform :: notification-service</name>`, `<description>Nghe event và gửi thông báo qua Telegram/Email/Webhook.</description>`; và thay khối hai starter riêng bằng:

```xml
    <!-- Idempotent consumer + EventEnvelope. resilience để retry gửi webhook
         và ngắt mạch khi endpoint của user chết. -->
    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-datahub-spring-boot-starter</artifactId>
    </dependency>
    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-resilience-spring-boot-starter</artifactId>
    </dependency>

    <!--
      BẮT BUỘC đi kèm javalibs-datahub-spring-boot-starter. Cùng một lớp lỗi với
      spring-boot-flyway bên dưới, nhưng nguy hiểm hơn vì nó IM LẶNG.

      Đừng chẩn đoán nhầm: starter kéo org.springframework.kafka:spring-kafka KHÔNG
      optional, nên client Kafka luôn có mặt. Thứ thiếu là
      org.springframework.boot:spring-boot-kafka — Boot 4.1 tách
      KafkaAutoConfiguration sang jar riêng, javalibs-datahub-spring-boot-autoconfigure
      để jar đó ở scope optional, mà DatahubKafkaAutoConfiguration lại tham chiếu
      class ấy CỨNG trong annotation: @AutoConfiguration(after = KafkaAutoConfiguration.class).

      Thiếu Flyway thì service chết ngay lúc khởi động nên không ai bỏ sót được.
      Thiếu jar này thì service vẫn UP, /actuator/health vẫn xanh, chỉ có một dòng
      WARN "Failed to introspect meta-annotation @AutoConfiguration ...
      TypeNotPresentException" rồi Spring bỏ qua TOÀN BỘ DatahubKafkaAutoConfiguration.
      EventPublisher qua Kafka không bao giờ được tạo, và event lặng lẽ không đi đâu.
      Một event không phát mà không ai báo lỗi là kiểu hỏng tệ nhất trên nền tảng
      ngân hàng — tiền đã ghi sổ nhưng phía nghe không bao giờ biết.
    -->
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-kafka</artifactId>
    </dependency>
```

- [ ] **Step 5: Viết hai main class**

`services/product-service/src/main/java/io/bankplatform/product/ProductApplication.java`:

```java
package io.bankplatform.product;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cache.annotation.EnableCaching;

/** {@code @EnableCaching} vì service này dùng javalibs-cache cho catalog. */
@SpringBootApplication
@EnableCaching
public class ProductApplication {

    public static void main(String[] args) {
        SpringApplication.run(ProductApplication.class, args);
    }
}
```

`services/notification-service/src/main/java/io/bankplatform/notification/NotificationApplication.java`:

```java
package io.bankplatform.notification;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class NotificationApplication {

    public static void main(String[] args) {
        SpringApplication.run(NotificationApplication.class, args);
    }
}
```

- [ ] **Step 6: Viết `services/product-service/src/main/resources/application.yml`**

```yaml
spring:
  application:
    name: product-service

  datasource:
    url: jdbc:postgresql://${DB_HOST:localhost}:${DB_PORT:5432}/${DB_NAME:bank}
    username: ${DB_USER:product_svc}
    password: ${DB_PASSWORD:product_dev}

  jpa:
    hibernate:
      ddl-auto: validate
    properties:
      hibernate:
        default_schema: product

  flyway:
    # TẮT có chủ đích — xem services/auth-service/src/main/resources/application.yml
    enabled: false
    schemas: product
    default-schema: product
    clean-disabled: true

  data:
    redis:
      host: ${REDIS_HOST:localhost}
      port: ${REDIS_PORT:6379}

server:
  port: 8083

javalibs:
  security:
    jwt:
      secret: ${JWT_SECRET}

management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
```

- [ ] **Step 7: Viết `services/notification-service/src/main/resources/application.yml`**

```yaml
spring:
  application:
    name: notification-service

  datasource:
    url: jdbc:postgresql://${DB_HOST:localhost}:${DB_PORT:5432}/${DB_NAME:bank}
    username: ${DB_USER:noti_svc}
    password: ${DB_PASSWORD:noti_dev}

  jpa:
    hibernate:
      ddl-auto: validate
    properties:
      hibernate:
        default_schema: notification

  flyway:
    # TẮT có chủ đích — xem services/auth-service/src/main/resources/application.yml
    enabled: false
    schemas: notification
    default-schema: notification
    clean-disabled: true

  kafka:
    bootstrap-servers: ${KAFKA_BOOTSTRAP:localhost:9092}
    consumer:
      group-id: notification-service
      auto-offset-reset: earliest

server:
  port: 8085

javalibs:
  security:
    jwt:
      secret: ${JWT_SECRET}

management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
```

- [ ] **Step 8: Viết `application-local.yml` và `application-test.yml` cho cả hai**

`application-local.yml` (giống nhau cho cả hai, chỉ đổi comment lệnh chạy):

```yaml
# Profile local: chạy với hạ tầng của compose.yaml.
#   mvn -pl services/product-service spring-boot:run -Dspring-boot.run.profiles=local
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/bank

javalibs:
  security:
    jwt:
      secret: local-dev-only-secret-please-change-me-at-least-32-bytes

logging:
  level:
    io.bankplatform: DEBUG
```

`src/test/resources/application-test.yml` (giống hệt nhau):

```yaml
javalibs:
  security:
    jwt:
      secret: test-only-secret-please-change-me-at-least-32-bytes

spring:
  flyway:
    enabled: false
```

- [ ] **Step 9: Viết `Dockerfile` cho cả hai**

`services/product-service/Dockerfile`:

```dockerfile
# Build context là thư mục service này. Jar phải được build TRƯỚC:
#   mvn -pl services/product-service -am -DskipTests package
#   docker build -t bank/product-service:0.1.0 services/product-service
FROM eclipse-temurin:21-jre
WORKDIR /app
ARG JAR_FILE=target/product-service-0.1.0-SNAPSHOT.jar
COPY ${JAR_FILE} app.jar
EXPOSE 8083
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
```

`services/notification-service/Dockerfile`: giống hệt, thay `product-service` → `notification-service` và `EXPOSE 8083` → `EXPOSE 8085`.

- [ ] **Step 10: Viết `README.md` và `ERROR-CODES.md` cho cả hai**

`services/product-service/README.md`:

```markdown
# product-service

Danh mục sản phẩm: lãi suất bậc thang, biểu phí, hạn mức, điều kiện mở, và **ánh xạ sản phẩm → tài khoản sổ cái**.

- **Cổng:** 8083
- **Schema:** `product` · **DB user:** `product_svc`
- **Mức cấu trúc: B (layered gọn).** Chiều phụ thuộc: `web → service → repository/model`.

## Vì sao Mức B

Service này gần như thuần đọc: 7 bảng, phần lớn truy vấn là "cho tôi biểu phí/lãi suất/hạn mức đang hiệu lực của sản phẩm X tại ngày Y". Không có aggregate nào có invariant phức tạp cần bảo vệ.

## Nguyên tắc dữ liệu bắt buộc giữ

Mọi bảng đều có `effective_from` / `effective_to`. **Đổi biểu phí là THÊM DÒNG, không sửa dòng cũ.** Sửa tại chỗ làm sao kê kỳ trước tính lại ra số khác — và đó là loại lỗi không ai phát hiện cho tới lúc khách hàng khiếu nại.

## Trách nhiệm không hiển nhiên

`product_gl_mappings` quyết định mỗi sản phẩm hạch toán vào GL nào. `core-banking-service` đọc bảng này qua API để biết ghi bút toán vào đâu. Đổi mapping của một sản phẩm đang có tài khoản chạy là việc phải có quy trình, không phải một lệnh UPDATE.

## Chạy local

```bash
docker compose up -d postgres redis
mvn -pl services/product-service -am spring-boot:run -Dspring-boot.run.profiles=local
```

## Migration

`db/migration/` rỗng, `spring.flyway.enabled=false`. Schema do `docs/database/schema.sql` khối `[4]` dựng.
```

`services/notification-service/README.md`:

```markdown
# notification-service

Nghe event, gửi thông báo qua Telegram / Email / Webhook, ghi lại mọi lần thử.

- **Cổng:** 8085
- **Schema:** `notification` · **DB user:** `noti_svc`
- **Mức cấu trúc: B (layered gọn).**

## Nguyên tắc: service này CHỈ NGHE

Mọi dữ liệu cần để soạn thông báo phải nằm trong payload của event (event-carried state). **Không gọi ngược lại service khác để hỏi thêm** — làm vậy là biến một hệ bất đồng bộ thành một chuỗi phụ thuộc đồng bộ, và khi service kia chết thì thông báo cũng chết theo.

## Idempotent consumer là bắt buộc

Kafka giao at-least-once. `INSERT` vào `processed_events` phải nằm **cùng transaction** với việc tạo notification; trùng `event_id` nghĩa là đã xử lý, bỏ qua message. "Không báo hai lần" là em ruột của "không trừ tiền hai lần".

## Bề mặt tấn công cần nhớ

`webhook_endpoints.url` do người dùng nhập — đây là bề mặt **SSRF** chính của cả hệ thống. Trước khi gọi phải chặn địa chỉ nội bộ (loopback, link-local, dải riêng), và chặn ở tầng resolve IP chứ không chỉ ở chuỗi URL.

## Chạy local

```bash
docker compose up -d postgres kafka
mvn -pl services/notification-service -am spring-boot:run -Dspring-boot.run.profiles=local
```

## Migration

`db/migration/` rỗng, `spring.flyway.enabled=false`. Schema do `docs/database/schema.sql` khối `[6]` dựng.
```

`services/product-service/ERROR-CODES.md`:

```markdown
# Mã lỗi — product-service

Prefix: `ERR-PROD-xxx`. Khai trong `io.bankplatform.product.web.ProductErrors` bằng `BusinessErrorCode.of(...)`; javalibs tự đưa vào OpenAPI docs.

Mã là **hợp đồng với frontend**: đã phát hành thì không đổi ý nghĩa, không tái sử dụng cho lỗi khác. Hết dùng thì đánh dấu deprecated, không xóa.

| Mã | HTTP | Ý nghĩa |
|---|---|---|
| _(chưa có)_ | | |
```

`services/notification-service/ERROR-CODES.md`: giống hệt trên, thay `product-service` → `notification-service`, `ERR-PROD-xxx` → `ERR-NOTI-xxx`, và `ProductErrors` → `io.bankplatform.notification.web.NotificationErrors`.

- [ ] **Step 11: Thêm hai module vào root `pom.xml`**

```xml
  <modules>
    <module>bank-common</module>
    <module>services/auth-service</module>
    <module>services/product-service</module>
    <module>services/notification-service</module>
  </modules>
```

- [ ] **Step 12: Build**

```bash
cd /Users/tanvx/Dev/bank-platform && mvn -B -P'!with-libs' clean install
```

Expected: `BUILD SUCCESS`, reactor có đủ 4 module con.

- [ ] **Step 13: Chạy cả hai và kiểm tra health**

```bash
cd /Users/tanvx/Dev/bank-platform && docker compose up -d && sleep 15
mvn -pl services/product-service spring-boot:run -Dspring-boot.run.profiles=local > /tmp/product-run.log 2>&1 &
mvn -pl services/notification-service spring-boot:run -Dspring-boot.run.profiles=local > /tmp/noti-run.log 2>&1 &
sleep 50
curl -s http://localhost:8083/actuator/health; echo
curl -s http://localhost:8085/actuator/health; echo
pkill -f "spring-boot:run" || true
```

Expected: cả hai trả `{"status":"UP"...}`.

- [ ] **Step 14: Commit**

```bash
cd /Users/tanvx/Dev/bank-platform
git add pom.xml services/product-service services/notification-service
git commit -m "feat: product-service và notification-service (Mức B)

Áp khuôn của auth-service. product thêm cache + search cho catalog;
notification thêm datahub (idempotent consumer) + resilience (retry
webhook). README của notification ghi rõ SSRF là bề mặt tấn công chính.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 14: `core-banking-service` — Mức A chia theo aggregate

**Files:**
- Create: `services/core-banking-service/pom.xml`, `README.md`, `ERROR-CODES.md`, `Dockerfile`
- Create: `services/core-banking-service/src/main/java/io/bankplatform/corebanking/CoreBankingApplication.java`
- Create: 18 thư mục rỗng dưới `io/bankplatform/corebanking/` (danh sách ở Step 2)
- Create: `src/main/resources/{application.yml,application-local.yml,db/migration/.gitkeep}`
- Create: `src/test/java/io/bankplatform/corebanking/{domain,application,api}/.gitkeep`, `src/test/resources/application-test.yml`
- Modify: `pom.xml`

**Interfaces:**
- Consumes: `bank-common` (Task 11), schema `core_banking` (Task 7–10)
- Produces: `io.bankplatform.corebanking.CoreBankingApplication`, cổng 8084. Đây là service duy nhất áp quy tắc "≥3 aggregate thì chia `domain/` và `application/` theo aggregate trước, theo loại sau".

- [ ] **Step 1: Xác nhận module chưa tồn tại**

```bash
cd /Users/tanvx/Dev/bank-platform && ls services/core-banking-service 2>&1
```

Expected: `No such file or directory`.

- [ ] **Step 2: Tạo cây thư mục**

```bash
cd /Users/tanvx/Dev/bank-platform
BASE=services/core-banking-service/src/main/java/io/bankplatform/corebanking

for d in \
  api/dto \
  application/account/command application/account/query \
  application/ledger/command  application/ledger/query \
  application/transfer/command application/transfer/query \
  application/event \
  domain/account/model  domain/account/rule  domain/account/event \
  domain/ledger/model   domain/ledger/rule   domain/ledger/event \
  domain/transfer/model domain/transfer/rule domain/transfer/event \
  domain/shared \
  infrastructure/persistence/account infrastructure/persistence/ledger infrastructure/persistence/transfer \
  infrastructure/messaging infrastructure/client \
  config
do
  mkdir -p "$BASE/$d" && touch "$BASE/$d/.gitkeep"
done

mkdir -p services/core-banking-service/src/main/resources/db/migration
touch    services/core-banking-service/src/main/resources/db/migration/.gitkeep
for d in domain application api; do
  mkdir -p "services/core-banking-service/src/test/java/io/bankplatform/corebanking/$d"
  touch    "services/core-banking-service/src/test/java/io/bankplatform/corebanking/$d/.gitkeep"
done
mkdir -p services/core-banking-service/src/test/resources
```

- [ ] **Step 3: Xác nhận cây thư mục đúng hình dạng**

```bash
cd /Users/tanvx/Dev/bank-platform
find services/core-banking-service/src/main/java -type d | sed 's|.*corebanking/||' | grep -v corebanking | sort
```

Expected: đúng 25 dòng, gồm `api`, `api/dto`, `application`, `application/account`, `application/account/command`, … `config`.

- [ ] **Step 4: Viết `services/core-banking-service/pom.xml`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <parent>
    <groupId>io.bankplatform</groupId>
    <artifactId>bank-platform</artifactId>
    <version>0.1.0-SNAPSHOT</version>
    <relativePath>../../pom.xml</relativePath>
  </parent>

  <artifactId>core-banking-service</artifactId>
  <name>bank-platform :: core-banking-service</name>
  <description>Sổ cái bút toán kép, tài khoản, hold, chuyển tiền, lãi và phí.</description>

  <dependencies>
    <dependency>
      <groupId>io.bankplatform</groupId>
      <artifactId>bank-common</artifactId>
    </dependency>

    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-web-spring-boot-starter</artifactId>
    </dependency>
    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-security-spring-boot-starter</artifactId>
    </dependency>
    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-openapi-spring-boot-starter</artifactId>
    </dependency>
    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-observability-spring-boot-starter</artifactId>
    </dependency>
    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-persistence-spring-boot-starter</artifactId>
    </dependency>

    <!-- Mức A: Command/Query bus + AggregateRoot, ValueObject, BusinessRule -->
    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-cqrs-spring-boot-starter</artifactId>
    </dependency>
    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-ddd-spring</artifactId>
    </dependency>

    <!-- Outbox: event ghi cùng transaction với bút toán, publisher tách rời -->
    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-datahub-spring-boot-starter</artifactId>
    </dependency>
    <!--
      BẮT BUỘC đi kèm javalibs-datahub-spring-boot-starter. Cùng một lớp lỗi với
      spring-boot-flyway bên dưới, nhưng nguy hiểm hơn vì nó IM LẶNG.

      Đừng chẩn đoán nhầm: starter kéo org.springframework.kafka:spring-kafka KHÔNG
      optional, nên client Kafka luôn có mặt. Thứ thiếu là
      org.springframework.boot:spring-boot-kafka — Boot 4.1 tách
      KafkaAutoConfiguration sang jar riêng, javalibs-datahub-spring-boot-autoconfigure
      để jar đó ở scope optional, mà DatahubKafkaAutoConfiguration lại tham chiếu
      class ấy CỨNG trong annotation: @AutoConfiguration(after = KafkaAutoConfiguration.class).

      Thiếu Flyway thì service chết ngay lúc khởi động nên không ai bỏ sót được.
      Thiếu jar này thì service vẫn UP, /actuator/health vẫn xanh, chỉ có một dòng
      WARN "Failed to introspect meta-annotation @AutoConfiguration ...
      TypeNotPresentException" rồi Spring bỏ qua TOÀN BỘ DatahubKafkaAutoConfiguration.
      EventPublisher qua Kafka không bao giờ được tạo, và event lặng lẽ không đi đâu.
      Riêng service này outbox mang bút toán đã ghi sổ: publisher chết câm nghĩa là
      sổ cái đúng nhưng cả hệ còn lại không bao giờ biết giao dịch đã xảy ra.
    -->
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-kafka</artifactId>
    </dependency>
    <!-- Circuit breaker khi gọi ngân hàng đối tác: chặn cascading failure -->
    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-resilience-spring-boot-starter</artifactId>
    </dependency>
    <!-- Lọc động sao kê / danh sách giao dịch -->
    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-search-spring-boot-starter</artifactId>
    </dependency>

    <!--
      BẮT BUỘC, kể cả khi spring.flyway.enabled=false.
      javalibs-persistence-spring-boot-starter kéo flyway-core KHÔNG optional, nên
      @ConditionalOnClass(Flyway.class) của JavalibsFlywayAutoConfiguration luôn thỏa.
      Nhưng autoconfigure lại để spring-boot-flyway ở scope optional, mà Boot 4.1 đã
      dời FlywayConfigurationCustomizer vào đúng jar đó -> NoClassDefFoundError lúc
      Spring soi @Bean của lớp cấu hình.

      Lưu ý hai cờ KHÁC NHAU: spring.flyway.enabled gate FlywayAutoConfiguration của
      Spring Boot; JavalibsFlywayAutoConfiguration bị gate bởi cờ riêng
      javalibs.persistence.flyway.enabled (mặc định true). Tắt cờ thứ hai có thể cũng
      né được lỗi — nhưng ta CỐ Ý không làm vậy: để nó bật thì lưới an toàn Flyway của
      javalibs (clean-disabled, kiểm quy ước đặt tên migration) đã sẵn sàng, và tự động
      có hiệu lực ngay khi bật spring.flyway.enabled ở task sau. Tắt đi thì phải nhớ
      bật lại — thứ rất dễ quên trên một nền tảng ngân hàng.
    -->
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-flyway</artifactId>
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
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-test</artifactId>
      <scope>test</scope>
    </dependency>
    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-security-test</artifactId>
      <scope>test</scope>
    </dependency>
  </dependencies>

  <build>
    <plugins>
      <plugin>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-maven-plugin</artifactId>
      </plugin>
    </plugins>
  </build>
</project>
```

- [ ] **Step 5: Viết main class**

`services/core-banking-service/src/main/java/io/bankplatform/corebanking/CoreBankingApplication.java`:

```java
package io.bankplatform.corebanking;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Không cần {@code @Import} hay {@code @ComponentScan} cho javalibs:
 * mỗi starter tự đăng ký auto-configuration.
 */
@SpringBootApplication
public class CoreBankingApplication {

    public static void main(String[] args) {
        SpringApplication.run(CoreBankingApplication.class, args);
    }
}
```

- [ ] **Step 6: Viết `application.yml`**

```yaml
spring:
  application:
    name: core-banking-service

  datasource:
    url: jdbc:postgresql://${DB_HOST:localhost}:${DB_PORT:5432}/${DB_NAME:bank}
    username: ${DB_USER:core_svc}
    password: ${DB_PASSWORD:core_dev}

  jpa:
    hibernate:
      ddl-auto: validate
    properties:
      hibernate:
        default_schema: core_banking

  flyway:
    # TẮT có chủ đích — xem services/auth-service/src/main/resources/application.yml
    enabled: false
    schemas: core_banking
    default-schema: core_banking
    clean-disabled: true

  kafka:
    bootstrap-servers: ${KAFKA_BOOTSTRAP:localhost:9092}
    consumer:
      group-id: core-banking-service
      auto-offset-reset: earliest

server:
  port: 8084

javalibs:
  security:
    jwt:
      secret: ${JWT_SECRET}

management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
```

- [ ] **Step 7: Viết `application-local.yml` và `src/test/resources/application-test.yml`**

`application-local.yml`:

```yaml
# Profile local: chạy với hạ tầng của compose.yaml.
#   mvn -pl services/core-banking-service spring-boot:run -Dspring-boot.run.profiles=local
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/bank

javalibs:
  security:
    jwt:
      secret: local-dev-only-secret-please-change-me-at-least-32-bytes

logging:
  level:
    io.bankplatform: DEBUG
```

`src/test/resources/application-test.yml`:

```yaml
javalibs:
  security:
    jwt:
      secret: test-only-secret-please-change-me-at-least-32-bytes

spring:
  flyway:
    enabled: false
```

- [ ] **Step 8: Viết `Dockerfile`**

```dockerfile
# Build context là thư mục service này. Jar phải được build TRƯỚC:
#   mvn -pl services/core-banking-service -am -DskipTests package
#   docker build -t bank/core-banking-service:0.1.0 services/core-banking-service
FROM eclipse-temurin:21-jre
WORKDIR /app
ARG JAR_FILE=target/core-banking-service-0.1.0-SNAPSHOT.jar
COPY ${JAR_FILE} app.jar
EXPOSE 8084
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
```

- [ ] **Step 9: Viết `README.md`**

```markdown
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
```

- [ ] **Step 10: Viết `ERROR-CODES.md`**

```markdown
# Mã lỗi — core-banking-service

Prefix: `ERR-CORE-xxx`. Khai trong `io.bankplatform.corebanking.api.CoreBankingErrors` bằng `BusinessErrorCode.of(...)`; javalibs tự đưa vào OpenAPI docs.

Mã là **hợp đồng với frontend**: đã phát hành thì không đổi ý nghĩa, không tái sử dụng. Hết dùng thì đánh dấu deprecated, không xóa.

| Mã | HTTP | Ý nghĩa |
|---|---|---|
| _(chưa có)_ | | |
```

- [ ] **Step 11: Thêm module vào root `pom.xml`**

```xml
    <module>services/core-banking-service</module>
```

- [ ] **Step 12: Build và chạy**

```bash
cd /Users/tanvx/Dev/bank-platform && mvn -B -P'!with-libs' clean install
docker compose up -d && sleep 15
mvn -pl services/core-banking-service spring-boot:run -Dspring-boot.run.profiles=local > /tmp/core-run.log 2>&1 &
sleep 50
curl -s http://localhost:8084/actuator/health; echo
pkill -f "spring-boot:run" || true
```

Expected: `BUILD SUCCESS`, rồi `{"status":"UP"...}`.

- [ ] **Step 13: Commit**

```bash
cd /Users/tanvx/Dev/bank-platform
git add pom.xml services/core-banking-service
git commit -m "feat: core-banking-service (Mức A, chia theo aggregate)

domain/ và application/ chia theo account/ledger/transfer trước, theo
loại sau — quy tắc >=3 aggregate. Starter: cqrs + ddd-spring + datahub
(outbox) + resilience (circuit breaker sang partner) + search.
README liệt kê 5 bất biến domain phải bảo vệ.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 15: `customer-service` — Mức A phẳng

**Files:**
- Create: `services/customer-service/**` (cùng bộ file như Task 14, cây `domain/` phẳng)
- Modify: `pom.xml`

**Interfaces:**
- Consumes: `bank-common` (Task 11), schema `customer` (Task 5)
- Produces: `io.bankplatform.customer.CustomerApplication`, cổng 8082. Minh họa Mức A **dưới** ngưỡng 3 aggregate — giữ bố cục phẳng của javalibs.

- [ ] **Step 1: Xác nhận module chưa tồn tại**

```bash
cd /Users/tanvx/Dev/bank-platform && ls services/customer-service 2>&1
```

Expected: `No such file or directory`.

- [ ] **Step 2: Tạo cây thư mục phẳng**

```bash
cd /Users/tanvx/Dev/bank-platform
BASE=services/customer-service/src/main/java/io/bankplatform/customer

for d in \
  api/dto \
  application/command application/query application/event \
  domain/model domain/rule domain/event domain/port \
  infrastructure/persistence infrastructure/messaging infrastructure/client \
  config
do
  mkdir -p "$BASE/$d" && touch "$BASE/$d/.gitkeep"
done

mkdir -p services/customer-service/src/main/resources/db/migration
touch    services/customer-service/src/main/resources/db/migration/.gitkeep
for d in domain application api; do
  mkdir -p "services/customer-service/src/test/java/io/bankplatform/customer/$d"
  touch    "services/customer-service/src/test/java/io/bankplatform/customer/$d/.gitkeep"
done
mkdir -p services/customer-service/src/test/resources
```

- [ ] **Step 3: Viết `services/customer-service/pom.xml`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <parent>
    <groupId>io.bankplatform</groupId>
    <artifactId>bank-platform</artifactId>
    <version>0.1.0-SNAPSHOT</version>
    <relativePath>../../pom.xml</relativePath>
  </parent>

  <artifactId>customer-service</artifactId>
  <name>bank-platform :: customer-service</name>
  <description>CIF: hồ sơ khách hàng, giấy tờ, địa chỉ, liên hệ, KYC, đánh giá rủi ro.</description>

  <dependencies>
    <dependency>
      <groupId>io.bankplatform</groupId>
      <artifactId>bank-common</artifactId>
    </dependency>

    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-web-spring-boot-starter</artifactId>
    </dependency>
    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-security-spring-boot-starter</artifactId>
    </dependency>
    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-openapi-spring-boot-starter</artifactId>
    </dependency>
    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-observability-spring-boot-starter</artifactId>
    </dependency>
    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-persistence-spring-boot-starter</artifactId>
    </dependency>

    <!-- Mức A: Command/Query bus + AggregateRoot, ValueObject, BusinessRule -->
    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-cqrs-spring-boot-starter</artifactId>
    </dependency>
    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-ddd-spring</artifactId>
    </dependency>

    <!-- Outbox: phát customer.kyc.approved.v1 cùng transaction với việc duyệt -->
    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-datahub-spring-boot-starter</artifactId>
    </dependency>
    <!--
      BẮT BUỘC đi kèm javalibs-datahub-spring-boot-starter. Cùng một lớp lỗi với
      spring-boot-flyway bên dưới, nhưng nguy hiểm hơn vì nó IM LẶNG.

      Đừng chẩn đoán nhầm: starter kéo org.springframework.kafka:spring-kafka KHÔNG
      optional, nên client Kafka luôn có mặt. Thứ thiếu là
      org.springframework.boot:spring-boot-kafka — Boot 4.1 tách
      KafkaAutoConfiguration sang jar riêng, javalibs-datahub-spring-boot-autoconfigure
      để jar đó ở scope optional, mà DatahubKafkaAutoConfiguration lại tham chiếu
      class ấy CỨNG trong annotation: @AutoConfiguration(after = KafkaAutoConfiguration.class).

      Thiếu Flyway thì service chết ngay lúc khởi động nên không ai bỏ sót được.
      Thiếu jar này thì service vẫn UP, /actuator/health vẫn xanh, chỉ có một dòng
      WARN "Failed to introspect meta-annotation @AutoConfiguration ...
      TypeNotPresentException" rồi Spring bỏ qua TOÀN BỘ DatahubKafkaAutoConfiguration.
      EventPublisher qua Kafka không bao giờ được tạo, và event lặng lẽ không đi đâu.
      Riêng service này, customer.kyc.approved.v1 không phát nghĩa là khách đã được
      duyệt KYC nhưng không service nào mở được tài khoản cho họ.
    -->
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-kafka</artifactId>
    </dependency>
    <!-- Lọc động danh sách khách hàng -->
    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-search-spring-boot-starter</artifactId>
    </dependency>
    <!--
      CỐ Ý KHÔNG có javalibs-resilience: service này không gọi hệ thống ngoài nào.
      Thêm circuit breaker cho thứ không có mạng lưới gọi ra là thêm cấu hình
      phải bảo trì mà không bảo vệ gì.
    -->

    <!--
      BẮT BUỘC, kể cả khi spring.flyway.enabled=false.
      javalibs-persistence-spring-boot-starter kéo flyway-core KHÔNG optional, nên
      @ConditionalOnClass(Flyway.class) của JavalibsFlywayAutoConfiguration luôn thỏa.
      Nhưng autoconfigure lại để spring-boot-flyway ở scope optional, mà Boot 4.1 đã
      dời FlywayConfigurationCustomizer vào đúng jar đó -> NoClassDefFoundError lúc
      Spring soi @Bean của lớp cấu hình.

      Lưu ý hai cờ KHÁC NHAU: spring.flyway.enabled gate FlywayAutoConfiguration của
      Spring Boot; JavalibsFlywayAutoConfiguration bị gate bởi cờ riêng
      javalibs.persistence.flyway.enabled (mặc định true). Tắt cờ thứ hai có thể cũng
      né được lỗi — nhưng ta CỐ Ý không làm vậy: để nó bật thì lưới an toàn Flyway của
      javalibs (clean-disabled, kiểm quy ước đặt tên migration) đã sẵn sàng, và tự động
      có hiệu lực ngay khi bật spring.flyway.enabled ở task sau. Tắt đi thì phải nhớ
      bật lại — thứ rất dễ quên trên một nền tảng ngân hàng.
    -->
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-flyway</artifactId>
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
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-test</artifactId>
      <scope>test</scope>
    </dependency>
    <dependency>
      <groupId>io.javalibs</groupId>
      <artifactId>javalibs-security-test</artifactId>
      <scope>test</scope>
    </dependency>
  </dependencies>

  <build>
    <plugins>
      <plugin>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-maven-plugin</artifactId>
      </plugin>
    </plugins>
  </build>
</project>
```

- [ ] **Step 4: Viết main class**

`services/customer-service/src/main/java/io/bankplatform/customer/CustomerApplication.java`:

```java
package io.bankplatform.customer;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class CustomerApplication {

    public static void main(String[] args) {
        SpringApplication.run(CustomerApplication.class, args);
    }
}
```

- [ ] **Step 5: Viết `application.yml`**

```yaml
spring:
  application:
    name: customer-service

  datasource:
    url: jdbc:postgresql://${DB_HOST:localhost}:${DB_PORT:5432}/${DB_NAME:bank}
    username: ${DB_USER:customer_svc}
    password: ${DB_PASSWORD:customer_dev}

  jpa:
    hibernate:
      ddl-auto: validate
    properties:
      hibernate:
        default_schema: customer

  flyway:
    # TẮT có chủ đích — xem services/auth-service/src/main/resources/application.yml
    enabled: false
    schemas: customer
    default-schema: customer
    clean-disabled: true

  kafka:
    bootstrap-servers: ${KAFKA_BOOTSTRAP:localhost:9092}

server:
  port: 8082

javalibs:
  security:
    jwt:
      secret: ${JWT_SECRET}

management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
```

- [ ] **Step 6: Viết `application-local.yml`, `src/test/resources/application-test.yml`, `Dockerfile`**

`services/customer-service/src/main/resources/application-local.yml`:

```yaml
# Profile local: chạy với hạ tầng của compose.yaml.
#   mvn -pl services/customer-service spring-boot:run -Dspring-boot.run.profiles=local
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/bank

javalibs:
  security:
    jwt:
      secret: local-dev-only-secret-please-change-me-at-least-32-bytes

logging:
  level:
    io.bankplatform: DEBUG
```

`services/customer-service/src/test/resources/application-test.yml`:

```yaml
javalibs:
  security:
    jwt:
      secret: test-only-secret-please-change-me-at-least-32-bytes

spring:
  flyway:
    enabled: false
```

`services/customer-service/Dockerfile`:

```dockerfile
# Build context là thư mục service này. Jar phải được build TRƯỚC:
#   mvn -pl services/customer-service -am -DskipTests package
#   docker build -t bank/customer-service:0.1.0 services/customer-service
FROM eclipse-temurin:21-jre
WORKDIR /app
ARG JAR_FILE=target/customer-service-0.1.0-SNAPSHOT.jar
COPY ${JAR_FILE} app.jar
EXPOSE 8082
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
```

- [ ] **Step 7: Viết `README.md`**

```markdown
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
```

- [ ] **Step 8: Viết `ERROR-CODES.md`**

```markdown
# Mã lỗi — customer-service

Prefix: `ERR-CUST-xxx`. Khai trong `io.bankplatform.customer.api.CustomerErrors` bằng `BusinessErrorCode.of(...)`; javalibs tự đưa vào OpenAPI docs.

Mã là **hợp đồng với frontend**: đã phát hành thì không đổi ý nghĩa, không tái sử dụng cho lỗi khác. Hết dùng thì đánh dấu deprecated, không xóa.

| Mã | HTTP | Ý nghĩa |
|---|---|---|
| _(chưa có)_ | | |
```

- [ ] **Step 9: Thêm module vào root `pom.xml`**

```xml
    <module>services/customer-service</module>
```

- [ ] **Step 10: Build và chạy**

```bash
cd /Users/tanvx/Dev/bank-platform && mvn -B -P'!with-libs' clean install
docker compose up -d && sleep 15
mvn -pl services/customer-service spring-boot:run -Dspring-boot.run.profiles=local > /tmp/customer-run.log 2>&1 &
sleep 50
curl -s http://localhost:8082/actuator/health; echo
pkill -f "spring-boot:run" || true
```

Expected: `BUILD SUCCESS`, rồi `{"status":"UP"...}`.

- [ ] **Step 11: Commit**

```bash
cd /Users/tanvx/Dev/bank-platform
git add pom.xml services/customer-service
git commit -m "feat: customer-service (Mức A, bố cục phẳng)

Hai aggregate (Customer, KycVerification) nên dưới ngưỡng chia theo
aggregate — giữ domain/{model,rule,event,port} phẳng. README đối chiếu
ba khái niệm User/Customer/Account và liệt kê 4 bất biến domain.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 16: `gateway-service` — kèm xác minh tương thích Spring Cloud

**Files:**
- Create: `services/gateway-service/{pom.xml,README.md,Dockerfile}`
- Create: `services/gateway-service/src/main/java/io/bankplatform/gateway/GatewayApplication.java`
- Create: `services/gateway-service/src/main/java/io/bankplatform/gateway/config/.gitkeep`
- Create: `services/gateway-service/src/main/resources/{application.yml,application-local.yml}`
- Modify: `pom.xml`
- Có điều kiện: `docker/nginx/nginx.conf`, `compose.yaml`

**Interfaces:**
- Consumes: root POM (Task 1)
- Produces: `io.bankplatform.gateway.GatewayApplication`, cổng 8080. **Không** dùng javalibs, **không** chạm DB.

Khác với 5 service kia, gateway **không có `ERROR-CODES.md`** — nó không có endpoint nghiệp vụ nào nên không có mã lỗi nghiệp vụ để khai. Lỗi nó sinh ra là lỗi định tuyến (404, 502, 504), thuộc về HTTP chứ không thuộc về catalog mã lỗi. Cũng không có `application-test.yml` vì không có test.

**Rủi ro đã biết:** spec §4 ghi rõ chưa xác minh được có release train Spring Cloud tương thích Spring Boot 4.1. Step 1–2 xác minh trước khi viết bất cứ dòng nào.

- [ ] **Step 1: Liệt kê các bản `spring-cloud-dependencies` mới nhất**

```bash
curl -s "https://search.maven.org/solrsearch/select?q=g:org.springframework.cloud+AND+a:spring-cloud-dependencies&core=gav&rows=30&wt=json" \
  | python3 -c "import json,sys; [print(d['v']) for d in json.load(sys.stdin)['response']['docs']]"
```

Ghi lại danh sách. Nếu lệnh thất bại vì không có mạng, bỏ qua sang Step 2b.

- [ ] **Step 2a: Tìm bản có `spring-boot.version` là 4.1.x**

Với từng version ứng viên `<V>` (mới nhất trước), kiểm tra POM của nó:

```bash
V=2026.0.0   # thay bằng version thật từ Step 1
curl -s "https://repo1.maven.org/maven2/org/springframework/cloud/spring-cloud-dependencies/${V}/spring-cloud-dependencies-${V}.pom" \
  | grep -iE "spring-boot.version|<name>"
```

Ghi lại kết quả. Có ba khả năng:

**Người dùng đã quyết định: dùng Spring Cloud Gateway, không dùng nginx.** Verify ở đây là để chọn đúng *version*, không phải để chọn *có dùng hay không*.

| Kết quả | Hành động |
|---|---|
| Tìm được bản khai `spring-boot.version` **4.1.x** | Đi tiếp Step 3 với version đó |
| Chỉ có bản cho Boot 4.0.x | Thử Step 3 với bản đó — Boot 4.0 và 4.1 cùng dòng major, khả năng chạy được cao. Nếu build hoặc khởi động lỗi, ghi lại lỗi thật rồi báo **BLOCKED** |
| Không có bản nào cho Boot 4.x | Báo **BLOCKED** ngay, kèm danh sách version đã thử và `spring-boot.version` của từng bản |

**Không tự ý chuyển sang nginx.** Đó là quyết định của con người, không phải của người triển khai. Nếu Spring Cloud Gateway không dùng được với Boot 4.1, việc cần làm là dừng lại và báo — vì lựa chọn thay thế có thể là hạ Spring Boot, đợi release train mới, hoặc chấp nhận nginx, và cả ba đều nằm ngoài thẩm quyền của task này.

- [ ] **Step 2b: (dự phòng, CHỈ chạy khi người dùng đổi quyết định) — nginx thay gateway**

Giữ lại làm tài liệu tham chiếu. **Không chạy step này trừ khi được chỉ định rõ ràng.** Tạo `docker/nginx/nginx.conf`:

```nginx
# Đường lui khi chưa có Spring Cloud Gateway tương thích Spring Boot 4.1.
# Định tuyến thuần, không xác thực — mọi service vẫn tự kiểm JWT qua javalibs-security.
events {}
http {
    upstream auth_svc     { server host.docker.internal:8081; }
    upstream customer_svc { server host.docker.internal:8082; }
    upstream product_svc  { server host.docker.internal:8083; }
    upstream core_svc     { server host.docker.internal:8084; }
    upstream noti_svc     { server host.docker.internal:8085; }

    server {
        listen 8080;
        location /api/auth/         { proxy_pass http://auth_svc; }
        location /api/customers/    { proxy_pass http://customer_svc; }
        location /api/products/     { proxy_pass http://product_svc; }
        location /api/accounts/     { proxy_pass http://core_svc; }
        location /api/transfers/    { proxy_pass http://core_svc; }
        location /api/notifications/{ proxy_pass http://noti_svc; }
    }
}
```

Thêm vào `compose.yaml`:

```yaml
  gateway:
    image: nginx:1.27-alpine
    container_name: bank-gateway
    ports:
      - "8080:8080"
    volumes:
      - ./docker/nginx/nginx.conf:/etc/nginx/nginx.conf:ro
    extra_hosts:
      - "host.docker.internal:host-gateway"
```

Rồi **bỏ qua Step 3–8**, làm Step 9 (module Java rỗng có comment giải thích) và Step 10–12.

- [ ] **Step 3: Tạo cây thư mục**

```bash
cd /Users/tanvx/Dev/bank-platform
mkdir -p services/gateway-service/src/main/java/io/bankplatform/gateway/config
touch    services/gateway-service/src/main/java/io/bankplatform/gateway/config/.gitkeep
mkdir -p services/gateway-service/src/main/resources
```

- [ ] **Step 4: Viết `services/gateway-service/pom.xml`**

Thay `<SPRING_CLOUD_VERSION>` bằng version xác minh được ở Step 2a:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <parent>
    <groupId>io.bankplatform</groupId>
    <artifactId>bank-platform</artifactId>
    <version>0.1.0-SNAPSHOT</version>
    <relativePath>../../pom.xml</relativePath>
  </parent>

  <artifactId>gateway-service</artifactId>
  <name>bank-platform :: gateway-service</name>
  <description>
    Cổng vào duy nhất cho frontend. CHỈ định tuyến — không nghiệp vụ, không DB,
    không javalibs. Mỗi service phía sau vẫn tự kiểm JWT.
  </description>

  <properties>
    <!-- Version này đã được xác minh khai spring-boot.version 4.1.x. Đổi Spring Boot
         thì phải kiểm lại: Spring Cloud đi theo release train riêng, bám sát Boot. -->
    <spring-cloud.version>SPRING_CLOUD_VERSION</spring-cloud.version>
  </properties>

  <dependencyManagement>
    <dependencies>
      <dependency>
        <groupId>org.springframework.cloud</groupId>
        <artifactId>spring-cloud-dependencies</artifactId>
        <version>${spring-cloud.version}</version>
        <type>pom</type>
        <scope>import</scope>
      </dependency>
    </dependencies>
  </dependencyManagement>

  <dependencies>
    <!-- Bản servlet (WebMVC), không phải reactive: đồng bộ với mọi service khác
         trong repo, đỡ phải học hai mô hình lập trình cùng lúc. -->
    <dependency>
      <groupId>org.springframework.cloud</groupId>
      <artifactId>spring-cloud-starter-gateway-server-webmvc</artifactId>
    </dependency>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-actuator</artifactId>
    </dependency>
  </dependencies>

  <build>
    <plugins>
      <plugin>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-maven-plugin</artifactId>
      </plugin>
    </plugins>
  </build>
</project>
```

- [ ] **Step 5: Viết main class**

`services/gateway-service/src/main/java/io/bankplatform/gateway/GatewayApplication.java`:

```java
package io.bankplatform.gateway;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class GatewayApplication {

    public static void main(String[] args) {
        SpringApplication.run(GatewayApplication.class, args);
    }
}
```

- [ ] **Step 6: Viết `application.yml`**

```yaml
spring:
  application:
    name: gateway-service

  cloud:
    gateway:
      # Route khai bằng cấu hình, không bằng code — thêm service mới là thêm
      # vài dòng yaml, không phải deploy lại logic.
      routes:
        - id: auth
          uri: ${AUTH_URI:http://localhost:8081}
          predicates:
            - Path=/api/auth/**
        - id: customer
          uri: ${CUSTOMER_URI:http://localhost:8082}
          predicates:
            - Path=/api/customers/**
        - id: product
          uri: ${PRODUCT_URI:http://localhost:8083}
          predicates:
            - Path=/api/products/**
        - id: core-banking
          uri: ${CORE_URI:http://localhost:8084}
          predicates:
            - Path=/api/accounts/**,/api/transfers/**
        - id: notification
          uri: ${NOTIFICATION_URI:http://localhost:8085}
          predicates:
            - Path=/api/notifications/**

server:
  port: 8080

management:
  endpoints:
    web:
      exposure:
        include: health,info,gateway
```

- [ ] **Step 7: Viết `application-local.yml`**

```yaml
# Profile local: mọi service chạy trên máy này.
#   mvn -pl services/gateway-service spring-boot:run -Dspring-boot.run.profiles=local
logging:
  level:
    org.springframework.cloud.gateway: DEBUG
```

- [ ] **Step 8: Viết `Dockerfile`**

```dockerfile
# Build context là thư mục service này. Jar phải được build TRƯỚC:
#   mvn -pl services/gateway-service -am -DskipTests package
#   docker build -t bank/gateway-service:0.1.0 services/gateway-service
FROM eclipse-temurin:21-jre
WORKDIR /app
ARG JAR_FILE=target/gateway-service-0.1.0-SNAPSHOT.jar
COPY ${JAR_FILE} app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
```

- [ ] **Step 9: Viết `README.md`**

Ghi lại **kết quả thật** của Step 1–2, không phải kết quả mong đợi:

```markdown
# gateway-service

Cổng vào duy nhất cho frontend. **Chỉ định tuyến** — không nghiệp vụ, không chạm DB, không dùng javalibs.

- **Cổng:** 8080
- **Không có schema DB.**

## Xác thực nằm ở đâu

Gateway **không** kiểm JWT. Mỗi service phía sau tự kiểm qua `javalibs-security` — nếu gateway kiểm hộ thì bất kỳ ai gọi thẳng vào service (trong cùng cluster) đều bỏ qua được xác thực. Gateway chỉ là tiện ích định tuyến, không phải ranh giới tin cậy.

## Tình trạng tương thích Spring Cloud

Spring Cloud đi theo release train riêng, bám sát version Spring Boot.

- **Đã kiểm:** _(ghi ngày kiểm, các version đã thử, và version nào khai `spring-boot.version` 4.1.x)_
- **Đang dùng:** `spring-cloud-dependencies:<version>`
- **Nếu nâng Spring Boot:** phải kiểm lại bảng tương thích trước, đừng chỉ đổi số.

## Bảng route

| Path | Service | Cổng |
|---|---|---|
| `/api/auth/**` | auth-service | 8081 |
| `/api/customers/**` | customer-service | 8082 |
| `/api/products/**` | product-service | 8083 |
| `/api/accounts/**`, `/api/transfers/**` | core-banking-service | 8084 |
| `/api/notifications/**` | notification-service | 8085 |

## Chạy local

```bash
mvn -pl services/gateway-service -am spring-boot:run -Dspring-boot.run.profiles=local
curl -s http://localhost:8080/actuator/gateway/routes | head -c 400
```
```

Nếu đi theo đường lui Step 2b, thay hai mục đầu bằng ghi chú: module Java đang rỗng có chủ đích, `compose.yaml` dùng nginx tại cổng 8080, và điều kiện để quay lại Spring Cloud Gateway.

- [ ] **Step 10: Thêm module vào root `pom.xml`**

```xml
    <module>services/gateway-service</module>
```

- [ ] **Step 11: Build và kiểm tra route**

```bash
cd /Users/tanvx/Dev/bank-platform && mvn -B -P'!with-libs' clean install
mvn -pl services/gateway-service spring-boot:run -Dspring-boot.run.profiles=local > /tmp/gw-run.log 2>&1 &
sleep 40
curl -s http://localhost:8080/actuator/health; echo
curl -s http://localhost:8080/actuator/gateway/routes | head -c 400; echo
pkill -f "spring-boot:run" || true
```

Expected: `{"status":"UP"...}` và JSON liệt kê 5 route. Nếu đi đường lui Step 2b: `docker compose up -d gateway && curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/api/auth/` trả về mã HTTP (502 khi auth-service chưa chạy là bình thường — nó chứng minh nginx đã định tuyến).

- [ ] **Step 12: Commit**

```bash
cd /Users/tanvx/Dev/bank-platform
git add pom.xml services/gateway-service compose.yaml docker 2>/dev/null || git add pom.xml services/gateway-service
git commit -m "feat: gateway-service — định tuyến tập trung

Đã xác minh version Spring Cloud tương thích Spring Boot 4.1 trước khi
viết pom (kết quả ghi trong README). Gateway KHÔNG kiểm JWT: mỗi service
tự kiểm, nếu không thì gọi thẳng vào service là bỏ qua được xác thực.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 17: Dotfiles, CI, `docs/legacy/`, README gốc, nghiệm thu toàn hệ

**Files:**
- Create: `.editorconfig`, `.gitattributes`, `.env.sample`, `README.md`
- Modify: `.gitignore`
- Create: `.github/workflows/ci.yml`
- Move: `docs/*.sql` → `docs/legacy/`
- Create: `docs/legacy/README.md`

**Interfaces:**
- Consumes: toàn bộ Task 1–16
- Produces: repo hoàn chỉnh, `mvn -B clean install` xanh từ gốc, CI chạy được.

- [ ] **Step 1: Xác nhận repo chưa có dotfiles đầy đủ**

```bash
cd /Users/tanvx/Dev/bank-platform && ls -a | grep -E "^\.(editorconfig|gitattributes|env.sample|github)$" || echo "CHƯA CÓ"
```

Expected: `CHƯA CÓ`.

- [ ] **Step 2: Mở rộng `.gitignore`**

```gitignore
# Maven / Java
target/
!.mvn/wrapper/maven-wrapper.jar
.mvn/timing.properties

# IDE
.idea/
*.iml
*.ipr
*.iws
.vscode/
.classpath
.project
.settings/

# OS
.DS_Store
Thumbs.db

# Log và báo cáo
logs/
*.log
jacoco.exec
surefire-reports/
failsafe-reports/

# Testcontainers / Docker
.testcontainers.properties
**/.testcontainers/*

# Biến môi trường — .env.sample thì commit, .env thì không
.env
.env.*
!.env.sample

# Scratch của subagent-driven-development — không bao giờ commit
.superpowers/

# Cấu hình skill cục bộ của người dùng — không thuộc về repo
.claude

# Linh tinh
*.orig
*.rej
```

**Hai dòng `.superpowers/` và `.claude` là bắt buộc, đừng bỏ.** Step 15 của task này chạy `git add -A`. Thiếu `.superpowers/` thì toàn bộ ledger và báo cáo của quy trình review bị commit vào repo; thiếu `.claude` thì thư mục cấu hình skill cục bộ của người dùng (2.2 MB, 101 file) bị kéo vào. **Cả hai dòng đã có sẵn trong `.gitignore` trước khi task này chạy** — việc của Step 2 là **mở rộng** file, tuyệt đối không ghi đè làm mất chúng. Kiểm lại bằng `git check-ignore -v .claude .superpowers` sau khi sửa.

- [ ] **Step 3: Viết `.editorconfig`**

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = space
indent_size = 4

[*.{yml,yaml,json,xml}]
indent_size = 2

[*.md]
trim_trailing_whitespace = false

[*.sql]
indent_size = 4

[Makefile]
indent_style = tab
```

- [ ] **Step 4: Viết `.gitattributes`**

```gitattributes
* text=auto eol=lf

*.java   text diff=java
*.sql    text
*.yml    text
*.yaml   text
*.xml    text
*.md     text diff=markdown

*.jar    binary
*.png    binary
*.jpg    binary
*.gif    binary
*.ico    binary
```

- [ ] **Step 5: Viết `.env.sample`**

```dotenv
# Sao chép thành .env rồi chỉnh. KHÔNG commit .env.
# AI agent và script KHÔNG ĐƯỢC đọc hay in nội dung .env.

SPRING_PROFILES_ACTIVE=local

# Postgres — khớp docs/database/schema.sql
DB_HOST=localhost
DB_PORT=5432
DB_NAME=bank

# Bí mật ký JWT. Tối thiểu 32 byte. Mỗi môi trường một giá trị khác nhau.
JWT_SECRET=change-me-to-at-least-32-bytes-of-random-data

KAFKA_BOOTSTRAP=localhost:9092
REDIS_HOST=localhost
REDIS_PORT=6379
```

- [ ] **Step 6: Chuyển 6 file SQL cũ sang `docs/legacy/`**

```bash
cd /Users/tanvx/Dev/bank-platform
mkdir -p docs/legacy
git mv docs/01-init-schemas.sql docs/V1__auth_init.sql docs/V1__notification_init.sql \
       docs/V2__ownership_and_audit.sql docs/V3__outbox_and_external.sql \
       docs/V4__ledger_partition.sql docs/legacy/ 2>/dev/null \
  || mv docs/*.sql docs/legacy/
ls docs/legacy/
```

Expected: 6 file `.sql`. Nếu `git mv` thất bại vì file chưa được track (chúng chưa từng được commit — commit đầu chỉ có spec và `.gitignore`), lệnh `mv` thường sẽ chạy.

- [ ] **Step 7: Viết `docs/legacy/README.md`**

```markdown
# Bản SQL cũ — giữ làm tài liệu tham chiếu

Sáu file ở đây là thiết kế database **trước** khi có `docs/database/schema.sql`. Chúng **không còn được chạy** và không được sửa. Giữ lại vì mỗi file mang một bài học mà bản mới không thể hiện.

## Cái gì đã đổi

| Bản cũ | Bản mới | Vì sao |
|---|---|---|
| 3 schema (`auth`, `core_banking`, `notification`) | 5 schema (thêm `customer`, `product`) | Bản cũ dạy pattern hệ thống phân tán nhưng gần như không dạy nghiệp vụ ngân hàng: không có khách hàng, không có sản phẩm, không có lãi và phí |
| `ledger_entries` phẳng | `journal_entries` + `journal_lines` | Bảng phẳng không có phía đối ứng, không có GL, và không diễn tả nổi giao dịch ba dòng (chuyển tiền có thu phí) |
| Không có chart of accounts | `gl_accounts` | Không có sổ cái thì không có gì để đối chiếu số dư tài khoản khách hàng |
| `accounts.type = 'SYSTEM'` | bỏ | `journal_lines.account_id` NULL đã diễn tả "dòng này chỉ chạm GL nội bộ". `accounts` là sổ phụ khách hàng, `gl_accounts` là sổ cái |
| `accounts.owner_user_id` → `auth.users` | `accounts.primary_customer_id` → `customer.customers` | Chủ tài khoản là **khách hàng**, không phải tài khoản đăng nhập. Giữ cả hai đường là hai nguồn sự thật cho cùng một quan hệ |
| Số dư không lưu | `ledger_balance` + `hold_amount` + `available_balance` GENERATED | Không có khái niệm số dư khả dụng thì không giải thích được vì sao quẹt thẻ xong tiền "treo" |
| CHECK inline không tên | mọi CHECK đều `ck_<bảng>_<ý nghĩa>` | Chính `V3__outbox_and_external.sql` đã vấp lỗi này: phải `\d transfers` mới biết Postgres đặt tên constraint là gì |

## Bài học chỉ có ở đây

**`V4__ledger_partition.sql`** dựng partition bằng expand–swap trên bảng đang có dữ liệu: tạo bảng mới, copy sang, đổi tên, giữ sequence. `schema.sql` sinh partition ngay từ đầu nên không có bước này — nhưng ngoài đời bạn luôn phải partition một bảng *đã lớn*, và đó chính là kịch bản `V4` mô tả. Đọc nó khi cần làm việc đó thật.

**`V2__ownership_and_audit.sql`** minh họa expand–contract: chỉ THÊM cột ở bước một, để code cũ và code mới cùng chạy được trong lúc rollout; siết ràng buộc ở migration sau, chỉ khi đã backfill xong.

## Đừng chạy chúng

`compose.yaml` chỉ mount `docs/database/schema.sql`. Chạy các file ở đây lên cùng một database sẽ tạo ra bảng trùng tên với cấu trúc khác.
```

- [ ] **Step 8: Viết `.github/workflows/ci.yml`**

```yaml
name: ci

on:
  push:
    branches: [master, main]
  pull_request:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '21'
          cache: maven

      # Build CẢ platform-libs (profile with-libs bật mặc định): đảm bảo bản
      # javalibs nằm trong repo thực sự compile được, không chỉ tin vào artifact
      # đã publish ở đâu đó.
      - name: Build toàn reactor
        run: mvn -B clean install -DskipTests

      - name: Kiểm tra schema.sql chạy được
        run: |
          docker compose up -d postgres
          for i in $(seq 1 30); do
            docker compose exec -T postgres pg_isready -U postgres -d bank && break
            sleep 2
          done
          COUNT=$(docker compose exec -T postgres psql -U postgres -d bank -tAc "
            SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname IN ('auth','customer','product','core_banking','notification')
              AND c.relkind IN ('r','p') AND c.oid NOT IN (SELECT inhrelid FROM pg_inherits)")
          echo "Số bảng: $COUNT"
          test "$COUNT" -eq 42
```

- [ ] **Step 9: Viết `README.md` gốc**

```markdown
# bank-platform

Monorepo core banking dùng để học nghiệp vụ ngân hàng bằng cách tự xây nó. Spring Boot 4.1 · Java 21 · PostgreSQL 17.

**Đây là base project: không có code nghiệp vụ.** Toàn repo có đúng 6 file `.java`, đều là main class. Cấu trúc package đã dựng sẵn và rỗng; database đã thiết kế đầy đủ.

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
```

- [ ] **Step 10: NGHIỆM THU — build sạch toàn reactor**

```bash
cd /Users/tanvx/Dev/bank-platform && mvn -B clean install -DskipTests 2>&1 | tail -30
```

Expected: `BUILD SUCCESS`, reactor summary có `bank-platform`, `bank-common`, 6 service, và các module javalibs.

- [ ] **Step 11: NGHIỆM THU — đúng 6 file `.java`**

```bash
cd /Users/tanvx/Dev/bank-platform
find bank-common services -name "*.java" | sort
find bank-common services -name "*.java" | wc -l
```

Expected: đúng 6 đường dẫn, tất cả đều là `*Application.java`, và số đếm là `6`.

- [ ] **Step 12: NGHIỆM THU — database đủ 42 bảng và seed**

```bash
cd /Users/tanvx/Dev/bank-platform && docker compose down -v && docker compose up -d && sleep 15
docker compose exec -T postgres psql -U postgres -d bank -tAc "
SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname IN ('auth','customer','product','core_banking','notification')
  AND c.relkind IN ('r','p') AND c.oid NOT IN (SELECT inhrelid FROM pg_inherits)"
docker compose exec -T postgres psql -U postgres -d bank -tAc "SELECT count(*) FROM core_banking.gl_accounts"
docker compose exec -T postgres psql -U postgres -d bank -tAc "SELECT count(*) FROM product.products"
docker compose exec -T postgres psql -U postgres -d bank -tAc "
SELECT count(*) FROM pg_inherits i JOIN pg_class p ON p.oid = i.inhparent WHERE p.relname = 'journal_lines'"
```

Expected: `42`, `9`, `3`, `4`.

- [ ] **Step 13: NGHIỆM THU — sáu service khởi động được**

```bash
cd /Users/tanvx/Dev/bank-platform
for svc in gateway auth customer product core-banking notification; do
  mvn -pl services/${svc}-service spring-boot:run -Dspring-boot.run.profiles=local > /tmp/${svc}.log 2>&1 &
done
sleep 90
for p in 8080 8081 8082 8083 8084 8085; do
  printf "%s -> " "$p"; curl -s http://localhost:$p/actuator/health || echo "KHÔNG PHẢN HỒI"; echo
done
```

Expected: cả 6 cổng trả `{"status":"UP"...}`. Cổng nào không lên thì đọc `/tmp/<tên>.log`.

- [ ] **Step 14: NGHIỆM THU — Swagger UI của 5 service nghiệp vụ**

```bash
for p in 8081 8082 8083 8084 8085; do
  printf "%s -> %s\n" "$p" "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:$p/swagger-ui/index.html)"
done
pkill -f "spring-boot:run" || true
```

Expected: cả 5 trả `200`. Gateway không có Swagger (không có endpoint nghiệp vụ nào).

- [ ] **Step 15: Commit**

```bash
cd /Users/tanvx/Dev/bank-platform
git add -A
git commit -m "chore: dotfiles, CI, docs/legacy, README gốc

.gitignore/.editorconfig/.gitattributes/.env.sample theo chuẩn dr-jskill.
CI build cả platform-libs và kiểm schema.sql dựng đủ 42 bảng.
6 file SQL cũ chuyển sang docs/legacy/ kèm bảng đối chiếu cái gì đã đổi
và vì sao — V4 (partition bằng expand-swap) là bài học không có ở bản mới.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Đối chiếu spec

| Yêu cầu trong spec | Task |
|---|---|
| §4 javalibs nhúng nguyên vẹn thành `platform-libs`, root POM một reactor, profile `with-libs` | 1 |
| §4 starter javalibs theo từng service | 12, 13, 14, 15 |
| §4 rủi ro Spring Cloud Gateway — verify trước, có đường lui | 16 |
| §5 cấu trúc package Mức A chia theo aggregate | 14 |
| §5 cấu trúc package Mức A phẳng | 15 |
| §5 cấu trúc package Mức B | 12, 13 |
| §5 `bank-common` phạm vi hẹp + 4 điều cấm | 11 |
| §5 đúng 6 file `.java` | 17 Step 11 |
| §6.1 chín nguyên tắc thiết kế | 2 |
| §6.2 DB1 bút toán kép · DB2 trigger cân đối · DB3 bỏ SYSTEM · DB4 số dư lưu sẵn | 8 · 8 · 7+8 · 7 |
| §6.3 `auth` 4 bảng | 3 |
| §6.4 `customer` 10 bảng | 5 |
| §6.5 `product` 7 bảng | 6 |
| §6.6 `core_banking` 15 bảng | 7, 8, 9 |
| §6.7 `notification` 6 bảng | 4 |
| §6.8 bố cục `schema.sql`, seed 9 GL + 3 sản phẩm, 4 partition | 2–10 |
| §6.9 `docs/legacy/` | 17 |
| §7 compose.yaml, khung service, git + CI | 2, 12–16, 17 |
| §8 năm tiêu chí nghiệm thu | 17 Step 10–14, và Task 8 Step 4 cho DB2 |
