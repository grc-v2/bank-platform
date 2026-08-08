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
