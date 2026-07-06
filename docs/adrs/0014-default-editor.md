# Use Helix as the default editor

- Status: accepted
- Date: 2026-07-05
- Deciders: nateinaction
- Guiding principles: [Prefer Memory-Safe Tooling](../ARCHITECTURE.md#3-prefer-memory-safe-tooling), [Layered Software Delivery](../ARCHITECTURE.md#4-layered-software-delivery)

## Context and Problem Statement

stableOS needs a default terminal editor — the primary tool for editing config
files, code, and other text. It is delivered as part of the OS's tool layer
([ADR 0007](0007-layered-software-delivery.md)), so the choice shapes the day-to-day
editing experience for anyone using the system.

The [Prefer Memory-Safe Tooling](../ARCHITECTURE.md#3-prefer-memory-safe-tooling)
principle applies: an editor is a long-running, trusted process given direct
access to the filesystem, so a memory-safe implementation is preferred.

## Considered Options

- **Helix** — modal terminal editor written in **Rust**, with built-in LSP
  support, tree-sitter syntax highlighting, and multiple-cursor editing.
  Opinionated, batteries-included design: no plugin system, no config language
  beyond TOML — just a well-structured default experience out of the box.
- **Vim / Neovim** — the long-standing default for modal terminal editing.
  Neovim is written in **C** (not memory-safe) and Vim in C as well. Both have
  mature ecosystems and extensive plugin support, but require significant
  configuration effort to reach a comparable feature level (LSP, tree-sitter
  highlighting, etc.). The large plugin ecosystem is a double-edged sword:
  power users love it; for a curated OS image, unbounded plugin sprawl is a
  configuration surface to manage.

## Decision Outcome

Chosen: **Helix**.

Both candidates are capable modal editors. The [memory safety
principle](../ARCHITECTURE.md#3-prefer-memory-safe-tooling) weighs clearly in
Helix's favor: it is written in Rust, while Vim and Neovim are written in C.
Beyond safety, Helix ships LSP integration, tree-sitter highlighting, and
multiple cursors without any plugins or additional configuration, which aligns
with the OS goal of a curated, low-maintenance default experience. Vim/Neovim's
plugin ecosystem is a strength for power users who want to build their own
environment, but it means the baseline experience requires meaningful setup to
reach parity — work that belongs in a user's dotfiles, not in the OS image.

The main cost of choosing Helix is ecosystem maturity: Vim muscle memory is
widespread, and Helix's key bindings differ enough that users familiar with Vim
will have an adjustment period. Helix is also younger and has fewer resources,
tutorials, and plugin integrations (by design). These are real costs, recorded
here so the choice can be revisited.

### Consequences

- Good: memory-safe (Rust) implementation, satisfying [principle 3](../ARCHITECTURE.md#3-prefer-memory-safe-tooling).
- Good: LSP, tree-sitter highlighting, and multiple-cursor editing work out of
  the box — no plugin configuration required in the OS image.
- Good: TOML-only config is simple to version and reproduce via
  [chezmoi + Nix](0008-declarative-user-state.md).
- Bad: Helix key bindings differ from Vim, requiring adjustment for anyone with
  existing Vim muscle memory.
- Bad: Helix is younger than Vim/Neovim with a smaller community, fewer
  tutorials, and no plugin system — users who want deep extensibility must look
  elsewhere.

### Revisit Triggers

- If Helix's lack of a plugin system becomes a meaningful friction point for
  day-to-day use, reconsider **Neovim** with a curated, declaratively managed
  config (e.g. via Nix).
- If a memory-safe modal editor with a Vim-compatible plugin ecosystem matures,
  evaluate it against this decision.
