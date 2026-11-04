<!--
SPDX-License-Identifier: GPL-3.0-only

Neodots - Safe opt-in DNS diagnostic usage.

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

# Opt-in DNS behavior diagnostic

This standalone Python 3 diagnostic does not change system DNS, install anything,
or run as part of production or the Nix test suite. Obtain authorization for
**both resolver addresses, every queried domain, and the network path** before
running it. There are no default targets or domains. Enter numeric IPv4 gateway
and public resolver addresses explicitly; the public address must be globally
routable. Loopback, multicast and unspecified addresses are rejected. IPv6
targets are individually optional. For a link-local IPv6 gateway, specify an
existing interface explicitly, for example `--gateway6 'fe80::1%wlan0'` with
the actual authorized address and interface. Other scoped addresses and
link-local public resolvers are rejected. The gateway is not discovered or
verified to actually be a gateway.

For example, replace every placeholder with authorized values (the following is
not a runnable command until then):

```sh
python3 tests/dns/diagnostic.py --authorize \
  --gateway AUTHORIZED_GATEWAY_IPV4 --public AUTHORIZED_PUBLIC_IPV4 \
  --domain AUTHORIZED_DOMAIN
```

Optionally provide `--gateway6` and/or `--public6` with authorized IPv6
addresses, and `--qtype AAAA` to query AAAA records instead of the default A.
The query transport family and record type are independent. The suffix must be
an ASCII domain of at least two labels. Each query name is a random subdomain;
make sure the domain owner permits random names and the expected NXDOMAIN or
wildcard behavior. Queries may reach upstream/authoritative servers and appear in
logs. Store stdout securely if redirected: it contains IP addresses and names.
No report file is created or shared by the program.

For each target, the program sequentially sends at most **20 queries** to port
53: UDP and TCP, each with no EDNS, EDNS size 512, EDNS size 1232, EDNS
1232 plus an eight-byte client cookie, and EDNS 1232 with the DNSSEC OK (DO)
bit. Each variant sends a new random name once (cold) and repeats it (warm).
The maximum with all four targets is 80 queries. The fixed minimum delay between
probes is 0.25 seconds. The per-probe timeout defaults to 5 seconds and can be
set with `--timeout` to a value greater than zero and at most 10 seconds; there
is no application retry. Connection setup/OS scheduling may add time. UDP
truncation is reported, not automatically retried over TCP; TCP probes are
separate. One JSON document is emitted on stdout, with UTC start timestamp,
transaction ID, destination port, elapsed time, timeout/error or response header
rcode, truncation, and counts for each attempt.
The JSON records cache state, late responses and UDP/TCP comparison as `unknown`;
it does not infer these from timings. A DNS response including NXDOMAIN is not an
overall pass or proof of correctness.
The exit code indicates invocation success, not that all probes succeeded.

## Interpretation and limitations

* Cold/warm are **labels**, not proof of a cache miss or hit. Random names reduce
  prior exact-name cache hits but negative caching, wildcards, prefetch, upstream
  caches, DNSSEC and network conditions can influence results. There is no cache
  flush. Comparisons across variants, transports and targets use **different
  names**, so timing and response differences are not controlled experiments.
* The tool sends a client cookie but does not parse or validate returned EDNS
  options, server cookies, response records, extended rcodes, DNSSEC, or
  authenticated answers. The rcode is only the low four header bits. It checks
  the response ID, QR/opcode, and an exactly echoed uncompressed question; it
  does not fully validate the DNS message. Compressed/altered questions may be
  rejected even if otherwise valid. Counts may describe malformed records.
* No packet capture is performed. A timeout means no accepted response during
  the probe window; this tool does **not** capture or establish absence of late
  responses, retransmissions by other software, or traffic on other interfaces.
  Do not capture traffic unless separately authorized, and use a separately
  approved capture procedure if needed. This is not a VPN leak test, DNS-over-TLS
  test, benchmark, or production acceptance test.

## Local self-test

```sh
python3 tests/dns/selftest.py
```

The test starts synthetic UDP and TCP DNS responders bound to IPv4 loopback on
an ephemeral port, validates the wire variants and cold/warm pairing, and tests
that missing authorization and an invalid target fail before probing. It makes
no external network requests and does not exercise a real resolver or IPv6.

## Isolated DNS fixture and QEMU test

The [fixture](fixtures/README.md) never forwards DNS and has independently tested
healthy, EDNS-UDP-drop and synthetic first-query-failure modes. Run its loopback
self-test with `PYTHONDONTWRITEBYTECODE=1 python3 tests/dns/fixtures/selftest.py`.
The explicitly invoked QEMU test uses disposable guests, a private virtual switch,
synthetic addresses and no physical networking; it is not part of default CI:

```sh
nix build --offline --no-write-lock-file --no-link -L 'path:.#dns-qemu'
```

The `path:` reference includes new untracked test files in a working checkout.
Run only on a builder with Nix's Linux sandbox enabled and a private network
namespace. The NixOS test driver starts `vde_plug2tap` for every test VLAN; a
privileged unsandboxed or interactive driver could create a host TAP, so do not
run this test that way or attach the switch to a physical interface. The test
here was built with `nix config show sandbox` reporting `true`.
Nix may need available build inputs and KVM on the builder; lack of either is a
skip or build error, not a pass. Nix fixed-output derivations can still fetch
sources even with `--offline`; pre-provision inputs for a fully offline build.
The guest network itself has no production-network interface. See the investigation
report for actual tested scenarios, observed results and limitations.
