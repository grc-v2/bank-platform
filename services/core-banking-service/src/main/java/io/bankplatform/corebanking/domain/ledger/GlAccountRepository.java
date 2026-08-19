package io.bankplatform.corebanking.domain.ledger;

import io.bankplatform.corebanking.domain.ledger.model.GlAccount;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface GlAccountRepository extends JpaRepository<GlAccount, Long> {

    Optional<GlAccount> findByGlCode(String glCode);
}
