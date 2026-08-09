package io.bankplatform.auth;

import io.bankplatform.auth.model.*;
import io.bankplatform.auth.repository.*;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;

@Transactional
class AuthPersistenceMappingTest extends AbstractIntegrationTest {

    @Autowired UserRepository users;
    @Autowired RefreshTokenRepository refreshTokens;
    @Autowired LoginAuditRepository loginAudits;
    @Autowired EntityManager em;

    @Test
    void userRoundTrip_kemRoles() {
        User u = new User("teller01", "$2a$10$hash-gia-du-60-ky-tu");
        u.getRoles().add(UserRole.TELLER);
        u.getRoles().add(UserRole.ADMIN);
        users.saveAndFlush(u);
        em.clear();

        User loaded = users.findByUsername("teller01").orElseThrow();
        assertThat(loaded.getStatus()).isEqualTo(UserStatus.ACTIVE);
        assertThat(loaded.getRoles()).containsExactlyInAnyOrder(UserRole.TELLER, UserRole.ADMIN);
        assertThat(loaded.getCreatedAt()).isNotNull(); // DB giữ, Hibernate đọc lại
        assertThat(loaded.getUpdatedAt()).isNotNull();
    }

    @Test
    void refreshTokenRoundTrip() {
        User u = users.saveAndFlush(new User("cust01", "$2a$10$hash"));
        RefreshToken t = new RefreshToken(u.getId(), "a".repeat(64), OffsetDateTime.now().plusDays(30));
        refreshTokens.saveAndFlush(t);
        em.clear();

        RefreshToken loaded = refreshTokens.findByTokenHash("a".repeat(64)).orElseThrow();
        assertThat(loaded.getUserId()).isEqualTo(u.getId());
        assertThat(loaded.getRevokedAt()).isNull();
        assertThat(loaded.getCreatedAt()).isNotNull();
    }

    @Test
    void loginAuditRoundTrip_inet() {
        LoginAudit a = new LoginAudit("ai-do", null, false, "203.0.113.7", "curl/8");
        loginAudits.saveAndFlush(a);
        em.clear();

        LoginAudit loaded = loginAudits.findById(a.getId()).orElseThrow();
        assertThat(loaded.isSuccess()).isFalse();
        assertThat(loaded.getIp()).isEqualTo("203.0.113.7");
        assertThat(loaded.getOccurredAt()).isNotNull();
    }
}
