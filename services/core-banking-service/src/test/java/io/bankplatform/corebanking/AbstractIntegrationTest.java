package io.bankplatform.corebanking;

import io.javalibs.test.BaseIntegrationTest;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;

/**
 * Nạp docs/database/schema.sql (nguồn sự thật duy nhất — quyết định D5) vào
 * container Postgres singleton của javalibs-test, đúng MỘT lần mỗi JVM test.
 * Idempotent: schema của service đã tồn tại thì bỏ qua. Phải chạy trong static
 * block để xong TRƯỚC khi Spring context dựng (ddl-auto: validate cần bảng).
 */
public abstract class AbstractIntegrationTest extends BaseIntegrationTest {

    private static final String SCHEMA_NAME = "core_banking";

    static {
        try (Connection conn = DriverManager.getConnection(
                postgres().getJdbcUrl(), postgres().getUsername(), postgres().getPassword());
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
