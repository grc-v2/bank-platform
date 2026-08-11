package io.bankplatform.corebanking.domain.ledger.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import org.hibernate.annotations.Generated;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.generator.EventType;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

/**
 * Entity chi tiết dòng hạch toán trong bút toán (schema core_banking).
 * L3: `@Id` chỉ trên `id`, không map composite PK (id, created_at).
 * Append-only tuyệt đối: không có setter ngoài setter liên kết parent.
 */
@Entity
@Table(name = "journal_lines")
public class JournalLine extends io.javalibs.ddd.Entity<Long> {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "journal_entry_id", nullable = false)
    private JournalEntry journalEntry;

    @Column(name = "line_no", nullable = false)
    private int lineNo;

    @Column(name = "account_id")
    private Long accountId;

    @Column(name = "gl_code", nullable = false, length = 20)
    private String glCode;

    @Enumerated(EnumType.STRING)
    @Column(name = "direction", nullable = false, length = 6)
    private LedgerDirection direction;

    @Column(name = "amount", nullable = false, precision = 19, scale = 4)
    private BigDecimal amount;

    @JdbcTypeCode(SqlTypes.CHAR)
    @Column(name = "currency", nullable = false, length = 3)
    private String currency = "VND";

    @Column(name = "balance_after", precision = 19, scale = 4)
    private BigDecimal balanceAfter;

    @Generated(event = EventType.INSERT)
    @Column(name = "created_at", insertable = false, updatable = false)
    private OffsetDateTime createdAt;

    protected JournalLine() {
    }

    public JournalLine(int lineNo, Long accountId, String glCode, LedgerDirection direction,
                       BigDecimal amount, String currency, BigDecimal balanceAfter) {
        this.lineNo = lineNo;
        this.accountId = accountId;
        this.glCode = glCode;
        this.direction = direction;
        this.amount = amount;
        this.currency = currency != null ? currency : "VND";
        this.balanceAfter = balanceAfter;
    }

    @Override
    public Long getId() {
        return id;
    }

    public JournalEntry getJournalEntry() {
        return journalEntry;
    }

    public void setJournalEntry(JournalEntry journalEntry) {
        this.journalEntry = journalEntry;
    }

    public int getLineNo() {
        return lineNo;
    }

    public Long getAccountId() {
        return accountId;
    }

    public String getGlCode() {
        return glCode;
    }

    public LedgerDirection getDirection() {
        return direction;
    }

    public BigDecimal getAmount() {
        return amount;
    }

    public String getCurrency() {
        return currency;
    }

    public BigDecimal getBalanceAfter() {
        return balanceAfter;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }
}
