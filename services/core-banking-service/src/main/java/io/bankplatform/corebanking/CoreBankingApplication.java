package io.bankplatform.corebanking;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Không cần {@code @Import} hay {@code @ComponentScan} cho javalibs:
 * mỗi starter tự đăng ký auto-configuration.
 */
@SpringBootApplication
public class CoreBankingApplication {

    public static void main(String[] args) {
        SpringApplication.run(CoreBankingApplication.class, args);
    }
}
