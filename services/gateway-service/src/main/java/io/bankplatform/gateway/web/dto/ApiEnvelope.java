package io.bankplatform.gateway.web.dto;

import java.time.Instant;

/**
 * Bản sao HÌNH DẠNG của io.javalibs.web.ApiResponse. Gateway cố ý không dùng
 * javalibs (xem README của nó), nhưng frontend cần MỘT hình dạng envelope cho
 * cả sáu service — nên chép hình dạng, không chép thư viện.
 */
public record ApiEnvelope<T>(boolean success, T data, String message, Instant timestamp, String traceId) {

    public static <T> ApiEnvelope<T> ok(T data) {
        return new ApiEnvelope<>(true, data, null, Instant.now(), null);
    }
}
