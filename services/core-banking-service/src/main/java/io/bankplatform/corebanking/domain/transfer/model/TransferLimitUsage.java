package io.bankplatform.corebanking.domain.transfer.model;

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
 * Entity theo dõi mức sử dụng hạn mức chuyển tiền của tài khoản (schema core_banking).
 */
@Entity
@Table(name = "transfer_limit_usage")
public class TransferLimitUsage extends io.bankplatform.common.ddd.Entity<Long> {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "account_id", nullable = false)
    private Long accountId;

    @Column(name = "limit_code", nullable = false, length = 30)
    private String limitCode;

    @Column(name = "window_start", nullable = false)
    private LocalDate windowStart;

    @Column(name = "used_amount", nullable = false, precision = 19, scale = 4)
    private BigDecimal usedAmount = BigDecimal.ZERO;

    @Column(name = "used_count", nullable = false)
    private int usedCount = 0;

    @Generated(event = {EventType.INSERT, EventType.UPDATE})
    @Column(name = "updated_at", insertable = false, updatable = false)
    private OffsetDateTime updatedAt;

    protected TransferLimitUsage() {
    }

    public TransferLimitUsage(Long accountId, String limitCode, LocalDate windowStart,
                              BigDecimal usedAmount, int usedCount) {
        this.accountId = accountId;
        this.limitCode = limitCode;
        this.windowStart = windowStart;
        this.usedAmount = usedAmount != null ? usedAmount : BigDecimal.ZERO;
        this.usedCount = usedCount;
    }

    @Override
    public Long getId() {
        return id;
    }

    public Long getAccountId() {
        return accountId;
    }

    public String getLimitCode() {
        return limitCode;
    }

    public LocalDate getWindowStart() {
        return windowStart;
    }

    public BigDecimal getUsedAmount() {
        return usedAmount;
    }

    public void setUsedAmount(BigDecimal usedAmount) {
        this.usedAmount = usedAmount;
    }

    public int getUsedCount() {
        return usedCount;
    }

    public void setUsedCount(int usedCount) {
        this.usedCount = usedCount;
    }

    public OffsetDateTime getUpdatedAt() {
        return updatedAt;
    }
}
