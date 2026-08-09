package io.bankplatform.gateway.web.dto;

import java.time.Instant;
import java.util.List;

/**
 * Payload của GET /api/gateway/info. Khác 5 service nghiệp vụ: không schema,
 * không mã lỗi, không dependencies — thay bằng bảng route đang chạy.
 */
public record GatewayInfoResponse(
        String serviceName,
        String description,
        String version,
        int port,
        String javaVersion,
        String springBootVersion,
        Instant startedAt,
        long uptimeSeconds,
        List<RouteInfo> routes) {
}
