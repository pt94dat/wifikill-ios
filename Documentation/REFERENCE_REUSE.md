# LanGuard — phát triển từ source tham chiếu và tái sử dụng,28/11/2026

## 1. APK thực sự đã truy cập

Đã mở file người dùng gửi, đọc ZIP/Android binary XML và ELF header, không thực thi mã APK. SHA-256:`1740186ff063ae5e1eca007521d2d26b6ccf02b4ee470b3a3925be0ffa729006`, trùng artifact đã dùng trước. Metadata: package`wifi.killl.com`, version1.1.2/code17, minSDK15/target26;7 thư viện native ABI, bản64bit ARM là **ELF AArch64**, không phải Mach-O. Manifest có các quyền mạng/Wi-Fi/location và thành phần SDK ngoài; layout có scanner/list/device/router details và diagnostics.

Đây là bằng chứng tĩnh về cấu trúc, không phải bằng chứng Kill/Unkill hoặc nhận diện MAC đã chạy. Chưa xác minh nhà phát hành gốc từ chữ “WiFiKill” hay nguồn APKPure. Không có Android runtime/ground-truth benchmark được chạy trong lần này; không điền thời gian quét hoặc xác suất thành công của APK. Không sao chép binary, mã độc quyền, tài nguyên thương hiệu hoặc cơ chế can thiệp kết nối.

## 2. Ma trận parity có bằng chứng

| Chức năng | APK được xác minh | LanGuard0.5.1 | Triển khai được chọn / gate |
|---|---|---|---|
| Nhận mạng | Manifest/network UI tĩnh; runtime chưa đo | Interface/gateway/subnet tự phát hiện | Giữ public Darwin APIs, không hardcode gateway |
| Discovery | Scanner/list layout; runtime chưa đo | TCP443 + Bonjour + neighbor/history | Tái sử dụng SimplePing, ICMP độc lập với TCP; host echo đối chứng |
| IP | Có UI thiết bị; giá trị runtime chưa kiểm tra | Có địa chỉ và scope | Giữ subnet/generation guards |
| MAC | Không tuyên bố thành công từ layout |0 usable neighbor trên iPhone | Inventory neighbor/DHCP đã xác thực; lease không đồng nghĩa online |
| Tên | UI tĩnh; runtime chưa kiểm tra | Bonjour32services/17addresses, NBNS2 trong mẫu phone | Giữ pipeline, thêm metadata TXT do publisher tự khai |
| Manufacturer/model | Chưa kiểm chứng runtime | Chưa có assignment lookup | Chỉ hiển thị TXT rõ ràng, đánh dấu tự khai; không đoán hãng từ model |
| Classification | Không suy ra từ quảng cáo | Service hint | Giữ mức suy luận service, không khẳng định phần cứng |
| Tốc độ | Không có benchmark APK | Phone6.17s initial/9.51s final | Không tuyên bố tăng tốc A8 nếu chưa đo |
| Device list | Có layout list/details | Native UIKit hoạt động | Hiển thị MAC khi nguồn hợp lệ có, nguồn/claim trong details |
| Kill/Unkill | Không chạy kiểm chứng APK | Có điều kiện gateway được cấp quyền | Giữ current-neighbor verification, timed leases, restore; DHCP-only không cấp quyền Kill |
| Enrollment | Không suy ra cơ chế từ APK | Gõ HTTPS endpoint/token | Import file quản trị cấp, rồi review/Save; không tự tin quảng cáo DNS-SD |

## 3. Nghiên cứu source và chiến lược reuse

