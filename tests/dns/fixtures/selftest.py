#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
#
# Neodots - Isolated DNS fixture self-test.
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

"""Exercise the real fixture process using only loopback."""
import json
from pathlib import Path
import socket
import struct
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import diagnostic

SERVER = Path(__file__).with_name('server.py')
SOURCES = []


def exchange(port, protocol, name='ok.fixture.test', qtype=1, edns=None, cookie=None):
    ident, question, packet = diagnostic.query(name, qtype, edns, cookie)
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM if protocol == 'udp' else socket.SOCK_STREAM) as sock:
        sock.settimeout(0.3)
        sock.connect(('127.0.0.1', port))
        SOURCES.append(sock.getsockname())
        sock.sendall(packet if protocol == 'udp' else struct.pack('!H', len(packet)) + packet)
        try:
            if protocol == 'udp':
                response = sock.recv(4096)
            else:
                header = sock.recv(2)
                if not header:
                    return None
                response = diagnostic.recv_exact(sock, struct.unpack('!H', header)[0], time.monotonic() + 1)
        except (TimeoutError, ConnectionResetError):
            return None
    rid, flags, qd, an, ns, ar = struct.unpack_from('!HHHHHH', response)
    assert rid == ident and qd == 1 and response[12:12 + len(question)] == question
    return flags & 15, an, response[12 + len(question):]


def check(mode, cases):
    SOURCES.clear()
    with tempfile.TemporaryDirectory() as directory:
        log = Path(directory) / 'queries.jsonl'
        command = [sys.executable, str(SERVER), '--port', '0', '--mode', mode, '--log', str(log),
                   '--max-queries', str(len(cases)), '--duration', '10', '--answer', '192.0.2.99']
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            ready = json.loads(process.stdout.readline())
            assert ready['ready']
            for options, expected in cases:
                result = exchange(ready['port'], **options)
                if expected is None:
                    assert result is None, (options, result)
                else:
                    assert result is not None and result[:2] == expected[:2], (options, result)
                    if len(expected) > 2:
                        assert expected[2] in result[2], (options, result)
            assert process.wait(timeout=3) == 0, process.stderr.read()
            rows = [json.loads(line) for line in log.read_text().splitlines()]
            assert len(rows) == len(cases)
            assert [(row['source_ip'], row['source_port']) for row in rows] == SOURCES
            assert all(a['monotonic_seconds'] <= b['monotonic_seconds'] for a, b in zip(rows, rows[1:]))
            return rows
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
            process.stdout.close()
            process.stderr.close()


def main():
    for transport in ('udp', 'tcp'):
        rows = check('healthy', [({'protocol': transport, 'name': 'x.fixture.test'}, (0, 1, socket.inet_aton('192.0.2.99'))),
                                 ({'protocol': transport, 'qtype': 28}, (0, 1, socket.inet_pton(socket.AF_INET6, '2001:db8::42'))),
                                 ({'protocol': transport, 'name': 'nxdomain.fixture.test'}, (3, 0)),
                                 ({'protocol': transport, 'name': 'refused.fixture.test'}, (5, 0)),
                                 ({'protocol': transport, 'edns': 1232, 'cookie': b'12345678'}, (0, 1))])
        assert rows[-1]['edns'] and rows[-1]['edns_size'] == 1232 and rows[-1]['cookie'] == b'12345678'.hex()
    rows = check('edns-drop', [({'protocol': 'udp', 'edns': 1232, 'cookie': b'12345678'}, None),
                                ({'protocol': 'udp'}, (0, 1)), ({'protocol': 'tcp', 'edns': 1232}, (0, 1))])
    assert [row['dropped'] for row in rows] == [True, False, False]
    rows = check('cold-first-failure', [({'protocol': p}, result) for p in ('udp', 'tcp') for result in (None, (0, 1))])
    assert [row['cold'] for row in rows] == [True, False, True, False]
    print('DNS fixture self-test passed (loopback only)')


if __name__ == '__main__':
    main()
