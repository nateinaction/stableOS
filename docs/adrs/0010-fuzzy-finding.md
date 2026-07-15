# Use fzf for fuzzy finding

- Status: superseded by [ADR 0018](0018-remove-fuzzy-finding-and-directory-navigation.md)
- Date: 2026-07-05
- Deciders: nateinaction
- Guiding principles: [Prefer Memory-Safe Tooling](../ARCHITECTURE.md#3-prefer-memory-safe-tooling), [One Way to Do Things](../ARCHITECTURE.md#7-one-way-to-do-things)

## Context and Problem Statement

Interactive fuzzy selection — over shell history, files, processes, and as the
picker backing other tools — is a foundational piece of CLI ergonomics. stableOS
ships one fuzzy finder as an image RPM
([ADR 0007](0007-layered-software-delivery.md)) and later tools build on it — a
directory jumper's interactive mode, for example, delegates to whichever finder is
chosen here — so this decision is a shared dependency and should be made first.

Both realistic candidates are memory-safe, so
[principle 3](../ARCHITECTURE.md#3-prefer-memory-safe-tooling) does not decide it
on its own — the choice turns on maturity and ecosystem.

## Considered Options

- **fzf** — the de-facto standard fuzzy finder, written in **Go** (memory-safe).
  Extremely mature and ubiquitous, with first-class fish key bindings
  (`CTRL-T`, `CTRL-R`, `ALT-C`), and the finder most other tools (including
  zoxide) integrate with by default.
- **skim (`sk`)** — a fuzzy finder written in **Rust** (memory-safe), API-similar
  to fzf. Younger, smaller ecosystem, fewer downstream integrations.

## Decision Outcome

Chosen: **fzf**.

Because both are memory-safe, the [memory-safety tiebreaker](../ARCHITECTURE.md#3-prefer-memory-safe-tooling)
that favored Rust elsewhere does not apply — skim's Rust implementation earns it
no decisive edge over fzf's Go one, and
[principle 3](../ARCHITECTURE.md#3-prefer-memory-safe-tooling) is explicitly a
tiebreaker, not an absolute rule. With safety equal, **maturity and ecosystem
integration** decide: fzf is the standard nearly every other tool expects, has
battle-tested fish bindings, and is what interactive tools reach for by default.
Choosing it maximizes integration and minimizes surprises.

Selecting one finder and committing to it satisfies
[One Way to Do Things](../ARCHITECTURE.md#7-one-way-to-do-things); skim is declined
rather than shipped alongside.

### Consequences

- Good: memory-safe (Go), so [principle 3](../ARCHITECTURE.md#3-prefer-memory-safe-tooling)
  is satisfied even though it was not the deciding factor.
- Good: maximum ecosystem compatibility — downstream tools (zoxide and others)
  integrate with fzf out of the box, avoiding glue and edge cases.
- Good: mature, widely documented fish key bindings for history, file, and
  directory selection.
- Bad: this is the one place a memory-safe **Rust** alternative (skim) was passed
  over for a **Go** tool; consistent with the principle being a tiebreaker, but
  worth recording as a conscious exception to any "prefer Rust" reflex.
- Revisit trigger: if skim reaches comparable ubiquity and downstream tools adopt
  it as a first-class backend, the Rust implementation could be reconsidered, and
  this ADR superseded.
