package io.bankplatform.customer.domain.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import org.hibernate.annotations.Generated;
import org.hibernate.generator.EventType;

import java.time.OffsetDateTime;

/**
 * Entity tài liệu đính kèm cho hồ sơ KYC (schema customer). Append-only.
 */
@Entity
@Table(name = "kyc_documents")
public class KycDocument extends io.javalibs.ddd.Entity<Long> {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "kyc_verification_id", nullable = false)
    private KycVerification kycVerification;

    @Column(name = "doc_type", nullable = false, length = 50)
    private String docType;

    @Column(name = "storage_key", nullable = false, length = 500)
    private String storageKey;

    @Column(name = "checksum", nullable = false, length = 64)
    private String checksum;

    @Generated(event = EventType.INSERT)
    @Column(name = "uploaded_at", insertable = false, updatable = false)
    private OffsetDateTime uploadedAt;

    protected KycDocument() {
    }

    public KycDocument(String docType, String storageKey, String checksum) {
        this.docType = docType;
        this.storageKey = storageKey;
        this.checksum = checksum;
    }

    @Override
    public Long getId() {
        return id;
    }

    public KycVerification getKycVerification() {
        return kycVerification;
    }

    public void setKycVerification(KycVerification kycVerification) {
        this.kycVerification = kycVerification;
    }

    public String getDocType() {
        return docType;
    }

    public String getStorageKey() {
        return storageKey;
    }

    public String getChecksum() {
        return checksum;
    }

    public OffsetDateTime getUploadedAt() {
        return uploadedAt;
    }
}
