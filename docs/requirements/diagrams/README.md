# Sơ đồ nghiệp vụ — sinh từ bộ đặc tả `docs/requirements/`

Mỗi chương đặc tả một thư mục, cấu trúc file thống nhất:

| File | Loại | Nội dung |
|---|---|---|
| `usecase.drawio` / `.png` | Use case diagram | Toàn bộ chức năng của nhóm: actor ↔ use case (mã khớp đặc tả), quan hệ «include» |
| `<MÃ>-activity.drawio` / `.png` | Activity diagram | Luồng chính + các nhánh thay thế/ngoại lệ của chức năng `<MÃ>` (bám mục *Luồng chính* / *Luồng thay thế* trong đặc tả) |
| `<MÃ>-sequence.drawio` / `.png` | Sequence diagram | Tương tác actor ↔ gateway ↔ service ↔ DB/Kafka/đối tác theo luồng chính; mũi tên đứt = bất đồng bộ (event), note vàng = bất biến quan trọng |

Phạm vi: 9 sơ đồ use case (nhóm A–I) + mỗi chức năng trong 64 chức năng một cặp activity + sequence.

## Quy ước đọc

- **Mã chức năng** trên sơ đồ (AUTH-02, TRF-02…) tra ngược về đặc tả cùng chương để xem quy tắc
  nghiệp vụ (BR-x), dữ liệu và trạng thái đầy đủ — sơ đồ vẽ LUỒNG, đặc tả giữ CHI TIẾT.
- Activity: hình thoi = quyết định; nhánh ghi điều kiện; node bo tròn = bắt đầu/kết thúc
  (một luồng có thể nhiều kết cục).
- Sequence: mũi tên liền = gọi đồng bộ; đứt xám = phản hồi; đứt có mũi tên hở = bất đồng bộ
  (outbox → Kafka → consumer); thứ tự participant trái → phải = hướng đi của lệnh.

## Sửa sơ đồ

File `.drawio` là nguồn (mở bằng draw.io desktop / diagrams.net); `.png` là bản render để xem
nhanh. Sửa `.drawio` xong export lại PNG:

```bash
drawio -x -f png --width 1600 -o <tên>.png <tên>.drawio
```

Khi đặc tả đổi luồng thì sửa sơ đồ tương ứng trong cùng commit — hai thứ lệch nhau thì đặc tả
là nguồn sự thật.
