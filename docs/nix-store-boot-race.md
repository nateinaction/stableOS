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
