#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Bounded isolated DNS fixture.
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

"""Bounded synthetic DNS server for an isolated test network; never forwards queries."""
import argparse
import ipaddress
import json
import os
import select
import socket
import struct
import time


def name_at(data, offset):
    labels = []
    start = offset
    while True:
        if offset >= len(data):
            raise ValueError('truncated name')
        size = data[offset]
        offset += 1
        if not size:
            break
        if size > 63 or offset + size > len(data):
            raise ValueError('invalid or compressed name')
        labels.append(data[offset:offset + size].decode('ascii').lower())
        offset += size
        if offset - start > 255:
            raise ValueError('name too long')
    return '.'.join(labels), offset


def parse(data):
    if len(data) < 12:
        raise ValueError('short header')
    ident, flags, qd, an, ns, ar = struct.unpack_from('!HHHHHH', data)
    if flags & 0xf800 or qd != 1 or an or ns or ar > 1:
        raise ValueError('unsupported query')
    name, pos = name_at(data, 12)
    if pos + 4 > len(data):
        raise ValueError('short question')
    qtype, qclass = struct.unpack_from('!HH', data, pos)
    pos += 4
    question = data[12:pos]
    edns, cookie, size, do = False, None, None, False
    if ar:
        owner, pos = name_at(data, pos)
        if owner or pos + 10 > len(data):
            raise ValueError('invalid OPT')
        kind, size, ttl, length = struct.unpack_from('!HHIH', data, pos)
        pos += 10
        if kind != 41 or pos + length != len(data):
            raise ValueError('invalid OPT length')
        edns, do = True, bool(ttl & 0x8000)
        end = pos + length
        while pos < end:
            if pos + 4 > end:
                raise ValueError('short option')
            code, n = struct.unpack_from('!HH', data, pos)
            pos += 4
            if pos + n > end:
                raise ValueError('short option data')
            if code == 10:
                cookie = data[pos:pos + n].hex()
            pos += n
    elif pos != len(data):
        raise ValueError('trailing data')
    return ident, flags, name, qtype, qclass, question, edns, cookie, size, do


def reply(query, answer):
    ident, flags, name, qtype, qclass, question, edns, cookie, size, do = query
    if name == 'refused.fixture.test' or not (name == 'fixture.test' or name.endswith('.fixture.test')):
        rcode = 5
    elif name == 'nxdomain.fixture.test':
        rcode = 3
    else:
        rcode = 0
    address = (answer if qtype == 1 else ipaddress.IPv6Address('2001:db8::42')) if qclass == 1 and qtype in (1, 28) and not rcode else None
    record = b''
    if address:
        packed = address.packed
        record = b'\xc0\x0c' + struct.pack('!HHIH', qtype, 1, 0, len(packed)) + packed
    # Echo a minimal EDNS(0) OPT so ordinary resolvers can use EDNS.
    opt = b'\0' + struct.pack('!HHIH', 41, 1232, 0, 0) if edns else b''
    return struct.pack('!HHHHHH', ident, 0x8480 | (flags & 0x0100) | rcode, 1, bool(record), 0, bool(opt)) + question + record + opt, rcode


def read_exact(conn, n, deadline):
    result = b''
    while len(result) < n:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError('deadline')
        conn.settimeout(min(1, remaining))
        chunk = conn.recv(n - len(result))
        if not chunk:
            raise EOFError
        result += chunk
    return result


def serve(args):
    family = socket.AF_INET6 if args.bind.version == 6 else socket.AF_INET
    seen = set()
    count = 0
    deadline = time.monotonic() + args.duration
    with socket.socket(family, socket.SOCK_STREAM) as tcp, socket.socket(family, socket.SOCK_DGRAM) as udp:
        tcp.bind((str(args.bind), args.port))
        port = tcp.getsockname()[1]
        tcp.listen(8)
        udp.bind((str(args.bind), port))
        with open(args.log or os.devnull, 'w', encoding='utf-8', buffering=1) as log:
            print(json.dumps({'ready': True, 'bind': str(args.bind), 'port': port}), flush=True)
            def process(data, protocol, peer):
                nonlocal count
                count += 1
                metadata = {'protocol': protocol, 'source_ip': peer[0], 'source_port': peer[1],
                            'monotonic_seconds': time.monotonic()}
                try:
                    query = parse(data)
                    ident, flags, name, qtype, qclass, _, edns, cookie, size, do = query
                    key = (protocol, name, qtype, qclass)
                    cold = key not in seen
                    seen.add(key)
                    dropped = (args.mode == 'edns-drop' and protocol == 'udp' and edns) or (args.mode == 'cold-first-failure' and cold)
                    response, rcode = reply(query, args.answer)
                    print(json.dumps({**metadata, 'name': name, 'qtype': qtype, 'qclass': qclass,
                                      'id': ident, 'edns': edns, 'edns_size': size, 'do': do,
                                      'cookie': cookie, 'cold': cold, 'dropped': dropped,
                                      'rcode': None if dropped else rcode}), file=log, flush=True)
                    return None if dropped else response
                except (ValueError, UnicodeDecodeError, struct.error) as exc:
                    print(json.dumps({**metadata, 'error': str(exc)}), file=log, flush=True)
                    return None
            while count < args.max_queries:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    break
                ready, _, _ = select.select([udp, tcp], [], [], remaining)
                if udp in ready and count < args.max_queries:
                    data, peer = udp.recvfrom(65535)
                    response = process(data, 'udp', peer)
                    if response is not None:
                        udp.sendto(response, peer)
                if tcp in ready and count < args.max_queries:
                    conn, peer = tcp.accept()
                    with conn:
                        try:
                            while count < args.max_queries:
                                length = struct.unpack('!H', read_exact(conn, 2, deadline))[0]
                                response = process(read_exact(conn, length, deadline), 'tcp', peer)
                                if response is None:
                                    break
                                conn.sendall(struct.pack('!H', len(response)) + response)
                        except (OSError, EOFError, struct.error):
                            pass


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bind', type=ipaddress.ip_address, default=ipaddress.ip_address('127.0.0.1'))
    parser.add_argument('--port', type=int, default=53)
    parser.add_argument('--answer', type=ipaddress.IPv4Address, default=ipaddress.IPv4Address('192.0.2.42'))
    parser.add_argument('--mode', choices=('healthy', 'edns-drop', 'cold-first-failure'), default='healthy')
    parser.add_argument('--log', help='JSONL query log, overwritten on startup')
    parser.add_argument('--max-queries', type=int, default=256)
    parser.add_argument('--duration', type=int, default=120, help='maximum lifetime in seconds')
    args = parser.parse_args()
    if not 0 <= args.port <= 65535 or not 1 <= args.max_queries <= 10000 or not 1 <= args.duration <= 3600:
        parser.error('port, max-queries or duration outside allowed bounds')
    if args.bind.is_unspecified or args.bind.is_multicast:
        parser.error('bind to a specific unicast test interface')
    serve(args)


if __name__ == '__main__':
    main()
