package io.bankplatform.corebanking.domain.transfer.model;

/**
 * Trạng thái Saga giao dịch liên ngân hàng, khớp CHECK constraint ck_ext_saga_state trong schema.sql.
 */
public enum SagaState {
    HOLD_PLACED,
    PARTNER_REQUESTED,
    PARTNER_CONFIRMED,
    PARTNER_REJECTED,
    TIMED_OUT,
    COMPENSATED
}
