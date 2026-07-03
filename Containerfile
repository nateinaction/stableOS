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
