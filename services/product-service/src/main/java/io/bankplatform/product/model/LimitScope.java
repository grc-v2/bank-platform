package io.bankplatform.product.model;

/**
 * Phạm vi tính hạn mức, khớp CHECK constraint ck_limit_scope trong schema.sql.
 */
public enum LimitScope {
    PER_TRANSACTION,
    PER_DAY,
    PER_MONTH
}
