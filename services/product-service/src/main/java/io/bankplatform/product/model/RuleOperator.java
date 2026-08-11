package io.bankplatform.product.model;

/**
 * Toán tử so sánh điều kiện mở sản phẩm, khớp CHECK constraint ck_rule_operator trong schema.sql.
 */
public enum RuleOperator {
    EQ,
    NEQ,
    GTE,
    LTE,
    IN
}
