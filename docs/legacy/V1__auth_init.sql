-- auth / V1__auth_init.sql — ĐÁP ÁN MẪU, copy vào auth-service khi vào M2
-- (Flyway của auth-service: schemas=auth, user auth_svc)
-- Nguyên tắc: auth chỉ biết danh tính — không biết gì về tài khoản ngân hàng.

CREATE TABLE users (
    id            BIGSERIAL PRIMARY KEY,
    username      VARCHAR(100)  NOT NULL UNIQUE,
    -- BCrypt cho ra chuỗi 60 ký tự; để 100 phòng đổi thuật toán (argon2 dài hơn)
    password_hash VARCHAR(100)  NOT NULL,
    status        VARCHAR(20)   NOT NULL DEFAULT 'ACTIVE'
                  CHECK (status IN ('ACTIVE', 'LOCKED', 'DISABLED')),
    created_at    TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- Bảng nối thay vì cột role: một người kiêm TELLER + ADMIN được
CREATE TABLE user_roles (
    user_id BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    role    VARCHAR(20) NOT NULL CHECK (role IN ('CUSTOMER', 'TELLER', 'ADMIN')),
    PRIMARY KEY (user_id, role)
);

-- Lời giải bài "thu hồi JWT" (deep-dive M2): access token ngắn hạn stateless,
-- khả năng thu hồi đặt ở refresh token — khóa user = revoke mọi refresh token.
CREATE TABLE refresh_tokens (
    id         BIGSERIAL PRIMARY KEY,
    user_id    BIGINT       NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    -- Lưu HASH của token, không lưu token thô: lộ DB không lộ phiên đăng nhập
    token_hash VARCHAR(64)  NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ  NOT NULL,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- Append-only. Nguyên liệu cho AI phát hiện bất thường ở M6.
CREATE TABLE login_audit (
    id         BIGSERIAL PRIMARY KEY,
    -- Không FK: giữ được cả lần đăng nhập với username không tồn tại
    username   VARCHAR(100) NOT NULL,
    user_id    BIGINT,
    success    BOOLEAN      NOT NULL,
    ip         INET,
    user_agent VARCHAR(500),
    at         TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_refresh_user  ON refresh_tokens (user_id);
CREATE INDEX idx_login_user_at ON login_audit (username, at DESC);
