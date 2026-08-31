package io.bankplatform.common.web;

import java.time.Instant;

/**
 * Envelope chuẩn cho mọi phản hồi API, thành công lẫn thất bại.
 *
 * <p>Là {@code record} Java thuần — không annotation Spring, không annotation
 * Jackson. Jackson 3 của Boot 4.1 serialize record theo đúng thứ tự khai báo
 * component, nên thứ tự năm trường dưới đây LÀ hợp đồng với frontend và với
 * năm {@code ServiceInfoApiTest}. Đổi tên hay thứ tự là phá cả hai.
 *
 * <p>{@code traceId} hiện luôn {@code null}: chưa có correlation-id filter nào
 * sau khi gỡ module observability của platform-libs. Trường vẫn giữ để khi dựng filter không
 * phải đổi hợp đồng JSON.
 *
 * @param <T>       kiểu payload
 * @param success   {@code true} khi xử lý thành công
 * @param data      payload; {@code null} với phản hồi lỗi
 * @param message   thông điệp cho người đọc, có thể {@code null}
 * @param timestamp thời điểm server tạo phản hồi
 * @param traceId   định danh nối phản hồi với log server, có thể {@code null}
 */
public record ApiResponse<T>(
        boolean success,
        T data,
        String message,
        Instant timestamp,
        String traceId) {

    /** Phản hồi thành công, không kèm thông điệp. */
    public static <T> ApiResponse<T> ok(T data) {
        return new ApiResponse<>(true, data, null, Instant.now(), null);
    }

    /** Phản hồi thành công kèm thông điệp cho người đọc. */
    public static <T> ApiResponse<T> ok(T data, String message) {
        return new ApiResponse<>(true, data, message, Instant.now(), null);
    }

    /** Phản hồi lỗi, chỉ mang thông điệp. */
    public static <T> ApiResponse<T> error(String message) {
        return new ApiResponse<>(false, null, message, Instant.now(), null);
    }

    /** Phản hồi lỗi kèm traceId để người dùng báo lỗi có thứ đối chiếu log. */
    public static <T> ApiResponse<T> error(String message, String traceId) {
        return new ApiResponse<>(false, null, message, Instant.now(), traceId);
    }
}
