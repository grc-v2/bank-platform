package io.bankplatform.customer.domain.model;

/**
 * Loại khách hàng (Cá nhân hoặc Tổ chức), khớp CHECK constraint ck_customers_type trong schema.sql.
 */
public enum CustomerType {
    INDIVIDUAL,
    ORGANIZATION
}
