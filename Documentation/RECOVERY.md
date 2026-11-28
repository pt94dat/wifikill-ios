# LanGuard — phục hồi chức năng DNS và đánh giá kiến trúc, 28/11/2026

## 1. Kết quả điều hành

Đã tái hiện **lỗi trong ứng dụng**, không cần giả định lỗi iOS/router: `name_reply()` của 0.5.0 kết thúc truy vấn ngay khi DNS-SD gửi `NoSuchRecord`. Với `ReturnIntermediates`, đây không phải tín hiệu kết thúc subscription. Một PTR hợp lệ đến sau bị bỏ mất. Test mới chạy trên mã cũ thực sự thất bại (`mode=6 outcome=3 events=1`); bản sửa nhận được PTR (`outcome=1 events=2`). Đây là sửa đường nhận tên thực, không phải đổi nhãn lỗi.

Không suy ra 16 truy vấn âm trên iPhone chắc chắn có PTR phía sau. Chưa có bằng chứng rằng iPhone mục tiêu đã nhận được tên/MAC sau sửa. Không quảng cáo hoàn tất nhận diện thiết bị hay tương đương NetCut.

Đã phát hành **0.5.1-beta.1 / build 6** sau gate native/build/package, dành cho lỗi đã tái hiện và thay đổi điều phối có giới hạn. Đã tải lại gói công khai, xác minh SHA-256 và source commit bên trong `Info.plist`. Nghiệm thu trên iPhone vẫn **pending**; không coi kết quả host là kết quả A8.

## 2. Kiến trúc và quyết định

Giữ UIKit, Theos, ARM64/iOS12, package ID, APT, snapshot hai revision, kiểm tra generation/fingerprint, history theo mạng và quản lý gateway đã xác thực. Không viết lại toàn ứng dụng vì bằng chứng hiện tại không yêu cầu.

Thay **điều phối DNS sản xuất**: từ các worker chờ từng truy vấn sang vòng lặp sự kiện DNS-SD `poll`, tối đa 64 subscription đồng thời, một ngân sách chung tối đa 3 giây. Không tạo thêm thread. PTR hợp lệ kết thúc subscription đó, mở chỗ cho yêu cầu tiếp theo; kết quả âm giữ mở đến deadline/hủy/lỗi cuối. Mỗi yêu cầu có buffer, callback context, outcome và cleanup riêng.

Lý do phải thay điều phối: giữ âm mở đúng cách khiến pool 12 cũ có thể dùng cả 3 giây cho 12 địa chỉ, bỏ qua các địa chỉ sau. Test có 17 yêu cầu nay khởi động đủ cả 17. Giới hạn 64 là **giới hạn tài nguyên được thử**, không bảo đảm mọi mạng: fixture 130 âm chứng minh 64 được thử, 66 `notAttempted`, không biến phần chưa thử thành “không có tên”. Khi 130 yêu cầu có kết quả dương nhanh, tất cả 130 hoàn tất bằng cách tái sử dụng slot.

NBNS vẫn tối đa 12 worker, chạy đồng thời với vòng DNS; join trước khi ghép kết quả để tránh data race và giữ thứ tự ưu tiên PTR; tên NBNS không bị PTR thất bại ghi đè. Bonjour vẫn chạy trên main run loop, song song với phần identity. Không thay TCP/443 bằng quét nhiều port chỉ để tăng số đếm. Snapshot tiếp tục biểu diễn **địa chỉ/quan sát**, không xác nhận số thiết bị vật lý.

Không thay neighbor parser bằng API riêng/quyền root. Không thêm dependency/OUI database khi chưa có MAC hợp lệ; database không khắc phục được dữ liệu đầu vào thiếu. Bổ sung `LGDevice.identityEvidence`: từng thuộc tính có value/source/confidence/observedAt/validity/networkScope/limitations; tối đa64 observations/device, upsert theo attribute+source. Thời điểm là lúc ứng dụng ghi nhận dữ liệu, không phải đồng hồ thiết bị từ xa; validity giới hạn snapshot, không bịa TTL DNS. Evidence không được lưu vào history hoặc sanitized export. Nguồn gồm TCP/local interface, neighbor, PTR, NBNS, DNS-SD, user label và inventory của adapter gateway đã xác thực sẵn có. Không biến dữ liệu đó thành identity vật lý đã xác thực.

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
- Portable local suite cuối:31 test methods pass,5.269giây; các C regression dùng ASan/UBSan. LeakSanitizer tắt theo giới hạn ptrace môi trường; cleanup của DNS refs được assert riêng.

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

## 9. Bằng chứng phát hành

