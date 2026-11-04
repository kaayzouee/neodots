<!--
SPDX-License-Identifier: GPL-3.0-only

Neodots - Evidence-backed DNS root-cause investigation.

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

# DNS root-cause investigation

Date: 2026-11-04. **Status: investigation incomplete; exact failing component and historical cause unverified.** No production DNS or network setting was changed. The earlier DNS observations below are **owner-supplied evidence**, not independently rerun in this investigation; their raw capture and dig transcripts were not provided. Runtime and configuration observations were inspected read-only. See [remediation plan](DNS-REMEDIATION-PLAN.md).

## Problem and evidence boundaries

Since 2025 the owner reports that NixOS installation media and installed systems sometimes showed a connected network while applications could not reach the Internet, across multiple networks; manually configured public DNS restored connectivity, and other distributions reportedly worked on the hardware. The failing resolver configurations, actual application packets, and network states were not captured. These reports cannot establish that all failures were DNS, had one cause, or were NixOS-specific. The current router observation is a separate event.

On 2026-11-04, the owner reports wlp98s0 at 192.168.2.6, gateway and DHCP/DNS 192.168.2.253, and DHCP-advertised IPv6 DNS fe80::e660:4dff:fecc:8847%wlp98s0. IPv4 and IPv6 gateway neighbor MAC addresses matched. This supports a common gateway/network device, **not** a particular manufacturer, model, firmware or DNS proxy. Public IPv4 and gateway ping, public UDP DNS, local TCP DNS, and current static DNS worked. These are time-limited observations, not proof of historical connectivity.

## Historical configuration sources and timeline

