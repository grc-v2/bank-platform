# 00 — Lộ trình thực hành lên Senior trên bank-platform

**Ngày:** 2026-08-30 · **Trạng thái:** bản thiết kế chờ review
**Nguồn tiêu chí & khung học:** repo `java-scalability-notes`
— [Lộ trình 24 tháng Mid → Senior](../../../Java/java-scalability-notes/senior-java-roadmap/00-tong-quan.md) (4 giai đoạn)
— Ma trận năng lực Senior Java 2026 (96 tiêu chí, 6 module — webapp DevPrep, `webapp/js/data/senior-java-matrix.js`)
**Nền triển khai:** repo này — [lộ trình nghiệp vụ 7 giai đoạn](../requirements/00-tong-quan-va-lo-trinh.md) + [lộ trình DevOps 8 giai đoạn](../devops/00-tong-quan-va-lo-trinh.md)

Tài liệu này là **nhạc trưởng**: nó không đặc tả lại nghiệp vụ (đã có `docs/requirements/`),
không chép lại kế hoạch DevOps từng tuần (đã có `docs/devops/00`), không định nghĩa lại tiêu
chí Senior (đã có roadmap 24 tháng + ma trận 96 tiêu chí). Nó trả lời đúng một câu hỏi:
**mỗi bài học của lộ trình Senior được thực hành Ở ĐÂU trên bank-platform, theo thứ tự nào,
và bằng chứng nghiệm thu là gì.**

---

## 1. Tư tưởng thiết kế

1. **bank-platform là phòng lab duy nhất.** Roadmap gốc yêu cầu 4 repo rời
   (`java-deep-dive`, `springboot-cicd-observability`, `production-ready-platform`,
   `distributed-patterns-demo`). Ở đây cả 4 gộp thành một hệ core banking có nghiệp vụ thật:
   tiền, bút toán kép, saga, outbox, EOD. Một repo có chuyện để kể mạnh hơn bốn repo demo —
   và mọi pattern (idempotency, outbox, resilience) xuất hiện vì *nghiệp vụ cần*, không phải
   vì giáo trình bảo làm.
2. **Ba nguồn giữ nguyên vai trò, không trộn.** Roadmap 24 tháng trả lời *"tuần này làm gì"*;
   ma trận 96 tiêu chí trả lời *"tôi đang ở mức nào"* (tick trong DevPrep, localStorage);
   tài liệu này trả lời *"làm điều đó ở đâu trên bank-platform"*.
3. **DoD cố định, thời gian co giãn** (nguyên tắc D13 của lộ trình DevOps). Ước lượng dưới đây
   tính theo **6–8 giờ/tuần**; nếu chỉ có 5 giờ, nhân 1.5 — không cắt DoD.
4. **Học gì neo ngay vào chức năng đó.** Mỗi lab của roadmap gốc được gắn vào một mã chức năng
   cụ thể (AUTH-xx, TRF-xx…). Lab không có chỗ neo = hoãn đến phase có chỗ neo.
5. **Bằng chứng trước, tuyên bố sau.** Mỗi mục hoàn thành phải có: số liệu trước/sau hoặc
   log/screenshot, một ghi chú Feynman, và tick tiêu chí ma trận tương ứng. Tất cả đổ về
   GitHub (`tanvx-training/bank-platform`) + blog.
6. **Không đọc trước quá một phase.**

## 2. Bản đồ ghép bốn lộ trình

| Phase | Thời gian ước lượng | Roadmap gốc | Nghiệp vụ bank-platform | DevOps bank-platform | Ma trận |
|---|---|---|---|---|---|
| **A — Java & Spring chuyên sâu trên nghiệp vụ thật** | tháng 1–9 | GĐ1 | GĐ1–4 (AUTH → CUST/KYC → PROD → GL/ACCT) | GĐ0 (khởi động) | M1 (phần lớn), M2, mầm M3/M4 |
| **B — DevOps nền tảng** | tháng 9–14 | GĐ2 + nửa GĐ3 | — (đóng băng feature mới, chỉ vá) | GĐ1–4 (container, CI/CD, K8s, observability) | M5 |
| **C — Hệ phân tán trên tiền thật** | tháng 14–22 | GĐ4 + nốt GĐ3 | GĐ5–6 (TRF saga, lãi/phí, EOD) | GĐ5–8 (GitOps, security, Ansible, DB ops) | M3, M4 trọn; chốt M1 |
| **D — Vận hành, làm cứng & hồ sơ** | tháng 22–26 | GĐ4 (đóng gói) | GĐ7 (audit, tra soát, giám sát) | capstone C1–C6 | chấm toàn ma trận |
| *(Mở rộng tùy chọn)* | sau DoD lõi | GĐ3 phần cloud | chương 10 chân trời mở rộng | — | M6 + các mục stretch |

