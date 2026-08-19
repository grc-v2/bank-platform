package io.bankplatform.auth.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
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
 * Ứng với {@code auth.login_audit} (schema.sql khối [2]). Append-only — không
 * setter. Cố ý KHÔNG FK/association sang {@link User}: phải giữ được cả lần
 * đăng nhập bằng username không tồn tại, đó là dữ liệu để phát hiện dò tài khoản.
 */
@Entity
@Table(name = "login_audit")
public class LoginAudit {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "username", nullable = false, length = 100)
    private String username;

    @Column(name = "user_id")
    private Long userId;

    @Column(name = "success", nullable = false)
    private boolean success;

    @JdbcTypeCode(SqlTypes.INET)
    @Column(name = "ip")
    private String ip;

    @Column(name = "user_agent", length = 500)
    private String userAgent;

    @Generated(event = EventType.INSERT)
    @Column(name = "at", insertable = false, updatable = false)
    private OffsetDateTime occurredAt;

    protected LoginAudit() {
        // JPA
    }

    public LoginAudit(String username, Long userId, boolean success, String ip, String userAgent) {
        this.username = username;
        this.userId = userId;
        this.success = success;
        this.ip = ip;
        this.userAgent = userAgent;
    }

    public Long getId() {
        return id;
    }

    public String getUsername() {
        return username;
    }

    public Long getUserId() {
        return userId;
    }

    public boolean isSuccess() {
        return success;
    }

    public String getIp() {
        return ip;
    }

    public String getUserAgent() {
        return userAgent;
    }

    public OffsetDateTime getOccurredAt() {
        return occurredAt;
    }
}
