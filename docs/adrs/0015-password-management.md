# Password management

- Status: accepted
- Date: 2026-07-05
- Deciders: nateinaction
- Guiding principles: [Layered Software Delivery](../ARCHITECTURE.md#4-layered-software-delivery), [User State Is Declared by Users, Not the Build](../ARCHITECTURE.md#8-user-state-is-declared-by-users-not-the-build)

## Context and Problem Statement

A password manager is essential security infrastructure for a daily-driver OS, but
the choice of *which* manager is genuinely personal: it depends on existing vaults,
family or team sharing plans, preferred clients, and trust posture. Unlike system
daemons such as Tailscale, a password manager does not need to be identical across
machines and its absence does not break the OS — it is per-user configuration, not
OS identity.

Password management is important enough that stableOS should have a clear position
on how it is delivered once the user makes a choice.

## Considered Options

- **Bake a specific password manager into the image RPM tier** — picks one manager
  for all users, removes user choice, and couples every image rebuild to that
  vendor's release cadence.
- **Flatpak (per-machine, user-chosen)** — sandboxed, independently updated, not
  baked into the image. Matches the delivery tier for GUI apps per ADR 0007.

## Decision Outcome

Chosen: **password management is a user choice, delivered via the Flatpak tier.**

stableOS does not prescribe a specific password manager. The user's chosen manager
should be installed as a Flatpak and tracked in their dotfiles repo (chezmoi), not
baked into the image. This keeps the image vendor-neutral on this dimension and
treats the password manager like any other user-level GUI app.

### Consequences

- Good: the image is not coupled to any one password manager vendor — users can
  choose freely without forking the image.
- Good: Flatpak delivers the sandboxing and independent update cadence appropriate
  for a high-trust credential store.
- Bad: leaving the choice entirely to the user means first-boot does not
  automatically set up credential storage; it requires a manual install step.

### Known exceptions

**1Password clipboard bug:** The 1Password Flatpak does not propagate clipboard
writes correctly. Until that is resolved upstream, users who choose 1Password should
install it as an image RPM rather than via Flatpak. Once fixed, move the install to
Flatpak and remove the RPM from the Containerfile. Tracked in
[issue #31](https://github.com/nateinaction/stableOS/issues/31).

### Revisit Triggers

- If the **1Password Flatpak clipboard bug** is resolved, move the 1Password install
  from the image RPM tier to Flatpak and remove the Containerfile entry.
- If a mainstream **OS-integrated credential standard** (analogous to Apple's
  Keychain / Passwords app) emerges on Linux with broad desktop environment support,
  reconsider whether stableOS should ship that standard rather than deferring the
  choice entirely to the user.
