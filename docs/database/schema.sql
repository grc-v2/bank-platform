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
--     Không có FX trong phạm vi này. Trigger cân đối từ chối CẢ HAI vế: bút toán
--     trộn nhiều loại tiền, VÀ dòng mang loại tiền khác với tài khoản nó hạch toán
--     vào (vế thứ hai từng thiếu — bút toán USD vào tài khoản VND đi lọt sạch).
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

-- ---------------------------------------------------------------------
--  updated_at PHẢI DO DATABASE GIỮ
--
--  Tám bảng trong file này khai `updated_at TIMESTAMPTZ NOT NULL DEFAULT now()`.
--  DEFAULT chỉ chạy lúc INSERT. Không có gì cập nhật nó thì một cột tên updated_at
--  thực chất là created_at thứ hai — và nó sai một cách IM LẶNG: không lỗi, không
--  cảnh báo, chỉ là mọi con số đọc ra từ nó đều sai.
--
--  Cột này là HỢP ĐỒNG với phía tiêu thụ dữ liệu, không phải trang trí. CDC, đồng
--  bộ tăng dần, job đối chiếu đều hỏi "có gì đổi sau mốc X" bằng đúng cột này. Một
--  hàng bị sửa mà updated_at đứng yên thì không bao giờ lọt vào mẻ đồng bộ, và hai
--  hệ thống trôi lệch nhau mà không ai nhìn thấy.
--
--  ĐẶT Ở DATABASE, KHÔNG Ở JPA @PreUpdate: chưa có entity nào tồn tại, và bất biến
--  này phải đúng với MỌI thứ ghi vào bảng — batch job, script vá dữ liệu tay, psql
--  lúc 2 giờ sáng — chứ không riêng đường đi qua Hibernate.
--
--  Hàm đặt ở schema public vì năm schema có năm owner khác nhau và không owner nào
--  tạo được object trong schema của người khác; public là chỗ duy nhất cả năm role
--  đều USAGE được. Ở trên chỉ REVOKE CREATE trên public chứ không REVOKE USAGE,
--  nên các role vẫn gọi được hàm này.
--
--  HỆ QUẢ CÓ CHỦ ĐÍCH (đã kiểm): trigger GHI ĐÈ cả giá trị mà câu UPDATE tự đặt cho
--  updated_at. `UPDATE ... SET updated_at = '2020-01-01'` vẫn ra now(). Đó đúng là ý
--  nghĩa của "database sở hữu cột này" — không ai bịa được thời điểm sửa. Nếu có ngày
--  cần nạp dữ liệu giữ nguyên updated_at gốc (di trú từ hệ thống cũ), phải DROP
--  trigger, nạp, rồi tạo lại trong cùng một transaction, và đó là việc có chủ đích
--  chứ không phải chuyện tình cờ làm được.
--
--  Dùng now() (thời điểm BẮT ĐẦU transaction) chứ không clock_timestamp(): mọi hàng
--  sửa trong cùng một transaction mang đúng một mốc, khớp với DEFAULT now() của
--  created_at. Phía đọc CDC nhờ đó thấy một transaction là một mốc thời gian.
--
--  KHÔNG dùng WHEN (OLD.* IS DISTINCT FROM NEW.*), nên một UPDATE không đổi gì vẫn
--  đẩy updated_at và vẫn tạo một nhịp thừa cho CDC. Đã cân nhắc và CỐ Ý bỏ, không
--  phải quên: Postgres từ chối thẳng mệnh đề đó trên core_banking.accounts —
--    ERROR: BEFORE trigger's WHEN condition cannot reference NEW generated columns
--  vì accounts có cột GENERATED available_balance (bảy bảng còn lại thì không).
--  Gắn guard cho bảy bảng kia mà bỏ accounts sẽ tạo ra HAI ngữ nghĩa updated_at khác
--  nhau trong cùng một database — đúng thứ tệ nhất cho phía tiêu thụ mà cột này sinh
--  ra để phục vụ. Còn liệt kê tay từng cột riêng cho accounts thì mỗi cột thêm về sau
--  sẽ lặng lẽ nằm ngoài guard, ngay trên bảng sổ cái. Chọn nhiễu ĐỀU thay vì nhiễu
--  lệch. Nếu sau này bỏ cột GENERATED kia, hãy gắn guard cho cả tám bảng cùng lúc.
-- ---------------------------------------------------------------------
CREATE FUNCTION public.set_updated_at() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

-- Postgres mặc định đã cấp EXECUTE cho PUBLIC trên function mới. Khai tường minh
-- để bất biến không phụ thuộc vào một mặc định mà ALTER DEFAULT PRIVILEGES ở môi
-- trường khác có thể đã đổi.
GRANT EXECUTE ON FUNCTION public.set_updated_at()
    TO auth_svc, customer_svc, product_svc, core_svc, noti_svc;

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

-- updated_at do DB giữ (xem khối [1]). Bỏ trigger này đi thì cột thành created_at.
CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

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

-- updated_at do DB giữ (xem khối [1]). Bỏ trigger này đi thì cột thành created_at.
CREATE TRIGGER trg_prefs_updated_at BEFORE UPDATE ON user_notification_preferences
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

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

