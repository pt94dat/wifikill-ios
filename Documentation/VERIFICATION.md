# Verification gates

Evidence update: 2026-11-27. See GitHub Actions for live build/deployment results. No physical-device access is available in this workspace.

| Gate | Status | Evidence |
|---|---|---|
| APK analyzed | Static analysis completed, dynamic testing pending | Local inspection records retained outside the public repository |
| Source implemented | Partial engineering beta | Sources/, Gateway/, Scripts/, Tests/ |
| Source committed | Check repository commit history | GitHub history is authoritative |
| Gateway unit tests | 17 passed | `python3 -m unittest discover -s Tests -v`; explicit command doubles, not actual router tests |
| Native build | Passed locally, ARM64/iOS12 | Theos 8167f59, Clang 11.1, iPhoneOS12.4 SDK; C/Objective-C compilation, link, strip and ad hoc signing succeeded |
| Debian package generated/validated | Passed locally | Actual .deb, ARM64 Mach-O, minimum iOS12, embedded signature, icons, registration scripts and generated checksum verified |
| Website/APT published | Pending deployment; local APT verified | Release SHA256/size, Packages.gz decompression, actual .deb hash/size and architecture passed |
| Device installation / launch | Pending | No physical iPhone available |
| Network discovery runtime | Pending | No target-device scan evidence |
| Actual Kill / Unkill | Pending | No controlled gateway/client hardware available |
| UI/performance/final QA | Pending | Physical acceptance and incomplete requirement closure required |
