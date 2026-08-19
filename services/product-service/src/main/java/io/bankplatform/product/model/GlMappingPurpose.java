package io.bankplatform.product.model;

/**
 * Mục đích hạch toán GL của sản phẩm, khớp CHECK constraint ck_glmap_purpose trong schema.sql.
 */
public enum GlMappingPurpose {
    PRINCIPAL,
    INTEREST_PAYABLE,
    INTEREST_EXPENSE,
    FEE_INCOME
}
