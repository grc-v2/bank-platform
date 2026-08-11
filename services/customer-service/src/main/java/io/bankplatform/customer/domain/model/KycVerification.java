package io.bankplatform.customer.domain.model;

import io.javalibs.ddd.AggregateRoot;
import jakarta.persistence.*;
import org.hibernate.annotations.Generated;
import org.hibernate.generator.EventType;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;

/**
 * Aggregate Root đại diện cho hồ sơ xác minh KYC của khách hàng (schema customer).
 */
@Entity
@Table(name = "kyc_verifications")
public class KycVerification extends AggregateRoot<Long> {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "customer_id", nullable = false)
    private Long customerId;

    @Column(name = "level", nullable = false)
    private short level;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private KycStatus status = KycStatus.PENDING;

    @Enumerated(EnumType.STRING)
    @Column(name = "method", nullable = false, length = 20)
    private KycMethod method;

    @Generated(event = EventType.INSERT)
    @Column(name = "submitted_at", insertable = false, updatable = false)
    private OffsetDateTime submittedAt;

    @Column(name = "decided_at")
    private OffsetDateTime decidedAt;

    @Column(name = "decided_by")
    private Long decidedBy;

    @Column(name = "reject_reason", length = 500)
    private String rejectReason;

    @Column(name = "expires_at")
    private OffsetDateTime expiresAt;

    @OneToMany(mappedBy = "kycVerification", cascade = CascadeType.PERSIST, fetch = FetchType.LAZY)
    private List<KycDocument> documents = new ArrayList<>();

    protected KycVerification() {
    }

    public KycVerification(Long customerId, short level, KycStatus status, KycMethod method) {
        this.customerId = customerId;
        this.level = level;
        this.status = status != null ? status : KycStatus.PENDING;
        this.method = method;
    }

    @Override
    public Long getId() {
        return id;
    }

    public Long getCustomerId() {
        return customerId;
    }

    public short getLevel() {
        return level;
    }

    public KycStatus getStatus() {
        return status;
    }

    public void setStatus(KycStatus status) {
        this.status = status;
    }

    public KycMethod getMethod() {
        return method;
    }

    public OffsetDateTime getSubmittedAt() {
        return submittedAt;
    }

    public OffsetDateTime getDecidedAt() {
        return decidedAt;
    }

    public void setDecidedAt(OffsetDateTime decidedAt) {
        this.decidedAt = decidedAt;
    }

    public Long getDecidedBy() {
        return decidedBy;
    }

    public void setDecidedBy(Long decidedBy) {
        this.decidedBy = decidedBy;
    }

    public String getRejectReason() {
        return rejectReason;
    }

    public void setRejectReason(String rejectReason) {
        this.rejectReason = rejectReason;
    }

    public OffsetDateTime getExpiresAt() {
        return expiresAt;
    }

    public void setExpiresAt(OffsetDateTime expiresAt) {
        this.expiresAt = expiresAt;
    }

    public List<KycDocument> getDocuments() {
        return documents;
    }

    public void addDocument(KycDocument document) {
        if (document != null) {
            documents.add(document);
            document.setKycVerification(this);
        }
    }
}
