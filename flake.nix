{
  description = "stableOS development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        # Single manifest for the dev/lint/test toolchain shared by local
        # workflows (via direnv + .envrc) and CI (via `nix develop -c ...`).
        # podman is intentionally omitted: it ships in the Fedora Atomic base OS
        # and is preinstalled on CI runners, which run privileged/rootful builds.
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            gnumake
            hadolint
            container-structure-test
            pre-commit
          ];

          shellHook = ''
            # Idempotently install the git hooks on shell entry so every clone
            # and worktree (activated via direnv) commits through pre-commit —
            # otherwise lint that only CI's --all-files run catches slips through.
            if [ -d .git ] || git rev-parse --git-dir >/dev/null 2>&1; then
              pre-commit install --install-hooks >/dev/null 2>&1 || true
            fi
          '';
        };
      }
    );
}
