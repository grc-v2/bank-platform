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

## Persistence

Entity + repository map 5/6 bảng của schema `notification` (schema.sql khối [6]):

| Bảng | Entity | Repository |
|---|---|---|
| `notification_templates` | `model.NotificationTemplate` | `repository.NotificationTemplateRepository` (+ `findByTemplateCodeAndChannelAndLocaleAndVersion`) |
| `notifications` | `model.Notification` | `repository.NotificationRepository` (không finder thêm — L9) |
| `delivery_attempts` | `model.DeliveryAttempt` (append-only, không setter) | `repository.DeliveryAttemptRepository` (+ `findByNotificationIdAndAttemptNo`) |
| `webhook_endpoints` | `model.WebhookEndpoint` | `repository.WebhookEndpointRepository` (+ `findByUserIdAndUrl`) |
| `user_notification_preferences` | `model.NotificationPreference` (`@EmbeddedId model.NotificationPreferenceId`) | `repository.NotificationPreferenceRepository` |

**`processed_events` KHÔNG được map** (quyết định L1 của kế hoạch entity+repository toàn hệ thống). Đây là bảng hạ tầng của vòng idempotent-consumer, mà hạ tầng đó chưa tồn tại: `javalibs-datahub` đã gỡ cùng platform-libs và bản thay thế chưa viết. Map bây giờ là đoán trước hình dạng của một cơ chế chưa thiết kế. Hibernate `ddl-auto: validate` không đụng bảng không map nên không ảnh hưởng khởi động. Sẽ map lại khi viết consumer thật.

Điểm mapping đáng chú ý khác:

- `NotificationChannel` (TELEGRAM/EMAIL/WEBHOOK) là MỘT enum dùng chung cho `notification_templates`, `notifications` và `user_notification_preferences` — cả ba bảng lặp lại đúng một CHECK, không tách theo bảng.
- `notifications.user_id` và `webhook_endpoints.user_id` là cột `Long` thường, KHÔNG association sang `auth.users` — tham chiếu MỀM, xuyên schema, đúng nguyên tắc "chỉ nghe event" của service này.
- `DeliveryAttempt` cố ý KHÔNG nằm trong aggregate `Notification`: job retry ghi attempt không cần load lại Notification, `notificationId` là cột `Long` thường. Bảng append-only nên entity không có setter.
- `notifications.status` là trường DUY NHẤT app cập nhật sau khi tạo (có setter) — bản thân bảng `notifications`/`delivery_attempts` vẫn append-only về mặt audit lịch sử gửi.
- `notifications.payload` (JSONB NOT NULL) map bằng `String` + `@JdbcTypeCode(SqlTypes.JSON)` theo đúng quy ước chung — round-trip qua Testcontainers Postgres pass ngay lần đầu.
- `user_notification_preferences` PK ghép 3 cột (`user_id`, `event_type`, `channel`) map bằng `@EmbeddedId model.NotificationPreferenceId`. `updated_at` của bảng này do DB giữ qua trigger riêng `trg_prefs_updated_at` (khác với `created_at` DEFAULT thông thường ở 4 bảng còn lại) — vẫn cùng một khuôn `@Generated` + `insertable=false, updatable=false`.
- `webhook_endpoints.secret` chỉ là field thường, không annotation ẩn giá trị — kỷ luật "không log secret" nằm ở tầng gọi (service/logging), không phải trách nhiệm của entity.

Test mapping: `NotificationPersistenceMappingTest` (round-trip từng bảng đã map qua Testcontainers, `docs/database/schema.sql` nạp thật vào container qua `AbstractIntegrationTest`). `ServiceInfoApiTest` cũng đổi sang extends `AbstractIntegrationTest` vì từ nay Spring context nào cũng cần schema `notification` tồn tại sẵn để `ddl-auto: validate` không chết lúc khởi động.

## Chạy local

```bash
docker compose up -d postgres kafka
mvn -pl services/notification-service -am spring-boot:run -Dspring-boot.run.profiles=local
```

## Migration

`db/migration/` rỗng, `spring.flyway.enabled=false`. Schema do `docs/database/schema.sql` khối `[6]` dựng.
