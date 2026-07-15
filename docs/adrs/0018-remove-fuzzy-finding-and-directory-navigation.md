# Remove fzf and zoxide from the image

- Status: accepted
- Date: 2026-07-14
- Deciders: nateinaction
- Guiding principles: [Layered Software Delivery](../ARCHITECTURE.md#4-layered-software-delivery)
- Supersedes: [ADR 0010](0010-fuzzy-finding.md), [ADR 0011](0011-directory-navigation.md)

## Context and Problem Statement

[ADR 0010](0010-fuzzy-finding.md) and [ADR 0011](0011-directory-navigation.md)
chose fzf and zoxide as image RPMs, reasoning that they were foundational,
shared dependencies (a directory jumper's interactive mode delegates to the
fuzzy finder) that belonged in the curated system layer rather than left to
each user to pick.

In practice, fzf and zoxide are personal interactive-shell ergonomics, not
system-level dependencies anything else in the image relies on — no other
image RPM or system service requires them at build or runtime. That makes
them a better fit for user-owned, per-user configuration
([ADR 0008](0008-declarative-user-state.md)) than for the OS image: shipping
them in the image pins their version to the image release cadence and forces
every user into the same choice, where a user-owned Nix flake lets each
person pick, version, and update their own tooling independently.

[PR #45](https://github.com/nateinaction/stableOS/pull/45) removed both
(along with `/etc/skel` defaults for them) and moved their management to
[nateinaction/dotfiles](https://github.com/nateinaction/dotfiles), a
user-owned Nix flake, consistent with how other per-user tooling is already
handled there.

## Considered Options

- **Keep shipping fzf and zoxide as image RPMs** (status quo per ADR 0010 /
  ADR 0011) — every user gets them for free, but pinned to the image's
  release cadence and dnf-packaged versions.
- **Remove them from the image; manage via user dotfiles (Nix flake)** — each
  user opts in, chooses versions, and updates independently of image
  releases; the OS image sheds two packages that nothing else depends on.

## Decision Outcome

Chosen: **remove fzf and zoxide from the image; manage them in
[nateinaction/dotfiles](https://github.com/nateinaction/dotfiles)**.

Neither tool is a dependency of anything else shipped in the image — the
"shared dependency" framing in ADR 0010 / ADR 0011 was about them depending on
*each other*, not about other system components depending on *them*. That
makes them ergonomics, not platform, and ergonomics belong in user-owned
config per [ADR 0008](0008-declarative-user-state.md), not baked into the
image.

### Consequences

- Good: two fewer packages in the image's build, update, and CVE surface.
- Good: users can choose their own version/cadence for fzf and zoxide (or skip
  them entirely) without waiting on an image release.
