FROM quay.io/fedora-ostree-desktops/cosmic-atomic:45@sha256:2c42315f5fab9e04fcda5db19ef0451a6970e3b3e91fb418c49322419261589f

LABEL title="stableOS" \
      description="Custom Fedora bootc COSMIC desktop environment" \
      source="https://github.com/nateinaction/stableOS"

# Fix /opt so 1Password persists across boots.
# On bootc, /opt is a symlink to /var/opt (non-persistent), so we redirect it to /usr/lib/opt (in the image).
RUN rm -rf /opt && mkdir -p /usr/lib/opt && ln -s /usr/lib/opt /opt

# Add Tailscale repo and install tailscale + tailscaled daemon.
RUN dnf5 -y config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo && \
    dnf5 install -y tailscale && \
    systemctl enable tailscaled.service && \
    dnf5 clean all

# Install vim.
RUN dnf5 install -y vim && dnf5 clean all

# Install Fish shell and set it as the default shell.
RUN dnf5 install -y fish && \
    echo "/usr/bin/fish" >> /etc/shells && \
    dnf5 clean all

# Install chezmoi for dotfile management.
RUN dnf5 install -y chezmoi && dnf5 clean all

# Add GitHub CLI repo and install gh.
RUN dnf5 -y config-manager addrepo --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo && \
    dnf5 install -y gh && \
    dnf5 clean all

# Install Node.js and the Claude Code CLI (installs system-wide under /usr).
RUN dnf5 install -y nodejs npm && \
    npm install -g @anthropic-ai/claude-code@2.1.200 && \
    npm cache clean --force && \
    dnf5 clean all

# Install Broadcom wl WiFi driver for MacBook hardware.
# broadcom-wl is an akmod (source kernel module), so it must be compiled against
# the kernel baked into this image. We detect that kernel version from the
# installed kernel-core package (NOT `uname -r`, which is the build host's kernel)
# and force akmods to build for it. The resulting wl.ko lands in /usr/lib/modules.
RUN dnf5 install -y \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" && \
    KERNEL_VERSION="$(rpm -q kernel-core --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')" && \
    dnf5 install -y akmods "kernel-devel-${KERNEL_VERSION}" broadcom-wl && \
    akmods --force --kernels "${KERNEL_VERSION}" && \
    modinfo -k "${KERNEL_VERSION}" wl && \
    dnf5 clean all

# Enable automatic image updates via bootc.
RUN systemctl enable bootc-fetch-apply-updates.timer

# Copy systemd units.
COPY files/systemd/flathub-setup.service /usr/lib/systemd/system/

# Copy COSMIC skeleton defaults for new users.
COPY files/skel/ /etc/skel/

# Enable first-boot Flathub setup.
RUN systemctl enable flathub-setup.service

# Ensure image is valid for bootc/image-mode.
RUN bootc container lint
