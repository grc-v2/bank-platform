package io.bankplatform.corebanking.domain.ledger.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import org.hibernate.annotations.Generated;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.generator.EventType;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

/**
 * Entity khoản phí thu của tài khoản (schema core_banking).
 * Setters chỉ dành cho trạng thái chuyển giao dịch hạch toán (status, journalEntryId).
 */
@Entity
@Table(name = "fee_charges")
public class FeeCharge extends io.bankplatform.common.ddd.Entity<Long> {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "account_id", nullable = false)
    private Long accountId;

    @Column(name = "fee_code", nullable = false, length = 30)
    private String feeCode;

    @Column(name = "source_type", length = 30)
    private String sourceType;

    @Column(name = "source_id", length = 100)
    private String sourceId;

    @Column(name = "amount", nullable = false, precision = 19, scale = 4)
    private BigDecimal amount;

    @JdbcTypeCode(SqlTypes.CHAR)
    @Column(name = "currency", nullable = false, length = 3)
    private String currency = "VND";

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private FeeChargeStatus status = FeeChargeStatus.PENDING;

    @Column(name = "journal_entry_id")
    private Long journalEntryId;

    @Generated(event = EventType.INSERT)
    @Column(name = "charged_at", insertable = false, updatable = false)
    private OffsetDateTime chargedAt;

    protected FeeCharge() {
    }

    public FeeCharge(Long accountId, String feeCode, String sourceType, String sourceId,
                     BigDecimal amount, String currency, FeeChargeStatus status) {
        this.accountId = accountId;
        this.feeCode = feeCode;
        this.sourceType = sourceType;
        this.sourceId = sourceId;
        this.amount = amount;
        this.currency = currency != null ? currency : "VND";
        this.status = status != null ? status : FeeChargeStatus.PENDING;
    }

    @Override
    public Long getId() {
        return id;
    }

    public Long getAccountId() {
        return accountId;
    }

    public String getFeeCode() {
        return feeCode;
    }

    public String getSourceType() {
        return sourceType;
    }

    public String getSourceId() {
        return sourceId;
    }

    public BigDecimal getAmount() {
        return amount;
    }

    public String getCurrency() {
        return currency;
    }

    public FeeChargeStatus getStatus() {
        return status;
    }

    public void setStatus(FeeChargeStatus status) {
        this.status = status;
    }

    public Long getJournalEntryId() {
        return journalEntryId;
    }

    public void setJournalEntryId(Long journalEntryId) {
        this.journalEntryId = journalEntryId;
    }

    public OffsetDateTime getChargedAt() {
        return chargedAt;
    }
}
