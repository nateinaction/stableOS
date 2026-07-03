FROM quay.io/fedora-ostree-desktops/cosmic-atomic:44@sha256:0dd577894925b5b9af2d5944acb878d3db4e61a2fa15944eceeb224cbf96da8b

LABEL title="stableOS" \
      description="Custom Fedora bootc COSMIC desktop environment" \
      source="https://github.com/nateinaction/stableOS"

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

# Add Claude Code repo and install claude-code.
RUN dnf5 -y config-manager addrepo \
        --id=claude-code \
        --set=name="Claude Code" \
        --set=baseurl=https://downloads.claude.ai/claude-code/rpm/stable \
        --set=gpgcheck=1 \
        --set=gpgkey=https://downloads.claude.ai/keys/claude-code.asc && \
    dnf5 install -y claude-code && \
    dnf5 clean all

# Install the Broadcom wl WiFi driver for MacBook hardware.
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
