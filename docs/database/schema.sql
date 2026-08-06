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
    -- Khoá phụ này tồn tại CHỈ để hai bảng chi tiết bên dưới FK vào được theo cặp
    -- (id, customer_type). Nhờ nó, DB tự chặn việc gắn hồ sơ tổ chức cho khách
    -- hàng cá nhân — mẫu "disjoint subtype" kinh điển của mô hình party.
    CONSTRAINT uq_customers_id_type   UNIQUE (id, customer_type),
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
-- customer_type lặp lại ở bảng con KHÔNG phải dư thừa: nó là nửa còn lại của FK
-- theo cặp. CHECK ghim nó bằng 'INDIVIDUAL', FK bắt cặp phải khớp customers,
-- nên một khách hàng ORGANIZATION không thể có dòng ở đây. DB tự chặn, không
-- cần trigger, không đẩy bất biến sang code chưa viết.
CREATE TABLE individual_details (
    customer_id    BIGINT       PRIMARY KEY,
    customer_type  VARCHAR(20)  NOT NULL DEFAULT 'INDIVIDUAL',
    first_name     VARCHAR(100) NOT NULL,
    last_name      VARCHAR(100) NOT NULL,
    date_of_birth  DATE         NOT NULL,
    gender         VARCHAR(10),
    nationality    CHAR(2)      NOT NULL DEFAULT 'VN',
    occupation     VARCHAR(100),
    marital_status VARCHAR(20),
    CONSTRAINT fk_individual_customer FOREIGN KEY (customer_id, customer_type)
        REFERENCES customers (id, customer_type) ON DELETE CASCADE,
    CONSTRAINT ck_individual_type    CHECK (customer_type = 'INDIVIDUAL'),
    CONSTRAINT ck_individual_gender  CHECK (gender IS NULL OR gender IN ('MALE', 'FEMALE', 'OTHER')),
    CONSTRAINT ck_individual_marital CHECK (marital_status IS NULL OR marital_status IN ('SINGLE', 'MARRIED', 'DIVORCED', 'WIDOWED')),
    CONSTRAINT ck_individual_dob     CHECK (date_of_birth < CURRENT_DATE)
);

CREATE TABLE organization_details (
    customer_id        BIGINT       PRIMARY KEY,
    customer_type      VARCHAR(20)  NOT NULL DEFAULT 'ORGANIZATION',
    legal_name         VARCHAR(200) NOT NULL,
    trade_name         VARCHAR(200),
    tax_code           VARCHAR(20)  NOT NULL,
    incorporation_date DATE,
    business_type      VARCHAR(100),
    CONSTRAINT fk_organization_customer FOREIGN KEY (customer_id, customer_type)
        REFERENCES customers (id, customer_type) ON DELETE CASCADE,
    CONSTRAINT ck_organization_type     CHECK (customer_type = 'ORGANIZATION'),
    CONSTRAINT uq_organization_tax_code UNIQUE (tax_code)
);

