package io.bankplatform.product.model;

/**
 * Kênh giao dịch áp dụng hạn mức, khớp CHECK constraint ck_limit_channel trong schema.sql.
 */
public enum LimitChannel {
    ANY,
    INTERNET,
    MOBILE,
    ATM,
    BRANCH
}
