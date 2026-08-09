# Vận hành — Build, Release, Publish, CI/CD

## Build & test

```bash
mvn clean install            # build + toàn bộ unit/integration test (482 test)
mvn clean install -DskipTests
mvn -pl javalibs-security -amd clean install   # chỉ một nhóm module + những gì phụ thuộc nó
mvn -f javalibs-web/pom.xml test               # build một module con độc lập
mvn clean verify             # kèm báo cáo JaCoCo (target/site/jacoco của từng module)
```

Yêu cầu môi trường (enforcer chặn nếu thiếu): **JDK 21+, Maven 3.6.3+**. Test của javalibs không cần Docker (H2 + mock); Docker chỉ cần cho client dùng `javalibs-test`.

## Versioning & release

- Toàn bộ artifact chia sẻ **một version duy nhất** (hiện `2.0.0-SNAPSHOT`), pin tập trung trong BOM `javalibs-dependencies`.
- Theo **SemVer**:
  - `PATCH` — sửa lỗi, không đổi API/hành vi mặc định;
  - `MINOR` — thêm module/tính năng/property mới (backward compatible);
  - `MAJOR` — đổi/bỏ API, đổi giá trị mặc định của property, nâng baseline (Java/Spring Boot major).
- **Quy tắc vàng:** không bao giờ đổi hành vi mặc định trong MINOR — service upgrade BOM phải chạy y hệt.
- Release: đổi version ở `javalibs-root/pom.xml` (tất cả parent/child kế thừa), đổi version trong `javalibs-dependencies/pom.xml` (BOM không có parent — **dễ quên**), tag `v<version>`, để CI deploy.

## Publish lên GitHub Packages

Repo: [`tanvx-training/javalibs-4.1`](https://github.com/tanvx-training/javalibs-4.1) (private).
`distributionManagement` trong root POM **và** BOM trỏ về một repository Maven duy nhất của
GitHub Packages, dùng chung URL cho cả cặp id `javalibs-releases`/`javalibs-snapshots`
(khác Nexus, nơi mỗi id một URL riêng):

```bash
mvn -B -DskipTests deploy -Prelease
```

- Profile `-Prelease` đính kèm `-sources.jar` và `-javadoc.jar`.
- Credentials đặt trong `~/.m2/settings.xml` (personal access token scope `write:packages` khi
  publish thủ công; `GITHUB_TOKEN` mặc định khi chạy trong GitHub Actions):

```xml
<servers>
  <server>
    <id>javalibs-snapshots</id>
    <username>${env.GITHUB_ACTOR}</username>
    <password>${env.GITHUB_TOKEN}</password>
  </server>
</servers>
```

- Service **tiêu thụ** artifact từ GitHub Packages phải khai cùng URL ở `<repositories>` và
  cùng cặp credentials — GitHub Packages yêu cầu xác thực kể cả khi chỉ đọc.

## CI/CD

Workflow tại `.github/workflows/ci.yml` (repo làm việc trên branch `master`):

| Trigger | Hành động |
|---|---|
| PR vào `master` | `mvn clean verify` (build + test) |
| Push `master` | build + deploy SNAPSHOT lên GitHub Packages |
| Tag `v*` | build + deploy release (kèm sources/javadoc) |

Secret cần khai báo: `GITHUB_TOKEN` (mặc định có sẵn trong GitHub Actions, chỉ cần đủ quyền
`packages: write`) — không cần secret Nexus/Artifactory nữa.

## Nâng cấp Spring Boot / thư viện thứ ba

Version chốt tại một chỗ — `javalibs-root/pom.xml` (đây là root POM của chính repo này, xem
[architecture.md](architecture.md), không phải repo `javalibs-root` sibling dùng để migrate):

```xml
<spring-boot.version>4.1.0</spring-boot.version>
<jjwt.version>0.12.6</jjwt.version>
<resilience4j.version>2.4.0</resilience4j.version>
<springdoc.version>3.1.0</springdoc.version>
```

Quy trình: đổi property → `mvn clean install` → đọc kỹ deprecation/behavior change trong release notes (đặc biệt Spring Security DSL và springdoc theo minor của Boot) → bump MINOR version của javalibs → thông báo các team.

## Troubleshooting

| Triệu chứng | Nguyên nhân thường gặp |
|---|---|
| Bean của javalibs không được tạo | Cờ `enabled` đang tắt; thiếu bean điều kiện (`DataSource`, `KafkaTemplate`, `RedisConnectionFactory`, `CacheAspectSupport`/`@EnableCaching`); hoặc service đã tự định nghĩa bean cùng type (javalibs chủ động lùi). Chạy với `--debug` để xem Condition Evaluation Report. |
| Startup fail "javalibs.security.jwt.secret or ... must be configured" | Mode `jwt` cần secret hoặc public-key; hoặc tắt module / chuyển mode. Đây là fail-fast chủ đích. |
| `IllegalStateException` khi `outbox.enqueue` | Gọi ngoài transaction — thêm `@Transactional` vào method service (chủ đích của pattern). |
| Outbox row kẹt `FAILED` | Đã quá `max-attempts`. Xem `last_error`, sửa nguyên nhân, `UPDATE ... SET status='PENDING', attempts=0` để relay lại. |
| Cache Redis ném lỗi deserialize sau khi refactor DTO | JSON chứa `@class` cũ — flush cache liên quan (đây là trade-off có tài liệu của serializer). |
| Test client fail vì thiếu Docker | `javalibs-test` dựng PostgreSQL qua Testcontainers — cần Docker daemon; hoặc đừng extend `BaseIntegrationTest` cho unit test. |
| 401 dù token hợp lệ | Kiểm tra secret hai bên khớp, `clock-skew`, issuer/audience; token bị revoke (blacklist); xem log DEBUG của `JwtAuthenticationFilter`. |