Đường găng nghiệp vụ giữ nguyên: **AUTH → CUST → PROD → (GL + ACCT) → TRF → INT/FEE → OPS.**

---

## 3. Phase A — Java & Spring chuyên sâu trên nghiệp vụ thật (tháng 1–9)

Tương ứng roadmap gốc GĐ1 (6 tháng, 70% Java / 30% DevOps). Kéo dài hơn bản gốc vì thay lab
đồ chơi bằng code nghiệp vụ thật — đổi lại, cuối phase có luôn 4 giai đoạn nghiệp vụ chạy được.

### A0 — Khởi động (2 tuần)

- Chạy **DevOps GĐ0** theo đúng `docs/devops/00` §7: commit mốc WIP, đẩy repo lên GitHub,
  CI chạy thật và xanh (bỏ `-DskipTests` cho module service), nối `.env` vào compose, cài tool.
- Khi bắt tay vào auth-service: **cắt khối schema `auth` từ `docs/database/schema.sql` thành
  migration Flyway đầu tiên** và bật `spring.flyway.enabled=true` (README đã dặn) — từ đây
  mỗi service khởi động nghiệp vụ đều lặp nghi thức này.
- Dựng nếp ghi chú: ghi chú Feynman thuộc dự án để trong `docs/notes/` của repo này;
  lý thuyết chung để bên `java-scalability-notes`.

### A1 — auth-service: AUTH-01…09 (6–8 tuần)

Nghiệp vụ theo đặc tả [chương 01](../requirements/01-dinh-danh-truy-cap.md): đăng ký, đăng
nhập, JWT, refresh rotation, đổi mật khẩu, quản trị user/role, giám sát đăng nhập cơ bản,
xác thực + định tuyến tại gateway.

Lab Senior neo vào đây:

| Lab (từ roadmap gốc GĐ1) | Neo vào | Ma trận |
|---|---|---|
| Debug bean lifecycle tại `AbstractAutowireCapableBeanFactory#doCreateBean`, vẽ 3 pha | service xác thực của chính mình | sj-m2-t1-c1 |
| Chứng minh proxy CGLIB + self-invocation mất `@Transactional` | flow phát hành refresh token | sj-m2-t1, nền cho A2 |
| Vẽ + debug filter chain Spring Security, phân biệt authn/authz | cấu hình security auth + gateway | sj-m2-t4-c1…c3 |
| Mô hình hoá trạng thái bằng sealed interface + record, switch không default | `UserStatus`, vòng đời refresh token | sj-m1-t3-c1/c2 |
| JSpecify `@NullMarked` cho một package + kiểm tra tĩnh | `bank-common` | sj-m2-t2-c2 |
| Test đáng tin: `@WebMvcTest` + `@MockitoBean`, integration Testcontainers luồng login e2e | toàn service | sj-m2-t7-c2 |

**DoD** (khớp DoD GĐ1 nghiệp vụ): đăng ký → đăng nhập → gọi API bảo vệ qua gateway → refresh
→ logout; khóa user thì phiên chết. Cộng thêm: ghi chú Feynman "hành trình một bean" và
"filter chain của tôi".

### A2 — customer-service + notification tối thiểu: CUST-01…12, NOTI-01/02/03 (6–8 tuần)

Nghiệp vụ theo [chương 02](../requirements/02-khach-hang-kyc.md) + [08](../requirements/08-thong-bao.md):
CIF, KYC 3 mức, OTP, và lần xuất hiện đầu tiên của **outbox (OPS-01)** + **idempotent
consumer (NOTI-01)** — sớm hơn roadmap gốc (GĐ4) vì nghiệp vụ cần, đây là điểm mạnh của lab này.

