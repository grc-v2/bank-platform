package io.bankplatform.corebanking.domain.ledger.model;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;

import java.io.Serializable;
import java.time.LocalDate;
import java.util.Objects;

/**
 * Composite Primary Key cho bảng account_balance_snapshots.
 */
@Embeddable
public class AccountBalanceSnapshotId implements Serializable {

    @Column(name = "account_id")
    private Long accountId;

    @Column(name = "as_of_date")
    private LocalDate asOfDate;

    public AccountBalanceSnapshotId() {
    }

    public AccountBalanceSnapshotId(Long accountId, LocalDate asOfDate) {
        this.accountId = accountId;
        this.asOfDate = asOfDate;
    }

    public Long getAccountId() {
        return accountId;
    }

    public void setAccountId(Long accountId) {
        this.accountId = accountId;
    }

    public LocalDate getAsOfDate() {
        return asOfDate;
    }

    public void setAsOfDate(LocalDate asOfDate) {
        this.asOfDate = asOfDate;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        AccountBalanceSnapshotId that = (AccountBalanceSnapshotId) o;
        return Objects.equals(accountId, that.accountId) && Objects.equals(asOfDate, that.asOfDate);
    }

    @Override
    public int hashCode() {
        return Objects.hash(accountId, asOfDate);
    }
}
