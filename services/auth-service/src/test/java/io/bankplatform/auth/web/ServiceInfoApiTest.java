package io.bankplatform.auth.web;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.bankplatform.auth.AbstractIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.resttestclient.TestRestTemplate;
import org.springframework.http.ResponseEntity;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Test full-context: chứng minh endpoint đi qua được javalibs-security mà
 * KHÔNG cần JWT (đây là điều slice test không chứng minh nổi — autoconfigure
 * của javalibs không được nạp trong @WebMvcTest).
 *
 * <p>Extends {@link AbstractIntegrationTest} (không phải {@code BaseIntegrationTest}
 * trực tiếp) vì từ khi có entity, Spring context nào cũng cần schema `auth` đã
 * tồn tại trong container để {@code ddl-auto: validate} không chết lúc khởi động.
 */
class ServiceInfoApiTest extends AbstractIntegrationTest {

    @Autowired
    TestRestTemplate rest;

    private final ObjectMapper mapper = new ObjectMapper();

    @Test
    void traVeThongTinServiceKhongCanJwt() throws Exception {
        ResponseEntity<String> response = rest.getForEntity("/api/auth/info", String.class);

        assertThat(response.getStatusCode().value()).isEqualTo(200);
        JsonNode body = mapper.readTree(response.getBody());
        assertThat(body.path("success").asBoolean()).isTrue();

        JsonNode data = body.path("data");
        assertThat(data.path("serviceName").asText()).isEqualTo("auth-service");
        assertThat(data.path("description").asText())
                .isEqualTo("Định danh và phát hành token. Không biết gì về tài khoản ngân hàng.");
        assertThat(data.path("port").asInt()).isEqualTo(8081);
        assertThat(data.path("structureLevel").asText()).isEqualTo("B — layered gọn");
        assertThat(data.path("dbSchema").asText()).isEqualTo("auth");
        assertThat(data.path("errorCodePrefix").asText()).isEqualTo("ERR-AUTH");
        assertThat(data.path("version").asText()).isNotBlank();
        // Ghim build-info thật sự chạy: bỏ execution ở root pom thì rơi về
        // fallback "unknown" và dòng dưới phải fail lộ ra ngay, không âm thầm.
        assertThat(data.path("version").asText()).isNotEqualTo("unknown");
        assertThat(data.path("springBootVersion").asText()).isEqualTo("4.1.0");
        assertThat(data.path("uptimeSeconds").asLong()).isGreaterThanOrEqualTo(0);

        // db là Postgres của Testcontainers -> phải UP. redis không chạy trong
        // test nên chỉ cần dòng nó CÓ MẶT (auth có DataRedisHealthIndicator),
        // không assert giá trị.
        assertThat(statusOf(data, "db")).isEqualTo("UP");
        assertThat(dependencyNames(data)).contains("redis");
    }

    private String statusOf(JsonNode data, String name) {
        for (JsonNode dep : data.path("dependencies")) {
            if (name.equals(dep.path("name").asText())) {
                return dep.path("status").asText();
            }
        }
        return null;
    }

    private java.util.List<String> dependencyNames(JsonNode data) {
        var names = new java.util.ArrayList<String>();
        data.path("dependencies").forEach(dep -> names.add(dep.path("name").asText()));
        return names;
    }
}