Lab Senior neo vào đây:

| Lab | Neo vào | Ma trận |
|---|---|---|
| **Bộ 5 test transactional-traps** (self-invocation, checked exception không rollback, method không public, nuốt exception trong transaction lồng, REQUIRES_NEW) — "tài sản quý nhất repo" theo roadmap gốc | viết trên chính flow duyệt KYC + ghi outbox | sj-m2-t3-c1 |
| Outbox: insert nghiệp vụ + insert outbox cùng transaction; test tắt/bật poller mô phỏng crash | `customer.kyc.approved.v1` | sj-m3-t3-c2 |
| Idempotent consumer theo `event_id` (bảng processed_events); test gửi trùng 3 lần chỉ xử lý 1 | notification nhận event KYC | sj-m3-t4-c2 (mầm) |
| State machine hồ sơ: sealed + switch exhaustive | vòng đời CIF/KYC | sj-m1-t3-c2 |

**DoD**: mở CIF → nộp KYC → CSO duyệt → customer ACTIVE, event phát qua outbox, notification
nhận đúng một lần; 5 test traps xanh và giải thích được từng test; ghi chú Feynman
"dual-write và vì sao outbox tồn tại".

### A3 — product-service: PROD-01…07 (4–6 tuần)

Nghiệp vụ theo [chương 03](../requirements/03-san-pham.md): vòng đời sản phẩm, lãi suất bậc
thang, biểu phí, hạn mức, GL mapping — tất cả **hiệu lực theo thời gian (BR-G5)**.

Lab Senior neo vào đây:

| Lab | Neo vào | Ma trận |
|---|---|---|
| Dữ liệu temporal: đóng dòng cũ trước, chèn dòng mới sau, cùng transaction; test chồng lấn | bảng lãi suất/phí/hạn mức | củng cố sj-m2-t3 |
| API versioning built-in của Framework 7 | catalog API cho kênh | sj-m2-t5-c1 |
| HTTP Service Client (`@HttpExchange`) + so sánh RestClient/WebClient/HTTP interface | core-banking gọi catalog product | sj-m2-t5-c2/c3 |
| Persistence context, dirty checking, flush mode — quan sát qua SQL log | quản trị giá | sj-m2-t3-c1 |

**DoD**: seed 3 sản phẩm quản trị được qua API; đổi lãi suất đúng quy trình đóng-dòng-cũ-trước.

### A4 — core-banking: GL-01…03 + ACCT-01…08 (10–12 tuần, trái tim của phase)

Nghiệp vụ theo [chương 04](../requirements/04-so-cai-hach-toan.md) + [05](../requirements/05-tai-khoan.md):
chart of accounts, **posting engine bút toán kép**, mở tài khoản (eligibility thật từ A3),
số dư, hold, sao kê, đóng tài khoản.

Lab Senior neo vào đây — đây là nơi "2 case optimize" của roadmap gốc có số liệu thật:

| Lab | Neo vào | Ma trận |
|---|---|---|
| Race condition thật: 2 thread cùng rút một tài khoản → optimistic lock `version`; JMH so synchronized/Atomic/LongAdder trên counter đếm bút toán | posting engine + accounts | sj-m1-t4-c1 |
| Isolation levels bằng 2 terminal (non-repeatable read ở READ COMMITTED…) | bảng accounts/journal | sj-m2-t3-c1 |
| **Case optimize #1 — săn N+1**: bật đếm query (hibernate statistics/p6spy), đo trước → fix bằng `join fetch`/`@EntityGraph`/batch size → đo sau, viết tài liệu 1 trang | sao kê ACCT-08, tra cứu 360° CUST-12 | sj-m2-t3-c2/c4 |
| **Case optimize #2 — index & EXPLAIN**: `EXPLAIN (ANALYZE, BUFFERS)`, composite index đúng thứ tự cột, tự phá index (function trên cột, leading wildcard), trade-off ghi rõ | truy vấn journal_lines, partial index bảng hàng đợi (NFR-6) | sj-m4-t1-c1/c2 |
| **Partition sổ cái theo tháng** (OPS-04) + đo plan trước/sau trên bảng ≥ 1 triệu dòng sinh bằng `generate_series` | journal_entries/lines | sj-m4-t2-c1 |
| GC log dưới tải: `-Xlog:gc*` + bắn `hey` vào API chuyển tiền mặt, so `-Xmx` các mức, đọc pause; heap dump lab tìm leak (MAT, GC root) | core-banking chạy local | sj-m1-t4-c2/c4, sj-m1-t6-c3 |
| JMH benchmark posting engine (bút toán/giây), có baseline, đọc error margin | posting engine | sj-m1-t5-c1/c2 |

