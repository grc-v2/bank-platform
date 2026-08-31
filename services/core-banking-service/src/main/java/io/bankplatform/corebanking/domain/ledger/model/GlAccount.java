package io.bankplatform.corebanking.domain.ledger.model;

import io.bankplatform.common.ddd.AggregateRoot;
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

import java.time.OffsetDateTime;

/**
 * Aggregate Root đại diện cho tài khoản sổ cái GL của ngân hàng (schema core_banking).
 */
@Entity
@Table(name = "gl_accounts")
public class GlAccount extends AggregateRoot<Long> {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "gl_code", nullable = false, unique = true, length = 20)
    private String glCode;

    @Column(name = "name", nullable = false, length = 200)
    private String name;

    @Enumerated(EnumType.STRING)
    @Column(name = "account_class", nullable = false, length = 20)
    private GlAccountClass accountClass;

    @Enumerated(EnumType.STRING)
    @Column(name = "normal_balance", nullable = false, length = 6)
    private NormalBalance normalBalance;

    @Column(name = "parent_gl_code", length = 20)
    private String parentGlCode;

    @Column(name = "is_postable", nullable = false)
    private boolean isPostable = true;

    @JdbcTypeCode(SqlTypes.CHAR)
    @Column(name = "currency", nullable = false, length = 3)
    private String currency = "VND";

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private GlAccountStatus status = GlAccountStatus.ACTIVE;

    @Generated(event = EventType.INSERT)
    @Column(name = "created_at", insertable = false, updatable = false)
    private OffsetDateTime createdAt;

    protected GlAccount() {
    }

    public GlAccount(String glCode, String name, GlAccountClass accountClass, NormalBalance normalBalance,
                     String parentGlCode, boolean isPostable, String currency, GlAccountStatus status) {
        this.glCode = glCode;
        this.name = name;
        this.accountClass = accountClass;
        this.normalBalance = normalBalance;
        this.parentGlCode = parentGlCode;
        this.isPostable = isPostable;
        this.currency = currency != null ? currency : "VND";
        this.status = status != null ? status : GlAccountStatus.ACTIVE;
    }

    @Override
    public Long getId() {
        return id;
    }

    public String getGlCode() {
        return glCode;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public GlAccountClass getAccountClass() {
        return accountClass;
    }

    public NormalBalance getNormalBalance() {
        return normalBalance;
    }

    public String getParentGlCode() {
        return parentGlCode;
    }

    public void setParentGlCode(String parentGlCode) {
        this.parentGlCode = parentGlCode;
    }

    public boolean isPostable() {
        return isPostable;
    }

    public void setPostable(boolean postable) {
        isPostable = postable;
    }

    public String getCurrency() {
        return currency;
    }

    public GlAccountStatus getStatus() {
        return status;
    }

    public void setStatus(GlAccountStatus status) {
        this.status = status;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }
}
