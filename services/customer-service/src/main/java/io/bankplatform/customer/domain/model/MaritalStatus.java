package io.bankplatform.customer.domain.model;

/**
 * Tình trạng hôn nhân, khớp CHECK constraint ck_individual_marital trong schema.sql.
 */
public enum MaritalStatus {
    SINGLE,
    MARRIED,
    DIVORCED,
    WIDOWED
}
