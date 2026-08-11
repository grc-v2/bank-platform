package io.bankplatform.corebanking.domain.account.model;

import io.javalibs.ddd.AggregateRoot;
import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.OneToMany;
import jakarta.persistence.Table;
import jakarta.persistence.Version;
import org.hibernate.annotations.Generated;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.generator.EventType;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.HashSet;
import java.util.Set;

/**
 * Aggregate Root đại diện cho tài khoản tiền gửi của khách hàng (schema core_banking).
 */
@Entity
@Table(name = "accounts")
public class Account extends AggregateRoot<Long> {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "account_number", nullable = false, unique = true, length = 20)
    private String accountNumber;

    @Column(name = "product_code", nullable = false, length = 30)
    private String productCode;

    @Column(name = "primary_customer_id", nullable = false)
    private Long primaryCustomerId;

    @JdbcTypeCode(SqlTypes.CHAR)
    @Column(name = "currency", nullable = false, length = 3)
    private String currency = "VND";

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private AccountStatus status = AccountStatus.PENDING;

    @Column(name = "gl_code", nullable = false, length = 20)
    private String glCode;

    @Column(name = "ledger_balance", nullable = false, precision = 19, scale = 4)
    private BigDecimal ledgerBalance = BigDecimal.ZERO;

    @Column(name = "hold_amount", nullable = false, precision = 19, scale = 4)
    private BigDecimal holdAmount = BigDecimal.ZERO;

    @Generated(event = {EventType.INSERT, EventType.UPDATE})
    @Column(name = "available_balance", insertable = false, updatable = false, precision = 19, scale = 4)
    private BigDecimal availableBalance;

    @Column(name = "overdraft_limit", nullable = false, precision = 19, scale = 4)
    private BigDecimal overdraftLimit = BigDecimal.ZERO;

    @Version
    @Column(name = "version", nullable = false)
    private int version;

    @Column(name = "opened_at")
    private OffsetDateTime openedAt;

    @Column(name = "closed_at")
    private OffsetDateTime closedAt;

    @Generated(event = EventType.INSERT)
    @Column(name = "created_at", insertable = false, updatable = false)
    private OffsetDateTime createdAt;

    @Generated(event = {EventType.INSERT, EventType.UPDATE})
    @Column(name = "updated_at", insertable = false, updatable = false)
    private OffsetDateTime updatedAt;

    @OneToMany(mappedBy = "account", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    private Set<AccountHolder> holders = new HashSet<>();

    protected Account() {
    }

    public Account(String accountNumber, String productCode, Long primaryCustomerId,
                   String currency, String glCode, BigDecimal ledgerBalance, BigDecimal holdAmount, BigDecimal overdraftLimit) {
        this.accountNumber = accountNumber;
        this.productCode = productCode;
        this.primaryCustomerId = primaryCustomerId;
        this.currency = currency != null ? currency : "VND";
        this.glCode = glCode;
        this.ledgerBalance = ledgerBalance != null ? ledgerBalance : BigDecimal.ZERO;
        this.holdAmount = holdAmount != null ? holdAmount : BigDecimal.ZERO;
        this.overdraftLimit = overdraftLimit != null ? overdraftLimit : BigDecimal.ZERO;
        this.status = AccountStatus.PENDING;
    }

    @Override
    public Long getId() {
        return id;
    }

    public String getAccountNumber() {
        return accountNumber;
    }

    public String getProductCode() {
        return productCode;
    }

    public Long getPrimaryCustomerId() {
        return primaryCustomerId;
    }

    public String getCurrency() {
        return currency;
    }

    public AccountStatus getStatus() {
        return status;
    }

    public void setStatus(AccountStatus status) {
        this.status = status;
    }

    public String getGlCode() {
        return glCode;
    }

    public void setGlCode(String glCode) {
        this.glCode = glCode;
    }

    public BigDecimal getLedgerBalance() {
        return ledgerBalance;
    }

    public void setLedgerBalance(BigDecimal ledgerBalance) {
        this.ledgerBalance = ledgerBalance;
    }

    public BigDecimal getHoldAmount() {
        return holdAmount;
    }

    public void setHoldAmount(BigDecimal holdAmount) {
        this.holdAmount = holdAmount;
    }

    public BigDecimal getAvailableBalance() {
        return availableBalance;
    }

    public BigDecimal getOverdraftLimit() {
        return overdraftLimit;
    }

    public void setOverdraftLimit(BigDecimal overdraftLimit) {
        this.overdraftLimit = overdraftLimit;
    }

    public int getVersion() {
        return version;
    }

    public OffsetDateTime getOpenedAt() {
        return openedAt;
    }

    public void setOpenedAt(OffsetDateTime openedAt) {
        this.openedAt = openedAt;
    }

    public OffsetDateTime getClosedAt() {
        return closedAt;
    }

    public void setClosedAt(OffsetDateTime closedAt) {
        this.closedAt = closedAt;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }

    public OffsetDateTime getUpdatedAt() {
        return updatedAt;
    }

    public Set<AccountHolder> getHolders() {
        return holders;
    }

    public void addHolder(Long customerId, HolderRole role) {
        AccountHolder holder = new AccountHolder(this, customerId, role);
        holders.add(holder);
    }
}