**DoD**: mở tài khoản kiểm eligibility thật → nộp tiền mặt (bút toán OPENING) → số dư đúng,
sao kê đúng, đóng tài khoản được; DB cưỡng chế bút toán cân Nợ/Có tại COMMIT (NFR-3);
2 tài liệu case optimize có số trước/sau.

### Nghiệm thu Phase A

- Chấm **checklist cuối GĐ1 roadmap gốc**, ánh xạ: "repo ≥ 10 chủ đề" → ghi chú + lab trong
  repo này; "bộ 5 test traps xanh" → A2; "2 case optimize" → A4; "debug source Spring ≥ 3
  lần" → A1; "integration test Testcontainers" → toàn phase; "≥ 8/10 câu tự kiểm tra" → giữ nguyên.
- **Mock interview Java Senior** (giữ nguyên nghi thức roadmap gốc: người thật hoặc ghi âm tự chấm).
- Mục "2 case optimize *tại công ty*": nếu xin được đề thật ở công ty thì làm song song —
  đó là bằng chứng thăng chức tốt nhất; không có thì 2 case trên bank-platform vẫn đạt DoD học tập.

---

## 4. Phase B — DevOps nền tảng (tháng 9–14)

Chạy đúng **DevOps GĐ1–4** theo `docs/devops/00` §7 — kế hoạch từng tuần đã có sẵn ở đó,
không chép lại. Phase này đóng băng feature nghiệp vụ mới (chỉ vá bug) để giữ nhịp 1 mạch học.

| DevOps GĐ | Nội dung chính | Khớp roadmap gốc | Ma trận |
|---|---|---|---|
| GĐ1 (t3–6) | Một Dockerfile multi-stage `ARG SERVICE`, layered jar, JVM trong cgroup (`MaxRAMPercentage`), drill OOMKilled/timezone/initdb | GĐ2 tháng 8 | sj-m5-t1-c1…c3 |
| GĐ2 (t7–10) | CI/CD: path filter monorepo, GHCR tag `sha-`, Trivy gate, SBOM, release theo tag, chạm Jenkins | GĐ2 tháng 9–10 | sj-m5-t4-c1 |
| GĐ3 (t11–16) | OrbStack K8s: YAML tay → Helm chart `bank-service` + umbrella, 3 probe, rolling update 0 lỗi dưới tải (readiness + graceful + preStop + PDB), 5 drill pod lỗi | GĐ3 tháng 13–15 | sj-m5-t2-c1…c3 |
| GĐ4 (t17–20) | kube-prometheus-stack, RED dashboard, alert nổ thật, log JSON + Loki, tracing OTel + Tempo, nối metric→trace→log | GĐ2 tháng 11 (nâng cấp lên K8s) | sj-m5-t3-c1…c4 |

Điểm mạnh so với kế hoạch DevOps gốc (viết khi chưa có code nghiệp vụ): sau Phase A, thứ được
deploy và quan trắc là **nghiệp vụ thật** — thêm ngay custom metric business (số bút toán/giây,
outbox lag, tỉ lệ fail OTP) thay vì chỉ `/info`.

Khác biệt có chủ đích so với roadmap gốc, kế thừa quyết định D1 của lộ trình DevOps:

- VPS + Nginx + certbot → **máy Ubuntu OrbStack + ingress + mkcert** (làm ở DevOps GĐ6, Phase C).
- AWS/Terraform/chứng chỉ → **hoãn sang mục Mở rộng** (mục 7). Kỹ năng lõi chuyển nguyên vẹn.

