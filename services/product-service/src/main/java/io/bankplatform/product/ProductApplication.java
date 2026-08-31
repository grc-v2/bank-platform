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
 */
@SpringBootApplication
@EnableCaching
@ConfigurationPropertiesScan
public class ProductApplication {

    public static void main(String[] args) {
        SpringApplication.run(ProductApplication.class, args);
    }
}
