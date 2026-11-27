# Verification gates

Evidence update: 2026-11-27. Native application source/build commit: `df90de79af2d7292313e0341c070e5bd90e0cc62`. This document update does not change the native application. [Successful build, deploy and verification run](https://github.com/pt94dat/wifikill-ios/actions/runs/45964203681).

| Gate | Status | Evidence |
|---|---|---|
| APK analyzed | Static analysis completed; dynamic testing pending | Detailed local inspection records retained outside the public repository |
| Source implemented | Partial engineering beta | Sources/, Gateway/, Scripts/, Tests/ |
| Source committed | Passed | Native code commit linked above; original repository history preserved |
| Automated gateway tests | 17 passed | Logic tests and local HTTP authentication/input-boundary tests; command doubles are explicitly labelled |
| Native build | Passed locally and in macOS CI | Theos 8167f59, Xcode 16.4 CI; ARM64, minimum iOS12.0; ldid signing |
| Debian package | Generated and validated | Public .deb downloaded again: 32,368 bytes; ARM64 Mach-O, iOS minimum, signature structure, bundle/icons, permissions and install/remove scripts checked |
| Executable code hashes | Passed on published package | Both SHA-1 and SHA-256 CodeDirectories: 31 code-page hashes each verified against actual executable bytes; this does not prove jailbreak trust or device launch |
| Website/APT published | Passed | HTTPS website, Release, Packages, Packages.gz and actual Debian download accessible |
| APT integrity | Passed in CI and independently after publication | Release hashes/sizes, gzip decompression, package architecture, size and SHA-256 matched; current values in release.json and package-validation.json |
| Device installation / launch | Pending | No physical test device available |
| Network discovery runtime | Pending | No target-device scan evidence |
| Actual Internet restriction / restoration | Pending | No controlled gateway/client hardware available; unit tests are not end-to-end evidence |
| UI/performance/final QA | Pending | Physical acceptance and incomplete requirement closure required |

This is an engineering beta, not a completed implementation of every requested feature. Discovery is independent of router brand. Access control currently requires the explicitly configured compatible Linux/nftables reference agent, which is not supported on every stock router. No universal control claim is made. The APT metadata is not GPG-signed; HTTPS and generated hashes provide transport/integrity checks, not an independent repository signing identity.
