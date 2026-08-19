package io.bankplatform.customer.domain.port;

import io.bankplatform.customer.domain.model.KycVerification;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface KycVerificationRepository extends JpaRepository<KycVerification, Long> {

    List<KycVerification> findByCustomerIdOrderBySubmittedAtDesc(Long customerId);
}
