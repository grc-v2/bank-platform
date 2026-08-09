package io.bankplatform.notification.web.dto;

/** Trạng thái một hạ tầng service phụ thuộc, đọc từ actuator HealthEndpoint. */
public record DependencyStatus(String name, String status) {
}
