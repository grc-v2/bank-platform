# Mã lỗi — core-banking-service

Prefix: `ERR-CORE-xxx`. **Chưa có cơ chế mã lỗi nào trong code**: `BusinessErrorCode` là kiểu của javalibs (đã gỡ cùng platform-libs) và class `io.bankplatform.corebanking.api.CoreBankingErrors` chưa từng được viết. Bảng dưới là hợp đồng đặt trước — sẽ nối vào code khi dựng `@RestControllerAdvice` đầu tiên, xem docs/KNOWN-LIMITATIONS.md.

Mã là **hợp đồng với frontend**: đã phát hành thì không đổi ý nghĩa, không tái sử dụng. Hết dùng thì đánh dấu deprecated, không xóa.

| Mã | HTTP | Ý nghĩa |
|---|---|---|
| _(chưa có)_ | | |
