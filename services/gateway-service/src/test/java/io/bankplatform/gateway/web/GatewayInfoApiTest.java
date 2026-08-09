package io.bankplatform.gateway.web;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * MockMvc (webEnvironment MOCK) thay vì RANDOM_PORT: giữ nguyên server.port
 * 8080 từ yml để assert được, và không cần server thật.
 */
@SpringBootTest
@AutoConfigureMockMvc
class GatewayInfoApiTest {

    @Autowired
    MockMvc mvc;

    @Test
    void traVeThongTinGatewayVaBangRoute() throws Exception {
        mvc.perform(get("/api/gateway/info"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.serviceName").value("gateway-service"))
                .andExpect(jsonPath("$.data.port").value(8080))
                .andExpect(jsonPath("$.data.routes.length()").value(5))
                .andExpect(jsonPath("$.data.routes[?(@.id=='auth')].paths[0]").value("/api/auth/**"))
                .andExpect(jsonPath("$.data.routes[?(@.id=='core-banking')].target")
                        .value("http://localhost:8084"));
    }
}
