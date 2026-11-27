# Phase 5 — functional identity enrichment

Baseline application0.4 source: `ca38c9b25634445e1e35b326a9e374dba067dc1f`; repository baseline `b37488a1442ca951e04139efd8d83750369f9552`. The supplied physical report matches this source, iPhone7,2/iOS12.5.8, mobile UID501. Its completed/reconciled4-address scan, exported diagnostics and approximately8.57-second elapsed/15.27MiB resident sample are actual device evidence. They do not establish peak memory, battery cost, full device census or identity correctness. Private network identifiers and the raw attachment are not published.

## Findings and applied corrections

| Finding | Evidence and actual implementation | Verification boundary |
|---|---|---|
| All3 PTR lookups expired at400ms | Baseline used a hard400ms teardown with no continued identity phase. New production resolver separates a400ms soft mark from a bounded continuation, checks cancellation at50ms poll intervals and records cleanup/late success. Public ReturnIntermediates requests negative/progress observations; unrelated rrtypes are ignored, not misread as PTR. | Production API-shim experiment with a650ms reply:400ms misses it;800/1500/3000ms receive the actual fixture name. This reproduces the missed-result mechanism, not the cause of this phone's3 missing names. |
| Scan waited for identity | The old UI received nothing until DNS/NBNS and Bonjour ended. New detached address snapshot revision1 is displayed before identity. A fingerprint/generation-checked revision2 merges evidence. Both revisions publish their matching counts and scanID. | Initial rows are copied to prevent worker mutation of displayed objects. Cancel/background/network changes invalidate the generation; in-flight resolver references are cleaned. Actual A8 latency/memory improvement remains to be measured. |
| Bonjour covered six service types only | The old collector could never find a service whose type was outside its list. New documented DNS-SD meta-query enumerates types, then starts bounded native browsers. Up to16 types and64 service instances, with existing direct types preserved. | Controlled host advertisement outside the six original types must be found; collection windows1500/3000/5000ms are compared. No success is claimed from browser startup alone. |
| Resolved services ignored absent TCP rows | Old enrichment only looped over existing results. New subnet-validated association can create a service-observation row without TCP443 response. | It stays Unknown for TCP reachability, explicitly “Service advertised · TCP unverified”; advertisedOnly is a subset of Unknown, not an extra respondent. No fabricated MAC or physical identity. |
| Route semantics too broad | Old parser accepted every local AF_LINK gateway route as a neighbor candidate, without host/link-layer route flags. New filter requires documented HOST/LLINFO semantics and separately counts non-neighbor routes. | Fixtures distinguish connected-prefix routes from genuine neighbor records. The original266-record dump is unavailable, so its239 incomplete/16 placeholder observations cannot be retrospectively reclassified. |
| Record vs unique count | 255 candidate records,254 unique rejected addresses is compatible with repeated rejected-address observations; old duplicate count covered usable records only. | New rejectedRepeated category reports this distinction. It is not a physical-device count. |
| Device identity confidence | A user label, network-reported name and service-derived hint are different evidence. | Native model returns User-defined / Reported-unverified / Unknown. Category text remains a hint; confirmed identity is not invented. |

The architecture keeps TCP/neighbor/history discovery and authorized control separate. Existing gateway/token components are unchanged; new Kill/Unkill development is deferred. Controls are unavailable while identity revisions are pending to avoid replacing a model during an operation.

## Research and alternatives

