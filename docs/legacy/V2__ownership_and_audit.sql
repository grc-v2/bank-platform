-- core_banking / V2__ownership_and_audit.sql — ĐÁP ÁN MẪU, dùng khi vào M2
-- Bước EXPAND của expand–contract: chỉ THÊM, không siết — code cũ (Phase 0-1)
-- vẫn chạy được trên schema này trong suốt quá trình rollout.

-- Tham chiếu MỀM sang auth.users: cột thường, KHÔNG FK xuyên schema.
-- NULL được phép ở bước này — tài khoản cũ chưa có chủ.
ALTER TABLE accounts
    ADD COLUMN owner_user_id BIGINT;

CREATE INDEX idx_accounts_owner ON accounts (owner_user_id);

-- Audit append-only cho mọi thao tác ghi của core (audit-starter M2 sẽ ghi vào đây).
CREATE TABLE audit_log (
    id            BIGSERIAL PRIMARY KEY,
    actor_user_id BIGINT,                       -- NULL = hệ thống/batch
    action        VARCHAR(50)  NOT NULL,        -- vd: TRANSFER_CREATE, ACCOUNT_FREEZE
    resource_type VARCHAR(50)  NOT NULL,
    resource_id   VARCHAR(100) NOT NULL,
    detail        JSONB,
    at            TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_resource ON audit_log (resource_type, resource_id, at DESC);
CREATE INDEX idx_audit_actor    ON audit_log (actor_user_id, at DESC);

-- Bước CONTRACT làm ở migration SAU (vd V2_1), CHỈ sau khi:
--   1. Backfill xong: mọi account CUSTOMER được gán chủ (script/app-side, không ở đây)
--   2. Code mới đã rollout xong (không còn phiên bản không biết owner_user_id)
-- Khi đó mới:
--   ALTER TABLE accounts
--     ADD CONSTRAINT customer_must_have_owner
--     CHECK (type = 'SYSTEM' OR owner_user_id IS NOT NULL);
-- (Dùng CHECK thay NOT NULL để tài khoản SYSTEM tiếp tục vô chủ hợp lệ.)
