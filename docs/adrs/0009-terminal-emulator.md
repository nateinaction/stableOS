# Use Warp as the terminal emulator

- Status: superseded by [ADR 0017](0017-terminal-emulator-alacritty.md)
- Date: 2026-07-05
- Deciders: nateinaction
- Guiding principles: [Prefer Memory-Safe Tooling](../ARCHITECTURE.md#3-prefer-memory-safe-tooling), [Layered Software Delivery](../ARCHITECTURE.md#4-layered-software-delivery)

## Context and Problem Statement

stableOS needs a default terminal emulator — the primary interface for the CLI
tooling the OS ships ([ADR 0007](0007-layered-software-delivery.md)). It is
delivered as an image RPM (a core, system-wide tool), so the choice is baked into
the image's identity.

The [Prefer Memory-Safe Tooling](../ARCHITECTURE.md#3-prefer-memory-safe-tooling)
principle applies: the terminal is always-running and always-focused, so a
memory-safe implementation is preferred. Beyond that, the author wants a terminal
with modern ergonomics — notably AI-assisted command prediction — to speed daily
work.

## Considered Options

- **Warp** — GPU-accelerated terminal written in **Rust**, with block-based
  output, built-in AI command search/prediction, and modern editing UX. Ships an
  RPM. Now **open source** (OpenAI is the founding sponsor of the repository).
  The plain terminal runs with no account, but the **AI and team features still
  require a cloud login** today; the maintainers have signaled that requirement is
  not intended to be permanent.
- **Alacritty** — minimal GPU-accelerated terminal written in **Rust**, fully
  open source, no account, no telemetry. Deliberately spartan: no tabs, splits, or
  AI features (relies on a multiplexer / the shell for those).
- **Ghostty** — fast, feature-rich, GPU-accelerated terminal with native tabs and
  splits, fully open source, no account. Written in **Zig**, which is **not
  memory-safe**, so it counts against [principle 3](../ARCHITECTURE.md#3-prefer-memory-safe-tooling).

## Decision Outcome

Chosen: **Warp**.

**Ghostty** is set aside on [memory safety](../ARCHITECTURE.md#3-prefer-memory-safe-tooling):
it is written in Zig (not memory-safe), which principle 3 weighs against for an
always-running tool, despite its strong open-source feature set. Between the two
remaining Rust candidates, memory safety does **not** distinguish them — it is
satisfied either way. The deciding factor is feature set: Warp's AI command
prediction, command blocks, and modern editing are the day-to-day ergonomics the
author wants, and Alacritty intentionally provides none of them.

This choice is made with eyes open to a real cost: Warp's **AI features are still
account-gated**, which sits in tension with an otherwise open, self-hostable,
privacy-respecting stack. Warp is now open source and the plain terminal needs no
login, which softens the concern, but the AI command prediction that motivated the
choice is exactly the part that still requires signing in. That tradeoff is
accepted for now in exchange for the UX, and recorded here so it can be revisited
(see Consequences).

### Consequences

- Good: memory-safe (Rust) terminal, satisfying [principle 3](../ARCHITECTURE.md#3-prefer-memory-safe-tooling).
- Good: AI command prediction and block-based UX materially speed interactive
  work — the reason for the choice.
- Good: Warp is now **open source**, so it can be audited and, in principle,
  forked or self-hosted — closing much of the gap with the rest of the stack.
- Bad: Warp's **AI and team features still require a cloud login** and send
  telemetry, introducing an external dependency and a privacy surface on the
  OS's primary interface. The AI is the reason for the choice, so this gate lands
  on the feature that matters most. The maintainers have signaled this requirement
  is not meant to be permanent, but it applies today.
- Bad: reliance on a hosted AI backend means that AI-assisted UX degrades or
  requires sign-in when offline (the plain terminal still works).

### Revisit Triggers

- If the account requirement, telemetry, or licensing becomes
  unacceptable, **Alacritty** (or another memory-safe, open terminal) is the
  fallback, and this ADR should be superseded.
- If AI command autosuggestions become available through some
  other means that more closely align with the [guiding principles](../ARCHITECTURE.md)
  (e.g. a memory-safe, open, account-free terminal or a local/self-hostable model),
  reconsider this choice — AI suggestions are the main reason for Warp, so an
  option that delivers them without the account gate would likely win.
