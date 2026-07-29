# Configure DNF repositories after package installation completes.
# On Fedora, we ensure COPR repos are enabled and DNF is configured correctly.

# Restore cups-browsed config if needed
if [[ -f /etc/cups/cups-browsed.conf.rpmnew ]]; then
  cp -f /etc/cups/cups-browsed.conf.rpmnew /etc/cups/cups-browsed.conf
fi

# Enable COPR repos if not already enabled
if command -v dnf &>/dev/null; then
  dnf copr enable -y nett00n/hyprland 2>/dev/null || true
fi

# Install all base packages from the manifest (single source of truth)
source "$OMARCHY_INSTALL/install-base-packages.sh"

source "$OMARCHY_INSTALL/hardware/dnf.sh"
