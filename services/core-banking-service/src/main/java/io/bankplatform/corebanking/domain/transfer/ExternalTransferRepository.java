package io.bankplatform.corebanking.domain.transfer;

import io.bankplatform.corebanking.domain.transfer.model.ExternalTransfer;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface ExternalTransferRepository extends JpaRepository<ExternalTransfer, Long> {

    Optional<ExternalTransfer> findByTransferId(Long transferId);
}
