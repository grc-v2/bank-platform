package io.bankplatform.product.model;

import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Entity bảng product_fees (schema product).
 * Cấu hình biểu phí giao dịch và duy trì tài khoản.
 */
@Entity
@Table(name = "product_fees")
public class ProductFee {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "product_id", nullable = false)
    private Long productId;

    @Column(name = "fee_code", nullable = false, length = 30)
    private String feeCode;

    @Enumerated(EnumType.STRING)
    @Column(name = "fee_type", nullable = false, length = 20)
    private FeeType feeType;

    @Column(name = "amount", precision = 19, scale = 4)
    private BigDecimal amount;

    @Column(name = "percent", precision = 9, scale = 6)
    private BigDecimal percent;

    @Column(name = "min_amount", precision = 19, scale = 4)
    private BigDecimal minAmount;

    @Column(name = "max_amount", precision = 19, scale = 4)
    private BigDecimal maxAmount;

    @Enumerated(EnumType.STRING)
    @Column(name = "charge_event", nullable = false, length = 40)
    private ChargeEvent chargeEvent;

    @JdbcTypeCode(SqlTypes.CHAR)
    @Column(name = "currency", nullable = false, length = 3)
    private String currency = "VND";

    @Column(name = "effective_from", nullable = false)
    private LocalDate effectiveFrom;

    @Column(name = "effective_to")
    private LocalDate effectiveTo;

    protected ProductFee() {
    }

    public ProductFee(Long productId, String feeCode, FeeType feeType, BigDecimal amount, BigDecimal percent,
                      BigDecimal minAmount, BigDecimal maxAmount, ChargeEvent chargeEvent, String currency,
                      LocalDate effectiveFrom, LocalDate effectiveTo) {
        this.productId = productId;
        this.feeCode = feeCode;
        this.feeType = feeType;
        this.amount = amount;
        this.percent = percent;
        this.minAmount = minAmount;
        this.maxAmount = maxAmount;
        this.chargeEvent = chargeEvent;
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

    public String getFeeCode() {
        return feeCode;
    }

    public FeeType getFeeType() {
        return feeType;
    }

    public BigDecimal getAmount() {
        return amount;
    }

    public BigDecimal getPercent() {
        return percent;
    }

    public BigDecimal getMinAmount() {
        return minAmount;
    }

    public BigDecimal getMaxAmount() {
        return maxAmount;
    }

    public ChargeEvent getChargeEvent() {
        return chargeEvent;
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

    public void setFeeCode(String feeCode) {
        this.feeCode = feeCode;
    }

    public void setFeeType(FeeType feeType) {
        this.feeType = feeType;
    }

    public void setAmount(BigDecimal amount) {
        this.amount = amount;
    }

    public void setPercent(BigDecimal percent) {
        this.percent = percent;
    }

    public void setMinAmount(BigDecimal minAmount) {
        this.minAmount = minAmount;
    }

    public void setMaxAmount(BigDecimal maxAmount) {
        this.maxAmount = maxAmount;
    }

    public void setChargeEvent(ChargeEvent chargeEvent) {
        this.chargeEvent = chargeEvent;
    }

    public void setEffectiveFrom(LocalDate effectiveFrom) {
        this.effectiveFrom = effectiveFrom;
    }

    public void setEffectiveTo(LocalDate effectiveTo) {
        this.effectiveTo = effectiveTo;
    }
}
