#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Bounded authorized DNS behavior diagnostic.
#
# Copyright (C) 2026 kaayzouee
# Author: https://github.com/kaayzouee
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation, version 3 of the License.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
# Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program. If not, see <https://www.gnu.org/licenses/>.

"""Explicitly authorized, bounded DNS transport diagnostic; see README.md."""

import argparse
from datetime import datetime, timezone
import ipaddress
import json
import math
import re
import secrets
import socket
import struct
import time

TIMEOUT = 5.0
DELAY = 0.25
# No-EDNS baseline, two buffer sizes, client cookie, and DNSSEC OK bit.
VARIANTS = (("plain", None, False, False), ("edns512", 512, False, False),
            ("edns1232", 1232, False, False), ("cookie1232", 1232, True, False),
            ("do1232", 1232, False, True))


def suffix_name(value):
    value = value.rstrip(".").lower()
    labels = value.split(".")
    if (len(labels) < 2 or len(value) > 220 or any(
        not re.fullmatch(r"[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?", label)
        for label in labels
    )):
        raise argparse.ArgumentTypeError("use an ASCII domain suffix with at least two valid labels")
    return value


def address(value, public=False, gateway6=False):
    try:
        ip = ipaddress.ip_address(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("resolver must be a numeric IP address") from exc
    scope = getattr(ip, "scope_id", None)
    if ip.is_multicast or ip.is_unspecified or ip.is_loopback:
        raise argparse.ArgumentTypeError("resolver must be a routable unicast address")
    if ip.is_link_local:
        if not gateway6 or ip.version != 6 or not scope:
            raise argparse.ArgumentTypeError("IPv6 link-local gateway requires %interface scope")
        try:
            socket.if_nametoindex(scope)
        except OSError as exc:
            raise argparse.ArgumentTypeError("scope must name an existing interface") from exc
    elif scope:
        raise argparse.ArgumentTypeError("scope is only supported for IPv6 link-local gateways")
    if public and not ip.is_global:
        raise argparse.ArgumentTypeError("public resolver must have a global address")
    return str(ip)


def timeout_value(value):
    try:
        seconds = float(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("timeout must be a number") from exc
    if not math.isfinite(seconds) or not 0 < seconds <= 10:
        raise argparse.ArgumentTypeError("timeout must be greater than 0 and at most 10 seconds")
    return seconds


def query(name, qtype, bufsize, cookie, do_bit=False):
    ident = secrets.randbits(16)
    qname = b"".join(bytes([len(label)]) + label.encode("ascii") for label in name.split(".")) + b"\0"
    question = qname + struct.pack("!HH", qtype, 1)
    opt = b""
    if bufsize is not None:
        options = struct.pack("!HH", 10, 8) + cookie if cookie else b""
        opt = b"\0" + struct.pack("!HHIH", 41, bufsize, 0x8000 if do_bit else 0, len(options)) + options
    return ident, question, struct.pack("!HHHHHH", ident, 0x0100, 1, 0, 0, bool(opt)) + question + opt


def recv_exact(sock, count, deadline):
    result = b""
    while len(result) < count:
        sock.settimeout(max(0.001, deadline - time.monotonic()))
        if time.monotonic() >= deadline:
            raise TimeoutError("deadline exceeded")
        part = sock.recv(count - len(result))
        if not part:
            raise ValueError("short TCP response")
        result += part
    return result


def probe(ip, port, protocol, name, qtype, bufsize, cookie, do_bit=False, timeout=TIMEOUT):
    ident, question, packet = query(name, qtype, bufsize, cookie, do_bit)
    timestamp = datetime.now(timezone.utc).isoformat()
    metadata = {"timestamp_utc": timestamp, "transaction_id": ident, "port": port}
    start = time.monotonic()
    try:
        family = socket.AF_INET6 if ":" in ip else socket.AF_INET
        kind = socket.SOCK_DGRAM if protocol == "udp" else socket.SOCK_STREAM
        with socket.socket(family, kind) as sock:
            sock.settimeout(timeout)
            host, separator, scope = ip.partition("%")
            destination = (host, port, 0, socket.if_nametoindex(scope)) if separator else (host, port)
            sock.connect(destination)
            metadata["source_port"] = sock.getsockname()[1]
            deadline = start + timeout
            if protocol == "udp":
                sock.sendall(packet)
                sock.settimeout(max(0.001, deadline - time.monotonic()))
                data = sock.recv(65535)
            else:
                sock.settimeout(max(0.001, deadline - time.monotonic()))
                sock.sendall(struct.pack("!H", len(packet)) + packet)
                length = struct.unpack("!H", recv_exact(sock, 2, deadline))[0]
                data = recv_exact(sock, length, deadline)
        if len(data) < 12:
            raise ValueError("short DNS header")
        rid, flags, qd, an, ns, ar = struct.unpack("!HHHHHH", data[:12])
        if rid != ident or not flags & 0x8000 or flags & 0x7800 or qd != 1 or data[12:12 + len(question)] != question:
            raise ValueError("response ID, opcode, QR, or question mismatch")
        return {**metadata, "status": "response", "elapsed_ms": round((time.monotonic() - start) * 1000, 3),
                "rcode": flags & 15, "truncated": bool(flags & 0x0200),
                "answer_count": an, "authority_count": ns, "additional_count": ar,
                "response_bytes": len(data)}
    except (OSError, ValueError, struct.error) as exc:
        return {**metadata, "status": "timeout" if isinstance(exc, TimeoutError) else "error",
                "elapsed_ms": round((time.monotonic() - start) * 1000, 3),
                "error": str(exc)}


def run(targets, suffix, qtype=1, port=53, timeout=TIMEOUT):
    rows = []
    for role, ip in targets:
        for protocol in ("udp", "tcp"):
            for variant, bufsize, use_cookie, do_bit in VARIANTS:
                name = secrets.token_hex(8) + "." + suffix
                cookie = secrets.token_bytes(8) if use_cookie else None
                for phase in ("cold", "warm"):
                    if rows:
                        time.sleep(DELAY)
                    result = probe(ip, port, protocol, name, qtype, bufsize, cookie, do_bit, timeout)
                    rows.append({"target": role, "ip": ip, "protocol": protocol,
                                 "variant": variant, "bufsize": bufsize, "do": do_bit,
                                 "request_opt": bufsize is not None,
                                 "request_edns_version": 0 if bufsize is not None else None,
                                 "cookie": use_cookie, "phase": phase, "name": name,
                                 "qtype": "A" if qtype == 1 else "AAAA", **result})
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--authorize", action="store_true", help="confirm authorization for all targets and domain")
    parser.add_argument("--gateway", required=True, help="authorized gateway resolver IPv4 address")
    parser.add_argument("--public", required=True, help="authorized public resolver IPv4 address")
    parser.add_argument("--gateway6", help="optional authorized gateway resolver IPv6 address")
    parser.add_argument("--public6", help="optional authorized public resolver IPv6 address")
    parser.add_argument("--domain", required=True, type=suffix_name, help="authorized domain suffix for randomized subdomains")
    parser.add_argument("--qtype", choices=("A", "AAAA"), default="A")
    parser.add_argument("--timeout", type=timeout_value, default=TIMEOUT,
                        help="per-probe timeout in seconds, greater than 0 and at most 10 (default: 5)")
    args = parser.parse_args()
    if not args.authorize:
        parser.error("--authorize is required; no network request was made")
    try:
        targets = [("gateway", address(args.gateway)), ("public", address(args.public, public=True))]
        if any(ipaddress.ip_address(ip).version != 4 for _, ip in targets):
            raise argparse.ArgumentTypeError("--gateway and --public require IPv4")
        for role, value in (("gateway6", args.gateway6), ("public6", args.public6)):
            if value:
                ip = address(value, public=role == "public6", gateway6=role == "gateway6")
                if ipaddress.ip_address(ip).version != 6:
                    raise argparse.ArgumentTypeError(f"--{role} requires IPv6")
                targets.append((role, ip))
    except argparse.ArgumentTypeError as exc:
        parser.error(str(exc))
    print(json.dumps({"schema": 1, "timeout_seconds": args.timeout, "delay_seconds": DELAY,
                      "cache_state": "unknown", "late_responses": "unknown",
                      "udp_tcp_comparison": "unknown",
                      "results": run(targets, args.domain, 1 if args.qtype == "A" else 28,
                                     timeout=args.timeout)}, indent=2))


if __name__ == "__main__":
    main()
