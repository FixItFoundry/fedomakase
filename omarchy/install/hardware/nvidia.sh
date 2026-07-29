if lspci | grep -qi 'nvidia'; then
  # On Fedora, kernel headers are installed via the kernel-devel package
  omarchy-pkg-add kernel-devel

  # Fedora provides akmod-nvidia from RPM Fusion for automatic NVIDIA driver builds
  # Enable RPM Fusion if not already enabled
  if ! rpm -q rpmfusion-nonfree-release &>/dev/null; then
    sudo dnf install -y \
      "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
      "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" \
      2>/dev/null || true
  fi

  PACKAGES=(akmod-nvidia xorg-x11-drv-nvidia-cuda)

  omarchy-pkg-add "${PACKAGES[@]}"

  # Per-session Hyprland NVIDIA env vars are handled by default/hypr/nvidia.lua.

  # Configure modprobe for early KMS
  mkdir -p /etc/modprobe.d
  cat > /etc/modprobe.d/nvidia.conf <<'EOF'
options nvidia_drm modeset=1
EOF

  # Configure dracut for early loading (Fedora uses dracut, not mkinitcpio)
  mkdir -p /etc/dracut.conf.d
  cat > /etc/dracut.conf.d/nvidia.conf <<'EOF'
add_drivers+=" nvidia nvidia_modeset nvidia_uvm nvidia_drm "
EOF
fi
