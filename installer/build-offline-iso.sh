#!/bin/bash
# Omarchy Fedora Offline ISO Build Script (build-offline-iso.sh)
# Builds a fully self-contained offline installer by mirroring the netinst packages locally.

set -euo pipefail

WORKSPACE_DIR="/home/jcasco/Projects/Omarchy Fedora Merge"
FEDORA_ISO="$WORKSPACE_DIR/Fedora-Everything-netinst-x86_64-44-1.7.iso"
OMARCHY_DIR="/home/jcasco/Projects/Fedora-Omarchy"
BUILD_DIR="/tmp/omarchy_offline_iso_build"
OUTPUT_ISO="/home/jcasco/Projects/Fedora-Omarchy/omarchy-fedora44-offline.iso"

echo -e "\e[32m=== Starting Omarchy Fedora Offline ISO Generation ===\e[0m"

# 1. Check prerequisites
if [[ ! -f "$FEDORA_ISO" ]]; then
  echo -e "\e[31mError: Base Fedora ISO not found at $FEDORA_ISO\e[0m" >&2
  exit 1
fi

if [[ ! -d "$OMARCHY_DIR" ]]; then
  echo -e "\e[31mError: Omarchy Fedora directory not found at $OMARCHY_DIR\e[0m" >&2
  exit 1
fi

# 2. Clean & prepare build workspace
echo "[1/6] Preparing offline build workspace..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/extracted"

# 3. Extract base Fedora ISO
echo "[2/6] Extracting base Fedora ISO..."
bsdtar -C "$BUILD_DIR/extracted" -xf "$FEDORA_ISO"

# 3.1 Extract the missing EFI and MAC boot partitions from the original ISO
echo "[3/6] Restoring UEFI bootloader partition..."
EFI_SECTOR=$(fdisk -l "$FEDORA_ISO" | awk '{ for(i=1;i<=NF;i++) if($i ~ /\.iso2$/) { print $(i+1); break } }')
EFI_SIZE=$(fdisk -l "$FEDORA_ISO" | awk '{ for(i=1;i<=NF;i++) if($i ~ /\.iso2$/) { print $(i+3); break } }')
if [[ -n "$EFI_SECTOR" && -n "$EFI_SIZE" ]]; then
  dd if="$FEDORA_ISO" of="$BUILD_DIR/efiboot.img" skip="$EFI_SECTOR" count="$EFI_SIZE" bs=512 status=none
else
  echo -e "\e[31mError: Could not find EFI partition in $FEDORA_ISO\e[0m" >&2
  exit 1
fi

MAC_SECTOR=$(fdisk -l "$FEDORA_ISO" | awk '{ for(i=1;i<=NF;i++) if($i ~ /\.iso3$/) { print $(i+1); break } }')
MAC_SIZE=$(fdisk -l "$FEDORA_ISO" | awk '{ for(i=1;i<=NF;i++) if($i ~ /\.iso3$/) { print $(i+3); break } }')
if [[ -n "$MAC_SECTOR" && -n "$MAC_SIZE" ]]; then
  dd if="$FEDORA_ISO" of="$BUILD_DIR/macboot.img" skip="$MAC_SECTOR" count="$MAC_SIZE" bs=512 status=none
fi

# 4. Inject Kickstart & Omarchy Fedora payload
echo "[4/6] Injecting Offline Kickstart and Omarchy payload..."
cp -f "$OMARCHY_DIR/installer/omarchy-ks-offline.cfg" "$BUILD_DIR/extracted/omarchy-ks-offline.cfg"
# Keep netinstall ks around just in case
cp -f "$OMARCHY_DIR/installer/omarchy-ks.cfg" "$BUILD_DIR/extracted/omarchy-ks.cfg" 

