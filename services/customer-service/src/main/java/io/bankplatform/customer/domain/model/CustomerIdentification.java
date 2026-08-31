package io.bankplatform.customer.domain.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import org.hibernate.annotations.Generated;
import org.hibernate.generator.EventType;

import java.time.LocalDate;
import java.time.OffsetDateTime;

/**
 * Entity bảng customer_identifications (schema customer).
 */
@Entity
@Table(name = "customer_identifications")
public class CustomerIdentification extends io.bankplatform.common.ddd.Entity<Long> {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "customer_id", nullable = false)
    private Customer customer;

    @Enumerated(EnumType.STRING)
    @Column(name = "id_type", nullable = false, length = 30)
    private IdentificationType idType;

    @Column(name = "id_number", nullable = false, length = 50)
    private String idNumber;

    @Column(name = "issued_date")
    private LocalDate issuedDate;

    @Column(name = "issued_place", length = 100)
    private String issuedPlace;

    @Column(name = "expiry_date")
    private LocalDate expiryDate;

    @Generated(event = EventType.INSERT)
    @Column(name = "created_at", insertable = false, updatable = false)
    private OffsetDateTime createdAt;

    protected CustomerIdentification() {
    }

    public CustomerIdentification(IdentificationType idType, String idNumber,
                                  LocalDate issuedDate, String issuedPlace, LocalDate expiryDate) {
        this.idType = idType;
        this.idNumber = idNumber;
        this.issuedDate = issuedDate;
        this.issuedPlace = issuedPlace;
        this.expiryDate = expiryDate;
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

    public IdentificationType getIdType() {
        return idType;
    }

    public String getIdNumber() {
        return idNumber;
    }

    public LocalDate getIssuedDate() {
        return issuedDate;
    }

    public String getIssuedPlace() {
        return issuedPlace;
    }

    public LocalDate getExpiryDate() {
        return expiryDate;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }
}
