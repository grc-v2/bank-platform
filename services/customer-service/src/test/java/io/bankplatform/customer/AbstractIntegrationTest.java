package io.bankplatform.customer;

import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureTestRestTemplate;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.postgresql.PostgreSQLContainer;

import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;

/**
 * Nền cho mọi test full-context của customer-service.
 *
 * <p>Container Postgres theo mẫu singleton: khởi động MỘT lần cho cả JVM test
 * của module này, Ryuk của Testcontainers dọn khi JVM thoát. Mỗi module Maven
 * chạy một JVM surefire riêng nên container KHÔNG chia sẻ được giữa các module —
 * đó là lý do lớp này được chép vào từng service thay vì đóng thành test-jar
 * dùng chung.
 *
 * <p>Static block nạp docs/database/schema.sql (nguồn sự thật duy nhất — quyết
 * định D5) đúng một lần, idempotent, và phải xong TRƯỚC khi Spring context dựng
 * vì {@code ddl-auto: validate} cần bảng đã tồn tại.
 *
 * <p>Cần Docker daemon đang chạy (OrbStack).
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@ActiveProfiles("test")
public abstract class AbstractIntegrationTest {

    private static final String IMAGE = "postgres:16-alpine";
    private static final String SCHEMA_NAME = "customer";

    private static final PostgreSQLContainer POSTGRES;

    static {
        POSTGRES = new PostgreSQLContainer(IMAGE)
                .withDatabaseName("it_db")
                .withUsername("it_user")
                .withPassword("it_pass");
        POSTGRES.start();

        try (Connection conn = DriverManager.getConnection(
                POSTGRES.getJdbcUrl(), POSTGRES.getUsername(), POSTGRES.getPassword());
             Statement st = conn.createStatement()) {
            try (ResultSet rs = st.executeQuery(
                    "SELECT 1 FROM information_schema.schemata WHERE schema_name = '" + SCHEMA_NAME + "'")) {
                if (!rs.next()) {
                    st.execute(Files.readString(schemaSql()));
                }
            }
        } catch (Exception e) {
            throw new IllegalStateException("Không nạp được schema.sql vào container test", e);
        }
    }

    @DynamicPropertySource
    static void registerDatasourceProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
    }

    // Surefire chạy với cwd = thư mục module -> đi ngược lên tìm repo root,
    // để test vẫn chạy được khi IDE đặt cwd khác.
    private static Path schemaSql() {
        Path dir = Path.of("").toAbsolutePath();
        for (int i = 0; i < 6 && dir != null; i++, dir = dir.getParent()) {
            Path candidate = dir.resolve("docs/database/schema.sql");
            if (Files.exists(candidate)) {
                return candidate;
            }
        }
        throw new IllegalStateException("Không tìm thấy docs/database/schema.sql từ " + Path.of("").toAbsolutePath());
    }
}
