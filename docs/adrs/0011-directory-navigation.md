# Use zoxide for directory navigation

- Status: superseded by [ADR 0018](0018-remove-fuzzy-finding-and-directory-navigation.md)
- Date: 2026-07-05
- Deciders: nateinaction
- Guiding principles: [Prefer Memory-Safe Tooling](../ARCHITECTURE.md#3-prefer-memory-safe-tooling), [One Way to Do Things](../ARCHITECTURE.md#7-one-way-to-do-things)

## Context and Problem Statement

Frequent directory changes are a large share of interactive shell time. A "smart
`cd`" that remembers frequently-used directories and jumps to them by a fragment
of their name (`z proj` → `~/code/github.com/nateinaction/stableOS`) removes most
of that friction.

stableOS ships a curated set of core CLI tools as image RPMs
([ADR 0007](0007-layered-software-delivery.md)), so a single such helper should be
chosen and committed to. It should be memory-safe
([principle 3](../ARCHITECTURE.md#3-prefer-memory-safe-tooling)) and integrate
cleanly with the shell.

## Considered Options

- **zoxide** — smart-`cd` written in **Rust**. Maintained, fast, cross-shell
  (including fish), with an interactive mode (`zi`) that delegates to the system
  fuzzy finder.
- **`rupa/z` (`z.sh`)** — the original "frecency" jumper, a **POSIX shell
  script**. Battle-tested but unmaintained-ish, slower, and shell-script-bound.
- **A fish-native `z` plugin** — pure-fish reimplementation. No extra binary, but
  fish-only and less maintained.
- **oh-my-fish's `z` wrapper** — the same idea packaged via a fish framework,
  adding a plugin-manager dependency for one feature.

## Decision Outcome

Chosen: **zoxide**.

zoxide is the modern standard for this niche: it is written in **Rust**
(satisfying [principle 3](../ARCHITECTURE.md#3-prefer-memory-safe-tooling), where
the shell-script alternatives are neither faster nor safer), actively maintained,
noticeably faster than `z.sh`, and cross-shell so it is not coupled to fish. Its
interactive mode reuses the fuzzy finder chosen in
[ADR 0010](0010-fuzzy-finding.md) (fzf), so the two tools compose instead of
overlapping.

Picking one jumper and committing to it satisfies
[One Way to Do Things](../ARCHITECTURE.md#7-one-way-to-do-things): the fish-native
plugin and the oh-my-fish wrapper solve the same problem with more coupling and
less maintenance, so they are declined rather than offered alongside.

### Consequences

- Good: memory-safe (Rust), fast, and actively maintained.
- Good: cross-shell, so the choice survives a future shell change rather than
  being fish-locked.
- Good: composes with the chosen fuzzy finder ([ADR 0010](0010-fuzzy-finding.md))
  for interactive selection instead of reimplementing it.
- Bad: adds a compiled binary to the image rather than a few lines of shell — a
  small size/maintenance cost accepted for speed and safety.
- Bad: the frecency database is per-user runtime state; it is rebuilt over time on
  a fresh machine rather than declared, so early navigation is less smart until it
  warms up.