-- KHÔNG CASCADE. Bốn bảng tiếp theo (giấy tờ, KYC, tài liệu KYC, đánh giá rủi ro)
-- là BẰNG CHỨNG TUÂN THỦ: chúng phải sống sót qua việc đóng hồ sơ khách hàng, vì
-- nghĩa vụ lưu trữ KYC/AML không kết thúc khi quan hệ với khách hàng kết thúc.
-- Hệ quả cố ý: `DELETE FROM customers` sẽ bị FK từ chối. Đóng khách hàng đi bằng
-- `status = 'CLOSED'`, không xoá vật lý. Nếu thật sự phải xoá (yêu cầu xoá dữ liệu
-- cá nhân), đó là một quy trình có phê duyệt, không phải một câu lệnh DELETE.
CREATE TABLE customer_identifications (
    id           BIGSERIAL    PRIMARY KEY,
    customer_id  BIGINT       NOT NULL REFERENCES customers (id),
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
    customer_id   BIGINT       NOT NULL REFERENCES customers (id),
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
    kyc_verification_id BIGINT       NOT NULL REFERENCES kyc_verifications (id),
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
    customer_id BIGINT      NOT NULL REFERENCES customers (id),
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
-- Mỗi khách hàng, mỗi loại địa chỉ, tại một thời điểm chỉ có MỘT dòng đang hiệu lực.
-- Không có ràng buộc này thì hai dòng cùng valid_to IS NULL là hợp lệ với DB, và
-- truy vấn "địa chỉ tại ngày X" không còn đảm bảo trả về đúng một kết quả — đúng
-- cái làm hỏng việc in sao kê theo địa chỉ tại kỳ đó.
CREATE UNIQUE INDEX uq_address_current ON customer_addresses (customer_id, address_type)
    WHERE valid_to IS NULL;
CREATE INDEX idx_contact_customer    ON customer_contacts (customer_id);
CREATE INDEX idx_kyc_customer        ON kyc_verifications (customer_id, submitted_at DESC);
CREATE INDEX idx_kyc_open            ON kyc_verifications (submitted_at) WHERE status IN ('PENDING', 'IN_REVIEW');
CREATE INDEX idx_kycdoc_verification ON kyc_documents (kyc_verification_id);
CREATE INDEX idx_risk_customer       ON customer_risk_assessments (customer_id, assessed_at DESC);
CREATE INDEX idx_cust_outbox_unpub   ON outbox (created_at) WHERE published_at IS NULL;

RESET ROLE;
SET search_path = public;

-- <<< HẾT KHỐI [3]

-- ---------------------------------------------------------------------
-- [4] SCHEMA product — nơi NGHIỆP VỤ SỐNG.
--     Lãi suất, biểu phí, hạn mức, điều kiện mở: tất cả là DỮ LIỆU, không phải
--     hằng số trong code. Đổi biểu phí không được phép là một lần deploy.
--
--     Mọi bảng GIÁ TRỊ (rates, fees, limits, gl_mappings) đều có effective_from/
--     effective_to: đổi thì THÊM DÒNG, không sửa dòng cũ — nếu không, sao kê tháng
--     trước tính lại sẽ ra số khác. Riêng product_eligibility_rules CỐ Ý không có:
--     điều kiện mở tài khoản chỉ được đánh giá tại thời điểm mở, không cần tra ngược.
--
--     Ràng buộc "không hai dòng cùng hiệu lực" KHÔNG phải UNIQUE trên effective_from
--     — cái đó chỉ chặn trùng đúng ngày bắt đầu. Phải là EXCLUDE trên khoảng ngày.
-- ---------------------------------------------------------------------

-- btree_gist cho phép trộn toán tử '=' (trên BIGINT, VARCHAR) với '&&' (trên
-- daterange) trong cùng một EXCLUDE. Chạy dưới quyền superuser, TRƯỚC SET ROLE.
CREATE EXTENSION IF NOT EXISTS btree_gist;

SET ROLE product_svc;
SET search_path = product;

CREATE TABLE products (
    id             BIGSERIAL     PRIMARY KEY,
    product_code   VARCHAR(30)   NOT NULL,
    name           VARCHAR(200)  NOT NULL,
    category       VARCHAR(30)   NOT NULL,
    currency       CHAR(3)       NOT NULL DEFAULT 'VND',
    status         VARCHAR(20)   NOT NULL DEFAULT 'DRAFT',
    description    VARCHAR(1000),
    effective_from DATE          NOT NULL DEFAULT CURRENT_DATE,
    effective_to   DATE,
    created_at     TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT uq_products_code     UNIQUE (product_code),
    CONSTRAINT ck_products_category CHECK (category IN ('CURRENT_ACCOUNT', 'SAVINGS_ACCOUNT', 'TERM_DEPOSIT')),
    CONSTRAINT ck_products_status   CHECK (status IN ('DRAFT', 'ACTIVE', 'RETIRED')),
    CONSTRAINT ck_products_period   CHECK (effective_to IS NULL OR effective_to > effective_from)
);

-- Lãi suất BẬC THANG: theo số dư (tier_from/tier_to) hoặc theo kỳ hạn (term_months).
CREATE TABLE product_interest_rates (
    id             BIGSERIAL     PRIMARY KEY,
    product_id     BIGINT        NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    tier_from      NUMERIC(19,4) NOT NULL DEFAULT 0,
    tier_to        NUMERIC(19,4),
    term_months    INT,
    annual_rate    NUMERIC(9,6)  NOT NULL,
    effective_from DATE          NOT NULL DEFAULT CURRENT_DATE,
    effective_to   DATE,
    CONSTRAINT ck_rate_tier   CHECK (tier_to IS NULL OR tier_to > tier_from),
    CONSTRAINT ck_rate_value  CHECK (annual_rate >= 0 AND annual_rate < 1),
    CONSTRAINT ck_rate_term   CHECK (term_months IS NULL OR term_months > 0),
    CONSTRAINT ck_rate_period CHECK (effective_to IS NULL OR effective_to > effective_from)
);
COMMENT ON COLUMN product_interest_rates.annual_rate IS
    'Tỉ lệ thập phân: 0.045000 = 4.5%/năm. CHECK < 1 chặn lỗi nhập 4.5 thay vì 0.045';
COMMENT ON COLUMN product_interest_rates.tier_to IS
    'NULL = bậc cao nhất, không giới hạn trên';
COMMENT ON COLUMN product_interest_rates.term_months IS
    'NULL với sản phẩm không kỳ hạn. BẤT BIẾN DO ỨNG DỤNG GIỮ: TERM_DEPOSIT phải có term_months, CURRENT/SAVINGS phải không — CHECK không với sang bảng products được nên DB không chặn nổi';

CREATE TABLE product_fees (
    id             BIGSERIAL     PRIMARY KEY,
    product_id     BIGINT        NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    fee_code       VARCHAR(30)   NOT NULL,
    fee_type       VARCHAR(20)   NOT NULL,
    amount         NUMERIC(19,4),
    percent        NUMERIC(9,6),
    min_amount     NUMERIC(19,4),
    max_amount     NUMERIC(19,4),
    charge_event   VARCHAR(40)   NOT NULL,
    currency       CHAR(3)       NOT NULL DEFAULT 'VND',
    effective_from DATE          NOT NULL DEFAULT CURRENT_DATE,
    effective_to   DATE,
    -- TIERED CỐ Ý KHÔNG có trong danh sách: phí bậc thang cần một bảng
    -- product_fee_tiers để chứa các bậc, mà bảng đó chưa tồn tại. Thêm một enum
    -- value không dùng được chỉ tạo ra một lỗ trong ck_fee_shape. Khi nào thực sự
    -- cần phí bậc thang thì thêm bảng tier TRƯỚC, rồi mới mở enum.
    CONSTRAINT ck_fee_type  CHECK (fee_type IN ('FLAT', 'PERCENT')),
    CONSTRAINT ck_fee_event CHECK (charge_event IN (
        'ACCOUNT_OPEN', 'ACCOUNT_CLOSE', 'MONTHLY_MAINTENANCE',
        'INTERNAL_TRANSFER', 'EXTERNAL_TRANSFER', 'ATM_WITHDRAWAL', 'STATEMENT_REQUEST')),
    CONSTRAINT ck_fee_shape CHECK (
           (fee_type = 'FLAT'    AND amount  IS NOT NULL AND percent IS NULL)
        OR (fee_type = 'PERCENT' AND percent IS NOT NULL AND amount  IS NULL)),
    CONSTRAINT ck_fee_bounds CHECK (min_amount IS NULL OR max_amount IS NULL OR max_amount >= min_amount),
    CONSTRAINT uq_fee UNIQUE (product_id, fee_code, effective_from),
    -- Hai biểu phí cùng fee_code không được PHỦ NHAU về thời gian. UNIQUE trên
    -- effective_from chỉ chặn trùng đúng ngày bắt đầu, không chặn được
    -- (01/01 -> 31/12) chồng lên (01/06 -> mở) — và khi đó không ai trả lời được
    -- tháng 6 thu phí theo dòng nào.
    CONSTRAINT ex_fee_overlap EXCLUDE USING gist (
        product_id WITH =,
        fee_code   WITH =,
        daterange(effective_from, effective_to, '[)') WITH &&)
);
COMMENT ON CONSTRAINT ck_fee_shape ON product_fees IS
    'FLAT dùng amount, PERCENT dùng percent — không cho điền cả hai rồi cãi nhau cái nào thắng';

CREATE TABLE product_limits (
    id             BIGSERIAL     PRIMARY KEY,
    product_id     BIGINT        NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    limit_code     VARCHAR(30)   NOT NULL,
    scope          VARCHAR(20)   NOT NULL,
    channel        VARCHAR(20)   NOT NULL DEFAULT 'ANY',
    max_amount     NUMERIC(19,4),
    max_count      INT,
    currency       CHAR(3)       NOT NULL DEFAULT 'VND',
    effective_from DATE          NOT NULL DEFAULT CURRENT_DATE,
    effective_to   DATE,
    CONSTRAINT ck_limit_scope   CHECK (scope IN ('PER_TRANSACTION', 'PER_DAY', 'PER_MONTH')),
    CONSTRAINT ck_limit_channel CHECK (channel IN ('ANY', 'INTERNET', 'MOBILE', 'ATM', 'BRANCH')),
    CONSTRAINT ck_limit_value   CHECK (max_amount IS NOT NULL OR max_count IS NOT NULL),
    CONSTRAINT uq_limit UNIQUE (product_id, limit_code, effective_from),
    -- Cùng lý do như ex_fee_overlap: hai hạn mức cùng mã không được phủ nhau.
    -- channel nằm trong khoá vì cùng một limit_code có thể khác nhau theo kênh.
    CONSTRAINT ex_limit_overlap EXCLUDE USING gist (
        product_id WITH =,
        limit_code WITH =,
        channel    WITH =,
        daterange(effective_from, effective_to, '[)') WITH &&)
);
COMMENT ON TABLE product_limits IS
    'Khuôn hạn mức theo sản phẩm. Mức đã dùng thực tế nằm ở core_banking.transfer_limit_usage';

CREATE TABLE product_eligibility_rules (
    id         BIGSERIAL    PRIMARY KEY,
    product_id BIGINT       NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    rule_type  VARCHAR(30)  NOT NULL,
    operator   VARCHAR(10)  NOT NULL,
    rule_value VARCHAR(100) NOT NULL,
    CONSTRAINT ck_rule_type     CHECK (rule_type IN ('MIN_AGE', 'MAX_AGE', 'MIN_KYC_LEVEL', 'CUSTOMER_TYPE', 'MAX_RISK_RATING')),
    CONSTRAINT ck_rule_operator CHECK (operator IN ('EQ', 'NEQ', 'GTE', 'LTE', 'IN')),
    CONSTRAINT uq_rule UNIQUE (product_id, rule_type)
);

-- CẦU NỐI QUAN TRỌNG NHẤT giữa product và sổ cái: sản phẩm nào thì gốc hạch
-- toán vào GL nào, lãi phải trả vào GL nào, phí thu vào GL nào.
-- Không có bảng này thì mã GL bị hardcode trong code — lỗi kinh điển của
-- core banking tự viết, và là thứ khiến việc thêm sản phẩm mới phải sửa code.
-- CÓ effective_from/effective_to, và đó là điểm quan trọng nhất của bảng này.
-- Nếu chỉ UNIQUE (product_id, purpose) thì đổi mã GL buộc phải UPDATE dòng cũ —
-- và ngay lúc đó mất khả năng trả lời "giao dịch tháng trước hạch toán vào tài
-- khoản nào". Với sổ cái, mất lịch sử ánh xạ là mất khả năng đối chiếu kỳ cũ.
CREATE TABLE product_gl_mappings (
    id             BIGSERIAL   PRIMARY KEY,
    product_id     BIGINT      NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    purpose        VARCHAR(30) NOT NULL,
    gl_code        VARCHAR(20) NOT NULL,
    effective_from DATE        NOT NULL DEFAULT CURRENT_DATE,
    effective_to   DATE,
    CONSTRAINT ck_glmap_purpose CHECK (purpose IN ('PRINCIPAL', 'INTEREST_PAYABLE', 'INTEREST_EXPENSE', 'FEE_INCOME')),
    CONSTRAINT ck_glmap_period  CHECK (effective_to IS NULL OR effective_to > effective_from),
    CONSTRAINT uq_glmap UNIQUE (product_id, purpose, effective_from),
    CONSTRAINT ex_glmap_overlap EXCLUDE USING gist (
        product_id WITH =,
        purpose    WITH =,
        daterange(effective_from, effective_to, '[)') WITH &&)
);
COMMENT ON COLUMN product_gl_mappings.gl_code IS
    'Tham chiếu MỀM sang core_banking.gl_accounts.gl_code — không FK xuyên schema';

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
    'Phát product.activated.v1 / product.retired.v1 để service khác vô hiệu cache catalog. Độc lập với outbox của customer và core_banking';

CREATE INDEX idx_products_status      ON products (status) WHERE status = 'ACTIVE';
CREATE INDEX idx_rates_product        ON product_interest_rates (product_id, effective_from DESC);
CREATE INDEX idx_fees_product         ON product_fees (product_id, charge_event);
CREATE INDEX idx_limits_product       ON product_limits (product_id, scope, channel);
CREATE INDEX idx_rules_product        ON product_eligibility_rules (product_id);
CREATE INDEX idx_glmap_product        ON product_gl_mappings (product_id);
CREATE INDEX idx_prod_outbox_unpub    ON outbox (created_at) WHERE published_at IS NULL;

RESET ROLE;
SET search_path = public;

-- <<< HẾT KHỐI [4]

-- =====================================================================
-- [5] SCHEMA core_banking — TRÁI TIM.
--     Thứ tự tạo bảng trong khối này là BẮT BUỘC: gl_accounts trước (mọi thứ
--     FK vào gl_code), rồi accounts, rồi sổ cái, rồi giao dịch.
-- =====================================================================
SET ROLE core_svc;
SET search_path = core_banking;

-- ---------------------------------------------------------------------
-- [5a] Chart of accounts, tài khoản khách hàng, hold
-- ---------------------------------------------------------------------

-- SỔ CÁI. Phân biệt với accounts: gl_accounts là sổ cái của ngân hàng,
-- accounts là sổ phụ của khách hàng. Số dư mọi tài khoản khách hàng của cùng
-- một sản phẩm cộng lại phải bằng số dư GL tương ứng — đó là phép đối chiếu
-- cơ bản nhất của core banking.
CREATE TABLE gl_accounts (
    id             BIGSERIAL    PRIMARY KEY,
    gl_code        VARCHAR(20)  NOT NULL,
    name           VARCHAR(200) NOT NULL,
    account_class  VARCHAR(20)  NOT NULL,
    normal_balance VARCHAR(6)   NOT NULL,
    parent_gl_code VARCHAR(20)  REFERENCES gl_accounts (gl_code),
    is_postable    BOOLEAN      NOT NULL DEFAULT TRUE,
    currency       CHAR(3)      NOT NULL DEFAULT 'VND',
    status         VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE',
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    -- UNIQUE đặt tên tường minh: accounts.gl_code và journal_lines.gl_code đều
    -- FK vào cột này, nên nó là một hợp đồng công khai chứ không phải chi tiết nội bộ.
    CONSTRAINT uq_gl_code   UNIQUE (gl_code),
    CONSTRAINT ck_gl_class  CHECK (account_class IN ('ASSET', 'LIABILITY', 'EQUITY', 'INCOME', 'EXPENSE')),
    CONSTRAINT ck_gl_normal CHECK (normal_balance IN ('DEBIT', 'CREDIT')),
    CONSTRAINT ck_gl_status CHECK (status IN ('ACTIVE', 'CLOSED')),
    -- Nguyên lý kế toán kép, viết thành ràng buộc thay vì để trong đầu người ta:
    -- TÀI SẢN và CHI PHÍ tăng bên NỢ; NỢ PHẢI TRẢ, VỐN và THU NHẬP tăng bên CÓ.
    CONSTRAINT ck_gl_class_normal CHECK (
           (account_class IN ('ASSET', 'EXPENSE')              AND normal_balance = 'DEBIT')
        OR (account_class IN ('LIABILITY', 'EQUITY', 'INCOME') AND normal_balance = 'CREDIT'))
);
COMMENT ON COLUMN gl_accounts.is_postable IS
    'FALSE = tài khoản tổng hợp, chỉ để gom số. Hạch toán thẳng vào nó là sai';

CREATE TABLE accounts (
    id                  BIGSERIAL     PRIMARY KEY,
    account_number      VARCHAR(20)   NOT NULL,
    product_code        VARCHAR(30)   NOT NULL,
    primary_customer_id BIGINT        NOT NULL,
    currency            CHAR(3)       NOT NULL DEFAULT 'VND',
    status              VARCHAR(20)   NOT NULL DEFAULT 'PENDING',
    gl_code             VARCHAR(20)   NOT NULL REFERENCES gl_accounts (gl_code),
    ledger_balance      NUMERIC(19,4) NOT NULL DEFAULT 0,
    hold_amount         NUMERIC(19,4) NOT NULL DEFAULT 0,
    available_balance   NUMERIC(19,4) GENERATED ALWAYS AS (ledger_balance - hold_amount) STORED,
    overdraft_limit     NUMERIC(19,4) NOT NULL DEFAULT 0,
    version             INT           NOT NULL DEFAULT 0,
    opened_at           TIMESTAMPTZ,
    closed_at           TIMESTAMPTZ,
    created_at          TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT uq_accounts_number    UNIQUE (account_number),
    CONSTRAINT ck_accounts_status    CHECK (status IN ('PENDING', 'ACTIVE', 'DORMANT', 'FROZEN', 'CLOSED')),
    CONSTRAINT ck_accounts_hold      CHECK (hold_amount >= 0),
    CONSTRAINT ck_accounts_overdraft CHECK (overdraft_limit >= 0),
    -- Viết bằng biểu thức GỐC chứ không tham chiếu cột available_balance.
    -- (Postgres CHO PHÉP CHECK tham chiếu cột GENERATED STORED — đã kiểm chứng.)
    -- Lý do là tính độc lập: ràng buộc đọc được mà không cần biết
    -- available_balance được định nghĩa thế nào, và không phụ thuộc thứ tự tính cột.
    CONSTRAINT ck_accounts_available CHECK (ledger_balance - hold_amount >= -overdraft_limit),
    CONSTRAINT ck_accounts_closed    CHECK (status <> 'CLOSED' OR closed_at IS NOT NULL)
);
COMMENT ON TABLE accounts IS
    'CHỈ tài khoản khách hàng. KHÔNG có tài khoản SYSTEM (quyết định DB3): phía nội bộ của bút toán đi thẳng vào gl_code với account_id NULL';
COMMENT ON COLUMN accounts.product_code IS
    'Tham chiếu MỀM sang product.products.product_code';
COMMENT ON COLUMN accounts.primary_customer_id IS
    'Tham chiếu MỀM sang customer.customers.id. Cố ý trùng lặp với dòng PRIMARY trong account_holders để truy vấn "tài khoản của tôi" không phải join. BẤT BIẾN do ứng dụng giữ: luôn tồn tại account_holders(id, primary_customer_id, PRIMARY)';
COMMENT ON COLUMN accounts.ledger_balance IS
    'Số dư sổ cái, lưu sẵn (quyết định DB4). Cập nhật CÙNG transaction với bút toán, không bao giờ tính lại từ journal_lines lúc đọc';
COMMENT ON COLUMN accounts.available_balance IS
    'Số dư KHẢ DỤNG = sổ cái trừ tiền đang treo. Đây là con số khách hàng nhìn thấy và là con số dùng để duyệt giao dịch';
COMMENT ON COLUMN accounts.version IS
    'Optimistic lock cho JPA @Version. Hai giao dịch cùng trừ một tài khoản là tình huống thật, không phải giả định';

-- Một tài khoản NHIỀU CHỦ: đồng sở hữu, người được ủy quyền ký.
CREATE TABLE account_holders (
    account_id  BIGINT      NOT NULL REFERENCES accounts (id) ON DELETE CASCADE,
    customer_id BIGINT      NOT NULL,
    holder_role VARCHAR(30) NOT NULL,
    added_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (account_id, customer_id),
    CONSTRAINT ck_holder_role CHECK (holder_role IN ('PRIMARY', 'JOINT', 'AUTHORIZED_SIGNATORY'))
);
COMMENT ON COLUMN account_holders.customer_id IS
    'Tham chiếu MỀM sang customer.customers.id';

-- Partial unique index: mỗi tài khoản CHỈ MỘT chủ chính. Đây là nửa ràng buộc
-- mà DB giữ được; nửa còn lại (customer_id của dòng này == accounts.primary_customer_id)
-- nằm ở hai bảng nên ứng dụng phải giữ.
CREATE UNIQUE INDEX uq_account_one_primary
    ON account_holders (account_id) WHERE holder_role = 'PRIMARY';

-- HOLD = tiền đã bị giữ nhưng CHƯA hạch toán. Đây là lý do quẹt thẻ xong tiền
-- "treo" mà số dư sổ cái chưa đổi. Hold hết hạn mà không capture thì tự nhả.
CREATE TABLE account_holds (
    id             BIGSERIAL     PRIMARY KEY,
    account_id     BIGINT        NOT NULL REFERENCES accounts (id),
    amount         NUMERIC(19,4) NOT NULL,
    reason         VARCHAR(20)   NOT NULL,
    reference_type VARCHAR(30),
    reference_id   VARCHAR(100),
    status         VARCHAR(20)   NOT NULL DEFAULT 'ACTIVE',
    placed_at      TIMESTAMPTZ   NOT NULL DEFAULT now(),
    expires_at     TIMESTAMPTZ,
    released_at    TIMESTAMPTZ,
    CONSTRAINT ck_hold_amount   CHECK (amount > 0),
    CONSTRAINT ck_hold_reason   CHECK (reason IN ('TRANSFER', 'CARD_AUTH', 'LEGAL', 'FEE')),
    CONSTRAINT ck_hold_status   CHECK (status IN ('ACTIVE', 'RELEASED', 'CAPTURED', 'EXPIRED')),
    CONSTRAINT ck_hold_released CHECK (status = 'ACTIVE' OR released_at IS NOT NULL),
    -- Chỉ phong toả theo lệnh cơ quan (LEGAL) mới được vô hạn. Mọi hold còn lại
    -- BẮT BUỘC có hạn — không có expires_at thì job quét (đi qua idx_holds_expiry)
    -- không nhìn thấy nó, và tiền của khách bị treo vĩnh viễn không đường về.
    CONSTRAINT ck_hold_expiry   CHECK (reason = 'LEGAL' OR expires_at IS NOT NULL)
);
COMMENT ON COLUMN account_holds.status IS
    'CAPTURED = đã chuyển thành bút toán thật. RELEASED = nhả không hạch toán. EXPIRED = quá hạn, job quét nhả';

CREATE INDEX idx_accounts_customer ON accounts (primary_customer_id);
CREATE INDEX idx_accounts_product  ON accounts (product_code);
CREATE INDEX idx_accounts_gl       ON accounts (gl_code);
CREATE INDEX idx_holders_customer  ON account_holders (customer_id);
-- Hai partial index cùng lọc ACTIVE nhưng phục vụ hai truy vấn khác nhau:
-- một cho "tổng tiền treo của tài khoản này", một cho job quét hold quá hạn.
CREATE INDEX idx_holds_active ON account_holds (account_id) WHERE status = 'ACTIVE';
CREATE INDEX idx_holds_expiry ON account_holds (expires_at) WHERE status = 'ACTIVE';

-- <<< HẾT KHỐI [5a]
