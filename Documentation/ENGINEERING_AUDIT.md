# Engineering audit — 0.3.0-beta.1

Review date: 2026-11-27. This is an independently implemented engineering beta. Installation and launch of earlier builds were reported on an iPhone 6/iOS 12.5.8; those observations do not validate this release. No photograph, credential or device-specific network inventory is published.

## A. Research and architecture

| Primary source reviewed | What is established | Decision |
|---|---|---|
| [NetCut / Arcai](https://www.arcai.com/) | Android product describes root/superuser requirements and ARP-related operation. Public reusable source/license and universal compatibility were not established. | Product reference only; no copied code or unauthorized mechanism. |
| User-provided WiFiKill Free 1.1.2 APK | Earlier actual static inspection identified DEX/native/root-related implementation. Artifact SHA256: `1740186ff063ae5e1eca007521d2d26b6ccf02b4ee470b3a3925be0ffa729006`. Static presence is not execution evidence. | Reference only; no Android binaries, tracking SDKs or proprietary implementation redistributed. |
| [Gokuencinar / Nuke Wireless](https://github.com/Gokuencinar/GokuEnREPO) | Current primary README labels Nuke Wireless “In Development”; current public package evidence does not establish a usable 1.0.2 source release or iOS 15–18 support. Conflicting secondary release claims remain unverified. | Not treated as an available implementation or iOS 12 dependency. |
| [emp0ry / LocalFence](https://github.com/emp0ry/LocalFence) | Public source; GPL-3.0-or-later; rootless iOS 16+ target. Has discovery, daemon identity validation and conservative naming concepts. | Study only; no GPL code copied into this MIT project. Its runtime is not an iOS 12 drop-in. |
| [Harpy Reloaded / Chariz](https://chariz.com/buy/harpy-reloaded) | MidnightChips, version 1.0.1, dated 2021-09-17, jailbroken iOS 14.0–14.8. Public reusable source/license not established. | Product comparison only; neither compatibility nor ARP implementation imported. |
| [Apple XNU 4903.241.1 rtsock.c](https://github.com/apple-oss-distributions/xnu/blob/xnu-4903.241.1/bsd/net/rtsock.c), [route.c](https://github.com/apple-oss-distributions/xnu/blob/xnu-4903.241.1/bsd/net/route.c) | iOS 12-family source distinguishes privileged link-layer read mode from ordinary scrubbed route dumps and checks route-read permission. Exact phone kernel/jailbreak permission remains unmeasured. | Attempt read-only mode 10, fall back normally, expose result. Do not grant private entitlements or claim root guarantees MAC visibility. |
| [Apple Bonjour](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/NSNetServiceProgGuide/Articles/BrowsingForServices.html), [RFC 1002](https://www.rfc-editor.org/rfc/rfc1002) | Standard service advertisements and node-status packet structures. They report observations, not authenticated physical identity. | Independently implemented bounded Bonjour/NetBIOS enrichment. |
| [Avahi](https://avahi.org/doxygen/html/), [systemd execution](https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html) | Explicit service advertisement and supervised daemon facilities. | Optional Linux installer/service; no assumed stock-router support. |

An OUI-data dependency was investigated but not adopted because its precise distributable licensing payload was not verified. Manufacturer stays unknown; service type hints are not manufacturer/model identification. Sources were reviewed rather than assumed accurate from search snippets. No external source code was copied.

The supported architecture remains native iOS discovery plus an explicitly enrolled management adapter. The adapter protocol permits additional implementations, but only the Linux/nftables reference backend is implemented. Implementing a protocol is not proof of support for all router vendors. Installing the phone application alone cannot create a missing authorized gateway service.

## B. Root causes and evidentiary limits

| Finding | Classification and consequence |
|---|---|
| MAC unavailable despite TCP responses | Confirmed separation: TCP establishes address responsiveness; it does not supply a MAC. Ordinary Darwin route dumps may redact MAC. Best-effort additional observations cannot guarantee identity. |
| No compatible service advertised | Confirmed product gap: previous gateway setup did not install an advertisement. Also possible multicast filtering or absent service. It does not prove no router API exists. |
| Kill unavailable after scan | Expected with no authenticated compatible backend or no safe target identifier. Discovery is not management authorization. |
| “Control: TCP response observed” | Confirmed UI/model fallback error; control now has its own text. |
| Long modal with automatic keyboard | Confirmed interaction problem in supplied screens; dedicated scrollable pages replace the long forms. Physical keyboard/safe-area acceptance remains pending. |
| Different observed totals across scans | Filter definitions changed and scan timing/topology can change. Exact 76/42/48 attribution is not provable from screenshots. Entries are address observations, not a physical-device census. |
| TLS accept blocking | Confirmed implementation risk; handshake moved to bounded worker threads. |
| SIGTERM cleanup absent | Confirmed implementation gap; graceful shutdown now flushes owned leases; crash recovery still uses kernel TTL. |
| Address-based preferences | DHCP reuse could transfer labels; actual-MAC/network scope preferred, address-only labels expire after 15 minutes. |

## C. Implemented before/after

- Details: long alert → grouped native scrollable identity/connectivity/management sections, localized timestamps, explicit rename input.
- Authorization: long keyboard-first alert → native settings page, secure token entry, network-bound enrollment and TLS trust preserved.
- Identity: PTR/cache only → bounded PTR, directed NBNS and Bonjour evidence, neighbor permission telemetry. Self-reported observations are labelled. No invented names, MACs or vendors.
- Control: shared connectivity fallback → independent control state and separate router readback. Gateway protects management and system devices and validates current IP/MAC mappings.
- Deployment: manual Python reference only → versioned gateway bundle, administrator installer, systemd service and optional token-free Avahi suggestion.
- Safety/recovery: lease-only crash bound → graceful cleanup plus kernel expiry, protected peers, owned-table isolation and real routed traffic tests.
- Release checks: signature envelope only → CodeDirectory executable page hashes; public checks require exact expected version and source SHA.

## D. Verification and release evidence

Baseline: 20 Python/portable-C checks passed before changes. Current local suite: 25 tests passed, including production identity/NBNS parsers and mutation-detection regression. Native Foundation assertions and full ARM64 UIKit compilation run on macOS CI. Python backend unit tests use explicitly labelled command doubles; these alone do not prove enforcement.

A separate real Linux network-namespace lab routes IPv4 and IPv6 between gateway, target, administrator and upstream namespaces. It runs the actual HTTPS agent and kernel nftables. Initial successful run [45976751179](https://github.com/pt94dat/wifikill-ios/actions/runs/45976751179) passed 19 checks: authenticated capabilities, protected management/gateway, actual target restriction and restoration, unaffected other client, LAN link preservation, crash lease expiry and unrelated firewall preservation. The release workflow repeats this lab with additional mapping, placeholder, stalled-TLS, graceful-stop and restart checks. Exact results are published as [gateway-lab-results.json](https://pt94dat.github.io/wifikill-ios/gateway-lab-results.json); do not infer a pass from a planned checklist.

[Build workflow](../.github/workflows/build-and-deploy.yml) gates ARM64 packaging on the real lab. The engineering-audit branch does not deploy. Main deploys only after successful checks; public verification compares exact source/version and downloaded package/bundle hashes. [Current release metadata](https://pt94dat.github.io/wifikill-ios/release.json), [package validation](https://pt94dat.github.io/wifikill-ios/package-validation.json), [retained releases](https://pt94dat.github.io/wifikill-ios/releases.json) are generated from actual outputs. Previous immutable packages remain available for rollback. Baseline source inventory is [AUDIT_INVENTORY.json](AUDIT_INVENTORY.json).

## E. Remaining acceptance gates

This is not a completed universal NetCut replacement. The current user network has not been demonstrated to expose a configured compatible management backend. No result here proves control of that network or public Internet access from a physical iPhone. Real lab upstream traffic is not the public Internet.

Required on-device checks for this release: upgrade/install/launch on iOS 12.5.8; inspect keyboard dismissal, scrolling and text at large sizes; scan cancel/background/network-change behavior; compare identity observations with gateway records; configure trusted TLS/token on an administered compatible gateway; restrict a consenting test client and independently test its IPv4/IPv6 Internet, restore it, test expiry and recovery. No physical performance, crash-free runtime, universal MAC recovery or installer/systemd/Avahi acceptance is claimed by compilation or namespaces.

Topology beyond routed Ethernet, embedded firmware without prerequisites, alternate uplinks and hardware fast paths require another tested adapter or explicit unsupported status. No ARP spoofing, deauthentication, interception, credential bypass or unauthorized access-control feature was implemented or deferred as a promised next step.
