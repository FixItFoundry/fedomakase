echo "Ensure quickshell is installed for Fedora"

if [[ -f /etc/fedora-release ]]; then
  if ! rpm -q quickshell &>/dev/null; then
    sudo dnf install -y quickshell
    omarchy-state set restart-shell-required
  fi
  exit 0
fi

if ! omarchy-pkg-present quickshell-git; then
  # One transaction with --ask 4 so pacman accepts replacing the conflicting
  # quickshell package in place; packages depending on quickshell stay
  # satisfied through the provides.
  sudo pacman -S --noconfirm --ask 4 quickshell-git
  omarchy-state set restart-shell-required
fi
