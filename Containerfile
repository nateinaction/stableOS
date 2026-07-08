FROM quay.io/fedora-ostree-desktops/cosmic-atomic:44@sha256:f113e0cc80bf403ad8cd5489f71bae23bf36d7537d1ebbb9c2ba0f5287ca4de0

LABEL title="stableOS" \
      description="Custom Fedora bootc COSMIC desktop environment" \
      source="https://github.com/nateinaction/stableOS"

# Make /opt usable for RPMs that install there.
#
# The base image ships /opt as a symlink to /var/opt (the writable, persistent
# model). /var/opt does not exist at build time, so RPM's cpio unpack fails with
# "mkdir failed - No such file or directory" when creating /opt/<app>. Replacing
# the symlink with a real directory makes /opt part of the immutable image, which
# is the intended model for software baked in at build time. Trade-off: /opt is
# read-only at runtime.
#
# https://bootc.dev/bootc/building/guidance.html
# https://github.com/bootc-dev/bootc/discussions/1038
RUN rm -f /opt && mkdir -p /opt

# Remove the Firefox RPM shipped by the base image. Firefox is installed as a
# Flatpak (org.mozilla.firefox) instead — see README — so the base RPM is a
# redundant, separately-updated duplicate.
RUN dnf5 remove -y firefox firefox-langpacks && dnf5 clean all

# Add Tailscale repo and install tailscale + tailscaled daemon.
# Ref: ADR-0013 (private-mesh-networking)
RUN dnf5 -y config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo && \
    dnf5 install -y tailscale && \
    systemctl enable tailscaled.service && \
    dnf5 clean all

# Install Fish shell and set it as the default shell for new users.
# Ref: ADR-0012 (shell)
RUN dnf5 install -y fish && \
    echo "/usr/bin/fish" >> /etc/shells && \
    useradd -D --shell /usr/bin/fish && \
    dnf5 clean all

# Install helix.
# Ref: ADR-0014 (default-editor)
RUN dnf5 install -y helix && dnf5 clean all

# Install chezmoi for dotfile management.
# Ref: ADR-0008 (declarative-user-state)
RUN dnf5 install -y chezmoi && dnf5 clean all

# Add Warp terminal repo and install warp-terminal.
# Ref: ADR-0009 (terminal-emulator)
RUN dnf5 -y config-manager addrepo \
        --id=warpdotdev \
        --set=name=warpdotdev \
        --set=baseurl=https://releases.warp.dev/linux/rpm/stable \
        --set=gpgcheck=1 \
        --set=gpgkey=https://releases.warp.dev/linux/keys/warp.asc && \
    dnf5 install -y warp-terminal && \
    dnf5 clean all

# Install Alacritty, a minimal memory-safe (Rust) terminal emulator.
# Ref: ADR-0009 (terminal-emulator) — the account-free fallback to Warp.
RUN dnf5 install -y alacritty && dnf5 clean all

# Add 1Password repo and install the 1Password desktop app and CLI (`op`).
# Ref: ADR-0015 (password-management)
RUN rpm --import https://downloads.1password.com/linux/keys/1password.asc && \
    dnf5 -y config-manager addrepo \
        --id=1password \
        --set=name="1Password Stable Channel" \
        --set=baseurl=https://downloads.1password.com/linux/rpm/stable/\$basearch \
        --set=enabled=1 \
        --set=gpgcheck=1 \
        --set=repo_gpgcheck=1 \
        --set=gpgkey=https://downloads.1password.com/linux/keys/1password.asc && \
    dnf5 install -y 1password 1password-cli && \
    dnf5 clean all

# Install Nix (multi-user) and direnv for per-project development environments.
# Ref: ADR-0008 (declarative-user-state)
#
# Nix gives per-project dev shells (`nix develop` against a flake.nix) without
# rebuilding the image. Fedora 44 ships Nix natively; nix-daemon pulls in
# nix-core and nix-filesystem for the multi-user daemon.
#
# The store must live at a real /nix (not a symlink) so the binary cache, whose
# artifacts hard-code /nix/store paths, can substitute prebuilt toolchains. /nix
# isn't writable on the immutable root, so nix.mount bind-mounts the persistent,
# per-machine /var/nix onto /nix at boot; nix-store-init.service seeds /var/nix
# from the image skeleton before the mount (see docs/adrs/0016-nix-store-on-immutable-host.md). We
# create /nix here as the bind-mount target and enable the daemon + mount.
#
# nix-direnv (not in Fedora repos) is a single shell file fetched at a pinned
# version; its direnvrc lets a project `.envrc` with `use flake` auto-activate.
# renovate: datasource=github-releases depName=nix-community/nix-direnv
ARG NIX_DIRENV_VERSION=3.1.1
RUN dnf5 install -y nix-core nix-daemon direnv && \
    mkdir -p /nix /usr/share/nix-direnv && \
    curl -fsSL -o /usr/share/nix-direnv/direnvrc \
        "https://raw.githubusercontent.com/nix-community/nix-direnv/${NIX_DIRENV_VERSION}/direnvrc" && \
    dnf5 clean all

