package io.bankplatform.notification.repository;

import io.bankplatform.notification.model.NotificationPreference;
import io.bankplatform.notification.model.NotificationPreferenceId;
import org.springframework.data.jpa.repository.JpaRepository;

public interface NotificationPreferenceRepository
        extends JpaRepository<NotificationPreference, NotificationPreferenceId> {
}
