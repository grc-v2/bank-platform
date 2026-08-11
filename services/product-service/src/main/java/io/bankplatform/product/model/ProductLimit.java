package io.bankplatform.product.model;

import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Entity bảng product_limits (schema product).
 * Cấu hình khuôn hạn mức giao dịch theo sản phẩm.
 */
@Entity
@Table(name = "product_limits")
public class ProductLimit {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "product_id", nullable = false)
    private Long productId;

    @Column(name = "limit_code", nullable = false, length = 30)
    private String limitCode;

    @Enumerated(EnumType.STRING)
    @Column(name = "scope", nullable = false, length = 20)
    private LimitScope scope;

    @Enumerated(EnumType.STRING)
    @Column(name = "channel", nullable = false, length = 20)
    private LimitChannel channel = LimitChannel.ANY;

    @Column(name = "max_amount", precision = 19, scale = 4)
    private BigDecimal maxAmount;

    @Column(name = "max_count")
    private Integer maxCount;

    @JdbcTypeCode(SqlTypes.CHAR)
    @Column(name = "currency", nullable = false, length = 3)
    private String currency = "VND";

    @Column(name = "effective_from", nullable = false)
    private LocalDate effectiveFrom;

    @Column(name = "effective_to")
    private LocalDate effectiveTo;

    protected ProductLimit() {
    }

    public ProductLimit(Long productId, String limitCode, LimitScope scope, LimitChannel channel,
                        BigDecimal maxAmount, Integer maxCount, String currency,
                        LocalDate effectiveFrom, LocalDate effectiveTo) {
        this.productId = productId;
        this.limitCode = limitCode;
        this.scope = scope;
        this.channel = channel != null ? channel : LimitChannel.ANY;
        this.maxAmount = maxAmount;
        this.maxCount = maxCount;
        this.currency = currency != null ? currency : "VND";
        this.effectiveFrom = effectiveFrom != null ? effectiveFrom : LocalDate.now();
        this.effectiveTo = effectiveTo;
    }

    public Long getId() {
        return id;
    }

    public Long getProductId() {
        return productId;
    }

    public String getLimitCode() {
        return limitCode;
    }

    public LimitScope getScope() {
        return scope;
    }

    public LimitChannel getChannel() {
        return channel;
    }

    public BigDecimal getMaxAmount() {
        return maxAmount;
    }

    public Integer getMaxCount() {
        return maxCount;
    }

    public String getCurrency() {
        return currency;
    }

    public LocalDate getEffectiveFrom() {
        return effectiveFrom;
    }

    public LocalDate getEffectiveTo() {
        return effectiveTo;
    }

    public void setLimitCode(String limitCode) {
        this.limitCode = limitCode;
    }

    public void setScope(LimitScope scope) {
        this.scope = scope;
    }

    public void setChannel(LimitChannel channel) {
        this.channel = channel;
    }

    public void setMaxAmount(BigDecimal maxAmount) {
        this.maxAmount = maxAmount;
    }

    public void setMaxCount(Integer maxCount) {
        this.maxCount = maxCount;
    }

    public void setEffectiveFrom(LocalDate effectiveFrom) {
        this.effectiveFrom = effectiveFrom;
    }

    public void setEffectiveTo(LocalDate effectiveTo) {
        this.effectiveTo = effectiveTo;
    }
}
