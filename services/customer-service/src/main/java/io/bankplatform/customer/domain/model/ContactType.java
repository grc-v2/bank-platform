package io.bankplatform.customer.domain.model;

/**
 * Loại kênh liên hệ khách hàng, khớp CHECK constraint ck_contact_type trong schema.sql.
 */
public enum ContactType {
    EMAIL,
    MOBILE,
    PHONE
}
