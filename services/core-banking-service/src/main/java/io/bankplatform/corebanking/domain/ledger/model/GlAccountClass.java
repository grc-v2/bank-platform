package io.bankplatform.corebanking.domain.ledger.model;

/**
 * Phân loại tài khoản sổ cái GL, khớp CHECK constraint ck_gl_class trong schema.sql.
 */
public enum GlAccountClass {
    ASSET,
    LIABILITY,
    EQUITY,
    INCOME,
    EXPENSE
}
