-- notification / V1__notification_init.sql — ĐÁP ÁN MẪU, copy vào notification-service khi vào M3
-- (Flyway: schemas=notification, user noti_svc)
-- Nguyên tắc: service này chỉ NGHE event — mọi dữ liệu cần thiết phải nằm trong payload.

-- Xương sống idempotent consumer: "không báo hai lần" là em ruột của "không trừ hai lần".
-- INSERT vào đây phải nằm CÙNG transaction với việc tạo notification;
-- trùng event_id -> đã xử lý -> bỏ qua message (at-least-once của Kafka được thuần hóa tại đây).
CREATE TABLE processed_events (
    event_id     VARCHAR(64)  PRIMARY KEY,
    processed_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE notifications (
    id         BIGSERIAL PRIMARY KEY,
    -- Tham chiếu mềm sang auth.users — KHÔNG FK xuyên schema (DATABASE-DESIGN §1.2)
    user_id    BIGINT       NOT NULL,
    event_type VARCHAR(50)  NOT NULL,          -- vd: transfer.completed, balance.low
    channel    VARCHAR(20)  NOT NULL CHECK (channel IN ('TELEGRAM', 'EMAIL', 'WEBHOOK')),
    -- Mỗi loại thông báo một hình dạng dữ liệu — chỗ dùng hợp lệ hiếm hoi của JSONB
    payload    JSONB        NOT NULL,
    status     VARCHAR(20)  NOT NULL DEFAULT 'PENDING'
               CHECK (status IN ('PENDING', 'SENT', 'FAILED')),
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- Tách attempts khỏi notifications: một thông báo nhiều lần thử,
-- lịch sử retry đọc được — nuôi dashboard M5 (tỉ lệ fail theo kênh).
CREATE TABLE delivery_attempts (
    id              BIGSERIAL PRIMARY KEY,
    notification_id BIGINT      NOT NULL REFERENCES notifications (id) ON DELETE CASCADE,
    attempt_no      INT         NOT NULL,
    status          VARCHAR(20) NOT NULL CHECK (status IN ('SUCCESS', 'FAILED')),
    error           VARCHAR(1000),
    at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (notification_id, attempt_no)
);

-- URL do user nhập = bề mặt SSRF chính của M3 (InetAddressFilter + test vector).
-- secret dùng ký HMAC payload để endpoint nhận xác minh nguồn — chuẩn webhook.
CREATE TABLE webhook_endpoints (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT        NOT NULL,           -- tham chiếu mềm
    url             VARCHAR(2048) NOT NULL,
    secret          VARCHAR(64)   NOT NULL,
    active          BOOLEAN       NOT NULL DEFAULT TRUE,
    last_status     INT,
    last_checked_at TIMESTAMPTZ,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT now(),
    UNIQUE (user_id, url)
);

CREATE INDEX idx_noti_user_at   ON notifications (user_id, created_at DESC);
CREATE INDEX idx_noti_status    ON notifications (status) WHERE status = 'PENDING';  -- partial: worker chỉ quét PENDING
CREATE INDEX idx_attempts_noti  ON delivery_attempts (notification_id);
CREATE INDEX idx_webhook_user   ON webhook_endpoints (user_id);