| Source chính / revision | License / tương thích đã đọc | Source-level finding | Quyết định |
|---|---|---|---|
|[mavris/MMLanScan](https://github.com/mavris/MMLanScan),`b93b4e4515dbb07eeb2d70e72fe9da106a5e02f3`|MIT; podspec3.0.0, targetiOS8; ObjC|MacFinder có read AF_ROUTE và offset cố định; chínhREADME cảnh báo MAC/brand từiOS11. PingOperation giữ worker/runloop, timeout1s.|Không thay toàn engine bằng thuật toán phụ thuộc MAC. Reuse **SimplePing** có license Apple riêng, giữ cả noticesMIT/Apple.|
|SimplePing trong source trên; [Apple sample archive](https://developer.apple.com/library/archive/samplecode/SimplePing/Introduction/Intro.html)|Apple sample-code redistribution terms, nguyên văn trong source và appresources; APIs lâu đời|SOCK_DGRAM/IPPROTO_ICMP, CFSocket/runloop, checksum/identifier/sequence validation, stop/deallocate. Numeric hostAddress tránh DNS blocking.|Vendor implementation; chỉ sửa header platform condition/import. Wrapper riêng ghép với TCP, không tự viết lại ICMP protocol.|
|[mediaios/net-diagnosis](https://github.com/mediaios/net-diagnosis),`90dc2b5b54ad79f5b6cd86668477160aa8400d8e`|MIT; podspec1.0.12; deployment targets trong podspec bị comment, không lấy đó làm chứng cứ OS minimum|Có C++PNSamplePing dùng datagramICMP và nhiều modules/traceroute; không có bằng chứng khắc phục MACiOS12 từ source đã đọc.|Không mang toànSDK/C++/diagnostics ngoài mục tiêu vào app khi SimplePing đã đủ đúng nhiệm vụ.|
|[Apple DNS-SD guide](https://developer.apple.com/library/archive/documentation/Networking/Conceptual/dns_discovery_api/), public NSNetService API|API hệ thống, không thêm thư viện|Có sẵn parser TXT dictionary và service lifecycle;0.5.1 đã có bằng chứng phone.|Reuse Foundation TXT APIs, không tự viết wire parserTXT.|
|[dnsmasq tác giả — lease format](https://lists.thekelleys.org.uk/pipermail/dnsmasq-discuss/2008q3/002457.html)|Dùng format tài liệu, không copy implementationGPL|expiry/MAC/IP/hostname/client-id; lease là allocation, không liveness.|Adapter mỏng dùng Pythonstdlib/ipaddress; không viết DHCPserver/client. Lab reuse dnsmasq + BusyBoxudhcpc.|
|[BusyBox documentation](https://www.busybox.net/BusyBox.html),[Ubuntu udhcpc](https://packages.ubuntu.com/noble/udhcpc)|Dùng binaries trong labVM; không bundle vàoapp|Có client DHCP đã tồn tại, script hook tùy chọn.|Dùng transaction thật trong namespace, script`/bin/true` không sửa DNS/routes host.|

Các đánh giá NetCut/Fing/Network Analyzer và source lịch sử trong báo cáo trước vẫn là tham chiếu; không xem mô tả sản phẩm như license/source code tái sử dụng. MMLanScan có datasetOUI nhưng provenance/quyền datasetIEEE chưa được kiểm chứng riêng; không giả định licenseMIT code tự giải quyết license dữ liệu và không bundle nó để che việc phone thiếuMAC.

## 4. Nguyên nhân và kiến trúc được chọn

- TCP443 là bằng chứng hẹp: thiết bị không nhận TCP đó có thể vẫn trả echo. Bổ sung ICMP đã được triển khai bởi Apple, không thay đường Bonjour đang có bằng chứng.
- API neighbor phone trả incomplete/placeholder; parser fixtures vẫn nhận unicast/privateMAC hợp lệ. Không gán UID501 là nguyên nhân duy nhất và không dùng MacFinder offset cũ làm privacy bypass.
- Có nguồn MAC được cấp quyền khác: lease do DHCP server quản trị ghi và current neighbor của gateway. Nguồn này cần enrollment thật, không tự mở quyền router.
- Metadata dịch vụ có thể bị mất nếu chỉ nhìn IP/hostname. Dùng NSNetService TXT parser, giữ claim model/manufacturer cùng provenance, không coi service name là tên phần cứng xác thực.
- Gateway inventory chỉ được merge sau HTTPS/token và context/generation checks. Merge clone model để không làm bẩn raw scan baseline; refresh luôn dựa trên scan observations, tránh giữ lease hết hạn khi inventory đổi.
- File enrollment giảm gõ token/endpoint. Import chỉ parse≤4096bytes, không network/Keychain; userSave hiện hữu vẫn kiểm tra mạng/TLS/capability và lưuKeychain.

## 5. Chức năng được triển khai

1. `LGHostProbe` ghép **SimplePing được reuse** và TCP trong cùng worker budget; ICMP được đếm riêng và tham gia reconciliation. Luôn stop/delegate teardown. Interval ICMP bao gồm thời gian ứng dụng chờ/drain runloop, không gọi là RTT chính xác.
2. TXT`model`/`manufacturer` là claim rõ ràng, giới hạn128bytes, loại control chars; không xuất tên/model/vendor trong sanitizedJSON.
3. Gateway đọc các lease paths do admin khai báo và CIDRs rõ ràng; bỏ expired/bad/placeholder/conflict/out-of-scope. API không nhận đường dẫn file từ client. Native merger giữ scope, không nâng lease thành online.
4. UI hiển thị MAC hợp lệ; allocation-only/self-reported identifier không bật Kill mới. Unkill của rule đã có vẫn được phép. Server vẫn yêu cầu current neighbor mapping cho restriction.
5. Enrollment JSONprivate: helper xuấtmode0600/O_EXCL, không in token; file import không thay chứng chỉTLS hay tự cấp quyền. Không gửi secrets qua URL/QR không được xác minh.

## 6. Kiểm thử và các mức bằng chứng

- Unit/fixture: valid/private MAC, scope/expiry/conflict; actual file parser; enrollment token/origin; model copy; ICMP counter reconciliation.
- Host-native: AppleSimplePing với loopback echo thật và TCP transport cố ý im lặng;20 lượt, cộng giữ ưu tiên accepted/refused. Không coi loopback là kiểm tra discovery LAN hoặc iPhone.
- Native Bonjour: publisher sở hữu cóTXTmodel/manufacturer; kiểm tra cùng observation và association đếnmodel; các window hiện có được giữ.
- Controlled Linux: dnsmasq/udhcpc thực sự trao đổi DHCP trong namespace; lease có MAC veth đã biết. Gateway APIHTTPS trả record; artifact chỉ có test identitiesreserved, không credentials; native merger tiêu thụ chính record đó và giữ allocation-only.
- Gateway restrictions: giữ các regressions IPv4/IPv6, mapping mismatch, admin protection, timed expiry/crash,restore.
- Physical: chỉ baseline0.5.1 được người dùng cung cấp. Không tuyên bố các thay đổi mới đã chạy trên A8.

Các kết quả CI thực tế/failure và quyết định release sẽ ghi sau khi gate chạy; không lấy danh sách test dự kiến làm kết quả pass.

## 7. So sánh với baseline0.5.1

| Hạng mục |0.5.1 đã có bằng chứng phone|Thay đổi / giới hạn|
|---|---|---|
| Bonjour|32found/32resolved/17matched,13types|Giữ engine, thêmTXTclaims; không bảo đảm lại đúng những số đó khi môi trường đổi|
| NetBIOS|2replies|Giữ|
| LocalOnly|Pass11ms|Giữ|
| Discovery|TCP17accepted+local1;55entries có history|ThêmICMP; FP/FN physical chưa đo; không đổi nhiều entry thành nhiều device|
| MAC|Neighbor0usable|Có đường authorized inventory/DHCP có đối chứng; không khôi phục MAC phone bằng phép màu|
| Identity|Tên/service tùy môi trường|TXTclaims rõ provenance, DHCP clientname; không bịa assignment/vendor|
| Scan speed/RAM|6.17s/9.51s,15.38MiBresident|Chưa có benchmark phone mới; không hứa nhanh hơn chỉ vì compile/testpass|
| Control|Gateway-conditional|Giữ control thật; allocation không tự cấp authority|
| Enrollment|Gõ endpoint/token|Importfile doadmincấp, reviewSave; HTTPS trust vẫn bắt buộc|

## 8. MAC và manufacturer

Không có API mới nào được chứng minh đọc MAC third-party trực tiếp trên iPhone12.5.8. Có một nguồn quản trị khác được triển khai, cần service/lease access được cấp quyền. Nếu mạng nhà không có service này, app không tự tạo ra MAC. Private/randomizedMAC vẫn là valid identifier theo snapshot/network, không là manufacturer/model hoặc identity vĩnh viễn. OUI assignment database chưa được thêm; manufacturer chỉ hiện khi publisher tự khai và ghi rõunverified.

## 9. Kill/Unkill

Không clone cơ chế gây gián đoạn trong APK. Không ARPimpersonation/MITM/privacybypass. DHCP-only không cho Kill; kernel-neighbor confirmation và quản trị gateway vẫn bắt buộc. Enrollment file không làm mọi stockrouter tương thích. Router readback và client Internet verification vẫn riêng biệt.

## 10. Release và source

Nhánh`reference-reuse`; baseline`9c6779180de31496f87af42feb0a43bc5b6564d7`. Ứng viên0.6.0-beta.1/build7 chỉ được publish nếu native/lab/build/package qua gate và có tiến bộ chức năng được chứng minh. Giữ nguyênpackageID/rootfuliOS12; giữ toàn bộ6release đã có thay vì bỏ bản cũ thứ6. Không publish APK hoặc credential enrollment.

## 11. Những gì còn phải xác minh

ICMP trên phone, model/manufacturer thực sự được thiết bị LAN quảng bá, inventory và enrollment trên gateway của người dùng, memory/scan timing A8, completeness theo physical ground truth. Không thay các phần này bằng số testpassed. Public source không chứng minh đầy đủ functional parity của một APK chưa được chạy.

## 12. Quy trình cuối ngắn gọn

Nếu phát hành: cập nhật một lần từ Sileo cũ, scan mạng mình được phép quản trị, xem tên/IP/MAC/model có nguồn trongdetails rồi xuất một sanitizedJSON. `icmpResponded` và `icmpFailures` dùng để phân biệt echo thực với socket failure. `authorizedInventory` tách số merge quản trị khỏi rawscan. Không gửi enrollmentfile chứa token. Không có gatewayservice thì không cần điền thông tin quản trị để thử discovery.

### Gate đầu tiên, chưa phát hành

Run46098939210: transactionDHCP thật đã tạo lease, nhưng assertion record API chưa đạt; build bịskip đúng gate. Chưa kết luận root cause khi chưa có actualrecord. Lab bổ sung diagnostic chỉ cho fixture sở hữu, và chủ động xóa neighbor có thể được DHCP học để tạo đối chứng allocation-only. Các native checks được tách job độc lập, tránh một lỗi lab che kết quả tương thích library. Lease source cũng từ chối non-regularfile bằng fdnonblocking/fstat, không để FIFO cấu hình sai treo worker.

### Review bổ sung trước phát hành

Không dùng model đã merge inventory làm baseline cho lần refresh sau: native merger clone rawscan; controller giữ scanDevices và reject callback khácgeneration/đangscan/đangmutation. Inventory lỗi hoặc hết quyền trở về rawobservations, reset combinedcounts và cập nhật detailđangmở, không giữ MAC lease cũ như dữ liệu hiện hành. DHCPfile khôngregular bị từ chối nonblocking. Enrollmentorigin kiểm tra cả portrange. Cần xem kết quả CI của đúng commit sau các thay đổi này, không dùng test của commit trước làm bằng chứng đã hoàn tất.
