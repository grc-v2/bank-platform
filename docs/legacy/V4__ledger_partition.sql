-- core_banking / V4__ledger_partition.sql — ĐÁP ÁN MẪU, dùng khi vào M4
-- Chiến lược cho demo: dừng-ghi rồi hoán đổi bảng (chấp nhận downtime local).
-- Production dùng đường khác (pg_partman / attach dần) — ghi nhận trong ADR M4.
-- CHẠY SAU KHI đã EXPLAIN trên dữ liệu lớn từ data generator — đúng kỷ luật
-- "index/partition theo bằng chứng".

BEGIN;

-- 1) Bảng mới partition theo RANGE tháng trên created_at.
--    Lưu ý cơ chế: PK của bảng partition PHẢI CHỨA cột partition -> PK (id, created_at).
--    Hệ quả thật đáng học: UNIQUE toàn cục theo id đơn lẻ không còn được DB đảm bảo.
CREATE TABLE ledger_entries_p (
    id            BIGINT        NOT NULL DEFAULT nextval('ledger_entries_id_seq'),
    transfer_id   BIGINT        NOT NULL,
    account_id    BIGINT        NOT NULL,
    entry_type    VARCHAR(6)    NOT NULL CHECK (entry_type IN ('DEBIT', 'CREDIT')),
    amount        NUMERIC(19,4) NOT NULL CHECK (amount > 0),
    balance_after NUMERIC(19,4) NOT NULL,
    created_at    TIMESTAMPTZ   NOT NULL DEFAULT now(),
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- 2) Partition theo tháng + DEFAULT hứng dữ liệu ngoài khoảng.
--    (Tạo tay vài tháng để hiểu; sinh tự động là việc của job/pg_partman sau này.)
CREATE TABLE ledger_entries_2026_08 PARTITION OF ledger_entries_p
    FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE ledger_entries_2026_09 PARTITION OF ledger_entries_p
    FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE ledger_entries_2026_10 PARTITION OF ledger_entries_p
    FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE ledger_entries_default PARTITION OF ledger_entries_p DEFAULT;

-- 3) Chuyển dữ liệu, hoán đổi tên, giữ nguyên sequence.
INSERT INTO ledger_entries_p (id, transfer_id, account_id, entry_type, amount, balance_after, created_at)
SELECT id, transfer_id, account_id, entry_type, amount, balance_after, created_at
FROM ledger_entries;

ALTER SEQUENCE ledger_entries_id_seq OWNED BY ledger_entries_p.id;
ALTER TABLE ledger_entries RENAME TO ledger_entries_old;
ALTER TABLE ledger_entries_p RENAME TO ledger_entries;

-- 4) Index trên bảng partition (tự lan xuống từng partition):
--    - Composite sao kê "để dành từ V1", giờ mới đánh — sau bằng chứng EXPLAIN.
CREATE INDEX idx_ledger_account_at ON ledger_entries (account_id, created_at DESC);
CREATE INDEX idx_ledger_transfer_p ON ledger_entries (transfer_id);

COMMIT;

-- 5) Sau khi reconciliation test xanh trên bảng mới: DROP TABLE ledger_entries_old;
--    (để ngoài transaction trên, chạy tay — có đường lui nếu nghi ngờ)

-- Ghi chú trade-off cho ADR M4:
--   * FK từ bảng khác trỏ VÀO bảng partition bị hạn chế -> V1 đã trỏ ledger->transfers
--     (hướng ra) nên an toàn; chiều ngược lại không tồn tại — thiết kế V1 đã né trước.
--   * Truy vấn sao kê có WHERE account_id + khoảng created_at -> partition pruning;
--     chứng minh bằng EXPLAIN trước/sau, đếm số partition bị chạm.
--   * Drop partition tháng cũ = archive tức thời, thay cho DELETE triệu dòng.
