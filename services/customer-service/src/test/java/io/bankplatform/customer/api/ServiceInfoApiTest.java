package io.bankplatform.customer.api;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.javalibs.test.BaseIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.resttestclient.TestRestTemplate;
import org.springframework.http.ResponseEntity;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Test full-context: chứng minh endpoint đi qua được javalibs-security mà
 * KHÔNG cần JWT (đây là điều slice test không chứng minh nổi — autoconfigure
 * của javalibs không được nạp trong @WebMvcTest).
 */
class ServiceInfoApiTest extends BaseIntegrationTest {

    @Autowired
    TestRestTemplate rest;

    private final ObjectMapper mapper = new ObjectMapper();

    @Test
    void traVeThongTinServiceKhongCanJwt() throws Exception {
        ResponseEntity<String> response = rest.getForEntity("/api/customers/info", String.class);

        assertThat(response.getStatusCode().value()).isEqualTo(200);
        JsonNode body = mapper.readTree(response.getBody());
        assertThat(body.path("success").asBoolean()).isTrue();

        JsonNode data = body.path("data");
        assertThat(data.path("serviceName").asText()).isEqualTo("customer-service");
        assertThat(data.path("description").asText())
                .isEqualTo("CIF: hồ sơ khách hàng, giấy tờ, địa chỉ, liên hệ, KYC, đánh giá rủi ro.");
        assertThat(data.path("port").asInt()).isEqualTo(8082);
        assertThat(data.path("structureLevel").asText()).isEqualTo("A — phẳng");
        assertThat(data.path("dbSchema").asText()).isEqualTo("customer");
        assertThat(data.path("errorCodePrefix").asText()).isEqualTo("ERR-CUST");
        assertThat(data.path("version").asText()).isNotBlank();
        // Ghim build-info thật sự chạy: bỏ execution ở root pom thì rơi về
        // fallback "unknown" và dòng dưới phải fail lộ ra ngay, không âm thầm.
        assertThat(data.path("version").asText()).isNotEqualTo("unknown");
        assertThat(data.path("springBootVersion").asText()).isEqualTo("4.1.0");
        assertThat(data.path("uptimeSeconds").asLong()).isGreaterThanOrEqualTo(0);

        // db là Postgres của Testcontainers -> phải UP. customer không có
        // Redis nên dòng "redis" không được xuất hiện trong danh sách dependency.
        assertThat(statusOf(data, "db")).isEqualTo("UP");
        assertThat(dependencyNames(data)).doesNotContain("redis");
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
