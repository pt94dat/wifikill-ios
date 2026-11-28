#!/usr/bin/env python3
"""Opt-in Linux/nftables gateway adapter. No sniffing, spoofing or shell execution.
Install only on a gateway you administer. All restrictions are kernel-timed leases.
"""
import argparse
import hmac
import ipaddress
import json
import os
import re
import ssl
import signal
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

MAC = re.compile(r"(?:[0-9a-f]{2}:){5}[0-9a-f]{2}\Z")
INTERFACE = re.compile(r"[a-zA-Z0-9_.:-]{1,15}\Z")
TABLE = "languard"


def mac_value(value):
    if not isinstance(value, str) or not MAC.fullmatch(value.lower()):
        raise ValueError("Invalid MAC address")
    value = value.lower()
    if int(value[:2], 16) & 1 or value in {"00:00:00:00:00:00", "02:00:00:00:00:00"}:
        raise ValueError("Unicast MAC required")
    return value


class Gateway:
    def __init__(self, config, runner=subprocess.run):
        self.config, self.runner = config, runner
        self.lock = threading.RLock()
        self.stopping = False
        self.lan = config["lan_interfaces"]
        self.wan = config["wan_interfaces"]
        if not self.lan or not self.wan or set(self.lan) & set(self.wan):
            raise ValueError("Separate LAN and WAN interfaces required")
        if any(not INTERFACE.fullmatch(x) for x in self.lan + self.wan):
            raise ValueError("Invalid interface name")
        self.protected = {mac_value(m) for m in config["protected_macs"]}
        if not self.protected:
            raise ValueError("Explicit host/admin protection required")

    def run(self, args, text=None):
        r = self.runner(args, input=text, text=True, capture_output=True, timeout=5)
        if r.returncode:
            raise RuntimeError("Gateway command failed; inspect local service logs")
        return r.stdout

    def nft(self, command):
        return self.run(["nft", "-f", "-"], command)

    def neighbors(self):
        values = json.loads(self.run(["ip", "-j", "neigh", "show"]))
        return [v for v in values if v.get("dev") in self.lan and v.get("lladdr") and not set(v.get("state", [])) & {"FAILED", "INCOMPLETE"}]

    def devices(self):
        """Authorized observations, not online status. DHCP never authorizes a restriction."""
        rows, neighbor_conflicts = {}, set()
        for raw in self.neighbors():
            try:
                ip, mac = str(ipaddress.ip_address(raw["dst"])), mac_value(raw["lladdr"])
            except (KeyError, ValueError):
                continue
            if ip in rows and rows[ip]["lladdr"] != mac:
                neighbor_conflicts.add(ip)
            rows[ip] = {**raw, "dst": ip, "lladdr": mac, "source": "neighbor"}
        files = self.config.get("dnsmasq_lease_files", [])
        if not isinstance(files, list) or len(files) > 8 or any(not isinstance(p, str) or not os.path.isabs(p) for p in files):
            raise ValueError("Explicit absolute lease paths required")
        networks = [ipaddress.ip_network(n) for n in self.config.get("inventory_networks", [])]
        if files and (not networks or any(n.version != 4 for n in networks)):
            raise ValueError("Explicit IPv4 inventory networks required for DHCP")
        leases, conflicts = {}, set()
        now = int(time.time())
        for file in files:
            with open(file, encoding="utf-8") as stream:
                text = stream.read(1024 * 1024 + 1)
            if len(text) > 1024 * 1024 or len(text.splitlines()) > 4096:
                raise ValueError("Lease inventory exceeds bounded size")
            # dnsmasq's documented format: expiry MAC IPv4 hostname client-id.
            for line in text.splitlines():
                fields = line.split()
                if len(fields) != 5:
                    continue
                try:
                    expiry, mac, ip = int(fields[0]), mac_value(fields[1]), ipaddress.ip_address(fields[2])
                except ValueError:
                    continue
                if expiry < 0 or (expiry and expiry <= now) or ip.version != 4 or not any(ip in n and ip not in (n.network_address, n.broadcast_address) for n in networks):
                    continue
                key = str(ip)
                if key in leases and leases[key]["lladdr"] != mac:
                    conflicts.add(key)
                hostname = fields[3] if fields[3] != "*" and len(fields[3]) <= 128 and all(32 < ord(c) < 127 for c in fields[3]) else ""
                leases[key] = {"dst": key, "lladdr": mac, "hostname": hostname, "source": "dnsmasq", "expires_at": expiry}
        for ip, lease in leases.items():
            if ip in conflicts or ip in neighbor_conflicts:
                continue
            if ip in rows:
                if rows[ip]["lladdr"] == lease["lladdr"]:
                    rows[ip]["hostname"] = lease["hostname"]
                    rows[ip]["expires_at"] = lease["expires_at"]
            else:
                rows[ip] = lease
        for ip in neighbor_conflicts:
            rows.pop(ip, None)
        return list(rows.values())[:2048]

    def check_topology(self):
        rules = json.loads(self.run(["nft", "-j", "list", "ruleset"]))
        # Hardware/software flow offload can bypass forward hooks. Refuse it.
        if any("flowtable" in x for x in rules.get("nftables", [])):
            raise ValueError("Flow offload must be disabled before using this adapter")
        addresses = json.loads(self.run(["ip", "-j", "link", "show"]))
        names = {v["ifname"] for v in addresses}
        if not set(self.lan + self.wan) <= names:
            raise ValueError("Configured network interfaces unavailable")
        for row in addresses:
            if row.get("address") and MAC.fullmatch(row["address"].lower()):
                self.protected.add(row["address"].lower())

    def install(self):
        self.check_topology()
        # Named table belongs solely to this adapter. Restart restores old leases.
        existing = self.runner(["nft", "list", "table", "inet", TABLE], text=True, capture_output=True, timeout=5)
        prefix = f"delete table inet {TABLE}\n" if existing.returncode == 0 else ""
        lan = ", ".join(json.dumps(x) for x in self.lan)
        wan = ", ".join(json.dumps(x) for x in self.wan)
        self.nft(prefix + f'''table inet {TABLE} {{
 set blocked {{ type ether_addr; flags timeout; timeout 300s; }}
 chain forward {{ type filter hook forward priority -100; policy accept;
  iifname {{ {lan} }} oifname {{ {wan} }} ether saddr @blocked counter drop
 }}
}}
''')

    def active(self):
        data = json.loads(self.run(["nft", "-j", "list", "set", "inet", TABLE, "blocked"]))
        active = {}
        for item in data.get("nftables", []):
            for elem in item.get("set", {}).get("elem", []):
                value = elem
                expires = None
                if isinstance(elem, dict):
                    inner = elem.get("elem", elem)
                    value = inner.get("val")
                    expires = inner.get("expires")
                if isinstance(value, str) and MAC.fullmatch(value.lower()):
                    active[value.lower()] = {"expires_ms": expires}
        return active

    def management_authorized(self, peer):
        peers = {n["lladdr"].lower() for n in self.neighbors() if n.get("dst") == peer}
        return bool(peers) and peers <= self.protected

    def validate_target(self, mac, ip, peer):
        mac = mac_value(mac)
        target = ipaddress.ip_address(ip)
        if target.is_multicast or target.is_loopback or target.is_unspecified:
            raise ValueError("Invalid client IP")
        neighbors = self.neighbors()
        peer_macs = {n["lladdr"].lower() for n in neighbors if n.get("dst") == peer}
        # An enrolled management client must itself be explicitly protected.
        if not peer_macs or not peer_macs <= self.protected:
            raise PermissionError("Management client must be local and explicitly protected")
        if mac in self.protected or mac in peer_macs:
            raise PermissionError("Host, gateway or protected device")
        if not any(n.get("dst") == str(target) and n["lladdr"].lower() == mac for n in neighbors):
            raise ValueError("IP/MAC mapping not confirmed on a LAN interface")
        return mac

    def restrict(self, mac, ip, seconds, peer):
        if isinstance(seconds, bool) or not isinstance(seconds, int) or not 30 <= seconds <= 900:
            raise ValueError("Lease must be 30–900 seconds")
        with self.lock:
            if self.stopping:
                raise RuntimeError("Gateway is stopping; new leases are refused")
            self.check_topology()
            mac = self.validate_target(mac, ip, peer)
            # update refreshes an existing element atomically; nft add is not a refresh.
            current = self.active()
            commands = f"delete element inet {TABLE} blocked {{ {mac} }}\n" if mac in current else ""
            self.nft(commands + f"add element inet {TABLE} blocked {{ {mac} timeout {seconds}s }}\n")
            verified = mac in self.active()
            return {"restricted": verified, "router_verified": verified,
                    "end_to_end_verified": False, "lease_seconds": seconds}

    def restore(self, mac=None):
        with self.lock:
            if mac is None:
                self.nft(f"flush set inet {TABLE} blocked\n")
            else:
                mac = mac_value(mac)
                if mac in self.active():
                    self.nft(f"delete element inet {TABLE} blocked {{ {mac} }}\n")
            active = self.active()
            return {"restricted": bool(active) if mac is None else mac in active,
                    "router_verified": not active if mac is None else mac not in active,
                    "end_to_end_verified": False}


