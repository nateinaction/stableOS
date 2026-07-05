# Automated updates

- Status: accepted
- Date: 2026-07-04
- Deciders: nateinaction
- Guiding principle: [Continuous, Automated Updates](../ARCHITECTURE.md#6-continuous-automated-updates)

## Context and Problem Statement

stableOS pins many external dependencies for reproducibility: the base image
digest, GitHub Actions (by SHA), pre-commit hooks, the nixpkgs flake input, and
version-pinned artifacts fetched in the `Containerfile` (e.g. nix-direnv). Pinned
dependencies are reproducible but go stale — and stale dependencies mean missed
security fixes, which cuts against the safety goal. Keeping them current by hand
is tedious and easy to forget for a single-maintainer project.

How should dependency updates be kept current with minimal manual effort while
preserving the pin-everything discipline?

## Considered Options

- **Renovate** — a bot that opens PRs to bump pinned dependencies across many
  ecosystems (Docker, GitHub Actions, pre-commit, Nix, generic regex).
- **Dependabot** — GitHub-native, but narrower ecosystem coverage.
- **Manual updates** — bump versions by hand as noticed.

## Decision Outcome

Chosen: **Renovate** (`renovate.json`), extending `config:recommended` with:

- **`pinDigests: true`** — keep dependencies pinned to digests/SHAs (aligns with
  the reproducibility discipline) while Renovate handles moving the pins forward.
- **Enabled managers** beyond the defaults: `pre-commit`, `nix` (flake.lock), and
  the `dockerfile` manager pointed at `Containerfile`. In-Containerfile artifacts
  like nix-direnv are tracked via `# renovate:` comments.
- **`automerge: true` (automergeType: pr)** for non-major updates, so routine
  bumps flow through with minimal attention.
- **Major updates require manual review** (`matchUpdateTypes: [major] →
  automerge: false`) — the changes most likely to break get a human.
- **Base image capped at GA Fedora** — `quay.io/fedora-ostree-desktops/cosmic-atomic`
  is restricted to `allowedVersions: "<=44"` so Renovate only proposes the base
  bump once the next Fedora reaches general availability; the cap is raised by
  hand when a new Fedora GAs (~April/October).

CI gates every Renovate PR (lint + build + structure tests), so automerge only
lands changes that pass the same checks as any other PR.

### Consequences

- Good: dependencies stay current — including security fixes — with little
  manual effort, without abandoning digest/SHA pinning.
- Good: broad ecosystem coverage in one tool (Docker, Actions, pre-commit, Nix,
  regex-tracked artifacts).
- Good: risk-tiered automation — routine bumps automerge, majors and base-OS
  jumps stay manual/gated.
- Good: CI is the safety net; nothing automerges that fails the build/tests.
- Bad: automerge trusts CI coverage; a gap in the tests could let a bad
  non-major update land unattended.
- Bad: the Fedora `allowedVersions` cap is a manual knob that must be bumped each
  release, or base-OS updates silently stall.
- Bad: a steady stream of PRs to review/observe, even if most automerge.
