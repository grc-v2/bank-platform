package io.bankplatform.corebanking.domain.transfer;

import io.bankplatform.corebanking.domain.transfer.model.TransferLimitUsage;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.Optional;

@Repository
public interface TransferLimitUsageRepository extends JpaRepository<TransferLimitUsage, Long> {

    Optional<TransferLimitUsage> findByAccountIdAndLimitCodeAndWindowStart(Long accountId, String limitCode, LocalDate windowStart);
}
