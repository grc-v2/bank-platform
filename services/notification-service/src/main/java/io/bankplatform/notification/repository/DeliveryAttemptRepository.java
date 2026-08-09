package io.bankplatform.notification.repository;

import io.bankplatform.notification.model.DeliveryAttempt;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface DeliveryAttemptRepository extends JpaRepository<DeliveryAttempt, Long> {

    // Suy từ uq_attempts (notification_id, attempt_no) — L9.
    Optional<DeliveryAttempt> findByNotificationIdAndAttemptNo(Long notificationId, int attemptNo);
}
