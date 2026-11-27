# Phase 4 — discovery engine and runtime diagnostics

Baseline: application source `ddad63f1282cb60ae1cfc62ca99ac9dd512f5c55`; repository documentation head `381bb11a135583cf268916a48dac7e8c329096b6`. The baseline local Python/C suite passed 25 tests. User photographs establish 0.3 installation/launch, scanning and scrollable settings on the physical iPhone; they do not validate the new release. Exact workplace identifiers and photos are deliberately excluded from this public report.

## Scope and execution path

Application/main → LGNetworkController → LGScanner → automatic LGNetworkContext/interface/subnet → bounded TCP workers → ordinary neighbor dump/parser → network-scoped history → DNS-SD PTR + directed NBNS → main-run-loop NetServiceBrowser → committed counts and runtime diagnostic report → device cards/details. Authorized gateway requests, token storage and kernel policy are preserved; Kill/Unkill engineering is deferred in this phase. Controls without current capability are hidden.

Reviewed application lifecycle, all network/identity/storage/model/UI modules, gateway adapter protocol and implementation, signing/plist/entitlements, Theos, Debian install/remove scripts, repository generation, release preservation and workflow. Stable backend and signing logic were retained. New code has no third-party source dependency or private entitlement. Ordinary read-only route dumps replace the previous private-mode attempt; unavailable identity is not pursued through OS privacy bypasses.

## Research evidence and selected alternatives

