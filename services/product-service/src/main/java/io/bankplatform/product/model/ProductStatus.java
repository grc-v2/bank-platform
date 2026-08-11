package io.bankplatform.product.model;

/**
 * Trạng thái vòng đời sản phẩm, khớp CHECK constraint ck_products_status trong schema.sql.
 */
public enum ProductStatus {
    DRAFT,
    ACTIVE,
    RETIRED
}