-- updated_at do DB giữ (xem khối [1]). Bỏ trigger này đi thì cột thành created_at.
CREATE TRIGGER trg_customers_updated_at BEFORE UPDATE ON customers
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

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
    CONSTRAINT ck_rate_period CHECK (effective_to IS NULL OR effective_to > effective_from),
    -- Bảng GIÁ TRỊ cuối cùng còn thiếu lưới chống chồng lấn (fees, limits, gl_mappings
    -- đã có từ đầu) — khối comment mở đầu schema [4] vẫn nói cả bốn bảng đều có, nên
    -- trước ràng buộc này chính file tự mâu thuẫn với mình. Thiếu nó thì hai dòng cùng
    -- sản phẩm, cùng bậc, cùng kỳ hạn, cùng ngày hiệu lực nhưng KHÁC lãi suất là hợp lệ
    -- với DB, và câu "áp lãi suất nào" được trả lời bằng thứ tự hàng trả về — tức là
    -- không trả lời được.
    --
    -- Hai chỗ dễ sập bẫy, cả hai xử lý ngay tại đây:
    --   1. BẬC cũng là một KHOẢNG. Phải xét chồng lấn trên numrange(tier_from, tier_to)
    --      chứ không phải '=' trên từng cột; nếu không, bậc 0-100tr và bậc 50-200tr của
    --      cùng một sản phẩm vẫn lọt qua.
    --   2. term_months NULL-ABLE, mà 'WITH =' KHÔNG BAO GIỜ khớp NULL với NULL. Để trần
    --      thì mọi dòng không kỳ hạn — chính là toàn bộ CA và SA — vĩnh viễn không xung
    --      đột với nhau, đúng những dòng cần bảo vệ nhất lại lọt hết. COALESCE về -1 kéo
    --      NULL thành giá trị so sánh được; -1 an toàn vì ck_rate_term đã bắt
    --      term_months > 0 nên không dòng thật nào mang -1.
    --
    -- KHÔNG DEFERRABLE — giống hệt ba ràng buộc ex_* anh em, nên hành vi nhất quán
    -- trong cả file. Hệ quả thực hành khi đổi lãi suất, viết ra đây vì chưa chỗ nào
    -- ghi: phải ĐÓNG dòng cũ TRƯỚC (UPDATE effective_to) rồi mới INSERT dòng mới.
    -- Làm ngược thứ tự thì ngay tại câu INSERT hai khoảng còn phủ nhau và câu lệnh bị
    -- chặn, dù trạng thái cuối transaction hoàn toàn hợp lệ.
    CONSTRAINT ex_rate_overlap EXCLUDE USING gist (
        product_id                                    WITH =,
        COALESCE(term_months, -1)                     WITH =,
        numrange(tier_from, tier_to, '[)')            WITH &&,
        daterange(effective_from, effective_to, '[)') WITH &&)
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
    -- Khoảng hiệu lực RỖNG (effective_to = effective_from) phải chặn ở đây, và
    -- ex_fee_overlap bên dưới KHÔNG gánh thay được: daterange rỗng không '&&' với bất
    -- kỳ khoảng nào, kể cả chính nó, nên EXCLUDE nhìn dòng đó là hoàn toàn vô hại.
    -- Thực tế đó là một biểu phí không bao giờ có hiệu lực — phí âm thầm không thu,
    -- không lỗi, không cảnh báo. Cùng khuôn với ck_products_period / ck_rate_period /
    -- ck_glmap_period, ba bảng anh em đã có từ đầu.
    CONSTRAINT ck_fee_period CHECK (effective_to IS NULL OR effective_to > effective_from),
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
    -- Cùng lý do như ck_fee_period: khoảng rỗng lọt qua EXCLUDE vì daterange rỗng
    -- không '&&' với gì cả. Ở bảng này hậu quả nặng hơn phí — một hạn mức không bao
    -- giờ có hiệu lực nghĩa là KHÔNG có hạn mức, tức là chốt chặn số tiền bị mở toang
    -- mà nhìn vào bảng vẫn thấy có dòng hạn mức nằm đó.
    CONSTRAINT ck_limit_period  CHECK (effective_to IS NULL OR effective_to > effective_from),
    CONSTRAINT uq_limit UNIQUE (product_id, limit_code, channel, effective_from),
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

-- updated_at do DB giữ (xem khối [1]). Bỏ trigger này đi thì cột thành created_at.
CREATE TRIGGER trg_products_updated_at BEFORE UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

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
        OR (account_class IN ('LIABILITY', 'EQUITY', 'INCOME') AND normal_balance = 'CREDIT')),
    -- Một tài khoản không thể là cha của chính nó. FK ở trên chỉ bắt parent_gl_code
    -- phải TỒN TẠI — mà chính nó thì luôn tồn tại, nên
    -- `UPDATE gl_accounts SET parent_gl_code = '1010' WHERE gl_code = '1010'` đi lọt
    -- nếu thiếu CHECK này, và mọi phép cộng dồn lên cây tài khoản sẽ lặp vô hạn.
    --
    -- PHẠM VI CÓ CHỦ ĐÍCH: chỉ chặn vòng ĐỘ DÀI 1. Vòng dài hơn (A -> B -> A) CỐ Ý
    -- KHÔNG chặn — bắt nó cần trigger đệ quy chạy trên mỗi lần ghi, và đó là quyết
    -- định đã cân nhắc rồi bỏ. Hệ quả bắt buộc phải nhớ: mọi lần duyệt cây tài khoản
    -- về sau PHẢI viết bằng `WITH RECURSIVE ... CYCLE`, đừng giả định cây sạch chu trình.
    CONSTRAINT ck_gl_parent_not_self CHECK (parent_gl_code IS NULL OR parent_gl_code <> gl_code)
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

-- updated_at do DB giữ (xem khối [1]). Bỏ trigger này đi thì cột thành created_at.
CREATE TRIGGER trg_accounts_updated_at BEFORE UPDATE ON accounts
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- <<< HẾT KHỐI [5a]

-- ---------------------------------------------------------------------
-- [5b] SỔ CÁI BÚT TOÁN KÉP (quyết định DB1)
--
--      Một giao dịch = MỘT journal_entries (header) + NHIỀU journal_lines.
--      Chuyển 100.000 và thu phí 2.000 là một bút toán BA dòng:
--        Nợ  tài khoản người gửi   102.000
--        Có  tài khoản người nhận  100.000
--        Có  GL thu nhập phí         2.000
--      Bảng ledger_entries phẳng của bản cũ không diễn tả nổi việc này.
-- ---------------------------------------------------------------------

CREATE TABLE journal_entries (
    id                   BIGSERIAL    PRIMARY KEY,
    entry_reference      VARCHAR(40)  NOT NULL,
    transaction_type     VARCHAR(20)  NOT NULL,
    source_type          VARCHAR(30),
    source_id            VARCHAR(100),
    value_date           DATE         NOT NULL,
    booking_date         DATE         NOT NULL DEFAULT CURRENT_DATE,
    posted_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    description          VARCHAR(500),
    reversal_of_entry_id BIGINT       REFERENCES journal_entries (id),
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_txid         xid8         NOT NULL DEFAULT pg_current_xact_id(),
    CONSTRAINT uq_journal_reference UNIQUE (entry_reference),
    CONSTRAINT ck_journal_txn_type CHECK (transaction_type IN (
        'TRANSFER', 'FEE', 'INTEREST', 'REVERSAL', 'ADJUSTMENT', 'OPENING')),
    -- REVERSAL bắt buộc trỏ về bản gốc; loại khác bắt buộc không trỏ.
    CONSTRAINT ck_journal_reversal CHECK (
           (transaction_type =  'REVERSAL' AND reversal_of_entry_id IS NOT NULL)
        OR (transaction_type <> 'REVERSAL' AND reversal_of_entry_id IS NULL))
);
COMMENT ON COLUMN journal_entries.value_date IS
    'NGÀY HIỆU LỰC — quyết định tính lãi. Khác booking_date: giao dịch cuối ngày 31 có thể value_date 31 nhưng booking_date 01 tháng sau';
COMMENT ON COLUMN journal_entries.booking_date IS
    'NGÀY HẠCH TOÁN — quyết định bút toán rơi vào kỳ sổ nào';
COMMENT ON COLUMN journal_entries.reversal_of_entry_id IS
    'Sổ cái APPEND-ONLY: sai thì ghi bút toán đảo trỏ về bản gốc, không bao giờ UPDATE hay DELETE bút toán cũ';
COMMENT ON COLUMN journal_entries.created_txid IS
    'TỒN TẠI ĐỂ trg_journal_lines_same_txn phân biệt được "header vừa sinh trong transaction này" với "header của một transaction đã xong". KHÔNG trùng vai với system column xmin: xmin của hàng ghi trong SAVEPOINT là id của SUBTRANSACTION, còn cột này lấy DEFAULT pg_current_xact_id() nên luôn là id transaction NGOÀI CÙNG. Xoá cột là mở lại lỗ hổng chèn dòng vào bút toán đã chốt — đọc khối comment ở trg_journal_lines_same_txn trước khi động vào';

