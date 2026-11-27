# Phase 2 — implementation and acceptance

## Root causes corrected

The original MAC reader accepted the redacted sentinel as a hardware identifier. The scanner then included any cached neighbor address, even without an active response, under one discovered count. Device preferences could consequently share a placeholder key. It also read the route table for each candidate rather than once per scan. None of this establishes that a prior count equals that many connected physical devices.

The new reader validates addresses, excludes invalid-only cache evidence, deduplicates network/address observations, separates response/cache/history categories and never restores historical MAC identity after DHCP reuse. Manufacturer/type remain unavailable rather than guessed. DNS names are labelled network-reported. User names remain user labels.

## Counts

- Entries: unique address observations retained for the current network.
- Responded: TCP connection/refusal plus the local phone; not authenticated physical identity or Internet verification.
- Cached: valid current neighbor mapping without a response in this scan.
- Unknown: previously responding address not verified now; bounded seven-day history.
- Rules: current authenticated router-set readback for rows with usable MACs. No independently verified Internet restriction count is claimed.

## Access control and recovery

Discovery remains independent of router brand. A reusable adapter protocol and local DNS-SD suggestions are implemented; only the configured HTTPS LanGuard Linux/nftables adapter is supported. Arbitrary stock-router control remains unsupported.

The adapter must be explicitly enrolled for the current network. Tokens are stored per canonical HTTPS endpoint; new advertised services receive no credentials automatically. Rootful installation grants no automatic right or technical ability to control an arbitrary router.

Requests are followed by a separate readback of the owned kernel set. Failed Kill never becomes a restoration-success message. Pending operations are protected from duplicate requests and configuration changes. An operation journal supports readback on return, and gateway leases expire after five minutes independently of the phone. Only the adapter's own set is restored; unrelated policies are preserved. This is not end-to-end Internet verification.

## Automated evidence

The completed local checkpoint built ARM64 and passed 20 Python/portable-C tests before the workspace became unavailable. Final reconstructed source and all packaging/deployment changes must pass GitHub Actions before publication. CI additionally runs the native Foundation device-state regression executable. See the workflow and verification record for final results.

An isolated kernel integration check was attempted, but Netlink socket access was denied by the execution environment. No gateway/client end-to-end success is claimed.

## Device update acceptance — pending

1. Refresh the same Sileo source and confirm 0.2.0-beta.1 upgrades the same package.
2. Launch; verify cards and counters fit the display. The invalid sentinel must not appear as a device MAC.
3. Scan twice, cancel, filter response/cache/unknown rows and compare against a controlled client inventory. A lower total alone is not evidence of correctness.
4. Rename/favorite/protect a controlled client; verify persistence and that host/gateway stay protected.
5. Switch/disconnect Wi-Fi during a scan; results/authorization from the old network must be discarded.
6. Without an adapter, controls remain disabled and Settings explains why. If an adapter exists, enroll it once; unknown certificates/bad tokens must fail.
7. On controlled clients, independently test Internet before Kill, during the rule, after Unkill and after lease expiry. Verify other clients remain unaffected.
8. Interrupt an operation, relaunch, check router readback and Restore All. Test upgrade/removal and device memory/CPU separately.

Publication does not mark these physical tests passed. No performance numbers or universal router compatibility are asserted.
