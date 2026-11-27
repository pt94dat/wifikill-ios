# LanGuard — native iOS network management

Independent Objective-C/C implementation targeting **iPhone 6, iOS 12, ARM64, Chimera rootful**. Android reference: supplied WiFiKill APK 1.1.2. No APK code, assets, tracking SDKs or attack executables are incorporated.

**Status: engineering beta, not a complete implementation of the Master Prompt.** Compilation, publication and physical-device verification are independent gates. See [verification](Documentation/VERIFICATION.md) and [requirements audit](Documentation/REQUIREMENTS.md).

## Installation

Published repository, when the GitHub Actions deployment succeeds:

`https://pt94dat.github.io/wifikill-ios/`

Add this URL in **Sileo → Sources → Add**, refresh and install **LanGuard**. The website reads the actual compiled package version and checksum. No WebClip, browser wrapper or APK emulator is installed. Do not infer device compatibility from an HTTP response or build success.

## Implemented source

- Native UIKit navigation, compact dark device list and search.
- Wi-Fi IPv4 interface, subnet and default route discovery through BSD APIs.
- Bounded asynchronous TCP reachability scanning (/22–/30), cancellation and periodic refresh while active.
- Read-only neighbor MAC lookup when allowed by the OS. Silent, IPv6-only or isolated devices may be missed.
- Device names, favorites and local protection preferences; host/gateway automatically protected.
- Gateway TCP reachability diagnostics with response time; explicit separation from Internet verification.
- Bounded local event history and Keychain token storage.
- HTTPS authenticated capability detection through an extensible gateway protocol.
- Individual Kill/Unkill and Restore All through an explicitly enrolled adapter. No ARP poisoning, interception or firmware bypass.
- Linux/nftables reference gateway agent with kernel-expiring leases; both IPv4 and IPv6 forwarded traffic match source MAC on configured Ethernet LAN/WAN paths.
- Theos app build, ad hoc signing, Debian packaging, strict package inspection, generated flat APT metadata, checksum verification and gated GitHub Pages deployment.

## Access control is conditional

A stock router without an authenticated control API cannot be managed by this application. Discovery is router-brand independent; access control is **not universal**.

This beta implements one vendor-independent **opt-in Linux/nftables agent protocol**, not native OpenWrt/MikroTik/UniFi adapters. The agent must run on the gateway itself and needs Python 3.9+, `ip`, `nft` and root. Stock firmware may not support installing it. No router configuration is changed automatically by scanning.

Configure the gateway only if you administer it; see [agent setup](Gateway/README.md). Enter its HTTPS endpoint and an enrolled token in app Settings. TLS requires a certificate trusted by iOS. Unsupported environments keep Kill disabled. Rules expire after **300 seconds** independently of the phone. Readback verifies the router set only; real client Internet loss/restoration remains a separate acceptance test.

## Development

End users should not need to compile. CI runs on macOS using the Apple SDK installed with Xcode, with pinned Theos. For developers with Theos and a licensed SDK:

```sh
THEOS=/path/to/theos make package
python3 -m unittest discover -s Tests -v
python3 Scripts/build_repository.py
python3 Scripts/verify_repository.py build/repository
```

The package validator requires `dpkg-deb`. It rejects non-ARM64 executables, missing signature structures, wrong iOS minimums, incomplete bundles and invalid registration scripts. It does not substitute for installation/launch tests.

## Removal, recovery and rollback

Use **Restore All** before uninstalling from Sileo. Active restrictions otherwise expire in at most five minutes; removing the iOS app does not directly remove a rule on the gateway. Administrators can restore immediately using `nft flush set inet languard blocked` on their gateway. Forget authorization in Settings to delete the Keychain token. Device preferences/history may persist in the app data container after package removal; use iOS app-data removal if desired.

For rollback, install a previously validated `.deb` from Actions artifacts. Keep the last working downloaded package before updating; this initial beta does not yet retain a multi-version public APT history automatically. A failed build does not deploy over the published repository.

## Source reference

[APK analysis](Documentation/APK_ANALYSIS.md) · [Feature mapping](Documentation/TRACEABILITY.md) · [Physical-device checklist](Documentation/DEVICE_ACCEPTANCE.md) · [CI](.github/workflows/build-and-deploy.yml)
