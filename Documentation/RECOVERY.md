# LanGuard — phục hồi chức năng DNS và đánh giá kiến trúc, 28/11/2026

## 1. Kết quả điều hành

Đã tái hiện **lỗi trong ứng dụng**, không cần giả định lỗi iOS/router: `name_reply()` của 0.5.0 kết thúc truy vấn ngay khi DNS-SD gửi `NoSuchRecord`. Với `ReturnIntermediates`, đây không phải tín hiệu kết thúc subscription. Một PTR hợp lệ đến sau bị bỏ mất. Test mới chạy trên mã cũ thực sự thất bại (`mode=6 outcome=3 events=1`); bản sửa nhận được PTR (`outcome=1 events=2`). Đây là sửa đường nhận tên thực, không phải đổi nhãn lỗi.

Không suy ra 16 truy vấn âm trên iPhone chắc chắn có PTR phía sau. Chưa có bằng chứng rằng iPhone mục tiêu đã nhận được tên/MAC sau sửa. Không quảng cáo hoàn tất nhận diện thiết bị hay tương đương NetCut.

Ứng viên là **0.5.1-beta.1 / build 6**, dành cho một lỗi đã tái hiện và thay đổi điều phối có giới hạn. Chỉ phát hành sau kiểm thử native/build/package. Kết quả CI và phát hành được bổ sung bên dưới khi hoàn tất.

## 2. Kiến trúc và quyết định

Giữ UIKit, Theos, ARM64/iOS12, package ID, APT, snapshot hai revision, kiểm tra generation/fingerprint, history theo mạng và quản lý gateway đã xác thực. Không viết lại toàn ứng dụng vì bằng chứng hiện tại không yêu cầu.

Thay **điều phối DNS sản xuất**: từ các worker chờ từng truy vấn sang vòng lặp sự kiện DNS-SD `poll`, tối đa 64 subscription đồng thời, một ngân sách chung tối đa 3 giây. Không tạo thêm thread. PTR hợp lệ kết thúc subscription đó, mở chỗ cho yêu cầu tiếp theo; kết quả âm giữ mở đến deadline/hủy/lỗi cuối. Mỗi yêu cầu có buffer, callback context, outcome và cleanup riêng.

Lý do phải thay điều phối: giữ âm mở đúng cách khiến pool 12 cũ có thể dùng cả 3 giây cho 12 địa chỉ, bỏ qua các địa chỉ sau. Test có 17 yêu cầu nay khởi động đủ cả 17. Giới hạn 64 là **giới hạn tài nguyên được thử**, không bảo đảm mọi mạng: fixture 130 âm chứng minh 64 được thử, 66 `notAttempted`, không biến phần chưa thử thành “không có tên”. Khi 130 yêu cầu có kết quả dương nhanh, tất cả 130 hoàn tất bằng cách tái sử dụng slot.

NBNS vẫn tối đa 12 worker, chạy trước vòng DNS, độc lập với âm DNS; tên NBNS không bị PTR thất bại ghi đè. Bonjour vẫn chạy trên main run loop, song song với phần identity. Không thay TCP/443 bằng quét nhiều port chỉ để tăng số đếm. Snapshot tiếp tục biểu diễn **địa chỉ/quan sát**, không xác nhận số thiết bị vật lý.

Không thay neighbor parser bằng API riêng/quyền root. Không thêm dependency/OUI database khi chưa có MAC hợp lệ; database không khắc phục được dữ liệu đầu vào thiếu. Kiến trúc evidence hiện tại có nguồn MAC, loại phản hồi, DNS outcome, service evidence, thời gian phản hồi và phạm vi scan; chưa phải inventory có xác thực hoặc hồ sơ đầy đủ thời gian/TTL cho từng thuộc tính.

## 3. Nghiên cứu độc lập và lựa chọn

Các nguồn chính được đối chiếu lại cho lần sửa này:

