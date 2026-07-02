FROM quay.io/fedora-ostree-desktops/cosmic-atomic:43

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

# Install Fish shell and set it as the default shell.
RUN dnf5 install -y fish && \
    echo "/usr/bin/fish" >> /etc/shells && \
    dnf5 clean all

# Install chezmoi for dotfile management.
RUN dnf5 install -y chezmoi && dnf5 clean all

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
