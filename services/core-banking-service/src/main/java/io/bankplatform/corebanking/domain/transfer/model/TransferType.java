package io.bankplatform.corebanking.domain.transfer.model;

/**
 * Loại chuyển tiền (Nội bộ / Liên ngân hàng), khớp CHECK constraint ck_transfers_type trong schema.sql.
 */
public enum TransferType {
    INTERNAL,
    EXTERNAL
}
