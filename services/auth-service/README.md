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

## Persistence

Entity + repository map đủ 3 bảng của schema `auth` (schema.sql khối [2]) — **không có bảng nào bị bỏ qua**:

| Bảng | Entity | Repository |
|---|---|---|
| `users` | `model.User` | `repository.UserRepository` (+ `findByUsername`) |
| `refresh_tokens` | `model.RefreshToken` | `repository.RefreshTokenRepository` (+ `findByTokenHash`) |
| `login_audit` | `model.LoginAudit` (append-only, không setter) | `repository.LoginAuditRepository` (không finder thêm — L9) |

`user_roles` **không** có entity/repository riêng (quyết định L8): map bằng `@ElementCollection<UserRole>` ngay trên `User` (`@CollectionTable(name = "user_roles")`). Lý do: bảng chỉ có `(user_id, role)`, vòng đời gắn chặt với `User`, và `javalibs-security` lấy role từ JWT lúc runtime chứ không query lại bảng này.

Điểm mapping đáng chú ý khác:

- `refresh_tokens.user_id` và `login_audit.user_id` là cột `Long` thường, KHÔNG association `@ManyToOne` sang `User` — token/audit có vòng đời độc lập với aggregate `User`. `login_audit` cố ý không có FK sang `users` ở tầng DB lẫn Java, để giữ được cả log đăng nhập bằng username không tồn tại.
- `login_audit.at` (TIMESTAMPTZ, DEFAULT now(), DB giữ) map vào field `occurredAt` qua `@Column(name = "at")` — `at` vẫn là định danh Java hợp lệ (compile bình thường), đổi tên chỉ vì `at` không mô tả tốt ý nghĩa của field so với `occurredAt`.
- `login_audit.ip` (INET) map bằng `String` + `@JdbcTypeCode(SqlTypes.INET)` theo đúng quy ước chung — round-trip qua Testcontainers Postgres pass ngay lần đầu, không cần fallback `columnDefinition`.
- `created_at`/`updated_at` (và `login_audit.at`) đều `insertable = false, updatable = false` + `@Generated` — DB giữ giá trị, Hibernate chỉ đọc lại sau flush.

Test mapping: `AuthPersistenceMappingTest` (round-trip từng bảng qua Testcontainers, `docs/database/schema.sql` nạp thật vào container qua `AbstractIntegrationTest`). `ServiceInfoApiTest` cũng đổi sang extends `AbstractIntegrationTest` vì từ nay Spring context nào cũng cần schema `auth` tồn tại sẵn để `ddl-auto: validate` không chết lúc khởi động.
