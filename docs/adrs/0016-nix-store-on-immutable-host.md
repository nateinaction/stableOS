# Hosting the Nix store on an immutable host

- Status: accepted
- Date: 2026-07-05
- Deciders: nateinaction
- Guiding principles: [Immutability and Reliability](../ARCHITECTURE.md#1-immutability-and-reliability), [Portability and Reproducibility](../ARCHITECTURE.md#2-portability-and-reproducibility), [Layered Software Delivery](../ARCHITECTURE.md#4-layered-software-delivery)

## Context and Problem Statement

[ADR 0007](0007-layered-software-delivery.md) and [ADR 0008](0008-declarative-user-state.md)
put developer toolchains in a **Nix** tier (`nix develop` against a project
`flake.nix`, auto-activated by direnv). Those ADRs decide *that* Nix is used;
this one decides *how* Nix is made to work on an immutable, image-mode host,
which is not free.

Nix imposes two hard constraints:

- The store must live at a **real, writable `/nix`**. Nix refuses a symlinked
  `/nix`, and the binary cache ships artifacts with absolute `/nix/store` paths
  hard-coded, so substitution only works if the store is genuinely at `/nix`.
- On an immutable root ([ADR 0001](0001-immutable-operating-system.md)), the
  `/nix` baked into the image is **read-only**, so it cannot host a live store.

So writable state must be layered onto a read-only path without breaking the
immutability guarantee, and it must come up reliably on every boot with no
manual intervention. Getting this wrong makes the entire Nix tier — the OS's
whole dev-environment story — unusable: every `nix` call fails with
`/nix/store/.links: Read-only file system`.

## Considered Options

- **Symlink `/nix` → `/var/nix`.** Simplest, but Nix rejects a symlinked store
  outright. Non-starter.
- **Bake a writable store into the image.** Contradicts immutability; the store
  is machine-local, mutable state and does not belong in the shared image.
- **Bind-mount a `/var`-backed store onto a real `/nix`, created at boot.** Keep
  the store on writable, upgrade-persistent `/var/nix`; bind-mount it onto the
  real (image-provided) `/nix` directory at boot; socket-activate `nix-daemon`.
  For creating/seeding `/var/nix` on first boot, two sub-options:
  - **tmpfiles rule + mount condition** — a `d /var/nix` tmpfiles entry creates
    it, and `nix.mount` guards itself with `ConditionPathExists=/var/nix`.
  - **explicit seeding oneshot ordered before the mount** — a `Type=oneshot`
    unit seeds `/var/nix` from the image skeleton, ordered `Before=nix.mount`
    and `RequiredBy=nix.mount`.
- **For the daemon socket under SELinux:** relabel the socket directory to an
  `init_var_run_t`-style type, **or** ship a scoped policy module allowing the
  needed operations on the observed type.

## Decision Outcome

Chosen: **a `/var`-backed store bind-mounted onto `/nix`, seeded by an explicit
first-boot oneshot, with a scoped SELinux policy module for the daemon socket.**

**Store location and mount.** The real store lives on `/var/nix` (writable,
machine-local, persists across upgrades). `nix.mount` bind-mounts `/var/nix`
onto `/nix` at boot; `nix-daemon` is socket-activated. `/nix` stays part of the
immutable image as the bind-mount target — nothing writable is baked in.

**First-boot seeding (oneshot, not tmpfiles).** The tmpfiles-plus-condition
approach loses a boot-ordering race: `nix.mount` is evaluated while reaching
`local-fs.target`, but `systemd-tmpfiles-setup.service` is ordered *after*
`local-fs.target`, so on first boot `ConditionPathExists=/var/nix` is checked
**before** anything has created `/var/nix`. A skipped mount condition is not
retried, so `/nix` stays read-only for the rest of the boot and Nix is dead.

Instead, `nix-store-init.service` (`Type=oneshot`, `Before=nix.mount`,
`RequiredBy=nix.mount`, guarded by `ConditionPathExists=!/var/nix`) seeds
`/var/nix` from the read-only image skeleton (`cp -a /nix/. /var/nix/`,
preserving the sticky, `akmods`-group store permissions) and creates the
directory itself, so no tmpfiles rule is needed. `nix.mount` gains
`Requires=`/`After=nix-store-init.service`. Because `/var/nix` persists, the
seed runs only on the first boot after install.

**SELinux policy module.** Because the store physically lives on `/var`, the
`/nix` bind mount inherits `/var/nix`'s labels, so `/nix` and everything under it
resolve to `default_t` — and neither Fedora's `nix-core`/`nix-daemon` RPMs nor
this image ship any Nix SELinux policy. Under enforcing SELinux, systemd
(`init_t`) is then denied creating the daemon socket
(`/nix/var/nix/daemon-socket/socket`, a `sock_file` labeled `default_t`), so the
socket unit fails `Permission denied` even as root and Nix stays unusable. The
image bakes a scoped module (`files/selinux/nix-daemon-socket.te`) granting
exactly the observed operations:

```text
allow init_t default_t:sock_file { create write unlink };
```

`create`/`write` cover binding the socket on first boot. `unlink` is required
too: the stock `nix-daemon.socket` unit does not set `RemoveOnStop=`, so the
socket file persists on `/var` across reboots, and on the **second and every
later boot** systemd must `unlink` the stale socket before rebinding — a denial
the first-boot-only path never exercises. The module is compiled and installed
at build time (`checkmodule` + `semodule_package` + `semodule -i`, with the
build-only `checkpolicy`/`policycoreutils-devel` installed and removed in the
same layer), and `container-structure-test.yaml` asserts `semodule -l` lists it.

The **relabel** alternative (retype the socket dir to an `init_var_run_t`-style
type) was set aside as untested; the scoped module is proven to bring the socket
up under enforcing SELinux, and stays deliberately narrow — scoped to the
observed denials, with unrelated `bootupd_t` noise excluded.

### Consequences

- Good: the Nix tier from [ADR 0007](0007-layered-software-delivery.md) actually
  works on the immutable host — a real writable store at `/nix` with binary-cache
  substitution intact.
- Good: immutability is preserved — the writable store is machine-local `/var`
  state; the image only provides the read-only `/nix` bind-mount target.
- Good: reproducible and hands-off — a fresh install seeds and mounts the store
  on first boot with no manual steps, serving portability.
- Good: the store persists across atomic upgrades because it lives on `/var`.
- Bad: several coupled moving parts (seed oneshot, bind mount, socket activation,
  SELinux module) must all stay in lockstep; a regression in any one silently
  breaks Nix.
- Bad: the image carries a **custom SELinux policy module** to maintain, because
  no upstream Nix policy fits a `/var`-backed store. It is scoped to
  `init_t`/`default_t`, broader than an ideal `nix_*`-typed policy would be.
- Bad: this path cannot be validated in the build sandbox — it requires a real
  install, and because the `unlink` denial only appears on the **second** boot,
  validation must include a reboot, not just first boot.

The full debugging trace behind this decision — symptoms, journal evidence for
the boot-ordering race and each SELinux denial, and the in-place recovery steps
for a machine already stuck — is recorded in the
[troubleshooting runbook](https://github.com/nateinaction/stableOS/issues/29#issuecomment-4888351191).

### Revisit Triggers

- If a proper **Nix SELinux policy** (`nix_*` types + fcontext for `/nix`) lands
  upstream or in the Fedora RPMs, drop the scoped module and adopt it, or switch
  to the label-based approach.
- If the `nix-daemon.socket` unit gains `RemoveOnStop=` (or ships one upstream),
  the `unlink` grant may become unnecessary — narrow the module accordingly.
- If Nix ever supports a store at an arbitrary path (removing the hard-coded
  `/nix/store` assumption), the bind-mount indirection could be dropped.
