package io.bankplatform.corebanking.domain.ledger.model;

/**
 * Tính chất số dư chuẩn của tài khoản GL, khớp CHECK constraint ck_gl_normal trong schema.sql.
 */
public enum NormalBalance {
    DEBIT,
    CREDIT
}
