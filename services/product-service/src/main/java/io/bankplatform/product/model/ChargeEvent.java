package io.bankplatform.product.model;

/**
 * Sự kiện kích hoạt thu phí, khớp CHECK constraint ck_fee_event trong schema.sql.
 */
public enum ChargeEvent {
    ACCOUNT_OPEN,
    ACCOUNT_CLOSE,
    MONTHLY_MAINTENANCE,
    INTERNAL_TRANSFER,
    EXTERNAL_TRANSFER,
    ATM_WITHDRAWAL,
    STATEMENT_REQUEST
}
