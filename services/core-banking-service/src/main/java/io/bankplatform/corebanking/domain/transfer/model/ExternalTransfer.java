package io.bankplatform.corebanking.domain.transfer.model;

import io.javalibs.ddd.Entity;
import jakarta.persistence.*;
import org.hibernate.annotations.Generated;
import org.hibernate.generator.EventType;

import java.time.OffsetDateTime;

/**
 * Entity Saga quản lý chuyển tiền liên ngân hàng (schema core_banking).
 */
@jakarta.persistence.Entity
@Table(name = "external_transfers")
public class ExternalTransfer extends Entity<Long> {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "transfer_id", nullable = false, unique = true)
    private Long transferId;

    @Column(name = "partner_code", nullable = false, length = 20)
    private String partnerCode;

    @Column(name = "partner_ref", length = 100)
    private String partnerRef;

    @Enumerated(EnumType.STRING)
    @Column(name = "saga_state", nullable = false, length = 30)
    private SagaState sagaState = SagaState.HOLD_PLACED;

    @Column(name = "partner_idempotency_key", nullable = false, unique = true, length = 64)
    private String partnerIdempotencyKey;

    @Column(name = "deadline_at", nullable = false)
    private OffsetDateTime deadlineAt;

    @Generated(event = EventType.INSERT)
    @Column(name = "created_at", insertable = false, updatable = false)
    private OffsetDateTime createdAt;

    @Generated(event = {EventType.INSERT, EventType.UPDATE})
    @Column(name = "updated_at", insertable = false, updatable = false)
    private OffsetDateTime updatedAt;

    protected ExternalTransfer() {
    }

    public ExternalTransfer(Long transferId, String partnerCode, String partnerRef,
                            SagaState sagaState, String partnerIdempotencyKey, OffsetDateTime deadlineAt) {
        this.transferId = transferId;
        this.partnerCode = partnerCode;
        this.partnerRef = partnerRef;
        this.sagaState = sagaState != null ? sagaState : SagaState.HOLD_PLACED;
        this.partnerIdempotencyKey = partnerIdempotencyKey;
        this.deadlineAt = deadlineAt;
    }

    @Override
    public Long getId() {
        return id;
    }

    public Long getTransferId() {
        return transferId;
    }

    public String getPartnerCode() {
        return partnerCode;
    }

    public String getPartnerRef() {
        return partnerRef;
    }

    public void setPartnerRef(String partnerRef) {
        this.partnerRef = partnerRef;
    }

    public SagaState getSagaState() {
        return sagaState;
    }

    public void setSagaState(SagaState sagaState) {
        this.sagaState = sagaState;
    }

    public String getPartnerIdempotencyKey() {
        return partnerIdempotencyKey;
    }

    public OffsetDateTime getDeadlineAt() {
        return deadlineAt;
    }

    public void setDeadlineAt(OffsetDateTime deadlineAt) {
        this.deadlineAt = deadlineAt;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }

    public OffsetDateTime getUpdatedAt() {
        return updatedAt;
    }
}
