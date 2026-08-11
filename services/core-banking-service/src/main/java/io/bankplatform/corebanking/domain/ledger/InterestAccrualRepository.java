package io.bankplatform.corebanking.domain.ledger;

import io.bankplatform.corebanking.domain.ledger.model.InterestAccrual;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.Optional;

@Repository
public interface InterestAccrualRepository extends JpaRepository<InterestAccrual, Long> {

    Optional<InterestAccrual> findByAccountIdAndAccrualDate(Long accountId, LocalDate accrualDate);
}
