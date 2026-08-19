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
import org.hibernate.generator.EventType;

import java.time.OffsetDateTime;

/**
 * Ứng với {@code notification.delivery_attempts} (schema.sql khối [6]).
 * Append-only — không setter (quy ước chung, entity nằm trong danh sách
 * bảng append-only). Cố ý KHÔNG nằm trong aggregate {@link Notification}:
 * job retry ghi attempt không cần load lại Notification, chỉ cần
 * {@code notificationId} kiểu {@code Long} thường.
 */
@Entity
@Table(name = "delivery_attempts")
public class DeliveryAttempt {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "notification_id", nullable = false)
    private Long notificationId;

    @Column(name = "attempt_no", nullable = false)
    private int attemptNo;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private DeliveryAttemptStatus status;

    @Column(name = "error", length = 1000)
    private String error;

    @Generated(event = EventType.INSERT)
    @Column(name = "at", insertable = false, updatable = false)
    private OffsetDateTime occurredAt;

    protected DeliveryAttempt() {
        // JPA
    }

    public DeliveryAttempt(Long notificationId, int attemptNo, DeliveryAttemptStatus status, String error) {
        this.notificationId = notificationId;
        this.attemptNo = attemptNo;
        this.status = status;
        this.error = error;
    }

    public Long getId() {
        return id;
    }

    public Long getNotificationId() {
        return notificationId;
    }

    public int getAttemptNo() {
        return attemptNo;
    }

    public DeliveryAttemptStatus getStatus() {
        return status;
    }

    public String getError() {
        return error;
    }

    public OffsetDateTime getOccurredAt() {
        return occurredAt;
    }
}