# Copy Nix daemon/store configuration, the store-seed oneshot, and bind-mount unit.
COPY files/nix/nix.conf /etc/nix/nix.conf
COPY files/systemd/nix-store-init.service /usr/lib/systemd/system/
COPY files/systemd/nix.mount /usr/lib/systemd/system/
COPY files/systemd/nix-daemon.service.d/ /usr/lib/systemd/system/nix-daemon.service.d/

# Install a scoped SELinux policy module so systemd may create the nix-daemon
# socket under /nix (labeled default_t because the store lives on /var). Without
# it the socket unit fails "Permission denied" under enforcing and Nix is
# unusable. checkpolicy/policycoreutils-devel provide checkmodule and
# semodule_package; they are build-only, so install, compile, and remove them in
# one layer. See docs/adrs/0016-nix-store-on-immutable-host.md.
# Ref: ADR-0008 (declarative-user-state)
COPY files/selinux/nix-daemon-socket.te /tmp/nix-daemon-socket.te
RUN dnf5 install -y checkpolicy policycoreutils-devel && \
    checkmodule -M -m -o /tmp/nix-daemon-socket.mod /tmp/nix-daemon-socket.te && \
    semodule_package -o /tmp/nix-daemon-socket.pp -m /tmp/nix-daemon-socket.mod && \
    semodule -i /tmp/nix-daemon-socket.pp && \
    dnf5 remove -y checkpolicy policycoreutils-devel && \
    dnf5 clean all && \
    rm -f /tmp/nix-daemon-socket.te /tmp/nix-daemon-socket.mod /tmp/nix-daemon-socket.pp

# Enable the Nix store bind mount and the socket-activated daemon. nix.mount
# pulls in nix-store-init.service via its Requires=, so enabling the mount is
# enough; the daemon is socket-activated.
RUN systemctl enable nix.mount nix-daemon.socket

# Install the Broadcom wl WiFi driver for MacBook hardware.
# Ref: https://github.com/nateinaction/stableOS/issues/38
#
# broadcom-wl ships as an akmod (source module) that must be compiled against the
# kernel baked into this image. Two things make this tricky in a container build:
#
#  1. Kernel version: we build for the image's kernel-core, NOT `uname -r` (which
#     is the build host's kernel). The matching kernel-devel must exist in the
#     repos, which requires a stable Fedora base.
#  2. Root: akmodsbuild refuses to run as root (it treats a writable /var as
#     "root"). The akmod-wl %post scriptlet builds directly as root and fails, so
#     we install it with scriptlets disabled and instead invoke the `akmods`
#     wrapper, which drops to the unprivileged `akmods` user to compile wl.ko.
RUN dnf5 install -y \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" && \
    KERNEL_VERSION="$(rpm -q kernel-core --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')" && \
    dnf5 install -y akmods "kernel-devel-${KERNEL_VERSION}" && \
    dnf5 install -y --setopt=tsflags=noscripts broadcom-wl && \
    akmods --force --kernels "${KERNEL_VERSION}" && \
    modinfo -k "${KERNEL_VERSION}" wl && \
    dnf5 clean all

# Force-load applesmc so the MacBook keyboard backlight LED is available.
COPY files/modules-load.d/applesmc.conf /usr/lib/modules-load.d/

# Enable automatic image updates via bootc.
RUN systemctl enable bootc-fetch-apply-updates.timer

# Copy systemd units.
COPY files/systemd/flathub-setup.service /usr/lib/systemd/system/

# Copy skeleton defaults for new users.
COPY files/skel/ /etc/skel/

# Bake in the cosign public key and container signature policy so installed
# systems verify this image's signature on every `bootc upgrade`. The policy
# leaves the default permissive (base/flatpak/other pulls keep working) and
# only *requires* a valid signature for ghcr.io/nateinaction/stableos.
COPY cosign.pub /etc/pki/containers/stableos.pub
COPY files/containers/policy.json /etc/containers/policy.json
COPY files/containers/registries.d/ /etc/containers/registries.d/

# Enable first-boot Flathub setup.
RUN systemctl enable flathub-setup.service

# Ensure image is valid for bootc/image-mode.
RUN bootc container lint
