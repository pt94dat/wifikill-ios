# Optional authorized gateway adapter

This is a real Linux/nftables reference adapter, not a universal router API. It must be installed **on the forwarding gateway**, not an arbitrary LAN laptop. It requires Python 3.9+, nftables (with JSON support and timed ether_addr sets), iproute2, TLS and root. Embedded firmware without these facilities is unsupported.

## Administrator setup

1. Read `config.example.json`; replace documentation addresses and interfaces with the actual gateway LAN and WAN interfaces. Include every relevant WAN egress (including IPv6); otherwise alternate uplinks can bypass the rule. Routed Ethernet forwarding only: PPP, VPN, bridged-only APs, nested routers and non-Ethernet paths need another adapter.
2. Explicitly add the management iPhone's current Wi-Fi MAC and any devices that must never be restricted to `protected_macs`. System interface MACs are protected automatically. Keep the phone on the same LAN as the service. The server verifies the management peer's neighbor mapping and refuses unprotected or remote management clients for new restrictions.
3. Disable **all hardware and software flow offload**, including vendor fast paths. The service refuses nftables flowtables; it cannot automatically detect every vendor hardware acceleration mechanism. Do not claim verified blocking until a real client test confirms it. Unknown topology is unsupported.
4. Create a random token locally: `python3 -c 'import secrets; print(secrets.token_urlsafe(48))'`. Save it in the configured token file (mode 0600). Do not commit it or send it in chat.
5. Supply a TLS certificate/key for a local DNS name or IP that iOS trusts. Install your own CA profile on your test iPhone if necessary. No trust bypass or plaintext mode is provided.
6. Bind the service to the management LAN address only. Restrict TCP/8443 to the admin phone in the existing gateway firewall. Keep a local console available for recovery.
7. Run `python3 languard_gateway.py --config /etc/languard/config.json` as the gateway administrator. Use your operating system's service manager for production supervision. No automated router installation is attempted.
8. In the native app, enter the HTTPS URL and token. Capability detection uses authenticated GET `/v1/capabilities`; no router-brand assumption is involved.

The service owns only `inet languard`. Its forward hook priority -100 applies before ordinary established-connection accept rules. Its MAC set uses kernel timeouts so abnormal app/server termination cannot create permanent rules. Graceful server shutdown flushes the set; server restart also restores old leases. A firewall restart may remove its table, after which API verification fails closed until service restart.

## Protocol version 1

All endpoints require `Authorization: Bearer <token>` over HTTPS. There is no unauthenticated control endpoint. No CORS support and no redirects.

| Method | Path | Result |
|---|---|---|
| GET | `/v1/capabilities` | Authenticated protocol and maximum lease |
| GET | `/v1/devices` | Gateway neighbor cache, not proof of Internet connectivity |
| GET | `/v1/restrictions` | Read back live timed MAC set |
| PUT | `/v1/restrictions/02:11:22:33:44:55` | Body `{"ip":"192.0.2.20","seconds":300}`; apply bounded lease and read it back |
| DELETE | `/v1/restrictions/02:11:22:33:44:55` | Remove matching rule and read back |
| DELETE | `/v1/restrictions` | Restore all agent-managed leases and verify empty set |

A successful result contains `router_verified: true`, **never** `end_to_end_verified: true`. MAC spoofing, rotating addresses, client VPN routes through other LAN peers and alternate gateways may bypass this mechanism. A privileged gateway operator can always remove rules. This is a management tool, not an adversarial enforcement product.

## Recovery

On the gateway: `nft flush set inet languard blocked`. To remove the adapter completely, stop its service, run `nft delete table inet languard` and remove only its configured files. No unrelated firewall tables are changed.

Unit tests use an explicitly labelled command double. They do not prove kernel nftables compatibility or physical Internet restriction; these require a controlled gateway and client.
