# Fish shell configuration for stableOS
# Global defaults applied to all new users at install time.
# Personal configuration and aliases should be managed via chezmoi.

# Suppress the startup message.
set fish_greeting

# Set up a simple prompt if desired (Fish has excellent defaults).
# Personal prompt customization can be applied via chezmoi.

# Ensure Flathub is in PATH for flatpak apps.
if not contains /usr/local/bin $PATH
    set -gx PATH /usr/local/bin $PATH
end

# Initialize chezmoi completion if available.
if type -q chezmoi
    chezmoi completion fish | source
end

# Initialize zoxide (directory jumper).
if type -q zoxide
    zoxide init fish | source
end

# Add packages installed with `nix profile install` to PATH.
if not contains $HOME/.nix-profile/bin $PATH
    set -gx PATH $HOME/.nix-profile/bin $PATH
end

# Hook direnv so project .envrc files (e.g. `use flake`) auto-load dev environments.
if type -q direnv
    direnv hook fish | source
end
