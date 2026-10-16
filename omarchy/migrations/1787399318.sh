echo "Switch from quickshell-git to quickshell"

[[ -f /etc/fedora-release ]] && exit 0

if omarchy-pkg-present quickshell-git; then
  sudo pacman -S --noconfirm --ask 4 quickshell
fi