-- MỘT bút toán chỉ được đảo MỘT LẦN. ck_journal_reversal ở trên bắt REVERSAL phải
-- trỏ về bản gốc, nhưng không nói gì về việc hai bút toán đảo cùng trỏ về một gốc.
-- Thiếu ràng buộc này thì cả hai đều cân, cả hai đều qua trg_journal_balanced, và
-- bản gốc bị đảo hai lần — tiền chạy ngược hai lượt, số dư lệch đúng bằng số tiền
-- gốc, mà sổ cái vẫn "đúng" ở mọi phép kiểm từng-bút-toán.
-- Partial index (bỏ NULL) chứ không UNIQUE thường: đại đa số bút toán không phải
-- bút toán đảo, không việc gì phải đánh index cho NULL của chúng.
-- Đảo một bút toán đảo VẪN được: C đảo B, B đảo A -> hai giá trị khác nhau.
--
-- ĐÂY LÀ MỘT LỰA CHỌN CHÍNH SÁCH, không phải chân lý hiển nhiên. Nó đồng thời cấm
-- ĐẢO TỪNG PHẦN — nhiều bút toán đảo nhỏ cùng trỏ về một bút toán gốc — vốn là việc
-- có thật trong nghiệp vụ ngân hàng. Ở phạm vi này ta chọn "một gốc, một đảo" vì nó
-- đơn giản và DB kiểm được bằng một index. Ngày nào cần đảo từng phần thì phải thay
-- ràng buộc này bằng một ràng buộc trên TỔNG số tiền đã đảo (không vượt bản gốc),
-- chứ đừng chỉ lặng lẽ DROP index rồi đi tiếp.
CREATE UNIQUE INDEX uq_journal_one_reversal
    ON journal_entries (reversal_of_entry_id) WHERE reversal_of_entry_id IS NOT NULL;

CREATE TABLE journal_lines (
    id               BIGSERIAL,
    journal_entry_id BIGINT        NOT NULL REFERENCES journal_entries (id),
    line_no          INT           NOT NULL,
    account_id       BIGINT        REFERENCES accounts (id),
    gl_code          VARCHAR(20)   NOT NULL REFERENCES gl_accounts (gl_code),
    direction        VARCHAR(6)    NOT NULL,
    amount           NUMERIC(19,4) NOT NULL,
    currency         CHAR(3)       NOT NULL DEFAULT 'VND',
    balance_after    NUMERIC(19,4),
    created_at       TIMESTAMPTZ   NOT NULL DEFAULT now(),
    PRIMARY KEY (id, created_at),
    CONSTRAINT uq_journal_line   UNIQUE (journal_entry_id, line_no, created_at),
    CONSTRAINT ck_line_direction CHECK (direction IN ('DEBIT', 'CREDIT')),
    CONSTRAINT ck_line_amount    CHECK (amount > 0),
    CONSTRAINT ck_line_no        CHECK (line_no > 0)
) PARTITION BY RANGE (created_at);

COMMENT ON COLUMN journal_lines.account_id IS
    'NULL = dòng này chỉ chạm GL nội bộ (tiền mặt, clearing, thu nhập phí). Quyết định DB3: không có tài khoản SYSTEM trong bảng accounts';
COMMENT ON COLUMN journal_lines.amount IS
    'LUÔN DƯƠNG. Nợ hay Có do cột direction quyết định, không dùng dấu âm — số âm trong sổ cái là nguồn gốc của những đêm mất ngủ';
COMMENT ON CONSTRAINT uq_journal_line ON journal_lines IS
    'Postgres bắt UNIQUE/PK trên bảng partition PHẢI chứa cột partition, nên có created_at ở đây. ĐẢM BẢO NÀY CHỈ TRONG PHẠM VI MỘT TRANSACTION: now() không đổi suốt transaction nên mọi dòng của một bút toán có created_at giống hệt nhau, và line_no trùng bị chặn. Transaction KHÁC insert lại line_no cũ sẽ có created_at khác và LỌT — chặn chuyện đó là việc của trg_journal_lines_immutable, không phải của ràng buộc này';

-- Partition theo tháng. Sinh sẵn ba tháng để hiểu cơ chế; sinh tự động về sau
-- là việc của job hoặc pg_partman. DEFAULT hứng dữ liệu ngoài khoảng để INSERT
-- không chết khi ai đó quên tạo partition tháng mới.
CREATE TABLE journal_lines_2026_08 PARTITION OF journal_lines
    FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE journal_lines_2026_09 PARTITION OF journal_lines
    FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE journal_lines_2026_10 PARTITION OF journal_lines
    FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE journal_lines_default PARTITION OF journal_lines DEFAULT;

CREATE INDEX idx_lines_entry   ON journal_lines (journal_entry_id);
CREATE INDEX idx_lines_account ON journal_lines (account_id, created_at DESC);
CREATE INDEX idx_lines_gl      ON journal_lines (gl_code, created_at DESC);

-- ---------------------------------------------------------------------
-- QUYẾT ĐỊNH DB2 — ràng buộc "tổng Nợ = tổng Có"
--
-- Đây là ràng buộc LIÊN HÀNG: nó nói về tập các dòng của một bút toán, không
-- nói về từng dòng. Không CHECK nào biểu diễn được (CHECK chỉ thấy một hàng).
--
-- Giải pháp: CONSTRAINT TRIGGER DEFERRABLE INITIALLY DEFERRED. Nó chạy tại
-- COMMIT chứ không tại INSERT — đúng lúc mọi dòng đã nằm trong bảng.
--
-- Trigger đặt trên journal_entries (bảng THƯỜNG) vì phép cân đối nói về TẬP các
-- dòng của một bút toán, và chỗ tự nhiên để kiểm tại COMMIT là hàng header.
--
-- KHOẢNG HỞ NÓ KHÔNG BỊT: bút toán đã cân, đã commit, rồi một transaction KHÁC chèn
-- thêm dòng vào chính bút toán ấy. trg_journal_balanced chỉ chạy khi INSERT vào
-- journal_entries nên không bao giờ chạy lại.
--
-- Trước đây chỗ này ghi rằng phải chấp nhận khoảng hở vì "bảng partition không mang
-- nổi ràng buộc cần thiết". LÝ DO ĐÓ SAI, và đã kiểm lại bằng thực nghiệm trên đúng
-- Postgres mà repo dùng (17.10):
--   * trigger FOR EACH ROW trên bảng partition được Postgres nhân xuống MỌI partition
--     con. pg_get_triggerdef cho thấy trg_journal_lines_immutable nằm trên
--     journal_lines VÀ cả bốn partition.
--   * kể cả CONSTRAINT TRIGGER ... DEFERRABLE INITIALLY DEFERRED đặt trên bảng
--     partition cũng được chấp nhận và cũng nhân xuống đủ bốn partition.
-- Không có giới hạn nào của Postgres buộc phải bỏ trống chỗ này.
--
-- Khoảng hở giờ do trg_journal_lines_same_txn (bên dưới) bịt.
-- ---------------------------------------------------------------------
CREATE FUNCTION core_banking.assert_journal_balanced() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
    v_lines          INT;
    v_net            NUMERIC(19,4);
    v_currencies     INT;
    v_non_postable   INT;
    v_wrong_currency INT;
