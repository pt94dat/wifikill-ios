# Phase 5 — functional identity enrichment

Baseline application0.4 source: `ca38c9b25634445e1e35b326a9e374dba067dc1f`; repository baseline `b37488a1442ca951e04139efd8d83750369f9552`. The supplied physical report matches this source, iPhone7,2/iOS12.5.8, mobile UID501. Its completed/reconciled4-address scan, exported diagnostics and approximately8.57-second elapsed/15.27MiB resident sample are actual device evidence. They do not establish peak memory, battery cost, full device census or identity correctness. Private network identifiers and the raw attachment are not published.

## Findings and applied corrections

| Finding | Evidence and actual implementation | Verification boundary |
|---|---|---|
| All3 PTR lookups expired at400ms | Baseline used a hard400ms teardown with no continued identity phase. New production resolver separates a400ms soft mark from a bounded continuation, checks cancellation at50ms poll intervals and records cleanup/late success. Public ReturnIntermediates requests negative/progress observations; unrelated rrtypes are ignored, not misread as PTR. | Production API-shim experiment with a650ms reply:400ms misses it;800/1500/3000ms receive the actual fixture name. This reproduces the missed-result mechanism, not the cause of this phone's3 missing names. |
| Scan waited for identity | The old UI received nothing until DNS/NBNS and Bonjour ended. New detached address snapshot revision1 is displayed before identity. A fingerprint/generation-checked revision2 merges evidence. Both revisions publish their matching counts and scanID. | Initial rows are copied to prevent worker mutation of displayed objects. Cancel/background/network changes invalidate the generation; in-flight resolver references are cleaned. Actual A8 latency/memory improvement remains to be measured. |
| Bonjour covered six service types only | The old collector could never find a service whose type was outside its list. New documented DNS-SD meta-query enumerates types, then starts bounded native browsers. Up to16 types and64 service instances, with existing direct types preserved. | Controlled host advertisement outside the six original types must be found; collection windows1500/3000/5000ms are compared. No success is claimed from browser startup alone. |
| Resolved services ignored absent TCP rows | Old enrichment only looped over existing results. New subnet-validated association can create a service-observation row without TCP443 response. | It stays Unknown for TCP reachability, explicitly “Service advertised · TCP unverified”; advertisedOnly is a subset of Unknown, not an extra respondent. No fabricated MAC or physical identity. |
| Route semantics too broad | Old parser accepted every local AF_LINK gateway route as a neighbor candidate, without host/link-layer route flags. New filter requires documented HOST plus AF_LINK semantics and separately counts non-neighbor routes. | Fixtures distinguish connected-prefix routes from genuine neighbor records. The original266-record dump is unavailable, so its239 incomplete/16 placeholder observations cannot be retrospectively reclassified. |
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
| [CocoaAsyncSocket](https://github.com/robbiehanson/CocoaAsyncSocket) | Primary podspec7.6.5 declares public-domain licensing, iOS9 minimum and CFNetwork/Security frameworks; public Objective-C source available. Not added: OS DNS-SD already provides the needed cancellation and service APIs, so another socket dependency does not resolve these defects. |
| [Apple Swift DNS resolver](https://github.com/apple/swift-async-dns-resolver) | Public source, Apache2.0; current Package.swift uses Swift tools6.1 and a c-ares C target. These dependencies are not assumed to match the fixed Objective-C/C iOS12 target. Engineering discussion informs independent code, library not imported. |

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

## Additional reproduced functional defect

The first owned non-default Bonjour fixture failed at both1.5 and3seconds even though the collector reported enumeration success and found/resolved services. Source tracing identified a data-loss defect: an address-keyed dictionary retained only one observation and skipped a later generic service on the same IP. The repair retains a bounded array of distinct name/type observations per address, selects display evidence deterministically and removes only the withdrawn service. Tests inspect the actual owned observation inside that array rather than treating any callback as success. Late resolve callbacks for a removed service are ignored.

NetBIOS's production socket query is additionally exercised against an owned loopback UDP responder, including actual query/response transaction matching. Only the test build injects an ephemeral UDP port; production remainsUDP137. This demonstrates query/parser operation for a compatible responder and does not establish that the3 home-network peers offer NBNS.

The production LGScanner pipeline is linked to explicitly synthetic transports in a native host test. It must display copied initial rows before a delayed name, commit a second matching scanID/revision, preserve counter reconciliation, reject network-switched evidence, cancel after the first callback and complete repeated scans. This tests the actual orchestration, not a second implementation of it; it is not a physical-network or A8 performance test.

A proposed strict LLINFO-bit requirement was rejected during source verification: the iOS12-family header marks RTF_LLINFO deprecated and aliases the bit as application LLDATA. The final parser requires HOST plus AF_LINK, not that deprecated bit; a HOST-only valid-MAC regression fixture prevents false rejection. This is a source-supported semantic correction, not evidence that every old incomplete record was a non-neighbor route.

## Observed experiment results on released source

| Experiment / condition | Observed result | Meaning / limit |
|---|---|---|
| Production resolver + synthetic650ms responder,400ms hard | Deadline at400.8ms; one cleanup | Reproduces missed late name; not a phone DNS-server measurement |
| Same,800ms hard | Resolved at660.6ms | Actual fixture name accepted after the old400ms cutoff |
| Same,1500ms hard | Resolved at717.3ms | Scheduler/load affect elapsed time; fixture delay is nominal |
| Same,3000ms hard | Resolved at652.6ms | Useful reply returned immediately when received, not held until deadline |
| Cancellation during pending synthetic query | Cancelled and cleaned within asserted500ms bound | Exact cancellation time was not logged; no invented number |
| Actual host local-only PTR at400/800/1500/3000ms hard | All resolved, code0, cleanup1; observed0.5/0.4/0.5/0.4ms | Proves real DNS-SD API path for an owned known record, not physical phone naming |
| Actual owned non-default Bonjour at1500ms | Matched;1519.2ms collection elapsed | Own observation preserved among multiple services |
| Same at3000ms | Matched;3011.8ms | Does not establish that3s is necessary on every network |
| Same at5000ms | Matched;5020.4ms | No battery or all-network completeness claim |
| Actual scanner with synthetic transport | Initial address revision2.7ms, final identity revision685.7ms | Demonstrates staged delivery/copy isolation; these are not A8 scan timings or a speedup comparison against8.57s |
| Actual scanner cancellation / switched network / repeats | Passed | Production orchestration linked to explicit controlled transports |
| Production NBNS socket query / loopback responder | Passed on host | Actual request/response; ephemeral test-only port, production137 unchanged |
| Production parser / validation / counter / cache fixtures | Passed | Includes HOST-only valid entry, non-neighbor route, duplicate/conflict, malformed/private MAC, expiry and identity-field stripping |

The early Bonjour experiments failed at both1.5/3s despite callbacks; those candidates were not deployed. Preserving multiple observations repaired that data-loss failure. A compiler mismatch in BOOL block inference on the host was corrected with an explicit block return type. No claim is made that either issue explains every missing name in the original phone report.

## Before / after against0.4

| Area |0.4 baseline |0.5 implementation / remaining limit |
|---|---|---|
| Discovery | Whole result after identity phase | Detached early address revision plus guarded final revision; physical accuracy not newly measured |
| Neighbor processing | AF_LINK-scoped records without HOST qualification | Non-host routes excluded; repeated rejected observations counted separately; no unavailable MAC fabricated |
| Reverse DNS | Hard400ms result cutoff | Cancellable soft/hard continuation, progress/negative observation flag, explicit late success; phone outcome pending |
| Bonjour | Six types, one retained observation per IP | Dynamic bounded types, multiple observations, correct removal/late-resolve handling |
| Service-only evidence | Ignored if IP absent from TCP/cache/history | Subnet-validated observation can enter Unknown with TCP unverified; not counted as a TCP response |
| MAC / manufacturer | Unavailable on supplied phone | Still not demonstrated; no private entitlement, escalation or database added |
| Category / confidence | Basic service hint | User-defined, reported-unverified, confirmed-local-role and Unknown kept distinct; hints remain inferred |
| NetBIOS | Zero home replies, parser fixtures | Query path also verified with owned loopback responder; no claim modern peers provide NBNS |
| Cache/history | Normalized IP/time, expiry and scoped labels | Preserved; identity not permanently cached by IP; stale callbacks/labels guarded across network switches |
| Scan consistency | Single completed snapshot | Same scanID, explicit revisions, detached initial rows, final counts recomputed with service evidence |
| Performance | Phone8.57s / resident15.27MiB single sample | Earlier display architecture tested;0.5 physical duration/resident/battery not yet measured |
| Stability | Module cancellation checks | Production pipeline cancellation/network-switch/repeat tests; physical stress remains pending |
| UI | Dark diagnostics and copy/export | Details update on identity commit, old-network edits guarded, incomplete scans not logged as complete, management actions gated while enrichment pending |

Global identity budget and12-worker limit can leave some DNS jobs unstarted on dense networks. `budgetNotStarted` records that limitation; this is a bounded-resource choice, not a claim that every address was queried or named. Initial/final timings and DNS outcomes remain redacted aggregates.

## Implementation index

- `Sources/Network/LGResolver.c`, `LGNetwork.h`: public intermediate results, cancellable soft/hard query control and cleanup metrics.
- `LGScanner.{h,m}`: detached initial revision, overlapping Bonjour/DNS, current-generation/fingerprint checks and committed final counts.
- `LGBonjourInventory.{h,m}`, new `LGServiceEvidence.{h,m}`: bounded dynamic types, multi-service association/removal and service-only entries.
- `LGNeighborParser.{h,c}`, `LGRouteABI.h`: documented host-route semantics and rejection aggregation.
- `LGNetBIOS.c`: production port unchanged; port dependency injected only in the owned transport test build.
- `LGScanSnapshot.m`, `Sources/Devices/LGDevice.{h,m}`: advertised-only subset, copy isolation and confidence text.
- `Sources/Diagnostics/LGDiagnostics.m`, `Sources/UI/LGNetworkController.m`, `LGDeviceDetailsController.m`: whitelist support, coherent UI revisions and scoped actions.
- `Tests/scan_pipeline_tests.m`, `resolver_timing_tests.c`, `resolver_native_tests.c`, `bonjour_native_tests.m`, `test_netbios_transport.py`, `netbios_query_test.c`, parser/model fixtures: production code exercised with explicitly labelled transports.
- Workflow, control/plist, package validator, repository builder and release text: ARM64/iOS12 provenance and immutable retained downloads.

## Final release evidence

| Evidence | Result |
|---|---|
| Version | 0.5.0-beta.1 |
| Application source commit | `f3f5125e2cbad027738127ca5f3cf10026b5f819` |
| Package | com.pt94dat.wifikillios_0.5.0-beta.1_iphoneos-arm.deb |
| Architecture | iphoneos-arm package; native ARM64, minimum iOS12.0 |
| Compiler | Pinned Theos / Xcode16.4 on supported macOS15 Intel runner |
| Size | 74,824 bytes |
| Package SHA256 | `bc3e7bb829508980f9852c82ce30c7d037370db240b92307897721a1eb69fd73` |
| Gateway bundle SHA256 | `3d9f4a9abaa54b08417408821b8ffff7cef4b43501a376777b71379befd2e450` |
| Python/C suite | 29 tests passed, including production resolver/parser/loopback transport |
| Native / controlled host gates | Device/snapshot/confidence/redaction, production scanner orchestration, owned Bonjour and actual local-only PTR passed |
| Existing management regression | 25/25 isolated kernel lab checks passed; no new management feature or physical control claim |
| Package verification | ARM64 Mach-O, minimum OS, bundle/registration/signature page hashes passed |
| Deployment / public verification | Passed; exact version/source, package/index/gateway hashes verified over HTTPS |
| Independent download | Published .deb revalidated locally; embedded LGSourceCommit matched release metadata |
| History preservation | Versions0.1–0.4 retained alongside0.5; previous gateway0.4 archive independently matched original SHA256 |
| Physical0.5 acceptance | Pending; no inherited0.4 success claimed |

[Core preflight candidate](https://github.com/pt94dat/wifikill-ios/actions/runs/46047008112) · [Final source build/deployment/public verification](https://github.com/pt94dat/wifikill-ios/actions/runs/46047524272) · [Direct Debian download](https://pt94dat.github.io/wifikill-ios/debs/com.pt94dat.wifikillios_0.5.0-beta.1_iphoneos-arm.deb) · [Existing Sileo source](https://pt94dat.github.io/wifikill-ios/) · [Release metadata](https://pt94dat.github.io/wifikill-ios/release.json).

Documentation-only commits after release do not rebuild or replace the immutable package. Final acceptance still needs an authorized physical scan, preferably an owned Bonjour-advertising device or known PTR record, followed by one completed revision2 export. A network with no such evidence cannot establish naming success. MAC/manufacturer availability, A8 peak/repeated memory behavior, UI navigation/share-sheet behavior and real network-change stress remain unresolved physical acceptance items. This phase does not promise later authorization bypass or universal identity recovery.
