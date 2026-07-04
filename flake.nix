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
            fish
            pre-commit
          ];

          shellHook = ''
            echo "stableOS dev shell — make, hadolint, container-structure-test, fish, pre-commit"
          '';
        };
      }
    );
}
