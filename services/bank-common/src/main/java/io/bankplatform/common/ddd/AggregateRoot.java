package io.bankplatform.common.ddd;

/**
 * Đánh dấu gốc aggregate: biên nhất quán của mô hình miền, và là entity duy
 * nhất mà repository được phép nạp/lưu trực tiếp.
 *
 * <p>Hiện lớp này KHÔNG thêm hành vi nào ngoài {@link Entity} — nó là một dấu
 * hiệu kiểu (type marker) để đọc code biết đâu là gốc aggregate, đâu là entity
 * con. Bản javalibs cũ có sẵn cơ chế domain event ({@code registerEvent},
 * {@code pullDomainEvents}) nhưng chưa dòng code nghiệp vụ nào trong repo dùng
 * tới, nên cố ý không chép sang. Thêm khi thật sự publish event đầu tiên —
 * xem docs/KNOWN-LIMITATIONS.md.
 *
 * @param <ID> kiểu định danh
 */
public abstract class AggregateRoot<ID> extends Entity<ID> {
}
