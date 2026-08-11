package io.bankplatform.corebanking.domain.account.model;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;

import java.io.Serializable;
import java.util.Objects;

/**
 * Composite Primary Key cho bảng account_holders.
 */
@Embeddable
public class AccountHolderId implements Serializable {

    @Column(name = "account_id")
    private Long accountId;

    @Column(name = "customer_id")
    private Long customerId;

    public AccountHolderId() {
    }

    public AccountHolderId(Long accountId, Long customerId) {
        this.accountId = accountId;
        this.customerId = customerId;
    }

    public Long getAccountId() {
        return accountId;
    }

    public void setAccountId(Long accountId) {
        this.accountId = accountId;
    }

    public Long getCustomerId() {
        return customerId;
    }

    public void setCustomerId(Long customerId) {
        this.customerId = customerId;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        AccountHolderId that = (AccountHolderId) o;
        return Objects.equals(accountId, that.accountId) && Objects.equals(customerId, that.customerId);
    }

    @Override
    public int hashCode() {
        return Objects.hash(accountId, customerId);
    }
}