BEGIN
    SELECT COUNT(*),
           COALESCE(SUM(CASE WHEN direction = 'DEBIT' THEN amount ELSE -amount END), 0),
           COUNT(DISTINCT currency)
      INTO v_lines, v_net, v_currencies
      FROM core_banking.journal_lines
     WHERE journal_entry_id = NEW.id;

    IF v_lines < 2 THEN
        RAISE EXCEPTION 'Bút toán % có % dòng — tối thiểu 2 (một Nợ, một Có)',
            NEW.entry_reference, v_lines;
    END IF;

    IF v_currencies > 1 THEN
        RAISE EXCEPTION 'Bút toán % trộn % loại tiền — ngoài phạm vi (không có FX)',
            NEW.entry_reference, v_currencies;
    END IF;

    IF v_net <> 0 THEN
        RAISE EXCEPTION 'Bút toán % KHÔNG CÂN: tổng Nợ - tổng Có = %',
            NEW.entry_reference, v_net;
    END IF;

    -- Không được hạch toán thẳng vào tài khoản GL TỔNG HỢP (is_postable = FALSE).
    -- Bút toán kiểu đó vẫn cân, nên nếu không chặn ở đây thì sai chỉ lộ ra ở khâu
    -- đối chiếu — lúc đó đã lẫn vào hàng nghìn bút toán đúng. FK chỉ kiểm gl_code
    -- có tồn tại, không kiểm nó có được phép hạch toán hay không.
    SELECT COUNT(*)
      INTO v_non_postable
      FROM core_banking.journal_lines l
      JOIN core_banking.gl_accounts  g ON g.gl_code = l.gl_code
     WHERE l.journal_entry_id = NEW.id
       AND NOT g.is_postable;

    IF v_non_postable > 0 THEN
        RAISE EXCEPTION 'Bút toán % có % dòng hạch toán vào GL tổng hợp (is_postable = FALSE)',
            NEW.entry_reference, v_non_postable;
    END IF;

    -- Nguyên tắc 3 ở đầu file hứa "một tài khoản một loại tiền", nhưng phép kiểm
    -- COUNT(DISTINCT currency) ở trên CHỈ nhìn trong nội bộ một bút toán: nó bắt được
    -- bút toán TRỘN tiền, không bắt được bút toán ĐỒNG NHẤT NHƯNG SAI loại tiền. Hai
    -- dòng USD cân nhau hạch toán vào tài khoản VND đi lọt sạch — rồi
    -- accounts.ledger_balance cộng thẳng USD vào số dư VND, và không phép đối chiếu
    -- nào ở [8] phát hiện ra vì bản thân bút toán vẫn cân.
    --
    -- Dòng có account_id NULL CỐ Ý không bị kiểm ở đây: theo quyết định DB3 đó là dòng
    -- chỉ chạm GL nội bộ, không có tài khoản khách hàng nào để đối chiếu. JOIN (không
    -- phải LEFT JOIN) loại chúng ra một cách tự nhiên — đừng "sửa" thành LEFT JOIN.
    SELECT COUNT(*)
      INTO v_wrong_currency
      FROM core_banking.journal_lines l
      JOIN core_banking.accounts     a ON a.id = l.account_id
     WHERE l.journal_entry_id = NEW.id
       AND a.currency <> l.currency;

    IF v_wrong_currency > 0 THEN
        RAISE EXCEPTION 'Bút toán % có % dòng lệch loại tiền so với tài khoản được hạch toán',
            NEW.entry_reference, v_wrong_currency;
    END IF;

    RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER trg_journal_balanced
    AFTER INSERT ON journal_entries
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION core_banking.assert_journal_balanced();

-- ---------------------------------------------------------------------
-- APPEND-ONLY, ÉP BẰNG DB CHỨ KHÔNG CHỈ BẰNG LỜI
--
-- Nguyên tắc số 5 ở đầu file nói sổ cái không UPDATE, không DELETE. Cho tới
-- đây đó mới chỉ là một câu văn: trg_journal_balanced chỉ chạy khi INSERT vào
-- journal_entries, nên một UPDATE lên journal_lines làm lệch bút toán đã cân
-- sẽ đi lọt hoàn toàn và không gì phát hiện được.
--
-- Và không thể thay bằng REVOKE: core_svc SỞ HỮU các bảng này, mà chủ sở hữu
-- đi xuyên qua mọi GRANT. Chỉ trigger mới chặn được.
--
-- Còn hai đường vòng mà trigger không với tới: TRUNCATE và DROP TABLE. Cả hai
-- đều cần quyền chủ sở hữu và đều là hành động có chủ ý, không phải tai nạn của
-- một câu UPDATE viết vội — chấp nhận được ở tầng này.
-- ---------------------------------------------------------------------
CREATE FUNCTION core_banking.reject_ledger_mutation() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION
        'Sổ cái là APPEND-ONLY: % lên %.% bị từ chối. Sai thì ghi bút toán ĐẢO (transaction_type = ''REVERSAL'', reversal_of_entry_id trỏ về bản gốc)',
        TG_OP, TG_TABLE_SCHEMA, TG_TABLE_NAME;
END;
$$;

CREATE TRIGGER trg_journal_entries_immutable
    BEFORE UPDATE OR DELETE ON journal_entries
    FOR EACH ROW EXECUTE FUNCTION core_banking.reject_ledger_mutation();

CREATE TRIGGER trg_journal_lines_immutable
    BEFORE UPDATE OR DELETE ON journal_lines
    FOR EACH ROW EXECUTE FUNCTION core_banking.reject_ledger_mutation();

