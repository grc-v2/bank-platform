package io.bankplatform.customer.domain.port;

import io.bankplatform.customer.domain.model.CustomerRiskAssessment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CustomerRiskAssessmentRepository extends JpaRepository<CustomerRiskAssessment, Long> {

    List<CustomerRiskAssessment> findByCustomerIdOrderByAssessedAtDesc(Long customerId);
}
