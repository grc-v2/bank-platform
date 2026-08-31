package io.bankplatform.corebanking.domain.ledger.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import org.hibernate.annotations.Generated;
import org.hibernate.generator.EventType;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;

/**
 * Entity dự thu lãi hàng ngày (schema core_banking).
 * Setters chỉ dành cho trạng thái hạch toán (posted, journalEntryId).
 */
@Entity
@Table(name = "interest_accruals")
public class InterestAccrual extends io.bankplatform.common.ddd.Entity<Long> {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "account_id", nullable = false)
    private Long accountId;

    @Column(name = "accrual_date", nullable = false)
    private LocalDate accrualDate;

    @Column(name = "principal_base", nullable = false, precision = 19, scale = 4)
    private BigDecimal principalBase;

    @Column(name = "annual_rate", nullable = false, precision = 9, scale = 6)
    private BigDecimal annualRate;

    @Column(name = "accrued_amount", nullable = false, precision = 19, scale = 4)
    private BigDecimal accruedAmount;

    @Column(name = "posted", nullable = false)
    private boolean posted = false;

    @Column(name = "journal_entry_id")
    private Long journalEntryId;

    @Generated(event = EventType.INSERT)
    @Column(name = "created_at", insertable = false, updatable = false)
    private OffsetDateTime createdAt;

    protected InterestAccrual() {
    }

    public InterestAccrual(Long accountId, LocalDate accrualDate, BigDecimal principalBase,
                           BigDecimal annualRate, BigDecimal accruedAmount) {
        this.accountId = accountId;
        this.accrualDate = accrualDate;
        this.principalBase = principalBase;
        this.annualRate = annualRate;
        this.accruedAmount = accruedAmount;
        this.posted = false;
    }

    @Override
    public Long getId() {
        return id;
    }

    public Long getAccountId() {
        return accountId;
    }

    public LocalDate getAccrualDate() {
        return accrualDate;
    }

    public BigDecimal getPrincipalBase() {
        return principalBase;
    }

    public BigDecimal getAnnualRate() {
        return annualRate;
    }

    public BigDecimal getAccruedAmount() {
        return accruedAmount;
    }

    public boolean isPosted() {
        return posted;
    }

    public void setPosted(boolean posted) {
        this.posted = posted;
    }

    public Long getJournalEntryId() {
        return journalEntryId;
    }

    public void setJournalEntryId(Long journalEntryId) {
        this.journalEntryId = journalEntryId;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }
}
