#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Synthetic DNS diagnostic regression test.
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

"""Synthetic loopback-only DNS fixture; no external network."""

import argparse
from datetime import datetime
import json
import select
import socket
import struct
import subprocess
import sys
import threading
from unittest.mock import patch

import diagnostic


def read_exact(sock, count):
    data = b""
    while len(data) < count:
        part = sock.recv(count - len(data))
        if not part:
            raise AssertionError("incomplete fixture request")
        data += part
    return data


def response(packet):
    ident, flags, qd, _, _, ar = struct.unpack("!HHHHHH", packet[:12])
    assert flags == 0x100 and qd == 1 and ar in (0, 1)
    end = 12
    while packet[end]:
        end += packet[end] + 1
    end += 5
    question = packet[12:end]
    opt = packet[end:]
    if ar:
        assert opt[0] == 0 and struct.unpack("!H", opt[1:3])[0] == 41
        size = struct.unpack("!H", opt[3:5])[0]
        assert size in (512, 1232)
        options_length = struct.unpack("!H", opt[9:11])[0]
        assert len(opt) == 11 + options_length
        if options_length:
            assert options_length == 12 and opt[11:15] == struct.pack("!HH", 10, 8)
    else:
        assert not opt
    return struct.pack("!HHHHHH", ident, 0x8183, 1, 0, 0, 0) + question


def fixture(udp, tcp, errors, seen):
    def answer(packet):
        data = response(packet)
        opt = packet[len(data):]
        seen.append((struct.unpack("!H", packet[:2])[0],
                     bool(opt and struct.unpack("!I", opt[5:9])[0] & 0x8000)))
        return data

    try:
        for _ in range(20):
            ready, _, _ = select.select([udp, tcp], [], [], 3)
            assert ready, "fixture timed out"
            if udp in ready:
                packet, peer = udp.recvfrom(4096)
                udp.sendto(answer(packet), peer)
            else:
                conn, _ = tcp.accept()
                with conn:
                    conn.settimeout(2)
                    length = struct.unpack("!H", read_exact(conn, 2))[0]
                    data = answer(read_exact(conn, length))
                    conn.sendall(struct.pack("!H", len(data)) + data)
    except Exception as exc:
        errors.append(exc)


def main():
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as udp, socket.socket(socket.AF_INET, socket.SOCK_STREAM) as tcp:
        tcp.bind(("127.0.0.1", 0))
        port = tcp.getsockname()[1]
        tcp.listen()
        udp.bind(("127.0.0.1", port))
        errors, seen = [], []
        server = threading.Thread(target=fixture, args=(udp, tcp, errors, seen), daemon=True)
        server.start()
        rows = diagnostic.run([("fixture", "127.0.0.1")], "example.test", port=port)
        server.join(timeout=3)
        assert not server.is_alive() and not errors, errors
    assert len(rows) == 20
    assert all(row["status"] == "response" and row["rcode"] == 3 for row in rows), rows
    assert [(row["transaction_id"], row["do"]) for row in rows] == seen
    assert all(row["source_port"] > 0 and row["request_opt"] == (row["bufsize"] is not None)
               and row["request_edns_version"] == (0 if row["request_opt"] else None) for row in rows)
    assert all(row["port"] == port and datetime.fromisoformat(row["timestamp_utc"]).utcoffset().total_seconds() == 0 for row in rows)
    timestamps = [datetime.fromisoformat(row["timestamp_utc"]) for row in rows]
    assert all((b - a).total_seconds() >= 0.24 for a, b in zip(timestamps, timestamps[1:]))
    for cold, warm in zip(rows[::2], rows[1::2]):
        assert (cold["phase"], warm["phase"]) == ("cold", "warm")
        assert cold["name"] == warm["name"] and cold["variant"] == warm["variant"]
    assert len({row["name"] for row in rows}) == 10
    assert json.loads(json.dumps(rows)) == rows
    # A forged transaction ID must not be accepted as a DNS response.
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as udp:
        udp.bind(("127.0.0.1", 0))
        def wrong_id():
            packet, peer = udp.recvfrom(4096)
            answer = response(packet)
            udp.sendto(bytes([answer[0] ^ 1]) + answer[1:], peer)
        server = threading.Thread(target=wrong_id, daemon=True)
        server.start()
        result = diagnostic.probe("127.0.0.1", udp.getsockname()[1], "udp", "x.example.test", 1, None, None)
        server.join(timeout=3)
        assert not server.is_alive() and result["status"] == "error" and "mismatch" in result["error"]
    command = [sys.executable, diagnostic.__file__, "--gateway", "192.168.1.1",
               "--public", "1.1.1.1", "--domain", "example.test"]
    denied = subprocess.run(command, capture_output=True, text=True, timeout=3)
    assert denied.returncode != 0 and "--authorize is required" in denied.stderr
    invalid = subprocess.run(command + ["--authorize", "--public6", "::1"], capture_output=True, text=True, timeout=3)
    assert invalid.returncode != 0 and "routable unicast" in invalid.stderr
    interface = socket.if_nameindex()[0][1]
    scoped = f"fe80::1%{interface}"
    assert diagnostic.address(scoped, gateway6=True) == scoped
    with patch.object(diagnostic.socket, "socket") as fake_socket:
        sock = fake_socket.return_value.__enter__.return_value
        sock.connect.side_effect = OSError("synthetic failure")
        result = diagnostic.probe(scoped, 53, "udp", "x.example.test", 1, None, None)
        sock.connect.assert_called_once_with(("fe80::1", 53, 0, socket.if_nametoindex(interface)))
        assert result["status"] == "error" and result["port"] == 53
    for address, public, gateway6 in (("fe80::1", False, True),
                                      ("fe80::1%no-such-interface", False, True),
                                      (scoped, True, False), ("2001:4860::1%lo", False, True)):
        try:
            diagnostic.address(address, public=public, gateway6=gateway6)
            raise AssertionError(f"accepted invalid scoped address {address}")
        except argparse.ArgumentTypeError:
            pass
    assert diagnostic.timeout_value("10") == 10
    for value in ("0", "11", "nan", "inf", "not-a-number"):
        try:
            diagnostic.timeout_value(value)
            raise AssertionError(f"accepted invalid timeout {value}")
        except argparse.ArgumentTypeError:
            pass
    print("DNS synthetic UDP/TCP self-test passed (21 loopback probes; no external network)")


if __name__ == "__main__":
    main()
