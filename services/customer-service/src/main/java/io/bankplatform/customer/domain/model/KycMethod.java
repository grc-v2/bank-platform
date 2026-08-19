package io.bankplatform.customer.domain.model;

/**
 * Phương thức xác minh KYC, khớp CHECK constraint ck_kyc_method trong schema.sql.
 */
public enum KycMethod {
    MANUAL,
    EKYC
}
