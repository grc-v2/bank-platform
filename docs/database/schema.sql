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
CREATE TABLE individual_details (
    customer_id    BIGINT       PRIMARY KEY REFERENCES customers (id) ON DELETE CASCADE,
    first_name     VARCHAR(100) NOT NULL,
    last_name      VARCHAR(100) NOT NULL,
    date_of_birth  DATE         NOT NULL,
    gender         VARCHAR(10),
    nationality    CHAR(2)      NOT NULL DEFAULT 'VN',
    occupation     VARCHAR(100),
    marital_status VARCHAR(20),
    CONSTRAINT ck_individual_gender  CHECK (gender IS NULL OR gender IN ('MALE', 'FEMALE', 'OTHER')),
    CONSTRAINT ck_individual_marital CHECK (marital_status IS NULL OR marital_status IN ('SINGLE', 'MARRIED', 'DIVORCED', 'WIDOWED')),
    CONSTRAINT ck_individual_dob     CHECK (date_of_birth < CURRENT_DATE)
);

CREATE TABLE organization_details (
    customer_id        BIGINT       PRIMARY KEY REFERENCES customers (id) ON DELETE CASCADE,
    legal_name         VARCHAR(200) NOT NULL,
    trade_name         VARCHAR(200),
    tax_code           VARCHAR(20)  NOT NULL,
    incorporation_date DATE,
    business_type      VARCHAR(100),
    CONSTRAINT uq_organization_tax_code UNIQUE (tax_code)
);

CREATE TABLE customer_identifications (
    id           BIGSERIAL    PRIMARY KEY,
    customer_id  BIGINT       NOT NULL REFERENCES customers (id) ON DELETE CASCADE,
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
    customer_id   BIGINT       NOT NULL REFERENCES customers (id) ON DELETE CASCADE,
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
    kyc_verification_id BIGINT       NOT NULL REFERENCES kyc_verifications (id) ON DELETE CASCADE,
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
    customer_id BIGINT      NOT NULL REFERENCES customers (id) ON DELETE CASCADE,
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
CREATE INDEX idx_contact_customer    ON customer_contacts (customer_id);
CREATE INDEX idx_kyc_customer        ON kyc_verifications (customer_id, submitted_at DESC);
CREATE INDEX idx_kyc_open            ON kyc_verifications (submitted_at) WHERE status IN ('PENDING', 'IN_REVIEW');
CREATE INDEX idx_kycdoc_verification ON kyc_documents (kyc_verification_id);
CREATE INDEX idx_risk_customer       ON customer_risk_assessments (customer_id, assessed_at DESC);
CREATE INDEX idx_cust_outbox_unpub   ON outbox (created_at) WHERE published_at IS NULL;

RESET ROLE;
SET search_path = public;

-- <<< HẾT KHỐI [3]
