package io.bankplatform.corebanking.domain.transfer.model;

/**
 * Kênh khởi tạo giao dịch chuyển tiền, khớp CHECK constraint ck_transfers_channel trong schema.sql.
 */
public enum TransferChannel {
    INTERNET,
    MOBILE,
    ATM,
    BRANCH,
    API
}
