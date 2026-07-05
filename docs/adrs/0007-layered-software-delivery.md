# Layered software delivery

- Status: accepted
- Date: 2026-07-04
- Deciders: nateinaction
- Guiding principles: [Layered Software Delivery](../ARCHITECTURE.md#4-layered-software-delivery), [User State Is Declared by Users, Not the Build](../ARCHITECTURE.md#8-user-state-is-declared-by-users-not-the-build)

## Context and Problem Statement

On an immutable image-mode OS ([ADR 0001](0001-immutable-operating-system.md)),
there is no single obvious place to install software. Baking everything into the
image maximizes reproducibility but makes every change require an image rebuild
and reboot, bloats the base, and gives GUI apps more privilege than they need.
Installing everything at runtime undermines the portability goal — a new machine
would not carry the apps forward. Different kinds of software have genuinely
different needs (privilege, sandboxing, update cadence, whether they belong to
the machine or the project), so a single mechanism is a poor fit.

How should each piece of software be delivered?

## Considered Options

- **One mechanism for everything** — e.g. bake every app as an RPM in the image,
  or install everything as Flatpaks at runtime.
- **Tiered delivery** — route each piece of software to the mechanism that fits
  its role: image RPMs, Flatpaks, or Nix.

## Decision Outcome

Chosen: **tiered delivery**, with a clear rule for which tier each piece of
software lands in.

1. **RPM, baked into the image** — for **system-wide tools and daemons** that
   should be present on every machine and are part of the OS's identity: system
   services (Tailscale), CLI tooling (vim, gh, chezmoi, zoxide, fzf, Claude
   Code), terminals, and apps distributed as RPMs. These are committed in the
   `Containerfile`, so they are reproduced automatically on new hardware —
   directly serving the portability goal.

2. **Flatpak, installed per-machine at runtime** — for **GUI applications, less
   critical apps, and anything that benefits from stronger sandboxing** — most
   notably the web browser (Firefox), the highest-exposure app on the system.
   Flatpaks run sandboxed with per-app permissions, update independently of the
   OS image, and do not require an image rebuild. Flathub is pre-configured on
   first boot (`files/systemd/flathub-setup.service`) so these installs are a
   one-liner and can themselves be tracked declaratively in dotfiles.

3. **Nix, per-project (and user-wide) at runtime** — for **development
   environments and project toolchains** (Go, Rust, language servers, etc.) that
   change often and are project-specific. `nix develop` against a project
   `flake.nix` (auto-activated by direnv) spins up a reproducible toolchain with
   **no image rebuild**, keeping the base OS clean and dev dependencies
   per-project.

Per-user state that is neither system nor project — shell config, aliases,
desktop tweaks, and the list of Flatpaks to install — is managed with **chezmoi**
from a **separate dotfiles repo**, not baked into the image. This keeps the image
as global defaults and the dotfiles repo as per-user customization, and means a
new machine is reconstituted from image + dotfiles rather than by hand.

### Decision rule (summary)

- Is it a system daemon or a core system-wide tool available as an RPM? →
  **RPM in the image.**
- Is it a GUI app, a browser, lower-priority, or something that wants sandboxing?
  → **Flatpak.**
- Is it a development/project toolchain? → **Nix dev shell.**
- Is it personal config/state? → **chezmoi dotfiles repo.**

### Known exceptions

- **1Password** is currently shipped as an **image RPM**, but by the rule above it
  *should* be a Flatpak (it is a sandboxable GUI app). It stays an RPM only
  because the Flatpak build did not allow copying to the clipboard. **It should be
  moved to Flatpak once that limitation is resolved.**

### Consequences

- Good: each tier matches software to the right trade-off — reproducibility and
  ubiquity for system tools, sandboxing and independent updates for GUI apps,
  fast per-project iteration for dev toolchains.
- Good: the browser and other high-exposure GUI apps run sandboxed via Flatpak
  rather than with full system privilege.
- Good: dev toolchains and most apps can change without an image rebuild/reboot,
  mitigating the immutable base's slower iteration.
- Good: portability preserved — image RPMs carry system state to new hardware;
  Flatpak lists and config carry via the dotfiles repo.
- Bad: more moving parts — four mechanisms (RPM, Flatpak, Nix, chezmoi) to
  understand and maintain, versus one.
- Bad: the tier boundary requires judgment, and real-world limitations force
  exceptions (see 1Password) that must be tracked so they can be revisited.
- Bad: Flatpak apps and dotfiles are not baked into the image, so a fresh install
  is fully reproduced only after the first-boot Flatpak/chezmoi steps run.
