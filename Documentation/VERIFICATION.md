# Current verification —0.5.0-beta.1

[Phase5 consolidated research, root causes, actual experiments, release evidence and physical checklist](PHASE5.md).

- Source: `f3f5125e2cbad027738127ca5f3cf10026b5f819`.
- [Final main pipeline: all tests, ARM64 build, package checks, deployment and exact public verification passed](https://github.com/pt94dat/wifikill-ios/actions/runs/46047524272).
-29 Python/C tests; native models/pipeline; actual controlled PTR/Bonjour;25 unchanged kernel lab checks passed.
- Published package independently revalidated:74,824 bytes; SHA256 `bc3e7bb829508980f9852c82ce30c7d037370db240b92307897721a1eb69fd73`.
- Bundle source identifier matches; four prior versions and their published gateway archives retained.
- Physical0.5 identification/performance acceptance pending. New access-management development remains deferred.

# Historical verification — 0.4.0-beta.1

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


## DNS recovery0.5.1-beta.1 —28/11/2026

Source`f8b6cf1577f63fd32e51522eafd0dc23c75c78ab`; main workflow[46093584618](https://github.com/pt94dat/wifikill-ios/actions/runs/46093584618) passed all four jobs.31 portable methods, native model/pipeline/Bonjour/PTR and10 production LocalOnly checks passed;25 real isolated gateway checks passed. Re-downloaded public package80,182bytes, SHA-256`9b0f45685191a488442165f06548b1368a9f72c67ceb3a58339b91f7f1e0bc31`, Info.plist version0.5.1/build6/source match. All five earlier packages retained;0.5.0 checksum unchanged.

[Consolidated Vietnamese findings, failed experiments, release evidence and one-device checklist](RECOVERY.md). Physical iPhone name/MAC/manufacturer/category improvement and performance remain unverified. LocalOnly control success would establish local API behavior only.


## Reference/reuse0.6.0-beta.1 —28/11/2026

Source`dd32536c626f78accb5bfc536157d1668b519d7c`, main workflow[46100153805](https://github.com/pt94dat/wifikill-ios/actions/runs/46100153805), all5jobs passed. Actual unprivileged host ICMP20echoes with silentTCPfixture; actual namespaceDHCP→authenticatedHTTPSinventory→native model MAC/name; allocation-only cannot authorizeKill; nativeBonjourTXTclaims; private enrollment decoding/export;36portable methods and28realnamespacechecks pass. Physical acceptance of new0.6features remains pending.

Re-downloaded public package91,844bytes, SHA256`1a9d744bb09279f3d72374e12efa87d7df9353f3d8b8378e5ceace35293cbcbd`; Info0.6.0/build7/source match, minimumiOS12, ARM64/iphoneos-arm, bothApple/MMLanScan licenses present. All6priorpackages retained unchanged. [Consolidated Vietnamese reference findings/reuse decisions/failures/limits/release evidence](REFERENCE_REUSE.md).
