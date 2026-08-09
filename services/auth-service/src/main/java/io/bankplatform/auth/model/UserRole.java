package io.bankplatform.auth.model;

/**
 * Ứng với {@code ck_user_roles_role} trên {@code auth.user_roles.role} (schema.sql khối [2]).
 */
public enum UserRole {
    CUSTOMER,
    TELLER,
    CSO,
    RISK_OFFICER,
    ADMIN,
    SYSTEM
}
