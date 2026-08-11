package io.bankplatform.corebanking.domain.account;

import io.bankplatform.corebanking.domain.account.model.AccountHold;
import io.bankplatform.corebanking.domain.account.model.HoldStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface AccountHoldRepository extends JpaRepository<AccountHold, Long> {

    List<AccountHold> findByAccountIdAndStatus(Long accountId, HoldStatus status);
}
