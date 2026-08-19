package io.bankplatform.corebanking.domain.ledger.model;

/**
 * Trạng thái của khoản phí thu, khớp CHECK constraint ck_fee_charge_status trong schema.sql.
 */
public enum FeeChargeStatus {
    PENDING,
    POSTED,
    WAIVED
}
