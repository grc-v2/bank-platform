package io.bankplatform.common.ddd;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Ghim hợp đồng định danh của {@link Entity} — thứ 22 entity JPA của customer-service
 * và core-banking-service đã dựa vào sau khi chúng chuyển khỏi platform-libs (Task 4 và 5).
 * Ba tính chất dưới đây là lý do lớp này tồn tại; mất một cái là entity vào Set/Map
 * sai lặng lẽ.
 */
class EntityTest {

    static class Account extends Entity<Long> {
        private final Long id;
        Account(Long id) { this.id = id; }
        @Override public Long getId() { return id; }
    }

    static class Customer extends Entity<Long> {
        private final Long id;
        Customer(Long id) { this.id = id; }
        @Override public Long getId() { return id; }
    }

    @Test
    void haiEntityCungLopCungIdThiBangNhau() {
        assertThat(new Account(1L)).isEqualTo(new Account(1L));
    }

    @Test
    void idNullChiBangChinhNo() {
        Account chuaLuu = new Account(null);
        assertThat(chuaLuu).isEqualTo(chuaLuu);
        assertThat(chuaLuu).isNotEqualTo(new Account(null));
    }

    @Test
    void khacLopThiKhacNhauDuCungId() {
        assertThat(new Account(1L)).isNotEqualTo(new Customer(1L));
    }

    @Test
    void hashCodeOnDinhKhiIdDuocGanLucPersist() {
        // Hibernate gán id SAU khi entity đã nằm trong HashSet. hashCode phụ
        // thuộc id sẽ làm entity "mất tích" khỏi set đó.
        assertThat(new Account(null).hashCode()).isEqualTo(new Account(99L).hashCode());
    }

    @Test
    void toStringCoTenLopVaId() {
        assertThat(new Account(7L)).hasToString("Account[id=7]");
    }
}
