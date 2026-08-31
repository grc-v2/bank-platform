package io.bankplatform.corebanking;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

/**
 * Không cần {@code @Import} hay {@code @ComponentScan} nào thêm: core-banking
 * chỉ dùng starter chính chủ Spring Boot (webmvc, validation, actuator,
 * springdoc, data-jpa, flyway) và bank-common, mỗi starter tự đăng ký
 * auto-configuration qua file
 * {@code META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports}.
 * Không còn thư viện ngoài (platform-libs) nào cần khai báo riêng.
 */
@SpringBootApplication
@ConfigurationPropertiesScan
public class CoreBankingApplication {

    public static void main(String[] args) {
        SpringApplication.run(CoreBankingApplication.class, args);
    }
}
