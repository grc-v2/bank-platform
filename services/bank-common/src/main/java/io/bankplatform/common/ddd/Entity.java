package io.bankplatform.common.ddd;

import java.util.Objects;

/**
 * Lớp nền cho entity DDD: đối tượng được định danh bằng ID chứ không bằng
 * thuộc tính.
 *
 * <p>Hai entity bằng nhau khi cùng lớp cụ thể và cùng ID. Entity chưa có ID
 * (chưa persist) chỉ bằng chính nó — nếu không, mọi entity mới đều bằng nhau
 * và một {@code HashSet} chỉ giữ được đúng một cái.
 *
 * @param <ID> kiểu định danh
 */
public abstract class Entity<ID> {

    /** Định danh của entity; có thể {@code null} trước lần persist đầu tiên. */
    public abstract ID getId();

    @Override
    public boolean equals(Object other) {
        if (this == other) {
            return true;
        }
        if (other == null || getClass() != other.getClass()) {
            return false;
        }
        Entity<?> that = (Entity<?>) other;
        return getId() != null && Objects.equals(getId(), that.getId());
    }

    @Override
    public int hashCode() {
        // Hằng số theo lớp, KHÔNG theo id: Hibernate gán id lúc persist, mà
        // entity có thể đã nằm trong HashSet từ trước. hashCode đổi giữa chừng
        // là entity biến mất khỏi set trong im lặng.
        return getClass().hashCode();
    }

    @Override
    public String toString() {
        return getClass().getSimpleName() + "[id=" + getId() + "]";
    }
}
