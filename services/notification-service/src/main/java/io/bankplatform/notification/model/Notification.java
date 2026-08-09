package io.bankplatform.notification.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import org.hibernate.annotations.Generated;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.generator.EventType;
import org.hibernate.type.SqlTypes;

import java.time.OffsetDateTime;

/**
 * Ứng với {@code notification.notifications} (schema.sql khối [6]). {@code userId}
 * là tham chiếu MỀM sang {@code auth.users} — KHÔNG association/FK xuyên schema.
 * {@code payload} JSONB chứa toàn bộ dữ liệu cần để soạn thông báo (event-carried
 * state), vì service này CHỈ NGHE event và không được gọi ngược lại hỏi thêm.
 * {@code status} là trường DUY NHẤT app cập nhật sau khi tạo — lịch sử từng lần
 * thử gửi nằm ở {@link DeliveryAttempt}, một bảng độc lập, không phải ở đây.
 */
@Entity
@Table(name = "notifications")
public class Notification {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "event_type", nullable = false, length = 50)
    private String eventType;

    @Enumerated(EnumType.STRING)
    @Column(name = "channel", nullable = false, length = 20)
    private NotificationChannel channel;

    @Column(name = "template_code", length = 50)
    private String templateCode;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "payload", nullable = false)
    private String payload;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private NotificationStatus status;

    @Generated(event = EventType.INSERT)
    @Column(name = "created_at", insertable = false, updatable = false)
    private OffsetDateTime createdAt;

    protected Notification() {
        // JPA
    }

    public Notification(Long userId, String eventType, NotificationChannel channel,
                         String templateCode, String payload) {
        this.userId = userId;
        this.eventType = eventType;
        this.channel = channel;
        this.templateCode = templateCode;
        this.payload = payload;
        this.status = NotificationStatus.PENDING;
    }

    public Long getId() {
        return id;
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

    public String getTemplateCode() {
        return templateCode;
    }

    public String getPayload() {
        return payload;
    }

    public NotificationStatus getStatus() {
        return status;
    }

    public void setStatus(NotificationStatus status) {
        this.status = status;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }
}
