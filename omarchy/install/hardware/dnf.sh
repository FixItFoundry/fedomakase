# Hardware-specific repository extensions for Fedora.
# On Arch, this appended to pacman.conf. On Fedora, we enable COPR repos instead.

# T2 MacBook support: if detected, enable the T2 COPR repo
if [[ -f /sys/class/dmi/id/board_name ]] && grep -qi "Mac" /sys/class/dmi/id/board_name 2>/dev/null; then
  echo "T2 Mac hardware detected — COPR repos for T2 support may need manual setup."
fi
