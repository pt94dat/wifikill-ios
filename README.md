# LanGuard — native iOS network management

Current development release: **0.5.1-beta.1**. Same package ID and Sileo source as the prior beta. This is an engineering beta with conditional authorized access control, not complete NetCut equivalence.

## Update

Refresh `https://pt94dat.github.io/wifikill-ios/` in Sileo and install the offered LanGuard upgrade. Published version/hash are generated from the actual validated package. [Release metadata](https://pt94dat.github.io/wifikill-ios/release.json) and [previous releases](https://pt94dat.github.io/wifikill-ios/releases.json).

## Phase 5 functional identity enrichment

[Phase 5 experiments, repairs and acceptance](Documentation/PHASE5.md). Address results are now displayed before bounded identity work finishes. Matching scanID/revisions, copied models and generation/network checks prevent late results from changing another scan. The400ms DNS mark becomes a soft threshold; useful later results can be accepted within a global3-second window with cancellation and cleanup. DNS-SD returns intermediate/negative observations without inventing NXDOMAIN.

Bonjour dynamically enumerates service types, preserves multiple advertisements for one address and can add a service-only observation even without TCP443 response. Such an entry explicitly says TCP unverified and remains in Unknown; it is not a confirmed physical identity. Host/link-layer route semantics exclude non-neighbor routes. No MAC recovery or manufacturer identification on the user's network is claimed. Existing authorized management is preserved; new Kill/Unkill work is deferred.

## Phase 4 discovery reconstruction

[Consolidated phase 4 report and acceptance checklist](Documentation/PHASE4.md). Production route bytes now pass a fixture-tested parser with separate malformed/incomplete/placeholder/duplicate/conflict statistics. Scan counts are tied to one committed scan ID and reconciled against accepted/refused/local responses. DNS and Bonjour report actual module outcomes; network-scoped historical addresses expire and are not physical identities. Repeated scan workers are serialized and cancellation stops queued work and discovery delegates.

Open **Diagnostics → Copy / Export** for a whitelist-redacted runtime JSON report. It excludes network names, IP/MAC/name lists, endpoints, tokens and traffic. Identity availability on iOS 12 remains conditional. No private entitlement or privacy bypass is introduced. This phase defers new Kill/Unkill work and preserves the existing authorized gateway backend.

## Earlier engineering corrections

Invalid/redacted MAC values are rejected. Response, cache and unknown history counts are separate. Scans use bounded concurrency and cancellation, a single neighbor snapshot, network-change checks and bounded reverse DNS. The native main screen now has device cards, status filters and concise evidence counts; technical identity and network data live in detail screens.

Native scrollable detail/authorization screens separate connectivity from control, with explicit keyboard entry. Names can be user-defined, DNS-reported, Bonjour-advertised or NetBIOS-reported. These observations are unauthenticated. The current build uses an ordinary read-only neighbor view with classified parser/API telemetry; no private mode, entitlement or MAC availability guarantee is introduced. Address-only labels expire to reduce DHCP reuse errors. Physical device type/manufacturer are not fabricated. A response or refusal is evidence about an address, not proof of current Internet access or unique physical identity.

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

Current DNS recovery implementation, experiment failures, physical positive-control procedure and release evidence: [Vietnamese recovery report](Documentation/RECOVERY.md).
