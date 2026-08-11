package io.bankplatform.customer.domain.model;

/**
 * Trạng thái xác minh KYC, khớp CHECK constraint ck_kyc_status trong schema.sql.
 */
public enum KycStatus {
    PENDING,
    IN_REVIEW,
    APPROVED,
    REJECTED,
    EXPIRED
}
