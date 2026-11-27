# Changelog

## 0.2.0-beta.1 — 2026-11-27

- Reject redacted, zero, broadcast, multicast and malformed MACs without rejecting valid locally administered addresses.
- Snapshot neighbor information once per completed scan; separate TCP response, valid cache and historical unknown observations. Deduplicate by network/address. Persist only bounded response history.
- Bound reverse DNS lookup, cancel scans, discard switched-network results and refresh while active.
- Rebuild the main screen with rounded cards, concise counts, status filters, explicit authorization reason and technical details behind Network/device details.
- Scope credentials to HTTPS endpoints and authorization to the selected network. Discover advertised adapters without sending credentials automatically.
- Enrich missing MACs from an authenticated adapter's neighbor cache; protect host/gateway and retain user preferences safely.
- Independently read back router rules after requests, distinguish failed restriction from restoration, persist interrupted-operation journals and keep finite kernel leases.
- Retain checksum-validated previous packages during publication.

## 0.1.0-beta.1 — 2026-11-27

Initial independently implemented native app and authenticated gateway reference adapter. Prior installation/launch feedback exists; this update requires a separate device test.
