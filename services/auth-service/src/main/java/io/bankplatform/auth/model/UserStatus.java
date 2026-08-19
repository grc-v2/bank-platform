package io.bankplatform.auth.model;

/**
 * Ứng với {@code ck_users_status} trên {@code auth.users.status} (schema.sql khối [2]).
 */
public enum UserStatus {
    ACTIVE,
    LOCKED,
    DISABLED
}