| Primary source | Authenticity, license / compatibility | Application |
|---|---|---|
| [Apple XNU iOS-12-family route ABI](https://github.com/apple-oss-distributions/xnu/blob/xnu-4903.241.1/bsd/net/route.h), [rtsock](https://github.com/apple-oss-distributions/xnu/blob/xnu-4903.241.1/bsd/net/rtsock.c) | Apple public source under its published source terms, not a drop-in app library. Wire headers, 32-bit sockaddr alignment and standard dump scrubbing are relevant; exact target runtime must be measured. | Independent byte parser, preserved 92-byte route-header contract, valid zero-length netmask handling, synthetic fixtures, no copied kernel implementation. |
| [Apple legacy getnameinfo manual](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/getnameinfo.3.html) | Official historical iOS manual; POSIX API available before iOS 12. NI_NAMEREQD prevents numeric fallback but has no timeout argument. | Rejected as an uncancellable worker replacement for the existing DNS-SD query. |
| [Apple DNSServiceQueryRecord](https://developer.apple.com/documentation/dnssd/dnsservicequeryrecord(_:_:_:_:_:_:_:_:)), [socket descriptor](https://developer.apple.com/documentation/dnssd/dnsservicerefsockfd(_:)), [legacy resolving guide](https://developer.apple.com/library/archive/documentation/Networking/Conceptual/dns_discovery_api/Articles/resolving.html) | Official documented DNS-SD interface, predates iOS 12; platform implementation supplied by OS. Operations are terminated by reference deallocation. | Keep bounded poll/process/deallocate lifecycle; distinguish callback/no-record/API/deadline/malformed outcomes. A deadline is not NXDOMAIN. |
| [Apple NetServiceBrowser](https://developer.apple.com/documentation/foundation/netservicebrowser), [legacy Bonjour guide](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/NSNetServiceProgGuide/Articles/BrowsingForServices.html) | Official Foundation API predates iOS 12. No newer Network.framework browser introduced. | Track browse/resolve errors and pending work; explicit cancellation; controlled host experiments compare 1.5 and 3 second windows. |
| [Apple mDNSResponder](https://github.com/apple-oss-distributions/mDNSResponder) | Apple public implementation and headers, separate source terms. OS library is used, not redistributed. | Controlled local-only PTR registration/query test and actual owned Bonjour advertisement in macOS CI; not an iPhone claim. |
| [Gokuencinar BetterWiFi RH / Nuke lead](https://github.com/Gokuencinar/GokuEnREPO) | Primary distribution repository and descriptions exist; source availability/license for an iOS-12-compatible implementation is not established by the package listing. RootHide/Dopamine descriptions are not proof of Chimera compatibility. | No binary/source imported and no compatibility inferred from marketing. |
| [silverwind oui-data](https://github.com/silverwind/oui-data), [IEEE registry](https://standards.ieee.org/products-programs/regauth/) | Public assignment data is not automatically an authenticated device identity. Candidate metadata advertises BSD-2-Clause, but exact dataset redistribution/provenance must be verified before bundling. Prior full JSON measured about 5.6 MB, much larger than the app package. | No dataset bundled while usable MAC remains unproven. Locally administered MAC does not receive vendor inference. Manufacturer stays unknown rather than adding a misleading database feature. |

Prior NetCut/WiFiKill/LocalFence/Harpy comparisons remain in [the earlier audit](ENGINEERING_AUDIT.md); no disruption/interception/private-entitlement implementation is imported. Historical public API documentation and production-code experiments, rather than modern-jailbreak product claims, drive these changes.

## Confirmed defects and limits

| Symptom / gap | Source evidence and correction | Verification / remaining limitation |
|---|---|---|
| 43 excluded neighbor identifiers | Old counter incremented once per parsed invalid six-byte MAC record in the selected view. It was not a count of confirmed devices. Incomplete, malformed and duplicate records lacked separate reporting. New production byte parser classifies placeholder pattern, zero, multicast, incomplete, malformed, duplicates, conflicts and unique rejected addresses separately. | Synthetic production-parser fixtures and sanitizer tests. The original phone dump was not captured: cannot retrospectively assign all 43 records to redaction or parsing. New sanitized export narrows the cause without leaking identifiers. |
| Neighbor view 2 confused with a count | It is an enum for no usable MAC with invalid patterns, not two respondents. | Report keeps it as source status separate from response categories. |
| Response/count discrepancy | Old UI counted mutable rows and diagnostics copied separate scanner metrics without a scan ID. The supplied accepted/refused numbers plus one local row do not conclusively reconcile the observed total. | New one-scan ID, committed counts, explicit local/other evidence and reconciliation boolean. No fabricated explanation of the old discrepancy. |
| Duplicate/conflicting neighbor records | Old parser could return repeated IP records and last value could overwrite a conflicting mapping. | Same-address/same-MAC deduplication, conflicting mapping suppressed. No permanent identity inferred from an IP. |
| Resolver outcomes collapsed | Old callback ignored asynchronous errors, allowing failure to appear as deadline/unknown. | Actual callback categories and numeric errors; deallocation on success/failure/deadline. Production code exercised through a deterministic API shim and controlled real macOS DNS-SD. |
| Bonjour “none observed” ambiguous | Old collector had no failure/pending/removal telemetry and scanner cancellation left collection running until timer. | Explicit stop/delegate cleanup; errors and unresolved-at-deadline reported; removed service evidence discarded; stronger service category not overwritten by generic hints. No advertising/no-result cannot establish unsupported network. |
| History and /22 capacity | Storage arbitrarily truncated at 512; scan budget reaches 1,022. Future/duplicate records were insufficiently normalized. | Recent valid subnet-scoped address history normalized, newest timestamp deduped, seven-day expiry, future records rejected, capacity1,022. Tests cover expiry/network boundaries. Historical identity/MAC not persisted. |
| Cancellation and repeated scans | Each new scan could create a separate background worker queue while previous work drained. | Serial scan orchestration, cancel queued operations and Bonjour, retain generation/fingerprint discard checks. In-flight network calls still finish within their bounded phase; actual A8 stress acceptance pending. |
| Missing diagnostic export | Numerous screenshots were required to inspect runtime evidence. | Native Copy and activity-sheet Export of whitelist-redacted JSON, actual module counters, scan lifecycle, CPU timing and resident bytes/API status. No token/endpoint/IP/MAC/SSID/name list is exported. |
| Readability | Low-contrast field placeholders, duplicate IP card labels, dense diagnostic alerts, unavailable Kill controls. | Explicit placeholder tint, category/identity subtitle, dark scrollable report, native sharing and hidden unavailable action. Runtime UIKit acceptance remains pending. |

## Before / after and performance boundaries

Baseline 0.3 used 12 workers, 300 ms TCP, 400 ms PTR, 150 ms NBNS and 1.5 second Bonjour. Those production budgets remain unchanged; no blind timeout/workload increase. Serial execution prevents repeated scan requests from multiplying queues. New measurements report total/probe/identity wall time, process CPU delta and resident bytes at completion. These are actual process measurements, not battery or frame-rate claims. No physical speedup, memory benchmark or crash-free claim is made before on-device acceptance.

MAC, manufacturer and exact physical identity can remain unavailable. DNS and Bonjour report only evidence actually returned; hints such as printer service are not a confirmed manufacturer or device model. Discovery still uses IPv4 address responses and may miss silent or isolated clients. Local response does not verify Internet access. Management functionality is not expanded or newly accepted in phase4.

## QA and release gates

Baseline25 Python/C tests passed. Current local suite27 passes, including production Darwin parser and resolver with AddressSanitizer/UBSan (leak detection disabled in the ptrace-managed local executor; this is not a leak test). Native Foundation snapshot/history/redaction/Bonjour lifecycle fixtures, controlled real macOS DNS-SD and Bonjour-window tests, full iOS ARM64 compilation and the unchanged real gateway regression lab are CI gates. No physical iOS test is implied by a host test.

The phase4 branch cannot deploy. Only a successful tested candidate may be promoted; main then rebuilds, preserves immutable releases, validates package contents/signature page hashes and verifies downloaded public metadata against exact source/version. Final release evidence will be appended only after observing results.

## Physical acceptance

1. Upgrade the existing LanGuard package; verify version0.4 and launch on the same authorized Wi-Fi.
2. Scan, inspect response categories and completion diagnostics; total must equal responded+cached+unknown; responded must equal accepted+refused+local with no unexplained rows.
3. Repeat/cancel a scan and background/return; no stale snapshot should replace a newer one.
4. Inspect identity evidence: unavailable remains honest; names and category hints remain reported/inferred.
5. Open Diagnostics → Copy or Export and send one sanitized JSON report. It must include scanID, parser categories, resolver/Bonjour outcomes and timings, without credentials/network identifiers.
6. Check placeholder contrast, card labels, scrolling and keyboard handling. A gateway setup is not needed for this phase's acceptance.
