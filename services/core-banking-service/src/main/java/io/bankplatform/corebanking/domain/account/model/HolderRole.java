package io.bankplatform.corebanking.domain.account.model;

/**
 * Vai trò chủ tài khoản, khớp CHECK constraint ck_holder_role trong schema.sql.
 */
public enum HolderRole {
    PRIMARY,
    JOINT,
    AUTHORIZED_SIGNATORY
}
