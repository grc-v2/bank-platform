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
