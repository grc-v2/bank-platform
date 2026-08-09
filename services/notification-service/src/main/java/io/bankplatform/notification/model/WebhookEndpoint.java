package io.bankplatform.notification.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import org.hibernate.annotations.Generated;
import org.hibernate.generator.EventType;

import java.time.OffsetDateTime;

/**
 * Ứng với {@code notification.webhook_endpoints} (schema.sql khối [6]).
 * {@code url} do người dùng nhập — bề mặt SSRF chính của service này (chặn ở
 * tầng gọi HTTP khi thực hiện call, không phải trách nhiệm của entity).
 * {@code secret} dùng ký HMAC payload để endpoint nhận xác minh nguồn —
 * KHÔNG được log field này ra ở bất kỳ tầng nào phía trên (chỉ là field
 * thường ở đây, không có annotation ẩn giá trị; kỷ luật log nằm ở tầng gọi).
 */
@Entity
@Table(name = "webhook_endpoints")
public class WebhookEndpoint {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "url", nullable = false, length = 2048)
    private String url;

    @Column(name = "secret", nullable = false, length = 64)
    private String secret;

    @Column(name = "active", nullable = false)
    private boolean active;

    @Column(name = "last_status")
    private Integer lastStatus;

    @Column(name = "last_checked_at")
    private OffsetDateTime lastCheckedAt;

    @Generated(event = EventType.INSERT)
    @Column(name = "created_at", insertable = false, updatable = false)
    private OffsetDateTime createdAt;

    protected WebhookEndpoint() {
        // JPA
    }

    public WebhookEndpoint(Long userId, String url, String secret) {
        this.userId = userId;
        this.url = url;
        this.secret = secret;
        this.active = true;
    }

    public Long getId() {
        return id;
    }

    public Long getUserId() {
        return userId;
    }

    public String getUrl() {
        return url;
    }

    public String getSecret() {
        return secret;
    }

    public boolean isActive() {
        return active;
    }

    public void setActive(boolean active) {
        this.active = active;
    }

    public Integer getLastStatus() {
        return lastStatus;
    }

    public void setLastStatus(Integer lastStatus) {
        this.lastStatus = lastStatus;
    }

    public OffsetDateTime getLastCheckedAt() {
        return lastCheckedAt;
    }

    public void setLastCheckedAt(OffsetDateTime lastCheckedAt) {
        this.lastCheckedAt = lastCheckedAt;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }
}