-- ---------------------------------------------------------------------
-- KHÔNG CHÈN DÒNG VÀO BÚT TOÁN ĐÃ COMMIT
--
-- Bịt nốt khoảng hở của trg_journal_balanced (mô tả ngay trên nó). Một bút toán đã
-- cân và đã commit thì TẬP DÒNG của nó là bất biến; chèn thêm dòng vào đó là sửa một
-- bản ghi sổ cái đã chốt. Hai trigger immutable phía trên chỉ chặn UPDATE và DELETE,
-- nên trước trigger này INSERT là đường vòng duy nhất còn mở — và nó không để lại
-- dấu vết nào, bút toán vẫn "tồn tại hợp lệ", chỉ là nội dung đã khác lúc chốt.
--
-- CƠ CHẾ: so journal_entries.created_txid với pg_current_xact_id() tại lúc chèn dòng.
-- Bằng nhau nghĩa là header sinh ra trong CHÍNH transaction đang chạy — cho qua. Khác
-- nhau nghĩa là header thuộc một transaction khác đã kết thúc — chặn.
--
-- VÌ SAO PHẢI CÓ CỘT created_txid MÀ KHÔNG DÙNG system column xmin. Đọc hết đoạn này
-- trước khi xoá cột đó vì tưởng nó thừa:
--   pg_current_xact_id() LUÔN trả id của transaction NGOÀI CÙNG. Còn xmin của một hàng
--   ghi bên trong SAVEPOINT là id của SUBTRANSACTION, không phải của transaction ngoài
--   cùng. Đo trực tiếp trên chính DB này: mở transaction (id ngoài cùng 1023), vào
--   SAVEPOINT rồi INSERT header — xmin của header là 1024. Hai số không khớp.
--   Hệ quả nếu dùng xmin: MỌI bố cục ghi header bên trong savepoint đều bị từ chối OAN.
--   Đã dựng lại và xác nhận cả ba bố cục sau đều bị chặn sai:
--     * header và các dòng cùng nằm trong một SAVEPOINT rồi RELEASE — đây đúng là thứ
--       @Transactional(propagation = NESTED) của Spring sinh ra;
--     * header trong SAVEPOINT đã RELEASE, các dòng ở mức ngoài;
--     * SAVEPOINT/RELEASE bọc quanh TỪNG câu lệnh — hình dạng SQL mà PgJDBC tạo ra khi
--       chạy với autosave=always (và với autosave=conservative sau một lỗi đã hồi phục).
--       Với cấu hình đó thì mọi bút toán của hệ thống đều fail.
--   created_txid lấy giá trị từ DEFAULT pg_current_xact_id(), và DEFAULT dù được tính
--   BÊN TRONG savepoint vẫn cho id transaction ngoài cùng — đúng cái mà xmin không có.
--   Cột này còn bỏ luôn phép cast xid8 -> xid (64 bit xuống 32 bit) và rủi ro wraparound
--   đi kèm: xid8 so với xid8, không cast.
--
-- KHÔNG có ràng buộc nào về mức lồng transaction. Ghi header và các dòng ở mức nào,
-- qua bao nhiêu lớp savepoint, theo thứ tự nào cũng được — điều kiện duy nhất là chúng
-- thuộc cùng MỘT transaction ngoài cùng.
-- ---------------------------------------------------------------------
CREATE FUNCTION core_banking.assert_entry_not_committed() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
    v_ref TEXT;
BEGIN
    SELECT e.entry_reference
      INTO v_ref
      FROM core_banking.journal_entries e
     WHERE e.id = NEW.journal_entry_id
       AND e.created_txid <> pg_current_xact_id();

    IF FOUND THEN
        RAISE EXCEPTION
            'Bút toán % đã COMMIT ở transaction trước — không được chèn thêm dòng. Sai thì ghi bút toán ĐẢO (transaction_type = ''REVERSAL''), không vá dòng vào bút toán cũ',
            v_ref;
    END IF;

    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_journal_lines_same_txn
    AFTER INSERT ON journal_lines
    FOR EACH ROW EXECUTE FUNCTION core_banking.assert_entry_not_committed();

-- Chốt số dư cuối ngày. Hai công dụng: sao kê không phải quét lại sổ cái từ đầu,
-- và job đối chiếu có mốc để so accounts.ledger_balance với tổng bút toán.
CREATE TABLE account_balance_snapshots (
    account_id      BIGINT        NOT NULL REFERENCES accounts (id),
    as_of_date      DATE          NOT NULL,
    opening_balance NUMERIC(19,4) NOT NULL,
    closing_balance NUMERIC(19,4) NOT NULL,
    total_debit     NUMERIC(19,4) NOT NULL DEFAULT 0,
    total_credit    NUMERIC(19,4) NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT now(),
    PRIMARY KEY (account_id, as_of_date),
    CONSTRAINT ck_snapshot_totals CHECK (total_debit >= 0 AND total_credit >= 0)
);

-- <<< HẾT KHỐI [5b]

-- ---------------------------------------------------------------------
-- [5c] Giao dịch, lãi, phí, hạ tầng
-- ---------------------------------------------------------------------

CREATE TABLE transfers (
    id                         BIGSERIAL     PRIMARY KEY,
    transfer_reference         VARCHAR(40)   NOT NULL,
    idempotency_key            VARCHAR(64)   NOT NULL,
    transfer_type              VARCHAR(20)   NOT NULL,
    source_account_id          BIGINT        NOT NULL REFERENCES accounts (id),
    destination_account_id     BIGINT        REFERENCES accounts (id),
    destination_account_number VARCHAR(34),
    destination_bank_code      VARCHAR(20),
    amount                     NUMERIC(19,4) NOT NULL,
    currency                   CHAR(3)       NOT NULL DEFAULT 'VND',
    fee_amount                 NUMERIC(19,4) NOT NULL DEFAULT 0,
    channel                    VARCHAR(20)   NOT NULL,
    description                VARCHAR(500),
    status                     VARCHAR(20)   NOT NULL DEFAULT 'PENDING',
    journal_entry_id           BIGINT        REFERENCES journal_entries (id),
    initiated_by_user_id       BIGINT,
    version                    INT           NOT NULL DEFAULT 0,
    created_at                 TIMESTAMPTZ   NOT NULL DEFAULT now(),
    completed_at               TIMESTAMPTZ,
    updated_at                 TIMESTAMPTZ   NOT NULL DEFAULT now(),
    -- Constraint ĐẶT TÊN TƯỜNG MINH. Bản cũ để CHECK inline, Postgres tự đặt
    -- tên 'transfers_status_check', và đến migration sau mới phát hiện mình
    -- không biết nó tên gì. Bài học đó nằm ở đây.
    CONSTRAINT uq_transfers_reference   UNIQUE (transfer_reference),
    -- UNIQUE trên idempotency_key LÀ toàn bộ cơ chế chống trùng lệnh. Đặt tên
    -- tường minh vì đây là ràng buộc mà code sẽ bắt lỗi theo tên khi client retry.
    CONSTRAINT uq_transfers_idempotency UNIQUE (idempotency_key),
    CONSTRAINT ck_transfers_status  CHECK (status IN ('PENDING', 'PENDING_EXTERNAL', 'COMPLETED', 'FAILED', 'REVERSED')),
    CONSTRAINT ck_transfers_type    CHECK (transfer_type IN ('INTERNAL', 'EXTERNAL')),
    CONSTRAINT ck_transfers_channel CHECK (channel IN ('INTERNET', 'MOBILE', 'ATM', 'BRANCH', 'API')),
    CONSTRAINT ck_transfers_amount  CHECK (amount > 0 AND fee_amount >= 0),
    -- Chuyển nội bộ phải có tài khoản đích trong hệ thống; chuyển liên ngân hàng
    -- phải có số tài khoản + mã ngân hàng đối tác. Mỗi nhánh vừa BẮT BUỘC trường
    -- của loại mình, vừa CẤM trường của loại kia — nếu chỉ bắt buộc mà không cấm
    -- thì một dòng EXTERNAL vẫn mang được destination_account_id, và nó trông như
    -- cả hai loại giao dịch cùng lúc.
    CONSTRAINT ck_transfers_target  CHECK (
           (transfer_type = 'INTERNAL'
                AND destination_account_id     IS NOT NULL
                AND destination_account_number IS NULL
                AND destination_bank_code      IS NULL)
        OR (transfer_type = 'EXTERNAL'
                AND destination_account_number IS NOT NULL
                AND destination_bank_code      IS NOT NULL
                AND destination_account_id     IS NULL)),
    CONSTRAINT ck_transfers_self    CHECK (destination_account_id IS NULL OR destination_account_id <> source_account_id),
    -- COMPLETED nghĩa là tiền ĐÃ dịch chuyển. Không có journal_entry_id thì không
    -- có bút toán nào phía sau — tức là báo tiền đã chuyển mà sổ cái không biết.
    -- Cùng khuôn với ck_accrual_posted và ck_fee_charge_posted bên dưới.
    CONSTRAINT ck_transfers_completed_posted CHECK (
        status <> 'COMPLETED' OR journal_entry_id IS NOT NULL)
);
COMMENT ON COLUMN transfers.idempotency_key IS
    'Client gửi lại cùng key = cùng một lệnh. UNIQUE ở đây đảm bảo AN TOÀN TIỀN BẠC (không bao giờ trừ hai lần) mà không cần code kiểm tra trước. Nhưng nó CHƯA làm endpoint idempotent: lần gọi lại nhận unique_violation chứ không nhận lại kết quả cũ. Muốn idempotent thật, tầng ứng dụng phải bắt vi phạm đó rồi tra và trả về chính transfer đã tạo';
