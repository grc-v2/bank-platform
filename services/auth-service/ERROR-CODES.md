# Mã lỗi — auth-service

Prefix: `ERR-AUTH-xxx`. Mỗi mã khai một lần trong class `io.bankplatform.auth.web.AuthErrors` bằng `BusinessErrorCode.of(...)`, và javalibs tự đưa chúng vào OpenAPI docs.

Mã là **hợp đồng với frontend**: đã phát hành thì không đổi ý nghĩa, không tái sử dụng cho lỗi khác. Hết ý nghĩa thì đánh dấu deprecated, không xóa.

| Mã | HTTP | Ý nghĩa |
|---|---|---|
| _(chưa có)_ | | |