class Handler(BaseHTTPRequestHandler):
    server_version = "LanGuardGateway/1"
    protocol_version = "HTTP/1.0"

    def log_message(self, fmt, *args):
        # Never log request URLs, Authorization headers, tokens or device identities.
        pass

    def setup(self):
        super().setup()
        self.connection.settimeout(8)

    def reply(self, code, data):
        body = json.dumps(data).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def dispatch(self):
        expected = "Bearer " + self.server.token
        if not hmac.compare_digest(self.headers.get("Authorization", "").encode("utf-8"), expected.encode("ascii")):
            self.reply(401, {"error": "Authentication required"})
            return
        try:
            if self.headers.get("Transfer-Encoding"):
                raise ValueError("Chunked requests unsupported")
            length = int(self.headers.get("Content-Length", "0"))
            if not 0 <= length <= 2048:
                raise ValueError("Invalid body size")
            path = urlsplit(self.path)
            if path.query or path.fragment:
                raise ValueError("Query parameters unsupported")
            path = path.path
            gateway = self.server.gateway
            body = json.loads(self.rfile.read(length)) if length else {}
            if not isinstance(body, dict):
                raise ValueError("JSON object required")
            if self.command == "GET" and path == "/v1/capabilities":
                gateway.check_topology()
                gateway.active()  # Fail closed if the kernel table vanished.
                data = {"protocol": "languard-gateway/1", "lease_max_seconds": 900,
                        "scope": "configured LAN to WAN forwarding, IPv4 and IPv6",
                        "end_to_end_verification": False,
                        "management_authorized": gateway.management_authorized(self.client_address[0])}
            elif self.command == "GET" and path == "/v1/restrictions":
                data = {"active": gateway.active()}
            elif self.command == "GET" and path == "/v1/devices":
                data = {"devices": gateway.devices()}
            elif self.command == "DELETE" and path == "/v1/restrictions":
                data = gateway.restore()
            elif path.startswith("/v1/restrictions/") and self.command in ("PUT", "DELETE"):
                mac = mac_value(path.removeprefix("/v1/restrictions/"))
                data = gateway.restrict(mac, body.get("ip", ""), body.get("seconds", 300), self.client_address[0]) if self.command == "PUT" else gateway.restore(mac)
            else:
                self.reply(404, {"error": "Unsupported operation"})
                return
            self.reply(200, data)
        except (ValueError, TypeError, KeyError):
            self.reply(400, {"error": "Invalid target, lease, topology or request"})
        except PermissionError as e:
            self.reply(403, {"error": str(e)})
        except (RuntimeError, subprocess.TimeoutExpired, OSError):
            self.reply(503, {"error": "Gateway verification unavailable; operation unverified"})

    do_GET = do_PUT = do_DELETE = dispatch


