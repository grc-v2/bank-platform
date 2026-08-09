-- 01-init-schemas.sql — chạy một lần khi Postgres khởi tạo (docker-entrypoint-initdb.d)
-- Mua ranh giới service từ ngày 1: 3 schema + 3 DB user, mỗi service chỉ thấy schema của mình.
-- compose.yaml: mount thư mục docker/initdb vào /docker-entrypoint-initdb.d

CREATE SCHEMA IF NOT EXISTS core_banking;
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS notification;

-- Mật khẩu dev — đổi qua biến môi trường khi lên K8s (M5)
CREATE USER core_svc WITH PASSWORD 'core_dev';
CREATE USER auth_svc WITH PASSWORD 'auth_dev';
CREATE USER noti_svc WITH PASSWORD 'noti_dev';

-- Mỗi user toàn quyền TRONG schema của mình (Flyway cần CREATE), không thấy schema khác
GRANT ALL ON SCHEMA core_banking TO core_svc;
GRANT ALL ON SCHEMA auth         TO auth_svc;
GRANT ALL ON SCHEMA notification TO noti_svc;

ALTER USER core_svc SET search_path = core_banking;
ALTER USER auth_svc SET search_path = auth;
ALTER USER noti_svc SET search_path = notification;

-- Chặn quyền mặc định trên schema public để không ai "đi lạc"
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
