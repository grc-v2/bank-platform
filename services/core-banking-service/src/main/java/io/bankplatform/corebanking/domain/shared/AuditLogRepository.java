package io.bankplatform.corebanking.domain.shared;

import io.bankplatform.corebanking.domain.shared.model.AuditLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface AuditLogRepository extends JpaRepository<AuditLog, Long> {
}
