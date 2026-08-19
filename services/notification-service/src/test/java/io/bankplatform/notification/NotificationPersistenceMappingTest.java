package io.bankplatform.notification;

import io.bankplatform.notification.model.DeliveryAttempt;
import io.bankplatform.notification.model.DeliveryAttemptStatus;
import io.bankplatform.notification.model.Notification;
import io.bankplatform.notification.model.NotificationChannel;
import io.bankplatform.notification.model.NotificationPreference;
import io.bankplatform.notification.model.NotificationPreferenceId;
import io.bankplatform.notification.model.NotificationStatus;
import io.bankplatform.notification.model.NotificationTemplate;
import io.bankplatform.notification.model.WebhookEndpoint;
import io.bankplatform.notification.repository.DeliveryAttemptRepository;
import io.bankplatform.notification.repository.NotificationPreferenceRepository;
import io.bankplatform.notification.repository.NotificationRepository;
import io.bankplatform.notification.repository.NotificationTemplateRepository;
import io.bankplatform.notification.repository.WebhookEndpointRepository;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.transaction.annotation.Transactional;

import static org.assertj.core.api.Assertions.assertThat;

@Transactional
class NotificationPersistenceMappingTest extends AbstractIntegrationTest {

    @Autowired NotificationTemplateRepository templates;
    @Autowired NotificationRepository notifications;
    @Autowired DeliveryAttemptRepository attempts;
    @Autowired WebhookEndpointRepository webhookEndpoints;
    @Autowired NotificationPreferenceRepository preferences;
    @Autowired EntityManager em;

    @Test
    void templateRoundTrip_versionVaActiveMacDinhTuConstructor() {
        NotificationTemplate t = new NotificationTemplate(
                "transfer.completed.v1", NotificationChannel.EMAIL, "vi-VN",
                "Giao dịch thành công", "Bạn vừa chuyển {{amount}} {{currency}}");
        templates.saveAndFlush(t);
        em.clear();

        NotificationTemplate loaded = templates.findById(t.getId()).orElseThrow();
        assertThat(loaded.getVersion()).isEqualTo(1);
        assertThat(loaded.isActive()).isTrue();
        assertThat(loaded.getCreatedAt()).isNotNull(); // DB giữ, Hibernate đọc lại
    }

    @Test
    void notificationRoundTrip_payloadJsonb() {
        Notification n = new Notification(
                9L, "transfer.completed.v1", NotificationChannel.EMAIL,
                "transfer.completed.v1", "{\"amount\":100000,\"currency\":\"VND\"}");
        notifications.saveAndFlush(n);
        em.clear();

        Notification loaded = notifications.findById(n.getId()).orElseThrow();
        assertThat(loaded.getStatus()).isEqualTo(NotificationStatus.PENDING);
        assertThat(loaded.getPayload()).contains("\"amount\"");
        assertThat(loaded.getCreatedAt()).isNotNull();
    }

    @Test
    void deliveryAttemptRoundTrip() {
        Notification n = notifications.saveAndFlush(new Notification(
                9L, "transfer.completed.v1", NotificationChannel.EMAIL,
                "transfer.completed.v1", "{\"amount\":100000,\"currency\":\"VND\"}"));
        DeliveryAttempt a = new DeliveryAttempt(n.getId(), 1, DeliveryAttemptStatus.SUCCESS, null);
        attempts.saveAndFlush(a);
        em.clear();

        DeliveryAttempt loaded = attempts.findByNotificationIdAndAttemptNo(n.getId(), 1).orElseThrow();
        assertThat(loaded.getStatus()).isEqualTo(DeliveryAttemptStatus.SUCCESS);
        assertThat(loaded.getOccurredAt()).isNotNull();
    }

    @Test
    void webhookEndpointRoundTrip() {
        WebhookEndpoint w = new WebhookEndpoint(9L, "https://example.com/hook", "s".repeat(32));
        webhookEndpoints.saveAndFlush(w);
        em.clear();

        WebhookEndpoint loaded = webhookEndpoints.findByUserIdAndUrl(9L, "https://example.com/hook").orElseThrow();
        assertThat(loaded.isActive()).isTrue();
        assertThat(loaded.getLastStatus()).isNull();
        assertThat(loaded.getCreatedAt()).isNotNull();
    }

    @Test
    void preferenceRoundTrip_compositeId() {
        NotificationPreferenceId id = new NotificationPreferenceId(9L, "transfer.completed.v1", NotificationChannel.EMAIL);
        preferences.saveAndFlush(new NotificationPreference(id, true));
        em.clear();

        NotificationPreference loaded = preferences.findById(
                new NotificationPreferenceId(9L, "transfer.completed.v1", NotificationChannel.EMAIL)).orElseThrow();
        assertThat(loaded.isEnabled()).isTrue();
        assertThat(loaded.getUpdatedAt()).isNotNull(); // DB giữ qua trigger trg_prefs_updated_at
    }
}
