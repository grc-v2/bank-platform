package io.bankplatform.corebanking.domain.ledger.model;

import jakarta.persistence.Column;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import org.hibernate.annotations.Generated;
import org.hibernate.generator.EventType;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;

/**
 * Entity bảng account_balance_snapshots (schema core_banking). Append-only.
 */
@Entity
@Table(name = "account_balance_snapshots")
public class AccountBalanceSnapshot extends io.javalibs.ddd.Entity<AccountBalanceSnapshotId> {

    @EmbeddedId
    private AccountBalanceSnapshotId id;

    @Column(name = "opening_balance", nullable = false, precision = 19, scale = 4)
    private BigDecimal openingBalance;

    @Column(name = "closing_balance", nullable = false, precision = 19, scale = 4)
    private BigDecimal closingBalance;

    @Column(name = "total_debit", nullable = false, precision = 19, scale = 4)
    private BigDecimal totalDebit = BigDecimal.ZERO;

    @Column(name = "total_credit", nullable = false, precision = 19, scale = 4)
    private BigDecimal totalCredit = BigDecimal.ZERO;

    @Generated(event = EventType.INSERT)
    @Column(name = "created_at", insertable = false, updatable = false)
    private OffsetDateTime createdAt;

    protected AccountBalanceSnapshot() {
    }

    public AccountBalanceSnapshot(Long accountId, LocalDate asOfDate, BigDecimal openingBalance,
                                  BigDecimal closingBalance, BigDecimal totalDebit, BigDecimal totalCredit) {
        this.id = new AccountBalanceSnapshotId(accountId, asOfDate);
        this.openingBalance = openingBalance;
        this.closingBalance = closingBalance;
        this.totalDebit = totalDebit != null ? totalDebit : BigDecimal.ZERO;
        this.totalCredit = totalCredit != null ? totalCredit : BigDecimal.ZERO;
    }

    @Override
    public AccountBalanceSnapshotId getId() {
        return id;
    }

    public BigDecimal getOpeningBalance() {
        return openingBalance;
    }

    public BigDecimal getClosingBalance() {
        return closingBalance;
    }

    public BigDecimal getTotalDebit() {
        return totalDebit;
    }

    public BigDecimal getTotalCredit() {
        return totalCredit;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }
}