**Nghiệm thu Phase B**: DoD của từng DevOps GĐ (đã ghi trong `docs/devops/00`) + chấm checklist
GĐ2 roadmap gốc (image < 300 MB non-root Trivy sạch, dashboard RED + JVM + pool, 2 alert nổ
thật vào điện thoại, truy vết 1 request lỗi < 3 phút, blog #1 về hành trình tự động hoá).

---

## 5. Phase C — Hệ phân tán trên tiền thật (tháng 14–22)

Tương ứng roadmap gốc GĐ4 (messaging, caching, resilience, DDIA, design doc, system design),
chạy trên nghiệp vụ **GĐ5–6** — nơi các pattern này là yêu cầu bắt buộc chứ không phải demo.
Xen kẽ DevOps GĐ5–8 (GitOps, security, Ansible, DB ops) theo lịch của `docs/devops/00`.

### C1 — Chuyển tiền nội bộ + idempotency: TRF-01, TRF-04 (4 tuần)

- Chuyển nội bộ nguyên tử có phí (BR-G1…G4), **idempotency key** đúng BR-G3: gửi lại cùng key
  nhận đúng kết quả cũ — test chứng minh. Velocity check TRF-04 bằng Redis `INCR + EXPIRE`.
- Ma trận: sj-m3-t4-c2. Ghi chú Feynman "thiết kế idempotency key cho payment flow" (câu hỏi
  phỏng vấn số 8 của roadmap gốc — giờ có lab thật để kể).

### C2 — Saga liên ngân hàng + resilience: TRF-02/03/05 (6–8 tuần)

- Saga qua tài khoản trung gian GL 1900, partner giả lập có API confirm/reject + chỉnh được
  độ trễ/lỗi. Đủ **3 kết cục**: confirm / reject / timeout; job quét saga treo TRF-05.
- Lab resilience theo đúng thứ tự roadmap gốc: **timeout trước tiên** (demo "không timeout →
  thread pool cạn → endpoint không liên quan chết theo"), retry + backoff + jitter (và khi nào
  retry gây hại), circuit breaker CLOSED/OPEN/HALF_OPEN xem trên Grafana, bulkhead; Toxiproxy
  chen giữa core-banking và partner.
- Ma trận: sj-m3-t3-c1/c4, sj-m3-t4-c1/c3. Design doc #1 lấy chất liệu tại đây (mục C7).

### C3 — Kafka sâu trên notification: NOTI-03…06 (3–4 tuần)

- 3 thí nghiệm kinh điển: 2 instance cùng group chia partition + rebalance khi kill; khác
  group nhận đủ; ordering theo key (key = account_id). Retry topic + **DLT** với message
  poison; theo dõi **LAG** bằng `kafka-consumer-groups.sh` và đưa lên Grafana.
- Webhook NOTI-05: chặn **SSRF** bằng InetAddressFilter (cấm private range, link-local,
  metadata endpoint) + test chứng minh chặn URL nội bộ.
- Ma trận: sj-m3-t2-c1…c3, sj-m3-t5-c1/c2 (đây là "capstone M3 tương đương" trên bank-platform).

### C4 — Redis: cache, lock, virtual threads (4 tuần)

- Cache-aside cho catalog sản phẩm (PROD-07 — đọc nhiều ghi hiếm): TTL + invalidation khi đổi
  giá qua event `product.*`; benchmark k6 trước/sau; **lab stampede** (TTL ngắn + tải cao →
  răng cưa DB, fix bằng jitter TTL rồi bằng lock) — có ảnh trước/sau.
- **Distributed lock** cho job quét saga + EOD khi chạy 2 instance (không chạy trùng);
  trình bày tranh luận Redlock/fencing token.
- **Virtual threads** cho notification-service (gửi đa kênh IO-bound): bật cho tầng HTTP +
  dispatcher, load test trước/sau; ghi rõ giới hạn pinning trên JDK 21 (JEP 491 chỉ từ JDK 24).
- Ma trận: sj-m4-t3-c1…c3, sj-m4-t4-c1/c2, sj-m1-t1-c1…c3, sj-m1-t6-c1.

### C5 — Lãi, phí, EOD, replication: INT/FEE, GL-04/05, OPS-03 (6 tuần)

- EOD orchestration đúng thứ tự: nhả hold → quét saga → dự thu lãi → thu phí → snapshot →
  đối chiếu khớp 100%; **mọi job idempotent theo ngày** (NFR-7) — chạy lại không nhân đôi lãi.
- Lab replication: PostgreSQL master–replica local, cho sao kê/truy vấn lịch sử đọc từ
  replica; tự gây và xử lý bài toán đọc-sau-ghi (replication lag).
- Ma trận: sj-m4-t2-c2/c3.

### C6 — DevOps GĐ5–8 xen kẽ

GitOps ArgoCD + Sealed Secrets, security (Kyverno, PSS, NetworkPolicy trên kind), Ansible dựng
k3s trên máy Ubuntu OrbStack, backup/restore Postgres có bấm giờ — chạy theo `docs/devops/00`,
mục tiêu chốt capstone **C1–C6** của lộ trình DevOps.

### C7 — DDIA + design doc + system design (chạy nền suốt phase, ~1 buổi/tuần)

- **DDIA 6 tuần** theo lịch roadmap gốc; mục bắt buộc "hệ thống của tôi" trỏ thẳng vào
  bank-platform: ch.3 → sổ cái append-only là log; ch.5 → lab replica C5; ch.6 → partition
  sổ cái A4; ch.7 → isolation của posting engine; ch.11 → outbox/CDC.
- **Design doc #1 và #2** theo template Google (Context → Goals/Non-goals → ≥ 2 phương án →
  đề xuất → rollout → rủi ro). Đề thật từ repo: *outbox poller vs CDC Debezium*; *chiến lược
  cache catalog*; *xử lý saga treo & bồi hoàn*. Ưu tiên mang đề ở công ty nếu có (giá trị
  thăng chức cao hơn); bản bank-platform lưu vào `docs/superpowers/specs/` và xin review từ
  mentor/đồng nghiệp senior.
