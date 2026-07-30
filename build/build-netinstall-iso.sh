#!/bin/bash
# Omarchy Fedora Netinstall ISO Build Script
# Unpacks Fedora Everything Netinstall, embeds Omarchy payload, builds bootable ISO.
#
# Prerequisites:
#   - Fedora Everything Netinstall ISO (Fedora-Everything-netinst-x86_64-44-*.iso)
#   - bsdtar, xorriso (installed automatically if missing)
#
# Usage:
#   sudo bash build/build-netinstall-iso.sh /path/to/Fedora-Everything-netinst-x86_64-44-*.iso

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

BUILD_DIR="/tmp/fedomakase_iso_build"
OUTPUT_ISO="$REPO_DIR/fedomakase-44-x86_64.iso"
ISO_LABEL="Fedora-E-dvd-x86_64-44"

echo -e "\e[32m=== Starting Fedomakase Netinstall ISO Build ===\e[0m"

# 1. Clean & prepare build workspace
echo "[1/6] Preparing build workspace..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/extracted"

# 2. Extract base Fedora ISO
echo "[2/6] Extracting base Fedora ISO..."
bsdtar -C "$BUILD_DIR/extracted" -xf "$FEDORA_ISO"

# 3. Extract EFI and MAC boot partitions
echo "[3/6] Restoring UEFI bootloader partition..."
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
echo "[4/6] Injecting Kickstart and Omarchy payload..."
cp -f "$OMARCHY_DIR/installer/omarchy-ks.cfg" "$BUILD_DIR/extracted/omarchy-ks.cfg"
mkdir -p "$BUILD_DIR/extracted/omarchy-fedora"
rsync -a --exclude="*.iso" "$OMARCHY_DIR/" "$BUILD_DIR/extracted/omarchy-fedora/"

# Download static gum for installer UI
echo "Downloading static gum binary..."
wget -qO /tmp/gum.tar.gz "https://github.com/charmbracelet/gum/releases/download/v0.14.3/gum_0.14.3_Linux_x86_64.tar.gz" || true
tar -xf /tmp/gum.tar.gz -C /tmp || true
cp /tmp/gum_0.14.3_Linux_x86_64/gum "$BUILD_DIR/extracted/omarchy-fedora/installer/gum" 2>/dev/null || true
chmod +x "$BUILD_DIR/extracted/omarchy-fedora/installer/gum" 2>/dev/null || true

# 5. Update GRUB2 boot configuration
echo "[5/6] Updating bootloader configuration..."
for cfg in "$BUILD_DIR/extracted/boot/grub2/grub.cfg" "$BUILD_DIR/extracted/EFI/BOOT/grub.cfg"; do
  if [[ -f "$cfg" ]]; then
    sed -i 's/set default=.*/set default="0"/' "$cfg"
    sed -i 's/set timeout=.*/set timeout=1/' "$cfg"
    # Remove any existing inst.ks= or inst.text parameter to prevent duplicates
    sed -i 's/ inst\.ks=[^ ]*//g' "$cfg"
    sed -i 's/ inst\.text//g' "$cfg"
    # Append inst.ks= and force text mode (GUI overrides TTY switches)
    sed -i "s|inst.stage2=hd:LABEL=[^ ]*|& inst.ks=hd:LABEL=$ISO_LABEL:/omarchy-ks.cfg inst.text|g" "$cfg"
  fi
done

# 6. Repack bootable ISO
echo "[6/6] Building final ISO ($OUTPUT_ISO)..."

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
  echo "Error: xorriso not available. ISO generation aborted." >&2
  exit 1
fi

rm -rf "$BUILD_DIR"
echo -e "\e[32m=== Build Complete: $OUTPUT_ISO ===\e[0m"
