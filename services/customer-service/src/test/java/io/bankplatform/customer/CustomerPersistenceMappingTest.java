package io.bankplatform.customer;

import io.bankplatform.customer.domain.model.*;
import io.bankplatform.customer.domain.port.*;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

@Transactional
class CustomerPersistenceMappingTest extends AbstractIntegrationTest {

    @Autowired
    private CustomerRepository customerRepository;

    @Autowired
    private KycVerificationRepository kycVerificationRepository;

    @Autowired
    private CustomerRiskAssessmentRepository riskAssessmentRepository;

    @Autowired
    private EntityManager em;

    @Test
    void saveCustomerIndividual_roundTrip() {
        Customer customer = new Customer(
                "CIF_IND_001",
                101L,
                CustomerType.INDIVIDUAL,
                CustomerStatus.ACTIVE,
                (short) 1,
                RiskRating.LOW
        );

        IndividualDetails details = new IndividualDetails(
                "Văn A",
                "Nguyễn",
                LocalDate.of(1990, 1, 1),
                Gender.MALE,
                "VN",
                "Kỹ sư CNTT",
                MaritalStatus.SINGLE
        );
        customer.setIndividualDetails(details);

        CustomerIdentification ident = new CustomerIdentification(
                IdentificationType.NATIONAL_ID,
                "123456789012",
                LocalDate.of(2020, 1, 1),
                "CA TP.HCM",
                null
        );
        customer.addIdentification(ident);

        CustomerAddress address = new CustomerAddress(
                AddressType.PERMANENT,
                "123 Lê Lợi",
                null,
                "Phường Bến Nghé",
                "Quận 1",
                "TP.HCM",
                "VN",
                true,
                LocalDate.now(),
                null
        );
        customer.addAddress(address);

        CustomerContact contact = new CustomerContact(
                ContactType.EMAIL,
                "nguyenvana@example.com",
                true,
                OffsetDateTime.now()
        );
        customer.addContact(contact);

        customer = customerRepository.saveAndFlush(customer);
        Long customerId = customer.getId();
        assertThat(customerId).isNotNull();

        em.clear();

        Customer fetched = customerRepository.findByCustomerNumber("CIF_IND_001").orElseThrow();
        assertThat(fetched.getId()).isEqualTo(customerId);
        assertThat(fetched.getCustomerType()).isEqualTo(CustomerType.INDIVIDUAL);
        assertThat(fetched.getStatus()).isEqualTo(CustomerStatus.ACTIVE);
        assertThat(fetched.getKycLevel()).isEqualTo((short) 1);
        assertThat(fetched.getCreatedAt()).isNotNull();
        assertThat(fetched.getUpdatedAt()).isNotNull();

        assertThat(fetched.getIndividualDetails()).isNotNull();
        assertThat(fetched.getIndividualDetails().getFirstName()).isEqualTo("Văn A");
        assertThat(fetched.getIndividualDetails().getLastName()).isEqualTo("Nguyễn");

        assertThat(fetched.getIdentifications()).hasSize(1);
        assertThat(fetched.getIdentifications().get(0).getIdNumber()).isEqualTo("123456789012");
        assertThat(fetched.getIdentifications().get(0).getCreatedAt()).isNotNull();

        assertThat(fetched.getAddresses()).hasSize(1);
        assertThat(fetched.getAddresses().get(0).getLine1()).isEqualTo("123 Lê Lợi");

        assertThat(fetched.getContacts()).hasSize(1);
        assertThat(fetched.getContacts().get(0).getContactValue()).isEqualTo("nguyenvana@example.com");
    }

