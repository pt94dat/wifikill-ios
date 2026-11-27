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
| [Gokuencinar BetterWiFi RH / Nuke lead](https://github.com/Gokuencinar/GokuEnREPO) | The current primary README now lists NukeWireless 1.0.2 with Dopamine, RootHide and Rootful variants, superseding the earlier audit's observed development-only listing. Distribution descriptions exist; source availability/license for an iOS-12-compatible implementation is not established by the package listing. BetterWiFi RH's current rootful package explicitly requires firmware >=15 and <18, so it is incompatible with iOS 12. Nuke 1.0.2's published package dependencies include network-cmds, ldid and arpoison; they do not establish exact iOS 12 compatibility or reusable source rights. Its disruption dependency is outside this phase. | No binary/source imported and no compatibility inferred from marketing. |
| [silverwind oui-data](https://github.com/silverwind/oui-data), [IEEE registry](https://standards.ieee.org/products-programs/regauth/) | Public assignment data is not automatically an authenticated device identity. Candidate metadata advertises BSD-2-Clause, but exact dataset redistribution/provenance must be verified before bundling. Prior full JSON measured about 5.6 MB, much larger than the app package. | No dataset bundled while usable MAC remains unproven. Locally administered MAC does not receive vendor inference. Manufacturer stays unknown rather than adding a misleading database feature. |

Prior NetCut/WiFiKill/LocalFence/Harpy comparisons remain in [the earlier audit](ENGINEERING_AUDIT.md); no disruption/interception/private-entitlement implementation is imported. Historical public API documentation and production-code experiments, rather than modern-jailbreak product claims, drive these changes.

## Confirmed defects and limits

| Symptom / gap | Source evidence and correction | Verification / remaining limitation |
|---|---|---|
| 43 excluded neighbor identifiers | Old counter incremented once per parsed invalid six-byte MAC record in the selected view. It was not a count of confirmed devices. Incomplete, malformed and duplicate records lacked separate reporting. New production byte parser classifies placeholder pattern, zero, multicast, incomplete, malformed, duplicates, conflicts and unique rejected addresses separately. | Synthetic production-parser fixtures and sanitizer tests, including 43 distinct rejected addresses versus 43 repeats of one address. The original phone dump was not captured: cannot retrospectively assign all 43 records to redaction or parsing. New sanitized export narrows the cause without leaking identifiers. |
| Neighbor view 2 confused with a count | It is an enum for no usable MAC with invalid patterns, not two respondents. | Report keeps it as source status separate from response categories. |
| Response/count discrepancy | Confirmed source ordering defect: the old scanner published metrics before Bonjour completed, while UI rows were delivered later. Navigation could cancel that completion and leave newer metrics beside previous rows. There was also no scan ID. The supplied accepted/refused numbers plus one local row do not conclusively reconcile the observed total. | New one-scan ID, committed counts, explicit local/other evidence and reconciliation boolean. No fabricated explanation of the old discrepancy. |
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

The phase4 branch cannot deploy. Only a successful tested candidate may be promoted; main then rebuilds, preserves immutable releases, validates package contents/signature page hashes and verifies downloaded public metadata against exact source/version. Observed release results are recorded below.

## Physical acceptance

1. Upgrade the existing LanGuard package; verify version0.4 and launch on the same authorized Wi-Fi.
2. Scan, inspect response categories and completion diagnostics; total must equal responded+cached+unknown; responded must equal accepted+refused+local with no unexplained rows.
3. Repeat/cancel a scan and background/return; no stale snapshot should replace a newer one.
4. Inspect identity evidence: unavailable remains honest; names and category hints remain reported/inferred.
5. Open Diagnostics → Copy or Export and send one sanitized JSON report. It must include scanID, parser categories, resolver/Bonjour outcomes and timings, without credentials/network identifiers.
6. Check placeholder contrast, card labels, scrolling and keyboard handling. A gateway setup is not needed for this phase's acceptance.

## Implementation index

- `Sources/Network/LGNeighborParser.{h,c}`: production wire parser with bounded records, classification, duplicate/conflict handling.
- `Sources/Network/LGNetwork.{h,c}`: ordinary read-only source, API errno/status and corrected nonblocking socket error checks.
- `Sources/Network/LGResolver.c`: actual DNS-SD query, callback outcomes and cleanup.
- `Sources/Network/LGScanSnapshot.{h,m}`: counter reconciliation and history normalization.
- `Sources/Network/LGScanner.{h,m}`: serialized phase orchestration, cancellation and one completed main-thread publication.
- `Sources/Network/LGBonjourInventory.{h,m}`: run-loop lifecycle, errors, removals and reusable-collector generation guard.
- `Sources/Diagnostics/LGDiagnostics.{h,m}`: runtime JSON and whitelist redaction.
- `Sources/Devices/LGDevice.{h,m}`, `Sources/Storage/LGStore.m`: evidence outcomes and historical capacity.
- `Sources/UI/LGNetworkController.m`, `LGDeviceCell.m`, `LGDeviceDetailsController.m`, `LGAuthorizationController.m`: native export/navigation and scoped readability corrections.
- `Tests/test_network_engine.py`, parser/resolver C fixtures, native snapshot/history/redaction fixtures, controlled Bonjour/PTR fixtures: tests execute production implementations.
- `.github/workflows/build-and-deploy.yml`, release scripts, plist/control, website/readme/changelog: exact build provenance, gated packaging and retained versioned downloads.

Historical gateway archives are now checksum-retained alongside historical Debian packages. No gateway control logic was expanded.

Manufacturer feasibility: [IEEE registry FAQ](https://standards.ieee.org/faqs/regauth/) and [RFC 9542](https://www.rfc-editor.org/rfc/rfc9542.html) distinguish MA-L (24-bit), MA-M (28-bit) and MA-S (36-bit) assignment prefixes. A future database must use appropriate longest-prefix matching and label the registry assignee rather than assert a physical product manufacturer. Locally administered/randomized addresses cannot safely use global-prefix inference. No offline lookup performance or memory figure is claimed for a database that was not bundled.

Build-host fallback: an Apple-Silicon job remained without an assigned runner. The final workflow uses GitHub's supported `macos-15-intel` pool with `/Applications/Xcode_16.4.app/Contents/Developer` pinned. The output target remains iOS 12 ARM64; this does not change the user's hardware or OS. Concurrency is scoped per branch so an undeployable preflight cannot hold the main release queue. [Official runner labels](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) and [image/Xcode inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md) were checked before the change.

## Before / after summary

| Area | 0.3 baseline | 0.4 verified change / limit |
|---|---|---|
| Discovery accuracy | Address responses, not a device census | Same probe scope; fixture-tested unique snapshots. Real-network accuracy still needs comparison with an authorized inventory. |
| Rejected identifiers | One invalid-MAC record count | Independent categories, record/unique distinction, duplicate/conflict suppression; synthetic43 cases passed. |
| MAC availability | Unavailable on inspected phone | No universal availability claim; ordinary source diagnostics now expose why records are unusable. |
| Counter coherence | Metrics could precede row publication | Same completion commit and scanID, explicit local evidence and reconciliation fixtures. |
| DNS | Binary success/unknown | Production API/callback/deadline/no-record/malformed distinctions; controlled real PTR passed. |
| Bonjour/service evidence | Short collection with little failure evidence | Errors/pending/removal/cancellation telemetry and reuse guard; owned host advertisement found at both tested windows. |
| Manufacturer | Unknown | Remains unknown without legitimate usable evidence; no unverified dataset or vendor inference. |
| Category | Service hints when available | Hints remain explicitly unverified; generic observations do not overwrite an existing stronger hint. No phone-network identification success claimed. |
| Cache/history | Arbitrary512 record truncation | Normalized recent subnet records, duplicate/newest timestamp handling, seven-day expiry and capacity1,022. |
| Performance | Fixed budgets, no exported timings | Same production budgets, serial orchestration and actual runtime time/CPU/resident measurements. No A8 speed/battery claim yet. |
| Stability | Incomplete cancellation visibility | Queued operation and Bonjour cancellation/reuse tested at module level; physical repeated-scan/background stress remains pending. |
| UI readability | Duplicate IP subtitle, low-contrast placeholders, long diagnostic text | Native dark export page, explicit placeholder tint, evidence subtitle, unavailable control hidden; visual acceptance pending. |
| Diagnostic export | Screenshots required | Native Copy and activity-sheet JSON export implemented; whitelist redaction tested. |
| Kill/Unkill | Conditional authorized gateway | Preserved; no new access-control implementation or physical acceptance in phase4. |

## Published release evidence

| Evidence | Result |
|---|---|
| Version | 0.4.0-beta.1 |
| Exact application source commit | `ca38c9b25634445e1e35b326a9e374dba067dc1f` |
| Package | com.pt94dat.wifikillios_0.4.0-beta.1_iphoneos-arm.deb |
| Architecture | iphoneos-arm; native ARM64, minimum iOS12.0 |
| Published size | 68,940 bytes |
| Package SHA256 | `9500c06a591cec525dad52754531dd20985e0729b5eb11c0bb9ec045f35201e1` |
| Gateway archive SHA256 | `135ccc8b0de1cda59c6abfc357718e93e49bfd2551e9ef2e09837bd3da5298a2` |
| Python / portable C | 27 passed, including production parser/resolver sanitizer fixtures |
| Native tests | Device model, snapshot/history/redaction/Bonjour lifecycle fixtures, actual owned Bonjour publisher and local-only PTR query all passed |
| Controlled Bonjour measurement | Release host: 1,553.2 ms for configured1,500 ms; 3,037.5 ms for configured3,000 ms; both found the owned service. Not a phone/battery benchmark. |
| Existing gateway regression | 25/25 real isolated kernel lab checks passed; no public Internet or physical phone test |
| Packaging | ARM64 Mach-O, iOS12 minimum, bundle/registration and executable signature-page hashes passed |
| Publication | Pages deployment and exact source/version/public hash verification passed |
| Independent download | Published .deb downloaded, revalidated and bundle LGSourceCommit matched release metadata |
| Retention | 0.1, 0.2 and 0.3 Debian releases retained; original0.3 gateway archive independently rehashed successfully |
| Physical0.4 acceptance | Pending; install/launch feedback from0.3 is not transferred to this build |

[Successful exact-source preflight](https://github.com/pt94dat/wifikill-ios/actions/runs/46032067779) · [Successful main build/deployment/public verification](https://github.com/pt94dat/wifikill-ios/actions/runs/46032550437) · [Direct Debian download](https://pt94dat.github.io/wifikill-ios/debs/com.pt94dat.wifikillios_0.4.0-beta.1_iphoneos-arm.deb) · [Existing Sileo source](https://pt94dat.github.io/wifikill-ios/) · [Generated release metadata](https://pt94dat.github.io/wifikill-ios/release.json).

Documentation-only updates after publication do not rebuild or replace this immutable package. The recorded application source commit remains the one embedded in the published bundle. Physical installation/update/removal, keyboard/share-sheet behavior, A8 performance, real-network discovery/identity and live cancellation/background behavior remain acceptance items. No claim is made that the inspected phone can now recover MACs or identify every client.
