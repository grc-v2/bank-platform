# gateway-service

Cổng vào duy nhất cho frontend. **Chỉ định tuyến** — không nghiệp vụ, không chạm DB.

- **Cổng:** 8080
- **Không có schema DB.**

## Xác thực nằm ở đâu

Gateway **không** kiểm JWT, và từ 2026-09-01 **cũng không service nào phía sau kiểm** — Spring Security đã gỡ cùng platform-libs (xem docs/KNOWN-LIMITATIONS.md). Hiện toàn hệ thống không có xác thực.

Khi dựng lại: đặt việc kiểm token ở **từng service**, không phải ở gateway. Gateway kiểm hộ thì bất kỳ ai gọi thẳng vào service (trong cùng cluster) đều bỏ qua được xác thực. Gateway chỉ là tiện ích định tuyến, không phải ranh giới tin cậy.

## Tình trạng tương thích Spring Cloud

Spring Cloud đi theo release train riêng, bám sát version Spring Boot.

- **Đã kiểm (2026-08-09):** Dùng `maven-metadata.xml` của `spring-cloud-dependencies` trên Maven Central (không dùng API solr của search.maven.org — API đó trả danh sách không sắp theo thời gian và có thể báo nhầm bản cũ là mới nhất). `<latest>`/`<release>` đều là `2025.1.2`. POM của `spring-cloud-dependencies:2025.1.2` khai `spring-boot.version` = `4.0.7` (không có bản GA nào của Spring Cloud khai Boot 4.1.x tính đến thời điểm kiểm). Theo bảng quyết định trong task brief, đây là dòng "chỉ có bản cho Boot 4.0.x": build thử bằng version đó, chưa lỗi thì đi tiếp.
- **Đang dùng:** `spring-cloud-dependencies:2025.1.2` (quản lý `spring-cloud-gateway` 5.0.2), trong khi repo chạy `spring-boot-starter-parent:4.1.0`.
- **Kết quả build/khởi động thật:** `mvn -B -P'!with-libs' clean install` cho `BUILD SUCCESS` với đủ 8 module (root + 7). Xác minh bằng `mvn -pl services/gateway-service dependency:tree`: mọi artifact `org.springframework.boot:*` phân giải ở **4.1.0** (không phải 4.0.7), còn mọi artifact `org.springframework.cloud:*` phân giải ở **5.0.2**. Gateway khởi động thành công, `/actuator/health` trả `UP`.
- **Vì sao Boot ra 4.1.0 chứ không phải 4.0.7 (cơ chế thật, đừng đoán lại):** `spring-cloud-dependencies:2025.1.2` **chỉ** quản lý artifact nhóm `org.springframework.cloud`. Nó không import `spring-boot-dependencies`; `grep -c "org.springframework.boot"` trên chính POM đó **và** trên POM cha `spring-cloud-dependencies-parent:5.0.2` đều trả `0`. Vậy nên không hề có version Boot nào từ phía Spring Cloud để tranh chấp — 4.1.0 từ `spring-boot-starter-parent` là version duy nhất có mặt, không phải version "thắng". Thuộc tính `<spring-boot.version>4.0.7</spring-boot.version>` bên trong POM đó được *khai* nhưng không được *tham chiếu* ở đâu trong chính file ấy: nó ghi lại dòng Boot mà train được kiểm thử cùng, là tài liệu chứ không phải cơ chế ghim version. **Quy tắc rút ra:** một BOM import chỉ ghim đúng những artifact nó thực sự quản lý — mở POM của BOM ra xem trước khi kết luận nó đang đánh nhau với parent.
- **Lưới an toàn (đã kiểm bằng thực nghiệm):** kể cả khi một train tương lai *có* import `spring-boot-dependencies`, `dependencyManagement` thừa kế từ parent vẫn thắng BOM import ở POM con. POM thử với parent `spring-boot-starter-parent:4.1.0` tự import `spring-boot-dependencies:4.0.7` rồi chạy `dependency:tree` cho ra mọi artifact Boot ở **4.1.0**.
- **Phát hiện thêm (không phải lỗi tương thích Boot/Cloud):** `spring-cloud-starter-gateway-server-webmvc` (bản servlet) đọc cấu hình route ở prefix `spring.cloud.gateway.server.webmvc`, KHÔNG phải `spring.cloud.gateway` như bản reactive — xác minh bằng cách đọc trực tiếp annotation `@ConfigurationProperties` trên class `GatewayMvcProperties` trong file `.jar`. Đồng thời, bản webmvc **không có endpoint actuator "gateway"** (không có class nào gắn `@Endpoint` trong toàn bộ jar `spring-cloud-gateway-server-webmvc-5.0.2.jar`) — khác với bản reactive vốn có `/actuator/gateway/routes`. Vì vậy `curl http://localhost:8080/actuator/gateway/routes` luôn trả `404`, bất kể route có đăng ký đúng hay không; đây là đặc tính có chủ đích của module, không phải lỗi cấu hình. Xác minh route hoạt động thật bằng cách khác: log khởi động ở mức DEBUG cho thấy `RouterFunctionHolderFactory` khớp đủ 5 route, và gọi `curl http://localhost:8080/api/auth/foo` (lúc auth-service chưa chạy) trả `500` kèm `ResourceAccessException: I/O error on GET request for "http://localhost:8081/api/auth/foo"` — chứng minh gateway đã cố proxy đúng địa chỉ, khác hẳn với gọi một path không khớp predicate nào (`404` từ Spring MVC).
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
curl -s http://localhost:8080/actuator/health
# /actuator/gateway/routes KHÔNG tồn tại trên bản webmvc (xem phần "Tình trạng tương thích" ở trên).
# Muốn thấy route đã đăng ký: chạy với profile local (bật DEBUG cho
# org.springframework.cloud.gateway) và đọc log khởi động, hoặc gọi thử một
# path khớp route (vd. /api/auth/xyz) và quan sát gateway cố proxy sang đúng cổng backend.
```
