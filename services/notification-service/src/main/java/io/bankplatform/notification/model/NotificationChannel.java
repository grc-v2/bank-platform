package io.bankplatform.notification.model;

/**
 * Kênh gửi thông báo — dùng CHUNG cho {@code notification_templates},
 * {@code notifications} và {@code user_notification_preferences}: cả ba bảng
 * lặp lại đúng một CHECK {@code IN ('TELEGRAM','EMAIL','WEBHOOK')}
 * (schema.sql khối [6]), nên chỉ một enum duy nhất, không tách theo bảng.
 */
public enum NotificationChannel {
    TELEGRAM,
    EMAIL,
    WEBHOOK
}
