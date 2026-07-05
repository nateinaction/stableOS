# Build on an immutable, image-mode (bootc) base

- Status: accepted
- Date: 2026-07-04
- Deciders: nateinaction

## Context and Problem Statement

stableOS is a personal daily-driver operating system. The primary goals are
**safety, reliability, and portability**:

- The OS should be hard to break and easy to recover when something does go
  wrong.
- The configuration should be **portable to new hardware** without manually
  reconstructing state. Moving to another machine should not mean remembering
  and re-installing the set of applications and system tweaks by hand — the
  declared image should carry them.

A traditional mutable Linux install accumulates local state and drifts over
time: upgrades are applied in place, partial-upgrade states are possible, there
is no clean atomic rollback, and the machine's true configuration lives only in
its accumulated local state — so it cannot be faithfully reproduced on new
hardware. An immutable, declarative OS is wanted instead. The real question was
*which* declarative-OS approach to build on.

## Considered Options

- **bootc bootable-container image on a Fedora Atomic distribution** — the whole
  OS is an OCI image defined by a `Containerfile`, booted directly; `/` is
  read-only; updates swap in a new image atomically with rollback. Built on the
  Fedora RPM ecosystem and standard container tooling.
- **NixOS** — a fully declarative distribution where the entire system is
  described in the Nix language and built by the Nix package manager, with
  generations and atomic rollback.

Both options deliver the immutability, reproducibility, and portability the goals
require. The difference is the ecosystem and mental model.

## Decision Outcome

Chosen: **bootc bootable-container image on Fedora Atomic**, built on
`quay.io/fedora-ostree-desktops/cosmic-atomic:44`. The entire OS — base plus all
customization — is defined in a `Containerfile`, built into an OCI image, and
booted directly (bootc/image-mode). `/` is immutable at runtime; `bootc upgrade`
stages a new image for the next boot; `bootc rollback` returns to the prior
deployment.

bootc/Fedora Atomic was preferred over NixOS because:

- It builds on **familiar, mainstream tooling** — ordinary `Containerfile`s,
  `dnf`, RPM repos, and OCI registries — rather than requiring the whole OS to be
  expressed in the Nix language. The learning curve and day-to-day authoring cost
  are lower.
- The upstream **COSMIC atomic desktop image** is published ready-to-extend as a
  Fedora bootc base, so the desktop comes for free instead of being assembled
  from NixOS modules.
- The build and distribution model is **plain container images**: build in CI,
  push to a registry, `bootc switch`/`upgrade` to consume — leveraging existing
  container infrastructure, signing, and registries.
- Nix is still adopted where it is strongest — reproducible per-project dev
  environments and the build toolchain — *without* committing the entire OS to
  it. This captures much of NixOS's reproducibility benefit at the layer where it
  pays off most.

All system customization happens at **build time** in the image, not at install
or runtime. The declared image *is* the configuration: the set of installed
system applications and tweaks is committed to the `Containerfile`, so installing
stableOS on new hardware reproduces that state automatically — nothing to
remember or rebuild by hand. rpm-ostree local package layering is deliberately
avoided so every machine boots a bit-for-bit identical, centrally-built image;
layering would reintroduce exactly the per-machine drift that breaks portability.
State that genuinely is per-machine or per-user is layered on top declaratively —
Flatpak apps and chezmoi-managed dotfiles. Because `/` is immutable, machine-local
writable state lives on `/var` (persisted across upgrades) and per-user state in
`/home`.

### Consequences

- Good: atomic upgrades with one-command rollback (`bootc rollback`) — the core
  reliability win. A bad image never leaves the machine unbootable.
- Good: portability and reproducibility — the OS is fully described by the
  `Containerfile` and its pinned base digest, so new hardware reaches the same
  known-good configuration (including which apps are installed) just by
  installing or `bootc switch`-ing to the image.
- Good: uses mainstream container + Fedora tooling, so most Linux knowledge and
  the existing RPM ecosystem transfer directly; lower ongoing authoring cost than
  expressing the whole OS in Nix.
- Good: no configuration drift; the running system matches the image exactly, and
  updates are testable in CI before they reach a machine.
- Bad: less end-to-end reproducibility than NixOS — RPM installs pull from
  upstream repos and are only as pinned as the base digest and repo state, where
  NixOS would hash-pin everything.
- Bad: customization requires an image rebuild rather than a quick local
  `dnf install`; iteration is slower.
- Bad: some software assumes a writable `/` or `/opt` and needs adaptation to the
  image model (documented inline in the `Containerfile`), and writable state must
  be consciously routed to `/var` — subsystems that expect to write under `/`
  (e.g. the Nix store) need explicit handling, see
  [`docs/nix-store-boot-race.md`](../nix-store-boot-race.md).
