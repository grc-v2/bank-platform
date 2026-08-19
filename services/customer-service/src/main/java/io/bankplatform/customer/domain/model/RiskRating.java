package io.bankplatform.customer.domain.model;

/**
 * Mức độ rủi ro khách hàng, khớp CHECK constraint ck_customers_risk / ck_risk_rating trong schema.sql.
 */
public enum RiskRating {
    LOW,
    MEDIUM,
    HIGH
}