The owner reports using `networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];` in the predecessor NixOS configuration dating to 2025. This is owner-provided evidence, not an independently verified copy of that file. Unauthenticated requests to [the predecessor repository](https://github.com/kaayzouee/nixos-dotfiles) returned 404; this does not distinguish private, renamed, removed, or nonexistent. GitHub CLI had no configured authentication (`gh api repos/kaayzouee/nixos-dotfiles` exited 4), and a local path search found no predecessor checkout. The remaining 2025 configuration, revision and actual resolver ownership are unavailable pending an authorized copy. The October 2026 finding below is scoped **only to Neodots**: it is not the first known use of explicit public DNS across the owner's NixOS configurations.

## Repository history — earliest verifiable Neodots evidence

The parentless root commit `cb50545acaa4b7710394ec40fe44c67d8949fa87` (2026-09-24, author timezone +07) already contained **commented-out** static `1.1.1.1`/`8.8.8.8` text. It is not evidence that it was active then or establishes when it first worked. The active root configuration used NetworkManager `dns=none`, disabled resolved/resolvconf, pointed the resolver at localhost, and enabled Stubby with encrypted Cloudflare/Google upstreams. The same root commit already included the Proton VPN package; package presence does not demonstrate use or DNS routing.

Commit `76e609bd64c6879452e59ee7167cdf4c916ab845` on 2026-09-26 added interface-specific DHCP; `466a5201a94adb63fb250a0806b752432acb53fa` later that day removed it and disabled global dhcpcd/useDHCP, citing competing clients. `96e506adc705ef569a6e30f9a708fcdee4769f60` on 2026-10-09 moved the package declaration while retaining Proton VPN. `eec62cd52010a749b058feebbfb1a4530d8207c4` on 2026-10-22 changed nixpkgs from 26.05 to unstable. The first verified **active** static public resolver in the available first-parent history is `3771549bc28838215979068019723d455a839521` (2026-10-29 +07), which disabled Stubby and replaced localhost with public nameservers. Its restoration comment is not independent proof of the 2025 state. The repository is not shallow, but its root cannot establish unpublished earlier history; the original failure, NixOS revision, DNS ownership and VPN use remain unrecorded.

## DNS-management ownership comparison

| Property | Predecessor circa 2025 | Current Neodots |
|---|---|---|
| Declared nameservers | Owner reports `1.1.1.1`, `8.8.8.8` through `networking.nameservers` | Static file: `1.1.1.1`, `8.8.8.8` |
| DNS manager and actual file owner | Unknown; original files and runtime state unavailable | NixOS `environment.etc`, store-backed file |
| NetworkManager DNS mode | Unknown | `none` |
| DHCP-provided DNS | Precedence and use unknown | Discovered by NM, not installed into active resolver file |
| systemd-resolved / resolvconf | Unknown | Both disabled |
| Faulty DHCP DNS | Historical behavior unverified | Bypassed by static file, subject to routing and applications using their own resolver |

An explicit `networking.nameservers` declaration alone does not prove which server a historical application actually used. Its effects depend on the pinned NixOS modules, DNS manager, network profiles, resolver state and application; recover these before making a historical attribution.

### Version-specific nameserver precedence

The historical pin is unavailable. As a **source-only approximation**, NixOS 25.11 revision [`abaa3ca1c9f4d3e7fae9576e4495bd64e10b46a0`](https://github.com/NixOS/nixpkgs/commit/abaa3ca1c9f4d3e7fae9576e4495bd64e10b46a0), dated 2025-12-31, provides a concrete 2025 comparison, not evidence of the owner's version. Its [scripted networking module](https://github.com/NixOS/nixpkgs/blob/abaa3ca1c9f4d3e7fae9576e4495bd64e10b46a0/nixos/modules/tasks/network-interfaces-scripted.nix) contributes declared nameservers through `resolvconf -m 1 -a static` only when resolvconf is enabled and networkd is not used. This is an openresolv contribution, not an unconditional replacement of DHCP DNS. [openresolv ordering](https://github.com/NetworkConfiguration/openresolv/blob/v3.17.0/resolvconf.8.in) also depends on key order, VPN/dynamic order, metrics and exclusive/private/local settings: a metric 0 contribution can precede metric 1. Inspect `resolvconf -l` and `resolvconf -i` at runtime; DHCP DNS can coexist or take precedence depending on the configuration. The [25.11 NetworkManager module](https://github.com/NixOS/nixpkgs/blob/abaa3ca1c9f4d3e7fae9576e4495bd64e10b46a0/nixos/modules/services/networking/networkmanager.nix) defaults to `dns=default`, internal DHCP and `rc-manager=resolvconf` when enabled, otherwise unmanaged. `useDHCP=false` does not disable NetworkManager's DHCP. With [systemd-resolved](https://github.com/NixOS/nixpkgs/blob/abaa3ca1c9f4d3e7fae9576e4495bd64e10b46a0/nixos/modules/system/boot/resolved.nix), declared nameservers feed global resolved DNS and NetworkManager integrates differently. Actual 2025 settings, profile priorities, other services and runtime ordering remain unknown.

At that same 2025 source revision, [resolvconf's `dnsExtensionMechanism` option](https://github.com/NixOS/nixpkgs/blob/abaa3ca1c9f4d3e7fae9576e4495bd64e10b46a0/nixos/modules/config/resolvconf.nix) defaults to true and contributes `options edns0` when resolvconf manages the file. The current lock retains that default. This makes EDNS use by glibc plausible in such a configuration, but does not establish the historical effective setting.

An offline evaluation of the **current** lock (`1d060086d60cb76a40cf37109f979d88a5bd6396`, not 2025) confirms that NM plus declared nameservers generates a static resolvconf contribution; with `dns=none`, resolvconf disabled and a separately declared static file, `networking.nameservers` does not rewrite that file. Setting `system.stateVersion = "25.11"` in this evaluation does not select 25.11 modules. Evaluation proves neither actual DHCP precedence nor application packets.

## Current resolver ownership — confirmed read-only

In the prior investigation, the working tree including then-existing staged and unstaged edits was evaluated, not reset. Its nixpkgs pin was `1d060086d60cb76a40cf37109f979d88a5bd6396`; live system reports `26.11.20261103.1d06008`, NetworkManager 1.58.1, glibc 2.44, systemd 262. Owner's dig was BIND 9.20.30. `system.stateVersion = 26.11` is a compatibility setting, not the package revision. At that earlier review the working lock differed from its then-HEAD; the present checkout at `0456780` records this pin. Offline evaluation reports NM enabled, `dns=none`, `useDHCP=false`, dhcpcd disabled, resolved/resolvconf/Stubby disabled, `networking.nameservers=[]`, and the expected exact resolver text. The [network module](../../modules/system/networking.nix) owns the explicit definitions; module-option metadata names that module for NM DNS, resolved and Stubby. Evaluating the effective values succeeded; it does not prove every profile's runtime behavior or that the current checkout is identical to the booted generation.

```text
connection -> NetworkManager (live: DHCP client internal)
   |         -> DHCP addressing/routes (not NixOS dhcpcd)
   +--------> learned DHCP IPv4/IPv6 DNS shown in NM, connection metadata
                  |  dns=none + rc-manager=unmanaged: not installed in resolv.conf
NixOS environment.etc."resolv.conf" (static, store-backed, owner: network module)
   -> /etc/resolv.conf -> nameserver 1.1.1.1, then 8.8.8.8
application -> glibc / nscd -> NSS: mymachines files myhostname dns
   -> on DNS lookup, resolver reads /etc/resolv.conf
   -> configured public addresses, subject to routing/VPN
```

NetworkManager may discover DNS while intentionally leaving the static file alone; this is **not** a conflict by itself. Live `/etc/NetworkManager/NetworkManager.conf` has `dhcp=internal`, `dns=none`, `rc-manager=unmanaged`; `/etc/resolv.conf` resolves to a Nix-store file containing those two nameserver lines. Live `nsswitch.conf` has `hosts: mymachines files myhostname dns`. The active `nscd` service forwards NSS requests; its hosts cache is enabled with configured positive and negative TTLs zero. Effective caching cannot be concluded solely from these settings: e.g. DNS TTL handling can matter. Resolved, Stubby and dnsmasq services were inactive when inspected. Other app-specific caching is not excluded.

For ordinary NSS lookups, preceding NSS sources or nscd may answer before DNS. `dig @server` bypasses this NSS chain and selects its own destination. Browsers, independent libraries, VPN clients and systemd-resolved users may choose another path. Proton VPN is installed (4.16.5), not proof of an active VPN. The active Wi-Fi profile read-only inspection reported IPv4 and IPv6 methods `auto`, `ignore-auto-dns=no`, no manually configured DNS addresses and priority `0`; other profiles and application/VPN behavior were not exhaustively inspected. No DNS-leak claim is warranted. Evaluated firewall policy is enabled; no DNS-specific rule was identified in the repository networking module, but the complete live packet rules and VPN-installed rules were not inspected. Nothing here establishes the ownership or selected DNS of the historical default configuration.

Recheck without changing networking (avoid displaying profile secrets):

```sh
nixos-version; NetworkManager --version; getconf GNU_LIBC_VERSION
readlink -f /etc/resolv.conf
nmcli -t -f DEVICE,TYPE,STATE device status
systemctl is-active NetworkManager.service systemd-resolved.service nscd.service
nix eval --offline --no-write-lock-file --json .#nixosConfigurations.nixos.config.networking.networkmanager.dns
nix eval --offline --no-write-lock-file --raw .#checks.x86_64-linux.config-invariants.drvPath
```

The last command evaluates repository policy, not connectivity. In this working pin's NetworkManager module, the `dns` option defaults to `default`, DHCP defaults to `internal`, and generated `rc-manager` is `resolvconf` when resolvconf is enabled and `unmanaged` otherwise; `settings` can override generated values. Neodots explicitly overrides DNS to `none`. This source-level comparison is not a test of a complete standard system: the actual result also depends on the resolved and resolvconf modules and other definitions. A complete option audit should review generated settings, profile DNS/ignore-auto-dns and VPN configuration with secrets redacted. NixOS defaults must be checked against the **exact** nixpkgs revision of each test, not projected backward from this host.

## Supplied DNS observations, not a new reproduction

| Target / query | Reported result | Interpretation |
|---|---|---|
| Gateway UDP, EDNS + COOKIE, fresh names | repeated timeouts | **Observed:** a client deadline was exceeded, not necessarily packet loss. |
| Gateway UDP, EDNS, no COOKIE | timeout | COOKIE alone is not sufficient to explain the observed pattern. |
| Gateway UDP, no EDNS | answers in 6–113 ms | Contrasts with EDNS, but different names and time/order confound a causal claim. |
| Gateway UDP, EDNS buffer 512 | timeout in an earlier test | Smaller advertised receive buffer did not reliably avoid the symptom. |
| Gateway TCP, EDNS | response ~69 ms, OPT present | Transport/path difference observed; why TCP works is unknown. |
| Public resolver UDP EDNS | response ~268 ms | External DNS reachable for that sample, not universal availability. |
| Previously queried `example.com` | EDNS and non-EDNS often a few ms, decreasing TTL | Consistent with caching, but exact cache location and hit status were not established. |
| Advertised IPv6 endpoint | earlier timeout reported | Insufficient to establish independent IPv6 failure, scope, routing, transport or reproducibility. |

Fresh random labels reduce ordinary name-cache contamination but do not guarantee cold authoritative or upstream state; negative caching, wildcard synthesis, shared suffix caches and retries may matter. Query types, response code and authority records matter: an NXDOMAIN or NOERROR/NODATA can be a valid DNS response, not a transport failure. Compare equivalent responses, not merely answer counts.

### Historical commands and expected versus actual

The following are examples from the supplied test, retained as a transcript, not commands run by this investigation. Only repeat them after authorizing the resolver, domain owner and network path; choose a fresh approved name and avoid assuming `example.com` delegates randomized test queries to you.

```sh
dig @192.168.2.253 probe-1793800613.example.com A +time=5 +tries=1
dig +nocookie @192.168.2.253 probe-1793800552-b.example.com A +time=5 +tries=1
dig +noedns @192.168.2.253 probe-1793800557-c.example.com A +time=5 +tries=1
dig +tcp @192.168.2.253 probe-1793800613.example.com A +time=5 +tries=1
```

Expected: a matching DNS response within the deadline for each valid request, whether positive or a valid negative response. Reported actual: the first two timed out, the non-EDNS UDP and EDNS TCP requests returned responses. Different names and the TCP retry of a name already queried introduce cache and ordering confounds. The synthetic test below reproduces an EDNS-drop mechanism, not the actual gateway implementation or proof of the historical incident.

### Supplied packet timeline

At 20:49:19.791732 an EDNS UDP query ID 62873 was sent; at 20:49:22.807748 an EDNS query ID 52550 was sent. At 20:49:25.772652 a REFUSED for 62873 arrived (~5.98 s after transmission). At 20:49:25.825819 a non-EDNS query ID 57358 was sent; at 20:49:25.838077 its successful response arrived (~12 ms), together with a successful response for ID 52550 (~3.03 s after that query). Correlation above comes from the owner-supplied summary; no raw packet bytes were available for independent header, OPT, endpoint, fragmentation or checksum validation. Late replies can arrive after a particular `dig` deadline. Near-coincident responses are compatible with queueing or shared upstream work, but do not establish either. REFUSED is a valid response code and does not identify which device chose it. Missing optional OPT/options alone is not proof of a malformed DNS message.

### What operation fails and where?

**Confirmed from supplied client-side observations:** some gateway-directed, EDNS-enabled UDP requests for apparently uncached names exceeded the client's wait while other local non-EDNS UDP and TCP requests succeeded. **Likely:** the gateway forwarding path interacts poorly with those requests or their timing. **Unverified:** whether the client, local gateway, another proxy, upstream resolver, return path or an interaction is responsible; which EDNS feature matters; whether there is a standards violation; why TCP succeeds or warm names are fast. Client capture alone cannot distinguish a forward failure from upstream delay, response loss, gateway relay failure, or client rejection. COOKIE is **ruled out as the sole necessary trigger in the reported comparison**, not ruled out as a contributing factor. A gateway-side capture on both sides plus logs is required to isolate the failing operation.

## Isolated QEMU reproduction and application behavior

The opt-in [QEMU test](../../tests/dns-qemu.nix) boots a disposable fixture and NixOS clients on a test-driver private switch, with the QEMU user-mode network interface removed. dnsmasq advertises `198.51.100.1`; a Python server responds only for `fixture.test` and never forwards. A second server at `198.51.100.2` represents an independent static resolver, not the actual public services. The client importing the production module overrides only its resolver-file content inside the VM with this synthetic address. The `legacy-nameservers-only` reconstruction adds the owner-reported public addresses plus NetworkManager, an automatic Ethernet profile, `useDHCP=false`, and test-framework interface settings. These added settings and the 2026 package pin are **not verified 2025 settings**. No guest uses personal disks, secrets or physical interfaces.

Diagnostic and five-VM assertion runs on Nixpkgs `1d060086d60cb76a40cf37109f979d88a5bd6396`, NetworkManager 1.58.1, openresolv 3.17.4, glibc 2.44, systemd 262 and BIND 9.20.30 produced the following. The DNS fixture decodes received DNS wire messages and logs source, transport, type, EDNS, COOKIE, timing and result; this is fixture-side application logging, **not an independent pcap**.

| Configuration / controlled condition | Observed result |
|---|---|
| Minimal historical-style reconstruction, healthy DHCP DNS | `/etc/resolv.conf` listed `198.51.100.1`, then `1.1.1.1`, then `8.8.8.8`, with `options edns0`; NSS queried the DHCP server and got the synthetic answer. The public addresses were configured but had no external network path. |
| Standard NM, healthy DHCP DNS | DHCP-advertised server appeared in the resolver file and received application queries. |
| Standard NM, EDNS UDP drop | Direct `dig` with EDNS timed out; non-EDNS UDP and EDNS TCP succeeded. `getent ahostsv4` failed with status 13. Fixture logs show application A and AAAA UDP queries with EDNS payload 1200 and no COOKIE, dropped and retried. |
| DHCP DNS completely unavailable | DNS lookups failed; `curl` by synthetic hostname timed out, while HTTP by numeric `198.51.100.1` returned 200. A separately configured static resolver still answered. |
| Current-policy analogue | NM learned `.1`, while the file selected synthetic `.2`; the fixture at `.2` received NSS queries even while `.1` was unavailable. This tests ownership with substituted addresses, not reachability of the real public resolvers. |
| systemd-resolved, healthy DNS | The file pointed to `127.0.0.53`; Python `socket.getaddrinfo` succeeded, and the DHCP fixture received the query. Faulty-DNS fallback under resolved was not tested. |
| Non-NixOS distribution / IPv6 transport | Not tested. No pinned non-NixOS image was found locally; no comparison or IPv6-link-local transport claim is made. AAAA query type over IPv4 is not IPv6 transport. |

The test did not independently capture packets with tcpdump, test `getaddrinfo` failure through resolved, or establish the actual router's fallback behavior. Its fixture log identifies received DNS packets and destination via the specific bound endpoint, but is not an independent network capture. The full 2025 release, DHCP setup, NSS settings and service topology remain unreconstructed.

For example, one diagnostic run logged `nss.fixture.test` from `198.51.100.129`: UDP A ID 20381 and AAAA ID 45, EDNS size 1200 without COOKIE, both dropped at fixture monotonic time 67.785 s, retried about 5 seconds later; A ID 5058 was also retried. Exact IDs and times vary. This demonstrates that **this** configuration can turn an EDNS-specific DNS transport problem into an ordinary application failure. It does not prove the real gateway would fail the same application packets or that its delay and cache mechanisms match the synthetic drop.

Run from the repository root:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 tests/dns/selftest.py
PYTHONDONTWRITEBYTECODE=1 python3 tests/dns/fixtures/selftest.py
nix build --offline --no-write-lock-file --no-link -L 'path:.#dns-qemu'
```

The `path:` flake includes untracked working files. Run only under a Linux Nix builder with sandbox and private network namespace enabled: the upstream test driver attempts `vde_plug2tap` for each VLAN, so an unsandboxed privileged or interactive driver could create a host TAP. The test was built with `nix config show sandbox` reporting `true`; no physical interface was attached. VM tests require a suitable QEMU builder; missing KVM or inputs means skip/failure, never pass. `--offline` does not prevent a missing fixed-output source from being fetched by a builder: one such dependency was fetched during preparation. The test guest network remained isolated. Fixture documentation describes healthy, EDNS-drop, first-query-failure, NXDOMAIN and REFUSED modes. First-query state is synthetic and does not establish a router cache. No production DNS, Wi-Fi, DHCP or router setting was modified.

## Hypothesis register

| ID and hypothesis | Status / confidence | Supporting and contradicting evidence; discriminating test |
|---|---|---|
| H1 Gateway path mishandles EDNS over UDP | Likely / moderate for association, low for component | Owner reports EDNS timeouts, non-EDNS and TCP answers; names and order differed, and captures do not isolate gateway versus upstream. Controlled same-name comparisons and authorized paired ingress/egress capture required. |
| H2 Upstream stalls on cold queries | Unverified / low | Reported fast repeat answers are consistent with caching; cache location/state and upstream transactions are unknown. Controlled cache-state and upstream logs required. |
| H3 NetworkManager selects unexpected DNS | Unverified / low historically | A connected interface can learn DHCP DNS; no historical effective config or packet destination exists. Inspect historical profile and runtime destination. |
| H4 `networking.nameservers` does not provide intended effective DNS | Reproduced / high for this reconstruction; unverified historically | The controlled guest placed DHCP DNS before both declared public servers and sent queries to DHCP DNS. Other service/profile settings can change order; the actual 2025 modules and effective order are unknown. Recover the historical pin and runtime state. |
| H5 resolvconf or resolved changes ownership | Unverified / low historically | Both can manage DNS differently; neither is active in current static policy. Recover original settings and compare actual file ownership. |
| H6 IPv6 resolver selection causes timeout | Unverified / low | A link-local timeout was reported; scope, IPv6 route and independent transport tests were not established. Test scoped transport and A versus AAAA separately. |
| H7 glibc retry/fallback differs across distributions | Unverified / low | Other distributions reportedly worked, but no matched captures or exact software versions exist. Compare resolver implementations with the same fixture and packet traces. |
| H8 Multiple networking services interfere | Unverified / low historically | Repository history mentions competing DHCP clients in 2026; that is not proof of a 2025 conflict. Recover active-service and lease logs. |
| H9 Historical and current problems are independent | Unverified / low | Multiple networks and years allow it; no matched historical packets connect or separate them. Recover a failed historical setup and compare controlled traces. |

## Safe reproduction and comparison design

Use the opt-in bounded probe in `tests/dns` only with explicitly authorized destinations and a domain approved for test queries; consult its help and README. It tests protocol behavior directly, not NSS or a browser. Run with a unique label series and repeat selected names, recording exact timeout and all response codes; repeats suggest but cannot prove cache hits. Order effects and randomized label/NXDOMAIN behavior must be documented. A controlled authoritative test zone with known answers is better than random labels beneath a public zone. A zero-answer negative response must not be classified as a network failure. Do not run a flood, use private domains, or commit logs with private data.

For packet-level isolation use an explicitly authorized, otherwise idle disposable client/test network, and capture only the dedicated test client's DNS traffic to the chosen target and port, including UDP and TCP. A narrow capture may still include other apps on that client; stop them or use a dedicated isolated source address. Record timestamps, endpoints, IDs, exact question and DNS flags/OPT/COOKIE/DO/buffer, packet sizes, fragmentation, response code, flags and byte-level differences. A timed-out client socket may close before a late reply: capture must continue long enough to observe it. Store raw captures outside the repo with restrictive permissions, inspect locally, and publish only sanitized synthetic excerpts. Lack of OPT in a reply is not by itself malformed. For fragmentation include IP fragments in the capture filter, not only packets with DNS port 53. Comparing gateway ingress with its authorized upstream egress is necessary to identify forwarding vs upstream/return-path failures; obtain administrative permission first.

For client comparisons prepare disposable NixOS instances using (1) that revision's standard NM DNS settings, (2) resolved integration, and (3) the existing static policy, plus a comparison distribution if practical. Connect each equivalently to the *real target gateway*, for example using an owner-authorized bridged test setup; VM NAT often supplies a different DNS proxy. Verify routes, advertised/selected DNS and actual packet destination, not merely VM configuration. Do not change the live host or boot physical installation media without authorization. Match query type, name, time and gateway; use controlled independent cold names and repeats. Record NixOS, NM, glibc/systemd versions, NSS and resolver ownership. Run `getent ahosts`, IPv4/IPv6 `getent` variants and a small `getaddrinfo` client with captured A/AAAA timing, in addition to direct DNS probes. Test browser secure DNS separately and applications with independent DNS libraries. A normal host lookup against the current static public nameservers does not test the gateway. Verify whether application packets actually contain EDNS before attributing dig's EDNS behavior to glibc. Compare simultaneous A/AAAA versus sequential behavior in disposable clients; `single-request` and `single-request-reopen` are diagnostic options, not production fixes. Observe DNS destinations with VPN active only when authorized and compare VPN split-domain behavior.

## Upstream evidence and applicability

* [NetworkManager DNS and rc-manager documentation](https://networkmanager.dev/docs/api/latest/NetworkManager.conf.html) describes DNS management modes; the live NixOS-generated config above, not generic upstream autodetection, determines this host.
* [NixOS 25.11 NM module](https://raw.githubusercontent.com/NixOS/nixpkgs/nixos-25.11/nixos/modules/services/networking/networkmanager.nix) is a version-specific example of resolver integration, not proof of the 2025 host's exact revision or defaults.
* [glibc resolv.conf(5)](https://man7.org/linux/man-pages/man5/resolv.conf.5.html) documents nameserver ordering, `edns0`, timeout/attempts and A/AAAA parallelism and appliance-sensitive diagnostic options. One resolver timeout is not necessarily the entire application's lookup deadline. The current static file does not specify `edns0`; real-gateway application traffic remains unmeasured. The isolated resolvconf-managed guests do set it and their application query behavior is recorded above.
* [nixpkgs PR #569556](https://github.com/NixOS/nixpkgs/pull/569556), opened 2026-10-02, proposes making the resolved module's NetworkManager DNS assignment a default to avoid conflicting explicit assignments; open as inspected. The issue concerns configurations enabling resolved and assigning a different NM DNS mode. It is **not** evidence this host, with resolved disabled, hit that conflict, and cannot explain 2025 without evidence.
* [dae issue #1158](https://github.com/daeuniverse/dae/issues/1158) reports in 2026 that dae 2.1.1 re-encodes compressed DNS replies into oversized responses for non-EDNS clients on a dnsmasq 2.93/OpenWrt setup; proposed fixes are discussed, not established here. This is a different failure direction and software stack; it illustrates why packet sizes and proxy behavior must be measured, not a diagnosis of this router.
* [RFC 6891 EDNS](https://www.rfc-editor.org/rfc/rfc6891) and [RFC 7873 DNS cookies](https://www.rfc-editor.org/rfc/rfc7873) define protocol context. Establishing a violation requires the actual wire messages and appropriate protocol conditions.

## Validation record

Baseline Git revision was `0456780bc4ac9920f1fcb8df02b96560d53f4f0e`; tests used the modified working tree, locked Nixpkgs `1d060086d60cb76a40cf37109f979d88a5bd6396`, Nix 2.34.9, Python 3.13.16 and QEMU 11.1.2 on x86_64 with `/dev/kvm` available. The following are distinct from the owner-supplied gateway observations:

| Command | Result and scope |
|---|---|
| `PYTHONDONTWRITEBYTECODE=1 python3 tests/dns/selftest.py` | PASS: 21 loopback diagnostic probes. |
| `PYTHONDONTWRITEBYTECODE=1 python3 tests/dns/fixtures/selftest.py` | PASS: fixture modes and wire responses on loopback. |
| `nix build --offline --no-write-lock-file --no-link -L .#checks.x86_64-linux.config-invariants` | PASS: policy assertions, not DNS connectivity. |
| `PYTHONDONTWRITEBYTECODE=1 python3 tests/repository-policy.py` | PASS: repository policy. |
| `nixfmt --check flake.nix tests/dns-qemu.nix` | PASS with Nixfmt 1.5.0. |
| `git check-ignore -v -- tests/dns/__pycache__/diagnostic.cpython-313.pyc tests/dns/__pycache__/other.cpython-313.pyc tests/dns/other.pyc` | PASS: the cache-directory and bytecode patterns apply; `git ls-files '*__pycache__*' '*.pyc'` returns no tracked artifacts. |

A preliminary four-VM assertion build passed in 83.36 s. A subsequent amended run failed because its shell exited early while capturing an expected nonzero `getent` status; that failed run is not counted as a pass. After correction, `nix build --offline --no-write-lock-file --no-link -L 'path:.#dns-qemu'` **passed** the five-VM KVM test in 100.96 s. A further build after formatting exited 0 using the existing result. The test exercised cookie and no-cookie EDNS timeouts, plain UDP and TCP success, NSS failure, resolved's healthy path, numeric HTTP and static-resolver independence. Fixture logs do not replace a historical packet trace. A non-NixOS image comparison was investigated but not run: a separate safe test-driver control path and authenticated pinned image are needed. This is a skip, not a pass.

## Outstanding answers and escalation

**Unresolved:** exact forwarding hop/operation, EDNS feature and protocol compliance, cache mechanism, TCP difference, IPv6 independence, real glibc/browser impact, a NixOS-specific regression, why other distributions appeared to work, and whether any historical event shares this cause. No exact router model or upstream service is known. Do not file a NixOS or vendor issue based solely on the workaround. Once isolated, prepare a sanitized report for the responsible component with exact versions, configuration, expected/actual results, bounded commands, query/response bytes and cache controls; include no private IP/MAC, credentials, personal domains or proprietary logs without permission. If the result implicates the gateway, ask its administrator to identify model, firmware, forwarding/upstream, DNSSEC/filtering and logs; do not scan, authenticate or modify it without authorization.

**Recommended now:** retain the static workaround; the [remediation plan](DNS-REMEDIATION-PLAN.md) describes tradeoffs, verification and rollback gates. Policy regression tests validate configuration only, and cannot establish live DNS health.
