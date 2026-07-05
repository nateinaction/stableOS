# Prefer tooling built on memory-safe languages (north star)

- Status: accepted
- Date: 2026-07-04
- Deciders: nateinaction

## Context and Problem Statement

stableOS is a daily-driver OS whose overriding goals are safety and reliability
([ADR 0001](0001-immutable-image-mode-base.md)). A large, recurring class of
security vulnerabilities and crashes on any operating system comes from
**memory-unsafe code** — buffer overflows, use-after-free, data races — in
software written in languages like C and C++.

Countless individual choices go into an OS: the desktop environment, terminals,
CLI tools, daemons, and so on. Making each of those choices ad hoc risks
inconsistency and misses an easy, systemic lever for reducing that class of bugs.
A single guiding principle would let every later decision pull in the same
direction without re-litigating the rationale each time.

## Considered Options

- **Adopt a north star: prefer memory-safe languages** — when choosing between
  comparable pieces of software, favor the one built on a memory-safe language
  (Rust, Go, etc.), all else being roughly equal.
- **No guiding principle** — evaluate each piece of software purely on its own
  merits case by case.

## Decision Outcome

Chosen: **adopt "prefer tooling built on memory-safe languages" as an explicit
north star** for stableOS. When selecting software to build the OS from or to
bake into the image, a memory-safe implementation is preferred over a
memory-unsafe one where a credible option exists and the options are otherwise
comparable.

This is a **preference, not an absolute rule**: it is one strong input among
others (maturity, integration cost, features, availability). Where the
memory-safe option is not yet credible, or a specific feature is decisive, the
memory-unsafe option may still win — but the trade-off should be made
consciously, and the memory-safe option is the default tiebreaker.

Later ADRs apply this north star and cite it as a deciding factor. Because it is a
foundational, cross-cutting principle rather than a component choice, it is placed
early in the ADR sequence so subsequent records can reference it.

### Consequences

- Good: a systemic reduction in an entire class of memory-safety
  vulnerabilities and crashes across the software the OS is built from.
- Good: gives every later decision a consistent, pre-agreed tiebreaker, so
  choices don't have to re-argue the rationale.
- Good: biases the system toward modern, actively-developed Rust/Go tooling.
- Bad: the memory-safe option is sometimes younger or less feature-complete than
  a mature C/C++ incumbent, so applying the north star can mean accepting rough
  edges (e.g. a younger desktop or tool).
- Bad: "comparable" and "credible" require judgment; the principle guides but
  does not mechanically decide, so exceptions will exist and must be justified.
