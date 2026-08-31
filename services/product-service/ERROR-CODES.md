# Mã lỗi — product-service

Prefix: `ERR-PROD-xxx`. **Chưa có cơ chế mã lỗi nào trong code**: `BusinessErrorCode` là kiểu của javalibs (đã gỡ cùng platform-libs) và class `io.bankplatform.product.web.ProductErrors` chưa từng được viết. Bảng dưới là hợp đồng đặt trước — sẽ nối vào code khi dựng `@RestControllerAdvice` đầu tiên, xem docs/KNOWN-LIMITATIONS.md.

Mã là **hợp đồng với frontend**: đã phát hành thì không đổi ý nghĩa, không tái sử dụng cho lỗi khác. Hết dùng thì đánh dấu deprecated, không xóa.

| Mã | HTTP | Ý nghĩa |
|---|---|---|
| _(chưa có)_ | | |
