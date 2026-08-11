package io.bankplatform.corebanking.domain.transfer.model;

/**
 * Trạng thái của lệnh chuyển tiền, khớp CHECK constraint ck_transfers_status trong schema.sql.
 */
public enum TransferStatus {
    PENDING,
    PENDING_EXTERNAL,
    COMPLETED,
    FAILED,
    REVERSED
}
