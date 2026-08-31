# product-service

Danh mục sản phẩm: lãi suất bậc thang, biểu phí, hạn mức, điều kiện mở, và **ánh xạ sản phẩm → tài khoản sổ cái**.

- **Cổng:** 8083
- **Schema:** `product` · **DB user:** `product_svc`
- **Mức cấu trúc: B (layered gọn).** Chiều phụ thuộc: `web → service → repository/model`.

## Vì sao Mức B

Service này gần như thuần đọc: 7 bảng, phần lớn truy vấn là "cho tôi biểu phí/lãi suất/hạn mức đang hiệu lực của sản phẩm X tại ngày Y". Không có aggregate nào có invariant phức tạp cần bảo vệ.

## Nguyên tắc dữ liệu bắt buộc giữ

Mọi bảng đều có `effective_from` / `effective_to`. **Đổi biểu phí là THÊM DÒNG, không sửa dòng cũ.** Sửa tại chỗ làm sao kê kỳ trước tính lại ra số khác — và đó là loại lỗi không ai phát hiện cho tới lúc khách hàng khiếu nại.

## Trách nhiệm không hiển nhiên

`product_gl_mappings` quyết định mỗi sản phẩm hạch toán vào GL nào. `core-banking-service` đọc bảng này qua API để biết ghi bút toán vào đâu. Đổi mapping của một sản phẩm đang có tài khoản chạy là việc phải có quy trình, không phải một lệnh UPDATE.

## Chạy local

```bash
docker compose up -d postgres redis
mvn -pl services/product-service -am spring-boot:run -Dspring-boot.run.profiles=local
```

## Migration

`db/migration/` rỗng, `spring.flyway.enabled=false`. Schema do `docs/database/schema.sql` khối `[4]` dựng.

## Persistence (Entity & Repository)

- **Mapping Mức B**: Entities đặt tại `io.bankplatform.product.model`, Repositories tại `io.bankplatform.product.repository`.
- **Aggregate và Collection con**: 5 bảng con (`product_interest_rates`, `product_fees`, `product_limits`, `product_eligibility_rules`, `product_gl_mappings`) chỉ giữ `Long productId` (KHÔNG map association 2 chiều hay `@OneToMany` collection trên `Product`). Lý do: Catalog sản phẩm chủ yếu đọc, các bảng con được truy vấn độc lập theo `product_id` + ngày hiệu lực ở phase nghiệp vụ.
- **Bảng bỏ qua**: `outbox` KHÔNG map (quyết định L1 — chưa có hạ tầng eventing nào. `javalibs-datahub` đã gỡ cùng platform-libs; sẽ quyết lại khi viết luồng publish event đầu tiên).
- **Validate schema**: Mọi entity được kiểm chứng qua `ddl-auto: validate` với schema PostgreSQL thật trong Testcontainers `ProductPersistenceMappingTest`.

