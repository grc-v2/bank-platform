package io.bankplatform.customer.domain.model;

/**
 * Loại giấy tờ định danh, khớp CHECK constraint ck_ident_type trong schema.sql.
 */
public enum IdentificationType {
    NATIONAL_ID,
    PASSPORT,
    DRIVER_LICENSE,
    BUSINESS_LICENSE
}
