# Use Alacritty as the terminal emulator

- Status: accepted
- Date: 2026-07-14
- Deciders: nateinaction
- Guiding principles: [Prefer Memory-Safe Tooling](../ARCHITECTURE.md#3-prefer-memory-safe-tooling), [Layered Software Delivery](../ARCHITECTURE.md#4-layered-software-delivery)
- Supersedes: [ADR 0009](0009-terminal-emulator.md)

## Context and Problem Statement

[ADR 0009](0009-terminal-emulator.md) chose Warp over Alacritty for its AI
command prediction and block-based UX, accepting the account-gated AI features
as a known cost. [PR #51](https://github.com/nateinaction/stableOS/pull/51)
shipped Alacritty alongside Warp as a deliberate experiment — both installed,
to be compared directly on real day-to-day use before picking one.

That comparison is done. Warp's day-to-day performance did not hold up against
Alacritty's: Alacritty is noticeably lighter and more responsive as an
always-running, always-focused process, which is exactly the property
[principle 3](../ARCHITECTURE.md#3-prefer-memory-safe-tooling) cares about for
this class of tool. Warp's AI features were the reason it was chosen in the
first place, but they don't outweigh a terminal that is slower to use for
every single interactive session.

## Considered Options

- **Alacritty** — minimal GPU-accelerated terminal written in **Rust**, fully
  open source, no account, no telemetry. Deliberately spartan: no tabs, splits,
  or AI features (relies on a multiplexer / the shell for those).
- **Warp** — GPU-accelerated terminal written in **Rust**, with block-based
  output, built-in AI command search/prediction, and modern editing UX. Now
  open source, though AI and team features still require a cloud login. Kept
  in the image since ADR 0009; retained only as the prior default pending this
  decision.

## Decision Outcome

Chosen: **Alacritty**. Warp is dropped from the image.

The head-to-head trial settled the question ADR 0009 left open: raw
interactive performance matters more day to day than Warp's AI-assisted
command prediction, and Alacritty wins clearly on performance. Memory safety
([principle 3](../ARCHITECTURE.md#3-prefer-memory-safe-tooling)) was already
satisfied by both candidates, so it doesn't distinguish them here — performance
does. This also removes the account-gated AI dependency that ADR 0009 flagged
as an open cost, which is a secondary win but not the deciding one.

### Consequences

- Good: memory-safe (Rust) terminal, satisfying
  [principle 3](../ARCHITECTURE.md#3-prefer-memory-safe-tooling).
- Good: lighter, faster interactive performance for an always-running,
  always-focused process — the deciding factor.
- Good: no account or cloud login required for any terminal feature; no
  telemetry surface on the OS's primary interface.
- Bad: no AI-assisted command prediction, block-based output, or built-in
  tabs/splits — Alacritty is deliberately minimal and relies on a multiplexer
  or the shell for anything beyond raw terminal emulation.

### Revisit Triggers

- If a memory-safe, performant, account-free terminal emerges with AI-assisted
  command prediction, evaluate it against this decision — that combination is
  what Warp couldn't deliver without a performance or account-gating cost.
