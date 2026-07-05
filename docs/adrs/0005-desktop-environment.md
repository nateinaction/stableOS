# Use the COSMIC desktop environment

- Status: accepted
- Date: 2026-07-04
- Deciders: nateinaction

## Context and Problem Statement

stableOS needs a desktop environment. Given the decision to build on a Fedora
Atomic bootc base ([ADR 0001](0001-immutable-image-mode-base.md)), the choice of
desktop is coupled to which upstream atomic base image is used as the `FROM` — a
DE that ships as a maintained `*-atomic` image is far cheaper to consume than one
assembled by hand on top of a generic base.

The [memory-safe-language north star](0002-memory-safe-language-northstar.md)
also applies: the desktop is the largest always-running piece of software on the
system, so preferring a memory-safe implementation matters most here.

## Considered Options

- **COSMIC** via `quay.io/fedora-ostree-desktops/cosmic-atomic` — desktop from
  System76 written in **Rust**, shipped as a maintained Fedora atomic image.
- **GNOME** via `fedora-ostree-desktops/silverblue` — the mainstream Fedora
  atomic desktop; core written primarily in C.
- **KDE Plasma** via `fedora-ostree-desktops/kinoite` — mature, configurable
  Fedora atomic desktop; written primarily in C++.

## Decision Outcome

Chosen: **COSMIC**, by building on
`quay.io/fedora-ostree-desktops/cosmic-atomic:44`.

The deciding factor is the memory-safety north star: COSMIC is written in
**Rust**, a memory-safe language, whereas GNOME (C) and KDE (C++) are built on
memory-unsafe foundations. COSMIC also ships as a first-class member of the
`fedora-ostree-desktops` family, so it slots directly into the bootc model with
no extra assembly, and it is the desktop the author wants to run day to day.
COSMIC's defaults for new users are seeded through the image via `/etc/skel`
(`files/skel/.config/cosmic/shell.ron`).

The base image is pinned to the current GA Fedora release; how that pin is
advanced is covered by the update-automation decision.

### Consequences

- Good: the primary, always-running desktop stack is built on a memory-safe
  language, advancing the security/reliability north star.
- Good: COSMIC ships as a first-class Fedora atomic image, so it composes cleanly
  with the bootc base and requires no manual desktop assembly.
- Good: a modern, Wayland-native desktop that matches the author's preference.
- Bad: COSMIC is younger and less battle-tested than GNOME or KDE; some rough
  edges and churn are expected as it matures — an accepted cost of applying the
  memory-safety north star.
- Bad: image-baked `/etc/skel` defaults only apply to users created *after* the
  image is installed; changing defaults for existing users needs a separate
  mechanism (personal dotfiles).
