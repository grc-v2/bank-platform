package io.bankplatform.product.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.LocalDate;

/**
 * Entity bảng product_gl_mappings (schema product).
 * Cầu hình ánh xạ sản phẩm với tài khoản kế toán General Ledger.
 */
@Entity
@Table(name = "product_gl_mappings")
public class ProductGlMapping {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "product_id", nullable = false)
    private Long productId;

    @Enumerated(EnumType.STRING)
    @Column(name = "purpose", nullable = false, length = 30)
    private GlMappingPurpose purpose;

    @Column(name = "gl_code", nullable = false, length = 20)
    private String glCode;

    @Column(name = "effective_from", nullable = false)
    private LocalDate effectiveFrom;

    @Column(name = "effective_to")
    private LocalDate effectiveTo;

    protected ProductGlMapping() {
    }

    public ProductGlMapping(Long productId, GlMappingPurpose purpose, String glCode,
                            LocalDate effectiveFrom, LocalDate effectiveTo) {
        this.productId = productId;
        this.purpose = purpose;
        this.glCode = glCode;
        this.effectiveFrom = effectiveFrom != null ? effectiveFrom : LocalDate.now();
        this.effectiveTo = effectiveTo;
    }

    public Long getId() {
        return id;
    }

    public Long getProductId() {
        return productId;
    }

    public GlMappingPurpose getPurpose() {
        return purpose;
    }

    public String getGlCode() {
        return glCode;
    }

    public LocalDate getEffectiveFrom() {
        return effectiveFrom;
    }

    public LocalDate getEffectiveTo() {
        return effectiveTo;
    }

    public void setPurpose(GlMappingPurpose purpose) {
        this.purpose = purpose;
    }

    public void setGlCode(String glCode) {
        this.glCode = glCode;
    }

    public void setEffectiveFrom(LocalDate effectiveFrom) {
        this.effectiveFrom = effectiveFrom;
    }

    public void setEffectiveTo(LocalDate effectiveTo) {
        this.effectiveTo = effectiveTo;
    }
}
