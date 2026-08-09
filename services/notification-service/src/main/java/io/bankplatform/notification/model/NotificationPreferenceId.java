package io.bankplatform.notification.model;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;

import java.io.Serializable;
import java.util.Objects;

/**
 * Khoá chính ghép của {@code notification.user_notification_preferences}:
 * (user_id, event_type, channel) — một dòng cho mỗi cặp (loại event, kênh)
 * mà người dùng CHỈNH KHÁC mặc định. Vắng dòng nghĩa là mặc định BẬT.
 */
@Embeddable
public class NotificationPreferenceId implements Serializable {

    @Column(name = "user_id")
    private Long userId;

    @Column(name = "event_type")
    private String eventType;

    @Enumerated(EnumType.STRING)
    @Column(name = "channel")
    private NotificationChannel channel;

    protected NotificationPreferenceId() {
        // JPA
    }

    public NotificationPreferenceId(Long userId, String eventType, NotificationChannel channel) {
        this.userId = userId;
        this.eventType = eventType;
        this.channel = channel;
    }

    public Long getUserId() {
        return userId;
    }

    public String getEventType() {
        return eventType;
    }

    public NotificationChannel getChannel() {
        return channel;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) {
            return true;
        }
        if (!(o instanceof NotificationPreferenceId that)) {
            return false;
        }
        return Objects.equals(userId, that.userId)
                && Objects.equals(eventType, that.eventType)
                && channel == that.channel;
    }

    @Override
    public int hashCode() {
        return Objects.hash(userId, eventType, channel);
    }
}