- **System design 8 đề** đúng nghi thức 45 phút + ghi âm; đề *payment flow* dùng chất liệu
  idempotency/saga thật của mình.

**Nghiệm thu Phase C**: DoD nghiệp vụ GĐ5–6 (chuyển nội bộ chống trùng lệnh; liên NH đủ 3 kết
cục; EOD chạy trọn và chạy lại được; đối chiếu khớp) + checklist GĐ4 roadmap gốc phần repo
(test outbox + idempotency xanh, circuit breaker trên Grafana, 6 ghi chú DDIA, 8 đề đã luyện).

---

## 6. Phase D — Vận hành, làm cứng & hồ sơ Senior (tháng 22–26)

- Nghiệp vụ **GĐ7**: audit đầy đủ thao tác ghi (BR-G8), giám sát đăng nhập AUTH-08, tra soát
  – hoàn trả TRF-06, dashboard tỉ lệ fail notification.
- **Game day tổng** trên full stack K8s: ≥ 4 sự cố kịch bản (outbox ùn, đối chiếu lệch, saga
  treo hàng loạt, memory leak) — chẩn đoán chỉ bằng dashboard/log/trace < 10 phút mỗi ca;
  mỗi ca một runbook + postmortem (nối kho `docs/devops/runbook|postmortem`).
- **2 buổi mock system design** mức Senior với đề chưa luyện; giữa 2 buổi luyện bù điểm yếu.
- **Đóng gói hồ sơ**: CV theo công thức "làm X, bằng cách Y, kết quả Z đo được" (nguyên liệu:
  case N+1, case index/partition, rolling update 0 lỗi, saga 3 kết cục, EOD idempotent, game
  day); pin repo; blog tổng kết (mục tiêu ≥ 4 bài tích luỹ từ B/C/D).
- **Chấm ma trận lần cuối** trong DevPrep: mục tiêu tick ≥ 80% tiêu chí mỗi module M1–M5
  (84 tiêu chí lõi), các mục stretch/M6 tính riêng theo mục 7.
- Nước đi cuối theo roadmap gốc: đề xuất thăng chức nội bộ với bộ bằng chứng, hoặc ra thị
  trường với hồ sơ.

---

## 7. Mở rộng tùy chọn (sau DoD lõi — không chặn Phase nào)

