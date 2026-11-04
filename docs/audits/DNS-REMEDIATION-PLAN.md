<!--
SPDX-License-Identifier: GPL-3.0-only

Neodots - DNS remediation evaluation and rollback plan.

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

# DNS remediation plan

Status: **no production change approved or implemented**, 2026-11-04. The
[DNS investigation](DNS-ROOT-CAUSE.md) distinguishes the supplied observations
from the still-unidentified forwarding-path fault. Retain the existing static
plaintext IPv4 nameservers and firewall for now: they are the only locally
observed working compatibility workaround, not proof of a general DNS fix.

## Candidates, not recommendations to deploy

| Candidate | Reliability, latency and maintenance | Compatibility and security |
|---|---|---|
| Diagnose/update gateway DNS forwarding | Potentially fixes all clients and preserves DHCP, but vendor, firmware, fault and regression risk are unknown; cold-cache and rollback must be tested. | Can preserve IPv4/IPv6, VPN split DNS and captive portal discovery; plaintext upstream remains possible. Requires authorized administration. |
| Correct gateway upstream/DHCP-advertised resolver | Can remove a faulty forwarding hop; cold/warm latency, reachability and failure behavior must be measured. | May bypass local zones or captive portals; check IPv6 advertisements and VPN routes as well as privacy. Requires network administrator. |
| Fix a verified NixOS integration defect | Best scoped if a reproducible ownership/selection defect is actually found; none is established. | Requires version-specific tests and rollback; cannot fix an independently broken network resolver. |
| Local caching/forwarding resolver | Could provide explicit upstream control and warm-cache speed; adds service, cold-cache upstream dependency and maintenance. | Must test IPv6, VPN split domains, portals, confidentiality and bootstrap; fail-closed versus fallback must be explicit. Not justified by current evidence. |
| Encrypted DNS | Can protect DNS on a selected hop; handshake, bootstrap, upstream outage and latency may harm reliability. | Can bypass local/VPN domains and captive portals; privacy alone is not evidence of better connectivity. Decide whether plaintext fallback is allowed and test it. |
| Retain static public IPv4 DNS | Demonstrated working during the supplied test; no extra service, easy rollback, public resolver outages and cold-cache delays remain possible. | Plaintext; discloses queries to resolvers/on-path observers; bypasses DHCP DNS, local names and normal NM split DNS, may break captive portals; IPv6-only networks lack IPv6 nameservers. A VPN app/browser may separately control routing or DNS. |

## Before any approved replacement

1. Preserve current configuration and evaluated values, current system generation,
   and a known-working recovery method. Agree on authorized maintenance window,
   scope, router access, test targets and who can restore network connectivity.
2. Identify the failing forwarding hop using authorized device/upstream logs and
   paired client- and gateway-side captures. Compare controlled EDNS/transport,
   cache state, DO bit and payload; do not assume an EDNS violation from a timeout.
3. In disposable environments on the same gateway, compare NixOS default NM,
   NixOS resolved, current static policy, and another distribution. Verify the
   packet destination is the actual gateway, not VM NAT; record versions and
   nameserver ownership. Compare application lookups, A/AAAA, simultaneous versus
   sequential requests, cold/warm caches, IPv4 and IPv6, timeout and recovery.
4. Test proposed replacement and current policy side by side: uplink loss and
   recovery, unreachable first resolver, TCP/UDP, EDNS options, IPv6-only network,
   captive portal, local names, VPN connected/disconnected and split DNS, browser
   independent DNS, and intended privacy/fail-open or fail-closed behavior.
   Keep the offline policy check distinct from the opt-in network test.
5. Document measured criteria and results, including unsuccessful networks. Obtain
   explicit owner approval before changing the five protected NixOS options,
   live network state, router, DHCP, VPN routing or running `nixos-rebuild switch`.

## Rollback after a future authorized change

Before applying, record `readlink -f /run/current-system` and save the exact
reviewed configuration and corresponding system generation securely. Ensure an
out-of-band or local console is available; establish how to recover remotely
before disconnecting. If validation fails, under a separately approved maintenance
procedure restore the recorded configuration/generation using the documented
NixOS rollback mechanism, then verify `/etc/resolv.conf`, NetworkManager DNS mode,
firewall, routes, application lookups, portal and VPN. Revert any router or DHCP
changes using the administrator's saved configuration as a separate operation.
Do not assume a NixOS generation rollback reverses router, profile, VPN, or other
mutable state. This document authorizes no execution.
