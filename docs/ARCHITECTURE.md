# Architecture & Guiding Principles

## Overview

stableOS is a personal daily-driver operating system built with **bootc** (bootable container) on Fedora Atomic, featuring the COSMIC desktop. This document captures the guiding principles that shape architecture and design decisions. These principles are mutable and can evolve; for immutable records of *specific decisions and their rationale*, see [`docs/adrs/`](docs/adrs/).

## Guiding Principles

### 1. Immutability and Reliability

The root filesystem is read-only; all OS state is defined declaratively in the `Containerfile`. This ensures:

- **No configuration drift** — the running system matches the committed image exactly.
- **Atomic upgrades** — `bootc upgrade` stages a complete image for the next boot; a bad upgrade never leaves the machine unbootable.
- **One-command rollback** — `bootc rollback` returns to the prior deployment, so bad images are recoverable.
- **Auditability** — system configuration lives in git, not accumulated in machine-local state.

### 2. Portability and Reproducibility

The declared image is the configuration. Installing stableOS on new hardware reproduces the same known-good state automatically:

- All system-level customization happens at **build time** in the `Containerfile`.
- Per-machine and per-user state is layered on top declaratively (writable `/var` for machine-local, `/home` for per-user).
- **No local package layering** — every machine boots the same bit-for-bit image to avoid per-machine drift.
- The OS and its versions can be distributed as ordinary OCI images via standard container registries.

### 3. Prefer Memory-Safe Tooling

When choosing software for the image, prefer tools and libraries built on memory-safe languages (Rust, Go, etc.) over memory-unsafe equivalents (C, C++), all else being roughly equal. This is a strong tiebreaker, not an absolute rule; credible maturity, features, and integration cost may override it.

**Rationale:** A systemic reduction in an entire class of bugs (buffer overflows, use-after-free, data races) that compromise safety and reliability.

### 4. Layered Software Delivery

Software is delivered in three tiers, each with appropriate constraints and distribution mechanisms:

1. **System services** (RPM/systemd) — daemons, core OS infrastructure, things that need root or deep system integration.
2. **Sandboxed applications** (Flatpak/COSMIC Store) — GUI applications, prioritized for security isolation and ease of update.
3. **Developer environments** (Nix/direnv) — per-project toolchains, kept separate from the system image.

### 5. Familiar, Mainstream Tooling

Build and extend stableOS using mainstream, familiar tools rather than novel or highly specialized approaches:

- Use ordinary `Containerfile`s, `dnf`, RPM repos, and OCI registries instead of domain-specific declarative languages (Nix for the whole OS, etc.).
- Leverage existing container infrastructure, tooling knowledge, and CI/CD patterns.
- Nix is adopted where it is strongest (reproducible dev environments) *without* committing the entire OS to it.

**Rationale:** Lower learning curve, lower ongoing authoring cost, easier for contributors to follow and maintain.

### 6. Verified, Signed Updates

All published images must be cryptographically signed and verification must be automatic and enforced:

- Images are signed with cosign using a project key.
- Systems enforce signature verification in `/etc/containers/policy.json` so unsigned or mis-signed images are rejected.
- This is particularly important in an immutable OS where an update misbehavior cannot be locally patched.

### 7. Continuous, Automated Updates

The OS should pull new images automatically and stage them for the next reboot, keeping the system current with minimal user friction:

- `bootc-fetch-apply-updates` timer runs weekly, checking for and staging new images.
- Users can disable this if needed, but it is the default to ensure timely security updates.
- Atomic rollback (`bootc rollback`) provides an escape hatch if an update misbehaves.

### 8. Separate Build and Authoring Concerns

- **Image building** happens in CI with a pinned, reproducible toolchain (defined in a Nix flake) and all test, lint, and format checks.
- **Local development** uses the same Nix flake so local and CI stay in lockstep; no surprise tool differences.
- The `Containerfile` is the source of truth; local iteration requires rebuilding the image, not ad-hoc system tweaks.

## Architecture Layers

```
┌─────────────────────────────────────────────────┐
│  Per-user state: dotfiles, config, ssh keys    │
│  (/home — persists across upgrades)             │
├─────────────────────────────────────────────────┤
│  Sandboxed applications (Flatpak)               │
│  Updated independently, isolated                │
├─────────────────────────────────────────────────┤
│  Read-only OS image (bootc)                     │
│  System services, daemons, core tools (RPM)     │
│  (/—immutable)                                  │
├─────────────────────────────────────────────────┤
│  Machine-local persistent state                 │
│  (/var — writable, persists across upgrades)    │
├─────────────────────────────────────────────────┤
│  Fedora Atomic / COSMIC base (bootc image)      │
│  Immutable root filesystem                      │
└─────────────────────────────────────────────────┘
```

## Decision-Making Workflow

1. **Small decisions, tactical questions:** Settled inline in code or in Slack. Update this file if a new principle emerges.
2. **Significant architectural decisions:** Propose an ADR (see [`docs/adrs/`](docs/adrs/)) so the rationale is recorded and future contributors understand the context.
3. **Principle changes or clarifications:** Update this file and propose via PR for discussion.

See [`docs/adrs/README.md`](docs/adrs/README.md) for the ADR process and existing decisions.
