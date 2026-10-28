# Replace GNU coreutils with uutils-coreutils

- Status: accepted
- Date: 2026-07-15
- Deciders: nateinaction
- Guiding principles: [Prefer Memory-Safe Tooling](../ARCHITECTURE.md#3-prefer-memory-safe-tooling), [Layered Software Delivery](../ARCHITECTURE.md#4-layered-software-delivery)

## Context and Problem Statement

`coreutils` (`ls`, `cp`, `mv`, `rm`, `cat`, `sort`, and the rest of the ~100
basic file/text utilities) is written in C and runs constantly on every
stableOS system — every shell command, script, and systemd unit that touches
the filesystem goes through it. Per the [memory safety
principle](../ARCHITECTURE.md#3-prefer-memory-safe-tooling), a memory-safe
rewrite is worth adopting if it's credibly mature enough for daily use.

[uutils/coreutils](https://github.com/uutils/coreutils) is a cross-platform
Rust reimplementation of GNU coreutils, aiming for command-line compatibility.
Fedora packages it as `uutils-coreutils` (present in Fedora 44, the base for
this image). Fedora's own [Change
proposal](https://fedoraproject.org/wiki/Changes/Rust_Uutils_Coreutils_0.5_Nushell_0.109)
for updating it in Fedora 44 is explicit that they "don't plan to propose this
to be the default `coreutils` in Fedora at this moment" — it ships as an
opt-in package, installed alongside GNU coreutils under a `uu_`-prefixed
binary namespace (`/usr/bin/uu_ls`, `/usr/bin/uu_cp`, etc.), not as a drop-in
replacement.

That means there is no supported `dnf swap` path: the package doesn't
`Obsolete` or `Conflict` with `coreutils`, and `coreutils` can't simply be
removed — it's an implicit dependency of nearly everything else in the image,
including the build toolchain itself. A genuine system-wide swap requires
retargeting each `/usr/bin/<tool>` GNU binary at its uutils equivalent while
leaving the `coreutils` package installed (unused, but satisfying dependency
resolution for other packages).

## Considered Options

- **uutils-coreutils, full swap** — install `uutils-coreutils` and symlink
  every `/usr/bin/<tool>` it provides over the GNU binary of the same name, so
  the Rust implementation is what actually runs everywhere: interactive
  shells, scripts, and systemd units alike. `coreutils` stays installed
  (nothing obsoletes it, and too much depends on it to remove), but its
  binaries are shadowed and no longer reachable via `PATH`.
- **uutils-coreutils, PATH-shadowed for interactive shells only** — install
  uutils-coreutils and prepend its binaries to `PATH` for interactive user
  shells, leaving `/usr/bin` (and therefore systemd units, scripts, and the
  build toolchain) on GNU coreutils. Lower risk, but leaves most of the
  system — everything that doesn't go through an interactive shell — on the
  memory-unsafe implementation, which is most of what coreutils actually does
  on a running system.
- **Stay on GNU coreutils** — mature, exhaustively battle-tested, the de facto
  standard `sh`/`bash` scripts everywhere assume. Written in C, so it doesn't
  satisfy [principle 3](../ARCHITECTURE.md#3-prefer-memory-safe-tooling).

## Decision Outcome

Chosen: **uutils-coreutils, full swap**.

Fedora's decision to keep uutils-coreutils opt-in is about not disrupting the
distribution's entire user base by default, not a specific compatibility
finding against it — GNU-compatibility has been the project's explicit,
long-running goal, and Fedora ships it as a normal, signed package. For a
single-purpose personal image where the guiding principle is to prefer
memory-safe tooling when a candidate is credibly mature, shadowing only the
interactive shell doesn't satisfy the principle where it matters most:
coreutils spends the overwhelming majority of its runtime invoked by scripts,
systemd units, and other non-interactive callers, not typed at a prompt. A
partial swap would be memory-safe exactly where the blast radius is smallest
and unchanged where it's largest.

The real cost is the one Fedora's own Change proposal flags implicitly by not
defaulting to it: full coverage and identical behavior for every GNU flag and
edge case isn't guaranteed, and this is being done without Fedora's own
distribution-wide validation behind it. Given [ADR
0001](0001-immutable-operating-system.md)'s rollback story, a regression here
is recoverable — a bad boot rolls back to the prior deployment — so the risk
is judged acceptable for the safety gained. `coreutils` itself stays installed
(unshadowed but present) so removing it isn't a second, independent risk on
top of the swap; it satisfies dependency resolution for anything that still
lists it as a requirement without actually running.

### Consequences

- Good: the memory-unsafe C implementation is no longer what runs for
  everyday file operations across shells, scripts, and systemd units,
  satisfying [principle 3](../ARCHITECTURE.md#3-prefer-memory-safe-tooling).
- Good: [ADR 0001](0001-immutable-operating-system.md)'s atomic rollback is
  the safety net if the swap causes an unexpected regression — a bad boot is
  never a stuck boot.
- Bad: uutils-coreutils does not have Fedora's own distribution-wide
  validation behind it as a default — Fedora explicitly chose not to make
  this swap themselves yet. Any GNU-only flag or behavior a script or unit
  depends on that uutils hasn't replicated becomes a real breakage, discovered
  at build or boot time rather than ahead of time.
- Bad: the swap is maintained by hand (a symlink loop in the Containerfile,
  not a package-managed transition), so it isn't tracked or verified by dnf's
  dependency resolver the way a real package swap would be.

### Revisit Triggers

- If Fedora ships an official `dnf swap`-compatible transition (an
  `Obsoletes`/`Provides` package that replaces `coreutils` cleanly), switch to
  that instead of the hand-maintained symlink loop.
- If a build or boot regression is traced to a uutils/GNU behavioral
  difference that can't be worked around, reconsider scope (e.g. exclude the
  specific tool from the swap) before reverting the whole decision.