mkdir -p "$BUILD_DIR/extracted/omarchy-fedora"
cp -rf "$OMARCHY_DIR"/* "$BUILD_DIR/extracted/omarchy-fedora/"

# Download static gum for the installer UI
echo "Downloading static gum binary..."
wget -qO /tmp/gum.tar.gz "https://github.com/charmbracelet/gum/releases/download/v0.14.3/gum_0.14.3_Linux_x86_64.tar.gz" || true
tar -xf /tmp/gum.tar.gz -C /tmp || true
cp /tmp/gum_0.14.3_Linux_x86_64/gum "$BUILD_DIR/extracted/omarchy-fedora/installer/gum" 2>/dev/null || true
chmod +x "$BUILD_DIR/extracted/omarchy-fedora/installer/gum" 2>/dev/null || true

# 5. Mirror Packages for Offline Installation
echo "[5/6] Mirroring all required Fedora packages to local ISO repository..."
mkdir -p "$BUILD_DIR/extracted/omarchy-repo"
dnf download --resolve --alldeps \
  --destdir="$BUILD_DIR/extracted/omarchy-repo" \
  --repo=fedora --repo=updates --repo=copr-hyprland \
  --repofrompath=copr-hyprland,https://copr-be.cloud.fedoraproject.org/results/nett00n/hyprland/fedora-44-x86_64/ \
  hyprland hyprland-uwsm uwsm hyprpaper hyprlock hypridle waybar \
  rofi-wayland swaync slurp grim wl-clipboard brightnessctl pamixer \
  wireplumber pipewire pipewire-utils xdg-desktop-portal \
  xdg-desktop-portal-gtk xdg-desktop-portal-hyprland sddm qt6-qtwayland \
  qt6-qtdeclarative qt6-qt5compat qt6-qtsvg plymouth power-profiles-daemon \
  lxpolkit kitty foot neovim btop fastfetch fzf ripgrep fd-find eza \
  zoxide tmux gum bat git zsh bash-completion nautilus \
  evince loupe imv mpv gnome-disk-utility gnome-calculator flatpak \
  NetworkManager NetworkManager-wifi NetworkManager-bluetooth bluez \
  bluez-tools linux-firmware kernel-modules-extra \
  iwlwifi-dvm-firmware iwlwifi-mvm-firmware realtek-firmware \
  alsa-firmware wpa_supplicant iwd rfkill jq unzip tar xz p7zip \
  ca-certificates gcc gcc-c++ make clang llvm ruby lua python3 python3-pip \
  docker docker-compose google-noto-fonts-common google-noto-emoji-fonts \
  google-noto-sans-fonts jetbrains-mono-fonts-all yaru-icon-theme \
  avahi cups cups-filters fcitx5 fcitx5-gtk fcitx5-qt ImageMagick inxi \
  kdenlive luarocks obs-studio plocate python3-gobject qt5-qtwayland \
  snapper alsa-sof-firmware system-config-printer udiskie wtype xournalpp \
  yt-dlp btrfs-progs dosfstools exfatprogs gvfs-mtp gvfs-smb pipewire-alsa \
  pipewire-pulseaudio || true

echo "Generating createrepo metadata for local offline repo..."
if ! command -v createrepo_c &>/dev/null; then
  dnf install -y createrepo_c || true
fi
createrepo_c "$BUILD_DIR/extracted/omarchy-repo"

# 6. Update GRUB2 boot configuration for automatic Offline Kickstart (BIOS & EFI)
echo "[6/6] Updating bootloader configuration & repacking ISO..."
ISO_LABEL="Fedora-E-dvd-x86_64-44"

for cfg in "$BUILD_DIR/extracted/boot/grub2/grub.cfg" "$BUILD_DIR/extracted/EFI/BOOT/grub.cfg"; do
  if [[ -f "$cfg" ]]; then
    echo "Configuring bootloader at $cfg..."
    sed -i 's/set default=.*/set default="0"/' "$cfg"
    sed -i 's/set timeout=.*/set timeout=1/' "$cfg"
    if ! grep -q "inst.ks=" "$cfg"; then
      # FIX: Use omarchy-ks-offline.cfg here!
      sed -i "s|inst.stage2=hd:LABEL=[^ ]*|& inst.ks=hd:LABEL=$ISO_LABEL:/omarchy-ks-offline.cfg|g" "$cfg"
    fi
  fi
done

# Ensure xorriso is available since it is absolutely required for ISOHybrid UEFI/BIOS Boot
if ! command -v xorriso &>/dev/null; then
  echo "Installing local xorriso for proper boot headers..."
  mkdir -p /tmp/xorriso_local
  pushd /tmp/xorriso_local >/dev/null
  dnf download xorriso libisoburn libisofs libburn -yq || true
  for pkg in *.rpm; do
    rpm2cpio "$pkg" | cpio -idmv -W none &>/dev/null || true
    chmod -R u+w . 2>/dev/null || true
  done
  export PATH="/tmp/xorriso_local/usr/bin:$PATH"
  export LD_LIBRARY_PATH="/tmp/xorriso_local/usr/lib64:/tmp/xorriso_local/usr/lib:${LD_LIBRARY_PATH:-}"
  popd >/dev/null
fi

if command -v xorriso &>/dev/null; then
  xorriso -as mkisofs \
    -V "$ISO_LABEL" \
    -J -R -l \
    -b images/eltorito.img \
    -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
    -eltorito-alt-boot \
    -e '--interval:appended_partition_2:all::' \
    -no-emul-boot \
    --grub2-mbr "$BUILD_DIR/extracted/boot/grub2/i386-pc/boot_hybrid.img" \
    -partition_offset 16 \
    --protective-msdos-label \
    -append_partition 2 0xef "$BUILD_DIR/efiboot.img" \
    $([[ -f "$BUILD_DIR/macboot.img" ]] && echo "-append_partition 3 0x00 $BUILD_DIR/macboot.img") \
    -appended_part_as_gpt \
    -o "$OUTPUT_ISO" \
    "$BUILD_DIR/extracted"
else
  echo -e "\e[31mError: xorriso could not be found or downloaded. ISO generation aborted to prevent unbootable images.\e[0m" >&2
  exit 1
fi

echo -e "\e[32m=== Omarchy Fedora Full Offline ISO Build Complete: $OUTPUT_ISO ===\e[0m"
