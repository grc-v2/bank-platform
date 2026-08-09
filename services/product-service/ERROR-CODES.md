# Mã lỗi — product-service

Prefix: `ERR-PROD-xxx`. Khai trong `io.bankplatform.product.web.ProductErrors` bằng `BusinessErrorCode.of(...)`; javalibs tự đưa vào OpenAPI docs.

Mã là **hợp đồng với frontend**: đã phát hành thì không đổi ý nghĩa, không tái sử dụng cho lỗi khác. Hết dùng thì đánh dấu deprecated, không xóa.

| Mã | HTTP | Ý nghĩa |
|---|---|---|
| _(chưa có)_ | | |
