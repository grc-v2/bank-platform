package io.bankplatform.product.model;

/**
 * Loại điều kiện điều kiện mở sản phẩm, khớp CHECK constraint ck_rule_type trong schema.sql.
 */
public enum EligibilityRuleType {
    MIN_AGE,
    MAX_AGE,
    MIN_KYC_LEVEL,
    CUSTOMER_TYPE,
    MAX_RISK_RATING
}
