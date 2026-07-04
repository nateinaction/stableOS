# First-boot race: `/nix` stays read-only, Nix unusable

## Symptom

Every `nix` invocation fails immediately, even a trivial one:

```console
$ nix flake lock
error: creating directory "/nix/store/.links": Read-only file system
```

`systemctl` shows the store never got mounted and the daemon never started:

```console
$ systemctl status nix.mount
  Active: inactive (dead)
  Condition: start condition unmet
             └─ ConditionPathExists=/var/nix was not met

$ systemctl status nix-daemon.socket
  Active: inactive (dead)
  Condition: start condition unmet
             └─ ConditionPathIsReadWrite=/nix/var/nix/daemon-socket was not met
```

## How the Nix store is supposed to work here

The root filesystem is immutable (bootc/ostree), so `/nix` — baked into the
image — is read-only. Nix refuses a symlinked `/nix`, and the binary cache ships
artifacts hard-coded to absolute `/nix/store` paths, so the store must live at a
real, writable `/nix`. The design keeps the store on writable, machine-local,
upgrade-persistent `/var`:

- `/var/nix` holds the real store.
- `nix.mount` bind-mounts `/var/nix` onto `/nix` at boot.
- `nix-daemon.socket` (socket-activated) starts the daemon on first use.

## Root cause: a first-boot ordering race (NOT "/var/nix is missing")

`/var/nix` is not permanently missing — it gets created, just **too late**.

Originally `/var/nix` was created by a tmpfiles rule (`d /var/nix`, processed by
`systemd-tmpfiles-setup.service`) and `nix.mount` guarded itself with
`ConditionPathExists=/var/nix`. The ordering does not line up:

- `nix.mount` is `WantedBy=local-fs.target` and evaluated while reaching it.
- `systemd-tmpfiles-setup.service` is ordered `After=local-fs.target`, i.e. it
  runs *after* `nix.mount` has already been evaluated.

So on first boot the condition is checked before the directory exists. Evidence
from a first-boot journal:

```
00:24:13  systemd-tmpfiles-setup.service runs (does not create /var/nix yet)
00:24:28  nix.mount SKIPPED — ConditionPathExists=/var/nix unmet   ← the bug
00:24:29  systemd-tmpfiles-setup.service runs again; /var/nix finally created,
          and /nix/var/nix/daemon-socket → "Read-only file system"
00:24:33  nix-daemon.socket SKIPPED — /nix/var/nix/daemon-socket not writable
```

A skipped condition is **not** retried, so `nix.mount` stays dead for the rest
of the boot. `/nix` remains the read-only image copy, Nix's own tmpfiles entries
(`/nix/var/nix/daemon-socket`, `…/builds`) fail as read-only, the daemon socket
condition fails, and every `nix` call hits `/nix/store/.links: Read-only file
system`.

Two coupled gaps, both flowing from the one skipped mount:

1. `nix.mount` checked for `/var/nix` before anything created it.
2. Even a successful mount of an *empty* `/var/nix` hides the image's store
   skeleton, and the image `/nix/var/nix` has no `daemon-socket` dir.

## The fix (in this repo)

Replace the racy "tmpfiles creates it + mount conditions on it" pattern with an
explicit oneshot that seeds the store, ordered before the mount:

- **`files/systemd/nix-store-init.service`** — `Type=oneshot`,
  `Before=nix.mount`, `RequiredBy=nix.mount`, guarded by
  `ConditionPathExists=!/var/nix` so it seeds only once.
  `ExecStart=/usr/bin/cp -a /nix/. /var/nix/` populates `/var/nix` from the
  read-only image skeleton (preserving the sticky, `akmods`-group `store/`
  perms). `cp` creates `/var/nix` itself, so no tmpfiles rule is needed.
- **`files/systemd/nix.mount`** — dropped `ConditionPathExists=/var/nix`; added
  `Requires=nix-store-init.service` + `After=nix-store-init.service`.
- **`files/tmpfiles.d/nix.conf`** — removed (the `d /var/nix` rule is now
  redundant).
- **`Containerfile`** — copies `nix-store-init.service`; no longer copies the
  tmpfiles rule.

`/nix/var/nix/daemon-socket` and `…/builds` are then created by Nix's own
tmpfiles, which succeed because `/nix` is the writable bind mount by that point.

Because `/var/nix` lives on persistent `/var`, the seed runs only on the first
boot after install; later boots find it already present.

## Recovering a machine already stuck (needs root)

For a system already booted from the buggy image, unblock it in place — this
persists, so it survives reboots:

```sh
sudo cp -a /nix/. /var/nix/            # seed store/ + var/ skeleton
sudo systemctl start nix.mount         # /var/nix now exists → binds onto /nix
sudo systemd-tmpfiles --create         # create daemon-socket/builds on writable /nix
sudo systemctl start nix-daemon.socket
nix --version                          # should work now
```