class TLSServer(ThreadingHTTPServer):
    """Bound TLS handshakes to worker threads; a stalled handshake must not block all clients."""
    daemon_threads = True
    def __init__(self, address, handler, context):
        self.context = context
        self.slots = threading.BoundedSemaphore(16)
        super().__init__(address, handler)

    def process_request(self, request, address):
        if not self.slots.acquire(blocking=False):
            request.close()
            return
        try:
            super().process_request(request, address)
        except BaseException:
            self.slots.release()
            raise

    def process_request_thread(self, request, address):
        try:
            request.settimeout(8)
            secure = self.context.wrap_socket(request, server_side=True)
            super().process_request_thread(secure, address)
        except (ssl.SSLError, TimeoutError, OSError):
            request.close()
        finally:
            self.slots.release()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)
    args = parser.parse_args()
    config = json.loads(Path(args.config).read_text())
    token = Path(config["token_file"]).read_text().strip()
    if len(token) < 32 or not token.isascii() or any(c.isspace() for c in token):
        raise ValueError("Use a random ASCII token of at least 32 characters")
    if os.geteuid() != 0:
        raise PermissionError("Gateway service needs root/CAP_NET_ADMIN for nftables")
    # Validate TLS material before touching existing rules. No plaintext or trust bypass mode.
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_cert_chain(config["certificate"], config["private_key"])
    gateway = Gateway(config)
    server = TLSServer((config["listen_address"], config.get("port", 8443)), Handler, context)
    server.gateway, server.token = gateway, token
    gateway.install()
    def stop(signum, frame):
        del signum, frame
        threading.Thread(target=server.shutdown, daemon=True).start()
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    try:
        server.serve_forever()
    finally:
        try:
            with gateway.lock:
                gateway.stopping = True
                gateway.restore()
        finally:
            server.server_close()


if __name__ == "__main__":
    main()
