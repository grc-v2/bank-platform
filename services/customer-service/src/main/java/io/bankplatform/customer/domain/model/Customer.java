package io.bankplatform.customer.domain.model;

import io.bankplatform.common.ddd.AggregateRoot;
import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import org.hibernate.annotations.Generated;
import org.hibernate.generator.EventType;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;

/**
 * Aggregate Root đại diện cho thông tin CIF khách hàng (schema customer).
 */
@Entity
@Table(name = "customers")
public class Customer extends AggregateRoot<Long> {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "customer_number", nullable = false, unique = true, length = 20)
    private String customerNumber;

    @Column(name = "user_id")
    private Long userId;

    @Enumerated(EnumType.STRING)
    @Column(name = "customer_type", nullable = false, length = 20)
    private CustomerType customerType;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private CustomerStatus status = CustomerStatus.DRAFT;

    @Column(name = "kyc_level", nullable = false)
    private short kycLevel = 0;

    @Enumerated(EnumType.STRING)
    @Column(name = "risk_rating", length = 10)
    private RiskRating riskRating;

    @Generated(event = EventType.INSERT)
    @Column(name = "created_at", insertable = false, updatable = false)
    private OffsetDateTime createdAt;

    @Generated(event = {EventType.INSERT, EventType.UPDATE})
    @Column(name = "updated_at", insertable = false, updatable = false)
    private OffsetDateTime updatedAt;

    @OneToOne(mappedBy = "customer", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    private IndividualDetails individualDetails;

    @OneToOne(mappedBy = "customer", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    private OrganizationDetails organizationDetails;

    @OneToMany(mappedBy = "customer", cascade = {CascadeType.PERSIST, CascadeType.MERGE}, fetch = FetchType.LAZY)
    private List<CustomerIdentification> identifications = new ArrayList<>();

    @OneToMany(mappedBy = "customer", cascade = {CascadeType.PERSIST, CascadeType.MERGE}, fetch = FetchType.LAZY)
    private List<CustomerAddress> addresses = new ArrayList<>();

    @OneToMany(mappedBy = "customer", cascade = {CascadeType.PERSIST, CascadeType.MERGE}, fetch = FetchType.LAZY)
    private List<CustomerContact> contacts = new ArrayList<>();

    protected Customer() {
    }

    public Customer(String customerNumber, Long userId, CustomerType customerType,
                    CustomerStatus status, short kycLevel, RiskRating riskRating) {
        this.customerNumber = customerNumber;
        this.userId = userId;
        this.customerType = customerType;
        this.status = status != null ? status : CustomerStatus.DRAFT;
        this.kycLevel = kycLevel;
        this.riskRating = riskRating;
    }

    @Override
    public Long getId() {
        return id;
    }

    public String getCustomerNumber() {
        return customerNumber;
    }

    public Long getUserId() {
        return userId;
    }

    public void setUserId(Long userId) {
        this.userId = userId;
    }

    public CustomerType getCustomerType() {
        return customerType;
    }

    public CustomerStatus getStatus() {
        return status;
    }

    public void setStatus(CustomerStatus status) {
        this.status = status;
    }

    public short getKycLevel() {
        return kycLevel;
    }

    public void setKycLevel(short kycLevel) {
        this.kycLevel = kycLevel;
    }

    public RiskRating getRiskRating() {
        return riskRating;
    }

    public void setRiskRating(RiskRating riskRating) {
        this.riskRating = riskRating;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }

    public OffsetDateTime getUpdatedAt() {
        return updatedAt;
    }

    public IndividualDetails getIndividualDetails() {
        return individualDetails;
    }

    public void setIndividualDetails(IndividualDetails individualDetails) {
        this.individualDetails = individualDetails;
        if (individualDetails != null) {
            individualDetails.setCustomer(this);
        }
    }

    public OrganizationDetails getOrganizationDetails() {
        return organizationDetails;
    }

    public void setOrganizationDetails(OrganizationDetails organizationDetails) {
        this.organizationDetails = organizationDetails;
        if (organizationDetails != null) {
            organizationDetails.setCustomer(this);
        }
    }

    public List<CustomerIdentification> getIdentifications() {
        return identifications;
    }

    public void addIdentification(CustomerIdentification identification) {
        if (identification != null) {
            identifications.add(identification);
            identification.setCustomer(this);
        }
    }

    public List<CustomerAddress> getAddresses() {
        return addresses;
    }

    public void addAddress(CustomerAddress address) {
        if (address != null) {
            addresses.add(address);
            address.setCustomer(this);
        }
    }

    public List<CustomerContact> getContacts() {
        return contacts;
    }

    public void addContact(CustomerContact contact) {
        if (contact != null) {
            contacts.add(contact);
            contact.setCustomer(this);
        }
    }
}
