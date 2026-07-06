# Use fish as the interactive shell

- Status: accepted
- Date: 2026-07-05
- Deciders: nateinaction
- Guiding principles: [Prefer Memory-Safe Tooling](../ARCHITECTURE.md#3-prefer-memory-safe-tooling), [One Way to Do Things](../ARCHITECTURE.md#7-one-way-to-do-things)

## Context and Problem Statement

stableOS needs a default interactive shell — the environment where the user spends
the majority of their CLI time. The choice affects daily ergonomics directly and
also determines how other tools (zoxide, fzf, starship, etc.) integrate. Because
the shell is always running and is the root of the interactive session, a
memory-safe implementation is preferred under
[principle 3](../ARCHITECTURE.md#3-prefer-memory-safe-tooling).

## Considered Options

- **fish** (Friendly Interactive SHell) — interactive-first shell with
  autosuggestions, syntax highlighting, and tab completions out of the box, no
  plugins required. Written in **Rust** (the C++ rewrite is complete as of
  fish 4.x; all C++ code has been removed), satisfying
  [principle 3](../ARCHITECTURE.md#3-prefer-memory-safe-tooling).
- **zsh** — POSIX-compatible shell with a large plugin ecosystem (oh-my-zsh,
  prezto). Ships good completions but requires non-trivial configuration to reach
  parity with fish's defaults. Written in **C** — not memory-safe.
- **bash** — ubiquitous POSIX shell, the system default on most Linux
  distributions. Near-zero interactive ergonomics without heavy configuration.
  Written in **C** — not memory-safe.

## Decision Outcome

Chosen: **fish**.

All three shells get the job done, but fish's interactive ergonomics are
substantially ahead without any configuration: real-time autosuggestions, inline
syntax highlighting, and rich tab completions work on first launch. zsh can
approximate this with plugins, but that means maintaining a plugin manager and a
configuration layer that fish simply does not need — inconsistent with
[One Way to Do Things](../ARCHITECTURE.md#7-one-way-to-do-things).

On memory safety, fish is the only candidate written in Rust. bash and zsh are
both C with no plans to change. fish's C++ rewrite is complete — all C++ code has
been removed as of fish 4.x — so the memory-safety benefit is fully realized.

fish's non-POSIX syntax is a noted tradeoff: scripts that must run under bash or
sh cannot use fish idioms. That is acceptable here because interactive use
(history, completions, prompts) is the primary concern; system scripts targeting
POSIX compatibility are a separate concern and do not need to use fish.

### Consequences

- Good: autosuggestions, syntax highlighting, and completions work with zero
  configuration — the shell is useful immediately on a fresh machine.
- Good: written entirely in **Rust** (C++ rewrite complete as of fish 4.x),
  satisfying [principle 3](../ARCHITECTURE.md#3-prefer-memory-safe-tooling) fully;
  bash and zsh have no equivalent.
- Good: no plugin manager or framework required, reducing the surface area that
  can break on an update.
- Bad: fish's syntax is **not POSIX-compatible** — scripts written for bash/sh
  cannot be sourced in fish directly. System-level and POSIX scripts remain
  bash/sh as they always were; this only affects the interactive session.
