# Verification gates

## Current release: 0.2.0-beta.1

The corrected local checkpoint compiled ARM64 and passed 20 Python/portable-C tests before the workspace became unavailable. The final publication gate is GitHub Actions on the committed source. Native Foundation state assertions are an additional CI gate. Build, package, deployment and public-resource status must be taken from the run results.

Updated physical-device tests remain **pending**: upgrade/install, launch, runtime scan classification, network switching, UI/performance and actual controlled-client Internet restriction/restoration. Previous-version install/launch feedback does not certify this update.

The execution environment denied Netlink sockets during an isolated kernel test attempt. No kernel/gateway/client end-to-end test passed here. Only the authenticated reference gateway agent is implemented; arbitrary stock routers remain unsupported. No full NetCut equivalence is claimed.

See [Phase 2](PHASE2.md) for corrected defects, evidence definitions and the test checklist.

## Previous published build

Native source/build commit `df90de79af2d7292313e0341c070e5bd90e0cc62`; [successful prior run](https://github.com/pt94dat/wifikill-ios/actions/runs/45964203681). Its public package, APT metadata and executable code-page hashes were verified. It is retained for rollback by the next publication.
