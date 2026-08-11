package io.bankplatform.corebanking.domain.ledger.model;

/**
 * Loại giao dịch kế toán, khớp CHECK constraint ck_journal_txn_type trong schema.sql.
 */
public enum TransactionType {
    TRANSFER,
    FEE,
    INTEREST,
    REVERSAL,
    ADJUSTMENT,
    OPENING
}