    @Test
    void saveCustomerOrganization_roundTrip() {
        Customer customer = new Customer(
                "CIF_ORG_001",
                null,
                CustomerType.ORGANIZATION,
                CustomerStatus.ACTIVE,
                (short) 2,
                RiskRating.MEDIUM
        );

        OrganizationDetails details = new OrganizationDetails(
                "Công ty TNHH Mẫu",
                "Sample Co",
                "0101234567",
                LocalDate.of(2015, 5, 15),
                "FINTECH"
        );
        customer.setOrganizationDetails(details);

        customer = customerRepository.saveAndFlush(customer);
        Long customerId = customer.getId();

        em.clear();

        Customer fetched = customerRepository.findByCustomerNumber("CIF_ORG_001").orElseThrow();
        assertThat(fetched.getId()).isEqualTo(customerId);
        assertThat(fetched.getOrganizationDetails()).isNotNull();
        assertThat(fetched.getOrganizationDetails().getLegalName()).isEqualTo("Công ty TNHH Mẫu");
        assertThat(fetched.getOrganizationDetails().getTaxCode()).isEqualTo("0101234567");
    }

    @Test
    void saveKycVerificationWithDocuments_roundTrip() {
        Customer customer = customerRepository.saveAndFlush(new Customer(
                "CIF_KYC_001", null, CustomerType.INDIVIDUAL, CustomerStatus.ACTIVE, (short) 1, RiskRating.LOW
        ));
        Long targetCustomerId = customer.getId();

        KycVerification kyc = new KycVerification(
                targetCustomerId,
                (short) 2,
                KycStatus.APPROVED,
                KycMethod.EKYC
        );
        kyc.setDecidedAt(OffsetDateTime.now());
        kyc.setDecidedBy(201L);

        KycDocument doc = new KycDocument(
                "NATIONAL_ID_FRONT",
                "kyc/2026/08/doc1.jpg",
                "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        );
        kyc.addDocument(doc);

        kyc = kycVerificationRepository.saveAndFlush(kyc);
        Long kycId = kyc.getId();
        assertThat(kycId).isNotNull();

        em.clear();

        List<KycVerification> fetchedList = kycVerificationRepository.findByCustomerIdOrderBySubmittedAtDesc(targetCustomerId);
        assertThat(fetchedList).isNotEmpty();
        KycVerification fetched = fetchedList.get(0);
        assertThat(fetched.getId()).isEqualTo(kycId);
        assertThat(fetched.getStatus()).isEqualTo(KycStatus.APPROVED);
        assertThat(fetched.getDecidedBy()).isEqualTo(201L);
        assertThat(fetched.getSubmittedAt()).isNotNull();

        assertThat(fetched.getDocuments()).hasSize(1);
        assertThat(fetched.getDocuments().get(0).getDocType()).isEqualTo("NATIONAL_ID_FRONT");
        assertThat(fetched.getDocuments().get(0).getUploadedAt()).isNotNull();
    }

    @Test
    void saveCustomerRiskAssessment_roundTrip() {
        Customer customer = customerRepository.saveAndFlush(new Customer(
                "CIF_RISK_001", null, CustomerType.INDIVIDUAL, CustomerStatus.ACTIVE, (short) 1, RiskRating.MEDIUM
        ));
        Long targetCustomerId = customer.getId();

        CustomerRiskAssessment risk = new CustomerRiskAssessment(
                targetCustomerId,
                RiskRating.MEDIUM,
                45,
                "{\"factors\":[\"pep_relative\"]}",
                301L
        );

        risk = riskAssessmentRepository.saveAndFlush(risk);
        Long riskId = risk.getId();
        assertThat(riskId).isNotNull();

        em.clear();

        List<CustomerRiskAssessment> fetchedList = riskAssessmentRepository.findByCustomerIdOrderByAssessedAtDesc(targetCustomerId);
        assertThat(fetchedList).hasSize(1);
        CustomerRiskAssessment fetched = fetchedList.get(0);
        assertThat(fetched.getId()).isEqualTo(riskId);
        assertThat(fetched.getRating()).isEqualTo(RiskRating.MEDIUM);
        assertThat(fetched.getScore()).isEqualTo(45);
        assertThat(fetched.getReason()).contains("pep_relative");
        assertThat(fetched.getAssessedAt()).isNotNull();
    }
}
