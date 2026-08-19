package io.bankplatform.corebanking.domain.account.model;

/**
 * Lý do phong tỏa tạm thời số dư tài khoản, khớp CHECK constraint ck_hold_reason trong schema.sql.
 */
public enum HoldReason {
    TRANSFER,
    CARD_AUTH,
    LEGAL,
    FEE
}
