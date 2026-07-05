# Architecture Decision Records

This directory records the significant architectural decisions behind stableOS,
using the [MADR](https://adr.github.io/madr/) format. Each record is immutable
once accepted; if a decision changes, add a new ADR that supersedes the old one
rather than editing history.

| ADR | Title | Status |
| --- | --- | --- |
| [0001](0001-immutable-operating-system.md) | Build on an immutable operating system | Accepted |
| [0002](0002-memory-safe-language-north-star.md) | Prefer applications built on memory safe languages | Accepted |
| [0003](0003-automated-updates.md) | Ensure continual automated updates | Accepted |
| [0004](0004-cosign-image-signing.md) | Update delivery verification | Accepted |
| [0005](0005-ci-rechunk-publish-pipeline.md) | Rechunk images into deterministic layers before publishing | Accepted |
| [0006](0006-nix-build-toolchain-manifest.md) | Use a Nix flake as the single build/lint/test toolchain | Accepted |
| [0007](0007-desktop-environment.md) | Use the COSMIC desktop environment | Accepted |
| [0008](0008-software-delivery-tiers.md) | Deliver software in tiers: System services, sandboxed, developer environments | Accepted |
