# Use Tailscale for private mesh networking

- Status: accepted
- Date: 2026-07-05
- Deciders: nateinaction
- Guiding principles: [Prefer Memory-Safe Tooling](../ARCHITECTURE.md#3-prefer-memory-safe-tooling), [Layered Software Delivery](../ARCHITECTURE.md#4-layered-software-delivery), [Portability and Reproducibility](../ARCHITECTURE.md#2-portability-and-reproducibility)

## Context and Problem Statement

stableOS is a daily-driver that runs across multiple personal machines. Those
machines need to reach each other privately — for SSH, file transfer, and remote
access — without exposing services to the public internet. The challenge is that
real-world machines sit behind NAT, change IP addresses, and span different
networks. A practical solution must handle NAT traversal automatically and be
simple enough to stay maintained across a small fleet without a dedicated
administrator.

Since Tailscale is a system-wide daemon that must be present on every machine
and is tightly coupled to the OS networking stack, it belongs in the image RPM
tier ([ADR 0007](0007-layered-software-delivery.md)). That makes the choice of
*which* tool load-bearing — it is baked into the image and follows the machine to
new hardware automatically.

## Considered Options

- **Tailscale** — hosted-coordination, peer-to-peer mesh VPN built on WireGuard.
  Client written in **Go** (memory-safe). Handles NAT traversal automatically via
  DERP relay fallback. Provides MagicDNS (stable hostnames), ACLs, and exit
  nodes. Free tier covers personal fleets. No server to operate.
- **Headscale** — self-hosted, open-source coordination server that speaks the
  Tailscale protocol; standard Tailscale clients connect to it. Eliminates the
  Tailscale-hosted coordination plane but requires running and maintaining a
  server — a persistent operational burden counter to the goal of a simple,
  zero-server personal setup.
- **WireGuard (raw)** — the kernel-level VPN protocol that Tailscale wraps.
  In-tree since Linux 5.6. Full control, no cloud dependency, but key exchange,
  peer configuration, and routing are entirely manual. Impractical to maintain
  across more than two or three peers without additional tooling.
- **ZeroTier** — closest SaaS competitor to Tailscale. Similar hosted-coordination
  model with a free tier and a self-hosted controller option. Older and less
  polished; no meaningful advantage over Tailscale for a personal fleet.
- **Nebula** (Defined Networking) — self-hosted overlay mesh using a "lighthouse"
  model. Fully open source, but requires running a lighthouse server, adding the
  same operational overhead as Headscale with less ecosystem support.

## Decision Outcome

Chosen: **Tailscale**.

The core requirement is private, NAT-traversing connectivity between personal
machines with zero servers to run. Tailscale is the only option that satisfies
all three: it is peer-to-peer (WireGuard-based, so traffic goes machine-to-machine
where NAT allows), handles NAT traversal automatically, and requires no
coordination server to operate. Every alternative either demands a server
(Headscale, Nebula) or trades managed ergonomics for manual key management (raw
WireGuard).

On memory safety, the Tailscale client is written in **Go** — a garbage-collected,
memory-safe language — satisfying [principle 3](../ARCHITECTURE.md#3-prefer-memory-safe-tooling).
The WireGuard data plane lives in the Linux kernel and uses formally-verified
cryptographic primitives (Noise protocol, ChaCha20-Poly1305, Curve25519).

The real cost is the **hosted coordination plane**: Tailscale, Inc. operates the
servers that facilitate peer discovery and key exchange. This introduces a vendor
dependency and a potential privacy surface on machine metadata (hostnames, IP
assignments, ACL rules). Headscale is recorded here as the well-understood escape
hatch — it speaks the same protocol, so migration is possible if Tailscale's
terms, pricing, or privacy posture becomes unacceptable. That option is kept
viable by staying on the standard Tailscale client rather than anything
proprietary.

### Consequences

- Good: zero servers to operate — peer discovery and NAT traversal are handled by
  Tailscale's coordination plane, requiring no persistent infrastructure from the
  user.
- Good: Tailscale client is written in **Go** (memory-safe), and the WireGuard
  data plane uses formally-verified cryptography, satisfying
  [principle 3](../ARCHITECTURE.md#3-prefer-memory-safe-tooling).
- Good: baked into the image RPM tier ([ADR 0007](0007-layered-software-delivery.md)),
  so Tailscale is present and identical on every machine automatically — no
  manual setup after imaging new hardware.
- Good: MagicDNS provides stable hostnames across the fleet, making machine
  addressing reliable even as IPs change.
- Bad: the coordination plane is **Tailscale-hosted** — machine metadata (names,
  IPs, ACL configuration) passes through Tailscale's servers. This is a vendor
  dependency and a privacy surface not present in fully self-hosted alternatives.
- Bad: the free tier's limits and Tailscale's terms could change; the service
  could be discontinued. Mitigated by the Headscale escape hatch.

### Revisit Triggers

- If Tailscale's pricing, terms, or privacy posture becomes unacceptable,
  **Headscale** (self-hosted coordination with the standard Tailscale client) is
  the direct replacement — migrate the coordination server, keep the client.
- If a self-hosted, zero-server alternative emerges with equivalent NAT traversal,
  memory-safe tooling, and ease-of-use, reconsider.