| Hạng mục | Kết quả đã xác minh |
|---|---|
| Version / build |0.5.1-beta.1 /6|
| Source commit |[`f8b6cf1577f63fd32e51522eafd0dc23c75c78ab`](https://github.com/pt94dat/wifikill-ios/commit/f8b6cf1577f63fd32e51522eafd0dc23c75c78ab)|
| Gói |`com.pt94dat.wifikillios_0.5.1-beta.1_iphoneos-arm.deb`|
| Kích thước tải lại |80,182bytes|
| SHA-256 gói công khai |`9b0f45685191a488442165f06548b1368a9f72c67ceb3a58339b91f7f1e0bc31`|
| Tải trực tiếp |[Gói .deb](https://pt94dat.github.io/wifikill-ios/debs/com.pt94dat.wifikillios_0.5.1-beta.1_iphoneos-arm.deb)|
| Sileo source |https://pt94dat.github.io/wifikill-ios/|
| Gate nhánh kỹ thuật |[46093070208](https://github.com/pt94dat/wifikill-ios/actions/runs/46093070208): gateway-lab và build success; deploy/verify được skip đúng theo branch|
| Pipeline main |[46093584618](https://github.com/pt94dat/wifikill-ios/actions/runs/46093584618): gateway-lab/build/deploy/verify đều success|
| Package validation |ARM64 Mach-O, Debian iphoneos-arm, minimum12.0, same bundle/package ID, code page hashes/signature bounds và resources qua validator|
| Association tải lại |`CFBundleShortVersionString=0.5.1`, `CFBundleVersion=6`, `LGSourceCommit=f8b6cf1577f63fd32e51522eafd0dc23c75c78ab`|
| Giữ bản cũ |0.1/0.2/0.3/0.4/0.5.0 đều còn trong APT cùng0.5.1; SHA0.5.0 vẫn`bc3e7bb829508980f9852c82ce30c7d037370db240b92307897721a1eb69fd73`|
| Gateway bundle mới |`languard-gateway-0.5.1-beta.1.tar.gz`, SHA`564f62fe9fc2e7bcc4108718e402d421c3867f12a0d4e23857c625a192fb7f29`; backend không thay đổi chức năng|
| Gateway0.5.0 giữ nguyên |SHA`3d9f4a9abaa54b08417408821b8ffff7cef4b43501a376777b71379befd2e450` được đối chiếu lại|
| Physical iPhone |Chưa chạy bản mới; cần checklist mục11|

Không gán hash artifact preflight cho gói public: hai lần build có thể khác timestamp. Bảng trên dùng **gói public tải lại thực tế**. HTTPS/hash xác minh tính nhất quán; APT GPG signing vẫn chưa được bổ sung.

## 10. Những phần còn chưa giải quyết

- Không có nguồn neighbor/MAC hợp lệ mới trên iPhone. Không được phép suy diễn quyền UID501 là nguyên nhân duy nhất.
- Không có ground truth network inventory để đo FP/FN vật lý ở mạng nhà. Counter reconciliation không phải accuracy.
- Không có quyền vận hành iPhone từ môi trường này, nên không tự chứng minh PTR/Bonjour path trên A8.
- DNS không phải nguồn tên cho mọi thiết bị.64 âm có thể hết budget; `budgetNotStarted` cho biết phần chưa thử. Subnet IPv4 vẫn/22–/30; không bổ sung inventory IPv6.
- Chưa thêm adapter DHCP/router inventory mới. Adapter cần xác thực/đăng ký rõ ràng; không tự lấy dữ liệu quản trị.
- Identity evidence đã có provenance theo thuộc tính và scope snapshot, nhưng chưa có TTL riêng được lấy từ từng protocol hoặc danh tính vật lý được xác thực. Tên DNS/NBNS/Bonjour vẫn có thể trùng/giả; nhãn người dùng không chứng minh identity.
- Không có số peak-memory/battery/phone performance mới. Không gọi suite host là nghiệm thu iPhone.
- Kill/Unkill không thuộc phần sửa này; giữ backend được cấp quyền và phân biệt readback với Internet thực.

## 11. Một lần xác minh trên iPhone

**Phép thử đầu tiên không cần cấu hình router/máy tính:** sau nâng cấp, chạy scan đến cuối → Diagnostics → **Test local PTR** → chờ kết quả → Export một JSON. Kỳ vọng `positiveControl`: `setupCode=0`, `registered=1`, `outcome=1`, `matched=1`, `removed=1`, `cleaned=1`. Nếu thất bại, mã setup/query cho biết phép thử dừng ở registration hay resolution; không che lỗi hoặc dùng dữ liệu giả để báo pass. Đây là positive control thật dùng daemon DNS-SD trên chính iPhone, chỉ LocalOnly, không xác nhận tên hay khả năng multicast của LAN. Kết quả còn lại của scan giữ nguyên.

Ứng dụng đăng ký duy nhất một PTR thử LocalOnly có tên ngẫu nhiên, TTL10, đọc lại bằng **batch resolver sản xuất**, xóa record và deallocate connection/query; tổng thời gian chờ setup≤1s/query≤0.8s, ngoài main thread. Không gửi tên thật hoặc lấy MAC. Không thêm quyền/daemon root. JSON chỉ xuất mã trạng thái/thời gian, không xuất tên/IP fixture. Controlled tests gồm lỗi create/register/fd/callback/query, tên không khớp, lỗi remove và thành công; assert cleanup cả đường thất bại. Native host của bản cuối chạy cùng hàm production10 lần liên tiếp; kết quả ghi bên dưới. Test này cần thiết để phân biệt iPhone không chạy được public API với LAN không cung cấp PTR, không thay thế bản sửa chức năng DNS.

### Nếu cần kiểm tra thêm nguồn LAN có ground truth

Sau khi ứng viên có URL/checksum được xác minh: nâng cấp bằng Sileo nguồn hiện có, giữ nguyên dữ liệu. Để thử dương thực sự, dùng một máy tính mình quản trị trong cùng LAN có **PTR đã được xác nhận bằng DNS hệ thống** hoặc một Bonjour service đang quảng bá. Chạy scan một lần khi máy tính đó bật, đợi revision2; đối chiếu IP/tên kỳ vọng, xuất **một JSON sanitized**. Nếu có thể chạy `dns-sd -B _languard-test._tcp local.` và publisher trên máy Mac, đó là kiểm chứng Bonjour riêng, không thay thế PTR.

Dự đoán kiểm chứng: DNS có PTR→`resolved` và tên hiển thị; chỉ negative→query được giữ đến deadline rồi `noRecordReported`; không callback→`applicationDeadline`; nguồn không đủ không được tạo MAC/vendor. Đối chiếu `started/cleaned/budgetNotStarted`, completion và revision. Báo lỗi nếu positive đã được xác nhận từ cùng mạng nhưng LanGuard vẫn không nhận. Chỉ bấm mở một iPhone bình thường không tạo PTR hoặc service, nên không phải positive control.

### Sửa bổ sung trong review trước phát hành

Một lần chạy fixture batch phát hiện `live != 0` dù các lượt trước đã qua. Trace xác nhận deadline có thể vượt qua giữa hai lần đọc monotonic clock: vòng lặp thoát ở kiểm tra thứ hai, trước khi cleanup refs chưa finished. Đã đổi sang một trạng thái stop được chốt ở đầu vòng; deadline vượt giữa vòng sẽ quay lại cleanup thay vì break trực tiếp. Thêm200 chu kỳ deadline1ms, xen kẽ positive/negative, assert không còn ref sống. Đây là lỗi mới phát hiện ở ứng viên chưa phát hành; commit đầu tiên không được merge/publish. Không xem một lượt test pass là đủ để bỏ qua failure.

Bổ sung source: `LGDNSCheck.c/.h`, UI nút positive control và export whitelist có kiểm tra redaction. Bộ portable suite cuối thực tế31 test methods pass; số và thời gian CI ghi trong phụ lục.

### Provenance được nối vào sản phẩm

Màn hình **Sources and confidence** hiển thị từng giá trị, nguồn, confidence, thời điểm ghi nhận, validity và giới hạn; scope nội bộ là network key của scan, UI ghi “this snapshot network”. Không xuất network key chứa tên/BSSID vào JSON. Không điền manufacturer/model nếu thiếu bằng chứng. Các phép copy model giữ snapshot initial tách biệt; test mới kiểm tra đủ tám trường, upsert không nhân bản, copy isolation, scope và xóa giá trị rỗng. PTR và NBNS cùng được giữ như hai nguồn thay vì chỉ thấy một chuỗi hostname cuối cùng. Gateway inventory đang có được ghi nguồn authenticated, đồng thời nói rõ TLS/token xác thực service chứ không chứng minh endpoint vật lý.

Fixture batch cũng dùng130 IP/tên PTR **khác nhau**, kiểm tra chính xác từng output tương ứng input khi slot tái sử dụng; không chỉ kiểm tra tổng số callback. Pipeline synthetic so expected set với observed set và tên PTR/Bonjour gắn đúng địa chỉ, báo FP/FN của **observation fixture**, không phải precision/recall thiết bị vật lý trong mạng nhà.

### Failure native của positive control và sửa nguyên nhân

Run `46092560897` bị chặn trước build/release: hai lượt LocalOnly thành công nhưng lượt3 registration trả `-65548` (NameConflict). Test dùng lại cùng tên owner reverse sau khi remove; daemon có thể chưa hoàn tất xử lý remove trước registration tiếp theo. Không tăng sleep/timeout để che lỗi: mỗi lần production check nay có **owner reverse riêng** trong namespace LocalOnly, dùng địa chỉ loopback thử127/8, sequence atomic theo tiến trình và tên expected riêng. Không gửi probe tới địa chỉ đó. Deallocate vẫn bắt buộc. Native regression tăng lên10 lần liên tiếp và flush log trước assertion. Đây là sửa fixture/control lifecycle, không phải bằng chứng rằng đã chữa MAC hay LAN Bonjour trên iPhone.

Review lịch chạy cuối: không để NBNS và DNS nối tiếp nhau thành hai cửa sổ chờ. Bỏ wait trước DNS, join worker trước khi áp dụng kết quả PTR; tránh race khi cả hai nguồn điền hostname. Pipeline native dùng NBNS trễ250ms/DNS trễ650ms và cờ atomic để assert chúng thực sự chồng lấp, không dùng một ngưỡng thời gian mong manh làm bằng chứng. Đây là synthetic scheduling test, không phải tốc độ iPhone.

## Phụ lục — kết quả cuối của source đã phát hành

- Main native pipeline: initial5.6ms/final703.5ms trong **synthetic transports**, cùng scanID và detached revisions; NBNS250ms/DNS650ms được assert chồng lấp bằng cờ atomic. Đây không phải scan LAN hoặc benchmark iPhone.
- Ground truth observation fixture: expected3/observed3/FP0/FN0; PTR và Bonjour gắn đúng địa chỉ. Không suy ra accuracy mạng nhà.
- Host Bonjour:1.5/3/5s đều matched đúng service sở hữu; thời gian1568.9/3013.8/5048.8ms.
- Host batch DNS:17 subscriptions cùng một owned PTR đều resolved/cleaned. Fixture riêng dùng130 tên/IP khác nhau để kiểm tra association và refill slot.
- Production LocalOnly control:10/10 registered/matched/removed/cleaned; khoảng1.4–1.9ms trên runner macOS. Không suy ra thời gian iPhone.
-31 Python/C test methods pass trên main,46.675s (bao gồm compile/ASan); local31 pass5.269s. Thêm5 lượt bounded-batch riêng, tổng1000 chu kỳ deadline1ms không giữ lại ref.
-25 kiểm tra gateway namespace IPv4/IPv6 pass; bao gồm auth, mapping mismatch, bảo vệ management/gateway, hạn chế/khôi phục forwarded client flow, lease expiry sau crash và giữ firewall không liên quan. Không kiểm tra Internet công cộng hay thao tác quản lý từ iPhone.
- Các failure native/cleanup nêu phía trên được sửa **trước** khi merge/publish. Bản làm việc không được phát hành chỉ vì một lượt CI pass.
- Source chính đã merge main; nhánh`fix/dns-intermediate-negative-20261128` giữ source đã qua gate. Commit báo cáo sau phát hành dùng`[skip ci]`, không rebuild/ghi đè phiên bản immutable.

Danh sách31 file thay đổi so baseline, có thể xem [diff nguồn đầy đủ](https://github.com/pt94dat/wifikill-ios/compare/4fa1302f7d5f12c5631c641932add240b67ece09...f8b6cf1577f63fd32e51522eafd0dc23c75c78ab):

```text
.github/workflows/build-and-deploy.yml
Documentation/RECOVERY.md
README.md
Resources/Info.plist
Scripts/build_repository.py
Scripts/validate_package.py
Sources/Devices/LGDevice.h
Sources/Devices/LGDevice.m
Sources/Diagnostics/LGDiagnostics.m
Sources/Network/LGDNSCheck.c
Sources/Network/LGDNSCheck.h
Sources/Network/LGIdentity.c
Sources/Network/LGNetwork.h
Sources/Network/LGResolver.c
Sources/Network/LGScanner.m
Sources/Network/LGServiceEvidence.m
Sources/UI/LGDeviceDetailsController.m
Sources/UI/LGNetworkController.m
Tests/dnscheck_shim.h
Tests/dnscheck_tests.c
Tests/identity_tests.c
Tests/model_tests.m
Tests/network_model_tests.m
Tests/resolver_batch_tests.c
Tests/resolver_native_tests.c
Tests/resolver_tests.c
Tests/resolver_timing_tests.c
Tests/scan_pipeline_tests.m
Tests/test_network_engine.py
Website/index.html
control
```
