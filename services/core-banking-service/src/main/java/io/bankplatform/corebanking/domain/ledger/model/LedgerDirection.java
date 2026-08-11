package io.bankplatform.corebanking.domain.ledger.model;

/**
 * Chiều hạch toán Nợ/Có (DEBIT/CREDIT), khớp CHECK constraint ck_line_direction trong schema.sql.
 * Ghi chú L7: enum nội bộ core-banking.
 */
public enum LedgerDirection {
    DEBIT,
    CREDIT
}
