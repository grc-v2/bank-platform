package io.bankplatform.customer.api;

import io.bankplatform.customer.api.dto.DependencyStatus;
import io.bankplatform.customer.api.dto.ServiceInfoResponse;
import io.bankplatform.customer.config.ServiceInfoProperties;
import io.bankplatform.common.web.ApiResponse;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.SpringBootVersion;
import org.springframework.boot.health.actuate.endpoint.CompositeHealthDescriptor;
import org.springframework.boot.health.actuate.endpoint.HealthEndpoint;
import org.springframework.boot.info.BuildProperties;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.lang.management.ManagementFactory;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;

/**
 * Thông tin chi tiết của service cho dashboard dev.
 *
 * <p>Không có xác thực nào chặn endpoint này — từ 2026-09-01 service không còn
 * Spring Security (xem docs/KNOWN-LIMITATIONS.md). Kể cả khi dựng lại
 * security, endpoint này nên để mở: payload chỉ là metadata dev, không secret,
 * không connection string.</p>
 */
@RestController
public class ServiceInfoController {

    /**
     * Chỉ ba hạ tầng này đáng hiển thị — các component còn lại của actuator
     * (diskSpace, ping, ssl) là nhiễu với dashboard. "kafka" nằm sẵn trong
     * danh sách theo dõi dù Boot 4.1 KHÔNG có health indicator nào cho Kafka
     * — đã soát cả actuator, spring-boot-kafka lẫn spring-kafka 4.1.0, không
     * jar nào chứa lớp health Kafka — VÀ Kafka client hiện không còn trên
     * classpath của service này (gỡ cùng platform-libs, xem
     * docs/KNOWN-LIMITATIONS.md mục "Kafka client không còn trên classpath").
     * Muốn dòng kafka xuất hiện phải làm hai việc theo thứ tự: (1) thêm lại
     * dependency Kafka vào pom.xml, (2) viết health indicator (tự viết bằng
     * KafkaAdmin.describeCluster hoặc chờ Boot bổ sung).
     */
    private static final Set<String> WATCHED_DEPENDENCIES = Set.of("db", "redis", "kafka");

    private final ServiceInfoProperties properties;
    private final HealthEndpoint healthEndpoint;
    private final String serviceName;
    private final String version;

    ServiceInfoController(ServiceInfoProperties properties,
                          HealthEndpoint healthEndpoint,
                          @Value("${spring.application.name}") String serviceName,
                          ObjectProvider<BuildProperties> buildProperties) {
        this.properties = properties;
        this.healthEndpoint = healthEndpoint;
        this.serviceName = serviceName;
        // BuildProperties chỉ tồn tại khi goal build-info đã chạy (mvn); chạy
        // từ IDE có thể thiếu — fallback thay vì chết lúc khởi động.
        BuildProperties build = buildProperties.getIfAvailable();
        this.version = build != null ? build.getVersion() : "unknown";
    }

    @GetMapping("/api/customers/info")
    public ApiResponse<ServiceInfoResponse> info() {
        var runtime = ManagementFactory.getRuntimeMXBean();
        return ApiResponse.ok(new ServiceInfoResponse(
                serviceName,
                properties.description(),
                version,
                properties.port(),
                properties.structureLevel(),
                properties.dbSchema(),
                properties.errorCodePrefix(),
                Runtime.version().toString(),
                SpringBootVersion.getVersion(),
                Instant.ofEpochMilli(runtime.getStartTime()),
                runtime.getUptime() / 1000,
                dependencies()));
    }

    private List<DependencyStatus> dependencies() {
        List<DependencyStatus> result = new ArrayList<>();
        if (healthEndpoint.health() instanceof CompositeHealthDescriptor composite) {
            composite.getComponents().forEach((name, descriptor) -> {
                if (WATCHED_DEPENDENCIES.contains(name)) {
                    result.add(new DependencyStatus(name, descriptor.getStatus().getCode()));
                }
            });
        }
        return result;
    }
}
