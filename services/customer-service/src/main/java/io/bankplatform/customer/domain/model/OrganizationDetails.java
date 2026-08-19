package io.bankplatform.customer.domain.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.MapsId;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;

import java.time.LocalDate;

/**
 * Hồ sơ chi tiết cho khách hàng tổ chức/doanh nghiệp (schema customer).
 */
@Entity
@Table(name = "organization_details")
public class OrganizationDetails extends io.javalibs.ddd.Entity<Long> {

    @Id
    @Column(name = "customer_id")
    private Long customerId;

    @MapsId
    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "customer_id")
    private Customer customer;

    @Column(name = "legal_name", nullable = false, length = 200)
    private String legalName;

    @Column(name = "trade_name", length = 200)
    private String tradeName;

    @Column(name = "tax_code", nullable = false, unique = true, length = 20)
    private String taxCode;

    @Column(name = "incorporation_date")
    private LocalDate incorporationDate;

    @Column(name = "business_type", length = 100)
    private String businessType;

    protected OrganizationDetails() {
    }

    public OrganizationDetails(String legalName, String tradeName, String taxCode,
                               LocalDate incorporationDate, String businessType) {
        this.legalName = legalName;
        this.tradeName = tradeName;
        this.taxCode = taxCode;
        this.incorporationDate = incorporationDate;
        this.businessType = businessType;
    }

    @Override
    public Long getId() {
        return customerId;
    }

    public Customer getCustomer() {
        return customer;
    }

    public void setCustomer(Customer customer) {
        this.customer = customer;
        if (customer != null) {
            this.customerId = customer.getId();
        }
    }

    public String getLegalName() {
        return legalName;
    }

    public void setLegalName(String legalName) {
        this.legalName = legalName;
    }

    public String getTradeName() {
        return tradeName;
    }

    public void setTradeName(String tradeName) {
        this.tradeName = tradeName;
    }

    public String getTaxCode() {
        return taxCode;
    }

    public void setTaxCode(String taxCode) {
        this.taxCode = taxCode;
    }

    public LocalDate getIncorporationDate() {
        return incorporationDate;
    }

    public void setIncorporationDate(LocalDate incorporationDate) {
        this.incorporationDate = incorporationDate;
    }

    public String getBusinessType() {
        return businessType;
    }

    public void setBusinessType(String businessType) {
        this.businessType = businessType;
    }
}
