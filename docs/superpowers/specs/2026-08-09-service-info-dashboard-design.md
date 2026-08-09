# Service Info API + Dashboard — thiết kế

**Ngày:** 2026-08-09 · **Trạng thái:** chờ duyệt
**Nền:** master @ 67320e0 (nền scaffolding đã merge — 6 service, database đầy đủ, chưa có code nghiệp vụ)

## Mục tiêu

1. Mỗi service (cả 6, kể cả gateway) có một API `GET .../info` trả thông tin chi tiết
   về chính nó — tĩnh (tên, version, cổng, schema…) và động (uptime, trạng thái hạ tầng).
2. Một dự án frontend (React + Vite) gọi các API đó qua gateway và hiển thị dashboard
   6 thẻ service, tự refresh, chịu được service chết.

**Hết hiệu lực một ràng buộc cũ:** phase scaffolding ép "đúng 6 file `.java`". Feature
này là code nghiệp vụ đầu tiên — số file `.java` sẽ tăng, và đó là chủ đích, không phải
lỗi. Không "sửa lại cho đủ 6".

**Ràng buộc còn nguyên hiệu lực:** không sửa `platform-libs/`; gateway không dùng
javalibs; không FK xuyên schema; comment tiếng Việt giải thích *vì sao*.

## Kiến trúc tổng thể

```
React (Vite dev, :5173)
   │  fetch, mỗi 10s
   ▼
Gateway :8080  ──(route có sẵn)──▶  auth :8081        GET /api/auth/info
   │                                customer :8082    GET /api/customers/info
   │                                product :8083     GET /api/products/info
   │                                core-banking :8084 GET /api/accounts/info
   │                                notification :8085 GET /api/notifications/info
   └─(controller nội bộ)──▶ GET /api/gateway/info
```

- **Không thêm route gateway nào.** Endpoint info của mỗi service nằm dưới prefix route
  có sẵn của nó (`/api/accounts/info` là của core-banking — DTO có `serviceName` nên
  không nhầm được). `/api/gateway/info` không khớp route nào nên rơi xuống
  `@RestController` của chính gateway.
- **CORS xử lý tại gateway, một chỗ duy nhất** — vì mọi request của frontend đều đi qua
  8080. Gateway không có javalibs nên không dùng được `javalibs.web.cors.*`; thêm một
  class `CorsConfig` nhỏ trong package `config/` (đang rỗng sẵn chỗ): cho origin
  `http://localhost:5173`, method `GET, OPTIONS`, path `/api/**`.

## API contract

### 5 service nghiệp vụ — `GET /api/<prefix>/info`

Response dùng `ApiResponse<T>` của javalibs-web (khuôn chuẩn của platform). Payload:

```json
{
  "serviceName": "core-banking-service",
  "description": "Sổ cái bút toán kép, tài khoản, hold, chuyển tiền, lãi và phí.",
  "version": "0.1.0-SNAPSHOT",
  "port": 8084,
  "structureLevel": "A — chia theo aggregate",
  "dbSchema": "core_banking",
  "errorCodePrefix": "ERR-CORE",
  "javaVersion": "21.x",
  "springBootVersion": "4.1.0",
  "startedAt": "2026-08-09T10:00:00+07:00",
  "uptimeSeconds": 1234,
  "dependencies": [
    { "name": "db",    "status": "UP" },
    { "name": "kafka", "status": "UP" },
    { "name": "redis", "status": "UNKNOWN" }
  ]
}
```

Nguồn dữ liệu:

| Trường | Nguồn |
|---|---|
| `serviceName` | `spring.application.name` |
| `description`, `structureLevel`, `dbSchema`, `errorCodePrefix` | Khối cấu hình mới `bank.info.*` trong `application.yml` của từng service — một chỗ, đọc bằng `@ConfigurationProperties` |
| `version` | `BuildProperties` (bật goal `build-info` của spring-boot-maven-plugin ở root pom, một lần cho cả reactor); fallback `"unknown"` nếu thiếu |
| `port` | `server.port` |
| `javaVersion` | `Runtime.version()` |
| `springBootVersion` | `SpringBootVersion.getVersion()` |
| `startedAt`, `uptimeSeconds` | `RuntimeMXBean` (start time của JVM) |
| `dependencies` | Đọc `HealthEndpoint` có sẵn của actuator, trích các component (`db`, `redis`, `kafka`…) — **không tự viết health check**. Component không tồn tại → không đưa vào danh sách. |

**Rủi ro đã biết, xử lý lúc lập plan:** Spring Boot không có health indicator sẵn cho
Kafka client thường (chỉ có cho Kafka Streams). Nếu xác nhận đúng vậy ở repo này thì
chọn một trong hai, ưu tiên (a): (a) bảng dependencies của các service dùng Kafka không
có dòng `kafka` — chấp nhận, ghi chú; (b) viết một `HealthIndicator` nhỏ dùng
`KafkaAdmin.describeCluster` với timeout ngắn. Không để plan tự bịa lựa chọn thứ ba.

