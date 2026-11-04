<!--
SPDX-License-Identifier: GPL-3.0-only

Neodots - Isolated DNS fixture usage.

Copyright (C) 2026 kaayzouee
Author: https://github.com/kaayzouee

This program is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation, version 3 of the License.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
Public License for more details.

You should have received a copy of the GNU General Public License along
with this program. If not, see <https://www.gnu.org/licenses/>.
-->

# Isolated DNS fixture

Run only on a loopback or isolated test interface; this server never forwards queries or changes DNS configuration.

```
python3 tests/dns/fixtures/server.py --bind 127.0.0.1 --port 0 --mode healthy --log /tmp/dns-fixture.jsonl
python3 tests/dns/fixtures/selftest.py
```

The first stdout line is a JSON ready notification with the actual bound port. Both UDP and TCP use that port. Default port is 53; `--port 0` picks an ephemeral port. `--answer` sets the A address (default `192.0.2.42`); AAAA is `2001:db8::42`. All names in `fixture.test` are positive except `nxdomain.fixture.test` (NXDOMAIN) and `refused.fixture.test` (REFUSED); outside names are REFUSED. Other types return NODATA. TTL is zero.

Modes: `healthy` always answers; `edns-drop` drops UDP queries with any OPT record, but answers TCP and plain UDP; `cold-first-failure` drops the first query for each `(transport, name, type, class)` and answers subsequent ones. Dropped TCP requests close the connection. Restart to reset state. This is synthetic behavior, not a cache.

`--log` writes and flushes JSONL per query, including transport, source IP and port, monotonic seconds at receipt (only differences within the same host are meaningful), name, numeric qtype, EDNS size, DO bit, COOKIE bytes in hex (null if absent), cold state and drop/rcode. Malformed requests are logged as errors. The file is overwritten at startup. The fixture exits after `--max-queries` (default 256, max 10000) or `--duration` seconds (default 120, max 3600). A TCP connection is idle-limited to one second; requests, including malformed ones, count toward the limit. It only supports ordinary uncompressed single-question DNS queries and one optional OPT.
