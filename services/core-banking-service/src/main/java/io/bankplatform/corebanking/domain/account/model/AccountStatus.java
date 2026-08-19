package io.bankplatform.corebanking.domain.account.model;

/**
 * Trạng thái tài khoản khách hàng, khớp CHECK constraint ck_accounts_status trong schema.sql.
 */
public enum AccountStatus {
    PENDING,
    ACTIVE,
    DORMANT,
    FROZEN,
    CLOSED
}
