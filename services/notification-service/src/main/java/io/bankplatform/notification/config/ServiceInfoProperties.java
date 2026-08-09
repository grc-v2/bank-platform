package io.bankplatform.notification.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Thông tin service TỰ KHAI về mình (khối bank.info trong application.yml).
 * port ở đây là cổng CÔNG BỐ của service, không đọc từ server.port — vì test
 * chạy RANDOM_PORT làm server.port thành 0, còn dashboard cần cổng thật.
 */
@ConfigurationProperties(prefix = "bank.info")
public record ServiceInfoProperties(
        String description,
        String structureLevel,
        String dbSchema,
        String errorCodePrefix,
        int port) {
}
