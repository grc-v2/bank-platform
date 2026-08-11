package io.bankplatform.corebanking.domain.ledger;

import io.bankplatform.corebanking.domain.ledger.model.AccountBalanceSnapshot;
import io.bankplatform.corebanking.domain.ledger.model.AccountBalanceSnapshotId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface AccountBalanceSnapshotRepository extends JpaRepository<AccountBalanceSnapshot, AccountBalanceSnapshotId> {
}