COMMENT ON COLUMN transfers.journal_entry_id IS
    'NULL khi chưa hạch toán (PENDING). Bút toán là sự thật; transfers chỉ là ý định';

-- Saga chuyển tiền liên ngân hàng.
-- PENDING_EXTERNAL = đã treo tiền nguồn, đang chờ đối tác xác nhận.
-- Thất bại hoặc quá hạn -> bút toán ĐẢO, không bao giờ xóa bút toán gốc.
CREATE TABLE external_transfers (
    id                      BIGSERIAL   PRIMARY KEY,
    transfer_id             BIGINT      NOT NULL REFERENCES transfers (id),
    partner_code            VARCHAR(20) NOT NULL,
    partner_ref             VARCHAR(100),
    saga_state              VARCHAR(30) NOT NULL DEFAULT 'HOLD_PLACED',
    partner_idempotency_key VARCHAR(64) NOT NULL,
    deadline_at             TIMESTAMPTZ NOT NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- Một transfer chỉ có tối đa một saga liên ngân hàng.
    CONSTRAINT uq_ext_transfer     UNIQUE (transfer_id),
    CONSTRAINT uq_ext_idempotency  UNIQUE (partner_idempotency_key),
    CONSTRAINT ck_ext_saga_state CHECK (saga_state IN (
        'HOLD_PLACED',        -- đã treo tiền nguồn, chưa gọi đối tác
        'PARTNER_REQUESTED',  -- đã gọi, đang chờ trả lời
        'PARTNER_CONFIRMED',  -- xong -> transfer COMPLETED
        'PARTNER_REJECTED',   -- bị từ chối -> đảo bút toán
        'TIMED_OUT',          -- quá hạn -> đảo bút toán
        'COMPENSATED'))       -- bút toán đảo đã ghi
);
COMMENT ON COLUMN external_transfers.partner_idempotency_key IS
    'Idempotency với ĐỐI TÁC (khác idempotency_key với client): retry gọi partner dùng lại đúng key này';
COMMENT ON COLUMN external_transfers.saga_state IS
    'BẤT BIẾN DO ỨNG DỤNG GIỮ: saga_state và transfers.status là hai máy trạng thái mô tả cùng một sự việc và phải khớp nhau (PARTNER_CONFIRMED <-> COMPLETED, PARTNER_REJECTED/TIMED_OUT -> COMPENSATED <-> REVERSED). CHECK không với sang bảng khác được nên DB không chặn nổi việc chúng trôi lệch — cập nhật cả hai trong CÙNG transaction';

-- Velocity check: đã dùng bao nhiêu hạn mức trong cửa sổ nào.
-- Khuôn hạn mức nằm ở product.product_limits; bảng này là mức đã tiêu.
CREATE TABLE transfer_limit_usage (
    id           BIGSERIAL     PRIMARY KEY,
    account_id   BIGINT        NOT NULL REFERENCES accounts (id),
    limit_code   VARCHAR(30)   NOT NULL,
    window_start DATE          NOT NULL,
    used_amount  NUMERIC(19,4) NOT NULL DEFAULT 0,
    used_count   INT           NOT NULL DEFAULT 0,
    updated_at   TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT uq_limit_usage UNIQUE (account_id, limit_code, window_start),
    CONSTRAINT ck_limit_usage CHECK (used_amount >= 0 AND used_count >= 0)
);
COMMENT ON COLUMN transfer_limit_usage.window_start IS
    'Ngày đầu cửa sổ: hạn mức ngày thì là chính ngày đó, hạn mức tháng thì là ngày 01';
COMMENT ON COLUMN transfer_limit_usage.limit_code IS
    'Khớp product.product_limits.limit_code nhưng KHÔNG có FK (xuyên schema). Cái giá của ranh giới service: giá trị ở đây là chuỗi tự do, gõ sai hoặc đổi tên bên product mà không đồng bộ sẽ làm hạn mức âm thầm không được đếm. Đối chiếu định kỳ là việc của ứng dụng';

-- Dự thu lãi HẰNG NGÀY, hạch toán định kỳ. UNIQUE(account_id, accrual_date)
-- là toàn bộ cơ chế chống chạy EOD hai lần — không cần cờ "đã chạy chưa".
CREATE TABLE interest_accruals (
    id               BIGSERIAL     PRIMARY KEY,
    account_id       BIGINT        NOT NULL REFERENCES accounts (id),
    accrual_date     DATE          NOT NULL,
    principal_base   NUMERIC(19,4) NOT NULL,
    annual_rate      NUMERIC(9,6)  NOT NULL,
    accrued_amount   NUMERIC(19,4) NOT NULL,
    posted           BOOLEAN       NOT NULL DEFAULT FALSE,
    journal_entry_id BIGINT        REFERENCES journal_entries (id),
    created_at       TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT uq_accrual        UNIQUE (account_id, accrual_date),
    CONSTRAINT ck_accrual_posted CHECK (NOT posted OR journal_entry_id IS NOT NULL),
    CONSTRAINT ck_accrual_rate   CHECK (annual_rate >= 0 AND annual_rate < 1)
);
COMMENT ON COLUMN interest_accruals.posted IS
    'FALSE = đã tính, chưa hạch toán. Lãi dồn từng ngày nhưng chỉ nhập sổ khi trả — đó là lý do tách bảng này khỏi journal_lines';

