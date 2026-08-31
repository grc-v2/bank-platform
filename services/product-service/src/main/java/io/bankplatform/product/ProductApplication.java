package io.bankplatform.product;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;
import org.springframework.cache.annotation.EnableCaching;

/**
 * {@code @EnableCaching} để cache catalog sản phẩm. Cache backend là Redis:
 * spring-boot-starter-cache + spring-boot-starter-data-redis đủ để Boot tự
 * chọn RedisCacheManager. Chưa có @Cacheable nào — bật sẵn để khi thêm không
 * phải đụng lớp khởi động.
 *
 * <p><b>Cảnh báo trước khi thêm {@code @Cacheable} đầu tiên:</b> cache manager
 * mặc định của Boot khác ngữ nghĩa với bản javalibs cũ — giá trị cache phải
 * {@code implements Serializable} (JdkSerializationRedisSerializer) và không
 * có TTL mặc định (sẽ không bao giờ hết hạn trừ khi tự đặt
 * {@code spring.cache.redis.time-to-live}). Xem mục "Cache của
 * product-service đổi ngữ nghĩa, chưa lộ ra" trong docs/KNOWN-LIMITATIONS.md.</p>
 */
@SpringBootApplication
@EnableCaching
@ConfigurationPropertiesScan
public class ProductApplication {

    public static void main(String[] args) {
        SpringApplication.run(ProductApplication.class, args);
    }
}
