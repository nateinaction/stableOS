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
| [0009](0009-terminal-emulator.md) | Use Warp as the terminal emulator | Superseded by [0017](0017-terminal-emulator-alacritty.md) |
| [0010](0010-fuzzy-finding.md) | Use fzf for fuzzy finding | Superseded by [0018](0018-remove-fuzzy-finding-and-directory-navigation.md) |
| [0011](0011-directory-navigation.md) | Use zoxide for directory navigation | Superseded by [0018](0018-remove-fuzzy-finding-and-directory-navigation.md) |
| [0012](0012-shell.md) | Use fish as the interactive shell | Accepted |
| [0013](0013-private-mesh-networking.md) | Use Tailscale for private mesh networking | Accepted |
| [0014](0014-default-editor.md) | Use Helix as the default editor | Accepted |
| [0015](0015-password-management.md) | Password management | Accepted |
| [0016](0016-nix-store-on-immutable-host.md) | Hosting the Nix store on an immutable host | Accepted |
| [0017](0017-terminal-emulator-alacritty.md) | Use Alacritty as the terminal emulator | Accepted |
| [0018](0018-remove-fuzzy-finding-and-directory-navigation.md) | Remove fzf and zoxide from the image | Accepted |
