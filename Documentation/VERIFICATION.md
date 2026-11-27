# Current verification — 0.4.0-beta.1

[Consolidated phase4 report, root causes, exact release evidence and physical checklist](PHASE4.md).

- Source: `ca38c9b25634445e1e35b326a9e374dba067dc1f`.
- [Main pipeline: build, tests, deployment and public exact-release verification passed](https://github.com/pt94dat/wifikill-ios/actions/runs/46032550437).
- 27 Python/C tests, native fixtures, actual controlled host DNS/Bonjour and 25 unchanged gateway lab checks passed.
- Published .deb independently downloaded and revalidated: 68,940 bytes; SHA256 `9500c06a591cec525dad52754531dd20985e0729b5eb11c0bb9ec045f35201e1`.
- Bundle build identifier matches exact source. Three old .deb versions and the original0.3 gateway archive remain available.
- Physical0.4 testing and identity availability on the target network remain pending. Kill/Unkill development is deferred in this phase.

# Historical verification — 0.3.0-beta.1

[Consolidated audit, fixes, limitations and exact release evidence](ENGINEERING_AUDIT.md).

- Source: `ddad63f1282cb60ae1cfc62ca99ac9dd512f5c55`.
- [Build, real lab, deployment and exact public verification: passed](https://github.com/pt94dat/wifikill-ios/actions/runs/45978787339).
- 25 Python/portable-C tests and native Foundation assertions passed.
- 25 real isolated gateway checks passed. Physical iPhone and public Internet tests remain pending.
- Published .deb independently downloaded and validated: 60,358 bytes, SHA256 `c82fe460856e2ded3fba416054fd843e24f9bb4fd4f0424fc2b6606eae954425`.
- Previous two immutable packages retained.

The following is the historical 0.2 release record, not the current release result.

# Verification gates — 0.2.0-beta.1

Application source/build commit: `7a8aacae235d0987d4cf8e1f229a36daf56afe5f`.

- [Build, tests, package, deployment and post-deployment verification — passed](https://github.com/pt94dat/wifikill-ios/actions/runs/45969171502)
- [Independent exact-release, package-hash and rollback audit — passed](https://github.com/pt94dat/wifikill-ios/actions/runs/45969590688)

| Gate | Result |
|---|---|
| Source audit / corrections | Implemented; see PHASE2.md |
| Python / portable C regression suite | 20 tests passed on the final committed source |
| Native Foundation device-state regression executable | Passed on macOS; includes failed Kill vs failed Unkill readback |
| Native ARM64 build / ldid signing | Passed in macOS CI with Xcode 16.4 / pinned Theos |
| Debian bundle / architecture / minimum OS / signature structure / registration scripts | Validated |
| Published website / flat APT metadata | Published and verified through HTTPS |
| Packages / Packages.gz / Release hashes / sizes / .deb hashes | Verified after deployment and again by an independent audit job |
| Exact current release / source commit | Matched 0.2.0-beta.1 and the source commit above |
| Published current package size | 51,108 bytes |
| Previous 0.1.0-beta.1 package | Retained, validated and still downloadable with its original SHA-256 |
| Updated physical-device install / launch | Pending |
| Updated runtime discovery accuracy / UI / performance | Pending |
| Actual target Internet restriction and restoration | Pending; no controlled gateway/client acceptance performed |

Published current package SHA-256:

`5e1b6c05c3c8aaaa0c3acdbdf69b3705cf2f64f52ae50f2f99d1e410b3c3c502`

Package: https://pt94dat.github.io/wifikill-ios/debs/com.pt94dat.wifikillios_0.2.0-beta.1_iphoneos-arm.deb

Sileo/Cydia source: https://pt94dat.github.io/wifikill-ios/

## Verification limits

Response/cache/history counts describe address observations, not authenticated unique physical devices. The exact previous count cannot be independently reconstructed from a photograph alone. Placeholder identifiers are no longer used as identity or control targets.

The supported control mechanism remains an explicitly authorized HTTPS LanGuard agent on a compatible Linux/nftables gateway. Router rule readback is separate from a client Internet test. No universal stock-router support or complete NetCut equivalence is claimed.

The local environment denied Netlink sockets during an isolated kernel test attempt and later became unavailable. Final compilation, testing, packaging, retention, deployment and independent publication auditing were completed through GitHub Actions; no kernel/client end-to-end or physical UI/performance success is implied.

APT metadata is unsigned by GPG. HTTPS and generated hashes provide transport/integrity checks, not an independent repository signing identity.

[Phase 2 findings and physical-device acceptance checklist](PHASE2.md).
