# Use a Nix flake as the single build/lint/test toolchain

- Status: accepted
- Date: 2026-07-04
- Deciders: nateinaction

## Context and Problem Statement

Building, linting, and testing stableOS needs a toolchain: `make`, `hadolint`,
`container-structure-test`, `fish` (config syntax checks), and `pre-commit`.
This toolchain has to run in two places — a contributor's machine and CI — and
they must stay in lockstep, or "works on my machine" / "passes locally, fails in
CI" drift creeps in.

The host is an immutable Fedora Atomic system ([ADR 0001](0001-immutable-image-mode-base.md)),
where layering build tools into the base OS is discouraged, so the toolchain
should not be installed system-wide. It also should not be baked into the
stableOS image itself — build tooling is not something end users need.

stableOS originally solved this with **Makefile targets that downloaded pinned
tool binaries into a `build/` directory** (leftovers of which still linger in
`build/`: `hadolint-v2.14.0`, `fish-4.8.0`, `uv`). That worked but had to
hand-manage per-tool download/pin/extract logic for each platform. This ADR
records the move away from it.

## Considered Options

- **Nix flake dev shell** (`flake.nix` + `.envrc`) — declare the toolchain once
  in `devShells.default`; direnv auto-loads it locally, CI runs `nix develop -c`.
- **Makefile downloads binaries into `build/`** (the original approach) — each
  tool fetched at a pinned version by a `make` recipe into a local `build/` dir.
- **System packages / rpm-ostree layering** — install the tools onto each host.

## Decision Outcome

Chosen: a **Nix flake dev shell** as the single toolchain manifest, replacing the
Makefile-downloads-into-`build/` approach. `flake.nix` defines
`devShells.default` with the pinned toolchain; `.envrc` (`use flake`)
auto-activates it via direnv on `cd`; CI installs Nix and runs targets with
`nix develop -c make …`. `flake.lock` pins nixpkgs so local and CI resolve
byte-identical tool versions.

This is the **same Nix** the OS offers to end users for dev environments
([ADR 0003](0003-software-delivery-tiers.md)) — here applied to stableOS's own
build tooling. Compared to the `build/`-download approach it removes all the
bespoke per-tool fetch/pin/extract logic: adding a tool is one line in
`flake.nix`, versions are pinned centrally in `flake.lock`, and multi-platform
resolution is handled by nixpkgs. It keeps the immutable base OS clean (nothing
layered in), keeps the shipped image lean (no build tools baked in), and makes
one manifest the single source of truth for both humans and CI.

`podman` is deliberately **excluded** from the flake: it ships in the Fedora
Atomic base and is preinstalled on CI runners, and the build runs rootful/
privileged, so pulling podman from Nix would add friction for no benefit.
`PODMAN` is overridable in the `Makefile` for hosts where it lives elsewhere.

### Consequences

- Good: one manifest (`flake.nix` + `flake.lock`) drives local and CI toolchains,
  eliminating version drift between them.
- Good: adding or bumping a tool is a one-line change, versus the per-tool
  download/pin/extract scripting the `build/` approach required.
- Good: no build tools are layered into the immutable host or baked into the
  shipped image; the toolchain is per-project and reproducible.
- Good: onboarding is `direnv allow` (or `nix develop`) — no manual tool install.
- Good: consistent with the OS's broader Nix-for-dev-environments strategy, so
  contributors use one mechanism.
- Bad: contributors must have Nix (with flakes) and direnv installed; on non-
  stableOS hosts that is a prerequisite to learn. (stableOS itself ships both.)
- Bad: CI pays the cost of installing Nix and realizing the dev shell on each run.
- Bad: the podman carve-out means one tool is out-of-band from the manifest and
  relies on the host/runner providing it.
