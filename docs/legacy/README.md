# Bản SQL cũ — giữ làm tài liệu tham chiếu

Sáu file ở đây là thiết kế database **trước** khi có `docs/database/schema.sql`. Chúng **không còn được chạy** và không được sửa. Giữ lại vì mỗi file mang một bài học mà bản mới không thể hiện.

## Cái gì đã đổi

| Bản cũ | Bản mới | Vì sao |
|---|---|---|
| 3 schema (`auth`, `core_banking`, `notification`) | 5 schema (thêm `customer`, `product`) | Bản cũ dạy pattern hệ thống phân tán nhưng gần như không dạy nghiệp vụ ngân hàng: không có khách hàng, không có sản phẩm, không có lãi và phí |
| `ledger_entries` phẳng | `journal_entries` + `journal_lines` | Bảng phẳng không có phía đối ứng, không có GL, và không diễn tả nổi giao dịch ba dòng (chuyển tiền có thu phí) |
| Không có chart of accounts | `gl_accounts` | Không có sổ cái thì không có gì để đối chiếu số dư tài khoản khách hàng |
| `accounts.type = 'SYSTEM'` | bỏ | `journal_lines.account_id` NULL đã diễn tả "dòng này chỉ chạm GL nội bộ". `accounts` là sổ phụ khách hàng, `gl_accounts` là sổ cái |
| `accounts.owner_user_id` → `auth.users` | `accounts.primary_customer_id` → `customer.customers` | Chủ tài khoản là **khách hàng**, không phải tài khoản đăng nhập. Giữ cả hai đường là hai nguồn sự thật cho cùng một quan hệ |
| Số dư không lưu | `ledger_balance` + `hold_amount` + `available_balance` GENERATED | Không có khái niệm số dư khả dụng thì không giải thích được vì sao quẹt thẻ xong tiền "treo" |
| CHECK inline không tên | mọi CHECK đều `ck_<bảng>_<ý nghĩa>` | Chính `V3__outbox_and_external.sql` đã vấp lỗi này: phải `\d transfers` mới biết Postgres đặt tên constraint là gì |

## Bài học chỉ có ở đây

**`V4__ledger_partition.sql`** dựng partition bằng expand–swap trên bảng đang có dữ liệu: tạo bảng mới, copy sang, đổi tên, giữ sequence. `schema.sql` sinh partition ngay từ đầu nên không có bước này — nhưng ngoài đời bạn luôn phải partition một bảng *đã lớn*, và đó chính là kịch bản `V4` mô tả. Đọc nó khi cần làm việc đó thật.

**`V2__ownership_and_audit.sql`** minh họa expand–contract: chỉ THÊM cột ở bước một, để code cũ và code mới cùng chạy được trong lúc rollout; siết ràng buộc ở migration sau, chỉ khi đã backfill xong.

## Đừng chạy chúng

`compose.yaml` chỉ mount `docs/database/schema.sql`. Chạy các file ở đây lên cùng một database sẽ tạo ra bảng trùng tên với cấu trúc khác.
