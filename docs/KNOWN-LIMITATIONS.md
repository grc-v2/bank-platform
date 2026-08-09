# Giới hạn đã biết và việc còn lại

Những mục dưới đây được phát hiện trong quá trình review, đã được cân nhắc, và **cố ý
chưa xử lý** ở nền scaffolding này. Ghi lại để không ai phải phát hiện lại lần nữa —
và để không ai tưởng chúng là bỏ sót.

Mỗi mục ghi: hiện trạng, vì sao chưa xử, và điều kiện để xử.

## Database

### Chu trình GL dài không bị chặn

`gl_accounts.parent_gl_code` có `ck_gl_parent_not_self` chặn `A -> A`, nhưng **không**
chặn `A -> B -> A`. Đây là quyết định có ý thức của chủ dự án, không phải bỏ sót.

Hệ quả: mọi đoạn duyệt cây GL để cộng dồn số dư **phải** dùng `WITH RECURSIVE ... CYCLE`,
nếu không sẽ lặp vô hạn. Seed hiện tại không gắn parent cho dòng nào (`gl_with_parent = 0`)
nên rủi ro chỉ xuất hiện khi có người dựng cây GL thật.

### `assert_journal_balanced` chưa đối chiếu tiền tệ cho dòng GL-only

Trigger ép `journal_lines.currency` khớp `accounts.currency`, nhưng dòng có
`account_id IS NULL` (hạch toán thẳng vào GL) thì không có tài khoản để đối chiếu —
và `gl_accounts.currency` chưa được đưa vào phép kiểm.

Xử khi: bắt đầu dùng dòng GL-only thật. Chỗ sửa nằm ngay cạnh phép kiểm hiện có.

### `set_updated_at()` không có guard cho UPDATE không đổi gì

Một `UPDATE` không thay đổi giá trị nào vẫn bump `updated_at`, gây nhiễu cho đúng
loại consumer (CDC, đồng bộ tăng dần) mà cột này sinh ra để phục vụ.

Vì sao chưa xử: cách viết gọn `WHEN (OLD.* IS DISTINCT FROM NEW.*)` bị Postgres **từ chối
thẳng** trên `core_banking.accounts` — `ERROR: A whole-row reference is used and the table
contains generated columns` (bảng có `available_balance` là `GENERATED`). Guard bảy bảng
và bỏ bảng sổ cái sẽ tạo hai ngữ nghĩa `updated_at` khác nhau trong cùng một database,
tệ hơn là không guard cái nào. Liệt kê cột bằng tay thì cột thêm sau sẽ âm thầm rơi ra
ngoài guard, đúng trên bảng nhạy cảm nhất.

Xử khi: chấp nhận so sánh theo danh sách cột tường minh kèm quy trình cập nhật, hoặc
Postgres cho phép whole-row reference trên bảng có cột generated.

### `uq_journal_one_reversal` chặn luôn đảo một phần

Ràng buộc cho phép **một** bút toán đảo cho một bút toán gốc. Đảo một phần — hai bút
toán đảo nhỏ cho cùng một gốc — là nghiệp vụ có thật và hiện không làm được.

Đây là lựa chọn chính sách, không phải bất biến hiển nhiên: `reversal_of_entry_id` chỉ
là con trỏ, không mang số tiền, nên không có cách nào để DB biết tổng các phần đảo có
vượt gốc hay không. Muốn hỗ trợ đảo một phần thì phải thiết kế lại chỗ đó trước.

### Các ràng buộc `ex_*_overlap` không `DEFERRABLE`

`ex_fee_overlap`, `ex_limit_overlap`, `ex_glmap_overlap`, `ex_rate_overlap` đều kiểm ngay
tại câu lệnh. Nghĩa là khi đổi biểu giá phải **đóng dòng cũ trước, chèn dòng mới sau**;
làm ngược lại sẽ đụng dòng còn để ngỏ `effective_to IS NULL`.

Hợp đồng thứ tự này áp cho mọi code ghi vào bốn bảng đó.

## Service

### `/actuator/prometheus` trả 404 ở cả sáu service

Cả sáu `application.yml` đều khai `include: health,info,metrics,prometheus`, nhưng
endpoint `prometheus` **không tồn tại**: không service nào có Prometheus registry trên
classpath. `javalibs-observability-spring-boot-starter` chỉ kéo
`spring-boot-starter-actuator` và `micrometer-tracing-bridge-otel`;
`PrometheusMetricsExportAutoConfiguration` bị gate bởi
`@ConditionalOnClass(PrometheusMeterRegistry)`, lớp chỉ có trong
`micrometer-registry-prometheus`. `/actuator/metrics` thì hoạt động bình thường.

Mục khai được giữ lại vì vô hại và giữ được đối xứng giữa sáu service.

Xử bằng cách thêm `micrometer-registry-prometheus` vào
`javalibs-observability-spring-boot-starter` — **một chỗ sửa cho cả sáu service**, vì
`platform-libs/` nằm ngay trong repo này. Nhưng `platform-libs/` đang bị ràng buộc
"không sửa một dòng nào", nên đây là quyết định của con người chứ không phải việc
có thể tự làm.

### Dockerfile

Cả sáu Dockerfile hardcode `ARG JAR_FILE=target/<svc>-0.1.0-SNAPSHOT.jar`, nên một lệnh
`mvn versions:set` sẽ làm hỏng cả sáu image mà không báo gì. Chúng cũng chạy bằng `root`
(không có `USER`), và năm service nghiệp vụ sẽ chết lúc khởi động vì `JWT_SECRET` không
có giá trị mặc định còn `ENTRYPOINT` không đặt profile nào.

Đây là Dockerfile mức "đủ để build thử", chưa phải mức triển khai.

### `.env.sample` chưa được nối vào đâu

Không có gì trong repo đọc `.env`: `compose.yaml` không có `${}` substitution và không
khai `env_file`, còn Spring Boot không tự đọc `.env`. Làm theo dòng đầu file
("sao chép thành `.env` rồi chỉnh") hiện không có tác dụng gì.

Nó đang là **danh sách tham chiếu các biến cần export**, không phải file cấu hình sống.

## Quy ước còn lệch

- **Khoá ngoại không đặt tên tường minh.** 44/46 FK dùng tên Postgres tự sinh
  (`customer_identifications_customer_id_fkey`). Global Constraint chỉ yêu cầu đặt tên
  `CHECK` và `UNIQUE`. Tên tự sinh cho FK một cột là tất định (`<bảng>_<cột>_fkey`) nên
  không có rủi ro thật, chỉ lệch thẩm mỹ với phần còn lại của file.
- **Tên constraint lúc viết tắt lúc đầy đủ** — `ck_users_status` và `ck_transfers_status`
  dùng tên bảng đầy đủ, còn `ck_prefs_channel`, `ck_ident_type`, `ck_glmap_purpose` viết
  tắt. Mọi tên đều tường minh nên vô hại hôm nay. Đáng lưu ý: tên `uq_*` và `ex_*` trở
  thành **tên index toàn schema**, nên viết tắt làm tăng rủi ro trùng khi thêm bảng.

## CI

`.github/workflows/ci.yml` **chưa từng chạy thật** — repo chưa có remote. Workflow đã
được đọc kỹ và nhất quán với cách repo build (profile `with-libs` mặc định bật, JDK 21,
probe Postgres qua TCP), nhưng lần push đầu tiên vẫn là lần chạy đầu tiên.
