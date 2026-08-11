package io.bankplatform.customer.domain.model;

import io.javalibs.ddd.Entity;
import jakarta.persistence.*;
import org.hibernate.annotations.Generated;
import org.hibernate.generator.EventType;

import java.time.OffsetDateTime;

/**
 * Entity bảng customer_contacts (schema customer).
 */
@jakarta.persistence.Entity
@Table(name = "customer_contacts")
public class CustomerContact extends Entity<Long> {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "customer_id", nullable = false)
    private Customer customer;

    @Enumerated(EnumType.STRING)
    @Column(name = "contact_type", nullable = false, length = 20)
    private ContactType contactType;

    @Column(name = "contact_value", nullable = false, length = 200)
    private String contactValue;

    @Column(name = "is_primary", nullable = false)
    private boolean isPrimary = false;

    @Column(name = "verified_at")
    private OffsetDateTime verifiedAt;

    @Generated(event = EventType.INSERT)
    @Column(name = "created_at", insertable = false, updatable = false)
    private OffsetDateTime createdAt;

    protected CustomerContact() {
    }

    public CustomerContact(ContactType contactType, String contactValue, boolean isPrimary, OffsetDateTime verifiedAt) {
        this.contactType = contactType;
        this.contactValue = contactValue;
        this.isPrimary = isPrimary;
        this.verifiedAt = verifiedAt;
    }

    @Override
    public Long getId() {
        return id;
    }

    public Customer getCustomer() {
        return customer;
    }

    public void setCustomer(Customer customer) {
        this.customer = customer;
    }

    public ContactType getContactType() {
        return contactType;
    }

    public String getContactValue() {
        return contactValue;
    }

    public boolean isPrimary() {
        return isPrimary;
    }

    public void setPrimary(boolean primary) {
        isPrimary = primary;
    }

    public OffsetDateTime getVerifiedAt() {
        return verifiedAt;
    }

    public void setVerifiedAt(OffsetDateTime verifiedAt) {
        this.verifiedAt = verifiedAt;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }
}