CREATE TABLE fee_charges (
    id               BIGSERIAL     PRIMARY KEY,
    account_id       BIGINT        NOT NULL REFERENCES accounts (id),
    fee_code         VARCHAR(30)   NOT NULL,
    source_type      VARCHAR(30),
    source_id        VARCHAR(100),
    amount           NUMERIC(19,4) NOT NULL,
    currency         CHAR(3)       NOT NULL DEFAULT 'VND',
    status           VARCHAR(20)   NOT NULL DEFAULT 'PENDING',
    journal_entry_id BIGINT        REFERENCES journal_entries (id),
    charged_at       TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT ck_fee_charge_status CHECK (status IN ('PENDING', 'POSTED', 'WAIVED')),
    CONSTRAINT ck_fee_charge_amount CHECK (amount >= 0),
    CONSTRAINT ck_fee_charge_posted CHECK (status <> 'POSTED' OR journal_entry_id IS NOT NULL)
);
COMMENT ON COLUMN fee_charges.status IS
    'WAIVED = miễn phí nhưng VẪN LƯU VẾT đã từng phát sinh. Xóa dòng đi là mất khả năng trả lời "sao tháng này không thu phí khách này"';

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
    'Phát transfer.completed.v1, transfer.reversed.v1... Độc lập với outbox của customer và product';

