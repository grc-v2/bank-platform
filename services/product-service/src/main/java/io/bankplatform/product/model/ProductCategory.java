package io.bankplatform.product.model;

/**
 * Danh mục sản phẩm ngân hàng, khớp CHECK constraint ck_products_category trong schema.sql.
 */
public enum ProductCategory {
    CURRENT_ACCOUNT,
    SAVINGS_ACCOUNT,
    TERM_DEPOSIT
}
