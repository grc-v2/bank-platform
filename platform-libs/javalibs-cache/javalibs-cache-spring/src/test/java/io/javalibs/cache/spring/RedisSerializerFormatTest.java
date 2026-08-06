package io.javalibs.cache.spring;

import org.junit.jupiter.api.Test;

import java.time.LocalDate;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Khoá hình dạng JSON của cache Redis, chụp trên dòng 1.0.x (Spring Boot 3.5.3, Jackson 2).
 *
 * <p>Dòng 1.0.x nhúng thuộc tính "@class" để entry deserialize được mà không cần cấu hình
 * kiểu theo từng cache. Nếu test này đỏ sau khi lên Jackson 3 ở Task 10, mọi entry đang
 * nằm trong Redis của service sẽ hỏng khi nâng — đó là thay đổi loại (b), phải ghi
 * CHANGELOG kèm hướng dẫn flush cache. Test này KHÔNG được sửa cho vừa hành vi mới.
 */
class RedisSerializerFormatTest {

    record Sample(String name, LocalDate day) {
    }

    @Test
    void embedsClassNameAndIsoDate() {
        byte[] json = RedisCacheConfigurations.jsonSerializer()
                .serialize(new Sample("tour", LocalDate.of(2026, 8, 2)));

        assertThat(new String(json))
                .contains("\"@class\"")
                .contains(Sample.class.getName())
                .contains("2026-08-02");
    }

    @Test
    void roundTripsBackToSameValue() {
        Sample original = new Sample("tour", LocalDate.of(2026, 8, 2));
        var serializer = RedisCacheConfigurations.jsonSerializer();

        Object restored = serializer.deserialize(serializer.serialize(original));

        assertThat(restored).isEqualTo(original);
    }
}
