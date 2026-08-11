package io.bankplatform.customer.domain.model;

/**
 * Trạng thái hồ sơ khách hàng, khớp CHECK constraint ck_customers_status trong schema.sql.
 */
public enum CustomerStatus {
    DRAFT,
    PENDING_KYC,
    ACTIVE,
    SUSPENDED,
    CLOSED
}
