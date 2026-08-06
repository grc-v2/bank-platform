package io.javalibs.cqrs.autoconfigure;

import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Bảo vệ file AutoConfiguration.imports của module này.
 *
 * <p>Các test ApplicationContextRunner khác nạp lớp auto-configuration trực tiếp qua
 * {@code AutoConfigurations.of(...)}, nên chúng KHÔNG chạm tới file .imports. Nếu file
 * đó sai đường dẫn hoặc chứa tên lớp đã đổi, starter sẽ im lặng không kích hoạt và
 * không test nào khác bắt được. Test này đọc thẳng file trong src/main/resources
 * (thư mục làm việc của surefire là basedir của module) để chỉ kiểm đúng file của
 * chính module này, không lẫn file của Spring Boot trên classpath.
 */
class AutoConfigurationImportsTest {

    private static final Path IMPORTS = Path.of(
            "src/main/resources/META-INF/spring",
            "org.springframework.boot.autoconfigure.AutoConfiguration.imports");

    @Test
    void importsFileExistsAndIsNotEmpty() throws IOException {
        assertThat(IMPORTS).exists();
        assertThat(entries()).isNotEmpty();
    }

    @Test
    void everyListedClassIsLoadableAndAnnotated() throws IOException {
        for (String className : entries()) {
            Class<?> type = assertLoadable(className);
            assertThat(type.getAnnotations())
                    .as("%s phải mang @AutoConfiguration", className)
                    .anyMatch(a -> a.annotationType().getName()
                            .equals("org.springframework.boot.autoconfigure.AutoConfiguration"));
        }
    }

    private static Class<?> assertLoadable(String className) {
        try {
            return Class.forName(className, false,
                    AutoConfigurationImportsTest.class.getClassLoader());
        } catch (ClassNotFoundException e) {
            throw new AssertionError(
                    "File .imports liệt kê lớp không tồn tại: " + className, e);
        }
    }

    private static List<String> entries() throws IOException {
        return Files.readAllLines(IMPORTS).stream()
                .map(String::trim)
                .filter(line -> !line.isEmpty() && !line.startsWith("#"))
                .toList();
    }
}
