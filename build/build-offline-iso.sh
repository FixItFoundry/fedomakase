#!/bin/bash
# Omarchy Fedora Offline ISO Build Script
# Builds a fully self-contained offline installer by mirroring packages locally.
#
# Prerequisites:
#   - Fedora Everything Netinstall ISO (Fedora-Everything-netinst-x86_64-44-*.iso)
#   - bsdtar, xorriso, createrepo_c (installed automatically if missing)
#
# Usage:
#   sudo bash build/build-offline-iso.sh /path/to/Fedora-Everything-netinst-x86_64-44-*.iso

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
OMARCHY_DIR="$REPO_DIR/omarchy"

FEDORA_ISO="${1:-}"
if [[ -z "$FEDORA_ISO" ]]; then
  echo "Usage: sudo bash $0 /path/to/Fedora-Everything-netinst-x86_64-44-*.iso" >&2
  exit 1
fi

if [[ ! -f "$FEDORA_ISO" ]]; then
  echo "Error: Base Fedora ISO not found at $FEDORA_ISO" >&2
  exit 1
fi

if [[ ! -d "$OMARCHY_DIR" ]]; then
  echo "Error: Omarchy source not found at $OMARCHY_DIR" >&2
  exit 1
fi

BUILD_DIR="/tmp/fedomakase_offline_iso_build"
OUTPUT_ISO="$REPO_DIR/fedomakase-offline-44-x86_64.iso"
ISO_LABEL="Fedora-E-dvd-x86_64-44"

echo -e "\e[32m=== Starting Fedomakase Offline ISO Build ===\e[0m"

# 1. Clean & prepare build workspace
echo "[1/7] Preparing offline build workspace..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/extracted"

# 2. Extract base Fedora ISO
echo "[2/7] Extracting base Fedora ISO..."
bsdtar -C "$BUILD_DIR/extracted" -xf "$FEDORA_ISO"

# 3. Extract EFI and MAC boot partitions
echo "[3/7] Restoring UEFI bootloader partition..."
EFI_SECTOR=$(fdisk -l "$FEDORA_ISO" | awk '{ for(i=1;i<=NF;i++) if($i ~ /\.iso2$/) { print $(i+1); break } }')
EFI_SIZE=$(fdisk -l "$FEDORA_ISO" | awk '{ for(i=1;i<=NF;i++) if($i ~ /\.iso2$/) { print $(i+3); break } }')
if [[ -n "$EFI_SECTOR" && -n "$EFI_SIZE" ]]; then
  dd if="$FEDORA_ISO" of="$BUILD_DIR/efiboot.img" skip="$EFI_SECTOR" count="$EFI_SIZE" bs=512 status=none
else
  echo "Error: Could not find EFI partition in $FEDORA_ISO" >&2
  exit 1
fi

MAC_SECTOR=$(fdisk -l "$FEDORA_ISO" | awk '{ for(i=1;i<=NF;i++) if($i ~ /\.iso3$/) { print $(i+1); break } }')
MAC_SIZE=$(fdisk -l "$FEDORA_ISO" | awk '{ for(i=1;i<=NF;i++) if($i ~ /\.iso3$/) { print $(i+3); break } }')
if [[ -n "$MAC_SECTOR" && -n "$MAC_SIZE" ]]; then
  dd if="$FEDORA_ISO" of="$BUILD_DIR/macboot.img" skip="$MAC_SECTOR" count="$MAC_SIZE" bs=512 status=none
fi

# 4. Inject Kickstart & Omarchy payload
echo "[4/7] Injecting Offline Kickstart and Omarchy payload..."
cp -f "$OMARCHY_DIR/installer/omarchy-ks-offline.cfg" "$BUILD_DIR/extracted/omarchy-ks-offline.cfg"
cp -f "$OMARCHY_DIR/installer/omarchy-ks.cfg" "$BUILD_DIR/extracted/omarchy-ks.cfg"

mkdir -p "$BUILD_DIR/extracted/omarchy-fedora"
rsync -a --exclude="*.iso" "$OMARCHY_DIR/" "$BUILD_DIR/extracted/omarchy-fedora/"

