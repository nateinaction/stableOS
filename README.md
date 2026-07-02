# stableOS

A custom Fedora-based operating system built with **bootc** (bootable container), featuring the **COSMIC** desktop environment.

## Overview

stableOS is built on `quay.io/fedora-ostree-desktops/cosmic-atomic:43`, providing a modern COSMIC desktop in an image-mode (immutable root filesystem) setup. The image is built via GitHub Actions and published to `ghcr.io/nateinaction/stableos` for easy distribution and updates.

## Building Locally

Build the image with podman:

```bash
sudo podman build -t stableos .
```

## Producing an Installation ISO

To create a bootable ISO for installing stableOS on a new machine:

```bash
sudo podman run --rm -it --privileged \
  --security-opt label=type:unconfined_t \
  -v ./output:/output \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type iso --local ghcr.io/nateinaction/stableos:latest
```

The ISO will be written to `output/bootiso/install.iso`.

## Installation

### On Bare Metal

1. Flash the ISO to a USB drive:
   ```bash
   sudo dd if=output/bootiso/install.iso of=/dev/sdX bs=4M status=progress
   ```
   (Replace `/dev/sdX` with your USB device.)

2. Boot the target machine from the USB drive.

3. Run through the Anaconda installer:
   - Create a user account (this user will have `wheel` group privileges).
   - Complete the installation.

4. Reboot into stableOS.

### Switching an Existing Fedora Atomic Machine

If you already have a bootc-enabled Fedora Atomic system, switch to stableOS:

```bash
sudo bootc switch ghcr.io/nateinaction/stableos:latest
```

## Updates

After installation, fetch the latest image from GHCR:

```bash
sudo bootc upgrade
```

This pulls new images published to the registry and stages them for the next reboot.

## Repository Structure

- `Containerfile` — Container image definition
- `.github/workflows/build.yml` — GitHub Actions CI/CD pipeline
- `config.toml` — Optional bootc-image-builder configuration
- `README.md` — This file
- `.gitignore` — Git ignore rules

## Future Enhancements

- Image signing with cosign/sigstore
- Customized package set and system defaults
- Unattended installation via custom Anaconda kickstart
