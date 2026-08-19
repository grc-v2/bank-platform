package io.bankplatform.notification.model;

import jakarta.persistence.Column;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import org.hibernate.annotations.Generated;
import org.hibernate.generator.EventType;

import java.time.OffsetDateTime;

/**
 * Ứng với {@code notification.user_notification_preferences} (schema.sql khối [6]).
 * Opt-out theo từng cặp (loại event, kênh): vắng dòng nghĩa là mặc định BẬT,
 * dòng chỉ được tạo khi người dùng chỉnh khác mặc định. {@code updated_at} do
 * DB giữ qua trigger {@code trg_prefs_updated_at} (không phải {@code created_at}
 * DEFAULT thông thường — đây là timestamp "đời bản ghi", app không tự đặt).
 */
@Entity
@Table(name = "user_notification_preferences")
public class NotificationPreference {

    @EmbeddedId
    private NotificationPreferenceId id;

    @Column(name = "enabled", nullable = false)
    private boolean enabled;

    @Generated(event = {EventType.INSERT, EventType.UPDATE})
    @Column(name = "updated_at", insertable = false, updatable = false)
    private OffsetDateTime updatedAt;

    protected NotificationPreference() {
        // JPA
    }

    public NotificationPreference(NotificationPreferenceId id, boolean enabled) {
        this.id = id;
        this.enabled = enabled;
    }

    public NotificationPreferenceId getId() {
        return id;
    }

    public boolean isEnabled() {
        return enabled;
    }

    public void setEnabled(boolean enabled) {
        this.enabled = enabled;
    }

    public OffsetDateTime getUpdatedAt() {
        return updatedAt;
    }
}