# Download static gum for installer UI
echo "Downloading static gum binary..."
wget -qO /tmp/gum.tar.gz "https://github.com/charmbracelet/gum/releases/download/v0.14.3/gum_0.14.3_Linux_x86_64.tar.gz" || true
tar -xf /tmp/gum.tar.gz -C /tmp || true
cp /tmp/gum_0.14.3_Linux_x86_64/gum "$BUILD_DIR/extracted/omarchy-fedora/installer/gum" 2>/dev/null || true
chmod +x "$BUILD_DIR/extracted/omarchy-fedora/installer/gum" 2>/dev/null || true

# 5. Mirror Packages for Offline Installation
echo "[5/7] Mirroring all required Fedora packages to local ISO repository..."
mkdir -p "$BUILD_DIR/extracted/omarchy-repo"
dnf download --resolve --alldeps --skip-unavailable \
  --destdir="$BUILD_DIR/extracted/omarchy-repo" \
  --repo=fedora --repo=updates --repo=copr-hyprland \
  --repofrompath=copr-hyprland,https://copr-be.cloud.fedoraproject.org/results/nett00n/hyprland/fedora-44-x86_64/ \
  hyprland hyprpaper hyprlock hypridle waybar \
  rofi-wayland swaync slurp grim wl-clipboard brightnessctl pamixer \
  wireplumber pipewire pipewire-utils xdg-desktop-portal \
  xdg-desktop-portal-gtk xdg-desktop-portal-hyprland sddm qt6-qtwayland \
  qt6-qtdeclarative qt6-qt5compat qt6-qtsvg plymouth power-profiles-daemon \
  kitty foot neovim btop fastfetch fzf ripgrep fd-find eza \
  zoxide starship tmux gum bat lazygit git zsh bash-completion nautilus \
  evince loupe imv mpv gnome-disk-utility gnome-calculator flatpak \
  NetworkManager NetworkManager-wifi NetworkManager-bluetooth bluez \
  bluez-tools bluez-firmware linux-firmware kernel-modules-extra \
  iwl7260-firmware iwlwifi-dvm-firmware iwlwifi-mvm-firmware realtek-firmware \
  alsa-firmware wpa_supplicant iwd rfkill jq unzip tar xz p7zip \
  ca-certificates gcc gcc-c++ make clang llvm ruby lua python3 python3-pip \
  google-noto-fonts-common google-noto-emoji-fonts \
  google-noto-sans-fonts jetbrains-mono-fonts-all || true

echo "Generating createrepo metadata for local offline repo..."
if ! command -v createrepo_c &>/dev/null; then
  dnf install -y createrepo_c || true
fi
createrepo_c "$BUILD_DIR/extracted/omarchy-repo"

# 6. Update GRUB2 boot configuration
echo "[6/7] Updating bootloader configuration..."
for cfg in "$BUILD_DIR/extracted/boot/grub2/grub.cfg" "$BUILD_DIR/extracted/EFI/BOOT/grub.cfg"; do
  if [[ -f "$cfg" ]]; then
    sed -i 's/set default=.*/set default="0"/' "$cfg"
    sed -i 's/set timeout=.*/set timeout=1/' "$cfg"
    # Remove any existing inst.ks= parameter to prevent duplicates
    sed -i 's/ inst\.ks=[^ ]*//g' "$cfg"
    # Append the correct inst.ks= parameter
    sed -i "s|inst.stage2=hd:LABEL=[^ ]*|& inst.ks=cdrom:/omarchy-ks-offline.cfg|g" "$cfg"
  fi
done

# 7. Repack bootable ISO
echo "[7/7] Building final ISO ($OUTPUT_ISO)..."

if ! command -v xorriso &>/dev/null; then
  echo "Installing xorriso..."
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
    -c boot.catalog \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -eltorito-alt-boot \
    -e '--interval:appended_partition_2:all::' \
    -no-emul-boot -isohybrid-gpt-basdat \
    -append_partition 2 0xef "$BUILD_DIR/efiboot.img" \
    $([[ -f "$BUILD_DIR/macboot.img" ]] && echo "-append_partition 3 0x00 $BUILD_DIR/macboot.img") \
    -appended_part_as_gpt \
    -isohybrid-mbr "$BUILD_DIR/extracted/boot/grub2/i386-pc/boot_hybrid.img" \
    -o "$OUTPUT_ISO" \
    "$BUILD_DIR/extracted"
else
  echo "Error: xorriso not available. ISO generation aborted." >&2
  exit 1
fi

rm -rf "$BUILD_DIR"
echo -e "\e[32m=== Build Complete: $OUTPUT_ISO ===\e[0m"
