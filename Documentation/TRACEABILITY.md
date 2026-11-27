# Functional traceability

Detailed APK-derived class/method evidence is kept outside this public repository.

| Reference capability | Independent implementation | Status |
|---|---|---|
| Network information | BSD interface/subnet/default route | Implemented, physical verification pending |
| Discovery | Bounded TCP probes and neighbor cache | Partial; silent/IPv6-only devices may be absent |
| Device identification | IP, available MAC, local names/favorites/protection | Partial; vendor/hostname identification pending |
| Ping-style diagnostics | Explicit TCP reachability/latency alternative | Implemented; ICMP/DNS/port tools pending |
| Access restriction/restoration | Authenticated gateway protocol with expiring leases and readback | Compatible opt-in agent only; real client tests pending |
| History | Local bounded event history | Implemented; full device history pending |
| Multiple selection | Restore All only | Partial |
| Interception/spoofing | Excluded | Restricted by project boundary |
| Ads/analytics | Excluded | No third-party tracking code incorporated |