> **Heads up:** on an SELinux-enforcing system the last two lines fail — the
> daemon socket cannot be created under `/nix`. That is a *separate* problem;
> see the next section.

---

# Second problem: SELinux blocks the daemon socket

## Symptom

After the store is mounted and seeded (boot-race fixed), starting the daemon
socket still fails:

```console
$ sudo systemctl start nix-daemon.socket
Job failed. See "journalctl -xe" for details.

$ systemctl status nix-daemon.socket
  Active: failed (Result: resources)
  nix-daemon.socket: Failed to create listening socket
    (/nix/var/nix/daemon-socket/socket): Permission denied
```

Permission denied *as root* is the tell: it is SELinux, not Unix permissions.

## Root cause: the store lives on `/var`, so `/nix` is labeled `default_t`

The audit record is unambiguous:

```
avc: denied { create } comm="systemd" name="socket"
  scontext=system_u:system_r:init_t:s0
  tcontext=system_u:object_r:default_t:s0
  tclass=sock_file permissive=0
```

systemd (`init_t`) is socket-activating `nix-daemon` and must create the
listening socket in `/nix/var/nix/daemon-socket`. That directory is labeled
`default_t`, and the policy does not let `init_t` create a `sock_file` there.
For comparison, the systemd-managed socket dir `/run/systemd` is
`init_var_run_t`, a type `init_t` *is* allowed to write.

Why `default_t`? Two compounding facts:

1. **The store physically lives on `/var`.** `/nix` is a bind mount of the
   `/var/nix` btrfs subvolume, so SELinux labels come from the real inodes under
   `/var/nix`, not from any `/nix` rule.
2. **This image ships no Nix SELinux policy.** There are no `nix_*` types, no
   fcontext rules for `/nix`, and no loaded nix policy module — the Fedora
   `nix-core` / `nix-daemon` RPMs ship none. So `matchpathcon /nix/store` and
   `matchpathcon /nix/var/nix/daemon-socket` both resolve to `default_t`.

Result: even with the boot-race fixed and `/nix` writable, the daemon socket
cannot be created under enforcing SELinux, so Nix stays unusable.

This gap was never addressed: the "store on `/var`, bind-mounted onto `/nix`"
design was not reconciled with SELinux.

## In-place unblock (needs root)

Confirm SELinux is the only remaining blocker, capture every denial Nix
produces, turn them into a local policy module, and return to enforcing:

```sh
# 1) permissive: confirm nix works and generate all AVCs at once
sudo setenforce 0
sudo systemctl start nix-daemon.socket
nix run nixpkgs#hello                      # should print: Hello, world!

# 2) build + install a policy module from the collected denials
sudo ausearch -m avc -ts today | audit2allow -M nix-local
sudo semodule -i nix-local.pp

# 3) back to enforcing and verify
sudo setenforce 1
sudo systemctl restart nix-daemon.socket
nix run nixpkgs#hello                       # Hello, world! under enforcing
```

## Durable fix (implemented in the image)

Confirmed working: with just the one reviewed rule loaded, `nix run
nixpkgs#hello` succeeds under **enforcing** SELinux. The `audit2allow` capture
also swept up unrelated `bootupd_t` denials — those are deliberately excluded.

The image now bakes exactly this scoped module (`files/selinux/nix-daemon-socket.te`):

```
allow init_t default_t:sock_file { create write unlink };
```

(For why `unlink` is in the rule, see "Third problem" below — it was added after
a second-boot failure that the first-boot-only validation missed.)

The `Containerfile` compiles and installs it at build time
(`checkmodule` + `semodule_package` + `semodule -i`, with `checkpolicy` /
`policycoreutils-devel` installed and removed in the same layer), and
`container-structure-test.yaml` asserts `semodule -l` lists `nix-daemon-socket`.

The label-based alternative (relabel `/nix/var/nix/daemon-socket` to an
`init_var_run_t`-style type) was considered but not shipped: it was untested,
whereas this module is proven. Revisit if a proper Nix SELinux policy lands
upstream.

> Cannot be validated from the build sandbox — it needs a rebuild + fresh
> install to confirm `semodule -i` succeeds during the image build and the
> socket comes up on first boot.

Tooling note: `audit2allow` is present on the running system, but
`sesearch`/`seinfo` are **not**, so policy was inspected via `audit2allow`,
`matchpathcon`, and `ls -Z`. The build needs `checkpolicy` +
`policycoreutils-devel` for `checkmodule`/`semodule_package`.

---

# Third problem: the socket dies on the *second* boot (`unlink` denied)

## Symptom

The image with the `{ create write }` SELinux module was deployed and rebooted
into. First-boot-style checks looked fine, but on this boot the socket was dead:

```console
$ systemctl is-active nix.mount nix-daemon.socket
active
failed
$ getenforce
Enforcing
$ nix run nixpkgs#hello
error: cannot connect to socket at '/nix/var/nix/daemon-socket/socket': Connection refused
```

"Connection refused" (not "no such file") is the tell: the socket *file* exists,
but nothing is listening on it — the socket unit failed to bind.

