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