| Mục | Nội dung | Nguồn gốc |
|---|---|---|
| Cloud + Terraform | 2–4 tuần: IAM/VPC/EKS tay rồi Terraform hoá, ngân sách ~30–50 USD, budget alert trước tiên | roadmap gốc GĐ3; hoãn theo quyết định D1 DevOps |
| Chứng chỉ | CKA (tài liệu sẵn trong `java-scalability-notes/CKA`) hoặc AWS SAA — quyết khi chọn hướng | roadmap gốc GĐ3 |
| Nâng JDK 25 | Structured concurrency + scoped values (fan-out tra cứu 360°: gọi song song account + KYC + risk, fail-fast) — cần preview flag; kèm JEP 491 hết pinning | sj-m1-t2 (3 tiêu chí) |
| GraalVM native | Thử với gateway-service (ít dependency nhất), đo startup/RSS/throughput, ghi trade-off | sj-m2-t6, sj-m2-t7-c3 |
| gRPC nội bộ | Thí điểm core-banking ↔ customer bằng Spring gRPC, so với REST hiện có | sj-m3-t1-c2 |
| M6 — GenAI | Spring AI 2.x + pgvector: "trợ lý vận hành" RAG trên `docs/requirements` + runbook, có trích nguồn; MCP server phơi tra cứu số dư đọc-only | sj-m6 (12 tiêu chí) |

## 8. Nhịp làm việc & nghi thức

- **Tuần**: 1h đọc phần bản chất → 3–5h làm → 30' ghi bằng chứng vào docs → 30' tick ma trận
  + trả lời câu "vì sao" thành tiếng.
- **Review quý** (bắt buộc, 2h — nghi thức của roadmap gốc file 00): chấm checklist phase
  hiện tại; cập nhật CV bằng con số mới; dọn README; viết đoạn "quý này tôi làm được gì mà
  3 tháng trước chưa làm được"; 2 quý liên tiếp trượt → thu hẹp phạm vi (cắt mục Mở rộng
  trước, không cắt DoD lõi).
- **Mock interview**: cuối Phase A (Java) và Phase D (system design) — không bỏ.
- **Blog**: tối thiểu 1 bài/phase từ B trở đi (B: tự động hoá; C: saga/outbox trên core
  banking; D: tổng kết hành trình).

## 9. Phủ ma trận năng lực — tra nhanh

| Module (số tiêu chí) | Phủ ở | Ghi chú |
|---|---|---|
| M1 Java Core & JVM (18) | A4 (GC, JMM, JMH, heap dump) + C4 (virtual threads) | sj-m1-t2 (3 tiêu chí) cần JDK 25 → mục 7; sj-m1-t5-c3 (async-profiler/JFR) làm trong game day D |
| M2 Spring Boot 4.1 (21) | A1–A4 gần trọn | sj-m2-t6 + m2-t7-c3 (native) → mục 7; sj-m2-t7-c1 (custom starter) → tách starter outbox/idempotency dùng chung 2 service ở cuối C |
| M3 Distributed (18) | A2 (outbox mầm) + C1–C3 trọn | sj-m3-t1-c2 (gRPC) → mục 7 |
| M4 DB & Redis (13) | A4 (index, partition) + C4/C5 (cache, lock, replica) | đủ trong lõi |
| M5 Cloud-Native & DevOps (14) | B trọn + C6 | đủ trong lõi |
| M6 GenAI (12) | mục 7 | ngoài phạm vi core banking, làm sau DoD |

Tổng lõi bắt buộc: **84 tiêu chí M1–M5**, trong đó 9 tiêu chí đánh dấu stretch (JDK 25,
native, gRPC) được phép dời sang mục 7 mà không tính trượt.

## 10. Câu hỏi mở — chốt khi đến nơi

1. Nâng JDK 21 → 25 cho toàn repo hay chỉ lab riêng? (platform-libs đã gỡ khỏi repo
   2026-09-01 nên không còn ràng buộc tương thích đó; quyết ở đầu Phase C.)
2. Chứng chỉ CKA hay SAA hay không thi? (quyết cuối Phase B, theo hướng nghiệp muốn rẽ.)
3. Design doc #1 lấy đề công ty hay đề bank-platform? (quyết khi vào C7, ưu tiên công ty.)
4. Custom starter outbox/idempotency tách ở cuối Phase C hay để Phase D? (khi cả customer
   lẫn core-banking cùng lặp pattern thì tách — quy tắc "rule of three" trừ một.)
