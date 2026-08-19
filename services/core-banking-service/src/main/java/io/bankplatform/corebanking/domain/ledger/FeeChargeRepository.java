package io.bankplatform.corebanking.domain.ledger;

import io.bankplatform.corebanking.domain.ledger.model.FeeCharge;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface FeeChargeRepository extends JpaRepository<FeeCharge, Long> {

    List<FeeCharge> findByAccountIdOrderByChargedAtDesc(Long accountId);
}
