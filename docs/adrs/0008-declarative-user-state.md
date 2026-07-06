# Declarative user state with chezmoi, Nix, and direnv

- Status: accepted
- Date: 2026-07-05
- Deciders: nateinaction
- Guiding principles: [User State Is Declared by Users, Not the Build](../ARCHITECTURE.md#8-user-state-is-declared-by-users-not-the-build), [Portability and Reproducibility](../ARCHITECTURE.md#2-portability-and-reproducibility), [Prefer Memory-Safe Tooling](../ARCHITECTURE.md#3-prefer-memory-safe-tooling)

## Context and Problem Statement

The build defines the OS, not the person using it ([ADR 0007](0007-layered-software-delivery.md),
[principle 8](../ARCHITECTURE.md#8-user-state-is-declared-by-users-not-the-build)).
The image stays generic and identical for everyone; personalization must live
outside it, expressed declaratively so it can be version-controlled, audited, and
reapplied on a fresh machine.

But "user state" is not one thing. It splits into two concerns that behave very
differently:

1. **Configuration files** — shell config, aliases, editor settings, desktop
   tweaks, and the list of Flatpaks to install. These are text that belongs in
   `$HOME`, often need per-machine or templated differences (work vs. personal,
   hostname-specific values), and sometimes contain secrets.
2. **Per-user and per-project software** — development toolchains (Go, Rust,
   language servers) and user-scoped CLI tools that should *not* be baked into the
   image and change far more often than the OS.

A new machine should be reconstituted from **image + declared user state**, not by
hand. What mechanism(s) should express that state?

## Considered Options

For configuration files (dotfiles):

- **chezmoi** — a single static Go binary that manages `$HOME` from a source
  repo, with templating, per-machine data, and native secret-manager integration.
- **GNU Stow / bare git repo** — symlink-farm or a git repo checked out over
  `$HOME`. Minimal, but no templating, no secrets story, no per-machine
  differences.
- **yadm** — git wrapper for dotfiles; templating exists but is thinner and it is
  a shell script over git.
- **Nix / home-manager for dotfiles too** — express dotfiles as Nix modules,
  unifying config and packages under one tool.

For per-user / per-project software:

- **Nix** (`nix develop` + per-project `flake.nix`, plus user-wide profiles) —
  reproducible, per-project toolchains with no image rebuild.
- **Bake into the image** — rejected by [ADR 0007](0007-layered-software-delivery.md)
  for dev toolchains (too much churn, not project-scoped).

## Decision Outcome

Chosen: **two complementary tools, each for the concern it fits best** — rather
than forcing everything through one mechanism.

- **chezmoi** manages **dotfiles and configuration** from a **separate dotfiles
  repo**. It handles templating (per-machine/hostname differences), can pull
  secrets from a password manager instead of committing them, and deploys from a
  single self-contained binary with no runtime.

- **Nix** manages **per-project and user-scoped software** via `nix develop`
  against a project `flake.nix` and user profiles. This keeps dev toolchains
  reproducible, per-project, and out of the image.

- **direnv** is the activation mechanism that makes the Nix dev shell part of the
  declared state rather than a manual step. Each project carries an `.envrc`
  (`use flake`), so direnv automatically loads the project's `flake.nix` dev shell
  on `cd` into the directory and unloads it on exit — no explicit `nix develop`
  invocation required.

The tools are selected because they cover different concerns (configuration vs.
software vs. activation), have different iteration cadences, and keeping them
separate avoids coupling a person's editor config to a Nix rebuild.

### Decision rule (summary)

- Is it a file in `$HOME` (config, aliases, desktop settings, Flatpak list)? →
  **chezmoi**, from the dotfiles repo.
- Is it a dev/project toolchain or user-scoped package? → **Nix** dev shell /
  profile, auto-activated per project by **direnv** (`.envrc` → `use flake`).
- Is it a system daemon or core system-wide tool? → not user state; **RPM in the
  image** ([ADR 0007](0007-layered-software-delivery.md)).

### Consequences

- Good: a fresh machine is reconstituted from image + dotfiles repo + project
  flakes, with no manual setup — directly serving portability.
- Good: each tool plays to its strength — chezmoi's templating and secret handling
  for config, Nix's reproducibility for toolchains.
- Good: both user-facing tools that run constantly — chezmoi (dotfile apply) and
  direnv (shell activation) — are memory-safe Go binaries, satisfying
  [principle 3](../ARCHITECTURE.md#3-prefer-memory-safe-tooling) for the parts a
  user interacts with day to day.
- Bad: two tools for "user state" instead of one, so the boundary between them
  requires judgment (see decision rule).
- Bad: the Nix implementation itself is written in C++, so [principle 3](../ARCHITECTURE.md#3-prefer-memory-safe-tooling)
  is not satisfied there; Nix is chosen for reproducibility, and memory safety is a
  tiebreaker rather than an absolute rule.
- Bad: user state is not in the image, so a fresh install is fully personalized
  only after the chezmoi apply and first `direnv`/`nix develop` run.