| Nguồn chính | Kết luận và quyết định |
|---|---|
| [Apple ReturnIntermediates](https://developer.apple.com/documentation/dnssd/kdnsserviceflagsreturnintermediates) | Negative callback không tự hủy query; có thể có positive về sau. Áp dụng sửa state machine. |
| [Apple mDNSResponder public header](https://github.com/apple-oss-distributions/mDNSResponder/blob/main/mDNSShared/dns_sd.h) và [bản lịch sử 878.260.1](https://github.com/apple-oss-distributions/mDNSResponder/blob/mDNSResponder-878.260.1/mDNSShared/dns_sd.h) | Dùng public QueryRecord/SockFD/ProcessResult/Deallocate, không dùng API mới riêng iOS13+. Header hiện hành không được dùng để suy ra availability; đối chiếu bản lịch sử và import API của gói. |
| [Apple DNS-SD client library](https://github.com/apple-oss-distributions/mDNSResponder/blob/main/Documents/dnssd-client-library.md) | Tận dụng daemon hệ thống, không nhúng một resolver mDNS khác hoặc tự bỏ qua cấu hình DNS mạng. |
| [RFC 6763](https://www.rfc-editor.org/rfc/rfc6763) | Service discovery cung cấp instance/service/host, không chứng minh thiết bị vật lý hay tên xác thực. Giữ service-only rows và chuẩn hóa regtype. |
| [Apple mDNSResponder LICENSE](https://github.com/apple-oss-distributions/mDNSResponder/blob/main/LICENSE) | Mã nguồn có thật, license theo từng file; chỉ sử dụng public API hệ thống, không nhập implementation bên ngoài vào repo MIT. |
| [getnameinfo cũ của Apple](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/getnameinfo.3.html) | Blocking resolver không có cancellation theo deadline của ứng dụng; không chuyển ngược sang thread không hủy được. |
| [XNU lịch sử route.h](https://github.com/apple-oss-distributions/xnu/blob/xnu-4903.241.1/bsd/net/route.h) | Giữ ABI wire parser đã kiểm thử; không dùng bit LLDATA làm điều kiện bắt buộc để nhận neighbor. |

Các đánh giá sản phẩm/library ở [PHASE5.md](PHASE5.md), [PHASE4.md](PHASE4.md) và [ENGINEERING_AUDIT.md](ENGINEERING_AUDIT.md) được giữ làm lịch sử. Không coi quảng cáo Fing/NetCut/WiFiKill/Harpy hay một repo Debian là bằng chứng có source tái sử dụng tương thích iOS12. Không nhập mã độc quyền, GPL hoặc cơ chế gây gián đoạn. Các sản phẩm đó không giải thích tốt hơn chuỗi callback đã tái hiện bằng chính mã LanGuard.

Nhánh `fix/dns-intermediate-negative-20261128` lúc bắt đầu trỏ `4fa1302f7d5f12c5631c641932add240b67ece09`, trùng main, **diff rỗng**, không chứa bản sửa sẵn. Các thay đổi sau là công việc mới được kiểm chứng, không nhận lại tuyên bố audit như kết quả đã hoàn tất.

## 4. Ma trận nguyên nhân

| Vấn đề | Nguyên nhân xác nhận / giả thuyết còn lại | Thí nghiệm và sửa | Giới hạn |
|---|---|---|---|
| DNS âm khoảng 32ms trên điện thoại | Xác nhận code kết thúc ngay âm; chưa xác nhận mạng thật có positive sau âm | Chuỗi âm→PTR và 3 âm→PTR thất bại trên code cũ, thành công sau sửa | Cần một nguồn PTR thật đã biết trên mạng của iPhone |
| Tên muộn bị mất | Deadline vẫn là giới hạn hợp lệ; âm sớm không được chấm dứt cửa sổ | Âm ngay, positive trễ 650ms: 400ms không nhận; 800/1500/3000ms nhận | Thời gian lab không phải tốc độ A8 |
| Coverage DNS giảm khi âm giữ mở | Pool12 và ngân sách toàn cục làm yêu cầu sau không chạy | Vòng sự kiện 64 slot; ground truth17 positive sau âm đều nhận | Trên64 âm có thể chưa thử phần còn lại; export thể hiện rõ |
| MAC bằng 0 | Nguồn điện thoại báo incomplete/placeholder; không đủ raw dump để gán nguyên nhân tuyệt đối | Chạy lại parser production với valid/private/placeholder/truncated/conflict/ABI fixtures | Không có bản sửa được chứng minh khôi phục MAC trên iPhone |
| Bonjour bằng 0 | Chưa có ground truth service trên mạng điện thoại; không đủ để kết luận app/network/OS | Giữ positive host publish/browse/resolve; sửa chuẩn hóa absolute regtype/case, thêm regression | Host không chứng minh iPhone nhận multicast |
| TCP refusal bị hiểu thành thiết bị thật | 443 response là bằng chứng địa chỉ, có thể qua intermediary | Giữ phân biệt accepted/refused/local/service-only, không tăng số thiết bị giả | Thiết bị im lặng vẫn có thể vắng; chưa đo recall mạng nhà |
| Manufacturer/type unknown | Không có MAC/service evidence tương ứng | Không bịa vendor/model; category chỉ là service hint | Không tuyên bố đã hoàn tất classifier/manufacturer |
| PTR sai định dạng hoặc callback không liên quan | Cần phân biệt loại/class/add/remove và RDATA framing | Bỏ qua CNAME/removal/wrong-class; malformed không chặn positive tiếp theo; từ chối trailing bytes | Không xác thực danh tính từ tên DNS |

## 5. Thay đổi người dùng thấy được

Khi nguồn DNS thực sự trả PTR hợp lệ sau một negative callback trong cửa sổ scan, tên đó nay có đường đi đến model và tên hiển thị. Đây là kết quả có điều kiện; không tạo PTR mà router không cung cấp.

Các lookup không còn phải chiếm một worker chờ kết quả. Với tối đa64 pending subscriptions, scan có thể thử đồng thời nhiều địa chỉ hơn pool12 cũ. Không thay đổi số địa chỉ chỉ để làm đẹp kết quả.

Device details diễn giải `noRecordReported` bằng câu “No PTR observed before the scan deadline”; trạng thái timeout, lỗi, tên nhận được và chưa thử được giải thích riêng. Raw enum vẫn dùng trong JSON để đối chiếu kỹ thuật.

## 6. Thực nghiệm, bao gồm kết quả âm

- **Red/green thực:** test production `resolver_tests.c` mới, code cũ thất bại mode6 trước PTR. Sau sửa nhận đủ sự kiện và tên `test.local`.
- 15 đường callback: positive; lỗi tạo API; deadline không có callback; lỗi ProcessResult; âm không có positive đến hết cửa sổ; malformed; âm→positive; nhiều âm→positive; lỗi API sau âm; malformed→positive; CNAME→PTR; removal→add; wrong-class→IN; fd lỗi; hủy sau âm. Mỗi subscription đã tạo được cleanup một lần; output lỗi không giữ tên cũ.
- Callback batch:17 âm→positive =17 resolved/17 cleanup/peak17;130 âm =64 thử/66 chưa thử/64 cleanup; hủy130 =130 cancelled/64 cleanup;130 positive =130 resolved/130 cleanup/peak64. Đây là fixture, không phải130 thiết bị.
- Timing transport có pipe/pthread: negative ngay rồi positive650ms; ma trận400/800/1500/3000. Không dùng kết quả này như đo mạng thật.
- Native macOS tiếp tục đăng ký PTR LocalOnly do test sở hữu; thêm17 subscriptions đồng thời tới **một** PTR đó. Không gọi đây là17 thiết bị.
- Native Bonjour đăng ký service riêng ngoài sáu type mặc định; kiểm tra đúng tên/type trong observations và so sánh1.5/3/5giây. Chưa đo phone multicast.
- Giữ pipeline thực với synthetic transport để kiểm tra revision, association service-only, copy-isolation, cancel/network switch và scan lặp. Không xem đây là benchmark mạng.
- Portable local suite:30 test methods pass, khoảng5giây; các C regression dùng ASan/UBSan. LeakSanitizer tắt theo giới hạn ptrace môi trường; cleanup của DNS refs được assert riêng.

## 7. Trước / sau 0.5.0

| Hạng mục | Trước | Sau, phần đã chứng minh |
|---|---|---|
| Discovery accuracy | 17 địa chỉ trên mẫu phone, chưa có physical inventory | Không chứng minh recall/precision toàn mạng thay đổi; giữ đếm bằng chứng |
| DNS callback | Negative kết thúc ngay | Âm không loại bỏ positive về sau |
| DNS scheduling |12 worker, global3s |64 event slots, global≤3s, không thêm thread; coverage fixture có giới hạn công khai |
| Bonjour |0 trên phone; host positive đã qua | Giữ host test, chuẩn hóa regtype absolute/case; phone chưa biết |
| Identity availability | Phone không có tên/MAC | Controlled PTR positive có đường nhận đúng; phone chưa xác minh |
| MAC/vendor |0 usable/unknown | Chưa có cải thiện physical được chứng minh |
| Category | Unknown khi không service | Không nâng confidence không căn cứ |
| Performance | Phone initial6.13s/final9.38s, CPU486.92ms | Không có số A8 mới; negative nay được giữ mở nên số DNS completion có thể tăng đúng tới budget |
| Memory | Phone resident14.97MiB | Tối đa64 refs; request buffer theo số địa chỉ≤1022, thêm khoảng0.3MiB C buffer ở trường hợp lớn; daemon allocation/peak phone chưa đo |
| Stability | Snapshot/generation guards hiện hữu | Giữ guards, thêm multi-event cancellation và bounded cleanup tests |
| UI |Raw noRecordReported |Diễn giải outcome rõ ràng |

## 8. Bằng chứng triển khai và review

Sửa trọng tâm: `Sources/Network/LGResolver.c`, `LGNetwork.h`, `LGScanner.m`. Sửa validation: `LGIdentity.c`, `LGServiceEvidence.m`. UI/export: `LGDeviceDetailsController.m`, `LGDiagnostics.m`. Tests: resolver sequences/timing/native/batch, identity, network model và scan pipeline. Release metadata/workflow giữ upgrade path và bản cũ.

Review kiến trúc: giữ phần đã có bằng chứng, thay riêng DNS scheduling. Review implementation: context không trỏ vào slot đã reuse khi ref chưa deallocate; không chia sẻ buffer giữa query; cleanup trên timeout/cancel/error; chặn callback sau positive hoàn tất. Review compatibility: chỉ public C DNS-SD/poll và API UIKit hiện có, không tăng minimum iOS. Review network: không gán âm API thành NXDOMAIN; refusal không thành physical identity. Review privacy: không export tên/IP/MAC/token; giới hạn và redaction giữ nguyên. Review adversarial: nhiều negative, malformed trước positive, removal/wrong type/class, fd/API failure, capacity và network-change. Đây là tự review theo từng góc nhìn, không giả làm nhóm reviewer độc lập.

## 9. Release gate

Chưa xác nhận phát hành tại thời điểm ghi phần này. Các kết quả CI, commit và checksum chính xác được ghi vào phụ lục sau khi thực sự hoàn tất. Không merge trước khi native tests/build/package qua gate. 0.5.0 giữ nguyên để rollback.

## 10. Những phần còn chưa giải quyết

- Không có nguồn neighbor/MAC hợp lệ mới trên iPhone. Không được phép suy diễn quyền UID501 là nguyên nhân duy nhất.
- Không có ground truth network inventory để đo FP/FN vật lý ở mạng nhà. Counter reconciliation không phải accuracy.
- Không có quyền vận hành iPhone từ môi trường này, nên không tự chứng minh PTR/Bonjour path trên A8.
- DNS không phải nguồn tên cho mọi thiết bị.64 âm có thể hết budget; `budgetNotStarted` cho biết phần chưa thử. Subnet IPv4 vẫn/22–/30; không bổ sung inventory IPv6.
- Chưa thêm adapter DHCP/router inventory mới. Adapter cần xác thực/đăng ký rõ ràng; không tự lấy dữ liệu quản trị.
- Identity model chưa trở thành hồ sơ đa thuộc tính có thời hạn xác thực đầy đủ; tên DNS/NBNS/Bonjour vẫn tự báo, dễ trùng/giả. User label không chứng minh identity.
- Không có số peak-memory/battery/phone performance mới. Không gọi suite host là nghiệm thu iPhone.
- Kill/Unkill không thuộc phần sửa này; giữ backend được cấp quyền và phân biệt readback với Internet thực.

## 11. Một lần xác minh trên iPhone

Sau khi ứng viên có URL/checksum được xác minh: nâng cấp bằng Sileo nguồn hiện có, giữ nguyên dữ liệu. Để thử dương thực sự, dùng một máy tính mình quản trị trong cùng LAN có **PTR đã được xác nhận bằng DNS hệ thống** hoặc một Bonjour service đang quảng bá. Chạy scan một lần khi máy tính đó bật, đợi revision2; đối chiếu IP/tên kỳ vọng, xuất **một JSON sanitized**. Nếu có thể chạy `dns-sd -B _languard-test._tcp local.` và publisher trên máy Mac, đó là kiểm chứng Bonjour riêng, không thay thế PTR.

Dự đoán kiểm chứng: DNS có PTR→`resolved` và tên hiển thị; chỉ negative→query được giữ đến deadline rồi `noRecordReported`; không callback→`applicationDeadline`; nguồn không đủ không được tạo MAC/vendor. Đối chiếu `started/cleaned/budgetNotStarted`, completion và revision. Báo lỗi nếu positive đã được xác nhận từ cùng mạng nhưng LanGuard vẫn không nhận. Chỉ bấm mở một iPhone bình thường không tạo PTR hoặc service, nên không phải positive control.
