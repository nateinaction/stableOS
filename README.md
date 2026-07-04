# stableOS

A custom Fedora-based operating system built with **bootc** (bootable container), featuring the **COSMIC** desktop environment.

## Overview

stableOS is built on `quay.io/fedora-ostree-desktops/cosmic-atomic:44`, providing a modern COSMIC desktop in an image-mode (immutable root filesystem) setup. The image is built via GitHub Actions and published to `ghcr.io/nateinaction/stableos` for easy distribution and updates.

## Building Locally

Build the image with podman:

```bash
make
```

To create a bootable ISO for installing stableOS on a new machine:

```bash
make output/bootiso/stableos.iso
```

The ISO will be written to `output/bootiso/stableos.iso`.

## Installed Packages

stableOS includes a curated set of applications and tools baked into the image:

- **Tailscale** — Secure networking daemon (run `sudo tailscale up` after first boot to configure).
- **chezmoi** — Dotfile manager for reproducible, versioned user configuration.
- **Claude Code** — Anthropic's agentic coding CLI (run `claude` to start; requires a Claude account).
- **Warp** — Modern Rust-based terminal with AI and collaboration features (launch from the app grid or run `warp-terminal`).
- **Alacritty** — Fast, GPU-accelerated terminal emulator (launch from the app grid or run `alacritty`).
- **1Password** — Password manager + browser extension (installed via the official 1Password RPM repo).
- **Flathub** — Preconfigured on first boot for easy Flatpak app installation via COSMIC Store.

### Recommended Post-Install Apps

Install these via Flatpak (COSMIC Store or `flatpak install`) after first boot:

- **Firefox** — `flatpak install flathub org.mozilla.firefox` (web browser with great Flatpak integration)

### Post-Install Setup

1. **Install apps via COSMIC Store or Flatpak CLI:** On first boot, Flathub is configured. Use COSMIC Store to browse and install, or install from the terminal:
   ```bash
   flatpak install flathub org.mozilla.firefox
   ```

2. **Tailscale:** After starting Tailscale, authenticate with your account:
   ```bash
   sudo tailscale up
   ```

3. **Dotfiles:** Set up your personal shell config, aliases, and desktop settings with chezmoi:
   ```bash
   chezmoi init --apply nateinaction  # pulls github.com/nateinaction/dotfiles
   ```
   Keep your dotfiles in a **separate repository** from stableOS; the image handles global defaults, while your dotfiles repo handles per-user customization.

### Automatic Updates

stableOS pulls new images weekly and stages them for the next reboot. Check status with:
```bash
systemctl status bootc-fetch-apply-updates.timer
```

To disable automatic updates:
```bash
systemctl disable bootc-fetch-apply-updates.timer
```

## Installation

### On Bare Metal

1. Flash the ISO to a USB drive:
   ```bash
   dd if=output/bootiso/stableos.iso of=/dev/sdX bs=4M status=progress
   ```
   (Replace `/dev/sdX` with your USB device.)

2. Boot the target machine from the USB drive.

3. Run through the Anaconda installer:
   - Create your user account (this user will have `wheel` group privileges).
   - Complete the installation.

4. Reboot into stableOS.

5. Follow the **Post-Install Setup** section above.

### Switching an Existing Fedora Atomic Machine

If you already have a bootc-enabled Fedora Atomic system, switch to stableOS:

```bash
bootc switch ghcr.io/nateinaction/stableos:latest
```

## Updates

After installation, fetch the latest image from GHCR:

```bash
sudo bootc upgrade
```

This pulls new images published to the registry and stages them for the next reboot.

To reboot into the update automatically once it's staged:

```bash
sudo bootc upgrade --apply
```

To check whether an update is available without staging it:

```bash
sudo bootc upgrade --check
```

If an update misbehaves, roll back to the previous deployment:

```bash
sudo bootc rollback
```

## Verifying the Image

Published images are signed with [cosign](https://github.com/sigstore/cosign) using the
key in `cosign.pub`. Verify a pulled image against it:

```bash
cosign verify --key cosign.pub ghcr.io/nateinaction/stableos:latest
```

Installed systems also enforce this automatically: `/etc/containers/policy.json` (baked
into the image) requires a valid signature for `ghcr.io/nateinaction/stableos`, so
`bootc upgrade` refuses any unsigned or mis-signed image.

## Repository Structure

- `Containerfile` — Container image definition
- `Makefile` — Local build, lint, test, and ISO targets
- `.github/workflows/build.yml` — Build, test, sign, and publish the image to GHCR
- `.github/workflows/iso.yml` — On-demand installer ISO build from a published image
- `config.toml` — Optional bootc-image-builder configuration
- `container-structure-test.yaml` — Image acceptance tests
- `cosign.pub` — Public key used to verify image signatures
- `.pre-commit-config.yaml` — Formatting and lint hooks
- `renovate.json` — Automated dependency updates
- `files/` — Files copied into the image (systemd units, `/etc/skel` defaults, container signature policy, module configs)
- `README.md` — This file
- `.gitignore` — Git ignore rules

## Notes

- **Flatpak-first approach:** GUI applications like Firefox are installed via Flatpak for better portability and security. System daemons (Tailscale) and apps that ship an official RPM repo (1Password) remain RPM-based.
- **Image mode:** `/` is immutable; system updates are applied to new image layers via `bootc upgrade`. User data in `/home` persists across updates.

## Future Enhancements

- Unattended installation via custom Anaconda kickstart
