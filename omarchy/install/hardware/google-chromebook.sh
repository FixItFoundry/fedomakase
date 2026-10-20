# Googlebook / Chromebook hardware setup (e.g. Acer Googlebook 14 GP714-91N / Moonstone on Google_Fatcat)
# Configures top-row action keys via keyd, SoundWire/SOF audio packages, and
# RW_LEGACY (edk2) fallback UEFI bootloader path (\EFI\BOOT\BOOTX64.EFI).

if [[ -e /dev/cros_ec ]] || grep -qiE '^(Google|ChromiumOS)' /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/board_vendor /sys/class/dmi/id/product_family 2>/dev/null; then
  # Ensure Sound Open Firmware and ALSA UCM profiles are installed for SoundWire SDCA (ALC721 + ALC1320)
  omarchy-pkg-add alsa-sof-firmware alsa-ucm || true

  # Configure keyd for Googlebook / ChromeEC Strauss top-row action keys
  if ! command -v keyd &>/dev/null; then
    sudo dnf copr enable -y alternateved/keyd 2>/dev/null || true
    omarchy-pkg-add keyd || true
  fi

  if command -v keyd &>/dev/null; then
    sudo mkdir -p /etc/keyd /usr/share/keyd
    sudo touch /usr/share/keyd/keyd.compose
    sudo tee /etc/keyd/cros.conf >/dev/null <<'EOF'
[ids]
0000:0000
0001:0001
18d1:*

[main]
f1 = back
f2 = forward
f3 = refresh
f4 = f11
f5 = scale
f6 = brightnessdown
f7 = brightnessup
f8 = mute
f9 = volumedown
f10 = volumeup
back = back
forward = forward
refresh = refresh
scale = f11
brightnessdown = brightnessdown
brightnessup = brightnessup
mute = mute
volumedown = volumedown
volumeup = volumeup

[meta]
f1 = f1
f2 = f2
f3 = f3
f4 = f4
f5 = f5
f6 = f6
f7 = f7
f8 = f8
f9 = f9
f10 = f10
back = f1
forward = f2
refresh = f3
scale = f4
brightnessdown = f6
brightnessup = f7
mute = f8
volumedown = f9
volumeup = f10
EOF
    sudo systemctl enable keyd.service 2>/dev/null || true
  fi

  # Coreboot RW_LEGACY (edk2) does not persist custom UEFI NVRAM BootOrder entries across cold boots;
  # ensure Fedora's signed shim/GRUB is mirrored at the standard removable fallback path \EFI\BOOT\BOOTX64.EFI.
  if [[ -d /boot/efi/EFI/fedora ]]; then
    sudo mkdir -p /boot/efi/EFI/BOOT
    [[ -f /boot/efi/EFI/fedora/shimx64.efi ]] && sudo cp -f /boot/efi/EFI/fedora/shimx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI || true
    [[ -f /boot/efi/EFI/fedora/grubx64.efi ]] && sudo cp -f /boot/efi/EFI/fedora/grubx64.efi /boot/efi/EFI/BOOT/grubx64.efi || true
    [[ -f /boot/efi/EFI/fedora/grub.cfg ]] && sudo cp -f /boot/efi/EFI/fedora/grub.cfg /boot/efi/EFI/BOOT/grub.cfg || true
  fi
fi
