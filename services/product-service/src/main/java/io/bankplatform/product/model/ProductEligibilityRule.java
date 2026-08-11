package io.bankplatform.product.model;

import jakarta.persistence.*;

/**
 * Entity bảng product_eligibility_rules (schema product).
 * Điều kiện để khách hàng được mở/đăng ký sản phẩm.
 */
@Entity
@Table(name = "product_eligibility_rules")
public class ProductEligibilityRule {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "product_id", nullable = false)
    private Long productId;

    @Enumerated(EnumType.STRING)
    @Column(name = "rule_type", nullable = false, length = 30)
    private EligibilityRuleType ruleType;

    @Enumerated(EnumType.STRING)
    @Column(name = "operator", nullable = false, length = 10)
    private RuleOperator operator;

    @Column(name = "rule_value", nullable = false, length = 100)
    private String ruleValue;

    protected ProductEligibilityRule() {
    }

    public ProductEligibilityRule(Long productId, EligibilityRuleType ruleType, RuleOperator operator, String ruleValue) {
        this.productId = productId;
        this.ruleType = ruleType;
        this.operator = operator;
        this.ruleValue = ruleValue;
    }

    public Long getId() {
        return id;
    }

    public Long getProductId() {
        return productId;
    }

    public EligibilityRuleType getRuleType() {
        return ruleType;
    }

    public RuleOperator getOperator() {
        return operator;
    }

    public String getRuleValue() {
        return ruleValue;
    }

    public void setRuleType(EligibilityRuleType ruleType) {
        this.ruleType = ruleType;
    }

    public void setOperator(RuleOperator operator) {
        this.operator = operator;
    }

    public void setRuleValue(String ruleValue) {
        this.ruleValue = ruleValue;
    }
}