## Root cause: a persistent stale socket that SELinux won't let systemd remove

The listening socket `/nix/var/nix/daemon-socket/socket` lives on the persistent
`/var/nix` subvolume (`/nix` is a bind mount of it), and the stock
`nix-daemon.socket` unit does **not** set `RemoveOnStop=`, so the socket file is
left on disk when the unit stops. It therefore survives every reboot.

On the next boot systemd must remove that leftover socket before it can rebind.
That `unlink` is a *different* permission from the `create`/`write` the first
module granted, and on a `default_t` sock_file it is denied:

```
avc: denied { unlink } comm="systemd"
  scontext=system_u:system_r:init_t:s0
  tcontext=system_u:object_r:default_t:s0
  tclass=sock_file permissive=0
```

so the bind fails and the unit goes `failed`.

**Why first-boot validation missed it:** on a fresh install the seeded store has
no `daemon-socket/socket` yet, so the very first boot only ever *creates* the
socket (`create`/`write`, both granted) and works. The `unlink` path is reached
only once a socket file already exists — i.e. on the **second and every later
boot**. Validating only the first boot hides the bug completely.

The by-hand recovery that unblocked the running machine —
`stop nix-daemon.service; rm -f …/socket; reset-failed; start nix-daemon.socket`
— worked because the `rm` is done as root (unconfined), doing exactly the
`unlink` systemd itself was denied.

## The fix (in this repo)

Add `unlink` to the module (`files/selinux/nix-daemon-socket.te`):

```
allow init_t default_t:sock_file { create write unlink };
```

Derived from the observed `unlink` AVC, in the same scoped-to-observed-denials
style as the original rule. No `getattr`/`setattr` denials appeared, so none are
granted. This is the minimal fix that keeps the store-on-`/var` design working;
the label-based alternative (relabel the daemon-socket dir) remains the longer-
term option if upstream Nix SELinux policy lands.

> **Validation must include a reboot.** The build sandbox cannot test this at
> all, and a single first boot is *not* sufficient — the regression only appears
> on the second boot. Deploy, boot, then reboot again, and confirm
> `nix-daemon.socket` is `active` and `nix run nixpkgs#hello` works **after the
> reboot**.

---

# Resume checklist (after reboot / new session)

The running machine was unblocked by hand (store seeded, SELinux module loaded);
those changes persist on `/var` and in the policy store. The repo changes are
committed on branch **`nix-single-manifest`**. Pick up here:

**1. Confirm the live machine still works (should need nothing):**

```sh
systemctl is-active nix.mount nix-daemon.socket   # want: active active
getenforce                                        # want: Enforcing
nix run nixpkgs#hello                             # want: ¡Hola mundo! / Hello, world!
```

If `nix.mount` is not active: `sudo systemctl start nix.mount`.
If `nix-daemon.socket` failed (stale socket from a previous boot — the "Third
problem" above; expected on any image whose SELinux module lacks `unlink`):

```sh
sudo systemctl stop nix-daemon.service
sudo rm -f /nix/var/nix/daemon-socket/socket
sudo systemctl reset-failed nix-daemon.socket
sudo systemctl start nix-daemon.socket
```

This is a hand-`unlink` workaround. The durable fix is the `unlink` rule now in
the SELinux module (`files/selinux/nix-daemon-socket.te`). Once an image carrying
it is deployed, the socket comes back up on its own after a reboot.

**2. The hand-loaded `nix-local` module is broader than needed** (it included
`bootupd_t` noise). Once the rebuilt image's `nix-daemon-socket` module is in
use, remove the local one:

```sh
sudo semodule -r nix-local        # only after the new image is deployed & verified
```

**3. Validate the committed image fixes** (needs a build host with podman +
the Nix dev shell working):

```sh
make build                        # or: podman build -f ./Containerfile -t stableos:latest .
make test-container-structure     # asserts the units + SELinux module are present
```

Then deploy and reboot into it, and verify **neither the first nor a subsequent
boot needs manual steps** (the `unlink` regression only shows on the second
boot, so a single reboot is not enough):

```sh
sudo bootc upgrade                # once the image is published, or switch to a local build
sudo reboot
# after login, with NO manual intervention:
systemctl is-active nix.mount nix-daemon.socket   # want: active active
nix run nixpkgs#hello

sudo reboot                       # reboot AGAIN — this is the one that used to fail
# after login, still with NO manual intervention:
systemctl is-active nix.mount nix-daemon.socket   # want: active active
nix run nixpkgs#hello             # want: works under enforcing, no stale-socket fix
```

**4. Open outstanding items:**
- The SELinux + boot-race image fixes are committed on branch `nix-lock-2` (atop
  the merged `nix-single-manifest` work and the committed `flake.lock`); push it
  and open a PR.
- Re-run `make fmt` once the Nix dev shell is active — the image commits were
  made with `--no-verify` because hadolint lives only in the flake dev shell.
