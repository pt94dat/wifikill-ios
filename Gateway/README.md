# Optional authorized gateway adapter

This is a real Linux/nftables reference adapter, not a universal router API. It must be installed **on the forwarding gateway**, not an arbitrary LAN laptop. It requires Python 3.9+, nftables (with JSON support and timed ether_addr sets), iproute2, TLS and root. Embedded firmware without these facilities is unsupported.

## Administrator setup

1. Read `config.example.json`; replace documentation addresses and interfaces with the actual gateway LAN and WAN interfaces. Include every relevant WAN egress (including IPv6); otherwise alternate uplinks can bypass the rule. Routed Ethernet forwarding only: PPP, VPN, bridged-only APs, nested routers and non-Ethernet paths need another adapter.
2. Explicitly add the management iPhone's current Wi-Fi MAC and any devices that must never be restricted to `protected_macs`. System interface MACs are protected automatically. Keep the phone on the same LAN as the service. The server verifies the management peer's neighbor mapping and refuses unprotected or remote management clients for new restrictions.
3. Disable **all hardware and software flow offload**, including vendor fast paths. The service refuses nftables flowtables; it cannot automatically detect every vendor hardware acceleration mechanism. Do not claim verified blocking until a real client test confirms it. Unknown topology is unsupported.
4. Create a random token locally: `python3 -c 'import secrets; print(secrets.token_urlsafe(48))'`. Save it in the configured token file (mode 0600). Do not commit it or send it in chat.
5. Supply a TLS certificate/key for a local DNS name or IP that iOS trusts. Install your own CA profile on your test iPhone if necessary. No trust bypass or plaintext mode is provided.
6. Bind the service to the management LAN address only. Restrict TCP/8443 to the admin phone in the existing gateway firewall. Keep a local console available for recovery.
7. On a systemd Linux gateway, install prerequisites `python3`, `nftables`, `iproute2` and optionally `avahi-daemon`. Place the edited config at `/etc/languard/config.json`. From the extracted bundle run `sudo python3 Gateway/install_gateway.py --check`, then `sudo python3 Gateway/install_gateway.py`. The installer creates the token if absent, installs only the LanGuard service and starts it. Inspect `systemctl status languard-gateway` and `journalctl -u languard-gateway`. This is explicit administrator installation, not automatic modification of discovered routers.
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

## Service discovery and supervision

Download the [versioned gateway bundle](https://pt94dat.github.io/wifikill-ios/gateway/languard-gateway-0.3.0-beta.1.tar.gz) and compare its SHA256 against `gateway/SHA256SUMS`. The installer writes an Avahi advertisement when `/etc/avahi/services` exists. The administrator must enable Avahi separately; multicast filtering may still prevent discovery. Advertisements contain no token and are only suggestions. The hostname chosen in the app must match the trusted TLS certificate. An empty discovery list does not prove that every management method is unsupported.

The service bounds concurrent TLS handshakes; an idle handshake does not block the accept loop. SIGTERM/SIGINT initiate graceful shutdown and flush only its own timed set. SIGKILL cannot run cleanup; kernel lease expiry provides bounded recovery. Production installer/systemd/Avahi behavior requires acceptance on the selected gateway. The CI namespace lab runs the actual agent and nftables, not systemd or a physical router.

To uninstall: `sudo systemctl disable --now languard-gateway`; remove `/etc/systemd/system/languard-gateway.service`, `/etc/avahi/services/languard-gateway.service` if installed, and `/opt/languard-gateway`; run `sudo systemctl daemon-reload`. Remove credentials/config only when no longer needed. Delete only `inet languard` if it remains.

The enforced hook covers LAN-to-WAN forwarded packets from the selected MAC. Tests cover client-initiated sessions; ongoing unsolicited inbound traffic and full bidirectional isolation are not independently established.
