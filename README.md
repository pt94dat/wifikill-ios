# LanGuard — native iOS network management

Current development release: **0.3.0-beta.1**. Same package ID and Sileo source as the prior beta. This is an engineering beta with conditional authorized access control, not complete NetCut equivalence.

## Update

Refresh `https://pt94dat.github.io/wifikill-ios/` in Sileo and install the offered LanGuard upgrade. Published version/hash are generated from the actual validated package. [Release metadata](https://pt94dat.github.io/wifikill-ios/release.json) and [previous releases](https://pt94dat.github.io/wifikill-ios/releases.json).

## Current engineering corrections

Invalid/redacted MAC values are rejected. Response, cache and unknown history counts are separate. Scans use bounded concurrency and cancellation, a single neighbor snapshot, network-change checks and bounded reverse DNS. The native main screen now has device cards, status filters and concise evidence counts; technical identity and network data live in detail screens.

Native scrollable detail/authorization screens separate connectivity from control, with explicit keyboard entry. Names can be user-defined, DNS-reported, Bonjour-advertised or NetBIOS-reported. These observations are unauthenticated. A read-only privileged neighbor view is attempted where the runtime permits it, with standard-view fallback and capability telemetry; no new entitlement or MAC availability guarantee is introduced. Address-only labels expire to reduce DHCP reuse errors. Physical device type/manufacturer are not fabricated. A response or refusal is evidence about an address, not proof of current Internet access or unique physical identity.

## Authorized control

A reusable adapter protocol separates discovery from access control. The supported reference adapter is an optional authenticated HTTPS service on a Linux/nftables gateway. Local DNS-SD advertisements are untrusted suggestions; no credentials are sent automatically. There are no native stock-router adapters and no universal access-control claim.

Setup requires an administrator-controlled compatible gateway, valid TLS, an enrolled token and explicit authorization for the current network. Credentials are endpoint-scoped in Keychain. Protected/host/gateway rows cannot be restricted. Individual Kill/Unkill performs actual gateway requests followed by separate router-set readback. Router rule presence/removal is **not** independent target Internet verification.

[Engineering audit and evidence](Documentation/ENGINEERING_AUDIT.md) · [Gateway setup](Gateway/README.md) · [Phase 2 findings, limits and device checklist](Documentation/PHASE2.md).

## Recovery and rollback

Restrictions expire after five minutes independently of app/server termination. Restore All changes only the adapter-owned LanGuard set. An interrupted-operation journal triggers readback on return. Removing the phone app does not directly remove remote rules; restore first or wait for expiry. Administrators can run `nft flush set inet languard blocked` on the enrolled gateway.

CI retains up to five prior validated public packages. An invalid build or failed retention/validation never deploys over a working release. Previously published version filenames are immutable; a correction after publication needs a new version.

## Build and verification

Theos with an Apple-provided Xcode SDK builds/signs/packages the native ARM64 app in CI. The pipeline runs Python/portable-C tests and a native Foundation state regression executable, runs isolated routed IPv4/IPv6 nftables enforcement and crash-recovery checks, validates Mach-O/bundle/signature code-page hashes and APT hashes, deploys and verifies the public repository. [Workflow](.github/workflows/build-and-deploy.yml).

Physical update installation, runtime scan accuracy, Internet control, UI and performance remain separate gates. No physical-device acceptance is implied by successful compilation. [Verification](Documentation/VERIFICATION.md).

Detailed APK-derived metadata and device photographs are not included in this public repository. Original Android binaries, branding and tracking SDKs are not redistributed.