Mỗi service chép riêng record DTO + controller của mình (đúng luật `bank-common` cấm
REST DTO — quy tắc 3 trong README của nó). Vị trí theo cấu trúc từng service:

| Service | Controller + DTO nằm ở |
|---|---|
| auth, product, notification (Mức B) | `web/` + `web/dto/` |
| core-banking, customer (Mức A) | `api/` + `api/dto/` |

### Gateway — `GET /api/gateway/info`

Gateway không có javalibs nên **không** dùng `ApiResponse` — nó trả JSON cùng hình dạng
envelope bằng record tự viết (vài dòng, không kéo thư viện nào). Payload khác 5 service
kia: không `dbSchema`, không `errorCodePrefix`, không `dependencies`; thay bằng **bảng
route** đọc từ chính cấu hình nó đang chạy (bind `spring.cloud.gateway.server.webmvc.routes`):

```json
{
  "serviceName": "gateway-service",
  "version": "0.1.0-SNAPSHOT",
  "port": 8080,
  "javaVersion": "21.x",
  "springBootVersion": "4.1.0",
  "startedAt": "…",
  "uptimeSeconds": 1234,
  "routes": [
    { "id": "auth", "path": "/api/auth/**", "target": "http://localhost:8081" }
  ]
}
```

### Bảo mật

javalibs-security mặc định chặn mọi thứ ngoài actuator health/info + swagger, và chưa
có API login nào phát JWT → endpoint info **phải** vào `javalibs.security.permit-all`.

**Bẫy đã biết:** `permit-all` là list — khai trong yml sẽ **thay thế** list mặc định,
không phải nối thêm. Mỗi service phải khai lại đủ các đường mặc định
(`/actuator/health`, `/actuator/health/**`, `/actuator/info`, `/error`,
`/v3/api-docs/**`, `/swagger-ui/**`, `/swagger-ui.html`) **cộng** `/api/<prefix>/info`,
kèm comment giải thích vì sao phải chép lại list mặc định.

Thông tin trả về là metadata dev (cổng, schema, version) — chấp nhận công khai ở môi
trường dev này; không trả credential, connection string, hay secret nào.

### Mã lỗi

API chỉ đọc, không có nhánh lỗi nghiệp vụ → **không** thêm mã `ERR-*` mới.
`ERROR-CODES.md` các service giữ nguyên.

## Frontend — `frontend/` (cấp gốc, ngoài reactor Maven)

React + Vite, JavaScript (không TypeScript — dashboard nhỏ, giữ rào vào thấp). UI
tiếng Việt, đồng bộ ngôn ngữ tài liệu repo.

```
frontend/
  package.json          # react, react-dom, vite — không thêm thư viện UI/fetch nào
  vite.config.js
  index.html
  src/
    main.jsx
    App.jsx             # lưới 6 thẻ + vòng refresh 10s
    services.js         # danh mục 6 service: tên hiển thị + đường info — MỘT nguồn sự thật
    api.js              # fetch + timeout ngắn (~3s), lỗi → {status:'DOWN'}
    components/
      ServiceCard.jsx   # thẻ một service: thông tin tĩnh + đèn UP/DOWN + uptime
      RouteTable.jsx    # riêng thẻ gateway: bảng route
```

Hành vi:
- Poll cả 6 endpoint mỗi 10 giây (`Promise.allSettled` — một service chết không kéo
  các thẻ khác chết theo).
- Service không phản hồi/timeout → thẻ chuyển trạng thái **DOWN** (xám + đèn đỏ), giữ
  dữ liệu tĩnh lần cuối thấy được nếu có. Không vỡ trang, không trắng màn hình.
- Không router, không state manager, không thư viện fetch — YAGNI.

Chạy dev: `npm install && npm run dev` trong `frontend/` (backend + compose phải chạy
sẵn). Ghi vào README gốc mục mới "Frontend dashboard".

## Test

- **Mỗi service nghiệp vụ:** một test controller (slice MockMvc) assert: 200, đủ
  trường tĩnh đúng giá trị của service đó, và endpoint đi qua được security không cần
  JWT. Cơ chế slice cụ thể (autoconfig javalibs trong `@WebMvcTest` hoạt động thế nào)
  chốt lúc lập plan — nếu slice không nạp được security thật thì test permit-all chuyển
  sang integration test một service đại diện, các service còn lại chỉ test shape.
- **Gateway:** một test controller cho `/api/gateway/info` (không cần security — gateway
  không có javalibs-security).
- **Frontend:** chưa test ở vòng này — sẽ thêm khi dashboard có logic đáng test.
- TDD theo superpowers cho phần backend.

## Ngoài phạm vi (nói rõ để khỏi trôi)

- Không thêm API login/JWT (auth-service vẫn chưa có nghiệp vụ).
- Không đổi route gateway, không đụng schema DB, không sửa `platform-libs/`.
- Không đưa gì mới vào `bank-common`.
- Không CI cho frontend (CI hiện tại chỉ build Maven; thêm bước node là việc khác).
- Không phục vụ frontend từ gateway (phương án B đã bị loại có chủ đích).
