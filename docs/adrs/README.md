# Architecture Decision Records

This directory records the significant architectural decisions behind stableOS,
using the [MADR](https://adr.github.io/madr/) format. Each record is immutable
once accepted; if a decision changes, add a new ADR that supersedes the old one
rather than editing history.

| ADR | Title | Status |
| --- | --- | --- |
| [0001](0001-immutable-operating-system.md) | Build on an immutable operating system | Accepted |
| [0002](0002-automated-updates.md) | Automated updates | Accepted |
| [0003](0003-verified-signed-updates.md) | Verified, signed updates | Accepted |
| [0004](0004-minimize-update-deltas.md) | Minimize update download deltas | Accepted |
| [0005](0005-single-build-toolchain.md) | Single build toolchain | Accepted |
| [0006](0006-desktop-environment.md) | Use the COSMIC desktop environment | Accepted |
| [0007](0007-layered-software-delivery.md) | Layered software delivery | Accepted |
| [0008](0008-declarative-user-state.md) | Declarative user state with chezmoi and Nix | Accepted |
| [0009](0009-terminal-emulator.md) | Use Warp as the terminal emulator | Accepted |
| [0010](0010-fuzzy-finding.md) | Use fzf for fuzzy finding | Accepted |
| [0011](0011-directory-navigation.md) | Use zoxide for directory navigation | Accepted |
