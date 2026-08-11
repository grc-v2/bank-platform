package io.bankplatform.product.model;

/**
 * Loại biểu phí (cố định hoặc phần trăm), khớp CHECK constraint ck_fee_type trong schema.sql.
 */
public enum FeeType {
    FLAT,
    PERCENT
}
