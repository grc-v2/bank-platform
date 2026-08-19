package io.bankplatform.product.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Entity bảng product_interest_rates (schema product).
 * Cấu hình lãi suất bậc thang theo số dư hoặc kỳ hạn.
 */
@Entity
@Table(name = "product_interest_rates")
public class ProductInterestRate {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "product_id", nullable = false)
    private Long productId;

    @Column(name = "tier_from", nullable = false, precision = 19, scale = 4)
    private BigDecimal tierFrom = BigDecimal.ZERO;

    @Column(name = "tier_to", precision = 19, scale = 4)
    private BigDecimal tierTo;

    @Column(name = "term_months")
    private Integer termMonths;

    @Column(name = "annual_rate", nullable = false, precision = 9, scale = 6)
    private BigDecimal annualRate;

    @Column(name = "effective_from", nullable = false)
    private LocalDate effectiveFrom;

    @Column(name = "effective_to")
    private LocalDate effectiveTo;

    protected ProductInterestRate() {
    }

    public ProductInterestRate(Long productId, BigDecimal tierFrom, BigDecimal tierTo, Integer termMonths,
                               BigDecimal annualRate, LocalDate effectiveFrom, LocalDate effectiveTo) {
        this.productId = productId;
        this.tierFrom = tierFrom != null ? tierFrom : BigDecimal.ZERO;
        this.tierTo = tierTo;
        this.termMonths = termMonths;
        this.annualRate = annualRate;
        this.effectiveFrom = effectiveFrom != null ? effectiveFrom : LocalDate.now();
        this.effectiveTo = effectiveTo;
    }

    public Long getId() {
        return id;
    }

    public Long getProductId() {
        return productId;
    }

    public BigDecimal getTierFrom() {
        return tierFrom;
    }

    public BigDecimal getTierTo() {
        return tierTo;
    }

    public Integer getTermMonths() {
        return termMonths;
    }

    public BigDecimal getAnnualRate() {
        return annualRate;
    }

    public LocalDate getEffectiveFrom() {
        return effectiveFrom;
    }

    public LocalDate getEffectiveTo() {
        return effectiveTo;
    }

    public void setEffectiveTo(LocalDate effectiveTo) {
        this.effectiveTo = effectiveTo;
    }
}
