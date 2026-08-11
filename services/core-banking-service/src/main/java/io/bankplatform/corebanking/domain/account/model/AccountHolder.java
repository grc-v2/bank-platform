package io.bankplatform.corebanking.domain.account.model;

import io.javalibs.ddd.Entity;
import jakarta.persistence.*;
import org.hibernate.annotations.Generated;
import org.hibernate.generator.EventType;

import java.time.OffsetDateTime;

/**
 * Entity bảng account_holders (schema core_banking).
 */
@jakarta.persistence.Entity
@Table(name = "account_holders")
public class AccountHolder extends Entity<AccountHolderId> {

    @EmbeddedId
    private AccountHolderId id;

    @MapsId("accountId")
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "account_id")
    private Account account;

    @Enumerated(EnumType.STRING)
    @Column(name = "holder_role", nullable = false, length = 30)
    private HolderRole holderRole;

    @Generated(event = EventType.INSERT)
    @Column(name = "added_at", insertable = false, updatable = false)
    private OffsetDateTime addedAt;

    protected AccountHolder() {
    }

    public AccountHolder(Account account, Long customerId, HolderRole holderRole) {
        this.account = account;
        this.id = new AccountHolderId(account != null ? account.getId() : null, customerId);
        this.holderRole = holderRole;
    }

    @Override
    public AccountHolderId getId() {
        return id;
    }

    public Account getAccount() {
        return account;
    }

    public void setAccount(Account account) {
        this.account = account;
        if (account != null && id != null) {
            id.setAccountId(account.getId());
        }
    }

    public Long getCustomerId() {
        return id != null ? id.getCustomerId() : null;
    }

    public HolderRole getHolderRole() {
        return holderRole;
    }

    public void setHolderRole(HolderRole holderRole) {
        this.holderRole = holderRole;
    }

    public OffsetDateTime getAddedAt() {
        return addedAt;
    }
}
