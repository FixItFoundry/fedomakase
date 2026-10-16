# Configure DNF repositories after package installation completes.
# On Fedora, we ensure COPR repos from the single source of truth are enabled.

COPR_FILE="${OMARCHY_INSTALL:-/usr/share/omarchy/install}/omarchy-fedora-copr.repos"
if command -v dnf &>/dev/null && [[ -f "$COPR_FILE" ]]; then
  while IFS= read -r copr; do
    [[ -z "$copr" || "$copr" =~ ^[[:space:]]*# ]] && continue
    dnf copr enable -y "$copr" 2>/dev/null || true
  done < "$COPR_FILE"
fi

# Install all base packages from the manifest (single source of truth)
source "$OMARCHY_INSTALL/install-base-packages.sh"

source "$OMARCHY_INSTALL/hardware/dnf.sh"
