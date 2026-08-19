package io.bankplatform.corebanking.domain.ledger.model;

/**
 * Trạng thái tài khoản GL, khớp CHECK constraint ck_gl_status trong schema.sql.
 */
public enum GlAccountStatus {
    ACTIVE,
    CLOSED
}
