package io.bankplatform.auth.repository;

import io.bankplatform.auth.model.LoginAudit;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * Append-only (L9): không thêm finder — query nghiệp vụ thuộc phase use-case.
 */
public interface LoginAuditRepository extends JpaRepository<LoginAudit, Long> {
}
