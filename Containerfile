FROM quay.io/fedora-ostree-desktops/cosmic-atomic:43

LABEL title="stableOS" \
      description="Custom Fedora bootc COSMIC desktop environment" \
      source="https://github.com/nateinaction/stableOS"

# Example package layering with dnf5
# Uncomment and add packages as needed for real customization:
# RUN dnf5 install -y \
#     package-one \
#     package-two && \
#     dnf5 clean all

# Optional: wire up Flathub for COSMIC Store
# RUN flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Ensure image is valid for bootc/image-mode
RUN bootc container lint
