if omarchy-hw-aarch64-n1x; then
  echo "NVIDIA N1x platform detected; GPU driver policy is owned by hardware/n1x.sh"
elif lspci | grep -qi 'nvidia'; then
  # On Fedora, kernel headers are installed via the kernel-devel package
  omarchy-pkg-add kernel-devel

  # Fedora provides akmod-nvidia from RPM Fusion for automatic NVIDIA driver builds
  if ! rpm -q rpmfusion-nonfree-release &>/dev/null; then
    sudo dnf install -y \
      "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
      "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" \
      2>/dev/null || true
  fi

  PACKAGES=(akmod-nvidia xorg-x11-drv-nvidia-cuda libva-nvidia-driver)

  omarchy-pkg-add "${PACKAGES[@]}"

  # Per-session Hyprland NVIDIA env vars are handled by default/hypr/nvidia.lua.

  # Configure modprobe for early KMS
  mkdir -p /etc/modprobe.d
  cat > /etc/modprobe.d/nvidia.conf <<'MODEOF'
options nvidia_drm modeset=1
MODEOF

  # Configure dracut for early loading (Fedora uses dracut, not mkinitcpio)
  mkdir -p /etc/dracut.conf.d
  cat > /etc/dracut.conf.d/nvidia.conf <<'DRACUTEOF'
add_drivers+=" nvidia nvidia_modeset nvidia_uvm nvidia_drm "
DRACUTEOF
fi
