-- core_banking / V3__outbox_and_external.sql — ĐÁP ÁN MẪU, dùng khi vào M3

-- 1) Transactional Outbox: event ghi CÙNG transaction với nghiệp vụ,
--    publisher tách rời poll rồi đẩy Kafka — giải bài dual-write (deep-dive M3).
CREATE TABLE outbox (
    id             BIGSERIAL PRIMARY KEY,
    aggregate_type VARCHAR(50)  NOT NULL,      -- 'transfer'
    aggregate_id   VARCHAR(100) NOT NULL,      -- transfer id
    event_type     VARCHAR(100) NOT NULL,      -- 'transfer.completed.v1'
    -- Payload TỰ ĐỦ (event-carried state): consumer không gọi ngược hỏi thêm
    payload        JSONB        NOT NULL,
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    published_at   TIMESTAMPTZ                  -- NULL = chưa publish
);
-- Partial index: publisher chỉ quét hàng chưa publish — bảng lớn dần vẫn nhanh
CREATE INDEX idx_outbox_unpublished ON outbox (created_at) WHERE published_at IS NULL;

-- 2) Trạng thái saga liên ngân hàng.
--    Lưu ý: CHECK inline trong V1 được Postgres tự đặt tên 'transfers_status_check' —
--    xác minh tên bằng \d transfers trước khi chạy (bài học đặt tên constraint tường minh!).
ALTER TABLE transfers DROP CONSTRAINT transfers_status_check;
ALTER TABLE transfers ADD CONSTRAINT transfers_status_check
    CHECK (status IN ('PENDING', 'PENDING_EXTERNAL', 'COMPLETED', 'FAILED', 'REVERSED'));

-- 3) Bảng saga cho chuyển tiền liên ngân hàng (orchestration state).
--    PENDING_EXTERNAL = tiền đã trừ nguồn (hold), chờ partner xác nhận;
--    thất bại/timeout -> bút toán đảo (reversal), KHÔNG xóa bút toán gốc.
CREATE TABLE external_transfers (
    id             BIGSERIAL PRIMARY KEY,
    transfer_id    BIGINT       NOT NULL UNIQUE REFERENCES transfers (id),
    partner_code   VARCHAR(20)  NOT NULL,       -- 'MOCKBANK'
    partner_ref    VARCHAR(100),                -- mã tham chiếu phía đối tác
    saga_state     VARCHAR(30)  NOT NULL DEFAULT 'HOLD_PLACED'
                   CHECK (saga_state IN (
                       'HOLD_PLACED',           -- đã trừ nguồn, chưa gọi partner
                       'PARTNER_REQUESTED',     -- đã gọi, chờ trả lời
                       'PARTNER_CONFIRMED',     -- xong -> transfer COMPLETED
                       'PARTNER_REJECTED',      -- bị từ chối -> reversal
                       'TIMED_OUT',             -- quá hạn -> reversal
                       'COMPENSATED'            -- bút toán đảo đã ghi
                   )),
    -- Idempotency với ĐỐI TÁC: retry gọi partner dùng lại key này
    partner_idempotency_key VARCHAR(64) NOT NULL UNIQUE,
    deadline_at    TIMESTAMPTZ  NOT NULL,       -- quá hạn -> job quét chuyển TIMED_OUT
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ  NOT NULL DEFAULT now()
);
-- Job quét saga treo: chỉ index hàng chưa kết thúc
CREATE INDEX idx_ext_active ON external_transfers (deadline_at)
    WHERE saga_state IN ('HOLD_PLACED', 'PARTNER_REQUESTED');
