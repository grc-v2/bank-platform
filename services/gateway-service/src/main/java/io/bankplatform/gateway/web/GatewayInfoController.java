package io.bankplatform.gateway.web;

import io.bankplatform.gateway.web.dto.ApiEnvelope;
import io.bankplatform.gateway.web.dto.GatewayInfoResponse;
import io.bankplatform.gateway.web.dto.RouteInfo;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.SpringBootVersion;
import org.springframework.boot.info.BuildProperties;
import org.springframework.cloud.gateway.server.mvc.config.GatewayMvcProperties;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.lang.management.ManagementFactory;
import java.time.Instant;
import java.util.List;

/**
 * Thông tin của chính gateway cho dashboard. /api/gateway/** không khớp route
 * chuyển tiếp nào nên rơi xuống controller này — không đụng bảng route.
 */
@RestController
public class GatewayInfoController {

    private static final String DESCRIPTION =
            "Cổng vào duy nhất cho frontend. Chỉ định tuyến — không nghiệp vụ, không DB.";

    private final GatewayMvcProperties gatewayProperties;
    private final String serviceName;
    private final int port;
    private final String version;

    GatewayInfoController(GatewayMvcProperties gatewayProperties,
                          @Value("${spring.application.name}") String serviceName,
                          @Value("${server.port}") int port,
                          ObjectProvider<BuildProperties> buildProperties) {
        this.gatewayProperties = gatewayProperties;
        this.serviceName = serviceName;
        this.port = port;
        BuildProperties build = buildProperties.getIfAvailable();
        this.version = build != null ? build.getVersion() : "unknown";
    }

    @GetMapping("/api/gateway/info")
    public ApiEnvelope<GatewayInfoResponse> info() {
        var runtime = ManagementFactory.getRuntimeMXBean();
        return ApiEnvelope.ok(new GatewayInfoResponse(
                serviceName,
                DESCRIPTION,
                version,
                port,
                Runtime.version().toString(),
                SpringBootVersion.getVersion(),
                Instant.ofEpochMilli(runtime.getStartTime()),
                runtime.getUptime() / 1000,
                routes()));
    }

    private List<RouteInfo> routes() {
        return gatewayProperties.getRoutes().stream()
                .map(route -> new RouteInfo(
                        route.getId(),
                        // Shorthand "Path=/a/**,/b/**" được parser tách thành nhiều
                        // args — flatMap gom lại thành danh sách pattern phẳng.
                        route.getPredicates().stream()
                                .filter(p -> "Path".equals(p.getName()))
                                .flatMap(p -> p.getArgs().values().stream())
                                .toList(),
                        String.valueOf(route.getUri())))
                .toList();
    }
}
