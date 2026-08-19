package io.bankplatform.auth.repository;

import io.bankplatform.auth.model.LoginAudit;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * Bảng login_audit append-only theo thiết kế schema (schema.sql), không có
 * UPDATE/DELETE nghiệp vụ. Không thêm finder ở đây vì L9 chỉ cho thêm finder
 * suy ra từ UNIQUE key — bảng này không có UNIQUE key nghiệp vụ; query nghiệp
 * vụ (nếu cần) thuộc phase use-case.
 */
public interface LoginAuditRepository extends JpaRepository<LoginAudit, Long> {
}
