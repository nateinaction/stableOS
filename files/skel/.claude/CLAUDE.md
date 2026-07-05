# Environment

This machine runs an **immutable Fedora Atomic** distribution (rpm-ostree based, e.g. Silverblue/Kinoite/Bluefin). The base OS image is read-only and updated atomically. Do **not** assume you can freely `dnf install` packages into the system — layering packages with `rpm-ostree install` is possible but discouraged and requires a reboot. Avoid mutating the base system.

## Dependency management: use Nix

Manage project and development dependencies with **Nix**, not system packages or `rpm-ostree` layering. This keeps the base OS clean and makes environments reproducible and per-project.

For each repository:

- Add a **`flake.nix`** defining the project's dev environment (`devShells.default`) with all needed tools and dependencies.
- Add an **`.envrc`** file so that **direnv** automatically loads the environment on `cd` into the repo. Typically:

  ```
  use flake
  ```

- direnv activates the flake's dev shell automatically when entering the directory, so tools are available without polluting the global system.

When setting up a new repo or adding a dependency, prefer adding it to the repo's `flake.nix` rather than installing it globally.
