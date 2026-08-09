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
 * Ứng với {@code notification.notification_templates} (schema.sql khối [6]).
 * Nội dung thông báo tách khỏi việc gửi: đổi câu chữ không cần deploy lại code.
 * {@code version} tăng dần mỗi lần sửa nội dung — sửa nghĩa là TẠO DÒNG MỚI
 * với version kế tiếp, không ghi đè dòng cũ, để tra được thông báo cũ đã gửi
 * bằng đúng bản nội dung nào. {@code active} cho phép ngừng dùng một version
 * (ví dụ khi ban hành version mới) mà vẫn giữ lại lịch sử.
 */
@Entity
@Table(name = "notification_templates")
public class NotificationTemplate {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "template_code", nullable = false, length = 50)
    private String templateCode;

    @Enumerated(EnumType.STRING)
    @Column(name = "channel", nullable = false, length = 20)
    private NotificationChannel channel;

    @Column(name = "locale", nullable = false, length = 10)
    private String locale;

    @Column(name = "subject", length = 200)
    private String subject;

    @Column(name = "body_template", nullable = false)
    private String bodyTemplate;

    @Column(name = "version", nullable = false)
    private int version;

    @Column(name = "active", nullable = false)
    private boolean active;

    @Generated(event = EventType.INSERT)
    @Column(name = "created_at", insertable = false, updatable = false)
    private OffsetDateTime createdAt;

    protected NotificationTemplate() {
        // JPA
    }

    public NotificationTemplate(String templateCode, NotificationChannel channel, String locale,
                                 String subject, String bodyTemplate) {
        this.templateCode = templateCode;
        this.channel = channel;
        this.locale = locale;
        this.subject = subject;
        this.bodyTemplate = bodyTemplate;
        this.version = 1;
        this.active = true;
    }

    public Long getId() {
        return id;
    }

    public String getTemplateCode() {
        return templateCode;
    }

    public NotificationChannel getChannel() {
        return channel;
    }

    public String getLocale() {
        return locale;
    }

    public String getSubject() {
        return subject;
    }

    public String getBodyTemplate() {
        return bodyTemplate;
    }

    public int getVersion() {
        return version;
    }

    public boolean isActive() {
        return active;
    }

    public void setActive(boolean active) {
        this.active = active;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }
}
