package io.bankplatform.corebanking.domain.account.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import org.hibernate.annotations.Generated;
import org.hibernate.generator.EventType;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

/**
 * Entity phong tỏa tạm thời tiền trên tài khoản (schema core_banking).
 */
@Entity
@Table(name = "account_holds")
public class AccountHold extends io.bankplatform.common.ddd.Entity<Long> {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "account_id", nullable = false)
    private Long accountId;

    @Column(name = "amount", nullable = false, precision = 19, scale = 4)
    private BigDecimal amount;

    @Enumerated(EnumType.STRING)
    @Column(name = "reason", nullable = false, length = 20)
    private HoldReason reason;

    @Column(name = "reference_type", length = 30)
    private String referenceType;

    @Column(name = "reference_id", length = 100)
    private String referenceId;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private HoldStatus status = HoldStatus.ACTIVE;

    @Generated(event = EventType.INSERT)
    @Column(name = "placed_at", insertable = false, updatable = false)
    private OffsetDateTime placedAt;

    @Column(name = "expires_at")
    private OffsetDateTime expiresAt;

    @Column(name = "released_at")
    private OffsetDateTime releasedAt;

    protected AccountHold() {
    }

    public AccountHold(Long accountId, BigDecimal amount, HoldReason reason,
                       String referenceType, String referenceId, OffsetDateTime expiresAt) {
        this.accountId = accountId;
        this.amount = amount;
        this.reason = reason;
        this.referenceType = referenceType;
        this.referenceId = referenceId;
        this.status = HoldStatus.ACTIVE;
        this.expiresAt = expiresAt;
    }

    @Override
    public Long getId() {
        return id;
    }

    public Long getAccountId() {
        return accountId;
    }

    public BigDecimal getAmount() {
        return amount;
    }

    public HoldReason getReason() {
        return reason;
    }

    public String getReferenceType() {
        return referenceType;
    }

    public String getReferenceId() {
        return referenceId;
    }

    public HoldStatus getStatus() {
        return status;
    }

    public void setStatus(HoldStatus status) {
        this.status = status;
    }

    public OffsetDateTime getPlacedAt() {
        return placedAt;
    }

    public OffsetDateTime getExpiresAt() {
        return expiresAt;
    }

    public void setExpiresAt(OffsetDateTime expiresAt) {
        this.expiresAt = expiresAt;
    }

    public OffsetDateTime getReleasedAt() {
        return releasedAt;
    }

    public void setReleasedAt(OffsetDateTime releasedAt) {
        this.releasedAt = releasedAt;
    }
}
