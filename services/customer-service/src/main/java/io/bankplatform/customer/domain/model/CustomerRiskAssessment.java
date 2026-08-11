package io.bankplatform.customer.domain.model;

import io.javalibs.ddd.Entity;
import jakarta.persistence.*;
import org.hibernate.annotations.Generated;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.generator.EventType;
import org.hibernate.type.SqlTypes;

import java.time.OffsetDateTime;

/**
 * Entity bảng customer_risk_assessments (schema customer). Append-only.
 */
@jakarta.persistence.Entity
@Table(name = "customer_risk_assessments")
public class CustomerRiskAssessment extends Entity<Long> {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "customer_id", nullable = false)
    private Long customerId;

    @Enumerated(EnumType.STRING)
    @Column(name = "rating", nullable = false, length = 10)
    private RiskRating rating;

    @Column(name = "score", nullable = false)
    private int score;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "reason")
    private String reason;

    @Column(name = "assessed_by")
    private Long assessedBy;

    @Generated(event = EventType.INSERT)
    @Column(name = "assessed_at", insertable = false, updatable = false)
    private OffsetDateTime assessedAt;

    protected CustomerRiskAssessment() {
    }

    public CustomerRiskAssessment(Long customerId, RiskRating rating, int score, String reason, Long assessedBy) {
        this.customerId = customerId;
        this.rating = rating;
        this.score = score;
        this.reason = reason;
        this.assessedBy = assessedBy;
    }

    @Override
    public Long getId() {
        return id;
    }

    public Long getCustomerId() {
        return customerId;
    }

    public RiskRating getRating() {
        return rating;
    }

    public int getScore() {
        return score;
    }

    public String getReason() {
        return reason;
    }

    public Long getAssessedBy() {
        return assessedBy;
    }

    public OffsetDateTime getAssessedAt() {
        return assessedAt;
    }
}