| Source | Verification, compatibility and decision |
|---|---|
| [Apple DNSServiceQueryRecord](https://developer.apple.com/documentation/dnssd/dnsservicequeryrecord(_:_:_:_:_:_:_:_:)) and [mDNSResponder header](https://github.com/apple-oss-distributions/mDNSResponder/blob/main/mDNSShared/dns_sd.h) | Documented OS-provided C DNS-SD API, predates iOS12. Reference deallocation terminates the query. No library implementation is copied. |
| [Apple resolver issue37 and maintainer clarification](https://github.com/apple/swift-async-dns-resolver/issues/37) | Public primary project discussion identifies ReturnIntermediates and clarifies that CNAME/progress or NoSuchRecord-now is not permanent nonexistence. New code reports the observed category and does not cache negative identity. This issue is not proof of the phone's root cause. |
| [Apple getnameinfo manual](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/getnameinfo.3.html) | Compatible POSIX alternative with NI_NAMEREQD but no timeout parameter; rejected as an uncancellable-worker replacement. |
| [Apple Bonjour archive](https://developer.apple.com/library/archive/documentation/Networking/Conceptual/dns_discovery_api/) and [QA1337 archive listing](https://developer.apple.com/library/archive/navigation/index.html?filter=bonjour) | Dynamic service-type discovery is a longstanding documented DNS-SD pattern. Foundation NetServiceBrowser and public DNSServiceSetDispatchQueue are used; no NWBrowser/iOS13 dependency and no added entitlement. Modern iOS14+ multicast/privacy instructions are not backported as claims about iOS12. |
| [Apple XNU iOS12-family route header](https://github.com/apple-oss-distributions/xnu/blob/xnu-4903.241.1/bsd/net/route.h) | Published wire definitions and host/link-layer route flags justify semantic filtering; no kernel implementation/private read mode is imported. |
| [Network Analyzer developer help](https://techet.net/netanalyzer/help) | Primary product documentation describes mDNS/NetBIOS/DNS names and platform-specific MAC limits. Binary product, not a verified reusable source library. Modern advertised features are not evidence of iOS12 compatibility. |
| [Fing recognition documentation](https://help.fing.com/hc/en-us/articles/26228162005916-Device-Recognition), [MAC restrictions](https://help.fing.com/hc/en-us/articles/14557409680412-MAC-Addresses-and-Private-Addressing) | Primary product references only, not source or a license to copy recognition data. Recent iOS27 MAC functionality is not an iOS12 solution. |
| [CocoaAsyncSocket](https://github.com/robbiehanson/CocoaAsyncSocket) | Public legacy Objective-C project; license/platform claims require exact release checking before adoption. Not added: OS DNS-SD already provides the needed cancellation and service APIs, so another socket dependency does not resolve these defects. |
| [Apple Swift DNS resolver](https://github.com/apple/swift-async-dns-resolver) | Public source under its own license; its Swift/dependency/platform requirements are not assumed to match the fixed Objective-C/C iOS12 target. Engineering discussion informs independent code, library not imported. |

Earlier references (NetCut/WiFiKill/Nuke/LocalFence/Harpy/BetterWiFi) remain historical research, not a source of privilege/privacy-bypass implementations. No third-party code or recognition dataset is copied. Manufacturer lookup remains unavailable without legitimate usable identifiers and a verified appropriate dataset; a large OUI database would not solve the supplied no-MAC report.

## Experiments and decision criteria

Production resolver API-shim tests model a known650ms PTR response at400/800/1500/3000ms deadlines, verify a real returned fixture name and single cleanup, and cancel before the reply. These are synthetic transport tests using the production resolver, not an actual DNS-server latency benchmark. Controlled native DNS-SD tests register/query a local-only known PTR at each deadline. Controlled native Bonjour tests publish a non-default service and compare1500/3000/5000ms, verifying callbacks, resolution and association.

Production continuation uses a global3-second identity window,12 workers and50ms cancel polling; queued DNS work is not started once that window is exhausted. Bonjour overlaps DNS for3seconds. The previous400ms becomes a soft observation threshold rather than a reason to discard a useful result. This is not simply a timeout increase: initial results are decoupled, stale generations are rejected, queries are cancellable, and newly advertised observations can enter the inventory. The window choice is a bounded experiment for the phone, not a proven optimum or proof that longer waits always help.

## Regression and remaining blockers

Baseline physical MAC/name availability remains unresolved. UID501 does not prove the missing-MAC cause. Ordinary route API success does not establish useful data. DNS timeout does not establish missing PTR. Zero Bonjour callbacks in1.5seconds does not establish absent services or broken callbacks. Zero NBNS replies does not establish a defective module: existing production parser/query contract is retained and fixtures remain gates.

History continues to retain only bounded subnet-scoped IP/time observations, with seven-day expiration and no permanent physical identity inferred from an address. Name results are kept in the current scan, not persisted as permanent IP identity; stale DHCP mappings therefore do not seed an identity cache. Existing label expiry/protection rules remain. Export retains aggregate whitelisting and excludes names, raw records, IP/MAC values, endpoints and credentials.

Full iPhone repeated-scan/background/keyboard/identity/performance acceptance remains pending. Actual source/build/test/release results will be appended after observation; no laboratory result will be labelled physical acceptance.

## Physical acceptance

1. Upgrade the existing package from the same Sileo source.
2. Scan an authorized network. Address rows should appear before the “identifying” phase ends; wait for revision2/completed before exporting the comparison report.
3. For a meaningful naming test, use an owned device/service known to advertise Bonjour or an administrator-controlled address with a known PTR record. A network without either cannot prove name-recovery success.
4. Confirm service-only observations say TCP unverified; no MAC or manufacturer should be fabricated.
5. Cancel/restart one scan and switch networks once; old identity must not overwrite the new scan.
6. Export one sanitized JSON report for comparison with0.4. No repeated screenshots required.
