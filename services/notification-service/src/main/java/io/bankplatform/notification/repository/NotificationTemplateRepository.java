package io.bankplatform.notification.repository;

import io.bankplatform.notification.model.NotificationChannel;
import io.bankplatform.notification.model.NotificationTemplate;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface NotificationTemplateRepository extends JpaRepository<NotificationTemplate, Long> {

    // Suy từ uq_templates (template_code, channel, locale, version) — L9.
    Optional<NotificationTemplate> findByTemplateCodeAndChannelAndLocaleAndVersion(
            String templateCode, NotificationChannel channel, String locale, int version);
}