-- core_banking cũng là CONSUMER: nghe customer.status.changed.v1 để phong tỏa
-- tài khoản khi khách hàng bị đình chỉ.
CREATE TABLE processed_events (
    event_id     VARCHAR(64) PRIMARY KEY,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Append-only cho mọi thao tác ghi của core.
CREATE TABLE audit_log (
    id            BIGSERIAL    PRIMARY KEY,
    actor_user_id BIGINT,
    action        VARCHAR(50)  NOT NULL,
    resource_type VARCHAR(50)  NOT NULL,
    resource_id   VARCHAR(100) NOT NULL,
    detail        JSONB,
    at            TIMESTAMPTZ  NOT NULL DEFAULT now()
);
COMMENT ON COLUMN audit_log.actor_user_id IS
    'NULL = hệ thống hoặc batch job, không phải người';

CREATE INDEX idx_transfers_source   ON transfers (source_account_id, created_at DESC);
CREATE INDEX idx_transfers_dest     ON transfers (destination_account_id, created_at DESC);
CREATE INDEX idx_transfers_pending  ON transfers (created_at) WHERE status IN ('PENDING', 'PENDING_EXTERNAL');
-- Job quét saga treo: chỉ index những dòng chưa kết thúc.
CREATE INDEX idx_ext_active         ON external_transfers (deadline_at)
    WHERE saga_state IN ('HOLD_PLACED', 'PARTNER_REQUESTED');
CREATE INDEX idx_accrual_unposted   ON interest_accruals (accrual_date) WHERE NOT posted;
CREATE INDEX idx_fee_account        ON fee_charges (account_id, charged_at DESC);
CREATE INDEX idx_fee_pending        ON fee_charges (charged_at) WHERE status = 'PENDING';
CREATE INDEX idx_core_outbox_unpub  ON outbox (created_at) WHERE published_at IS NULL;
CREATE INDEX idx_audit_resource     ON audit_log (resource_type, resource_id, at DESC);
CREATE INDEX idx_audit_actor        ON audit_log (actor_user_id, at DESC);

-- updated_at do DB giữ (xem khối [1]). Bỏ các trigger này đi thì cột thành created_at.
CREATE TRIGGER trg_transfers_updated_at BEFORE UPDATE ON transfers
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_ext_transfers_updated_at BEFORE UPDATE ON external_transfers
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_limit_usage_updated_at BEFORE UPDATE ON transfer_limit_usage
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

RESET ROLE;
SET search_path = public;

-- <<< HẾT KHỐI [5c] — kết thúc schema core_banking

-- =====================================================================
-- [7] SEED DATA
--     Chỉ dữ liệu THAM CHIẾU: hệ thống tài khoản và danh mục sản phẩm.
--     KHÔNG seed khách hàng, KHÔNG seed tài khoản — hai thứ đó là dữ liệu
--     nghiệp vụ, phải đi qua đúng luồng mở hồ sơ và mở tài khoản.
-- =====================================================================

SET ROLE core_svc;
SET search_path = core_banking;

-- Chart of accounts tối thiểu. Quy ước đánh số:
--   1xxx TÀI SẢN · 2xxx NỢ PHẢI TRẢ · 3xxx VỐN · 4xxx THU NHẬP · 5xxx CHI PHÍ
-- Tiền gửi của khách hàng là NỢ PHẢI TRẢ của ngân hàng — đây là chỗ người mới
-- hay nhầm nhất: khách gửi tiền vào thì ngân hàng NỢ khách số tiền đó.
INSERT INTO gl_accounts (gl_code, name, account_class, normal_balance, is_postable) VALUES
    ('1010', 'Tiền mặt tại quỹ',                  'ASSET',     'DEBIT',  TRUE),
    ('1900', 'Tài khoản trung gian thanh toán',   'ASSET',     'DEBIT',  TRUE),
    ('2010', 'Tiền gửi khách hàng - thanh toán',  'LIABILITY', 'CREDIT', TRUE),
    ('2020', 'Tiền gửi khách hàng - tiết kiệm',   'LIABILITY', 'CREDIT', TRUE),
    ('2110', 'Lãi phải trả khách hàng',           'LIABILITY', 'CREDIT', TRUE),
    ('3010', 'Vốn điều lệ',                       'EQUITY',    'CREDIT', TRUE),
    ('3020', 'Lợi nhuận giữ lại',                 'EQUITY',    'CREDIT', TRUE),
    ('4010', 'Thu nhập từ phí dịch vụ',           'INCOME',    'CREDIT', TRUE),
    ('5010', 'Chi phí lãi tiền gửi',              'EXPENSE',   'DEBIT',  TRUE);

COMMENT ON TABLE gl_accounts IS
    '1900 là tài khoản trung gian: tiền đã rời tài khoản nguồn nhưng chưa tới đích (chuyển liên ngân hàng đang chờ đối tác). Số dư của nó phải về 0 sau mỗi phiên đối chiếu';

RESET ROLE;
SET search_path = public;

SET ROLE product_svc;
SET search_path = product;

INSERT INTO products (product_code, name, category, currency, status, description) VALUES
    ('CA_STANDARD', 'Tài khoản thanh toán chuẩn',      'CURRENT_ACCOUNT', 'VND', 'ACTIVE', 'Tài khoản dùng hằng ngày, lãi suất không kỳ hạn'),
    ('SA_STANDARD', 'Tài khoản tiết kiệm không kỳ hạn', 'SAVINGS_ACCOUNT', 'VND', 'ACTIVE', 'Rút bất cứ lúc nào, lãi bậc thang theo số dư'),
    ('TD_12M',      'Tiền gửi có kỳ hạn 12 tháng',      'TERM_DEPOSIT',    'VND', 'ACTIVE', 'Rút trước hạn hưởng lãi không kỳ hạn');

-- Lãi suất. CA phẳng; SA bậc thang theo số dư; TD theo kỳ hạn.
INSERT INTO product_interest_rates (product_id, tier_from, tier_to, term_months, annual_rate)
SELECT id, 0, NULL, NULL, 0.001000 FROM products WHERE product_code = 'CA_STANDARD';

INSERT INTO product_interest_rates (product_id, tier_from, tier_to, term_months, annual_rate)
SELECT id, 0, 100000000, NULL::INT, 0.005000 FROM products WHERE product_code = 'SA_STANDARD'
UNION ALL
SELECT id, 100000000, NULL, NULL, 0.008000 FROM products WHERE product_code = 'SA_STANDARD';

INSERT INTO product_interest_rates (product_id, tier_from, tier_to, term_months, annual_rate)
SELECT id, 0, NULL, 12, 0.055000 FROM products WHERE product_code = 'TD_12M';

-- Biểu phí của tài khoản thanh toán.
INSERT INTO product_fees (product_id, fee_code, fee_type, amount, percent, min_amount, max_amount, charge_event)
SELECT id, 'MAINT_MONTHLY', 'FLAT',    11000, NULL::NUMERIC,    NULL::NUMERIC,    NULL::NUMERIC, 'MONTHLY_MAINTENANCE' FROM products WHERE product_code = 'CA_STANDARD'
UNION ALL
SELECT id, 'TRF_INTERNAL',  'FLAT',        0, NULL,    NULL,    NULL, 'INTERNAL_TRANSFER'   FROM products WHERE product_code = 'CA_STANDARD'
UNION ALL
SELECT id, 'TRF_EXTERNAL',  'PERCENT',  NULL, 0.000500, 5500, 1100000, 'EXTERNAL_TRANSFER'  FROM products WHERE product_code = 'CA_STANDARD';

-- Hạn mức chuyển tiền của tài khoản thanh toán.
INSERT INTO product_limits (product_id, limit_code, scope, channel, max_amount, max_count)
SELECT id, 'TRF_PER_TXN', 'PER_TRANSACTION', 'ANY',      500000000, NULL FROM products WHERE product_code = 'CA_STANDARD'
UNION ALL
SELECT id, 'TRF_PER_DAY', 'PER_DAY',         'ANY',     1000000000,   20 FROM products WHERE product_code = 'CA_STANDARD'
UNION ALL
SELECT id, 'TRF_PER_TXN', 'PER_TRANSACTION', 'MOBILE',   100000000, NULL FROM products WHERE product_code = 'CA_STANDARD';

-- Điều kiện mở tài khoản.
INSERT INTO product_eligibility_rules (product_id, rule_type, operator, rule_value)
SELECT id, 'MIN_AGE',       'GTE', '18' FROM products WHERE product_code = 'CA_STANDARD'
UNION ALL
SELECT id, 'MIN_KYC_LEVEL', 'GTE', '1'  FROM products WHERE product_code = 'CA_STANDARD'
UNION ALL
SELECT id, 'MIN_KYC_LEVEL', 'GTE', '2'  FROM products WHERE product_code = 'TD_12M';

-- CẦU NỐI sang sổ cái: mỗi sản phẩm hạch toán vào GL nào.
INSERT INTO product_gl_mappings (product_id, purpose, gl_code)
SELECT id, 'PRINCIPAL',        '2010' FROM products WHERE product_code = 'CA_STANDARD'
UNION ALL SELECT id, 'INTEREST_PAYABLE', '2110' FROM products WHERE product_code = 'CA_STANDARD'
UNION ALL SELECT id, 'INTEREST_EXPENSE', '5010' FROM products WHERE product_code = 'CA_STANDARD'
UNION ALL SELECT id, 'FEE_INCOME',       '4010' FROM products WHERE product_code = 'CA_STANDARD'
UNION ALL SELECT id, 'PRINCIPAL',        '2020' FROM products WHERE product_code = 'SA_STANDARD'
UNION ALL SELECT id, 'INTEREST_PAYABLE', '2110' FROM products WHERE product_code = 'SA_STANDARD'
UNION ALL SELECT id, 'INTEREST_EXPENSE', '5010' FROM products WHERE product_code = 'SA_STANDARD'
UNION ALL SELECT id, 'FEE_INCOME',       '4010' FROM products WHERE product_code = 'SA_STANDARD'
UNION ALL SELECT id, 'PRINCIPAL',        '2020' FROM products WHERE product_code = 'TD_12M'
UNION ALL SELECT id, 'INTEREST_PAYABLE', '2110' FROM products WHERE product_code = 'TD_12M'
UNION ALL SELECT id, 'INTEREST_EXPENSE', '5010' FROM products WHERE product_code = 'TD_12M'
UNION ALL SELECT id, 'FEE_INCOME',       '4010' FROM products WHERE product_code = 'TD_12M';

RESET ROLE;
SET search_path = public;


-- =====================================================================
-- [8] GHI CHÚ VẬN HÀNH
--
--  TẠO PARTITION THÁNG MỚI. journal_lines có partition tới hết 2026-10 và một
--  DEFAULT hứng phần còn lại. DEFAULT là lưới an toàn, không phải chỗ để dữ liệu
--  ở lâu: nó không được prune nên mọi truy vấn đều phải quét nó.
--    CREATE TABLE core_banking.journal_lines_2026_11
--        PARTITION OF core_banking.journal_lines
--        FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
--  Nếu DEFAULT đã có dữ liệu thuộc khoảng đó, lệnh trên sẽ bị từ chối — phải
--  tách dữ liệu ra trước. Đó là lý do tạo partition TRƯỚC khi cần, bằng job.
--
--  XÓA DỮ LIỆU CŨ. DROP một partition tháng = lưu trữ tức thì, thay cho DELETE
--  hàng triệu dòng. Đây là lợi ích lớn nhất của partition ở bảng sổ cái.
--
--  ĐÁNH INDEX THEO BẰNG CHỨNG. Các index trong file này phục vụ những truy vấn
--  đã biết chắc sẽ có (sao kê theo tài khoản, quét outbox chưa publish, quét
--  saga treo). Index tiếp theo chỉ thêm sau khi EXPLAIN trên dữ liệu thật cho
--  thấy cần — index thừa làm chậm mọi lệnh ghi trên bảng nóng.
--
--  ĐỐI CHIẾU. Hai phép kiểm phải luôn đúng, chạy định kỳ:
--    1. Với mỗi bút toán: SUM(DEBIT) = SUM(CREDIT). Trigger đã đảm bảo lúc ghi,
--       nhưng vẫn nên quét lại để phát hiện can thiệp trực tiếp vào DB.
--    2. Với mỗi GL: SUM(số dư các accounts trỏ vào gl_code đó) = số dư GL tính
--       từ journal_lines. Lệch nghĩa là accounts.ledger_balance đã trôi khỏi sổ cái.
--
--  KHI BẬT FLYWAY. Cắt phần schema của service từ file này thành
--  V<yyyyMMddHHmm>__<mô_tả>.sql trong db/migration/, rồi đổi
--  spring.flyway.enabled thành true. Với database đã có sẵn bảng do file này
--  tạo, cần thêm spring.flyway.baseline-on-migrate=true cho lần chạy đầu —
--  hoặc sạch hơn: docker compose down -v rồi để Flyway dựng lại từ đầu.
-- =====================================================================
