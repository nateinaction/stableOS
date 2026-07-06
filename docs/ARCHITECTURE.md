# Architecture & Guiding Principles

## Overview

stableOS is a personal daily-driver operating system built with **bootc** (bootable container) on Fedora Atomic, featuring the COSMIC desktop. This document captures the guiding principles that shape architecture and design decisions. These principles are mutable and can evolve; for immutable records of *specific decisions and their rationale*, see [`docs/adrs/`](adrs/).

## Guiding Principles

These are principle-level statements. They describe *what* stableOS values and *why*, not the specific mechanisms that implement them — those belong in ADRs (see [`docs/adrs/`](adrs/)).

Every guiding principle should have at least one related ADR that records a concrete decision applying it. A principle with no supporting ADR is aspirational rather than established, and should be treated as a candidate for either grounding in a real decision or removal.

### 1. Immutability and Reliability

The root filesystem is read-only; all OS state is defined declaratively. This ensures:

- **No configuration drift** — the running system matches the committed definition exactly.
- **Atomic upgrades** — an upgrade stages a complete new version for the next boot; a bad upgrade never leaves the machine unbootable.
- **One-command rollback** — reverting to the prior deployment recovers from a bad upgrade.
- **Auditability** — system configuration lives in version control, not accumulated in machine-local state.

### 2. Portability and Reproducibility

The declaration is the configuration. Installing stableOS on new hardware reproduces the same known-good state automatically:

- All system-level customization happens at **build time**.
- Per-machine and per-user state is layered on top declaratively (writable machine-local state and per-user state persist across upgrades).
- **No local package layering** — every machine boots from the same known-good definition to avoid per-machine drift.
- The OS and its versions can be distributed and versioned through standard tooling.

### 3. Prefer Memory-Safe Tooling

When choosing software for the OS, prefer tools and libraries built on memory-safe languages (Rust, Go, etc.) over memory-unsafe equivalents (C, C++), all else being roughly equal. This is a strong tiebreaker, not an absolute rule; credible maturity, features, and integration cost may override it.

**Rationale:** A systemic reduction in an entire class of bugs (buffer overflows, use-after-free, data races) that compromise safety and reliability.

### 4. Layered Software Delivery

Software is delivered in tiers, each with appropriate constraints and distribution mechanisms:

1. **System services** — daemons, core OS infrastructure, things that need root or deep system integration.
2. **Sandboxed software** — user-facing programs, prioritized for security isolation and ease of update.
3. **Developer environments** — per-project toolchains, kept separate from the system image.

Adding a system-wide utility to the image must be accompanied by an ADR recording the decision and its rationale.

### 5. Verified, Signed Updates

All published releases must be cryptographically signed and verification must be automatic and enforced:

- Releases are signed with a project key.
- Systems enforce signature verification so unsigned or mis-signed updates are rejected.
- This is particularly important in an immutable OS where an update misbehavior cannot be locally patched.

### 6. Continuous, Automated Updates

The OS should pull new versions automatically and stage them for the next reboot, keeping the system current with minimal user friction:

- A scheduled timer regularly checks for and stages new versions.
- Users can disable this if needed, but it is the default to ensure timely security updates.
- Atomic rollback provides an escape hatch if an update misbehaves.

### 7. One Way to Do Things

Provide a single, canonical way to accomplish any given task. Do not ship two things that perform the same function — pick one and commit to it. A single well-supported path is easier to document, secure, and maintain. Redundant options create decision fatigue, drift, and duplicated maintenance for no real benefit.

### 8. User State Is Declared by Users, Not the Build

The build defines the OS, not the person using it. User state — dotfiles, application settings, personal configuration — must not be baked into the system image. Instead, users are given tools to **declare their own state** and reproduce it on top of any stableOS install:

- The build stays generic and identical for everyone; personalization lives outside it.
- User state is expressed declaratively so it can be version-controlled, audited, and reapplied on a fresh machine.
- Separating user state from the system image keeps upgrades clean and avoids coupling a person's preferences to the OS release cycle.

## Decision-Making Workflow

1. **Small decisions, tactical questions:** Settled inline in code. Update this file if a new principle emerges.
2. **Significant architectural decisions:** Propose an ADR (see [`docs/adrs/`](adrs/)) so the rationale is recorded and future contributors understand the context.
3. **Principle changes or clarifications:** Update this file and propose via PR for discussion.

See [`docs/adrs/README.md`](adrs/README.md) for the ADR process and existing decisions.
