package io.bankplatform.customer.domain.model;

/**
 * Loại địa chỉ khách hàng, khớp CHECK constraint ck_address_type trong schema.sql.
 */
public enum AddressType {
    PERMANENT,
    RESIDENTIAL,
    MAILING,
    BUSINESS
}
