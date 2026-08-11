package io.bankplatform.corebanking.domain.account.model;

/**
 * Trạng thái của lệnh phong tỏa tiền, khớp CHECK constraint ck_hold_status trong schema.sql.
 */
public enum HoldStatus {
    ACTIVE,
    RELEASED,
    CAPTURED,
    EXPIRED
}
