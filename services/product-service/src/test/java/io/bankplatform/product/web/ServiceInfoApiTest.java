package io.bankplatform.product.web;

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
        ResponseEntity<String> response = rest.getForEntity("/api/products/info", String.class);

        assertThat(response.getStatusCode().value()).isEqualTo(200);
        JsonNode body = mapper.readTree(response.getBody());
        assertThat(body.path("success").asBoolean()).isTrue();

        JsonNode data = body.path("data");
        assertThat(data.path("serviceName").asText()).isEqualTo("product-service");
        assertThat(data.path("description").asText())
                .isEqualTo("Danh mục sản phẩm: lãi suất, biểu phí, hạn mức, điều kiện mở, ánh xạ GL.");
        assertThat(data.path("port").asInt()).isEqualTo(8083);
        assertThat(data.path("structureLevel").asText()).isEqualTo("B — layered gọn");
        assertThat(data.path("dbSchema").asText()).isEqualTo("product");
        assertThat(data.path("errorCodePrefix").asText()).isEqualTo("ERR-PROD");
        assertThat(data.path("version").asText()).isNotBlank();
        assertThat(data.path("springBootVersion").asText()).isEqualTo("4.1.0");
        assertThat(data.path("uptimeSeconds").asLong()).isGreaterThanOrEqualTo(0);

        // db là Postgres của Testcontainers -> phải UP. redis không chạy trong
        // test nên chỉ cần dòng nó CÓ MẶT (product có DataRedisHealthIndicator),
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
