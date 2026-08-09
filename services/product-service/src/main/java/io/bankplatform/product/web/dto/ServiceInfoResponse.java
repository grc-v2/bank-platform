package io.bankplatform.product.web.dto;

import java.time.Instant;
import java.util.List;

/** Payload của GET /api/products/info — hợp đồng với frontend dashboard. */
public record ServiceInfoResponse(
        String serviceName,
        String description,
        String version,
        int port,
        String structureLevel,
        String dbSchema,
        String errorCodePrefix,
        String javaVersion,
        String springBootVersion,
        Instant startedAt,
        long uptimeSeconds,
        List<DependencyStatus> dependencies) {
}
