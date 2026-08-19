package io.bankplatform.notification.repository;

import io.bankplatform.notification.model.WebhookEndpoint;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface WebhookEndpointRepository extends JpaRepository<WebhookEndpoint, Long> {

    // Suy từ uq_webhook (user_id, url) — L9.
    Optional<WebhookEndpoint> findByUserIdAndUrl(Long userId, String url);
}
